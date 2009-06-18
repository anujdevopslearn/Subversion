#!/usr/local/bin/perl -w

use strict;
use Storable qw(nstore retrieve);
use Test::More tests => 4;
use Test::Harness;

ok( store_array(), 'Store array');
ok( retrieve_array(), 'Retrieve array');
ok( store_hash(), 'Store hash');
ok( retrieve_hash(), 'Retrieve hash');

sub store_array {
  my @array = ( 'PeptideAtlas_atlas_build_id', 123 );
  nstore(\@array, '/tmp/array.sto') || return 0;
}

sub store_hash {
  my %hash = ( PeptideAtlas_atlas_build_id => 123 );
  nstore(\%hash, '/tmp/hash.sto') || return 0;

}

sub retrieve_array {
  my $arrayref = retrieve("/tmp/array.sto") || return 0;
  my $ok = $arrayref->[0];
  return $ok
}

sub retrieve_hash {
  my $hashref = retrieve("/tmp/hash.sto") || return 0;
  my $ok = 0;
  for my $k ( keys( %$hashref ) ) {
    $ok = $k;
  }
  return $ok
}

              
