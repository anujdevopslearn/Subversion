#!/usr/local/bin/perl -w
#
# Usage: load_blast_stats.pl (file)
#
# Parses a blast output file and loads results for each snp
# into the main SNP databases.
#
# 2002/03/11 Kerry Deutsch

###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;

use Bio::Tools::BPlite;
use Getopt::Long;
use vars qw ($sbeams $sbeamsMOD
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TESTONLY $current_contact_id $current_username);
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
$PROG_NAME = "load_blast_stats.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] snp_file
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
  --testonly          Do not do the final load, just test

 e.g.:  $PROG_NAME celera_dbSNP_dqa_exons.blast

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
        "database:s","delete_existing","update_existing","testonly")
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
  print "  DBVERSION = $DBVERSION\n";
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

  #### If there aren't any parameters, print usage
  unless ($ARGV[0]){
    print "$USAGE";
    exit;
  }

  #### Define standard variables
  my ($query,$querylen,$dbtitle,$hit,$hsp,$hspcnt,$bioname,$queryname);
  my ($sql,$result,$junk,$cnt);

  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"} || 0;
  my $update_existing = $OPTIONS{"update_existing"} || 0;

  #### Print out the header
  $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
  print "\n" unless ($QUIET);


  #### Set the name file
  my $source_file = $ARGV[0];
  unless ( -e "$source_file" ) {
    bail_out("Cannot find file $source_file");
  }

  my $blast = new Bio::Tools::BPlite(-file=>$source_file);
  my %allele_hash;
  my @snp_data;

  {
    $query = $blast->query;
    ($queryname,$junk) = split(/\(/, $query);
    $queryname =~ s/ //g;
    my %rowdata;

    #### Get snp_id, 5' length, and 3' length of this query
    $sql = qq~
          SELECT A.snp_instance_id,SI.trimmed_fiveprime_length,
                 SI.trimmed_threeprime_length
            FROM ${TBSN_ALLELE} A
       LEFT JOIN ${TBSN_SNP_INSTANCE} SI
              ON (A.snp_instance_id = SI.snp_instance_id)
           WHERE A.query_sequence_id = '$queryname'
    ~;

    @snp_data = $sbeams->selectSeveralColumns($sql);
    $allele_hash{$queryname}=$snp_data[0];

    $rowdata{query_sequence_id} = $queryname if (defined($queryname));
    $querylen = $blast->qlength;
    $rowdata{query_length} = $querylen if (defined($querylen));
    $dbtitle = $blast->database;
    $dbtitle =~ s/bioseqs\///g;
    $dbtitle =~ s/ //g;

    $sql = qq~
          SELECT biosequence_name,biosequence_id
            FROM ${TBSN_BIOSEQUENCE}
       LEFT JOIN ${TBSN_BIOSEQUENCE_SET}
              ON ${TBSN_BIOSEQUENCE_SET}.biosequence_set_id = ${TBSN_BIOSEQUENCE}.biosequence_set_id
           WHERE ${TBSN_BIOSEQUENCE_SET}.set_path like '%$dbtitle%'
    ~;
    my %biosequence_id = $sbeams->selectTwoColumnHash($sql);

    $cnt = 0;
    while ($hit = $blast->nextSbjct) {
      if ($cnt == 0) {

        #### Get biosequence_id of this dbtitle
        $bioname = $hit->name;
        $bioname =~ s/\s.+//;
        $rowdata{matched_biosequence_id} = $biosequence_id{$bioname};

        $hspcnt = 0;
        while ($hsp=$hit->nextHSP) {
          if ($hspcnt == 0) {
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

            if (($rowdata{strand} eq "1") && defined($allele_hash{$queryname}->[1])) {
              $rowdata{end_fiveprime_position} = $rowdata{match_start} - $rowdata{query_start} + $allele_hash{$queryname}->[1];
            }
            elsif (($rowdata{strand} eq "-1") && defined($allele_hash{$queryname}->[2])) {
#              $rowdata{end_fiveprime_position} = $rowdata{match_end} + $rowdata{query_start} - $allele_hash{$queryname}->[2];
              $rowdata{end_fiveprime_position} = $rowdata{match_start} + $allele_hash{$queryname}->[2] - ($rowdata{query_length} - $rowdata{query_end} - 1);
            }
          }
          $hspcnt++;
        }
      }
      $cnt++;
    }

    #### Insert the data into the database
    if ($rowdata{matched_biosequence_id}) {
      $result = $sbeams->insert_update_row(
        insert=>1,
        table_name=>"${TBSN_ALLELE_BLAST_STATS}",
        rowdata_ref=>\%rowdata,
        PK=>"allele_id",
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
      );
    }
    last if ($blast->_parseHeader == -1);
    redo
  }
}
