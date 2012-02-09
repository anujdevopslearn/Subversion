#!/usr/local/bin/perl -w

use DBI;
use Getopt::Long;
use FindBin qw( $Bin );

use lib "$Bin/../../perl";
use SBEAMS::Connection::Settings qw( $DBCONFIG $DBINSTANCE );
use strict;

use constant COMMIT => 20;

$|++; # don't buffer output

{ # MAIN

  # If no args are given, print usage and exit
  if (! @ARGV) {
    printUsage();
    exit 0;
  }

  my $args = processArgs();
  my $cmds = parseFile ( $args );
  if ( $args->{test_mode} ) {
    printCommands( $args, $cmds );
    exit;
  }
  my $dbh = dbConnect( $args );

 if ( $args->{query_mode} ) {
    printResults( $args, $dbh, $cmds );
  } else {
    insertRecords( $args, $dbh, $cmds );
  }
  $dbh->disconnect();
  exit 0;
}

sub parseXML {
  my $args = shift;
  my @cmds;

  # Otherwise, parse the file as usual.
  print "Parsing command file $args->{sfile}\n" if $args->{verbose};

  open( FIL, $args->{sfile} ) || die "Unable to open file $args->{sfile}";
  my @fields;
  my @values;
  my $table;
  while ( my $line = <FIL> ) {

    chomp $line;
    next if $line =~ /^\s*$/;
    next if $line =~ /^<SBEAMS_EXPORT/;
    next if $line =~ /^<\?xml/;

    if ( $line =~ /\/>/ ) {
      my $cmd = "INSERT INTO $table (" . join( ", ", @fields ) . ") VALUES ( " . join( ", ", @values ) . ")\n";
      push @cmds, $cmd;
      @values = ();
      @fields = ();
    } elsif ( $line =~ /<\s*(\w+)/ ) {
      $table = ( $args->{database} ) ? "$args->{database}.dbo.$1" : $1;
    } else {
      my @entry = split( "=", $line );
      for my $item ( @entry ) {
        $item =~ s/^\s+//;
        $item =~ s/\s+$//;
        if ( $item =~ /CURRENT_TIMESTAMP|NULL/i ) {
          $item =~ s/\"//g;
        } else {
          $item =~ s/\"/'/g;
        }
      }
      push @fields, $entry[0];
      push @values, $entry[1];
    }
  }
  return \@cmds;
}

sub parseFile {
  my $args = shift;
  my @cmds;
  my $cmd = '';

  # Manual queries take precedence...
  if ( $args->{manual_mode} ) {
    # This is gonna be querymode.
    $args->{query} ||= 1;
    print "Running manual query\n";
    return( [ $args->{manual} ] );
  }

  if ( $args->{xml} ) {
    return parseXML( $args );
  }

  # Otherwise, parse the file as usual.
  print "Parsing command file $args->{sfile}\n" if $args->{verbose};
  open( FIL, $args->{sfile} ) || die "Unable to open file $args->{sfile}";
  while ( my $line = <FIL> ) {
    #chomp $line;
    next if $line =~ /^\s*$/;

    #### If the user opts to ignore Audit Trail FOREIGN KEYS, stop when found
    if ($args->{no_audit_constraints} && $line =~ /Audit trail FOREIGN KEYS/) {
      last;
    }

    if ( $args->{delimiter} eq 'GO' ) {
      if ( $line =~ /^GO\s*$/i ) {
        push @cmds, $cmd;
        $cmd = '';
      } else {
        $cmd .= "$line\n";
      }
    } else {
      if ( $line =~ /;\s*$/ ) {
        $cmd .= $line;
        push @cmds, $cmd;
        $cmd = '';
      } else {
        $cmd .= $line;
      }
    }
  }
  push @cmds, $cmd if $cmd;  # Leftovers
  return( \@cmds );
}

sub printCommands {
  my $args = shift;
  my $sql = shift;
  my $cnt = 0;
  foreach my $sql ( @$sql ) {
    $cnt++;
    print "--Stmt $cnt\n";
    print "$sql\n";
  }
}

sub printResults {
  my $args = shift;
  my $dbh = shift;
  my $sql = shift;

  # set default filename
  $args->{outfile} ||= '/tmp/sql_output_file.tsv';
  open OUTFILE, ">$args->{outfile}" || die "couldn't open $args->{outfile}";
  foreach my $sql ( @$sql ) {
    if ( $sql !~ / UPDATE | DROP | INSERT | DELETE | TRUNCATE /gi ) {
      print "$sql\n";  # Query mode implies a certain amount of verbosity!
      my $sth = $dbh->prepare( $sql );
      $sth->execute();
      my $firstrow = 1;
      my $cnt = 0;
      while ( my $row = $sth->fetchrow_arrayref() ) {
        
        $cnt++;
        if ( $firstrow ) {
          print OUTFILE join( "\t", @{$sth->{NAME}} ) . "\n";
          $firstrow = 0;
        }
        my @row;
        for my $val ( @{$row} ) {
          $val = ( defined $val ) ? $val : '';
          push @row, $val;
        }


        print OUTFILE join( "\t", @$row ) . "\n";
      }
    } else {
      print "Query mode is read-only, not running $sql";
    }
  }
}

sub insertRecords {
  my $args = shift;
  my $dbh = shift;
  my $cmds = shift;
  
  my $cnt;
  foreach my $cmd ( @$cmds ) {
    $cnt++;
    print "$cmd\n" if $args->{verbose};
    $dbh->do( $cmd );
#    $dbh->commit() unless $cnt % COMMIT;
  }
#  $dbh->commit();
}

sub dbConnect {
  my $args = shift;

  # Get db driver from configuration file
  my $DB_SERVER = $DBCONFIG->{$DBINSTANCE}->{DB_SERVER};
  my $DB_DATABASE = $args->{database} || $DBCONFIG->{$DBINSTANCE}->{DB_DATABASE};
  my $cstring = eval "\"$DBCONFIG->{$DBINSTANCE}->{DB_DRIVER}\"";

  my $dbh = DBI->connect( $cstring, $args->{user}, $args->{pass} ) || die ('couldn\'t connect' );
#  $dbh->{AutoCommit} = 0;
  $dbh->{RaiseError} = ( $args->{ignore_errors} ) ? 0 : 1;

  $dbh->{PrintError} = ( $args->{quiet} ) ? 0 : 1;

  print "Connected to database successfully\n" if $args->{verbose};
  return $dbh;
}

sub processArgs {
  my %args;
  unless( GetOptions ( \%args, 'pass=s', 'user=s', 'verbose', 'sfile=s',
                      'delimiter=s', 'ignore_errors', 'manual:s',
                      'no_audit_constraints', 'database=s', 'query_mode', 
                      'test_mode', 'quiet|q', 'outfile=s', 'xml' ) ) {
  printUsage("Error with options, please check usage:");
  }

  for ( qw( user ) ) {
    if ( !defined $args{$_} ) {
    printUsage( "Missing required parameter: $_" ) unless $args{test_mode}; 
    }
  }
  unless( $args{manual} || $args{sfile} ) {
    printUsage( "Must specify either a sql file or a manual query" );
  }

  # User declined to enter a password, prompt for one
  while ( !$args{pass} ) {
    if ($args{test_mode}) {
      $args{pass} = 'testing';
      next;
    }
    print "Enter password, followed by [Enter] (cntl-C to quit):\t";
    $|++;
    system("stty -echo");
    my $pass = <>;
    system("stty echo");
    chomp $pass;
    print "\n";
    if ( $pass ) {
      #( my $err = $pass ) =~ s/[\w\#]//g;
      #die "Illegal characters in password: $err \n" if $err;
      $args{pass} = $pass;
    } else {
      print "No input received.\n";
      $|++;
    }
  }
  
  # Delimiter will either be semicolon or GO
  $args{delimiter} = ( !$args{delimiter} ) ? ';' :
                     ( uc($args{delimiter}) eq 'GO' ) ? 'GO' : ';'; 

  return \%args;
}

sub printUsage {
  my $err = shift || '';
  print( <<"  EOU" );
   $err
   
   Usage: $0 -u username -s sfile [ -p password ]

   -u --user xxxx     username to authenticate to the db
   -p --pass xxxx     password to authenticate to the db.  Will be prompted
                      if value is ommitted.
   -s --sfile xxxx    SQL file which defines table and columns etc
   -o --outfile xxxx  File to which to write output in query mode
   -v --verbose       verbose output
   -i --ignore_errs   Ignore SQL errors and continue
      --delimiter xx  Delimter for splitting file, semicolon (default) or GO.
      --query_mode    Run (SELECT) query(s) and print results.
   -t --test_mode     Parse file and simply print out each statement that would have been executed. 
   -m --manual        SELECT query provided explicitly, obviates the need for
                      a SQL file.
   -n --no_audit_constraints  If set, then the Audit Trail FOREIGN KEYS are skipped
      --database      Specify a database to initially connect to besides the default
      --quiet         Suppress printing of database errors
   -x, --xml          File is in generic SBEAMS XML format
     
  EOU
  exit;
}
