#!/usr/local/bin/perl -w

#$Id:  $

use DBI;
use Test::More tests => 7;
use Test::Harness;
use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

$|++; # do not buffer output
my ($sbeams, $key, $value, $km, @orgs );
my $msg;

use_ok( 'SBEAMS::Connection' );
use_ok( 'SBEAMS::BioLink::KGMLParser' );
use_ok( 'SBEAMS::BioLink::KeggMaps' );
ok( get_sbeams(), 'Instantiate sbeams object' );
ok( $km = SBEAMS::BioLink::KeggMaps->new(), 'Instantiate keggmaps object' );
ok( authenticate(), 'Authenticate login' );
ok( get_organisms(), "Fetch supported organisms" );


sub getParser {
#  $parser = SBEAMS::BioLink::KGMLParser->new();
#  return $parser;
}


sub get_sbeams {
  $sbeams = new SBEAMS::Connection;
  return $sbeams;
}

sub parse {
#  return $parser->parse();
}

sub authenticate {
  return $sbeams->Authenticate();
}

sub get_organisms {
  my $orgs = $km->getSupportedOrganisms();
  @orgs = @{$orgs};
  return scalar @orgs;
}


sub breakdown {
 # Put clean-up code here
}
END {
  breakdown();
} # End END
