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
    exit unless ($current_username = $sbeams->Authenticate());


		#### Read in the default input parameters
		my %parameters;
		my $n_params_found = $sbeams->parse_input_parameters(q=>$q,parameters_ref=>\%parameters);
		#$sbeams->printDebuggingInfo($q);
		
		
		#### Process generic "state" parameters before we start
		$sbeams->processStandardParameters(parameters_ref=>\%parameters);
		
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

    $sbeams->printUserContext();
    print qq!
        <P>
        <H2>$CATEGORY</H2>
        $LINESEPARATOR
        <TABLE>
    !;

    if ($current_project_id gt "") {
        $sql_query = qq~
SELECT	A.array_id,A.array_name,
	AR.array_request_id,ARSL.array_request_slide_id,
	AR.date_created AS 'date_requested',
	PB.printing_batch_id,PB.date_started AS 'date_printed',
	H.hybridization_id,H.date_hybridized,
	ASCAN.array_scan_id,ASCAN.date_scanned,ASCAN.data_flag AS 'scan_flag',
	AQ.array_quantitation_id,AQ.date_quantitated,AQ.data_flag AS 'quan_flag'
  FROM $TBIJ_ARRAY_REQUEST AR
  LEFT JOIN $TBIJ_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN $TBIJ_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN $TBIJ_PRINTING_BATCH PB ON ( A.printing_batch_id = PB.printing_batch_id )
  LEFT JOIN $TBIJ_HYBRIDIZATION H ON ( A.array_id = H.array_id )
  LEFT JOIN $TBIJ_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN $TBIJ_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
 WHERE AR.project_id=$current_project_id
   AND ARSL.array_request_slide_id IS NOT NULL
   AND ( AR.record_status != 'D' OR AR.record_status IS NULL )
   AND ( A.record_status != 'D' OR A.record_status IS NULL )
   AND ( PB.record_status != 'D' OR PB.record_status IS NULL )
   AND ( H.record_status != 'D' OR H.record_status IS NULL )
   AND ( ASCAN.record_status != 'D' OR ASCAN.record_status IS NULL )
   AND ( AQ.record_status != 'D' OR AQ.record_status IS NULL )
 ORDER BY A.array_name,AR.array_request_id,ARSL.array_request_slide_id
        ~;

      my $base_url = "$CGI_BASE_DIR/Inkjet/ManageTable.cgi?TABLE_NAME=IJ_";
      %url_cols = ('array_name' => "${base_url}array&array_id=%0V",
                   'date_requested' => "$CGI_BASE_DIR/Inkjet/SubmitArrayRequest.cgi?TABLE_NAME=IJ_array_request&array_request_id=%2V",
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
      return $sbeams->displayQueryResult(sql_query=>$sql_query,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols);
		}
}# end printEntryForm



