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
  my $msgs = $parser->parse_file( type => $params->{type},
                                  wbook => $params->{workbook} );

  if ( $params->{verbose} ) {
    for my $msg ( @$msgs ) {
      print "$msg\n";
    }
  }
  
  # Allow parser to chew data into digestable bits
  $parser->process_data();
  
  sub processParams {
    my %params;
    GetOptions( \%params, "workbook=s", "type=s", "verbose" );

    $params{type} ||= 'xls';
  
    unless( $params{workbook} ) {
      printUsage( "Missing required parameter 'workbook'" );
    }

    unless ( $params{type} =~ /^xls$|^tsv$/ ) {
      printUsage( 'Type must be either xls or tsv' );
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
  -w --workbook      Filename of workbook file to upload
  -t --type          Type of file, either xls or tsv (defaults to xls) 

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
