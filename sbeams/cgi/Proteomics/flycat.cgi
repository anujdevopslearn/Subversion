#!/usr/local/bin/perl -T

###############################################################################
# Program     : flycat.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page for FLYCAT queries.
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
	<HR ALIGN=LEFT SIZE="3" WIDTH="30%" NOSHADE>
	<H3>Welcome to FLYCAT, a catalog of annotated peptides in Drosophila.</H3>
	<P>
        <IMG WIDTH="236" HEIGHT="246" SRC="../../images/flycat.gif">
        <P>
	Click on one of the links below to view annotations for genes
	beginning with the character...<P>
    ~;

    my $sql = qq~
	SELECT SUBSTRING(biosequence_name,1,1) AS 'first letter',COUNT(*) AS 'Count'
	  FROM $TBPR_BIOSEQUENCE
	 WHERE biosequence_set_id = 3
	 GROUP BY SUBSTRING(biosequence_name,1,1)
	 ORDER BY 1
    ~;


    my @columns = $sbeams->selectOneColumn($sql);

    my $element;
    foreach $element (@columns) {
      $element = uc($element);
      print "<a href=\"$CGI_BASE_DIR/Proteomics/SummarizePeptides?search_batch_id=10,11,12&display_options=GroupReference,BSDesc&reference_constraint=$element\%25&sort_order=reference&row_limit=1000&annotation_status_id=Annot&apply_action=QUERYHIDE\">&nbsp;$element&nbsp;</a> "
    }

    print qq~
	<BR>
	<BR>
	<H2>OR:</H2>
	<FORM ACTION="$CGI_BASE_DIR/Proteomics/SummarizePeptides" METHOD="post">
	Enter the gene search string (% is a wildcard):<BR>
	Gene Name <INPUT TYPE="text" NAME="gene_name_constraint" VALUE="" SIZE=20><BR>
	Accession <INPUT TYPE="text" NAME="accession_constraint" VALUE="" SIZE=20> (FBgnxxxxxxx)<BR>

	<INPUT TYPE="hidden" NAME="search_batch_id" VALUE="10,11,12">
	<INPUT TYPE="hidden" NAME="display_options" VALUE="GroupReference,BSDesc">
	<INPUT TYPE="hidden" NAME="annotation_status_id" VALUE="Annot">
	<INPUT TYPE="hidden" NAME="sort_order" VALUE="reference">
	<INPUT TYPE="hidden" NAME="row_limit" VALUE="1000">
	<INPUT TYPE="hidden" NAME="apply_action" VALUE="QUERYHIDE">

	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action_fake" VALUE="QUERY">
	</FORM>
    ~;

} # end showMainPage


