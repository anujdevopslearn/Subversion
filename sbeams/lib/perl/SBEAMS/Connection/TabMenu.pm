###############################################################################
# $Id$
#
# Description : Module for building tabbed menus for HTML pages. 
#
# SBEAMS is Copyright (C) 2000-2004 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::Connection::TabMenu;

use strict;
use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::DataTable;
use overload ( '""', \&asHTML );

##### Public Methods ###########################################################
#
# Module provides interface to build a set of tabbed menus for a web page.
# If you create and optionally add content to a TabMenu object, and then refer
# to it in double quotes, it will stringify using the asHTML method.  This 
# makes it easy to print within any sort of printing block
#
# For further information, please try perldoc `TabMenu.pm`

#+
# Constructor method.  
#
# narg  cgi          $q/$cgi object from page, needed to extract tab/url. (REQ)
# narg  activeColor   bgcolor for active tab, defaults to gray
# narg  inactiveColor bgcolor for inactive tab, defaults to light gray
# narg  atextColor    Color of text in active tab, default black
# narg  itextColor    Color of text in inactive tab, default black
# narg  isSticky      If true, pass thru cgi params, else delete 
# narg  boxContent    If true, draw box around content (if any)
# narg  maSkin        If true, reoverload stringify to point at &asMA_skin
#
sub new {
  my $class = shift;
  my $this = { activeColor => '999999', # 
               inactiveColor => '#EEEEEE', # light gray 
               atextColor => '000000', # black
               itextColor => '000000', # black
               isSticky => 0,
               boxContent => 1,
               maSkin => 0,
               paramName => '_tab',
               @_,
               _tabIndex => 0,
               _tabs => [ 'placeholder' ]
             };

  for ( qw(cgi) ) {
    die ( "Required argument $_ missing" ) unless defined $this->{$_};
  }
  my $cgi = $this->{cgi};

  # cache tab number (if any).  Delete from url to avoid collisions.
  $this->{_currentTab} = $cgi->param( $this->{paramName} );
  $cgi->delete( $this->{paramName} ) if $this->{_currentTab};

  # Cache abs and abs_query urls
  my @urlparams = ( -absolute => 1 );
  $this->{_absURL} = $cgi->url( @urlparams );
  $log->debug( "Absolute URL is $this->{_absURL}" );

  # Do we want to include current params?
  push @urlparams, -query => 1;
  $this->{_absQueryURL} = $cgi->url( @urlparams );
  $log->debug( "Query URL is $this->{_absURL}" );


  if ( $this->{maSkin} ) {
    eval 'use overload \'""\' => \&asMA_HTML';
  }
  
  # Objectification.
  bless $this, $class;

  # Allow constructor to define some tabs
  if ( ref( $this->{labels} ) eq 'ARRAY' ) {
      foreach( @{$this->{labels}} ) {
        $this->addTab( label => $_ );
      }
    }
  
  return $this;
}

#+
# settor method for current tab.  Required if user allows cgi parameters to be
# processed before creating tab object.
# -
sub setCurrentTab {
  my $this = shift;
  my %args = @_;
  if ( $args{currtab} ) {
    $this->{_currentTab} = $args{currtab};
  }
}

#+
# accessor method for tabnum
# -
sub getCurrentTab {
  my $this = shift;
  return ( $this->{_currentTab} );
}

#+
# stub method, for one day allowing the corners of the tabs to be rounded 
# -
sub setRounded {
  my $this = shift;
  $this->{_rounded} = 1;
}

#+
# returns number of defined tabs
# -
sub getNumTabs {
  my $this = shift;
  # Due to starting the tabs at 1, there is an offset.
  return ( scalar( @{$this->{_tabs}} ) - 1 );
}

#+
# Set active tab background color
# narg color    Color for background  
#-
sub setActiveColor {
  my $this = shift;
  my %args = @_;
  if ( $args{color} ) {
    $this->{activeColor} = $args{color};
  }
}

#+
# Set inactive tab background color
# narg color    Color for background  
#-
sub setInactiveColor {
  my $this = shift;
  my %args = @_;
  if ( $args{color} ) {
    $this->{inactiveColor} = $args{color};
  }
}


#+
# Set active tab text color
# narg color    Color for text 
#-
sub setAtextColor {
  my $this = shift;
  my %args = @_;
  if ( $args{color} ) {
    $this->{atextColor} = $args{color};
  }
}

#+
# Set inactive tab text color
# narg color    Color for text 
#-
sub setItextColor {
  my $this = shift;
  my %args = @_;
  if ( $args{color} ) {
    $this->{itextColor} = $args{color};
  }
}

#+
# creates new DataTable for menu display.
#-
sub getTable {
  my $this = shift;

  # tab menu is at its heart just a table...
  $this->{_table} = SBEAMS::Connection::DataTable->new( WIDTH => '650',
                                                        BORDER => 0,
                                                        CELLSPACING => 0,
                                                        CELLPADDING => 0 );
}


#+
# I'm sure this is useful somehow!
#-
sub setBoxContent {
  my $this = shift;
  $this->{boxContent} = shift;
}

#+
# Add content to tab, useful only if a border is desired.
#-
sub addContent {
  my $this = shift;
  $this->{_content} = shift;
}

#+
# Set tab to load by default
#-
sub setDefaultTab {
  my $this = shift;
  $this->{_defaultTab} = shift;
}

#+
#  Add a new tab to menuset
#-
sub addTab {
  my $this = shift;
  my %args = @_;
  for ( qw(label) ) {
    die ("Missing parameter $_") unless $args{label};
  }
  # Increment the tabIndex
  $this->{_tabIndex}++;

  # Which param behaviour do we want.
  my $url = ( $this->{isSticky} ) ? $this->{_absQueryURL} : $this->{_absURL};
  
  $args{url} ||= $url;
  my $del = ( $args{url} =~ /\?/ ) ? '&' : '?';
  $args{url} .= "${del}$this->{paramName}=$this->{_tabIndex}";

  push ( @{$this->{_tabs}}, { url => $args{url}, label => $args{label}, helptext => $args{helptext} } );

  # return tab number in case it is useful to the caller.
  return $this->{_tabIndex};
}

#+
#  returns numeric index of active tab
#-
sub getActiveTab {
  my $this = shift;
  # If a tab was already selected, it is active
  return ( $this->{_currentTab} ) if $this->{_currentTab};

  # Else use default
  return ( $this->{_defaultTab} ) if $this->{_defaultTab};

  # Else use first tab
  return 1;
}

#+
#  returns name of active tab
#-
sub getActiveTabName {
  my $this = shift;

  my $act = $this->getActiveTab();

  return( $this->{_tabs}->[$act]->{label} )
}



#+
# Rendering method, returns HTML rendition of tabmenu
#-
sub asHTML {
  my $this = shift;
  return $this->asCSSHTML();
}

#+
# Rendering method, returns CSS derived menu look 'n feel.
#-
sub asCSSHTML {
  my $this = shift;

  # Get table for rendering stuff...
  $this->getTable();

  my @tabs = @{$this->{_tabs}};
  my @row;
  my $dtab ||= $this->getActiveTab();

  my $list = "<DIV id=menuset>\n";

  for( my $i = 1; $i <= $#tabs; $i++ ) {
    my $spc = "&nbsp;";
    my $color = ( $dtab == $i ) ? $this->{activeColor} : $this->{inactiveColor};
    my $htext = '';# ( $tabs[$i]->{helptext} ) ? "TITLE='$tabs[$i]->{helptext}'" : '';
    my $class = (  $dtab == $i ) ? 'class=atab' : '';
    $list .=<<"    END";
    <A $class HREF='$tabs[$i]->{url}' $htext> $tabs[$i]->{label} </A> 
    END

  }
  $list .= "</DIV>\n";

  $this->{_table}->addRow ( [ $list] );
  $this->{_table}->setCellAttr( ROW => 1, COL => 1, ALIGN => 'CENTER' );
  
  if ( $this->{_content} ) {
    $this->{_table}->addRow ( [ "<TABLE WIDTH='100%'><TR><TD BGCOLOR='WHITE'>$this->{_content}</TD></TR></TABLE>" ] );
    my $color = ( $this->{boxContent} ) ? $this->{activeColor} : 'WHITE';
    $this->{_table}->setCellAttr ( COL => 1, ROW => 2, BGCOLOR => $color );
  }

  


  return ( <<"  END" );
  <!-- Begin TabMenu --> 
    <!-- CSS definitions -->
    <style type="text/css">
    #menuset {
             position:relative;
	           float:left;
	           width:100%;
	           padding:0 0 0 0
	           margin:0;
	           list-style:none;
	           line-height:1.75em;  
             }
   
    #menuset LI {
                float:left;
	              margin:0;
	              padding:0;
                }

    #menuset A {
	              padding:0;
                float:left;
                display:block;
              	color:#555555;
              	text-decoration:none;
                padding:0.25em 1em;
              	font-weight:bold;
              	background:#DEDEDE;
              	margin:0;
              	border-left:1.25px solid #FFFFFF;
              	border-top:1.25px solid #FFFFFFF;
              	border-right:1.25px solid #AAAAAA;
                }

    #menuset A:hover {
	    background:#BBCCBB;
     	color:#444444;
    }
    #menuset A:active,
    #menuset A.atab:link,
    #menuset A.atab:visited {
	    background:#BBBBBB;
     	color:#333333;
    }
    #menuset A.atab:hover {
	    background:#BBCCBB;
     	color:#444444;
    }
    </style>

  $this->{_table}
    
  <!-- End TabMenu -->
  END
#return "$this->{_table}";
}


#+
# Rendering method, returns HTML rendition of tabmenu
#-
sub asSimpleHTML {
  my $this = shift;
  # Get table for rendering stuff...
  $this->getTable();

  my @tabs = @{$this->{_tabs}};
  my @row;
  my $dtab ||= $this->getActiveTab();

  for( my $i = 1; $i <= $#tabs; $i++ ) {
    my $spc = "&nbsp;";
    my $color = ( $dtab == $i ) ? $this->{activeColor} : $this->{inactiveColor};
    my $htext = ( $tabs[$i]->{helptext} ) ? "TITLE='$tabs[$i]->{helptext}'" : '';
    my $link =<<"    END";
    <A HREF='$tabs[$i]->{url}' STYLE='text-decoration:none' $htext>
      <FONT COLOR=$this->{textColor}> $tabs[$i]->{label} 
      </FONT>
    </A> 
    END
    unless( $i == 1 ) {
      push( @row, $spc );
      my $col = $#row + 1;
      $this->{_table}->setCellAttr( COL => $col, ROW => 1, 
                                    BGCOLOR => $this->{activeColor} );
    }
  push( @row, $link ); 
  my $col = $#row + 1;
  $this->{_table}->setCellAttr( COL => $col, ROW => 1, BGCOLOR => $color,
                                ALIGN => 'CENTER', NOWRAP => 1 );
  }

  my $cnt = ( $this->getNumTabs() ) * 2 + 5 ;
  push @row,  '&nbsp;' x 50;
  $this->{_table}->addRow ( \@row );
  my $hbase = '/devDC/sbeams';

# Add horizontal rule...
  $this->{_table}->addRow ( [ "<IMG SRC='$hbase/images/transparent.gif' HEIGHT='2' WIDTH='1' BORDER='0'>" ] );
  $this->{_table}->setCellAttr ( COL => 1, ROW => 2, COLSPAN => $cnt, BGCOLOR => $this->{activeColor} );
  
  if ( $this->{_content} ) {
    $this->{_table}->addRow ( [ "<TABLE WIDTH='100%'><TR><TD BGCOLOR='white'>$this->{_content}</TD></TR></TABLE>" ] );
    my $color = ( $this->{boxContent} ) ? $this->{activeColor} : 'white';
    $this->{_table}->setCellAttr ( COL => 1, ROW => 3, COLSPAN => $cnt,
                                    BGCOLOR => $color );
  }
  return "<!-- Begin TabMenu --> $this->{_table} <!-- End TabMenu -->";
#return "$this->{_table}";
}

sub asMA_HTML {
  my $this = shift;

  # Get table for rendering stuff...
  $this->getTable();

  $this->setActiveColor( color => '#FFCC33' );
  $this->setInactiveColor( color => '#224499' );
  $this->setAtextColor( color => '#000000' );
  $this->setItextColor( color => '#FFFFFF' );
  $this->setBoxContent( 0 );

  my @tabs = @{$this->{_tabs}};
  my @row;
  my $dtab = $this->getActiveTab();
  for( my $i = 1; $i <= $#tabs; $i++ ) {
    my $spc = "&nbsp;";
    my $color = ( $dtab == $i ) ? $this->{activeColor} : $this->{inactiveColor};
    my $tcolor = ( $dtab == $i ) ? $this->{atextColor} : $this->{itextColor};
    my $htext = ( $tabs[$i]->{helptext} ) ? "TITLE='$tabs[$i]->{helptext}'" : '';
    my $link =<<"    END";
    <A HREF='$tabs[$i]->{url}' STYLE='text-decoration:none' $htext>
      <FONT COLOR=$tcolor> $tabs[$i]->{label} 
      </FONT>
    </A> 
    END
    unless( $i == 1 ) {
      push( @row, $spc );
      my $col = $#row + 1;
      $this->{_table}->setCellAttr( COL => $col, ROW => 1, WIDTH => '15' );
    }
  push( @row, $link ); 
  my $col = $#row + 1;
  $this->{_table}->setCellAttr( COL => $col, ROW => 1, BGCOLOR => $color,
                                ALIGN => 'CENTER', NOWRAP => 1, WIDTH => 95 );
  }

  my $cnt = ( $this->getNumTabs() ) * 2;
  $this->{_table}->addRow ( \@row );
  my $hbase = '/devDC/sbeams';

# Add horizontal rule...
  $this->{_table}->addRow ( [ "<IMG SRC='$hbase/images/transparent.gif' HEIGHT='2' WIDTH='1' BORDER='0'>" ] );
  $this->{_table}->setCellAttr ( COL => 1, ROW => 2, COLSPAN => $cnt, BGCOLOR => $this->{activeColor} );
  
  if ( $this->{_content} ) {
    $this->{_table}->addRow ( [ "<TABLE WIDTH='100%'><TR><TD BGCOLOR='white'>$this->{_content}</TD></TR></TABLE>" ] );
    my $color = ( $this->{boxContent} ) ? $this->{activeColor} : 'white';
    $this->{_table}->setCellAttr ( COL => 1, ROW => 3, COLSPAN => $cnt,
                                    BGCOLOR => $color );
  }
  return "<!-- Begin TabMenu --> $this->{_table} <!-- End TabMenu -->";
}

#+
# Rendering method, returns table as tab-de
#-
sub asHTMLts {
  my $this = shift;

  # Get table for rendering stuff...
  $this->getTable();

  my @tabs = @{$this->{_tabs}};
  my @row;
  my $dtab = $this->getActiveTab();
  for( my $i = 1; $i <= $#tabs; $i++ ) {
    my $color = ( $dtab == $i ) ? $this->{activeColor} : $this->{inactiveColor};
    my $link =<<"    END";
    <TABLE BORDER=1 WIDTH='100%'><TR><TD ALIGN='CENTER' BGCOLOR='$color'>
    <A HREF='$tabs[$i]->{url}' STYLE='text-decoration:none' >
      <FONT COLOR=$this->{textColor}> $tabs[$i]->{label} 
      </FONT>
    </A> 
    </TD></TR></TABLE>
    END
    push( @row, $link ); 
#$this->{_table}->setCellAttr( COL => $i, ROW => 1, BGCOLOR => $color, ALIGN => 'CENTER' );
  }

  my $cnt = $this->getNumTabs() + 1;
  push @row,  '&nbsp;' x 50;
  $this->{_table}->addRow ( \@row );

# Add horizontal rule...
  $this->{_table}->addRow ( [ "<IMG SRC='/images/transparent.gif' HEIGHT='1', WIDTH='1' BORDER='0'>" ] );
  $this->{_table}->addRow ( [ "<IMG SRC='/images/transparent.gif' HEIGHT='3', WIDTH='1' BORDER='0'>" ] );
  $this->{_table}->addRow ( [ "<IMG SRC='/images/transparent.gif' HEIGHT='1', WIDTH='1' BORDER='0'>" ] );
  $this->{_table}->setCellAttr ( COL => 1, ROW => 2, COLSPAN => $cnt, BGCOLOR => '#FFFF99' );
  $this->{_table}->setCellAttr ( COL => 1, ROW => 3, COLSPAN => $cnt, BGCOLOR => $this->{activeColor} );
  $this->{_table}->setCellAttr ( COL => 1, ROW => 4, COLSPAN => $cnt, BGCOLOR => '#993399' );
  
  if ( $this->{_content} ) {
    $this->{_table}->addRow ( [ $this->{_content} ] );
    $this->{_table}->setCellAttr ( COL => 1, ROW => 5, COLSPAN => $cnt );
  }
  return "$this->{_table}";
}
##### Private Methods #########################################################

sub _getURL {
  my $this = shift;

  # Default
  my @urlparams = ( -absolute => 1 );

  # Do we want to include current params?
  push @urlparams, -query => 1 if $this->{isSticky};

  # This will give an absolute internal url w/ query string.
  $this->{_url} = $this->{cgi}->url( -absolute => 1, -query => 1 );
  $this->{_url} = $this->{cgi}->url( @urlparams );
  
  my $comment =<<'  ENDITALL';

  my     $full_url      = $cgi->url();
    my       $query_url      = $cgi->url(-query=>1);  #alternative syntax
      my     $relative_url  = $cgi->url(-relative=>1);
        my   $absolute_url  = $cgi->url(-absolute=>1);
          my $url_with_path = $cgi->url(-path_info=>1);
        my   $url_with_path_and_query = $cgi->url(-absolute=>1,-query=>1);
          my $netloc        = $cgi->url(-base => 1);

  # cache invocation url
  print STDERR <<"  END";
FULL:   $full_url  
QUER:   $query_url  
REL:    $relative_url
ABS:    $absolute_url
URL_P:  $url_with_path
URL_PQ: $url_with_path_and_query
BASE:   $netloc       
SELF:   $this->{_self_url};
  END
  ENDITALL

}


1;

__END__

=head1 NAME: 

SBEAMS::Connection::TabMenu, sbeams HTML page tabbed menus widget

=head1 SYNOPSIS

Module provides interface to build a set of tabbed menus for a web page.
If you create and optionally add content to a TabMenu object, and then refer
to it in double quotes, it will stringify using the asHTML method.  This 
makes it easy to print within any sort of printing block


=head1 USAGE

use SBEAMS::Connection::TabMenu;

my $tabmenu = SBEAMS::Connection::TabMenu->new( cgi => $q,
                                              );

$tabmenu->addTab( label => 'Current Project', helptext => 'View details of current Project' );
$tabmenu->addTab( label => 'My Projects', helptext => 'View all projects owned by me' );
$tabmenu->addTab( label => 'Recent Resultsets', helptext => 'View recent SBEAMS resultsets' );
$tabmenu->addTab( label => 'Accessible Projects', helptext => 'View projects I have access to' );

my $content;

if ( $tabmenu->getActiveTabName() eq 'Recent Resultsets' ){

  $content = $sbeams->getRecentResultsets() ;

} elsif ( $tabmenu->getActiveTabName() eq 'Current Project' ){

  $content = $sbeams->getProjectDetailsTable( project_id => $project_id ); 

} elsif ( $tabmenu->getActiveTab() == 2 ){

    $content = $sbeams->getProjectsYouOwn();

} elsif ( $tabmenu->getActiveTab() == 4 ){

  $content = $sbeams->getProjectsYouHaveAccessTo();

}

# Add content to tabmenu (if desired). 

$tabmenu->addContent( $content );

# The stringify method is overloaded to call the $tabmenu->asHTML method.  This simplifies printing the object in a print block. 

print "$tabmenu";


# This is completely equivalent:

# print $tabmenu->asHTML(); 


=head2 Constructor arguements

=head3 cgi

$q/$cgi object from page, needed to extract tab/url. (REQ)

=head3 activeColor

bgcolor for active tab, defaults to gray

=head3 inactiveColor

bgcolor for inactive tab, defaults to light gray

=head3 atextColor

Color of text in active tab, default black

=head3 itextColor

Color of text in inactive tab, default black

=head3 isSticky

If true, pass thru cgi params, else delete 

=head3 boxContent

If true, draw box around content (if any)

=head3 maSkin

If true, reoverload stringify to point at &asMA_skin

=cut
