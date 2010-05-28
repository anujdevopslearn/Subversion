#!/usr/local/bin/perl

use strict;
use Getopt::Long;
use File::Basename;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::BestPeptideSelector;
use SBEAMS::PeptideAtlas::Tables;

$|++; # don't buffer output

my $sbeams = SBEAMS::Connection->new();
$sbeams->Authenticate();
my $atlas = SBEAMS::PeptideAtlas->new();
$atlas->setSBEAMS( $sbeams );
my $pep_sel = SBEAMS::PeptideAtlas::BestPeptideSelector->new();
$pep_sel->setSBEAMS( $sbeams );

my $opts = process_opts();


#IPI:IPI00000001.2
{ # Main
  print "fasta file is $opts->{fasta_file}\n" if $opts->{verbose};
  my $fsa = $sbeams->read_fasta_file( filename => $opts->{fasta_file},
                                     acc_regex => [ '>(\S+).*?(isoform\s\d+)', '^>IPI:(IPI\d+)\.*', '>(\S+)' ],
                                       verbose => $opts->{verbose} ); 

  my $seq2acc = invert_fasta( $fsa );

  my $peptides = read_pepfile();
  
  if ( $opts->{remap_proteins} ) {
    map_peptides( sequences => $seq2acc, peptides => $peptides );
  }

  if ( $opts->{evaluted_file} ) {

  }

  my @opts = ( 'peptides', $peptides, 'force_mc', 1, 'seq_idx', $opts->{idx_peptide} - 1 );

  push @opts, ( 'hydrophob_idx', $opts->{'_num_tabs'} - 1 ) if $opts->{calc_ssr};

  push @opts, ( 'score_idx', $opts->{'score_idx'} - 1 ) if ( $opts->{score_idx} );

#    $pep_sel->pabst_evaluate_peptides( peptides => $peptides,
#                                       force_mc => 1,
#                                  hydrophob_idx => $opts->{'_num_tabs'}- 1,
#                                        seq_idx => $opts->{idx_peptide} - 1 
#                                       );

  # check file (list of prots to penalize/reward.
  my %chk_args;
  if ( $opts->{chk_file} && defined $opts->{chk_scr} ) {
    $chk_args{chk_peptide_hash} = get_chk_hash();
    $chk_args{peptide_hash_scr} = $opts->{chk_scr};
  }


  $pep_sel->pabst_evaluate_peptides( @opts, %chk_args );

  open ( OUT, ">$opts->{output_file}" ) || die "Unable to open $opts->{output_file}";

  if ( $opts->{sort_within_prots} ) {
    my $n_peptides = $opts->{n_peptides} || 10000;
    my $sort_idx = 0;
    my %prots;
    for my $p ( @$peptides ) {
      if ( !$sort_idx ) {
        $sort_idx = scalar( @{$p} ) - 1;
      }
      my $prot = $p->[$opts->{sort_within_prots}-1] || die "missing required prot!";
      $prots{$prot} ||= [];
      push @{$prots{$prot}}, $p;
    }

    for my $prot ( sort( keys( %prots ) ) ) {
      my @peps = @{$prots{$prot}};
      @peps = sort { $b->[$sort_idx] <=> $a->[$sort_idx] } ( @peps );
      my $cnt = 0;
      for my $pep ( @peps ) {
        print OUT join( "\t",  @$pep ) . "\n";
        last if ++$cnt >= $n_peptides;
      }
    }
  } else {

    my $cnt = 0;
    $opts->{_num_tabs} ||= 0;
    for my $p ( @$peptides ) {
      while ( $opts->{skipped_lines}->{$cnt} ) {
        print OUT "\t" x $opts->{_num_tabs} . "\n";
        $cnt++;
      } 
      print OUT join( "\t",  @$p ) . "\n";
      $cnt++;
    }
  }


}

sub invert_fasta {
  my $fsa = shift || return {};
  my %seq2acc;
  for my $acc ( keys( %$fsa ) ) {
    my $seq = $fsa->{$acc};
    $seq2acc{$seq} ||= [];
    push @{$seq2acc{$seq}}, $acc;
  }
  return \%seq2acc;
}

sub map_peptides {
  my %args = @_;
  for my $arg ( qw( sequences peptides ) ) {
    print_usage( "no $arg file passed to map_peptides" ) unless $args{$arg};
  }

  my @bioseqs = keys( %{$args{sequences}} );
  my $perl_idx = $opts->{idx_peptide} - 1;
  for my $pep_row ( @{$args{peptides}} ) {
    my $pepseq = $pep_row->[$perl_idx];
    my $n_matches;
    my %acc;
    my @matches = grep( /$pepseq/, @bioseqs);
    for my $seq (@matches) {
      $n_matches++;
      foreach my $match (@matches) {
        # Count each sequence-unique entry as a protein mapping.
        my $accessions_list = $args{sequences}->{$match};
        for my $acc ( @$accessions_list ) {
          $acc{$acc}++;
        }
      }
    }
    # Done, sort out what we have and update row
    my $all_acc = join( ',', sort( keys( %acc ) ) );
    push ( @{$pep_row}, $n_matches, $all_acc );
  }
}

sub read_pepfile {
  open ( PEP, $opts->{peptide_file} || print_usage( "Unable to open pepfile $opts->{peptide_file}" ) );
  my @peptides;
  my $cnt++;
  my %ssr;
  if ( $opts->{calc_ssr} ) {
    $atlas->{_ssrCalc} = $atlas->getSSRCalculator();
  }

  while ( my $line = <PEP> ) {
    chomp $line;
    my @line = split( "\t", $line, -1 );
    my $seq = $line[$opts->{idx_peptide} - 1];
    if ( $opts->{wspace_skip_idx} ) {
      if ( $line[$opts->{wspace_skip_idx} - 1] eq '' ) {
        $opts->{skipped_lines}->{$cnt}++;
        $cnt++;
        print "$line\n";
        next;
      }
    } else {
      if ( !$seq ) {
        print STDERR "Peptide field is blank - index is 1-based - skipping\n";
        next;
      }
    }
    $opts->{_num_tabs} ||= scalar( @line );
    if ( $opts->{calc_ssr} ) {
      if ( ! defined $ssr{$seq} ) {
        $ssr{$seq} = $atlas->calc_SSR( seq => $seq );
      }
      push @line, $ssr{$seq};
    }

    push @peptides, \@line;
    $cnt++;
  }
  $opts->{_num_tabs}++ if $opts->{calc_ssr};
  print "Read " . scalar( @peptides ) . " peptides from $opts->{peptide_file}\n" if $opts->{verbose};
  return \@peptides;

}


sub process_opts {
  my %opts;
  GetOptions( \%opts, 'atlas_build=i', 'config=s', 'help', 'tsv_file=s', 
              'peptide_file=s', 'idx_peptide=i',  'fasta_file=s', 'remap_proteins',  
              'verbose', 'wspace_skip_idx=i', 'show_prot_names', 'output_file:s',
              'evaluated_file=s', 'broad_predictor=s', 'calc_ssr', 'score_idx:i',
              'sort_within_prots=i', 'n_peptides=i', 'chk_file=s', 'chk_scr=f'
             ) || print_usage();

# Add 9, 13, 14, 17

# 1 biosequence_name
# 2 preceding_residue
# 3 peptide_sequence
# 4 following_residue
# 5 empirical_proteotypic_score
# 6 suitability_score
# 7 predicted_suitability_scoremerged_score
# 8 molecular_weight
# 9 SSRCalc_relative_hydrophobicity
# 10 n_protein_mappings
# 11 n_genome_locations
# 12 best_probability
# 13 n_observations
# 14 annotations
# 15 atlas_build
# 16 synthesis_score
# 17 syntheis_adjusted_score

  my $err = '';
  for my $req_arg ( qw ( fasta_file idx_peptide peptide_file output_file ) ) {
    $err = ( $err ) ? "$err, $req_arg" : "Missing required argument(s) $req_arg" if !defined $opts{$req_arg};
  }
  print_usage( $err ) if $err;
  $opts{skipped_lines} = {};

  print_usag
   e() if $opts{help};
  if ( $opts{config} ) {
    open CFG, $opts{config} || print_usage( "Unable to open config file $opts{config}");
    my %config_vals;
    while( my $line = <CFG> ) {
      chomp $line;
      $line =~ s/\#.*$//;
      $line =~ /^(\S+)\s+(\S+)/;
      if ( $1 && $2 ) {
        $config_vals{$1} = $2;
      }
    }
    print "setting value!\n";
    $pep_sel->set_pabst_penalty_values( %config_vals );
  }
  return \%opts;
}

sub print_usage {
  my $msg = shift || '';
  my $sub = basename( $0 );
  print <<"  END";
      $msg

usage: $sub -a build_id [ -t outfile -n obs_cutoff -p proteins_file -v -b .3 ]

   -a, --atlas_build      Numeric atlas build ID to query 
   --config           Config file defining penalites for various sequence  
   -f, --fasta_file       reference fasta file of proteins, supercedes atlas_build
                          specified biosequence_set
   -p, --peptide_file     file of peptides, may have other info
   -o, --output_file      file to print annotated peptides to.
   -i, --idx_peptide      1-based index of peptide info in peptide_file
   -r, --remap_proteins   remap peptides to target db
   --show_prot_names  print column with proteins that mapped to peptide X.
                          Requires --remap_proteins.
   --score_idx            Index of column to be used as score base.
   --sort_within_prots    Sort within proteins, arg value is index of prot col
   -t, --tsv_file         print output to specified file rather than stdout
   -h, --help             Print usage
   -v, --verbose          Verbose output, prints progress 
   --calc_ssr             Calculate ssr, append as new column 
   --chk_file             File of peptide accessions for which to modify score.  
                          Primary purpose is to boost proteins on a particular 
                          list, e.g.
   --chk_scr              Score to apply for items in chk_file above.
   -w, --wspace_skip_idx  Skip rows where column x, 1-based idx, is blank
  END
# End of the line
  exit;
}


sub get_chk_hash {
  # opts is global : (
  return {} unless ( $opts->{chk_file} && defined $opts->{chk_scr} );

  my %chk_hash;
  open CHK, $opts->{chk_file} || die "Unable to open chk_file $opts->{chk_file}";

  while ( my $chk_line = <CHK> ) {
    chomp $chk_line;
    $chk_hash{$chk_line}++;
  }
  close CHK;
  return \%chk_hash;
}


__DATA__
