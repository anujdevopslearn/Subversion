#!/usr/bin/perl -w
#  regis: /usr/bin/perl   mimas: /usr/local/bin/perl
# paidentlist2mayu.pl
# Convert PAidentlist file to Mayu input format,
#  using adjusted probabilities (not initial probabilities).
# Takes no command line arguments; uses stdin and stdout.
# Terry Farrah, Institute for Systems Biology   January, 2009

use strict;

sub getmods{
  my %args = @_;
  my $modseq = $args{'modseq'};
  my $inmod = 0;
  my $modmass = "";
  my $pos = 1;
  my $modpos;
  my $mods = "";
  my @chars = split '', $modseq;
  foreach my $char (@chars) {
    if ($char eq "[") {
      $inmod = 1;
      $modpos = $pos-1;
    }
    elsif ($char eq "]") {
      #print $modpos, " ", $modmass, "\n";
      $mods = $mods . sprintf("%d=%d:", $modpos, $modmass);
      #print $mods, "\n";
      $modmass = "";
      $inmod = 0;
    }
    elsif ($inmod) {  # we're inside a pair of square brackets
      $modmass = $modmass . $char;
    }
    else {   # char is an amino acid
      $pos++;
    }
  }
  # remove final colon
  #print $modseq;
  if ($mods ne "") { chop($mods); }
  #print " final mods = ", $mods, "\n";
  return ($mods);
}

while (my $line = <STDIN>) {
  chomp($line);
  # parse input line into fields
  my ($a, $scan, $b, $seq, $c, $modseq, $d, $e,
         $probability, $f, $proteinID, $adj_prob, $g, $h) =
    split(/\s+/,$line);
  # construct Mayu modification field from modified peptide string
  #  (all other fields are direct copies from input)
  my $mods = getmods(modseq => $modseq);
  # output line
  if (defined $adj_prob) {
    printf("%s,%s,%s,%s,%s\n",
         $scan, $seq, $proteinID, $mods, $probability);
  }
}
