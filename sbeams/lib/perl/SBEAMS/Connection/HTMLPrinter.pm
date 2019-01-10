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
# SBEAMS is Copyright (C) 2000-2014 Institute for Systems Biology
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
  my $loadscript = ( $args{onload} ) ? $args{onload} : 
                   ( $args{sort_tables} ) ? 'sortables_init()' : 
                                               "self.focus()"; 

  #### If the output mode is interactive text, display text header
  if ($self->output_mode() eq 'interactive') {
    $self->printTextHeader();
    return;
  }

  #### If the output mode is not html, then we don't need the rest
  return unless $self->output_mode() eq 'html';

  my $http_header = $self->get_http_header( $self->get_output_mode() );
  print $http_header;

  my $doctype = '<!DOCTYPE HTML>' . "\n";
  $doctype = '' unless $args{show_doctype}; 
    
  print qq~
	$doctype<HTML><HEAD>
	<TITLE>$DBTITLE - Systems Biology Experiment Analysis Management System</TITLE>
  ~;


  print getSortableHTML() if $args{sort_table};
  
  #### Only send Javascript functions if the full header desired
  unless ($minimal_header eq "YES") {
    $self->printJavascriptFunctions();
  }

  #### Send the style sheet
  $self->printStyleSheet();

  #### Determine the Title bar background decoration
  my $header_bkg = "bgcolor=\"$BGCOLOR\"";
  $header_bkg = "background=\"$HTML_BASE_DIR/images/plaintop.jpg\"" if ($DBVERSION =~ /Primary/ );

  print qq~
	<!--META HTTP-EQUIV="Expires" CONTENT="Fri, Jun 12 1981 08:20:00 GMT"-->
	<!--META HTTP-EQUIV="Pragma" CONTENT="no-cache"-->
	<!--META HTTP-EQUIV="Cache-Control" CONTENT="no-cache"-->
	</HEAD>

	<!-- Background white, links blue (unvisited), navy (visited), red (active) -->
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" TOPMARGIN=0 LEFTMARGIN=0 OnLoad="$loadscript;">
	<table border=0 width="100%" cellspacing=0 cellpadding=1>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td bgcolor="$BARCOLOR"><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmlclear.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmlclear.gif"></a></td>
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
  my %args = @_;

  my $FONT_SIZE_SM=8;
  my $FONT_SIZE=9;
  my $FONT_SIZE_MED=12;
  my $FONT_SIZE_LG=12;
  my $FONT_SIZE_HG=14;

  if ( $HTTP_USER_AGENT =~ /Mozilla\/4.+X11/ ) {
    $FONT_SIZE_SM=11;
    $FONT_SIZE=12;
    $FONT_SIZE_MED=13;
    $FONT_SIZE_LG=14;
    $FONT_SIZE_HG=19;
  }
#	A.sortheader{background-color: #888888; font-size: ${FONT_SIZE}pt; font-weight: bold; color:white; line-height: 25px;}

my $module_styles =<<"  END_STYLE";
  .sortarrow { font-size: ${FONT_SIZE_LG}pt; font-weight: bold }
  .sortheader{ font-size: ${FONT_SIZE}pt; font-weight: bold; color:white; }
  .sortheader th   { font-weight: bold; padding: 5px 12px; }
  .info_box { background: #F0F0F0; border: #000 1px solid; padding: 4px; width: 80%; color: #444444 }
  .small_super_text { vertical-align: super; font-size: ${FONT_SIZE_SM}pt }
  .clear_info_box { border: #000 1px solid; padding: 4px; width: 100%; color: #444444 }
  .nowrap_clear_info_box { border: #000 1px solid; padding: 4px; width: 100%; white-space: nowrap; color: #444444 }
  .clear_warning_box { border: #F03 1px solid; padding: 4px; width: 80%; color: #444444 }
  .popup_help { cursor: Help; color:#444444; background-color: #E0E0E0 }
  .gaggle-data { display: none }
  .bold_text { font-weight: bold; white-space: nowrap }
  .nowrap_text { white-space: nowrap }
  a.dataheader { font-weight: bold; text-decoration:none; }
  a.dataheader:hover { color:b00; }
  .dataheader { font-weight: bold; color:white }

  /* Style info below organized by originating module
  /* Peptide Atlas */
  .cellblock_top { border-top:"1px solid"; border-color:black; border-left:"1px solid"; border-right:"1px solid"}
  .cellblock_bottom { border-bottom:thin solid; border-color:black; border-left:thin solid; border-right:thin solid}
  .cellblock { border-color:black; border-left:thin solid; border-right:thin solid}
  .small_form_field {    font-family: Verdana, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE_SM}pt; color: #000000; background-color: #FFFFCC; padding: 1px; height: 16px; border: 1px solid #7F9DB9 }  
  .small_form_text {    font-family: Verdana, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE_SM}pt; }
  .small_form_caption {    font-family: Verdana, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE_SM}pt; font-weight: bold; }
  .pseudo_link    {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration:none; color: blue; CURSOR: help;}
  .white_bg{background-color: #FFFFFF }
  .grey_bg{ background-color: #CCCCCC }
  .bold_italic_text{font-weight:bold;font-style:italic}
  .bold_red_italic_text{font-weight:bold;font-style:italic;color:red}
  .inactive_text {color:#AAAAAA}
  .med_gray_bg{ background-color: #CCCCCC; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; Padding:2}
  .grey_header{ font-family: Helvetica, Arial, sans-serif; color: #000000; font-size: ${FONT_SIZE_HG}pt; background-color: #CCCCCC; font-weight: bold; padding:1 2}
  .section_description{ font-family: Helvetica, Arial, sans-serif; color: #666666; font-size: ${FONT_SIZE_HG}pt; font-weight: bold; padding:1}
  .rev_gray{background-color: #555555; font-size: ${FONT_SIZE_MED}pt; font-weight: bold; color:white; line-height: 25px;}
  .rev_gray_head{background-color: #888888; font-size: ${FONT_SIZE}pt; font-weight: bold; color:white; line-height: 25px;}
  .blue_bg{ font-family: Helvetica, Arial, sans-serif; background-color: #4455cc; font-size: ${FONT_SIZE_HG}pt; font-weight: bold; color: white}
  .pa_predicted_pep{ background-color: lightcyan; font-size: ${FONT_SIZE}pt; font-family:courier; letter-spacing:0.5;	border-style: solid; border-width: 0.1px; border-color: black }
  .spaced_text { line-height: 1.2em; }
  .spaced_text SUB, .spaced SUP { line-height: 1; }
  .aa_mod { vertical-align: top; font-size: ${FONT_SIZE}; color: darkslategray }

  .pa_sequence_font{font-family:courier; font-size: ${FONT_SIZE}pt;  letter-spacing:0.5; font-weight: bold; }	
  .pa_observed_sequence{font-family:courier; font-size: ${FONT_SIZE}pt; color: red;  letter-spacing:0.5; font-weight: bold;}	
  .pa_sequence_counter{font-size:smaller;color:#ccc;}

  .pa_snp_font{font-family:courier; font-size: ${FONT_SIZE}pt; letter-spacing:0.5; font-weight: bold; background-color: #66CCFF}	
  .pa_snp_obs_font{font-family:courier; font-size: ${FONT_SIZE}pt; letter-spacing:0.5; font-weight: bold; color: #00CC00}	
  .pa_snp_medium_font{font-family:courier; font-size: ${FONT_SIZE}pt; letter-spacing:0.5; font-weight: bold; color: #CCCC00}	
  .pa_snp_warn_font{font-family:courier; font-size: ${FONT_SIZE}pt; letter-spacing:0.5; font-weight: bold; color: #CC0000}	

  .pa_acetylated_font{font-family:courier; font-size: ${FONT_SIZE}pt; letter-spacing:0.5; font-weight: bold; background-color: #FFCC66}	
  .pa_phospho_font{font-family:courier; font-size: ${FONT_SIZE}pt; letter-spacing:0.5; font-weight: bold; background-color: #009966}	
  .pa_modified_aa_font{font-family:courier; font-size: ${FONT_SIZE}pt; letter-spacing:0.5; font-weight: bold; background-color: #999999}	
  .pa_glycosite{ background-color: #EE9999; border-style: solid; font-size: ${FONT_SIZE}pt; font-family:courier; border-width: 0px; letter-spacing:0.5 }	

  .section_heading {  font-family: Helvetica, Arial, sans-serif; font-size: 10pt; font-weight: Bold; }
  .description { font-family: Helvetica, Arial, sans-serif; color:#333333; font-size: 9pt; font-style: italic;  }
  .help_key {  font-family: Helvetica, Arial, sans-serif; font-size: 9pt; font-weight: Bold; }
  .help_val {  font-family: Helvetica, Arial, sans-serif; font-size: 9pt; }
  .plot_caption {  font-family: Helvetica, Arial, sans-serif; font-size: 12pt; }

  .left_text { text-align: left }
  .center_text { text-align: center }
  .right_text { text-align: right }
  .header_text { color: white; text-align: left }
  .topbound_text { vertical-align: top }
  .clustal_dummy_wrap {width: 900px; overflow-x: scroll; overflow-y:hidden; height: 20px;}
  .clustal_wrap {width: 900px; overflow-x: scroll; overflow-y:hidden; height: 200px;}
  .clustal_dummy {width:1000px; height: 20px; }
  .clustalx {width:1000px; }
  .clustal {width: 1000px; overflow-x: scroll; scrollbar-arrow-color: blue; scrollbar- face-color: #e7e7e7; scrollbar-3dlight-color: #a0a0a0; scrollbar-darkshadow-color: #888888}
  .clustal_peptide {width: 1000px; height: 400px; overflow-x: scroll; overflow-y: scroll; scrollbar-arrow-color: blue; scrollbar- face-color: #e7e7e7; scrollbar-3dlight-color: #a0a0a0; scrollbar-darkshadow-color: #888888}
  .fade_header { background-image: url($HTML_BASE_DIR/images/fade_orange_header_2.png); background-repeat: no-repeat }

  /* Glycopeptide */
  .blue_bg_glyco{ font-family: Helvetica, Arial, sans-serif; background-color: #4455cc; font-size: ${FONT_SIZE_MED}pt; font-weight: bold; color: white}
  .identified_pep{ background-color: #882222; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; letter-spacing:0.5;	color:white; Padding:1; border-style: solid; border-left-width: 1px; border-right-width: 1px; border-top-width: 1px; border-left-color: #eeeeee; border-right-color: #eeeeee; border-top-color: #aaaaaa; border-bottom-color:#aaaaaa; }
  .predicted_pep{ background-color: #FFCC66; font-size: ${FONT_SIZE_LG}pt; font-family:courier; font-weight: bold; letter-spacing:0.5;	border-style: solid; border-width: 1px; border-right-color: blue ; border-left-color:  red ; }
  .sseq{ background-color: #CCCCFF; font-size: ${FONT_SIZE_LG}pt; font-weight: bold}
  .tmhmm{ background-color: #CCFFCC; font-size: ${FONT_SIZE}pt; font-weight: bold; text-decoration:underline}
  .instruction_text{ font-size: ${FONT_SIZE_LG}pt; font-weight: bold}
  .sequence_font{font-family:courier; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; letter-spacing:0.5}	
  .obs_seq_font{font-family:courier; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; letter-spacing:0.5; color: red }	
  .sec_obs_seq_font{font-family:courier; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; letter-spacing:0.5; color: green }	
  .obs_seq_bg_font{font-family:courier; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; letter-spacing:0.5; background-color: lightskyblue }	
  .sec_obs_seq_bg_font{font-family:courier; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; letter-spacing:0.5; background-color: springgreen }	

table.freeze_table { table-layout: fixed; width: 1000px; *margin-left: -100px;/*ie7*/}
     .freeze_table td { vertical-align: top; width:100px;  }
     .freeze_table th {  position:absolute; *position: relative; /*ie7*/ left:0; width:100px;  }

  /* Phosphopep */
  .invalid_parameter_value  {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_LG}pt; text-decoration: none; color: #FC0; font-style: Oblique; }
  .missing_required_parameter  {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_LG}pt; text-decoration: none; color: #F03; font-style: Italic; }
  .section_title  {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_HG}pt; text-decoration: none; color: #090; font-style: Normal; }

  /* Microarray */
  .lite_blue_bg{font-family: Helvetica, Arial, sans-serif; background-color: #eeeeff; font-size: ${FONT_SIZE_HG}pt; color: #cc1111; font-weight: bold;border-style: solid; border-width: 1px; border-color: #555555 #cccccc #cccccc #555555;}
  .orange_bg{ background-color: #FFCC66; font-size: ${FONT_SIZE_LG}pt; font-weight: bold}
  .red_bg{ background-color: #882222; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; color:white; Padding:2}

  td.grn_bg{ background-color: #00FF00; font-size: ${FONT_SIZE}pt;}
  td.yel_bg{ background-color: #FFFF00; font-size: ${FONT_SIZE}pt;}
  td.red_bg{ background-color: #FF0000; font-size: ${FONT_SIZE}pt; }

  .small_cell {font-size: 8; background-color: #CCCCCC; white-space: nowrap  }
  .med_cell {font-size: 10; background-color: #CCCCCC; white-space: nowrap  }
  .anno_cell {white-space: nowrap  }
  .present_cell{border: none}
  .marginal_cell{border: 1px solid #0033CC}
  .absent_cell{border: 2px solid #660033}
  .small_text{font-family: Helvetica,Arial,sans-serif; font-size:x-small; color:#aaaaaa}
  .table_setup{border: 0px ; border-collapse: collapse;   }
  .pad_cell{padding:5px;  }
  .white_hyper_text{font-family: Helvetica,Arial,sans-serif; color:#000000;}
  .white_text    {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: underline; color: white; CURSOR: help;}
  .white_text_head {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: underline; color: white; CURSOR: help;}
  
  div.visible { display: inline; white-space: nowrap;         }
  div.visilink { color: blue; display: inline; white-space: nowrap;         }
  div.hidden { display: none; }
  span.visible { display: inline; white-space: nowrap;         }
  span.hidden { display: none; }
  table.tbl_visible { display: table; }
  table.tbl_hidden { display: none; }
  tr.tbl_visible { display: table-row; }
  .hoverabletitle { margin-top: 8px; background:#f3f1e4; color:#555; font-size:large; font-weight:bold; border-top:1px solid #b00; border-left:15px solid #b00; padding:0.5em}
  .hoverabletitle:hover { box-shadow:0 3px 5px 3px #aaa;}
  tr.hoverable:hover td { background:#ffad4e; }
  td.key   { border-bottom:1px solid #ddd; background:#d3d1c4;}
  td.value { border-bottom:1px solid #ddd; }
  tr.tbl_hidden { display: none; }
  td.tbl_visible { display: table-cell; }
  td.tbl_hidden { display: none; }
  END_STYLE

  if ( $args{module_only} ) {
    return <<"    END";
    <style type="text/css">
    $module_styles
    </style>
    END
  }

  my $complete_style = qq~
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
	A:link    {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: none; }
	A:visited {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: none; }
	A:hover   {  font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration: underline; color: red}
	A:link.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	A:visited.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	A:hover.nav {  font-family: Helvetica, Arial, sans-serif; color: red;}
	.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}

  $module_styles



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

	if ( $args{return_style_html} ) {
		return $complete_style;
	} 
	print $complete_style;


  my $agent = $q->user_agent();
  # Style for turning text sideways for vertical printing, MSIE only
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
	<script language="JavaScript" type="text/javascript">
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
        </script>
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
	  <td><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmlclear.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmlclear.gif"></a></td>
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

  # Have to fish for error file, since we are using Carp (can't pass sbeams
  # object ).  
	my $errfile = 'Error-' . getppid();
	my $is_error = 0;
	if ( $self->doesSBEAMSTempFileExist( filename => $errfile ) ) {
	  $self->deleteSBEAMSTempFile( filename => $errfile );
		$is_error++;
	}

	my $error_status = ( $is_error ) ? '<!--SBEAMS_PAGE_ERROR-->' : '<!--SBEAMS_PAGE_OK-->';

  print qq~
	<BR>
	<HR SIZE="2" NOSHADE WIDTH="35%" ALIGN="LEFT" color="#FF8700">
	<TABLE>
	<TR>
	  <TD><IMG SRC="$HTML_BASE_DIR/images/sbeamstinywhite.png"></TD>
	  <TD class='small_text'>SBEAMS$module_name&nbsp;&nbsp;&nbsp;$SBEAMS_VERSION<BR>
              &copy; 2000-2008 Institute for Systems Biology<TD>
	  <TD><IMG SRC="$HTML_BASE_DIR/images/isbtinywhite.png"></TD>
	</TR>
	</TABLE>
	$error_status
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
#  print $self->get_http_header;

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
  $tabmenu->addTab( label    => 'Related Files',
                    helptext => 'Add/View files of any type associated with this project' );

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

  } elsif ( $tabmenu->getActiveTabName() eq 'Related Files' ){

    $content = $self->getProjectFiles();

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
  my $force = $args{force_header} || 0;

  #### If invocation_mode is HTTP, then printout an HTML message
  if ($self->invocation_mode() =~ /https*/ && $self->output_mode() eq 'html') {
    print "<H4>$state: ";
    print "$type<BR>\n" if ($type);
    if ($HTML_message) {
      print "$HTML_message</H4>\n";
    } else {
      print "$message</H4>\n";
    }
    return;
  } else {
		print STDERR "going to handle the error\n";
    $self->handle_error( state => $args{state}, 
                   error_type  => lc($args{type}),
                       message => $args{message},
                  force_header => $force );
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
  my $text = shift || 'n/a';
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
# Utility method, returns text formatted for Error messages
#-
sub makeErrorText {
  my $self = shift;
  my $text = shift;
  return( "<I><FONT COLOR=#FF0000>$text</FONT></I>" );
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
                 json => 'application/json',
                force => 'application/force-download',
                octet => 'application/octet-stream',
                 jpg  => 'image/jpeg',
                 png  => 'image/png',
                 jnlp => 'application/x-java-jnlp-file',
            cytoscape => 'application/x-java-jnlp-file'
               );
  return $ctypes{$type};
}

sub getXMLEncodingStatement {
  my $encoding = qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
  return $encoding;
}

sub getTableXML {
  my $self = shift;
  my %args = @_;
  for my $k ( qw(table_name col_names col_values ) ) {
    return unless defined $args{$k};
  }
  my $xml =<<"  XML";
<?xml version="1.0" standalone="yes"?>
<data>
  XML

# Adapted to use encodeXMLEntity routine, below
#  $xml .= "   <$args{table_name}";
#  for ( my $i = 0; $i < scalar(@{$args{col_names}} ); $i++ ) {
#    my $evalue = $self->escapeXML( value => $args{col_values}->[$i] );
#    $xml .= qq/ $args{col_names}->[$i]="$evalue"/;
#  }

  my %attrs;
  @attrs{@{$args{col_names}}} = @{$args{col_values}};
  $xml .= $self->encodeXMLEntity( entity_name => $args{table_name},
                                  entity_type => 'openclose',
                                 stack_indent => 1,
                                   attributes => \%attrs ) . "\n";
  
  $xml .= "</data>\n";
  return $xml;
}

###############################################################################
# encodeXMLEntity
# 
# creates a block of nicely formatted XML for a given entity and its associated
# attributes
#
# @narg entity_name  - Required, name of XML entity
# @narg indent       - Number of spaces to indent, default 0
# @narg attributes   - Reference to hash of attributes
# @narg entity_type  - Type of XML tag, one of open, openclose, or close.  If 
#                      type is close, will ensure that this is correct tag to 
#                      close (on top of the entity stack). default openclose
# @narg compact      - Write attributes compactly (space delim), default 0
# @narg stack_indent - Indent based on the depth of entity stack, default 0
# @narg escape_vals  - Escape problem characters in attribute values ("<>'&)
#                      default 1 (true)
# 
###############################################################################
sub encodeXMLEntity {
  my $self = shift;
  my %args = @_;
  my $entity_name = $args{'entity_name'} || die("No entity_name provided");
  my $indent = $args{'indent'} || 0;
  my $entity_type = $args{'entity_type'} || 'openclose';
  my $attributes = $args{'attributes'} || {};
  $args{stack_indent} || 0;
  $args{escape_vals} = 0 if !defined $args{escape_vals};

  #### Define a string from which to get padding
  my $padstring = '                                                       ';
  my $compact = $args{compact} || 0;
  my $vindent = 8;  # Amount to indent attributes relative to entity 

  #### Define a stack to make user we are nesting correctly
  our @xml_entity_stack;
  if ( !defined $args{indent} && $args{stack_indent} ) {
    $indent = scalar(@xml_entity_stack);
  }

  #### Close tag
  if ($entity_type eq 'close') {

    #### Verify that the correct item was on top of the stack
    my $top_entity = pop(@xml_entity_stack);
    if ($top_entity ne $entity_name) {
      die("ERROR forming XML: Was told to close <$entity_name>, but ".
          "<$top_entity> was on top of the stack!");
    }
    return substr($padstring,0,$indent)."</$entity_name>\n";
  }

  #### Else this is an open tag
  my $buffer = substr($padstring,0,$indent)."<$entity_name";


  #### encode the attribute values if any
  while (my ($name,$value) = each %{$attributes}) {
    if ( defined $value ) {
      $value = $self->escapeXML( value => $value );
      if ($compact) {
        $buffer .= qq~ $name="$value"~;
      } else {
        $buffer .= "\n".substr($padstring,0,$indent+$vindent).qq~$name="$value"~;
      }
    }
  }

  #### If an open and close tag, write the trailing /
  if ($entity_type eq 'openclose') {
    $buffer .= "/";

  #### Otherwise push the entity on our stack
  } else {
    push(@xml_entity_stack,$entity_name);
  }


  $buffer .= ">\n";

  return($buffer);

} # end encodeXMLEntity

sub escapeXML {
  my $self = shift;
  my %args = @_;
  return '' unless defined $args{value};
  $args{value} =~ s/\&/&amp;/gm;
  $args{value} =~ s/\</&lt;g/gm;
  $args{value} =~ s/\>/&gt;/gm;
  $args{value} =~ s/"/&quot;/gm;
  $args{value} =~ s/'/&apos;/gm;
  return $args{value};
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

#	print STDERR "Browser is $HTTP_USER_AGENT\n";
  unless ( $self->{_host_logged} ) {
    $log->debug( "Host is $ENV{REMOTE_HOST}" ) if $ENV{REMOTE_HOST};
    $log->debug( "Addr is $ENV{REMOTE_ADDR}" ) if $ENV{REMOTE_ADDR};
    $self->{_host_logged}++;
  }
	my $host = $ENV{REMOTE_HOST} || $ENV{REMOTE_ADDR};

  my @dhost;
	my %dhost;
	for my $hoststring ( split( ",", $CONFIG_SETTING{DELAYED_RESPONSE_HOST} ) ) {
		my ( $dhost, $dtime ) = split( "::::", $hoststring );
		push @dhost, $dhost;
		$dhost{$dhost} = $dtime;
	}

	if ( !$self->{_delay_imposed} && grep /^$host$/, @dhost ) {
 	  $log->warn( "Access delayed by policy for $host, agent $HTTP_USER_AGENT" );
		sleep $dhost{$host};
 	  $log->warn( "Slept $dhost{$host} seconds" );
		$self->{_delay_imposed}++;
	}

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
  } 
	if ( $args{filename} ) {
    $param_hash{'Content-Disposition'}="attachment;filename=$args{filename}";
#    $header = $q->header( -type => $type );
  } else {
#    $header = $q->header( -type => $type );
  }
#  use Data::Dumper;
#  die Dumper( %param_hash );

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
  if ( !defined $q ) {
    use CGI qw(-no_debug);
    $q = new CGI;
  }
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
                 SolexaTrans => '#66CCFF',
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
# @narg showimg  - optional image to be shown whilst content is hiding, defaults to minus
# @narg hideimg  - optional image to be shown whilst content is showing, defaults to plus
# @narg name     - Name for this toggle thingy
# @narg sticky   - Remember the state of this toggle in session?  Requires name,
#                  defaults to 0 (false)
# @narg width    - Minimum width to reserve for hidden items.
# @narg barlink  - 0/1, should use new-style clickable bar to show/hide (default is 0)
# @narg opendiv  - 0/1, should the <DIV> tag remain open to allow more content addition
#                  NOTE: must close </DIV> after caller (default is 0)

#-
sub make_toggle_section {
  my $self = shift;
  my %args = @_;

  # Initialize some variables
  my $html = '';      # HTML string to return
  my $hidetext = '';  # Text for 'hide content' link
  my $showtext = '';  # Text for 'show content' link
  my $neuttext = '';  # Auxiliary text for show/hide -- also: text shown for "bar" link
  my $hideimg = ( $args{hideimg} ) ? $args{hideimg} : 'small_gray_plus.gif';  # image for 'hide content' link
  my $showimg = ( $args{showimg} ) ? $args{showimg} : 'small_gray_minus.gif';  # image for 'show content' link

  # No content, bail
  return $html unless $args{content};

  $args{barlink} = 0 unless defined $args{barlink};
  $args{opendiv} = 0 unless defined $args{opendiv};
  $args{imglink} = 1 unless defined $args{textlink};
  $args{textlink} = 0 unless defined $args{textlink};
  if ( $args{textlink} ) {
    $hidetext = ( $args{textlink} ) ? $args{hidetext} : ' hide ';
    $showtext = ( $args{textlink} ) ? $args{showtext} : ' show ';
  }
  $neuttext = $args{neutraltext} if $args{neutraltext};
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
  my $initial_gif = ( $args{visible} ) ? $showimg : $hideimg;  


  # Add css/javascript iff necessary
  unless ( $self->{_toggle_section_exists} ) {
    $self->{_toggle_section_exists}++;
    $html =<<"    END"
    <style TYPE="text/css" media="all"> 
    div.visible { display: inline; white-space: nowrap; }
    div.hidden { display: none; }
    </style>

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
      var show = document.getElementById( div_name + 'showtext');
      var hide = document.getElementById( div_name + 'hidetext');
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
          var regex = new RegExp( ".*small_gray_plus.gif" );
          var match = regex.exec( tgif.src );
          if ( match ) {
            tgif.src = "$HTML_BASE_DIR/images/small_gray_minus.gif"; 
          } else {
            tgif.src =  '$HTML_BASE_DIR/images/$showimg'
          }
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
          var regex = new RegExp( ".*small_gray_minus.gif" );
          var match = regex.exec( tgif.src );
          if ( match ) {
            tgif.src = "$HTML_BASE_DIR/images/small_gray_plus.gif"; 
          } else {
            tgif.src =  '$HTML_BASE_DIR/images/$hideimg'
          }
        }
      }
    }
    </SCRIPT>
    END
  }

  my $width = ( !$args{width} ) ? '' :
    "<IMG SRC=$HTML_BASE_DIR/images/clear.gif WIDTH=$args{width} HEIGHT=2>";

  my $closediv = $args{opendiv} ? '' : '</DIV>';

  $html .=<<"  END";
     $width
    <DIV ID=$args{name} class="$hideclass"> $args{content} $closediv
  END

  my $tip = ( $args{tooltip} ) ? "TITLE='$args{tooltip}'" : '';
  my $imghtml = '';
  if ( $args{imglink} ) {
    $imghtml = "<IMG ID='$args{name}_gif' $tip SRC='$HTML_BASE_DIR/images/$initial_gif'>"; 
  }
  my $texthtml = '';
  if ( $args{textlink} ) {
    $texthtml = "<DIV ID=$args{name}hidetext class='$hideclass'> $hidetext </DIV>";
    $texthtml .= "<DIV ID=$args{name}showtext class='$showclass'> $showtext </DIV>";
  }


  my $linkhtml = '';

  $args{anchor} ||= $args{neutraltext};
  my $anchor = ( $args{anchor} ) ? "<A NAME='$args{anchor}'></A>" : '';
  if ( $args{no_toggle} ) {
    $linkhtml = qq~$anchor<DIV CLASS="hoverabletitle">$neuttext</DIV>~ ;
    return $linkhtml;
    
  }

  if ( $args{barlink} ) {

    my $toggle =  q~ONCLICK="toggle_content('${args{name}}')~;
#    my $toggle =  qq~ONCLICK="toggle_content('${args{name}}')>$imghtml"~;
#    $toggle = '>' if $args{no_toggle};

    $linkhtml = qq~$anchor<DIV CLASS="hoverabletitle" ONCLICK="toggle_content('${args{name}}')">$imghtml $texthtml $neuttext</DIV>~;

  }
  else {
    $linkhtml = qq~<A ONCLICK="toggle_content('${args{name}}')">$imghtml $texthtml</A> $neuttext~;
  }


  # Return html as separate content/widget, or as a concatentated thingy
  return wantarray ? ( $html, $linkhtml ) : $linkhtml . $html;
}

sub get_checkbox_toggle {
  my $self = shift;
  my %args = @_;
  for my $k ( qw(controller_name checkbox_name ) ) {
    return unless defined $args{$k};
  }

	my $script = qq~
	<INPUT TYPE=checkbox ID=$args{controller_name} ONCHANGE="$args{controller_name}_toggle_checkboxes($args{checkbox_name});return true;">
  <SCRIPT TYPE="text/javascript">
  function $args{controller_name}_toggle_checkboxes (checkbox_name) {
		var controller = document.getElementById( '$args{controller_name}' )
		controller.checked=false;

		var checkboxes = document.getElementsByName( '$args{checkbox_name}' )
    for (i = 0; i < checkboxes.length; i++) {
      checkboxes[i].checked = checkboxes[i].checked? false:true
		}
	}
	</SCRIPT>
  ~;
	$log->debug( $script );
	return $script;
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
  my $js_css = '';      # javascript/css string if necessary
  my $hidetext = '';  # Text for 'hide content' link
  my $showtext = '';  # Text for 'show content' link
  my $neuttext = '';  # Auxilary text for show/hide

  $args{plaintext} ||= 0;  # Don't have text in a table 

  
  my $hideimg = ( $args{hideimg} ) ? $args{hideimg} : 'small_gray_minus.gif';  # image for 'hide content' link
  my $showimg = ( $args{showimg} ) ? $args{showimg} : 'small_gray_plus.gif';  # image for 'show content' link

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
  my $initial_gif = ( $args{visible} ) ? $hideimg : $showimg;


  # Add css/javascript iff necessary
  unless ( $self->{_tbl_toggle_section_exists} ) {
    $self->{_tbl_toggle_section_exists}++;
    $js_css =<<"    END";
    <STYLE TYPE="text/css" media="all">
    table.tbl_visible { display: table; }
    table.tbl_hidden { display: none; }
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

      if ( tgif ) {
        var src = tgif.src;
        if ( src.match(/$hideimg/) ) {
          tgif.src =  '$HTML_BASE_DIR/images/$showimg'
        } else {
          tgif.src =  '$HTML_BASE_DIR/images/$hideimg'
        }
      } else {
//         This pops up if there is text but no image, not good.
//        alert( "It don't exist" );
      }


      var tbl_obj = document.getElementsByName( obj_name );

      for (var i=0; i < tbl_obj.length; i++) {
        var current_state = tbl_obj[i].className;
        var new_state = 'none';
        if ( current_state == 'tbl_hidden' ) {
          new_state = 'tbl_visible';
        } else if (  current_state == 'tbl_visible' ) {
          new_state = 'tbl_hidden';
        }
        tbl_obj[i].className = new_state;
      }
      $set_cookie_code
    }
    </SCRIPT>
    END


    # Put this here for expediency.  If it causes trouble we can cat it 
    # together with one of the other returned items.
    # Caused trouble if header hadn't printed.  
    # print $html if $self->output_mode() =~ /html/i;
  }

  # Set up the TR/TD attributes
  my $tbl_html = "NAME='$args{name}' ID='$args{name}' ";
  
  # Image isn't hidden, it is switched in the javascript
  my $imghtml = '';
  if ( $args{imglink} ) {
    my $tip = ( $args{tooltip} ) ? "TITLE='$args{tooltip}'" : '';
    $imghtml = "<IMG ID='$args{name}_gif' $tip SRC='$HTML_BASE_DIR/images/$initial_gif'>"; 
  }

  # The show/hide text is in two opposite toggling sections 
  my $texthtml = '';
  if ( $args{textlink} ) {
    if ( $args{plaintext} ) {
      $texthtml = "<DIV ID=${hideclass}hidetext CLASS=$hideclass>$hidetext</SPAN><SPAN CLASS=$showclass ID=${showclass}showtext>$showtext</SPAN>";
    } else {
      $texthtml = "<TD $tbl_html CLASS=$hideclass>$hidetext</TD><TD $tbl_html CLASS=$showclass>$showtext</TD>";
    }
  }
  
  $tbl_html .= "CLASS='$hideclass' ";


  my $linkhtml = '';
  if ( $texthtml ) {
    if ( !$args{plaintext} ) {
       $linkhtml = qq~<A ONCLICK="toggle_tbl('${args{name}}');"><TABLE><TR><TD>$imghtml</TD>$texthtml </TR></TABLE></A> $neuttext~; 
    } else {
       $linkhtml = qq~<A ONCLICK="toggle_tbl('${args{name}}');">$texthtml</A> $neuttext~;
    }
  } else {
    $linkhtml = qq~<A ONCLICK="toggle_tbl('${args{name}}');">$imghtml</A> ~;
  }

  $linkhtml = $js_css . $linkhtml;
  # Return html as separate content/widget, or as a concatentated thingy
  return wantarray ? ( $tbl_html, $linkhtml ) : $linkhtml . $tbl_html;

  
} # End make_table_toggle

#+
# returns clear gif of specified width, default 120px
#-
sub getGifSpacer {
  my $self = shift;
  my $size = shift || 120;  # Default?
  return "<IMG SRC=$HTML_BASE_DIR/images/clear.gif WIDTH=$size HEIGHT=2>";
}

#+
# Returns javascript for including sorttable.js in page
#-
sub getSortableHTML {
  return <<"  END";
  <SCRIPT LANGUAGE=javascript SRC="$HTML_BASE_DIR/usr/javascript/sorttable.js"></SCRIPT>
  END
}

#+
# Given input string and optional length (default 35 characters) will return
# potentially modified string with original string as 'mouseover' text (in DIV
# title).  If original string is less than length it is returned intact, else
# string is truncated at length and appended with ellipses (...).
#-
sub truncateStringWithMouseover {
  my $self = shift;
  my %args = @_;
  return undef unless $args{string};
  my $string = $args{string};
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  my $len = $args{len} || 35;
  my $shorty = $self->truncateString( %args );
  my $shlen = length( $shorty );
  my $stlen = length( $string );
  if ( $shlen < $stlen ) {
    $shorty .= '...' if $args{add_elipses};
  }
  my $class = ( $args{suppress_class} ) ? '' : 'CLASS=popup_help';
  if ( $args{nowrap} ) {
    $class = "CLASS=anno_cell";
  }
  return qq~<SPAN $class TITLE="$string">$shorty</SPAN>~;
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
  
  $args{types} ||= [ 'submit' ];

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

sub get_user_agent {
  my $self = shift;
  return $q->user_agent();
}

sub get_MSIE_javascript_error {
  my $self = shift;
  my $message = shift || "<BR>There is a known issue with this page on Internet Explorer.  We are working to resolve the problem, and in the meantime suggest that you use Firefox or Google Chrome to view this page";
  if ( $self->get_user_agent =~ /MSIE/ ) {
    return $self->makeErrorText( $message );
  }
  return '';
}

sub getStatusWidget {
  my $self = shift;
  my %args = ( text => '',
               timeout => '', 
               timeout_text => '', 
               add_container => 1, 
               @_ );
  return '' unless $args{id};

  my $timeout = '';
  if ( $args{timeout} ) {
    $timeout = qq~
	  function clear_status() {
      info_txt.innerHTML="$args{timeout_text}";
  	}
    setTimeout( "clear_status()", $args{timeout} )
    ~;
  }

  my $container = '';
  if ( $args{add_container} ) {
    $container = "<DIV id=$args{id}></DIV>";
  }

  my $widget = qq~
  $container
  <script type="text/javascript">
  var info_txt=document.getElementById("$args{id}");
  info_txt.innerHTML="$args{text}";
  $timeout
  </script>
  ~;
  return $widget;

}

sub updateStatusWidget {
  my $self = shift;
  return $self->getStatusWidget( add_container => 0, @_ );
}

sub get_form_fields {
  my $self = shift;
  my %args = ( params => {},
               @_ );

  return '' unless $args{type};
  return '' unless $args{fields};

  my %fields;
  if ( $args{type} =~ /^text$/ ) {
    my $size = $args{size} || 10;
    for my $field ( @{$args{fields}} ) {
      my $val = ( defined $args{params}->{$field} ) ? $args{params}->{$field} : '';
      $fields{$field} = "<tr><td align=right><b>$field</b></td><td align=left><input type='text' value='$val' size=$size id=$field name=$field /></td></tr>\n";
    }
  }
  if ( $args{type} =~ /^radio$/ ) {
    my $size = $args{size} || 10;
    for my $field ( @{$args{fields}} ) {
      my $val = ( defined $args{params}->{$field} ) ? $args{params}->{$field} : '';
      $fields{$field} = "<tr><td align=right><b>$field</b></td><td align=left><input type=radio value='0' name=$field>No  < input type=radio  name=$field value='1'>Yes</td></tr> \n";
    }
  }
  return \%fields;
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


