#!/usr/local/bin/perl -w
use strict;
$|++;

open (my $infh, "peptides_mappable_to_swiss.tsv");
my %swiss_peps;
while (my $line = <$infh>) {
  chomp $line;
  $swiss_peps{$line} = 1;
}
close $infh;

open ($infh, "peptide_mapping.tsv");
%swiss_peps;
while (my $line = <$infh>) {
  chomp $line;
  my @fields = split("\t", $line);
  my $pepseq = $fields[1];
  if (! defined $pepseq) {
    print STDERR "$line\n";
  } elsif (!defined $swiss_peps{$pepseq}) {
    print $line, "\n";
  }
}
