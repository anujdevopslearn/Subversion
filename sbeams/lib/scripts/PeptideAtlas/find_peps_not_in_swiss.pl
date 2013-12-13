#!/usr/local/bin/perl -w
use strict;
$|++;

my $sprot_file = shift;
open (P , "<$sprot_file");

my %sprot= ();
foreach my $line (<P>){
  chomp $line;
  $sprot{$line} = 1;
}

my $infh;
open ($infh, "<peptide_mapping.tsv");
my %pep = ();
while (my $line = <$infh>) {
 chomp $line;
  my @fields = split("\t", $line);
  my $pepseq = $fields[1];
  my $prot = $fields[2]; 
  next if(! $prot );
  if(not defined $pep{$pepseq}){
    $pep{$pepseq} = 0;
  }
  if(defined $sprot{$prot}){
    $pep{$pepseq}++;
  }
}
seek ($infh, 0,0);
open (OUT, ">peptide_mapping_not_swiss.tsv");
while (my $line = <$infh>) {
 chomp $line;
  my @fields = split("\t", $line);
  next if (@fields < 3);
  my $pepseq = $fields[1];
  if(defined $pep{$pepseq}){
    if($pep{$pepseq} < 1 ){
      print OUT "$line\n";
    }
  }else{
    print OUT "$line\n";
  }
}


close P;
close $infh;
exit;

