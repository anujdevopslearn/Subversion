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
use CGI::Carp qw(fatalsToBrowser croak);
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

    #### Obtain main SBEAMS object and use its http_header
    $sbeams = $self->getSBEAMS();
    my $http_header = $sbeams->get_http_header();

    print qq~$http_header
	<HTML><HEAD>
	<TITLE>$DBTITLE - MicroArray</TITLE>
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
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" TOPMARGIN=0 LEFTMARGIN=0 >
	<table border=0 width="100%" cellspacing=0 cellpadding=0>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
		<td colspan=3>
			<table border=0 width=100% cellspacing=0 cellpadding=0>
				<tr>
				  <td bgcolor="#000000" align=left><img alt="MICROARRAY" src="$HTML_BASE_DIR/images/microarray.gif"></td>
				  <td bgcolor="#000000" align=right valign=center><font color="#ffffff"><a href="$CGI_BASE_DIR/logout.cgi"><img src="$HTML_BASE_DIR/images/logout.gif" border=0 alt="LOGOUT"></a><img src="$HTML_BASE_DIR/images/space.gif" height=1 width=25></td>
				</tr>
			</table>
		</td>
	</tr>

    ~;

    #print ">>>http_header=$http_header<BR>\n";

    if ($navigation_bar eq "YES") {
      print qq~
	<!------- Button Bar -------------------------------------------->
	<tr><td bgcolor="#ffffff" align="left" valign="top" width="150">
	<table bgcolor="#ffffff" border=0 width="100%" cellpadding=2 cellspacing=0>
	<tr><td><a href="$CGI_BASE_DIR/main.cgi"><img src="$HTML_BASE_DIR/images/ma_sbeams_home.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi"><img src="$HTML_BASE_DIR/images/ma_array_home.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ProjectHome.cgi"><IMG SRC="$HTML_BASE_DIR/images/ma_project_home.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GridAlignCheck.cgi"><img src="$HTML_BASE_DIR/images/ma_alignment_check.jpg"></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ProjectHome.cgi?tab=data_analysis"><img src="$HTML_BASE_DIR/images/ma_data_analysis.jpg"></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ProcessProject.cgi"><img src="$HTML_BASE_DIR/images/ma_pipeline.jpg"></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ProjectHome.cgi?tab=miame_status"><img src="$HTML_BASE_DIR/images/ma_miame_status.jpg"></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SubmitArrayRequest.cgi?TABLE_NAME=array_request"><img src="$HTML_BASE_DIR/images/ma_array_requests.jpg"></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=protocol"><img src="$HTML_BASE_DIR/images/ma_protocols.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=labeling"><img src="$HTML_BASE_DIR/images/ma_labeling.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=hybridization"><img src="$HTML_BASE_DIR/images/ma_hybridization.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=array_quantitation"><img src="$HTML_BASE_DIR/images/ma_quantitation.jpg"></a></td></tr>
    ~;

      $current_work_group_name = $sbeams->getCurrent_work_group_name();
      if ($current_work_group_name eq "Microarray_admin" || $current_work_group_name eq "Admin" || 1) {
       print qq~
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=contact"><img src="$HTML_BASE_DIR/images/ma_contacts.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=array"><img src="$HTML_BASE_DIR/images/ma_arrays.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=array_scan"><img src="$HTML_BASE_DIR/images/ma_array_scans.jpg"></a></td></tr>
       ~;
      }

      $current_work_group_name = $sbeams->getCurrent_work_group_name();
      if ($current_work_group_name eq "Microarray_admin" || $current_work_group_name eq "Admin") {
       print qq~
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=slide_lot"><img src="$HTML_BASE_DIR/images/ma_slide_lots.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=array_layout"><img src="$HTML_BASE_DIR/images/ma_array_layout.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=printing_batch"><img src="$HTML_BASE_DIR/images/ma_printing_batches.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=slide_type"><img src="$HTML_BASE_DIR/images/ma_slide_types_costs.jpg"></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/ManageTable.cgi?TABLE_NAME=user_login"><img src="$HTML_BASE_DIR/images/ma_admin.jpg"></a></td></tr>
       ~;
      }

      print qq~
	</table>
	</td>
	<td width=5 bgcolor="#cc0000">
		<img src="$HTML_BASE_DIR/images/space.gif" width=5 height=1>
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
  document.MainForm.apply_action_hidden.value = "REFRESH";
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
  extension = ".?";
  
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
	<BR><HR SIZE="2" NOSHADE WIDTH="70%" ALIGN="CENTER">
	<center>
	<font face="Helvetica,Arial,sans-serif" size=-2>
	SBEAMS - Microarray [Under Development]<BR>
	&copy; 2002 Institute for Systems Biology<BR><BR>
	</BODY></HTML>\n\n
    ~;
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
	    print qq~
		<TD WIDTH="15">&nbsp;</TD>
		<TD BGCOLOR="$unselected_bg_color" ALIGN="CENTER" WIDTH="95" NOWRAP><A HREF="$page_link?tab=$link"><FONT COLOR="$unselected_font_color" SIZE="-1">$tab_title</FONT></A></TD>
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
