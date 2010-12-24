#!/usr/local/bin/perl -w
# Insert four columns for local protein FDR to Mayu .csv output.
# Makes use of STDIN and STDOUT.
# Terry Farrah    Oct. 2010

$|++;   # disable output buffering
use strict;

# Calculate local FDRs by comparing to previous step, 5 steps ago, etc.
my @step_sizes = (1, 5, 10, 25);
my $n_step_sizes = scalar @step_sizes;

# Read header & get indices for target_protID, FP_protID, protFDR
# Then output modified header
my $line = <STDIN>;
chomp $line;
my @header_fields = split(",",$line);
my( $n_target_idx )= grep { $header_fields[$_] eq "target_protID" }
  0..$#header_fields;
my( $n_fp_idx )= grep { $header_fields[$_] eq "FP_protID" }
  0..$#header_fields;
my( $protFDR_idx )= grep { $header_fields[$_] eq "protFDR" }
  0..$#header_fields;
my @lFDR_header_fields = ();
for my $step (@step_sizes) {
  push (@lFDR_header_fields, sprintf("lFDR_%d", $step));
}
splice (@header_fields, $protFDR_idx+1, 0, @lFDR_header_fields);
my $header = join (",", @header_fields);
print $header, "\n";


# Process the data, calculating the four different local FDRs for each
# line and inserting those values into the line.
my @lines = <STDIN>;
my $nlines = scalar @lines;
my $ra_fields;
for (my $i = 0; $i < $nlines; $i++) {
  my $line = $lines[$i];
  chomp $line;
  my @fields = split(",",$line);
  $ra_fields->[$i] = \@fields;
  my @local_fdr = ();
  my $ra_local_fdr = \@local_fdr;
  for (my $j = 0; $j < $n_step_sizes; $j++) {
    my $steps = $step_sizes[$j];
    if ( $i >= $steps ) {
      my $target_diff = $ra_fields->[$i]->[$n_target_idx] -
			$ra_fields->[$i-$steps]->[$n_target_idx];
      my $fp_diff = $ra_fields->[$i]->[$n_fp_idx] -
		    $ra_fields->[$i-$steps]->[$n_fp_idx];
      if ($fp_diff == 0) {
	$ra_local_fdr->[$j] = 0;
      } elsif ($target_diff == 0) {
	$ra_local_fdr->[$j] = 1;
      } else {
	$ra_local_fdr->[$j] = $fp_diff / $target_diff;
      }
    } else {
      $ra_local_fdr->[$j] = 0;
    }
    $ra_local_fdr->[$j] = sprintf ("%0.3f", $ra_local_fdr->[$j]);
  }
  splice (@fields, $protFDR_idx+1, 0, @{$ra_local_fdr});
  my $outline = join (",", @fields);
  print $outline, "\n";
}
