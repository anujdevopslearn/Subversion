#!/usr/local/bin/perl

###############################################################################
# Program     : BrowseSearchHits.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               browse through Proteomics output search hits.
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
    my $username;

    my $CATEGORY="Proteomics Data Test Query";
    my $TABLE_NAME="BrowseSearchHits";
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
        <H2>Maintain $CATEGORY</H2>
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

        # Build the option list
        $optionlists{$element}=$sbeams->buildOptionList(
           $optionlist_queries{$element},$parameters{$element});
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
          <OPTION VALUE=""></OPTION>
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


      #### Build XCORR constraint
      my $xcorr_clause = "";
      my ($icharge,$xcorr);
      for ($icharge=1;$icharge<4;$icharge++) {
        $xcorr = $parameters{"xcorr_charge$icharge"};
        if ($xcorr) {
          if ($xcorr =~ /^[\d\.]+$/) {
            $xcorr_clause = "   AND ( S.assumed_charge = $icharge AND SH.cross_corr = $xcorr )\n";
          } elsif ($xcorr =~ /^between\s+[\d\.]+\s+and\s+[\d\.]+$/i) {
            $xcorr_clause = "   AND ( S.assumed_charge = $icharge AND SH.cross_corr $xcorr )\n";
          } elsif ($xcorr =~ /^[><=][=]*\s*[\d\.]+$/) {
            $xcorr_clause = "   AND ( S.assumed_charge = $icharge AND SH.cross_corr $xcorr )\n";
          } else {
            print "<H4>Cannot parse XCorr Constraint $icharge!  Check syntax.</H4>\n\n";
            return;
          }
        }
      }


      #### Build FILE_ROOT constraint
      my $file_root_clause = "";
      if ($parameters{file_root_constraint}) {
        if ($parameters{file_root_constraint} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
          print "<H4>Cannot parse file_root Constraint!  Check syntax.</H4>\n\n";
          return;
        } else {
          $file_root_clause = "   AND S.file_root LIKE '$parameters{file_root_constraint}'";
        }
      }


      #### Build XCORR_RANK constraint
      my $xcorr_rank_clause = "";
      if ($parameters{xcorr_rank_constraint}) {
        if ($parameters{xcorr_rank_constraint} =~ /^[\d]+$/) {
          $xcorr_clause = "   AND SH.cross_corr_rank = $parameters{xcorr_rank_constraint}";
        } elsif ($parameters{xcorr_rank_constraint} =~ /^between\s+[\d]+\s+and\s+[\d]+$/i) {
          $xcorr_clause = "   AND SH.cross_corr_rank $parameters{xcorr_rank_constraint}";
        } elsif ($parameters{xcorr_rank_constraint} =~ /^[><=][=]*\s*[\d]+$/) {
          $xcorr_clause = "   AND SH.cross_corr_rank $parameters{xcorr_rank_constraint}";
        } else {
          print "<H4>Cannot parse XCorr Rank Constraint!  Check syntax.</H4>\n\n";
          return;
        }
      }


      #### Build CHARGE constraint
      my $charge_clause = "";
      if ($parameters{charge_constraint} =~ /[\d,]+/) {
        $charge_clause = "   AND S.assumed_charge IN ( $parameters{charge_constraint} )";
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


      #### Build ICAT RATIO constraint
      my $ICAT_ratio_clause = "";
      if ($parameters{ICAT_constraint}) {
        if ($parameters{ICAT_constraint} =~ /^[\d\.]+$/) {
          $ICAT_ratio_clause = "   AND ICAT_light/ISNULL(NULLIF(ICAT_heavy,0),0.01) = $parameters{ICAT_constraint}";
        } elsif ($parameters{ICAT_constraint} =~ /^between\s+[\d\.]+\s+and\s+[\d\.]+$/i) {
          $ICAT_ratio_clause = "   AND ICAT_light/ISNULL(NULLIF(ICAT_heavy,0),0.01) $parameters{ICAT_constraint}";
        } elsif ($parameters{ICAT_constraint} =~ /^[><=][=]*\s*[\d\.]+$/) {
          $ICAT_ratio_clause = "   AND ICAT_light/ISNULL(NULLIF(ICAT_heavy,0),0.01) $parameters{ICAT_constraint}";
        } else {
          print "<H4>Cannot parse ICAT Ratio Constraint!  Check syntax.</H4>\n\n";
          return;
        }
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
      my @column_array = (
        ["search_batch_id","SB.search_batch_id","search_batch_id"],
        ["search_id","S.search_id","search_id"],
        ["search_hit_id","SH.search_hit_id","search_hit_id"],
        ["experiment_tag","experiment_tag","Exp"],
        ["database_tag","database_tag","DB"],
        ["data_location","SB.data_location","data_location"],
        ["fraction_tag","F.fraction_tag","fraction_tag"],
        ["file_root","S.file_root","file_root"],
        ["cross_corr_rank","SH.cross_corr_rank","Rxc"],
        ["prelim_score_rank","SH.prelim_score_rank","RSp"],
        ["hit_mass_plus_H","CONVERT(varchar(20),SH.hit_mass_plus_H) + ' (' + STR(SH.mass_delta,5,2) + ')'","(M+H)+"],
        ["cross_corr","STR(SH.cross_corr,5,4)","XCorr"],
        ["next_dCn","STR(SH.next_dCn,5,3)","dCn"],
        ["prelim_score","STR(SH.prelim_score,8,1)","Sp"],
        ["ions","STR(SH.identified_ions,2,0) + '/' + STR(SH.total_ions,3,0)","Ions"],
        ["reference","reference","Reference"],
        ["additional_proteins","additional_proteins","Nmore"],
        ["peptide_string","peptide_string","Peptide"],
        ["peptide","peptide","actual_peptide"],
        ["database_path","PD.database_path","database_path"],
        ["ICAT","STR(ICAT_light,5,2) + ':' + STR(ICAT_heavy,5,2)","ICAT"],
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
	SELECT $limit_clause $columns_clause
	  FROM proteomics.dbo.search_hit SH
	  JOIN proteomics.dbo.search S ON ( SH.search_id = S.search_id )
	  JOIN proteomics.dbo.search_batch SB ON ( S.search_batch_id = SB.search_batch_id )
	  JOIN proteomics.dbo.msms_scan MSS ON ( S.msms_scan_id = MSS.msms_scan_id )
	  JOIN proteomics.dbo.fraction F ON ( MSS.fraction_id = F.fraction_id )
	  JOIN proteomics.dbo.protein_database PD ON ( SB.protein_database_id = PD.protein_database_id )
	  JOIN proteomics.dbo.proteomics_experiment PE ON ( F.experiment_id = PE.experiment_id )
	  LEFT JOIN $TB_ICAT_QUANTITATION ICAT ON ( SH.search_hit_id = ICAT.search_hit_id )
	 WHERE 1 = 1
	$search_batch_clause
	$xcorr_clause
	$charge_clause
	$reference_clause
	$peptide_clause
	$file_root_clause
	$ICAT_ratio_clause
	$order_by_clause
       ~;

      #print "<PRE>\n$sql_query\n</PRE>\n";

      my $base_url = "$CGI_BASE_DIR/Proteomics/BrowseSearchHits.cgi";
      %url_cols = ('file_root' => "http://regis/cgi-bin/showout_html5?OutFile=/data/search/\%$colnameidx{data_location}V/\%$colnameidx{fraction_tag}V/\%$colnameidx{file_root}V.out",
		   'file_root_ATAG' => 'TARGET="Win1"',
      		   'Rxc' => "$base_url?QUERY_NAME=ShowSearch&search_batch_id=\%$colnameidx{search_batch_id}V&file_root_constraint=\%$colnameidx{file_root}V&apply_action=QUERY",
		   'Rxc_ATAG' => 'TARGET="Win1"',
                   'Reference' => "http://regis/cgi-bin/consensus_html4?Ref=%V&Db=\%$colnameidx{database_path}V&Pep=\%$colnameidx{peptide}V&MassType=0",
		   'Reference_ATAG' => 'TARGET="Win1"',
                   'Ions' => "http://regis/cgi-bin/displayions_html5?Dta=/data/search/\%$colnameidx{data_location}V/\%$colnameidx{fraction_tag}V/\%$colnameidx{file_root}V.dta&MassType=0&NumAxis=1&Pep=\%$colnameidx{peptide}V",
		   'Ions_ATAG' => 'TARGET="Win1"',
                   'Nmore' => "http://regis/cgi-bin/blast_html4?Db=\%$colnameidx{database_path}V&Pep=\%$colnameidx{peptide}V&MassType=0",
		   'Nmore_ATAG' => 'TARGET="Win1"',
                   'Peptide' => "http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?PROGRAM=blastp&DATABASE=nr&OVERVIEW=TRUE&EXPECT=1000&FILTER=L&QUERY=\%$colnameidx{peptide}V",
		   'Peptide_ATAG' => 'TARGET="Win1"',
      );

      %hidden_cols = ('data_location' => 1,
                      'search_batch_id' => 1,
                      'search_id' => 1,
                      'search_hit_id' => 1,
                      'fraction_tag' => 1,
                      'actual_peptide' => 1,
                      'database_path' => 1,
      );


    } else {
      $apply_action="BAD SELECTION";
    }


    if ($apply_action eq "QUERY") {
      return $sbeams->displayQueryResult(sql_query=>$sql_query,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols);
    } else {
      print "<H4>Select parameters above and press QUERY</H4>\n";
    }


} # end printEntryForm


