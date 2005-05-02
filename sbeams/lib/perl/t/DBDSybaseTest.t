#!/tools/bin/perl -w


use DBI;
use Test::More tests => 4;
use Test::Harness;
use Digest::MD5 qw( md5 md5_base64 );
use strict;

close(STDERR);

$|++; # do not buffer output
my %queries = ( 1 => 'SELECT * FROM pubs.dbo.authors ORDER BY au_id',
                2 => 'SELECT * FROM pubs.dbo.employee ORDER BY emp_id',
                3 => "SELECT * FROM pubs.dbo.titles T JOIN pubs.dbo.titleauthor TA ON T.title_id = TA.title_id JOIN pubs.dbo.authors A ON A.au_id = TA.au_id ORDER BY A.au_id, T.title_id DESC" 
              ); 
  
# Set up user agent and sbeams objects
my $dbh;
ok( $dbh = dbConnect(), 'Connect to database' );

# Setup
my %results;

for my $key ( sort( keys( %queries ) ) ) { 
  my $sth = $dbh->prepare( $queries{$key} );
  $sth->execute;
  my @results = stringify( $sth );
  $results{$key} = \@results;
}

my $status = 1;
my $iterations = 1000;
for my $key ( sort( keys( %queries ) ) ) {
    # Get a fresh handle, just in case
    eval { $dbh->disconnect() };
    $dbh = dbConnect();
    for( my $i = 1; $i < $iterations; $i++ ) {
      my $sth = $dbh->prepare( $queries{$key} );
      $sth->execute();
      my( $num, $string ) = stringify( $sth );
      if ( $num != $results{$key}->[0] ) {
        print STDERR "$num results returned, $results{$key} expected at iteration $i for query $key\n";
        $status = 0;
      } elsif ( $string ne $results{$key}->[1] ) {
        print STDERR "MD5 sum different at iteration $i for query $key\n";
        $status = 0;
      }
    }
  ok( $status, "Run query $key for $iterations iterations" );
}
eval { $dbh->disconnect() };

sub stringify {
  my $sth = shift;
  my $cnt = 0;
  my $contents = '';
  while ( my @row = $sth->fetchrow_array() ) {
    $cnt++;
    $contents .= join "::", map{ ( defined $_ ) ? $_ : 'NULL' } @row;
  }
  my $chksum = md5_base64( $contents );
  print STDERR "$chksum => $contents\n" if 0; # Debug stmt, proves something is working!
  return ( $cnt, $chksum );
}

sub dbConnect {
  my $connect = "DBI:Sybase:server=mssql;database=pubs";
  my $user = 'user';
  my $pass = 'pass';

  my $dbh = DBI->connect( $connect, $user, $pass, { RaiseError => 1, AutoCommit => 0 } ) || die( $DBI::errstr );
  return $dbh;
}

