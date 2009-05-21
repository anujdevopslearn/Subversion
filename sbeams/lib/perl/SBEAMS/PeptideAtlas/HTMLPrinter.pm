package SBEAMS::PeptideAtlas::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::PeptideAtlas::HTMLPrinter
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
use vars qw($sbeams $current_contact_id $current_username $q
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name $current_user_context_id);
use CGI::Carp qw(fatalsToBrowser croak);
use SBEAMS::Connection qw($log $q);
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::DataTable;
use SBEAMS::Connection::GoogleVisualization;

use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::TableInfo;
use SBEAMS::PeptideAtlas::Tables;


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

  my $sbeams = $self->getSBEAMS();
  my $project_id = $args{'project_id'} || $sbeams->getCurrent_project_id();
  my $output_mode = $sbeams->output_mode();
  my $http_header = $sbeams->get_http_header();

  #### If the output mode is interactive text, display text header
  if ($output_mode eq 'interactive') {
    $sbeams->printTextHeader();
    return;
  }

  #### If the output mode is not html, then we may not want a header here
  if ($output_mode ne 'html') {

    # Caller may want header printing to be handled here
    if ( $args{force_header} ) { 

      # Print http header
      print $http_header if $sbeams->invocation_mode() eq 'http';
    }

    return;
  }

  #### Obtain main SBEAMS object and use its http_header
  $sbeams = $self->getSBEAMS();

  if( $sbeams->isGuestUser() ) {
      $self->displayGuestPageHeader( @_ );
      return;
  } elsif ( $CONFIG_SETTING{PA_USER_SKIN} ) {
    $current_username = $sbeams->getCurrent_username();
    for my $skin ( split( ",", $CONFIG_SETTING{PA_USER_SKIN} ) ) {
#      $log->debug( "skin is $skin" );
      my ( $name, $value ) = split( /::::/, $skin, -1 );
#      $log->debug( "name is $name, val is $value" );
      if ( $name eq $current_username ) {
#        $log->debug( "CUSTOM! $CONFIG_SETTING{PA_USER_SKIN}" );
        $self->displayGuestPageHeader( @_, uri => $value );
        return;
      } else {
        $log->debug( "$name does not equal $current_username" );
      }
    }
  }
  $self->displayStandardPageHeader(@_);
}


###############################################################################
# displayInternalResearcherPageHeader
###############################################################################
sub displayInternalResearcherPageHeader {
  my $self = shift;
  my %args = @_;

  my $navigation_bar = $args{'navigation_bar'} || "YES";

  my $LOGOUT_URI = "$CGI_BASE_DIR/logout.cgi";

  my $LOGOUT_LINK = qq~<A HREF="$LOGOUT_URI" class="Nav_link">LOGOUT</A>~;


  #### Obtain main SBEAMS object and use its http_header
  my $sbeams = $self->getSBEAMS();
  my $http_header = $sbeams->get_http_header();
  use LWP::UserAgent;
  use HTTP::Request;
  my $ua = LWP::UserAgent->new();
  my $skinLink = 'http://www.peptideatlas.org';
  my $response = $ua->request( HTTP::Request->new( GET => "$skinLink/.index.dbbrowse.php" ) );
  my @page = split( "\n", $response->content() );
  my $skin = '';
  my $cnt=0;
  for ( @page ) {

    $cnt++;
    $_ =~ s/\<\!-- LOGIN_LINK --\>/$LOGOUT_LINK/;
    last if $_ =~ /--- Main Page Content ---/;
    $skin .= $_;
  }

  $skin =~ s/\/images\//\/sbeams\/images\//gm;
  $self->{'_external_footer'}=join("\n", @page[$cnt..$#page]);
 
  print "$http_header\n\n";
  print <<"  END_PAGE";
  <HTML>
    $skin
  END_PAGE

  $self->printJavascriptFunctions();
  }


###############################################################################
# displayGuestPageHeader
###############################################################################
sub displayGuestPageHeader {
 	my $self = shift;
  my %args = @_;

  my $navigation_bar = $args{'navigation_bar'} || "YES";

  my $LOGIN_URI = "$SERVER_BASE_DIR$ENV{REQUEST_URI}";

  if ($LOGIN_URI =~ /\?/) {
    $LOGIN_URI .= "&force_login=yes";
  } else {
    $LOGIN_URI .= "?force_login=yes";
  }
  my $LOGIN_LINK = qq~<A HREF="$LOGIN_URI" class="Nav_link">LOGIN</A>~;

	$log->debug( "Does c-widget exist?" );

	my $sbeams = $self->getSBEAMS();
 	$current_username ||= $sbeams->getCurrent_username();
	$log->debug( "SBEAMS is $sbeams in HTML Printer, user is $current_username" );

	my $cswitcher = '';
	if ( -e "$PHYSICAL_BASE_DIR/lib/perl/SBEAMS/PeptideAtlas/ContextWidget.pm" ) {
		$log->debug( "it exists, lets use it!" );
		require SBEAMS::PeptideAtlas::ContextWidget;
		my $cwidget = SBEAMS::PeptideAtlas::ContextWidget->new();
		$log->debug( "got a new one" );
		$cswitcher = $cwidget->getContextSwitcher( username => $current_username,
		                                           cookie_path => $HTML_BASE_DIR );

	} else {
		$log->debug(  "$PHYSICAL_BASE_DIR/lib/perl/SBEAMS/PeptideAtlas/ContextWidget.pm doesn't exist" ) 
	}


  # Use http_header from main SBEAMS object
  my $http_header = $sbeams->get_http_header();
  use LWP::UserAgent;
  use HTTP::Request;
  my $ua = LWP::UserAgent->new();
  my $skinLink = $args{uri} || 'http://www.peptideatlas.org/.index.dbbrowse.php';
  #my $skinLink = 'http://dbtmp.systemsbiology.net/';
  my $response = $ua->request( HTTP::Request->new( GET => "$skinLink" ) );
  my @page = split( "\n", $response->content() );
  my $skin = '';
  my $cnt=0;
  my $init = ( $args{init_tooltip} ) ? $self->init_pa_tooltip() : '';
  my $css_info = $sbeams->printStyleSheet( module_only => 1 );

  $LOGIN_LINK .= "<BR><BR><BR>\n$cswitcher<BR>\n";
  for ( @page ) {
    $cnt++;
    $_ =~ s/\<\!-- LOGIN_LINK --\>/$LOGIN_LINK/;
    $_ =~ s/(\<[^>]*body[^>]*\>)/$1$init$css_info/;
    last if $_ =~ /--- Main Page Content ---/;
    $skin .= "$_\n";
  }
  
  $self->{'_external_footer'} = join("\n", '<!--SBEAMS_PAGE_OK-->', @page[$cnt..$#page]);
  $skin =~ s#/images/#/sbeams/images/#gm;
  #$skin =~ s#/images/#/dev2/sbeams/images/#gm;

  print "$http_header\n\n";
  print <<"  END_PAGE";
  <HTML>
    $skin
  END_PAGE
  print "$args{header_info}\n" if $args{header_info};

  $self->printJavascriptFunctions();
  }



###############################################################################
# displayStandardPageHeader
###############################################################################
sub displayStandardPageHeader {
  my $self = shift;
  my %args = @_;

  my $navigation_bar = $args{'navigation_bar'} || "YES";

  #### Obtain main SBEAMS object and use its http_header
  my $sbeams = $self->getSBEAMS();
  my $http_header = $sbeams->get_http_header();

  my $message = $sbeams->get_page_message();

  print qq~$http_header
	<HTML><HEAD>
	<TITLE>$DBTITLE - $SBEAMS_PART</TITLE>
  ~;


  $self->printJavascriptFunctions();
  $self->printStyleSheet();

  my $loadscript = "$args{onload};" || '';

  print "$args{header_info}\n" if $args{header_info};

  #### Determine the Title bar background decoration
  my $header_bkg = "bgcolor=\"$BGCOLOR\"";
  $header_bkg = "background=\"$HTML_BASE_DIR//images/plaintop.jpg\"" if ($DBVERSION =~ /Primary/);

  print qq~
	<!--META HTTP-EQUIV="Expires" CONTENT="Fri, Jun 12 1981 08:20:00 GMT"-->
	<!--META HTTP-EQUIV="Pragma" CONTENT="no-cache"-->
	<!--META HTTP-EQUIV="Cache-Control" CONTENT="no-cache"-->
	</HEAD>

	<!-- Background white, links blue (unvisited), navy (visited), red (active) -->
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" TOPMARGIN=0 LEFTMARGIN=0 OnLoad="$loadscript self.focus();">
  ~;
  print $self->init_pa_tooltip() if $args{init_tooltip};

  print qq~
	<table border=0 width="100%" cellspacing=0 cellpadding=1>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td bgcolor="$BARCOLOR"><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmlclear.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmlclear.gif"></a></td>
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
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetPeptides"><nobr>&nbsp;&nbsp;&nbsp;Browse Peptides</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseBioSequence.cgi"><nobr>&nbsp;&nbsp;&nbsp;Browse Bioseqs</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetPeptide"><nobr>&nbsp;&nbsp;&nbsp;Get Peptide Summary</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetProtein"><nobr>&nbsp;&nbsp;&nbsp;Get Protein Summary</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/showPathways"><nobr>&nbsp;&nbsp;&nbsp;Pathway Search</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetMRMList"><nobr>&nbsp;&nbsp;&nbsp;MRM Transitions</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/Glycopeptide/Glyco_prediction.cgi"><nobr>&nbsp;&nbsp;&nbsp;Search Glyco-Peptides</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Manage Tables:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_biosequence_set"><nobr>&nbsp;&nbsp;&nbsp;Biosequence Sets</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_atlas_build"><nobr>&nbsp;&nbsp;&nbsp;Atlas Builds</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_default_atlas_build"><nobr>&nbsp;&nbsp;&nbsp;Default Builds</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_atlas_search_batch"><nobr>&nbsp;&nbsp;&nbsp;Atlas Search Batches</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_sample"><nobr>&nbsp;&nbsp;&nbsp;Samples</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BL_dbxref"><nobr>&nbsp;&nbsp;&nbsp;DB Xrefs</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=organism"><nobr>&nbsp;&nbsp;&nbsp;Organisms</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_publication"><nobr>&nbsp;&nbsp;&nbsp;Publications</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Annotations:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_spectrum_annotation"><nobr>&nbsp;&nbsp;&nbsp;Spectra</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_peptide_annotation"><nobr>&nbsp;&nbsp;&nbsp;Peptides</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_modified_peptide_annotation"><nobr>&nbsp;&nbsp;&nbsp;Modified Peptides</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_spectrum_annotation_level"><nobr>&nbsp;&nbsp;&nbsp;Spectra Levels</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=AT_transition_suitability_level"><nobr>&nbsp;&nbsp;&nbsp;Transition Levels</nobr></a></td></tr>
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
    print <<"    END";
    <STYLE>
     TD { background-repeat: no-repeat; }
    </STYLE>
    END

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

   if($self->{'_external_footer'}) {


	  # Have to fish for error file, since we are using Carp (can't pass sbeams
		# object ).
	  my $errfile = 'Error-' . getppid();
 	  my $is_error = 0;
 	  if ( $sbeams->doesSBEAMSTempFileExist( filename => $errfile ) ) {
			$sbeams->deleteSBEAMSTempFile( filename => $errfile );
			$is_error++;
		}

   	$self->{'_external_footer'} =~ s/SBEAMS_PAGE_OK/SBEAMS_PAGE_ERROR/gmi if $is_error;

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
    my $close_main_tables = 'NO';
    $close_main_tables = 'YES' unless ($close_tables eq 'YES');

    #### Default to the Core footer
    $sbeams->display_page_footer(display_footer=>'YES',
      close_tables=>$close_main_tables);
  }

}



###############################################################################
# encodeSectionHeader
###############################################################################
sub encodeSectionHeader {
  my $METHOD = 'encodeSectionHeader';
  my $self = shift || die ("self not passed");
  my %args = @_;
  
  # Default to BOLD
  $args{bold} = 1 if !defined $args{bold};

  my $text = $args{text} || '';
  $text = "<B>$text</B>" if $args{bold};

  my $link = $args{link} || '';

  my $buffer = qq~
        <TR><TD colspan="2" background="$HTML_BASE_DIR/images/fade_orange_header_2.png" width="600">$link<font color="white">$text</font></TD></TR>
~;

  return $buffer;

}


###############################################################################
# encodeSectionItem
###############################################################################
sub encodeSectionItem {
  my $METHOD = 'encodeSectionItem';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $key = $args{key} || '';
  my $value = $args{value} || '';
  my $url = $args{url} || '';
  my $kwid = ( $args{key_width} ) ? "WIDTH='$args{key_width}'" : '';
  my $vwid = ( $args{val_width} ) ? "WIDTH='$args{val_width}'" : '';
  
  my $tr = $args{tr_info} || ''; 

  $url =~ s/ /+/g;

  my $astart = '';
  my $aend = '';
  if ($url) {
    $astart = qq~<A HREF="$url" target="_blank">~;
    $aend = qq~</A>~;
  }

  my $buffer = qq~
        <TR $tr><TD NOWRAP bgcolor="cccccc" $kwid>$key</TD><TD $vwid>$astart$value$aend</TD></TR>
~;

  return $buffer;

}


###############################################################################
# encodeSectionTable
###############################################################################
#
#
# @nparam  rows             Reference to array of row arrayrefs.  Required.
# @nparam  header           rows includes header info, default 0
# @nparam  width            Width of table
# @nparam  nocenter         Overrides centering of header info
# @nparam  align            Ref to array of positional info for columns -
#                           right, left, and center
# @nparam  rows_to_show     Number of rows to show initially, others are loaded
#                           into page but hidden by CSS and showable view JS.
# @nparam  nowrap           ref to array of col indexes on which to set nowrap
# @nparam  maxrows          Maximum number of rows the table can contain, 
#                           irrespective of the number displayed.
# @nparam  chg_bkg_idx      Index of field on which to trigger alternating
#                           colors.
# @nparam  bkg_interval     numeric interval on which to alternate colors, 
#                           superceded by chk_bkg_idx
# @nparam  set_download     Have table include download link if set to a true
#                           value.  If text value is used then it will be used
#                           as text for the link.
# @nparam  sortable         If true, make data table sortable
#
#
# 
#
sub encodeSectionTable {
  my $METHOD = 'encodeSectionTable';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $pre_text = '';
  my $class_def = '';
  my $id = $args{table_id} || '';

  if ( $args{sortable} ) {
    if ( !$self->{_included_sortable} ) {
      $pre_text = qq~
      <SCRIPT LANGUAGE=javascript SRC="$HTML_BASE_DIR/usr/javascript/sorttable.js"></SCRIPT>
      ~;
      $class_def = 'PA_sort_table';
      $self->{_included_sortable}++;
    }
  }

  my @table_attrs = ( 'BORDER' => 0, );
  my $tr_info = $args{tr_info} || 'NOOP=1 ';
  my $tab = SBEAMS::Connection::DataTable->new( @table_attrs, 
                                                __tr_info => $tr_info,
                                                CLASS => $class_def,
                                                  ID => $id  );
  my $num_cols = 0;


  my $rs_link = '';
  my $rs_name = '';
  my $file_prefix = $args{file_prefix} || 'mrm_';
  if ( $args{set_download} ) {
    # Kluge part 1
    my $rs_headers = shift( @{$args{rows}} );
    $rs_name = $self->make_resultset( rs_data => $args{rows}, 
                                      headers => $rs_headers,
                                  file_prefix => $file_prefix );

    $rs_link = "<a href='$CGI_BASE_DIR/GetResultSet.cgi/$rs_name.tsv?rs_set_name=$rs_name&format=tsv;remove_markup=1' TITLE='Download table as tab-delimited text file' CLASS=info_box>Download as TSV</a>",
    # Kluge part 2
    unshift( @{$args{rows}}, $rs_headers );
  }

  return '' unless $args{rows};
  $args{header} ||= 0;
  if ( $args{width} ) {
    push @table_attrs, 'WIDTH', $args{width};
  }

  $args{max_rows} ||= 0;
  my $sbeams = $self->getSBEAMS();
  my $prefix = $sbeams->getRandomString( num_chars => 8, 
                                          char_set => ['A'..'Z', 'a'..'z'] );
  my $first = 1;
  my $bgcolor = '#C0D0C0';
  my $chg_idx;
  my $rcnt = ( $args{header} ) ? 1 : 0;
  for my $row ( @{$args{rows}} ) {
    $num_cols = scalar( @$row ) unless $num_cols;
    $tab->addRow( $row );
    $rcnt++;
    if ( $args{chg_bkg_idx} ) { # alternate on index
      if ( !$chg_idx ) {
        $chg_idx = $row->[$args{chg_bkg_idx}];
      } elsif ( $chg_idx ne $row->[$args{chg_bkg_idx}] ) {
        $bgcolor = ( $bgcolor eq '#C0D0C0' ) ? '#F5F5F5' : '#C0D0C0';
        $chg_idx = $row->[$args{chg_bkg_idx}];
      }

    } elsif ( $args{bkg_interval} ) { # alternate on n_rows
      unless ( $rcnt % $args{bkg_interval} ) {
        $bgcolor = ( $bgcolor eq '#C0D0C0' ) ? '#F5F5F5' : '#C0D0C0';
      }
    } elsif ( $args{bg_color} ) { # single solid color
      $bgcolor = $args{bg_color};
    }
    $tab->setRowAttr(  ROWS => [$tab->getRowNum()], BGCOLOR => $bgcolor );
    my $num_rows = $tab->getRowNum() - 1;

    if ( $args{rows_to_show} && $args{rows_to_show} < $num_rows ) {
      $tab->setRowAttr( ROWS => [$tab->getRowNum()], ID => $prefix . '_toggle', 
                                                     NAME => $prefix . '_toggle', 
                                                     CLASS => 'hidden' ); 
    }
    if ( $args{max_rows} && $args{max_rows} <= $num_rows ) {
      my $span = scalar( @$row );
      my $msg = "Table truncated at $args{max_rows} rows";
      if  ( $args{set_download} ) {
        $msg .= "(won't affect download, " . scalar( @{$args{rows}} ) . ' total rows)';
      }
      $tab->addRow( [$sbeams->makeInfoText("<I>$msg</I>")] );
      $tab->setColAttr( ROWS => [$tab->getRowNum()], 
                     COLSPAN => $span, 
                        COLS => [ 1 ], 
                       ALIGN => 'CENTER' ); 

      if ( $args{rows_to_show} && $args{rows_to_show} < $num_rows ) {
        $tab->setRowAttr( ROWS => [$tab->getRowNum()], ID => $prefix . '_toggle', 
                                                     NAME => $prefix . '_toggle', 
                                                     CLASS => 'hidden' ); 
      } 
      last;
    }
  }

  my $nowrap = $args{nowrap} || [];
  if ( scalar( @$nowrap ) ) {
    $tab->setColAttr( COLS => $nowrap, NOWRAP => 1 ); 
  }
  
  # How many do we have?
  my $tot = $tab->getRowNum();
  my $closelink;
  if ( $args{rows_to_show} && $args{rows_to_show} < $tot - 1 ) {
    $closelink = $self->add_tabletoggle_js(); 
    $closelink .= "\n<FONT COLOR=BLUE><A HREF=#null ONCLICK=toggle_em('$prefix');return><SPAN ID='${prefix}_text' NAME='${prefix}_text' >Show more</A></FONT>";
  }

  # if no wrapping desired...
  if ( $args{nowrap} ) {
    $tab->setRowAttr( ROWS => [1..$tot], NOWRAP => 1 ); 
  }

  # Set header attributes
  if ( $args{header} ) {
    if ( $args{sortable} ) {
      $tab->setRowAttr( ROWS => [1], BGCOLOR => '#0000A0' ); 
    } else {
      $tab->setRowAttr( ROWS => [1], BGCOLOR => '#CCCCCC' ); 
    }
    $tab->setRowAttr( ROWS => [1], ALIGN => 'CENTER' ) unless $args{nocenter};
  }

  if ( $args{align} ) {
    for ( my $i = 0; $i <= $#{$args{align}}; $i++ ) {
      $tab->setColAttr( ROWS => [2..$tot], COLS => [$i + 1], ALIGN => $args{align}->[$i] );
    }
  }
#  $tab->addRow( [$closelink] );

  my $html = "$pre_text\n";

  if ( $rs_link || $args{change_form} ) {
    if ( !$rs_link ) {
      $html .= "<TR><TD NOWRAP ALIGN=left>$args{change_form}</TD></TR>\n";
    } elsif ( !$args{change_form} ) {
      $html .= "<TR><TD NOWRAP COLSPAN=$num_cols ALIGN=right>$rs_link</TD></TR>\n";
    } else {
      $html .= "<TR><TD NOWRAP ALIGN=left>$args{change_form}</TD>\n";
      $html .= "<TD NOWRAP ALIGN=right>$rs_link</TD></TR>\n";
    }
  }
 
  $html .= "<TR><TD NOWRAP COLSPAN=2>$tab</TD></TR>";
  $html .= '</TABLE>' if $args{close_table};
  $html .= $closelink;

  return ( wantarray ) ? ($html, $rs_name) : $html;
}

###############################################################################
# display sample plot
###############################################################################
sub getSamplePlotDisplay {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my %args = @_;
  my $SUB_NAME = 'getSampleDisplay';

  for my $arg ( qw( n_obs obs_per_million ) ) {
		unless ( defined ($args{$arg} ) ) {
      $log->error( "Missing required argument $arg" );
      return undef;
		}
  }

  my $header = '';
  if ( $args{link} ) {
    $header .= $self->encodeSectionHeader( text => 'Observed in Samples:',
                                          link => $args{link} );
  } else {
    $header .= $self->encodeSectionHeader( text => 'Observed in Samples:',);
  }

  my $trinfo = $args{tr_info} || '';
	my $height = 50  + scalar( @{$args{n_obs}} ) * 12;
	$log->debug( "Height is $height pre call" );

  my $GV = SBEAMS::Connection::GoogleVisualization->new();
  my $chart = $GV->setDrawBarChart(  samples => $args{n_obs},
                                  data_types => [ 'string', 'number' ],
                                    headings => [ 'Sample Name', 'Number of Observations' ],
                                  );
  my $chart_2 = $GV->setDrawBarChart(  samples => $args{obs_per_million},
                                  data_types => [ 'string', 'number' ],
                                    headings => [ 'Sample Name', 'Obs per million spectra' ],
  
	);
  $chart .= $chart_2 . ' ' . $GV->getHeaderInfo();
	$chart = "<TR $trinfo><TD></TD><TD>&nbsp;&nbsp;$chart</TD></TR>";


  return ( wantarray() ) ? ($header, $chart) : $header . "\n" . $chart;
}

###############################################################################
# displaySampleMap
###############################################################################
sub getSampleMapDisplay {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my %args = @_;

  my $in = join( ", ", keys( %{$args{instance_ids}} ) );
  return unless $in;

  my $header = '';
  if ( $args{link} ) {
    $header .= $self->encodeSectionHeader( text => 'Sample peptide map:',
                                          link => $args{link} );
  } else {
    $header .= $self->encodeSectionHeader( text => 'Sample peptide map:',);
  }
  $header = '' if $args{no_header};

  my $html = '';
  my $trinfo = $args{tr_info} || '';


  my $sql = qq~     
  	SELECT DISTINCT SB.atlas_search_batch_id, sample_tag, 
		-- CASE WHEN PISB.n_observations IS NULL THEN 0 ELSE PISB.n_observations END
		PISB.n_observations, peptide_accession 
		FROM $TBAT_ATLAS_SEARCH_BATCH SB 
	  JOIN $TBAT_SAMPLE S ON s.sample_id = SB.sample_id
	  JOIN $TBAT_PEPTIDE_INSTANCE_SEARCH_BATCH PISB ON PISB.atlas_search_batch_id = SB.atlas_search_batch_id
	  JOIN $TBAT_PEPTIDE_INSTANCE PI ON PI.peptide_instance_id = PISB.peptide_instance_id
	  JOIN $TBAT_PEPTIDE P ON P.peptide_id = PI.peptide_id
    WHERE PI.peptide_instance_id IN ( $in )
    AND S.record_status != 'D'
    ORDER BY peptide_accession ASC
  ~;

  my @samples = $sbeams->selectSeveralColumns($sql);

  my $sample_js;
	my %samples;
	my %peptides;
	my $cntr = 0;
  for my $row ( @samples ) { 
		$cntr++;
		my $key = $row->[1] . '::::' . $row->[0];
		$peptides{$row->[3]}++;
		$samples{$key} ||= {};
		$samples{$key}->{$row->[3]} = $row->[2];
	}
	my $array_def = qq~
	<script type="text/javascript">
    google.setOnLoadCallback(drawHeatMap);
    function drawHeatMap() {
    var data = new google.visualization.DataTable();
    data.addColumn('string', 'Sample Name');
	~;
	my @peps;
  for my $pa ( sort( keys( %peptides ) ) ) {
    $array_def .= "    data.addColumn('number', '$pa');\n";
		push @peps, $pa;
	}
	$array_def .= "DEFINE_ROWS_HERE\n";

	my $row = 0;
	my $max = 0;
	my $min = 50;
	$cntr = 0;
	for my $sa ( sort( keys( %samples ) ) ) {
	  my $col = 0;
		my ( $name, $id ) = split "::::", $sa;
    $array_def .= "    data.setValue( $row, $col, '$name' );\n";
	  $col++;
    for my $pa ( @peps ) {
			if ( $samples{$sa}->{$pa} ) {
        my $pep_cnt = log(1 + $samples{$sa}->{$pa})/log(10);
			  $max = ( $pep_cnt > $max ) ? $pep_cnt : $max;
    		$min = ( $pep_cnt < $min ) ? $pep_cnt : $min;
        $array_def .= "    data.setValue( $row, $col, $pep_cnt );\n";
		    $cntr++;
			}
		  $col++;
		}
		$row++;
	}
	$array_def =~ s/DEFINE_ROWS_HERE/data.addRows($row);/;
	my $num_colors = 256;
	$array_def .= qq~
	heatmap = new org.systemsbiology.visualization.BioHeatMap(document.getElementById('heatmapContainer'));
	heatmap.draw(data, {numberOfColors:$num_colors,passThroughBlack:false,startColor:{r:255,g:255,b:255,a:1},endColor:{r:100,g:100,b:100,a:1},emptyDataColor:{r:256,g:256,b:256,a:1}});
		}
  </script>
  ~;

	$args{header_text} = ( $args{header_text} ) ? "<TR $trinfo><TD ALIGN=CENTER CLASS=section_description>$args{header_text}</TD></TR>" : '';
	my $content = qq~
  <script type="text/javascript" src="https://www.google.com/jsapi"></script>
  <script type="text/javascript">
    google.load("visualization", "1", {});
    google.load("prototype", "1.6");
  </script>    
  <script type="text/javascript" src="$HTML_BASE_DIR/usr/javascript/main/js/load.js"></script>
  <script type="text/javascript">
    systemsbiology.load("visualization", "1.0", {packages:["bioheatmap"]});
  </script>

	$array_def

  $args{header_text}
	<TR $trinfo><TD> <DIV ID="heatmapContainer"></DIV>  </TD></TR>
	

	~;

  return ( wantarray() ) ? ($header, $content) : $header . "\n" . $content;


} # end getSampleMapDisplay

###############################################################################
# displaySamples
###############################################################################
sub getSampleDisplay {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my %args = @_;
  my $SUB_NAME = 'getSampleDisplay';

  unless( $args{sample_ids} ) {
    $log->error( "No samples passed to display samples" );
    return;
  }

  my $in = join( ", ", @{$args{sample_ids}} );
  return unless $in;

  my $sql = qq~
    SELECT sample_id,sample_title, sample_description
      FROM $TBAT_SAMPLE
     WHERE sample_id IN ( $in )
     AND record_status != 'D'
     ORDER BY sample_id ASC
  ~;

  my @samples = $sbeams->selectSeveralColumns($sql);

  my $header = '';

  if ( $args{link} ) {
    $header .= $self->encodeSectionHeader( text => 'Observed in Samples:',
                                          link => $args{link} );
  } else {
    $header .= $self->encodeSectionHeader( text => 'Observed in Samples:',);
  }
  $header = '' if $args{no_header};

  my $html = '';
  my $trinfo = $args{tr_info} || '';

  foreach my $sample (@samples) {
    my ($sample_id,$sample_title,$sample_description) = @{$sample};
    $sample_title = $self->make_pa_tooltip( tip_text => $sample_description, link_text => $sample_title );

    $html .= $self->encodeSectionItem(
      key=>$sample_id,
      value=>$sample_title,
      key_width => '5%',
      val_width => '95%',
      tr_info => $trinfo,
      url=>"$CGI_BASE_DIR/$SBEAMS_PART/ManageTable.cgi?TABLE_NAME=AT_SAMPLE&sample_id=$sample_id",
    );
  }

  return ( wantarray() ) ? ($header, $html) : $header . "\n" . $html;
} # end getSampleDisplay

sub add_tabletoggle_js {
  my $self = shift;
  return '' if $self->{_added_ttoggle_js};
  $self->{_added_ttoggle_js}++;
  return <<"  END";
  <STYLE TYPE="text/css" media="screen">
    tr.visible { display: block-row; }
    tr.hidden { display: none; }
    td.visible { display: table-cell; }
    td.hidden { display: none; }
  </STYLE>
  <SCRIPT TYPE="text/javascript">
    function toggle_em(prefix) {
      
      // Grab page elements by their IDs
      var togglekey = prefix + '_toggle';
      var textkey = prefix   + '_text';

      var rows = document.getElementsByName(togglekey);
      var show = document.getElementById(textkey);

      var ttext = show.innerHTML;
      if ( ttext == 'Show more' ) {
        show.innerHTML = "Show fewer";
      } else {
        show.innerHTML = "Show more";
      }
      
      for (var i=0; i < rows.length; i++) {
        if ( rows[i].className == 'hidden' ) {
           rows[i].className = 'visible';
        } else {
           rows[i].className = 'hidden';
        }
      }
    }
    </SCRIPT>

  END
  
}

#+
# Routine will set up PA tooltip colors and javascript.  
#
# @return   JS/CSS to be printed in the page at an appropriate juncture
#-
sub init_pa_tooltip {
  my $self = shift;
  
  # return nothing if tooltip has already been initialized
  return '' if $self->{_tooltip_init};
  
  $self->{_tooltip_init} = 1;
  return <<"  END";
  <SCRIPT DEFER="defer" src="$HTML_BASE_DIR/usr/javascript/TipWidget.js" TYPE="text/javascript"></SCRIPT>
  <STYLE>
  div#tooltipID { background-color:#F0F0F0;
                  border:2px 
                  solid #FF8C00; 
                  padding:4px; 
                  line-height:1.5; 
                  width:200px; 
                  font-family: Helvetica, Arial, sans-serif;
                  font-size:12px; 
                  font-weight: normal; 
                  position:absolute; 
                  visibility:hidden; left:0; top:0;
                }
  </STYLE>
  END
}


#+
# Routine to generate a 'tooltip' mouseover widget with 
#-
sub make_pa_tooltip {
  my $self = shift;
  my %args = @_;
  for my $arg ( qw( tip_text link_text ) ) {
    if ( !$args{$arg} ) {
      $log->error( "Missing required argument $arg" );
      return "";
    }
  }

  # Issue warning if tooltip js wasn't printed (well, fetched anyway).
  $log->warn( "Failed to itialize tooltip!" ) if !$self->{_tooltip_init};

  my $class = $args{class} || 'pseudo_link';

  # Sanitize tooltip text
  $args{tip_text} =~ s/\'/\\\'/g;
  $args{tip_text} =~ s/\"/\\\'/g;
  $args{tip_text} =~ s/\r\n/ /g;
  $args{tip_text} =~ s/\n/ /g;
  
  return "<SPAN CLASS=$class onMouseover=\"showTooltip(event, '$args{tip_text}')\" onMouseout=\"hideTooltip()\">$args{link_text}</SPAN>";
}

sub formatMassMods { 
  my $self = shift;
  my $sequence = shift || return undef;
  $sequence =~ s/\[/<SPAN CLASS=aa_mod>\[/gm;
  $sequence =~ s/\]/\]<\/SPAN>/gm;
  return $sequence;
}


sub get_table_help_section {
  my $self = shift;
  my %args = @_;
  $args{showtext} ||= 'show column descriptions';
  $args{hidetext} ||= 'hide column descriptions';
  $args{heading} ||= 'Column information';
  $args{description} ||= '';


  my $index = "<TABLE class=info_box>\n";
  for my $entry ( @{$args{entries}} ) {
    $index .= $self->encodeSectionItem( %$entry );
  }
  $index .= "</TABLE>\n";

  my $content =<<"  END";
  <BR>
  <span class=section_heading>$args{heading}</span> 
  <span class=description>$args{description}</span>
  $index
  END

  $sbeams = $self->getSBEAMS();
  my $section_toggle = $sbeams->make_toggle_section( content => $content,
                                                     sticky   => 0,
                                                     visible  => 0,
                                                     imglink  => 1,
                                                     showimg  => "/info_small.gif",
                                                     hideimg  => "/info_small.gif",
                                                     textlink => 1,
                                                     name     => $args{name},
                                                     showtext => $args{showtext},
                                                     hidetext => $args{hidetext},
                                          );

  return $section_toggle;
}





###############################################################################
########### vocabHTML
######################################################################################

sub vocabHTML {

###### This subroutine displays the Vocab section on the HTML Page
 
my $self=shift;
my $sbeamsMOD=$self;

my ($table3);

my $pi_desc='Isoelectric point of the peptide';
my $ssrcalc_desc='Sequence Specific Retention Factor provides a hydrophobicity measure for each peptide using the algorithm of Krohkin et al. Version 3.0 <A HREF=http://hs2.proteome.ca/SSRCalc/SSRCalc.html target=_blank>more</A>';
my $org_desc='Organism in which this peptide is observed';
my $n_obs_desc='Number of MS/MS spectra that are identified to this peptide in each build. The hyperlink will take you to the peptide page that will display all the relevant information about this peptide contained in the listed PeptideAtlas build';
my $build_names_desc='Public build in which this peptide is found. The hyperlink will take you to a build specific page summarizing all the relevant information about the build.';

$table3 ='<BR><BR><BR><BR><BR><BR><BR><BR><BR><BR><TABLE WIDTH=600>';

$table3 .= $sbeamsMOD->encodeSectionHeader( text => 'Vocabulary',
                                            width => 900
                                            );

#Substituting the path generated from encodeSectionHeader to match with peptideatlas.org for displaying orange header
$table3 =~ s/\/devAP\/sbeams//gm;

$table3 .= $sbeamsMOD->encodeSectionItem( key   => 'pI',
                                          value => $pi_desc,
                                          key_width => '20%'
                                         );
$table3.= $sbeamsMOD->encodeSectionItem( key   => 'SSRCalc',
                                          value =>$ssrcalc_desc
                                         );
$table3.= $sbeamsMOD->encodeSectionItem( key   => 'Organism Name',
                                          value =>$org_desc
                                         );

$table3.= $sbeamsMOD->encodeSectionItem( key   => 'Number of observations ',
                                          value =>$n_obs_desc
                                         );

$table3.= $sbeamsMOD->encodeSectionItem( key   => 'Build Names in which Peptide is found',
                                          value =>$build_names_desc
                                         );
$table3 .= '</TABLE>';

return ($table3);


}





sub get_atlas_checklist {
  my $self = shift;
  my %args = @_;

  # check input
	for my $arg ( qw( build_info js_call ) ) {
		return "Missing required arguement $arg" unless defined $args{$arg};
	}

  #### Get a list of accessible builds, use to validate passed list.
  my @accessible = $self->getAccessibleBuilds();
	my %build_check;
	for my $build ( @accessible ) {
		$build_check{$build}++;
	}

  # Convenience
	my %build_info = %{$args{build_info}};
  my @builds =  sort { $build_info{$a}->{org} cmp $build_info{$b}->{org} ||
		               $build_info{$b}->{is_curr} <=>  $build_info{$a}->{is_curr} ||
		            $build_info{$b}->{is_default} <=>  $build_info{$a}->{is_default} ||
						 		      $build_info{$a}->{name} cmp $build_info{$b}->{name} } keys %build_info;

  my $table = SBEAMS::Connection::DataTable->new(BORDER => 0);
  $table->addRow( [ 'Add', 'Build Id', 'Display Name', 'Full Name', 'Organism', 'is_def' ] );
  $table->setRowAttr(  ROWS => [1], BGCOLOR => '#bbbbbb', ALIGN=>'CENTER' );
  $table->setHeaderAttr( BOLD => 1 );

  for my $build ( @builds ) {
		my %build = %{$build_info{$build}};
    my $checked = ( $build{visible} ) ? 'checked' : '';

    my $chkbox =<<"    END";
    <INPUT $checked TYPE="checkbox" NAME="build_id" VALUE="$build" onchange="$args{js_call}($build);">
    END
    $table->addRow( [ $chkbox, $build, @build{qw(display_name name org is_default)} ] );
    $table->setRowAttr( ROWS => [$table->getRowNum()], BGCOLOR => $build{bgcolor} );

	}
	return "$table";
}

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


