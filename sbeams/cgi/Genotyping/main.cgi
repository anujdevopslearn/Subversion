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
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($q $sbeams $sbeamsGenotyping $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;

use SBEAMS::Genotyping;
use SBEAMS::Genotyping::Settings;

$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsGenotyping = new SBEAMS::Genotyping;
$sbeamsGenotyping->setSBEAMS($sbeams);


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
    $sbeamsGenotyping->printPageHeader();
    showMainPage();
    $sbeamsGenotyping->printPageFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

    $sbeams->printUserContext();

    print qq!

        <BR> You are successfully logged into the $DBTITLE -
        $SBEAMS_PART system.  This module allows users to submit a
        request to the Genotyping Facility.  Please choose your tasks
        from the menu bar on the left, or read below for an overview
        of the process.<BR><BR>

        <font color=red>TO SUBMIT A GENOTYPING REQUEST:</font>

        <UL>

        <LI> Know the Project under which the submission should be
        entered.  If there isn\'t one yet, create it by clicking
        [Projects] [Add Project]

        <LI> Select the request options with [Experiments] [Add Experiment]

        <LI> Two forms are required: a Sample file and a SNP file.
        Example of the required formats can be seen by clicking <A HREF="$HTML_BASE_DIR/doc/Genotyping/SampleFileColumnDefinitions.php">[File formats]</A>.

        <LI> After submitting the request, you will receive an email
        with a cost estimate and approximate delivery date.</UL><BR><BR>

        <font color=red>PLEASE READ THE FOLLOWING CAREFULLY:</font><BR><BR>

        <B> DNA criteria </B>

        <UL>
        <LI> DNA should be quantified using a SNA specific
        method.  We recommend the Pico Green method (Molecular
        Probes catalog number R-21495 http://www.molecularprobes.com)
        or the Hoechst Dye 33258 method.

        <LI> All DNAs must be normalized to a concentration of
        approximately 10 ng/&#181;l.  The total amount of DNA required
        is dependent on the number of SNPs to be studied and is
        defined for each project.

        <LI> DNA stock must be diluted in ddH<SUB>2</SUB>0.

        <LI> A brief description of the DNA extraction protocol(s)
        should be included.</UL><BR><BR>

        <B>Shipping instructions</B>

        <UL>
        <LI> Wells A1 through A4 must remain empty for controls.

        <LI> Plates should not be directly stacked on one another.
        The well bottoms may pierce the foil lids.  Place the foam
        packing material pads between plates.

        <LI> The lids must be sealed tightly and completely.  We
        suggest the use of devices such as the MJ Research Roller for
        Microseal Film (catalog number MSR-0001) or the Corning
        Storage Mat Applicator (catalog number 3081).

        <LI> DNA must be solidly frozen prior to shipment and remain
        frozen to avoid the possibility of cross contamination or
        degradation.  Plates must be shipped on sufficient dry ice to
        ensure that the samples remain frozen.

        <LI> DNA should be shipped overnight express.</UL><BR>

	<BR>
	This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions to
	<B>kdeutsch\@systemsbiology.org</B>.
	<BR>
	<BR>

    !;

} # end showMainPage


