#!/usr/local/bin/perl

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
use vars qw ($q $sbeams $sbeamsIJ $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;

use SBEAMS::Inkjet;
use SBEAMS::Inkjet::Settings;

$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsIJ = new SBEAMS::Inkjet;
$sbeamsIJ->setSBEAMS($sbeams);


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

    #### Read in the default input parameters
    my %parameters;
    my $n_params_found = $sbeams->parse_input_parameters(
				     q=>$q,parameters_ref=>\%parameters);
    #$sbeams->printDebuggingInfo($q);


    #### Process generic "state" parameters before we start
    $sbeams->processStandardParameters(
    parameters_ref=>\%parameters);


    #### Print the header, do what the program does, and print footer
    $sbeamsIJ->printPageHeader();
    showMainPage();
    $sbeamsIJ->printPageFooter();

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
	This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions to
	<B>edeutsch\@systemsbiology.org</B>.
	<P>
	<center>
	<img src="$HTML_BASE_DIR/images/maimagemap.gif" usemap="#map" border=0>
	<map name="map">
		<area shape=rect coords="6,6,106,56" href="ManageTable.cgi?TABLE_NAME=project&ShowEntryForm=1">
		<area shape=rect coords="99,65,199,115" href="SubmitArrayRequest.cgi?TABLE_NAME=IJ_array_request&ShowEntryForm=1">
		<area shape=rect coords="190,124,290,174" href="ManageTable.cgi?TABLE_NAME=IJ_array&ShowEntryForm=1">
		<area shape=rect coords="281,183,381,233" href="ManageTable.cgi?TABLE_NAME=IJ_array_scan&ShowEntryForm=1">
		<area shape=rect coords="371,241,471,291" href="ManageTable.cgi?TABLE_NAME=IJ_array_quantitation&ShowEntryForm=1">
		<area shape=rect coords="432,301,562,351" href="ProcessProject.cgi">
		<area shape=rect coords="59,178,159,228" href="ManageTable.cgi?TABLE_NAME=IJ_hybridization&ShowEntryForm=1">
		<area shape=rect coords="59,254,159,304" href="ManageTable.cgi?TABLE_NAME=IJ_labeling&ShowEntryForm=1">
		<area shape=rect coords="324,11,424,61" href="ManageTable.cgi?TABLE_NAME=IJ_slide_lot&ShowEntryForm=1">
		<area shape=rect coords="451,11,551,61" href="ManageTable.cgi?TABLE_NAME=IJ_slide_model&ShowEntryForm=1">
		<area shape=rect coords="395,75,495,125" href="ManageTable.cgi?TABLE_NAME=IJ_printing_batch&ShowEntryForm=1">
		<area shape=rect coords="469,137,569,187" href="ManageTable.cgi?TABLE_NAME=IJ_protocol&ShowEntryForm=1">
    !;
    # Depending on user context, the image map links will be printed?
    print qq!
	</map>
	<p>

	<BR>
	<BR>
    !;

} # end showMainPage


