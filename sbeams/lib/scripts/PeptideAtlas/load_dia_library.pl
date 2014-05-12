#!/usr/local/bin/perl 

###############################################################################
# Program     : load_dia_library.pl
#
# Description : Load the consensus library (msp or spectrast) into the consensus 
#               spectrum tables.
###############################################################################

use strict;
use Getopt::Long;
use FindBin;
use File::Basename qw( basename );
use Cwd qw( abs_path );

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $PROG_NAME $USAGE %options $QUIET $VERBOSE $DEBUG $TESTONLY
         );
$|++;


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [options]
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --help                 Print usage statement and exit

  --load                 load the library
  --test                 test only, don't write records
  --path                 path to DIA library file
  --format               format of DIA library file, one of peakview, sptxt, traml
  --comment              Description of library. 
  --library_name         Name for consensus library
  --organism_name        Organism name (e.g. yeast, Human,...)

  --delete id            delete the library with dia_library_id
  --list                 List existing library name/id pairs

 e.g.: ./$PROG_NAME --path /data/mtb_peakview.tsv --library_name 'Mtb_peakview' --organism_name Mtb --load
EOU


#### Process options
unless (GetOptions(\%options,"verbose:s","quiet","debug:s","test", 'help',
                   "load", "library_name:s", "organism_name:s", 'list', 'format:s',
                   "path:s", "delete:s", 'comment=s', "project_id:i", 'instrument:s', 
                   ) ) {
    print "\n$USAGE\n";
    exit;
  }

$VERBOSE = $options{"verbose"} || 0;

$QUIET = $options{"quiet"} || 0;

$DEBUG = $options{"debug"} || 0;

$TESTONLY = $options{"test"} || 0;

unless ( $options{'delete'}  || $options{'load'} || $options{'test'} || $options{list} ) {
    print "\n$USAGE\n";
    print "Need --load or --test or --delete id\n";
    exit(0);
}

if ( $options{'load'} || $options{'test'} ) {
  my $err = 0;
  for my $opt ( qw( path library_name organism_name project_id format instrument ) ) { 
    $err++ unless defined $options{$opt};
  }
  if ( $err ) {
    print "\n$USAGE\n";
    print "Need --path, --library_name, --project_id, --format, --organism_name, and --instrument\n";
    exit(0);
  }

  my $instrument_id = '';
  my $sth = $sbeams->get_statement_handle( "SELECT DISTINCT instrument_type_name, instrument_type_id FROM $TBAT_INSTRUMENT_TYPE" );
  while( my @row = $sth->fetchrow_array() ) {
    if ( lc( $row[0] ) eq lc( $options{instrument} ) ) {
      $instrument_id = $row[1];
      last;
    }
  }
  if ( !$instrument_id ) {
    print "\nUnable to find an instrument with the name $options{instrument}... exiting\n\n";
    sleep 2;
    print $USAGE;
    exit;
  }
  $options{instrument_id} = $instrument_id;

}

if ( $options{help} ) {
    print "\n$USAGE\n";
    exit(0);
}

if ( $options{list} ) {
  printBuildList();
  exit(0);
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
sub main 
{
  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless (
      $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
  );

  $sbeams->printPageHeader() unless ($QUIET);

  handleRequest();

  $sbeams->printPageFooter() unless ($QUIET);

} # end main


###############################################################################
# handleRequest
###############################################################################
sub handleRequest 
{
    my %args = @_;

    if ($options{load} || $options{test} )
    {
        my $organism_id = getOrganismId(
            organism_name => $options{organism_name} 
        );

        ## make sure file exists
        my $file_path = abs_path( $options{path} );
        my $file_name = basename( $file_path );

        unless (-e $file_path)
        {
          print "File does not exist: $file_path\n";
          exit(0);
        }
        my $checksum = `md5sum $file_path`;
        $checksum =~ /^(\S+)\s+.*$/;
        $checksum = $1;

        populateRecords(organism_id => $organism_id, 
                          file_path => $file_path,
                        file_format => $options{format},
                             md5sum => $checksum,
                         project_id => $options{project_id},
                 instrument_type_id => $options{instrument_id},
                   dia_library_name => $file_name,
                    dia_library_tag => $options{library_name},
                            comment => $options{comment}
                       );
    }

    if ($options{delete}) {
        removeConsensusLibrary( dia_library_id => $options{delete} );
        exit 0;
    }

} # end handleRequest


###############################################################################
# populateRecords - populate consensus spectrum records with content of file
# 
# @param organism_id - organism id
# @param file_path - absolute path to library .msp file
###############################################################################
sub populateRecords
{
  my %args = @_;

  print "Loading library $args{dia_library_name}\n";

  ## create a dia_library record:
  my $dia_library_id = $sbeams->updateOrInsertRow(
      table_name=>$TBAT_DIA_LIBRARY,
      insert=>1,
      rowdata_ref=>\%args,
      PK => 'dia_library_id',
      return_PK=>1,
      add_audit_parameters => 1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
  );

}


###############################################################################
#  getOrganismId
# @param organism_name - organism name (e.g. Yeast, Human, ...)
# @return organism_id
###############################################################################
sub getOrganismId
{
    my %args = @_;

    my $organism_name = $args{organism_name} || die "need organism_name";

    my $sql = qq~
        SELECT O.organism_id
        FROM $TB_ORGANISM O
        WHERE O.organism_name = '$organism_name'
        AND O.record_status != 'D'
    ~;

    my ($organism_id) = $sbeams->selectOneColumn($sql) or die
        "no organism id found with sql:\n$sql\n($!)";

    return $organism_id;
}



#######################################################################
# removeConsensusLibrary - remove parent record and children
# @param dia_library_spectrum_id
#######################################################################
sub removeConsensusLibrary {

  my %args = @_;

  unless ( $args{dia_library_id} ) {
    die "Missing required option dia_library_id";
  }

  print "lib id string is $args{dia_library_id}\n";
  $args{dia_library_id} =~ s/\s//g;

  for my $id ( split( ',', $args{dia_library_id} ) ) {
    if ( $id !~ /^\d+$/ ) {
      die "illegal ID: $id\n";
    }
    print "Deleting library: $id ";
    $sbeams->do( "DELETE FROM $TBAT_DIA_LIBRARY WHERE dia_library_id = $id" );
  }
  printBuildList();
  exit;
}

sub printBuildList {
  my $id = shift;
  my $sql = "SELECT dia_library_name, dia_library_id, file_format, file_path FROM $TBAT_DIA_LIBRARY ";
  if ( $id ) {
    $sql .= " WHERE dia_library_id = $id ";
  }
  $sql .= " ORDER BY dia_library_id ASC";

  print join( "\t", 'Lib Name', 'Lib ID', 'Format', 'Path' ) . "\n";
  my $sth = $sbeams->get_statement_handle( $sql );
  while( my @row = $sth->fetchrow_array() ) {
    if ( $id ) {
      print "$row[0] ($row[1]}";
    } else {
      print join( "\t", @row ) . "\n";
    }
  }
}

__DATA__
