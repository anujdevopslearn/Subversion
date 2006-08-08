#!/usr/local/bin/perl -w
###############################################################################
#### Simple test script to verify that database connection is working
#### Edit the EDITME section below to reflect local database server
#### $Id$
###############################################################################

  use strict;
  use DBI;
  my ($dsn,$user_name,$password,$querystring);

  #### EDITME: set the desired test #
  my $test = 1;

  #### SQL Server/Sybase SBEAMS test
  if ($test == 1) {
    $dsn = "DBI:Sybase:server=mssql;database=sbeams";
    $user_name = "XXXXX"; # user name
    $password = "XXXXXX";  # password
    $querystring="SELECT * FROM user_login";

  #### SQL Server/Sybase pubs test
  } elsif ($test == 2) {
    $dsn = "DBI:Sybase:server=mssql;database=pubs";
    $user_name = "XXXXX"; # user name
    $password = "XXXXX";  # password
    $querystring="SELECT * FROM authors";

  #### MySQL GO test
  } elsif ($test == 3) {
    $dsn = "DBI:mysql:go:mysql";
    $user_name = "XXXXX"; # user name
    $password = "XXXXX";  # password
    $querystring="SELECT * FROM species";

  #### PostgreSQL Genex test
  } elsif ($test == 4) {
    $dsn = "DBI:Pg:dbname=genex;host=pgsql";
    $user_name = "XXXXXX"; # user name
    $password = "XXXXXX";  # password
    $querystring="SELECT * FROM species";

  } else {
    die("Test $test not defined");
  }


  #############################################################################

  my ($dbh, $sth);           # database and statement handles
  my (%attr) = (             # error-handling attributes
    PrintError => 0,
    RaiseError => 0
  );

  #### connect to database
  $dbh = DBI->connect ($dsn, $user_name, $password, \%attr )
    or bail_out ("Cannot connect to database");


  #### issue query
  print "[QUERY]: $querystring\n";
  $sth = $dbh->prepare ($querystring) or bail_out ("Cannot prepare query");
  $sth->execute () or bail_out ("Cannot execute query");


  #### Read the results
  my $counter = 0;
  while (my (@result) = $sth->fetchrow_array()) {
    for (my $i=0; $i<scalar(@result); $i++) {
      $result[$i] = '<NULL>' if (!defined($result[$i]));
    }
    print join(" | ",@result),"\n";
    $counter++;
    last if ($counter > 4);
  }

  #### clean up
  if ($DBI::err) {
    bail_out ("Error during retrieval");
  }
  $sth->finish () or bail_out ("Cannot finish query");


  #### Disconnect database session
  $dbh->disconnect ()
    or bail_out ("Cannot disconnect from database");

  exit(0);




###############################################################################
#### bail_out() subroutine - print error code and string, then exit
###############################################################################

sub bail_out {
  my ($message) = shift;
  die "$message\nError $DBI::err ($DBI::errstr)\n";
}


