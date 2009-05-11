#!/usr/local/bin/perl -w

###############################################################################
# Program     : help_popup.cgi
# Author      : Michelle Whiting <mwhiting@systemsbiology.org>
# $Id$
#
# Description : Window to be popped up by JavaScript, with help text.
#
# SBEAMS is Copyright (C) 2000-2006 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

###############################################################################
# Usage: create a popup link as follows:
#
#	<a href="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?
#		help_text_id=1','Help','width=500,height=400,resizable=yes');
#		return false">Link</a>
#
# Where the help_text_id is the database Id if the help text you want to be
# displayed. Remember to set the width & height to the size you'd like the
# window to be.
###############################################################################

###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($q $sbeams $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib "../lib/perl";
use Env qw(HTTP_USER_AGENT);
#use CGI;
use Data::Dumper;
use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::DataTable;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;

#$q   = new CGI;
$sbeams = new SBEAMS::Connection;

###############################################################################
# Define Standard Variables
###############################################################################
my ($title, $text);

###############################################################################
# The database ID for the help text being requested
###############################################################################
my $help_text_id   = $q->param( 'help_text_id' );
my $column_name	   = $q->param( 'column_name' );
my $table_name     = $q->param( 'table_name' );
my $table_group    = $q->param( 'table_group' );
my @groups         = $q->param( 'groupinfo' );
my $project_id     = $q->param( 'project_id' );
my $email_link     = $q->param( 'email_link' ) || 'yes';
my $session_key     = $q->param( 'session_key' );

if ($help_text_id) {
######################################
# Get the help text from the database
######################################
  my (@help_text) = $sbeams->selectSeveralColumns("
	SELECT	title,help_text
	FROM		help_text
	WHERE	help_text_id = '$help_text_id'
  ");

#####################################
# Get the title and text out of the 
# array reference
#####################################
	$title	= $help_text[0][0];
	$text	= $help_text[0][1];
}elsif ($column_name && $table_name) { # Display column 'help' text.

  displayColumnText( $column_name, $table_name );
  exit 0;

}elsif ( scalar @groups ) { # Group info?

  displayGroupInfo( \@groups, $table_name, $table_group );
  exit 0;

}elsif ( $session_key ) { # Text passed via session_id 
  # Pick your poison!  One of these is required to make it work
  $sbeams->getSessionCookie();
#  $sbeams->Authenticate();
  $title = $q->param('title');
  $text = $sbeams->getSessionAttribute( key => $session_key );
  print STDERR "got key  $session_key => $text\n";

}else {
	 $title = $q->param('title');
	 $text = $q->param('text');
}

########################
#Start printing the page
########################

my $FONT_SIZE=12;
$FONT_SIZE=10 if ( $HTTP_USER_AGENT =~ /Win/ );

print $q->header('text/html');
my $email_help = '<BR>';
if ( $email_link =~ /yes/i ) {
$email_help =<<"  END";
  <table border=0 cellspacing=0 cellpadding=0 width=100%>
  	<tr height=25>
  		<td bgcolor=#99cc66 align=right>
  			<font size=2>
  			Need more help? Email <a href="mailto:$DBADMIN">your local $DBTITLE administrator $DBADMIN</a>&nbsp;
  		</td>
  	</tr>
  </table>
  END
}

print qq~
<HTML>
<HEAD>
<TITLE>SBEAMS Help - $title</TITLE>
<style type="text/css">
body {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
td   {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
form   {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
</style>
</HEAD>

<BODY bgcolor="#ffffff" alink=#ff3399 link=#6600cc text=#000000 vlink=#993366 leftmargin=0 topmargin=0>
$email_help
<p>
<table border=0 cellspacing=0 cellpadding=0 width=90% align=center>
	<tr>
		<td ALIGN=CENTER>
			<font size=2>
			<b>$title</b>
			<p>
			$text
		</td>
	</tr>
</table>
<p>&nbsp;<p>
<center>
<font size=2 face="Tahoma, Arial, Helvetica, sans-serif">
<a href="#" onClick='self.close()'>Close Window</a>

</BODY>
</HTML>
~;

sub displayColumnText {
  my $column_name = shift;
  my $table_name = shift;

  my @text = $sbeams->selectSeveralColumns( <<"  END" );
	SELECT	column_title, column_text
	FROM $TB_TABLE_COLUMN
	WHERE	table_name = '$table_name'
	AND	column_name = '$column_name'
  END

  my $row = $text[0];
  my ( $title, $text );
  if ( !$row ) {
    $title = "Unable to find column information";
    $text = "Unable to find information on reference column";
  } else {
    ( $title, $text ) = @$row;


  if ( $text =~ /(<A HREF *=.*<\/A>?)/i ) {
    # We seem to have a link, save it aside while escaping HTML
    my $link = $1;
    $text =~ s/\Q$link\E/LINKPLACEHOLDER/gm;
    $text = $q->escapeHTML( $text );
    $text =~ s/LINKPLACEHOLDER/$link/;
  } else {
    $text = $q->escapeHTML( $text );
  }

  $title = $q->escapeHTML( $title );
  }

  my $FONT_SIZE=12;
  $FONT_SIZE=10 if ( $HTTP_USER_AGENT =~ /Win/ );

  print $q->header( "text/html" );

  print <<"  END_PAGE";
<HTML>
<HEAD>
<TITLE>SBEAMs help - $title</TITLE>
<style type="text/css">
  body {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
  td   {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
  form   {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
  </style>
  </HEAD>

  <BODY bgcolor="#ffffff" alink=#ff3399 link=#6600cc text=#000000 vlink=#993366 leftmargin=0 topmargin=0>
  <p>
  <table border=0 cellspacing=0 cellpadding=0 width=90% align=center>
   <tr><TD>&nbsp;</TD>
   </tr>
   <tr>
     <td ALIGN=CENTER>
       <font size=2>
       <b>$title:</b>
     </td>
   </tr>
   <tr><TD>&nbsp;</TD>
   </tr>
   <tr><TD>&nbsp;</TD>
   </tr>
   <tr>
     <td ALIGN=CENTER>
       <font size=2>
       $text
     </td>
   </tr>
  </table>
  <p>&nbsp;<p>
  <center>
  <font size=2 face="Tahoma, Arial, Helvetica, sans-serif">
  <a href="#" onClick='self.close()'>Close Window</a>

  </BODY>
  </HTML>
  END_PAGE
 

}


sub displayGroupInfo {
  my $groups = shift;
  my $table = shift;
  my $tgroup = shift;
  my $msg = '';

  $msg =<<"    END_MSG";
    <FONT size=1 face="Tahoma, Arial, Helvetica, sans-serif">
    This shows the permissions you have on the table <I>$table</I>,
    which is in the table group <I>$tgroup</I>
    </FONT>
    END_MSG

  my %perms = $sbeams->getPrivilegeNames();
              
  $table = SBEAMS::Connection::DataTable->new( BORDER => 0, CELLPADDING => 2 );
  $table->addRow( [ '<B>Group Name</B>', '<B>Group Id&nbsp;&nbsp;</B>', '<B>Privilege</B>' ] );
  $table->addRow( [ '&nbsp;' ] );
  $table->setColAttr( COLS => [1], ROWS => [2], COLSPAN => 3, style => 'font-size:1pt', bgcolor => '#BBBBBB' );
  $table->setColAttr( COLS => [1, 3], ROWS => [1, 3..scalar(@groups) + 2], ALIGN => 'LEFT' );
  $table->setColAttr( COLS => [2], ROWS => [1, 3..scalar(@groups) + 2], ALIGN => 'CENTER' );

  foreach my $grp ( @groups ) {
    my @grp = split( ":::", $grp, -1 );
    $table->addRow( [ $grp[0], $grp[1], ucfirst($perms{$grp[2]}) ] );
  }
  
  $title = $q->escapeHTML( $title );

  my $fontsize = ( $HTTP_USER_AGENT =~ /Win/ ) ? 10 : 10;

  print $q->header( "text/html" );

  print <<"  END_PAGE";
  <HTML>
  <HEAD>
  <TITLE>SBEAMs help - $title</TITLE>
  <style type="text/css">
  //<!--
  body {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${fontsize}pt;}
  td   {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${fontsize}pt;}
  form   {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${fontsize}pt;}
  //-->
  </style>
  </HEAD>

  <BODY bgcolor="#ffffff" alink=#ff3399 link=#6600cc text=#000000 vlink=#993366 leftmargin=0 topmargin=0>
  <CENTER>
  <BR>
  $msg
  <BR>
  <BR>
  $table 
  <BR>
  <BR>
  <font size=2 face="Tahoma, Arial, Helvetica, sans-serif">
  <a href="#" onClick='self.close()'>Close Window</a>
  </CENTER>

  </BODY>
  </HTML>
  END_PAGE

}
