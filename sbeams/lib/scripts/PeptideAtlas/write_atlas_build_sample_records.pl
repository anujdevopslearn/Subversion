#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_atlas_build.pl
# Author      : Nichole King
#
# Description : If have used earlier version of load_atlas_build and notice
#               that atlas build sample records weren't created, can run
#               this to create the atlas build sample records
#	        also, you can use this code to update all sample in the build
#		to be public
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
             $ATLAS_BUILD_ID 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TEST
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
  --test                 Test only, don't write records
  --atlas_build_id       Atlas build id
  --public               Set all atlas samples to be public
 e.g.: ./$PROG_NAME --atlas_build_id \'73\' 
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","test",
        "atlas_build_id:s", "public"
    )) {

    die "\n$USAGE";

}


$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TEST = $OPTIONS{"test"} || 0;

my $PUBLIC = $OPTIONS{"public"} || 0;


   
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
      $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
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


  my $atlas_build_id = $OPTIONS{"atlas_build_id"} || '';

  #### Verify required parameters
  unless ($atlas_build_id) {
    print "\n$USAGE\n";
    print "\nERROR: You must specify an --atlas_build_id\n\n";
    exit;
  }


  ## set ATLAS_BUILD_ID:
  $ATLAS_BUILD_ID = $atlas_build_id;


  writeRecords( atlas_build_id=>$ATLAS_BUILD_ID);


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


} # end handleRequest



###############################################################################
# writeRecords -- write atlas build sample records
# @param atlas_build_id
###############################################################################
sub writeRecords 
{
    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'} or die
        " need atlas_build_id ($!)";

    ## get array of sample_id's
    my %samples_hash = get_sample_id_array( atlas_build_id => $atlas_build_id );

    ## get all atlas_build_sample records into a hash:
    my $sql = qq~
        SELECT sample_id, atlas_build_sample_id
        FROM $TBAT_ATLAS_BUILD_SAMPLE
        WHERE record_status != 'D'
        AND atlas_build_id='$atlas_build_id'
    ~;
    my @samples = keys %samples_hash;

    my %abs_hash = $sbeams->selectTwoColumnHash($sql);

    if ($TEST)
    {
        for (my $i=0; $i <= $#samples; $i++)
        {
            my $sample_id = $samples[$i];

            if (!exists $abs_hash{$sample_id})
            {
                print "would create an atlas_build_sample "
                . " for sample_id $sample_id\n";
            } else
            {
                print "found atlas_build_sample $abs_hash{$sample_id} "
                . " for sample_id $sample_id\t $samples_hash{$sample_id}"
                . " (is_public setting)\n";
            }
        }
        if( $PUBLIC )
        {
            print "\nwould set is_public for all samples above to Y\n\n";
        }
    } else
    {
        ## check that there's an atlas_build_sample_record, and if not, create one
        for (my $i=0; $i <= $#samples; $i++)
        {
            my $sample_id = $samples[$i];

            if (!exists $abs_hash{$sample_id})
            {
                my $tmp_abs_id = createAtlasBuildSampleRecord(
                    sample_id => $sample_id,
                    atlas_build_id => $ATLAS_BUILD_ID
                );
            }
            if( $PUBLIC )
            {
              my $updatesql = qq~
                UPDATE $TBAT_SAMPLE
                SET is_public='Y'
                WHERE sample_id=$sample_id
              ~;
              $sbeams->do($updatesql);

            }
        }

    }
   

}

###############################################################################
# get_sample_id_array -- get array of sample id for atlas
# @param atlas_build_id
# @return sample array
###############################################################################
sub get_sample_id_array 
{
    my %args = @_;

    my @s;

    my $atlas_build_id = $args{atlas_build_id} or die
        " need atlas_build_id ($!)";

    my %sample_hash;

    ## having to go around through peptide records, then using hash to
    ## store distinct returned rows
    my $sql = qq~
        SELECT S.sample_id, S.is_public
        FROM $TBAT_SAMPLE S
        JOIN $TBAT_PEPTIDE_INSTANCE_SAMPLE PEPIS
        ON (PEPIS.sample_id = S.sample_id)
        JOIN $TBAT_PEPTIDE_INSTANCE PEPI
        ON (PEPI.peptide_instance_id = PEPIS.peptide_instance_id)
        WHERE PEPI.atlas_build_id = '$atlas_build_id'
        AND S.record_status != 'D'
        AND PEPIS.record_status != 'D'
    ~;

    %sample_hash = $sbeams->selectTwoColumnHash($sql) or die
        "unable to execute statement:\n$sql\n($!)";

  #  foreach my $sample_id (keys %sample_hash)
  #  {
  #     print $sample_hash{$sample_id},"\n";
  #  }

    return %sample_hash;
}


###############################################################################
#  createAtlasBuildSampleRecord -- create atlas build sample record 
# @param sample_id
# @param atlas_build_id
###############################################################################
sub createAtlasBuildSampleRecord {

    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id ($!)";

    my $atlas_build_id = $args{atlas_build_id} or 
        die "need atlas_build_id ($!)";

    ## Populate atlas_build_sample table
    my %rowdata = (   ##   atlas_build_sample    table attributes
        atlas_build_id => $atlas_build_id,
        sample_id => $sample_id,
    );

    my $atlas_build_sample_id = $sbeams->updateOrInsertRow(
        insert=>1,
        table_name=>$TBAT_ATLAS_BUILD_SAMPLE,
        rowdata_ref=>\%rowdata,
        PK => 'atlas_build_sample_id',
        return_PK => 1,
        add_audit_parameters => 1,
        verbose=>$VERBOSE,
        testonly=>$TEST,
    );

    return $sample_id;

} ## end createAtlasBuildSampleRecord
