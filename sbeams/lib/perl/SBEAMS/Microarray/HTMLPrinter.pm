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
use CGI::Carp qw( croak);
use SBEAMS::Connection qw( $log $q );
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

  #### If the output mode is interactive text, display text header
  my $sbeams = $self->getSBEAMS();
  if ($sbeams->output_mode() eq 'interactive') {
    $sbeams->printTextHeader();
    return;
  }

  #### If the output mode is not html, then we don't want a header here
  if ($sbeams->output_mode() ne 'html') {
    if ( $sbeams->output_mode() eq 'print') {
      print $sbeams->get_http_header();
      $self->printStyleSheet();
      print "<TABLE border=0 CELLPADDING=5 CELLSPACING=5><TR><TD>\n";
    }
    return;
  }


  #### Obtain main SBEAMS object and use its http_header
  $sbeams = $self->getSBEAMS();

	$current_contact_id = $sbeams->getCurrent_contact_id();
	
	if ($sbeams->getCurrent_contact_id() ne 107)
	{
    $self->displaySBEAMSPageHeader(@_);
	}
	else # Currently only guest mode is SCGAP, will likely change...
	{
		$self->displaySCGAPPageHeader(@_);
	}
}


sub displaySCGAPPageHeader
{ 
	my $self = shift;
  my %args = @_;

  #### Obtain main SBEAMS object and use its http_header
  my $sbeams = $self->getSBEAMS();
  my $http_header = $sbeams->get_http_header();
  use LWP::UserAgent;
  use HTTP::Request;
  my $ua = LWP::UserAgent->new();
  my $scgapLink = 'http://scgap.systemsbiology.net';
  my $response = $ua->request( HTTP::Request->new( GET => "$scgapLink/skin.php" ) );
  my @page = split( "\n", $response->content() );
  my $skin = '';
  my $cnt = 0;
  for ( @page ) {
    $cnt++;
    last if $_ =~ / End of main content/;
    $skin .= $_;
  }
  $self->{'_external_footer'} = join( "\n", @page[$cnt..$#page] );
  $skin =~ s/\/images\//\/sbeams\/images\//gm;
 
	
  my $affy_css = $self->getAffyCSS();
  print "$http_header\n\n";
  print <<"  END_PAGE";
  <HTML>
    $affy_css
    $skin
  END_PAGE

  $self->printJavascriptFunctions();
}
sub getAffyCSS {
  my $self = shift;
  my $FONT_SIZE=10;
  my $FONT_SIZE_SM=9;
  my $FONT_SIZE_MED=10;
  my $FONT_SIZE_LG=11;
  my $FONT_SIZE_HG=12;

  my $css =<<"  END";
	<STYLE TYPE="text/css">	
	.white_bg{background-color: #FFFFFF }
	.grey_bg{ background-color: #CCCCCC }
	.med_gray_bg{ background-color: #CCCCCC; font-size: ${FONT_SIZE_LG}pt; font-weight: bold; Padding:2}
	.grey_header{ font-family: Helvetica, Arial, sans-serif; color: #000000; font-size: ${FONT_SIZE_HG}pt; background-color: #CCCCCC; font-weight: bold; padding:1 2}
	.rev_gray{background-color: #555555; font-size: ${FONT_SIZE_MED}pt; font-weight: bold; color:white; line-height: 25px;}
	.rev_gray_head{background-color: #555555; font-size: ${FONT_SIZE}pt; font-weight: bold; color:white; line-height: 25px;}
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
  END

  my $agent = $q->user_agent();
  if ( $agent =~ /MSIE/ ) {
    $css .= " .med_vert_cell {font-size: 10; background-color: #CCCCCC; white-space: nowrap; writing-mode: tb-rl; filter: flipv fliph;  }\n";
  }
  $css .= "</style>\n";

  return $css;
}

sub displaySBEAMSPageHeader
{
	my $self = shift;
  my %args = @_;

  #### Obtain main SBEAMS object and use its http_header
  my $sbeams = $self->getSBEAMS();
  my $http_header = $sbeams->get_http_header();

  my $navigation_bar = $args{'navigation_bar'} || "YES";

  print qq~$http_header
	<HTML><HEAD>
	<TITLE>$DBTITLE - $SBEAMS_PART</TITLE>
  ~;

  $self->printJavascriptFunctions();
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
	  <td WIDTH="100%" align="left" $header_bkg><H1>  $DBTITLE - $SBEAMS_PART<BR> $DBVERSION</H1></td>
	</tr>

    ~;

  if ($navigation_bar eq "YES") {
  
    my $pad = '<NOBR>&nbsp;&nbsp;&nbsp;';
    my $affy_docs = ( $CONFIG_SETTING{MA_AFFY_HELPDOCS_URL} =~ /http/ ) ?
  		"<tr><td><a href='$CONFIG_SETTING{MA_AFFY_HELPDOCS_URL}'>$pad Affy Help Docs</a></td></tr>" :
      "<tr><td><a href='$HTML_BASE_DIR/doc/Microarray/affy_help_pages/index.php'>$pad Affy Help Docs</a></td></tr>";
  
    $current_work_group_name = $sbeams->getCurrent_work_group_name();

      
    my $mod_link = ucfirst( lc($SBEAMS_PART) );

    my $affy =<<"    END";
    <TABLE>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/bioconductor/upload.cgi">$pad Data Pipeline</td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/dataDownload.cgi?type=affy">$pad Download Data</td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetExpression">$pad Get Expression</td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetAffy_GeneIntensity.cgi">$pad Affy Gene Intensity</td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/bioconductor/Add_affy_annotation.cgi">$pad Annotate Files</td></tr>
    <tr><td>$affy_docs</td></tr>
    <tr><td>&nbsp;</td></tr>
    </TABLE>
    END
    my ($af_content, $af_link) = $sbeams->make_toggle_section( content => $affy,
                                                                  name => 'ma_affy_toggle',
                                                                sticky => 1,
                                                               visible => 1 );
    print qq~
  	<!------- Button Bar ------------------------------------------>
	
    <tr><td bgcolor="$BARCOLOR" align="left" valign="top">
    <table border=0 width="120" cellpadding=1 cellspacing=0>
    <tr><td><a href="$CGI_BASE_DIR/main.cgi">$DBTITLE Home</a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$mod_link/main.cgi">$mod_link Home</a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
    <tr><td>&nbsp;</td></tr>
    <tr><td NOWRAP>$af_link Affymetrix Arrays: </td></tr>
    <tr><td>$af_content </td></tr>
     ~;

    my $two_color_section = '';
    unless ( $CONFIG_SETTING{MA_HIDE_TWO_COLOR} ) {
      my $two_color =<<"      END";
      <TABLE>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/PipelineSetup.cgi">$pad Data Pipeline</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/dataDownload.cgi?type=2color">$pad Download Data</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetExpression">$pad Get Expression</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/graphicalOverview.cgi">$pad Graphical Overview</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SubmitArrayRequest.cgi?TABLE_NAME=MA_array_request">$pad Array Requests</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_labeling">$pad Labeling</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_hybridization">$pad Hybridization</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_array_quantitation">$pad Quantitation</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GridAlignCheck.cgi">$pad Check Alignment </a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?mode=miame_status">$pad MIAME Status</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?mode=management">$pad Manage Arrays</a>
      </td></tr>
      <tr><td>
        <a href="http://db.systemsbiology.net/software/ArrayProcess" TARGET=_blank>$pad Pipeline Help</a>
      </td></tr>
      <tr><td>&nbsp;</td></tr>
      </TABLE>
      END
      my ($tc_content, $tc_link) = $sbeams->make_toggle_section( content => $two_color,
                                                                  sticky => 1,
                                                                    name => 'ma_twocolor_toggle');
      $two_color_section = qq~
      <tr><td NOWRAP>$tc_link Two Color Arrays:</td></tr>
      <tr><td>$tc_content</td></tr>
      ~;
    }

    my $admin_section = '';
    if ($current_work_group_name eq "Microarray_admin" || $current_work_group_name eq "Admin" ) {
      my $admin =<<"      END";
      <TABLE>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_array">$pad Arrays</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_array_scan">$pad Array scans</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_slide_lot">$pad Slide Lots</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_array_layout">$pad Array Layouts</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_printing_batch">$pad Printing Batches</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_slide_type">$pad Slide Types</a>
      </td></tr>
      <tr><td>
        <a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=protocol">$pad Protocols</a>
      </td></tr>
      </TABLE>
      END
      my ($ad_content, $ad_link) = $sbeams->make_toggle_section( content => $admin, 
                                                                    name => 'ma_admin_toggle',
                                                                  sticky => 1,
                                                                 visible => 1 );
      $admin_section =<<"      END";
	    <tr><td NOWRAP>$ad_link Administration: </td></tr>
	    <tr><td>$ad_content </td></tr>
	    <tr><td>&nbsp; </td></tr>
      END
    }

    my $message = $sbeams->get_page_message();
    my $notice = $sbeams->get_notice( 'Microarray' );
    if ( $message ) {
      $message .= "<BR>$notice\n" if $message;
    } else {
      $message = $notice if $notice;
    }

    print qq~
    $two_color_section
    $admin_section
	  </table>
	  </td>

	  <!-------- Main Page ------------------------------------------->
	  <td valign=top>
	  <table border=0 bgcolor="#ffffff" cellpadding=4>
	  <tr><td>$message
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

    #### Obtain main SBEAMS object and use its style sheet
    $sbeams = $self->getSBEAMS();
    $sbeams->printStyleSheet();

}

sub getBanner {
  my $this = shift;
  my $header_bkg = "bgcolor=\"$BGCOLOR\"";
  $header_bkg = "background=\"/images/plaintop.jpg\"" if ($DBVERSION =~ /Primary/);
  return <<"  END_BANNER";
  <table border=0 width=100% cellspacing=0 cellpadding=0>
	<tr>
	  <td WIDTH="100%" align="left" $header_bkg><H1>  $DBTITLE - $SBEAMS_PART<BR> $DBVERSION</H1></td>
	</tr>
  </table>
  END_BANNER
  return <<"  END_BANNER"
  <table border=0 width=100% cellspacing=0 cellpadding=0>
    <tr>
      <td bgcolor="#000000" align=left><img alt="MICROARRAY" src="$HTML_BASE_DIR/images/microarray.gif"></td>
      <td bgcolor="#000000" align=right valign=center><font color="#ffffff"><a href="$CGI_BASE_DIR/logout.cgi"><img src="$HTML_BASE_DIR/images/logout.gif" border=0 alt="LOGOUT"></a><img src="$HTML_BASE_DIR/images/space.gif" height=1 width=25></td>
    </tr>
  </table>
  END_BANNER
}

sub getMenu {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();

  my $pad = '<NOBR>&nbsp;&nbsp;&nbsp;';
  my $affy_docs = ( $CONFIG_SETTING{Microarray_affy_help_docs_url} =~ /http/ ) ?
  		"<tr><td><a href='$CONFIG_SETTING{Microarray_affy_help_docs_url}'>$pad Affy Help Docs</a></td></tr>" :
      "<tr><td><a href='$HTML_BASE_DIR/doc/Microarray/affy_help_pages/index.php'>$pad Affy Help Docs</a></td></tr>";

  $current_work_group_name = $sbeams->getCurrent_work_group_name();

  my $admin_menu;
  if ($current_work_group_name eq "Microarray_admin" || $current_work_group_name eq "Admin" ) {
    $admin_menu =<<"    END";
    <tr><td>Administration: </td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_array">$pad Arrays</a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_array_scan">$pad Array scans</a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_slide_lot">$pad Slide Lots</a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_array_layout">$pad Array Layouts</a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_printing_batch">$pad Printing Batches</a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_slide_type">$pad Slide Types</a></td></tr>
    <tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=protocol">$pad Protocols</a></td></tr>
    END
  }
  $BARCOLOR ||= '#FFFFFF';
  my $mod_link = ucfirst( lc($SBEAMS_PART) );
      
  my $menu =<<"  END";
	<table bgcolor=$BARCOLOR border=0 width="100%" cellpadding=2 cellspacing=0>

  <!-- Standard bloc -->
	<tr><td><a href="$CGI_BASE_DIR/main.cgi">$DBTITLE Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$mod_link/main.cgi">$mod_link Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
  <tr><td>&nbsp;</td></tr>

	<tr><td>Affymetrix Arrays: </td></tr>
  <!--<A HREF="$CGI_BASE_DIR/main.cgi"><IMG SRC=$HTML_BASE_DIR/images/home_small.gif></A>-->
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/bioconductor/upload.cgi">$pad Data Pipeline</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/dataDownload.cgi?type=affy">$pad Download Data</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetExpression">$pad Get Expression</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetAffy_GeneIntensity.cgi">$pad Affy Gene Intensity</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/bioconductor/Add_affy_annotation.cgi">$pad Annotate Files</td></tr>
	<tr><td>$affy_docs</td></tr>
	<tr><td>&nbsp;</td></tr>
  END
  
  unless ( $CONFIG_SETTING{MA_HIDE_TWO_COLOR} ) {
     $menu .=<<"    END";
    <tr><td>Two Color Arrays:</td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/PipelineSetup.cgi">$pad Data Pipeline</td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/dataDownload.cgi?type=2color">$pad Download Data</td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetExpression">$pad Get Expression</td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/graphicalOverview.cgi">$pad Graphical Overview</td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SubmitArrayRequest.cgi?TABLE_NAME=MA_array_request">$pad Array Requests</td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_labeling">$pad Labeling</a></td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_hybridization">$pad Hybridization</a></td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=MA_array_quantitation">$pad Quantitation</a></td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GridAlignCheck.cgi">$pad Check Alignment </td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?mode=miame_status">$pad MIAME Status</td></tr>
  	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?mode=management">$pad Manage Arrays</td></tr>
        <tr><td><a href="http://db.systemsbiology.net/software/ArrayProcess" TARGET=_blank>$pad Pipeline Help</td></tr>
  	<!--<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/graphicalOverview.cgi?tab=news_and_links">$pad News and Links</td></tr>-->  
    END
  }

  $menu .=<<"  END";
  $admin_menu
  </table>
  END

  return $menu;
      
  # This code never gets reached for now, update when needed.
  if ( exists $CONFIG_SETTING{MA_AFFY_HELPDOCS_URL} && $CONFIG_SETTING{MA_AFFY_HELPDOCS_URL} =~ /http/){
    $menu .=<<"    END";
		<tr><td><a class='blue_button' href="$CONFIG_SETTING{MA_AFFY_HELPDOCS_URL}">Affy Help Docs</a></td></tr>
    END
  } else {
    $menu .=<<"    END";
    <tr><td><a class='blue_button' href="$HTML_BASE_DIR/doc/Microarray/affy_help_pages/index.php">Affy Help Docs</a></td></tr>
    END
  }	
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
  document.MainForm.apply_action_hidden.value = "REFRESH";
  document.MainForm.project_select_change.value = "TRUE";
  document.MainForm.submit();
}

function refreshPairWiseOnly()
{
    document.MainForm.pair_wise_only.value = "YES";
	document.MainForm.submit();
}

function showPassed(input_field) {
  confirm( "selected option ="+document.MainForm.slide_id.options[document.MainForm.slide_id.selectedIndex].text+"=");
  return;
}

function confirmPasswdChange() {
  if (confirm( "The old password for this user will no longer be "+"valid.")) {
    return true;
  }else {
    return false;
  }
}

function ClickedNowButton(input_field) {
  field_name = input_field.name;
  today = new Date();
  date_value =
      today.getFullYear() + "-" + (today.getMonth()+1) + "-" +
      today.getDate() + " " +
      today.getHours() + ":" +today.getMinutes();
  
  if (field_name == "date_labeled") {
      document.MainForm.date_labeled.value = date_value;
  }else if (field_name == "date_hybridized") {
      document.MainForm.date_hybridized.value = date_value;
  }else if (field_name == "date_received") {
      document.MainForm.date_received.value = date_value;
  }else if (field_name == "date_scanned") {
      document.MainForm.date_scanned.value = date_value;
  }else if (field_name == "date_quantitated") {
      document.MainForm.date_quantitated.value = date_value;
  }

  return;
}

function setDefaultImagesLocation() {
    array_name = document.MainForm.array_id.options[document.MainForm.array_id.selectedIndex].text;
    if (array_name.substr(array_name.length-9,99) == " - *DONE*") {
      array_name = array_name.substr(0,array_name.length-9);
    }

    serial_number = array_name;
    if (serial_number.substr(serial_number.length-1,99) >= "A") {
      serial_number = serial_number.substr(0,array_name.length-1);
    }

    today = new Date();
    date_value =
	"" + today.getFullYear() +
	addLeadingZeros((today.getMonth()+1),2) +
	addLeadingZeros(today.getDate(),2)
	date_value = date_value.substr(2,6);

    start_group = Math.round(serial_number/100-0.5)*100+1;
    start_group = addLeadingZeros(start_group.toString(),5);

    end_group = Math.round(serial_number/100+0.5)*100;
    end_group = addLeadingZeros(end_group.toString(),5);

    array_name = addLeadingZeros(array_name.toString(),5);

    document.MainForm.stage_location.value =
	"/net/arrays/ScanArray_Images/" +
	start_group + "-"+ end_group + "/" +
	array_name + "_" + date_value;
    return;
}

function addLeadingZeros(instring,ndigits) {
  instring = instring.toString();
  while (instring.length < ndigits) { instring = "0" + instring; }
  return instring;
}

function setDefaultQALocation() {
  array_name = document.MainForm.array_scan_id.options[document.MainForm.array_scan_id.selectedIndex].text;
  array_name = array_name.toString();
  if (array_name.substr(array_name.length-9,99) == " - *DONE*") {
    array_name = array_name.substr(0,array_name.length-9);
  }

  start_group = Math.round(array_name/100-0.5)*100+1;
  start_group = addLeadingZeros(start_group.toString(),5);

  end_group = Math.round(array_name/100+0.5)*100;
  end_group = addLeadingZeros(end_group.toString(),5);

  protocol_name = document.MainForm.protocol_id.options[document.MainForm.protocol_id.selectedIndex].text;
  protocol_name = protocol_name.toString();
  extension = ".csv";
  
  if (protocol_name.search(/QuantArray/i)>-1) { extension = ".qa"; }
  if (protocol_name.search(/Dapple/i)>-1) { extension = ".dapple"; }

  document.MainForm.stage_location.value =
      "/net/arrays/Quantitation/" +
      start_group + "-"+ end_group + "/" +
      array_name + extension;

  return;
}

  function setArrayName() {
    array_name = document.MainForm.array_name.value=document.MainForm.slide_id.options[document.MainForm.slide_id.selectedIndex].text;
    array_name = array_name.toString();
    if (array_name.substr(array_name.length-9,99) == " - *DONE*") {
      array_name = array_name.substr(0,array_name.length-9);
    }
    while (array_name.length < 5) { array_name = "0" + array_name; }

    document.MainForm.array_name.value = array_name;
    return;
}

function setLayoutFileName() {
  document.MainForm.source_filename.value =
      "/net/arrays/Slide_Templates/" +
      document.MainForm.name.value + ".key"
      return;
}
function changetabnumber (){
    document.Selectedfiles_form._tab.value = 1;
    if(confirm("Really delete checked files?")){

    }else{
	var all_files = document.Selectedfiles_form.files;
 	var numb_files = all_files.length;
 
 	for (var i = 0; i < numb_files; i++){
 		all_files[i].value = '';
 	}
	alert("Ok none of the current " + numb_files + " files will be deleted"); 
    } 
   return;
}


// -->
</SCRIPT>
~;

}





###############################################################################
# printPageFooter
###############################################################################
sub printPageFooter {
  my $self = shift;


  #### Allow old-style single argument
  my $n_params = scalar @_;
  my %args;
  #### If the old-style single argument exists, create args hash with it
  if ($n_params == 1) {
    my $flag = shift;
    $args{close_tables} = 'NO';
    $args{close_tables} = 'YES' if ($flag =~ /CloseTables/);
    $args{display_footer} = 'NO';
    $args{display_footer} = 'YES' if ($flag =~ /Footer/);
  } else {
    %args = @_;
  }


  #### If the output mode is interactive text, display text header
  my $sbeams = $self->getSBEAMS();
  if ($sbeams->output_mode() eq 'interactive') {
    $sbeams->printTextHeader(%args);
    return;
  }


  #### If the output mode is not html, then we don't want a header here
  if ($sbeams->output_mode() ne 'html') {
    print "</TD></TR></TABLE>\n" if $sbeams->output_mode() eq 'print';
    return;
  }


  #### Process the arguments list
  my $close_tables = $args{'close_tables'} || 'YES';
  my $display_footer = $args{'display_footer'} || 'YES';
  my $separator_bar = $args{'separator_bar'} || 'NO';

  if ( $self->{'_external_footer'} ) {
    print "$self->{'_external_footer'}\n";
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
    #### Default to the Core footer
    $sbeams->display_page_footer(display_footer=>'YES');
  }

}


###############################################################################
# print_tabs
###############################################################################
sub print_tabs {
    my $self= shift;
    my %args = @_;
    my $SUB_NAME = "print_tabs";
    
## Decode argument list
    my $tab_titles_ref = $args{'tab_titles_ref'}
    || die "ERROR[$SUB_NAME]:tab_titles_ref not passed";
    my $selected_tab = $args{'selected_tab'} || 0;
    my $parent_tab = $args{'parent_tab'};
    my $page_link = $args{'page_link'}
    || die "ERROR[$SUB_NAME]:page_link not passed";
    my $unselected_bg_color   = $args{'unselected_bg_color'}   || "\#224499";
    my $unselected_font_color = $args{'unselected_font_color'} || "\#ffffff";
    my $selected_bg_color     = $args{'selected_bg_color'}     || "\#ffcc33";
    my $selected_font_color   = $args{'selected_font_color'}   || "\#000000";
    my $line_color            = $args{'line_color'}            || "\#3366cc";
    
    
    
## Define standard variables
    my @tab_titles = @{$tab_titles_ref};
    my $counter = 0;
    
## Start TABLE
    print qq~
	<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="0">
	<TR>
	~;
    
## for each desired tab, make one
    while (@tab_titles) {
	my $tab_title = shift(@tab_titles);
	my $link = $tab_title;
	while ($link =~ /\s+/) {
	    $link =~ s(\s+)(_);
	}
	$link =~ tr/A-Z/a-z/;
	if ($counter == $selected_tab) {
	    print qq~
		<TD WIDTH="15">&nbsp;</TD>
		<TD BGCOLOR="$selected_bg_color" ALIGN="CENTER" WIDTH="95" NOWRAP><FONT COLOR="$selected_font_color" SIZE="-1">$tab_title</FONT></TD>
		~;
	}else {
	    my $print_parent_tab =  $parent_tab ? "&tab=$parent_tab": '';
	    print qq~
		<TD WIDTH="15">&nbsp;</TD>
		<TD BGCOLOR="$unselected_bg_color" ALIGN="CENTER" WIDTH="95" NOWRAP><A HREF="$page_link?tab=$link$print_parent_tab"><FONT COLOR="$unselected_font_color" SIZE="-1">$tab_title</FONT></A></TD>
		~;
	}
	$counter++;
	
    }
    
## Draw line underneath tabs
    print qq~
	<TD WIDTH="15">&nbsp;</TD>
	</TR>
	<TR>
        <TD colspan=12 BGCOLOR="$line_color"><IMG WIDTH=1 height=1 alt=""></TD>
	~;
    
## Finish table
    print qq~
	</TR>
	</TABLE>
	~;
    
    return;
}


###############################################################################
# Print QuickLinks
###############################################################################
sub printQuickLinks {
	my $self = shift;
	my $q = shift;

}

###############################################################################
# change_views_javascript
###############################################################################
sub change_views_javascript {
	
	
print qq~
<SCRIPT LANGUAGE="Javascript">
<!--
function change_views_javascript(input_obj){
 var form = input_obj.form;
 var val = form.display_type.val ;
 onClick="parent.location='?display_type='" + val + "'";
 

document.get_all_files.submit();
}
//-->
</SCRIPT>
~;

}

###############################################################################
# updateCheckBoxButtons_javascript
###############################################################################
sub updateCheckBoxButtons_javascript {
  print  getUpdateCheckBoxButtonsJavascript();
}

#+
#
#-
sub getUpdateCheckBoxButtonsJavascript {

  return <<"  END_JAVASCRIPT";
<SCRIPT LANGUAGE="Javascript">
<!--
function updateCheckBoxButtons(input_obj){
 var form = input_obj.form;
 var all_checkboxes = form.click_all_files;
 var updatedVals;
 
 var regexp = /(.+?)__(.*)/; //Exmple 42__XML
 
 var results = input_obj.value.match(regexp);
  
 var file_types = new Object();
 
 for (var i=0; i<all_checkboxes.length; i ++){				//Loop through the all checkbox buttons and store their checked value in an object
 	
  	var hold = form.click_all_files[i].value;			// grab the value of the checkbox
	file_types[hold] = form.click_all_files[i].checked;		// set for each data type if it is checked or not
	
 }
 
 if (all_checkboxes.length == null){					//If there is only one element we will not get back an array and file_types will not exists
	var hold = form.click_all_files.value;
	file_types[hold] = form.click_all_files.checked;
}

 
 
 if (all_files ){

 }else{
	var all_files = form.get_all_files				//Do not re-make the all_files array if it has already been made.  Not sure why this works but it does
 }

 for (var i = 0; i<all_files.length; i ++) {
 	
 	var results = form.get_all_files[i].value.match(regexp);	//split apart the checkbox val 
 									
									//grab the file_extension
	var file_ext = results[2];					//remember that the first javascript regex match returned is the full string then the parenthesized sub expressions
 	
	var click_all_check_val =  file_types[file_ext];		//set the file extension click_all_files checked val
	 
	
	form.get_all_files[i].checked = click_all_check_val ;		//Set the checkbox to what ever the all_checkbox checked value was
	  
 
 }

  return;
}

//-->
</SCRIPT>
  END_JAVASCRIPT

}

###############################################################################
# make_checkbox_contol_table
###############################################################################
sub get_file_cbox {

	my $self = shift;
	my %args = @_;
	
	my @box_names = @{$args{box_names}};
	my @default_file_types = @ {$args{default_file_types}};
  my %cbox;
	
  foreach my $file_type (@box_names){
  my $checked = '';
			
			if ( grep {$file_type eq $_} @default_file_types) {
				$checked = "CHECKED";
			}
      $cbox{$file_type} ="<input type='checkbox' name='click_all_files' value='$file_type' $checked onClick='Javascript:updateCheckBoxButtons(this)'>"
		}
  return \%cbox;
}


sub make_checkbox_control_table {
  my $self = shift;
  my %args = @_;
  my $cbox = $self->get_file_cbox( %args );
  my $table =<<'  END';
  <TABLE BORDER=0>
  <TR><TD COLSPAN=2>Click to select or de-select all arrays</TD></TR>
  END

  for my $bname ( @{$args{box_names}} ){
    $table .= "<TR><TD>$bname</TD><TD>$cbox->{$bname}</TD></TR>";
  }
  $table .= '</TABLE>';

  # Ouch!  I'd rather return the scalar and print from the source.
  print $table;
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
