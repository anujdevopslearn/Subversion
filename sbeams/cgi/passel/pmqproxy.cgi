#!/usr/local/bin/perl

use CGI qw(:standard);
require LWP::UserAgent;
my $ua = new LWP::UserAgent;
$ua->timeout(120);

my $query = new CGI;
my $ids  = $query->param(ids);
#my $url = 'http://www.ncbi.nlm.nih.gov//projects/geo/tools/pmqproxy.cgi?'.$ids;
my $url = 'http://www.ncbi.nlm.nih.gov/pubmed/'.$ids;


my $request = new HTTP::Request('GET', $url);
my $response = $ua->request($request);

my $content = $response->content();
print header('application/xml');
print $content;

exit; 
