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
#  - spectrum file is in mzXML format (not mzML)
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
Usage: $PROG_NAME --trans trans_file [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --transitions               Transition file in (required)
  --ATAQS                     Transition file lacks header but is in ATAQS format
                                Implies --tr_format csv.
  --tr_format                 Transition file format (tsv/csv, default tsv)
  --spectra                   Spectrum file in .mzXML format (.mzML to be implemented)
                               If not provided, assume same basename as transition file.
  --mquest                    mQuest output file (not needed if mProphet?)
  --mprophet                  mProphet output file
  --noload_pi                 Don't load peptide ion records
  --noload_tg                 Don't load transition group records
  --noload_tr                 Don't load transition records
  --noload_ch                 Don't load chromatogram records
 
  --ruth_prelim               Special handling for Ruth's preliminary data
  --ruth_2011                 Special handling for Ruth's 2011 data

 e.g.:  $PROG_NAME --tr TRID01_decoy_01.tsv --mpro mProphet_peakgroups.tsv
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "transitions:s", "spectra:s", "mprophet:s", "tr_format:s",
        "noload_pi", "noload_tg", "noload_tr", "noload_ch",
        "ruth_prelim", "ruth_2011",  "ATAQS", "mquest:s",
    )) {

    die "\n$USAGE";
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

my $load_peptide_ions = ! $OPTIONS{"noload_pi"};
my $load_transition_groups = ! $OPTIONS{"noload_tg"};
my $load_chromatograms = ! $OPTIONS{"noload_ch"};
my $load_transitions = ! $OPTIONS{"noload_tr"};
my $special_expt = '';
$special_expt = 'ruth_prelim' if  $OPTIONS{"ruth_prelim"};
$special_expt = 'ruth_2011' if  $OPTIONS{"ruth_2011"};

my $mpro_file = $OPTIONS{"mprophet"};
my $mquest_file = $OPTIONS{"mquest"};

my $ataqs = $OPTIONS{"ATAQS"};

my $tr_format = $OPTIONS{"tr_format"};
$tr_format = "csv" if $ataqs;
$tr_format = "tsv" unless $tr_format;
if ($tr_format !~ /^[tc]sv$/) {
  die "$USAGE\ntr_format can only be csv or tsv.";
}

# Get spectrum filename if not given on command line.
my $transition_file = $OPTIONS{"transitions"};
my $data_dir = `dirname $transition_file`;
chomp $data_dir;
$_ = `basename $transition_file`;
my ($tran_file_basename) = /^(\S+)\.\S+$/;  #strip extension

my $spectrum_file = $OPTIONS{"spectra"};
my $distinct_spectrum_filename = 0;
if ($spectrum_file) {
  $distinct_spectrum_filename = 1;
}
my $spec_file_basename;
my $spectrum_filepath;
if ($spectrum_file) {
  $_ = `basename $spectrum_file`;
  ($spec_file_basename) = /^(\S+)\.\S+$/;  #strip extension
  $spectrum_filepath = $spectrum_file;
} else {
  $spec_file_basename = $tran_file_basename;
  $spectrum_filepath = "$data_dir/$spec_file_basename.mzXML";
}
  

###############################################################################
###
### Main section: Load an SRM run.
###
###############################################################################


### Get experiment and run IDS
my ($SEL_run_id, $SEL_experiment_id);
$SEL_run_id = $loader->get_SEL_run_id(
  spec_file_basename => $spec_file_basename,
);
$SEL_experiment_id = $loader->get_SEL_experiment_id(
  SEL_run_id => $SEL_run_id,
);

### Read through spectrum file and collect all the Q1s measured.
my $q1_measured_aref =
  $loader->collect_q1s_from_spectrum_file (
    spectrum_filepath => $spectrum_filepath,
);
#--------------------------------------------------
# my @q1s = @{$q1_measured_aref};
# for my $q1 (@q1s) { print "$q1\n"; }
# exit;
#-------------------------------------------------- 

### Read mQuest peakgroup file; store scores in mpro hash
my $mpro_href = {};
if ($mquest_file) {
  $loader->read_mquest_peakgroup_file (
    mquest_file => $mquest_file,
    spec_file_basename => $spec_file_basename,
    mpro_href => $mpro_href,
    special_expt => $special_expt,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
}

### Read mProphet peakgroup file; store scores in mpro hash
if ($mpro_file) {
  $loader->read_mprophet_peakgroup_file (
    mpro_file => $mpro_file,
    spec_file_basename => $spec_file_basename,
    mpro_href => $mpro_href,
    special_expt => $special_expt,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
}

### Read transition file; store info in transdata hash.
my $transdata_href = $loader->read_transition_list(
  transition_file => $transition_file,
  tr_format => $tr_format,
  ataqs => $ataqs,
  special_expt => $special_expt,
  verbose => $VERBOSE,
  quiet => $QUIET,
  testonly => $TESTONLY,
  debug => $DEBUG,
);

### Transfer mquest/mprophet scores into transdata hash
if ($mpro_href) {
  $loader->store_mprophet_scores_in_transition_hash (
    spec_file_basename => $spec_file_basename,
    transdata_href => $transdata_href,
    mpro_href => $mpro_href,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
} else {
  print "No mProphet or mQuest file given.\n" if ($VERBOSE);
}

### Load transition data into database
$loader->load_transition_data (
  SEL_run_id => $SEL_run_id,
  transdata_href => $transdata_href,
  q1_measured_aref => $q1_measured_aref,
  spec_file_basename => $spec_file_basename,
  load_peptide_ions => $load_peptide_ions,
  load_transition_groups => $load_transition_groups,
  load_transitions => $load_transitions,
  load_chromatograms => $load_chromatograms,
  verbose => $VERBOSE,
  quiet => $QUIET,
  testonly => $TESTONLY,
  debug => $DEBUG,
);

### End main program
