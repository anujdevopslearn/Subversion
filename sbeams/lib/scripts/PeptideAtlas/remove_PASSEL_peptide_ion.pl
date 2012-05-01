#!/usr/local/bin/perl

###############################################################################
# Program      : remove_PASSEL_peptide_ion.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  : Remove a SEL_peptide_ion record
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
$|++;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Authenticator;

use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::LoadSRMExperiment;


use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);

$sbeams = new SBEAMS::Connection;
my $loader = new SBEAMS::PeptideAtlas::LoadSRMExperiment;

###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added
  --help                      Print this message

  --pep modified_pepseq       Remove ion with this seq (required)
  --charge charge             Remove ion with this charge (required)
  --run SEL_run_id            Remove ion belonging to this PASSEL run (required)
 
 e.g.:  $PROG_NAME --pep 'AAIHFDC[160]DLQWER' --charge 2 --run 378

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:i","quiet","debug:i","testonly",
        "pep:s", "charge:i", "run:i",  "help",
    )) {

    die "\n$USAGE";
}

if ($OPTIONS{"help"}) {
  print "\n$USAGE";
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

my $SEL_run_id = $OPTIONS{"run"};
my $pepseq = $OPTIONS{"pep"};
my $charge = $OPTIONS{"charge"};
if ((! $SEL_run_id) || (! $pepseq) || (! $charge)) {
  print "$USAGE\nMust specify all three --pep, --charge, --run\n";
  exit();
}


###############################################################################
###
### Main section: remove peptide ion record
###
###############################################################################

$loader->removePeptideIon(
    SEL_run_id => $SEL_run_id,
    modified_peptide_sequence => $pepseq,
    charge => $charge,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
);

### End main program
