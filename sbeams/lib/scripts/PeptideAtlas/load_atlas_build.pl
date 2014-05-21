#!/usr/local/bin/perl 

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
use SpectraDescriptionSetParametersParser;
use SearchResultsParametersParser;
use Benchmark;

use XML::Parser;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username $ATLAS_BUILD_ID %spectra
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TESTVARS $CHECKTABLES $sbeamsPROT $SSRCalculator $massCalculator
            );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q $log);
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


#### Create and initialize SSRCalc object with 3.0
use lib '/net/db/src/SSRCalc/ssrcalc';
$ENV{SSRCalc} = '/net/db/src/SSRCalc/ssrcalc';
use SSRCalculator;
my $SSRCalculator = new SSRCalculator;
$SSRCalculator->initializeGlobals3();
$SSRCalculator->ReadParmFile3();

use SBEAMS::Proteomics::PeptideMassCalculator;
$massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator;


###############################################################################
# Set program name and usage banner for command line use
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
  --check_tables              will not insert or update.  does a check of peptide_instance_sample

  --list                      If set, list the available builds and exit
  --delete                    Delete an atlas build (does not build an atlas).
  --purge                     Delete child records in atlas build (retains parent atlas record).
  --load                      Build an atlas (cannot currently be used in conjunction with --purge).
  --spectra                   Loads or updates the individual spectra for a build
  --prot_info                 Loads or updates protein identifications for a build (with --purge, purges)
  --instance_searchbatch_obs           Loads or updates the number of observations per 
                              search_batch for peptide_instance and modified_pi tables
  --coordinates               Loads or updates the peptide coordinates

  --organism_abbrev           Abbreviation of organism like Hs

  --atlas_build_name          Name of the atlas build (already entered by hand in
                              the atlas_build table) into which to load the data
  --default_sample_project_id default project_id  needed for auto-creation of tables (best to set
                              default to dev/private access and open access later)
  --spectrum_fragmentation_type

 e.g.:  ./load_atlas_build.pl --atlas_build_name \'Human_P0.9_Ens26_NCBI35\' --organism_abbrev \'Hs\' --load --default_sample_project_id 476

 e.g.: ./load_atlas_build.pl --atlas_build_name \'TestAtlas\' --delete
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "testvars","delete", "purge", "load", "check_tables",
        "atlas_build_name:s", "organism_abbrev:s", "default_sample_project_id:s",
        "list","spectra","prot_info","coordinates","instance_searchbatch_obs",
        "spectrum_fragmentation_type",
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

  my $default_sample_project_id = $OPTIONS{"default_sample_project_id"} || '';


  #### If a listing was requested, list and return
  if ($OPTIONS{"list"}) {
    use SBEAMS::PeptideAtlas::AtlasBuild;
    my $builds = new SBEAMS::PeptideAtlas::AtlasBuild();
    $builds->setSBEAMS($sbeams);
    $builds->listBuilds();
    return;
  }


  #### Verify required parameters
  unless ($atlas_build_name) {
    print "\nERROR: You must specify an --atlas_build_name\n\n";
    die "\n$USAGE";
  }


  ## --delete with --load will not work
  if ($del && $load) {
      print "ERROR: --delete --load will not work.\n";
      print "  use: --purge, then --load, instead\n\n";
      die "\n$USAGE";
      exit;
  }


  ## --delete with --purge will not work
  if ($del && $purge) {
      print "ERROR: select --delete or --purge, but not both\n";
      print "$USAGE";
      exit;
  }

  ## --load with --purge should work, but isn't working Dec. 2008.
  ##  appears to purge & load, but afterward old load shows in web interface
  if ($load && $purge) {
      print "ERROR: --purge --load is not currently working.\n";
      print "  use: --purge, then --load, instead\n\n";
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
  # (if also --prot_info, handled later -- will purge only prot_info.)
  if ($purge && ! $OPTIONS{prot_info}) {

       print "Removing child records in $atlas_build_name ($ATLAS_BUILD_ID): \n";

      removeAtlas(atlas_build_id => $ATLAS_BUILD_ID,
           keep_parent_record => 1);

  }#end --purge


  ## handle --load:
  if ($load) {
     my $t0 = new Benchmark; 
     # Use explicit commits for performance
     loadAtlas( atlas_build_id=>$ATLAS_BUILD_ID,
          organism_abbrev => $organism_abbrev,
          default_sample_project_id => $default_sample_project_id,
      );

     populateSampleRecordsWithSampleAccession();

     my $t1 = new Benchmark; 
     my $td = timestr(timediff( $t1, $t0 ));
     print "Loaded Atlas records in $td\n";

  } ## end --load

  #### If spectrum loading was requested
  if ($OPTIONS{"spectra"}) {
    use SBEAMS::PeptideAtlas::Spectrum;
    my $spectra = new SBEAMS::PeptideAtlas::Spectrum;
    my $atlas_build_directory = get_atlas_build_directory(
      atlas_build_id => $ATLAS_BUILD_ID,
    );
    $spectra->setSBEAMS($sbeams);
    $spectra->setVERBOSE($VERBOSE);
    $spectra->setTESTONLY($TESTONLY);
    $spectra->loadBuildSpectra(
      atlas_build_id => $ATLAS_BUILD_ID,
      atlas_build_directory => $atlas_build_directory,
      organism_abbrev => $organism_abbrev,
    );
  }

  #### If load or purge of protein information was requested
  if ($OPTIONS{"prot_info"}) {
    # if --purge, purge prot_info, unless load also requested, in which
    # case the entire load should have been purged already and we now
    # want to load prot_info
    if ($purge && !$load) {
       print "Purging protein identification info from $atlas_build_name ($ATLAS_BUILD_ID): \n";
       purgeProteinIdentificationInfo(
	 atlas_build_id => $ATLAS_BUILD_ID,
       );
    } else {
      use SBEAMS::PeptideAtlas::ProtInfo;
      my $prot_info = new SBEAMS::PeptideAtlas::ProtInfo;
      my $atlas_build_directory = get_atlas_build_directory(
	atlas_build_id => $ATLAS_BUILD_ID,
      );
      $prot_info->setSBEAMS($sbeams);
      $prot_info->setVERBOSE($VERBOSE);
      $prot_info->setTESTONLY($TESTONLY);
      $prot_info->loadBuildProtInfo(
	atlas_build_id => $ATLAS_BUILD_ID,
	atlas_build_directory => $atlas_build_directory,
      );
    }
  }


  #### If coordinates only was requested
  if ($OPTIONS{"coordinates"}) {
    print "\n Begin (manual) calc coordinates \n";
    ## set infile to coordinate mapping file
    my $builds_directory = get_atlas_build_directory (atlas_build_id =>
        $ATLAS_BUILD_ID);
    my $mapping_file = "$builds_directory/coordinate_mapping.txt";
    my $biosequence_set_id = get_biosequence_set_id (atlas_build_id =>
        $ATLAS_BUILD_ID);

    #### Update the build data already loaded with genomic coordinates
    readCoords_updateRecords_calcAttributes(
        infile => $mapping_file,
        atlas_build_id => $ATLAS_BUILD_ID,
        biosequence_set_id => $biosequence_set_id,
        organism_abbrev => $organism_abbrev,
        source_dir => $builds_directory,
    );
  }

  #### If update of inst_sample_obs only was requested, or during load
  if ($OPTIONS{instance_searchbatch_obs} || $OPTIONS{load} ) {
    print "\n Begin update instance search_batch observations \n";

    ## set infile to PAidentlist file
    my $dir = get_atlas_build_directory (atlas_build_id => $ATLAS_BUILD_ID);
    my $identlist = "$dir/PeptideAtlasInput_sorted.PAidentlist";
    $identlist = "$dir/PeptideAtlasInput_concat.PAidentlist" if !-e $identlist;

    if ( !-e $identlist ) {
      print STDERR "Unable to find Identlist, inst_searchbatch_obs not finished\n";
		} else {
#			print "Getting search batch to sample mapping\n";
      my $psb2asb = $sbeamsMOD->getProtSB2AtlasSB(build_id=>[$ATLAS_BUILD_ID]);
#      for my $k ( sort { $a <=> $b } keys ( %{$sb2smpl} ) ) { print "$k => $sb2smpl->{$k}\n"; }
			print "Getting counts from ident list\n";


    # Get search_batch to peptide_source_type mapping
    my $asb2pst = $sbeamsMOD->getAtlasSB2PeptideSrcType();




      my $inst_obs = $sbeamsMOD->cntObsFromIdentlist( identlist_file => $identlist,
			                                          key_type => 'peptide',
													  psb2asb => $psb2asb );

			print "Updating pep instance records\n";
      my $inst_recs = $sbeamsMOD->getPepInstRecords( build_id => $ATLAS_BUILD_ID );
      initiate_transaction();

      my $cnt = 0;
      my $commit_interval = 50;
			for my $peptide ( keys( %{$inst_recs} ) ) {
				for my $sbatch( keys( %{$inst_recs->{$peptide}} ) ) {
          if ( $inst_obs->{$peptide}->{$sbatch}  ) {
            $sbeams->updateOrInsertRow( update => 1,
                                    table_name => $TBAT_PEPTIDE_INSTANCE_SEARCH_BATCH,
                                   rowdata_ref => {n_observations => $inst_obs->{$peptide}->{$sbatch} },
                                            PK => 'peptide_instance_search_batch_id',
                                      PK_value => $inst_recs->{$peptide}->{$sbatch},
                          add_audit_parameters => 1,
                                       verbose => $VERBOSE,
                                      testonly => $TESTONLY,
                                   );             
						$cnt++;
						commit_transaction() unless $commit_interval % $cnt;
#					  my $sql = " UPDATE peptide_instance_sample SET n_observations = $inst_obs->{$peptide}->{$sample} WHERE peptide_instance_sample_id = $inst_recs->{$peptide}->{$sample}";
					}
				}
			}
 			commit_transaction() unless $cnt && $commit_interval % $cnt;

			print "Updating modified pep instance records\n";
      my $mod_inst_recs = $sbeamsMOD->getModPepInstRecords( build_id => $ATLAS_BUILD_ID );

	   	$cnt = 0;
			for my $peptide ( keys( %{$mod_inst_recs} ) ) {
				for my $search_batch( keys( %{$mod_inst_recs->{$peptide}} ) ) {
          if ( $inst_obs->{$peptide}->{$search_batch}  ) {

            $sbeams->updateOrInsertRow( update => 1,
                                    table_name => $TBAT_MODIFIED_PEPTIDE_INSTANCE_SEARCH_BATCH,
                                   rowdata_ref => {n_observations => $inst_obs->{$peptide}->{$search_batch} },
                                            PK => 'modified_peptide_instance_search_batch_id',
                                      PK_value => $mod_inst_recs->{$peptide}->{$search_batch},
                          add_audit_parameters => 1,
                                       verbose => $VERBOSE,
                                      testonly => $TESTONLY,
                                   );             
						$cnt++;
						commit_transaction() unless $commit_interval % $cnt;
#						my $sql = "UPDATE modified_peptide_instance_sample SET n_observations = $inst_obs->{$peptide}->{$sample} WHERE peptide_instance_sample_id = $mod_inst_recs->{$peptide}->{$sample}";
					}
				}
			}
     # last commit, then reset to standard autocommit mode
     commit_transaction() unless $cnt && $commit_interval % $cnt;
     reset_dbh();
    }
  }

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }

 #### If spectrum_fragmentation_type loading was requested
  if ($OPTIONS{"spectrum_fragmentation_type"}) {
    use SBEAMS::PeptideAtlas::Spectrum;
    my $spectra = new SBEAMS::PeptideAtlas::Spectrum;
    $spectra->setSBEAMS($sbeams);
    $spectra->setVERBOSE($VERBOSE);
    $spectra->setTESTONLY($TESTONLY);
    $spectra->loadSpectrum_Fragmentation_Type(
      atlas_build_id => $ATLAS_BUILD_ID,
    );
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

    my $atlas_build_id = $args{atlas_build_id} or die "need atlas build id";

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
      atlas_build => 'peptide_instance(C),atlas_build_sample(C),atlas_build_search_batch(C),spectra_description_set(C),search_key(C)',
      atlas_build_search_batch => 'search_batch_statistics(C)',
      peptide_instance => 'peptide_mapping(C),peptide_instance_sample(C),peptide_instance_search_batch(C),modified_peptide_instance(C)',
      modified_peptide_instance => 'modified_peptide_instance_sample(C),modified_peptide_instance_search_batch(C)',
   );

   #my $TESTONLY = "0";
   my $VERBOSE = "1" unless ($VERBOSE);

   # first, delete the protein identification info.
   purgeProteinIdentificationInfo(
     atlas_build_id => $atlas_build_id,
   );

   # then, recursively delete the child records of the atlas build
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
# purgeProteinIdentificationInfo -- delete all records for given build in
# protein_identification and biosequence_relationship tables 
###############################################################################
sub purgeProteinIdentificationInfo {
    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'} or die
        " need atlas_build_id";

    my $sql = qq~
	DELETE
	FROM $TBAT_PROTEIN_IDENTIFICATION
	WHERE atlas_build_id = '$atlas_build_id'
	~;

    print "Purging protein_identification table ...\n";

    $sbeams->executeSQL($sql);

    $sql = qq~
	DELETE
	FROM $TBAT_BIOSEQUENCE_RELATIONSHIP
	WHERE atlas_build_id = '$atlas_build_id'
	~;

    print "Purging biosequence_relationship table ...\n";

    $sbeams->executeSQL($sql);
}


###############################################################################
# loadAtlas -- load an atlas
# @param atlas_build_id
# @param organism_abbrev
# @param default_sample_project_id  project_id to be used when creating new samples
###############################################################################
sub loadAtlas {

    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'} or die
        " need atlas_build_id";

    my $organism_abbrev = $args{'organism_abbrev'} or die
        " need organism_abbrev";

    my $default_sample_project_id = $args{'default_sample_project_id'} or
       die "need default_sample_project_id";


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
               default_sample_project_id => $default_sample_project_id,
               organism_abbrev => $organism_abbrev,
    );


    print "\nFinished loading atlas \n";

}




###############################################################################
# buildAtlas -- populates PeptideAtlas records in requested atlas_build
# @param atlas_build_id 
# @param default_sample_project_id
# @param biosequence_set_id
# @param source_dir
# @param organism_abbrev
###############################################################################
sub buildAtlas {

    print "building atlas...\n" if ($TESTONLY);

    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'} or die "need atlas_build_id ($!)";

    my $default_sample_project_id = $args{'default_sample_project_id'} or die
        "need default_sample_project_id ($!)";

    my $biosequence_set_id = $args{'biosequence_set_id'} or 
        die "need biosequence_set_id ($!)";

    my $source_dir = $args{'source_dir'} or 
        die "need source directory containing coordinate_mapping.txt etc. ($!)";

    my $organism_abbrev = $args{'organism_abbrev'} or 
        die "need organism_abbrev ($!)";
 

    ## hash with key = search_batch_id, value = $search_dir
    my %loading_sbid_searchdir_hash = getInfoFromExperimentsList(
        infile => "$source_dir../Experiments.list" );

    ## the content handler for loadFromPAxmlFile is using search_batch_id's 
    ## from proteomics so we need to send it hash to look up atlas_search_batch_ids
    ## and sample_ids when needed.  
    ## note, this method creates sample and *search_batch records when necessary
    my %proteomicsSBID_hash =  get_search_batch_and_sample_id_hash(
        atlas_build_id => $atlas_build_id,
        default_sample_project_id => $default_sample_project_id,
        loading_sbid_searchdir_hash_ref => \%loading_sbid_searchdir_hash,
        source_dir => $source_dir,
    );

        
    #### Load from .PAxml file
    my $PAxmlfile = $source_dir . "APD_" . $organism_abbrev . "_all.PAxml";

    if (-e $PAxmlfile) {
        initiate_transaction();
        loadFromPAxmlFile(
            infile => $PAxmlfile,
            sbid_asbid_sid_hash_ref => \%proteomicsSBID_hash,
            atlas_build_id => $ATLAS_BUILD_ID,
        );
        # Commit final inserts (if any) from PAxml load.
        commit_transaction();
        reset_dbh(); 
    } else {
        die("ERROR: Unable to find '$PAxmlfile' to load data from.");
    }


    ## set infile to coordinate mapping file
    my $mapping_file = "$source_dir/coordinate_mapping.txt";

    print "\n Begin calc coordinates (build_atlas)\n";

    #### Update the build data already loaded with genomic coordinates
    readCoords_updateRecords_calcAttributes(
        infile => $mapping_file,
        atlas_build_id => $ATLAS_BUILD_ID,
        biosequence_set_id => $biosequence_set_id,
        organism_abbrev => $organism_abbrev,
        source_dir => $source_dir,
    );


}# end buildAtlas



###############################################################################
# get_search_batch_and_sample_id_hash --  get complex hash, and create all
# sample and *search_batch records in the process
#
# @param atlas_build_id
# @param default_sample_project_id default project_id used in creating new samples
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

    my $default_sample_project_id = $args{'default_sample_project_id'} or
        die "need default_sample_project_id ($!)";

    my $source_dir = $args{source_dir} or die("need source_dir ($!)");

    my $loading_sbid_searchdir_hash_ref = $args{loading_sbid_searchdir_hash_ref} 
       or die "need loading_sbid_searchdir_hash_ref ($)";

    ## hash with key = search_batch_id, value = $search_dir
    my %loading_sbid_searchdir_hash = %{$loading_sbid_searchdir_hash_ref};

    ## loading_sbid_searchdir_hash is used to get the sbid's to access
    ## the Proteomic records

    my $loading_sbid_list = get_string_list_of_keys(
        hash_ref => \%loading_sbid_searchdir_hash);

    foreach my $loading_sb_id (keys %loading_sbid_searchdir_hash )
    {
        my ($atlas_search_batch_id, $sample_id);

        my $asb_exists = "false";

        my $sample_exists = "false";

        ##########  handle sample records ##################
        ## since there are so few sample_records, will query one at a 
        ## time instead of large select

        #### see if an atlas_search_batch record exists ####
        my $sql = qq~
            SELECT ASB.sample_id, ASB.atlas_search_batch_id
            FROM $TBAT_ATLAS_SEARCH_BATCH ASB
            WHERE ASB.proteomics_search_batch_id = '$loading_sb_id'
            AND ASB.record_status != 'D'
        ~;

        my @rows = $sbeams->selectSeveralColumns($sql);

        foreach my $row (@rows)
        {
            my ($s_id, $asb_id) = @{$row};
            $sample_id = $s_id;
            $atlas_search_batch_id = $asb_id;
            $asb_exists = "true";
        }


        if ( $asb_exists eq "true" )
        { ## If $TBAT_ATLAS_SEARCH_BATCH exists, then so does a sample, and just got it in last query
            $sample_exists = "true";
        } else
        {   ## [cases: either this is a new sample, or the new table/records for any atlas_search_batch
            ## of this sample haven't been written yet (adjusting to new schema)

            ## For both cases, need to look for a sample record.  Will have to make assumption
            ## that PeptideAtlas sample_tag equals Proteomics exp_tag, until enough atlases
            ## have been built to have populated atlas_search_batch table, then we
            ## can skip this sample_exists check section
            $sql = qq~
                SELECT S.sample_id
                FROM $TBAT_SAMPLE S
                JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON (S.sample_tag = PE.experiment_tag)
                JOIN $TBPR_SEARCH_BATCH PSB ON (PE.experiment_id = PSB.experiment_id)
                WHERE PSB.search_batch_id = '$loading_sb_id'
                AND PE.record_status != 'D'
                AND S.record_status != 'D'
            ~;

            @rows = $sbeams->selectSeveralColumns($sql);
            
            foreach my $row (@rows)
            {
                my ($s_id) = @{$row};
                $sample_id = $s_id;
                $sample_exists = "true";
            }
        }
        ## Lastly, if no sample_id, create one from protomics record.  
        ## if this is true, then also will be missing [atlas_search_batch] and 
        ## [atlas_search_batch_parameter] and [atlas_search_batch_parameter_set]
       if ( ($asb_exists eq "false") || ($sample_exists eq "false") )
       {
            $sql = qq~
                SELECT distinct SB.search_batch_id, PE.experiment_name, PE.experiment_tag,
                SB.data_location, P.project_id, P.publication_id
                FROM $TBPR_PROTEOMICS_EXPERIMENT PE
                JOIN $TBPR_SEARCH_BATCH SB
                ON ( PE.EXPERIMENT_ID = SB.EXPERIMENT_ID)
                JOIN $TB_PROJECT P
                ON ( P.PROJECT_ID = PE.PROJECT_ID)
                WHERE SB.search_batch_id = '$loading_sb_id'
                AND PE.record_status != 'D'
            ~;

            @rows = $sbeams->selectSeveralColumns($sql) or die
                "Could not find proteomics experiment record for ".
                " search batch id $loading_sb_id \n$sql\n ($!)";

            foreach my $row (@rows)
            {
                my ($sb_id, $exp_name, $exp_tag, $d_l, $p_id, $pub_id) = @{$row};

                ## create [sample] record if it doesn't exist:
                if ($sample_exists eq "false")
                {
                    my %rowdata = (
                        search_batch_id => $sb_id,
                        sample_tag => $exp_tag,
                        original_experiment_tag => $exp_tag,
                        sample_title => $exp_name,
                        sample_description => $exp_name,
                        is_public => 'N',
              peptide_source_type => 'Natural',
                        project_id => $p_id,
                        sample_publication_ids => $pub_id
                    );

                    $sample_id = insert_sample( rowdata_ref => \%rowdata );
                }


                ## create [atlas_search_batch]
                my $search_batch_path = $loading_sbid_searchdir_hash{$loading_sb_id};
                $atlas_search_batch_id = create_atlas_search_batch(
                    proteomics_search_batch_id => $loading_sb_id,
                    sample_id => $sample_id,
                    search_batch_path => $search_batch_path
                );

                ## create [atlas_search_batch_parameter]s and [atlas_search_batch_parameter_set]
                my $successful = create_atlas_search_batch_parameter_recs(
                    atlas_search_batch_id => $atlas_search_batch_id,
                    search_batch_path => $search_batch_path
                );

            }

        } ## end of the "no sample_id" loop

        ### okay, all [sample] records exist now, and [atlas_search_batch]s

        ## load 'em into hash
        $loaded_sbid_asbid_sid_hash{$loading_sb_id}->{sample_id} = $sample_id;

        $loaded_sbid_asbid_sid_hash{$loading_sb_id}->{atlas_search_batch_id} = 
            $atlas_search_batch_id;


        ## create [atlas_build_search_batch] record
        my $atlas_build_search_batch_id = 
            create_atlas_build_search_batch(
                atlas_build_id => $atlas_build_id,
                sample_id => $sample_id,
                atlas_search_batch_id => $atlas_search_batch_id,
            );

        ## create a [spectra_description_set] record
        insert_spectra_description_set( 
            atlas_build_id => $atlas_build_id,
            sample_id => $sample_id,
            atlas_search_batch_id => $atlas_search_batch_id,
            search_batch_dir_path =>$loading_sbid_searchdir_hash{$loading_sb_id}
        );
         

        ## create [atlas_build_sample] record
        my $atlas_build_sample_id = createAtlasBuildSampleLink(
            sample_id => $sample_id,
            atlas_build_id => $atlas_build_id,
        );


#       my $path = "$dl/$sub_dir";
#
#       ## if doesn't exist, use global var for archive area
#       unless (-e $path)
#       {
#           $path = $RAW_DATA_DIR{Proteomics} . "/path";
#       }
#
#       unless (-e $path)
#       {
#           print "[WARN] cannot locate $path for " .
#           "atlas_build_search_batch w/ id=$absbid ";
#       }

    } ## end iterate over load 

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



#######################################################################
# getProteomicsExpTag -- get proteomics experiment tag, given search
#     batch id
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

    my $str_list = "";

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
# @param proteomics_search_batch_id  search batch id to look-up Proteomics info
# @param sample_id
# @param search_batch_path absolute path to search_batch information
# @return atlas_search_batch_id
#######################################################################
sub create_atlas_search_batch
{
    my %args = @_;

    my $sbid = $args{proteomics_search_batch_id} or die "need search_batch_id ($!)";

    my $sid = $args{sample_id} or die "need sample_id ($!)";

    my $proteomics_search_batch_path = $args{search_batch_path}
        or die "need search_batch_path ($!)";

    my $atlas_search_batch_id;

    my $nspec = $sbeamsMOD->getNSpecFromFlatFiles( search_batch_path => $proteomics_search_batch_path );

    my $search_batch_subdir =  $proteomics_search_batch_path;

    ##trim off all except last directory
    $search_batch_subdir =~ s/^(.+)\/(.+)/$2/gi;

    my $experiment_path = $proteomics_search_batch_path;

    $experiment_path =~ /.*\/archive\/(.*)\/.*/;
    $experiment_path = $1;
    #$experiment_path =~ s/^(.+)\/(.+)\/(.+)\/(.+)\/(.+)/$2\/$3\/$4/gi;

    my $TPP_version = getTPPVersion( directory => $proteomics_search_batch_path);
print "TPP version $TPP_version\n";
    ## attributes for atlas_search_batch_record
    my %rowdata = (             ##  atlas_search_batch
        proteomics_search_batch_id => $sbid,
        sample_id => $sid,
        n_searched_spectra => $nspec,
        data_location => $experiment_path,
        search_batch_subdir => $search_batch_subdir,
        TPP_version => $TPP_version,
    );

    $atlas_search_batch_id = $sbeams->updateOrInsertRow(
        insert=>1,
        table_name=>$TBAT_ATLAS_SEARCH_BATCH,
        rowdata_ref=>\%rowdata,
        PK => 'atlas_search_batch_id',
        return_PK => 1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    print "[INFO] Created  atlas_search_batch record $atlas_search_batch_id\n";

    return $atlas_search_batch_id;

}


#######################################################################
# create_atlas_build_search_batch -- create atlas_build_search_batch record
# @param sample_id  sample_id
# @param atlas_build_id
# @param atlas_search_batch_id  atlas_search_batch_id
# @return atlas_build_search_batch_id
#######################################################################
sub create_atlas_build_search_batch
{

    my %args = @_;

    my $sid = $args{sample_id} or die "need sample_id ($!)";

    my $atlas_build_id = $args{atlas_build_id} or die "need atlas_build_id ($!)";

    my $atlas_search_batch_id = $args{atlas_search_batch_id}
        or die "need atlas_search_batch_id ($!)";


    ## attributes for atlas_build_search_batch_record
    my %rowdata = (             ##  atlas_search_batch
        sample_id => $sid,
        atlas_search_batch_id => $atlas_search_batch_id,
        atlas_build_id => $atlas_build_id,
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


    my ($peptide_mass_tolerance, $peptide_ion_tolerance, 
        $enzyme, $num_enzyme_termini);


    #### Make a list of guesses for params files
    my @params_files = ( "$search_batch_path/sequest.params",
      "$search_batch_path/../sequest.params", "$search_batch_path/comet.def",
      "$search_batch_path/tandem.params", "$search_batch_path/tandem.xml",
      "$search_batch_path/spectrast.params",
      "$search_batch_path/comet.params",
    );

    #### Try to find the files in order
    my $found = '??';
    my $infile;
    foreach $infile ( @params_files ) {
      print "Looking for $infile...";
      if ( -e $infile ) {
	print "found!\n";
	$found = $infile;
	last;
      }
      print "\n";
    }

    unless ($found) {
      print "WARNING: Unable to find any search engine parameter file\n";
      return;
    }
    $infile = $found;


    ## if can't find readParamsFile, instantiate Protoeomics module 
    ## $sbeamsPROT = SBEAMS::Proteomics->new();
    ## $sbeamsPROT->setSBEAMS($sbeams);

    #### Read in the search parameters file
    my $result = $sbeamsPROT->readParamsFile(inputfile => "$infile");

    unless ($result) 
    {
        print "ERROR: Unable to read search parameter file: '$infile'\n";

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

	#### Not all search engines specify this, and it always seems to
	#### be 0 anyway. Set a default of 0 in case it is not seen.
	$peptide_mass_tolerance = 0;
	$peptide_ion_tolerance = 0;
	$enzyme = -1;
	$num_enzyme_termini = -1;

        ## pick up params needed for ATLAS_SEARCH_BATCH_PARAMETER_SET
        if ($key eq "peptide_mass_tolerance" or $key eq "MassTol" or
            $key eq "indexRetrievalMzTolerance")
        {
            $peptide_mass_tolerance = $rowdata{parameter_value};
        }

        if ($key eq "fragment_ion_tolerance")
        {
            $peptide_ion_tolerance = $rowdata{parameter_value};
        }

        if ($key eq "enzyme_number" or $key eq "EnzymeNum")
        {
            $enzyme = $rowdata{parameter_value};
        }

        if ($key eq "NumEnzymeTermini")
        {
            $num_enzyme_termini = $rowdata{parameter_value};
        }

	#### If this is Tandem-K data, we don't have any of this
	if ($key eq 'scoring, algorithm') {
	  $peptide_mass_tolerance = -1;
	  $peptide_ion_tolerance = -1;
	  $enzyme = 1;
	  $num_enzyme_termini = 1;
	}


    }

    #### If there was no NumEnzymeTermini specified, the default is 0
    $num_enzyme_termini = 0 unless ($num_enzyme_termini);
    $peptide_mass_tolerance = 0 unless ($peptide_mass_tolerance);
    $peptide_ion_tolerance = 0 unless ($peptide_ion_tolerance);
    $enzyme = 0 unless ($enzyme);


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
# @param $rowdata_ref  reference to hash holding table attributes
###############################################################################
sub insert_sample
{
    my $METHOD='insert_sample';

    my %args = @_;

    my $rowdata_ref = $args{'rowdata_ref'} or die("need rowdata_ref");

    my %rowdata = %{$rowdata_ref};


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

    print "INFO[$METHOD]: created sample record $sample_id\n";

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
        AND record_status != 'D'
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

    my $results_parser = new SearchResultsParametersParser();

    $results_parser->setSearch_batch_directory($directory);

    $results_parser->parse();

    my $TPP_version = $results_parser->getTPP_version();

    return $TPP_version;

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

    ## get instrunent model id from pr instrument table
    my $sql = qq~
        SELECT instrument_id, instrument_name
        FROM $TBPR_INSTRUMENT
    ~;

    my %id2instrname = $sbeams->selectTwoColumnHash($sql);

    ## There could be [spectra_description_set] records for this
    ## sample_id and atlas_search_batch
    $sql = qq~
      SELECT distinct sample_id, atlas_search_batch_id, 
      instrument_model_id, instrument_model_name, conversion_software_name, 
      conversion_software_version, mzXML_schema, n_spectra
      FROM $TBAT_SPECTRA_DESCRIPTION_SET
      WHERE atlas_search_batch_id = '$atlas_search_batch_id'
      AND sample_id = '$sample_id'
      AND record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);
   
    my ($instrument_model_id, $instrument_model_name, $conversion_software_name,
    $conversion_software_version, $mzXML_schema, $n_spectra);
    ## If record exists, use attributes to create new record afterwards
    if ($#rows > -1)
    {
        foreach my $row (@rows)
        {
            my ($sid, $asbid, $imid, $imn, $csn, $csv, $ms, $ns) = @{$row}; 

            $instrument_model_id = $imid;

            $instrument_model_name = $imn;

            $conversion_software_name = $csn;

            $conversion_software_version = $csv;

            $mzXML_schema = $ms;

            $n_spectra = $ns;

        }

    } else
    { 

        ## read experiment's pepXML file to get an mzXML file name
        my @mzXMLFileNames = getSpectrumXMLFileNames( 
                             search_batch_dir_path => $search_batch_dir_path);
        print `date`;
				if (1) {
					print "Found ".scalar(@mzXMLFileNames)." spectrum XML files in $search_batch_dir_path\n";
				} 

        #### read an mzXML file to get needed attributes... could make a sax content handler for this, 
        #### but only need the first dozen or so lines of file, and the mzXML files are huge...
        my $infile = $mzXMLFileNames[0];
        my $spectrum_parser = new SpectraDescriptionSetParametersParser();

        $spectrum_parser->setSpectrumXML_file($infile);

        $spectrum_parser->parse();

        $mzXML_schema = $spectrum_parser->getSpectrumXML_schema();

        $conversion_software_name =
            $spectrum_parser->getConversion_software_name();

        $conversion_software_version =
            $spectrum_parser->getConversion_software_version();

        $instrument_model_name = $spectrum_parser->getInstrument_model_name();

        $instrument_model_id='';
        my $maxmatch =0;
        if($instrument_model_name)
        {
          foreach my $instrid (keys %id2instrname)
          {
            my $instrname = $id2instrname{$instrid};
            my @seg = split(/\s+/, $instrname);
            my $match = 0;
            foreach my $elm (@seg)
            {
              next if($elm eq 'Classic');
              if($instrument_model_name =~ /$elm/i)
              {
                $match++;
              }
              if($instrument_model_name !~ /$elm/i)
              {
                $match =0;
                last;
              }
            }
            if ($match > $maxmatch)
            {
              $maxmatch =$match;
              $instrument_model_id=$instrid;
            }
          }

        }


        ## count the number of MS/MS in the mzXML files: ##
        my $sum = 0;

        foreach my $mzXMLFile (@mzXMLFileNames)
        {
#            my $nspec = `grep 'msLevel="2"' $mzXMLFile | wc -l`;
            my $nspec = 500;
            $sum = $sum + $nspec;
            # don't print, since this is broken
            #print "  nspec=$nspec\n";
        }

        $n_spectra = $sum;

    }
    ## if didn't get instrument_model_id from file 
    ## use the one in proteomics table
    if ( ! $instrument_model_id){
      my $sql = qq~;
        SELECT I.INSTRUMENT_ID
        FROM $TBAT_ATLAS_SEARCH_BATCH ASB 
        JOIN $TBPR_SEARCH_BATCH PSB ON (PSB.SEARCH_BATCH_ID = ASB.PROTEOMICS_SEARCH_BATCH_ID)
        JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON (PSB.EXPERIMENT_ID = PE.EXPERIMENT_ID)
        LEFT JOIN $TBPR_INSTRUMENT I ON (I.INSTRUMENT_ID = PE.INSTRUMENT_ID)
        WHERE ASB.SAMPLE_ID = $sample_id
     ~;
      my @rows = $sbeams->selectOneColumn($sql);
      if(@rows){
        $instrument_model_id = $rows[0];
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
        mzXML_schema => $mzXML_schema,
        n_spectra => $n_spectra,
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
  
    %rowdata = (
        instrument_model_id  => $instrument_model_id,
    );

    #update [sample] instrument_model_id 
    my $sucess = $sbeams->updateOrInsertRow(
        update=>1,
        table_name=>$TBAT_SAMPLE,
        rowdata_ref=>\%rowdata,
        PK => 'sample_id',
        PK_value => $sample_id,
        return_PK => 0, 
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );


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

    my $pepXMLfile = $sbeamsMOD->findPepXMLFile( search_path => $search_batch_path );
 
    if ( !-e $pepXMLfile ) {
      print STDERR "Unable to find pep xml file, build stats will not be computed correctly\n";
    }


    my $n0;

#   print "    file: $pepXMLfile\n";

##  Need to make this a global var, as perl doesn't have nested
##  subroutines (i.e., can't include sub local_start_handler
##  in this subroutine and have %spectra be accessible to it)

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


#######################################################################
# readCoords_updateRecords_calcAttributes -- read coordinate mapping
# file, calculate mapping attributes, update peptide_instance
# record, and create peptide_mapping records 
# @infile
# @atlas_build_id 
# @biosequence_set_id 
# @organism_abbrev 
# $source_dir
#######################################################################
sub readCoords_updateRecords_calcAttributes {

    my %args = @_;

    my $infile = $args{'infile'} or die "need infile ($!)";

#   my $proteomicsSBID_hash_ref = $args{'proteomicsSBID_hash_ref'} or die
#       " need proteomicsSBID_hash_ref ($!)";
#
#   my %proteomicsSBID_hash = %{$proteomicsSBID_hash_ref};

    my $atlas_build_id = $args{atlas_build_id} or die "need atlas_build_id ($!)";

    my $biosequence_set_id = $args{biosequence_set_id} or die 
        "need biosequence_set_id ($!)";

    my $organism_abbrev = $args{organism_abbrev} or die
        "need organism_abbrev ($!)";

    my $source_dir = $args{source_dir} or die("need source_dir");


    ## get hash with key=peptide_accession, value=peptide_id
    my %peptides = get_peptide_accession_id_hash();

    ## get hash with key=biosequence_name, value=biosequence_id
    my %biosequence_ids = get_biosequence_name_id_hash(
        biosequence_set_id => $biosequence_set_id);

    #### Load the duplicate mapping file if available
    my %duplicate_proteins;
    if ( -e "$source_dir/duplicate_groups.txt" ) {
      if (open(INFILE,"$source_dir/duplicate_groups.txt")) {
	my $header = <INFILE>;
	while (my $line = <INFILE>) {
	  chomp($line);
	  my @protein_names = split(/\s+/,$line);
	  my $reference = shift(@protein_names);
	  foreach my $duplicate ( @protein_names ) {
	    $duplicate_proteins{$duplicate} = $reference;
	    #print "$duplicate = $reference\n";
	  }
	}
      }
      close(INFILE);
    }


    my (@peptide_accession, @biosequence_name);
    my (@chromosome, @strand, @start_in_chromosome, @end_in_chromosome);
    my (@n_protein_mappings, @n_genome_locations, @is_exon_spanning);
    my (@start_in_biosequence, @end_in_biosequence);


    ## hash with key = $peptide_accession[$ind], 
    ##           value = string of array indices holding given peptide_accession
    my %index_hash;


    #### Cases where a peptides maps to both a forward and a DECOY are an
    #### unnecessary distraction. Remove all mappings to DECOY proteins
    #### where the peptide also maps to a forward protein
    open(INFILE, $infile) or die "ERROR: Unable to open for reading $infile ($!)";
    my $outfile = "${infile}-noDECOYdup";
    open(OUTFILE, ">$outfile") or die "ERROR: Unable to open for writing $outfile ($!)";
    print "\nTransforming $infile\n";
    my $bufferWithDecoys = '';
    my $bufferWithoutDecoys = '';
    my $previousPeptideAccession;
    my $hasNonDecoyMapping = 0;
    while (my $line = <INFILE>) {
      my @columns = split(/\t/,$line);
      my $peptideAccession = $columns[0];
      if ($previousPeptideAccession && $peptideAccession ne $previousPeptideAccession) {
				if ($hasNonDecoyMapping) {
					print OUTFILE $bufferWithoutDecoys;
				} else {
					print OUTFILE $bufferWithDecoys;
				}
				$bufferWithDecoys = '';
				$bufferWithoutDecoys = '';
				$hasNonDecoyMapping = 0;
			}

			if ($line =~ /DECOY/) {
				} else {
					$hasNonDecoyMapping = 1;
					$bufferWithoutDecoys .= $line;
				}
				$bufferWithDecoys .= $line;
				$previousPeptideAccession = $peptideAccession;
		}
		if ($hasNonDecoyMapping) {
			print OUTFILE $bufferWithoutDecoys;
		} else {
			print OUTFILE $bufferWithDecoys;
		}
		close(INFILE);
		close(OUTFILE);
		$infile = $outfile;


		open(INFILE, $infile) or die "ERROR: Unable to open for reading $infile ($!)";
		#### READ  coordinate_mapping.txt  ##############
		print "\nReading $infile\n";

		my $line;


		## hash with key = peptide_accession, value = peptide_sequence
		my %peptideAccession_peptideSequence = get_peptide_accession_sequence_hash(
				atlas_build_id => $atlas_build_id );

		#### Load information from the coordinate mapping file:
		#### into a series of arrays, one element per row
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
				## and for yeast and halo:
				if ( ($tmp_chromosome =~ /^S/) || ($organism_abbrev eq "Hbt")) {
						$tmp_chromosome = $columns[12];
				}
				### For Ens 32 and on, we are storing chromsome in column 8, so no need for parsing
				#if ( ($tmp_chromosome =~ /^(\d+)$/) || ($tmp_chromosome =~ /^((X)|(Y))$/) ) {
				#    $tmp_chromosome = $tmp_chromosome;
				#}
				### Additional match for the novel chromosomes such as 17_NT_079568 X_NT_078116
				#if ( ($tmp =~ /^(\d+)_NT_(\d+)$/) || ($tmp_chromosome =~ /^((X)|(Y))_NT_(\d+)$/) ) {
				#    $tmp_chromosome = $tmp_chromosome;

				push(@chromosome, $tmp_chromosome);
				push(@strand,$columns[9]);
				push(@start_in_chromosome,$columns[10]);
				push(@end_in_chromosome,$columns[11]);

				## hash with
				## keys =  peptide accession
				## values = space-separated string list of array indices (of the arrays above, holding pep_accession)
				if ( exists $index_hash{$pep_acc} ) {
						$index_hash{$pep_acc} = join " ", $index_hash{$pep_acc}, $ind;

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

    print "\nCalculating n_protein_mappings, n_genome_locations, and is_exon_spanning\n";

    ## looping through a peptide's array indices to calculate these:
    foreach my $tmp_ind_str (values ( %index_hash ) ) {  #key = peptide_accession

        #### Recreate an array of rows for this peptide from the space-separated string
        my @tmp_ind_array = split(" ", $tmp_ind_str);

        my (%protein_mappings_hash, %chromosomal_mappings_hash);
				my %distinct_proteins_hash;

        my $peptide = $peptide_accession[$tmp_ind_array[0]];
        my $protein;


        #### Loop over all the rows for this peptide
				my $first_index = -1;
        for (my $ii = 0; $ii <= $#tmp_ind_array; $ii++) {

            my $i_ind=$tmp_ind_array[$ii];
						if ($ii == 0) {
							$first_index = $i_ind;
						}

						$protein = $biosequence_name[$i_ind];

						my $chrom = $chromosome[$i_ind];
						my $start = $start_in_chromosome[$i_ind];
						my $end = $end_in_chromosome[$i_ind];
						my $coord_str = "$chrom:$start:$end";

						my $diff_coords = abs($start - $end);

						my $seq_length = 
							length($peptideAccession_peptideSequence{$peptide});

						## If entire sequence fits between coordinates, the protein has
						## redundant sequences.  If the sequence doesn't fit between
						## coordinates, it's exon spanning:
						if ( $diff_coords > 0 ) {
							if ( ($diff_coords + 1) != ($seq_length * 3) ) {
											$is_exon_spanning[$first_index] = 'Y';
							}

						#### Only count a chromosomal mapping the first time it is seen
							#### with different start/end coords for a protein
						#### FIXME: Note if a peptide legitimately maps to two different places
						#### in a protein, then this logic fails. Always has and continues to...

							#### 
							my @prev_coords = split(":", $protein_mappings_hash{$protein});
						if ( ! $protein_mappings_hash{$protein} ||
									 ($prev_coords[1] eq $prev_coords[2] )) {  # this means mapping wasn't stored last time
						$chromosomal_mappings_hash{$coord_str} = $protein;
						} 
					} 

						if (! defined $protein_mappings_hash{$protein} || $coord_str ne "0:0:0") {
								$protein_mappings_hash{$protein} = $coord_str;
						}

						#### If this protein is really a duplicate of another, then reset the
						#### protein name to the primary refernce for counting purposes
						if ($duplicate_proteins{$protein}) {
							$protein = $duplicate_proteins{$protein};
						}

							if (! defined $distinct_proteins_hash{$protein} || $coord_str ne "0:0:0") {
									$distinct_proteins_hash{$protein} = $coord_str;
							}
					}


        ## Count the number of chromosomal mappings and protein_mappings
        my $pep_n_genome_locations = keys( %chromosomal_mappings_hash);
        my $pep_n_protein_mappings = keys( %distinct_proteins_hash );
        my @different_coords = values( %chromosomal_mappings_hash);


        ## Assign values to all array members:
        foreach my $tmpind (@tmp_ind_array) {
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
    print "\nCalculating is_subpeptide_of\n";

    ## hash with key = peptide_accession, value = sub-peptide string list
    my %peptideAccession_subPeptide;
    
    my @peptideAccession_peptideSequence ='';
    foreach my $pep_acc (keys %peptideAccession_peptideSequence){
      push @peptideAccession_peptideSequence, "$pep_acc.$peptideAccession_peptideSequence{$pep_acc}";
    }
    foreach my $sub_pep_acc (keys %peptideAccession_peptideSequence){
      my $sub_pep = $peptideAccession_peptideSequence{$sub_pep_acc};
      my @matches = grep (/$sub_pep/, @peptideAccession_peptideSequence);
      foreach my $m (@matches){
        $m =~ /(.*)\.(.*)/;
        if($1 ne $sub_pep_acc){
          if ( exists $peptideAccession_subPeptide{$sub_pep_acc} ){
            $peptideAccession_subPeptide{$sub_pep_acc} =join ",", $peptideAccession_subPeptide{$sub_pep_acc},
                                                         $peptides{$1};
          }else{
            $peptideAccession_subPeptide{$sub_pep_acc} = $peptides{$1};
          }
        } 
      }     

    #foreach my $sub_pep_acc (keys %peptideAccession_peptideSequence){
    #   for my $super_pep_acc (keys %peptideAccession_peptideSequence){
    #        if ( ( index($peptideAccession_peptideSequence{$super_pep_acc}, 
    #            $peptideAccession_peptideSequence{$sub_pep_acc}) >= 0) 
    #            && ($super_pep_acc ne $sub_pep_acc) ) {
    #            if ( exists $peptideAccession_subPeptide{$sub_pep_acc} ){
    #                $str =
    #                    join ",", $peptideAccession_subPeptide{$sub_pep_acc},
    #                    $peptides{$super_pep_acc};
    #
    #            } else { 
    #                $peptideAccession_subPeptide{$sub_pep_acc} = $peptides{$super_pep_acc};
    #            }
    #       }
    #    }
			 if(length($peptideAccession_subPeptide{$sub_pep_acc}) > 1023){
				 print "truncate super_pep from $peptideAccession_subPeptide{$sub_pep_acc}\n";
				 my $str = substr ($peptideAccession_subPeptide{$sub_pep_acc} , 0, 1015);
				 $str =~ s/\,\w+$//;
				 $peptideAccession_subPeptide{$sub_pep_acc} = $str. ",...";
				 print "to $peptideAccession_subPeptide{$sub_pep_acc}\n";
			 }
    }
    undef @peptideAccession_peptideSequence;


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


    ## hash with key = peptide_accession, value = peptide_instance_id
    my %peptideAccession_peptideInstanceID = 
        get_peptide_accession_instance_id_hash( 
        atlas_build_id => $atlas_build_id );


    my %strand_xlate = ( '-' => '-',   '+' => '+',  '-1' => '-',
                        '+1' => '+',   '1' => '+',
			'0'  => '?',
    );


    #### Create a list of the number of peptide_mapping records
    #### for each peptide_instance for this build
    my $sql = qq~
           SELECT PI.peptide_instance_id,COUNT(peptide_mapping_id)
             FROM $TBAT_PEPTIDE_INSTANCE PI
             JOIN $TBAT_PEPTIDE_MAPPING PM ON ( PI.peptide_instance_id = PM.peptide_instance_id )
            WHERE atlas_build_id ='$ATLAS_BUILD_ID'
            GROUP BY PI.peptide_instance_id
       ~;
    my %existing_mapping_records = $sbeams->selectTwoColumnHash($sql);


    #### Loop over each row in the input file and insert the records
    my $previous_peptide_accession = 'none';
    my $mapping_record_count = 0;

    # Initiate transaction for this block
    initiate_transaction();
    for (my $row = 0; $row <= $#peptide_accession; $row++){

      #### Convert varied strand notations to single notation: +,-,?
      my $tmp = $strand_xlate{$strand[$row]}
            or die("ERROR: Unable to translate strand $strand[$row]");
      $strand[$row] = $tmp;

      #### Make sure we can resolve the biosequence_id
      my $biosequence_id = $biosequence_ids{$biosequence_name[$row]};
      if ( !$biosequence_id ) {
        # Battle known incrementing error
        if ( $biosequence_name[$row] =~ /\d+\.\d+$/ ) {
          # Try the trimmed version
          my $name = $biosequence_name[$row];
          $name =~ s/\.\d+$//;
          $biosequence_id = $biosequence_ids{$name};
          if ( !$biosequence_id ) {
            die("ERROR: BLAST matched biosequence_name $biosequence_name[$row] does not appear to be in the biosequence table!!");
          }
          # Cache the incremented version
          $biosequence_ids{$biosequence_name[$row]} = $biosequence_id;
        } else {
          die("ERROR: Unable to map biosequence_name $biosequence_name[$row] to a biosequence_id. Atlas build record references biosequence_set $args{biosequence_set_id}; probably you mapped this build against a different biosequence_set.");
        }
      }

      my $tmp_pep_acc = $peptide_accession[$row];
      my $peptide_id = $peptides{$tmp_pep_acc} ||
            die("ERROR: Wanted to insert data for peptide $peptide_accession[$row] ".
            "which is in the BLAST output summary, but not in the input ".
            "peptide file??");

      my $peptide_instance_id = $peptideAccession_peptideInstanceID{$tmp_pep_acc};


      #### If this is the first row for a peptide, then UPDATE peptide_instance record
      if ($tmp_pep_acc ne $previous_peptide_accession) {
        my %rowdata = (   ##   peptide_instance    table attributes
            n_genome_locations => $n_genome_locations[$row],
            is_exon_spanning => $is_exon_spanning[$row],
            n_protein_mappings => $n_protein_mappings[$row],
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
	    }

      #### If there are already peptide_mapping records
      if ($existing_mapping_records{$peptide_instance_id}) {
        #### If we're finished with the previous peptide, verify the count
        if ($tmp_pep_acc ne $previous_peptide_accession &&
              $previous_peptide_accession ne 'none') {
          unless ($mapping_record_count ==
            $existing_mapping_records{$peptideAccession_peptideInstanceID{$previous_peptide_accession}}) {
            die("ERROR: Peptide $previous_peptide_accession had ".
            $existing_mapping_records{$peptideAccession_peptideInstanceID{$previous_peptide_accession}}.
            " pre-existing peptide_mapping records, but we would have INSERTed $mapping_record_count. ".
            "This is a serious problem and may require a complete reload.");
          }
        }

        #### If there weren't already records, CREATE peptide_mapping record
      } else {
        my %rowdata = (   ##   peptide_mapping      table attributes
            peptide_instance_id => $peptide_instance_id,
            matched_biosequence_id => $biosequence_id,
            start_in_biosequence => $start_in_biosequence[$row],
            end_in_biosequence => $end_in_biosequence[$row],
            chromosome => $chromosome[$row],
            start_in_chromosome => $start_in_chromosome[$row],
            end_in_chromosome => $end_in_chromosome[$row],
            strand => $strand[$row],
        );
        $sbeams->updateOrInsertRow(
            insert=>1,
            table_name=>$TBAT_PEPTIDE_MAPPING,
            rowdata_ref=>\%rowdata,
            PK => 'peptide_mapping_id',
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );
      }

      #### If this is the first row for a peptide, then update the previous flag (must be done last)
      if ($tmp_pep_acc ne $previous_peptide_accession) {
          $previous_peptide_accession = $tmp_pep_acc;
          $mapping_record_count = 0;
      }
      $mapping_record_count++;

      if ($row/100 == int($row/100)) {
        print "$row...";
       # $sbeams->commit_transaction();
      }

    }  ## end  create peptide_mapping records and update peptide_instance records
    print "\n";

    # last commit, then reset to standard autocommit mode
    commit_transaction();
    reset_dbh();


   ## LAST TEST to assert that all peptides of an atlas in
   ## peptide_instance  are associated with a peptide_instance_sample record
   ## ALSO checks that atlas_build_sample is filled...uses this as start point
   if ($CHECKTABLES) {

       print "\nChecking peptide_instance_sample records\n";

       my $sql = qq~
           SELECT peptide_instance_id, sample_ids
           FROM $TBAT_PEPTIDE_INSTANCE
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
           FROM $TBAT_ATLAS_BUILD_SAMPLE
           WHERE atlas_build_id ='$ATLAS_BUILD_ID'
           AND record_status != 'D'
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
           FROM $TBAT_PEPTIDE_INSTANCE_SAMPLE
           WHERE sample_id IN ( $sample_id_string )
           AND record_status != 'D'
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
#  getMzXMLFileNamesFromPepXMLFileOld
#    12/30/08: replaced by tmf with a version that is slower
#     but simpler and more sure. It uses <msms_run_summary>
#     instead of <inputfile>.
#######################################################################
sub getMzXMLFileNamesFromPepXMLFileOld
{
    my %args = @_;
    my $infile = $args{infile} or die
        " need pepXML filepath ($!)";
    my $search_batch_dir_path = $args{search_batch_dir_path} or die
        " need search_batch_dir_path filepath ($!)";
    my ($msRunPepXMLFileName, $mzXMLFileName);
    my (@msRunPepXMLFileNames, @mzXMLFileNames);
    my $guessed_experiment_dir;

    unless(-e $infile) {
      print "could not find infile '$infile'.\n";
      return @mzXMLFileNames;
    }

    open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

    #### Try to glean a mzXML filename from each <inputfile>
    while (my $line = <INFILE>)
    {
        chomp($line);

        # File is another pepXML file
        if ($line =~ /^(\<inputfile name=\")(.+)(\/)(.+\.pep\.xml)\"\/\>/)
        {
           my $pepxml_dir = $2;
           my $pepxml_filename = $4;
           print "Found a nested pepXML file: $pepxml_dir\/$pepxml_filename\n";
           # Get mzXML filenames from this file
           push(@mzXMLFileNames,
            getMzXMLFileNamesFromPepXMLFile(infile => $pepxml_dir."\/".$pepxml_filename,
                                            search_batch_dir_path => $search_batch_dir_path));
           next;
        }

        # Filename includes at least two slashes
        elsif ($line =~ /^(\<inputfile name=\")(.+)(\/)(.+)(\/)(.+)(\")(\/\>)/)
        {
            my $exp_dir = $2;   #portion preceding second-to-last slash

            my $tmp = $6; #filename without path

            # truncate any .xml extension
            if ($tmp =~ /(.+)\.xml/)
            {
                $tmp = $1;
            }

	    #### Attempted workaround for more crazy Qstar files
	    if ($tmp =~ /\.(\d+)\.\d$/) {
	      next;
	    }

            # Assume mzXML file is of same basename as .xml file,
            # but one directory higher (in experiment dir)
            $mzXMLFileName = "$exp_dir/$tmp" . ".mzXML";

            push (@mzXMLFileNames, $mzXMLFileName);

        # Filename does not include at least two slashes
	} elsif ($line =~ /^\<inputfile name=\"(.+)\"/) {
            # Assume mzXML file is exactly the same, plus .mzXML
	    my $tmp = $1;
            $mzXMLFileName = "$tmp" . ".mzXML";
            push (@mzXMLFileNames, $mzXMLFileName);
	}

        #### Workaround for problem Qstar experiments, specifically
        #### /sbeams/archive/rossola/HUPO-ISB/b1-CIT_glyco_qstar
	if ($line =~ m~directory="(.+)/.+">~) {
	  $guessed_experiment_dir = $1;
	}
        if ($line =~ m~<inputfile name="(.+)\.xml"/>~) {
	  $mzXMLFileName = "$guessed_experiment_dir/$1.mzXML";
	  push (@mzXMLFileNames, $mzXMLFileName);
	}


	#### Finish parsing if we get to <roc> element and we've found something
        if ($line =~ /(\<roc)(.+)/ && $mzXMLFileName)
        {
            last;
        }

	#### Finish parsing when we reach <spectrum_query> for sure
        last if ($line =~ /\<spectrum_query/);

    }

    close(INFILE) or die "Cannot close $infile";


    #### There are often absolute paths in the pepXML, but if the experiments
    #### were not searched locally or were moved, these may well be wrong.
    #### Verify the locations and if inaccessible try the search_batch_dir
    for (my $i=0; $i< scalar(@mzXMLFileNames); $i++) {
      my $file = $mzXMLFileNames[$i];
      next if ( -e $file);
      my $barefilename = $file;
      $barefilename =~ s#.+/##;
      $file = "$search_batch_dir_path/$barefilename";
      if ( -e $file ) {
        $mzXMLFileNames[$i] = $file;
      } else {
        #### Fred Hutch processed files sometimes have fract in there
        $file =~ s/\.fract\.mzXML/.mzXML/;
        if ( -e $file ) {
          $mzXMLFileNames[$i] = $file;
        }else {
          print "ERROR: Unable to determine location of file '$mzXMLFileNames[$i]'\n";
          print "  (also tried: $file)\n";
        }
      }
    }
    return @mzXMLFileNames;
}


#######################################################################
#  getSpectrumXMLFileNamesFromPepXMLFile
#######################################################################
sub getSpectrumXMLFileNamesFromPepXMLFile
{
    my %args = @_;
    my $infile = $args{infile} or die
        " need pepXML filepath ($!)";
    my $search_batch_dir_path = $args{search_batch_dir_path} or die
        " need search_batch_dir_path filepath ($!)";
    my ($msRunPepXMLFileName, $spectrumXMLFileName);
    my (@msRunPepXMLFileNames, @spectrumXMLFileNames);
    my $guessed_experiment_dir;

    unless(-e $infile) {
      print "could not find infile '$infile'.\n";
      return @spectrumXMLFileNames;
    }

    if($infile =~ /\.gz$/){
      open(INFILE, "gunzip -c $infile|") or die "cannot open $infile for reading ($!)";
    }else{
      open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";
    }
    print "getting spectrum XML filenames from $infile\n";

    #### Try to glean an mzML or mzXML filename from each
    #### <msms_run_summary> element.
    while (my $line = <INFILE>)
    {
        chomp($line);

        if ($line =~ /^\<msms_run_summary base_name=\"(.+?)\".*raw_data="(.+?)"/)
        {
            my $basename = $1;
            my $extension = $2;

            if($extension eq 'gz'){
              $extension = '.mzML.gz';
            }
						#### Attempted workaround for more crazy Qstar files
						if ($basename =~ /\.(\d+)\.\d$/) {
							next;
						}
            $spectrumXMLFileName = "$basename$extension";
            #print "got spectrumXMLFileName $spectrumXMLFileName\n";
            push (@spectrumXMLFileNames, $spectrumXMLFileName);
	}
    }
    close(INFILE) or die "Cannot close $infile";

    return @spectrumXMLFileNames;
}


#######################################################################
# getSpectrumXMLFileNames -- get spectrum File Names used in the pepXML
# @param search_batch_dir_path absolute path to search_batch_dir
# @return mzXMLFileNames
#######################################################################
sub getSpectrumXMLFileNames
{
    my %args = @_;

    my $search_batch_dir_path = $args{search_batch_dir_path} or die
        " need search_batch_dir_path ($!)";

    ## to handle both older and newer formats:
    my ($msRunPepXMLFileName, $mzXMLFileName);
    my (@msRunPepXMLFileNames, @mzXMLFileNames);
    my $guessed_experiment_dir;

    my $infile="";

    #### Sometimes search_batch_dir_path is actually a file??
    if ($search_batch_dir_path =~ /\.xml/) {
      $infile = $search_batch_dir_path;

    #### Otherwise it's directory, try to find the file
    } else {
      $infile = $sbeamsMOD->findPepXMLFile(
        search_path => $search_batch_dir_path
      );
      if ( $infile eq "" ) {
	die("ERROR: Unable to auto-detect an interact file in $search_batch_dir_path");
      }
    }

    push(@mzXMLFileNames,
      getSpectrumXMLFileNamesFromPepXMLFile(infile => $infile,
            search_batch_dir_path => $search_batch_dir_path));
    my @foundmzXMLFiles;
    #### There are often absolute paths in the pepXML, but if the experimnts
    #### were not searched locally or were move, this may well be wrong.
    #### Verify the locations and if inaccessible try the search_batch_dir
    for (my $i=0; $i< scalar(@mzXMLFileNames); $i++) {
      my $file = $mzXMLFileNames[$i];
      if ( -e $file){push (@foundmzXMLFiles, $file);next;}
      my $barefilename = $file;
      $barefilename =~ s#.+/##;
      $file = "$search_batch_dir_path/$barefilename";
      if ( -e $file || -f $file) {
        push (@foundmzXMLFiles, $file);
      }else {
        #### Fred Hutch processed files sometimes have fract in there
        $file =~ s/\.fract\.mzXML/.mzXML/;
        if ( -e $file ) {
          push (@foundmzXMLFiles, $file);
        }elsif ( -e $file.".gz" ){
           push (@foundmzXMLFiles, $file.".gz"); 
        }else {
          print "ERROR: Unable to determine location of file '$mzXMLFileNames[$i]'\n";
          print "  (also tried: $file)\n";
        }
      }
    }
    return @foundmzXMLFiles;

}



###############################################################################
# insert_peptide
###############################################################################
sub insert_peptide {
  my %args = @_;

  my $rowdata_ref = $args{'rowdata_ref'} or die("need rowdata_ref");

  my $sequence = $rowdata_ref->{peptide_sequence};
  my $mw =  $massCalculator->getPeptideMass( mass_type => 'monoisotopic',
                                              sequence => $sequence );

  my $pI = $sbeamsMOD->calculatePeptidePI( sequence => $sequence );

  my $hp;
  if ($SSRCalculator->checkSequence($sequence)) {
    $hp = $SSRCalculator->TSUM3($sequence);
  }

  $rowdata_ref->{molecular_weight} = $mw;
  $rowdata_ref->{peptide_isoelectric_point} = $pI;
  $rowdata_ref->{SSRCalc_relative_hydrophobicity} = $hp;

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

  # Some peptides lack sibling peptide, convert nan => 0 to keep db happy
  if ( $rowdata_ref->{n_sibling_peptides} && $rowdata_ref->{n_sibling_peptides} =~ /nan|inf/ ) {
    $rowdata_ref->{n_sibling_peptides} = 0; 
  }

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

sub commit_transaction {
  my %args = @_;
  $sbeams->commit_transaction();
}

sub initiate_transaction {
  my %args = @_;
  print "Initiating transaction\n";
  $sbeams->initiate_transaction();
}

sub reset_dbh {
  my %args = @_;
  print "Resetting DBH\n";
  $sbeams->reset_dbh();
}


###############################################################################
# insert_modified_peptide_instance
###############################################################################
sub insert_modified_peptide_instance {
  my %args = @_;

  my $rowdata_ref = $args{'rowdata_ref'} or die("need rowdata_ref");

  # Some peptides lack sibling peptide, convert nan => 0 to keep db happy
  if ( $rowdata_ref->{n_sibling_peptides} && $rowdata_ref->{n_sibling_peptides} =~ /nan|inf/ ) {
    $rowdata_ref->{n_sibling_peptides} = 0; 
  }


  #### Calculate some mass values based on the sequence
  my $modified_peptide_sequence = $rowdata_ref->{modified_peptide_sequence};
  my $peptide_charge = $rowdata_ref->{peptide_charge};

  $rowdata_ref->{monoisotopic_peptide_mass} =
    $massCalculator->getPeptideMass(
				    sequence => $modified_peptide_sequence,
				    mass_type => 'monoisotopic',
				   );

  $rowdata_ref->{average_peptide_mass} =
    $massCalculator->getPeptideMass(
				    sequence => $modified_peptide_sequence,
				    mass_type => 'average',
				   );

  $rowdata_ref->{monoisotopic_parent_mz} =
    $massCalculator->getPeptideMass(
				    sequence => $modified_peptide_sequence,
				    mass_type => 'monoisotopic',
				    charge => $peptide_charge,
				   );

  $rowdata_ref->{average_parent_mz} =
    $massCalculator->getPeptideMass(
				    sequence => $modified_peptide_sequence,
				    mass_type => 'average',
				    charge => $peptide_charge,
				   );


  #### INSERT the record
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
      testonly=>$TESTONLY
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
# populateSampleRecordsWithSampleAccession - 
# update sample records that need accession numbers
#######################################################################
sub populateSampleRecordsWithSampleAccession
{

    ## get hash with key=sample_id, value=sample_accession
    ##                              (where values may be '')
    my %sampleId_sampleAccession_hash = getSampleIdSampleAccessionHash();


    ## accession root name and number of digits:
    my $root_name = "PAe";

    my $num_digits = 6;

    ## get last number used, will return 0 if none were set yet
    my $last_number_used = getLastNumberFromAccessions(
        hash_ref => \%sampleId_sampleAccession_hash,
        root_name => $root_name,
    ); 


    ## sort numerically by key:
    foreach my $sample_id (sort { $a <=> $b } keys %sampleId_sampleAccession_hash)
    {
 
        my $existing_accession = $sampleId_sampleAccession_hash{$sample_id};

        ## execute only if there isn't a sample_accession
        unless ($existing_accession )
        {
            my $next_number = $last_number_used + 1;

            my $next_number_length =  length($next_number);

            # exit with error if num digits needed is larger than num digits expected
            if ($next_number_length > $num_digits)
            {
                print "number of digits exceeds $num_digits\n";

                exit(0);
            }


            my $next_accession = $root_name;

            for (my $i=0; $i < ($num_digits - $next_number_length); $i++ )
            {
                $next_accession = $next_accession . "0";
            }

            $next_accession = $next_accession . $next_number;
     
            updateSampleRecord(
                sample_id => $sample_id,
                sample_accession => $next_accession,
            );
 
            $last_number_used = $last_number_used + 1;
 
        }
 
    }
 
}


###############################################################################
#  getSampleIdSampleAccessionHash
#
# @return hash with key = sample_id, value = sample_accession
###############################################################################
sub getSampleIdSampleAccessionHash
{
    my %args = @_;

    ## having to go around through peptide records, then using hash to
    ## store distinct returned rows
    my $sql = qq~
        SELECT sample_id, sample_accession
        FROM $TBAT_SAMPLE 
        WHERE record_status != 'D'
    ~;

    my %hash = $sbeams->selectTwoColumnHash($sql) or die
        "unable to execute statement:\n$sql\n($!)";

    return %hash;

}

#######################################################################
# getLastNumberFromAccessions
# @param ref to sample_id, sample_accession hash
# @param default_first_accession
# @return the latest accession in hash, or zero if none present
#######################################################################
sub getLastNumberFromAccessions
{
    my %args = @_;

    my $hash_ref = $args{hash_ref} or die "need hash_ref";

    my $root_name = $args{root_name} or die "need root_name";

    my %hash = %{$hash_ref};

    my $last_number = 0;

    my $last_written_accession;

    my $n = keys %hash;

    if ($n > 0)
    {
        ## sort by hash values in descending asciibetical order:
        my @sorted_keys = sort { $hash{$b} cmp $hash{$a} } keys %hash;

        if (@sorted_keys)
        {
            $last_written_accession = $hash{$sorted_keys[0]};

            $last_number = $last_written_accession;

            $last_number =~ s/($root_name)(\d+)$/$2/;

            $last_number = int($last_number);
        }

    }

    return $last_number;
}



###############################################################################
# updateSampleRecord -- update sample record...
# @param sample_id
# @param sample_accession
###############################################################################
sub updateSampleRecord 
{

    my %args = @_;

    my $sample_id = $args{sample_id} or die "need sample_id";

    my $sample_accession = $args{sample_accession} 
        or die "need sample_accession";


    my %rowdata = (  
        sample_accession => $sample_accession,
    );

    my $success = $sbeams->updateOrInsertRow(
        update=>1,
        table_name=>$TBAT_SAMPLE,
        rowdata_ref=>\%rowdata,
        PK => 'sample_id',
        PK_value => $sample_id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    return $success;

} 


#######################################################################
# getNextAccession - get next accession
# @param root_name - root of accession name (e.g. "PAe")
# @param num_digits - number of digits in accession string
# @param last_num_used - last number used
# @return next_accession
#######################################################################
sub getNextAccession
{
    my %args = @_;

    my $num_digits = $args{num_digits} or die "need num_digits";

    my $last_number_used = $args{last_num_used} or die "need last_num_used";

    my $root_name = $args{root_name} or die "need root_name";

    my $next_number = $last_number_used + 1;

    my $next_number_length =  length($next_number);

    # exit with error if num digits needed is larger than num digits expected
    if ($next_number_length > $num_digits)
    {
        print "number of digits exceeds $num_digits\n";

        exit(0);
    }


    my $next_accession = $root_name;

    for (my $i=0; $i < ($num_digits - $next_number_length); $i++ )
    {
        $next_accession = $next_accession . "0";
    }

    $next_accession = $next_accession . $next_number;

    return $next_accession;

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

