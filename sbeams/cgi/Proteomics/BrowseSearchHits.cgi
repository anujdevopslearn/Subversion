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

    my $CATEGORY="Browse Search Hits";
    my $TABLE_NAME="BrowseSearchHits";
    $TABLE_NAME = $q->param("QUERY_NAME") if $q->param("QUERY_NAME");


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

    my $apply_action  = $q->param('apply_action');


    #### If xcorr_charge is undefined (not just "") then set to a high limit
    #### So that a naive query is quick
    if ( ($TABLE_NAME eq "BrowseSearchHits") && $no_params_flag ) {
      $parameters{xcorr_charge1} = ">4.0";
      $parameters{xcorr_charge2} = ">4.5";
      $parameters{xcorr_charge3} = ">5.0";
      $parameters{sort_order} = "experiment_tag,set_tag,S.file_root,SH.cross_corr_rank,SH.hit_index";
    }


    #### If this is a ShowSearch query and sort_order is undefined (not just ""),
    #### then set to a likely default
    if (($TABLE_NAME eq "ShowSearch") && (!defined($parameters{sort_order})) ) {
      $parameters{sort_order} = "S.file_root,experiment_tag,set_tag,SH.cross_corr_rank,SH.hit_index";
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
    my $show_sql;

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
            $xcorr_clause .= "	    OR ( S.assumed_charge = $icharge AND SH.cross_corr = $xcorr )\n";
          } elsif ($xcorr =~ /^between\s+[\d\.]+\s+and\s+[\d\.]+$/i) {
            $xcorr_clause .= "	    OR ( S.assumed_charge = $icharge AND SH.cross_corr $xcorr )\n";
          } elsif ($xcorr =~ /^[><=][=]*\s*[\d\.]+$/) {
            $xcorr_clause .= "	    OR ( S.assumed_charge = $icharge AND SH.cross_corr $xcorr )\n";
          } else {
            print "<H4>Cannot parse XCorr Constraint $icharge!  Check syntax.</H4>\n\n";
            return;
          }
        }
      }
      if ($xcorr_clause) {
        $xcorr_clause =~ s/^\s+OR/ AND \(/;
        $xcorr_clause .= "	     )\n";
      }


      #### Build FILE_ROOT constraint
      my $file_root_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"S.file_root",
        constraint_type=>"plain_text",
        constraint_name=>"file_root",
        constraint_value=>$parameters{file_root_constraint} );
      return if ($file_root_clause == -1);


      #### Build BEST_HIT constraint
      my $best_hit_clause = "";
      if ($parameters{best_hit_constraint}) {
        if ($parameters{best_hit_constraint} =~ /Any/i) {
          $best_hit_clause = "   AND best_hit_flag > ''";
        } elsif ($parameters{best_hit_constraint} =~ /User/i) {
          $best_hit_clause = "   AND best_hit_flag = 'U'";
        } elsif ($parameters{best_hit_constraint} =~ /Default/i) {
          $best_hit_clause = "   AND best_hit_flag = 'D'";
        }
      }


      #### Build XCORR_RANK constraint
      my $xcorr_rank_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"SH.cross_corr_rank",
        constraint_type=>"flexible_int",
        constraint_name=>"XCorr Rank",
        constraint_value=>$parameters{xcorr_rank_constraint} );
      return if ($xcorr_rank_clause == -1);


      #### Build CHARGE constraint
      my $charge_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"S.assumed_charge",
        constraint_type=>"int_list",
        constraint_name=>"Charge",
        constraint_value=>$parameters{charge_constraint} );
      return if ($charge_clause == -1);


      #### Build REFERENCE PROTEIN constraint
      my $reference_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"SH.reference",
        constraint_type=>"plain_text",
        constraint_name=>"Reference",
        constraint_value=>$parameters{reference_constraint} );
      return if ($reference_clause == -1);


      #### Build PROTEIN DESCRIPTION constraint
      my $description_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"BS.biosequence_desc",
        constraint_type=>"plain_text",
        constraint_name=>"Protein Description",
        constraint_value=>$parameters{description_constraint} );
      return if ($description_clause == -1);


      #### Build PEPTIDE constraint
      my $peptide_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"SH.peptide",
        constraint_type=>"plain_text",
        constraint_name=>"Peptide",
        constraint_value=>$parameters{peptide_constraint} );
      return if ($peptide_clause == -1);


      #### Build PEPTIDE STRING constraint
      my $peptide_string_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"SH.peptide_string",
        constraint_type=>"plain_text",
        constraint_name=>"Peptide String",
        constraint_value=>$parameters{peptide_string_constraint} );
      return if ($peptide_string_clause == -1);


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


      #### Build QUANTITATION constraint
      my $quantitation_clause = "";
      if ($parameters{quantitation_constraint}) {
        if ($parameters{quantitation_constraint} =~ /^[\d\.]+$/) {
          $quantitation_clause = "   AND d0_intensity/ISNULL(NULLIF(d8_intensity,0),0.01) = $parameters{quantitation_constraint}";
        } elsif ($parameters{quantitation_constraint} =~ /^between\s+[\d\.]+\s+and\s+[\d\.]+$/i) {
          $quantitation_clause = "   AND d0_intensity/ISNULL(NULLIF(d8_intensity,0),0.01) $parameters{quantitation_constraint}";
        } elsif ($parameters{quantitation_constraint} =~ /^[><=][=]*\s*[\d\.]+$/) {
          $quantitation_clause = "   AND d0_intensity/ISNULL(NULLIF(d8_intensity,0),0.01) $parameters{quantitation_constraint}";
        } else {
          print "<H4>Cannot parse Quantitation Constraint!  Check syntax.</H4>\n\n";
          return;
        }
      }


      #### Build QUANTITATION FORMAT
      my $quant_format_clause = "";
      $parameters{quantitation_format} = "d81" unless $parameters{quantitation_format};
      if ($parameters{quantitation_format}) {
        if ($parameters{quantitation_format} eq "raw") {
          $quant_format_clause = "STR(d0_intensity,5,2) + ':' + STR(d8_intensity,5,2) + ".
            "(CASE WHEN QUAN.date_modified != QUAN.date_created THEN ' *' ELSE '' END)";
        } elsif ($parameters{quantitation_format} eq "High1") {
          $quant_format_clause = "(CASE WHEN d0_intensity > d8_intensity ".
	    "THEN '1 : ' + STR(d8_intensity/ISNULL(NULLIF(d0_intensity,0.0),0.001),5,2) ".
	    "ELSE STR(d0_intensity/ISNULL(NULLIF(d8_intensity,0.0),0.001),4,2) + ' : 1' ".
	    "END) + ".
            "ISNULL(manually_changed,'')";
        } elsif ($parameters{quantitation_format} eq "d01") {
          $quant_format_clause = "'1 :' + STR(d8_intensity/ISNULL(NULLIF(d0_intensity,0.0),0.001),5,2) + ".
            "ISNULL(manually_changed,'')";
        } elsif ($parameters{quantitation_format} eq "d81") {
          $quant_format_clause = "STR(d0_intensity/ISNULL(NULLIF(d8_intensity,0.0),0.001),5,2) + ': 1' + ".
            "ISNULL(manually_changed,'')";
        } elsif ($parameters{quantitation_format} eq "decimal") {
          $quant_format_clause = "STR(d0_intensity/ISNULL(NULLIF(d8_intensity,0.0),0.001),10,4) + ".
            "ISNULL(manually_changed,'')";
        } elsif ($parameters{quantitation_format} eq "decimalplain") {
          $quant_format_clause = "STR(d0_intensity/ISNULL(NULLIF(d8_intensity,0.0),0.001),10,4)";
        } else {
          print "<H4>Cannot parse Quantitation Format!  Check syntax.</H4>\n\n";
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


      #### Build Additional peptide constraints
      my $second_peptide_clause = "";
      if ($parameters{peptide_options}) {
        if ($parameters{peptide_options} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
          print "<H4>Cannot parse Peptide Options!  Check syntax.</H4>\n\n";
          return;
        } else {
          my $C = "";
          $C = "C" if ( $parameters{peptide_options} =~ /C_containing/ );
          if ( $parameters{peptide_options} =~ /DoublyTryptic/ ) {
            $second_peptide_clause = "   AND SH.peptide_string LIKE '[RK].%${C}%[RK]._'";
          } elsif ( $parameters{peptide_options} =~ /SinglyTryptic/ ) {
            $second_peptide_clause = "   AND ( SH.peptide_string LIKE '[RK].%${C}%._' OR ".
                                              "SH.peptide_string LIKE '_.%${C}%[RK]._' )";
          } else {
            $second_peptide_clause = "   AND SH.peptide_string LIKE '_.%${C}%._'";
          }
        }
      }


      #### Build ROWCOUNT constraint
      unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=99999) {
        $parameters{row_limit} = 100;
      }
      my $limit_clause = "TOP $parameters{row_limit}";


      #### Define the desired columns
      #### [friendly name used in url_cols,SQL,displayed column title]
      my @column_array = (
        ["search_batch_id","SB.search_batch_id","search_batch_id"],
        ["msms_spectrum_id","S.msms_spectrum_id","msms_spectrum_id"],
        ["search_id","S.search_id","search_id"],
        ["search_hit_id","SH.search_hit_id","search_hit_id"],
        ["experiment_tag","experiment_tag","Exp"],
        ["set_tag","set_tag","DB"],
        ["data_location","SB.data_location","data_location"],
        ["fraction_tag","F.fraction_tag","fraction_tag"],
        ["file_root","S.file_root","file_root"],
        ["out_file","'.out'",".out"],
        ["best_hit_flag","best_hit_flag","bh"],
        ["cross_corr_rank","SH.cross_corr_rank","Rxc"],
        ["prelim_score_rank","SH.prelim_score_rank","RSp"],
        ["hit_mass_plus_H","CONVERT(varchar(20),SH.hit_mass_plus_H) + ' (' + STR(SH.mass_delta,5,2) + ')'","(M+H)+"],
        ["cross_corr","STR(SH.cross_corr,5,4)","XCorr"],
        ["next_dCn","STR(SH.next_dCn,5,3)","dCn"],
        ["prelim_score","STR(SH.prelim_score,8,1)","Sp"],
        ["ions","STR(SH.identified_ions,2,0) + '/' + STR(SH.total_ions,3,0)","Ions"],
#        ["ions_old","STR(SH.identified_ions,2,0) + '/' + STR(SH.total_ions,3,0)","!Ions"],
        ["reference","reference","Reference"],
        ["additional_proteins","additional_proteins","N+"],
        ["additional_proteins_old","additional_proteins","!N+"],
        ["peptide_string","peptide_string","Peptide"],
        ["peptide","peptide","actual_peptide"],
        ["biosequence_set_id","BSS.biosequence_set_id","biosequence_set_id"],
        ["set_path","BSS.set_path","set_path"],
        ["isoelectric_point","STR(isoelectric_point,8,3)","pI"],
        ["quantitation","$quant_format_clause","Quant"],
        ["quantitation_id","QUAN.quantitation_id","quantitation_id"],
#        ["assumed_charge","S.assumed_charge","assumed_charge"],
        ["search_hit_annotation_id","SHA.search_hit_annotation_id","search_hit_annotation_id"],
        ["annotation_label","label_desc","Annot"],
      );


      #### Adjust the columns definition based on user-selected options
      if ( $parameters{display_options} =~ /BSDesc/ ) {
        push(@column_array,["biosequence_desc","biosequence_desc","Reference Description"]);
      }
      if ( $parameters{display_options} =~ /MaxRefWidth/ ) {
        $max_widths{'Reference'} = 20;
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

      $sql_query = qq~
	SELECT $limit_clause $columns_clause
	  FROM $TBPR_SEARCH_HIT SH
	  JOIN $TBPR_SEARCH S ON ( SH.search_id = S.search_id )
	  JOIN $TBPR_SEARCH_BATCH SB ON ( S.search_batch_id = SB.search_batch_id )
	  JOIN $TBPR_MSMS_SPECTRUM MSS ON ( S.msms_spectrum_id = MSS.msms_spectrum_id )
	  JOIN $TBPR_FRACTION F ON ( MSS.fraction_id = F.fraction_id )
	  JOIN $TBPR_BIOSEQUENCE_SET BSS ON ( SB.biosequence_set_id = BSS.biosequence_set_id )
	  JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON ( F.experiment_id = PE.experiment_id )
	  LEFT JOIN $TBPR_QUANTITATION QUAN ON ( SH.search_hit_id = QUAN.search_hit_id )
	  LEFT JOIN $TBPR_BIOSEQUENCE BS ON ( SB.biosequence_set_id = BS.biosequence_set_id AND SH.reference = BS.biosequence_name )
	  LEFT JOIN $TBPR_SEARCH_HIT_ANNOTATION SHA ON ( SH.search_hit_id = SHA.search_hit_id )
	  LEFT JOIN $TBPR_ANNOTATION_LABEL AL ON ( SHA.annotation_label_id = AL.annotation_label_id )
	 WHERE 1 = 1
	$search_batch_clause
	$best_hit_clause
	$xcorr_clause
	$xcorr_rank_clause
	$charge_clause
	$reference_clause
        $description_clause
	$peptide_clause
	$peptide_string_clause
	$second_peptide_clause
	$mass_clause
	$isoelectric_point_clause
	$file_root_clause
	$quantitation_clause
	$annotation_label_clause
	$annotation_status_clause
	$order_by_clause
       ~;

      #print "<PRE>\n$sql_query\n</PRE>\n";

      # '.out' => "http://regis/cgi-bin/showout_html5?OutFile=/data/search/\%$colnameidx{data_location}V/\%$colnameidx{fraction_tag}V/\%$colnameidx{file_root}V.out"


      my $base_url = "$CGI_BASE_DIR/Proteomics/BrowseSearchHits.cgi";
      %url_cols = ('.out' => "$CGI_BASE_DIR/Proteomics/ShowOutFile.cgi?search_id=\%$colnameidx{search_id}V",
		   '.out_ATAG' => 'TARGET="Win1"',
      		   'file_root' => "$base_url?QUERY_NAME=ShowSearch&search_batch_id=\%$colnameidx{search_batch_id}V&file_root_constraint=\%$colnameidx{file_root}V&apply_action=QUERY",
		   'file_root_ATAG' => 'TARGET="Win1"',
                   'Reference' => "http://regis/cgi-bin/consensus_html4?Ref=%V&Db=\%$colnameidx{set_path}V&Pep=\%$colnameidx{peptide}V&MassType=0",
		   'Reference_ATAG' => 'TARGET="Win1"',
                   '!Ions' => "http://regis/cgi-bin/displayions_html5?Dta=/data/search/\%$colnameidx{data_location}V/\%$colnameidx{fraction_tag}V/\%$colnameidx{file_root}V.dta&MassType=0&NumAxis=1&Pep=\%$colnameidx{peptide}V",
		   '!Ions_ATAG' => 'TARGET="Win1"',
                   'Ions' => "$CGI_BASE_DIR/Proteomics/ShowSpectrum.cgi?msms_spectrum_id=\%$colnameidx{msms_spectrum_id}V&search_batch_id=\%$colnameidx{search_batch_id}V&peptide=\%$colnameidx{peptide_string}V",
		   'Ions_ATAG' => 'TARGET="Win1"',
                   '!N+' => "http://regis/cgi-bin/blast_html4?Db=\%$colnameidx{set_path}V&Pep=\%$colnameidx{peptide}V&MassType=0",
		   '!N+_ATAG' => 'TARGET="Win1"',
                   'N+' => "$CGI_BASE_DIR/Proteomics/BrowseBioSequence.cgi?biosequence_set_id=\%$colnameidx{biosequence_set_id}V&biosequence_seq_constraint=*\%$colnameidx{peptide}V*&display_options=MaxSeqWidth&search_hit_id=\%$colnameidx{search_hit_id}V&apply_action=HIDEQUERY",
		   'N+_ATAG' => 'TARGET="Win1"',
                   'Peptide' => "http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?PROGRAM=blastp&DATABASE=nr&OVERVIEW=TRUE&EXPECT=1000&FILTER=L&QUERY=\%$colnameidx{peptide}V",
		   'Peptide_ATAG' => 'TARGET="Win1"',
                   'Annot' => "$CGI_BASE_DIR/Proteomics/ManageTable.cgi?TABLE_NAME=search_hit_annotation&search_hit_annotation_id=\%$colnameidx{search_hit_annotation_id}V&search_hit_id=\%$colnameidx{search_hit_id}V&ShowEntryForm=1",
		   'Annot_ATAG' => 'TARGET="Win1"',
		   'Annot_ISNULL' => ' [Add] ',
                   'bh' => "$CGI_BASE_DIR/Proteomics/SetBestHit.cgi?search_id=\%$colnameidx{search_id}V&search_hit_id=\%$colnameidx{search_hit_id}V",
		   'bh_ATAG' => 'TARGET="Win1"',
                   'Quant' => "$CGI_BASE_DIR/Proteomics/Xpress.cgi?quantitation_id=\%$colnameidx{quantitation_id}V",
		   'Quant_ATAG' => 'TARGET="Win1"',
      );

      %hidden_cols = ('data_location' => 1,
                      'search_batch_id' => 1,
                      'msms_spectrum_id' => 1,
                      'search_id' => 1,
                      'search_hit_id' => 1,
                      'fraction_tag' => 1,
                      'actual_peptide' => 1,
                      'set_path' => 1,
                      'biosequence_set_id' => 1,
                      'search_hit_annotation_id' => 1,
                      'quantitation_id' => 1,
#                      'assumed_charge' => 1,
      );

		   #######'Reference_ATAG' => "TARGET=\"Win1\" ONMOUSEOVER=\"window.status='%V'; return true\"",

    } else {
      $apply_action="BAD SELECTION";
    }



    #### If QUERY was selected, go ahead and execute the query!
    if ($apply_action =~ /QUERY/i) {

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


