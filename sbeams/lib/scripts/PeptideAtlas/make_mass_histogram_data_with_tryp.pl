#!/usr/local/bin/perl -w

#######################################################################
# Make histogram of avg mole weight of peptide sequence in given atlas.
# Has as context, the histogram of avg mol wgt of peptide sequences in
# a trypticlly digested protein database (allowing 1 missed cleavage)
#
#  flags are:
# --test            test this code
# --run             run program
# --atlas_build_id  atlas build id
# --use_last_run    use data collected from last run of this program
#                   (de-serialization)
#
#   Author: Nichole King
#######################################################################
use strict;
use Getopt::Long;
use FindBin;

## to create figure:
use GD;
use GD::Graph;
use GD::Graph::xylines;
use GD::Graph::xylinespoints;
use GD::Graph::xypoints;
use GD::Graph::bars;
use GD::Text;

use POSIX qw(ceil floor);


## for serialization 
use Storable qw(store retrieve freeze thaw dclone);


use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $current_username 
             $PROG_NAME $USAGE %OPTIONS $TEST 
             $outfig $atlas_build_id $useSerializedData
             $serDataFile $serDigestedDataFile $serTitleFile 
             $makeHistogram $outfile $digestedOutfile $protFile
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

## PeptideAtlas classes
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;


use SBEAMS::Proteomics::AvgMolWgt::AvgMolWgt;
use SBEAMS::Proteomics::TrypticDigestor::TrypticDigestor;


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


## USAGE:
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: [OPTIONS] key=value key=value ...
Options:
   --test            test this code
   --run             run program
   --atlas_build_id  atlas build id
   --use_last_run    use data collected from last run of this program
                     (serialization)

 e.g.:  ./$PROG_NAME --test
        ./$PROG_NAME --atlas_build_id '78' --run

EOU


GetOptions(\%OPTIONS, "test", "run", "atlas_build_id:s", "use_last_run",
"histogram");


if ( $OPTIONS{"test"} || $OPTIONS{"use_last_run"} ||
( $OPTIONS{"run"} && $OPTIONS{"atlas_build_id"}) )
{

    $TEST = $OPTIONS{"test"} || 0;

    $atlas_build_id = $OPTIONS{"atlas_build_id"} || "";

    $useSerializedData = $OPTIONS{"use_last_run"} || 0;

    $atlas_build_id = '78' if ($TEST);

    $makeHistogram = 1;

} else
{

    print "$USAGE\n";

    exit(0);

}


$serDataFile = "./.pepMassData.ser";

$serDigestedDataFile = "./.digestedPepMassData.ser";

$serTitleFile = "./.pepMassTitle.ser";

$outfile = "./pepMassData.txt";

$digestedOutfile = "./digestedPepMassData.txt";

main();

exit(0);


###############################################################################
# main
###############################################################################
sub main 
{

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ( $current_username = $sbeams->Authenticate(

        work_group=>'PeptideAtlas_admin')
    );


    ## check that can write to outfiles (also initializes ):
    check_files();


    handleRequest();


} ## end main


#######################################################################
# check_files -- check that can write to outfiles and initializes
#######################################################################
sub check_files()
{

    ## write new empty file:
    open(OUTFILE,">$outfile") or die "cannot write to $outfile";

    close(OUTFILE) or die "cannot close $outfile";


    ## initialize serialized data file if not re-using the last one
    unless ($useSerializedData)
    {
        open(OUTFILE,">$serDataFile") or die "cannot write to $serDataFile";

        close(OUTFILE) or die "cannot close $serDataFile";

        open(OUTFILE,">$serTitleFile") or die "cannot write to $serTitleFile";

        close(OUTFILE) or die "cannot close $serTitleFile";

    }

}


#######################################################################
# handleRequest
#######################################################################
sub handleRequest()
{

    ## hash with key = peptide sequence, value = avg mol wgt
    my %pepMassHash;

    my %digestedPepMassHash;

    my %title;


    ## if requested last serialization, retrieve data
    if ($useSerializedData)
    {

        %title = %{ retrieve($serTitleFile) };

        %pepMassHash = %{ retrieve($serDataFile) };

        %digestedPepMassHash = %{ retrieve($serDigestedDataFile) };

        test_peptide_mass(peptide_hash_ref => 
            \%pepMassHash) if ($TEST);

    } else
    {

        %pepMassHash = get_peptide_mass_hash(
            atlas_build_id => $atlas_build_id);

        %digestedPepMassHash = get_digested_peptide_mass_hash(
            atlas_build_id => $atlas_build_id);

        my $tmp = get_atlas_build_name( 
            atlas_build_id => $atlas_build_id );

        $tmp = "$tmp($atlas_build_id)";

        $title{"title"} = $tmp;

        ## serialization:
        store(\%pepMassHash, $serDataFile)
            or die "can't store data in $serDataFile ($!)";

        store(\%digestedPepMassHash, $serDigestedDataFile)
            or die "can't store data in $serDigestedDataFile ($!)";

        store(\%title, $serTitleFile)
            or die "can't store data in $serTitleFile ($!)";

    }


    if ($makeHistogram)
    {

        my (@data) = make_histogram_data(
            data_hash_ref => \%pepMassHash,
            outfile => $outfile,
        );


        my (@digestedData) = make_histogram_data(
            data_hash_ref => \%digestedPepMassHash,
            outfile => $digestedOutfile,
        );

    }

}

###############################################################################
# get_peptide_mass_hash
###############################################################################
sub get_peptide_mass_hash
{

    my %args = @_;

    my $atlas_build_id = $args{ atlas_build_id } || die "need atlas build id";

    ## get hash with key = peptide sequence, value = 0
    my %pepHash = get_peptide_hash( atlas_build_id => $atlas_build_id);

    ## replace hash values with avg mol wgt of sequences
    %pepHash = calculate_avg_mol_wgts(
        peptide_hash_ref => \%pepHash
    );


    return %pepHash;

}


###############################################################################
# get_digested_peptide_mass_hash -- get reference protein fasta file used
# in atlas build, and tryptically digest it, filtering by avg molec mass
# [note this is a memory hog of a method, so could be improved someday if
# used often enough]
#
# @param $atlas_build_id 
# @return hash with keys = sequence, values = avg mol wgt
###############################################################################
sub get_digested_peptide_mass_hash
{

    my %args = @_;

    my $atlas_build_id = $args{ atlas_build_id } || die "need atlas build id";

    ## key = peptide sequence, value = avg mol wgt
    my %digestedPepHash;
    

    ## get all protein sequences from protein database:
    my $sql = qq~
        SELECT B.biosequence_seq, '0'
        FROM $TBAT_ATLAS_BUILD AB, $TBAT_BIOSEQUENCE B
        WHERE AB.atlas_build_id = '$atlas_build_id'
        AND AB.biosequence_set_id = B.biosequence_set_id
    ~;

    ## make hash with key=proteinName, value=0
    my %protHash = $sbeams->selectTwoColumnHash($sql) or
        die "unable to complete statement:\n$sql\n($!)";

    
    ## now digest each of them using: 
    ## my %peptide_hash = TrypticDigestor::digestSequence(
    ##       sequence => $sequence,
    ##       n_allowed_missed_cleavages => '1',
    ##       min_avg_mol_wgt = 200,
    ##       max_avg_mol_wgt = 5000
    foreach my $prot (keys %protHash)
    {

        ## get a hash of digested peptides (key=pep_seq, value=mass)
        my %tmpHash = TrypticDigestor::digestSequence(
            sequence => $prot,
            n_allowed_missed_cleavages => "1", 
            min_avg_mol_wgt => "0",
            max_avg_mol_wgt => "5000"
        );


        ## store those in master digested hash:
        foreach my $pep ( keys %tmpHash )
        {

            $digestedPepHash{$pep} = $tmpHash{$pep};

        }
        
    }
    

    return %digestedPepHash;

}

########################################################################
# calculate_avg_mol_wgts
# @param $peptide_hash_ref  -- reference to hash with 
#                              keys = peptide sequence
#                              value = [not important, it gets replaced]
# @return hash with key = sequence, value = avg mol wgt
########################################################################
sub calculate_avg_mol_wgts
{
    my %args = @_;

    my %hash;

    my $peptide_hash_ref = $args{peptide_hash_ref} or
        die "need peptide hash reference ($!)";

    %hash = %{ $peptide_hash_ref };

    ##  get avg molec wgt for sequence
    foreach my $pep (keys %hash)
    {
        $hash{$pep} = AvgMolWgt::calcAvgMolWgt( sequence => $pep );
    }


    test_peptide_mass( peptide_hash_ref => \%hash) if ($TEST);

    return %hash;

}


########################################################################
sub test_peptide_mass
{
    my %args = @_;

    my %hash;

    my $peptide_hash_ref = $args{peptide_hash_ref} or
        die "need pep hash reference ($!)";

    my %hash = %{ $peptide_hash_ref };

    ## put a test here, eh

}


###############################################################################
# get_atlas_build_name 
###############################################################################
sub get_atlas_build_name
{

    my %args = @_;

    my $id = $args{atlas_build_id} || die "need atlas build id ($!)";

    my $sql = qq~
        SELECT atlas_build_name
        FROM $TBAT_ATLAS_BUILD
        where atlas_build_id = '$id'
    ~;

    my ($atlas_build_name) = $sbeams->selectOneColumn($sql) or
        die "unable to complete statement:\n$sql\n($!)";

    return $atlas_build_name;

}

###############################################################################
# get_peptide_hash
###############################################################################
sub get_peptide_hash
{

    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || "die need atlas build id";

    ## get a hash of peptide sequences 
    my $sql = qq~
        SELECT P.peptide_sequence, '0'
        FROM $TBAT_PEPTIDE P
        JOIN $TBAT_PEPTIDE_INSTANCE PEPI ON (PEPI.peptide_id = P.peptide_id)
        where PEPI.atlas_build_id = '$atlas_build_id'
    ~;

    ## make hash with key=peptide sequence, value=0
    my %pepHash = $sbeams->selectTwoColumnHash($sql) or
        die "unable to complete statement:\n$sql\n($!)";

    if ($TEST)
    {
 
        my $expectedN = 1058;
 
        my $returnedN = keys %pepHash;
 
        if ( $returnedN != $expectedN )
        {
 
            print "TEST FAILED:\n" .
                "    returned $returnedN peptides but expected $expectedN\n";
 
         } else
         {
 
            print "TEST SUCCEEDED:\n" .
                "    returned $returnedN peptides\n";
 
         }

    }

    return %pepHash;

}


########################################################################
# make_histogram_data
########################################################################
sub make_histogram_data
{
    my %args = @_;

    my $data_hash_ref = $args{data_hash_ref} or die 
        "need data hash reference";

    my %data_hash = %{$data_hash_ref};

    my $oFile = $args{outfile} or die "need name of output file";


    ## here, x is peptide sequence, y is peptide mass

    my (@x, @y, @data);

    ## sort numerically by values:
    my @sortedKeys = sort{ $data_hash{$a} <=>  $data_hash{$b}} 
        keys %data_hash;

    my $count = 0;

    ## rounded to the lowest 100:
    my $xminData = $data_hash{$sortedKeys[0]};

    my $xmin = (floor( $xminData/100.)) * 100;

    ## rounded to the highest 100:
    my $xmaxData = $data_hash{$sortedKeys[$#sortedKeys]};

    my $xmax = (ceil( $xmaxData/100.)) * 100;

    ##xxxxxxx
#   print "xmin = $xminData rounded to $xmin, xmax = $xmaxData rounded to $xmax\n";

    ## want bins of size 100 Da
    my $bin_sz = 100;

    my $num_bins = ($xmax-$xmin)/$bin_sz;
   
    my (@bin_centers, @binned_data);

    for (my $i=0; $i < $num_bins; $i++)
    {

        my $bin_center = $xmin + ($bin_sz*($i + 0.5));

        $bin_centers[$i] = $bin_center;

        $binned_data[$i] = 0;

#       print "$i -- $bin_center $binned_data[$i]\n";

    } 


    ## this will be an array of size $num_bins, of the number of proteins per prot cov bin
    my (@binned_data) = 0;

    foreach my $key (@sortedKeys)
    {

        my $bin_number = (floor( ($data_hash{$key} - $xmin)/$bin_sz ));

#       die "$data_hash{$key} is in bin $bin_number ..." . $data_hash{$key}/$bin_sz . "\n";

        $binned_data[$bin_number]++;

    }


#   for (my $i=0; $i < $num_bins; $i++)
#   {
#
#       print "$i -- $bin_centers[$i]  $binned_data[$i] \n";
#
#   }


    #### Create a combined array
    @data = ([@bin_centers],[@binned_data]);

    write_to_outfile( x_array_ref => \@bin_centers, 
        y_array_ref => \@binned_data,
        outfile => $oFile);

    return @data;

}


########################################################################
# write_to_outfile -- writes x and y arrays to outfile in 2 columns
########################################################################
sub write_to_outfile
{
    my %args = @_;

    my $x_array_ref = $args{x_array_ref} or die 
        "need x array reference";

    my $y_array_ref = $args{y_array_ref} or die 
        "need y array reference";

    my @x_array= @{$x_array_ref};

    my @y_array= @{$y_array_ref};

    my $oFile = $args{outfile} or die 
        "need output filename";


    open(OUTFILE,">$oFile") or die "cannot write to $oFile";

    for (my $i=0; $i <= $#x_array; $i++)
    {

        my $x = $x_array[$i];

        my $y = $y_array[$i] || "0";

        print OUTFILE "$x\t$y\n";

    }

    close(OUTFILE) or die "cannot close $oFile";

    print "wrote outfile  $oFile\n";

}

