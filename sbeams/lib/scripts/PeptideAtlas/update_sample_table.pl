#!/usr/local/bin/perl -w

###############################################################################
# Program     : update_sample_table.pl
# Author      : nking
# $Id: 
#
# Description : This script updates PeptideAtlas.dbo.sample to
#               pass on search_batch_id, as it's no longer an
#               entry in SBEAMS web interface to create/insert a sample table
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
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG 
            );


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

  --atlas_build_name     Name of the atlas build (already entered by hand in
                         the atlas_build table) into which to load the data

 e.g.:  ./update_sample_table.pl --atlas_build_name "HumanEns21P0.7" 

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
        "atlas_build_name:s")) {

    die "\n$USAGE";

}

$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;


if ($DEBUG) {

    print "Options settings:\n";

    print "  VERBOSE = $VERBOSE\n";

    print "  QUIET = $QUIET\n";

    print "  DEBUG = $DEBUG\n";

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
  my $atlas_build_name = $OPTIONS{"atlas_build_name"} || '';

  #### Verify required parameters
  unless ($atlas_build_name) {
    print "\nERROR: You must specify an --atlas_build_name\n\n";
    die "\n$USAGE";
  }


  #### If there are any unresolved parameters, exit
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Get the atlas_build_id for the supplied name
  my $sql;
  $sql = qq~
    SELECT atlas_build_id
      FROM $TBAT_ATLAS_BUILD
     WHERE atlas_build_name = '$atlas_build_name'
       AND record_status != 'D'
  ~;

  my @rows = $sbeams->selectOneColumn($sql) or die "unable to find ".
      "an id for $atlas_build_name with query:\n$sql\n($!)";


  my ($atlas_build_id) = $rows[0];


  print "atlas build id = $atlas_build_id\n";


  updateSample(atlas_build_id => $atlas_build_id);

  print "Finished updating sample table \n";



} # end handleRequest


###############################################################################
# updateSample - updates sample table with search_batch_id...used to be
#                entered from SBEAMS web insert/create sample record, but
#                is no longer there, so this is needed...should be added
#                to load_atlas_build in near future
###############################################################################
sub updateSample {  

    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'};


    #### Get the current list of peptides in the peptide table
    my $sql;
    $sql = qq~
        SELECT peptide_accession,peptide_id
        FROM $TBAT_PEPTIDE
    ~;
    my %peptides = $sbeams->selectTwoColumnHash($sql);
    ## creates hash with key=peptide_accession, value=peptide_id
 
 

    ## Get an array of sample_id for a given atlas_id
    $sql = qq~
       SELECT sample_id, atlas_build_id
       FROM PeptideAtlas.dbo.atlas_build_sample
       WHERE atlas_build_id ='$atlas_build_id'
    ~;

    my %sample_id_hash =  $sbeams->selectTwoColumnHash($sql) 
        or die "could not find sample id's for atlas_build_id= ".
        "$atlas_build_id ($!)";



    foreach my $sample_id ( sort keys (%sample_id_hash) ) {

        ## get search_batch_id given sample_id, via Proteomics records:
        $sql = qq~
            SELECT SB.search_batch_id
            FROM Proteomics.dbo.search_batch SB
                JOIN Proteomics.dbo.proteomics_experiment PE
                ON ( PE.experiment_id = SB.experiment_id)
                JOIN PeptideAtlas.dbo.sample S 
                ON ( PE.experiment_tag = S.sample_tag )
            WHERE S.sample_id = '$sample_id'
        ~;

        my @rows = $sbeams->selectOneColumn($sql) 
             or die "could not find sample record for sample_id = ".
             "$sample_id ? in PeptideAtlas.dbo.sample ($!)";


        my $search_batch_id = @rows[0];

        ## get sample table info to help populate atlas_build_sample table and sample
        $sql = qq~
               UPDATE PeptideAtlas.dbo.sample
               SET search_batch_id = '$search_batch_id'
               WHERE sample_id = '$sample_id'
        ~;

        my $return = $sbeams->executeSQL($sql);

    }
}
