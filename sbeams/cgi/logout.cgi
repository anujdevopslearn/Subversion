#!/usr/local/bin/perl

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
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$sbeams = new SBEAMS::Connection;

use CGI;
$q = new CGI;


###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag to level n
  --testonly          Set testonly flag which simulates INSERTs/UPDATEs only

 e.g.:  $PROG_NAME --verbose 2 keyword=value

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","quiet")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "   VERBOSE = $VERBOSE\n";
  print "     QUIET = $QUIET\n";
  print "     DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);



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

