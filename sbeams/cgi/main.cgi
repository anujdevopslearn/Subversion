#!/usr/local/bin/perl -T

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
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
  $sbeams->printPageHeader();
  showMainPage();
  $sbeams->printPageFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

  #### Print out the current user information
  $sbeams->printUserContext();

  #### Write some welcoming text
  print qq~
	<BR>
	You have successfully logged into the $DBTITLE interface.<BR>
	Note your current user group above, and click [CHANGE] to change it.<P> 

	Please choose a section/subsection/task from the menu bar on the
	left to continue.<P>

	This system is still under active development.  Please
	report bugs, problems, difficulties, and suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>

	<UL>
  ~;


  #### Get the list of Modules available to us
  my @modules = $sbeams->getModules();

  #### Print out entries for each module
  my $module;
  foreach $module (@modules) {
    print qq~
	<LI><A HREF="$module/main.cgi">SBEAMS - $module</A>
	<BR><BR>
    ~;
  }


  #### Finish the list
  print qq~
	</UL>

	<BR>
	<BR>
    ~;

} # end showMainPage


