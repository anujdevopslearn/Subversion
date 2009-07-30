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


{ # Main
  print "fasta file is $opts->{fasta_file}\n" if $opts->{verbose};
  my $fsa = $sbeams->read_fasta_file( filename => $opts->{fasta_file},
                                     acc_regex => [ '>(\S+).*?(isoform\s\d+)', '>(\S+)' ],
                                       verbose => $opts->{verbose} ); 

  my $seq2acc = invert_fasta( $fsa );

  my $peptides = read_pepfile();
  
  if ( $opts->{remap_proteins} ) {
    map_peptides( sequences => $seq2acc, peptides => $peptides );
  }

  $pep_sel->pabst_evaluate_peptides( peptides => $peptides,
                                     force_mc => 1,
                                      seq_idx => $opts->{idx_peptide} - 1 
                                     );

  open ( OUT, ">$opts->{output_file}" ) || die "Unable to open $opts->{output_file}";
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
  while ( my $line = <PEP> ) {
    chomp $line;
    my @line = split( "\t", $line, -1 );
    if ( $opts->{wspace_skip_idx} ) {
      if ( $line[$opts->{wspace_skip_idx} - 1] eq '' ) {
        $opts->{skipped_lines}->{$cnt}++;
        $cnt++;
        next;
      }
    } else {
      if ( !$line[$opts->{idx_peptide} - 1] ) {
        print STDERR "Peptide field is blank - index is 1-based - skipping\n";
        next;
      }
    }
    $opts->{_num_tabs} ||= scalar( @line );
    push @peptides, \@line;
    $cnt++;
  }
  print "Read " . scalar( @peptides ) . " peptides from $opts->{peptide_file}\n" if $opts->{verbose};
  return \@peptides;

}


sub process_opts {
  my %opts;
  GetOptions( \%opts, 'atlas_build=i', 'config=s', 'help', 'tsv_file=s', 
              'peptide_file=s', 'idx_peptide=i',  'fasta_file=s', 'remap_proteins',  
              'verbose', 'wspace_skip_idx=i', 'show_prot_names', 'output_file:s' ) || print_usage();

  my $err = '';
  for my $req_arg ( qw ( fasta_file idx_peptide peptide_file output_file ) ) {
    $err = ( $err ) ? "$err, $req_arg" : "Missing required argument(s) $req_arg" if !defined $opts{$req_arg};
  }
  print_usage( $err ) if $err;
  $opts{skipped_lines} = {};

  print_usage() if $opts{help};
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
   -c, --config           Config file defining penalites for various sequence  
   -f, --fasta_file       reference fasta file of proteins, supercedes atlas_build
                          specified biosequence_set
   -p, --peptide_file     file of peptides, may have other info
   -o, --output_file      file to print annotated peptides to.
   -i, --idx_peptide      1-based index of peptide info in peptide_file
   -r, --remap_proteins   remap peptides to target db
   -s, --show_prot_names  print column with proteins that mapped to peptide X.
                          Requires --remap_proteins.
   -t, --tsv_file         print output to specified file rather than stdout
   -h, --help             Print usage
   -v, --verbose          Verbose output, prints progress 
   -w, --wspace_skip_idx  Skip rows where column x, 1-based idx, is blank
  END
# End of the line
  exit;
}


__DATA__

  print_default_config() if $args{default_config};

  if ( $args{show_builds} ) {
    $args{show_builds} = 'def' unless $args{show_builds} eq 'all';  
  } else {
    my $err;
    for my $k ( qw( atlas_build ) ) {
      $err .= ( $err ) ? ", $err" : "Missing required parameter(s) $k" if !defined $args{$k};
    }
    print_usage( $err ) if $err;
  }
  for my $opt ( qw( n_peptides obs_min atlas_build ) ) {
    if ( $args{$opt}  && $args{$opt} !~ /^\d+$/ ) {
      print_usage( "$opt must be an integer" );
    }
  }
  if ( $args{config} ) {
    open CFG, $args{config} || print_usage( "Unable to open config file $args{config}");
    my %config_vals;
    while( my $line = <CFG> ) {
      chomp $line;
      $line =~ s/\#.*$//;
      $line =~ /^(\S+)\s+(\S+)/;
      if ( $1 && $2 ) {
        $config_vals{$1} = $2;
      }
    }
    $pep_sel->set_pabst_penalty_values( %config_vals );
  }


  return \%args;
}



__DATA__


my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;




{ # Main 
  if ( $args->{show_builds} ) {
    show_builds();
  } else {
    print STDERR "Starting: " . time() . "\n" if $args->{verbose};
    print STDERR "Fetching observed peptides\n" if $args->{verbose};

    my $observed = get_observed_peptides();
    print STDERR "Fetching theoretical peptides\n" if $args->{verbose};
    my $theoretical = get_theoretical_peptides();
    print STDERR "Merging peptides ($args->{n_peptides})\n" if $args->{verbose};
    my $merged = $pep_sel->merge_pabst_peptides(  obs => $observed, 
                                                 theo => $theoretical,
                                           n_peptides => $args->{n_peptides},
                                              verbose => $args->{verbose}
                                               );

    print STDERR "Freeing memory\n" if $args->{verbose};
    # Free up some memory!!!
    undef $observed;
    undef $theoretical;

    print STDERR "Printing peptides\n" if $args->{verbose};

    my $headings = get_headings();
    if ( $args->{tsv_file} ) {
      open( TSV, ">$args->{tsv_file}" ) || print_usage( "Unable to open file $args->{tsv_file}" );
      print TSV join( "\t", @$headings ) . "\n";
    } else {
      print join( "\t", @$headings ) . "\n";
    }

    for my $peptide ( @{$merged} ) {
      $peptide->[4] = sprintf( "%0.2f", $peptide->[4] ) if $peptide->[4] !~ /na/;
      $peptide->[5] = sprintf( "%0.2f", $peptide->[5] ) if $peptide->[5] !~ /na/;
      $peptide->[6] = sprintf( "%0.2f", $peptide->[6] ) if $peptide->[6] !~ /na/;
      $peptide->[7] = sprintf( "%0.2f", $peptide->[7] ) if $peptide->[7] !~ /na/;
      $peptide->[15] = sprintf( "%0.2f", $peptide->[15] ) if $peptide->[15];
      $peptide->[16] = sprintf( "%0.3f", $peptide->[16] );
      if ( $args->{tsv_file} ) {
        print TSV join( "\t", @{$peptide} ) . "\n";
      } else {
        print join( "\t", @{$peptide} ) . "\n";
      }
    }
    close TSV if $args->{tsv_file};

    print STDERR "Finishing: " . time() . "\n" if $args->{verbose};
  }
} # End main

sub show_builds {
  my $sql = qq~
         SELECT AB.atlas_build_id, atlas_build_name, organism_name, BS.biosequence_set_id, set_name
         FROM $TBAT_ATLAS_BUILD AB
         JOIN $TBAT_BIOSEQUENCE_SET BS ON BS.biosequence_set_id = AB.biosequence_set_id
         JOIN $TB_ORGANISM O ON BS.organism_id = O.organism_id
         ORDER BY AB.atlas_build_id
  ~;

  my @results = $sbeams->selectSeveralColumns($sql);
  if ( $args->{tsv_file} ) {
    open( TSV, ">$args->{tsv_file}" ) || print_usage( "Unable to open file $args->{tsv_file}" );
    print TSV "Build ID\tBuild name\torganism\tRef DB ID\tRef DB Name\n";
    for my $row ( @results ) {
      print TSV join( "\t", @{$row} ) . "\n";
    }
    close TSV
  } else {
    print "Build ID\tBuild name\torganism\tRef DB ID\tRef DB Name\n";
    for my $row ( @results ) {
      print join( "\t", @{$row} ) . "\n";
    }
  }
}

sub process_args {
  my %args;

  GetOptions( \%args, 'atlas_build=i', 'show_builds', 'help', 'tsv_file=s', 
              'protein_file=s', 'n_peptides=i', 'config=s', 'default_config', 
              'bonus_obs=f', 'obs_min=i', 'verbose', 'name_prefix=s'
             ) || print_usage();

  print_usage() if $args{help};
  print_default_config() if $args{default_config};

  if ( $args{show_builds} ) {
    $args{show_builds} = 'def' unless $args{show_builds} eq 'all';  
  } else {
    my $err;
    for my $k ( qw( atlas_build ) ) {
      $err .= ( $err ) ? ", $err" : "Missing required parameter(s) $k" if !defined $args{$k};
    }
    print_usage( $err ) if $err;
  }
  for my $opt ( qw( n_peptides obs_min atlas_build ) ) {
    if ( $args{$opt}  && $args{$opt} !~ /^\d+$/ ) {
      print_usage( "$opt must be an integer" );
    }
  }
  if ( $args{config} ) {
    open CFG, $args{config} || print_usage( "Unable to open config file $args{config}");
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


  return \%args;
}

sub print_default_config {
  my $config = $pep_sel->get_default_pabst_scoring( show_defs => 1 );
  if ( !-e "best_peptide.conf" ) {
    open( CONF, ">best_peptide.conf" ) || die "Unable to open config file, printing to STDERR\n$config\n";
    print CONF $config;
  } else {
    print STDERR "Config file exists, printing to STDERR\n$config\n";
  }
  exit;
}


sub get_observed_peptides {
  
  my $build_where = "WHERE PI.atlas_build_id = $args->{atlas_build}";
  my $name_in = ( $args->{protein_file} ) ? get_protein_in_clause() : '';
  my $nobs_and = ( $args->{obs_min} ) ? "AND n_observations > $args->{obs_min}" : ''; 
  my $name_like = ( $args->{name_prefix} ) ? "AND biosequence_name like '$args->{name_prefix}%'" : ''; 

  # Short circuit with BestPeptideSelector object method!
  return $pep_sel->get_pabst_observed_peptides(       atlas_build => $args->{atlas_build},
                                                protein_in_clause => $name_in, 
                                                  min_nobs_clause => $nobs_and, 
                                                        name_like => $name_like, 
                                                        bonus_obs => $args->{bonus_obs},
                                                          verbose => $args->{verbose}
                                              );
}

sub get_headings {

  return $pep_sel->get_pabst_headings();

  my @headings = qw( biosequence_name preceding_residue peptide_sequence following_residue 
                     empirical_proteotypic_score suitability_score molecular_weight 
                     SSRCalc_relative_hydrophobicity n_protein_mappings n_genome_locations
                     best_probability n_observations synthesis_score synthesis_warnings
                     syntheis_adjusted_score );
  return \@headings;
}

sub get_protein_in_clause {
  # protein list in a file
  open PROT, $args->{protein_file} || 
             print_usage( "Unable to open protein file $args->{protein_file}" );
  my $in_clause = 'AND biosequence_name IN (';
  my $sep = '';
  while ( my $prot = <PROT> ) {
    chomp $prot;
    $in_clause .= $sep . "'" . $prot . "'";
    $sep = ',';
  }
  return '' unless $sep;
  $in_clause .= ')';
  return $in_clause;
}

sub get_theoretical_peptides {
  
  my $build_where = "WHERE AB.atlas_build_id = $args->{atlas_build}";
  my $name_in = ( $args->{protein_file} ) ? get_protein_in_clause() : '';

  # Short circuit with BestPeptideSelector object method!
  return $pep_sel->get_pabst_theoretical_peptides( 
                                            atlas_build => $args->{atlas_build},
                                      protein_in_clause => $name_in, 
                                                verbose => $args->{verbose}
                                                 );
}

__DATA__
sub merge_peptides {
  my $obs = shift;
  my $theo = shift;
  my @final_protein_list;

  # loop over keys of theoretical list - all proteins are represented
  for my $prot ( sort( keys( %$theo ) ) ) {

    # List of peptides for this protein
    my @peptides; 

    # consider each theoretical peptide...
    for my $pep( sort( keys( %{$theo->{$prot}} ) ) ) {
      # Set to theo value by default
      my $peptide = $theo->{$prot}->{$pep};

      # If this pep is also observed, use the one with the higher score
      if ( $obs->{$prot} && $obs->{$prot}->{$pep} ) { 
        if( $obs->{$prot}->{$pep}->[13] >  $theo->{$prot}->{$pep}->[13] ) {
          $peptide = $obs->{$prot}->{$pep}
        }
      }

      push @peptides, $peptide;
    }

    # If this protein is also observed, check for non-tryptic keys
    if ( $obs->{$prot} ) {

      # consider each peptide...
      for my $pep ( sort( keys(  %{$obs->{$prot}}  ) ) ) {

        # skip it if we've already seen it 
        next if $theo->{$prot}->{$pep};

        # Hopefully its non-tryptic nature will beat it down!  
        push @peptides, $obs->{$prot}->{$pep}
      }
    }

    # OK, we have a merged array of peptides with scores.  Sort and return
    @peptides = sort { $b->[13] <=> $a->[13] } @peptides;

    # FIXME - apply peptide number or score threshold here?
    push @final_protein_list, @peptides;

  }
  return \@final_protein_list;
}



sub get_theoretical_peptides {
  
  my $build_where = "WHERE AB.atlas_build_id = $args->{atlas_build}";
  my $name_in = ( $args->{protein_file} ) ? get_protein_in_clause() : '';

  # Short circuit with BestPeptideSelector object method!
  return $pep_sel->get_pabst_theoretical_peptides( atlas_build => $args->{atlas_build},
                                                   protein_in_clause => $name_in );


  my $pepsql =<<"  END"; 
  SELECT DISTINCT biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  CASE WHEN  peptidesieve_ESI > peptidesieve_ICAT THEN  (peptidesieve_ESI +  detectabilitypredictor_score )/2  
                       ELSE  (peptidesieve_ICAT +  detectabilitypredictor_score )/2  
                  END AS suitability_score,
                  STR(molecular_weight, 7, 4) Molecular_weight,
                  STR(SSRCalc_relative_hydrophobicity,7,2) AS "SSRCalc_relative_hydrophobicity",
                  n_protein_mappings AS "n_protein_mappings",
                  n_genome_locations AS "n_genome_locations",
                  'n/a',
                  'n/a'
  FROM $TBAT_PROTEOTYPIC_PEPTIDE PP
  JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PM ON ( PP.proteotypic_peptide_id = PM.proteotypic_peptide_id )
  JOIN $TBAT_BIOSEQUENCE BS ON ( PM.source_biosequence_id = BS.biosequence_id )
  JOIN $TBAT_ATLAS_BUILD AB ON ( AB.biosequence_set_id = BS.biosequence_set_id ) 
  $build_where
  $name_in
  ORDER BY biosequence_name, suitability_score DESC
  END

#  print STDERR $pepsql; exit;


  my $sth = $sbeams->get_statement_handle( $pepsql );
  # Big hash of proteins
  my $pep_cnt;
  my %proteins;
  while( my @row = $sth->fetchrow_array() ) {

    # Adjust the score with a PBR!
    my $row = $pep_sel->pabst_evaluate_peptides( peptides => [\@row], seq_idx => 2, follow_idx => 3, score_idx => 4, ssr_idx => 8 );
    @row = @{$row->[0]};

    # Each protein is a hashref
    $proteins{$row[0]} ||= {};
    m # That hashref points to the row
    $proteins{$row[0]}->{$row[1].$row[2].$row[3]} = \@row;
    $pep_cnt++;
  }
  print STDERR "Saw " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n";
#  my $cnt = 0; for my $k ( keys ( %proteins ) ) { print "$k\n"; last if $cnt++ >= 10; }
  return \%proteins;
}

sub get_observed_peptides {
  
  my $build_where = "WHERE PI.atlas_build_id = $args->{atlas_build}";
  my $name_in = ( $args->{protein_file} ) ? get_protein_in_clause() : '';
  my $nobs_and = ( $args->{obs_min} ) ? "AND n_observations > $args->{obs_min}" : ''; 

  # Short circuit with BestPeptideSelector object method!
  return $pep_sel->get_pabst_observed_peptides(       atlas_build => $args->{atlas_build},
                                                protein_in_clause => $name_in, 
                                                  min_nobs_clause => $nobs_and, 
                                                        bonus_obs => $args->{bonus_obs}  
                                              );
  my $obs_adjustment = 1;


  my $pepsql =<<"  END"; 
  SELECT DISTINCT 
                  biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  CASE WHEN empirical_proteotypic_score IS NULL THEN .5 + $obs_adjustment 
                       ELSE  empirical_proteotypic_score + $obs_adjustment
                  END AS suitability_score,
                  STR(molecular_weight, 7, 4) Molecular_weight,
                  STR(P.SSRCalc_relative_hydrophobicity,7,2) AS "SSRCalc_relative_hydrophobicity",
                  PI.n_protein_mappings AS "n_protein_mappings",
                  PI.n_genome_locations AS "n_genome_locations",
                  STR(PI.best_probability,7,3) AS "best_probability",
                  PI.n_observations AS "n_observations"
  FROM $TBAT_PEPTIDE_INSTANCE PI
  JOIN $TBAT_PEPTIDE P ON ( PI.peptide_id = P.peptide_id )
  JOIN $TBAT_PEPTIDE_MAPPING PM ON ( PI.peptide_instance_id = PM.peptide_instance_id )
  JOIN $TBAT_BIOSEQUENCE BS ON ( PM.matched_biosequence_id = BS.biosequence_id )
  $build_where
  $nobs_and
  $name_in
  ORDER BY biosequence_name, suitability_score DESC
  END

#  print STDERR $pepsql; exit;


  my $sth = $sbeams->get_statement_handle( $pepsql );
  # Big hash of proteins
  my $pep_cnt;
  my %proteins;
  while( my @row = $sth->fetchrow_array() ) {

     # Adjust the score with a PBR!
     my $row = $pep_sel->pabst_evaluate_peptides( peptides => [\@row], seq_idx => 2, follow_idx => 3, score_idx => 4 );
     @row = @{$row->[0]};

    # Each protein is a hashref
    $proteins{$row[0]} ||= {};
    # That hashref points to the row, keyed by sequence w/ flanking AA
    $proteins{$row[0]}->{$row[1].$row[2].$row[3]} = \@row;
    $pep_cnt++;
  }
  print STDERR "Saw " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n";
#  my $cnt = 0; for my $k ( keys ( %proteins ) ) { print "$k\n"; last if $cnt++ >= 10; }

  return \%proteins;

}
