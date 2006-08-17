package SBEAMS::ProteinStructure::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::ProteinStructure::HTMLPrinter
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
use SBEAMS::Connection::Tables;

use SBEAMS::ProteinStructure::Settings;
use SBEAMS::ProteinStructure::TableInfo;


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


    #### Begin the page with the HTTP header and then the TITLE
    print qq~$http_header
	<HTML><HEAD>
	<TITLE>$DBTITLE - $SBEAMS_PART</TITLE>
    ~;


	#### Check to see if the PI of the project is Halo User.
	#### If so, print the halo skin.  NOTE: you also need to adjust the halo_footer
	my $current_project = $sbeams->getCurrent_project_id();
	my $sql = qq~

	  SELECT UWG.contact_id
	    FROM $TB_WORK_GROUP WG
		JOIN $TB_USER_WORK_GROUP UWG ON (WG.work_group_id = UWG.work_group_id)
		JOIN $TB_PROJECT P ON (P.PI_contact_id = UWG.contact_id)
	   WHERE WG.work_group_name = 'HaloPIs'
	     AND P.project_id = $current_project

	   ~;
	my @rows = $sbeams->selectOneColumn($sql);
#	if (scalar(@rows) > 0 ) {
	if ( $sbeams->is_ext_halo_user() ) {
	  $self->display_ext_halo_template( %args );
	  return;
	}

    $self->printJavascriptFunctions();
    $self->printStyleSheet();

    my $loadscript = "$args{onload};" || '';

    #### Determine the Title bar background decoration
    my $header_bkg = "bgcolor=\"$BGCOLOR\"";
    $header_bkg = "background=\"/images/plaintop.jpg\"" if ($DBVERSION =~ /Primary/);

    print qq~
	<!--META HTTP-EQUIV="Expires" CONTENT="Fri, Jun 12 1981 08:20:00 GMT"-->
	<!--META HTTP-EQUIV="Pragma" CONTENT="no-cache"-->
	<!--META HTTP-EQUIV="Cache-Control" CONTENT="no-cache"-->
	</HEAD>

	<!-- Background white, links blue (unvisited), navy (visited), red (active) -->
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" TOPMARGIN=0 LEFTMARGIN=0 OnLoad="$loadscript self.focus();">
	<table border=0 width="100%" cellspacing=0 cellpadding=1>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td bgcolor="$BARCOLOR"><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmltblue.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmltblue.gif"></a></td>
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
	<tr><td>Browse Data:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseBioSequence.cgi"><nobr>&nbsp;&nbsp;&nbsp;Browse BioSeqs</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetDomainHits"><nobr>&nbsp;&nbsp;&nbsp;Browse Domain Hits</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Manage Tables:</td></tr><script src="js/dw_viewport.js" type="text/javascript"></script>

	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project"><nobr>&nbsp;&nbsp;&nbsp;Projects</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PS_biosequence_set"><nobr>&nbsp;&nbsp;&nbsp;BioSequenceSets</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PS_domain_match_type"><nobr>&nbsp;&nbsp;&nbsp;Match Types</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PS_domain_match_source"><nobr>&nbsp;&nbsp;&nbsp;Match Sources</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PS_dbxref"><nobr>&nbsp;&nbsp;&nbsp;DB xRefs</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Documentation:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/Help?document=GetDomainHitsColumnDefinitions"><nobr>&nbsp;&nbsp;&nbsp;Column Definitions</nobr></a></td></tr>
      ~;

      #### Special links to show if the current user is using the admin group
      my $current_work_group_name = $sbeams->getCurrent_work_group_name();
      if ($current_work_group_name eq 'ProteinStructure_admin') {
        print qq~
	  <tr><td>&nbsp;</td></tr>
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

    <STYLE>
    div#tooltipID {
	  background-color:#1C3887;
      border:2px solid #EE7621; 
      padding:4px;
	  line-height:1.5;
	  width:200px;
      color:#FFFFFF;
	  font-family: Helvetica, Arial, sans-serif;
	  font-size:12px;
      font-weight: normal;
      position:absolute; 
      visibility:hidden;
      left:0;
      top:0;
    }
    </STYLE>

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
  my $tooltip_footer = $self->getToolTip();

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

  #### Check to see if the PI of the curernt project is a Halobacterium guy.
  #### If so, print the halo skin
  if ($display_footer eq 'YES') {
	my $current_project = $sbeams->getCurrent_project_id();
	my $sql = qq~

	  SELECT UWG.contact_id
	    FROM $TB_WORK_GROUP WG
		JOIN $TB_USER_WORK_GROUP UWG ON (WG.work_group_id = UWG.work_group_id)
		JOIN $TB_PROJECT P ON (P.PI_contact_id = UWG.contact_id)
	   WHERE WG.work_group_name = 'HaloPIs'
	     AND P.project_id = $current_project

	   ~;
	my @rows = $sbeams->selectOneColumn($sql);


  #### If closing the content tables is desired
  if ($args{'close_tables'} eq 'YES') {
    print qq~
	</TD></TR></TABLE>
	</TD></TR></TABLE>
    ~;
  }


  #### If displaying a fat bar separtor is desired
  if ($separator_bar eq 'YES') {
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";
  }



#	if (scalar(@rows) > 0 ) {
  # Note that we are using is_ext_user as opposed to is PI logic above
	if ( $sbeams->is_ext_halo_user() ) {
	  $self->display_ext_halo_footer();
	  return;
	}else {
	  print $tooltip_footer;
	  $sbeams->display_page_footer(display_footer=>'YES');
	}
  }
}

###############################################################################
# getToolTipFooter
###############################################################################
sub getToolTip {
  my $self = shift;
  my $footer = qq~
<SCRIPT src="$HTML_BASE_DIR/usr/javascript/TipWidget.js" TYPE="text/javascript"></SCRIPT>
	~;
  return $footer;
}

###############################################################################
# display_ext_halo_template
###############################################################################
sub display_ext_halo_template {
  my $self = shift;
  my %args = @_;

  my $loadscript = "$args{onload};" || '';

  $self->printJavascriptFunctions();
  $self->display_ext_halo_style_sheet();

  my $LOGIN_URI = "$SERVER_BASE_DIR$ENV{REQUEST_URI}";
  if ($LOGIN_URI =~ /\?/) {
    $LOGIN_URI .= "&force_login=yes";
  } else {
    $LOGIN_URI .= "?force_login=yes";
  }

  my $HALO_HOME = 'http://baliga.systemsbiology.net';
  my $buf = qq~
<body OnLoad="$loadscript self.focus()" leftmargin="0" rightmargin="0" marginspace="0" topmargin="3" bottommargin="3" marginheight="3" marginwidth="0">

<table bordercolor="#827975" cellpadding="0" cellspacing="0" width="680" border="1" align="center">
	<tr>
		<td>
		<!-- top image bar -->
		<table id="Table_01" align="center" bgcolor="f7f5ea" width="680" height="132" border="0" cellpadding="0" cellspacing="0">
		<tr>
			<td colspan="2" bgcolor="#827975" height="8"></td>
		</tr>
		<tr>
			<td colspan="2" bgcolor="B25D3C" height="1"></td>
		</tr>
		<tr>
			<td colspan="2" height="36" valign="top" background="/images/topbluebar.gif">
			<a href="http://www.systemsbiology.org/"><img src="/images/isbhome.gif" alt="" height="16" width="70" align="right" border="0"></a>
			<div class="TopTitle">
			<font color="white"><!--Top Title of Website goes here--><strong><font size="5" face="Arial, Helvetica, Verdana, sans-serif">
						&nbsp;&nbsp;Baliga Lab at ISB</font></strong></font></div></td>
		</tr>
		<tr>
			<td width="255"><img src="/images/bottombluebar.gif" width="255" height="77" alt=""></td>
			<td><img src="/images/imgbar.jpg" width="425" height="77" alt=""></td>
		</tr>
		<tr>
			<td colspan="2" bgcolor="B25D3C" height="1"></td>
		</tr>
		<tr>
			<td colspan="2" bgcolor="827975" height="4"></td>
		</tr>
		<tr>
			<td colspan="2" bgcolor="C6C1B8" height="3"></td>
		</tr>
		<tr>
			<td colspan="2"><img src="/images/clear.gif" alt="" height="10" width="680" border="0"></td>
		</tr>
		</table>
		
		<!--end top bar-->
	~;

  $buf .= qq~
<!-- --------------- Navigation Bar: List of links ------------------------ -->
<!-- START Main page table -->
<table align="center" bgcolor="#f3f1e4" border="0" cellpadding="0" cellspacing="0" width="677">
<tbody>
		<tr>
			<td width="1"></td>
			<td width="130"><img src="/images/clear.gif" border="0" height="1" width="130"></td>
			<td width="550"><img src="/images/clear.gif" border="0" height="1" width="545"></td>
		</tr>
		<tr valign="top" height="601">
			<td width="1" height="601"></td>
			<td width="120" height="601"><!-- START Secondary navigation table -->
				<table align="center" bgcolor="#ffffff" border="0" cellpadding="0" cellspacing="0" width="134">
					<tbody>
						<tr height="2">
							<td bgcolor="#c6c1b8" height="2" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td colspan="3" bgcolor="#c6c1b8" width="132" height="2"><img src="/images/clear.gif" border="0" height="2" width="1"></td>
							<td bgcolor="#c6c1b8" height="2" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr height="20">
							<td bgcolor="#c6c1b8" height="20" width="1"><img src="/images/clear.gif" border="0" height="20" width="1"></td>
							<td class="SecondNavTitle" colspan="2" align="center" bgcolor="#c6c1b8" width="129" height="20"><img src="/images/redarrow.gif" alt="" height="8" width="8" border="0" />&nbsp;&nbsp;<a href="http://halo.systemsbiology.net/" class="SecondNavTitle">Halo Home</a></td>
							<td bgcolor="#c6c1b8" height="20" width="3"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td bgcolor="#c6c1b8" width="1" height="20"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td colspan="3" bgcolor="#c6c1b8" width="132" height="2"><img src="/images/clear.gif" border="0" height="2" width="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="5"></td>
							<td width="124"><img src="/images/clear.gif" border="0" height="1" width="110"></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="3"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124"><p class="SecondNavOff">Project Information</p></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="3"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124" height="1"><img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/background.php" class="leftnavlink">Background</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/systems.php" class="leftnavlink">Systems Approach</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/data.php" class="leftnavlink">Data Integration</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/publications.php" class="leftnavlink">Publications</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/contacts.php" class="leftnavlink">Contacts</a><br>
							</td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124" height="32"><img src="/images/SecondNavSpacer.gif" alt="" height="4" width="110" border="0" /></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="3"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<!--Place Holder -->
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124"><p class="SecondNavOff">Organisms</p></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="3"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124" height="1"><img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/halobacterium/" class="leftnavlink"><i>Halobacterium &nbsp;&nbsp;&nbsp;&nbsp;sp.NRC-1</i></a><br>
							         <img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/haloarcula/" class="leftnavlink"><i>Haloarcula &nbsp;&nbsp;&nbsp;&nbsp;marismortui</i></a><br>
							</td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124" height="32"><img src="/images/SecondNavSpacer.gif" alt="" height="4" width="110" border="0" /></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="3"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<!--Place Holder -->
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124"><p class="SecondNavOff">Halo Group Resources</p></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="3"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124" height="1"><img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://db.systemsbiology.net/sbeams/cgi/Oligo/Search_Oligo.cgi" class="leftnavlink">Oligo Search &nbsp;&nbsp;&nbsp;&nbsp;(Internal)</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://db/%7Emjohnson/faq/index.html" class="leftnavlink" target="_blank">Data FAQ (Internal)</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/students/home.htm" class="leftnavlink">Student Intern Site</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/cytoscape/cellphone/index.php" class="leftnavlink">High School &nbsp;&nbsp;&nbsp;&nbsp;Education</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/purplemembrane/PurpleMembrane.html" class="leftnavlink" target="new">Purple Membrane &nbsp;&nbsp;&nbsp;&nbsp;Model</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://halo.systemsbiology.net/cytoscape/cellphone/cy.jnlp" class="leftnavlink">Cell Phone Simulation</a><br>
							</td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124" height="32"><img src="/images/SecondNavSpacer.gif" alt="" height="4" width="110" border="0" /></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="3"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<!--Place Holder -->
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124"><p class="SecondNavOff">Software Links</p></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124" height="1"><img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://www.cytoscape.org/" target="new" class="leftnavlink">Cytoscape</a><br>
								                                           <img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://www.sbeams.org/" target="new" class="leftnavlink">SBEAMS</a><br>
					        </td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="5"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td width="124" height="32"><img src="/images/SecondNavSpacer.gif" alt="" height="4" width="110" border="0" /></td>
							<td width="3"><img src="/images/clear.gif" border="0" height="1" width="3"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
						</tr>
						<!--Place Holder -->
						<tr height="1">
							<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
							<td bgcolor="white" height="1" width="5"></td>
							<td width="124" height="1"><p class="SecondNavOff">Baliga Group Links</p></td>
							<td width="3" height="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"></td>
						</tr>
						<!--Place Holder -->
						<tr height="1">
							<td bgcolor="#c6c1b8" height="1" width="1"></td>
							<td bgcolor="white" height="1" width="5"></td>
							<td width="124" height="1"><img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://www.systemsbiology.org/Scientists_and_Research/Faculty_Groups/Baliga_Group" target="new" class="leftnavlink">Baliga Group</a><br>
								<img src="/images/textmarker.gif" alt="" height="7" width="10" border="0">&nbsp;<a href="http://www.systemsbiology.org/Scientists_and_Research/Faculty_Groups/Baliga_Group/Profile" target="new" class="leftnavlink">Dr. Nitin Baliga\'s &nbsp;&nbsp;&nbsp;&nbsp;Profile</a><br>
								<!--<a href="http://www.systemsbiology.org/Scientists_and_Research/Faculty_Groups/Baliga_Group/Research_Projects" target="new" class="leftnavlink">Research Projects</a><br>--></td>
							<td width="3" height="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"></td>
						</tr>

						<!--Place Holder -->
						<tr height="1">
							<td bgcolor="#c6c1b8" height="1" width="1"></td>
							<td bgcolor="white" height="1" width="5"></td>
							<td width="124" height="1">&nbsp;&nbsp;</td>
							<td width="3" height="1"></td>
							<td bgcolor="#c6c1b8" height="1" width="1"></td>
						</tr>
						<tr>
							<td bgcolor="#c6c1b8" height="1" width="1"></td>
							<td width="5" bgcolor="#c6c1b8"></td>
							<td width="124" bgcolor="#c6c1b8" height="1"></td>
							<td width="3" height="1" bgcolor="#c6c1b8"></td>
							<td width="1" height="1" bgcolor="#c6c1b8"></td>
						</tr>


					</tbody>
				</table>
				<!-- END Secondary navigation table --><br>
				<center>
				<a href="http://www.systemsbiology.org/"><img src="/images/isblogo.gif" alt="" height="65" width="115" align="baseline" border="0"></a></center>
			</td>
			<!-- <td width="550" height="601"> -->
			<td>
  ~;


  $buf .= qq~

<!-- START Body content table -->
									<table align="center" bgcolor="white" border="0" cellpadding="0" cellspacing="0" width="540">
										<tbody>
											<tr>
												<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
												<td colspan="3" bgcolor="#c6c1b8" width="538" height="2"><img src="/images/clear.gif" border="0" height="2" width="1"></td>
												<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
											</tr>
											<tr height="20">
												<td bgcolor="#c6c1b8" height="20" width="1"><img src="/images/clear.gif" border="0" height="20" width="1"></td>
												
												
												<td colspan="3" class="Pagetitle" bgcolor="#c6c1b8" width="538" height="20"><img src="/images/clear.gif" border="0" height="1" width="6">
									<!--Header of Content page goes here.  Should match left nav that was clicked-->Proteome Search Results</td>
												<td bgcolor="#c6c1b8" height="20" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
											</tr>
											<tr>
												<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
												<td colspan="3" bgcolor="#c6c1b8" width="538" height="2"><img src="/images/clear.gif" border="0" height="2" width="1"></td>
												<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
											</tr>
											<tr>
												<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
												<td width="4"></td>
												<td width="521"></td>
												<td bgcolor="white" height="1" width="9"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
												<td width="1" bgcolor="#c6c1b8"><img src="/images/clear.gif" alt="" height="2" width="1" border="0"></td>
											</tr>
											<tr valign="top" height="598">
												<td bgcolor="#c6c1b8" height="598" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
												<td width="4" height="598"><img src="/images/clear.gif" border="0" height="1" width="8"></td>
												<td width="521" height="598"><!-- This space is reserved for the Content of your Site-->	
  ~;


  $buf =~ s/=\"\/images/=\"$HALO_HOME\/images/g;
  #$buf =~ s/href=\"\//href=\"$HTML_BASE_DIR\//g;
  $buf =~ s/href=\"\//href=\"http:\/\/halo.systemsbiology.net\//g;
  print $buf;
  return;

}



###############################################################################
# display_ext_halo_style_sheet
###############################################################################
sub display_ext_halo_style_sheet {
  my $self = shift;
  my %args = @_;

  my $FONT_SIZE=9;
  my $FONT_SIZE_SM=8;
  my $FONT_SIZE_LG=12;
  my $FONT_SIZE_HG=14;

  if ( $ENV{HTTP_USER_AGENT} =~ /Mozilla\/4.+X11/ ) {
    $FONT_SIZE=12;
    $FONT_SIZE_SM=11;
    $FONT_SIZE_LG=14;
    $FONT_SIZE_HG=19;
  }

    print qq~
<!-- Style sheet definition --------------------------------------------------->
	<style type="text/css">	<!--

	//

	.TopTitle { font-family: Arial, Helvetica, Verdana, sans-serif; font-size:24px; color:#ffffff; font-weight: bold; }

.leftnavlink {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:11px;
	color:#294A93;
	text-decoration:none;
	line-height:18px;
	 letter-spacing:.3px;
	font-weight:normal}
.leftnavlink:hover {color: #c28962;}
.leftnavlinkstate {cursor: hand; font-family:arial,helvetica,sans serif; font-size:11px; letter-spacing:.3px; color:#F3F1E4;}


.textlink {
	font-family: Helvetica, Arial,  Verdana, sans-serif;
	font-size:12px;
	color:#c28962;
	line-height:16px;
	font-weight:normal}
.textlink:hover {color: #294A93;}
.textlinkstate {cursor: hand; font-family: helvetica, arial, sans serif; font-size:12px; letter-spacing:.5px; color:#F3F1E4;}






h1  {font-family: Helvetica, Arial, Verdana, sans-serif; font-size: 14px; font-weight:bold; color:#666;line-height:20px;}
h2  { color: #004896; font-family: Helvetica, Arial, sans-serif; font-size: 18pt; font-weight: bold; }
h3  {font-family: Helvetica, Arial, sans-serif; font-size: 12pt; color:#004896}
h4  { color: #004896; font-family: Helvetica, Arial, sans-serif; font-size: 10pt; font-weight:normal; font-weight:bold }






.TopNavlink {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:14px;
	color:#fff;
	font-variant: small-caps;
	text-decoration:none;
	line-height:20px;
	letter-spacing:1px;
	font-weight:bold}
.TopNavlink:hover {color: #D99B67;}
.TopNavlinkstate {cursor: hand; font-family:verdana,arial,helvetica,sans serif; font-size:11px; letter-spacing:1px; font-variant: small-caps; color:#F3F1E4;}

.speaker_link {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:13px;
	color:#000000;
	line-height:20px;
	font-weight:normal}
.speaker_link:hover {color: #000000;}
.speaker_linkstate {cursor: hand; font-family:verdana,arial,helvetica,sans serif; font-size:13px; color:#000000;}

.TrailNav {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:10px;
	color:#827975;
	text-decoration:none;
	line-height:20px;
	letter-spacing:.5px;
	font-weight:normal}

.SecondNavTitle {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:14px;
	color:#827975;
	font-variant:small-caps;
	text-decoration:none;
	line-height:14px;
	font-weight:bold}

.SecondNavTitle:hover {color: #827975;}
.SecondNavTitlestate {cursor:hand; font-family:verdana,arial,helvetica,sans serif; font-size:13px; text-decoration:none; color:#827975;}

.SecondNavOn {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:13px;
	color:#B35F3E;
	font-variant: small-caps;
	text-decoration:none;
	line-height:13px;
	letter-spacing:.5px;
	font-weight:bold}

.SecondNavOff {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:13px;
	color:#827975;
	text-decoration:none;
	line-height:18px;
	letter-spacing:.5px;
	font-weight:bold}

.SecondNav2Off { font-family: Arial, Helvetica, Verdana, sans-serif; font-size:11px; color:#827975; font-weight: 600; text-decoration:none; line-height:13px; letter-spacing:0.5px; }
.SecondNav2On {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-weight: normal;
	font-size: 11px;
	color:#B35F3E;
	text-decoration:none;
	line-height:13px;
	letter-spacing:.5px;}

.PageTitle {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:15px;
	color:#827975;
	text-decoration:none;
	line-height:14px;
	letter-spacing:0.5px;
	font-weight:bold}

.texttitle {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:12px;
	color:#B35F3E;
	line-height:16px;
	letter-spacing:.5px;
	font-weight:normal;
	font-weight:bold}
.texttitle:hover {color: #B35F3E;}
.texttitlestate {cursor: hand; font-family:verdana,arial,helvetica,sans serif; font-size:12px; letter-spacing:.5px; font-weight:bold; color:#B35F3E;}

.text {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:12px;
	color:#555555;
	line-height:16px;
	letter-spacing:.5px;
	font-weight:normal}


.textsm {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:11px;
	color:#555555;
	line-height:13px;
	letter-spacing:.5px;
	font-weight:normal}
.textsm:hover {color: #B35F3E;}
.textsmstate {cursor: hand; font-family:verdana,arial,helvetica,sans serif; font-size:11px; letter-spacing:.5px; color:#F3F1E4;}

.top {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:11px;
	color:#B35F3E;
	line-height:16px;
	font-variant: small-caps;
	text-decoration:none;
	letter-spacing:.5px;
	font-weight:normal;
	font-weight:bold}
.top:hover {color: #B35F3E;}
.topstate {cursor: hand; font-family:verdana,arial,helvetica,sans serif; font-size:11px; letter-spacing:.5px; text-decoration:none; font-variant: small-caps; font-weight:bold; color:#B35F3E;}


.RL {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:11px;
	color:#294A93;
	line-height:14px;
	text-decoration:none;
	letter-spacing:.5px;
	font-weight:normal}
.RL:hover {color: #B35F3E;}
.RLstate {cursor: hand; font-family:verdana,arial,helvetica,sans serif; font-size:11px; text-decoration:none; font-weight:bold; letter-spacing:.5px; text-decoration:none; color:#294A93;}


.RelatedLinksTitle {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:13px;
	color:#827975;
	font-variant: small-caps;
	text-decoration:none;
	line-height:13px;
	letter-spacing:.5px;
	font-weight:bold}

.RelatedLinks {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:11px;
	color:#294A93;
	text-decoration:none;
	letter-spacing:.5px;
	font-weight:bold}
.RelatedLinks:hover {color: #B35F3E;}
.RelatedLinksstate {cursor: hand; font-family:verdana,arial,helvetica,sans serif; font-size:11px; font-weight:bold; letter-spacing:.5px; text-decoration:none; color:#294A93;}

.BottomNav {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:9px;
	color:#fff;
	text-decoration:none;
	font-variant: small-caps;
	line-height:14px;
	letter-spacing:0.5px;
	font-weight:normal}
.BottomNav:hover {color: #c2c2c2;}
.BottomNavstate {cursor: hand; font-family:verdana, arial, helvetica, "sans serif"; font-size:9px; font-variant: small-caps; letter-spacing:0.5px; color:#c28962;}

.copyright {
	font-family: Verdana, Helvetica, Arial, sans-serif;
	font-size:9px;
	color:#fff}

.textform {
 color: #000000;
 font-family: Verdana, Arial, Helvetica, sans-serif;
 font-size: 10px;
 text-align: center;}

.PressTitle {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:13px;
	color:#555555;
	line-height:16px;
	letter-spacing:.5px;
	font-weight:bold}

.PressLink {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:11px;
	color:#294A93;
	text-decoration:none;
	line-height:normal;
	letter-spacing:.2px;
	font-weight:normal}
.PressLink:hover {color: #B35F3E;}
.PressLinkstate {cursor: hand; font-family:verdana,arial,helvetica,sans serif; text-decoration:none; font-size:11px; font-weight:normal; letter-spacing:.5px; color:#F3F1E4;}

.PressHeadline_inside {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:14px;
	color:#294A93;
	text-decoration:none;
	line-height:14px;
	letter-spacing:.5px;
	font-weight:bold}

.ACWhiteTitle {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:12px;
	color:#FFFFFF;
	text-decoration:none;
	line-height:13px;
	letter-spacing:.1px;
	}

.table{
	background-color: #FFFFFF;
	border-color: #827975;
	border-width: 1px 1px 1px 1px;
	border-style: solid;
	margin-bottom: 8px
	}
.brown {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:12px;
	color:#946000;
	line-height:16px;
	letter-spacing:.5px;
	text-decoration:none;
	font-weight:normal}

.black {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:12px;
	color:#000000;
	line-height:16px;
	letter-spacing:.5px;
	text-decoration:none;
	font-weight:normal}

.form {
	font-family: Verdana, Arial, Helvetica, Verdana, sans-serif;
	font-size:11px;
	color:#555555;}

.bullets {
	font-family: Arial, Helvetica, Verdana, sans-serif;
	font-size:12px;
	color:#555555;
	line-height:16px;
	letter-spacing:.5px;
	font-weight:normal}
	//
	-->
</style>
</head>
  ~;

  return;

}



###############################################################################
# display_ext_halo_footer
###############################################################################
sub display_ext_halo_footer {
  my $self = shift;
  my %args = @_;
  my $tooltip_footer = $self->getToolTip;

  my $buf = qq~
	<!-- End Content-->												
		</td>
		<td width="9" height="598"><img src="/images/clear.gif" border="0" height="1" width="9"></td>
		<td bgcolor="#c6c1b8" height="598" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
	</tr>
	<tr>
		<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
		<td colspan="3" bgcolor="#c6c1b8" width="538" height="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
		<td bgcolor="#c6c1b8" height="1" width="1"><img src="/images/clear.gif" border="0" height="1" width="1"></td>
	</tr>
	</tbody>
	</table>

	<!-- END Body content table -->
</td>

<!-- End Main page table -->
			
<table width="100%" align="center" cellpadding="0" cellspacing="0" border="0" bordercolor="#827975" height="30">
	<tr>
		<td bgcolor="#827975" height="18" align="left">
				
		<!-- START copyright content -->

		<center>
		<span class="BottomNav">
<a href="http://baliga.systemsbiology.net/" class="BottomNav">HOME</a>  |  <a href="http://baliga.systemsbiology.net/background.php" class="BottomNav">BACKGROUND</a>  |  <a href="http://baliga.systemsbiology.net/systems.php" class="BottomNav">SYSTEMS APPROACH</a>  |  <a href="http://baliga.systemsbiology.net/data.php" class="BottomNav">DATA INTEGRATION</a>  |  <a href="http://baliga.systemsbiology.net/contacts.php" class="BottomNav">CONTACTS</a>  |  <a href="http://baliga.systemsbiology.net/publications.php" class="BottomNav">PUBLICATIONS</a>  |  <a href="http://baliga.systemsbiology.net/halobacterium/" class="BottomNav">ORGANISMS</a> |  <a href="http://intranet.systemsbiology.net/" class="BottomNav">INTRANET</a>
		</span>

		<br>
		<span class="copyright">© 2005, Institute for Systems Biology, All Rights Reserved</span>
		<br>
		</center>
		<!-- END copyright content -->
				
		</td>
	</tr>
	<tr height="12">
		<td bgcolor="#294a93" height="12">
		</td>
	</tr>
</table>

</tr></table>

$tooltip_footer
		
	</body>
</html>
  ~;

  $buf =~ s/=\"\/images/=\"$HTML_BASE_DIR\/images/g;
  print $buf;
  return;

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
