#!/usr/local/bin/perl 

###############################################################################
# Program     : load_RTcatalog_scores.pl
# Author      : zsun <zsun@systemsbiology.org>
# 
#
# Description : This script load the database for RTcatalog values
#
###############################################################################

use strict;
use Getopt::Long;
use File::Basename;
    use Data::Dumper;
use FindBin;
#### Set up SBEAMS modules
use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use vars qw ($sbeams $atlas $q $current_username $PROG_NAME $USAGE %opts
             $QUIET $VERBOSE $DEBUG $TESTONLY $TESTVARS $CHECKTABLES );

# don't buffer output
$|++;

## Globals
$sbeams = new SBEAMS::Connection;
$atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
$PROG_NAME = basename( $0 );
## Set up environment

## Process options
GetOptions( \%opts,"verbose:s","quiet","debug:s","testonly", 'list_file:s', 
            'domain_list_id:i', 'help', 'force' ) 
            || usage( "Error processing options" );

$VERBOSE = $opts{"verbose"} || 0;
$QUIET = $opts{"quiet"} || 0;
$DEBUG = $opts{"debug"} || 0;
$TESTONLY = $opts{"testonly"} || 0;
 
my $mia;
for my $opt ( qw( domain_list_id list_file ) ) {
  if ( !defined ( $opts{$opt} ) ) {
    $mia = ( $mia ) ? $mia . ',' . $opt : "Missing required option(s): $opt";
  }
}
usage( $mia ) if $mia;

if($opts{"help"}){
 usage();
}


if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  $current_username = $sbeams->Authenticate( work_group=>'PeptideAtlas_admin' ) || exit;

  if ( $opts{domain_list_id} ) {
    check_list( $opts{domain_list_id} );

  } else {
    die "Must provide domain_list_id\n";
  }

  print "Fill table\n";
  fillTable(  );
  return;

} # end main

sub check_list {
  my $list_id = shift;

  my $sql = "SELECT COUNT(*) FROM $TBAT_DOMAIN_PROTEIN_LIST WHERE protein_list_id = $list_id";
  my $result = $sbeams->selectrow_arrayref( $sql );
  if ( $result->[0] ) {
    my $sql = "SELECT COUNT(*) FROM $TBAT_DOMAIN_LIST_PROTEIN WHERE protein_list_id = $list_id";
    my $result = $sbeams->selectrow_arrayref( $sql );
    if ( $result->[0] ) {
      if ( !$opts{force} ) {
        usage( "This domain protein list already has data, use --force option to purge and load new records" );
      } else {
        $sbeams->do( "DELETE FROM $TBAT_DOMAIN_LIST_PROTEIN WHERE protein_list_id = $list_id" );
        return 1;
      }
    } else {
      return 1;
    }
  } else {
    usage( "You must first load the list data via the ManageTable interface" );
  }

}


###############################################################################
# fillTable, fill $TBAT_elution_time table
###############################################################################
sub fillTable{

  my %valid = ( original_name => 1,
                original_accession  => 1,
                uniprot_accession  => 1,
                protein_symbol  => 1,
                gene_symbol  => 1,
                protein_full_name  => 1,
                priority  => 1,
                comment  => 1,
              );



  open LIST, $opts{list_file} || die;
  my %headings;
  my $cnt;
  my %keep_fields;
  while ( my $line = <LIST> ) {
    chomp $line;
    my @line = split( /\t/, $line );
    unless ( $cnt++ ) {
      my $idx = 0;
      for my $heading ( @line ) {
        my $lc_head = lc( $heading );
        if ( $valid{$lc_head} ) {
          $keep_fields{$lc_head} = $idx;
        }
        $idx++;
      }
      next;
    }
    my %rowdata;
    for my $key ( keys( %keep_fields ) ) {
      $rowdata{$key} = $line[$keep_fields{$key}];
    }
    $rowdata{protein_list_id} = $opts{domain_list_id};

    for my $id ( keys( %valid ) ) {
      $rowdata{$id} = '' if !defined $rowdata{$id};
      if ( $id eq 'protein_full_name' && length( $rowdata{$id} ) > 255 ) {
        $rowdata{$id} = substr( $rowdata{$id}, 0, 255 );
      }
    }
    if ( !$rowdata{uniprot_accession} ) {
      print STDERR "Skipping $line, no uniprot accession\n";
      next;
    }

    $sbeams->updateOrInsertRow( insert => 1,
                           table_name  => $TBAT_DOMAIN_LIST_PROTEIN,
                           rowdata_ref => \%rowdata,
                               verbose => $VERBOSE,
                           testonly    => $TESTONLY );


  }

} # end fillTable

sub usage {
  my $msg = shift || '';
#'list_file:s', 'domain_list_id:i', 'help', 'force' ) || usage( "Error processing options" );

  print <<"  EOU";

  $msg


  Usage: $PROG_NAME [opts]
  Options:

    --list_file            Name of file 
    --domain_list_id       ID of domain_list, already added via ManageTable (numeric);                  

    --verbose n            Set verbosity level.  default is 0
    --quiet                Set flag to print nothing at all except errors
    --debug n              Set debug flag
    --testonly             If set, rows in the database are not changed or added
    --help                 print this usage and exit.

   e.g.: $PROG_NAME --list listfile --domain domain_id

  EOU
  exit;
}

__DATA__
