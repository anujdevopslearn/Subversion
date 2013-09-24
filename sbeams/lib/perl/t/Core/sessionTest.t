#!/usr/local/bin/perl -w

#$Id:  $

use DBI;
use Test::More tests => 8;
use Test::Harness;
use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

$|++; # do not buffer output
my ($sbeams, $key, $value);

use_ok( 'SBEAMS::Connection' );
ok( get_sbeams(), 'Instantiate sbeams object' );
ok( authenticate(), 'Authenticate login' );
ok( set_values(), 'get key/value pair' );
ok( get_cookie(), 'Get session cookie' );
ok( store_key(), 'Set session attribute' );
ok( retrieve_key(), 'Fetch session attribute' );
ok( delete_key(), 'Delete session attribute' );

sub get_sbeams {
  $sbeams = new SBEAMS::Connection;
  return $sbeams;
}

sub authenticate {
  return $sbeams->Authenticate();
}

sub set_values {
  $key = $sbeams->getRandomString();
  $value = $sbeams->getRandomString( num_chars => 2000 );
}

sub get_cookie {
  $sbeams->createSessionCookie( key => $key, value => $value );
}

sub store_key {
  $sbeams->setSessionAttribute( key => $key, value => $value );
}

sub retrieve_key {
  my $newval = $sbeams->getSessionAttribute( key => $key );
  return ( $newval eq $value );
}

sub delete_key {
  $sbeams->deleteSessionAttribute( key => $key );
  my $newval = $sbeams->getSessionAttribute( key => $key );
  if ( $newval ) {
    return 0;
  } else {
    return 1;
  }
}

sub breakdown {
 # Put clean-up code here
}
END {
  breakdown();
} # End END
