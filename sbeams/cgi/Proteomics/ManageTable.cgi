#!/usr/local/bin/perl 

###############################################################################
# Program     : ManageTable.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               manage the contents of a table.
#               This means viewing, inserting, updating,
#               and deleting records.
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
use SBEAMS::Connection::TableInfo;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Proteomics::TableInfo;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsPROT = new SBEAMS::Proteomics;
$sbeamsPROT->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Global Variables
###############################################################################
main();

# Set maximum post (file upload) to 10 MB
$CGI::POST_MAX = 1024 * 10000; 


###############################################################################
# Main Program:
#
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main { 
    $TABLE_NAME = $q->param('TABLE_NAME') || croak "TABLE_NAME not specified."; 

    croak "This TABLE_NAME=$TABLE_NAME cannot be managed by this program."
      unless ($sbeamsPROT->returnTableInfo($TABLE_NAME,"ManageTableAllowed"))[0] eq "YES";

    ($CATEGORY) = $sbeamsPROT->returnTableInfo($TABLE_NAME,"CATEGORY");
    ($PROGRAM_FILE_NAME) = $sbeamsPROT->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");
    ($DB_TABLE_NAME) = $sbeamsPROT->returnTableInfo($TABLE_NAME,"DB_TABLE_NAME");
    ($PK_COLUMN_NAME) = $sbeamsPROT->returnTableInfo($TABLE_NAME,"PK_COLUMN_NAME");
    @MENU_OPTIONS = $sbeamsPROT->returnTableInfo($TABLE_NAME,"MENU_OPTIONS");

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


    # Decide where to go based on form values
    if      ($q->param('apply_action')) { processEntryForm();
    } elsif ($q->param('apply_action_hidden')) { printEntryForm();
    } elsif ($q->param('ShowEntryForm')) { printEntryForm();
    } elsif ($q->param("$PK_COLUMN_NAME")) { printEntryForm();
    } else { printOptions();
    } # end if

} # end processRequests


###############################################################################
# Print Options Page
###############################################################################
sub printOptions {

    $sbeams->printUserContext();

    print qq!
	<BR>
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
    $sbeamsPROT->printPageFooter(close_table=>"YES",display_footer=>"NO");
    showTable("WithOptions");

} # end printOptions




###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

    my %parameters;
    my $element;
    my $sql_query;
    my $username;

    # Get the columns for this table
    my @columns = $sbeamsPROT->returnTableInfo($TABLE_NAME,"ordered_columns");
    my %input_types = 
      $sbeamsPROT->returnTableInfo($TABLE_NAME,"input_types");

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


    my $apply_action = $q->param('apply_action');
    my $apply_action_hidden  = $q->param('apply_action_hidden');
    if ($apply_action_hidden gt "") { $apply_action = $apply_action_hidden; }


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
          $parameters{@columns[$element]}=@row[$element];
      }

      $sth->finish;
    }


    my $record_status_options =
      $sbeams->getRecordStatusOptions($parameters{"record_status"});


    #### FIX ME: table specific hacks
    if ($TABLE_NAME eq "search_hit_annotation") {
      $parameters{annotation_source_id} = 1
        unless ($parameters{annotation_source_id});
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
      }
      if ($input_type eq "file") {
        $file_upload_flag = "ENCTYPE=\"multipart/form-data\"";
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
        if ($input_types{$element} eq "fixedfromlist") {
          my %templist =
            $sbeams->selectTwoColumnHash($optionlist_queries{$element});
          $optionlists{$element} = $templist{$parameters{$element}};
        } else {
          $optionlists{$element}=$sbeams->buildOptionList(
             $optionlist_queries{$element},$parameters{$element},
             $method_options);
        }

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
        print qq!
          <TD><SELECT NAME="$column_name" $onChange>
          <OPTION VALUE=""></OPTION>
          $optionlists{$column_name}</SELECT></TD>
        !;
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

      if ($input_type eq "fixedfromlist") {
        print qq!
          <TD><INPUT TYPE="hidden" NAME="$column_name"
           VALUE="$parameters{$column_name}">
           $optionlists{$column_name}</TD></TD>
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


    # Ad-hoc hack to allow some additional logic here
    postFormHook(%parameters);



    print qq!
        <TR><TD><B>record_status:</B></TD>
        <TD><SELECT NAME="record_status">
            $record_status_options
            </SELECT></TD>
        </TR><TR>
        <TD COLSPAN=3 BGCOLOR="#EEEEFF">
        <INPUT TYPE="hidden" NAME="TABLE_NAME" VALUE="$TABLE_NAME"></TD></TR>
        !;


       # If a specific record was passed, display UPDATE options
       if ($parameters{$PK_COLUMN_NAME} gt "") {

         if ($parameters{date_created}) {
           my $created_by_username = $sbeams->getUsername($parameters{created_by_id});
           my $modified_by_username = $sbeams->getUsername($parameters{modified_by_id});
           my $date_created = $parameters{date_created}; chop($date_created);
           my $date_modified = $parameters{date_modified}; chop($date_modified);
           print qq~
             <TR><TD><B>Record Created:</B></TD>
             <TD COLSPAN=2>${date_created} by ${created_by_username}</TD></TR>
           ~;
           unless ($date_created eq $date_modified) {
             print qq~
               <TR><TD><B>Record Modified:</B></TD>
               <TD COLSPAN=2>${date_modified} by ${modified_by_username}</TD></TR>
             ~;
           }
         }

         print qq!
            <TR><TD COLSPAN=3 BGCOLOR="#EEEEFF">
            <INPUT TYPE="hidden" NAME="TABLE_NAME" VALUE="$TABLE_NAME">
            <INPUT TYPE="hidden" NAME="$PK_COLUMN_NAME"
              VALUE="$parameters{$PK_COLUMN_NAME}">
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH"> this form<BR>
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="submit" NAME="apply_action" VALUE="UPDATE"> this record with this new data<BR>
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="submit" NAME="apply_action" VALUE="INSERT"> new record(s) with this information (uniqueness will be checked)<BR>
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="submit" NAME="apply_action" VALUE="DELETE"> this record<BR>
         !;

       # Otherwise, just allow INSERT or REFRESH
       } else {
         print qq!
            <TR><TD COLSPAN=3 BGCOLOR="#EEEEFF">
            <INPUT TYPE="hidden" NAME="TABLE_NAME" VALUE="$TABLE_NAME">
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH"> this form<BR>
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="submit" NAME="apply_action" VALUE="INSERT"> new record(s) with this information<BR>
         !;
       }


       print qq!
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
            <INPUT TYPE="reset" VALUE="CLEAR"> fields
            <INPUT TYPE="hidden" NAME="apply_action_hidden" VALUE="">
         </TR></TABLE>
         </FORM>
       !;


    $sbeamsPROT->printPageFooter("CloseTables");
    showTable('',\%parameters);

} # end printEntryForm


###############################################################################
# show Table
#
# Displays the Table
###############################################################################
sub showTable {
    my $with_options = shift;
    my $parameters_ref = shift;

    my $detail_level = $q->param('detail_level') || "BASIC";

    my ($main_query_part) =
      $sbeamsPROT->returnTableInfo($TABLE_NAME,$detail_level."Query",
      $parameters_ref);

    my ($full_where_clause,$full_orderby_clause) = 
      $sbeams->processTableDisplayControls($TABLE_NAME);

    #### If a new ORDER BY clause is specified, remove the default one
    if ($full_orderby_clause) {
      $main_query_part =~ s/\s*ORDER BY.*//i;
    }


    my $sql_query = qq~
        $main_query_part
        $full_where_clause
        $full_orderby_clause
    ~;

    #print "<PRE>$sql_query\n\n</PRE>";

    my ($element,$value);
    my %url_cols = $sbeamsPROT->returnTableInfo($TABLE_NAME,"url_cols");

    return $sbeams->displayQueryResult(sql_query=>$sql_query,
        url_cols_ref=>\%url_cols);

} # end showTable



###############################################################################
# Process Entry Form
#
###############################################################################
sub processEntryForm {
    my %parameters;
    my $element;
    my $sql_query;
    my @returned_information;
    my $tmp;

    # Get the columns for this table
    my @columns = $sbeamsPROT->returnTableInfo($TABLE_NAME,"ordered_columns");


    # Check to see if there is a column which will allow a range of numbers
    # over which a multi-insert could be performed
    my ($multi_insert_column) = 
      $sbeamsPROT->returnTableInfo($TABLE_NAME,"MULTI_INSERT_COLUMN");


    # Read the form values for each column
    foreach $element (@columns) {
        if ($element eq $multi_insert_column) {
          $parameters{$element}=join(",",$q->param($element));
        } else {
          $parameters{$element}=$q->param($element);
        }
        #print "$element=$parameters{$element}=<BR>\n";
    }


    my $apply_action  = $q->param('apply_action');


    if ($apply_action eq "REFRESH") {
      printEntryForm();
      exit;
    }


    # Check for missing required information
    my @required_columns = 
      $sbeamsPROT->returnTableInfo($TABLE_NAME,"required_columns");
    if (@required_columns) {
      my $error_message;
      foreach $element (@required_columns) {
        $error_message .= "<LI> You must provide a <B>$element</B>."
          unless $parameters{$element};
      }

      $error_message .= preUpdateDataCheck(%parameters);

      if ($error_message) {
          $sbeams->printIncompleteForm($error_message);
          return 0;
      }
    }


    my @data_columns = 
      $sbeamsPROT->returnTableInfo($TABLE_NAME,"data_columns");
    my %input_types = 
      $sbeamsPROT->returnTableInfo($TABLE_NAME,"input_types");


    # Multi-Insert logic.  In certain cases, we'll allow the user to specify
    # a range like "15-20,22-23" for exactly one field, and this triggers
    # INSERTion of multiple rows.
    my @series;
    if ($multi_insert_column) {
      my $input = $parameters{$multi_insert_column};
      $input =~ s/\-/\.\./g;

      # Replace any characters which are NOT 0-9 or , or . which a space
      # before we let it go into eval!!
      $input =~ tr/0-9\,\./ /cs;

      @series = eval $input;

      if (@series) { }
      else {
        $input =~ /(\d*)/;
        @series = ($1);
      }

      if (@series) { }
      else {
        push (@returned_information,"NOT ACCEPTED");
        push (@returned_information,
          "Unable to parse your input '$parameters{$multi_insert_column}'
           into a series of numbers.");
        printAttemptedChangeResult($apply_action,@returned_information);
        return;
      }

      if ( ($#series > 0) && $parameters{$PK_COLUMN_NAME} && 
           ($apply_action ne "INSERT") ) {
        push (@returned_information,"NOT ACCEPTED");
        push (@returned_information,
          "Sorry, cannot UPDATE or DELETE multiple records.
           Only INSERT of multiple records permitted.");
        printAttemptedChangeResult($apply_action,@returned_information);
        return;
      }
    } else {
      @series = ( "dummy" );
    }


    my $multi_insert;
    foreach $multi_insert (@series) {
      if ($multi_insert_column) {
        $parameters{$multi_insert_column}=$multi_insert;
        print "Processing record for $multi_insert...<BR>\n";
      }


    # Note the following block has NOT been indented properly for historical
    # reasons of insertion into above foreach statement

    # If a PK has already been provided and action is not INSERT, build
    # SQL statements for DELETE and UPDATE
    if ($parameters{$PK_COLUMN_NAME} && ($apply_action ne "INSERT")) {
        $sql_query = "";
        if ($apply_action eq "DELETE") {

            $sql_query = qq!
                UPDATE $DB_TABLE_NAME SET
                  date_modified=CURRENT_TIMESTAMP,
                  modified_by_id=$current_contact_id,
                  record_status='D'
                WHERE $PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}
            !;

        } else {
            $sql_query = "UPDATE $DB_TABLE_NAME SET ";

            foreach $element (@data_columns) {
              $tmp = $parameters{$element};

              # If datatype is password, then decode the ********** to
              # revert back to the original password, or just keep as is if
              # blank, or encrypt it if it's something else
              if ($input_types{$element} eq "password") {
                if ( substr($tmp,0,10) eq "**********" ) {
                  $tmp = substr($tmp,10,50);
                } elsif ( $tmp gt "" ) {
                  my $salt  = (rand() * 220);
                  $tmp = crypt($tmp, $salt);
                }
              }

              # Change all ' to '' so that it can go in the INSERT statement
              $tmp =~ s/'/''/g;
              $sql_query .= "$element='$tmp',\n"
            }

            $sql_query .= qq!
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

    # Otherwise, the action is INSERT, so build a SQL statement for that
    } else {

        # Since this is a new INSERT, zero out any previous PK
        $parameters{$PK_COLUMN_NAME}=0;

        # Check for an existing record that this would duplicate
        my @key_columns = 
          $sbeamsPROT->returnTableInfo($TABLE_NAME,"key_columns");
        my %unique_values;
        if (@key_columns) {
          foreach $element (@key_columns) {
            $unique_values{$element} = $parameters{$element};
          }
        }
        my $existing_record = checkForPreexistingRecord(%unique_values);
        if ($existing_record) {
            printPreexistingRecord($existing_record);
            return;
        }


        # Build the column names and VALUES for each data column
        my ($query_part1,$query_part2,$tmp);
        foreach $element (@data_columns) {
          $query_part1 .= "$element,";
          $tmp = $parameters{$element};

          # If datatype is password, then decode the ********** to
          # revert back to the original password, or just keep as is if
          # blank, or encrypt it if it's something else
          if ($input_types{$element} eq "password") {
             if ( substr($tmp,0,10) eq "**********" ) {
               $tmp = substr($tmp,10,50);
             } elsif ( $tmp gt "" ) {
               my $salt  = (rand() * 220);
               $tmp = crypt($tmp, $salt);
             }
          }

          $tmp =~ s/'/''/g;
          $query_part2 .= "'$tmp',";
        }

        # Build the SQL statement
        $sql_query = qq!
 		INSERT INTO $DB_TABLE_NAME
		  ($query_part1 created_by_id,modified_by_id,
		   owner_group_id,record_status)
		VALUES
		  ($query_part2 $current_contact_id, $current_contact_id,
 		  $current_work_group_id, '$parameters{record_status}')
        !;

    }


    # Execute the SQL statement extract status and PK from result
    @returned_information = $sbeams->applySqlChange("$sql_query",
      $current_contact_id,
      $TABLE_NAME,"$PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}");
    my $returned_request_status = shift @returned_information;
    my $returned_request_PK = shift @returned_information;

    if ($apply_action eq "INSERT") {
      $parameters{$PK_COLUMN_NAME}=$returned_request_PK;
    }

    printAttemptedChangeResult($apply_action,$returned_request_status,
      @returned_information);


    # If change was successful, then check to see if there are any data
    # files to be uploaded, and if so, do so.
    if ($returned_request_status eq "SUCCESSFUL") {
      # Check for any file uploads
      my $filename;
      foreach $element (keys %input_types) {
        if ($input_types{$element} eq "file") {
          $filename = "$parameters{$PK_COLUMN_NAME}_$element.dat";
          print "Uploading data for $element from $parameters{$element}<BR>\n";
          writeDataFile($parameters{$element}, $TABLE_NAME, $filename);

          # Update the table for the file that was actually uploaded
          $sql_query = qq~
                UPDATE $DB_TABLE_NAME SET
                  $element='$TABLE_NAME/$filename'
                WHERE $PK_COLUMN_NAME=$parameters{$PK_COLUMN_NAME}
          ~;

          my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
          my $rv  = $sth->execute or croak $dbh->errstr;

        }
      }
    }



    } # End multi-insert

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
      my $value = $unique_values{$element};
      $value =~ s/'/''/g;
      $sql_query .= "
	   AND $element='$value'";
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
        <A HREF="$PROGRAM_FILE_NAME&$PK_COLUMN_NAME=$record_id">Click
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

    my $subdir = $sbeams->getSBEAMS_SUBDIR();
    $subdir .= "/" if ($subdir);

    # First element is SUCCESSFUL or DENIED.  Rest is additional messages.
    my $result = shift @returned_result;
    my $back_button = $sbeams->getGoBackButton();

    $sbeams->printUserContext();

    print qq!
        <P>
        <H2>Return Status</H2>
        $LINESEPARATOR
        <P>
        <TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
        $apply_action of your record was <B>$result</B>.
        <P>
        <BLOCKQUOTE>
    !;

    foreach $error (@returned_result) { print "<LI>$error<P>\n"; }

    print qq!
        </BLOCKQUOTE>
        </TD></TR></TABLE>
        $LINESEPARATOR
        <P>
        <CENTER><B>
        You can click on BACK to INSERT/UPDATE another record with similar
        values $back_button
        <BR><BR><BR>
        [ <A HREF="$CGI_BASE_DIR/${subdir}$PROGRAM_FILE_NAME">View $CATEGORY Table</A>]
        </B></CENTER><BR><BR><BR><BR>
    !;

    # See if this table has a next_step property, i.e. a likely next "Add"
    # function.  If so, then print out the link(s) to take the user there.
    my $sql_query = qq~
	SELECT next_step
	  FROM $TB_TABLE_PROPERTY
	 WHERE table_name = '$TABLE_NAME'
    ~;
    my ($next_step) = $sbeams->selectOneColumn($sql_query);
    if ($next_step) {
      my @next_steps = split(",",$next_step);
      foreach $next_step (@next_steps) {
        print qq~
	  <B>Next Step? [ <A HREF="$CGI_BASE_DIR/${subdir}ManageTable.cgi?TABLE_NAME=$next_step&ShowEntryForm=1">Add $next_step</A>
	  ]</B>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
        ~;
      }
    }


} # end printAttemptedChangeResult


###############################################################################
# WriteData File
###############################################################################
sub writeDataFile {
    my $data = shift;
    my $subdir  = shift;
    my $filename  = shift;
    my $buffer;

    open(DATA, ">$UPLOAD_DIR/$subdir/$filename") || croak "Couldn't open $filename: $!";

#    while (<$data>) {
#       $_ =~ s/\cM/\n/g;
#       print DATA $_;
#    }

    while (read($data, $buffer, 1024)) {
        print DATA $buffer;
    }


    close(DATA);

} # end writeDataFile


###############################################################################
# Post-form Hook
#
# This is just a hacked hook to possibly do something interesting after all
# the entry data has been displayed (possibly REFRESHED) on certain tables
###############################################################################
sub postFormHook {
  my %parameters = @_;

  if ($TABLE_NAME eq "array_scan") {
  
    if ($parameters{stage_location} gt "") {
      if ( -d "$parameters{stage_location}/Images" ) {
        print "<TR><TD><B><font color=green>Status:</font></B></TD>";
        print "    <TD>Images/ subdirectory verified</TD></TR>\n";
      } else {
        print "<TR><TD><B><font color=red>WARNING:</font></B></TD>";
        print "    <TD><B><font color=red>Images/ subdirectory not found</font></B></TD></TR>\n";
      }
    }
  }


  if ($TABLE_NAME eq "array_quantitation") {
  
    if ($parameters{stage_location} gt "") {
      if ( -e "$parameters{stage_location}" ) {
        print "<TR><TD><B><font color=green>Status:</font></B></TD>";
        print "    <TD>Existence of data file verified</TD></TR>\n";
      } else {
        print "<TR><TD><B><font color=red>WARNING:</font></B></TD>";
        print "    <TD><B><font color=red>Data file does not exist at STAGE location</font></B></TD></TR>\n";
      }
    }
  }


  if ($TABLE_NAME eq "array_layout") {
  
    if ($parameters{source_filename} gt "") {
      if ( -e "$parameters{source_filename}" ) {
        print "<TR><TD><B><font color=green>Status:</font></B></TD>";
        print "    <TD>Existence of data file verified</TD></TR>\n";
      } else {
        print "<TR><TD><B><font color=red>WARNING:</font></B></TD>";
        print "    <TD><B><font color=red>Data file does not exist at specified location</font></B></TD></TR>\n";
      }
    }
  }



  return;

} # end postFormHook



###############################################################################
# preUpdateDataCheck
#
# For certain tables, there are additional checks that should be made before
# an INSERT or UPDATE is performed.
###############################################################################
sub preUpdateDataCheck {
  my %parameters = @_;

  if ($TABLE_NAME eq "array_scan") {
      unless ( ($parameters{stage_location} gt "") &&
             ( -d "$parameters{stage_location}/Images" ) ) {
      return "The specified scanned data location does not exist (looking for an 'Images/' subdirectory in '$parameters{stage_location}')";
    }
  }


  if ($TABLE_NAME eq "array_quantitation") {
      unless ( ($parameters{stage_location} gt "") &&
             ( -e "$parameters{stage_location}" ) ) {
      return "The specified quantitation data file does not exist (looking for file '$parameters{stage_location}')";
    }
  }


  if ($TABLE_NAME eq "array_layout") {
      unless ( ($parameters{source_filename} gt "") &&
             ( -e "$parameters{source_filename}" ) ) {
      return "The specified layout key file does not exist (looking for file '$parameters{source_filename}')";
    }
  }



  return "";

} # end preUpdateDataCheck






