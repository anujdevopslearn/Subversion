#!/usr/local/bin/perl -w

###############################################################################
#
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../../perl/SBEAMS/PeptideAtlas";
use PAxmlContentHandler;
use SpectraDescriptionSetParametersParser;
use SearchResultsParametersParser;

use XML::Parser;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $ATLAS_BUILD_ID %spectra
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $sbeamsPROT  $UPDATE_ALL
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

$sbeamsPROT = new SBEAMS::Proteomics;
$sbeamsPROT->setSBEAMS($sbeams);

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added
  --testvars                  If set, makes sure all vars are filled

  --update                    update atlas_search_batch_records

  --atlas_build_name          Name of the atlas build (already entered by hand in
                              the atlas_build table) into which to load the data
  --update_all

 e.g.:  ./$PROG_NAME --atlas_build_name \'Human_P0.9_Ens26_NCBI35\' --update
 e.g.:  ./$PROG_NAME --update_all

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "update", "atlas_build_name:s", "update_all"
    )) {

    die "\n$USAGE";

}


$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TESTONLY = $OPTIONS{"testonly"} || 0;

$UPDATE_ALL = $OPTIONS{"update_all"} || 0;

   
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
sub main 
{

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless (
      $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
  );

  handleRequest();

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  my %args = @_;

  ##### PROCESS COMMAND LINE OPTIONS AND RESTRICTIONS #####

  my $update = $OPTIONS{"update"} || '';

  my $update_all = $OPTIONS{"update_all"} || '';

  my $atlas_build_name = $OPTIONS{"atlas_build_name"} || '';

  #### Verify required parameters
  unless ($atlas_build_name || $update_all) {
    print "\nERROR: You must specify an --atlas_build_name or --update_all\n\n";
    die "\n$USAGE";
  }

  #### If there are any unresolved parameters, exit
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }

  if ($atlas_build_name)
  {
      $ATLAS_BUILD_ID = get_atlas_build_id(atlas_build_name=>$atlas_build_name);
      my $msg = $sbeams->update_PA_table_variables($ATLAS_BUILD_ID);
      if ($update) 
      {
          update_atlas_search_batch_records( atlas_build_id=>$ATLAS_BUILD_ID);
      } 

  }  elsif ($UPDATE_ALL)
  {
      my $sql = qq~
          SELECT atlas_search_batch_id
          FROM $TBAT_ATLAS_SEARCH_BATCH
          WHERE record_status != 'D'
          order by atlas_search_batch_id
      ~;

     my @rows = $sbeams->selectSeveralColumns($sql);

     foreach my $row (@rows)
     {
         my ($asb_id) = @{$row};

         update_atlas_search_batch_record(atlas_search_batch_id=>$asb_id);
     }
  }
} # end handleRequest

###############################################################################
# get_atlas_build_id  --  get atlas build id
# @param atlas_build_name
# @return atlas_build_id
###############################################################################
sub get_atlas_build_id 
{
    my %args = @_;

    my $name = $args{atlas_build_name} or die "need atlas build name($!)";

    my $id;

    my $sql = qq~
        SELECT atlas_build_id
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_name = '$name'
        AND record_status != 'D'
    ~;

    ($id) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: Unable to find the atlas_build_name ". 
        $name." with $sql\n\n";

    return $id;
}


###############################################################################
# get_search_batch_directory
# @param atlas_search_batch_id
# @return directory holding search batch data
###############################################################################
sub get_search_batch_directory
{
    my %args = @_;

    my $atlas_search_batch_id = $args{atlas_search_batch_id} or
        "die need atlas_search_batch_id";

    my $path;

    my $sql = qq~
        SELECT ASB.data_location, ASB.search_batch_subdir
        FROM $TBAT_ATLAS_SEARCH_BATCH ASB
        WHERE ASB.atlas_search_batch_id = '$atlas_search_batch_id'
        AND ASB.record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or
        die "\nERROR: $sql\n"; 

    ## get the global variable 
    my $archive_dir = $RAW_DATA_DIR{Proteomics};

    my $search_batch_absolute_path;

    foreach my $row (@rows)
    {
        my ($data_location, $search_batch_subdir, $atlas_search_batch_id) = @{$row};

        $search_batch_absolute_path = "$archive_dir/$data_location/$search_batch_subdir";

        ## check that path exists
        unless ( -e $search_batch_absolute_path) 
        {
            print "\n Can't find path $search_batch_absolute_path in file system.  Please check ".
            " atlas_search_batch $atlas_search_batch_id\n";
        }
    }

    return $search_batch_absolute_path;
}

###############################################################################
# get_biosequence_set_id  --  get biosequence_set_id
# @param atlas_build_id
# @return atlas_build:biosequence_set_id
###############################################################################
sub get_biosequence_set_id
{
    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} or die "need atlas build id($!)";

    my $b_id;

    my $sql = qq~
        SELECT biosequence_set_id
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_id = '$atlas_build_id'
        AND record_status != 'D'
    ~;

    ($b_id) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: Unable to find the biosequence_set_id in atlas_build record". 
        " with $sql\n\n";

    return $b_id;
}

###############################################################################
# update_atlas_search_batch_record
# @param atlas_search_batch_id
##############################################################################
sub update_atlas_search_batch_record
{
    my %args = @_;

    my $atlas_search_batch_id = $args{atlas_search_batch_id} or 
        die "need atlas_search_batch_id";

    my $path = get_search_batch_directory(
          atlas_search_batch_id=>$atlas_search_batch_id);

    my $nspec = $sbeamsMOD->getNSpecFromFlatFiles (search_batch_path => $path);

    ## UPDATE atlas_search_batch record
    my %rowdata = (
       n_searched_spectra => $nspec,
    );

    my $success = $sbeams->updateOrInsertRow(
        update=>1,
        table_name=>$TBAT_ATLAS_SEARCH_BATCH,
        rowdata_ref=>\%rowdata,
        PK => 'atlas_search_batch_id',
        PK_value => $atlas_search_batch_id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

}


###############################################################################
# update_atlas_search_batch_records -- updates the n_searched_spectra field of atlas_search_batch
# records
# @param atlas_build_id
###############################################################################
sub update_atlas_search_batch_records 
{
    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'} or die
        " need atlas_build_id";

    my $biosequence_set_id = get_biosequence_set_id (atlas_build_id =>
        $atlas_build_id);

    my $sql = qq~
        SELECT n_searched_spectra, ASB.atlas_search_batch_id
        FROM $TBAT_ATLAS_SEARCH_BATCH ASB
        JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
        ON (ABSB.atlas_search_batch_id = ASB.atlas_search_batch_id)
        WHERE ABSB.atlas_build_id = '$atlas_build_id'
        AND ABSB.record_status != 'D'
        AND ASB.record_status != 'D'
        order by ASB.atlas_search_batch_id;
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);

    foreach my $row (@rows)
    {
        my ($n, $atlas_search_batch_id) = @{$row};

            my $path = get_search_batch_directory(
                atlas_search_batch_id=>$atlas_search_batch_id);

            my $nspec = $sbeamsMOD->getNSpecFromFlatFiles (search_batch_path => $path);

            ## UPDATE atlas_search_batch record
            my %rowdata = (  
                n_searched_spectra => $nspec,
            );

            my $success = $sbeams->updateOrInsertRow(
                update=>1,
                table_name=>$TBAT_ATLAS_SEARCH_BATCH,
                rowdata_ref=>\%rowdata,
                PK => 'atlas_search_batch_id',
                PK_value => $atlas_search_batch_id,
                verbose=>$VERBOSE,
                testonly=>$TESTONLY,
            );
        
    }
}# end update_atlas_search_batch_records


#######################################################################
# getTPPVersion - get TPP version used in PeptideProphet scoring
# @param directory full path to search_batch directory
# @return string holding TPP version
#######################################################################
sub getTPPVersion
{
    my %args = @_;

    my $directory = $args{directory} or die
        "need path to search_batch directory file($!)";

    my $results_parser = new SearchResultsParametersParser();

    $results_parser->setSearch_batch_directory($directory);

    $results_parser->parse();

    my $TPP_version = $results_parser->getTPP_version();

    return $TPP_version;

}


#######################################################################
# getNSpecFromProteomics - get the number of spectra with P>=0 loaded 
#    into Proteomics for this search batch
# @param search_batch_id
# @return number of spectra with P>=0 loaded into Proteomics for search_batch
#######################################################################
sub getNSpecFromProteomics
{
    my %args = @_;

    my $search_batch_id = $args{search_batch_id} or die 
        "need search_batch_id ($!)";

    ## get nspec for P>=0.0
    my $sql = qq~
        SELECT count(*)
        FROM $TBPR_PROTEOMICS_EXPERIMENT PE, $TBPR_SEARCH_BATCH SB,
        $TBPR_FRACTION F, $TBPR_MSMS_SPECTRUM MSS
        WHERE SB.search_batch_id = $search_batch_id
        AND PE.experiment_id = SB.experiment_id
        AND PE.experiment_id = F.experiment_id
        AND F.fraction_id = MSS.fraction_id
        AND PE.record_status != 'D'
    ~;

    my @rows = $sbeams->selectOneColumn($sql) or die
        "Could not complete query (No spectra loaded?): $sql ($!)";

    my $n0 = $rows[0];

    return $n0;
}


#######################################################################
# getNSpecFromFlatFiles 
# @param search_batch_path
# @return number of spectra with P>=0 for search_batch
#######################################################################
sub getNSpecFromFlatFiles
{
    my %args = @_;

    my $search_batch_path = $args{search_batch_path} or die 
        "need search_batch_path ($!)";

	  my $pepXMLfile = $sbeamsMOD->findPepXMLFile( search_path => $search_batch_path,
		                                             preferred_names => [qw(interact-prob.xml interact-prob.pep.xml)] );

    my $n0;
    
#   print "    file: $pepXMLfile\n";

##  Need to make this a global var, as perl doesn't have nested
##  subroutines (i.e., can't include sub local_start_handler
##  right here and have %spectra be accessible to it

    %spectra = ();

    if (-e $pepXMLfile)
    {
        my $parser = new XML::Parser( );

        $parser->setHandlers(Start => \&local_start_handler);

        $parser->parsefile($pepXMLfile);
    }

    $n0 = keys %spectra;

    print "Num spectra searched: $n0\n" if ($TESTONLY);

    return $n0;
}


###################################################################
# local_start_handler -- local content handler for parsing of a
# pepxml to get number of spectra in interact-prob.xml file
###################################################################
sub local_start_handler
{
    my ($expat, $element, %attrs) = @_;

    ## need to get attribute spectrum from spectrum_query element,
    ## drop the last .\d from the string to get the spectrum name,
    ## then count the number of unique spectrum names in the file
    if ($element eq 'spectrum_query')
    {
        my $spectrum = $attrs{spectrum};

        ## drop the last . followed by number
        $spectrum =~ s/(.*)(\.)(\d)/$1/;

        $spectra{$spectrum} = $spectrum;
    }
}

