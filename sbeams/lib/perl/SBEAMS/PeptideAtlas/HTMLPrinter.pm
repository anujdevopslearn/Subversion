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
use vars qw($sbeams $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name $current_user_context_id);
use CGI::Carp qw(fatalsToBrowser croak);
use SBEAMS::Connection qw($log);
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::DataTable;

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

  #### If the output mode is interactive text, display text header
  my $http_header = $sbeams->get_http_header();
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

  if( $sbeams->isGuestUser() ) {
    $self->displayGuestPageHeader();
# } elsif ( $self->isYeastPA(project_id => $project_id) )
# {
#   $self->displayInternalResearcherPageHeader();
  } else
  {
    $self->displayStandardPageHeader(@_);
   }
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
  for ( @page ) {
    $_ =~ s/\<\!-- LOGIN_LINK --\>/$LOGOUT_LINK/;
    last if $_ =~ /--- Main Page Content ---/;
    $skin .= $_;
  }
  $skin =~ s/\/images\//\/sbeams\/images\//gm;
 
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


  #### Obtain main SBEAMS object and use its http_header
  my $sbeams = $self->getSBEAMS();
  my $http_header = $sbeams->get_http_header();
  use LWP::UserAgent;
  use HTTP::Request;
  my $ua = LWP::UserAgent->new();
  my $skinLink = 'http://www.peptideatlas.org';
  #my $skinLink = 'http://dbtmp.systemsbiology.net/';
  my $response = $ua->request( HTTP::Request->new( GET => "$skinLink/.index.dbbrowse.php" ) );
  my @page = split( "\n", $response->content() );
  my $skin = '';
  for ( @page ) {
    $_ =~ s/\<\!-- LOGIN_LINK --\>/$LOGIN_LINK/;
    last if $_ =~ /--- Main Page Content ---/;
    $skin .= "$_\n";
  }
  $skin =~ s#/images/#/sbeams/images/#gm;
  #$skin =~ s#/images/#/dev2/sbeams/images/#gm;

  print "$http_header\n\n";
  print <<"  END_PAGE";
  <HTML>
    $skin
  END_PAGE

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
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetPeptides"><nobr>&nbsp;&nbsp;&nbsp;Browse Peptides</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseBioSequence.cgi"><nobr>&nbsp;&nbsp;&nbsp;Browse Bioseqs</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetPeptide"><nobr>&nbsp;&nbsp;&nbsp;Get Peptide Summary</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetProtein"><nobr>&nbsp;&nbsp;&nbsp;Get Protein Summary</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/showPathways"><nobr>&nbsp;&nbsp;&nbsp;Pathway Search</nobr></a></td></tr>
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
# 
#
sub encodeSectionTable {
  my $METHOD = 'encodeSectionTable';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my @table_attrs = ( 'BORDER' => 0, );
  my $tr_info = $args{tr_info} || 'NOOP=1';
  my $tab = SBEAMS::Connection::DataTable->new( @table_attrs, __tr_info => $tr_info );

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
  for my $row ( @{$args{rows}} ) {
    $tab->addRow( $row );
    my $num_rows = $tab->getRowNum() - 1;

    if ( $args{rows_to_show} && $args{rows_to_show} < $num_rows ) {
      $tab->setRowAttr( ROWS => [$tab->getRowNum()], ID => $prefix . '_toggle', 
                                                     NAME => $prefix . '_toggle', 
                                                     CLASS => 'hidden' ); 
    } elsif ( $args{tr_info} ) {
    }
    if ( $args{max_rows} && $args{max_rows} <= $num_rows ) {
      $log->debug( "Max is $args{max_rows} and num is $num_rows" );
      my $span = scalar( @$row );
      $tab->addRow( [$sbeams->makeInfoText("<I>Table truncated at $args{max_rows} rows</I>")] );
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
  $log->debug( "We have $tot total rows");
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
    $tab->setRowAttr( ROWS => [1], BGCOLOR => '#CCCCCC' ); 
    $tab->setRowAttr( ROWS => [1], ALIGN => 'CENTER' ) unless $args{nocenter};
  }

  if ( $args{align} ) {
    for ( my $i = 0; $i <= $#{$args{align}}; $i++ ) {
      $tab->setColAttr( ROWS => [2..$tot], COLS => [$i + 1], ALIGN => $args{align}->[$i] );
    }
  }
  $tab->addRow( [$closelink] );


  my $html =<<"  END";
  <TR><TD NOWRAP COLSPAN=2>$tab</TD></TR>
  END

  return $html;
}

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
    SELECT sample_id,sample_title
      FROM $TBAT_SAMPLE
     WHERE sample_id IN ( $in )
     AND record_status != 'D'
     ORDER BY sample_id ASC
  ~;

  my @samples = $sbeams->selectSeveralColumns($sql);

  my $header;
  if ( $args{link} ) {
    $header = $self->encodeSectionHeader( text => 'Observed in Samples:',
                                          link => $args{link} );
  } else {
    $header = $self->encodeSectionHeader( text => 'Observed in Samples:',);
  }

  my $html = '';
  my $trinfo = $args{tr_info} || '';

  foreach my $sample (@samples) {
    my ($sample_id,$sample_title) = @{$sample};
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
