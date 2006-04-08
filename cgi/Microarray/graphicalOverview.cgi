#!/usr/local/bin/perl


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
 
use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

#use CGI;
#$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value kay=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET   = $OPTIONS{"quiet"} || 0;
$DEBUG   = $OPTIONS{"debug"} || 0;
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

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters( parameters_ref=>\%parameters);

  $sbeamsMOD->printPageHeader();
  handle_request(ref_parameters=>\%parameters);
  $sbeamsMOD->printPageFooter();

} # end main


###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;

  #### Show current user context information
  $sbeams->printUserContext();

  print_graphical_overview_tab();
  return;

} # end handle_request


###############################################################################
# print_graphical_overview_tab
###############################################################################
sub print_graphical_overview_tab {
  my %args = @_;
  my $SUB_NAME = "print_graphical_overview_tab";
  
  #### Print out graphic
  print qq!
  <P>
  <center>
  <img src="$HTML_BASE_DIR/images/maimagemap.gif" usemap="#map" border=0>
  <map name="map">
  <area shape=rect coords="6,6,106,56" href="ManageTable.cgi?TABLE_NAME=project&ShowEntryForm=1">
  <area shape=rect coords="99,65,199,115" href="SubmitArrayRequest.cgi?TABLE_NAME=MA_array_request&ShowEntryForm=1">
  <area shape=rect coords="190,124,290,174" href="ManageTable.cgi?TABLE_NAME=MA_array&ShowEntryForm=1">
  <area shape=rect coords="281,183,381,233" href="ManageTable.cgi?TABLE_NAME=MA_array_scan&ShowEntryForm=1">
  <area shape=rect coords="371,241,471,291" href="ManageTable.cgi?TABLE_NAME=MA_array_quantitation&ShowEntryForm=1">
  <area shape=rect coords="432,301,562,351" href="PipelineSetup.cgi">
  <area shape=rect coords="59,178,159,228" href="ManageTable.cgi?TABLE_NAME=MA_hybridization&ShowEntryForm=1">
  <area shape=rect coords="59,254,159,304" href="ManageTable.cgi?TABLE_NAME=MA_labeling&ShowEntryForm=1">
  <area shape=rect coords="324,11,424,61" href="ManageTable.cgi?TABLE_NAME=MA_slide_lot&ShowEntryForm=1">
  <area shape=rect coords="451,11,551,61" href="ManageTable.cgi?TABLE_NAME=MA_slide_model&ShowEntryForm=1">
  <area shape=rect coords="395,75,495,125" href="ManageTable.cgi?TABLE_NAME=MA_printing_batch&ShowEntryForm=1">
  <area shape=rect coords="469,137,569,187" href="ManageTable.cgi?TABLE_NAME=protocol&ShowEntryForm=1">
  !;

  # Depending on user context, the image map links will be printed?
  print qq!
  </map>
  </p>
  !;

  return;
}


