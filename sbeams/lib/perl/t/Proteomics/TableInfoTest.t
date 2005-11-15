#!/usr/local/bin/perl -w

#####################################################################
# Program	: TableInfoTest.t 
# $Id$
#
# Description: Test for TableInfo module, testing different permutations
#              of table_name and search_key   
#
# SBEAMS is Copyright (C) 2000-2006 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public
# License (GPL) version 2 as published by the Free Software
# Foundation.  It is provided WITHOUT ANY WARRANTY.  See the full
# description of GPL terms in the LICENSE file distributed with this
# software.
#####################################################################

use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );         # path to $SBEAMS/lib/perl directory
use Test::More;
use DBI;

# Globals
  my ($sbeams, $sbeamsMOD, $user);
  use constant VERBOSE => 0; # Turn on to see SQL errors 

# Setup output streams.
close(STDERR) unless VERBOSE;
$|++; 

# Setup tests
BEGIN {
} # end BEGIN


# MAIN
{
  my $tables = get_tables();
  my $keys = get_keys();

  my $num_tests = scalar(@$tables) * scalar(@$keys) + 7;
  plan( tests => $num_tests );

  use_ok( 'SBEAMS::Connection' );
  use_ok( 'SBEAMS::Proteomics' );
  use_ok( 'SBEAMS::Proteomics::TableInfo' );
  ok( $sbeams = new SBEAMS::Connection->new(),"Create SBEAMS object" );
  ok( $sbeamsMOD = SBEAMS::Proteomics->new(),"Create SB::Proteomics object");
  ok( $sbeamsMOD->setSBEAMS($sbeams),"Cache SBEAMS object" );
  ok($user = $sbeams->Authenticate(permitted_work_groups_ref => ['Admin']),
			                              "authenticate current user");

  for my $table (@$tables) {
    for my $key (@$keys) {
      if ( $key !~ /url_cols/ ) {
        ok( sql_test($table, $key), "Testing SQL for $key from $table" );
      } else {
        ok( fetch_test($table, $key), "Testing fetch for $key from $table" );
      }
    }
  }

}

sub get_keys {
  my @keys = qw(FULLQuery projPermSQL BASICQuery url_cols);
  return \@keys;
}

sub get_tables {
  return [qw( APD_peptide_summary PR_biosequence PR_biosequence_set
              PR_fraction PR_gradient_program PR_proteomics_experiment
              PR_proteomics_sample PR_publication PR_search_batch
              PR_search_hit_annotation PR_bogus_table) 
         ]; 
}

sub fetch_test {
  my $table = shift;
  my $key = shift;
  return $sbeamsMOD->returnTableInfo( $table, $key );
  }

sub sql_test {
  my $table = shift;
  my $key = shift;
  my ($res) = $sbeamsMOD->returnTableInfo( $table, $key );
  my @sql;
  if ( ref $res eq 'HASH' ) {
    for my $k (keys(%$res)) {
      $res->{$k} =~ s/KEYVAL/1/g;
      push @sql, $res->{$k};
    }
  } else {
    push @sql, $res;
  }
  my $status = scalar( @sql );
  for my $sql ( @sql ) {
    next unless $sql;
    my @sql_results;
    eval {
         $sbeams->selectSeveralColumns($sql) 
         };
    if ( $@ ) { 
      print STDERR "Error $DBI::errstr on $sql\n" if VERBOSE;
      $status--;
    }
  }
  return $status;

}

# breakdown
sub breakdown {
#    print "After the script, there was ... END\n\n";
}

# Breakdown tests, should always execute
END {
    breakdown();
} # end END

1;

__END__

=head1  TableInfoTest.t

=head2  DESCRIPTION

Test for sql invoked in TableInfo module

=head2  USAGE

./TableInfoTest.t

=cut
