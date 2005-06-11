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

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $current_username 
             $PROG_NAME $USAGE %OPTIONS $TEST 
             $repository_dir $public_outfile $notpublic_outfile 
             $data_root_dir
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
  --test      test this code

  --run       run program

 e.g.:  $PROG_NAME --run

EOU


unless ( GetOptions(\%OPTIONS, "test", "run") )
{

    print "$USAGE";

    exit;

};



$TEST = $OPTIONS{"test"} || 0;


## repository path:
$repository_dir = "/sbeams/pa_public_archive";

if ($TEST)
{

    $repository_dir = "$repository_dir/TESTFILES";

}

## root dir of SBEAMS experiments:
$data_root_dir = "/sbeams/archive"; 

## paths for output files:
$public_outfile = "$repository_dir/repository_public.txt";

$notpublic_outfile = "$repository_dir/repository_notpublic.txt";


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


    ## check that can write to repository files (also initializes them):
    check_files();


    ## write repository_public.txt, tar up relevant files and move em
    ## if needed
    write_public_file();

    ## write repository_notpublic.txt
    write_private_file();

    print "\nDial up jsp page on browser to generate HTML and
    copy that viewed source to web location...haven't worked out this
    step yet to be auto-matic...\n";

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
# check_files -- check that can write to repository files, and
#   initialize them
#######################################################################
sub check_files()
{

    ## write new empty public file:
    open(OUTFILE,">$public_outfile") or die 
        "cannot open $public_outfile for writing ($!)";

    close(OUTFILE) or die
        "cannot close $public_outfile ($!)";


    ## write new empty "not public" file:
    open(OUTFILE,">$notpublic_outfile") or die 
        "cannot open $notpublic_outfile for writing ($!)";

    close(OUTFILE) or die
        "cannot close $notpublic_outfile ($!)";


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


    ## iterate over sample_tags, writing formatted info to file:
    foreach my $sample_tag ( keys %samples)
    {

        my $sbid = $samples{$sample_tag}->{search_batch_id};

        ## identify data directories (spectra stored one level above search results):
        my $search_data_dir = $data_dirs{ $sbid };

        my $orig_data_dir = $search_data_dir;

        $orig_data_dir =~ s/(.+)\/(.*)$/$1/gi; ## path up one dir level


        ## get mzXMLDataLocation. 
        ## (if doesn't already exist in $repository_dir, will create gzipped tar file)
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


        ## get raw data location.
        ## (if doesn't already exist in $repository_dir, will create gzipped tar file)
        my $rawDataLocation = get_data_location(

            sample_tag => $sample_tag,

            data_dir => $orig_data_dir,

            file_suffix => $rawDataType,

            file_pattern => "*.$rawDataType",

        );


        ## get search results file location.
        ## (if doesn't already exist in $repository_dir, will create gzipped tar file)
        my $searchResultsLocation = get_data_location(

            sample_tag => $sample_tag,

            data_dir => $search_data_dir,

            file_suffix => "searched",

            file_pattern => "inter* ASAP*",

        );


        ## get protein prophet file location.
        ## (if doesn't already exist in $repository_dir, will create gzipped tar file)
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

        
        write_to_public_file(
            
            sample_tag => $sample_tag,

            rawDataLocation => $rawDataLocation,

            rawDataType => $rawDataType,
   
            mzXMLDataLocation => $mzXMLDataLocation,

            READMELocation => $READMELocation,

            searchResultsLocation => $searchResultsLocation,

            description => $description,

            pub_citation_array_ref => \@publication_citations,

            pub_url_array_ref => \@publication_urls,

        );

    }

}

#######################################################################
# write_to_public_file -- write info to the public repository file
#######################################################################
sub write_to_public_file
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $rawDataLocation = $args{rawDataLocation} || 
        die "need rawDataLocation ($!)";

    my $rawDataType = $args{rawDataType} ||
        die "need rawDataType ($!)";

    my $mzXMLDataLocation = $args{mzXMLDataLocation} ||
        die "need mzXMLDataLocation ($!)";

    my $READMELocation = $args{READMELocation} ||
        die "need READMELocation ($!)";

    my $searchResultsLocation = $args{searchResultsLocation} ||
        die "need searchResultsLocation ($!)";

    my $description = $args{description} ||
        die "need description ($!)";


    my $pub_citation_array_ref = $args{pub_citation_array_ref} ||
        die "need citation array ($!)";

    my $pub_url_array_ref = $args{pub_url_array_ref} ||
        die "need url array ($!)";


    my @pub_cit = @{$pub_citation_array_ref};

    my @pub_url = @{$pub_url_array_ref};


    my $str = "$sample_tag\t$rawDataLocation\t$rawDataType\t"
        ."$mzXMLDataLocation\t$READMELocation\t$searchResultsLocation"
        ."\t$description";

    for (my $i = 0; $i <= $#pub_cit; $i++)
    {

        $str = "$str\t".$pub_cit[$i]."\t".$pub_url[$i];

    }


    open(OUTFILE,">>$public_outfile") or die 
        "cannot open $public_outfile for writing ($!)";


    print OUTFILE "$str\n";

    close(OUTFILE) or die
        "cannot close $public_outfile ($!)";

}


#######################################################################
# get_data_location -- given sample_tag, search dir, and data_type, 
#     gets the path of the gzipped tar file.  If the file isn't found
#     in $repository_dir, it packs up the files from the data dir
#     and puts the gzipped tar file in $repository_dir
#######################################################################
sub get_data_location
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $data_dir = $args{data_dir} || die "need data directory for $sample_tag ($!)";

    my $file_suffix = $args{file_suffix} || die "need file_suffix($!)";

    my $file_pattern = $args{file_pattern} || die "need file_pattern for list($!)";

    my $compressed_archive_file = get_compressed_archive_filename(

        sample_tag => $sample_tag,

        file_suffix => $file_suffix,

    );

    my $data_location = "$repository_dir/$compressed_archive_file";



    ## Is file in $repository_dir ?
    if ( -e $data_location )
    {

        ## do nothing
            
    } else 
    {

        print "making $data_location may take awhile, patience...\n";


        ## get pwd, chdir to orig_data_dir, tar up files, gzip 'em, move 'em
        my $progwd = `pwd`;

        chdir $data_dir || die "cannot chdir to $data_dir ($!)";


        ## make a file that contains list of files:
        my $filelist = "tt.txt";

        my $cmd = "rm -f $filelist";

        system $cmd;

        $cmd = "ls $file_pattern > $filelist";

        system $cmd;


        ## if filelist is empty, die with error message:
        die "could not find $file_pattern files in $data_dir" if (-z $filelist);


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

    return $data_location;

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
    my @files = `ls $data_dir/*.dat`;

    if ( $#files > -1)
    {

        $raw_data_type = "dat";

    }



    ## check for .RAW files:
    unless ($raw_data_type)
    {

        my @files = `ls $data_dir/*.RAW`;

        if ( $#files > -1)
        {

            $raw_data_type = "RAW";

        }

    }


    ## check for .raw files:
    unless ($raw_data_type)
    {

        my @files = `ls $data_dir/*.raw`;

        if ( $#files > -1)
        {

            $raw_data_type = "raw";

        }

    }


    if ($TEST)
    {

        print "raw data type in $data_dir is $raw_data_type\n";

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
        die "need experiment raw data type for $sample_tag "
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



        ## Get repository file names, content, and sizes:
        my $file1 = get_compressed_archive_filename(

            sample_tag => $sample_tag,

            file_suffix => $raw_data_type,

        );

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

        my $file1_content = "spectra in .$raw_data_type format\n";

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

        my $file1_size = stat($file1)->size;

        my $file2_size = stat($file2)->size;

        my $file3_size = stat($file3)->size;

        my $file4_size = stat($file4)->size;


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


#   ## print out attribs if testing
#   if ($TEST)
#   {
#
#       foreach my $sbid ( keys %data_dir_hash )
#       {
#
#           print "search_batch_id = $sbid ---> path = $data_dir_hash{$sbid}\n";
#
#       }
#
#   }

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


#   ## print out attribs if testing
#   if ($TEST)
#   {
#
#       foreach my $pid ( keys %publ_info )
#       {
#
#           print "\$publ_info{$pid}->{citation}=$publ_info{$pid}->{citation}\n";
#
#           print "  \$publ_info{$pid}->{url}=$publ_info{$pid}->{url}\n";
#
#           print "  \$publ_info{$pid}->{pmid}=$publ_info{$pid}->{pmid}\n";
#
#       }
#
#   }

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
        WHERE is_public = 'n'
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


#   if ($TEST)
#   {
#
#       ## print out attribs if testing
#       foreach my $st ( keys %sample_info )
#       {
#
#           my $str = "\$sample_info{$st}->";
#
#           my $str2 = $sample_info{$st}->{cell_type};
#
#           print ("$str", "{cell_type} = ", $str2, "\n");
#
#           $str2 = $sample_info{$st}->{data_contributors};
#
#           print ("  $str", "{data_contributors} = ", $str2, "\n");
#
#       }
#
#   } ## end $TEST


    ## assert data structure contents:
    if ($TEST)
    {
 
        foreach my $row (@rows)
        {

            my ($sample_tag, $cell_type, $data_contributors) = @{$row};

            if ($sample_info{$sample_tag}->{cell_type} ne $cell_type)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{cell_type} ($!)";

            }


            if ($sample_info{$sample_tag}->{data_contributors} ne 
                $data_contributors)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{data_contributors} ($!)";

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
        SELECT sample_tag,
            sample_description,
            search_batch_id,
            data_contributors, 
            is_public,
            sample_publication_ids
        FROM $TBAT_SAMPLE
        WHERE is_public = 'y'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records ($!)";

    ## store query results in $sample_info
    foreach my $row (@rows) 
    {

        my ($sample_tag, $sample_description, $search_batch_id,
            $data_contributors, $is_public, $sample_publication_ids) 
            = @{$row};

        ## replace dos end of line markers (\r) and (\n) with space
        $sample_description =~ s/\r/ /g;

        $sample_description =~ s/\n/ /g;

        $sample_info{$sample_tag}->{description} = $sample_description;

        $sample_info{$sample_tag}->{search_batch_id} = $search_batch_id;

        $sample_info{$sample_tag}->{data_contributors} = $data_contributors;

        $sample_info{$sample_tag}->{is_public} = $is_public;

        $sample_info{$sample_tag}->{publication_ids} = $sample_publication_ids;

    }


    if ($TEST)
    {
 
#       ## print out attribs if testing
#       foreach my $st ( keys %sample_info )
#       {
#
#           my $str = "\$sample_info{$st}->";
#
#           my $str2 = $sample_info{$st}->{description};
#
#           print ("$str", "{description} = ", $str2, "\n");
#
#           $str2 = $sample_info{$st}->{search_batch_id};
#
#           print ("  $str", "{search_batch_id} = ", $str2, "\n");
#
#           $str2 = $sample_info{$st}->{data_contributors};
#
#           print ("  $str", "{data_contributors} = ", $str2, "\n");
#
#           $str2 = $sample_info{$st}->{is_public};
#
#           print ("  $str", "{is_public} = ", $str2, "\n");
#
#           $str2 = $sample_info{$st}->{publication_ids};
#
#           print ("  $str", "{publication_ids} = ", $str2, "\n");
#
#       }


        ## assert data structure contents
        foreach my $row (@rows) 
        {

            my ($sample_tag, $sample_description, $search_batch_id,
                $data_contributors, $is_public, $sample_publication_ids) 
                = @{$row};

            ## replace dos end of line markers (\r) and (\n) with space
            $sample_description =~ s/\r/ /g;

            $sample_description =~ s/\n/ /g;

            if ( $sample_info{$sample_tag}->{description} ne
            $sample_description)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{description} ($!)";

            }


            if ($sample_info{$sample_tag}->{search_batch_id} ne
            $search_batch_id)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{search_batch_id} ($!)";

            }


            if ($sample_info{$sample_tag}->{data_contributors} ne
            $data_contributors)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{data_contributors} ($!)";

            }

            if ($sample_info{$sample_tag}->{is_public} ne
            $is_public)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{is_public} ($!)";

            }

            if ($sample_info{$sample_tag}->{publication_ids} ne
            $sample_publication_ids)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag}->{publication_ids} ($!)";

            }

        } ## end assert test

        


        ## then reduce $sample_info to just one $sample_tag entry
        my %small_sample_info;

        my $count = 0;

        foreach my $st ( keys %sample_info )
        {

            while ($count < 1)
            {

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

    my $cell_type = $args{cell_type} || ""; ## might not be in record

    my $data_contributors = $args{data_contributors} ||
        die "need data_contributors for $sample_tag ($!)";


    my $str = "$sample_tag\t$cell_type\t$data_contributors";


    open(OUTFILE,">>$notpublic_outfile") or die 
        "cannot open $notpublic_outfile for writing ($!)";


    print OUTFILE "$str\n";

    close(OUTFILE) or die
        "cannot close $notpublic_outfile ($!)";

}


#######################################################################
# get_compressed_archive_filename --  given sample_tag and data_type,
#    returns name of compressed file archive
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
# get_archive_filename --  given sample_tag and data_type,
#    returns name of file archive
#######################################################################
sub get_archive_filename
{

    my %args = @_;

    my $sample_tag = $args{sample_tag} || die "need sample_tag ($!)";

    my $file_suffix = $args{file_suffix} || die "need file suffix ($!)";

    my $file = $sample_tag."_$file_suffix".".tar";

    return $file;

}

