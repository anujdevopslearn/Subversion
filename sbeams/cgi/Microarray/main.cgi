#!/usr/local/bin/perl -T


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use CGI;
$q = new CGI;


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
  $sbeams->processStandardParameters(
    parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
    # Some action
  } else {
    $sbeamsMOD->printPageHeader();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }


} # end main



###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);
  my @rows;


  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();

  #### Title
  $sql = qq~
	SELECT first_name, last_name
	  FROM $TB_CONTACT
	 WHERE contact_id = '$current_contact_id'
  ~;

  @rows = $sbeams->selectSeveralColumns($sql);

  my ($fName, $lName);
  if (@rows) {($fName, $lName) = @{$rows[0]}};

  print qq~
      <H1><CENTER><B>$fName $lName\'s Homepage</B></CENTER></H1>
  ~;

  #### Get information about the current project from the database
  $sql = qq~
	SELECT UC.project_id,P.name,P.project_tag,P.project_status, C.first_name, C.last_name
	  FROM $TB_USER_CONTEXT UC
	  JOIN $TB_PROJECT P ON ( UC.project_id = P.project_id )
	  JOIN $TB_CONTACT C ON ( P.PI_contact_id = C.contact_id )
	 WHERE UC.contact_id = '$current_contact_id'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  my $pi_first_name = '';
  my $pi_last_name = '';
  my $project_id = '';
  my $project_name = 'NONE';
  my $project_tag = 'NONE';
  my $project_status = 'N/A';
  if (@rows) {
    ($project_id,$project_name,$project_tag,$project_status,$pi_first_name,$pi_last_name) = @{$rows[0]};
  }

  #### Print out some information about this project
  print qq~
	<H1>Current Project: <A class="h1" HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">$project_name</A></H1>
	<TABLE WIDTH="100%" BORDER=0>
	<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	             <TD COLSPAN="2" WIDTH="100%"><B>PI</B> $pi_first_name $pi_last_name</TD></TR>
	<TR><TD></TD><TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag</TD></TR>
  ~;

  #### Get project description
  my $description = '';
  if ($project_id > 0) {
      $sql = qq~
	  SELECT description 
	  FROM $TB_PROJECT 
	  WHERE project_id = '$project_id'
	  AND record_status != 'D'
      ~;
      my @temp = $sbeams->selectOneColumn($sql);
      $description = $temp[0];

      print qq~
	<TR><TD></TD><TD COLSPAN="2" WIDTH="100%"<B>Description: </B>$description</TD></TR>
      ~;
  }

  #### Get all the array information for this project
  my $array_requests = 0;
  my $array_scans = 0;
  my $quantitation_files = 0;
  if ($project_id > 0) {
      $sql = qq~
	  SELECT array_request_id FROM $TB_ARRAY_REQUEST
	  WHERE project_id = '$project_id'
	  AND record_status != 'D'
      ~;

      my @temp = $sbeams->selectOneColumn($sql);
      $array_requests = @temp;

      $sql = qq~
	  SELECT ASCAN.array_scan_id, AQ.array_quantitation_id
	  FROM $TB_ARRAY_SCAN ASCAN
	  JOIN $TB_ARRAY A ON ( A.array_id = ASCAN.array_id )
	  JOIN $TB_ARRAY_QUANTITATION AQ ON ( AQ.array_scan_id = ASCAN.array_scan_id )
	  WHERE A.project_id = '$project_id'
	  AND ASCAN.record_status != 'D'
	  AND A.record_status != 'D'
	  AND AQ.record_status != 'D'
      ~;

      my %results = $sbeams->selectTwoColumnHash($sql);
      foreach my $key (keys %results) {
	  $array_scans++;
	  if (defined($results{$key})) {
	      $quantitation_files++;
	  }
      }
  }

  print qq~
        <TR><TD></TD><TD COLSPAN="2"><B>Array Requests: $array_requests</B></TD></TR>
        <TR><TD></TD><TD COLSPAN="2"><B>Array Scans: $array_scans</B></TD></TR>
        <TR><TD></TD><TD COLSPAN="2"><B>Array Quantitations: $quantitation_files</B></TD></TR>
        <TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD></TR>
  ~;

  #### Quick Links
  print qq~
        <TR><TD></TD><TD COLSPAN="2"><A HREF="ShowProjectStatus.cgi">Project Status</A></TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><A HREF="ProcessProject.cgi">Data Processing</A></TD></TR>
	~;
  #### Finish the table
  print qq~
	</TABLE>
  ~;

  ## Print projects user owns
  $sbeams->printProjectsYouOwn();

  ## Print projects user has access to
  $sbeams->printProjectsYouHaveAccessTo();

  #### Print out graphic
  print qq!
  <P>
  <center>
  <img src="$HTML_BASE_DIR/images/maimagemap.gif" usemap="#map" border=0>
  <map name="map">
  <area shape=rect coords="6,6,106,56" href="ManageTable.cgi?TABLE_NAME=project&ShowEntryForm=1">
  <area shape=rect coords="99,65,199,115" href="SubmitArrayRequest.cgi?TABLE_NAME=array_request&ShowEntryForm=1">
  <area shape=rect coords="190,124,290,174" href="ManageTable.cgi?TABLE_NAME=array&ShowEntryForm=1">
  <area shape=rect coords="281,183,381,233" href="ManageTable.cgi?TABLE_NAME=array_scan&ShowEntryForm=1">
  <area shape=rect coords="371,241,471,291" href="ManageTable.cgi?TABLE_NAME=array_quantitation&ShowEntryForm=1">
  <area shape=rect coords="432,301,562,351" href="ProcessProject.cgi">
  <area shape=rect coords="59,178,159,228" href="ManageTable.cgi?TABLE_NAME=hybridization&ShowEntryForm=1">
  <area shape=rect coords="59,254,159,304" href="ManageTable.cgi?TABLE_NAME=labeling&ShowEntryForm=1">
  <area shape=rect coords="324,11,424,61" href="ManageTable.cgi?TABLE_NAME=slide_lot&ShowEntryForm=1">
  <area shape=rect coords="451,11,551,61" href="ManageTable.cgi?TABLE_NAME=slide_model&ShowEntryForm=1">
  <area shape=rect coords="395,75,495,125" href="ManageTable.cgi?TABLE_NAME=printing_batch&ShowEntryForm=1">
  <area shape=rect coords="469,137,569,187" href="ManageTable.cgi?TABLE_NAME=protocol&ShowEntryForm=1">
  !;

  # Depending on user context, the image map links will be printed?
  print qq!
  </map>
  </p>
  !;

  return;

} # end handle_request


