#!/usr/local/bin/perl -w
use strict;

###############################################################################
# Program     : getMiscBuildStats.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id:
#
# Description : Performs several big SQL queries to gath more stats about
#               the specified build.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;

use lib "/net/dblocal/www/html/sbeams/lib/perl";

use vars qw ( $sbeams $sbeamsMOD $current_username
              $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );

#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

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
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --atlas_build_id    atlas_build_id to generate stats for

e.g.:  ./getMiscBuildStats.pl.pl --atlas_build_id=54

EOU


####### Process options #######################
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
       "atlas_build_id:s",
		  )
       ) {
  print "$USAGE";
  exit;
}


########################################################################
# Set Global Variables and execute main()
########################################################################
main();
exit(0);



########################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if failure, continue if works.
########################################################################
sub main {


  ## authenticate SBEAMS user and exit if fail
  exit unless ($current_username = $sbeams->Authenticate(
                work_group=>'PeptideAtlas_admin',
  ));

  $sbeams->printPageHeader() unless ($QUIET);

  handleRequest();

  $sbeams->printPageFooter() unless ($QUIET);


} # end main



########################################################################
# handleRequest
########################################################################
sub handleRequest {
  my %args = @_;

  #### Set the command-line options
  my $atlas_build_id = $OPTIONS{"atlas_build_id"};

  #### If there are any parameters left, complain and print usage
  if ($ARGV[0]){
      print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
      print "$USAGE";
      exit;
  }

  #### Verify required parameters
  unless ( $atlas_build_id ) {
    print "$USAGE";
    print "\nERROR: You must specify --atlas_build_id \n\n";
    exit;
  }


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Determine the corresponding APD_id
  my $sql = qq~
      SELECT APD_id
        FROM $TBAT_ATLAS_BUILD
       WHERE atlas_build_id = '$atlas_build_id'
         AND record_status != 'D'
    ~;
  my ($APD_id) =  $sbeams->selectOneColumn($sql) or
    die "Cannot get APD_id from atlas_build_id = $atlas_build_id ($!)";


  #### Get the experiment_list
  $sql = qq~
     SELECT experiment_list,minimum_probability
       FROM $TBAPD_PEPTIDE_SUMMARY
      WHERE peptide_summary_id = '$APD_id'
        AND record_status != 'D'
  ~;

  my @rows = $sbeams->selectSeveralColumns($sql)
    or die "Could not complete query: $sql ($!)";

  #my $search_batch_id_list = @rows[0]->[0];
  #my $minimum_probability = @rows[0]->[1];
  my ($search_batch_id_list, $minimum_probability);
  foreach my $row (@rows)
  {
    ($search_batch_id_list, $minimum_probability) = @{$row};
  }
   


  #### Number of distinct peptide names mapped to in build
  $sql = qq~
  SELECT COUNT(DISTINCT PI.peptide_instance_id),
       'Number of distinct peptide names mapped to in build'
  FROM $TBAT_PEPTIDE_INSTANCE PI
  JOIN $TBAT_PEPTIDE_MAPPING PM
       ON ( PI.peptide_instance_id = PM.peptide_instance_id )
 WHERE PI.atlas_build_id='$atlas_build_id'
  ~;

  my @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row ( @rows ) {
    print join("\t",@{$row}),"\n";
  }


  #### Total number of MS/MS spectra w/ P >= NN
  $sql = qq~
SELECT COUNT(*),
       'Total number of MS/MS spectra w/ P >= $minimum_probability'
  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
  JOIN $TBPR_SEARCH_BATCH SB ON (PE.experiment_id = SB.experiment_id)
  JOIN $TBPR_SEARCH S ON (S.search_batch_id = SB.search_batch_id)
  JOIN $TBPR_SEARCH_HIT SH ON (S.search_id = SH.search_id)
 WHERE SH.probability >= '$minimum_probability'
   AND SB.search_batch_id IN ($search_batch_id_list)
~;

  my @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row ( @rows ) {
    print join("\t",@{$row}),"\n";
  }


  #### Total number of searched MS/MS spectra
  $sql = qq~
SELECT COUNT(*),
       'Total number of searched MS/MS spectra'
  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
  JOIN $TBPR_SEARCH_BATCH SB ON ( PE.experiment_id = SB.experiment_id )
  JOIN $TBPR_FRACTION F ON ( PE.experiment_id = F.experiment_id )
  JOIN $TBPR_MSMS_SPECTRUM MSS ON ( F.fraction_id = MSS.fraction_id )
 WHERE SB.search_batch_id IN ($search_batch_id_list)
~;

  my @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row ( @rows ) {
    print join("\t",@{$row}),"\n";
  }


  #### Total number of msruns in used experiments
  $sql = qq~
SELECT COUNT(*),
       'Total number of msruns in used experiments'
  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
  JOIN $TBPR_SEARCH_BATCH SB ON ( PE.experiment_id = SB.experiment_id )
  JOIN $TBPR_FRACTION F ON ( PE.experiment_id = F.experiment_id )
 WHERE SB.search_batch_id IN ($search_batch_id_list)
~;

  my @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row ( @rows ) {
    print join("\t",@{$row}),"\n";
  }



  print "\n";

}
