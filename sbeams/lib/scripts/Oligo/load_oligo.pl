#!/usr/local/bin/perl -w


######################################################################
# Program  	: load_oligo.pl
# Authors	: Patrick Mar <pmar@systemsbiology.org>,
#             Michael Johnson <mjohnson@systemsbiology.org>
#
# Other contributors : Eric Deutsch <edeutsch@systemsbiology.org>
# 
# Description : Populates the following tables in the Oligo database -
#		        oligo_parameter_set
#               oligo_search
#               selected_oligo
#               oligo
#               oligo_annotation
#               oligo_set
#               oligo_oligo_set
#
# Last modified : 8/24/04
######################################################################


######################################################################
# Generic SBEAMS setup
######################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $q $module $work_group $USAGE %OPTIONS 
			 $QUIET $VERBOSE $DEBUG $DATABASE $TESTONLY $PROG_NAME
             $current_contact_id $current_username);

####Setup SBEAMS core module####
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Oligo;
use SBEAMS::Oligo::Settings;
use SBEAMS::Oligo::Tables;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Oligo;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
$q = new CGI;

$PROG_NAME = "load_oligo.pl";

######################################################################
# Command line stuff
######################################################################
$USAGE = <<EOU;
Usage: load_oligo.pl [OPTIONS]
Options:

  ## REQUIRED parameters.  They must be set 
  --search_tool_id n     The search tool that was used to 
                          create this oligo set
  --oligo_set_type_name  Set oligo purpose- knockout or expression
  --bioseq_set n         The biosequence set this set of oligos 
                          belong to (ORF set)
  --oligo_file           FASTA-formatted oligo file

  ## User Options
  --delete_existing      Delete the existing biosequences for this 
                          set before loading.  Normally, if there 
                          are existing biosequences, the load is blocked.
  --update_existing      Update the existing biosequence set with 
                          information in the file 
  --datetime n           (Default: current timestamp)
  --project_id n         (Default: current project ID)         


  ## Developer Options
  --verbose n            Set verbosity level. (Default: 0)
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --testonly             If set, rows in the database are not 
                          changed or added
  --set_tag              The set_tag of a biosequence set.  Note that 
                          an entire fasta file of oligo sequences 
                          (e.g.: haloarcula expression oligos) are
                          initially treated as a biosequence_set for 
                          loading purposes

 e.g.:  $PROG_NAME --quiet

EOU

#### Process options ####
unless (GetOptions(\%OPTIONS,
				   "search_tool_id=s",
				   "oligo_set_type_name=s",
				   "bioseq_set=s",
				   "oligo_file=s",
				   "delete_existing",
				   "update_existing",
				   "datetime:s",
				   "project_id:s",
				   "verbose:s",
				   "quiet",
				   "debug:s",
				   "testonly",
				   "set_tag:s")){
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 1;
if($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}


######################################################################
# Set Global Variables and execute main()
######################################################################
main();
exit(0);


######################################################################
# Main:
# 
# Call $sbeams->Authenticate() and exit if it fails or continue if it 
#   works
######################################################################
sub main{

  ## Variables
  my $current_username;
  my $project_id;

  ## Prep Work
  check_command_line();
  ($current_username, $project_id) = authenticate_user(); 

  
  $sbeams->printPageHeader();

  ## Populate oligo_search table
 # my %rowdata = ('project_id' => $project_id,
#				 'search_tool_id' => $OPTIONS{search_tool_id},
#				 'search_id_code' => time(),
#				 'search_username' => $current_username,
#				 'search_date' => $OPTIONS{datetime},
#				 'comments' => "created by load_oligo.pl");

#  my $rowdata_ref = \%rowdata; 
#  my $array_request_id = $sbeams->updateOrInsertRow(
#	table_name => "${DATABASE}oligo_search",
#        rowdata_ref => $rowdata_ref,
#        insert => 1,
#        return_PK => 1,
#        add_audit_parameters => 1, 
#        testonly => $TESTONLY, 
#        verbose => $VERBOSE );
#    undef %rowdata;


    ####Populate oligo_parameter_set####
  
    
    $sbeams->printPageFooter();

}



######################################################################
# check_command_line - verifies command line is cool
######################################################################
sub check_command_line {
  print "[STATUS]: Verifying Command Line Options...\n";

  ## Standard Variables
  my $sql;
  my @rows;

  #### Process the commmand line

  ## Required arguments
  my $search_tool_id = $OPTIONS{"search_tool_id"};
  my $oligo_set_type_name = $OPTIONS{"oligo_set_type_name"};
  my $bioseq_set = $OPTIONS{"bioseq_set"} || '';

  unless ($search_tool_id && $oligo_set_type_name && $bioseq_set) {
	print $USAGE;
	exit;
  }

  ## Data Loading Options
  my $delete_existing = $OPTIONS{"delete_existing"};
  my $update_existing = $OPTIONS{"update_existing"};
  if ( defined($delete_existing) && defined($update_existing) ) {
	print "[ERROR]: Select delete_existing OR update_existing...not both.\n";
	exit;
  }elsif ( !defined($delete_existing) && !defined($update_existing) ) {
	print "[ERROR]: Select either delete_existing OR update_existing.\n";
	exit;
  }

  if ($delete_existing){
	print "[STATUS]: Delete Existing selected\n";
  }else {
	print "[STATUS]: Update Existing selected\n";
  }

  ## Biosequence set tag (ORF list) associated with these oligos
  my $set_tag = $OPTIONS{set_tag};
  unless ($set_tag) {
	print "[ERROR]: Specify a corresponding biosequence set of ORFs\n";
	exit;
  }

  ## Data Loading Time/Date
  if ( !defined($OPTIONS{datetime}) ) {
	$OPTIONS{datetime} = "CURRENT_TIMESTAMP";
  } 
  my $datetime = $OPTIONS{datetime};
  print "[STATUS]: Load Date = $datetime\n";

  ## Verify the search tool and oligo set types.
  $sql = qq~
SELECT search_tool_id, search_tool_name
  FROM $TBOG_SEARCH_TOOL
 WHERE search_tool_id = $search_tool_id
   AND record_status != 'D'
 ~;
  @rows = $sbeams->selectSeveralColumns($sql);
  if ( scalar(@rows) == 1 ) {
	print "[STATUS]: Search Tool - @rows->[1]\n";
  }else{
	print "[ERROR]: search tool not found\n";
  }

  $sql = qq~
SELECT oligo_type_id, oligo_set_type_name
  FROM $TBOG_OLIGO_SET_TYPE
 WHERE oligo_set_type_name = $oligo_set_type_name
   AND record_status != 'D'
 ~;
  @rows = $sbeams->selectSeveralColumns($sql);
  if ( scalar(@rows) == 1 ) {
	print "[STATUS]: Oligo Set Type - @rows->[1]\n";
  }else{
	print "[ERROR]: Oligo Set Type not found\n";
  }

} #end check_command_line



######################################################################
#  authenticate_user - performs authentication and verification
######################################################################
sub authenticate_user {

  #### User Authentication
  my $module = 'Oligo';
  my $work_group = 'Oligo_admin';
  $DATABASE = $DBPREFIX{$module};

  ## Exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(work_group=>$work_group));

  ## If user doesn't specify project_id, use current project_id####
  my $project_id = $OPTIONS{"project_id"} || $sbeams->getCurrent_project_id();
  
  ## Verify that the user can write to the project
  my @writable_projects = $sbeams->getWritableProjects();
  my $project_is_writable = 0;
  foreach my $proj (@writable_projects) {
	if ($proj = $project_id) {
	  $project_is_writable = 1;
	}
  }
  unless ($project_is_writable == 1) {
	print "[ERROR] project id $project_id is NOT writable.\n";
	exit;
  }

  return ($current_username, $project_id);
}


