#!/usr/local/bin/perl -w

#$Id$

use strict;
use Test::More tests => 7;
#use lib '/net/dblocal/www/html/devDC/sbeams/lib/perl';
#use lib '/net/dblocal/www/html/sbeams/lib/perl';
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

# Need to provide username/password for registered user on target system.
use constant BASE_URL => 'http://db.systemsbiology.net/devDC/sbeams';
#use constant BASE_URL => 'http://db.systemsbiology.net/sbeams';
use constant USERNAME => 'guest';
use constant PASSWORD => 'gessst!';

use CGI;
use SBEAMS::Connection qw( $log $q );
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Client;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::UserAgent;
use Crypt::CBC;

# Global fun!
my ( $ua, $sbeams, $q, $sbeams_client );
my %auth = ( username => USERNAME, password => PASSWORD, login => 'yes' );

# Set up user agent and sbeams objects
ok( sbeams_connect(), 'sbeams connection' );
ok( store_cookie(), 'authenticated and stored cookies' );
ok( test_cached_cookie(), 'Use user agent cached cookie' );
ok( test_force_login(), 'Checking forced login with existing cookie' );
ok( test_force_with_auth(), 'Checking forced login without cookie' );
ok( load_cookie(), 'Reauthenticate with cookie stored on disk' );
ok( test_cached_cookie(), 'Testing loaded cookie' );

#+
# create sbeams object
#-
sub sbeams_connect {
  $sbeams = new SBEAMS::Connection;
}

#+
# Does site require auth even if valid cookie included
#-
sub test_force_login {
  my $response = $ua->get( BASE_URL . '/cgi/main.cgi?force_login=yes' );
  return ( $response->content() =~ /INPUT TYPE.*password.*NAME.*password/ ) ? 1 : 0; 
}

#+
# Show that cookie that useragent has cached works
#-
sub test_cached_cookie {
  my $response = $ua->get( BASE_URL . '/cgi/main.cgi' );
  return ( $response->content() =~ /INPUT TYPE.*password.*NAME.*password/ ) ? 0 : 1; 
}

#+
# Does force login rule even if authen credentials are passed?
#-
sub test_force_with_auth {
  my $agent = LWP::UserAgent->new( );
  my $response = $agent->post( BASE_URL . '/cgi/main.cgi?force_login=yes', {%auth, force_login => 'yes' } );
  return ( $response->content() =~ /INPUT TYPE.*password.*NAME.*password/ ) ? 1 : 0; 
}

#+
# create sbeams object
#-
sub load_cookie {
  $ua = LWP::UserAgent->new( );
  my $cookieJar = HTTP::Cookies->new();
  $ua->cookie_jar( $cookieJar );
  $ua->cookie_jar()->load( '/tmp/lwpcookies.txt' );
  my $response = $ua->get( BASE_URL . '/cgi/main.cgi' );
  return ( $response->content() =~ /INPUT TYPE.*password.*NAME.*password/ ) ? 0 : 1; 
}

#+
# Create useragent, fetch and cache cookie
#-
sub store_cookie {
  $ua = LWP::UserAgent->new( );
  my $time = time();
  $ua->cookie_jar( HTTP::Cookies->new( file     => '/tmp/lwpcookies.txt', 
                                       autosave => 0, 
                                       ignore_discard => 1 ) );
  my $response = $ua->post( BASE_URL . '/cgi/main.cgi' , \%auth );
  $ua->cookie_jar()->save( '/tmp/lwpcookies.txt' );
  return ( $ua->cookie_jar() ) ? 1 : 0;
} 

END {
  breakdown();
} # End END

sub breakdown {
  system( 'rm /tmp/lwpcookies.txt' );
}


