#!/usr/local/bin/perl -w

###############################################################################
# Program     : calculate_basic_build_stats.pl
# Author      : Nichole King
#
# Description : calculates basic build stats - the spectra stats are from 
# new database records and from flatfiles because the spectra are still not
# in the database...  peptide and protein stats are from database records
# Can use flag to only use peptides which have been observed more than once.
#
## Follow this up with organism specific gene stat scripts, for example
## count_genes_yeast.pl
###############################################################################

###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../perl";
use vars qw ($current_username $BASE_DIR $ORGANISM $ATLAS_BUILD_ID
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $sbeams $sbeamsMOD $q $current_username $N_OBS_GT_1
             $ORGANISM_ABBREV
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
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
  --verbose n                  Set verbosity level.  default is 0
  --quiet                      Set flag to print nothing at all except errors
  --debug n                    Set debug flag
  --testonly                   If set, rows in the database are not changed or added
  --atlas_build_id             atlas build id 
  --organism_abbrev            organism abbreviation 
  --use_nobs_greater_than_one  use only the counts derived from peptides with n_obs>1
  --probability                This value will will do calcs using only assignments
                               with P >= probability
                               [not required, default is to use lower limit probability
                               of the build.  If you set this value, it should be
                               larger than the atlas's probability].  
             
 e.g.:  ./$PROG_NAME --atlas_build_id 83 --organism_abbrev Sc

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
    "atlas_build_id:s", "use_nobs_greater_than_one",
    "organism_abbrev:s", "probability:s" )) {

    die "\n$USAGE";

}

$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TESTONLY = $OPTIONS{"testonly"} || 0;

$ATLAS_BUILD_ID = $OPTIONS{"atlas_build_id"} || 0;

$N_OBS_GT_1 = $OPTIONS{"use_nobs_greater_than_one"} || 0;

$ORGANISM_ABBREV = $OPTIONS{"organism_abbrev"} || "";

unless ($ATLAS_BUILD_ID) 
{
    print "\nNeed atlas_build_id\n$USAGE\n";
    exit;
}
   
unless ($ORGANISM_ABBREV) 
{
    print "\nNeed organism_abbrev\n$USAGE\n";
    exit;
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

    my $n_exp = get_number_of_experiments(atlas_build_id=>$ATLAS_BUILD_ID);

    my $n_ms_runs = get_number_of_ms_runs(atlas_build_id=>$ATLAS_BUILD_ID);

    my $n_msms_spectra = get_number_of_spectra(atlas_build_id=>$ATLAS_BUILD_ID);

    my $n_msms_spectra_searched = get_number_of_spectra_searched
        (atlas_build_id=>$ATLAS_BUILD_ID);

    my $n_msms_spectra_above_threshhold = 
        get_number_of_spectra_above_threshhold(
        atlas_build_id=>$ATLAS_BUILD_ID, 
        probability=>$OPTIONS{probability});

    my $n_distinct_peptides = get_number_of_distinct_peptides(
        atlas_build_id=>$ATLAS_BUILD_ID,
        probability=>$OPTIONS{probability});

    my $n_distinct_peptides_aligned_to_reference = 
        get_number_of_distinct_peptides_aligned_to_reference(
        atlas_build_id=>$ATLAS_BUILD_ID,
        probability=>$OPTIONS{probability});

    print "Number of experiments: $n_exp\n";

    print "Number of MS runs: $n_ms_runs\n";

    print "Number of MSMS spectra: $n_msms_spectra\n";

    print "Number of MSMS spectra searched: $n_msms_spectra_searched\n";

    print "Number of MSMS spectra above threshhold: $n_msms_spectra_above_threshhold\n";

    print "Number of distinct peptides in atlas: $n_distinct_peptides\n";

    print "Number of distinct peptides aligned to reference genome: $n_distinct_peptides_aligned_to_reference\n";
    
    ## get number of proteins/ORFs in reference protein fasta file:
    my %reference_protein_hash = get_reference_protein_hash( 
        atlas_build_id=>$ATLAS_BUILD_ID,
        probability=>$OPTIONS{probability});

    ## get number of proteins/ORFs in atlas:
    my %pa_protein_hash = get_protein_hash(
        atlas_build_id=>$ATLAS_BUILD_ID,
        probability=>$OPTIONS{probability});

    ## get only those proteins with peptides which map to only one protein
    ## (in other words, not counting ambiguous peptide identifications)
    my %pa_unambiguous_protein_hash = 
        get_unambiguous_protein_hash( 
            atlas_build_id=>$ATLAS_BUILD_ID,
            probability=>$OPTIONS{probability});

    my $n_atlas = keys %pa_protein_hash;

    my $n_ref = keys %reference_protein_hash;

    my $n_unambiguous_atlas = keys %pa_unambiguous_protein_hash;

    my $percent = ($n_atlas / $n_ref) * 100.;

    my $percent_unambiguous = ($n_unambiguous_atlas / $n_ref) * 100.;

    print "Number of proteins or ORFs seen in PeptideAtlas: $n_atlas ($percent %)\n";

    print "Number of unambiguous proteins or ORFs seen in PeptideAtlas: "
        . "$n_unambiguous_atlas ($percent_unambiguous %)\n";

    print "Number of proteins or ORFs in reference database: $n_ref\n";

}


#######################################################################
# get_number_of_experiments -- get number of experiments used in build
# @param atlas_build_id
# @return n_exp
#######################################################################
sub get_number_of_experiments
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $sql = qq~
        SELECT count (distinct atlas_build_sample_id)
        FROM $TBAT_ATLAS_BUILD_SAMPLE
        WHERE atlas_build_id = '$atlas_build_id'
        AND record_status != 'D'
    ~;

    my ($n_exp) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: Unable to count atlas_build_sample_ids ".
        " with $sql\n\n";

    return $n_exp;
}

#######################################################################
# get_number_of_ms_runs - get number of MS runs
# @param atlas_build_id
# @return n_ms_runs
#######################################################################
sub get_number_of_ms_runs
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $data_base_dir = $RAW_DATA_DIR{Proteomics};

    ## this is currently not stored in database, so need to count all
    ## mzXML files in each sample's data directory
    my $sql = qq~
        SELECT distinct data_location
        FROM $TBAT_ATLAS_SEARCH_BATCH ASB
        JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
        ON (ABSB.atlas_search_batch_id = ASB.atlas_search_batch_id)
        where ABSB.atlas_build_id='$atlas_build_id'
        and ABSB.record_status != 'D'
        and ASB.record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);

    my $n_ms_runs = 0;

    foreach my $row (@rows)
    {
        my ($data_location) = @{$row};

        $data_location = "$data_base_dir/$data_location";

        ## trim the /data3/ off if it's there...
        $data_location =~ s/\/data3(.*)/$1/;

        ## count number of mzXML files there... trouble if no mzXML files or multiple versions...
        my $nfiles = `find $data_location -name '*.mzXML' -maxdepth 1 -follow | wc -l`;

        unless ($nfiles > 0)
        {
            print "ERROR: could not find mzXML files in $data_location\n";
        }
 
        $n_ms_runs = $n_ms_runs + $nfiles;
    }

    return $n_ms_runs;
}

#######################################################################
# get_number_of_spectra -- get total number of spectra in all mzXML files
# @param atlas_build_id
# @return n_msms_spectra
#######################################################################
sub get_number_of_spectra
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $sql = qq~
        SELECT sum (n_spectra)
        FROM $TBAT_SPECTRA_DESCRIPTION_SET
        WHERE atlas_build_id = '$atlas_build_id'
        AND record_status != 'D'
    ~;

    my ($n_msms_spectra) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: n_spectra not stored?  $sql \n\n";

    return $n_msms_spectra
}


#######################################################################
# get_number_of_spectra_searched -- get number of spectra searched
# @param atlas_build_id
# @return n_msms_spectra_searched
#######################################################################
sub get_number_of_spectra_searched
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $sql = qq~
        SELECT sum (n_searched_spectra)
        FROM $TBAT_ATLAS_SEARCH_BATCH ASB
        JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
        ON (ABSB.atlas_search_batch_id = ASB.atlas_search_batch_id)
        WHERE ABSB.atlas_build_id = '$atlas_build_id'
        AND ABSB.record_status != 'D'
        AND ASB.record_status != 'D'
    ~;

    my ($n_msms_spectra_searched) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: n_seached_spectra not stored?  $sql \n\n";

    return $n_msms_spectra_searched;
}

#######################################################################
# get_number_of_spectra_above_threshhold - get number of spectra above
#     a threshhold P value (currently, that's the P value of the atlas
#     so no need to filter here).
# @param atlas_build_id
# @param probability  -- lower limit probability threshhold
# @return number of spectra above a threshhold P value
#######################################################################
sub get_number_of_spectra_above_threshhold
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die 
        "need atlas_build_id";

    my $probability = $OPTIONS{probability} || "";

    ## this stage requires that createPipelineInput.pl have been run
    ## ahead of time...

    ## reads APD_<organism_abbrev>_all.peplist
    my $atlas_build_directory = get_atlas_build_directory(
        atlas_build_id => $atlas_build_id );

    my $infile = "$atlas_build_directory/APD_".$ORGANISM_ABBREV."_all.peplist";
    my $infile = "$atlas_build_directory/APD_".$ORGANISM_ABBREV."_all.peplist";

    ## huge hash to make sure not counting spectrum more than once
    my %spectra;

    ## huge hash to only count peptides with n_obs > 1 if $N_OBS_GT_1 is set
    my %peptides;

    my $n;

    if (-e $infile)
    {
        if ($N_OBS_GT_1)
        {
            ## once through to discover peps with n_obs > 1
            open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";
            while (my $line = <INFILE>)
            {
                chomp($line);

                my @columns = split(/\t/,$line);
                ## search_batch_id 
                ## sequence 
                ## probability
                ## protein_name
                ## spectrum_query
                if ($probability)
                {
                    if ( $columns[2] >= $probability )
                    {
                        my $peptide = $columns[1];

                        if (exists $peptides{$peptide})
                        {
                            $peptides{$peptide} = $peptides{$peptide} + 1;
                        } else
                        {
                            $peptides{$peptide} = 1;
                        }
                    }
                } else
                {
                    my $peptide = $columns[1];

                    if (exists $peptides{$peptide})
                    {
                        $peptides{$peptide} = $peptides{$peptide} + 1;
                    } else
                    {
                        $peptides{$peptide} = 1;
                    }
                }
            }
            close(INFILE) or die "Cannot close $infile";

            ## now only store proteins with peptide seen more than once:
            open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";
            while (my $line = <INFILE>)
            {
                chomp($line);

                my @columns = split(/\t/,$line);

                my $peptide = $columns[1];

                my $prob = $columns[2];

                my $spectrum = $columns[4];

                if ($probability)
                {
                    if ( $columns[2] >= $probability )
                    {
                        ## drop the last . followed by number
                        $spectrum =~ s/(.*)(\.)(\d)/$1/;
        
                        if ($peptides{$peptide} > 1)
                        {
                            $spectra{$spectrum} = $spectrum;
                        }
                    }
                } else
                {
                    ## drop the last . followed by number
                    $spectrum =~ s/(.*)(\.)(\d)/$1/;
    
                    if ($peptides{$peptide} > 1)
                    {
                        $spectra{$spectrum} = $spectrum;
                    }
                }
            }

            close(INFILE) or die "Cannot close $infile";
            $n = keys %spectra;

        } else
        {
            open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

            while (my $line = <INFILE>)
            {
                chomp($line);

                my @columns = split(/\t/,$line);
                ## search_batch_id 
                ## sequence 
                ## probability
                ## protein_name
                ## spectrum_query
                if ($probability)
                {
                    if ( $columns[2] >= $probability )
                    {
                        my $spectrum = $columns[4];
                        if ($columns[2] >= $probability)
                        {
                            ## drop the last . followed by number
                            $spectrum =~ s/(.*)(\.)(\d)/$1/;
        
                            $spectra{$spectrum} = $spectrum;
                        }
                    }
                } else
                {
                    my $spectrum = $columns[4];
    
                    ## drop the last . followed by number
                    $spectrum =~ s/(.*)(\.)(\d)/$1/;

                    $spectra{$spectrum} = $spectrum;
                }
            
            }

            close(INFILE) or die "Cannot close $infile";

            $n = keys %spectra;
        }

    } else
    {
        print "Need to use createPipelineInput.pl first to generate "
            . " needed file: APD_".$ORGANISM_ABBREV."_all.peplist\n";
    }

    return $n;
}


#######################################################################
# get_number_of_distinct_peptides -- get distinct number of peptides
# @param atlas_build_id
# @param probability -- lower limit probability to use in including peptides
# @return n_distinct_peptides
#######################################################################
sub get_number_of_distinct_peptides
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $probability = $args{probability} || "";

    my $sql;

    if ($N_OBS_GT_1)
    {
        if ($probability)
        {
            $sql = qq~
            SELECT count (distinct peptide_instance_id)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI
            WHERE PEPI.atlas_build_id = '$atlas_build_id'
            AND PEPI.n_observations > 1
            AND PEPI.best_probability >= '$probability'
            ~;
        } else
        {
            $sql = qq~
            SELECT count (distinct peptide_instance_id)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI
            WHERE PEPI.atlas_build_id = '$atlas_build_id'
            AND PEPI.n_observations > 1
            ~;
        }

    } else
    {
        if ($probability)
        {
            $sql = qq~
            SELECT count (distinct peptide_instance_id)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI
            WHERE PEPI.atlas_build_id = '$atlas_build_id'
            AND PEPI.best_probability >= '$probability'
            ~;
        } else
        {
            $sql = qq~
            SELECT count (distinct peptide_instance_id)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI
            WHERE PEPI.atlas_build_id = '$atlas_build_id'
            ~;
        }
    }

    my ($n_distinct_peptides) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: in sql?  $sql \n\n";

    return $n_distinct_peptides;
}

#######################################################################
# get_number_of_distinct_peptides_aligned_to_reference
# @param atlas_build_id
# @param probability
# @return n_distinct_peptides_aligned_to_reference
#######################################################################
sub get_number_of_distinct_peptides_aligned_to_reference
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $probability = $args{probability} || "";

    my $sql;

    if ($N_OBS_GT_1)
    {
        if ($probability)
        {
            $sql = qq~
            SELECT count (distinct peptide_instance_id)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI
            WHERE PEPI.atlas_build_id = '$atlas_build_id'
            AND PEPI.n_observations > 1
            AND PEPI.n_protein_mappings > 0
            AND PEPI.best_probability >= '$probability'
            ~;
        } else 
        {
            $sql = qq~
            SELECT count (distinct peptide_instance_id)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI
            WHERE PEPI.atlas_build_id = '$atlas_build_id'
            AND PEPI.n_observations > 1
            AND PEPI.n_protein_mappings > 0
            ~;
        }

    } else
    {
        if ($probability)
        {
            $sql = qq~
            SELECT count (distinct peptide_instance_id)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI
            WHERE PEPI.atlas_build_id = '$atlas_build_id'
            AND PEPI.n_protein_mappings > 0
            AND PEPI.best_probability >= '$probability'
            ~;
        } else
        {
            $sql = qq~
            SELECT count (distinct peptide_instance_id)
            FROM $TBAT_PEPTIDE_INSTANCE PEPI
            WHERE PEPI.atlas_build_id = '$atlas_build_id'
            AND PEPI.n_protein_mappings > 0
            ~;
        }
    }

    my ($n_distinct_peptides_aligned_to_reference) = 
        $sbeams->selectOneColumn($sql) or
        die "\nERROR: in sql?  $sql \n\n";

    return $n_distinct_peptides_aligned_to_reference;
}


#######################################################################
# get_reference_protein_hash - get hash of reference proteins
# @param atlas_build_id
# @return protein_hash
#######################################################################
sub get_reference_protein_hash
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $sql = qq~
    SELECT distinct B.biosequence_name
    FROM $TBAT_BIOSEQUENCE B
    JOIN $TBAT_ATLAS_BUILD AB
    ON (AB.biosequence_set_id = B.biosequence_set_id)
    WHERE AB.atlas_build_id='$atlas_build_id'
    AND AB.record_status != 'D'
    AND B.record_status != 'D'
    ~;

    my %reference_protein_hash = $sbeams->selectTwoColumnHash($sql) or
        die "\nERROR: in sql?  $sql \n\n";

    return %reference_protein_hash;

}

#######################################################################
# get_protein_hash - get hash with key = protein name, value = num peptides
# @param atlas_build_id
# @param probability
# @return protein_hash
#######################################################################
sub get_protein_hash
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $probability = $args{probability} || "";

    my $sql;

    if ($N_OBS_GT_1)
    {
        if ($probability)
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
                AND PEPI.best_probability >= '$probability'
                AND BB.record_status != 'D'
                )
            FROM $TBAT_PEPTIDE_INSTANCE PEPI,
            $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
            WHERE PM.matched_biosequence_id=B.biosequence_id
            AND PEPI.peptide_instance_id=PM.peptide_instance_id
            AND PEPI.atlas_build_id='$atlas_build_id'
            AND PEPI.n_observations > 1
            AND PEPI.best_probability >= '$probability'
            AND B.record_status != 'D'
            ~;
        } else
        {
            if ($probability)
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
                    AND PEPI.best_probability >= '$probability'
                    AND BB.record_status != 'D'
                    )
                FROM $TBAT_PEPTIDE_INSTANCE PEPI,
                $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
                WHERE PM.matched_biosequence_id=B.biosequence_id
                AND PEPI.peptide_instance_id=PM.peptide_instance_id
                AND PEPI.atlas_build_id='$atlas_build_id'
                AND PEPI.n_observations > 1
                AND PEPI.best_probability >= '$probability'
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
            }
        }

    } else
    {
        if ($probability)
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
                AND PEPI.best_probability >= '$probability'
                AND BB.biosequence_name = B.biosequence_name
                AND BB.record_status != 'D'
                )
            FROM $TBAT_PEPTIDE_INSTANCE PEPI,
            $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
            WHERE PM.matched_biosequence_id=B.biosequence_id
            AND PEPI.peptide_instance_id=PM.peptide_instance_id
            AND PEPI.atlas_build_id='$atlas_build_id'
            AND PEPI.best_probability >= '$probability'
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
    }

    my %protein_hash = $sbeams->selectTwoColumnHash($sql) or
        die "\nERROR: in sql?  $sql \n\n";

    return %protein_hash;

}

#######################################################################
# get_unambiguous_protein_hash - get hash with key = protein name, 
# value = num peptides, where only using prots id'ed through peps
# which map to only 1 prot (no ambiguous peptide id's used)
# @param atlas_build_id
# @param probability
# @return protein_hash
#######################################################################
sub get_unambiguous_protein_hash
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id";

    my $probability = $args{probability} || "";

    my $sql;

    if ($N_OBS_GT_1)
    {
        if ($probability)
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
                AND PEPI.best_probability >= '$probability'
                AND PEPI.n_protein_mappings = 1
                AND BB.record_status != 'D'
                )
            FROM $TBAT_PEPTIDE_INSTANCE PEPI,
            $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
            WHERE PM.matched_biosequence_id=B.biosequence_id
            AND PEPI.peptide_instance_id=PM.peptide_instance_id
            AND PEPI.atlas_build_id='$atlas_build_id'
            AND PEPI.n_observations > 1
            AND PEPI.best_probability >= '$probability'
            AND PEPI.n_protein_mappings = 1
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
                AND PEPI.n_observations > 1
                AND PEPI.n_protein_mappings = 1
                AND BB.record_status != 'D'
                )
            FROM $TBAT_PEPTIDE_INSTANCE PEPI,
            $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
            WHERE PM.matched_biosequence_id=B.biosequence_id
            AND PEPI.peptide_instance_id=PM.peptide_instance_id
            AND PEPI.atlas_build_id='$atlas_build_id'
            AND PEPI.n_observations > 1
            AND PEPI.n_protein_mappings = 1
            AND B.record_status != 'D'
            ~;
        }

    } else
    {
        if ($probability)
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
                AND PEPI.n_protein_mappings = 1
                AND PEPI.best_probability >= '$probability'
                AND BB.biosequence_name = B.biosequence_name
                AND BB.record_status != 'D'
                )
            FROM $TBAT_PEPTIDE_INSTANCE PEPI,
            $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
            WHERE PM.matched_biosequence_id=B.biosequence_id
            AND PEPI.peptide_instance_id=PM.peptide_instance_id
            AND PEPI.n_protein_mappings = 1
            AND PEPI.atlas_build_id='$atlas_build_id'
            AND PEPI.best_probability >= '$probability'
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
                AND PEPI.n_protein_mappings = 1
                AND BB.biosequence_name = B.biosequence_name
                AND BB.record_status != 'D'
                )
            FROM $TBAT_PEPTIDE_INSTANCE PEPI,
            $TBAT_PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B
            WHERE PM.matched_biosequence_id=B.biosequence_id
            AND PEPI.peptide_instance_id=PM.peptide_instance_id
            AND PEPI.n_protein_mappings = 1
            AND PEPI.atlas_build_id='$atlas_build_id'
            AND B.record_status != 'D'
            ~;
        }
    }

    my %protein_hash = $sbeams->selectTwoColumnHash($sql) or
        die "\nERROR: in sql?  $sql \n\n";

    return %protein_hash;

}


###############################################################################
# get_atlas_build_directory  --  get atlas build directory
# @param atlas_build_id
# @return atlas_build:data_path
###############################################################################
sub get_atlas_build_directory
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} or die "need atlas build id($!)";

    my $path;

    my $sql = qq~
        SELECT data_path
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_id = '$atlas_build_id'
        AND record_status != 'D'
    ~;

    ($path) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: Unable to find the data_path in atlas_build record".
        " with $sql\n\n";

    ## get the global variable PeptideAtlas_PIPELINE_DIRECTORY
    my $pipeline_dir = $CONFIG_SETTING{PeptideAtlas_PIPELINE_DIRECTORY};

    $path = "$pipeline_dir/$path";

    ## check that path exists
    unless ( -e $path)
    {
        die "\n Can't find path $path in file system.  Please check ".
        " the record for atlas_build with atlas_build_id=$atlas_build_id";
    }

    return $path;
}

