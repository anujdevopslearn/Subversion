#!/local/programs/bin/perl -w
#!/usr/local/bin/perl -w

#$Id$

use DBI;
use Test::More tests => 102;
use Test::Harness;
use strict;

# Limit the noise to beautify the output.  Sometimes need to comment this out to troubleshoot
close(STDERR);

$|++; # don't buffer output
my $numrows;
my $msg;

# Name of test table
my $test = 'test';
  
# Make as many database connections as possible, those that fail are dropped. 
my %dbh;
ok( $dbh{sqlserv} = dbConnect( 'sqlserv' ), 'Connect to SQL Server database' );
ok( $dbh{mysql} = dbConnect( 'mysql' ), 'Connect to MySQL database' );
ok( $dbh{pgsql} = dbConnect( 'pgsql' ), 'Connect to PostgreSQL database' );
print "\n";

# Iterate through hash of dbhandles, or some salient subset.
#for my $db ( qw( mysql ) ) {
for my $db ( keys( %dbh ) ) {

  # Bail if a particular handle didn't 'take'
  next unless defined $dbh{$db};

  # Print our header line, check driver name and version.
  print "Working on $db ( $dbh{$db}->{Driver}->{Name}, version $dbh{$db}->{Driver}->{Version}   )...\n";

  # Reset the test table.
  ok( dropTable( $db ), 'Drop test table');
  ok( createTable( $db ), 'Create test table');

  # Optionally change dbname
#  $test = ( $db eq 'mysql' ) ? 'test' : 'sbeams_test.dbo.test';

  # Set up database, test inserts with autocommit ON
  ok( deleteRows( $db ), "Clean up database" );
  setNumrows( $db );
  ok( testInsert( $db ), 'Insert 3 rows' );
  ok( checkNumrows( $db, $numrows + 3 ), "Check number of rows: $msg" );

  # Test interrupted inserts with autocommit ON
  setNumrows( $db );
  ok( testInsert( $db ), 'Insert 3 rows' );
  ok( testInterrupt( $db ), 'Interrupt transaction' );
  ok( checkNumrows( $db, $numrows + 3 ), "Check number of rows: $msg" );
  print "\n";


  # Test ability to turn autocommit off
  ok( setAutoCommit( $db, 0 ), 'Set Autocommit OFF' );
  ok( checkCommitState( $db, 0 ), "Verify autocommit state - OFF" );
  
  # Test committed inserts with autocommit OFF
  setNumrows( $db );
  ok( testInsert( $db ), 'Insert 3 rows' );
  ok( testCommit( $db ), 'Commit transaction' );
  ok( checkNumrows( $db, $numrows + 3 ), "Check number of rows: $msg" );

  # Test rolled-back inserts with autocommit OFF
  setNumrows( $db );
  ok( testInsert( $db ), 'Insert 3 rows' );
  ok( testRollback( $db ), 'Rollback transaction' );
  ok( checkNumrows( $db, $numrows ), "Check number of rows: $msg" );

  # Test interrupted inserts with autocommit OFF
  setNumrows( $db );
  ok( testInsert( $db ), 'Insert 3 rows' );
  ok( testInterrupt( $db ), 'Interrupt transaction' );
  ok( checkNumrows( $db, $numrows ), "Check number of rows: $msg" );
  print "\n";


  # Test ability to set AutoCommit ON
  ok( setAutoCommit( $db, 1 ), 'Set Autocommit ON' );
  ok( checkCommitState( $db, 1 ), "Verify autocommit state - ON" );

  # Test begin with commit 
  setNumrows( $db );
  ok( testBegin( $db ), 'Set transaction beginning' );
  ok( testInsert( $db ), 'Insert 3 rows' );
  ok( testCommit( $db ), 'Commit transaction' );
  ok( checkNumrows( $db, $numrows + 3 ), "Check number of rows: $msg" );

  # Test begin with rollback 
  setNumrows( $db );
  ok( testBegin( $db ), 'Set transaction beginning' );
  ok( testInsert( $db ), 'Insert 3 rows' );
  ok( testRollback( $db ), 'Rollback transaction' );
  ok( checkNumrows( $db, $numrows ), "Check number of rows: $msg" );

  # Test begin with interrupt 
  setNumrows( $db );
  ok( testBegin( $db ), 'Set transaction beginning' );
  ok( testInsert( $db ), 'Insert 3 rows' );
  ok( testInterrupt( $db ), 'Rollback transaction' );
  ok( checkNumrows( $db, $numrows ), "Check number of rows: $msg" );

  print "\n\n";
}


END {
  breakdown();
} # End END

sub createTable {
  my $db = shift;
  my $sql = "CREATE TABLE $test ( f_one INTEGER, f_two VARCHAR(36) )";
  $sql .= " TYPE InnoDB" if $db eq 'mysql';
  $dbh{$db}->do( $sql );
}

sub dropTable {
  my $db = shift;
  my $sql = "DROP TABLE $test";
  $dbh{$db}->do( $sql );
}


sub breakdown {
}

sub testInterrupt {
  my $db = shift;
  eval {
    undef( $dbh{$db} );
  }; 
  $dbh{$db} = dbConnect( $db );
  return ( defined $dbh{$db} ) ? 1 : 0;
}

sub checkCommitState {
  my $db = shift;
  my $state = shift;
  return ( $dbh{$db}->{AutoCommit} == $state ) ? 1 : 0;
}

sub checkNumrows {
  my $db = shift;
  my $num = shift;
#print "DB is $db, CNT is $num\n";
  my ( $cnt ) = $dbh{$db}->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $test
  END
  $msg = ( $num == $cnt ) ? "Found $cnt as expected" : "Found $cnt, expected $num\n";
  return ( $num == $cnt ) ? 1 : 0;
}

sub testCommit {
  my $db = shift;
  $dbh{$db}->commit();
}

sub testBegin {
  my $db = shift;
  $dbh{$db}->begin_work();
}

sub testRollback {
  my $db = shift;
  $dbh{$db}->rollback();
}

sub testInsert {
  my $db = shift;
  my $sql = "INSERT INTO $test ( f_one, f_two ) VALUES ( ";
  my %strs = ( 1 => 'one', 2 => 'two', 3 => 'three' );
  my $status;
  for my $key ( keys( %strs) ) {
    $status = $dbh{$db}->do( $sql . $key . ", '$strs{$key}' )" );
  }
  return $status;
}

sub deleteRows {
  my $db = shift;
  $dbh{$db}->do( "DELETE FROM $test" );
}


sub setNumrows {
  my $db = shift;
  ( $numrows ) = $dbh{$db}->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $test
  END
#  print "Found $numrows rows\n";
}

sub setAutoCommit {
  my $db = shift;
  my $commit = shift;
  my $result = ${dbh{$db}}->{AutoCommit} = $commit; 
  return ( $result == $commit ) ? 1 : 0;
}
  

sub dbConnect {
  my $db = shift;

  my $connect = ( $db eq 'mysql' ) ?   "DBI:mysql:host=pandora;database=dcampbel" :
                                     # "DBI:mysql:host=mysql;database=test" :
                ( $db eq 'sqlserv' ) ? "DBI:Sybase:server=mssql;database=sbeams_test" :
                                       "DBI:Pg:host=pgsql;dbname=sbeamstest1";

#  my $user = ( $db eq 'mysql' ) ? 'guest' : 
  my $user = ( $db eq 'mysql' ) ? 'dcampbel' : 
             ( $db eq 'sqlserv' ) ? 'dcampbel' : 'tsbeamsadmin';

#  my $pass = ( $db eq 'mysql' ) ? 'guest' : 
  my $pass = ( $db eq 'mysql' ) ? 'xxxxxx' : 
             ( $db eq 'sqlserv' ) ? 'xxxxxx' : 'xxxxxx'; 

  my $dbh;
  eval {
    $dbh = DBI->connect( $connect, $user, $pass, { RaiseError => 0, AutoCommit => 1 } );
  };
  return $dbh;
}

#  $dbh->{AutoCommit} = 0;


__DATA__


