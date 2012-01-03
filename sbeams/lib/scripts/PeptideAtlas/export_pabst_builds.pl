#!/usr/local/bin/perl -w

# This program will export an atlas build as TSV file  

use DBI;
use Getopt::Long;
use FindBin qw( $Bin );

use lib "$Bin/../../perl";
use SBEAMS::Connection::Settings qw( $DBCONFIG $DBINSTANCE );
use SBEAMS::Connection;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::BestPeptideSelector;
use strict;

my $sbeams = SBEAMS::Connection->new();
$sbeams->Authenticate();
my $selector = new SBEAMS::PeptideAtlas::BestPeptideSelector;
$selector->setSBEAMS( $sbeams );
my $map = $selector->getInstrumentMap( invert => 1 );

$|++; # don't buffer output
my $args = processArgs();

{ # MAIN

  my $builds = get_builds();
  for my $build_id ( keys( %{$builds} ) ) {
    print "$build_id ";
    if ( $args->{build_id} ) {
      unless ( grep /^$build_id$/, @{$args->{build_id}} ) {
        print " - skipping\n";
        next;
      }
    }
    print " - exporting ... ";
    export_build( build_id => $build_id, name => $builds->{$build_id} );
    print " Done\n";
  }

}

sub get_builds {
  my $sql = "SELECT pabst_build_id, build_name FROM $TBAT_PABST_BUILD";
  my $sth = $sbeams->get_statement_handle( $sql );
  my %builds;
  while ( my @row = $sth->fetchrow_array() ) {
    $builds{$row[0]} = $row[1];
  }
  return \%builds;
}


sub export_build {
  my %args = @_;
#  for my $arg ( keys( %args ) ) { print "$arg => $args{$arg}\n"; }

  my $file_name = $args{name} . '.exp';
  $file_name =~ s/\s+/_/g;
  my $gz_file_name = $args{name} . '.exp.gz';

  if ( !$args->{force} && ( -e $file_name || -e $gz_file_name ) ) {
    print STDERR "File $file_name already exists, use -force option to force overwrite.  Skipping\n";
    return;
  }

  my @headings = qw( biosequence_name preceding_residue modified_peptide_sequence
                     following_residue synthesis_adjusted_score transition_source
                     precursor_ion_mz precursor_ion_charge fragment_ion_mz
                     fragment_ion_charge fragment_ion_label ion_rank
                     relative_intensity SSRCalc_relative_hydrophobicity
                     merged_score n_observations max_precursor_intensity );

  my $col_string = join( ", ", @headings );

  print STDERR "Exporting $file_name\n" if $args->{verbose};

  open ( FIL, ">$file_name" );
  print FIL join( "\t", @headings ) . "\n";

  $col_string =~ s/modified_peptide_sequence/PI.modified_peptide_sequence/;
  $col_string =~ s/transition_source/instrument_type_name/;
  $col_string =~ s/SSRCalc_relative_hydrophobicity/elution_time/;
  $col_string =~ s/n_observations/PII.n_observations/;
  $col_string =~ s/biosequence_name/BS.biosequence_name/;
   
  my $sql = qq~
  SELECT DISTINCT  
  $col_string, PTI.is_predicted
  FROM PeptideAtlas.dbo.pabst_tmp_peptide PP 
  JOIN PeptideAtlas.dbo.pabst_tmp_peptide_ion PI 
  ON PP.pabst_peptide_id = PI.pabst_peptide_id
  JOIN PeptideAtlas.dbo.pabst_tmp_peptide_mapping PM 
  ON PM.pabst_peptide_id = PP.pabst_peptide_id
  JOIN PeptideAtlas.dbo.pabst_tmp_peptide_ion_instance PII 
  ON PI.pabst_peptide_ion_id = PII.pabst_peptide_ion_id
  JOIN PeptideAtlas.dbo.pabst_tmp_transition PT 
  ON PT.pabst_peptide_ion_id = PI.pabst_peptide_ion_id 
  JOIN PeptideAtlas.dbo.pabst_tmp_transition_instance PTI 
  ON PT.pabst_transition_id = PTI.pabst_transition_id 
  JOIN PeptideAtlas.dbo.instrument_type IT 
  ON ( IT.instrument_type_id = PTI.source_instrument_type_id  AND
       IT.instrument_type_id = PII.source_instrument_type_id ) 
  JOIN PeptideAtlas.dbo.pabst_tmp_source_priority PSP 
  ON ( PSP.source_instrument_type_id = PTI.source_instrument_type_id )
  JOIN peptideatlas.dbo.biosequence BS
  ON BS.biosequence_id = PM.biosequence_id 
  LEFT JOIN PeptideAtlas.dbo.elution_time ET ON ET.modified_peptide_sequence = PP.peptide_sequence
  LEFT JOIN PeptideAtlas.dbo.elution_time_type ETT ON ET.elution_time_type_id = ETT.elution_time_type_id
  WHERE  PP.pabst_build_id IN ( $args{build_id} )
  AND ( BS.biosequence_name LIKE 'P%'  )
  AND (elution_time_type = 'SSRCalc' OR elution_time_type IS NULL)
  ORDER BY biosequence_name, 
  PTI.is_predicted ASC,
  synthesis_adjusted_score DESC,
  PI.modified_peptide_sequence,
  instrument_type_name DESC,
  PII.max_precursor_intensity DESC,
  PII.n_observations DESC,
  relative_intensity DESC,
  ion_rank ASC
  ~;

#  print STDERR "\tpreparing SQL " . time() . "\n" if $args->{verbose};
  my $sth = $sbeams->get_statement_handle( $sql );
  print STDERR "\tprinting " . time() . "\n" if $args->{verbose};
  while ( my @row = $sth->fetchrow_array() ) {
    for my $i ( 6, 8 ) {
      $row[$i] = sprintf( "%0.2f", $row[$i] );
    }
    for my $i ( 4, 13, 14 ) {
      $row[$i] = sprintf( "%0.1f", $row[$i] );
    }
    $row[12] = int( $row[12] );
    $row[5] .= '(pred)' if $row[16] eq 'Y';
    print FIL join( "\t", @row[0..15] ) . "\n";
    
  }
  close FIL;
  return;

}


sub printUsage {
  my $err = shift || '';
  print( <<"  EOU" );
   $err
   
   Usage: $0

  EOU
  exit;
}

sub processArgs {
  my %args;
  unless( GetOptions ( \%args, 'build_id=i@', 'verbose', 'force' ) ) {
    printUsage("Error with options, please check usage:");
  }
  die "need build_id " unless $args{build_id};

  return \%args;
}

__DATA__
# Removed from table list; 
#<export_data table_name="AT_sample_publication" qualifiers="sample_id IN ( SELECT DISTINCT sample_id FROM TBAT_ATLAS_BUILD_SAMPLE WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
#<export_data table_name="AT_atlas_search_batch_parameter" qualifiers="atlas_search_batch_id IN ( SELECT DISTINCT atlas_search_batch_id FROM TBAT_ATLAS_BUILD_SEARCH_BATCH WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
#  <export_data table_name="AT_atlas_search_batch_parameter_set" qualifiers="atlas_search_batch_id IN ( SELECT DISTINCT atlas_search_batch_id FROM TBAT_ATLAS_BUILD_SEARCH_BATCH WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
# <export_data table_name="AT_peptide_instance_sample" qualifiers="peptide_instance_id IN ( SELECT DISTINCT peptide_instance_id FROM TBAT_PEPTIDE_INSTANCE WHERE atlas_build_id=ATLAS_BUILD_ID )"></export_data>
#
#   <export_data table_name="AT_modified_peptide_instance_sample" qualifiers="modified_peptide_instance_id IN ( select modified_peptide_instance_id FROM TBAT_MODIFIED_PEPTIDE_INSTANCE WHERE peptide_instance_id IN ( SELECT DISTINCT peptide_instance_id FROM TBAT_PEPTIDE_INSTANCE WHERE atlas_build_id=ATLAS_BUILD_ID ) )"></export_data>

__DATA__
