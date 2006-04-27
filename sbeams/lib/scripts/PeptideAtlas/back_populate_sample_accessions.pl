#!/usr/local/bin/perl -w

###############################################################################
# Program     : back_populate_sample_accessions.pl
# Author      : Nichole King
#
# Description : This will populate sample_accession in sample records where
#               the field is empty.  It'll create accession numbers, ordered
#               by sample_id.  The root name PAe is hard wired into the code.
#               (for example, sample_accession is PAe000001)
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
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
  --test                 test only, don't write records
 e.g.: ./$PROG_NAME --atlas_build_id \'73\' 
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","test",
        "atlas_build_id:s"
    )) {

    die "\n$USAGE";

}


$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TEST = $OPTIONS{"test"} || 0;

   
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

  populateSampleRecordsWithSampleAccession();

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


} # end handleRequest



###############################################################################
# populateSampleRecordsWithSampleAccession - populate sample records with
# sample_accesion
###############################################################################
sub populateSampleRecordsWithSampleAccession
{

    my %args = @_;

    ## get hash with key=sample_id, value=sample_accession
    ##                              (where values may be '')
    my %sampleId_sampleAccession_hash = getSampleIdSampleAccessionHash();


    ## accession root name and number of digits:
    my $root_name = "PAe";

    my $num_digits = 6;

    ## get last number used, will return 0 if none were set yet
    my $last_number_used = getLastNumberFromAccessions(
        hash_ref => \%sampleId_sampleAccession_hash,
        root_name => $root_name,
    ); 


    ## sort numerically by key:
    foreach my $sample_id (sort { $a <=> $b } keys %sampleId_sampleAccession_hash)
    {
 
        my $existing_accession = $sampleId_sampleAccession_hash{$sample_id};

        ## execute only if there isn't a sample_accession
        unless ($existing_accession )
        {
            my $next_accession;

            my $next_number = $last_number_used + 1;

            my $next_number_length =  length($next_number);

            # exit with error if num digits needed is larger than num digits expected
            if ($next_number_length > $num_digits)
            {
                print "number of digits exceeds $num_digits\n";

                exit(0);
            }


            my $next_accession = $root_name;

            for (my $i=0; $i < ($num_digits - $next_number_length); $i++ )
            {
                $next_accession = $next_accession . "0";
            }

            $next_accession = $next_accession . $next_number;
     
            updateSampleRecord(
                sample_id => $sample_id,
                sample_accession => $next_accession,
            );
 
            $last_number_used = $last_number_used + 1;
 
        }
 
    }
 
}


###############################################################################
#  getSampleIdSampleAccessionHash
#
# @param ref to sample_id array
# @return hash with key = sample_id, value = sample_accession
###############################################################################
sub getSampleIdSampleAccessionHash
{
    my %args = @_;

    ## having to go around through peptide records, then using hash to
    ## store distinct returned rows
    my $sql = qq~
        SELECT sample_id, sample_accession
        FROM $TBAT_SAMPLE 
        WHERE record_status != 'D'
    ~;

    my %hash = $sbeams->selectTwoColumnHash($sql) or die
        "unable to execute statement:\n$sql\n($!)";

    return %hash;

}

#######################################################################
# getLastNumberFromAccessions
# @param ref to sample_id, sample_accession hash
# @param default_first_accession
# @return the latest accession in hash, or zero if none present
#######################################################################
sub getLastNumberFromAccessions
{
    my %args = @_;

    my $hash_ref = $args{hash_ref} or die "need hash_ref";

    my $root_name = $args{root_name} or die "need root_name";

    my %hash = %{$hash_ref};

    my $last_number = 0;

    my $last_written_accession;

    my $n = keys %hash;

    if ($n > 0)
    {
        ## sort by hash values in descending asciibetical order:
        my @sorted_keys = sort { $hash{$b} cmp $hash{$a} } keys %hash;

        if (@sorted_keys)
        {
            $last_written_accession = $hash{$sorted_keys[0]};

            $last_number = $last_written_accession;

            $last_number =~ s/($root_name)(\d+)$/$2/;

            $last_number = int($last_number);
        }

    }

    return $last_number;
}



###############################################################################
# updateSampleRecord -- update sample record...
# @param sample_id
# @param sample_accession
###############################################################################
sub updateSampleRecord 
{

    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id";

    my $sample_accession = $args{sample_accession} 
        or die "need sample_accession";


    my %rowdata = (  
        sample_accession => $sample_accession,
    );

    my $success = $sbeams->updateOrInsertRow(
        update=>1,
        table_name=>$TBAT_SAMPLE,
        rowdata_ref=>\%rowdata,
        PK => 'sample_id',
        PK_value => $sample_id,
        verbose=>$VERBOSE,
        testonly=>$TEST,
    );

    return $success;

} 


#######################################################################
# getNextAccession - get next accession
# @param root_name - root of accession name (e.g. "PAe")
# @param num_digits - number of digits in accession string
# @param last_num_used - last number used
# @return next_accession
#######################################################################
sub getNextAccession
{
    my %args = @_;

    my $num_digits = $args{num_digits} or die "need num_digits";

    my $last_number_used = $args{last_num_used} or die "need last_num_used";

    my $root_name = $args{root_name} or die "need root_name";

    my $next_accession;

    my $next_number = $last_number_used + 1;

    my $next_number_length =  length($next_number);

    # exit with error if num digits needed is larger than num digits expected
    if ($next_number_length > $num_digits)
    {
        print "number of digits exceeds $num_digits\n";

        exit(0);
    }


    my $next_accession = $root_name;

    for (my $i=0; $i < ($num_digits - $next_number_length); $i++ )
    {
        $next_accession = $next_accession . "0";
    }

    $next_accession = $next_accession . $next_number;

    return $next_accession;

}
