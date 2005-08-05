#!/usr/local/bin/perl -w
#


use lib( "../../perl" );
use SBEAMS::Biomarker::ParseSampleWorkbook;

my $parser = SBEAMS::Biomarker::ParseSampleWorkbook->new();
for my $file ( @ARGV ) {
  $parser->parse_file( wbook => $file );
}

