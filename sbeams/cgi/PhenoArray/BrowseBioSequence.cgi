#!/usr/local/bin/perl

###############################################################################
# Program     : BrowseBioSequence.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               browse through BioSequences, although this is usually meant
#               to be used in an autolinked way.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsPH $dbh $current_contact_id $current_username
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

use SBEAMS::PhenoArray;
use SBEAMS::PhenoArray::Settings;
use SBEAMS::PhenoArray::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsPH = new SBEAMS::PhenoArray;
$sbeamsPH->setSBEAMS($sbeams);
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
    $sbeamsPH->printPageHeader();
    processRequests();
    $sbeamsPH->printPageFooter();

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

    my $apply_action  = $q->param('apply_action');

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

    my $CATEGORY="BioSequence Search";
    my $TABLE_NAME="PH_BrowseBioSequence";
    $TABLE_NAME = $q->param("QUERY_NAME") if $q->param("QUERY_NAME");
    ($PROGRAM_FILE_NAME) =
      $sbeamsPH->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");

    # Get the columns for this table
    my @columns = $sbeamsPH->returnTableInfo($TABLE_NAME,"ordered_columns");
    my %input_types = 
      $sbeamsPH->returnTableInfo($TABLE_NAME,"input_types");


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
    my $search_hit_id  = $q->param('search_hit_id');


    #### If xcorr_charge is undefined (not just "") then set to a high limit
    #### So that a naive query is quick
    if ( ($TABLE_NAME eq "BrowseSearchHits") && $no_params_flag ) {
      $parameters{xcorr_charge1} = ">4.0";
      $parameters{xcorr_charge2} = ">4.5";
      $parameters{xcorr_charge3} = ">5.0";
      $parameters{sort_order} = "experiment_tag,set_tag,S.file_root,SH.cross_corr_rank";
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
        <FORM METHOD="post" ACTION="$PROGRAM_FILE_NAME" $file_upload_flag>
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
      my $limit_clause = "TOP 100";
      if ($parameters{row_limit} > 0 && $parameters{row_limit}<=99999) {
        $limit_clause = "TOP $parameters{row_limit}";
      }


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

      $sql_query = qq~
	SELECT $limit_clause $columns_clause
	  FROM $TBPH_BIOSEQUENCE BS
	  LEFT JOIN $TBPH_BIOSEQUENCE_SET BSS ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
	 WHERE 1 = 1
	$biosequence_set_clause
	$biosequence_name_clause
	$biosequence_gene_name_clause
	$biosequence_seq_clause
	$biosequence_desc_clause
	$order_by_clause
       ~;


      my $base_url = "$CGI_BASE_DIR/PhenoArray/BrowseBioSequence.cgi";
      %url_cols = ('set_tag' => "$CGI_BASE_DIR/PhenoArray/ManageTable.cgi?TABLE_NAME=PH_biosequence_set&biosequence_set_id=\%$colnameidx{biosequence_set_id}V",
                   'gene_name' => "\%$colnameidx{uri}V\%$colnameidx{gene_name}V",
      );

      %hidden_cols = ('biosequence_set_id' => 1,
                      'biosequence_id' => 1,
                      'uri' => 1,
       );


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


      #### Print out some information about the returned resultset:
      if (0 == 1) {
        print "resultset_ref = $resultset_ref<BR>\n";
        while ( ($key,$value) = each %{$resultset_ref} ) {
          printf("%s = %s<BR>\n",$key,$value);
        }
        print "columnlist = ",join(" , ",@{$resultset_ref->{column_list_ref}}),"<BR>\n";
        while ( ($key,$value) = each %{$resultset_ref->{column_hash_ref}} ) {
          printf("%s = %s<BR>\n",$key,$value);
        }
        foreach $element (@{$resultset_ref->{data_ref}}) {
          print "->",join(" | ",@{$element}),"<BR>\n";
        }
      }

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
		</FORM>
        ~;

      }

      return;


    #### If QUERY was not selected, then tell the user to enter some parameters
    } else {
      print "<H4>Select parameters above and press QUERY</H4>\n";
    }


} # end printEntryForm

