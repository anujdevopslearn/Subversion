#!/usr/local/bin/perl -w
#
# Usage: remap_snps.pl
#
# This script "merges" duplicate snps.  Currently, the most recent Celera set
# is used as the reference.  Any other sources of snps that match a Celera
# snp are given that snp's id.  The corresponding "alternate" ids are added to
# the external source accession fields in the snp table for the Celera snp.
# For the other sources, the snp table's obsoleted_by_snp_id field is given
# the Celera snp's id.
#
# 2002/07/22 Kerry Deutsch


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;

use Getopt::Long;
use vars qw ($sbeams $sbeamsMOD
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username);
use lib qw (/net/db/lib/sbeams/lib/perl);
use FindBin;

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
$PROG_NAME = "remap_snps.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] search_spec
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly n        Set testonly flag

 e.g.:  $PROG_NAME Celera_MHC

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly")
        && ($ARGV[0])) {
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
  my ($i,$element,$key,$value,$line,$result,$sql,$row,$row2);


  #### Print out the header
  $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
  print "\n" unless ($QUIET);


  #### Set the string you'd like to use to isolate a data source set
  my $search_string = $ARGV[0];

  #### Get most recent Celera source_version_id
  $sql = "SELECT SV.source_version_id" .
         "  FROM ${TBSN_SOURCE_VERSION} SV " .
         " WHERE SV.date_created = " .
         "      (SELECT max(date_created) from ${TBSN_SOURCE_VERSION} SV" .
	 "       WHERE SV.source_version_name LIKE '%$search_string%')";
  #print "SQL: $sql\n";
  my ($source_version_id) = $sbeams->selectOneColumn($sql);


  #### Find all snps and snp_instances for the particular source_version_id
  #### (Celera usually) which originally came from a different source
  $sql = "SELECT SI.snp_id,SI.snp_instance_id,SI.snp_instance_source_accession" .
         "  FROM ${TBSN_SNP_INSTANCE} SI ".
         " WHERE SI.source_version_id = '$source_version_id' ".
         "   AND SI.snp_instance_source_accession IS NOT NULL";
  #print "SQL: $sql\n";
  my @si_source_accessions = $sbeams->selectSeveralColumns($sql);


  my ($snp_id, $this_snp_instance_id, $source_accession, %rowdata, %rowdata2);
  foreach $row (@si_source_accessions) {

    ($snp_id,$this_snp_instance_id,$source_accession) = @{$row};

    #### Look for this snp_instance_source_accession in other native sources
    $sql = "SELECT SI.snp_instance_id,SI.snp_id" .
           "  FROM ${TBSN_SNP_INSTANCE} SI ".
           " WHERE SI.snp_instance_source_accession = '$source_accession' ".
           "   AND SI.source_version_id != '$source_version_id' ";

    #print "SQL: $sql\n";
    my @si_snp_instances = $sbeams->selectSeveralColumns($sql);

    foreach $row2 (@si_snp_instances) {

      my ($match_snp_instance_id,$match_snp_id) = @{$row2};

      #### If the celera snp_id is already matched_snp_id then there's
      #### nothing more to do
      next if ($match_snp_id == $snp_id);


      #### Update all snp_instances to point to the Celera snp's snp_id
      $rowdata{snp_id} = $snp_id;
      $result = $sbeams->insert_update_row(update=>1,
        table_name=>"${TBSN_SNP_INSTANCE}",
        rowdata_ref=>\%rowdata,PK=>"snp_instance_id",
        PK_value=>$match_snp_instance_id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY
        );


      #### Update snp to enter the other native accession for the
      #### master Celera_accession
      %rowdata2 = ();
      if ($source_accession =~ /^ss/) {
	$rowdata2{dbSNP_accession} = $source_accession;
      } elsif ($source_accession =~ /^SNP/ || $source_accession =~ /^IND/) {
	$rowdata2{hgbase_accession} = $source_accession;
      } else {
        die "Wah!  I don't know what to do with source_accession ".
          "'$source_accession'";
      }

      $rowdata2{date_modified} = 'CURRENT_TIMESTAMP';
      $rowdata2{modified_by_id} = $sbeams->getCurrent_contact_id();

      $result = $sbeams->insert_update_row(update=>1,
        table_name=>"${TBSN_SNP}",
        rowdata_ref=>\%rowdata2,PK=>"snp_id",
        PK_value=>$snp_id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY
        );


      #### If this record hasn't already been re-parented, then UPDATE
      #### the other native snp entry to have the Celera snp_id in the
      #### obsoleted_by_snp_id field
      if ($match_snp_id != $snp_id) {
        my %rowdata = ();
        $rowdata{obsoleted_by_snp_id} = $snp_id;
        $rowdata{date_modified} = 'CURRENT_TIMESTAMP';
        $rowdata{modified_by_id} = $sbeams->getCurrent_contact_id();
  	$result = $sbeams->insert_update_row(update=>1,
  	  table_name=>"${TBSN_SNP}",
  	  rowdata_ref=>\%rowdata,PK=>"snp_id",
  	  PK_value=>$match_snp_id,
  	  verbose=>$VERBOSE,
  	  testonly=>$TESTONLY
  	  );
      }

    }
  }
}
