#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_atlas_build.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads a build of the PeptideAtlas into the
#               database from the build process data products files
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


use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $ATLAS_BUILD_ID 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TESTVARS $CHECKTABLES
             $sbeamsPROT
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
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --testonly             If set, rows in the database are not changed or added
  --testvars             If set, makes sure all vars are filled
  --check_tables         will not insert or update.  does a check of peptide_instance_sample

  --delete               Delete an atlas build (does not build an atlas).
  --purge                Delete child records in atlas build (retains parent atlas record).
  --load                 Build an atlas (can be used in conjunction with --purge).

  --organism_abbrev      Abbreviation of organism like Hs

  --atlas_build_name     Name of the atlas build (already entered by hand in
                         the atlas_build table) into which to load the data

 e.g.:  ./load_atlas_build.pl --atlas_build_name \'Human_P0.9_Ens26_NCBI35\' --organism_abbrev \'Hs\' --purge --load 

 e.g.: ./load_atlas_build.pl --atlas_build_name \'TestAtlas\' --delete
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "testvars","delete", "purge", "load", "check_tables",
        "atlas_build_name:s", "organism_abbrev:s"
    )) {

    die "\n$USAGE";

}


$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TESTONLY = $OPTIONS{"testonly"} || 0;

$TESTVARS = $OPTIONS{"testvars"} || 0;

$CHECKTABLES = $OPTIONS{"check_tables"} || 0;

$TESTONLY = 1 if ($CHECKTABLES);

if ($DEBUG) {

    print "Options settings:\n";

    print "  VERBOSE = $VERBOSE\n";

    print "  QUIET = $QUIET\n";

    print "  DEBUG = $DEBUG\n";

    print "  TESTONLY = $TESTONLY\n";

    print "  TESTVARS = $TESTVARS\n";

    print "  CHECKTABLES = $CHECKTABLES\n";

}
   
   
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
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless (
      $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
  );


  $sbeams->printPageHeader() unless ($QUIET);

  handleRequest();

  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  my %args = @_;

  ##### PROCESS COMMAND LINE OPTIONS AND RESTRICTIONS #####

  #### Set the command-line options
  my $del = $OPTIONS{"delete"} || '';

  my $purge = $OPTIONS{"purge"} || '';

  my $load = $OPTIONS{"load"} || '';

  my $organism_abbrev = $OPTIONS{"organism_abbrev"} || '';

  my $atlas_build_name = $OPTIONS{"atlas_build_name"} || '';


  #### Verify required parameters
  unless ($atlas_build_name) {
    print "\nERROR: You must specify an --atlas_build_name\n\n";
    die "\n$USAGE";
  }


  ## --delete with --load will not work
  if ($del && $load) {
      print "ERROR: --delete --load will not work.\n";
      print "  use: --purge --load instead\n\n";
      die "\n$USAGE";
      exit;
  }


  ## --delete with --purge will not work
  if ($del && $purge) {
      print "ERROR: select --delete or --purge, but not both\n";
      print "$USAGE";
      exit;
  }


  #### If there are any unresolved parameters, exit
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }


  ## get ATLAS_BUILD_ID:
  $ATLAS_BUILD_ID = get_atlas_build_id(atlas_build_name=>$atlas_build_name);


  ## handle --purge:
  if ($purge) {

       print "Removing child records in $atlas_build_name ($ATLAS_BUILD_ID): \n";

       removeAtlas(atlas_build_id => $ATLAS_BUILD_ID,
           keep_parent_record => 1);

  }#end --purge


  

  ## handle --load:
  if ($load) {

      loadAtlas( atlas_build_id=>$ATLAS_BUILD_ID,
          organism_abbrev => $organism_abbrev,
      );

  } ## end --load



  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }



  ## handle --delete:
  if ($del) {

     print "Removing atlas $atlas_build_name ($ATLAS_BUILD_ID) \n";

     removeAtlas(atlas_build_id => $ATLAS_BUILD_ID);

  }#end --delete



  if ($TESTONLY || $purge) {
      print "\a done\n";
  }



} # end handleRequest



###############################################################################
# get_atlas_build_id  --  get atlas build id
# @param atlas_build_name
# @return atlas_build_id
###############################################################################
sub get_atlas_build_id {

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
# removeAtlas -- removes atlas build records
#
#   has option --keep_parent to keep parent record (purge uses this feature)
###############################################################################
sub removeAtlas {
   my %args = @_;
   my $atlas_build_id = $args{'atlas_build_id'};
   my $keep_parent_record = $args{'keep_parent_record'} || 0;

   my $database_name = $DBPREFIX{PeptideAtlas};
   my $table_name = "atlas_build";
   my $full_table_name = "$database_name$table_name";

   my %table_child_relationship = (
      atlas_build => 'peptide_instance(C),atlas_build_sample(C),'.
        'atlas_build_search_batch(C),spectra_description_set(C)',

      peptide_instance => 'peptide_mapping(C),peptide_instance_sample(C),'.
        'modified_peptide_instance(C)',

      modified_peptide_instance => 'modified_peptide_instance_sample(C),',

      atlas_build_search_batch => 'atlas_search_batch(C)',

      atlas_search_batch => 'atlas_search_batch_parameter(C),'.
        'atlas_search_batch_parameter_set(C),'.
        'peptide_instance_search_batch(C),'.
        'modified_peptide_instance_search_batch(C)'
   );

   #my $TESTONLY = "0";
   my $VERBOSE = "1" unless ($VERBOSE);

   if ($keep_parent_record) {
      my $result = $sbeams->deleteRecordsAndChildren(
         table_name => 'atlas_build',
         table_child_relationship => \%table_child_relationship,
         delete_PKs => [ $atlas_build_id ],
         delete_batch => 1000,
         database => $database_name,
         verbose => $VERBOSE,
         testonly => $TESTONLY,
         keep_parent_record => 1,
      );
   } else {
      my $result = $sbeams->deleteRecordsAndChildren(
         table_name => 'atlas_build',
         table_child_relationship => \%table_child_relationship,
         delete_PKs => [ $atlas_build_id ],
         delete_batch => 1000,
         database => $database_name,
         verbose => $VERBOSE,
         testonly => $TESTONLY,
      );
   }
} # end removeAtlas



###############################################################################
# loadAtlas -- load an atlas
# @param atlas_build_id
# @param organism_abbrev
###############################################################################
sub loadAtlas {

    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'} or die
        " need atlas_build_id ($!)";

    my $organism_abbrev = $args{'organism_abbrev'} or die
        " need organism_abbrev ($!)";


    {
        ## check if atlas has peptide_instance entries (checking for 1 entry):
        my $sql =qq~
            SELECT *
            FROM $TBAT_PEPTIDE_INSTANCE
            WHERE atlas_build_id = '$atlas_build_id'
            ~;
    
        print "Checking whether peptide_instance records exist for atlas...\n"
            if ($TESTONLY);
    
        my @peptide_instance_array = $sbeams->selectOneColumn($sql);
    
        ## if has entries, tell user...atlas_build_name might be a user error
        if (@peptide_instance_array && $TESTONLY == 0) { 
            print "ERROR: Records already exist in atlas $\atlas_build name\n";
            print "To purge existing records and load new records\n";
            print "  use: --purge --load \n";
            print "$USAGE";
            return;
        }

    }


    my $builds_directory = get_atlas_build_directory (atlas_build_id =>
        $atlas_build_id);

    $builds_directory = "$builds_directory/";

    my $biosequence_set_id = get_biosequence_set_id (atlas_build_id =>
        $atlas_build_id);


    ## build atlas:
    print "Building atlas $atlas_build_id: \n";
  
    buildAtlas(atlas_build_id => $atlas_build_id,
               biosequence_set_id => $biosequence_set_id,
               source_dir => $builds_directory,
               organism_abbrev => $organism_abbrev,
    );


    print "\nFinished loading atlas \n";

}




###############################################################################
# buildAtlas -- populates PeptideAtlas records in requested atlas_build
###############################################################################
sub buildAtlas {

    print "building atlas...\n" if ($TESTONLY);

    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'} or die "need atlas_build_id ($!)";

    my $biosequence_set_id = $args{'biosequence_set_id'} or 
        die "need biosequence_set_id ($!)";

    my $source_dir = $args{'source_dir'} or 
        die "need source directory containing coordinate_mapping.txt etc. ($!)";

    my $organism_abbrev = $args{'organism_abbrev'} or 
        die "need organism_abbrev ($!)";
 

    ## hash with key = search_batch_id, value = $search_dir
    my %loading_sbid_searchdir_hash = getInfoFromExperimentsList(
        infile => "$source_dir../Experiments.list" );


#   ## get hash with key = atlas_search_batch_id, value = sample_id
#   ## and create [*sample] records and [*search_batch] records if they don't already exist
#   my %sample_id_hash = get_sample_id_hash(
#       atlas_build_id => $atlas_build_id,
#       loading_sbid_searchdir_hash_ref => \%loading_sbid_searchdir_hash,   
#       source_dir => $source_dir, 
#   );

    ## the content handler for loadFromPAxmlFile is using search_batch_id's 
    ## which are the proteomics search_batch_id's because that's what's 
    ## stored in the PAxml, so we need to send it
    ## a hash to look-up atlas_search_batch_id's using keys search_batch_id
    ## and it needs sample_ids
    my %proteomicsSBID_hash =  get_search_batch_and_sample_id_hash(
        atlas_build_id => $atlas_build_id,
        loading_sbid_searchdir_hash_ref => \%loading_sbid_searchdir_hash,
        source_dir => $source_dir,
    );

        
    #### Load from .PAxml file
    my $PAxmlfile = $source_dir . "APD_" . $organism_abbrev . "_all.PAxml";

    if (-e $PAxmlfile) 
    {
        loadFromPAxmlFile(
            infile => $PAxmlfile,
            sbid_asbid_sid_hash_ref => \%proteomicsSBID_hash,
            atlas_build_id => $ATLAS_BUILD_ID,
        );

    } else 
    {
        die("ERROR: Unable to find '$PAxmlfile' to load data from.");
    }


    ## set infile to coordinate mapping file
    my $mapping_file = "$source_dir/coordinate_mapping.txt";

    #### Update the build data already loaded with genomic coordinates
    readCoords_updateRecords_calcAttributes(
        infile => $mapping_file,
        atlas_build_id => $ATLAS_BUILD_ID,
        biosequence_set_id => $biosequence_set_id,
        organism_abbrev => $organism_abbrev
    );


}# end buildAtlas



###############################################################################
# get_search_batch_and_sample_id_hash --  get complex hash, and create all
# sample and search_batch records in the process
#
# @param atlas_build_id
# @param search_batch_hash_ref reference to hash with key = search_batch_id
# @return complex hash accessed as:
#     $hash{$proteomics_search_batch_id}->{atlas_search_batch_id}
#     $hash{$proteomics_search_batch_id}->{sample_id}
###############################################################################
sub get_search_batch_and_sample_id_hash
{
    my $METHOD='get_search_batch_and_sample_id_hash';

    my %loaded_sbid_asbid_sid_hash;

    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} or die("need atlas_build_id");

    my $source_dir = $args{source_dir} or die(" need source_dir ($!)");

    my $loading_sbid_searchdir_hash_ref = $args{loading_sbid_searchdir_hash_ref} 
       or die "need loading_sbid_searchdir_hash_ref ($)";

    ## hash with key = search_batch_id, value = $search_dir
    my %loading_sbid_searchdir_hash = %{$loading_sbid_searchdir_hash_ref};

    ## loading_sbid_searchdir_hash is used to get the sbid's to access
    ## the Proteomic records

    my $loading_sbid_list = get_string_list_of_keys(
        hash_ref => \%loading_sbid_searchdir_hash);


    #### Get complex hash of existing search_batches and their search dirs
    ## accessed as 
    ##   $existing_sb_hash{$sbid}->{proteomics_search_batch_id}
    ##   $existing_sb_hash{$sbid}->{atlas_search_batch_id}
    ##   $existing_sb_hash{$sbid}->{search_dir_path}}
    ##   $existing_sb_hash{$sbid}->{proteomics_experiment_tag}
    my %existing_sb_hash = get_sb_hash(
        search_batch_id_list => $loading_sbid_list );


    #### Get complex hash of existing search_batches and their search dirs
    ## if the atlas_build_search_batch record is filled
    ## accessed as $existing_absb_hash{$sbid}->{atlas_build_search_batch_id}
    ##             $existing_absb_hash{$sbid}->{atlas_search_batch_id}
    ##             $existing_absb_hash{$sbid}->{search_dir_path}
    my %existing_absb_hash = get_absb_hash(
        search_batch_id_list => $loading_sbid_list,
        atlas_build_id => $atlas_build_id );


    ## Get complex hash of existing sample information, 
    ## accessed as: 
    ##  $existing_samples_hash{$original_experiment_tag}->{original_experiment_tag}
    ##  $existing_samples_hash{$original_experiment_tag}->{sample_id}
    ##  $existing_samples_hash{$original_experiment_tag}->{sample_tag}
    my %existing_samples_hash = get_samples_hash();
    

    foreach my $sbid (keys %loading_sbid_searchdir_hash)
    {

        ## if [atlas_search_batch] record doesn't exist:
        if (! exists $existing_sb_hash{$sbid} )
        {
            my $search_batch_path = $loading_sbid_searchdir_hash{$sbid};

            my $atlas_search_batch_id = create_atlas_search_batch(
                search_batch_id => $sbid,
                search_batch_path => $search_batch_path
            );

            $existing_sb_hash{$sbid}->{search_dir_path} = $search_batch_path;

            my $atlas_build_search_batch_id = 
                create_atlas_build_search_batch(
                    search_batch_id => $sbid,
                    atlas_search_batch_id => $atlas_search_batch_id,
                    search_batch_path => $search_batch_path
                );

            my $successful = create_atlas_search_batch_parameter_recs(
                atlas_search_batch_id => $atlas_search_batch_id,
                search_batch_path => $search_batch_path
            );

            $existing_absb_hash{$sbid}->{atlas_build_search_batch_id}
                = $atlas_build_search_batch_id;

            $existing_absb_hash{$sbid}->{atlas_search_batch_id}
                = $atlas_search_batch_id;

            $existing_absb_hash{$sbid}->{search_dir_path}
                = $search_batch_path;

            $existing_sb_hash{$sbid}->{proteomics_search_batch_id} = 
                $sbid;

            $existing_sb_hash{$sbid}->{atlas_search_batch_id} = 
                $atlas_search_batch_id;

            $existing_sb_hash{$sbid}->{search_dir_path} = 
                $search_batch_path;

            my $et = getProteomicsExpTag( search_batch_id => $sbid );

            $existing_sb_hash{$sbid}->{proteomics_experiment_tag} =  $et;
               

        } else
        { ## else, the atlas_search_batch records exist, and just need to create
          ## the atlas_build_search_batch_record
            my $asbid = $existing_sb_hash{$sbid}->{atlas_search_batch_id};

            my $search_batch_path = $existing_sb_hash{$sbid}->{search_dir_path};

            my $atlas_build_search_batch_id =
                create_atlas_build_search_batch( 
                    search_batch_id => $sbid,
                    atlas_search_batch_id => $asbid,
                    search_batch_path => $search_batch_path);

            $existing_absb_hash{$sbid}->{atlas_search_batch_id}
                = $asbid;

            $existing_absb_hash{$sbid}->{atlas_build_search_batch_id}
                = $atlas_build_search_batch_id;

            $existing_absb_hash{$sbid}->{search_dir_path}
                = $search_batch_path;

        }

        my $exp_tag = $existing_sb_hash{$sbid}->{proteomics_experiment_tag};
 
        ## if a sample record doesn't exist, create one
        if (!exists $existing_samples_hash{$exp_tag} )
        {
            my $sample_id = insert_sample( 
                proteomics_experiment_tag => $exp_tag,
                search_batch_id => $sbid,
                atlas_build_id => $atlas_build_id );

            $existing_samples_hash{$exp_tag}->{original_experiment_tag}
                = $exp_tag;

            $existing_samples_hash{$exp_tag}->{sample_id} = $sample_id;

            $existing_samples_hash{$exp_tag}->{sample_tag} = $exp_tag;

        }

        my $proteomics_sbid = $existing_sb_hash{$sbid}->{proteomics_search_batch_id};

        my $atlas_sbid = $existing_absb_hash{$sbid}->{atlas_search_batch_id};

        my $atlas_sample_id = $existing_samples_hash{$exp_tag}->{sample_id};

        $loaded_sbid_asbid_sid_hash{$proteomics_sbid}->{atlas_search_batch_id}
            = $atlas_sbid;

        $loaded_sbid_asbid_sid_hash{$proteomics_sbid}->{sample_id} 
            = $atlas_sample_id;


        ## create a [spectra_description_set] record
        insert_spectra_description_set( 
            atlas_build_id => $atlas_build_id,
            sample_id => $existing_samples_hash{$exp_tag}->{sample_id},
            atlas_search_batch_id => 
                $existing_absb_hash{$sbid}->{atlas_search_batch_id},
            search_batch_dir_path => $existing_absb_hash{$sbid}->{search_dir_path}
        );
         

        my $atlas_build_sample_id = createAtlasBuildSampleLink(
            sample_id => $existing_samples_hash{$exp_tag}->{sample_id},
            atlas_build_id => $atlas_build_id,
        );


        ## update [atlas_build_search_batch] record with sample_id
        update_atlas_build_search_batch(
            sample_id => $existing_samples_hash{$exp_tag}->{sample_id},
            atlas_build_search_batch_id => 
                $existing_absb_hash{$sbid}->{atlas_build_search_batch_id},
        );

    }
##### xxxxxxx need to check this section carefully...worried that
####  mistakes may damage existing records...

    return %loaded_sbid_asbid_sid_hash;

}



###############################################################################
#  createAtlasBuildSampleLink -- create atlas build sample record
# @param sample_id
# @param atlas_build_id
# @return atlas_build_sample_id
###############################################################################
sub createAtlasBuildSampleLink {

    my $METHOD = "createAtlasBuildSampleLink";

    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id ($!)";

    my $atlas_build_id = $args{atlas_build_id} or 
        die "need atlas_build_id ($!)";


    ## Populate atlas_build_sample table
    my %rowdata = (   ##   atlas_build_sample    table attributes
        atlas_build_id => $atlas_build_id,
        sample_id => $sample_id,
    );


    my $atlas_build_sample_id = $sbeams->updateOrInsertRow(
        insert=>1,
        table_name=>$TBAT_ATLAS_BUILD_SAMPLE,
        rowdata_ref=>\%rowdata,
        PK => 'atlas_build_sample_id',
        return_PK => 1,
        add_audit_parameters => 1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    print "INFO[$METHOD]: created atlas_build_sample_id=".
        "$atlas_build_sample_id\n";

    return $atlas_build_sample_id;

} ## end createAtlasBuildSampleLink


###############################################################################
# get_sb_hash -- get complex hash of search_batch_id's and search directories
# accessed as:
#   $hash{$proteomics_search_batch_id}->{proteomics_search_batch_id}
#   $hash{$proteomics_search_batch_id}->{atlas_search_batch_id}
#   $hash{$proteomics_search_batch_id}->{search_dir_path}
#   $hash{$proteomics_search_batch_id}->{proteomics_experiment_tag}
#
# @param search_batch_id_list
# @return %hash
###############################################################################
sub get_sb_hash
{

    my %args = @_;

    my $sbid_list = $args{search_batch_id_list} or die 
        "need search_batch_id_list ($!)";

    my %hash;

    my $sql = qq~
        SELECT ASB.atlas_search_batch_id, ASB.proteomics_search_batch_id, 
        ASB.data_location, ASB.search_batch_subdir, PE.experiment_tag
        FROM $TBAT_ATLAS_SEARCH_BATCH ASB
            JOIN $TBPR_SEARCH_BATCH SB 
            ON (ASB.proteomics_search_batch_id = SB.search_batch_id)
            JOIN $TBPR_PROTEOMICS_EXPERIMENT PE
            ON (PE.experiment_id = SB.experiment_id)
        WHERE ASB.proteomics_search_batch_id IN ($sbid_list)
        AND ASB.record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);

    foreach my $row (@rows)
    {
        my ($asbid, $sbid, $dl, $sub_dir, $exp_tag) = @{$row};

        my $path = "$dl/$sub_dir";

        ## if doesn't exist, use global var for archive area
        unless (-e $path)
        {
            $path = $RAW_DATA_DIR{Proteomics} . "/path";
        }

        unless (-e $path)
        {
            print "[WARN] cannot locate $path for " .
            "atlas_search_batch w/ id=$asbid ";
        }

        $hash{$sbid}->{search_dir_path} = $path;

        $hash{$sbid}->{proteomics_search_batch_id} = $sbid;

        $hash{$sbid}->{atlas_search_batch_id} = $asbid;

        $hash{$sbid}->{proteomics_experiment_tag} = $exp_tag;

    }

    return %hash;

}

#######################################################################
# getProteomicsExpTag -- get proteomics experiment tag, given search
# batch id
#
# @param search_batch_id
# @return exp_tag
#######################################################################
sub getProteomicsExpTag
{

    my %args = @_;

    my $search_batch_id = $args{search_batch_id} or die
        "need search_batch_id ($!)";

    my $exp_tag;
    
    my $sql = qq~
        SELECT PE.experiment_tag, SB.search_batch_id
        FROM $TBPR_SEARCH_BATCH SB 
        JOIN $TBPR_PROTEOMICS_EXPERIMENT PE
        ON (PE.experiment_id = SB.experiment_id)
        WHERE SB.search_batch_id = '$search_batch_id'
        AND PE.record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql) or 
        print "[WARN] could not find proteomics experiment tag for "
        . "search_batch_id = $search_batch_id\n";

    foreach my $row (@rows)
    {
        my ($et, $sbid) = @{$row};

        $exp_tag = $et;

#       print "$et, $sbid\n";
    }

    return $exp_tag;

}

###############################################################################
# get_absb_hash -- get complex hash of existing search_batches and their search 
# dirs when atlas_build_search_batch record exists.  hash is accessed as:
#
#     $existing_absb_hash{$sbid}->{atlas_build_search_batch_id}
#     $existing_absb_hash{$sbid}->{atlas_search_batch_id}
#     $existing_absb_hash{$sbid}->{search_dir_path}
#
# @param search_batch_id_list
# @param atlas_build_id
###############################################################################
sub get_absb_hash
{

    my %args = @_;

    my $sbid_list = $args{search_batch_id_list} or die 
        "need search_batch_id_list ($!)";

    my $atlas_build_id = $args{atlas_build_id} or die 
        "need atlas_build_id ($!)";

    my %hash;

    my $sql = qq~
        SELECT ABSB.atlas_build_search_batch_id, ASB.atlas_search_batch_id,
        ASB.proteomics_search_batch_id,
        ASB.data_location, ASB.search_batch_subdir
        FROM $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
        INNER JOIN $TBAT_ATLAS_SEARCH_BATCH ASB
        ON (ABSB.atlas_search_batch_id = ASB.atlas_search_batch_id)
        WHERE ASB.proteomics_search_batch_id IN ($sbid_list)
        AND ABSB.atlas_build_id = '$atlas_build_id'
        AND ASB.record_status != 'D'
        AND ABSB.record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);

    foreach my $row (@rows)
    {
        my ($absbid, $asbid, $sbid, $dl, $sub_dir) = @{$row};

        my $path = "$dl/$sub_dir";

        ## if doesn't exist, use global var for archive area
        unless (-e $path)
        {
            $path = $RAW_DATA_DIR{Proteomics} . "/path";
        }

        unless (-e $path)
        {
            print "[WARN] cannot locate $path for " .
            "atlas_build_search_batch w/ id=$absbid ";
        }

        $hash{$sbid}->{atlas_build_search_batch_id} = $absbid;

        $hash{$sbid}->{atlas_search_batch_id} = $asbid;

        $hash{$sbid}->{search_dir_path} = $path;

    }

    return %hash;

}


#######################################################################
#  get_samples_hash - get complex hash of sample information
#  accessed as:
#  $hash{$original_experiment_tag}->{original_experiment_tag}
#  $hash{$original_experiment_tag}->{sample_id}
#  $hash{$original_experiment_tag}->{sample_tag}
#
#  @return complex hash
#######################################################################
sub get_samples_hash
{

    ## get hash of existing samples and their sample_tags
    my %hash;

    my $sql = qq~
        SELECT sample_id, sample_tag, original_experiment_tag
        FROM $TBAT_SAMPLE
        WHERE record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);

    foreach my $row (@rows)
    {
        my ($sid, $st, $et) = @{$row};
    
        $hash{$et}->{original_experiment_tag} = $et;
    
        $hash{$et}->{sample_id} = $sid;
    
        $hash{$et}->{sample_tag} = $st;
    }

    return %hash;

}


#######################################################################
# get_string_list_of_keys -- get string list of keys
# @param hash_ref 
# @return string of a list of the hash keys, separated by commas
#######################################################################
sub get_string_list_of_keys
{

    my %args=@_;

    my $hash_ref = $args{hash_ref} or die "need hash_ref";

    my %hash = %{$hash_ref};

    my $str_list;

    foreach my $key ( keys %hash)
    {
        if ($str_list eq "")
        {
            $str_list = "$key";
        } else
        {
             $str_list = "$str_list,$key";
        }
    }

    return $str_list;

}

#######################################################################
# create_atlas_search_batch -- create atlas_search_batch record
# using assumption that atlas_search_batch_id should be equal to
# the Proteomics search_batch_id
# @param search_batch_id  search batch id to look-up Proteomics info
# @param search_batch_path absolute path to search_batch information
# @return atlas_search_batch_id
#######################################################################
sub create_atlas_search_batch
{

    my %args = @_;

    my $sbid = $args{search_batch_id} or die "need search_batch_id ($!)";

    my $search_batch_path = $args{search_batch_path}
        or die "need search_batch_path ($!)";

    my $atlas_search_batch_id;


    my $nspec = getNSpecFromProteomics( search_batch_id => $sbid );

    my $search_batch_subdir =  $search_batch_path;

    ##trim off all except last directory
    $search_batch_subdir =~ s/^(.+)\/(.+)/$2/gi;

    my $experiment_dir = $search_batch_path;

    ##trim off all except second to last directory
    $experiment_dir =~ s/^(.+)\/(.+)\/(.+)/$2/gi;

    my $TPP_version = getTPPVersion( directory => $search_batch_path);

    ## attributes for atlas_search_batch_record
    my %rowdata = (             ##  atlas_search_batch
        proteomics_search_batch_id => $sbid,
        n_searched_spectra => $nspec,
        data_location => $experiment_dir,
        search_batch_subdir => $search_batch_subdir,
        TPP_version => $TPP_version,
    );

    my $atlas_search_batch_id = $sbeams->updateOrInsertRow(
        insert=>1,
        table_name=>$TBAT_ATLAS_SEARCH_BATCH,
        rowdata_ref=>\%rowdata,
        PK => 'atlas_search_batch_id',
        return_PK => 1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    return $atlas_search_batch_id;

}


#######################################################################
# create_atlas_build_search_batch -- create atlas_build_search_batch record
# @param search_batch_id  search batch id to look-up Proteomics info
# @param atlas_search_batch_id  atlas_search_batch_id
# @param search_batch_path absolute path to search_batch information
# @return atlas_build_search_batch_id
#######################################################################
sub create_atlas_build_search_batch
{

    my %args = @_;

    my $sbid = $args{search_batch_id} or die "need search_batch_id ($!)";

    my $search_batch_path = $args{search_batch_path}
        or die "need search_batch_path ($!)";

    my $atlas_search_batch_id = $args{atlas_search_batch_id}
        or die "need atlas_search_batch_id ($!)";

    my $nspec = getNSpecFromProteomics( search_batch_id=>$sbid);

    my $search_batch_subdir =  $search_batch_path;

    ##trim off all except last directory
    $search_batch_subdir =~ s/^(.+)\/(.+)/$2/gi;


    ## attributes for atlas_build_search_batch_record
    my %rowdata = (             ##  atlas_search_batch
        n_searched_spectra => $nspec,
        data_path => $search_batch_subdir,
        atlas_search_batch_id => $atlas_search_batch_id,
    );

    my $atlas_build_search_batch_id = $sbeams->updateOrInsertRow(
        insert => 1,
        table_name => $TBAT_ATLAS_BUILD_SEARCH_BATCH,
        rowdata_ref => \%rowdata,
        PK => 'atlas_build_search_batch_id',
        return_PK => 1,
        verbose => $VERBOSE,
        testonly => $TESTONLY,
    );

    return $atlas_build_search_batch_id;

}

#######################################################################
# update_atlas_build_search_batch -- update atlas_build_search_batch record
# with sample_id
# @param sample_id
#######################################################################
sub update_atlas_build_search_batch
{

    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id ($!)";

    my $atlas_build_search_batch_id = $args{atlas_build_search_batch_id} 
        or die "need atlas_build_search_batch_id ($!)";

    ## attributes for atlas_build_search_batch_record
    my %rowdata = (             ##  atlas_search_batch
        sample_id => $sample_id,
    );

    $sbeams->updateOrInsertRow(
        update => 1,
        table_name => $TBAT_ATLAS_BUILD_SEARCH_BATCH,
        rowdata_ref => \%rowdata,
        PK => 'atlas_build_search_batch_id',
        PK_value => $atlas_build_search_batch_id,
        verbose => $VERBOSE,
        testonly => $TESTONLY,
    );

}


#######################################################################
# create_atlas_search_batch_parameter_recs - create records for
# atlas_search_batch_parameter_set and atlas_search_batch_parameter
#
# @param $atlas_search_batch_id
# @param $search_batch_path absolute path to search_batch directory
# @return successful returns 1 for "true" 
#######################################################################
sub create_atlas_search_batch_parameter_recs
{
    my %args = @_;

    my $atlas_search_batch_id  = $args{atlas_search_batch_id}
        or die "need atlas_search_batch_id ($!)";

    my $search_batch_path = $args{search_batch_path}
        or die "need search_batch_path ($!)";


    my ($peptide_mass_tolerance, $peptide_ion_tolerance, $peptide_ion_tolerance,
        $enzyme, $num_enzyme_termini);


    #### Assume the location of the search parameters file
    my $infile = "$search_batch_path/sequest.params";

    #### Complain and return if the file does not exist
    if ( ! -e "$infile" ) 
    {
        #### Also try the parent directory
        $infile = "$search_batch_path/../sequest.params";

        if ( ! -e "$infile" ) 
        {
            print "ERROR: Unable to find sequest parameter file: '$infile'\n";
            return;
        }

    }

    ## if can't find readParamsFile, instantiate Protoeomics module 
    ## $sbeamsPROT = SBEAMS::Proteomics->new();
    ## $sbeamsPROT->setSBEAMS($sbeams);

    #### Read in the search parameters file
    my $result = $sbeamsPROT->readParamsFile(inputfile => "$infile");

    unless ($result) 
    {
        print "ERROR: Unable to read sequest parameter file: '$infile'\n";

        return;
    }

    #### Loop over each returned row
    my ($key,$value,$tmp);

    my $counter = 0;

    ## store returned results from sequest.params as key value pair records in
    ## ATLAS_SEARCH_BATCH_PARAMETER table
    foreach $key (@{${$result}{keys_in_order}}) 
    {

        #### Define the data for this row
        my %rowdata;
        $rowdata{atlas_search_batch_id} = $atlas_search_batch_id;
        $rowdata{key_order} = $counter;
        $rowdata{parameter_key} = $key;
        $rowdata{parameter_value} = ${$result}{parameters}->{$key};

        #### INSERT it
        $sbeams->insert_update_row(
            insert => 1,
            table_name => $TBAT_ATLAS_SEARCH_BATCH_PARAMETER,
            rowdata_ref => \%rowdata,
            verbose => $VERBOSE,
            testonly => $TESTONLY,
        );

        $counter++;

        ## pick up params needed for ATLAS_SEARCH_BATCH_PARAMETER_SET
        if ($key eq "peptide_mass_tolerance")
        {
            $peptide_mass_tolerance = $rowdata{parameter_value};
        }

        if ($key eq "fragment_ion_tolerance")
        {
            $peptide_ion_tolerance = $rowdata{parameter_value};
        }

        if ($key eq "enzyme_number")
        {
            $enzyme = $rowdata{parameter_value};
        }

        if ($key eq "NumEnzymeTermini")
        {
            $num_enzyme_termini = $rowdata{parameter_value};
        }

    }

    my %rowdata = ( ##   ATLAS_SEARCH_BATCH_PARAMETER_SET attributes
        peptide_mass_tolerance => $peptide_mass_tolerance,
        peptide_ion_tolerance => $peptide_ion_tolerance,
        enzyme => $enzyme,
        num_enzyme_termini => $num_enzyme_termini,
    );


    #### INSERT it
    $sbeams->insert_update_row(
        insert => 1,
        table_name => $TBAT_ATLAS_SEARCH_BATCH_PARAMETER_SET,
        rowdata_ref => \%rowdata,
        verbose => $VERBOSE,
        testonly => $TESTONLY,
    );

    return 1;

}


###############################################################################
#  insert_sample -- get or create sample record
#     with minimum info and some default settings 
#     [ specifically: is_public='N', project_id='476' ]
# @param search_batch_id
# @param atlas_build_id
# @param proteomics_experiment_tag
###############################################################################
sub insert_sample
{

    my $METHOD='insert_sample';

    my %args = @_;

    my $sb_id = $args{search_batch_id} or die "need search_batch_id ($!)";

    my $atlas_build_id = $args{atlas_build_id} or
        die "need atlas_build_id ($!)";

    my $experiment_tag = $args{proteomics_experiment_tag} or
        die "need proteomics_experiment_tag($!)";

    my $experiment_name;

    ## get experiment_tag, experiment_name, $TB_ORGANISM.organism_name
    my $sql = qq~
        SELECT distinct SB.search_batch_id, PE.experiment_name
        FROM $TBPR_PROTEOMICS_EXPERIMENT PE
        JOIN $TBPR_SEARCH_BATCH SB
        ON ( PE.experiment_id = SB.experiment_id)
        WHERE SB.search_batch_id = '$sb_id'
        AND PE.record_status != 'D'
    ~;
#       AND PE.experiment_tag = '$experiment_tag'

    my @rows = $sbeams->selectSeveralColumns($sql) or die
        "Could not find proteomics experiment record for ".
        " search batch id $sb_id \n$sql\n ($!)";

    foreach my $row (@rows)
    {
        ## xxxxxxx might want to check that PE.experiment_tag = $experiment_tag too
        my ($sbid, $exp_name) = @{$row};

        $experiment_name = $exp_name;
    }


    ## assume is_public = 'N' and project_id='476' for development PA
    my %rowdata = ( ##   sample      some of the table attributes:
        search_batch_id => $sb_id,
        sample_tag => $experiment_tag,
        original_experiment_tag => $experiment_tag,
        sample_title => $experiment_name,
        sample_description => $experiment_name,
        is_public => 'N',
        project_id => '476',
    );


    ## create a sample record:
    my $sample_id = $sbeams->updateOrInsertRow(
        table_name=>$TBAT_SAMPLE,
        insert=>1,
        rowdata_ref=>\%rowdata,
        PK => 'sample_id',
        return_PK=>1,
        add_audit_parameters => 1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    return $sample_id;

} ## end insert_sample



#######################################################################
#  get_peptide_accession_id_hash -- get hash 
#      key = peptide accession
#      value = peptide_id
#######################################################################
sub get_peptide_accession_id_hash {

    #### Get the current list of peptides in the peptide table
    my $sql = qq~
        SELECT peptide_accession,peptide_id
        FROM $TBAT_PEPTIDE
        ~;

    my %peptide_ids_hash = $sbeams->selectTwoColumnHash($sql);

    return %peptide_ids_hash;

}

#######################################################################
# getInfoFromExperimentsList - get hash of experiment list contents
# @param infile full path to Experiments.list file
# @return hash with key = search_batch_id,
#                 value = full path to search dir
#######################################################################
sub getInfoFromExperimentsList
{

    my $METHOD = "getInfoFromExperimentsList";

    my %args = @_;

    my $infile = $args{infile} or die
        "need path to Experiments.list file($!)";

    my %hash;

    open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

    while (my $line = <INFILE>) 
    {

        chomp($line);

        if ($line =~ /^(\d+)(\s+)(.+)/) 
        {
            $hash{$1} = $3;

        }

    }

    close(INFILE) or die "Cannot close $infile";

    return %hash;

}


#######################################################################
# get_peptide_accession_instance_id_hash -- get hash
#     key = peptide accession
#     value = peptide_instance_id
#######################################################################
sub get_peptide_accession_instance_id_hash {

    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} or die
        "need atlas build id ($!)";

    my %hash;

    my $sql = qq~
        SELECT P.peptide_accession, PEPI.peptide_instance_id
        FROM $TBAT_PEPTIDE_INSTANCE PEPI
        JOIN $TBAT_PEPTIDE P ON (P.peptide_id = PEPI.peptide_id)
        WHERE PEPI.atlas_build_id = $atlas_build_id
        ~;

    %hash = $sbeams->selectTwoColumnHash($sql) or die
        "unable to execute statement:\n$sql\n($!)";

    return %hash;

}


#######################################################################
# get_peptide_accession_sequence_hash - get hash with key = peptide
#    accession, value = peptide sequence
#######################################################################
sub get_peptide_accession_sequence_hash
{

    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} or die
        "need atlas build id ($!)";

    my %hash;

    my $sql = qq~
        SELECT P.peptide_accession, P.peptide_sequence
        FROM $TBAT_PEPTIDE_INSTANCE PEPI
        JOIN $TBAT_PEPTIDE P ON (P.peptide_id = PEPI.peptide_id)
        WHERE PEPI.atlas_build_id = $atlas_build_id
        ~;

    %hash = $sbeams->selectTwoColumnHash($sql);

    return %hash;

}


#######################################################################
#  get_biosequence_name_id_hash -- get hash
#      key = biosequence_name
#      value = biosequence_id
# @param biosequence_set_id
#######################################################################
sub get_biosequence_name_id_hash {

    my %args = @_;

    my $biosequence_set_id = $args{'biosequence_set_id'};

    my %hash;


    #### Get the current biosequences in this set
    my $sql = qq~
        SELECT biosequence_name,biosequence_id
        FROM $TBAT_BIOSEQUENCE
        WHERE biosequence_set_id = '$biosequence_set_id'
    ~;


    %hash = $sbeams->selectTwoColumnHash($sql) or
        die "unable to get biosequence name and id from biosequence".
        " set $biosequence_set_id ($!)";


    ## creates hash with key=biosequence_name, value=biosequence_id
    return %hash;

}

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

    my $METHOD = "getTPPVersion";

    ## get pepXML file
    my $infile = "$directory/interact-prob.xml";

    unless(-e $infile)
    {
        print "[WARN] could not find $infile\n";

        $infile = "$directory/interact.xml";
    }
    unless(-e $infile)
    {
        die "could not find $infile either\n";
    }

    open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

    ## example entry:
    ## <peptideprophet_summary version="PeptideProphet v3.0 April 1, 2004 (TPP v2.6 Quantitative Precipitation Forecast rev.2, Build 200512211154)" author="AKeller@ISB" min_prob="0.00" options=" MINPROB=0" est_tot_num_correct="12527.0">

    my $str1 = '\<peptideprophet_summary version=\"PeptideProphet';

    my $versionString;

    while (my $line = <INFILE>) 
    {
        chomp($line);

        if ($line =~ /^($str1)(.+)(\()(TPP\sv)(\d\.\d+\.*\d*)\s(.+)(\))(.+)/)
        {
            $versionString = $5;

            last;
        }

    }

    close(INFILE) or die "Cannot close $infile";

    if ($versionString eq "")
    {
        print "[WARN] could not find TPP version in $infile\n";

    }

    return $versionString;

}

#######################################################################
# insert_spectra_description_set - insert or update a record
#    for [spectra_description_set] table.  
# @param atlas_build_id
# @param sample_id 
# @param atlas_search_batch_id
#######################################################################
sub insert_spectra_description_set
{
    my $METHOD = "insert_spectra_description_set";

    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} or die
        "need atlas_build_id ($!)";

    my $sample_id = $args{sample_id} or die
        "need sample_id ($!)";

    my $atlas_search_batch_id = $args{atlas_search_batch_id} or die
        "need atlas_search_batch_id ($!)";

    my $search_batch_dir_path = $args{search_batch_dir_path} or die
        "need search_batch_dir_path ($!)";

    ## There could be [spectra_description_set records for this
    ## sample_id and atlas_search_batch
    my $sql = qq~
        SELECT distinct sample_id, atlas_search_batch_id, 
        instrument_model_id, instrument_model_name, conversion_software_name, 
        conversion_software_version, mzXML_schema
        FROM $TBAT_SPECTRA_DESCRIPTION_SET
        WHERE atlas_search_batch_id = '$atlas_search_batch_id'
        AND sample_id = '$sample_id'
        AND record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);

    my ($instrument_model_id, $conversion_software_name, 
    $instrument_model_id, $instrument_model_name, $conversion_software_name,
    $conversion_software_version, $mzXML_schema);


    ## If record exists, use attributes to create new record afterwards
    if ($#rows > -1)
    {

        foreach my $row (@rows)
        {
            my ($sid, $asbid, $imid, $imn, $csn, $csv, $ms) = @{$row}; 

            $instrument_model_id = $imid;

            $instrument_model_name = $imn;

            $conversion_software_name = $csn;

            $conversion_software_version = $csv;

            $mzXML_schema = $ms;

        }

    } else
    { 

        ## read experiment's pepXML file to get an mzXML file name
        my $singleMzXMLFileName = getAnMzXMLFileName( search_batch_dir_path => $search_batch_dir_path);


        #### read the mzXML file to get needed attributes... could make a content hndler for this, 
        #### but only need the first dozen or so lines of file, and the mzXML files are huge...
        my $infile = $singleMzXMLFileName;

        # $instrument_model_id         ==> <msManufacturer category="msManufacturer" value="ThermoFinnigan"/>
        #                                  <msModel category="msModel" value="LCQ Deca"/>
        # $conversion_software_name    ==> <software type="conversion"
        #                                       name="Thermo2mzXML"
        #                                       version="1"/>
        # $conversion_software_version ==>
        # $mzXML_schema                ==>  xsi:schemaLocation="http://sashimi.sourceforge.net/schema_revision/mzXML_2.0 http://sashimi.sourceforge.net/schema_revision/mzXML_2.0/mzXML_idx_2.0.xsd">

        open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

        while (my $line = <INFILE>)
        {
            chomp($line);

            ## recent schema:
            if ($line =~ /.+schemaLocation=\".+\/(.+)\/schema_revision\/(.+)\/(.+\.xsd)\">/)
            {
                $mzXML_schema = $2;
            }

            ## former MsXML schema:
            ## xsi:schemaLocation="http://sashimi.sourceforge.net/schema/ http://sashimi.sourceforge.net/schema/MsXML.xsd
            if ($line =~ /.+schemaLocation=\".+\/(.+)\/schema\/(.+)\.xsd\"/ )
            {
                $mzXML_schema = $2;
            }

            if ($line =~ /.+\<msManufacturer\scategory=\".+\"\svalue=\"(.+)\"\/\>/)
            {
                $instrument_model_name = $1;
            }
            if ($line =~ /.+\<msModel\scategory=\".+\"\svalue=\"(.+)\"\/\>/)
            {
                $instrument_model_name = $instrument_model_name . " $1";
            }

            ## former MsXML schema:
            if ($line =~ /.+\<instrument\smanufacturer=\"(.+)\"/ )
            {
                $instrument_model_name = $1;

                ## read the next line, and get model name
                $line = <INFILE>;
                chomp($line);
                $line =~ /.+\<instrument\smanufacturer=\"(.+)\"/;

                $instrument_model_name = $instrument_model_name . " $1";

            }

            if ($line =~ /.+\<software\stype=\"conversion(.+)/)
            {
                $line = <INFILE>;

                chomp($line);

                if ($line =~ /.+name=\"(.+)\"/)
                {
                    $conversion_software_name = $1;
                } else
                {
                    print "[WARN] please edit parser to pick up software attributes ($!)";
                }

                $line = <INFILE>;

                chomp($line);

                if ($line =~ /.+version=\"(.+)\"/)
                {
                    $conversion_software_version = $1;
                }

                last; ## done
            }

        }

        close(INFILE) or die "Cannot close $infile";

        if ( ($mzXML_schema eq "") || ($instrument_model_name eq "")
        || ($conversion_software_name eq "") || 
        ($conversion_software_version eq "") )
        {
            print "[WARN] please edit parser to pick up spectra attributes for $infile ($!)";
        }

    }


    ## insert [spectra_description_set] record
    my %rowdata = (             
        atlas_build_id => $atlas_build_id,
        sample_id => $sample_id,
        atlas_search_batch_id => $atlas_search_batch_id,
        instrument_model_id  => $instrument_model_id,
        instrument_model_name  => $instrument_model_name,
        conversion_software_name => $conversion_software_name,
        conversion_software_version => $conversion_software_version,
        mzXML_schema => $mzXML_schema
    );

    my $spectra_description_set_id = $sbeams->updateOrInsertRow(
        insert=>1,
        table_name=>$TBAT_SPECTRA_DESCRIPTION_SET,
        rowdata_ref=>\%rowdata,
        PK => 'spectra_description_id',
        return_PK => 1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

}


#######################################################################
# getNSpecFromProteomics
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
    ~;

    my @rows = $sbeams->selectOneColumn($sql) or die
        "Could not complete query (No spectra loaded?): $sql ($!)";

    my $n0 = $rows[0];

    return $n0;

}



#######################################################################
# readCoords_updateRecords_calcAttributes -- read coordinate mapping
# file, calculate mapping attributes, update peptide_instance
# record, and create peptide_mapping records 
# @infile
# @atlas_build_id 
# @biosequence_set_id 
# @organism_abbrev 
#######################################################################
sub readCoords_updateRecords_calcAttributes {

    my %args = @_;

    my $infile = $args{'infile'} or die "need infile ($!)";

    my $proteomicsSBID_hash_ref = $args{'proteomicsSBID_hash_ref'} or die
        " need proteomicsSBID_hash_ref ($!)";

    my %proteomicsSBID_hash = %{$proteomicsSBID_hash_ref};

    my $atlas_build_id = $args{atlas_build_id} or die "need atlas_build_id ($!)";

    my $biosequence_set_id = $args{biosequence_set_id} or die 
        "need biosequence_set_id ($!)";

    my $organism_abbrev = $args{organism_abbrev} or die
        "need organism_abbrev ($!)";

    ## get hash with key=peptide_accession, value=peptide_id
    my %peptides = get_peptide_accession_id_hash();
        

    ## get hash with key=biosequence_name, value=biosequence_id
    my %biosequence_ids = get_biosequence_name_id_hash(
        biosequence_set_id => $biosequence_set_id);


    my (@peptide_accession, @biosequence_name);

    my (@chromosome, @strand, @start_in_chromosome, @end_in_chromosome);

    my (@n_protein_mappings, @n_genome_locations, @is_exon_spanning);

    my (@start_in_biosequence, @end_in_biosequence);


    ## hash with key = $peptide_accession[$ind], 
    ##           value = string of array indices holding given peptide_accession
    my %index_hash; 
                   

    open(INFILE, $infile) or die "ERROR: Unable to open for reading $infile ($!)";
 
    #### READ  coordinate_mapping.txt  ##############
    print "\nReading $infile\n";

    my $line;


    ## hash with key = peptide_accession, value = peptide_sequence
    my %peptideAccession_peptideSequence = get_peptide_accession_sequence_hash( 
        atlas_build_id => $atlas_build_id );

    #### Load information from the coordinate mapping file:
    my $ind=0;

    while ($line = <INFILE>) {

        chomp($line);

        my @columns = split(/\t/,$line);
  
        my $pep_acc = $columns[0];

        push(@peptide_accession, $columns[0]);

        push(@biosequence_name, $columns[2]);

        push(@start_in_biosequence, $columns[5]);

        push(@end_in_biosequence, $columns[6]);

        my $tmp_chromosome = $columns[8];

        ## parsing for chromosome:   this is set for Ens 21 and 22 notation...
        if ($tmp_chromosome =~ /^(chromosome:)(NCBI.+:)(.+)(:.+:.+:.+)/ ) {
            $tmp_chromosome = $3;
        }
        if ($tmp_chromosome =~ /^(chromosome:)(DROM.+:)(.+)(:.+:.+:.+)/ ) {
            $tmp_chromosome = $3;
        }
        ## and for yeast:
        if ($tmp_chromosome =~ /^S/) {
            $tmp_chromosome = $columns[12];
        }

        ### For Ens 32 and on, we are storing chromsome in column 8, so no need for parsing
        #if ( ($tmp_chromosome =~ /^(\d+)$/) || ($tmp_chromosome =~ /^((X)|(Y))$/) ) {
        #    $tmp_chromosome = $tmp_chromosome;
        #}
        ### Additional match for the novel chromosomes such as 17_NT_079568 X_NT_078116
        #if ( ($tmp =~ /^(\d+)_NT_(\d+)$/) || ($tmp_chromosome =~ /^((X)|(Y))_NT_(\d+)$/) ) {
        #    $tmp_chromosome = $tmp_chromosome;
        #}


        push(@chromosome, $tmp_chromosome);

        push(@strand,$columns[9]);

        push(@start_in_chromosome,$columns[10]);
 
        push(@end_in_chromosome,$columns[11]);

 
        ## hash with
        ## keys =  pep_accession
        ## values = the array indices (of the arrays above, holding pep_accession)
        if ( exists $index_hash{$pep_acc} ) {
 
            $index_hash{$pep_acc} = 
                join " ", $index_hash{$pep_acc}, $ind;

        } else {

           $index_hash{$pep_acc} = $ind;

        }


        push(@n_protein_mappings, 1);  ##unless replaced in next section

        push(@n_genome_locations, 1);  ##unless replaced in next section

        push(@is_exon_spanning, 'N');  ##unless replaced in next section

        $ind++;

    }   ## END reading coordinate mapping file

    close(INFILE) or die "Cannot close $infile ($!)";

    print "\nFinished reading .../coordinate_mapping.txt\n";



    if ($TESTONLY) { 

        foreach my $tmp_ind_str (values ( %index_hash ) ) {

            my @tmp_ind_array = split(" ", $tmp_ind_str);
 
            my %unique_protein_hash;

            my %unique_coord_hash;
 
            for (my $ii = 0; $ii <= $#tmp_ind_array; $ii++) {
 
               my $i_ind=$tmp_ind_array[$ii];
 
                reset %unique_protein_hash; ## necessary?
                reset %unique_coord_hash;   ## necessary?
 
                ##what is key of index_hash where value = $tmp_ind_str  ?
                ##is that key = $pep_accession[$i_ind]  ?
                my %inverse_index_hash = reverse %index_hash;
 
                die "check accession numbers in index_hash" 
                    if ($inverse_index_hash{$tmp_ind_str} != $peptide_accession[$i_ind]); 

            }
        }
    } ## end TEST
 

    ## n_protein_mappings -- Number of distinct proteins that a peptide maps to
    ## n_genome_locations -- Number of mappings to Genome where protein is not the same
    ##                       (in other words, counts span over exons only once)
    ## is_exon_spanning   -- Whether a peptide has been mapped to a protein more than
    ##                       once (with different chromosomal coordinates)...each coord
    ##                       set should be shorter in length than the entire sequence...
    ##                       This avoids counting repeat occurrences of an entire
    ##                       peptide in a protein or ORF.

    ## For each peptide:
    ## protein_mappings_hash:  key = protein, value="$chrom:$start:$end"
    ## --> n_protein_mappings = keys ( %protein_mappings_hash )
    ##
    ## --> n_genome_locations =  keys of reverse protein_mappings_hash
    ##
    ## is_exon_spanning_hash:  key = protein,
    ##                         value = 'Y' if (  (diff_coords + 1) != (seq_length*3);

    print "\nCalculating n_protein_mappings, n_genome_locations, and is_exon_spanning\n";

    ## looping through a peptide's array indices to calculate these:
    foreach my $tmp_ind_str (values ( %index_hash ) ) {  #key = peptide_accession

        my @tmp_ind_array = split(" ", $tmp_ind_str);
 
        my (%protein_mappings_hash, %is_exon_spanning_hash);

        ## will skip 1st key = peptide in hashes below, and instead, 
        ## reset hash for each peptide
        reset %protein_mappings_hash; ## necessary?  above declaration should have cleared these?
        reset %is_exon_spanning_hash;

        my $peptide = $peptide_accession[$tmp_ind_array[0]];
        my $protein;

        ## initialize to 'N'
        $is_exon_spanning_hash{$protein} = 'N';


        ## for each index:
        for (my $ii = 0; $ii <= $#tmp_ind_array; $ii++) {

            my $i_ind=$tmp_ind_array[$ii];

            $protein = $biosequence_name[$i_ind];

            my $chrom = $chromosome[$i_ind];

            my $start = $start_in_chromosome[$i_ind];

            my $end = $end_in_chromosome[$i_ind];

            my $coord_str = "$chrom:$start:$end";

          
            $protein_mappings_hash{$protein} = $coord_str;


            my $diff_coords = abs($start - $end );
 
            my $seq_length = 
                length($peptideAccession_peptideSequence{$peptide});

            ## If entire sequence fits between coordinates, the protein has
            ## redundant sequences.  If the sequence doesn't fit between
            ## coordinates, it's exon spanning:
            if (  ($diff_coords + 1) != ($seq_length * 3) ) {

                $is_exon_spanning_hash{$protein} = 'Y';

                ## update larger scope variable too:
                $is_exon_spanning[$i_ind] = 'Y';

            }

        } 

       ## Another iteration through indices to count n_genome_locations
       ## want the number of unique coord strings, corrected to count is_exon_spanning peptides as only 1 addition.
       my %inverse_protein_hash = reverse %protein_mappings_hash;

       my $pep_n_genome_locations = keys( %inverse_protein_hash);


       my $pep_n_protein_mappings = keys( %protein_mappings_hash );


       ## need to assign values to array members now:
       foreach my $tmpind (@tmp_ind_array) {

           $protein = $biosequence_name[$tmpind];


           $n_protein_mappings[$tmpind] = $pep_n_protein_mappings;

           $n_genome_locations[$tmpind] = $pep_n_genome_locations;

       }
     
   } ## end calculate n_genome_locations, n_protein_mappings and is_exon_spanning loop
 
   ### ABOVE modeled following rules:
   ##
   ## PAp00011291  9       ENSP00000295561 ... 24323279        24323305
   ## PAp00011291  9       ENSP00000336741 ... 24323279        24323305
   ## ---> n_genome_locations = 1 for both
   ## ---> n_protein_mappings = 2 for both
   ## ---> is_exon_spanning   = n for both
   ##
   ## PAp00004221  13      ENSP00000317473 ... 75675871        75675882
   ## PAp00004221  13      ENSP00000317473 ... 75677437        75677463
   ## ---> n_genome_locations = 1 for both
   ## ---> n_protein_mappings = 1 for both
   ## ---> is_exon_spanning   = y for both
   ## 
   ## PAp00004290  16      ENSP00000306222 ...   1151627         1151633
   ## PAp00004290  16      ENSP00000306222 ...   1151067         1151107
   ## PAp00004290  16      ENSP00000281456 ... 186762937       186762943
   ## PAp00004290  16      ENSP00000281456 ... 186763858       186763898
   ## ---> n_genome_locations = 2 for all
   ## ---> n_protein_mappings = 2 for both
   ## ---> is_exon_spanning   = y for all

   ## testing match to above rules:
   ## the above cases have P=1.0, and tested for Ens build 22 - 26
   if ($TESTONLY && ($organism_abbrev eq 'Hs') ) {  
       for (my $ii = 0; $ii <= $#peptide_accession; $ii++) {
           my @test_pep = ("PAp00011291", "PAp00004221", "PAp00004290", "PAp00005006");
           my @test_n_protein_mappings = ("2", "1", "2", "5");
           my @test_n_genome_locations = ("1", "1", "2", "5");
           my @test_is_exon_spanning = ('N', 'Y', 'Y', 'N');

           for (my $jj = 0; $jj <= $#test_pep; $jj++) {
               if ($peptide_accession[$ii] eq $test_pep[$jj]) {
                   if ($n_genome_locations[$ii] != $test_n_genome_locations[$jj]) {
                       print "!! $test_pep[$jj] : " .
                       "expected n_genome_locations=$test_n_genome_locations[$jj]" .
                       " but calculated $n_genome_locations[$ii]\n";
                   }
                   if ($n_protein_mappings[$ii] != $test_n_protein_mappings[$jj]) {
                       print "!! $test_pep[$jj] : " .
                       " expected n_protein_mappings=$test_n_protein_mappings[$jj]",
                       " but calculated $n_protein_mappings[$ii]\n";
                   }
                   if ($is_exon_spanning[$ii] != $test_is_exon_spanning[$jj]) {
                       print "!! $test_pep[$jj] : " .
                       " expected is_exon_spanning=$test_is_exon_spanning[$jj]",
                       " but calculated $is_exon_spanning[$ii]\n";
                   }
               }
           }
       }
   }


    ## Calculate is_subpeptide_of

    ## hash with key = peptide_accession, value = sub-peptide string list
    my %peptideAccession_subPeptide;

    foreach my $sub_pep_acc (keys %peptideAccession_peptideSequence)
    {        

        for my $super_pep_acc (keys %peptideAccession_peptideSequence)
        {        

            if ( ( index($peptideAccession_peptideSequence{$super_pep_acc}, 
                $peptideAccession_peptideSequence{$sub_pep_acc}) >= 0) 
                && ($super_pep_acc ne $sub_pep_acc) ) {
   
                if ( exists $peptideAccession_subPeptide{$sub_pep_acc} )
                {

                    $peptideAccession_subPeptide{$sub_pep_acc} =
                        join ",", $peptideAccession_subPeptide{$sub_pep_acc},
                        $peptides{$super_pep_acc};

                } else { 

                    $peptideAccession_subPeptide{$sub_pep_acc} = 
                    $peptides{$super_pep_acc};

                }

            }

        }

    }


   if ($TESTVARS) {

       my $n = ($#peptide_accession) + 1;

       print "\nChecking storage of values after calcs.  $n entries\n";

       for(my $i =0; $i <= $#peptide_accession; $i++){

           my $tmp_pep_acc = $peptide_accession[$i];

           my $tmp_strand = $strand[$i] ;
           my $tmp_peptide_id = $peptides{$tmp_pep_acc};
           my $tmp_n_genome_locations = $n_genome_locations[$i];
           my $tmp_is_exon_spanning = $is_exon_spanning[$i];
           my $tmp_n_protein_mappings = $n_protein_mappings[$i];
           my $tmp_start_in_biosequence = $start_in_biosequence[$i];
           my $tmp_end_in_biosequence = $end_in_biosequence[$i];
           my $tmp_chromosome = $chromosome[$i];
           my $tmp_start_in_chromosome = $start_in_chromosome[$i];
           my $tmp_end_in_chromosome = $end_in_chromosome[$i];
           my $tmp_strand = $strand[$i];


           if (!$tmp_pep_acc) {
         
               print "PROBLEM:  missing \$tmp_pep_acc for index $i\n";

           } elsif (!$tmp_strand) {

               print "PROBLEM:  missing \$tmp_strand for $tmp_pep_acc \n";

           } elsif (!$tmp_n_genome_locations) {

               print "PROBLEM:  missing \$tmp_n_genome_locations for $tmp_pep_acc \n";

           } elsif (!$tmp_is_exon_spanning) {

               print "PROBLEM:  missing \$tmp_is_exon_spanning  for $tmp_pep_acc \n";

           } elsif (!$tmp_n_protein_mappings){

               print "PROBLEM:  missing \$tmp_n_protein_mappings for $tmp_pep_acc \n";

           } elsif (!$tmp_start_in_biosequence) {

               print "PROBLEM:  missing \$tmp_start_in_biosequence for $tmp_pep_acc \n";

           } elsif (!$tmp_end_in_biosequence ) {

               print "PROBLEM:  missing \$tmp_end_in_biosequence for $tmp_pep_acc \n";

           } elsif (!$tmp_chromosome ){

               print "PROBLEM:  missing \$tmp_chromosome for $tmp_pep_acc \n";

           } elsif (!$tmp_start_in_chromosome ) {

               print "PROBLEM:  missing \$tmp_start_in_chromosome for $tmp_pep_acc \n";

           } elsif (!$tmp_end_in_chromosome ) {

               print "PROBLEM:  missing \$tmp_end_in_chromosome  for $tmp_pep_acc \n";

           } elsif (!$tmp_strand) {

               print "PROBLEM:  missing \$tmp_strand for $tmp_pep_acc \n";

           }
       }

       print "-->end third stage test of vars\n";
    }


    ####----------------------------------------------------------------------------
    ## Creating peptide_mapping records, and updating peptide_instance records
    ####----------------------------------------------------------------------------
    print "\nCreating peptide_mapping records, and updating peptide_instance records\n";


    ## hash with key = peptide_accesion, value = peptide_instance_id
    my %peptideAccession_peptideInstanceID = 
        get_peptide_accession_instance_id_hash( 
        atlas_build_id => $atlas_build_id );


    my %strand_xlate = ( '-' => '-',   '+' => '+',  '-1' => '-',
                        '+1' => '+',   '1' => '+'
    );


    for (my $i =0; $i <= $#peptide_accession; $i++){

        my $tmp = $strand_xlate{$strand[$i]}
            or die("ERROR: Unable to translate strand $strand[$i]");

        $strand[$i] = $tmp;
 
        #### Make sure we can resolve the biosequence_id
        my $biosequence_id = $biosequence_ids{$biosequence_name[$i]}
            || die("ERROR: BLAST matched biosequence_name $biosequence_name[$i] ".
            "does not appear to be in the biosequence table!!");

        my $tmp_pep_acc = $peptide_accession[$i];
 

        my $peptide_id = $peptides{$tmp_pep_acc} ||
            die("ERROR: Wanted to insert data for peptide $peptide_accession[$i] ".
            "which is in the BLAST output summary, but not in the input ".
            "peptide file??");

        my $peptide_instance_id = $peptideAccession_peptideInstanceID{$tmp_pep_acc};


        ## UPDATE peptide_instance record
        my %rowdata = (   ##   peptide_instance    table attributes
            n_genome_locations => $n_genome_locations[$i],
            is_exon_spanning => $is_exon_spanning[$i],
            n_protein_mappings => $n_protein_mappings[$i],
            is_subpeptide_of => $peptideAccession_subPeptide{$tmp_pep_acc},
        );
 

        my $success = $sbeams->updateOrInsertRow(
            update=>1,
            table_name=>$TBAT_PEPTIDE_INSTANCE,
            rowdata_ref=>\%rowdata,
            PK => 'peptide_instance_id',
            PK_value => $peptide_instance_id,
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );


        ## CREATE peptide_mapping record
        my %rowdata = (   ##   peptide_mapping      table attributes
            peptide_instance_id => $peptide_instance_id,
            matched_biosequence_id => $biosequence_id,
            start_in_biosequence => $start_in_biosequence[$i],
            end_in_biosequence => $end_in_biosequence[$i],
            chromosome => $chromosome[$i],
            start_in_chromosome => $start_in_chromosome[$i],
            end_in_chromosome => $end_in_chromosome[$i],
            strand => $strand[$i],
        );
        
        $sbeams->updateOrInsertRow(
            insert=>1,
            table_name=>$TBAT_PEPTIDE_MAPPING,
            rowdata_ref=>\%rowdata,
            PK => 'peptide_mapping_id',
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );


        print "$i...";
 
    }  ## end  create peptide_mapping records and update peptide_instance records


    print "\n";
 

   ## LAST TEST to assert that all peptides of an atlas in
   ## peptide_instance  are associated with a peptide_instance_sample record
   ## ALSO checks that atlas_build_sample is filled...uses this as start point
   if ($CHECKTABLES) {

       print "\nChecking peptide_instance_sample records\n";

       my $sql = qq~
           SELECT peptide_instance_id, sample_ids
           FROM PeptideAtlas.dbo.peptide_instance
           WHERE atlas_build_id ='$ATLAS_BUILD_ID'
       ~;

       ## make hash with key = peptide_instance_id, value = sample_ids
       my %peptide_instance_hash = $sbeams->selectTwoColumnHash($sql)
           or die "In last test, unable to complete query:\n$sql\n($!)";

       my $n = keys ( %peptide_instance_hash ) ;

       print "\n$n peptide_instance_ids in atlas build $ATLAS_BUILD_ID\n";

       
       ## get an array of sample_id for a given atlas_id
       $sql = qq~
           SELECT sample_id
           FROM PeptideAtlas.dbo.atlas_build_sample
           WHERE atlas_build_id ='$ATLAS_BUILD_ID'
        ~;

       my @sample_id_array =  $sbeams->selectOneColumn($sql) 
           or die "could not find sample id's for atlas_build_id= ".
           "$ATLAS_BUILD_ID ($!)";

       my $sample_id_string = join("\',\'",@sample_id_array);
       ## add a ' to beginning of string and to end
       $sample_id_string =~ s/^(\w+)/\'$1/;
       $sample_id_string =~ s/(\w+)$/$1\'/;


       ## grab all records in peptide_instance_sample that contain
       ## sample_id = one of "sample_id_string"
       $sql = qq~
           SELECT peptide_instance_id, sample_id
           FROM PeptideAtlas.dbo.peptide_instance_sample
            WHERE sample_id IN ( $sample_id_string )
       ~;
       ## returns an array of references to arrays (each of which is a returned row?)
       my @peptide_instance_id_ref_array = $sbeams->selectSeveralColumns($sql)
           or die "In last test, unable to complete query:\n$sql\n($!)";


       foreach my $peptide_instance_id ( keys %peptide_instance_hash) {

           my $tmp_sample_ids = $peptide_instance_hash{$peptide_instance_id};
           
           ## split sample_ids into sample_id:
           my @sample_id = split(",", $tmp_sample_ids );

            foreach (my $i; $i <= $#sample_id; $i++) {
 
                ## check that there's an entry in @peptide_instance_id_ref_array
                ## matching $peptide_instance_id and $sample_id[$i]
                my $match_flag = 0;

                foreach my $row (@peptide_instance_id_ref_array) {
             
                    my ($tmp_peptide_instance_id, $tmp_sample_id) = @{$row};

                    if ( ($peptide_instance_id == $tmp_peptide_instance_id)
                    && ($tmp_sample_id == $sample_id[$i]) ) {

                        $match_flag = 1;

                        last;
                    }
                    
                }
 
                unless ($match_flag == 1) {

                    print "couldn't find peptide_instance_sample record for ".
                        "peptide_instance_id $peptide_instance_id in sample $sample_id[$i]\n";

                }
 
            }

       }

   }


}


#######################################################################
# loadFromPAxmlFile - uses SAX Content handler to parse APD_*all.PAxml 
# and call methods within this code to insert [peptide], 
# [peptide_instance*], and [modified_peptide_instance*] records
#
# @param atlas_build_id
# @param sbid_asbid_sid_hash_ref reference to complex hash holding
#    atlas_search_batch_id and sample_id using key = protomics
#    search_batch_id
# @param $infile the APD_<organism>_all.PAxml file
#######################################################################
sub loadFromPAxmlFile {
  my %args = @_;

  my $infile = $args{'infile'} or die "need infile ($!)";

  my $sbid_asbid_sid_hash_ref = $args{'sbid_asbid_sid_hash_ref'} or die
    "need sample_id_hash reference ($!)";

  my $atlas_build_id = $args{'atlas_build_id'} or die
    "need atlas_build_id ($!)";

  ## hash with key = atlas_search_batch_id, value = sample_id
  my %sbid_asbid_sid_hash = %{ $sbid_asbid_sid_hash_ref };

  ## get hash with key=peptide_accession, value=peptide_id
  my %peptide_acc_id_hash = get_peptide_accession_id_hash();

  #### Process parser options
  my $validate = $OPTIONS{validate} || 'auto';
  my $namespace = $OPTIONS{namespaces} || 0;
  my $schema = $OPTIONS{schemas} || 0;

  if (uc($validate) eq 'ALWAYS') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Always;
  } elsif (uc($validate) eq 'NEVER') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Never;
  } elsif (uc($validate) eq 'AUTO') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Auto;
  } else {
    die("Unknown value for -v: $validate\n$USAGE");
  }

  #### Set up the Xerces parser
  my $parser = XML::Xerces::XMLReaderFactory::createXMLReader();
  $parser->setFeature("http://xml.org/sax/features/namespaces", $namespace);

  if ($validate eq $XML::Xerces::SAX2XMLReader::Val_Auto) {
    $parser->setFeature("http://xml.org/sax/features/validation", 1);
    $parser->setFeature("http://apache.org/xml/features/validation/dynamic",1);

  } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Never) {
    $parser->setFeature("http://xml.org/sax/features/validation", 0);

  } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Always) {
    $parser->setFeature("http://xml.org/sax/features/validation", 1);
    $parser->setFeature("http://apache.org/xml/features/validation/dynamic",0);
  }

  $parser->setFeature("http://apache.org/xml/features/validation/schema",
    $schema);


  #### Create the error handler and content handler
  my $error_handler = XML::Xerces::PerlErrorHandler->new();
  $parser->setErrorHandler($error_handler);

  my $CONTENT_HANDLER = PAxmlContentHandler->new();
  $parser->setContentHandler($CONTENT_HANDLER);

  $CONTENT_HANDLER->setVerbosity($VERBOSE);
  $CONTENT_HANDLER->{counter} = 0;
  $CONTENT_HANDLER->{atlas_build_id} = $atlas_build_id;

  $CONTENT_HANDLER->{sbid_asbid_sid_hash} = 
    \%sbid_asbid_sid_hash;

  $CONTENT_HANDLER->{peptide_acc_id_hash} = \%peptide_acc_id_hash;


  $parser->parse(XML::Xerces::LocalFileInputSource->new($infile));

  return(1);

}


#######################################################################
#  getAnMzXMLFileName -- get an mzXML File Name by reading the interact
#  pepXML file, and parsing a foudn pepXML name
# @param search_batch_dir_path absolute path to search_batch_dir
# @return anMzXMLFileName
#######################################################################
sub getAnMzXMLFileName
{

    my %args = @_;

    my $search_batch_dir_path = $args{search_batch_dir_path} or die
        " need search_batch_dir_path ($!)";

    my $infile = "$search_batch_dir_path/interact-prob.xml";

    my ($msRunPepXMLFileName, $mzXMLFileName);

    unless(-e $infile)
    {
        print "[WARN] could not find $infile\n";

        $infile = "$search_batch_dir_path/interact.xml";
    }
    unless(-e $infile)
    {
        die "could not find $infile either\n";
    }

    open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

    while (my $line = <INFILE>)
    {
        chomp($line);

        if ($line =~ /^(\<inputfile name=\")(.+)(\/)(.+)(\/)(.+)(\")(\/\>)/)
        {

            my $exp_dir = $2;

            my $tmp = $6;

            if ($tmp =~ /(.+)\.xml/)
            {

                $tmp = $1;
            }

            $mzXMLFileName = "$exp_dir/$tmp" . ".mzXML";

            last;
        }

    }

    close(INFILE) or die "Cannot close $infile";

    if ($msRunPepXMLFileName)
    {

        ## remove the .xml and search_dir
        $msRunPepXMLFileName =~ /^(.+)\/(.+)\/(.+)(xml)/;

        $mzXMLFileName = "$1/$3" . "mzXML";

        unless( -e $mzXMLFileName)
        {
            die "could not find $mzXMLFileName ($!)\n";

        }

    }

    return $mzXMLFileName;

}



###############################################################################
# insert_peptide
###############################################################################
sub insert_peptide {
  my %args = @_;

  my $rowdata_ref = $args{'rowdata_ref'} or die("need rowdata_ref");

  my $peptide_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TBAT_PEPTIDE,
    rowdata_ref=>$rowdata_ref,
    PK => 'peptide_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  return($peptide_id);

} # end insert_peptide


###############################################################################
# insert_peptide_instance
###############################################################################
sub insert_peptide_instance {
  my %args = @_;

  my $rowdata_ref = $args{'rowdata_ref'} or die("need rowdata_ref");

  my $peptide_instance_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TBAT_PEPTIDE_INSTANCE,
    rowdata_ref=>$rowdata_ref,
    PK => 'peptide_instance_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  return($peptide_instance_id);

} # end insert_peptide_instance



###############################################################################
# insert_modified_peptide_instance
###############################################################################
sub insert_modified_peptide_instance {
  my %args = @_;

  my $rowdata_ref = $args{'rowdata_ref'} or die("need rowdata_ref");

  my $modified_peptide_instance_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TBAT_MODIFIED_PEPTIDE_INSTANCE,
    rowdata_ref=>$rowdata_ref,
    PK => 'modified_peptide_instance_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  return($modified_peptide_instance_id);

} # end insert_modified_peptide_instance



###############################################################################
# insert_peptide_instance_samples
#
# @param $peptide_instance_id
# @param $sample_ids string of sample_ids separated by commas
###############################################################################
sub insert_peptide_instance_samples {

  my %args = @_;

  my $peptide_instance_id = $args{'peptide_instance_id'}
    or die("need peptide_instance_id");

  my $sample_ids = $args{'sample_ids'} or die("need sample_ids");

  my @sample_ids = split(/,/,$sample_ids);

  foreach my $sample_id ( @sample_ids ) {
    my %rowdata = (
      peptide_instance_id => $peptide_instance_id,
      sample_id => $sample_id,
    );

    $sbeams->updateOrInsertRow(
      insert=>1,
      table_name=>$TBAT_PEPTIDE_INSTANCE_SAMPLE,
      rowdata_ref=>\%rowdata,
      PK => 'peptide_instance_sample_id',
      add_audit_parameters => 1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

  }

  return(1);

} # end insert_peptide_instance_samples



###############################################################################
# insert_peptide_instance_search_batches
#  
# @param $peptide_instance_id
# @param $atlas_search_batch_ids
###############################################################################
sub insert_peptide_instance_search_batches 
{
    my %args = @_;

    my $peptide_instance_id = $args{'peptide_instance_id'}
        or die("need peptide_instance_id");

    my $atlas_search_batch_ids = $args{'atlas_search_batch_ids'} 
        or die("need atlas_search_batch_ids");

    my @atlas_search_batch_id_array = split(/,/,$atlas_search_batch_ids);

    foreach my $atlas_search_batch_id ( @atlas_search_batch_id_array ) 
    {
        my %rowdata = (
            peptide_instance_id => $peptide_instance_id,
            atlas_search_batch_id => $atlas_search_batch_id,
        );

        $sbeams->updateOrInsertRow(
            insert=>1,
            table_name=>$TBAT_PEPTIDE_INSTANCE_SEARCH_BATCH,
            rowdata_ref=>\%rowdata,
            PK => 'peptide_instance_search_batch_id',
            add_audit_parameters => 1,
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );

    }

    return(1);

} # end insert_peptide_instance_search_batches



###############################################################################
# insert_modified_peptide_instance_samples
###############################################################################
sub insert_modified_peptide_instance_samples 
{

  my %args = @_;

  my $modified_peptide_instance_id = $args{'modified_peptide_instance_id'}
    or die("need modified_peptide_instance_id");

  my $sample_ids = $args{'sample_ids'} or die("need sample_ids");

  my @sample_ids = split(/,/,$sample_ids);

  foreach my $sample_id ( @sample_ids ) {
    my %rowdata = (
      modified_peptide_instance_id => $modified_peptide_instance_id,
      sample_id => $sample_id,
    );

    $sbeams->updateOrInsertRow(
      insert=>1,
      table_name=>$TBAT_MODIFIED_PEPTIDE_INSTANCE_SAMPLE,
      rowdata_ref=>\%rowdata,
      PK => 'modified_peptide_instance_sample_id',
      add_audit_parameters => 1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

  }

  return(1);

} # end insert_modified_peptide_instance_samples



###############################################################################
# insert_modified_peptide_instance_search_batches
#  
# @param $modified_peptide_instance_id
# @param $atlas_search_batch_ids
###############################################################################
sub insert_modified_peptide_instance_search_batches 
{
    my %args = @_;

    my $modified_peptide_instance_id = $args{'modified_peptide_instance_id'}
        or die("need modified_peptide_instance_id");

    my $atlas_search_batch_ids = $args{'atlas_search_batch_ids'} 
        or die("need atlas_search_batch_ids");

    my @atlas_search_batch_id_array = split(/,/,$atlas_search_batch_ids);

    foreach my $atlas_search_batch_id ( @atlas_search_batch_id_array ) 
    {
        my %rowdata = (
            modified_peptide_instance_id => $modified_peptide_instance_id,
            atlas_search_batch_id => $atlas_search_batch_id,
        );

        $sbeams->updateOrInsertRow(
            insert=>1,
            table_name=>$TBAT_MODIFIED_PEPTIDE_INSTANCE_SEARCH_BATCH,
            rowdata_ref=>\%rowdata,
            PK => 'modified_peptide_instance_search_batch_id',
            add_audit_parameters => 1,
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );

    }

    return(1);

} # end insert_modified_peptide_instance_search_batches


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

