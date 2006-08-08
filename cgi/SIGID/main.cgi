#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($q $sbeams $sbeamsSIGID $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
#use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;

use SBEAMS::SIGID;
use SBEAMS::SIGID::Settings;

#$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsSIGID = new SBEAMS::SIGID;
$sbeamsSIGID->setSBEAMS($sbeams);


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
    $sbeamsSIGID->printPageHeader();
    showMainPage();
    $sbeamsSIGID->printPageFooter();

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

	<UL>

        Despite the availability of a large number of antibiotics,
        infections still represent an important cause of morbidity and
        mortality.  The Swiss Immunogenetic Study on Infectious
        Disease has been established to better understand why some
        individuals are more susecptible to infections than others.
        The aim of the study is to determine whether individuals
        hospitalized with very severe infections (e.g. meningitis or
        septic shock) have specific genetic characteristics that make
        them more susceptible to a specific pathogen.  The discovery
        of such genetic differences between individuals will help to
        better understand the immune response to infectious agent and
        to find new drugs and vaccines.

        <BR>
        <BR>

        Malgr&#233 le grand nombre d'antibiotiques &#224 disposition,
        les infections constituent encore un cause importante de
        maladie et et de mortalit&#233 dans la population. L'Etude
        Immunog&#233n&#233tique suisse sur les Maladies Infectieuses a
        &#233t&#233 mise en place pour mieux comprendre pourquoi
        certains individus sont plus sensibles aux infections que
        d'autres. Le but de l'&#233tude est de d&#233terminer si les
        personnes hospitalis&#233es pour des infections
        s&#233v&#232res (par exemple m&#233ningites ou chocs
        septiques) poss&#232dent des charact&#233ristiques
        g&#233n&#233tiques qui les rendent particuli&#232rement
        sensibles &#224 certains agents pathog&#232nes. La
        d&#233couverte de telles diff&#233rences g&#233n&#233tiques
        entre individus permettra de mieux comprendre la r&#233ponse
        immunitaire aux infections et d'&#233tablir de nouveaux
        m&#233dicaments et de nouveaux vaccins.

        <BR>
        <BR>

        Put German blurb here...

        </UL>

	<BR>
	<BR>

	This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions to
	<B>kdeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>

	<BR>
	<BR>
    !;

} # end showMainPage


