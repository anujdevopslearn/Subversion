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
$PROG_NAME = "generate_fasta_file.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] fasta_file
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly n        Set testonly flag

 e.g.:  $PROG_NAME

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
  my ($i,$element,$key,$value,$line,$result,$sql,$row);

  #### Set the fasta file name
  my $fasta_file = $ARGV[0];

  #### Print out the header
  $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
  print "\n" unless ($QUIET);


  #### Open fasta file for writing
  unless (open(FASTAFILE,">$fasta_file")) {
    die("Cannot open file $fasta_file");
  }

  #### Get allele_id, query sequence for fasta file
  $sql = "   SELECT A.allele_id,convert(varchar(4000),SI.trimmed_fiveprime_sequence)+" .
  	 "          A.allele+convert(varchar(4000),SI.trimmed_threeprime_sequence) as sequence," .
         "          QS.query_sequence_id" .
  	 "     FROM ${TBSN_ALLELE} A " .
  	 "     JOIN ${TBSN_SNP_INSTANCE} SI on (A.snp_instance_id = SI.snp_instance_id)" .
  	 "LEFT JOIN ${TBSN_QUERY_SEQUENCE} QS on (QS.query_sequence = " .
         "          convert(varchar(4000),SI.trimmed_fiveprime_sequence)+ " .
  	 "          A.allele+convert(varchar(4000),SI.trimmed_threeprime_sequence) ) " .
	 "    WHERE A.query_sequence_id IS NULL " .
         "ORDER BY A.allele_id";
#        print "SQL: $sql\n";
  	my @sequences = $sbeams->selectSeveralColumns($sql);


  my %query_sequence_ids;

  my ($query_sequence_id,$sequence);
  foreach $row (@sequences) {
    #### If there's no sequence, just skip this record
    next unless ($row->[1]);

    #### Pull out the query_sequence_id from the result set
    $query_sequence_id = $row->[2];
    $sequence = uc($row->[1]);


    #### If it's not defined, then see if we've already cencountered this
    #### sequence in this program
    unless ($query_sequence_id) {
      $query_sequence_id = $query_sequence_ids{$sequence}
        if ($query_sequence_ids{$sequence});
    }

    #### If it's still not defined, then INSERT a record for it
    unless ($query_sequence_id) {
      my %rowdata = ('query_sequence'=>$row->[1]);
      $query_sequence_id = $sbeams->insert_update_row(
    	insert=>1,
    	table_name=>${TBSN_QUERY_SEQUENCE},
    	rowdata_ref=>\%rowdata,
    	PK=>'query_sequence_id',
    	return_PK=>1,
    	verbose=>$VERBOSE,
    	testonly=>$TESTONLY,
      );
      $row->[1] =~ s/-//g;
      print FASTAFILE "\>".$query_sequence_id."\n".$row->[1]."\n";
      $query_sequence_ids{$row->[1]} = $query_sequence_id;
    }


    #### Now UPDATE allele with the appropriate query_sequence_id
    my %seqhash = ( 'query_sequence_id' => $query_sequence_id );
    $query_sequence_id = $sbeams->insert_update_row(
      update=>1,
      table_name=>${TBSN_ALLELE},
      rowdata_ref=>\%seqhash,
      PK=>'allele_id',
      PK_value=>$row->[0],
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

    print ".";

  }

  #$sbeams->executeSQL("CREATE NONCLUSTERED INDEX idx_query_sequence_sequence
  #  ON ${TBSN_QUERY_SEQUENCE} ( query_sequence ) WITH DROP_EXISTING");


}
