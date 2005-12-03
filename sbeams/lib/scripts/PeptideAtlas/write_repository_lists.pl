#!/usr/local/bin/perl  -w


#######################################################################
# write_repository_lists -- generates the public and "not public" lists
#   for the repository area.  It also packs up public data and
#   puts it in public area if not found there already.
#
#   NOTE:  PeptideAtlas needs a new table to hold data contributors
#   info, so when that happens, this script needs to be altered...  
#
#   Author: Nichole King
#######################################################################
use strict;
use Getopt::Long;
use FindBin;
use File::stat;

use XML::Writer;
use XML::Parser;
use IO::File;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $current_username 
             $PROG_NAME $USAGE %OPTIONS $TEST 
             $repository_dir $public_outfile $notpublic_outfile 
             $data_root_dir $errorfile $public_xml_outfile
             $repository_url $repository_web_path
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


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


## USAGE:
$USAGE = <<EOU;
Usage: [OPTIONS] key=value key=value ...
Options:
  --test                 test this code

  --run                  run program

  --make_tmp_files       output files are named rep*.tmp to minimize 
                         interruption of active download service

  --public_archive_path  path to public repository archive

  --sbeams_data_path     path to sbeams data 

  --repository_url       URL for PA repository 

  --repository_web_path  path to directory that apache accesses

 e.g.:  ./$PROG_NAME --public_archive_path "/pa_public_archive"  --sbeams_data_path "/sbeams" --repository_url "http://www.peptideatlas.org/repository" --repository_web_path "/www/peptideatlas/repository/pa_public_archive" --run --make_tmp_files

EOU

## get arguments:
GetOptions(\%OPTIONS, "test", "run", "make_tmp_files", 
"public_archive_path:s", "sbeams_data_path:s", "repository_url:s",
"repository_web_path:s");


## check for required arguments:
unless ( ($OPTIONS{"test"} || $OPTIONS{"run"} ) && 
$OPTIONS{"public_archive_path"} && $OPTIONS{"sbeams_data_path"} &&
$OPTIONS{"repository_url"} && $OPTIONS{"repository_web_path"})
{

    print "$USAGE";

    exit;

};


## set some vars based upon arguments:
$TEST = $OPTIONS{"test"} || 0;

$repository_dir = $OPTIONS{"public_archive_path"};

$data_root_dir = $OPTIONS{"sbeams_data_path"};

$repository_url = $OPTIONS{"repository_url"};

$repository_web_path = $OPTIONS{"repository_web_path"};


if ($TEST)
{

    $repository_dir = "$repository_dir/TESTFILES";

}



## paths for output files:
$public_outfile = "$repository_dir/repository_public.txt";

$public_xml_outfile = "$repository_dir/repository_public.xml";

$notpublic_outfile = "$repository_dir/repository_notpublic.txt";

$errorfile = "$repository_dir/errorfile.txt";

if ( $OPTIONS{"make_tmp_files"} )
{

    $public_outfile = $public_outfile . ".tmp";    

    $public_xml_outfile = $public_xml_outfile . ".tmp";    

    $notpublic_outfile = $notpublic_outfile . ".tmp";    

}


#### execute main #####
main();

exit(0);


###############################################################################
# main
###############################################################################
sub main 
{

    #######################################################################
    #  writes repository_public.txt and repository_notpublic.txt files
    #######################################################################
    #  -- sql queries to all sample records in PeptideAtlas database
    #     to fill public and not public files
    #######################################################################


    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ( $current_username = 

        $sbeams->Authenticate(

        work_group=>'PeptideAtlas_admin')
    );


    ## make sure that user is on atlas:
    check_host();


    ## check that can write to files (also initializes them):
    check_files();


    ## write namespace and root tag to xml file:
    initializeXMLFile();

    ## write repository_public.txt, tar up relevant files and move em
    ## if needed
    write_public_file();

    ## write repository_notpublic.txt
    write_private_file();


    ## write ending root node and check that xml is well-formed
    finalizeXMLFile();


    print "\nWrote the following files:\n";

    print "$public_outfile\n$public_xml_outfile\n"; 

    print "$notpublic_outfile\n$errorfile\n"; 


    print "\nDial up jsp page on browser to generate HTML and
    copy that viewed source to web location. \n";

} ## end main


#######################################################################
# check_host -- check that host name is atlas as we need to write to
#   /sbeams/
#######################################################################
sub check_host()
{

    ## make sure that this is running on atlas for queries
    my $uname = `uname -a`;

    if ($uname =~ /.*(atlas).*/)
    {

        # continue

    } else
    {

        die "you must run this on atlas";

    }

}

#######################################################################
# check_files -- check that can write to files, and
#   initialize them
#######################################################################
sub check_files()
{

    my @outfiles =  ($public_outfile, $public_xml_outfile,
        $notpublic_outfile, $errorfile);

    for (my $i=0; $i <= $#outfiles; $i++)
    {

        my $outfile = $outfiles[$i];

        open(OUTFILE,">$outfile") or die 
           "cannot open $outfile for writing";

        close(OUTFILE) or die "cannot close $outfile";

    }


    ## initialize the xml file:
    


}


#######################################################################
# write_public_file -- writes repository_public.txt file.  If the 
#    gzipped files it expects to see are not found, it creates them
#    and moves them to expected location
#
#    NOTE: method essentially stores single sql query for all sample 
#    records into a data structure and re-uses the structure.  if
#    one day find ourselves memory limited, will need to break
#    get_publication_info(), get_public_sample_info(), and 
#    get_data_directories() into queries that produce smaller returns
#    here and change iteration accordingly...this procedure should
#    probably be it's own module too.
#######################################################################
sub write_public_file()
{

    ## Get publication information.  Structure is:
    ##  $publications{$publication_id}->{citation}
    ##  $publications{$publication_id}->{url}
    ##  $publications{$publication_id}->{pmid}
    my %publications = get_publication_info();


    ## Get sample information. Structure is: 
    ##  $samples{$sample_tag}->{organism} = $organism;
    ##  $samples{$sample_tag}->{description} = $sample_description;
    ##  $samples{$sample_tag}->{search_batch_id} = $search_batch_id;
    ##  $samples{$sample_tag}->{data_contributors} = $data_contributors;
    ##  $samples{$sample_tag}->{is_public} = $is_public;
    ##  $samples{$sample_tag}->{publication_ids} = $publication_ids;
    my %samples = get_public_sample_info();


    ## Get experiment location information. Structure is simple hash with
    ##  key = $search_batch_id, 
    ##  value = $experiment_path
    my %data_dirs = get_data_directories();


    ## Iterate over sample_tags, writing formatted info to file:
    ## sorting by organism and sample_tag
    my %sampleTagOrganismHash; 

    foreach my $sample_tag ( keys %samples )
    {

        my $str = $samples{$sample_tag}->{organism} . ":$sample_tag";

        $sampleTagOrganismHash{ $str } = $sample_tag;
        
    }

    ## sort by string of organism:sample_tag
    my @sample_tag_strings = sort {$a cmp $b} keys %sampleTagOrganismHash;

    foreach my $sample_tag_string ( @sample_tag_strings )
    {

        my @tmp = split(":", $sample_tag_string);

        my $sample_tag = $tmp[1];

        my $sbid = $samples{$sample_tag}->{search_batch_id};

        ## identify data directories (spectra stored one level above search results):
        my $search_data_dir = $data_dirs{ $sbid };

        my $orig_data_dir = $search_data_dir;

        $orig_data_dir =~ s/(.+)\/(.*)$/$1/gi; ## path up one dir level

        ## Use get_data_location to: Check that compressed archive is in the public
        ## archive area -- if not, use file_pattern to search for files and create
        ## compressed archive and move it to public archive area -- if files with 
        ## file_pattern don't exist, the location is an empty string

        ## get mzXMLDataLocation. 
        my $mzXMLDataLocation = get_data_location( 

            sample_tag => $sample_tag, 

            data_dir => $orig_data_dir,

            file_suffix => "mzXML",

            file_pattern => "*.mzXML",

        );

        
        ## get raw data type by searching data dir for known suffixes
        my $rawDataType = get_raw_data_type(
            
            data_dir => $orig_data_dir,
            
        );

        ## set file pattern expression to search for.  The dta's need special treatment:
        my $pat = "*.$rawDataType";
       
        $pat = "*_dta.tar" if ($rawDataType eq "TarOfDtas");


        ## get raw data location.
        my $rawDataLocation = get_data_location(

            sample_tag => $sample_tag,

            data_dir => $orig_data_dir,

            file_suffix => $rawDataType,

            file_pattern => $pat,

        );


        ## get search results file location.
        my $searchResultsLocation = get_data_location(

            sample_tag => $sample_tag,

            data_dir => $search_data_dir,

            file_suffix => "searched",

            file_pattern => "inter* ASAP* *.tgz *.html sequest.params",

        );


        ## get protein prophet file location.
        my $proteinProphetLocation = get_data_location(

            sample_tag => $sample_tag,

            data_dir => $search_data_dir,

            file_suffix => "prot",

            file_pattern => "inter*prot.x?? inter*prot.shtml",

        );

        my $data_contributors = $samples{$sample_tag}->{data_contributors};

        my $description = $samples{$sample_tag}->{description};



        ## get array of publication info:
        my @publication_citations = get_publication_citation_entry(

            publication_ids => $samples{$sample_tag}->{publication_ids},

            publications_ref => \%publications,

            entry_type => "citation",

        );


        ## get array of publication urls:
        my @publication_urls = get_publication_citation_entry(

            publication_ids => $samples{$sample_tag}->{publication_ids},

            publications_ref => \%publications,

            entry_type => "url",

        );


        ## get array of publication pmids:
        my @publication_pmids = get_publication_citation_entry(

            publication_ids => $samples{$sample_tag}->{publication_ids},

            publications_ref => \%publications,

            entry_type => "pmid",

        );


        ## get README file location.
        ## (if doesn't already exist in $repository_dir, will create it with
        ## minimum information...NOTE: this needs to be filled with more sample
        ## information and future data contibutors table info)
        my $READMELocation = get_README_location(

            sample_tag => $sample_tag,

            data_contributors => $data_contributors,

            experiment_description => $description,

            raw_data_type => $rawDataType,

            pmids_array_ref => \@publication_pmids,

            citation_array_ref => \@publication_citations,

        );

        
        ## write txt and xml files:
        write_to_public_file(
            
            sample_tag => $sample_tag,

            organism => $samples{$sample_tag}->{organism},

            rawDataLocation => $rawDataLocation,

            rawDataType => $rawDataType,
   
            mzXMLDataLocation => $mzXMLDataLocation,

            READMELocation => $READMELocation,

            searchResultsLocation => $searchResultsLocation,

            proteinProphetLocation => $proteinProphetLocation,

            description => $description,

            data_contributors => $data_contributors,

            pub_citation_array_ref => \@publication_citations,

            pub_url_array_ref => \@publication_urls,

        );

    }

}

#######################################################################
# write_to_public_file -- write info to the public repository files
# and write soft-links accessible by URLs
# @param $sample_tag
# @param $organism
# @param $rawDataLocation (not required)
# @param $rawDataType (not required)
# @param $mzXMLDataLocation
# @param $READMELocation
# @param $searchResultsLocation
# @param $proteinProphetLocation (not required)
# @param $description
#######################################################################
sub write_to_public_file
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $organism = $args{organism} || die "need organism ($!)";

    my $rawDataLocation = $args{rawDataLocation};

    my $rawDataType = $args{rawDataType};

    my $mzXMLDataLocation = $args{mzXMLDataLocation} ||
        die "need mzXMLDataLocation ($!)";

    my $READMELocation = $args{READMELocation} ||
        die "need READMELocation ($!)";

    my $searchResultsLocation = $args{searchResultsLocation} ||
        die "need searchResultsLocation ($!)";

    my $proteinProphetLocation = $args{proteinProphetLocation};

    my $description = $args{description} ||
        die "need description ($!)";

    ## xxxxxxx this should be required, why did I set it to empty set?
    my $data_contributors = $args{data_contributors} || "[]";

    $data_contributors =~ s/\r/ /g;

    $data_contributors =~ s/\n/ /g;

    ## create soft-links from $repository_dir to PA repository public archive URL
    ## (will return empty string if location is empty string)
    $rawDataLocation = makeHttpLocation( 
        location => $rawDataLocation );

    $mzXMLDataLocation = makeHttpLocation( 
        location => $mzXMLDataLocation );

    $READMELocation = makeHttpLocation( 
        location => $READMELocation );

    $searchResultsLocation = makeHttpLocation( 
        location => $searchResultsLocation );

    $proteinProphetLocation = makeHttpLocation( 
        location => $proteinProphetLocation );


    my $pub_citation_array_ref = $args{pub_citation_array_ref} ||
        die "need citation array ($!)";

    my $pub_url_array_ref = $args{pub_url_array_ref} ||
        die "need url array ($!)";


    my @pub_cit = @{$pub_citation_array_ref};

    my @pub_url = @{$pub_url_array_ref};


    ####### write to txt file: ########
    my $str = "$sample_tag\t$organism\t$rawDataLocation\t$rawDataType\t"
        ."$mzXMLDataLocation\t$READMELocation\t$searchResultsLocation\t"
        ."$proteinProphetLocation\t$description\t$data_contributors\t";

    for (my $i = 0; $i <= $#pub_cit; $i++)
    {

        $str = "$str\t".$pub_cit[$i]."\t".$pub_url[$i];

    }


    open(OUTFILE,">>$public_outfile") or die 
        "cannot open $public_outfile for writing ($!)";


    print OUTFILE "$str\n";

    close(OUTFILE) or die
        "cannot close $public_outfile ($!)";


    ######## write to xml file: ########
    writeXMLSample(
        sample_tag => $sample_tag,
        organism => $organism,
        description => $description,
        rawDataType => $rawDataType,
        rawDataLocation => $rawDataLocation,
        mzXMLDataLocation => $mzXMLDataLocation,
        READMELocation => $READMELocation,
        searchResultsLocation => $searchResultsLocation,
        proteinProphetLocation => $proteinProphetLocation,
        data_contributors => $data_contributors,
        pub_citation_array_ref => \@pub_cit,
        pub_url_array_ref => \@pub_url,
    );


}


#######################################################################
#  initializeXMLFile -- write xml declaration and root node start tag
#######################################################################
sub initializeXMLFile
{

    my $out = new IO::File(">$public_xml_outfile");

    my $writer = new XML::Writer(OUTPUT=> $out, UNSAFE => 1);

    $writer->xmlDecl('UTF-8');

    $writer->startTag( 'repository' );

    $writer->end();

    $out->close();

}

#######################################################################
#  finalizeXMLFile -- write root node end tag, and check well-formedness
#######################################################################
sub finalizeXMLFile
{

    my $out = new IO::File(">>$public_xml_outfile");

    my $writer = new XML::Writer(OUTPUT=> $out, UNSAFE => 1);

    $writer->endTag( 'repository' );

    $writer->end();

    $out->close();

    checkWellFormedness();

}


#######################################################################
#  checkWellFormedness -- check that xml file is well-formed
#######################################################################
sub checkWellFormedness
{

    ## check that xml file is well-formed
    my $parser = new XML::Parser();

    eval
    {
        $parser->parsefile ("$public_xml_outfile");
    };


    if ($@)
    {

        print "WARNING: $public_xml_outfile is not well-formed\n";

        error_message (
            message => "WARNING: $public_xml_outfile is not well-formed");

    }

}


#######################################################################
# makeHttpLocation - make soft-link from public archive area to
# repository web path
# @param $location 
# @return webapp relative URI
# (returns empty string if location is empty string)
#######################################################################
sub makeHttpLocation
{

    my %args = @_;

    my $location = $args{location};

    my $newLocation = $location;

    if ($newLocation ne "")
    {

        ## xxxxxxx assuming that all web implementations have sub-dir of
        ## repository called pa_public_archive
        my $pa_public_uri = "pa_public_archive";

        my $pa_public_url = "$repository_url/$pa_public_uri";

        ## extract filename from location....
        my $lastDirMarkerIndex = rindex($location, "/");

        my $filename = substr( $newLocation, $lastDirMarkerIndex + 1);
    
        ## file location with respect to repository url:
        $newLocation = "$pa_public_url/$filename";


        ###### now, make soft link from $location to $repository_web_path/$filename
        my $newSoftLink = "$repository_web_path/$filename";

        symlink $location, $newSoftLink;
#       symlink $location, $newSoftLink or warn 
#           "Can't make soft link from $location to $newSoftLink ($!)\n";

    }


    return $newLocation;

}

#######################################################################
# get_data_location -- given sample_tag, search dir, and data_type, 
#     gets the path of the gzipped tar file.  If the file isn't found
#     in $repository_dir, it packs up the files from the data dir
#     and puts the gzipped tar file in $repository_dir
# @param sample_tag
# @param data_dir
# @param file_suffix  to use as archive file suffix (for example "searched")
# @param file_pattern to use for inclusion in archive file 
#    (for example "inter* ASAP* *.tgz *.html sequest.params")
# @return data_location or compressed archive file; returns nothing if
#    if files with file_pattern don't exist.  (for example, happens
#    when original vendor specific spectra are missing)
#######################################################################
sub get_data_location
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $data_dir = $args{data_dir} || die "need data directory for $sample_tag ($!)";

    my $file_suffix = $args{file_suffix} || 
        error_message ( 
            message => "need file_suffix for $sample_tag, looking in $data_dir ($!)");

    my $file_pattern = $args{file_pattern} || die "need file_pattern for list($!)";


    ## get a formatted name to look for:
    my $compressed_archive_file = get_compressed_archive_filename(

        sample_tag => $sample_tag,

        file_suffix => $file_suffix,

    );


    my $data_location = "$repository_dir/$compressed_archive_file";


    ## Does file exist in $repository_dir ?
    if ( -e $data_location )
    {

        ## do nothing
            
    } else 
    {
        ## else, need to create archive compress it, and move it to public area:
        print "making $data_location may take awhile, patience...\n";


        ## get pwd, chdir to orig_data_dir, tar up files, gzip 'em, move 'em
        my $progwd = `pwd`;

        chdir $data_dir || die "cannot chdir to $data_dir ($!)";


        #### make a file containing files with pattern: ####
        my $filelist = "tt.txt";

        my $cmd = "rm -f $filelist";

        system $cmd;

#       $cmd = "ls $file_pattern > $filelist";

        $cmd = "find $data_dir -name \'$file_pattern\' -print > $filelist";

        system $cmd;


        ## if filelist is empty, report error message, and set data_location to null: 
        if (-z $filelist)
        {

            error_message ( 

                message => "could not find $file_pattern files in $data_dir",

            );

            $data_location = "";

        } else
        {

            ## make a tar archive:
            my $archive_file = get_archive_filename(
    
                sample_tag => $sample_tag,
    
                file_suffix => $file_suffix,
    
            );
    
            my $cmd = "tar -cf $archive_file --files-from=$filelist";
    
            system $cmd;
    
    
            ## compress the tar file:
            my $cmd = "gzip $archive_file";
    
            system $cmd;
    
    
            ## move the gzipped tar file
            $cmd = "mv $compressed_archive_file $repository_dir/";
    
    
            system $cmd;
    
            ## return to former pwd
            chdir $progwd;

        }

    }

    return $data_location;

}

#######################################################################
# error_message
#######################################################################
sub error_message
{

    my %args = @_;

    my $message = $args{message} || die "need message ($!)";


    open(OUTFILE,">>$errorfile") or die "cannot write to $errorfile ($!)";

    print OUTFILE "$message\n";

    close(OUTFILE) or die "cannot close $errorfile ($!)";

}




#######################################################################
# get_raw_data_type -- given data_dir, gets raw data type
#######################################################################
sub get_raw_data_type
{

    my %args = @_;

    my $data_dir = $args{data_dir} ||
        die "need data directory ($!)";


    my $raw_data_type="";


    ## check for .dat files:
#   my @files = `ls $data_dir/*.dat`;
    my @files = `find $data_dir -name \'*.dat\' -print`;


    if ( $#files > -1)
    {

        $raw_data_type = "dat";

    }



    ## check for .RAW files:
    unless ($raw_data_type)
    {

#       my @files = `ls $data_dir/*.RAW`;
        my @files = `find $data_dir -name \'*.RAW\' -print`;

        if ( $#files > -1)
        {

            $raw_data_type = "RAW";

        }

    }


    ## check for .raw files:
    unless ($raw_data_type)
    {

#       my @files = `ls $data_dir/*.raw`;
        my @files = `find $data_dir -name \'*.raw\' -print`;

        if ( $#files > -1)
        {

            $raw_data_type = "raw";

        }

    }


    ## check for .dta tar files:
    unless ($raw_data_type)
    {

#       my @files = `ls $data_dir/*_dta.tar`;
        my @files = `find $data_dir -name \'*_dta.tar\' -print`;

        if ( $#files > -1)
        {

            $raw_data_type = "TarOfDtas";

        }

    }


    ## check for an empty file with "nothingHere" where we don't have original data
    ##  xxxxxxx changing this... entry not necessary now, so remove this implementation
    unless ($raw_data_type)
    {

        my @files = `ls $data_dir/*.nothingHere`;

        if ( $#files > -1)
        {

            $raw_data_type = "nothingHere";

        }

    }


    if ($TEST)
    {

        print "original data format in $data_dir is $raw_data_type\n";

    }


    return $raw_data_type;

}



#######################################################################
# get_publication_citation_entry -- gets publication citation given 
#     publication_id, publications data structure, and entry_type
#     where entry_type can be "citation" or "url" or "pmid"
#######################################################################
sub get_publication_citation_entry
{

    my %args = @_;

    my $publication_ids = $args{publication_ids} || ''; ##might not have publications

    my $publications_ref = $args{publications_ref} || die "ERROR: Must pass publications hash";

    my $entry_type = $args{entry_type} || die "ERROR: Must pass publications entry type";

    my %tmp_publications = %{$publications_ref};

    my @entry_array;


    ## Need to order by publication_id so that citation arrays are parallel
    ## (i.e. url array indices are same as pmid array indices, etc.)
    my @publication_id_array = split /,/ , $publication_ids;

    my @sorted_publication_id_array = sort  sort_by_num @publication_id_array;

    for (my $i = 0; $i <= $#sorted_publication_id_array; $i++)
    {

        my $publication_id = $sorted_publication_id_array[$i];

        if ( exists $tmp_publications{$publication_id} )
        {

           my $entry = $tmp_publications{$publication_id}->{$entry_type};

           push( @entry_array, $entry);

        }

    }

    return @entry_array;
   
}


###############################################################################
#  sort_by_num -- sort numerically
###############################################################################
sub sort_by_num 
{

   if ($a < $b) {-1} elsif ($a > $b) {1} else {0}

}


#######################################################################
# get_README_location --  looks for README file in $repository_dir
#    and if not found, creates it with minimal information...this
#    section needs work and someday should be its own module.
#    It also creates a gzipped copy of the README file for use by the 
#    multi-download servlet
#######################################################################
sub get_README_location
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $data_contributors = $args{data_contributors} || 
        die "need data contributors for $sample_tag ($!)";

    my $experiment_description = $args{experiment_description} || 
        die "need experiment description for $sample_tag ($!)";

    my $raw_data_type = $args{raw_data_type} ||
        warn "need experiment raw data type for $sample_tag "
        ."(the data is probably not in the directory)";


    my $pmids_array_ref = $args{pmids_array_ref} ||
        die "need pmid array reference for $sample_tag ($!)";

    my $citation_array_ref = $args{citation_array_ref} ||
        die "need citation array reference for $sample_tag ($!)";

    my @pmids = @{$pmids_array_ref};

    my @citations = @{$citation_array_ref};


    my $file = $sample_tag."_README";

    my $data_location = "$repository_dir/$file";



    ## Is file in $repository_dir ?
    if ( -e $data_location )
    {

        ## do nothing
            
    } else 
    {

        print "making $data_location ...\n";


        ## get pwd, chdir to repository_dir, make the file
        my $progwd = `pwd`;

        chdir $repository_dir || 
            die "cannot chdir to $repository_dir ($!)";



        my ($file1, $file1_content, $file1_size);

        if ($raw_data_type)
        {

            ## Get repository file names, content, and sizes:
            $file1 = get_compressed_archive_filename(

                sample_tag => $sample_tag,

                file_suffix => $raw_data_type,

            );

            $file1_content = "spectra in .$raw_data_type format\n";

            if (-e $file1)
            {

                $file1_size = stat($file1)->size;

            }

        } else 
        {

            $file1 = "-";

            $file1_content = "orig spectra not avail\n";

            $file1_size = 0;
        }



        my $file2 = get_compressed_archive_filename(

            sample_tag => $sample_tag,

            file_suffix => "mzXML",

        );

        my $file3 = get_compressed_archive_filename(

            sample_tag => $sample_tag,

            file_suffix => "searched",

        );

        my $file4 = get_compressed_archive_filename(

            sample_tag => $sample_tag,

            file_suffix => "prot",

        );


        my $file2_content = "spectra in .mzXML format\n";

        my $file3_content = sprintf("%-21s\n%52s%-21s\n%52s%-21s\n%52s%-21s\n",
            "Files from: SEQUEST,", 
            " ",
            "PeptideProphet,",
            " ",
            "ProteinProphet, ",
            " ",
            "and ASAPRatio if present");

        my $file4_content = "ProteinProphet files\n";

        my ($file2_size, $file3_size, $file4_size);


        if (-e $file2)
        {

            $file2_size = stat($file2)->size;

        }

        if (-e $file3)
        {

            $file3_size = stat($file3)->size;

        }

        if (-e $file4)
        {

            $file4_size = stat($file4)->size;

        }

            

        ## write to README file
        open(OUTFILE,">$file") or die 
            "cannot open $file for writing ($!)";

        ## item 1
        my $str = "#1. Data Contributors:\n" .
            "    $data_contributors\n";

        print OUTFILE "$str\n";


        ## item 2
        $str = "#2. URL link to a www resource\n";

        print OUTFILE "$str\n";


        ## item 3
        $str = "#3. Literature references and PubMed identifications:\n";

        for (my $i = 0; $i <= $#pmids; $i++)
        {

            $str = $str."    $citations[$i]\n    PubMed ID: $pmids[$i]\n";

        }

        print OUTFILE "$str\n";


        ## item 4
        $str = sprintf("%-27s\n    %-68s\n",
            "#4. Experiment Description:",  $experiment_description);

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
        my $fmt = "%-40s %-10s %-22s\n";

        $str = sprintf("$fmt", "#File", "size [bytes]", "Content:");

        print OUTFILE "$str";

        $str = sprintf("$fmt", $file1, $file1_size, $file1_content);
        
        print OUTFILE "$str";

        $str = sprintf("$fmt", $file2, $file2_size, $file2_content);
        
        print OUTFILE "$str";

        $str = sprintf("$fmt", $file3, $file3_size, $file3_content);
        
        print OUTFILE "$str";

        $str = sprintf("$fmt", $file4, $file4_size, $file4_content);
        
        print OUTFILE "$str";


        close(OUTFILE) or die
            "cannot close $file ($!)";

        ## make copy of file and gzip it and rename it
        my $cmd = "cp $file tmp.txt; gzip tmp.txt; mv tmp.txt.gz $file.gz";

        system $cmd;


        ## return to former pwd
        chdir $progwd;

    }

    return $data_location;

}


#######################################################################
# get_data_directories -- gets all Proteomics search_batch_id records
#       and stores the search_batch_id and data dir in a hash.
#       key = search_batch_id, 
#       value = experiment data dir
#######################################################################
sub get_data_directories
{

    my %data_dir_hash;


    my $sql = qq~
        SELECT search_batch_id, data_location
        FROM $TBPR_SEARCH_BATCH
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find proteomics_experiment and search_batch records ($!)";

    ## store query results in $publ_info
    foreach my $row (@rows) 
    {

        my ($search_batch_id, $data_path ) = @{$row};

        ## if $data_path has /data3/sbeams/archive/, remove that
        $data_path =~ s/^(\/data3\/sbeams\/archive\/)(.+)$/$2/gi;
        
        ## if $data_path starts with a /, remove that
        $data_path =~ s/^(\/)(.+)$/$2/gi;

        $data_path = "$data_root_dir/$data_path";

        $data_dir_hash{$search_batch_id} = $data_path;

    }


    ## assert hash not empty
    if ($TEST)
    {
 
        foreach my $row (@rows)
        {

            my ($sbid, $dp ) = @{$row};

            $dp =~ s/^(\/data3\/sbeams\/archive\/)(.+)$/$2/gi;

            $dp =~ s/^(\/)(.+)$/$2/gi;

            $dp  = "$data_root_dir/$dp";

            ## assert entry not empty:
            if ( !exists $data_dir_hash{$sbid})
            {

                warn "get_data_directories TEST fails for $sbid ($!)";

            }

        }
 
    } ## end TEST


    return %data_dir_hash;

}


#######################################################################
# get_publication_info -- get all citation, url, pmid entries from
#     poublication records and store it by publication_id
#######################################################################
sub get_publication_info()
{

    my %publ_info;


    my $sql = qq~
        SELECT publication_id, publication_name, uri, pubmed_ID
        FROM $TBAT_PUBLICATION
    ~;


    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find publication records ($!)";


    ## store query results in $publ_info
    foreach my $row (@rows) 
    {

        my ($publication_id, $publication_name, $uri, $pmid) = @{$row};

        $publ_info{$publication_id}->{citation} = $publication_name; 

        $publ_info{$publication_id}->{url} = $uri;

        $publ_info{$publication_id}->{pmid} = $pmid;

    }


    ## assert data structure contents:
    if ($TEST)
    {

        foreach my $row (@rows)
        {

            my ($publication_id, $publication_name, $uri, $pmid) = @{$row};

            if ( $publ_info{$publication_id}->{citation} ne $publication_name)
            {

                warn "TEST fails for $publ_info{$publication_id}->{citation} ($!)";

            }

            if ( $publ_info{$publication_id}->{url} ne $uri)
            {

                warn "TEST fails for $publ_info{$publication_id}->{uri} ($!)";

            }

            if ( $publ_info{$publication_id}->{pmid} ne $pmid)
            {

                warn "TEST fails for $publ_info{$publication_id}->{pmid} ($!)";

            }


        }

    }


    return %publ_info;

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
        SELECT sample_tag,
            cell_type_term,
            data_contributors
        FROM $TBAT_SAMPLE
        WHERE is_public = 'N'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records ($!)";

    ## store query results in $sample_info
    foreach my $row (@rows) 
    {

        my ($sample_tag, $cell_type, $data_contributors) = @{$row};

        $sample_info{$sample_tag}->{cell_type} = $cell_type;

        $sample_info{$sample_tag}->{data_contributors} = $data_contributors;

    }



    ## assert data structure contents:
    if ($TEST)
    {
 
        foreach my $row (@rows)
        {

            my ($sample_tag, $cell_type, $data_contributors) = @{$row};

            if ($sample_info{$sample_tag}->{cell_type} ne $cell_type)
            {

                warn "TEST fails for " .
                    "$sample_info{$sample_tag}->{cell_type} ($!)".
                    " ($sample_info{$sample_tag}->{cell_type} != " .
                    " $cell_type)\n";


            }


            if ($sample_info{$sample_tag}->{data_contributors} ne 
                $data_contributors)
            {

                warn "TEST fails for " .
                    "$sample_info{$sample_tag}->{data_contributors} ($!)\n".
                    " ( $sample_info{$sample_tag}->{data_contributors} != " .
                    " $data_contributors )\n";

            }

        }

    } ## end TEST


    return %sample_info;

}
   
#######################################################################
# get_public_sample_info -- get relevant attributes from all
#    public sample records and store it by sample_tag
#######################################################################
sub get_public_sample_info
{

    my %sample_info;

    ## get sample info:
    my $sql = qq~
        SELECT S.sample_tag, O.organism_name,
            S.sample_description,
            S.search_batch_id,
            S.data_contributors, 
            S.is_public,
            S.sample_publication_ids
        FROM $TBAT_SAMPLE S
        JOIN $TBPR_SEARCH_BATCH SB 
            ON (SB.search_batch_id = S.search_batch_id)
        JOIN $TBPR_BIOSEQUENCE_SET BS 
            ON (BS.biosequence_set_id = SB.biosequence_set_id)
        JOIN $TB_ORGANISM O ON (BS.organism_id = O.organism_id)
        WHERE S.is_public = 'Y'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records ($!)";

    ## store query results in $sample_info
    foreach my $row (@rows) 
    {

        my ($sample_tag, $organism, $sample_description, $search_batch_id,
            $data_contributors, $is_public, $sample_publication_ids) 
            = @{$row};

        ## replace dos end of line markers (\r) and (\n) with space
        $sample_description =~ s/\r/ /g;

        $sample_description =~ s/\n/ /g;

        $data_contributors =~ s/\r/ /g;

        $data_contributors =~ s/\n/ /g;

        $sample_info{$sample_tag}->{organism} = $organism;

        $sample_info{$sample_tag}->{description} = $sample_description;

        $sample_info{$sample_tag}->{search_batch_id} = $search_batch_id;

        $sample_info{$sample_tag}->{data_contributors} = $data_contributors;

        $sample_info{$sample_tag}->{is_public} = $is_public;

        $sample_info{$sample_tag}->{publication_ids} = $sample_publication_ids;

    }

    if ($TEST)
    {
 
        ## assert data structure contents
        foreach my $row (@rows) 
        {

            my ($sample_tag, $organism, $sample_description, $search_batch_id,
                $data_contributors, $is_public, $sample_publication_ids) 
                = @{$row};

            ## replace dos end of line markers (\r) and (\n) with space
            $sample_description =~ s/\r/ /g;

            $sample_description =~ s/\n/ /g;

            $data_contributors =~ s/\r/ /g;

            $data_contributors =~ s/\n/ /g;

            if ( $sample_info{$sample_tag}->{organism} ne $organism)
            {

                warn "TEST fails for $sample_tag" .
                    "$sample_info{$sample_tag}->{organism} ($!)";

            }


            if ( $sample_info{$sample_tag}->{description} ne
            $sample_description)
            {

                warn "TEST fails for $sample_tag " .
                    "$sample_info{$sample_tag}->{description} ($!)\n".
                    "  ($sample_info{$sample_tag}->{description} ".
                    " != $sample_description)\n";

            }


            if ($sample_info{$sample_tag}->{search_batch_id} ne
            $search_batch_id)
            {

                warn "TEST fails for $sample_tag " .
                    "$sample_info{$sample_tag}->{search_batch_id} ($!)\n" .
                    "  ($sample_info{$sample_tag}->{search_batch_id} NE " .
                    " $search_batch_id)\n";

            }


            if ($sample_info{$sample_tag}->{data_contributors} ne
            $data_contributors)
            {

                warn "TEST fails for $sample_tag " .
                    "$sample_info{$sample_tag}->{data_contributors} ($!)\n" .
                    "  ($sample_info{$sample_tag}->{data_contributors} NE " .
                    " $data_contributors)\n";

            }

            if ($sample_info{$sample_tag}->{is_public} ne
            $is_public)
            {

                warn "TEST fails for $sample_tag " .
                    "$sample_info{$sample_tag}->{is_public} ($!)\n" .
                    "  ($sample_info{$sample_tag}->{is_public} NE " .
                    " $is_public)\n";

            }

            if ($sample_info{$sample_tag}->{publication_ids} ne
            $sample_publication_ids)
            {

                warn "TEST fails for $sample_tag " .
                    "$sample_info{$sample_tag}->{publication_ids} ($!)";

            }

        } ## end assert test

        


        ## then reduce $sample_info to just one $sample_tag entry
        my %small_sample_info;

        my $count = 0;

        foreach my $st ( keys %sample_info )
        {

            while ($count < 1)
            {

                $small_sample_info{$st}->{organism} 
                    = $sample_info{$st}->{organism};

                $small_sample_info{$st}->{description} 
                    = $sample_info{$st}->{description};

                $small_sample_info{$st}->{search_batch_id}
                    = $sample_info{$st}->{search_batch_id};

                $small_sample_info{$st}->{data_contributors} 
                    = $sample_info{$st}->{data_contributors};

                $small_sample_info{$st}->{is_public} 
                    = $sample_info{$st}->{is_public};

                $small_sample_info{$st}->{publication_ids} 
                    = $sample_info{$st}->{publication_ids};

                $count++;

            }

        }

        %sample_info = %small_sample_info;
        
    } ## end $TEST


    return %sample_info;

}
   
#######################################################################
# write_private_file -- writes repository_notpublic.txt file.  
#
#######################################################################
sub write_private_file()
{

    ## Get sample information. Structure is: 
    ##  $samples{$sample_tag}->{cell_type} = $cell_type;
    ##  $samples{$sample_tag}->{data_contributors} = $data_contributors;
    my %samples = get_notpublic_sample_info();


    ## iterate over sample_tags, writing formatted info to file:
    foreach my $sample_tag ( keys %samples)
    {

        write_to_notpublic_file(
            
            sample_tag => $sample_tag,

            cell_type => $samples{$sample_tag}->{cell_type},

            data_contributors => $samples{$sample_tag}->{data_contributors},

        );

    }

}

#######################################################################
# write_to_notpublic_file -- write info to "not public" repository file
#######################################################################
sub write_to_notpublic_file
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $cell_type = $args{cell_type} || "[]"; ## might not be in record

    my $data_contributors = $args{data_contributors} ||
        die "need data_contributors for $sample_tag ($!)";

    chomp($data_contributors);


    my $str = "$sample_tag\t$cell_type\t$data_contributors";


    open(OUTFILE,">>$notpublic_outfile") or die 
        "cannot open $notpublic_outfile for writing ($!)";


    print OUTFILE "$str\n";

    close(OUTFILE) or die
        "cannot close $notpublic_outfile ($!)";

}


#######################################################################
# get_compressed_archive_filename --  given sample_tag and file_suffix
#    returns name of compressed file archive 
# @param $sample_tag (for example: exp1)
# @param $file_suffix (for example: mzXML)
# @return formatted name for the archive file (for example: exp1_mzXML.tar.gz)
#######################################################################
sub get_compressed_archive_filename
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $file_suffix = $args{file_suffix} || die "need file suffix ($!)";

    my $file = get_archive_filename(

        sample_tag => $sample_tag,

        file_suffix => $file_suffix,

    );


    my $file = $file.".gz";

    return $file;

}


#######################################################################
# get_archive_filename --  given sample_tag and file_suffix,
#    returns a formatted name of file archive
# @param $sample_tag (for example: exp1)
# @param $file_suffix (for example: mzXML)
# @return formatted name for the archive file (for example: exp1_mzXML.tar)
#######################################################################
sub get_archive_filename
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $file_suffix = $args{file_suffix} || die "need file suffix ($!)";

    if ($file_suffix eq "TarOfDtas")
    {

        $file_suffix = "dtas";

    }

    my $file = $sample_tag."_$file_suffix".".tar";

    return $file;

}


#######################################################################
# writeXMLSample -- write sample info to xml file.  
#
# Format will be:
#  <sample>
#    <tag>exp1</tag>
#    <organism>Human</organism>
#    <description>Erythroleukemia K562 cell line</description>
#    <data_contributors>Katherine Resing (U Col), Meyer-Arendt K, Mendoza AM, Aveline-Wolf LD Jonscher KR, Pierce KG, Old WM, Cheung HT, Russell S, Wattawa JL, Goehle GR, Knight RD, Ahn NG</data_contributors>
#    <resource>
#      <README="http://www.peptideatlas.org/repository/pa_public_archive/A8_IP_README"/>
#    </resource>
#    <resource>
#      <RAW_Format="http://www.peptideatlas.org/repository/pa_public_archive/A8_IP_RAW.tar.gz"/>
#    </resource>
#    <resource>
#      <dat_Format="http://www.peptideatlas.org/repository/pa_public_archive/A8_IP_dat.tar.gz"/>
#    </resource>
#    <resource>
#      <mzXML_Format="http://www.peptideatlas.org/repository/pa_public_archive/A8_IP_mzXML.tar.gz"/>
#    </resource>
#    <resource>
#      <Search_Results="http://www.peptideatlas.org/repository/pa_public_archive/A8_IP_searched.tar.gz"/>
#    </resource>
#    <resource>
#      <ProteinProphet_file="http://www.peptideatlas.org/repository/pa_public_archive/A8_IP_prot.tar.gz"/>
#    </resource>
#    <publication>
#      <citation="Resing et al. 2004, Anal Chem"/>
#      <url="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=15228325"/>
#    </publication>
#  </sample>
#######################################################################
sub writeXMLSample
{

    my %args = @_;

    ## read arguments:
    my $sample_tag = $args{'sample_tag'} || die "need sample tag ($!)";

    my $organism = $args{'organism'} || die "need organism ($!)";

    my $description = $args{'description'} || die "need description ($!)";

    my $mzXMLDataLocation = $args{'mzXMLDataLocation'} || 
        die "need mzXMLDataLocation ($!)";

    my $READMELocation = $args{'READMELocation'} || 
        die "need READMELocation ($!)";

    my $data_contributors = $args{'data_contributors'} ||
        die "need data_contributors ($!)";

    my $searchResultsLocation = $args{'searchResultsLocation'} || 
        die "need searchResultsLocation ($!)";

    my $rawDataLocation = $args{'rawDataLocation'};

    my $rawDataType = $args{'rawDataType'};

    my $proteinProphetLocation = $args{'proteinProphetLocation'};

    my $pub_citation_array_ref = $args{'pub_citation_array_ref'};

    my $pub_url_array_ref = $args{'pub_url_array_ref'};

    #my @pub_cit = @{$pub_citation_array_ref};

    #my @pub_url = @{$pub_url_array_ref};



    ## open xml file and writer:
    my $out = new IO::File(">>$public_xml_outfile");

    my $writer = new XML::Writer(OUTPUT=> $out, UNSAFE => 1);

    ## indent 2 spaces, write start tag, write end-of line marker
    $out->print("  ");
    $writer->startTag("sample");
    $out->print("\n");


    ## indent 4 spaces, write tag, write end-of line marker
    $out->print("    ");
    $writer->startTag("sample_tag");
    $writer->characters($sample_tag);
    $writer->endTag("sample_tag");
    $out->print("\n");


    ## indent 4 spaces, write tag, write end-of line marker
    $out->print("    ");
    $writer->startTag("organism");
    $writer->characters($organism);
    $writer->endTag("organism");
    $out->print("\n");


    ## indent 4 spaces, write tag, write end-of line marker
    $out->print("    ");
    $writer->startTag("description");
    $writer->characters($description);
    $writer->endTag("description");
    $out->print("\n");


    ## indent 4 spaces, write tag, write end-of line marker
    $out->print("    ");
    $writer->startTag("resource", "README" => $READMELocation);
    $writer->endTag("resource");
    $out->print("\n");

    ## indent 4 spaces, write tag, write end-of line marker
    $out->print("    ");
    $writer->startTag("resource", "Data_Contributors" => $data_contributors);
    $writer->endTag("resource");
    $out->print("\n");


    ## indent 4 spaces, write tag, write end-of line marker
    $out->print("    ");
    $writer->startTag("resource", "mzXML_format" => $mzXMLDataLocation);
    $writer->endTag("resource");
    $out->print("\n");


    ## indent 4 spaces, write tag, write end-of line marker
    $out->print("    ");
    $writer->startTag("resource", "Search_Results" => $searchResultsLocation);
    $writer->endTag("resource");
    $out->print("\n");


    if ($rawDataLocation ne "")
    {
        ## indent 4 spaces, write tag, write end-of line marker
        $out->print("    ");
        $writer->startTag("resource", "${rawDataType}_format" => $rawDataLocation);
        $writer->endTag("resource");
        $out->print("\n");
    }

    if ($proteinProphetLocation ne "")
    {
        ## indent 4 spaces, write tag, write end-of line marker
        $out->print("    ");
        $writer->startTag("resource", 
            "ProteinProphet_file" => $proteinProphetLocation);
        $writer->endTag("resource");
        $out->print("\n");
    }


    if ($pub_citation_array_ref )
    {

        my @pub_cit = @{$pub_citation_array_ref};

        my @pub_url = @{$pub_url_array_ref};

        for (my $i = 0; $i <= $#pub_cit; $i++)
        {
            ## indent 4 spaces, write tag, write end-of line marker
            $out->print("    ");
            $writer->startTag("publication",
                "citation" => $pub_cit[$i],
                "url" => $pub_url[$i],
            );
            $writer->endTag("publication");
            $out->print("\n");
        }
    }

    ####### end resources #######


    ## indent 2 spaces, write end sample tag:
    $out->print("  ");
    $writer->endTag("sample");

    $writer->end();

    $out->close();

}

