#!/usr/local/bin/perl

###############################################################################
# Program      : load_SRM_experiment.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Loads all spectrum files found in an experiment directory into 
# SRM Experiment Atlas (PASSEL) database tables
# Assumes:
#  - publication, sample, and experiment records have already been  created
#  - spectrum files are in mzML or mzXML format
#  - transition groups are unique given Q1, protname, stripped pepseq
#  - transition list is in mProphet format with a header line
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
use vars qw ($q $sbeams $sbeamsMOD $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name);

use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ( $current_username = $sbeams->Authenticate(
    allow_anonymous_access => 1,
  ));


$current_contact_id = $sbeams->getCurrent_contact_id;
# This is returning 1, but prev SEL_run records used 40.
$current_work_group_id = $sbeams->getCurrent_work_group_id;
$current_work_group_id = 40;

my $loader = new SBEAMS::PeptideAtlas::LoadSRMExperiment;

###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME --expt_id NN [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --expt_id                   SEL_experiment_id (required)
  --purge                     Purge before loading; keep run records.
  --noload                    Don't load; useful with --purge.
  --mult_tx_files             One Tx file per spectrum file. Default: single
				Tx file for all runs, named transition_list.tsv
  --mult_tg_per_q1            Multiple transition groups measured per Q1
				(e.g. to detect different phospho sites)
  --q1_tolerance              Tolerance for matching Q1 in transition list
                                to rounded value in spec files; default 0.007
  --q3_tolerance              Tolerance for matching Q3 in transition list to
                                rounded value in spec files; default =q1_tol

  --create_expt_record        Create experiment record. Default: already created.
  --data_path                 Required with create_expt_record.
  --sample_id                 Recommended with create_expt_record.
  --project_id                Recommended with create_expt_record.
  --pass_identifier             e.g. PASS00129; recommended with create_expt_record.
  --title                     Expt title; recommended with create_expt_record.

  --create_run_records        Create run records. Default: already created.
  --mprophet                  mProphet output filename
  --scores_only               Load mQuest/mProphet scores only; everything else
                                already loaded. (peak_group records
                                will be created if not prev. created)

 e.g.:  $PROG_NAME --expt_id 78 --mpro mProphet_peakgroups.tsv
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
         "expt_id:i", "mult_tx_files", "create_run_records", "mprophet:s",
         "purge", "help", "q1_tolerance:f", "create_expt_record", "data_path:s",
	 "q3_tolerance:f","sample_id:i","project_id:i","pass_identifier:s",
	 "title:s", "mult_tg_per_q1", "scores_only", "noload",
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


my $SEL_experiment_id = $OPTIONS{"expt_id"};
my $create_expt_record = $OPTIONS{"create_expt_record"};
if (! $SEL_experiment_id && ! $create_expt_record ) {
   print "$PROG_NAME: --expt_id or --create_expt_record required.\n";
   print $USAGE;
   exit;
}
if ($SEL_experiment_id && $create_expt_record ) {
   print "$PROG_NAME: specify only one of --expt_id or --create_expt_record; with --create_expt_record, experiment ID will be autogenerated.\n";
   exit;
}

my $purge = $OPTIONS{"purge"};
my $noload = $OPTIONS{"noload"};
my $mult_tx_files = $OPTIONS{"mult_tx_files"};
my $mult_tg_per_q1 = $OPTIONS{"mult_tg_per_q1"};
my $q1_tolerance = $OPTIONS{"q1_tolerance"};
my $q3_tolerance = $OPTIONS{"q3_tolerance"};
my $create_run_records = $OPTIONS{"create_run_records"};
my $data_path = $OPTIONS{"data_path"};
my $sample_id = $OPTIONS{"sample_id"};
my $project_id = $OPTIONS{"project_id"};
my $pass_identifier = $OPTIONS{"pass_identifier"};
my $expt_title = $OPTIONS{"title"};
my $load_scores_only = $OPTIONS{"scores_only"};

if ($create_expt_record && !$data_path) {
  print "$PROG_NAME: must specify --data_path with --create_expt_record.\n";
  exit;
}

my $mpro_file = $OPTIONS{"mprophet"};
if ($mpro_file && $mult_tg_per_q1) {
  print STDERR "mProphet results will not be loaded properly for multiple ".
               "transition groups per Q1. Some code changes need to happen. ".
               "Under read_mprophet_peakgroup_file, in LoadSRMExperiment.pm, ".
               "mpro scores are currently hashed to the stripped pepseq. ".
               "Needs to instead hash to, probably, transition_group_pepseq, ".
               "as is currently done for read_mquest_peakgroup_file(). ".
               "Before implementing this change, check that this column actually ".
               "exists in your mProphet file, and that it holds a modseq. ".
	       "Comment says 'Ruth 2011', suggesting ".
               "that it's a special column seen only in Ruth's data. ".
               "If you don't make this change, scores for all peps with the ".
	       "same Q1 will be stored under the stripped pepseq, overwriting ".
	       "one another.".
               "\n";
  exit;
}

###############################################################################
###
### Main section: Load all runs for an SRM experiment.
###
###############################################################################


print "Loading data for PASSEL experiment $SEL_experiment_id\n" if ($VERBOSE);
print "Allowing multiple transition groups per Q1\n" if ($VERBOSE && $mult_tg_per_q1);
print "Loading mQuest/mProphet scores only\n" if ($load_scores_only && $VERBOSE);

# Get info about this experiment from the database
my ($expt_id, $mprophet_analysis, $heavy_label);
my $sql = qq~
  SELECT SEL_experiment_id, data_path, q1_tolerance, q3_tolerance,
     mprophet_analysis, heavy_label
  FROM $TBAT_SEL_EXPERIMENT
  WHERE SEL_experiment_id = '$SEL_experiment_id'
  AND record_status != 'D'
  ;
~;
my @rows = $sbeams->selectSeveralColumns($sql);
if (scalar @rows) {
  my ($stored_path, $stored_q1_tol, $stored_q3_tol);
  ($expt_id, $stored_path, $stored_q1_tol, $stored_q3_tol,
    $mprophet_analysis, $heavy_label) = @{$rows[0]};
  $data_path = $stored_path if !$data_path; #retain any infos specified in params
  $q1_tolerance = $stored_q3_tol if !$q1_tolerance;
  $q3_tolerance = $stored_q3_tol if !$q3_tolerance;
}


# If expt doesn't exist, and if user OKs, create it
if ( ! $expt_id  ) {
  if ( $create_expt_record) {
    if (! -d $data_path ) {
      die "$PROG_NAME: data_path $data_path does not exist."
    }
    print "Creating SEL_experiment record for data path $data_path.\n" unless $QUIET; 
    print "Be sure to manually add sample_id, project_id, and experiment_title!\n" unless $QUIET; 
    my $rowdata_ref;
    $rowdata_ref->{'data_path'} = $data_path;
    $rowdata_ref->{'sample_id'} = $sample_id || '';
    $rowdata_ref->{'project_id'} = $project_id || '';
    $rowdata_ref->{'datasetIdentifier'} = $pass_identifier || '';
    $rowdata_ref->{'experiment_title'} = $expt_title || '';
    $rowdata_ref->{'q1_tolerance'} = $q1_tolerance;
    $rowdata_ref->{'q3_tolerance'} = $q3_tolerance;
    $rowdata_ref->{'created_by_id'} = $current_contact_id;
    $rowdata_ref->{'modified_by_id'} = $current_contact_id;
    $rowdata_ref->{'owner_group_id'} =  $current_work_group_id;
    $rowdata_ref->{'record_status'} = 'N';
    $SEL_experiment_id = $sbeams->updateOrInsertRow (
      table_name => $TBAT_SEL_EXPERIMENT,
      rowdata_ref => $rowdata_ref,
      return_PK => 1,
      print_SQL => 0,
      verbose => $VERBOSE,
      testonly => $TESTONLY,
      return_error => '',
      insert => 1,
    );
    print "Created experiment #${SEL_experiment_id}.\n\n" unless $QUIET;
  } else {
    die "$PROG_NAME : Experiment  $SEL_experiment_id does not exist; use --create_expt_record to autocreate a new record.";
  }
}

if ($purge) {
  print "Purging ...\n"
      if ($VERBOSE);
  $loader->removeSRMExperiment(
    SEL_experiment_id => ${SEL_experiment_id},
    keep_experiments_and_runs => 1,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
}

exit if ($noload);

#my $specfiles = `ls ${data_path}/*.{mzXML,mzML}`;
#print "$specfiles\n";
#exit;
my $specfiles = `ls ${data_path}/*.{mzXML,mzML} 2> /dev/null`;
my @specfiles = split(' ', $specfiles);
if (! scalar @specfiles) {
  print "No .mzXML or .mzML files found in $data_path (listing was \'$specfiles\')\n";
  exit;
}

# get filenames for all mzML, mzXML files in that directory
# for each file ...
for my $spectrum_filepath (@specfiles) {
  print "specfile=$spectrum_filepath\n" if ($VERBOSE);
  my ($spectrum_basename, $ext) =  ($spectrum_filepath =~ /$data_path\/(\S+)(\.mzX?ML)/ );
  my $spectrum_filename = $spectrum_basename.$ext;

  #  check for run record using SQL
  my $sql = qq~
    SELECT SELR.SEL_run_id 
    FROM $TBAT_SEL_RUN SELR
    WHERE SELR.SEL_experiment_id = '$SEL_experiment_id'
    AND SELR.spectrum_filename = '$spectrum_filename'
    AND SELR.record_status != 'D';
  ~;
  my ($SEL_run_id) = $sbeams->selectOneColumn($sql);

  # If it doesn't exist, and if user OKs, create it

  if (! $SEL_run_id  ) {
    if ( $create_run_records) {
    print "Creating SEL_run record for $spectrum_filename... \n" if $VERBOSE; 
      my $rowdata_ref;
      $rowdata_ref->{'SEL_experiment_id'} = $SEL_experiment_id;
      $rowdata_ref->{'spectrum_filename'} = $spectrum_filename;
      $rowdata_ref->{'created_by_id'} = $current_contact_id;
      $rowdata_ref->{'modified_by_id'} = $current_contact_id;
      $rowdata_ref->{'owner_group_id'} =  $current_work_group_id;
      $rowdata_ref->{'record_status'} = 'N';
      $SEL_run_id = $sbeams->updateOrInsertRow (
				table_name => $TBAT_SEL_RUN,
				rowdata_ref => $rowdata_ref,
				return_PK => 1,
				print_SQL => 0,
				verbose => $VERBOSE,
				testonly => $TESTONLY,
				return_error => '',
				insert => 1,
      );
      print " SEL_run_id = $SEL_run_id.\n" if $VERBOSE; 
    } else {
      print "No SEL_run_id for $spectrum_filename; use --create_run_records to create.\n";
      next;
    }
  }

  print "Q1 tol $q1_tolerance Q3 tol $q3_tolerance\n" if $VERBOSE>1;

  # construct expected mquest file & check for existence & readability

  #my $mquest_file = $spectrum_basename . "_scores.xls";
  my $mquest_file = $spectrum_filepath;
  $mquest_file =~ s/$ext/_scores.xls/;
  if (! -r $mquest_file) {
    print "mQuest file \"$mquest_file\" does not exist or is not readable.\n"
      if $VERBOSE;
    $mquest_file = '';
  } else {
    print "Was able to open mQuest file \"$mquest_file\". Woot!\n" if $VERBOSE; 
  }

  # make an option for load_SRM_run to create the run record?
  $loader-> load_srm_run (
    spectrum_file => $spectrum_filepath,
    data_path => $data_path,
    SEL_run_id => $SEL_run_id,
    mquest_file => $mquest_file,
    mpro_file => $mpro_file,
    transition_file => "$data_path/transition_list.tsv",
    q1_tolerance => $q1_tolerance,
    q3_tolerance => $q3_tolerance,
    mult_tg_per_q1 => $mult_tg_per_q1,
    load_scores_only => $load_scores_only,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );
}

$loader->map_peps_to_prots (
    SEL_experiment_id => $SEL_experiment_id,
    transition_file => "$data_path/transition_list.tsv",
    glyco => $OPTIONS{'glyco'},
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
);

### End main program
