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

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Proteomics;
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

    my $search_hit_id  = $q->param('search_hit_id');


    #### Set some specific settings for this program
    my $CATEGORY="BioSequence Search";
    $TABLE_NAME="PR_BrowseBioSequence" unless ($TABLE_NAME);
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
    $parameters{row_limit} = 1000;
      ($parameters{row_limit} > 0 && $parameters{row_limit}<=99999);
    my $limit_clause = "TOP $parameters{row_limit}";


    #### Define the desired columns
    my @column_array = (
      ["biosequence_id","BS.biosequence_id","biosequence_id"],
      ["biosequence_set_id","BS.biosequence_set_id","biosequence_set_id"],
      ["set_tag","BSS.set_tag","set_tag"],
      ["biosequence_name","BS.biosequence_name","biosequence_name"],
      ["biosequence_gene_name","BS.biosequence_gene_name","gene_name"],
      ["accessor","DBX.accessor","accessor"],
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
        FROM $TBPR_BIOSEQUENCE BS
        LEFT JOIN $TBPR_BIOSEQUENCE_SET BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
        LEFT JOIN $TB_DBXREF DBX ON ( BS.dbxref_id = DBX.dbxref_id )
       WHERE 1 = 1
      $biosequence_set_clause
      $biosequence_name_clause
      $biosequence_gene_name_clause
      $biosequence_seq_clause
      $biosequence_desc_clause
      $order_by_clause
     ~;


    %url_cols = ('set_tag' => "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=biosequence_set&biosequence_set_id=\%$colnameidx{biosequence_set_id}V",
                 'accession' => "\%$colnameidx{accessor}V\%$colnameidx{accesssion}V",
    );

    %hidden_cols = ('biosequence_set_id' => 1,
                    'biosequence_id' => 1,
                    'accessor' => 1,
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


      #### If a search_hit_id was supplied, give the user the option of
      #### updating the search_hit with a new protein
      my $nrows = @{$resultset_ref->{data_ref}};
      if ($search_hit_id && $nrows > 1) {
        print qq~
		<FORM METHOD="post" ACTION="$PROGRAM_FILE_NAME"><BR><BR>
		There are multiple proteins that contain this peptide.  If you
		want to set a different protein as the preferred one, select it
		from the list box below and click [UPDATE]<BR><BR>
		<SELECT NAME="biosequence_id" SIZE=5>
        ~;

        my $biosequence_id_colindex =
          $resultset_ref->{column_hash_ref}->{biosequence_id};
        my $biosequence_name_colindex =
          $resultset_ref->{column_hash_ref}->{biosequence_name};
        foreach $element (@{$resultset_ref->{data_ref}}) {
          print "<OPTION VALUE=\"",$element->[$biosequence_id_colindex],"\">",
            $element->[$biosequence_name_colindex],"</OPTION>\n";
        }

        print qq~
		</SELECT><BR><BR>
		<INPUT TYPE="hidden" NAME="search_hit_id"
		  VALUE="$search_hit_id">
		&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
		<INPUT TYPE="submit" NAME="apply_action" VALUE="UPDATE">
		</FORM><BR><BR>
        ~;

      }


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

  my ($i,$element,$key,$value,$line,$result,$sql);
  my %parameters;

  my $CATEGORY="BioSequence Search";
  my $TABLE_NAME="search_hit";

  $sbeams->printUserContext();
  print qq~
	<P>
	<H2>Return Status</H2>
	$LINESEPARATOR
	<P>
  ~;


  #### Define the possible passed parameters
  my @columns = ("search_hit_id","biosequence_id");


  #### Read the form values for each column
  foreach $element (@columns) {
    $parameters{$element}=$q->param($element);
    #print "$element = $parameters{$element}<BR>\n";
  }


  #### verify that needed parameters were passed
  unless ($parameters{search_hit_id} && $parameters{biosequence_id}) {
    print "ERROR: not all needed parameters were passed.  This should never ".
      "happen!  Record was not updated.<BR>\n";
    return;
  }


  #### Determine what the biosequence_name for this sequence is
  $sql = "SELECT biosequence_name FROM $TBPR_BIOSEQUENCE ".
         " WHERE biosequence_id = '$parameters{biosequence_id}'";
  my ($biosequence_name) = $sbeams->selectOneColumn($sql);
  unless ($biosequence_name) {
    print "ERROR: Unable to determine the biosequence_name for biosequence_id".
      " = '$parameters{biosequence_id}'.  This really should never ".
      "happen!  Record was not updated.<BR>\n";
    return;
  }


  #print "biosequence_name = $biosequence_name<BR><BR><BR>\n";


  #### Prepare the new information into a hash
  my %rowdata;
  $rowdata{biosequence_id} = $parameters{biosequence_id};
  $rowdata{reference} = $biosequence_name;


  #### Insert the data into the database
  $result = $sbeams->insert_update_row(update=>1,
    table_name=>"$TBPR_SEARCH_HIT",
    rowdata_ref=>\%rowdata,PK=>"search_hit_id",
    PK_value => $parameters{search_hit_id},
    #,verbose=>1,testonly=>1
  );


  my $back_button = $sbeams->getGoBackButton();
  if ($result) {
    print qq~
	<B>UPDATE was successful!</B><BR><BR>
	Please note that although the data has
	been changed in the database, previous web pages will still show the
	old value.  Redo the [QUERY] to see the updated data table<BR><BR>
	<CENTER>$back_button</CENTER>
	<BR><BR>
    ~;
  } else {
    print qq~
	UPDATE has failed!  This should never happen.  Please report this<BR>
	<CENTER>$back_button</CENTER>
	<BR><BR>
    ~;
  }


} # end updatePreferredReference


