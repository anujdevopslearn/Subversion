#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_biosequence_set.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads a biosequence set (gene library) from a
#               FASTA file.  Note that there may be some cusomtization for
#               the particular library to populate gene_name and accesssion
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
	     $TESTONLY
             $current_contact_id $current_username
	     $fav_codon_frequency $n_transmembrane_regions
	     $rosetta_lookup $pfam_search_results $ginzu_search_results
             $mamSum_search_results $InterProScan_search_results
             %domain_match_types %domain_match_sources
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::Proteomics::Utilities;

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n          Set verbosity level.  default is 0
  --quiet              Set flag to print nothing at all except errors
  --debug n            Set debug flag
  --testonly           If set, rows in the database are not changed or added
  --delete_existing    Delete the existing biosequences for this set before
                       loading.  Normally, if there are existing biosequences,
                       the load is blocked.
  --update_existing    Update the existing biosequence set with information
                       in the file
  --skip_sequence      If set, only the names, descs, etc. are loaded;
                       the actual sequence (often not really necessary)
                       is not written
  --set_tag            The set_tag of a biosequence_set that is to be worked
                       on; all are checked if none is provided
  --file_prefix        A prefix that is prepended to the set_path in the
                       biosequence_set table
  --check_status       Is set, nothing is actually done, but rather the
                       biosequence_sets are verified
  --fav_codon_frequency_file   Full path name of a file from which to load
                       favored codon frequency values
  --n_transmembrane_regions_file   Full path name of a file from which to load
                       number of transmembrane regions values
  --calc_n_transmembrane_regions
                       Set flag to add in n_transmembrane_regions calculations
  --rosetta_lookup_file   Full path name of a file which containts
                       lookup information for converting rosetta names
                       to biosequence_names
  --pfam_search_results_summary_file   Full path name of a file from which
                       to load the pfam search results
  --ginzu_search_results_dir   Full path name of a directory in which
                       there are a bunch of .domains files to load
  --mamSum_search_results_summary_file   Full path name of a file from which
                       to load the mamSum search results
  --InterProScan_search_results_summary_file   Full path name of a file
                       from which to load the InterProScan search results

 e.g.:  $PROG_NAME --check_status

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
    "delete_existing","update_existing","skip_sequence",
    "set_tag:s","file_prefix:s","check_status","fav_codon_frequency_file:s",
    "calc_n_transmembrane_regions","n_transmembrane_regions_file:s",
    "rosetta_lookup_file:s","pfam_search_results_summary_file:s",
    "ginzu_search_results_dir:s","mamSum_search_results_summary_file:s",
    "InterProScan_search_results_summary_file:s",
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

  #### Try to determine which module we want to affect
  my $module = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ($module eq 'Proteomics') {
    $work_group = "${module}_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Biosap') {
    $work_group = "Biosap";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'SNP') {
    $work_group = "SNP";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Microarray') {
    $work_group = "Microarray_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'ProteinStructure') {
    $work_group = "ProteinStructure_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'BioLink') {
    $work_group = "BioLink_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'PeptideAtlas') {
    $work_group = "PeptideAtlas_admin";
    $DATABASE = $DBPREFIX{$module};
  }


  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>$work_group,
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


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"} || '';
  my $update_existing = $OPTIONS{"update_existing"} || '';
  my $skip_sequence = $OPTIONS{"skip_sequence"} || '';
  my $check_status = $OPTIONS{"check_status"} || '';
  my $set_tag = $OPTIONS{"set_tag"} || '';
  my $file_prefix = $OPTIONS{"file_prefix"} || '';
  my $fav_codon_frequency_file = $OPTIONS{"fav_codon_frequency_file"} || '';
  my $n_transmembrane_regions_file =
    $OPTIONS{"n_transmembrane_regions_file"} || '';
  my $rosetta_lookup_file =
    $OPTIONS{"rosetta_lookup_file"} || '';
  my $pfam_search_results_summary_file =
    $OPTIONS{"pfam_search_results_summary_file"} || '';
  my $ginzu_search_results_dir =
    $OPTIONS{"ginzu_search_results_dir"} || '';
  my $mamSum_search_results_summary_file =
    $OPTIONS{"mamSum_search_results_summary_file"} || '';
  my $InterProScan_search_results_summary_file =
    $OPTIONS{"InterProScan_search_results_summary_file"} || '';


  #### Get the file_prefix if it was specified, and otherwise guess
  unless ($file_prefix) {
    my $module = $sbeams->getSBEAMS_SUBDIR();
    #$file_prefix = '/regis' if ($module eq 'Proteomics');
  }


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Define a scalar and array of biosequence_set_id's
  my ($biosequence_set_id,$n_biosequence_sets);
  my @biosequence_set_ids;

  #### If there was a set_tag specified, identify it
  if ($set_tag) {
    $sql = qq~
          SELECT BSS.biosequence_set_id
            FROM ${DATABASE}biosequence_set BSS
           WHERE BSS.set_tag = '$set_tag'
             AND BSS.record_status != 'D'
    ~;

    @biosequence_set_ids = $sbeams->selectOneColumn($sql);
    $n_biosequence_sets = @biosequence_set_ids;

    die "No biosequence_sets found with set_tag = '$set_tag'"
      if ($n_biosequence_sets < 1);
    die "Too many biosequence_sets found with set_tag = '$set_tag'"
      if ($n_biosequence_sets > 1);


  #### If there was NOT a set_tag specified, scan for all available ones
  } else {
    $sql = qq~
          SELECT biosequence_set_id
            FROM ${DATABASE}biosequence_set
           WHERE record_status != 'D'
    ~;

    @biosequence_set_ids = $sbeams->selectOneColumn($sql);
    $n_biosequence_sets = @biosequence_set_ids;

    die "No biosequence_sets found in this database"
      if ($n_biosequence_sets < 1);

  }


  #### If a fav codon freq file was specified, load it for later processing
  if ($fav_codon_frequency_file) {
    $fav_codon_frequency->{zzzHASH} = -1;
    readFavCodonFrequencyFile(
      source_file => $fav_codon_frequency_file,
      fav_codon_frequency => $fav_codon_frequency);
  }


  #### If a rosetta_lookup_file was specified,
  #### load it for later processing
  if ($rosetta_lookup_file) {
    $rosetta_lookup->{zzzHASH} = -1;
    readRosettaLookupFile(
      source_file => $rosetta_lookup_file,
      rosetta_lookup => $rosetta_lookup);
  }


  #### If one of the ProteinStructure options was specified
  if ($pfam_search_results_summary_file ||
      $ginzu_search_results_dir ||
      $mamSum_search_results_summary_file ||
      $InterProScan_search_results_summary_file) {
    %domain_match_types = $sbeams->selectTwoColumnHash(
      "SELECT domain_match_type_name,domain_match_type_id ".
      "  FROM ${DATABASE}domain_match_type WHERE record_status != 'D'");
    %domain_match_sources = $sbeams->selectTwoColumnHash(
      "SELECT domain_match_source_name,domain_match_source_id ".
      "  FROM ${DATABASE}domain_match_source WHERE record_status != 'D'");
  }




  #### If a pfam_search_results_summary_file was specified,
  #### load it for later processing
  if ($pfam_search_results_summary_file) {
    $pfam_search_results->{zzzHASH} = -1;
    readPFAMSearchSummaryFile(
      source_file => $pfam_search_results_summary_file,
      pfam_search_results => $pfam_search_results);
  }


  #### If a ginzu_search_results_dir was specified,
  #### load it for later processing
  if ($ginzu_search_results_dir) {
    $ginzu_search_results->{zzzHASH} = -1;
    readGinzuFiles(
      source_dir => $ginzu_search_results_dir,
      ginzu_search_results => $ginzu_search_results);
  }

  #### If a mamSum_search_results_summary_file was specified,
  #### load it for later processing
  if ($mamSum_search_results_summary_file) {
    $mamSum_search_results = readMamSumFile(
      source_file => $mamSum_search_results_summary_file,
    );
  }


  #### If a InterProScan_search_results_summary_file was specified,
  #### load it for later processing
  if ($InterProScan_search_results_summary_file) {
    $InterProScan_search_results = readInterProScanFile(
      source_file => $InterProScan_search_results_summary_file,
    );
  }


  #### If a n_transmembrane_regions_file was specified,
  #### load it for later processing
  if ($n_transmembrane_regions_file) {
    $n_transmembrane_regions->{zzzHASH} = -1;
    readNTransmembraneRegionsFile(
      source_file => $n_transmembrane_regions_file,
      n_transmembrane_regions => $n_transmembrane_regions);
  }


  #### Loop over each biosequence_set, determining its status and processing
  #### it if desired
  print "        set_tag      n_rows -e Dt set_path\n";
  print "---------------  ----------  - -- -------------------------------\n";
  foreach $biosequence_set_id (@biosequence_set_ids) {
    my $status = getBiosequenceSetStatus(
      biosequence_set_id => $biosequence_set_id);
    printf("%15s  %10d  %s %s %s\n",$status->{set_tag},$status->{n_rows},
      $status->{file_exists},$status->{is_up_to_date},$status->{set_path});

    #### If we're not just checking the status
    unless ($check_status) {
      my $do_load = 0;
      $do_load = 1 if ($status->{n_rows} == 0);
      $do_load = 1 if ($update_existing);
      $do_load = 1 if ($delete_existing);

      #### If it's determined that we need to do a load, do it
      if ($do_load) {
        $result = loadBiosequenceSet(set_name=>$status->{set_name},
				     source_file=>$file_prefix.$status->{set_path},
				     organism_id=>$status->{organism_id});
      }
    }
  }


  return;

}



###############################################################################
# getBiosequenceSetStatus
###############################################################################
sub getBiosequenceSetStatus {
  my %args = @_;
  my $SUB_NAME = 'getBiosequenceSetStatus';


  #### Decode the argument list
  my $biosequence_set_id = $args{'biosequence_set_id'}
   || die "ERROR[$SUB_NAME]: biosequence_set_id not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Get information about this biosequence_set_id from database
  $sql = qq~
          SELECT BSS.biosequence_set_id,organism_id,set_name,set_tag,set_path,
                 set_version,source_file_date
            FROM ${DATABASE}biosequence_set BSS
           WHERE BSS.biosequence_set_id = '$biosequence_set_id'
             AND BSS.record_status != 'D'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);


  #### Put the information in a hash
  my %status;
  $status{biosequence_set_id} = $rows[0]->[0];
  $status{organism_id} = $rows[0]->[1];
  $status{set_name} = $rows[0]->[2];
  $status{set_tag} = $rows[0]->[3];
  $status{set_path} = $rows[0]->[4];
  $status{set_version} = $rows[0]->[5];
  $status{source_file_date} = $rows[0]->[6];


  #### Get the number of rows for this biosequence_set_id from database
  $sql = qq~
          SELECT count(*) AS 'count'
            FROM ${DATABASE}biosequence BS
           WHERE BS.biosequence_set_id = '$biosequence_set_id'
  ~;
  my ($n_rows) = $sbeams->selectOneColumn($sql);


  #### See if the file exists
  $status{file_exists} = ' ';
  $status{file_exists} = '!' unless ( -e $status{set_path} );


  #### See if the file is up to date
  $status{is_up_to_date} = '  ';
  my @stats = stat($status{set_path});
  my $mtime = $stats[9];
  my $source_file_date;
  if ($mtime && $status{source_file_date}) {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime($mtime);
    $source_file_date = sprintf("%d-%2d-%2d_%2d:%2d:%2d",
      1900+$year,$mon+1,$mday,$hour,$min,$sec);
    $source_file_date =~ s/ /0/g;
    $source_file_date =~ s/_/ /g;
    if ($source_file_date eq $status{source_file_date}) {
      $status{is_up_to_date} = 'OK';
    } else {
      $status{is_up_to_date} =
        "$source_file_date != $status{source_file_date}";
    }
  }


  #### Put the information in a hash
  $status{n_rows} = $n_rows;


  #### Return information
  return \%status;

}


###############################################################################
# loadBiosequenceSet
###############################################################################
sub loadBiosequenceSet {
  my %args = @_;
  my $SUB_NAME = 'loadBiosequenceSet';


  #### Decode the argument list
  my $set_name = $args{'set_name'}
   || die "ERROR[$SUB_NAME]: set_name not passed";
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";
  my $organism_id = $args{'organism_id'} || "";

  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"};
  my $update_existing = $OPTIONS{"update_existing"};
  my $skip_sequence = $OPTIONS{"skip_sequence"};


  #### Verify the source_file
  unless ( -e "$source_file" ) {
    die("ERROR[$SUB_NAME]: Cannot find file $source_file");
  }


  #### Set the set_name
  $sql = "SELECT set_name,biosequence_set_id" .
         "  FROM ${DATABASE}biosequence_set";
  #print "SQL: $sql\n";
  my %set_names = $sbeams->selectTwoColumnHash($sql);
  my $biosequence_set_id = $set_names{$set_name};


  #### If we didn't find it then bail
  unless ($biosequence_set_id) {
    bail_out("Unable to determine a biosequence_set_id for '$set_name'.  " .
      "A record for this biosequence_set must already have been entered " .
      "before the sequences may be loaded.");
  }


  #### Test if there are already sequences for this biosequence_set
  $sql = "SELECT COUNT(*) FROM ${DATABASE}biosequence ".
         " WHERE biosequence_set_id = '$biosequence_set_id'";
  my ($count) = $sbeams->selectOneColumn($sql);
  if ($count) {
    if ($delete_existing) {
      print "Deleting...\n";
      $sql = "DELETE FROM ${DATABASE}biosequence ".
             " WHERE biosequence_set_id = '$biosequence_set_id'";
      if ($TESTONLY) {
	  print "SQL: $sql\n";
      } else {
	  $sbeams->executeSQL($sql);
      }
    } elsif (!($update_existing)) {
      die("There are already biosequence records for this " .
        "biosequence_set.\nPlease delete those records before trying to load " .
        "new sequences,\nor specify the --delete_existing ".
        "or --update_existing flags.");
    }
  }


  #### Open annotation file and load data
  unless (open(INFILE,"$source_file")) {
    die("Cannot open file '$source_file'");
  }


  #### Create a hash to store biosequence_names that have been seen
  my %biosequence_names;


  #### Definitions for loop
  my ($biosequence_id,$biosequence_name,$biosequence_desc,$biosequence_seq);
  my $counter = 0;
  my ($information,$sequence,$insert,$update);
  $information = "####";


  #### Loop over all data in the file
  my $loopflag = 1;
  while ($loopflag) {

    #### At the end of file, set loopflag to 0, but finish this loop, writing
    #### the last entry to the database
    unless (defined($line=<INFILE>)) {
      $loopflag = 0;
      $line = ">BOGUS DESCRIPTION";
    }

    #### Strip CRs of all flavors
    $line =~ s/[\n\r]//g;

    #### If the line has a ">" and it's not the first, write the
    #### previous sequence to the database
    if (($line =~ />/) && ($information ne "####")) {
      my %rowdata;
      $information =~ /^(.*)>(\S+)/;
      $rowdata{biosequence_name} = $2;

      #### Print a warning if malformed
      if ($1) {
	print "\nWARNING: Header line possibly malformed:\n$information\n".
	  "Ignoring all characters before >\n";
      }

      $information =~ /^>(\S+)\s(.+)/;
      $rowdata{biosequence_desc} = $2 || '';
      $rowdata{biosequence_set_id} = $biosequence_set_id;
      $rowdata{biosequence_seq} = $sequence unless ($skip_sequence);
      $rowdata{organism_id} = $organism_id if ($DATABASE eq 'sbeams.dbo.');

      #### Do special parsing depending on which genome set is being loaded
      $result = specialParsing(biosequence_set_name=>$set_name,
        rowdata_ref=>\%rowdata);


      #### If we're updating, then try to find the appropriate record
      #### The whole program could be sped up quite a bit by doing a single
      #### select and returning a single hash at the beginning of the program
      $insert = 1; $update = 0;
      if ($update_existing) {
        $biosequence_id = get_biosequence_id(
          biosequence_set_id => $biosequence_set_id,
          biosequence_name => $rowdata{biosequence_name});
        if (defined($biosequence_id) && $biosequence_id > 0) {
          $insert = 0; $update = 1;
        } else {
          print "WARNING: INSERT instead of UPDATE ".
            "'$rowdata{biosequence_name}'\n";
        }
      }



      #### Verify that we haven't done this one already
      if ($biosequence_names{$rowdata{biosequence_name}}) {
        print "\nWARNING: Duplicate biosequence_name ".
          "'$rowdata{biosequence_name}'in file!  Skipping the duplicate.\n";

      } else {
        #### Insert the data into the database
        loadBiosequence(insert=>$insert,update=>$update,
          table_name=>"${DATABASE}biosequence",
          rowdata_ref=>\%rowdata,PK=>"biosequence_id",
          PK_value => $biosequence_id,
          verbose=>$VERBOSE,
	  testonly=>$TESTONLY,
          );

        $counter++;
      }


      #### Reset temporary holders
      $information = "";
      $sequence = "";

      #### Add this one to the list of already seen
      $biosequence_names{$rowdata{biosequence_name}} = 1;

      #### Print some counters for biosequences INSERTed/UPDATEd
      #last if ($counter > 5);
      print "$counter..." if ($counter % 100 == 0);

    }


    #### If the line has a ">" then parse it
    if ($line =~ />/) {
      $information = $line;
      $sequence = "";
    #### Otherwise, it must be sequence data
    } else {
      $sequence .= $line;
    }


  }


  close(INFILE);
  print "\n$counter rows INSERT/UPDATed\n";


  updateSourceFileDate(
    biosequence_set_id => $biosequence_set_id,
    source_file => $source_file,
  );

}



###############################################################################
# updateSourceFileDate
###############################################################################
sub updateSourceFileDate {
  my %args = @_;
  my $SUB_NAME = "updateSourceFileDate";


  #### Decode the argument list
  my $biosequence_set_id = $args{'biosequence_set_id'}
   || die "ERROR[$SUB_NAME]: biosequence_set_id not passed";
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";


  #### Check if there's a source_file_date column (some older versions
  #### may not have this)
  print "Looking for source_file_date column\n" if ($VERBOSE);
  my $sql = "SELECT * FROM ${DATABASE}biosequence_set";
  my @rows = $sbeams->selectHashArray($sql);
  return unless exists($rows[0]->{source_file_date});


  #### Get the last modification date from this file
  my @stats = stat($source_file);
  my $mtime = $stats[9];
  my $source_file_date;
  if ($mtime) {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime($mtime);
    $source_file_date = sprintf("%d-%d-%d %d:%d:%d",
      1900+$year,$mon+1,$mday,$hour,$min,$sec);
    print "INFO: Updating source_file_date to '$source_file_date'\n";
  } else {
    $source_file_date = "CURRENT_TIMESTAMP";
    print "WARNING: Unable to determine the source_file_date for ".
     "'$source_file'.\n";
  }


  #### UPDATE the record with the current datetime
  print "Updating source_file_date column\n" if ($VERBOSE);
  my %rowdata = (
    source_file_date => $source_file_date,
  );

  my $result = $sbeams->updateOrInsertRow(
    update => 1,
    table_name => "${DATABASE}biosequence_set",
    rowdata_ref => \%rowdata,
    PK => "biosequence_set_id",
    PK_value => $biosequence_set_id,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
 );



} # end updateSourceFileDate



###############################################################################
# loadBiosequence
###############################################################################
sub loadBiosequence {
  my %args = @_;
  my $SUB_NAME = "loadBiosequence";

  #### Decode the argument list
  my $insert   = $args{'insert'}   || 0;
  my $update   = $args{'update'}   || 0;
  my $PK       = $args{'PK_name'}  || $args{'PK'} || '';
  my $PK_value = $args{'PK_value'} || '';

  my $rowdata_ref = $args{'rowdata_ref'}
  || die "ERROR[$SUB_NAME]: rowdata not passed!";
  my $table_name = $args{'table_name'} 
  || die "ERROR[$SUB_NAME]:table_name not passed!";


  #### Get the file_prefix if it was specified, and otherwise guess
  my $module = $sbeams->getSBEAMS_SUBDIR();

  #### Microarray uses the new schema and this is just a quick hack to get it
  #### working.  This will  need to populate biosequence_external_xref in the
  #### future, using an INSERT, INSERT, UPDATE triplet for new sequences.
  #### FIX ME!!!
  if ($module eq 'Microarray') {
      #print "$rowdata_ref->{dbxref_id}\t";
      delete ($rowdata_ref->{biosequence_accession});
      delete ($rowdata_ref->{dbxref_id});
  }


  #### If the biosequence_name bloats beyond 255, truncate it
  if (length($rowdata_ref->{biosequence_name}) > 255) {
    print "\nWARNING: truncating name for ".
      $rowdata_ref->{biosequence_name}." to 255 characters\n";
    $rowdata_ref->{biosequence_name} = substr($rowdata_ref->{biosequence_name},
      0,255);
  }
  my $biosequence_name = $rowdata_ref->{biosequence_name};

  #### If the biosequence_desc bloats beyond 1024, truncate it
  if (length($rowdata_ref->{biosequence_desc}) > 1024) {
    print "\nWARNING: truncating description for ".
      $rowdata_ref->{biosequence_name}." to 1024 characters\n";
    $rowdata_ref->{biosequence_desc} = substr($rowdata_ref->{biosequence_desc},
      0,1024);
  }


  #### INSERT/UPDATE the row
  my $biosequence_id = $sbeams->insert_update_row(insert=>$insert,
		  update=>$update,
		  table_name=>$table_name,
		  rowdata_ref=>$rowdata_ref,
		  PK=>$PK,
		  PK_value => $PK_value,
		  verbose=>$VERBOSE,
		  testonly=>$TESTONLY,
		  return_PK=>1,
		  );

  #### See if we have TMR data to add
  my $have_tmr_data = 0;
  if (defined($n_transmembrane_regions) && $biosequence_id) {
    if (defined($n_transmembrane_regions->
	      {$rowdata_ref->{biosequence_name}}->{topology})) {
      $have_tmr_data = 1;
    }
  }


  #### If we have TMR data, INSERT or UPDATE extra biosequence properties
  if ($have_tmr_data) {

    #### See if there's already a record there
    my $sql =
      "SELECT biosequence_property_set_id
         FROM ${DATABASE}biosequence_property_set
        WHERE biosequence_id = '$biosequence_id'
      ";
    my @biosequence_property_set_ids = $sbeams->selectOneColumn($sql);

    #### Determine INSERT or UPDATE based on the result
    $insert = 0;
    $update = 0;
    $insert = 1 if (scalar(@biosequence_property_set_ids) eq 0);
    $update = 1 if (scalar(@biosequence_property_set_ids) eq 1);
    if (scalar(@biosequence_property_set_ids) > 1) {
      die("ERROR: Unexpected result from query:\n$sql\n");
    }
    my $biosequence_property_set_id = $biosequence_property_set_ids[0] || 0;


    #### Fill the row data hash with information we have
    my %rowdata;
    $rowdata{biosequence_id} = $biosequence_id;

    $rowdata{n_transmembrane_regions} = $n_transmembrane_regions->
      {$rowdata_ref->{biosequence_name}}->{n_tmm}
      if (defined($n_transmembrane_regions->
        {$rowdata_ref->{biosequence_name}}->{n_tmm}));

    $rowdata{transmembrane_topology} = $n_transmembrane_regions->
      {$rowdata_ref->{biosequence_name}}->{topology}
      if (defined($n_transmembrane_regions->
        {$rowdata_ref->{biosequence_name}}->{topology}));

    $rowdata{transmembrane_class} = $n_transmembrane_regions->
      {$rowdata_ref->{biosequence_name}}->{sec_mem_class}
      if (defined($n_transmembrane_regions->
        {$rowdata_ref->{biosequence_name}}->{sec_mem_class}));

    if (defined($n_transmembrane_regions->
		{$rowdata_ref->{biosequence_name}}->{has_signal_peptide})) {
      $rowdata{has_signal_peptide} = $n_transmembrane_regions->
        {$rowdata_ref->{biosequence_name}}->{has_signal_peptide};
      $rowdata{has_signal_peptide_probability} = $n_transmembrane_regions->
        {$rowdata_ref->{biosequence_name}}->{has_signal_peptide_probability};
      $rowdata{signal_peptide_length} = $n_transmembrane_regions->
        {$rowdata_ref->{biosequence_name}}->{signal_peptide_length};
      $rowdata{signal_peptide_is_cleaved} = $n_transmembrane_regions->
        {$rowdata_ref->{biosequence_name}}->{signal_peptide_is_cleaved};
    }


    #### Insert or update the row
    my $result = $sbeams->insert_update_row(
      insert=>$insert,
      update=>$update,
      table_name=>"${DATABASE}biosequence_property_set",
      rowdata_ref=>\%rowdata,
      PK=>"biosequence_property_set_id",
      PK_value => $biosequence_property_set_id,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

  }



  #### See if we have PFAM data to add
  my $have_pfam_data = 0;
  if (defined($pfam_search_results) && $biosequence_id) {
    if (defined($pfam_search_results->
	      {data}->{$biosequence_name})) {
      $have_pfam_data = 1;
    }
  }


  #### If we have PFAM data, INSERT or UPDATE domain_match
  if ($have_pfam_data) {

    #### Get the domain_match_source_id
    my $domain_match_source_id = $domain_match_sources{'PFAM Search'};

    #### See if there's already a record there
    my $sql =
      "SELECT domain_match_id
         FROM ${DATABASE}domain_match
        WHERE biosequence_id = '$biosequence_id'
          AND domain_match_source_id = '$domain_match_source_id'
      ";
    my @domain_match_ids = $sbeams->selectOneColumn($sql);

    #### If there are any of these, DELETE them
    if (scalar(@domain_match_ids) > 0) {
      $sql =
        "DELETE
           FROM ${DATABASE}domain_match
          WHERE biosequence_id = '$biosequence_id'
            AND domain_match_source_id = '$domain_match_source_id'
        ";
      $sbeams->executeSQL($sql);
    }


    #### Loop over all the entries for this biosequence
    foreach my $match (@{$pfam_search_results->{data}->{$biosequence_name}}) {

      #### Fill the row data hash with information we have
      my %rowdata;
      $rowdata{biosequence_id} = $biosequence_id;

      $rowdata{score} = $match->{score}
        if (defined($match->{score}));

      $rowdata{e_value} = $match->{e_value}
        if (defined($match->{e_value}));

      if (defined($match->{match_name})) {
        $rowdata{match_name} = $match->{match_name};
        $rowdata{match_accession} = $match->{match_name};
      }

      $rowdata{query_start} = $match->{query_start}
        if (defined($match->{query_start}));

      $rowdata{query_end} = $match->{query_end}
        if (defined($match->{query_end}));

      $rowdata{domain_match_type_id} =
        $domain_match_types{'pfam'};

      $rowdata{domain_match_source_id} =
        $domain_match_sources{'PFAM Search'};

      #### Insert or update the row
      $sbeams->insert_update_row(
  	insert=>1,
  	table_name=>"${DATABASE}domain_match",
  	rowdata_ref=>\%rowdata,
  	PK=>"domain_match_id",
  	verbose=>$VERBOSE,
  	testonly=>$TESTONLY,
      );

    }

  }


  #### See if we have Ginzu data to add
  my $have_ginzu_data = 0;
  if (defined($ginzu_search_results) && $biosequence_id) {
    if (defined($ginzu_search_results->
	      {data}->{$biosequence_name})) {
      $have_ginzu_data = 1;
    }

  }


  #### If we have Ginzu data, INSERT or UPDATE domain_match
  if ($have_ginzu_data) {

    #### Get the domain_match_source_id
    my $domain_match_source_id = $domain_match_sources{Ginzu};

    #### See if there's already a record there
    my $sql =
      "SELECT domain_match_id
         FROM ${DATABASE}domain_match
        WHERE biosequence_id = '$biosequence_id'
          AND domain_match_source_id = '$domain_match_source_id'
      ";
    my @domain_match_ids = $sbeams->selectOneColumn($sql);

    #### If there are any of these, DELETE them
    if (scalar(@domain_match_ids) > 0) {
      $sql =
        "DELETE
           FROM ${DATABASE}domain_match
          WHERE biosequence_id = '$biosequence_id'
            AND domain_match_source_id = '$domain_match_source_id'
        ";
      $sbeams->executeSQL($sql);
    }


    #### Loop over all the entries for this biosequence
    foreach my $match (@{$ginzu_search_results->{data}->{$biosequence_name}}) {

      #### Fill the row data hash with information we have
      my %rowdata;
      $rowdata{biosequence_id} = $biosequence_id;

      $rowdata{query_start} = $match->{query_start}
        if (defined($match->{query_start}));

      $rowdata{query_end} = $match->{query_end}
        if (defined($match->{query_end}));

      $rowdata{query_length} = $match->{query_length}
        if (defined($match->{query_length}));

      $rowdata{match_start} = $match->{match_start}
        if (defined($match->{match_start}));

      $rowdata{match_end} = $match->{match_end}
        if (defined($match->{match_end}));

      $rowdata{match_name} = $match->{match_name}
        if (defined($match->{match_name}));

      $rowdata{domain_match_index} = $match->{match_index}
        if (defined($match->{match_index}));

      $rowdata{z_score} = $match->{z_score}
        if (defined($match->{z_score}));

      $rowdata{e_value} = 10**(-1*$match->{z_score})
        if (defined($match->{z_score}));

      if (defined($match->{match_source})) {
        if (defined($domain_match_types{$match->{match_source}})) {
          $rowdata{domain_match_type_id} =
            $domain_match_types{$match->{match_source}};
          $rowdata{match_accession} = $match->{match_name}
            if ($match->{match_source} eq 'pfam');
          $rowdata{match_accession} = substr($match->{match_name},0,4)
            if ($match->{match_source} =~ /pdbblast|orfeus/);

        } else {
          print "WARNING: Unable to transform match source '",
            $match->{match_source},"'\n";
        }
      } else {
        print "WARNING: No match_source for '$biosequence_name'\n";
      }

      $rowdata{domain_match_source_id} =
        $domain_match_sources{'Ginzu'};

      #### For PDB hits that are 6 chars long, chop off last underscore
      if (defined($match->{match_name}) && defined($match->{match_source}) &&
	  $match->{match_source} eq 'pdbblast') {
	if (length($match->{match_name}) == 6) {
	  $rowdata{match_name} = substr($match->{match_name},0,5);
	}
      }


      #### Insert or update the row
      my $result = $sbeams->insert_update_row(
  	insert=>1,
  	table_name=>"${DATABASE}domain_match",
  	rowdata_ref=>\%rowdata,
  	PK=>"domain_match_id",
  	verbose=>$VERBOSE,
  	testonly=>$TESTONLY,
      );

    }

  }


  #### Hack for yucky halo mamSum
  my $adj_biosequence_name = $biosequence_name;
  chop($adj_biosequence_name);


  #### See if we have mamSum data to add
  my $have_mamSum_data = 0;
  if (defined($mamSum_search_results) && $biosequence_id) {
    if (defined($mamSum_search_results->{$adj_biosequence_name})) {
      $have_mamSum_data = 1;
    }
  }


  #### If we have mamSum data, INSERT or UPDATE domain_match
  if ($have_mamSum_data) {

    #### Get the domain_match_source_id
    my $domain_match_source_id = $domain_match_sources{mamSum};

    #### See if there's already a record there
    my $sql =
      "SELECT domain_match_id
         FROM ${DATABASE}domain_match
        WHERE biosequence_id = '$biosequence_id'
          AND domain_match_source_id = '$domain_match_source_id'
      ";
    my @domain_match_ids = $sbeams->selectOneColumn($sql);

    #### If there are any of these, DELETE them
    if (scalar(@domain_match_ids) > 0) {
      $sql =
        "DELETE
           FROM ${DATABASE}domain_match
          WHERE biosequence_id = '$biosequence_id'
            AND domain_match_source_id = '$domain_match_source_id'
        ";
      $sbeams->executeSQL($sql);
    }


    #### Loop over all the domain for this biosequence
    my $domains = $mamSum_search_results->{$adj_biosequence_name};
    foreach my $domain_tag (keys %{$domains}) {

      #### Loop over all the domain matches for this biosequence
      foreach my $match (@{$domains->{$domain_tag}->{clusters}}) {

  	#### Fill the row data hash with information we have
  	my %rowdata;
  	$rowdata{biosequence_id} = $biosequence_id;

        if ($domain_tag =~ /\d/) {
          $rowdata{domain_match_index} = $domain_tag;
        }

	$rowdata{overall_probability} = $domains->{$domain_tag}->
            {cluster_probability}
  	  if (defined($domains->{$domain_tag}->{cluster_probability}));

        if (defined($match->{cluster_name})) {
	  $rowdata{cluster_name} = $match->{cluster_name};
	  if ($match->{cluster_name} eq $domains->{$domain_tag}->{best_cluster}) {
	    $rowdata{best_match_flag} = 'Y';
          }
        }

	$rowdata{query_start} = $match->{query_start}
  	  if (defined($match->{query_start}));

  	$rowdata{query_length} = $match->{query_length}
  	  if (defined($match->{query_length}));

  	$rowdata{match_length} = $match->{match_length}
  	  if (defined($match->{match_length}));

	if (defined($match->{match_name})) {
    	  $rowdata{match_name} = $match->{match_name};
    	  $rowdata{match_accession} = substr($match->{match_name},0,4);
	}

	$rowdata{domain_match_type_id} = $domain_match_types{PDB};

  	$rowdata{z_score} = $match->{z_score}
  	  if (defined($match->{z_score}));

  	$rowdata{probability} = $match->{probability}
  	  if (defined($match->{probability}));

  	$rowdata{cluster_name} = $match->{cluster_name}
  	  if (defined($match->{cluster_name}));

  	if (defined($match->{second_match_name})) {
    	  $rowdata{second_match_name} = $match->{second_match_name};
    	  $rowdata{second_match_accession} = $match->{second_match_name};
    	  $rowdata{second_match_accession} =~ s/\./\//g;
	}


  	$rowdata{match_annotation} = $match->{match_annotation}
  	  if (defined($match->{match_annotation}));

  	$rowdata{e_value} = 10**(-1*$match->{z_score})
  	  if (defined($match->{z_score}));

	$rowdata{domain_match_source_id} =
  	  $domain_match_sources{mamSum};


  	#### Insert or update the row
  	my $result = $sbeams->insert_update_row(
  	  insert=>1,
  	  table_name=>"${DATABASE}domain_match",
  	  rowdata_ref=>\%rowdata,
  	  PK=>"domain_match_id",
  	  verbose=>$VERBOSE,
  	  testonly=>$TESTONLY,
  	);

      } # end foreach match

    } # end foreach domain

  } # if have mamSum



  #### See if we have InterProScan data to add
  my $have_InterProScan_data = 0;
  if (defined($InterProScan_search_results) && $biosequence_id) {
    if (defined($InterProScan_search_results->{$biosequence_name})) {
      $have_InterProScan_data = 1;
    }
  }


  #### If we have InterProScan data, INSERT or UPDATE domain_match
  if ($have_InterProScan_data) {

    #### Get the domain_match_source_id
    my $domain_match_source_id = $domain_match_sources{'InterProScan'} ||
      die("Unable to find domain match source InterProScan in ".
	  Data::Dumper->Dump([\%domain_match_sources]));

    #### See if there's already a record there
    my $sql =
      "SELECT domain_match_id
         FROM ${DATABASE}domain_match
        WHERE biosequence_id = '$biosequence_id'
          AND domain_match_source_id = '$domain_match_source_id'
      ";
    my @domain_match_ids = $sbeams->selectOneColumn($sql);

    #### If there are any of these, DELETE them
    if (scalar(@domain_match_ids) > 0) {
      $sql =
        "DELETE
           FROM ${DATABASE}domain_match
          WHERE biosequence_id = '$biosequence_id'
            AND domain_match_source_id = '$domain_match_source_id'
        ";
      $sbeams->executeSQL($sql);
    }



    #### Loop over all the domain matches for this biosequence
    my @matches = @{$InterProScan_search_results->{$biosequence_name}};
    foreach my $match (@matches) {

	#### Fill the row data hash with information we have
	my %rowdata;
	$rowdata{biosequence_id} = $biosequence_id;

        $rowdata{domain_match_source_id} = $domain_match_source_id;

	$rowdata{match_name} = $match->{match_name}
	  if (defined($match->{match_name}));
	$rowdata{match_accession} = $match->{match_accession}
	  if (defined($match->{match_accession}));
	$rowdata{domain_match_type_id} = $match->{match_type_id}
	  if (defined($match->{match_type_id}));

	$rowdata{second_match_name} = $match->{second_match_name}
	  if (defined($match->{second_match_name}));
	$rowdata{second_match_accession} = $match->{second_match_accession}
	  if (defined($match->{second_match_accession}));
	$rowdata{second_match_type_id} = $match->{second_match_type_id}
	  if (defined($match->{second_match_type_id}));

        $rowdata{e_value} = $match->{evalue}
	  if (defined($match->{evalue}));


        $rowdata{query_start} = $match->{query_start}
	  if (defined($match->{query_start}));
        $rowdata{query_end} = $match->{query_end}
	  if (defined($match->{query_end}));
	$rowdata{query_length} = $match->{query_length}
	  if (defined($match->{query_length}));

	$rowdata{match_annotation} = $match->{match_annotation}
	  if (defined($match->{match_annotation}));

	#### Insert or update the row
	my $result = $sbeams->insert_update_row(
	  insert=>1,
	  table_name=>"${DATABASE}domain_match",
	  rowdata_ref=>\%rowdata,
	  PK=>"domain_match_id",
	  verbose=>$VERBOSE,
	  testonly=>$TESTONLY,
	);

    } # end foreach match

  } # if have InterProScan


  return;
}




###############################################################################
# additionalParsing: fill in the gene_name and accession fields based on
#                    data in the id and description, depending on particular
#                    set being loaded.
###############################################################################
sub specialParsing {
  my %args = @_;
  my $SUB_NAME = "specialParsing";


  #### Decode the argument list
  my $biosequence_set_name = $args{'biosequence_set_name'}
   || die "ERROR[$SUB_NAME]: biosequence_set_name not passed";
  my $rowdata_ref = $args{'rowdata_ref'}
   || die "ERROR[$SUB_NAME]: rowdata_ref not passed";


  #### Define a few variables
  my ($n_other_names,@other_names);


  #### Encoding popular among a bunch of databases
  #### Can be overridden later on a case-by-case basis
  if ($rowdata_ref->{biosequence_name} =~ /^SW.{0,1}\:(.+)$/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '1';
  }

  if ($rowdata_ref->{biosequence_name} =~ /^PIR.\:(.+)$/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '6';
  }

  if ($rowdata_ref->{biosequence_name} =~ /^GP.{0,1}\:(.+)_\d+$/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '8';
  }


  #### Conversion rules for the ENSEMBLE Protein database
  if ($rowdata_ref->{biosequence_name} =~ /^Translation:(ENSP\d+)$/ ) {
     $rowdata_ref->{biosequence_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     if ($rowdata_ref->{biosequence_desc} =~ /(ENSG\d+)/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
     }
     $rowdata_ref->{dbxref_id} = '20';
  }


  #### Conversion rules for the IPI database
  if ($rowdata_ref->{biosequence_name} =~ /^IPI:(IPI[\d\.]+)$/ ) {
     $rowdata_ref->{biosequence_accession} = $1;
     if ($rowdata_ref->{biosequence_name} =~ /^IPI:(IPI[\d]+)\.\d+$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
     }
     $rowdata_ref->{dbxref_id} = '9';
  }


  #### Conversion rules for the new IPI database
  if ($rowdata_ref->{biosequence_name} =~ /^(IPI[\d\.]+)$/ ) {
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{dbxref_id} = '9';
  }

  #### Conversion rules for the new IPI database 2 (dreiss)
  if ($rowdata_ref->{biosequence_name} =~ /^IPI:(IPI[\d\.]+)\|/ ) {
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{dbxref_id} = '9';
  }


  #### Conversion rules for some generic GenBank IDs
  if ($rowdata_ref->{biosequence_name} =~ /gb\|([A-Z\d\.]+)\|/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '7';
  }


  #### Conversion rules for some generic GenBank IDs
  if ($rowdata_ref->{biosequence_name} =~ /gi\|(\d+)\|/ ) {
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '12';
  }

  #### Special Conversion rules for yeast orf names from GB (dreiss)
  if ($rowdata_ref->{biosequence_desc} =~ /\s(\S+)p\s\[Saccharomyces cerevisiae/ ) {
      $rowdata_ref->{biosequence_gene_name} = $1;
  }


  #### Special conversion rules for Halobacterium
  #### >gabT   , from VNG6210g 
  if ($biosequence_set_name eq "Halo Biosequences") {
      if ($rowdata_ref->{biosequence_desc} =~ /from (\S+)/) {
	  my $temp_gene_name = $1;
	  $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
	  delete($rowdata_ref->{biosequence_name}); #delete old name
	  $rowdata_ref->{biosequence_name} = $temp_gene_name; #add new name
      }

  }


  #### Special conversion rules for Halobacterium
  #### >VNG1667G_cdc48c CDCH_HALN1 (Q9HPF0) CdcH protein
  if ($biosequence_set_name eq "halo092602_pA") {
    $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
    if ($rowdata_ref->{biosequence_desc} =~ /([\w_]+_HALN1)/) {
      $rowdata_ref->{biosequence_gene_name} = $1;
    }
    $rowdata_ref->{dbxref_id} = '17';
  }


  #### Special conversion rules for Drosophila genome R2, e.g.:
  #### >Scr|FBgn0003339|CT1096|FBan0001030 "transcription factor" mol_weight=44264  located on: 3R 84A6-84B1; 
  if ($biosequence_set_name eq "Drosophila aa_gadfly Protein Database R2" ||
      $biosequence_set_name eq "Drosophila na_gadfly Nucleotide Database R2") {
    @other_names = split('\|',$rowdata_ref->{biosequence_name});
    $n_other_names = scalar(@other_names);
    if ($n_other_names > 1) {
       $rowdata_ref->{biosequence_gene_name} = $other_names[0];
       $rowdata_ref->{biosequence_accession} = $other_names[1];
       $rowdata_ref->{dbxref_id} = '2';
       $rowdata_ref->{biosequence_desc} =~ s/^\s+//;
    }
  }


  #### Special conversion rules for Drosophila genome R3, e.g.:
  #### >Scr|FBgn0003339|CT1096|FBan0001030 "transcription factor" mol_weight=44264  located on: 3R 84A6-84B1; 
  if ($biosequence_set_name eq "Drosophila aa_gadfly Protein Database R3 Non-redundant" ||
      $biosequence_set_name eq "Drosophila aa_gadfly Protein Database R3 Original" ||
      $biosequence_set_name eq "Drosophila na_gadfly Nucleotide Database R3") {

    if ($rowdata_ref->{biosequence_desc} =~
                      /gene_info:\[.*gene symbol:(\S+) .*?(FBgn\d+) /) {
       #print "******\ndesc: $rowdata_ref->{biosequence_desc}\n1: $1\n2: $2\n*****\n";
       $rowdata_ref->{biosequence_gene_name} = $1;
       $rowdata_ref->{biosequence_accession} = $2;
       $rowdata_ref->{dbxref_id} = '2';
    } else {
       $rowdata_ref->{biosequence_gene_name} = undef;
       $rowdata_ref->{biosequence_accession} = undef;
       $rowdata_ref->{dbxref_id} = undef;
    }
  }


  #### Special conversion rules for Drosophila genome R3 genome, e.g.:
  if ($biosequence_set_name eq "Drosophila genome_gadfly Nucleotide Database R3") {
    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
  }


  #### Special conversion rules for Human Contig, e.g.:
  #### >Contig109 fasta_990917.300k.no_chimeric_4.Contig38095 1 767 REPEAT: 15 318 REPEAT: 320 531 REPEAT: 664 765


  #### Special conversion rules for NRP, e.g.:
  #### >SWN:AAC2_MOUSE Q9ji91 mus musculus (mouse). alpha-actinin 2 (alpha actinin skeletal muscle isoform 2) (f-actin cross linking protein). 8/2001


  #### Special conversion rules for Human NCI, e.g.:
  #### >SWN:3BP1_HUMAN Q9y3l3 homo sapiens (human). sh3-domain binding protein 1 (3bp-1). 3/2002 [MASS=66765]
  #### >SW:AKA7_HUMAN O43687 homo sapiens (human). a-kinase anchor protein 7 (a-kinase anchor protein 9 kda). 5/2000 [MASS=8838]
  #### >PIR1:SNHUC3 multicatalytic endopeptidase complex (EC 3.4.99.46) chain C3 - human [MASS=25899]
  #### >PIR2:S17526 aconitate hydratase (EC 4.2.1.3) - human (fragments) [MASS=6931]
  #### >PIR4:T01781 probable pol protein pseudogene - human (fragment) [MASS=13740]
  #### >GPN:AF345332_1 Homo sapiens SWAN mRNA, complete cds; SH3/WW domain anchor protein in the nucleus. [MASS=97395]
  #### >GP:AF119839_1 Homo sapiens PRO0889 mRNA, complete cds; predicted protein of HQ0889. [MASS=6643]
  #### >GP:BC001812_1 Homo sapiens, clone IMAGE:2959521, mRNA, partial cds. [MASS=5769]
  #### >3D:2clrA HUMAN CLASS I HISTOCOMPATIBILITY ANTIGEN (HLA-A 0201) COMPLEXED WITH A DECAMERIC [MASS=31808]
  #### >TFD:TFDP00561 : HOX 2.2 ((human)) polypeptide [MASS=25574]
  if ($biosequence_set_name eq "Human NCI Database") {
    #### Nothing special, uses generic SW, PIR, etc. encodings above
  }


  #### Special conversion rules for Yeast NCI from regis, e.g.:
  #### SW:ACEA_YEAST P28240 saccharomyces cerevisiae (baker's yeast). isocitrate lyase (ec 4.1.3.1) (isocitrase) (isocitratase) (icl). 2/1996 [MASS=62409]

  if ($biosequence_set_name eq "Yeast NCI Database") {
    #### Nothing special, uses generic SW, PIR, etc. encodings above
  }

  if ($biosequence_set_name eq "ISB Yeast Database") {
      $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
  }

  #### Special conversion rules for Yeast genome, e.g.:
  #### >ORFN:YAL014C YAL014C, Chr I from 128400-129017, reverse complement
  if ($biosequence_set_name eq "yeast_orf_coding" ||
      $biosequence_set_name eq "Yeast ORFs Database" ||
      $biosequence_set_name eq "Yeast ORFs Common Name Database" ||
      $biosequence_set_name eq "Yeast ORF Proteins" ||
      $biosequence_set_name eq "Yeast ORFs Database 200210") {
    if ($rowdata_ref->{biosequence_desc} =~ /([\w\-\:]+)\s([\w\-\:]+), .+/ ) {
      if ($biosequence_set_name eq "Yeast ORFs Common Name Database" ||
          $biosequence_set_name eq "Yeast ORFs Database 200210" ) {
        $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
        #$rowdata_ref->{biosequence_accession} = $1;
        $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
      } else {
        $rowdata_ref->{biosequence_gene_name} = $1;
        #$rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
        $rowdata_ref->{biosequence_accession} = $1;
      }
      $rowdata_ref->{dbxref_id} = '7';
    }
  }

  #### Conversion Rules for SGD:
  #### >ORFN:YAL001C TFC3 SGDID:S0000001, Chr I from 147591-147660,147751-151163, reverse complement
  if ($biosequence_set_name eq "SGD Yeast ORF Database"){
    if ($rowdata_ref->{biosequence_desc} =~ /([\w-]+)\sSGDID\:([\w-]+), .+/ ) {
	$rowdata_ref->{biosequence_gene_name} = $1;
	$rowdata_ref->{biosequence_accession} = $2;
	$rowdata_ref->{dbxref_id} = '7';
    }
  }

  #### Special conversion rules for DQA, DBQ, DRB exons, e.g.:
  #### >DQB1_0612_exon1
  if ($biosequence_set_name =~ /Allelic exons/) {
    if ($rowdata_ref->{biosequence_name} =~ /^([A-Za-z0-9]+)_/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
    }
    $rowdata_ref->{biosequence_desc} = $rowdata_ref->{biosequence_name};
  }

  #### Special conversion rules for Halobacterium genome, e.g.:
  #### >gene-275_2467-rpl31e
  if ($biosequence_set_name eq "halobacterium_orf_coding") {
    if ($rowdata_ref->{biosequence_name} =~ /-(\w+)$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
   }
  }

  #### Special conversion rules for Human FASTA file, e.g.:
  ####>ACC:AA406372|zv10c10.s1 Soares_NhHMPu_S1 Homo sapiens cDNA clone IMAGE:753234 3' similar to gb:X59739_rna1 ZINC FINGER X-CHROMOSOMAL PROTEIN (HUMAN );, mRNA sequence.
  if ($biosequence_set_name eq "Human BioSequence Database") {
    if ($rowdata_ref->{biosequence_name} =~ /^ACC\:([\w-]+)\|/) {
	$rowdata_ref->{biosequence_gene_name} = $1;
	$rowdata_ref->{biosequence_accession} = $1;
	$rowdata_ref->{dbxref_id} = '8';
    }
  }

  #### Special conversion rules for Human genome, e.g.:
  #### >gnl|UG|Hs#S35 Human mRNA for ferrochelatase (EC 4.99.1.1) /cds=(29,1300) /gb=D00726 /gi=219655 /ug=Hs.26 /len=2443
  if ($biosequence_set_name eq "Human unique sequences") {
    if ($rowdata_ref->{biosequence_desc} =~ /\/gi=(\d+) / ) {
       $rowdata_ref->{biosequence_accession} = $1;
    }
    if ($rowdata_ref->{biosequence_name} =~ /\|(Hs\S+)$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
    }
  }


  #### Conversion Rules for ATH1.pep (TAIR):
  #### >At1g79800.1 hypothetical protein   /  contains similarity to phytocyanin/early nodulin-like protein GI:4559346 from [Arabidopsis thaliana]
  if ($biosequence_set_name eq "Arabidopsis Protein Database") {
    $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{dbxref_id} = '10';
  }


  #### Conversion Rules for wormpep92 (C Elegans):
  #### >B0285.7 CE00646   Aminopeptidase status:Partially_confirmed SW:P46557 protein_id:CAA84298.1
  if ($biosequence_set_name eq "C Elegans Protein Database") {
    $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
    if ($rowdata_ref->{biosequence_desc} =~ /^(\S+)\s+(.+)/ ) {
      $rowdata_ref->{biosequence_accession} = $1;
      $rowdata_ref->{dbxref_id} = '11';
    }
  }


  #### If there's favored codon frequency lookup information, set it
  if (defined($fav_codon_frequency)) {
    if ($fav_codon_frequency->{$rowdata_ref->{biosequence_name}}) {
      $rowdata_ref->{fav_codon_frequency} =
        $fav_codon_frequency->{$rowdata_ref->{biosequence_name}};
    }
  }


#  #### If there's n_transmembrane_regions lookup information, set it
#  if (defined($n_transmembrane_regions)) {
#    if ($n_transmembrane_regions->{$rowdata_ref->{biosequence_name}}) {
#      $rowdata_ref->{n_transmembrane_regions} =
#	 $n_transmembrane_regions->{$rowdata_ref->{biosequence_name}}->
#	   {n_tmm};
#    }
#  }
#
#
#  #### If the calc_n_transmembrane_regions flag is set, do the calculation
#  if (defined($OPTIONS{"calc_n_transmembrane_regions"}) &&
#      defined($rowdata_ref->{biosequence_seq}) &&
#      $rowdata_ref->{biosequence_seq} ) {
#    $rowdata_ref->{n_transmembrane_regions} = 
#      SBEAMS::Proteomics::Utilities::calcNTransmembraneRegions(
#	 peptide=>$rowdata_ref->{biosequence_seq},
#	 calc_method=>'NewMethod');
#  }


}


###############################################################################
# get_biosequence_id: Obtain the biosequence_id from the available parameters
###############################################################################
sub get_biosequence_id {
  my %args = @_;
  my $SUB_NAME = "get_biosequence_id";


  #### Decode the argument list
  my $biosequence_set_id = $args{'biosequence_set_id'}
   || die "ERROR[$SUB_NAME]: biosequence_set_id not passed";
  my $biosequence_name = $args{'biosequence_name'}
   || die "ERROR[$SUB_NAME]: biosequence_name not passed";
  $biosequence_name =~ s/\'/\'\'/g;


  my $sql = "SELECT biosequence_id" .
           "  FROM ${DATABASE}biosequence".
           " WHERE biosequence_set_id = '$biosequence_set_id'".
           "   AND biosequence_name = '$biosequence_name'";
  #print "SQL: $sql\n";
  my @biosequence_ids = $sbeams->selectOneColumn($sql);

  my $count = @biosequence_ids;
  if ($count > 1) {
    die "ERROR[$SUB_NAME]: multiple biosequence_id's returned from by\n$sql\n".
      "This should be impossible!";
  }

  return $biosequence_ids[0];

}


###############################################################################
# readFavCodonFrequencyFile
###############################################################################
sub readFavCodonFrequencyFile {
  my %args = @_;
  my $SUB_NAME = "readFavCodonFrequencyFile";


  #### Decode the argument list
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";
  # Don't bother getting the output data struct since it's a global


  unless ( -f $source_file ) {
    $fav_codon_frequency->{return_status} = 'FAIL';
    die("Unable to find favored codon frequency file '$source_file'");
  }


  #### Define the column number from which data are loaded
  my $fcf_column_index;
  my $bs_name_column_index;

  if ($source_file =~ /bias_gadfly.dros.RELASE2/) {
    $bs_name_column_index = 0;
    $fcf_column_index = 2;
  } elsif ($source_file =~ /protein_properties.tab/) {
    $bs_name_column_index = 0;
    $fcf_column_index = 29;
  } elsif ($source_file =~ /bias.txt/) {
    $bs_name_column_index = 3;
    $fcf_column_index = 2;
  } else {
   die("Sorry, unknown filetype for favored codon frequency file");
  }

  open(CODONFILE,"$source_file") ||
    die("Unable to favored codon frequency file '$source_file'");


  #### Read the header column
  my $line;
  $line = <CODONFILE>;
  my $tmp;
  my $biosequence_name;
  my @columns;
  my @words;


  #### Read in all the data putting it into the hash
  print "Reading favored codon frequency file...\n";
  while ($line = <CODONFILE>) {
    @columns = split("\t",$line);
    $biosequence_name = $columns[$bs_name_column_index];
    $biosequence_name =~ s/[\r\n]//g;
    $biosequence_name =~ s/^\s+//;
    @words = split(/\s/,$biosequence_name);
    $biosequence_name = $words[0];
    my $fcf = $columns[$fcf_column_index];
    $fcf =~ s/\s//g;

    $fav_codon_frequency->{$biosequence_name} = $fcf;
  }

  close(CODONFILE);

  $fav_codon_frequency->{return_status} = 'SUCCESS';
  return;

}


###############################################################################
# readNTransmembraneRegionsFile
###############################################################################
sub readNTransmembraneRegionsFile {
  my %args = @_;
  my $SUB_NAME = "readNTransmembraneRegionsFile";


  #### Decode the argument list
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";
  # Don't bother getting the output data struct since it's a global


  unless ( -f $source_file ) {
    $n_transmembrane_regions->{return_status} = 'FAIL';
    die("Unable to find n_transmembrane_regions file '$source_file'");
  }


  open(TMRFILE,"$source_file") ||
    die("Unable to n_transmembrane_regions file '$source_file'");


  #### Define some variables
  my $line;
  my $tmp;
  my $biosequence_name;
  my @columns;
  my @words;


  #### Skip the header
  print "Reading n_transmembrane_regions file...\n";
  print "  Parsing header...\n";
  my $first_line_flag = 1;
  while ($line = <TMRFILE>) {
    if ($first_line_flag && $line !~ /^\#/) {
      print "  Ooops. No header! That's okay.\n";
      close(TMRFILE);
      open(TMRFILE,"$source_file");
      last;
    }
    last if ($line =~ /^\#\# name/);
    $first_line_flag = 0;
  }

  unless (defined($line)) {
    print "ERROR Reading TM file: No end of header!";
    return;
  }



  #### Read in all the data putting it into the hash
  print "  Parsing data...\n";
  while ($line = <TMRFILE>) {
    next if ($line =~ /^\#/);
    $line =~ s/[\r\n]//g;
    @columns = split("\t",$line);
    $biosequence_name = $columns[0];
    my %properties;

    #### Extract the number of transmembrane regions
    if ($line =~/tm: (\d+)/) {
      $properties{n_tmm} = $1;
    }
    #### Extract the protein class
    if ($line =~/sec\/mem-class: (.+?)\s/) {
      $properties{sec_mem_class} = $1;
    }
    #### Extract the topology string
    if ($columns[5]) {
      $properties{topology} = $columns[5];
    }

    #### Extract the signal peptide information
    if ($line =~ /sigP:/) {
      if ($line =~ /sigP:\s*(\d+)\s([YN])\s([\d\.]+)\s([YN])/) {
	$properties{signal_peptide_length} = $1;
	$properties{signal_peptide_is_cleaved} = $2;
	$properties{has_signal_peptide_probability} = $3;
	$properties{has_signal_peptide} = $4;
      } else {
	print "ERROR: Unable to parse signal pepetide data ".
	  $columns[3]."\n";
      }
    }


    #### If we're also currently have a rosetta lookup, then try to do
    #### a rosetta name lookup
    if (defined($rosetta_lookup) &&
        defined($rosetta_lookup->{$biosequence_name})) {
      $biosequence_name = $rosetta_lookup->{$biosequence_name};
    }

    #print "  $biosequence_name has $properties{n_tmm} TMRs\n";
    $n_transmembrane_regions->{$biosequence_name} = \%properties;
  }

  close(TMRFILE);

  $n_transmembrane_regions->{return_status} = 'SUCCESS';
  return;

}



###############################################################################
# readRosettaLookupFile
###############################################################################
sub readRosettaLookupFile {
  my %args = @_;
  my $SUB_NAME = "readRosettaLookupFile";


  #### Decode the argument list
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";
  # Don't bother getting the output data struct since it's a global


  unless ( -f $source_file ) {
    $rosetta_lookup->{return_status} = 'FAIL';
    die("Unable to find Rosetta Lookup file '$source_file'");
  }


  open(LOOKUPFILE,"$source_file") ||
    die("Unable to open Rosetta Lookup file '$source_file'");


  print "Reading lookup file file...\n";

  #### Define some variables
  my $line;

  #### Read the contents of the file into a hash
  while ($line = <LOOKUPFILE>) {
    $line =~ s/[\r\n]//g;
    my @columns = split("\t",$line);
    #$rosetta_lookup->{$columns[0]} = $columns[1];
    $rosetta_lookup->{$columns[1]} = $columns[0];
    #print "  '$columns[1]' == '$columns[0]'\n";
  }

  close(LOOKUPFILE);
  return 1;

} # end readRosettaLookupFile



###############################################################################
# readPFAMSearchSummaryFile
###############################################################################
sub readPFAMSearchSummaryFile {
  my %args = @_;
  my $SUB_NAME = "readPFAMSearchSummaryFile";


  #### Decode the argument list
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";
  # Don't bother getting the output data struct since it's a global


  unless ( -f $source_file ) {
    $pfam_search_results->{return_status} = 'FAIL';
    die("Unable to find PFAM Search Results file '$source_file'");
  }


  open(PFAMFILE,"$source_file") ||
    die("Unable to open PFAM Search Results file '$source_file'");


  #### Define some variables
  my $line;
  my $tmp;
  my ($rosetta_name,$biosequence_name);
  my @columns;
  my @words;


  #### Skip the header
  print "Reading pfam_search_results file...\n";
  print "  No header...\n";

  #### Read in all the data putting it into the hash
  print "  Parsing data...\n";
  while ($line = <PFAMFILE>) {
    next if ($line =~ /^\#/);
    $line =~ s/[\r\n]//g;
    @columns = split(/\s+/,$line);
    shift(@columns);
    $rosetta_name = $columns[0];
    $biosequence_name = $columns[1];
    my %properties;
    if ($columns[2]) {
      $properties{score} = $columns[2];
    }
    if ($columns[3]) {
      $properties{e_value} = $columns[3];
    }
    if ($columns[4]) {
      $properties{match_name} = $columns[4];
    }
    if ($columns[5]) {
      $properties{query_start} = $columns[5];
    }
    if ($columns[6]) {
      $properties{query_end} = $columns[6];
    }

    #print "  $biosequence_name has match $properties{match_name}\n";

    #### If this is a new biosequence, create an empty array for it
    unless (defined($pfam_search_results->{data}->{$biosequence_name})) {
      my @tmp = ();
      $pfam_search_results->{data}->{$biosequence_name} = \@tmp;
    }

    #### Store this domain in the data hash
    push(@{$pfam_search_results->{data}->{$biosequence_name}},\%properties);


    #### Check the lookup
    if (defined($rosetta_lookup) && 0) {
      my $tmp = $rosetta_lookup->{$rosetta_name};
		  $tmp = '<undef>' unless defined($tmp);
      unless ($tmp eq $biosequence_name) {
        print "ERROR: Rosetta name verification failed! ",
          "'$biosequence_name' != '$tmp'\n";
      }
    }
  }

  close(PFAMFILE);

  $pfam_search_results->{return_status} = 'SUCCESS';
  return;

} # end readPFAMSearchSummaryFile



###############################################################################
# readGinzuFiles
###############################################################################
sub readGinzuFiles {
  my %args = @_;
  my $SUB_NAME = "readGinzuFiles";


  #### Decode the argument list
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_dir not passed";
  # Don't bother getting the output data struct since it's a global


  unless ( -d $source_dir ) {
    $pfam_search_results->{return_status} = 'FAIL';
    die("Unable to find directory '$source_dir'");
  }


  #### Get all the files in the directory
  my @files = getDirListing($source_dir);

  #### Loop over all files, ingesting the contents
  foreach my $file (@files) {

    if ($file =~ /(.+)\.domains/) {

      my $biosequence_name = $1;

      #### If we're also currently have a rosetta lookup, then try to do
      #### a rosetta name lookup
      if (defined($rosetta_lookup) &&
  	  defined($rosetta_lookup->{$biosequence_name})) {
  	$biosequence_name = $rosetta_lookup->{$biosequence_name};
      }

      my $domain_search = readDomainsFile(
        source_file => "$source_dir/$file",
      );

      #### Put part of the result into the global
      $ginzu_search_results->{data}->{$biosequence_name} =
        $domain_search->{matches};

    } else {
      print "WARNING: File '$file' not recognized as a Ginzu file!\n";
    }

  }


  $ginzu_search_results->{return_status} = 'SUCCESS';

  return;

} # end readGinzuFiles



###############################################################################
# getDirectoryListing
###############################################################################
sub getDirListing {
  my $dir = shift;
  my @files;

  opendir(DIR, $dir)
    || die "[${PROG_NAME}:getDirListing] Cannot open $dir: $!";
  @files = grep (!/(^\.$)|(^\.\.$)/, readdir(DIR));
  closedir(DIR);

  return sort(@files);
}



###############################################################################
# readDomainsFile
###############################################################################
sub readDomainsFile {
  #my $self = shift;
  my %args = @_;


  #### Decode the argument list
  my $source_file = $args{'source_file'} ||
    die ("ERROR: Must supply source_file");
  my $verbose = $args{'verbose'} || '';

  #### Define some variables
  my ($line);

  #### Define a hash to hold the contents of the file
  my %data;
  $data{SUCCESS} = 0;


  #### Set the rosetta_name
  if ($source_file =~ /^(.+)\.domains$/) {
    $data{rosetta_name} = $1;
  } else {
    print "ERROR: Unable to parse the rosetta_name from file name ".
    "'$source_file'.  Perhaps it has the wrong extension\n";
    return \%data;
  }


  #### Open the specified file
  unless ( open(INFILE, "$source_file") ) {
    die("Cannot open input file $source_file\n");
  }


  #### Verify the header
  $line = <INFILE>;
  $line =~ s/[\r\n]//g;
  unless ($line =~ /CHILI-iBALL ROBETTA DOMAIN PARSER v(.+)/) {
    print "ERROR: File '$source_file' does not begin as expected\n";
    return \%data;
  }
  $data{program_version} = $1;
  $line = <INFILE>;
  $line =~ s/[\r\n]//g;


  #### Read the preamble query/coverage information
  while ($line !~ /^COVERAGE /) {
    if ($line =~ /^(\w+):\s*([\w\.]+)/) {
      my $key = $1;
      my $sequence = $2;
      if ($key eq 'sspred' || $key eq 'query' || $key eq 'coverage') {
        $data{$key} = $sequence;
      } else {
        print "ERROR: Unrecognized header item '$key' while ".
          "reading '$source_file'\n";
        return \%data;
      }
    }
    $line = <INFILE>;
    $line =~ s/[\r\n]//g;
  }


  #### Read in all the domain matches
  my @matches = ();
  my $match_index = 0;
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    last if ($line =~ /^\s*$/);

    #### Split the line into columns and insist we get 8
    my @columns = split(/\s+/,$line);
    shift(@columns);
    unless (scalar(@columns) == 8) {
      print "ERROR: Error parsing line '$line' of '$source_file'.  ".
        "Expected 8 columns of information but got ".scalar(@columns)."\n";
      return \%data;
    }

    #### Create a temporary hash and fill it with these data
    my %parameters;
    $parameters{'full_line'} = $line;
    $parameters{'query_start'} = $columns[0];
    $parameters{'query_end'} = $columns[1];
    $parameters{'query_length'} = $columns[2];
    $parameters{'match_start'} = $columns[3];
    $parameters{'match_end'} = $columns[4];
    $parameters{'match_name'} = $columns[5];
    $parameters{'z_score'} = $columns[6];
    $parameters{'match_source'} = $columns[7];
    $parameters{'match_index'} = $match_index;

    #### Put the hash on the list
    push(@matches,\%parameters);
    $match_index++;

  }

  $data{matches} = \@matches;


  #### At this point, skip to the CUTS section and parse that
  #### We're not bothering yet because we're not using it


  #### Close the input file
  close(INFILE);


  #### Set SUCCESS flag and return
  $data{SUCCESS} = 1;
  return \%data;

} # end readDomainsFile



###############################################################################
# readMamSumFile
###############################################################################
sub readMamSumFile {
  #my $self = shift || die("ERROR: Parameter self not passed!");
  my %args = @_;
  my $SUB_NAME = "readMamSumFile";


  #### Decode the argument list
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";


  #### Define a hash to hold the contents of the file
  my %data;
  $data{SUCCESS} = 0;


  #### Verify that the file exists
  unless ( -f $source_file ) {
    print "ERROR: Unable to find file '$source_file'\n";
    return \%data;
  }


  #### Open the specified file
  unless ( open(INFILE, "$source_file") ) {
    print "ERROR: Unable to open file '$source_file'\n";
    return \%data;
  }


  #### Set up some data
  my $line;
  my @possible_hits = ();


  #### Read in all the search results
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    next if ($line =~ /^\s*$/);

    #### If it's a domain header line, process that
    if ($line =~ /^(\S+) one\-of\-top\-five\-correct: ([\d\.]+) CThresh: [\d\.]+ \d+ best_is: (cluster\d+)$/ ) {
      my $tmp = $1;
      my $domain_char = substr($tmp,length($tmp)-1,1);
      my $biosequence_name = substr($tmp,0,length($tmp)-1);
      my $cluster_probability = $2;
      my $best_cluster = $3;
      $data{$biosequence_name}->{$domain_char}->{cluster_probability} =
        $cluster_probability;
      $data{$biosequence_name}->{$domain_char}->{best_cluster} = $best_cluster;
      my @tmp;
      $data{$biosequence_name}->{$domain_char}->{clusters} = \@tmp;


    #### Or it's one of the hit lines, process that
    } elsif ($line =~ /conP:/) {

      #### Split the line into columns
      my @columns = split(/\t/,$line);

      #### Create a temporary hash and fill it with these data
      my %parameters;
      my $biosequence_name;
      my $domain_char;

      #### Parse the first column into its components
      if ($columns[0] =~ /^(\S+) (cluster\d+) \-\> (\S+)$/) {
        my $tmp = $1;
        $domain_char = substr($tmp,length($tmp)-1,1);
        $biosequence_name = substr($tmp,0,length($tmp)-1);
        $parameters{'biosequence_name'} = $biosequence_name;
        $parameters{'cluster_name'} = $2;
	$parameters{'match_name'} = $3;
      } else {
        print "ERROR: Unable to parse names for line: '$line'\n";
      }

      $parameters{'z_score'} = $columns[1];

      #### Parse the third column into its components
      if ($columns[2] =~ /^(\d+) \/ (\d+)$/) {
        $parameters{'match_length'} = $1;
        $parameters{'query_length'} = $2;
      } else {
        print "ERROR: Unable to parse lengths for line: '$line'\n";
      }

      #### Parse the fourth column into its components
      if ($columns[3] =~ /^conP:\s+([\d\.]+)$/) {
        $parameters{'probability'} = $1;
      } else {
        print "ERROR: Unable to parse conP for line: '$line'\n";
      }

      #### Parse the CATH ID column into its components
      $columns[4] = '' unless(defined($columns[4]));
      if ($columns[4] ne '' &&
          $columns[4] =~ /^CATH-ID:\s+([\d\.]+)$/) {
        $parameters{'second_match_name'} = $1;
        $parameters{'second_match_accession'} = $1;
        $parameters{'second_match_accession'} =~ s/\./\//g;
        $parameters{'second_match_type_id'} = $domain_match_types{'CATH'};

      } else {
        print "ERROR: Unable to parse CATH-ID column '$columns[4]' for line: '$line'\n"
          unless ($columns[4] eq 'NO-CATH' || $columns[4] eq 'CATH-TRUNC' ||
           $columns[4] eq '' );
      }

      $columns[5] =~ s/^\s+// if defined($columns[5]);
      $parameters{'match_annotation'} = $columns[5] if defined($columns[5]);

      #### Push this cluster data onto the list
      push(@{$data{$biosequence_name}->{$domain_char}->{clusters}},
        \%parameters);


    #### Else if it's an end line
    } elsif ($line eq '--end--') {

      # Do nothing


    #### And if nothing has been triggered yet, complain and die
    } else {
      if ($line =~ /CThresh:\s+best_is:/) {
        # just simply no hits
      } elsif ($line =~ /best_is: $/) {
        # just simply no hits
      } else {
        die("ERROR: Line '$line' not recognized by parser");
      }
    }

  }


  #### Close the input file
  close(INFILE);


  #### Set SUCCESS flag and return
  print "INFO: mamSum file successfully parsed!\n" if ($VERBOSE);
  $data{SUCCESS} = 1;
  return \%data;

} # end readMamSumFile



###############################################################################
# readInterProScanFile
###############################################################################
sub readInterProScanFile {
  #my $self = shift;
  my %args = @_;


  #### Decode the argument list
  my $source_file = $args{'source_file'} ||
    die ("ERROR: Must supply source_file");
  my $verbose = $args{'verbose'} || '';

  #### Define some variables
  my ($line);

  #### Define a hash to hold the contents of the file
  my %data;
  $data{SUCCESS} = 0;


  #### Open the specified file
  unless ( open(INFILE, "$source_file") ) {
    die("Cannot open input file $source_file\n");
  }


  #### Verify the header
  $line = <INFILE>;
  $line =~ s/[\r\n]//g;
  unless ($line =~ /orf\ttigr\tipr\tec/) {
    print "ERROR: File '$source_file' does not begin as expected\n";
    return \%data;
  }

  #### Read in all the domain matches
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    next if ($line =~ /^\s*$/);

    #### Split the line into columns and insist we get 10
    my @columns = split(/\t/,$line);
    unless (scalar(@columns) == 10) {
      print "ERROR: Error parsing line '$line' of '$source_file'.  ".
        "Expected 10 columns of information but got ".scalar(@columns)."\n";
      return \%data;
    }
    my $biosequence_name = $columns[0];

    #### Create a temporary hash and fill it with these data
    my %parameters;
    $parameters{'full_line'} = $line;
    $parameters{'biosequence_name'} = $biosequence_name;
    $parameters{'match_name'} = $columns[1];

    $parameters{'match_accession'} = $columns[1];
    $parameters{'match_type_id'} = $domain_match_types{'TIGRFAM'};
    $parameters{'second_match_name'} = $columns[2];
    $parameters{'second_match_accession'} = $columns[2];
    $parameters{'second_match_type_id'} = $domain_match_types{'InterPro'};

    $parameters{'EC_number'} = $columns[3];
    $parameters{'match_annotation'} = $columns[4].': '.$columns[5];
    $parameters{'evalue'} = $columns[6];
    $parameters{'query_start'} = $columns[7];
    $parameters{'query_end'} = $columns[8];
    $parameters{'query_length'} = $columns[9];

    #### Store this new data on the array for this biosequence_name
    my @matches = ();
    $data{$biosequence_name} = \@matches
      unless (defined($data{$biosequence_name}));
    push(@{$data{$biosequence_name}},\%parameters);
  }


  #### Close the input file
  close(INFILE);


  #### Set SUCCESS flag and return
  $data{SUCCESS} = 1;
  return \%data;

} # end readInterProScanFile




