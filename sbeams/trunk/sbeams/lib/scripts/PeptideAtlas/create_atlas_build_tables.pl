#!/usr/local/bin/perl 

###############################################################################
# Program     : create_atlas_build_tables.pl 
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
             %table_columns
            );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ProtInfo;

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

use SBEAMS::PeptideAtlas::Spectrum;
my $spectra = new SBEAMS::PeptideAtlas::Spectrum;
$spectra->setSBEAMS($sbeams);
$spectra->setVERBOSE($VERBOSE);
$spectra->setTESTONLY($TESTONLY);

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
  --all
  --peptide                   
  --spectra                  Loads or updates the individual ptm spectra for a build
  --prot_info                 Loads or updates protein identifications for a build
  --organism_abbrev           Abbreviation of organism like Hs

  --atlas_build_name          Name of the atlas build (already entered by hand in
                              the atlas_build table) into which to load the data
  --default_sample_project_id default project_id  needed for auto-creation of tables (best to set
                              default to dev/private access and open access later)
  --table_columns             table column file ( _CREATETABLES.mssql)

 e.g.:  ./create_atlas_build_tables.pl --atlas_build_name \'Human_P0.9_Ens26_NCBI35\' --organism_abbrev \'Hs\' --default_sample_project_id 476 --all

 e.g.: ./load_atlas_build.pl --atlas_build_name \'TestAtlas\' --delete

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
        "peptide",'table_columns:s', 'all',
        "atlas_build_name:s", "organism_abbrev:s", "default_sample_project_id:s",
        "spectra", "prot_info",
    )) {

    die "\n$USAGE";

}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;

my $table_column_file = $OPTIONS{"table_columns"} || '';
$TESTONLY = 1 if ($CHECKTABLES);

my $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin');
my $current_contact_id = $sbeams->getCurrent_contact_id();
my $current_work_group_id = $sbeams->getCurrent_work_group_id();
print "current_contact_id=$current_contact_id current_work_group_id=$current_work_group_id\n";

if ($DEBUG) {
    print "Options settings:\n";
    print "  VERBOSE = $VERBOSE\n";
    print "  QUIET = $QUIET\n";
    print "  DEBUG = $DEBUG\n";
    print "  CHECKTABLES = $CHECKTABLES\n";

}

our %fhs;
our %pk_counter =();
our $dbprefix='';
our $spec_counter =0;

if (! -e $table_column_file){
	die "need table_column file\n$USAGE\n"; 
}
open (IN, "<$table_column_file") or die "cannot open $table_column_file\n";
my $table_name ='';
while (my $line = <IN>){
	chomp $line;
	next if ($line  =~ /(^$|^\)|^GO|KEY)/);
	$line =~ s/^\s+//;
	if ($line =~ /CREATE TABLE (.*).dbo.(\S+)\s+.*/){
		$dbprefix = $1;
		$table_name = $2;
		$pk_counter{$table_name} =1;
	}elsif($line =~ /(\S+)\s+.*/){
		push @{$table_columns{$table_name}} , $1;
	} 
}

#### table dir 
mkdir $dbprefix;

   
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
  #### Set the command-line options
  my $organism_abbrev = $OPTIONS{"organism_abbrev"} || '';
  my $atlas_build_name = $OPTIONS{"atlas_build_name"} || '';
  my $default_sample_project_id = $OPTIONS{"default_sample_project_id"} || '';

  #### Verify required parameters
  unless ($atlas_build_name) {
    print "\nERROR: You must specify an --atlas_build_name\n\n";
    die "\n$USAGE";
  }

  #### If there are any unresolved parameters, exit
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }

  ## get ATLAS_BUILD_ID:
  $ATLAS_BUILD_ID = get_atlas_build_id(atlas_build_name=>$atlas_build_name);
  my $atlas_build_directory = get_atlas_build_directory(
      atlas_build_id => $ATLAS_BUILD_ID,
    );
  chdir "$atlas_build_directory/../";

  #$sbeamsMOD->update_PA_table_variables($ATLAS_BUILD_ID);
  my @tables = qw (peptide_instance
                   peptide_mapping
									 peptide_instance_sample
									 peptide_instance_search_batch
									 modified_peptide_instance
									 modified_peptide_instance_sample
									 modified_peptide_instance_search_batch);

  if ($OPTIONS{all} || $OPTIONS{peptide}){
		print "generating \n\t". join("\n\t", @tables) . "\ntables\n";
    set_file_handler (tables=>\@tables); 
		loadAtlas( atlas_build_id=>$ATLAS_BUILD_ID,
					organism_abbrev => $organism_abbrev,
					default_sample_project_id => $default_sample_project_id,
			);
		 foreach my $table (@tables){
			 close $fhs{$table};
		 }
     if ( -e "$atlas_build_directory/peptide_NET_NMC.tsv"){
       my $file = "$atlas_build_directory/peptide_NET_NMC.tsv";
       write_peptide_net_nmc(file => $file, atlas_build_id=>$ATLAS_BUILD_ID); 
     }else{
       print "WARNING: missing $atlas_build_directory/peptide_NET_NMC.tsv file\n";
     } 

 
  }

  @tables = qw (spectrum_identification
                         spectrum_ptm_identification
                         spectrum);
  
  if ($OPTIONS{all}  || $OPTIONS{spectra}){
    print "generating \n\t". join("\n\t", @tables)."\ntables\n";
    set_file_handler (tables=>\@tables);

		populateSampleRecordsWithSampleAccession();
		## loading spectra
		my $atlas_build_directory = get_atlas_build_directory(
			atlas_build_id => $ATLAS_BUILD_ID,
		);
		loadBuildSpectra(
			atlas_build_id => $ATLAS_BUILD_ID,
			atlas_build_directory => $atlas_build_directory,
			organism_abbrev => $organism_abbrev,
		);
		#close file handler
		foreach my $table (@tables){
			close $fhs{$table};
		}
  }
  @tables = qw(biosequence_relationship
               protein_identification 
               biosequence_id_atlas_build_search_batch);
 
  #### If load or purge of protein information was requested
  if ($OPTIONS{all} || $OPTIONS{"prot_info"} ) {
    print "generating \n\t". join("\n\t", @tables)."\ntables\n";
    set_file_handler (tables=>\@tables);

		my $prot_info = new SBEAMS::PeptideAtlas::ProtInfo(\%fhs,\%pk_counter);
		my $atlas_build_directory = get_atlas_build_directory(
				atlas_build_id => $ATLAS_BUILD_ID,
			);
		$prot_info->setSBEAMS($sbeams);
		$prot_info->setVERBOSE($VERBOSE);
		$prot_info->setTESTONLY($TESTONLY);
		#if ($OPTIONS{"prot_info"}){
			$prot_info->loadBuildProtInfo(
				atlas_build_id => $ATLAS_BUILD_ID,
				atlas_build_directory => $atlas_build_directory,
			);
		#}else{
		#	$prot_info->update_protInfo_sampleSpecific(
		#		atlas_build_id => $ATLAS_BUILD_ID,
		#	);
		#}
		## biosequence_id_atlas_build_search_batch table;
    my %peptideAccession_absb = write_biosequence_id_atlas_build_search_batch (
                                atlas_build_id => $ATLAS_BUILD_ID);

    foreach my $table (@tables){
      close $fhs{$table};
    }

  }
  exit;
} # end main 


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
    my $table = $args{'table'} || $TBAT_PROTEIN_IDENTIFICATION;
    my $constraint = '';
    if ($table =~ /nextprot/i){
      if (! $args{'nextprot_mapping_id'}){
         die "ERROR: need nextprot_mapping_id\n";
      }
      $constraint = "AND nextprot_mapping_id =  $args{'nextprot_mapping_id'} ";
    }
    my $sql = qq~
		DELETE
		FROM $table
		WHERE atlas_build_id = '$atlas_build_id'
		$constraint
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

   my $sql = qq~
    DELETE
    FROM $TBAT_BIOSEQUENCE_ID_ATLAS_BUILD_SEARCH_BATCH 
    WHERE  ID in (
      SELECT BIABSB.ID 
      from $TBAT_BIOSEQUENCE_ID_ATLAS_BUILD_SEARCH_BATCH BIABSB
      JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
      ON (BIABSB.ATLAS_BUILD_SEARCH_BATCH_ID = ABSB.ATLAS_BUILD_SEARCH_BATCH_ID)
      WHERE ABSB.atlas_build_id = $atlas_build_id
    )
   ~;
   print "Purging BIOSEQUENCE_ID_ATLAS_BUILD_SEARCH_BATCH table ...\n";
   $sbeams->executeSQL($sql);

   print "Purging caching\n";
   $sql = qq~
     DELETE FROM $TB_CACHED_RESULTSET WHERE key_value = $atlas_build_id
   ~;
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
        infile => "$source_dir/../Experiments.list" );

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

    my $psb2asb = $sbeamsMOD->getProtSB2AtlasSB(build_id=>[$atlas_build_id]);
    my $inst_obs = $sbeamsMOD->cntObsFromIdentlist( identlist_file => "$source_dir/PeptideAtlasInput_concat.PAidentlist",
                                                key_type => 'peptide',
                                                psb2asb => $psb2asb );
      
    #### Load from .PAxml file
    my $PAxmlfile = $source_dir . "APD_" . $organism_abbrev . "_all.PAxml";

    if (-e $PAxmlfile) {
        ## get last pepide_instance of the build
        ## if exist, delete it and its child entries and start loading from here
        loadFromPAxmlFile(
            infile => $PAxmlfile,
            sbid_asbid_sid_hash_ref => \%proteomicsSBID_hash,
            atlas_build_id => $ATLAS_BUILD_ID,
            inst_obs => $inst_obs
        );
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
                ### check to see if there is update on sample publication
                my $query1 = qq~
                   SELECT distinct P.publication_id 
                   FROM $TBAT_ATLAS_SEARCH_BATCH ASB 
									 JOIN $TBAT_SAMPLE S ON (s.sample_id = ASB.sample_id) 
									 JOIN $TBPR_SEARCH_BATCH SB ON (SB.SEARCH_BATCH_ID = ASB.PROTEOMICS_SEARCH_BATCH_ID)
									 JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON (PE.EXPERIMENT_ID = SB.EXPERIMENT_ID)
									 JOIN $TB_PROJECT P ON (P.PROJECT_ID = PE.PROJECT_ID)
									 LEFT JOIN $TBAT_SAMPLE_PUBLICATION SP ON (SP.sample_id = S.sample_id)
									WHERE S.sample_id = $sample_id 
								~;
                my ($pid_str1,$pid_str2) ='';
                my @result1 = $sbeams->selectOneColumn($sql);
                $pid_str1 = join(",", sort {$a <=> $b} @result1) if (@result1);
                my $query2= qq~
                    select sample_publication_ids
                    from $TBAT_SAMPLE
                    where S.sample_id = $sample_id
                ~;
                my @result2 = $sbeams->selectOneColumn($sql);
                $pid_str2 = $result2[0] if (@result2);
                $pid_str2 =~ s/\s+//g;

                if ($pid_str1 ne $pid_str2){
                  print "Update publcation record for sample $sample_id, $pid_str1\n";
                  $sbeams->executeSQL("delete from $TBAT_SAMPLE_PUBLICATION where sample_id = $sample_id");
                  $sbeams->executeSQL("update $TBAT_SAMPLE set sample_publication_ids='$pid_str1' where sample_id = $sample_id");
                  foreach my $pid (@result1){
                     my %rowdata = (publication_id => $pid,
                                        sample_id => $sample_id);
                     my $success = $sbeams->updateOrInsertRow(
                                 insert =>1,
                                 table_name=>$TBAT_SAMPLE_PUBLICATION,
                                 rowdata_ref=>\%rowdata,
                                 PK => 'sample_publication_id',
                                 return_PK => 1,
                                 verbose=>$VERBOSE,
                                 testonly=>$TESTONLY,
                                );
                  }
                    
                }
 
            }
        }
        ## Lastly, if no sample_id, create one from protomics record.  
        ## if this is true, then also will be missing [atlas_search_batch] and 
        ## [atlas_search_batch_parameter] and [atlas_search_batch_parameter_set]
       if ( ($asb_exists eq "false") || ($sample_exists eq "false") ){
            $sql = qq~
                SELECT --distinct 
                       SB.search_batch_id, 
                       PE.experiment_name, 
                       PE.experiment_tag,
                       SB.data_location, 
                       P.project_id, 
                       P.publication_id, 
                       pe.protease_id, 
                       pe.organism_id,
                       pe.cell_line,
                       pe.tissue_cell_type,
                       pe.disease,
                       pe.treatment_physiological_state,
                       pe.sample_preparation,
                       pe.sample_category_id
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
                my ($sb_id, $exp_name, $exp_tag, $d_l, $p_id, $pub_id,$protease_id,$organism_id,
                    $cell_line,$tissue_cell_type,$disease,$treatment_physiological_state,
                    $sample_preparation,$sample_category_id) = @{$row};

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
                        sample_publication_ids => $pub_id,
                        protease_id =>  $protease_id,
                        organism_id => $organism_id,
                        cell_line => $cell_line,
                        tissue_cell_type => $tissue_cell_type, 
                        disease => $disease,
                        treatment_physiological_state => $treatment_physiological_state, 
                        sample_preparation => $sample_preparation,
                        sample_category_id => $sample_category_id,
                    );

                    $sample_id = insert_sample( rowdata_ref => \%rowdata );
                    print "#######insert  $sample_id $exp_tag $exp_name\n";
                    insert_sample_publications($sample_id, $pub_id) if ($pub_id);

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
        my ($atlas_build_search_batch_id, $atlas_build_sample_id);
        my $sql = qq~
          SELECT ATLAS_BUILD_SEARCH_BATCH_ID
          FROM $TBAT_ATLAS_BUILD_SEARCH_BATCH
          WHERE SAMPLE_ID = $sample_id
          AND ATLAS_BUILD_ID = $atlas_build_id
          AND ATLAS_SEARCH_BATCH_ID = $atlas_search_batch_id
        ~;
        @rows = $sbeams->selectOneColumn($sql);

        $atlas_build_search_batch_id =
            create_atlas_build_search_batch(
                atlas_build_id => $atlas_build_id,
                sample_id => $sample_id,
                atlas_search_batch_id => $atlas_search_batch_id,
        ) if (! @rows);

        ## create a [spectra_description_set] record
        $sql = qq~
          SELECT SPECTRA_DESCRIPTION_SET_ID
          FROM $TBAT_SPECTRA_DESCRIPTION_SET
          WHERE SAMPLE_ID = $sample_id
          AND ATLAS_BUILD_ID = $atlas_build_id
          AND ATLAS_SEARCH_BATCH_ID = $atlas_search_batch_id
        ~;
        @rows = $sbeams->selectOneColumn($sql);

        insert_spectra_description_set(
            atlas_build_id => $atlas_build_id,
            sample_id => $sample_id,
            atlas_search_batch_id => $atlas_search_batch_id,
            search_batch_dir_path =>$loading_sbid_searchdir_hash{$loading_sb_id}
        ) if (! @rows);


        ## create [atlas_build_sample] record
        $sql = qq~
          SELECT ATLAS_BUILD_SAMPLE_ID
          FROM $TBAT_ATLAS_BUILD_SAMPLE
          WHERE SAMPLE_ID = $sample_id
          AND ATLAS_BUILD_ID = $atlas_build_id
        ~;
        @rows = $sbeams->selectOneColumn($sql);
        $atlas_build_sample_id = createAtlasBuildSampleLink(
            sample_id => $sample_id,
            atlas_build_id => $atlas_build_id,
        ) if (! @rows);

    } ## end iterate over load 
    return %loaded_sbid_asbid_sid_hash;
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

    my ($nruns, $nspec) = $sbeamsMOD->getNSpecFromFlatFiles( search_batch_path => $proteomics_search_batch_path );

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
        n_runs => $nruns,
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
    my @params_files = ( "$search_batch_path/msfragger.params",
      "$search_batch_path/sequest.params", 
      "$search_batch_path/tandem.params",
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
##################################################################
### insert_sample_publications 
##################################################################

sub insert_sample_publications{
  my $sample_id = shift;
  my $publication_ids = shift;
  my @ids = split(",", $publication_ids);
  my $current_contact_id = $sbeams->getCurrent_contact_id;
  my $current_work_group_id = $sbeams->getCurrent_work_group_id;
  my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
  $year += 1900;
  $mon++;
  my $date = "$year\-$mon\-$mday $hour:$min:$sec";

  foreach my $id (@ids){
    my $sql = qq~
          select sample_publication_id
          FROM $TBAT_SAMPLE_PUBLICATION
          where sample_id = $sample_id and publication_id = $id;
        ~;
        my @result = $sbeams->selectOneColumn($sql);
      if (!@result){

       my %rowdata = (
          sample_id => $sample_id,
          publication_id => $id,
          date_created       =>  $date,
          created_by_id      =>  $current_contact_id,
          date_modified      =>  $date,
          modified_by_id     =>  $current_contact_id,
          owner_group_id     =>  $current_work_group_id,
          record_status      =>  'N',);
        my $sample_publication_id = $sbeams->updateOrInsertRow(
            table_name=>$TBAT_SAMPLE_PUBLICATION,
            insert=>1,
            rowdata_ref=>\%rowdata,
            PK => 'sample_publication_id',
            return_PK=>1,
            add_audit_parameters => 1,
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );
      }
  }


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
    ## insert sample publication 
    my @pids = split(",", $rowdata{sample_publication_ids});
    foreach my $pid (@pids){
      print "INFO[$METHOD]: insert publication $pid for sample $sample_id\n";
		  %rowdata = (    publication_id     =>  $pid,
										sample_id => $sample_id);
		  my $success = $sbeams->updateOrInsertRow(
						 insert =>1,
						 table_name=>$TBAT_SAMPLE_PUBLICATION,
						 rowdata_ref=>\%rowdata,
						 PK => 'sample_publication_id',
						 return_PK => 1,
						 verbose=>$VERBOSE,
						 testonly=>$TESTONLY,
						);
     }

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
    my $sql = qq~
        SELECT P.peptide_id, P.peptide_accession
        FROM $TBAT_PEPTIDE P 
        ~;

    my %hash = $sbeams->selectTwoColumnHash($sql) or die
        "unable to execute statement:\n$sql\n($!)";

    my %peptide_accession=();
    close $fhs{peptide_instance};
    open (IN, "<$dbprefix/peptide_instance.txt") or die "cannot open peptide_instance.txt\n";
    while (my $line = <IN>){
      my @tmp = split(/\t/, $line);
      my $peptide_instance_id = $tmp[0];
      my $peptide_id = $tmp[2]; 
      die "ERROR: peptide_id=$peptide_id not found in $TBAT_PEPTIDE\n" if (! $hash{$peptide_id});
      $peptide_accession{$hash{$peptide_id}} = $peptide_instance_id;
    }
    close IN;
    return %peptide_accession;

}


#######################################################################
# write_biosequence_id_atlas_build_search_batch 
#######################################################################
sub write_biosequence_id_atlas_build_search_batch { 
    my %args = @_;
    my $atlas_build_id = $args{atlas_build_id};

    my $sql = qq~
      select ASB.ATLAS_SEARCH_BATCH_ID, ABSB.ATLAS_BUILD_SEARCH_BATCH_ID
      FROM $TBAT_ATLAS_SEARCH_BATCH ASB 
      JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH  ABSB 
      ON    (ASB.ATLAS_SEARCH_BATCH_ID = ABSB.ATLAS_SEARCH_BATCH_ID)
      where atlas_build_id = $atlas_build_id
    ~;
   
    my %search_batch2build_search_batch = $sbeams->selectTwoColumnHash($sql);
 

    open (IN, "<$dbprefix/peptide_instance_search_batch.txt") or 
          die "cannot open $dbprefix/peptide_instance_search_batch.txt\n";
    my %pi_build_search_batch =();
    while (my $line = <IN>){
      my @tmp = split(/\t/, $line);
      my $peptide_instance_id = $tmp[1];
      my $search_batch_id = $tmp[2];
      my $build_search_batch = $search_batch2build_search_batch{$search_batch_id};
      $pi_build_search_batch{$peptide_instance_id}{$build_search_batch} =1;
    }
    close IN;

   $sql = qq~
      select BS.BIOSEQUENCE_ID 
      FROM $TBAT_BIOSEQUENCE BS
      JOIN $TBAT_ATLAS_BUILD A ON (A.biosequence_set_id = BS.biosequence_set_id)
      where A.atlas_build_id = $atlas_build_id
      AND BS.biosequence_name not like 'DECOY%'
      AND BS.biosequence_name not like 'CONTAM%' 
    ~;

    my @bioseqence_ids = $sbeams->selectOneColumn($sql);
    my %bioseqence_ids = map {$_=> 1} @bioseqence_ids;
    undef @bioseqence_ids;

    open (MAP, "<$dbprefix/peptide_mapping.txt") or
          die "cannot open $dbprefix/peptide_mapping.txt\n";

    my $fh = $fhs{biosequence_id_atlas_build_search_batch};
    my $counter = 1;
    while (my $line = <MAP>){
      my @tmp = split(/\t/, $line);
      my $peptide_instance_id = $tmp[1];
      my $matched_biosequence_id = $tmp[2];
      next if (not defined $bioseqence_ids{$matched_biosequence_id});
      foreach my $build_search_batch (keys %{$pi_build_search_batch{$peptide_instance_id}}){
        print $fh "$counter\t$matched_biosequence_id\t$build_search_batch\n";
        $counter++
      }
    }
    close $fh;
 
}


#######################################################################
# write_peptide_net_nmc
#######################################################################
sub write_peptide_net_nmc{
    my %args = @_;
    my $file = $args{file};
    my $atlas_build_id = $args{atlas_build_id};

    my $sql = qq~
        SELECT P.peptide_id, P.peptide_accession
        FROM $TBAT_PEPTIDE P
        ~;
    my %peptide_id = $sbeams->selectTwoColumnHash($sql);

    $sql = qq~
      SELECT BS.BIOSEQUENCE_ID, BS.BIOSEQUENCE_NAME
      FROM $TBAT_BIOSEQUENCE BS
      JOIN $TBAT_ATLAS_BUILD A ON (A.biosequence_set_id = BS.biosequence_set_id)
      where A.atlas_build_id = $atlas_build_id
      AND BS.biosequence_name not like 'DECOY%'
      AND BS.biosequence_name not like 'CONTAM%' 
    ~;

    my %bioseqence_ids = $sbeams->selectTwoColumnHash($sql);
    my %pi_peptide_id=();

    open (PI, "<$dbprefix/peptide_instance.txt") or
          die "cannot open $dbprefix/peptide_instance.txt\n";
    while (my $line = <PI>){
      my @tmp = split(/\t/, $line);
      my $peptide_instance_id = $tmp[0];
      my $peptide_id = $tmp[2];
      $pi_peptide_id{$peptide_instance_id} = $peptide_id;
      
    }
    close PI;
 
    my %peptide_mapping;
    open (MAP, "<$dbprefix/peptide_mapping.txt") or
          die "cannot open $dbprefix/peptide_mapping.txt\n";
    while (my $line = <MAP>){
      my @tmp = split(/\t/, $line);
      my $peptide_mapping_id = $tmp[0];
      my $peptide_instance_id = $tmp[1];
      my $matched_biosequence_id = $tmp[2];
      my $peptide_accession = $peptide_id{$pi_peptide_id{$peptide_instance_id}};  
      my $biosequence_name = $bioseqence_ids{$matched_biosequence_id};
      $peptide_accession =~ s/PAp0+//;
      $peptide_mapping{$biosequence_name}{$peptide_accession}{pi_id} = $peptide_instance_id;
      push @{$peptide_mapping{$biosequence_name}{$peptide_accession}{pm_id}}, $peptide_mapping_id;
    }
    close MAP;

    open (IN,"<$file") or die "cannot open $file\n";
    open (OUTPI, ">$dbprefix/peptide_instance_netupdate.tsv") or 
          die "cannot open $dbprefix/peptide_instance_netupdate.tsv\n";
    open (OUTPM, ">$dbprefix/peptide_mapping_netupdate.tsv") or
          die "cannot open $dbprefix/peptide_mapping_netupdate.tsv\n";
    print OUTPM "peptide_mapping_id\tprotease_ids\thighest_n_enzymatic_termini\t".
                "lowest_n_missed_cleavages\n";
    print OUTPI "peptide_instance_id\thighest_n_enzymatic_termini\tlowest_n_missed_cleavages\n";
    my %data=();
    my $counter =0; 
		while (my $line = <IN>){
			chomp $line;
			my ($pepacc, $pepseq, $prot,
					$enzyme_prot, $highest_n_enzymatic_termini_prot, $lowest_n_missed_cleavages_prot,
					$enzyme, $highest_n_enzymatic_termini, $lowest_n_missed_cleavages) = split("\t", $line);
			$pepacc =~ s/PAp0+//;
			my $pi_id = $peptide_mapping{$prot}{$pepacc}{pi_id};
			$data{$pi_id}{enzyme} = $enzyme;
			$data{$pi_id}{highest_n_enzymatic_termini} = $highest_n_enzymatic_termini;
			$data{$pi_id}{lowest_n_missed_cleavages} = $lowest_n_missed_cleavages;

			$counter++;
      foreach my $pm_id (@{$peptide_mapping{$prot}{$pepacc}{pm_id}}){
        print OUTPM "$pm_id\t$enzyme_prot\t$highest_n_enzymatic_termini_prot\t".
                    "$lowest_n_missed_cleavages_prot\n";

      }
      print "$counter..." if ($counter % 100000 == 0);
   }
   $counter =0;
   foreach my $id (keys %data){
    $counter++;
    print OUTPI "$id\t$data{$id}{highest_n_enzymatic_termini}\t$data{$id}{lowest_n_missed_cleavages}\n";
    print "$counter..." if ($counter % 10000 == 0);
  }
  close OUTPI;
  close OUTPM;
 
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
        FROM $TBAT_PEPTIDE P 
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
    my ($instrument_model_id, $instrument_model_name, $conversion_software_name,
    $conversion_software_version, $mzXML_schema, $n_spectra);
        $search_batch_dir_path =~ s/\s+//g;
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
        $conversion_software_name = $spectrum_parser->getConversion_software_name();
        $conversion_software_version = $spectrum_parser->getConversion_software_version();
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
        #foreach my $mzXMLFile (@mzXMLFileNames)
        #{
#            my $nspec = `grep 'msLevel="2"' $mzXMLFile | wc -l`;
        #    my $nspec = 500;
        #    $sum = $sum + $nspec;
            # don't print, since this is broken
            #print "  nspec=$nspec\n";
        #}

        $n_spectra = $sum;

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

    my %rowdata = (
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
    my (@peptide_preceding_residue,@peptide_following_residue);

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
    my %data_hash = ();
		while ($line = <INFILE>) {
				chomp($line);
				my @columns = split(/\t/,$line);
				my $pep_acc = $columns[0];
        push(@peptide_accession, $columns[0]);
        my $tmp_chromosome = $columns[10];

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
				## hash with
				## keys =  peptide accession
				## values = space-separated string list of array indices (of the arrays above, holding pep_accession)
				if ( exists $index_hash{$pep_acc} ) {
						$index_hash{$pep_acc} = join " ", $index_hash{$pep_acc}, $ind;

				} else {
					 $index_hash{$pep_acc} = $ind;
				}
        # 0.  peptide_accession
        # 1.  biosequence_name
        # 2.  start_in_biosequence
        # 3.  end_in_biosequence
        # 4.  peptide_preceding_residue
        # 5.  peptide_following_residue
        # 6.  tmp_chromosome
        # 7.  strand
        # 8.  start_in_chromosome
        # 9.  end_in_chromosome,
        # 10. n_protein_mappings
        # 11. n_genome_locations
        # 12. is_exon_spanning
        $columns[12] =~ s/'//g;
        my @data = ($columns[0],$columns[2],$columns[5],$columns[6],$columns[7],$columns[8],
                    $tmp_chromosome,$columns[11],$columns[12],$columns[13],1,1,'N');
        $data_hash{$ind} = join(",", @data);
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
            my @data = split(",", $data_hash{$i_ind});
            $protein = $data[1];
            my $chrom = $data[6];
            my $start = $data[8];
            my $end = $data[9];
            my $coord_str = "$chrom:$start:$end";
            my $diff_coords = abs($start - $end);
            my $seq_length =
              length($peptideAccession_peptideSequence{$peptide});

            ## If entire sequence fits between coordinates, the protein has
            ## redundant sequences.  If the sequence doesn't fit between
            ## coordinates, it's exon spanning:
            if ( $diff_coords > 0 ) {
              if ( ($diff_coords + 1) != ($seq_length * 3) ) {
                      #$is_exon_spanning[$first_index] = 'Y';
                     my @values = split(",", $data_hash{$first_index});
                     $values[12] = 'Y';
                     $data_hash{$first_index} = join(",", @values);
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
            #$n_protein_mappings[$tmpind] = $pep_n_protein_mappings;
            #$n_genome_locations[$tmpind] = $pep_n_genome_locations;
           my @values = split(",", $data_hash{$tmpind});
           $values[10] = $pep_n_protein_mappings;
           $values[11] = $pep_n_genome_locations;
           $data_hash{$tmpind} = join(",", @values);
           #print "$values[0] $pep_n_protein_mappings $pep_n_genome_locations \n";
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

   ### 2015-09-24 above logic fix below case also 
	 ##PAp00092783     10      ENSP00000321334 100     1064    0       160599568       160599597
	 ##PAp00092783     10      ENSP00000321334 100     152     0       160644915       160644944
	 ##PAp00092783     10      ENSP00000321334 100     266     0       160639368       160639397
	 ##PAp00092783     10      ENSP00000321334 100     380     0       160633821       160633850
	 ##PAp00092783     10      ENSP00000321334 100     38      0       160650406       160650435
	 ##PAp00092783     10      ENSP00000321334 100     494     0       160628275       160628304
	 ##PAp00092783     10      ENSP00000321334 100     608     0       160622731       160622760
	 ##PAp00092783     10      ENSP00000321334 100     722     0       160617185       160617214
	 ##PAp00092783     10      ENSP00000321334 100     836     0       160611630       160611659
	 ##PAp00092783     10      ENSP00000395608 100     311     0       160599568       160599597
	 ##PAp00092783     10      ENSP00000395608 100     83      0       160611630       160611659
	 ##PAp00092783     10      ENSP00000480589 100     197     0       160633821       160633850
	 ##PAp00092783     10      ENSP00000480589 100     311     0       160628275       160628304
	 ##PAp00092783     10      ENSP00000480589 100     425     0       160622731       160622760
	 ##PAp00092783     10      ENSP00000480589 100     539     0       160617185       160617214
	 ##PAp00092783     10      ENSP00000480589 100     83      0       160639368       160639397
   ## ---> n_genome_locations = 1 
   ## ---> n_protein_mappings = 3
   ## ---> is_exon_spanning   = n


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
    my $subpep_file = "$source_dir/is_subpep_of.tsv";
    if ( ! -e "$subpep_file" ) {
  
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
				 if(length($peptideAccession_subPeptide{$sub_pep_acc}) > 1023){
					 #print "truncate super_pep from $peptideAccession_subPeptide{$sub_pep_acc}\n";
					 my $str = substr ($peptideAccession_subPeptide{$sub_pep_acc} , 0, 1015);
					 $str =~ s/\,\w+$//;
					 $peptideAccession_subPeptide{$sub_pep_acc} = $str. ",...";
					 #print "to $peptideAccession_subPeptide{$sub_pep_acc}\n";
				 }
			}
			undef @peptideAccession_peptideSequence;
    }else{
			open (SUB ,"<$subpep_file" ) or die "cannot open $subpep_file\n";
			while (my $line = <SUB>){
				chomp $line;
				my($sub_pep_acc, $str ) = split("\t", $line);
        if ($str =~ /PAp/){
          my @peps =();
          foreach my $acc (split(",", $str)){
            #print "$acc $peptides{$acc}\n";
            push @peps, $peptides{$acc};
          }
          $str = join(",", @peps);
        }
				$peptideAccession_subPeptide{$sub_pep_acc} = $str;
        
				if(length($peptideAccession_subPeptide{$sub_pep_acc}) > 1023){
					 #print "truncate super_pep from $peptideAccession_subPeptide{$sub_pep_acc}\n";
					 my $str = substr ($peptideAccession_subPeptide{$sub_pep_acc} , 0, 1015);
					 $str =~ s/\,\w+$//;
					 $peptideAccession_subPeptide{$sub_pep_acc} = $str. ",...";
					 #print "to $peptideAccession_subPeptide{$sub_pep_acc}\n";
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

    open (PI, ">$dbprefix/peptide_instance_update.tsv");
    print PI "peptide_instance_id\tn_genome_locations\tis_exon_spanning\tn_protein_mappings\tis_subpeptide_of\n";
    ## hash with key = peptide_accession, value = peptide_instance_id
    my %peptideAccession_peptideInstanceID = get_peptide_accession_instance_id_hash( );
    print scalar keys %peptideAccession_peptideInstanceID ; 
    print "\n";

    my %strand_xlate = ( '-' => '-',   '+' => '+',  '-1' => '-',
                        '+1' => '+',   '1' => '+',
			'0'  => '?',
    );

    #### Loop over each row in the input file and insert the records
    my $previous_peptide_accession = 'none';
    my $mapping_record_count = 0;
    for (my $row = 0; $row <= $#peptide_accession; $row++){

     #### Convert varied strand notations to single notation: +,-,?
      my @data = split(",", $data_hash{$row});
      my $tmp = $strand_xlate{$data[7]} or die("ERROR: Unable to translate strand $data[7]");
      $data[7] = $tmp;

      #### Make sure we can resolve the biosequence_id
      my $biosequence_id = $biosequence_ids{$data[1]};
      if ( !$biosequence_id ) {
        # Battle known incrementing error
        if ( $data[1]=~ /\d+\.\d+$/ ) {
          # Try the trimmed version
          my $name = $data[1];
          $name =~ s/\.\d+$//;
          $biosequence_id = $biosequence_ids{$name};
          if ( !$biosequence_id ) {
            die("ERROR: BLAST matched biosequence_name $data[1] does not appear to be in the biosequence table!!");
          }
          # Cache the incremented version
          $biosequence_ids{$data[1]} = $biosequence_id;
        } else {
          die("ERROR: Unable to map biosequence_name $data[1] to a biosequence_id. Atlas build record references biosequence_set $args{biosequence_set_id}; probably you mapped this build against a different biosequence_set.");
        }
      }

      my $tmp_pep_acc = $peptide_accession[$row];

      #if( $tmp_pep_acc =~ /(PAp02122881|PAp01657280|PAp00972436|PAp00133923|PAp04626425)/){
      #    if ($tmp_pep_acc ne $previous_peptide_accession) {
      #      $previous_peptide_accession = $tmp_pep_acc;
      #      $mapping_record_count = 0;
      #   }
      #   next;
      #}
      #if(!  $peptides{$tmp_pep_acc} ){ print "$tmp_pep_acc\n";};

      my $peptide_id = $peptides{$tmp_pep_acc} ||
            die("ERROR: Wanted to insert data for peptide $peptide_accession[$row] ".
            "which is in the BLAST output summary, but not in the input ".
            "peptide file??");

      my $peptide_instance_id = $peptideAccession_peptideInstanceID{$tmp_pep_acc};
      if (! $peptide_instance_id){
        die "ERROR $tmp_pep_acc\n";
      }
     #### If this is the first row for a peptide, then UPDATE peptide_instance record
      if ($tmp_pep_acc ne $previous_peptide_accession) {
        print PI "$peptide_instance_id\t$data[11]\t$data[12]\t$data[10]\t$peptideAccession_subPeptide{$tmp_pep_acc}\n";
      }

			#### If there weren't already records, CREATE peptide_mapping record
		
			# peptide_instance_id => $peptide_instance_id,
			# matched_biosequence_id => $biosequence_id,
			# start_in_biosequence => $data[2], 
			# end_in_biosequence => $data[3], 
			# peptide_preceding_residue => $data[4],
			# peptide_following_residue => $data[5], 
			# chromosome => $data[6],
			# strand => $data[7], 
			# start_in_chromosome => $data[8], 
			# end_in_chromosome => $data[9], 
		
			# peptide_mapping_id  
			#  peptide_instance_id
			#  matched_biosequence_id    
			#  start_in_biosequence     
			#  end_in_biosequence      
			#  chromosome             
			#  start_in_chromosome   
			#  end_in_chromosome    
			#  strand                   
			#  peptide_preceding_residue 
			#  peptide_following_residue 
			#  protease_ids             
			#  highest_n_enzymatic_termini 
			#  lowest_n_missed_cleavages 

      my $fh = $fhs{peptide_mapping};
			print $fh "$pk_counter{peptide_mapping}\t$peptide_instance_id\t$biosequence_id\t".
               "$data[2]\t$data[3]\t".
               "$data[6]\t$data[8]\t$data[9]\t$data[7]\t".
							 "$data[4]\t$data[5]\t\t\t\n";
      $pk_counter{peptide_mapping}++;
      #### If this is the first row for a peptide, then update the previous flag (must be done last)
      if ($tmp_pep_acc ne $previous_peptide_accession) {
          $previous_peptide_accession = $tmp_pep_acc;
          $mapping_record_count = 0;
      }
      $mapping_record_count++;
      if ($row/1000 == int($row/1000)) {
        print "$row...";
      }
    }  ## end  create peptide_mapping records and update peptide_instance records
    print "\n";
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

  my $inst_obs = $args{'inst_obs'} or die " inst_obs  ($!)";

  ## hash with key = atlas_search_batch_id, value = sample_id
  my %sbid_asbid_sid_hash = %{ $sbid_asbid_sid_hash_ref };

  ## get hash with key=peptide_accession, value=peptide_id
  my %peptide_acc_id_hash = get_peptide_accession_id_hash();

  my %peptide_instance_hash =();
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
  #$CONTENT_HANDLER->{peptide_accession} = $peptide_accession;
 
  $CONTENT_HANDLER->{fh} = \%fhs;
  $CONTENT_HANDLER->{pk_counter} = \%pk_counter;
  $CONTENT_HANDLER->{current_contact_id} = $current_contact_id;
  $CONTENT_HANDLER->{current_work_group_id} = $current_work_group_id;
  $CONTENT_HANDLER->{peptide_instance_id} =\%peptide_instance_hash;
  $CONTENT_HANDLER->{inst_obs} = $inst_obs;

  $parser->parse(XML::Xerces::LocalFileInputSource->new($infile));

  return(1);

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
    if ($infile =~ /Combined_201306_Agilent-IT/){
      push @spectrumXMLFileNames, "/regis/sbeams/archive/jmalmstr/lg_scale_serum/SEC_OGE_II/Combined_201306_Agilent-IT/C0702-000032.mzXML";
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
            if ($extension eq 'mzBIN_calibrated'){
              $extension='.mzML';
              $basename =~ s/split.*tempdir\d+//;
            }
            if ($extension !~ /^\./){
              $extension = ".$extension";
            }
            if($extension eq 'gz' && $extension ne 'mzML.gz'){
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
					if ($file =~ /.gz/){
						 $file =~ s/.gz//;
          } 
          if ( -e $file){
             push (@foundmzXMLFiles, "$file");
          }elsif ( -e "$file.mzML" ) {
						 push (@foundmzXMLFiles, "$file.mzML");
					}elsif ( -e "$file.mzXML" ) {
						 push (@foundmzXMLFiles, "$file.mzXML");
					}elsif ( -e "$file.mzML.gz"){
							push (@foundmzXMLFiles, $file.".mzML.gz");
					}elsif ( -e "$file.mzXML.gz"){
							push (@foundmzXMLFiles, $file.".mzXML.gz");
					}else{
						print "ERROR: Unable to determine location of file '$mzXMLFileNames[$i]'\n";
						print "  (also tried: $file)\n";
					}
        }
      }
    }
    return @foundmzXMLFiles;

}
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

########### Spectrum_txt.pm ################ 
###############################################################################
# loadBuildSpectra -- Loads all spectra for specified build
###############################################################################
sub loadBuildSpectra {
  my $METHOD = 'loadBuildSpectra';
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $atlas_build_directory = $args{atlas_build_directory}
    or die("ERROR[$METHOD]: Parameter atlas_build_directory not passed");

  my $organism_abbrev = $args{organism_abbrev}
    or die("ERROR[$METHOD]: Parameter organism_abbrev not passed");

  #### First try to find the PAidentlist file
  my $filetype = 'PAidentlist';
  my $expected_n_columns = 21;
  my $peplist_file = "$atlas_build_directory/".
    "PeptideAtlasInput_concat.PAidentlist";

  #### Else try the older peplist file
  unless (-e $peplist_file) {
    die "ERROR: Unable to find PAidentlist file '$peplist_file'\n";
  }


  #### Find and open the input peplist file
  unless (open(INFILE,$peplist_file)) {
    print "ERROR: Unable to open for read file '$peplist_file'\n";
    return;
  }

  #### Loop through all spectrum identifications and load
  my @columns;
  my $pre_search_batch_id;
  while ( my $line = <INFILE>) {
    chomp $line;
    @columns = split(/\t/,$line, -1);
    unless (scalar(@columns) == $expected_n_columns || scalar(@columns) == 22) {
				die("ERROR: Unexpected number of columns (".
				scalar(@columns)."!=$expected_n_columns) in\n$line\n");
    }

    my ($search_batch_id,$spectrum_name,$peptide_accession,$peptide_sequence,
        $preceding_residue,$modified_sequence,$following_residue,$charge,
        $probability,$massdiff,$protein_name,$proteinProphet_probability,
        $n_proteinProphet_observations,$n_sibling_peptides,
        $SpectraST_probability, $ptm_sequence,$precursor_intensity,
        $total_ion_current,$signal_to_noise,$retention_time_sec,$chimera_level,$ptm_lability);
		($search_batch_id,
			$spectrum_name,
			$peptide_accession,
			$peptide_sequence,
			$preceding_residue,
			$modified_sequence,
			$following_residue,
			$charge,
			$probability,
			$massdiff,
			$protein_name,
			$proteinProphet_probability,
			$n_proteinProphet_observations,
			$n_sibling_peptides,
			$precursor_intensity,
			$total_ion_current,
			$signal_to_noise,
			$retention_time_sec,
			$chimera_level,
      $ptm_sequence,
      $ptm_lability) = @columns;
		  #### Correction for occasional value '+-0.000000'
      $massdiff =~ s/\+\-//;
    
    insertSpectrumIdentification(
       atlas_build_id => $atlas_build_id,
       search_batch_id => $search_batch_id,
       modified_sequence => $modified_sequence,
       ptm_sequence => $ptm_sequence,
       ptm_lability => $ptm_lability,
       charge => $charge,
       probability => $probability,
       protein_name => $protein_name,
       spectrum_name => $spectrum_name,
       massdiff => $massdiff,
			 precursor_intensity => $precursor_intensity,
			 total_ion_current => $total_ion_current,
			 signal_to_noise => $signal_to_noise,
       retention_time_sec => $retention_time_sec,
       chimera_level => $chimera_level, 
       );
    if($pre_search_batch_id ne $search_batch_id){
      print "\nsearch_batch_id: $pre_search_batch_id, $spec_counter records processed\n";
    }
    $pre_search_batch_id = $search_batch_id;
    #print "$spec_counter... " if ($spec_counter %10000 == 0);
  }
} # end loadBuildSpectra

###############################################################################
# insertSpectrumIdentification --
###############################################################################
sub insertSpectrumIdentification {
  my $METHOD = 'insertSpectrumIdentification';
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");
  my $search_batch_id = $args{search_batch_id}
    or die("ERROR[$METHOD]: Parameter search_batch_id not passed");
  my $modified_sequence = $args{modified_sequence}
    or die("ERROR[$METHOD]: Parameter modified_sequence not passed");
  my $ptm_sequence = $args{ptm_sequence} || ''; 
  my $ptm_lability = $args{ptm_lability} || '';
  my $charge = $args{charge}
    or die("ERROR[$METHOD]: Parameter charge not passed");
  my $protein_name = $args{protein_name}
    or die("ERROR[$METHOD]: Parameter protein_name not passed");
  my $spectrum_name = $args{spectrum_name}
    or die("ERROR[$METHOD]: Parameter spectrum_name not passed");

  my $massdiff = $args{massdiff};
  my $chimera_level = $args{chimera_level}; 
  my $probability = $args{probability};
  die("ERROR[$METHOD]: Parameter probability not passed") if($probability eq '');
  my $precursor_intensity = $args{precursor_intensity};
  my $total_ion_current = $args{total_ion_current};
  my $signal_to_noise = $args{signal_to_noise};
  my $retention_time_sec = $args{retention_time_sec};
  #return if ($modified_sequence =~ /[JUO]/);
  our $counter;

  #### Get the modified_peptide_instance_id for this peptide
  my $modified_peptide_instance_id = get_modified_peptide_instance_id(
    atlas_build_id => $atlas_build_id,
    modified_sequence => $modified_sequence,
    charge => $charge,
  );

  #### Get the sample_id for this search_batch_id
  my $sample_id = $spectra->get_sample_id(
    proteomics_search_batch_id => $search_batch_id,
  );

  #### Get the atlas_search_batch_id for this search_batch_id
  my $atlas_search_batch_id = $spectra->get_atlas_search_batch_id(
    proteomics_search_batch_id => $search_batch_id,
  );

  #### If not, INSERT it
	my $spectrum_id = insertSpectrumRecord(
		sample_id => $sample_id,
		spectrum_name => $spectrum_name,
		proteomics_search_batch_id => $search_batch_id,
		chimera_level => $chimera_level,
		precursor_intensity => $precursor_intensity,
		total_ion_current => $total_ion_current,
		signal_to_noise => $signal_to_noise,
		retention_time_sec => $retention_time_sec,
	);
	$counter++;
	print "$counter..." if ($counter/1000 == int($counter/1000));


  #### If not, save to array and insert later 
  my $fh = $fhs{spectrum_identification};
  print $fh "$pk_counter{spectrum_identification}\t$modified_peptide_instance_id\t$probability\t$spectrum_id\t$atlas_search_batch_id\t$massdiff\n";

  if ($ptm_sequence){
		$fh = $fhs{spectrum_ptm_identification};
    my @ptm_sequences = split(",", $ptm_sequence);
    my @ptm_labilities = split(",",$ptm_lability);
    
    for (my $i=0; $i<=$#ptm_sequences;$i++){
      my $sequence = $ptm_sequences[$i];
      my $lability = $ptm_labilities[$i];
      $sequence =~ /\[(\S+)\](.*)/;
		  print $fh "$pk_counter{spectrum_ptm_identification}\t$pk_counter{spectrum_identification}\t$2\t$1\t$lability\n";
      $pk_counter{spectrum_ptm_identification}++;
    }
  }
  $pk_counter{spectrum_identification}++;
} # end insertSpectrumIdentification


###############################################################################
# get_modified_peptide_instance_id --
###############################################################################
sub get_modified_peptide_instance_id {
  my $METHOD = 'get_modified_peptide_instance_id';
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");
  my $modified_sequence = $args{modified_sequence}
    or die("ERROR[$METHOD]: Parameter modified_sequence not passed");
  my $charge = $args{charge}
    or die("ERROR[$METHOD]: Parameter charge not passed");

  #### If we haven't loaded all modified_peptide_instance_ids into the
  #### cache yet, do so
  our %modified_peptide_instance_ids;
  unless (%modified_peptide_instance_ids) {
    print "[INFO] Loading all modified_peptide_instance_ids...\n";
    open (MPI, "<PeptideAtlas_build$atlas_build_id/modified_peptide_instance.txt") or die "cannot open modified_peptide_instance.txt\n";
    #my $line = <MPI>;
    while (my $line = <MPI>){
       my @row =  split("\t", $line);
       my $modified_peptide_instance_id = $row[0];
       my $charge = $row[3];
       my $modified_sequence = $row[2];
       $modified_peptide_instance_ids{$row[3]}{$row[2]} = $modified_peptide_instance_id;
    }
    close MPI;
  }

  #### Lookup and return modified_peptide_instance_id
  #$modified_sequence =~ s/\([\d\.]+\)//g;
  if ($modified_peptide_instance_ids{$charge}{$modified_sequence}) {
    return($modified_peptide_instance_ids{$charge}{$modified_sequence});
  };

  die("ERROR: Unable to find '$modified_sequence/$charge' in modified_peptide_instance_ids hash. ".
      "This should never happen.");

} # end get_modified_peptide_instance_id


###############################################################################
# insertSpectrumRecord --
###############################################################################
sub insertSpectrumRecord {
  my $METHOD = 'insertSpectrumRecord';
  my %args = @_;

  #### Process parameters
  my $sample_id = $args{sample_id}
    or die("ERROR[$METHOD]: Parameter sample_id not passed");
  my $spectrum_name = $args{spectrum_name}
    or die("ERROR[$METHOD]: Parameter spectrum_name not passed");
  my $proteomics_search_batch_id = $args{proteomics_search_batch_id}
    or die("ERROR[$METHOD]: Parameter proteomics_search_batch_id not passed");
  my $chimera_level = $args{chimera_level} ;
  my $precursor_intensity = $args{precursor_intensity};
  my $total_ion_current = $args{total_ion_current};
  my $signal_to_noise = $args{signal_to_noise};
  my $retention_time_sec = $args{retention_time_sec};


  #### Parse the name into components
  my ($fraction_tag,$start_scan,$end_scan);
  if ($spectrum_name =~ /^(.+)\.(\d+)\.(\d+)\.\d$/) {
    $fraction_tag = $1;
    $start_scan = $2;
    $end_scan = $3;
  }
  elsif($spectrum_name  =~ /^(.+)\..*\s+(\d+).*\d\)$/) {
    $fraction_tag = $1;
    $start_scan = $2;
    $end_scan = $2;
  }
  else {
    die("ERROR: Unable to parse fraction name from '$spectrum_name'");
  }

  my $spectrum_id = $pk_counter{spectrum};
  my $fh = $fhs{spectrum};
  print $fh "$spectrum_id\t$sample_id\t$spectrum_name\t$start_scan\t$end_scan\t".
                     "-1\t$precursor_intensity\t$total_ion_current\t\t\t\t\t\t\t".
                     "$chimera_level\t$signal_to_noise\t$retention_time_sec\n";

  #### Add it to the cache
  #our %spectrum_ids;
  #my $key = "$sample_id$spectrum_name";
  #$spectrum_ids{$key} = $spectrum_id;
  $pk_counter{spectrum}++;
  return($spectrum_id);

} # end insertSpectrumRecord

###############################################################################
# get_spectrum_identification_id --
###############################################################################
sub get_spectrum_identification_id {
  my $METHOD = 'get_spectrum_identification_id';
  my %args = @_;

  #### Process parameters
  my $spectrum_id = $args{spectrum_id}
    or die("ERROR[$METHOD]: Parameter spectrum_id not passed");
  my $atlas_search_batch_id = $args{atlas_search_batch_id}
    or die("ERROR[$METHOD]: Parameter atlas_search_batch_id not passed");
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  #### If we haven't loaded all spectrum_identification_ids into the
  #### cache yet, do so
  our %spectrum_identification_ids;
  unless (%spectrum_identification_ids){
    print "\n[INFO] Loading all spectrum_identification_ids ...\n";
    my $sql = qq~
      SELECT SI.atlas_search_batch_id,SI.spectrum_id, SI.spectrum_identification_id
        FROM $TBAT_SPECTRUM_IDENTIFICATION SI
        JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI
             ON ( SI.modified_peptide_instance_id = MPI.modified_peptide_instance_id )
        JOIN $TBAT_PEPTIDE_INSTANCE PEPI
             ON ( MPI.peptide_instance_id = PEPI.peptide_instance_id )
       WHERE PEPI.atlas_build_id = '$atlas_build_id'
    ~;

    my $sth = $sbeams->get_statement_handle( $sql );
    my $n = 0;
    #### Create a hash out of it
    while ( my $row = $sth->fetchrow_arrayref() ) {
      $spectrum_identification_ids{$row->[0]}{$row->[1]} = $row->[2];
      $n++;
    }

    print "       $n loaded...\n";
  }
  #### Lookup and return spectrum_identification_id
  if ( $spectrum_identification_ids{$atlas_search_batch_id}{$spectrum_id}){
    return $spectrum_identification_ids{$atlas_search_batch_id}{$spectrum_id}; 
  };

  return();

} # end get_spectrum_identification_id

########################################################################### 
## file handler
###########################################################################
sub set_file_handler {
  my %args =@_;
  my $tables = $args{tables};
  foreach my $table (@$tables){
    my $fh = FileHandle->new();
    open ($fh , ">$dbprefix/$table.txt") or die "cannot open $dbprefix/$table.txt file for writing\n";
    die "ERROR no column info for $table\n" if (! $table_columns{$table});
    $fhs{$table} = $fh;
  }

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
 
