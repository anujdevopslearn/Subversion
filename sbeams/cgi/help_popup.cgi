#!/usr/bin/perl -wT

#################################################################################
#																#
# Program:	help_popup.cgi											#
# Author:		Michelle Whiting										#
# Created:	03/11/02												#
#																#
# Window popped up by JavaScript, with help text.							#
#																#
#################################################################################

###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($q $sbeams $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../lib/perl);
use Env qw(HTTP_USER_AGENT);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;

$q   = new CGI;
$sbeams = new SBEAMS::Connection;


###############################################################################
# The database ID for the help text being requested
###############################################################################
my $help_text_id	= $q->param( 'help_text_id' );

######################################
# Get the help text from the database
######################################
my (@help_text) = $sbeams->selectSeveralColumns("
	SELECT	title,
			help_text
	FROM		help_text
	WHERE	help_text_id = '$help_text_id'
");

my $title	= $help_text[0][0];
my $text	= $help_text[0][1];


########################
#Start printing the page
########################

my $FONT_SIZE=12;
$FONT_SIZE=10 if ( $HTTP_USER_AGENT =~ /Win/ );

print $q->header( "text/html" );


print qq~
<HTML>
<HEAD>
<TITLE>SBEAMS Help - $title</TITLE>
<style type="text/css">
//<!--
body {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
td   {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
form   {  font-family: Tahoma, Arial, Helvetica, sans-serif; font-size: ${FONT_SIZE}pt;}
//-->
</style>
</HEAD>

<BODY bgcolor="#ffffff" alink=#ff3399 link=#6600cc text=#000000 vlink=#993366 leftmargin=0 topmargin=0>
<table border=0 cellspacing=0 cellpadding=0 width=100%>
	<tr height=25>
		<td bgcolor=#99cc66 align=right>
			<font size=2>
			Need more help? Email <a href="mailto:edeutsch\@systemsbiology.org">Eric Deutsch</a>&nbsp;
		</td>
	</tr>
</table>
<p>
<table border=0 cellspacing=0 cellpadding=0 width=90% align=center>
	<tr>
		<td>
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

