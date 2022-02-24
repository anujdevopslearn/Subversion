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
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use DirHandle;
use Math::Interpolate;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsPROT $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TESTONLY
             $current_contact_id $current_username
             %spectra_written $interact_fname
	     %timepoints $t0 $t1
            );

#### Store timepoint
$timepoints{t0} = [gettimeofday()];


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;


use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$sbeams = SBEAMS::Connection->new();
$sbeamsPROT = SBEAMS::Proteomics->new();
$sbeamsPROT->setSBEAMS($sbeams);


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --list_all          If set, a list of experiments with status is printed
  --load              If set, a fresh load of the named experiment_tag
                      plus search_subdir will be triggered
  --update_from_summary_files
                      If set, an update from the html summary files
                      will be triggered
  --update_search     If set, a generic update of the search data will
                      be triggered
  --update_probabilties
                      If set, an update of the probability values will be
                      be triggered
  --update_timing_info
                      If set, an update of the timing and percent buffer
                      B information will be triggered
  --update_data_location    update data_location in search_batch and atlas_search_batch
  --update_experiment_tag   update experiment_tag and sample_tag
  --gradient_program_id=nnn
                      If there is no gradient_program_id already set for
                      this fraction, then set it to this value instead of 1
  --column_delay=nnn  If there is no column_delay already set for
                      this fraction, then set it to this value instead of 240
  --experiment_tag    The experiment_tag of a proteomics_experiment
                      that is to be worked on; all are checked if
                      none is provided
  --experiment_id     Load into this experiment using id (enforced uniqueness)
  --search_subdir     Subdirectory (from the experiment_path of the
                      specific sequest search to load)
  --check_status      If set, nothing is actually done, but rather the
                      experiments are verified
  --testonly          If set, nothing is actually inserted into the database,
                      but we just go through all the motions.  Use --verbose
                      to see all the SQL statements that would occur
  --file_prefix       A prefix that is prepended to the experiment_path in the
                      proteomics_expierment table, assuming it is a
                      relative path instead of an absolute one
  --force_ref_db      Normally this program expects the database name for
                      all sequest searches to be the same, but some old
                      fusty data has obsolete database information encoded
                      in the .out files.  If set, this flag ignores the
                      database name in the .out files and assumes that this is
                      the database to be referenced.  Careful, this disables
                      some safety checks!
  --cleanup_archive   Perform cleanup maintenance on the directory which can
                      include many functions including compressing and
                      verifying the layout
  --delete_search_batch   Perform a delete of all the components of the
                      specified search_batch.  This does not delete spectra
                      or fractions.  Use --delete_experiment for that
  --delete_experiment   Perform a delete of fractions, spectra, and the
                      experiment itself for the specified experiment.
  --delete_fraction   Perform a delete of the specified fraction,
                      its spectra, searches, and search_hits.
  --force_search_batch  Forces adding a search_batch even if there are no
                      fractions to load
  --fix_ipi           If set, then convert long ugly IPI accessions to a
                      simple IPInnnnnnnnnn

  --interact_fname    name of interact file (e.g. interact-prob.xml, or
                      older format interact-prob-data.htm,  etc.).  use this
                      in conjunction with --search_subdir "subdirectory"
  --pepxml_load       If set, the whole experiment will be loaded from
                      the pepXML file instead of subdirectories with .out files

  --experiment_list_file     Path to the Experiment.list file. If given it will be updated with search id and 
                             experiment path  
  --experiment_tag_list_file search_batch_id\ttag


 e.g.:  $PROG_NAME --list_all
        $PROG_NAME --check --experiment_tag=rafapr
        $PROG_NAME --experiment_id '12' --check_status ----testonly
        $PROG_NAME --experiment_id '12' --search_subdir 'HsIPI_v4.0' --load
        $PROG_NAME --experiment_id '12' --search_subdir 'HsIPI_v4.0' --interact_fname 'interact-prob.xml' --update_probabilities
        $PROG_NAME --update_data_location --experiment_id
        $PROG_NAME --update_data_location --experiment_list_file file
        $PROG_NAME --update_experiment_tag --experiment_tag_list_file  file 
EOU


#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
  "experiment_tag:s","file_prefix:s","check_status","force_ref_db:s",
  "list_all","search_subdir:s","load","testonly",
  "update_from_summary_files","update_search","update_probabilities",
  "update_timing_info","gradient_program_id:i","column_delay:i",
  "cleanup_archive","delete_search_batch","delete_experiment",
  "delete_fraction:s","force_search_batch","fix_ipi",
  "interact_fname:s", "experiment_id:s","pepxml_load","experiment_list_file:s",
  "update_data_location", "experiment_tag_list_file:s", "update_experiment_tag"
  )) {
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
my $search_database;  ## needed for parsing NCBInr file later

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
  my $check_status = $OPTIONS{"check_status"} || '';
  my $list_all = $OPTIONS{"list_all"} || '';
  my $load = $OPTIONS{"load"} || '';
  my $update_from_summary_files = $OPTIONS{"update_from_summary_files"} || '';
  my $update_search = $OPTIONS{"update_search"} || '';
  my $update_probabilities = $OPTIONS{"update_probabilities"} || '';
  my $update_timing_info = $OPTIONS{"update_timing_info"} || '';
  my $cleanup_archive = $OPTIONS{"cleanup_archive"} || '';
  my $delete_search_batch = $OPTIONS{"delete_search_batch"} || '';
  my $delete_experiment = $OPTIONS{"delete_experiment"} || '';
  my $delete_fraction = $OPTIONS{"delete_fraction"} || '';
  my $experiment_tag = $OPTIONS{"experiment_tag"} || '';
  my $search_subdir = $OPTIONS{"search_subdir"} || '';
  my $file_prefix = $OPTIONS{"file_prefix"} || '';
  my $force_ref_db = $OPTIONS{'force_ref_db'} || '';
  $interact_fname = $OPTIONS{"interact_fname"} || '';
  my $experiment_id = $OPTIONS{"experiment_id"} || '';
  my $pepxml_load = $OPTIONS{"pepxml_load"} || '';
  my $experiment_list_file =$OPTIONS{"experiment_list_file"};
  my $update_data_location = $OPTIONS{"update_data_location"} || 0;
  my $update_experiment_tag =  $OPTIONS{"update_experiment_tag"} || 0;

  $TESTONLY = $OPTIONS{'testonly'} || 0;
  $DATABASE = $DBPREFIX{'Proteomics'};


  #### Get the file_prefix if it was specified, and otherwise guess
  unless ($file_prefix) {
    my $module = $sbeams->getSBEAMS_SUBDIR($SBEAMS_SUBDIR);
    $file_prefix = $RAW_DATA_DIR{Proteomics};
    print "$module file_prefix='$file_prefix'\n";
  }

  #### If there are any parameters left, complain and print usage
  if ($ARGV[0]){
    print "ERROR: Unresolved parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  ## if experiment_id was specified, check on it
  if ($experiment_id)
  {

      $experiment_tag = getExperimentTag( exp_id => $experiment_id );

      if ($experiment_tag eq ''){
         die "no experiment_tag found for experiment_id $experiment_id\n";
      }
  }


  ## if $interact_fname was set and updating_probabilities, require $search_subdir too...
  if ( $interact_fname && $update_probabilities )
  {

      unless ($search_subdir)
      {

          print "$USAGE\n";

          print "ERROR: need to set --search_subdir\n";

          exit;

      }

  }

  if ($update_data_location){
     my $experiment_list_file = $OPTIONS{"experiment_list_file"} || '';
     if (! $experiment_id && ! $experiment_list_file){
        die "ERROR: needs experiment_id to update\n";
     }
     if ($experiment_id){
       updateDataLocation( experiment_id=>$experiment_id);
     }else{
       updateDataLocation_list(experiment_list_file=>$experiment_list_file);
     }
     exit;
  }

  if ($update_experiment_tag){
     if (! $OPTIONS{"experiment_tag_list_file"} ){
       die "ERROR: need experiment_tag_list_file\n";
     }
     updateExperimentTag(experiment_tag_list_file => $OPTIONS{"experiment_tag_list_file"});
     exit;
  }

  #### Define a scalar and array of experiment_id's
  my $n_experiment_ids;
  my @experiment_ids;

  #### If there was a set_tag specified, and no experiment_id specified,
  #### identify from tag:
  if ($experiment_tag ){
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

      $experiment_id = $experiment_ids[0];

  #### If there was NOT a experiment_tag specified, scan for all available ones
  } else {
    die "needs experiment_tag or experiment_id\n";
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
    ## xxxxxxx note, need assignment to experiment_id here, but not sure that
    ## original intention of this section is still carried through rest of code

  }


  ### check $search_subdir and $interact_fname and make sure all's swell before proceeding
  my $full_interact_file_path;

  if ( $interact_fname && $search_subdir)
  {

      ## retrieve experiment directory from experiment record:
      my $exp_dir = getExperimentDirectory( exp_id => $experiment_id);
      if ( -e "$file_prefix/$exp_dir/$search_subdir/$interact_fname")
      {
          $full_interact_file_path = "$file_prefix/$exp_dir/$search_subdir/$interact_fname";

      } else
      {

          die "File $file_prefix/$exp_dir/$search_subdir/$interact_fname "
              . "not found.  Please check --interact_fname $interact_fname "
              . " and --search_subdir $search_subdir ($!)";

      }

  } 

  #### Loop over each experiment, determining its status and processing
  #### it if desired
  print "        set_tag  n_fracs  n_srch  n_spec  experiment_path\n";
  print "---------------  -------  ------  ------  -----------------------\n";
  foreach $experiment_id (@experiment_ids) {
    my $status = getExperimentStatus(
      experiment_id => $experiment_id);
    printf("%15s  %7d  %6d  %6d  %s\n",
      $status->{experiment_tag},$status->{n_fractions},
      $status->{n_search_batches},$status->{n_spectra},
      $status->{experiment_path});

    #### If there are search_batchs, print out information on them
    if ($status->{n_search_batches}) {
      foreach my $search_batch (@{$status->{search_batch_subdirs}}) {
	my $search_batch_id = $status->{search_batch_ids_by_subdir}
	  ->{$search_batch};
        printf("                        id=%5d          %s\n",
          $search_batch_id,$search_batch);
      }
    }

    #### Figure out what search_batches to work on
    #### If the user supplied one, go to work on it
    my @search_batches;
    if ($search_subdir) {
      @search_batches = ($search_subdir);

    #### If not, do them all
    } elsif ($status->{n_search_batches}) {
      @search_batches = @{$status->{search_batch_subdirs}};

    #### Except if there are none, go to the next item
    } else {
      printf("                                          No search_batch\n");
    }

    my $search_batch_subdir;
    foreach $search_batch_subdir (@search_batches) {

      #### If we're not just checking the status
      if ($list_all eq '' && $status->{experiment_path}) {
        my $prefix = $file_prefix;
        $prefix = '' if ($status->{experiment_path} =~ /\/dblocal/);

        my $source_dir;
				if ($status->{experiment_path} =~ /^\//) {
					$source_dir = $status->{experiment_path}."/".
								$search_batch_subdir;
				} else {
					$source_dir = $prefix."/".$status->{experiment_path}."/".
								$search_batch_subdir;
				}

				if (!-d $source_dir) {
						print "WARNING: Directory not found! $source_dir\n";
				}

				#### If user asked for a load, do it
				if ($load) {
							print "Loading data in $source_dir\n";

				if ($pepxml_load) {
						$result = loadProteomicsExperimentFromPepXML(
							experiment_tag=>$status->{experiment_tag},
							source_dir=>$source_dir
								);

				} else {
						$result = loadProteomicsExperiment(
							experiment_tag=>$status->{experiment_tag},
							source_dir=>$source_dir,
						experiment_list_file=>$experiment_list_file
								);
			}
  	  print "\n";
  	}

  	#### If user asked for an update_from html, do it
  	if ($update_from_summary_files) {
          print "Updating from summary files in $source_dir\n";
  	  $result = updateFromSummaryFiles(
  	    experiment_tag=>$status->{experiment_tag},
  	    search_batch_subdir=>$search_batch_subdir,
  	    source_dir=>$source_dir,
          );
  	  print "\n";
  	}


  	#### If user asked for an update_probabilities, do it
  	if ($update_probabilities) {
          print "Updating probabilities in $source_dir\n";
  	  $result = updateProbabilities(
  	    experiment_tag=>$status->{experiment_tag},
  	    search_batch_subdir=>$search_batch_subdir,
  	    source_dir=>$source_dir,
            full_interact_path => $full_interact_file_path,
          );
  	  print "\n";
  	}

  	#### If user asked for an update_search, do it
  	if ($update_search) {
          print "Updating search results\n";
  	  $result = updateSearchResults(
  	    experiment_tag=>$status->{experiment_tag},
  	    search_batch_subdir=>$search_batch_subdir,
  	    source_dir=>$source_dir,
          );
  	  print "\n";
  	}

  	#### If user asked for an update_timing_info, do it
  	if ($update_timing_info) {
          print "Updating Timing and % ACN information from nfo files\n";
  	  $result = updateTimingInfo(
  	    experiment_tag=>$status->{experiment_tag},
  	    search_batch_subdir=>$search_batch_subdir,
  	    source_dir=>$source_dir);
  	  print "\n";
  	}

  	#### If user asked for general maintenance, do it
  	if ($cleanup_archive) {
          print "Performing general cleanup on the file archive...\n";
  	  $result = cleanupArchive(
  	    experiment_tag=>$status->{experiment_tag},
  	    search_batch_subdir=>$search_batch_subdir,
  	    source_dir=>$source_dir);
  	  print "\n";
  	}

  	#### If user asked for delete_search_batch, do it
  	if ($delete_search_batch) {
          print "Deleting search batch $search_batch_subdir in the database...\n\n";
  	  $result = deleteSearchBatch(
  	    experiment_tag=>$status->{experiment_tag},
  	    search_batch_subdir=>$search_batch_subdir,
  	    source_dir=>$source_dir);
  	  print "\n";
  	}

      } # endif list_all

    } # endforeach subdir


    #### If user asked for delete_experiment, do it
    if ($delete_experiment) {
    print "Deleting experiment '$experiment_tag' in the database...\n\n";
      $result = deleteExperiment(
        experiment_tag=>$experiment_tag,
      );
      print "\n";
    }


    #### If user asked for delete_fraction, do it
    if ($delete_fraction) {
    print "Deleting fraction '$delete_fraction' in experiment ".
      "'$experiment_tag' in the database ".
      "(but not the files)...\n\n";
      $result = deleteFraction(
        experiment_tag=>$experiment_tag,
        fraction_tag=>$delete_fraction,
      );
      print "\n";
    }

  } # endforeach experiment


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
                 experiment_path
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


  #### Get the search_batches for this experiment
  $sql = qq~
          SELECT search_batch_subdir
            FROM $TBPR_SEARCH_BATCH SB
           WHERE SB.experiment_id = '$experiment_id'
  ~;
  my @subdirs = $sbeams->selectOneColumn($sql);
  $status{n_search_batches} = scalar(@subdirs);
  $status{search_batch_subdirs} = \@subdirs;


  #### Get the search_batch_ids for this experiment
  $sql = qq~
          SELECT search_batch_subdir,search_batch_id
            FROM $TBPR_SEARCH_BATCH SB
           WHERE SB.experiment_id = '$experiment_id'
  ~;
  my %ids_by_subdirs = $sbeams->selectTwoColumnHash($sql);
  $status{search_batch_ids_by_subdir} = \%ids_by_subdirs;


  #### Return information
  return \%status;

}



###############################################################################
# loadProteomicsExperiment - load spectra and .out's
###############################################################################
sub loadProteomicsExperiment {
  my %args = @_;
  my $SUB_NAME = 'loadProteomicsExperiment';


  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_file not passed";

  my $experiment_list_file = $args{'experiment_list_file'};


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Set the command-line options
  my $check_status = $OPTIONS{"check_status"};
  my $file_prefix = $OPTIONS{"file_prefix"} || '';
  my $force_ref_db = $OPTIONS{'force_ref_db'};



  #### Verify that the source directory looks right
  unless ( -d "$source_dir" ) {
    die("ERROR: '$source_dir' is not a directory!\n");
  }

  unless ( -f "$source_dir/interact.htm" ||
           -f "$source_dir/interact.xml" ||
           -f "$source_dir/interact-prob.xml" ||
           -f "$source_dir/sequest.params" ||
           -f "$source_dir/comet.params" || 
	         -f "$source_dir/interact-prob.pep.xml" ||
	         -f "$source_dir/interact-prob-data.htm" ||
           -f "$source_dir/interact-combined.pep.xml" ||
           -f "$source_dir/interact-ipro.pep.xml") {
    die("ERROR: '$source_dir' just doesn't look like a search results ".
        "directory");
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
  my @dir_contents = getDirListing($source_dir);
  unless (@dir_contents) {
    die "ERROR: Unable to read directory '$source_dir'\n";
  }

  print "\nDuring the load process, the following symbols may be printed\n";
  print "  . Each inserted search result (single .out/.dta)\n";
  print "  - Spectrum is intentionally not INSERTed into database tables\n";
  print "  < Fewer than all of the search_hits are INSERTed as per config\n\n";

  foreach $element (@dir_contents) {

    #### If it's a directory but not ./ or ../
    if ( -d "$source_dir/$element" && $element ne "." && $element ne "..") {

      #### Then also verify that there's at least one .out file there
      my $subdir = new DirHandle "$source_dir/$element";
      my $OKflag = 0;
      while ((!$OKflag) && defined($i = $subdir->read())) {
        $OKflag++ if ($i =~ /\.out$/ && $i !~ /slurm/i);
      }

      #### And if so, add it to out list
      push(@fractions,$element) if ($OKflag);
    } ## end if

  } ## end foreach


  #### If there are no fractions, and force_search_batch was specified,
  #### then add a search_batch records but nothing else to do
  unless (@fractions) {
    if ($OPTIONS{force_search_batch}) {

      #### If the --force_ref_db option was supplied, use that
      if ($OPTIONS{force_ref_db}) {
      	$search_database = $OPTIONS{force_ref_db};

      #### Else try to get the information from the params file
      } elsif (-e "$source_dir/sequest.params") {
				my $line;
				open(INF,"$source_dir/sequest.params");
				while ($line = <INF>) {
					$line =~ s/[\r\n]//g;
				  if ($line =~ /database_name\s*=\s*(\S+)\s*$/) {
	          if ($1) {
              if ($search_database) {
                die("ERROR: more than one search database_name defined.  This is not yet supported.");
              } else {
                $search_database = $1;
              }
            }
	       }  
	    }
     	close(INF);
   }


		if ($search_database) {
			my $search_batch_id = addSearchBatchEntry(
							experiment_id=>$experiment_id,
							search_database=>$search_database,
							search_directory=>$source_dir,
							fraction_directory=>"$source_dir"
					);
			print "Added search_batch_id $search_batch_id\n";
		 
			if ($experiment_list_file) {
				open(EXP_IN, ">>$experiment_list_file") or exit(0);

					print (EXP_IN "$search_batch_id\t$source_dir\n");
			
					close(EXP_IN);
		 }
		 else {
				print "[INFO]: Path to Experiment.list not provided ";

		 }
					 
					 
		
	 } else {
			print "ERROR: Unable to determine search_database from sequest.params\n";
	 }

	 } else {
				print "ERROR: There do not appear to be any fractions to load\n";
	 }
 }


  #### Define a hash to hold the fraction_id's
  my %fraction_ids;

  #### Create a hash to hold the lower case versions of fraction_tags
  my %lower_case_fractions;


  #### For each @fraction, check to see if it's already in the database
  #### and if not, INSERT it
  my $fraction_id;
  my @returned_fraction_ids;
  foreach $element (@fractions) {

    #### Check to make sure there isn't some different-case version
    if (exists($lower_case_fractions{lc($element)})) {
        print "ERROR: There is already another fraction with this same name ".
    	  "but with different capitalization in this experiment.  Since ".
	      "most RDBMS's are case-insensitive, this cannot be.\n";
        next;
      }

    #### Determine how many fractions respond to this name
    $sql="SELECT fraction_id\n".
         "  FROM $TBPR_FRACTION\n".
         " WHERE experiment_id = $experiment_id\n".
         "   AND fraction_tag = '$element'";
    @returned_fraction_ids = $sbeams->selectOneColumn($sql);

    #### If none, then we need to add this fraction
    if (! @returned_fraction_ids) {
      $lower_case_fractions{lc($element)} = 1;
      if ($check_status) {
        print "Entry for fraction '$element' needs to be added\n";
        next;
      }
      print "Adding fraction '$element' to database\n";
      my $tmp = $element;
      if ($tmp =~ /^$experiment_tag.+$/) {
        $tmp =~ s/$experiment_tag//;
      }

      #### Caculate a fraction number
      my $fraction_number;

      #### If it looks like a 96 well plate ID, turn into number
      if ($tmp =~ /^([A-H])(\d{1,2})$/ && $2 <= 12) {
        my $letter = $1;
        my $number = $2;
        $letter =~ tr/A-H/1-8/;
        $fraction_number = ($number - 1) * 8 + $letter;

      #### Else just pull out a number
      } elsif ($tmp =~ /^.*?(\d+).*?$/) {
        $fraction_number = $1;
        # Guard against numbers too big
        $fraction_number = substr($fraction_number,0,8);
      }


      my %rowdata;
      $rowdata{experiment_id} = $experiment_id;
      $rowdata{fraction_tag} = $element;
      $rowdata{fraction_number} = $fraction_number;
      $fraction_id = $sbeams->insert_update_row(
        insert=>1,
        table_name=>$TBPR_FRACTION,
        rowdata_ref=>\%rowdata,
        PK_name=>'fraction_id',
        return_PK=>1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY.$check_status,
      );

      $fraction_ids{$element} = $fraction_id;


    #### Else if there is exactly one, mention that it's already there
    } elsif (scalar(@returned_fraction_ids) == 1) {
      print "Fraction '$element' already exists in the database\n";
      $fraction_ids{$element} = $returned_fraction_ids[0];


    #### If we get more than one, this is bad so die horribly
    } else {
      my $tmp = scalar(@returned_fraction_ids);
      die("ERROR: Found $tmp records for $element already!");
    }

  }


  #### Store timepoint
  $timepoints{t1} = [gettimeofday()];


  #### For each @fraction, descend into the directory and start loading
  #### the data therein
  my $search_batch_id;
  my $search_id;
  my $search_hit_id;
  my $msms_spectrum_id;
  my $outfile;
  my $total_files = 0;

  my $use_batch_transactions = 1;

  foreach $element (@fractions) {

    #### Die if the fraction does not already exist in database
    $fraction_id = $fraction_ids{$element};
    unless ($fraction_id) {
      die "ERROR: Nothing in the database for fraction $element yet!\n";
    }


    #### Get a list of all files in the subdirectory
    my $filecounter = 0;
    $t0 = [gettimeofday()];
    my @file_list = getDirListing("$source_dir/$element");
    $t1 = [gettimeofday()];
    $timepoints{'A #getDirListing'} += tv_interval($t0,$t1);

    print "\nProcessing data in $element\n";
    if ($use_batch_transactions && !$TESTONLY) {
      $sbeams->initiate_transaction();
    }
    #### Loop over each file, INSERTing into database if a .dta file
    foreach $file (@file_list) {

      if ($file =~ /\.dta$/) {
        #### Insert the contents of the .dta file into the database and
        #### return the autogen PK, or if it already exists (from
        #### another search batch) then just return that PK
				my $t0local = [gettimeofday()];
        $msms_spectrum_id = addMsmsSpectrumEntry(
          "$source_dir/$element/$file",$fraction_id);
          unless ($msms_spectrum_id) {
          die "ERROR: Did not receive msms_spectrum_id\n";
        }
				$t1 = [gettimeofday()];
				$timepoints{'B #addMsmsSpectrumEntry'} += tv_interval($t0local,$t1);


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
				$t0 = [gettimeofday()];
        my %data = $sbeamsPROT->readOutFile(
          inputfile => "$source_dir/$element/$outfile");
        my $file_root = ${$data{parameters}}{file_root};
        my $mass = ${$data{parameters}}{sample_mass_plus_H};
				$t1 = [gettimeofday()];
				$timepoints{'C #readOutFile'} += tv_interval($t0,$t1);

        #### if $search_database not yet defined (very first .out file)
        #### then create and entry so we know $search_batch_id
        unless ($search_database) {
          $search_database = ${$data{parameters}}{search_database};
          if ($force_ref_db) {
            print "Overriding detected database '$search_database' with ".
              "supplied forced '$force_ref_db'\n";
            $search_database = $force_ref_db;
          }

          $search_batch_id = addSearchBatchEntry(
            experiment_id=>$experiment_id,
            search_database=>$search_database,
            search_directory=>$source_dir,
            fraction_directory=>"$source_dir/$element"
          );
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
        $t0 = [gettimeofday()];
        $search_id = addSearchEntry($data{parameters},
          $search_batch_id,$msms_spectrum_id);
        $t1 = [gettimeofday()];
        $timepoints{'D #addSearchEntry'} += tv_interval($t0,$t1);

        #### If a valid search_id was returned, insert the hits
        if ($search_id > 0) {

          #### Insert the entries into table "search_hit"
				  $t0 = [gettimeofday()];
          $search_hit_id = addSearchHitEntry($data{matches},$search_id);
				  $t1 = [gettimeofday()];
				  $timepoints{'E #addSearchHitEntry'} += tv_interval($t0,$t1);

          #print "Successfully loaded $file_root (mass = $mass)\n";
          print ".";

        }

        $filecounter++;

				if ($use_batch_transactions && !$TESTONLY && ($filecounter%10 == 0)) {
					 print "#";
				  $sbeams->commit_transaction();
					$sbeams->initiate_transaction();
				}

      }


      #exit if ($filecounter > 2);


    } ## endwhile

    if ($use_batch_transactions && !$TESTONLY) {
      print "#reset";
      $sbeams->reset_dbh();
      $sbeams->commit_transaction();
      $sbeams->setAutoCommit(1);
      print "*************\n";
    }
    print "\nFound $filecounter .out files to process\n";
    $total_files += $filecounter;

  } ## endforeach
  #### Store timepoint
  $timepoints{t2} = [gettimeofday()];
  showTimeStatus(total_files=>$total_files);

} # end handleRequest



###############################################################################
# showTimeStatus - Show the timing information about the loading
###############################################################################
sub showTimeStatus {
  my %args = @_;
  my $SUB_NAME = 'showTimeStatus';

  my $total_files = $args{'total_files'};

  if (!defined($total_files)) {
    die "ERROR[$SUB_NAME]:total_files not passed";
  }
  $total_files = -1 unless ($total_files);


  printf("%10.2fs Startup time\n",tv_interval($timepoints{t0},$timepoints{t1}));
  printf("%10.2fs Load time\n",tv_interval($timepoints{t1},$timepoints{t2}));
  my $accum = 0;
  foreach my $key ( sort(keys(%timepoints)) ) {
    unless ($key =~ /t\d/) {
      printf("%10.2fs $key\n",$timepoints{$key});
      unless ($key =~ / \-\d /) {
	$accum += $timepoints{$key}
      }
    }
  }
  printf("%10.2fs other time\n",tv_interval($timepoints{t1},$timepoints{t2}) - $accum);
  printf("%10.2f hours per 100,000 .outs\n",
	 tv_interval($timepoints{t0},$timepoints{t2})/$total_files*100000/60/60);

  return;

}


###############################################################################
# loadProteomicsExperimentFromPepXML - load experiment for single pepXML
###############################################################################
sub loadProteomicsExperimentFromPepXML {
  my %args = @_;
  my $SUB_NAME = 'loadProteomicsExperimentFromPepXML';


  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_file not passed";


  #### Set the command-line options
  my $check_status = $OPTIONS{"check_status"};
  my $file_prefix = $OPTIONS{"file_prefix"} || '';
  my $force_ref_db = $OPTIONS{'force_ref_db'};


  #### Verify that the source directory looks right
  unless ( -d "$source_dir" ) {
    die("ERROR: '$source_dir' is not a directory!\n");
  }


  #### Try to find if this setname already exists in database
  my $sql="SELECT experiment_id ".
      "FROM $TBPR_PROTEOMICS_EXPERIMENT ".
      "WHERE experiment_tag = '$experiment_tag'";
  my ($experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Find the pepXML file to load from
  my $infile;
  if ($OPTIONS{interact_fname}) {
    $infile = "$source_dir/$OPTIONS{interact_fname}";
    unless ( -f $infile ) {
      die("ERROR: Unable to find specified input file '$infile'");
    }
  } else {
    my @potential_xml_files = (
      "$source_dir/interact-ipro.pep.xml",
      "$source_dir/interact-prob.xml",
      "$source_dir/interact.xml",
    );
    foreach my $potential_xml_file ( @potential_xml_files ) {
      if ( -f $potential_xml_file ) {
      	$infile = $potential_xml_file;
      	last;
      }
    }
  }

  unless ($infile) {
    die("ERROR: Unable to find a suitable pepXML file to load from");
  }


  print "INFO: Loading from $infile\n";
  use SBEAMS::Proteomics::PepXMLLoader;

  my $pepXMLLoader = new SBEAMS::Proteomics::PepXMLLoader;
  my $result = $pepXMLLoader->loadExperimentFromPepXMLFile(
    experiment_id=>$experiment_id,
    search_directory=>$source_dir,
    source_file => $infile,
    verbose=>$VERBOSE,
  );

  return 1;

}


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
  $t0 = [gettimeofday()];
  my $result;
  if (-e $inputfile) {
    $result = $sbeamsPROT->readDtaFile(inputfile => "$inputfile");
    unless ($result) {
      die "ERROR: Unable to read dta file '$inputfile'\n";
    }
  } else {
    if ($inputfile =~ m#(.+)/(.+?)/(.+)\.(\d+)\.(\d+)\.(\d)\.dta#) {
      #print "--$1--$2--$3--$4--$5--$6--\n";
      my $search_batch_path = $1;
      my $msrun_name = $2;
      my $start_scan = $4;
      my $end_scan = $5;
      my $charge = $6;
      my $mzXML_filename = "$search_batch_path/$msrun_name.mzXML";
      my $buffer = "INFO: Looking for '$mzXML_filename'<BR>\n";
      if ( -e $mzXML_filename ) {
      	$buffer .= "INFO: Found '$mzXML_filename'<BR>\n";
      	$buffer .= "INFO: Spectrum number is $start_scan<BR>\n";
       	my $filename = "$PHYSICAL_BASE_DIR/lib/c/Proteomics/getSpectrum/".
        "getSpectrum $start_scan $mzXML_filename |";
      	unless (open(DTAFILE,$filename)) {
    	    $buffer .= "ERROR Cannot open '$filename'!!<BR>\n";
    	    print $buffer;
	        return;
    	  } 
    	  my @mz_intensities;
    	  while (my $line = <DTAFILE>) {
	        chomp($line);
  	      my @values = split(/\s+/,$line);
    	    push(@mz_intensities,\@values);
	      }
				close(DTAFILE);
				$result->{parameters}->{file_root} = "$msrun_name.$start_scan.$end_scan";
				$result->{parameters}->{start_scan} = $start_scan;
				$result->{parameters}->{end_scan} = $end_scan;
				$result->{parameters}->{n_peaks} = scalar(@mz_intensities);
				$result->{mass_intensities} = \@mz_intensities;

				$buffer .= "file_root=$msrun_name\n";
				$buffer .= "start_scan=$start_scan, end_scan=$end_scan\n";
				$buffer .= "n_peaks=".scalar(@mz_intensities)."\n";
				print $buffer if ($VERBOSE > 1);

    } else {
    	die("ERROR: Unable to find $inputfile or mzXML_filename");
    }
  } else {
      die "ERROR: Unable to read dta file '$inputfile'\n";
  }

}

  my $file_root = ${$result}{parameters}->{file_root};
  $t1 = [gettimeofday()];
  $timepoints{'B -1  readDtaFile'} += tv_interval($t0,$t1);


  #### Try to find if this file_root already exists for this fraction_id
  $t0 = [gettimeofday()];
  my $msms_spectrum_id;
  our %msms_spectrum_id_hash;
  if ($msms_spectrum_id_hash{'====='.$fraction_id}) {
    if ($msms_spectrum_id_hash{$file_root}) {
      $msms_spectrum_id = $msms_spectrum_id_hash{$file_root};
    }
  } else {
    my $sql_query;
    $sql_query = qq~
      SELECT msms_spectrum_file_root,msms_spectrum_id
        FROM $TBPR_MSMS_SPECTRUM
       WHERE fraction_id = '$fraction_id'
    ~;
    %msms_spectrum_id_hash = $sbeams->selectTwoColumnHash($sql_query);
    $msms_spectrum_id_hash{'====='.$fraction_id} = 1;
  }
  $t1 = [gettimeofday()];
  $timepoints{'B -2  SQL find msms_spectrum_id'} += tv_interval($t0,$t1);

  #### If it is found, then return the key
  if ($msms_spectrum_id) {
    #print "Already found ($msms_spectrum_id)!  No need to reload\n";
    #print "($msms_spectrum_id)";
    return $msms_spectrum_id;

  #### Otherwise, extract some more info and build a statement to INSERT
  } else {
    my $start_scan = ${$result}{parameters}->{start_scan};
    my $end_scan = ${$result}{parameters}->{end_scan};
    my $n_peaks = ${$result}{parameters}->{n_peaks};

    $t0 = [gettimeofday()];
    my %rowdata;
    $rowdata{fraction_id} = $fraction_id;
    $rowdata{msms_spectrum_file_root} = $file_root;
    $rowdata{start_scan} = $start_scan;
    $rowdata{end_scan} = $end_scan;
    $rowdata{n_peaks} = $n_peaks;
    $msms_spectrum_id = $sbeams->insert_update_row(
      insert=>1,
      table_name=>$TBPR_MSMS_SPECTRUM,
      rowdata_ref=>\%rowdata,
      PK=>'msms_spectrum_id',
      return_PK=>1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

    #### Verify that we got the autogen key that was just INSERTed
    unless ($msms_spectrum_id) {
      die "ERROR: Failed to retreive PK msms_spectrum_id\n";
    }
    $msms_spectrum_id_hash{$file_root} = $msms_spectrum_id;
    $t1 = [gettimeofday()];
    $timepoints{'B -3  INSERT msms_spectrum'} += tv_interval($t0,$t1);
  }


  #### Now insert all the mass,intensity pairs
  $t0 = [gettimeofday()];
  my ($i,$mass,$intensity);


  #### Define flag to control where spectra will be written, default is TABLE
  my $spectrum_destination = 'TABLE';

  #### But can override in SBEAMS.conf file to skip writing
  if (defined($CONFIG_SETTING{Proteomics_SPECTRUM_DESTINATION}) &&
      $CONFIG_SETTING{Proteomics_SPECTRUM_DESTINATION} eq 'SKIP') {
    $spectrum_destination = 'SKIP';
    $spectra_written{$msms_spectrum_id} = 1;
    print "-";
    return $msms_spectrum_id;
  }

  #### Or provide a path name
  if (defined($CONFIG_SETTING{Proteomics_SPECTRUM_DESTINATION}) &&
      $CONFIG_SETTING{Proteomics_SPECTRUM_DESTINATION} =~ /!(SKIP|TABLE)/) {
    $spectrum_destination = 'FILE';
  }

  #### If we are writing the spectra to a file, open the default file
  if ($spectrum_destination eq 'FILE') {
    return $msms_spectrum_id if (defined($spectra_written{$msms_spectrum_id}));
    open(SPECFILE,">>".$CONFIG_SETTING{Proteomics_SPECTRUM_DESTINATION});
    $spectra_written{$msms_spectrum_id} = 1;
  }

  for ($i=0; $i<${$result}{parameters}->{n_peaks}; $i++) {
    $mass = ${$result}{mass_intensities}->[$i]->[0];
    $intensity = ${$result}{mass_intensities}->[$i]->[1];
    if ($spectrum_destination eq 'FILE') {
      print SPECFILE "$msms_spectrum_id\t$mass\t$intensity\r\n";
    } else {

      my %rowdata;
      $rowdata{msms_spectrum_id} = $msms_spectrum_id;
      $rowdata{mass} = $mass;
      $rowdata{intensity} = $intensity;
      $sbeams->insert_update_row(
    	insert=>1,
    	table_name=>$TBPR_MSMS_SPECTRUM_PEAK,
    	rowdata_ref=>\%rowdata,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
      );

    }

  }

  close SPECFILE if ($spectrum_destination eq 'FILE');
  $t1 = [gettimeofday()];
  $timepoints{'B -4  Store peaks'} += tv_interval($t0,$t1);

  return $msms_spectrum_id;

}



###############################################################################
# addSearchBatchEntry: find or make a new entry in search_batch table
###############################################################################
sub addSearchBatchEntry {
  my %args = @_;
  my $SUB_NAME = 'addSearchBatchEntry';


  #### Decode the argument list
  my $experiment_id = $args{'experiment_id'}
   || die "ERROR[$SUB_NAME]: experiment_id not passed";
  my $search_database = $args{'search_database'}
   || die "ERROR[$SUB_NAME]: search_database not passed";
  my $search_directory = $args{'search_directory'}
   || die "ERROR[$SUB_NAME]: search_directory not passed";
  my $fraction_directory = $args{'fraction_directory'}
   || die "ERROR[$SUB_NAME]: fraction_directory not passed";


  my $sql_query;

  #### Determinte the search_batch_subdir as the last item on the directory
  $search_directory =~ /.+\/(.+)/;
  my $search_batch_subdir = $1;


  #### Find the biosequence_set_id for the supplied $search_database
  $sql_query = qq~
      SELECT biosequence_set_id
        FROM $TBPR_BIOSEQUENCE_SET
       WHERE set_path = '$search_database'
         AND record_status != 'D'
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
         AND search_batch_subdir = '$search_batch_subdir'
  ~;
  my @search_batch_ids = $sbeams->selectOneColumn($sql_query);
  my $search_batch_id;


  #### If not, create one
  if (! @search_batch_ids) {
    print "INFO: Need to add a search_batch for these data\n";

    my %rowdata;
    $rowdata{experiment_id} = $experiment_id;
    $rowdata{biosequence_set_id} = $biosequence_set_id;
    $rowdata{data_location} = $search_directory;
    $rowdata{search_batch_subdir} = $search_batch_subdir;
    $search_batch_id = $sbeams->insert_update_row(
  	insert=>1,
  	table_name=>$TBPR_SEARCH_BATCH,
  	rowdata_ref=>\%rowdata,
        PK=>'search_batch_id',
        return_PK=>1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    unless ($search_batch_id) {
      die "ERROR: Failed to retreive PK search_batch_id\n";
    }


    #### Read in the sequest.params file in the same subdirectory
    #### and store its contents
    #### TODO: Load Mascot search analogue
    unless (addParamsEntries($search_batch_id,$fraction_directory)) {
      #die "ERROR: addParamsEntries failed.\n";
      print "WARNING: addParamsEntries failed. Will continue anyway\n";
    }


  #### If there's exactly one, the that's what we want
  } elsif (scalar(@search_batch_ids) == 1) {
    print "INFO: The search_batch that would be loaded is already ".
      "in the database\n";
    $search_batch_id = $search_batch_ids[0];

  #### If there's more than one, we have a big problem
  } elsif (scalar(@search_batch_ids) > 1) {
    die "ERROR: Found too many records for\n$sql_query\n";
  }


  return $search_batch_id;

}

sub updateExperimentTag{
  my %args = @_;
  my $SUB_NAME = 'updateExperimentTag';
  my $experiment_tag_list_file = $args{experiment_tag_list_file} || die "ERROR[$SUB_NAME]: experiment_tag_list_file not passed";
  ## get search_batch ids
  open (IN, "<$experiment_tag_list_file" ) or die "cannot open $experiment_tag_list_file\n";
  foreach my $line (<IN>){
    chomp $line;
    next if ($line =~ /^#/);
    next if ($line =~ /^$/);
    my ($search_batch_id, $tag) = split("\t", $line);
    my $sql_query = qq~
      SELECT PE.experiment_id, PE.experiment_tag,S.sample_id, S.sample_tag
      FROM $TBPR_PROTEOMICS_EXPERIMENT PE
      JOIN  $TBPR_SEARCH_BATCH SB ON (PE.EXPERIMENT_ID = SB.EXPERIMENT_ID)
      LEFT JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON ( ASB.PROTEOMICS_SEARCH_BATCH_ID  = SB.SEARCH_BATCH_ID)
      JOIN $TBAT_SAMPLE S ON (S.sample_id = ASB.sample_id)
      WHERE SB.search_batch_id = $search_batch_id
    ~;
    my @results = $sbeams->selectSeveralColumns ($sql_query);
		foreach my $row(@results){
	    my ($exp_id, $exp_tag, $sample_id, $sample_tag) = @$row;
     if ( $exp_id && $exp_tag ne $tag ) {
        print "experiment_id=$exp_id experiment_tag=$exp_tag\tnew_tag='$tag'\n";    
        my %rowdata=();
        $rowdata{experiment_tag} = $tag;
				my $success = $sbeams->insert_update_row(
						update=>1,
						table_name=>$TBPR_PROTEOMICS_EXPERIMENT,
						rowdata_ref=>\%rowdata,
						PK=>'experiment_id',
						PK_value=>$exp_id,
						verbose=>$VERBOSE,
						testonly=>$TESTONLY,
				);
      }
      if ($sample_id && $sample_tag ne  $tag ) {
        print "sample_id=$sample_id\tsample_tag=$sample_tag\tnew_tag='$tag'\n";    
        my %rowdata=();
        $rowdata{sample_tag} = $tag;
        my $success = $sbeams->insert_update_row(
            update=>1,
            table_name=>$TBAT_SAMPLE,
            rowdata_ref=>\%rowdata,
            PK=>'sample_id',
            PK_value=>$sample_id,
            verbose=>$VERBOSE,
            testonly=>$TESTONLY,
        );

      }
		}
  }
}

###############################################################################
#update search_batch data_location
###############################################################################
sub updateDataLocation_list{
  my %args = @_;
  my $SUB_NAME = 'updateDataLocation';
  my $experiment_list_file = $args{experiment_list_file} || die "ERROR[$SUB_NAME]: experiment_list_file not passed";
  ## get search_batch ids
  open (IN, "<$experiment_list_file" ) or die "cannot open $experiment_list_file\n";
  foreach my $line (<IN>){
    chomp $line;
    next if ($line =~ /^#/);
    next if ($line =~ /^$/);
    my ($search_batch_id, $data_loc) = split("\t", $line);
    my $experiment_path = $data_loc;
    $data_loc =~ s/\/{0,}$//;
    $data_loc =~ /.*archive\/(.*)\/.*/; 
    $experiment_path = $1;
    print "$line\nupdate\n";
    my $sql_query = qq~
      SELECT PE.experiment_id, PE.experiment_path
      FROM $TBPR_PROTEOMICS_EXPERIMENT PE
      JOIN  $TBPR_SEARCH_BATCH SB ON (PE.EXPERIMENT_ID = SB.EXPERIMENT_ID)
      WHERE SB.search_batch_id = $search_batch_id
    ~;
    my @results = $sbeams->selectSeveralColumns ($sql_query);
    my %rowdata=();
		foreach my $row(@results){
	    my ($exp_id, $exp_path) = @$row;
      if ($exp_path ne $experiment_path ) {
        print "\t$exp_path ->\t$experiment_path\n";
        $rowdata{experiment_path} = $experiment_path;
				my $success = $sbeams->insert_update_row(
						update=>1,
						table_name=>$TBPR_PROTEOMICS_EXPERIMENT,
						rowdata_ref=>\%rowdata,
						PK=>'experiment_id',
						PK_value=>$exp_id,
						verbose=>$VERBOSE,
						testonly=>$TESTONLY,
				);
        updateDataLocation(experiment_id=>$exp_id);
      }
		}
  }
}

###############################################################################
#update search_batch data_location
###############################################################################
sub updateDataLocation{
  my %args = @_;
  my $SUB_NAME = 'updateDataLocation';
  my $experiment_id = $args{experiment_id} || die "ERROR[$SUB_NAME]: experiment_id  not passed"; 
  ## get search_batch ids
  my $sql_query = qq~
      SELECT PE.experiment_id, PE.experiment_path, SB.search_batch_id, SB.data_location, ASB.atlas_search_batch_id, ASB.data_location
      FROM $TBPR_PROTEOMICS_EXPERIMENT PE
      JOIN  $TBPR_SEARCH_BATCH SB ON (PE.EXPERIMENT_ID = SB.EXPERIMENT_ID)
      LEFT JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON ( ASB.PROTEOMICS_SEARCH_BATCH_ID  = SB.SEARCH_BATCH_ID)
      WHERE PE.experiment_id = '$experiment_id'
   ~;
  my @results = $sbeams->selectSeveralColumns ($sql_query);
  my %rowdata=();
  foreach my $row(@results){
    my ($exp_id, $exp_path, $sb_id, $sb_data_location,$asb_id, $asb_data_location)=@$row;
    if ($exp_path !~ /^\/regis/){
      $exp_path = "/regis/sbeams/archive/$exp_path";
    }
    print "PE.experiment_id=$exp_id\n";
    if ($exp_path ne $sb_data_location){
      print "experiment_path=$exp_path != search_batch data_location=$sb_data_location\n";
      print "set search_batch $sb_id data_location=$exp_path\n\n";
      $rowdata{data_location} = $exp_path;
			my $success = $sbeams->insert_update_row(
					update=>1,
					table_name=>$TBPR_SEARCH_BATCH,
					rowdata_ref=>\%rowdata,
					PK=>'search_batch_id',
					PK_value=>$sb_id,
					verbose=>$VERBOSE,
					testonly=>$TESTONLY,
			)
    }else{
       print "experiment_path=$exp_path == search_batch data_location=$sb_data_location\n";
       print "no update\n\n";
    }
    if ($asb_id && ($exp_path ne $asb_data_location)){
       print "experiment_path=$exp_path != atlas_search_batch data_location=$asb_data_location\n";
       print "set atlas_search_batch $asb_id data_location=$exp_path\n\n";
       $rowdata{data_location} = $exp_path;
       my $success = $sbeams->insert_update_row(
          update=>1,
          table_name=>$TBAT_ATLAS_SEARCH_BATCH,
          rowdata_ref=>\%rowdata,
          PK=>'atlas_search_batch_id',
          PK_value=>$asb_id,
          verbose=>$VERBOSE,
          testonly=>$TESTONLY,
      );
    }else{
      print "experiment_path=$exp_path == atlas_search_batch data_location=$asb_data_location\n";
      print "no update\n\n";
    }
  
  }


}

###############################################################################
# getMsrunId: Get the msrun_id == fraction_id is it exists
###############################################################################
sub getMsrunId {
  my %args = @_;
  my $SUB_NAME = 'getMsrunId';

  #### Decode the argument list
  my $experiment_id = $args{'experiment_id'}
   || die "ERROR[$SUB_NAME]: experiment_id not passed";
  my $fraction_tag = $args{'fraction_tag'}
   || die "ERROR[$SUB_NAME]: fraction_tag not passed";

  #### Determine how many fractions respond to this name
  my $sql="SELECT fraction_id\n".
         "  FROM $TBPR_FRACTION\n".
         " WHERE experiment_id = $experiment_id\n".
         "   AND fraction_tag = '$fraction_tag'";
  my @returned_fraction_ids = $sbeams->selectOneColumn($sql);

  if (! @returned_fraction_ids) {
    return;
  } elsif (scalar(@returned_fraction_ids) == 1) {
    print "Fraction '$fraction_tag' already exists in the database\n";
    return($returned_fraction_ids[0]);
  } else {
    my $tmp = scalar(@returned_fraction_ids);
    die("ERROR: Found $tmp records for $fraction_tag already!");
  }

} # end getMsrunId



###############################################################################
# addMsrunEntry: Insert a new entry in fraction table
###############################################################################
sub addMsrunEntry {
  my %args = @_;
  my $SUB_NAME = 'addMsrunEntry';

  #### Decode the argument list
  my $experiment_id = $args{'experiment_id'}
   || die "ERROR[$SUB_NAME]: experiment_id not passed";
  my $fraction_tag = $args{'fraction_tag'}
   || die "ERROR[$SUB_NAME]: fraction_tag not passed";

  #### Caculate a fraction number
  my $fraction_number;

  #### If it looks like a 96 well plate ID, turn into number
  if ($fraction_tag =~ /^([A-H])(\d{1,2})$/ && $2 <= 12) {
    my $letter = $1;
    my $number = $2;
    $letter =~ tr/A-H/1-8/;
    $fraction_number = ($number - 1) * 8 + $letter;

  #### Else just pull out a number
  } elsif ($fraction_tag =~ /^.*?(\d+).*?$/) {
    $fraction_number = $1;
    # Guard against numbers too big
    $fraction_number = substr($fraction_number,0,8);
  }


  my %rowdata;
  $rowdata{experiment_id} = $experiment_id;
  $rowdata{fraction_tag} = $fraction_tag;
  $rowdata{fraction_number} = $fraction_number;
  my $fraction_id = $sbeams->insert_update_row(
    insert=>1,
    table_name=>$TBPR_FRACTION,
    rowdata_ref=>\%rowdata,
    PK_name=>'fraction_id',
    return_PK=>1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  return($fraction_id);
}



###############################################################################
# addSearchEntry: Insert a new entry in search table;  does not add probabilities
###############################################################################
sub addSearchEntry {
  my ($parameters_ref) = shift
    || die "ERROR addSearchBatch: missing parameter 1: parameters_ref\n";
  my ($search_batch_id) = shift
    || die "ERROR addSearchBatch: missing parameter 2: search_batch_id\n";
  my ($msms_spectrum_id) = shift
    || die "ERROR addSearchBatch: missing parameter 3: msms_spectrum_id\n";


  #### Verify that this search isn't already in the database
  #### This is a lot of work for the server, so could be disabled
  #### If a UNIQUE key is put in place to insure a crash here
  my $file_root = $parameters_ref->{file_root};
  if (1 == 1) {
    my $sql = qq~
      SELECT search_id
        FROM $TBPR_SEARCH
       WHERE search_batch_id = '$search_batch_id'
         AND msms_spectrum_id = '$msms_spectrum_id'
         AND file_root = '$file_root'
    ~;
    my ($result) = $sbeams->selectOneColumn($sql);
    if ($result) {
      print "INFO: This search is already in the database as id '$result'\n";
      return -1;
    }
  }


  #### Define the data columns for table "search"
  my @columns = ( "file_root","start_scan","end_scan",
    "sample_mass_plus_H","assumed_charge","total_intensity",
    "matched_peptides","lowest_prelim_score",
    "search_date","search_elapsed_min","search_host" );


  #### Define the data for this row
  my ($element,$tmp);
  my %rowdata;
  $rowdata{search_batch_id} = $search_batch_id;
  $rowdata{msms_spectrum_id} = $msms_spectrum_id;


  #### Add each of the columns
  foreach $element (@columns) {
    $rowdata{$element} = $parameters_ref->{$element};
  }


  #### INSERT the search row
  my $search_id = $sbeams->insert_update_row(
    insert=>1,
    table_name=>$TBPR_SEARCH,
    rowdata_ref=>\%rowdata,
    PK=>'search_id',
    return_PK=>1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  #### Verify successful INSERT
  die("ERROR: Failed to retreive PK search_id ".
    "(got $search_id)") unless ($search_id);

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


  #### Define the data columns for table search_hit
  my @columns = ( "hit_index","cross_corr_rank","prelim_score_rank",
    "hit_mass_plus_H","mass_delta","cross_corr","norm_corr_delta",
    "prelim_score",
    "identified_ions","total_ions","reference","additional_proteins",
    "peptide","peptide_string" );


  #### Pull out the array of rows
  my @matches = @{$matches_ref};


  #### Print a warning and return if there are no rows
  unless (@matches) {
    print "WARNING: Apparently no matches for this search\n";
    return 1;
  }


  #### Define some variables
  my ($match,$element,$tmp,$i,$last_cols);
  my $n_matches = scalar(@matches);

  #### Limit the number of top hits to load.  This should probably be
  #### a command line option rather than hard coded or a conf option
  my $max_matches = 10;
  if (defined($CONFIG_SETTING{Proteomics_MAX_TOP_HITS_TO_LOAD})) {
    $max_matches = $CONFIG_SETTING{Proteomics_MAX_TOP_HITS_TO_LOAD};
  }
  if ($n_matches > $max_matches) {
    $n_matches = $max_matches;
    print "<";
  }


  #### Loop over each row
  for ($i=0; $i<$n_matches; $i++) {
    $match = $matches[$i];

    #### Define the data to be inserted for this row
    my %rowdata;
    $rowdata{search_id} = $search_id; 
    foreach $element (@columns) {
      $rowdata{$element} = $match->{$element};
    }


    #### if the fix_ipi option was set, try to fix the IPI numbers
    #### From something like 'IPI:IPI00173559.1|REFSEQ_XP:XP_210301|EN'
    #### To just 'IPI00173559'
    if ($OPTIONS{'fix_ipi'}) {
      my $tmp = $rowdata{reference};
      if ($rowdata{reference} =~ /(IPI\d+)/) {
	$rowdata{reference} = $1;
      }
    }


    #### If there are more rows, then add the dCn to next row
    $last_cols = "";
    if (($i+1) < $n_matches) {
      $rowdata{next_dCn} = $matches[$i+1]->{norm_corr_delta} - 
        $match->{norm_corr_delta};
    }

    #### If this is the first row, then label it with best_hit_flag
    if ($i == 0) {
      $rowdata{best_hit_flag} = 'D'; 
    }

    #### If there's a search_hit_proteins element present, then set
    #### return_PK flag in preparation for adding the additional proteins
    my $return_PK = 0;
    $return_PK = 1 if (defined($match->{search_hit_proteins}));

    #### INSERT the search_hit row
    my $search_hit_id = $sbeams->insert_update_row(
      insert=>1,
      table_name=>$TBPR_SEARCH_HIT,
      rowdata_ref=>\%rowdata,
      PK=>'search_hit_id',
      return_PK=>$return_PK,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

    #### Verify success
    die "Unable to insert into $TBPR_SEARCH_HIT" unless ($search_hit_id);

    #### If there are additional proteins, insert those
    if (defined($match->{search_hit_proteins})) {
      %rowdata = ();
      $rowdata{search_hit_id} = $search_hit_id;
      foreach $element (@{$match->{search_hit_proteins}}) {
        $rowdata{reference} = $element;
        $sbeams->insert_update_row(
  	  insert=>1,
  	  table_name=>$TBPR_SEARCH_HIT_PROTEIN,
  	  rowdata_ref=>\%rowdata,
          verbose=>$VERBOSE,
          testonly=>$TESTONLY,
  	);

      }

    }


  } # endfor


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


  print "INFO: Searching for search parameter information...\n";
  my $result;

  #### Make a list of guesses for params files
  my @params_files = ( "$directory/sequest.params",
    "$directory/../sequest.params", "$directory/comet.def",
    "$directory/tandem.params", "$directory/tandem.xml",
    "$directory/spectrast.params",
  );

  #### Try to find the files in order
  my $found;
  foreach my $file ( @params_files ) {
    print "  Looking for $file...";
    if ( -e $file ) {
      print "found!\n";
      $found = $file;
      last;
    } else {
      print "no\n";
    }
  }


  #### Since there's a move to not have parameter files, try to fake it
  unless ($found) {

    #### Make a list of guesses for filenames
    my @pepXML_files = ( "$directory/interact-prob.xml",
      "$directory/interact.xml",
    );

    #### Try to find the files in order
    foreach my $file ( @pepXML_files ) {
      print "  Looking for $file...";
      if ( -e $file ) {
	print "found!\n";
	$found = $file;
	last;
      } else {
	print "no\n";
      }
    }

    if (open(INFILE,$found)) {
      my $line;
      my $search_engine;
      while ($line = <INFILE>) {
	if ($line =~ /search_engine=\"(\w+)\"/) {
	  $search_engine = $1;
	  last;
	}
      }
      if ($search_engine && $search_engine eq 'PHENYX') {
	my @tmp = ( 'search_engine_name' );
	$result->{keys_in_order} = \@tmp;
	$result->{parameters}->{search_engine_name} = $search_engine;
	print "  Search engine is $search_engine with no parameters available. Unfortunate but proceeding.\n";
      }
      close(INFILE);
    }
  }

  unless ($found) {
    print "WARNING: Unable to find any search engine parameter file\n";
    return;
  }


  #### Read in the search parameters file
  my $file = $found;

  unless ($result) {
    $result = $sbeamsPROT->readParamsFile(inputfile => "$file");
  }

  unless ($result) {
    print "ERROR: Unable to read sequest parameter file: '$file'\n";
    return;
  }


  #### Loop over each row
  my ($key,$value,$tmp);
  my $counter = 0;
  foreach $key (@{${$result}{keys_in_order}}) {

    #### Define the data for this row
    my %rowdata;
    $rowdata{search_batch_id} = $search_batch_id;
    $rowdata{key_order} = $counter;
    $rowdata{parameter_key} = $key;
    $rowdata{parameter_value} = ${$result}{parameters}->{$key};

    #### INSERT it
    $sbeams->insert_update_row(
	insert=>1,
	table_name=>$TBPR_SEARCH_BATCH_PARAMETER,
	rowdata_ref=>\%rowdata,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );

    $counter++;

  }


  return 1;

}



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
# updateFromSummaryFiles
###############################################################################
sub updateFromSummaryFiles {
  my %args = @_;
  my $SUB_NAME = 'updateFromSummaryFile';


  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $search_batch_subdir = $args{'search_batch_subdir'}
   || die "ERROR[$SUB_NAME]: search_batch_subdir not passed";
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_dir not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Set the command-line options
  my $file_prefix = $OPTIONS{"file_prefix"} || '';


  #### Verify that the source directory looks right
  unless ( -d "$source_dir" ) {
    die("ERROR: '$source_dir' is not a directory!\n");
  }

  unless ( -f "$source_dir/interact.htm" ||
           -f "$source_dir/interact.xml" ||
           -f "$source_dir/interact-prob.xml" ||
           -f "$source_dir/sequest.params" ||
	   -f "$source_dir/interact-prob.pep.xml" ||
           -f "$source_dir/interact-combined.pep.xml" ||
           -f "$source_dir/finalInteract/interact.htm" ||
           -f "$source_dir/interact-prob-data.htm"
  ) {
    die("ERROR: '$source_dir' just doesn't look like a sequest search ".
        "directory");
  }


  #### Try to find this experiment in database
  $sql="SELECT experiment_id ".
      "FROM $TBPR_PROTEOMICS_EXPERIMENT ".
      "WHERE experiment_tag = '$experiment_tag'";
  my ($experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Try to find this search_batch_id in database
  $sql = qq~
    SELECT search_batch_id
      FROM $TBPR_SEARCH_BATCH
     WHERE experiment_id = '$experiment_id'
       AND search_batch_subdir = '$search_batch_subdir'
  ~;
  my ($search_batch_id) = $sbeams->selectOneColumn($sql);
  unless ($search_batch_id) {
    print "\nERROR: Unable to find search_batch '$search_batch_subdir'.\n".
          "       This search_batch must already exist in the database\n\n";
    return;
  }



  #### Get the fractions for this experiment
  $sql = qq~
          SELECT fraction_id,fraction_tag
            FROM $TBPR_FRACTION F
           WHERE F.experiment_id = '$experiment_id'
  ~;
  my @fractions = $sbeams->selectSeveralColumns($sql);
  unless (@fractions) {
    die "Unable to find any fractions for this experiment.  Cannot update.\n";
  }


  #### Loop over all fractions, doing the updates
  my ($fraction,$fraction_id,$fraction_tag);
  foreach $fraction (@fractions) {
    $fraction_id = $fraction->[0];
    $fraction_tag = $fraction->[1];

    my $source_file = "$source_dir/$fraction_tag.html";

    print "Updating fraction $fraction_tag";
    my $data_ref = $sbeamsPROT->readSummaryFile(inputfile=>$source_file,
      verbose=>$VERBOSE);


    #### Loop over each row
    my ($key2,$value2,$file_root);
    while ( ($key,$value) = each %{$data_ref->{files}} ) {

      $file_root = $key;
      $file_root =~ s/\.out$//;

      #### Find the corresponding search_hit_id in table search_hit
      #### Can this be put outside, the loop, it would be a big speed
      #### improvement
      #### On the other hand, it would be nice to be able to UPDATE
      #### not just INSERT, so that will require some more thought FIXME
      $sql = qq~
	SELECT SH.search_hit_id,Q.quantitation_id
	  FROM $TBPR_SEARCH S
	  JOIN $TBPR_SEARCH_HIT SH ON ( S.search_id = SH.search_id )
          LEFT JOIN $TBPR_QUANTITATION Q ON (SH.search_hit_id=Q.search_hit_id)
	 WHERE search_batch_id = '$search_batch_id'
	   AND hit_index = 1
	   AND file_root = '$file_root'
      ~;
      my ($search_hit_id,$quantitation_id) =
        $sbeams->selectTwoColumnHash($sql);
      unless ($search_hit_id) {
        print "\nERROR: Unable to find search_hit_id with\n".
              "$sql\n\n";
        next;
      }

      #### If a quantitation_id also turned up, skip this one
      if ($quantitation_id) {
        print "INFO: There is already a quantitation record for $file_root ".
          "(search_hit_id $search_hit_id).  Skip.\n";
        next;
      }


      my %rowdata;
      $rowdata{search_hit_id} = $search_hit_id;
      while ( ($key2,$value2) = each %{$value} ) {
        $rowdata{$key2} = $value2;
      }

      #### INSERT it
      $sbeams->insert_update_row(
        insert=>1,
        table_name=>$TBPR_QUANTITATION,
        rowdata_ref=>\%rowdata,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
      );

      print ".";

    } # endwhile

    print "\n";

  } # end foreach

  return;

} # end updateFromSummaryFiles



###############################################################################
# updateProbabilities - this is the only subroutine which will load probabilities.
# If user has specified an interact_fname, will look for it and die if not
# found.
###############################################################################
sub updateProbabilities {
  my %args = @_;
  my $SUB_NAME = 'updateProbabilities';


  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $search_batch_subdir = $args{'search_batch_subdir'}
   || die "ERROR[$SUB_NAME]: search_batch_subdir not passed";
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_dir not passed";

  my $interact_file_path = $args{'full_interact_path'} || "";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Set the command-line options
  my $file_prefix = $OPTIONS{"file_prefix"} || '';


  #### Try to find this experiment in database
  $sql="SELECT experiment_id ".
      "FROM $TBPR_PROTEOMICS_EXPERIMENT ".
      "WHERE experiment_tag = '$experiment_tag'";
  my ($experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Try to find this search_batch_id in database
  $sql = qq~
    SELECT search_batch_id
      FROM $TBPR_SEARCH_BATCH
     WHERE experiment_id = '$experiment_id'
       AND search_batch_subdir = '$search_batch_subdir'
  ~;
  my ($search_batch_id) = $sbeams->selectOneColumn($sql);
  unless ($search_batch_id) {
    print "\nERROR: Unable to find search_batch '$search_batch_subdir'.\n".
          "       This search_batch must already exist in the database\n\n";
    return;
  }

  
  #### Read in the probabilities
  my $data_ref;

  ## determine interact file name and whether it's an htm or xml
  my $isXMLFile = "";

  my $isHTMFile = "";

  ## If user specified interact file name, check for it one more time, and die if not
  ## found.  This is repeat of section above...should clean one day
  if ( $interact_file_path )
  {

      if ( -e "$interact_file_path")
      {

          ##do nothing

      } else
      {

          die "File $interact_file_path not found. "
              . "Please check --interact_fname $interact_fname ";
      }

      if ($interact_file_path =~ /(.+)(xml)$/)
      {

          $isXMLFile = 1;

      } else
      {

          $isHTMFile = 1;

      }

  } 

  ## else, run through list of default interact file names
  ## and use one of those
  if ( !$interact_file_path )
  {
      my @potential_xml_files;

      push( @potential_xml_files, "$source_dir/interact-ipro.pep.xml" );
      push( @potential_xml_files, "$source_dir/interact-prob.xml" );

      push( @potential_xml_files, "$source_dir/interact.xml" );

      my $potential_htm_file = "$source_dir/interact-prob-data.htm";

      for (my $ii = 0; $ii <= $#potential_xml_files; $ii++)
      {
    
          if (-e $potential_xml_files[$ii] )
          {

              $interact_file_path =  $potential_xml_files[$ii];

              $isXMLFile = 1;

              last;

          }
          
      } ## end run through @potential_xml_files

      ## if still not found, try old pipeline product:
      if (-e $potential_htm_file)
      {

          $interact_file_path = $potential_htm_file;

          $isHTMFile = 1;

          $isXMLFile = "";

      }

  }

  ## if still no file found, tell user and die
  if (!$interact_file_path)
  {

      die "Can't find peptide interact file in $source_dir. "
      . "Please check, and if still problems, use file name flag "
      . "For example:  --interact_fname interact-prob.xml ";

  }

  print "attempting to load $interact_file_path\n";

  #### First guess an XML Interact file with probabilities
  if ($isXMLFile == 1) {
    print "Found XML interact file. " +
    "Reading probabilities from source file '$interact_file_path'\n";
    use SBEAMS::Proteomics::XMLUtilities;
    my $XMLreader = new SBEAMS::Proteomics::XMLUtilities;
    $data_ref = $XMLreader->readXInteractFile(
      source_file => $interact_file_path,
      verbose=>$VERBOSE,
    );

  #### Second, guess an HTML Interact file with probabilities
  } elsif ( $isHTMFile == 1 ) {
    print "Found HTM interact file. " +
    "Reading probabilities from source file '$interact_file_path'...\n";
    $data_ref = $sbeamsPROT->readSummaryFile(
      inputfile => $interact_file_path,
      verbose=>$VERBOSE
    );
  } else {
    die "!! UNABLE TO FIND INTERACT FILE (looking for $interact_file_path)";
  }


  #print $data_ref,"\n";
  #print $data_ref->{files},"\n";
  my @nfiles = keys(%{$data_ref->{files}});
  print "\n  nfiles = ".scalar(@nfiles)."\n";;
  print "\n  nfiles = ", $#nfiles + 1, "\n";;


  #### Get all the rank 1 search_hit_id's for this search_batch
  $sql = qq~
      SELECT file_root,search_hit_id
        FROM $TBPR_SEARCH S
        JOIN $TBPR_SEARCH_HIT SH ON ( S.search_id = SH.search_id )
       WHERE search_batch_id = '$search_batch_id'
         AND hit_index = 1
  ~;
  my %search_hit_ids = $sbeams->selectTwoColumnHash($sql);


  #### Loop over each row
  my ($key,$value,$tmp,$key2,$value2,$file_root);
  my %rowdata;
  my $search_hit_id;


  while ( ($key,$value) = each %{${$data_ref}{files}} ) {
    #print "$key = $value\n";
    $file_root = $key;
    $file_root =~ s/\.out$//;

    #### Hack
    #$file_root =~ s/raft52\./raft0052\./;
    #$file_root =~ s/raft20\./raft0020\./;


    #### Find the corresponding search_hit_id in table search_hit
    if (1 == 1) {
      $search_hit_id = $search_hit_ids{$file_root};
    } else {
      $sql = qq~
      SELECT search_hit_id
        FROM $TBPR_SEARCH S
        JOIN $TBPR_SEARCH_HIT SH ON ( S.search_id = SH.search_id )
       WHERE search_batch_id = '$search_batch_id'
         AND hit_index = 1
         AND file_root = '$file_root'
      ~;
      $search_hit_id = $sbeams->selectOneColumn($sql);
    }

    unless ($search_hit_id) {
      print "\nERROR: Unable to find search_hit_id with\n".
            "file_root '$file_root' using:$sql\n\n";
      next;
    }


    #### Update that data
    if (defined($value->{probability})) {
      %rowdata = ();
      $rowdata{probability} = $value->{probability};

      $result = $sbeams->insert_update_row(
        update=>1,
        table_name=>$TBPR_SEARCH_HIT,
        rowdata_ref=>\%rowdata,
	PK=>'search_hit_id',
        PK_value=>$search_hit_id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
        );

      print ".";

    }

  } # endwhile

  return;

} # end sub updateProbabilities



###############################################################################
# updateSearchResults
###############################################################################
sub updateSearchResults {
  my %args = @_;
  my $SUB_NAME = 'updateSearchResults';

  #### Set up use of some special stuff to calculate pI.
  #### This should probably be replaced with native Perl calculator
  #use lib "$FindBin::Bin/../../c/Proteomics/pICalculator/blib/lib";
  #use lib "$FindBin::Bin/../../c/Proteomics/pICalculator/blib/arch";
  #use pICalculator;


  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $search_batch_subdir = $args{'search_batch_subdir'}
   || die "ERROR[$SUB_NAME]: search_batch_subdir not passed";
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_dir not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Settings
  my $adjust_best_hits = 1;


  #### Set the command-line options
  my $file_prefix = $OPTIONS{"file_prefix"} || '';


  #### Try to find this experiment in database
  $sql="SELECT experiment_id ".
      "FROM $TBPR_PROTEOMICS_EXPERIMENT ".
      "WHERE experiment_tag = '$experiment_tag'";
  my ($experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Try to find this search_batch_id in database
  $sql = qq~
    SELECT search_batch_id
      FROM $TBPR_SEARCH_BATCH
     WHERE experiment_id = '$experiment_id'
       AND search_batch_subdir = '$search_batch_subdir'
  ~;
  my ($search_batch_id) = $sbeams->selectOneColumn($sql);
  unless ($search_batch_id) {
    print "\nERROR: Unable to find search_batch '$search_batch_subdir'.\n".
          "       This search_batch must already exist in the database\n\n";
    return;
  }


  #### Find the appropriate search_id's in the database
  $sql = "SELECT search_id ".
           "FROM $TBPR_SEARCH ".
          "WHERE search_batch_id = '$search_batch_id'";
  my @search_ids = $sbeams->selectOneColumn($sql);
  unless (@search_ids) {
    print "\nERROR: Unable to find search_batch_id '$search_batch_id'.\n".
          "       in the database.  It must already exist there\n\n";
    return;
  }


  print scalar(@search_ids)," search_id's found.\n";


  #### Set up for main loop
  my $counter = 0;
  my ($search_id,$nrows,@data,@newdata);
  my (@matches,$n_matches,$j,$n_proteins);
  print "Processing search_batch...\n";

  #### Loop over each search_id
  foreach $search_id (@search_ids) {

    ## Testing
    ##next unless ($search_id == 30234);

    #### Get the corresponding search_hit's
    $sql = qq~
	SELECT SH.*,file_root,SB.search_batch_id,SB.biosequence_set_id,
	       biosequence_name,BS.biosequence_id AS 'matched_biosequence_id'
	  FROM $TBPR_SEARCH_HIT SH
	  JOIN $TBPR_SEARCH S ON ( SH.search_id = S.search_id )
	  JOIN $TBPR_SEARCH_BATCH SB ON ( S.search_batch_id = SB.search_batch_id )
	  LEFT JOIN $TBPR_BIOSEQUENCE BS ON
	       ( SH.reference=BS.biosequence_name
	         AND SB.biosequence_set_id = BS.biosequence_set_id )
	 WHERE SH.search_id = '$search_id'
         ORDER BY SH.search_hit_id
    ~;

    @data = $sbeams->selectHashArray($sql);
    $nrows = @data;
    print "search_id = $search_id, got nrows = $nrows ".
      " ( $data[0]->{peptide_string} )\n"
      if ($VERBOSE);


    #### If query returned nothing, squawk and go to next search
    unless ($nrows) {
      print "WARNING: No rows returned for search_id = $search_id\n";
      next;
    }


    #### Reset the new data ref array
    @newdata = ();
    my ($peptide,$pI);


    #### Loop over each search_hit_id
    for ($i=0; $i<$nrows; $i++) {
      my %coldata;
      $coldata{search_hit_id} = $data[$i]->{search_hit_id};
      $coldata{best_hit_flag} = "";


      $peptide = $data[$i]->{peptide};

      #### Calculate pI (Isoelectric point)
      #### This should probably be replaced with native Perl calculator
      #$pI = pICalculator::COMPUTE_PI($peptide,length($peptide),0);
      #$coldata{isoelectric_point} = $pI;

      #### Calculate Gravy Score
      my $gravy_score = SBEAMS::Proteomics::Utilities::calcGravyScore(
        peptide=>$peptide);
      $coldata{gravy_score} = $gravy_score;


      #### Find additional proteins
      #### This is extremely computationally expensive
      if (0 == 1) {
  	my @output = `./findpept $data[$i]->{peptide} /net/db/projects/proteomics/dbase/drosophila/aa_gadfly.dros.RELEASE2`;
  	$n_proteins = @output;
  	for ($j=0; $j<$n_proteins; $j++) {
  	  chomp $output[$j];
  	  my %tmp_rowdata;
  	  $tmp_rowdata{search_hit_id} = $data[$i]->{search_hit_id};
  	  $tmp_rowdata{reference} = $output[$j];
  	  $result = $sbeams->insert_update_row(
	    table_name=>$TBPR_SEARCH_HIT_PROTEIN,
  	    insert=>1,rowdata_ref=>\%tmp_rowdata
  	    #,verbose=>1,testonly=>1
  	  );
  	}
  	#print "Other proteins: ",join(",",@output),"\n";
      }


      #### If the reference and biosequence_name don't match as they should
      if ($data[$i]->{reference} ne $data[$i]->{biosequence_name}) {

        #### if biosequence_name is not blank, this is very confusing and bad
        if ($data[$i]->{biosequence_name}) {
          print "  WARNING: reference and biosequence name don't match!\n";
          print "           reference[$i] = $data[$i]->{reference}\n";
          print "    biosequence_name[$i] = $data[$i]->{biosequence_name}\n";

        #### Since biosequence_name is blank, try to guess
        } else {

          #### If this is a SWx or GPx record, try the other combination
          my $prot = $data[$i]->{reference};
          if ($prot =~ /^(SW)(.{0,1})\:(.+)$/ || $prot =~ /^(GP)(.{0,1})\:(.+)$/) {
            my $src = $1;
            my $tag = $2;
            my $acc = $3;
            if ($tag eq 'N') {
              $tag = '';
            } else {
              $tag = 'N';
            }
            $prot = "$src$tag:$acc";
            $sql = qq~
		SELECT biosequence_id,biosequence_name
		  FROM $TBPR_BIOSEQUENCE BS
		 WHERE biosequence_set_id = '$data[$i]->{biosequence_set_id}'
		   AND biosequence_name = '$prot'
            ~;

          #### Otherwise if it's an old IPI, do a temporary fix.  REMOVE ME
          } elsif ($prot =~ /IPI:(IPI\d+)\.\d+/) {
            $prot = $1;
            $sql = qq~
		SELECT biosequence_id,biosequence_name
		  FROM $TBPR_BIOSEQUENCE BS
		 WHERE biosequence_set_id = '$data[$i]->{biosequence_set_id}'
		   AND biosequence_name = '$prot'
            ~;


          #### Otherwise if it's an IPI, do a temporary fix.  REMOVE ME
          } elsif ($prot =~ /IPI\d/) {
            #$prot = "IPI:$prot";
            $sql = qq~
		SELECT biosequence_id,biosequence_name
		  FROM $TBPR_BIOSEQUENCE BS
		 WHERE biosequence_set_id = '$data[$i]->{biosequence_set_id}'
		   AND biosequence_gene_name = '$prot'
            ~;


          #### Otherwise guess that it might be a truncated Reference?
          } else {
            $sql = qq~
		SELECT biosequence_id,biosequence_name,biosequence_seq
		  FROM $TBPR_BIOSEQUENCE BS
		 WHERE biosequence_set_id = '$data[$i]->{biosequence_set_id}'
		   AND biosequence_name LIKE '$data[$i]->{reference}\%'
            ~;
          }

          @matches = $sbeams->selectSeveralColumns($sql);
          $n_matches = @matches;

          #### If there is exactly one matching row, this is good
          if ($n_matches == 1) {
            $data[$i]->{biosequence_id} = $matches[0]->[0];
            $data[$i]->{biosequence_name} = $matches[0]->[1];
            if ($VERBOSE) {
              print "  Repairing mismatch:\n";
              print "           reference[$i] = $data[$i]->{reference}\n";
              print "    biosequence_name[$i] = $data[$i]->{biosequence_name}\n";
            }
            $coldata{reference} = $data[$i]->{biosequence_name}

          #### If there is more than one matching row, so just pick the first one
          #### that has the peptide in it or just the first one.
          } elsif ($n_matches > 1) {
            print "\nWARNING: attempt to find match for".
              "\n '$data[$i]->{reference}\%' returned more than one row:\n";
            my $best = -1;
            my $ctr = 0;
            foreach $element (@matches) {
              print "  $element->[1]\n";
              if ($element->[2] =~ /$peptide/) {
                print "  Found the peptide '$peptide' in the above biosequence!\n";
                unless ($best >= 0) {
                  $best = $ctr;
                }
              }
              $ctr++;
            }

            #### If we didn't find one with the peptide in it, just select 0
            unless ($best >= 0) {
              $best=0;
              print "  None of these seem to include the discovered peptide.\n";
              print "  Maybe that's because this is a nucleotide database.\n";
            }

            print "  Setting the match to be index $best.\n";
            $data[$i]->{biosequence_id} = $matches[$best]->[0];
            $data[$i]->{biosequence_name} = $matches[$best]->[1];
            $coldata{reference} = $data[$i]->{biosequence_name}


          #### If there are no rows, this is not good
          } else {
            print "ERROR: Unable to find a match for:\n";
            print "           reference[$i] = $data[$i]->{reference}\n";
          }

        }

      }

      $coldata{biosequence_id} = $data[$i]->{matched_biosequence_id};
      push(@newdata,\%coldata);

    }



    #### If we want to adjust the best hit status for searches
    my $make_best_hit_guess = 0;
    if ($adjust_best_hits) {

      #### First, collect stats on the best hit
      $i=0;
      my $n_D_hits = 0;
      my $n_U_hits = 0;
      my $n_other_hits = 0;
      while ($i<$nrows) {
        $data[$i]->{best_hit_flag} = '' unless ($data[$i]->{best_hit_flag});
        $data[$i]->{best_hit_flag} =~ s/\s//g;
        print "  - $i: =",$data[$i]->{best_hit_flag},"=\n" if ($VERBOSE > 1);
        if ($data[$i]->{best_hit_flag} eq 'D') {
          $n_D_hits++;
        } elsif ($data[$i]->{best_hit_flag} eq 'U') {
          $n_U_hits++;
        } elsif ($data[$i]->{best_hit_flag}) {
          $n_other_hits++;
        }
        $i++;
      }

      #### If there's more than one best hit, complain bitterly
      if ($n_D_hits + $n_U_hits + $n_other_hits > 1) {
        print "ERROR: search_id '$search_id' has more than one best hit!!\n";
        print "       D: $n_D_hits  U: $n_U_hits  other: $n_other_hits\n";
        print "       Going to rewrite with best guess...\n";
        $make_best_hit_guess = 1;

      #### If there's a type of best hit we don't understand, complain
      } elsif ($n_other_hits) {
        die("ERROR: search_id '$search_id' has an unknown type of best hit!!\n");

      #### Otherwise, if there's one user hit, clear flag
      } elsif ($n_U_hits == 1) {
        $make_best_hit_guess = 0;

      #### Otherwise, if there's one default hit, set flag
      } elsif ($n_D_hits == 1) {
        $make_best_hit_guess = 1;

      #### Otherwise, if nothings yet been set a best hit, set flag
      } elsif ($n_D_hits + $n_U_hits + $n_other_hits == 0) {
        $make_best_hit_guess = 1;

      #### There should be nothing else
      } else {
        die("ERROR: BEST_HIT_OPTION_FAIL. This should never happen");
      }

    }


    #### If the flag is set for adjusting the best hit status for searches
    if ($make_best_hit_guess) {

      #### First clear all best_hit flags
      $i=0;
      while ($i<$nrows) {
        $newdata[$i]->{best_hit_flag} = "";
        $i++;
      }

      #### If the top hit is at least singly tryptic, then make it best_hit
      if ($data[0]->{peptide_string} =~ /^[KR]\..+/i ||
  	  $data[0]->{peptide_string} =~ /.+[KR]\..$/i ) {
  	$newdata[0]->{best_hit_flag} = "D";

      #### If not, see if there's a better match in lower hits
      } else {
  	$i=1;
  	while ($i<$nrows) {
  	  if ($data[$i]->{peptide_string} =~ /^[KR]\..+/i ||
  	      $data[$i]->{peptide_string} =~ /.+[KR]\..$/i ) {
  	    $newdata[$i]->{best_hit_flag} = "D";
  	    last;
  	  }
  	  $i++;
  	}

	#### There was not, so just set the flag on the top one
  	$newdata[0]->{best_hit_flag} = "D" if ($i == $nrows);

      }

    }


    #### Print out the results of the decisions
    if ($DEBUG) {
      foreach $element (@newdata) {
        print "  >> ";
        while ( ($key,$value) = each %{$element} ) {
          print "$key='$value'  ";
        }
        print "\n";
      }
    }


    #### Write the data back to the database
    my $search_hit_id;
    foreach $element (@newdata) {
      $search_hit_id = $element->{search_hit_id};

      unless ($search_hit_id) {
        print "ERROR: this is very bad.  search_hit_id is null!!\n";
        print "i = $i\n";
        print "Query was:\n$sql\n";
        print "  >> ";
        while ( ($key,$value) = each %{$element} ) {
          print "$key='$value'  ";
        }
        print "\n";
        die "bummer";
      }

      delete $element->{search_hit_id};
      $result = $sbeams->insert_update_row(table_name=>$TBPR_SEARCH_HIT,
        update=>1,rowdata_ref=>$element,PK=>"search_hit_id",
        PK_value=>$search_hit_id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY
      );

    }


    #last if ($counter > 1);
    $counter++;
    print "$counter..." if ($counter % 100 == 0);


  }


  return;

} # end sub updateSearchResults



###############################################################################
# updateTimingInfo
###############################################################################
sub updateTimingInfo {
  my %args = @_;
  my $SUB_NAME = 'updateTimingInfo';

  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $search_batch_subdir = $args{'search_batch_subdir'}
   || die "ERROR[$SUB_NAME]: search_batch_subdir not passed";
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_dir not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Set the command-line options
  my $file_prefix = $OPTIONS{"file_prefix"} || '';
  my $set_gradient_program_id = $OPTIONS{"gradient_program_id"};
  my $set_column_delay = $OPTIONS{"column_delay"};


  #### Try to find this experiment in database
  $sql="SELECT experiment_id ".
      "FROM $TBPR_PROTEOMICS_EXPERIMENT ".
      "WHERE experiment_tag = '$experiment_tag'";
  my ($proteomics_experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($proteomics_experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Get all the fraction_ids for this experiment
  $sql = qq~
	SELECT fraction_id
	  FROM $TBPR_FRACTION
	 WHERE experiment_id = '$proteomics_experiment_id'
  ~;
  my @fraction_ids = $sbeams->selectOneColumn($sql);

  #### If no fractions were found, complain
  unless (@fraction_ids) {
    die("Unable to find any fractions with: $sql");
  }


  #### Loop over each fraction_id
  my $fraction_id;
  foreach $fraction_id (@fraction_ids) {

    #### Get the information about this fraction including location
    $sql = qq~
	SELECT fraction_id,fraction_tag,experiment_path,column_delay,
	       ISNULL(F.gradient_program_id,PE.gradient_program_id)
	  FROM $TBPR_FRACTION F
          JOIN $TBPR_PROTEOMICS_EXPERIMENT PE
               ON (F.experiment_id=PE.experiment_id)
	 WHERE fraction_id = '$fraction_id'
    ~;
    my @rows = $sbeams->selectSeveralColumns($sql);
    my @fraction_info = @{$rows[0]};


    #### Extract some information into variables
    my $fraction_tag = $fraction_info[1];
    my $experiment_path = $fraction_info[2];
    my $column_delay = $fraction_info[3];
    my $gradient_program_id = $fraction_info[4];
    my $source_file = "$experiment_path/$fraction_tag.nfo";

    #### If the file is a relative path, prefix with $prefix or $RAW_DATA_DIR
    unless (-e $source_file) {
      $source_file = "$RAW_DATA_DIR{Proteomics}/$source_file";
    }
    unless (-e $source_file) {
      print "Unable to find '$source_file', needed for timing info.\n";
      next;
    }

    print "\nProcessing fraction '$fraction_tag'\n";


    #### If the user supplied a column_delay, set it
    if (defined($set_column_delay)) {
      $column_delay = $set_column_delay;
      print "Setting column_delay to $column_delay\n";
    }

    #### If there's no column delay, set it to a default and warn the user
    unless ($column_delay) {
      $column_delay = 240;
      print "No column_delay has been defined for this fraction yet.\n";
      print "  Setting it to default value $column_delay seconds.\n";
    }


    #### If the user supplied a gradient_program_id, set it
    if (defined($set_gradient_program_id)) {
      $gradient_program_id = $set_gradient_program_id;
      print "Setting gradient_program_id to $gradient_program_id\n";
    }

    #### If there's no gradient_program_id, set it to a default
    #### and warn the user
    unless ($gradient_program_id) {
      $gradient_program_id = 1;
      print "No gradient_program_id has been defined for this fraction yet.\n";
      print "  Setting it to default value $gradient_program_id.\n";
    }


    #### Get the gradient program data points to calculate % buffer
    my $gradient_program = getGradientProgram(
      gradient_program_id=>$gradient_program_id);
    my @prog_times = @{$gradient_program->{gradient_delta_times}};
    my @prog_deltas = @{$gradient_program->{buffer_B_setting_percents}};


    #### Read the .nfo file for this fraction
    my %msrun_data = $sbeamsPROT->readNfoFile(source_file=>$source_file,
      verbose=>$VERBOSE);


    #### Read the .precur file for this fraction if it exists
    my $precur_data;
    my $precur_file = $source_file;
    $precur_file =~ s/\.nfo/.precur/;
    if ( -e $precur_file ) {
      $precur_data = $sbeamsPROT->readPrecurFile(
        source_file=>$precur_file,
	verbose=>$VERBOSE
      );
    }


    #### If we got back data, UPDATE some fraction-specific pieces of data
    if (%msrun_data) {
      my %rowdata;
      $rowdata{fraction_date} = $msrun_data{parameters}->{Date};
      $rowdata{column_delay} = $column_delay;
      $rowdata{gradient_program_id} = $gradient_program_id;

      #### UPDATE the information
      $result = $sbeams->insert_update_row(
        update=>1,
        table_name=>$TBPR_FRACTION,
        rowdata_ref=>\%rowdata,
	PK=>'fraction_id',
        PK_value=>$fraction_id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
      );


    #### Otherwise we cannot continue
    } else {
      die("Unable to get information from '$source_file'");
    }


    #### Get a hash of msms_spectrum_id's
    $sql = qq~
	SELECT start_scan,msms_spectrum_id
	  FROM $TBPR_MSMS_SPECTRUM
	 WHERE fraction_id = '$fraction_id'
    ~;
    my %msms_spectrum_ids = $sbeams->selectTwoColumnHash($sql);

    #### If no msms_spectra were found, fail
    unless (%msms_spectrum_ids) {
      print "SEVERE WARNING: Unable to find any msms_spectrum_ids with: $sql";
      next;
    }


    #### Loop over each row of data from the file
    my $row;
    foreach $row (@{$msrun_data{spec_data}}) {

      my $scan_number = $row->[0];

      #### If this scan_number is in the database, update it
      if ($msms_spectrum_ids{$scan_number}) {

        my $msms_spectrum_id = $msms_spectrum_ids{$scan_number};

        #### Populate a hash with the data we want to update
        my %rowdata;
	$rowdata{scan_time} = $row->[3] / 10000.0;
	my $retention_time = $rowdata{scan_time} - $column_delay;
	#$rowdata{retention_time} = $rowdata{scan_time} - $column_delay;

        #### Calculate buffer percents
        my $result_ref = calcBufferPercent(
          retention_time=>$retention_time,
          prog_times_ref=>\@prog_times,
          prog_deltas_ref=>\@prog_deltas,
        );
        my $buffer_B_percent = $result_ref->{buffer_B_percent};


        #### Verify and add to rowdata
        if ($buffer_B_percent) {
          $rowdata{calc_buffer_percent} = $buffer_B_percent;
        } else {
          print "ERROR: Unable to calculate buffer B percent\n";
        }


	#### If we have precursor_intensity information, add that
	if (defined($precur_data) && defined($precur_data->{$scan_number})) {
	  my $idx = $precur_data->{column_names_hash}->{precursor_intensity};
	  my $precursor_intensity = $precur_data->{$scan_number}->[$idx];
	  $rowdata{precursor_intensity} = $precursor_intensity/1e6;
	}


        #### UPDATE the information
  	$result = $sbeams->insert_update_row(
  	  update=>1,
  	  table_name=>$TBPR_MSMS_SPECTRUM,
  	  rowdata_ref=>\%rowdata,
  	  PK=>'msms_spectrum_id',
  	  PK_value=>$msms_spectrum_id,
  	  verbose=>$VERBOSE,
  	  testonly=>$TESTONLY,
  	);

        print ".";

      } else {
        #### This is scan is not in the database.  There are many good
        #### reasons why it might be, so sweep on
      }


    } # endforeach $row

    print "\n";

  } # endforeach $fraction


} # end updateTimingInfo



###############################################################################
# getGradientProgram
###############################################################################
sub getGradientProgram {
  my %args = @_;

  my $gradient_program_id = $args{'gradient_program_id'}
    || die "Must supply the gradient_program_id";
  my $verbose = $args{'verbose'} || 0;


  #### Define some variables
  my ($key,$value,$i,$matches,$tmp,$sql);


  #### Get all the gradient_program_deltas for this program
  $sql = qq~
	SELECT gradient_delta_time,buffer_B_setting_percent
	  FROM $TBPR_GRADIENT_DELTA
	 WHERE gradient_program_id = '$gradient_program_id'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);

  #### Verify
  unless (@rows) {
    die("Unable to get information gradient program information with $sql");
  }


  #### Fill arrays with the gradient program points
  #### NOTE THAT UNITS IN GRADIENT_DELTA IS IN MINUTES, SO CONVERT TO SECONDS
  my $row;
  my @gradient_delta_times;
  my @buffer_B_setting_percents;
  foreach $row (@rows) {
    push(@gradient_delta_times,$row->[0]*60.0);
    push(@buffer_B_setting_percents,$row->[1]);
  }


  #### Create the final hash to return
  my %finalhash;
  $finalhash{gradient_delta_times} = \@gradient_delta_times;
  $finalhash{buffer_B_setting_percents} = \@buffer_B_setting_percents;

  return \%finalhash;


}



###############################################################################
# calcBufferBPercent
###############################################################################
sub calcBufferPercent {
  my %args = @_;

  my $retention_time = $args{'retention_time'}
    || die "Must supply the retention_time";
  my $prog_times_ref = $args{'prog_times_ref'}
    || die "Must supply the prog_times_ref";
  my $prog_deltas_ref = $args{'prog_deltas_ref'}
    || die "Must supply the prog_deltas_ref";


  #### Define some variables
  my ($key,$value,$i,$matches,$tmp,$sql);


  #### Calculate the actual buffer percents based on the time
  my ($buffer_B_percent) = Math::Interpolate::linear_interpolate(
    $retention_time, $prog_times_ref, $prog_deltas_ref);
  if ($VERBOSE) {
    print "x: ",join(',',@{$prog_times_ref}),"\n";
    print "y: ",join(',',@{$prog_deltas_ref}),"\n";
    print "retention_time_in: $retention_time\n";
    print "buffer_B_percent_out: $buffer_B_percent\n";
  }


  #### Create the final hash to return
  my %finalhash;
  $finalhash{buffer_B_percent} = $buffer_B_percent;
  $finalhash{buffer_A_percent} = 100 - $buffer_B_percent;

  return \%finalhash;


}


###############################################################################
# cleanupArchive
###############################################################################
sub cleanupArchive {
  my %args = @_;
  my $SUB_NAME = 'cleanupArchive';

  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $search_batch_subdir = $args{'search_batch_subdir'}
   || die "ERROR[$SUB_NAME]: search_batch_subdir not passed";
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_dir not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Set the command-line options
  my $file_prefix = $OPTIONS{"file_prefix"} || '';


  #### Try to find this experiment in database
  $sql="SELECT experiment_id ".
      "FROM $TBPR_PROTEOMICS_EXPERIMENT ".
      "WHERE experiment_tag = '$experiment_tag'";
  my ($proteomics_experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($proteomics_experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Get all the fraction_ids for this experiment
  $sql = qq~
	SELECT fraction_id
	  FROM $TBPR_FRACTION
	 WHERE experiment_id = '$proteomics_experiment_id'
  ~;
  my @fraction_ids = $sbeams->selectOneColumn($sql);

  #### If no fractions were found, complain
  unless (@fraction_ids) {
    print "WARNING: Unable to find any fractions for experiment. Partially loaded.";
  }


  #### Loop over each fraction_id
  my $fraction_id;
  foreach $fraction_id (@fraction_ids) {

    #### Get the information about this fraction including location
    $sql = qq~
	SELECT fraction_id,fraction_tag,experiment_path
	  FROM $TBPR_FRACTION F
          JOIN $TBPR_PROTEOMICS_EXPERIMENT PE
               ON (F.experiment_id=PE.experiment_id)
	 WHERE fraction_id = '$fraction_id'
    ~;
    my @rows = $sbeams->selectSeveralColumns($sql);
    my @fraction_info = @{$rows[0]};


    #### Extract some information into variables
    my $fraction_tag = $fraction_info[1];
    my $experiment_path = $fraction_info[2];
    my $source_file = "$experiment_path/$fraction_tag.nfo";

    #### If the file is a relative path, prefix with $prefix or $RAW_DATA_DIR
    unless (-e $source_file) {
      $source_file = "$RAW_DATA_DIR{Proteomics}/$source_file";
    }

    print "\nProcessing fraction '$fraction_tag'\n";


    #### Determine the Root directory for this experiment/search_batch
    #### and verify that it exists
    my $root = "$experiment_path/$search_batch_subdir";
    if ( -e $root ) {
      print "  ERROR: Found direct reference; should be relative\n";
      print "  SKIP!\n";
      next;
    } else {
      print "  Examining $root\n";
      $root = "$RAW_DATA_DIR{Proteomics}/$root";
    }
    unless ( -e $root ) {
      print "ERROR: Unable to find root '$root'\n";
      print "  SKIP!\n";
      next;
    }


    #### Verify that the html summary file is there
    if ( -e "$root/$fraction_tag.html" ) {
      print "  HTML summary file OK\n";
    } else {
      print "  ERROR: Missing summary file '$root/$fraction_tag.html'\n";
    }


    #### Check the status of the tgz and data search subdirs
    if ( -e "$root/$fraction_tag.tgz" ) {
      print "  TGZ file OK\n";
      if ( -d "$root/$fraction_tag" ) {
        print "  Data subdir also exists, so purge it\n";
        system("/bin/rm -rf $root/$fraction_tag");
      } else {
        print "  Data subdir not present which is OK\n";
      }
    } else {
      print "  TGZ file missing\n";
      if ( -d "$root/$fraction_tag" ) {
        print "  Data subdir does exist, so tar it up and purge it\n";
        system("(cd $root/$fraction_tag && tar -czf ../$fraction_tag.tgz .)");
      } else {
        print "  ERROR: Cannot find either TGZ or data subdir!!\n";
      }
    }


    print "\n------------------------------------------------------------\n";

  }

}



###############################################################################
# deleteSearchBatch
###############################################################################
sub deleteSearchBatch {
  my %args = @_;
  my $SUB_NAME = 'deleteSearchBatch';

  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $search_batch_subdir = $args{'search_batch_subdir'}
   || die "ERROR[$SUB_NAME]: search_batch_subdir not passed";
  my $source_dir = $args{'source_dir'}
   || die "ERROR[$SUB_NAME]: source_dir not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Try to find this experiment in database
  $sql="SELECT experiment_id ".
      "FROM $TBPR_PROTEOMICS_EXPERIMENT ".
      "WHERE experiment_tag = '$experiment_tag'";
  my ($proteomics_experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($proteomics_experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Try to find this search_batch in database
  $sql = qq~
      SELECT search_batch_id
        FROM $TBPR_SEARCH_BATCH
       WHERE experiment_id = '$proteomics_experiment_id'
         AND search_batch_subdir = '$search_batch_subdir'
  ~;
  my @search_batch_ids = $sbeams->selectOneColumn($sql);
  my $search_batch_id;

  if (scalar(@search_batch_ids) < 1) {
    print "\nERROR: Unable to find this search batch\n";
    return;
  }
  if (scalar(@search_batch_ids) > 1) {
    print "\nERROR: Too many search_batches returned from $sql\n";
    return;
  }


  #### Define the inheritance path:
  ####  (C) means Child that directly links to the parent
  ####  (PKLC) means a PKeyLess Child that should be deleted by it parental key
  ####  (A) means Association from parent to this table and requires delete
  ####  (L) means Linking table from child to parent
  my %table_child_relationship = (
    search_batch => 'search(C),search_batch_parameter(PKLC)',
    search => 'search_hit(C)',
    search_hit => 'quantitation(C),search_hit_protein(C)',
  );


  foreach my $element (@search_batch_ids) {
    my $result = $sbeams->deleteRecordsAndChildren(
      table_name => 'search_batch',
      table_child_relationship => \%table_child_relationship,
      delete_PKs => [ $element ],
      delete_batch => 1000,
      database => $DBPREFIX{Proteomics},
      verbose => $VERBOSE,
      testonly => $TESTONLY,
    );

  }

}



###############################################################################
# deleteExperiment
###############################################################################
sub deleteExperiment {
  my %args = @_;
  my $SUB_NAME = 'deleteExperiment';

  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";


  #### Try to find this experiment in database
  my $sql = qq~
     SELECT experiment_id
       FROM $TBPR_PROTEOMICS_EXPERIMENT
      WHERE experiment_tag = '$experiment_tag'
  ~;
  my ($proteomics_experiment_id) = $sbeams->selectOneColumn($sql);
  unless ($proteomics_experiment_id) {
    print "\nERROR: Unable to find experiment tag '$experiment_tag'.\n".
          "       This experiment must already exist in the database\n\n";
    return;
  }


  #### Try to find if there are any search_batches in database
  $sql = qq~
      SELECT search_batch_id
        FROM $TBPR_SEARCH_BATCH
       WHERE experiment_id = '$proteomics_experiment_id'
  ~;
  my @search_batch_ids = $sbeams->selectOneColumn($sql);
  my $search_batch_id;

  if (scalar(@search_batch_ids) > 0) {
    print "\nERROR: There are still search batches for this experiment. ".
      "Please delete all search batches first, then delete the experiment.\n";
    return;
  }


  #### Define the inheritance path:
  ####  (C) means Child that directly links to the parent
  ####  (PKLC) means a PKeyLess Child that should be deleted by it parental key
  ####  (A) means Association from parent to this table and requires delete
  ####  (L) means Linking table from child to parent
  my %table_child_relationship = (
    proteomics_experiment => 'fraction(C)',
    fraction => 'msms_spectrum(C)',
    msms_spectrum => 'msms_spectrum_peak(PKLC)',
  );

  #### Define some instances where the PK name is not the table name + _id
  my %table_PK_column_names = (
    proteomics_experiment => 'experiment_id',
  );

  my $result = $sbeams->deleteRecordsAndChildren(
    table_name => 'proteomics_experiment',
    table_child_relationship => \%table_child_relationship,
    table_PK_column_names => \%table_PK_column_names,
    delete_PKs => [ $proteomics_experiment_id ],
    delete_batch => 1000,
    database => $DBPREFIX{Proteomics},
    verbose => $VERBOSE,
    testonly => $TESTONLY,
  );


}
###############################################################################
# deleteFraction
###############################################################################
sub deleteFraction {
  my %args = @_;
  my $SUB_NAME = 'deleteFraction';

  #### Decode the argument list
  my $experiment_tag = $args{'experiment_tag'}
   || die "ERROR[$SUB_NAME]: experiment_tag not passed";
  my $fraction_tag = $args{'fraction_tag'}
   || die "ERROR[$SUB_NAME]: fraction_tag not passed";

  print "aaaaaaaaa $fraction_tag $experiment_tag\n";
  #### Try to find this fraction in database
  my $sql = qq~
     SELECT fraction_id
       FROM $TBPR_PROTEOMICS_EXPERIMENT PE
       JOIN $TBPR_FRACTION F ON ( PE.experiment_id = F.experiment_id )
      WHERE experiment_tag = '$experiment_tag'
        AND fraction_tag = '$fraction_tag'
  ~;
  my ($fraction_id) = $sbeams->selectOneColumn($sql);
  unless ($fraction_id) {
    print "\nERROR: Unable to find fraction tag '$fraction_tag'.\n".
          "       This fraction must already exist in the database\n\n";
    return;
  }


  #### Define the inheritance path:
  ####  (C) means Child that directly links to the parent
  ####  (PKLC) means a PKeyLess Child that should be deleted by it parental key
  ####  (A) means Association from parent to this table and requires delete
  ####  (L) means Linking table from child to parent
  my %table_child_relationship = (
    fraction => 'msms_spectrum(C)',
    msms_spectrum => 'msms_spectrum_peak(PKLC),search(C)',
    search => 'search_hit(C)',
    search_hit => 'quantitation(C),search_hit_protein(C)',
  );

  my $result = $sbeams->deleteRecordsAndChildren(
    table_name => 'fraction',
    table_child_relationship => \%table_child_relationship,
    delete_PKs => [ $fraction_id ],
    delete_batch => 1000,
    database => $DBPREFIX{Proteomics},
    verbose => $VERBOSE,
    testonly => $TESTONLY,
  );


}


#######################################################################
# getExperimentTag - retrieve experiment tag, given experiment id
# @param exp_id 
# @return exp tag
#######################################################################
sub getExperimentTag
{

    my %args = @_;

    my $exp_id = $args{exp_id} || die "need exp_id ($!)";

    my $exp_tag;

    my $sql = qq~
        SELECT PE.experiment_tag
        FROM $TBPR_PROTEOMICS_EXPERIMENT PE
        WHERE PE.experiment_id = '$exp_id'
        AND PE.record_status != 'D'
    ~;


    ($exp_tag) = $sbeams->selectOneColumn($sql) or die
        "Could not find record for experiment id $exp_id";

    return $exp_tag;

}


#######################################################################
# getExperimentDirectory - retrieve path to experiment directory
# @param exp_id 
# @param exp_tag
# @return path to experiment
#######################################################################
sub getExperimentDirectory
{

    my %args = @_;

    my $exp_tag = $args{exp_tag};

    my $exp_id = $args{exp_id};

    my $exp_path;

    unless ($exp_tag || $exp_id)
    {

        die "need exp_tag or exp_id ($!)";

    }

    if (!$exp_tag)
    {

        $exp_tag = getExperimentTag( exp_id => $exp_id );

    }

    
    my $sql = qq~
        SELECT PE.experiment_path
        FROM $TBPR_PROTEOMICS_EXPERIMENT PE
        WHERE PE.experiment_id = '$exp_id'
        AND PE.record_status != 'D'
    ~;


    ($exp_path) = $sbeams->selectOneColumn($sql) or die
        "Could not find record for experiment id $exp_id";

    return $exp_path;

}
