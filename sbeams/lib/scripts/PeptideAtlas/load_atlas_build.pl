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
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
$q = CGI->new();


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
  --delete               Delete existing atlas build. Does not build an atlas.
  --purge                Delete child records in atlas build (retains parent atlas record).
  --load                 build an atlas...can be used in conjunction with --purge
  --atlas_build_name     Name of the atlas build (already entered by hand in
                         the atlas_build table) into which to load the data
  --source_dir           Name of the source file from which data are loaded
  --organism_abbrev      Abbreviation of organism like Hs

 e.g.:  ./load_atlas_build.pl --atlas_build_name "HumanEns21P0.7" --organism_abbrev "Hs" --purge --load --source_dir "/net/db/projects/PeptideAtlas/pipeline/output/HumanV34dP0.9/DATA_FILES"

 e.g.: ./load_atlas_build.pl --atlas_build_name "TestAtlas" --delete
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "delete", "purge", "load",
        "atlas_build_name:s","source_dir:s",
        "organism_abbrev:s",
     )) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
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
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>'PeptideAtlas_admin',
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);


} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {
  my %args = @_;

  #### Set the command-line options
  my $del = $OPTIONS{"delete"} || '';
  my $purge = $OPTIONS{"purge"} || '';
  my $load = $OPTIONS{"load"} || '';
  my $source_dir = $OPTIONS{"source_dir"} || '';
  my $organism_abbrev = $OPTIONS{"organism_abbrev"} || '';
  my $atlas_build_name = $OPTIONS{"atlas_build_name"} || '';

  #### Verify required parameters
  unless ($atlas_build_name) {
    print "ERROR: You must specify an --atlas_build_name\n\n";
    print "$USAGE";
    exit;
  }

  ## --delete with --load will not work
  if ($del && $load) {
      print "ERROR: --delete --load will not work.\n";
      print "  use: --purge --load instead\n\n";
      print "$USAGE";
      exit;
  }


  ## --delete with --purge will not work
  if ($del && $purge) {
      print "ERROR: select --delete or --purge, but not both\n";
      print "$USAGE";
      exit;
  }


  #### If there are any parameters left, complain and print usage
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

  ## HANDLING OPTIONS  

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
     if (@peptide_instance_array) { 
        print "ERROR: Records already exist in atlas $\atlas_build name\n";
        print "To purge existing records and load new records\n";
        print "  use: --purge --load \n";
        print "$USAGE";
        return;
     }

     print "Building atlas $atlas_build_name ($atlas_build_id): \n";
  
     buildAltas(atlas_build_id => $atlas_build_id,
                biosequence_set_id => $biosequence_set_id,
                source_dir => $source_dir,
                organism_abbrev => $organism_abbrev);

  } ## end --load

} # end handleRequest

###############################################################################
# removeAtlas -- removes atlas build records
#
#   has option --keep_parent to keep parent record (used with purge)
###############################################################################
sub removeAtlas {
   my %args = @_;
   my $atlas_build_id = $args{'atlas_build_id'};
   my $keep_parent_record = $args{'keep_parent_record'} || 0;

   my $table_name = "atlas_build";
   my $database_name = "peptideatlas.dbo.";
   my $full_table_name = "$database_name$table_name";

   my %table_child_relationship = (
      atlas_build => 'peptide_instance(C)',
      peptide_instance => 'peptide_mapping(C)',
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
sub buildAltas {  
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
 
 
   #### Get the current list of biosequences in this set
   $sql = qq~
     SELECT biosequence_name,biosequence_id
       FROM $TBAT_BIOSEQUENCE
      WHERE biosequence_set_id = '$biosequence_set_id'
   ~;
   my %biosequence_ids = $sbeams->selectTwoColumnHash($sql);
 
 
   ## READ APD file of experiment peptides
   #### Open the file containing the input peptide properties
   unless (open(INFILE,"${source_dir}/APD_${organism_abbrev}_all.tsv")) {
     print "ERROR: Unable to open for reading input file ".
       "'${source_dir}/APD_${organism_abbrev}_all.tsv'\n\n";
     return;
   }
 
 
   #### Read and parse the header line of APD_{organism}_all.tsv
   my $line;
   $line = <INFILE>;
   $line =~ s/[\r\n]//g;
   my @column_names = split(/\t/,$line);
   my $i = 0;
   my %column_indices;
   foreach my $column_name (@column_names) {
     $column_indices{$column_name} = $i;
     $i++;
   }
 
 
   #### Load the relevant information in the peptide input file
   ## storing APD info in hashes with keys of peptide_id (can be found as $peptides{$peptide_accession[$i]})
   my $counter = 0;
   my (%APD_peptide_accession, %APD_peptide_sequence, %APD_peptide_length, %APD_best_probability);
   my (%APD_n_observations, %APD_sample_ids, %APD_peptide_id);
   while ($line = <INFILE>) {
     $line =~ s/[\r\n]//g;
     my @columns = split(/\t/,$line);
 
     my $tmp_pep_id = $peptides{$columns[$column_indices{peptide_identifier_str}]};
     $APD_peptide_accession{$tmp_pep_id} = $columns[$column_indices{peptide_identifier_str}];
     $APD_peptide_sequence{$tmp_pep_id} = $columns[$column_indices{peptide}];
     $APD_peptide_length{$tmp_pep_id} = length($APD_peptide_sequence{$tmp_pep_id});
     $APD_best_probability{$tmp_pep_id} = $columns[$column_indices{maximum_probability}];
     $APD_n_observations{$tmp_pep_id} = $columns[$column_indices{n_peptides}];
     #### FIXME !!!! APD output has two columns names with the same name!!
     $APD_sample_ids{$tmp_pep_id} = $columns[$column_indices{maximum_probability}+2];
 
     #### If this doesn't yet exist in the database table "peptide", add it
     $APD_peptide_id{$tmp_pep_id} = $peptides{$APD_peptide_accession{$tmp_pep_id}};
 
     unless ($APD_peptide_id{$tmp_pep_id}) {
       my %rowdata = (             ##  peptide     table attributes:
         peptide_accession => $APD_peptide_accession{$tmp_pep_id},
         peptide_sequence => $APD_peptide_sequence{$tmp_pep_id},
         peptide_length => $APD_peptide_length{$tmp_pep_id},
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
 
       ## re-read peptides hash to include new peptide_id:
       $sql = qq~
          SELECT peptide_accession,peptide_id
          FROM $TBAT_PEPTIDE
       ~;
       %peptides = $sbeams->selectTwoColumnHash($sql);
 
       ## and enter that in APD_peptide_id hash:
       $APD_peptide_id{$tmp_pep_id} = $peptides{$APD_peptide_accession{$tmp_pep_id}};
     } # end unless
 
     $counter++;
 
   } # end while INFILE
   close(INFILE);
   my $APD_last_ind = $counter - 1;
 
 
   ## READ peptides found in Ensembl along with their coord info:
   #### Open the file containing the BLAST alignment summary
   unless (open(INFILE,"$source_dir/coordinate_mapping.txt")) {
     print "ERROR: Unable to open for reading input file ".
       "'$source_dir/coordinate_mapping.txt'\n\n";
     return;
   }
 
   #### Read and parse the header line of coordinate_mapping.txt
   if (0 == 1) {
     $line = <INFILE>;
     $line =~ s/[\r\n]//g;
     my @column_names = split(/\t/,$line);
     my $i = 0;
     foreach my $column_name (@column_names) {
         $column_indices{$column_name} = $i;
     }
   }
 
   #### Define a hash to hold the loaded Ensembl hits:
   my %loaded_peptides;
   my $peptide_instance_id = -1;
   my %strand_xlate = (
 		      '-' => '-',
 		      '+' => '+',
 		      '-1' => '-',
 		      '+1' => '+',
 		      '1' => '+',
 		     );
 
 
   my %index_hash; # key   = $peptide_accession[$ind], 
                   # value = string of array indices
 
   ## storage in arrays to later calculate n_mapped_locations and is_exon_spanning
   my (@peptide_accession, @biosequence_name, @start_in_biosequence, 
   @end_in_biosequence, @chromosome, @strand, @start_in_chromosome, 
   @end_in_chromosome, @n_mapped_locations, @is_exon_spanning);
 
   #### Load the relevant information in the coordinate mapping file:
   my $ind=0;
   while ($line = <INFILE>) {
      $line =~ s/[\r\n]//g;
      my @columns = split(/\t/,$line);
  
      $peptide_accession[$ind] = $columns[0];
      $biosequence_name[$ind] = $columns[2];
      $start_in_biosequence[$ind] = $columns[5];
      $end_in_biosequence[$ind] = $columns[6];
      $chromosome[$ind] = $columns[8];
      $strand[$ind] = $columns[9];
      $start_in_chromosome[$ind] = $columns[10];
      $end_in_chromosome[$ind] = $columns[11];
 
      ## making hash, keys =  peptide_accession
      ##              values = the array indices (of the arrays above, holding info for the peptide_accession)
      if ( exists $index_hash{$peptide_accession[$ind]} ) {
         $index_hash{$peptide_accession[$ind]} = 
           join " ", $index_hash{$peptide_accession[$ind]}, $ind;
      } else {
         $index_hash{$peptide_accession[$ind]} = $ind;
      }
      $n_mapped_locations[$ind] = 1; #unless replaced in next section
      $is_exon_spanning[$ind]= 'n';  #unless replaced in next section
 
      $ind++;
   }
   close(INFILE);
   my $last_ind = $ind - 1;
 
 
   #  print "size of hash = " . keys( %index_hash ) . ".\n";
   ## looping through indices of multiple peptide identifications:
   foreach my $tmp_ind_str (values ( %index_hash ) ) {
      my @tmp_ind_array = split(" ", $tmp_ind_str);
      my $last_ind = $#tmp_ind_array;
      ## making match_coords_hash with key = protein names which are same 
      ## in subset of multiple responses...
      ##    values = string of chromosome coords
      ## then, size of %match_coords_hash gives n_mapped_locations
      my %match_coords_hash;
 
      for (my $ii = 0; $ii <= $#tmp_ind_array; $ii++) {
         my $i_ind=$tmp_ind_array[$ii];
         $n_mapped_locations[$i_ind] = $#tmp_ind_array + 1;
         for (my $jj = ($ii + 1); $jj <= $#tmp_ind_array; $jj++) {
            my $j_ind=$tmp_ind_array[$jj];
            if ($biosequence_name[$i_ind] eq $biosequence_name[$j_ind]) {
               if ($start_in_chromosome[$i_ind] != $start_in_chromosome[$j_ind]) {
                  $is_exon_spanning[$i_ind] = 'y';
                  $is_exon_spanning[$j_ind] = 'y';
               }     
            }
         }
      }
   } ## end calculate n_mapped_locations and is_exon_spanning loop
 
   ### ABOVE modeled following rules:
   ##
   ## APDpep00011291  9       ENSP00000295561 ... 24323279        24323305
   ## APDpep00011291  9       ENSP00000336741 ... 24323279        24323305
   ## ---> n_mapped_locations = 2 for both
   ## ---> is_exon_spanning   = n for both
   ##
   ## APDpep00004221  13      ENSP00000317473 ... 75675871        75675882
   ## APDpep00004221  13      ENSP00000317473 ... 75677437        75677463
   ## ---> n_mapped_locations = 1 for both
   ## ---> is_exon_spanning   = y for both
   ## 
   ## APDpep00004290  16      ENSP00000306222 ...   1151627         1151633
   ## APDpep00004290  16      ENSP00000306222 ...   1151067         1151107
   ## APDpep00004290  16      ENSP00000281456 ... 186762937       186762943
   ## APDpep00004290  16      ENSP00000281456 ... 186763858       186763898
   ## ---> n_mapped_locations = 2 for all
   ## ---> is_exon_spanning   = y for all
 
 
   for(my $i =0; $i <= $last_ind; $i++){
     my $tmp = $strand_xlate{$strand[$i]}
       or die("ERROR: Unable to translate strand $strand[$i]");
     $strand[$i] = $tmp;
 
     #### Make sure we can resolve the biosequence_id
     my $biosequence_id = $biosequence_ids{$biosequence_name[$i]}
       || die("ERROR: BLAST matched biosequence_name $biosequence_name[$i] ".
 	     "does not appear to be in the biosequence table!!");
 
     #### If this peptide_instance hasn't yet been added to the database, add it
     ## Note: nothing has been loaded into peptide_instance at this point, but
     ## maybe this is here for subsequent additions to existing atlas?
     if ($loaded_peptides{$peptide_accession[$i]}) {
       $peptide_instance_id = $loaded_peptides{$peptide_accession[$i]};
 
     } else {
 
       my $peptide_id = $peptides{$peptide_accession[$i]} ||
 	die("ERROR: Wanted to insert data for peptide $peptide_accession[$i] ".
 	    "which is in the BLAST output summary, but not in the input ".
 	    "peptide file??");
 
       my %rowdata = (   ##   peptide_instance    table attributes
         atlas_build_id => $atlas_build_id,
         peptide_id => $peptide_id,
         best_probability => $APD_best_probability{$peptides{$peptide_accession[$i]}},
         n_observations => $APD_n_observations{$peptides{$peptide_accession[$i]}},
         sample_ids => $APD_sample_ids{$peptides{$peptide_accession[$i]}},
         n_mapped_locations => $n_mapped_locations[$i],
         is_exon_spanning => $is_exon_spanning[$i],
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
 
     }
 
 
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
   
   } #end for loop
 
   print "\n";
 
 
   ## Making entries in peptide_instance for peptides that weren't hits in Ensembl:

   ## make sql call to get hash of peptide_id and any other variable...
     $sql = qq~
      SELECT peptide_id,atlas_build_id
      FROM $TBAT_PEPTIDE_INSTANCE
      WHERE atlas_build_id = '$atlas_build_id'
   ~;
   my %peptide_instances = $sbeams->selectTwoColumnHash($sql);
 
   foreach my $tmp_pep_id (values %APD_peptide_id ) {
 
      if ($peptide_instances{$tmp_pep_id}) {
 
         ##  do nothing if it exists
 
      } else {
 
         ## create peptide_instance entries
         my %rowdata = ( ##   peptide_instance    table attributes
            atlas_build_id => $atlas_build_id,
            peptide_id => $tmp_pep_id,
            best_probability => $APD_best_probability{$tmp_pep_id},
            n_observations => ,$APD_n_observations{$tmp_pep_id},
            sample_ids => ,$APD_sample_ids{$tmp_pep_id},
            n_mapped_locations => '0',
            is_exon_spanning => 'n',
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
      }
   } ## end peptide_instance entries for those not in Ensembl
}# end buildAtlas
