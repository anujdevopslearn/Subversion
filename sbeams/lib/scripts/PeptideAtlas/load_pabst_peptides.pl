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
use SBEAMS::PeptideAtlas::BestPeptideSelector;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::PeptideFragmenter;

use FragmentationComparator;
use SBEAMS::Proteomics::PeptideMassCalculator;

my $pid = $$;

use constant MIN_FRAGMENT_MZ => 200;
use constant MAX_TRANSITIONS => 16;

$|++; # don't buffer output
my @letters = qw( A C D E F G H I K L M N P Q R S T V W Y );

my $sbeams = SBEAMS::Connection->new();
$sbeams->Authenticate();

my $atlas = SBEAMS::PeptideAtlas->new();
$atlas->setSBEAMS( $sbeams );

my $pep_sel = SBEAMS::PeptideAtlas::BestPeptideSelector->new();
$pep_sel->setSBEAMS( $sbeams );

my $instrument_map = $pep_sel->getInstrumentMap( src_only => 1 );
#for my $i ( sort( keys( %{$instrument_map} ) ) ) { print "$i => $instrument_map->{$i}\n"; } exit;

my %instr_type = reverse( %{$instrument_map} );
#for my $i ( sort( keys( %instr_type ) ) ) { print "$i => $instr_type{$i}\n"; }

my $massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator;

my $peptide_fragmentor = new SBEAMS::PeptideAtlas::PeptideFragmenter( MzMaximum => 3000,
                                                                      MzMinimum => MIN_FRAGMENT_MZ );

# Will be populated in process_args
my @mrm_libs;
my %mrm_libs;
my @src_paths;
my %src_paths;

# too soon?
my $seq2id = getPABSTPeptideData();

my $tmp_path = "/tmp/PABST_tmp/";
if ( ! -e $tmp_path ) {
  print STDERR "directory $tmp_path does not exist!";
  mkdir( $tmp_path );
  die "unable to create directory $tmp_path!" if ! -e $tmp_path;
}

# Used later
my $patr;
my $name2id;
my $organism_id;
my $build_id;
#my %peptide_ions = ( charge => { 1 => 0, 2 => 0, 3 => 0, 4 => 0 }, ions => {}, ion_id => '' );

# Store tmp files for cleanup
my %tmp_files;

my $args = process_args();

print "Begin at " . time() . "\n" if $args->{verbose};

if ( $args->{show_builds} ) {
  list_builds();
  exit;
}

if ( $args->{bulk_update} ) {
  die "bulk file exists, exiting" if -e 'bulk_update.bcp';
  open( BULK, ">bulk_update.bcp" );
}

my %model_map = ( QTrap4000 => '/net/db/projects/spectraComparison/FragModel_4000QTRAP.fragmod',
                  QTOF => '/net/db/projects/spectraComparison/FragModel_AgilentQTOF.fragmod', 
                  QQQ => '/net/db/projects/spectraComparison/FragModel_AgilentQTOF.fragmod', 
                  IonTrap => '/net/db/projects/spectraComparison/FragModel_IonTrap.fragmod', 
                  QTrap5500 => '/net/db/projects/spectraComparison/FragModel_QTRAP5500.fragmod', 
             );

# Load spectrum comparer code
my %fc;

my $build_nobs = {};
if ( $args->{nobs_build} ) {
  $build_nobs = get_build_nobs( build_id => $args->{nobs_build} );
}

my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;

# Flag for uber-verbose logging.
my $paranoid = 0;
$paranoid++ if $args->{verbose} > 1;

my %stats;


{ # Main 

  if ( $args->{delete} ) {
    delete_pabst_build();
    exit;
  }
  print "How I get here?\n";
  exit;

  print "Loading fragment compare\n" if $args->{verbose};
  for my $model ( keys( %model_map ) ) {
    print STDERR "loading model for $model\n" if $args->{verbose}; 
    $fc{$model} = new FragmentationComparator;
    $fc{$model}->loadFragmentationModel( filename => $model_map{$model} );
    $fc{$model}->setUseBondInfo(1);
    $fc{$model}->setNormalizationMethod(1);
  }
  print "done\n" if $args->{verbose};

  # Segregate input files
  my $time = time();
  print "Segregating files by letter $time\n" if $args->{verbose};
  for my $mrm ( @mrm_libs ) {
    print STDERR "Segregating file $mrm at " . time() . "\n"; 
    segregate_file( file => $mrm, tmp_path => $tmp_path, index => 9 );
    print STDERR "Done at " . time() . " mem usage is " . &memusage . " \n"; 
    next unless $args->{use_intensities};

    my $intensity_file = $mrm;
    $intensity_file =~ s/\.mrm$/\.inten/;
    print STDERR "Segregating file $intensity_file at " . time() . "\n"; 
    segregate_file( file => $intensity_file, tmp_path => $tmp_path, index => 0 );
    print STDERR "Done at " . time() . " mem usage is " . &memusage . " \n"; 
  }

  for my $path ( @src_paths ) {
    print STDERR "Segregating file $path at " . time() . "\n"; 
    segregate_file( file => $path, tmp_path => $tmp_path, index => 0 );
    print STDERR "Done at " . time() . " mem usage is " . &memusage . " \n"; 
  }


  open PEP, $args->{peptides} || die "Unable to open peptide file $args->{peptides}";
  print STDERR "Segregating file $args->{peptides} at " . time() . "\n"; 
  segregate_file( file => $args->{peptides}, tmp_path => $tmp_path , index => 2, header => 1 );
  print STDERR "Done at " . time() . " mem usage is " . &memusage . " \n"; 
  close PEP;
  
  open PEP, $args->{peptides} || die "Unable to open peptide file $args->{peptides}";

  # Fetch the various datasets to merge
  print STDERR "Caching stored data at " . time() . "\n"; 
  $patr = getPATRPeptides();
  $name2id = getBioseqInfo( $args->{biosequence_set_id} );
  $organism_id = getOrganismID( $args->{biosequence_set_id} );
  print STDERR "Done at " . time() . " mem usage is " . &memusage . " \n"; 

  if ( $args->{load} ) {
    # Looks like we have a build to load - insert build record
    my $conffile = abs_path( $args->{conf} );
    my $rowdata = {  build_name => $args->{name},
                    build_comment => $args->{description},
                      organism_id => $organism_id,
                 parameter_string => $args->{parameters},
                   parameter_file => $conffile,
               biosequence_set_id => $args->{biosequence_set_id}, 
                       project_id => $args->{project_id}, 
                       build_date => 'CURRENT_TIMESTAMP', 
                       is_default => 'T'
                    };
  
    $build_id = $sbeams->updateOrInsertRow( insert => 1,
                                       table_name  => $TBAT_PABST_BUILD,
                                       rowdata_ref => $rowdata,
                                       verbose     => $args->{verbose},
                                       verbose     => 0, 
                                      return_PK    => 1,
                                                PK => 'pabst_build_id',
                                       testonly    => $args->{testonly} );

    # TODO add intensity file insert 
    my $cnt = 0;
    for my $file ( @mrm_libs, $args->{conf} ) {
      $cnt++;
      my $fullpath = abs_path( $file );
      my ($name,$path) = fileparse($fullpath);
      my $checksum = `md5sum $file`;
      $checksum =~ s/\s+/\t/;
      my @checksum = split( /\t/, $checksum );

      $mrm_libs{$file} ||= '';

      my $rowdata = { pabst_build_id => $build_id,
                          file_order => $cnt,
                     file_name => $name,
                     file_path => $path,
                 file_checksum => $checksum[0],
           source_instrument_type_id => $mrm_libs{$file}
                    };

      $sbeams->updateOrInsertRow( insert => 1,
                             table_name  => $TBAT_PABST_BUILD_FILE,
                             rowdata_ref => $rowdata,
                             verbose     => $args->{verbose},
                             verbose     => 0,
                            return_PK    => 0,
                                      PK => 'pabst_build_file_id',
                             testonly    => $args->{testonly} );



    }
  }
  
  # stripped peptide sequence to instrument to mass/chg modified hash
#  for my $model ( keys( %model_map ) ) {
#    $peptide_ions{$model} ||= {};
#  }

  print STDERR "Going to load peptides at " . time() . ", memory at " . &memusage . "\n";
  my $cnt = load_build_peptides();
  cleanup_tmp();

  print "Saw $cnt total peptides\n";
  for my $s ( sort( keys( %stats ) ) ) {
    print "$s => $stats{$s}\n";
  }

  close BULK if $args->{bulk_update}; 

} # End Main

print "Finished at " . time() . "\n";

sub get_build_nobs {

  my %opts = @_;
  die  "Missing required parameter build_id" unless $opts{build_id};
  die  "Illegal value for build_id" unless $opts{build_id} =~ /^\d+$/;

  my $msg = $sbeams->update_PA_table_variables($opts{build_id});
  my $build_sql = qq~;
  SELECT DISTINCT MPI.n_observations, modified_peptide_sequence, peptide_charge
  FROM $TBAT_PEPTIDE P 
  JOIN $TBAT_PEPTIDE_INSTANCE PI 
    ON P.peptide_id = PI.peptide_id
  JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI 
    ON PI.peptide_instance_id = MPI.peptide_instance_id
  WHERE atlas_build_id = $opts{build_id};
  ~;

  my %nobs;
  my $sth = $sbeams->get_statement_handle( $build_sql );

  my $cnt = 0;
  while( my $row = $sth->fetchrow_arrayref() ) {
    my $key = $row->[1] . $row->[2];
    $nobs{$key} = $row->[0];
  }
  return \%nobs;
}

sub segregate_file {

  my %args = @_;

  for my $opt ( qw( file index ) ) {
    die "Missing required argument $opt in segregate_file" unless defined $args{$opt};
  }
  return unless -e $args{file};

  $args{tmp_path} ||= "/tmp/";

  $tmp_files{$args{file}} = {};
  my %fh;
  for my $aa1 ( @letters ) {
    for my $aa2 ( @letters ) {
      my $suffix = $aa1 . $aa2;
      $tmp_files{$args{file}}->{$suffix} = $args{tmp_path} . '/' . $args{file} . $suffix;
      if ( -e $tmp_files{$args{file}}->{$suffix} ) {
        die "File $tmp_files{$args{file}}->{$suffix} already exists, exiting";
      }
      $fh{$suffix} = new FileHandle;
      $fh{$suffix}->open( ">$tmp_files{$args{file}}->{$suffix}" );
    }
  }
  open INFIL, $args{file};
  my $cnt;
  while ( my $line = <INFIL> ) {
    next if !$cnt++ && $args{header};
    my @line = split( /\t/, $line );

    $line[$args{'index'}] =~ /^(\w).*$/;
    my $key = $1;

    if ( !defined $fh{$key} ) {
      my $sequence = $line[$args{index}];

      if  ( $args->{mod_reject} ) {
        my ( $seq, $chg ) = split( /\//, $sequence );
        my @mods = $seq =~ /(\d+)/g;
        for my $mod ( @mods ) {
          if ( $mod != 160 ) {
            print STDERR "REJECT peptide $seq due to mods\n";
            $stats{mod_reject}++;
            next;
          }
        }
      }

      $sequence =~ s/^n\[\d+\]//;
      $sequence =~ s/\[\d+\]//g;
      $sequence =~ s/\r//;
      $sequence =~ /^(\w\w).*$/;
      $key = $1;
      if ( !defined $fh{$key} ) {
        print STDERR "WARN: No key found from $line[$args{index}] or $sequence\n";
        next;
      }
    }

    eval {
      print {$fh{$key}} $line;
    }; 
    if ( $@ ) {
      die "died with $@, field $args{index} was $line[$args{index}]";
    }
  }
  close INFIL;
  for my $aa1 ( @letters ) {
    for my $aa2 ( @letters ) {
      my $suffix = $aa1 . $aa2;
	    $fh{$suffix}->close();
    }
  }
}

sub cleanup_tmp {
  for my $file ( keys( %tmp_files ) ) {
    for my $aa1 ( @letters ) {
      for my $aa2 ( @letters ) {
        my $suffix = $aa1 . $aa2;
#        next if $suffix =~ /AP|GP|GG|AA/;
        unlink( $tmp_files{$file}->{$suffix} );
      }
    }
  }
}

sub insert_transitions {

  my %args = @_;

# transition_id_ref
# transitions_ref
# peptide_ion_ref
# instr_id

  my $tcnt = 1;
  for my $t ( @{$args{transitions_ref}} ) {

    my $label = $t->[6] . $t->[7] . '+' . $t->[5];

    # Insert transition only once 
    if ( !$args{transition_id_ref}->{$label} ) {

      # Fixme, use delta?
      my $fragment_mz = $args{peptide_ion_ref}->{$label} || $t->[4];

      my $tranrow = { pabst_peptide_ion_id => $args{peptide_ion_ref}->{peptide_ion_id},
                        precursor_ion_mz => $args{peptide_ion_ref}->{precursor} ,
                      precursor_ion_charge => $t->[3],
                         fragment_ion_mz => $fragment_mz,
                       fragment_ion_charge => $t->[5],
                        fragment_ion_label => $t->[6] . $t->[7],
                      };

      if ( $fragment_mz < MIN_FRAGMENT_MZ ) {
#        print STDERR "Skipping $label with mz of $fragment_mz due to size!\n";
        next;
      }

      $args{transition_id_ref}->{$label} = $sbeams->updateOrInsertRow( insert => 1,
                                                                 table_name  => $TBAT_PABST_TRANSITION,
                                                                rowdata_ref => $tranrow,
                                                                 verbose     => $args->{verbose},
                                                                 verbose     => 0,
                                                                return_PK    => 1,
                                                                          PK => 'pabst_transition_id',
                                                                 testonly    => $args->{testonly} );
    }

      
      my $is_predicted = ( $args{is_predicted} ) ? 'Y' : 'N';
      my $rowdata = { pabst_transition_id => $args{transition_id_ref}->{$label},
                           ion_rank => $tcnt++,
                 relative_intensity => $t->[9],
                   collision_energy => $t->[8],
                        observed_mz => $t->[4],
                       is_predicted => $is_predicted,
          source_instrument_type_id => $args{instr_id},
                      };
      if ( $args->{bulk_update} ) {
        my $inten = $t->[9] || 'NULL';
        my $coll = $t->[8] || 'NULL';
        print BULK join( "\t", $args{transition_id_ref}->{$label},$t->[4],$rowdata->{ion_rank},$inten,$args{instr_id},$t->[4],$coll,$is_predicted ) . "\n";

      } else { 

        $sbeams->updateOrInsertRow( insert => 1,
                               table_name  => $TBAT_PABST_TRANSITION_INSTANCE,
                               rowdata_ref => $rowdata,
                               verbose     => $args->{verbose},
                               verbose     => 0,
                              return_PK    => 1,
                                        PK => 'pabst_transition_instance_id',
                               testonly    => $args->{testonly} );
      }



  }

}

sub insert_peptide_ion {
  my %args = @_;
#ion_ref - precursor
#        - modseq
#        - charge
#peptide_id  

  # Insert peptide record
  my $rowdata = { pabst_peptide_id => $args{peptide_id},
                  modified_peptide_sequence => $args{ion_ref}->{modifiedSequence},
                  peptide_charge => $args{ion_ref}->{charge},
                  peptide_mz => $args{ion_ref}->{precursor},
  };


#  print "Inserting pepion $args{ion_ref}->{modifiedSequence} as $args{ion_ref}->{charge}\n";
 
  my $peptide_ion_id;
   $peptide_ion_id = $sbeams->updateOrInsertRow( insert => 1,
                                            table_name  => $TBAT_PABST_PEPTIDE_ION,
                                            rowdata_ref => $rowdata,
                                                verbose => $args->{verbose},
                                                verbose => 0,
                                              return_PK => 1,
                                                     PK => 'pabst_peptide_ion_id',
                                            testonly    => $args->{testonly} );

   return $peptide_ion_id;
}


sub insert_peptide_ion_instance {
  my %args = @_;
#ion_id 
#instr_id
#n_obs
# ion_key 

  my $nobs = $args{n_obs};
  # Update n_obs based on atlas if specfied by user.
  if ( $build_nobs &&  $build_nobs->{$args{ion_key}} ) {
    $nobs = $build_nobs->{$args{ion_key}};
  }
#  print STDERR join( "\t", 'NOBS', $args{ion_key}, $nobs, $args{n_obs} ) . "\n";
  my $intensity = $args{max_precursor_intensity} || 0;

  # Insert peptide_ion_instance record
  my $rowdata = { pabst_peptide_ion_id => $args{ion_id},
                  source_instrument_type_id => $args{instr_id},
                  n_observations => $nobs,
                  max_precursor_intensity => $intensity,
  };
#  print "Inserting peption instance for $args{ion_id} on $args{instr_id}\n";
 
  my $peptide_ion_instance_id;
  $peptide_ion_instance_id = $sbeams->updateOrInsertRow( insert => 1,
                                           table_name  => $TBAT_PABST_PEPTIDE_ION_INSTANCE,
                                           rowdata_ref => $rowdata,
                                               verbose => $args->{verbose},
                                               verbose => 0,
                                             return_PK => 1,
                                                    PK => 'pabst_peptide_ion_instance_id',
                                           testonly    => $args->{testonly} );

   return $peptide_ion_instance_id;
}

sub insert_src_path {
  my %args = @_;
# peptide_ion_instance_id
# path 

  # Insert peptide_ion_instance record
  my $rowdata = { peptide_ion_instance_id => $args{peptide_ion_instance_id},
                  source_path => $args{path},
  };
 
  $sbeams->updateOrInsertRow( insert => 1,
                         table_name  => 'peptideatlas.dbo.pabst_tmp_source_path',
                         rowdata_ref => $rowdata,
                             verbose => $args->{verbose},
                             verbose => 0,
                         testonly    => $args->{testonly} );

}




## FINITO


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


sub populate {
  #  populate( $lib_data{$mrm}, $pep, \@trans, $mrm_libs{$mrm}, \%used_trans );

  # Seems to be unused
  die "A fiery death";

  my $trans_lib = shift;
  my $pep = shift;
  my $global_trans = shift;
  my $type = shift;

  my $used_transitions = shift || die "need used transitions hash!";

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
        last if scalar( @{$global_trans} ) >= MAX_TRANSITIONS;
      }
    }
    last if scalar( @{$global_trans} ) >= MAX_TRANSITIONS;
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
#    sleep 3;
  } else {
    print STDERR "No Pabst build found with ID $build_id, exiting\n";
    exit;
  }
  return;
}

sub list_builds {
  my $sql = qq~
  SELECT pabst_build_id, build_name FROM $TBAT_PABST_BUILD 
  ORDER BY pabst_build_id ASC
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  print join( "\t", 'Build ID', 'Build Name' ) . "\n";
  while( my @row = $sth->fetchrow_array() ) {
    print  join( "\t", @row ) . "\n";
  }
  exit;
  return;
}

sub load_build_peptides {

  for my $aa1 ( @letters ) {
    for my $aa2 ( @letters ) {
      my $suffix = $aa1 . $aa2;

      print STDERR "Looping over AA, currently $suffix " . &memusage() . " \n" if $args->{verbose}; 
      my %lib_data;
      my %intensity_data;
      for my $lib_base ( @mrm_libs ) {
  
        my $mrm = $tmp_files{$lib_base}->{$suffix};
  
        # lib data is hash ref, init here, and pass to reading routine.
        # If more than one lib is provided for a given data type, will
        # use first instance of a given peptide ion
        my $time = time();
#        print "Reading $mrm file data: $time\n" if $args->{verbose};
        my $type = $instr_type{$mrm_libs{$lib_base}};
  
        $lib_data{$type} ||= {};
        $lib_data{$type} = readSpectrastSRMFile( file => $mrm,
                                                type => $type,
                                                 lib => $lib_data{$type} );
  
#        print Dumper( %lib_data) if $suffix eq 'GG';
        # Added intensity values
        next unless $args->{use_intensities};
        my $inten_base = $lib_base; 
        $inten_base =~ s/mrm$/inten/;
        my $inten = $tmp_files{$inten_base}->{$suffix};
        $intensity_data{$type} ||= {};
  
        $intensity_data{$type} = readIntensityFile( file => $inten,
                                                    type => $type,
                                                     lib => $intensity_data{$type} );
  
      }

      my %path_data;
      for my $lib_base ( @src_paths ) {
  
        my $path = $tmp_files{$lib_base}->{$suffix};
  
        # path data is hash ref, init here, and pass to reading routine.
        # If more than one lib is provided for a given data type, will
        # use first instance of a given peptide ion
        my $time = time();
        print "Reading $path file data: $time\n" if $args->{verbose};
        my $type = $instr_type{$src_paths{$lib_base}};
  
        $path_data{$type} ||= {};
  
        $path_data{$type} = readIntensityFile( file => $path,
                                               type => $type,
                                                lib => $path_data{$type} );
      }
  
  
      my $pepfile = $tmp_path . $args->{peptides} . $suffix;
  
      open PEP, $pepfile || die "Unable to open peptide file $pepfile";
  
      # Meat and 'taters
      my $cnt;
      my %is_predicted;
      while ( my $line = <PEP> ) {
        print "Loaded $cnt peptides, mem usage is " . &memusage . "\n" unless $cnt++ % 2500;
#        foreach my $entry ( keys %main:: ) {
#          print "$entry => $main::{$entry}\n";
#        }
#        die;
    
        chomp $line;
        my @line = split( "\t", $line, -1 );
    
        # Often loading a fetch_best_peptides file
        next if $line[0] eq 'biosequence_name';
    
        # Disregard peptides with odd amino acids 
        unless ( $line[2] =~ /^[ACDEFGHIKLMNOPQRSTVWY]+$/ ) {
          $stats{bad_aa}++;
          next;
        }
        $line[14] =~ s/NxST/nxst/g;
        if ( $line[14] =~ /ST|MC/ ) {
          $stats{nontryptic}++;
          # print STDERR "$line[2] is nontryptic!\n";
    
          next;
        }
    
        # All Cys residues must be alkylated carboxymethyl...
        # this 'modified sequence' is just the peptide + C160, all
        # other mods are from the mrm libraries
        my $modified_sequence = $line[2];
        if ( $modified_sequence =~ /C/ ) {
          # Skip if alread modded
          next if $modified_sequence =~ /\d/; 

          # Change *all* Cys (prev regex skipped second C of CC peptides)
          $modified_sequence =~ s/C/C[160]/g;
        }
#        print STDERR "$line[2] becomes $modified_sequence\n";
    
        my $pep_key = $line[1] . $line[2] . $line[3];
  
        # Only insert if we need to?
        if ( !$seq2id->{$pep_key} ) {
      
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
        
  
          # FIXME - if we key off of the modified peptide, are we inserting more than one peptide for those peptides
          # represented in different mod states?
  
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

#          print "INSERTING $line[2], modseq of $modified_sequence\n";
          my $stripped_seq = $modified_sequence;
          $stripped_seq =~ s/\[\d+\]//g;
        
          # Cache this to avoid double insert.
          $seq2id->{$pep_key} = $pep_id;
          # END Insert peptide record
    
          my %peptide_ions;
          # loop over instrument types, calc theoretical frag masses for any pepions seen.
          for my $instr ( keys( %lib_data ) ) {
#            print "SUFX: $suffix $instr\n";
            if  ( $lib_data{$instr} ) {
              if ( $lib_data{$instr}->{$modified_sequence} || $lib_data{$instr}->{MOD_IONS}->{$stripped_seq} ) {
#                print "Has lib data for $modified_sequence\t";
#                print join( ',', keys( %{$lib_data{$instr}} ) ) . "\n";
#                print join( ',', keys( %{$lib_data{$instr}}, $lib_data{$instr}->{MOD_IONS} ) ) . "\n";
#                print join( ',', keys( %{$lib_data{$instr}} ), Dumper( $lib_data{$instr}->{MOD_IONS} ) ) . "\n";

                for my $modseq ( $modified_sequence, keys( %{$lib_data{$instr}->{MOD_IONS}->{$stripped_seq}} ) ) {
#                  print "MSEQ $modseq\n";

                  for my $chg ( sort { $a <=> $b } ( keys( %{$lib_data{$instr}->{$modseq}} ) ) ) {
                    my $ion_key = $modseq . $chg;
#                    print "\tCHG $chg\n";
                    if ( !$peptide_ions{$ion_key} ) {
                      $peptide_ions{$ion_key} ||= { charge => $chg,
                                          modifiedSequence => $modseq
                                                  };
                      my $mz_value = $peptide_fragmentor->getExpectedFragments( modifiedSequence => $modseq, 
                                                                                          charge => $chg );
    
                      for my $row ( @{$mz_value} ) {
#                        print "MZ is $row->{mz} for $row->{label}, original is $peptide_ions{$ion_key}->{$row->{label}} on $instr\n";

                        $peptide_ions{$ion_key}->{$row->{label}} ||=  sprintf( "%0.4f", $row->{mz} );
                      }
    
                      # Insert peptide ion here...
                      $peptide_ions{$ion_key}->{peptide_ion_id} = insert_peptide_ion( ion_ref =>  $peptide_ions{$ion_key},
                                                                                    peptide_id => $pep_id,
                                                                                   );
                    }
                  }
                }
              } else {
#                print "Didn't have lib data for $modified_sequence\t";
#                print join( ',', keys( %{$lib_data{$instr}} ), Dumper( $lib_data{$instr}->{MOD_IONS} ) ) . "\n";
              }
            }
          } # End calc theoretical masses loop
  


          # If we didn't see any peptide ions from any of the mrm databases...
          my $is_predicted = 0;

          # This keeps second inserts of a 'is_predicted' peptide to be recorded as not predicted.
          if ( $is_predicted{$modified_sequence} ) {
            $is_predicted++;
          }

           # Important note, we only do the prediction if there are no MRMs from any instrument - therefore
           # the is_predicted is instrument-independent.
          if ( !scalar( keys( %peptide_ions ) ) ) {

            my $ec = $pep_sel->get_expected_charge( sequence => $line[2] );

					  # Charge states > 4 are unlikely to be found
						$ec = 4 if $ec > 3;

            my $ion_key = $modified_sequence . $ec;

            $is_predicted++;
            $is_predicted{$modified_sequence}++;
#            print "$modified_sequence IS predicted, and the fact is being recorded!\n";

            for my $instr ( keys( %lib_data ) ) {
              $peptide_ions{$ion_key} ||= { charge => $ec,
                                  modifiedSequence => $modified_sequence };
  
              $lib_data{$instr}->{$modified_sequence}->{$ec} = generate_theoretical( sequence => $line[2], charge => $ec, fc => $fc{$instr}  );

              my $mz_value = $peptide_fragmentor->getExpectedFragments( modifiedSequence => $modified_sequence, 
                                                                                        charge => $ec );
    
              my $trans =  $lib_data{$instr}->{$modified_sequence}->{$ec};

              for my $row ( @{$mz_value} ) {
                $peptide_ions{$ion_key}->{$row->{label}} ||=  sprintf( "%0.4f", $row->{mz} );
              }
              # Insert peptide ion here...
              $peptide_ions{$ion_key}->{peptide_ion_id} = insert_peptide_ion( ion_ref =>  $peptide_ions{$ion_key},
                                                                           peptide_id => $pep_id );
  
  
              next if ( !$lib_data{$instr}->{$modified_sequence}->{$ec}  );
            }
#            print "In theoretical loop for $modified_sequence, calculated fragments and everything!\n";
  
          } else {
  #         print STDERR "Skipping";
  #          next;
          }
          


          # loop over instruments, insert any transitions
          my %transitions;
          for my $instr ( keys( %lib_data ) ) {
    
    #       For each instrument type, insert all available peptide ions including mods - cache list
            if  ( $lib_data{$instr} && ( $lib_data{$instr}->{$modified_sequence} || $lib_data{$instr}->{MOD_IONS}->{$stripped_seq} ) ) {

              for my $modseq ( $modified_sequence, keys( %{$lib_data{$instr}->{MOD_IONS}->{$stripped_seq}} ) ) {
#                print "transitions for $modified_sequence\n";
    
                my $transition_set;
                if ( $lib_data{$instr}->{$modseq} ) {
                  $transition_set = $lib_data{$instr}->{$modseq};
                } else {
                  next;
                }

                for my $chg ( sort { $a <=> $b } ( keys( %{$lib_data{$instr}->{$modseq}} ) ) ) {
                  my $ion_key = $modseq . $chg;
  
                  # Kind of ugly, but we need to extract a value from the first transition entry...
                  my $nobs = 0;
                  unless ( $is_predicted ) {
                    for my $t ( @{$lib_data{$instr}->{$modseq}->{$chg}} ) {
                      $nobs = $t->[11];
                      last;
                    }
                    $nobs ||= 1;
                  }
  
                  my $intensity = 0;
                  if ( $intensity_data{$instr} && $intensity_data{$instr}->{$ion_key} ) {
                    $intensity = $intensity_data{$instr}->{$ion_key};
                  }
  
                  # Insert peptide ion instance here...
                  my $pii_id = insert_peptide_ion_instance( ion_id => $peptide_ions{$ion_key}->{peptide_ion_id},
                                                          instr_id => $instrument_map->{$instr},
                                                             n_obs => $nobs,
                                                           ion_key => $ion_key,
                                           max_precursor_intensity => $intensity
                                                          );

#                  print "Trans should be ok for $instr and $modseq and $chg: $lib_data{$instr}->{$modseq}->{$chg}\n";

                  # Insert transitions here...
                  insert_transitions( transitions_ref => $lib_data{$instr}->{$modseq}->{$chg}, 
                                      peptide_ion_ref => $peptide_ions{$ion_key},
                                   transition_ids_ref => \%transitions,
                                         is_predicted => $is_predicted,
                                             instr_id => $instrument_map->{$instr},
                                    );
    
                }
              }
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
      print STDERR "Done with $aa1$aa2 at " . time() . " mem usage is " . &memusage . " \n" if $args->{verbose}; 
    } # End second AA loop
    print STDERR "Done with $aa1 at " . time() . " mem usage is " . &memusage . " \n" if $args->{verbose}; 
  } # End first AA loop
} # End load_build_peptides

sub memusage {
  my @results = `ps -o pmem,pid $pid`;
  my $mem = '';
  for my $line  ( @results ) {
    chomp $line;
    if ( $line =~ /\s*(\d+\.*\d*)\s+$pid/ ) {
      $mem = $1;
      last;
    }
  }
  $mem .= '% (' . time() . ')';
  return $mem;
}


sub delete_pabst_build {

  check_build( $args->{'build_id'} );

  my $database_name = $DBPREFIX{SRMAtlas} || die "must define SRMAtlas as DBPREFIX";
  my $table_name = "pabst_build";

  my $full_table_name = "$database_name$table_name";

   my %table_child_relationship = (
      pabst_build => 'pabst_peptide(C),pabst_build_file(C),pabst_build_resource(C),pabst_build_statistics(C)',
      pabst_peptide => 'pabst_peptide_ion(C),pabst_peptide_mapping(C)',
      pabst_peptide_ion => 'pabst_transition(C),pabst_peptide_ion_instance(C)',
      pabst_transition => 'pabst_transition_instance(C)'
   );

  # recursively delete the child records of the atlas build
  my $result = $sbeams->deleteRecordsAndChildren(
         table_name => 'pabst_build',
         table_child_relationship => \%table_child_relationship,
         table_PK_column_names => { pabst_build_resource => 'pabst_build_id', pabst_build_statistics => 'pabst_build_id' },
         delete_PKs => [ $args->{build_id} ],
         delete_batch => 1000,
         database => $database_name,
         verbose => $args->{verbose},
     verbose     => 0, 
         testonly => $args->{testonly},
      );
  print "Done with deletion\n";
  return 1;
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
    last if scalar( @{$global_trans} ) >= MAX_TRANSITIONS;
  }
}

sub generate_theoretical {

  my %args = @_;
  for my $arg ( qw( sequence charge fc ) ) {

    die "FARG!" unless defined $args{$arg};
  }

  my @predicted;
  
  for my $chg ( $args{charge} ) {

    # Precursor m/z
    my $parent_mz = $massCalculator->getPeptideMass( sequence => $args{sequence},   
                                             mass_type => 'monoisotopic',
                                                charge => $args{charge},
                                            );

    # Use Eric's fragmentation model
    my $spec = $args{fc}->synthesizeIon( "$args{sequence}/$args{charge}");

    if ($spec) {
      $args{fc}->normalizeSpectrum($spec);
#      print STDERR "GOSPEC: No spectrum from $pep/$chg\n" if $paranoid;
    } else {
      return undef;
    }

    # Sort by fragment intensity
    my @unsorted = @{$spec->{mzIntArray}};
    my @sorted_frags = sort { $b->[1] <=> $a->[1] } @{$spec->{mzIntArray}};

    for my $frag ( @sorted_frags ) {
      last unless $frag->[1] > 0;
      $frag->[1] = sprintf( "%0.1f", $frag->[1] * 100 );

      # mz                              '82.5394891',
      # inten                           '0',
      # series                             'b',
      # number                             1,
      # charge                             2
      push @predicted, [ $args{sequence}, $args{sequence}, $parent_mz, $args{charge}, $frag->[0], $frag->[4],
                         $frag->[2], $frag->[3], '', $frag->[1], 'Predicted' ];
    }
  }
    
  if ( scalar( @predicted ) ) {
    return \@predicted;
  }
  die "BLARG";
  return undef;
}

sub process_args {

  my %args;
  GetOptions( \%args, 'mrm_file=s@', 'help', 'run_path_file=s@',
              'peptides:s', 'conf=s', 'parameters=s', 'description=s',
              'verbose', 'testonly', 'biosequence_set_id=i', 'name=s',
              'load', 'output_file=s', 'project_id=i', 'organism=i',
              'mapping_build:i', 'delete', 'build_id=i', 'specified_only',
              'show_builds', 'nobs_build=i', 'use_intensities', 'quash_bulk', 'mod_reject' );

  my $missing;
  $args{bulk_update} = ( $args{quash_bulk} || $args{'delete'} ) ? 0 : 1;

  $args{mapping_build} ||= 0;
  $args{verbose} ||= 0;

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

#  print "Library file is $args{file}, type is $args{type}, lib is $args{lib}\n" if $args->{verbose};

  if ( ! -e $args{file} ) {
    die "File $args{file} does not exist";
  }
  open SRM, $args{file} || die "Unable to open SRM file $args{file}";

  my %srm = %{$args{lib}};
  $srm{MOD_IONS} ||= {};

  while ( my $line = <SRM> ) {
    chomp $line;
    my @line = split( /\t/, $line, -1 );

    my ( $seq, $chg ) = split( "/", $line[9], -1 );

    $srm{$seq} ||= {};
    $srm{$seq}->{$chg} ||= [];

    # Cache any modified sequenes 
    if ( $seq =~ /\d/ ) {
      my $stripped = $seq;
      $stripped =~ s/\[\d+\]//gm;
      $srm{MOD_IONS}->{$stripped} ||= {};
      $srm{MOD_IONS}->{$stripped}->{$seq}++;
    }

#    print "$seq and $chg has " . scalar( @{$srm{$seq}->{$chg}} ) . " \n";
    # FIXME are these redundant?  Effective?
    next if scalar( @{$srm{$seq}->{$chg}} ) > MAX_TRANSITIONS;
#    next if $all_mrm_peaks{$srm{$seq}->{$chg}} > MAX_TRANSITIONS;

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

# 00 Lib Name
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

