#!/usr/local/bin/perl -T

###############################################################################
# Program     : flycat.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page for FLYCAT queries.
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
use SBEAMS::Connection::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

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
    exit unless ($current_username = $sbeams->Authenticate());

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

    print qq~
	<BR>
	Welcome to FLYCAT, a catalog of peptides observed in Drosophila.
	<P>
	Click on one of the links below to view annotations for genes
	beginning with the character...<P>
	<BR>
    ~;

    my $sql = qq~
	SELECT SUBSTRING(biosequence_name,1,1) AS 'first letter',COUNT(*) AS 'Count'
	  FROM $TB_BIOSEQUENCE
	 WHERE biosequence_set_id = 3
	 GROUP BY SUBSTRING(biosequence_name,1,1)
	 ORDER BY 1
    ~;


    my @columns = $sbeams->selectOneColumn($sql);

    my $element;
    foreach $element (@columns) {
      $element = uc($element);
      print "<a href=\"$CGI_BASE_DIR/Proteomics/BrowseAnnotatedPeptides.cgi?search_batch_id=1,4&display_options=GroupReference,BSDesc&reference_constraint=$element\%25&apply_action=QUERY\">&nbsp;$element&nbsp;</a> "
    }

    print qq~
	<BR>
	<BR>
    ~;

} # end showMainPage


