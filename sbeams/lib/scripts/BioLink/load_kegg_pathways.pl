#!/usr/local/bin/perl

use strict;

use Getopt::Long;
use File::Basename;

use lib ( "../../perl" );
use SBEAMS::BioLink::Tables;
use SBEAMS::BioLink::KeggMaps;
use SBEAMS::Connection;

my $km = new SBEAMS::BioLink::KeggMaps();


$|++;

my $args = processArgs();
my $verbose = $args->{verbose} || 0;


{ # Main block
  
  # Decide what to do based on mode
  if ( $args->{insert} ) {
    insert_pathway_data();
  } elsif ( $args->{update} ) {
    update_pathway_data();
  } elsif ( $args->{'delete'} ) {
    delete_pathway_data();
  } else {
    usage( "Unknown mode" );
  }
} # End main


sub insert_pathway_data {
  for my $organism ( @{$args->{organism}} ) {
    $km->loadPathwayCache( organism => $organism, overwrite => 0 );
  }
}

sub update_pathway_data {
  for my $organism ( @{$args->{organism}} ) {
    $km->deletePathwayCache( organism => $organism );
    $km->loadPathwayCache( organism => $organism, overwrite => 1 );
  }
}

sub delete_pathway_data {
  for my $organism ( @{$args->{organism}} ) {
    $km->deletePathwayCache( organism => $organism );
  }
}


sub processArgs {
  my %args = ( organism => [] );
  GetOptions ( \%args, 'insert', 'update', 'delete', 'organism=s@' );

  my $modecnt = 0;
  for ( qw( insert delete update ) ) {
    $modecnt++ if defined $args{$_};
  }
  print usage( "Must specify one and only one of i/u/d" ) unless $modecnt == 1; 

  my $valid_orgs = $km->getSupportedOrganisms();
  
  if ( @{$args{organism}} ) { # If user specified orgs, check 'em
    for my $o ( @{$args{organism}} ) { 
      if ( !grep /^$o$/, @{$valid_orgs} ) {
        my $vstring = join( ",", @{$valid_orgs} );
        usage("Invalid organism $o, supported values are: $vstring");
      }
    }
  } else { # Else we're going to do all supported ones
    $args{organism} = $valid_orgs;
  }
  return \%args;
}

sub usage {
  my $err = shift || '';
  my $name = basename( $0 );

  print( <<"  EOU" );
   $err

   Usage: $name mode(-u or -d or -i) [-o organism]

   -i --insert   Insert only missing data, do not overwrite existing records 
   -u --update   Update pathway/gene info for selected organism or all 
   -i --delete   Delete genes/pathway info from db
   -o --organism Complete actions for specified organism(s); defaults to all
  EOU
  exit;
}


__DATA__

my $wsdl = 'http://soap.genome.jp/KEGG.wsdl';
print "WSDL to connect to KEGG: $wsdl\n";

# Organism(s), pathway(s) of interest
my $org = qw( hsa );
#my $gene = 'TGF-beta';
my $pathway = 'mitochondria';


# List pathways for specified organism
my @path;
my $result = SOAP::Lite
             -> service($wsdl)
             -> list_pathways($org);
print "Found " . scalar( @{$result} ) . " pathways for $org\n";

foreach my $path (@{$result}) {
  print "$path->{entry_id}\t$path->{definition}\n" if $verbose;
  push @path, $path->{entry_id} if $path->{definition} =~ /$pathway/i;
}
#exit;
#
#
#
###

  $result =  SOAP::Lite
               -> service($wsdl)
               -> get_genes_by_organism('hsa');

  print "Found " . scalar( @{$result} ) . " thingys \n";
  use Data::Dumper;
  print Dumper "$result->[0]\n";

###

foreach my $path ( @path ) {
#  print "Searching path $path\n";
  $result =  SOAP::Lite
               -> service($wsdl)
               -> get_genes_by_pathway($path);

  print "Found " . scalar( @{$result} ) . " genes in the $path pathway\n";

  my $cnt = 1;
  my %genehash;
  while ( @{$result} ) {
    my $gene_string;
    for ( my $i = 0; $i < 50; $i++ ) {
      $gene_string .= ' ' . shift( @{$result} ); 
    }
    print "processing batch #$cnt\n";
    $cnt++;
    my $gene_info =  SOAP::Lite
                   -> service($wsdl)
                   -> btit($gene_string);

    foreach my $line ( split /\n/, $gene_info ) {
      my ( $gene_id, $symbol, $defn ) = ($line =~ /$org:(\d+)\s+([^;]+);\s+(.*)/);

      # Multiple gene symbols
      if ( $symbol =~ /,/ ) {
        my @syms = split( /,/, $symbol );
        $symbol = $syms[0];
        $defn = "(AKA " . join /,/, @syms[1..$#syms] . ") $defn";
      }

      $genehash{$gene_id} = [ $symbol, $defn ];
    }
  }
  for ( keys(%genehash) ) { print "$_ => $genehash{$_}->[0] ($genehash{$_}->[1])\n" }
}


#$result =  SOAP::Lite
#             -> service($wsdl)
#             -> get_linkdb_by_entry($path, 'pathway', 1, 1000 );

#print "Found " . scalar( @{$result} ) . " elements in pathway $path\n";

#foreach my $path (@{$result}) {
#  print Dumper( $path ) . "\n" if $verbose;
#}

#!/usr/local/bin/perl -w

# $Id: loadCBILcoordinates.pl 2671 2004-11-08 23:49:41Z dcampbel $

use DBI;
use DBD::mysql;
use Getopt::Long;
use strict;

use constant COMMIT => 250;

$|++; # don't buffer output


# MAIN

{
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
  my $sql = "INSERT INTO CBIL_genome_coordinates ( $colstr ) VALUES ( XXXXXX )";
  
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
