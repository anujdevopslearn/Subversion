#!/usr/local/bin/perl -w

###############################################################################
# Program     : count_genes_yeast.pl
# Author      : nking
# $Id:  Exp $
#
# Description : Gets protein list from database, and reads genes
# from SGD_features file, calculates number of unique gene names,
# and number mapped to
#
###############################################################################


###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use POSIX qw(ceil floor);

use lib "$FindBin::Bin/../../perl";
use vars qw ($current_username $BASE_DIR $N_OBS_GT_1 $ATLAS_BUILD_ID
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $sbeams $sbeamsMOD $q $current_username
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

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
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --testonly             If set, rows in the database are not changed or added
  --atlas_build_id             atlas build id
  --use_nobs_greater_than_one  use only the counts derived from peptides with n_obs>1

 e.g.:  ./$PROG_NAME --atlas_build_id 83
 e.g.:  ./$PROG_NAME --atlas_build_id 83 --use_nobs_greater_than_one

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "base_dir:s", "organism:s",
        "atlas_build_id:s", "use_nobs_greater_than_one"
    )) {

    die "\n$USAGE";

}

$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TESTONLY = $OPTIONS{"testonly"} || 0;

$ATLAS_BUILD_ID = $OPTIONS{"atlas_build_id"} || 0;

$N_OBS_GT_1 = $OPTIONS{"use_nobs_greater_than_one"} || 0;

unless ($ATLAS_BUILD_ID) 
{
    print "\n$USAGE\n Need --atlas_build_id\n";

    exit(0);
}
   

###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();

exit(0);

###############################################################################
# main - call $sbeams->Authenticate() and handle request
###############################################################################
sub main
{

    #### Do the SBEAMS authentication and exit if a username is not returned
     exit unless (
         $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
     );


     handleRequest();

} # end main


########################################################################
# handleRequest
########################################################################
sub handleRequest 
{
    my %args = @_;

    my $atlas_build_id = $ATLAS_BUILD_ID;

    my $BASE_DIR = get_atlas_build_directory(atlas_build_id=>$ATLAS_BUILD_ID);

    my $features_file = "$BASE_DIR/SGD_features.tab";

    ## hash with key = protein_name, value = number of peptides seen
    my %orf_hash = get_protein_hash( atlas_build_id=>$ATLAS_BUILD_ID);

    ## read SGD features file to get gene names for all ORFS
    my $infile = $features_file;

    my %mapped_gene_hash; ##keys=gene, value=comma sep string of orfs

    my %gene_hash; ##keys=gene...this is for all genes in SGD features file

    my %sgd_orf_hash;  ## key = SGD ORF name, value = same

    my %sgd_gene_orf_hash;  ## key = gene, value = comma sep string of orfs

    ## read SGD features file to get gene names for all ORFS (verified, dubious, etc)
    $infile = $features_file;

    my $line;

    open(INFILE, "<$infile") or
    die "cannot open $infile for reading ($!)";

    while ($line = <INFILE>) 
    {
        chomp($line);

        my @columns = split(/\t/,$line);
    
        my $featureType = $columns[1];

        my $featureName = $columns[3];

        my $gene_name = $columns[4];

        if  ($featureType eq "ORF")  
        {
            $gene_hash{$gene_name} = $gene_name;

            $sgd_orf_hash{$featureName} = $featureName;

            if ( exists $orf_hash{$featureName} ) 
            {
                ## in case want to write to file later:
                if ( exists $mapped_gene_hash{$gene_name} ) 
                {
                    $mapped_gene_hash{$gene_name} = 
                        join ",", $mapped_gene_hash{$gene_name}, $featureName;
                } else 
                {
                    $mapped_gene_hash{$gene_name} = $featureName;
                }
            }

            ## store all SGD orfs in a gene hash
            if ( exists $sgd_gene_orf_hash{$gene_name} )
            {
                my $orfs = $sgd_gene_orf_hash{$gene_name};

                if ( $orfs =~ /(.*)$featureName(.*)/ )
                {
                    ## it's already in string, so ignore it
                } else
                {
                    $sgd_gene_orf_hash{$gene_name} = 
                        join ",", $orfs, $featureName;
                }
            } else
            {
                $sgd_gene_orf_hash{$gene_name} = $featureName;
            }
        }
    }
    close(INFILE) or die "cannot close $infile ($!)";
  
    ########## count orfs in SGD fasta file ###############

    my $n_genes = keys %gene_hash;

    my $n_mapped_genes = keys %mapped_gene_hash;

    my $percent = ($n_mapped_genes/$n_genes) * 100.;

    my $n_orfs_atlas = keys %orf_hash;

    my $n_orfs_sgd = keys %sgd_orf_hash;

    print "Number of atlas ORFs used for this search is $n_orfs_atlas\n";

    print "Number of SGD ORFs present in features file is $n_orfs_sgd\n";

    print "Number of genes for all ORFs (includes dubious) in SGD features file is $n_genes\n";

    print "Number of genes atlas maps to is $n_mapped_genes ($percent %)\n";


    my %orfs_in_sgd_fasta;

    my %orfs_in_sgd_fasta_not_in_features;

    $infile = "$BASE_DIR/orf_trans_all.fasta";

    open(INFILE, "<$infile") or
    die "cannot open $infile for reading ($!)";

    while ($line = <INFILE>) {

        chomp($line);

        if ($line =~ /^>(.+)/)
        {

            my @columns = split(/\s/,$line);
    
            my $orf = $columns[0];
            if ( $orf =~ /^>(.*)/ )
            {
                $orf = $1;
            }


            $orfs_in_sgd_fasta{$orf} = $orf;

            ## if not if features hash, store it here:
            if ( exists $sgd_orf_hash{$orf} ) 
            {

            } else
            {
                $orfs_in_sgd_fasta_not_in_features{$orf} = $orf;

            }
        }
    }
    close(INFILE) or die "cannot close $infile ($!)";
  
    my $n_orfs_in_sgd_fasta = keys %orfs_in_sgd_fasta;
    my $n_orfs_in_sgd_fasta_not_in_features = keys %orfs_in_sgd_fasta_not_in_features;

    print "\nNumber of ORFs in SGD fasta file = $n_orfs_in_sgd_fasta\n";
    print "Number of ORFs in SGD fasta file not in features file = $n_orfs_in_sgd_fasta_not_in_features\n";

    my $outfile = "gene_orf_hist.txt";

    my $n_1 = 0;
    ## replace values, with num orfs
    foreach my $gene (keys %sgd_gene_orf_hash)
    {
        my @orfs = split( ",", $sgd_gene_orf_hash{$gene} );

        my $no = $#orfs + 1;

        if ($no == 1)
        {
            $n_1 = $n_1 + 1;
        }
        if ($no > 1)
        {
            print "$gene:$no\n"; 
        }
        $sgd_gene_orf_hash{$gene} = $no;
    }
    print "num genes with 1 ORF: $n_1\n";

    make_histogram_data(
        data_hash_ref => \%sgd_gene_orf_hash,
        outfile => $outfile
    );

}


#######################################################################
# get_atlas_build_directory - get base_dir of atlas_build
# @param atlas_build_id
# @return base_dir
#######################################################################
sub get_atlas_build_directory
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $sql = qq~
        SELECT data_path
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_id = '$atlas_build_id'
        AND record_status != 'D'
    ~;

    my ($data_path) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: Unable to find the atlas_build_id $atlas_build_id".
        " with $sql\n\n";

    my $pipeline_dir = $CONFIG_SETTING{PeptideAtlas_PIPELINE_DIRECTORY};

    $data_path = "$pipeline_dir/$data_path";

    ## check that path exists
    unless ( -e $data_path)
    {
        die "\n Can't find path $data_path in file system.  Please check ".
        " the record for atlas_build with atlas_build_id=$atlas_build_id";
    }

    return $data_path;
}

#######################################################################
# get_protein_hash - get hash with key = protein name, value = protein_name
# @param atlas_build_id
# @return protein_hash
#######################################################################
sub get_protein_hash
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $sql;

    if ($N_OBS_GT_1)
    {
        $sql = qq~
        SELECT B.biosequence_name, B.biosequence_name
        FROM $TBAT_PEPTIDE_INSTANCE PEPI,
        $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
        WHERE PM.matched_biosequence_id=B.biosequence_id
        AND PEPI.peptide_instance_id=PM.peptide_instance_id
        AND PEPI.atlas_build_id='$atlas_build_id'
        AND PEPI.n_observations > 1
        AND B.record_status != 'D'
        ~;

    } else
    {
        $sql = qq~
        SELECT B.biosequence_name, B.biosequence_name
        FROM $TBAT_PEPTIDE_INSTANCE PEPI,
        $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
        WHERE PM.matched_biosequence_id=B.biosequence_id
        AND PEPI.peptide_instance_id=PM.peptide_instance_id
        AND PEPI.atlas_build_id='$atlas_build_id'
        AND B.record_status != 'D'
        ~;
    }

    my %protein_hash = $sbeams->selectTwoColumnHash($sql) or
        die "\nERROR: in sql?  $sql \n\n";

    return %protein_hash;

}
#######################################################################
# get_protein_npep_hash - get hash with key = protein name, value = num peptides
# @param atlas_build_id
# @return protein_hash
#######################################################################
sub get_protein_npep_hash
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $sql;

    if ($N_OBS_GT_1)
    {
        $sql = qq~
        SELECT B.biosequence_name,
            (SELECT SUM(PEPI.n_observations)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI,
            $TBAT_PEPTIDE_MAPPING PM,
            $TBAT_BIOSEQUENCE BB
            WHERE PEPI.peptide_instance_id=PM.peptide_instance_id
            AND PM.matched_biosequence_id=BB.biosequence_id
            AND PEPI.atlas_build_id='$atlas_build_id'
            AND PEPI.is_subpeptide_of is NULL
            AND BB.biosequence_name = B.biosequence_name
            AND PEPI.n_observations > 1
            AND BB.record_status != 'D'
            )
        FROM $TBAT_PEPTIDE_INSTANCE PEPI,
        $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
        WHERE PM.matched_biosequence_id=B.biosequence_id
        AND PEPI.peptide_instance_id=PM.peptide_instance_id
        AND PEPI.atlas_build_id='$atlas_build_id'
        AND PEPI.n_observations > 1
        AND B.record_status != 'D'
        ~;

    } else
    {
        $sql = qq~
        SELECT B.biosequence_name,
            (SELECT SUM(PEPI.n_observations)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI,
            $TBAT_PEPTIDE_MAPPING PM,
            $TBAT_BIOSEQUENCE BB
            WHERE PEPI.peptide_instance_id=PM.peptide_instance_id
            AND PM.matched_biosequence_id=BB.biosequence_id
            AND PEPI.atlas_build_id='$atlas_build_id'
            AND PEPI.is_subpeptide_of is NULL
            AND BB.biosequence_name = B.biosequence_name
            AND BB.record_status != 'D'
            )
        FROM $TBAT_PEPTIDE_INSTANCE PEPI,
        $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
        WHERE PM.matched_biosequence_id=B.biosequence_id
        AND PEPI.peptide_instance_id=PM.peptide_instance_id
        AND PEPI.atlas_build_id='$atlas_build_id'
        AND B.record_status != 'D'
        ~;
    }

    my %protein_hash = $sbeams->selectTwoColumnHash($sql) or
        die "\nERROR: in sql?  $sql \n\n";

    return %protein_hash;

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

    my $xmin = (floor( $data_hash{$sortedKeys[0]} ));

    my $xmax = (ceil( $data_hash{$sortedKeys[$#sortedKeys]}));

    print "xmin = $xmin,  xmax = $xmax\n";

#   my $bin_sz = 100;
    my $bin_sz = 1;

    my $num_bins = ($xmax-$xmin)/$bin_sz;

    my (@bin_centers, @binned_data);

    for (my $i=0; $i < $num_bins + 1; $i++)
    {
        my $bin_center = $xmin + ($bin_sz*($i + 0.5));

        $bin_centers[$i] = sprintf("%.2f", $bin_center);

        $binned_data[$i] = 0;

#       print "$i -- $bin_centers[$i] $binned_data[$i]\n";
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
#       print "$i -- $bin_centers[$i]  $binned_data[$i] \n";
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
        my $x = sprintf("%6.2f",$x_array[$i]);

        my $y = $y_array[$i] || "0";

        my $y = sprintf("%8.0f",$y);

        print OUTFILE "$x  $y\n";
    }

    close(OUTFILE) or die "cannot close $oFile";

    print "wrote $oFile\n";
}
