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
  my $foobar;
  print $foobar;
  
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

  my $all_items = $parser->get_processed_items();
  die "No valid objects found" unless $all_items;

  if ( $params->{test_only} ) {
    test_data( biosource => $biosource,
               biosample => $biosample,
               items     => $all_items,
               redundant => 0,
               verbose   => 1 );
  } else {
    add_items( biosource => $biosource,
               biosample => $biosample,
               items     => $all_items,
               autocreate  => $params->{autocreate} );
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
  $args{ autocreate} ||= 0;

  my $missing = test_data( biosource => $args{biosource},
                           biosample => $args{biosample},
                           items     => $args{items},
                           redundant => 0,
                           verbose   => 1 );
  my $msg = '';
  if ( $missing->{attributes} ) {
    for ( @{$missing->{attributes}} ) {
      $msg .= "Missing attribute: $_ \n";
    }
  } elsif ( $missing->{diseases} ) {
    for ( @{$missing->{diseases}} ) {
      $msg .= "Missing disease: $_ \n";
    }
  } elsif ( $missing->{tissues} ) {
    for ( @{$missing->{tissues}} ) {
      $msg .= "Missing tissue: $_ \n";
    }
  }

  
  if ( !$args{autocreate} ) {
    print "Unable to proceed, autocreate not set and unfulfilled dependancies found:\n";
    print "$msg\n";
    exit;
  } else { # We are allowed to make new stuff as needed!
  
    # We are going to (try to) do this atomically.

     # cache initial values for these
    my $ac = $sbeams->isAutoCommit();
    my $re = $sbeams->isRaiseError();
    
    $sbeams->initiate_transaction();

    eval {
      $args{biosource}->create_attributes( attr => $missing->{attributes},
                                           auto => 1 
                                         );
      $args{biosource}->create_diseases( diseases => $missing->{diseases},
                                         auto => 1 
                                         );
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

  my $item_no = 0;
  for my $item ( @{$args{items}} ){
    $item_no++;

    for my $k ( keys(%{$item->{biosource_attr}}) ) {
      my $res = $args{biosource}->attr_exists( $k );
      if ( !$res && $args{verbose} ) {
        push @{$missing->{attributes}}, $k;
      }
    }

    for my $k ( keys(%{$item->{tissue_type}}) ) {
      my $res = $args{biosource}->tissue_exists( $k );
      if ( !$res && $args{verbose} ) {
        push @{$missing->{tissues}}, $k;
      }
    }

    for my $k ( keys(%{$item->{disease}}) ) {
      my $res = $args{biosource}->disease_exists( $k );
      if ( !$res && $args{verbose} ) {
        push @{$missing->{diseases}}, $k;
      }
    }

    for my $k ( keys(%{$item->{biosample_attr}}) ) {
      my $res = $args{biosample}->attr_exists( $k );
      if ( !$res && $args{verbose} ) {
        push @{$missing->{attributes}}, $k;
      }
    }
  }
#      $biosource->add_new( biosource => $item->{biosource},
#                           biosource_attr => $item->{biosource_attr},
#                           tissue_type => $item->{tissue_type},
#                          disease => $item->{disease},
#                          disease_stage => $item->{disease_stage}
#                         );

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

  my %redundant_attr;
  my %redundant_tissue;
  my %redundant_disease;

  my %missing = ( attributes => [],
                  tissues    => [],
                  diseases   => [] );

  my $item_no = 0;
  for my $item ( @{$args{items}} ){
    $item_no++;

    for my $k ( keys(%{$item->{biosource_attr}}) ) {
      unless ( $args{redundant} ) {
        next if $redundant_attr{$k};
        $redundant_attr{$k}++;
      }
      my $res = $args{biosource}->attr_exists( $k );
      if ( !$res && $args{verbose} ) {
        push @{$missing{attributes}}, $k;
        print "Line $item_no: Source Attribute $k does not yet exist\n"
      }
    }


    for my $k ( keys(%{$item->{tissue_type}}) ) {
      unless ( $args{redundant} ) {
        next if $redundant_tissue{$k};
        $redundant_tissue{$k}++;
      }
      my $res = $args{biosource}->tissue_exists( $k );
      if ( !$res && $args{verbose} ) {
        push @{$missing{tissues}}, $k;
        print "Line $item_no: Tissue type $k does not yet exist\n";
      }
    }


    for my $k ( keys(%{$item->{biosource_disease}}) ) {
      unless ( $args{redundant} ) {
        next if $redundant_disease{$k};
        $redundant_disease{$k}++;
      }
      my $res = $args{biosource}->disease_exists( $k );
      if ( !$res && $args{verbose} ) {
        push @{$missing{diseases}}, $k;
        print "Line $item_no: Disease $k does not yet exist\n";
      }
    }


    for my $k ( keys(%{$item->{biosample_attr}}) ) {
      unless ( $args{redundant} ) {
        next if $redundant_attr{$k};
        $redundant_attr{$k}++;
      }
      my $res = $args{biosample}->attr_exists( $k );
      if ( !$res && $args{verbose} ) {
        push @{$missing{attributes}}, $k;
        print "Line $item_no: Sample Attribute $k does not yet exist\n"
      }
    }
  }

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
