#!/usr/local/bin/perl -w

###############################################################################
# Program     : PubMedTest.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script is a test of the PubMedFetcher module
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
use FindBin;
use Data::Dumper;

use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection::PubMedFetcher;

use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username
            );


#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$sbeams = new SBEAMS::Connection;


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] parameters
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          Set to not actually write to database
  --source_file xxxx  Output file to which data information are dumped

 e.g.:  $PROG_NAME

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
       )) {
  print "$USAGE";
  exit;
}
$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit 0;



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'Admin'
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);


} # end main


###############################################################################
# handleRequest
###############################################################################
sub handleRequest {
  my %args = @_;


  #### Print out the user context header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
  my $PubMedID = 8798556;

  my $pubmed_info = $PubMedFetcher->getArticleInfo(
    PubMedID => $PubMedID,
    verbose => 2,
  );

  if ($pubmed_info) {
    while (my ($key,$value) = each %{$pubmed_info}) {
      print "$key=$value=<BR>\n";
    }
  }


  return;

} # end handleRequest


