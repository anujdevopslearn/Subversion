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
	You have successfully logged into the $DBTITLE interface.<BR>
	Note your current user group above, and click [CHANGE] to change it.<P> 

	Please choose a section/subsection/task from the menu bar on the
	left to continue.<P>

	This system is still under active development.  Please
	report bugs, problems, difficulties, and suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>

	<UL>
	<LI><A HREF="Microarray/main.cgi">SBEAMS - Microarray</A>
	<BR><BR>
	<LI><A HREF="Proteomics/main.cgi">SBEAMS - Proteomics</A>
	<BR><BR>
	<LI><A HREF="Inkjet/main.cgi">SBEAMS - Inkjet</A>
	<BR><BR>
	<LI><A HREF="Biosap/main.cgi">SBEAMS - BioSap</A>
	<BR><BR>
	<LI><A HREF="PhenoArray/main.cgi">SBEAMS - Phenotype Array</A>
	<BR><BR>
	<LI><A HREF="SNP/main.cgi">SBEAMS - SNP</A>
	<BR><BR>
	<LI><A HREF="BEDB/main.cgi">SBEAMS - BEDB</A>
	<BR><BR>
	<LI><A HREF="GEAP/main.cgi">SBEAMS - GEAP</A>
	<BR><BR>
	<LI><A HREF="tools/main.cgi">SBEAMS - Tools</A>
	</UL>

	<BR>
	<BR>
    !;

} # end showMainPage


