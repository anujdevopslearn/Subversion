#! /usr/bin/perl
# runsql.pl - simple bootstrap sql executer for get SBEAMS going. too crude.  replace.


use DBI;
use strict;


my ($dsn) = "DBI:Sybase:server=protdb;database=sbeams";
#my ($dsn) = "DBI:ODBC:mssql";
my ($user_name) = "sbeamsadmin"; # user name
my ($password) = 'xxxxxx';  # password
my ($dbh, $sth);           # database and statement handles
my (@ary);                 # array for rows returned by query
my (%attr) =               # error-handling attributes
(
    PrintError => 0,
    RaiseError => 0
);
my (%tables);
my ($tablename);
my ($counter);
my ($ntables);
my ($tablerows);
my ($querystring);


my $infile = shift;
my $sql = '';

#### connect to database
$dbh = DBI->connect ($dsn, $user_name, $password, \%attr )
	or bail_out ("Cannot connect to database");

if ($infile) {
  open(INFILE,$infile) || die("ERROR: Unable to open $infile");
  my $line = '';
  while ($line = <INFILE>) {
    if ($line =~ /^GO/) {
      $sth = $dbh->prepare ($sql)
	or bail_out ("Cannot prepare query");
      if ($sth->execute ()) {
      	## okay
      } else {
	print "ERROR $DBI::err ($DBI::errstr)\n\n";
	#or bail_out ("Cannot execute query");
      }
      $sql ='';
    } else {
    $sql .= $line;
    }
  }

  if ($sql =~ /\S/) {
    $sth = $dbh->prepare ($sql)
        or bail_out ("Cannot prepare query");
    if ($sth->execute ()) {
      ## okay
    } else {
      print "ERROR $DBI::err ($DBI::errstr)\n\n";
      #or bail_out ("Cannot execute query");
    }
  }

  close(INFILE);
  exit;
}




#### issue query
$sql="sp_tables" unless ($sql);

print "[QUERY]: ",$sql,"\n";
$sth = $dbh->prepare ($sql)
	or bail_out ("Cannot prepare query");
$sth->execute ()
	or bail_out ("Cannot execute query");



#### read results of query
$counter = 0;
while (@ary = $sth->fetchrow_array ())
{
	print join(" | ",@ary),"\n";
        #print "=",length(@ary[6]),"=\n";
	$counter++;
}



$DBI::err == 0
	or bail_out ("Error during retrieval");


#### clean up
$sth->finish ()
	or bail_out ("Cannot finish query");



#### ---------------------------------------------------------


$dbh->disconnect ()
	or bail_out ("Cannot disconnect from database");
exit (0);


#### --------------------------------------------------------------
#### --------------------------------------------------------------
#### bail_out() subroutine - print error code and string, then exit

sub bail_out
{
my ($message) = shift;
die "$message\nError $DBI::err ($DBI::errstr)\n";
}
