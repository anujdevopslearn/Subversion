package SBEAMS::Microarray::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::Microarray::HTMLPrinter
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Microarray module which handles
#               standardized parts of generating HTML.
#
#		This really begs to get a lot more object oriented such that
#		there are several different contexts under which the a user
#		can be in, and the header, button bar, etc. vary by context
###############################################################################


use strict;
use vars qw($sbeams $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name $current_user_context_id);
use CGI::Carp qw(fatalsToBrowser croak);
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TableInfo;

use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::TableInfo;


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


###############################################################################
# printPageHeader
###############################################################################
sub printPageHeader {
    my $self = shift;
    my %args = @_;

    my $navigation_bar = $args{'navigation_bar'} || "YES";

    #### Obtain main SBEAMS object and use its http_header
    $sbeams = $self->getSBEAMS();
    my $http_header = $sbeams->get_http_header();

    print qq~$http_header
	<HTML><HEAD>
	<TITLE>$DBTITLE - MicroArray</TITLE>
    ~;


    $self->printJavascriptFunctions();
    $self->printStyleSheet();


    #### Determine the Title bar background decoration
    my $header_bkg = "bgcolor=\"$BGCOLOR\"";
    $header_bkg = "background=\"/images/plaintop.jpg\"" if ($DBVERSION =~ /Primary/);

    print qq~
	<!--META HTTP-EQUIV="Expires" CONTENT="Fri, Jun 12 1981 08:20:00 GMT"-->
	<!--META HTTP-EQUIV="Pragma" CONTENT="no-cache"-->
	<!--META HTTP-EQUIV="Cache-Control" CONTENT="no-cache"-->
	</HEAD>

	<!-- Background white, links blue (unvisited), navy (visited), red (active) -->
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" >
	<table border=0 width="100%" cellspacing=0 cellpadding=1>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td bgcolor="$BARCOLOR"><a href="http://www.systemsbiology.org/"><img height=60 width=60 border=0 alt="ISB Main" src="/images/ISBlogo60t.gif"></a><a href="http://db.systemsbiology.net/"><img height=60 width=60 border=0 alt="ISB DB" src="/images/ISBDBt.gif"></a></td>
	  <td align="left" $header_bkg><H1>$DBTITLE - $SBEAMS_PART<BR>$DBVERSION</H1></td>
	</tr>

    ~;

    #print ">>>http_header=$http_header<BR>\n";

    if ($navigation_bar eq "YES") {
      print qq~
	<!------- Button Bar -------------------------------------------->
	<tr><td bgcolor="$BARCOLOR" align="left" valign="top">
	<table border=0 width="120" cellpadding=2 cellspacing=0>

	<tr><td><a href="$CGI_BASE_DIR/main.cgi">$DBTITLE Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi">$SBEAMS_PART Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
	<tr><td>&nbsp;</td></tr>

	<tr><td>Array Requests:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project"><nobr>&nbsp;&nbsp;&nbsp;Manage Projects</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SubmitArrayRequest.cgi?TABLE_NAME=array_request"><nobr>&nbsp;&nbsp;&nbsp;Array Requests</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>

	<tr><td>Status/Processing:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ShowProjectStatus.cgi"><nobr>&nbsp;&nbsp;&nbsp;Project Status</a></nobr></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GridAlignCheck.cgi"><nobr>&nbsp;&nbsp;&nbsp;Alignment Check</a></nobr></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ProcessProject.cgi"><nobr>&nbsp;&nbsp;&nbsp;Data Processing</a></nobr></td></tr>
	<tr><td>&nbsp;</td></tr>

	<tr><td>Array Information:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=protocol"><nobr>&nbsp;&nbsp;&nbsp;Protocols</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=labeling"><nobr>&nbsp;&nbsp;&nbsp;Labeling</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=hybridization"><nobr>&nbsp;&nbsp;&nbsp;Hybridization</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=array_quantitation"><nobr>&nbsp;&nbsp;&nbsp;Quantitation</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
    ~;

      $current_work_group_name = $sbeams->getCurrent_work_group_name();
      if ($current_work_group_name eq "Arrays" || $current_work_group_name eq "Admin" || 1) {
       print qq~
	<tr><td>Arrays Core:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=contact"><nobr>&nbsp;&nbsp;&nbsp;Contacts</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=array"><nobr>&nbsp;&nbsp;&nbsp;Arrays</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=array_scan"><nobr>&nbsp;&nbsp;&nbsp;Scanning</nobr></a></td></tr>
       ~;
      }

      $current_work_group_name = $sbeams->getCurrent_work_group_name();
      if ($current_work_group_name eq "Arrays" || $current_work_group_name eq "Admin") {
       print qq~
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=slide_lot"><nobr>&nbsp;&nbsp;&nbsp;Physical Slides</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=array_layout"><nobr>&nbsp;&nbsp;&nbsp;Array Layouts</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=printing_batch"><nobr>&nbsp;&nbsp;&nbsp;Printing Batches</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=slide_type"><nobr>&nbsp;&nbsp;&nbsp;Slide Type/Costs</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/ManageTable.cgi?TABLE_NAME=user_login"><nobr>Admin</nobr></a></td></tr>
       ~;
      }

      print qq~
	</table>
	</td>

	<!-------- Main Page ------------------------------------------->
	<td valign=top>
	<table border=0 bgcolor="#ffffff" cellpadding=4>
	<tr><td>

    ~;
    } else {
      print qq~
	</TABLE>
      ~;
    }

}

# 	<table border=0 width="680" bgcolor="#ffffff" cellpadding=4>


###############################################################################
# printStyleSheet
#
# Print the standard style sheet for pages.  Use a font size of 10pt if
# remote client is on Windows, else use 12pt.  This ends up making fonts
# appear the same size on Windows+IE and Linux+Netscape.  Other tweaks for
# different browsers might be appropriate.
###############################################################################
sub printStyleSheet {
    my $self = shift;

    #### Obtain main SBEAMS object and use its style sheet
    $sbeams = $self->getSBEAMS();
    $sbeams->printStyleSheet();

}


###############################################################################
# printJavascriptFunctions
#
# Print the standard Javascript functions that should appear at the top of
# most pages.  There probably should be some customization allowance here.
# Not sure how to design that yet.
###############################################################################
sub printJavascriptFunctions {
    my $self = shift;
    my $javascript_includes = shift;


    print qq~
	<SCRIPT LANGUAGE="JavaScript">
	<!--

	function refreshDocument() {
            //confirm( "apply_action ="+document.forms[0].apply_action.options[0].selected+"=");
            document.forms[0].apply_action_hidden.value = "REFRESH";
	    document.forms[0].submit();
	} // end refresh


	function showPassed(input_field) {
            //confirm( "input_field ="+input_field+"=");
            confirm( "selected option ="+document.forms[0].slide_id.options[document.forms[0].slide_id.selectedIndex].text+"=");
	    return;
	} // end showPassed


	function confirmPasswdChange() {
	    if (confirm( "The old password for this user will no longer be "
	               + "valid.")) {
	        return true;
	    } else {
	        return false;
	    } // end if
	} // end confirmPasswdChange


	function ClickedNowButton(input_field) {
	    //confirm( "input_field ="+input_field+"=");
	    field_name = input_field.name
	    today = new Date();
	    date_value =
	      today.getFullYear() + "-" + (today.getMonth()+1) + "-" +
	      today.getDate() + " " +
	      today.getHours() + ":" +today.getMinutes();

	    if (field_name == "date_labeled") {
	      document.forms[0].date_labeled.value = date_value;
	    } else if (field_name == "date_hybridized") {
	      document.forms[0].date_hybridized.value = date_value;
	    } else if (field_name == "date_received") {
	      document.forms[0].date_received.value = date_value;
	    } else if (field_name == "date_scanned") {
	      document.forms[0].date_scanned.value = date_value;
	    } else if (field_name == "date_quantitated") {
	      document.forms[0].date_quantitated.value = date_value;
	    }

	    return;
	} // end ClickedNowButton


	function setDefaultImagesLocation() {
	    // /net/arrays/ScanArray_Images/00001-00100/00012_A1_MMDDYY/Images/
	    array_name = document.forms[0].array_id.options[document.forms[0].array_id.selectedIndex].text
	    if (array_name.substr(array_name.length-9,99) == " - *DONE*") {
	      array_name = array_name.substr(0,array_name.length-9);
	    }

	    today = new Date();
	    date_value =
	      "" + today.getFullYear() +
	      addLeadingZeros((today.getMonth()+1),2) +
	      addLeadingZeros(today.getDate(),2)
	    date_value = date_value.substr(2,6);

            start_group = Math.round(array_name/100-0.5)*100+1;
            start_group = addLeadingZeros(start_group.toString(),5);

            end_group = Math.round(array_name/100+0.5)*100;
            end_group = addLeadingZeros(end_group.toString(),5);

            array_name = addLeadingZeros(array_name.toString(),5);

	    document.forms[0].stage_location.value =
	      "/net/arrays/ScanArray_Images/" +
	      start_group + "-"+ end_group + "/" +
	      array_name + "_A1_" + date_value;

	    return;
	} // end setDefaultImagesLocation


	function addLeadingZeros(instring,ndigits) {
	    instring = instring.toString();
	    while (instring.length < ndigits) { instring = "0" + instring; }
	    return instring;
	}


	function setDefaultQALocation() {

	    array_name = document.forms[0].array_scan_id.options[document.forms[0].array_scan_id.selectedIndex].text;
            array_name = array_name.toString();
	    if (array_name.substr(array_name.length-9,99) == " - *DONE*") {
	      array_name = array_name.substr(0,array_name.length-9);
	    }

            start_group = Math.round(array_name/100-0.5)*100+1;
            start_group = addLeadingZeros(start_group.toString(),5);

            end_group = Math.round(array_name/100+0.5)*100;
            end_group = addLeadingZeros(end_group.toString(),5);

	    protocol_name = document.forms[0].protocol_id.options[document.forms[0].protocol_id.selectedIndex].text;
            protocol_name = protocol_name.toString();
	    extension = ".?";
	    //confirm( "result ="+protocol_name.search(/QuantArray/i)+"=");
	    if (protocol_name.search(/QuantArray/i)>-1) { extension = ".qa"; }
	    //confirm( "result ="+protocol_name.search(/Dapple/i)+"=");
	    if (protocol_name.search(/Dapple/i)>-1) { extension = ".dapple"; }

	    document.forms[0].stage_location.value =
	      "/net/arrays/Quantitation/" +
	      start_group + "-"+ end_group + "/" +
	      array_name + extension;

	    return;
	} // end setDefaultQALocation


        function setArrayName() {

	    array_name = document.forms[0].array_name.value=document.forms[0].slide_id.options[document.forms[0].slide_id.selectedIndex].text;
            array_name = array_name.toString();
	    if (array_name.substr(array_name.length-9,99) == " - *DONE*") {
	      array_name = array_name.substr(0,array_name.length-9);
	    }
            while (array_name.length < 5) { array_name = "0" + array_name; }

	    document.forms[0].array_name.value = array_name;

	    return;
	} // end setArrayName


	function setLayoutFileName() {
            document.forms[0].source_filename.value =
              "/net/arrays/Slide_Templates/" +
              document.forms[0].name.value + ".key"
	    return;
	} // end setLayoutFileName

        // -->
        </SCRIPT>
    ~;

}





###############################################################################
# printPageFooter
###############################################################################
sub printPageFooter {
  my $self = shift;
  my $flag = shift || "CloseTablesAndPrintFooter";

  if ($flag =~ /CloseTables/) {
    print qq~
	</TD></TR></TABLE>
	</TD></TR></TABLE>
    ~;
  }

  if ($flag =~ /Footer/) {
    print qq~
	<BR><HR SIZE="2" NOSHADE WIDTH="30%" ALIGN="LEFT">
	SBEAMS - Microarray [Under Development]<BR><BR><BR>
	</BODY></HTML>\n\n
    ~;
  }

}


###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::WebInterface::HTMLPrinter - Perl extension for common HTML printing methods

=head1 SYNOPSIS

  Used as part of this system

    use SBEAMS::WebInterface;
    $adb = new SBEAMS::WebInterface;

    $adb->printPageHeader();

    $adb->printPageFooter();

    $adb->getGoBackButton();

=head1 DESCRIPTION

    This module is inherited by the SBEAMS::WebInterface module,
    although it can be used on its own.  Its main function 
    is to encapsulate common HTML printing routines used by
    this application.

=head1 METHODS

=item B<printPageHeader()>

    Prints the common HTML header used by all HTML pages generated 
    by theis application

=item B<printPageFooter()>

    Prints the common HTML footer used by all HTML pages generated 
    by this application

=item B<getGoBackButton()>

    Returns a form button, coded with javascript, so that when it 
    is clicked the user is returned to the previous page in the 
    browser history.

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cut
