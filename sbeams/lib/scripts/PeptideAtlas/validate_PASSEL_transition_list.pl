#!/usr/local/bin/perl

# Validate a .tsv transition list file for PASSEL.
#   - Check for required columns
#   - Check data types
#   - Print some stats
# Terry Farrah  June 2013

use strict;
$|=1;
my $exit_on_first_error = 0;

my @required_column_names = (
   'q1','q3','sequence','prec_z','frg_type','frg_z','frg_nr','transition_group_id',
);
my %required_column_names = map { $_ => 1 } @required_column_names;
my %col_idx;

# Read column names and index
my $header = <STDIN>;
chomp $header;
my @fields = split("\t", $header);
my $i = 0;
for my $field (@fields) {
  $field = lc($field);
  #print "|$field|\n";
  $col_idx{$field} = $i;
  $i++;
}
# Check that required columns exist
for my $name (@required_column_names) {
  if (! defined $col_idx{$name}) {
    print "No $name column.\n";
    exit;
  }
}

# Read and validate the data
my $min_prec_z = 1000;
my $max_prec_z = 0;
my $min_frg_z = 1000;
my $max_frg_z = 0;
my $min_frg_nr = 1000;
my $max_frg_nr = 0;
my %frg_types;
my %q1_digits;
my %q3_digits;
my $min_q1 = 50000;
my $max_q1 = 0;
my $min_q3 = 50000;
my $max_q3 = 0;
my $n_heavy;
my $n_light;
my $n_no_isotype;
my %sequences;
my %mods;
my %pep_to_q1;


my $n=0;
while (my $line = <STDIN>) {
  chomp $line;
  my @fields = split("\t", $line);
  $n++;

  # Check q1, q3 columns
  my $q1 = $fields[$col_idx{'q1'}];
  if ($q1 =~ /^\d+$/) {
    $q1_digits{0}++;
  } elsif ($q1 =~ /^\d+\.(\d+)$/) {
    $q1_digits{length($1)}++;
  } else {
    print "line $n: q1 not float: |$q1|\n";
    exit if $exit_on_first_error;
  }
  if ($q1 > $max_q1) {
    $max_q1 = $q1;
  }
  if ($q1 < $min_q1) {
    $min_q1 = $q1;
  }

  my $q3 = $fields[$col_idx{'q3'}];
  if ($q3 =~ /^\d+$/) {
    $q3_digits{0}++;
  } elsif ($q3 =~ /^\d+\.(\d+)$/) {
    $q3_digits{length($1)}++;
  } else {
    print "line $n: q3 not float: |$q3|\n";
    exit if $exit_on_first_error;
  }
  if ($q3 > $max_q3) {
    $max_q3 = $q3;
  }
  if ($q3 < $min_q3) {
    $min_q3 = $q3;
  }

  # Check prec_z, frg_z, frg_nr columns.
  my $prec_z = $fields[$col_idx{'prec_z'}];
  if ($prec_z !~ /^\d+$/) {
    print "line $n: prec_z not integer: |$prec_z|\n";
    exit if $exit_on_first_error;
  }
  if ($prec_z < $min_prec_z) {
    $min_prec_z = $prec_z;
  }
  if ($prec_z > $max_prec_z) {
    $max_prec_z = $prec_z;
  }

  my $frg_z = $fields[$col_idx{'frg_z'}];
  if ($frg_z !~ /^\d+$/) {
    print "line $n: frg_z not integer: |$frg_z|\n";
    exit if $exit_on_first_error;
  }
  if ($frg_z < $min_frg_z) {
    $min_frg_z = $frg_z;
  }
  if ($frg_z > $max_frg_z) {
    $max_frg_z = $frg_z;
  }

  my $frg_nr = $fields[$col_idx{'frg_nr'}];
  if ($frg_nr !~ /^\d+$/) {
    print "line $n: frg_nr not integer: |$frg_nr|\n";
    exit if $exit_on_first_error;
  }
  if ($frg_nr < $min_frg_nr) {
    $min_frg_nr = $frg_nr;
  }
  if ($frg_nr > $max_frg_nr) {
    $max_frg_nr = $frg_nr;
  }

  # Check frg_type column
  my $frg_type = $fields[$col_idx{'frg_type'}];
  if ($frg_type !~ /^\w$/) {
    print "line $n: frg_type not single char: |$frg_type|\n";
    exit if $exit_on_first_error;
  }
  $frg_types{$frg_type} = 1;

  # Check isotype column, if exists
  my $isotype;
  if (defined $col_idx{'isotype'}) {
    $isotype = $fields[$col_idx{'isotype'}];
    if ($isotype =~ m/light/i) {
      $n_light++;
    } elsif ($isotype =~ m/heavy/i) {
      $n_heavy++;
    } elsif ($isotype == '') {
      $n_no_isotype++;
      $isotype = 'none';
    } else {
      print "line $n: unknown isotype: |$isotype|\n";
      exit if $exit_on_first_error;
    }
  } else {
    $isotype = 'light';
  }

  # Check sequence
  my $sequence = $fields[$col_idx{'sequence'}];
  $sequences{$sequence}++;
  my @mods = ($sequence =~ m/(.\[.+?\])/g);
  for my $mod (@mods) {
    if ($mod !~ /^.\[\d+\]$/) {
      print "line $n: bad mod: |$mod|\n";
      exit if $exit_on_first_error;
    }
    $mods{$mod}++;
  }

  # Map peptide to q1
  if (defined $pep_to_q1{$sequence}->{$prec_z}->{$isotype}) {
    if ($pep_to_q1{$sequence}->{$prec_z}->{$isotype} != $q1) {
      print "Warning: multiple q1 for $sequence $isotype $prec_z($pep_to_q1{$sequence}->{$prec_z}->{$isotype}, $q1)\n";
    }
  } else {
    $pep_to_q1{$sequence}->{$prec_z}->{$isotype} = $q1;
  }

  # Check transition_group_id
  my $transition_group_id = $fields[$col_idx{'transition_group_id'}];
  if ($transition_group_id !~ /^\S+?\.\S+$/) {
    print "line $n: bad transition_group_id: |$transition_group_id|\n";
    exit if $exit_on_first_error;
  } elsif ($transition_group_id =~ /(^\S+?)\.(\S+)$/) {
    my $tgi_seq = $1;
    my $tgi_z = $2;
    if ($sequence != $tgi_seq) {
      print "line $n: mismatched sequence in transition_group_id: |$transition_group_id| |$tgi_seq|!=|$sequence|\n";
      exit if $exit_on_first_error;
    } elsif ($prec_z != $tgi_z) {
      print "line $n: mismatched prec_z in transition_group_id: |$transition_group_id|  |$tgi_z|!=|$prec_z|\n";
      exit if $exit_on_first_error;
    }
  }

  # Check relative intensity, if exists
  my $rel_int;
  if (defined $col_idx{'relative_intensity'}) {
    $rel_int = $fields[$col_idx{'relative_intensity'}];
    if (($rel_int =~ /^\d+$/) || ($rel_int =~  /^\d+\.(\d+)$/)) {
      if ($rel_int > 100) {
	print "line $n: relative_intensity greater than 1: |$rel_int|\n";
	exit if $exit_on_first_error;
      }
    } elsif ($rel_int == '') {
      $rel_int = 0;
    } else {
      print "line $n: relative_intensity not float: |$rel_int|\n";
      exit if $exit_on_first_error;
    }
  }
}

# Print summary
print "q1 range ${min_q1} - ${max_q1}\n";
print "Digits after decimal: ";
for my $n (sort keys %q1_digits) {
  print "$n=$q1_digits{$n} ";
}
print "\n";
print "q3 range ${min_q3} - ${max_q3}\n";
print "Digits after decimal: ";
for my $n (sort keys %q3_digits) {
  print "$n=$q3_digits{$n} ";
}
print "\n";
print "prec_z range ${min_prec_z}-${max_prec_z}\n";
print "frg_types: ";
for my $frg_type (sort keys %frg_types) {
  print "$frg_type ";
}
print "\n";
print "frg_nr range ${min_frg_nr}-${max_frg_nr}\n";
print "frg_z range ${min_frg_z}-${max_frg_z}\n";

if (defined $col_idx{'isotype'}) {
  print "$n_light light\n" if $n_light;
  print "$n_heavy heavy\n" if $n_heavy;
  print "$n_no_isotype no isotype\n" if $n_no_isotype;
} else {
  print "No isotype column.\n";
}

my $nseqs = scalar keys %sequences;
my %seqs_per_count;
print "$nseqs different modified peptides\n";
for my $seq (sort keys %sequences) {
  $seqs_per_count{$sequences{$seq}}++;
}
for my $count (sort {$a <=> $b} keys %seqs_per_count) {
  print "$count Tx: $seqs_per_count{$count} peps\n";
}

print "Modifications:\n";
for my $mod (sort keys %mods) {
  print "  $mod $mods{$mod}\n";
}

print "$n lines validated.\n";
