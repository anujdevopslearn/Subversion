#!/usr/local/bin/perl

###############################################################################
# Program      : compare_SwissProt_idents_across_builds.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Compile the normalized observation counts for all Swiss-Prot identifiers
#  in a set of atlas builds and output in a spreadsheet.
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use Statistics::Regression;
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
use SBEAMS::PeptideAtlas::ProtInfo;

## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
my $prot_info = new SBEAMS::PeptideAtlas::ProtInfo;
$prot_info->setSBEAMS($sbeams);

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ( $current_username = $sbeams->Authenticate(
    allow_anonymous_access => 1,
  ));


$current_contact_id = $sbeams->getCurrent_contact_id;
# This is returning 1, but prev SEL_run records used 40.
$current_work_group_id = $sbeams->getCurrent_work_group_id;
$current_work_group_id = 40;

###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
                              When nonzero, waits for user confirm at each step.
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --atlas_build_ids           Comma-separated list. One of these 2 options required.
  --atlas_build_dirs          Comma-separated list, such as
			  HumanKidney_2013-05,HumanUrine_2013-05,HumanPlasma_2013-06
  --names                     Comma-separated list of names corresponding to builds.
  --min_NSC                   Minimum NSC to count as "observed" (default 0.0000001
                                   effectively disables this option)
  --log_ratio_thresholds      For 3 atlases, log10 ratio thresholds for >> to hold.
                                Comma-separated for atlas pairs 12,13,21,23,31,32
  --list_files                Generate lists of identifiers for each comparison
  --create_universe           Make list of idents seen in any atlas for GO anal
  --complete_mapping          Use complete mapping for all builds when making
                                comparisons, instead of using NR set for first build


 e.g.:  $PROG_NAME --atlas_build_ids 262,234,248 --names urine,plasma,kidney
EOU

####
#### Process options
####


unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
         "atlas_build_ids=s","atlas_build_dirs=s","min_NSC=f",
	 "log_ratio_thresholds=s", "names=s","list_files",
	 "create_universe:s","complete_mapping",
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

my @atlas_build_ids = split(",", $OPTIONS{"atlas_build_ids"});
my @atlas_build_dirs = split(",", $OPTIONS{"atlas_build_dirs"});
if (! (@atlas_build_ids || @atlas_build_dirs)) {
  print "ERROR: comma-separated list of atlas_build_ids or atlas_build_dirs required.\n";
  print $USAGE;
  exit;
}
if (@atlas_build_ids && @atlas_build_dirs) {
  print "ERROR: only one of --atlas_build_ids or --atlas_build_dirs allowed.\n";
  print $USAGE;
  exit;
}

my $real_atlas_ids_provided=0;
my $n_atlases;
my %data_path;
if (@atlas_build_dirs) {
  $n_atlases = scalar @atlas_build_dirs;
  # Make fake atlas_build_ids numbered 1..N
  for (my $i=0; $i<$n_atlases; $i++) {
    my $atlas_build_id = $i+1;
    $atlas_build_ids[$i]=$atlas_build_id;
    my $atlas_build_dir = $atlas_build_dirs[$i];
    $atlas_build_dir =~ s/\s//g;  #remove any whitespace
    $data_path{$atlas_build_id} = "$atlas_build_dir/DATA_FILES";
  }
  $real_atlas_ids_provided=0;
} else {
  $real_atlas_ids_provided=1;
  $n_atlases = scalar @atlas_build_ids;
  # Get the data location for each atlas build ID
  for my $atlas_build_id (@atlas_build_ids) {
    $atlas_build_id =~ s/\s//g;  #remove all whitespace
    my $query = qq~
      SELECT data_path
      FROM $TBAT_ATLAS_BUILD
      WHERE atlas_build_id = '$atlas_build_id';
    ~;
    my ($data_path) = $sbeams->selectOneColumn($query);
    if (! $data_path) {
      print "No data_path for atlas_build $atlas_build_id, or build doesn't exist.\n";
      exit;
    } else {
      print "$atlas_build_id $data_path\n" if $VERBOSE;
      $data_path{$atlas_build_id} = $data_path;
    }
  }
}

my @atlas_names = split(",", $OPTIONS{"names"});
if (scalar @atlas_names != scalar @atlas_build_ids) {
  @atlas_names = @atlas_build_ids;
}

# Create a (possibly customized) minimum concentration per atlas
my $min_NSC = $OPTIONS{'min_NSC'} || 0.0000001;
my @min_NSC;
for (my $i=0; $i<$n_atlases; $i++) {
    $min_NSC[$i] = $min_NSC;
}

my $list_files = $OPTIONS{'list_files'};
my $use_complete_mapping = defined $OPTIONS{'complete_mapping'};
my $create_universe = defined $OPTIONS{'create_universe'};
my $universe_filename = $OPTIONS{'create_universe'} ||
  '/users/tfarrah/FourAtlases/swiss_in_any_KUP_atlas.acc';
my $ratio_threshold = 1000;
my $log_ratio_thresholds = $OPTIONS{'log_ratio_thresholds'} || '';
my @log_ratio_thresholds;
if ($log_ratio_thresholds) {
  @log_ratio_thresholds = split(",",$log_ratio_thresholds);
  my $n = scalar @log_ratio_thresholds;
  die "ERROR: $n log ratio thresholds given; need 6" if ($n != 6);
  for my $t (@log_ratio_thresholds) {
    die "ERROR: log ratio $t is not a number"
       if (! $t =~ m|^[0-9,".","-"]+$|);
  }
}



# proteins with no obs (norm_PSMs_per_100k == 0)
# are considered to have the value of almost_zero instead of zero
# for purposes of taking ratios
# 07/10/13
my @almost_zero;   #atlas-specific almost_zero value



###############################################################################
###
### Get the norm_obs_per_100k for each  Swiss-Prot identifier for each build.
### Get the nonredundant Swiss-Prot identifiers for each build
### Also get the max norm_obs_per_100k for all variants of each SwissProt entry.
###
###############################################################################
my $i = 0;
my @nr_sprot_hrefs;
my %conc;
for my $atlas_build_id (@atlas_build_ids) {
  $almost_zero[$i] = 1000;   #07/10/13
  my $PAprotIdentlist_file = "/net/db/projects/PeptideAtlas/pipeline/output/$data_path{$atlas_build_id}/PeptideAtlasInput.PAprotIdentlist";

  # First, get a low-redundancy list of SwissProt identifiers--those that are:
  # - canonical or possibly distinguished, OR
  # - subsumed/ntt-subsumed by a non-SwissProt
  # In cases where multiple SwissProt are subsumed by the same non-SwissProt,
  #  select only the strongest one.
  my $swiss_idents_in_build = $prot_info->get_swiss_idents_in_build(
    atlas_build_id=>$atlas_build_id,
  );

  $nr_sprot_hrefs[$i] = {};
  my %subsuming_idents = ();
  open(my $infh, $PAprotIdentlist_file) || die "Can't open $PAprotIdentlist_file for reading.\n";
  <$infh>;  #throw away header line
  while (<$infh>) {
    chomp;
    my @fields = split(",",$_);
    my $ident = $fields[1];
    my $npeps = $fields[5];
    my $level = $fields[6];
    my $ref = $fields[8];  # subsuming protein, if any
    if ( is_sprot ($ident, $swiss_idents_in_build) ) {
      if (($level =~ m|canonical|) ||
	  ($level =~ m|possibly_distinguished| )) {
	$nr_sprot_hrefs[$i]->{$ident}->{level} = $level;
	$nr_sprot_hrefs[$i]->{$ident}->{npeps} = $npeps;
      } elsif ( ! is_sprot($ref, $swiss_idents_in_build))  {
	$nr_sprot_hrefs[$i]->{$ident}->{level} = $level;
	$nr_sprot_hrefs[$i]->{$ident}->{npeps} = $npeps;
	$nr_sprot_hrefs[$i]->{$ident}->{ref} = $ref;
	push (@{$subsuming_idents{$ref}}, $ident);
      } else {
	#print "$ident $level $ref\n";
      }
    }
  }
  close $infh;

  # For each subsuming ident, pick the subsumed that (a) is
  # ntt-subsumed, or, if none, (b) the one with the most peps.
  # Delete the rest.
  for my $subsuming (keys %subsuming_idents) {
    #print "$subsuming is subsuming\n";
    my $selected_subsumed;
    my $selected_is_ntt_subsumed = 0;
    my $max_peps = 0;
    for my $subsumed (@{$subsuming_idents{$subsuming}}) {
      my $npeps = $nr_sprot_hrefs[$i]->{$subsumed}->{npeps};
      #print "  $subsumed $npeps\n";
      if ($nr_sprot_hrefs[$i]->{$subsumed}->{level} eq 'ntt-subsumed') {
	if ($npeps > $max_peps) {
	  $selected_subsumed = $subsumed;
	  $max_peps = $npeps;
	  $selected_is_ntt_subsumed = 1;
	  #print "   ... is ntt-subsumed  and becomes selected.\n";
	}
      } elsif (($npeps > $max_peps) && !$selected_is_ntt_subsumed) {
	$selected_subsumed = $subsumed;
	$max_peps = $npeps;
	#print "   ... with $npeps, becomes selected.\n";
      }
    }
    for my $subsumed (@{$subsuming_idents{$subsuming}}) {
      delete $nr_sprot_hrefs[$i]->{$subsumed}
	 unless $subsumed eq $selected_subsumed;
    }
  }

  # Add the "-all" version of each ident to the non-redundant list
  for my $ident (keys %{$nr_sprot_hrefs[$i]}) {
    $ident =~ /^(......)/;
    my $all_ident = $1 . "-all";
    $nr_sprot_hrefs[$i]->{$all_ident}->{level} = 'all';
  }

  # Now, get the infos on each protein.
  my $PAprotlist_file = "/net/db/projects/PeptideAtlas/pipeline/output/$data_path{$atlas_build_id}/PeptideAtlasInput.PAprotlist";
  #print $PAprotlist_file, "\n";
  open(my $infh, $PAprotlist_file) || die "Can't open $PAprotlist_file for reading.\n";
  <$infh>;  #throw away header line
  my $count = 0;
  while (my $line = <$infh>) {
    #print $line;
    chomp $line;
    my @fields = split (",", $line);
    my $idents = $fields[1];
    my $conc = $fields[12];
    $almost_zero[$i] = $conc   #07/10/13
       if ($conc > 0) && ( $conc < $almost_zero[$i] );
    #print "$conc\n";
    #$count++; last if $count > 10;
    my @idents = split ( /\s+/ , $idents );
    #for my $id (@idents) { print "$id "; } print "\n";
    for my $ident (@idents) {
      #if (defined $swiss_prot_href->{$ident}) 
      #if (defined $nr_sprot_hrefs[$atlas_build_id]->{$ident}) 
      if (is_sprot($ident, $swiss_idents_in_build)) {
        #print $ident, "\n";
        my $canonical_ident = substr($ident, 0, 6); #strip to 6 chars
	$conc{$ident}->[$i] = $conc;
        my $inclusive_ident = $canonical_ident . "-all";
        my $prev_inclusive_conc = $conc{$inclusive_ident}->[$i];
        if (defined $prev_inclusive_conc) {
          $conc{$inclusive_ident}->[$i] = $conc if $conc > $prev_inclusive_conc;
        } else {
          $conc{$inclusive_ident}->[$i] = $conc;
        }
      }
    }
  }
  $almost_zero[$i] /= 2;  # set to half smallest NSC in build   #07/10/13
  printf STDERR "almost_zero $i = %0.6f\n", $almost_zero[$i];
  close $infh;
  $i++;
}


###############################################################################
###
### Make some identifier lists using set operations and NSC comparisons.
###
###############################################################################

my %seen_above_threshold;  # the default threshold is effectively zero.
my %seen;
my %universe;
my %log_ratio;

if (0) { # debug
  for (my $i = 0; $i<3; $i++) {
    my $count=0;
    for my $key (keys %{$nr_sprot_hrefs[$i]}) {
      print "$i |$key|\n";
      $count++;
    }
    print "$count total\n";
  }
}


# What's seen in each build? in any build?
for my $ident (keys %conc) {
  my $seen_in_any = 0;
  my $seen_above_threshold_in_any = 0;
  for (my $i=0; $i<$n_atlases; $i++) {
    if ($conc{$ident}->[$i] > 0) {
      $seen{$ident}->{$atlas_names[$i]} = 1;
      $seen_in_any = 1;
      if ($conc{$ident}->[$i] >= $min_NSC[$i]) {
	$seen_above_threshold{$ident}->{$atlas_names[$i]} = 1;
	$seen_above_threshold_in_any = 1;
      }
    }
  }
  $seen{$ident}->{'seen_in_any'} = $seen_in_any;
  $seen_above_threshold{$ident}->{'seen_above_threshold_in_any'}
     = $seen_above_threshold_in_any;
}

# If exactly 3 builds: perform some comparisons.
# Simultaneously, create an appropriate enrichment universe
# for each comparison.
my @comparisons = ();
my @main_build_in_comparison = ();
if ($n_atlases == 3) {

  # What's seen in all builds? For each, get avg. norm_PSMs_per_100k
  # Universe = seen in any build
  my $c = 'seen in all';
  push @comparisons, $c;
  push @main_build_in_comparison, 0;
  for my $ident (keys %conc) {
    if (($use_complete_mapping ||
	 defined $nr_sprot_hrefs[0]->{$ident} ) &&
        (($conc{$ident}->[0] >= $min_NSC[0]) &&
	 ($conc{$ident}->[1] >= $min_NSC[1]) &&
	 ($conc{$ident}->[2] >= $min_NSC[2]))) {
       #print "$ident: seen! nr_sprot_hrefs = $nr_sprot_hrefs[0]->{$ident}->{level}\n";
      $seen_above_threshold{$ident}->{$c} = average($conc{$ident});
    } else {
      #print "$ident: not seen. nr_sprot_hrefs = $nr_sprot_hrefs[0]->{$ident}->{level}\n";
      $seen_above_threshold{$ident}->{$c} = 0;
    }
    $universe{$ident}->{$c} =
     (($conc{$ident}->[0] >= $min_NSC[0]) ||
      ($conc{$ident}->[1] >= $min_NSC[1]) ||
      ($conc{$ident}->[2] >= $min_NSC[2])) ;
  }

  # For each build pair, which prots seen in both builds?
  # Again, for each prot, get avg. value
  # Universe = seen in either build
  for my $pair_aref ( [0,1], [0,2], [1,2]) {
    my $i = $pair_aref->[0];
    my $j = $pair_aref->[1];
    my $c = "$atlas_names[$i] AND $atlas_names[$j]";
    push @comparisons, $c;
    push @main_build_in_comparison, $i;
    for my $ident (keys %conc) {
      if (($use_complete_mapping ||
	   defined $nr_sprot_hrefs[$i]->{$ident} ) &&
          (($conc{$ident}->[$i] >= $min_NSC[$i]) &&
	   ($conc{$ident}->[$j] >= $min_NSC[$j]))) {
	$seen_above_threshold{$ident}->{$c} = average([$conc{$ident}->[$i],
	  $conc{$ident}->[$j]]);
	$log_ratio{$c}->{$ident} =
	  log10($conc{$ident}->[$i]/$conc{$ident}->[$j]);
      } else {
	$seen_above_threshold{$ident}->{$c} = 0;
      }
      $universe{$ident}->{$c} =
       (($conc{$ident}->[$i] >= $min_NSC[$i]) ||
	($conc{$ident}->[$j] >= $min_NSC[$j])) ;
    }
  }
  # For each build pair, which prots seen in first but not second?
  # Universe = seen in first build
  # 07/10/13
  for my $pair_aref ( [0,1], [0,2], [1,0], [1,2], [2,0], [2,1],) {
    my $i = $pair_aref->[0];
    my $j = $pair_aref->[1];
    my $c = "$atlas_names[$i] NOT $atlas_names[$j]";
    push @comparisons, $c;
    push @main_build_in_comparison, $i;
    for my $ident (keys %conc) {
      if (($use_complete_mapping ||
	   defined $nr_sprot_hrefs[$i]->{$ident} ) &&
          (($conc{$ident}->[$i] > 0) &&
	   ($conc{$ident}->[$j] == 0))) {
	$seen_above_threshold {$ident}->{$c} = "x";
      } else {
	$seen_above_threshold{$ident}->{$c} = "";
      }
      $universe{$ident}->{$c} = ($conc{$ident}->[$i] > 0);
    }
  }
  # For each build pair, which prots seen in first much more than second?
  # For each prot, get ratio.
  # Universe = seen in first build
  my @th;
  for my $pair_aref ( [0,1], [0,2], [1,0], [1,2], [2,0], [2,1],) {
    my $i = $pair_aref->[0];
    my $j = $pair_aref->[1];
    my $c = "$atlas_names[$i] >> $atlas_names[$j]";
    $ratio_threshold = 10 ** (shift @log_ratio_thresholds)
       if ($log_ratio_thresholds);
    $th[$i]->[$j] = $ratio_threshold;
    print STDERR "$c $ratio_threshold\n";
    push @comparisons, $c;
    push @main_build_in_comparison, $i;
    for my $ident (keys %conc) {
      my $ratio = ($conc{$ident}->[$j] != 0) ?
                  $conc{$ident}->[$i] / $conc{$ident}->[$j] : 
                  $conc{$ident}->[$i] / $almost_zero[$j] ;
      if (($use_complete_mapping ||
	   defined $nr_sprot_hrefs[$i]->{$ident} ) &&
          $ratio >= $ratio_threshold) {
	$seen_above_threshold {$ident}->{$c} = $ratio;
      } else {
	$seen_above_threshold{$ident}->{$c} = 0;
      }
      $universe{$ident}->{$c} =
       ($conc{$ident}->[$i] >= $min_NSC[$i]);
    }
  }

  # For each build triplet, which prots seen in two but not in third?
  # Universe = seen in either of first 2 builds (any NSC)
  # 07/10/13
  for my $triplet_aref ( [0,1,2], [1,2,0], [2,0,1],) {
    my $i = $triplet_aref->[0];
    my $j = $triplet_aref->[1];
    my $k = $triplet_aref->[2];
    my $c = "$atlas_names[$i] AND $atlas_names[$j] NOT $atlas_names[$k]";
    push @comparisons, $c;
    push @main_build_in_comparison, $i;
    for my $ident (keys %conc) {
      if (($use_complete_mapping ||
	   defined $nr_sprot_hrefs[$i]->{$ident} ) &&
          (($conc{$ident}->[$i] > 0) &&
	   ($conc{$ident}->[$j] > 0) &&
           ($conc{$ident}->[$k] == 0))) {
        $seen_above_threshold{$ident}->{$c} = "x"
      } else {
	$seen_above_threshold{$ident}->{$c} = "";
      }
      $universe{$ident}->{$c} =
       (($conc{$ident}->[$i] > 0) || ($conc{$ident}->[$j] > 0));
    }
    # Seen in one but not in the other two?
    # Universe = seen in first build (any NSC)
    # 07/10/13
    my $c = "$atlas_names[$i] NOT $atlas_names[$j] NOT $atlas_names[$k]";
    push @comparisons, $c;
    push @main_build_in_comparison, $i;
    for my $ident (keys %conc) {
      my $avg_of_two = average([$conc{$ident}->[$j], $conc{$ident}->[$k]]);
      if (($use_complete_mapping ||
	   defined $nr_sprot_hrefs[$i]->{$ident} ) &&
          (($conc{$ident}->[$i] > 0 ) &&
	   ($conc{$ident}->[$j] == 0 ) &&
	   ($conc{$ident}->[$k] == 0 ))) {
        $seen_above_threshold{$ident}->{$c} = "x";
      } else {
	$seen_above_threshold{$ident}->{$c} = "";
      }
      $universe{$ident}->{$c} = ($conc{$ident}->[$i] > 0 );
    }
  }
  # For each build triplet, which prots seen in two much more than the other?
  # Get avg. of the two and divide by the third.
  # Universe = seen in either of first 2 builds above NSC threshold
  for my $triplet_aref ( [0,1,2], [1,2,0], [2,0,1],) {
    my $i = $triplet_aref->[0];
    my $j = $triplet_aref->[1];
    my $k = $triplet_aref->[2];
    my $c = "$atlas_names[$i] AND $atlas_names[$j] >> $atlas_names[$k]";
    push @comparisons, $c;
    push @main_build_in_comparison, $i;
    for my $ident (keys %conc) {
      my $avg_of_two = average([$conc{$ident}->[$i], $conc{$ident}->[$j]]);
      my $ratio = ($conc{$ident}->[$k] != 0) ?
                 $avg_of_two / $conc{$ident}->[$k] :
                 $avg_of_two / $almost_zero[$k];
      if (($use_complete_mapping ||
	   defined $nr_sprot_hrefs[$i]->{$ident} ) &&
          (($conc{$ident}->[$i] >   # >= would test true when both are zero.
	    ($conc{$ident}->[$k] || $almost_zero[$k]) * $th[$i]->[$k]) &&
	   ($conc{$ident}->[$j] > 
	    ($conc{$ident}->[$k] || $almost_zero[$k]) * $th[$j]->[$k]) &&
           ($conc{$ident}->[$i] >= $min_NSC[$i]) &&
           ($conc{$ident}->[$j] >= $min_NSC[$j]))) {
        $seen_above_threshold{$ident}->{$c} = $ratio;
      } else {
	$seen_above_threshold{$ident}->{$c} = 0;
      }
      $universe{$ident}->{$c} =
       (($conc{$ident}->[$i] >= $min_NSC[$i]) ||
	($conc{$ident}->[$j] >= $min_NSC[$j])) ;
    }
    # Seen in one much more than the other two?
    # Get ratio between first and avg of other two.
    # Universe = seen in first build above NSC threshold.
    my $c = "$atlas_names[$i] >> $atlas_names[$j] AND $atlas_names[$k]";
    push @comparisons, $c;
    push @main_build_in_comparison, $i;
    for my $ident (keys %conc) {
      my $avg_of_two = average([
	               ($conc{$ident}->[$j] || $almost_zero[$j]),
		       ($conc{$ident}->[$k] || $almost_zero[$k])
		       ]);
      my $ratio = $conc{$ident}->[$i] / $avg_of_two;
      if (($use_complete_mapping ||
	   defined $nr_sprot_hrefs[$i]->{$ident} ) &&
          (($conc{$ident}->[$i] > 
	    ($conc{$ident}->[$j] || $almost_zero[$j]) * $th[$i]->[$j]) &&
	   ($conc{$ident}->[$i] > 
	    ($conc{$ident}->[$k] || $almost_zero[$k]) * $th[$i]->[$k]) &&
           ($conc{$ident}->[$i] >= $min_NSC[$i] ))) {
        $seen_above_threshold{$ident}->{$c} = $ratio;
      } else {
	$seen_above_threshold{$ident}->{$c} = 0;
      }
      $universe{$ident}->{$c} =
       ($conc{$ident}->[$i] >= $min_NSC[$i]);
    }
  }
}

###############################################################################
###
### Calculate the mean, SD for the NSC log ratios for each atlas pair
###
###############################################################################
for my $pair_aref ( [0,1], [0,2], [1,2]) {
  my $i = $pair_aref->[0];
  my $j = $pair_aref->[1];
  my $c = "$atlas_names[$i] AND $atlas_names[$j]";
  # Find a linear function that fits the log(NSC) values for this atlas pair
  # Create regression object
  my $reg=Statistics::Regression->new(
     "$c", ["Intercept", "Slope"]
     );
  # Add data points
  my @idents = keys %{$log_ratio{$c}};
  for my $ident (@idents) {
    $reg->include(log10($conc{$ident}->[$i]),
            [1.0, log10($conc{$ident}->[$j])])
      if $ident =~ m|-all|;
  }
  my @theta = $reg->theta();
  my ($intercept, $slope) = @theta;
  #my @se = $reg->standarderrors();
  #my $rsq = $reg->rsq();
  #$reg->print;

  print STDERR "$c intercept = $intercept   slope = $slope\n";

 
#--------------------------------------------------
#   my @ratios = values %{$log_ratio{$c}};
#   my $mean = average(\@ratios);
#   my $sd = stdev(\@ratios);
#   print STDERR "$c $mean $sd\n";
#-------------------------------------------------- 
}


###############################################################################
###
### Create massive .tsv file with NSC and set memberships for each ID'd protein
### Print header field while storing infos in hash, then print hash.
###
###############################################################################

# First, get protein descriptions
print STDERR "Getting descriptions ... ";
my $ident_string =  join ("','" , keys %conc);
$ident_string = "'" . $ident_string . "'";
my $query = qq~
  SELECT biosequence_name, biosequence_desc
  FROM $TBAT_BIOSEQUENCE
  WHERE biosequence_name in ($ident_string)
~;
my @rows = $sbeams->selectSeveralColumns($query);
print STDERR "Storing descriptions in hash ... ";
my %desc;
for my $row_aref (@rows) {
  my $description = $row_aref->[1];
  # Groom the description
  if ($description =~ /_HUMAN (.+) OS=Homo sapiens GN=/) {
    $description = $1;
  } elsif ($description =~ /DE=(.+)$/) {
    $description = $1;
  } elsif ($description =~ /ID=(.+) MODRES=/) {
    $description = $1;
  }
  $desc{$row_aref->[0]} = $description;
}
print STDERR "Done.\n";

print "identifier\tdescription\t";
for (my $i = 0; $i < $n_atlases; $i++) {
  print "$atlas_names[$i]_c\t$atlas_names[$i]_nr\t";
}
for my $c (@comparisons) {
  print "$c\t";
}
print "\n";

# Print the infos on each identifier into the .tsv file.
# Count a few things in the process.
my @nonzero;
my @threshold_count;
my @all_sum;
my @thresholds = (0.5, 1, 3, 5, 10, 20, 50);
my %pass_threshold;
for my $ident (sort keys %conc) {
  my $column = 0;
  my $stripped_ident = $ident;
  $stripped_ident =~ s/-all//;
  # Print identifier and description
  print "$ident\t$desc{$stripped_ident}\t";
  $column += 2;

  my $i = 0;
  # Print NSC, and whether member of nonredundant list, for each atlas
  for (my $i = 0; $i < $n_atlases; $i++) {
    my $conc = $conc{$ident}->[$i];
    my $format;
    if ($conc >= 0.003) {
      $format = "%0.3f";
    } elsif ($conc >= 0.0003) {
      $format = "%0.4f";
    } elsif ($conc >= 0.00003) {
      $format = "%0.5f";
    } elsif ($conc >= 0.000003) {
      $format = "%0.6f";
    } else {
      $format = "%0.3f";
    }

    printf "$format\t", $conc;
    print (defined $nr_sprot_hrefs[$i]->{$ident} ? "X\t" : "\t");
    
    $nonzero[$column]++ if $conc;
    $all_sum[$column]+= $conc if $ident =~ /-all/;
    for my $threshold (@thresholds) {
      $pass_threshold{$threshold}->[$column]++ if $conc >= $threshold;
    }
    $column++;
  }

  # For each set, print info for this protein.
  # In some cases, either X (member) or blank (not member).
  # In other cases, an NSC average value or ratio.
  for my $c (@comparisons) {
    print "$seen_above_threshold{$ident}->{$c}\t";
    $nonzero[$column]++ if $seen_above_threshold{$ident}->{$c};
    $column++;
  }

  # That's all!
  print "\n";
}



# Create some auxiliary files for each of the individual atlases
# and the various comparisons:
# -- identifer lists (.acc)
# -- non-redundant identifier lists (_nr.acc)
# -- universe files (.universe) for GO analysis
# -- HTML file of idenfiers with descriptions, abundances, and hotlinks to uniprot, 
# 
if ($list_files) {
  for ($i=0; $i<$n_atlases; $i++) {
#--------------------------------------------------
### This code was to create a list of all accessions seen in
###   an atlas, not just those passing the min_NSC threshold.
###   But now, 07/10/13, we are (effectively) not using the min_NSC
###   threshold.
#     my $acc_file = $atlas_names[$i] . "_all.acc";
#     open (my $allfh, ">$acc_file");
#-------------------------------------------------- 
    my $nr_file = $atlas_names[$i] . "_nr.acc";
    open (my $nrfh, ">$nr_file") || die "Can't open $nr_file for writing";
    for my $ident (keys %{$nr_sprot_hrefs[$i]}) {
      print $nrfh "$ident\n" if ($ident !~ /-all$/);
    }
    close $nrfh;
    my $acc_above_threshold_file = $atlas_names[$i] . ".acc";
    open (my $accfh, ">$acc_above_threshold_file") || die "Can't open $acc_above_threshold_file for writing";
    my $uni_file = $atlas_names[$i] . ".universe";
    open (my $unifh, ">$uni_file") || die "Can't open $uni_file for writing";
    my $html_file = $atlas_names[$i] . ".html";
    open (my $htmlfh, ">$html_file") || die "Can't open $html_file for writing";
    print $htmlfh "<html>\n<h3>2013 HKUP analysis: Identifiers belonging to $atlas_names[$i]</h3>\n<body>\n<table>\n";
    print $htmlfh "<tr><td>Identifier</td>\n";
    for (my $k=0; $k<3; $k++) {
      print $htmlfh "<td>$atlas_names[$k]</td>";
    }
    print $htmlfh "<td>Description; link to Uniprot</td></tr>\n";
#--------------------------------------------------
#     for my $ident (sort keys %seen) {   
#       if ($ident !~ /-all/) {
# 	print $allfh "$ident\n" if $seen{$ident}->{$atlas_names[$i]};
#       }
#     }
#-------------------------------------------------- 
    for my $ident (sort keys %seen_above_threshold) {   
      if ($ident =~ /(.*)-all/) {
	my $base_ident = $1;
	print $accfh "$base_ident\n" if $seen_above_threshold{$ident}->{$atlas_names[$i]};
	print $unifh "$base_ident\n" if $seen_above_threshold{$ident}->{'seen_above_threshold_in_any'};
      }
    }
    # sort by decreasing concentration in atlas
    for my $ident (sort {$conc{$b}->[$i] <=> $conc{$a}->[$i]} keys %seen_above_threshold) {   
      if ($ident =~ /(.*)-all/) {
	my $base_ident = $1;
	if ($seen_above_threshold{$ident}->{$atlas_names[$i]}) {
	  print $htmlfh "<tr><td>$base_ident</td>";
	  for (my $j=0; $j<$n_atlases; $j++) {
	    print $htmlfh "<td>$conc{$ident}->[$j]</td>";
	  }
	  print $htmlfh "<td><a href=\"http://www.uniprot.org/uniprot/$base_ident\">$desc{$base_ident}</a></td>";
	  print $htmlfh "</tr>\n";
	}
      }
    }
#--------------------------------------------------
#     close $allfh;
#-------------------------------------------------- 
    close $accfh;
    close $unifh;
    print $htmlfh "</table>\n</body>\n</html>\n";
    close $htmlfh;
  }
  for my $c (@comparisons) {
    my $main_build = shift @main_build_in_comparison;
    my $base_file = $c;
    # 07/10/13
    $base_file =~ s/ >> /ENRICHED_OVER/g;
    $base_file =~ s/\s//g;
    my $acc_file = $base_file . ".acc";
    open (my $accfh, ">$acc_file") || die "Can't open $acc_file for writing.";
    my $uni_file = $base_file . ".universe";
    open (my $unifh, ">$uni_file") || die "Can't open $uni_file for writing.";
    my $html_file = $base_file . ".html";
    open (my $htmlfh, ">$html_file") || die "Can't open $html_file for writing.";
    print $htmlfh "<html>\n<h3>2013 HKUP analysis: Identifiers belonging to $c</h3>\n<body>\n<table>\n";
    print $htmlfh "<tr><td>Identifier</td>\n";
    for (my $k=0; $k<3; $k++) {
      print $htmlfh "<td>$atlas_names[$k]</td>";
    }
    print $htmlfh "<td>Description; link to Uniprot</td></tr>\n";
    for my $ident (sort keys %seen_above_threshold) {   
      if ($ident =~ /(.*)-all/) {
	my $base_ident = $1;
	print $accfh "$base_ident\n" if $seen_above_threshold{$ident}->{$c};
	print $unifh "$base_ident\n" if $universe{$ident}->{$c};
      }
    }
    # sort by decreasing concentration in first atlas
    for my $ident (sort {$conc{$b}->[$main_build] <=> $conc{$a}->[$main_build]} keys %seen_above_threshold) {   
      if ($ident =~ /(.*)-all/) {
	my $base_ident = $1;
	if ($seen_above_threshold{$ident}->{$c}) {
	  print $htmlfh "<tr><td>$base_ident</td>";
	  for (my $j=0; $j<$n_atlases; $j++) {
	    print $htmlfh "<td>$conc{$ident}->[$j]</td>";
	  }
	  print $htmlfh "<td><a href=\"http://www.uniprot.org/uniprot/$base_ident\">$desc{$base_ident}</a></td>";
	  print $htmlfh "</tr>\n";
	}
      }
    }
    close $accfh;
    close $unifh;
    print $htmlfh "</table>\n</body>\n</html>\n";
    close $htmlfh;
  }
}

# Create a list of identifiers seen in any atlas.
# Can be used as an all-purpose universe for GO analysis.
# (The universes for each individual atlas, already created above,
#  should be identical to this one, just with different filenames.)
if ($create_universe) {
  open(my $outfh, ">$universe_filename") ||
    die "Can't open $universe_filename for writing.";
  for my $ident (sort keys %seen_above_threshold) {   
    if ($ident =~ /(.*)-all/) {
      my $base_ident = $1;
      print $outfh "$base_ident\n" if $seen_above_threshold{$ident}->{'seen_above_threshold_in_any'};
    }
  }
  close $outfh;
}

######################################################
###
### Print some informational lines into the .tsv file
###
######################################################

# Sums of non-zero entries in each column
print "\n";
print "Non-zero values\t\t";
my $i=0;
for my $count (@nonzero) {
  $i++;
  if ($i >= $n_atlases) {
    print "$count";
    print "\t" if $i < scalar @nonzero;
  }
}
print "\n";


# For each atlas, what is the sum of the values for the -all identifiers?
# Should be about 100K. May wish to normalize to this value.
print "sum for ______-all identifiers\t\t";
my $i=0;
for my $sum (@all_sum) {
  $i++;
  if ($i >= $n_atlases) {
    printf "%d", int($sum);
    print "\t" if $i < scalar @all_sum;
  }
}
print "\n";

# For each atlas, how many values are >0.5, 1, 3, 5, 10, 20, 50?
# Allows one to select a reasonable threshold to answer the question
# "is this protein present in this sample?" in a way that is fair
# across atlases, given that some atlases are deeper than others.
# Want to select a threshold where the tally is approximately the
# same for subproteomes of similar protein-richness (hard to determine)
for my $threshold (@thresholds) {
  printf "n_values >= %0.1f\t\t", $threshold;
  my $i=0;
  for my $count (@{$pass_threshold{$threshold}}) {
    $i++;
    if ($i >= $n_atlases) {
      printf "$count";
      print "\t" if $i < scalar @all_sum;
    }
  }
print "\n";
}


#############
# average
#############
sub average{
  my $aref = shift;
  my @array = @{$aref};
  my $n = scalar @array;
  my $sum = 0;
  for my $x (@array) {
    $sum += $x;
  }
  return ${sum}/$n;
}

########
# stdev
# from http://edwards.sdsu.edu/labsite/index.php/kate/302-calculating-the-average-and-standard-deviation
########
sub stdev{
  my($data) = @_;
  if(@$data == 1){
    return 0;
  }
  my $average = &average($data);
  my $sqtotal = 0;
  foreach(@$data) {
    $sqtotal += ($average-$_) ** 2;
  }
  my $std = ($sqtotal / (@$data-1)) ** 0.5;
  return $std;
}

#######
# log10
#######
sub log10 {
  my $n = shift;
  return log($n)/log(10);
}

#############
# is_sprot
#############
sub is_sprot {
  my $ident = shift;
  my $swiss_idents_href = shift;
  return ($swiss_idents_href->{$ident});
}

