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
use vars qw ($sbeams $sbeamsMOD $q $current_username $ATLAS_BUILD_ID
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TESTVARS $CHECKTABLES
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
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
  --atlas_build_name     Name of the atlas build (already entered by hand in
                         the atlas_build table) into which to load the data
  --source_dir           Name of the source file from which data are loaded
  --organism_abbrev      Abbreviation of organism like Hs

 e.g.:  ./load_atlas_build.pl --atlas_build_name 'HumanEns21P0.7' --organism_abbrev 'Hs' --purge --load --source_dir '/net/db/projects/PeptideAtlas/pipeline/output/HumanV34dP0.9/DATA_FILES'

 e.g.: ./load_atlas_build.pl --atlas_build_name 'TestAtlas' --delete
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "testvars","delete", "purge", "load", "check_tables",
        "atlas_build_name:s","source_dir:s", "organism_abbrev:s")) {

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
      $current_username = $sbeams->Authenticate(
          work_group=>'PeptideAtlas_admin')
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
  my $source_dir = $OPTIONS{"source_dir"} || '';
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

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }

  ##### HANDLING REST OF CODE NOW #####

  #### Get the atlas_build_id for the supplied name
  my $sql;
  $sql = qq~
    SELECT atlas_build_id,biosequence_set_id
      FROM $TBAT_ATLAS_BUILD
     WHERE atlas_build_name = '$atlas_build_name'
       AND record_status != 'D'
  ~;

  my @rows = $sbeams->selectSeveralColumns($sql);
  unless (scalar(@rows) == 1) {
    print "ERROR: Unable to find the atlas_build_name '$atlas_build_name' ".
      "with $sql\n\n";
    return;
  }
  my ($atlas_build_id,$biosequence_set_id) = @{$rows[0]};

  $ATLAS_BUILD_ID = $atlas_build_id; ## global variable needed for last test

  print "atlas build id = $atlas_build_id\n";

  ## --delete option:
  if ($del) {
     print "Removing atlas $atlas_build_name ($atlas_build_id) \n";
     removeAtlas(atlas_build_id => $atlas_build_id);
  }#end --delete



  ## --purge option:
  if ($purge) {
     print "Removing child records in $atlas_build_name ($atlas_build_id): \n";
     removeAtlas(atlas_build_id => $atlas_build_id,
                 keep_parent_record => 1);
  }#end --purge



  ## --load option:
  if ($load) {
  
     ## verify that an organism abbrev was given
     unless ($OPTIONS{'organism_abbrev'}) {
        print "ERROR: Must supply organism_abbrev\n";
        print "$USAGE";
        return;
     }

     #### Verify the source_file
     if ( $source_dir && !(-d $source_dir) ) {
        print "ERROR: Unable to access source_dir '$source_dir'\n\n";
        return;
     }

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

     print "Building atlas $atlas_build_name ($atlas_build_id): \n";
  
     buildAtlas(atlas_build_id => $atlas_build_id,
                biosequence_set_id => $biosequence_set_id,
                source_dir => $source_dir,
                organism_abbrev => $organism_abbrev);

  } ## end --load

  print "Finished buildAtlas \n";


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

   my $TESTONLY = "0";
   my $VERBOSE = "4";

   if ($keep_parent_record) {
      my $result = $sbeams->deleteRecordsAndChildren(
         table_name => 'atlas_build',
         table_child_relationship => \%table_child_relationship,
         delete_PKs => [ $atlas_build_id ],
         delete_batch => 10000,
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
         delete_batch => 10000,
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
 

   #### Get the current list of peptides in the peptide table
   my $sql;
   $sql = qq~
      SELECT peptide_accession,peptide_id
      FROM $TBAT_PEPTIDE
   ~;
   my %peptides = $sbeams->selectTwoColumnHash($sql);
   ## creates hash with key=peptide_accession, value=peptide_id
 
 
   #### Get the current list of biosequences in this set
   $sql = qq~
     SELECT biosequence_name,biosequence_id
       FROM $TBAT_BIOSEQUENCE
      WHERE biosequence_set_id = '$biosequence_set_id'
   ~;
   my %biosequence_ids = $sbeams->selectTwoColumnHash($sql);
   ## creates hash with key=biosequence_name, value=biosequence_id
 
 
   #### Open the file containing the input peptide properties (APD tsv file)
   my $infile = "${source_dir}/APD_${organism_abbrev}_all.tsv";
   
   open(INFILE, $infile) or die "ERROR: Unable to open for reading $infile ($!)";
 
 
   #### READ  APD_{organism}_all.tsv ##############
   print "\nReading $infile\n";
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
   my (%APD_peptide_accession, %APD_peptide_sequence, %APD_peptide_length, %APD_best_probability);
   my (%APD_n_observations, %APD_search_batch_ids, %APD_sample_ids, %APD_peptide_id);
   my (%APD_is_subpeptide_of);

   while ($line = <INFILE>) {

       chomp($line);

       my @columns = split(/\t/,$line);
 
       my $tmp_pep_acc = $columns[$column_indices{peptide_identifier_str}];

       $APD_peptide_accession{$tmp_pep_acc} = $tmp_pep_acc;

       $APD_peptide_sequence{$tmp_pep_acc} = $columns[$column_indices{peptide}];

       $APD_peptide_length{$tmp_pep_acc} = length($APD_peptide_sequence{$tmp_pep_acc});

       $APD_best_probability{$tmp_pep_acc} = $columns[$column_indices{maximum_probability}];
       $APD_best_probability{$tmp_pep_acc} =~ s/\s+//g; ## remove empty spaces 

       $APD_n_observations{$tmp_pep_acc} = $columns[$column_indices{n_peptides}];

       $APD_search_batch_ids{$tmp_pep_acc} = $columns[$column_indices{observed_experiment_list}];
       $APD_search_batch_ids{$tmp_pep_acc} =~ s/\"//g;  ## removing quotes " from string

       my @tmp_search_batch_id = split(",", $APD_search_batch_ids{$tmp_pep_acc} );


       ## create string of sample_ids given string of search_batch_ids
       for (my $ii = 0; $ii <= $#tmp_search_batch_id; $ii++) {

           my $search_batch_id = $tmp_search_batch_id[$ii];

           my $sql;

           ### given search_batch_id, need sample_id
           #$sql = qq~
           #   SELECT sample_id
           #      FROM $TBAT_SAMPLE
           #   WHERE search_batch_id = '$tmp_search_batch_id[$ii]'
           #      AND record_status != 'D'
           #~;
 
           ## method above doesn't work for obsolete APD builds as the search_batch_ids have
           ## been updated in the sample record...so, need to use Proteomics records:
           ## get experiment_id, then experiment_tag, then sample_id

           ## get sample_id using search_batch_id, via Proteomics records:
           $sql = qq~
               SELECT S.sample_id
               FROM PeptideAtlas.dbo.sample S
                   JOIN Proteomics.dbo.proteomics_experiment PE
                   ON ( PE.experiment_tag = S.sample_tag)
                   JOIN Proteomics.dbo.search_batch SB 
                   ON ( PE.experiment_id = SB.experiment_id )
               WHERE SB.search_batch_id = '$search_batch_id'
           ~;

           my @rows = $sbeams->selectOneColumn($sql) 
               or die "could not find sample id for search_batch_id = ".
               $search_batch_id." in PeptideAtlas.dbo.sample ($!)";

           my $tmp_sample_id = @rows[0];

           ## create string of sample ids:
           if ($ii == 0) {

               $APD_sample_ids{$tmp_pep_acc} = $tmp_sample_id;

           } else {

               $APD_sample_ids{$tmp_pep_acc} =  join ",", $APD_sample_ids{$tmp_pep_acc}, 
                   $tmp_sample_id;

           }


           ## get sample table info to help populate atlas_build_sample table and sample
           my $sql;

           $sql = qq~
               SELECT date_created, created_by_id, date_modified, modified_by_id, 
               owner_group_id, record_status
               FROM $TBAT_SAMPLE
               WHERE sample_id = '$tmp_sample_id'
               AND record_status != 'D'
           ~;

           ## array of refs to array:
           my @rows = $sbeams->selectSeveralColumns($sql)
                or die "Couldn't find record for sample_id = ".
                "$tmp_sample_id in PeptideAtlas.dbo.sample ".
                "[search_batch_id = $search_batch_id".
                "] \n$sql\n($!)";

           foreach my $row (@rows) {

               my ($dc, $cbi, $dm, $mbi, $ogi, $rs) = @{$row};

                ## Populate atlas_build_sample table
                my %rowdata = (   ##   atlas_build_sample    table attributes
                    atlas_build_id => $atlas_build_id,
                    sample_id => $tmp_sample_id,
                    date_created => $dc,
                    created_by_id  => $cbi,
                    date_modified  => $dm,
                    modified_by_id  => $mbi,
                    owner_group_id  => $ogi,
                    record_status  => $rs,
                );

               my $atlas_build_sample_id = $sbeams->updateOrInsertRow(
                   insert=>1,
                   table_name=>$TBAT_ATLAS_BUILD_SAMPLE,
                   rowdata_ref=>\%rowdata,
                   PK => 'atlas_build_sample_id',
                   return_PK => 1,
                   verbose=>$VERBOSE,
                   testonly=>$TESTONLY,
               );

               ## Update sample table too to have search_batch_id 

           }  ## end Populate atlas_build_sample and sample

       } ## end create string of search_batch_ids for a peptide

       #### If this peptide_id doesn't yet exist in the database table "peptide", add it
       $APD_peptide_id{$tmp_pep_acc} = $peptides{$tmp_pep_acc};
       ## where %peptides is a hash with key=peptide_accession, value=peptide_id
 

       ## Populate peptide  table
       unless ($APD_peptide_id{$tmp_pep_acc}) {
           my %rowdata = (             ##  peptide     table attributes:
               peptide_accession => $APD_peptide_accession{$tmp_pep_acc},
               peptide_sequence => $APD_peptide_sequence{$tmp_pep_acc},
               peptide_length => $APD_peptide_length{$tmp_pep_acc},
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
           $peptides{$tmp_pep_acc} = $peptide_id;

           ## and enter that in APD_peptide_id hash:
           $APD_peptide_id{$tmp_pep_acc} = $peptide_id;
       } # end unless
 
       $counter++;

       die "sample_ids is null?? might need to create a sample record search_batch_ids=".
           $APD_search_batch_ids{$tmp_pep_acc}." ($!)" if (!$APD_sample_ids{$tmp_pep_acc});
 
    } # end while INFILE

    close(INFILE) or die "Cannot close $infile ($!)";


    ## test that hash values were all filled
    if ($TESTVARS) {
        
       print "Checking hash values after read of $infile\n";
        
       foreach my $tmp_pep_acc (keys %APD_peptide_accession) {

           my $pep_acc = $APD_peptide_accession{$tmp_pep_acc};
           my $pep_seq = $APD_peptide_sequence{$tmp_pep_acc};
           my $pep_length = $APD_peptide_length{$tmp_pep_acc};
           my $best_prob = $APD_best_probability{$tmp_pep_acc};
           my $n_obs = $APD_n_observations{$tmp_pep_acc};
           my $sb_ids=$APD_search_batch_ids{$tmp_pep_acc};
           my $s_ids = $APD_sample_ids{$tmp_pep_acc};
           my $pep_id = $APD_peptide_id{$tmp_pep_acc};

           my $str = "    $APD_peptide_accession{$tmp_pep_acc}*\t".
                   "$APD_peptide_sequence{$tmp_pep_acc}*\t".
                   "$APD_peptide_length{$tmp_pep_acc}*\t".
                   "$APD_best_probability{$tmp_pep_acc}*\t".
                   "$APD_n_observations{$tmp_pep_acc}*\t".
                   "$APD_search_batch_ids{$tmp_pep_acc}*\t".
                   "$APD_sample_ids{$tmp_pep_acc}*\t".
                   "$APD_peptide_id{$tmp_pep_acc}*\n";


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

           } elsif (!$s_ids) {

               print "PROBLEM...missing info for \$s_ids for peptide $pep_acc\n";

               print $str;

           } elsif (!$pep_id) {

               print "PROBLEM...missing info for \$pep_id for peptide $pep_acc\n";

               print $str;

           } 

       } 

       print "   end first stage test of vars\n";
        
    }

 
    $infile = "$source_dir/coordinate_mapping.txt";

    open(INFILE, $infile) or die "ERROR: Unable to open for reading $infile ($!)";
 
    #### READ  coordinate_mapping.txt  ##############
    print "\nReading $infile\n";

    #### Read and parse the header line of coordinate_mapping.txt...not there currently
    if (0 == 1) {
        chomp($line = <INFILE>);
        my @column_names = split(/\t/,$line);
        my $i = 0;
        foreach my $column_name (@column_names) {
            $column_indices{$column_name} = $i;
        }
    }
 
   #### Define a hash to hold the loaded Ensembl hits:
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
 
 
   my %index_hash; # key   = $peptide_accession[$ind], 
                   # value = string of array indices holding given peptide_accession
 
   ## storage in arrays to later calculate n_genome_locations and is_exon_spanning
   my (@peptide_accession, @biosequence_name, @start_in_biosequence, 
   @end_in_biosequence, @chromosome, @strand, @start_in_chromosome, 
   @end_in_chromosome, @n_protein_mappings, @n_genome_locations, @is_exon_spanning);
 
   #### Load information from the coordinate mapping file:
   my $ind=0;

   while ($line = <INFILE>) {

       chomp($line);

       my @columns = split(/\t/,$line);
  
       $peptide_accession[$ind] = $columns[0];

       $biosequence_name[$ind] = $columns[2];

       $start_in_biosequence[$ind] = $columns[5];

       $end_in_biosequence[$ind] = $columns[6];

       $chromosome[$ind] = $columns[8]; 

       ## parsing for chromosome:   this is set for Ens 21 and 22 notation...
       if ($chromosome[$ind] =~ /^(chromosome:)(NCBI.+:)(.+)(:.+:.+:.+)/ ) {
            $chromosome[$ind] = $3;
       }
       if ($chromosome[$ind] =~ /^(chromosome:)(DROM.+:)(.+)(:.+:.+:.+)/ ) {
            $chromosome[$ind] = $3;
       }

       ## if $columns[8] begins with an S, this is SGD data: ...could store SGDID later
       if ($columns[8]  =~ /^S/ ) {
            $chromosome[$ind] = $columns[12];
       }

       $strand[$ind] = $columns[9];

       $start_in_chromosome[$ind] = $columns[10];

       $end_in_chromosome[$ind] = $columns[11];
 
       ## %index_hash has:
       ## keys =  peptide_accession
       ## values = the array indices (of the arrays above, holding peptide_accession)
       if ( exists $index_hash{$peptide_accession[$ind]} ) {

           $index_hash{$peptide_accession[$ind]} = 
               join " ", $index_hash{$peptide_accession[$ind]}, $ind;

       } else {

           $index_hash{$peptide_accession[$ind]} = $ind;

       }

       $n_protein_mappings[$ind] = 1; #unless replaced in next section

       $n_genome_locations[$ind] = 1; #unless replaced in next section

       $is_exon_spanning[$ind]= 'n';  #unless replaced in next section
 
       $ind++;

   }   ## end reading coordinate mapping file

   close(INFILE) or die "Cannot close $infile ($!)";


   if ($TESTVARS) {

       print "Checking array values after read of file $infile \n";

       for(my $i =0; $i <= $#peptide_accession; $i++){

           my $tmp_pep_acc = $peptide_accession[$i];
           my $tmp_biosequence_name = $biosequence_name[$i];
           my $tmp_start_in_biosequence = $start_in_biosequence[$i];
           my $tmp_end_in_biosequence = $end_in_biosequence[$i];
	   my $tmp_chromosome = $chromosome[$i];
           my $tmp_strand = $strand_xlate{$strand[$i]} ;
           my $tmp_start_in_chromosome = $start_in_chromosome[$i];
           my $tmp_end_in_chromosome = $end_in_chromosome[$i];
           my $tmp_n_genome_locations = $n_genome_locations[$i];
           my $tmp_is_exon_spanning = $is_exon_spanning[$i];
           my $tmp_n_protein_mappings = $n_protein_mappings[$i];
           

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

       print "   end second stage test of vars\n";
        
   }


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
               ##is that key = $peptide_accession[$i_ind]  ?
               my %inverse_index_hash = reverse %index_hash;

               die "check accession numbers in index_hash" 
                   if ($inverse_index_hash{$tmp_ind_str} != $peptide_accession[$i_ind]); 

           }
       }
   } 

 
   ## n_protein_mappings -- Number of distinct accession numbers (proteins) 
   ##                       that a peptide maps to
   ## n_genome_locations -- Number of mappings to Genome where protein is not the same
   ##                       (in other words, counts span over exons only once)
   ## is_exon_spanning  --  Whether a peptide has been mapped to a protein more than
   ##                       once (with different chromosomal coordinates), and not
   ##                       mapping the entire peptide sequence.  Some proteins have
   ##                       repeated sequences, so want to make sure not recording
   ##                       those as exon_spanning

   ## protein_mappings_hash:  1st key = peptide, 2nd key = protein, value=anything
   ## --> n_protein_mappings = keys ( $protein_mappings_hash{$peptide} )
   ##
   ## genome_locations_hash:  1st key = peptide, 2nd key = "chrom:start_chrom:end_chrom"
   ## --> n_genome_locations = see below
   ##
   ## is_exon_spanning_hash:  1st key = peptide, 2nd key = protein,
   ##                         value = 'y' if (  (diff_coords + 1) != (seq_length*3);

   print "\nCalculating n_protein_mappings, n_genome_locations, and is_exon_spanning\n";

   ## looping through a peptide's array indices to calculate these:
   foreach my $tmp_ind_str (values ( %index_hash ) ) {  #key = peptide_accession

       my @tmp_ind_array = split(" ", $tmp_ind_str);
 
       my (%protein_mappings_hash, %genome_locations_hash, %is_exon_spanning_hash);

       ## will skip 1st key = peptide in hashes below, and instead, 
       ## reset hash for each peptide
       reset %protein_mappings_hash; ## necessary?  above declaration should have cleared these?
       reset %genome_locations_hash;
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

       print "Checking storage of values after counting calculations \n";

       for(my $i =0; $i <= $#peptide_accession; $i++){

           my $tmp_pep_acc = $peptide_accession[$i];

           my $tmp_strand = $strand_xlate{$strand[$i]} ;
           my $tmp_peptide_id = $peptides{$tmp_pep_acc};
           my $tmp_best_probability = $APD_best_probability{$tmp_pep_acc};
           my $tmp_n_obs = $APD_n_observations{$tmp_pep_acc};
           my $tmp_search_batch_ids = $APD_search_batch_ids{$tmp_pep_acc};
           my $tmp_sample_ids = $APD_sample_ids{$tmp_pep_acc};
           my $tmp_n_genome_locations = $n_genome_locations[$i];
           my $tmp_is_exon_spanning = $is_exon_spanning[$i];
           my $tmp_n_protein_mappings = $n_protein_mappings[$i];
           my $tmp_peptide_instance_id = $loaded_peptides{$tmp_pep_acc};
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

       print "   end third stage test of vars\n";
   }


   ####----------------------------------------------------------------------------
   ## Loading peptides with mappings into tables:
   ##    peptide_instance, peptide_instance_sample, and peptide_mapping
   ####----------------------------------------------------------------------------
   print "\nLoading mapped peptides into peptide_instance, ".
       "peptide_instance_sample, and peptide_mapping tables\n";

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
               n_observations => ,$APD_n_observations{$tmp_pep_acc},
               search_batch_ids => ,$APD_search_batch_ids{$tmp_pep_acc},
               sample_ids => ,$APD_sample_ids{$tmp_pep_acc},
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
       $APD_is_subpeptide_of{$sub_pep_acc} = '"'.$APD_is_subpeptide_of{$sub_pep_acc}.'"';

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
