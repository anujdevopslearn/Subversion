#!/usr/local/bin/perl

###############################################################################
# Program     : load_proteomics_experiment.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads a proteomics experiment, i.e. a directory
#               tree of sequest search results against a single protein
#               biosequence_set.
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use DirHandle;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsPROT $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_contact_id $current_username
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$sbeams = SBEAMS::Connection->new();
$sbeamsPROT = SBEAMS::Proteomics->new();
$sbeamsPROT->setSBEAMS($sbeams);


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] <experiment_tag> <directory_path>
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --experiment_tag    The experiment_tag of a proteomics_experiment
                      that is to be worked on
                      on; all are checked if none is provided
  --file_prefix       A prefix that is prepended to the set_path in the
                      biosequence_set table
  --check_status      Is set, nothing is actually done, but rather the
                      biosequence_sets are verified
  --force_ref_db      Normally this program expects the database name for
                      all sequest searches to be the same, but some old
                      fusty data has obsolete database information encoded
                      in the .out files.  If set, this flag ignores the
                      contents of the .out files and assumes that this is
                      the database to be referenced.  Careful, this disables
                      some safety checks!

 e.g.:  $PROG_NAME --set_tag=rafapr --check

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
  "experiment_tag:s","file_prefix:s","check_status","force_ref_db:s")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
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
    work_group=>'Proteomics_admin',
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
  my $check_status = $OPTIONS{"check_status"};
  my $experiment_tag = $OPTIONS{"experiment_tag"} || '';
  my $file_prefix = $OPTIONS{"file_prefix"} || '';
  my $force_ref_db = $OPTIONS{'force_ref_db'};
  $DATABASE = $DBPREFIX{'Proteomics'};


  #### Get the file_prefix if it was specified, and otherwise guess
  unless ($file_prefix) {
    my $module = $sbeams->getSBEAMS_SUBDIR();
    $file_prefix = '/net/dblocal/data/proteomics' if ($module eq 'Proteomics');
  }


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Define a scalar and array of experiment_id's
  my ($experiment_id,$n_experiment_ids);
  my @experiment_ids;


  #### If there was a set_tag specified, identify it
  if ($experiment_tag) {
    $sql = qq~
          SELECT PE.experiment_id
            FROM $TBPR_PROTEOMICS_EXPERIMENT PE
           WHERE PE.experiment_tag = '$experiment_tag'
             AND PE.record_status != 'D'
    ~;

    @experiment_ids = $sbeams->selectOneColumn($sql);
    $n_experiment_ids = @experiment_ids;

    die "No experiments found with experiment_tag = '$experiment_tag'"
      if ($n_experiment_ids < 1);
    die "Too many experiments found with experiment_tag = '$experiment_tag'"
      if ($n_experiment_ids > 1);


  #### If there was NOT a experiment_tag specified, scan for all available ones
  } else {
    $sql = qq~
          SELECT PE.experiment_id
            FROM $TBPR_PROTEOMICS_EXPERIMENT PE
            JOIN $TB_USER_LOGIN UL ON (PE.contact_id=UL.contact_id)
           WHERE PE.record_status != 'D'
           ORDER BY username,experiment_tag
    ~;

    @experiment_ids = $sbeams->selectOneColumn($sql);
    $n_experiment_ids = @experiment_ids;

    die "No experiments found with experiment_tag = '$experiment_tag'"
      if ($n_experiment_ids < 1);

  }


  #### Loop over each experiment, determining its status and processing
  #### it if desired
  print "        set_tag  n_fracs  n_srch  n_spec  set_path\n";
  print "---------------  -------  ------  ------  -----------------------\n";
  foreach $experiment_id (@experiment_ids) {
    my $status = getExperimentStatus(
      experiment_id => $experiment_id);
    printf("%15s  %7d  %6d  %6d  %s\n",
      $status->{experiment_tag},$status->{n_fractions},
      $status->{n_search_batches},$status->{n_spectra},
      $status->{experiment_path});

    #### If we're not just checking the status
    unless ($check_status) {
      my $do_load = 0;
      #$do_load = 1 if ($status->{n_rows} == 0);
      #$do_load = 1 if ($update_existing);
      #$do_load = 1 if ($delete_existing);

      #### If it's determined that we need to do a load, do it
      if ($do_load) {
        $result = loadProteomicsExperiment(
          experiment_tag=>$status->{experment_tag},
          source_file=>$file_prefix.$status->{experiment_path});
      }

    }

  }


  return;

}



###############################################################################
# getExperimentStatus
###############################################################################
sub getExperimentStatus { 
  my %args = @_;
  my $SUB_NAME = 'getExperimentStatus';


  #### Decode the argument list
  my $experiment_id = $args{'experiment_id'}
   || die "ERROR[$SUB_NAME]: experiment_id not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Get information about this biosequence_set_id from database
  $sql = qq~
          SELECT PE.experiment_id,experiment_name,experiment_tag,
                 '???' AS 'experiment_path'
		   FROM $TBPR_PROTEOMICS_EXPERIMENT PE
           WHERE PE.experiment_id = '$experiment_id'
             AND PE.record_status != 'D'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);


  #### Put the information in a hash
  my %status;
  $status{experiment_id} = $rows[0]->[0];
  $status{experiment_name} = $rows[0]->[1];
  $status{experiment_tag} = $rows[0]->[2];
  $status{experiment_path} = $rows[0]->[3];


  #### Get the number of fractions for this experiment
  $sql = qq~
          SELECT count(*) AS 'count'
            FROM $TBPR_FRACTION F
           WHERE F.experiment_id = '$experiment_id'
  ~;
  my ($n_rows) = $sbeams->selectOneColumn($sql);
  $status{n_fractions} = $n_rows;


  #### Get the number of loaded spectra for this experiment
  $sql = qq~
          SELECT count(*) AS 'count'
            FROM $TBPR_FRACTION F
            JOIN  $TBPR_MSMS_SPECTRUM MS ON (F.fraction_id=MS.fraction_id)
           WHERE F.experiment_id = '$experiment_id'
  ~;
  my ($n_rows) = $sbeams->selectOneColumn($sql);
  $status{n_spectra} = $n_rows;


  #### Get the number of search_batches for this experiment
  $sql = qq~
          SELECT count(*) AS 'count'
            FROM $TBPR_SEARCH_BATCH SB
           WHERE SB.experiment_id = '$experiment_id'
  ~;
  my ($n_rows) = $sbeams->selectOneColumn($sql);
  $status{n_search_batches} = $n_rows;

  #### Return information
  return \%status;

}



###############################################################################
# loadProteomicsExperiment
###############################################################################
sub loadProteomicsExperiment { 
  my %args = @_;
  my $SUB_NAME = 'loadProteomicsExperiment';


  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Set the command-line options
  my $check_status = $OPTIONS{"check_status"};
  my $experiment_tag = $OPTIONS{"experiment_tag"} || '';
  my $file_prefix = $OPTIONS{"file_prefix"} || '';
  my $force_ref_db = $OPTIONS{'force_ref_db'};



  #### Get the source directory and verify that it looks right
  my $source_dir = $ARGV[1];
  unless ( -d "$source_dir" ) {
    bail_out("ERROR: $source_dir is not a directory!\n");
  }


  unless ( -f "$source_dir/interact.htm" ) {
    unless ( -f "$source_dir/finalInteract/interact.htm" ) {
      bail_out("ERROR: Cannot find $source_dir/interact.htm!\n");
    }
  }


  #### Try to find if this setname already exists in database
  $sql="SELECT experiment_id ".
      "FROM $TBPR_PROTEOMICS_EXPERIMENT ".
      "WHERE experiment_tag = '$experiment_tag'";
  my ($experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Find all the subdirectories and add them to @fractions
  my @fractions;
  my $dir = new DirHandle "$source_dir";
  if (defined $dir) {
    while (defined($element = $dir->read())) {

      #### If it's a directory but not ./ or ../
      if ( -d "$source_dir/$element" && $element ne "." && $element ne "..") {

        #### Then also verify that there's at least one .out file there
        my $subdir = new DirHandle "$source_dir/$element";
        my $OKflag = 0;
        while ((!$OKflag) && defined($i = $subdir->read())) {
          $OKflag++ if ($i =~ /\.out$/);
        }

        #### And if so, add it to out list
        push(@fractions,$element) if ($OKflag);
        #print "I hope to find data in $element\n" if ($VERBOSE);

      } ## endif

    } ## endwhile

  } else {
    die "ERROR: Unable to read directory '$dir'\n";
  }


  #### For each @fraction, check to see if it's already in the database
  #### and if not, INSERT it
  my $fraction_id;
  my @fraction_ids;
  foreach $element (@fractions) {
    $sql="SELECT fraction_id\n".
               "  FROM $TBPR_FRACTION\n".
               " WHERE experiment_id = $experiment_id\n".
               "   AND fraction_tag = '$element'";
    @fraction_ids = $sbeams->selectOneColumn($sql);
    if (! @fraction_ids) {
      print "Nothing in the database for $element yet.  Adding it...\n";
      my $tmp = $element;
      $tmp =~ s/$experiment_tag//;
      $tmp =~ /^.*?(\d+).*?$/;
      my $fraction_number = $1;
      $sql="INSERT INTO $TBPR_FRACTION\n".
                 "       (experiment_id,fraction_tag,fraction_number)\n".
                 "VALUES ('$experiment_id','$element','$fraction_number')";
      $sbeams->executeSQL($sql);
    } elsif ($#fraction_ids == 0) {
      #print "OK, already a record for $element\n";
    } else {
      my $tmp = $#fraction_ids + 1;
      print "ERROR: Found $tmp records for $element already!\n";
    }
  }


  #### For each @fraction, descend into the directory and start loading
  #### the data therein
  my $search_batch_id;
  my $search_database;
  my $search_id;
  my $search_hit_id;
  my $msms_spectrum_id;
  my $outfile;
  foreach $element (@fractions) {
    $sql="SELECT fraction_id\n".
               "  FROM $TBPR_FRACTION\n".
               " WHERE experiment_id = $experiment_id\n".
               "   AND fraction_tag = '$element'";
    @fraction_ids = $sbeams->selectOneColumn($sql);

    #### Die if the fraction does not already exist in database
    if (!@fraction_ids) {
      die "ERROR: Nothing in the database for fraction $element yet!\n";

    #### If exactly one fraction was found, go to work!
    } elsif ($#fraction_ids == 0) {
      ($fraction_id) = @fraction_ids;

      #### Get a list of all files in the subdirectory
      my $subdir = new DirHandle "$source_dir/$element";
      my $filecounter = 0;
      my @file_list = ();


      #### Make a sorted list of all files
      while (defined($file = $subdir->read())) {
        push(@file_list,$file);
      }
      @file_list = sort(@file_list);

      print "\nProcessing data in $element\n";

      #### Loop over each file, INSERTing into database if a .dta file
      foreach $file (@file_list) {

        if ($file =~ /\.dta$/) {

          #### Insert the contents of the .dta file into the database and
          #### return the autogen PK, or if it already exists (from
          #### another search batch) then just return that PK
          $msms_spectrum_id = addMsmsSpectrumEntry("$source_dir/$element/$file",
            $fraction_id);
          unless ($msms_spectrum_id) {
            die "ERROR: Did not receive msms_spectrum_id\n";
          }


          #### Set $outfile to the corresponding .out file
          $outfile = $file;
          $outfile =~ s/\.dta/.out/;


          #### Sometimes there's no corresponding .out file
          unless ( -e "$source_dir/$element/$outfile" ) {
            print "\nWARNING: file '$source_dir/$element/$outfile' does not ".
                  "exist! (but the .dta file does).  oh well. \n";
            next;
          }


          #### Load the .out file
          my %data = readOutFile(
            inputfile => "$source_dir/$element/$outfile");
          my $file_root = ${$data{parameters}}{file_root};
          my $mass = ${$data{parameters}}{sample_mass_plus_H};

          #### if $search_database not yet defined (very first .out file)
          #### then create and entry so we know $search_batch_id
          unless ($search_database) {
            $search_database = ${$data{parameters}}{search_database};
            if ($force_ref_db) {
              print "Overriding detected database '$search_database' with ".
                "supplied forced '$force_ref_db'\n";
              $search_database = $force_ref_db;
            }
            $search_batch_id = addSearchBatchEntry($experiment_id,
              $search_database,"$source_dir/$element");
          }

          #### If $search_database is different from the {search_database}
          #### in parameters, we have a violation of assumption (that
          #### all files to be loaded are from same search_batch) and must die
          unless ($force_ref_db) {
            unless ($search_database eq ${$data{parameters}}{search_database}) {
              die "ERROR: Data appear to come from more than one \n".
                  "       search_database!  This is totally unexpected\n".
                  "       '$search_database' != ".
                  "'${$data{parameters}}{search_database}'\n";
            }
          }


          #### Insert the entry into table "search"
          #print "=====================================================\n";
          $search_id = addSearchEntry($data{parameters},
            $search_batch_id,$msms_spectrum_id);


          #### Insert the entries into table "search_hit"
          $search_hit_id = addSearchHitEntry($data{matches},$search_id);


          #print "Successfully loaded $file_root (mass = $mass)\n";
          print ".";
          $filecounter++;
        }


        #exit if ($filecounter > 5);


      } ## endwhile

      print "\nFound $filecounter .out files to process\n";


    #### If more than one fraction is found, die.  This should never happen
    } else {
      my $tmp = $#fraction_ids + 1;
      die "ERROR: Found $tmp records for $element already!\n";
    }

  } ## endforeach


} # end handleRequest



###############################################################################
###############################################################################
###############################################################################


###############################################################################
# addMsmsSpectrumEntry: find or make a new entry in msms_spectrum table
###############################################################################
sub addMsmsSpectrumEntry {
  my ($inputfile) = shift
    || die "ERROR addMsmsSpectrumEntry: missing parameter 1: inputfile\n";
  my ($fraction_id) = shift
    || die "ERROR addMsmsSpectrumEntry: missing parameter 2: fraction_id\n";


  #### Read in the specified file
  my $result = readDtaFile(inputfile => "$inputfile");
  unless ($result) {
    die "ERROR: Unable to read dta file '$inputfile'\n";
  }
  my $file_root = ${$result}{parameters}->{file_root};


  #### Try to find if this file_root already exists for this fraction_id
  my $sql_query;
  $sql_query = qq~
      SELECT msms_spectrum_id
        FROM $TBPR_MSMS_SPECTRUM
       WHERE fraction_id = '$fraction_id'
         AND msms_spectrum_file_root = '$file_root'
  ~;
  my ($msms_spectrum_id) = $sbeams->selectOneColumn($sql_query);

  #### If it is found, then return the key
  if ($msms_spectrum_id) {
    #print "Already found ($msms_spectrum_id)!  No need to reload\n";
    #print "($msms_spectrum_id)";
    return $msms_spectrum_id;
  }

  #### Otherwise, extract some more info and build a statement to INSERT
  my $start_scan = ${$result}{parameters}->{start_scan};
  my $end_scan = ${$result}{parameters}->{end_scan};
  my $n_peaks = ${$result}{parameters}->{n_peaks};

  $sql_query = qq~
      INSERT INTO $TBPR_MSMS_SPECTRUM ( fraction_id,msms_spectrum_file_root,
      	start_scan,end_scan,n_peaks )
      VALUES ( '$fraction_id','$file_root',
      	'$start_scan','$end_scan','$n_peaks' )
  ~;

  print "$sql_query\n\n" if $VERBOSE;
  $sbeams->executeSQL("$sql_query");


  #### Now obtain the autogen key that was just INSERTed
  unless ($msms_spectrum_id = $sbeams->getLastInsertedPK()) {
    die "ERROR: Failed to retreive PK search_batch_id\n";
  }


  #### Unecomment to avoid inserting the spectral information
  #return $msms_spectrum_id;


  #### Now insert all the mass,intensity pairs
  my ($i,$mass,$intensity);
  my $create_bcp_file = "YES";
  my $create_bcp_file = 0;

  if ($create_bcp_file) {
    open(SPECFILE,">>/net/db/projects/proteomics/bcp/msms_spectrum_peak.txt");
  }

  for ($i=0; $i<${$result}{parameters}->{n_peaks}; $i++) {
    $mass = ${$result}{mass_intensities}->[$i]->[0];
    $intensity = ${$result}{mass_intensities}->[$i]->[1];
    if ($create_bcp_file) {
      print SPECFILE "$msms_spectrum_id\t$mass\t$intensity\r\n";
    } else {
      $sql_query = qq~
        INSERT INTO $TBPR_MSMS_SPECTRUM_PEAK ( msms_spectrum_id,mass,intensity )
        VALUES ( '$msms_spectrum_id','$mass','$intensity' )
      ~;

      #print "$sql_query\n\n" if $VERBOSE;
      $sbeams->executeSQL("$sql_query");
    }

  }

  close SPECFILE if ($create_bcp_file);

  return $msms_spectrum_id;

}



###############################################################################
# addSearchBatchEntry: find or make a new entry in search_batch table
###############################################################################
sub addSearchBatchEntry {
  my ($experiment_id) = shift
    || die "ERROR addSearchBatch: missing parameter 1: experiment_id\n";
  my ($search_database) = shift
    || die "ERROR addSearchBatch: missing parameter 2: search_database\n";
  my ($directory) = shift
    || die "ERROR addSearchBatch: missing parameter 3: directory\n";

  my $sql_query;


  #### Find the biosequence_set_id for the supplied $search_database
  $sql_query = qq~
      SELECT biosequence_set_id
        FROM $TBPR_BIOSEQUENCE_SET
       WHERE set_path = '$search_database'
  ~;
  my ($biosequence_set_id) = $sbeams->selectOneColumn($sql_query);
  unless ($biosequence_set_id) {
    die "ERROR: Database has not yet been entered: '$search_database'\n";
  }


  #### See if a suitable search_batch entry already exists
  $sql_query = qq~
      SELECT search_batch_id
        FROM $TBPR_SEARCH_BATCH
       WHERE experiment_id = '$experiment_id'
         AND biosequence_set_id = '$biosequence_set_id'
  ~;
  my @search_batch_ids = $sbeams->selectOneColumn($sql_query);
  my $search_batch_id;


  #### If not, create one
  if (! @search_batch_ids) {
    print "INFO: Need to add a search_batch for these data\n";

    $sql_query = qq~
      INSERT INTO $TBPR_SEARCH_BATCH (experiment_id,biosequence_set_id)
      VALUES ( $experiment_id,$biosequence_set_id )
    ~;
    print "$sql_query\n\n" if $VERBOSE;
    $sbeams->executeSQL("$sql_query");
    unless ($search_batch_id = $sbeams->getLastInsertedPK()) {
      die "ERROR: Failed to retreive PK search_batch_id\n";
    }


    #### Read in the sequest.params file in the same subdirectory
    #### and store its contents
    unless (addParamsEntries($search_batch_id,$directory)) {
      die "ERROR: addParamsEntries failed.\n";
    }


  #### If there's exactly one, the that's what we want
  } elsif ($#search_batch_ids == 0) {
    $search_batch_id = $search_batch_ids[0];

  #### If there's more than one, we have a big problem
  } elsif ($#search_batch_ids > 0) {
    die "ERROR: Found too many records for\n$sql_query\n";
  }


  return $search_batch_id;

}



###############################################################################
# addSearchEntry: Insert a new entry in search table
###############################################################################
sub addSearchEntry {
  my ($parameters_ref) = shift
    || die "ERROR addSearchBatch: missing parameter 1: parameters_ref\n";
  my ($search_batch_id) = shift
    || die "ERROR addSearchBatch: missing parameter 2: search_batch_id\n";
  my ($msms_spectrum_id) = shift
    || die "ERROR addSearchBatch: missing parameter 3: msms_spectrum_id\n";

  #### Define the data columns for table "search"
  my @columns = ( "file_root","start_scan","end_scan",
    "sample_mass_plus_H","assumed_charge","total_intensity",
    "matched_peptides","lowest_prelim_score",
    "search_date","search_elapsed_min","search_host" );


  #### Build the VALUES part of the SQL statement
  my ($element,$tmp);
  my @sql_values;
  foreach $element (@columns) {
    $tmp = $parameters_ref->{$element};
    $tmp =~ s/\'/\'\'/g;
    push(@sql_values,"'$tmp'");
  }


  #### Build the whole SQL statement and execute
  my $sql_query = "INSERT INTO $TBPR_SEARCH ( search_batch_id,msms_spectrum_id,".
    join(",",@columns)." )\n".
    "VALUES ( $search_batch_id,$msms_spectrum_id,".join(",",@sql_values)." )";

  print "$sql_query\n\n" if $VERBOSE;
  $sbeams->executeSQL("$sql_query");


  #### Retrieve the autogen key for the just-inserted row
  my $search_id;
  unless ($search_id = $sbeams->getLastInsertedPK()) {
    die "ERROR: Failed to retreive PK search_id\n";
  }


  #### Return that key if successful
  return $search_id;

}


###############################################################################
# addSearchHitEntry: Insert a new entry in search_hit table
###############################################################################
sub addSearchHitEntry {
  my ($matches_ref) = shift
    || die "ERROR addSearchBatch: missing parameter 1: matches_ref\n";
  my ($search_id) = shift
    || die "ERROR addSearchBatch: missing parameter 2: search_id\n";


  #### Define the data columns for table "search_hit"
  my @columns = ( "hit_index","cross_corr_rank","prelim_score_rank",
    "hit_mass_plus_H","mass_delta","cross_corr","norm_corr_delta","prelim_score",
    "identified_ions","total_ions","reference","additional_proteins",
    "peptide","peptide_string" );


  #### Pull out the array of rows
  my @matches = @{$matches_ref};


  #### Print a warning and return if there are no rows
  unless (@matches) {
    print "WARNING: Apparently no matches for this search\n";
    return 1;
  }


  #### Loop over each row
  my ($match,$element,$tmp,$i,$last_cols);
  my $n_matches = $#matches;
  for ($i=0; $i<=$n_matches; $i++) {
    $match = $matches[$i];

    #### Build the VALUES part of the SQL statement
    my @sql_values;
    foreach $element (@columns) {
      $tmp = $match->{$element};
      $tmp =~ s/\'/\'\'/g;
      push(@sql_values,"'$tmp'");
    }

    #### If there are more rows then, add the dCn to next row
    $last_cols = "";
    if ($i<$n_matches) {
      $last_cols .= ",next_dCn";
      $tmp = $matches[$i+1]->{norm_corr_delta} - $match->{norm_corr_delta};
      push(@sql_values,"'$tmp'");
    }


    #### If this is the first row, then label it with best_hit_flag
    if ($i==0) {
      $last_cols .= ",best_hit_flag";
      push(@sql_values,"'D'");
    }


    #### Build the whole SQL statement and execute
    my $sql_query = "INSERT INTO $TBPR_SEARCH_HIT ( search_id,".
      join(",",@columns)."$last_cols )\n".
      "VALUES ( $search_id,".join(",",@sql_values)." )";

    print "$sql_query\n\n" if $VERBOSE;
    $sbeams->executeSQL("$sql_query");

  }


  return 1;

}



###############################################################################
# addParamsEntries: Read a seqest.params file and put into search_batch_keyvalue
###############################################################################
sub addParamsEntries {
  my ($search_batch_id) = shift
    || die "ERROR addSearchBatch: missing parameter 1: search_batch_id\n";
  my ($directory) = shift
    || die "ERROR addSearchBatch: missing parameter 2: directory\n";


  my $file = "$directory/sequest.params";

  if ( ! -e "$file" ) {
    print "ERROR: Unable to find sequest parameter file: '$file'\n";
    return;
  }


  my $result = readParamsFile(inputfile => "$file");
  unless ($result) {
    print "ERROR: Unable to read sequest parameter file: '$file'\n";
    return;
  }


  #### Loop over each row
  my ($key,$value,$tmp);
  my $counter = 0;
  foreach $key (@{${$result}{keys_in_order}}) {

    $value = ${$result}{parameters}->{$key};
    $value =~ s/\'/\'\'/g;

    #### Build the whole SQL statement and execute
    my $sql_query = qq~
      INSERT INTO $TBPR_SEARCH_BATCH_PARAMETER
      	( search_batch_id,key_order,parameter_key,parameter_value )
      VALUES  ( '$search_batch_id',$counter,'$key','$value' )
    ~;

    print "$sql_query\n\n" if $VERBOSE;
    $sbeams->executeSQL("$sql_query");

    $counter++;

  }


  return 1;

}


