package SBEAMS::Cytometry::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::Cytometry::HTMLPrinter
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::WebInterface module which handles
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

use SBEAMS::Cytometry::Settings;
use SBEAMS::Cytometry::TableInfo;


###############################################################################
# printPageHeader
###############################################################################
sub printPageHeader {
  my $self = shift;
  
  $self->display_page_header(@_);
}



sub display_page_header 
{ 
	my $self = shift;
	my %args = @_;
	
 #### If the output mode is interactive text, display text header
    $sbeams = $self->getSBEAMS();
    if ($sbeams->output_mode() eq 'interactive') {
    $sbeams->printTextHeader();
   return;
    }

 #### If the output mode is not html, then we don't want a header here
    if ($sbeams->output_mode() ne 'html') {
      return;
    }
	
	
	my $sbeams = $self->getSBEAMS();
	$current_contact_id = $sbeams->getCurrent_contact_id();
#print "this is $current_contact_id";
	
	
	if ($sbeams->getCurrent_contact_id() ne 107)
	{
      
      $self->displayPageHeader();

	}
	else 
	{
		$self->displayGuestPageHeader();
		
	}
}


sub displayGuestPageHeader
{ 
	my $self = shift;
  my %args = @_;

  my $navigation_bar = $args{'navigation_bar'} || "YES";

  my $LOGIN_URI = "$SERVER_BASE_DIR$ENV{REQUEST_URI}";
  if ($LOGIN_URI =~ /\?/) {
    $LOGIN_URI .= "&force_login=yes";
  } else {
    $LOGIN_URI .= "?force_login=yes";
  }

  my $pad = '&nbsp;' x 5;
  my $LOGIN_LINK = qq~$pad<A HREF="$LOGIN_URI" class="Nav_link">Login to database</A><BR>~;


  #### Obtain main SBEAMS object and use its http_header
  my $sbeams = $self->getSBEAMS();
  my $http_header = $sbeams->get_http_header();
  use LWP::UserAgent;
  use HTTP::Request;
  my $ua = LWP::UserAgent->new();
  my $scgapLink = 'http://scgap.systemsbiology.net';
  my $response = $ua->request( HTTP::Request->new( GET => "$scgapLink/skin.php" ) );
  my @page = split( "\r", $response->content() );
  my $skin = '';
  for ( @page ) {
    $_ =~ s/\<\!-- LOGIN_LINK --\>/$LOGIN_LINK/;
    last if $_ =~ / End of main content/;
    $skin .= $_;
  }
  print STDERR "SKINNNNN $skin";
  $skin =~ s/\/images\//\/sbeams\/images\//gm;
  print STDERR "SKIONNNN$skin";
 
  print "$http_header\n\n";
  print <<"  END_PAGE";
  <HTML>
    $skin
  END_PAGE

  $self->printJavascriptFunctions();
}


sub  displayGuestPageFooter
{
	
print qq~
</td></tr>
</table>
</td></tr>
</table>
<BR>
<hr size=1 width="55%" align="left" color="#FF8700">
<TABLE border="0">
<TR><TD><IMG SRC="/images/ISB_symbol_tiny.jpg"></TD>
<TD><nowrap>SCGAP UESC - ISB / UW</nowrap></A></TD></TR>
</TABLE>
<BR>
<BR>
~;
}




###############################################################################
# display_page_header
###############################################################################
sub displayPageHeader {
    my $self = shift;
    my %args = @_;

    my $navigation_bar = $args{'navigation_bar'} || "YES";

    #### If the output mode is interactive text, display text header
    my $sbeams = $self->getSBEAMS();
    if ($sbeams->output_mode() eq 'interactive') {
      $sbeams->printTextHeader();
      return;
    }


    #### If the output mode is not html, then we don't want a header here
    if ($sbeams->output_mode() ne 'html') {
      return;
    }


    #### Obtain main SBEAMS object and use its http_header
    $sbeams = $self->getSBEAMS();
    my $http_header = $sbeams->get_http_header();

    print qq~$http_header
	<HTML><HEAD>
	<TITLE>$DBTITLE - $SBEAMS_PART</TITLE>
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
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" TOPMARGIN=0 LEFTMARGIN=0 OnLoad="self.focus();">
	<table border=0 width="100%" cellspacing=0 cellpadding=1>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td bgcolor="$BARCOLOR"><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmlclear.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmlclear.gif"></a></td>
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
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_PART/main.cgi">$SBEAMS_PART Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
	<tr><td>&nbsp;</td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/projectMain.cgi?action=QUERY"><nobr>&nbsp;&nbsp;&nbsp;Project Summary</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Manage Tables:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project"><nobr>&nbsp;&nbsp;&nbsp;Projects</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_fcs_run"><nobr>&nbsp;&nbsp;&nbsp;FCS Runs</nobr></a></td></tr>
    	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_measured_parameters"><nobr>&nbsp;&nbsp;&nbsp;Measured Channels</nobr></a></td></tr>
   <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_sort_entity"><nobr>&nbsp;&nbsp;&nbsp;Sort Entity</nobr></a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_tissue_type"><nobr>&nbsp;&nbsp;&nbsp;Tissue Type</nobr></a></td></tr>
  <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_sort_type"><nobr>&nbsp;&nbsp;&nbsp;Sort Technique</nobr></a></td></tr>
  <tr></tr>
  <tr></tr>
  <tr><td>Documentation</td></tr>
 <tr><td><a href="$HTML_BASE_DIR/cgi/$SBEAMS_SUBDIR/Help?document=SampleNameConvention"><nobr>&nbsp;&nbsp;&nbsp;Sample Name Coding</nobr></a></td></tr>
  
	<tr><td>&nbsp;</td></tr>

	</table>
	</td>

	<!-------- Main Page ------------------------------------------->
	<td valign=top>
	<table border=0 bgcolor="#ffffff" cellpadding=4>
	<tr><td>

    ~;
   # <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/AddFCSRuns"><nobr>&nbsp;&nbsp;&nbsp;Add FCS Runs</nobr></a></td></tr>
   # <tr><td>&nbsp;</td></tr>
    
    
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
            //confirm( "apply_action ="+document.MainForm.apply_action.options[0].selected+"=");
            document.MainForm.apply_action_hidden.value = "REFRESH";
            document.MainForm.action.value = "REFRESH";
	    document.MainForm.submit();
	} // end refreshDocument


	function showPassed(input_field) {
            //confirm( "input_field ="+input_field+"=");
            confirm( "selected option ="+document.forms[0].slide_id.options[document.forms[0].slide_id.selectedIndex].text+"=");
	    return;
	} // end showPassed


	function ClickedNowButton(input_field) {
	  field_name = input_field.name;
	  today = new Date();
	  date_value =
	      today.getFullYear() + "-" + (today.getMonth()+1) + "-" +
	      today.getDate() + " " +
	      today.getHours() + ":" +today.getMinutes();

	  if (field_name == "preparation_date") {
	      document.MainForm.preparation_date.value = date_value;
	  }

	  return;
	} // end ClickedNowButton



        // -->
        </SCRIPT>
    ~;

}


###############################################################################
# printPageFooter
###############################################################################
sub printPageFooter {
  my $self = shift;
  $self->display_page_footer(@_);
}


###############################################################################
# display_page_footer
###############################################################################
sub display_page_footer {

my $self = shift;
  my %args = @_;


#### If the output mode is interactive text, display text header
  my $sbeams = $self->getSBEAMS();
  if ($sbeams->output_mode() eq 'interactive') {
    $sbeams->printTextHeader(%args);
    return;
  }


  #### If the output mode is not html, then we don't want a header here
  if ($sbeams->output_mode() ne 'html') {
    return;
  }

  
  $sbeams = $self->getSBEAMS();
	$current_contact_id = $sbeams->getCurrent_contact_id();
#	print "this is $current_contact_id";
	
	
	if ($sbeams->getCurrent_contact_id() ne 107)
	{
		$self->displayRegularPageFooter();
			
	}
	else 
	{
		$self->displayGuestPageFooter();
		
	}
}
  
 
  
sub displayRegularPageFooter
{
	my $self = shift; 
	my %args = @_;

  #### Process the arguments list
  my $close_tables = $args{'close_tables'} || 'YES';
  my $display_footer = $args{'display_footer'} || 'YES';
  my $separator_bar = $args{'separator_bar'} || 'NO';


  #### If closing the content tables is desired
  if ($close_tables eq 'YES') {
    print qq~
	</TD></TR></TABLE>
	</TD></TR></TABLE>
    ~;
  }


  #### If displaying a fat bar separtor is desired
  if ($separator_bar eq 'YES') {
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";
  }


  #### If finishing up the page completely is desired
  if ($display_footer eq 'YES') {
    #### Default to the Core footer
    $sbeams->display_page_footer(display_footer=>'YES');
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
