#!/usr/local/bin/perl

###############################################################################
# Program     : BrowseFeatures.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               browse through Features resulting from BioSap.
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
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


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
        $ff = join(",",$q->param($ee));
        print "$ee=$ff<BR>\n";
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
    my (%url_cols,%hidden_cols,%max_widths);
    my $username;

    my $CATEGORY="Browse BioSap Feaures";
    my $TABLE_NAME="BrowseBioSapFeature";
    $TABLE_NAME = $q->param("QUERY_NAME") if $q->param("QUERY_NAME");


    # Get the columns for this table
    my @columns = $sbeamsBS->returnTableInfo($TABLE_NAME,"ordered_columns");
    my %input_types = 
      $sbeamsBS->returnTableInfo($TABLE_NAME,"input_types");

    # Read the form values for each column
    foreach $element (@columns) {
        if ($input_types{$element} eq "multioptionlist") {
          my @tmparray = $q->param($element);
          if (scalar(@tmparray) > 1) {
            pop @tmparray unless ($tmparray[$#tmparray]);
            shift @tmparray unless ($tmparray[0]);
          }
          $parameters{$element}=join(",",@tmparray);
        } else {
          $parameters{$element}=$q->param($element);
        }
    }

    my $apply_action  = $q->param('apply_action');


    #### If xcorr_charge is undefined (not just "") then set to a high limit
    #### So that a naive query is quick
    if (($TABLE_NAME eq "BrowseSearchHits") && (!defined($parameters{xcorr_charge1})) ) {
      $parameters{xcorr_charge1} = ">4.0";
      $parameters{xcorr_charge2} = ">4.5";
      $parameters{xcorr_charge3} = ">5.0";
      $parameters{sort_order} = "reference";
    }


    #### If this is a ShowSearch query and sort_order is undefined (not just ""),
    #### then set to a likely default
    if (($TABLE_NAME eq "ShowSearch") && (!defined($parameters{sort_order})) ) {
      $parameters{sort_order} = "S.file_root,experiment_tag,set_tag,SH.cross_corr_rank";
    }


    # ---------------------------
    # Query to obtain column information about the table being managed
    $sql_query = qq~
	SELECT column_name,column_title,is_required,input_type,input_length,
	       is_data_column,column_text,optionlist_query,onChange
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$TABLE_NAME'
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
    my $file_upload_flag = "";
    while (my @row = $sth->fetchrow_array) {
      my ($column_name,$column_title,$is_required,$input_type,$input_length,
          $is_data_column,$column_text,$optionlist_query,$onChange) = @row;
      if ($optionlist_query gt "") {
        $optionlist_queries{$column_name}=$optionlist_query;
      if ($input_type eq "file") {
        $file_upload_flag = "ENCTYPE=\"multipart/form-data\""; }
      }
    }
    $sth->finish;
    $file_upload_flag = "";


    # There appears to be a Netscape bug in that one cannot [BACK] to a form
    # that had multipart encoding.  So, only include form type multipart if
    # we really have an upload field.  IE users are fine either way.
    $sbeams->printUserContext();
    print qq!
        <P>
        <H2>$CATEGORY</H2>
        $LINESEPARATOR
        <FORM METHOD="post" $file_upload_flag>
        <TABLE>
    !;


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
        $optionlists{$element}=$sbeams->buildOptionList(
           $optionlist_queries{$element},$parameters{$element},$method_options);
    }


    # ---------------------------
    # Redo query to obtain column information about the table being managed
    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;

    while (my @row = $sth->fetchrow_array) {
      my ($column_name,$column_title,$is_required,$input_type,$input_length,
          $is_data_column,$column_text,$optionlist_query,$onChange) = @row;

      if ($onChange gt "") {
        $onChange = " onChange=\"$onChange\"";
      }


      #### If the action included the phrase HIDE, don't print all the options
      if ($apply_action =~ /HIDE/i) {
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}"></TD>
        !;
        next;
      }


      if ($is_required eq "N") { print "<TR><TD><B>$column_title:</B></TD>\n"; }
      else { print "<TR><TD><B><font color=red>$column_title:</font></B></TD>\n"; }


      if ($input_type eq "text") {
        print qq!
          <TD><INPUT TYPE="$input_type" NAME="$column_name"
           VALUE="$parameters{$column_name}" SIZE=$input_length $onChange></TD>
        !;
      }


      if ($input_type eq "file") {
        print qq!
          <TD><INPUT TYPE="$input_type" NAME="$column_name"
           VALUE="$parameters{$column_name}" SIZE=$input_length $onChange>
        !;
        if ($parameters{$column_name}) {
          print qq!
            <A HREF="$DATA_DIR/$parameters{$column_name}">view file</A>
          !;
        }
        print qq!
           </TD>
        !;
      }


      if ($input_type eq "password") {

        # If we just loaded password data from the database, and it's not
        # a blank field, the replace it with a special entry that we'll
        # look for and decode when it comes time to UPDATE.
        if ($parameters{$PK_COLUMN_NAME} gt "" && $apply_action ne "REFRESH") {
          if ($parameters{$column_name} gt "") {
            $parameters{$column_name}="**********".$parameters{$column_name};
          }
        }

        print qq!
          <TD><INPUT TYPE="$input_type" NAME="$column_name"
           VALUE="$parameters{$column_name}" SIZE=$input_length></TD>
        !;
      }


      if ($input_type eq "fixed") {
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">$parameters{$column_name}</TD>
        !;
      }

      if ($input_type eq "textarea") {
        print qq!
          <TD><TEXTAREA NAME="$column_name" rows=$input_length cols=40>$parameters{$column_name}</TEXTAREA></TD>
        !;
      }

      if ($input_type eq "textdate") {
        if ($parameters{$column_name} eq "") {
          my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
          $year+=1900; $mon+=1;
          $parameters{$column_name} = "$year-$mon-$mday $hour:$min";
        }
        print qq!
          <TD><INPUT TYPE="text" NAME="$column_name"
           VALUE="$parameters{$column_name}" SIZE=$input_length>
          <INPUT TYPE="button" NAME="${column_name}_button"
           VALUE="NOW" onClick="ClickedNowButton($column_name)">
           </TD>
        !;
      }

      if ($input_type eq "optionlist") {
        print qq~
          <TD><SELECT NAME="$column_name" $onChange> <!-- $parameters{$column_name} -->
          <OPTION VALUE=""></OPTION>
          $optionlists{$column_name}</SELECT></TD>
        ~;
      }

      if ($input_type eq "scrolloptionlist") {
        print qq!
          <TD><SELECT NAME="$column_name" SIZE=$input_length $onChange>
          <OPTION VALUE=""></OPTION>
          $optionlists{$column_name}</SELECT></TD>
        !;
      }

      if ($input_type eq "multioptionlist") {
        print qq!
          <TD><SELECT NAME="$column_name" MULTIPLE SIZE=$input_length $onChange>
          $optionlists{$column_name}
          <OPTION VALUE=""></OPTION>
          </SELECT></TD>
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



    # ---------------------------
    # If this is a HIDE query, then just show a button to reveal constraints
    if ($apply_action =~ /HIDE/i) {
      print qq!
	<INPUT TYPE="hidden" NAME="QUERY_NAME" VALUE="$TABLE_NAME">
	<TR><TD COLSPAN=2>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="SHOW CONSTRAINTS">
        </TD></TR></TABLE>
        </FORM>
      !;

    # Else show the QUERY, REFRESH, and Reset buttons
    } else {
      print qq!
	<INPUT TYPE="hidden" NAME="QUERY_NAME" VALUE="$TABLE_NAME">
	<TR><TD COLSPAN=2>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="QUERY">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="reset"  VALUE="Reset">
        </TD></TR></TABLE>
        </FORM>
      !;
    }


    $sbeams->printPageFooter("CloseTables");
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";


    # --------------------------------------------------
    # --------------------------------------------------
    # --------------------------------------------------
    # --------------------------------------------------
    my $show_sql;
    my $tsv_output;

    if ($apply_action gt "") {


      #### Build BIOSAP_SEARCH constraint
      my $biosap_search_clause = "";
      if ($parameters{biosap_search_id}) {
        $biosap_search_clause = "   AND biosap_search_id IN ( $parameters{biosap_search_id} )";
      }


      #### Build TM constraint
      my $tm_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"F.melting_temp",
        constraint_type=>"flexible_float",
        constraint_name=>"Melting Temp",
        constraint_value=>$parameters{tm_constraint} );
      return if ($tm_clause == -1);


      #### Build THREEPRIME DISTANCE constraint
      my $threeprime_distance_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"F.threeprime_distance",
        constraint_type=>"flexible_int",
        constraint_name=>"3' Distance",
        constraint_value=>$parameters{threeprime_distance_constraint} );
      return if ($threeprime_distance_clause == -1);


      #### Build MISMATCH REJECTION constraint
      my $mismatch_rejection_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"F.sequence_length - FH.number_of_identities",
        constraint_type=>"int",
        constraint_name=>"Mismatch Rejection",
        constraint_value=>$parameters{mismatch_rejection_constraint} );
      return if ($mismatch_rejection_clause == -1);
      $mismatch_rejection_clause =~ s/=/<=/; 

      #### Why don't the queries work without this?????!!!!
      $mismatch_rejection_clause = "   AND F.sequence_length - FH.number_of_identities = 0"
        unless ($mismatch_rejection_clause);


      #### Build GENE CONSTRAINTS
      my $gene_constraints = "";
      if ($parameters{biosequence_name_constraint}) {
        my @tmparray = split(/[\n\r]+/,$parameters{biosequence_name_constraint});
        foreach $element (@tmparray) {
          $element =~ s/'/''/g;
          $gene_constraints .= "OR biosequence_name LIKE '$element'\n"
            if ($element);
        }
        $gene_constraints =~ s/OR/WHERE/;
      }


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
      unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=99999) {
        $parameters{row_limit} = 100;
      }
      my $limit_clause = "TOP $parameters{row_limit}";


      #### Define the desired columns
      my @column_array;


      #### Limit the width of the Reference column if user selected
      if ( $parameters{display_options} =~ /AdditionalColumns/ ) {
        @column_array = (
          ["biosequence_name","biosequence_name","biosequence_name"],
          ["melting_temp","melting_temp","melting_temp"],
          ["threeprime_distance","threeprime_distance","threeprime_distance"],
          ["feature_sequence","feature_sequence","feature_sequence"],
        );

      } else {
        @column_array = (
          ["biosequence_name","biosequence_name","biosequence_name"],
          ["feature_sequence","feature_sequence","feature_sequence"],
        );
      }


      #### Set flag to display SQL statement if user selected
      if ( $parameters{display_options} =~ /ShowSQL/ ) {
        $show_sql = 1;
      }

      #### Set flag to display in tab separated value format
      if ( $parameters{display_options} =~ /TSV/ ) {
        $tsv_output = 1;
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


      $sql_query = qq~
-- Create a table of the desired genes
SELECT biosequence_id,biosequence_name
  INTO #tmpDesiredGene
  FROM $TBBS_BIOSEQUENCE BS
  JOIN $TBBS_BIOSEQUENCE_SET BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
$gene_constraints


-- Create a table of all features and their close matches
SELECT F.feature_id,F.biosequence_id AS 'main_biosequence_id',
       FH.biosequence_id AS 'hit_biosequence_id'
  INTO #tmpAllCloseMatches
  FROM $TBBS_FEATURE F
  JOIN #tmpDesiredGene tDG ON ( F.biosequence_id = tDG.biosequence_id )
  JOIN $TBBS_FEATURE_HIT FH ON ( F.feature_id = FH.feature_id )
  JOIN $TBBS_BIOSEQUENCE BS2 ON ( FH.biosequence_id = BS2.biosequence_id )
 WHERE 1 = 1
$biosap_search_clause
$mismatch_rejection_clause


-- Create a second table of features which have matches to a different gene
SELECT feature_id,COUNT(*) AS 'Count'
  INTO #tmpBadMatches
  FROM #tmpAllCloseMatches
 WHERE main_biosequence_id != hit_biosequence_id
 GROUP BY feature_id


-- Delete features from first table where there are matches in second table
DELETE FROM #tmpAllCloseMatches
 WHERE feature_id IN ( SELECT feature_id FROM #tmpBadMatches )


-- Create the final table of good genes and features
SELECT F.feature_id,BS1.biosequence_name AS 'main_biosequence_name',
       BS2.biosequence_name AS 'hit_biosequence_name',
       CONVERT(NUMERIC(10,1),melting_temp) AS 'melting_temp',
       threeprime_distance,sequence_length,number_of_identities,
       feature_sequence
  INTO #tmpResult
  FROM #tmpAllCloseMatches tACM
  JOIN $TBBS_FEATURE F ON ( tACM.feature_id = F.feature_id )
  JOIN $TBBS_FEATURE_HIT FH ON ( tACM.feature_id = FH.feature_id )
  JOIN $TBBS_BIOSEQUENCE BS1 ON ( tACM.main_biosequence_id = BS1.biosequence_id )
  JOIN $TBBS_BIOSEQUENCE BS2 ON ( FH.biosequence_id = BS2.biosequence_id )
$mismatch_rejection_clause
$tm_clause
$threeprime_distance_clause
 ORDER BY BS1.biosequence_name,feature_sequence,BS2.biosequence_name


-- Now create the final dataset in a pretty format
SELECT DISTINCT BS1.biosequence_name AS 'biosequence_name',
       CONVERT(NUMERIC(10,1),F.melting_temp) AS 'melting_temp',
       F.threeprime_distance,F.feature_sequence
  INTO #tmpFinal
  FROM #tmpResult tR
  JOIN $TBBS_FEATURE F ON ( tR.feature_id = F.feature_id )
  JOIN $TBBS_BIOSEQUENCE BS1 ON ( F.biosequence_id = BS1.biosequence_id )
  JOIN $TBBS_FEATURE_HIT FH ON ( F.feature_id = FH.feature_id )
 WHERE 1 = 1
$biosap_search_clause
$mismatch_rejection_clause
$tm_clause
$threeprime_distance_clause
 ORDER BY BS1.biosequence_name,F.melting_temp,F.feature_sequence


-- Print out the final dataset with the desired columns
SELECT $columns_clause
  FROM #tmpFinal
$order_by_clause
      ~;


      my $base_url = "$CGI_BASE_DIR/Biosap/BrowseAnnotatedPeptides.cgi";
      %url_cols = (
      );

      %hidden_cols = ('none' => 1,
      );



    } else {
      $apply_action="BAD SELECTION";
    }



    #### If QUERY was selected, go ahead and execute the query!
    if ($apply_action =~ /QUERY/i) {

      if ($tsv_output) {
        my @rows = $sbeams->selectSeveralColumns($sql_query);
        print "<PRE>\n";
        foreach $element (@rows) {
          print join("\t",@{$element}),"\n";
        }
        print "</PRE><BR><BR><BR>\n";
        return
      }

      my ($resultset_ref,$key,$value,$element);
      my %resultset;
      $resultset_ref = \%resultset;

      print "<PRE>$sql_query</PRE><BR>\n" if ($show_sql);
      $sbeams->displayQueryResult(sql_query=>$sql_query,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols,
          max_widths=>\%max_widths,resultset_ref=>$resultset_ref);


      if ( $parameters{row_limit} == scalar(@{$resultset_ref->{data_ref}}) ) {
        print "<font color=red>WARNING: </font>Resultset truncated at ".
          "$parameters{row_limit} rows.  Increase row limit to see more.<BR>\n";
      }

      #### Print out some information about the returned resultset:
      if (0 == 1) {
        print "resultset_ref = $resultset_ref<BR>\n";
        while ( ($key,$value) = each %{$resultset_ref} ) {
          printf("%s = %s<BR>\n",$key,$value);
        }
        print "columnlist = ",join(" , ",@{$resultset_ref->{column_list_ref}}),"<BR>\n";
        print "nrows = ",scalar(@{$resultset_ref->{data_ref}}),"<BR>\n";
      }


    #### If QUERY was not selected, then tell the user to enter some parameters
    } else {
      print "<H4>Select parameters above and press QUERY</H4>\n";
    }


} # end printEntryForm


