#!/usr/local/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use File::Basename;

use lib( '../../perl/' );

use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::BestPeptideSelector;
use SBEAMS::PeptideAtlas::Tables;

$|++; # don't buffer output

my $args = process_args();
my $sbeams = SBEAMS::Connection->new();
my $atlas = SBEAMS::PeptideAtlas->new();
$atlas->setSBEAMS( $sbeams );
my $pep_sel = SBEAMS::PeptideAtlas::BestPeptideSelector->new();

my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;

{ # Main 
  if ( $args->{show_builds} ) {
    show_builds();
  } else {
    my $observed = get_observed_peptides();
    my $theoretical = get_theoretical_peptides();
    my $merged = merge_peptides( $observed, $theoretical );

    my $headings = get_headings();
    if ( $args->{tsv_file} ) {
      open( TSV, ">$args->{tsv_file}" ) || print_usage( "Unable to open file $args->{tsv_file}" );
      print TSV join( "\t", @$headings ) . "\n";
    } else {
      print join( "\t", @$headings ) . "\n";
    }

    for my $peptide ( @{$merged} ) {
      if ( $args->{tsv_file} ) {
        print TSV join( "\t", @{$peptide} ) . "\n";
      } else {
        print join( "\t", @{$peptide} ) . "\n";
      }
    }
    close TSV if $args->{tsv_file};

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
              'protein_file=s', 'n_obs=i' );

  print_usage() if $args{help};

  if ( $args{show_builds} ) {
    $args{show_builds} = 'def' unless $args{show_builds} eq 'all';  
  } else {
    my $err;
    for my $k ( qw( atlas_build ) ) {
      $err .= ( $err ) ? ", $err" : "Missing required parameter(s) $k" if !defined $args{$k};
    }
    print_usage( $err ) if $err;
  }
  if ( $args{n_obs}  && $args{n_obs} !~ /^\d+$/ ) {
    print_usage( "n_obs must be an integer" );
  }

  return \%args;
}

sub print_usage {
  my $msg = shift || '';
  my $sub = basename( $0 );
  print <<"  END";
      $msg

usage: $sub -a build_id [ -t outfile -n obs_cutoff -p proteins_file ]

   -a, --atlas_build    (Numeric) atlas build ID to query 
   -p, --protein_file   file of protein names, one per line.  Should match biosequence.biosequence_name 
   -s, --show_builds    Print info about builds in db 
   -t, --tsv_file       print output to specified file rather than stdout
   -n, --n_obs          Minimum number of times seen for observed peptides 
   -h, --help           Print usage
  END
# End of the line
  exit;
}

sub get_observed_peptides {
  
  my $build_where = "WHERE PI.atlas_build_id = $args->{atlas_build}";
  my $name_in = ( $args->{protein_file} ) ? get_protein_in_clause() : '';
  my $nobs_and = ( $args->{n_obs} ) ? "AND n_observations > $args->{n_obs}" : ''; 

  # Score adjustment for observed peptides!!!
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
     my $row = $pep_sel->pabst_evaluate_peptides( peptides => [\@row], seq_idx => 2, score_idx => 4 );
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

sub get_headings {

  my @headings = qw( biosequence_name preceding_residue peptide_sequence following_residue           
                     suitability_score molecular_weight SSRCalc_relative_hydrophobicity
                     n_protein_mappings n_genome_locations best_probability n_observations
                     synthesis_score synthesis_warnings syntheis_adjusted_score );
  return \@headings;
}

sub get_protein_in_clause {
  # protein list in a file
  open PROT, $args->{protein_file} || print_usage( "Unable to open protein file $args->{protein_file}" );
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
    my $row = $pep_sel->pabst_evaluate_peptides( peptides => [\@row], seq_idx => 2, score_idx => 4 );
    @row = @{$row->[0]};

    # Each protein is a hashref
    $proteins{$row[0]} ||= {};
    # That hashref points to the row
    $proteins{$row[0]}->{$row[1].$row[2].$row[3]} = \@row;
    $pep_cnt++;
  }
  print STDERR "Saw " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n";
#  my $cnt = 0; for my $k ( keys ( %proteins ) ) { print "$k\n"; last if $cnt++ >= 10; }
  return \%proteins;
}

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


__DATA__
sub get_aa_usage {
  my %results;
  my $build_where = "WHERE AB.atlas_build_id = $args->{atlas_build}";
  my $nobs_and = "AND n_observations > $args->{n_obs_cutoff}" if $args->{n_obs_cutoff};
  $nobs_and ||= '';

  # Get some info
  my $sql = get_build_sql();
  $sql .= "\n  $build_where\n ";
#  AB.atlas_build_id, atlas_build_name, organism_name, set_name, BS.biosequence_set_id, organism_specialized_build, probability_threshold

  my $r = $sbeams->selectrow_arrayref( $sql );
  my $cutoff = sprintf ( "%0.2f", $r->[5] );
  print STDERR <<"  END";
  Build ID:\t$r->[0]
  Build Name:\t$r->[1]
  Organism:\t$r->[2]
  P cutoff:\t$cutoff
  Reference DB:\t$r->[3]
  END

  print STDERR "Fetching peptides from build $r->[1]\n";
  my $pepsql =<<"  END"; 
  SELECT DISTINCT peptide_accession, peptide_sequence
   FROM $TBAT_PEPTIDE_INSTANCE AB
   INNER JOIN $TBAT_PEPTIDE P
          ON ( AB.peptide_id = P.peptide_id )
  $build_where
  $nobs_and
  ORDER BY peptide_accession
  END

  $pepsql = $sbeams->evalSQL( $pepsql );
#  print STDERR "$pepsql\n";
  my $sth = $dbh->prepare( $pepsql );
  $sth->execute();

  my %aa;
  my $cnt;
  my $aa_cnt;
  while( my @row = $sth->fetchrow_array() ) {
    $cnt++;
    my @aa = split "", $row[1];
    for my $aa ( @aa ) {
      $aa{$aa}++;
      $aa_cnt++;
    }
#    last if $cnt > 5;
  }
  print STDERR "Found $aa_cnt amino acids in $cnt peptides\n";

  print STDERR "Fetching proteins from refdb $r->[3]\n";
  my $dbsql =<<"  END"; 
  SELECT biosequence_seq FROM $TBAT_BIOSEQUENCE
  WHERE biosequence_set_id = $r->[4]
  END

  my $sth = $dbh->prepare( $sbeams->evalSQL($dbsql) );
  $sth->execute();

  my %dbaa;
  my $dbcnt;
  my $dbaa_cnt;
  while( my @row = $sth->fetchrow_array() ) {
    $dbcnt++;
    my @aa = split "", $row[0];
    for my $aa ( @aa ) {
      $dbaa{$aa}++;
      $dbaa_cnt++;
    }
#    last if $dbcnt > 5;
  }

  print STDERR "Saw $dbaa_cnt total aa's in $dbcnt proteins\n";
  print "AA\tBuild $r->[0]\tRef DB\n";
#  print "AA\tAtlas %\tIPI %\tAtlas #\n";
  for my $aa (sort(keys( %aa) )) {
#    my $perc = sprintf( "%0.1f", $aa{$aa}/$aa_cnt * 100 );
    next if $aa =~ /[XBZ]/;
    print "$aa\t$aa{$aa}\t$dbaa{$aa}\n";
#    print "$aa\t$perc%\t$db_aa->{$aa}%\t($aa{$aa}) \n";
  }
}


sub get_build_sql {
  my $type = shift || '';

  my $sql =<<"  END";
  SELECT AB.atlas_build_id, atlas_build_name, organism_name, set_name, BS.biosequence_set_id,
         probability_threshold
  FROM $TBAT_ATLAS_BUILD AB
  JOIN $TBAT_BIOSEQUENCE_SET BS ON BS.biosequence_set_id = AB.biosequence_set_id
  JOIN $TB_ORGANISM O ON BS.organism_id = O.organism_id
  END

  if ( $type eq 'def' ) {
    $sql .= "\n  JOIN $TBAT_DEFAULT_ATLAS_BUILD  DAB ON AB.atlas_build_id = DAB.atlas_build_id \n";
  }
  return $sql;
}



__DATA__

sub get_db_aa {
  my $file = shift;

# Uncomment to use IPI canned
#  print "using canned version\n";
# print "Saw 26317132 aa in 60397 proteins\n";
#  return get_ipi_nums();

# Uncomment to use YEAST canned
#  print "using canned version\n";
# print "Saw 3019081 aa in 6714 proteins\n";
#  return get_yeast_nums();

# Uncomment to use ENSP canned
  print "using canned version\n";
  print "Saw 23659384 aa in 48218 proteins\n";
  return get_ensp_nums();

  
#  return get_ipi_perc();
  open FIL, "$file" || die "Unable to open file $file";
  my $cnt;
  my $aa_cnt;
  my %aa;
  while ( my $line = <FIL> ) {
    if ( $line =~ /^>/ ) {
      $cnt++;
      next;
    }
    $line =~ s/\s//g;
    $line =~ s/\*//g;
    if ( $line !~ /^[A-Za-z]*$/ ){
      die "Trouble with line $cnt: $line";
    }
    my @aa = split "", $line;
    for my $aa ( @aa ) {
      $aa{$aa}++;
      $aa_cnt++;
    }
#    last if $cnt > 10;
  }
  print "Saw $aa_cnt aa in $cnt proteins\n";
  for my $aa (sort(keys( %aa)) ) {
    print "$aa => $aa{$aa},\n";
  }
  for my $aa (sort(keys( %aa)) ) {
    $aa{$aa} = sprintf( "%0.1f", $aa{$aa}/$aa_cnt * 100 );
    print "$aa => $aa{$aa},\n";
  }
  exit;
  return \%aa;
}

sub get_ipi_nums {
  return { A => 1841393,
           B => 67,
           C => 603139,
           D => 1229870,
           E => 1854882,
           F => 932285,
           G => 1763164,
           H => 695002,
           I => 1119370,
           K => 1488734,
           L => 2583265,
           M => 561740,
           N => 921425,
           P => 1714680,
           Q => 1264388,
           R => 1518949,
           S => 2212529,
           T => 1424025,
           V => 1572115,
           W => 334939,
           X => 3874,
           Y => 677232,
           Z => 65 };

sub get_ipi_perc {
  return { A => 7.0,
           B => 0.0,
           C => 2.3,
           D => 4.7,
           E => 7.0,
           F => 3.5,
           G => 6.7,
           H => 2.6,
           I => 4.3,
           K => 5.7,
           L => 9.8,
           M => 2.1,
           N => 3.5,
           P => 6.5,
           Q => 4.8,
           R => 5.8,
           S => 8.4,
           T => 5.4,
           V => 6.0,
           W => 1.3,
           X => 0.0,
           Y => 2.6,
           Z => 0.0 };
}

sub get_yeast_nums {
  return { 
A => 165299,
C => 39853,
D => 173775,
E => 194201,
F => 136339,
G => 149481,
H => 65862,
I => 198386,
K => 219584,
L => 289136,
M => 63475,
N => 184380,
P => 132446,
Q => 118145,
R => 134562,
S => 273404,
T => 178519,
V => 168440,
W => 31557,
Y => 102237
            };
}

sub get_yeast_perc {
  return { 
A => 5.5,
C => 1.3,
D => 5.8,
E => 6.4,
F => 4.5,
G => 5.0,
H => 2.2,
I => 6.6,
K => 7.3,
L => 9.6,
M => 2.1,
N => 6.1,
P => 4.4,
Q => 3.9,
R => 4.5,
S => 9.1,
T => 5.9,
V => 5.6,
W => 1.0,
Y => 3.4,
            };
}

sub get_ensp_perc {
  return { 
A => 7.0,
C => 2.2,
D => 4.8,
E => 7.1,
F => 3.6,
G => 6.6,
H => 2.6,
I => 4.3,
K => 5.8,
L => 9.9,
M => 2.2,
N => 3.6,
P => 6.3,
Q => 4.8,
R => 5.7,
S => 8.3,
T => 5.3,
U => 0.0,
V => 6.0,
W => 1.2,
X => 0.0,
Y => 2.6,
   };
}

sub get_ensp_nums {
  return { 
 A => 1646521,
C => 532092,
D => 1126503,
E => 1687634,
F => 852632,
G => 1564438,
H => 616165,
I => 1027001,
K => 1360678,
L => 2339218,
M => 510249,
N => 850023,
P => 1502366,
Q => 1136290,
R => 1348726,
S => 1967430,
T => 1260741,
U => 9,
V => 1413107,
W => 292958,
X => 1,
Y => 624602

    
            };
}

}process_args {
  my %args;
  GetOptions(\%args, 'mzfile=s', 'hitfile=s', 'tolerance=i', 'verbose', 'ox_met:i', 'identified' );
  for my $k ( qw( mzfile hitfile tolerance ) ) {
    unless ( $args{$k} ) {
      print <<"      END";
Missing argument $k:

usage: $0 -m mz input file -h hit file -t mass tolerance (ppm) [-v -o]

   -m, --mzfile      Name of file with mz data
   -h, --hitfile     Name of output file
   -t, --tolerance   Mass tolerance in parts per million
   -v, --verbose     More informative output
   -i, --identified  Query vs. identified peptides (default is predicted).
   -o, --ox_met      Allow specified number of oxidized mets ( 1 or 2 only )
      END
      exit;
    }
  }

  return \%args;
}

