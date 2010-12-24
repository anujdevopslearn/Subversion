#!/usr/bin/perl  -w
# trimMayuOutput.pl
# Trim lines from bottom of Mayu output that present redundant info
# Alter final line so that it shows the true PSM FDR for the entire
# atlas.
#
# Terry Farrah, Institute for Systems Biology   September 2010

use strict;
use Getopt::Long;

my %options;
GetOptions( \%options, 'infile=s', 'outfile=s', 'help|?',  'verbose|s',
          );
printUsage() if $options{help} || (! defined $options{infile} ) ||
  ( ! defined $options{outfile} );

my $verbose = $options{verbose};

my $infile = $options{infile};
open (INFILE, $infile) || die "Can't open $infile for reading";

my $outfile = $options{outfile};
open (OUTFILE, ">".$outfile) || die "Can't open $outfile for writing";


my @lines = <INFILE>;
my $nlines = scalar @lines;
printf ("%d input data lines, ", $nlines-1);

#echo header
print OUTFILE $lines[0];

my $last_line_to_echo;
my $last_line = "";
my $n_output_lines;
my (@fields_2, $target_psm_2, $fp_psm_2);
for (my $i=$nlines-1; $i>0; $i--) {
  if ($i>1) {
    @fields_2 = split(",", $lines[$i]);
    $target_psm_2 = int($fields_2[3]);
    $fp_psm_2 = int($fields_2[5]);
    my @fields_1 = split(",", $lines[$i-1]);
    my $target_psm_1 = int($fields_1[3]);
    my $fp_psm_1 = int($fields_1[5]);
    next if (($target_psm_1 == $target_psm_2) && ($fp_psm_1 == $fp_psm_2));
  }
  # if we get here, we're at the last output line.
  # compute exact final FDR
  my $fdr;
  if ($target_psm_2 == 0) {
    $fdr = 0;
  } else {
    $fdr = sprintf("%0.7f", $fp_psm_2 / $target_psm_2);
  }
  # splice it into the previous line
  $fields_2[2]=$fdr;
  $last_line = join(",", @fields_2);
  $n_output_lines=$i;
  last;
}

for (my $i=1; $i<$n_output_lines; $i++) {
  print OUTFILE $lines[$i];
}
print OUTFILE $last_line;
print "$n_output_lines output data lines.\n";


sub printUsage {
  print( <<"  END" );

Usage:  $0 

  -h, --help             Print this usage information and exit
  -i, --infile           Untrimmed Mayu output .csv file to process
  -o, --outfile          Output filename for trimmed file
  -v, --verbose          Print details about execution.
 
  END
  exit;
}

__DATA__
nr_runs,nr_files,mFDR,target_PSM,decoy_PSM,FP_PSM,TP_PSM,target_pepID,decoy_pepID,FP_pepID,FP_pepID_stdev,TP_pepID,pepFDR,target_protID,decoy_protID,FP_protID,FP_protID_stdev,TP_protID,protFDR,target_protIDs,decoy_protIDs,FP_protIDs,TP_protIDs,protFDRs,target_protIDns,decoy_protIDns,FP_protIDns,TP_protIDns,protFDRns
562,1,0,260499,0,0,260499,5995,0,0,0.00000000,5995,0.00000000,1294,0,0,0.00000000,1294,0.00000000,131,0,0,131,0.00000000,1163,0,0,1163,0.00000000
562,1,0.0001,298204,29,29,298175,7376,11,11,0.12726899,7365,0.00148912,1503,11,11,0.17255524,1492,0.00729882,171,10,10,161,0.05832068,1332,1,1,1331,0.00074871
562,1,0.0002,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0003,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0004,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0005,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0006,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0007,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0008,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0009,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.001,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0011,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0012,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0013,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0014,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158
562,1,0.0015,314370,55,55,314315,8078,20,20,0.17948849,8058,0.00247187,1609,20,20,0.33165469,1589,0.01235855,192,13,13,179,0.06731867,1417,7,7,1410,0.00491158

