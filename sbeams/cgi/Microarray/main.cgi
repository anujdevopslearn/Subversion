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


  #### Define variables for Summary Section
  my $project_id = $parameters{PROJECT_ID} || $sbeams->getCurrent_project_id; 
  my $current_contact_id = $sbeams->getCurrent_contact_id();
  my ($first_name, $last_name);
  #### Show current user context information
  $sbeams->printUserContext();

  #### Get information about the current project from the database
  $sql = qq~
	SELECT C.first_name, C.last_name
	FROM $TB_CONTACT C
	WHERE C.contact_id = '$current_contact_id'
	AND C.record_status != 'D'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  if (@rows) {
    ($first_name, $last_name) = @{$rows[0]};
  }

  #### Print Project Title
  print qq~
      	<H1>$first_name $last_name\'s Homepage</H1><BR>
	~;

  #### print_tabs
  my @tab_titles = ("Array News","Current Project","Projects You Own","Accessible Projects","Graphical Overview");
  my $tab_titles_ref = \@tab_titles;
  my $page_link = "main.cgi";
  my $unselected_bg_color = "\#008000";
  my $unselected_font_color = "\#FFFFFF";
  my $selected_bg_color = "\#DC143C";
  my $selected_font_color = "\#FFFFFF";

  #### Summary Section 
  if($parameters{'tab'} eq "array_news") {
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     unselected_bg_color=>$unselected_bg_color,
			     unselected_font_color=>$unselected_font_color,
			     selected_bg_color=>$selected_bg_color,
			     selected_font_color=>$selected_font_color,
			     selected_tab=>0);
      print_array_news_tab();
  }elsif ($parameters{'tab'} eq "current_project"){
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     unselected_bg_color=>$unselected_bg_color,
			     unselected_font_color=>$unselected_font_color,
			     selected_bg_color=>$selected_bg_color,
			     selected_font_color=>$selected_font_color,
			     selected_tab=>1);
      print_current_project_tab(); 
  }elsif($parameters{'tab'} eq "projects_you_own") { 
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     unselected_bg_color=>$unselected_bg_color,
			     unselected_font_color=>$unselected_font_color,
			     selected_bg_color=>$selected_bg_color,
			     selected_font_color=>$selected_font_color,
			     selected_tab=>2);
      print_projects_you_own_tab(); 
  }elsif($parameters{'tab'} eq "accessible_projects") { 
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     unselected_bg_color=>$unselected_bg_color,
			     unselected_font_color=>$unselected_font_color,
			     selected_bg_color=>$selected_bg_color,
			     selected_font_color=>$selected_font_color,
			     selected_tab=>3);
      print_accessible_projects_tab(); 
  }elsif($parameters{'tab'} eq "graphical_overview") {
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     unselected_bg_color=>$unselected_bg_color,
			     unselected_font_color=>$unselected_font_color,
			     selected_bg_color=>$selected_bg_color,
			     selected_font_color=>$selected_font_color,
			     selected_tab=>4);
      print_graphical_overview_tab();
  }else{
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     unselected_bg_color=>$unselected_bg_color,
			     unselected_font_color=>$unselected_font_color,
			     selected_bg_color=>$selected_bg_color,
			     selected_font_color=>$selected_font_color,
			     selected_tab=>0);
      print_array_news_tab();
  }
 
  return;

} # end handle_request


###############################################################################
# print_array_news_tab
###############################################################################
sub print_array_news_tab {
  my %args = @_;
  my $SUB_NAME = "print_array_news_tab";
  my $file_name = "$PHYSICAL_BASE_DIR/lib/etc/$SBEAMS_SUBDIR/news/current_news.txt";

  open(INFILE, $file_name) || die "unable to open news file, $file_name";
  print qq~
      <P>
      ~;
  while (<INFILE>) {
      my $textline = $_;
      if ($textline =~ /^Title:(.*)/){
         print qq ~
	   <H3><FONT COLOR="red"><U>$1</U></FONT></H3>
	  ~;
      }elsif($textline =~/^Posted:(.*)/){
	 print qq~
	     <B>Posted on: $1</B><BR>
	     ~;
     }elsif($textline =~/\w/){
	 print qq~$textline~;
     }
  }
  print qq~
      </P>
      ~;    
  return;
}
###############################################################################
# print_current_project_tab
###############################################################################
sub print_current_project_tab {
    my %args = @_;
    my $SUB_NAME = "print_current_project_tab";

    #$sbeams->printCurrentProject(page_link=>'ProjectHome.cgi');


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
	<H1>Summary of $project_name: <A HREF="ProjectHome.cgi">[More Information]</A></H1>
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

    return;
}



###############################################################################
# print_projects_you_own_tab
###############################################################################
sub print_projects_you_own_tab {
  my %args = @_;
  my $SUB_NAME = "print_projects_you_own_tab";
  
  $sbeams->printProjectsYouOwn();

  return;
}
  

###############################################################################
# print_accessible_projects_tab
###############################################################################
sub print_accessible_projects_tab {
  my %args = @_;
  my $SUB_NAME = "print_accessible_projects_tab";
  
  $sbeams->printProjectsYouHaveAccessTo();

  return;
}

  

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
}


