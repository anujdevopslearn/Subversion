#!/usr/local/bin/perl  -w

#######################################################################
# write_repository_lists -- generates the public and "not public" 
#   xml files for the repository area and handles population of
#   apache accessible files in the public repository area.  
#   The file versioning system within uses timestamp, timestamp
#   property files, and database stored properties to handle
#   versioning. It determines when new files are to be written
#   by comparing properties in the current repository file
#   to properties written into SBEAMS PeptideAtlas records.
#   The information in a timestamp properties text
#   file represents the content of a file in the 
#   apache accessible repository area.  The database properties 
#   information represents the content of file in the sbeams archive
#   file area.  A use case is:  the sbeams archive mzXML files get
#   reconverted to modern mzXML format, and the database properties
#   get updated.  This script would see that that the latest repository
#   mzXML files are lagging behind the files in /sbeams/archive and
#   so would then make new timestamped tar archives and place them
#   in the apache accessible repository area.
#
#   Author: Nichole King
#
#   $Ning Zhang @09062007 Modified the script
#   in order to only show the latest search results and newest mzXML.
#   Before the change, multiple search batches may be existed for one
#   sample and they are showed in the web page and pa_public_archive.
#   (1)change in upload_data() =>get rid of existing mzXML.tar.gz
#   (2)change in write_public_file =>only get the latest search batch results
#   (3)change it run on phoebe
#
#    Zhi Sun @ 20110207 
#    1: use peptideatlas FTP site to store the tar file.
#    2: Create html page directly from this script, remove the dependency of the sForm
#   
#    Zhi Sun @ 20110622
#    clean up: remove all html or php file generation script. only keep the script that 
#    upload the data to ftp site.
#######################################################################

use strict;
use Getopt::Long;
use FindBin;
use File::stat;

use XML::Parser;
use IO::File;
use LWP::UserAgent;
use File::Copy;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $PROG_NAME $USAGE %OPTIONS $TEST $VERBOSE
             $repository_url $repository_path $repository_path_cp
             $sbeams_data_path
             $errorfile $timestamp_pattern
             $public_php_outfile $notpublic_php_outfile
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

## PeptideAtlas classes
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

## Proteomics (for search_batch::data_location)
use SBEAMS::Proteomics::Tables;

use SBEAMS::PeptideAtlas::SpectraDescriptionSetParametersParser; 	 
use SBEAMS::PeptideAtlas::SearchResultsParametersParser;


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


## USAGE:
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: [OPTIONS] key=value key=value ...
Options:
  --test                 test this code, no disk writing
  --test_samples         if would like to run test, using specific samples,
                         can specify them here separated by commas
                         (e.g.,  --test_samples "26,34")
  --test_project_ids        --test_project_id "965" 
  --project_ids
  --samples
  --raw_private               don't release RAW and mzXML|mzML files
  --run 

e.g.:  ./$PROG_NAME  --test_sample 2700 --verbose 1 
			 ./$PROG_NAME  --test_project_ids "965" --verbose 1

EOU

## get arguments:
GetOptions(\%OPTIONS, "test", "verbose:s", "test_samples:s",
           "test_project_ids:s","samples:s", "project_ids:s", "raw_private:s","run");


## check for required arguments:
unless ( $OPTIONS{"test"} || $OPTIONS{"test_samples"} || 
         $OPTIONS{"test_project_ids"} || $OPTIONS{"run"} ||
         $OPTIONS{"project_ids"} || $OPTIONS{"samples"})
{
    print "$USAGE";
    #exit;
};

## check format of test_samples if it's used
if ($OPTIONS{"test_samples"} || $OPTIONS{"samples"})
{
    my @t = split(",", $OPTIONS{"test_samples"});

    unless ($#t >= 0)
    {
        print " Please specify sample ids, seprated by commas.\n"
            . " For example:  --test_samples '54,92'";

        exit;
    }
}


## set some vars based upon arguments:
if ($OPTIONS{"test"}  || $OPTIONS{"test_samples"} || $OPTIONS{"test_project_ids"}){
  $TEST =1;
}else{
  $TEST = 0;
}
  
$VERBOSE = $OPTIONS{"verbose"} || 0;
$sbeams_data_path = "/regis/sbeams/archive/";
$repository_path = "/prometheus/u1/ftp/pub/PeptideAtlas/Repository";
$repository_path_cp =  "/prometheus/u1/ftp/pub/PeptideAtlas/Repository";

$timestamp_pattern = "+%Y%m%d%H%M";
our $notpublic_buffer = '';


if ($TEST)
{
	 $repository_path = "/prometheus/u1/ftp/pub/PeptideAtlas/TEST";
   $repository_path_cp = "/prometheus/u1/ftp/pub/PeptideAtlas/TEST";
}

if( $TEST && $OPTIONS{"run"}){

	$repository_path = "/prometheus/u1/ftp/pub/PeptideAtlas/TEST";
	$repository_path_cp = "/prometheus/u1/ftp/pub/PeptideAtlas/TEST";

}

#### execute main #####
main();

exit(0);


###############################################################################
# main
###############################################################################
sub main 
{
    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ( $current_username = 
        $sbeams->Authenticate(connect_read_only => '1')
    );

    ## make sure that user is on atlas:
    check_host();

    ## check that mandatory sample annotation exists
    unless ($TEST)
    {
        check_samples();
    }
    write_public_file();
    #write_private_file();
} ## end main


#######################################################################
# check_host -- check that host name is atlas as we need to write to
#   /sbeams/
#######################################################################
sub check_host()
{
    ## make sure that this is running on atlas for queries
    my $uname = `uname -a`;

    #unless ($uname =~ /.*(dione).*/)
    #{
    #    die "you must run this on dione";
    #}
}

#######################################################################
# check_samples -- checks that all samples have needed annotation.
# for example, we shouldn't post data missing data_contributors field
#######################################################################
sub check_samples
{
    my $sql = qq~
        SELECT S.sample_tag, S.data_contributors
        FROM $TBAT_SAMPLE S
        WHERE S.record_status != 'D'
        AND is_public='Y'
        ORDER BY S.sample_tag
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records using $sql";

    my $exit_flag = 0; ## false

    foreach my $row (@rows)
    {
        my ($st, $dc) = @{$row};

        if ($dc eq "")
        {
            print "[ERROR] $st is missing data_contributors\n";

            #$exit_flag = 1;
        }

    }

    if ($exit_flag)
    {
        die "\nNeed to fill in data_contributors before running this\n";
    } else
    {
        print "\nHave all of minimum required sample annotation\n";
    }

}


#######################################################################
# write_public_file -- writes repository_public.xml file.  
#    While at it, sees if files exist in public archive area, and if
#    so, sees if they are the most current known.  If the files are not
#    the most current, it makes tar archives of the most
#    current and copies them to the public archive area, with a timestamp
#    in their name, and a timestamped properties file containing the
#    the fundamental properties of the file to check for changes
#    (changes such as mzXML schema version, for example).
#
#    NOTE: method essentially stores the results from a query for all sample 
#    records into a data structure and re-uses the structure.  if
#    one day find ourselves memory limited, will need to break
#    get_publication_info(), get_public_sample_info(), and 
#    get_data_directories() into queries that produce smaller returns
#    here and change iteration accordingly...this procedure should
#    probably be it's own module too.
#######################################################################
sub write_public_file
{
    my $sql;

    my $sample_ids = $OPTIONS{raw_private};
    $sample_ids =~ s/"//g;
    $sample_ids =~ s/'//g;
    $sample_ids =~ s/\s+//g;
    my @t = split(",",$sample_ids);
    my %raw_private = map { $_ => 1 } @t;
 
     
    if ($OPTIONS{"test_samples"} || $OPTIONS{"test_project_ids"})
    {
        ## get a string of sample id formatted for use in IN clause of
        ## SQL statement
        my $test_sample_ids ='';
        if($OPTIONS{"test_samples"}  ne ''){
          $test_sample_ids = formatSampleIDs(
            sample_ids => $OPTIONS{"test_samples"});
        }elsif($OPTIONS{"test_project_ids"} ne ''){
          my $test_project_ids = formatSampleIDs(
            sample_ids => $OPTIONS{"test_project_ids"});
          $test_sample_ids = qq~
						SELECT DISTINCT S.SAMPLE_ID
						FROM
						$TBPR_PROTEOMICS_EXPERIMENT E,
						$TBPR_SEARCH_BATCH SB,
						$TBAT_ATLAS_SEARCH_BATCH ASB,
						$TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB,
						$TBAT_SAMPLE S
						WHERE
						E.EXPERIMENT_ID = SB.EXPERIMENT_ID
						AND SB.SEARCH_BATCH_ID = ASB.PROTEOMICS_SEARCH_BATCH_ID
						AND ASB.SAMPLE_ID = ABSB.SAMPLE_ID
						AND ABSB.SAMPLE_ID = S.SAMPLE_ID
						AND E.PROJECT_ID in ($test_project_ids)
         ~;
        } 
        $sql = qq~
        SELECT distinct S.sample_accession, S.sample_tag, S.sample_id,
        O.organism_name, S.is_public
        FROM $TBAT_SAMPLE S
        JOIN $TBAT_ATLAS_BUILD_SAMPLE ABS ON (ABS.sample_id = S.sample_id)
        JOIN $TBAT_ATLAS_BUILD AB ON (AB.atlas_build_id = ABS.atlas_build_id)
        JOIN $TBAT_BIOSEQUENCE_SET BS ON (BS.biosequence_set_id = AB.biosequence_set_id)
        JOIN $TB_ORGANISM O ON (BS.organism_id = O.organism_id)
        WHERE 
        S.is_public = 'Y' AND 
        S.record_status != 'D'
        AND S.sample_id IN ($test_sample_ids)
        --AND AB.atlas_build_id= 366
        ORDER BY O.organism_name, S.sample_tag
        ~;
        print "$sql\n";
        
    } elsif ($OPTIONS{"test"}  and ( ! $OPTIONS{"test_samples"} and !  $OPTIONS{"test_project_ids"}) and ! $OPTIONS{"run"})
    {   ## Use 2 records for TEST
        $sql = qq~
        SELECT distinct top 2 S.sample_accession, S.sample_tag, S.sample_id,
        O.organism_name, S.is_public
        FROM $TBAT_SAMPLE S
        JOIN $TBAT_ATLAS_BUILD_SAMPLE ABS ON (ABS.sample_id = S.sample_id)
        JOIN $TBAT_ATLAS_BUILD AB ON (AB.atlas_build_id = ABS.atlas_build_id)
        JOIN $TBAT_BIOSEQUENCE_SET BS ON (BS.biosequence_set_id = AB.biosequence_set_id)
        JOIN $TB_ORGANISM O ON (BS.organism_id = O.organism_id)
        WHERE S.is_public = 'Y' AND S.record_status != 'D'
        ORDER BY O.organism_name, S.sample_tag
        ~;

    } else
    {
        my $sample_id_clause='';
        if($OPTIONS{"samples"}  ne ''){
          $sample_id_clause = "AND S.sample_id IN (" .  formatSampleIDs(sample_ids => $OPTIONS{"samples"});
          $sample_id_clause .= ")"; 
        }
        if( $OPTIONS{"project_ids"} ne ''){
          my $project_ids = formatSampleIDs(
            sample_ids => $OPTIONS{"project_ids"});
          $sample_id_clause = qq~
            AND S.sample_id in (
            SELECT DISTINCT S.SAMPLE_ID
            FROM
            $TBPR_PROTEOMICS_EXPERIMENT E 
            JOIN $TBPR_SEARCH_BATCH SB ON (E.EXPERIMENT_ID = SB.EXPERIMENT_ID)
            JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON (SB.SEARCH_BATCH_ID = ASB.PROTEOMICS_SEARCH_BATCH_ID)
            RIGHT JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON ( ASB.SAMPLE_ID = ABSB.SAMPLE_ID)
            JOIN $TBAT_SAMPLE S ON (ABSB.SAMPLE_ID = S.SAMPLE_ID)
            WHERE E.PROJECT_ID in ($project_ids))
           ~;
        }
        $sql = qq~
        SELECT distinct S.sample_accession, S.sample_tag, S.sample_id,
        O.organism_name, S.is_public
        FROM $TBAT_SAMPLE S
        JOIN $TBAT_ATLAS_BUILD_SAMPLE ABS ON (ABS.sample_id = S.sample_id)
        JOIN $TBAT_ATLAS_BUILD AB ON (AB.atlas_build_id = ABS.atlas_build_id)
        JOIN $TBAT_BIOSEQUENCE_SET BS ON (BS.biosequence_set_id = AB.biosequence_set_id)
        JOIN $TB_ORGANISM O ON (BS.organism_id = O.organism_id)
        WHERE 
        S.is_public = 'Y' AND 
        S.record_status != 'D'
        $sample_id_clause
        AND S.sample_id != '198' AND S.sample_id != '292'
        and ABS.atlas_build_id = 451
        ORDER BY O.organism_name, S.sample_tag
        ~;
        ## xx temporarily adding ignore MicroProt datasets as their 
        ## interact file names are too highly specialized...
    }

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records using $sql";
    my $count = 0;
    ## store query results in $sample_info
    foreach my $row (@rows) 
    {
        $count = $count + 1;
        my (@file_array_for_README, @pubmed_id_array_for_README);
        my (@pub_cit_array_for_README, @pub_url_array_for_README);
        my ($sample_accession, $sample_tag, $sample_id, $organism, 
            $is_public) = @{$row};
       # unless ( $sample_id eq '517' or $sample_id eq '413' or $sample_id eq '1715' or $sample_id eq '1950'
       #          or $sample_id eq '2536' or $sample_id eq '156'){
       #   next;
       # }
        my $sql2 = qq~
        SELECT S.sample_description, S.data_contributors
        FROM $TBAT_SAMPLE S
        WHERE S.sample_id = '$sample_id'
        AND S.record_status != 'D'
        ~;

        next if($organism eq 'Chimpanzee' );

        if($organism eq 'Honeybee'){
          $organism = 'HoneyBee';
        }

        #next if ($organism !~/human/i);
				#next if(not defined $list{$sample_accession});
        next if ( -l "/prometheus/u1/ftp/pub/PeptideAtlas/Repository/$sample_accession" || 
                  -d "/prometheus/u1/ftp/pub/PeptideAtlas/Repository/$sample_accession" );
        print "$sample_tag $sample_accession $sample_id\n";

        $organism =~ s/\s+/_/g;
        if (! -d "$repository_path/$organism" ){
           mkdir "$repository_path/$organism";
        }
        if(! -d "$repository_path/$organism/$sample_accession"){
					mkdir  "$repository_path/$organism/$sample_accession";
        }
        $repository_path = "$repository_path/$organism/$sample_accession";

        my @rows2 = $sbeams->selectSeveralColumns($sql2) or 
            die "Couldn't find sample records using $sql2";

        my ($sample_description, $data_contributors);

        ## store query results in $sample_info
        foreach my $row2 (@rows2) 
        {
            my ($d, $c) = @{$row2}; 
            ## replace dos end of line markers (\r) and (\n) with space
            $sample_description = $d;
            $data_contributors = $c;
            $sample_description =~ s/\r/ /g;
            $sample_description =~ s/\n/ /g;
            $data_contributors =~ s/\r/ /g;
            $data_contributors =~ s/\n/ /g;
        }
 
        ######### handle the remaining resources  ####
        #### resource mzXML_format
        #### resource RAW_format
        #### resource Search_Results
        #### resource ProteinProphet_file
        #### resource sequest.params
        #### resource qualscore_results
        #### publication citation
        #### resource README

        ## (1 sample record <--> 1 spectra_description_set). i.e. not pointing to last mzXML file
        ## anymore in the repository xml file for clarity, but the older archive files will still
        ## be present in the apache accessible archive area for anyone dialing up the url directly.
        my $spectra_data_dir = get_spectra_location( sample_id => $sample_id);
        #if ($organism eq 'HoneyBee'){
        #  goto TPP;
        #}
        if($raw_private{$sample_id}){ goto TPP;}
				#goto TPP; ## zhi


        ## get mzXML url, check properties of database with timestamp properties file ( if lagging,
        ## pack up new files etc, or if the archive doesn't already exist create the archive file, etc)
        upload_mzXML(  sample_id => $sample_id,
            sample_accession => $sample_accession, spectra_data_dir => "$spectra_data_dir");
        goto TPP;

        ## get orig data type by searching data dir for known suffixes
        my $origDataType = get_orig_data_type( data_dir => "$spectra_data_dir");

        if ($origDataType)
        {
            ## get original data url, if don't see it in the public repository, pack up files etc, 
            ## [this uses a subset of upload_data, so one day, could redesign those few subs...]
            ## For some of the older HUPO datasets, the original spectra aren't available,
            ## so we only have the dtas.  We're giving those a datatype/suffix of dtapack
            ## which means there are a few special edits for it in several places in this
            ## script (search for dta to edit those)

            upload_orig_data(  
                sample_id => $sample_id,
                sample_accession => $sample_accession, 
                spectra_data_dir => "$spectra_data_dir",
                orig_data_type => $origDataType,
            );
        }

       TPP:
        ###########  iterate over all search batches for this sample #############
       	#unlike before, we only want to latest search results
      	#in other words, the highest atlas_search_batch_id

        $sql2 = qq~
            SELECT distinct ASB.TPP_version, ASB.atlas_search_batch_id, ASB.data_location,
            ASB.search_batch_subdir
            FROM $TBAT_ATLAS_SEARCH_BATCH ASB
            JOIN $TBAT_SPECTRA_DESCRIPTION_SET SDS
            ON (ASB.atlas_search_batch_id = SDS.atlas_search_batch_id)
            JOIN $TBAT_SAMPLE S ON (S.sample_id = SDS.sample_id)
            WHERE S.sample_id = '$sample_id'
            AND --S.is_public = 'Y' AND 
            S.record_status != 'D'
            ORDER BY ASB.atlas_search_batch_id DESC
        ~;

        @rows2 = $sbeams->selectSeveralColumns($sql2) or 
        die "Couldn't find ATLAS_SEARCH_BATCH records for sample $sample_id";

      	#Ning changed the following code
        #foreach my $row2 (@rows2) 
        #{
            my ($TPP_version, $atlas_search_batch_id, $data_location,
                $search_batch_subdir) = @{$rows2[0]};
            
            $data_location = $data_location . "/" . $search_batch_subdir;

            ## if path has /data3/sbeams/archive/, remove that
            $data_location =~ s/^(.*sbeams\/archive\/)(.+)$/$2/gi;

            ## if path starts with a /, remove that
            $data_location =~ s/^(\/)(.+)$/$2/gi;

            ## make absolute path
            $data_location = "$sbeams_data_path/$data_location";

            ## make sure it exists:
            unless ( -d $data_location )
            {
                die "$data_location does not exist";
            }

            ## for each row returned, get a url (checking for timestamp properties file, etc)
            ## NOTE, this leads to copy over of the sequest.params file and the qualscore_results
            ## too, so will recover those filenames next with file tests
            upload_search_result (
                TPP_version => $TPP_version,
                atlas_search_batch_id => $atlas_search_batch_id, 
                sample_accession => $sample_accession,
                search_results_dir => $data_location,
            );

            ## retrieve and write tags for params and qualscore_results 
            my $prefix = $sample_accession . "_" . $atlas_search_batch_id;
            my $search_params_file_name = "$prefix" . "_search.params";
            my $hqus_file_name = "$prefix" . "_qualscore_results";

            upload_sb_files (
                file_name => $search_params_file_name,
                sb_file_name => "params",
                search_results_dir => $data_location,
            );

            upload_sb_files (
                file_name => $hqus_file_name,
                sb_file_name => "qualscore_results",
                search_results_dir => $data_location,
            );

            ## for each row returned, get a url (checking for timestamp properties file, etc)
            upload_protein_prophet_files (
                TPP_version => $TPP_version,
                atlas_search_batch_id => $atlas_search_batch_id,
                sample_accession => $sample_accession,
                search_results_dir => $data_location,
            );

        ####  handle publication citations  #####
        my $sql3 = qq~
            SELECT P.publication_name, P.uri, P.pubmed_ID
            FROM $TBAT_PUBLICATION P
            JOIN $TBAT_SAMPLE_PUBLICATION SP ON (P.publication_id = SP.publication_id)
            JOIN $TBAT_SAMPLE S ON (S.sample_id = SP.sample_id)
            WHERE S.sample_id = '$sample_id'
            AND SP.record_status != 'D'
        ~;

        my @rows3 = $sbeams->selectSeveralColumns($sql3);
        foreach my $row3 (@rows3) 
        {
            my ($pub_name, $pub_url, $pubmed_id) = @{$row3};

            ## write url to xml file as attribute in a resource element
            push(@pubmed_id_array_for_README, $pubmed_id);

            push(@pub_cit_array_for_README, $pub_name);

            push(@pub_url_array_for_README, $pub_url);
        } 

        ## writes the readme file and returns its URL
        write_readme(
            sample_accession => $sample_accession,
            sample_tag => $sample_tag,
            organism => $organism,
            description => $sample_description,
            data_contributors => $data_contributors,
            array_of_pub_cit_ref => \@pub_cit_array_for_README,
            array_of_pub_url_ref => \@pub_url_array_for_README,
            array_of_pubmed_ids_ref => \@pubmed_id_array_for_README,
        );
        $repository_path = $repository_path_cp;
    } ## end loop over samples

}

#######################################################################
#  upload_mzXML -- get mzXML url, check properties of database with
#      timestamp properties file and pack up new files if the archive
#      doesn't already exist to create the archive file
# @param sample_id
# @param sample_accession
# @param spectra_data_dir
# @return url for gzipped mzXML archive
#######################################################################
sub upload_mzXML
{
    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id";

    my $sample_accession = $args{sample_accession} or die "need sample_accession";

    my $spectra_data_dir = $args{spectra_data_dir} or die "need spectra_data_dir";

    ## Get hash of spectra info with keys: conversion_software_name, conversion_software_version,
    ## and mzXML_schema
    my %spectra_properties = get_spectra_properties_info_from_db( sample_id => $sample_id);

    ## Look for latest mzXML file in the archive (it will need to have 
    ## timestamp already in it, no compatibility with old unversioned 
    ## files, as want to create structure anew, while preserving old
    ## files in the archive for people to find if they are looking)
    ##    if latest mzXML is found, get the timestamp txt file and 
    ##        compare it to database properties
    ##        if properties file is lagging behind database,
    ##            create new properties file and new gzipped archive
    ##            return that url
    ##        else return the url for the already up to date mzXML gzipped archive
    ##    else, there's no versioned mzXML file yet, so create it and create the timestamped
    ##    properties file
    ## This functionality is generalized in upload_data so that other operations can use it...
    
    upload_data(
        sample_accession => $sample_accession,
        data_dir => $spectra_data_dir,
        file_suffix => "mzXML",
        file_pattern => "mz*ML",
        properties_ref => \%spectra_properties
    );

}

#######################################################################
# upload_data -- given sample_accession, search dir, and data_type, 
# gets the url of the gzipped tar file.  
#
# Looks for latest gzipped archive file_pattern file in $repository_path
#     If the file is found, get it's complementary properties timstamp file
#         and compare contents to database properties
#         If the properties timstamp file is lagging behind database properties
#             create new properties file and new gzipped archive
#             return that url
#         Else return the url for the existing (already up-to-date) gzipped archive
#     Else there's no versioned gzipped archive file_pattern file yet, so create
#         and create the complementary properties file
# Else file pattern doesn't exist, so return null.  This can happen, for example
# when the orginal vendor specific spectra are missing.
#
# @param sample_accession
# @param data_dir
# @param properties_ref -- reference to hash of properties from database
# @param file_suffix  to use as archive file suffix (for example "searched")
# @param file_pattern to use for inclusion in archive file 
#    (for example "mzXML")
#    (for example "inter ASAP tgz html sequest")
# @return data_url of compressed archive file; returns nothing if
#    if files with file_pattern don't exist.  (for example, happens
#    when original vendor specific spectra are missing)
#######################################################################
sub upload_data
{
    my %args = @_;

    my $sample_accession = $args{sample_accession} || die "need sample_accession";

    my $data_dir = $args{data_dir} || die "need data directory for $sample_accession";

    my $properties_ref = $args{properties_ref} or die "need properties_ref";

    my %properties = %{$properties_ref};

    my $file_suffix = $args{file_suffix} || 
        error_message ( 
            message => "need file_suffix for $sample_accession, looking in $data_dir ($!)");

    my $file_pattern = $args{file_pattern} || die "need file_pattern for list($!)";

    #### make a file containing files with pattern: ####
    my $fileWithFileNames = "tt.txt";

    my $pat = $sample_accession . "*" . $file_pattern . "*" . "gz";

    ## files are in $repository_path, but be careful not to include $repository_path/TESTFILES
    my $cmd = "find $repository_path -maxdepth 1 -name \'$pat\'  -print > $fileWithFileNames";
    ## where each file in $fileWithFileNames is given as the absolute path to the file
    print "$cmd\n" if ($VERBOSE);
    system $cmd;

    my $latestFile = "";

    ## if filelist is not empty
    if (-s $fileWithFileNames)
    {
        ## [case: files matching pattern exist (could be versioned and un-versioned)]
        $latestFile = getLatestFileName( fileWithFileNames => $fileWithFileNames ); 
        ## this is absolute path
    }

    if ($latestFile)
    {
        ## [case: versioned files exist, and we found the latest]

        ## compare properties timestamp file to database properties
        ## and return true if it is current, or false if it is not
        my $fileIsCurrent = isFileCurrent( file => $latestFile, properties_ref => $properties_ref);

       if ($fileIsCurrent)
       {
            ## [case: versioned file exists and is in sync with database info]

       } else
       {
            ## [case: versioned file is lagging behind database info]

            ## create new properties file and new gzipped archive, 
            ## return absolute path (= $repository_path/file)
            ## for newly created gzipped archive
            ## AND update the database information
      	    ## Ning_added, remove all other versions of mzXML.tar.gz
	          my $rm_pat = "$repository_path/$pat";
	          system "rm -f $rm_pat";

            $latestFile = makeNewArchiveAndProperties(
                sample_accession => $sample_accession,
                data_dir => $data_dir,
                file_suffix => $file_suffix,
                file_pattern => $file_pattern
            );
       }

    } else
    {
        ## [case: no versioned file exists yet]
           
        ## create new properties file and new gzipped archive
        ## return url for newly created gzipped archive
        ## AND update the database information
        ## create new properties file and new gzipped archive,
        ## return absolute path (= $repository_path/file)
        ## for newly created gzipped archive
        ## AND update the database information
        $latestFile = makeNewArchiveAndProperties(
            sample_accession => $sample_accession,
            data_dir => $data_dir,
            file_suffix => $file_suffix,
            file_pattern => $file_pattern
        );
    }

}


#######################################################################
# get_orig_data_type -- given data_dir, gets orig data type
# @param data_dir - absolute path to data
# @return data_type (e.g. .RAW, .raw, or dtapack)
#######################################################################
sub get_orig_data_type
{
    my %args = @_;

    my $data_dir = $args{data_dir} ||
        die "need data directory ($!)";

    my $orig_data_type="";


    ## check for .RAW files:
    unless ($orig_data_type)
    {
      foreach my $type (qw(RAW raw wiff WIFF yep baf dtapack)){
        my @files = `find $data_dir -maxdepth 2 -name \'*.$type*\'  -print`;

        if ( $#files > -1)
        {
            $orig_data_type = "$type";
        }
      }
    }


#    ## check for .raw files:
#    unless ($orig_data_type)
#    {
#        my @files = `find $data_dir -maxdepth 1 -name \'*.raw\' -print`;
#
#        if ( $#files > -1)
#        {
#            $orig_data_type = "raw";
#        }
#    }
#
#
#    ## check for dta.tar files:
#    unless ($orig_data_type)
#    {
#        my @files = `find $data_dir -maxdepth 1 -name \'*_dta.tar\' -print`;
#
#        if ( $#files > -1)
#        {
#            $orig_data_type = "dtapack";
#        }
#    }
#
    return $orig_data_type;
}


#######################################################################
# get_spectra_location -- gets the data directory holding spectra for
# the sample
# @param sample_id
# @return absolute path to data holding the spectra
#######################################################################
sub get_spectra_location
{
    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id";

    my $sql = qq~
        SELECT distinct ASB.data_location + '/' + ASB.search_batch_subdir 
        FROM $TBAT_ATLAS_SEARCH_BATCH ASB
        JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB 
        ON (ABSB.atlas_search_batch_id = ASB.atlas_search_batch_id)
        WHERE ABSB.sample_id = '$sample_id'
        AND ABSB.record_status != 'D'
        AND ASB.record_status != 'D'
    ~;

    my ($data_path) = $sbeams->selectOneColumn($sql) or 
        die "Could not find atlas_search_batch for sample_id = $sample_id";

print $data_path , "\n";
    ## if $data_path has /data3/sbeams/archive/, remove that
    $data_path =~ s/^(.*sbeams\/archive\/)(.+)$/$2/gi;
        
    ## if $data_path starts with a /, remove that
    $data_path =~ s/^(\/)(.+)$/$2/gi;

    $data_path = "$sbeams_data_path/$data_path";
print $data_path , "\n";

    ## make sure it exists:
    if ( ! -d $data_path){
       $data_path =~ s/(.*)\/.*/$1/;
    }
    unless (-d $data_path)
    {
        die "$sample_id: $data_path doesn't exist";
    }

    return $data_path;
}


#######################################################################
# get_spectra_properties_info_from_db -- get spectra info
# @param sample_id
# @return complex hash of format:
#     $spectra_info{$sample_id}->{conversion_software_name}
#     $spectra_info{$sample_id}->{conversion_software_version}
#     $spectra_info{$sample_id}->{mzXML_schema}
#######################################################################
sub get_spectra_properties_info_from_db
{
    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id";

    my %spectra_info;

    my $sql = qq~
        SELECT conversion_software_name, conversion_software_version,
        mzXML_schema, spectra_description_set_id
        FROM $TBAT_SPECTRA_DESCRIPTION_SET
        WHERE sample_id = '$sample_id'
        AND record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find spectra_description_set for sample_id = $sample_id";

    ## store query results in $sample_info
    foreach my $row (@rows) 
    {
        my ($c_s_n, $c_s_v, $m_s, $s_d_s_i) = @{$row};

        $spectra_info{conversion_software_name} = $c_s_n;

        $spectra_info{conversion_software_version} = $c_s_v;

        $spectra_info{mzXML_schema} = $m_s;
     
        $spectra_info{spectra_description_set_id} = $m_s;
    }

    return %spectra_info;
}


#######################################################################
# get_notpublic_sample_info -- get ExpTag, CellType, and DataContributors
#    for the "not public" datasets
#######################################################################
sub get_notpublic_sample_info
{
    my %sample_info;

    ## get sample info:
    my $sql = qq~
        SELECT S.sample_tag, S.cell_type_term, O.organism_name,
            S.data_contributors
        FROM $TBAT_SAMPLE S
        JOIN $TBPR_SEARCH_BATCH SB 
            ON (SB.search_batch_id = S.search_batch_id)
        JOIN $TBPR_BIOSEQUENCE_SET BS 
            ON (BS.biosequence_set_id = SB.biosequence_set_id)
        JOIN $TB_ORGANISM O ON (BS.organism_id = O.organism_id)
        WHERE is_public = 'N'
    ~;


    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records ($!)";

    ## store query results in $sample_info
    foreach my $row (@rows) 
    {

        my ($sample_tag, $cell_type, $organism, $data_contributors) = @{$row};

        if($data_contributors){
          $data_contributors =~ s/\r/ /g;

          $data_contributors =~ s/\n/ /g;
        }
        $sample_info{$sample_tag}->{cell_type} = $cell_type;

        $sample_info{$sample_tag}->{organism} = $organism;

        $sample_info{$sample_tag}->{data_contributors} = $data_contributors;

    }


    ## assert data structure contents:
    if ($TEST)
    {
        foreach my $row (@rows)
        {
            my ($sample_tag, $cell_type, $organism, $data_contributors) = @{$row};

           # if ($sample_info{$sample_tag}->{cell_type} ne $cell_type)
           # {
           #     warn "TEST fails for " .
           #         "$sample_info{$sample_tag}->{cell_type} ($!)".
           #         " ($sample_info{$sample_tag}->{cell_type} != " .
           #         " $cell_type)\n";
           # }

            if ($sample_info{$sample_tag}->{organism} ne $organism)
            {
                warn "TEST fails for " .
                    "$sample_info{$sample_tag}->{organism} ($!)".
                    " ($sample_info{$sample_tag}->{organism} != " .
                    " $organism)\n";
            }
        }

    } ## end TEST


    return %sample_info;

}
   
#######################################################################
# get_public_sample_info -- get relevant attributes from all public
# sample records and store it into complex hash with key=sample_accession
#######################################################################
sub get_public_sample_info
{
    my %sample_info;

    ## get sample info:
    my $sql = qq~
        SELECT S.sample_accession, S.sample_tag, S.sample_id, 
            O.organism_name, S.sample_description, S.data_contributors, 
            S.is_public, S.sample_publication_ids
        FROM $TBAT_SAMPLE S
        JOIN $TBAT_BIOSEQUENCE_SET BS ON (BS.project_id = S.project_id)
        JOIN $TB_ORGANISM O ON (BS.organism_id = O.organism_id)
        WHERE S.is_public = 'Y'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records ($!)";

    ## store query results in $sample_info
    foreach my $row (@rows) 
    {
        my ($sample_accession, $sample_tag, $sample_id, $organism, 
            $sample_description,
            $data_contributors, $is_public, $sample_publication_ids) 
            = @{$row};

        ## replace dos end of line markers (\r) and (\n) with space
        $sample_description =~ s/\r/ /g;

        $sample_description =~ s/\n/ /g;

        $data_contributors =~ s/\r/ /g;

        $data_contributors =~ s/\n/ /g;

        $sample_info{$sample_accession}->{sample_id} = $sample_id;

        $sample_info{$sample_accession}->{sample_tag} = $sample_tag;

        $sample_info{$sample_accession}->{organism} = $organism;

        $sample_info{$sample_accession}->{description} = $sample_description;

        $sample_info{$sample_accession}->{data_contributors} = $data_contributors;

        $sample_info{$sample_accession}->{is_public} = $is_public;

        $sample_info{$sample_accession}->{publication_ids} = $sample_publication_ids;

    }

    return %sample_info;
}
   
#######################################################################
# write_private_file -- writes repository_notpublic.xml file.  
#
#######################################################################
sub write_private_file
{

    ## Get sample information. Structure is: 
    ##  $samples{$sample_tag}->{cell_type} = $cell_type;
    ##  $samples{$sample_tag}->{organism} = $cell_type;
    ##  $samples{$sample_tag}->{data_contributors} = $data_contributors;
    my %samples = get_notpublic_sample_info();


    ## iterate over sample_tags, writing formatted info to file:
    foreach my $sample_tag ( sort keys %samples)
    {
        my $cell_type = $samples{$sample_tag}->{cell_type};

        my $organism = $samples{$sample_tag}->{organism};

        my $data_contributors = $samples{$sample_tag}->{data_contributors};

        write_to_notpublic_file(
            sample_tag => $sample_tag,
            organism => $organism,
            data_contributors => $data_contributors,
            cell_type => $cell_type
        );

    }

}

#######################################################################
# write_to_notpublic_file -- write info to "not public" repository file
#######################################################################
sub write_to_notpublic_file
{
    my %args = @_;

    my $sample_tag = $args{'sample_tag'} || die "need sample_tag";

    my $organism = $args{'organism'} || die "need organism for $sample_tag";

    my $data_contributors; 
    if ($TEST)
    {
        $data_contributors = $args{data_contributors} || ''; ## dev database isn't annotated
    } else
    {
        $data_contributors = $args{data_contributors} || '';
            # or die "need data_contributors for sample_tag $sample_tag";
    }

    if($data_contributors ne ''){
      $data_contributors =~ s/\r/ /g;
      $data_contributors =~ s/\n/ /g;
    }
    my $cell_type = $args{'cell_type'} || "[]"; ## might not be in record

   ######## write to xml file: ########
    writeNotPublicPhpSample(
        sample_tag => $sample_tag,
        organism => $organism,
        cell_type => $cell_type,
        data_contributors => $data_contributors,
    );

}


#######################################################################
# writeNotPublicXMLSample -- write not public sample info to xml file.  
#
# Format is:
# <sample>
#   <sample_tag>A8_IP</sample_tag>
#   <organism>Human</organism>
#   <cell_type>Human Erythroleukemia K562 cell line</cell_type>
# </sample>
#
#######################################################################

sub writeNotPublicPhpSample
{
    my %args = @_;

    ## read arguments:
    my $sample_tag = $args{'sample_tag'} || die "need sample tag ($!)";

    my $cell_type = $args{'cell_type'} || die "need cell_type ($!)";

    my $organism = $args{'organism'} || die "need organism ($!)";

    my $data_contributors;
    if ($TEST)
    {
        $data_contributors = $args{data_contributors}; ## dev database isn't annotated
    } else
    {
       $data_contributors = $args{data_contributors} #zhi or die "need data_contributors";
    }
    $notpublic_buffer .= qq~
         <tr><td class="rep">$sample_tag</td>
         <td class="rep">$organism</td>
         <td class="rep">$data_contributors</td>
         </tr>
    ~;
}

##################################################################
# getLatestFileName - get the filename with the most recent timestamp
# (where filenames are in in file).  It will return null if it didn't
# find a versioned file in the list.
# @param fileWithFileNames
# @return latestFile - file with most recent timestamp, or null if
# no versioned files were in list
#######################################################################
sub getLatestFileName
{
    my %args = @_;

    my $infile = $args{fileWithFileNames} or die "need fileWithFileNames";

    my $latestFile;

    ##$timestamp_pattern = "%Y%m%d%m%M";
    ## example: 200605050544

    my $latestTimeStamp = 0;

    open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

    while (my $fileName = <INFILE>)
    {
        chomp($fileName);

        if ( $fileName =~ /^(.+)(\d{12})(.+)$/ )
        {
            my $timestamp = $2;

            if ($timestamp > $latestTimeStamp)
            {
                $latestTimeStamp = $timestamp;

                $latestFile = $fileName;
            }
        }

    }

    close(INFILE) or die "Cannot close $infile";

    return $latestFile;
}

#######################################################################
# getAFileInFile - open given file which has a list of files, and
# return the name of the first file in it
# @param fileWithFileNames
# @return aFile - a file in the file which contains a list of files
#######################################################################
sub getAFileInFile
{
    my %args = @_;

    my $infile = $args{fileWithFileNames} or die "need fileWithFileNames";

    my $latestFile;

    open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

    my $fileName = <INFILE>;

    chomp($fileName);

    close(INFILE) or die "Cannot close $infile";

    return $fileName;
}


#######################################################################
# isFileCurrent -- determine if file is current from information
#     in database properties and information in timestamp text file.
#     Note: the file version is the version present in the repository 
#     archive flat file area, while the database version is the version 
#     present in the sbeams archive flatfile area
# @param file - fileName of latest versioned file
# @param properties_ref - reference to hash map holding 
#  properties stored in database to be compared with properties
#  of the versioned file
# @return true for is current, and false for lagging behind database
#######################################################################
sub isFileCurrent
{
    my %args = @_;

    my $file = $args{file} or die "need file";

    my $properties_ref = $args{properties_ref} or die "need properties_ref";

    my %propertiesInDatabase = %{$properties_ref};

    ## if file is as current as database, this becomes true:
    my $fileIsCurrent = 0; ## false

    my $propertiesFileName = getPropertiesFileName(
        archiveFileName => $file
    );

    my %propertiesInFile = getPropertiesInFile( 
        propertiesFileName => $propertiesFileName 
    );

    ## comparator for mzXML
    if ( exists $propertiesInDatabase{mzXML_schema} )
    {
        $fileIsCurrent = mzXML_comparator( 
            propertiesInDatabase_ref => \%propertiesInDatabase,
            propertiesInFile_ref => \%propertiesInFile
        );
    }

    return $fileIsCurrent;
}

#######################################################################
# getPropertiesFileName
# @param archiveFileName
# @return propertiesFileName
#######################################################################
sub getPropertiesFileName
{
    my %args = @_;

    my $archiveFileName = $args{archiveFileName} or die "need archiveFileName";

    my $propertiesFileName;

    if ($archiveFileName =~ /^(.+)(\d{12})(.+)$/ )
    {
        $propertiesFileName = "$1$2.properties";
    }

    return $propertiesFileName;
}


#######################################################################
# getPropertiesInFile -- get properties in file
# @param propertiesFileName
# @return hash of properties
#######################################################################
sub getPropertiesInFile
{
    my %args = @_;

    my $infile = $args{propertiesFileName} or die 
        "need propertiesFileName";

    my %propertiesHash;

    open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

    while (my $line = <INFILE>)
    {
        chomp($line);

        if ($line=~ /^(.+)(=)(.+)$/ )
        {
            $propertiesHash{$1} = $3;
        }

    }

    close(INFILE) or die "Cannot close $infile";

    return %propertiesHash;
}


#######################################################################
# writePropertiesFile -- write properties to file
# @param versioned_properties_filename
# @param properties_hash_ref - reference to  hash of properties
#######################################################################
sub writePropertiesFile
{
    my %args = @_;

    my $outfile = $args{versioned_properties_filename} or die 
        "need versioned_properties_filename";

    my $properties_hash_ref = $args{properties_hash_ref} or die
        "need properties_hash_ref";

    my %properties_hash = %{$properties_hash_ref};

    open(OUTFILE, ">$repository_path/$outfile") or die "cannot open $repository_path/$outfile for writing";

    foreach my $key ( keys %properties_hash )
    {
        my $value = $properties_hash{$key};

        print OUTFILE "$key=$value\n";
    }

    close(OUTFILE) or die "Cannot close $outfile";
}


#######################################################################
# mzXML_comparator
# @param $propertiesInDatabase_ref
# @param $propertiesInFile_ref 
# @return 1 if file is current with database, 0 if file is lagging database
#######################################################################
sub mzXML_comparator
{
    my %args = @_;

    my $propertiesInDatabase_ref = $args{propertiesInDatabase_ref} or
        die "need propertiesInDatabase_ref";

    my $propertiesInFile_ref = $args{propertiesInFile_ref} or
        die "need propertiesInFile_ref";

    my %propertiesInDatabase = %{$propertiesInDatabase_ref};

    my %propertiesInFile = %{$propertiesInFile_ref};

    my $fileIsCurrent = 0; ## false

    my $fileIsCurrent_software = 0; ## false

    my $fileIsCurrent_schema = 0; ## false

    my $check_software_version="no";

    my $check_mzXML_schema_version="yes";


    ## spectra if the properties hash holds: mzXML_schema, 
    ## conversion_software_version, or conversion_software_name
        
    if ($check_software_version eq "yes")
    {
        ## compare conversion_software_version for conversion_software_name
        ## ( for now, give up if the conversion_software_name is different,
        ## someday, will need a list of preference when more than one exists)

        if ($propertiesInFile{conversion_software_name} eq 
        $propertiesInDatabase{conversion_software_name})
        {
            my $file_version = $propertiesInFile{conversion_software_version};

            my $db_version = $propertiesInDatabase{conversion_software_version};

            my ($f1, $f2, $f3, $d1, $d2, $d3);

            my $two_decimal_pattern = '^(\d+)\.(\d+)\.(\d+)$';
            my $one_decimal_pattern = '^(\d+)\.(\d+)$';

            if ($file_version =~ /$one_decimal_pattern/)
            {
                $f1 = $1;
                $f2 = $2;
                $db_version =~ /$one_decimal_pattern/;
                $d1 = $1;
                $d2 = $2;
            } elsif ($file_version =~ /$two_decimal_pattern/)
            {
                $f1 = $1;
                $f2 = $2;
                $f3 = $3;
                $db_version =~ /$two_decimal_pattern/;
                $d1 = $1;
                $d2 = $2;
                $d3 = $3;
                if ( ($f1 >= $d1) && ($f2 >= $d2) && ($f3 >= $d3) )
                {
                    $fileIsCurrent_software = 1; ## true
                }
            }
        }
    } ##end check software version


    ## check schema version
    if ($check_mzXML_schema_version eq "yes" )
    {
        ## examples: MsXML, mzXML_2.0, mzXML_2.1, mzXML_1.1.1
        my $schema_pattern = '^(.+)_(.+)$';
        
        my $file_version = $propertiesInFile{mzXML_schema};

        my $db_version = $propertiesInDatabase{mzXML_schema};
        if($file_version =~ /^.+_idx_([\d\.]+).xsd$/)
        {
            $file_version = $1;
        }elsif ($file_version =~ /$schema_pattern/)
        {
            $file_version = $2;
        }else
        {
            $file_version = -1;
        }
        if($db_version =~ /^(.+)_idx_([\d\.]+).xsd$/)
        {
           $db_version = $1;
        }
        elsif ($db_version =~ /$schema_pattern/)
        {
            $db_version = $2;
        }
        else
        {
            $db_version = -1;
        }
        
        ## becomes true when file_version is >= db_version.   
        ## file_version should never be > than db_version though, I think...
        $fileIsCurrent_schema = ($file_version >= $db_version) ? 1 : 0;
    } ## end check schema version

    $fileIsCurrent = ($fileIsCurrent_software || $fileIsCurrent_schema) ? 1 : 0;
    #return $fileIsCurrent;
}

#######################################################################
#makeNewArchiveAndProperties -- create new versioned gzipped archive 
# and properties file; move it to $repository_path; update the database;
# and return the absolute path of the versioned gzipped archive file
# NOTE: some specialization for handling mzXML, or search_results
# happens here.  If adding a new versioned file resource, can add
# code here to handle it...
#
# @param sample_accession
# @param data_dir -- absolute path to relevant data in SBEAMS flatfile area
# @param file_suffix -- suffix in the to be created file name.
# [final file name: $sample_accession_$file_suffix_timestamp.tar.gz]
# @param file_pattern -- files of this/these patterns will be included
#     in new versioned gzipped archive
# @param prefix -- a prefix used only for sequest.params name
# @return absolute path of new versioned gzipped archive file
#######################################################################
sub makeNewArchiveAndProperties
{
    my %args = @_;

    my $sample_accession = $args{sample_accession} or die 
        "need sample_accession";

    my $data_dir = $args{data_dir} or die "need data_dir";

    my $file_suffix = $args{file_suffix} or die "need file_suffix";
  
    my $file_pattern = $args{file_pattern} or die "need file_pattern";

    my $prefix = $args{prefix};

    my $versioned_compressed_archive_file_path;

  
    #######  create new versioned gzipped archive and properties file  #######

    ## get a local (relative) filename to use for the .tar file: 
    my $versioned_compressed_archive_filename = 
        get_versioned_compressed_archive_filename(
        sample_accession => $sample_accession,
        file_suffix => $file_suffix,
    );

    ## derive a local (relative) properties file name from that file name
    my $versioned_properties_filename = $versioned_compressed_archive_filename;

    $versioned_properties_filename =~ s/\.tar\.gz/\.properties/;

    print "making $versioned_compressed_archive_filename may take awhile, patience...\n";

    ## get pwd, chdir to orig_data_dir, tar up files, gzip 'em, move 'em
    my $progwd = `pwd`;

    chdir $data_dir || die "cannot chdir to $data_dir ($!)";
    print "chdir $data_dir\n" if ($VERBOSE);

    #### make a file containing files with pattern: ####
    my $filelist = "tt.txt";
    my $cmd = "rm -f $filelist";
    print "$cmd\n" if ($VERBOSE);
    system $cmd;
    my $pat = "*$file_pattern";

    ## if file_pattern is '*.xml *.tgz *.params *ASAP*', we'll
    ## need separate finds
    my @pats = split(" ", $pat);
    $cmd = "find . -maxdepth 2 -name \'$pats[0]*\' -print > $filelist";
    print "1: $cmd\n" if ($VERBOSE);
    system $cmd;
    for (my $i=1; $i <= $#pats; $i++)
    {
        $cmd = "find . -maxdepth 2 -name \'$pats[$i]*\' -print >> $filelist";
        print "2: $cmd\n" if ($VERBOSE);
        system $cmd;
    }
    ## check if the search result is in the dir, if not, this might be te combined search result
    if( $file_suffix =~ /Search_Result/){
       my @search_result_files = `grep '.xml' $filelist | grep -v inter`;
       if(@search_result_files == 0 ){
          print "NO search result found in $data_dir\n" if ($VERBOSE);
          my @all_search_dirs = Get_OriginalSearchDir(data_dir=> $data_dir);
          foreach my $search_dir(@all_search_dirs){
						$data_dir =~ /(.*\/)\.*/;
						my $str = $1;
						if($search_dir =~ /$data_dir/){
							$search_dir =~ s/$data_dir//;
							 print "1: $str $search_dir\n";

						}elsif($search_dir =~ /$str/){
						  $search_dir =~ s/$str/..\//;
							print "2: $str $search_dir\n";
						}
					  $search_dir =~ s/^\/\.\./\.\./; 
            $cmd = "find $search_dir -maxdepth 1 -name '*.pep.xml' -print >> $filelist";
            print "$cmd\n" if ($VERBOSE);
            system $cmd;
          }
       }
    }
    ## if filelist is empty, report error message, and set final file to null: 
    if (-z $filelist)
    {
        error_message ( 
            message => "could not find $file_pattern files in $data_dir",
        );

        $versioned_compressed_archive_file_path = "";

    } else
    {
        my %properties_hash;

        ## if this is an mzXML file, get its properties
        if ( $file_suffix eq "mzXML")
        {
            ## write a properties file with the mzXML characteristics
            my $mzXMLFile = getAFileInFile( fileWithFileNames => $filelist);

            my $spectrum_parser = new SpectraDescriptionSetParametersParser();
            if ($mzXMLFile !~ /\.gz/ &&  $data_dir !~ /smohammed/){
							$spectrum_parser->setSpectrumXML_file($mzXMLFile);

							$spectrum_parser->parse();

							my $mzXML_schema = $spectrum_parser->getSpectrumXML_schema();
							my $conversion_software_name = $spectrum_parser->getConversion_software_name();

							my $conversion_software_version = $spectrum_parser->getConversion_software_version();

							%properties_hash = ( mzXML_schema => $mzXML_schema,
									conversion_software_name => $conversion_software_name,
									conversion_software_version => $conversion_software_version);
            }
        } elsif ( ($file_suffix =~ /^Search(.*)/) || ($file_suffix =~ /^prot_(.*)/) )
        {
            my $results_parser = new SearchResultsParametersParser();

            $results_parser->setSearch_batch_directory($data_dir);

            $results_parser->parse();

            my $TPP_version = $results_parser->getTPP_version();

            %properties_hash = ( TPP_version => $TPP_version );
        }
         
        writePropertiesFile(
            versioned_properties_filename => $versioned_properties_filename,
            properties_hash_ref => \%properties_hash);


        ## get archive filename from $versioned_compressed_archive_filename
        #my $versioned_archive_filename = $versioned_compressed_archive_filename;
        #$versioned_archive_filename =~ s/\.gz//;

        ## make tar file
        my $cmd = "tar -v -h -czf $repository_path/$versioned_compressed_archive_filename --files-from=$filelist";
        print "$cmd\n" if ($VERBOSE);
        system $cmd;
    
        my $check_path1 = $repository_path . "/" . $versioned_compressed_archive_filename;

        my $check_path2 = $repository_path . "/" . $versioned_properties_filename;

        ## update the database, but make sure the move completed first:
        if ( (-e $check_path1 ) && ( -e $check_path2 ) )
        {
            if (exists $properties_hash{mzXML_schema})
            {
                updateDatabaseSpectrumProperties ( 
                    properties_hash_ref => \%properties_hash );

            } elsif (exists $properties_hash{TPP_version})
            {
                ## don't update database.  we don't offer any search results
                ## that haven't already been loaded
                
                ## make a copy of sequest.params file though.
                my $timestamp;
                if ($versioned_properties_filename =~ /^(.*)\_(.*)(\.tar\.gz)$/ )
                {
                    $timestamp = $2;
                }

                if ( $prefix )
                {
                    ## if *.params exists, copy it over
                    my @params_file = `ls {spectrast,sequest,omssa,tandem}.params`;
                    foreach my $pf (@params_file){
                      chomp $pf;
                      if( ! -z $pf){
                        my $new_file_name = "$repository_path/$prefix" . "_$pf";
                        $cmd = "cp $pf $new_file_name";
                        print "$cmd\n" if ($VERBOSE);
                        system $cmd;
                       }
                    }
                    ## if qualscore file exists, copy it over
                    if (-e "qualscore_results")
                    {
                        my $new_file_name = "$repository_path/$prefix" . "_qualscore_results";
                        $cmd = "cp qualscore_results $new_file_name";
                        print "$cmd\n" if ($VERBOSE);
                        system $cmd;
                    }
                }
            }
        }

        ####  return the absolute path of the versioned gzipped archive file  ####
        $versioned_compressed_archive_file_path = 
            "$repository_path/$versioned_compressed_archive_filename";

    }

    ## return to former directory
    chdir $progwd;

    return $versioned_compressed_archive_file_path;
}
### 
sub Get_OriginalSearchDir {

   my  %args = @_;
   my  $data_dir =  $args{data_dir};
	 my $iprophetfile = `ls $data_dir/interact*{ipro,combine}*.xml | grep -v prot | grep -v filter`;
	 chomp $iprophetfile;
	 my (@inputfiles, @all_search_dirs);
	if( -e $iprophetfile ){
		@inputfiles = `grep -m1 -A50 '<analysis_summary analysis="interprophet"' $iprophetfile | grep  '<inputfile name="' `;
	}
	if(@inputfiles >=  2){
		foreach my $f(@inputfiles){
			chomp $f;
			$f =~ /<inputfile name="(.*\/)interact.*/;
      my $search_dir = $1;
			if($search_dir =~ /^\.\.\/(.*)/){
				push @all_search_dirs, "$data_dir/../$1";
			}else{
				push @all_search_dirs, "$search_dir";
			}
		}
  }
  return   @all_search_dirs;
}


#######################################################################
# get_versioned_compressed_archive_filename --  given sample_accession and file_suffix
#    returns versioned name of compressed file archive 
# @param $sample_accession 
# @param $file_suffix (for example: mzXML)
# @return formatted versioned name for the archive file 
# (for example: PAe0000001_mzXML_200612060133.tar.gz)
#######################################################################
sub get_versioned_compressed_archive_filename
{
    my %args = @_;

    my $sample_accession = $args{sample_accession} || 
        die "need sample_accession ($!)";

    my $file_suffix = $args{file_suffix} || die "need file suffix ($!)";


    my $file = get_versioned_archive_filename(
        sample_accession => $sample_accession,
        file_suffix => $file_suffix,
    );


    $file = $file.".gz";

    return $file;

}


#######################################################################
# get_versioned_archive_filename --  given sample_accession and file_suffix,
#    returns a versioned name of file archive
# @param $sample_accession 
# @param $file_suffix (for example: mzXML)
# @return versioned name of the file archive 
#  (e.g. PAe0000001_mzXML_200612060133.tar)
#######################################################################
sub get_versioned_archive_filename
{
    my %args = @_;

    my $sample_accession = $args{sample_accession} || 
        die "need sample_accession ($!)";

    my $file_suffix = $args{file_suffix} || die "need file suffix ($!)";

    ## special treatement for the dta tars
    if ($file_suffix eq "dta.tar")
    {
        $file_suffix = "dtapack";
    }

    my $timestamp = `date $timestamp_pattern`;

    chomp($timestamp);

    my $file = $sample_accession . "_" . $file_suffix . "_" . $timestamp . ".tar";

    return $file;

}


#######################################################################
# updateDatabaseSpectrumProperties - updates database properties with
#  info in the properties file
# @param properties_hash_ref - reference to properties hash
#######################################################################
sub updateDatabaseSpectrumProperties
{
    my %args = @_;

    my $properties_hash_ref = $args{properties_hash_ref} ||
        die "need properties_hash_ref ($!)";

    my %properties_hash;

    ## one last check that properties exist before updating:
    if ( ( exists $properties_hash{mzXML_schema} ) &&
    (exists $properties_hash{conversion_software_name} ) &&
    (exists $properties_hash{conversion_software_version} ))
    {
        ## UPDATE spectra_description_set
        my %rowdata = (   ##   peptide_instance    table attributes
            mzXML_schema => $properties_hash{mzXML_schema},
            conversion_software_name => $properties_hash{conversion_software_name},
            conversion_software_version => $properties_hash{conversion_software_version},
        );

        my $success = $sbeams->updateOrInsertRow(
            update=>1,
            table_name=>$TBAT_SPECTRA_DESCRIPTION_SET,
            rowdata_ref=>\%rowdata,
            PK => 'spectra_description_set_id',
            PK_value => $properties_hash{spectra_description_set_id},
            verbose=>$VERBOSE,
            testonly=>$TEST,
        );

    }
}



#######################################################################
# upload_orig_data  -- get original data URL from public repository, 
#  or if doesn't exist, packs up files and moves them there, and then
#  returns url
# @param sample_id -
# @param sample_accession -
# @param spectra_data_dir -
# @param orig_data_type -
# @return URL to the archive data file
#######################################################################
sub upload_orig_data
{
    my %args =@_;

    my $sample_id = $args{sample_id} or die "need sample_id";

    my $sample_accession = $args{sample_accession} or die
        "need sample_accession";

    my $data_dir = $args{spectra_data_dir} or die
        "need spectra_data_dir";

    my $orig_data_type = $args{orig_data_type} or die
        "orig_data_type";

    ## does an archive file already exist in the repository?
    my $filelist = "tt.txt";
    my $pat = "*$sample_accession*$orig_data_type*";
    my $cmd = "find $repository_path/ -maxdepth 1 -name \'$pat\' -print > $filelist";
    print "$cmd\n" if ($VERBOSE);
    system $cmd;

    my $versioned_compressed_archive_file_path;

    if (-s $filelist)
    { ## [case: file list is not empty]
        $versioned_compressed_archive_file_path = 
           getLatestFileName( fileWithFileNames => $filelist ); 

        print "Found archive file: $versioned_compressed_archive_file_path\n"
            if ($VERBOSE);
    }

    if (-z $filelist)
    {   ## [case: file list is empty]

        ## get a local (relative) filename to use for the .tar file:
        my $versioned_compressed_archive_filename =
            get_versioned_compressed_archive_filename(
            sample_accession => $sample_accession,
            file_suffix => $orig_data_type,
        );

        ## get archive filename from $versioned_compressed_archive_filename
        my $versioned_archive_filename = $versioned_compressed_archive_filename;
        $versioned_archive_filename =~ s/\.gz//;

        ####  return the absolute path of the versioned gzipped archive file  ####
        $versioned_compressed_archive_file_path =
        "$repository_path/$versioned_compressed_archive_filename";

        unless (-e $versioned_compressed_archive_file_path)
        {
            ## [case: no file exists yet in repository]
        
            ## create gzipped archive
            ## AND update the database information

            ## get pwd, chdir to orig_data_dir, tar up files, gzip 'em, move 'em
            my $progwd = `pwd`;

            chdir $data_dir || die "cannot chdir to $data_dir ($!)";
            print "chdir $data_dir\n" if ($VERBOSE);

            #### make a file containing files with pattern: ####
            $filelist = "tt.txt";
            my $cmd = "rm -f $filelist";
            print "$cmd\n" if ($VERBOSE);
            system $cmd;
            my $pat = "*$orig_data_type";
            my $maxdepth = 1;
            if($pat =~ /raw/i){
             $maxdepth = 2;
            }
            $pat = "*_dta.tar" if ($orig_data_type eq "dtapack");
            print "$pat\n";

            $cmd = "find . -maxdepth 2 -name \'$pat\' -print  > $filelist";
            print "$cmd\n" if ($VERBOSE);
            system $cmd;

            ## if filelist is empty, report error message, and set final file to null: 
            ## this shouldn't happen though, as only reach this point with a defined
            ## orig data type
            if (-z $filelist)
            {
                error_message ( 
                    message => "could not find $orig_data_type files in $data_dir",
                );

                $versioned_compressed_archive_filename = "";

            } else
            {
                #my $tar_file_name = $versioned_archive_filename;

                ## make tar file
                my $cmd = "tar -v -h -czf $repository_path/$versioned_compressed_archive_filename --files-from=$filelist";
                print "$cmd\n" if ($VERBOSE);
                system $cmd;
    
                ## compress the tar file:
                #my $cmd = "gzip $repository_path/$sample_accession/$tar_file_name";
                #print "$cmd\n" if ($VERBOSE);
                #system $cmd;

                ####  move them to $repository_path/  ####
                #$cmd = "mv $versioned_compressed_archive_filename $versioned_compressed_archive_file_path";
                #print "$cmd\n" if ($VERBOSE);
                #system $cmd;

            }

            ## return to former directory
            chdir $progwd;
            print "chdir $progwd\n" if ($VERBOSE);

            print "versioned_compressed_archive_file_path: $versioned_compressed_archive_file_path\n"
                if ($VERBOSE);
        } 
    }
}


#######################################################################
# upload_sb_files - looks for file in public archive, and
# if not there, generates it and puts it there.
# (this is written to handle sequest.params and qualscore_results)
# @param file_name - the public archive file name to look for
# @param sb_file_name - the file name in the search batch directory
# @param search_results_dir
# @return URL for gzipped file of sequest.params file
#######################################################################
sub upload_sb_files
{
    my %args =@_;

    my $file_name = $args{file_name} or die "need file_name";

    my $sb_file_name = $args{sb_file_name} or die "need sb_file_name";

    my $data_dir = $args{search_results_dir} or die
        "need search_results_dir";

  
    my $prefix = $file_name;
    $prefix =~ s/_search.params//;     
    ## does a search_batch for this atlas_search_batch_id already exist in
    ## the archive?  if not, make one:
    my $filelist = "tt.txt";
    my $pat = "$file_name*gz";
    my $cmd = "find $repository_path/ -maxdepth 1 -name \'$pat\' -print > $filelist";
    print "$cmd\n" if ($VERBOSE);
    system $cmd;
    my $file_path;
    #if( -e "$repository_path/$prefix"."_sequest.params" and ! -e "$data_dir/sequest.params"){
    #  `cp "$repository_path/$prefix""_sequest.params" "$data_dir/sequest.params"` ;
    #   print "cp $repository_path/$prefix _sequest.params $data_dir/sequest.params\n";
    #}
    #if( -e "$repository_path/$prefix"."_tandem.params" and ! -e "$data_dir/tandem.params"){
    #  `cp "$repository_path/$prefix""_tandem.params" "$data_dir/tandem.params"` ;
    #   print "cp $repository_path/$prefix _tandem.params $data_dir/tandem.params\n";
    #}

    #if( -e "$repository_path/$prefix"."_spectrast.params" and ! -e "$data_dir/spectrast.params"){
    #  `cp "$repository_path/$prefix""_spectrast.params" "$data_dir/spectrast.params"` ;
    #   print "cp $repository_path/$prefix _spectrast.params $data_dir/spectrast.params\n";
    #}

    if (-s $filelist)
    { ## [case: file list is not empty]
        $file_path = "$repository_path/$file_name.tar.gz";

        print "Found archive file: $file_path\n" if ($VERBOSE);
    }

    ## if filelist is empty
    if (-z $filelist)
    {
        my $file_pattern = $sb_file_name;
        my %search_database;
        ## get pwd, chdir to search_batch_dir, gzip file and move it to public archive
        my $progwd = `pwd`;
        chdir $data_dir || die "cannot chdir to $data_dir ($!)";
        print "chdir $data_dir\n" if ($VERBOSE);

        #### make a file containing files with pattern: ####
        my $filelist = "tt.txt";
        my $cmd = "rm -f $filelist";
        print "$cmd\n" if ($VERBOSE);
        system $cmd;
        my $pat = '';
        if($sb_file_name =~ /params/){
          $pat = "*.$sb_file_name";
        }else{
          $pat = $sb_file_name;
        }
        my ($db,$search_type)  = getSearchDatabaseAndSearchType(data_dir => $data_dir);
                          
        if($db){
          $search_database{$db} = $search_type;
        }
        $cmd = "find . -maxdepth 1 -name \'$pat\'  -not -empty -print |grep -v '.*\..*\..*' | grep -v 'xinteract' > $filelist";
        print "$cmd\n" if ($VERBOSE);
        system $cmd;
        if( -z $filelist && $sb_file_name =~ /params/ ){
          my @all_search_dirs = Get_OriginalSearchDir(data_dir=> $data_dir);
          foreach my $dir (@all_search_dirs){
            print "copy  $dir/*.params to $data_dir\n" if ($VERBOSE);
            `cp $dir/{tandem,spectrast,sequest,omssa}.params  $data_dir`;
            ($db, $search_type) = getSearchDatabaseAndSearchType(data_dir => "$dir/");
            if($db ne ''){
               print "found database $db \n"  if ($VERBOSE);
               $search_database{$db} = $search_type;
            }else{
              print "WARNNING: no search database found for $dir/\n";
            }

          }
          `rm $filelist`;
          print "$cmd\n" if ($VERBOSE);
          system $cmd; 
        }

        ## if filelist is not empty
        unless (-z $filelist)
        {
            my $cmd = "tar -v -h -czf $file_name.tar.gz --files-from=$filelist";
            print "$cmd\n" if ($VERBOSE);
            system $cmd;
            ## move it to $repository_path/
            $cmd = "mv $file_name.tar.gz $repository_path/";
            print "$cmd\n" if ($VERBOSE);
            system $cmd;
            ## copy the file to repository name and compress it:
            if($sb_file_name =~ /params/){
              my @params_files = `cat $filelist`;
              foreach (@params_files){
                chomp;
                s/\.\///;
                $cmd = "cp $_ '$repository_path/$prefix''_$_'";
                print "$cmd\n" if($VERBOSE);
                system $cmd;
              }
            }else{
              $cmd = "cp $sb_file_name $repository_path/$file_name";
              print "$cmd\n" if ($VERBOSE);
              system $cmd;
            }

            $file_path = "$repository_path/$file_name.tar.gz";
            
           ### copy search database
           foreach my $db (keys %search_database){
             my $name = $db;
             $name =~ s/.*\/(.*)/$1/;
             if( -e $db ){
               if( ! -e "$repository_path/../../SearchDatabase/$name"){
                 `cp $db $repository_path/../../SearchDatabase/`;
               }
               my $dbname;
               if($search_database{$db} eq ''){
                  $dbname = "$repository_path/$prefix"."_searchdatabase.fasta";
               }else{
                 if($name =~ /splib/){
                   $dbname = "$repository_path/$prefix"."_searchdatabase_$search_database{$db}.splib";
                 }else{
                   $dbname = "$repository_path/$prefix"."_searchdatabase_$search_database{$db}.fasta";
                 }
               }
               `ln -s "../../SearchDatabase/$name" "$dbname"`;
              }else{
                print "WARNNING: $db not found\n";
              }
            } 
        }
    }
}

sub getSearchDatabaseAndSearchType {
  my %args  = @_;
  my $data_dir = $args{data_dir};
  my ($search_type, $db);
  if( -e "$data_dir/sequest.params" ) {
     $search_type = "sequest";
      $db = `grep database_name sequest.params | sed 's/.*=//g' `;
  }elsif( -e "$data_dir/spectrast.params" ){
    $search_type = "spectrast";
    $db = `grep '^libraryFile' spectrast.params | sed 's/.*=//g'`; 
  }else{
    if( -e "$data_dir/tandem.params" ) {
      $search_type = "tandem";
    }
    $db = `ls $data_dir/*.xml | grep -v inter | tail -1 | xargs grep -m1 'search_database' | cut -f2 -d'"'`;
  }
  $db =~ s/\s+//g;
  if($db && $db =~ /^\/dbase/){
    $db = "/regis/$db";
  }
  if($db =~ /fgcz_7227_2005010.fasta/){
     $db = '/regis/dbase/users/sbeams/fly_fgcz_7227_20050105.fasta';
  }
  if($db =~ /p225_db7_20070808_decoy_wormpep170/){
    $db ='/regis/sbeams/archive/sschrimp/Celegans/db/decoy_wormpep170.fa';
  }
  return ($db, $search_type);
}


#######################################################################
# upload_search_result - get repository URL for gzipped tar file
# of search results, check properties of database with
# timestamp properties file and pack up new files if the archive
# doesn't already exist to create the archive file;  ALSO, need to
# pack up the sequest.params file as a seperate file for each
# search result
# @param TPP_version
# @param atlas_search_batch_id
# @param sample_accession
# @param search_results_dir
# @return URL for gzipped tar file of search results
#######################################################################
sub upload_search_result
{
    my %args =@_;

    ## search results file name will be:
    ## PAe0000001_Search_Results_<atlas_search_batch_id>_<timestamp>.properties

    my $sample_accession = $args{sample_accession} or die
        "need sample_accession";

    my $data_dir = $args{search_results_dir} or die
        "need search_results_dir";

    my $TPP_version = $args{TPP_version}; ## some pepXML files don't contain TPP version

    my $atlas_search_batch_id = $args{atlas_search_batch_id} or
        die "need atlas_search_batch_id";

    my $suffix = "Search_Results_" . $atlas_search_batch_id;

    ## does a search_batch for this atlas_search_batch_id already exist in
    ## the archive?  if not, make one:
    my $filelist = "tt.txt";
    my $pat = "$sample_accession*$suffix*gz";
    my $cmd = "find $repository_path -maxdepth 1 -name \'$pat\' -print > $filelist";
    print "$cmd\n" if ($VERBOSE);
    system $cmd;
    my $file_path;

    if (-s $filelist)
    { ## [case: file list is not empty]
        $file_path = getLatestFileName( fileWithFileNames => $filelist ); 

        print "Found archive file: $file_path\n" if ($VERBOSE);
    }

    ## if filelist is empty
    if (-z $filelist)
    {
        my $file_pattern = "*.xml *.tgz *.params *ASAP*";

        my $prefix = $sample_accession . "_" . $atlas_search_batch_id;

        $file_path = makeNewArchiveAndProperties(
            sample_accession => $sample_accession,
            data_dir => $data_dir,
            file_suffix => $suffix,
            file_pattern => $file_pattern,
            prefix => $prefix
        );

    }
}


#######################################################################
# upload_protein_prophet_files - get repository URL for gzipped tar file
# of search results, check properties of database with
# timestamp properties file and pack up new files if the archive
# doesn't already exist to create the archive file;  ALSO, need to
# pack up the sequest.params file as a seperate file for each
# search result
# @param TPP_version
# @param atlas_search_batch_id
# @param sample_accession
# @param search_results_dir
# @return URL for gzipped tar file of search results
#######################################################################
sub upload_protein_prophet_files
{
    my %args =@_;

    ## protein_prophet file name will be:
    ## PAe0000001_prot_<atlas_search_batch_id>_<timestamp>.properties

    my $sample_accession = $args{sample_accession} or die
        "need sample_accession";

    my $data_dir = $args{search_results_dir} or die
        "need spectra_data_dir";

    my $TPP_version = $args{TPP_version};

    my $atlas_search_batch_id = $args{atlas_search_batch_id} or
        die "need atlas_search_batch_id";

    my $suffix = "prot_" . $atlas_search_batch_id;

    ## does a protein prophet archive for this atlas_search_batch_id already exist in
    ## the archive?  if not, make one:
    my $filelist = "tt.txt";
    my $pat = "$sample_accession*$suffix*gz";
    my $cmd = "find $repository_path -maxdepth 1 -name \'$pat\' -print > $filelist";
    print "$cmd\n" if ($VERBOSE);
    system $cmd;

    my $file_path;

    if (-s $filelist)
    { ## [case: file list is not empty]
        $file_path = getLatestFileName( fileWithFileNames => $filelist );
        print "Found archive file: $file_path\n" if ($VERBOSE);
    }

    ## if filelist is empty
    if (-z $filelist)
    {
        my $file_pattern = "inter*prot.x?? inter*prot.shtml";

        $file_path = makeNewArchiveAndProperties(
            sample_accession => $sample_accession,
            data_dir => $data_dir,
            file_suffix => $suffix,
            file_pattern => $file_pattern
        );

    }
}


#######################################################################
# write_readme
# @param sample_accession
# @param sample_tag
# @param organism
# @param description
# @param data_contributors
# @param array_of_file_urls_ref -- reference to array of file URLs
# @param array_of_pub_url_ref
# @param array_of_pub_cit_ref
# @param array_of_pubmed_id_ref
# @param array_of_pubmed_ids_ref 
# @return readme_url
#######################################################################
sub write_readme
{
    my %args = @_;

    my $sample_accession = $args{sample_accession} or die
        "need sample_accession";

    my $sample_tag = $args{sample_tag} or die "need sample_tag";

    my $organism = $args{organism} or die "need organism";

    my $description = $args{description} or die "need description";

    my $data_contributors; 
    if ($TEST)
    {
        $data_contributors = $args{data_contributors}; ## dev database isn't annotated
    } else
    {
       $data_contributors = $args{data_contributors} or die "need data_contributors";
    }

    my $array_of_pub_url_ref = $args{array_of_pub_url_ref};
    my $array_of_pub_cit_ref = $args{array_of_pub_cit_ref};
    my $array_of_pubmed_ids_ref = $args{array_of_pubmed_ids_ref};
    my @array_of_pub_urls;
    my @array_of_pub_cits;
    my @array_of_pubmed_ids;
    if ($array_of_pub_url_ref)
    {
        @array_of_pub_urls = @{$array_of_pub_url_ref};
        @array_of_pub_cits = @{$array_of_pub_cit_ref};
        @array_of_pubmed_ids = @{$array_of_pubmed_ids_ref};
    }


    my $outfile = "$repository_path/$sample_accession" . "_README";

    my $file_name = $sample_accession . "_README";

    ## write to README file
    open(OUTFILE,">$outfile") or die "cannot open $outfile for writing";

    ## item 1
    my $str = "#1. Data Contributors:\n" .  "    $data_contributors\n";
    print OUTFILE "$str\n";

    ## item 2
    $str = "#2. URL link to a www resource\n";
    print OUTFILE "$str\n";

    ## item 3
    $str = "#3. Literature references and PubMed identifications:\n";
    for (my $i = 0; $i <= $#array_of_pub_urls; $i++)
    {
        $str = $str."    $array_of_pub_cits[$i]\n    PubMed ID: $array_of_pubmed_ids[$i]\n";
    }
    print OUTFILE "$str\n";

    ## item 4
    $str = sprintf("%-27s\n    %-68s\n",
        "#4. Experiment Description:",  $description);
    print OUTFILE "$str\n";

    ## item 5
    $str = "#5. Treatment Description:\n";
    print OUTFILE "$str\n";

    ## item 6
    $str = "#6. Instrument Type:\n";
    print OUTFILE "$str\n";

    ## item 7
    $str = "#7. Organism NCBI_TaxID (9606 for human):\n";
    print OUTFILE "$str\n";

    ## item 8
    $str = "#8. Bio source description (eVOC) anatomical site:\n";
    print OUTFILE "$str\n";

    ## item 9
    $str = "#9. Pathology (eVOC):\n";
    print OUTFILE "$str\n";

    ## item 10
    $str = "#10. Cell-type:\n";
    print OUTFILE "$str\n\n";

    ## File sizes:
    print OUTFILE "$str";
    close(OUTFILE) or die "cannot close $outfile ($!)";

}

#######################################################################
#  print_hash
#
# @param hash_ref to hash to print
#######################################################################
sub print_hash
{
    my %args = @_;

    my $hr = $args{hash_ref};

    my %h = %{$hr};

    foreach my $k (keys %h)
    {
        print "key: $k   value:$h{$k}\n";
    }
}


#######################################################################
# formatSampleIDs -- format test_samples string to be usable as an
#  IN clause in an SQL statement
#
# @param sample_ids
#######################################################################
sub formatSampleIDs
{
    my %args = @_;

    my $sample_ids = $args{sample_ids};

    $sample_ids =~ s/"//g; 

    $sample_ids =~ s/'//g; 

    $sample_ids =~ s/\s+//g;

    my @t = split(",",$sample_ids);

    $sample_ids = join("','", @t);

    $sample_ids = "'" . $sample_ids . "'";

    return $sample_ids;
}
sub error_message
{
	    my %args = @_;

			my $message = $args{message} || die "need message ($!)";
      die "$message\n";
}
