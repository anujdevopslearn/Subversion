#!/usr/local/bin/perl 
use strict;
use DBI;
use Getopt::Long;
use File::Basename;
use FindBin;
use Data::Dumper;

use lib "$FindBin::Bin/../../perl";

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
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
my $instrument_map = $pep_sel->getInstrumentMap();
$instrument_map->{Any} = 0;


my %code2instrument = reverse( %{$instrument_map} );

# User can specify one or more builds
#
my @update_builds = @ARGV;
my $build_info = get_build_info( builds => \@update_builds );

if ( !scalar( keys( %{$build_info} ) ) ) {
  print "Unable to find any valid builds\n";
  exit;
#} else {
#  print Dumper($build_info);
}

for my $build ( sort( keys(  %{$build_info} ) ) ) {
  my $t0 = time();
  print STDERR "Getting build counts for $build_info->{$build}->{name}($build).\n";
  get_build_peptide_counts( $build );
  my $t1 = time();
  my $delta = $t1 - $t0;
  print STDERR "Lookup took $delta seconds\n";
  my @sql_stmts = ( "DELETE FROM $TBAT_PABST_BUILD_STATISTICS WHERE build_id = $build;" );
  my $bcnt = $build_info->{$build}->{bioseq_cnts}; 
  my $bid = $build_info->{$build}->{bioseq_id}; 
  for my $instr ( keys( %{$build_info->{$build}->{counts}} ) ) {
    my %cov;
    for my $cover ( 1..5 ) {
      $cov{$cover} = $build_info->{$build}->{counts}->{$instr}->{$cover} || 0;
      $cov{any} += $cov{$cover};
    }
    $cov{0} = 0 || $bcnt - $cov{any}; 
    my $cov_string = join( ",", @cov{ qw( 0 1 2 3 4 5 any)} ); 

    my $insert = qq~
      INSERT INTO $TBAT_PABST_BUILD_STATISTICS 
        ( build_id, ref_db, ref_db_cnt, instrument_id, cov_0, cov_1, cov_2, cov_3, cov_4, cov_5, cov_any )
      VALUES ( $build, $bid, $bcnt, $instr,$cov_string ); 
      ~;
    push @sql_stmts, $insert;
  }
  for my $stmt ( @sql_stmts ) {
    $sbeams->do( $stmt );
  }
}
#die Dumper( $build_info );

sub get_build_peptide_counts {

  my $build_id = shift || die;

  # Select total bioseq counts 
	my $sql = qq~
  SELECT COUNT(*) 
  FROM $TBAT_BIOSEQUENCE 
  WHERE $build_info->{$build_id}->{bioseq_clause}
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
	while ( my @row = $sth->fetchrow_array() ) {
    $build_info->{$build_id}->{bioseq_cnts} = $row[0];
    last;
  }
  
  # Tater time!
  # Original way, slow-ish
  $sql = qq~
  select DISTINCT PTI.source_instrument_type_id, PP.pabst_peptide_id, PM.biosequence_id
  FROM $TBAT_PABST_TMP_PEPTIDE PP
  JOIN $TBAT_PABST_TMP_PEPTIDE_ION PI
    ON PP.pabst_peptide_id = PI.pabst_peptide_id
  JOIN $TBAT_PABST_TMP_PEPTIDE_ION_INSTANCE PII
    ON PII.pabst_peptide_ion_id = PI.pabst_peptide_ion_id
  JOIN $TBAT_PABST_TMP_TRANSITION PT 
    ON PI.pabst_peptide_ion_id = PT.pabst_peptide_ion_id
  JOIN $TBAT_PABST_TMP_TRANSITION_INSTANCE PTI 
    ON PTI.pabst_transition_id = PT.pabst_transition_id
  JOIN $TBAT_PABST_TMP_PEPTIDE_MAPPING PM
    ON PP.pabst_peptide_id = PM.pabst_peptide_id
  JOIN $TBAT_BIOSEQUENCE B 
    ON B.biosequence_id = PM.biosequence_id
  WHERE pabst_build_id = $build_id 
  AND $build_info->{$build_id}->{bioseq_clause}
  AND is_predicted = 'N'
  ~;
#	while ( my @row = $sth->fetchrow_array() ) {
#    # hashref bioseq->instrument->peptide->cnt
#    $proteins{$row[2]} ||= {};
#    $proteins{$row[2]}->{$row[0]} ||= {};
#    $proteins{$row[2]}->{$row[0]}->{$row[1]}++;
#  }

  my $trans_sql = qq~
  select PTI.source_instrument_type_id, PP.peptide_sequence
  FROM $TBAT_PABST_TMP_PEPTIDE PP
  JOIN $TBAT_PABST_TMP_PEPTIDE_ION PI
    ON PP.pabst_peptide_id = PI.pabst_peptide_id
  JOIN $TBAT_PABST_TMP_PEPTIDE_ION_INSTANCE PII
    ON PII.pabst_peptide_ion_id = PI.pabst_peptide_ion_id
  JOIN $TBAT_PABST_TMP_TRANSITION PT 
    ON PI.pabst_peptide_ion_id = PT.pabst_peptide_ion_id
  JOIN $TBAT_PABST_TMP_TRANSITION_INSTANCE PTI 
    ON PTI.pabst_transition_id = PT.pabst_transition_id
  WHERE pabst_build_id = $build_id 
  AND is_predicted = 'N'
  ~;

  my $t1 = time();
  print STDERR "exec trans SQL " . time() . "\n";
  my $sth = $sbeams->get_statement_handle( $trans_sql );
  my %peptides;
  my %instruments;
	while ( my @row = $sth->fetchrow_array() ) {
    # hashref peptide->instrument->cnt
    $peptides{$row[1]} ||= {};
    $peptides{$row[1]}->{$row[0]}++;
    $instruments{$row[0]}++;
  }

  my $t2 = time();
  my $delta = $t2 - $t1;
  print STDERR "Done in $delta seconds \n";


  my $map_sql = qq~
  select DISTINCT PP.peptide_sequence, PM.biosequence_id
  FROM $TBAT_PABST_TMP_PEPTIDE PP
  JOIN $TBAT_PABST_TMP_PEPTIDE_MAPPING PM
    ON PP.pabst_peptide_id = PM.pabst_peptide_id
  JOIN $TBAT_BIOSEQUENCE B 
    ON B.biosequence_id = PM.biosequence_id
  WHERE pabst_build_id = $build_id 
  AND $build_info->{$build_id}->{bioseq_clause}
  ~;
  print STDERR "exec map SQL \n";
  my $sth = $sbeams->get_statement_handle( $map_sql );
  my %proteins;
  my $hit = 0;
  my $miss = 0;
	while ( my @row = $sth->fetchrow_array() ) {
#    $peptides{$row[1]} ||= {};
#    $instruments{$row[0]}++;
    # hashref bioseq->instrument->peptide->cnt

    # Many mapping peptides won't have empirical data
    $proteins{$row[1]} ||= {};
    if ( $peptides{$row[0]} ) {
      $hit++;
    } else {
      $miss++;
      next;
    }

    for my $instr ( keys( %instruments ) ) {
      next unless $peptides{$row[0]}->{$instr};

      $proteins{$row[1]}->{$instr} ||= {};
      $proteins{$row[1]}->{$instr}->{$row[0]}++;
    }
    $proteins{$row[1]}->{0} ||= {};
    $proteins{$row[1]}->{0}->{$row[0]}++;
  }

  print STDERR "Done, $hit hit and $miss miss \n";

	while ( my @row = $sth->fetchrow_array() ) {
    # hashref bioseq->instrument->peptide->cnt
  }
  my %counts;
  for my $prot ( keys( %proteins ) ) {
    for my $inst_id ( keys ( %{$proteins{$prot}} ) ) {
      my $cnt = scalar( keys( %{$proteins{$prot}->{$inst_id}} ) );
      $cnt = 5 if $cnt > 5;
      $counts{$inst_id} ||= {};
      $counts{$inst_id}->{$cnt}++;
#      $counts{$code2instrument{$inst_id}} ||= {};
#      $counts{$code2instrument{$inst_id}}->{$cnt}++;
    }
  }
  $build_info->{$build_id}->{counts} = \%counts;
}



sub get_build_info {

  my %args = @_;
  my $build_clause = '';
  if ( $args{builds} && scalar( @{$args{builds}} ) ) {
    $build_clause = "WHERE pabst_build_id IN ( " . join( ',', @{$args{builds}} ) . ')';
  }
  
  # Select build list
	my $sql = qq~
  SELECT pabst_build_id, build_name, organism_id, biosequence_set_id
  FROM $TBAT_PABST_BUILD 
  $build_clause
  ORDER BY pabst_build_id DESC
  ~;

  my %builds;

  my $sth = $sbeams->get_statement_handle( $sql );
	while ( my @row = $sth->fetchrow_array() ) {


    my $bioseq_clause = qq~ 
     biosequence_set_id = $row[3]
    AND biosequence_name NOT LIKE 'DECOY%'
    ~;

    if ( $row[2] == 2 || $row[2] == 6 ) {
      $bioseq_clause .= "AND LEN(biosequence_name) = 6\n";
    } elsif ( $row[2] == 40 ) {
      $bioseq_clause .= "AND biosequence_name LIKE 'Rv%'\n";
    } elsif ( $row[2] == 3 ) {
      $bioseq_clause .= "AND biosequence_name LIKE 'Y%'\n";
    }

#    $builds{$row[0]} ||= {};
    $builds{$row[0]} = { name => $row[1],
                         org => $row[2], 
                         bioseq_id => $row[3], 
                         bioseq_clause => $bioseq_clause };

  }

  return \%builds;
}

__DATA__

