#!/tools/bin/perl -w

#$Id$

use DBI;
use Test::More tests => 7;
use Test::Harness;
use Digest::MD5 qw( md5 md5_base64 );
use strict;

# Number of times to execute each statement.
use constant ITERATIONS => 10;
use constant REFRESH_HANDLE => 0;
use constant VERBOSE => 0;

# Quiet down in there!
close(STDERR);

# Immediate gratification desired, do not buffer output
$|++; 

my %queries = ( 1 => 'SELECT * FROM pubs.dbo.authors ORDER BY au_id',
                2 => 'SELECT * FROM pubs.dbo.employee ORDER BY emp_id',
                3 => "SELECT * FROM pubs.dbo.titles T JOIN pubs.dbo.titleauthor TA ON T.title_id = TA.title_id JOIN pubs.dbo.authors A ON A.au_id = TA.au_id ORDER BY A.au_id, T.title_id DESC", 
                #4 => "SELECT TOP 1000 * FROM microarray_test.dbo.affy_gene_intensity"
              ); 
  
# Set up user agent and sbeams objects
my $dbh;
ok( $dbh = dbConnect(), "Connect to database ($dbh->{Driver}->{Name}, version $dbh->{Driver}->{Version}  )" );

# Setup
my %results;

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
    $contents .= join "::", map{ ( defined $_ ) ? $_ : 'NULL' } @row;
  }
  my $chksum = md5_base64( $contents );
#  print STDERR "$chksum => $contents\n" if 1; # Debug stmt, proves something is working!
  print "checksum => $chksum\n" if VERBOSE; # Debug stmt, proves something is working!
  return ( $cnt, $chksum );
}

sub dbConnect {
  # Define the database you want to interrogate
  my $db = 'sqlserv';
          # 'pgsql';
          # 'mysql';
          # 'sqlserv';
  
 my %connect = ( mysql => "DBI:mysql:host=mysql;database=test", 
                 sqlserv => "DBI:Sybase:server=mssql;database=SBEAMSTest1", 
                 pgsql => "DBI:Pg:host=pgsql;dbname=sbeamstest1" );

  my $user = 'sbeams_user';

  my %pass = ( mysql => 'mysql_pass',
               sqlserv => 'mssql_pass',
               pgsql => 'pgsql_pass' ); 

  my $dbh = DBI->connect( $connect{$db}, $user, $pass{$db}, { RaiseError => 1, AutoCommit => 0 } ) || die( $DBI::errstr );
  return $dbh;
}

