#!/usr/local/bin/perl 

###############################################################################
# Program     : SummarizeRuns.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that summarizes all BioSap runs.
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsBS $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Biosap;
use SBEAMS::Biosap::Settings;
use SBEAMS::Biosap::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsBS = new SBEAMS::Biosap;
$sbeamsBS->setSBEAMS($sbeams);


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
    $sbeamsBS->printPageHeader();
    processRequests();
    $sbeamsBS->printPageFooter();


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


    #### Decide where to go based on form values
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

    my $CATEGORY="Summarize Runs";


    my $apply_action  = "QUERY";


    $sbeams->printUserContext();
    print qq!
        <P>
        <H2>$CATEGORY</H2>
        $LINESEPARATOR
    !;


    $sbeams->printPageFooter("CloseTables");
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";


    #### Always run the query whenever called
    if (1 == 1) {

      #### Define the desired columns
      my @column_array = (
        ["biosap_search_id","BSR.biosap_search_id","biosap_search_id"],
        ["biosap_search_idcode","BSR.biosap_search_idcode","biosap_search_idcode"],
        ["search_username","BSR.search_username","search_username"],
        ["search_date","BSR.search_date","search_date"],
        ["biosap_version","BSR.biosap_version","biosap_version"],
        ["comment","FP.comment","comment"],
      );

      my $columns_clause = "";
      my $i = 0;
      my %colnameidx;
      foreach $element (@column_array) {
	$columns_clause .= "," if ($columns_clause);
        $columns_clause .= qq ~
		$element->[1] AS '$element->[2]'~;
        $colnameidx{$element->[0]} = $i;

        $i++;
      }


      $sql_query = qq~
	SELECT *
	  FROM $TBBS_BIOSAP_SEARCH BSR
	  LEFT JOIN $TBBS_FEATURAMA_PARAMETER FP ON ( BSR.biosap_search_id = FP.biosap_search_id )
	  LEFT JOIN $TBBS_FEATURAMA_STATISTIC FS ON ( BSR.biosap_search_id = FS.biosap_search_id )
	  LEFT JOIN $TBBS_FILTERBLAST_STATISTIC FBS ON ( BSR.biosap_search_id = FBS.biosap_search_id )
	 ORDER BY BSR.biosap_search_id
     ~;


      %url_cols = (
      );

      %hidden_cols = (
      );


    } else {
      $apply_action="BAD SELECTION";
    }


    if ($apply_action eq "QUERY") {
      #print "<PRE>$sql_query</PRE><BR>\n";
      $sbeams->displayQueryResult(sql_query=>$sql_query,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols);


    } else {
      print "<H4>Select parameters above and press QUERY\n";
    }


} # end printEntryForm








