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
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;

use SBEAMS::Interactions;
use SBEAMS::Interactions::Settings;
use SBEAMS::Interactions::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Interactions;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

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
# Global Variables
###############################################################################
$PROGRAM_FILE_NAME = 'main.cgi';
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin',
    #  'Proteomics_readonly'],
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
    # Some action
  } else {
    $sbeamsMOD->display_page_header();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->display_page_footer();
  }


} # end main



###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();


  print qq~

	<P> You are successfully logged into the <B>$DBTITLE -
	$SBEAMS_PART</B> system.  This module is designed as a repository
	for curated molecular interactions.  Interactions may be queried,
	updated, and exported to Cytoscape.</P>

	<P>Please choose your tasks from the menu bar on the left.</P>

	<font color=red>TO ENTER A BATCH OF INTERACTIONS:</font>

	<UL>

	<LI> Know the Project under which the interactions should be
	entered.  If there isn't yet one, create it by clicking
	[Projects] [Add Project]

	<LI> Do you already have a suitable Interaction Group for your
	interactions?  If there isn't yet one, create it by clicking
	[Interactions] [Manage Interaction Groups] [Add Interaction
	Group]

	<P>

	<LI> Enter the relevant publications with [Publications] [Add
	Publication]

	<LI> Enter the relevant assays with [Assay] [Add Assay].  If
	the assay is just for an existing publication for which little
	additional details are to be added, just make the Assay Name
	the same as the Publication Name

	<LI> Enter the relevant Bioentities involved in the
	interactions with [Bioentities] [Add Bioentity]

	<LI> Enter the relevant Interactions with [Interactions] [Add
	Interaction]

	</UL>

	<P> This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions
	to <B>edeutsch\@systemsbiology.org</B>.</P>
  ~;


  ##########################################################################
  #### Print out some recent resultsets

  $sbeams->printRecentResultsets();


  ##########################################################################
  #### Print out all projects owned by the user

  $sbeams->printProjectsYouOwn();


  ##########################################################################
  #### Print out all projects user has access to

  $sbeams->printProjectsYouHaveAccessTo();


  return;


} # end handleResquest

