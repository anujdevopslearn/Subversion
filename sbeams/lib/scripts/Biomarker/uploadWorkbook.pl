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
  $biomarker->setSBEAMS( $sbeams );

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
  $biosource->setSBEAMS( $sbeams );
  my $biosample = SBEAMS::Biomarker::Biosample->new();
  $biosample->setSBEAMS( $sbeams );

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
               autocreate  => $params->{autocreate} );
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
  for my $arg qw( biosource biosample items autocreate ) {
    die "Missing required parameter $arg" unless defined $args{$arg};
  }

  my $results = test_data( biosource => $args{biosource},
                           biosample => $args{biosample},
                           items     => $args{items},
                           redundant => 0,
                           verbose   => 1 );

  if ( $results->{missing} ) {

    # Missing peripherals, and autocreate isn't set
    if ( !$args{autocreate} ) {
      printMissing( $results );
      print "Unable to proceed, autocreate not set and unfulfilled dependancies found:\n";
      exit;
    }

    # Missing peripherals that we cannot autocreate
    if ( @{$results->{manual}} ) {
      print "Unable to proceed, cannot manually add one or more results attributes\n";
      exit;
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
         $args{biosource}->createTissues( tissue => $results->{tissues} );
         $args{biosample}->createStorageLoc( strg_loc => $results->{storage_loc} );

         my $name =   'upload-' . $sbeams->get_datetime();
         print "Yabba dabba doo\n";

         my $grp_id = $biomarker->create_biogroup( group_name  => $name,
                                                   description => "Dataset uploaded via $0",
                                                   type        => 'import' );

         # Next, iterate through lines and add src/samples, join records.
         foreach my $item ( @{$args{items}} ) {

           # Add biosource record
           my $src_id = $args{biosource}->addNew( data_ref => $item->{biosource},
                                                  group_id => $grp_id );

           # Biosource related
           $args{biosource}->addBiosourceAttrs(  attrs => $item->{biosource_attr},
                                                src_id => $src_id );
           $args{biosource}->addBiosourceDiseases(  diseases => $item->{biosource_disease},
                                                src_id => $src_id );


           # Add biosample record
           my $smpl_id = $args{biosample}->addNew(  data_ref => $item->{biosample},
                                                    group_id => $grp_id,
                                                   source_id => $src_id );
           # Biosample related
           $args{biosample}->addBiosampleAttrs(  attrs => $item->{biosample_attr},
                                                src_id => $src_id );
         }
       };
       if ( $@ ) {
         print STDERR "$@\n";
         $sbeams->rollback_transaction();
         exit;
       } 
  $sbeams->rollback_transaction();
  $sbeams->commit_transaction();
  $sbeams->setAutoCommit( $ac );
  $sbeams->setRaiseError( $re );
  }
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
  my %redundant_tissue;
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


    ### Check tissues ###
    for my $k ( keys(%{$item->{tissue_type}}) ) {

      # Skip if we've seen it (unless redundant mode)
      next if $redundant_tissue{$k} && !$args{redundant};

      # push into missing tissues array, print message if desired.
      unless ( $args{biosource}->tissueExists( $k ) ) { 
        push @{$results{tissues}}, $k;
        push @auto, "Line $item_no: Tissue $k doesn't exist yet\n";
      }
      # record the fact that we've seen it.
      $redundant_tissue{$k}++;
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
    my $stor = $item->{biosample}->{storage_location};
    
    # Skip if we've seen it (unless redundant mode)
    next if $redundant_storage_loc{$stor} && !$args{redundant};
    
    # push into missing storage_loc array, print message if desired.
    unless ( $args{biosample}->storageLocExists($stor) ) {
      push @{$results{storage_loc}}, $stor;
      push @auto, "Line $item_no: Storage location $stor does not yet exist\n";
    }
    $redundant_storage_loc{$stor}++;

     
    ### Check organism ###
    my $organism = $item->{biosource}->{organism};
    
    # Skip if we've seen it (unless redundant mode)
    next if $redundant_organism{$organism} && !$args{redundant};
    
    # Cache info
    unless ( $args{biosource}->organismExists($organism) ) {
      push @{$results{organism}}, $organism;
      push @manual, "Line $item_no: Organism $organism does not yet exist\n"; 
    }
    $redundant_organism{$organism}++;

     
    ### Check organization ###
    my $organization = $item->{biosource}->{organization};
    
    # Skip if we've seen it (unless redundant mode)
    next if $redundant_organization{$organization} && !$args{redundant};
    
    # Cache info
    unless ( $args{biosource}->organizationExists($organization) ) {
      push @{$results{organization}}, $organization;
      push @manual, "Line $item_no: Organization $organization does not yet exist\n";
    }
    $redundant_organization{$organization}++;
  }
  # Total number of items seen
  $results{total} = $item_no;

  # Are there any missing things?
  $results{missing} = ( @auto || @manual ) ? 1 : 0;

  # Cache here, this way we get the line numbers...
  $results{auto} = \@auto;
  $results{manual} = \@manual;

  return \%results;
}


sub processParams {
  my %params;
  GetOptions( \%params, 'file_name=s', 'type=s', 'verbose',
                        'experiment=s', 'autocreate',
                        'test_only');

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
  -t --type          Type of file, either xls or tsv (defaults to xls) 
  -e --experiment    Name of experiment in database in which to load data 
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
