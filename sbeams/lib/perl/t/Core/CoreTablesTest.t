#!/usr/local/bin/perl -w

#$Id: DBStressTest.t 3927 2005-09-19 17:23:26Z dcampbel $

use DBI;
use Test::More; 
use Digest::MD5 qw( md5 md5_base64 );
use strict;

use FindBin qw($Bin);
use lib( "$Bin/../.." );
use SBEAMS::Connection;
use SBEAMS::Connection::Tables;

# Number of times to execute each statement.
use constant ITERATIONS => 50; # Number of times to exec each query
use constant REFRESH_HANDLE => 0; # Refresh handle between executions?
use constant VERBOSE => 0;  # Level of loquaciousness to exhibit
use constant NUM_ROWS => 100;  # (Max) Number of rows to hash together

# Quiet down in there!
#close(STDERR);

# Immediate gratification desired, do not buffer output
$|++; 

my %queries = ( 1 => "SELECT * FROM $TB_ORGANISM",
                2 => "SELECT * FROM $TB_MGED_ONTOLOGY_RELATIONSHIP",
                3 => "SELECT * FROM $TB_MGED_ONTOLOGY_TERM",
                4 => "SELECT * FROM $TB_DBXREF",
              ); 

my $num_tests = scalar(keys(%queries)) * 2 + 1;
plan( tests => $num_tests );
  
# Set up user agent and sbeams objects
my $dbh = dbConnect();
my $msg = ( ref($dbh) ) ?  "Connect to db ($dbh->{Driver}->{Name}, version $dbh->{Driver}->{Version}  )" : "Failed to connect to database";
ok( ref($dbh), $msg ); 

# Setup
my %results;


SKIP: {
skip "queries, db connection failed", $num_tests - 1 unless ref($dbh);
# Establish baseline data.
for my $key ( sort( keys( %queries ) ) ) { 
  my $sth = $dbh->prepare( $queries{$key} );
  $sth->execute;
  my @results = stringify( $sth );
  $results{$key} = \@results;
  ok( $results{$key} , "Got data for query $key" );
}


# Loop through each query and execute it the specified number of times.
my $status = 1;
my $iterations = ITERATIONS;
for my $key ( sort( keys( %queries ) ) ) {
#   Get a fresh handle, if so configured 
  if ( REFRESH_HANDLE ) {
    eval { $dbh->disconnect() };
    $dbh = dbConnect();
  }
  for( my $i = 1; $i < $iterations; $i++ ) {

    # prep and exec query
    my $sth = $dbh->prepare( $queries{$key} );
    $sth->execute();

    # Check number and content of return values
    my( $num, $string ) = stringify( $sth );

    # Define error conditions
    if ( $num != $results{$key}->[0] ) {
      print STDERR "$num results returned, $results{$key} expected at iteration $i for query $key\n";
      $status = 0;
      last;
    } elsif ( $string ne $results{$key}->[1] ) {
      print STDERR "MD5 sum different at iteration $i for query $key\n";
      $status = 0;
      last;
    }
  }
  ok( $status, "Run query $key for $iterations iterations" );
}
} # End skip block
eval { $dbh->disconnect() };

#+
# Join each row on '::', concatenate the whole shebang, and take an MD5Sum of the result.
#-
sub stringify {
  my $sth = shift;
  my $cnt = 0;
  my $contents = '';
  while ( my @row = $sth->fetchrow_array() ) {
    $cnt++;

    # Insurance against big tables!
    last if $cnt >= NUM_ROWS;
    $contents .= join "::", map{ ( defined $_ ) ? $_ : 'NULL' } @row;
  }
  my $chksum = md5_base64( $contents );
  print "$cnt rows, checksum => $chksum\n" if VERBOSE; # Anything happening?
  return ( $cnt, $chksum );
}

sub dbConnect {
  # We will use the sbeams connection machinery, connecting as a read_only
  # user.  If this is not set up, the connex will fail.
  
  my $sbeams = SBEAMS::Connection->new();
  my $status = $sbeams->Authenticate( connect_read_only => 1 );

  return $status unless $status;
  my $dbh = $sbeams->getDBHandle();

  return $dbh;
}

