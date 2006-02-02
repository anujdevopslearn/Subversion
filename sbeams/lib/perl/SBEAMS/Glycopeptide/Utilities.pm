package SBEAMS::Glycopeptide::Utilities;

sub new {
  my $class = shift;
  my $this = {};
  bless $this, $class;
  return $this;
}


sub clean_pepseq {
  my $this = shift;
  my $seq = shift || return;
  $seq =~ s/\-MET\(O\)/m/g;
  $seq =~ s/N\*/n/g;
  $seq =~ s/N\#/n/g;
  $seq =~ s/M\#/m/g;
  $seq =~ s/d/n/g;
  $seq =~ s/U/n/g;
  $seq =~ s/^.\.//g;
  $seq =~ s/\..$//g;
  return $seq;
}
1;

__DATA__
#!/tools/bin/perl -w

BEGIN {
unshift ( @INC, '/net/dblocal/www/html/sbeams/lib/perl' );
}

use strict;
$|++; # don't buffer output

usage() unless $ARGV[0];

my $file = read_file( $ARGV[0] );
print "\n";

my $pdet = $file->{IDX}{'Detection Probability'};
my $pepP = $file->{IDX}{'Peptide ProPhet'};
my $pipi = $file->{IDX}{'IPI'};

my %ipi = %{$file->{DAT_H}};

my ( %all, %det, %ndet );
my $skip;
my $cnt;
my $det = 0;
my $non = 0;
my $tot = scalar( keys( %ipi ) );
my $pp = 0;
my $pp_all;

for my $row ( @{$file->{DAT_A}} ) {
  $cnt++;
  $pp_all++ if $row->[$pepP];
  if ( $row->[$pdet] == -1 ) {
    $pp++ if $row->[$pepP];
    $skip++;
    next;
  }
  my $bin = int( $row->[$pdet] * 100 );
  $all{$bin}++;
  
# If it is a detected protein
  if ( $ipi{$row->[$pipi]} ) {
    if ( $row->[$pepP] ) {
      $det++;
      $det{$bin}++
    } else {
      $non++;
      $ndet{$bin}++
    }
  }
}

print "Saw a total of $skip of $cnt peptides with det_prob of -1, $pp were detected\n";
print "Saw $det peptides from $tot detected proteins, $non were not seen\n"; 
print "Does $det + $pp = $pp_all?\n";
open OUTFILE, ">/tmp/histogram.csv";
print OUTFILE "Bin\tTotal\tDetected\tNotDetected\n";

for ( my $i = 0; $i <= 100; $i++ ) {
  $det{$i} ||= 0;
  $all{$i} ||= 0;
  $ndet{$i} ||= 0;
  print OUTFILE "$i\t$all{$i}\t$det{$i}\t$ndet{$i}\n";
}




sub read_file {
  my $file = shift;
  my $hash = shift || 0;
  open( INFIL, "$file" ) || die "Unable to open file: $file";

  my @heads;
  my %idx;
  my @data;
  my %data;
  my $cnt;

  print "\n\nReading input file $file:\n";
  while( my $line = <INFIL> ) {
    $cnt++;
    print "*" unless $cnt % 1000;
    print "\n" unless $cnt % 30000;
    chomp $line;
    unless( scalar(@heads) ) {
      @heads = split( "\t", $line, -1 );
      my $i = 0;
      for my $h ( @heads ) {
        $idx{$h} = $i++;
      }
      next;
    }
    my @guts = split( "\t", $line, -1 );
    push @data, \@guts;
    # make a hash of all seen IPI's 
    $data{$guts[$idx{IPI}]}++ if $guts[$idx{'Peptide ProPhet'}];
  }
  my %return = ( IDX => \%idx, DAT_A => \@data, DAT_H => \%data );
  return \%return;
}

sub usage {
  print "Usage: $0 filename filename\n";
  exit;
}
#!/tools/bin/perl -w

BEGIN {
unshift ( @INC, '/net/dblocal/www/html/sbeams/lib/perl' );
}

use DBI;
#use DBD::Sybase;


use strict;
$|++; # don't buffer output

{  # MAIN

  my $dbh = getDBH();
  my $file = $ARGV[0] || die "usage: insert_prediction_scores.pl filename";
  open( INFIL, "<$file" ) || die "Unable to open file: $file";

  my @heads;
  my %idx;
  my @ipi;
  my $cnt;
  print "\n\nReading input file $file:\n";
  while( my $line = <INFIL> ) {
    $cnt++;
    print "*" unless $cnt % 1000;
    print "\n" unless $cnt % 40000;
    chomp $line;
    unless( scalar(@heads) ) {
      @heads = split( "\t", $line, -1 );
      my $i = 0;
      for my $h ( @heads ) {
        $idx{$h} = $i++;
      }
      # print "$idx{'Predicted Tryptic NXT/S Peptide Sequence'}\n";
      next;
    }
    my @guts = split( "\t", $line, -1 );
    push @ipi, { IPI => $guts[$idx{IPI}],
                 SEQ => $guts[$idx{'Predicted Tryptic NXT/S Peptide Sequence'}],
                 DPR => $guts[$idx{'Detection Probability'}],
               };
  }
  $cnt = 0;
  print "\nFinished\n\n";
  print "Fetching records from database.\n";
  my %rec_stat = ( good => 0, bad => 0 );
  my @bad;
  foreach my $ipi ( @ipi ) {
    $cnt++;
    print "*" unless $cnt % 100;
    print "\n" unless $cnt % 4000;
    my $sql =<<"    END";
    SELECT predicted_peptide_id 
    FROM dcampbel.dbo.predicted_peptide pp 
    JOIN dcampbel.dbo.ipi_data id
    ON id.ipi_data_id = pp.ipi_data_id
    WHERE id.ipi_accession_number = '$ipi->{IPI}'
    AND pp.predicted_peptide_sequence LIKE '$ipi->{SEQ}'
    END
#    print "$sql\n";
    my ( $pp_id ) = $dbh->selectrow_array( $sql );
    if ( $pp_id ) {
      $rec_stat{good}++;
      my $usql =<<"      END";
      UPDATE predicted_peptide 
      SET detection_probability = $ipi->{DPR}
      WHERE predicted_peptide_id = $pp_id
      END
#$dbh->do( $usql );
    } else {
      $rec_stat{bad}++;
      push @bad, [ $ipi->{IPI}, $ipi->{SEQ} ];
    }
  }
  print "\nFound $rec_stat{good} existing records, $rec_stat{bad} were not found\n";

  foreach my $b ( @bad ) {
    print "$b->[0]\t$b->[1]\n";
  }
  exit 0;

}


sub getDBH {
  my $cstring = "DBI:Sybase:server=mssql;database=dcampbel";
  my $dbh = DBI->connect( $cstring, 'dcampbel', 'Dav413' ) || die( "fails" );
}

#!/usr/local/bin/perl -w

## Work in progress, trying to make generic SQL loader more intelligent

use DBI;
use DBD::mysql;
use Getopt::Long;
use strict;

use constant COMMIT => 250;

$|++; # don't buffer output

my $dbh;

# MAIN

{
  
  my $args = processArgs();
  $dbh = dbConnect( $args );
  my $info = readTableFile ( $args );
  insertRecords ( $args, $info );
}

sub readTableFile {
  my $args = shift;
  my %tInfo;
  open ( TAB, "$args->{tfile}" ) || die ( "Unable to open file $args->{tfile}\n" );
  while( my $line = <TAB> ) {
    chomp $line;
    my ( $name, $type ) = ( $line =~ /^([^=]+)=(.+)$/ );
#    print "Name is $name, Type is $type\n" if $args->{verbose};
    if ( uc( $name ) eq 'TABLE' ) {
      $tInfo{_tablename_} = $type;
    } else {
      $tInfo{$name} = $type;
      print "$name => $type\n" if $args->{verbose};
    }
  } 
  close TAB;
  return \%tInfo;
}

sub finish_load {
  $dbh->disconnect();
  exit;
}

sub insertRecords {

  my $args = shift;
  my $info = shift;
  my $ctr = 0;
  my $refnum;
  my @heads;
  my %idx;
  my $baseSQL;

  open ( RECS, "$args->{rfile}" ) || die ( "Unable to open file $args->{rfile}" );
  while ( my $line = <RECS> ) {

# Skip header line?
    chomp $line;
    $ctr++;
    my @line = split( "\t", $line, -1 );
    my $inum = scalar( @line );
    print "Found $inum items on line $ctr\n" if $args->{verbose};
    #my @nline;

    if ( !scalar(@heads) ) {
      # In header loop
      print "header contents: " . join( "::", @line ) . "\n" if $args->{verbose};

      @heads = @line;
      $refnum = scalar( @heads );

      my @c = keys( %{$info} );
      for ( @c ) { 
        print "$_ => $info->{$_}\n";
      }
      my $ictr = 0;
      for my $h ( @heads )  {
        die "Missing column info for $h\n" unless ( grep /^$h$/, @c );
        $idx{$ictr} = $h; 
        $ictr++;
      }
      $baseSQL = getBaseSQL( $info, \@heads );
      next;
    }

    # KLUGE!  had this on to set a default value for a not null column.
    #if (!$line[1]) {
    if (0) {
     $line[1] = $line[0];
     print "noline 1\n";
     next unless $line[0];
     print "line 0\n";
    }


    print "line contents: " . join( "::", @line ) . "\n" if $args->{verbose} && $ctr < 5;
    my @nline = map { (defined $_) ? $_ : 'NULL' } @line;
    @nline = map { ($_ ne '') ? $_ : 'NULL' } @line;

    for my $val ( @line ) {
      $val = 'NULL' unless defined $val;
      $val = 'NULL' if $val eq '';
#      $val =~ s/\'//g;
      $val =~ s/\"//g;
      push @nline, $val;
    }

    print join( "::", @nline ) . "\n" if $args->{verbose} && $ctr < 5;

    my $valString = '';
    my $delim = '';
#    $line[9] = substr( $nline[9], 0, 255 );
    for( my $i = 0; $i <= $#heads; $i++ ) {

      if ( $nline[$i] eq 'NULL' ) {
        $valString .= "$delim $nline[$i]";
      } elsif ( $info->{$idx{$i}} =~ /char/i ) {
#        $nline[$i] = substr( $nline[$i], 0, 250 );
        $valString .= "$delim '$nline[$i]'";
      } else {
        #$nline[$i] =~ s/(\d+);.*/$i/g;
        $valString .= "$delim $nline[$i]";
      }
      # print "$valString\n";
      $delim = ', ';
    }
    #print join( "::", @line ) . "\n";
#    print "Base is: $baseSQL\n";
#    print "Valstr is: $valString\n";
    my $execSQL =  $baseSQL . $valString . ')';
      
    eval {
    $dbh->do( $execSQL );
    };
    if ( $@ ) { die ( $execSQL ); }

    unless( $ctr % COMMIT ) {
      print "*";
      $dbh->commit();
    }
    print "\t $ctr \n" unless $ctr % ( COMMIT * 20 );
  }
  print "\t $ctr \n";
  $dbh->commit();
  $dbh->disconnect();
}

sub getBaseSQL {

  my $info = shift;
  my $cols = shift;

  my $colstr = join( ", ", @$cols );
  my $sql = "INSERT INTO $info->{_tablename_} ( $colstr ) VALUES ( ";
  
  return $sql;
}


sub dbConnect {

  my $args = shift;
#my $cString = "DBI:mysql:host=$args->{host};database=$args->{dbname}";
  my $cString = "DBI:Sybase:server=$args->{host};database=$args->{dbname}";
  $dbh = DBI->connect( $cString, "$args->{user}", "$args->{pass}" ) || die ('couldn\'t connect' );
  $dbh->{AutoCommit} = 0;
  $dbh->{RaiseError} = 1;
  return $dbh;
}

sub processArgs {
  my %args;
  GetOptions ( \%args, 'pass=s', 'user=s', 'host=s', 'verbose',
                       'tfile=s', 'rfile=s', 'dbname=s', 'noheads' );
  for ( qw( pass user host tfile rfile dbname ) ) {
    if ( !defined $args{$_} ) {
    print usage($_); 
    exit;
    }
  }
  return \%args;
}

sub usage {
  my $err = shift;
  return( <<"  EOU" );
   Error: must provide $err:

   Usage: $0 -h dbhost -u username -p password -d dbname -t tfile -r rfile

   Options with arguments
   -h --host    hostname of machine running database
   -u --user    username to authenticate to the db
   -p --pass    password to authenticate to the db
   -t --tfile   table file which defines table and columns
   -r --rfile   record file which holds data to insert
   -d --dbname  name of database to use

   Options with no arguments
   -n --noheads No header in rfile, order in tfile must match order in rfile
   -v --verbose Provide verbose output

  EOU
}
#!/tools/bin/perl -w

BEGIN {
unshift ( @INC, '/net/dblocal/www/html/sbeams/lib/perl' );
}

use DBI;


use strict;
$|++; # don't buffer output

usage() unless $ARGV[0] && $ARGV[1];

my $secondary = read_file( $ARGV[0] );
my $primary = read_file( $ARGV[1] );
print "\n";

open OUTFILE, ">/tmp/merged_file.tsv";

for (keys( %{$primary->{IDX}})) {
#  print "Primary: $_ => $primary->{IDX}{$_}\n";
}
print "\n";
for (keys( %{$secondary->{IDX}})) {
#  print "Secondary: $_ => $secondary->{IDX}{$_}\n";
}
my %sec = %{$secondary->{DAT_H}};
my $pdet = $primary->{IDX}{'Detection Probability'};
my $pipi = $primary->{IDX}{'IPI'};
my $pseq = $primary->{IDX}{'Predicted Tryptic NXT/S Peptide Sequence'};

print OUTFILE join ("\t", @{$primary->{HEADS}}) . "\n";
for my $row ( @{$primary->{DAT_A}} ) {

  my $key = $row->[$pipi] . ':::' . $row->[$pseq];

  $row->[$pdet] = $sec{$key};
  if ( !$sec{$key} ) {
    print "Freakin lizards, yo!\n";
  }
  print OUTFILE join ("\t", @{$row}) . "\n";
   # $data{$[$idx{IPI}] . ':::' .  $guts[$idx{'Predicted Tryptic NXT/S Peptide Sequence'}]} = \@guts;
}

sub read_file {
  my $file = shift;
  my $hash = shift || 0;
  open( INFIL, "<$file" ) || die "Unable to open file: $file";

  my @heads;
  my %idx;
  my @data;
  my %data;
  my $cnt;

  print "\n\nReading input file $file:\n";
  while( my $line = <INFIL> ) {
    $cnt++;
    print "*" unless $cnt % 1000;
#    last unless $cnt % 2;
    print "\n" unless $cnt % 30000;
    chomp $line;
    unless( scalar(@heads) ) {
      @heads = split( "\t", $line, -1 );
      my $i = 0;
      for my $h ( @heads ) {
        $idx{$h} = $i++;
      }
      # print "$idx{'Predicted Tryptic NXT/S Peptide Sequence'}\n";
      next;
    }
    my @guts = split( "\t", $line, -1 );
    push @data, \@guts;
    # making a hash of ipi::sequence => prob score, for easy lookup later...
    $data{$guts[$idx{IPI}] . ':::' .  $guts[$idx{'Predicted Tryptic NXT/S Peptide Sequence'}]} =  $guts[$idx{'Detection Probability'}];
  }
  my %return = ( IDX => \%idx, DAT_A => \@data, DAT_H => \%data, HEADS => \@heads );
  return \%return;
}

sub usage {
  print "Usage: $0 filename filename\n";
  exit;
}
#!/tools/bin/perl -w

BEGIN {
unshift ( @INC, '/net/dblocal/www/html/sbeams/lib/perl' );
}

use DBI;


use strict;
$|++; # don't buffer output

{  # MAIN

  my $dbh = getDBH();
  my $file = $ARGV[0] || die "usage: $0 filename";
  open( INFIL, "<$file" ) || die "Unable to open file: $file";

  my @heads;
  my %idx;
  my %ipi;
  my $cnt;
  print "\n\nReading input file $file:\n";
  while( my $line = <INFIL> ) {
    $cnt++;
    print "*" unless $cnt % 1000;
    print "\n" unless $cnt % 30000;
    chomp $line;
    unless( scalar(@heads) ) {
      @heads = split( "\t", $line, -1 );
      my $i = 0;
      for my $h ( @heads ) {
        $idx{$h} = $i++;
      }
      # print "$idx{'Predicted Tryptic NXT/S Peptide Sequence'}\n";
      next;
    }
    my @guts = split( "\t", $line, -1 );
    # making a hash of ipi::sequence => prob score, for easy lookup later...
    $ipi{$guts[$idx{IPI}] . ':::' .  $guts[$idx{'Predicted Tryptic NXT/S Peptide Sequence'}]} = $guts[$idx{'Detection Probability'}];
  }
  $cnt = 0;
  print "\nFinished\n\n";
  print "Fetching records from database.\n";
  my $sql =<<"  END";
  SELECT detection_probability, id.ipi_accession_number, pp.predicted_peptide_sequence,
  predicted_peptide_id
  FROM dcampbel.dbo.predicted_peptide pp 
  JOIN dcampbel.dbo.ipi_data id
  ON id.ipi_data_id = pp.ipi_data_id
  END
  my $sth = $dbh->prepare( $sql );
  $sth->execute();

  my %rec_stat = ( good => 0, bad => 0, lost => 0 );
  my @bad;
  while( my @row = $sth->fetchrow_array() ) {
    $cnt++;
    print "*" unless $cnt % 1000;
    print "\n" unless $cnt % 30000;

    $row[0] ||= 0;

    my $file_value = $ipi{$row[1] . ':::' . $row[2]};

    if ( defined $file_value ) {
    
      my $dbprob = sprintf( "%.5f", $row[0]); 
      my $fileprob = sprintf( "%.5f",$ipi{$row[1] . ':::' . $row[2]} );

      if ( $dbprob == $fileprob ) {
        $rec_stat{good}++;
      } else {
        $row[0] = $fileprob;
        push @bad, \@row;
        $rec_stat{bad}++;
      }

    } else {
      $rec_stat{lost}++;
    }

  }
  print "\n $rec_stat{good} scores matched, $rec_stat{bad} did not, and $rec_stat{lost} were missing\n";

  my $usql =<<"  END";
  UPDATE dcampbel.dbo.predicted_peptide 
  SET detection_probability = DETECTION
  WHERE predicted_peptide_id = PREDICTED_ID
  END
  print "Updating erroneous records\n";
  my $ucount = 0;
  open LOGFILE, ">/tmp/update.log";
  for my $row ( @bad ){
    next unless $row->[0] && $row->[3];
    $ucount++;
    print "*" unless $ucount % 100;
    print "\n" unless $ucount % 3000;

    my $update_sql = $usql;
    $update_sql =~ s/DETECTION/$row->[0]/;
    $update_sql =~ s/PREDICTED_ID/$row->[3]/;
    print LOGFILE "$update_sql\n\n";
    #$dbh->do( $update_sql );
  }
  print "Updated $ucount records\n";

  exit 0;

}


sub getDBH {
  my $cstring = "DBI:Sybase:server=mssql;database=dcampbel";
  my $dbh = DBI->connect( $cstring, 'dcampbel', 'Dav413' ) || die( "fails" );
}

