#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_array_elements.pl
# Author      : Michael Johnson <mjohnson@systemsbiology.org>
#
# Description : This script loads the array elements from a map file
#               Note that there may be some cusomtization for
#               the particular library to populate gene_name and accesssion
#
##################################XF#############################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE $NOTES %OPTIONS $QUIET $VERBOSE $TESTONLY $DEBUG $DATABASE
             $current_contact_id $current_username $LAYOUT_ID $SPOT_NUMBER
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Inkjet::Settings;
use SBEAMS::Inkjet::Tables;
use SBEAMS::Inkjet::TableInfo;
$sbeams = SBEAMS::Connection->new();

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n          Set verbosity level.  default is 0
  --quiet              Set flag to print nothing at all except errors
  --debug n            Set debug flag
  --delete_existing    Delete the existing biosequences for this set before
                       loading.  Normally, if there are existing biosequences,
                       the load is blocked.
  --update_existing    Update the existing biosequence set with information
                       in the file
  --skip_sequence      If set, only the names, descs, etc. are loaded;
                       the actual sequence (often not really necessary)
                       is not written
  --layout_tag         The layout_tag of a array_layout that is to be worked
                       on; all are checked if none is provided
  --file_prefix        A prefix that is prepended to the set_path in the
                       biosequence_set table
  --check_status       Is set, nothing is actually done, but rather the
                       biosequence_sets are verified
  --testonly           If set, information in the db is not altered
  --biosequence_set_id Update only specific biosequence_set
  --notes              View notes on using this code (will exit afterwards)
EOU

$NOTES = <<EOU;;


########## NOTES ON USING load_array_elements.pl ###########
This script is used to load an array design (and its array elements)
into SBEAMS.  It is necessary to have biosequence set loaded.  This
is done through load_biosequence_set.pl. 

Examples:
For yeast:
./load_array_elements.pl --biosequence_set_id 3 --update_existing

For an individual array design:


EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
  "delete_existing","update_existing","skip_sequence",
  "layout_tag:s","check_status","testonly", "biosequence_set_id:s","notes")) {
  print "$USAGE";
  exit;
}

if ($OPTIONS{"notes"}){
    print "$NOTES";
    exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Try to determine which module we want to affect
  my $module = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ($module eq 'Proteomics') {
    $work_group = "${module}_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Biosap') {
    $work_group = "Biosap";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'SNP') {
    $work_group = "SNP";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Inkjet') {
    $work_group = "Inkjet_admin";
    $DATABASE = $DBPREFIX{$module};
  }


  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>$work_group,
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest { 
  my %args = @_;

  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);

  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"} || '';
  my $update_existing = $OPTIONS{"update_existing"} || '';
  my $skip_sequence   = $OPTIONS{"skip_sequence"}   || '';
  my $check_status    = $OPTIONS{"check_status"}    || '';
  my $layout_tag      = $OPTIONS{"layout_tag"}      || '';
  my $file_prefix     = $OPTIONS{"file_prefix"}     || '';
  my $bss_id = $OPTIONS{"biosequence_set_id"} || 0;

  #### Get the file_prefix if it was specified, and otherwise guess
  unless ($file_prefix) {
    my $module = $sbeams->getSBEAMS_SUBDIR();
    $file_prefix = '/net/dblocal/data/proteomics' if ($module eq 'Proteomics');
  }


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Define a scalar and array of biosequence_set_id's
  my ($array_layout_id, $n_array_layouts);
  my @array_layout_ids;

  #### If there was a layout_tag specified, ensure that it has layouts in the db
  if ($layout_tag) {
    $sql = qq~
          SELECT layout_id
            FROM ${DATABASE}array_layout
           WHERE name = '$layout_tag'
             AND record_status != 'D'
    ~;

    @array_layout_ids = $sbeams->selectOneColumn($sql);
    $n_array_layouts = @array_layout_ids;

    die "No array_layouts found with layout_tag = '$layout_tag'"
      if ($n_array_layouts < 1);
#    push (@array_layout_ids, $layout_tag);

  #### If there was NOT a layout_tag specified, scan for all available layouts
  } else {
    $sql = qq~
          SELECT layout_id
            FROM ${DATABASE}array_layout
           WHERE record_status != 'D'
    ~;

    if ($bss_id != 0) {
	$sql .= "AND biosequence_set_id = \'$bss_id\'";
    }else {
	$sql .= "AND biosequence_set_id != ''";
    }

    @array_layout_ids = $sbeams->selectOneColumn($sql);
    $n_array_layouts = @array_layout_ids;

    die "No array_layouts found in this database"
      if ($n_array_layouts < 1);

  }


  #### Loop over each biosequence_set, determining its status and processing
  #### it if desired
  print "          layout_tag      n_rows  file\n";
  print "--------------------  ----------  -----------------------------------\n";
  foreach $array_layout_id (@array_layout_ids) {
      $LAYOUT_ID = $array_layout_id;
      $SPOT_NUMBER = 1;
    my $status = getArrayLayoutStatus(
      array_layout_id => $array_layout_id
				      );
    printf("%20s  %10d  %s\n",$status->{name},$status->{n_rows},
      $status->{source_filename});

    #### If we're not just checking the status
    unless ($check_status) {
      my $do_load = 0;
      $do_load = 1 if ($status->{n_rows} == 0);
      $do_load = 1 if ($update_existing);
      $do_load = 1 if ($delete_existing);

      #### If it's determined that we need to do a load, do it
      if ($do_load) {
        $result = loadArrayLayout(
	   name=>$status->{name},
	   source_file=>$status->{source_filename}
	 );
      }
    }
  }

  return;

}



###############################################################################
# getArrayLayoutStatus
###############################################################################
sub getArrayLayoutStatus { 
  my %args = @_;
  my $SUB_NAME = 'getArrayLayoutStatus';


  #### Decode the argument list
  my $array_layout_id = $args{'array_layout_id'}
   || die "ERROR[$SUB_NAME]: array_layout_id not passed";

  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Get information about this array_layout_id from database
  $sql = qq~
          SELECT layout_id,name,data_file,source_filename
            FROM ${DATABASE}array_layout 
           WHERE layout_id = '$array_layout_id'
             AND record_status != 'D'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);


  #### Put the information in a hash
  my %status;
  $status{layout_id} = $rows[0]->[0];
  $status{name}      = $rows[0]->[1];
  $status{data_file} = $rows[0]->[2];
  $status{source_filename} = $rows[0]->[3];
 

  #### Get the number of rows for this biosequence_set_id from database
  $sql = qq~
          SELECT count(*) AS 'count'
            FROM ${DATABASE}array_element AE
           WHERE AE.layout_id = '$array_layout_id'
  ~;
  my ($n_rows) = $sbeams->selectOneColumn($sql);


  #### Put the information in a hash
  $status{n_rows} = $n_rows;


  #### Return information
  return \%status;

}
    

###############################################################################
# loadArrayLayout
###############################################################################
sub loadArrayLayout { 
  my %args = @_;
  my $SUB_NAME = 'loadArrayLayout';
  
  #### Decode the argument list
  my $set_name = $args{'name'}
   || die "ERROR[$SUB_NAME]: array_layout_id not passed";
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql, @rows);


  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"};
  my $update_existing = $OPTIONS{"update_existing"};
  my $skip_sequence   = $OPTIONS{"skip_sequence"};


  #### Verify the source_file
  unless ( -e "$source_file" ) {
    die("ERROR[$SUB_NAME]: Cannot find file $source_file");
  }

  #### Find out the layout_id and the biosequence_set_id
  $sql = qq~ 
      SELECT layout_id, biosequence_set_id
      FROM ${DATABASE}array_layout
      WHERE name = '$set_name'
      ~;
  #print "SQL: $sql\n";
  @rows = $sbeams->selectSeveralColumns($sql);
  my ($array_layout_id, $biosequence_set_id) = @{$rows[0]};
  
  #### Set the biosequence_set_id
#  $sql = "SELECT name, biosequence_set_id ".
#         " FROM ${DATABASE}array_layout";
#  my %sets = $sbeams->selectTwoColumnHash($sql);
#  my $biosequence_set_id = $sets{$set_name};
  
  unless($biosequence_set_id) {
      print "\n #### WARNING: No update performed for $set_name";
      print "\n #### REASON:  No biosequence_set specified\n";
      return;
  }
  #### If we didn't find it then bail
  unless ($array_layout_id) {
    bail_out("Unable to determine a biosequence_set_id for '$set_name'.  " .
      "A record for this biosequence_set must already have been entered " .
      "before the sequences may be loaded.");
  }


  #### Test if there are already sequences for this biosequence_set
  $sql = "SELECT COUNT(*) FROM ${DATABASE}array_element ".
         " WHERE layout_id = '$array_layout_id'";
  my ($count) = $sbeams->selectOneColumn($sql);
  if ($count) {
    if ($delete_existing) {
      print "Deleting...\n$sql\n";
      $sql = "DELETE FROM ${DATABASE}array_element ".
             " WHERE array_layout_id = '$array_layout_id'";
      $sbeams->executeSQL($sql);
    } elsif (!($update_existing)) {
      die("There are already biosequence records for this " .
        "array_layout.\nPlease delete those records before trying to load " .
        "new sequences,\nor specify the --delete_existing ".
        "or --update_existing flags.");
    }
  }


  #### Open file and  make sure file exists
  open(INFILE,"$source_file") || die "Unable to open $source_file";

  #### Load lookup hashes for biosequence
  $sql = "SELECT biosequence_gene_name, biosequence_id ".
         "FROM $TBIJ_BIOSEQUENCE ".
         "WHERE record_status !='D'".
         "  AND biosequence_set_id = $biosequence_set_id";
 
  #print "\n---biosequence ids---\n$sql\n";
  my (%biosequence_ids, %transform_map);

  %biosequence_ids = $sbeams->selectTwoColumnHash($sql);

  #### switch any .key files to .map files
  if ($source_file =~ /\.key/){
      $source_file =~ s/\.key/\.map/;
  }

  #### Define column map
  my ($biosequence_id_column,%column_map) = find_column_hash(source_file=>$source_file);

  #### Print hash for testing
  #my @keys = keys %column_map;
  #my @values = values %column_map;
  #while(@keys) {
  #    print (pop(@keys), '=', pop(@values), "\n");
  #}
   
  #print "\nbiosequence_id_column = $biosequence_id_column\n";
  #print "lookup '': ",$biosequence_ids{''},"\n";
  #while ( my ($key1,$value1) = each(%biosequence_ids)) {
  #  print "'$key1' = '$value1'\n";
  #}


  #### For tricky mappings, such as layout_id and spot_number
  #### use an absurdly high column number.  This will not work,if
  #### there are 1000 columns in the file
  %transform_map = (
     $biosequence_id_column => \%biosequence_ids,
     '1000'=> sub{return $LAYOUT_ID;},
     '1001'=> sub{return $SPOT_NUMBER++;}
   );

  my %update_keys = (
      'meta_row'   =>'0',
      'meta_column'=>'1',
      'rel_row'    =>'2',
      'rel_column' =>'3',
      'layout_id'  =>'1000',
     );


  #### Execute $sbeams->transferTable() to update contact table
  #### See ./update_driver_tables.pl
  if ($TESTONLY) {
      print "\n$TESTONLY- TEST ONLY MODE\n";
  }
  print "\nTransferring $source_file -> array_element";
  $sbeams->transferTable(
		 source_file=>$source_file,
		 delimiter=>'\t',
		 skip_lines=>'1',
		 dest_PK_name=>'element_id',
		 dest_conn=>$sbeams,
		 column_map_ref=>\%column_map,
		 transform_map_ref=>\%transform_map,
		 table_name=>$TBIJ_ARRAY_ELEMENT,
		 update=>1,
		 update_keys_ref=>\%update_keys,
		 verbose=>$VERBOSE,
		 testonly=>$TESTONLY,
		 );
  close(INFILE);
}


###############################################################################
# find_column_hash
###############################################################################
sub find_column_hash {
  my %args = @_;
  my $SUB_NAME = "find_column_hash";
  

  #### Decode the argument list
  my $source_file = $args{'source_file'} 
  || die "no source file passed in find_column_hash";
  
  #### Open file and  make sure file exists
  open(INFILE,"$source_file") || die "Unable to open $source_file";

  #### Check to make sure file is in the correct format
  my ($line,$element,%column_hash, @column_names);
  my $n_columns = 0;
  
  while ($n_columns < 4){
    $line = <INFILE>; 
    $line =~ s/[\r\n]//g;
    @column_names = split("\t", $line);
    $n_columns = @column_names;
  }
  close(INFILE);

  #### Go through the elements and see if they match a database field
  my $counter = 0;
  foreach $element (@column_names) {
    if ( $element =~ /^(meta|zone)\S?row/i ) {
	$column_hash{'meta_row'} = $counter;
    }
    elsif ( $element =~ /^(meta|zone)\S?col/i ) {
	$column_hash{'meta_column'} = $counter;
    }
    elsif ( $element =~ /^row$/i ) {
	$column_hash{'rel_row'} = $counter;
    }
    elsif ( $element =~ /^col$/i ) {
	$column_hash{'rel_column'} = $counter;
    }
    elsif ( $element =~ /384/i) {
	if ( $element =~ /plate/i) {
	    $column_hash{'w384_plate'} = $counter;
	}
	elsif ( $element =~ /row/i ) {
	    $column_hash{'w384_row'} = $counter;
	}
	elsif ( $element =~ /col/i ) {
	    $column_hash{'w384_column'} = $counter;
	}
    }
    elsif ( $element =~ /96/i ) {
	if ( $element =~ /plate/i ) {
	    $column_hash{'w96_plate'} = $counter;
	}
	elsif ( $element =~ /row/i ) {
	    $column_hash{'w96_row'} = $counter;
	}
	elsif ( $element =~ /col/i ) {
	    $column_hash{'w96_column'} = $counter;
	}
    }
    elsif ( $element =~ /orf|orf_name|^external_id$|accession/i ) {
	$column_hash{'biosequence_id'} = $counter;
    }
    elsif ( $element =~ /ref/i ) { 
	$column_hash{'reference'} = $counter;
    }
    $counter++;
  }

  #### Add column #1000 to deal with layout_id
  $column_hash{'layout_id'} = 1000;
  $column_hash{'spot_number'} = 1001;

  my $biosequence_column = $column_hash{'biosequence_id'};

  #### Invert the hash
  my %reverse_hash = reverse %column_hash;
  
  return ($biosequence_column, %reverse_hash);
}
