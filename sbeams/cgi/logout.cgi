#!/usr/local/bin/perl -T

###############################################################################
# Program     : logout.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script logs the user out by destroying
#               his or her cookie.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
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
$PROGRAM_FILE_NAME = 'logout.cgi';
main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue and destroy the user's cookie.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Call processLogut which prints a header and message, and print footer
    processLogout();
    $sbeams->printPageFooter();

} # end main


###############################################################################
# Replace the user's cookie with a wrecked, expired one 
###############################################################################
sub processLogout {

    #### Destroy the user's cookie by replacing with an invalid one and
    #### Send that broken cookie to the user in a "thanks" message.
    $sbeams->destroyAuthHeader();
    $sbeams->printPageHeader();

    printThanksForExiting();

} # end processLogout


###############################################################################
# Print Thanks For Exiting Message
###############################################################################
sub printThanksForExiting {

    print qq~
        <P>
        <H2>Logged Out</H2>
        $LINESEPARATOR
        <P>
        <TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
        You have logged out of $DBTITLE.
        This insures that no one will come behind you and use your 
        browser session and your username to access the $DBTITLE system.
        <P>
        </TD></TR></TABLE>
        $LINESEPARATOR
        <P>
        [ <a href="$CGI_BASE_DIR/main.cgi">Login Again</A> ]
    ~;

} # end printThanksForExiting

