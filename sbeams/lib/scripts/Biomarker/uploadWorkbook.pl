#!/usr/local/bin/perl -w
#

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
my $biomarker = SBEAMS::Biomarker->new();

# Main
{
  $sbeams->Authenticate();
  $biomarker->setSBEAMS( $sbeams );

  my $params = processParams();
  
  # Instantiate new parser
  my $parser = SBEAMS::Biomarker::ParseSampleWorkbook->new();
  
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
               items     => $all_items );
  } else {
    add_items( biosource => $biosource,
               biosample => $biosample,
               items     => $all_items );
  }

}
  

sub test_data {
  my %args = @_;
  for my $arg qw( biosource biosample items ) {
    die "Missing required parameter $arg" unless defined $args{$arg};
  }
  my $item_no = 0;
  for my $item ( @{$args{items}} ){
    $item_no++;

    for my $k ( keys(%{$item->{biosource_attr}}) ) {
      my $res = $args{biosource}->attr_exists( $k );
      print "Line $item_no: Source Attribute $k does not yet exist\n" unless $res;
    }
    for my $k ( keys(%{$item->{tissue_type}}) ) {
      my $res = $args{biosource}->tissue_exists( $k );
      print "Line $item_no: Tissue type $k does not yet exist\n" unless $res;
    }
    for my $k ( keys(%{$item->{disease}}) ) {
      my $res = $args{biosource}->disease_exists( $k );
      print "Line $item_no: Disease $k does not yet exist\n" unless $res;
    }
    for my $k ( keys(%{$item->{biosample_attr}}) ) {
      my $res = $args{biosample}->attr_exists( $k );
      print "Line $item_no: Sample Attribute $k does not yet exist\n" unless $res;
    }
  }
}



sub add_items {
#      $biosource->add_new( biosource => $item->{biosource},
#                           biosource_attr => $item->{biosource_attr},
#                           tissue_type => $item->{tissue_type},
#                          disease => $item->{disease},
#                          disease_stage => $item->{disease_stage}
#                         );
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
  -w --file_name      Filename of file_name file to upload
  -t --type          Type of file, either xls or tsv (defaults to xls) 
  -e --experiment    Name of experiment in database in which to load data 
  -a --autocreate    autcreate attributes/diseases if they don't already exist 

  END_USAGE
  
  exit; 
}

__DATA__

  my %hidx = %{$parser->{_headidx}};
  for my $k ( keys( %hidx ) ){
    my $name;
    ( $name = $file ) =~ s/Sample_progress_file_name.csv//g;
    my $pos = ( length( $hidx{$k} ) == 1 ) ? '0' . $hidx{$k} : $hidx{$k};
