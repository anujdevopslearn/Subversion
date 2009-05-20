#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_solexatrans.pl
# Author      : Denise Mauldin <dmauldin@systemsbiology.org>
#
# Description : This script loads Solexa sequencing runs from SLIMseq into SBEAMS
#
###############################################################################
our $VERSION = '1.00';

=head1 NAME

load_solexatrans.pl - SLIMseq Solexa run loader


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

This script loads Solexa sequencing runs from SLIMseq into SBEAMS


=head2 EXPORT

Nothing


=head1 SEE ALSO

SBEAMS::SolexaTrans::Solexa;
SBEAMS::SolexaTrans::Solexa_file_groups;

SBEAMS::SolexaTrans::Settings; #contains the default file extensions and file path to find Solexa files of interest

=head1 AUTHOR

Denise Mauldin, E<lt>dmauldin@localdomainE<gt>

=cut

###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use warnings;
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
use vars qw ($sbeams $q $sbeams_solexa $utilities
  $PROG_NAME $USAGE %OPTIONS
  $VERBOSE $QUIET $DEBUG
  $DATABASE $TESTONLY
  $CURRENT_USERNAME
  $SBEAMS_SUBDIR
  $BASE_DIRECTORY
  @FILE_TYPES
  $SLIMSEQ_URI
  $SLIMSEQ_USER
  $SLIMSEQ_PASS
  $RUN_MODE
  %HOLD_COVERSION_VALS
  %data_to_find
  @BAD_PROJECTS
  $METHOD
  $UPDATE_RUN
  $DELETE_RUN
  $DELETE_BOTH
  $DELETE_ALL
);

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::SolexaTrans::Tables;

use SBEAMS::SolexaTrans::Solexa;
use SBEAMS::SolexaTrans::SolexaUtilities;

$sbeams = new SBEAMS::Connection;

$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$sbeams_solexa = new SBEAMS::SolexaTrans::Solexa;
$sbeams_solexa->setSBEAMS($sbeams);

$utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
$utilities->setSBEAMS($sbeams);

# Constants that represent access levels in the privilege table
use constant DATA_NONE => 50;
use constant DATA_READER => 40;
use constant DATA_WRITER => 30;
use constant DATA_GROUP_MOD => 25;
use constant DATA_MODIFIER => 20;
use constant DATA_ADMIN => 10;


#use CGI;
#$q = CGI->new();

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;

my @run_modes = qw(add_new update delete);

$USAGE = <<EOU;
$PROG_NAME is used to find and load Solexa runs into SBEAMS. 


Usage: $PROG_NAME --run_mode <add_new, update, delete>  [OPTIONS]
Options:
    --verbose <num>                           Set verbosity level.  Default is 0
    --quiet                                   Set flag to print nothing at all except errors
    --debug n                                 Set debug flag    
    --base_directory <file path>              Override the default directory to start
                                                searching for files
    --file_extension <space separated list>   Override the default File
                                                extensions to search for.
    --testonly                                Information in the database is not altered

Run Mode Notes:
 add_new : will only upload new files if the file_root name is unique
 
 update --method \<space separated list\>: 
 	Update run mode runs just like the add_new mode, parsing and gathering 
  information.  It will upload NEW files if it finds them, but if the root_file
  name has been previously set this method will update the data pointed to by
  the method flag
  
  Must provide a --method command line flag followed by a comma separated list
  of method names.  Data will be updated only for fields with a valid method 
  name always overriding the data in the database. See Solexa.pm for the names of
  the setters
  
  Will also accept run number(s) to specifically update instead of all the 
  runs.  Set the --run_id flag and give some ids comma separated.
 
 delete 

  --run <solexa_run_id> OR <root_file_name> Delete the run but LEAVES
    the sample, can be a comma separated list
  --both <solexa_run_id> OR <root_file_name>  Deletes the run and sample, can
    be a comma separated list
  --delete_all YES
    Removes all the samples and run information

Examples;

# typical mode, adds any new files
1) ./$PROG_NAME --run_mode add_new 			        

# will parse the sample tag information and stomp the data in the database 	  
# update will not change project permissions - use update_project_permission.pl or SBEAMS web interface
2) ./$PROG_NAME --run_mode update

# Delete the run with the file root given but LEAVES the sample
3) ./$PROG_NAME --run_mode delete -

# removes both the run and sample records
4) ./$PROG_NAME --run_mode delete 

#REMOVES ALL RUNS AND SAMPLES....Be careful
5) ./$PROG_NAME --run_mode delete --delete_all YES			

EOU

#### Process options
unless (
  GetOptions(
    \%OPTIONS,  "run_mode:s",       "verbose:i",    "quiet",
    "debug:i",  "run:s",          "both:s",       "delete_all:s",
    "method:s", "base_directory:s", "file_types:s", "testonly",
    "run_id:s", 
  )
  )
{
  print "$USAGE";
  exit;
}

$VERBOSE  = $OPTIONS{verbose} || 0;
$QUIET    = $OPTIONS{quiet};
$DEBUG    = $OPTIONS{debug} || 0;
$TESTONLY = $OPTIONS{testonly} || 0;
$RUN_MODE = $OPTIONS{run_mode};

$METHOD = $OPTIONS{method};

$UPDATE_RUN = $OPTIONS{run_ids};

$DELETE_RUN = $OPTIONS{run};
$DELETE_BOTH  = $OPTIONS{both};
$DELETE_ALL   = $OPTIONS{delete_all};

my $val = grep { $RUN_MODE eq $_ } @run_modes;

unless ($val) {
  print "\n*** Invalid or missing run_mode: $RUN_MODE ***\n\n $USAGE";
  exit;
}

#if ( $RUN_MODE eq 'update' )
#{    #if update mode check to see if --method <name> is set correctly
#  unless ( $METHOD =~ /^set/ || $METHOD =~ /^show/ ) {
#    print
#"\n*** Must provide a --method command line argument when updating data ***$USAGE\n";
#    exit;
#  }
#  check_setters($METHOD);
#}

##############################
##Setup a few global variables
if ( $OPTIONS{base_directory} ) {
  $BASE_DIRECTORY = $OPTIONS{base_directory};
}
else {
  $BASE_DIRECTORY =
    $sbeams_solexa->get_SOLEXA_DEFAULT_DIR()
    ;    #get method in SBEAMS::SolexaTrans::Settings.pm
}

if ( $OPTIONS{file_types} ) {
  @FILE_TYPES = split /\s+/, $OPTIONS{file_types};
}
else {
  @FILE_TYPES = $sbeams_solexa->get_SOLEXA_FILES();
}

$SLIMSEQ_URI =
  $sbeams_solexa->get_SLIMSEQ_URI()
  ;      #get method in SBEAMS::SolexaTrans::Settings.pm
$SLIMSEQ_USER =
  $sbeams_solexa->get_SLIMSEQ_USER()
  ;      #get method in SBEAMS::SolexaTrans::Settings.pm
$SLIMSEQ_PASS =
  $sbeams_solexa->get_SLIMSEQ_PASS()
  ;      #get method in SBEAMS::SolexaTrans::Settings.pm

############################

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  if ($QUIET) { print "  QUIET = $QUIET\n";} else { print "  QUIET NOT SET\n"; }
  print "  DEBUG = $DEBUG\n";
  print "  RUN_MODE = $RUN_MODE\n";
  print "  BASE_DIR = $BASE_DIRECTORY\n";
  print "  FILE_TYPES = @FILE_TYPES\n";
  if ($TESTONLY) { print "  TESTONLY = $OPTIONS{testonly}\n"; } else { print "  TESTONLY NOT SET\n"; }
  if ($METHOD) { print "  METHOD = $METHOD\n";} else { print "  METHOD NOT SET\n"; }
  print "  URI = $SLIMSEQ_URI\n";
  print "  USER = $SLIMSEQ_USER\n";
  print "  PASS = $SLIMSEQ_PASS\n";
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################
$utilities->base_dir($BASE_DIRECTORY);
$utilities->file_extension_names(@FILE_TYPES);
$utilities->verbose($VERBOSE);
$utilities->debug($DEBUG);
$utilities->testonly($TESTONLY);

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
  if ( $module eq 'SolexaTrans' ) {
#    $work_group = "SolexaTrans_admin";
    $work_group = 'Developer';
    $DATABASE   = $DBPREFIX{$module};
    print "DATABASE '$DATABASE'\n" if ($DEBUG);
  }

#### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ( $CURRENT_USERNAME =
    $sbeams->Authenticate( work_group => $work_group, ) );

## Presently, force module to be microarray and work_group to be SolexaTrans_admin  XXXXX what does this do and is it needed
  if ( $module ne 'SolexaTrans' ) {
    print
      "WARNING: Module was not SolexaTrans.  Resetting module to SolexaTrans\n";
    $work_group = "SolexaTrans_admin";
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

    print "Retrieving solexa information from SLIMseq\n";
    add_slimseq_information();
     
  }
  elsif ( $RUN_MODE eq 'delete' ) {
    unless ( $DELETE_RUN || $DELETE_BOTH || $DELETE_ALL ) {
      die
"*** Please provide command line arg --both or --run with a valid solexa run_id when attempting to delete data\n",
        "Or provide the command line arg --delete_all YES\n",
        "You provided '$DELETE_RUN' or '$DELETE_BOTH'\n ***\n$USAGE";
    }

    #delete_solexa_data();
  }
  else {
    die "This is not a valid run mode '$RUN_MODE'\n $USAGE";
  }

  print "Finished running load_solexatrans\n";
}

###############################################################################
#add_slimseq_information
#
#Parse information from SLIMseq and add to SolexaTrans
###############################################################################

sub add_slimseq_information {
  my $SUB_NAME = 'add_slimseq_information';

  print "Using SLIMseq URI: $SLIMSEQ_URI\n" if $VERBOSE > 0;

  my @project_summaries = request_summary_json('projects');

  foreach my $project_summary (@project_summaries) {
#    print "beginning transaction\n";
#    $sbeams->initiate_transaction();
    my $ERROR = '';  # error flag.  Used to escape from foreach loops if there's an error in the project.
    my $slimseq_project_id = $project_summary->{"id"};

    my %project = request_detailed_json("$SLIMSEQ_URI/projects/$slimseq_project_id");
    my @sample_uris = sort {$a cmp $b} @{$project{"sample_uris"}};
    my $project_tag = $project{"file_folder"};
    my $project_name = $project{"name"};
    if (!$project_tag) { 
      $project_tag = $project_name; 
      $project_tag =~ s/ /_/g;
      $project_tag =~ s/!-~//g;
    }
 
    my $sbeams_project_id = $utilities->check_sbeams_project(tag => $project_tag, name => $project_name);
    my @samples;   # cache samples so we don't have to request the JSON again
    foreach my $sample_uri (@sample_uris) {
      my %sample = request_detailed_json($sample_uri);
      push(@samples, \%sample);
    }     

    if (scalar(@samples) == 0) {
      print "No samples for current project, skipping insert\n";
      next;
    }

    # if there is no project we need to get the first sample from JSON
    # because the project doesn't contain user information in SLIMseq
    if (!$sbeams_project_id) {
	print "Adding project $project_name $project_tag\n" if $VERBOSE >= 10;
	my $cscnt = 0;
        my ($first_name, $last_name);
	while (!$first_name && !$last_name) {
	  if ($cscnt >= scalar(@samples)) { 
#	    $ERROR = 'ERROR: Can\'t find a user to assign this project to - '.$project_name;
#            last;
	     $first_name = 'Bruz';
             $last_name = 'Marzolf';
             print "WARNING: SETTING OWNER FOR PROJECT $project_name TO Bruz Marzolf\n";
          }
          my %sample = %{$samples[$cscnt]};
          my $username = $sample{"submitted_by"};
          ($first_name, $last_name) = split(/\s+/, $username) if $username;
	  $cscnt++;
	}

	if ($ERROR) {
          print "ERROR WITH PROJECT - $project_name.  Project information not added.\n";
          print $ERROR."\n";
#          $sbeams->
	  next;
	}

        print "Project $project_name assigned to $first_name $last_name\n" if ($VERBOSE >= 10);
        my $contact_id = $utilities->check_sbeams_user("first_name" => $first_name, "last_name" => $last_name);
	if ($contact_id == 0) {
          print "Inserting a new user $first_name $last_name\n" if ($VERBOSE >0);
          # no user in SBEAMS, so collect data to create a SBEAMS user - already have first name and last name
	  # so we need to collect lab memberships and username
          # Since we can't look up the user by the name, only the ID, we have to parse through all the 
          # summaries until we find the user_id that matches the name we have
	  my @user_summaries = request_summary_json('users');
	  my $user_found = 0;  # flag used to exit the summary loop when we've found our match
          foreach my $user_summary (@user_summaries) {
	    if ($user_found == 1) { last; }
	    my %user = request_detailed_json($user_summary->{"uri"});
            if ($first_name eq $user{"firstname"} && $last_name eq $user{"lastname"}) {
	      $user_found = 1;
	      my $slimseq_user_id = $user_summary->{"id"};
              my $username = $user_summary->{"login"};

              # find the lab group for the user and the group for the user
              # labs are defined as having 'Lab' in the name
              # all others are groups
              # labs go into the lab_id field in contact
              # groups go into the group_id field in contact
              # both of these fields link to the organization table
              # if the organization does not exist in SBEAMS then it warns and does not add
              # THIS DOES NOT DO ANYTHING WITH 'work_group', ONLY FILLS IN FIELDS IN 'contact'
              my $lab_group_uris = $user{"lab_group_uris"};
              my ($sbeams_lab_id, $sbeams_group_id);
              my %work_groups = ('solexatrans_user' => DATA_READER); # base read access
              foreach my $lab_uri (@$lab_group_uris) {
                my %lab = request_detailed_json("$lab_uri");

                # check the organization table so we can fill in contacts information
		my $sbeams_organization_id = $utilities->check_sbeams_organization("name" => $lab{"name"});
                if ($sbeams_organization_id) {
                  if ($lab{"name"} =~ /[Ll]ab/) {
                    print "Assigning SLIMseq group membership ".$lab{"name"}.
                          " to lab_id $sbeams_organization_id\n" if ($VERBOSE >= 10);
                    if ($sbeams_lab_id && $sbeams_lab_id != $sbeams_organization_id) { 
                       print "WARN: Overwriting sbeams_lab_id - ".
                             "$username old id $sbeams_lab_id new id $sbeams_organization_id\n" if ($VERBOSE > 0 && !$QUIET);
                    }
                    $sbeams_lab_id = $sbeams_organization_id;
                  } else {
                    print "Assigning SLIMseq group membership ".$lab{"name"}.
                          " to group_id $sbeams_organization_id\n" if ($VERBOSE >= 10);
                    if ($sbeams_group_id && $sbeams_group_id != $sbeams_organization_id) { 
                       print "WARN: Overwriting sbeams_group_id - username $username old group id ".
                             "$sbeams_group_id new organization id $sbeams_organization_id\n" if ($VERBOSE > 0 && !$QUIET);
                    }
                    $sbeams_group_id = $sbeams_organization_id;
                  }
                } else {
                  print "WARN: No organization id found for ".$lab{"name"}.".  ".
                        "Not adding this information to the SBEAMS user creation. ".
                        "If this user has additional lab groups in SLIMseq, user may ".
                        "still have a lab_id or group_id assigned.\n" if ($VERBOSE > 0 && !$QUIET);
                } # end if sbeams_organization_id

                # check the work_group table so we can add an appropriate entry to user_work_group
                my $sbeams_wg_id = $utilities->check_sbeams_work_group("name" => $lab{"name"});
                if ($sbeams_wg_id) {
#                  $work_groups{$sbeams_wg_id} = DATA_WRITER;  
                  $work_groups{$lab{"name"}} = DATA_WRITER;
                } else {
                  print "WARNING: Could not find group for ".$lab{"name"}." - an admin must add this".
                        " group to the work_group table in SBEAMS and then add user $first_name $last_name ".
                        " to the group manually.\n";
                } # end if sbeams_wg_id

              } # end foreach lab_uri
              $sbeams_lab_id = 'NULL' if !$sbeams_lab_id;
              $sbeams_group_id = 'NULL' if !$sbeams_group_id;

	      print "Adding CONTACT $first_name, $last_name, $username " if $VERBOSE;
	      print "in lab $sbeams_lab_id " if $sbeams_lab_id ne 'NULL' && $VERBOSE;
              print "in group $sbeams_group_id " if $sbeams_group_id ne 'NULL' && $VERBOSE;
              print "to SBEAMS with work_groups \n" if $VERBOSE;
              foreach my $key (keys %work_groups) {
                 print "wg $key priv $work_groups{$key}\n" if $VERBOSE;
              }
              print "\n" if $VERBOSE;

	      $contact_id = $sbeams->addUserAndGroups("first_name" => $first_name,
						 "last_name"  => $last_name,
						 "username"   => $username,
                                                 "lab_id"     => $sbeams_lab_id,
                                                 "group_id"   => $sbeams_group_id,
                                                 "work_groups" => \%work_groups
						 ) ;

	      if (!$contact_id) { 
                 if ($TESTONLY) { $contact_id = 682; } 
                 else { die "No contact_id created for user $first_name $last_name in SBEAMS\n"; } 
              }
            } # end found matching user in the JSON
          }
        } # end create user

        print "Adding a new project $project_name tag $project_tag\n" if ($VERBOSE >=20);
	# insert the project
	$sbeams_project_id = $utilities->insert_project("name" => $project_name, 
                                                        "tag" => $project_tag, 
                                                        "contact_id" => $contact_id);

        print "sbeams project id is now $sbeams_project_id for name $project_name tag $project_tag\n" if ($VERBOSE >= 20);

	# now need to set permissions for the new project
	my $project_lab_group_uri = $project{"lab_group_uri"};
        my %project_lab_group = request_detailed_json($project_lab_group_uri);
        my $project_lab_name = $project_lab_group{"name"};
        # find the work_group in SBEAMS that corresponds to this lab group in SLIMseq
        my $sbeams_wg_id = $utilities->check_sbeams_work_group("name" => $project_lab_name);
        if ($sbeams_wg_id) {
          my $sbeams_gpp_id = $utilities->check_sbeams_group_project_permission("work_group_id" => $sbeams_wg_id,
                                                                          "project_id" => $sbeams_project_id);
          if (!$sbeams_gpp_id) {
            print "Creating link between project $sbeams_project_id and work_group $sbeams_wg_id in ".
                  "the group_project_permissions table\n" if $VERBOSE > 10;

            $sbeams->update_group_permissions("project_id" => $sbeams_project_id,
		                              "ref_parameters" => {"groupName0" => $sbeams_wg_id,
                                              "groupPriv0" => '25'},
                                              testonly => $TESTONLY
                                              );

            $sbeams_gpp_id = $utilities->check_sbeams_group_project_permission("work_group_id" => $sbeams_wg_id,
                                                                               "project_id" => $sbeams_project_id);

            if ($TESTONLY) { $sbeams_gpp_id = int(rand(1000)); }
            die "Something went wrong in adding group permission for workgroup $sbeams_wg_id to ".
                "project $sbeams_project_id in solexatrans\n" unless $sbeams_gpp_id;

          }
        
          # check that solexatrans_admin is permitted - this may need a flag to enable/disable
          # or it may need to be commented out based on user desires - allows solexatrans_admin
          # to read all solexatrans projects
          my $sbeams_stwg_id = $utilities->check_sbeams_work_group("name" => 'solexatrans_admin');
          if ($sbeams_stwg_id) {
            my $sbeams_stgpp_id = $utilities->check_sbeams_group_project_permission("work_group_id" => $sbeams_stwg_id,
                                                                                    "project_id" => $sbeams_project_id);
            if (!$sbeams_stgpp_id) {
              print "Creating link between project $sbeams_project_id and solexatrans_admin work_group $sbeams_stwg_id".
                    " in the group_project_permissions table\n" if $VERBOSE > 10;

              $sbeams->update_group_permissions("project_id" => $sbeams_project_id,
                                                "ref_parameters" => {"groupName0" => $sbeams_stwg_id,
                                                "groupPriv0" => '40'},
                                                testonly => $TESTONLY);

              $sbeams_stgpp_id = $utilities->check_sbeams_group_project_permission("work_group_id" => $sbeams_stwg_id,
                                                                                   "project_id" => $sbeams_project_id);

              if ($TESTONLY) { $sbeams_stgpp_id = int(rand(1000)); }
              die "Something went wrong in adding group permission for workgroup $sbeams_stwg_id to ".
                  "project $sbeams_project_id in solexatrans\n" unless $sbeams_stgpp_id;

            }
         }

        } else {  # can't find a sbeams work_group_id
          print "WARNING: Could not find group for $project_lab_name - an admin must add this".
          " group to the work_group table in SBEAMS and then add an entry into the group_project_permission ".
          " table in SBEAMS for project id $sbeams_project_id. It is likely that there is also an accompanying ".
          " error above that indicates that a user could not be added to this work group as well.\n";
       } # end if sbeams_wg_id

    } # end insert project
     elsif ($RUN_MODE eq 'update') {
          print "Updating project ".$project_name."\n" if ($VERBOSE >=20);

          my %project = ( 
                          'name' => $project_name,
                          'project_tag' => $project_tag
                        );


          update_database('TABLE_NAME' => 'project',
                          'ID' => $sbeams_project_id,
                          'PARAMS' => \%project
                          );
    } # end update project


    # so now we have inserted the project and need to continue down the JSON entry to insert samples
    foreach my $sampleRef (@samples) {
      my %sample = %$sampleRef;
      print "Processing Sample ".$sample{"sample_description"}." with slimseq_sample_id ".$sample{"id"}."\n" if $VERBOSE > 0;
      my $flow_cell_lane_uris = $sample{"flow_cell_lane_uris"};
      my $num_flow_cell_lanes = scalar @$flow_cell_lane_uris;
      # IF THE SAMPLE DOES NOT HAVE ANY FLOW_CELL_LANES THEN WE DON'T WANT TO INSERT IT
      print "Skipping sample with SLIMseq id ".$sample{id}." and description ".$sample{"sample_description"}.
            " because it does not have any flow cell lanes (no Solexa Samples have been run)\n" if $num_flow_cell_lanes < 1;
      next unless $num_flow_cell_lanes > 0;

      # CHECK to see if sample is in the database
      my $sbeams_sample_id = $utilities->check_sbeams_sample("slimseq_id" => $sample{"id"});

      if (!$sbeams_sample_id) {
	# COLLECT INFORMATION FOR INSERTING A SAMPLE

       	# organism information
        my $sbeams_org_id = $utilities->check_sbeams_organism("name" => $sample{"reference_genome"}->{"organism"});
	die "Cannot find an sbeams_org_id for organism ".$sample{"reference_genome"}->{"organism"}." in SBEAMS\n" 
	    unless $sbeams_org_id;
        print "Found SBEAMS organism id $sbeams_org_id for organism ".$sample{"reference_genome"}->{"organism"}."\n"
            if ($VERBOSE >= 20);

	# sample prep kit information
	my $sample_prep_kit_uri = $sample{"sample_prep_kit_uri"};
	# spk = sample_prep_kit
        my ($slimseq_spk_id) = $sample_prep_kit_uri =~ /\/(\d+)$/;
        print "Checking for slimseq sample prep kit id $slimseq_spk_id from uri $sample_prep_kit_uri\n" if $VERBOSE > 20;
	# check for this kit in sbeams
	my $sbeams_spk_id = $utilities->check_sbeams_sample_prep_kit("slimseq_sample_prep_kit_id" => $slimseq_spk_id);
     
        print "Found SBEAMS sample prep kit id - $sbeams_spk_id\n" if $VERBOSE >=20; 
        # INSERT a new spk into SBEAMS - need enzyme name and motif
	# many methods do not use a restriction_enzyme, so undef has to be acceptable.
	unless ($sbeams_spk_id) {
	  my %slimseq_spk = request_detailed_json("$sample_prep_kit_uri");
          print "Adding a new Sample Prep Kit ".$slimseq_spk{"name"}."\n" if ($VERBOSE >=20);
         
          $sbeams_spk_id = $utilities->insert_sample_prep_kit("slimseq_spk_id" => $slimseq_spk_id,
							      "name" => $slimseq_spk{"name"},
							      "restriction_enzyme" => $slimseq_spk{"restriction_enzyme"},
							     );
          die "Cannot insert a sample_prep_kit into solexatrans with SLIMseq ID $slimseq_spk_id\n" if !$sbeams_spk_id;
          print "Finished inserting Sample Prep Kit with id $sbeams_spk_id\n" if $VERBOSE > 0;
        } # end insert spk

        # reference genome information
        my $rg_name = $sample{"reference_genome"}->{"name"};

        my $sbeams_rg_id = $utilities->check_sbeams_reference_genome("name" => $rg_name, "org_id" => $sbeams_org_id);
        print "Found SBEAMS reference genome id $sbeams_rg_id\n" if $VERBOSE >=20;

        # INSERT a new reference genome into SBEAMS
        unless ($sbeams_rg_id) {
          print "Adding a new Reference Genome - $rg_name organism_id $sbeams_org_id\n" if ($VERBOSE > 0);
          $sbeams_rg_id = $utilities->insert_reference_genome("name" => $rg_name, "org_id" => $sbeams_org_id); 
          die "$sbeams_rg_id" if ($sbeams_rg_id =~ /ERROR/);
        }

        print "Adding a new Sample - ".$sample{"sample_description"}." with tag ".$sample{"name_on_tube"}. 
              " in project $sbeams_project_id\n" if ($VERBOSE >=20);
	# INSERT SAMPLE WITH COLLECTED INFO
        $sbeams_sample_id = $utilities->insert_sample(%sample, 
                                                      "slimseq_project_id" => $slimseq_project_id,
                                                      "sbeams_project_id" => $sbeams_project_id,
						      "sbeams_organism_id" => $sbeams_org_id,
						      "solexa_spk_id" => $sbeams_spk_id,
						      "solexa_reference_genome_id" => $sbeams_rg_id,
						     );
        print "Finished inserting sample ".$sample{"sample_description"}." in SBEAMS - got sbeams_sample_id ".
              $sbeams_sample_id." from SBEAMS database\n" if $VERBOSE >= 20;
      } # end insert sample
        elsif ($sbeams_sample_id && $RUN_MODE eq 'update') {
          print "Updating sample ".$sample{"id"}."\n" if ($VERBOSE >=20);

          # map slimseq keys to sbeams keys
          # sample_tag = name_on_tube
          # full_sample_name = sample_description
          $sample{'sample_tag'} = $sample{'name_on_tube'};
          $sample{'full_sample_name'} = $sample{'sample_description'};
          $sample{'slimseq_sample_id'} = $sample{'id'};
          delete $sample{'id'};
          delete $sample{'name_on_tube'};
          delete $sample{'sample_description'};
          $sample{'comment'} = 'This record was automatically updated based on a SLIMseq record by LoadSolexa.';

          update_database('TABLE_NAME' => "ST_SOLEXA_SAMPLE",
                          'ID' => $sbeams_sample_id,
                          'PARAMS' => \%sample
                          );
      } # end update sample


      foreach my $flow_cell_lane_uri (@$flow_cell_lane_uris) {  # go through all flow cells lanes
        my %flow_cell_lane = request_detailed_json("$flow_cell_lane_uri");
        print "Checking flow cell lane ".$flow_cell_lane{"id"}."\n" if $VERBOSE > 0;
        print "Skipping flow cell lane ".$flow_cell_lane{"id"}." because it does not have a raw_data path ".
              "and therefore the Solexa run has not finished\n" if ($VERBOSE > 0 && !$flow_cell_lane{"raw_data_path"});
        next unless $flow_cell_lane{"raw_data_path"};

        # to insert a flow_cell_lane, check if flow_cell is in database
        my ($slimseq_flow_cell_id) = ($flow_cell_lane{"flow_cell_uri"} =~ /.*\/(.*)/);
	print "Checking for SLIMseq flow cell $slimseq_flow_cell_id in SBEAMS\n" if $VERBOSE >= 20;
        my $sbeams_fc_id = $utilities->check_sbeams_flow_cell("slimseq_fc_id" => $slimseq_flow_cell_id);
        print "Found SBEAMS flow cell id $sbeams_fc_id for SLIMseq flow cell id $slimseq_flow_cell_id\n" 
		if ($VERBOSE >=20 && $sbeams_fc_id);

        # if not found, insert a flow cell
        my %flow_cell = request_detailed_json($flow_cell_lane{"flow_cell_uri"});
        if (!$sbeams_fc_id) { 
          print "Adding a new Flow Cell - ".$flow_cell{"name"}."\n" if ($VERBOSE >=20);
          $sbeams_fc_id = $utilities->insert_flow_cell(%flow_cell);
          die $sbeams_fc_id if $sbeams_fc_id =~ /ERROR/;
        } elsif ($sbeams_fc_id && $RUN_MODE eq 'update') {
          print "Updating Flow Cell - ".$flow_cell{"name"}."\n" if ($VERBOSE >= 20);
          update_database('TABLE_NAME' => "ST_SOLEXA_FLOW_CELL",
                          'ID' => $flow_cell{"id"},
                          'PARAMS' => \%flow_cell
                        );
        }

        #check for the instrument
        my ($slimseq_instrument_id) = ($flow_cell{"sequencer_uri"} =~ /.*\/(.*)/);
        my $sbeams_instrument_id = $utilities->check_sbeams_instrument("slimseq_instrument_id" => $slimseq_instrument_id);

        # if not found add an instrument
        my %instrument = request_detailed_json($flow_cell{"sequencer_uri"});
        if (!$sbeams_instrument_id) {
          print "Adding a new Instrument - ".$instrument{"name"}."\n" if ($VERBOSE >=20);
          $sbeams_instrument_id = $utilities->insert_instrument(%instrument);
          die "$sbeams_instrument_id" if ($sbeams_instrument_id =~ /ERROR/);
        } elsif ($sbeams_instrument_id && $RUN_MODE eq 'update') {
          print "Updating Instrument - ".$instrument{"name"}."\n" if ($VERBOSE >= 20);
          update_database('TABLE_NAME' => "ST_SOLEXA_INSTRUMENT",
                          'ID' => $instrument{"id"},
                          'PARAMS' => \%instrument
                          );
        }
       
        #check for a run that connects the instrument to the flow cell 
        # this table exists in the SLIMseq database - sequencing_runs, but is not exposed
        # therefore we have no SLIMseq ID to enter in this table and we check for the 
        # combination of flow cell and instrument to make the link
        my $sbeams_run_id = $utilities->check_sbeams_solexa_run("sbeams_fc_id" => $sbeams_fc_id,
                                                                "sbeams_instrument_id" => $sbeams_instrument_id);
        # if not found add a link table entry in solexa_run
        if (!$sbeams_run_id) {
          print "Adding a new Solexa Run entry with flow cell $sbeams_fc_id and instrument ".
                "$sbeams_instrument_id\n" if $VERBOSE > 0;
          $sbeams_run_id = $utilities->insert_solexa_run("sbeams_fc_id" => $sbeams_fc_id,
                                                         "sbeams_instrument_id" => $sbeams_instrument_id);
          die "$sbeams_run_id" if ($sbeams_run_id =~ /ERROR/);
        }

        # fcl = flow_cell_lane 
        my $slimseq_fcl_id = $flow_cell_lane{"id"};

        my $sbeams_fcl_id = $utilities->check_sbeams_flow_cell_lane("slimseq_fcl_id" => $slimseq_fcl_id);
        print "Found SBEAMS flow cell lane id $sbeams_fcl_id for SLIMseq fcl id $slimseq_fcl_id\n" 
               if ($VERBOSE > 20 && $sbeams_fcl_id);

        # insert a flow cell lane if we need to
        if (!$sbeams_fcl_id) { 
          print "Adding a new Solexa Flow Cell Lane entry with id ".$flow_cell_lane{"id"}."\n" if $VERBOSE > 0;
          print "sbeams_fc_id is $sbeams_fc_id flow cell lane is \n";
          $sbeams_fcl_id = $utilities->insert_flow_cell_lane(%flow_cell_lane,
                                                             "sbeams_fc_id" => $sbeams_fc_id);
          die "$sbeams_fcl_id" if ($sbeams_fcl_id =~ /ERROR/);
        } elsif ($sbeams_fcl_id && $RUN_MODE eq 'update') {
          print "Updating Solexa Flow Cell Lane - ".$flow_cell_lane{"id"}."\n" if $VERBOSE >= 20;
          update_database('TABLE_NAME' => "ST_SOLEXA_FLOW_CELL_LANE",
                          'ID' => $sbeams_fcl_id,
                          'PARAMS' => \%flow_cell_lane
                        );
        }

        print "checking flow cell lane to sample\n" if $VERBOSE > 0;
        # need to connect the flow cell lane with the sample
        my ($sbeams_fcl_to_sample_sample_id, $sbeams_fcl_to_sample_fcl_id) = 
                $utilities->check_sbeams_flow_cell_lane_to_sample("sbeams_fcl_id" => $sbeams_fcl_id,
                                                                  "sbeams_sample_id" => $sbeams_sample_id);

        print "Found flow_cell_lane_to_sample entries: $sbeams_fcl_to_sample_sample_id $sbeams_fcl_to_sample_fcl_id\n" if $VERBOSE > 0;
        # insert a linker table entry
        if (!$sbeams_fcl_to_sample_sample_id && !$sbeams_fcl_to_sample_fcl_id) {
           print "Adding a new Flow Cell Lane Samples (Linker table) entry for Flow Cell Lane $sbeams_fcl_id ".
                 " and Sample ID $sbeams_sample_id\n" if $VERBOSE > 0;
           ($sbeams_fcl_to_sample_sample_id, $sbeams_fcl_to_sample_fcl_id) = 
                $utilities->insert_flow_cell_lane_to_sample("sbeams_fcl_id" => $sbeams_fcl_id,
                                                            "sbeams_sample_id" => $sbeams_sample_id,
                                                            );

           die "$sbeams_fcl_to_sample_sample_id" if ($sbeams_fcl_to_sample_sample_id =~ /ERROR/); 
        }


        # GET READY TO INSERT A SPR ENTRY

    #ELAND
        my $eland_output_file_id = $utilities->check_sbeams_file_path("file_path" => $flow_cell_lane{"eland_output_file"});
        print "Found SBEAMS ELAND output file id $eland_output_file_id for file ".$flow_cell_lane{"eland_output_file"}."\n" 
            if $eland_output_file_id && $VERBOSE > 20;

        if (!$eland_output_file_id) {
          print "Adding a new ELAND output file entry for Flow Cell Lane $sbeams_fcl_id ".
                 " and Sample ID $sbeams_sample_id\n" if $VERBOSE > 0;
          # Server names are entered via the POPULATE SQL file at database creation.
          # RUNE is where /solexa mounts are from as of 02/01/2009.
          # Somewhat of an artifical construct since /solexa should be available from all ISB machines.
          # If this information is incorrect, edit this and also edit /sql/SolexaTrans/SolexaTrans_POPULATE.sql
          my $eland_server_id = $utilities->check_sbeams_server("server_name" => "RUNE");
          if ($eland_server_id =~ /ERROR/) { die $eland_server_id; }
          $eland_output_file_id = $utilities->insert_file_path("file_path" => $flow_cell_lane{"eland_output_file"},
                                                          "file_path_name" => 'ELAND output file',
                                                          "file_path_desc" => '',
                                                          "server_id" => $eland_server_id);
          if ($eland_output_file_id =~ /ERROR/) { die $eland_output_file_id; }
        }

        my $summary_file_id = $utilities->check_sbeams_file_path("file_path" => $flow_cell_lane{"summary_file"});
        print "Found SBEAMS summary file id $summary_file_id for file ".$flow_cell_lane{"summary_file"}."\n" if $summary_file_id && $VERBOSE > 20;

        if (!$summary_file_id) {
           print "Adding a new Summary file entry for Flow Cell Lane $sbeams_fcl_id ".
                 " and Sample ID $sbeams_sample_id\n" if $VERBOSE > 0;
          # Server names are entered via the POPULATE SQL file at database creation.
          # RUNE is where /solexa mounts are from as of 02/01/2009.
          # Somewhat of an artifical construct since /solexa should be available from all ISB machines.
          # If this information is incorrect, edit this and also edit /sql/SolexaTrans/SolexaTrans_POPULATE.sql
          my $summary_server_id = $utilities->check_sbeams_server("server_name" => "RUNE");
          if ($summary_server_id =~ /ERROR/) { die $summary_server_id; }
          $summary_file_id = $utilities->insert_file_path("file_path" => $flow_cell_lane{"summary_file"},
                                                          "file_path_name" => 'Solexa Pipeline Summary file',
                                                          "file_path_desc" => '',
                                                          "server_id" => $summary_server_id);
          if ($summary_file_id =~ /ERROR/) { die $summary_file_id; }
        }

        my $raw_data_id = $utilities->check_sbeams_file_path("file_path" => $flow_cell_lane{"raw_data_path"});
        print "Found SBEAMS raw data path id $raw_data_id for file ".$flow_cell_lane{"raw_data_path"}."\n" if $raw_data_id && $VERBOSE > 20;

        if (!$raw_data_id) {
           print "Adding a new Raw Data path entry for Flow Cell Lane $sbeams_fcl_id ".
                 " and Sample ID $sbeams_sample_id\n" if $VERBOSE > 0;
          # Server names are entered via the POPULATE SQL file at database creation.
          # RUNE is where /solexa mounts are from as of 02/01/2009.
          # Somewhat of an artifical construct since /solexa should be available from all ISB machines.
          # If this information is incorrect, edit this and also edit /sql/SolexaTrans/SolexaTrans_POPULATE.sql
          my $raw_data_server_id = $utilities->check_sbeams_server("server_name" => "RUNE");
          if ($raw_data_server_id =~ /ERROR/) { die $raw_data_server_id; }
          $raw_data_id = $utilities->insert_file_path("file_path" => $flow_cell_lane{"raw_data_path"},
                                                          "file_path_name" => 'Path to Solexa Pipeline Raw Data',
                                                          "file_path_desc" => '',
                                                          "server_id" => $raw_data_server_id);
          if ($raw_data_id =~ /ERROR/) { die $raw_data_id; }
        }

        print "Checking for SBEAMS pipeline results id\n" if $VERBOSE > 20;
        my $sbeams_spr_id = $utilities->check_sbeams_pipeline_results("sbeams_fcl_id" => $sbeams_fcl_id,
                                                                     "eland_output_file_id" => $eland_output_file_id,
                                                                     "summary_file_id" => $summary_file_id,
                                                                     "raw_data_path_id" => $raw_data_id
                                                                    );

        # 'Delete' old SPR entries.  This currently works because the SLIMSeq interface only displays
        # the most current SPR entry.
        #THIS SHOULD BE CHANGED IF SLIMSEQ GETS CHANGED TO DISPLAY MORE THAN ONE PIPELINE RESULT
        # get all SPRs for the current flow cell
        my $spr_ref = $utilities->get_sbeams_spr_by_flow_cell_lane("sbeams_fcl_id" => $sbeams_fcl_id);

        foreach my $spr_entry (@$spr_ref) {
          my $spr_id = $spr_entry->[0];
          if ($sbeams_spr_id) {
            # if there's a current spr id then make sure not to delete that entry
            if ($spr_id != $sbeams_spr_id) {
              print "'Deleting' Solexa Pipeline Results entry with id $spr_id since the current entry is $sbeams_spr_id\n";
              my $rc = $utilities->delete_sbeams_spr('solexa_pipeline_results_id' => $spr_id);
              if ($rc =~ /ERROR/) { die $rc; }
            }
          } else {
            print "'Deleting' Solexa Pipeline Results entry with id $spr_id since a new entry has to be created.\n";
            my $rc = $utilities->delete_sbeams_spr('solexa_pipeline_results_id' => $spr_id);
            if ($rc =~ /ERROR/) { die $rc; }
          } 
        }

        if (!$sbeams_spr_id) {
          print "Adding a new Pipeline Results entry for Flow Cell Lane $sbeams_fcl_id ".
                " and Sample ID $sbeams_sample_id\n" if $VERBOSE > 0;

          # have to remove the time zone component of the datetime 2008/12/18 10:29:40 -0800
          my $full_updated_at = $flow_cell_lane{"updated_at"};
          my @date_components = split(/\s+/, $full_updated_at);
          pop(@date_components);
          my $slimseq_updated_at = join(" ", @date_components);
          $sbeams_spr_id = $utilities->insert_pipeline_results("sbeams_fcl_id" => $sbeams_fcl_id,
                                                                "eland_output_file_id" => $eland_output_file_id,
                                                                "summary_file_id" => $summary_file_id,
                                                                "raw_data_path_id" => $raw_data_id,
								"slimseq_updated_at" => $slimseq_updated_at,
                                                                "slimseq_status" => $flow_cell_lane{"status"}
                                                                );
          if ($sbeams_spr_id =~ /ERROR/) { die $sbeams_spr_id; }
        }


      } # end foreach flow_cell_lane_uri

    } # end sample
#    print "committing transcation\n";
#    $sbeams->commit_transaction();
  } # end project
}


###############################################################################
#request_summary_json
#
#Request the summary JSON from SLIMseq
###############################################################################

sub request_summary_json {
  my $resource = shift;
  my $browser = new LWP::UserAgent( keep_alive => 1 );

  my $url = "$SLIMSEQ_URI/".$resource;
  print "Requesting Summary $url\n" if $VERBOSE > 0;
  my $request = HTTP::Request->new( GET => $url );
  $request->authorization_basic( $SLIMSEQ_USER, $SLIMSEQ_PASS );
  $request->content_type('application/json');

  my $response = $browser->request($request);
  die "Summary JSON request failed: $url\n" if ($response->is_error);
 

  #print $response->as_string, "\n";
  print "Summary JSON: ", $response->content, "\n" if $VERBOSE > 100;

  #print $response->status_line;
  my $json = new JSON;
  my $run_summaries_scalar = $json->decode( $response->content );

  return @{$run_summaries_scalar};
}

###############################################################################
#request_detailed_json
#
#Request the detailed JSON from SLIMseq
###############################################################################

sub request_detailed_json {
  my $uri = shift @_;

  print "Requesting Detailed URI: $uri\n" if $VERBOSE > 0;

  my $browser = new LWP::UserAgent( keep_alive => 1 );

  my $request = HTTP::Request->new( GET => $uri );
  $request->authorization_basic( $SLIMSEQ_USER, $SLIMSEQ_PASS );
  $request->content_type('application/json');

  my $response = $browser->request($request);
  die "Detail JSON request failed: $uri\n" if ($response->is_error);

  #print $response->as_string, "\n";
  print "Detail JSON: ", $response->content, "\n" if $VERBOSE > 100;

  #print $response->status_line;

  my $json = new JSON;
  my $detail_scalar = $json->decode( $response->content );

  return %{$detail_scalar};
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
  		FROM $TBST_FILE_PATH
  		WHERE file_path like '$basepath'
  	   ~;

  my @rows = $sbeams->selectOneColumn($sql);
  if (@rows) {
    $HOLD_COVERSION_VALS{BASE_PATH}{$basepath} = $rows[0];
    return $rows[0];    #return the file_path.file_path_id
  }

  unless (@rows) {

    my $rowdata_ref = {
      file_path_name => 'Path to Solexa Run Data'
      ,                 #if the base path has not been seen insert a new record
      file_path => $basepath,
      server_id => 1,           #hack to default to server id 1.  FIX ME
    };

    if ( $DEBUG > 0 ) {
      print "SQL DATA\n";
      print Dumper($rowdata_ref);
    }
    my $file_path_id = $sbeams->updateOrInsertRow(
      table_name           => $TBST_FILE_PATH,
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
# get_organization_id	
# 
# given the user_login_id get the organization id
###############################################################################
sub get_organization_id {
  my $SUB_NAME = 'get_organization_id';

  my %args = @_;
  
  my $user_login_id = $args{'user_login_id'};
  
  return unless ($user_login_id =~ /^\d+$/);
  
  if (exists $HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id}) {			#if the user_id has been seen before return the org_id
  
  	return $HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id};
  	
  }
  
  my $sql = qq~ 	
		SELECT o.organization_id, organization 
  		FROM $TB_ORGANIZATION o, $TB_CONTACT c, $TB_USER_LOGIN ul
  		WHERE ul.user_login_id = $user_login_id AND
  		ul.contact_id = c.contact_id AND
  		c.organization_id = o.organization_id
  	  ~;
  
  my @rows = $sbeams->selectOneColumn($sql);
  
  if ($rows[0]) { 
  	$HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id} = $rows[0];		#save the user_id Organization_id for future access
  	return $rows[0];
  
  }else{
  	return ;
  }
}


###############################################################################
#  update_database
# takes in a TABLE_NAME (prepends ST_ to it), a primary ID of that table to update,
#   and a list of fields in that table to update
# returns the primary id that was updated back
###############################################################################

sub update_database {
  my %args = @_;

  my $TABLE_NAME = $args{'TABLE_NAME'};
  my $id = $args{'ID'};
  my %params = %{$args{'PARAMS'}};

  #### Get the columns and input types for this table/query
  my @columns;
  my $PK_COLUMN_NAME;
  my $sqltable;
  if ($TABLE_NAME =~ /^ST_/) {
    @columns = $sbeams_solexa->returnTableInfo($TABLE_NAME,"ordered_columns");
    ($PK_COLUMN_NAME) = $sbeams_solexa->returnTableInfo($TABLE_NAME, "PK_COLUMN_NAME");
    $sqltable = '$TB'.$TABLE_NAME;
  } else {
    # the sbeams tables are all lower case and caught in Connection.pm, so they need a special case
    @columns = $sbeams->returnTableInfo($TABLE_NAME,'ordered_columns');
    ($PK_COLUMN_NAME) = $sbeams->returnTableInfo($TABLE_NAME, "PK_COLUMN_NAME");
    $sqltable = '$TB_'.uc($TABLE_NAME);
  }
    

  print "Found columns ".Dumper(\@columns)." in table $TABLE_NAME with PK COL $PK_COLUMN_NAME\n" if $VERBOSE >=100;

# The following commented section is useful for retrieving the info from the database
# if we were planning on only updating stuff that had changed

  #### Define the desired columns in the query
  #["external_identifier",$extid_column,"External Identifier"],
#  my @column_array;
#  foreach my $column (@columns) {
#    my @iarray = ();
#    push(@iarray, $column);
#    push(@iarray, $column);
#    push(@iarray, $column);
#    push(@column_array, \@iarray);
#  }

#  my %colname_idx = ();
#  my @column_titles = ();
#  my $columns_clause = $sbeams->build_SQL_columns_list(
#      column_array_ref => \@column_array,
#      colnameidx_ref => \%colname_idx,
#      column_titles_ref => \@column_titles
#      );

  $sqltable =~ s/(\$\w+)/$1/eeg;

  print "Updating table $sqltable\n" if $VERBOSE >= 100;
  my $rowdata_ref = ();

  foreach my $column (@columns) {
    $rowdata_ref->{$column} = $params{$column} if $params{$column};
  }
  print "Rowdata ref\n" if $VERBOSE >= 100;
  print Dumper($rowdata_ref) if $VERBOSE >=100;

  die "Missing data to update database - $TABLE_NAME $id" unless $PK_COLUMN_NAME && scalar @columns > 0;
  my $new_id = $sbeams->updateOrInsertRow(
      table_name => $sqltable,
      rowdata_ref => $rowdata_ref,
      PK => $PK_COLUMN_NAME,
      return_PK=>1,
      update=>1,
      PK_value=>$id,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
      add_audit_parameters=>1
    );

  unless ($new_id){
    die "ERROR: Could not update database\n";
  }
  
}



1;
