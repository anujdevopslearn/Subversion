#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_slimarray_affy_arrays.pl
# Author      : Bruz Marzolf <bmarzolf@systemsbiology.org>
#
# Description : This script loads Affy arrays from SLIMarray into SBEAMS
#
###############################################################################
our $VERSION = '1.00';

=head1 NAME

load_slimarray_affy_arrays.pl - SLIMarray array loader


=head1 SYNOPSIS

  --run_mode <add_new or update or delete>  [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
    --testonly         Information in the database is not altered
    --base_directory   <file path> Override the default directory to start
                       searching for files
    --file_extension   <space separated list> Override the default File
                       extensions to search for.

=head1 DESCRIPTION

This script loads Affy arrays from SLIMarray into SBEAMS


=head2 EXPORT

Nothing


=head1 SEE ALSO

SBEAMS::Microarray::Affy;
SBEAMS::Microarray::Affy_file_groups;

SBEAMS::Microarray::Settings; #contains the default file extensions and file path to find Affy files of interest

=head1 AUTHOR

Bruz Marzolf, E<lt>bmarzolf@localdomainE<gt>

=cut

###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use File::Basename;

#use File::Find;
use Data::Dumper;

#use XML::XPath;
#use XML::Parser;
#use XML::XPath::XMLParser;

use JSON;
use LWP::UserAgent;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $q $sbeams_affy $sbeams_affy_groups
  $PROG_NAME $USAGE %OPTIONS
  $VERBOSE $QUIET $DEBUG
  $DATABASE $TESTONLY
  $CURRENT_USERNAME
  $SBEAMS_SUBDIR
  $BASE_DIRECTORY
  $AGE_LIMIT
  @FILE_TYPES
  $SLIMARRAY_URI
  $SLIMARRAY_USER
  $SLIMARRAY_PASS
  $RUN_MODE
  %HOLD_COVERSION_VALS
  %data_to_find
  @BAD_PROJECTS
  $METHOD
  $UPDATE_ARRAY
  $DELETE_ARRAY
  $DELETE_BOTH
  $DELETE_ALL
);

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray::Tables;

use SBEAMS::Microarray::Affy;
use SBEAMS::Microarray::Affy_file_groups;

$sbeams = new SBEAMS::Connection;

$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$sbeams_affy = new SBEAMS::Microarray::Affy;
$sbeams_affy->setSBEAMS($sbeams);
$sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;

$sbeams_affy_groups->setSBEAMS($sbeams);

#use CGI;
#$q = CGI->new();

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;

my @run_modes = qw(add_new update delete);

$USAGE = <<EOU;
$PROG_NAME is used to find and load Affy arrays into SBEAMS. 


Usage: $PROG_NAME --run_mode <add_new, update, delete>  [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
    --base_directory   <file path> Override the default directory to start
                       searching for files
    --file_extension   <space separated list> Override the default File
                       extensions to search for.
    --testonly         Information in the database is not altered

Run Mode Notes:
 add_new : will only upload new files if the file_root name is unique
 
 update --method \<space separated list\>: 
 	Update run mode runs just like the add_new mode, parsing and gathering 
  information.  It will upload NEW files if it finds them, but if the root_file
  name has been previously set this method will update the data pointed to by
  the method flag
  
  Must provide a --method command line flag followed by a comma separated list
  of method names.  Data will be updated only for fields with a valid method 
  name always overriding the data in the database See Affy.pm for the names of
  the setters
  
  Will also accept array number(s) to specifically update instead of all the 
  arrays.  Set the --array_id flag and give some ids comma separated.
 
 delete 

  --array <affy_array_id> OR <root_file_name> Delete the array but LEAVES
    the sample, can be a comma separated list
  --both <affy_array_id> OR <root_file_name>  Deletes the array and sample, can
    be a comma separated list
  --delete_all YES
    Removes all the samples and array information

Examples;

# typical mode, adds any new files
1) ./$PROG_NAME --run_mode add_new 			        

# will parse the sample tag information and stomp the data in the database 	  
2) ./$PROG_NAME --run_mode update --method set_afs_sample_tag   

3) ./$PROG_NAME --run_mode update --method set_afs_sample_tag --array_id 507,508

4) ./$PROG_NAME --run_mode update --method show_all_methods

# Delete the array with the file root given but LEAVES the sample
5) ./$PROG_NAME --run_mode delete --array 20040609_02_LPS1-50	

# removes both the array and sample records for the two root_file names
6) ./$PROG_NAME --run_mode delete --both 20040609_02_LPS1-40 20040609_02_LPS1-50	

#REMOVES ALL ARRAYS AND SAMPLES....Becareful
7) ./$PROG_NAME --run_mode delete --delete_all YES			

EOU

#### Process options
unless (
  GetOptions(
    \%OPTIONS,  "run_mode:s",       "verbose:i",    "quiet",
    "debug:i",  "array:s",          "both:s",       "delete_all:s",
    "method:s", "base_directory:s", "file_types:s", "testonly",
    "array_id:s", "age_limit:i"
  )
  )
{
  print "$USAGE";
  exit;
}

$VERBOSE  = $OPTIONS{verbose} || 0;
$QUIET    = $OPTIONS{quiet};
$DEBUG    = $OPTIONS{debug} || 0;
$TESTONLY = $OPTIONS{testonly};
$RUN_MODE = $OPTIONS{run_mode};

$METHOD = $OPTIONS{method};

$UPDATE_ARRAY = $OPTIONS{array_ids};

$DELETE_ARRAY = $OPTIONS{array};
$DELETE_BOTH  = $OPTIONS{both};
$DELETE_ALL   = $OPTIONS{delete_all};

my $val = grep { $RUN_MODE eq $_ } @run_modes;

unless ($val) {
  print "\n*** Invalid or missing run_mode: $RUN_MODE ***\n\n $USAGE";
  exit;
}

if ( $RUN_MODE eq 'update' )
{    #if update mode check to see if --method <name> is set correctly
  unless ( $METHOD =~ /^set/ || $METHOD =~ /^show/ ) {
    print
"\n*** Must provide a --method command line argument when updating data ***$USAGE\n";
    exit;

  }

  check_setters($METHOD);

}

##############################
##Setup a few global variables
if ( $OPTIONS{base_directory} ) {
  $BASE_DIRECTORY = $OPTIONS{base_directory};
}
else {
  $BASE_DIRECTORY =
    $sbeams_affy->get_AFFY_DEFAULT_DIR()
    ;    #get method in SBEAMS::Microarray::Settings.pm
}

if ( $OPTIONS{file_types} ) {
  @FILE_TYPES = split /\s+/, $OPTIONS{file_types};
}
else {
  @FILE_TYPES = $sbeams_affy->get_AFFY_FILES();
}

if ( $OPTIONS{age_limit} ) {
  $AGE_LIMIT = $OPTIONS{age_limit};
}

$SLIMARRAY_URI =
  $sbeams_affy->get_SLIMARRAY_URI()
  ;      #get method in SBEAMS::Microarray::Settings.pm
$SLIMARRAY_USER =
  $sbeams_affy->get_SLIMARRAY_USER()
  ;      #get method in SBEAMS::Microarray::Settings.pm
$SLIMARRAY_PASS =
  $sbeams_affy->get_SLIMARRAY_PASS()
  ;      #get method in SBEAMS::Microarray::Settings.pm

############################

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  RUN_MODE = $RUN_MODE\n";
  print "  BASE_DIR = $BASE_DIRECTORY\n";
  print "  FILE_TYPE = @FILE_TYPES\n";
  print "  TESTONLY = $OPTIONS{testonly}\n";
  print "  METHOD = $METHOD\n";
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################
$sbeams_affy_groups->base_dir($BASE_DIRECTORY);
$sbeams_affy_groups->file_extension_names(@FILE_TYPES);
$sbeams_affy_groups->verbose($VERBOSE);
$sbeams_affy_groups->debug($DEBUG);

main();
exit(0);

###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

#### Try to determine which module we want to affect
  my $module     = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ( $module eq 'Microarray' ) {
    $work_group = "Microarray_admin";
    $DATABASE   = $DBPREFIX{$module};
    print "DATABASE '$DATABASE'\n" if ($DEBUG);
  }

#### Do the SBEAMS authentication and exit if a username is not returned
  exit
    unless ( $CURRENT_USERNAME =
    $sbeams->Authenticate( work_group => $work_group, ) );

## Presently, force module to be microarray and work_group to be Microarray_admin  XXXXXX what does this do and is it needed
  if ( $module ne 'Microarray' ) {
    print
      "WARNING: Module was not Microarray.  Resetting module to Microarray\n";
    $work_group = "Microarray_admin";
    $DATABASE   = $DBPREFIX{$module};
  }

  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

}    # end main

###############################################################################
# handleRequest
#
# Handles the core functionality of this script
###############################################################################
sub handleRequest {
  my %args     = @_;
  my $SUB_NAME = "handleRequest";

  if ( $RUN_MODE eq 'add_new' || $RUN_MODE eq 'update' ) {

    print "Retrieving affy array information from SLIMarray\n";
    parse_slimarray_arrays();

    print "Starting to add arrays\n";
    add_affy_arrays( object => $sbeams_affy ); #add all the data to the database

    #write_error_log( object => $sbeams_affy_groups );
    if (@BAD_PROJECTS) {
      print "ERROR: PROJECT WITH NO PROJECT ID's\n";
      print @BAD_PROJECTS;
    }
  }
  elsif ( $RUN_MODE eq 'delete' ) {
    unless ( $DELETE_ARRAY || $DELETE_BOTH || $DELETE_ALL ) {
      die
"*** Please provide command line arg --both or --array with a valid affy array_id when attempting to delete data\n",
        "Or provide the command line arg --delete_all YES\n",
        "You provided '$DELETE_ARRAY' or '$DELETE_BOTH'\n ***\n$USAGE";
    }

    #delete_affy_data();
  }
  else {
    die "This is not a valid run mode '$RUN_MODE'\n $USAGE";
  }
}

###############################################################################
#parse_slimarray_arrays
#
#Parse sample information from SLIMarray to make SBEAMS array records
###############################################################################

sub parse_slimarray_arrays {
  my $SUB_NAME = 'parse_slimarray_arrays';

  print "Using SLIMarray URI: $SLIMARRAY_URI\n" if $VERBOSE > 0;

  my @array_summaries = request_summary_json();

  print "Found ", $#array_summaries + 1, " arrays in SLIMarray\n";

  foreach my $summary (@array_summaries) {
    print "Processing ", $summary->{"file_root"}, "\n" if $VERBOSE > 0;

  # skip if we're adding new arrays only and this one is already in the database
    my $db_affy_array_id =
      $sbeams_affy_groups->find_affy_array_id(
      root_file_name => $summary->{"file_root"} );
    if ( $db_affy_array_id != 0 && $RUN_MODE eq 'add_new' ) {
      print
"FILE ROOT IS ALREADY IN DATABASE AND WE ARE NOT IN UPDATE MODE SKIP PARSING '",
        $summary->{"file_root"}, "'\n"
        if $VERBOSE > 0;
      next;
    }

    my %sample = request_sample_json( $summary->{"uri"} );

    # skip if this is not an Affymetrix array
    unless ( $sample{"raw_data_type"} eq "Affymetrix CEL" ) {
      print "NOT AN AFFYMETRIX FILE: ", $sample{"raw_data_path"}, "\n"
        if $VERBOSE > 0;
      next;
    }
    
    # skip if the raw data doesn't exist on the file system
    unless ( $sample{"raw_data_path"} ne "" && -e $sample{"raw_data_path"} ) {
      print "FILE DOES NOT EXIST: ", $sample{"raw_data_path"}, "\n"
        if $VERBOSE > 0;
      next;
    }

    print "Found file: ", $sample{"raw_data_path"}, "\n" if $VERBOSE > 0;

    my $sbeams_affy = new SBEAMS::Microarray::Affy;    #make new affy instance

    # set file root
    $sbeams_affy->set_afa_file_root( $sample{"file_root"} );

    # set the sample_tag--within a project this should be a unique name
    my $sample_tag = $sample{"sample_description"};
    $sbeams_affy->set_afs_sample_tag($sample_tag);

    # set base path
    $sample{"raw_data_path"} =~ /^(.*)\/\d{8}_\d{2}_.*/;
    my $base_path = $1;
    print "Base path: $base_path\n" if $VERBOSE >= 2;
    my $base_path_id = get_file_path_id( basepath => $base_path );
    print "BASENAME '$base_path' CONVERTED TO FILE_PATH_ID '$base_path_id'\n"
      if $VERBOSE > 0;
    $sbeams_affy->set_afa_file_path_id($base_path_id);

#Hash keys <Table_abbreviation _ column name> which should also match the method names in Affy.pm
    %data_to_find = (
      AFS_PROJECT_ID => {
        KEY        => 'project',
        VAL        => '',
        SORT       => 1,
        SQL_METHOD =>
          '$sbeams_affy->find_project_id(project_name=>$val, do_not_die => 1)',
        FILE_VAL_REQUIRED => 'YES',
      },

      AFA_USER_ID => {
        KEY               => 'user',
        SORT              => 2,
        VAL               => '',
        SQL_METHOD        => '$sbeams_affy->find_user_login_id(username=>$val)',
        FILE_VAL_REQUIRED => 'YES',
      },

      AFS_ORGANISM_ID => {
        KEY        => 'organism',
        VAL        => '',
        SORT       => 3,
        SQL_METHOD => '$sbeams_affy->find_organism_id(organism_name=>$val)',
        FILE_VAL_REQUIRED => 'YES',
      },

      AFA_ARRAY_TYPE_ID => {
        KEY        => 'chip_type',
        VAL        => '',
        SORT       => 4,
        SQL_METHOD => '$sbeams_affy->find_slide_type_id(slide_name=>$val)',
        FILE_VAL_REQUIRED => 'YES',
      },

      AFS_SAMPLE_TAG => {
        KEY               => 'sample_description',
        VAL               => '',
        SORT              => 5,
        FILE_VAL_REQUIRED => 'YES',
      },
      AFS_SAMPLE_GROUP_NAME => {
        KEY               => 'sample_group_name',
        VAL               => '',
        SORT              => 6,
        FILE_VAL_REQUIRED => 'YES',
      },

      #
      AFS_SAMPLE_PREPARATION_DATE => {
        KEY               => 'submission_date',
        VAL               => '',
        SORT              => 31,
        FILE_VAL_REQUIRED => 'NO',
      },

#DEFAULT TO THE USER_id ORGANIZATION ID
#AFS_SAMPLE_PROVIDER_ORGANIZATION    =>{	HEADER  => 'sample_sample_provider_organization',
#		          	VAL	=> '',
#		          	SORT	=> 8,
#		 			FILE_VAL_REQUIRED => 'NO',
#		 			SQL_METHOD => 'get_organization_id(user_login_id => $data_to_find{AFA_USER_ID}{VAL})'
#		           },

      #### End of protocol section ###
      AFS_AFFY_ARRAY_SAMPLE_ID => {
        VAL => $sample_tag
        , #bit of a hack, will query on the sample_tag and project_id which must be unique
        SORT => 100
        , #really want this to go last since it will insert the affy_array_sample if it cannot find the Sample tag in the database.  And it needs some information collected by some of the other hash elements before it does so.
        SQL => "	SELECT affy_array_sample_id
    					 				FROM $TBMA_AFFY_ARRAY_SAMPLE
    									WHERE sample_tag like 'HOOK_VAL'",

        CONSTRAINT =>
          '"AND project_id = " . $data_to_find{AFS_PROJECT_ID}{VAL}',
      },
    );

    #############################################################################################################################
#loop through the data_to_find keys pulling data from the INFO files and converting the human readable names to id within the database
    foreach my $data_key (
      sort { $data_to_find{$a}{'SORT'} <=> $data_to_find{$b}{'SORT'} }
      keys %data_to_find
      )
    {    #start foreach loop

      my $val = '';

      ##########################################################################################
      ##Pull the value from the SLIMarray JSON
      if ( my $key = $data_to_find{$data_key}{KEY} ) {

        if ( $VERBOSE > 0 ) {
          print "FIND DATA FOR KEY '$key'\n";
        }

        $val = $sample{$key};
      }
      else {
        $val =
          $data_to_find{$data_key}
          {VAL}; #use the default VAL from the data_to_find hash if there's no KEY
      }

      if ( $data_to_find{$data_key}{FILE_VAL_REQUIRED}
        && $data_to_find{$data_key}{FILE_VAL_REQUIRED} eq 'YES' & !$val )
      {
        $sbeams_affy_groups->group_error(
          root_file_name => $sample{"file_root"},
          error => "CANNOT FIND VAL FOR '$data_key' EITHER FROM THE INFO"
            . "FILE OR DEFAULT, THIS IS NOT GOOD.  Please EDIT THE FILE AND TRY AGAIN",
        );
        next;
      }

      if ( $VERBOSE > 0 ) {
        print "$data_key => '$val'\n";
      }
      ##########################################################################################
      ###if the data $val needs to be converted to a id value from the database run the little sql statement to do so
      my $id_val = '';

      if ( $data_to_find{$data_key}{SQL}
        || $data_to_find{$data_key}{SQL_METHOD} )
      {

        $id_val = convert_val_to_id(
          value      => $val,
          sql        => $data_to_find{$data_key}{SQL},
          sql_method => $data_to_find{$data_key}{SQL_METHOD},
          data_key   => $data_key,
          affy_obj   => $sbeams_affy,
        );
      }
      elsif ( $data_to_find{$data_key}{FORMAT} ) {

        $id_val = format_val(
          value     => $val,
          transform => $data_to_find{$data_key}{FORMAT},
        );
      }
      else {
        $id_val = $val
          ; #if the val from the INFO FILE does not need to be convert or formatted give it back
      }

 #store the results of the conversion (if needed) no matter what the results are
      $data_to_find{$data_key}{VAL} = $id_val;

      ##########################################################################################
      #collected errors in the all_files_h and print them to the log file
      if ( defined $id_val && $id_val =~ /ERROR/ ) {
        $sbeams_affy_groups->group_error(
          root_file_name => $sample{"file_root"},
          error          => "$id_val",
        );
        print "$id_val\n";

        if ( $data_key eq 'AFS_PROJECT_ID' ) {    #TESTING
              #push @BAD_PROJECTS, ( $summary->{"uri"}, "\t$val\n" );
          print "NO PROJECT ID FOR: $val\n";
        }
      }
      else {
        set_data(
          value  => $id_val,        #collect the 'Good' data in Affy objects
          key    => $data_key,
          object => $sbeams_affy,
        );
      }
      
      # stop processing this array if there was an error
      # this prevents crashes due to an error result for one array attribute being used in the lookup for another 
      last if $id_val =~ /ERROR/;
    }
  }
}

###############################################################################
#request_summary_json
#
#Request the summary JSON for all arrays from SLIMarray
###############################################################################

sub request_summary_json {
  my $browser = new LWP::UserAgent( keep_alive => 1 );

  my $age_limit_parameter = "";
  if($AGE_LIMIT) {
    $age_limit_parameter = "?age_limit=" . $AGE_LIMIT
  }
  
  my $url = "$SLIMARRAY_URI/samples" . $age_limit_parameter;
  my $request = HTTP::Request->new( GET => $url );
  $request->authorization_basic( $SLIMARRAY_USER, $SLIMARRAY_PASS );
  $request->content_type('application/json');

  my $response = $browser->request($request);

  #print $response->as_string, "\n";
  print "Summary JSON: ", $response->content, "\n" if $VERBOSE > 0;

  #print $response->status_line;

  my $json                   = new JSON;
  my $array_summaries_scalar = $json->decode( $response->content );

  return @{$array_summaries_scalar};
}

###############################################################################
#request_sample_json
#
#Request the detailed JSON for a single sample from SLIMarray
###############################################################################

sub request_sample_json {
  my $sample_uri = shift @_;

  print "Sample URI: $sample_uri\n" if $VERBOSE > 0;

  my $browser = new LWP::UserAgent( keep_alive => 1 );

  my $request = HTTP::Request->new( GET => $sample_uri );
  $request->authorization_basic( $SLIMARRAY_USER, $SLIMARRAY_PASS );
  $request->content_type('application/json');

  my $response = $browser->request($request);

  #print $response->as_string, "\n";
  print "Detail JSON: ", $response->content, "\n" if $VERBOSE > 0;

  #print $response->status_line;

  my $json                = new JSON;
  my $array_detail_scalar = $json->decode( $response->content );

  return %{$array_detail_scalar};
}

###############################################################################
#get_file_path_id
#
#Change the file base path to an id
###############################################################################
sub get_file_path_id {
  my $SUB_NAME = 'get_file_path_id';

  my $basepath = '';

  my %args = @_;

  $basepath = $args{basepath};

  if ( exists $HOLD_COVERSION_VALS{BASE_PATH}{$basepath} )
  { #first check to see if this path has been seen before, if so pull it from memory
    return $HOLD_COVERSION_VALS{BASE_PATH}
      {$basepath};    #return the file_path.file_path_id
  }

#if we have not seen the base path look in the database to see if has been entered
  my $sql = qq~ 	SELECT file_path_id
  		FROM $TBMA_FILE_PATH
  		WHERE file_path like '$basepath'
  	   ~;

  my @rows = $sbeams->selectOneColumn($sql);
  if (@rows) {
    $HOLD_COVERSION_VALS{BASE_PATH}{$basepath} = $rows[0];
    return $rows[0];    #return the file_path.file_path_id
  }

  unless (@rows) {

    my $rowdata_ref = {
      file_path_name => 'Path to Affy Data'
      ,                 #if the base path has not been seen insert a new record
      file_path => $basepath,
      server_id => 1,           #hack to default to server id 1.  FIX ME
    };

    if ( $DEBUG > 0 ) {
      print "SQL DATA\n";
      print Dumper($rowdata_ref);
    }
    my $file_path_id = $sbeams->updateOrInsertRow(
      table_name           => $TBMA_FILE_PATH,
      rowdata_ref          => $rowdata_ref,
      return_PK            => 1,
      verbose              => $VERBOSE,
      testonly             => $TESTONLY,
      insert               => 1,
      PK                   => 'file_path_id',
      add_audit_parameters => 1,
    );

    $HOLD_COVERSION_VALS{BASE_PATH}{$basepath} = $file_path_id;
    return $file_path_id;
  }

}

###############################################################################
# convert_val_to_id
# convert the data returned by the X-path into an ID if there is a sql statment to do it
# Will have to substitute the value passed in into the SQL replacing the "HOOK_VAL"
#
# Maybe should be called 'convert val to id and oh, incidentally insert an
# affy_array_sample record if you are so inclined.  Why on earth is this here!?
#
###############################################################################
sub convert_val_to_id {
  my $SUB_NAME = 'convert_val_to_id';

  my %args = @_;

  my $val        = $args{'value'};
  my $sql        = $args{'sql'};
  my $sql_method = $args{'sql_method'};

  my $data_key    = $args{'data_key'};
  my $sbeams_affy = $args{'affy_obj'};

  print "STARTING $SUB_NAME\n" if ( $VERBOSE > 0 );
  return unless ( $sql || $sql_method ) && $val;

  ###########################################

  if ( exists $HOLD_COVERSION_VALS{$data_key}{$val} )
  { #if the value has been used before in a query and it returned an id just reuse the previous id instead of requiring
    if ( $VERBOSE > 0 ) {
      print "VAL '$val' for '$data_key' HAS BEEN SEEN BEFORE RETURNING",
" DATA '$HOLD_COVERSION_VALS{$data_key}{$val}' FROM CONVERSION VAL HASH\n";
    }
    return $HOLD_COVERSION_VALS{$data_key}{$val};
  }
  ###########################################

  my @rows = ();
  if ($sql) {
    $sql =~
      s/HOOK_VAL/$val/;   #replace the 'HOOK_VAL' in the sql query with the $val

    if ( exists $data_to_find{$data_key}{'CONSTRAINT'} )
    { #if there is a constraint to attach to the sql attach the value to the sql statment
      my $constraint = '';

      $constraint =
        eval $data_to_find{$data_key}{'CONSTRAINT'
        }; #takes the value from the CONSTRAINT key, then does an eval on the perl statement returning the value which can then be appended to the sql statment

      if ($@) {
        print "ERROR: COULD NOT ADD CONSTRAINT to SQL '$@'\n";
        die;
      }

      if ( $VERBOSE > 0 ) {
        print "ADDING CONSTRAINT TO SQL '$constraint'\n";
      }
      $sql .= $constraint;
    }
    print "ABOUT TO RUN SQL'$sql'\n" if ( $VERBOSE > 0 );
    @rows = $sbeams->selectOneColumn($sql);
  }
  elsif ( $sql_method && $val ) {
    print "SQL METHOD TO RUN '$sql_method'\n" if ( $VERBOSE > 0 );

    @rows =
      eval $sql_method
      ; #eval the sql_method which will point to a method in Affy.pm, that should convert a name tag to the database id

    if ($@) {
      return "ERROR: COULD NOT RUN METHOD '$sql_method' '$@'\n";
      #print "ERROR: COULD NOT RUN METHOD '$sql_method' '$@'\n";
      #die;
    }
  }

  if ( $VERBOSE > 0 ) {
    print "SUB '$SUB_NAME' SQL '$sql'\n";
    print "DATA TO CONVERT '$data_key' RESULTS '@rows'\n";
  }

  if ( defined $rows[0] && $rows[0] =~ /^\d/ )
  { #if the query works it will give back a id, if not it will try and find a default value below
    $HOLD_COVERSION_VALS{$data_key}{$val} = $rows[0];
    return $rows[0];

  }
  else {
    if ( $data_key eq 'AFS_AFFY_ARRAY_SAMPLE_ID' )
    {    #if there was no affy_sample_id then the record needs to be inserted

      my $organization_id =
        get_organization_id( user_login_id => $data_to_find{AFA_USER_ID}{VAL} )
        ;    #Grab the organization_id if there is a valid user_login_id

      my $rowdata_ref = {
        project_id => $sbeams_affy->get_afs_project_id()
        , #get the project_id, should always be the first piece of data to be converted
        sample_tag               => $sbeams_affy->get_afs_sample_tag(),
        sample_group_name        => $sbeams_affy->get_afs_sample_group_name(),
        affy_sample_protocol_ids =>
          $sbeams_affy->get_afs_affy_sample_protocol_ids(),
        sample_preparation_date =>
          $sbeams_affy->get_afs_sample_preparation_date()
        ? $sbeams_affy->get_afs_sample_preparation_date()
        : 'CURRENT_TIMESTAMP'
        , #default to current time stamp, user is the only one who knows this data
        sample_provider_organization_id => $organization_id,
        organism_id                     => $sbeams_affy->get_afs_organism_id(),
        strain_or_line        => $sbeams_affy->get_afs_strain_or_line(),
        individual            => $sbeams_affy->get_afs_individual(),
        sex_ontology_term_id  => $sbeams_affy->get_afs_sex_ontology_term_id(),
        age                   => $sbeams_affy->get_afs_age(),
        organism_part         => $sbeams_affy->get_afs_organism_part(),
        cell_line             => $sbeams_affy->get_afs_cell_line(),
        cell_type             => $sbeams_affy->get_afs_cell_type(),
        disease_state         => $sbeams_affy->get_afs_disease_state(),
        rna_template_mass     => $sbeams_affy->get_afs_rna_template_mass(),
        protocol_deviations   => $sbeams_affy->get_afs_protocol_deviations(),
        sample_description    => $sbeams_affy->get_afs_sample_description(),
        treatment_description => $sbeams_affy->get_afs_treatment_description(),
        comment               => $sbeams_affy->get_afs_comment(),
        data_flag             => $sbeams_affy->get_afs_data_flag(),
      };

      if ($DEBUG) {
        print "SQL DATA\n";
        print Dumper($rowdata_ref);
      }
      my $sample_id = $sbeams->updateOrInsertRow(
        table_name           => $TBMA_AFFY_ARRAY_SAMPLE,
        rowdata_ref          => $rowdata_ref,
        return_PK            => 1,
        verbose              => $VERBOSE,
        testonly             => $TESTONLY,
        insert               => 1,
        PK                   => 'affy_array_sample_id',
        add_audit_parameters => 1,
      );

      print "SAMPLE ID '$sample_id'\n";

      if ($sample_id) {
        insert_treatment_records(
          sample_id   => $sample_id,
          sbeams_affy => $sbeams_affy
        );
      }

      unless ($sample_id) {
        return "ERROR: COULD NOT ENTER SAMPLE FOR SAMPLE TAG '"
          . $sbeams_affy->get_afs_sample_tag() . "'\n";
      }

      return $sample_id;    #SHOULD CHECK THIS

    }

    return "ERROR: CANNOT FIND ID CONVERTING '$data_key' FOR VAL '$val'";
  }
}

###############################################################################
# set_data
# convert the data_to_find hash key to a method name and set the data in the affy object
#
###############################################################################
sub set_data {
  my $SUB_NAME = 'set_data';

  my %args = @_;

  my $sbeams_affy = $args{'object'};

  my $data_key    = lc( $args{'key'} );
  my $method_name =
    "set_$data_key"; #make the method name to call to the Microarray::Affy class

  if ( $VERBOSE > 0 ) {
    print "METHOD NAME '$method_name' VAL '$args{value}'\n";
  }

  $sbeams_affy->$method_name( $args{'value'} );    #set the value
}

###############################################################################
# get_organization_id
#
# given the user_login_id get the organization id
###############################################################################
sub get_organization_id {
  my $SUB_NAME = 'get_organization_id';

  my %args = @_;

  my $user_login_id = $args{'user_login_id'};

  return unless ( $user_login_id =~ /^\d+$/ );

  if ( exists $HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id} )
  {    #if the user_id has been seen before return the org_id

    return $HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id};

  }

  my $sql = qq~ 	SELECT o.organization_id, organization 
  		FROM $TB_ORGANIZATION o, $TB_CONTACT c, $TB_USER_LOGIN ul
  		WHERE ul.user_login_id = $user_login_id AND
  		ul.contact_id = c.contact_id AND
  		c.organization_id = o.organization_id
  	  ~;

  my @rows = $sbeams->selectOneColumn($sql);

  if ( $rows[0] ) {
    $HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id} =
      $rows[0];    #save the user_id Organization_id for future access
    return $rows[0];

  }
  else {
    return;
  }
}

sub insert_treatment_records {
  my %args = @_;
  return unless $args{sample_id} || $args{sbeams_affy};
  my $treatments = $args{sbeams_affy}->get_treatment_values();
  for my $treatment ( @{$treatments} ) {
    my $treat_id = $sbeams->updateOrInsertRow(
      PK                   => 'treatment_id',
      table_name           => $TBMA_TREATMENT,
      rowdata_ref          => $treatment,
      return_PK            => 1,
      verbose              => $VERBOSE,
      testonly             => $TESTONLY,
      insert               => 1,
      add_audit_parameters => 1,
    );
    print "added treatment $treat_id \n" if $DEBUG;

    next unless $treat_id;

    # Add any treatment to sample links
    my $rowdata = {
      treatment_id         => $treat_id,
      affy_array_sample_id => $args{sample_id}
    };

    my $ast_id = $sbeams->updateOrInsertRow(
      PK                   => 'affy_sample_treatment_id',
      table_name           => $TBMA_AFFY_SAMPLE_TREATMENT,
      rowdata_ref          => $rowdata,
      return_PK            => 1,
      verbose              => $VERBOSE,
      testonly             => $TESTONLY,
      insert               => 1,
      add_audit_parameters => 0,
    );

  }

}

###############################################################################
# add_affy_arrays
#
#Take all the objects that were created reading the files and add (or update) data to the affy_array table
###############################################################################
sub add_affy_arrays {
  my $SUB_NAME = 'add_affy_arrays';
  my %args     = @_;

  my $sbeams_affy = $args{'object'};

  foreach my $affy_o ( $sbeams_affy->registered ) {

    # skip arrays without the required information
    next
      unless ( $affy_o->get_afs_project_id &&
               $affy_o->get_afa_file_root &&
               $affy_o->get_afa_array_type_id &&
               $affy_o->get_afa_user_id &&
               $affy_o->get_afs_affy_array_sample_id &&
               $affy_o->get_afa_file_path_id
             );

  #return the affy_array_id if the array is already in the db otherwise return 0
    my $db_affy_array_id =
      $sbeams_affy_groups->find_affy_array_id(
      root_file_name => $affy_o->get_afa_file_root() );

    if ( $db_affy_array_id == 0 ) {
      if ( $VERBOSE > 0 ) {
        print "ADDING OBJECT '" . $affy_o->get_afa_file_root() . "'\n";

      }

      my $rowdata_ref = {
        file_root      => $affy_o->get_afa_file_root,
        array_type_id  => $affy_o->get_afa_array_type_id,
        user_id        => $affy_o->get_afa_user_id,
        processed_date => $affy_o->get_afa_processed_date
        ? $affy_o->get_afa_processed_date
        : 'CURRENT_TIMESTAMP',
        affy_array_sample_id    => $affy_o->get_afs_affy_array_sample_id,
        file_path_id            => $affy_o->get_afa_file_path_id,
        affy_array_protocol_ids => $affy_o->get_afa_affy_array_protocol_ids,
        comment                 => $affy_o->get_afa_comment,
      };

      my $new_affy_array_id = $sbeams->updateOrInsertRow(
        table_name           => $TBMA_AFFY_ARRAY,
        rowdata_ref          => $rowdata_ref,
        return_PK            => 1,
        verbose              => $VERBOSE,
        testonly             => $TESTONLY,
        insert               => 1,
        PK                   => 'affy_array_id',
        add_audit_parameters => 1,
      );

      if ($new_affy_array_id) {
        add_protocol_information(
          object        => $affy_o,
          affy_array_id => $new_affy_array_id
        );
      }

    }
    elsif ( $db_affy_array_id =~ /^\d/ && $RUN_MODE eq 'update' )
    {    #come here if the root_file name has been seen before

      if ( $VERBOSE > 0 ) {
        print "UPDATEING DATA '" . $affy_o->get_afa_file_root . "'\n",
          "METHODS '$METHOD' ARRAY_ID '$db_affy_array_id'\n";
      }

      update_data(
        object   => $affy_o,
        array_id => $db_affy_array_id,
        method   => $METHOD,
      );

    }
    else {

      if ( $VERBOSE > 0 ) {
        print Dumper( "BAD OBJECT MISSING STUFF" . $affy_o );
      }
    }
  }
}

###############################################################################
# add_protocol_information
#
#Add protocol information to the linking tables and affy array and affy sample tables
###############################################################################
sub add_protocol_information {
  my $SUB_NAME = 'add_protocl_information';

  my %args          = @_;
  my $affy_o        = $args{object};
  my $affy_array_id = $args{affy_array_id};

  my $affy_array_sample_id = $affy_o->get_afs_affy_array_sample_id();

  my $sample_protocol_val     = $affy_o->get_afs_affy_sample_protocol_ids();
  my $affy_array_protocol_val = $affy_o->get_afa_affy_array_protocol_ids();
  $sample_protocol_val = '' if !defined $sample_protocol_val;
  my @sample_ids = split /,/,
    $sample_protocol_val;    #might be comma delimited list of protocol_ids

  foreach my $protocol_id (@sample_ids)
  {                          #add protocols to the sample protocol linking table

    my $clean_table_name =
      $TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL
      ; #the returnTableInfo cannot contain the database name on Example Microarray.dbo.affy_array

    $clean_table_name =~ s/.*\./MA_/;    #remove everything upto the last period

    my ($PK_COLUMN_NAME) =
      $sbeams->returnTableInfo( $clean_table_name, "PK_COLUMN_NAME" )
      ;    #get the column name for the primary key

    my $rowdata_ref = {
      affy_array_sample_id => $affy_array_sample_id,
      protocol_id          => $protocol_id,
    };

    my $affy_array_sample_protocol_id =
      $sbeams->updateOrInsertRow
      (    #add the affy array sample protocol data to the linking table
      table_name           => $TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL,
      rowdata_ref          => $rowdata_ref,
      return_PK            => 1,
      verbose              => $VERBOSE,
      testonly             => $TESTONLY,
      insert               => 1,
      PK                   => $PK_COLUMN_NAME,
      add_audit_parameters => 1,
      );
    if ( $VERBOSE > 0 ) {
      print
"ADD PROTOCOL '$protocol_id' to SAMPLE LINKING TABLE '$affy_array_sample_protocol_id' for SAMPLE '$affy_array_sample_id'\n";
    }

  }
  #################################################################################
  ###Add the protocols to the array linking table
  $affy_array_protocol_val = '' if !defined $affy_array_protocol_val;
  my @array_p_ids = split /,/,
    $affy_array_protocol_val;    #might be comma delimited list of protocol_ids

  foreach my $protocol_id (@array_p_ids)
  {    #add protocols to the sample protocol linking table

    my $clean_table_name =
      $TBMA_AFFY_ARRAY_PROTOCOL
      ; #the returnTableInfo cannot contain the database name on Example Microarray.dbo.affy_array

    $clean_table_name =~ s/.*\./MA_/;    #remove everything upto the last period

    my ($PK_COLUMN_NAME) =
      $sbeams->returnTableInfo( $clean_table_name, "PK_COLUMN_NAME" )
      ;    #get the column name for the primary key

    my $rowdata_ref = {
      affy_array_id => $affy_array_id,
      protocol_id   => $protocol_id,
    };

    my $affy_array_protocol_id =
      $sbeams->updateOrInsertRow
      (    #add the affy array sample protocol data to the linking table
      table_name           => $TBMA_AFFY_ARRAY_PROTOCOL,
      rowdata_ref          => $rowdata_ref,
      return_PK            => 1,
      verbose              => $VERBOSE,
      testonly             => $TESTONLY,
      insert               => 1,
      PK                   => $PK_COLUMN_NAME,
      add_audit_parameters => 1,
      );
    if ( $VERBOSE > 0 ) {
      print
"ADD PROTOCOL '$protocol_id' to AFFY ARRAY LINKING TABLE '$affy_array_protocol_id' for ARRAY '$affy_array_id'\n";
    }

  }

}    #end of protocol uploads
###############################################################################
# update_data
#
# If data needs to be update come here
###############################################################################
sub update_data {
  my $SUB_NAME = 'update_data';

  if ( $VERBOSE > 0 ) {
    print "IM GOING TO UPDATE DATA\n";
  }
  my %args = @_;

  my $affy_o        = $args{object};
  my $affy_array_id = $args{array_id};
  my $method_names  = $args{method};

  my %table_names = (
    afa  => $TBMA_AFFY_ARRAY,
    afs  => $TBMA_AFFY_ARRAY_SAMPLE,
    afap => $TBMA_AFFY_ARRAY_PROTOCOL
    ,    #will use these if we need to update the linking tables
    afsp => $TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL,
  );

  my @methods = split /,/, $args{method};
  print "ALL METHODS '@methods'\n" if ( $VERBOSE > 0 );
###############################################################################################
##Start looping through all the methods
  foreach my $method (@methods) {

#parse the method name to figure out what table and column to update
#example set_afs_sample_tag  TABLE types afs => (af)fy array (s)ample or afa => (af)fy (a)rray
    if ( $method =~ /set_(af.+?)_(.*)/ ) {
      my $table_type = $1;
      my $table_name =
        $table_names{$table_type};    #table name for the data to update

      my $column_name = $2;

#bit dorky but we want to call the get_(method) but on the command line we entered set_(method)
      $method =~ s/set_/get_/;

      my $rowdata_ref = {};

      ##if we have a list of arrays to update just update a few specific arrays
      if ($UPDATE_ARRAY) {

        if ( grep { $affy_array_id == $_ } split /,/, $UPDATE_ARRAY ) {
          $rowdata_ref = {
            $column_name => $affy_o->$method(),

          };
        }
      }
      else {
        $rowdata_ref = {
          $column_name => $affy_o->$method(),

        };
      }

#the returnTableInfo cannot contain the database name for Example Microarray.dbo.affy_array
      my $clean_table_name = $table_name;

#remove everything upto the last period and append on the db prefix to make MA_affy_array
      $clean_table_name =~ s/.*\./MA_/;

      #get the column name for the primary key
      my ($PK_COLUMN_NAME) =
        $sbeams->returnTableInfo( $clean_table_name, "PK_COLUMN_NAME" );

      my $pk_value = '';

#if we are updating data in the affy_array table then we can use the affy_array_id which was passed in
      if ( $table_type eq 'afa' ) {
        $pk_value = $affy_array_id;

#if we are going to update data in the sample table use the affy_array_id and find the affy_sample_id
      }
      elsif ( $table_type eq 'afs' ) {

        $pk_value =
          $sbeams_affy_groups->find_affy_array_sample_id(
          affy_array_id => $affy_array_id );
      }

      if ( $method =~ /protocol_ids$/ )
      { #if this is a method to update the protocol_ids we will need to update the data in the linking tables too.
        my $protocol_prefix =
          "${table_type}p"
          ;   #append a "p" to figure out which protocol linking table to update

        update_linking_table(
          object   => $affy_o,
          fk_value =>
            $pk_value,    #will need the foreign key to update the linking table
          method             => $method,
          linking_table_name => $table_names{$protocol_prefix},

        );
      }

      if ( $DEBUG > 0 ) {
        print
"UPDATE DATA FOR TABLE '$table_name' CLEAN NAME '$clean_table_name' \n",
          "PK_NAME = '$PK_COLUMN_NAME', PK_value = '$pk_value'\n",
          "COLUMN NAME '$column_name' DATA '" . $affy_o->$method() . "'\n";

        print Dumper($rowdata_ref);
      }

      ####################################################################################################
      ### Updating the Organization id

      if ( $method =~ /afa_user_id$/ )
      { #if we are updating the user ID for whatever reason we will have to update the sample_provider_organization_id too, since it is found by quering with the
            #user_login_id

        my $table_name       = $TBMA_AFFY_ARRAY_SAMPLE;
        my $clean_table_name =
          $TBMA_AFFY_ARRAY_SAMPLE
          ; #the returnTableInfo cannot contain the database name for Example Microarray.dbo.affy_array
        $clean_table_name =~ s/.*\./MA_/
          ; #remove everything upto the last period and append on the db prefix to make MA_affy_array

        my ($PK_COLUMN_NAME) =
          $sbeams->returnTableInfo( $clean_table_name, "PK_COLUMN_NAME" )
          ;    #get the column name for the primary key

        my $pk_value =
          $sbeams_affy_groups->find_affy_array_sample_id(
          affy_array_id => $affy_array_id );

        my $user_login_id = $affy_o->get_afa_user_id;

        my $org_id = get_organization_id( user_login_id => $user_login_id );

        my $rowdata_ref = {
          sample_provider_organization_id => $org_id,

        };

        if ( $DEBUG > 0 ) {
          print
"UPDATE DATA FOR ORGANIZATION '$table_name' CLEAN NAME '$clean_table_name' \n",
"USER ID = '$user_login_id' PK_NAME = '$PK_COLUMN_NAME', PK_value = '$pk_value'\n",
            "COLUMN NAME '$column_name' DATA '$org_id' \n";

          print Dumper($rowdata_ref);
        }

        my $returned_id = $sbeams->updateOrInsertRow(
          table_name           => $table_name,
          rowdata_ref          => $rowdata_ref,
          return_PK            => 1,
          verbose              => $VERBOSE,
          testonly             => $TESTONLY,
          update               => 1,
          PK_name              => $PK_COLUMN_NAME,
          PK_value             => $pk_value,
          add_audit_parameters => 1,
        );
      }
####################################################################################################
### Update the data
      my $returned_id = $sbeams->updateOrInsertRow(
        table_name           => $table_name,
        rowdata_ref          => $rowdata_ref,
        return_PK            => 1,
        verbose              => $VERBOSE,
        testonly             => $TESTONLY,
        update               => 1,
        PK_name              => $PK_COLUMN_NAME,
        PK_value             => $pk_value,
        add_audit_parameters => 1,
      );

    }
    else {
      print "ERROR Cannot Parse Method name '$method' to update data\n";
    }
  }

}

###############################################################################
# update_linking_table
#
#If the data in the protocol_ids column is updated, usually a comma delimited list of protocol ids, we will need to change
#the data within the linking table too.  This subroutine will first delete ALL protocol ids from the linking table for a particular affy_array_id
#then insert the new records
###############################################################################
sub update_linking_table {
  my $SUB_NAME = 'update_linking_table';
  my %args     = @_;

  my $affy_o   = $args{object};
  my $fk_value =
    $args{fk_value};    #this will be the affy_array_id or affy_array_sample_id
  my $method             = $args{method};
  my $linking_table_name =
    $args{linking_table_name}; #Linking table name that will be updated full database table name Example Microarray.dbo.affy_array

  my $c_linking_table_name =
    $linking_table_name
    ; #the returnTableInfo cannot contain the database name for Example Microarray.dbo.affy_array
  $c_linking_table_name =~ s/.*\./MA_/
    ; #remove everything upto the last period and append on the db prefix to make MA_affy_array

  my ( $foregin_key_column_name, $foreign_tbl_name ) =
    $sbeams->returnTableInfo( $c_linking_table_name, 'fk_tables' )
    ;    #to figure out what table we were updating

  my ($PK_COLUMN_NAME) =
    $sbeams->returnTableInfo( $c_linking_table_name, "PK_COLUMN_NAME" )
    ;    #get the column name for the primary key

  delete_linking_table_records(
    fk_value            => $fk_value,
    fk_column_name      => $foregin_key_column_name,
    protocol_table_name => $linking_table_name,
  );

  my $project_ids =
    $affy_o->$method();    #grab the comma delimited list of protocol ids

  my @all_ids = split /,/, $project_ids;    #split them apart

  foreach my $protocol_id (@all_ids)
  {    #foreach protocol id insert the data into the linking table

    my $rowdata_ref = {
      $foregin_key_column_name => $fk_value,
      protocol_id              => $protocol_id,
    };

    my $affy_array_protocol_id =
      $sbeams->updateOrInsertRow
      (    #add the affy array sample protocol data to the linking table
      table_name           => $linking_table_name,
      rowdata_ref          => $rowdata_ref,
      return_PK            => 1,
      verbose              => $VERBOSE,
      testonly             => $TESTONLY,
      insert               => 1,
      PK                   => $PK_COLUMN_NAME,
      add_audit_parameters => 1,
      );

  }
}


