#!/usr/local/bin/perl

###############################################################################
# Program      : load_SRM_run.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Read a transition file and optional mProphet file and load entries into
# SRM Experiment Atlas transition & chromatogram tables.
# Assumes:
#  - samples, runs, experiments have already been manually loaded
#  - transition groups are unique given Q1, protname, stripped pepseq
#  - transition list has a header line
#  - mProphet peakgroups file is in .tsv format with specific column headers
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
$|++;

use lib "$FindBin::Bin/../../perl";
use SBEAMS::PeptideAtlas::LoadSRMExperiment;

use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);

my $loader = new SBEAMS::PeptideAtlas::LoadSRMExperiment;

###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Load a single SRM run into PASSEL. Assumes that sample, experiment, and
 run records already exist; will not create run records.
Usage: $PROG_NAME --trans trans_file [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --transitions               Transition file in mProphet format (required)
  --tr_format                 Transition file format (tsv/csv, default tsv)
  --ATAQS                     Transition file lacks header and is in ATAQS format
                                Implies --tr_format csv.
  --spectra                   Spectrum file in .mzXML or .mzML format
                               If not provided, assume same basename as transition file.
  --purge                     Purge before loading
  --mult_tg_per_q1            Multiple transition groups measured per Q1
				(e.g. to detect different phospho sites)
  --q1_tolerance              For matching Q1 in Tx file vs. spectrum file.
                                Default 0.005
  --q3_tolerance              Default: same as q1_tolerance
  --mquest                    mQuest output file (not needed if mProphet?)
  --mprophet                  mProphet output file
  --scores_only               Load mQuest/mProphet scores only; everything else
                                already loaded.
  --noload_pi                 Don't load peptide ion records
  --noload_tg                 Don't load transition group records
  --noload_tr                 Don't load transition records
  --noload_ch                 Don't load chromatogram records

 e.g.:  $PROG_NAME --tr TRID01_decoy_01.tsv --mpro mProphet_peakgroups.tsv
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly","help",
        "transitions:s", "spectra:s", "mprophet:s", "tr_format:s",
        "noload_pi", "noload_tg", "noload_tr", "noload_ch", "scores_only",
        "ruth_prelim", "ruth_2011",  "ATAQS", "mquest:s",
        "q1_tolerance:f", "q3_tolerance:f", "mult_tg_per_q1", "purge",
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

my $purge = $OPTIONS{"purge"};
my $load_peptide_ions = ! $OPTIONS{"noload_pi"};
my $load_transition_groups = ! $OPTIONS{"noload_tg"};
my $load_chromatograms = ! $OPTIONS{"noload_ch"};
my $load_transitions = ! $OPTIONS{"noload_tr"};
my $load_scores_only =  $OPTIONS{"scores_only"};
my $special_expt = '';
$special_expt = 'ruth_prelim' if  $OPTIONS{"ruth_prelim"};
$special_expt = 'ruth_2011' if  $OPTIONS{"ruth_2011"};

my $mpro_file = $OPTIONS{"mprophet"};
my $mquest_file = $OPTIONS{"mquest"};
my $mult_tg_per_q1 = $OPTIONS{"mult_tg_per_q1"};
my $q1_tolerance = $OPTIONS{"q1_tolerance"};
my $q3_tolerance = $OPTIONS{"q3_tolerance"} || $q1_tolerance;

my $ataqs = $OPTIONS{"ATAQS"};

my $tr_format = $OPTIONS{"tr_format"};
$tr_format = "csv" if $ataqs;
$tr_format = "tsv" unless $tr_format;
if ($tr_format !~ /^[tc]sv$/) {
  die "$USAGE\ntr_format can only be csv or tsv.";
}

# Get spectrum filename if not given on command line.
my $transition_file = $OPTIONS{"transitions"};
if (! $transition_file) {
  print "$PROG_NAME: transition file required.\n";
  print $USAGE;
  exit;
}

my $spectrum_file = $OPTIONS{"spectra"};
  

###############################################################################
###
### Main section: Load an SRM run.
###
###############################################################################

$loader-> load_srm_run (
  spectrum_file => $spectrum_file,
  mquest_file => $mquest_file,
  mpro_file => $mpro_file,
  transition_file => $transition_file,
  tr_format => $tr_format,
  ataqs => $ataqs,
  special_expt => $special_expt,
  q1_tolerance => $q1_tolerance,
  q3_tolerance => $q3_tolerance,
  mult_tg_per_q1 => $mult_tg_per_q1,
  load_peptide_ions => $load_peptide_ions,
  load_transition_groups => $load_transition_groups,
  load_transitions => $load_transitions,
  load_chromatograms => $load_chromatograms,
  load_scores_only => $load_scores_only,
  purge => $purge,
  verbose => $VERBOSE,
  quiet => $QUIET,
  testonly => $TESTONLY,
  debug => $DEBUG,
);
### End main program
