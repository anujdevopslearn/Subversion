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

use lib "/net/db/projects/PeptideAtlas/lib/Swissknife_1.67/lib";
use SWISS::Entry;
use SWISS::FTs;

$|=1;

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
my $sprot_dat_file='/data/seqdb/uniprot_sprot/uniprot_sprot.dat';

###############################################################################
### Set program name and usage banner 
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Creates .tsv and .html files of SwissProt identifiers in this build that have peptide
 evidence for various N-terminus situations. Writes in current working directory.
Options:
  --verbose n                 Set verbosity level.  default is 0
                              When nonzero, waits for user confirm at each step.
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --atlas_build_id            Required
  --protid                    Run on only this SwissProt identifier. For testing.
  --sprot_dat                 SwissProt DAT file.
                              Default: $sprot_dat_file
  --no_variants               Don't get SwissProt variant information
EOU

###############################################################################
#### Process options
###############################################################################


unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
         "atlas_build_id=s","protid=s","no_variants","sprot_dat",
    )) {

    die "\n$USAGE";
}

if ($OPTIONS{"help"}) {
  print $USAGE; exit;
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

my $one_protid = $OPTIONS{'protid'};
my $no_variants = $OPTIONS{'no_variants'};
$sprot_dat_file = $OPTIONS{'sprot_dat'} if $OPTIONS{'sprot_dat'};

###############################################################################
### Get all SwissProt identifiers, sequences, and peptides in this build
###############################################################################

my %prot_pep;
my %pep_prot;

# Read SwissProt DAT file, unless no variant annotations wanted
# This code processes about 10,000 entries/minute. Since there are
# > 540,000 entries in the file, this would take nearly an hour
#--------------------------------------------------
# print "Using SwissKnife to get all human entries from uniprot_sprot.dat\n" if $VERBOSE;
# unless ($no_variants) {
#   local $/ = "\n//\n";
#   open ( my $infh, $sprot_dat_file) || die "Can't open $sprot_dat_file";
#   my $cnt = 0;
#   while ( my $record = <$infh>){
# 
#     $cnt++;
#     unless ($QUIET) {
#       print STDERR "." unless $cnt % 100;
#       print STDERR "$cnt" unless  $cnt % 1000;
#     }
# 
#     # Read the entry
#     my $entry = SWISS::Entry->fromText($record);
#     $entry->fullParse();  # this line is super slow
#     next unless is_human( $entry );
# 
#     my $fasta = $entry->toFasta();
#     next if !$fasta;
# 
#     $fasta = split_fasta( $fasta );
#     my $acc = $fasta->[0];
#     my $seq = $fasta->[1];
#     if ( !$seq || !$acc ) {
#       next;
#     }
# 
#     my $clean_acc;
#     if ( $acc =~ /sp\|([^|]+)\|/ ) {
#       $clean_acc = $1;
#     }
#     $clean_acc ||= $acc;
# 
#     my $var_list = get_vars( $entry );
# 
#     for my $var (@{$var_list}) {
#       my ($var_type, $var_num, $var_start, $var_end, $var_info) = (@{$var});
#       if ($var_type eq 'InitMet') {
# 	$prot_pep{$clean_acc}->{InitMet} = $var_info;
#       } elsif (($var_type eq 'Signal') && ($var_num == 1)) {
# 	# One protein in this analysis had two Signal vars, one for each
# 	#  of two splice variants. They were basically the same, but had different
# 	#  start residue numbers. We just use the first of the two.
# 	$prot_pep{$clean_acc}->{Signal_end} = $var_end;
# 	$prot_pep{$clean_acc}->{Signal_info} = $var_info;
#       }
#     }
#   }
# }
#-------------------------------------------------- 

# Get all the SwissProt identifiers in this build
my $swiss_idents_in_build;
if ($one_protid) {
  $swiss_idents_in_build = { $one_protid => 1 }
} else {
  print "Getting all SwissProt identifiers for this build ...\n" if $VERBOSE;
  $swiss_idents_in_build = $prot_info->get_swiss_idents_in_build(
    atlas_build_id=>$atlas_build_id,
  );
}
my $nprots = scalar keys %{$swiss_idents_in_build};
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
my $prot_pep_file = "/net/db/projects/PeptideAtlas/pipeline/output/${data_path}/peptide_mapping.tsv";
print "Reading peptide_mapping file ...\n" if $VERBOSE;
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


###############################################################################
### Process each identifier
###############################################################################
my %init_met_not_cleaved;
my %init_met_cleaved;
my %init_non_met_observed;
my %first_tryptic_pep_too_short;
my %first_observed_pep_nontryptic_nterm;

# For each identifier, get six leftmost mapping peptide start positions.
# Check to see whether the identifier has any of five types of cleavage
# evidence.
# If $VERBOSE, print summary for each protein to STDOUT.
my %mult_mapping_firstpeps;
my $nprots = scalar keys %prot_pep;
print "Processing each of $nprots protein identifiers " if $VERBOSE;
my $counter=0;
for my $protid (sort keys %prot_pep) {
  $counter++;
  my ($init_met_observed, $init_met_cleaved, $init_non_met_observed);
  my @starts = sort {$a <=> $b} keys %{$prot_pep{$protid}};
  my $nstarts = scalar @starts;
  my $seq = $seqmap{$protid};


  # Get and store InitMet and Signal variants from SwissProt
  unless ($no_variants) {
    my $html_seq = $atlas->get_html_seq_vars(
      seq=>$seq,
      accession=>$protid
    );

    my $var_list = $html_seq->{variant_list};
    shift ($var_list);  #discard header
    for my $var (@{$var_list}) {
      my ($var_type, $var_num, $var_start, $var_end, $var_info) = (@{$var});
      if ($var_type eq 'InitMet') {
	$prot_pep{$protid}->{InitMet} = $var_info;
      } elsif (($var_type eq 'Signal') && ($var_num == 1)) {
	# One protein in this analysis had two Signal vars, one for each
	#  of two splice variants. They were basically the same, but had different
	#  start residue numbers. We just use the first of the two.
	$prot_pep{$protid}->{Signal_end} = $var_end;
	$prot_pep{$protid}->{Signal_info} = $var_info;
      }
    }
    print "." if (! ($counter%100) && ($VERBOSE == 1));
    print "$counter" if (! ($counter%1000) && ($VERBOSE == 1));
  }
  
  my $firstpep;
  my $firststart;
  my $pos2pep;
  # For each of the six leftmost positions ...
  print "$protid: " if ($VERBOSE > 1);
  for (my $i=0; $i < min($nstarts, 6); $i++) {
    my $start = $starts[$i];
    print " $start" if ($VERBOSE > 1);
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
    if ($VERBOSE > 1) {
      if (($n_peps > 1) || ($n_mappings > 1)) {
	print "(";
	print "$n_peps" if $n_peps>1;
	print ".";
	print "$n_mappings" if $n_mappings > 1;
	print ")";
      }
    }
    if ($start == 1) {
      # Is init met observed?
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
  print " ", $firstpep if ($VERBOSE > 1);
  if ($init_met_observed) {
    print " init_met_not_cleaved" if ($VERBOSE > 1);
    $init_met_not_cleaved{$protid} = $firstpep;
  }
  if ($init_met_cleaved) {
    print " init_met_cleaved" if ($VERBOSE > 1);
    $init_met_cleaved{$protid} = $pos2pep;
  }
  if ($init_non_met_observed) {
    print " init_non_met_observed" if ($VERBOSE > 1);
    $init_non_met_observed{$protid} = $firstpep;
  }
  # Does KR near N-terminus make PeptideAtlas evidence unlikely?
  if ($seq =~ m/^.{1,6}[KR]/i) {
    print " first_tryptic_pep_too_short" if ($VERBOSE > 1);
    $first_tryptic_pep_too_short{$protid} = substr($seq,0,20);
  }
  # If first pep is at position > 2, is it preceded by K or R?
  if ($firststart > 2) {
    my $preceding_residue = substr($seq, $firststart-2, 1);
    if ($preceding_residue !~ m/[KR]/i) {
      print " first_observed_pep_nontryptic_nterm ($preceding_residue)" if ($VERBOSE > 1);
      $first_observed_pep_nontryptic_nterm{$protid}->{seq} = $firstpep;
      $first_observed_pep_nontryptic_nterm{$protid}->{start} = $firststart;
      $first_observed_pep_nontryptic_nterm{$protid}->{preceding_residue} = $preceding_residue;
      # Store any subsequent peptide start locations if within 20 residues of first
      #print "Starts $starts[1] $starts[2] $starts[3]\n";
      $first_observed_pep_nontryptic_nterm{$protid}->{start2} = ($starts[1] < $firststart + 25) ? $starts[1] : '';
      $first_observed_pep_nontryptic_nterm{$protid}->{start3} = ($starts[2] < $firststart + 25) ? $starts[2] : '';
      $first_observed_pep_nontryptic_nterm{$protid}->{start4} = ($starts[3] < $firststart + 25) ? $starts[3] : '';
      $first_observed_pep_nontryptic_nterm{$protid}->{start5} = ($starts[4] < $firststart + 25) ? $starts[4] : '';
      $first_observed_pep_nontryptic_nterm{$protid}->{start6} = ($starts[5] < $firststart + 25) ? $starts[5] : '';
    }
  }
  print "\n" if ($VERBOSE > 1);
}
print "\n" if $VERBOSE == 1;

printf "%d multiple mapping firstpeps\n", scalar keys %mult_mapping_firstpeps if $VERBOSE;

###############################################################################
### Create files of the awesome result sets!
###############################################################################
my $outfh;
my $htmlfh;

my $i=1;
# We have to print this list first, before init_met_both_cleaved_and_not,
# because after printing that list we delete stuff from the cleaved
# and not_cleaved hashes -- and we rely on the initial contents of those
# hashes for this list.
my $set = "first_observed_pep_nontryptic_nterm";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>prec aa</td><td>first observed peptide</td><td>position</td><td>2nd</td><td>3rd</td><td>4th</td><td>5th</td><td>6th</td><td>mappings</td><td>SP InitMet</td><td>SP Signal</td></tr>\n";
for my $protid (sort keys %first_observed_pep_nontryptic_nterm) {
  # consider only if this identifier not included in the other lists
  if ((! defined $init_met_cleaved{$protid}) &&
      (! defined $init_met_not_cleaved{$protid}) &&
      (! defined $init_non_met_observed{$protid})) {
    my $pep = $first_observed_pep_nontryptic_nterm{$protid}->{seq};
    my $n_mappings = $pep_prot{$pep}->{nmappings};
    print $outfh "$protid\t$first_observed_pep_nontryptic_nterm{$protid}->{preceding_residue}\t";
    print $outfh "$pep\t";
    print $outfh "$first_observed_pep_nontryptic_nterm{$protid}->{start}\t";
    print $outfh "$n_mappings\n";
    print $htmlfh "<tr>";
    print $htmlfh "<td>$i</td>"; $i++;
    print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{preceding_residue}</td>\t";
    print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{start}</td>\n";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{start2}</td>";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{start3}</td>";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{start4}</td>";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{start5}</td>";
    print $htmlfh "<td>$first_observed_pep_nontryptic_nterm{$protid}->{start6}</td>";
    print $htmlfh "<td>$n_mappings</td>";
    print_var_info_html($protid, $htmlfh);
    print $htmlfh "</tr>\n";
  }
}
print $htmlfh "</table></html>\n";
close $outfh;
close $htmlfh;

$i=1;
# We have to print this list before the lists init_met_cleaved and
# init_met_not_cleaved, because while constructing and printing
# this list, we delete the corresponding entries from those other
# two lists so that the three lists are disjoint.
$set = "init_met_both_cleaved_and_not";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>longest pep position 1</td><td>mappings</td><td>longest pep position 2</td><td>mappings</td><td>SP InitMet</td><td>SP Signal</td></tr>\n";
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
    print_var_info_html($protid, $htmlfh);
    print $htmlfh "</tr>\n";
    # delete these proteins for cleaved and for not_cleaved so they are not included
    # in those output files
    delete $init_met_not_cleaved{$protid};
    delete $init_met_cleaved{$protid};
  }
}
print $htmlfh "</table></html>\n";
close $outfh;
close $htmlfh;


$i=1;
$set = "init_met_not_cleaved";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>longest pep position 1</td><td>mappings</td><td>SP InitMet</td><td>SP Signal</td></tr>\n";
for my $protid (sort keys %init_met_not_cleaved) {
  my $pep = $init_met_not_cleaved{$protid};
  my $n_mappings = $pep_prot{$pep}->{nmappings};
  print $outfh "$protid\t$pep\t$n_mappings\n";
  print $htmlfh "<tr>";
  print $htmlfh "<td>$i</td>"; $i++;
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
  print $htmlfh "<td>$n_mappings</td>";
  print_var_info_html($protid, $htmlfh);
  print $htmlfh "</tr>\n";
}
print $htmlfh "</table></html>\n";
close $outfh;
close $htmlfh;

$i=1;
$set = "init_met_cleaved";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>longest pep position 2</td><td>mappings</td><td>SP InitMet</td><td>SP Signal</td></tr>\n";
for my $protid (sort keys %init_met_cleaved) {
  my $pep = $init_met_cleaved{$protid};
  my $n_mappings = $pep_prot{$pep}->{nmappings};
  print $outfh "$protid\t$pep\t$n_mappings\n";
  print $htmlfh "<tr>";
  print $htmlfh "<td>$i</td>"; $i++;
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
  print $htmlfh "<td>$n_mappings</td>";
  print_var_info_html($protid, $htmlfh);
  print $htmlfh "</tr>\n";
}
print $htmlfh "</table></html>\n";
close $outfh;
close $htmlfh;

$i=1;
$set = "init_non_met_observed";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>longest pep position 1</td><td>mappings</td><td>SP InitMet</td><td>SP Signal</td></tr>\n";
for my $protid (sort keys %init_non_met_observed) {
  my $pep = $init_non_met_observed{$protid};
  my $n_mappings = $pep_prot{$pep}->{nmappings};
  print $outfh "$protid\t$pep\t$n_mappings\n";
  print $htmlfh "<tr>";
  print $htmlfh "<td>$i</td>"; $i++;
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide\?peptide_sequence_constraint=$pep&atlas_build_id=$atlas_build_id\">$pep</a></td>";
  print $htmlfh "<td>$n_mappings</td>";
  print_var_info_html($protid, $htmlfh);
  print $htmlfh "</tr>\n";
}
print $htmlfh "</table></html>\n";
close $outfh;
close $htmlfh;

$i=1;
$set = "first_tryptic_pep_too_short";
open ($outfh, ">$set.tsv") or die "Can't open file for writing";
open ($htmlfh, ">$set.html") or die "Can't open file for writing";
print $htmlfh "<html>\n<h3>$set</h3>\n";
print $htmlfh "<table>\n";
print $htmlfh "<tr><td></td><td>protid</td><td>first 20 residues</td><td>SP InitMet</td><td>SP Signal</td></tr>\n";
for my $protid (sort keys %first_tryptic_pep_too_short) {
  my $pep = $first_tryptic_pep_too_short{$protid};
  print $outfh "$protid\t$pep\n";
  print $htmlfh "<tr>";
  print $htmlfh "<td>$i</td>"; $i++;
  print $htmlfh "<td><a href=\"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetProtein\?protein_name=$protid\&action=QUERY\&atlas_build_id=$atlas_build_id\">$protid</a></td>";
  print $htmlfh "<td>$pep</td>";
  print_var_info_html($protid, $htmlfh);
  print $htmlfh "</tr>\n";
}
print $htmlfh "</table></html>\n";
close $outfh;
close $htmlfh;


# end main program

#########################
### print_var_info_html
#########################
sub print_var_info_html {
  my $protid = shift || die "print_var_info_html needs protid";
  my $htmlfh = shift || die "print_var_info_html needs output filehandle";
  print $htmlfh "<td>$prot_pep{$protid}->{InitMet}</td>";
  my $signal_end = $prot_pep{$protid}->{Signal_end};
  print $htmlfh "<td>";
  if ($signal_end) {
    my $putative_start = $first_observed_pep_nontryptic_nterm{$protid}->{start};
    print $htmlfh "1-${signal_end}";
    if ($prot_pep{$protid}->{Signal_info}) {
      print $htmlfh " $prot_pep{$protid}->{Signal_info}";
    }
    my $diff = $putative_start - $signal_end;
    if ($diff == 1) {
      print $htmlfh " Match";
    } elsif (abs($diff-1) < 10) {
      printf $htmlfh " Slightly off (%d)", $diff-1;
    }
  }
  print $htmlfh "</td>";
}


###############
### is_sprot
###############
sub is_sprot {
  my $ident = shift;
  my $swiss_idents_href = shift || die "is_sprot: needs hash arg";
  return ($swiss_idents_href->{$ident});
}


###############
### is_human
###############
sub is_human {
  my $entry = shift;
  for my $os ( @{$entry->{OSs}->{list}} ) {
    my $rec_org = $os->toText();
    chomp $rec_org;
    if ( $rec_org =~ /human/i) {
      return 1;
    }
  }
  return 0;
}

##############
### get_vars
##############
sub get_vars {
  my $entry = shift;
  my $fts = $entry->{FTs};
  my @vars;
  for my $ft ( @{$fts->{list}} ) {
    push @vars, $ft;
  }
  return \@vars;
}

#################
### split_fasta
#################
sub split_fasta {
  my $fasta = shift;
  my @fasta = split( "\n", $fasta, -1 );
  my $acc = '';
  my $seq = '';
  for my $line ( @fasta ) {
    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
    if ( $line =~ /^>/ ) {
      $acc = $line;
    } else {
      $seq .= $line;
    }
  }
  return [ $acc, $seq ];
}
