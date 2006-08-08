#!/usr/local/bin/perl

###############################################################################
# Program     : load_biosequence_set.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org> / 
#               Rowan Christmas <xmas@systemsbiology.org>
# $Id$
#
# Description : This script loads a biosequence set (gene library) from a
#               FASTA file.  Note that there may be some cusomtization for
#               the particular library to populate gene_name and accesssion
#
###############################################################################


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;
use Getopt::Long;
use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_contact_id $current_username);
#use FindBin;
#use lib "$FindBin::Bin/../lib";
use lib qw (/net/db/lib/sbeams/lib/perl);
#use lib qw (/host/db/local/www/html/dev2/sbeams/lib/perl);


#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$sbeams = new SBEAMS::Connection;


#### Set program name and usage banner
$PROG_NAME = "load_biosequence_set.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] biosequence_file biosequence_set_name
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --database xxxx     Database where the biosequence* tables are found
  --delete_existing   Delete the existing biosequences for this set before
                      loading.  Normally, if there are existing biosequences,
                      the load is blocked.
  --update_existing   Update the existing biosequence set with information
                      in the file
  --skip_sequence     If set, only the names, descs, etc. are loaded; the actual
                      sequence (often not really necessary) is not written

 e.g.:  $PROG_NAME yeast_orf_coding.fasta yeast_orf_coding

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
  "database:s","delete_existing","update_existing","skip_sequence")) {
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
    $sbeams->Authenticate(work_group=>'Phenotype_user'));


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
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"} || 0;
  my $update_existing = $OPTIONS{"update_existing"} || 0;
  my $skip_sequence = $OPTIONS{"skip_sequence"} || 0;
  $DATABASE = $OPTIONS{"database"} || $sbeams->getPHENOARRAY_DB();


  #### Print out the header
  $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
  print "\n" unless ($QUIET);


  #### If a parameter is not supplied, print usage and bail
  unless ($ARGV[0] && $ARGV[1]) {
    print $USAGE;
    exit 0;
  }


  #### Set the name file
  my $source_file = $ARGV[0];
  unless ( -e "$source_file" ) {
    bail_out("Cannot find file $source_file");
  }


  #### Set the set_name
  my $set_name = $ARGV[1];
  $sql = "SELECT set_name,biosequence_set_id" .
         "  FROM ${DATABASE}biosequence_set";
  #print "SQL: $sql\n";
  my %set_names = $sbeams->selectTwoColumnHash($sql);
  my $biosequence_set_id = $set_names{$set_name};


  #### If we didn't find it then bail
  unless ($biosequence_set_id) {
    bail_out("Unable to determine a biosequence_set_id for '$set_name'.  " .
      "A record for this biosequence_set must already have been entered " .
      "before the sequences may be loaded.");
  }


  #### Test if there are already sequences for this biosequence_set
  $sql = "SELECT COUNT(*) FROM ${DATABASE}biosequence ".
         " WHERE biosequence_set_id = '$biosequence_set_id'";
  my ($count) = $sbeams->selectOneColumn($sql);
  if ($count) {
    if ($delete_existing) {
      $sql = "DELETE FROM ${DATABASE}biosequence ".
             " WHERE biosequence_set_id = '$biosequence_set_id'";
      $sbeams->executeSQL($sql);
    } elsif (!($update_existing)) {
      bail_out("There are already biosequence records for this " .
        "biosequence_set.\nPlease delete those records before trying to load " .
        "new sequences,\nor specify the --delete_existing ".
        "or --update_existing flags.");
    }
  }


  #### Open annotation file and load data
  unless (open(INFILE,"$source_file")) {
    bail_out("Cannot open file '$source_file'");
  }


  #### Definitions for loop
  my ($biosequence_id,$biosequence_name,$biosequence_desc,$biosequence_seq);
  my $counter = 0;
  my ($information,$sequence,$insert,$update);
  $information = "####";


  #### Loop over all data in the file
  my $loopflag = 1;
  while ($loopflag) {

    #### At the end of file, set loopflag to 0, but finish this loop, writing
    #### the last entry to the database
    unless ($line=<INFILE>) {
      $loopflag = 0;
      $line = ">BOGUS DESCRIPTION";
    }

    #### Strip CRs of all flavors
    $line =~ s/[\n\r]//g;

    #### If the line begins with ">" and it's not the first, write the
    #### previous sequence to the database
    if (($line =~ /^>/) && ($information ne "####")) {
      my %rowdata;
      #$information =~ /^>(\S+)/;
      #$rowdata{biosequence_name} = $1;
      $information =~ /^>ORFN:(\S+)\s(\S+),\sChr\s\S+\sfrom\s(\d+)\-(\d+)/ ; #,\sChr\s\S\sfrom\s(\d)\-(\d)/;
      $rowdata{biosequence_name} = $1;
      $rowdata{biosequence_desc} = $2;
      $rowdata{biosequence_gene_name} = $1;
      $rowdata{biosequence_start} = $3;
      $rowdata{biosequence_length} = $4-$3;

      #print "$1 $2 $3 $4 $rowdata{biosequence_length}\n";

      $rowdata{biosequence_set_id} = $biosequence_set_id;
      $rowdata{biosequence_seq} = $sequence unless ($skip_sequence);

      #### Do special parsing depending on which genome set is being loaded
      $result = specialParsing(biosequence_set_name=>$set_name,
        rowdata_ref=>\%rowdata);


      #### If we're updating, then try to find the appropriate record
      #### The whole program could be sped up quite a bit by doing a single
      #### select and returning a single hash at the beginning of the program
      $insert = 1; $update = 0;
      if ($update_existing) {
        $biosequence_id = get_biosequence_id(
          biosequence_set_id => $biosequence_set_id,
          biosequence_name => $rowdata{biosequence_name});
        if ($biosequence_id > 0) {
          $insert = 0; $update = 1;
        } else {
          print "WARNING: biosequence_name = '$rowdata{biosequence_name}' ".
            "was not found in the database, so I'm INSERTing it instead of ".
            "UPDATing as one might have expected\n";
        }
      }


      #### Insert the data into the database
      $result = $sbeams->insert_update_row(insert=>$insert,update=>$update,
        table_name=>"${DATABASE}biosequence",
        rowdata_ref=>\%rowdata,PK=>"biosequence_id",
        PK_value => $biosequence_id,
        #,verbose=>1,testonly=>1
        );

      #### Reset temporary holders
      $information = "";
      $sequence = "";


      #### Print some counters for biosequences INSERTed/UPDATEd
      #last if ($counter > 5);
      $counter++;
      print "$counter..." if ($counter % 100 == 0);

    }


    #### If the line begins with ">" then parse it
    if ($line =~ /^>/) {
      $information = $line;
      $sequence = "";
    #### Otherwise, it must be sequence data
    } else {
      $sequence .= $line;
    }


  }


  close(INFILE);
  print "\n$counter rows INSERT/UPDATed\n";

}


###############################################################################
###############################################################################
###############################################################################
###############################################################################


###############################################################################
# bail_out() subroutine - print error code and string, then exit
###############################################################################
sub bail_out {
  my ($message) = shift;
  print scalar localtime(),": ERROR in [$PROG_NAME]:\n$message\n";
  print "DBI State: $DBI::err ($DBI::errstr)\n";
  exit 0;
}


###############################################################################
# additionalParsing: fill in the gene_name and accession fields based on
#                    data in the id and description, depending on particular
#                    set being loaded.
###############################################################################
sub specialParsing {
  my %args = @_;
  my $SUB_NAME = "specialParsing";


  #### Decode the argument list
  my $biosequence_set_name = $args{'biosequence_set_name'}
   || die "ERROR[$SUB_NAME]: biosequence_set_name not passed";
  my $rowdata_ref = $args{'rowdata_ref'}
   || die "ERROR[$SUB_NAME]: rowdata_ref not passed";


  #### Define a few variables
  my ($n_other_names,@other_names);


  #### Special conversion rules for Drosophila genome, e.g.:
  #### >Scr|FBgn0003339|CT1096|FBan0001030 "transcription factor" mol_weight=44264  located on: 3R 84A6-84B1; 
  if ($biosequence_set_name eq "Drosophila aa_gadfly Database") {
    @other_names = split('\|',$rowdata_ref->{biosequence_name});
    $n_other_names = scalar(@other_names);
    if ($n_other_names > 1) {
       $rowdata_ref->{biosequence_gene_name} = $other_names[0];
       $rowdata_ref->{biosequence_accession} = $other_names[1];
    }
  }


  #### Special conversion rules for Human Contig, e.g.:
  #### >Contig109 fasta_990917.300k.no_chimeric_4.Contig38095 1 767 REPEAT: 15 318 REPEAT: 320 531 REPEAT: 664 765


  #### Special conversion rules for NRP, e.g.:
  #### >SWN:AAC2_MOUSE Q9ji91 mus musculus (mouse). alpha-actinin 2 (alpha actinin skeletal muscle isoform 2) (f-actin cross linking protein). 8/2001


  #### Special conversion rules for Yeast genome, e.g.:
  #### >ORFN:YAL014C YAL014C, Chr I from 128400-129017, reverse complement
  if ($biosequence_set_name eq "yeast_orf_coding") {
    if ($rowdata_ref->{biosequence_desc} =~ /([\w-]+), .+/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
    }
  }


  #### Special conversion rules for Halobacterium genome, e.g.:
  #### >gene-275_2467-rpl31e
  if ($biosequence_set_name eq "halobacterium_orf_coding") {
    if ($rowdata_ref->{biosequence_name} =~ /-(\w+)$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
    }
  }


  #### Special conversion rules for Human genome, e.g.:
  #### >gnl|UG|Hs#S35 Human mRNA for ferrochelatase (EC 4.99.1.1) /cds=(29,1300) /gb=D00726 /gi=219655 /ug=Hs.26 /len=2443
  if ($biosequence_set_name eq "Human unique sequences") {
    if ($rowdata_ref->{biosequence_desc} =~ /\/gi=(\d+) / ) {
       $rowdata_ref->{biosequence_accession} = $1;
    }
    if ($rowdata_ref->{biosequence_name} =~ /\|(Hs\S+)$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
    }
  }


}


###############################################################################
# get_biosequence_id: Obtain the biosequence_id from the available parameters
###############################################################################
sub get_biosequence_id {
  my %args = @_;
  my $SUB_NAME = "get_biosequence_id";


  #### Decode the argument list
  my $biosequence_set_id = $args{'biosequence_set_id'}
   || die "ERROR[$SUB_NAME]: biosequence_set_id not passed";
  my $biosequence_name = $args{'biosequence_name'}
   || die "ERROR[$SUB_NAME]: biosequence_name not passed";
  $biosequence_name =~ s/'/''/g;


  my $sql = "SELECT biosequence_id" .
           "  FROM ${DATABASE}biosequence".
           " WHERE biosequence_set_id = '$biosequence_set_id'".
           "   AND biosequence_name = '$biosequence_name'";
  #print "SQL: $sql\n";
  my @biosequence_ids = $sbeams->selectOneColumn($sql);

  my $count = @biosequence_ids;
  if ($count > 1) {
    die "ERROR[$SUB_NAME]: multiple biosequence_id's returned from by\n$sql\n".
      "This should be impossible!";
  }

  return $biosequence_ids[0];

}


