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
use File::Basename;

use lib "$FindBin::Bin/../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;


$sbeams = new SBEAMS::Connection;

# use CGI;
#$q = new CGI;


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
# Set Global Variables and execute main()
###############################################################################
$PROGRAM_FILE_NAME = basename( $0 );
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    #permitted_work_groups_ref=>['xxx','yyy'],
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
  if (defined($parameters{action}) && $parameters{action} eq "???") {
    # Some action
  } else {
    $sbeams->display_page_header();
    handle_request(ref_parameters=>\%parameters);
    $sbeams->display_page_footer();
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


  #### Print out the current user information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();


  #### Write some welcoming text
  print qq~

	<P>Welcome to the Systems Biology Experiment Analysis
	Management System (SBEAMS) interface.  Please check your
	current work group and current project listed above and change
	it via the pull down menus if desired, or use the list of
	projects below.</P>

	<P>The modules available to you are listed on the
	navigation bar on the left.  Enter the interface for one of
	the available modules by clicking on it.</P>

	<P>This system is still under active development.  Please
	report bugs, problems, difficulties, and suggestions to
	<B>edeutsch\@systemsbiology.org</B>.</P>
  ~;


  my $comment =<<'  END';
  #### Show the list of Modules available to this user
  print qq~
	<H1>Available SBEAMS Modules:</H1>
	<UL>
  ~;


  #### Get the list of Modules available to us
  my @modules = $sbeams->getModules();

  #### Print out entries for each module
  my $module;
  foreach $module (@modules) {
    print qq~
	<LI><A HREF="$module/main.cgi">SBEAMS - $module</A>
    ~;
  }
	</UL>

  END

  print qq~

	<P>To integrate resultsets from queries in multiple modules
	(e.g., Interactions, Microarray, and Proteomics) and visualize
	with Cytoscape, try out the new, experimental <B><A
	HREF="$CGI_BASE_DIR/IntegrateResultsets">IntegrateResultsets</A></B>
	interface.

	<BR>
	<BR>
    ~;

  # Create new tabmenu item.  This may be a $sbeams object method in the future.
  my $tabmenu = SBEAMS::Connection::TabMenu->new( cgi => $q );

  # Preferred way to add tabs.  label is required, helptext optional
  $tabmenu->addTab( label => 'Current Project', helptext => 'View details of current Project' );
  $tabmenu->addTab( label => 'My Projects', helptext => 'View all projects owned by me' );
  $tabmenu->addTab( label => 'Recent Resultsets', helptext => 'View recent SBEAMS resultsets' );
  $tabmenu->addTab( label => 'Accessible Projects', helptext => 'View projects I have access to' );

  # This really shouldn't need to be done!
  $SBEAMS_SUBDIR = '';

  ##########################################################################
  #### Print out some recent resultsets

  # Scalar to hold content.  In this case we add content to tabmenu, not required
  my $content;

  # conditional block to exec code based on selected tab.  Can define based
  # on tag label...
  if ( $tabmenu->getActiveTabName() eq 'Recent Resultsets' ){

    $content = $sbeams->getRecentResultsets() ;

  } elsif ( $tabmenu->getActiveTabName() eq 'Current Project' ){

  ##########################################################################
  #### Print out project detail stuff, if current or default project exists

  my $project_id = $sbeams->getCurrent_project_id();
  # $project_id ||= $sbeams->getDefault_project_id();
  if ( $project_id ) {
    $content = $sbeams->getProjectDetailsTable( project_id => $project_id ); 
  }

  # or exec code based on tab index.  Tabs are indexed in the order they are 
  # added, starting at 1.  
  } elsif ( $tabmenu->getActiveTab() == 2 ){

  ##########################################################################
  #### Print out all projects owned by the user

    $content = $sbeams->getProjectsYouOwn();

  } elsif ( $tabmenu->getActiveTab() == 4 ){

  ##########################################################################
  #### Print out all projects user has access to

  $content = $sbeams->getProjectsYouHaveAccessTo();
#  $content = $sbeams->getAccessibleProjectInfo( mod_data => 'all' );

  }

  # Add content to tabmenu (if desired). 
  $tabmenu->addContent( $content );

  # The stringify method is overloaded to call the $tabmenu->asHTML method.  
  # This simplifies printing the object in a print block. 
  print "$tabmenu";

  # This is completely equivalent:
  # print $tabmenu->asHTML(); 
   

} # end handle_request


