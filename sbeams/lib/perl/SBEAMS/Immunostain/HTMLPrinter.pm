package SBEAMS::Immunostain::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::Immunostain::HTMLPrinter
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

use SBEAMS::Immunostain::Settings;
use SBEAMS::Immunostain::TableInfo;
use Data::Dumper;

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
sub display_page_header 
{ 
	my $self = shift;
	my %args = @_;
	
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
	
	
	my $sbeams = $self->getSBEAMS();
	$current_contact_id = $sbeams->getCurrent_contact_id();
#	print "this is $current_contact_id";
	
	
	if ($sbeams->getCurrent_contact_id() ne 107)
	{
		$self->displayRegularPageHeader();
			
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

    #### If the output mode is interactive text, display text header
   # my $sbeams = $self->getSBEAMS();
  #  if ($sbeams->output_mode() eq 'interactive') {
   # $sbeams->printTextHeader();
  # return;
  #  }

 #### If the output mode is not html, then we don't want a header here
   # if ($sbeams->output_mode() ne 'html') {
     # return;
   # }


  #### Obtain main SBEAMS object and use its http_header
	my $sbeams = $self->getSBEAMS();
 #   my $http_header = $sbeams->get_http_header();

   # print qq~ $http_header
	#<HTML><HEAD>
	#<TITLE>$DBTITLE - $SBEAMS_PART</TITLE>
   # ~;

  #$self->printJavascriptFunctions();
  # $self->printStyleSheet();
 
my $scgapLink = 'http://scgap.systemsbiology.net';
 
 print qq~
 
 <HTML>
<head><title>SCGAP Urologic Epithelial Stem Cells Project  </title>

<!-- Style sheet definition --------------------------------------------------->
	<style type="text/css">	<!--

	//
	body  	{font-family: Helvetica, Arial, sans-serif; font-size: 9pt; color:#33333; line-height:1.8}


	th    	{font-family: Helvetica, Arial, sans-serif; font-size: 9pt; font-weight: bold;}
	td    	{font-family: Helvetica, Arial, sans-serif; font-size: 9pt; color:#333333;}
	form  	{font-family: Helvetica, Arial, sans-serif; font-size: 9pt}
	pre   	{font-family: Courier New, Courier; font-size: 8pt}
	h1   	{font-family: Helvetica, Arial, Verdana, sans-serif; font-size: 14px; font-weight:bold; color:#0E207F;line-height:20px;}
	h2   	{font-family: Helvetica, Arial, sans-serif; font-size: 12pt; font-weight: bold}
	h3   	{font-family: Helvetica, Arial, sans-serif; font-size: 12pt; color:#FF8700}
	h4   	{font-family: Helvetica, Arial, sans-serif; font-size: 12pt;}
	.text_link  {font-family: Helvetica, Arial, sans-serif; font-size: 9pt; text-decoration:underline; color:#0E207F}
	.text_linkstate {font-family: Helvetica, Arial, sans-serif; font-size: 9pt; text-decoration:underline; color:#0E207F}
	.text_link:hover   {font-family: Helvetica, Arial, sans-serif; font-size: 9pt; text-decoration:underline; color:#DC842F}

	.page_header {font-family: Arial, Helvetica, Verdana, sans-serif; font-size:18px; font-weight:bold; color:#0E207F; line-height:1.2}
	.sub_header {font-family: Arial, Helvetica, Verdana, sans-serif; font-size:12px; font-weight:bold; color:#FF8700; line-height:1.8}
	.Nav_link {font-family:verdana,arial,helvetica,sans serif; font-size:11px; line-height:1.3; color:#DC842F; text-decoration: none;}
	.Nav_link:hover {color: #FFFFFF; text-decoration: none;}
	.Nav_linkstate {cursor:hand; font-family:verdana,arial,helvetica,sans serif; font-size:11px; color:#DC842F; text-decoration:none;}
	.nav_Sub {font-family: Arial, Helvetica, Verdana, sans-serif; font-size:12px; font-weight:bold; color:#ffffff;}

	//
	-->
</style>
</head>

<!-- Begin body: background white, text black -------------------------------->
<body bgcolor="#FFFFFF" text="#000000" TOPMARGIN=0 LEFTMARGIN=0>


<!-- Begin the whole-page table -->
<body background="$HTML_BASE_DIR/images/bg.gif" bgcolor="#FBFCFE">
<a name="TOP"></a>
<!-- -------------- Top Line Header: logo and big title ------------------- -->
<table border="0" width="100%" cellspacing="0" cellpadding="0">
<tr valign="baseline">
<td width="150" bgcolor="#0E207F">
<a href="http://www.systemsbiology.org/" target="_blank"><img src="$HTML_BASE_DIR/images/Logo_left.jpg" width="150" height="85" border="0" align="absbottom"></a>
</td>
<td width="12"><img src="$HTML_BASE_DIR/images/clear.gif" width="12" height="85" border="0"></td>
<td width="518" align="left" valign="bottom">
<span class="page_header">SCGAP Urologic Epithelial Stem Cells Project<BR>&nbsp;<BR></span>
</td>
</tr>
<tr valign="bottom">
<td colspan="3"><img src="$HTML_BASE_DIR/images/nav_orange_bar.gif" width="680" height="18" border="0"></td>

</tr>
~;
	if ($navigation_bar eq "YES") {
print qq~

<!-- --------------- Navigation Bar: List of links ------------------------ -->
<tr>
<td align="left" valign="top" background="$HTML_BASE_DIR/images/bg_Nav.gif">

<table border="0" width="150" cellpadding="0" cellspacing="0">
<tr>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="8" height="10" border="0"></td>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="11" height="10" border="0"></td>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="120" height="10" border="0"></td>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="11" height="10" border="0"></td>
</tr>
<tr>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="http://www.systemsbiology.org/" class="Nav_link">ISB Main</a><br>
<a href="http://www.niddk.nih.gov/" class="Nav_link">NIH/NIDDK Main</a><br>
<a href="http://www.scgap.org/" class="Nav_link">SCGAP Main</a><br>
<a href="http://www.pedb.org/" class="Nav_link">PEDB</a><br></td>
</tr>
<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td background="/images/nav_subTitles.gif"><img src"$HTML_BASE_DIR/images/clear.gif" width="1" height="18" border="0"></td>
<td background="/images/nav_subTitles.gif" colspan="2"><span class="nav_Sub">Project Information</span><td>
<td><img src="$HTML_BASE_DIR/images/nav_subTitles_cr.gif" width="11" height="18" border="0"></td></tr>
<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="/" class="Nav_link">Project Home</a><br>
<a href="$scgapLink/contacts.php" class="Nav_link">Contacts</a><br>
<a href="$scgapLink/project_description.php" class="Nav_link">Project Description</a><br></td>
</tr>
<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td background="/images/nav_subTitles.gif"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="18" border="0"></td>
<td background="/images/nav_subTitles.gif" colspan="2"><span class="nav_Sub">Project Data</span><td>
<td><img src="$HTML_BASE_DIR/images/nav_subTitles_cr.gif" width="11" height="18" border="0"></td></tr>
<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="$HTML_BASE_DIR/cgi/Immunostain/ScgapDataAccess.cgi/" class="Nav_link">Data Access Quick Links</a><br>
<a href="$HTML_BASE_DIR/cgi/Immunostain/main.cgi/" class="Nav_link">Search Data</a><br>
<a href="$HTML_BASE_DIR/cgi/Immunostain/SummarizeStains/" class="Nav_link">Stain Characterization Summary</a><br>
<a href="$HTML_BASE_DIR/cgi/Immunostain/BrowseBioSequence.cgi/" class="Nav_link">Browse Bio Sequences</a><br>
</tr>


<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td background="/images/nav_subTitles.gif"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="18" border="0"></td>
<td background="/images/nav_subTitles.gif" colspan="2"><span class="nav_Sub">Resources</span></td>

<td><img src="$HTML_BASE_DIR/images/nav_subTitles_cr.gif" width="11" height="18" border="0"></td>
</tr>
<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="$scgapLink/figures/CD_specificity.php" class="Nav_link">CD Specificity</a><br>
<a href="$scgapLink/figures/LC_BC_representation.php" class="Nav_link">Luminal &amp; basal cells<br>&nbsp;&nbsp;&nbsp;in PEDB</a><br>
<a href="https://db.systemsbiology.net/sbeams/" class="Nav_link">SBEAMS Database</a><br>
<a href="$scgapLink/data/" class="Nav_link">Data Access</a><br>
<a href="$scgapLink/ontology/" class="Nav_link">Our Ontology</a><br>
<a href="$scgapLink/data/misfishie/" class="Nav_link">MISFISHIE Std</a><br>
<a href="/software/" class="Nav_link">Software</a><br>
<a href="http://www.ncbi.nlm.nih.gov/prow/guide/45277084.htm" class="Nav_link">CD Resources<br>&nbsp;&nbsp;&nbsp;(NCBI PROW)</a><br></td>
</tr>
<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td background="/images/nav_subTitles.gif"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="18" border="0"></td>
<td background="/images/nav_subTitles.gif" colspan="2"><span class="nav_Sub">Software Links</span></td>

<td><img src="$HTML_BASE_DIR/images/nav_subTitles_cr.gif" width="11" height="18" border="0"></td>
</tr>
<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="http://www.cytoscape.org/" class="Nav_link">Cytoscape</a><br>
<a href="http://www.sbeams.org/" class="Nav_link">SBEAMS</a><br>
<a href="http://db.systemsbiology.net/software/ArrayProcess/" class="Nav_link">ISB Microarray Software</a><br></td>
</tr>
<tr>
<td colspan="4"><img src="$HTML_BASE_DIR/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
</td>
</table>
</td>
<td width="12"><img src="/images/clear.gif" alt="" width="12" height="1" border="0"></td>
<!-- -------------------------- End Navigation Bar ------------------------ -->
<td>
~;
print qq~
<!-- --------------------------- Main Page Content ------------------------ -->

<table border=0 width="100%" cellpadding=0 cellspacing=0>
<tr><td>
~;

    } else {
      print qq~
	</TABLE>
      ~;
    }

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




sub displayRegularPageHeader {
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
	  <td bgcolor="$BARCOLOR"><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmltblue.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmltblue.gif"></a></td>
	  <td align="left" $header_bkg><H1>  $DBTITLE - $SBEAMS_PART<BR> $DBVERSION</H1></td>
	</tr>

    ~;

    #print ">>>http_header=$http_header<BR>\n";

    if ($navigation_bar eq "YES") {
     print qq~
	<!------- Button Bar ------------------------------------------>
	
	
	<tr><td bgcolor="$BARCOLOR" align="left" valign="top">
	<table border=0 width="120" cellpadding=2 cellspacing=0>
	<tr><td><a href="$CGI_BASE_DIR/main.cgi">$DBTITLE Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_PART/main.cgi">$SBEAMS_PART Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Manage Tables:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project"><nobr>&nbsp;&nbsp;&nbsp;Projects</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_specimen"><nobr>&nbsp;&nbsp;&nbsp;Specimens</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_specimen_block"><nobr>&nbsp;&nbsp;&nbsp;Specimen Blocks</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_stained_slide"><nobr>&nbsp;&nbsp;&nbsp;Stained Slide</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_slide_image"><nobr>&nbsp;&nbsp;&nbsp;Slide Images</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_stain_cell_presence"><nobr>&nbsp;&nbsp;&nbsp;Characterization</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_antigen"><nobr>&nbsp;&nbsp;&nbsp;Antigens</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_antibody"><nobr>&nbsp;&nbsp;&nbsp;Antibodies</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_cell_type"><nobr>&nbsp;&nbsp;&nbsp;Cell Types</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_tissue_type"><nobr>&nbsp;&nbsp;&nbsp;Tissue Types</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_surgical_procedure"><nobr>&nbsp;&nbsp;&nbsp;Surgical Procs</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_clinical_diagnosis"><nobr>&nbsp;&nbsp;&nbsp;Clinical Diags</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_cell_presence_level"><nobr>&nbsp;&nbsp;&nbsp;Presence</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_abundance_level"><nobr>&nbsp;&nbsp;&nbsp;Abundance</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=protocol"><nobr>&nbsp;&nbsp;&nbsp;Protocols</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>~;
	  
	print qq~
	<tr><td>Browse Data:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains"><nobr>&nbsp;&nbsp;&nbsp;Summarize Stains</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseBioSequence.cgi"><nobr>&nbsp;&nbsp;&nbsp;Browse BioSeqs</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
        <tr><td>Documentation:</td></tr>
        <tr><td><a href="$HTML_BASE_DIR/doc/$SBEAMS_SUBDIR/FileNameConvention.php"><nobr>&nbsp;&nbsp;&nbsp;Filename Coding</nobr></a></td></tr>
        <tr><td><a href="$HTML_BASE_DIR/doc/$SBEAMS_SUBDIR/${SBEAMS_PART}_Schema.gif"><nobr>&nbsp;&nbsp;&nbsp;Schema (GIF)</nobr></a></td></tr>
				<tr><td><a href="http://scgap.systemsbiology.net/dataloading"><nobr>&nbsp;&nbsp;&nbsp;Data Loading</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Other Resources:</td></tr>
	<tr><td><a href="http://scgap.systemsbiology.net"><nobr>&nbsp;&nbsp;&nbsp;SCGAP Home</nobr></a></td></tr>
	<tr><td><a href="http://scgap.systemsbiology.net/ontology/"><nobr>&nbsp;&nbsp;&nbsp;Ontology</nobr></a></td></tr>
	<tr><td><a href="http://www.ncbi.nlm.nih.gov/prow/guide/45277084.htm"><nobr>&nbsp;&nbsp;&nbsp;NCBI PROW<BR>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;CD Index</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
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

  
  my $sbeams = $self->getSBEAMS();
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
    print qq~
	<BR><HR SIZE="2" NOSHADE WIDTH="30%" ALIGN="LEFT">
	SBEAMS - $SBEAMS_PART [Under Development]<BR><BR><BR>
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
