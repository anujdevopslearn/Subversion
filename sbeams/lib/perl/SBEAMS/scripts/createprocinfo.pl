#!/usr/bin/perl
# createprocinfo.pl - List the size of all the tables in a database


use DBI;
use strict;


my ($dsn) = "DBI:Sybase:server=tj-db2ks-01;database=sbdb"; # data source name
my ($user_name) = "guest";  # user name
my ($password) = "guest"; # password
my ($dbh, $sth);            # database and statement handles
my (@rows);                 # array containing references to each row
my ($row_ref);              # reference to a returned row
my ($element);              # generic element of an array
my (%attr) =                # error-handling attributes
(
    PrintError => 0,
    RaiseError => 0
);
my (%tables);
my ($tablename);
my ($counter);
my ($ntables);
my ($tablerows);


#### connect to database
$dbh = DBI->connect ($dsn, $user_name, $password, \%attr)
	or bail_out ("Cannot connect to database");


#### Query to return information about the arrays we need to process
my $sqlquery = qq~
SELECT	A.array_id,A.array_name,
	AQ.array_quantitation_id,AQ.data_flag AS 'quan_flag',
	AQ.stage_location,ARSM1.name AS 'Sample1Name',ARSM2.name AS 'Sample2Name'
  FROM array_request AR
  LEFT JOIN array_request_slide ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN array_request_sample ARSM1 ON ( ARSL.array_request_slide_id = ARSM1.array_request_slide_id AND ARSM1.sample_index=0)
  LEFT JOIN array_request_sample ARSM2 ON ( ARSL.array_request_slide_id = ARSM2.array_request_slide_id AND ARSM2.sample_index=1)
  LEFT JOIN array A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN printing_batch PB ON ( A.printing_batch_id = PB.printing_batch_id )
  LEFT JOIN hybridization H ON ( A.array_id = H.array_id )
  LEFT JOIN array_scan ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN array_quantitation AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
 WHERE AR.project_id=5
 ORDER BY ARSL.array_request_slide_id
~;


#### issue query
$sth = $dbh->prepare ($sqlquery)
	or bail_out ("Cannot prepare query");
$sth->execute ()
	or bail_out ("Cannot execute query");


#### read results of query
$counter = 0;
while ( $row_ref = $sth->fetchrow_arrayref() ) {
	push(@rows,[@$row_ref]);
	$counter++;
}
$DBI::err == 0
	or bail_out ("Error during retrieval");

print join("  |  ",@{$sth->{NAME}}),"\n";
print "--------------------------------------------------------------\n";
foreach $element (@rows) {
	print join("  |  ",@$element),"\n";
}



# Need logic here to separate into categories of
# - Sample1Name_vs_Sample2Name (first unique)
# - Sample1Name_vs_Sample2Name (second unique)
# - ...
# - not ready yet (column 0 is undef)
# - not OK (column 3 is not OK)




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
