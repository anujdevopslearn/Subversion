###############################################################################
# $Id$
#
# Description : Generic Table building mechanism designed for use with cgi
#               scripts.  Default export mode is HTML; can also export as 
#               TSV.
#
# Copyright (C) 2005, Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::Connection::SBPage;

use strict;
use overload ( '""', \&asHTML );

use SBEAMS::Connection qw( $q );
use SBEAMS::Connection::DataTable;
use SBEAMS::Connection::Log;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings qw( :default );

use POSIX;

my $log = SBEAMS::Connection::Log->new();

##### Public Methods ###########################################################
#
# Method to produce standard SBEAMS server web page

#+
# Constructor method.  Any name => value parameters passed will be appended
# as table attributes
#
sub new {
  my $class = shift;
  my $this = { user_context => 1,
               @_,
             };
  bless $this, $class;
  return $this;
}

sub setSBEAMS {
  my $this = shift;
  my %args = @_;
  die "Missing sbeams object" unless $args{sbeams};
  $this->{sbeams} = $args{sbeams};
  return 1;
}

sub setSBEAMSMod {
  my $this = shift;
  my %args = @_;
  die "Missing sbeamsMOD object" unless $args{sbeamsMOD};
  $this->{sbeamsMOD} = $args{sbeamsMOD};
  return 1;
}

sub getSBEAMS {
  my $this = shift;
  return $this->{sbeams};
}

sub getSBEAMSMod {
  my $this = shift;
  return $this->{sbeamsMOD};
}

sub addContent {
  my $this = shift;
  my $content = shift;
  $this->{_content} .= $content;
}

sub printPage {
  my $this = shift;
  my $sbeams = $this->getSBEAMS();
  my $page = $this->asHTML();
  print $page;
  
}

sub asHTML {

  my $this = shift;
  my %args = @_;

  my $nav_bar = $args{'nav_bar'} || 1;

  my $sbeams = $this->getSBEAMS() || die "Must supply sbeams object";
  my $sbeamsMOD = $this->getSBEAMSMod();
   
  my $header = $sbeams->get_http_header();
  my $onload = ( $this->{onload} ) ? $this->{onload} : "self.focus()";

  if ( $this->{minimal} ) {
    $log->debug( "minimosity!" );
    return <<"    END";
$header


<HTML>
 <HEAD></HEAD>
 <BODY OnLoad='$onload;'>
 $this->{_content}
 </BODY>
</HTML>
    END
  }
    

  
  my $jscript = $this->_getJavascriptFunctions();
  my $sort_js = ( $this->{sortable} ) ? $sbeams->getSortableHTML() : ''; 
  my $style = $this->_getStyleSheet();
  my $navbar = $this->_getNavBar( $sbeams );
  my $footer = $this->_getFooter();


  #### Determine the Title bar background decoration
  my $head_bkg = ( $DBVERSION =~ /Primary/ ) ? "$HTML_BASE_DIR/images/plaintop.jpg" : $BGCOLOR;
  my $head_tag = ($DBVERSION =~ /Primary/) ?  'BACKGROUND' : 'BGCOLOR';
  my $padding = '&nbsp;' x 300;
  my $mpad = '&nbsp;' x 5;

  my $maintab = SBEAMS::Connection::DataTable->new( BORDER => 0, WIDTH => '60%', CELLPADDING => 0, CELLSPACING => 0 );
  my $isblink =<<"  END_LINK";
  <a href="http://db.systemsbiology.net/">
   <img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmlclear.gif">
  </a>
  <a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi">
    <img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmltblue.gif">
  </a>
  END_LINK

  my $banner = $this->_getBanner( $sbeams );

  my $context = ( $this->{user_context} ) ? $this->_getUserContext( $sbeams ) : '';

  my $mainpage =<<"  END_MAIN"; 
  <BR>
  <!--------  User Context ---------------------------------------------------->
  $context
  <!-------- Main Page -------------------------------------------------------->
  $padding
  $mpad <TABLE CELLPADDING=1><TR><TD>$this->{_content}</TD></TR></TABLE>
  END_MAIN

  $maintab->addRow( [ $isblink, $banner ] );
  $maintab->addRow( [ $navbar, $mainpage ] );

  $maintab->setCellAttr( ROW => 1, COL => 1, ALIGN => 'LEFT', 
                         BGCOLOR => $BARCOLOR, NOWRAP => 1 ); 

  $maintab->setCellAttr( ROW => 1, COL => 2, $head_tag => $head_bkg,
                         ALIGN => 'LEFT', NOWRAP => 1 ); 

  $maintab->setCellAttr( ROW => 2, COL => 1,  BGCOLOR => "#CDD1E7",
                         ALIGN => 'LEFT', NOWRAP => 1, VALIGN => 'TOP' ); 

  $maintab->setCellAttr( ROW => 2, COL => 2, VALIGN => 'TOP',
                         ALIGN => 'LEFT' ); 

  my $page =<<"  END_PAGE";
$header


  <HTML>
  <HEAD>
  <TITLE>$DBTITLE - Systems Biology Experiment Analysis Management System</TITLE>
	<!--META HTTP-EQUIV="Expires" CONTENT="Fri, Jun 12 1981 08:20:00 GMT"-->
	<!--META HTTP-EQUIV="Pragma" CONTENT="no-cache"-->
	<!--META HTTP-EQUIV="Cache-Control" CONTENT="no-cache"-->
	</HEAD>
	<!-- Background white, links blue (unvisited), navy (visited), red (active) -->
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" TOPMARGIN=0 LEFTMARGIN=0 OnLoad="$onload;">
	<a name="TOP"></a>

  <!------- Javascript functions --------------------------------------------->
  $jscript
  $sort_js

  <!------- Stylesheet ------------------------------------------------------->
  $style

  $maintab

  $footer
  END_PAGE

  return $page;

}

##### Private Methods #########################################################

sub _getFooter {
  my $this = shift;

  my $module_name = ( $SBEAMS_PART ) ? " - $SBEAMS_PART" : '';

  return <<"  END";
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
  END

}


sub _getNavBar {

  my $this = shift;
  my $sbeams = shift;

  if ( $this->getSBEAMSMod() ) {
    my $sbeamsMOD = $this->getSBEAMSMod();
    my $menu;
    # Try to call getMenu method on sbeamMOD object
    eval { $menu = $sbeamsMOD->getMenu( sbeams => $sbeams ) };
    $log->debug( $@ );

    # Return menu if we got one
    return $menu if $menu;
  }

  my $ntable = SBEAMS::Connection::DataTable->new( CELLPADDING => 2 );

	$ntable->addRow( [ "<A HREF='$CGI_BASE_DIR/main.cgi'>$DBTITLE Home</A>" ] );
	$ntable->addRow( [ "<A HREF='$CGI_BASE_DIR/ChangePassword'>Change Password</A>" ] );
	$ntable->addRow( [ "<A HREF='$CGI_BASE_DIR/logout.cgi'>Logout</A>" ] );
	$ntable->addRow( [ '&nbsp;' ] );
	$ntable->addRow( [ 'Available Modules' ] );

  my $mpad = '&nbsp;' x 4;

  # Get the list of Modules 
  my @modules = $sbeams->getModules();
  foreach my $mod ( @modules ) {
	  $ntable->addRow( [ "<a href='$CGI_BASE_DIR/$mod/main.cgi'>$mpad $mod</a>" ] );
  }

	$ntable->addRow( [ '&nbsp;' ] );

  my $ia = $sbeams->isAdminUser();

  if ( $sbeams->isAdminUser ) {
	  $ntable->addRow( [ '&nbsp;' ] );
	  $ntable->addRow( [ "<A HREF='$CGI_BASE_DIR/ManageTable.cgi?TABLE_NAME=user_login'>Admin</a>" ] );
  }

  $ntable->addRow( [ '&nbsp;' ] );
  $ntable->addRow( [ "<A HREF='$CGI_BASE_DIR/Help?document=index''>Documentation</a>" ] );
  $ntable->setColAttr( COLS => [1], ROWS => [ 1..$ntable->getRowNum()], NOWRAP => 1 );

  return( <<"  END_NAV" );
  <!-------- Navagation Bar -------------------------------------------------->
  $ntable
  END_NAV
}

sub _getBanner {
  my $this = shift;
  my $sbeams = shift;
  if ( $this->getSBEAMSMod() ) {
    my $sbeamsMOD = $this->getSBEAMSMod();
    my $banner;
    # Try to call getMenu method on sbeamMOD object
    eval { $banner = $sbeamsMOD->getBanner( sbeams => $sbeams ) };
    $log->debug( $@ );

    # Return Banner if we got one
    return $banner if $banner;
  }
  return <<"  END_BAN";
  <H1>$DBTITLE - Systems Biology Experiment Analysis Management System<BR> $DBVERSION </H1>
  END_BAN


}


###############################################################################
#
# Return the standard style sheet for pages.  Use a font size of 10pt if
# remote client is on Windows, else use 12pt.  This ends up making fonts
# appear the same size on Windows+IE and Linux+Netscape.  Other tweaks for
# different browsers might be appropriate.
###############################################################################
sub _getStyleSheet {
    my $this = shift;

    my $font_size=9;
    my $font_size_sm=8;
    my $font_size_lg=12;
    my $font_size_hg=14;

    if ( $ENV{HTTP_USER_AGENT} =~ /Mozilla\/4.+X11/ ) {
      $font_size=12;
      $font_size_sm=11;
      $font_size_lg=14;
      $font_size_hg=19;
    }


  return <<"  END_STYLE";
	<style type="text/css">
	//<!--
	body {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size}pt}
	th   {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size}pt; font-weight: bold;}
	td   {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size}pt;}
	form   {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size}pt}
	pre    {  font-family: Courier New, Courier; font-size: ${font_size_sm}pt}
	h1   {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size_hg}pt; font-weight: bold}
	h2   {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size_lg}pt; font-weight: bold}
	h3   {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size_lg}pt}
	h4   {  font-family: AHelvetica, rial, sans-serif; font-size: ${font_size_lg}pt}
	A.h1 {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size_hg}pt; font-weight: bold; text-decoration: none; color: blue}
	A.h1:link {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size_hg}pt; font-weight: bold; text-decoration: none; color: blue}
	A.h1:visited {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size_hg}pt; font-weight: bold; text-decoration: none; color: darkblue}
	A.h1:hover {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size_hg}pt; font-weight: bold; text-decoration: none; color: red}
	A:link    {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size}pt; text-decoration: none; color: blue}
	A:visited {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size}pt; text-decoration: none; color: darkblue}
	A:hover   {  font-family: Helvetica, Arial, sans-serif; font-size: ${font_size}pt; text-decoration: underline; color: red}
	A:link.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	A:visited.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	A:hover.nav {  font-family: Helvetica, Arial, sans-serif; color: red;}
	.nav {  font-family: Helvetica, Arial, sans-serif; color: #000000}
	.grey_bg{ background-color: #CCCCCC }
	.med_gray_bg{ background-color: #CCCCCC; ${font_size_lg}pt; font-weight: bold; Padding:2}
	.grey_header{ font-family: Helvetica, Arial, sans-serif; color: #000000; font-size: ${font_size_hg}pt; background-color: #CCCCCC; font-weight: bold; padding:1 2}
	.rev_gray{background-color: #555555; ${font_size_lg}pt; font-weight: bold; color:white; line-height: 25px;}
	.blue_bg{ font-family: Helvetica, Arial, sans-serif; background-color: #4455cc; ${font_size_hg}pt; font-weight: bold; color: white}
	.orange_bg{ background-color: #FFCC66; ${font_size_lg}pt; font-weight: bold}
	.red_bg{ background-color: #882222; ${font_size_lg}pt; font-weight: bold; color:white;}
	.small_cell {font-size: 8; background-color: #CCCCCC; white-space: nowrap  }
	.anno_cell {white-space: nowrap  }
	.present_cell{border: none}
	.marginal_cell{border: 1px solid #0033CC}
	.absent_cell{border: 2px solid #660033}
	.small_text{font-family: Helvetica,Arial,sans-serif; font-size:x-small; color:#aaaaaa}
	.table_setup{border: 0px ; border-collapse: collapse;   }
	.pad_cell{padding:5px;  }
	
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
	
	//-->
	</style>
  END_STYLE
}


###############################################################################
# getJavascriptFunctions
#
# Return the standard Javascript functions that should appear at the top of
# most pages.  There probably should be some customization allowance here.
# Not sure how to design that yet.
###############################################################################
sub _getJavascriptFunctions {
    my $this = shift;
    my $javascript_includes = shift;


  return <<"  END";
  <SCRIPT LANGUAGE="JavaScript"><!--

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

  --></SCRIPT>
  END

}


sub _getUserContext {
  my $this = shift;
  my $sbeams = shift;
  my %args = @_;

  #### Define standard variables
  my $style = 'HTML';
  my ($work_group_sql, $project_sql, @rows);
  my ($work_group_chooser, $project_chooser);

  #### Find sub directory
  my $subdir = $sbeams->getSBEAMS_SUBDIR();
  $subdir .= "/" if ($subdir);

  #### Get all relevant user information
  my $current_username = $sbeams->getCurrent_username;
  my $current_contact_id = $sbeams->getCurrent_contact_id;
  my $current_work_group_id = $sbeams->getCurrent_work_group_id;
  my $current_work_group_name = $sbeams->getCurrent_work_group_name;
  my $current_project_id = $sbeams->getCurrent_project_id;
  my $current_project_name = $sbeams->getCurrent_project_name;
  my $current_user_context_id = $sbeams->getCurrent_user_context_id;


  #### The guest user should never be presented with sbeams
  if ($current_username eq 'guest') {
    return;
  }

  #### Find out the current URI
  my $submit_string = $ENV{'SCRIPT_URI?'} || '';
  my $context = '';

  # Bail if not in HTML mode
  return unless ($style eq "HTML");

  $context =<<"  END";
  <SCRIPT LANGUAGE="Javascript">
  function switchWorkGroup(){
  var chooser = document.userChooser.workGroupChooser;
  var val = chooser.options[chooser.selectedIndex].value;
  if (document.MainForm == null) {
    document.groupChooser.set_current_work_group.value = val;
    document.groupChooser.submit();
  }else {
    document.MainForm.set_current_work_group.value = val;
    if (document.MainForm.apply_action_hidden != null){
      document.MainForm.apply_action_hidden.value = "REFRESH";
    }
    if (document.MainForm.action != null) {
      document.MainForm.action.value = "REFRESH";
    }
    if (document.MainForm.insert_with_template != null) {
      document.MainForm.insert_with_template.value = 0;
    }

    document.MainForm.submit();
    }
  }

  function switchProject(){
  var chooser = document.userChooser.projectIDChooser;
  var val = chooser.options[chooser.selectedIndex].value;
  if (document.MainForm == null) {
    document.projectChooser.set_current_project_id.value = val;
    document.projectChooser.submit();
  }else {
    document.MainForm.set_current_project_id.value = val;
    if (document.MainForm.apply_action_hidden != null){
      document.MainForm.apply_action_hidden.value = "REFRESH";
    }
    if (document.MainForm.action != null) {
      document.MainForm.action.value = "REFRESH";
    }
    if (document.MainForm.insert_with_template != null) {
      document.MainForm.insert_with_template.value = 0;
    }
    document.MainForm.submit();
    }
  }
  </SCRIPT>
  END

  $work_group_sql = qq~
      SELECT WG.work_group_id,WG.work_group_name
      FROM $TB_WORK_GROUP WG
      INNER JOIN $TB_USER_WORK_GROUP UWG ON ( WG.work_group_id=UWG.work_group_id ) 
      WHERE contact_id = '$current_contact_id'
        AND WG.record_status != 'D'
        AND UWG.record_status != 'D'
      ORDER BY WG.work_group_name
      ~;
  @rows = $sbeams->selectSeveralColumns($work_group_sql);

  $work_group_chooser = "<SELECT NAME='workGroupChooser' onChange='switchWorkGroup()'>";

  foreach my $row_ref (@rows) {
    my ($work_group_id, $work_group_name) = @{$row_ref};
    my $sel = ($work_group_id == $current_work_group_id) ? 'SELECTED' : '';
    $work_group_chooser .= "<OPTION $sel VALUE='$work_group_name'>$work_group_name";
  }
  $work_group_chooser .= '</SELECT>';

  #### Get accessible projects and make <SELECT> if we're in HTML mode
  $subdir =~ tr/A-Z/a-z/;
  my @project_ids = $sbeams->getAccessibleProjects(module=>"$subdir");
  my $project_ids_list = join(',',@project_ids) || '-1';
  $project_sql = qq~
    SELECT P.project_id, UL.username+' - '+P.name
      FROM $TB_PROJECT P 
      LEFT JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id = UL.contact_id )
     WHERE P.project_id IN ( $project_ids_list )
       AND P.record_status != 'D'
       AND UL.record_status != 'D'
     GROUP BY P.project_id, P.name, UL.username
     ORDER BY UL.username, P.name
  ~;

  @rows = $sbeams->selectSeveralColumns($project_sql);
  $project_chooser = '<SELECT NAME="projectIDChooser" onChange="switchProject()">';

  foreach my $row_ref (@rows) {
    my ($project_id, $project_name) = @{$row_ref};
    if ($project_id == $current_project_id) {
    	$project_chooser .= qq~
      <OPTION SELECTED VALUE="$project_id">$project_name ($project_id)
      ~;
    } else {
      $project_chooser .= qq~
      <OPTION VALUE="$project_id">$project_name ($project_id)
       ~;
    }
  }
  $project_chooser .= '</SELECT>';
	
  my $temp_current_work_group_name = $current_work_group_name;
  if ($current_work_group_name eq "Admin") {
    $temp_current_work_group_name = "<FONT COLOR=red><BLINK>$current_work_group_name</BLINK></FONT>";
  }
  my $pad = '&nbsp;' x 2;
  my $hidden = '';

  my @params = $q->param();
  for my $p (@params) {
    my $v = $q->param( $p );
    $hidden .= "<INPUT TYPE=HIDDEN NAME=$p VALUE=$v>";
  }
  
  $context .=<<"  END";
  <FORM NAME="userChooser">
  <TABLE WIDTH="100%"  CELLPADDING="0">
   <TR>
    <TD NOWRAP>
    <IMG SRC="$HTML_BASE_DIR/images/bullet.gif">
    Login:$pad<B> $current_username</B> ($current_contact_id) $pad Group: $pad $work_group_chooser
    </TD>
   </TR>

   <TR>
    <TD NOWRAP>
    <IMG SRC="$HTML_BASE_DIR/images/bullet.gif">Project:$project_chooser
    </TD>
   </TR>
  </TABLE>
  </FORM>

  <FORM NAME="projectChooser" METHOD="GET" ACTION="$submit_string">
  $hidden
  <INPUT TYPE="hidden" NAME="set_current_project_id">
  </FORM>

  <FORM NAME="groupChooser" METHOD="GET" ACTION="$submit_string">
  $hidden
  <INPUT TYPE="hidden" NAME="set_current_work_group">
  </FORM>
  END

  return $context;
}

__DATA__
    
  #### PRINT TEXT ####
  if ($style eq "TEXT") {
    print qq!Current Login: $current_username ($current_contact_id)  Current Group: $current_work_group_name ($current_work_group_id)
	Current Project: $current_project_name ($current_project_id)
	!;
}
