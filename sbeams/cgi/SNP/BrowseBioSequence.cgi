#!/usr/local/bin/perl

###############################################################################
# Program     : BrowseBioSequence.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               browse through BioSequences.
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

use SBEAMS::SNP;
use SBEAMS::SNP::Settings;
use SBEAMS::SNP::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SNP;
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
    my $apply_action  = $q->param('apply_action');
    my $TABLE_NAME = $q->param("QUERY_NAME");


    #### Set some specific settings for this program
    my $CATEGORY="BioSequence Search";
    $TABLE_NAME="SN_BrowseBioSequence" unless ($TABLE_NAME);
    ($PROGRAM_FILE_NAME) =
      $sbeamsMOD->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");
    my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME";


    #### Get the columns and input types for this table/query
    my @columns = $sbeamsMOD->returnTableInfo($TABLE_NAME,"ordered_columns");
    my %input_types = 
      $sbeamsMOD->returnTableInfo($TABLE_NAME,"input_types");


    #### Read the form values for each column
    my $n_params_found = $sbeams->parse_input_parameters(
      q=>$q,parameters_ref=>\%parameters,
      columns_ref=>\@columns,input_types_ref=>\%input_types);


    #### If the apply action was to recall a previous resultset, do it
    my %rs_params = $sbeams->parseResultSetParams(q=>$q);
    if ($apply_action eq "VIEWRESULTSET") {
      $sbeams->readResultSet(resultset_file=>$rs_params{set_name},
          resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters);
      $n_params_found = 99;
    }


    #### Set some reasonable defaults if no parameters supplied
    unless ($n_params_found) {
    }


    #### Display the user-interaction input form
    $sbeams->display_input_form(
      TABLE_NAME=>$TABLE_NAME,CATEGORY=>$CATEGORY,apply_action=>$apply_action,
      PROGRAM_FILE_NAME=>$PROGRAM_FILE_NAME,
      parameters_ref=>\%parameters,
      input_types_ref=>\%input_types);


    #### Show the QUERY, REFRESH, and Reset buttons
    print qq!
	<INPUT TYPE="hidden" NAME="QUERY_NAME" VALUE="$TABLE_NAME">
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


    #### Finish the upper part of the page and go begin the full-width
    #### data portion of the page
    $sbeams->printPageFooter("CloseTables");
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";



    #########################################################################
    #### Build BIOSEQENCE_SET constraint
    my $biosequence_set_clause = $sbeams->parseConstraint2SQL(
      constraint_column=>"BS.biosequence_set_id",
      constraint_type=>"int_list",
      constraint_name=>"BioSequence Set",
      constraint_value=>$parameters{biosequence_set_id} );
    return if ($biosequence_set_clause == -1);


    #### Build BIOSEQUENCE_NAME constraint
    my $biosequence_name_clause = $sbeams->parseConstraint2SQL(
      constraint_column=>"BS.biosequence_name",
      constraint_type=>"plain_text",
      constraint_name=>"BioSequence Name",
      constraint_value=>$parameters{biosequence_name_constraint} );
    return if ($biosequence_name_clause == -1);


    #### Build BIOSEQUENCE_NAME constraint
    my $biosequence_gene_name_clause = $sbeams->parseConstraint2SQL(
      constraint_column=>"BS.biosequence_gene_name",
      constraint_type=>"plain_text",
      constraint_name=>"BioSequence Gene Name",
      constraint_value=>$parameters{biosequence_gene_name_constraint} );
    return if ($biosequence_gene_name_clause == -1);


    #### Build BIOSEQUENCE_SEQ constraint
    my $biosequence_seq_clause = $sbeams->parseConstraint2SQL(
      constraint_column=>"BS.biosequence_seq",
      constraint_type=>"plain_text",
      constraint_name=>"BioSequence Sequence",
      constraint_value=>$parameters{biosequence_seq_constraint} );
    return if ($biosequence_seq_clause == -1);
    $biosequence_seq_clause =~ s/\*/\%/g;


    #### Build BIOSEQUENCE_DESC constraint
    my $biosequence_desc_clause = $sbeams->parseConstraint2SQL(
      constraint_column=>"BS.biosequence_desc",
      constraint_type=>"plain_text",
      constraint_name=>"BioSequence Description",
      constraint_value=>$parameters{biosequence_desc_constraint} );
    return if ($biosequence_desc_clause == -1);


    #### Build SORT ORDER
    my $order_by_clause = "";
    if ($parameters{sort_order}) {
      if ($parameters{sort_order} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
        print "<H4>Cannot parse Sort Order!  Check syntax.</H4>\n\n";
        return;
      } else {
        $order_by_clause = " ORDER BY $parameters{sort_order}";
      }
    }


    #### Build ROWCOUNT constraint
    $parameters{row_limit} = 1000
      unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=99999);
    my $limit_clause = "TOP $parameters{row_limit}";


    #### Define the desired columns
    my @column_array = (
      ["biosequence_id","BS.biosequence_id","biosequence_id"],
      ["biosequence_set_id","BS.biosequence_set_id","biosequence_set_id"],
      ["set_tag","BSS.set_tag","set_tag"],
      ["uri","BSS.uri","uri"],
      ["biosequence_name","BS.biosequence_name","biosequence_name"],
      ["biosequence_gene_name","BS.biosequence_gene_name","gene_name"],
      ["biosequence_accession","BS.biosequence_accession","accession"],
      ["biosequence_desc","BS.biosequence_desc","description"],
      ["biosequence_seq","BS.biosequence_seq","sequence"],
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
      SELECT $limit_clause $columns_clause
        FROM $TBSN_BIOSEQUENCE BS
        LEFT JOIN $TBSN_BIOSEQUENCE_SET BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
       WHERE 1 = 1
      $biosequence_set_clause
      $biosequence_name_clause
      $biosequence_gene_name_clause
      $biosequence_seq_clause
      $biosequence_desc_clause
      $order_by_clause
     ~;


    %url_cols = ('set_tag' => "$CGI_BASE_DIR/SNP/ManageTable.cgi?TABLE_NAME=biosequence_set&biosequence_set_id=\%$colnameidx{biosequence_set_id}V",
                 'accession' => "\%$colnameidx{uri}V\%$colnameidx{accesssion}V",
    );

    %hidden_cols = ('biosequence_set_id' => 1,
                    'biosequence_id' => 1,
                    'uri' => 1,
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
          max_widths=>\%max_widths,resultset_ref=>$resultset_ref);


      #### Display the resultset controls
      $sbeams->displayResultSetControls(rs_params_ref=>\%rs_params,
          resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters,
	  base_url=>$base_url);



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


