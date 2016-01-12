#!/usr/local/bin/perl -w

use strict;

use Getopt::Long;
use Data::Dumper;

my $ts = time();

# Read in and check options (global)
my %options;
process_options();

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

my %stats = ( count => 0, kept => 0, pcount => 0 );
my %swath_bins = calculate_swath_bins();

my %doppler;

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
    $stats{pcount}++;
  }
  close PROT;
  $stats{message} .= "Used $stats{pcount} proteins for filtering\n";
}

# hash to store whether a particular ion key ( sequence + q1 )
# as reached its:
# max_limit - if so, no more fragments!
# min_limit - if so, print accumulated fragments
my %ion_limit = ( ELVISLIVS => { min => 0, max => 0 } );

# Hash to cache frags for an ion_key until it reaches the min_limit
my %ion_cache;

open(OUT,">$options{output_file}") || die("ERROR: Unable to write output file $options{output_file}");
open INFILE, $options{input_file} || die "ERROR: Unable to read '$options{input_file}'";
my $cnt = 0;
my %ion2bin;
while ( my $line = <INFILE>) {
  unless ( $cnt++ ) {
    print OUT $line;
    next;
  }
  $stats{count}++;
  chomp $line;
  my @line = split( /\t/, $line );

  my $q1 = $line[0];
  if ( $q1 < $options{prec_min_mz} || $q1 > $options{prec_max_mz} ) {
#    print STDERR "$q1 is out of range!\n";
    next;
  }

  if ( $line[1] < $options{frag_min_mz} || $line[1] > $options{frag_max_mz} ) {
#    print STDERR "$q1 is out of range!\n";
    next;
  }

  # Calculate bin for this q1 value
  $q1 = sprintf( "%0.1f", $line[0] );

  unless ( $options{no_swaths} ) {
    if ( !$ion2bin{$q1} ) {
      $ion2bin{$q1} = get_bin( $q1 );
#    print STDERR "bin for $q1 is $ion2bin{$q1}->[0] to $ion2bin{$q1}->[1]\n";
    }
    # Strip q3 that fall into the bin
    if ( $line[1] >= $ion2bin{$q1}->[0] && $line[1] <= $ion2bin{$q1}->[1] ) { 
#      print STDERR "q3 $line[1] is in target bin for $q1 !\n";
      next 
    }
  }

  # Filter vs pre-defined list of proteins
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
      } else {
        if ( $proteins{$pstr} ) {
          $ok++;
        }  
        if ( !$ok ) {  # O Schubert hack
          my @parts = split( /_/, $pstr );
          if ( $parts[0] && $parts[1] && ( $parts[0] eq $parts[1] ) ) {
            $pstr = $parts[0];
            if ( $proteins{$pstr} ) {
              $ok++;
            }  
          }
        }
      }
    } else {
      $ok++;
    }
    next unless $ok;
  }

  if ( $options{nodups} ) {
    # openswath 11,12,15,16,17 ( modpep, pre_z, f_type, f_z, f_series )
    # peakview 7, 8, 9, 10, 11
    my $dupkey = ( $options{format} eq 'peakview' ) ? join( ':', @line[7..11] ) : join( ':', @line[11,12,15,16,17] );
    next if $doppler{$dupkey}++;
 }

  # We may limit based on min/max number of fragments per precursor (seq + mz)
  if ( $options{max_num_frags} || $options{min_num_frags} ) {

    my $ion_key = ( $options{format} eq 'peakview' ) ? $line[6] . $line[0] : $line[8] . $line[0];
    $ion_limit{$ion_key} ||= { min => 0, max => 0 };

    if ( $options{max_num_frags} ) {
 
      # First check list of keys known to be over max
      if ( $ion_limit{$ion_key}->{max} >= $options{max_num_frags} ) {
        next;
      }
      # Record the fact that we're (potentially) using this ion
      $ion_limit{$ion_key}->{max}++;
    }

    if ( $options{min_num_frags} ) {

      # First check list of keys known to be over min
      if ( !$ion_limit{$ion_key}->{min} ) {
        $ion_cache{$ion_key} ||= [];
        push @{$ion_cache{$ion_key}}, \@line;

        if ( scalar @{$ion_cache{$ion_key}} >= $options{min_num_frags} ) {
          # Record the fact that we're (potentially) using this ion
          $ion_limit{$ion_key}->{min}++;
          for my $row ( @{$ion_cache{$ion_key}} ) {
            print OUT join( "\t", @{$row} ) . "\n";
            $stats{kept}++;
          }
          undef $ion_cache{$ion_key};
        }
        next;
      }
    } 
  }




  $stats{kept}++;

  print OUT join( "\t", @line ) . "\n";
}
close INFILE;
close OUT;

my $tf = time();
my $tdelta = $tf - $ts;

$stats{message} .= "Kept $stats{kept} ions out of $stats{count} in the library\n";

print "Finished run in $tdelta seconds\n";
print $stats{message};

sub process_options {

  GetOptions( \%options, 'help', 
                         'format:s', 
                         'output_file:s', 
                         'prec_min_mz:i', 
                         'prec_max_mz:i', 
                         'frag_min_mz:i', 
                         'frag_max_mz:i', 
                         'min_num_frags:i', 
                         'max_num_frags:i', 
                         'width:i', 
                         'overlap:f',
                         'proteins:s', 
                         'nodups',
                         'print_swaths', 
                         'swaths_file:s', 
                         'no_swaths', 
                         'input_file:s' );

  printUsage() if $options{help};

  unless ( ( $options{prec_min_mz} && $options{prec_max_mz} && $options{width} ) || $options{swaths_file} || $options{no_swaths} ) {
    printUsage( "Must provide either a swaths_file, specify no_swaths, or provide prec_min_mz, prec_max_mz, and width" );
  }
  $options{prec_min_mz} ||= 0;
  $options{prec_max_mz} ||= 1800;
  $options{frag_min_mz} ||= $options{prec_min_mz};
  $options{frag_max_mz} ||= $options{prec_max_mz};
  $options{overlap} ||= 0;
  $options{format} ||= 'peakview';

  if ( $options{print_swaths} && !$options{input_file} && $options{output_file} ) {
    calculate_swath_bins();
    exit;
  }


  my $infile = $options{input_file} || printUsage( "input file required" );
  my $outfile = $options{output_file} || printUsage( "outfile required" );

}

sub calculate_swath_bins {

  my %swath_bins;
  return %swath_bins if $options{no_swaths};

  # Manually set min, max, and width take precedence
  if ( $options{prec_min_mz} && $options{prec_max_mz} && $options{width} ) {
    my $start = $options{prec_min_mz};
    my $end = $options{prec_min_mz} + $options{width};
    my $bin_cnt = 0;
    while ( $end < $options{prec_max_mz} ) {
      my $over = ( $bin_cnt++ ) ? $options{overlap} : 0;
#     print "Over is $over, $options{overlap}, bin_cnt is $bin_cnt\n";
      $swath_bins{$start - $over} = $end + $options{overlap};
      $start = $end;
      $end += $options{width};
    }
    $swath_bins{$start - $options{overlap}}  ||= $options{prec_max_mz};

    if ( $options{print_swaths} ) {
      print_swaths( %swath_bins );
    }

  # Else use user-supplied SWATHS file
  } elsif( $options{swaths_file} ) {
    open SWA, $options{swaths_file};
    while ( my $line = <SWA> ) {
      chomp $line;
      $line =~ s/\r//g;
      chomp $line;
      my @line = split( /\s+/, $line );
      $swath_bins{$line[0]} = $line[1];
      $options{prec_min_mz} ||= $line[0];
      $options{prec_min_mz} = $line[0] if $line[0] < $options{prec_min_mz};
      $options{prec_max_mz} ||= $line[1];
      $options{prec_max_mz} = $line[1] if $line[1] > $options{prec_max_mz};
      $options{width} ||= $line[1] - $line[0];
    }
    close SWA;
    $options{frag_min_mz} ||= $options{prec_min_mz};
    $options{frag_max_mz} ||= $options{prec_max_mz};
  }
  unless ( scalar( keys( %swath_bins ) ) ) {
    print STDERR "No valid SWATHS found, exiting.\n";
    exit;
  }
  return( %swath_bins );
}

sub print_swaths {
  my %swath_bins = @_;
  my $swath_file = $options{output_file} . '.swaths';
  open SWA, ">$swath_file";
  for my $bin ( sort {$a <=> $b} keys( %swath_bins ) ) {
    print SWA "$bin\t$swath_bins{$bin}\n";
  }
  close SWA;
}

sub get_bin {
  my $q = shift;
  my $min;
  my $max;
  my $prev;
  if ( !scalar( %swath_bins ) ) {
    die "No SWATH bins set";
  }
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

  -h, --help           Print this usage information and exit
  -f, --format         Format of input file, one of peakview or openswath 
      --output_file    Output TSV file
  -i, --input_file     Input TSV file to subset
      --prec_min_mz    Minimum m/z value for SWATH bins (q1)
      --prec_max_mz    Maximum m/z value for SWATH bins (q1)
  -w, --width          Width of swath bins
      --overlap        Amount of overlap between adjacent SWATH bins
      --frag_min_mz    Minimum m/z value for fragment ions
      --frag_max_mz    Maximum m/z value for fragment ions 
      --min_num_frags  Minimum number of fragments per q1
      --max_num_frags  Maximum number of fragments per q1
  -s, --swaths_file    File of user-defined swath bins
      --proteins       File of user-defined proteins to include
      --print_swaths   Print SWATHS file generated by pre min/max/width/overlap 

  END
  exit;
}


