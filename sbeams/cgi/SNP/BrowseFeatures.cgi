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
use vars qw ($q $sbeams $sbeamsSN $dbh $current_contact_id $current_username
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

use SBEAMS::SNP;
use SBEAMS::SNP::Settings;
use SBEAMS::SNP::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsSN = new SBEAMS::SNP;
$sbeamsSN->setSBEAMS($sbeams);
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
    $sbeamsSN->printPageHeader();
    processRequests();
    $sbeamsSN->printPageFooter();

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

    my ($i,$element,$key,$value,$line,$result,$sql);
    my %parameters;
    my %resultset = ();
    my $resultset_ref = \%resultset;

    my $sql_query;
    my (%url_cols,%hidden_cols,%max_widths);
    my $username;

    #### Read in the standard form values
    my $apply_action  = $q->param('apply_action');
    my $TABLE_NAME = $q->param("QUERY_NAME");


    #### Set some specific settings for this program
    my $CATEGORY="Browse BioSap Features";
    $TABLE_NAME="BrowseBioSapFeature" unless ($TABLE_NAME);
    my $base_url = "$CGI_BASE_DIR/SNP/BrowseFeatures.cgi";


    # Get the columns for this table
    my @columns = $sbeamsSN->returnTableInfo($TABLE_NAME,"ordered_columns");
    my %input_types = 
      $sbeamsSN->returnTableInfo($TABLE_NAME,"input_types");

    # Read the form values for each column
    my $no_params_flag = 1;
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
        $no_params_flag = 0 if ($parameters{$element});
    }



    #### If the apply action was to recall a previous resultset, do it
    my %rs_params;
    $rs_params{set_name} = $q->param("rs_set_name");
    $rs_params{page_size} = $q->param("rs_page_size") || 50;
    $rs_params{page_number} = $q->param("rs_page_number") || 1;
    $rs_params{page_number} -= 1 if ($rs_params{page_number});
    if ($apply_action eq "VIEWRESULTSET") {
      $sbeams->readResultSet(resultset_file=>$rs_params{set_name},
          resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters);
      $no_params_flag = 0;
    }


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
        $parameters{row_limit} = 5000;
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


-- Create a second table of unique feature,hit_biosequence_id rows
-- since we'll ignore multiple hits to the same gene (won't we?)
SELECT feature_id,hit_biosequence_id,COUNT(*) AS 'Count'
  INTO #tmpUniqueMatches
  FROM #tmpAllCloseMatches
 GROUP BY feature_id,hit_biosequence_id


-- Create a third table of features which have multiple matches
SELECT feature_id,COUNT(*) AS 'Count'
  INTO #tmpBadMatches
  FROM #tmpUniqueMatches
 GROUP BY feature_id
HAVING COUNT(*) > 1


-- Delete features from first table where there are matches in third table
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
SELECT $limit_clause $columns_clause
  FROM #tmpFinal
$order_by_clause
      ~;


      %url_cols = (
      );

      %hidden_cols = ('none' => 1,
      );



    } else {
      $apply_action="BAD SELECTION";
    }



    #### If QUERY or VIEWRESULTSET was selected, display the data
    if ($apply_action =~ /QUERY/i || $apply_action eq "VIEWRESULTSET") {

      #### Show the SQL that will be or was executed
      print "<PRE>$sql_query</PRE><BR>\n" if ($show_sql);

      #### If the action contained QUERY, then fetch the results from
      #### the database
      if ($apply_action =~ /QUERY/i) {

        #### Fetch the results from the database
        $sbeams->fetchResultSet(sql_query=>$sql_query,
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


} # end printEntryForm


