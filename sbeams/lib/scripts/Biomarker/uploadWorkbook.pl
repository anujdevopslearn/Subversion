#!/usr/local/bin/perl -w
#

use FindBin qw($Bin);
use Getopt::Long;

use lib( "$Bin/../../perl" );
use SBEAMS::Connection qw($log);

use Carp;

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
  
  # Silly, don't want next line to exceed 80 chars
  my $v = 'verbose';
  
  # Instantiate new parser
  my $parser = SBEAMS::Biomarker::ParseSampleWorkbook->new($v => $params->{$v});
  
  # Give parser file_name file to chew on
  my $msgs = $parser->parse_file( type => $params->{type},
                                  wbook => $params->{file_name} );

  if ( $params->{verbose} ) {
    for my $msg ( @$msgs ) {
      print "$msg\n";
    }
  }
  
  # Allow parser to chew data into digestable bits
  $parser->process_data();

  my $biosource = SBEAMS::Biomarker::Biosource->new();
  $biosource->setSBEAMS( $sbeams );
  my $biosample = SBEAMS::Biomarker::Biosample->new();
  $biosample->setSBEAMS( $sbeams );

  my $group;

  # Fetch processed file as hash of hashrefs
  my $all_items = $parser->get_processed_items();
  die "No valid objects found" unless $all_items;

  if ( $params->{test_only} ) {
    my $missing = test_data( biosource => $biosource,
                             biosample => $biosample,
                             items     => $all_items,
                             redundant => 0 
                           );

    # Print some info, if warranted
    printMissing( $missing ) if $missing->{true};

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
    for ( @{$missing->{auto}} ) { print $_; }
    print "\n";
  }
  if ( @{$missing->{manual}} ) {
    print <<"    END";

  The following attributes must be added via the web UI before you can can
  upload this dataset. 
  --------------------------------------------------------------------------
    END
    sleep 2;
    for ( @{$missing->{manual}} ) { print $_; }
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

  my $missing = test_data( biosource => $args{biosource},
                           biosample => $args{biosample},
                           items     => $args{items},
                           redundant => 0,
                           verbose   => 1 );

  if ( $missing->{true} ) {
    printMissing( $missing );
    if ( !$args{autocreate} ) {
      print "Unable to proceed, autocreate not set and unfulfilled dependancies found:\n";
      exit;
    } elsif ( @{$missing->{manual}} ) {
      print "Unable to proceed, cannot manually add one or more missing attributes\n";
      exit;
    }

    
  
  # We are going to (try to) do this atomically.

  # cache initial values for these
  my $ac = $sbeams->isAutoCommit();
  my $re = $sbeams->isRaiseError();
    
  $sbeams->initiate_transaction();

  eval {
    $args{biosource}->create_attributes( attr => $missing->{attributes},
                                         auto => 1 );
    $args{biosource}->create_diseases( diseases => $missing->{diseases},
                                       auto => 1 );
    $args{biosource}->create_tissues( tissue => $missing->{tissues} );

       };
       if ( $@ ) {
         print STDERR "$@\n";
         $sbeams->rollback_transaction();
         exit;
       } 
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
  my %missing = ( attributes   => [],
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

      # push into missing array, print message if desired.
      unless ( $args{biosource}->attr_exists($k) ) {
        push @{$missing{attributes}}, $k; 
        push @auto, "Line $item_no: Attribute $k doesn't exist yet\n";
      }
      # record the fact that we've seen it.
      $redundant_attr{$k}++;
    }


    ### Check tissues ###
    for my $k ( keys(%{$item->{tissue_type}}) ) {

      # Skip if we've seen it (unless redundant mode)
      next if $redundant_tissue{$k} && !$args{redundant};

      # push into missing array, print message if desired.
      unless ( $args{biosource}->tissue_exists( $k ) ) { 
        push @{$missing{tissues}}, $k;
        push @auto, "Line $item_no: Tissue $k doesn't exist yet\n";
      }
      # record the fact that we've seen it.
      $redundant_tissue{$k}++;
    }

    
    ### Check Diseases ###
    for my $k ( keys(%{$item->{biosource_disease}}) ) {

      # Skip if we've seen it (unless redundant mode)
      next if $redundant_disease{$k} && !$args{redundant};

      # push into missing array, print message if desired.
      unless ( $args{biosource}->disease_exists( $k ) ) {
        push @{$missing{diseases}}, $k;
        push @auto, "Line $item_no: Disease $k doesn't exist yet\n";
      }
      # record the fact that we've seen it.
      $redundant_disease{$k}++;
    }
     
    ### Check storage_location ###
    my $stor = $item->{biosample}->{storage_location};
    
    # Skip if we've seen it (unless redundant mode)
    next if $redundant_storage_loc{$stor} && !$args{redundant};
    
    # push into missing array, print message if desired.
    unless ( $args{biosample}->storage_loc_exists($stor) ) {
      push @{$missing{storage_loc}}, $stor;
      push @auto, "Line $item_no: Storage location $stor does not yet exist\n";
    }
    $redundant_storage_loc{$stor}++;

     
    ### Check organism ###
    my $organism = $item->{biosource}->{organism};
    
    # Skip if we've seen it (unless redundant mode)
    next if $redundant_organism{$organism} && !$args{redundant};
    
    unless ( $args{biosource}->organism_exists($organism) ) {
      push @{$missing{organism}}, $organism;
      push @manual, "Line $item_no: Organism $organism does not yet exist\n"; 
    }
    $redundant_organism{$organism}++;

     
    ### Check organization ###
    my $organization = $item->{biosource}->{organization};
    
    # Skip if we've seen it (unless redundant mode)
    next if $redundant_organization{$organization} && !$args{redundant};
    
    unless ( $args{biosource}->organization_exists($organization) ) {
      push @{$missing{organization}}, $organization;
      push @manual, "Line $item_no: Organization $organization does not yet exist\n";
    }
    $redundant_organization{$organization}++;
  }

  # Are there any missing things?
  $missing{true} = ( @auto || @manual ) ? 1 : 0;

  # Cache here, this way we get the line numbers...
  $missing{auto} = \@auto;
  $missing{manual} = \@manual;

  return \%missing;
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
