#!/usr/local/bin/perl -w

use DBI;
use Getopt::Long;
use strict;
use Data::Dumper;
use Test::More tests => 36;
use Test::Harness;


use constant REFRESH_HANDLE => 1;
close( STDERR );

$|++; # unbuffer output

my $iter = 3;
my $opts = getOptions();
my $TB_TEST_SAMPLE = "$opts->{db}.dbo.test_sample";

# db handle
my $dbh = dbConnect();

# Delete/Create tables if needed
setup_tables() if $opts->{setup};

# number of rows in test table at any point in time
my $numrows;

# message passing from test to main 
my $msg;


my $cid = 1;

  # Test ability to set AutoCommit ON, setup db
  ok( setAutoCommit( 1 ), 'Set Autocommit ON' );
  ok( checkCommitState( 1 ), "Verify autocommit state - ON" );
  ok( deleteRows(), "Clean up database" );


  # Test inserts with autocommit ON
  setNumrows();
  ok( testInsert(), "Insert $iter rows" );
  ok( checkNumrows( $numrows + $iter ), "Check number of rows: $msg" );

  # Test rolled-back inserts with autocommit ON
  setNumrows( );
  ok( testInsert( ), "Insert $iter rows" );
  ok( testRollback( ), 'Rollback transaction' );
  ok( checkNumrows( $numrows + $iter ), "Check number of rows: $msg" );

  # Test interrupted inserts with autocommit ON
  setNumrows();
  ok( testInsert(), "Insert $iter rows" );
  ok( testInterrupt(), 'Interrupt transaction' );
  ok( checkNumrows( $numrows + $iter ), "Check number of rows: $msg" );
  print "\n";
  print "\n";

  # Test ability to turn autocommit off
  ok( setAutoCommit(  0 ), 'Set Autocommit OFF' );
  ok( checkCommitState(  0 ), "Verify autocommit state - OFF" );
  
  # Test committed inserts with autocommit OFF
  setNumrows();
  ok( testInsert(), "Insert $iter rows" );
  ok( testCommit(), 'Commit transaction' );
  ok( checkNumrows(  $numrows + $iter ), "Check number of rows: $msg" );

  # Test rolled-back inserts with autocommit OFF
  setNumrows( );
  ok( testInsert( ), "Insert $iter rows" );
  ok( testRollback( ), 'Rollback transaction' );
  ok( checkNumrows(  $numrows ), "Check number of rows: $msg" );

  # Test interrupted inserts with autocommit OFF
  setNumrows();
  ok( testInsert(), "Insert $iter rows" );
  ok( testInterrupt(), 'Interrupt transaction' );
  ok( checkNumrows( $numrows ), "Check number of rows: $msg" );
  print "\n";
  print "\n";

  # Test transaction isolation
  ok( testInitiateTransaction(), 'Isolate transaction' );

  # Test commited inserts within transaction
  setNumrows( );
  ok( testInsert( ), "Insert $iter rows" );
  ok( testCommit(), 'Commit isolated transaction' );
  ok( checkNumrows(  $numrows + $iter ), "Check number of rows: $msg" );

  # Test rolled-back inserts within transaction
  ok( testInitiateTransaction(), 'Isolate transaction' );
  setNumrows();
  ok( testInsert( ), "Insert $iter rows" );
  ok( testRollback( ), 'Rollback transaction' );
  ok( dbping( ), 'Ping database' );
  ok( checkNumrows(  $numrows ), "Check number of rows: $msg" );

  # Test interrupted inserts within transaction
  ok( testInitiateTransaction(), 'Isolate transaction' );
  setNumrows();
  ok( testInsert(), "Insert $iter rows" );
  ok( testInterrupt(), 'Interrupt transaction' );
  ok( dbping( ), 'Ping database' );
  ok( checkNumrows( $numrows ), "Check number of rows: $msg" );

  print "\n\n";

delete_tables() if $opts->{setup};

END {
  breakdown();
} # End END

sub breakdown {
}

sub dbping {
  $dbh->ping();
}

sub testInitiateTransaction {

  # Set up transaction
  initiate_transaction();
  return 1;
}




sub getOptions {
  my %opts;
  GetOptions( \%opts, 'username=s', 'pass=s', 'server=s', 'db=s', 'setup', 'delete_tables' );

  for my $opt ( qw( username pass ) ) {
    die "missing required option $opt ($opts{$opt})\n" unless $opts{$opt};  
  }
  $opts{server} ||= 'helios';
  $opts{db} ||= 'sbeams';
  return \%opts;
}

sub delete_tables {
  my $sql = " DROP TABLE $TB_TEST_SAMPLE ";
  $dbh->do( $sql );
  die ( $DBI::errstr ) if $DBI::errstr;
}

sub setup_tables {
  my $sql = qq~
  CREATE TABLE $TB_TEST_SAMPLE 
   ( project_id INTEGER, 
     sample_tag VARCHAR(256),
     age INTEGER,
     sample_protocol_ids VARCHAR(256), 
     sample_description VARCHAR(256),
     modified_by_id INTEGER,
     created_by_id INTEGER ) 
  ~;

  $dbh->do( $sql );
  if ( $DBI::errstr ) {
    # table might be in the way...
    delete_tables();
    $dbh->do( $sql );
  }
  die ( $DBI::errstr ) if $DBI::errstr;
}

sub dbConnect {
  my %error_attr = ( PrintError => 0, RaiseError => 0);
  my $cstr = "DBI:Sybase:server=$opts->{server};datbase=$opts->{db}";
  my $dbh = DBI->connect( $cstr, $opts->{username}, $opts->{pass}, \%error_attr ) || die "Unable to connect:\n\n $DBI::errstr";
  return $dbh;
}


sub initiate_transaction {

   # Turn autocommit off
  $dbh->{AutoCommit} = 0;

  # Finish any incomplete transactions
  eval {
    $dbh->commit();
  };

  if ( $@ ) {
    print STDERR "DBI error: $@\n";
  }

  # Turn RaiseError off, because mssql begin_work is AFU
  $dbh->{RaiseError} = 0;

  # from DBI docs, appears that setting AutoCommit off is sufficient to init_transaction.
  # Begin transaction
  #  $dbh->begin_work();
}


sub testInterrupt {
  eval {
    undef( $dbh );
  }; 
  eval {
    $dbh = dbConnect();
  };
  return ( defined $dbh ) ? 1 : 0;
}

sub checkCommitState {
  my $state = shift;
  return ( $dbh->{AutoCommit} == $state ) ? 1 : 0;
}

sub checkNumrows {
  my $num = shift;
  my ( $cnt ) = $dbh->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $TB_TEST_SAMPLE
  END
  $msg = ( $num == $cnt ) ? "Found $cnt as expected" : "Found $cnt, expected $num\n";
  return ( $num == $cnt ) ? 1 : 0;
}

sub testCommit {
  eval {
  $dbh->commit();
  };
  return ( $! ) ? 0 : 1;
}

sub testBegin {
  $dbh->begin_work();
}

sub testRollback {
  eval {
    $dbh->rollback();
  };
  return 1 unless $@;
}

sub testInsert {

  my @ids;
  my $name = 'sbeams_test_data.1';

  my $project_id = 100;

  for ( my $i = 0; $i < $iter; $i++ ) {

    my $sql =<<"    END";
    INSERT INTO $TB_TEST_SAMPLE 
      ( project_id, sample_tag, age, sample_protocol_ids, 
        sample_description, modified_by_id, created_by_id ) 
        VALUES ( $project_id, '$name',
        '100', '1,2,3,4,5,6', 'autogenerated', $cid, $cid )
    END
    my $sth = $dbh->prepare( $sql );
    $sth->execute();

    $name++;
  }
  return \@ids;
}

sub deleteRows {
  $dbh->do( "DELETE FROM $TB_TEST_SAMPLE" );
}


sub setNumrows {
  ( $numrows ) = $dbh->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $TB_TEST_SAMPLE
  END
}

sub setAutoCommit {
  my $commit = shift;
  my $result = $dbh->{AutoCommit} = $commit; 
  return ( $result == $commit ) ? 1 : 0;
}
  
sub setRaiseError {
  my $raise = shift;
  my $result = $dbh->{RaiseError} = $raise; 
  return ( $result == $raise ) ? 1 : 0;
}
  





__DATA__



  # Test begin with commit 
  setNumrows(  );
  ok( testBegin( ), 'Set transaction beginning' );
  ok( testInsert(  ), "Insert $iter rows" );
  ok( testCommit( ), 'Commit transaction' );
  ok( checkNumrows( $numrows + $iter ), "Check number of rows: $msg" );

  # Test begin with rollback 
  setNumrows(  );
  ok( testBegin(  ), 'Set transaction beginning' );
  ok( testInsert(  ), "Insert $iter rows" );
  ok( testRollback( ), 'Rollback transaction' );
  ok( checkNumrows(  $numrows ), "Check number of rows: $msg" );

  # Test begin with interrupt 
  setNumrows(  );
  ok( testBegin( ), 'Set transaction beginning' );
  ok( testInsert( ), "Insert $iter rows" );
  ok( testInterrupt(  ), 'Rollback transaction' );
  ok( checkNumrows(  $numrows ), "Check number of rows: $msg" );
+++++++++++++++++++++++++++++++++
  my $ac = $sbeams->isAutoCommit();
  my $re = $sbeams->isRaiseError();

  # Set up transaction
  $sbeams->initiate_transaction();

  eval {
  # insert treatment record
    my $treatment_id = $biomarker->insert_treatment( data_ref => $treat );
  # insert new samples
    my $status = $biosample->insert_biosamples(    bio_group => $treat->{treatment_name},
                                                treatment_id => $treatment_id,
                                                    data_ref => $cache->{children} );
  };   # End eval block

  my $status;
  if ( $@ ) {
    print STDERR "$@\n";
    $sbeams->rollback_transaction();
    $status = "Error: Unable to create treatment/samples";
  } else { 

    # want to calculate the number of new samples created.  $cache->{children}
    # is a hash keyed by parent_biosample_id and a arrayref of individual kids
    # as a value.  
    my $cnt = scalar( keys( %{$cache->{children}} ) );
    for my $child ( keys(  %{$cache->{children}} ) ) {
      my $reps = scalar( @{$cache->{children}->{$child}} );
      $cnt = $cnt * $reps;
      last;  # Just need the first one
    }

    $status = "Successfully created treatment with $cnt new samples";
    $sbeams->commit_transaction();
  }# End eval catch-error block

  $sbeams->setAutoCommit( $ac );
  $sbeams->setRaiseError( $re );
