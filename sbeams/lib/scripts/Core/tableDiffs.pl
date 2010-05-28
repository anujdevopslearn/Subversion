#!/usr/local/bin/perl -w
#!/local/bin/perl

# Initial revision of script to compare tables/columns in a pair of databases
# to ensure they are in sync.

use FindBin qw( $Bin );
use lib ( "$Bin/../../perl" );

use Benchmark;
use SBEAMS::Connection;
use SBEAMS::Connection::DataTable;

my $print = 1;

use strict;
$|++; # don't buffer output

# MAIN

my $sbeams = SBEAMS::Connection->new();
my $dbh = $sbeams->getDBHandle();

my @dbs = ( 'SBEAMS', 'SBEAMS_test' );
#my @dbs = ( 'Microarray3', 'Microarray_test' );
#my @dbs = qw( peptideatlas peptideatlas_test );
#my @dbs = qw( proteomics proteomicsLM );
my %tab;

my %tables = { union => {} };
for my $schema ( @dbs ) {
  $tables{$schema} ||= {};
  $dbh->do( "use $schema" );

  my $sql = 'sp_tables';

  my $sth = $dbh->prepare( $sql );
  $sth->execute();
  my %cols; # columns we might expect to see
  while ( my @row = $sth->fetchrow_array() ) {
	  next unless $row[3] =~/TABLE/;
    next if $row[3] =~/SYSTEM/;
		my $table = uc($row[2]);
		$table =~ s/\s//g;

    my $csql = 'SELECT TOP 1 * FROM ' . $schema . '.dbo.' . $table;
#  	print "$csql\n";
    my $csth = $dbh->prepare( $csql ) || die 'cannot prepare';
		eval {
    $csth->execute() || die "cannot execute $csql";
		};
		if ( $@ ) {
			print "Error: $@\n";
			next;
		}

	 	$tables{$schema}->{$table} = {};
	 	$tables{union}->{$table} ||= {};

  	for my $col ( @{$csth->{NAME}} ) {
			$tables{$schema}->{$table}->{$col} = 'Yes';
			$tables{union}->{$table}->{$col} = 'Yes';
		}
    $csth->finish();
#	  last;
  }
  $sth->finish();
}

 	print join( "\t", '                         table', '                        column', @dbs, 'union' ) . "\n";
  for my $table ( sort( keys( %{$tables{union}} ) ) ) {
		my $tname = sprintf( '%30s', $table );
		$tname = substr( $tname, 0, 30 );
		my $t1 = $tables{$dbs[0]}->{$table};
		my $t2 = $tables{$dbs[1]}->{$table};
		my $un = $tables{union}->{$table};
		for my $col ( sort( keys( %$un ) ) ) {
  		my $cname = sprintf( '%30s', $col );
			$cname = substr( $cname, 0, 30 );
			my $t1c = ( !$t1->{$col} )  ? ' ' x ( length( $dbs[0] ) - 2 ) . 'No' :  ' ' x ( length( $dbs[0] ) - 3 ) . 'Yes';
			my $t2c = ( !$t2->{$col} )  ? ' ' x ( length( $dbs[1] ) - 2 ) . 'No' :  ' ' x ( length( $dbs[1] ) - 3 ) . 'Yes';
      my $uc = '  Yes';




			print join( "\t", $tname, $cname, $t1c, $t2c, $uc ) . "\n";

		}
#		print join( "\t", @{$tables{@dbs,'union'}} ) . "\n"; 
	print "\n\n";

	}
	print "END FIRST PART\n";

	if ( $print ) {
    for my $table ( sort( keys( %{$tables{$dbs[0]}} ) ) ) {
		  my $t1 = $tables{$dbs[0]}->{$table};
			for my $c (sort(keys(%{$t1}))) {
				print "$table\t$c\n";
			}
		}
	}



__DATA__
#SELECT distinct column_name FROM table_column WHERE table_name LIKE '%dbxref'
#SELECT distinct column_name FROM table_column WHERE table_name LIKE '___biosequence'
#SELECT distinct column_name FROM table_column WHERE table_name LIKE '%Biosequence_set'
#SELECT distinct table_name FROM sbeams.dbo.table_property WHERE table_name LIKE '___biosequence'

my $sql =<<END;
SELECT distinct table_name FROM sbeams.dbo.table_property WHERE table_name LIKE '%Biosequence_property_set'
END
$sth = $dbh->prepare( $sql );
$sth->execute();

while ( my $row = $sth->fetchrow_arrayref() ) {
  push @tabs, '$TB' . uc($row->[0]);
}
$sth->finish();

  my $table = SBEAMS::Connection::DataTable->new( BORDER => 1,
                                                  WIDTH => '100%',
                                                  ALIGN => 'CENTER' );
my $tcnt = 2;
my $ccnt = 1;
$table->addRow( ['table', keys(%cols) ] );
for my $tab ( @tabs ) {
  my $etab = $sbeams->evalSQL( $tab );
  if ( $etab ) {
    my( $cnt ) = $dbh->selectrow_array( "SELECT COUNT(*) FROM $etab" );
    $sql = "SELECT TOP 1 * FROM $etab";
    my @row = ( "$etab ($cnt)" );
    $sth = $dbh->prepare( $sql );
    $sth->execute();
    
    
    my $err = $dbh->errstr();
    if ( $err ) {
      print STDERR "Table $etab defined in driver tables but doesn't exist!\n";
      next;
    }

    my %row;
    for my $col ( @{$sth->{NAME}} ) {
      $row{$col}++;
    }
    for( keys ( %cols ) ) {
      my $color = ( exists $row{$_} ) ? '#B5FFC8' : '#FF5353';
      my $present = ( exists $row{$_} ) ? 'OK' : 'Missing';
      push @row, $present;
      my $cindx = $ccnt + 1;
      $table->setCellAttr( ROW => $tcnt, COL => $cindx, BGCOLOR => $color ); 
      $ccnt++;
    }
    $ccnt = 1;
    $tcnt++;
    $table->addRow( \@row );
  } else {
    print STDERR "No table for $tab\n";
  }

  }
$table->setColAttr( COLS => [1], ROWS => [1..$table->getRowNum()], NOWRAP => 1 );

print "<HTML><BODY>$table</BODY></HTML>";

__DATA__

    my ( $present ) = $dbh->selectrow_array( $sql );
    my $color = ( !$present ) ? '#FF5353' : '#B5FFC8';
    $present = ( !$present ) ? 'Missing' : 'OK';
    push @row, $present;
    my $cindx = $ccnt + 1;
    $table->setCellAttr( ROW => $tcnt, COL => $cindx, BGCOLOR => $color ); 
    $ccnt++;
  }
 $ccnt = 1;
 $tcnt++;
 $table->addRow( \@row );
}





