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
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          If set, rows in the database are not changed or added
  --delete_existing   Delete the existing data before trying to load
  --atlas_build_name  Name of the atlas build (already entered by hand in
                      the atlas_build table) into which to load the data
  --source_dir        Name of the source file from which data are loaded
  --organism_abbrev   Abbreviation of organism like Hs

 e.g.:  $PROG_NAME --atlas_build_name "Human Build 01 from APD"

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "delete_existing","atlas_build_name:s","source_dir:s",
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
  my $delete_existing = $OPTIONS{"delete_existing"} || '';
  my $source_dir = $OPTIONS{"source_dir"} || '';
  my $atlas_build_name = $OPTIONS{"atlas_build_name"} || '';

  #### Verify required parameters
  unless ($atlas_build_name) {
    print "ERROR: You must specify an --atlas_build_name\n\n";
    print "$USAGE";
    exit;
  }

  unless ($OPTIONS{'organism_abbrev'}) {
    print "ERROR: Must supply organism_abbrev\n";
    print "$USAGE";
    return;
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


  #### Verify the source_file
  if ( $source_dir && !(-d $source_dir) ) {
    print "ERROR: Unable to access source_dir '$source_dir'\n\n";
    return;
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

  #### Get the current list of peptides in the peptide table
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


  #### Open the file containing the input peptide properties
  unless (open(INFILE,"$source_dir/APD_$OPTIONS{organism_abbrev}_all.tsv")) {
    print "ERROR: Unable to open for reading input file ".
      "'$source_dir/APD_$OPTIONS{organism_abbrev}_all.tsv'\n\n";
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
  my $counter = 0;
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my @columns = split(/\t/,$line);

    my $peptide_accession = $columns[$column_indices{peptide_identifier_str}];
    my $peptide_sequence = $columns[$column_indices{peptide}];
    my $peptide_length = length($peptide_sequence);
    my $best_probability = $columns[$column_indices{maximum_probability}];
    my $n_observations = $columns[$column_indices{n_peptides}];
    #### FIXME !!!! APD output has two columns names with the same name!!
    my $sample_ids = $columns[$column_indices{maximum_probability}+2];


    #### If this doesn't yet exist in the database table "peptide", add it
    my $peptide_id = $peptides{$peptide_accession};

    unless ($peptide_id) {
      my %rowdata = (             ##  peptide     table attributes:
        peptide_accession => $peptide_accession,
        peptide_sequence => $peptide_sequence,
        peptide_length => $peptide_length,
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

    } # end unless

    ## create peptide_instance entries
    $peptides{$peptide_accession} = { ##peptide_instance     table attributes:
      peptide_id => $peptide_id,
      best_probability => $best_probability,
      n_observations => $n_observations,
      sample_ids => $sample_ids,
    };

    my %rowdata = ( ##   peptide_instance    table attributes
      atlas_build_id => $atlas_build_id,
      peptide_id => $peptide_id,
      best_probability => $best_probability,
      n_observations => ,$n_observations,
      sample_ids => ,$sample_ids,
      n_mapped_locations => '0',
      is_exon_spanning => 'n',
    );  ## entered some dummy values above

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
## end peptide_instance entries
 
    $counter++;

  } # end while INFILE
  close(INFILE);
  my $peptides_last_ind = $counter - 1;


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


  #### Define a hash to hold the loaded peptides
  my %loaded_peptides;
  my $peptide_instance_id = -1;
  my %strand_xlate = (
		      '-' => '-',
		      '+' => '+',
		      '-1' => '-',
		      '+1' => '+',
		      '1' => '+',
		     );

  #### Load the relevant information in the coordinate mapping file:
  ## storage in arrays to look at all entries to calculate 
  ## n_mapped_locations and is_exon_spanning
  my %index_hash; # key   = $peptide_accession[$ind], 
                  # value = string of array indices
  my (@peptide_accession, @biosequence_name, @start_in_biosequence, 
      @end_in_biosequence, @chromosome, @strand, @start_in_chromosome, 
      @end_in_chromosome, @n_mapped_locations, @is_exon_spanning);

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

     ## calculate n_mapped_locations, with hash of peptide_accessions
     if ( exists $index_hash{$peptide_accession[$ind]} ) {
        $index_hash{$peptide_accession[$ind]} = 
          join " ", $index_hash{$peptide_accession[$ind]}, $ind;
     } else {
        $index_hash{$peptide_accession[$ind]} = $ind;
     }
     $n_mapped_locations[$ind] = 1; #until next section
     $is_exon_spanning[$ind]= 'n';  #until next section

     $ind++;
  }
  close(INFILE);
  my $last_ind = $ind - 1;


  #  print "size of hash = " . keys( %index_hash ) . ".\n";
  ##looping through indices of multiple peptide identifications:
  foreach my $tmp_ind_str (values ( %index_hash ) ) {
     my @tmp_ind_array = split(" ", $tmp_ind_str);
     my $last_ind = $#tmp_ind_array;
     ## making match_coords_hash with key = protein names which are same 
     ## in subset of multiple responses...
     ##    values = string of chromosome coords
     ## then, size of %match_coords_hash gives n_mapped_locations
     my %match_coords_hash;
     foreach (@tmp_ind_array) {
        my $coord_str = $start_in_chromosome[$_] . ":" . $end_in_chromosome[$_];
        $match_coords_hash{$biosequence_name[$_]} = 
        $match_coords_hash{$biosequence_name[$_]} . " " . $coord_str;
     }

     foreach my $t_ind (@tmp_ind_array) {
        $n_mapped_locations[$t_ind] = keys( %match_coords_hash ); #size of hash
        ## look-up coordinates in that name set, and if split coords 
        ## are not equal, is_exon_spanning = 'y'
        my @tmp_coord_list = split(" ", $match_coords_hash{$biosequence_name[$t_ind]});
        for (my $t=0; $t < $#tmp_coord_list; $t++) {
           if ($tmp_coord_list[$t] ne $tmp_coord_list[$t+1]){
              $is_exon_spanning[$t_ind] = 'y';
           }
        }
     }
  }

  ### ABOVE, n_mapped_locations and is_exon_spanning modeled following rules:
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


  for(my $i =0; $i < $last_ind; $i++){
    my $tmp = $strand_xlate{$strand[$i]}
      or die("ERROR: Unable to translate strand $strand[$i]");
    $strand[$i] = $tmp;

    #### Make sure we can resolve the biosequence_id
    my $biosequence_id = $biosequence_ids{$biosequence_name[$i]}
      || die("ERROR: BLAST matched biosequence_name $biosequence_name[$i] ".
	     "does not appear to be in the biosequence table!!");

    #### If this peptide_instance hasn't yet been added to the database, add it
    if ($loaded_peptides{$peptide_accession[$i]}) {
      $peptide_instance_id = $loaded_peptides{$peptide_accession[$i]};

    } else {

      my $peptide_id = $peptides{$peptide_accession[$i]}->{peptide_id} ||
	die("ERROR: Wanted to insert data for peptide $peptide_accession[$i] ".
	    "which is in the BLAST output summary, but not in the input ".
	    "peptide file??");

      my %rowdata = (   ##   peptide_instance    table attributes
        atlas_build_id => $atlas_build_id,
        peptide_id => $peptide_id,
        best_probability => $peptides{$peptide_accession[$i]}->{best_probability},
        n_observations => ,$peptides{$peptide_accession[$i]}->{n_observations},
        sample_ids => ,$peptides{$peptide_accession[$i]}->{sample_ids},
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


    #### Now INSERT this peptide_mapping
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


} # end handleRequest
