#!/usr/local/bin/perl

###############################################################################
# Program     : ShowESTLibrary.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               see a list of EST Libraries that have something in them
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsMOD $dbh $current_contact_id $current_username
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::BEDB;
use SBEAMS::BEDB::Settings;
use SBEAMS::BEDB::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::BEDB;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate and exit if it fails or continue if it works.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Print the header, do what the program does, and print footer
    $sbeamsMOD->printPageHeader();
    processRequests();
    $sbeamsMOD->printPageFooter();

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

    #$sbeams->printDebuggingInfo($q);

    my $apply_action  = $q->param('apply_action');
    if ($apply_action eq "UPDATE") {
      updatePreferredReference();
    } else {
      printEntryForm();
    }

} # end processRequests



###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

    my ($i,$element,$key,$value,$line,$result,$sql);
    my %parameters;
    my %resultset = ();
    my $resultset_ref = \%resultset;
    my (%url_cols,%hidden_cols,%max_widths,$show_sql);


    #### Read in the standard form values
    my $apply_action  = $q->param('apply_action') || "QUERY";
    my $TABLE_NAME = $q->param("QUERY_NAME");


    #### Set some specific settings for this program
    my $CATEGORY="Show EST Libraries";
    $TABLE_NAME="BE_ShowESTLibrary" unless ($TABLE_NAME);
    my $base_url = "";


    #### If the apply action was to recall a previous resultset, do it
    my %rs_params = $sbeams->parseResultSetParams(q=>$q);
    if ($apply_action eq "VIEWRESULTSET") {
      $sbeams->readResultSet(resultset_file=>$rs_params{set_name},
          resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters);
    }


    #### Finish the upper part of the page and go begin the full-width
    #### data portion of the page
    #$sbeams->printPageFooter("CloseTables");
    #print "<BR><HR SIZE=5 NOSHADE><BR>\n";
    print qq~
      <BR>The Brain Expression database contains data from the following
      EST Libraries:<BR>
      <BR>
    ~;


    #### Define the desired columns
    my @column_array = (
      ["est_library_id","EL.est_library_id","est_library_id"],
      ["library_name","EL.library_name","Library Name"],
      ["description","EL.description","Description"],
      ["unigene_library_id","EL.unigene_library_id","unigene_library_id"],
      ["n_chromats","EL.n_chromats","Available Chromats"],
      ["n_good_ests","EL.n_good_ests","Good ESTs"],
      ["n_distinct_genes","EL.n_distinct_genes","Distinct Genes"],
      ["processed_date","SUBSTRING(CONVERT(varchar(25),EL.processed_date,121),1,10)","Date Processed"],
      ["keywords","EL.keywords","Keywords"],
    );


    #### Adjust the columns definition based on user-selected options
    if ( $parameters{display_options} =~ /MaxSeqWidth/ ) {
      $max_widths{'sequence'} = 100;
    }
    if ( $parameters{display_options} =~ /ShowSQL/ ) {
      $show_sql = 1;
    }


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


    $sql = qq~
      SELECT $columns_clause
        FROM $TBBE_EST_LIBRARY EL
       WHERE n_chromats > 0
       ORDER BY library_name
     ~;


    %url_cols = ('Library Name' => "http://www.ncbi.nlm.nih.gov/cgi-bin/UniGene/lib?ORG=Hs&LID=\%$colnameidx{unigene_library_id}V",
                 'Library Name_ATAG' => 'TARGET="Win2"',
                 'Distinct Genes' => "$CGI_BASE_DIR/$SBEAMS_SUBDIR/getAnnotation?est_library_id=\%$colnameidx{est_library_id}V&sort_order=COUNT(*)%20DESC&apply_action=HIDEQUERY",
                 'Distinct Genes_ATAG' => 'TARGET="Win2"',
                 'Available Chromats' => "$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseEST.cgi?est_library_id=\%$colnameidx{est_library_id}V&apply_action=HIDEQUERY",
                 'Available Chromats_ATAG' => 'TARGET="Win2"',
    );

    %hidden_cols = ('est_library_id' => 1,
                    'unigene_library_id' => 1,
     );


    #########################################################################
    #### If QUERY or VIEWRESULTSET was selected, display the data
    if ($apply_action =~ /QUERY/i || $apply_action eq "VIEWRESULTSET") {

      #### Show the SQL that will be or was executed
      print "<PRE>$sql</PRE><BR>\n" if ($show_sql);

      #### If the action contained QUERY, then fetch the results from
      #### the database
      if ($apply_action =~ /QUERY/i) {

        #### Fetch the results from the database
        $sbeams->fetchResultSet(sql_query=>$sql,
          resultset_ref=>$resultset_ref);

        #### Store the resultset and parameters to disk
        $rs_params{set_name} = "SETME";
        $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
          resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters);
      }


      #### Display the resultset
      $sbeams->displayResultSet(page_size=>$rs_params{page_size},
	  page_number=>$rs_params{page_number},
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols,
          max_widths=>\%max_widths,resultset_ref=>$resultset_ref,
          table_width=>'fit_to_page',
          row_color_scheme_ref=>$sbeamsMOD->getTableColorScheme());


      #### Display the resultset controls
      #$sbeams->displayResultSetControls(rs_params_ref=>\%rs_params,
      #    resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters,
      #    base_url=>$base_url);



    #### If QUERY was not selected, then tell the user to enter some parameters
    } else {
      print "<H4>Select parameters above and press QUERY</H4>\n";
    }


    print "<BR><BR>\n";

} # end printEntryForm



###############################################################################
# evalSQL: Callback for translating global table variables to names
###############################################################################
sub evalSQL {
  my $sql = shift;

  return eval "\"$sql\"";

} # end evalSQL



###############################################################################
# updatePreferredReference
###############################################################################
sub updatePreferredReference {


} # end updatePreferredReference


