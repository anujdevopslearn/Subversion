#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;

use SBEAMS::Interactions;
use SBEAMS::Interactions::Settings;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Interactions;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
$q = new CGI;


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
    $sbeamsMOD->printPageHeader();
    showMainPage();
    $sbeamsMOD->printPageFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

    $sbeams->printUserContext();

    print qq!
	<BR>
	You are successfully logged into the $DBTITLE - $SBEAMS_PART system.
	Please choose your tasks from the menu bar on the left.<P>
	<BR>
	<font color=red>TO ENTER A BATCH OF INTERACTIONS:</font>
	<UL>
	<LI> Know the Project under which the interactions should be entered.
	     If there isn't yet one, create it by clicking [Projects] [Add Project]
	<LI> Do you already have a suitable Interaction Group for your interactions?
	     If there isn't yet one, create it by clicking [Interactions]
	     [Manage Interaction Groups]  [Add Interaction Group]
	<P>
	<LI> Enter the relevant publications with [Publications] [Add Publication]
	<LI> Enter the relevant assays with [Assay] [Add Assay].  If the assay is
	     just for an existing publication for which little additional details
	     are to be added, just make the Assay Name the same as the Publication Name
	<LI> Enter the relevant Bioentities involved in the interactions
	     with [Bioentities] [Add Bioentity]
	<LI> Enter the relevant Interactions with [Interactions] [Add Interaction]
	</UL>

	This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>

	<BR>
	<BR>
    !;

} # end showMainPage


