#!/usr/local/bin/perl

###############################################################################
# Program     : BrowseAnnotatedPeptides.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               browse through Annotated search hits.
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

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsPROT = new SBEAMS::Proteomics;
$sbeamsPROT->setSBEAMS($sbeams);
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

    my $CATEGORY="Browse Annotated Peptides";
    my $TABLE_NAME="BrowseAnnotatedPeptides";
    $TABLE_NAME = $q->param("QUERY_NAME") if $q->param("QUERY_NAME");


    # Get the columns for this table
    my @columns = $sbeamsPROT->returnTableInfo($TABLE_NAME,"ordered_columns");
    my %input_types = 
      $sbeamsPROT->returnTableInfo($TABLE_NAME,"input_types");

    # Read the form values for each column
    foreach $element (@columns) {
        if ($input_types{$element} eq "multioptionlist") {
          $parameters{$element}=join(",",$q->param($element));
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
          $optionlists{$column_name}</SELECT></TR>
        !;
      }

      if ($input_type eq "multioptionlist") {
        print qq!
          <TD><SELECT NAME="$column_name" MULTIPLE SIZE=$input_length $onChange>
          $optionlists{$column_name}</SELECT></TR>
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
    # Show the QUERY, REFRESH, and Reset buttons
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


    $sbeams->printPageFooter("CloseTables");
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";


    # --------------------------------------------------
    # --------------------------------------------------
    # --------------------------------------------------
    # --------------------------------------------------

    if ($apply_action gt "") {


      #### Build SEARCH BATCH / EXPERIMENT constraint
      my $search_batch_clause = "";
      if ($parameters{search_batch_id}) {
        $search_batch_clause = "   AND SB.search_batch_id IN ( $parameters{search_batch_id} )";
      }



      #### Build REFERENCE PROTEIN constraint
      my $reference_clause = "";
      if ($parameters{reference_constraint}) {
        if ($parameters{reference_constraint} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
          print "<H4>Cannot parse Reference Constraint!  Check syntax.</H4>\n\n";
          return;
        } else {
          $reference_clause = "   AND SH.reference LIKE '$parameters{reference_constraint}'";
        }
      }


      #### Build PEPTIDE constraint
      my $peptide_clause = "";
      if ($parameters{peptide_constraint}) {
        if ($parameters{peptide_constraint} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
          print "<H4>Cannot parse Peptide Constraint!  Check syntax.</H4>\n\n";
          return;
        } else {
          $peptide_clause = "   AND SH.peptide_string LIKE '$parameters{peptide_constraint}'";
        }
      }



      #### Build ANNOTATION_LABELS constraint
      my $annotation_label_clause = "";
      if ($parameters{annotation_label_id}) {
        $annotation_label_clause = "   AND SHA.annotation_label_id IN ( $parameters{annotation_label_id} )";
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
      my $limit_clause = "TOP 100";
      if ($parameters{row_limit} > 0 && $parameters{row_limit}<=99999) {
        $limit_clause = "TOP $parameters{row_limit}";
      }


      #### Define the desired columns
      my $group_by_clause = "";
      my @column_array;
      if ( $parameters{display_options} =~ /GroupReference/ ) {
        @column_array = (
          ["reference","reference","Reference"],
          ["count","COUNT(*)","Count"],
        );
        $group_by_clause = " GROUP BY reference";
      } elsif ( $parameters{display_options} =~ /GroupPeptide/ ) {
        @column_array = (
          ["reference","reference","Reference"],
          ["peptide","peptide","Peptide"],
          ["count","COUNT(*)","Count"],
        );
        $group_by_clause = " GROUP BY reference,peptide";
      } else {
        @column_array = (
          ["reference","reference","Reference"],
          ["peptide","peptide","Peptide"],
        );
      }


      #### Add the protein descriptions at the end if user selected
      if ( $parameters{display_options} =~ /BSDesc/ ) {
        unshift(@column_array,["biosequence_accession","biosequence_accession","Accession"]);
        unshift(@column_array,["biosequence_gene_name","biosequence_gene_name","Gene Name"]);
        push(@column_array,["biosequence_desc","biosequence_desc","Reference Description"]);
        $group_by_clause .= ",biosequence_desc,biosequence_gene_name,biosequence_accession" if ($group_by_clause);
      }


      #### Limit the width of the Reference column if user selected
      if ( $parameters{display_options} =~ /MaxRefWidth/ ) {
        $max_widths{'Reference'} = 20;
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
	SELECT $limit_clause $columns_clause
	  FROM proteomics.dbo.search_hit SH
	  JOIN proteomics.dbo.search S ON ( SH.search_id = S.search_id )
	  JOIN $TB_SEARCH_HIT_ANNOTATION SHA ON ( SH.search_hit_id = SHA.search_hit_id )
	  JOIN proteomics.dbo.search_batch SB ON ( S.search_batch_id = SB.search_batch_id )
	  JOIN proteomics.dbo.biosequence_set BSS ON ( SB.biosequence_set_id = BSS.biosequence_set_id )
	  LEFT JOIN $TB_BIOSEQUENCE BS ON ( SB.biosequence_set_id = BS.biosequence_set_id AND SH.reference = BS.biosequence_name )
	 WHERE 1 = 1
	$search_batch_clause
	$reference_clause
	$peptide_clause
	$annotation_label_clause
	$group_by_clause
	$order_by_clause
       ~;

      #print "<PRE>\n$sql_query\n</PRE>\n";

      my $base_url = "$CGI_BASE_DIR/Proteomics/BrowseAnnotatedPeptides.cgi";
      %url_cols = ('Gene Name' => "http://flybase.bio.indiana.edu/.bin/fbidq.html?\%$colnameidx{biosequence_accession}V",
		   'Gene Name_ATAG' => 'TARGET="Win1"',
                   'Accession' => "http://flybase.bio.indiana.edu/.bin/fbidq.html?\%$colnameidx{biosequence_accession}V",
		   'Accession_ATAG' => 'TARGET="Win1"',
                   'Reference' => "$CGI_BASE_DIR/Proteomics/BrowseSearchHits.cgi?QUERY_NAME=BrowseSearchHits&reference_constraint=\%$colnameidx{reference}V&search_batch_id=$parameters{search_batch_id}&xcorr_rank_constraint=1&apply_action=QUERY",
		   'Reference_ATAG' => 'TARGET="Win1"','Peptide' => "$CGI_BASE_DIR/Proteomics/BrowseSearchHits.cgi?QUERY_NAME=BrowseSearchHits&peptide_constraint=\%$colnameidx{peptide}V&search_batch_id=$parameters{search_batch_id}&xcorr_rank_constraint=1&apply_action=QUERY",
		   'Peptide_ATAG' => 'TARGET="Win1"',
      );

      %hidden_cols = ('data_location' => 1,
                      'search_batch_id' => 1,
                      'search_id' => 1,
                      'search_hit_id' => 1,
                      'fraction_tag' => 1,
                      'set_path' => 1,
      );

		   #######'Reference_ATAG' => "TARGET=\"Win1\" ONMOUSEOVER=\"window.status='%V'; return true\"",


      #print "<PRE>$sql_query\n</PRE><BR>\n";

    } else {
      $apply_action="BAD SELECTION";
    }


    if ($apply_action eq "QUERY") {
      return $sbeams->displayQueryResult(sql_query=>$sql_query,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols,
          max_widths=>\%max_widths);
    } else {
      print "<H4>Select parameters above and press QUERY</H4>\n";
    }


} # end printEntryForm


