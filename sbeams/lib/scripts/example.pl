#!/usr/local/bin/perl -T

###############################################################################
# Program     : example.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script is an example of using the command-line SBEAMS
#               interface.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;
use Getopt::Long;
use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name);
use lib qw (../perl);


#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$sbeams = new SBEAMS::Connection;


#### Set program name and usage banner
$PROG_NAME = "example.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] parameters
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --database xxxx     Database where the default tables are found

 e.g.:  $PROG_NAME foo

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
  "database:s")) {
  print "$USAGE";
  exit;
}
$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  DBVERSION = $DBVERSION\n";
}


$| = 1;
main();
exit 0;


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue, else execute the important part of this script
###############################################################################
sub main { 

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'Array_user'));

  #### Print the header, do what the program does, and print footer
  $sbeams->printTextHeader();
  showMainPage();
  $sbeams->printTextFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);

  $current_username = $sbeams->getCurrent_username;
  $current_contact_id = $sbeams->getCurrent_contact_id;
  $current_work_group_id = $sbeams->getCurrent_work_group_id;
  $current_work_group_name = $sbeams->getCurrent_work_group_name;
  $current_project_id = $sbeams->getCurrent_project_id;
  $current_project_name = $sbeams->getCurrent_project_name;


  $sbeams->printUserContext(style=>'TEXT');

  print qq!
      You are successfully logged into the $DBTITLE system.  Your
      task would go here and do whatever you like.
  !;

  print "\n\n";
  $sql = "SELECT organization_id,organization FROM $TB_ORGANIZATION";
  my %organizations = $sbeams->selectTwoColumnHash($sql);

  while ( ($key,$value) = each %organizations ) {
    print "$key=$value\n";
  }


} # end showMainPage

