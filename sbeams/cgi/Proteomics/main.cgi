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
use vars qw ($q $sbeams $sbeamsPROT $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;

$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsPROT = new SBEAMS::Proteomics;
$sbeamsPROT->setSBEAMS($sbeams);


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
    exit unless ($current_username = $sbeams->Authenticate(
      #connect_read_only=>1,
      #allow_anonymous_access=>1,
      #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
    ));

    #### Print the header, do what the program does, and print footer
    $sbeamsPROT->printPageHeader();
    showMainPage();
    $sbeamsPROT->printPageFooter();

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
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>

	The navigation bar on the left will take you to the various
	capabilities available thus far, or choose from this more
	descriptive list:
	<UL>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project">Manage Project information</a> (Click to add a new project under which to register experiments)
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=proteomics_experiment">Manage Experiment information</a> (Click to add information about a proteomics experiment; required before data load)
	<P>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeFractions">Summarize fractions/spectra over one or more experiments</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizePeptides">Summarize proteins/peptides over one or more experiments</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/CompareExperiments">Compare number of proteins/peptides found over two or more experiments</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetSearchHits">Browse possible peptide identifications from sequest searches</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseBioSequence.cgi">Browse biosequences in the database</a>
	<P>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=biosequence_set">Manage BioSequence Database information</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=dbxref">Manage Database Cross-reference information</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_gradient_program">Manage Gradient Program information</a>
	<P>
	<LI><a href="http://db.systemsbiology.net:8080/proteomicsToolkit/">Access Proteomics Toolkit Interface</a>
	<LI><a href="$HTML_BASE_DIR/doc/$SBEAMS_SUBDIR/${SBEAMS_PART}_Schema.gif">View GIF of the database schema</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/flycat.cgi">Go to the prototype FLYCAT interface</a>
	</UL>

	<BR>
	<BR>
    !;

} # end showMainPage


