#!/usr/local/bin/perl 

###############################################################################
# Program     : SummarizeExperiment.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that summarizes the data in a proteomics
#               experiment.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsPROT $dbh $current_contact_id $current_username
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

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

use lib "/net/arrays/Pipeline/tools/lib";
require "QuantitationFile.pl";

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsPROT = new SBEAMS::Proteomics;
$sbeamsPROT->setSBEAMS($sbeams);


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
    $sbeamsPROT->printPageHeader();
    processRequests();
    $sbeamsPROT->printPageFooter();


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
    if ($q->param('PROCESS')) { submitJob();
    } else { printEntryForm();
    }


} # end processRequests



###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

    my %parameters;
    my $element;
    my $sql_query;
    my (%url_cols,%hidden_cols);

    my $CATEGORY="Summarize Experiments";


    my $apply_action  = $q->param('apply_action');
    $parameters{experiment_id} = join(",",$q->param('experiment_id'));


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
	SELECT experiment_id,username+' - '+experiment_name
	  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
	  LEFT JOIN $TB_USER_LOGIN UL ON ( PE.contact_id=UL.contact_id )
	 WHERE PE.record_status ~= 'D'
	 ORDER BY username,experiment_name
    ~;
    my $optionlist = $sbeams->buildOptionList(
           $sql_query,$parameters{experiment_id},"MULTIOPTIONLIST");


    print qq!
          <TR><TD><B>Experiment:</B></TD>
          <TD><SELECT NAME="experiment_id" MULTIPLE SIZE=5 >
          <OPTION VALUE=""></OPTION>
          $optionlist</SELECT></TD>
          <TD BGCOLOR="E0E0E0">Select the Experiment</TD>
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
    if ($parameters{experiment_id} > 0) {

      #### Define the desired columns
      my @column_array = (
        ["experiment_id","PE.experiment_id","experiment_id"],
        ["username","username","username"],
        ["project_id","P.project_id","project_id"],
        ["project_name","name","project_name"],
        ["experiment_tag","experiment_tag","experiment_tag"],
        ["experiment_name","experiment_name","experiment_name"],
        ["fraction_id","F.fraction_id","fraction_id"],
        ["fraction_tag","F.fraction_tag","fraction_tag"],
        ["TIC_plot","'TIC Plot'","TIC_plot"],
        ["n_scans","COUNT(*)","# CID spectra"],
      );

      my $columns_clause = "";
      my $group_by_clause = "";
      my $i = 0;
      my %colnameidx;
      foreach $element (@column_array) {
	$columns_clause .= "," if ($columns_clause);
        $columns_clause .= qq ~
		$element->[1] AS '$element->[2]'~;
        $colnameidx{$element->[0]} = $i;

	if ($element->[0] ne 'n_scans' && $element->[0] ne 'TIC_plot') {
	  $group_by_clause .= "," if ($group_by_clause);
	  $group_by_clause .= $element->[1];
	}
        $i++;
      }


      $sql_query = qq~
	SELECT $columns_clause
	  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
	  JOIN $TB_USER_LOGIN UL ON (PE.contact_id=UL.contact_id)
	  JOIN $TB_PROJECT P ON (PE.project_id=P.project_id)
	  JOIN $TBPR_FRACTION F ON (PE.experiment_id=F.experiment_id)
	  JOIN $TBPR_MSMS_SPECTRUM S ON (F.fraction_id=S.fraction_id)
	 WHERE P.record_status!='D'
	   AND UL.record_status!='D'
	   AND PE.record_status!='D'
	   AND PE.experiment_id IN ( $parameters{experiment_id} )
	 GROUP BY $group_by_clause
	 ORDER BY experiment_tag,fraction_tag
     ~;

      my $base_url = "$CGI_BASE_DIR/ManageTable.cgi?TABLE_NAME=";
      %url_cols = ('project_name' => "${base_url}project&project_id=\%$colnameidx{project_id}V",
                   'experiment_name' => "${base_url}proteomics_experiment&experiment_id=\%$colnameidx{experiment_id}V", 
                   'TIC_plot' => "$CGI_BASE_DIR/Proteomics/ShowTICPlot.cgi?fraction_id=\%$colnameidx{fraction_id}V", 
      );

      %hidden_cols = ('experiment_id' => 1,
                      'project_id' => 1,
                      'fraction_id' => 1,
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








