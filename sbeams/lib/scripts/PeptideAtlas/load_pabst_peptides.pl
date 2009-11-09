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


my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;

print "process args\n";
my $args = process_args();
print "done\n";

# Flag for uber-verbose logging.
my $paranoid = 0;

{ # Main 

  # Fetch the various datasets to merge
  my $patr = {};
  
  print "read qqq\n";
  my $qqq = readSpectrastSRMFile( 'qqq' );
  print "done\n";
  
  print "read qtof\n";
  my $qtof = readSpectrastSRMFile( 'qtof' );
  print "done\n";
  
  print "read ion_trap\n";
  my $it = readSpectrastSRMFile( 'ion_trap' );
  print "done\n";
  
  
  #print "read theoretical\n";
  #my $theo = readTIQAMSRMFile( $args->{theoretical} );
  ## Flag for uber-verbose logging.
  #print "done\n";
  
  my $name2id = getBioseqInfo( $args->{biosequence_set_id} );
  
  open PEP, $args->{peptides} || die "Unable to open peptide file $args->{peptides}";
  
  my $transition_limit = 10;
  
  my $cnt;
  my %stats;
  my $build_id;


  my $seq2id = getPABSTPeptideData();
  
  # Will populate as needed.
  my $theoretical;
  
  print "reading peptide file\n";
  while ( my $line = <PEP> ) {
    next unless $cnt++;
    chomp $line;
    my @line = split( "\t", $line, -1 );
  #  for my $l ( @line ) { print "$l\n"; }
  
    # Looks like we have a build to load - insert build record
    if ( !$build_id ) {
      my $rowdata = {  build_name => $args->{name},
                    build_comment => $args->{description},
                    ion_trap_file => $args->{ion_trap},
                         qqq_file => $args->{qqq},
                      organism_id => $args->{organism},
                 theoretical_file => '',
                 parameter_string => $args->{parameters},
                   parameter_file => $args->{conf}, 
                       project_id => $args->{project_id} 
                    };
  
      $build_id = $sbeams->updateOrInsertRow( insert => 1,
                                         table_name  => $TBAT_PABST_BUILD,
                                         rowdata_ref => $rowdata,
                                         verbose     => $args->{verbose},
                                        return_PK    => 1,
                                                  PK => 'pabst_build_id',
                                         testonly    => $args->{testonly} );
    }
  
    my $pep_key = $line[1] . $line[2] . $line[3];
  
    # Only insert if we need to?
    if ( !$seq2id->{$pep_key} ) {
  
      $stats{insert_new_yes}++;

      # Fill up transition list for this peptide entry
      my @trans;
      print "INIT: Trans has " . scalar( @trans ) . "\n" if $paranoid;
      my $pep = $line[2];
      $pep =~ s/\'//g;
      if ( $pep =~ /X/ ) {
        $stats{bad_aa}++;
        next;
      }
    
      populate( $qqq, $pep, \@trans, 'spectrast' );
      $stats{qqq_look}++;
      print "Trans has " . scalar( @trans ) . " post QQQ\n" if $paranoid; # if scalar( @trans ) ;
    
      if ( scalar( @trans ) < $transition_limit ) {
        populate( $qtof, $pep, \@trans, 'spectrast' );
        $stats{qtrap_look}++;
        print "Trans has " . scalar( @trans ) . " post Qtrap\n" if $paranoid; # if scalar( @trans );
      }
    
      if ( scalar( @trans ) < $transition_limit ) {
        populate( $it, $pep, \@trans, 'spectrast' );
        $stats{it_look}++;
        print "Trans has " . scalar( @trans ) . " post IT\n" if $paranoid; # if scalar( @trans );
      }
    
      if ( scalar( @trans ) < $transition_limit ) {
        if ( !$theoretical->{$pep} ) {
          # Reset...
          $theoretical = {};
          $theoretical->{$pep} = generate_theoretical( $pep );
        }
        populate_theoretical( $pep, $theoretical->{$pep}, \@trans );
        $stats{theo_look}++;
        print "Trans has " . scalar( @trans ) . " post THEO\n" if $paranoid; # if scalar( @trans );
      }
    
      
      if ( !scalar( @trans ) ) {
        $stats{unfound}++;
    #    print "peptide $pep not found ( $line[1], $line[3], $line[14] )\n";
      } elsif ( scalar( @trans ) < $transition_limit ) {
        $stats{shorted}++;
      } else {
        $stats{fulfilled}++;
      }
    
      if ( $qqq->{$pep} ) {
        $stats{qqq_yes}++;
      } else {
        $stats{qqq_no}++;
      }
      if ( $it->{$pep} ) {
        $stats{ion_trap_yes}++;
      } else {
        $stats{ion_trap_no}++;
      }
      if ( $theoretical->{$pep} ) {
        $stats{theoretical_yes}++;
      } else {
        $stats{theoretical_no}++;
      }
    
      # Insert peptide record
      # Fields in the PABST peptides file
    # 00 biosequence_name
    # 01 preceding_residue
    # 02 peptide_sequence
    # 03 following_residue
    # 04 empirical_proteotypic_score
    # 05 suitability_score
    # 06 predicted_suitability_score
    # 07 merged_score
    # 08 molecular_weight
    # 09 SSRCalc_relative_hydrophobicity
    # 10 n_protein_mappings
    # 11 n_genome_locations
    # 12 est_probability
    # 13 n_observations
    # 14 annotations
    # 15 atlas_build
    # 16 synthesis_score
    # 17 syntheis_adjusted_score
    
      # A little massaging?
      my $suit = ( $line[5] && $line[5] !~ /n/ ) ? $line[5] : $line[6];
      $line[13] = 0 unless $line[13] =~ /^\d+$/;
    
      for my $col ( 12, 4, 5, 15, 6 ) {
        $line[$col] = undef if ( $line[$col] =~ /^n/ );
      }
      for my $col ( 12, 9 ) {
        $line[$col] =~ s/\s//g if ( $line[$col] ); 
      }
    
      my $peprow = {  pabst_build_id => $build_id,
                      preceding_residue => $line[1],
                      peptide_sequence => $line[2],
                      following_residue => $line[3],
                      empirical_proteotypic_score => $line[4],
                      suitability_score => $line[5],
                      predicted_suitability_score => $line[6],
                      merged_score => $line[7],
                      molecular_weight => $line[8],
                      SSRCalc_relative_hydrophobicity => $line[9],
                      n_protein_mappings => $line[10],
                      n_genome_locations => $line[11],
                      best_probability => $line[12],
                      n_observations => $line[13],
                      synthesis_score => $line[16],
                      synthesis_warnings => $line[14],
                      syntheis_adjusted_score => $line[17],
                      source_build => $line[15] 
      };
    
    #  for my $k ( keys( %$peprow ) ) { print "$k => $peprow->{$k}\n"; }
    
    
      my $pep_id = $sbeams->updateOrInsertRow( insert => 1,
                                          table_name  => $TBAT_PABST_PEPTIDE,
                                          rowdata_ref => $peprow,
                                          verbose     => $args->{verbose},
                                         return_PK    => 1,
                                                   PK => 'pabst_peptide_id',
                                          testonly    => $args->{testonly} );
    
      # Cache this to avoid double insert.
      $seq2id->{$pep_key} = $pep_id;
    
    
    
    # 0 pep seq
    # 1 pep seq
    # 2 q1_mz
    # 3 q1_charge
    # 4 q3_mz
    # 5 q3_charge
    # 6 ion_series
    # 7 ion_number
    # 8 CE
    # 9 relative intensity
    # 10 lib_type
    #
    #
      my $tcnt = 1;
      for my $t ( @trans ) {
        my $tranrow = { pabst_peptide_id => $seq2id->{$pep_key},
                        transition_source => $t->[10],
                        precursor_ion_mass => $t->[2],
                        precursor_ion_charge => $t->[3],
                        fragment_ion_mass => $t->[4],
                        fragment_ion_charge => $t->[5],
                        fragment_ion_label => $t->[6] . $t->[7],
                        ion_rank => $tcnt++,
                        relative_intensity => $t->[9],
        };
    #    print "Tranrow is $tranrow\n"; for my $k ( keys ( %$tranrow ) ) { print "$k => $tranrow->{$k}\n"; } 
    
    
      my $trans_id = $sbeams->updateOrInsertRow( insert => 1,
                                            table_name  => $TBAT_PABST_TRANSITION,
                                            rowdata_ref => $tranrow,
                                            verbose     => $args->{verbose},
                                           return_PK    => 1,
                                                     PK => 'fragment_ion_id',
                                            testonly    => $args->{testonly} );
    
      }
    
    } else {
      $stats{insert_new_no}++;
    }
    
    my $maprow = {  pabst_peptide_id => $seq2id->{$pep_key},
                    biosequence_id => $name2id->{$line[0]} };
  
    my $map_id = $sbeams->updateOrInsertRow( insert => 1,
                                        table_name  => $TBAT_PABST_PEPTIDE_MAPPING,
                                        rowdata_ref => $maprow,
                                        verbose     => $args->{verbose},
                                       return_PK    => 1,
                                                 PK => 'pabst_peptide_id',
                                        testonly    => $args->{testonly} );
  

  } # End read peptide loop

  print "Saw $cnt total peptides\n";
  for my $s ( sort( keys( %stats ) ) ) {
    print "$s => $stats{$s}\n";
  }

} # End Main

sub getPABSTPeptideData {
  my $sql = qq~
  SELECT preceding_residue || peptide_sequence || following_residue, 
         pabst_peptide_id
    FROM $TBAT_PABST_PEPTIDE
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );

  my %seq_to_id;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $seq_to_id{$row->[0]} = $row->[1];
  }
  return \%seq_to_id;
}

sub populate {
  my $trans_lib = shift;
  my $pep = shift;
  my $global_trans = shift;
  my $type = shift;
  my $limit = shift || 10;

  print "Trans is $global_trans\n" if $paranoid;

  return unless $trans_lib->{$pep};
  print "Found peptide $pep in $type\n" if $paranoid;

  for my $chg ( 2, 3, 1 ) {
    if ( $trans_lib->{$pep}->{$chg} ) {
      print "looks like we have $pep with charge $chg in $type - " . scalar(  @{$trans_lib->{$pep}->{$chg}}   ) . "\n" if $paranoid;
      my @trans;
      if ( $type eq 'spectrast' ) {
        my $cnt = 1;
#        for my $i (  @{$trans_lib->{$pep}->{$chg}} ) { print "$cnt > $i\n" if $paranoid; $cnt++; }
        @trans = sort { $a->[9] <=> $b->[9] } @{$trans_lib->{$pep}->{$chg}};

        print "In the iffy, trans has " . scalar( @trans ) . " but tlib has " . scalar( @{$trans_lib->{$pep}->{$chg}} )  . "\n" if $paranoid;
      } else {
        print "In the elsy\n" if $paranoid;
        @trans = @{$trans_lib->{$pep}->{$chg}}
      }
      for my $t ( @trans ) {
        print "$t\n" if $paranoid;
#        for my $e ( @$t ) { print "$e\t" if $paranoid; }
        unshift @{$global_trans}, $t;
        last if scalar( @{$global_trans} >= $limit );
      }
    }
    last if scalar( @{$global_trans} >= $limit );
  }
#  print "\nTrans has " . scalar( @$global_trans ) . " transitions!\n" if $paranoid;
#  exit if $paranoid;
}

sub populate_theoretical {
  my $pep = shift;
  my $lib = shift;
  my $global_trans = shift;
  my $limit = shift || 10;

  for my $trans ( @{$lib} ) {
    push @{$global_trans}, $trans;
    last if scalar( @{$global_trans} ) >= $limit;
  }
}

sub generate_theoretical {
  my $pep = shift;

  my $frags = $pep_sel->generate_fragment_ions( peptide_seq => $pep,
                                                     max_mz => 2500,
                                                     min_mz => 400,
                                                       type => 'P',
                                             precursor_excl => 5 
                                          );
  return $pep_sel->order_fragments( $frags );
}

sub process_args {

  my %args;
  GetOptions( \%args, 'qqq:s', 'ion_trap:s', 'qtof:s', 'help',
              'peptides:s', 'conf=s', 'parameters=s', 'description=s',
              'verbose', 'testonly', 'biosequence_set_id=i', 'name=s',
              'load', 'output_file=s', 'project_id=i', 'organism=i' );

  my $missing;
  for my $opt ( qw( qqq ion_trap qtof peptides conf parameters 
                    biosequence_set_id project_id ) ) {
    $missing = ( $missing ) ? $missing . ", $opt" : "Missing required arg(s) $opt" if !$args{$opt};
  }


  if ( !$args{load} && !$args{output_file} ) {
    $missing .= "\n" . "      Must provide either --load for loading_mode or --output_file for generate mode";
  }

  if ( $args{conf} ) {
    undef local $/;
    open CONF, $args{conf} || die "unable to open config file $args{conf}";
    $args{conf} = <CONF>;
  }

  print_usage( $missing ) if $missing;
  return \%args;
}

sub readSpectrastSRMFile {
  my $lib_type = shift || die;

  my %type = ( qtof => 'T',
               qqq => 'Q',
               ion_trap => 'I' );
               

  my $srm_file = $args->{$lib_type};

  open SRM, $srm_file || die "Unable to open SRM file $srm_file";

  my %srm;
  while ( my $line = <SRM> ) {
    chomp $line;
    my @line = split( /\t/, $line, -1 );

    my ( $seq, $chg ) = split( "/", $line[9], -1 );

    my @labels = split( "/", $line[7], -1 );
    my $primary_label = $labels[0];

    next if $primary_label =~ /^p/;
    next if $primary_label =~ /^\?/;
    next if $primary_label =~ /^IWA/;

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
#    print "q3 series is $q3_series\n" if $show;
#    print "q3 peak is $q3_peak\n" if $show;

    $srm{$line[1]} ||= {};
    $srm{$line[1]}->{$line[2]} ||= [];
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
    push @{$srm{$seq}->{$chg}}, [ $seq, $seq, $line[3], $chg, @line[5], $q3_chg, $q3_series, $q3_peak, $line[10], $line[6], $type{$lib_type} ];
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
sub readTIQAMSRMFile {
  die unless $args->{theoretical};
  open THEO, $args->{theoretical} || die "Unable to open Theoretical peptide file $args->{theoretical}";
  my %srm;
  my $cnt;
  while ( my $line = <THEO> ) {
    $cnt++;

    print '*' unless $cnt % 5000;
    print "\n" unless $cnt % 100000;

    chomp $line;
    my @line = split( ',', $line, -1 );
    $srm{$line[1]} ||= {};
    $srm{$line[1]}->{$line[2]} ||= [];

    # Only cache 8 transitions per peptide, memory footprint
    next if scalar( @{$srm{$line[1]}->{$line[2]}} ) >= 8;

    # srm{peptide_sequence}->{charge} == pep seq, pep seq, q1 mz, q1 charge, q3 mz, q3 charge, ion series, ion number, CE, intensity
    push @{$srm{$line[1]}->{$line[2]}}, [ @line[1,1,3,2,5], 1, @line[6,7,9], '', 'T' ];
  }
  return \%srm;

# 00 Protein name YJL026W
# 01 Peptide sequence AAADALSDLEIK
# 02 Charge 2
# 03 Q1 m/z 608.8251475
# 04 ??? 1
# 05 Q3 m/z 704.38303
# 06 Ion series y
# 07 Series number 6
# 08 ??? 30
# 09 CE 32.28830649
# 10 ??> 1
# 11 ??? 2859
# 12 ??? 1215.634645
# "$protein,$pepSeq,$charge,$precursor,1,$fragmass,y,", $i + 1, ",$dwelltime,$CE,$modification,$bad,$unique,$nrProt,$mass\n"
}

sub print_usage {
  my $msg = shift || '';
  my $exe = basename( $0 );
  print <<"  END";
      $msg

usage: $exe -q qtrap_file -i ion_trap_file -t theoretical_file

   -i, --ion_trap     Ion Trap consensus library location 
   -q, --qqq          QQQ consensus library location
       --peptides     List of 'best' peptides
   -t, --theoretical  Theoretical transition information in TIQAM format 
   -h, --help         print this usage and exit
   -c, --conf         PABST config file used for build
       --parameters   parameter string for best peptide run
   -n, --name         Name for pabst_build 
   -o, --organism     Organism for pabst_build  
   -d, --description  description of pabst_build
  END

  exit;
}

sub getBioseqInfo {

  my $bioseq_set_id = shift || return {};
  
  my $sql = qq~
  SELECT biosequence_id, biosequence_name
  FROM $TBAT_BIOSEQUENCE
  WHERE biosequence_set_id = $bioseq_set_id
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my %name2id;
  while( my @row = $sth->fetchrow_array() ) {
    $name2id{$row[1]} = $row[0];
  }
  return \%name2id;
}

__DATA__




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
syntheis_adjusted_score  FLOAT,
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
syntheis_adjusted_score

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
syntheis_adjusted_score  FLOAT
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

