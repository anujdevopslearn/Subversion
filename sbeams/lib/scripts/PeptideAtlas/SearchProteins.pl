#!/usr/local/bin/perl -w
# (won't work on regis)
# Look up each of a list of proteins in a particular atlas build.
#  Return one line per protein. Report if protein identifier is
#  unknown.

use strict;
$| = 1;  #disable output buffering

if ($#ARGV < 1) {
  print STDERR "Usage: $0 <build_type_name> <prot_list_file>\n";
  print STDERR "  Looks up each identifier in <prot_list_file> in named build.\n";
  print STDERR "  Prints all equivalent primary identifiers for which\n";
  print STDERR "  there are one or more peptides in the atlas.";
  exit;
}

my $prot_list_file = pop (@ARGV);
my $build_type_name = pop (@ARGV);

open (PROTLIST, $prot_list_file);

my $search_key;

while (my $protid = <PROTLIST>) {
  chomp ($protid);
  $protid =~ s/\s+$//; #remove trailing spaces
  $search_key = $protid;
  # if protid is from Swiss-Prot and is not a 2nd, 3rd, etc. splice
  # variant, match either P12345 or P12345-1.
  if ($search_key =~ /[OPQ]...../) {
    $search_key = "$search_key;$search_key-1";
  } elsif ($search_key =~ /([OPQ].....)-1/) {
    $search_key = "$1;$search_key";
  }
  # if protid is IPI with version extension, look for identifier
  # without version
  if ($search_key =~ /(IPI........)\.\d+/) {
    $search_key = $1;
  }
  my $cmd = "$ENV{'SBEAMS'}/cgi/PeptideAtlas/Search --command_line action=GO " .
            "output_mode=tsv " .
            "search_key=\"$search_key\" " .
            "build_type_name=\"$build_type_name\"";

  my @search_output = `$cmd`;

  my $output_line = process_search_output(\@search_output, $protid);

  print $output_line;
}

sub process_search_output {
  my $query_protid = pop(@_);
  my @search_output = @{pop (@_) };
  my $output_line;
  my %protids;  # if $query_protid has wildcard, may match multiple protids.
  my %equiv_ids;

  if ($search_output[0] =~ /There were no matches/) {
    $output_line = "$query_protid\tUNKNOWN\t\n";
  } else {
    %equiv_ids = ();
    %protids = ();
    for (my $i = 1; $i <= $#search_output; $i++) {
      my $line = $search_output[$i];
      chomp $line;
      my @fields = split("\t", $line);
      if ($#fields < 3) {  #no peptides
        next;
      }
      my $protid = $fields[0];
      $protids{$protid} = 1;
      my $equiv_id = $fields[2];
      $equiv_ids{$equiv_id} = 1;
    }
    my $equiv_id_string = join(";", keys(%equiv_ids));
    my $prot_id_string = join(";", keys(%protids));
    $output_line = "$query_protid\t$prot_id_string\t$equiv_id_string\n";
  }
  return $output_line;
}
