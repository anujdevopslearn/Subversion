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
    print_javascript();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }

} # end main


###############################################################################
# print_javascript 
##############################################################################
sub print_javascript {

print qq~
<SCRIPT LANGUAGE="Javascript">
<!--

function viewRequest(status){
    var site;
    if (status == 'old') {
	var id = document.requests.chooser.options[document.requests.chooser.selectedIndex].value;
	site = "http://db.systemsbiology.net/dev7/sbeams/cgi/Microarray/SubmitArrayRequest.cgi?TABLE_NAME=array_request&array_request_id="+id;
    }
    else {
	site = "http://db.systemsbiology.net/dev7/sbeams/cgi/Microarray/SubmitArrayRequest.cgi?TABLE_NAME=array_request&ShowEntryForm=1";
    }
    var newWindow = window.open(site);
}

function viewImage(status){
    var site;
    if (status == 'old') {
	//alert ("scan images not available to be viewed.  Will be developed later");
    var id = document.images.chooser.options[document.images.chooser.selectedIndex].value
    var site = "http://db.systemsbiology.net/dev7/sbeams/cgi/Microarray/ManageTable.cgi?TABLE_NAME=array_scan&array_scan_id="+id
    }
    else {
	//alert ("scan images not on a network share.");
        var site = "http://db.systemsbiology.net/dev7/sbeams/cgi/Microarray/ManageTable.cgi?TABLE_NAME=array_scan&ShowEntryForm=1";
    }
    var newWindow = window.open(site);
}

function viewQuantitation(status){
    var site;
    if (status == 'old') {
	var id = document.quantitations.chooser.options[document.quantitations.chooser.selectedIndex].value;
	site = "http://db.systemsbiology.net/dev7/sbeams/cgi/Microarray/ManageTable.cgi?TABLE_NAME=array_quantitation&array_quantitation_id="+id;
    }
    else {
	site = "http://db.systemsbiology.net/dev7/sbeams/cgi/Microarray/ManageTable.cgi?TABLE_NAME=array_quantitation&ShowEntryForm=1";
    }
    var newWindow = window.open(site);
}

function viewLogFile(){
    var id = document.logFiles.chooser.options[document.logFiles.chooser.selectedIndex].value;
    viewFile(id);
}

function viewFile(id){
    var site = "http://db.systemsbiology.net/dev7/sbeams/cgi/Microarray/ViewFile.cgi?FILE_NAME="+id;
    var newWindow = window.open(site);
}

function viewPDF(){
    alert ("will be implemented");
    //var id = document.pdfFiles.chooser.options[document.pdfFiles.chooser.selectedIndex].value;
    //window.open("file://"+id);
}

//-->
</SCRIPT>
~;
return 1;
}

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


  #### Define variables for Summary Section
  my $project_id = $parameters{PROJECT_ID} || $sbeams->getCurrent_project_id; 
  my $pi_first_name = '';
  my $pi_last_name = '';
  my $username = '';
  my $project_name = 'NONE';
  my $project_tag = 'NONE';
  my $project_status = 'N/A';
  my $pi_contact_id;
  my (%array_requests, %array_scans, %quantitation_files);

  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();

  #### Get information about the current project from the database
  $sql = qq~
	SELECT P.name,P.project_tag,P.project_status, C.first_name, C.last_name, C.contact_id, UL.username
	  FROM $TB_PROJECT P
	  JOIN $TB_CONTACT C ON ( P.PI_contact_id = C.contact_id )
	  JOIN $TB_USER_LOGIN UL ON ( UL.contact_id = C.contact_id)
	WHERE P.project_id = '$project_id'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  if (@rows) {
    ($project_name,$project_tag,$project_status,$pi_first_name,$pi_last_name,$pi_contact_id,$username) = @{$rows[0]};
  }

  #### print_tabs
  my @tab_titles = ("Summary","Management","Data Analysis", "Permissions");
#  my @tab_titles = ("Summary","MIAME Status","Management","Data Analysis","Permissions");
  my $tab_titles_ref = \@tab_titles;
  my $page_link = 'ProjectHome.cgi';

  #### Summary Section 
  if ($parameters{'tab'} eq "summary"){
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>0);
      print_summary_tab(); 
  }
  elsif($parameters{'tab'} eq "miame_status") { 
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>1);
      print_miame_status_tab(); 
  }
  elsif($parameters{'tab'} eq "management") { 
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>1);
      print_management_tab(); 
  }
  elsif($parameters{'tab'} eq "data_analysis") {
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>2);
      print_data_analysis_tab()
  }
  elsif($parameters{'tab'} eq "permissions") {
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>3);
      print_permissions_tab(ref_parameters=>$ref_parameters); 
  }
  else{
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>0);
      print_summary_tab();
  }
  return;

} # end handle_request



###############################################################################
# print_summary_tab
###############################################################################
sub print_summary_tab {
  my %args = @_;
  my $SUB_NAME = "print_summary_tab";
  
  ## Define standard variables
  my ($sql, @rows);
  my $current_contact_id = $sbeams->getCurrent_contact_id();
  my (%array_requests, %array_scans, %quantitation_files);
  my $project_id = $sbeams->getCurrent_project_id();
  my ($project_name, $project_tag, $project_status, $project_desc);
  my ($pi_first_name, $pi_last_name, $pi_contact_id, $username);

  #### Get information about the current project from the database
  $sql = qq~
	SELECT P.name,P.project_tag,P.project_status,P.description,C.first_name,C.last_name,C.contact_id,UL.username
	  FROM $TB_PROJECT P
	  JOIN $TB_CONTACT C ON ( P.PI_contact_id = C.contact_id )
	  JOIN $TB_USER_LOGIN UL ON ( UL.contact_id = C.contact_id)
	WHERE P.project_id = '$project_id'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  if (@rows) {
    ($project_name,$project_tag,$project_status,$project_desc,$pi_first_name,$pi_last_name,$pi_contact_id,$username) = @{$rows[0]};
  }

  #### Print out some information about this project
  print qq~
	<H1>Summary of $project_name:</H1>
  <B><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">[Edit Project Description]</A></B><BR>
	<TABLE WIDTH="100%" BORDER=0>
	<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	             <TD COLSPAN="2" WIDTH="100%"><B>PI: </B>$pi_first_name $pi_last_name</TD></TR>
	<TR><TD></TD><TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Description:</B>$project_desc</TD></TR>
  ~;

  #### Get all the array information for this project
  my $n_array_requests = 0;
  my $n_array_scans = 0;
  my $n_quantitation_files = 0;
  if ($project_id > 0) {

      $sql = qq~
	  SELECT array_request_id, n_slides, date_created 
	  FROM $TB_ARRAY_REQUEST
	  WHERE project_id = '$project_id'
	  AND record_status != 'D'
      ~;
      @rows = $sbeams->selectSeveralColumns($sql);
      foreach my $row(@rows){
	  my @temp_row = @{$row};
	  $array_requests{$temp_row[0]} = "$temp_row[2] ($temp_row[1] slides)";
	  $n_array_requests++;
      }

      $sql = qq~
	  SELECT ASCAN.array_scan_id, ASCAN.stage_location
	  FROM $TB_ARRAY_SCAN ASCAN
	  JOIN $TB_ARRAY A ON ( A.array_id = ASCAN.array_id )
	  JOIN $TB_ARRAY_QUANTITATION AQ ON ( AQ.array_scan_id = ASCAN.array_scan_id )
	  WHERE A.project_id = '$project_id'
	  AND ASCAN.record_status != 'D'
	  AND A.record_status != 'D'
	  AND AQ.record_status != 'D'
      ~;
      %array_scans = $sbeams->selectTwoColumnHash($sql);

      $sql = qq~
	  SELECT AQ.array_quantitation_id, AQ.stage_location
	  FROM $TB_ARRAY_SCAN ASCAN
	  JOIN $TB_ARRAY A ON ( A.array_id = ASCAN.array_id )
	  JOIN $TB_ARRAY_QUANTITATION AQ ON ( AQ.array_scan_id = ASCAN.array_scan_id )
	  WHERE A.project_id = '$project_id'
	  AND ASCAN.record_status != 'D'
	  AND A.record_status != 'D'
	  AND AQ.record_status != 'D'
      ~;
      %quantitation_files = $sbeams->selectTwoColumnHash($sql);

      foreach my $key (keys %array_scans) {
	  $n_array_scans++;
      }
      foreach my $key (keys %quantitation_files){
	  $n_quantitation_files++;
      }
  }

  print qq~
      <TR><TD></TD><TD COLSPAN="2"><B>Array Requests: $n_array_requests</B></TD></TR>
      <TR><TD></TD><TD COLSPAN="2"><B>Array Scans: $n_array_scans</B></TD></TR>
      <TR><TD></TD><TD COLSPAN="2"><B>Array Quantitations: $n_quantitation_files</B></TD></TR>
      <TR><TD></TD><TD COLSPAN="2"><B>Access Privileges:</B><A HREF="$CGI_BASE_DIR/ManageProjectPrivileges">[View/Edit]</A></TD></TR>    
      <TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD></TR>
      </TABLE>
      $LINESEPARATOR
  ~;

####  Project Status Section ####
	$sql = qq~
SELECT	A.array_id,A.array_name,
	AR.array_request_id,ARSL.array_request_slide_id,
	AR.date_created AS 'date_requested',
	PB.printing_batch_id,PB.date_started AS 'date_printed',
	H.hybridization_id,H.date_hybridized,
	ASCAN.array_scan_id,ASCAN.date_scanned,ASCAN.data_flag AS 'scan_flag',
	AQ.array_quantitation_id,AQ.date_quantitated,AQ.data_flag AS 'quan_flag'
  FROM $TB_ARRAY_REQUEST AR
  LEFT JOIN $TB_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN $TB_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN $TB_PRINTING_BATCH PB ON ( A.printing_batch_id = PB.printing_batch_id )
  LEFT JOIN $TB_HYBRIDIZATION H ON ( A.array_id = H.array_id )
  LEFT JOIN $TB_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN $TB_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
 WHERE AR.project_id=$project_id
   AND ARSL.array_request_slide_id IS NOT NULL
   AND ( AR.record_status != 'D' OR AR.record_status IS NULL )
   AND ( A.record_status != 'D' OR A.record_status IS NULL )
   AND ( PB.record_status != 'D' OR PB.record_status IS NULL )
   AND ( H.record_status != 'D' OR H.record_status IS NULL )
   AND ( ASCAN.record_status != 'D' OR ASCAN.record_status IS NULL )
   AND ( AQ.record_status != 'D' OR AQ.record_status IS NULL )
 ORDER BY A.array_name,AR.array_request_id,ARSL.array_request_slide_id
        ~;

	my $base_url = "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=";
	my %url_cols = ('array_name' => "${base_url}array&array_id=%0V",
									'date_requested' => "$CGI_BASE_DIR/Microarray/SubmitArrayRequest.cgi?TABLE_NAME=array_request&array_request_id=%2V",
									'date_printed' => "${base_url}printing_batch&printing_batch_id=%5V", 
									'date_hybridized' => "${base_url}hybridization&hybridization_id=%7V", 
									'date_scanned' => "${base_url}array_scan&array_scan_id=%9V", 
									'date_quantitated' => "${base_url}array_quantitation&array_quantitation_id=%12V", 
									);

	my %hidden_cols = ('array_id' => 1,
										 'array_request_id' => 1,
										 'printing_batch_id' => 1,
										 'hybridization_id' => 1,
										 'array_scan_id' => 1,
										 'array_quantitation_id' => 1,
										 );

	return $sbeams->displayQueryResult(sql_query=>$sql,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols);
}


###############################################################################
# print_miame_status_tab
###############################################################################
sub print_miame_status_tab {
  my %args = @_;
  my $SUB_NAME = "print_miame_status_tab";
  
  ## Decode argument list
  my $project_id = $sbeams->getCurrent_project_id();

  ## Define standard variables

  print qq!
      <H1>MIAME Status:</H1>
      <IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="100%" HEIGHT="1"><BR>
      <UL>
        <LI><A HREF="http://www.mged.org/Workgroups/MIAME/miame.html" target="_blank">MIAME Website</A><BR>
        <LI><A HREF="MIAME_checklist.doc">Download MIAME Checklist</A>
      </UL>
      <A HREF="MIAMEStatus.cgi?PROJECT_ID=$project_id">Complete MIAME Details for this Project</A>
      <TABLE CELLSPACING="5">
        <TR><TD></TD></TR>
	<TR>
	<TD>Experiment Design</TD>
	<TD><A HREF="MIAMEStatus.cgi?CATEGORY=experiment_design">Detailed Information</A></TD>
	</TR>
	<TR>
	<TD>Array Design</TD>
	<TD><A HREF="MIAMEStatus.cgi?CATEGORY=array_design">Detailed Information</A></TD>
	</TR>
	<TR>
	<TD>Sample Information</TD>
	<TD><A HREF="MIAMEStatus.cgi?CATEGORY=sample_information">Detailed Information</A></TD>
	</TR>
	<TR>
	<TD>Labeling and Hybridization</TD>
	<TD><A HREF="MIAMEStatus.cgi?CATEGORY=labeling_and_hybridization">Detailed Information</A></TD>
	</TR>
	<TR>
	<TD>Measurements</TD>
	<TD><A HREF="MIAMEStatus.cgi?CATEGORY=measurements">Detailed Information</A></TD>
	</TR>
        <TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD></TR>
      </TABLE>
      $LINESEPARATOR
      !;
  return;
}
  

###############################################################################
# print_management_tab
###############################################################################
sub print_management_tab {
  my %args = @_;
  my $SUB_NAME = "print_management_tab";
  
  ## Decode argument list
  my $project_id = $sbeams->getCurrent_project_id();

  ## Define standard variables
  my ($sql, @rows);
  my (%array_requests, $n_array_requests);
  my (%array_scans, $n_array_scans);
  my (%quantitation_files, $n_quantitation_files);

  $sql = qq~
      SELECT array_request_id, n_slides, date_created 
      FROM $TB_ARRAY_REQUEST
      WHERE project_id = '$project_id'
      AND record_status != 'D'
      ~;
  @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row(@rows){
      my @temp_row = @{$row};
      $array_requests{$temp_row[0]} = "$temp_row[2] ($temp_row[1] slides)";
      $n_array_requests++;
  }
  
  $sql = qq~
      SELECT ASCAN.array_scan_id, ASCAN.stage_location
      FROM $TB_ARRAY_SCAN ASCAN
      JOIN $TB_ARRAY A ON ( A.array_id = ASCAN.array_id )
      JOIN $TB_ARRAY_QUANTITATION AQ ON ( AQ.array_scan_id = ASCAN.array_scan_id )
      WHERE A.project_id = '$project_id'
      AND ASCAN.record_status != 'D'
      AND A.record_status != 'D'
      AND AQ.record_status != 'D'
      ~;
  %array_scans = $sbeams->selectTwoColumnHash($sql);
  
  $sql = qq~
      SELECT AQ.array_quantitation_id, AQ.stage_location
      FROM $TB_ARRAY_SCAN ASCAN
      JOIN $TB_ARRAY A ON ( A.array_id = ASCAN.array_id )
      JOIN $TB_ARRAY_QUANTITATION AQ ON ( AQ.array_scan_id = ASCAN.array_scan_id )
      WHERE A.project_id = '$project_id'
      AND ASCAN.record_status != 'D'
      AND A.record_status != 'D'
      AND AQ.record_status != 'D'
      ~;
  %quantitation_files = $sbeams->selectTwoColumnHash($sql);
  
  foreach my $key (keys %array_scans) {
      $n_array_scans++;
  }
  foreach my $key (keys %quantitation_files){
      $n_quantitation_files++;
  }

  print qq~
      <H1>Project Management:</H1>
      <IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="100%" HEIGHT="1">
  ~;

  print qq~
      <FORM NAME="requests">
      <TABLE>
        <TR><TD><B>Array Requests</B></TD></TR>
        <TR><TD><SELECT NAME="chooser">
  ~;
  
  foreach my $key(keys %array_requests) {
      print qq~ <OPTION value = "$key">$array_requests{$key} ~;
  }

  print qq~
        </SELECT></TD></TR>
        <TR><TD>
	<INPUT TYPE="button" name="arButton" value="Go To Record" onClick="viewRequest('old')">
	<INPUT TYPE="button" name="newARButton" value="Add New Record" onClick="viewRequest('new')">
	</TD></TR>
      </TABLE>
      </FORM>
	
      <BR>
      
      <FORM NAME="images">
      <TABLE>
        <TR><TD><B>Array Images</B></TD></TR>
        <TR><TD><SELECT name="chooser">
        ~;
  
  foreach my $key(keys %array_scans) {
      my $name = $array_scans{$key};
      $name =~ s(^.*/)();
      print qq~ <OPTION value="$key">$name ~;
  }
  
  print qq~
        </SELECT></TD></TR>
        <TR><TD>
	<INPUT TYPE="button"name="aiButton" value="Go To Record" onClick="viewImage('old')">
	<INPUT TYPE="button"name="newAIButton" value="Add New Record" onClick="viewImage('new')">
	</TD></TR>
      </TABLE>
      </FORM>
      
      <BR>

      <FORM NAME="quantitations">
      <TABLE>
        <TR><TD><B>Array Quantitation</B></TD></TR>
        <TR><TD><SELECT name="chooser">
        ~;

  foreach my $key (keys %quantitation_files) {
      my $name = $quantitation_files{$key};
      $name =~ s(^.*/)();
      print qq~ <OPTION value="$key">$name ~;
  }
  print qq~
        </SELECT></TD></TR>
        <TR><TD>
	<INPUT TYPE="button"name="aqButton"value="Go to Record" onClick="viewQuantitation('old')">
	<INPUT TYPE="button"name="newAQButton"value="Add New Record" onClick="viewQuantitation('new')">
	</TD></TR>
      </TABLE>
      </FORM>
    $LINESEPARATOR
  ~;
  return;
}

  

###############################################################################
# print_data_analysis_tab
###############################################################################
sub print_data_analysis_tab {
  my %args = @_;
  my $SUB_NAME = "print_data_analysis_tab";
  
  ## Decode argument list
  my $project_id = $sbeams->getCurrent_project_id();

  ## Define standard variables
  my ($sql, @rows);

  # Data Analysis Section
  my $output_dir = "/net/arrays/Pipeline/output/project_id/".$project_id;
  my @pdf_list = glob("$output_dir/*.pdf");
  my @log_list = glob("$output_dir/*.log");

  print qq~
      <H1>Data Analysis:</H1>
      <UL>
        <LI><A HREF="ProcessProject.cgi">Submit a New Job to the Pipeline</A>
	<LI><A HREF="http://db.systemsbiology.net/software/ArrayProcess/" TARGET="_blank">What is the Data Processing Pipeline?</A>
      </UL>
      ~;
#  print qq~
#      <FORM NAME="pdfFiles">
#      <IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="100%" HEIGHT="1">
#      <TABLE>
#        <TR><TD><B>Preprocess PDFs</B></TD></TR>
#        <TR><TD><SELECT NAME="chooser">
#  ~;
#  
#  foreach my $pdf(@pdf_list) {
#      my $temp = $pdf;
#      $temp =~ s(^.*/)();
#      print qq~ <OPTION value="$pdf">$temp ~;
#  }
#
#  print qq~
#       </SELECT></TD></TR>
#       <TR><TD><INPUT TYPE="button" name="pdfButton" value="view" onClick="viewPDF()"></TD></TR>
#     </TABLE>
#     </FORM>
#
#     <BR>
#     ~;
  print qq~
     <FORM NAME="logFiles">
     <TABLE>
       <TR><TD><B>Log Files</B></TD></TR>
       <TR><TD><SELECT NAME="chooser">
  ~;

  foreach my $log(@log_list) {
      my $temp = $log;
      $temp =~ s(^.*/)();
      print qq~ <OPTION value="$temp">$temp~;
  }

  print qq~
       </SELECT></TD></TR>
       <TR>
         <TD><INPUT TYPE="button" name="logButton" value="view" onClick="viewLogFile()"></TD>
       </TR>
     </TABLE>
     </FORM>
     $LINESEPARATOR
     ~;

  return;
}


###############################################################################
# print_permissions_tab
###############################################################################
sub print_permissions_tab {
  my %args = @_;
  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  
  $sbeams->print_permissions_table(ref_parameters=>$ref_parameters,
																	 no_permissions=>1);
}

