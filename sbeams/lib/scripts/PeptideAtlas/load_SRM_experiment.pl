#!/usr/local/bin/perl

###############################################################################
# Program      : load_SRM_experiment.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Read a transition file and optional mProphet file and load entries into
# SRM Experiment Atlas transition & chromatogram tables.
# Assumes:
#  - samples, runs, experiments have already been manually loaded
#  - transition groups are unique given Q1, protname, stripped pepseq
#  - transition list is in .tsv format with specific column headers
#  - mProphet peakgroups file is in .tsv format with specific column headers
#  - spectrum file is in mzXML format (not mzML)
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../../perl/SBEAMS/PeptideAtlas";
$|++;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);

#### Set up SBEAMS modules
use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

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

  --transitions               Transition file in .tsv format (required)
  --spectra                   Spectrum file in .mzXML format (.mzML to be implemented)
                               If not provided, assume same basename as transition file.
  --mprophet                  mProphet output file
  --noload_tg                 Don't load transition group records
  --noload_tr                 Don't load transition records
  --noload_ch                 Don't load chromatogram records
  --purge_experiment N        Purge transition group, transition, and chromatogram
                               records for experiment N.
 
  --ruth_prelim               Special handling for Ruth's preliminary data
  --ruth_2011                 Special handling for Ruth's 2011 data

 e.g.:  $PROG_NAME --tr TRID01_decoy_01.tsv --mpro mProphet_peakgroups.tsv
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "transitions:s", "spectra:s", "mprophet:s",
        "noload_tg", "noload_tr", "noload_ch",
        "ruth_prelim", "ruth_2011", "purge_experiment:i",
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

my $load_transition_groups = ! $OPTIONS{"noload_tg"};
my $load_chromatograms = ! $OPTIONS{"noload_ch"};
my $load_transitions = ! $OPTIONS{"noload_tr"};
my $ruth_prelim = $OPTIONS{"ruth_prelim"};
my $ruth_2011 = $OPTIONS{"ruth_2011"};

my $purge_experiment = $OPTIONS{"purge_experiment"};
my $transition_file = $OPTIONS{"transitions"};
if ((! $purge_experiment) && (! $transition_file)) {
  die "$USAGE\nMust specify either --transitions or --purge_experiment.";
} elsif ($purge_experiment && $transition_file) {
  die "$USAGE\nCannot specify both --purge and --transitions.";
}

if ($purge_experiment) {
  print "Purging experiment $purge_experiment.\n" if $VERBOSE;
  removeSRMExperiment(
         SEL_experiment_id => $purge_experiment,
         keep_experiments_and_runs => 1,
      );
  exit();
}

open (TRAN_FILE, $transition_file) || die "Can't open $transition_file for reading.";
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
  

my $mprophet = 0;
my $mpro_file = $OPTIONS{"mprophet"};
if ($mpro_file) {
  open (MPRO_FILE, $mpro_file) || die "Can't open $mpro_file for reading.";
  $mprophet = 1;
}

### Read through spectrum file and collect all the Q1s measured.
open (MZXML, $spectrum_filepath) || die "Can't open $spectrum_filepath";
my %q1_measured;
while (my $line = <MZXML>) {
  if ($line =~ /<precursorMz.*>(\S+)<.precursorMz>/) {
    $q1_measured{$1} = 1;
  }
}
my @q1_measured = sort keys %q1_measured;
print "Measured Q1 (found in spectrum file):\n" if $VERBOSE > 2;
for my $q1 (@q1_measured) {
  print "  $q1\n" if $VERBOSE > 2;
}

### If mProphet peakgroup output file was provided, read and store its info.
### Read header and store indices for key elements.

my ($decoy, $log10_max_apex_intensity, $protein,  $stripped_pepseq, $modified_pepseq, $charge, $peak_group,  $m_score, $Tr);
my $mpro_href;
if ($mprophet) {
  my $line = <MPRO_FILE>;
  my @fields = split('\t', $line);
  my $i = 0;
  my ($log10_max_apex_intensity_idx, $protein_idx,  $peak_group_id_idx, $file_name_idx,
  $transition_group_pepseq_idx, $m_score_idx, $Tr_idx);
  for my $field (@fields) {
    if ($field =~ /^log10_max_apex_intensity$/i) {
      $log10_max_apex_intensity_idx = $i;
    } elsif ($field =~ /^protein$/i) {
      $protein_idx = $i;
    } elsif ($field =~ /^peak.*group_id$/i) {
      $peak_group_id_idx = $i;
    } elsif ($field =~ /^m_score$/i) {
      $m_score_idx = $i;
    } elsif ($field =~ /^file_name$/i) {   # Ruth 2011 data only
      $file_name_idx = $i;
    } elsif ($field =~ /^transition_group_pepseq$/i) {   # Ruth 2011 data only
      $transition_group_pepseq_idx = $i;
    } elsif ($field =~ /^Tr$/i) {   # Ruth 2011 data only?
      $Tr_idx = $i;
    }
    $i++;
  }

  ### Read and store each line of mProphet file
  ### NOTE!
  ### The mProphet file for Ruth_prelim contains one line per peakgroup.
  ### The one for Ruth's 2011 data contains only one line per pep, for the top
  ### peakgroup! This code seems to stumble along for both.
  print "Processing mProphet file!\n" if ($VERBOSE);
  while ($line = <MPRO_FILE>) {
    chomp $line;
    @fields = split('\t', $line);
    $log10_max_apex_intensity = $fields[$log10_max_apex_intensity_idx];
    $protein = $fields[$protein_idx];
    $Tr = $fields[$Tr_idx];  #retention time for best peak group
    $_ = $fields[$peak_group_id_idx]; #this field has 5 bits of info!
    if ($ruth_prelim) {
      ($spectrum_file, $modified_pepseq, $charge, $decoy, $peak_group) = /(\S+) (\S+?)\.(\S+) (\d) (\d+)/;
    } elsif ($ruth_2011) {
      my $dummy;
      ($stripped_pepseq, $charge, $decoy, $dummy, $peak_group) = /pg_(\S+?)\.(\d)_(\d)_target_(dummy)?(\d)/;
      $modified_pepseq = $fields[$transition_group_pepseq_idx];
      $spectrum_file = $fields[$file_name_idx] . ".mzXML";
    }
    if ($charge =~ /decoy/) {
      $charge =~ /(\S+)\.decoy/;
      $charge = $1;
    };

    $spectrum_file =~ /(\S+)\.\S+/;
    my $this_file_basename = $1;

    print "$this_file_basename, $modified_pepseq, $charge, $decoy, $peak_group\n" if ($VERBOSE)>1;
    $m_score = $fields[$m_score_idx];

    if ($this_file_basename && $modified_pepseq && $charge && !$decoy && (defined $peak_group)) {
      $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{log10_max_apex_intensity} = $log10_max_apex_intensity;
      $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{protein} = $protein; #probably unnecessary
      $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{m_score} = $m_score;
      $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{Tr} = $Tr;
      print 'Storing $mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$peak_group,'}->{m_score} = ', $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{m_score}, "\n" if ($VERBOSE > 1);
      print 'Storing $mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$peak_group,'}->{Tr} = ', $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{Tr}, "\n" if ($VERBOSE > 1);
      print 'Storing $mpro_href->{',$this_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$peak_group,'}->{log10_max_apex_intensity} = ', $mpro_href->{$this_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$peak_group}->{log10_max_apex_intensity}, "\n" if ($VERBOSE > 1);
    }
  }
}

### Now, process transition file.
### Read header and store indices for key elements
print "Reading transition file header!\n" if ($VERBOSE);
my $line = <TRAN_FILE>;
my @fields = split('\t', $line);
my $i = 0;
my ($q1_mz_idx, $q3_mz_idx, $ce_idx, $protein_name_idx, $stripped_sequence_idx,
    $isotype_idx, $prec_z_idx, $frg_type_idx, $frg_nr_idx, $frg_z_idx,
    $trfile_transition_group_id_idx, $modification_idx, $relative_intensity_idx,
    $intensity_rank_idx);
for my $field (@fields) {
  if ($field =~ /^q1$/i) {
    $q1_mz_idx = $i;
  } elsif ($field =~ /^q3$/i) {
    $q3_mz_idx = $i;
  } elsif ($field =~ /^ce$/i) {
    $ce_idx = $i;
  } elsif ($field =~ /^protein_name$|^protein$/i) {
    $protein_name_idx = $i;
  } elsif ($field =~ /^stripped_sequence$|^sequence$/i) {
    $stripped_sequence_idx = $i;
  } elsif ($field =~ /^isotype$|^heavy.light$/i) {
    $isotype_idx = $i;
  } elsif ($field =~ /^prec_z$|^q1 z$/i) {
    $prec_z_idx = $i;
  } elsif ($field =~ /^frg_type$|^ion type$/i) {
    $frg_type_idx = $i;
  } elsif ($field =~ /^frg_nr$|^ion number$/i) {
    $frg_nr_idx = $i;
  } elsif ($field =~ /^frg_z$|^q3 z$/i) {
    $frg_z_idx = $i;
  } elsif ($field =~ /^transition_group_id$/i) {
    $trfile_transition_group_id_idx = $i;
  } elsif ($field =~ /^modification$/i) {
    $modification_idx = $i;
  } elsif ($field =~ /^relative_intensity$/i) {
    $relative_intensity_idx = $i;
  } elsif ($field =~ /^intensity rank$/i) {
    $intensity_rank_idx = $i;
  }
  $i++;
}

### Read and store each line of transition file
my $rowdata_ref;
my $transdata_ref;
my ($peptide_sequence, $modified_peptide_sequence);

print "Processing transition file!\n" if ($VERBOSE);
while ($line = <TRAN_FILE>) {
  # Store select fields into transdata_ref hash
  # and load into SEL_transitions and SEL_transition_groups, if requested.
  @fields = split('\t', $line);
  my $q1_mz = $fields[$q1_mz_idx];
  my $q3_mz = $fields[$q3_mz_idx];
  $transdata_ref->{$q1_mz}->{collision_energy} = $fields[$ce_idx];
  $transdata_ref->{$q1_mz}->{protein_name} = $fields[$protein_name_idx];
  my $stripped_sequence = $fields[$stripped_sequence_idx];
  $transdata_ref->{$q1_mz}->{stripped_peptide_sequence} = $stripped_sequence;
  $transdata_ref->{$q1_mz}->{isotype} = $fields[$isotype_idx];
  $transdata_ref->{$q1_mz}->{peptide_charge} = $fields[$prec_z_idx];
  $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{frg_type} = $fields[$frg_type_idx];
  $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{frg_nr} = $fields[$frg_nr_idx];
  $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{frg_z} = $fields[$frg_z_idx];
  if ($relative_intensity_idx) {
    $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{relative_intensity} =
						$fields[$relative_intensity_idx];
  # transform intensity rank to relative intensity by taking inverse
  } elsif ($intensity_rank_idx) {
    my $relative_intensity;
    if ($fields[$intensity_rank_idx]) {
      $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{relative_intensity} =
						1/$fields[$intensity_rank_idx];
    } else {
      $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{relative_intensity} = 0;
    }
  }
  print "$stripped_sequence +$transdata_ref->{$q1_mz}->{peptide_charge} q1=$q1_mz q3=$q3_mz\n"
     if ($VERBOSE > 1);
  if ($ruth_prelim) {
    my $trfile_transition_group_id = $fields[$trfile_transition_group_id_idx];
    print $trfile_transition_group_id, "\n" if ($VERBOSE > 2);
    $trfile_transition_group_id =~ /^(\S+)\./;
    $transdata_ref->{$q1_mz}->{modified_peptide_sequence} = $1;
  } elsif ($ruth_2011) {
    $transdata_ref->{$q1_mz}->{modified_peptide_sequence} = $fields[$modification_idx];
  }
}

if ($mprophet) {
  print "Getting the mProphet scores for each transition group!\n" if ($VERBOSE);
  for my $q1_mz (keys %{$transdata_ref}) {
    # Grab the mProphet score(s) for each transition group.
    my $modified_pepseq = $transdata_ref->{$q1_mz}->{modified_peptide_sequence};
    my $charge = $transdata_ref->{$q1_mz}->{peptide_charge};
    my $decoy = 0;
    print "Getting mProphet scores for $spec_file_basename, $modified_pepseq, $charge, $decoy\n"
      if ($VERBOSE > 1);
    # For Ruth 2011 expt., mProphet file gives scores for only top peakgroup,
    # but for ruth_prelim it gives scores for all peakgroups.
    # Store them all.
    my $max_m_score = 0;
    my $Tr = 0;
    my $log10_max_apex_intensity = 0;
    for my $pg (keys %{$mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}} ) {
      my $m_score = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{m_score};
      $log10_max_apex_intensity = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{log10_max_apex_intensity};
      $Tr = $mpro_href->{$spec_file_basename}->{$modified_pepseq}->{$charge}->{$decoy}->{$pg}->{Tr};
      $transdata_ref->{$q1_mz}->{peak_groups}->{$pg}->{m_score} = $m_score;
      if ($m_score) {
	if ($m_score > $max_m_score) { $max_m_score = $m_score; }
	print '$mpro_href->{',$spec_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{m_score} = ', $m_score, "\n" if ($VERBOSE > 1);
      } else {
	print 'No m_score for $mpro_href->{',$spec_file_basename,'}->{',$modified_pepseq,'}->{',$charge,'}->{',$decoy,'}->{',$pg,'}->{m_score}', "\n"  if ($VERBOSE > 1);
      }
    }
    # Store the max m_score. Store the most recent Tr, intensity (they should all be identical).
    $transdata_ref->{$q1_mz}->{max_m_score} = $max_m_score;
    $transdata_ref->{$q1_mz}->{Tr} = $Tr;
    $transdata_ref->{$q1_mz}->{log10_max_apex_intensity} = $log10_max_apex_intensity;
  }
} else {
  print "No mProphet file given.\n" if ($VERBOSE);
}

### Load transition data

print "Loading data into SBEAMS!\n" if ($VERBOSE);
for my $q1_mz (keys %{$transdata_ref}) {

  # First, load transition group. Check to see whether already loaded.
  $rowdata_ref = {};  #reset
  $rowdata_ref->{stripped_peptide_sequence} = $transdata_ref->{$q1_mz}->{stripped_peptide_sequence};
  $rowdata_ref->{modified_peptide_sequence} = $transdata_ref->{$q1_mz}->{modified_peptide_sequence};
  $rowdata_ref->{peptide_charge} = $transdata_ref->{$q1_mz}->{peptide_charge};
  $rowdata_ref->{q1_mz} = $q1_mz;
  $rowdata_ref->{collision_energy} = $transdata_ref->{$q1_mz}->{collision_energy};
  $rowdata_ref->{isotype} = $transdata_ref->{$q1_mz}->{isotype};
  $rowdata_ref->{protein_name} = $transdata_ref->{$q1_mz}->{protein_name};

  my $sql =qq~
      SELECT SEL_transition_group_id
      FROM $TBAT_SEL_TRANSITION_GROUP
     WHERE stripped_peptide_sequence = '$rowdata_ref->{stripped_peptide_sequence}'
       AND q1_mz = '$rowdata_ref->{q1_mz}'
      ~;

  my @existing_transition_groups = $sbeams->selectOneColumn($sql);
  my $n_existing_tg = scalar @existing_transition_groups;

  # Load a SEL_transition_group record, or, if already loaded,
  # get its SEL_transition_group_id number.
  my $transition_group_id = 0;
  if ( $load_transition_groups && ! $n_existing_tg ) {
    $transition_group_id = $sbeams->updateOrInsertRow(
      insert=>1,
      table_name=>$TBAT_SEL_TRANSITION_GROUP,
      rowdata_ref=>$rowdata_ref,
      PK => 'SEL_transition_group_id',
      return_PK => 1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );
    #print "Loaded transition group $transition_group_id\n" if $VERBOSE > 2;
  } else {
    if ($n_existing_tg > 1) {
      print "WARNING: multiple transition groups found for q1  $rowdata_ref->{q1_mz}, $rowdata_ref->{protein_name}, $rowdata_ref->{stripped_peptide_sequence}; using first\n" unless ($QUIET);
      $transition_group_id = $existing_transition_groups[0];
    } elsif ($n_existing_tg == 0) {
      print "ERROR: no transition group found for q1  $rowdata_ref->{q1_mz}, $rowdata_ref->{protein_name}, $rowdata_ref->{stripped_peptide_sequence}\n";
    } else  {
      $transition_group_id = $existing_transition_groups[0];
      print "Transition group $transition_group_id already loaded\n" if $VERBOSE > 2;
    }
  }

  # Load a chromatogram record for this transition group
  # if scans for this transition group are in the spectrum file.
  # Get SEL_run_id from spectrum_filename
  my $sql = qq~
    SELECT SEL_run_id FROM $TBAT_SEL_RUN SELR
   WHERE SELR.spectrum_filename LIKE '$spec_file_basename.%';
  ~;
  my ($SEL_run_id) = $sbeams->selectOneColumn($sql);

  $rowdata_ref = {};  #reset
  $rowdata_ref->{SEL_transition_group_id} = $transition_group_id;
  $rowdata_ref->{SEL_run_id} = $SEL_run_id;
  $rowdata_ref->{m_score} = $transdata_ref->{$q1_mz}->{max_m_score};
  $rowdata_ref->{Tr} = $transdata_ref->{$q1_mz}->{Tr};
  $rowdata_ref->{max_apex_intensity} = $transdata_ref->{$q1_mz}->{log10_max_apex_intensity};
  if (! $rowdata_ref->{m_score} ) { $rowdata_ref->{m_score} = 'NULL' };
  if (! $rowdata_ref->{Tr} ) { $rowdata_ref->{Tr} = 'NULL' };
  if (! $rowdata_ref->{max_apex_intensity} ) { $rowdata_ref->{max_apex_intensity} = 'NULL' };

  my $was_scanned = find_q1_in_list (
    q1_mz=>$q1_mz,
    list_aref=>\@q1_measured,
    tol=>0.005,
  );

  sub find_q1_in_list {
    my %args = @_;
    my $target_q1=$args{'q1_mz'};
    my $list_aref = $args{'list_aref'};
    my $tol = $args{'tol'};

    for my $measured_q1 (@{$list_aref}) {
      return 1 if (($measured_q1 > $target_q1-$tol) &&
		   ($measured_q1 < $target_q1+$tol));
    }
    return 0;
  }



  my $chromatogram_id = 0;
  if ($load_chromatograms and $was_scanned) {
    $chromatogram_id = $sbeams->updateOrInsertRow(
      insert=>1,
      table_name=>$TBAT_SEL_CHROMATOGRAM,
      rowdata_ref=>$rowdata_ref,
      PK => 'SEL_chromatogram_id',
      return_PK => 1,
      verbose => $VERBOSE,
      testonly=> $TESTONLY,
    );
  } elsif (! $was_scanned ) {
    print "Q1 $q1_mz does not appear in this spectrum file.\n";
  }
  #print "Loaded chromatogram. Run ID: $SEL_run_id Chromatogram_id: $chromatogram_id\n" if $VERBOSE > 2;

   
  # Load a record for each transition
  for my $q3_mz (keys %{$transdata_ref->{$q1_mz}->{transitions}}) {
    $rowdata_ref = {};  #reset
    $rowdata_ref->{SEL_transition_group_id} = $transition_group_id;
    $rowdata_ref->{q3_mz} = $q3_mz;
    $rowdata_ref->{frg_type} = $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{frg_type};
    $rowdata_ref->{frg_nr} = $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{frg_nr};
    $rowdata_ref->{frg_z} = $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{frg_z};
    $rowdata_ref->{relative_intensity} =
			  $transdata_ref->{$q1_mz}->{transitions}->{$q3_mz}->{relative_intensity};

    my $transition_id = 0;
    # Has this transition already been loaded?
    my $sql =qq~
	SELECT SEL_transition_id
	FROM $TBAT_SEL_TRANSITION
       WHERE SEL_transition_group_id = '$transition_group_id'
	  AND q3_mz = '$q3_mz'
	~;
    my @existing_transitions = $sbeams->selectOneColumn($sql);
    my $n_existing_tr = scalar @existing_transitions;

    if ($n_existing_tr) {
      $transition_id = $existing_transitions[0];
      print "Transition $transition_id already loaded\n" if $VERBOSE > 2;
    }
    if ($load_transitions && ! $n_existing_tr) {
      $transition_id = $sbeams->updateOrInsertRow(
	insert=>1,
	table_name=>$TBAT_SEL_TRANSITION,
	rowdata_ref=>$rowdata_ref,
	PK => 'SEL_transition_id',
	return_PK => 1,
	verbose => $VERBOSE,
	testonly=> $TESTONLY,
      );
    }
    #print "  Loaded transition ID: $transition_id\n" if $VERBOSE > 2;
  }
}


###############################################################################
# removeSRMExperiment -- removes records for an SRM experiment
###############################################################################
sub removeSRMExperiment {
   my %args = @_;
   my $SEL_experiment_id = $args{'SEL_experiment_id'};
   my $keep_experiments_and_runs = $args{'keep_experiments_and_runs'} || 0;

   my $database_name = $DBPREFIX{PeptideAtlas};

   # First, get SEL_runs in this experiment.
   my $sql = qq~
     SELECT SEL_run_id
       FROM $TBAT_SEL_RUN 
     WHERE SEL_experiment_id = $SEL_experiment_id
   ~;
   my @run_ids = $sbeams->selectOneColumn($sql);
   my $run_id_string = join (",", @run_ids);

   # Next, get SEL_transition_group records that are parents
   # of chromatograms in this experiment. We may not want to purge these
   # as a rule (because they may belong to more than one expt.)
   # but for now we do.
   $sql = qq~
     SELECT SELTG.SEL_transition_group_id
       FROM $TBAT_SEL_TRANSITION_GROUP SELTG
       JOIN $TBAT_SEL_CHROMATOGRAM SELC
	 ON SELC.SEL_transition_group_id = SELTG.SEL_transition_group_id
      WHERE SELC.SEL_run_id in ($run_id_string)
   ~;
   my @transition_group_ids = $sbeams->selectOneColumn($sql);

   # Purge chromatogram records, and possibly also experiment & run records.
   my %table_child_relationship = (
      SEL_experiment => 'SEL_run(C)',
      SEL_run => 'SEL_chromatogram(C)',
   );

   if ($keep_experiments_and_runs) {
     print "Purging experiment $purge_experiment; keeping expt & run records.\n" if $VERBOSE;

     #don't delete experiment OR run records
     delete $table_child_relationship{SEL_EXPERIMENT};
     $sbeams->deleteRecordsAndChildren(
       table_name => 'SEL_run',
       table_child_relationship => \%table_child_relationship,
       delete_PKs => \@run_ids,
       delete_batch => 1000,
       database => $database_name,
       verbose => $VERBOSE,
       testonly => $TESTONLY,
       keep_parent_record => 1,
    );
  } else {
     print "Purging experiment $purge_experiment; removing expt & run records.\n" if $VERBOSE;
      $sbeams->deleteRecordsAndChildren(
         table_name => 'SEL_experiment',
         table_child_relationship => \%table_child_relationship,
         delete_PKs => [ $SEL_experiment_id ],
         delete_batch => 1000,
         database => $database_name,
         verbose => $VERBOSE,
         testonly => $TESTONLY,
      );
  }

  # Now, purge transition_group and transition records.
   %table_child_relationship = (
      SEL_transition_group => 'SEL_transition(C)',
   );

  my $result = $sbeams->deleteRecordsAndChildren(
     table_name => 'SEL_transition_group',
     table_child_relationship => \%table_child_relationship,
     delete_PKs => \@transition_group_ids,
     delete_batch => 1000,
     database => $database_name,
     verbose => $VERBOSE,
     testonly => $TESTONLY,
  );

} # end removeSRMExperiment
