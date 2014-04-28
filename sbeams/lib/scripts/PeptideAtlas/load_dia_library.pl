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
use Cwd qw( abs_path );

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
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
Usage: $PROG_NAME [OPTIONS]
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
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","test", 'help',
                   "load", "library_name:s", "organism_name:s", 'list', 'format:s',
                   "path:s", "delete:s", 'comment=s', "project_id:i"  ) ) {
    print "\n$USAGE\n";
    exit;
  }

$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TESTONLY = $OPTIONS{"test"} || 0;

unless ( $OPTIONS{'delete'}  || $OPTIONS{'load'} || $OPTIONS{'test'} || $OPTIONS{list} ) {
    print "\n$USAGE\n";
    print "Need --load or --test or --delete id\n";
    exit(0);
}

if ( $OPTIONS{'load'} || $OPTIONS{'test'} ) {
  my $err = 0;
  for my $opt ( qw( path library_name organism_name project_id format ) ) { 
    $err++ unless defined $OPTIONS{$opt};
  }
  if ( $err ) {
    print "\n$USAGE\n";
    print "Need --path, --library_name, --project_id, --format, and --organism_name\n";
    exit(0);
  }
}

if ( $OPTIONS{help} ) {
    print "\n$USAGE\n";
    exit(0);
}

if ( $OPTIONS{list} ) {
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

    if ($OPTIONS{load} || $OPTIONS{test} )
    {
        my $organism_id = getOrganismId(
            organism_name => $OPTIONS{organism_name} 
        );

        ## make sure file exists
        my $file_path = abs_path( $OPTIONS{path} );

        unless (-e $file_path)
        {
            print "File does not exist: $file_path\n";
            exit(0);
        }

        populateRecords(organism_id => $organism_id, 
                          file_path => $file_path,
                             format => $OPTIONS{format},
							  						verbose => $OPTIONS{verbose},
             dia_library_name => $OPTIONS{library_name},
                    library_comment => $OPTIONS{comment}
                       );
    }

    if ($OPTIONS{delete}) {
        removeConsensusLibrary( dia_library_id => $OPTIONS{delete} );
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

  my $organism_id = $args{organism_id} || die "need organism_id";

  my $infile = $args{file_path} || die "need file_path";

  my $md5sum = system( "md5sum $args{file_path}" );

  my $dia_library_name = $args{dia_library_name} || 
      die "need dia_library_name";

  my $library_comment = $args{library_comment} || '';

  print "Loading library $dia_library_name\n";

  my %rowdata = (
     organism_id => $organism_id,
     comment => $library_comment,
     file_format => $args{format},
     dia_library_name => $dia_library_name,
     md5sum => $args{md5sum},
     file_path => $args{file_path},
     project_id => $args{project_id},
  );

  ## create a dia_library record:
  my $dia_library_id = $sbeams->updateOrInsertRow(
      table_name=>$TBAT_DIA_LIBRARY,
      insert=>1,
      rowdata_ref=>\%rowdata,
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
