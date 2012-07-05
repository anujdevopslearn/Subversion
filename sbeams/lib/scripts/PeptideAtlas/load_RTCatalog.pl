#!/usr/local/bin/perl 
use strict;
use DBI;
use Getopt::Long;
use File::Basename;
use Cwd qw( abs_path );
use FindBin;
use Data::Dumper;
use FileHandle;

use lib "$FindBin::Bin/../../perl";
use lib '/net/db/projects/spectraComparison';

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas;


$|++; # don't buffer output

my $sbeams = SBEAMS::Connection->new();
$sbeams->Authenticate();

my $atlas = SBEAMS::PeptideAtlas->new();
$atlas->setSBEAMS( $sbeams );

my $args = process_args();

my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;

# TODO
# implement delete
# code to check supplied elution_time_type_id
# code to print list of available elution_time_type_id
# supress insert if other records with same type exist?
#

{ # Main 

  if ( $args->{delete} ) {
    print "Not yet implemented, alas!\n";
    exit;
  }

  if ( $args->{load} ) {

    open CAT, $args->{catalog_file} || die "unable to open cat file $args->{catalog_file}";
    my $cnt = 0;
    while ( my $line = <CAT> ) {
      chomp $line;
      my @line = split( "\t", $line, -1 );
      next if $line[0] =~ /Peptide/i;
      my $clean_seq = $line[0];
      $clean_seq =~ s/\[\d+\]//g;
      $cnt++;

      my $rowdata = { peptide_sequence => $clean_seq,
                      modified_peptide_sequence => $line[0],
                      elution_time => $line[1]/60,
                      SIQR => $line[2],
                      elution_time_type_id => $args->{elution_time_type_id},
                      elution_time_set => '' };

      my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      table_name  => 'peptideatlas.dbo.elution_time',
                                      rowdata_ref => $rowdata,
                                      verbose     => $args->{verbose},
                                     return_PK    => 1,
                                               PK => 'elution_time_id',
                                      testonly    => $args->{testonly} );
      print STDERR '*' unless $cnt % 500;
      print STDERR "\n" unless $cnt % 12500;
    }

    close CAT;
    print STDERR "loaded $cnt total rows\n";
  }

} # End Main


sub process_args {

  my %args;
  GetOptions( \%args, 'load', 'delete', 'catalog_file=s', 'elution_time_type_id:i' );

  print_usage() if $args{help};

  my $missing = '';
  for my $opt ( qw( elution_time_type_id ) ) {
    $missing = ( $missing ) ? $missing . ", $opt" : "Missing required arg(s) $opt" if !$args{$opt};
  }
  print_usage( $missing ) if $missing;

  unless ( $args{load} || $args{'delete'} ) {
    print_usage( "Must specify at least one of load and delete" );
  }

  if ( $args{load} && !$args{catalog_file} ) {
    print_usage( "Must catalog file in load mode" );
  }

  return \%args;
}


sub print_usage {
  my $msg = shift || '';
  my $exe = basename( $0 );

  print <<"  END";
      $msg

usage: $exe --elut elution_time_type_id [ --load --cat catalog_file --dele ] 

   -d, --delete         Delete records with defined elution_time_type_id
   -h, --help           print this usage and exit
   -l, --load           Load RT Catalog 
   -c, --catalog_file   File with RT Catalog data (we will load peptide sequence and RT mean
  END

  exit;

}

__DATA__

sub getPABSTPeptideData {

  my %seq_to_id;

  my $build_where = '';
  if ( $args->{mapping_build} ) {
    $build_where = "WHERE pabst_build_id = $args->{mapping_build}";
  }

  # Now require explicit mapping build, else return empty hashref
  return \%seq_to_id unless $build_where;

  die "Is this properly implemented? $build_where";

  my $sql = qq~
  SELECT preceding_residue || peptide_sequence || following_residue, 
         pabst_peptide_id
    FROM $TBAT_PABST_PEPTIDE
    $build_where
  ~;
  print "Mapping to existing build $args->{mapping_build}\n";

  my $sth = $sbeams->get_statement_handle( $sql );

  my $cnt = 0;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $cnt++;
    $seq_to_id{$row->[0]} = $row->[1];
  }
  print STDERR "saw $cnt total peptides\n";

  return \%seq_to_id;
}


sub process_args {

  my %args;
  GetOptions( \%args, 'catalog_file=s', 'elution_time_type_id:i' );

  print_usage() if $args{help};

  if ( !$args{load} && !$args{output_file} && !$args{delete} ) {
    $missing .= "\n" . "      Must provide either --load, --delete, or  --output_file mode";
  }

  if ( $args{delete} && ( !$args{build_id} && !$args{show_builds} ) ) {
    $missing .= "\n" . "      Must provide --build_id with --delete option";
  }

  if ( $args{load} || $args{output_file} ) {
    for my $opt ( qw( mrm_file peptides conf parameters biosequence_set_id project_id name description ) ) {
      $missing = ( $missing ) ? $missing . ", $opt" : "Missing required arg(s) $opt" if !$args{$opt};
    }
  }
  print_usage( $missing ) if $missing;

  if ( $args{conf} ) {
    undef local $/;
    open CONF, $args{conf} || die "unable to open config file $args{conf}";
    $args{conf_file} = <CONF>;
  }

  for my $consensus ( @{$args{mrm_file}} ) {
    my @lib_attr = split "\:", $consensus;
    print_usage ( "MRM lib files must specify instrument" ) unless scalar( @lib_attr ) > 1;
    print_usage ( "MRM lib files cannot contain : characters" ) if scalar( @lib_attr ) > 2;
    print_usage ( "unknown lib type $lib_attr[1]" ) unless $instrument_map->{$lib_attr[1]};
    push @mrm_libs, $lib_attr[0];
    $mrm_libs{$lib_attr[0]} = $instrument_map->{$lib_attr[1]};
  }

  for my $pathfile ( @{$args{run_path_file}} ) {
    my @lib_attr = split "\:", $pathfile;
    print_usage ( "MRM lib files must specify instrument" ) unless scalar( @lib_attr ) > 1;
    print_usage ( "MRM lib files cannot contain : characters" ) if scalar( @lib_attr ) > 2;
    print_usage ( "unknown lib type $lib_attr[1]" ) unless $instrument_map->{$lib_attr[1]};
    push @src_paths, $lib_attr[0];
    $src_paths{$lib_attr[0]} = $instrument_map->{$lib_attr[1]};
  }

  return \%args;
}


sub readSpectrastSRMFile {

  my %args = @_;

  print "Library file is $args{file}, type is $args{type}, lib is $args{lib}\n" if $args->{verbose};

  if ( ! -e $args{file} ) {
    die "File $args{file} does not exist";
  }
  open SRM, $args{file} || die "Unable to open SRM file $args{file}";

  my %srm = %{$args{lib}};

  while ( my $line = <SRM> ) {
    chomp $line;
    my @line = split( /\t/, $line, -1 );

    my ( $seq, $chg ) = split( "/", $line[9], -1 );

    $srm{$seq} ||= {};
    $srm{$seq}->{$chg} ||= [];
#    print "$seq and $chg has " . scalar( @{$srm{$seq}->{$chg}} ) . " \n";
    next if scalar( @{$srm{$seq}->{$chg}} ) > $transition_limit;
#    next if $all_mrm_peaks{$srm{$seq}->{$chg}} > $mrm_peak_limit;

    my @labels = split( "/", $line[7], -1 );
    my $primary_label = $labels[0];

#    next if $primary_label !~ /^[yb]/;

    # Exclude isotope ions
    next if $primary_label !~ /[yb]\d+/;
    next if $primary_label =~ /[yb]\d+i/;
    next if $primary_label =~ /^p/;
    next if $primary_label =~ /^\?/;
    next if $primary_label =~ /^I/;

#    my $show = 0;

    my ( $q3_peak, $q3_chg, $q3_delta, $q3_series );
    if ( $primary_label =~ /\^(\d+)/ ) {
      # charge other than 1
      $q3_chg = $1;
#      print "q3 charge is $q3_chg from $primary_label\n" if $show;
      # Trim the charge
      $primary_label =~ s/\^\d+//;
    } else {
      $q3_chg = 1;
    }
#    print "q3 charge is $q3_chg\n" if $show;

    if ( $primary_label =~ /(\w\d+)([+-]\d+)/ ) {
#      $show++;
#      print "from $labels[0]\n";
      $q3_delta = $2;
      $primary_label = $1;
    } else {
      $q3_delta = '';
    }
#    print "q3 delta is $q3_delta, q3 chg is $q3_chg\n" if $show;

    if ( $primary_label =~ /(\w)(\d+)/ ) {
      $q3_series = $1;
      $q3_peak = $2;
    } else {
      next;
      die ( "does not compute!!! - $labels[0]" );
    }
    my $show = 1;
#    print "q3 series is $q3_series\n" if $show;
#    print "q3 peak is $q3_peak\n" if $show;

    # Skip delta masses?
    if ( $q3_delta ) {
      $q3_peak .= $q3_delta;
    }
#    print "q3 delta is $q3_delta\n" if $show;
#    print "q3 peak is now $q3_peak\n" if $show;
#    exit;

# Reads in specified file, returns ordered MRM list with fields as follows.
# peptide sequence
# modified_peptide_sequence
# q1_mz
# q1_charge
# q3_mz
# q3_charge
# ion_series
# ion_number
# CE
# Relative intensity 
# Type 
    # srm{peptide_sequence}->{charge} == pep seq, pep seq, q1 mz, q1 charge, q3 mz, q3 charge, ion series, ion number, CE, intensity, lib_type
#
    my @reps = split( "/", $line[1] );

    push @{$srm{$seq}->{$chg}}, [ $seq, $seq, $line[3], $chg, @line[5], $q3_chg, $q3_series, $q3_peak, $line[10], $line[6], $args{type}, $reps[1] ];
#    $all_mrm_peaks{$srm{$seq}->{$chg}}++;

#    print "For $seq and $chg, pushed $line[6], top is $srm{$seq}->{$chg}->[0]->[9]\n" unless $lib_type =~ /ion_trap/;
#    push @{$srm{$line[1]}->{$line[2]}}, [ ];
#    print "pushed $seq, srM has " . scalar(@{$srm{$seq}->{$chg}}) . "\n" if $paranoid;
  }
  return \%srm;

# 00 Protein name YJL026W
# 01 reps in best run /total reps    0/0
# 02 pI   4.03
# 03 Q1 m/z   608.8246
# 04 RT   0.00
# 05 Q3 m/z   704.38
# 06 Rel Intensity  10000
# 07 peak label   y6/0.02
# 08 Q1 charge  2
# 09 peptide ion   AAADALSDLEIK/2
# 10 Collision Enery (theo)   32.29
# 11 mapped proteins   1
# 12 protein(s)  YJL026W
}


sub readIntensityFile {

  my %args = @_;

  print "Intensity file is $args{file}, type is $args{type}, lib is $args{lib}\n";

  if ( ! -e $args{file} ) {
    die "File $args{file} does not exist";
  }

  open INTEN, $args{file} || die "Unable to open intensity file $args{file}";

  # Might have passed in more than one library of a given type, use first available.
  my %inten = %{$args{lib}};

  while ( my $line = <INTEN> ) {
    chomp $line;
 
    # Intensity file format is peptide_ion, intensity, n_obs
    my @line = split( /\t/, $line, -1 );

    # Split into sequence/charge?  
    my @pepion = $line[0] =~ /^(\w+)(\d)$/;

    $inten{$line[0]} = $line[1];
  }
  print STDERR "Found " . scalar( keys( %inten ) ) . " values for $args{file}\n";

  return \%inten;
}


sub print_usage {
  my $msg = shift || '';
  my $exe = basename( $0 );

  my $instrument_str = join( ', ', sort( grep( !/PATR|Predicted/, keys( %{$instrument_map} ) ) ) );
  

#  GetOptions( \%args, 'mrm_file=s@', 'help',
#              'peptides:s', 'conf=s', 'parameters=s', 'description=s',
#              'verbose', 'testonly', 'biosequence_set_id=i', 'name=s',
#              'load', 'output_file=s', 'project_id=i', 'organism=i',
#              'mapping_build:i', 'delete', 'build_id=i', 'specified_only' );
  print <<"  END";
      $msg

usage: $exe --mrm qtrap_file:QTrap5500 [ --mrm ion_trap_file:IonTrap ... ] --pep peptide_file --load -c conf_file --param params -o 2 -n build_name

   -b, --build_id       PABST build ID, required with --delete mode
       --delete         Delete specified build
   -c, --conf           PABST config file used for build
       --description    Description of pabst_build
   -h, --help           print this usage and exit
   -i, --ion_trap       Ion Trap consensus library location 
   -l, --load           Load pabst build
       --mapping_build  existing PABST build id to use for mapping, default 0
                        which will insert all de-novo.
   -n, --name           Name for pabst_build 
   -o, --organism       Organism for pabst_build  
       --peptides       List of 'best' peptides
       --project_id     Project with which build is associated
       --parameters     parameter string for best peptide run
       --mrm            MRM file(s) to load, must also specify type, e.g. --mrm qtof_file:QTOF 
                        permitted values: $instrument_str
   -t, --testonly       Run delete in testonly mode
       --show_builds    List builds in database 
       --specified_only Only load peptides for which transitions were found in
                        one of the speclibs (supress theoretical)
  END

  exit;
}

sub getOrganismID {
  my $bioseq_set_id = shift || return {};
# FIXME - replace with $TBAT
#  FROM $TBAT_BIOSEQUENCE
#
  my $sql = qq~
  SELECT organism_id 
  FROM peptideatlas.dbo.biosequence_set
  WHERE biosequence_set_id = $bioseq_set_id
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  while( my @row = $sth->fetchrow_array() ) {
    return $row[0];
  }
  return 0;
}

sub getBioseqInfo {

  my $bioseq_set_id = shift || return {};
  
# FIXME - replace with $TBAT
#  FROM $TBAT_BIOSEQUENCE
#
  my $sql = qq~
  SELECT biosequence_id, biosequence_name
  FROM peptideatlas.dbo.biosequence
  WHERE biosequence_set_id = $bioseq_set_id
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my %name2id;
  while( my @row = $sth->fetchrow_array() ) {
    $name2id{$row[1]} = $row[0];
  }
  return \%name2id;
}


sub getPATRPeptides {

  # fetch peptides
  # fill in any missing info
  # hash results
  # return hashref

    # srm{peptide_sequence}->{charge} == pep seq, pep seq, q1 mz, q1 charge, q3 mz, q3 charge, ion series, ion number, CE, intensity, lib_type

  # DELETEME
  $TBAT_SRM_TRANSITION = 'peptideatlas.dbo.srm_transition';

  my $sql = qq~
  SELECT * FROM ( 
    SELECT stripped_peptide_sequence,
           modified_peptide_sequence,
           q1_mz,
           peptide_charge,
           q3_mz,
           CASE WHEN q3_ion_label LIKE '%^2%' THEN 2
                WHEN q3_ion_label LIKE '%^3%' THEN 3
                ELSE 1 END AS q3_charge,
           q3_ion_label AS series,
           q3_ion_label AS number,
           collision_energy,
           12000 AS intensity,
           'R' AS lib_type,
           CASE WHEN peptide_charge = 2 THEN 1
                WHEN peptide_charge = 3 THEN 2
                ELSE 3 END AS charge_priority,
           transition_suitability_level_id,
           srm_transition_id
  FROM $TBAT_SRM_TRANSITION
  WHERE record_status = 'N' ) AS subquery
  ORDER BY stripped_peptide_sequence, transition_suitability_level_id,
           charge_priority ASC, peptide_charge ASC, srm_transition_id ASC, 
           q3_mz
  ~;
# Should also sort by intensity!!!

  my $sth = $sbeams->get_statement_handle( $sql );

  # split series and number
  # drop charge priority

  my %patr;
  my $cnt = 0;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $cnt++;
    $patr{$row->[1]} ||= {};
    $patr{$row->[1]}->{$row->[3]} ||= [];

    my @mod_row = @{$row}[0..10];
    $row->[6] =~ /^(\w)(\d+)/;
    my $series = $1;
    my $number = $2;
    next unless $series && $number && $series =~ /[yb]/i;
#    print "Series is $series and number is $number and q3 charge is $mod_row[5] for $mod_row[6]\n";
    $mod_row[6] = $series;
    $mod_row[7] = $number;
    $mod_row[2] = sprintf( "%0.3f", $mod_row[2]);
    $mod_row[4] = sprintf( "%0.3f", $mod_row[4]);

    push @{$patr{$row->[1]}->{$row->[3]}}, \@mod_row;
#    last if $cnt > 100;
  }
  print STDERR "saw $cnt total peptides\n";
  return \%patr;

#  exit;
}



__DATA__

srm_transition_id
srm_transition_set_id
stripped_peptide_sequence
modified_peptide_sequence
monoisotopic_peptide_mass
peptide_charge
q1_mz
q3_mz
q3_ion_label
transition_suitability_level_id
collision_energy
retention_time
protein_name
comment
date_created
created_by_id
date_modified
modified_by_id
owner_group_id
record_status    
 


CREATE TABLE peptideatlas_test.dbo.pabst_build (
pabst_build_id  INTEGER IDENTITY,
build_name VARCHAR(255),
build_comment VARCHAR(2000),
ion_trap_file VARCHAR(255),
qtof_file VARCHAR(255),
qqq_file VARCHAR(255),
theoretical_file VARCHAR(255),
parameter_string VARCHAR(255),
organism_id, INT
parameter_file  TEXT,
project_id INT,
build_date DATETIME,
biosequence_set_id, INT
);



CREATE TABLE peptideatlas_test.dbo.pabst_peptide_mapping (
biosequence_id   INTEGER,
pabst_peptide_id INTEGER IDENTITY,
);

CREATE TABLE peptideatlas_test.dbo.pabst_peptide (
pabst_peptide_id INTEGER IDENTITY,
pabst_build_id  INTEGER,
preceding_residue  CHAR(1),
peptide_sequence   VARCHAR(255),
following_residue  CHAR(1),
molecular_weight  FLOAT,
n_protein_mappings INTEGER,
n_genome_locations  INTEGER,
SSRCalc_relative_hydrophobicity FLOAT,
best_probability  FLOAT,
n_observations   INTEGER,
source_build   INTEGER,
empirical_proteotypic_score FLOAT,
suitability_score   FLOAT,
merged_score     FLOAT,
synthesis_score   FLOAT,
synthesis_warnings  VARCHAR(255),
synthesis_adjusted_score  FLOAT,
);

GO
CREATE TABLE peptideatlas_test.dbo.pabst_transition ( 
fragment_ion_id INTEGER IDENTITY,
pabst_peptide_id INTEGER,
transition_source CHAR(1),
precursor_ion_mass FLOAT, 
precursor_ion_charge INTEGER, 
fragment_ion_mass FLOAT, 
fragment_ion_charge INTEGER, 
fragment_ion_label VARCHAR(36),
ion_rank INTEGER,
relative_intensity FLOAT
)

# Fields in the PABST peptides file
biosequence_name
preceding_residue
peptide_sequence
following_residue
empirical_proteotypic_score
suitability_score
redicted_suitability_score
merged_score
molecular_weight
SSRCalc_relative_hydrophobicity
n_protein_mappings
n_genome_locations
est_probability
n_observations
annotations
atlas_build
synthesis_score
synthesis_adjusted_score

fragment_ion_id
best_peptide_id
transition_source
precursor_ion_mass
precursor_ion_charge
fragment_ion_mass
fragment_ion_charge
fragment_ion_label
ion_rank    
relative_intensity








CREATE TABLE pabst_peptide (
best_peptide_id INTEGER, IDENTITY
biosequence_id   INTEGER,
preceding_residue  CHAR(1),
peptide_sequence   VARCHAR(255),
following_residue  CHAR(1),
empirical_proteotypic_score FLOAT,
suitability_score   FLOAT,
merged_score     FLOAT,
molecular_weight  FLOAT,
SSRCalc_relative_hydrophobicity FLOAT,
n_protein_mappings INTEGER,
n_genome_locations  INTEGER,
best_probability  FLOAT,
n_observations   INTEGER,
synthesis_score   FLOAT,
synthesis_warnings  VARCHAR,
synthesis_adjusted_score  FLOAT
parameter_set_id  INTEGER );

GO
CREATE TABLE pabst_transitions ( 
fragment_ion_id INTEGER IDENTITY,
best_peptide_id INTEGER,
transition_source_id INTEGER,
precursor_ion_mass FLOAT 
precursor_ion_charge INTEGER 
fragment_ion_mass FLOAT 
fragment_ion_charge INTEGER 
fragment_ion_label VARCHAR(36),
ion_rank INTEGER
)

