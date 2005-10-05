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
use vars qw ($q $PROGRAM_FILE_NAME $current_contact_id $current_username);
use lib qw (../../lib/perl);
#use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;

use SBEAMS::Biomarker;
use SBEAMS::Biomarker::Settings;

my $sbeams = new SBEAMS::Connection;
my $biomarker = new SBEAMS::Biomarker;
$biomarker->setSBEAMS($sbeams);


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
    $biomarker->printPageHeader();
    showMainPage();
    $biomarker->printPageFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

  $sbeams->printUserContext();
  my $tab = $sbeams->getMainPageTabMenuObj( cgi => $q );
#  $tab->addHRule();

  if ( $tab->getActiveTab == 1 ) { 
    my $project = $sbeams->getCurrent_project_name();
    $tab->setBoxContent( 0 );
    my $edit =<<"    END";
    <A HREF=$CGI_BASE_DIR/ManageProjectPrivileges>[Edit permissions]</A>
    END

    # Pull out content
    my $content = "<H1>$project $edit</H1>";

    my $expTable = $biomarker->get_experiment_overview();

    $tab->addContent( "$content $expTable" );


   }

  print qq!
	<BR>
  $tab
	<BR>
	<BR>

	<UL>
	</UL>

	<BR>
	<BR>
    !;

} # end showMainPage


