#!/usr/local/bin/perl -w

#$Id:  $

use DBI;
use Test::More tests => 7;
use Test::Harness;
use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

# Globals
my $sbeams;
my $atlas;

use_ok( 'SBEAMS::Connection' );
use_ok( 'SBEAMS::PeptideAtlas' );
ok( get_sbeams(), 'Instantiate sbeams object' );
ok( get_atlas(), 'Instantiate peptide atlas object' );
ok( authenticate(), 'Authenticate login' );
like( get_file( touch => 1, file => '' ), qr/\/tmp\/interact.xml/, 'Fetch filename without preferred' );

like( get_file( touch => 1, file => 'interact-combined.iproph.pep.xml', preferred => ['interact-combined.iproph.pep.xml'] ), 
              qr/\/tmp\/interact-combined.iproph.pep.xml/,
             'Fetch filename with preferred' );

sub get_file {
	my %args = @_;
	$args{file} ||= 'interact.xml';
	$args{preferred} ||= [];
	if ( $args{touch} ) {
		open( FIL, ">/tmp/$args{file}" ) || die( "unable to open file!" );
		close FIL;
	}

	my $result = $atlas->findPepXMLFile( search_path => '/tmp', preferred_names => $args{preferred} );
	if ( $args{touch} ) {
		system "rm /tmp/$args{file}";
	}
	return $result;
}


sub get_sbeams {
  $sbeams = new SBEAMS::Connection;
  return $sbeams;
}

sub get_atlas {
  $atlas = new SBEAMS::PeptideAtlas;
  return $atlas;
}


sub authenticate {
  return $sbeams->Authenticate();
}


sub breakdown {
 # Put clean-up code here
}
END {
  breakdown();
} # End END
