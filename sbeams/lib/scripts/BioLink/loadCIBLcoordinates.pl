#!/usr/local/bin/perl -w

# $Id$

use DBI;
use DBD::mysql;
use Getopt::Long;
use strict;

use constant COMMIT => 250;

$|++; # don't buffer output


# MAIN

{
  my $args = processArgs();
  my $dbh = dbConnect( $args );
  insertRecords ( $args, $dbh );
}


# Fixme, validation of column order
sub checkCols {
  return 1;
}

sub insertRecords {

  my $args = shift;
  my $dbh = shift;

  my $baseSQL = getInsertSQL( $dbh );
  my %col_types = getColMap( 'hash' );
  my @col_index = getColMap( 'array' );
  my $ctr = 0;
  my $organism;

  open ( RECS, "$args->{inputfile}" ) || die ( "Unable to open file $args->{inputfile}" );
  while ( my $line = <RECS> ) {
    chomp $line;
    my @line = split( "\t", $line, -1 );
    if ( !$ctr ) {
      $ctr++;
      die "Failed column check\n" unless checkCols( \@line );
    } else {
      $ctr++;

      # Add organism
      push @line, ( $line[1] =~ /^mm/ ) ? 6 : 2;  # human = 2, mouse = 6, cheesy

      my $valString = '';
      my $delim = '';
      $line[9] = substr( $line[9], 0, 255 );
      for (my $i = 0; $i <= $#line; $i++ ) {
        $line[$i] =~ s/\'//g;
        if ( $col_types{$col_index[$i]} =~ /char/i ) {
          $valString .= "$delim '$line[$i]'";
        } else {
          $valString .= "$delim $line[$i]";
        }
        $delim = ', ';
      }
      ( my $execSQL =  $baseSQL ) =~ s/XXXXXX/$valString/g;

      $dbh->do( $execSQL );

      unless( $ctr % COMMIT ) {
        print "*";
        $dbh->commit();
      }
      print "\t $ctr \n" unless $ctr % ( COMMIT * 20 );
    }
  }
  print "\t $ctr \n";
  $dbh->commit();
  $dbh->disconnect();
  
}

sub getInsertSQL {

  my $dbh = shift;
  my @cols = getColMap( 'array' );
 
  my $colstr = join( ", ", @cols );
  my $sql = "INSERT INTO CIBL_genome_coordinates ( $colstr ) VALUES ( XXXXXX )";
  
  return $sql;
}


sub dbConnect {
  my $args = shift;
  my $cString = "DBI:Sybase:server=$args->{host};database=$args->{dbname}";
  my $dbh = DBI->connect( $cString, "$args->{user}", "$args->{pass}" ) || die ('couldn\'t connect' );
  $dbh->{AutoCommit} = 0;
  $dbh->{RaiseError} = 1;
  return $dbh;
}

sub processArgs {
  my %args;
  GetOptions ( \%args, 'pass=s', 'user=s', 'host=s',
                       'inputfile=s', 'dbname=s' );
  for ( qw( pass user host inputfile dbname ) ) {
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

   Usage: $0 -h dbhost -u username -p password -d dbname -i input_file
   Usage: $0 -h mssql -u sbeams -p sbeamspass -d biolink -i MOE430A.mm5.map

   -h --host    hostname of machine running database
   -u --user    username to authenticate to the db
   -p --pass    password to authenticate to the db
   -d --dbname  name of database to use
   -i --inputfile   record file which holds data to insert
  EOU
}

sub getColMap {
  my $mode = shift;
  if ( $mode eq 'hash' ) {
    my %cols  = ( Probe_Set_Name => 'varchar',
                  Genome_Build => 'varchar',
                  Chromosome => 'varchar',
                  gene_start => 'int',
                  gene_end => 'int',
                  Strand => 'char',
                  DoTS => 'varchar',
                  GenBank => 'varchar',
                  Gene_Symbol => 'varchar',
                  Gene_Synonyms => 'varchar',
                  organism_id => 'int'
                 );
  return ( %cols );
  } elsif ( $mode eq 'array' ) {
    my @cols  =  qw( Probe_Set_Name Genome_Build Chromosome 
                     gene_start gene_end Strand DoTS GenBank Gene_Symbol
                     Gene_Synonyms organism_id );
    return ( @cols );
  }
  return undef;
}
