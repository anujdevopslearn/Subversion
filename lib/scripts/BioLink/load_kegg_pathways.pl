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
    $km->load_pathway_cache( organism => $organism, overwrite => 0 );
  }
}

sub update_pathway_data {
  for my $organism ( @{$args->{organism}} ) {
    $km->delete_pathway_cache( organism => $organism );
    $km->load_pathway_cache( organism => $organism, overwrite => 1 );
  }
}

sub delete_pathway_data {
  for my $organism ( @{$args->{organism}} ) {
    $km->delete_pathway_cache( organism => $organism );
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
