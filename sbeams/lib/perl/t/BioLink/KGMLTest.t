#!/usr/local/bin/perl -w

#$Id:  $

use DBI;
use Test::More tests => 8;
use Test::Harness;
use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

my $path = '00010';
my $org = 'hsa';
my $base = "http://www.genome.jp/kegg/KGML/KGML_v0.6.1/$org/";


my $url = $base . $org . $path . ".xml";
#my $url = $base . "map" . $path . ".xml";
my $parser;
my $content;

$|++; # do not buffer output
my ($sbeams, $key, $value);
my $msg;

use_ok( 'SBEAMS::Connection' );
use_ok( 'SBEAMS::BioLink::KGMLParser' );
ok( get_sbeams(), 'Instantiate sbeams object' );
ok( authenticate(), 'Authenticate login' );
ok( getParser(), "Instantiate parser" );
ok( fetchURL(), "Fetch URL" );
ok( parse(), "Parse XML" );
SKIP: {
        skip "FIXME!", 1;
ok( $msg = viewEntries(), "Check for XML entries $msg" );
      }


sub getParser {
  $parser = SBEAMS::BioLink::KGMLParser->new();
  return $parser;
}

sub fetchURL {
  $parser->set_url( url => $url );
  return $parser->fetch_url();
}

sub get_sbeams {
  $sbeams = new SBEAMS::Connection;
  return $sbeams;
}

sub parse {
  return $parser->parse();
}

sub authenticate {
  return $sbeams->Authenticate();
}

sub viewEntries {
  my @entries = @{$parser->{_entries}};
  my $attr_cnt = 0;
  my $entry_cnt = 0;
  for my $entry ( @entries ) {
    $entry_cnt++;
    for my $k ( keys( %{$entry} ) ) {
#      print "$k => $entry->{$k}\n";
      $attr_cnt++;
    }
  }
  return ( $entry_cnt ) ? "($attr_cnt attrs in $entry_cnt entries)" : 0;
}


sub breakdown {
 # Put clean-up code here
}
END {
  breakdown();
} # End END
