#!/usr/local/bin/perl -w
###############################################################################
# Program     : estimateConcentrations.pl
# Author      : Terry Farrah <tfarrah@systemsbiology.org>
# $Id$
#
# Description : Estimates protein concentration for a peptide atlas
#               build using spectral counting
#
# SBEAMS is Copyright (C) 2000-2010 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use POSIX;  #for floor()
use Math::Round qw/round/;
use GD::Simple;
use Getopt::Long;
use FindBin;
use Data::Dumper;
use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $DATABASE $current_contact_id $current_username
            );

use vars qw (%peptide_accessions %biosequence_attributes);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

use SBEAMS::Proteomics::Tables;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ProtInfo;
use SBEAMS::PeptideAtlas::SpectralCounting;
use SBEAMS::PeptideAtlas;

use Statistics::Descriptive;
#use Statistics::Descriptive::Full;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS( $sbeams );
# delete if we don't need
#$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

$| = 1; #flush output on every print


###############################################################################
# Read and validate command line args
###############################################################################
my $VERSION = q[$Id$ ];
$PROG_NAME = $FindBin::Script;
my $build_version = $ENV{VERSION};

my $USAGE = <<EOU;
USAGE: $PROG_NAME [OPTIONS] 
  Calculates PSMs per 100K for each protein, normalized to observable
  peps in protein. If calibration values given, estimates concentrations
  using spectral counting.
Options:
  --quiet             Set flag to print nothing at all except errors.
                      This masks the printing of progress information
                       and statistics that show whether process is
                       successful.
  --debug n           Set debug level.  default is 0

  --atlas_build_id    One of these three is required.
  --atlas_build_name   
  --atlas_data_dir

  --calibr_file       Name of .tsv file containing calibration values
                         Two columns: prot accession, fmol/ml
                         Default: sc_calibration.tsv in atlas build dir
  --protlist_file     PeptideAtlasInput.PAprotlist for build, created in step02a
                         Default: look in atlas build dir
  --PAidentlist_file  PeptideAtlasInput_concat.PAidentlist for build,
                         created in step1 Default: look in atlas build dir

  --biosequence_set_id   Required

  --min_n_obs         Min obs to use prot for spec counting. Default 4.
  --outlier_threshold Points more than this distance (log scale) above
		      or below trend will not be used for calibration.
                      Default: 2.0
  --stdev_win_width   Width (log scale) for sliding window used to
		      compute uncertainty factors. Default: 1.5

  --glyco_atlas       All expts are glycocapture. For abundance estimation.

 e.g.:  $PROG_NAME --atlas_build_name HumanPlasma_2010-05 --bioseq 73

EOU

#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
    "atlas_build_id=s", "atlas_build_name=s", "atlas_data_dir=s",
    "calibr_file=s", "protlist_file=s", "PAidentlist_file=s",
    "glyco_atlas", "stdev_win_width=f", "min_n_obs=i",
    "outlier_threshold=f", "biosequence_set_id=s",
  )) {
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
}

my $atlas_build_id = $OPTIONS{atlas_build_id} || '';
my $atlas_build_name = $OPTIONS{atlas_build_name} || '';
my $atlas_data_dir = $OPTIONS{atlas_data_dir} || '';
if (!$atlas_build_id && !$atlas_build_name && !$atlas_data_dir) {
  die "Must specify atlas_build_id, atlas_build_name, or atlas_data_dir";
}
if (($atlas_build_id && $atlas_build_name) ||
    ($atlas_build_id && $atlas_data_dir) ||
    ($atlas_build_name && $atlas_data_dir)) {
  die "Specify only one of atlas_build_id, atlas_build_name, or atlas_data_dir";
}
if ($atlas_build_id) {
  my $sql = qq~
     SELECT atlas_build_name
       FROM $TBAT_ATLAS_BUILD
      WHERE atlas_build_id = $atlas_build_id
  ~;
  ($atlas_build_name) = $sbeams->selectOneColumn($sql);
  $atlas_data_dir =
    $atlas->getAtlasBuildDirectory( atlas_build_id => $atlas_build_id );
} elsif ($atlas_build_name) {
  my $sql = qq~
     SELECT atlas_build_id
       FROM $TBAT_ATLAS_BUILD
      WHERE atlas_build_name = '$atlas_build_name'
  ~;
  ($atlas_build_id) = $sbeams->selectOneColumn($sql);
  $atlas_data_dir =
    $atlas->getAtlasBuildDirectory( atlas_build_id => $atlas_build_id );
  print "Hello! $atlas_build_name $atlas_build_id $atlas_data_dir\n";
} elsif ($atlas_data_dir) {
  my $build_path = `dirname $atlas_data_dir`;
  my $build_dir_name = `basename $build_path`;
  my $data_path = 'DATA_FILES' . `basename $build_dir_name`;
  my $sql = qq~
     SELECT atlas_build_id, atlas_build_name
       FROM $TBAT_ATLAS_BUILD
      WHERE data_path = '$data_path'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);
  if (@rows) {
# atlas_build_id not used
#    $atlas_build_id = $rows[0]->[0];
    $atlas_build_name = $rows[0]->[1];
  }
}


my ($calibr_file, $protlist_file, $PAidentlist_file);

if ($atlas_data_dir) {
  if ( ! -e $atlas_data_dir ) {
    die "$atlas_data_dir: no such directory";
  }
  $calibr_file=$atlas_data_dir."/sc_calibration.tsv";
  # calibr_file is optional; if it doesn't exist, set filename to empty str.
  $calibr_file = "" if (! -e $calibr_file);
  $protlist_file=$atlas_data_dir."/PeptideAtlasInput.PAprotIdentlist";
  $PAidentlist_file=$atlas_data_dir."/PeptideAtlasInput_concat.PAidentlist";
}

$calibr_file = $OPTIONS{calibr_file} if ($OPTIONS{calibr_file});
if (! $calibr_file) {
  print "No calibration file found; concentrations will not be estimated.\n";
}
$protlist_file = $OPTIONS{protlist_file} if ($OPTIONS{protlist_file});
$PAidentlist_file = $OPTIONS{PAidentlist_file} if ($OPTIONS{PAidentlist_file});

my $png_file = $atlas_data_dir."/sc_calibration.png";
my $protlist_rawfile = $protlist_file . '_prelim';

my $min_n_obs = $OPTIONS{min_n_obs} || 4;
my $outlier_threshold = $OPTIONS{outlier_threshold} || 2.0;
my $stdev_win_width = $OPTIONS{stdev_win_width} || 1.5;

my $bssid = $OPTIONS{biosequence_set_id};

if (!defined $PAidentlist_file || !defined $protlist_file || !defined $bssid) {
  print "$USAGE";
  exit;
}

my $organism_id;
my $glyco_atlas = $OPTIONS{glyco_atlas} || 0;

#### Fetch the total number of PSMs (identified spectra) for this build
my $total_PSMs = `wc -l $PAidentlist_file | cut -f 1 -d ' '`;
print "TOTAL PSMs $total_PSMs\n";


#### Fetch the biosequence data
my $sql = qq~
   SELECT organism_id
     FROM $TBAT_BIOSEQUENCE_SET
    WHERE biosequence_set_id = $bssid
~;
($organism_id) = $sbeams->selectOneColumn($sql);
print "Organism_id = $organism_id\n" unless $QUIET;

$sql = qq~
   SELECT biosequence_id,biosequence_name,biosequence_gene_name,
	  biosequence_accession,biosequence_desc,biosequence_seq
     FROM $TBAT_BIOSEQUENCE
    WHERE biosequence_set_id = $bssid
~;
print "Fetching all biosequence data...\n" unless $QUIET;
print "$sql" unless $QUIET;
my @rows = $sbeams->selectSeveralColumns($sql);
foreach my $row (@rows) {
  # Hash each biosequence_name to its row
  $biosequence_attributes{$row->[1]} = $row;
  #print "$row->[1]\n" unless $QUIET;
}
print "  Loaded ".scalar(@rows)." biosequences.\n" unless $QUIET;

#### Just in case the table is empty, put in a bogus hash entry
#### to prevent triggering a reload attempt
$biosequence_attributes{' '} = ' ';

my $effective_organism_id = 2;  # default is human
if ( defined $organism_id ) {
  $effective_organism_id = $organism_id;
}

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'PeptideAtlas_admin'));

#### Print the header, do what the program does, and print footer
$sbeams->printPageHeader() unless $QUIET;
main();
$sbeams->printPageFooter() unless $QUIET;

###############################################################################
# Main part of the script
###############################################################################
sub main {

  # Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }

  ####
  #### Get n_obs for each atlas protein and store in hash
  ####
  my $protlist_href =
      get_n_obs_for_each_atlas_protein_and_store_in_hash($protlist_file);

  my $calibr_slope = 0;
  my $calibr_y_int = 0;
  my %uncertainties;

  if ( $calibr_file) {

    ####
    #### Read calibration values from $calibr_file into hash
    ####
    my $calibr_href = read_calibration_values_and_store_in_hash ($calibr_file);

    ####
    #### Look up each calibration protein in the Atlas and store the
    #### normalized PSM count in $calibr_href. Note prots invalid for calibr.
    ####
    my ( $aref1, $aref2, $aref3, $aref4, $aref5, $aref6) =
      get_Atlas_info_for_calibration_proteins
	 ($calibr_href, $protlist_href, $glyco_atlas);
    my @calibr_not_in_atlas = @{$aref1};
    my @n_obs_too_low = @{$aref2};
    my @no_glycosite = @{$aref3};
    my @sorted_y_values = @{$aref4};
    my @sorted_x_values = @{$aref5};
    my @sorted_calibr_protids = @{$aref6};

    my $n_calibr = scalar @sorted_x_values;

    ####
    #### Fit a trend line to the (x,y) pairs (fmol_per_ml, norm_PSM_count)
    ####
    print "Fitting line to calibration values ...\n" unless $QUIET;
    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@sorted_y_values);
    my ($y_int, $slope, $corr_coeff, $rms) = $stat->least_squares_fit(@sorted_x_values);
    printf "   n=%d, y_int=%-6.2f slope=%-6.2f corr_coeff=%-6.2f rms=%-6.2f\n",
       $n_calibr, $y_int, $slope, $corr_coeff, $rms unless $QUIET;
    unless ($QUIET) {
      print "WARNING: negative correlation coefficient\n" if ($corr_coeff < 0)
    }

    ####
    #### Note outliers
    ####
    ($aref1, $aref2) = find_outliers($calibr_href, \@sorted_calibr_protids,
       \@sorted_x_values, \@sorted_y_values, $slope, $y_int);
    my @outliers = @{$aref1};
    my @culled_sorted_calibr_protids = @{$aref2};

    my $n_outliers = scalar @outliers;

    ####
    #### Draw a graph using GD::Simple
    ####
    open (PNG, ">$png_file");
    my ($x, $y);
    my $min_xy = -1;
    my $max_xy = 9;
    my $range_xy = $max_xy - $min_xy;
    my $origin = 100;
    my $winwidth = 700;
    my $plotwidth = $winwidth - 2*$origin;
    my $factor = $plotwidth / $range_xy;
    my $img = GD::Simple->new($winwidth, $winwidth);

    # Bound plotting area with a rectangle and draw legend
    my $build_name = $atlas_build_name;
    $build_name = `dirname $atlas_data_dir` if (!$build_name);
    draw_blank_plot_with_legend($img, $origin, $plotwidth, $build_name,
					 $min_xy,$max_xy,$min_n_obs, $stdev_win_width, $glyco_atlas);

    # Draw original trend line
    draw_trend_line ( $min_xy, $max_xy, $slope, $y_int, $origin,
														 $winwidth, $factor, $img, 'gray' );

    # Draw the calibration points
    for (my $i=0; $i<$n_calibr; $i++) {
      my $protid = $sorted_calibr_protids[$i];
      my $color = 'blue'; $color = 'red' if ($calibr_href->{$protid}->{outlier});
      $x = $sorted_x_values[$i]; $y = $sorted_y_values[$i];
      ($x, $y) = transform_x_y($x, $y, $origin, $winwidth, $factor, $min_xy);
      $img->bgcolor($color); $img->fgcolor($color);
      $img->rectangle($x-2,$y-2,$x+2,$y+2);
    }

    # Draw points for calibration proteins with n_obs below threshold
    for my $protid (@n_obs_too_low) {
      my $x = log10($calibr_href->{$protid}->{norm_PSM_count});
      my $y = log10($calibr_href->{$protid}->{fmol_per_ml});
      ($x, $y) = transform_x_y($x, $y, $origin, $winwidth, $factor, $min_xy);
      $img->bgcolor('white'); $img->fgcolor('red');
      $img->rectangle($x-2,$y-2,$x+2,$y+2);
    }

    # Draw points for calibration proteins with n_obs below threshold
    if ($glyco_atlas) {
      for my $protid (@no_glycosite) {
				my $x = log10($calibr_href->{$protid}->{norm_PSM_count});
				my $y = log10($calibr_href->{$protid}->{fmol_per_ml});
				($x, $y) = transform_x_y($x, $y, $origin, $winwidth, $factor, $min_xy);
				$img->bgcolor('white'); $img->fgcolor('green');
				$img->rectangle($x-2,$y-2,$x+2,$y+2);
      }
    }

    # end drawing graph using GD::Simple

    ####
    #### Re-calibrate with outliers tossed
    ####
    print "Re-fitting line ...\n" unless $QUIET;
    @sorted_x_values = ();
    @sorted_y_values = ();
    $n_calibr = scalar @culled_sorted_calibr_protids;
    for my $protid (@culled_sorted_calibr_protids) {
      #printf "%8s %8.2f %8.2f %8.2f\n", $protid,
       #log10($calibr_href->{$protid}->{norm_PSM_count}),
       #log10($calibr_href->{$protid}->{fmol_per_ml}),
       #log10($calibr_href->{$protid}->{norm_PSM_count})-
	   #log10($calibr_href->{$protid}->{fmol_per_ml}) unless $QUIET;
      push (@sorted_x_values, log10($calibr_href->{$protid}->{norm_PSM_count}));
      push (@sorted_y_values, log10($calibr_href->{$protid}->{fmol_per_ml}));
    }
    $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@sorted_y_values);
    ($y_int, $slope, $corr_coeff, $rms) =
	   $stat->least_squares_fit(@sorted_x_values);
    printf "   n=%d y_int=%-6.2f slope=%-6.2f corr_coeff=%-6.2f rms=%-6.2f\n",
       $n_calibr, $y_int, $slope, $corr_coeff, $rms unless $QUIET;
    unless ($QUIET) {
      print "WARNING: correlation coefficient still negative!\n"
	   if ($corr_coeff < 0);
    }

    # Save the slope & y-intercept for estimating Atlas concentrations
    $calibr_slope = $slope;
    $calibr_y_int = $y_int;

    # Draw new trend line
    draw_trend_line ( $min_xy, $max_xy, $slope, $y_int, $origin,
       $winwidth, $factor, $img, 'blue' );

    ####
    #### Calculate uncertainty factors
    ####

    # First, set up some useful parameters
    $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@sorted_x_values);
    my $x_min = $stat->min();
    my $x_max = $stat->max();
    my $x_range = $x_max - $x_min;
    my $x_window = $stdev_win_width;
    my $x_incr = 0.1;

    # Get the deviations from the trend line within a sliding window
    ($aref1, $aref2) = calculate_deviations_from_trend_line_using_sliding_window
						( $x_min, $x_max, $x_incr, $x_window, \@culled_sorted_calibr_protids,
							$calibr_href, $slope, $y_int,);
    my @x_values=@{$aref1};         # x values for which there is a stdev
    my @stdev_values=@{$aref2};     # the corresponding stdev values

    # Fit a line to those values
    print "Now, fitting a line to those values ...\n" unless $QUIET;
    $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@stdev_values);
    my ($y_int_err, $slope_err, $corr_coeff_err, $rms_err) =
	   $stat->least_squares_fit(@x_values);
    unless ($QUIET) {
      printf "   y_int=%-6.2f slope=%-6.2f corr_coeff=%-6.2f rms=%-6.2f\n",
						 $y_int_err, $slope_err, $corr_coeff_err, $rms_err;
      print "\nWARNING: uncertainty factors increase toward higher concentrations!\n" if ($slope_err > 0);
      #print "\nWARNING: negative correlation coefficient; ".
	    #"try increasing --stdev_win_width?\n" if ($corr_coeff_err < 0);
      print "\n";
    }

    # Then get the uncertainty factors by sampling values at intervals of
    # 1.0 along the x-axis. Store and print the factors.
    print "log10(norm PSM count) Uncertainty Factor\n" unless $QUIET;    
    for (my $i = -2; $i < 12; $i++ ) {
      my $center_log_x_window = $i + 0.5;
      my $low_x = $i;
      my $high_x = $i+1;
      my $stdev = $slope_err * $center_log_x_window + $y_int_err;
      my $uncertainty_factor = round(10 ** $stdev);
      $uncertainties{$low_x} = $uncertainty_factor;
      unless ($QUIET) {
				printf "       %2d-%-2d             %2dx",
				 $low_x, $high_x, $uncertainty_factor;
				print " (out of calibr range)" if (($i <= $x_min-1) || ($i >= $x_max+1));
				print "\n";
      }
    }

    # Graph the uncertainty stats
    my $n_uncert_vals = scalar(@stdev_values);
    for (my $i = 0; $i < $n_uncert_vals; $i++) {
      my $x = $x_values[$i];
      my $y = ($calibr_slope * $x + $calibr_y_int) + $stdev_values[$i];
      ($x, $y) = transform_x_y($x, $y, $origin, $winwidth, $factor, $min_xy);
      $img->bgcolor('pink'); $img->fgcolor('pink');
      $img->moveTo($x,$y);
      $img->ellipse(3,3);
      #$img->rectangle($x-2,$y-2,$x+2,$y+2);
    }
    draw_trend_line ( $min_xy, $max_xy, $slope+$slope_err, $y_int+$y_int_err,
       $origin, $winwidth, $factor, $img, 'pink' );
    draw_trend_line ( $min_xy, $max_xy, $slope-$slope_err, $y_int-$y_int_err,
       $origin, $winwidth, $factor, $img, 'pink' );

    # Print image
    print PNG $img->png;
    close (PNG);
    print "Plot stored in $png_file.\n" unless $QUIET;

  } #end if $calibr_file

  ####
  #### Calculate normalized PSMs per 100K for all protids.
  #### Estimate concentrations for all protein group representatives
  #### with n_obs >= 4 and insert into a copy of PeptideAtlasInput.PAProtlist
  ####
  estimate_concentrations ($calibr_file, $protlist_file, $protlist_rawfile,
      $min_n_obs, \%biosequence_attributes, $calibr_slope, $calibr_y_int,
      $total_PSMs, \%uncertainties, $glyco_atlas);

} # end main

###############################################################################
# read_calibration_values_and_store_in_hash
###############################################################################
sub read_calibration_values_and_store_in_hash {
  my $calibr_file = shift;
  my $calibr_href;
  print "Reading $calibr_file ...\n" unless $QUIET;
  open (CALIBR, $calibr_file) || die "Can't open $calibr_file";
  my $line = <CALIBR>;   #toss header line
  while ($line = <CALIBR>) {
    chomp $line;
    my ($protid, $fmol_per_ml) = split ("\t", $line);
    $calibr_href->{$protid}->{fmol_per_ml} = $fmol_per_ml;
  }
  close (CALIBR);
  return ($calibr_href);
}

###############################################################################
# get_n_obs_for_each_atlas_protein_and_store_in_hash
###############################################################################
sub get_n_obs_for_each_atlas_protein_and_store_in_hash {
  my $protlist_href;
  my $protlist_file = shift;
  print "Reading $protlist_file ...\n" unless $QUIET;
  open (PROT, $protlist_file) || die "Can't open $protlist_file";
  my $line = <PROT>;
  while ($line = <PROT>) {
    chomp $line;
    my ($protein_group_number,$biosequence_names,$probability,
        $confidence,$n_observations,$n_distinct_peptides,
        $level_name,$represented_by_biosequence_name,
        $subsumed_by_biosequence_names,$estimated_ng_per_ml,
        $abundance_uncertainty,$covering) = split (",", $line);
    my @protids = split(" ",$biosequence_names);
    for my $protid (@protids) {
      $protlist_href->{$protid}->{n_observations} = $n_observations;
    }
  }
  close (PROT);
  return ($protlist_href);
}

###############################################################################
# get_Atlas_info_for_calibration_proteins
###############################################################################
sub get_Atlas_info_for_calibration_proteins {
  my $calibr_href = shift;
  my $protlist_href = shift;
  my $glyco_atlas = shift;

  my @calibr_not_in_atlas;
  my @n_obs_too_low;
  my @no_glycosite;
  my @sorted_y_values;
  my @sorted_x_values;
  my @sorted_calibr_protids;

  print "Looking up calibration proteins in atlas ...\n" unless $QUIET;
  printf "   %-8.8s %-8.8s %-8.8s %-8.8s %-8.8s %-8.8s %-8.8s  Why discarded\n",
       "protid", "n_obs", "x=a.PSMs", "logx",
       "y=fmo/ml","logy","logdiff" unless $QUIET; 
  my @raw_sorted_calibr_protids = sort
      { $calibr_href->{$a}->{fmol_per_ml} <=>
        $calibr_href->{$b}->{fmol_per_ml};     }
      keys %{$calibr_href};
  for my $protid ( @raw_sorted_calibr_protids ) {
    ## get protein sequence
    my $protseq = $biosequence_attributes{$protid}->[5];
    ## calculate number of observable peptides
    my $n_observable_peps =
      SBEAMS::PeptideAtlas::SpectralCounting::countPepsInProt (
				seq=>$protseq,
      );
    my $n_observable_glycopeps =
      SBEAMS::PeptideAtlas::SpectralCounting::countPepsInProt (
				seq=>$protseq,
        glyco_only=>1,
      );
    my $fmol_per_ml = $calibr_href->{$protid}->{fmol_per_ml};
    my $log_fmol_per_ml = log10($fmol_per_ml);
    my ($norm_PSM_count, $log_norm_PSM_count);
    my $n_observations;

    ## If it is in this atlas build, (and, if glyco atlas, if it's
    ## a glyco protein), compute normalized PSM count
    if ( defined $protlist_href->{$protid} ) {
      $n_observations = $protlist_href->{$protid}->{n_observations};
      $norm_PSM_count = 
			SBEAMS::PeptideAtlas::SpectralCounting::adjust_PSM_count (
			 PSM_count => $n_observations,
			 n_observable_peps => $n_observable_peps,
			 n_observable_glycopeps => $n_observable_glycopeps,
			 glyco_atlas => $glyco_atlas,
			);
      $log_norm_PSM_count = log10($norm_PSM_count);
      $calibr_href->{$protid}->{norm_PSM_count} = $norm_PSM_count;
    } else {
      $n_observations = 0;
      $norm_PSM_count = 0;
      $log_norm_PSM_count = 0;
    }
    # Print info on this calibration protein
    printf "   %s %8.0f %8d %8.2f %8.2f %8.2f %8.2f",
	 $protid,
         $n_observations,
	 $norm_PSM_count,
	 $log_norm_PSM_count,
	 $fmol_per_ml,
	 $log_fmol_per_ml,
	 $log_norm_PSM_count - $log_fmol_per_ml unless $QUIET;
    ## Store values needed for calibration
    if (! defined $protlist_href->{$protid} ) {
      push (@calibr_not_in_atlas, $protid);
      print " Not in atlas" unless $QUIET;
    ## use hasGlycoSite; might be true when $n_observable_glycopeps==0
    } elsif (
	      ! SBEAMS::PeptideAtlas::SpectralCounting::hasGlycoSite(
		  seq=>$protseq,
		  next_aa=>'A')
            ) {

      push (@no_glycosite, $protid);
      print " no NXS/T motif" unless $QUIET;
    } elsif ($protlist_href->{$protid}->{n_observations} < $min_n_obs ) {
      push (@n_obs_too_low, $protid);
      print " n_obs < $min_n_obs" unless $QUIET;
    } else {
      push (@sorted_calibr_protids, $protid);
      push (@sorted_y_values, $log_fmol_per_ml);
      push (@sorted_x_values, $log_norm_PSM_count);
    }
    print "\n" unless $QUIET;
  }
  return ( \@calibr_not_in_atlas, \@n_obs_too_low, \@no_glycosite,
           \@sorted_y_values, \@sorted_x_values, \@sorted_calibr_protids, );
}


###############################################################################
# find_outliers: note which log(norm_PSM_count), log(fmol_per_ml) pairs
#   are far from the trend line, and separate from the others
###############################################################################

sub find_outliers {
  my $calibr_href = shift;
  my $sorted_calibr_protids_aref = shift;
  my $sorted_x_values_aref = shift;
  my $sorted_y_values_aref = shift;
  my $slope = shift;
  my $y_int = shift;

  my @outliers;
  my @culled_sorted_calibr_protids;
  my $n_calibr = scalar @{$sorted_x_values_aref};

  print "Tossing outliers ...\n" unless $QUIET;
  for (my $i=0; $i<$n_calibr; $i++) {
    my $x = $sorted_x_values_aref->[$i];
    my $y = $sorted_y_values_aref->[$i];
    my $protid = $sorted_calibr_protids_aref->[$i];
    my $predicted_y = $x*$slope + $y_int;
    printf "   %s x=%-8.2f y=%-8.2f predicted_y=%-8.2f",
           $protid, $x, $y, $predicted_y unless $QUIET;
    my $y_diff = abs ($y - $predicted_y);
    if ($y_diff > $outlier_threshold) {
      push ( @outliers, $protid );
      $calibr_href->{$protid}->{outlier} = 1;
      print " REJECT\n" unless $QUIET;
    } else {
      push ( @culled_sorted_calibr_protids, $protid );
      print "\n" unless $QUIET;
    }
  }
  return (\@outliers, \@culled_sorted_calibr_protids);
}

###############################################################################
# draw_blank_plot_with_legend
###############################################################################
sub draw_blank_plot_with_legend {
  my $img = shift;
  my $origin = shift;
  my $plotwidth = shift;
  my $build_name = shift;
  my $min_xy = shift;
  my $max_xy = shift;
  my $min_n_obs = shift;
  my $stdev_win_width = shift;
  my $glyco_atlas = shift;

  $img->fgcolor('black');  #pen color
  $img->rectangle($origin,$origin,$origin+$plotwidth,$origin+$plotwidth);
  my $date = `date`;
  my $y_start = 20;
  $img->moveTo (20, $y_start); $y_start += 15;
  $img->string ("Spectral Counting calibration for $build_name");
  $img->moveTo (20, $y_start); $y_start += 15;
  $img->string("X-axis: log normalized PSM counts. Y-axis: log measured fmol/ml".
                " Origin: $min_xy,$min_xy Max: $max_xy,$max_xy");
  $img->moveTo (20, $y_start); $y_start += 15;
  $img->string ("Solid red: outliers. Hollow red: PSMs < $min_n_obs ".
                " Gray line: all solid points.".
                " Blue line: outliers discarded.");
  $img->moveTo (20, $y_start); $y_start += 15;
  if ($glyco_atlas) {
    $img->string ("Hollow green: calibr prots with no NXS/T; not used");
    $img->moveTo (20, $y_start); $y_start += 15;
  }
  $img->string("Pink: stdevs for sliding ".
                "window width $stdev_win_width, with fitted trend line");
  $img->moveTo (20, $y_start); $y_start += 15;
  $img->string ("$date");

}


###############################################################################
# calculate_deviations_from_trend_line_using_sliding_window
###############################################################################
sub calculate_deviations_from_trend_line_using_sliding_window {
  my $x_min = shift;
  my $x_max = shift;
  my $x_incr = shift;
  my $x_window = shift;
  my $culled_sorted_calibr_protids_aref = shift;
  my $calibr_href = shift;
  my $slope = shift;
  my $y_int = shift;

  my @x_values=();       # x values for which there is a stdev
  my @stdev_values=();   # the corresponding stdev values

  unless ($QUIET) {
    print "Calculating uncertainty factors.\n";
    print "First, calculating stdev at increments along X-axis ...\n";
    printf "   min=%-6.2f max=%-6.2f incr=%-6.2f win=%-6.2f\n",
	    $x_min, $x_max, $x_incr, $x_window;
  }
  # Start and end a quarter-window width below/above first/last points.
  for (my $x_left=$x_min-(0.75*$x_window);
          $x_left<$x_max-(0.25*$x_window);
          $x_left+=$x_incr) {
    my $x_center = $x_left+($x_window/2);
    #printf "%-6.2f:\n", $x_left unless $QUIET;
    # get protids within window
    my $aref = get_protids_in_window(
       $culled_sorted_calibr_protids_aref, $calibr_href,  $x_left, $x_window);
    my @window_protids = @{$aref};
    # get deviations (square of distance from trend line)
    # for each of these values
    my @deviations = ();
    for my $protid (@window_protids) {
      my $x = log10($calibr_href->{$protid}->{norm_PSM_count});
      my $y = log10($calibr_href->{$protid}->{fmol_per_ml});
      my $predicted_y = $x*$slope + $y_int;
      my $diff = $y - $predicted_y;
      my $diff_squared = $diff * $diff;
      push (@deviations, $diff_squared);
      #printf "  %s x= %-4.1f y= %-4.1f pred_y= %-4.1f diff= %5.2f sqr'd= %-4.2f\n", $protid, $x, $y, $predicted_y, $diff, $diff_squared unless $QUIET;
    }
    # compute stdev as sqrt(sum(deviations)/n-1) (if n==1, then don't
    # divide).
    my $n_vals = scalar @window_protids;
    my $variance;
    if ($n_vals == 0) {
      $variance = 0;
    } elsif ($n_vals == 1) {
      $variance = $deviations[0];
    } else {
      my $stat = Statistics::Descriptive::Full->new();
      $stat->add_data(@deviations);
      $variance = ($stat->sum() / ( $n_vals - 1 ) );
    }
    my $stdev = sqrt($variance);
    if ($stdev) {
      push (@x_values, $x_center);
      push (@stdev_values, $stdev);
      #printf " => x_center=%6.2f  stdev=%6.2f\n", $x_center, $stdev unless $QUIET;
    }
  }

  sub get_protids_in_window {
    my $sorted_protid_aref = shift;
    my $calibr_href = shift;
    my $x_left = shift;
    my $x_window = shift;
    my $x_right = $x_left + $x_window;
    my @protids_in_window = ();
    for my $protid (@{$sorted_protid_aref}) {
      my $x = log10($calibr_href->{$protid}->{norm_PSM_count});
      #print "    Checking $protid $x\n" unless $QUIET;
      if (($x >= $x_left) && ($x <= $x_right)) {
        push (@protids_in_window, $protid);
      }
    }
    return \@protids_in_window;
  }

  return (\@x_values, \@stdev_values)
}


###############################################################################
# estimate_concentrations:
#   Calculate normalized PSMs per 100K for all protids.
#   Estimate concentrations for all protein group representatives in the
#   atlas with n_obs > min_n_obs, and write them into a copy of the 
#   PeptideAtlasInput.PAprotlist file. Include uncertanty factors.
###############################################################################
sub estimate_concentrations {
  my $calibr_file = shift;
  my $protlist_file = shift;
  my $protlist_rawfile = shift;
  my $min_n_obs = shift;
  my $biosequence_attributes_href = shift;
  my $calibr_slope = shift;
  my $calibr_y_int = shift;
  my $total_PSMs = shift;
  my $uncertainties_href = shift;
  my $glyco_atlas = shift;

  print "Copying $protlist_file to $protlist_rawfile.\n" unless $QUIET;
  `cp -f -p $protlist_file $protlist_rawfile`;
  print "Calculating norm PSMs per 100K for each protid"
      unless $QUIET;
  if ($calibr_file) {
    print " and estimating conc. for each group rep. with >=4 PSMs"
	unless $QUIET;
  }
  print ", and writing to $protlist_file.\n" unless $QUIET;
  open (PROT, $protlist_rawfile) || die "Can't open $protlist_rawfile";
  open (OUT, ">$protlist_file");
  my $line = <PROT>;
  print OUT $line;
  while ($line = <PROT>) {
    chomp $line;
    my ($protein_group_number,$biosequence_names,$probability,
        $confidence,$n_observations,$n_distinct_peptides,
        $level_name,$represented_by_biosequence_name,
        $subsumed_by_biosequence_names,$estimated_ng_per_ml,
        $abundance_uncertainty,$covering,$group_size,$norm_PSMs_per_100K) =
              split (",", $line);
    $norm_PSMs_per_100K = "" if (!$norm_PSMs_per_100K);
    my @protids = split(" ",$biosequence_names);
    
    my $primary_protid = $protids[0];
    my $protseq = $biosequence_attributes{$primary_protid}->[5];
   
    my ($formatted_estimated_ng_per_ml, $formatted_abundance_uncertainty,
	  $formatted_norm_PSMs_per_100K) = '';
    # Calculate estimated concentration and normalized PSMs per 100K
    if ( ! (($primary_protid =~ /DECOY/) ||
            ($primary_protid =~ /UNMAPPED/))) {
      ($formatted_estimated_ng_per_ml,
       $formatted_abundance_uncertainty,
       $formatted_norm_PSMs_per_100K) =
				SBEAMS::PeptideAtlas::SpectralCounting::get_estimated_abundance (
					prot_name=>$primary_protid,
					PSM_count=>$n_observations,
					total_PSMs=>$total_PSMs,
					sequence=>$biosequence_attributes_href->{$primary_protid}->[5],
					abundance_conversion_slope=>$calibr_slope,
					abundance_conversion_yint=>$calibr_y_int,
					uncertainties_href=>$uncertainties_href,
					glyco_atlas=>$glyco_atlas,
				);
      $norm_PSMs_per_100K = $formatted_norm_PSMs_per_100K;
    }

    # If we had a set of calibration values, and
    # if this is a protein group representative, and not a decoy
    # or unmapped protein, and if it has the minimum number of
    # observations ... and, if this is a glyco atlas, the protseq
    # has NXS/T motif ... record the newly estimated concentration.
    if ($calibr_file &&
        #($primary_protid eq $represented_by_biosequence_name) &&
        ($primary_protid && $level_name !~ /insufficient|weak|subsumed/) && 
        (! (($primary_protid =~ /DECOY/) ||
            ($primary_protid =~ /UNMAPPED/))) &&
        ($n_observations >= $min_n_obs) &&
        (!$glyco_atlas || 
				SBEAMS::PeptideAtlas::SpectralCounting::hasGlycoSite(
					seq=>$protseq,
					next_aa=>'A')
				)) {
      $estimated_ng_per_ml = $formatted_estimated_ng_per_ml;
      $abundance_uncertainty = $formatted_abundance_uncertainty;
    } 

    # Create the output line with the new norm_PSMs_per_100K, plus
    # the estimated concentration and abundance certainty if
    # appropriate.
    $line = join(",",
      $protein_group_number,$biosequence_names,$probability,
      $confidence,$n_observations,$n_distinct_peptides,
      $level_name,$represented_by_biosequence_name,
      $subsumed_by_biosequence_names,$estimated_ng_per_ml,
      $abundance_uncertainty,$covering,$group_size,$norm_PSMs_per_100K);
    print OUT "$line\n";
  }
  close (OUT);
  close (PROT);
}



###############################################################################
# transform_x_y: given x & y, compute the corresponding pixel on the
#   plot window
###############################################################################
sub transform_x_y {
  my $x = shift;
  my $y = shift;
  my $origin = shift;
  my $winwidth = shift;
  my $factor = shift;
  my $min_xy = shift;

  $x = $origin + ($x-$min_xy) * $factor;
  $y = $origin + ($y-$min_xy) * $factor;
  $y = $winwidth - $y;

  return ($x, $y);
}

###############################################################################
# draw_trend_line: given slope & y-intercept, draw line within
#   plot window
###############################################################################
sub draw_trend_line {
  my $min_xy = shift;
  my $max_xy = shift;
  my $slope = shift;
  my $y_int = shift;
  my $origin = shift;
  my $winwidth = shift;
  my $factor = shift;
  my $img = shift;
  my $color = shift;

  my $x = $min_xy; my $y = $x*$slope + $y_int;
  if ($y < $min_xy) {
    $y = $min_xy; $x = ( $y - $y_int ) / $slope;
  }
  ($x, $y) = transform_x_y($x, $y, $origin, $winwidth, $factor, $min_xy);
  $img->moveTo($x, $y);
  $x = $max_xy; $y = $x*$slope + $y_int;
  if ($y > $max_xy) {
    $y = $max_xy; $x = ( $y - $y_int ) / $slope;
  }
  ($x, $y) = transform_x_y($x, $y, $origin, $winwidth, $factor, $min_xy);
  $img->fgcolor($color);
  $img->lineTo($x, $y);
}
