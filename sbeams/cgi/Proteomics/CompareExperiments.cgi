#!/usr/local/bin/perl

###############################################################################
# Program     : CompareExperiments.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               compare the number of hits found in two or more experiments.
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
    my $CATEGORY="Compare Experiments";
    $TABLE_NAME="CompareExperiments" unless ($TABLE_NAME);
    my $base_url = "$CGI_BASE_DIR/Proteomics/${TABLE_NAME}.cgi";


    # Get the columns for this table
    my @columns = $sbeamsPROT->returnTableInfo($TABLE_NAME,"ordered_columns");
    my %input_types = 
      $sbeamsPROT->returnTableInfo($TABLE_NAME,"input_types");

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


    #### If no parameters are supplied, set some sensible defaults
    if (($TABLE_NAME eq "CompareExperiments") && $no_params_flag ) {
      $parameters{annotation_status_id} = 'Annot';
      $parameters{display_options} = 'GroupReference';
      $parameters{n_annotations_constraint} = '>0';
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

    if ($apply_action gt "") {


      #### Build SEARCH BATCH / EXPERIMENT constraint
      my $search_batch_clause = "";
      if ($parameters{search_batch_id}) {
        $search_batch_clause = "   AND SB.search_batch_id IN ( $parameters{search_batch_id} )";
      } else {
        print "<H4>You must select at least two experiments to compare!</H4>\n\n";
        return;
      }



      #### Build REFERENCE PROTEIN constraint
      my $reference_clause = "";
      my $biosequence_name_clause = "";
      if ($parameters{reference_constraint}) {
        if ($parameters{reference_constraint} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
          print "<H4>Cannot parse Reference Constraint!  Check syntax.</H4>\n\n";
          return;
        } else {
          $reference_clause = "   AND SH.reference LIKE '$parameters{reference_constraint}'";
          $biosequence_name_clause = "   AND BS.biosequence_name LIKE '$parameters{reference_constraint}'";
        }
      }


      #### Build GENE NAME constraint
      my $gene_name_clause = "";
      if ($parameters{gene_name_constraint}) {
        if ($parameters{gene_name_constraint} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
          print "<H4>Cannot parse Gene Name Constraint!  Check syntax.</H4>\n\n";
          return;
        } else {
          $gene_name_clause = "   AND BS.biosequence_gene_name LIKE '$parameters{gene_name_constraint}'";
        }
      }


      #### Build PROTEIN DESCRIPTION constraint
      my $description_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"BS.biosequence_desc",
        constraint_type=>"plain_text",
        constraint_name=>"Protein Description",
        constraint_value=>$parameters{description_constraint} );
      return if ($description_clause == -1);


      #### Build ACCESSION NUMBER constraint
      my $accession_clause = "";
      if ($parameters{accession_constraint}) {
        if ($parameters{accession_constraint} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
          print "<H4>Cannot parse Accession Number Constraint!  Check syntax.</H4>\n\n";
          return;
        } else {
          $reference_clause = "   AND BS.biosequence_accession LIKE '$parameters{accession_constraint}'";
        }
      }


      #### Build PEPTIDE constraint
      my $peptide_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"SH.peptide",
        constraint_type=>"plain_text",
        constraint_name=>"Peptide",
        constraint_value=>$parameters{peptide_constraint} );
      return if ($peptide_clause == -1);



      #### Build CHARGE constraint
      my $charge_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"S.assumed_charge",
        constraint_type=>"int_list",
        constraint_name=>"Charge",
        constraint_value=>$parameters{charge_constraint} );
      return if ($charge_clause == -1);


      #### Build MASS constraint
      my $mass_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"SH.hit_mass_plus_H",
        constraint_type=>"flexible_float",
        constraint_name=>"Mass Constraint",
        constraint_value=>$parameters{mass_constraint} );
      return if ($mass_clause == -1);


      #### Build ISOELECTRIC_POINT constraint
      my $isoelectric_point_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"isoelectric_point",
        constraint_type=>"flexible_float",
        constraint_name=>"Isoelectric Point",
        constraint_value=>$parameters{isoelectric_point_constraint} );
      return if ($isoelectric_point_clause == -1);


      #### Build ANNOTATION_STATUS and ANNOTATION_LABELS constraint
      my $annotation_status_clause = "";
      my $annotation_label_clause = "";

      if ($parameters{annotation_label_id}) {
        if ($parameters{annotation_status_id} eq 'Annot') {
          $annotation_label_clause = "   AND SHA.annotation_label_id IN ( $parameters{annotation_label_id} )";
        } elsif ($parameters{annotation_status_id} eq 'UNAnnot') {
          $annotation_status_clause = "   AND SHA.annotation_label_id IS NULL";
          $annotation_label_clause = "";
          print "WARNING: Annotation status and Annotation label constraints conflict!<BR>\n";
        } else {
          $annotation_label_clause = "   AND ( SHA.annotation_label_id IN ( $parameters{annotation_label_id} ) ".
            "OR SHA.annotation_label_id IS NULL )";
        }


      } else {
        if ($parameters{annotation_status_id} eq 'Annot') {
          $annotation_status_clause = "   AND SHA.annotation_label_id IS NOT NULL";
        } elsif ($parameters{annotation_status_id} eq 'UNAnnot') {
          $annotation_status_clause = "   AND SHA.annotation_label_id IS NULL";
        } else {
          #### Nothing
        }

      }


      #### Build NUMBER OF ANNOTATIONS constraint
      my $n_annotations_clause = "";
      if ($parameters{n_annotations_constraint}) {
        if ($parameters{n_annotations_constraint} =~ /^[\d]+$/) {
          $n_annotations_clause = "   AND row_count = $parameters{n_annotations_constraint}";
        } elsif ($parameters{n_annotations_constraint} =~ /^between\s+[\d]+\s+and\s+[\d]+$/i) {
          $n_annotations_clause = "   AND row_count $parameters{n_annotations_constraint}";
        } elsif ($parameters{n_annotations_constraint} =~ /^[><=][=]*\s*[\d]+$/) {
          $n_annotations_clause = "   AND row_count $parameters{n_annotations_constraint}";
        } else {
          print "<H4>Cannot parse Number of Annotations Constraint!  Check syntax.</H4>\n\n";
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
      unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=99999) {
        $parameters{row_limit} = 1000;
      }
      my $limit_clause = "TOP $parameters{row_limit}";


      #### Define the desired columns
      my $group_by_clause = "";
      my $final_group_by_clause = "";
      my @column_array;
      my $peptide_column = "";
      my $count_column = "";

      my %experiment_names = getExperimentNames($parameters{search_batch_id});


      #### If grouping by peptide,reference
      if ( $parameters{display_options} =~ /GroupPeptide/ ) {
        @column_array = (
          ["biosequence_gene_name","BS.biosequence_gene_name","Gene Name"],
          ["accessor","DBX.accessor","accessor"],
          ["biosequence_accession","BS.biosequence_accession","Accession"],
          ["reference","BS.biosequence_name","Reference"],
          ["peptide","peptide","Peptide"],
        );

	my @search_batch_ids = split(/,/,$parameters{search_batch_id});
	foreach my $id (@search_batch_ids) {
          push(@column_array, ["count$id",
            "SUM(CASE WHEN tABS.search_batch_id = $id THEN tABS.row_count ELSE 0 END)",
            "$experiment_names{$id}"] );
        }

        push(@column_array,
          ["biosequence_desc","BS.biosequence_desc","Reference Description"],
        );

        $group_by_clause = " GROUP BY SB.search_batch_id,SH.biosequence_id,peptide";
        $final_group_by_clause = " GROUP BY BS.biosequence_gene_name,BS.biosequence_accession,BS.biosequence_name,peptide,BS.biosequence_desc,DBX.accessor";
        $count_column = "COUNT(*) AS 'row_count'";
        $peptide_column = "peptide,";


      #### If grouping by reference
      } elsif ( $parameters{display_options} =~ /GroupReference/ ) {
        @column_array = (
          ["biosequence_gene_name","BS.biosequence_gene_name","Gene Name"],
          ["accessor","DBX.accessor","accessor"],
          ["biosequence_accession","BS.biosequence_accession","Accession"],
          ["reference","BS.biosequence_name","Reference"],
        );

	my @search_batch_ids = split(/,/,$parameters{search_batch_id});
	foreach my $id (@search_batch_ids) {
          push(@column_array, ["count$id",
            "SUM(CASE WHEN tABS.search_batch_id = $id THEN tABS.row_count ELSE 0 END)",
            "$experiment_names{$id}"] );
        }

        push(@column_array,
          ["biosequence_desc","BS.biosequence_desc","Reference Description"],
        );

        $group_by_clause = " GROUP BY SB.search_batch_id,SH.biosequence_id";
        $final_group_by_clause = " GROUP BY BS.biosequence_gene_name,BS.biosequence_accession,BS.biosequence_name,BS.biosequence_desc,DBX.accessor";
        $count_column = "COUNT(*) AS 'row_count'";


      #### If no grouping
      } else {
        @column_array = (
          ["biosequence_gene_name","BS.biosequence_gene_name","Gene Name"],
          ["accessor","DBX.accessor","accessor"],
          ["biosequence_accession","BS.biosequence_accession","Accession"],
          ["reference","BS.biosequence_name","Reference"],
          ["peptide","peptide","Peptide"],
        );

	my @search_batch_ids = split(/,/,$parameters{search_batch_id});
	foreach my $id (@search_batch_ids) {
          push(@column_array, ["count$id",
            "SUM(CASE WHEN tABS.search_batch_id = $id THEN tABS.row_count ELSE 0 END)",
            "$experiment_names{$id}"] );
        }

        push(@column_array,
          ["biosequence_desc","BS.biosequence_desc","Reference Description"],
        );

        $peptide_column = "peptide,";
        $final_group_by_clause = " GROUP BY BS.biosequence_gene_name,BS.biosequence_accession,BS.biosequence_name,peptide,BS.biosequence_desc,DBX.accessor";
        $count_column = "1 AS 'row_count'";
      }


      #### Limit the width of the Reference column if user selected
      if ( $parameters{display_options} =~ /MaxRefWidth/ ) {
        $max_widths{'Reference'} = 20;
      }
      #### Set flag to display SQL statement if user selected
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


      $sql_query = qq~
	SELECT DISTINCT BS.biosequence_id
	  INTO #tmpBSids
	  FROM proteomics.dbo.biosequence BS
	  JOIN proteomics.dbo.search_batch SB ON ( BS.biosequence_set_id = SB.biosequence_set_id )
	 WHERE 1 = 1
	$search_batch_clause
	$biosequence_name_clause
        $description_clause
	$gene_name_clause
	$accession_clause

	--

	SELECT SB.search_batch_id,SH.biosequence_id,$peptide_column$count_column
	  INTO #tmpAnnBSids
	  FROM proteomics.dbo.search_hit SH
	  JOIN proteomics.dbo.search S ON ( SH.search_id = S.search_id )
	  LEFT JOIN proteomics.dbo.search_hit_annotation SHA ON ( SH.search_hit_id = SHA.search_hit_id )
	  JOIN proteomics.dbo.search_batch SB ON ( S.search_batch_id = SB.search_batch_id )
	  JOIN $TBPR_BIOSEQUENCE BS ON ( SB.biosequence_set_id = BS.biosequence_set_id AND SH.biosequence_id = BS.biosequence_id )
	 WHERE 1 = 1
	$search_batch_clause
	$reference_clause
	$gene_name_clause
        $description_clause
	$accession_clause
	$peptide_clause
	$charge_clause
	$mass_clause
	$isoelectric_point_clause
	$annotation_label_clause
	$annotation_status_clause
	$group_by_clause

	--

	SELECT $limit_clause $columns_clause
	  FROM #tmpBSids tBS
	  LEFT JOIN #tmpAnnBSids tABS ON ( tBS.biosequence_id = tABS.biosequence_id )
	  JOIN $TBPR_BIOSEQUENCE BS ON ( tBS.biosequence_id = BS.biosequence_id )
          LEFT JOIN $TB_DBXREF DBX ON ( BS.dbxref_id = DBX.dbxref_id )
	$n_annotations_clause
        $description_clause
        $final_group_by_clause
	$order_by_clause

       ~;

      #print "<PRE>\n$sql_query\n</PRE>\n";

      %url_cols = ('Accession' => "\%$colnameidx{accessor}V\%$colnameidx{biosequence_accession}V",
		   'Accession_ATAG' => 'TARGET="Win1"',
                   'Reference' => "$CGI_BASE_DIR/Proteomics/BrowseSearchHits.cgi?QUERY_NAME=BrowseSearchHits&reference_constraint=\%$colnameidx{reference}V&search_batch_id=$parameters{search_batch_id}&display_options=BSDesc,MaxRefWidth&apply_action=$apply_action",
		   'Reference_ATAG' => 'TARGET="Win1"',
		   'Peptide' => "$CGI_BASE_DIR/Proteomics/BrowseSearchHits.cgi?QUERY_NAME=BrowseSearchHits&peptide_constraint=\%$colnameidx{peptide}V&search_batch_id=$parameters{search_batch_id}&display_options=BSDesc,MaxRefWidth&apply_action=$apply_action",
		   'Peptide_ATAG' => 'TARGET="Win1"',
      );

      %hidden_cols = ('accessor' => 1,
      );

		   #######'Reference_ATAG' => "TARGET=\"Win1\" ONMOUSEOVER=\"window.status='%V'; return true\"",


      #print "<PRE>$sql_query\n</PRE><BR>\n";

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


     #### Display some statistics for the result set
     summarizeExperimentComparison(rs_params_ref=>\%rs_params,
          resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters,
	  base_url=>$base_url);


    #### If QUERY was not selected, then tell the user to enter some parameters
    } else {
      print "<H4>Select parameters above and press QUERY</H4>\n";
    }


} # end printEntryForm


###############################################################################
# getExperimentNames: return a hash of the experiment (and possibly
#         search_batch) names of the supplied list of id's
###############################################################################
sub getExperimentNames {
  my $search_batch_ids = shift || die "getExperimentNames: missing search_batch_ids";

  my ($i,$element,$key,$value,$line,$result,$sql);

  my @search_batch_ids = split(/,/,$search_batch_ids);

  #### Get the data for all the specified search_batch_ids
  $sql = qq~
      SELECT search_batch_id,experiment_tag,set_tag
        FROM proteomics.dbo.proteomics_experiment PE
        JOIN proteomics.dbo.search_batch SB ON ( PE.experiment_id = SB.experiment_id )
        JOIN proteomics.dbo.biosequence_set BSS ON ( SB.biosequence_set_id = BSS.biosequence_set_id )
       WHERE search_batch_id IN ( $search_batch_ids )
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);

  #### Define some variables
  my $row;
  my %exp_tag_hash;            #### Contains just the experment tags
  my %exp_search_tag_hash;     #### Contains both exp and search tags
  my %unique_tags_hash;        #### Contains all exp tags in hash
  my $need_search_tags = 0;    #### Set if we need to do search tags


  #### Go ahead and build all the hashes.  The idea here is that if all
  #### the selected search_batch_ids correspond to different experiments
  #### (common) then we just want to display the experiment names.  But,
  #### if two search_batch_id's correspond to two different search batches
  #### for the same experiment, then we need to display both experiment
  #### names and search library tags
  foreach $row (@rows) {
    my $search_batch_id = $row->[0];
    my $experiment_tag = $row->[1];
    my $set_tag = $row->[2];
    $exp_tag_hash{$search_batch_id} = $experiment_tag;
    $exp_search_tag_hash{$search_batch_id} = "$experiment_tag($set_tag)";
    if (exists($unique_tags_hash{$experiment_tag})) {
      $need_search_tags = 1;
    }
    $unique_tags_hash{$experiment_tag} = 1;
  }

  return %exp_search_tag_hash if ($need_search_tags);
  return %exp_tag_hash;

} # end getExperimentNames


###############################################################################
# summarizeExperimentComparison
#
# Print out some statistics from the resultset
###############################################################################
sub summarizeExperimentComparison {
    my %args = @_;

    my ($i,$element,$key,$value,$line,$result,$sql);

    #### Process the arguments list
    my $resultset_ref = $args{'resultset_ref'};
    my $rs_params_ref = $args{'rs_params_ref'};
    my $query_parameters_ref = $args{'query_parameters_ref'};
    my $base_url = $args{'base_url'};

    my %rs_params = %{$rs_params_ref};
    my %parameters = %{$query_parameters_ref};


    #### Start a new section
    print "<HR SIZE=3 WIDTH=\"30%\" NOSHADE ALIGN=LEFT>";
    print "<B>Summary of resultset:</B><BR>\n";


    #### Print a warning if the resultset is truncated
    if ( $query_parameters_ref->{row_limit} == scalar(@{$resultset_ref->{data_ref}}) ) {
      print "<font color=red>WARNING: Resultset ".
	"truncated at $parameters{row_limit} rows. ".
	"Statistics only valid for the rows returned!</font><BR>\n";
    }


    #### Define non-data columns that should be ignored
    my %non_data_columns = ( 'Gene Name'=>1, 'Accession'=>1,
      'Reference'=>1, 'Reference Description'=>1, 'Peptide'=>1);


    #### Figure out what the data columns are and create two
    #### arrays, one of column names and one of data column indices
    my $column;
    my $rowtype = "Protein";
    my @data_column_names;
    my @data_columns;
    for ($i=0; $i<scalar(@{$resultset_ref->{column_list_ref}}); $i++) {
      $column = $resultset_ref->{column_list_ref}->[$i];
      $rowtype = "Peptide" if ($column eq 'Peptide');
      unless ($non_data_columns{$column}) {
	push(@data_column_names,$column);
	push(@data_columns,$i);
      }
    }


    #### Create a matrix for compiling overlap statistics.  Put
    #### blank values in each of the cells
    my ($summary_rows,$j);
    for ($i=0; $i<scalar(@data_columns); $i++) {
      $summary_rows->[$i]->[0] = $data_column_names[$i];
      for ($j=0; $j<scalar(@data_columns); $j++) {
        $summary_rows->[$i]->[$j+1] = '';
      }
      #print "$i: $data_column_names[$i] = $data_columns[$i]<BR>\n";
    }
    #print "<BR><BR>\n";


    #### Set up variables for statistics collection
    my $row;
    my $n_rows = scalar(@{$resultset_ref->{data_ref}});
    my $n_columns = scalar(@data_columns);
    my %stats = ( 'nonzero_in_all'=>0, 'more_than_one_in_all'=>0 );
    my %rowstats;

    #### Loop over each row in the resultset, compiling statistics
    for ($row=0; $row<$n_rows; $row++) {
      %rowstats = ( 'nonzero'=>0, 'more_than_one' => 0);

      #### Loop of each column and keep statistics
      for ($column=0; $column<$n_columns; $column++) {
        $rowstats{nonzero}++ if ($resultset_ref->{data_ref}->[$row]->[$data_columns[$column]]);
        $rowstats{more_than_one}++ if ($resultset_ref->{data_ref}->[$row]->[$data_columns[$column]] > 1);

        #### Loop over the rest of the columns to build the matrix
        for ($i=$column; $i<$n_columns; $i++) {
          $summary_rows->[$column]->[$i+1]++
            if ( ($resultset_ref->{data_ref}->[$row]->[$data_columns[$column]]) &&
                 ($resultset_ref->{data_ref}->[$row]->[$data_columns[$i]]) );
	}
      }
      $stats{nonzero_in_all}++ if ($rowstats{nonzero} == $n_columns);
      $stats{more_than_one_in_all}++ if ($rowstats{more_than_one} == $n_columns);
    }


    #### Print the statistics
    print "Total number of ${rowtype}s: $n_rows<BR>\n";
    print "Number of ${rowtype}s seen in every experiment: $stats{nonzero_in_all}<BR>\n";
    print "Number of ${rowtype}s seen more than once in every experiment: $stats{more_than_one_in_all}<BR>\n";


    #### Display the matrix as a HTML table resultset
    print "<BR>Intersection of observed ${rowtype}s in experiments:<BR>\n";
    my %dataset;
    $dataset{data_ref} = $summary_rows;
    $dataset{column_list_ref} = ['-',@data_column_names];
    $dataset{precisions_list_ref} = [ (50) x ($n_columns+1) ];
    $sbeams->displayResultSet(page_size=>100,page_number=>0,
      #url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols,
      resultset_ref=>\%dataset);


    #### Print out some debugging information about the returned resultset:
    if (0 == 1) {
      print "<BR><BR>resultset_ref = $resultset_ref<BR>\n";
      while ( ($key,$value) = each %{$resultset_ref} ) {
        printf("%s = %s<BR>\n",$key,$value);
      }
      #print "columnlist = ",
      #  join(" , ",@{$resultset_ref->{column_list_ref}}),"<BR>\n";
      print "nrows = ",scalar(@{$resultset_ref->{data_ref}}),"<BR>\n";
      print "rs_set_name=",$rs_params{set_name},"<BR>\n";
    }


    return 1;


} # end summarizeExperimentComparison
