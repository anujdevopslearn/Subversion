#!/usr/local/bin/perl  -w


#######################################################################
# write_experiment_outfile -- makes a tsv file of experiments of an
#    atlas.  File is called experiments_atlas_xx.tsv.  
# Format is:
# sample_tag  description  instrument  data_contributors  publ_ref
#
#
# Author: Nichole King
#######################################################################
use strict;
use Getopt::Long;
use FindBin;
use File::stat;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $current_username 
             $PROG_NAME $USAGE %OPTIONS $TEST 
             $outfile
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

$PROG_NAME = $FindBin::Script;
## USAGE:
$USAGE = <<EOU;
Usage: [OPTIONS] key=value key=value ...
Options:

  --atlas_build_id   atlas build id


 e.g.: ./$PROG_NAME --atlas_build_id 73

EOU

GetOptions(\%OPTIONS, "atlas_build_id:s");

unless ( $OPTIONS{"atlas_build_id"} )
{

    print "$USAGE";

    exit;

};


$TEST = $OPTIONS{"test"} || 0;


main();

exit(0);


###############################################################################
# main
###############################################################################
sub main 
{

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ( $current_username = 

        $sbeams->Authenticate(

        work_group=>'PeptideAtlas_admin')
    );


    ## make sure that user is on atlas:
    check_host();


    ## set name of output file:
    $outfile = getOutfileName(atlas_build_id => $OPTIONS{"atlas_build_id"});


    ## check that can write file (also initializes it):
    check_files();


    ## get string array of line entries of info for experiments
    my @lines = get_experiment_info(atlas_build_id => 
        $OPTIONS{"atlas_build_id"});


    write_outfile( lines_ref => \@lines, outfile => $outfile );


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

    ## write new empty outfile:
    open(OUTFILE,">$outfile") or die 
        "cannot open $outfile for writing ($!)";

    close(OUTFILE) or die
        "cannot close $outfile ($!)";

}


#######################################################################
# get_experiment_info - gets experiment info and writes
#    them all to a string array
# @return string array of info on all experiments of an atlas
#######################################################################
sub get_experiment_info
{

    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} || 
        die "need atlas build id ($!)";

    my @line_str_array;

    ## Get sample information. Structure is: 
    ##  $samples{$sample_tag}->{description} = $sample_description;
    ##  $samples{$sample_tag}->{search_batch_id} = $search_batch_id;
    ##  $samples{$sample_tag}->{data_contributors} = $data_contributors;
    ##  $samples{$sample_tag}->{instrument} = $instrument;
    my %samples = get_sample_info( atlas_build_id => $atlas_build_id);

    foreach my $key (sort keys %samples)
    {

        my $sample_tag = $key;

        my $data_contributors = $samples{$sample_tag}->{data_contributors};

        my $description = $samples{$sample_tag}->{description};

        my $instrument = $samples{$sample_tag}->{instrument};

        my $publ_refs = $samples{$sample_tag}->{publication_refs};

        my $str = "$sample_tag\t$description\t$instrument"
        ."\t$data_contributors\t$publ_refs";

        push(@line_str_array, $str);

    }

    return @line_str_array;

}

#######################################################################
# write_outfile -- write string array of lines to outfile
#######################################################################
sub write_outfile
{

    my %args = @_;

    my $lines_ref = $args{lines_ref} || 
        die " need lines_ref ($!)";

    my $outfile = $args{outfile} || die "need outfile ($!)";

    my @lines = @{$lines_ref};


    open(OUTFILE,">>$outfile") or die 
        "cannot open $outfile for writing ($!)";

    for (my $i = 0; $i <= $#lines; $i++)
    {

        print OUTFILE "$lines[$i]\n";

    }


    close(OUTFILE) or die
        "cannot close $outfile ($!)";

    print "\nwrote outfile $outfile\n\n";

}


#######################################################################
# error_message
#######################################################################
#sub error_message
#{
#
#   my %args = @_;
#
#   my $message = $args{message} || die "need message ($!)";
#
#
#   open(OUTFILE,">>$errorfile") or die "cannot write to $errorfile ($!)";
#
#   print OUTFILE "$message\n";
#
#   close(OUTFILE) or die "cannot close $errorfile ($!)";
#
#}


#######################################################################
# get_sample_info -- get relevant attributes from all
#   PeptideAtlas and Proteomics records
#
# store in data structure:
#   $samples{$sample_tag}->{description} = $sample_description;
#   $samples{$sample_tag}->{search_batch_id} = $search_batch_id;
#   $samples{$sample_tag}->{data_contributors} = $data_contributors;
#   $samples{$sample_tag}->{instrument} = $instrument;
#   $samples{$sample_tag}->{publication_refs} = $publ_refs;
#
#######################################################################
sub get_sample_info
{

    my %args = @_;

    my $atlas_build_id = $args{"atlas_build_id"} || 
        die "need atlas build id";

    my %sample_info;

    ## get sample info:
    my $sql = qq~
        SELECT S.sample_tag, 
            S.sample_description,
            S.search_batch_id,
            S.data_contributors,
            S.sample_publication_ids
        FROM $TBAT_SAMPLE S
        JOIN $TBAT_ATLAS_BUILD_SAMPLE ABS
        ON (S.sample_id = ABS.sample_id)
        WHERE ABS.atlas_build_id = '$atlas_build_id'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records ($!)";

    ## store query results in $sample_info
    foreach my $row (@rows) 
    {

        my ($sample_tag, $sample_description, $search_batch_id,
            $data_contributors, $publication_ids) = @{$row};

        ## replace dos end of line markers (\r) and (\n) with space
        $sample_description =~ s/\r/ /g;

        $sample_description =~ s/\n/ /g;

        $data_contributors =~ s/\r/ /g;

        $data_contributors =~ s/\n/ /g;

        $sample_info{$sample_tag}->{description} = $sample_description;

        $sample_info{$sample_tag}->{search_batch_id} = $search_batch_id;

        $sample_info{$sample_tag}->{data_contributors} = $data_contributors;

        ## make sql call to get instrument name:
        my $instrument = getInstrumentName( search_batch_id =>
            $search_batch_id );

        $sample_info{$sample_tag}->{instrument} = $instrument;

        ## make sql call to get publication refs:
        my $publications = getPublications( publication_ids => 
            $publication_ids );

        $sample_info{$sample_tag}->{publication_refs} = $publications;

    }

    if ($TEST)
    {
 
        ## assert data structure contents
        foreach my $row (@rows) 
        {

            my ($sample_tag, $sample_description, $search_batch_id,
                $data_contributors, $publication_ids) 
                = @{$row};

            ## replace dos end of line markers (\r) and (\n) with space
            $sample_description =~ s/\r/ /g;

            $sample_description =~ s/\n/ /g;

            $data_contributors =~ s/\r/ /g;

            $data_contributors =~ s/\n/ /g;


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

                $count++;

            }

        }

        %sample_info = %small_sample_info;
        
    } ## end $TEST


    return %sample_info;

}
   

#######################################################################
# getOutfileName
#   @param atlas_build_id
#   @return name of output tsv file
#######################################################################
sub getOutfileName
{

    my %args = @_;
 
    my $filename;

    my $atlas_build_id = $args{atlas_build_id} || 
        die "need atlas build id ($!)";

    ## check that atlas exists:
    my $sql = qq~
    SELECT atlas_build_id
    FROM $TBAT_ATLAS_BUILD
    WHERE atlas_build_id = '$atlas_build_id'
    AND record_status != 'D'
    ~;

    my ($check) = $sbeams->selectOneColumn($sql) or
    die "\nERROR: Unable to find the atlas_build_id with sql:\n"
    ."\n$sql\n";

    $filename = "experiments_atlas_" . $atlas_build_id . ".tsv";

    return $filename;

}


#######################################################################
# getInstrumentName
#   @param search_batch_id
#   @return name of mass spectrometer
#######################################################################
sub getInstrumentName
{

    my %args = @_;

    my $instrument_name;

    my $search_batch_id = $args{search_batch_id} ||
        die "need search_batch_id ($!)";

    my $sql = qq~
        SELECT INSTR.instrument_name
        FROM $TBPR_INSTRUMENT INSTR
        JOIN $TBPR_PROTEOMICS_EXPERIMENT PE
        ON (PE.instrument_id = INSTR.instrument_id)
        JOIN $TBPR_SEARCH_BATCH SB
        ON (SB.experiment_id = PE.experiment_id)
        WHERE SB.search_batch_id = '$search_batch_id'
        AND INSTR.record_status != 'D'
        AND PE.record_status != 'D'
    ~;

    ($instrument_name) = $sbeams->selectOneColumn($sql) or
    die "\nERROR: Unable to find the instrument_name with sql:\n"
    . "\n$sql\n";


    return $instrument_name;
}

#######################################################################
# getPublications
#   @param publication_ids
#   @return string of publication references
#######################################################################
sub getPublications
{

    my %args = @_;

    my $str = "";

    my $publication_ids = $args{publication_ids};

    if ($publication_ids ne "")
    {
        ## get hash of all publications in PeptideAtlas:
        my %publications = get_publication_info();
    

        my @publication_citations = get_publication_citation_entry(
        
            publication_ids => $publication_ids,

            publications_ref => \%publications,

            entry_type => "citation",

        );


        $str = $publication_citations[0] if ($#publication_citations >= 0);

        for (my $i=1; $i <= $#publication_citations; $i++)
        {

            $str = $str . "; $publication_citations[$i]";

        }

    }


    return $str;
}

#######################################################################
# get_publication_info -- get all citation, url, pmid entries from
#     publication records and store it by publication_id
#
# data structure is:
#    $publ_info{$publication_id}->{citation} = $publication_name;
#    $publ_info{$publication_id}->{url} = $uri;
#    $publ_info{$publication_id}->{pmid} = $pmid;
#
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


    return %publ_info;

}


#######################################################################
# get_publication_citation_entry -- gets publication citation given
#     publication_id, publications data structure, and entry_type
#     where entry_type can be "citation" or "url" or "pmid"
#######################################################################
sub get_publication_citation_entry
{

    my %args = @_;

    my $publication_ids = $args{publication_ids} || ''; 

    my $publications_ref = $args{publications_ref} || 
        die "ERROR: Must pass publications hash";

    my $entry_type = $args{entry_type} || 
        die "ERROR: Must pass publications entry type";

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


