#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_blast_results.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads the results of a BLAST run into the
#               blast_results table, assuming biosequences already exist
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::BioLink;
use SBEAMS::BioLink::Settings;
use SBEAMS::BioLink::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::BioLink;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
$q = CGI->new();

use Bio::Tools::BPlite;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] snp_file
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          If set, rows in the database are not changed or added
  --delete_existing   Delete the existing snps for this set before
                      loading.  Normally, if there are existing snps,,
                      the load is blocked.
  --update_existing   Update the existing snps with information
                      in the file

 e.g.:  $PROG_NAME ???

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "delete_existing","update_existing",
        "query_set_tag:s","match_set_tag:s","source_file:s",
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
  print "  DBVERSION = $DBVERSION\n";
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
    work_group=>'BioLink_admin',
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
  my $delete_existing = $OPTIONS{"delete_existing"} || 0;
  my $update_existing = $OPTIONS{"update_existing"} || 0;

  my $query_set_tag = $OPTIONS{"query_set_tag"} || '';
  my $match_set_tag = $OPTIONS{"match_set_tag"} || '';
  my $source_file = $OPTIONS{"source_file"} || '';

  #### If there are any parameters left, complain and print usage
  unless ($query_set_tag && $match_set_tag && $source_file){
    print "ERROR: Must supply parameter both --query_set_tag and ".
      "--match_set_tag and --source_file parametes\n";
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

  #### Verify the source_file
  unless ( -e "$source_file" ) {
    print "ERROR: Unable to access source_file '$source_file'\n\n";
    return;
  }


  #### Preload a biosequence lookup hash for both the query and match sets
  my $sql;
  print "Preloading query set biosequence_names...\n";
  $sql = qq~
          SELECT biosequence_name,biosequence_id
            FROM $TBBL_BIOSEQUENCE BS
            LEFT JOIN $TBBL_BIOSEQUENCE_SET BSS
                 ON BS.biosequence_set_id = BSS.biosequence_set_id
           WHERE BSS.set_tag = '$query_set_tag'
  ~;
  my %query_biosequence_ids = $sbeams->selectTwoColumnHash($sql);
  print "  ".scalar(keys(%query_biosequence_ids))." loaded.\n";

  print "Preloading match set biosequence_names...\n";
  $sql = qq~
          SELECT biosequence_name,biosequence_id
            FROM $TBBL_BIOSEQUENCE BS
            LEFT JOIN $TBBL_BIOSEQUENCE_SET BSS
                 ON BS.biosequence_set_id = BSS.biosequence_set_id
           WHERE BSS.set_tag = '$match_set_tag'
  ~;
  my %match_biosequence_ids = $sbeams->selectTwoColumnHash($sql);
  print "  ".scalar(keys(%match_biosequence_ids))." loaded.\n";

  #### Define standard variables
  my ($querylen,$dbtitle,$hit,$hsp,$hspcnt);

  #### Create a BLAST parser object
  my $blast = new Bio::Tools::BPlite(-file=>$source_file);


  #### Loop until we're done and break out
  my $counter = 0;
  while (1) {

    #### Define a hash to hold the row data
    my %rowdata_template;

    #### Get biosequence_id of this query
    my ($query_biosequence_name) = split(/\(/,$blast->query);
    $query_biosequence_name =~ s/\s//g;
    if ($query_biosequence_ids{$query_biosequence_name}) {
      $rowdata_template{query_biosequence_id} =
        $query_biosequence_ids{$query_biosequence_name};
    } else {
      die("ERROR: Unable to get a biosequence_id in query for ".
          "'$query_biosequence_name'");
    }

    $querylen = $blast->qlength;
    $rowdata_template{query_length} = $querylen if (defined($querylen));
    $dbtitle = $blast->database;


    #### Loop over all the matches for this query
    my $cnt = 0;
    while ($hit = $blast->nextSbjct) {

      #### Only load the first 20 hits regardless of score (?)
      if ($cnt < 20) {

        #### Get biosequence_id of this match
        my $matched_biosequence_name = $hit->name;
        $matched_biosequence_name =~ s/\s.+//;
        if ($match_biosequence_ids{$matched_biosequence_name}) {
          $rowdata_template{matched_biosequence_id} =
            $match_biosequence_ids{$matched_biosequence_name};
        } else {
          die("ERROR: Unable to get a biosequence_id in match for ".
              "'$matched_biosequence_name'");
        }

        #### Loop over all the matches to this matched_biosequence
        $hspcnt = 0;
        while ($hsp = $hit->nextHSP) {

          #### If the E-value of this alignment is < 0.5, then store it
          if (defined($hsp->P) && $hsp->P < 0.5) {

            #### Create a new row data hash for this one in of NULLs
            my %rowdata = %rowdata_template;

            $rowdata{score} = $hsp->score if (defined($hsp->score));
            $rowdata{identified_percent} = $hsp->percent if (defined($hsp->percent)) ;
            $rowdata{evalue} = $hsp->P if (defined($hsp->P));
            $rowdata{match_length} = $hsp->match if (defined($hsp->match));
            $rowdata{positives} = $hsp->positive if (defined($hsp->positive));
            $rowdata{hsp_length} = $hsp->length if (defined($hsp->length));
            $rowdata{query_sequence} = $hsp->querySeq if (defined($hsp->querySeq));
            $rowdata{matched_sequence} = $hsp->sbjctSeq if (defined($hsp->sbjctSeq)) ;
            $rowdata{query_start} = $hsp->query->start if (defined($hsp->query->start));
            $rowdata{query_end}= $hsp->query->end if (defined($hsp->query->end));
            $rowdata{match_start} = $hsp->subject->start if (defined($hsp->subject->start));
            $rowdata{match_end} = $hsp->subject->end if (defined($hsp->subject->end));
            $rowdata{strand} = $hsp->subject->strand if (defined($hsp->subject->strand));

      	    my $result = $sbeams->updateOrInsertRow(
      	      insert=>1,
      	      table_name=>$TBBL_BLAST_RESULTS,
      	      rowdata_ref=>\%rowdata,
      	      verbose=>$VERBOSE,
      	      testonly=>$TESTONLY,
      	    );

          } # end if E-vale < 0.5

          $hspcnt++;
        } # end while HSP

      } # end if cnt < 20

      $cnt++;

    } # end while next Subject

    #### Break out of the loop if there are no more BLAST results
    last if ($blast->_parseHeader == -1);

    #### Print progress information
    $counter++;
    print "$counter..." if ($counter/100.0 eq int($counter/100.0) && !$QUIET);

  } # end while (1)

} # end handleRequest
