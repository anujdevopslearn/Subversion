#!/usr/local/bin/perl
###############################################################################
# Program      : checkProtNtermEvidence.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Gather PeptideAtlas evidence for actual N-termini of proteins
###############################################################################

###############################################################################
### Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use List::Util qw( min max );
use FindBin;
$|++;

use lib "$FindBin::Bin/../../perl";

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
$current_work_group_id = $sbeams->getCurrent_work_group_id;

###############################################################################
### Set program name and usage banner 
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Creates .tsv files of SwissProt identifiers in this build that have peptide
 evidence for various N-terminus situations.
Options:
  --verbose n                 Set verbosity level.  default is 0
                              When nonzero, waits for user confirm at each step.
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --atlas_build_id           Required
EOU

###############################################################################
#### Process options
###############################################################################


unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
         "atlas_build_id=s",
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

my $atlas_build_id = $OPTIONS{"atlas_build_id"};

my $n_atlases;
my $data_path;
$atlas_build_id =~ s/\s//g;  #remove all whitespace
my $query = qq~
  SELECT data_path
  FROM $TBAT_ATLAS_BUILD
  WHERE atlas_build_id = '$atlas_build_id';
~;
($data_path) = $sbeams->selectOneColumn($query);
if (! $data_path) {
  print "No data_path for atlas_build $atlas_build_id, or build doesn't exist.\n";
  exit;
} else {
  print "$atlas_build_id $data_path\n" if $VERBOSE;
}

###############################################################################
### Get all SwissProt identifiers, sequences, and peptides in this build
###############################################################################

# Get all the SwissProt identifiers in this build
print "Getting all SwissProt identifiers for this build ...\n" if $VERBOSE;
my $swiss_idents_in_build = $prot_info->get_swiss_idents_in_build(
  atlas_build_id=>$atlas_build_id,
);
my $nprots = scalar keys $swiss_idents_in_build;
print "$nprots swissprot idents in this build.\n" if $VERBOSE;

# Get the sequences for all these proteins from the fasta file
print "Getting sequences for all SwissProt identifiers from fasta file ...\n" if $VERBOSE;
my $fasta_file = "/net/db/projects/PeptideAtlas/pipeline/output/${data_path}/Homo_sapiens.fasta";
my %seqmap;
open (my $infh, $fasta_file) or die "Can't open $fasta_file";
my ($protid, $seq);
while (my $line = <$infh>) {
  chomp $line;
  if ($line =~ /^>\s*(\S+)/) {
    $protid = $1;
  } else {
    if (is_sprot($protid, $swiss_idents_in_build)) {
      $seqmap{$protid} = $line;
    }
  }
}
my $nseqs = scalar keys %seqmap;
print "$nseqs fasta sequences stored with SwissProt idents.\n" if $VERBOSE;

# Read peptide_mapping.tsv file
print "Reading peptide_mapping file ...\n" if $VERBOSE;
my $prot_pep_file = "/net/db/projects/PeptideAtlas/pipeline/output/${data_path}/peptide_mapping.tsv";
my %prot_pep;
my %pep_prot;
open (my $infh, $prot_pep_file) || die "Can't open $prot_pep_file";
while (my $line = <$infh>) {
  chomp $line;
  my ($pep_acc, $pepseq, $protid, $start, $end) = split ("\t", $line);
  if (is_sprot($protid, $swiss_idents_in_build)) {
    $prot_pep{$protid}->{$start}->{peps}->{$pepseq} = 1;
    my ($base_protid) = substr($protid, 0, 6);
    $pep_prot{$pepseq}->{prots}->{$base_protid} = 1;
  }
}
for my $pepseq (keys %pep_prot) {
  $pep_prot{$pepseq}->{nprots} = scalar keys %{$pep_prot{$pepseq}->{prots}};
}

$nprots = scalar keys %prot_pep;
print "$nprots swissprot idents have peptides in this build.\n" if $VERBOSE;

my %init_met_not_cleaved;
my %init_met_cleaved;
my %init_non_met_observed;
my %first_tryptic_pep_too_short;
my %first_observed_pep_nontryptic_nterm;

###############################################################################
### Process each identifier
###############################################################################
# For each identifier, get six leftmost mapping peptide start positions.
# Check to see whether the identifier has any of five types of cleavage
# evidence.
# Unless $QUIET, print summary for each protein to STDOUT.
my %mult_mapping_firstpeps;
for my $protid (sort keys %prot_pep) {
  my ($init_met_observed, $init_met_cleaved, $init_non_met_observed);
  my @starts = sort {$a <=> $b} keys %{$prot_pep{$protid}};
  my $nstarts = scalar @starts;
  my $seq = $seqmap{$protid};
  print "$protid: " unless $QUIET;
  my $firstpep;
  my $firststart;
  my $pos2pep;
  # For each of the six leftmost positions ...
  for (my $i=0; $i < min($nstarts, 6); $i++) {
    my $start = $starts[$i];
    print " $start" unless $QUIET;
    $firststart = $start if ($i == 0);
    # Use the longest pep at this position; it will have the fewest mappings
    my @peps = keys %{$prot_pep{$protid}->{$start}->{peps}};
    my $n_peps = scalar @peps;
    my $pep = shift (@peps);
    for my $trial_pep (@peps) {
      if (length($trial_pep) > length($pep)) {
	$pep = $trial_pep;
      }
    }
    my $n_mappings = $pep_prot{$pep}->{nprots};
    $pep_prot{$pep}->{nmappings} = $n_mappings;
    my $mult_mappings = ($n_mappings > 1);
    $firstpep = $pep if ($i == 0);
    # Print n_peps at this position, n_mappings for longest pep
    unless ($QUIET) {
      if (($n_peps > 1) || ($n_mappings > 1)) {
	print "(";
	print "$n_peps" if $n_peps>1;
	print ".";
	print "$n_mappings" if $n_mappings > 1;
	print ")";
      }
    }
    if ($start == 1) {
      # Is init met obesrved?
      $init_met_observed = ($pep =~ m/^m/i);
      # Is it a non Met at position 1?
      $init_non_met_observed = ($pep !~ m/^m/i);
      # Is it multiply mapping?
      $mult_mapping_firstpeps{$pep} = 1 if $mult_mappings;
    }
    # Is it position two after a Met?
    if ($start == 2) {
      $init_met_cleaved = ($seq =~ m/^m/i);
      $pos2pep = $pep;
    }
  }
  print " ", $firstpep unless $QUIET;
  if ($init_met_observed) {
    print " init_met_not_cleaved" unless $QUIET;
    $init_met_not_cleaved{$protid} = $firstpep;
  }
  if ($init_met_cleaved) {
    print " init_met_cleaved" unless $QUIET;
    $init_met_cleaved{$protid} = $pos2pep;
  }
  if ($init_non_met_observed) {
    print " init_non_met_observed" unless $QUIET;
    $init_non_met_observed{$protid} = $firstpep;
  }
  # Does KR near N-terminus make PeptideAtlas evidence unlikely?
  if ($seq =~ m/^.{1,6}[KR]/i) {
    print " first_tryptic_pep_too_short" unless $QUIET;
    $first_tryptic_pep_too_short{$protid} = substr($seq,0,20);
  }
  # If first pep is at position > 2, is it preceded by K or R?
  if ($firststart > 2) {
    my $preceding_residue = substr($seq, $firststart-2, 1);
    if ($preceding_residue !~ m/[KR]/i) {
      print " first_observed_pep_nontryptic_nterm ($preceding_residue)" unless $QUIET;
      $first_observed_pep_nontryptic_nterm{$protid}->{seq} = $firstpep;
      $first_observed_pep_nontryptic_nterm{$protid}->{start} = $firststart;
      $first_observed_pep_nontryptic_nterm{$protid}->{preceding_residue} = $preceding_residue;
    }
  }
  print "\n" unless $QUIET;
}

printf "%d multiple mapping firstpeps\n", scalar keys %mult_mapping_firstpeps if $VERBOSE;

###############################################################################
### Create files of the awesome result sets!
###############################################################################
my $outfh;
my $htmlfh;

my $i=1;
my $set = "init_met_both_cleaved_and_not";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>longest pep position 1</td><td>mappings</td><td>longest pep position 2</td><td>mappings</td></tr>\n";
for my $protid (sort keys %init_met_not_cleaved) {
  if (defined $init_met_cleaved{$protid}) {
    print $outfh "$protid\t";
    my $pep = $init_met_not_cleaved{$protid};
    my $n_mappings = $pep_prot{$pep}->{nmappings};
    print $outfh "$pep\t$n_mappings\t";
    print $htmlfh "<tr>";
    print $htmlfh "<td>$i</td>"; $i++;
    print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
    print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
    print $htmlfh "<td>$n_mappings</td>";
    $pep = $init_met_cleaved{$protid};
    $n_mappings = $pep_prot{$pep}->{nmappings};
    print $outfh "$pep\t$n_mappings\n";
    print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
    print $htmlfh "<td>$n_mappings</td>";
    print $htmlfh "</tr>";
    # delete these proteins for cleaved and for not_cleaved so they are not included
    # in those output files
    delete $init_met_not_cleaved{$protid};
    delete $init_met_cleaved{$protid};
  }
}
print $htmlfh "</table></html>";
close $outfh;
close $htmlfh;


$i=1;
$set = "init_met_not_cleaved";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>longest pep position 1</td><td>mappings</td></tr>\n";
for my $protid (sort keys %init_met_not_cleaved) {
  my $pep = $init_met_not_cleaved{$protid};
  my $n_mappings = $pep_prot{$pep}->{nmappings};
  print $outfh "$protid\t$pep\t$n_mappings\n";
  print $htmlfh "<tr>";
  print $htmlfh "<td>$i</td>"; $i++;
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
  print $htmlfh "<td>$n_mappings</td>";
  print $htmlfh "</tr>";
}
print $htmlfh "</table></html>";
close $outfh;
close $htmlfh;

$i=1;
$set = "init_met_cleaved";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>longest pep position 2</td><td>mappings</td></tr>\n";
for my $protid (sort keys %init_met_cleaved) {
  my $pep = $init_met_cleaved{$protid};
  my $n_mappings = $pep_prot{$pep}->{nmappings};
  print $outfh "$protid\t$pep\t$n_mappings\n";
  print $htmlfh "<tr>";
  print $htmlfh "<td>$i</td>"; $i++;
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
  print $htmlfh "<td>$n_mappings</td>";
  print $htmlfh "</tr>";
}
print $htmlfh "</table></html>";
close $outfh;
close $htmlfh;

$i=1;
$set = "init_non_met_observed";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>longest pep position 1</td><td>mappings</td></tr>\n";
for my $protid (sort keys %init_non_met_observed) {
  my $pep = $init_non_met_observed{$protid};
  my $n_mappings = $pep_prot{$pep}->{nmappings};
  print $outfh "$protid\t$pep\t$n_mappings\n";
  print $htmlfh "<tr>";
  print $htmlfh "<td>$i</td>"; $i++;
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
  print $htmlfh "<td>$n_mappings</td>";
  print $htmlfh "</tr>";
}
print $htmlfh "</table></html>";
close $outfh;
close $htmlfh;

$i=1;
$set = "first_tryptic_pep_too_short";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>first 20 residues</td>\n";
for my $protid (sort keys %first_tryptic_pep_too_short) {
  my $pep = $first_tryptic_pep_too_short{$protid};
  print $outfh "$protid\t$pep\n";
  print $htmlfh "<tr>";
  print $htmlfh "<td>$i</td>"; $i++;
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
  print $htmlfh "<td>$pep</td>";
  print $htmlfh "</tr>";
}
print $htmlfh "</table></html>";
close $outfh;
close $htmlfh;

$i=1;
$set = "first_observed_pep_nontryptic_nterm";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>prec aa</td><td>first observed peptide</td><td>position</td><td>mappings</td></tr>\n";
for my $protid (sort keys %first_observed_pep_nontryptic_nterm) {
  # consider only if this identifier not included in the other lists
  if ((! defined $init_met_cleaved{$protid}) &&
      (! defined $init_met_not_cleaved{$protid}) &&
      (! defined $init_non_met_observed{$protid})) {
    my $pep = $first_observed_pep_nontryptic_nterm{$protid}->{seq};
    my $n_mappings = $pep_prot{$pep}->{nmappings};
    print $outfh "$protid\t$first_observed_pep_nontryptic_nterm{$protid}->{preceding_residue}\t";
    print $outfh "$pep\t";
    print $outfh "$first_observed_pep_nontryptic_nterm{$protid}->{start}\n";
    print $outfh "$n_mappings\t";
    print $htmlfh "<tr>";
    print $htmlfh "<td>$i</td>"; $i++;
    print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{preceding_residue}</td>\t";
    print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{start}</td>\n";
    print $htmlfh "<td>$n_mappings</td>";
    print $htmlfh "</tr>";
  }
}
print $htmlfh "</table></html>";
close $outfh;
close $htmlfh;

# end main program



###############
### is_sprot
###############
sub is_sprot {
  my $ident = shift;
  my $swiss_idents_href = shift || die "is_sprot: needs hash arg";
  return ($swiss_idents_href->{$ident});
}
