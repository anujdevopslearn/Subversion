#!/usr/local/bin/perl -w
#
# Usage: update_allele_string.pl
#
# Updates the snp_instance table, filling in the allele_string summary string
# from the allele table.
#
# 2002/04/15 Kerry Deutsch
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
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

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TESTONLY
             $current_contact_id $current_username
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::SNP;
use SBEAMS::SNP::Settings;
use SBEAMS::SNP::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SNP;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          If set, nothing is actually inserted into the database,
                      but we just go through all the motions.  Use --verbose
                      to see all the SQL statements that would occur

 e.g.:  $PROG_NAME

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly:s")) {
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
    work_group=>'SNP',
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);


} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  #### Define standard variables
  my ($sql,$result,$junk,$cnt);

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Get list of all currently loaded alleles
  $sql = "SELECT A.allele_id,A.snp_instance_id,A.allele" .
         "  FROM ${TBSN_ALLELE} A";
  print "SQL: $sql\n";
  my @allele_data = $sbeams->selectSeveralColumns($sql);


  my ($row,$snp_instance_id,$prev_snp_instance_id,$prev_allele_string);
  $cnt = 0;
  $prev_snp_instance_id = '';
  $prev_allele_string = '';
  my $is_true_snp = 0;

  my $n_alleles = scalar(@allele_data);
  print "Processing $n_alleles alleles...\n\n";

  #### Add dummy row at end to be able to UPDATE last real row
  push(@allele_data,[-1,-1,-1]);

  foreach $row (@allele_data) {
    #print "Row: ",join(',',@{$row}),"\n";

    my %rowdata;
    $snp_instance_id = $row->[1];
    my $allele = $row->[2];

    #### If this is a new snp_instance, write out the information we have
    if (($snp_instance_id ne $prev_snp_instance_id) && $cnt>0) {
      $rowdata{allele_string} = $prev_allele_string;

      #### If this snp has not be disqualified as being multibase,
      #### Verify that there's more than one type and store
      if ($is_true_snp != -1) {
        if ($prev_allele_string =~ /\//) {
          $rowdata{is_true_snp} = 'Y';
        } else {
          $rowdata{is_true_snp} = 'N';
        }
      } else {
         $rowdata{is_true_snp} = 'N'
      }

      #### Insert allele_string data into snp_instance
      $result = $sbeams->insert_update_row(
	update=>1,
        table_name=>$TBSN_SNP_INSTANCE,
        rowdata_ref=>\%rowdata,
        PK=>"snp_instance_id",
        PK_value=>$prev_snp_instance_id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
        );
      $prev_snp_instance_id = '';
      $prev_allele_string = '';
      $is_true_snp = 0;
    }

    #### Finish if we hit the dummy end row
    last if ($snp_instance_id == -1);


    #### If there's an allele worth doing anything with
    $allele = '' if (!defined($allele));
    $allele =~ s/\s//g;
    if ($allele gt '') {
      #### If the buffer is empty, then set else append
      if ($prev_allele_string eq '' ) {
        $prev_allele_string = $allele;
      } else {
        $prev_allele_string .= "/$allele";
      }

      #### If one of the alleles is multicharacter, this can't a true_snp
      $is_true_snp = -1 if (length($allele) > 1);

    }


    #### Prepare for next loop
    $prev_snp_instance_id = $snp_instance_id;
    $cnt++;

    if ($cnt/1000 == int($cnt/1000)) {
      print "$cnt(".int($cnt * 100 / $n_alleles)."%)... ";
    }

  }

}


