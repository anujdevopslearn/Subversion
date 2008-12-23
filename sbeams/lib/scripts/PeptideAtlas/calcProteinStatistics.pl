#!/usr/local/bin/perl -w

###############################################################################
# Program     : calcProteinStatistics.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script reads several input files
#               and estimates which proteins were observed
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use Getopt::Long;
use FindBin;

use vars qw (
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $peptide_hash
            );


###############################################################################
# Read and validate command line args
###############################################################################
my $VERSION = q[$Id$ ];
$PROG_NAME = $FindBin::Script;

my $USAGE = <<EOU;
USAGE: $PROG_NAME [OPTIONS] source_file
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
                      This masks the printing of progress information
  --debug n           Set debug level.  default is 0
  --testonly          If set, nothing is actually inserted into the database,
                      but we just go through all the motions.  Use --verbose
                      to see all the SQL statements that would occur

  --alignment_summary_file BLAST alignment summary file, e.g.
                      DATA_FILES/APD_ensembl_hits.tsv
  --unmapped_peptides_file File containing peptides that could not be mapped
                      to reference genome
  --peptide_fasta     FASTA file that provides peptide accession to sequence
                      mapping
  --peptide_inclusion_file File listing which peptides to include, e.g.
                      a file with only multiply-observed peptides
  --duplicate_protein_file File listing which proteins are exact duplicates
                      of another and can be discarded
  --protein_gene_file File mapping protein names to gene names
  --protein_length_correction_file File with proteins lengths and mean random hits
  --peptide_counts_file tsv file contains the number of matches for each peptide

 e.g.:  $PROG_NAME --alignment_summary_file ../DATA_FILES/APD_ensembl_hits.tsv \
             --unmapped_peptides_file ../DATA_FILES/APD_ensembl_lost_queries.dat \
             --peptide_fasta ../DATA_FILES/APD_Hs_all.fasta \
             --peptide_inclusion_file out.2tonsequences \
             --duplicate_protein_file ../DATA_FILES/duplicate_proteins.txt \
             --protein_gene_file ../DATA_FILES/protein2gene.txt
EOU


#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "alignment_summary_file:s","unmapped_peptides_file:s","peptide_fasta:s",
  "peptide_inclusion_file:s","duplicate_protein_file:s","protein_gene_file:s",
  "protein_length_correction_file:s","peptide_counts_file:s",
  )) {
  print "$USAGE";
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

main();
exit;


###############################################################################
# Main part of the script
###############################################################################
sub main {

  my $alignment_summary_file = $OPTIONS{alignment_summary_file};
  unless ($alignment_summary_file) {
    print "$USAGE\n";
    print "ERROR: Must supply --alignment_summary_file\n\n";
    return(0);
  }

  unless (open(INFILE,$alignment_summary_file)) {
    print "ERROR: Unable to open file '$alignment_summary_file'\n\n";
    return(0);
  }

  my $duplicate_protein_file = $OPTIONS{duplicate_protein_file};

  my $unmapped_peptides_file = $OPTIONS{unmapped_peptides_file};

  my $peptide_fasta = $OPTIONS{peptide_fasta};
  my %peptide_lookup;
  if ($peptide_fasta) {
    if (open(FASTAFILE,$peptide_fasta)) {
      while (my $line = <FASTAFILE>) {
	if ($line =~ /^\>(\w+)/) {
	  my $sequence = <FASTAFILE>;
	  chomp($sequence);
	  $peptide_lookup{$sequence} = $1;
	} else {
	  die("ERROR parsing $peptide_fasta");
	}
      }
      close(FASTAFILE);
    } else {
      die("ERROR: Unable to open $peptide_fasta");
    }
  }


  my $peptide_inclusion_file = $OPTIONS{peptide_inclusion_file};
  my %peptides_to_include;
  if ($peptide_inclusion_file) {
    if (open(INCLUDEFILE,$peptide_inclusion_file)) {
      while (my $line = <INCLUDEFILE>) {
        chomp($line);
	my $accession = $peptide_lookup{$line};
	unless ($accession) {
	  print "WARNING: Unable to find accession for $line\n";
	}
	$peptides_to_include{$accession} = 1;
      }
      close(INCLUDEFILE);
    } else {
      die("ERROR: Unable to open $peptide_inclusion_file");
    }
  }


  my $protein_gene_file = $OPTIONS{protein_gene_file};
  my %proteins_to_genes;
  if ($protein_gene_file) {
    if (open(MAPFILE,$protein_gene_file)) {
      while (my $line = <MAPFILE>) {
        chomp($line);
	my ($protein,$gene) = split(/\t/,$line);
	$proteins_to_genes{$protein} = $gene;
      }
      close(INCLUDEFILE);
    } else {
      die("ERROR: Unable to open $protein_gene_file");
    }
  }


  my %stats;
  my $prev_pep = '';
  my $prev_prot = '';
  my %peptides;
  my %proteins;


  my %duplicates;
  if ($duplicate_protein_file && -e $duplicate_protein_file) {
    if (open(DUPEFILE,$duplicate_protein_file)) {
      print "WARNING: Excluding duplicated sequences\n";
      while (my $line = <DUPEFILE>) {
	chomp($line);
	$duplicates{$line} = 1;
      }
      close(DUPEFILE);
    }
  } else {
    print "WARNING: Duplicate proteins information not available\n";
  }


  my $protein_length_correction_file = $OPTIONS{protein_length_correction_file};
  my %required_hits_95;
  if ($protein_length_correction_file && -e $protein_length_correction_file) {
    if (open(REFFILE,$protein_length_correction_file)) {
      print "INFO: Correcting for protein lengths\n";
      my @min_required = ( 0.02=>3, 0.075=>4, 0.18=>5, 0.33=>6,
			   0.52=>7, 0.75=>8, 1.02=>9, 1.32=>10 );
      my $required_hits;
      while (my $line = <REFFILE>) {
	chomp($line);
	my ($junk,$protein_name,$protein_length,$mean_random_hits) =
	  split(/\s+/,$line);
	if ($mean_random_hits < $min_required[0]) {
	  $required_hits = $min_required[1];
	} elsif ($mean_random_hits > $min_required[$#min_required-1]) {
	  $required_hits = int(($mean_random_hits-0.75)/.3+8);
	} else {
	  for (my $i=0; $i<scalar(@min_required); $i+=2) {
	    if ($mean_random_hits >= $min_required[$i]) {
	      $required_hits = $min_required[$i+1];
	    }
	  }
	}
	$required_hits_95{$protein_name} = $required_hits;
      }
      close(REFFILE);
    }
  } else {
    print "WARNING: Protein length correction not available\n";
  }


  #### Note a more appropriate thing to do here would be to count each
  #### peptide by its probability rather than by 1.
  my $peptide_counts_file = $OPTIONS{peptide_counts_file};
  my %peptide_counts;
  if ($peptide_counts_file && -e $peptide_counts_file) {
    if (open(REFFILE,$peptide_counts_file)) {
      print "INFO: Reading peptide counts\n";
      my $first_line = 1;
      while (my $line = <REFFILE>) {
	next if ($first_line && $line =~ /^peptide_identifier_str/);
	chomp($line);
	#my @columns = split(/\s+/,$line);
	my @columns = split(/\t/,$line);
	$peptide_counts{$columns[0]} = $columns[5];
	#print STDERR "  + $columns[0] = $columns[5]\n";
        $first_line = 0;
      }
      close(REFFILE);
    }
  } else {
    print "WARNING: Peptide counts not available\n";
  }


  my %protein_counts;
  while (my $line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my @columns = split(/\t/,$line);

    my $peptide_accession = $columns[0];
    my $biosequence_name = $columns[2];  # Ensembl protein

    next if ($duplicates{$biosequence_name});
    if ($peptide_inclusion_file) {
      next unless ($peptides_to_include{$peptide_accession});
    }

    $peptides{$peptide_accession}->{$biosequence_name}->{n_occur} = 1;
    $proteins{$biosequence_name}->{$peptide_accession}->{n_occur} = 1;
    if ($peptide_counts_file) {
      $protein_counts{$biosequence_name} += $peptide_counts{$peptide_accession};
    }
  }

  close(INFILE);



  #### Total number of peptides successfully mapped
  my $num_peptides_mapped_to_ensembl=scalar(keys(%peptides));

  #### Get the number of unmapped peptides
  print "counting entries in  $unmapped_peptides_file\n";
  my $num_peptides_notmapped_to_ensembl =
    `wc -l $unmapped_peptides_file`;
  $num_peptides_notmapped_to_ensembl =~ s/[\D]//g;



  #### Determine total number of distinct peptides
  my $n_p=$num_peptides_mapped_to_ensembl + $num_peptides_notmapped_to_ensembl;
  printf("%10d  Total Number of distinct peptides as input\n",$n_p);

  printf("%10d  Number of distinct peptides that mapped to Reference Genome\n",
	 $num_peptides_mapped_to_ensembl);

  printf("%10d  Number of all possible proteins implicated in mapping\n",
	 scalar(keys(%proteins)));


  #### If we read a protein length correction file, remove proteins that don't
  #### pass the 95% confidence threshold
  if ($protein_length_correction_file) {
    foreach my $protein (keys(%proteins)) {
      #print "$protein\t$protein_counts{$protein}\t$required_hits_95{$protein}\n";
      if (exists($required_hits_95{$protein})) {
	unless ($protein_counts{$protein} >= $required_hits_95{$protein}) {
	  delete($proteins{$protein});
	}
      #### Or just delete the protein if it's not in the file
      } else {
	delete($proteins{$protein});
      }
    }
  }

  my %simple_peptide_stats;
  my %simple_protein_stats;
  my %simple_gene_stats;
  my %tmp_peptides = %peptides;
  my %tmp_proteins = %proteins;
  my %unique_protein_hash;

  if (1) {
    foreach my $peptide (keys(%tmp_peptides)) {

      #### Get a list of the composing proteins
      my %composing_proteins = %{$tmp_peptides{$peptide}};

      #### Remove some proteins if they don't exist in %proteins
      #### This removes proteins that don't pass the 95% confidence
      #### criterion
      foreach my $composing_protein (keys(%composing_proteins)) {
	unless ($proteins{$composing_protein}) {
	  delete($composing_proteins{$composing_protein})
	}
      }


      #### For the case where there are both DECOY_ proteins and
      #### regular proteins, delete the DECOY_proteins as this
      #### is just freak chance
      my $have_non_DECOYs = 0;
      #### First check to see if there are non DECOY_s
      foreach my $composing_protein (keys(%composing_proteins)) {
	if ($composing_protein !~ /^DECOY_/) {
	  $have_non_DECOYs = 1;
	  last;
	}
      }

      #### If so, then delete
      if ($have_non_DECOYs) {
	foreach my $composing_protein (keys(%composing_proteins)) {
	  if ($composing_protein =~ /^DECOY_/) {
	    delete($composing_proteins{$composing_protein})
	  }
	}
      }


      #### Get the revised protein count
      my $n_proteins = scalar(keys(%composing_proteins));
      next unless ($n_proteins);


      #### If more than one mapping, call it degenerate
      if ($n_proteins == 1) {
	$simple_peptide_stats{$peptide}->{is_degenerate} = 0;
      } else {
	$simple_peptide_stats{$peptide}->{is_degenerate} = 1;
      }


      #### Remove all duplicate proteins.  Just keep first.
      my $counter = 0;
      foreach my $protein (sort keys(%composing_proteins)) {
	if ($counter) {
	  #delete($tmp_peptides{$peptide}->{$protein});
	  $unique_protein_hash{$protein} = $protein;
	} else {
	  $simple_protein_stats{$protein} = 1;
	  my $gene_name = $proteins_to_genes{$protein};
	  if ($gene_name) {
	    $simple_gene_stats{$gene_name} = 1;
	  }
	}
	$counter++;
      }

    }
    printf("%10d  Number of simple reduced proteins (naive ".
	   "correction for ambiguous mappings)\n",
	   scalar(keys(%simple_protein_stats)));
    printf("%10d  Number of simple reduced genes (naive ".
	   "correction for ambiguous protein mappings)\n",
	   scalar(keys(%simple_gene_stats)));
  }


  my $proteinsfile = 'simplereducedproteins.txt';
  print "Writing simple reduced proteins to file '$proteinsfile'\n";
  open(OUTFILE,">$proteinsfile") || die ("ERROR: Cannot write file");
  foreach my $protein (keys(%simple_protein_stats)) {
    print OUTFILE "$protein\n";
  }
  close(OUTFILE);
  if ($protein_length_correction_file) {
    open(OUTFILE,">${proteinsfile}-95") || die ("ERROR: Cannot write file");
    foreach my $protein (keys(%simple_protein_stats)) {
      print OUTFILE "$protein\t$protein_counts{$protein}\t$required_hits_95{$protein}\n";
    }
    close(OUTFILE);
  }

  my %nondegen_peptide_stats;
  my %nondegen_protein_stats;

  if (1) {
    foreach my $peptide (keys(%tmp_peptides)) {
      my %composing_proteins = %{$tmp_peptides{$peptide}};
      my $n_proteins = scalar(keys(%composing_proteins));
      die("ERROR 0") unless ($n_proteins);
      if ($n_proteins == 1) {
	$nondegen_peptide_stats{$peptide}->{is_degenerate} = 0;
      } else {
	$nondegen_peptide_stats{$peptide}->{is_degenerate} = 1;
	foreach my $protein (sort keys(%composing_proteins)) {
	  delete($tmp_proteins{$protein}->{$peptide});
	}
      }
    }

    #### Remove all proteins that no longer have a peptide
    foreach my $protein (keys(%tmp_proteins)) {
      my %composing_peptides = %{$tmp_proteins{$protein}};
      my $n_peptides = scalar(keys(%composing_peptides));
      if ($n_peptides) {
	$nondegen_protein_stats{$protein} = 1;
      }
    }

    printf("%10d  Number of unambiguously mapped proteins\n",
	   scalar(keys(%nondegen_protein_stats)));
  }


}
