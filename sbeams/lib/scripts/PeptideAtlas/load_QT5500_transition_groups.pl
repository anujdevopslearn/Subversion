#!/usr/local/bin/perl

###############################################################################
# Program      : load_QT5500_transition_groups.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# For each peptide in each QT5500 sample in SRMAtlas,
#  store some basic info from the mzML file for later use in GetPeptide.
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
$|++;

use lib "$FindBin::Bin/../../perl";
#use SBEAMS::PeptideAtlas::LoadSRMExperiment;

use vars qw ($sbeams $PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
#use SBEAMS::PeptideAtlas::ConsensusSpectrum;
#use SBEAMS::PeptideAtlas::ModificationHelper;
#use SBEAMS::PeptideAtlas::Utilities;

$sbeams = new SBEAMS::Connection;

#my $loader = new SBEAMS::PeptideAtlas::LoadSRMExperiment;

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

  --spectrum_name             Spectrum name to load.
                               If not provided, load all QT5500 spectra.
 e.g.:  $PROG_NAME --spec 5Q20100630_ZH-K92_P1_r01.00267.00267.2
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "spectrum_name:s",
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

my $spectrum_name = $OPTIONS{"spectrum_name"} || '';
my $spectrum_name_clause = '';
if ($spectrum_name) {
  $spectrum_name_clause = qq~
    and SPEC.spectrum_name = '$spectrum_name'
  ~;
}
  


# Get all QT5500 samples from SRMAtlas
#for each spectrum_name in each QT5500 sample in SRM_Atlas

my $sql = qq~
  select S.sample_id, S.sample_description, ASB.data_location, SPEC.spectrum_name
  from $TBAT_SAMPLE S
  join $TBAT_ATLAS_BUILD_SAMPLE ABS
  on ABS.sample_id = S.sample_id
  join $TBAT_ATLAS_BUILD AB
  on AB.atlas_build_id = ABS.atlas_build_id
  join $TBAT_SPECTRUM SPEC
  on SPEC.sample_id = S.sample_id
  join $TBAT_ATLAS_SEARCH_BATCH ASB
  on ASB.sample_id = S.sample_id
  where AB.atlas_build_name like 'Human SRM%'
  $spectrum_name_clause
  and S.sample_description like '%QT5500%';
~;

print "Executing $sql\n\n" if $VERBOSE;
my @rows = $sbeams->selectSeveralColumns($sql);
my $nrows = scalar @rows;
print "$nrows retrieved.\n" if $VERBOSE;

my %info;
my $general_data_dir = '/regis/sbeams/archive';

print "Getting filenames to cover all spectrum names gathered.\n" if $VERBOSE;
for my $row (@rows) {

  my ($sample_id, $sample_descr, $data_location, );
  ($sample_id, $sample_descr, $data_location, $spectrum_name) = @{$row};
  print "$sample_id\t$spectrum_name\t" if $VERBOSE > 2;

  # Get mzML filename, cycle, and charge from spectrum name
  $spectrum_name =~ /(\S+)\.(\d+?)\.(\d+?)\.(\d)/;
  my $mzml_basename = $1;
  my $cycle = int($2);
  my $cycle2 = int($3);
  my $precursor_charge = $4;
  $mzml_basename =~ s/\.mzML$//;    #remove .mzML if it's there
  my $mzml_fname = "${mzml_basename}.mzML";  #then add it back to all.
  my $rt;

  my $mzml_pathname = "${general_data_dir}/${data_location}/${mzml_fname}";
  print "$mzml_pathname\n" if $VERBOSE > 2;

  $info{$mzml_fname}->{cycles}->{$cycle}->{charge} = $precursor_charge;
  # Possible multiple paths for same fname? If so, this wipes out alternatives.
  if ( ! ( -e $mzml_pathname ) ) {
    print "$mzml_pathname does not exist.\n" if $DEBUG;
  } elsif ( ! ( -r $mzml_pathname ) ) {
    print "$mzml_pathname is not readable.\n" if $DEBUG;
  } else {
    $info{$mzml_fname}->{path} = $mzml_pathname;
  }
}

my $n_filenames = scalar keys %info;
print "$n_filenames different mzML filenames found.\n" if $VERBOSE;

my $insert_count = 0;
my $file_count = 0;
my $no_file = 0;
print "Looking up scans for each mzML file\n" if $VERBOSE;
for my $mzml_fname (keys %info) {
  my $mzml_pathname = $info{$mzml_fname}->{path};
  if (! $mzml_pathname ) {
    print "No readable pathname for $mzml_fname.\n" if $VERBOSE > 1;
    $no_file++;
    next;
  }
  print "Extracting info from $mzml_pathname.\n" if $VERBOSE > 1;
  my $cycle_list = join(" ", keys %{$info{$mzml_fname}->{cycles}} );
  # Make system call to readmzXML to get precursor m/z, RT.
  my $cmd = "/proteomics/sw/tpp/bin/readmzXML -b $mzml_pathname $cycle_list";
  print $cmd if $DEBUG;
  my $mzml_info = `$cmd`;
  print $mzml_info if $DEBUG;

  my ($cycle, $rt, $precursorMZ);
  for (split /^/, $mzml_info) {
    if ( /Scan (\d*)/ ) {
      $cycle = $1;
    }
    if ( /precursorMZ:\s*(\d+\.\d+)/ ) {
      $precursorMZ = $1;
    }
    if ( /scanTime:\s*(\d+\.\d+)/ ) {
      $rt = $1;
      print "Scan $cycle Precursor m/z: $precursorMZ RT: $rt\n" if $VERBOSE > 2;
      # $info{$mzml_fname}->{cycles}->{$cycle}->{rt} = $rt;
      # $info{$mzml_fname}->{cycles}->{$cycle}->{precursorMZ} = $precursorMZ;
      $insert_count++;

      my $rowdata_ref;
      $rowdata_ref->{mzml_filename} = $mzml_fname;
      $rowdata_ref->{mzml_pathname} = `dirname $mzml_pathname`;
      $rowdata_ref->{cycle} = $cycle;
      $rowdata_ref->{precursor_charge} = $info{$mzml_fname}->{cycles}->
							  {$cycle}->{charge};
      $rowdata_ref->{precursor_mz} = $precursorMZ;
      $rowdata_ref->{rt} = $rt;

      my $sql_verbose = ($VERBOSE > 1);

      # INSERT!
      my $qt5500_transition_group_id = $sbeams->updateOrInsertRow(
	insert=>1,
	table_name=>$TBAT_QT5500_TRANSITION_GROUP,
	rowdata_ref=>$rowdata_ref,
	PK => 'QT5500_transition_group_id',
	return_PK => 1,
	verbose=>$sql_verbose,
	testonly=>$TESTONLY,
      );
    }
  }

  $file_count++;
  print "." if ( ! ($file_count % 10) && $VERBOSE);
  print "$file_count" if ( ! ($file_count % 100) && $VERBOSE);



# What is the most efficient way to do this insert?

}

print "\n$no_file mzML files not found\n" if $VERBOSE;
print "$insert_count inserts\n" if $VERBOSE;
