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
	if (scalar(@rows) > 0 ) {
	  $self->display_ext_halo_template();
	  return;
	}

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
	<tr><td>Manage Tables:</td></tr>
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
	my $tooltip_header = $self->getToolTipHeader();

    print qq~
	<SCRIPT LANGUAGE="JavaScript">
	<!--

	function refreshDocument() {
	  document.MainForm.apply_action_hidden.value = "REFRESH";
	  document.MainForm.action.value = "REFRESH";
	  document.MainForm.submit();
	} // end refreshDocument

	function showPassed(input_field) {
	  confirm( "selected option ="+
			   document.forms[0].slide_id.options[document.forms[0].slide_id.selectedIndex].text+"=");
	  return;
	} // end showPassed
    // -->
    </SCRIPT>

	$tooltip_header;

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
  my $tooltip_footer = $self->getToolTipFooter();

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

  print $tooltip_footer;

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
	if (scalar(@rows) > 0 ) {
	  $self->display_ext_halo_footer();
	  return;
	}else {
	  $sbeams->display_page_footer(display_footer=>'YES');
	}
  }
}


###############################################################################
# getToolTipHeader
###############################################################################
sub getToolTipHeader {
  my $self = shift;
  my $header = qq~

    <STYLE>
    div#tipDiv {
      position:absolute; 
      visibility:hidden;
      left:0;
      top:0;
	  z-index:10000;
	  background-color:#9AC0CD;
      border:2px solid #EE7621; 
	  width:200px;
      padding:4px;
      color:#000;
	  font-size:12px;
	  line-height:1.5;
    }
    </STYLE>

	
<SCRIPT language="javascript">

function doTooltip(e, msg) {
  if ( typeof Tooltip == "undefined" || !Tooltip.ready ) return;
  Tooltip.show(e, msg);
}
function hideTip() {
  if ( typeof Tooltip == "undefined" || !Tooltip.ready ) return;
  Tooltip.hide();
}
</SCRIPT>
	~;

return $header;
}

###############################################################################
# getToolTipFooter
###############################################################################
sub getToolTipFooter {
  my $self = shift;
  my $footer = qq~

<SCRIPT>
var viewport = {
  getWindowpaneX: function () {
    this.width = 0;
    if (window.innerWidth) this.width = window.innerWidth - 18;
    else if (document.documentElement && document.documentElement.clientWidth) 
  		this.width = document.documentElement.clientWidth;
    else if (document.body && document.body.clientWidth) 
  		this.width = document.body.clientWidth;
  },
  
  getWindowpaneY: function () {
    this.height = 0;
    if (window.innerHeight) this.height = window.innerHeight - 18;
  	else if (document.documentElement && document.documentElement.clientHeight) 
  		this.height = document.documentElement.clientHeight;
  	else if (document.body && document.body.clientHeight) 
  		this.height = document.body.clientHeight;
  },
  
  getScrollpaneX: function () {
    this.scrollX = 0;
  	if (typeof window.pageXOffset == "number") this.scrollX = window.pageXOffset;
  	else if (document.documentElement && document.documentElement.scrollLeft)
  		this.scrollX = document.documentElement.scrollLeft;
  	else if (document.body && document.body.scrollLeft) 
  		this.scrollX = document.body.scrollLeft; 
  	else if (window.scrollX) this.scrollX = window.scrollX;
  },
  
  getScrollpaneY: function () {
    this.scrollY = 0;    
    if (typeof window.pageYOffset == "number") this.scrollY = window.pageYOffset;
    else if (document.documentElement && document.documentElement.scrollTop)
  		this.scrollY = document.documentElement.scrollTop;
  	else if (document.body && document.body.scrollTop) 
  		this.scrollY = document.body.scrollTop; 
  	else if (window.scrollY) this.scrollY = window.scrollY;
  },
  
  getAllDimensions: function () {
    this.getWindowpaneX();
    this.getScrollpaneX();
	this.getWindowpaneY();
	this.getScrollpaneY();
  }
  
}

var dw_event = {
  
  add: function(obj, etype, fp, cap) {
    cap = cap || false;
    if (obj.addEventListener) obj.addEventListener(etype, fp, cap);
    else if (obj.attachEvent) obj.attachEvent("on" + etype, fp);
  }, 

  remove: function(obj, etype, fp, cap) {
    cap = cap || false;
    if (obj.removeEventListener) obj.removeEventListener(etype, fp, cap);
    else if (obj.detachEvent) obj.detachEvent("on" + etype, fp);
  }, 

  DOMit: function(e) { 
    e = e? e: window.event;
    e.tgt = e.srcElement? e.srcElement: e.target;
    
    if (!e.preventDefault) e.preventDefault = function () { return false; }
    if (!e.stopPropagation) e.stopPropagation = function () { if (window.event) window.event.cancelBubble = true; }
        
    return e;
  }
  
}

var Tooltip = {
 followMouse: true,
 offX: 8,
 offY: 12,
 tipID: "tipDiv",
 showDelay: 100,
 hideDelay: 200,
    
 ready:false, timer:null, tip:null, 
  
 init: function() {  
   if ( document.createElement && document.body && typeof document.body.appendChild != "undefined" ) {
	 if ( !document.getElementById(this.tipID) ) {
	   var el = document.createElement("DIV");
	   el.id = this.tipID; document.body.appendChild(el);
	 }
	 this.ready = true;
   }
 },
    
 show: function(e, msg) {
   if (this.timer) { clearTimeout(this.timer);	this.timer = 0; }
   this.tip = document.getElementById( this.tipID );
   if (this.followMouse) // set up mousemove 
	 dw_event.add( document, "mousemove", this.trackMouse, true );
   this.writeTip("");  // for mac ie
	 this.writeTip(msg);
   viewport.getAllDimensions();
   this.positionTip(e);
   this.timer = setTimeout("Tooltip.toggleVis('" + this.tipID + "', 'visible')", this.showDelay);
 },
    
 writeTip: function(msg) {
   if ( this.tip && typeof this.tip.innerHTML != "undefined" ) this.tip.innerHTML = msg;
 },
    
 positionTip: function(e) {
   if ( this.tip && this.tip.style ) {
	 // put e.pageX/Y first! (for Safari)
	 var x = e.pageX? e.pageX: e.clientX + viewport.scrollX;
	 var y = e.pageY? e.pageY: e.clientY + viewport.scrollY;

	 if ( x + this.tip.offsetWidth + this.offX > viewport.width + viewport.scrollX ) {
	   x = x - this.tip.offsetWidth - this.offX;
	   if ( x < 0 ) x = 0;
	 } else x = x + this.offX;

	 if ( y + this.tip.offsetHeight + this.offY > viewport.height + viewport.scrollY ) {
	   y = y - this.tip.offsetHeight - this.offY;
	   if ( y < viewport.scrollY ) y = viewport.height + viewport.scrollY - this.tip.offsetHeight;
	 } else y = y + this.offY;
            
	 this.tip.style.left = x + "px"; this.tip.style.top = y + "px";
   }
 },
    
 hide: function() {
   if (this.timer) { clearTimeout(this.timer);	this.timer = 0; }
   this.timer = setTimeout("Tooltip.toggleVis('" + this.tipID + "', 'hidden')", this.hideDelay);
   if (this.followMouse) // release mousemove
	 dw_event.remove( document, "mousemove", this.trackMouse, true );
   this.tip = null; 
 },

 toggleVis: function(id, vis) { 
   var el = document.getElementById(id);
   if (el) el.style.visibility = vis;
 },
    
 trackMouse: function(e) {
   e = dw_event.DOMit(e);
   Tooltip.positionTip(e);
 }
    
}

Tooltip.init();
  </SCRIPT>
	~;
  return $footer;
}

###############################################################################
# display_ext_halo_template
###############################################################################
sub display_ext_halo_template {
  my $self = shift;
  my %args = @_;

  $self->printJavascriptFunctions();
  $self->display_ext_halo_style_sheet();

  my $LOGIN_URI = "$SERVER_BASE_DIR$ENV{REQUEST_URI}";
  if ($LOGIN_URI =~ /\?/) {
    $LOGIN_URI .= "&force_login=yes";
  } else {
    $LOGIN_URI .= "?force_login=yes";
  }


  my $buf = qq~
<!-- Begin body: background white, text black -------------------------------->
<body TOPMARGIN=0 LEFTMARGIN=0 background="/images/bg.gif" bgcolor="#FBFCFE">

<!-- Begin the whole-page table -->
<a name="TOP"></a>
<table border="0" width="680" cellspacing="0" cellpadding="0">

<!-- -------------- Top Line Header: logo and big title ------------------- -->
<tr valign="baseline">
<td width="150" bgcolor="#0E207F">
<a href="http://www.systemsbiology.org/" target="_blank"><img src="/images/Logo_left.jpg" width="150" height="85" border="0" align="bottom"></a>
</td>
<td width="12"><img src="/images/clear.gif" width="12" height="85" border="0"></td>

<td width="518" align="left" valign="bottom">
<span class="page_header">$DBTITLE - $SBEAMS_PART<BR>$DBVERSION<BR>&nbsp;<BR></span>
</td>

</tr>
<tr valign="bottom">
<td colspan="3"><img src="/images/nav_orange_bar.gif" width="680" height="18" border="0"></td>
</tr>
  ~;

  my $HALO_HOME = 'http://halo.systemsbiology.net';

  $buf .= qq~
<!-- --------------- Navigation Bar: List of links ------------------------ -->
<tr>
<td align="left" valign="top" background="/images/bg_Nav.gif">

<table border="0" width="150" cellpadding="0" cellspacing="0">

<tr>
<td><img src="/images/clear.gif" width="2" height="10" border="0"></td>
<td><img src="/images/clear.gif" width="5" height="10" border="0"></td>
<td><img src="/images/clear.gif" width="132" height="10" border="0"></td>
<td><img src="/images/clear.gif" width="11" height="10" border="0"></td>
</tr>



<tr>
<td><img src="/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="http://www.systemsbiology.org/" class="Nav_link">ISB Main</a><br>
<a href="http://halo.systemsbiology.net/" class="Nav_link">Halo Research at ISB</a><br>
</tr>
<tr>
<td colspan="4"><img src="/images/clear.gif" width="1" height="10" border="0"></td>
</tr>



<tr>
<td background="/images/nav_subTitles.gif"><img src="/images/clear.gif" width="1" height="18" border="0"></td>
<td background="/images/nav_subTitles.gif" colspan="2"><span class="nav_Sub">Project Information</span></td>
<td><img src="/images/nav_subTitles_cr.gif" width="11" height="18" border="0"></td>
</tr>

<tr>
<td colspan="4"><img src="/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td><img src="/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="$HALO_HOME/" class="Nav_link">Project Home</a><br>
<a href="$HALO_HOME/background.php" class="Nav_link">Background</a><br>
<a href="$HALO_HOME/systems.php" class="Nav_link">Systems Approach</a><br>
<a href="$HALO_HOME/data.php" class="Nav_link">Data Integration</a><br>
<a href="$HALO_HOME/publications.php" class="Nav_link">Publications</a><br>
<a href="$HALO_HOME/contacts.php" class="Nav_link">Contacts</a><br>
</td>
</tr>
<tr>
<td colspan="4"><img src="/images/clear.gif" width="1" height="10" border="0"></td>
</tr>



<tr>
<td background="/images/nav_subTitles.gif"><img src="/images/clear.gif" width="1" height="18" border="0"></td>
<td background="/images/nav_subTitles.gif" colspan="2"><span class="nav_Sub">Organisms</span></td>

<td><img src="/images/nav_subTitles_cr.gif" width="11" height="18" border="0"></td>
</tr>
<tr>
<td colspan="4"><img src="/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td><img src="/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="$HALO_HOME/halobacterium/" class="Nav_link">Halobacterium sp. NRC-1</a><br>
<a href="$HALO_HOME/haloarcula/" class="Nav_link">Haloarcula marismortui</a><br>
</tr>
<tr>
<td colspan="4"><img src="/images/clear.gif" width="1" height="10" border="0"></td>
</tr>



<tr>
<td background="/images/nav_subTitles.gif"><img src="/images/clear.gif" width="1" height="18" border="0"></td>
<td background="/images/nav_subTitles.gif" colspan="2"><span class="nav_Sub">Software Links</span></td>

<td><img src="/images/nav_subTitles_cr.gif" width="11" height="18" border="0"></td>
</tr>
<tr>
<td colspan="4"><img src="/images/clear.gif" width="1" height="10" border="0"></td>
</tr>
<tr>
<td><img src="/images/clear.gif" width="1" height="10" border="0"></td>
<td><img src="/images/clear.gif" width="1" height="10" border="0"></td>
<td colspan="2">
<a href="http://www.cytoscape.org/" class="Nav_link">Cytoscape</a><br>
<a href="http://www.sbeams.org/" class="Nav_link">SBEAMS</a><br>
<BR>
<BR>
<a href="$LOGIN_URI" class="Nav_link">LOGIN</a><br>
</td>
</tr>
<tr>
<td colspan="4"><img src="/images/clear.gif" width="1" height="10" border="0"></td>
</tr>



</table>

</td>
<td width="12"><img src="/images/clear.gif" alt="" width="12" height="1" border="0"></td>
<!-- -------------------------- End Navigation Bar ------------------------ -->

<td valign="top">

  ~;


  $buf .= qq~
<!-- --------------------------- Main Page Content ------------------------ -->

<table border="0" width="100%" cellpadding="0" cellspacing="0">
<tr>
<td>
<img src="/images/clear.gif" width="1" height="15" border="0">
</td>
</tr>

  ~;


  $buf =~ s/=\"\/images/=\"$HTML_BASE_DIR\/images/g;
  #$buf =~ s/href=\"\//href=\"$HTML_BASE_DIR\//g;
  $buf =~ s/href=\"\//href=\"http:\/\/halo.systemsbiology.net\//g;
  print $buf;
  return;

}



###############################################################################
# display_ext_halo_template
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
	body  	{font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; color:#33333; line-height:1.8}


	th    	{font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; font-weight: bold;}
	td    	{font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; color:#333333;}
	form  	{font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt}
	pre   	{font-family: Courier New, Courier; font-size: ${FONT_SIZE_SM}pt}
	h1   	{font-family: Helvetica, Arial, Verdana, sans-serif; font-size: ${FONT_SIZE_HG}px; font-weight:bold; color:#0E207F;line-height:20px;}
	h2   	{font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_LG}pt; font-weight: bold}
	h3   	{font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_LG}pt; color:#FF8700}
	h4   	{font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE_LG}pt;}
	.text_link  {font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration:none; color:blue}
	.text_linkstate {font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration:none; color:#0E207F}
	.text_link:hover   {font-family: Helvetica, Arial, sans-serif; font-size: ${FONT_SIZE}pt; text-decoration:none; color:#DC842F}

	.page_header {font-family: Helvetica, Arial, sans-serif; font-size:18px; font-weight:bold; color:#0E207F; line-height:1.2}
	.sub_header {font-family: Helvetica, Arial, sans-serif; font-size:12px; font-weight:bold; color:#FF8700; line-height:1.8}
	.Nav_link {font-family: Helvetica, Arial, sans-serif; font-size:${FONT_SIZE}pt; line-height:1.3; color:#DC842F; text-decoration:none;}
	.Nav_link:hover {color: #FFFFFF; text-decoration: none;}
	.Nav_linkstate {cursor:hand; font-family:Helvetica, Arial, sans-serif; font-size:11px; color:#DC842F; text-decoration:none;}
	.nav_Sub {font-family: Helvetica, Arial, sans-serif; font-size:12px; font-weight:bold; color:#ffffff; line-height:1.3;}

	//
	-->
</style>
  ~;

  return;

}



###############################################################################
# display_ext_halo_footer
###############################################################################
sub display_ext_halo_footer {
  my $self = shift;
  my %args = @_;
  my $tooltip_footer = $self->getToolTipFooter;

  my $buf = qq~
<!-- ------------------------ End of main content ----------------------- -->

</td></tr>
</table>


</td></tr>
</table>

$tooltip_footer

<BR>
<hr size=1 noshade width="55%" align="left" color="#FF8700">
<TABLE border="0">
<TR><TD><IMG SRC="/images/ISB_symbol_tiny.jpg"></TD>
<TD><nowrap>ISB Halo Group</nowrap></A></TD></TR>
</TABLE>
<BR>
<BR>

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
