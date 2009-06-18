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

use Test::More tests => 6;
use Test::Harness;

use POSIX;

my $aname = POSIX::tmpnam();
ok( store_array(), 'Store array');
ok( retrieve_array(), 'Retrieve array');

my $hname = POSIX::tmpnam( );
ok( store_hash(), 'Store hash');
ok( retrieve_hash(), 'Retrieve hash');

my $rname = POSIX::tmpnam( );
ok( retrieve_rs(), 'Retrieve resultset');
ok( retrieve_DATA_rs(), 'Retrieve DATA resultset');

sub store_array {
  my @array = ( 'PeptideAtlas_atlas_build_id', 123 );
  nstore(\@array, $aname ) || return 0;
}

sub store_hash {
  my %hash = ( PeptideAtlas_atlas_build_id => 123 );
  nstore(\%hash, $hname ) || return 0;
}

sub retrieve_array {
  my $arrayref = retrieve( $aname ) || return 0;
  my $ok = $arrayref->[0];
  return $ok
}

sub retrieve_hash {
  my $hashref = retrieve( $hname ) || return 0;
  my $ok = 0;
  for my $k ( keys( %$hashref ) ) {
    $ok = $k;
  }
  return $ok
}

sub retrieve_DATA_rs {
  open( RS, ">$rname" );

  while( my $rs = <DATA> ) {
    print RS $rs;
	}
  close RS;

  my $hashref = eval {retrieve( $rname )} || return 0;
  my $ok = 0;
  for my $k ( keys( %$hashref ) ) {
    $ok = $k;
  }
  return $ok
}

sub retrieve_rs {
  my $hashref = retrieve( 'test.sto' ) || return 0;
  my $ok = 0;
  for my $k ( keys( %$hashref ) ) {
    $ok = $k;
  }
  return $ok
}

__DATA__
pst0^D^F^D1234^D^D^D^H^C^H^@^@^@^D^B^E^@^@^@
^Cint
^B12
^B12
^B12
^B12^N^@^@^@types_list_ref^H<80>^K^@^@^@row_counter^D^B^E^@^@^@

project_id
^Kproject_tag
^Dname
^Husername
^Kdescription^O^@^@^@column_list_ref^H<80>^K^@^@^@row_pointer^D^C^E^@^@^@^H<81>^K^@^@^@project_tag^H<82>^D^@^@^@name^H<84>^K^@^@^@description^H<83>^H^@^@^@username^H<80>
^@^@^@project_id^O^@^@^@column_hash_ref^Hä  ^@^@^@page_size^D^B^E^@^@^@^H<8b>^H²^Hä^Hï^Hä^S^@^@^@precisions_list_ref^D^B^@^@^@^@^H^@^@^@data_ref
