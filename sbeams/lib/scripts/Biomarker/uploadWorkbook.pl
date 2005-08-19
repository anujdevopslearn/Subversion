#!/usr/local/bin/perl -w
#

use FindBin qw($Bin);
use Getopt::Long;

use lib( "$Bin/../../perl" );
use SBEAMS::Biomarker::ParseSampleWorkbook;

use strict;

# Main
{
  my $params = processParams();
  
  # Instantiate new parser
  my $parser = SBEAMS::Biomarker::ParseSampleWorkbook->new();
  
  # Give parser workbook file to chew on
  $parser->parse_file( wbook => $params->{workbook} );
  
  # Allow parser to chew data into digestable bits
  $parser->process_data();
  
  sub processParams {
    my %params;
    GetOptions( \%params, "workbook=s" );
  
    unless( $params{workbook} ) {
      printUsage( "Missing required parameter 'workbook'" );
    }
    return \%params;
  }
}

sub printUsage {
  my $msg = shift || '';

  $|++;

  print <<"  END_USAGE";
  $msg

  Usage: 
  uploadWorkbook.pl --workbook path/to/workbook/filename.txt

  Arguements:
  -w --workbook      Filename of workbook file (tsv) to upload

  END_USAGE
  
  exit; 
}

__DATA__

  my %hidx = %{$parser->{_headidx}};
  for my $k ( keys( %hidx ) ){
    my $name;
    ( $name = $file ) =~ s/Sample_progress_workbook.csv//g;
    my $pos = ( length( $hidx{$k} ) == 1 ) ? '0' . $hidx{$k} : $hidx{$k};
  }
