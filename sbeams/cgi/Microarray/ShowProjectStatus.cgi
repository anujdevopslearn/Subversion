#!/usr/local/bin/perl

###############################################################################
# Program     : ShowProjectStatus.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               display the latest status slide in a project.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsMA $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMA = new SBEAMS::Microarray;
$sbeamsMA->setSBEAMS($sbeams);


###############################################################################
# Global Variables
###############################################################################
main();


###############################################################################
# Main Program:
#
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Print the header, do what the program does, and print footer
    $sbeamsMA->printPageHeader();
    processRequests();
    $sbeamsMA->printPageFooter();

} # end main


###############################################################################
# Process Requests
#
# Test for specific form variables and process the request 
# based on what the user wants to do. 
###############################################################################
sub processRequests {
    $current_username = $sbeams->getCurrent_username;
    $current_contact_id = $sbeams->getCurrent_contact_id;
    $current_work_group_id = $sbeams->getCurrent_work_group_id;
    $current_work_group_name = $sbeams->getCurrent_work_group_name;
    $current_project_id = $sbeams->getCurrent_project_id;
    $current_project_name = $sbeams->getCurrent_project_name;
    $dbh = $sbeams->getDBHandle();


    # Enable for debugging
    if (0==1) {
      print "Content-type: text/html\n\n";
      my ($ee,$ff);
      foreach $ee (keys %ENV) {
        print "$ee =$ENV{$ee}=<BR>\n";
      }
      foreach $ee ( $q->param ) {
        $ff = $q->param($ee);
        print "$ee =$ff=<BR>\n";
      }
    }


    printEntryForm();


} # end processRequests



###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

    my %parameters;
    my $element;
    my $sql_query;
    my (%url_cols,%hidden_cols);

    my $CATEGORY="Show Project/Experiment Status";


    my $apply_action  = $q->param('apply_action');
    $parameters{project_id} = $q->param('project_id');

    # If we're coming to this page for the first time, and there is a
    # default project set, then automatically select that one and GO!
    if ( ($parameters{project_id} eq "") && ($current_project_id > 0) ) {
      $parameters{project_id} = $current_project_id;
      $apply_action = "QUERY";
    }


    $sbeams->printUserContext();
    print qq!
        <P>
        <H2>$CATEGORY</H2>
        $LINESEPARATOR
        <FORM METHOD="post">
        <TABLE>
    !;


    # ---------------------------
    # Query to obtain column information about the table being managed
    $sql_query = qq~
	SELECT project_id,username+' - '+name
	  FROM $TB_PROJECT P
	  LEFT JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id=UL.contact_id )
	 ORDER BY username,name
    ~;
    my $optionlist = $sbeams->buildOptionList(
           $sql_query,$parameters{project_id});


    my $selected = "SELECTED" if ($parameters{project_id} eq "ALL UNFINISHED") || "";
    print qq!
          <TR><TD><B>Project:</B></TD>
          <TD><SELECT NAME="project_id">
          <OPTION VALUE=""></OPTION>
          <OPTION VALUE="ALL UNFINISHED" $selected>ALL UNFINISHED</OPTION>
          $optionlist</SELECT></TD>
          <TD BGCOLOR="E0E0E0">Select the Project Name</TD>
          </TD></TR>
    !;


    # ---------------------------
    # Show the QUERY, REFRESH, and Reset buttons
    print qq!
	<TR><TD COLSPAN=2>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="QUERY">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="reset"  VALUE="Reset">
         </TR></TABLE>
         </FORM>
    !;


    $sbeams->printPageFooter("CloseTables");
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";

    # --------------------------------------------------
    if ($parameters{project_id} gt "") {

      if ($parameters{project_id} eq "ALL UNFINISHED") {
        $sql_query = qq~
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
 WHERE AR.request_status!='Finished'
--   AND ARSL.array_request_slide_id IS NOT NULL
   AND ( AR.record_status != 'D' OR AR.record_status IS NULL )
   AND ( A.record_status != 'D' OR A.record_status IS NULL )
   AND ( PB.record_status != 'D' OR PB.record_status IS NULL )
   AND ( H.record_status != 'D' OR H.record_status IS NULL )
   AND ( ASCAN.record_status != 'D' OR ASCAN.record_status IS NULL )
   AND ( AQ.record_status != 'D' OR AQ.record_status IS NULL )
 ORDER BY A.array_name,AR.array_request_id,ARSL.array_request_slide_id
        ~;
      } else {
        $sql_query = qq~
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
 WHERE AR.project_id=$parameters{project_id}
   AND ARSL.array_request_slide_id IS NOT NULL
   AND ( AR.record_status != 'D' OR AR.record_status IS NULL )
   AND ( A.record_status != 'D' OR A.record_status IS NULL )
   AND ( PB.record_status != 'D' OR PB.record_status IS NULL )
   AND ( H.record_status != 'D' OR H.record_status IS NULL )
   AND ( ASCAN.record_status != 'D' OR ASCAN.record_status IS NULL )
   AND ( AQ.record_status != 'D' OR AQ.record_status IS NULL )
 ORDER BY A.array_name,AR.array_request_id,ARSL.array_request_slide_id
        ~;
      }


      my $base_url = "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=";
      %url_cols = ('array_name' => "${base_url}array&array_id=%0V",
                   'date_requested' => "$CGI_BASE_DIR/Microarray/SubmitArrayRequest.cgi?TABLE_NAME=array_request&array_request_id=%2V",
                   'date_printed' => "${base_url}printing_batch&printing_batch_id=%5V", 
                   'date_hybridized' => "${base_url}hybridization&hybridization_id=%7V", 
                   'date_scanned' => "${base_url}array_scan&array_scan_id=%9V", 
                   'date_quantitated' => "${base_url}array_quantitation&array_quantitation_id=%12V", 
      );

      %hidden_cols = ('array_id' => 1,
                      'array_request_id' => 1,
                      'printing_batch_id' => 1,
                      'hybridization_id' => 1,
                      'array_scan_id' => 1,
                      'array_quantitation_id' => 1,
      );


    } else {
      $apply_action="BAD SELECTION";
    }


    if ($apply_action eq "QUERY") {
      return $sbeams->displayQueryResult(sql_query=>$sql_query,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols);
    } else {
      print "<H4>Select parameters above and press QUERY</H4>\n";
    }


} # end printEntryForm



