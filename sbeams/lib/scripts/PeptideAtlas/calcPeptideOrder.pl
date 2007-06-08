#!/usr/local/bin/perl -w

###############################################################################
# Program     : calcPeptideOrder.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script reads a peptide list created by
#               createPipelineInput.pl and calculates relative peptide order
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

  --source_file       Input 4-column tsv filename with columns:
                      search_batch_id sequence probability protein_name
  --P_threshold       Use this threshold for processing instead of
                      using all peptides in the input file
  --search_batch_id   If set, only process this search_batch_id and
                      ignore others

 e.g.:  $PROG_NAME --verbose 2 --source Yeast.peplist

EOU


#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "source_file:s","P_threshold:f","search_batch_id:i",
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

  my $source_file = $OPTIONS{source_file};
  unless ($source_file) {
    print "$USAGE\n";
    print "ERROR: Must supply --source_file\n\n";
    return(0);
  }

  unless (-e $source_file) {
    print "ERROR: Source file '$source_file' not found\n\n";
    return(0);
  }

  unless (open(INFILE,$source_file)) {
    print "ERROR: Unable to open source file '$source_file'\n\n";
    return(0);
  }


  my $P_threshold = $OPTIONS{P_threshold} || 0;
  my $process_search_batch_id = $OPTIONS{search_batch_id} || 0;

  my $this_search_batch_id;
  my $n_experiments = 0;

  my %peptides;
  my %matrix;

  my %other_peptides;
  my $offset_counter = 1;
  my $date;
  $date = `date`; chomp($date);
  print "$date: Starting calculation...\n";

  #### Skip header
  <INFILE>;

  #### Read in all the peptides for the first experiment
  my @columns;
  my $line;
  my $not_done = 1;
  while ($not_done) {

    #### Try to read in the next line;
    if ($line = <INFILE>) {
      chomp($line);
      @columns = split(/\t/,$line);
      next if ($columns[2] < $P_threshold);
      if ($process_search_batch_id) {
	next unless ($columns[0] == $process_search_batch_id);
      }

    #### If it fails, we're done, but still process the last batch
    } else {
      $not_done = 0;
      @columns = (-998899,'xx',-1,'zz');
    }

    #### If the this search_batch_id is not, known, learn from first record
    unless ($this_search_batch_id) {
      $this_search_batch_id = $columns[0];
      print "Processing search_batch_id=$this_search_batch_id\n";
      $n_experiments++;
    }

    #### If the search_batch_id of this peptide is not the same as the last
    #### then finish processing the last peptides of previous search_batch_id
    if ($this_search_batch_id != $columns[0]) {

      #### Process this search_batch
      foreach my $msrun (keys(%peptides)) {
	print "  Processing msrun $msrun...";
	my @scan_numbers = sort numerically keys(%{$peptides{$msrun}});
	my $n_spectrum_ids = scalar(@scan_numbers);
	print "  Found $n_spectrum_ids...";

	my %peptide_counts;
	foreach my $scan_number (@scan_numbers) {
	  my $sequence = $peptides{$msrun}->{$scan_number};
	  $peptide_counts{$sequence}++;
	}

	my $peptides_to_skip = 0;
	foreach my $pep ( keys(%peptide_counts) ) {
	  $peptides_to_skip++ if ($peptide_counts{$pep}>5);
	}
	print " skipping $peptides_to_skip peptides...\n";

	foreach my $scan_number (@scan_numbers) {
	  my $sequence = $peptides{$msrun}->{$scan_number};
	  if ($peptide_counts{$sequence} > 5) {
	    #print "  Skipping $peptide_counts{$sequence} x repeating ".
	    #  "$sequence\n";
	    next;
	  }
	  foreach my $other_scan_number (@scan_numbers) {
	    my $other_sequence = $peptides{$msrun}->{$other_scan_number};
	    if ($peptide_counts{$other_sequence} > 5) {
	      next;
	    }

	    my $offset = $other_peptides{$other_sequence};
	    unless ($offset) {
	      $other_peptides{$other_sequence} = $offset_counter;
	      $offset = $offset_counter;
	      my @tmp = ( 0,0 );
	      $matrix{$sequence}->[$offset] = \@tmp;
	      $offset_counter++;
	    }

	    my $difference = abs($scan_number - $other_scan_number);
	    if ($scan_number < $other_scan_number) {
	      #$matrix{$sequence}->[$offset]->[0]++;
	      $matrix{$sequence}->[$offset]->[0] += $difference;
	      #$matrix{$sequence}->[0] += $difference;  # produces non-linear
	      $matrix{$sequence}->[0] += 1;
	    } elsif ($scan_number > $other_scan_number) {
	      #$matrix{$sequence}->[$offset]->[1]++;
	      $matrix{$sequence}->[$offset]->[1] += $difference;
	      #$matrix{$sequence}->[0] += $difference;  # produces non-linear
	      $matrix{$sequence}->[0] += 1;
	    }
	  }
	}

      }


      #### Prepare for next search_batch_id
      $this_search_batch_id = $columns[0];
      %peptides = ();
      unless ($this_search_batch_id == -998899) {
	print "`date`: Processing search_batch_id=$this_search_batch_id\n";
	$n_experiments++;
      }

    }

    #### Put this peptide entry to the arrays
    if ($not_done) {
      my $sequence = $columns[1];
      my $spectrum = $columns[4];
      my ($msrun,$scan_number);
      if ($spectrum =~ /(.+)\.(\d+)\.(\d+)\.\d/) {
	$msrun = $1;
	$scan_number = $2;
      } else {
	print "ERROR: Unable to parse $spectrum\n";
      }

      $peptides{$msrun}->{$scan_number} = $sequence;
    }
  }

  close(INFILE);
  $date = `date`;
  print "$date: Done reading.\n";

  print "Total experiments: $n_experiments\n";
  print "Total peptides: $offset_counter\n";


  #### Calculate relative order for peptides
  $date = `date`; chomp($date);
  print "$date: Caculating peptide order...\n";
  my %peptide_scores;
  my @peptides;
  foreach my $peptide (keys(%matrix)) {
    my $before_sum = 0;
    my $after_sum = 0;
    my $total = 0;
    my $confused = 0;
    foreach my $other_peptide (keys(%other_peptides)) {
      my $offset = $other_peptides{$other_peptide};
      my $before = $matrix{$peptide}->[$offset]->[0] || 0;
      my $after = $matrix{$peptide}->[$offset]->[1] || 0;
      $before_sum += $before;
      $after_sum += $after;
      if ($before && $after) {
	$confused++;
      }
    }
    $total = $matrix{$peptide}->[0];

    #### Help reduce memory usage
    delete($matrix{$peptide});

    #print "$before_sum $after_sum $total $confused\n";
    my $score = ($after_sum-$before_sum)/$total;
    #$peptide_scores{$peptide} = $score;
    my @tmp = ( $peptide,$score,$confused );
    push(@peptides,\@tmp);
  }

  #my @sorted_peptides = sort byScore @peptides;

  $date = `date`; chomp($date);
  print "$date: Writing file...\n";
  open(OUTFILE,">out.peporder");
  foreach my $peptide (@peptides) {
    print OUTFILE "$peptide->[0]\t$peptide->[1]\t".
      "$peptide->[2]\n";
  }
  close(OUTFILE);


  $date = `date`; chomp($date);
  print "$date: Freeing memory...\n";
  return(1);

  $date = `date`; chomp($date);
  print "$date: Done.\n";
}



###############################################################################
# by_Probability
###############################################################################
sub by_Probability {

  return $b->[2] <=> $a->[2];

} # end by_Probability



###############################################################################
# numerically
###############################################################################
sub numerically {

  return $a <=> $b;

} # end numerically



###############################################################################
# byScore
###############################################################################
sub byScore {

  return $a->{score} <=> $b->{score};

} # end byScore



###############################################################################
# round
###############################################################################
sub round {

  my $value = shift;
  my $digits = shift;
  return sprintf("%.${digits}f",$value);

} # end round


