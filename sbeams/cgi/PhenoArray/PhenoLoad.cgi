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
use lib qw (/local/www/html/sbeams/lib/perl);
use vars qw ($q $sbeams $sbeamsPH $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS $DATABASE);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

###########################################
# File Upload Stuff
###########################################

use POSIX;
#use constant BUFFER_SIZE => 16_384;
use constant MAX_FILE_SIZE => 1_048_576_000_000; 

$CGI::DISABLE_UPLOADS = 0;
$CGI::POST_MAX = MAX_FILE_SIZE;


use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

use SBEAMS::PhenoArray;
use SBEAMS::PhenoArray::Settings;
use SBEAMS::PhenoArray::Tables;
use SBEAMS::PhenoArray::TableInfo;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsPH = new SBEAMS::PhenoArray;
$sbeamsPH->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
$DATABASE = $sbeams->getPHENOARRAY_DB();
###############################################################################
# Global Variables
###############################################################################
main();

#macro();


# Set maximum post (file upload) to 10 MB
$CGI::POST_MAX = 1024 * 10000; 


###############################################################################
# Main Program:
#
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main { 

 
    $TABLE_NAME = "PH_array_quantitation";  #NASTY HACK!!!!   

    ($CATEGORY) = $sbeamsPH->returnTableInfo($TABLE_NAME,"CATEGORY");
    ($PROGRAM_FILE_NAME) = $sbeamsPH->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");
    ($DB_TABLE_NAME) = $sbeamsPH->returnTableInfo($TABLE_NAME,"DB_TABLE_NAME");
    ($PK_COLUMN_NAME) = $sbeamsPH->returnTableInfo($TABLE_NAME,"PK_COLUMN_NAME");
    @MENU_OPTIONS = $sbeamsPH->returnTableInfo($TABLE_NAME,"MENU_OPTIONS");

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Print the header, do what the program does, and print footer

    $sbeamsPH->printPageHeader();
    processRequests();
    $sbeamsPH->printPageFooter();

} # end main

###################################################
#
# The Following is code for loading data into the PhenoDB
#
# Rowan Christmas 11/29/01
#
###################################################

my %plate_list;
my @sorted_plate_list;
my %plate;
my %cond_list;
my @sorted_cond_list;


####################
# Perform SQL queries to make dropdown boxes out of the conds and plates
sub pheno_list_make {
    
    #######
    # Select all the conditions
    my $sth = $dbh->prepare("SELECT condition_id, condition_name FROM $TBPH_CONDITION ORDER BY  condition_name") or croak $dbh->errstr;
    my $rv  = $sth->execute or croak $dbh->errstr;
 
    while ( my ($condition_id, $condition_name) = $sth->fetchrow_array() ) {
	$cond_list{$condition_name} = $condition_id;
    }
    @sorted_cond_list = sort( keys %cond_list);
    unshift (@sorted_cond_list, "");

    ######
    # Selcet all the Plates
    my $sth_plate = $dbh->prepare("SELECT plate_id, plate_name FROM $TBPH_PLATE ORDER BY plate_name") or croak $dbh->errstr;
    my $rv = $sth_plate->execute or croak $dbh->errstr;

    while ( my ($plate_id, $plate_name) = $sth_plate->fetchrow_array() ) {
	$plate_list{$plate_name} = $plate_id;
    }
    @sorted_plate_list = sort( keys %plate_list );
    unshift (@sorted_plate_list, "");

  
}

################
# Outpuit a condition list
sub pheno_cond_list {
    my $plateCond = shift;
    print qq~
	<select name=$plateCond>
	    ~;
    foreach my $cond (@sorted_cond_list) {
	print "<option value=$cond_list{$cond}>$cond</option>";
    }
    print qq~
	</select>
	    ~;
}
####################
# Output a plate list
sub pheno_plate_list {
    my $plate = shift;
    print qq~
	<select name=$plate>
	    ~;
    foreach my $cond (@sorted_plate_list) {
	print "<option value=$plate_list{$cond}>$cond</option>";
    }
    print qq~
	</select>
	    ~;
}

##########
# This subroutine displays the loader information
sub loader {
  
    pheno_list_make();   ## Make the lists 
    print <<ENDOFPIC; 
    <img SRC="/~xmas/images/macroarray.jpg">
ENDOFPIC
 
    #############
    # Display the A->D choices, and the file loader  
    print $q->p("Choose the A plate");
    pheno_plate_list("A");
    pheno_cond_list("condA"); 
    
    print $q->p("Choose the B plate");
    pheno_plate_list("B");
    pheno_cond_list("condB");  
    
    print $q->p("Choose the C plate");
    pheno_plate_list("C");
    pheno_cond_list("condC"); 
    
    print $q->p("Choose the D plate");
    pheno_plate_list("D"); 
    pheno_cond_list("condD"); 
    
    fileUploader();
}


####################
# file upload

sub fileUploader {
    print qq!
	<P>Please Choose the Dapple File to Upload
	<INPUT TYPE="FILE" SIZE="100" NAME="dapple_file">
	    !
}

#######################
# Dapple file Writer

sub writeDappleFile {
    my $filename = shift;
    my %rowdata = (
		   quant_file_path => "/net/yeast/PhenoDB/storage/$filename",
		   quant_file_name => $filename,
		   created_by_id => $sbeams->getCurrent_contact_id(),
		   modified_by_id => $sbeams->getCurrent_contact_id(),
		   record_status => 0,
		   );
    my $result;
    my $result = $sbeams->insert_update_row(
					insert => 1,
					update => 0,
					table_name => "$TBPH_ARRAY_QUANTITATION",
					rowdata_ref => \%rowdata,
					PK => "array_quantitaion_id",
					    );
    my $file = $q->param("dapple_file");
    open(DATA, ">/net/yeast/PhenoDB/storage/$filename") || croak "Couldn't open";
    while (<$file>) {
        print DATA $_;
    }
    close(DATA);
    print $q->p("Record Succesfully Inserted $result");
}


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
   
#################################
# Either accept input, or do something with it
#################################

    if ($q->param('apply_action')) { 
	processEntryForm();
    } else { 
	printEntryForm();
    }

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
    $sbeamsPH->printPageFooter("CloseTables");
} # end printOptions




###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {
    print $q->start_multipart_form(); ## Start Form
    
    #print qq!
	#<FORM ACTION="/cgi/upload.cgi" METHOD="POST" ENCTYPE="multipart/form-data">
	   # !;
    $sbeams->printUserContext(); ##Print User info
    #Print Title
    print qq!
        <P>
        <H2>Input New Dapple File</H2>
        <TABLE>
	    !;
  
    loader();
 
    #########################
    # Print out the buttons #
    #########################
    print qq!
	<HR>
	<TD COLSPAN=3 BGCOLOR="#EEEEFF">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
        <INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH"> this form<BR>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
        <INPUT TYPE="submit" NAME="apply_action" VALUE="INSERT"> new record(s) with this information<BR>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
        <INPUT TYPE="reset" VALUE="CLEAR"> fields
        <INPUT TYPE="hidden" NAME="apply_action_hidden" VALUE="">
        </TR></TABLE>
        </FORM>
	    !;
   
    print $q->endform(); ##End Form

} # end printEntryForm



##############################
# Process Entry Form
#
##############################

sub processEntryForm {

    if ( $q->param("dapple_file") && ( $q->param("A") || $q->param("B") || $q->param("C") || $q->param("D") ) )  {
	
	my $sql_plate = "SELECT plate_id, plate_name FROM ${DATABASE}plate";
	my %plate_id = $sbeams->selectTwoColumnHash($sql_plate);

	my $sql_cond = "SELECT condition_id, condition_name FROM ${DATABASE}condition";
	my %cond_id = $sbeams->selectTwoColumnHash($sql_cond);


 
	my $file = $q->param("dapple_file");
	my $A = $q->param("A"); 
	my $a = $q->param("condA");
	my $B = $q->param("B");
	my $b = $q->param("condB");
	my $C = $q->param("C");
	my $c = $q->param("condC");
	my $D = $q->param("D");
	my $d = $q->param("condD");
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
	my $time = strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);
	print $q->h1("Dapple File Being Processed.....");
	writeDappleFile("$time\:$plate_id{$A}\:$cond_id{$a}\:$plate_id{$B}\:$cond_id{$b}\:$plate_id{$C}\:$cond_id{$c}\:$plate_id{$D}\:$cond_id{$d}\.dapple");
    
	print $q->p("Done!!");
    
 
    } else {
	 my $back_button = $sbeams->getGoBackButton();
    print qq!
	
	<H2>No Dapple File Indicated</H2>
	$LINESEPARATOR
	<P>
	<TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
	In order to actually process a file I kinda need to know which 
	one it is, eh? Or, if you told me which dapple file, I also
	gotta know what plates were used to make it.  You only have to tell
	me one.
	<CENTER>
        <BR><BR>
	$back_button
	</CENTER>
	</TD></TR></TABLE>
	$LINESEPARATOR
        <P>!;
    }
    

}

##############################################################################
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

#     while (<$data>) {
#        $_ =~ s/\cM/\n/g;
#        print DATA $_;
#     }

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

} # end  postFormHook



######## #######################################################################
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








