#!/usr/local/bin/perl -w
#
# Usage: generate_fasta_file.pl
#
# Queries the SNP database and generates a FASTA file that can be used for BLAST.
#
# 2002/04/04 Kerry Deutsch


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;

use Getopt::Long;
use vars qw ($sbeams $sbeamsMOD
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG
             $current_contact_id $current_username);
use lib qw (/net/db/lib/sbeams/lib/perl);
use FindBin;
use lib "$FindBin::Bin/../lib";
use dbhandle;


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
$PROG_NAME = "generate_fasta_file.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] fasta_file
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s") && ($ARGV[0])) {
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
  my ($i,$element,$key,$value,$line,$result,$sql,$row);

  #### Set the fasta file name
  my $fasta_file = $ARGV[0];

  #### Print out the header
  $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
  print "\n" unless ($QUIET);


  #### Open fasta file for writing
  unless (open(FASTAFILE,">$fasta_file")) {
    bail_out("Cannot open file $fasta_file");
  }

  #### Get allele_id, query sequence for fasta file
  $sql = "   SELECT A.allele_id,convert(varchar(4000),SI.trimmed_fiveprime_sequence)+" .
  	 "          A.allele+convert(varchar(4000),SI.trimmed_threeprime_sequence) as sequence" .
  	 "     FROM ${TBSN_ALLELE} A " .
  	 "LEFT JOIN ${TBSN_SNP_INSTANCE} SI on (A.snp_instance_id = SI.snp_instance_id)" .
         "ORDER BY A.allele_id";
#        print "SQL: $sql\n";
  	my @sequences = $sbeams->selectSeveralColumns($sql);

  foreach $row (@sequences) {
    $row->[1] =~ s/-//g;
    print FASTAFILE "\>".$row->[0]."\n".$row->[1]."\n" if $row->[1];
  }

}
