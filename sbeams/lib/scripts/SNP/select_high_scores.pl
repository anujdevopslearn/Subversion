#!/usr/local/bin/perl -w
#
# Usage: select_high_scores.pl thresh
#
# Pulls out the highest scoring SNP match for each biosequence_set.
# User supplies a threshhold of identified_percent and match_length/query_length
# (the same threshhold will be used for both).
#
# 2002/04/09 Kerry Deutsch

###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;

use Bio::Tools::BPlite;
use Getopt::Long;
use vars qw ($sbeams $sbeamsMOD
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_contact_id $current_username);
use lib qw (/net/db/lib/sbeams/lib/perl);
use FindBin;
use lib "$FindBin::Bin/../lib";

#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

use SBEAMS::SNP;
use SBEAMS::SNP::Settings;
use SBEAMS::SNP::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SNP;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


#### Set program name and usage banner
$PROG_NAME = "select_high_scores.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] thresh
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME 95

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
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
  print "  DBVERSION = $DBVERSION\n";
}


#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'SNP'));


#### Print the header, do what the program does, and print footer
$| = 1;
$sbeams->printTextHeader() unless ($QUIET);
main();
$sbeams->printTextFooter() unless ($QUIET);

exit 0;


###############################################################################
# Main part of the script
###############################################################################
sub main {

  #### Define standard variables
  my ($query,$querylen,$dbtitle,$hit,$hsp,$hspcnt,$bioname,$queryname);
  my ($sql,$result,$junk,$cnt);

  #### Print out the header
  $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
  print "\n" unless ($QUIET);

  #### If a parameter is not supplied, print usage and bail
  unless ($ARGV[0]) {
    print $USAGE;
    exit 0;
  }

  #### Set the threshhold for a "good" score
  my $thresh = $ARGV[0];

  ######################################################################
  #### Create temporary table
  $sql = qq~
  SELECT S.snp_id,BSS.biosequence_set_id AS ref_id,
         MAX(BS.identified_percent) AS 'identified_percent'
    INTO #tmp1
    FROM ${TBSN_SNP_INSTANCE} SI
    JOIN ${TBSN_SNP_SOURCE} SS on (SS.snp_source_id = SI.snp_source_id)
    JOIN ${TBSN_ALLELE} A on (A.snp_instance_id = SI.snp_instance_id)
    JOIN ${TBSN_ALLELE_BLAST_STATS} BS on (BS.allele_id = A.allele_id)
    JOIN ${TBSN_BIOSEQUENCE} B on (B.biosequence_id = BS.matched_biosequence_id)
    JOIN ${TBSN_BIOSEQUENCE_SET} BSS ON (BSS.biosequence_set_id = B.biosequence_set_id)
   WHERE BS.percent_identified >= $thresh
     AND convert(real,BS.match_length)/BS.query_length >= $thresh/100
GROUP BY S.snp_instance_id,BSS.biosequence_set_id
ORDER BY S.snp_instance_id,BSS.biosequence_set_id
  ~;

  $sbeams->executeSQL($sql);


  ######################################################################
  #### Select out high scoring hits
  $sql = qq~
  SELECT SI.snp_instance_source_accession,A.allele_id,BSS.biosequence_set_id AS ref_id,
         BS.end_fiveprime_position AS end_fiveprime,BS.strand,BS.identified_percent AS 'percent',
         convert(numeric(5,2),convert(real,BS.match_length)/BS.query_length) AS match_ratio,
         convert(varchar(1000),S.fiveprime_sequence)+'['+S.allele_string+']'+
         convert(varchar(1000),S.threeprime_sequence)
    FROM ${TBSN_SNP_INSTANCE} SI
    JOIN ${TBSN_SNP_SOURCE} SS on (SS.snp_source_id = S.snp_source_id)
    JOIN ${TBSN_ALLELE} A on (A.snp_instance_id = S.snp_instance_id)
    JOIN ${TBSN_ALLELE_BLAST_STATS} BS on (BS.allele_id = A.allele_id)
    JOIN ${TBSN_BIOSEQUENCE} B on (B.biosequence_id = BS.matched_biosequence_id)
    JOIN ${TBSN_BIOSEQUENCE_SET} BSS ON (BSS.biosequence_set_id = B.biosequence_set_id)
    JOIN #tmp1 tt
      ON (SI.snp_instance_id = tt.snp_instance_id AND BSS.biosequence_set_id = tt.ref_id
     AND BS.identified_percent = tt.identified_percent )
   WHERE BS.identified_percent >= $thresh
     AND convert(real,BS.match_length)/BS.query_length >= $thresh/100
ORDER BY BSS.biosequence_set_id,BS.end_fiveprime_position
  ~;



