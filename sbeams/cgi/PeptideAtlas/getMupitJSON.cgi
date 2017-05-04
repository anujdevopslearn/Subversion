#!/usr/local/bin/perl

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use LWP;
use URI;
use Data::Dumper;

my $q = new CGI;
print $q->header( -type => 'application/json',
               -charset => 'utf-8',
			          );
my $prot = $q->param('prot');
my $off = $q->param('offset');

my $uri = URI->new(  'http://karchin-web02.icm.jhu.edu/MuPIT_Interactive/rest/showstructure/check' );
$uri->query_form( 'pos' => $prot . ':' . $off, protquery => 'y' );

my $ua = LWP::UserAgent->new();
my $response = $ua->get( "$uri" );

if ( $response->is_success() ) {
  print $response->content();
} else {
  print '{"hit":true,"status":"normal"}';
}

exit;
