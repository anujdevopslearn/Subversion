#!/usr/local/bin/perl 


use strict;
use lib( '/regis/sbeams/lib' );
use lib "/net/dblocal/www/html/devDC/sbeams/lib/perl/";
use FAlite;
use FindBin;
use Getopt::Long;

use lib "$FindBin::Bin/../../perl/";
use SBEAMS::Connection qw($q);
use SBEAMS::PeptideAtlas;

my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

$|++;

my $opts = get_options();

my $time = time();
my ($sec,$min,$hour,$mday,$mon,$year) = localtime($time);
print STDERR "Starting run: $hour:$min:$sec\n";

# General reporting hash
my %stats;

# read in protein file
print STDERR "reading fasta file..." if $opts->{verbose};
my ( $seq2acc, $acc2seq, $allpeptides ) = read_fasta();
my $manually_mapped = read_manual();
print STDERR "Done\n" if $opts->{verbose};
my @seqs = keys( %{$seq2acc} );
my @accs = keys( %{$acc2seq} );
print STDERR "Found " . scalar(@seqs) . " distinct sequences in " . scalar(@accs) . " entries\n" if $opts->{verbose};

if ( $opts->{output_file} ) {
  open( OUT, ">$opts->{output_file}" ) || die "Unable to open $opts->{output_file}: $!\n";
} else {
  open( OUT, ">&STDOUT" ) || die "Unable to open dup STDOUT\n";
}

my %peps;  # Stores pepseq => mapped acc string
my %prots; # Stores protein => hashref of mapped peptides

my %tested;  # Keep from analyzing non-mapping peptides more than once.

# Loop over peptides.
open( PEPS, "$opts->{peptide_file}") || die "Couldn't open $opts->{peptide_file}: $!\n";
  
print STDERR "Looping over peptides..." if $opts->{verbose};


while( my $line = <PEPS> ) {
  chomp $line;
  my @line = split( "\t", $line );
  $stats{line_count}++;

  if ( $opts->{init_mapping} && $opts->{init_mapping} > $stats{line_count} ) {
    print STDERR "Skipping line $stats{line_count} as per user\n";
    print OUT "$line\n";
    next;
  } 

  if ( $opts->{column_labels} && ($opts->{column_labels} >= $stats{line_count}) ) { 
    if ( $opts->{column_labels} == $stats{line_count} ) {  # Only print on last
      if ( $opts->{mapping_out} ) {
        if ( $opts->{omit_match_seq} ) {
          print OUT join( "\t", @line, ( 'protein_cnt', 'protein_string') ) . "\n" 
        } else {
          print OUT join( "\t", @line, ('matching_seq', 'protein_cnt', 'protein_string') ) . "\n" 
        }
      }
    } else {
      print OUT join( "\t", @line ) . "\n";
    }
    next;
  }

  my $pepseq = $line[$opts->{seq_idx}];
  $pepseq =~ s/\s//g;
  if ( $opts->{ZtoC} ) {
    $pepseq =~ s/Z/C/g;
  }
  if ( $opts->{strip_mods} ) {
    $pepseq =~ s/\[\d+\]//g;
  }

  my $matching_seq = $pepseq;
 
  unless ( $pepseq ) {
    if( $opts->{blank_skip} ) {
      if ( $opts->{mapping_out} ) {
        print OUT join( "\t", @line ) . "\n";
      } else {
        print join( "\t", @line ) . "\n";
      }
      next;
    } else {
      die "Error, no peptide in $line\n";
    }
  }
  $stats{total}++;

  print STDERR '*' unless $stats{total} % 100;
  print STDERR "\n" unless $stats{total} % 5000;

  unless ( $tested{$pepseq} ) {

    my $matched = '';
    if ( $opts->{n_convert} ) {
      $matched = map_peptide( $pepseq );
      if ( $matched ) {
#        print "NnotD: $pepseq\n";
        $stats{NnotD}++;
      } else {
        my $alt_pepseq = $pepseq;
        $alt_pepseq =~ s/D([^P][ST])/N$1/g;
        $matched = map_peptide( $alt_pepseq );
        if ( $matched ) {
          $matching_seq = $alt_pepseq;
          $stats{nxst_rescued}++;
        } elsif( !$opts->{suppress_brute} ) {
          # Did work the first time, so...
          $matched = map_peptide( $pepseq, 1 );
          if ( !$matched ) {
            $matched = map_peptide( $alt_pepseq, 1 );
          }
          if ( $matched ) {
            $stats{peptide_ok_brute}++;
          } else {
            $stats{nxst_stranded}++;
            my $tmp = $pepseq;
            $tmp =~ s/[ND].[ST]/-/g;
            my $mcnt = $tmp =~ s/-/-/g;
            $mcnt ||= 0;
            $stats{'motif_cnt_' . $mcnt}++;
          }
#        if ( $mcnt == 1 ) { print "$pepseq has only one!\n"; }
        } # End altseq matching attempt
      } # End if matched else
    } elsif ( $opts->{d2n_force} ) {
      my $ndseq = $pepseq;
      $ndseq =~ s/D/N/g;
      $ndseq =~ s/D/N/;
#      die "$ndseq from $pepseq\n";
      $matched = map_peptide( $ndseq );
      $matching_seq = $ndseq;
      if ( !$matched ) {
        # Force mapping
        $matched = map_peptide( $ndseq, 1 ) unless $opts->{suppress_brute};
        if ( $matched ) {
          $matching_seq = $ndseq;
          $stats{peptide_map_ok_brute}++;
        } else {
          print "MIA: >$pepseq<\n" if $opts->{show_mia};
        }
      } else {
        $stats{peptide_map_ok}++;
      }
    } else { # End if n_convert
      $matched = map_peptide( $pepseq );
      if ( !$matched ) {
        # Force mapping
        $matched = map_peptide( $pepseq, 1 ) unless $opts->{suppress_brute};
        if ( $matched ) {
          $stats{peptide_map_ok_brute}++;
        } else {
          print "MIA: >$pepseq<\n" if $opts->{show_mia};
        }
      }
    } # End if n_convert else 

    if ( $matched  ) {
      $stats{peptide_map_ok}++;
    } else {
      $stats{peptide_map_no}++;
      print "MIA: $pepseq\n" if $opts->{show_mia};
      $matching_seq = 'na';
    }
    $tested{$pepseq}++;
  }

  my $prot_str = 'na';
  my $prot_cnt = 0;
  if ( $peps{$matching_seq} ) {
    $prot_str = $peps{$matching_seq};
    $prot_cnt = $prot_str =~ tr/,/,/;
    $prot_cnt += 1;
  } 

  if ( $opts->{acc_sep_char} ne ',' ) {
    $prot_str =~ s/,/$opts->{acc_sep_char}/g;
  }

  if ( $opts->{mapping_out} ) {
    if ( $opts->{omit_match_seq} ) {
      print OUT join( "\t", $line, $prot_cnt, $prot_str ) . "\n";
    } else {
      print OUT join( "\t", $line, $matching_seq, $prot_cnt, $prot_str ) . "\n";
    }
  }

}
close OUT;

if ( $opts->{show_nomap} ) {
  open NOMAP, ">nomap.acc";
}
if ( $opts->{show_himap} ) {
  open HIMAP, ">himap.acc";
}
print "\n";
for my $acc ( keys( %{$acc2seq} ) ) {
  next unless $acc;

  my $n_peps = 0;

  # increment each prot in the manually mapped list by one
  if ( $manually_mapped && $manually_mapped->{$acc} ) {
    $n_peps++;
  }
  


  if ( $prots{$acc} ) {
    if ( $opts->{nocount_degen} ) {
      for my $mapped_pep (  keys( %{$prots{$acc}} ) ) {
        if ( !$allpeptides->{$mapped_pep} ) { # Should have a mapping
          print STDERR "DANGER, mapped pep doesn't map, D'oh!\n";
          exit;
        } elsif ( scalar( keys( %{$allpeptides->{$mapped_pep}} ) ) > 1 ) { # Degenerate
          print "REGEN: >$mapped_pep $allpeptides->{mapped_pep}<\n" if $opts->{show_regen}; #not an option
        } else { # Gerenate - as opposed to de-generate!
          $n_peps++;
          print "SIGEN: >$mapped_pep<\n" if $opts->{show_proteo}; #not an option
        }
      }
    } elsif ( $opts->{show_all_pep} ) {
      for my $mapped_pep (  keys( %{$prots{$acc}} ) ) {
        $n_peps++;
#        print "PEPTIDE: >$mapped_pep<\n";
        if ( scalar( keys( %{$allpeptides->{$mapped_pep}} ) ) > 1 ) { # Degenerate
          print "DEGEN: >$mapped_pep<\n";
          for my $k ( keys( %{$allpeptides->{$mapped_pep}} ) ) {
            print "$k\n";
          }
        } else { # Gerenate - as opposed to de-generate!
          print "PROTEO: >$mapped_pep<\n";
        }
      }
    } else {
      # Normal mode
      $n_peps = scalar( keys( %{$prots{$acc}} ) );
    }



  }
  $stats{prot_cnt_any}++ if $n_peps;
  if ( $opts->{bin_max} ) {
    $n_peps = $opts->{bin_max} if $n_peps > $opts->{bin_max};
  }
#  if ( $opts->{show_nomap} && ( !$n_peps || ($n_peps < 2 ))) {
  if ( $opts->{show_nomap} && $n_peps <= $opts->{min_nomap} ) {
    print NOMAP "$acc\n";
  }
  if ( $opts->{show_himap} && $n_peps == $opts->{show_himap} ) {
    print HIMAP "$acc\n";
  }
  my $key_num = ( $n_peps > 9 ) ? $n_peps : '0' . $n_peps;
  my $bin_key = 'prot_cnt_' . $key_num;
  $stats{$bin_key}++;
}

if ( $opts->{show_nomap} ) {
  close NOMAP;
}
if ( $opts->{show_himap} ) {
  close HIMAP;
}

if ( $opts->{key_calc} ) {
  run_key_calc();
}

my @cnt_bins;
my @cnt_vals;
for my $k ( sort( keys ( %stats ) ) ) {
  print STDERR "$k => $stats{$k}\n";
  if ( $k =~ /prot_cnt/ ) {
    push @cnt_bins, $k;
    push @cnt_vals, $stats{$k};
  }
}

print join( "\t", @cnt_bins ) . "\n";
print join( "\t", @cnt_vals ) . "\n";

my $etime = time();
my $delta = $etime - $time;
($sec,$min,$hour,$mday,$mon,$year) = localtime($time);
print STDERR "Finished run in $delta seconds: $hour:$min:$sec\n";

#  -v, --verbose        Verbose reporting
#  -h, --help           Print usage and exit
#  -f, --fasta_file     Fasta db file, required
#  -d, --duplicates     Allow sequence duplicates in fasta db
#  -t, --trim_acc       Trim fasta descriptor line to first space-delimited value
#  -p, --peptide_file   File of peptides
#  -s, --seq_idx        1-based Index of peptide sequence in file, defaults to 1
#  -n, --n_convert      Convert DxST to NxST if necessary to get matches
#  -m, --mapping_out   Print mapping results, appended to peptide line
#  -o, --output_file    File to which to print results, else STDOUT
#
#
#
#

sub run_key_calc {

  my %keys;

# Prots is ref to hash of acc => hashref of seqs. 
  for my $acc ( keys( %prots ) ) {
    my $seq_key;
    for my $seq ( sort( keys( %{$prots{$acc}} ) ) ) {
      $seq_key .= $seq;
    }
    $keys{$seq_key} ||= [];
    push @{$keys{$seq_key}}, $acc;
  }

  for my $key ( keys( %keys ) ) {

    if ( scalar( @{$keys{$key}} ) > 1 ) {
      for my $acc ( @{$keys{$key}} ) {
        print join( "\t", 'DEG', $acc, $key ) . "\n";
      }
      $stats{key_dopple}++;
      $stats{key_dopple_cnt} += scalar( @{$keys{$key}} );
    } else {
      my $acc = $keys{$key}->[0];
      print join( "\t", 'UNI', $acc, $key ) . "\n";
      $stats{key_unique}++;
    }
  }
}
sub map_peptide {

  my $pepseq = shift || die "No peptide supplied to map_peptide";
  my $skip_stats = 0;
  my $brute = shift || 0;
#  print STDERR "pepseq is $pepseq, brute is $brute\n";

  # global things...
  # Read only:
  # %allpeptides
  # %seq2acc 
  # @seq

  # Populate here:
  # %peps -  peptides keys => accession string
  # %prots - protein keys => peptide keyed hashref

  # if pep is non-tryptic or too long/short, do brute force mapping - 
  # unless we are suppressing it!
  if ( $pepseq =~ /[KR][^P]/ && !$opts->{suppress_brute} ) {
    $brute++;
    $stats{tryp_missed}++ unless $skip_stats;
  }
  if ( length( $pepseq ) < 6 ) {
    $brute++;
    $stats{short_peptide}++ unless $skip_stats;
  }
  if ( length( $pepseq ) > 300 ) {
    $brute++;
    $stats{long_peptide}++ unless $skip_stats;
  }

  my $match_str = '';
  if ( $brute ) {
    my $peplen = length( $pepseq );
    my @maps = grep(/$pepseq/, @seqs );
    if ( @maps ) {
      my $sep = '';
      for my $seq ( @maps ) {
        for my $acc ( sort( @{$seq2acc->{$seq}} ) ) {
          $prots{$acc} ||= {};
          $prots{$acc}->{$pepseq}++;

          if ( $opts->{show_all_flanking} || $opts->{c_term_cnt} ) {
            my $posn = $atlas->get_site_positions( pattern => $pepseq, 
                                                       seq => $seq );
            if ( $opts->{c_term_cnt} ) {
              my $c_term = is_c_term( seq => $seq, pep => $pepseq );
              $stats{cterm}++ if $c_term;
#              die "$pepseq is cterminal to $seq " if $c_term;
            }
            if ( $opts->{n_term_cnt} ) {
              my $n_term = is_n_term( seq => $seq, pep => $pepseq );
              if ( $n_term ) {
                if ( $n_term == 1 ) {
                  $stats{nterm}++;
                } else {
                  $stats{nterm_metcleave}++;
#                  print "metcleave is $pepseq\n";
                }
              }
            }


            my $pre = ( !$posn->[0] ) ? '-' : substr( $seq, $posn->[0] - 1, 1 );
            my $pseq = substr( $seq, $posn->[0], $peplen );
            my $fol = ( $posn->[0] + $peplen == length( $seq ) ) ? '-' : substr( $seq, $posn->[0] + $peplen, 1 );
#            print "$pepseq yeilds $pre, $pseq, $fol from $posn->[0], $posn->[1], $seq\n";
#            print join( "\t", $acc, $pre, $pseq, $fol ) . "\n";
             if ( $opts->{print_context} ) {
                next if ( $pre =~ /[KR-]/  && $pseq !~ /^P/ );
                print join( "\t", $acc, $pre, $pseq, $fol, $seq ) . "\n";
             }
          }

          # Even though this is not tryptic, cache peptide for later degeneracy test.
          $allpeptides->{$pepseq}->{$acc} ||= 1;

          $match_str .= $sep . $acc;
          $sep = ',';
        }
      }
    }
  } else {  # Try hash approach
    if ( $allpeptides->{$pepseq} ) {
      my $sep = '';
      for my $acc ( sort( keys( %{$allpeptides->{$pepseq}} ) ) ) {
        next unless $acc;
        my $seq = $acc2seq->{$acc};
        if ( $opts->{c_term_cnt}  ) {
          my $c_term = is_c_term( seq => $seq, pep => $pepseq );
          $stats{cterm}++ if $c_term;
        }
        if ( $opts->{n_term_cnt} ) {
          my $n_term = is_n_term( seq => $seq, pep => $pepseq );
          if ( $n_term ) {
            if ( $n_term == 1 ) {
              $stats{nterm}++;
            } else {
              $stats{nterm_metcleave}++;
#              print "metcleave is $pepseq\n";
            }
          }
        }
        $match_str .= $sep . $acc;
        $prots{$acc} ||= {};
        $prots{$acc}->{$pepseq}++;
        $sep = ',';
      }
    }
  } # End if brute else block
 
  if ( $match_str ) {
    $peps{$pepseq} = $match_str;
  }
  my $prot_cnt = 0;
  if ( $match_str ) {
    $prot_cnt = $match_str =~ tr/,/,/;
    $prot_cnt += 1;
  }

  if ( $prot_cnt ) {
    if ( $prot_cnt == 1 ) {
      $stats{pep_map_proteo}++;
    } else {
      $stats{pep_map_degen}++;
      print "DEGEN: $pepseq is in $match_str\n" if $opts->{show_degen};
    }
  }
  return $prot_cnt;
}

  

      # Already mapped?
#      if ( $peps{$pepseq} ) {
#        # Get strs for printout, prot values have already been stored.
#        $match_str = $peps{$pepseq}->{str};
#        $prot_cnt = $peps{$pepseq}->{cnt};
#      } else {
#      if ( scalar( @maps ) == 1 ) {
#        $stats{pep_map_proteo}++;
#      } else {
#        $stats{pep_map_degen}++;
#      }
#      my @keys = keys( %{$tryptic} );
#      if ( scalar( @keys ) == 1 ) {
#        $stats{pep_map_proteo}++;
#      } else {
#        $stats{pep_map_degen}++;
#      }



sub is_n_term {
  my %args = @_;

  my $peplen = length($args{pep});
  my $nterm = substr( $args{seq}, 0, $peplen);
  if ( $nterm eq $args{pep} ) {
    return 1;
  } else {
    $nterm = substr( $args{seq}, 1, $peplen);
  }
  return ( $nterm eq $args{pep} ) ? 2 : 0;
  
}


sub is_c_term {
  my %args = @_;
  my $peplen = length($args{pep});
  my $cterm = substr( $args{seq}, -1 * $peplen, $peplen);
  return ( $cterm eq $args{pep} ) ? 1 : 0;
}

sub read_fasta {
	
  my $fasta_file = $opts->{fasta_file} || die "Must supply fasta file";
  
  open(FASTA, "$fasta_file") || die "Couldn't open $fasta_file: $!\n";
  
  my $fasta = new FAlite(\*FASTA);
  my %seq2acc;
  my %acc2seq;
  my %tryptic;

  print STDERR "Interpreting peptides in N/D neutral manner...\n" if $opts->{d2n_force};
#  if ( $opts->{grep_only} ) {
#    return ( \%seq2acc, \%acc2seq, \%tryptic );
#  }

  while( my $entry = $fasta->nextEntry() ) {
    my $def = $entry->def();
    chomp $def;
    $def =~ s/^>//g;

    if ( $opts->{trim_acc} ) {
      $def =~ /^(\S+)\s.*$/;
      if ( $1 ) {
        $def = $1;
        $stats{trim_ok}++;
      } else {
        $stats{trim_no}++;
      }
    } elsif ( $opts->{acc_swiss} ) {
      # Look past first item for first SP id
      $def =~ /^\S+\s+([A-Za-z0-9]+).*$/;
      if ( $1 ) {
        $def = $1;
        $stats{swiss_acc_ok}++;
      } else {
        $stats{swiss_acc_no}++;
      }

    } elsif ( $opts->{pipe_acc} ) {
      $def =~ /^\w+\|(\w+)\|/;
      $def = $1 if $1;
    }

    if ( $def =~ /,/ ) {
      die "Comma in def will break counting, use trim option: $def";
    }

    my $seq = uc( $entry->seq() );
    chomp $seq;
    $seq =~ s/\s//gm;
    if ( $opts->{d2n_force} ) {
      $seq =~ s/D/N/g; 
    }
    if ( $opts->{i_to_l_convert} ) {
      $seq =~ s/I/L/gm;
    }

    if ( defined $seq2acc{$seq} ) {
      die "Duplicate sequences" unless $opts->{duplicates};
      $stats{acc_dup}++;
    } else {
      $stats{acc_ok}++;
    }
    $seq2acc{$seq} ||= [];
    push @{$seq2acc{$seq}}, $def;

    if ( defined $acc2seq{$def} ) {

#      die "Duplicate accessions: $def";
    } 
#    print "$def\n";
    $acc2seq{$def} = $seq;

    unless( $opts->{grep_only} ) {

      my $min_len = $opts->{length_min} || 6;
      my $max_len = $opts->{length_max} || 300;

      my $tryptic = $atlas->do_tryptic_digestion( aa_seq => $seq,
                                                 min_len => $min_len,
                                                 max_len => $max_len );

      my $tp_cnt = 0;
      for my $tp ( @{$tryptic} ) {
        if ( $opts->{met_trim} && !$tp_cnt ) {
          $tp_cnt++;
          $seq =~ m/$tp/g;
          my $pos = length( $` );
          if ( !$pos ) {
            my $mt = $tp;
            $mt =~ s/^M//;
            $tryptic{$mt} ||= {};
            $tryptic{$mt}->{$def}++;
          }
        }
#        print STDERR "Adding $tp\n";
        $tryptic{$tp} ||= {};
        $tryptic{$tp}->{$def}++;
      }
    }
  }
  return ( \%seq2acc, \%acc2seq, \%tryptic );

}

sub read_manual {
  
  return undef;
  
  while( my $line = <BPEPS> ) {
    chomp $line;
    my ( $pep, $build ) = split( "\t", $line );
    $pep = uc( $pep );
  }
}


sub read_peptides {
  my $peptide_file = shift();
  
  open( PEPS, "$peptide_file") || die "Couldn't open $peptide_file: $!\n";
  
  my @peptides;
  while( my $line = <PEPS> ) {
    next if $line =~ /^\s*$/;
    chomp $line;
#    my @peps = split( "\t", $line, -1 );
#    $peps[0] = uc( $peps[0] );
    push @peptides, $line;
  }
  return \@peptides;
}


sub get_options {
  my %opts;
  GetOptions(\%opts, "verbose", "fasta_file=s", 'help', 'seq_idx=i',
             'peptide_file=s', 'n_convert', 'duplicates', 'pipe_acc',
             'mapping_out', 'trim_acc', 'output_file=s', 'column_labels:i',
             'acc_swiss', 'ZtoC', 'bin_max=i', 'grep_only', 'init_mapping=i',
             'show_degen', 'show_mia', 'nocount_degen', 'show_nomap', 'show_himap=i',
             'show_proteo', 'show_all_pep', 'omit_match_seq', 'suppress_brute',
             'key_calc', 'show_all_flanking', "min_nomap=i", 'c_term_cnt', 'n_term_cnt',
             'print_context', 'i_to_l_convert', 'acc_sep_char=s', 'd2n_force', 'met_trim',
             'length_min:i', 'length_max:i', 'strip_mods', 'blank_skip' );

  print_usage() if $opts{help};

  my $missing;
  for my $arg ( qw( fasta_file peptide_file ) ) {
    unless ( defined $opts{$arg} ) {
      $missing = ( $missing ) ? "$missing, $arg" : "missing required option(s): $arg"
    }
  }

  $opts{acc_sep_char} ||= ',';

  if ( defined $opts{column_labels} ) {
    $opts{column_labels} ||= 1;
  }

  # This is the minium number of peptides to print out with show_nomap
	$opts{min_nomap} ||= 0;

  # adjust seq idx to 0-based, or set to default.
  if ( $opts{seq_idx} ) {
    $opts{seq_idx} -= 1;
  } else {
    $opts{seq_idx} = 0;
  }

  print_usage( $missing ) if $missing;
  print_usage() if $opts{help};
  return \%opts;
}

sub print_usage {

  my $msg = shift || '';
  my $exe = $FindBin::Script;



  print qq~
  $msg

#  GetOptions(\%opts, "verbose", "fasta_file=s", 'help', 'seq_idx=i',
#             'peptide_file=s', 'n_convert', 'duplicates', 'pipe_acc',
#             'mapping_out', 'trim_acc', 'output_file=s', 'column_labels:i',
#             'acc_swiss', 'ZtoC', 'bin_max=i', 'grep_only', 'init_mapping=i',
#             'show_degen', 'show_mia', 'nocount_degen' );

  Usage: $exe -f fasta_file -p peptide_file

  -v, --verbose        Verbose reporting
  -h, --help           Print usage and exit
  -f, --fasta_file     Fasta db file, required
      --duplicates     Allow sequence duplicates in fasta db
  -t, --trim_acc       Trim fasta descriptor line to first space-delimited value
  -p, --peptide_file   File of peptides
      --seq_idx        1-based Index of peptide sequence in file, defaults to 1
      --suppress_brute  Do not use brute-force mapping (IDs non-tryptic)
  -n, --n_convert      Convert DxST to NxST if necessary to get matches
      --mapping_out    Print mapping results, appended to peptide line
      --min_nomap      Minimum number of mapping peptides for nomap
      --output_file    File to which to print results, else STDOUT
  -c, --column_labels  Peptide file has column labels (headings) to skip.
  -a, --acc_swiss      Pull swiss prot acc from Uniprot fasta heading.
  -b, --bin_max        Max size of reported prot_count.
  -g, --grep_only      For small peptide lists, forgo the fasta digestion
      --i_to_l_convert For cached peptide mapping, convert Ile -> Leu (isobaric).
  -k, --key_calc       Run code to determine which prot seqs are unambiguously
                       defined by peptide set.
  -Z, --ZtoC           Convert Z to C in peptide sequences
      --show_degen     List degenerate peptides
      --show_proteo    List proteotypic peptides
      --show_all_pep   List all peptides
      --omit_match_seq List all peptides
      --show_mia       List missing peptides
      --show_nomap     List proteins for which there are less than min_nomap for (default 0)
      --min_nomap     List proteins for which there are no peptides
      --show_himap     List proteins for which there are more than show_himap peptides for 
      --nocount_degen  Omit degenerate peptides in counting protein bins
  ~;
  print "\n";
  exit;

}


__DATA__
  GetOptions(\%opts, "verbose", "fasta_file=s", 'help', 'seq_idx=i',
             'peptide_file=s', 'n_convert', 'duplicates', 'pipe_acc',
             'mapping_out', 'trim_acc', 'output_file=s', 'column_labels:i',
             'acc_swiss', 'ZtoC', 'bin_max=i', 'grep_only', 'init_mapping=i',
             'show_degen', 'show_mia', 'nocount_degen', 'show_nomap', 'show_himap=i',
             'show_proteo', 'show_all_pep', 'omit_match_seq', 'suppress_brute',
             'key_calc', 'show_all_flanking', "min_nomap=i", 'c_term_cnt', 'n_term_cnt',
             'print_context', 'i_to_l_convert' );

==> virus_peptides <==
WTTNTETGAPQLNPIDGPLPEDNEPSGYAQTDCVLEAMAFLEESHPGIFENSCIETMEVVQQTR
DNWHGSNRPWVSFDQNLDYQIGYICSGVFGDNPRPEDGTGSCGPVYVDGANGVK
DNWHGSNRPWVSFNQNLEYQIGYICSGVFGDNPRPNDGTGSCGPVSSNGAYGVK

==> pep_builds.tsv <==
peptide_sequence	atlas_build_id
AAAAAA	117
AAAAAAAAAASGAAIPPLIPPR	153
#!/usr/local/bin/perl 
