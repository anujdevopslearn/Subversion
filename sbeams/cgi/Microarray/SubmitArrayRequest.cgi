#!/usr/local/bin/perl

###############################################################################
# Program     : SubmitArrayRequest.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               submit array requests.
#               This means viewing, inserting, updating,
#               and deleting records.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsMOD $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS
             $DEFAULT_COST_SCHEME);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::TableInfo;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Global Variables
###############################################################################
$TABLE_NAME = "array_request";
$DEFAULT_COST_SCHEME = 1;
main();


###############################################################################
# Main Program:
#
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main { 

    ($CATEGORY) = $sbeamsMOD->returnTableInfo($TABLE_NAME,"CATEGORY");
    ($PROGRAM_FILE_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");
    ($DB_TABLE_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,"DB_TABLE_NAME");
    ($PK_COLUMN_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,"PK_COLUMN_NAME");
    @MENU_OPTIONS = $sbeamsMOD->returnTableInfo($TABLE_NAME,"MENU_OPTIONS");

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Don't print the header, do what the program does, and print footer
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
    $current_work_group_id = $sbeams->getCurrent_work_group_id;
    $current_work_group_name = $sbeams->getCurrent_work_group_name;
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

    # Decide where to go based on form values
    if      ($q->param('apply_action') eq 'VIEWRESULTSET') { printOptions();
    } elsif ($q->param('apply_action')) { processEntryForm();
    } elsif ($q->param('ShowEntryForm')) { printEntryForm();
    } elsif ($q->param("$PK_COLUMN_NAME")) { printEntryForm();
    } else { printOptions();
    } # end if

} # end processRequests


###############################################################################
# Print Options Page
###############################################################################
sub printOptions {

    $sbeamsMOD->printPageHeader();
    $sbeams->printUserContext();

    print qq!
        <P>
        <H2>$DBTITLE $CATEGORY Maintenance</H2>
        $LINESEPARATOR
    !;

    for (my $option=0; $option<$#MENU_OPTIONS; $option+=2) {
      print qq!
        $OPTIONARROW
        <A HREF="@MENU_OPTIONS[$option+1]">@MENU_OPTIONS[$option]</A>
      !;
    }

    print "$LINESEPARATOR<P>";


    #### Read in the default input parameters
    my %parameters;
    my $n_params_found = $sbeams->parse_input_parameters(
      q=>$q,parameters_ref=>\%parameters);

    #### Close the upper portion of the page and get ready for data table
    #$sbeamsMOD->printPageFooter(close_table=>"YES",display_footer=>"NO");

    #### Display the data table
    showTable(with_options=>'YES',parameters_ref=>\%parameters);

    #### Close the upper portion of the page and get ready for data table
    $sbeamsMOD->printPageFooter(close_table=>"YES",display_footer=>"NO");

} # end printOptions




###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

    $sbeamsMOD->printPageHeader();
    $sbeams->printUserContext();

    my %parameters;
    my $element;
    my $sql_query;
    my $username;
    my $proc_cost=0;
    my $total_price=0;

    # Get the columns for this table
    my @columns = $sbeamsMOD->returnTableInfo($TABLE_NAME,"ordered_columns");
    my %input_types = 
      $sbeamsMOD->returnTableInfo($TABLE_NAME,"input_types");

    # Read the form values for each column
    foreach $element (@columns) {
        $parameters{$element}=$q->param($element);
    }


    my $apply_action  = $q->param('apply_action');
    my $ignore_table  = $q->param('ignore_table');


    # ---------------------------
    # If a specific PK row was referenced and this is not a REFRESH of an
    # existing record, then load data from it into hash
    if ($parameters{$PK_COLUMN_NAME} gt "" && $apply_action ne "REFRESH") {
      $sql_query = qq!
        SELECT *
          FROM $DB_TABLE_NAME
         WHERE $PK_COLUMN_NAME='$parameters{$PK_COLUMN_NAME}'!;
      my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
      my $rv  = $sth->execute or croak $dbh->errstr;

      my @row = $sth->fetchrow_array;
      for ($element=0; $element<=$#row; $element++) {
          $parameters{$columns[$element]}=$row[$element];
      }

      $sth->finish;
    }


    $parameters{request_status}="Not Yet Submitted"
      if ( ! ($parameters{request_status}));


    #### Extract the value of cost_scheme_id or default to 1.
    #### FIX ME!! Do we have to hard-code the default value here??
    #print "cost_scheme_id=",$parameters{cost_scheme_id},"=<BR>\n";
    #print "DEFAULT_COST_SCHEME=",$DEFAULT_COST_SCHEME,"=<BR>\n";
    $parameters{cost_scheme_id} = $DEFAULT_COST_SCHEME unless ( $parameters{cost_scheme_id} >= 1 );
    my $cost_scheme_id = $parameters{cost_scheme_id};
    #print "cost_scheme_id=",$parameters{cost_scheme_id},"=<BR>\n";


    my $record_status_options =
      $sbeams->getRecordStatusOptions($parameters{"record_status"});


    print qq!
        <P>
        <H2>Manage ${CATEGORY}s</H2>
        <TABLE><TR><TD>
        Fill out this form to submit a new array job request, or modify existing
        fields to change the request.  Once jobs have been Started they cannot be
        modified unless reverted to Submitted status.  Required fields are labeled
        in <font color="red">red</font>.
        </TD></TR></TABLE>
        $LINESEPARATOR
        <FORM METHOD="post">
        <TABLE>
    !;


    # ---------------------------
    # Query to obtain column information about the table being managed
    $sql_query = qq~
	SELECT column_name,column_title,is_required,input_type,input_length,
	       is_data_column,column_text,optionlist_query
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$DB_TABLE_NAME'
	   AND is_data_column='Y'
	 ORDER BY column_index
    ~;
    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;


    # ---------------------------
    # First just extract any valid optionlist entries.  This is done
    # first as opposed to within the loop below so that a single DB connection
    # can be used.
    my %optionlist_queries;
    while (my @row = $sth->fetchrow_array) {
      my ($column_name,$column_title,$is_required,$input_type,$input_length,
          $is_data_column,$column_text,$optionlist_query) = @row;
      if ($optionlist_query gt "") {
        $optionlist_queries{$column_name}=$optionlist_query;
      }
    }
    $sth->finish;


    # ---------------------------
    # Build option lists for each optionlist query provided for this table
    my %optionlists;
    foreach $element (keys %optionlist_queries) {

        # If "$contact_id" appears in the SQL optionlist query, then substitute
        # that with either a value of $parameters{contact_id} if it is not
        # empty, or otherwise replace with the $current_contact_id
        if ( $optionlist_queries{$element} =~ /\$contact_id/ ) {
          if ( $parameters{"contact_id"} eq "" ) {
            $optionlist_queries{$element} =~
                s/\$contact_id/$current_contact_id/;
          } else {
            $optionlist_queries{$element} =~
                s/\$contact_id/$parameters{contact_id}/;
          }
        }

        # If "$cost_scheme_id" appears in the SQL optionlist query, then substitute
        # that with the value of the current variable of the same name
        if ( $optionlist_queries{$element} =~ /\$cost_scheme_id/ ) {
          $optionlist_queries{$element} =~
              s/\$cost_scheme_id/$cost_scheme_id/;
        }


        #### If $element is cost_scheme, restrict the list to the current option
        #### unless the user is working under the Arrays group
        if ( $element eq "cost_scheme_id" && $current_work_group_name ne "Arrays" ) {
          $optionlist_queries{$element} =~
            s/ORDER BY/WHERE cost_scheme_id = $cost_scheme_id ORDER BY/;
        }

        #### Evaluate the $TBxxxxx table name variables if in the query
        if ( $optionlist_queries{$element} =~ /\$TB/ ) {
          $optionlist_queries{$element} =
            eval "\"$optionlist_queries{$element}\"";
        }

        #### Set the MULTIOPTIONLIST flag if this is a multi-select list
        my $method_options;
        $method_options = "MULTIOPTIONLIST"
          if ($input_types{$element} eq "multioptionlist");

        # Build the option list
        #print $optionlist_queries{$element},"<BR>\n",$parameters{$element},"<BR>\n";
        $optionlists{$element}=$sbeams->buildOptionList(
           $optionlist_queries{$element},$parameters{$element},$method_options);
    }


    # ---------------------------
    # Redo query to obtain column information about the table being managed
    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    while (my @row = $sth->fetchrow_array) {
      my ($column_name,$column_title,$is_required,$input_type,$input_length,
          $is_data_column,$column_text,$optionlist_query) = @row;

      if ($is_required eq "N") { print "<TR><TD><B>$column_title:</B></TD>\n"; }
      else { print "<TR><TD><B><font color=red>$column_title:</font></B></TD>\n"; }

      if ($input_type eq "text") {
        print qq!
          <TD><INPUT TYPE="$input_type" NAME="$column_name"
           VALUE="$parameters{$column_name}" SIZE=$input_length></TD>
        !;
      }

      if ($input_type eq "textarea") {
        print qq!
          <TD><TEXTAREA NAME="$column_name" rows=$input_length cols=40>$parameters{$column_name}</TEXTAREA></TD>
        !;
      }

      if ($input_type eq "fixed") {
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">$parameters{$column_name}</TD>
        !;
      }

      if ($input_type eq "optionlist") {
        print qq!
          <TD><SELECT NAME="$column_name">
          <OPTION VALUE=""></OPTION>
          $optionlists{$column_name}</SELECT></TD>
        !;
      }

      if ($input_type eq "current_contact_id") {
        if ($parameters{$column_name} eq "") {
            $parameters{$column_name}=$current_contact_id;
            $username=$current_username;
        } else {
            if ( $parameters{$column_name} == $current_contact_id) {
              $username=$current_username;
            } else {
              $username=$sbeams->getUsername($parameters{$column_name});
            }
        }
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">$username</TD>
        !;
      }

    print qq!
      <TD BGCOLOR="E0E0E0">$column_text</TD></TR>
    !;

    }
    $sth->finish;
    print "</TABLE>";


#################################################

    my (@row_result,$isample);
    my $n_slides=$parameters{"n_slides"};
    my $n_samples=$parameters{"n_samples_per_slide"};
    if ($n_slides > 50) { $n_slides=50; }
    $n_slides=0 unless ($n_slides >= 1 && $n_slides <=50);
    $n_samples=2 unless ($n_samples >= 1 && $n_samples <=3);

    my %table_parameters;
    if ($n_slides > 0) {
      # Make a list of parameters for the table
      for $element (0..($n_slides-1)) {
        $table_parameters{"slide${element}id"}="";
        for $isample (0..($n_samples-1)) {
          $table_parameters{"sample${isample}name_$element"}="";
          $table_parameters{"sample${isample}labmeth_$element"}="";
          $table_parameters{"sample${isample}id_$element"}="";
         }
      }


      # Read the form values for each column
      foreach $element (keys %table_parameters) {
        $table_parameters{$element}=$q->param($element);
      }


    # ---------------------------
    # If a specific PK row was referenced, load data from it into hash
    if ($parameters{$PK_COLUMN_NAME} gt "") {
      $sql_query = qq!
        SELECT array_request_id,slide_index,sample_index,name,
               labeling_method_id,SLI.array_request_slide_id,
               array_request_sample_id
          FROM $TB_ARRAY_REQUEST_SAMPLE SAM
          FULL JOIN $TB_ARRAY_REQUEST_SLIDE SLI ON (
               SAM.array_request_slide_id = SLI.array_request_slide_id )
         WHERE $PK_COLUMN_NAME='$parameters{$PK_COLUMN_NAME}'!;
      my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
      my $rv  = $sth->execute or croak $dbh->errstr;

      while (my @row = $sth->fetchrow_array) {
          $table_parameters{"sample$row[2]name_$row[1]"}=$row[3];
          $table_parameters{"sample$row[2]labmeth_$row[1]"}=$row[4];
          $table_parameters{"sample$row[2]id_$row[1]"}=$row[6];
          $table_parameters{"slide$row[1]id"}=$row[5];
      }

      $sth->finish;
    }



      $sql_query = qq~
	SELECT labeling_method_id,name
	  FROM $TB_LABELING_METHOD
	 ORDER BY sort_order,name
      ~;
      my $optionlist=$sbeams->buildOptionList($sql_query);

      my $checked_flag = "";
      if ($ignore_table) { $checked_flag = " CHECKED"; }

      my ($row,$col);
      print qq~
	<P>
	<TABLE WIDTH=600><TR><TD>
	Please fill out the table below with the appropriate sample information.
	If you are not requesting sample hybridization etc. ("Requested Work"
	above), it is still
	recommended that you fill out the table below if you want the database
	to track your arrays; if you want to run your scanned output through
	the standard processing pipeline, this is required!
	</TD></TR><TR><TD>
	The sample names you provide below become the official label of each
	slide.  Entries with identical names are assumed to be repeats and
	will be processed as such by the standard pipeline.  These names will
	be used to link back to your private tables of sample information.
	Use of dates or other unique identifiers for your samples is highly
	encouraged.
        <BR><BR><BR>
      ~;

      if ($parameters{hybridization_request} eq "N" &&
          $parameters{scanning_request} eq "N" ) {
        print qq~
        <INPUT TYPE="checkbox" $checked_flag NAME="ignore_table"
           VALUE="ignore_table">
           Check here if you don't want to fill out the table below.  You
           can skip the table below only if you are just requesting slides
           and intend to do all labeling, hybridization, scanning, etc.
           yourself.
        ~;
      }

      print qq~
	</TD></TR>
	</TABLE>
        <P>
	<TABLE><TR>
	<TH>Slide Index</TH><TH>Slide Request ID</TH>
      ~;

      for $col (1..$n_samples) {
        print "<TH>Sample $col Name</TH><TH>Sample $col ID</TH><TH>Sample $col Labeling Method</TH>\n";
      }
      print "</TR>\n";

      my $thisoptionlist;
      for $row (0..($n_slides-1)) {
        print qq!
		<TR><TD>$row</TD>
		<TD><INPUT NAME="slide${row}id" TYPE="hidden"
		   VALUE="$table_parameters{"slide${row}id"}">
		$table_parameters{"slide${row}id"}</TD>
	!;
        for $col (0..($n_samples-1)) {
          $thisoptionlist=$optionlist;
          if ($table_parameters{"sample${col}labmeth_$row"}) {
            $thisoptionlist =~ s/VALUE="$table_parameters{"sample${col}labmeth_$row"}"/SELECTED VALUE="$table_parameters{"sample${col}labmeth_$row"}"/g;
          }
          print qq!
		<TD><INPUT NAME="sample${col}name_$row" TYPE="text"
		   VALUE="$table_parameters{"sample${col}name_$row"}" SIZE=25></TD>
		<TD><INPUT NAME="sample${col}id_$row" TYPE="hidden"
		   VALUE="$table_parameters{"sample${col}id_$row"}">
		   $table_parameters{"sample${col}id_$row"}</TD>
		<TD><SELECT NAME="sample${col}labmeth_$row">
		<OPTION VALUE=""></OPTION>
		$thisoptionlist</SELECT></TD>
          !;

          if ($table_parameters{"sample${col}labmeth_$row"}) {
            $sql_query = qq!
		SELECT price
		  FROM $TB_LABELING_METHOD
		 WHERE labeling_method_id='$table_parameters{"sample${col}labmeth_$row"}'
            !;
            @row_result = $sbeams->selectOneColumn($sql_query);
            $proc_cost = $proc_cost + $row_result[0];
          }

        }
      print "</TR>";
      }
      print "</TABLE>\n";


      if ($parameters{"slide_type_id"}) {
        $sql_query = qq!
		SELECT $n_slides * STC.price
		  FROM $TB_SLIDE_TYPE ST
		  JOIN $TB_SLIDE_TYPE_COST STC ON ( ST.slide_type_id = STC.slide_type_id )
		 WHERE ST.slide_type_id='$parameters{"slide_type_id"}'
		   AND STC.cost_scheme_id = $cost_scheme_id
        !;
        @row_result = $sbeams->selectOneColumn($sql_query);
        my ($slide_cost) = @row_result;

        print "<P>Slide Cost: \$ $slide_cost (includes printing if selected)<P>\n";
        $total_price += $slide_cost;

      }


      #### If the Arrays Group does both Labeling and Hyb
      if ( $parameters{"hybridization_request"} =~ /LH/ ) {
        print "<P>Total Label/Hyb Cost: \$ $proc_cost<P>\n";
        $total_price += $proc_cost;

      #### Else if the user does Labeling and the Arrays Group does Hyb
      } elsif ( $parameters{"hybridization_request"} eq "L" ) {
        my $hyb_price = 50;
        #### Kludge the Yeast Half Slide price to $25
        $hyb_price = 25 if ($parameters{"slide_type_id"} == 11);
        $proc_cost = $n_slides *  $hyb_price;
        print "<P>Total Hyb Cost: \$ $proc_cost<P>\n";
        $total_price += $proc_cost;

      #### Else the user does it all
      } else {
        print "<P>Label/Hyb Cost: (you have chosen to do this yourself)<P>\n";
      }


      if ($parameters{"scanning_request"}) {
        $sql_query = qq!
		SELECT $n_slides * price
		  FROM $TB_ARRAY_REQUEST_OPTION
		 WHERE option_key='$parameters{"scanning_request"}'
		   AND option_type='scanning_request'
        !;
        @row_result = $sbeams->selectOneColumn($sql_query);
        my ($analysis_cost) = @row_result;

        print "<P>Analysis Cost: \$ $analysis_cost<P>\n";
        $total_price += $analysis_cost;

      }



      print "<P>Total Cost: \$ $total_price<P>\n";


    } else {
      print qq!
             <B>Please select the number of desired slides above and
             click REFRESH below.<BR>
      !;
    }



    print qq!
        <TABLE>
        <TR><TD><B>record_status:</B></TD>
        <TD><SELECT NAME="record_status">
            $record_status_options
            </SELECT></TD>
        </TR><TR>
        <TD COLSPAN=2 BGCOLOR="#EEEEFF">
        <INPUT TYPE="hidden" NAME="price" VALUE="$total_price">
        <INPUT TYPE="hidden" NAME="TABLE_NAME" VALUE="$TABLE_NAME">
        !;


       # Once a record is no longer in the Submitted Phase, it can't be changed
       if ($parameters{request_status} =~ /Submit/) {

         # If a specific record was passed, display UPDATE options
         if ($parameters{$PK_COLUMN_NAME} gt "") {
           # Don't allow INSERTs here because this is just too dangerous.
           print qq!
              <INPUT TYPE="hidden" NAME="$PK_COLUMN_NAME"
                VALUE="$parameters{$PK_COLUMN_NAME}">
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
              <INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH"> this form<BR>
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
              <INPUT TYPE="submit" NAME="apply_action" VALUE="VIEW"> this request in a PRINTABLE VIEW<BR>
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
              <INPUT TYPE="submit" NAME="apply_action" VALUE="UPDATE"> this request with this new data<BR>
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
              <INPUT TYPE="submit" NAME="apply_action" VALUE="DELETE"> this request<BR>
           !;
         } else {
           print qq!
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH"> this form<BR>
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="submit" NAME="apply_action" VALUE="INSERT"> new request with this information<BR>
           !;
         }

       } else {
         print qq!
           <INPUT TYPE="hidden" NAME="$PK_COLUMN_NAME"
               VALUE="$parameters{$PK_COLUMN_NAME}">
           &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
           <INPUT TYPE="submit" NAME="apply_action" VALUE="VIEW"> this request in a PRINTABLE VIEW<BR>
           This job has already been started.  Changes may no longer be made.
           Contact the Arrays group directly if there are problems.<P>
         !;
       }

   print qq!
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="reset" VALUE="CLEAR"> fields
         </TR></TABLE>
         $LINESEPARATOR
   !;


    # If this is a not a new entry and the work_group is Arrays, allow
    # more options:
    if ($parameters{$PK_COLUMN_NAME} gt ""
        && $current_work_group_name eq "Arrays") {

      print qq!
        <TABLE>
        <TR>
        <TD COLSPAN=2 BGCOLOR="#EEFFEE">
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
              <INPUT TYPE="submit" NAME="apply_action" VALUE="SETSUBMITTED"> Set this request status to Submitted<BR>
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
              <INPUT TYPE="submit" NAME="apply_action" VALUE="SETSTARTED"> Set this request status to Started<BR>
              &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
              <INPUT TYPE="submit" NAME="apply_action" VALUE="SETFINISHED"> Set this request status to Finished<BR>
        </TD></TR></TABLE>
      !;
    }


    print qq!
         </FORM>
         <P>
    !;


    $sbeamsMOD->printPageFooter("CloseTables");

} # end printEntryForm


###############################################################################
# show Table
#
# Displays the Table
###############################################################################
sub showTable {
  my %args = @_;

  #### Process the arguments list
  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};
  my $with_options = $args{'with_options'};


  #### Get the specified level of detail or set to BASIC
  my $detail_level = $q->param('detail_level') || "BASIC";
  my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME";
  my $apply_action  = $parameters{'action'} || $parameters{'apply_action'};


  #### Get the query to show this table
  my ($main_query_part) =
    $sbeamsMOD->returnTableInfo($TABLE_NAME,$detail_level."Query",
    $query_parameters_ref);

  #### Display the table controls
  my ($full_where_clause,$full_orderby_clause) = 
    $sbeams->processTableDisplayControls($TABLE_NAME);


  #### If a new ORDER BY clause is specified, remove the default one
  if ($full_orderby_clause) {
    $main_query_part =~ s/\s*ORDER BY.*//i;
  }


  #### Build the final query
  my $sql_query = qq~
      $main_query_part
      $full_where_clause
      $full_orderby_clause
  ~;
  #print "<PRE>$sql_query\n\n</PRE>";


  #### Get the url link data
  my %url_cols = $sbeamsMOD->returnTableInfo($TABLE_NAME,"url_cols");


  #### Define some variables for the resultset
  my %resultset = ();
  my $resultset_ref = \%resultset;

  #### If the apply action was to recall a previous resultset, do it
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  if ($apply_action eq "VIEWRESULTSET") {
    $sbeams->readResultSet(
       resultset_file=>$rs_params{set_name},
       resultset_ref=>$resultset_ref,
       query_parameters_ref=>\%parameters
    );


  #### Otherwise fetch the results from the database server
  } else {

    #### Fetch the results from the database server
    $sbeams->fetchResultSet(sql_query=>$sql_query,
      resultset_ref=>$resultset_ref);
  
    #### Store the resultset and parameters to disk resultset cache
    $rs_params{set_name} = "SETME";
    $sbeams->writeResultSet(
      resultset_file_ref=>\$rs_params{set_name},
      resultset_ref=>$resultset_ref,
      query_parameters_ref=>\%parameters
    );
  }


  #### Display the resultset
  $sbeams->displayResultSet(
    rs_params_ref=>\%rs_params,
    url_cols_ref=>\%url_cols,
    #hidden_cols_ref=>\%hidden_cols,
    #max_widths=>\%max_widths,
    resultset_ref=>$resultset_ref,
    #column_titles_ref=>\@column_titles,
    base_url=>$base_url,
    query_parameters_ref=>\%parameters,
  );


  #### Display the resultset controls
  $sbeams->displayResultSetControls(
    rs_params_ref=>\%rs_params,
    resultset_ref=>$resultset_ref,
    query_parameters_ref=>\%parameters,
    base_url=>$base_url
  );


} # end showTable



###############################################################################
# Process Entry Form
#
###############################################################################
sub processEntryForm {
    my %parameters;
    my $element;
    my $sql_query;
    my $tmp;
    my $proc_cost=0;
    my $total_price=0;

    # Get the columns for this table
    my @columns = $sbeamsMOD->returnTableInfo($TABLE_NAME,"ordered_columns");

    # Read the form values for each column
    foreach $element (@columns) {
        $parameters{$element}=$q->param($element);
        #print "$element=$parameters{$element}=<BR>\n";
    }

    my $apply_action  = $q->param('apply_action');
    my $ignore_table  = $q->param('ignore_table');


    if ($apply_action eq "REFRESH") {
      printEntryForm();
      exit;
    }

    if ($apply_action eq "VIEW") {
      printCompletedEntry();
      exit;
    }


    $sbeamsMOD->printPageHeader();

    if ($parameters{"request_status"} eq "Not Yet Submitted") {
      $parameters{"request_status"}="Submitted";
    }
    if ($parameters{"request_status"} ne "Submitted" &&
        ! ($apply_action =~ /^SET/) ) {
      print "Cannot change a record that has already been started<BR>\n";
      return;
    }


    #### Extract the value of cost_scheme_id or default to 1.
    #### FIX ME!! Do we have to hard-code the default value here??
    $parameters{cost_scheme_id} = $DEFAULT_COST_SCHEME unless ( $parameters{cost_scheme_id} >= 1 );
    my $cost_scheme_id = $parameters{cost_scheme_id};


    # Check for missing required information
    my @required_columns = 
      $sbeamsMOD->returnTableInfo($TABLE_NAME,"required_columns");
    if (@required_columns) {
      my $error_message;
      foreach $element (@required_columns) {
        $error_message .= "<LI> You must provide a <B>$element</B>."
          unless $parameters{$element};
      }
      if ($error_message) {
          $sbeams->printIncompleteForm($error_message);
          return 0;
      }
    }


    # Read all the table information
    my (@row_result,$isample);
    my $n_slides=$parameters{"n_slides"};
    my $n_samples=$parameters{"n_samples_per_slide"};
    if ($n_slides > 50) { $n_slides=50; }
    $n_slides=0 unless ($n_slides >= 1 && $n_slides <=50);
    $n_samples=2 unless ($n_samples >= 1 && $n_samples <=3);

    my %table_parameters;
    if ($n_slides > 0) {
      # Make a list of parameters for the table
      for $element (0..($n_slides-1)) {
        $table_parameters{"slide${element}id"}="";
        for $isample (0..($n_samples-1)) {
          $table_parameters{"sample${isample}name_$element"}="";
          $table_parameters{"sample${isample}labmeth_$element"}="";
          $table_parameters{"sample${isample}id_$element"}="";
         }
      }


      # Read the form values for each column
      my @errors = ();
      foreach $element (keys %table_parameters) {
        $table_parameters{$element}=$q->param($element);
        if ($element =~ /name_/ || $element =~ /labmeth_/) {
          push (@errors,"Missing value for $element.<BR>\n")
            unless ($table_parameters{$element} || $ignore_table);
        }
      }

      if (@errors && ($apply_action ne "DELETE")) {
        print qq!
          @errors
          <P>
          Please go back and fill in all the sample name 
          and labeling information.<BR>\n
        !;
        return;
      }
    }

    my @data_columns = 
      $sbeamsMOD->returnTableInfo($TABLE_NAME,"data_columns");


    # If a PK has already been provided and action is /^SET/ then
    # update the record
    if ($parameters{$PK_COLUMN_NAME} && ($apply_action =~ /^SET/)) {
      $sql_query = "FAILED";
      $sql_query = qq!
                UPDATE $DB_TABLE_NAME SET
                  request_status='Submitted',
                  date_modified=CURRENT_TIMESTAMP,
                  modified_by_id=$current_contact_id
                WHERE $PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}
      ! if ($apply_action eq "SETSUBMITTED");

      $sql_query = qq!
                UPDATE $DB_TABLE_NAME SET
                  request_status='Started',
                  date_modified=CURRENT_TIMESTAMP,
                  modified_by_id=$current_contact_id
                WHERE $PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}
      ! if ($apply_action eq "SETSTARTED");

      $sql_query = qq!
                UPDATE $DB_TABLE_NAME SET
                  request_status='Finished',
                  date_modified=CURRENT_TIMESTAMP,
                  modified_by_id=$current_contact_id
                WHERE $PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}
      ! if ($apply_action eq "SETFINISHED");
    }




    # If a PK has already been provided and action is not INSERT, build
    # SQL statements for DELETE and UPDATE
    if ($parameters{$PK_COLUMN_NAME} &&
         ( ($apply_action eq "UPDATE") || ($apply_action eq "DELETE") ) ) {
        $sql_query = "";

        # Build SQL statement for DELETE record
        if ($apply_action eq "DELETE") {
            $sql_query = qq!
                UPDATE $DB_TABLE_NAME SET
                  date_modified=CURRENT_TIMESTAMP,
                  modified_by_id=$current_contact_id,
                  record_status='D'
                WHERE $PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}
            !;
        }

        if ($apply_action eq "UPDATE") {

            $sql_query = "UPDATE $DB_TABLE_NAME SET ";
            foreach $element (@data_columns) {
              $tmp = $parameters{$element};
              # Change all ' to '' so that it can go in the INSERT statement
              $tmp =~ s/'/''/g;
              $sql_query .= "$element='$tmp',\n";
            }
            $sql_query .= qq!
                  price='$parameters{price}',
                  date_modified=CURRENT_TIMESTAMP,
                  modified_by_id='$current_contact_id',
                  record_status='$parameters{record_status}'
                WHERE $PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}
            !;
        }

        if ($sql_query eq "") {
            print "ERROR: Action '$apply_action' not recognized.<BR>\n";
            return;
        }

    }

    # If the action is INSERT, build a SQL statement for that
    if ($apply_action eq "INSERT") {

        # Since this is a new INSERT, zero out any previous PK
        $parameters{$PK_COLUMN_NAME}=0;

        # Build the column names and VALUES for each data column
        my ($query_part1,$query_part2);
        foreach $element (@data_columns) {
          $query_part1 .= "$element,";

          $tmp = $parameters{$element};
          # Change all ' to '' so that it can go in the INSERT statement
          $tmp =~ s/'/''/g;
          $query_part2 .= "'$tmp',";
        }

        # Build the SQL statement
        $sql_query = qq!
 		INSERT INTO $DB_TABLE_NAME
		  ($query_part1 price,
		  created_by_id,modified_by_id,owner_group_id,record_status)
		VALUES
		  ($query_part2 '$parameters{price}',
		  $current_contact_id, $current_contact_id,
 		  $current_work_group_id,'$parameters{record_status}')
        !;

    }


    # Execute the SQL statement extract status and PK from result
    my @returned_information = $sbeams->applySqlChange("$sql_query",
      $current_contact_id,
      $TABLE_NAME,"$PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}");
    my $returned_request_status = shift @returned_information;
    my $returned_request_PK = shift @returned_information;



    # For most operations, extract the returned PK information
    if ( ( ($apply_action eq "INSERT") || ($apply_action eq "UPDATE") ) &&
        ($returned_request_status eq "SUCCESSFUL") ) {

      # Update the PK information in main parameters hash
      if ( !($parameters{$PK_COLUMN_NAME})) {
        $parameters{$PK_COLUMN_NAME} = $returned_request_PK;
      }

    }



    # If the INSERT or UPDATE of the request_status record was SUCCESSFUL,
    # then insert or update all the individual slide and sample information.
    if ( ( ($apply_action eq "INSERT") || ($apply_action eq "UPDATE") ) &&
        ($returned_request_status eq "SUCCESSFUL") ) {


      # Loop over each slide, INSERTing or UPDATing as appropriate
      for $element (0..($n_slides-1)) {


        # If there is already an ID for this slide, assume we need to UPDATE
        if ($table_parameters{"slide${element}id"} gt "") {

          # UPDATE array_request_sample record
          $sql_query = qq~
		UPDATE $TB_ARRAY_REQUEST_SLIDE SET
                 date_modified=CURRENT_TIMESTAMP,
                 modified_by_id=$current_contact_id,
                 record_status='$parameters{record_status}'
                WHERE array_request_slide_id=
                     $table_parameters{"slide${element}id"}
              ~;

          # Execute the SQL statement extract status and PK from result
          my @returned_information = $sbeams->applySqlChange("$sql_query",
              $current_contact_id,'array_request_slide',
              qq~array_request_slide_id=$table_parameters{"slide${element}id"}~);
          my $returned_slide_status = shift @returned_information;
          #my $returned_slide_PK = shift @returned_information;
          shift @returned_information;
          my $returned_slide_PK = $table_parameters{"slide${element}id"};

          # debugging print of INSERT result
          print "<BR>UPDATE of slide #$element (ID $returned_slide_PK)
            was $returned_slide_status<BR>\n";


        # If there is not yet an ID for this slide, we need to INSERT
        } else {

          # But double-check with a query that there isn't already a record
          $sql_query = qq~
		SELECT array_request_slide_id
		  FROM $TB_ARRAY_REQUEST_SLIDE
		 WHERE array_request_id='$parameters{$PK_COLUMN_NAME}'
		   AND slide_index = '$element'
          ~;
          my @result_set = $sbeams->selectOneColumn($sql_query);


          if ($result_set[0] gt "") {
            print qq~ERROR: No PK for this request and slide was passed to me,
              but there already seems to be a record in the table.  This should
              never happen.  Please report this error.<BR>\n~;
            return;

          # So far so good, so INSERT a new array_request_slide record
          } else {
            # INSERT a new array_request_slide record
            $sql_query = qq~
		INSERT INTO $TB_ARRAY_REQUEST_SLIDE
		 (array_request_id,slide_index,
		 created_by_id,modified_by_id,owner_group_id)
		VALUES
		 ( '$parameters{$PK_COLUMN_NAME}','$element',
		 $current_contact_id,$current_contact_id,$current_work_group_id)
            ~;

            # Execute the SQL statement extract status and PK from result
            my @returned_information = $sbeams->applySqlChange("$sql_query",
              $current_contact_id,'array_request_slide',
              qq~array_request_slide_id=$table_parameters{"slide${element}id"}~);
            my $returned_slide_status = shift @returned_information;
            my $returned_slide_PK = shift @returned_information;

            $table_parameters{"slide${element}id"} = $returned_slide_PK;

            # debugging print of INSERT result
            print "<BR>INSERT of slide #$element (ID $returned_slide_PK)
              was $returned_slide_status<BR>\n";
          }
        }


        # If we have an array_request_slide PK, then now work on UPDATing
        # or INSERTing array_request_sample
        if ( ($table_parameters{"slide${element}id"} gt "")
             && (!($ignore_table)) ) {

          # Now work on the individual sample records for this slide
          for $isample (0..($n_samples-1)) {

            # If there is already an ID for this sample, assume we need to UPDATE
            if ($table_parameters{"sample${isample}id_$element"} gt "") {

              # Change all ' to '' so that it can go in the INSERT statement
              my $tmp = $table_parameters{"sample${isample}name_$element"};
              $tmp =~ s/'/''/g;

              # UPDATE array_request_sample record
              $sql_query = qq~
			UPDATE $TB_ARRAY_REQUEST_SAMPLE SET
			 array_request_slide_id=
			     '$table_parameters{"slide${element}id"}',
			 sample_index='$isample',
			 name='$tmp',
			 labeling_method_id=
			     '$table_parameters{"sample${isample}labmeth_$element"}',
                     date_modified=CURRENT_TIMESTAMP,
                     modified_by_id=$current_contact_id,
                     record_status='$parameters{record_status}'
                    WHERE array_request_sample_id=
                     $table_parameters{"sample${isample}id_$element"}
              ~;

              # Execute the SQL statement extract status and PK from result
              my @returned_information = $sbeams->applySqlChange("$sql_query",
                $current_contact_id,'array_request_sample',
                qq~array_request_sample_id=$table_parameters{"sample${isample}id_$element"}~);

              my $returned_sample_status = shift @returned_information;
              #my $returned_sample_PK = shift @returned_information;
             shift @returned_information;
              my $returned_sample_PK = $table_parameters{"sample${isample}id_$element"};

              $table_parameters{"sample${isample}id_$element"} = 
                $returned_sample_PK;

              print qq~
                - UPDATE of sample #$isample (ID $returned_sample_PK)
                    for slide ID $table_parameters{"slide${element}id"}
                    was $returned_sample_status<BR>\n
              ~;


            # If there is not yet an ID for this sample, we need to INSERT
            } else {

              # But double-check with a query that there isn't already a record
              $sql_query = qq~
		SELECT array_request_sample_id
		  FROM $TB_ARRAY_REQUEST_SAMPLE
		 WHERE array_request_slide_id=
		       '$table_parameters{"slide${element}id"}'
		   AND sample_index = '$isample'
              ~;

              my @result_set = $sbeams->selectOneColumn($sql_query);

              # If something was returned, there is already a record!
              if ($result_set[0] gt "") {
                print qq~ERROR: No PK for this request and slide was passed to
                  me, but there already seems to be a record in the table.
                  This should never happen.  Please report this error.<BR>\n~;
                return;

              # So far so good, so INSERT a new array_request_slide record
              } else {


                # Change all ' to '' so that it can go in the INSERT statement
                my $tmp = $table_parameters{"sample${isample}name_$element"};
                $tmp =~ s/'/''/g;

                # INSERT a new array_request_slide record
                $sql_query = qq~
			INSERT INTO $TB_ARRAY_REQUEST_SAMPLE
			 (array_request_slide_id,sample_index,name,labeling_method_id,
			 created_by_id,modified_by_id,owner_group_id)
			VALUES
			 ( '$table_parameters{"slide${element}id"}','$isample',
			 '$tmp',
			 '$table_parameters{"sample${isample}labmeth_$element"}',
			 $current_contact_id,$current_contact_id,$current_work_group_id )
                ~;

                # Execute the SQL statement extract status and PK from result
                my @returned_information = $sbeams->applySqlChange("$sql_query",
                  $current_contact_id,'array_request_sample',
                  qq~array_request_sample_id=$table_parameters{"sample${isample}id_$element"}~);

                my $returned_sample_status = shift @returned_information;
                my $returned_sample_PK = shift @returned_information;

                $table_parameters{"sample${isample}id_$element"} = 
                  $returned_sample_PK;

                print qq~
                  - INSERT of sample #$isample (ID $returned_sample_PK)
                      for slide ID $table_parameters{"slide${element}id"}
                      was $returned_sample_status<BR>\n
                ~;
              }
            }

            # Calculate the print of each sample
            $sql_query = qq!
		SELECT price
		  FROM $TB_LABELING_METHOD
		 WHERE labeling_method_id='$table_parameters{"sample${isample}labmeth_$element"}'
            !;
            @row_result = $sbeams->selectOneColumn($sql_query);
            $proc_cost = $proc_cost + $row_result[0];
            #print "proc_cost,this_proc_cost = $proc_cost,$row_result[0]<BR>\n";
          } # endfor


        # If we don't have an array_request_slide PK, either $ignore_table set
        } elsif ($ignore_table) {
          # OK. do nothing

        #### or something bad happened.
        } else {
          print qq~ERROR: I do not have the PK information for the slide that
              I just INSERTed or UPDATEd.
              This should never happen.  Please report this error.<BR>\n~;
          return;
        }

      }

    }


    if ($returned_request_status eq "SUCCESSFUL") {
      print "<BR><BR><BR>Final Pricing:<BR><BR>\n";

      if ($parameters{"slide_type_id"}) {
        $sql_query = qq!
		SELECT $n_slides * STC.price
		  FROM $TB_SLIDE_TYPE ST
		  JOIN $TB_SLIDE_TYPE_COST STC ON ( ST.slide_type_id = STC.slide_type_id )
		 WHERE ST.slide_type_id='$parameters{"slide_type_id"}'
		   AND STC.cost_scheme_id = $cost_scheme_id
        !;
        @row_result = $sbeams->selectOneColumn($sql_query);
        my ($slide_cost) = @row_result;

        print "Slide Cost: \$ $slide_cost (includes printing if selected)<BR>\n";
        $total_price += $slide_cost;

      }


      #### If the Arrays Group does both Labeling and Hyb
      if ( $parameters{"hybridization_request"} =~ /LH/ ) {
        print "<P>Total Label/Hyb Cost: \$ $proc_cost<P>\n";
        $total_price += $proc_cost;

      #### Else if the user does Labeling and the Arrays Group does Hyb
      } elsif ( $parameters{"hybridization_request"} eq "L" ) {
        my $hyb_price = 50;
        #### Kludge the Yeast Half Slide price to $25
        $hyb_price = 25 if ($parameters{"slide_type_id"} == 11);
        $proc_cost = $n_slides *  $hyb_price;
        print "<P>Total Hyb Cost: \$ $proc_cost<P>\n";
        $total_price += $proc_cost;

      #### Else the user does it all
      } else {
        print "<P>Label/Hyb Cost: (you have chosen to do this yourself)<P>\n";
      }



      if ($parameters{"scanning_request"}) {
        $sql_query = qq!
		SELECT $n_slides * price
		  FROM $TB_ARRAY_REQUEST_OPTION
		 WHERE option_key='$parameters{"scanning_request"}'
		   AND option_type='scanning_request'
        !;
        @row_result = $sbeams->selectOneColumn($sql_query);
        my ($analysis_cost) = @row_result;

        print "Analysis Cost: \$ $analysis_cost<BR>\n";
        $total_price += $analysis_cost;

      }

      print "Total Cost: \$ $total_price<BR>\n";

      $sql_query = qq!
	UPDATE $DB_TABLE_NAME
	   SET price='$total_price'
	 WHERE $PK_COLUMN_NAME='$parameters{$PK_COLUMN_NAME}'
      !;
      #print "$sql_query<BR><BR>\n";
      $sbeams->executeSQL($sql_query);

    }


    printAttemptedChangeResult($apply_action,$returned_request_status,
      $parameters{$PK_COLUMN_NAME},@returned_information);


} # end processAddUser


###############################################################################
# Check For Preexisting Record
#
# Before the record is actually added, we check to see if there
# is already a matching record.
###############################################################################
sub checkForPreexistingRecord {
    my %unique_values = @_;
    my $element;
    my $foundvalue = '';
    my $error_message = '';

    my $sql_query = qq!
	SELECT $PK_COLUMN_NAME
	  FROM $DB_TABLE_NAME
	 WHERE $PK_COLUMN_NAME > 0!;

    foreach $element (keys %unique_values) {
      $sql_query .= "
	   AND $element='$unique_values{$element}'";
      $error_message .= "<B>$element</B> = $unique_values{$element}<BR>\n";
    }

    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    $sth->execute or croak $dbh->errstr;

    my @row = $sth->fetchrow_array;
    $sth->finish;

    print qq!
      The following columns where checked for uniqueness:<BR>
      $error_message<BR>
    ! if @row;

    return shift @row;

} # end checkForPreexistingRecord



###############################################################################
# Print Preexisting Record Message
###############################################################################
sub printPreexistingRecord {
    my $record_id = shift;

    my $back_button = $sbeams->getGoBackButton();
    print qq!
        <P>
        <H2>This $CATEGORY already exists</H2>
        $LINESEPARATOR
        <P>
        <TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
        Another $CATEGORY record already exists that would violate
        uniqueness contraints.  Perhaps you are trying to enter an item
        that already exists.  It is possible that the uniqueness constraints
        are too rigid, and they need to be relaxed a little to allow two
        records that are very similar.  It is also possible that
        there is a deleted item that matches the new entry (flagged as deleted
        but not yet purged from the system).  In that case, click on the
        existing (deleted) record, undelete it, and update as appropriate.
        <CENTER>
        <A HREF="$PROGRAM_FILE_NAME?$PK_COLUMN_NAME=$record_id">Click
          here to see the existing matching record</A><BR><BR>
        $back_button
        </CENTER>
        </TD></TR></TABLE>
        $LINESEPARATOR
        <P>!;
} # end printPreexistingRecord


###############################################################################
# Print Results of the attempted database change
###############################################################################
sub printAttemptedChangeResult {
    my $apply_action = shift || "?????";
    my @returned_result=@_;
    my $error;

    # First element is SUCCESSFUL or DENIED.  Rest is additional messages.
    my $result = shift @returned_result;
    my $resulting_PK = shift @returned_result;

    my $subdir = $sbeams->getSBEAMS_SUBDIR();
    $subdir .= "/" if ($subdir);

    $sbeams->printUserContext();
    print qq!
        <P>
        <H2>Return Status</H2>
        $LINESEPARATOR
        <P>
        <TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
        $apply_action of your record was <B>$result</B>.
        <P>
        <BLOCKQUOTE>!;
    foreach $error (@returned_result) { print "<LI>$error<P>\n"; }
    print qq!
        </BLOCKQUOTE>
        </TD></TR></TABLE>
    !;

    if ($result eq "SUCCESSFUL") {
      print qq~
        <CENTER><B>
        [ <A HREF="$PROGRAM_FILE_NAME&$PK_COLUMN_NAME=$resulting_PK&apply_action=VIEW">Click Here to View a PRINTABLE VERSION of your Request!!</A>]
        </B></CENTER>
      ~;
    }


    if ( ($result eq "SUCCESSFUL") && ($apply_action eq "INSERT" || $apply_action eq "UPDATE") ) {
      my $mailprog = "/usr/lib/sendmail";
      my $recipient_name = "Arrays Contact";
      my $recipient = "bmarzolf\@systemsbiology.org";
      my $cc_name = "SBEAMS";
      my $cc = "edeutsch\@systemsbiology.org";

      #### But if we're running as a dev version then just mail to administrator
      if ($DBVERSION =~ /Dev/) {
        $recipient_name = $cc_name;
        $recipient = $cc;
      }


      open (MAIL, "|$mailprog $recipient,$cc") || croak "Can't open $mailprog!\n";
      print MAIL "From: SBEAMS <edeutsch\@systemsbiology.org>\n";
      print MAIL "To: $recipient_name <$recipient>\n";
      print MAIL "Cc: $cc_name <$cc>\n";
      print MAIL "Reply-to: $current_username <${current_username}\@systemsbiology.org>\n";
      print MAIL "Subject: Microarray request submission\n\n";
      print MAIL "An $apply_action of a microarray request was just executed in SBEAMS by ${current_username}.\n\n";
      print MAIL "To see the request view this link:\n\n";
      print MAIL "$SERVER_BASE_DIR$CGI_BASE_DIR/${subdir}$PROGRAM_FILE_NAME&$PK_COLUMN_NAME=$resulting_PK&apply_action=VIEW\n\n";
      close (MAIL);

      print "<BR><BR>An email was just sent to the Arrays Group informing them of your request.<BR>\n";
    }


} # end printAttemptedChangeResult




###############################################################################
# Print Completed Entry (printable view)
###############################################################################
sub printCompletedEntry {

    $sbeamsMOD->printPageHeader(navigation_bar=>"NO");

    my %parameters;
    my $element;
    my $sql_query;
    my $username;
    my $proc_cost=0;
    my $total_price=0;

    # Get the columns for this table
    my @columns = $sbeamsMOD->returnTableInfo($TABLE_NAME,"ordered_columns");

    # Read the form values for each column
    foreach $element (@columns) {
        $parameters{$element}=$q->param($element);
    }


    my $apply_action  = $q->param('apply_action');


    # ---------------------------
    # If a specific PK row was referenced and this is not a REFRESH of an
    # existing record, then load data from it into hash
    if ($parameters{$PK_COLUMN_NAME} gt "" && $apply_action ne "REFRESH") {
      $sql_query = qq!
        SELECT *
          FROM $DB_TABLE_NAME
         WHERE $PK_COLUMN_NAME='$parameters{$PK_COLUMN_NAME}'!;
      my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
      my $rv  = $sth->execute or croak $dbh->errstr;

      my @row = $sth->fetchrow_array;
      for ($element=0; $element<=$#row; $element++) {
          $parameters{$columns[$element]}=$row[$element];
          #print "$columns[$element] =$row[$element]=<BR>\n";
      }

      $sth->finish;
    }


    $parameters{request_status}="Not Yet Submitted"
      if ( ! ($parameters{request_status}));


    #### Extract the value of cost_scheme_id or default to 1.
    #### FIX ME!! Do we have to hard-code the default value here??
    $parameters{cost_scheme_id} = $DEFAULT_COST_SCHEME unless ( $parameters{cost_scheme_id} >= 1 );
    my $cost_scheme_id = $parameters{cost_scheme_id};


    my $record_status_options =
      $sbeams->getRecordStatusOptions($parameters{"record_status"});


    print qq!
        <P>
        <H2>View $CATEGORY</H2>
        $LINESEPARATOR
        <FORM METHOD="post">
        <TABLE>
    !;


    # ---------------------------
    # Query to obtain column information about the table being managed
    $sql_query = qq~
	SELECT column_name,column_title,is_required,input_type,input_length,
	       is_display_column,column_text,optionlist_query
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$DB_TABLE_NAME'
	   AND is_display_column='Y'
	 ORDER BY column_index
    ~;
    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;


    # ---------------------------
    # First just extract any valid optionlist entries.  This is done
    # first as opposed to within the loop below so that a single DB connection
    # can be used.
    my %optionlist_queries;
    while (my @row = $sth->fetchrow_array) {
      my ($column_name,$column_title,$is_required,$input_type,$input_length,
          $is_data_column,$column_text,$optionlist_query) = @row;
      if ($optionlist_query gt "") {
        $optionlist_queries{$column_name}=$optionlist_query;
      }
    }
    $sth->finish;


    # ---------------------------
    # Build option lists for each optionlist query provided for this table
    my %optionlists;
    my %templist;
    foreach $element (keys %optionlist_queries) {

        # If "$contact_id" appears in the SQL optionlist query, then substitute
        # that with either a value of $parameters{contact_id} if it is not
        # empty, or otherwise replace with the $current_contact_id
        if ( $optionlist_queries{$element} =~ /\$contact_id/ ) {
          if ( $parameters{"contact_id"} eq "" ) {
            $optionlist_queries{$element} =~
                s/\$contact_id/$current_contact_id/;
          } else {
            $optionlist_queries{$element} =~
                s/\$contact_id/$parameters{contact_id}/;
          }
        }

        # If "$cost_scheme_id" appears in the SQL optionlist query, then substitute
        # that with the value of the current variable of the same name
        if ( $optionlist_queries{$element} =~ /\$cost_scheme_id/ ) {
          $optionlist_queries{$element} =~
              s/\$cost_scheme_id/$cost_scheme_id/;
        }

        #### Evaluate the $TBxxxxx table name variables if in the query
        if ( $optionlist_queries{$element} =~ /\$TB/ ) {
          $optionlist_queries{$element} =
            eval "\"$optionlist_queries{$element}\"";
        }

        # Build the option list
        #$optionlists{$element}=$sbeams->buildOptionList(
        #   $optionlist_queries{$element},$parameters{$element});
        #print "--> $optionlist_queries{$element} ==: ",join(",",%templist),"<BR>\n"

        %templist = $sbeams->selectTwoColumnHash($optionlist_queries{$element});
        $optionlists{$element} = $templist{$parameters{$element}};
    }



    # ---------------------------
    # Redo query to obtain column information about the table being managed
    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    while (my @row = $sth->fetchrow_array) {
      my ($column_name,$column_title,$is_required,$input_type,$input_length,
          $is_data_column,$column_text,$optionlist_query) = @row;

      if ($is_required eq "N") { print "<TR><TD><B>$column_title:</B></TD>\n"; }
      else { print "<TR><TD><B><font color=red>$column_title:</font></B></TD>\n"; }

      if ($input_type eq "text") {
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">$parameters{$column_name}</TD></TR>
        !;
      }

      if ($input_type eq "textarea") {
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">$parameters{$column_name}</TD></TR>
        !;
      }

      if ($input_type eq "fixed") {
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">$parameters{$column_name}</TD></TR>
        !;
      }

      if ($input_type eq "optionlist") {
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">
           $optionlists{$column_name}</TD></TR>
        !;
      }

      if ($input_type eq "current_contact_id") {
        if ($parameters{$column_name} eq "") {
            $parameters{$column_name}=$current_contact_id;
            $username=$current_username;
        } else {
            $username=$sbeams->getUsername($parameters{$column_name});
            if ( $parameters{$column_name} == $current_contact_id) {
              $username=$current_username;
            }
        }
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">$username</TD></TR>
        !;
      }

    }
    $sth->finish;
    print "</TABLE>";


#################################################

    my (@row_result,$isample);
    my $n_slides=$parameters{"n_slides"};
    my $n_samples=$parameters{"n_samples_per_slide"};
    if ($n_slides > 50) { $n_slides=50; }
    $n_slides=0 unless ($n_slides >= 1 && $n_slides <=50);
    $n_samples=2 unless ($n_samples >= 1 && $n_samples <=3);

    my %table_parameters;
    if ($n_slides > 0) {
      # Make a list of parameters for the table
      for $element (0..($n_slides-1)) {
        $table_parameters{"slide${element}id"}="";
        for $isample (0..($n_samples-1)) {
          $table_parameters{"sample${isample}name_$element"}="";
          $table_parameters{"sample${isample}labmeth_$element"}="";
          $table_parameters{"sample${isample}id_$element"}="";
         }
      }


      # Read the form values for each column
      foreach $element (keys %table_parameters) {
        $table_parameters{$element}=$q->param($element);
      }


    # ---------------------------
    # If a specific PK row was referenced, load data from it into hash
    if ($parameters{$PK_COLUMN_NAME} gt "") {
      $sql_query = qq!
        SELECT array_request_id,slide_index,sample_index,name,
               labeling_method_id,SLI.array_request_slide_id,
               array_request_sample_id
          FROM $TB_ARRAY_REQUEST_SAMPLE SAM
          FULL JOIN $TB_ARRAY_REQUEST_SLIDE SLI ON (
               SAM.array_request_slide_id = SLI.array_request_slide_id )
         WHERE $PK_COLUMN_NAME='$parameters{$PK_COLUMN_NAME}'!;
      my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
      my $rv  = $sth->execute or croak $dbh->errstr;

      while (my @row = $sth->fetchrow_array) {
          $table_parameters{"sample$row[2]name_$row[1]"}=$row[3];
          $table_parameters{"sample$row[2]labmeth_$row[1]"}=$row[4];
          $table_parameters{"sample$row[2]id_$row[1]"}=$row[6];
          $table_parameters{"slide$row[1]id"}=$row[5];
      }

      $sth->finish;
    }



      $sql_query = qq~
	SELECT labeling_method_id,name
	  FROM $TB_LABELING_METHOD
	 ORDER BY sort_order,name
      ~;
      my %optionlist=$sbeams->selectTwoColumnHash($sql_query);



      my ($row,$col);
      print qq~
	<P>
	<TABLE WIDTH=600><TR><TD>
	Below is your slide and sample information.  Each slide and sample
	has been assigned a unique identifier number.  If you are giving samples
	to the array group for labeling and further processing, YOU MUST LABEL
	YOUR SAMPLES WITH THESE SAMPLE IDs!
	</TD></TR><TR><TD>
	The sample names you provides become the official label of each
	sample.  Entries with identical names are assumed to be repeats and
	will be processed as such by the standard pipeline.  These names will
	be used to link back to your private tables of sample information.
	You can also use the Sample IDs to link back to each individual
	preparation of a (possibly multiply used) sample.
	</TD></TR></TABLE>
        <P>
	<TABLE WIDTH=675 BORDER=1><TR>
	<TH>Slide Index</TH><TH>Slide Request ID</TH>
      ~;

      for $col (1..$n_samples) {
        print "<TH>Sample $col Name</TH><TH>Sample $col ID</TH><TH>Sample $col Labeling Method</TH>\n";
      }
      print "</TR>\n";

      my $thisoptionlist;
      for $row (0..($n_slides-1)) {
        print qq!
		<TR><TD>$row</TD>
		<TD><INPUT NAME="slide${row}id" TYPE="hidden"
		   VALUE="$table_parameters{"slide${row}id"}">
		$table_parameters{"slide${row}id"}</TD>
	!;
        for $col (0..($n_samples-1)) {
          my $fgcolor="#ff0000";
          if ($col == 1) { $fgcolor="#000000"; }
          $thisoptionlist="";
          if ($table_parameters{"sample${col}labmeth_$row"}) {
            $thisoptionlist =
              $optionlist{$table_parameters{"sample${col}labmeth_$row"}};
          }
          print qq!
		<TD><FONT COLOR="$fgcolor">$table_parameters{"sample${col}name_$row"}</FONT></TD>
		<TD><FONT COLOR="$fgcolor"><INPUT NAME="sample${col}id_$row" TYPE="hidden"
		   VALUE="$table_parameters{"sample${col}id_$row"}">
		   $table_parameters{"sample${col}id_$row"}</FONT></TD>
		<TD><FONT COLOR="$fgcolor">$thisoptionlist</FONT></TD>
          !;

          if ($table_parameters{"sample${col}labmeth_$row"}) {
            $sql_query = qq!
		SELECT price
		  FROM $TB_LABELING_METHOD
		 WHERE labeling_method_id='$table_parameters{"sample${col}labmeth_$row"}'
            !;
            @row_result = $sbeams->selectOneColumn($sql_query);
            $proc_cost = $proc_cost + $row_result[0];

          }
        }
      print "</TR>";
      }
      print "</TABLE>\n";


      if ($parameters{"slide_type_id"}) {
        $sql_query = qq!
		SELECT $n_slides * STC.price
		  FROM $TB_SLIDE_TYPE ST
		  JOIN $TB_SLIDE_TYPE_COST STC ON ( ST.slide_type_id = STC.slide_type_id )
		 WHERE ST.slide_type_id='$parameters{"slide_type_id"}'
		   AND STC.cost_scheme_id = $cost_scheme_id
        !;
        @row_result = $sbeams->selectOneColumn($sql_query);
        my ($slide_cost) = @row_result;

        print "<P>Slide Cost: \$ $slide_cost (includes printing if selected)<P>\n";
        $total_price += $slide_cost;

      }


      #### If the Arrays Group does both Labeling and Hyb
      if ( $parameters{"hybridization_request"} =~ /LH/ ) {
        print "<P>Total Label/Hyb Cost: \$ $proc_cost<P>\n";
        $total_price += $proc_cost;

      #### Else if the user does Labeling and the Arrays Group does Hyb
      } elsif ( $parameters{"hybridization_request"} eq "L" ) {
        my $hyb_price = 50;
        #### Kludge the Yeast Half Slide price to $25
        $hyb_price = 25 if ($parameters{"slide_type_id"} == 11);
        $proc_cost = $n_slides *  $hyb_price;
        print "<P>Total Hyb Cost: \$ $proc_cost<P>\n";
        $total_price += $proc_cost;

      #### Else the user does it all
      } else {
        print "<P>Label/Hyb Cost: (you have chosen to do this yourself)<P>\n";
      }


      if ($parameters{"scanning_request"}) {
        $sql_query = qq!
		SELECT $n_slides * price
		  FROM $TB_ARRAY_REQUEST_OPTION
		 WHERE option_key='$parameters{"scanning_request"}'
		   AND option_type='scanning_request'
        !;
        @row_result = $sbeams->selectOneColumn($sql_query);
        my ($analysis_cost) = @row_result;

        print "<P>Analysis Cost: \$ $analysis_cost<P>\n";
        $total_price += $analysis_cost;

      }



      print "<P>Total Cost: \$ $total_price<P>\n";


    } else {
      print qq!
             <B>Please select the number of desired slides above and
             choose REFRESH below and press APPLY.<BR>
      !;
    }



    print qq!
        <TABLE>
	<TR>
        <TD COLSPAN=2 ALIGN="center">
        <INPUT TYPE="hidden" NAME="price" VALUE="$total_price">
        <INPUT TYPE="hidden" NAME="TABLE_NAME" VALUE="$TABLE_NAME">
        !;



    print qq!
         </TABLE>
         $LINESEPARATOR
         <P>
    !;


    print qq~
	<B>Please place the appropriate amount of XNA into one tube per
	reaction as per table below:</B><BR><BR>
    ~;
    my %url_cols;
    $sql_query = "SELECT * FROM arrays.dbo.xna_info";
    $sbeams->displayQueryResult(sql_query=>$sql_query,
        url_cols_ref=>\%url_cols,printable_table=>1);

    print qq~
        <BR><BR><BR><B>
	Add Arabadopsis control RNA to samples to be labeled as
	follows:</B><BR><BR>
    ~;
    $sql_query = "SELECT * FROM arrays.dbo.arabadopsis";
    $sbeams->displayQueryResult(sql_query=>$sql_query,
        url_cols_ref=>\%url_cols,printable_table=>1);

    print qq~
        <BR><BR><B><FONT COLOR=RED>
	**Speedvac your samples with controls to < 10 ul for cDNA and
	dry for direct labeling**</FONT</B><BR><BR><BR><BR>
    ~;


    $sbeamsMOD->printPageFooter("CloseTables");

} # end printEntryForm

