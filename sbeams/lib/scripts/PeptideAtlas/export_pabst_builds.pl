#!/usr/local/bin/perl

# This program will export an atlas build as TSV file  

use DBI;
use Getopt::Long;
use FindBin qw( $Bin );
use Data::Dumper;

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

  my @headings = qw( preceding_residue modified_peptide_sequence
                     following_residue synthesis_adjusted_score transition_source
                     precursor_ion_mz precursor_ion_charge fragment_ion_mz
                     fragment_ion_charge fragment_ion_label ion_rank
                     relative_intensity SSRCalc_relative_hydrophobicity
                     merged_score n_observations max_precursor_intensity );

  my $col_string = join( ", ", @headings );

  unshift @headings, 'protein';

  print STDERR "Exporting $file_name\n" if $args->{verbose};

  open ( FIL, ">$file_name" );
  print FIL join( "\t", @headings ) . "\n";

  $col_string =~ s/modified_peptide_sequence/PI.modified_peptide_sequence/;
  $col_string =~ s/transition_source/instrument_type_name/;
  $col_string =~ s/n_observations/PII.n_observations/;
  $col_string =~ s/biosequence_name/BS.biosequence_name/;

  my $bio_sql = qq~
  SELECT biosequence_name, BS.biosequence_id, PM.pabst_peptide_id
  FROM $TBAT_PABST_PEPTIDE PP 
  JOIN $TBAT_PABST_PEPTIDE_MAPPING PM 
    ON PM.pabst_peptide_id = PP.pabst_peptide_id
  JOIN $TBAT_BIOSEQUENCE BS
    ON BS.biosequence_id = PM.biosequence_id
  WHERE pabst_build_id = $args{build_id}
  ORDER BY biosequence_name ASC
  ~;
#  ORDER BY PP.pabst_peptide_id ASC

  my $sth = $sbeams->get_statement_handle( $bio_sql );
  my $cnt = 0;
  my $pep_id;

  my $empirical_constraint = '';
  if ( $args->{empirical_only} ) {
    $empirical_constraint = "AND PTI.is_predicted <> 'Y'";
  }
  my $source_constraint = '';
  if ( $args->{instrument_type} ) {
    $source_constraint = "AND PTI.source_instrument_type_id = $args->{instrument_type}";
  }


    my $sql = qq~
    SELECT DISTINCT  
    $col_string, PTI.is_predicted
    FROM $TBAT_PABST_TMP_PEPTIDE PP 
  
    JOIN $TBAT_PABST_TMP_PEPTIDE_ION PI 
    ON PP.pabst_peptide_id = PI.pabst_peptide_id
  
    JOIN $TBAT_PABST_TMP_PEPTIDE_ION_INSTANCE PII 
    ON PI.pabst_peptide_ion_id = PII.pabst_peptide_ion_id
    
    JOIN $TBAT_PABST_TMP_TRANSITION PT 
    ON PT.pabst_peptide_ion_id = PI.pabst_peptide_ion_id 
    
    JOIN $TBAT_PABST_TMP_TRANSITION_INSTANCE PTI 
    ON PT.pabst_transition_id = PTI.pabst_transition_id 
    
    JOIN $TBAT_INSTRUMENT_TYPE IT 
    ON ( IT.instrument_type_id = PTI.source_instrument_type_id  AND
         IT.instrument_type_id = PII.source_instrument_type_id ) 
    
    JOIN $TBAT_PABST_TMP_SOURCE_PRIORITY PSP 
    ON ( PSP.source_instrument_type_id = PTI.source_instrument_type_id )
    
    WHERE  PP.pabst_build_id IN ( $args{build_id} )
    AND PP.pabst_peptide_id = ? 
    $source_constraint
    $empirical_constraint
    ORDER BY 
    PTI.is_predicted ASC,
    synthesis_adjusted_score DESC,
    PI.modified_peptide_sequence,
    instrument_type_name DESC,
    PII.max_precursor_intensity DESC,
    PII.n_observations DESC,
    relative_intensity DESC,
    ion_rank ASC
  ~;

  my $dbh = $sbeams->getDBHandle();
  my $prep_sth = $dbh->prepare( $sql );
  print "\n";

  while ( my @peprow = $sth->fetchrow_array() ) {

    $prep_sth->execute( $peprow[2] );

    print STDERR "\tprinting " . time() . "\n" if $args->{verbose};

    my %max_ions;
    while ( my @row = $prep_sth->fetchrow_array() ) {
      unshift( @row, $peprow[0] );

      if( $args->{empirical_only} ) {
        next if $row[17] eq 'Y';
      }

      my $ion_key = join( ':', @row[2,7] );
      $max_ions{$ion_key}++;
      if ( $args->{max_transitions} && $max_ions{$ion_key} > $args->{max_transitions} ) {
        next;
      }

      if ( $args->{yonly} && $row[10] !~ /^y/i ) {
        next;
      } elsif ( $args->{noneutralloss} && $row[10] =~ /[by]\d+\-/i ) {
        next;
      }

      for my $i ( 6, 8 ) {
        $row[$i] = sprintf( "%0.2f", $row[$i] );
      }
      for my $i ( 4, 13, 14 ) {
        $row[$i] = sprintf( "%0.1f", $row[$i] );
      }
      $row[12] = int( $row[12] );
      $row[5] .= '(pred)' if $row[17] eq 'Y';
      print FIL join( "\t", @row[0..16] ) . "\n";

      
    }
    $cnt++;
    print "." unless $cnt % 100;
    print STDERR  time() . "\n" unless $cnt % 2000;

  } # End peptide_id loop
#  print "maximum id is $pep_id at " . time() . "\n";
  
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
  unless( GetOptions ( \%args, 'build_id=i@', 'verbose', 'force', 'yonly',
                       'noneutralloss', 'max_transitions=i', 'empirical_only', 'instrument_type:i' ) ) {
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
#!/usr/local/bin/perl

# This program will export an atlas build as TSV file  

use DBI;
use Getopt::Long;
use FindBin qw( $Bin );
use Data::Dumper;

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

  my @headings = qw( preceding_residue modified_peptide_sequence
                     following_residue synthesis_adjusted_score transition_source
                     precursor_ion_mz precursor_ion_charge fragment_ion_mz
                     fragment_ion_charge fragment_ion_label ion_rank
                     relative_intensity SSRCalc_relative_hydrophobicity
                     merged_score n_observations max_precursor_intensity );

  my $col_string = join( ", ", @headings );

  unshift @headings, 'protein';

  print STDERR "Exporting $file_name\n" if $args->{verbose};

  open ( FIL, ">$file_name" );
  print FIL join( "\t", @headings ) . "\n";

  $col_string =~ s/modified_peptide_sequence/PI.modified_peptide_sequence/;
  $col_string =~ s/transition_source/instrument_type_name/;
  $col_string =~ s/n_observations/PII.n_observations/;
  $col_string =~ s/biosequence_name/BS.biosequence_name/;

  my $bio_sql = qq~
  SELECT biosequence_name, BS.biosequence_id, PM.pabst_peptide_id
  FROM $TBAT_PABST_PEPTIDE PP 
  JOIN $TBAT_PABST_PEPTIDE_MAPPING PM 
    ON PM.pabst_peptide_id = PP.pabst_peptide_id
  JOIN $TBAT_BIOSEQUENCE BS
    ON BS.biosequence_id = PM.biosequence_id
  WHERE pabst_build_id = $args{build_id}
  ORDER BY PP.pabst_peptide_id ASC
  ~;

  my $sth = $sbeams->get_statement_handle( $bio_sql );
  my $cnt = 0;
  my $pep_id;


    my $sql = qq~
    SELECT DISTINCT  
    $col_string, PTI.is_predicted
    FROM $TBAT_PABST_TMP_PEPTIDE PP 
  
    JOIN $TBAT_PABST_TMP_PEPTIDE_ION PI 
    ON PP.pabst_peptide_id = PI.pabst_peptide_id
  
    JOIN $TBAT_PABST_TMP_PEPTIDE_ION_INSTANCE PII 
    ON PI.pabst_peptide_ion_id = PII.pabst_peptide_ion_id
    
    JOIN $TBAT_PABST_TMP_TRANSITION PT 
    ON PT.pabst_peptide_ion_id = PI.pabst_peptide_ion_id 
    
    JOIN $TBAT_PABST_TMP_TRANSITION_INSTANCE PTI 
    ON PT.pabst_transition_id = PTI.pabst_transition_id 
    
    JOIN $TBAT_INSTRUMENT_TYPE IT 
    ON ( IT.instrument_type_id = PTI.source_instrument_type_id  AND
         IT.instrument_type_id = PII.source_instrument_type_id ) 
    
    JOIN $TBAT_PABST_TMP_SOURCE_PRIORITY PSP 
    ON ( PSP.source_instrument_type_id = PTI.source_instrument_type_id )
    
    WHERE  PP.pabst_build_id IN ( $args{build_id} )
    AND PP.pabst_peptide_id = PABST_PEPTIDE_ID 
    ORDER BY 
    PTI.is_predicted ASC,
    synthesis_adjusted_score DESC,
    PI.modified_peptide_sequence,
    instrument_type_name DESC,
    PII.max_precursor_intensity DESC,
    PII.n_observations DESC,
    relative_intensity DESC,
    ion_rank ASC
    ~;

  print "\n";

  while ( my @peprow = $sth->fetchrow_array() ) {

    $pep_id = $peprow[2];
    if ( $args->{id} ) {
      next if $peprow[2] <= $args->{id};
    }
    print "minimum id is $pep_id " . time() . "\n" unless $cnt;
   
    my $local_sql = $sql;
    $local_sql =~ s/PABST_PEPTIDE_ID/$peprow[2]/;

  #  print STDERR "\tpreparing SQL " . time() . "\n" if $args->{verbose};
    my $sth = $sbeams->get_statement_handle( $local_sql );
    print STDERR "\tprinting " . time() . "\n" if $args->{verbose};
    my $row_cnt = 0;
    while ( my @row = $sth->fetchrow_array() ) {
      $row_cnt++;
      unshift( @row, $peprow[0] );
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
    $cnt++;
    print "$cnt ) $peprow[0] and $peprow[2] has $row_cnt\n";
#    print ".";
#    print STDERR "Done: " . time() . "\n" unless $cnt % 20;

    last if $cnt >= 100;
  } # End peptide_id loop
  print "maximum id is $pep_id at " . time() . "\n";
  
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
  unless( GetOptions ( \%args, 'build_id=i@', 'verbose', 'force', 'yonly', 'noneutralloss', 'id=i', 'max_transitions' ) ) {
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
