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
use lib qw (../../lib/perl);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;

use SBEAMS::Biomarker;
use SBEAMS::Biomarker::Settings;

# Program globals
my $sbeams = new SBEAMS::Connection;
my $biomarker = new SBEAMS::Biomarker;
$biomarker->setSBEAMS($sbeams);


{ # Main 

  # Authenticate and exit if a username is not returned
  my $user = $sbeams->Authenticate() || die "Unable to authenticate";

  my %param;
  $sbeams->parse_input_parameters( q => $q, parameters_ref => \%param );
  $sbeams->processStandardParameters( parameters_ref => \%param );

#  test_session_cookie();

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
    my $edit = qq~
    <A HREF=$CGI_BASE_DIR/ManageProjectPrivileges>[Edit permissions]</A>
    ~;

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
	<BR>
	<BR>
  !;

} # end showMainPage

sub test_session_cookie { 

  my $ltime = 'string' x 10000;
  my $time = time();
  $sbeams->getSessionCookie();
  $sbeams->setSessionAttribute( key => $time,  value => $ltime ); 
  $sbeams->setSessionAttribute( key => 'time',  value => $ltime ); 
  $log->debug( "Time is $ltime" );
  $log->debug( "Time is $ltime" );

  # Print the header, do what the program does, and print footer

}
