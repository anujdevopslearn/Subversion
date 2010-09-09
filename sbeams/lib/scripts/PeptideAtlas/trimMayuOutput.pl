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



my $nlines = 0;
my $n_unmapped = 0;
my @lines = <INFILE>;
$nlines = scalar @lines;
print "$nlines input lines\n";

#print header
print OUTFILE $lines[0];
#read and store first line
my @fields = split(",", $lines[1]);
my $last_target_psm = int($fields[3]);
my $last_line = $lines[1];

#read successive lines
for (my $i=2; $i < $nlines; $i++) {
  my @fields = split(",", $lines[$i]);
  my $target_psm = int($fields[3]);
  my $fp_psm = int($fields[5]);
  # if this line has the same (non-zero) PSM count as the previous line ...
  if ($target_psm && ($target_psm == $last_target_psm)) {
    # compute exact final FDR
    my $fdr = sprintf("%0.7f", $fp_psm / $target_psm);
    # splice it into the previous line
    @fields = split(",", $last_line);
    $fields[2]=$fdr;
    $last_line = join(",", @fields);
    # output the (altered) previous line & quit
    print OUTFILE $last_line;
    last;
  }
  # otherwise, print the previous line, and store this line & its PSM
  # count
  print OUTFILE $last_line;
  $last_line = $lines[$i];
  $last_target_psm = $target_psm;
}

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

