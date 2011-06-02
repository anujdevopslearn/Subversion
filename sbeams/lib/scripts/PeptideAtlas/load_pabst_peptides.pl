#!/usr/local/bin/perl 
use strict;
use DBI;
use Getopt::Long;
use File::Basename;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use lib '/net/db/projects/spectraComparison';

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::BestPeptideSelector;
use SBEAMS::PeptideAtlas::Tables;

use FragmentationComparator;
use SBEAMS::Proteomics::PeptideMassCalculator;

$|++; # don't buffer output

my $sbeams = SBEAMS::Connection->new();
$sbeams->Authenticate();

my $atlas = SBEAMS::PeptideAtlas->new();
$atlas->setSBEAMS( $sbeams );

my $pep_sel = SBEAMS::PeptideAtlas::BestPeptideSelector->new();
$pep_sel->setSBEAMS( $sbeams );

my $instrument_map = $pep_sel->getInstrumentMap();
#for my $i ( sort( keys( %{$instrument_map} ) ) ) { print "$i => $instrument_map->{$i}\n"; }

my %instr_type = reverse( %{$instrument_map} );
#for my $i ( sort( keys( %instr_type ) ) ) { print "$i => $instr_type{$i}\n"; }

my $massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator;

# Will be populated in process_args
my @mrm_libs;
my %mrm_libs;

my $args = process_args();

print "Begin at " . time() . "\n" if $args->{verbose};

print "Loading fragment compare\n" if $args->{verbose};

# Load spectrum comparer code
my %fc;
my $fc; #DELETEME
my @trans; #DELETEME
my %model_map = ( QTrap4000 => '/net/db/projects/spectraComparison/FragModel_4000QTRAP.fragmod',
                  QTOF => '/net/db/projects/spectraComparison/FragModel_AgilentQTOF.fragmod', 
                  IonTrap => '/net/db/projects/spectraComparison/FragModel_IonTrap.fragmod', 
                  QTrap5500 => '/net/db/projects/spectraComparison/FragModel_QTRAP5500.fragmod', 
             );

for my $model ( keys( %model_map ) ) {
  print STDERR "loading model for $model\n" if $args->{verbose}; 
  $fc{$model} = new FragmentationComparator;
  $fc{$model}->loadFragmentationModel( filename => $model_map{$model} );
  $fc{$model}->setUseBondInfo(1);
  $fc{$model}->setNormalizationMethod(1);
}

print "done\n" if $args->{verbose};

my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;
my $transition_limit = 10;

# DELETEME
my $mrm_peak_limit = $transition_limit + 10;

#my %all_mrm_peaks;


# Flag for uber-verbose logging.
my $paranoid = 0;
$paranoid++ if $args->{verbose} > 1;

use Data::Dumper;
my %stats;

{ # Main 

  if ( $args->{delete} ) {
    delete_pabst_build();
    exit;
  }

  # Fetch the various datasets to merge
  my $patr = getPATRPeptides();
  
  my %lib_data;
  for my $mrm ( @mrm_libs ) {

    my $time = time();
    print "Reading $mrm file data: $time\n" if $args->{verbose};

    # lib data is hash ref, init here, and pass to reading routine.  If more than one lib
    # is provided for a given data type, will use first instance of a given peptide ion
    my $type = $instr_type{$mrm_libs{$mrm}};

    $lib_data{$type} ||= {};
    $lib_data{$type} = readSpectrastSRMFile( file => $mrm,
                                            type => $type,
                                             lib => \%lib_data );
  }
  
  my $time = time();
  print "Done reading MRM files: $time\n";

  my $name2id = getBioseqInfo( $args->{biosequence_set_id} );
  my $organism_id = getOrganismID( $args->{biosequence_set_id} );
  
  open PEP, $args->{peptides} || die "Unable to open peptide file $args->{peptides}";


  # Looks like we have a build to load - insert build record
  my $build_id;
  if ( $args->{load} ) {
    my $rowdata = {  build_name => $args->{name},
                    build_comment => $args->{description},
                      organism_id => $organism_id,
                 parameter_string => $args->{parameters},
                   parameter_file => $args->{conf}, 
               biosequence_set_id => $args->{biosequence_set_id}, 
                       project_id => $args->{project_id}, 
                       is_default => 'T'
                    };
  
    $build_id = $sbeams->updateOrInsertRow( insert => 1,
                                       table_name  => $TBAT_PABST_BUILD,
                                       rowdata_ref => $rowdata,
                                       verbose     => 0, 
#                                       verbose     => $args->{verbose},
                                      return_PK    => 1,
                                                PK => 'pabst_build_id',
                                       testonly    => $args->{testonly} );
  }
  
  my $cnt;

  if ( $args->{output_file} ) {
#    $build_id = 'output_file';
  }

  my $seq2id = getPABSTPeptideData();
  
  # Will populate as needed.
  my $theoretical;
  
  print "reading peptide file\n";
  if ( $args->{output_file} ) {
    open( OUT, ">$args->{output_file}" );
  }

  # Meat and 'taters
  while ( my $line = <PEP> ) {

    chomp $line;
    my @line = split( "\t", $line, -1 );

    # Often loading a fetch_best_peptides file
    next if $line[0] eq 'biosequence_name';

    # Disregard peptides with odd amino acids 
    unless ( $line[2] =~ /^[ACDEFGHIKLMNOPQRSTVWY]+$/ ) {
      $stats{bad_aa}++;
      next;
    }
    if ( $line[14] =~ /ST|MC/ ) {
      $stats{nontryptic}++;
      next;
    }

    # All Cys residues must be alkylated carboxymethyl...
    if ( $line[2] =~ /C/ ) {
      $line[2] =~ s/C([^\[])/C[160]$1/g;
      $line[2] =~ s/C$/C[160]/; 
    }

    my $pep_key = $line[1] . $line[2] . $line[3];
  
    # Only insert if we need to?
    if ( !$seq2id->{$pep_key} || $args->{output_file} ) {
  
      $stats{insert_new_peptide}++;
    
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
    # 17 synthesis_adjusted_score
    
      # A little massaging?
      my $suit = ( $line[5] && $line[5] !~ /n/ ) ? $line[5] : $line[6];
      $line[13] = 0 unless $line[13] =~ /^\d+$/;
    
      for my $col ( 12, 4, 5, 15, 6 ) {
        $line[$col] = undef if ( $line[$col] =~ /^n/ );
      }
      for my $col ( 12, 9 ) {
        $line[$col] =~ s/\s//g if ( $line[$col] ); 
      }
    
      # Insert peptide record
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
                      annotations => $line[14],
                      synthesis_adjusted_score => $line[17],
                      source_build => $line[15] 
      };
    
      my $pep_id;
      if ( $args->{output_file} ) {
        # Unsure how to implement this... which transitions to print?
      } else {
       $pep_id = $sbeams->updateOrInsertRow(   insert => 1,
                                          table_name  => $TBAT_PABST_PEPTIDE,
                                          rowdata_ref => $peprow,
                                          verbose     => $args->{verbose},
                                          verbose     => 0, 
                                         return_PK    => 1,
                                                   PK => 'pabst_peptide_id',
                                          testonly    => $args->{testonly} );
      }
    
      # Cache this to avoid double insert.
      $seq2id->{$pep_key} = $pep_id;

      # END Insert peptide record

#      for my $instr ( keys( %{$instrument_map} ) ) {
      my %peptide_ions;
      for my $instr ( keys( %lib_data ) ) {
#        print "Checking $instr for $line[2]\n";
        if  ( $lib_data{$instr} ) {
#          print "Found lib data!\n";
          if ( $lib_data{$instr}->{$line[2]} ) {
            for my $chg ( sort { $a <=> $b } ( keys( %{$lib_data{$instr}->{$line[2]}} ) ) ) {

              my $ion_key = $line[2] . $chg;
              if ( !$peptide_ions{$ion_key} ) {
                # Insert peptide ion here...
              }
              print "Found $instr lib data for $line[2] in charge state $chg\n";
              for my $trans ( @{$lib_data{$instr}->{$line[2]}->{$chg}} ) {
                die Dumper( $trans );
              }
            }
          }
        }
      }

      if ( !scalar( keys( %peptide_ions ) ) ) {
        my $ech = calculate_expected_charge( $line[2] );
        if ( $ech > 2 ) {
        } else {
        }
      }
    
    
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
        if ( $args->{output_file} ) {
           print OUT join( "\t", $line[2], values( %$tranrow) ) . "\n" ;


    
        } else {
    
        my $trans_id = $sbeams->updateOrInsertRow( insert => 1,
                                              table_name  => $TBAT_PABST_TRANSITION,
                                              rowdata_ref => $tranrow,
                                              verbose     => $args->{verbose},
                                       verbose     => 0, 
                                             return_PK    => 1,
                                                       PK => 'fragment_ion_id',
                                              testonly    => $args->{testonly} );
    
        }
      }
    
    } else {
      $stats{insert_new_no}++;
    }
    
    my $maprow = {  pabst_peptide_id => $seq2id->{$pep_key},
                    biosequence_id => $name2id->{$line[0]} };

    if ( !$name2id->{$line[0]} ) {
      print STDERR "something is wrong with the mapping for $line[0]!\n";
    }
  
    my $map_id = $sbeams->updateOrInsertRow( insert => 1,
                                        table_name  => $TBAT_PABST_PEPTIDE_MAPPING,
                                        rowdata_ref => $maprow,
                                        verbose     => $args->{verbose},
                                       verbose     => 0, 
                                       return_PK    => 1,
                                                 PK => 'pabst_peptide_id',
                                        testonly    => $args->{testonly} );
  

  } # End read peptide loop
  close OUT;

  print "Saw $cnt total peptides\n";
  for my $s ( sort( keys( %stats ) ) ) {
    print "$s => $stats{$s}\n";
  }

} # End Main

print "Finished at " . time() . "\n";

sub calculate_expected_charge {
  my $seq = shift || return '';
  my $lys = $seq =~ tr/K/K/;
  my $arg = $seq =~ tr/R/R/;
  my $his = $seq =~ tr/H/H/;
  return( 1 + $lys + $arg + $his );
}

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
#MARK
sub populate {
  #  populate( $lib_data{$mrm}, $pep, \@trans, $mrm_libs{$mrm}, \%used_trans );
  my $trans_lib = shift;
  my $pep = shift;
  my $global_trans = shift;
  my $type = shift;

  my $used_transitions = shift || die "need used transitions hash!";

#  print "Trans is $global_trans\n" if $paranoid;

  return unless $trans_lib->{$pep};
#  print "Found peptide $pep in $type\n" if $paranoid;

  for my $chg ( 2, 3, 1 ) {
    if ( $trans_lib->{$pep}->{$chg} ) {
#      print "looks like we have $pep with charge $chg in $type - " . scalar(  @{$trans_lib->{$pep}->{$chg}}   ) . "\n" if $paranoid;
      my @trans;

#        for my $i (  @{$trans_lib->{$pep}->{$chg}} ) { print "$cnt > $i\n" if $paranoid; $cnt++; }
#        @trans = sort { $a->[9] <=> $b->[9] } @{$trans_lib->{$pep}->{$chg}};
#

      for my $t ( @{$trans_lib->{$pep}->{$chg}} ) {
        my $seen_key = join( ',', @{$t}[3,5,6,7] );
        next if $used_transitions->{$seen_key};
        push @{$global_trans}, $t;
        $used_transitions->{$seen_key}++;
        last if scalar( @{$global_trans} >= $transition_limit );
      }
    }
    last if scalar( @{$global_trans} >= $transition_limit );
  }
#  print "\nTrans has " . scalar( @$global_trans ) . " transitions!\n" if $paranoid;
#  exit if $paranoid;
}

sub check_build {
  my $build_id = shift || die "Must supply build id for delete";
  my $sql = qq~
  SELECT COUNT(*) FROM $TBAT_PABST_BUILD 
  WHERE pabst_build_id = $args->{build_id}
  ~;

  my ( $cnt ) = $sbeams->selectrow_array( $sql );
  if ( $cnt ) {
    print STDERR "Pabst build found, will delete in 3 seconds unless cntl-c is pressed\n";
    sleep 3;
  } else {
    print STDERR "No Pabst build found with ID $build_id, exiting\n";
    exit;
  }
  return;
}

sub delete_pabst_build {

  check_build( $args->{'build_id'} );

  my $database_name = $DBPREFIX{PeptideAtlas};
  my $table_name = "pabst_build";

  my $full_table_name = "$database_name$table_name";

   my %table_child_relationship = (
      pabst_build => 'pabst_peptide(C)',
      pabst_peptide => 'pabst_transition(C),pabst_peptide_mapping(C)'
   );

#      pabst_peptide => 'pabst_peptide_mapping(C)'
#      pabst_peptide => 'pabst_transition(C)','pabst_peptide_mapping(C)'

  # recursively delete the child records of the atlas build
  my $result = $sbeams->deleteRecordsAndChildren(
         table_name => 'pabst_build',
         table_child_relationship => \%table_child_relationship,
         delete_PKs => [ $args->{build_id} ],
         delete_batch => 1000,
         database => $database_name,
         verbose => $args->{verbose},
                                       verbose     => 0, 
         testonly => $args->{testonly},
      );

}


sub populate_theoretical {
  my $pep = shift;
  my $lib = shift;
  my $global_trans = shift;

  my $used_transitions = shift || die "need used transitions hash!";

  for my $trans ( @{$lib} ) {
    my $seen_key = join( ',', @{$trans}[3,5,6,7] );
    next if $used_transitions->{$seen_key};
    push @{$global_trans}, $trans;
    $used_transitions->{$seen_key}++;
    last if scalar( @{$global_trans} ) >= $transition_limit;
  }
}

sub generate_theoretical {

  my $pep = shift;
  my @predicted;
  
  # Consider first +2 and then +3 parent ion charge if necessary
  for my $chg ( 2, 3 ) {

    # Precursor m/z
    my $parent_mz = $massCalculator->getPeptideMass( sequence => $pep,   
                                             mass_type => 'monoisotopic',
                                                charge => $chg,
                                            );

    # Use Eric's fragmentation model
    my $spec = $fc->synthesizeIon( "$pep/$chg");
    if ($spec) {
      $fc->normalizeSpectrum($spec);
      print STDERR "GOSPEC: No spectrum from $pep/$chg\n" if $paranoid;
    } else {
      print STDERR "NOSPEC: No spectrum from $pep/$chg\n" if $paranoid;
      next;
    }

    # Sort by fragment intensity
    my @unsorted = @{$spec->{mzIntArray}};
    my @sorted_frags = sort { $b->[1] <=> $a->[1] } @{$spec->{mzIntArray}};

    for my $frag ( @sorted_frags ) {
      last unless $frag->[1] > 0;
      $frag->[1] = sprintf( "%0.1f", $frag->[1] * 2500 );

      # mz                              '82.5394891',
      # inten                           '0',
      # series                             'b',
      # number                             1,
      # charge                             2
      push @predicted, [ $pep, $pep, $parent_mz, $chg, $frag->[0], $frag->[4],
                         $frag->[2], $frag->[3], '', $frag->[1], 'P' ];
    }
  }
    
  if ( scalar( @predicted ) ) {
    return \@predicted;
  } else {
    # FIXME generate predicted the original way
    return [];
  }

  # Old Skool
  my $frags = $pep_sel->generate_fragment_ions( peptide_seq => $pep,
                                                     max_mz => 2500,
                                                     min_mz => 400,
                                                       type => 'P',
                                                     charge => 2,
                                             omit_precursor => 1,
                                             precursor_excl => 5 
                                          );
  my $ofrags = $pep_sel->order_fragments( $frags );
#  die Dumper ( $ofrags ) if $pep =~ /160/;
  return $ofrags;
 
}

sub process_args {

  my %args;
  GetOptions( \%args, 'mrm_file=s@', 'help',
              'peptides:s', 'conf=s', 'parameters=s', 'description=s',
              'verbose', 'testonly', 'biosequence_set_id=i', 'name=s',
              'load', 'output_file=s', 'project_id=i', 'organism=i',
              'mapping_build:i', 'delete', 'build_id=i', 'specified_only' );

  my $missing;

  $args{mapping_build} ||= 0;
  $args{verbose} ||= 0;

  print_usage() if $args{help};

  if ( !$args{load} && !$args{output_file} && !$args{delete} ) {
    $missing .= "\n" . "      Must provide either --load, --delete, or  --output_file mode";
  }

  if ( $args{delete} && !$args{build_id} ) {
    $missing .= "\n" . "      Must provide --build_id with --delete option";
  }

  if ( $args{load} || $args{output_file} ) {
    for my $opt ( qw( mrm_file peptides conf parameters biosequence_set_id project_id ) ) {
      $missing = ( $missing ) ? $missing . ", $opt" : "Missing required arg(s) $opt" if !$args{$opt};
    }
  }
  print_usage( $missing ) if $missing;

  if ( $args{conf} ) {
    undef local $/;
    open CONF, $args{conf} || die "unable to open config file $args{conf}";
    $args{conf} = <CONF>;
  }

  for my $consensus ( @{$args{mrm_file}} ) {
    my @lib_attr = split "\:", $consensus;
    print_usage ( "MRM lib files must specify instrument" ) unless scalar( @lib_attr ) > 1;
    print_usage ( "MRM lib files cannot contain : characters" ) if scalar( @lib_attr ) > 2;
    print_usage ( "unknown lib type $lib_attr[1]" ) unless $instrument_map->{$lib_attr[1]};
    push @mrm_libs, $lib_attr[0];
    $mrm_libs{$lib_attr[0]} = $instrument_map->{$lib_attr[1]};
  }

  return \%args;
}

#MARK
sub readSpectrastSRMFile {

  my %args = @_;

#  print "Library file is $args{file}, type is $args{type}, lib is $args{lib}\n";
#  exit;
#  return;

  open SRM, $args{file} || die "Unable to open SRM file $args{file}";

  my %srm = %{$args{lib}->{$args{type}}};

  while ( my $line = <SRM> ) {
    chomp $line;
    my @line = split( /\t/, $line, -1 );

    my ( $seq, $chg ) = split( "/", $line[9], -1 );

    $srm{$seq} ||= {};
    $srm{$seq}->{$chg} ||= [];
    next if scalar( @{$srm{$seq}->{$chg}} ) > $transition_limit;
#    next if $all_mrm_peaks{$srm{$seq}->{$chg}} > $mrm_peak_limit;

    my @labels = split( "/", $line[7], -1 );
    my $primary_label = $labels[0];

    next if $primary_label !~ /^[yb]/;

    # Exclude isotope ions
    next if $primary_label !~ /[yb]\d+i/;
#    next if $primary_label =~ /^p/;
#    next if $primary_label =~ /^\?/;
#    next if $primary_label =~ /^IWA/;

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

    # Skip delta masses?
    if ( $q3_delta ) {
      $q3_peak .= $q3_delta;
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
    # srm{peptide_sequence}->{charge} == pep seq, pep seq, q1 mz, q1 charge, q3 mz, q3 charge, ion series, ion number, CE, intensity, lib_type

    push @{$srm{$seq}->{$chg}}, [ $seq, $seq, $line[3], $chg, @line[5], $q3_chg, $q3_series, $q3_peak, $line[10], $line[6], $args{type} ];
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
   -s, --specified_only Only load peptides for which transitions were found in
                        one of the speclims (supress theoretical)
  END

  exit;
}

sub getOrganismID {
  my $bioseq_set_id = shift || return {};
  my $sql = qq~
  SELECT organism_id 
  FROM $TBAT_BIOSEQUENCE_SET
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

