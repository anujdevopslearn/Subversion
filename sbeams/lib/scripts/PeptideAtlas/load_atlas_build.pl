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

 e.g.:  ./load_atlas_build.pl --atlas_build_name \'Human_P0.9_Ens26_NCBI35\' --organism_abbrev \'Hs\' --purge --load 

 e.g.: ./load_atlas_build.pl --atlas_build_name \'TestAtlas\' --delete
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "testvars","delete", "purge", "load", "check_tables",
        "atlas_build_name:s", "organism_abbrev:s",
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
  my $base_directory = "/net/db/projects/PeptideAtlas/pipeline/output";
  my $source_dir;


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
  my $sql = qq~
      SELECT atlas_build_id,biosequence_set_id
      FROM $TBAT_ATLAS_BUILD
      WHERE atlas_build_name = '$atlas_build_name'
      AND record_status != 'D'
      ~;

  my ($atlas_build_id) = $sbeams->selectOneColumn($sql) or
      die "\nERROR: Unable to find the atlas_build_name". 
      $atlas_build_name."with $sql\n\n";

  $ATLAS_BUILD_ID = $atlas_build_id; ## global variable needed for last test



  ## handle --purge:
  if ($purge) {

     print "Removing child records in $atlas_build_name ($atlas_build_id): \n";

     removeAtlas(atlas_build_id => $atlas_build_id,
                 keep_parent_record => 1);

  }#end --purge




  ## handle --load:
  if ($load) {

      ## check if atlas has peptide_instance entries (checking for 1 entry):
      my $sql =qq~
          SELECT top 1 *
          FROM $TBAT_PEPTIDE_INSTANCE
          WHERE atlas_build_id = '$atlas_build_id'
          ~;

      my @peptide_instance_array = $sbeams->selectOneColumn($sql);

      ## if has entries, tell user...atlas_build_name might be a user error
      if (@peptide_instance_array && $TESTONLY == 0) { 
          print "ERROR: Records already exist in atlas $\atlas_build name\n";
          print "To purge existing records and load new records\n";
          print "  use: --purge --load \n";
          print "$USAGE";
          return;
      }


      ## require organism_abbrev:
      unless ($organism_abbrev ) {
          
          die "\nNeed organism_abbrev\n$USAGE\n";

      }

      ## check that base directory exists
      unless ( -d $base_directory ) {

          die "\n Can't find base_directory $base_directory\n";

      }

      $base_directory = "$base_directory/";


      ## get $relative_path  from atlas_build_id:data_path
      ## get APD_id          from atlas_build_id:APD_id
      ## get biosequence_set_id from atlas_build_id:biosequence_set_id
      my ($relative_path, $APD_id, $biosequence_set_id);
      $sql = qq~
          SELECT data_path, APD_id, biosequence_set_id
          FROM $TBAT_ATLAS_BUILD
          WHERE atlas_build_id = '$ATLAS_BUILD_ID'
          AND record_status != 'D'
      ~;

      my @rows = $sbeams->selectSeveralColumns($sql)
          or die "Couldn't find data_path, APD_id, biosequence_set_id ".
          "for atlas_build_id=$ATLAS_BUILD_ID ($!)";

      foreach my $row (@rows) {

         ($relative_path, $APD_id, $biosequence_set_id) = @{$row};

      }



      ## set source_dir as full path to data:
      $source_dir = $base_directory.$relative_path;
     
      unless ( -e $source_dir) {

          die "\n Can't find path $relative_path relative to ".
              " base directory $base_directory\n";

      }

  
      ## build atlas:
      print "Building atlas $atlas_build_name ($atlas_build_id): \n";
  
      buildAtlas(atlas_build_id => $atlas_build_id,
                biosequence_set_id => $biosequence_set_id,
                source_dir => $source_dir,
                organism_abbrev => $organism_abbrev,
                APD_id => $APD_id,
      );

      print "\nFinished buildAtlas \n";

  } ## end --load



  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }



  ## handle --delete:
  if ($del) {

     print "Removing atlas $atlas_build_name ($atlas_build_id) \n";

     removeAtlas(atlas_build_id => $atlas_build_id);

  }#end --delete



  if ($TESTONLY || $purge) {
      print "\a done\n";
  }



} # end handleRequest

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
# buildAtlas -- populates PeptideAtlas records in requested atlas_build
###############################################################################
sub buildAtlas {  

    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'};

    my $biosequence_set_id = $args{'biosequence_set_id'};

    my $source_dir = $args{'source_dir'};

    my $organism_abbrev = $args{'organism_abbrev'};
 
    my $APD_id = $args{'APD_id'};


    my %sample_id_hash; #key = search_batch_id, value = sample_id

    ## update sample records and create atlas_build_sample records:
    unless ($TESTONLY)
    {
        updateSampleTables(
            atlas_build_id => $atlas_build_id,
            APD_id => $APD_id,
            sample_ids_ref => \%sample_id_hash,
            test => $TESTONLY,
        );
    }


    #### Get the current list of peptides in the peptide table
    my $sql;
    $sql = qq~
        SELECT peptide_accession,peptide_id
        FROM $TBAT_PEPTIDE
        ~;

    ## creates hash with key=peptide_accession, value=peptide_id
    my %peptides = $sbeams->selectTwoColumnHash($sql) or
        die "Unable to get peptide_accession and peptide_id from table".
        " peptide ($!)";
 
 
    #### Get the current biosequences in this set
    $sql = qq~
        SELECT biosequence_name,biosequence_id
        FROM $TBAT_BIOSEQUENCE
        WHERE biosequence_set_id = '$biosequence_set_id'
    ~;
    my %biosequence_ids = $sbeams->selectTwoColumnHash($sql) or
        die "unable to get biosequence name and id from biosequence".
        " set $biosequence_set_id ($!)";
    ## creates hash with key=biosequence_name, value=biosequence_id
 

    ## declare variables to be filled in readAPDWritePeptideRecords:
    my (%APD_peptide_accession, %APD_peptide_sequence, %APD_peptide_length, %APD_best_probability);
    my (%APD_n_observations, %APD_search_batch_ids, %APD_sample_ids, %APD_peptide_id);
    my (%APD_is_subpeptide_of);


    #### set infile to APD tsv file
    my $infile = ${source_dir}."/APD_".${organism_abbrev}."_all.tsv";

    ## read APD and write peptide records:
    readAPDWritePeptideRecords(
        infile => $infile,
        pep_acc_ref => \%APD_peptide_accession,
        pep_seq_ref => \%APD_peptide_sequence,
        pep_length_ref => \%APD_peptide_length,
        best_prob_ref => \%APD_best_probability,
        n_obs_ref => \%APD_n_observations,
        sb_ids_ref  => \%APD_search_batch_ids,
        pep_id_ref => \%APD_peptide_id,
        pep_ref => \%peptides,
    );


    ## create comma separated string of sample_ids with key = pep acc:
    foreach my $pep (keys %APD_search_batch_ids) {

        my $sb_string = $APD_search_batch_ids{$pep};

        my @sb_array = split(",", $sb_string);

        foreach (my $ii=0; $ii <= $#sb_array; $ii++) {

            my $search_b_i = $sb_array[$ii];

            my $sample_i = $sample_id_hash{ $search_b_i };

            if( exists $APD_sample_ids{$pep} ) {

                $APD_sample_ids{$pep} = join "," , $APD_sample_ids{$pep}, $sample_i;

            } else {

                $APD_sample_ids{$pep} = $sample_i;

            }

        }

    }


    if ($TESTVARS) {

        testAPDVars(
            pep_acc_ref => \%APD_peptide_accession,
            pep_seq_ref => \%APD_peptide_sequence,
            pep_length_ref => \%APD_peptide_length,
            best_prob_ref => \%APD_best_probability,
            n_obs_ref => \%APD_n_observations,
            sb_ids_ref  => \%APD_search_batch_ids,
            sample_ids_ref => \%APD_sample_ids,
            pep_id_ref => \%APD_peptide_id,
            pep_ref => \%peptides,
        );

    }



    ## declare variables to be filled in readCoords
    my %index_hash; # key   = $peptide_accession[$ind], 
                   # value = string of array indices holding given peptide_accession

    ## storage in arrays to later calculate n_genome_locations and is_exon_spanning
    my (@peptide_accession, @biosequence_name, @start_in_biosequence,
    @end_in_biosequence, @chromosome, @strand, @start_in_chromosome,
    @end_in_chromosome, @n_protein_mappings, @n_genome_locations, @is_exon_spanning);

    ## set infile to coordinate mapping file
    $infile = "$source_dir/coordinate_mapping.txt";


    readCoords(
        infile => $infile,
        index_ref => \%index_hash,
        pep_acc_ref => \@peptide_accession,
        bio_name_ref => \@biosequence_name,
        start_bio_ref => \@start_in_biosequence,
        end_bio_ref => \@end_in_biosequence,
        chrom_ref => \@chromosome,
        strand_ref => \@strand,
        start_chrom_ref => \@start_in_chromosome,
        end_chrom_ref => \@end_in_chromosome,
        n_prot_map_ref => \@n_protein_mappings,
        n_gen_loc_ref => \@n_genome_locations,
        is_ex_sp_ref => \@is_exon_spanning,
    );


    if ($TESTVARS) {

        testCoordVars(
            index_ref => \%index_hash,
            pep_acc_ref => \@peptide_accession,
            bio_name_ref => \@biosequence_name,
            start_bio_ref => \@start_in_biosequence,
            end_bio_ref => \@end_in_biosequence,
            chrom_ref => \@chromosome,
            strand_ref => \@strand,
            start_chrom_ref => \@start_in_chromosome,
            end_chrom_ref => \@end_in_chromosome,
            n_prot_map_ref => \@n_protein_mappings,
            n_gen_loc_ref => \@n_genome_locations,
            is_ex_sp_ref => \@is_exon_spanning,
        ); 

    }



   ## n_protein_mappings -- Number of distinct accession numbers (proteins) 
   ##                       that a peptide maps to
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

           my $seq_length = $APD_peptide_length{$peptide};

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
                       print "!! $test_pep[$jj] : expected n_genome_locations=$test_n_genome_locations[$jj]",
                       " but calculated $n_genome_locations[$ii]\n";
                   }
                   if ($n_protein_mappings[$ii] != $test_n_protein_mappings[$jj]) {
                       print "!! $test_pep[$jj] : expected n_protein_mappings=$test_n_protein_mappings[$jj]",
                       " but calculated $n_protein_mappings[$ii]\n";
                   }
                   if ($is_exon_spanning[$ii] != $test_is_exon_spanning[$jj]) {
                       print "!! $test_pep[$jj] : expected is_exon_spanning=$test_is_exon_spanning[$jj]",
                       " but calculated $is_exon_spanning[$ii]\n";
                   }
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
           my $tmp_best_probability = $APD_best_probability{$tmp_pep_acc};
           my $tmp_n_obs = $APD_n_observations{$tmp_pep_acc};
           my $tmp_search_batch_ids = $APD_search_batch_ids{$tmp_pep_acc};
           my $tmp_sample_ids = $APD_sample_ids{$tmp_pep_acc};
           my $tmp_n_genome_locations = $n_genome_locations[$i];
           my $tmp_is_exon_spanning = $is_exon_spanning[$i];
           my $tmp_n_protein_mappings = $n_protein_mappings[$i];
           my $tmp_biosequence_id = $biosequence_ids{$biosequence_name[$i]};
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

           } elsif (!$tmp_best_probability) {

               print "PROBLEM:  missing \$tmp_best_probability for $tmp_pep_acc \n";

           } elsif (!$tmp_n_obs) {

               print "PROBLEM:  missing \$tmp_n_obs for $tmp_pep_acc \n";

           } elsif (!$tmp_search_batch_ids) {

               print "PROBLEM:  missing \$tmp_search_batch_ids for $tmp_pep_acc \n";

           } elsif (!$tmp_sample_ids) {

               print "PROBLEM:  missing \$tmp_sample_ids for $tmp_pep_acc \n";

           } elsif (!$tmp_n_genome_locations) {

               print "PROBLEM:  missing \$tmp_n_genome_locations for $tmp_pep_acc \n";

           } elsif (!$tmp_is_exon_spanning) {

               print "PROBLEM:  missing \$tmp_is_exon_spanning  for $tmp_pep_acc \n";

           } elsif (!$tmp_n_protein_mappings){

               print "PROBLEM:  missing \$tmp_n_protein_mappings for $tmp_pep_acc \n";

           } elsif (!$tmp_biosequence_id ) {

               print "PROBLEM:  missing \$tmp_biosequence_id  for $tmp_pep_acc \n";

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
   ## Loading peptides with mappings into tables:
   ##    peptide_instance, peptide_instance_sample, and peptide_mapping
   ####----------------------------------------------------------------------------
   print "\nLoading mapped peptides into peptide_instance, ".
       "peptide_instance_sample, and peptide_mapping tables\n";

   my %loaded_peptides;
   my $peptide_instance_id = -1;
   my $peptide_instance_sample_id = -1;
   my $atlas_build_sample_id = -1;
   my %strand_xlate = (
                      '-' => '-',
                      '+' => '+',
                      '-1' => '-',
                      '+1' => '+',
                      '1' => '+',
                     );
   my $counter=0;

   for(my $i =0; $i <= $#peptide_accession; $i++){

       my $tmp = $strand_xlate{$strand[$i]}
           or die("ERROR: Unable to translate strand $strand[$i]");

       $strand[$i] = $tmp;
 
       #### Make sure we can resolve the biosequence_id
       my $biosequence_id = $biosequence_ids{$biosequence_name[$i]}
           || die("ERROR: BLAST matched biosequence_name $biosequence_name[$i] ".
           "does not appear to be in the biosequence table!!");


       my $tmp_pep_acc = $peptide_accession[$i];
 
       #### If this peptide_instance hasn't yet been added to the database, add it
       if ($loaded_peptides{$tmp_pep_acc}) {

           $peptide_instance_id = $loaded_peptides{$tmp_pep_acc};
 
       } else {
 
           my $peptide_id = $peptides{$tmp_pep_acc} ||
 	       die("ERROR: Wanted to insert data for peptide $peptide_accession[$i] ".
               "which is in the BLAST output summary, but not in the input ".
               "peptide file??");

           if ( !defined($APD_best_probability{$tmp_pep_acc}) ) {

               die("ERROR: Wanted to insert data for peptide $tmp_pep_acc".
               "but the best probability is NULL??");

           }

           ## Populate peptide_instance table
           my %rowdata = (   ##   peptide_instance    table attributes
               atlas_build_id => $atlas_build_id,
               peptide_id => $peptide_id,
               best_probability => $APD_best_probability{$tmp_pep_acc},
               n_observations => $APD_n_observations{$tmp_pep_acc},
               search_batch_ids => $APD_search_batch_ids{$tmp_pep_acc},
               sample_ids => $APD_sample_ids{$tmp_pep_acc},
               n_genome_locations => $n_genome_locations[$i],
               is_exon_spanning => $is_exon_spanning[$i],
               n_protein_mappings => $n_protein_mappings[$i],
           );
 
           $peptide_instance_id = $sbeams->updateOrInsertRow(
               insert=>1,
               table_name=>$TBAT_PEPTIDE_INSTANCE,
               rowdata_ref=>\%rowdata,
               PK => 'peptide_instance_id',
               return_PK => 1,
               verbose=>$VERBOSE,
               testonly=>$TESTONLY,
           );
 
           $loaded_peptides{$peptide_accession[$i]} = $peptide_instance_id;

           ## Populate peptide_instance_sample table
           ##
           ## For each peptide_instance, there may be several peptide_instance_sample s
           ## split $APD_sample_ids{$tmp_pep_acc} on commas, and for each member, 
           ## create a peptide_instance_sample that holds the peptide_instance_id
           my @tmp_sample_id = split(",", $APD_sample_ids{$tmp_pep_acc} );


           for (my $ii = 0; $ii <= $#tmp_sample_id; $ii++) {

               my $sql;

               $sql = qq~
                   SELECT date_created, created_by_id, date_modified, modified_by_id, 
                   owner_group_id, record_status
                   FROM $TBAT_SAMPLE
                   WHERE sample_id = '$tmp_sample_id[$ii]'
                   AND record_status != 'D'
               ~;

               ## array of refs to array:
               my @rows = $sbeams->selectSeveralColumns($sql)
                    or die "Couldn't find record for sample_id = ".
                    $tmp_sample_id[$ii]." in PeptideAtlas.dbo.sample ($!)";

               foreach my $row (@rows) {

                   my ($dc, $cbi, $dm, $mbi, $ogi, $rs) = @{$row};

                   my %rowdata = (   ##   peptide_instance_sample    table attributes
                       peptide_instance_id => $peptide_instance_id,
                       sample_id => $tmp_sample_id[$ii],
                       date_created => $dc,
                       created_by_id  => $cbi,
                       date_modified  => $dm,
                       modified_by_id  => $mbi,
                       owner_group_id  => $ogi,
                       record_status  => $rs,
                    );

                   $peptide_instance_sample_id = $sbeams->updateOrInsertRow(
                       insert=>1,
                       table_name=>$TBAT_PEPTIDE_INSTANCE_SAMPLE,
                       rowdata_ref=>\%rowdata,
                       PK => 'peptide_instance_sample_id',
                       return_PK => 1,
                       verbose=>$VERBOSE,
                       testonly=>$TESTONLY,
                    );

               }
           }  ## end peptide_instance_sample & atlas_build_sample loop
       }  ## end  "not already present in peptide" loop
 

       #### INSERT  into  peptide_mapping
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
 
       #### Update row counter information
       $counter++;
       print "$counter..." if ($counter % 100 == 0);
   
   } #end for loop over mapped peptides
   ###----------------------------------------------------------------------------
 
   print "\n";
 
 
   ####----------------------------------------------------------------------------
   ## Loading peptides without mappings into tables:
   ##    peptide_instance, peptide_instance_sample.
   ####----------------------------------------------------------------------------

   print "\nLoading un-mapped peptides into peptide_instance and peptide_instance_sample\n";

   ## make sql call to get hash of peptide_id and any other variable...
   $sql = qq~
       SELECT peptide_id,atlas_build_id
       FROM $TBAT_PEPTIDE_INSTANCE
       WHERE atlas_build_id = '$atlas_build_id'
   ~;
   my %peptide_instances = $sbeams->selectTwoColumnHash($sql);
   ## makes hash with key = peptide_id, value = atlas_build_id
 
   foreach my $tmp_pep_acc (keys %APD_peptide_accession) {
 
       my $tmp_pep_id = $APD_peptide_id{$tmp_pep_acc};

       if ( !$peptide_instances{$tmp_pep_id} ) {
 
           my %rowdata = ( ##   peptide_instance    table attributes
               atlas_build_id => $atlas_build_id,
               peptide_id => $tmp_pep_id,
               best_probability => $APD_best_probability{$tmp_pep_acc},
               n_observations => $APD_n_observations{$tmp_pep_acc},
               search_batch_ids => $APD_search_batch_ids{$tmp_pep_acc},
               sample_ids => $APD_sample_ids{$tmp_pep_acc},
               n_genome_locations => '0',
               is_exon_spanning => 'n',
               n_protein_mappings => '0',
           );  
 
           my $peptide_instance_id = -1;

           $peptide_instance_id = $sbeams->updateOrInsertRow(
               insert=>1,
               table_name=>$TBAT_PEPTIDE_INSTANCE,
               rowdata_ref=>\%rowdata,
               PK => 'peptide_instance_id',
               return_PK => 1,
               verbose=>$VERBOSE,
               testonly=>$TESTONLY,
           );
         
           ## for each sample, create peptide_instance_sample record
           my @tmp_sample_id = split(",", $APD_sample_ids{$tmp_pep_acc} );

           for (my $ii = 0; $ii <= $#tmp_sample_id; $ii++) {

               my $sql;
               $sql = qq~
                   SELECT date_created, created_by_id, date_modified, modified_by_id, 
                       owner_group_id, record_status
                   FROM $TBAT_SAMPLE
                   WHERE sample_id = '$tmp_sample_id[$ii]'
                   AND record_status != 'D'
               ~;

               my @rows = $sbeams->selectSeveralColumns($sql)
                   or die "Couldn't find record for sample_id = ".
                   $tmp_sample_id[$ii]." in PeptideAtlas.dbo.sample ($!)";

               foreach my $row (@rows) {

                   my ($dc, $cbi, $dm, $mbi, $ogi, $rs) = @{$row};

                   my %rowdata = (   ##   peptide_instance_sample    table attributes
                       peptide_instance_id => $peptide_instance_id,
                       sample_id => $tmp_sample_id[$ii],
                       date_created => $dc,
                       created_by_id  => $cbi,
                       date_modified  => $dm,
                       modified_by_id  => $mbi,
                       owner_group_id  => $ogi,
                       record_status  => $rs,
                   );

                   $peptide_instance_sample_id = $sbeams->updateOrInsertRow(
                       insert=>1,
                       table_name=>$TBAT_PEPTIDE_INSTANCE_SAMPLE,
                       rowdata_ref=>\%rowdata,
                       PK => 'peptide_instance_sample_id',
                       return_PK => 1,
                       verbose=>$VERBOSE,
                       testonly=>$TESTONLY,
                   );
               }
           }  ## end peptide_instance_sample loop
       }
   } ## end peptide_instance entries for unmapped peptides


   #### Need peptide_instance_id's to update peptide_instance record:
   my $sql;
   $sql = qq~
      SELECT peptide_id,peptide_instance_id
      FROM $TBAT_PEPTIDE_INSTANCE
   ~;
   my %peptide_instances = $sbeams->selectTwoColumnHash($sql);
   ## creates hash with key=peptide_id, value=peptide_instance_id
 

   ##  calculate is_subpeptide_of, and enter into table peptide

   foreach my $sub_pep_acc (keys %APD_peptide_accession) {

       for my $super_pep_acc ( keys %APD_peptide_accession) {

           if ( ( index($APD_peptide_sequence{$super_pep_acc}, $APD_peptide_sequence{$sub_pep_acc}) >= 0) 
               && ($super_pep_acc ne $sub_pep_acc) ) {
       
               if ( $APD_is_subpeptide_of{$sub_pep_acc} ) {

                   $APD_is_subpeptide_of{$sub_pep_acc} = 
                       join ",", $APD_is_subpeptide_of{$sub_pep_acc}, $APD_peptide_id{$super_pep_acc};

               } else { 

                   $APD_is_subpeptide_of{$sub_pep_acc} = $APD_peptide_id{$super_pep_acc};

               }

           }
       }

 
       ## surround string with quotes: ?
#      $APD_is_subpeptide_of{$sub_pep_acc} = '"'.$APD_is_subpeptide_of{$sub_pep_acc}.'"';

       ## update table peptide_instance
       my %rowdata = ( ##   peptide instance       some of the table attributes:
           is_subpeptide_of => , $APD_is_subpeptide_of{$sub_pep_acc},
       );  
 
       my $peptide_instance_id = $peptide_instances { $APD_peptide_id{$sub_pep_acc} };

       my $result = $sbeams->updateOrInsertRow(
           update=>1,
           table_name=>$TBAT_PEPTIDE_INSTANCE,
           rowdata_ref=>\%rowdata,
           PK => 'peptide_instance_id',
           PK_value=>$peptide_instance_id,
           verbose=>$VERBOSE,
           testonly=>$TESTONLY,
       );
         
   }


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

}# end buildAtlas


###############################################################################
# updateSamples - updates sample and atlas_build_sample tables
# located with search_batch_id list from APD.
#
# Look for a sample table, if it doesn't exist, create it
# with minimal info from proteomics experiment while
# printing a warning to screen.
###############################################################################
sub updateSampleTables {

    my %args = @_;

    my $atlas_build_id = $args{'atlas_build_id'};

    my $APD_id = $args{'APD_id'};

    my $TEST = $args{'test'};

    my $sample_ids_ref = $args{'sample_ids_ref'};


    ## get the list of search batch ID's from the APD record:
    ## (experiment_list is actually search batch id's)
    my $sql = qq~
       SELECT experiment_list
       FROM $TBAPD_PEPTIDE_SUMMARY
       WHERE peptide_summary_id = '$APD_id'
    ~;

    my ($search_batch_id_list) = $sbeams->selectOneColumn($sql)
       or die "could not find search_batch_id list for APD_id = ".
       "$APD_id ? in APD's peptide_summary ($!)";

    if ($TEST) {

        print "\$search_batch_id_list = $search_batch_id_list\n";

    }


    my @search_batch_id = split ",", $search_batch_id_list;

    my @sample_id;

    my (@sample_tag, @sample_title, @sample_description, @dc, @cbi, @dm, @mbi, @ogi, @rs);
    
    ## Get sample_id from PeptideAtlas.dbo.sample.
    ## For each search_batch_id, see if there's a sample record,
    ## and if not, create one with minimal proteomics experiment info
    ## while printing a warning to screen.
    ## If there is a sample record, update it with sample_id
    for (my $i=0; $i<= $#search_batch_id; $i++) {

        ## FOR insearts and updates:
        ## Get date_created, created_by_id, date_modified, modified_by_id,
        ## and owner_group_id, record_status from atlas_build
        $sql = qq~
             SELECT date_created, created_by_id, date_modified, modified_by_id,
             owner_group_id, record_status
             FROM $TBAT_ATLAS_BUILD
             WHERE atlas_build_id = '$atlas_build_id'
             AND record_status != 'D'
        ~;

        my @rows = $sbeams->selectSeveralColumns($sql)
            or die "Couldn't find record for atlas_build_id = ".
            "$atlas_build_id \n$sql\n($!)";

        foreach my $row (@rows) 
        {
            my ($tdc, $tcbi, $tdm, $tmbi, $togi, $trs) = @{$row};

            $dc[$i] = $tdc;

            $cbi[$i] = $tcbi;

            $dm[$i] = $tdm;

            $mbi[$i] = $tmbi;

            $ogi[$i] = $togi;

            $rs[$i] = $trs;

        }


        ## get sample record if it exists
        $sql = qq~
            SELECT S.sample_id
            FROM $TBAT_SAMPLE S
            WHERE S.search_batch_id = '$search_batch_id[$i]'
            AND S.record_status != 'D'
        ~;


        my ($tmp) = $sbeams->selectOneColumn($sql)
            or warn "Could not find sample record for search_batch_id = ".
            "$search_batch_id[$i] ==> Creating a sample record now";


        if ($tmp) ## sample record exists for search_batch:
        {

            $sample_id[$i] = $tmp;

        } else ## If no sample record, create one
        {

            ## get experiment_tag, experiment_name, $TB_ORGANISM.organism_name
            $sql = qq~
                SELECT PE.experiment_tag, PE.experiment_name, O.organism_name
                FROM $TBPR_PROTEOMICS_EXPERIMENT PE
                JOIN $TB_ORGANISM O
                ON ( PE.organism_id = O.organism_id )
                JOIN $TBPR_SEARCH_BATCH SB
                ON ( PE.experiment_id = SB.experiment_id)
                WHERE SB.search_batch_id = '$search_batch_id[$i]'
                AND PE.record_status != 'D'
            ~;
        
            my @rows = $sbeams->selectSeveralColumns($sql)
                or die "Couldn't find proteomics experiment record for ".
                " search batch id $search_batch_id[$i] " .
                "\n$sql\n($!)";

            foreach my $row (@rows) 
            {
                my ($tmp_experiment_tag, $tmp_experiment_name, $tmp_organism_name) = @{$row};

                $sample_tag[$i] = $tmp_experiment_tag;

                $sample_title[$i] = $tmp_experiment_name;

                $sample_description[$i] = $tmp_organism_name;

            }


            my %rowdata = ( ##   sample      some of the table attributes:
                search_batch_id => $search_batch_id[$i],
                sample_tag => $sample_tag[$i],
                sample_title => $sample_title[$i],
                sample_description => $sample_description[$i],
                date_created => $dc[$i],
                created_by_id => $cbi[$i],
                date_modified => $dm[$i],
                modified_by_id => $mbi[$i],
                owner_group_id => $ogi[$i],
                record_status => $rs[$i],
            );


            ## create a sample record:
            my $tmp_sample_id = $sbeams->updateOrInsertRow(
                table_name=>$TBAT_SAMPLE,
                insert=>1,
                rowdata_ref=>\%rowdata,
                PK => 'sample_id',
                return_PK=>1,
                verbose=>$VERBOSE,
                testonly=>$TESTONLY,
            );

            $sample_id[$i] = $tmp_sample_id;

        }  ## end create sample record


        ## Populate atlas_build_sample table
        my %rowdata = (   ##   atlas_build_sample    table attributes
            atlas_build_id => $ATLAS_BUILD_ID,
            sample_id => $sample_id[$i],
            date_created => $dc[$i],
            created_by_id  => $cbi[$i],
            date_modified  => $dm[$i],
            modified_by_id  => $mbi[$i],
            owner_group_id  => $ogi[$i],
            record_status  => $rs[$i],
        );

       my $atlas_build_sample_id = $sbeams->updateOrInsertRow(
           insert=>1,
           table_name=>$TBAT_ATLAS_BUILD_SAMPLE,
           rowdata_ref=>\%rowdata,
           PK => 'atlas_build_sample_id',
           return_PK => 1,
           verbose=>$VERBOSE,
           testonly=>$TEST,
       );

    }

} ## end updateSamples
                                               

#######################################################################
#  readAPDWritePeptideRecords - reads APD file and writes peptide
#      record.  Fills APD hash variables through passed references
#######################################################################
sub readAPDWritePeptideRecords {

   my %args = @_;

   my $infile = $args{'infile'};

   my $pep_acc_ref = $args{'pep_acc_ref'};

   my $pep_seq_ref = $args{'pep_seq_ref'};

   my $pep_length_ref = $args{'pep_length_ref'};

   my $best_prob_ref = $args{'best_prob_ref'};

   my $n_obs_ref = $args{'n_obs_ref'};

   my $sb_ids_ref = $args{'sb_ids_ref'};

   my $pep_id_ref = $args{'pep_id_ref'};

   my $pep_ref = $args{'pep_ref'};


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
 
 
   #### read the rest of the file  APD_{organism}_all.tsv and store in hashes with
   ##   keys of peptide_accession 
   my $counter = 0;

   while ($line = <INFILE>) {

       chomp($line);

       my @columns = split(/\t/,$line);
 
       my $tmp_pep_acc = $columns[$column_indices{peptide_identifier_str}];


       $$pep_acc_ref{$tmp_pep_acc} = $tmp_pep_acc;

       $$pep_seq_ref{$tmp_pep_acc} = $columns[$column_indices{peptide}];

       $$pep_length_ref{$tmp_pep_acc} = length($$pep_seq_ref{$tmp_pep_acc});

       my $tmp_best_probability = $columns[$column_indices{maximum_probability}];
       $tmp_best_probability =~ s/\s+//g; ## remove empty spaces

       $$best_prob_ref{$tmp_pep_acc} = $tmp_best_probability;

       $$n_obs_ref{$tmp_pep_acc} = $columns[$column_indices{n_peptides}];

       my $tmp_search_batch_ids = $columns[$column_indices{observed_experiment_list}];
       $tmp_search_batch_ids =~ s/\"//g;  ## removing quotes " from string

       $$sb_ids_ref{$tmp_pep_acc} = $tmp_search_batch_ids;


       #### If this peptide_id doesn't yet exist in the database table "peptide", add it
       $$pep_id_ref{$tmp_pep_acc} = $$pep_ref{$tmp_pep_acc};
       ## where %peptides is a hash with key=peptide_accession, value=peptide_id
 

       ## Populate peptide  table
       unless ($$pep_id_ref{$tmp_pep_acc}) {
           my %rowdata = (             ##  peptide     table attributes:
               peptide_accession => $$pep_acc_ref{$tmp_pep_acc},
               peptide_sequence => $$pep_seq_ref{$tmp_pep_acc},
               peptide_length => $$pep_length_ref{$tmp_pep_acc},
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
           $$pep_ref{$tmp_pep_acc} = $peptide_id;

           ## and enter that in peptide_id hash:
           $$pep_id_ref{$tmp_pep_acc} = $peptide_id;
       } # end unless
 

       $counter++;

    } # end while INFILE

    close(INFILE) or die "Cannot close $infile ($!)";


}  ## end readAPDWritePeptideRecords


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
#   readCoords -- reads coordinate_mapping.txt file and fills
#   arrays and hash passed by reference
#######################################################################
sub readCoords {

    my %args = @_;

    my $infile = $args{'infile'};

    my $index_ref = $args{'index_ref'};

    my %ind_hash = %{$index_ref};

    my $pep_acc_ref = $args{'pep_acc_ref'};

    my $bio_name_ref = $args{'bio_name_ref'};

    my $start_bio_ref = $args{'start_bio_ref'};

    my $end_bio_ref = $args{'end_bio_ref'};

    my $chrom_ref = $args{'chrom_ref'};

    my $strand_ref = $args{'strand_ref'};

    my $start_chrom_ref = $args{'start_chrom_ref'};

    my $end_chrom_ref = $args{'end_chrom_ref'};

    my $n_prot_map_ref = $args{'n_prot_map_ref'};

    my $n_gen_loc_ref = $args{'n_gen_loc_ref'};

    my $is_ex_sp_ref = $args{'is_ex_sp_ref'};


  
    open(INFILE, $infile) or die "ERROR: Unable to open for reading $infile ($!)";
 
    #### READ  coordinate_mapping.txt  ##############
    print "\nReading $infile\n";

    my $line;

#   my %column_indices;
#
#   #### Read and parse the header line of coordinate_mapping.txt...no header currently
#   if (0 == 1) {
#       chomp($line = <INFILE>);
#       my @column_names = split(/\t/,$line);
#       my $i = 0;
#       foreach my $column_name (@column_names) {
#           $column_indices{$column_name} = $i;
#       }
#   }
 
 
   #### Load information from the coordinate mapping file:
   my $ind=0;

   while ($line = <INFILE>) {

       chomp($line);

       my @columns = split(/\t/,$line);
  
       my $pep_acc = $columns[0];

       push(@$pep_acc_ref, $columns[0]);

       push(@$bio_name_ref, $columns[2]);

       push(@$start_bio_ref, $columns[5]);

       push(@$end_bio_ref, $columns[6]);


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


       push(@$chrom_ref, $tmp_chromosome);

       push(@$strand_ref,$columns[9]);

       push(@$start_chrom_ref,$columns[10]);

       push(@$end_chrom_ref,$columns[11]);

 
       ## %ind_hash has:
       ## keys =  pep_accession
       ## values = the array indices (of the arrays above, holding pep_accession)
       if ( exists $ind_hash{$pep_acc} ) {

           $ind_hash{$pep_acc} = 
               join " ", $ind_hash{$pep_acc}, $ind;

       } else {

           $ind_hash{$pep_acc} = $ind;

       }


       push(@$n_prot_map_ref, 1);  ##unless replaced in next section

       push(@$n_gen_loc_ref, 1);  ##unless replaced in next section

       push(@$is_ex_sp_ref, 'n');  ##unless replaced in next section

       $ind++;

   }   ## end reading coordinate mapping file

   close(INFILE) or die "Cannot close $infile ($!)";



   if ($TESTONLY) { 

       my @pep_acc = @{$pep_acc_ref};
   
       foreach my $tmp_ind_str (values ( %ind_hash ) ) {

           my @tmp_ind_array = split(" ", $tmp_ind_str);

           my %unique_protein_hash;

           my %unique_coord_hash;

           for (my $ii = 0; $ii <= $#tmp_ind_array; $ii++) {

               my $i_ind=$tmp_ind_array[$ii];

               reset %unique_protein_hash; ## necessary?
               reset %unique_coord_hash;   ## necessary?

               ##what is key of ind_hash where value = $tmp_ind_str  ?
               ##is that key = $pep_accession[$i_ind]  ?
               my %inverse_ind_hash = reverse %ind_hash;

               die "check accession numbers in ind_hash" 
                   if ($inverse_ind_hash{$tmp_ind_str} != $pep_acc[$i_ind]); 

           }
       }
   } 

}



#######################################################################
#   testCoordVars -- tests that variables were filled
#######################################################################
sub testCoordVars {

    my %args = @_;

    my $index_ref = $args{'index_ref'};

    my %ind_hash = %{$index_ref};

    my $pep_acc_ref = $args{'pep_acc_ref'};

    my @pep_accession = @{$pep_acc_ref};

    my $bio_name_ref = $args{'bio_name_ref'};

    my @bioseq_name = @{$bio_name_ref};
     
    my $start_bio_ref = $args{'start_bio_ref'};

    my @start_in_bio = @{$start_bio_ref};

    my $end_bio_ref = $args{'end_bio_ref'};

    my @end_in_bio = @{$end_bio_ref};

    my $chrom_ref = $args{'chrom_ref'};

    my @chrom = @{$chrom_ref};

    my $strand_ref = $args{'strand_ref'};

    my @str = @{$strand_ref};

    my $start_chrom_ref = $args{'start_chrom_ref'};

    my @start_in_chrom = @{$start_chrom_ref};

    my $end_chrom_ref = $args{'end_chrom_ref'};

    my @end_in_chrom = @{$end_chrom_ref};

    my $n_prot_map_ref = $args{'n_prot_map_ref'};

    my @n_prot_mappings = @{$n_prot_map_ref};

    my $n_gen_loc_ref = $args{'n_gen_loc_ref'};

    my @n_gen_loc = @{$n_gen_loc_ref};

    my $is_ex_sp_ref = $args{'is_ex_sp_ref'};

    my @is_exon_span = @{$is_ex_sp_ref};


  
   if ($TESTVARS) {

       my $n = ($#pep_accession) + 1;

       print "\nChecking array values after read of coordinate file.  $n entries \n";

       for(my $i =0; $i <= $#pep_accession; $i++){

           my $tmp_pep_acc = $pep_accession[$i];
           my $tmp_biosequence_name = $bioseq_name[$i];
           my $tmp_start_in_biosequence = $start_in_bio[$i];
           my $tmp_end_in_biosequence = $end_in_bio[$i];
	   my $tmp_chromosome = $chrom[$i];
           my $tmp_strand = $str[$i];
           my $tmp_start_in_chromosome = $start_in_chrom[$i];
           my $tmp_end_in_chromosome = $end_in_chrom[$i];
           my $tmp_n_genome_locations = $n_gen_loc[$i];
           my $tmp_is_exon_spanning = $is_exon_span[$i];
           my $tmp_n_protein_mappings = $n_prot_mappings[$i];
           

           if (!$tmp_pep_acc) {
         
               print "PROBLEM:  missing \$tmp_pep_acc for index $i\n";

           } elsif (!$tmp_biosequence_name) {

               print "PROBLEM:  missing \$tmp_biosequence_name for $tmp_pep_acc \n";

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

           }
       }

       print "-->end second stage test of vars\n";

        
   }

}
