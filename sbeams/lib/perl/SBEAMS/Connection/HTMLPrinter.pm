package SBEAMS::Connection::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::Connection::HTMLPrinter
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               standardized parts of generating HTML.
#
#		This really begs to get a lot more object oriented such that
#		there are several different contexts under which the a user
#		can be in, and the header, button bar, etc. vary by context
###############################################################################


use strict;
use vars qw($current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name $current_user_context_id);
use CGI::Carp qw(fatalsToBrowser croak);
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
use Env qw (HTTP_USER_AGENT);


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
# display_page_header
###############################################################################
sub display_page_header {
  my $self = shift;
  $self->printPageHeader(@_);
}


###############################################################################
# printPageHeader
###############################################################################
sub printPageHeader {
    my $self = shift;
    my %args = @_;

    my $navigation_bar = $args{'navigation_bar'} || "YES";
    my $minimal_header = $args{'minimal_header'} || "NO";


    #### If the output mode is interactive text, display text header
    if ($self->output_mode() eq 'interactive') {
      $self->printTextHeader();
      return;
    }


    #### If the output mode is not html, then we don't want a header here
    if ($self->output_mode() ne 'html') {
      return;
    }


    my $http_header = $self->get_http_header();

    print qq~$http_header
	<HTML><HEAD>
	<TITLE>$DBTITLE - Systems Biology Experiment Analysis Management System</TITLE>
    ~;


    #### Only send Javascript functions if the full header desired
    unless ($minimal_header eq "YES") {
        $self->printJavascriptFunctions();
    }


    #### Send the style sheet
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
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" OnLoad="self.focus();">
	<table border=0 width="100%" cellspacing=0 cellpadding=3>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td bgcolor="$BARCOLOR"><a href="http://www.systemsbiology.org/"><img height=60 width=60 border=0 alt="ISB Main" src="/images/ISBlogo60t.gif"></a><a href="http://db.systemsbiology.net/"><img height=60 width=60 border=0 alt="ISB DB" src="/images/ISBDBt.gif"></a></td>
	  <td align="left" $header_bkg><H1>$DBTITLE - Systems Biology Experiment Analysis Management System<BR>$DBVERSION</H1></td>
	</tr>
    ~;

    #print ">>>http_header=$http_header<BR>\n";

    if ($minimal_header eq "YES") {
      print qq~
	<!------- Button Bar -------------------------------------------->
	<tr><td bgcolor="$BARCOLOR" align="left" valign="top">
	<table border=0 width="120" cellpadding=2 cellspacing=0>

	<tr><td><a href="/"><b>Server Home</b></a></td></tr>
	<tr><td><a href="$HTML_BASE_DIR/"><b>$DBTITLE Home</b></a></td></tr>

	</table>
	</td>

	<!-------- Main Page ------------------------------------------->
	<td valign=top>
	<table border=0 width="680" bgcolor="#ffffff" cellpadding=10>
	<tr><td>
      ~;
      return;
    }


    if ($navigation_bar eq "YES") {
      print qq~
	<!------- Button Bar -------------------------------------------->
	<tr><td bgcolor="$BARCOLOR" align="left" valign="top">
	<table border=0 width="120" cellpadding=2 cellspacing=0>

	<tr><td><a href="$CGI_BASE_DIR/main.cgi">$DBTITLE Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Installed Modules:</td></tr>
      ~;

      #### Get the list of Modules available to us
      my @modules = $self->getModules();

      #### Print out entries for each module
      my $module;
      foreach $module (@modules) {
        print qq~
	<tr><td><a href="$CGI_BASE_DIR/$module/main.cgi"><nobr>&nbsp;&nbsp;&nbsp;$module</nobr></a></td></tr>
        ~;
      }

      print qq~
	<tr><td>&nbsp;</td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/ManageTable.cgi?TABLE_NAME=user_login">Admin</a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td><a href="$HTML_BASE_DIR/doc/">Documentation</a></td></tr>
	</table>
	</td>

	<!-------- Main Page ------------------------------------------->
	<td valign=top>
	<table border=0 bgcolor="#ffffff" cellpadding=4>
	<tr><td align="top">

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

    my $FONT_SIZE=9;
    my $FONT_SIZE_SM=8;
    my $FONT_SIZE_LG=12;
    my $FONT_SIZE_HG=14;

    if ( $HTTP_USER_AGENT =~ /Mozilla\/4.+X11/ ) {
      $FONT_SIZE=12;
      $FONT_SIZE_SM=11;
      $FONT_SIZE_LG=14;
      $FONT_SIZE_HG=19;
    }


    print qq~
	<style type="text/css">
	//<!--
	body {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt}
	th   {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; font-weight: bold;}
	td   {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt;}
	form   {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt}
	pre    {  font-family: Courier New, Courier; font-size: ${FONT_SIZE_SM}pt}
	h1   {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_HG}pt; font-weight: bold}
	h2   {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_LG}pt; font-weight: bold}
	h3   {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_LG}pt}
	h4   {  font-family: AHelvetica, rial, sans-serif; font-size: ${FONT_SIZE_LG}pt}
	A.h1 {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_HG}pt; font-weight: bold; text-decoration: none; color: blue}
	A.h1:link {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_HG}pt; font-weight: bold; text-decoration: none; color: blue}
	A.h1:visited {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_HG}pt; font-weight: bold; text-decoration: none; color: darkblue}
	A.h1:hover {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_HG}pt; font-weight: bold; text-decoration: none; color: red}
	A:link    {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: none; color: blue}
	A:visited {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: none; color: darkblue}
	A:hover   {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: underline; color: red}
	A:link.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	A:visited.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	A:hover.nav {  font-family: Helvetica, Arial, sans-serif; color: red;}
	.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	//-->
	</style>
    ~;

    #### Boneyard:
    #	th   {  font-family: Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt; font-weight: bold; background-color: #A0A0A0;}
    #	pre    {  font-family: Courier; font-size: ${FONT_SIZE}pt}



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


        // -->
        </SCRIPT>
    ~;

}


###############################################################################
# printMinimalPageHeader
###############################################################################
sub printMinimalPageHeader {
    my $self = shift;
    my $head = shift || "Content-type: text/html\n\n";
    
    print qq~$head
	<HTML>
	<HEAD><TITLE>$DBTITLE - Systems Biology Experiment Analysis Management System</TITLE></HEAD>

	<!-- Background white, links blue (unvisited), navy (visited), red (active) -->
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" >
	<table border=0 width="100%" cellspacing=1 cellpadding=3>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td><img height=100 width=100 border=0 alt="$DBTITLE Logo" src="$HTML_BASE_DIR/images/logo.gif"></td>
	  <td align="left"><H1>$DBTITLE - Systems Biology Experiment Analysis Management System<BR>$DBVERSION</H1></td>
	</tr>

	<!------- Button Bar -------------------------------------------->
	<tr><td align="left" valign="top">
	<table border=0 width="120" cellpadding=2 cellspacing=0>

	<tr><td><a href="$HTML_BASE_DIR/"><b>$DBTITLE Home</b></a></td></tr>

	</table>
	</td>

	<!-------- Main Page ------------------------------------------->
	<td valign=top>
	<table border=0 width="680" bgcolor="#ffffff" cellpadding=10>
	<tr><td>

    ~;

}


###############################################################################
# printUserContext
###############################################################################
sub printUserContext {
    my $self = shift;
    my %args = @_;

    #### This is now obsoleted and ignored
    my $style = $args{'style'} || "HTML";


    #### If the output mode is interactive text, switch to text mode
    if ($self->output_mode() eq 'interactive') {
      $style = 'TEXT';

    #### If the output mode is html, then switch to html mode
    } elsif ($self->output_mode() eq 'html') {
      $style = 'HTML';

    #### Otherwise, we're in some data mode and don't want to see this
    } else {
      return;
    }


    my $subdir = $self->getSBEAMS_SUBDIR();
    $subdir .= "/" if ($subdir);

    $current_username = $self->getCurrent_username;
    $current_contact_id = $self->getCurrent_contact_id;
    $current_work_group_id = $self->getCurrent_work_group_id;
    $current_work_group_name = $self->getCurrent_work_group_name;
    $current_project_id = $self->getCurrent_project_id;
    $current_project_name = $self->getCurrent_project_name;
    $current_user_context_id = $self->getCurrent_user_context_id;

    my $temp_current_work_group_name = $current_work_group_name;
    if ($current_work_group_name eq "Admin") {
      $temp_current_work_group_name = "<FONT COLOR=red><BLINK>$current_work_group_name</BLINK></FONT>";
    }

    if ($style eq "HTML") {
      print qq!
	<TABLE width="100%"><tr><td width="100%">
	Current Login: <B>$current_username</B> ($current_contact_id) &nbsp;
	Current Group: <B>$temp_current_work_group_name</B> ($current_work_group_id) &nbsp;
	Current Project: <B>$current_project_name</B> ($current_project_id)
	&nbsp; <A HREF="$CGI_BASE_DIR/${subdir}ManageTable.cgi?TABLE_NAME=user_context&user_context_id=$current_user_context_id">[CHANGE]</A> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	</td></tr></TABLE>
      !;
     }


    if ($style eq "TEXT") {
      print qq!Current Login: $current_username ($current_contact_id)  Current Group: $current_work_group_name ($current_work_group_id)
Current Project: $current_project_name ($current_project_id)
!;
     }


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


  #### Process the arguments list
  my $close_tables = $args{'close_tables'} || 'YES';
  my $display_footer = $args{'display_footer'} || 'YES';
  my $separator_bar = $args{'separator_bar'} || 'NO';


  #### Hack to support previous, lame API.  Get rid of this eventually
  if (exists($args{'CloseTables'})) {
    $display_footer = 'NO';
  }


  #### If the output mode is interactive text, display text header
  if ($self->output_mode() eq 'interactive' && $display_footer eq 'YES') {
    $self->printTextHeader(%args);
    return;
  }


  #### If the output mode is not html, then we don't want a header here
  if ($self->output_mode() ne 'html') {
    return;
  }


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
    print qq~
	<BR><HR SIZE="2" NOSHADE WIDTH="30%" ALIGN="LEFT">
	SBEAMS @ ISB [Under Development]<BR><BR><BR>
	</BODY></HTML>\n\n
    ~;
  }

}



###############################################################################
# getGoBackButton
###############################################################################
sub getGoBackButton {
  my $self = shift;

  my $button = qq~
	<FORM>
	<INPUT TYPE="button" NAME="back" VALUE="Go Back"
		onClick="history.back()">
	</FORM>
    ~;

  return $button;
}


###############################################################################
# Print Incomplete Form Message
###############################################################################
sub printIncompleteForm {
    my $self = shift;
    my $errors = shift;
    my $back_button = $self->getGoBackButton();
    print qq!
        <P>
        <H2>Incomplete Form</H2>
        $LINESEPARATOR
        <P>
        <TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
        All required form fields must be filled in. Please see the 
        errors listed below and click the Back button to return to 
        the form.
        <P>
        $errors 
        <P>
        <CENTER>
        $back_button
        </CENTER>
        </TD></TR></TABLE>
        $LINESEPARATOR
        <P>!;
} # end printIncompleteForm



###############################################################################
# printTextHeader
###############################################################################
sub printTextHeader {
    my $self = shift;
    my %args = @_;

    print qq~---------------------------------- SBEAMS -------------------------------------
~;

}

###############################################################################
# printTextFooter
###############################################################################
sub printTextFooter {
    my $self = shift;
    my %args = @_;

    print qq~
---------------------------------- SBEAMS -------------------------------------
~;

}


###############################################################################
# Print Debugging Information
###############################################################################
sub printDebuggingInfo {
  my $self = shift;
  my $q = shift;

  my $element;

  #### Write out a HTTP header
  print "Content-type: text/html\n\n<BR><BR><PRE>\n";

  #### Write out all the environment variables
  print "Environment variables:\n";
  foreach $element (keys %ENV) {
    print "$element = '$ENV{$element}'\n";
  }

  #### Write out all the supplied parameters
  print "\nCGI parameters:\n";
  foreach $element ( $q->param ) {
    my $liststr = join(",",$q->param($element));
    print "$element = '$liststr'\n";
  }

  print "</PRE><BR>\n";

} # end printDebuggingInfo



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::HTMLPrinter

SBEAMS Core HTML and general header/footer display methods

=head2 SYNOPSIS

See SBEAMS::Connection for usage synopsis.

=head2 DESCRIPTION

This module is inherited by the SBEAMS::Connection module, although it
can be used on its own.  Its main function is to encapsulate common
HTML printing routines used by this application.


=head2 METHODS

=over

=item * B<printPageHeader()>

    Prints the common HTML header used by all HTML pages generated 
    by theis application

=item*  B<printPageFooter()>

    Prints the common HTML footer used by all HTML pages generated 
    by this application

=item * B<getGoBackButton()>

    Returns a form button, coded with javascript, so that when it 
    is clicked the user is returned to the previous page in the 
    browser history.


=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

