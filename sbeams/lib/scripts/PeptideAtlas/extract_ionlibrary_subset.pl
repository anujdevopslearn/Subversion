#!/usr/local/bin/perl -w

use strict;

use Getopt::Long;
use Data::Dumper;

my $ts = time();

# Read in and check options (global)
my %options;
my %colmap;
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

# spectronaut
# 
# 0    group_id [ AAAENIIPNSTGAAKAIGK.3;1796.986 ]
# 1    peptide_sequence [ AAAENIIPNSTGAAKAIGK ]
# 2    q1 [ 599.666837 ]
# 3    q3 [ 1114.61975097656 ]
# 4    q3.in_silico [ 1114.621471 ]
# 5    decoy [ NA ]
# 6    prec_z [ 3 ]
# 7    frg_type [ y ]
# 8    frg_nr [ 12 ]
# 9    frg_z [ 1 ]
# 10   relativeFragmentIntensity [ 72 ]
# 11   irt [ 30.48 ]
# 12   peptideModSeq [ AAAENIIPNSTGAAKAIGK ]
# 13   mZ.error [ 0.00172002343697386 ]
# 14   proteinInformation [ SAOUHSC_00795 ]
# 15   id [ AAAENIIPNSTGAAKAIGK.3 ]

my %stats = ( count => 0, kept => 0, pcount => 0, rt_max => 0, rt_max_minutes => 0 );
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


my %peptides;
if ( $options{peptides} ) {
  open PEP, $options{peptides};
  while ( my $line = <PEP> ) {
    chomp $line;
    $line =~ s/\r//g;
    my @line = split( /\t/, $line );
    $peptides{$line[0]}++;
  }
  close PEP;
  $stats{pepcount} = scalar( keys( %peptides ) );
  $stats{message} .= "Used $stats{pepcount} peptides for filtering\n";
}

# hash to store whether a particular ion key ( sequence + q1 )
# as reached its:
# max_limit - if so, no more fragments!
# min_limit - if so, print accumulated fragments


# hash to store whether a particular ion key ( sequence + q1 )
# as reached its:
# max_limit - if so, no more fragments!
# min_limit - if so, print accumulated fragments
# my %ion_limit = ( ELVISLIVS => { min => 0, max => 0 } );

# Hash to cache frags for an ion_key until it reaches the min_limit
my %ion_cache;

open(OUT,">$options{output_file}") || die("ERROR: Unable to write output file $options{output_file}");
open INFILE, $options{input_file} || die "ERROR: Unable to read '$options{input_file}'";
my $cnt = 0;
my %ion2bin;
my $curr_key = '';
my $curr_q1 = '';
my $curr_q3 = '';
my $ntabs;
while ( my $line = <INFILE>) {
  chomp $line;
  my @line = split( /\t/, $line );
  unless ( $cnt++ ) {
    $ntabs = scalar( @line );
    my $format_error = 0;
    if ( $options{format} eq 'peakview' ) {
      $format_error++ unless $line =~ /stripped_sequence/;
    } else {
      $format_error++ unless $line =~ /PrecursorMz/;
    }
    if ( $format_error ) {
      print STDERR "Illegal library file - missing required fields for $options{format} format\n";
      exit;
    }
    print OUT "$line\n";
    next;
  }
  $stats{count}++;
  if ( scalar( @line ) != $ntabs ) {
    print STDERR "Illegal library file - discrepancy in number of fields\n";
    exit;
  }


  my $q1 = ( $options{format} eq 'peakview' ) ? $line[0] : $line[$colmap{PrecursorMz}];
  my $q3 = ( $options{format} eq 'peakview' ) ? $line[1] : $line[$colmap{ProductMz}];

  die $line if !$q1;
  die $line if !$q3;

  if ( $q1 < $options{prec_min_mz} || $q1 > $options{prec_max_mz} ) {

#    print STDERR "$q1 is out of range!\n" if $options{verbose};
    next;
  }

  if ( $q3 < $options{frag_min_mz} || $q3 > $options{frag_max_mz} ) {
#    print STDERR "Frag mz $q3 out of range ( $options{frag_min_mz} to $options{frag_max_mz} )\n" if $options{verbose};
    next;
  }

  if ( $options{prec_frag_delta} && abs( $q1 - $q3 ) <= $options{prec_frag_delta} ) {
    print STDERR "Frag mz $q3 too close to prec mz $q1 (within $options{prec_frag_delta})\n" if $options{verbose};
    next;
  }

  # Calculate bin for this q1 value
  my $q1bin = sprintf( "%0.1f", $q1 );

  unless ( $options{no_swaths} ) {
    if ( !$ion2bin{$q1bin} ) {
      $ion2bin{$q1bin} = get_bin( $q1bin );
      if ( !$ion2bin{$q1bin} || !$q1bin  ) {
        print STDERR "Binny $q1bin\n";
        die Dumper( $ion2bin{$q1bin} );
      }
#    print STDERR "bin for $q1 is $ion2bin{$q1}->[0] to $ion2bin{$q1}->[1]\n";
    }

    if ( !$q3 || !$ion2bin{$q1bin}->[0] || !$ion2bin{$q1bin}->[1] ) { 
      die "Error with SWATH analysis: $line\n";
    }


    # Strip q3 that fall into the bin
    if ( $q3 >= $ion2bin{$q1bin}->[0] && $q3 <= $ion2bin{$q1bin}->[1] ) { 
#      print STDERR "q3 $q3 is in target bin for $q1 !\n";
#      print STDERR "Bin issue!\n" if $options{verbose};
      next 
    }
  }
  # Filter vs pre-defined list of peptides
  if ( $options{peptides} ) {
    my $pfield = ( $options{format} eq 'peakview' ) ? $line[6] : $line[$colmap{PeptideSequence}];

    my $skip = 0;

    if ( !$peptides{$pfield} ) {
      $skip++ if !$options{exclude};
    } else {
      $skip++ if $options{exclude};
    }

    if ( $skip ) {
      $stats{pep_skipped}++;
      print STDERR "no pfield!\n" if $options{verbose};
      next;
    } else {
      $stats{pep_kept}++;
    }
  }

  if ( $options{no_mc} ) {
    my $pfield = ( $options{format} eq 'peakview' ) ? $line[6] : $line[$colmap{PeptideSequence}];
    if ( $pfield  =~ /[KR][^P]/ ) {
      $stats{mc_skipped}++;
      print STDERR "no pfield!\n" if $options{verbose};
      next;
    } else {
      $stats{mc_kept}++;
    }
  }

  # Filter vs pre-defined list of proteins
  if ( $options{proteins} ) {
    my $pfield = ( $options{format} eq 'peakview' ) ? $line[13] : $line[$colmap{UniprotID}];

    my $ok = 0;
    if ( !$proteins{$pfield} ) {
      $pfield =~ /^(\d*)\/*(.+)$/;
      my $nprot = $1 || 0;
      my $pstr = $2 || '';
      if ( $options{clean_pv_names} ) {
      }
      if ( !$pstr ) {
        print STDERR "no pfield!\n" if $options{verbose};
        next;
      }

      if ( $nprot > 1 ) {
        my @prots = split( /\//, $pstr );
        for my $prot ( @prots ) {
          if ( $proteins{$prot} ) {
            $ok++;
            last;
          }
        }
        unless ( $ok ) {
          print STDERR "Not OK\n" if $options{verbose};
	  next;
	}
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


    my $dupkey = ( $options{format} eq 'peakview' ) ? join( ':', @line[7..11] ) : join( ':', @line[$colmap{FullUniModPeptideName},$colmap{PrecursorCharge},$colmap{FragmentType},$colmap{FragmentCharge},$colmap{FragmentSeriesNumber}] );
    next if $doppler{$dupkey}++;
 }

 my $rt_idx = ( $options{format} eq 'peakview' ) ? 2 : $colmap{Tr_recalibrated};
 $stats{rt_max} = $line[$rt_idx] if $line[$rt_idx] > $stats{rt_max};
 if ( $options{rt_in_minutes} ) {
   $line[$rt_idx] = sprintf( "%0.2f", $line[$rt_idx]/60 );
   $stats{rt_max_minutes} = $line[$rt_idx] if $line[$rt_idx] > $stats{rt_max_minutes};
 }

  if ( $options{excl_shared} && $line[3] =~ /[,\/]/ ) {
    next;
  }
  if ( $options{check_mass} ) {
# 11   FullUniModPeptideName [ AAAAAAAAAAAAAAAASAGGK ]
# 7    modification_sequence [ AAAAAAAAAAAAAAAASAGGK ]
    my $modseq = ( $options{format} eq 'peakview' ) ? $line[$colmap{modification_sequence}] : 
                                                      $line[$colmap{FullUniModPeptideName}]; 
# 12   PrecursorCharge [ 2 ]
    my $prec_z = ( $options{format} eq 'peakview' ) ? $line[$colmap{prec_z}] : 
                                                      $line[$colmap{PrecursorCharge}]; 

    die unless ( $q1 && $modseq && $prec_z );
    my $mass_key = $modseq . '_' . $prec_z;
    
    if ( !$options{mass_map}->{$mass_key} ) {
      $options{mass_map}->{$mass_key} = get_peptide_mass( $modseq, $prec_z );
    }

    if ( abs( $options{mass_map}->{$mass_key} - $q1 ) > 0.1 ) {
      print STDERR "$q1 is more than 1 Da from $options{mass_map}->{$mass_key} for $mass_key\n" unless $options{bad_mass}->{$mass_key}++;
      next;
    }
  }


  if ( $options{format} eq 'peakview' && $options{clean_pv_names} ) {

    for my $pidx ( 3, 13 ) {
      my $pfield = $line[$pidx];
      $pfield =~ /^(\d*)\/(.+)$/;
      my $nprot = $1 || 0;
      my $pstr = $2 || '';
      
      # Older versions of spectrast (spectrast2tsv?) used / as a delimiter
      $pstr =~ s/\//,/g;

#      print STDERR "$nprot and $pstr from $pfield\n";
      $line[$pidx] = $pstr if $pstr;
    }
    if ( $line[3] =~ /^,+$/ ) {
      $line[3] = $line[13];
    }
  }

  if ( $options{clean_sp_pipes} ) {
    for my $pidx ( 3, 13 ) {
      my $newprot;
      for my $prot ( split( /,/, $line[$pidx] ) ) {
        my @acc = split( /\|/, $prot );
        if ( scalar( @acc ) == 1 ) {
          $newprot = $prot;
        } elsif ( $acc[0] eq 'tr' || $acc[0] eq 'sp' ) {
          $newprot = $acc[1];
        } elsif ( $acc[0] eq 'CONTAM_tr' || $acc[0] eq 'CONTAM_sp' ) {
          $newprot = $acc[0] . '_' . $acc[1];
        } else {
          die "How do I clean pipes from $prot?\n";
        }
      }
      die Dumper( @line ) unless $newprot;
      $line[$pidx] = $newprot;
    }
  }

  # We may limit based on min/max number of fragments per precursor (seq + mz)
  if ( !$options{max_num_frags} && !$options{min_num_frags} ) { # No limits
    print OUT join( "\t", @line ) . "\n";
    $stats{kept}++;
    next;
  }

  my $ion_key = ( $options{format} eq 'peakview' ) ? $line[7] . $line[8] : $line[$colmap{FullUniModPeptideName}] . $line[$colmap{PrecursorMz}];
  $curr_key ||= $ion_key;

  # Time to process...
  if ( $ion_key ne $curr_key ) {
    print_extrema_list( $ion_cache{$curr_key} );
    undef $ion_cache{$curr_key};
    $curr_key = $ion_key;
  }
  $ion_cache{$ion_key} ||= [];
  push @{$ion_cache{$ion_key}}, \@line;
  $curr_q1 = $q1;
  $curr_q3 = $q3;
}
close INFILE;




close OUT;

my $tf = time();
my $tdelta = $tf - $ts;

$stats{message} .= "Max rt seen was $stats{rt_max}";
if ( $options{rt_in_minutes} ) {
  $stats{message} .= " - converted to $stats{rt_max_minutes} minutes\n";
} else {
  $stats{message} .= "\n";
}
$stats{message} .= "Kept $stats{kept} ions out of $stats{count} in the library\n";

print "Finished run in $tdelta seconds\n";
print $stats{message};


# Print min and/or max constrained list
sub print_extrema_list {

  my $ion_cache = shift || die;

  # If we have over the minimum...
  if ( scalar @{$ion_cache} >= $options{min_num_frags} ) { # Above min

    # If no max, we know we'll print all
    if ( !$options{max_num_frags} ) { # no max
      print STDERR "no max\n";
      for my $row ( @{$ion_cache} ) {
        print OUT join( "\t", @{$row} ) . "\n";
        $stats{kept}++;
      }
    } else {
      # process this ion's data
#        print STDERR "keep up to the max\n";
      my @use;
      my @defer;
      for my $row ( @{$ion_cache} ) {
        my $q1 = ( $options{format} eq 'peakview' ) ? $row->[0] : $row->[$colmap{PrecursorMz}];
        my $q3 = ( $options{format} eq 'peakview' ) ? $row->[1] : $row->[$colmap{ProductMz}];
        if ( $options{prefer_above} ) {
          if ( $q3 > $q1 ) {
#              print STDERR "$q3 is gt $q1?\n";
            push @use, $row;
          } else {
            push @defer, $row;
          }
        } else {
          push @use, $row;
        }
      }
      my $use_cnt = scalar( @use );
      my $def_cnt = scalar( @defer );
      my $use_deferred_cnt = $options{max_num_frags} - $use_cnt;
#        print "use is $use_cnt and deferred is $def_cnt, gonna use $use_deferred_cnt deffers\n";
      

      my $used = 0;
      my $def_used = 0;
      my $tot = 1;
      for my $row ( @{$ion_cache} ) {
#          print STDERR "looking at " . $tot++;
        last if $used >= $options{max_num_frags};
#          print STDERR " $used is still gt $options{max_num_frags}!\n";
        if ( $options{prefer_above} ) {
          my $q1 = ( $options{format} eq 'peakview' ) ? $row->[0] : $row->[$colmap{PrecursorMz}];
          my $q3 = ( $options{format} eq 'peakview' ) ? $row->[1] : $row->[$colmap{ProductMz}];
#            print STDERR "preferred, UD is $use_deferred_cnt and U is $def_used\n";
          if ( $q1 > $q3 ) {
            next if $use_deferred_cnt <= $def_used++;
          }
#            print STDERR "Got past it!\n";
          
        }
#          print STDERR "using $row->[6]\n";
        print OUT join( "\t", @{$row} ) . "\n";
        $stats{kept}++;
        $used++;
      }
    }
  }
}



#####

sub process_options {

  GetOptions( \%options, 'help', 
                         'format:s', 
                         'output_file:s', 
                         'excl_shared',
                         'prefer_above',
                         'prec_min_mz:f', 
                         'prec_max_mz:f', 
                         'frag_min_mz:f', 
                         'frag_max_mz:f', 
                         'min_num_frags:i', 
                         'max_num_frags:i', 
                         'width:i', 
                         'overlap:f',
                         'proteins:s', 
                         'peptides:s', 
                         'no_mc', 
                         'rt_in_minutes', 
                         'nodups',
                         'print_swaths', 
                         'swaths_file:s', 
                         'check_mass',
                         'no_swaths', 
                         'no_shared', 
                         'prec_frag_delta:f',
                         'verbose',
                         'clean_pv_names',
                         'clean_sp_pipes',
                         'exclude',
                         'split_multimapping',
                         'input_file:s' );

  printUsage() if $options{help};

  unless ( ( $options{prec_min_mz} && $options{prec_max_mz} && $options{width} ) || $options{swaths_file} || $options{no_swaths} ) {
    printUsage( "Must provide either a swaths_file, specify no_swaths, or provide prec_min_mz, prec_max_mz, and width" );
  }
  $options{prec_min_mz} ||= 0;
  $options{prec_max_mz} ||= 2000;
  $options{frag_min_mz} ||= $options{prec_min_mz};
  $options{frag_max_mz} ||= $options{prec_max_mz};
  $options{overlap} ||= 0;
  $options{clean_pv_names} = 1 if !defined $options{clean_pv_names};

  if ( $options{print_swaths} && !$options{input_file} && $options{output_file} ) {
    calculate_swath_bins();
    exit;
  }


  my $infile = $options{input_file} || printUsage( "input file required" );
  my $outfile = $options{output_file} || printUsage( "outfile required" );


  open INFILE, $options{input_file} || die "ERROR: Unable to read '$options{input_file}'";
  while ( my $line = <INFILE> ) {
    chomp $line;
    if ( $line =~ /Tr_recalibrated/ ) {
      $options{format} ||= 'openswath'; 
    }
    my $idx = 0;
    for my $col ( split(/\t/, $line) ) {
      $colmap{$col} = $idx++;
    }
    last;
  }
  close INFILE;
  $options{format} ||= 'peakview';


  my %mono = (
    G => 57.021464,
    D => 115.02694,
    A => 71.037114,
    Q => 128.05858,
    S => 87.032029,
    K => 128.09496,
    P => 97.052764,
    E => 129.04259,
    V => 99.068414,
    M => 131.04048,
    T => 101.04768,
    H => 137.05891,
    C => 103.00919,
    F => 147.06841,
    L => 113.08406,
    R => 156.10111,
    I => 113.08406,
    N => 114.04293,
    Y => 163.06333,
    W => 186.07931  );

  $options{mono} = \%mono;
  $options{mass_map} = {};
  $options{bad_mass} = {};


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

  my @return;
  for my $start ( sort {$a <=> $b } keys( %swath_bins ) ) {
    if ( $q >= $start && $q <= $swath_bins{$start} ) {
      # Are we in a boundry case?
      if ( !$return[0] ) {
        @return = ( $start, $swath_bins{$start} );
      } else {
        $return[1] = $swath_bins{$start};
      }
    }
    last if $start > $q;
  }
  return \@return;

  # Old code, does not account for ions in multiple bins.
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
      --peptides       File of user-defined peptides (tryptic?) to include
      --proteins       File of user-defined proteins to include
  -v, --verbose        Verbose mode (stand-alone)
      --print_swaths   Print SWATHS file generated by pre min/max/width/overlap 
  -c, --clean_pv_names tidy up peakview names: fix 1/name in uniprot/protein cols, fix
                       ,,, in protein col by using uniprot entry.
  -e, --excl_shared
      --no_mc          Exclude peptides with internal K/R not followed by P
      --rt_in_minutes  Divide RT field(s) by 60
      --nodups         Exclude duplicate fragments for a particular precuror - should never be a problem, probably indicates improper library construction
      --check_mass     Check to ensure fragment mz is close to theortical
      --no_swaths      No SWATHS filtering at all
 --prec_frag_delta     Filter q3 within specified range of q1, in Th
 --clean_sp_pipes      convert >sp|ACC|other => >ACC
 --split_multimapping  Split multimapping peptides to multiple entries, each with a single protein mapping [experimental]

  END
  exit;
}

sub get_peptide_mass {
  my $seq = shift;
  my $chg = shift;

  $seq =~ s/C\[CAM\]/Z/g;
  $seq =~ s/C\[160\]/Z/g;
  $seq =~ s/C\(UniMod:4\)/Z/g;
  my ($ccnt) = $seq =~ tr/Z/C/;

  $seq =~ s/C\[PCm\]/Z/g;
  $seq =~ s/C\[143\]/Z/g;
  my ($pcnt) = $seq =~ tr/Z/C/;

  $seq =~ s/M\[Oxi\]/Z/g;
  $seq =~ s/M\(UniMod:35\)/Z/g;
  $seq =~ s/M\[147\]/Z/g;
  my ($oxcnt) = $seq =~ tr/Z/M/;

  $seq =~ s/W\[Oxi\]/Z/g;
  $seq =~ s/W\(UniMod:35\)/Z/g;
#  $seq =~ s/W\[147\]/Z/g;
  $oxcnt += $seq =~ tr/Z/W/;

  $seq =~ s/E\[PGE\]/Z/g;
  $seq =~ s/E\[111\]/Z/g;
  my ($pecnt) = $seq =~ tr/Z/M/;

  $seq =~ s/Q\[PGQ\]/Z/g;
  $seq =~ s/Q\[111\]/Z/g;
  my ($pqcnt) = $seq =~ tr/Z/M/;

  if ( $seq =~ /(\[[^[]])/ ) {
    die "Unknown mod $1\n";
  }
  my $mass = 0;
  $mass += 57 * $ccnt;
  $mass += 39.99 * $pcnt;
  $mass += 15.99 * $oxcnt;
  $mass += -17.03 * $pecnt;
  $mass += -17.03 * $pqcnt;

  for my $aa ( split( '', $seq )  ){
    die "Unknown AA $aa from $seq" unless $options{mono}->{$aa};
    $mass += $options{mono}->{$aa}; 
  }
  $mass += 18;

  my $h_mass = 1.0078;
  return sprintf( '%0.4f', ( $mass + $chg * $h_mass)/$chg );
}

