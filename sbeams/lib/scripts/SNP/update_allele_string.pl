#!/usr/local/bin/perl -w
#
# Usage: update_allele_string.pl
#
# Updates the snp_instance table, filling in the allele_string summary string
# from the allele table.
#
# 2002/04/15 Kerry Deutsch

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
$PROG_NAME = "update_allele_string.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --database xxxx     Database where the snp* tables are found
  --delete_existing   Delete the existing snps for this set before
                      loading.  Normally, if there are existing snps,,
                      the load is blocked.
  --update_existing   Update the existing snps with information
                      in the file

 e.g.:  $PROG_NAME

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
  "database:s","delete_existing","update_existing")) {
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
  my ($sql,$result,$junk,$cnt);

  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"} || 0;
  my $update_existing = $OPTIONS{"update_existing"} || 0;

  #### Print out the header
  $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
  print "\n" unless ($QUIET);

  my %rowdata;

  #### Get list of currently loaded alleles
  $sql = "SELECT A.allele_id,A.snp_instance_id,A.allele" .
         "  FROM ${TBSN_ALLELE} A";
  #print "SQL: $sql\n";
  my @allele_data = $sbeams->selectSeveralColumns($sql);

  my ($row,$snp_instance_id,$prev_snp_instance_id,$prev_allele_string);
  $cnt = 0;
  $prev_snp_instance_id = "";
  $prev_allele_string = "";

  #### Add dummy row at end to be able to UPDATE last real row
  push(@allele_data,[-1,-1,-1]);

  foreach $row (@allele_data) {
#    print "Row: ",join(',',@{$row}),"\n";
    $snp_instance_id = $row->[1];
    if (($snp_instance_id ne $prev_snp_instance_id) && $cnt>0) {
      $rowdata{allele_string} = $prev_allele_string;

      #### Insert allele_string data into snp_instance
      $result = $sbeams->insert_update_row(update=>1,
        table_name=>"${TBSN_SNP_INSTANCE}",
        rowdata_ref=>\%rowdata,PK=>"snp_instance_id",
        PK_value=>"$prev_snp_instance_id",
#        verbose=>1,testonly=>1
        );
      $prev_snp_instance_id = "";
      $prev_allele_string = "";
    }

    last if ($snp_instance_id == -1);

    $prev_snp_instance_id = $snp_instance_id;
    if ($prev_allele_string eq "" ) {
      $prev_allele_string = $row->[2];
    } else {
      $prev_allele_string = "$prev_allele_string\/".$row->[2];
    }
    $cnt++;
  }
}
