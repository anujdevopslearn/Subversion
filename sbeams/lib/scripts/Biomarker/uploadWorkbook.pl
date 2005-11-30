#!/usr/local/bin/perl -w

# perl script to upload sample worksheet into the database
#
# $Id$

use FindBin qw($Bin);
use Getopt::Long;

use lib( "$Bin/../../perl" );
use SBEAMS::Connection qw($log);

use SBEAMS::Biomarker;
use SBEAMS::Biomarker::ParseSampleWorkbook;
use SBEAMS::Biomarker::Tables;
use SBEAMS::Biomarker::Biosample;
use SBEAMS::Biomarker::Biosource;

use strict;

# Setup global objects
my $sbeams = SBEAMS::Connection->new();
#$sbeams->output_mode( 'interactive' );
my $biomarker = SBEAMS::Biomarker->new();

# Main
{
  $sbeams->Authenticate();
  $biomarker->set_sbeams( $sbeams );

  my $params = processParams();
  
  # Instantiate new parser
  my $p = SBEAMS::Biomarker::ParseSampleWorkbook->new(verbose => $params->{verbose});
  
  # Give parser file_name file to chew on
  my $msgs = $p->parseFile( type => $params->{type},
                           wbook => $params->{file_name} );

  if ( $params->{verbose} ) {
    for my $msg ( @$msgs ) {
      print "$msg\n";
    }
  }
  
  # Allow parser to chew data into digestable bits
  $p->process_data();

  my $biosource = SBEAMS::Biomarker::Biosource->new();
  $biosource->set_sbeams( $sbeams );
  my $biosample = SBEAMS::Biomarker::Biosample->new();
  $biosample->set_sbeams( $sbeams );

  my $group;

  # Fetch processed file as hash of hashrefs
  my $all_items = $p->getProcessedItems();
  die "No valid objects found" unless $all_items;

  if ( $params->{test_only} ) {
    my $results = test_data( biosource => $biosource,
                             biosample => $biosample,
                             items     => $all_items,
                             redundant => 0 
                           );

    # Print some info, if warranted
    printMissing( $results ) if $results->{missing};

  } else {
    add_items( biosource => $biosource,
               biosample => $biosample,
               items     => $all_items,
               params  => $params );
  }

}
  
sub printMissing {
  my $missing = shift;

  print <<"  END";


  Found one or more related entities that don't yet exist in the database.  
  END

  if ( @{$missing->{auto}} ) {
    print <<"    END";
  If you run with the --autocreate flag ( and without the --test_only flag )
  then these will be autocreated for you.  The descriptions will be generic,
  so you should go back and update them via the manage table interface.
  --------------------------------------------------------------------------
    END
    sleep 2;
    for ( @{$missing->{auto}} ) { print "  > $_"; }
    print "\n";
  }
  if ( @{$missing->{manual}} ) {
    print <<"    END";

  The following attributes must be added via the web UI before you can can
  upload this dataset. 
  --------------------------------------------------------------------------
    END
    sleep 2;
    for ( @{$missing->{manual}} ) { print "  > $_"; }
    print "\n";
  }
}


#+
#
#
#-
sub add_items {
  my %args = @_;
  for my $arg qw( biosource biosample items params ) {
    die "Missing required parameter $arg" unless defined $args{$arg};
  }

  my %params = %{$args{params}};

  my $results = test_data( biosource => $args{biosource},
                           biosample => $args{biosample},
                           items     => $args{items},
                           redundant => 0,
                           verbose   => 1 );

  if ( $results->{missing} ) {

    # Missing peripherals, and autocreate isn't set
    if ( !$params{autocreate} ) {
      printMissing( $results );
      print "Unable to proceed, autocreate not set and unfulfilled dependancies found:\n";
      exit;
    }

    # Missing peripherals that we cannot autocreate
    if ( @{$results->{manual}} ) {
      print "Unable to proceed, cannot manually add one or more results attributes\n";
      exit;
    }
  }
  

  # cache initial values for these
  my $ac = $sbeams->isAutoCommit();
  my $re = $sbeams->isRaiseError();
    
  # We are going to (try to) do this atomically.
  $sbeams->initiate_transaction();

  eval {
         # First, add any peripheral things that need to be added
         $args{biosource}->createAttributes( attr => $results->{attributes},
                                              auto => 1 );
         $args{biosource}->createDiseases( diseases => $results->{diseases},
                                            auto => 1 );

# This is vestigal, when disease tissues were being autocreated.
         $args{biosource}->create_tissues( tissue_type => $results->{tissue_type} );
         $args{biosample}->createStorageLoc( strg_loc => $results->{storage_loc} );

         my $name = $params{group_tag} || 'upload-' . $sbeams->get_datetime() .
                                          '-' . $params{experiment};

         my $grp_id = $biomarker->create_biogroup( group_name  => $name,
                                                   description => "Dataset uploaded via $0",
                                                   type        => 'import' );

         # Next, iterate through lines and add src/samples, join records.
         foreach my $item ( @{$args{items}} ) {
            
           # Gotta map a few strings to their corresponding primary key.
           # Biosource
           set_organism_id( $item->{biosource} );
           set_org_id( $item->{biosource} );
           set_tissuetype_id( $item->{biosource} );

           # Biosample
           set_exp_id( $params{experiment}, $item->{biosample} );
           set_storageloc_id( $item->{biosample} );

           # Gotta clean up some ill-advised data
           na_to_undef( $item->{biosource} );
           interpret_age( $item->{biosource} ) if $item->{biosource}->{age};

           # Add biosource record
           my $src_id = $args{biosource}->add_new( data_ref => $item->{biosource},
                                                  group_id => $grp_id );
           next unless $src_id;


           # Biosource related
           $args{biosource}->add_biosource_attrs(  attrs => $item->{biosource_attr},
                                                src_id => $src_id );
           $args{biosource}->add_biosource_diseases(  diseases => $item->{biosource_disease},
                                                      src_id => $src_id );

           # Add biosample record
           # first a little triage
           $item->{biosample}->{biosample_name} = $item->{biosource}->{biosource_name}; 
           $item->{biosample}->{original_volume} = interpret_vol ( $item->{biosample}->{original_volume} );

           my $smpl_id = $args{biosample}->add_new( data_ref => $item->{biosample},
                                                    group_id => $grp_id,
                                                      src_id => $src_id
                                                  );
           # Biosample related
           $args{biosample}->add_biosample_attrs( attrs => $item->{biosample_attr},
                                                smpl_id => $smpl_id );
         }
       };   # End eval block
       if ( $@ ) {
         print STDERR "$@\n";
         $sbeams->rollback_transaction();
         exit;
       }  # End eval catch-error block
       
#  $sbeams->rollback_transaction();
  $sbeams->commit_transaction();
  $sbeams->setAutoCommit( $ac );
  $sbeams->setRaiseError( $re );
}

sub interpret_age {
  my $biosource = shift;
  my ($age) = $biosource->{age} =~ /(\d+)/g;
  my ($units) = $biosource->{age} =~ /(\D+)/g;
  print STDERR "$biosource->{age} => $age and $units\n";
  $biosource->{age} = $age;
  $biosource->{age_units} = $units;
  return;
}

sub interpret_vol {
  my $vol = shift;
  $vol =~ s/\D//g;
  return $vol;
}

sub set_exp_id {
  my $exp_name = shift;
  my $biosample = shift;
  ($biosample->{experiment_id}) = $sbeams->selectrow_array( <<"  END" );
  SELECT experiment_id 
  FROM $TBBM_EXPERIMENT
  WHERE experiment_tag = '$exp_name'
  END
}

sub set_organism_id {
  my $biosource = shift;
  return unless $biosource->{organism_id};
  ($biosource->{organism_id}) = $sbeams->selectrow_array( <<"  END" );
  SELECT organism_id 
  FROM $TB_ORGANISM
  WHERE organism_name = '$biosource->{organism_id}'
  END
}

sub set_org_id {
  my $biosource = shift;
  return unless $biosource->{organization_id};
  ($biosource->{organization_id}) = $sbeams->selectrow_array( <<"  END" );
  SELECT organization_id 
  FROM $TB_ORGANIZATION
  WHERE organization = '$biosource->{organization_id}'
  END
}

sub na_to_undef {
  my $dref = shift;
  for ( keys( %$dref ) ) {
    $dref->{$_} =~ s/^N\/A$//gi
  }
}

sub set_tissuetype_id {
  my $biosource = shift;

#  for my $k ( keys( %$biosource ) ) { print "KEYHASH $k => $biosource->{$k}\n";  } #  die;

  return unless $biosource->{tissue_type_id};

  # What is currently in the database
  ($biosource->{tissue_type_id}) = $sbeams->selectrow_array( <<"  END" );
  SELECT tissue_type_id 
  FROM $TBBM_TISSUE_TYPE
  WHERE tissue_type_name = '$biosource->{tissue_type_id}'
  END
  
}

sub set_storageloc_id {
  my $biosample = shift;
  $biosample->{storage_location_id} ||= undef;
  ($biosample->{storage_location_id}) = $sbeams->selectrow_array( <<"  END" );
  SELECT storage_location_id 
  FROM $TBBM_STORAGE_LOCATION
  WHERE location_name = '$biosample->{storage_location_id}'
  END
  return;
}

#+
# Subroutine checks attributes, tissues, and diseases to see if they exist in
# the db.  Returns ref to hash keyed by items above, each pointing to an array
# of items that did not exist.
#-
sub test_data {
  my %args = @_;
  for my $arg qw( biosource biosample items ) {
    die "Missing required parameter $arg" unless defined $args{$arg};
  }
  # Can autocreate
  my %redundant_attr;
  my %redundant_tissue_type;
  my %redundant_disease;
  my %redundant_storage_loc;

  # Cannot autocreate
  my %redundant_organism;
  my %redundant_organization;

  # Hash to hold various missing entities.
  my %results = ( attributes   => [],
                  tissues      => [],
                  diseases     => [],
                  storage_loc  => [],
                  organism     => [],
                  organization => []
                );

  # Arrays to hold warning messages, distinguish autocreate and manual fields.
  my ( @auto, @manual );

  my $item_no = 0;

  # Iterate through the items (lines), check whether various peripheral
  # values exist in the database. 
  for my $item ( @{$args{items}} ){
    $item_no++;

    ### Check Attributes ###
    for my $k ( keys( %{$item->{biosource_attr}} ),
                keys( %{$item->{biosample_attr}} ) ) {

      # Skip if we've seen it (unless redundant mode)
      next if $redundant_attr{$k} && !$args{redundant};

      # push into missing attributes array, print message if desired.
      unless ( $args{biosource}->attrExists($k) ) {
        push @{$results{attributes}}, $k; 
        push @auto, "Line $item_no: Attribute $k doesn't exist yet\n";
      }
      # record the fact that we've seen it.
      $redundant_attr{$k}++;
    }

    
    ### Check Diseases ###
    for my $k ( keys(%{$item->{biosource_disease}}) ) {

      # Skip if we've seen it (unless redundant mode)
      next if $redundant_disease{$k} && !$args{redundant};

      # push into missing disease array, print message if desired.
      unless ( $args{biosource}->diseaseExists( $k ) ) {
        push @{$results{diseases}}, $k;
        push @auto, "Line $item_no: Disease $k doesn't exist yet\n";
      }
      # record the fact that we've seen it.
      $redundant_disease{$k}++;
    }
     
    ### Check storage_location ###
    $item->{biosample}->{storage_location_id} ||= $biomarker->set_default_location();
    my $stor = $item->{biosample}->{storage_location_id};
    
    # push into missing storage_loc array, print message if desired.
    if ( (!$redundant_storage_loc{$stor} || $args{redundant} )) {
      unless ( $args{biosample}->storageLocExists($stor) ) {
        push @{$results{storage_loc}}, $stor;
        push @auto, "Line $item_no: Storage location $stor does not yet exist\n";
      }
      $redundant_storage_loc{$stor}++;
    }

    ### Check tissue_type ###
    my $tissue_type = $item->{biosource}->{tissue_type_id};
    
    # push into missing storage_loc array, print message if desired.
    if ( (!$redundant_tissue_type{$tissue_type} || $args{redundant} )) {
      unless ( $args{biosource}->tissue_type_exists($tissue_type) ) {
        push @{$results{tissue_type}}, $tissue_type;
        push @auto, "Line $item_no: Tissue type $tissue_type does not yet exist\n";
      }
      $redundant_tissue_type{$tissue_type}++;
    }

     
    ### Check organism ###
    my $organism = $item->{biosource}->{organism_id} || '';

    dumpstuff( $item_no, $item ) if !$organism;
    
    # Skip if we've seen it (unless redundant mode)
    if ( (!$redundant_organism{$organism} || $args{redundant})) {
      # Cache info
      unless ( $args{biosource}->organismExists($organism) ) {
        push @{$results{organism}}, $organism;
        push @manual, "Line $item_no: Organism $organism does not yet exist\n"; 
      }
      $redundant_organism{$organism}++;
    }

     
    ### Check organization ###
    my $organization = $item->{biosource}->{organization_id} || '';
    
    # Skip if we've seen it (unless redundant mode)
    if( !$redundant_organization{$organization} || $args{redundant} ) {
    
      # Cache info
      unless ( $args{biosource}->organizationExists($organization)  || $organism eq '' ) {
        push @{$results{organization}}, $organization;
        push @manual, "Line $item_no: Organization $organization does not yet exist\n";
      }
      $redundant_organization{$organization}++;
    }
  }
  # Total number of items seen
  $results{total} = $item_no;
  print STDERR "Saw $results{total} items\n" if $args{verbose}; 

  # Are there any missing things?
  $results{missing} = ( @auto || @manual ) ? 1 : 0;

  # Cache here, this way we get the line numbers...
  $results{auto} = \@auto;
  $results{manual} = \@manual;

  return \%results;
}


sub dumpstuff {
  my $num = shift;
  my $item = shift;
  use Data::Dumper;
  print Dumper( $item );
}

sub processParams {
  my %params;
  GetOptions( \%params, 'file_name=s', 'type=s', 'verbose',
                        'experiment=s', 'autocreate',
                        'test_only', 'group_tag=s' );

  $params{type} ||= 'xls';
  
  if ( !$params{file_name} ) {
    printUsage( "Missing required parameter 'file_name'" );
  } elsif ( $params{type} !~ /^xls$|^tsv$/ ) {
    printUsage( 'Type must be either xls or tsv' );
  } elsif ( !$params{experiment} && !$params{test_only} ) {
    printUsage( "Missing required parameter 'experiment'" ); 
  } elsif ( !$biomarker->checkExperiment( $params{experiment} ) && !$params{test_only} ) {
    printUsage( "Experiment doesn't exist or can't be modified by you" );
  } elsif ( $params{test_only} && $params{autocreate} ) {
    printUsage( "Test only and autocreate are mutually exclusive parameters" );
  }

  $params{verbose} ||= 0;
  $params{autocreate} ||= 0;
  return \%params;
}
sub printUsage {
  my $msg = shift || '';

  $|++;

  print <<"  END_USAGE";
  $msg

  Usage: 
  uploadWorkbook.pl --file_name path/to/file_name/filename.txt

  Arguements:
  -f --file_name     Filename of file_name file to upload
  -g --group_tag     'group' for this file, will show up in database as
                     the name of this collection of samples.
  -t --type          Type of file, either xls or tsv (defaults to xls) 
  -e --experiment    Tag (short name) of experiment in db in which to load data 
  -a --autocreate    autcreate attributes/diseases if they don't already exist 
  -t --test_only     Tests biosource/biosample, experiment, etc. entries, 
                     reports if they don't already exist in the database.

  END_USAGE
  
  exit; 
}

__DATA__

  my %hidx = %{$parser->{_headidx}};
  for my $k ( keys( %hidx ) ){
    my $name;
    ( $name = $file ) =~ s/Sample_progress_file_name.csv//g;
    my $pos = ( length( $hidx{$k} ) == 1 ) ? '0' . $hidx{$k} : $hidx{$k};
