#!/usr/local/bin/perl

###############################################################################
# Program      : cache_PASSEL_experiment_info.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Grabs info about loaded PASSEL experiments and caches in a JSON file for later
# use by GetSELExperiments cgi.
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

use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::PASSEL;

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
  --filtertest                Test only the filtering function. For development only.

  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
      "filtertest",
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
### Main section: Load all runs for an SRM experiment.
###
###############################################################################



my $passel = new SBEAMS::PeptideAtlas::PASSEL;

if ($OPTIONS{'filtertest'}) {
  print "Filtering data for PASSEL experiments based on project_id\n" if ($VERBOSE);
  $passel->srm_experiments_2_json (
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
} else {
  print "Caching data for all PASSEL experiments ...\n" if ($VERBOSE);
  $passel->srm_experiments_2_json_all (
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
}

### End main program
