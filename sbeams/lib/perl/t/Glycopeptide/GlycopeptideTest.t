#!/usr/local/bin/perl -w

#$Id: transactionTest.t 4669 2006-04-15 00:23:58Z dcampbel $

use DBI;
use Test::More tests => 3;
use Test::Harness;
use strict;

use FindBin qw($Bin);
use lib( "$Bin/../.." );
use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
my $sbeams = SBEAMS::Connection->new();

sub setup { 
}
BEGIN { setup() }

# 
use_ok( 'SBEAMS::Glycopeptide' );
ok ( my $glyco = SBEAMS::Glycopeptide->new(), "Instantiate glyco" );

# comment out to troubleshoot
# close(STDERR);

$|++; # unbuffer output

# Check tryptic digestion
ok( test_tryptic_digestion(), 'Testing digestion' );

sub test_tryptic_digestion {
  my @peps = ( '-.R.A', 'R.AAKPAARPAAK.B', 'K.BBBBBR.C', 'R.CCCCCK.-' );
  my $seq = 'RAAKPAARPAAKBBBBBRCCCCCK';
  my $peps = $glyco->do_tryptic_digestion( aa_seq => $seq, 
                                           flanking => 1   );
  my $test = 1;
  for ( my $i = 0; $i <= $#{$peps}; $i++ ) {
    $test = 0 unless $peps[$i] eq $peps->[$i];
  }

  @peps = ( '-.AAAAAAK.B', 'K.BBBBB.-' );
  $seq = 'AAAAAAKBBBBB';
  $peps = $glyco->do_tryptic_digestion( aa_seq => $seq, 
                                           flanking => 1   );
  for ( my $i = 0; $i <= $#{$peps}; $i++ ) {
    $test = 0 unless $peps[$i] eq $peps->[$i];
  }

  return $test;
}

END {
  breakdown();
} # End END

sub breakdown { 
}

