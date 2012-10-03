#! /usr/local/bin/perl -w
# Input: atlas build directory; biosequence set flatfile for that atlas
# Output: a low-redundancy protein sequence database suitable for Mayu.
#  This database should have the following properties:
#  - Include all protein identifications in the atlas covering set
#    (all the covering set identifications in the PAprotIdentlist)
#     including decoys
#  - Represent the basic human proteome
#  - Have a 1:1 target/decoy ratio
# Terry Farrah October 2012

use strict;
$|++;

my $print_stats = 0;
my $print_fasta = 1;
my $show_unfound_decoys = 0;

my $quiet = !$print_stats;

# -- Take as input the BSS flatfile and the atlas build directory
my $nargs = scalar @ARGV;
if ($nargs < 2) {
  print "Usage: $0 <bss_fasta_file> <atlas_build_dir>\n";
  print "  bss_fasta_file: biosequence set for atlas build\n";
  print "  atlas_build_dir: full path of PeptideAtlas pipeline output dir\n";
  exit;
}
my $bss_flatfile = $ARGV[0];
my $atlas_build_dir = $ARGV[1];
my $pipeline_dir = "/net/db/projects/PeptideAtlas/pipeline/output";

# -- Get the covering set from the PAidentlist and read accessions into list
#  This takes a few minutes; faster to get from a protlist file.
my $protIdentlist_file =
#"${pipeline_dir}/${atlas_build_dir}/DATA_FILES/PeptideAtlasInput.PAprotIdentlist";
"${atlas_build_dir}/DATA_FILES/PeptideAtlasInput.PAprotIdentlist";
my $infh;
open($infh, $protIdentlist_file) || die "Can't open $protIdentlist_file";
my %covering_set;
<$infh>;  #throw away header
while (my $line = <$infh>) {
  chomp $line;
  my @fields = split(",", $line);
  my $acc = $fields[1];
  my $is_covering = $fields[11];
  my $unmapped = ($acc =~ /UNMAPPED/);
  my $crap = ($acc =~ /sp\|/);
  $covering_set{$acc} = 1 if $is_covering && !$unmapped && !$crap;
}
my $n_acc = scalar keys %covering_set;
print "$n_acc accessions in covering set\n" if !$quiet;
close $infh;

# -- Read the bss flatfile into a hash
open($infh, $bss_flatfile) || die "Can't open $bss_flatfile";;
my %bss;
my $acc;
my $n_decoys = 0;
my $seq = '';
my $first = 1;
while (my $line = <$infh>) {
  chomp $line;
  if ($line =~ /^>\s*(\S+)/) {
    my $next_acc = $1;
    $n_decoys++ if ($next_acc =~ /DECOY/);
    if (! $first) {
      $bss{$acc} = $seq;
    }
    $acc = $next_acc;
    $seq = "";
    $first = 0;
  } else {
    $seq .= $line;
  }
}
#last seq
$bss{$acc} = $seq;
close $infh;

$n_acc = scalar keys %bss;
print "$n_acc accessions in biosequence set ($n_decoys decoys)\n" if !$quiet;

# Build database
my %mayu_db;
$n_decoys = 0;
# -- Add all swiss-prot canonicals and their decoys
for my $acc (keys %bss) {
  if ($acc =~ /^[A-Z]\S{5,5}$/) {
    $mayu_db{$acc} = $bss{$acc};
    my $decoy_acc = "DECOY_$acc";
    if (defined $bss{$decoy_acc}) {
      $mayu_db{$decoy_acc} = $bss{$decoy_acc};
      $n_decoys++;
    }
  }
}
$n_acc = scalar keys %mayu_db;
print "$n_acc swiss-prot canonicals (including $n_decoys decoys) found\n" if !$quiet;

# Add covering set proteins and their decoys (or, if the covering set protein
# is a decoy, add its target)
$n_decoys = 0;
my $no_decoys_found = 0;
my $n_covering_set_proteins_added = 0;
for my $acc (keys %covering_set) {
  if (! defined $mayu_db{$acc}) {  #not a Swiss-Prot canonical or decoy
    $mayu_db{$acc} = $bss{$acc};
    $n_covering_set_proteins_added ++;
    # If the accession is a decoy, add its target as well.
    if ($acc =~ /^DECOY_(\S+)/) {
      my $stripped_acc = $1;
      my $decoy_acc = $acc;
      $n_decoys++;
      if (defined $bss{$stripped_acc}) {
	$mayu_db{$stripped_acc} = $bss{$stripped_acc};
      } else {
	print "No target found for $decoy_acc\n" if $show_unfound_decoys;
      }
    # If the accession is a target, add its decoy as well.
    } else {
      my $decoy_acc = "DECOY_$acc";
      if (defined $bss{$decoy_acc}) {
	$mayu_db{$decoy_acc} = $bss{$decoy_acc};
	$n_decoys++;
      } else {
	print "No decoy found for $acc\n" if $show_unfound_decoys;
      }
    }
  }
}
$n_acc = scalar keys %mayu_db;
print "$n_acc accessions in database after adding $n_covering_set_proteins_added covering set (atlas idents)\n" if !$quiet;
my $n_swiss_prot_plus_covering_set = $n_acc;


# Add or subtract random decoys to get a 1:1 ratio
# (although, really, this should never be needed)
# First, count the decoys we already have
my $n_decoy_idents=0;
my %decoys;
for my $acc (keys %mayu_db) {
  if ($acc =~ /^DECOY/) {
    $n_decoy_idents++;
    $decoys{$acc} = 1;
  }
}
print "$n_decoy_idents total decoys added to DB so far\n" if !$quiet;
my $db_size = $n_swiss_prot_plus_covering_set - $n_decoy_idents;
print "$db_size total non-decoy entries\n" if !$quiet;
my $random_decoys_needed = $db_size - $n_decoy_idents;
print "$random_decoys_needed additional random decoys needed\n"
  if !$quiet && ($random_decoys_needed >0);
my $x = -$random_decoys_needed;
print "$x random decoys need to be removed from DB\n"
  if !$quiet && ($random_decoys_needed <0);

# We may need to add some decoys to reach 1:1 ratio
if ($random_decoys_needed > 0) {
  my $random_decoys_added = 0;
  for my $acc (keys %bss) {
    if (($acc =~ /^DECOY/) && (! defined $decoys{$acc})) {
      $mayu_db{$acc} = $bss{$acc};
      $random_decoys_added++;
      last if $random_decoys_added == $random_decoys_needed;
    }
  }

# ... or, we may need to subtract some. Be sure not to subtract those
# that are from the covering set of protein identifications!
} elsif ($random_decoys_needed < 0) {
  my $random_decoys_deleted = 0;
  for my $acc (keys %mayu_db) {
    if ($acc =~ /DECOY_(\S+)/) {
      if (! defined $covering_set{$acc}) {
	delete $mayu_db{$acc};
	$random_decoys_deleted ++;
	last if $random_decoys_deleted == -$random_decoys_needed;
      }
    }
  }
}

# -- Output fasta file!
my $counter = 0;
if ($print_fasta) {
  for my $acc (sort keys %mayu_db) {
    print ">$acc\n";
    print "$mayu_db{$acc}\n";
    $counter++;
  }
}
