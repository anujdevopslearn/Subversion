#!/tools32/bin/perl -w
#!/usr/local/bin/perl -w
BEGIN {
unshift @INC, qw( /net/db/src/SSRCalc/ssrcalc .  /tools32/lib/perl5/5.8.0/i386-linux-thread-multi /tools32/lib/perl5/5.8.0 /tools32/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi /tools32/lib/perl5/site_perl/5.8.0 /tools32/lib/perl5/site_perl  );

}

use strict;
use lib '/tools32/lib/perl5/5.8.0/i386-linux-thread-multi';
use lib '/tools32/lib/perl5/5.8.0/i386-linux-thread-multi/CORE';
use lib '/tools32/lib/perl5/5.8.0';
use lib '/tools32/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi';
use lib '/tools32/lib/perl5/site_perl/5.8.0';
use lib '/tools32/lib/perl5/site_perl';

use Storable qw(nstore retrieve);

use Test::More tests => 4;
use Test::Harness;

ok( store_array(), 'Store array');
ok( retrieve_array(), 'Retrieve array');
ok( store_hash(), 'Store hash');
ok( retrieve_hash(), 'Retrieve hash');

sub store_array {
  my @array = ( 'PeptideAtlas_atlas_build_id', 123 );
  nstore(\@array, 'array.sto') || return 0;
}

sub store_hash {
  my %hash = ( PeptideAtlas_atlas_build_id => 123 );
  nstore(\%hash, 'hash.sto') || return 0;

}

sub retrieve_array {
  my $arrayref = retrieve("array.sto") || return 0;
  my $ok = $arrayref->[0];
  return $ok
}

sub retrieve_hash {
  my $hashref = retrieve("hash.sto") || return 0;
  my $ok = 0;
  for my $k ( keys( %$hashref ) ) {
    $ok = $k;
  }
  return $ok
}


