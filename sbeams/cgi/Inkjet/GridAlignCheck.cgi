#!/usr/local/bin/perl 

###############################################################################
# Program     : GridAlignCheck.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to run some
#               Quantitation files through Bruz's GRAPE alignment checker.
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
             $t0 $t1 $t2 $t3 $hrt0 $hrt1 $hrt2 $hrt3
             $PK_COLUMN_NAME @MENU_OPTIONS);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
$t0 = (times)[0];
$hrt0 = [gettimeofday()];

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Inkjet;
use SBEAMS::Inkjet::Settings;
use SBEAMS::Inkjet::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMA = new SBEAMS::Inkjet;
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
    $t1 = (times)[0];
    $hrt1 = [gettimeofday()];
    exit unless ($current_username = $sbeams->Authenticate());


		#### Read in the default input parameters
		my %parameters;
		my $n_params_found = $sbeams->parse_input_parameters(q=>$q,parameters_ref=>\%parameters);
		#$sbeams->printDebuggingInfo($q);
		
		
		#### Process generic "state" parameters before we start
		$sbeams->processStandardParameters(parameters_ref=>\%parameters);

    #### Print the header, do what the program does, and print footer
    $t2 = (times)[0];
    $hrt2 = [gettimeofday()];
    $sbeamsMA->printPageHeader();
    processRequests();
    $sbeamsMA->printPageFooter();

    $t3 = (times)[0];
    $hrt3 = [gettimeofday()];

    printf("\nt0 - t1: %4f<BR>\n",tv_interval($hrt0,$hrt1));
    printf("t1 - t2: %4f<BR>\n",tv_interval($hrt1,$hrt2));
    printf("t2 - t3: %4f<BR>\n",tv_interval($hrt2,$hrt3));
    printf("User Tm: %4f <BR>\n",$t3);

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

    my $CATEGORY="Grid Alignment Check";


#    my $apply_action  = $q->param('apply_action');
#    $parameters{project_id} = $q->param('project_id');
#
#
#    # If we're coming to this page for the first time, and there is a
#    # default project set, then automatically select that one and GO!
#    if ( ($parameters{project_id} eq "") && ($current_project_id > 0) ) {
#      $parameters{project_id} = $current_project_id;
#      $apply_action = "QUERY";
#    }


    $sbeams->printUserContext();
    print qq!
        <P>
        <H2>$CATEGORY</H2>
        $LINESEPARATOR
        <TABLE>
    !;


#    # ---------------------------
#    # Query to obtain column information about the table being managed
#    $sql_query = qq~
#	SELECT project_id,username+' - '+name
#	  FROM $TB_PROJECT P
#	  LEFT JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id=UL.contact_id )
#	 ORDER BY username,name
#    ~;
#    my $optionlist = $sbeams->buildOptionList(
#           $sql_query,$parameters{project_id});
#
#
#    print qq!
#          <TR><TD><B>Project:</B></TD>
#          <TD><SELECT NAME="project_id">
#          <OPTION VALUE=""></OPTION>
#          $optionlist</SELECT></TD>
#          <TD BGCOLOR="E0E0E0">Select the Project Name</TD>
#          </TD></TR>
#    !;
#
#
#    # ---------------------------
#    # Show the QUERY, REFRESH, and Reset buttons
#    print qq!
#	<TR><TD COLSPAN=2>
#	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
#	<INPUT TYPE="submit" NAME="apply_action" VALUE="QUERY">
#	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
#	<INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH">
#	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
#	<INPUT TYPE="reset"  VALUE="Reset">
#         </TR></TABLE>
#         </FORM>
#    !;
#
#
#    $sbeams->printPageFooter("CloseTables");
#    print "<BR><HR SIZE=5 NOSHADE><BR>\n";
#
#    # --------------------------------------------------
    if ($current_project_id > 0) {
      $sql_query = qq~
SELECT 
	A.array_id,A.array_name,
	AR.array_request_id,ARSL.array_request_slide_id,
	AQ.array_quantitation_id,AQ.date_quantitated,AQ.data_flag AS 'quan_flag',
	AQ.stage_location AS 'filename'
  FROM $TBIJ_ARRAY_REQUEST AR
  LEFT JOIN $TBIJ_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN $TBIJ_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN $TBIJ_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN $TBIJ_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
 WHERE AR.project_id=$current_project_id
-- AND AQ.data_flag='OK'
   AND AQ.array_quantitation_id IS NOT NULL
   AND AR.record_status != 'D'
   AND A.record_status != 'D'
   AND ASCAN.record_status != 'D'
   AND AQ.record_status != 'D'
 ORDER BY A.array_name
     ~;

      my $base_url = "$CGI_BASE_DIR/ManageTable.cgi?TABLE_NAME=IJ_";
      %url_cols = ('array_name' => "${base_url}array&array_id=%0V",
                   'array_request_slide_id' => "$CGI_BASE_DIR/SubmitArrayRequest.cgi?TABLE_NAME=IJ_array_request&array_request_id=%2V",
                   'date_quantitated' => "${base_url}array_quantitation&array_quantitation_id=%4V", 
      );

      %hidden_cols = ('array_id' => 1,
                      'array_request_id' => 1,
                      'array_quantitation_id' => 1,
      );


    }# else {
#      $apply_action="BAD SELECTION";
#    }
#
#
#    if ($apply_action eq "QUERY") {
      $sbeams->displayQueryResult(sql_query=>$sql_query,url_cols_ref=>\%url_cols,
          hidden_cols_ref=>\%hidden_cols);

      print qq~
	<BR><HR SIZE=5 NOSHADE><BR>
	<FORM METHOD="post" ACTION="http://lemur/cgi-bin/bmarzolf/grape.cgi">
      ~;


      $sql_query = qq~
	SELECT	AQ.stage_location AS 'selection',A.array_name+': '+AQ.stage_location AS 'value'
	  FROM $TBIJ_ARRAY_REQUEST AR
	  LEFT JOIN $TBIJ_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
	  LEFT JOIN $TBIJ_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
	  LEFT JOIN $TBIJ_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
	  LEFT JOIN $TBIJ_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
	 WHERE AR.project_id=$current_project_id
	   AND AQ.data_flag='OK'
	   AND AQ.array_quantitation_id IS NOT NULL
	   AND AR.record_status != 'D'
	   AND A.record_status != 'D'
	   AND ASCAN.record_status != 'D'
	   AND AQ.record_status != 'D'
	 ORDER BY A.array_name
      ~;

      my $optionlist = $sbeams->buildOptionList($sql_query);

      print qq!
        Select one especially good slide as an alignment reference:<BR>
        <SELECT NAME="ref_file" SIZE=4>
        $optionlist</SELECT><BR><BR>
      !;


      print qq!
        Select the files you want to compare to the reference:<BR>
        <SELECT NAME="selected_files" SIZE=10 MULTIPLE>
        $optionlist</SELECT><BR>
        (To select multiple files under Windows: use CTRL-click;
	under Mac: use APPLE-click; under Linux: just click)<BR>
      !;


      print qq!
	<BR><BR>When you have made your selections, press the button below to submit the alignment check.
	Note that this process can take a few minutes, so please be patient.<BR>
	<INPUT TYPE="submit" NAME="Check" VALUE="Check">
	</FORM><BR><BR>
      !;

#    } else {
#      print "<H4>Select parameters above and press QUERY\n";
#    }


} # end printEntryForm



