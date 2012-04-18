#!/usr/local/bin/perl

###############################################################################
# Program      : cache_build_info.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Grabs stats and links about PeptideAtlas builds and caches in a .TSV file
# for later use by buildInfo cgi.
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
$|++;

use lib "$FindBin::Bin/../../perl";

use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);
use vars qw ($q $sbeams $sbeamsMOD $current_username);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::DataTable;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::BuildInfo;

## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ( $current_username = $sbeams->Authenticate(
    allow_anonymous_access => 1,
  ));


###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
    )) {

    die "\n$USAGE";
}

if ($OPTIONS{"help"}) {
  print $USAGE;
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
###
### Main section
###
###############################################################################



my $info = new SBEAMS::PeptideAtlas::BuildInfo;

print "Caching stats and links for all PeptideAtlas builds...\n" if ($VERBOSE);
$info-> pa_build_info_2_tsv (
  verbose => $VERBOSE,
  quiet => $QUIET,
  testonly => $TESTONLY,
  debug => $DEBUG,
);

### End main program
