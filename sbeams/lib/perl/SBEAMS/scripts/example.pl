#!/usr/bin/perl -T

###############################################################################
# Program     : example.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script is an example of using the command-line SBEAMS
#               interface.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($sbeams $dbh $PROGRAM_FILE_NAME
             $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name);
use lib qw (../..);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

$sbeams = new SBEAMS::Connection;


###############################################################################
# Global Variables
###############################################################################
$PROGRAM_FILE_NAME = 'example.pl';
main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username =
        $sbeams->Authenticate(work_group=>'Other'));

    #### Print the header, do what the program does, and print footer
    $sbeams->printTextHeader();
    showMainPage();
    $sbeams->printTextFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

    $current_username = $sbeams->getCurrent_username;
    $current_contact_id = $sbeams->getCurrent_contact_id;
    $current_work_group_id = $sbeams->getCurrent_work_group_id;
    $current_work_group_name = $sbeams->getCurrent_work_group_name;
    $current_project_id = $sbeams->getCurrent_project_id;
    $current_project_name = $sbeams->getCurrent_project_name;
    $dbh = $sbeams->getDBHandle();


    $sbeams->printUserContext(style=>'TEXT');

    print qq!
	You are successfully logged into the $DBTITLE system.  Your
	task would go here and do whatever you like.
    !;

} # end showMainPage

