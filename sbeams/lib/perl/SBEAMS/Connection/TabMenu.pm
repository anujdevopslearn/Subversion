###############################################################################
# $Id$
#
# Description : Module for building tabbed (drop-down) menus for HTML pages. 
#
# SBEAMS is Copyright (C) 2000-2021 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::Connection::TabMenu;

use strict;
use SBEAMS::Connection::DataTable;
use SBEAMS::Connection::Log;
use SBEAMS::Connection::Settings qw($HTML_BASE_DIR $CGI_BASE_DIR);
use overload ( '""', \&asHTML );

my $log = SBEAMS::Connection::Log->new();

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
# narg  hoverColor    bgcolor for hover tab, defaults to greenish
# narg  atextColor    Color of text in active tab, default black
# narg  itextColor    Color of text in inactive tab, default black
# narg  htextColor    Color of text in hover tab, default gray
# narg  isSticky      If true, pass thru cgi params, else delete 
# narg  boxContent    If true, draw box around content (if any)
# narg  isDropDown    If true, this is a drop-down menu
# narg  maSkin        If true, reoverload stringify to point at &asMA_skin
#-
sub new {
  my $class = shift;
  my $this = { activeColor   => 'BBBBBB', # dark grey
               inactiveColor => 'DEDEDE', # light grey 
               hoverColor => 'BBCCBB', # greenish
               atextColor => '000000', # black
               itextColor => '000000', # black
               htextColor => '444444', # gray
               isSticky => 0,
               boxContent => 1,
	       isDropDown => 0,
               maSkin => 0,
               paramName => '_tab',
               @_,
               _tabIndex => 0,
               _tabs => [ 'placeholder' ],
               _items => ()
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

  # Do we want to include current params?
  push @urlparams, -query => 1;
  $this->{_absQueryURL} = $cgi->url( @urlparams );

  #### If there's a password in here, strip it out!
  $this->{_absQueryURL} =~ s/password=.*?;/password=xxx;/;

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
  if ( $args{currsubtab} ) {
    $this->{_currentSubTab} = $args{currsubtab};
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
# Set hover color for mouseover on CSS tabs
# narg color    Color for hover
#-
sub setHoverColor {
  my $this = shift;
  my %args = @_;
  if ( $args{color} ) {
    $this->{hoverColor} = $args{color};
  }
}


#+
# Set active tab text color
# narg color    Color for text 
#-
#
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
  $this->{_table} = SBEAMS::Connection::DataTable->new( WIDTH => '100%',
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
# get tab content, allows for a crude 'append'
#-
sub getContent {
  my $this = shift;
  return $this->{_content}; 
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
#  @narg label  Name to put on tab itself REQ
#  @narg helptext Optional text to put in 'mouseover' info window. 
#  @narg url    Optional URL for this tab, overrides self URL if provided.
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
  my $url = ( $args{URL} ) ? $args{URL} : # Look for user-defined URL
            ( $this->{isSticky} ) ? $this->{_absQueryURL} : $this->{_absURL};
  
  $args{url} ||= $url;
  my $del = ( $args{url} =~ /\?/ ) ? '&' : '?';
  $args{url} .= "${del}$this->{paramName}=$this->{_tabIndex}";

  push ( @{$this->{_tabs}}, { url => $args{url}, label => $args{label}, helptext => $args{helptext} } );

  # return tab number in case it is useful to the caller.
  return $this->{_tabIndex};
}

#+
#  Add a new menu item to existing tab (heading)
#  @narg tablabel    Label of tab (heading) under which to put item REQ
#  @narg label       Name to put on item itself REQ
#  @narg url         URL for this item  REQ
#  @narg helptext    Optional text to put in 'mouseover' info window. 
#-
sub addMenuItem {
  my $this = shift;
  my %args = @_;
  for ( qw(tablabel label url) ) {
    die ("Missing parameter $_") unless $args{$_};
  }

  # Also append item index to url?
  my $del = ( $args{url} =~ /\?/ ) ? '&' : '?';
#  $args{url} .= "${del}$this->{paramName}=$this->{_tabIndex}";

  #check that tab label exists
  my @tabs = @{$this->{_tabs}};
  my $toptab;
  for( my $i = 1; $i <= $#tabs; $i++ ) {
      if ($args{tablabel} eq $tabs[$i]->{label}) {
	  $toptab = $args{tablabel};
	  last;
      }
  }
  die ("Could not find tab labeled $args{label}") unless $toptab;

  push ( @{$this->{_items}->{$toptab}}, { url => $args{url}, label => $args{label}, helptext => $args{helptext} } );

  # return SOMETHING ELSE? -- tab number in case it is useful to the caller.
  return $this->{_tabIndex};
}

sub addHRule {
  my $this = shift;
  $this->{hrule} = 1;
}

#+
#  returns numeric index of active tab
#-
sub getActiveTab {
  my $this = shift;
  
  if ( $this->{_currentTab} && $this->{_currentTab} <= $this->{_tabIndex} ) {
    # If a tab was already selected, it is active
    return ( $this->{_currentTab} )
    
  } elsif ( $this->{_defaultTab} ) {
    # Else use default
    return ( $this->{_defaultTab} );

  } else {
    # Else don't select any
    return 0;

  }
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

  if ($this->{isDropDown}) {
      return $this->asMenuCSSHTML2021(); # note: this is the only way to render drop-down menus at the moment
  } else {
      return $this->asCSSHTML2021();
  }

}


#+
# 2021 Rendering method for drop-down menus, returns CSS derived menu look 'n feel.
#-
sub asMenuCSSHTML2021 {
  my $this = shift;
  $this->{extra_width} = 499 if !defined $this->{extra_width};

  my $spc = "&nbsp;";

  # we will use this later
  my $tabmenu;

  my $table = "<div style='background:#d3d1c4;display:inline-block;width:100%;'>\n";

  my @tabs = @{$this->{_tabs}};
  my $dtab ||= $this->getActiveTab();

  for( my $i = 1; $i <= $#tabs; $i++ ) {
    my $color = ( $dtab == $i ) ? $this->{activeColor} : $this->{inactiveColor};
    my $htext =  ( $tabs[$i]->{helptext} ) ? "TITLE='$tabs[$i]->{helptext}'" : '';
    my $class = (  $dtab == $i ) ? 'atab' : '';

    if (exists $this->{_items}->{$tabs[$i]->{label}}) {
	my @items = @{$this->{_items}->{$tabs[$i]->{label}}};

	if ($dtab == $i) {
	    $table .= "<span class='tabmenuset $class' align='right' $htext> $tabs[$i]->{label} </span>\n";

	    $tabmenu = SBEAMS::Connection::TabMenu->
		new( cgi => $this->{cgi},
		     activeColor => 'ffffff',
		     inactiveColor   => 'f3f1e4',
		     hoverColor => '22eceb',
		     atextColor => '5e6a71', # black
		     itextColor => '5e6a71', # black
		     htextColor => '000', # black
		     paramName => '_subtab', # uses this as cgi param
		     )
		if !$tabmenu;

	    for my $item (@items) {
		$tabmenu->addTab(
				 label => $item->{label},
				 helptext => $item->{helptext},
				 URL => $item->{url}
				 );
	    }

	} else {

	    $table .= "<span onmouseover=\"showmenu('ddmenu$i')\" onmouseout=\"hidemenu('ddmenu$i')\" class='tabmenuset $class' id='ddtitle$i' $htext> $tabs[$i]->{label}";
	    $table .= "<span class='ddmenus' id='ddmenu$i'>\n";

	    for my $item (@items) {
		my $mhtext =  ( $item->{helptext} ) ? "title='$item->{helptext}'" : '';
		$table .= "<a class='ddmenu' $mhtext href='$item->{url}' >$item->{label} </a>\n";
	    }
	    $table .= "</span>\n</span>\n";
	}

    } else {
	$table .= "<a class='tabmenuset $class' align='right' href='$tabs[$i]->{url}' $htext> $tabs[$i]->{label} </a>\n";
    }

  }

  $table .= "</div>\n";

  if ($tabmenu) {
      $tabmenu->setCurrentTab( currtab => $this->{_currentSubTab} );
      $table .= "<div class='ddmenu' style='background:#$this->{activeColor};border-bottom:1px solid #$this->{atextColor};display:inline-block;padding-left:70px;width:calc(100% - 70px);'>".$tabmenu->asHTML()."</div>\n";
  }


  return ( <<"  END" );
  <!-- Begin TabDDMenu --> 
    <!-- CSS definitions -->
    <style type="text/css">
    .tabmenuset {
		margin: 0px;
	        list-style:none;
		white-space: nowrap;
                padding:0;
		float:left;
		display:block;
		color:#5e6a71;
		text-decoration:none;
		padding:6px 10px;
		font-weight:bold;
              	background:#$this->{inactiveColor};
		margin: 0px;
		border-right:1px solid #$this->{activeColor};
                }

    .tabmenuset:hover {
	       background:#$this->{hoverColor};
	       color:#$this->{htextColor};
               cursor: pointer;
	   }

    .tabmenuset.atab {
              background:#$this->{activeColor};
              color:#333333;
	      border-bottom:#$this->{activeColor};;
	  }

    .tabmenuset a:hover,
    .tabmenuset A.atab:hover {
              background:#$this->{hoverColor};
              color:#$this->{htextColor};
    }

    span.ddmenu, a.ddmenu{
              background:#$this->{activeColor};
              border-left: 4px solid #$this->{activeColor};
	      white-space: nowrap;
	      text-decoration:none;
	    display:block;
	    color:#$this->{atextColor};
	      padding:4px 6px;
	      font-weight:bold;
	      z-index:10;
	  }

    a.ddmenu:hover {
      border-left: 4px solid #b00;
    }

    span.ddmenus {
        min-width:170px;
	background:#$this->{activeColor};
	border: 1px solid #aaaaaa;
	border-collapse: collapse;
	visibility:hidden;
	position:absolute;
      display:inline-block;
	margin-top:1.5em;
	z-index:5;
	box-shadow: 0 4px 8px 0 rgba(0,0,0,0.2), 0 6px 20px 0 rgba(0,0,0,0.19);
      }

    </style>

    <SCRIPT LANGUAGE=JavaScript>
    function showmenu(elmnt){
      document.getElementById(elmnt).style.visibility="visible";
      var telmnt = elmnt.replace("menu", "title");
      if (document.getElementById(telmnt)) {
        document.getElementById(telmnt).style.backgroundColor = '#$this->{inactiveColor};';
        document.getElementById(elmnt).style.left = document.getElementById(telmnt).getBoundingClientRect().left - 1;
      }
    }

    function hidemenu(elmnt){
      document.getElementById(elmnt).style.visibility="hidden";
      var telmnt = elmnt.replace("menu", "title");
      if (document.getElementById(telmnt))
	  document.getElementById(telmnt).style.backgroundColor = '';
    }
    </SCRIPT>

    $table
    
  <!-- End TabMenu -->
  END

}


#+
# Rendering method for drop-down menus, returns CSS derived menu look 'n feel.
#-
sub asMenuCSSHTML {
  my $this = shift;
  $this->{extra_width} = 499 if !defined $this->{extra_width};

  my $spc = "&nbsp;";

  # we will use this later
  my $tabmenu;

  # Table for rendering stuff...
  my $table = "<table cellpadding='0' cellspacing='0' border='0'>\n<tr>\n";
  $table .= "<tr><td style='width:50;border-bottom:1px solid #bb0000;'><IMG SRC='$HTML_BASE_DIR/images/transparent.gif' HEIGHT='1' WIDTH='49' BORDER='0'></td>\n";

  my @tabs = @{$this->{_tabs}};
  my $dtab ||= $this->getActiveTab();

  for( my $i = 1; $i <= $#tabs; $i++ ) {
    my $color = ( $dtab == $i ) ? $this->{activeColor} : $this->{inactiveColor};
    my $htext =  ( $tabs[$i]->{helptext} ) ? "TITLE='$tabs[$i]->{helptext}'" : '';
    my $class = (  $dtab == $i ) ? 'class=atab' : '';

    if (exists $this->{_items}->{$tabs[$i]->{label}}) {
	my @items = @{$this->{_items}->{$tabs[$i]->{label}}};

	if ($dtab == $i) {
	    $table .= "<td class=tabmenuset align='right'><A $class HREF='#' $htext> $tabs[$i]->{label} </A></td>\n";

	    $tabmenu = SBEAMS::Connection::TabMenu->
		new( cgi => $this->{cgi},
		     activeColor => 'ffffff',
		     inactiveColor   => 'f3f1e4',
		     hoverColor => 'bb0000',
		     atextColor => '000000', # black
		     itextColor => '000000', # black
		     htextColor => 'ffffff', # white
		     paramName => '_subtab', # uses this as cgi param
		     )
		if !$tabmenu;

	    for my $item (@items) {
		$tabmenu->addTab(
				 label => $item->{label},
				 helptext => $item->{helptext},
				 URL => $item->{url}
				 );
	    }

	} else {

	    $table .= "<td onmouseover=\"showmenu('ddmenu$i')\" onmouseout=\"hidemenu('ddmenu$i')\" class=tabmenuset><a $class HREF='#' $htext> $tabs[$i]->{label} </A><br/>\n";
	    $table .= "<table class=ddmenu id=ddmenu$i cellspacing=0>\n";

	    for my $item (@items) {
		my $mhtext =  ( $item->{helptext} ) ? "TITLE='$item->{helptext}'" : '';
		$table .= "<tr><td class=ddmenu> <a class=ddmenu $mhtext href='$item->{url}' >$item->{label} </a></td></tr>\n";
	    }
	    $table .= "</table>\n</td>\n";
	}

    } else {
	$table .= "<td class=tabmenuset align='right'><A $class HREF='$tabs[$i]->{url}' $htext> $tabs[$i]->{label} </A></td>\n";
    }

  }
  $table .= "<td style='width:500;border-bottom:1px solid #bb0000;'><IMG SRC='$HTML_BASE_DIR/images/transparent.gif' HEIGHT='1' WIDTH='$this->{extra_width}' BORDER='0'></td>\n</tr>\n";

  if ($tabmenu) {
      $tabmenu->setCurrentTab( currtab => $this->{_currentSubTab} );
      $table .= "<tr><td class=ddmenu>$spc</td><td class=ddmenu colspan=99>".$tabmenu->asHTML()."</td></tr>\n";
  }

  $table .= "</table>\n";

  return ( <<"  END" );
  <!-- Begin TabDDMenu --> 
    <!-- CSS definitions -->
    <style type="text/css">
    .tabmenuset {
		 padding:0 0 0 0;
		 margin: 0px;
	         list-style:none;
		 white-space: nowrap;
	       }

    .tabmenuset A {
                padding:0;
		float:left;
		display:block;
		color:#827975;
		text-decoration:none;
		padding:4;
		font-weight:bold;
              	background:#$this->{inactiveColor};
		margin: 0px;
		border-top:1px solid #$this->{inactiveColor};
		border-bottom:1px solid #bb0000;
		border-right:1px solid #827975;
                }

    .tabmenuset A:hover {
               border-bottom:1px solid #bb0000;
	       border-top:1px solid #bb0000;
	       background:#$this->{hoverColor};
	       color:#$this->{htextColor};
	   }

    .tabmenuset A:active,
    .tabmenuset A.atab:link,
    .tabmenuset A.atab:visited {
              background:#$this->{activeColor};
              color:#333333;
	      border-top:1px solid #bb0000;
	      border-left:1px solid #bb0000;
	      border-right:1px solid #bb0000;
	      border-bottom:0;
	  }

    .tabmenuset A.atab:hover {
              background:#$this->{hoverColor};
              color:#$this->{htextColor};
    }

    td.ddmenu, a.ddmenu{
              background:#$this->{activeColor};
	      white-space: nowrap;
	      border-style: none;
	      font-weight:bold;
	      padding-right:20;
	      padding-left:10;
	      z-index:10;
	  }

    table.ddmenu {
        width:170px;
	background:#$this->{activeColor};
	border-color: #c6c1b8;
	border-width: 1px 1px 1px 1px;
	border-style: solid;
	border-collapse: collapse;
	visibility:hidden;
	position:absolute;
	z-index:2;
      }

    </style>

    <SCRIPT LANGUAGE=JavaScript>
    function showmenu(elmnt){   
        document.getElementById(elmnt).style.visibility="visible";
    }

    function hidemenu(elmnt){
        document.getElementById(elmnt).style.visibility="hidden";
    }
   </SCRIPT>

    $table
    
  <!-- End TabMenu -->
  END

}



#+
# Rendering method, returns CSS derived menu look 'n feel.
#-
sub asCSSHTML2021 {
  my $this = shift;

  # Get table for rendering stuff...
  $this->getTable();

  my @tabs = @{$this->{_tabs}};
  my @row;
  my $dtab ||= $this->getActiveTab();

  my $list = "<div id='menuset'>\n";

  for( my $i = 1; $i <= $#tabs; $i++ ) {
    my $spc = "&nbsp;";
    my $color = ( $dtab == $i ) ? $this->{activeColor} : $this->{inactiveColor};
    my $htext =  ( $tabs[$i]->{helptext} ) ? "title='$tabs[$i]->{helptext}'" : '';
    my $class = (  $dtab == $i ) ? 'class=atab' : '';
    $list .= "<a $class href='$tabs[$i]->{url}' $htext> $tabs[$i]->{label} </A>"
  }
  $list .= "</div>\n";

  my $border = '';
  if ( $this->{boxContent} ) {
    $border = 'border:1px solid #5e6a71;';
  }

  if ( $this->{_content} ) {
    $list .= "<br clear='both'><div style='min-height:200px; padding:0px 10px; $border'>$this->{_content}</div>\n";
  }


  return ( <<"  END" );
  <!-- Begin TabMenu --> 
    <!-- CSS definitions -->
    <style type="text/css">
    #menuset {
             position:relative;
	           float:left;
	           width:100%;
	           padding:0 0 0 0;
	           margin: 0px;
	           list-style:none;
	           line-height:1.75em;
             }
   
    #menuset LI {
                float:left;
	        margin: 0px;
	        padding:0;
                }

    #menuset A {
	        padding:0;
                float:left;
                display:block;
              	color:#$this->{atextColor};
              	text-decoration:none;
                padding:0.25em 1em;
              	font-weight:bold;
              	background:#$this->{inactiveColor};
              	margin: 0px;
              	border-left:1.25px solid #FFFFFF;
              	border-top:1.25px solid #FFFFFF;
              	border-right:1.25px solid #AAAAAA;
                }

    #menuset A:hover {
	    background:#$this->{hoverColor};
            color:#$this->{htextColor};
    }
    #menuset A:active,
    #menuset A.atab:link,
    #menuset A.atab:visited {
	    background:#$this->{activeColor};
     	    color:#$this->{atextColor};
            position: relative;
            top: 1px;
            border-left: 1px solid;
            border-right: 1px solid;
            border-top: 1px solid;
    }
    #menuset A.atab:hover {
	    background:#$this->{hoverColor};
            color:#$this->{htextColor};
    }
    </style>

  $list
    
  <!-- End TabMenu -->
  END

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
    my $htext =  ( $tabs[$i]->{helptext} ) ? "TITLE='$tabs[$i]->{helptext}'" : '';
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

  $this->setRule() if $this->{hrule};
  
  return ( <<"  END" );
  <!-- Begin TabMenu --> 
    <!-- CSS definitions -->
    <style type="text/css">
    #menuset {
             position:relative;
	           float:left;
	           width:100%;
	           padding:0 0 0 0;
	           margin: 0px;
	           list-style:none;
	           line-height:1.75em;
             }
   
    #menuset LI {
                float:left;
	        margin: 0px;
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
              	background:#$this->{inactiveColor};
              	margin: 0px;
              	border-left:1.25px solid #FFFFFF;
              	border-top:1.25px solid #FFFFFF;
              	border-right:1.25px solid #AAAAAA;
                }

    #menuset A:hover {
	    background:#$this->{hoverColor};
            color:#$this->{htextColor};
    }
    #menuset A:active,
    #menuset A.atab:link,
    #menuset A.atab:visited {
	    background:#$this->{activeColor};
     	    color:#333333;
    }
    #menuset A.atab:hover {
	    background:#$this->{hoverColor};
            color:#$this->{htextColor};
    }
    </style>

  $this->{_table}
    
  <!-- End TabMenu -->
  END
#return "$this->{_table}";
}




sub setRule {
  my $this = shift;
  my $cnt = ( $this->getNumTabs() ) * 2 + 5 ;
  $this->{_table}->addRow ( [ "<IMG SRC='$HTML_BASE_DIR/images/transparent.gif' HEIGHT='2' WIDTH='1' BORDER='0'>" ] );
  $this->{_table}->setCellAttr ( COL => 1, ROW => 2, COLSPAN => $cnt, BGCOLOR => $this->{activeColor} );
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

# Add horizontal rule...
  $this->{_table}->addRow ( [ "<IMG SRC='$HTML_BASE_DIR/images/transparent.gif' HEIGHT='2' WIDTH='1' BORDER='0'>" ] );
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

# Add horizontal rule...
  $this->{_table}->addRow ( [ "<IMG SRC='$HTML_BASE_DIR/images/transparent.gif' HEIGHT='2' WIDTH='1' BORDER='0'>" ] );
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
