#!/usr/local/bin/perl  -w


#######################################################################
# write_qualscore_script_for_atlas.pl -- writes a script to run
#     qualscore on all data directories of a given atlas.  The output
#     script is meant to be run on the regis cluster as a separate step
#     afterwards.
#
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
             $data_root_dir $atlas_build_name $atlas_build_id
             $errorfile $scriptfile $qdir_locations_file
            );
#            $interact_datafile 

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
  --test              test this code

  --atlas_build_name  Name of atlas build

  --atlas_build_id    atlas build id

 e.g.:  $PROG_NAME --atlas_build_name \'Yeast PeptideAtlas P\>\=0.9\'

EOU


unless ( GetOptions(\%OPTIONS, "test", "atlas_build_name:s", "atlas_build_id:s") )
{

    print "$USAGE";

    exit;

};



$TEST = $OPTIONS{"test"} || 0;

$atlas_build_name  = $OPTIONS{atlas_build_name} || '';

$atlas_build_id  = $OPTIONS{atlas_build_id} || '';

unless ($TEST || $atlas_build_name || $atlas_build_id)
{

    print "\n$USAGE\n";

    exit(0);

}


## root dir of SBEAMS experiments:
$data_root_dir = "/sbeams/archive"; 

## file names:
$errorfile = "/sbeams/archive/qualscore_ERRORS.txt";

$scriptfile = "/sbeams/archive/qualscore_script.csh";

##$interact_datafile = "interact-forqualscore-data.htm";
## Qualscore works on modern interact.xml now!
## Replacing interact_datafile with a search for the interact.xml 
## files in each directory.  If more than one of the following are 
## found, an error will be printed to error file, and will have to 
## handle that case by hand.  File patterns looking for are: 
## interact-prob.xml, interact-prob?.xml, and interact-prob??.xml   
## (some of the largest datasets had to be put through the 'Prophets in pieces.)

$qdir_locations_file = "/sbeams/archive/qualscore_locations.txt";

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

    ## initialize script file and error message file
    initialize_files();


    ## set atlas_build_id using atlas_build_name:
    set_atlas_build_id();


    ## write script (it has cmds to run qualscore on data directories)
    write_atlas_qualscore_script();

    print "\nwrote $scriptfile\n";

    print "wrote $errorfile\n\n";


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

        print "you must run this on atlas\n";

        exit(0);

    }

}

#######################################################################
# initialize_files -- check that can write to files and
#   initialize them
#######################################################################
sub initialize_files()
{

    ## initialize script file with csh location and cd to qualscore cmd
    open(OUTFILE,">$scriptfile") or die 
        "cannot open $scriptfile for writing ($!)";

    print OUTFILE "#!/bin/csh\n\n";

#   print OUTFILE "setenv datafile \"$interact_datafile\"\n\n";
#
#   print OUTFILE "setenv errorfile \"$errorfile\"\n\n";

    print OUTFILE "rm -f $qdir_locations_file\n\n";

    print OUTFILE "touch $qdir_locations_file\n\n";

    close(OUTFILE) or die
        "cannot close $scriptfile ($!)";


    ## write new empty error message file:
    open(OUTFILE,">$errorfile") or die 
        "cannot open $errorfile for writing ($!)";

    close(OUTFILE) or die
        "cannot close $errorfile ($!)";

}



#######################################################################
# write_atlas_qualscore_script --
#######################################################################
sub write_atlas_qualscore_script()
{

    ## Get sample information. Structure is: 
    ## key = sample_tag
    ## value = search_batch_id
    my %samples = get_sample_info();


    ## Get experiment location information. Structure is simple hash with
    ##  key = $search_batch_id, 
    ##  value = $experiment_path
    my %data_dirs = get_data_directories( sample_ref => \%samples );


    ## iterate over sample_tags, writing formatted info to file:
    foreach my $sample_tag ( keys %samples)
    {

        my $sbid = $samples{$sample_tag};

        ## identify data directories (spectra stored one level above search results):
        my $search_data_dir = $data_dirs{ $sbid };

        ## get data location, if more than one file matches pattern, prints
        ## message to error log and returns empty string
        my $interactDataFileLocation = get_data_location( 
 
            data_dir => $search_data_dir,
 
            file_pattern => "interact-prob.xml, interact-prob?.xml, interact-prob??.xml",
 
            sample_tag => $sample_tag,
 
        );

        if ($interactDataFileLocation)
        {

            write_script_file(
                
                data_dir => $search_data_dir,

                interactDataFileLocation => $interactDataFileLocation,
            );

        }

    } ## end sample tag iteration

}

#######################################################################
# write_script_file -- write script file of qualscore commands
#######################################################################
sub write_script_file
{

    ## writes a simple csh file of cmds to run qualscore

    my %args = @_;

    my $dataDir = $args{data_dir} || 
        die "need data directory ($!)";

    my $interactDataFileLocation = $args{interactDataFileLocation} || 
        die "need interactDataFileLocation ($!)";

    chomp ($dataDir);

    chomp ($interactDataFileLocation);

    my $str1 = "cd $dataDir";

    my $str3 = "qualscore $interactDataFileLocation | grep -v WARN >>\& $errorfile";

    my $str4 = "echo \"$dataDir/interact-data.qdir\" >> $qdir_locations_file";


    open(OUTFILE,">>$scriptfile") or die 
        "cannot open $scriptfile for writing ($!)";

    print OUTFILE "$str1\n";

    print OUTFILE "$str3\n";

    print OUTFILE "$str4\n\n";

    close(OUTFILE) or die
        "cannot close $scriptfile ($!)";

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
# get_data_location -- given dir, and file pattern; returns found
#     file name.
#######################################################################
sub get_data_location
{

    my %args = @_;

    my $sample_tag = $args{sample_tag};

    my $data_dir = $args{data_dir} || die "need data directory for $sample_tag ($!)";

    my $file_pattern = $args{file_pattern} || die "need file_pattern for $sample_tag list ($!)";

    ## split, if more than one entry:
    my @search_patterns = split(",",$file_pattern);

    my @locations;

    my $location;

    ## find matching patterns in directory:
    for (my $i=0; $i <=$#search_patterns; $i++)
    {

#       my $search_pattern = "$data_dir/$search_patterns[$i]";
#       my @data_location = `ls $search_pattern`;

        my $pat = $search_patterns[$i];

        my @data_location = `find $data_dir -name \'$pat\' -print`;

        for (my $j=0; $j <=$#data_location; $j++)
        {

            push(@locations, $data_location[$j]);

        }

    }

    if ( $#locations == -1)
    {

        error_message( message => 
            "couldn't find patterns $file_pattern in directory $data_dir" );

        $location = "";

    }

    if ( $#locations == 0)
    {

        $location = $locations[0];

    }

    if ( $#locations > 0)
    {

        my $msg = "Found more than one file matching patterns "
            . "$file_pattern in directory $data_dir. " 
            . "You'll have to run qualscore on this directory by hand.";

        error_message( message => $msg);

        $location = "";

    }

    return $location;

}

#######################################################################
# get_sample_info -- 
#    public sample records and store it by sample_tag.  
#    returns hash with key = sample_tag, value=search_batch_id
#######################################################################
sub get_sample_info
{

    my %sample_info;

    ## get sample info:
    # my $sql = qq~
    #     SELECT S.sample_tag, S.search_batch_id
    #     FROM $TBAT_SAMPLE S
    #     JOIN $TBAT_ATLAS_BUILD_SAMPLE ABS ON (ABS.sample_id = S.sample_id)
    #     WHERE ABS.record_status != 'D'
    #     AND S.record_status != 'D'
    #     AND ABS.atlas_build_id = '$atlas_build_id'
    # ~;

    ## see that atlas_build_sample records have disappeared, so 
    ## need to write that into/back into the loader!
    ## xxxxxxx
    ## meanwhile, work around is to get sample from an atlas build
    ## via the peptide_instance records:
    my $sql = qq~
        SELECT S.sample_tag, S.search_batch_id
        FROM $TBAT_SAMPLE S
        JOIN $TBAT_PEPTIDE_INSTANCE_SAMPLE PEPIS ON 
            (PEPIS.sample_id = S.sample_id)
        JOIN $TBAT_PEPTIDE_INSTANCE PEPI ON 
            (PEPI.peptide_instance_id = PEPIS.peptide_instance_id)
        WHERE S.record_status != 'D'
        AND PEPI.atlas_build_id = '$atlas_build_id'
    ~;
    

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Couldn't find sample records with \n$sql \n($!)";

    ## store query results in $sample_info
    foreach my $row (@rows) 
    {

        my ($sample_tag,  $search_batch_id ) = @{$row};

        if ( $sample_tag ne "test" && $sample_tag ne "LnCAP_nuc3" )
        {

            $sample_info{$sample_tag} = $search_batch_id;

        }

    }

#   if ($TEST)
#   {
#       foreach my $st ( keys %sample_info )
#       {
#
#           my $sb = $sample_info{$st};
#
#           print "---> $st : $sb\n";
#
#       }
#
#   }


    if ($TEST)
    {
 
        ## assert data structure contents
        foreach my $row (@rows) 
        {

            my ($sample_tag,  $search_batch_id ) = @{$row};

            if ($sample_info{$sample_tag} ne $search_batch_id)
            {

                warn "TEST fails for 
                    $sample_info{$sample_tag} ($!)";

            }

        } ## end assert test


        ## then reduce $sample_info to just one $sample_tag entry
        my %small_sample_info;

        my $count = 0;

        foreach my $st ( keys %sample_info )
        {

            while ($count < 1)
            {

                $small_sample_info{$st}
                    = $sample_info{$st};

                $count++;

            }

        }

        %sample_info = %small_sample_info;
        
    } ## end $TEST


    return %sample_info;

}



#######################################################################
# get_data_directories -- gets Proteomics records for given search batches
#       and stores the search_batch_id and data dir in a hash.
#       key = search_batch_id, 
#       value = experiment data dir
#######################################################################
sub get_data_directories
{

    my %args = @_;

    my $sample_ref = $args{'sample_ref'} || die "need sample ref ($)";

    my %sample = %{$sample_ref};


    my @search_batch_ids;

    ## make string of search_batch_id's for query
    foreach my $sample_tag ( keys %sample)
    {

        my $sbid = $sample{$sample_tag};

        push(@search_batch_ids, $sbid);

    }

    my $sb_string = join(",", @search_batch_ids);

    my %data_dir_hash;

    my $sql = qq~
        SELECT search_batch_id, data_location
        FROM $TBPR_SEARCH_BATCH
        WHERE search_batch_id IN ($sb_string)
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        die "Query failed: \n $sql \n ($!)";

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

    ## print out attribs if testing
    if ($TEST)
    {
 
        foreach my $sbid ( keys %data_dir_hash )
        {
 
            print "search_batch_id = $sbid ---> path = $data_dir_hash{$sbid}\n";
 
        }
 
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

###############################################################################
# set_atlas_build_id -- set global atlas build id using global atlas_build_name
###############################################################################
sub set_atlas_build_id 
{

    $atlas_build_id = $OPTIONS{"atlas_build_id"} || '';

    if ( $OPTIONS{"atlas_build_name"} && !$atlas_build_id )
    {
    
        my $sql = qq~
        SELECT atlas_build_id
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_name = '$atlas_build_name'
        AND record_status != 'D'
        ~;


        ($atlas_build_id) = $sbeams->selectOneColumn($sql) or
            die "\nERROR: Unable to find the atlas_build_id". 
            "with $sql\n\n";

    }

}

