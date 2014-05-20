#!/usr/local/bin/perl -w

#$Id: transactionTest.t 4664 2006-04-14 22:50:05Z dcampbel $

use DBI;
use Test::More tests => 5;
use Test::Harness;
use strict;

use FindBin qw($Bin);
use lib( "$Bin/../.." );
use SBEAMS::Connection;
use SBEAMS::Connection::Tables;


# Limit the noise to beautify the output.  Sometimes need to comment this out to troubleshoot
#close(STDERR);

$|++; # don't buffer output
my $numrows;
my $msg;

my $sbeams = SBEAMS::Connection->new();
my $test = 'transaction_test_table';
# Make as many database connections as possible, those that fail are dropped. 
my $dbh;
ok( $dbh = dbConnect(), 'Connect to SQL Server database' );
ok( test_init_transaction(), 'Initiate transaction' );
ok ( always_true(), 'always true' );

ok( test_commit_transaction(), 'commit transaction' );
ok( test_reset_dbh(), 'reset database handle' );
print "\n";
sub always_true {
  return 1;
}

sub test_init_transaction {
#  $dbh->{AutoCommit} = 0;
#  return $sbeams->initiate_transaction( no_raise_error => 1 );
  $sbeams->initiate_transaction( no_raise_error => 0 );
  return 1;
}

sub test_commit_transaction {
  $sbeams->commit_transaction();
  return 1;
}

sub test_reset_dbh {
  $sbeams->reset_dbh(); 
  return 1;
}

END {
  breakdown();
} # End END
sub createTable {
  my $db = shift;
  my $sql = "CREATE TABLE $test ( f_one INTEGER, f_two VARCHAR(36) )";
  $sql .= " TYPE InnoDB" if $db eq 'mysql';
  $dbh->do( $sql );
}

sub dropTable {
  my $db = shift;
  my $sql = "DROP TABLE $test";
  $dbh->do( $sql );
}


sub breakdown {
}

sub testInterrupt {
  my $db = shift;
  eval {
    undef( $dbh );
  }; 
  $dbh = dbConnect( $db );
  return ( defined $dbh ) ? 1 : 0;
}

sub checkCommitState {
  my $db = shift;
  my $state = shift;
  return ( $dbh->{AutoCommit} == $state ) ? 1 : 0;
}

sub checkNumrows {
  my $db = shift;
  my $num = shift;
#print "DB is $db, CNT is $num\n";
  my ( $cnt ) = $dbh->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $test
  END
  $msg = ( $num == $cnt ) ? "Found $cnt as expected" : "Found $cnt, expected $num\n";
  return ( $num == $cnt ) ? 1 : 0;
}

sub testCommit {
  my $db = shift;
  $dbh->commit();
}

sub testBegin {
  my $db = shift;
  $dbh->begin_work();
}

sub testRollback {
  my $db = shift;
  $dbh->rollback();
}

sub testInsert {
  my $db = shift;
  my $sql = "INSERT INTO $test ( f_one, f_two ) VALUES ( ";
  my %strs = ( 1 => 'one', 2 => 'two', 3 => 'three' );
  my $status;
  for my $key ( keys( %strs) ) {
    $status = $dbh->do( $sql . $key . ", '$strs{$key}' )" );
  }
  return $status;
}

sub deleteRows {
  my $db = shift;
  $dbh->do( "DELETE FROM $test" );
}


sub setNumrows {
  my $db = shift;
  ( $numrows ) = $dbh->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $test
  END
#  print "Found $numrows rows\n";
}

sub setAutoCommit {
  my $db = shift;
  my $commit = shift;
  my $result = $dbh->{AutoCommit} = $commit; 
  return ( $result == $commit ) ? 1 : 0;
}
  

sub dbConnect {
  
  my $status = $sbeams->Authenticate( connect_read_only => 0 );

  return $status unless $status;
  my $dbh = $sbeams->getDBHandle();

  return $dbh;


}

#  $dbh->{AutoCommit} = 0;


__DATA__


