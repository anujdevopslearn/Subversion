#!/usr/local/bin/perl -T

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($q $sbeams $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../lib/perl);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;

$q   = new CGI;
$sbeams = new SBEAMS::Connection;


###############################################################################
# Global Variables
###############################################################################
$PROGRAM_FILE_NAME = 'main.cgi';
main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Print the header, do what the program does, and print footer
    $sbeams->printPageHeader();
    showMainPage();
    $sbeams->printPageFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

    $sbeams->printUserContext();

    print qq!
	<BR>
	You are successfully logged into the $DBTITLE system.<P>
	Note your current user group above, and click [CHANGE] to change it.<P> 
	Please choose a section/task from the menu bar on the left.<P>
	<BR>
	This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>

	<UL>
	<LI><A HREF="MicroArrayMain.cgi">SBEAMS - MicroArray</A>
	<BR><BR>
	<LI><A HREF="Proteomics/main.cgi">SBEAMS - Proteomics</A>
	<BR><BR>
	<LI><A HREF="Inkjet/main.cgi">SBEAMS - Inkjet</A>
	<BR><BR>
	<LI><A HREF="GEAP/main.cgi">SBEAMS - GEAP</A>
	<BR><BR>
	<LI><A HREF="tools/main.cgi">SBEAMS - Tools</A>
	</UL>

	<BR>
	<BR>
    !;

} # end showMainPage


