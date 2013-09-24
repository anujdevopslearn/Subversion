#!/usr/local/bin/perl -w

#$Id:  $

use DBI;
use Test::More tests => 9;
use Test::Harness;
use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

$|++; # do not buffer output
my ($sbeams, $key, $value, $km, @orgs );
my $msg;
my $genes;

use_ok( 'SBEAMS::Connection' );
use_ok( 'SBEAMS::BioLink::KGMLParser' );
use_ok( 'SBEAMS::BioLink::KeggMaps' );
ok( get_sbeams(), 'Instantiate sbeams object' );
ok( $km = SBEAMS::BioLink::KeggMaps->new(), 'Instantiate keggmaps object' );
ok( authenticate(), 'Authenticate login' );
ok( get_organisms(), "Fetch supported organisms" );
$genes = get_genes_for_pathway();

SKIP: {
        skip "FIXME!", 2;
ok( ref($genes) eq 'ARRAY' && $#{$genes} >= 0,  "Fetch pathway genes" );
my $gene_info = $km->getGeneInfo( genes => $genes );
ok( ref($gene_info) eq 'ARRAY', "Fetch gene expression info" );

      }


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

sub get_genes_for_pathway {
  my $pathway = 'path:hsa00052';
  my $genes =  $km->getPathwayGenes( pathway => $pathway, 
                                      source => 'kegg',
                                    not_keys => 1 );
  return $genes;
}


sub breakdown {
 # Put clean-up code here
}
END {
  breakdown();
} # End END
