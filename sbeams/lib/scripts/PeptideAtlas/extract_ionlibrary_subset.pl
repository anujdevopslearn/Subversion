#!/usr/local/bin/perl -w

use strict;

use Getopt::Long;
use Data::Dumper;

my %options;
GetOptions( \%options, 'help', 'format:s', 'output_file:s', 'min:i', 'max:i', 'width:i', 'proteins:s', 'swaths:s', 'input_file:s' );

printUsage() if $options{help};

my $infile = $options{input_file} || printUsage( "input file required" );
my $outfile = $options{output_file} || printUsage( "outfile required" );

# peakview 
# 0    Q1 [ 778.413 ]
# 1    Q3 [ 498.2579 ]
# 2    RT_detected [ 57.3 ]
# 3    protein_name [ 1/P0CG40 ]
# 4    isotype [ light ]
# 5    relative_intensity [ 7324.6 ]
# 6    stripped_sequence [ AAAAAAAAAAAAAAAASAGGK ]
# 7    modification_sequence [ AAAAAAAAAAAAAAAASAGGK ]
# 8    prec_z [ 2 ]
# 9    frg_type [ b ]
# 10   frg_z [ 1 ]
# 11   frg_nr [ 7 ]
# 12   iRT [ 57.3 ]
# 13   uniprot_id [ 1/P0CG40 ]
# 14   decoy [ FALSE ]
# 15   N [ 1 ]
# 16   confidence [ 1 ]
# 17   shared [ FALSE ]

# openswath
# 0    PrecursorMz [ 778.4129855 ]
# 1    ProductMz [ 498.26707303 ]
# 2    Tr_recalibrated [ 57.3 ]
# 3    transition_name [ 6_AAAAAAAAAAAAAAAASAGGK_2 ]
# 4    CE [ -1 ]
# 5    LibraryIntensity [ 7324.6 ]
# 6    transition_group_id [ 1_AAAAAAAAAAAAAAAASAGGK_2 ]
# 7    decoy [ 0 ]
# 8    PeptideSequence [ AAAAAAAAAAAAAAAASAGGK ]
# 9    ProteinName [ 1/P0CG40 ]
# 10   Annotation [ b7/-0.009,b14^2/-0.009,m10:16/-0.009 ]
# 11   FullUniModPeptideName [ AAAAAAAAAAAAAAAASAGGK ]
# 12   PrecursorCharge [ 2 ]
# 13   GroupLabel [ light ]
# 14   UniprotID [ 1/P0CG40 ]
# 15   FragmentType [ b ]
# 16   FragmentCharge [ 1 ]
# 17   FragmentSeriesNumber [ 7 ]

my %swath_bins;
if ( $options{min} && $options{max} && $options{width} ) {
  my $start = $options{min};
  my $end = $options{min} + $options{width};
  while ( $end < $options{max} ) {
    $swath_bins{$start} = $end;
    $start = $end;
    $end += $options{width};
  }
  $swath_bins{$start} ||= $options{max};
} elsif( $options{swaths} ) {
  open SWA, $options{swaths};
  while ( my $line = <SWA> ) {
    chomp $line;
    my @line = split( /\s+/, $line );
    $swath_bins{$line[0]} = $line[1];
    $options{min} ||= $line[0];
    $options{max} = $line[1];
    $options{width} ||= $line[1] - $line[0];
  }
  close SWA;
}

for my $start ( sort {$a <=> $b } keys( %swath_bins ) ) {
#  print "$start\t$swath_bins{$start}\n";
}

my %proteins;
if ( $options{proteins} ) {
  open PROT, $options{proteins};
  while ( my $line = <PROT> ) {
    chomp $line;
    $line =~ s/\r//g;
    chomp $line;
    my $single = '1/' . $line;
    $proteins{$single}++;
    $proteins{$line}++;
  }
  close PROT;
}

open(OUT,">$outfile") || die("ERROR: Unable to write output file $outfile");
open INFILE, $options{input_file} || die "ERROR: Unable to read '$options{input_file}'";
my $cnt = 0;
my %sbins;
while ( my $line = <INFILE>) {
  unless ( $cnt++ ) {
    print OUT $line;
    next;
  }
  chomp $line;
  my @line = split( /\t/, $line );

  my $q1 = int( $line[0] );

  if ( $q1 < $options{min} || $q1 > $options{max} ) {
#    print STDERR "$q1 is out of range!\n";
    next;
  }
  if ( !$sbins{$q1} ) {
    $sbins{$q1} = get_bin( $q1 );
#    print STDERR "bin for $q1 is $sbins{$q1}->[0] to $sbins{$q1}->[1]\n";
  }

  if ( $line[1] > $sbins{$q1}->[0] && $line[1] < $sbins{$q1}->[1] ) { 
#    print STDERR "q3 $line[1] is in target bin for $q1 !\n";
    next;
  }
  if ( $options{proteins} ) {
    my $pfield = ( $options{format} eq 'peakview' ) ? $line[13] : $line[14];

    my $ok = 0;
    if ( !$proteins{$pfield} ) {
      $pfield =~ /^(\d*)\/*(.+)$/;
      my $nprot = $1 || 0;
      my $pstr = $2 || '';
      next unless $pstr;

      if ( $nprot > 1 ) {
        my @prots = split( /\//, $pstr );
        for my $prot ( @prots ) {
          if ( $proteins{$prot} ) {
            $ok++;
            last;
          }
        }
        next unless $ok;
      }
    } else {
      $ok++;
    }
    next unless $ok;
  }
  print OUT join( "\t", @line ) . "\n";
}
close INFILE;
close OUT;

sub get_bin {
  my $q = shift;
  my $prev;
  for my $start ( sort {$a <=> $b } keys( %swath_bins ) ) {
    if ( $start > $q ) {
      return [ $prev => $swath_bins{$prev} ];
    }
    $prev = $start;
  }
  return [ $prev => $swath_bins{$prev} ];
}

# 0 Q1
# 1 Q3
# 2 RT_detected
# 3 protein_name
# 4 isotype
# 5 relative_intensity
# 6 stripped_sequence
# 7 modification_sequence
# 8 prec_z
# 9 frg_type
# 10 frg_z
# 11 frg_nr
# 12 iRT
# 13 uniprot_id
# 14 decoy

sub printUsage {
  my $msg = shift || '';
  print( <<"  END" );

  $msg

Usage:  $0 [ OPTIONS ]

  -h, --help          Print this usage information and exit
  -f, --format        Format of input file, one of peakview or openswath 
  -o, --output_file   Output TSV file
  -i, --input_file    Input TSV file to subset
      --min           Minimum m/z value for SWATH bins 
      --max           Maximum m/z value for SWATH bins 
  -w, --width         Width of swath bins
  -s, --swaths        File of user-defined swath bins
  -p, --proteins      File of user-defined proteins to include

  END
  exit;
}


