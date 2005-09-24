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

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $ATLAS_BUILD_ID 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TESTVARS $CHECKTABLES
            );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


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

  --builds_directory     path to directory containing all builds

 e.g.:  ./load_atlas_build.pl --atlas_build_name \'Human_P0.9_Ens26_NCBI35\' --organism_abbrev \'Hs\' --purge --load --builds_directory \'/ex1/PeptideAtlas/builds\'

 e.g.: ./load_atlas_build.pl --atlas_build_name \'TestAtlas\' --delete
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "testvars","delete", "purge", "load", "check_tables",
        "atlas_build_name:s", "organism_abbrev:s", "builds_directory:s"
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

      my $builds_directory = $OPTIONS{"builds_directory"} || die 
          "$USAGE\n need -builds_directory\n";

      ## check that base directory exists
      unless ( -d $builds_directory ) {
    
          die "\n Can't find $builds_directory\n";

      }


      loadAtlas( atlas_build_id=>$ATLAS_BUILD_ID,
          organism_abbrev => $organism_abbrev,
          builds_directory => $builds_directory
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
###############################################################################
sub get_atlas_build_id {

    my %args = @_;

    my $name = $args{atlas_build_name} or die "need atlas build name($!)";

    my $id;

    my $sql = qq~
        SELECT atlas_build_id,biosequence_set_id
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_name = '$name'
        AND record_status != 'D'
    ~;

    ($id) = $sbeams->selectOneColumn($sql) or
        die "\nERROR: Unable to find the atlas_build_name". 
        $name."with $sql\n\n";

    return $id;

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

   my $table_name = "atlas_build";
   my $database_name = "Peptideatlas.dbo.";
   my $full_table_name = "$database_name$table_name";

   my %table_child_relationship = (
      atlas_build => 'peptide_instance(C),atlas_build_sample(C)',
      peptide_instance =>'peptide_mapping(C),peptide_instance_sample(C)',
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
# @param builds_directory
###############################################################################
sub loadAtlas {

    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'} or die
        " need atlas_build_id ($!)";

    my $organism_abbrev = $args{'organism_abbrev'} or die
        " need organism_abbrev ($!)";

    my $builds_directory = $args{'builds_directory'} or die
        " need builds_directory ($!)";

    $builds_directory = "$builds_directory/";


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



    ## get $relative_path  from atlas_build_id:data_path
    ## get APD_id          from atlas_build_id:APD_id
    ## get biosequence_set_id from atlas_build_id:biosequence_set_id
    my ($relative_path, $APD_id, $biosequence_set_id);

    my $sql = qq~
        SELECT data_path, APD_id, biosequence_set_id
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_id = '$atlas_build_id'
         AND record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql)
        or die "Couldn't find data_path, APD_id, biosequence_set_id ".
        "for atlas_build_id=$atlas_build_id \n$sql\n($!)";

    foreach my $row (@rows) {

         ($relative_path, $APD_id, $biosequence_set_id) = @{$row};

    }



    ## set source_dir as full path to data:
    my $source_dir = $builds_directory.$relative_path;
     
    unless ( -e $source_dir) {

        die "\n Can't find path $relative_path relative to ".
            " base directory $builds_directory\n";

    }

  

    ## build atlas:
    print "Building atlas $atlas_build_id: \n";
  
    buildAtlas(atlas_build_id => $atlas_build_id,
               biosequence_set_id => $biosequence_set_id,
               source_dir => $source_dir,
               organism_abbrev => $organism_abbrev,
               APD_id => $APD_id,
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
 
    my $APD_id = $args{'APD_id'} or die "need APD_id ($!)";



    ## get hash with key = search_batch_id, value = sample_id
    ## and create sample records if they don't already exist
    my %sample_id_hash = get_sample_id_hash( atlas_build_id => $atlas_build_id,
        APD_id => $APD_id
    );



    #### set infile to APD tsv file
    my $infile = $source_dir . "/APD_" . $organism_abbrev . "_all.tsv";

    ## read APD file, write peptide records, 
    ## initialize peptide_instance, and peptide_instance_sample
    readAPD_writeRecords( infile => $infile, 
        sample_id_hash_ref => \%sample_id_hash, 
        atlas_build_id => $ATLAS_BUILD_ID,
    );


    ## set infile to coordinate mapping file
    $infile = "$source_dir/coordinate_mapping.txt";

    readCoords_updateRecords_calcAttributes(
        infile => $infile,
        sample_id_hash_ref => \%sample_id_hash, 
        atlas_build_id => $ATLAS_BUILD_ID,
        biosequence_set_id => $biosequence_set_id,
        organism_abbrev => $organism_abbrev
    );


}# end buildAtlas



###############################################################################
# get_sample_id_hash -- get hash with key= search_batch_id, value=sample_id
#    creates smaple records if they don't exist yet
# @param atlas_build_id
# @param APD_id
###############################################################################
sub get_sample_id_hash {

    my %args = @_;

    my $atlas_build_id = $args{atlas_build_id} or die
        " need atlas_build_id ($!)";

    my $APD_id = $args{APD_id} or die
        " need APD_id ($!)";

    my $sb_list = get_search_batch_id_list( APD_id => $APD_id );
        

    ## fill in hash values with sample_id's
    my %sb_s_hash = get_search_batch_sample_id_hash( 
        sb_list => $sb_list );


    return %sb_s_hash;

}

###############################################################################
# get_search_batch_id_list -- get search_batch_id_list
###############################################################################
sub get_search_batch_id_list {

    my %args = @_;

    my $APD_id = $args{APD_id} or die "need APD_id ($!)";


    my $sb_list;


    ## get the list of search batch ID's from the APD record:
    ## (experiment_list is actually search batch id's)
    my $sql = qq~
       SELECT experiment_list
       FROM $TBAPD_PEPTIDE_SUMMARY
       WHERE peptide_summary_id = '$APD_id'
    ~;

    ($sb_list) = $sbeams->selectOneColumn($sql) or die 
        "could not find search_batch_id list for APD_id = ".
        "$APD_id ? \n $sql \n ($!)";

    return $sb_list;

}


###############################################################################
#  get_search_batch_sample_id_hash --  get hash with key=search batch id
#      value = sample id
# @param $search_batch_id_list
###############################################################################
sub get_search_batch_sample_id_hash {

    my %args = @_;

    my %hash;
  
    my $search_batch_id_list = $args{sb_list} or die "need search batch list ($!)";

    #### Get existing sample_id's in peptide atlas:
    my $sql = qq~
        SELECT search_batch_id, sample_id
        FROM $TBAT_SAMPLE
        WHERE search_batch_id IN ($search_batch_id_list)
        AND record_status != 'D'
    ~;

    %hash = $sbeams->selectTwoColumnHash($sql) or die
        "unable to execute statement:\n$sql\n($!)";

    return %hash;
     
}


###############################################################################
#  createSampleRecords -- create sample record and atlas_build_sample record
#     with minimum info and some default settings 
#     [ specifically: is_public='N', project_id='475' ]
# @param search_batch_id
# @param atlas_build_id
###############################################################################
sub createSampleRecords {

    my %args = @_;

    my $sb_id = $args{search_batch_id} or die "need search_batch_id ($!)";

    my $atlas_build_id = $args{atlas_build_id} or 
        die "need atlas_build_id ($!)";

    my ($sample_tag,$sample_title, $sample_id, $sample_description);
    

    ## get experiment_tag, experiment_name, $TB_ORGANISM.organism_name
    my $sql = qq~
        SELECT PE.experiment_tag, PE.experiment_name, O.organism_name
        FROM $TBPR_PROTEOMICS_EXPERIMENT PE
        JOIN $TB_ORGANISM O
        ON ( PE.organism_id = O.organism_id )
        JOIN $TBPR_SEARCH_BATCH SB
        ON ( PE.experiment_id = SB.experiment_id)
        WHERE SB.search_batch_id = '$sb_id'
        AND PE.record_status != 'D'
    ~;
        
    my @rows = $sbeams->selectSeveralColumns($sql) or die
        "Could not find proteomics experiment record for ".
        " search batch id $sb_id \n$sql\n ($!)";


    foreach my $row (@rows) 
    {

        my ($tmp_experiment_tag, $tmp_experiment_name, $tmp_organism_name) = @{$row};

        $sample_tag = $tmp_experiment_tag;

        $sample_title = $tmp_experiment_name;

        $sample_description = $tmp_organism_name;

    }


    ## assume is_public = 'N' and project_id='475' for public PA
    my %rowdata = ( ##   sample      some of the table attributes:
        search_batch_id => $sb_id,
        sample_tag => $sample_tag,
        sample_title => $sample_title,
        sample_description => $sample_description,
        is_public => 'N',
        project_id => '475',
    );


    ## create a sample record:
    my $tmp_sample_id = $sbeams->updateOrInsertRow(
        table_name=>$TBAT_SAMPLE,
        insert=>1,
        rowdata_ref=>\%rowdata,
        PK => 'sample_id',
        return_PK=>1,
        add_audit_parameters => 1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    $sample_id = $tmp_sample_id;


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

    return $sample_id;


} ## end createSampleRecords


#######################################################################
#  get_peptide_accession_id_hash -- get hash
#      key = peptide accession
#      value = peptide_id
#######################################################################
sub get_peptide_accession_id_hash {

    my %hash;

    #### Get the current list of peptides in the peptide table
    my $sql = qq~
        SELECT peptide_accession,peptide_id
        FROM $TBAT_PEPTIDE
        ~;

    %hash = $sbeams->selectTwoColumnHash($sql) or die
        "unable to execute statement:\n$sql\n($!)";


    return %hash;

}

#######################################################################
#  get__peptide_accession_instance_id_hash -- get hash
#      key = peptide accession
#      value = peptide_instance_id
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

    %hash = $sbeams->selectTwoColumnHash($sql) or die
        "unable to execute statement:\n$sql\n($!)";

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
# readAPD_writeRecords - reads APD file, writes peptide records,
#   initialize peptide_instance, and peptide_instance_sample
# @param infile
# @param sample_id_hash_ref
#######################################################################
sub readAPD_writeRecords {

    my %args = @_;

    my $infile = $args{'infile'} or die "need infile ($!)";

    my $sample_id_hash_ref = $args{'sample_id_hash_ref'} or die
        "need sample_id_hash reference ($!)";

    my $atlas_build_id = $args{'atlas_build_id'} or die
        "need atlas_build_id ($!)";

    ## hash with key = search_batch_id, value = sample_id
    my %searchBatchID_sampleId_hash = %{ $sample_id_hash_ref };


    ## get hash with key=peptide_accession, value=peptide_id
    my %peptide_acc_id_hash = get_peptide_accession_id_hash();
        

    #### READ  {organism}_all.tsv ##############
    print "\nReading $infile\n";
    open(INFILE, $infile) or die "ERROR: Unable to open for reading $infile ($!)";
 
    my $line;

    chomp($line = <INFILE>);

    my @column_names = split(/\t/,$line);

    my $i = 0;

    my %column_indices;

    foreach my $column_name (@column_names) {

        $column_indices{$column_name} = $i;

        $i++;

    }
 
    my ($pep_acc, $pep_seq, $pep_length, $best_prob, $n_obs, $search_batch_id_list);
 
    #### read the rest of the file  APD_{organism}_all.tsv and store in hashes with
    ##   keys of peptide_accession 
    my $counter = 0;

    while ($line = <INFILE>) {

        chomp($line);

        my @columns = split(/\t/,$line);
 
        $pep_acc = $columns[$column_indices{peptide_identifier_str}];

        $pep_seq = $columns[$column_indices{peptide}];

        $pep_length = length($pep_seq);

        $best_prob = $columns[$column_indices{maximum_probability}];

        $best_prob =~ s/\s+//g; ## remove empty spaces

        $n_obs = $columns[$column_indices{n_peptides}];

        $search_batch_id_list = $columns[$column_indices{observed_experiment_list}];

        $search_batch_id_list =~ s/\"//g;  ## removing quotes " from string

        my @search_batch = split(",", $search_batch_id_list);
        

        ## create string of sample_ids:
        my $sample_id_list = $searchBatchID_sampleId_hash{$search_batch[0]};

        for (my $i=1; $i <= $#search_batch; $i++)
        {

            $sample_id_list = $sample_id_list . "," .
                $searchBatchID_sampleId_hash{$search_batch[$i]} ;

        }


        #### If this peptide_id doesn't yet exist in the database table 
        #### "peptide", add it
        if (!exists $peptide_acc_id_hash{$pep_acc})
        {

            ## insert into peptide  table
            my %rowdata = (             ##  peptide     table attributes:
                peptide_accession => $pep_acc,
                peptide_sequence => $pep_seq,
                peptide_length => $pep_length,
            );
 
            my $peptide_id = $sbeams->updateOrInsertRow(
                insert=>1,
                table_name=>$TBAT_PEPTIDE,
                rowdata_ref=>\%rowdata,
                PK => 'peptide_id',
                return_PK => 1,
                verbose=>$VERBOSE,
                testonly=>$TESTONLY,
            );
 

            ## include new peptide_id in hash:
            $peptide_acc_id_hash{$pep_acc} = $peptide_id;

        } 

        my $peptide_id = $peptide_acc_id_hash{$pep_acc};

        ## Create/initialize peptide_instance 

        ## (setting n_genome_locations = 0, n_protein_mappings=0, 
        ## is_exon_spanning='N'---> they're updated in coordinate 
        ## mapping section)

        my %rowdata = (   ##   peptide_instance    table attributes
            atlas_build_id => $atlas_build_id,
            peptide_id => $peptide_id,
            best_probability => $best_prob,
            n_observations => $n_obs,
            n_genome_locations => 0,
            sample_ids => $sample_id_list,
            is_exon_spanning => 'n',
            n_protein_mappings => 0,
            search_batch_ids => $search_batch_id_list,
        );


        my $peptide_instance_id = $sbeams->updateOrInsertRow(
            insert=>1,
            table_name=>$TBAT_PEPTIDE_INSTANCE,
            rowdata_ref=>\%rowdata,
            PK => 'peptide_instance_id',
            return_PK => 1,
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );


        ## Create a peptide_instance_sample record for each sample
        for (my $i=0; $i <= $#search_batch; $i++)
        {

            my $sample_id =  $searchBatchID_sampleId_hash{$search_batch[$i]} ;

            ## initialize peptide_instance and peptide_instance_sample:
            my %rowdata = (   ##   peptide_instance_sample    table attributes
                peptide_instance_id => $peptide_instance_id,
                sample_id => $sample_id,
            );

            my $success = $sbeams->updateOrInsertRow(
                insert=>1,
                table_name=>$TBAT_PEPTIDE_INSTANCE_SAMPLE,
                rowdata_ref=>\%rowdata,
                PK => 'peptide_instance_sample_id',
                add_audit_parameters => 1,
                verbose=>$VERBOSE,
                testonly=>$TESTONLY,
            );

        }

    } # end while INFILE

    close(INFILE) or die "Cannot close $infile ($!)";


}  ## end readAPD_writeRecords



#######################################################################
#  testAPDVars  -- tests that APD variables were filled
#######################################################################
sub testAPDVars {

   my %args = @_;

   my $pep_acc_ref = $args{'pep_acc_ref'};

   my $pep_seq_ref = $args{'pep_seq_ref'};

   my $pep_length_ref = $args{'pep_length_ref'};

   my $best_prob_ref = $args{'best_prob_ref'};

   my $n_obs_ref = $args{'n_obs_ref'};

   my $sb_ids_ref = $args{'sb_ids_ref'};

   my $sample_ids_ref = $args{'sample_ids_ref'};

   my $pep_id_ref = $args{'pep_id_ref'};

   my $pep_ref = $args{'pep_ref'};


   my %peptide_accession = %{$pep_acc_ref};
   my %peptide_sequence = %{$pep_seq_ref};
   my %peptide_length = %{$pep_length_ref};
   my %best_probability = %{$best_prob_ref};
   my %n_observations = %{$n_obs_ref};
   my %search_batch_ids = %{$sb_ids_ref};
   my %sample_ids = %{$sample_ids_ref};
   my %peptide_id = %{$pep_id_ref};
   my %peptides = %{$pep_ref};


   my $n = keys %peptide_accession;

   print "\nChecking hash values after read of APD file.  $n entries\n";

   foreach my $tmp_pep_acc (keys %peptide_accession) {

       my $pep_acc = $peptide_accession{$tmp_pep_acc};
       my $pep_seq = $peptide_sequence{$tmp_pep_acc};
       my $pep_length = $peptide_length{$tmp_pep_acc};
       my $best_prob = $best_probability{$tmp_pep_acc};
       my $n_obs = $n_observations{$tmp_pep_acc};
       my $sb_ids=$search_batch_ids{$tmp_pep_acc};
       my $pep_id = $peptide_id{$tmp_pep_acc};

       my $str = "    $peptide_accession{$tmp_pep_acc}\t".
               "$peptide_sequence{$tmp_pep_acc}\t".
               "$peptide_length{$tmp_pep_acc}\t".
               "$best_probability{$tmp_pep_acc}\t".
               "$n_observations{$tmp_pep_acc}\t".
               "$search_batch_ids{$tmp_pep_acc}\t".
               "$sample_ids{$tmp_pep_acc}\t".
               "$peptide_id{$tmp_pep_acc}\n";


       if ( !$pep_acc ) {

           print "PROBLEM...missing info for \$pep_acc for peptide $pep_acc\n"; ##this won't happen

           print $str;

       } elsif (!$pep_seq) {

           print "PROBLEM...missing info for \$pep_seq for peptide $pep_acc\n";

           print $str;

       } elsif (!$pep_length) {

           print "PROBLEM...missing info for \$pep_length for peptide $pep_acc\n";

           print $str;

       } elsif (!$best_prob) {

           print "PROBLEM...missing info for \$best_prob for peptide $pep_acc\n";

           print $str;

       } elsif (!$n_obs) {

           print "PROBLEM...missing info for \$n_obs for peptide $pep_acc\n";

           print $str;

       } elsif (!$sb_ids) {

           print "PROBLEM...missing info for \$sb_ids for peptide $pep_acc\n";

           print $str;

       } elsif (!$pep_id) {

           print "PROBLEM...missing info for \$pep_id for peptide $pep_acc\n";

           print $str;

       } 

   } 

   print "-->end first stage test of vars\n";
        

}  ## end testAPDVars


#######################################################################
# readCoords_updateRecords_calcAttributes -- read coordinate mapping
#   file, calculate mapping attributes, update peptide_instance
#   record, and create peptide_mapping records 
#######################################################################
sub readCoords_updateRecords_calcAttributes {

    my %args = @_;

    my $infile = $args{'infile'} or die "need infile ($!)";

    my $sample_id_hash_ref = $args{'sample_id_hash_ref'} or die
        " need sample_id_hash_ref ($!)";

    my %searchBatchID_sampleID_id_hash = %{$sample_id_hash_ref};

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

        push(@is_exon_spanning, 'n');  ##unless replaced in next section

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
   ##                         value = 'y' if (  (diff_coords + 1) != (seq_length*3);

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

       ## initialize to 'n'
       $is_exon_spanning_hash{$protein} = 'n';


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

               $is_exon_spanning_hash{$protein} = 'y';

               ## update larger scope variable too:
               $is_exon_spanning[$i_ind] = 'y';

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
           my @test_is_exon_spanning = ('n', 'y', 'y', 'n');

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

