#!/usr/local/bin/perl -w

## Includes ##
use strict;
use Test::More tests => 12;
use HTTP::Request::Common;
use HTTP::Cookies;
use LWP::UserAgent;

#use lib '/net/dblocal/www/html/devDC/sbeams/lib/perl';
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

## Constants ##
use constant BASE_URL => 'http://db.systemsbiology.net/devDC/sbeams';
use constant USERNAME => 'cytoscape';
use constant PASSWORD => 'cytoscape';

## Globals ##
my ( $sbeams, $q, $ua, $url );
my %auth = ( username => USERNAME, password => PASSWORD, login => 'yes' );

BEGIN {
  print "Set up test\n";
  use_ok( 'CGI' );
  use_ok( 'SBEAMS::Connection' );
  use_ok( 'SBEAMS::Connection::Settings' );
  use_ok( 'SBEAMS::Connection::Tables' );
  use_ok( 'SBEAMS::Connection::TableInfo' );
  use_ok( 'HTTP::Request::Common' );
  use_ok( 'LWP::UserAgent' );
  $q = new CGI;
  
  # Insert user of known permissions
  $ua = LWP::UserAgent->new();
  $url = BASE_URL . '/cgi/ManageTable.cgi';
  
  $ua->cookie_jar( HTTP::Cookies->new( file => '/tmp/lwpcookies.txt', autosave => 1 ) );
  
  my $response = $ua->post( $url , \%auth );
  } # End BEGIN
  
END {
  print "Clean up\n";
  system( 'rm /tmp/lwpcookies.txt' );
} # End END


ok( check_cookie(), 'valid sbeams cookie' );
ok( sbeams_connect(), 'sbeams connection' );
ok( sbeams_authenticate(), 'sbeams authenticate' );
ok( check_authentication_info(), 'sbeams login info' );
ok( sbeams_get_best_permission(), 'sbeams permissions' );

sub check_cookie {
  my $response = $ua->post( BASE_URL . '/cgi/main.cgi' , \%auth );
  my $content = $response->content();
  (my $name) = $content =~ /Login:.*<B>(\w+)<\/B>.*/m;
  return ( $name =~ /cytoscape/ ) ? 1 : 0; 
}

sub sbeams_connect {
  $sbeams = new SBEAMS::Connection;
}

sub sbeams_authenticate {
  $sbeams->Authenticate();
}

sub check_authentication_info {
print STDERR "\tCurrent contact ID is " . $sbeams->getCurrent_contact_id() . "\n";
print STDERR "\tCurrent username ID is " . $sbeams->getCurrent_username() . "\n";
print STDERR "\tCurrent work group ID is " . $sbeams->getCurrent_work_group_id() . "\n";
print STDERR "\tCurrent work group is " . $sbeams->getCurrent_work_group_name() . "\n";
print STDERR "\tCurrent project is " . $sbeams->getCurrent_project_name() . "\n";
print STDERR "\tCurrent project ID is " . $sbeams->getCurrent_project_id() . "\n";
1;
}

sub sbeams_get_best_permission {
  my $p = $sbeams->get_best_permission();
  print "\tBest permission is $p\n";
  return $p;
}


