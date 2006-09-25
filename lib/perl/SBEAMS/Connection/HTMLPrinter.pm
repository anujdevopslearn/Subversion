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
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw($current_contact_id $current_username $q
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name $current_user_context_id);
use CGI::Carp qw(croak);
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Log;
use SBEAMS::Connection::Authenticator qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::TabMenu;

use Env qw (HTTP_USER_AGENT);

my $log = SBEAMS::Connection::Log->new();



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

  #### If the output mode is not html, then we don't need the rest
  return unless $self->output_mode() eq 'html';

  my $http_header = $self->get_http_header( $self->get_output_mode() );
  print $http_header;

  print qq~
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
  $header_bkg = "background=\"$HTML_BASE_DIR/images/plaintop.jpg\"" if ($DBVERSION =~ /Primary/);

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
	  <td bgcolor="$BARCOLOR"><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmltblue.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmltblue.gif"></a></td>
	  <td align="left" $header_bkg><H1>$DBTITLE - Systems Biology Experiment Analysis Management System<BR>$DBVERSION</H1></td>
	</tr>
    ~;


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
	<tr><td><a href="$CGI_BASE_DIR/ChangePassword">Change Password</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Available&nbsp;Modules:</td></tr>
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
      ~;

      my $current_work_group_name = $self->getCurrent_work_group_name();
      if ($current_work_group_name eq 'Admin') {
        print qq~
	  <tr><td>&nbsp;</td></tr>
	  <tr><td><a href="$CGI_BASE_DIR/ManageTable.cgi?TABLE_NAME=user_login">Admin</a></td></tr>
        ~;
      }

      print qq~
	<tr><td>&nbsp;</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/Help?document=index">Documentation</a></td></tr>
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
    my $FONT_SIZE_MED=12;
    my $FONT_SIZE_LG=12;
    my $FONT_SIZE_HG=14;

    if ( $HTTP_USER_AGENT =~ /Mozilla\/4.+X11/ ) {
      $FONT_SIZE_SM=11;
      $FONT_SIZE=12;
      $FONT_SIZE_MED=3;
      $FONT_SIZE_LG=14;
      $FONT_SIZE_HG=19;
    }


    print qq~
	<style type="text/css">
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
	.white_bg{background-color: #FFFFFF }
	.grey_bg{ background-color: #CCCCCC }
	.med_gray_bg{ background-color: #CCCCCC; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; Padding:2}
	.grey_header{ font-family: Helvetica, Arial, sans-serif; color: #000000; font-size: ${FONT_SIZE_HG}pt; background-color: #CCCCCC; font-weight: bold; padding:1 2}
	.rev_gray{background-color: #555555; font-size: ${FONT_SIZE_MED}pt; font-weight: bold; color:white; line-height: 25px;}
	.rev_gray_head{background-color: #555555; font-size: ${FONT_SIZE}pt; font-weight: bold; color:white; line-height: 25px;}
	.blue_bg{ font-family: Helvetica, Arial, sans-serif; background-color: #4455cc; font-size: ${FONT_SIZE_HG}pt; font-weight: bold; color: white}
	.blue_bg_glyco{ font-family: Helvetica, Arial, sans-serif; background-color: #4455cc; font-size: ${FONT_SIZE_MED}pt; font-weight: bold; color: white}
	.lite_blue_bg{font-family: Helvetica, Arial, sans-serif; background-color: #eeeeff; font-size: ${FONT_SIZE_HG}pt; color: #cc1111; font-weight: bold;border-style: solid; border-width: 1px; border-color: #555555 #cccccc #cccccc #555555;}
	.orange_bg{ background-color: #FFCC66; font-size: ${FONT_SIZE_LG}pt; font-weight: bold}
	.red_bg{ background-color: #882222; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; color:white; Padding:2}
	.small_cell {font-size: 8; background-color: #CCCCCC; white-space: nowrap  }
	.med_cell {font-size: 10; background-color: #CCCCCC; white-space: nowrap  }
	.anno_cell {white-space: nowrap  }
	.present_cell{border: none}
	.marginal_cell{border: 1px solid #0033CC}
	.absent_cell{border: 2px solid #660033}
	.small_text{font-family: Helvetica,Arial,sans-serif; font-size:x-small; color:#aaaaaa}
	.table_setup{border: 0px ; border-collapse: collapse;   }
	.pad_cell{padding:5px;  }
	.sequence_font{font-family:courier; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; letter-spacing:0.5}	
	.white_hyper_text{font-family: Helvetica,Arial,sans-serif; color:#000000;}
	
	.white_text    {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: underline; color: white; CURSOR: help;}
	.white_text_head {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: underline; color: white; CURSOR: help;}
	
	.pseudo_link    {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration:none; color: blue; CURSOR: help;}
	
  .observed_pep{ 
  background-color: #882222; 
  font-size: ${FONT_SIZE_LG}pt; 
  font-weight: bold; 
  letter-spacing:0.5;	
  color:white; 
  }
  .identified_pep{ 
  background-color: #EEEEEE; 
  font-size: ${FONT_SIZE_LG}pt; 
  font-weight: bold; 
  letter-spacing:0.5;	
  color:white; 
  Padding:1;
  border-style: solid;
  border-left-width: 1px;
  border-right-width: 1px;
  border-top-width: 1px;
  border-left-color: #eeeeee;
  border-right-color: #eeeeee;
  border-top-color: #aaaaaa;
  border-bottom-color:#aaaaaa;
  }
  .predicted_pep{ 
  background-color: #FFCC66; 
  font-size: ${FONT_SIZE_LG}pt; 
  font-family:courier;
  font-weight: bold; 
  letter-spacing:0.5;	
  border-style: solid;
  border-width: 1px;
  border-right-color: blue ;
  border-left-color:  red ;
  }
	
	.sseq{ background-color: #CCCCFF; font-size: ${FONT_SIZE_LG}pt; font-weight: bold}
	.tmhmm{ background-color: #CCFFCC; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; text-decoration:underline}
  .instruction_text{ font-size: ${FONT_SIZE_LG}pt; font-weight: bold}
	
	.glyco_site{ background-color: #ee9999; 
	border-style: solid;
	font-size: ${FONT_SIZE_LG}pt; 
	font-weight: bold; 
  font-family:courier;
	border-width: 1px;
  letter-spacing:0.5;	
	/* top right bottom left */
	border-color: #444444 #eeeeee #eeeeee #444444; }	
	
	
	a.edit_menuButton:link {
	/* font-size: 12px; */
	font-family: arial,helvetica,san-serif;
	color: #000000;
	line-height: 10px;
	white-space: nowrap;
	font-style: normal;
	font-weight: bold;
  	/* display: block; */
  	margin: 3px;
  	border-style: solid;
	border-width: 1px;
	border-color: #ccffff #669999 #669999 #ccffff;
	padding: 2px 2px 2px 2px;
	background-color: #ffbb00;
 	}
a.edit_menuButton:visited {
	/* font-size: 12px; */
	font-family: arial,helvetica,san-serif;
	color: #333333;
	line-height: 10px;
	font-style: normal;
	font-weight: bold;
	text-decoration: none;
  	/* display: block; */
  	border-color: #ffffff #99cccc #99cccc #ffffff;
	margin: 3px;
	border-style: solid;
	border-width: 1px;
	padding: 2px 2px 2px 2px;
	background-color: #ff8800;
	
 	}

a.edit_menuButton:hover {
 	/* font-size: 12px; */
	font-family: arial,helvetica,san-serif;
	color: #000000;
	line-height: 12px;
	font-style: normal;
	font-weight: bold;
	/* display: block; */
  	margin: 0px;
  	border-style: solid;
	border-width: 1px;
	border-color: #ffffff #99cccc #99cccc #ffffff;
	margin: 3px;
	padding: 2px 2px 2px 2px;
	background-color: #ff8800;
}
a.edit_menuButton:active {
 	/* font-size: 12px; */
	font-family: arial,helvetica,san-serif;
	color: #ffffff;
	line-height: 10px;
	font-style: normal;
	font-weight: bold;
	text-decoration: none;
  	/* display: block; */	
  	margin: 0px;
  	border-style: solid;
	border-width: 2px;
	border-color: #336666 #ccffff #ccffff #336666;
	margin: 3px;
	padding: 2px 2px 2px 2px;
	background-color: #ff8800;
}
a.red_button:link{
 	/* font-size: 12px; */
	font-family: arial,helvetica,san-serif;
	color: #ffffff;
	line-height: 10px;
	font-style: normal;
	font-weight: bold;
	text-decoration: none;
  	/* display: block; */	
  	margin: 0px;
  	border-style: solid;
	border-width: 2px;
	border-color: #336666 #ccffff #ccffff #336666;
	margin: 0px;
	padding: 2px 2px 2px 2px;
	background-color: #ff0066;
}

a.blue_button:link{ 
	background: #366496;
	color: #ffffff;
	text-decoration: none; 
	padding:0px 3px 0px 3px; 
	border-top: 1px solid #CBE3FF; 
	border-right: 1px solid #003366; 
	border-bottom: 1px solid #003366; \
	border-left:1px solid #B7CFEB; 
}

a.blue_button:visited{ 
	background: #366496;
	color: #ffffff;
	text-decoration: none; 
	padding:0px 3px 0px 3px; 
	border-top: 1px solid #CBE3FF; 
	border-right: 1px solid #003366; 
	border-bottom: 1px solid #003366; \
	border-left:1px solid #B7CFEB; 
}
a.blue_button:hover{ 
	background: #366496;
	color: #777777;
	text-decoration: none; 
	padding:0px 3px 0px 3px; 
	border-top: 1px solid #CBE3FF; 
	border-right: 1px solid #003366; 
	border-bottom: 1px solid #003366; \
	border-left:1px solid #B7CFEB; 
}

a.blue_button:active{ 
	background: #366496;
	color: #ffffff;
	text-decoration: none; 
	padding:0px 3px 0px 3px; 
	border-top: 1px solid #CBE3FF; 
	border-right: 1px solid #003366; 
	border-bottom: 1px solid #003366; \
	border-left:1px solid #B7CFEB; 
}
    ~;

  my $agent = $q->user_agent();
  $log->debug( $agent );
  if ( $agent =~ /MSIE/ ) {
    print " .med_vert_cell {font-size: 10; background-color: #CCCCCC; white-space: nowrap; writing-mode: tb-rl; filter: flipv fliph;  }\n";
  }
  print "</style>\n";

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
            document.MainForm.apply_action_hidden.value = "REFRESH";
            document.MainForm.action.value = "REFRESH";
	    document.MainForm.submit();
            //document.forms[0].apply_action_hidden.value = "REFRESH";
	    //document.forms[0].submit();
	} // end refresh


	function showPassed(input_field) {
            //confirm( "input_field ="+input_field+"=");
            confirm( "selected option ="+document.MainForm.slide_id.options[document.MainForm.slide_id.selectedIndex].text+"=");
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
    my $head = shift || $self->get_http_header;
    
    print qq~$head
	<HTML>
	<HEAD><TITLE>$DBTITLE - Systems Biology Experiment Analysis Management System</TITLE></HEAD>

	<!-- Background white, links blue (unvisited), navy (visited), red (active) -->
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" >
	<table border=0 width="100%" cellspacing=1 cellpadding=3>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmltblue.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmltblue.gif"></a></td>
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
    my %args  = @_;
    


    #### This is now obsoleted and ignored
    my $style = $args{'style'} || "HTML";


    my $subdir = $self->getSBEAMS_SUBDIR();
    $subdir .= "/" if ($subdir);


    #### If the output mode is interactive text, switch to text mode
    if ($self->output_mode() eq 'interactive') {
      $style = 'TEXT';

    #### If the output mode is html, then switch to html mode
    } elsif ($self->output_mode() eq 'html') {
      $style = 'HTML';
#      if ($subdir eq 'Proteomics/' || $subdir eq 'Microarray/' || $subdir eq '') {
      $self->printUserChooser(%args);
      return;
#      } 

    #### Otherwise, we're in some data mode and don't want to see this
    } else {
      return;
    }


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
    my $module_name = '';
    $module_name = " - $SBEAMS_PART" if (defined($SBEAMS_PART));

    print qq~
	<BR>
	<HR SIZE="2" NOSHADE WIDTH="35%" ALIGN="LEFT" color="#FF8700">
	<TABLE>
	<TR>
	  <TD><IMG SRC="$HTML_BASE_DIR/images/sbeamstinywhite.png"></TD>
	  <TD class='small_text'>SBEAMS$module_name&nbsp;&nbsp;&nbsp;$SBEAMS_VERSION<BR>
              &copy; 2005 Institute for Systems Biology<TD>
	  <TD><IMG SRC="$HTML_BASE_DIR/images/isbtinywhite.png"></TD>
	</TR>
	</TABLE>
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
# Print Insufficient Project Permissions Message
###############################################################################
sub printInsufficientPermissions {
  my $self = shift;
  my $errors = shift;
  my $back_button = $self->getGoBackButton();

  my $msg =<<"  END_MSG";
  Unable to execute requested action due to insufficient privileges.  Please
  see specific errors below for details.
  END_MSG

  print qq!
  <P>
  <H2>Permissions Error</H2>
  $LINESEPARATOR
  <P>
  <TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
  $msg
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
# Print Incomplete Form Message
###############################################################################
sub printIncompleteForm {
  my $self = shift;
  my $errors = shift;
  my $mode = shift || 'Incomplete';
  my $back_button = $self->getGoBackButton();

  my $msg =<<"  END_MSG";
  All required form fields must be filled in. Please see the 
  errors listed below and click the Back button to return to 
  the form.
  END_MSG

  print qq!
  <P>
  <H2>Incomplete Form</H2>
  $LINESEPARATOR
  <P>
  <TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
  $msg
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
  print $self->get_http_header;

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

sub printCGIParams {
  my $self = shift;
  my $q = shift;

  my $element;

  #### Write out a HTTP header
  print $self->get_http_header;

  #### Write out all the supplied parameters
  print "\nCGI parameters:\n";
  foreach $element ( $q->param ) {
    my $liststr = join(",",$q->param($element));
    print "$element = '$liststr'\n";
  }

  print "</PRE><BR>\n";

} # end printCGIParams

sub getMainPageTabMenu {
  my $self = shift;
	my $tabmenu = $self->getMainPageTabMenuObj( @_ );
  my $HTML = "$tabmenu";
  return \$HTML;
}

sub getMainPageTabMenuObj {
  my $self = shift;
  my %args = @_;

  # Create new tabmenu item.
  my $tabmenu = SBEAMS::Connection::TabMenu->new( cgi => $args{cgi} );

  # Add tabs
  $tabmenu->addTab( label    => 'Current Project', 
                    helptext => 'View details of current Project' );
  $tabmenu->addTab( label    => 'My Projects', 
                    helptext => 'View all projects owned by me' );
  $tabmenu->addTab( label    => 'Accessible Projects',
                    helptext => 'View projects I have access to' );
  $tabmenu->addTab( label    => 'Recent Resultsets',
                    helptext => 'View recent SBEAMS resultsets' );

  my $content = ''; # Scalar to hold content.

  # conditional block to exec code based on selected tab.

  if (  $tabmenu->getActiveTabName() eq 'Current Project' )  { 

    my $project_id = $self->getCurrent_project_id();
    if ( $project_id ) {
      $content = $self->getProjectDetailsTable( project_id => $project_id ); 
    } else {
      my $pad = '&nbsp;' x 5;
      $content = $pad . $self->makeInfoText('No current project selected');
    }

  } elsif ( $tabmenu->getActiveTabName() eq 'My Projects' ){

    $content = $self->getProjectsYouOwn();

  } elsif ( $tabmenu->getActiveTabName() eq 'Accessible Projects' ){

    $content = $self->getProjectsYouHaveAccessTo();

  } elsif ( $tabmenu->getActiveTabName() eq 'Recent Resultsets' ){

    $content = $self->getRecentResultsets();

  } else {

    my $pad = '&nbsp;' x 5;
    $content = $pad . $self->makeInfoText('Unknown tab selected');
    return \$content;

  }

  $tabmenu->addContent( $content );
	return($tabmenu);

}



###############################################################################
# Report Exception
###############################################################################
sub reportException {
  my $self = shift;
  my $METHOD = 'reportException';
  my %args = @_;

  #### Process the arguments list
  my $state = $args{'state'} || 'INTERNAL ERROR';
  my $type = $args{'type'} || '';
  my $message = $args{'message'} || 'NO MESSAGE';
  my $HTML_message = $args{'HTML_message'} || '';


  #### If invocation_mode is HTTP, then printout an HTML message
  if ($self->invocation_mode() eq 'http') {
    print "<H4>$state: ";
    print "$type<BR>\n" if ($type);
    if ($HTML_message) {
      print "$HTML_message</H4>\n";
    } else {
      print "$message</H4>\n";
    }
    return;
  } else {
    $self->handle_error( state => $args{state}, 
                   error_type  => lc($args{type}).
                       message => $args{message} );
  }


  if (1 == 1) {
    print "$state: ";
    print "$type\n" if ($type);
    print "$message\n";
    return;
  }

} # end reportException

#+ 
# Utility method, returns passed text enclosed in <FONT COLOR=#AAAAAA></FONT>
#-
sub makeInactiveText {
  my $self = shift;
  my $text = shift;
  return( "<FONT COLOR=#AAAAAA>$text</FONT>" );
}

#+ 
# Utility method, returns text formatted for INFO messages
#-
sub makeInfoText {
  my $self = shift;
  my $text = shift;
  return( "<I><FONT COLOR=#666666>$text</FONT></I>" );
}

#+
# returns http Content-type based on user-supplied 'mode' 
#-
sub get_content_type {
  my $self = shift;
  my $type = shift || 'html';

  my %ctypes = (  tsv => 'text/tab-separated-values',
              tsvfull => 'text/tab-separated-values',
                  csv => 'text/comma-separated-values',
              csvfull => 'text/comma-separated-values',
                  css => 'text/css',
                  xml => 'text/xml',
                 text => 'text/plain',
                 html => 'text/html',
                excel => 'application/excel',
                force => 'application/force-download',
                 jpg  => 'image/jpeg',
                 png  => 'image/png',
                 jnlp => 'application/x-java-jnlp-file',
            cytoscape => 'application/x-java-jnlp-file'
               );
  return $ctypes{$type};
}

#+
# Method returns an http header based on user supplied info.
# 
# @narg type    Explicit content type supercedes mode-based type.
# @narg mode    Output mode, will fetch if not supplied.  Begets content-type
# @narg cookies Boolean (perl true/false), supply cookies with the header?
# -
sub get_http_header {
  my $self = shift;
  my %args = @_;

  # output mode
  my $mode = $args{mode} || $self->output_mode();
  $mode =~ s/full//g; # Simplify tsvfull, csvfull modes

  my %param_hash;

  # explicit content type
  my $type = $args{type} || $self->get_content_type( $mode );

  # use cookies? 
  my $cookies = $args{cookies} || 1;
  
  my $header;
  my @cookie_jar;
  for ( qw( _session_cookie _sbname_cookie _sbeamsui ) ) {
    push @cookie_jar, $self->{$_} if $self->{$_};
  }
  if ( @cookie_jar && $cookies ) {
    $param_hash{'-cookie'} = \@cookie_jar;
#    $header = $q->header( -type => $type, -cookie => \@cookie_jar );
  } elsif ( $args{filename} ) {
    $param_hash{'Content-Disposition'}="attachment;filename=$args{filename}";
#    $header = $q->header( -type => $type );
  } else {
#    $header = $q->header( -type => $type );
  }
  $header = $q->header( '-type' => $type, %param_hash );
  return $header;
}

#+
# Routine to process SBEAMS UI cookie, if it exists.
# Gets called from Authenticator, but put here since it is a UI feature.
#-
sub processSBEAMSuiCookie {
  my $self = shift;

  # Fetch cookie from cgi object
  my %ui_cookie = $q->cookie('SBEAMSui');

  # If the cookie is there, process.
  if ( scalar(keys(%ui_cookie)) ) {

    # Transfer any settings to session hash
    for my $key ( keys (%ui_cookie) ) {
      $key = $q->unescape( $key ); # Key should probably always be clean...
      my $value = $q->unescape( $ui_cookie{$key} );
      $self->setSessionAttribute( key => $key,
                                  value => $ui_cookie{$key} );
    }

    # Figure out path from referer, cache blank cookie to reset.
    my $ref = $q->referer();
    $ref =~ /.*($HTML_BASE_DIR.*\/).*/;
    my $cpath = $1 || '/';
    my $cookie = $q->cookie(-name    => 'SBEAMSui',
                            -path   => $cpath,
                            -value   => {} );
    $self->{_sbeamsui} = $cookie;
  }
}

sub getModuleButton {
  my $self = shift;
  my $module = shift || 'unknown';
  my %colors = ( Immunostain => '#77A8FF',
                 Microarray  => '#FFCC66',
                 Biomarker   => '#CC99CC',
                 Proteomics  => '#66CC66',
                 Cytometry   => '#EEEEEE',
                 Inkjet      => '#AABBFF',
                 Interactions => '#DDFFFF',
                 PeptideAtlas => '#FFBBEE',
                 ProteinStructure => '#CCCCFF',
                 unknown     => '#888888' );

  return( <<"  END" );
  <STYLE TYPE=text/css>
  #${module}_button {
  background-color: $colors{$module};
  border: 1px #666666 solid;
  width: auto;
  text-align: center;
  white-space: nowrap;
  padding: 0 3 0 3
  }
  </STYLE>
  END
  my $extra =<<"  END";
  padding: 1px;
  margin-top: 100px;
  margin-left: 37.5%;
  text-align: center;
  text-decoration: none;
  margin-right: 37.5%;
  #${module}_button A:visited, A:active, A:link {
  text-decoration: none;
  }
  #${module}_button A:hover {
  background:#0090D0;
  color:#0090D0;             
  }
   
  END
}

#+
# Routine to unset sticky toggle; not a display method per se, but placed
# here as it is a companion method to make_toggle_section
#-
sub unstickToggleSection {
  my $self = shift;
  my %args = @_;
  return unless $args{stuck_name};
  $self->deleteSessionAttribute( key => $args{stuck_name} );
}

#+
# Generates CSS, javascript, and HTML to render a section (DIV) 'toggleable'
# @narg content  - The actual content (generally HTML) to hide/show, required
# @narg visible  - default visiblity, orignal state of content (default is 0)
# @narg textlink - 0/1, should show/hide text be shown (default is 0)
# @narg imglink  - 0/1, should plus/minus widget be shown (default is 1)
# @narg name     - Name for this toggle thingy
# @narg sticky   - Remember the state of this toggle in session?  Requires name,
#                  defaults to 0 (false)
# @narg width    - Minimum width to reserve for hidden items.
#-
sub make_toggle_section {
  my $self = shift;
  my %args = @_;

  # Initialize some variables
  my $html = '';      # HTML string to return
  my $hidetext = '';  # Text for 'hide content' link
  my $showtext = '';  # Text for 'show content' link
  my $neuttext = '';  # Auxilary text for show/hide

  # No content, bail
  return $html unless $args{content};

  $args{imglink} = 1 unless defined $args{textlink};
  $args{textlink} = 0 unless defined $args{textlink};
  if ( $args{textlink} ) {
    $hidetext = ( $args{textlink} ) ? $args{hidetext} : ' hide ';
    $showtext = ( $args{textlink} ) ? $args{showtext} : ' show ' ;
    $neuttext = $args{neutraltext} if $args{neutraltext};
  }
  for my $i ( $hidetext, $showtext ) {
    $i = "<FONT COLOR=blue> $i </FONT>";
  }
      
  # Default visiblity is hidden
  $args{visible} = 0 unless defined $args{visible};

  my $set_cookie_code = '';

  # If it is a sticky cookie, we might have a cached value
  if ( $args{sticky} && $args{name} ) {
    $set_cookie_code =<<"    END";
      // Set cookie?
      make_sticky_toggle( div_name, new_appearance );
    END

    my $sticky_value = $self->getSessionAttribute( key => $args{name} );
    if ( $sticky_value ) {
      $args{visible} = ( $sticky_value eq 'visible' ) ? 1 : 0;
    }
  }

  $args{name} ||= $self->getRandomString( num_chars => 12,
                                          char_set => [ 'A'..'z' ]
                                        ); 
  
  my $hideclass = ( $args{visible} ) ? 'visible' : 'hidden';
  my $showclass = ( $args{visible} ) ? 'hidden'  : 'visible';
  my $initial_gif = ( $args{visible} ) ? 'small_gray_minus.gif'  
                                       : 'small_gray_plus.gif';


  # Add css/javascript iff necessary
  unless ( $self->{_toggle_section_exists} ) {
    $self->{_toggle_section_exists}++;
    $html =<<"    END"
    <STYLE TYPE="text/css" media="screen">
    div.visible {
    display: inline;
    white-space: nowrap;         
    }
    div.hidden {
    display: none;
    }
    </STYLE>
    <SCRIPT TYPE="text/javascript">
    function make_sticky_toggle( div_name, appearance ) {
      var cookie = document.cookie;
      var regex = new RegExp( "SBEAMSui=([^;]+)" );
      var match = regex.exec( cookie + ";" );
      var newval = div_name + "&" + appearance;
      var cookie = "";
      if ( match ) {
        cookie = match[0] + "&" + newval;
      } else { 
        cookie = "SBEAMSui=" + newval;
      }
      document.cookie = cookie;
    }
    function toggle_content(div_name) {
      
      // Grab page elements by their IDs
      var mtable = document.getElementById(div_name);
      var show = document.getElementById('showtext');
      var hide = document.getElementById('hidetext');
      var gif_file = div_name + "_gif";
      var tgif = document.getElementById(gif_file);

      var current_appearance = mtable.className;

      var new_appearance = 'hidden';
      if ( current_appearance == 'hidden' ) {
        new_appearance = 'visible';
      }

      // If hidden set visible, and vice versa
      if ( current_appearance == 'hidden' ) {
        $set_cookie_code;
        mtable.className = 'visible';
        if ( hide ) {
          hide.className = 'visible';
        }
        if ( show ) {
          show.className = 'hidden';
        }
        if ( tgif ) {
          tgif.src =  '$HTML_BASE_DIR/images/small_gray_minus.gif'
        }
      } else {
        $set_cookie_code;
        mtable.className = 'hidden';
        if ( hide ) {
          hide.className = 'hidden';
        }
        if ( show ) {
          show.className = 'visible';
        }
        if ( tgif ) {
          tgif.src =  '$HTML_BASE_DIR/images/small_gray_plus.gif'
        }
      }
    }
    </SCRIPT>
    END
  }

  my $width = ( !$args{width} ) ? '' :
    "<IMG SRC=$HTML_BASE_DIR/images/clear.gif WIDTH=$args{width} HEIGHT=2>";

  $html .=<<"  END";
     $width
    <DIV ID=$args{name} class="$hideclass"> $args{content} </DIV>
  END

  my $tip = ( $args{tooltip} ) ? "TITLE='$args{tooltip}'" : '';
  my $imghtml = '';
  if ($args{imglink} ) {
    $imghtml = "<IMG ID='$args{name}_gif' $tip SRC='$HTML_BASE_DIR/images/$initial_gif'>"; 
  }
  my $texthtml = '';
  if ( $args{textlink} ) {
    $texthtml = "<DIV ID=hidetext class='$hideclass'> $hidetext </DIV>";
    $texthtml .= "<DIV ID=showtext class='$showclass'> $showtext </DIV>";
  }

  my $linkhtml = qq~<A ONCLICK="toggle_content('${args{name}}')">$imghtml $texthtml</A> $neuttext~;

  # Return html as separate content/widget, or as a concatentated thingy
  return wantarray ? ( $html, $linkhtml ) : $linkhtml . $html;
}


#+
# Generates CSS, javascript, and HTML to render table row or column 'toggleable'
# @narg visible  - default visiblity, orignal state of content (default is 0)
# @narg textlink - 0/1, should show/hide text be shown (default is 0)
# @narg imglink  - 0/1, should plus/minus widget be shown (default is 1)
# @narg name     - Name for this toggle thingy
# @narg tooltip  - Help text to display on image link 
# @narg sticky   - Remember the state of this toggle in session?  Requires name,
#                  defaults to 0 (false)
#-
sub make_table_toggle {
  my $self = shift;
  my %args = @_;

  # Initialize some variables
  my $html = '';      # HTML string to return
  my $hidetext = '';  # Text for 'hide content' link
  my $showtext = '';  # Text for 'show content' link
  my $neuttext = '';  # Auxilary text for show/hide

  $args{imglink} = 1 unless defined $args{textlink};
  $args{textlink} = 0 unless defined $args{textlink};
  if ( $args{textlink} ) {
    $hidetext = ( $args{textlink} ) ? $args{hidetext} : ' hide ';
    $showtext = ( $args{textlink} ) ? $args{showtext} : ' show ' ;
    $neuttext = $args{neutraltext} if $args{neutraltext};
  }
  for my $i ( $hidetext, $showtext ) {
    $i = "<FONT COLOR=blue> $i </FONT>";
  }
      
  # Default visiblity is hidden
  $args{visible} = 0 unless defined $args{visible};

  my $set_cookie_code = '';

  # If it is a sticky cookie, we might have a cached value
  if ( $args{sticky} && $args{name} ) {
    $set_cookie_code =<<"    END";
      // Set cookie?
      make_sticky_tbl_toggle( obj_name, new_state );
    END

    my $sticky_value = $self->getSessionAttribute( key => $args{name} );
    if ( $sticky_value ) {
      $args{visible} = ( $sticky_value eq 'tbl_visible' ) ? 1 : 0;
    }
  }

  $args{name} ||= $self->getRandomString( num_chars => 12,
                                          char_set => [ 'A'..'z' ]
                                        ); 
  
  my $hideclass = ( $args{visible} ) ? 'tbl_visible' : 'tbl_hidden';
  my $showclass = ( $args{visible} ) ? 'tbl_hidden'  : 'tbl_visible';
  my $initial_gif = ( $args{visible} ) ? 'small_gray_minus.gif'  
                                       : 'small_gray_plus.gif';


  # Add css/javascript iff necessary
  unless ( $self->{_tbl_toggle_section_exists} ) {
    $self->{_tbl_toggle_section_exists}++;
    $html =<<"    END";
    <STYLE TYPE="text/css" media="screen">
    tr.tbl_visible { display: table-row; }
    tr.tbl_hidden { display: none; }
    td.tbl_visible { display: table-cell; }
    td.tbl_hidden { display: none; }
    </STYLE>
    <SCRIPT TYPE="text/javascript">
    function make_sticky_tbl_toggle( obj_name, appearance ) {
      var cookie = document.cookie;
      var regex = new RegExp( "SBEAMSui=([^;]+)" );
      var match = regex.exec( cookie + ";" );
      var newval = obj_name + "&" + appearance;
      var cookie = "";
      if ( match ) {
        cookie = match[0] + "&" + newval;
      } else { 
        cookie = "SBEAMSui=" + newval;
      }
      document.cookie = cookie;
    }

    function toggle_tbl(obj_name) {
      
      // Grab page elements by their IDs
      var gif_file = obj_name + "_gif";
      var tgif = document.getElementById(gif_file);
      var tbl_obj = document.getElementsByName( obj_name );

      for (var i=0; i < tbl_obj.length; i++) {
        var current_state = tbl_obj[i].className;
        var new_state = 'none';
        if ( current_state == 'tbl_hidden' ) {
          new_state = 'tbl_visible';
          if ( tgif ) {
            tgif.src =  '$HTML_BASE_DIR/images/small_gray_minus.gif'
          }
        } else if (  current_state == 'tbl_visible' ) {
          new_state = 'tbl_hidden';
          if ( tgif ) {
            tgif.src =  '$HTML_BASE_DIR/images/small_gray_plus.gif'
          }
        }
        tbl_obj[i].className = new_state;
      }
      $set_cookie_code
    }
    </SCRIPT>
    END


    # Put this here for expediency.  If it causes trouble we can cat it 
    # together with one of the other returned items.
    print $html if $self->output_mode() =~ /html/i;
  }

  # Set up the TR/TD attributes
  my $tbl_html .= "NAME=$args{name} ID=$args{name} ";
  
  # Image isn't hidden, it is switched in the javascript
  my $imghtml = '';
  if ( $args{imglink} ) {
    my $tip = ( $args{tooltip} ) ? "TITLE='$args{tooltip}'" : '';
    $imghtml = "<IMG ID='$args{name}_gif' $tip SRC='$HTML_BASE_DIR/images/$initial_gif'>"; 
  }

  # The show/hide text is in two opposite toggling sections 
  my $texthtml = '';
  if ( $args{textlink} ) {
    $texthtml = "<TD $tbl_html CLASS=$hideclass>$hidetext</TD><TD $tbl_html CLASS=$showclass>$showtext</TD>";
  }
  
  $tbl_html .= "CLASS='$hideclass'";


  my $linkhtml = ( $texthtml ) ?  
        qq~<A ONCLICK="toggle_tbl('${args{name}}');"><TABLE><TR><TD>$imghtml</TD>$texthtml </TR></TABLE></A> $neuttext~ : 
        qq~<A ONCLICK="toggle_tbl('${args{name}}');">$imghtml</A> ~;

  # Return html as separate content/widget, or as a concatentated thingy
  return wantarray ? ( $tbl_html, $linkhtml ) : $linkhtml . $tbl_html;

  
}

############

sub getGifSpacer {
  my $self = shift;
  my $size = shift || 120;  # Default?
  return "<IMG SRC=$HTML_BASE_DIR/images/clear.gif WIDTH=$size HEIGHT=2>";
}

sub truncateStringWithMouseover {
  my $self = shift;
  my %args = @_;
  return undef unless $args{string};
  my $string = $args{string};
  my $len = $args{len} || 35;
  my $shorty = $self->truncateString( %args );
  return qq~<DIV TITLE="$string">$shorty</DIV>~;
}
#+
# Returns array of HTML form buttons
#
# arg types    arrayref, required, values of submit, back, reset
# arg name     name of submit button (if any)
# arg value    value of submit button (if any)
# arg back_name     name of submit button (if any)
# arg back_value    value of submit button (if any)
# arg reset_value    value of reset button (if any)
#-
sub getFormButtons {
  my $this = shift;
  my %args = @_;
  $args{name} ||= 'Submit';
  $args{value} ||= 'Submit';
  $args{onclick} ||= '';

  $args{back_name} ||= 'Back';
  $args{back_value} ||= 'Back';
  $args{back_onclick} ||= '';

  $args{reset_value} ||= 'Reset';
  $args{reset_onclick} ||= '';

  for ( qw( reset_onclick back_onclick onclick ) ) {
    $args{$_} = "onClick=$args{$_}" if $args{$_};
  }
  
  $args{types} ||= [];

  my @b;

  for my $type ( @{$args{types}} ) {
    push @b, <<"    END" if $type =~ /^submit$/i; 
    <INPUT TYPE=SUBMIT NAME='$args{name}' VALUE='$args{value}' $args{onclick}>
    END
    push @b, <<"    END" if $type =~ /^back$/i; 
    <INPUT TYPE=SUBMIT NAME=$args{back_name} VALUE=$args{back_value} $args{back_onclick}>
    END
    push @b, <<"    END" if $type =~ /^reset$/i; 
    <INPUT TYPE=RESET VALUE=$args{reset_value} $args{reset_onclick}>
    END
  }
  return @b;
}

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


