#!/usr/local/bin/perl 

use strict;
use DBI;
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

my $args = process_args();

my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;



sub print_process {
  my @procs = `ps aux`;
  my $cnt = 0;
  for my $p ( @procs ) {
    $p =~ s/\s+/\t/g;
    my @fields = split( "\t", $p );
    if ( !$cnt++ || ( $p =~ /fetch_best/ && $p =~ /perl/ ) ) {
      print join( "\t", @fields[2,3] ) . "\n";
    }
  }
}

{ # Main 


  print STDERR "Starting: " . time() . "\n" if $args->{verbose};
  print STDERR "Fetching observed peptides\n" if $args->{verbose};
  print_process() if $args->{verbose};
  my $observed = get_observed_peptides();
  print STDERR "Fetching theoretical peptides\n" if $args->{verbose};
  print_process() if $args->{verbose};
  my $theoretical = get_theoretical_peptides();
  print STDERR "Merging peptides ($args->{n_peptides})\n" if $args->{verbose};
  print_process() if $args->{verbose};

  my %chk_args;
  if ( $args->{chk_file} && defined $args->{chk_scr} ) {
    $chk_args{chk_peptide_hash} = get_chk_hash();
    $chk_args{peptide_hash_scr} = $args->{chk_scr};
  }

  my $merged = $pep_sel->merge_pabst_peptides(  obs => $observed, 
                                               theo => $theoretical,
                                         n_peptides => $args->{n_peptides},
                                            verbose => $args->{verbose},
                                            %chk_args
                                             );

  print STDERR "Freeing memory\n" if $args->{verbose};
  print_process() if $args->{verbose};
  # Free up some memory!!!
  undef $observed;
  undef $theoretical;

  print STDERR "Printing peptides\n" if $args->{verbose};
  print_process() if $args->{verbose};

  my $headings = get_headings();
  if ( $args->{tsv_file} ) {
    open( TSV, ">$args->{tsv_file}" ) || print_usage( "Unable to open file $args->{tsv_file}" );
    print TSV join( "\t", @$headings ) . "\n";
  } else {
    print join( "\t", @$headings ) . "\n";
  }

  for my $peptide ( @{$merged} ) {
    if ( defined $args->{min_score} ) {
      next if $peptide->[17] <= $args->{min_score};
    }
    if ( defined $args->{no_mc} ) {
      next if ( $peptide->[14] && $peptide->[14] =~ /MC/ );
    }
    if ( defined $args->{no_st} ) {
      next if ( $peptide->[14] && $peptide->[14] =~ /ST/ );
    }

    $peptide->[4] = sprintf( "%0.2f", $peptide->[4] ) if $peptide->[4] !~ /na/;
    $peptide->[5] = sprintf( "%0.2f", $peptide->[5] ) if $peptide->[5] !~ /na/;
    $peptide->[6] = sprintf( "%0.2f", $peptide->[6] ) if $peptide->[6] !~ /na/;
    $peptide->[7] = sprintf( "%0.2f", $peptide->[7] ) if $peptide->[7] !~ /na/;
    $peptide->[15] ||= 'na';
    $peptide->[16] = sprintf( "%0.2f", $peptide->[16] ) if $peptide->[16];
    $peptide->[17] = sprintf( "%0.3f", $peptide->[17] );
    if ( $args->{tsv_file} ) {
      print TSV join( "\t", @{$peptide} ) . "\n";
    } else {
        print join( "\t", @{$peptide} ) . "\n";
      }
    }
    close TSV if $args->{tsv_file};

    print STDERR "Finishing: " . time() . "\n" if $args->{verbose};




} # End main

sub show_builds {

  my $regex = shift;
  my $name_like = '';
  if ( $regex ) {
    $name_like = "WHERE atlas_build_name LIKE '%$regex%'";
  }

  my $sql = qq~
         SELECT AB.atlas_build_id, atlas_build_name, organism_name, BS.biosequence_set_id, set_name
         FROM $TBAT_ATLAS_BUILD AB
         JOIN $TBAT_BIOSEQUENCE_SET BS ON BS.biosequence_set_id = AB.biosequence_set_id
         JOIN $TB_ORGANISM O ON BS.organism_id = O.organism_id
         $name_like
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
  # Terminal request.
  exit;
}

sub process_args {

  my %args = ( atlas_build => [] );

  GetOptions( \%args, 'atlas_build=s@', 'show_builds', 'help', 'tsv_file=s', 
              'protein_file=s', 'n_peptides=i', 'config=s', 'default_config', 
              'bioseq_set=i', 'obs_min=i', 'verbose', 'name_prefix=s',
              'build_name=s', 'min_score=f', 'chk_file=s', 'chk_scr=f',
              'no_mc', 'no_st'
             ) || print_usage();

  # Short-circuit if we just want help/documention
  print_usage() if $args{help};
  print_default_config() if $args{default_config};
  show_builds( $args{build_name} ) if $args{show_builds};

  my $err;
  for my $k ( qw( atlas_build ) ) {
    $err .= ( $err ) ? ", $err" : "Missing required parameter(s) $k" if !defined $args{$k};
  }
  print_usage( $err ) if $err;

  for my $opt ( qw( n_peptides obs_min ) ) {
    if ( $args{$opt}  && $args{$opt} !~ /^\d+$/ ) {
      print_usage( "$opt must be an integer" );
    }
  }

  # Atlas build option changed from single INT to string array - might have 
  # appended weight in addition to id.
  my @build_ids;
  my @build_weights;
  for my $build ( @{$args{atlas_build}} ) {
    $build =~ /(\d+)\:*(\d*)/;
    my $id = $1 || die( "can't parse build_id from $build" );
    my $weight = $2 || 1;
    push @build_ids, $id;
    push @build_weights, $weight;
  }
  if ( !scalar( @build_ids ) ) {
    print_usage( "missing required parameter atlas_build" );
  }

  $args{atlas_build} = \@build_ids;
  $args{build_weights} = \@build_weights;

  if ( !$args{bioseq_set} ) {
    $args{bioseq_set} = $atlas->getBuildBiosequenceSetID( build_id => $build_ids[0] );
    print "Bioseq set id is $args{bioseq_set} from $build_ids[0]\n";
  }
      
  if ( $args{config} ) {
    open CFG, $args{config} || print_usage( "Unable to open config file $args{config}");
    my %config_vals;
    while( my $line = <CFG> ) {
      chomp $line;
      $line =~ s/\#.*$//;
      $line =~ /^(\S+)\s+(\S+)/;
      if ( $1 && defined $2 ) {
        $config_vals{$1} = $2;
      }
    }
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

sub print_usage {
  my $msg = shift || '';
  my $sub = basename( $0 );
  print <<"  END";
      $msg

usage: $sub -a build_id [ -t outfile -o 3 -p proteins_file -v --conf my_config_file  ]

   -a, --atlas_build    one or more atlas build ids to be queried for observed 
                        peptides, will be used in order provided.  Can be 
                        specified as a numeric id ( -a 123 -a 189 ) or as a composite
                        id:weight ( -a 123:3 ).  Scores from EPS and ESS will 
                        be multiplied by given weight, defaults to 1.
       --config         Config file defining penalites for various sequence  
       --chk_file       File of peptide accessions for which to modify score.  
                        Primary purpose is to boost proteins on a particular 
                        list, e.g.
       --chk_scr        Score to apply for items in chk_file above.
   -d, --default_config prints an example config file with defaults in CWD,
                        named best_peptide.conf, will not overwrite existing
                        file.  Exits after printing.
   -p, --protein_file   file of protein names, one per line.  Should match 
                        biosequence.biosequence_name
   -s, --show_builds    Print info about builds in db 
       --build_name     Regular expression to limit return values from 
                        show builds, will be used in LIKE clause, with wildcard
                        characters added automatically.
   -b, --bioseq_set     Explictly defined biosequence set.  If not provided, 
                        the BSS defined by the first atlas_build specified will
                        be used.
   -t, --tsv_file       print output to specified file rather than stdout
       --n_peptides     number of peptides to return per protein
       --name_prefix    prefix constraint on biosequences, allows subset of 
                        of bioseqs to be selected.
   -o, --obs_min        Minimum n_obs to consider for observed peptides
   -m, --min_score      Only print out peptides above min score threshold
   -h, --help           Print usage
   -v, --verbose        Verbose output, prints progress 
  END
# End of the line
  exit;
}

sub get_observed_peptides {
  
  my $builds = join( ',', @{$args->{atlas_build}} );

  my $build_where = "WHERE PI.atlas_build_id IN ( $builds )";
  my $name_in = ( $args->{protein_file} ) ? get_protein_in_clause() : '';
  my $nobs_and = ( $args->{obs_min} ) ? "AND n_observations > $args->{obs_min}" : ''; 
  my $name_like = ( $args->{name_prefix} ) ? "AND biosequence_name like '$args->{name_prefix}%'" : ''; 

  # Short circuit with BestPeptideSelector object method!
  return $pep_sel->get_pabst_multibuild_observed_peptides(   atlas_build => $args->{atlas_build},
                                                build_weights => $args->{build_weights}, 
                                                protein_in_clause => $name_in, 
                                                  min_nobs_clause => $nobs_and, 
                                                        name_like => $name_like, 
                                                          verbose => $args->{verbose}
                                              );
}

sub get_headings {

  return $pep_sel->get_pabst_headings();

}

sub get_chk_hash {
  # args is global : (
  return {} unless ( $args->{chk_file} && defined $args->{chk_scr} );

  my %chk_hash;
  open CHK, $args->{chk_file} || die "Unable to open chk_file $args->{chk_file}";

  while ( my $chk_line = <CHK> ) {
    chomp $chk_line;
    $chk_hash{$chk_line}++;
  }
  close CHK;
  return \%chk_hash;
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
  
  my $build_where = "WHERE B.biosequence_set_id = $args->{bioseq_set}";
  my $name_in = ( $args->{protein_file} ) ? get_protein_in_clause() : '';

  # Short circuit with BestPeptideSelector object method!
  return $pep_sel->get_pabst_theoretical_peptides( 
                                             bioseq_set => $args->{bioseq_set},
                                      protein_in_clause => $name_in, 
                                                verbose => $args->{verbose}
                                                 );
}

