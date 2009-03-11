package SBEAMS::SolexaTrans::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::SolexaTrans::HTMLPrinter
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: HTMLPrinter.pm 5575 2008-01-25 19:52:38Z dcampbel $
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
use CGI::Carp qw( croak);
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TableInfo;

use SBEAMS::SolexaTrans::Settings;
use SBEAMS::SolexaTrans::TableInfo;


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
	  <td bgcolor="$BARCOLOR" width=130><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmlclear.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmlclear.gif"></a></td>
	  <td align="left" $header_bkg><H1>$DBTITLE - $SBEAMS_PART<BR>$DBVERSION</H1></td>
	</tr>

    ~;

    #print ">>>http_header=$http_header<BR>\n";

    if ($navigation_bar eq "YES") {
# managetable example
#	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=ST_biosequence_set"><nobr>&nbsp;&nbsp;&nbsp;BioSequenceSets</nobr></a></td></tr>
      print qq~
	<!------- Button Bar -------------------------------------------->
	<tr><td bgcolor="$BARCOLOR" align="left" valign="top">
	<table border=0 width="120" cellpadding=2 cellspacing=0>

	<tr><td><a href="$CGI_BASE_DIR/main.cgi">$DBTITLE Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_PART/main.cgi">$SBEAMS_PART Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Tag Pipeline:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/Samples.cgi"><nobr>&nbsp;&nbsp;&nbsp;Start Pipeline</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/Status.cgi"><nobr>&nbsp;&nbsp;&nbsp;Job Status and Controls</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetCounts"><nobr>&nbsp;&nbsp;&nbsp;Get Counts</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/dataDownload.cgi"><nobr>&nbsp;&nbsp;&nbsp;Download Data</nobr></a></td></tr>
        ~;


        print qq~
	<tr><td>&nbsp;</td></tr>
	<tr><td>Manage Tables:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=ST_solexa_sample"><nobr>&nbsp;&nbsp;&nbsp;Solexa Samples</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Browse Data:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseBioSequence.cgi"><nobr>&nbsp;&nbsp;&nbsp;Browse BioSeqs</nobr></a></td></tr>
        ~ if $sbeams->getCurrent_work_group_name eq 'Developer';
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
  my $close_tables = $args{'close_tables'} || 'NO';
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
    #### Default to the Core footer
    $sbeams->display_page_footer(display_footer=>'YES');
  }

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
// var all_document_checkboxes = document.getElementsByName(input_obj.name);
// var all_checkboxes = [];
// for (var i = 0; i < all_document_checkboxes.length; i++) {
//   if (all_document_checkboxes[i].form == input_obj.form) {
//     all_checkboxes.push(all_document_checkboxes[i]);
//   }
// }

 var updatedVals;

 var regexp = /(.+?)__(.*)/; //Exmple 42__XML

 var results = input_obj.value.match(regexp);
 var file_types = new Object();

 for (var i=0; i<all_checkboxes.length; i ++){                          //Loop through the all checkbox buttons and store their checked value in an object

        var hold = form.click_all_files[i].value;                       // grab the value of the checkbox
        file_types[hold] = form.click_all_files[i].checked;             // set for each data type if it is checked or not

 }

 if (all_checkboxes.length == null){                                    //If there is only one element we will not get back an array and file_types will not exists
        var hold = form.click_all_files.value;
        file_types[hold] = form.click_all_files.checked;
}



 if (all_files ){

 }else{
        var all_files = form.get_all_files                              //Do not re-make the all_files array if it has already been made.  Not sure why this works but it does
 }

 for (var i = 0; i<all_files.length; i ++) {

        var results = form.get_all_files[i].value.match(regexp);        //split apart the checkbox val

                                                                        //grab the file_extension
        var file_ext = results[2];                                      //remember that the first javascript regex match returned is the full string then the parenthesized sub expressions

        var click_all_check_val =  file_types[file_ext];                //set the file extension click_all_files checked val


        form.get_all_files[i].checked = click_all_check_val ;           //Set the checkbox to what ever the all_checkbox checked value was


 }

  return;
}

//-->
</SCRIPT>
  END_JAVASCRIPT

}

###############################################################################
# updateSampleCheckBoxButtons_javascript
###############################################################################
sub updateSampleCheckBoxButtons_javascript {
  print  getUpdateSampleCheckBoxButtonsJavascript();
}

#+
#
#-


sub getUpdateSampleCheckBoxButtonsJavascript {

  return <<"  END_JAVASCRIPT";
<SCRIPT LANGUAGE="Javascript">
<!--
function updateSampleCheckBoxButtons(input_obj){
 var form = input_obj.form;
 var all_checkboxes = form.click_all_samples;
 var updatedVals;

 var regexp = /(.+?)__(.*)/; //Exmple 42__XML

 var results = input_obj.value.match(regexp);
 var file_types = new Object();

 for (var i=0; i<all_checkboxes.length; i ++){                          //Loop through the all checkbox buttons and store their checked value in an object

        var hold = form.click_all_samples[i].value;                       // grab the value of the checkbox
        file_types[hold] = form.click_all_samples[i].checked;             // set for each data type if it is checked or not

 }

 if (all_checkboxes.length == null){                                    //If there is only one element we will not get back an array and file_types will not exists
        var hold = form.click_all_samples.value;
        file_types[hold] = form.click_all_samples.checked;
}



 if (all_files ){

 }else{
        var all_files = form.select_samples                              //Do not re-make the all_files array if it has already been made.  Not sure why this works but it does
 }

 for (var i = 0; i<all_files.length; i ++) {

        var results = form.select_samples[i].value.match(regexp);        //split apart the checkbox val

                                                                        //grab the file_extension
        var file_ext = results[2];                                      //remember that the first javascript regex match returned is the full string then the parenthesized sub expressions
        var click_all_check_val =  file_types[file_ext];                //set the file extension click_all_files checked val


        form.select_samples[i].checked = click_all_check_val ;           //Set the checkbox to what ever the all_checkbox checked value was


 }

  return;
}

//-->
</SCRIPT>
  END_JAVASCRIPT

}
###############################################################################
# get_file_cbox
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

          $cbox{$file_type} ="<input type='checkbox' name='click_all_files' value='".
                             $file_type."' $checked onClick='Javascript:updateCheckBoxButtons(this)'>";

         } # end foreach
  return \%cbox;
}

###############################################################################
# get_sample_select_cbox
###############################################################################

sub get_sample_select_cbox {

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

          $cbox{$file_type} ="<input type='checkbox' name='click_all_samples' value='".
                             $file_type."' $checked onClick='Javascript:updateSampleCheckBoxButtons(this)'>";

         } # end foreach
  return \%cbox;
}


###############################################################################
# make_checkbox_contol_table
###############################################################################

sub make_checkbox_control_table {
  my $self = shift;
  my %args = @_;
  my $cbox = $self->get_file_cbox( %args );
  my $table =<<'  END';
  <TABLE BORDER=0>
  <TR><TD COLSPAN=2>Click to select or de-select all Samples</TD></TR>
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
