package SBEAMS::BEDB::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::BEDB::HTMLPrinter
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
             $current_project_id $current_project_name $current_user_context_id
             $DISPLAY_STYLE);
use CGI::Carp qw(fatalsToBrowser croak);
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TableInfo;

use SBEAMS::BEDB::Settings;
use SBEAMS::BEDB::TableInfo;


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
  $self->display_page_header(@_);
}


###############################################################################
# display_page_header
###############################################################################
sub display_page_header {
    my $self = shift;
    my %args = @_;


    #### Process the arguments list
    my $navigation_bar = $args{'navigation_bar'} || "YES";
    my $display_style = $args{'display_style'} || "External";
    $DISPLAY_STYLE = $display_style;


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
	<TITLE>Brain Expression Database</TITLE>
    ~;


    #### If External, adjust some settings
    if ($display_style eq "External") {
      $BARCOLOR = "#eeeeee";
      $navigation_bar="YES";
    }


    #### If we want to use internal style
    if ($display_style ne "External") {

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
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" OnLoad="self.focus();">
	<table border=0 width="100%" cellspacing=0 cellpadding=1>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td bgcolor="$BARCOLOR"><a href="http://www.systemsbiology.org/"><img height=60 width=60 border=0 alt="ISB Main" src="/images/ISBlogo60t.gif"></a><a href="http://db.systemsbiology.net/"><img height=60 width=60 border=0 alt="ISB DB" src="/images/ISBDBt.gif"></a></td>
	  <td align="left" $header_bkg><H1>$DBTITLE - $SBEAMS_PART<BR>$DBVERSION</H1></td>
	</tr>

      ~;

    #### If we want to use fancy External style
    } else {
      print qq~
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<meta name="author" content="FutureVision Web Agency - web site development, design, database development, corporate image &amp; multimedia presentations, Internet marketing &amp; promotion.">
<meta Author="Developed by FutureVision.com.ua, full-service software development, design, application, database development, corporate image & multimedia presentations, Internet marketing">
<link rel="stylesheet" href="/includes/BEDB/styles.css" type="text/css">
</head>
<body bgcolor="#FFFFFF" text="#000000" leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" OnLoad="self.focus();">
<table width="100%" border="0" cellspacing="0" cellpadding="0">
  <tr>
    <td valign="top">
      <table width="100%" border="0" cellspacing="0" cellpadding="0">
        <tr>
          <td class="color1"><img src="/images/BEDB/logo.gif" width="507" height="35" vspace="21" hspace="0" alt="Brain Expression Database"><br>
            <div class="topMenu"><a href="index.htm">&nbsp;HOME </a>|<a href="overview.htm">
              OVERVIEW </a>|<span class="sel"> LIBRARY &amp; EST ARCHIVE </span>|<a href="blast.htm">
              BLAST </a>|<a href="expression.htm"> EXPRESSION </a>|<a href="proteome.htm">
              PROTEOME </a>|<a href="transcriptome.htm"> TRANSCRIPTOME </a>|<a href="links.htm">
              LINKS&nbsp;</a></div>
          </td>
        </tr>
        <tr>
          <td class="color2"><img src="/images/BEDB/1x1t.gif" width="1" height="1"></td>
        </tr>
        <tr>
          <td class="color3">
            <table width="750" border="0" cellspacing="0" cellpadding="0">
              <tr>
                <td><img src="/images/BEDB/header03.jpg" width="367" height="75"></td>
                <td valign="bottom" align="right"><img src="/images/BEDB/_plibrary.gif" width="258" height="16" vspace="7" hspace="0" alt="Library &amp; EST archive"></td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
<table width="730" border="0" cellspacing="0" cellpadding="0">
      ~;
    }


    if ($navigation_bar eq "YES") {
      print qq~
	<!------- Button Bar -------------------------------------------->
	<tr><td bgcolor="$BARCOLOR" align="left" valign="top">
	<table border=0 width="120" cellpadding=2 cellspacing=0>

	<tr><td><a href="$CGI_BASE_DIR/main.cgi">$DBTITLE Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_PART/main.cgi">$SBEAMS_PART Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Summarize:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/BEDB/show_est_library"><nobr>&nbsp;&nbsp;&nbsp;EST Libraries</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Browse Data:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/BEDB/get_est_library"><nobr>&nbsp;&nbsp;&nbsp;EST Libraries</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/BEDB/get_annotation"><nobr>&nbsp;&nbsp;&nbsp;Genes</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/BEDB/get_est"><nobr>&nbsp;&nbsp;&nbsp;ESTs</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/BEDB/get_biosequence"><nobr>&nbsp;&nbsp;&nbsp;BioSequences</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Manage Tables:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/BEDB/ManageTable.cgi?TABLE_NAME=BE_biosequence_set"><nobr>&nbsp;&nbsp;&nbsp;BioSequenceSets</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	</table>
	</td>

	<!-------- Main Page ------------------------------------------->
	<td valign=top width="100%">
	<table border=0 bgcolor="#ffffff" cellpadding=4>
	<tr><td>

    ~;
    } else {
      print qq~
	</TABLE>
      ~;
    }

} # end display_page_header


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



        // -->
        </SCRIPT>
    ~;

}



###############################################################################
# getTableColorScheme
###############################################################################
sub getTableColorScheme {
  my $self = shift;

  my %row_color_scheme;
  $row_color_scheme{header_background} = '#008ba3';
  $row_color_scheme{change_n_rows} = 3;
  my @row_color_list = ("#F0F0F0","#ceeff0");
  $row_color_scheme{color_list} = \@row_color_list;
  my $row_color_scheme_ref = \%row_color_scheme;

  return $row_color_scheme_ref;
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
    if ($DISPLAY_STYLE ne "External") {
      print qq~
	<BR><HR SIZE="2" NOSHADE WIDTH="30%" ALIGN="LEFT">
	SBEAMS - $SBEAMS_PART [Under Development]<BR><BR><BR>
	</BODY></HTML>\n\n
      ~;
    } else {
      print qq~
      <table width="750" border="0" cellspacing="0" cellpadding="0">
        <tr>
          <td>
            <div class="bottomMenu"><a href="index.htm">&nbsp;Home </a>|<a href="overview.htm">
              Overview </a>|<span class="sel"> Library &amp; EST archive </span>|<a href="blast.htm">
              Blast </a>|<a href="expression.htm"> Expression </a>|<a href="proteome.htm">
              Proteome </a>|<a href="transcriptome.htm"> Transcriptome </a>|<a href="links.htm">
              Links&nbsp;</a></div>
            <div class="copyright">Copyright &copy; Institute for Systems Biology,
              2002. Design by <a href="http://www.futurevision.com.ua" target="_blank">FutureVision</a></div>
          </td>
        </tr>
      </table>
      <BR><BR><BR>
      </BODY></HTML>
      ~;

    }

  }

} # end display_page_footer



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
