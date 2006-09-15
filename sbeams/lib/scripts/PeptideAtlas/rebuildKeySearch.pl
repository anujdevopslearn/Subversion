#!/usr/local/bin/perl -w

###############################################################################
# Program     : rebuildKeySearch.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script rebuilds the PeptideAtlas key search mechanism
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::PeptideAtlas::KeySearch;

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
  --testonly             If set, rows in the database are not changed or added
  --GOA_directory        Directory where the latest GOA files are (Human, Mouse)
  --SGD_directory        Directory where the latest SGD files are (Yeast)
  --organism_name        Name of organism to process (Human, Yeast, Mouse)
  --organism_specialized_build    If there is more than one default build
                         for an organism, this must be supplied, too
  --atlas_build_id       atlas_build_id of the build for which number of
                         matching peptides should be populated

 e.g.: $PROG_NAME --organism_name Yeast --SGD_directory ./annotations
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
                   "GOA_directory:s","SGD_directory:s","organism_name:s",
		   "atlas_build_id:i","organism_specialized_build:s",
    )) {

    print "\n$USAGE";
    exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;

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
  exit unless (
    $current_username = $sbeams->Authenticate(
      work_group=>'PeptideAtlas_admin')
  );

  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  my %args = @_;

  ##### PROCESS COMMAND LINE OPTIONS AND RESTRICTIONS #####

  #### Set the command-line options
  my $GOA_directory = $OPTIONS{"GOA_directory"};
  my $SGD_directory = $OPTIONS{"SGD_directory"};
  my $organism_name = $OPTIONS{"organism_name"};
  my $atlas_build_id = $OPTIONS{"atlas_build_id"};
  my $organism_specialized_build = $OPTIONS{"organism_specialized_build"};

  #### If there are any unresolved parameters, exit
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }

  unless ($organism_name) {
    print "\n$USAGE\nINSUFFICIENT OPTIONS: You must supply --organism_name\n";
    exit;
  }

  unless ($atlas_build_id) {
    print "\n$USAGE\nINSUFFICIENT OPTIONS: You must supply --atlas_build_id\n";
    exit;
  }



  my $keySearch = new SBEAMS::PeptideAtlas::KeySearch;

  unless ( $keySearch->checkAtlasBuild(build_id => $atlas_build_id) ) {
    print "\n$USAGE\nInvalid build id: $atlas_build_id\n";
    exit;
  }

  $keySearch->setSBEAMS($sbeams);

  $keySearch->rebuildKeyIndex(
    GOA_directory => $GOA_directory,
    SGD_directory => $SGD_directory,
    organism_name => $organism_name,
    organism_specialized_build => $organism_specialized_build,
    atlas_build_id => $atlas_build_id,
    verbose => $VERBOSE,
    testonly => $TESTONLY,
  );


} # end handleRequest




