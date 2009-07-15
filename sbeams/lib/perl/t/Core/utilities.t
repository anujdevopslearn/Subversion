#!/usr/local/bin/perl -w

#$Id:  $

use DBI;
use Test::More tests => 5;
use Test::Harness;
use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

$|++; # do not buffer output
my ($sbeams, $key, $value);

use_ok( 'SBEAMS::Connection' );
ok( get_sbeams(), 'Instantiate sbeams object' );
ok( authenticate(), 'Authenticate login' );
ok( format_number(), 'Format number test' );
ok( read_fasta(), 'read fasta file test' );

sub get_sbeams {
  $sbeams = new SBEAMS::Connection;
  return $sbeams;
}

sub authenticate {
  return $sbeams->Authenticate();
}

sub format_number {
	my $input = 123456789;
	my $formatted = $sbeams->formatScientific( output_mode => 'text',
	                                            precision => 1,
                                              number => $input
																						);
	return ( $formatted eq '1.2E8' ) ? 1 : 0;
}

sub read_fasta {
  my $file = "/tmp/.util.test.fasta";
  open ( FAS, ">$file" ) || return 0;
  my $fasta = qq~
>IPI000001
ATGATGGAHAKSGJKAGHAKGJOADFJASASDJOFASJDFOASJFDOASFDJOASJDFQWOCM
AOSJDFOASJDFMOASMDFAOSDFMOASMDFOASMDFOASMFDOASMDFOASMDFOAMSDOFM
AISDFASJDFASJDF
>IPI000002 This is one kicking protein
AOSJDFOASJDFMOASMDFAOSDFMOASMDFOASMDFOASMFDOASMDFOASMDFOAMSDOFM
ATGATGGAHAKSGJKAGHAKGJOADFJASASDJOFASJDFOASJFDOASFDJOASJDFQWOCM
AOSJDFOASJDFMOASMDFAOSDFMOASMDFOASMDFOASMFDOASMDFOASMDFOAMSDOFM
>IPI000003 This is one kicking protein
AOSJDFOASJDFMOASMDFAOSDFMOASMDFOASMDFOASMFDOASMDFOASMDFOAMSDOFM
ATGATGGAHAKSGJKAGHAKGJOADFJASASDJOFASJDFOASJFDOASFDJOASJDFQWOCM
AOSJDFOASJDFMOASMDFAOSDFMOASMDFOASMDFOASMFDOASMDFOASMDFOAMSDOFM
~;
print FAS $fasta;
close FAS;
my $fsa = $sbeams->read_fasta_file( filename => $file,
                                    acc_regex => '^>(IPI\d+)',
                                    verbose => 0 );
#print STDERR join( "\t", keys( %$fsa ) ) . "\n";

unlink( $file );
return 1;
}

sub delete_key {
  $sbeams->deleteSessionAttribute( key => $key );
  my $newval = $sbeams->getSessionAttribute( key => $key );
  return ( !defined $newval );
}

sub breakdown {
 # Put clean-up code here
}
END {
  breakdown();
} # End END
