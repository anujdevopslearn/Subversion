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
use SBEAMS::Connection;

# Globals
  my $sbeams = SBEAMS::Connection->new();
  use constant VERBOSE => 1; # Turn on to see SQL errors 

# Setup output streams.
close(STDERR) unless VERBOSE;
$|++; 

# Setup tests
BEGIN {
} # end BEGIN


# MAIN
{
  my $tables = $sbeams->get_info_tables();
  my $keys = $sbeams->get_info_keys();

  my $num_tests = scalar(@$tables) * scalar(@$keys) + 1;
  plan( tests => $num_tests );

  ok( $sbeams->Authenticate(permitted_work_groups_ref => ['Admin']),
			                              "authenticate current user");



  for my $table (@$tables) {
    for my $key (@$keys) {
      if ( $key =~ /Query$|SQL/i ) {
        ok( sql_test($table, $key), "Testing SQL for $key from $table" );
      } else {
        ok( fetch_test($table, $key), "Testing fetch for $key from $table" );
      }
    }
  }
}

sub fetch_test {
  my $table = shift;
  my $key = shift;
  my $res;
  eval {
    $res = $sbeams->returnTableInfo( $table, $key );
    };
  if ( $@ ) {
    print STDERR "Error fetching $key from $table: $DBI::errstr";
    return 0;
  }
  return 1;
}

sub sql_test {
  my $table = shift;
  my $key = shift;
  my ($res) = $sbeams->returnTableInfo( $table, $key );
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
