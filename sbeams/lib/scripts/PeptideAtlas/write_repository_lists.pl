#!/usr/local/bin/perl 

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
#
#    Zhi Sun @ 20170802
#    use BDbag and change directroy structure
#
#######################################################################

use strict;
use Getopt::Long;
use FindBin;
use File::stat;
use POSIX;
use IO::File;
use LWP::UserAgent;
use File::Copy;
use File::Basename;
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
  --atlas_build_id 
e.g.:  ./$PROG_NAME  --test_sample 2700 --verbose 1 
			 ./$PROG_NAME  --test_project_ids "965" --verbose 1

EOU

## get arguments:
GetOptions(\%OPTIONS, "test", "verbose:s", "test_samples:s","atlas_build_id:i",
           "test_project_ids:s","samples:s", "project_ids:s", "raw_private:s","run");


## check for required arguments:
unless ( $OPTIONS{"test"} || 
         $OPTIONS{"test_samples"} || 
         $OPTIONS{"test_project_ids"} || 
         $OPTIONS{"run"} ||
         $OPTIONS{"project_ids"} || 
         $OPTIONS{"samples"} || 
         $OPTIONS{"atlas_build_id"}){
    print "$USAGE";
    exit;
}

## check format of test_samples if it's used
if ($OPTIONS{"test_samples"} || $OPTIONS{"samples"})
{
    my @t = split(",", ($OPTIONS{"test_samples"}, $OPTIONS{"samples"}));
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
$repository_path = "/proteomics/peptideatlas2/PADR/";
$repository_path_cp = $repository_path; 

our $notpublic_buffer = '';


if ($TEST)
{
	 $repository_path = "/proteomics/peptideatlas2/PADR/TEST"; 
   $repository_path_cp = $repository_path;
}

if( $TEST && $OPTIONS{"run"}){

	$repository_path = "/proteomics/peptideatlas2/PADR/TEST"; 
	$repository_path_cp = $repository_path;

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

    ## check that mandatory sample annotation exists
    unless ($TEST)
    {
        check_samples();
    }
    write_public_file();
    #write_private_file();
} ## end main


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
        if (@$row ==1) 
        {
            #print "[ERROR] $st is missing data_contributors\n";
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
# write_public_file 
#    While at it, sees if files exist in public archive area, and if
#    so, sees if they are the most current known.  If the files are not
#    the most current, copies them to the public archive area and gz it.
#
#######################################################################
sub write_public_file
{
    my $sql;
    my %raw_private = ();
    if ($OPTIONS{raw_private}){
			my $sample_ids = $OPTIONS{raw_private};
			$sample_ids =~ s/"//g;
			$sample_ids =~ s/'//g;
			$sample_ids =~ s/\s+//g;
			my @t = split(",",$sample_ids);
			%raw_private = map { $_ => 1 } @t;
    } 
     
    if ($OPTIONS{"test_samples"} || $OPTIONS{"test_project_ids"}){
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
    } elsif ($OPTIONS{"test"}  and 
            ( ! $OPTIONS{"test_samples"} and !  $OPTIONS{"test_project_ids"}) and 
            ! $OPTIONS{"run"}){   ## Use 2 records for TEST
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

    } else{
        my $sample_id_clause='';
        if($OPTIONS{"samples"}){
          $sample_id_clause = "AND S.sample_id IN (" .  formatSampleIDs(sample_ids => $OPTIONS{"samples"});
          $sample_id_clause .= ")"; 
        }
        if( $OPTIONS{"project_ids"}){
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
        if ($OPTIONS{"atlas_build_id"}){
          $sample_id_clause = qq~
            AND S.sample_id in (
							SELECT SAMPLE_ID 
							FROM $TBAT_ATLAS_BUILD_SAMPLE 
							WHERE ATLAS_BUILD_ID = $OPTIONS{"atlas_build_id"} 
            )
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
        --AND S.sample_id != '198' AND S.sample_id != '292'
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
#        my $sql2 = qq~
#        SELECT S.sample_description, S.data_contributors
#        FROM $TBAT_SAMPLE S
#        WHERE S.sample_id = '$sample_id'
#        AND S.record_status != 'D'
#        ~;
        my $sql2 = qq~
					SELECT S.SAMPLE_DESCRIPTION, 
                 S.DATA_CONTRIBUTORS, 
                 C.FIRST_NAME, C.LAST_NAME, 
                 PB.AUTHOR_LIST ,
                 S.REPOSITORY_IDENTIFIERS
					FROM $TB_PROJECT P JOIN  PROTEOMICS.DBO.PROTEOMICS_EXPERIMENT E ON (P.PROJECT_ID = E.PROJECT_ID)
					JOIN $TBPR_SEARCH_BATCH SB ON ( E.EXPERIMENT_ID = SB.EXPERIMENT_ID)
					JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON (SB.SEARCH_BATCH_ID = ASB.PROTEOMICS_SEARCH_BATCH_ID)
					JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON (ASB.SAMPLE_ID = ABSB.SAMPLE_ID)
					JOIN $TBAT_SAMPLE S ON (ABSB.SAMPLE_ID = S.SAMPLE_ID)
					LEFT JOIN $TBAT_SAMPLE_PUBLICATION SP ON (S.SAMPLE_ID = SP.SAMPLE_ID)
					LEFT JOIN $TBAT_PUBLICATION PB ON (PB.PUBLICATION_ID = SP.PUBLICATION_ID)
					LEFT JOIN $TB_CONTACT C ON (C.CONTACT_ID = P.PI_CONTACT_ID)
					WHERE S.sample_id = $sample_id
          AND S.record_status != 'D'
        ~;

        next if($organism eq 'Chimpanzee' );

        if($organism eq 'Honeybee'){
          $organism = 'HoneyBee';
        }

        print "$sample_tag $sample_accession $sample_id\n";


        my @rows2 = $sbeams->selectSeveralColumns($sql2) or 
            die "Couldn't find sample records using $sql2";

        my ($sample_description, $data_contributors,$repository_identifiers);

        ## store query results in $sample_info
        #foreach my $row2 (@rows2) 
        if (@rows2)
        {
            my ($d,$c1,$c21,$c22,$c3,$ids) =@{$rows2[0]}; 
            ## replace dos end of line markers (\r) and (\n) with space
            $sample_description = $d;
            $sample_description =~ s/\r/ /g;
            $sample_description =~ s/\n/ /g;
            if ($c1){
              $data_contributors = $c1;
            }elsif($c21 ){
              $data_contributors = "$c21 $c22";
            }else{
              $data_contributors = "$c3";
            }
            $data_contributors =~ s/\r/ /g;
            $data_contributors =~ s/\n/ /g;
            $repository_identifiers = $ids;
        }
 
        ######### handle the remaining resources  ####
        #### resource mzXML_format
        #### resource RAW_format
        #### resource Search_Results
        #### resource ProteinProphet_file
        #### metadata 

        my $spectra_data_dir = get_spectra_location( sample_id => $sample_id);
        if($raw_private{$sample_id}){ goto TPP;}

        ## get orig data type by searching data dir for known suffixes
        my $origDataType = get_orig_data_type( data_dir => "$spectra_data_dir");
 
        print "\tspectra_data_dir: $spectra_data_dir\n\torigDataType: $origDataType\n";
        $repository_path = "$repository_path_cp/$sample_accession";
        mkdir $repository_path if ( ! -d $repository_path);
        if ($origDataType)
        {
            ## get original data url, if don't see it in the public repository, pack up files etc, 
            ## For some of the older HUPO datasets, the original spectra aren't available,
            ## so we only have the dtas, they will have empty raw directory and dtas in mzML directory.
            upload_orig_data(  
                sample_id => $sample_id,
                sample_accession => $sample_accession, 
                spectra_data_dir => $spectra_data_dir,
                orig_data_type => $origDataType,
            );
        }
        TPP:

        ## get mzXML url, check properties of database with timestamp properties file ( if lagging,
        ## pack up new files etc, or if the archive doesn't already exist create the archive file, etc)
				upload_mzML(  
						sample_id => $sample_id,
						sample_accession => $sample_accession, 
						spectra_data_dir => "$spectra_data_dir",
				);

        ###########  check latest search batches for this sample #############
        my $atlas_build_clause='';
        if ($OPTIONS{"atlas_build_id"}){
          $atlas_build_clause = "AND ABSB.atlas_build_id = $OPTIONS{atlas_build_id}";
        }
        $sql2 = qq~
            --SELECT distinct ASB.TPP_version, ASB.atlas_search_batch_id, ASB.data_location,
            SELECT distinct ASB.atlas_search_batch_id, ASB.data_location, ASB.search_batch_subdir
            FROM $TBAT_ATLAS_SEARCH_BATCH ASB
            JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
            ON (ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id)
            JOIN $TBAT_SAMPLE S ON (S.sample_id = ABSB.sample_id)
            WHERE S.sample_id = '$sample_id'
            $atlas_build_clause
            AND S.record_status != 'D'
            ORDER BY ASB.ATLAS_SEARCH_BATCH_ID DESC
        ~;

        @rows2 = $sbeams->selectSeveralColumns($sql2) or 
        die "Couldn't find ATLAS_SEARCH_BATCH records for sample $sample_id";

				my ($atals_build_search_batch_id,$data_location,$search_batch_subdir) = @{$rows2[0]};
				
				$data_location = $data_location . "/" . $search_batch_subdir;

				## if path has /data3/sbeams/archive/, remove that
				$data_location =~ s/^(.*sbeams\/archive\/)(.+)$/$2/gi;

				## if path starts with a /, remove that
				$data_location =~ s/^(\/)(.+)$/$2/gi;

				## make absolute path
				$data_location = "$sbeams_data_path/$data_location";

				## make sure it exists:
				die "$data_location does not exist" unless ( -d $data_location );

				upload_search_result (
						sample_accession => $sample_accession,
						search_results_dir => $data_location,
				);

				## metadata
				upload_metadata(
						sample_accession => $sample_accession,
						search_results_dir => $data_location,
				);

        ####  handle publication citations  #####
        my $sql3 = qq~
            SELECT DISTINCT P.publication_name, P.uri, P.pubmed_ID
            FROM $TBAT_PUBLICATION P
            JOIN $TBAT_SAMPLE_PUBLICATION SP ON (P.publication_id = SP.publication_id)
            JOIN $TBAT_SAMPLE S ON (S.sample_id = SP.sample_id)
            WHERE S.sample_id = '$sample_id'
            AND SP.record_status != 'D'
        ~;

        my @rows3 = $sbeams->selectSeveralColumns($sql3);
        my (@pubmed_id_array_for_README, @pub_cit_array_for_README, @pub_url_array_for_README);
        foreach my $row3 (@rows3) {
            my ($pub_name, $pub_url, $pubmed_id) = @{$row3};
            push(@pubmed_id_array_for_README, $pubmed_id);
            push(@pub_cit_array_for_README, $pub_name);
            push(@pub_url_array_for_README, $pub_url);
        }
        write_readme(
            sample_accession => $sample_accession,
            origDataType => $origDataType,
            repository_identifiers => $repository_identifiers,
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
sub upload_mzML
{
    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id";

    my $sample_accession = $args{sample_accession} or die "need sample_accession";

    my $spectra_data_dir = $args{spectra_data_dir} or die "need spectra_data_dir";

    ## Get hash of spectra info with keys: conversion_software_name, conversion_software_version,
    ## and mzXML_schema
    #my %spectra_properties = get_spectra_properties_info_from_db( sample_id => $sample_id);

    ## The mzML collection contains the .mzML files after conversion. If raw files and mzML 
    #  files are not available, then .mzXML files are acceptable. If none of the above is available, 
    #  then .mgf files are acceptable. If .mzML files were converted from .mzXML, .mgf, or similar, 
    #  those files may also go here in addition to the .mzML files.
    print "\tUploading mzML/mzXML/mgf/dat files\n";
 
		mkdir "$repository_path/files" if ( ! -d "$repository_path/files" ); 
		mkdir "$repository_path/files/mzML" if ( ! -d "$repository_path/files/mzML" );
 
    foreach my $file_type (qw(mzML mzML.gz mzXML mzXML.gz mgf dat)){
			my $pat = "*$file_type";
			#### make a file containing files with pattern: ####
			my @files = `find -L $spectra_data_dir -maxdepth 1 -name \'$pat\' -print`;
      next if (! @files);
			foreach my $file (@files){
				 chomp $file;
         copy_file (source_file=>"$file",
                    destination => "$repository_path/files/mzML",
                    gzip => 1);
			}
      return;
    }
    print "\tWARNING: no mzML/mzXML/mgf/dat file found\n";

}


#######################################################################
# get_orig_data_type -- given data_dir, gets orig data type
# @param data_dir - absolute path to data
# @return data_type (e.g. .RAW, .raw, or dtapack)
#######################################################################
sub get_orig_data_type
{
    my %args = @_;

    my $data_dir = $args{data_dir} || die "need data directory ($!)";
    my $orig_data_type="";

    ## check for RAW files:
    unless ($orig_data_type){
      foreach my $type (qw(RAW raw wiff wiff.scan WIFF WIFF.scan yep baf .d)){
        my @files = `find $data_dir/../ -maxdepth 2 -name \'*.$type*\'  -print`;
        if ( $#files > -1){
            $orig_data_type = "$type";
            return $orig_data_type;
        }
      }
      if ( ! $orig_data_type ){
        foreach my $type (qw(.d raw RAW)){ 
					my @dirs = `find $data_dir/../ -maxdepth 2 -type d -name \'*$type*\'  -print`;
					if ( $#dirs > -1){
							return $type 
					}
        }
      }
    }
    print "\tWARNING: cannot find raw data type\n";
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

    ## if $data_path has /data3/sbeams/archive/, remove that
    $data_path =~ s/^(.*sbeams\/archive\/)(.+)$/$2/gi;
        
    ## if $data_path starts with a /, remove that
    $data_path =~ s/^(\/)(.+)$/$2/gi;

    $data_path = "$sbeams_data_path/$data_path";

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

    print "\tUploading Raw files\n";

    my $pat = "*$orig_data_type";
    mkdir "$repository_path/files" if ( ! -d "$repository_path/files"); 
    mkdir "$repository_path/files/raw" if ( ! -d "$repository_path/files/raw") ; 

		#### make a file containing files with pattern: ####
		$pat = "*$orig_data_type";
		my @files = `find $data_dir/../ -maxdepth 2 -name \'$pat\' -print`;
    if ($orig_data_type =~ /wiff/i){
       push @files, `find $data_dir/../ -maxdepth 2 -name \'$pat.scan\' -print`;
    }
    foreach my $file (@files){
       chomp $file;
       my $is_directory = 0;
       if ( -d "$file"){
         $is_directory =1;
       }
       copy_file (source_file=>"$file",
                  destination => "$repository_path/files/raw",
                  gzip => 1,
                  is_directory => $is_directory);
            
    }
}
#######################################################################
#upload_metadata
#-	The metadata collection is intended for all sorts of metadata files 
#about the data itself and the analysis without any of the actual data. 
#At minimum, we should aim to have a search engine params file here, but 
#ideally much more such as a ProteomeXchange XML, and/or a PASS DESCRIPTION file, 
#and ideally eventually a .dataset knowledge. file, which would be a rich 
#collection of what is known about the dataset.
#######################################################################
sub upload_metadata{
    my %args =@_;
    my $sample_accession = $args{sample_accession} or die
        "need sample_accession";
    my $data_dir = $args{search_results_dir} or die
        "need search_results_dir";
    print "\tUploading meta data\n";
    my $meta_data_dir = "$repository_path_cp/$sample_accession/files/metadata";
    mkdir $meta_data_dir;
    ## get latest parameter files
    my @paramater_files = `find -L $data_dir/../ -maxdepth 2 -type f -name \'*.params\'  -print`;
    my %paramaters = ();
    foreach my $file (@paramater_files){
       chomp $file;
       my $type = basename($file);
       next if($type =~ /.*\..*\..*/);
       my $time_stamp = get_file_timestamp($file);
       if (not defined $paramaters{$type}){
         $paramaters{$type}{f} = $file;
         $paramaters{$type}{t} = $time_stamp;
       }else{
         if ($paramaters{$type}{t} < $time_stamp){
           $paramaters{$type}{f} = $file;
           $paramaters{$type}{t} = $time_stamp;
         }
       }
    }
    foreach my $type(keys %paramaters){
       copy_file (source_file=>$paramaters{$type}{f},
              destination =>$meta_data_dir,
              gzip => 0);
             
    }
    ## get other files
    ## for now it's just pxd.xml file

    opendir (DIR, "$data_dir/../");
    while(my $filename = readdir(DIR)){
      if ($filename =~ /PXD.*.xml/i){
				copy_file (
           source_file => "$data_dir/../$filename",
				   destination => $meta_data_dir,
				   gzip => 0);
       }
    }

}
sub get_file_timestamp {
  my $file = shift;
  my $timestamp = POSIX::strftime( "%Y%m%d", localtime((stat($file))[9]));
  return $timestamp;
}
#######################################################################
# upload_search_result 
#-	The search collection is one of two collections for which there may be several 
#instances per experiment. The format .search_Engine_Datestamp. should be used, 
#e.g. .search_20170802/Comet.. In general, there is no major mandate to save all 
#previous searches, especially when they are considered obsolete; but there may be 
#cases where more than one search with the same engine is worth keeping. It is 
#permissible to add one tag to the end of the name, e.g. .search_20170802/Comet_SemiTrypNarrow. 
#and search_20170710/Comet_TrypWide., in cases where different searches with the same engine 
#are worth differentiating. In general this collection should contain all the msrun.pep.xml 
#files as well as all interact* files (including iProphet and ProteinProphet output for 
#this search where available) as well as the FASTA files and/or splib files used 
#(ideally a hard link to a central version in PADR/common/fasta/ and PADR/common/specli

#-	The combined collection represents the combination with iProphet of several searches. 
#The usual format should be search_20170802/combined, although it is permissible to append 
#one more field if further differentiation is desired, e.g. .search_20170802/combined_all

#######################################################################

sub upload_search_result
{
    my %args =@_;

    my $sample_accession = $args{sample_accession} or die
        "need sample_accession";

    my $data_dir = $args{search_results_dir} or die
        "need search_results_dir";
    print "\tUploading search result\n";

    ## does a search_batch for this atlas_search_batch_id already exist in
    ## the archive?  if not, make one:
    ## check if this is combined result
    my $ipro_file = "$data_dir/interact-ipro.pep.xml";
    if ( ! -e $ipro_file){
      die "ERROR: cannot file $ipro_file\n";
    }
    my $time_stamp = get_pipeline_analysis_date ($ipro_file);
    my $repository_search_dir = "$repository_path/files/search_$time_stamp";
    mkdir "$repository_search_dir";


    open (IN, "<$ipro_file");
    #<inputfile name="../XTK_Hs_UP_CompleteProteome_varsplic_PAB/interact-prob.pep.xml"/>
    #<inputfile name="../SPC_20120530/interact-prob.pep.xml"/>
    my @inputfiles = ();
    while (my $line = <IN>){
      last if ($line =~ /<roc_error_data/);
      chomp $line;
      if ($line =~ /<inputfile name="([^"]+)".*/){
        my $file = $1;
        if ($file =~ /^\.\'/){
           $file = "$data_dir/$file";
        }
        push @inputfiles , $1;
      }
    }
    
    ## only one search
    my ($search_db, $search_engine,$search_splib);
    die "no input file found for $ipro_file\n" if (@inputfiles == 0 );

    if (@inputfiles == 1){
       my $search_loc = $inputfiles[0];
       if ($search_loc !~ /\//){
         $search_loc = '';
       }else{ 
         $search_loc =~ s/(.*)\/.*/$1/;
       }
       $search_loc = "$data_dir/$search_loc";
       ($search_db, $search_engine,$search_splib) = get_search_info ($search_loc);
       if ($search_engine =~/spectrast/i && $search_splib eq ''){
         print "WARNING: cannot find search_splib for $search_loc\n";
       }
       upload_search_dir_files (
          repository_dir => $repository_search_dir,
          search_engine => $search_engine,
          search_db     => $search_db,
          search_splib => $search_splib,
          search_results_dir => $search_loc,
       );
      upload_protein_prophet_files (
          repository_dir => "$repository_path/files/proteins",
          search_results_dir => "$repository_search_dir/$search_engine");
 
       return;           
    }   
    ## combined files
		mkdir "$repository_search_dir/combined";
	  copy_file (source_file=>"$data_dir/interact-ipro.pep.xml",
							destination => "$repository_search_dir/combined",
							gzip => 1);
    if ( -e "$data_dir/interact-ipro.prot.xml"){
       copy_file (source_file=>"$data_dir/interact-ipro.prot.xml",
              destination => "$repository_search_dir/combined",
              gzip => 1);
    }else{
       print "\tWARNING: no $data_dir/interact-ipro.prot.xml file\n";
    }

    foreach my $inputfile (@inputfiles){
       my $search_loc = $inputfile;
       $search_loc =~ s/(.*)\/.*/$1/;
       $search_loc = "$data_dir/$search_loc";
       ($search_db, $search_engine,$search_splib) = get_search_info ($search_loc);
       if ($search_engine =~/spectrast/i && $search_splib eq ''){
         die "ERROR: cannot find search_splib for $search_loc\n";
       }
       upload_search_dir_files (
          repository_dir => $repository_search_dir,
          search_engine => $search_engine,
          search_db     => $search_db,
          search_splib => $search_splib,
          search_results_dir => $search_loc,
       );
    }
    upload_protein_prophet_files (
          repository_dir => "$repository_path/files/proteins",
          search_results_dir => "$repository_search_dir/combined");

}
#######################################################################
sub get_pipeline_analysis_date{
  my $file = shift;
  open (IN, "<$file") or die "cannot open $file\n";
  while (my $line =<IN>){
    if ($line =~ /(<program_details.*time=|<msms_pipeline_analysis date=)"(\d{4})\-(\d{2})\-(\d{2})\w.*/){
      return "$2$3$4";
    }
  }
  die "ERROR: cannot find analysis time for $file\n";
}


#######################################################################
#upload_search_dir_files
#upload files in search directory
#######################################################################
sub upload_search_dir_files{
  my %args =@_;
  my $data_dir = $args{search_results_dir} or die
        "need search_results_dir";
  my $repository_dir = $args{repository_dir};
  my $search_engine = $args{search_engine};
  my $search_db     = $args{search_db};
  my $search_splib= $args{search_splib};
  opendir ( DIR, $data_dir) || die "Error in opening dir $data_dir\n";
  mkdir "$repository_dir/$search_engine";
  my $cmd;
  my @metadata = ();
  my $gzip = 1;
  while(my $filename = readdir(DIR)){
    #search result
    if ($filename =~ /\.xml/ && $filename !~ /inter/){
       copy_file (source_file=>"$data_dir/$filename",
                  destination => "$repository_dir/$search_engine/",
                  gzip => 1);
    }elsif ($filename =~ /params/ && $filename !~ /.*\..*\..*/){
       copy_file (source_file=>"$data_dir/$filename",
                  destination => "$repository_dir/$search_engine/",
                  gzip => 0);
    }
  }
  if ( -e "$data_dir/interact-prob.pep.xml"){
	  copy_file (source_file=>"$data_dir/interact-prob.pep.xml",
							destination => "$repository_dir/$search_engine/",
							gzip => 1);
  }else{
     print "\tERROR: don't have $data_dir/interact-prob.pep.xml\n";
  }
  if ( -e "$data_dir/interact-ipro.pep.xml"){
    copy_file (source_file=>"$data_dir/interact-ipro.pep.xml",
              destination => "$repository_dir/$search_engine/",
              gzip => 1);
  }
  if ( -e "$data_dir/interact-ipro.prot.xml"){
    copy_file (source_file=>"$data_dir/interact-ipro.prot.xml",
              destination => "$repository_dir/$search_engine/",
              gzip => 1);
  }

  my $search_db_basename = basename($search_db);
  if ( -e $search_db ){
	  copy_file (source_file=>"$search_db",
							destination => "$repository_path_cp/common/fasta",
							gzip => 0);
    if (! -e "$repository_dir/$search_engine/$search_db_basename"){
      $cmd = "ln $repository_path_cp/common/fasta/$search_db_basename $repository_dir/$search_engine/$search_db_basename"; 
      print "$cmd\n" if ($VERBOSE);
      system($cmd);
    }
  }else{ ## check if in the repository location already
     my $database = $search_db;
     if ( -e "$repository_path_cp/common/fasta/$search_db_basename"){
       if ( ! -e "$repository_dir/$search_engine/$search_db_basename" ){
				 $cmd = "ln $repository_path_cp/common/fasta/$search_db_basename $repository_dir/$search_engine/$search_db_basename";
				 print "$cmd\n" if ($VERBOSE);
				 system($cmd);
       }
     }else{
       print "\tWARNING: $search_db not found\n";
     }
  }
  if ($search_engine =~ /spectrast/i && $search_splib ne ''){
    if ( -e "$search_splib"){
			copy_file (source_file=>"$search_splib",
								destination => "$repository_path_cp/common/splib",
								gzip => 0);
			$search_splib = basename($search_splib);
			if ( ! -e "$repository_dir/$search_engine/$search_splib") {
				$cmd = "ln $repository_path_cp/common/splib/$search_splib $repository_dir/$search_engine/$search_splib";
				print "$cmd\n" if ($VERBOSE);
				system($cmd);
			}
    }else{
       $search_splib = "$repository_path_cp/common/splib/" . basename($search_splib);
       if ( -e "$search_splib" && ! -e "$repository_dir/$search_engine/$search_splib" ) {
          $cmd = "ln $search_splib $repository_dir/$search_engine/";
          print "$cmd\n" if ($VERBOSE);
          system($cmd);
      }else{
         print "\tWARNING: cannot find $search_splib file\n"
      }
    }
  } 

}
#######################################################################
sub copy_file {
  my %args = @_;
  my $source_file = $args{source_file} ;
  my $destination = $args{destination};
  my $destination_filename =  $args{destination_filename} || '';
  my $gzip = $args{gzip} || 0;
  my $is_directory = $args{is_directory} || 0;
  my $file_name = $source_file;
  $file_name = basename($file_name);
  if ($destination_filename){
    $file_name = $destination_filename;
  }

  if ( -e "$destination/$file_name" || -e "$destination/$file_name.gz"){
    return;
  }
  print "\tcopy $source_file $destination\n" if ($VERBOSE);

  my $cmd = "cp -aH $source_file $destination/$file_name";
	print "$cmd\n" if ($VERBOSE);
	system($cmd);
  $cmd = '';
  if ($gzip){
    if ($is_directory){
      if ( $file_name !~ /zip/){
        $cmd = "zip -r $destination/$file_name.zip $destination/$file_name";
        print "$cmd\n";
        print "$cmd\n" if ($VERBOSE);
        system($cmd);
 
        $cmd = "rm -rf $destination/$file_name";
        print "$cmd\n";
        print "$cmd\n" if ($VERBOSE);
        system($cmd);
      }
    }else{
      if ($file_name !~ /\.gz/){
      	$cmd = "gzip $destination/$file_name"; 
        print "$cmd\n" if ($VERBOSE);
        system($cmd);
      }
    }
  }

  return;
}
#######################################################################
#get_search_info
#get search_engine, search_db, search_splib
########################################################################
sub get_search_info{
  my $dir = shift;
  opendir ( DIR, $dir ) || die "Error in opening dir $dir\n";
  my ($search_engine,$search_db,$search_splib);
  while(my $filename = readdir(DIR)){
     if ($filename =~ /\.xml/ && $filename !~ /inter/){
       my $fh ;
       print "getting search info from $dir/$filename\n" if ($VERBOSE) ;
       if ($filename =~ /.gz$/){
         open ($fh, "zcat $dir/$filename|") or die "cannot open $filename in $dir\n";
       }else{
         open ($fh, "<$dir/$filename") or die "cannot open $filename in $dir\n";
       }
       while (my $line =<$fh>){
         if ($line =~ /(<msms_run_summary|<search_summary).*search_engine="([^"]+)".*/i){
           $search_engine = $2;
           if ($search_engine =~ /Tandem/i){
             if ($search_engine=~ /k-score/){
               $search_engine= "Tandemk";
             }else{
               $search_engine= "Tandem";
             }
           }elsif($search_engine =~ /comet/i){
              $search_engine= "Comet";
           }elsif($search_engine =~ /SpectraST/i){
              $search_engine= "SpectraST";
           }else{
              $search_engine =~ s/\s\+/_/g;
           }
        }elsif($line =~ /<search_database local_path="([^"]+)".*/){
          $search_db = $1;
        }elsif($line =~ /<parameter name="spectral_library" value="([^"]+)".*/){
          $search_splib = $1;
        }
      }
      if ( $search_db && $search_engine){
        return ($search_db, $search_engine,$search_splib);
      }else{
        die "cannot find search engine and search database $dir/$filename\n";
      }
    }
  } 
}

#######################################################################
# upload_protein_prophet_files 
#The proteins collection is ideally just the latest best protein result and relatively small. 
#######################################################################
sub upload_protein_prophet_files
{
    my %args =@_;

    my $data_dir = $args{search_results_dir} or die
        "need spectra_data_dir";
    my $repository_dir = $args{repository_dir} or die 
        "need repository_dir\n";
    mkdir $repository_dir if ( ! -d $repository_dir);
    my $cmd = '';
    use File::Compare;
    foreach my $file (qw (interact-ipro.prot.xml.gz)){
			if ( -e "$data_dir/$file") {
				if ( -e "$repository_dir/$file"){
					if (compare("$data_dir/$file", "$repository_dir/$file") != 0) {
            my $lastest_file = getLatestFile(("$data_dir/$file", "$repository_dir/$file")); 
            if ($lastest_file ne "$repository_dir/$file"){
					  	unlink "$repository_dir/$file";
						  $cmd = "ln $data_dir/$file $repository_dir/$file";
						  system($cmd);
            }
					}else{
             print "$data_dir/$file and  $repository_dir/$file are the same file\n" if ($VERBOSE);
          }
				}else{
          if( ! -e "$repository_dir/$file"){
            $cmd = "ln $data_dir/$file $repository_dir/$file";
            system($cmd);
          }
        }
			}

    }
    ## link database
    ## get protein reference database
    #<protein_summary_header reference_database="/regis/sbeams5/nobackup/builds_output/HumanPublic_201611/DATA_FILES/Homo_sapiens.fasta"
    open (IN, "zcat $data_dir/interact-ipro.prot.xml.gz|") or die "cannot open $data_dir/interact-ipro.prot.xml.gz\n";
    my $db = '';
    while (my $line = <IN>){
      if ($line =~ /.*reference_database="([^"]+)"\s+.*/){
        $db = $1;
        last;
      }
    }
    my $repository_db = $db;
    $repository_db =~ s/.*\///;
    ## if database from build output append build directory name
    if ($db =~ /.*builds_output\/(.*)\/DATA_FILES\/(.*)/){
       $repository_db = $1 . "_" .$2;
    }
	  copy_file (source_file=>$db,
					destination => "$repository_path_cp/common/fasta",
          destination_filename => $repository_db,
					gzip => 0 );

    if ( ! -e "$repository_dir/$repository_db"){
      $cmd = "ln $repository_path_cp/common/fasta/$repository_db $repository_dir/$repository_db";
      print "$cmd" if ($VERBOSE);
      system($cmd); 
    }
      
}
sub getLatestFile {
  my @files = shift;
  my $lastest_file = '';
  my $time_stamp =0;
  foreach my $file (@files){
    my $analysis_time = get_pipeline_analysis_date($file);
    if ($analysis_time >  $time_stamp){
      $time_stamp = $analysis_time;
      $lastest_file = $file;
    }
  }
  return $lastest_file;

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

    my $data_contributors = $args{data_contributors} ;
    my $origDataType = $args{origDataType} || '';
    my $repository_identifiers = $args{repository_identifiers} || '';
 
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


    my $outfile = "$repository_path_cp/$sample_accession/files/metadata/";
    my $file_name = "README.txt";

    ## write to README file
    open(OUTFILE,">$outfile/$file_name") or die "cannot open $outfile/$file_name for writing";

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
    close(OUTFILE) or die "cannot close $outfile ($!)";

    my $fh;
    if ($repository_identifiers){
      write_pxdxml_file("$repository_path_cp/$sample_accession/files/metadata/", $repository_identifiers);
    }

    if ( ! $origDataType && $repository_identifiers){
      if (! -d "$repository_path_cp/$sample_accession/files/raw"){ 
         mkdir "$repository_path_cp/$sample_accession/files/raw";
      }
      open $fh, ">$repository_path_cp/$sample_accession/files/raw/raw.txt" || 
                die "cannot open $repository_path_cp/$sample_accession/files/raw/raw.txt\n" ;
      write_raw_links($fh, $repository_identifiers);
    }

}

sub write_pxdxml_file {
  my $path = shift;
  my $repository_identifiers = shift;
  if ($repository_identifiers =~ /(PXD0{0,})(\d+)/){
    open (OUT, ">$path/$1$2.xml");
    my $url = "http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=$2&outputMode=XML&test=no";
    my $ua = new LWP::UserAgent;
    my $request = new HTTP::Request('GET', $url);
    my $response = $ua->request($request);
    my $content = $response->content();
    print OUT "$content";
  }

}

#######################################################################
# write raw external links to file
#######################################################################
sub write_raw_links {
  my $fh = shift;
  my $repository_identifiers = shift;
  if ($repository_identifiers =~ /PXD0{0,}(\d+)/){
    my $url = "http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=$1&outputMode=XML&test=no";
    my $ua = new LWP::UserAgent;
		my $request = new HTTP::Request('GET', $url);
		my $response = $ua->request($request);
 		my $content = $response->content(); 
    my @raw_links = $content =~ /.*raw file URI.*value="([^"]+)".*/g;
    foreach my $link (@raw_links){
      print $fh "$link\n";
    }
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
