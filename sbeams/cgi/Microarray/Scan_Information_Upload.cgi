#!/usr/local/bin/perl -w

###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
require "/net/arrays/Pipeline/tools/lib/QuantitationFile.pl";
use vars qw ($q $sbeams $sbeamsMA $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name $current_user_context_id
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);

use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;

$q = new CGI;
$sbeamsMA = new SBEAMS::Microarray;
$sbeamsMA->setSBEAMS($sbeams);

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
    $sbeamsMA->printPageHeader();
    setup_page();
    $sbeamsMA->printPageFooter();


} # end main


###############################################################################
# setup_page
###############################################################################
sub setup_page {
    $current_username = $sbeams->getCurrent_username;
    $current_contact_id = $sbeams->getCurrent_contact_id;
    $current_work_group_id = $sbeams->getCurrent_work_group_id;
    $current_work_group_name = $sbeams->getCurrent_work_group_name;
    $current_project_id = $sbeams->getCurrent_project_id;
    $current_project_name = $sbeams->getCurrent_project_name;
    $current_user_context_id = $sbeams->getCurrent_user_context_id;

    #### For debugging
    if (0==1) {
	print "Content-type: text/html\n\n";
	my ($ee, $ff);
	foreach $ee(keys %ENV)  {
        print "$ee =$ENV{$ee}=<BR>\n";
      }
      foreach $ee ( $q->param ) {
        $ff = $q->param($ee);
        print "$ee =$ff=<BR>\n";
      }
    }

    if ($q->param('SUBMIT')) {submit_info();}
    else { print_form();}
} # end setup_page



###############################################################################
# Print Form
###############################################################################
sub print_form {
    my $SUB_NAME = "print_form";

    #### Define variables
    my (%parameters, $sql);
    my $CATEGORY = "Array Information Submission Page";
    my $REFUSAL  = "To continue, please select a project in your user profile!"; 
    my $PROFILE_LINK = "<A HREF =\"http:\/\/db.systemsbiology.net\/dev7\/sbeams\/cgi\/Microarray\/ManageTable\.cgi\?TABLE_NAME\=user_context&user_context_id\=$current_user_context_id\"</A>";

    my $apply_action = $q->param('apply_action');


    $parameters{project_id} = $q->param('project_id');

    if ( ($parameters{project_id} eq "") && (defined($current_project_id)) ) {
	$parameters{project_id} = $current_project_id;
	$apply_action = "QUERY";
    }

    $sbeams->printUserContext();
    print qq!
        <H2>$CATEGORY</H2>
        <FORM METHOD="post">
        <TABLE>
    !;


    #### Query to obtain column information about the table being managed
    $sql = qq~
	SELECT project_id,username+' - '+name
	  FROM $TB_PROJECT P
	  LEFT JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id=UL.contact_id )
	  ORDER BY username,name
    ~;
    my $optionlist = $sbeams->buildOptionList(
           $sql,$parameters{project_id});


    print qq!
          <TR><TD><B>Project:</B></TD>
          <TD><SELECT NAME="project_id">
          <OPTION VALUE=""></OPTION>
	   $optionlist</SELECT></TD>
          <TD BGCOLOR="E0E0E0">Select the Project Name</TD>
          </TD></TR>
    !;

    #### Show the QUERY, REFRESH, and Reset buttons
    print qq!
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


    #### Get information for jump_to tables
    my $subdir = $sbeams->getSBEAMS_SUBDIR();

    #### Start a new form and table
    print qq!
	<FORM METHOD="post" NAME="array_info">
	<TABLE>
	<TR>
	  <TD><FONT COLOR="red">Array</FONT>!;
    jump_to_table(table_name=>"array", subdir=>$subdir);
 
    print qq!
	  </TD>
	  <TD><FONT COLOR="red">Array Scan</FONT>!;
    jump_to_table(table_name=>"array_scan", subdir=>$subdir);
    print qq!
	  </TD>
	  <TD><FONT COLOR="red">Array Quantitation</FONT>!;
    jump_to_table(table_name=>"array_quantitation", subdir=>$subdir);
    print qq!
	  </TD>
        </TR>
	<TR>
    !;

    #### Create array list for the given project_id
    $sql = qq~
	SELECT A.array_name
	FROM $TB_ARRAY A
	WHERE A.project_id = $parameters{project_id}
	AND A.record_status != 'D'
    ~;

    print qq!<TD>!;
    create_option_list(sql=>$sql, table_name=>"array_list");
    print qq!</TD>!;

    #### Create list of array scan files
    $sql = qq~
	SELECT ACS.stage_location
	FROM $TB_ARRAY_SCAN ACS
	WHERE ACS.record_status != 'D'
    ~;

    print qq!<TD>!;
    create_option_list(sql=>$sql, table_name=>"array_scan_list");
    print qq!</TD>!;

    #### Create list of protocols
    $sql = qq~
	SELECT Q.stage_location
	FROM $TB_ARRAY_QUANTITATION Q
	WHERE Q.record_status != 'D'
    ~;

    print qq!<TD>!;
    create_option_list(sql=>$sql, table_name=>"quantitation_list");
    print qq!</TD>!;

    print qq!
	</TR>
	<TR>
	<TD>
	<INPUT TYPE="submit" NAME="SUBMIT" VALUE="Submit">
	</TD>
	</TR>
	</TABLE>
	</FORM>
    !;
    $sbeams->printPageFooter("CloseTables");
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";
}    

###############################################################################
# jump_to_table
###############################################################################
sub jump_to_table {
    my %args = @_;
    my $SUB_NAME = "jump_to_table";

    #### Define standard variables
    my ($table, $subdir);

    #### Decode argument list
    $table = $args{table_name};
    $subdir = $args{subdir};
    $subdir .= "/" if ($subdir);
    print qq!
	<A TARGET="AddToList" HREF="$CGI_BASE_DIR/${subdir}ManageTable.cgi?TABLE_NAME=$table&ShowEntryForm=1">
	<IMG SRC="$HTML_BASE_DIR/images/greyplus.gif" BORDER=0 ALT="Add to or view details about this list box"></A>
    !;
}
###############################################################################
# submit_info
###############################################################################
sub submit_info {
    my %args = @_;
    my $SUB_NAME = "submit_info";

    #### Define standard variables
    my ($sql, $array_scan, $array_quantitation);
    $array_scan = $q->param('array_scan_list');
    $array_quantitation = $q->param('quantitation_list');

    #### Fill in array_scan protocol if not already set
    $sql = qq~
	SELECT
	~;
}


###############################################################################
# create_option_list
###############################################################################
sub create_option_list {
    my %args = @_;
    my $SUB_NAME = "create_option_list";

    #### Define standard variables
    my (@names, $n_names, $file, $table_name, $sql);

    #### Decode argument list
    $sql = $args{sql}
    || die "ERROR[$SUB_NAME]: SQL query not passed!\n";
    $table_name = $args{table_name}
    || die "ERROR[$SUB_NAME]: table name not passed!\n";


    #### perform SQL query
    @names = $sbeams->selectOneColumn ($sql);
    $n_names = @names;

    #### Create option list
    print qq!<SELECT NAME="$table_name" SIZE=1>!;

    foreach $file(@names){
	$file =~ s(^.*/)();
	print qq!<OPTION VALUE="$file">$file!;
    }   

    print qq!</SELECT>!;

    return;
}
