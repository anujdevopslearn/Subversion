#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_biosequence_set.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads a biosequence set (gene library) from a
#               FASTA file.  Note that there may be some cusomtization for
#               the particular library to populate gene_name and accesssion
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
	     $TESTONLY
             $current_contact_id $current_username
	     $fav_codon_frequency
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::Proteomics::Utilities;

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n          Set verbosity level.  default is 0
  --quiet              Set flag to print nothing at all except errors
  --debug n            Set debug flag
  --testonly           If set, rows in the database are not changed or added
  --delete_existing    Delete the existing biosequences for this set before
                       loading.  Normally, if there are existing biosequences,
                       the load is blocked.
  --update_existing    Update the existing biosequence set with information
                       in the file
  --skip_sequence      If set, only the names, descs, etc. are loaded;
                       the actual sequence (often not really necessary)
                       is not written
  --set_tag            The set_tag of a biosequence_set that is to be worked
                       on; all are checked if none is provided
  --file_prefix        A prefix that is prepended to the set_path in the
                       biosequence_set table
  --check_status       Is set, nothing is actually done, but rather the
                       biosequence_sets are verified
  --codon_bias_file    Full path name of a file from which to load codon
                       bias values
  --calc_n_transmembrane_regions
                       Set flag to add in n_transmembrane_regions calculations

 e.g.:  $PROG_NAME --check_status

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "delete_existing","update_existing","skip_sequence",
  "set_tag:s","file_prefix:s","check_status","codon_bias_file:s",
  "calc_n_transmembrane_regions")) {
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

  #### Try to determine which module we want to affect
  my $module = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ($module eq 'Proteomics') {
    $work_group = "${module}_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Biosap') {
    $work_group = "Biosap";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'SNP') {
    $work_group = "SNP";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Microarray') {
    $work_group = "Arrays";
    $DATABASE = $DBPREFIX{$module};
  }


  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>$work_group,
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
  my $delete_existing = $OPTIONS{"delete_existing"} || '';
  my $update_existing = $OPTIONS{"update_existing"} || '';
  my $skip_sequence = $OPTIONS{"skip_sequence"} || '';
  my $check_status = $OPTIONS{"check_status"} || '';
  my $set_tag = $OPTIONS{"set_tag"} || '';
  my $file_prefix = $OPTIONS{"file_prefix"} || '';
  my $codon_bias_file = $OPTIONS{"codon_bias_file"} || '';

  #### Get the file_prefix if it was specified, and otherwise guess
  unless ($file_prefix) {
    my $module = $sbeams->getSBEAMS_SUBDIR();
    $file_prefix = '/regis' if ($module eq 'Proteomics');
  }


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Define a scalar and array of biosequence_set_id's
  my ($biosequence_set_id,$n_biosequence_sets);
  my @biosequence_set_ids;


  #### If there was a set_tag specified, identify it
  if ($set_tag) {
    $sql = qq~
          SELECT BSS.biosequence_set_id
            FROM ${DATABASE}biosequence_set BSS
           WHERE BSS.set_tag = '$set_tag'
             AND BSS.record_status != 'D'
    ~;

    @biosequence_set_ids = $sbeams->selectOneColumn($sql);
    $n_biosequence_sets = @biosequence_set_ids;

    die "No biosequence_sets found with set_tag = '$set_tag'"
      if ($n_biosequence_sets < 1);
    die "Too many biosequence_sets found with set_tag = '$set_tag'"
      if ($n_biosequence_sets > 1);


  #### If there was NOT a set_tag specified, scan for all available ones
  } else {
    $sql = qq~
          SELECT biosequence_set_id
            FROM ${DATABASE}biosequence_set
           WHERE record_status != 'D'
    ~;

    @biosequence_set_ids = $sbeams->selectOneColumn($sql);
    $n_biosequence_sets = @biosequence_set_ids;

    die "No biosequence_sets found in this database"
      if ($n_biosequence_sets < 1);

  }


  #### If a codon bias file was specified, load it for later processing
  if ($codon_bias_file) {
    $fav_codon_frequency->{zzzHASH} = -1;
    readCodonBiasFile(
      source_file => $codon_bias_file,
      fav_codon_frequency => $fav_codon_frequency);
  }
  #### Loop over each biosequence_set, determining its status and processing
  #### it if desired
  print "        set_tag      n_rows  set_path\n";
  print "---------------  ----------  -----------------------------------\n";
  foreach $biosequence_set_id (@biosequence_set_ids) {
    my $status = getBiosequenceSetStatus(
      biosequence_set_id => $biosequence_set_id);
    printf("%15s  %10d  %s\n",$status->{set_tag},$status->{n_rows},
      $status->{set_path});

    #### If we're not just checking the status
    unless ($check_status) {
      my $do_load = 0;
      $do_load = 1 if ($status->{n_rows} == 0);
      $do_load = 1 if ($update_existing);
      $do_load = 1 if ($delete_existing);

      #### If it's determined that we need to do a load, do it
      if ($do_load) {
        $result = loadBiosequenceSet(set_name=>$status->{set_name},
          source_file=>$file_prefix.$status->{set_path});
      }
    }
  }


  return;

}



###############################################################################
# getBiosequenceSetStatus
###############################################################################
sub getBiosequenceSetStatus { 
  my %args = @_;
  my $SUB_NAME = 'getBiosequenceSetStatus';


  #### Decode the argument list
  my $biosequence_set_id = $args{'biosequence_set_id'}
   || die "ERROR[$SUB_NAME]: biosequence_set_id not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Get information about this biosequence_set_id from database
  $sql = qq~
          SELECT BSS.biosequence_set_id,set_name,set_tag,set_path,set_version
            FROM ${DATABASE}biosequence_set BSS
           WHERE BSS.biosequence_set_id = '$biosequence_set_id'
             AND BSS.record_status != 'D'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);


  #### Put the information in a hash
  my %status;
  $status{biosequence_set_id} = $rows[0]->[0];
  $status{set_name} = $rows[0]->[1];
  $status{set_tag} = $rows[0]->[2];
  $status{set_path} = $rows[0]->[3];
  $status{set_version} = $rows[0]->[4];


  #### Get the number of rows for this biosequence_set_id from database
  $sql = qq~
          SELECT count(*) AS 'count'
            FROM ${DATABASE}biosequence BS
           WHERE BS.biosequence_set_id = '$biosequence_set_id'
  ~;
  my ($n_rows) = $sbeams->selectOneColumn($sql);


  #### Put the information in a hash
  $status{n_rows} = $n_rows;


  #### Return information
  return \%status;

}


###############################################################################
# loadBiosequenceSet
###############################################################################
sub loadBiosequenceSet { 
  my %args = @_;
  my $SUB_NAME = 'loadBiosequenceSet';


  #### Decode the argument list
  my $set_name = $args{'set_name'}
   || die "ERROR[$SUB_NAME]: biosequence_set_id not passed";
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"};
  my $update_existing = $OPTIONS{"update_existing"};
  my $skip_sequence = $OPTIONS{"skip_sequence"};


  #### Verify the source_file
  unless ( -e "$source_file" ) {
    die("ERROR[$SUB_NAME]: Cannot find file $source_file");
  }


  #### Set the set_name
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
      print "Deleting...\n$sql\n";
      $sql = "DELETE FROM ${DATABASE}biosequence ".
             " WHERE biosequence_set_id = '$biosequence_set_id'";
      $sbeams->executeSQL($sql);
    } elsif (!($update_existing)) {
      die("There are already biosequence records for this " .
        "biosequence_set.\nPlease delete those records before trying to load " .
        "new sequences,\nor specify the --delete_existing ".
        "or --update_existing flags.");
    }
  }


  #### Open annotation file and load data
  unless (open(INFILE,"$source_file")) {
    die("Cannot open file '$source_file'");
  }


  #### Create a hash to store biosequence_names that have been seen
  my %biosequence_names;


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
    unless (defined($line=<INFILE>)) {
      $loopflag = 0;
      $line = ">BOGUS DESCRIPTION";
    }

    #### Strip CRs of all flavors
    $line =~ s/[\n\r]//g;

    #### If the line begins with ">" and it's not the first, write the
    #### previous sequence to the database
    if (($line =~ /^>/) && ($information ne "####")) {
      my %rowdata;
      $information =~ /^>(\S+)/;
      $rowdata{biosequence_name} = $1;
      $information =~ /^>(\S+)\s(.+)/;
      $rowdata{biosequence_desc} = $2 || '';
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
        if (defined($biosequence_id) && $biosequence_id > 0) {
          $insert = 0; $update = 1;
        } else {
          print "WARNING: INSERTing instead of UPDATing ".
            "'$rowdata{biosequence_name}'\n";
        }
      }



      #### Verify that we haven't done this one already
      if ($biosequence_names{$rowdata{biosequence_name}}) {
        print "\nWARNING: Duplicate biosequence_name ".
          "'$rowdata{biosequence_name}'in file!  Skipping the duplicate.\n";

      } else {
        #### Insert the data into the database
        loadBiosequence(insert=>$insert,update=>$update,
          table_name=>"${DATABASE}biosequence",
          rowdata_ref=>\%rowdata,PK=>"biosequence_id",
          PK_value => $biosequence_id,
          verbose=>$VERBOSE,
	  testonly=>$TESTONLY,
          );

        $counter++;
      }


      #### Reset temporary holders
      $information = "";
      $sequence = "";

      #### Add this one to the list of already seen
      $biosequence_names{$rowdata{biosequence_name}} = 1;

      #### Print some counters for biosequences INSERTed/UPDATEd
      #last if ($counter > 5);
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
# loadBiosequence
###############################################################################
sub loadBiosequence {
  my %args = @_;
  my $SUB_NAME = "loadBiosequence";

  #### Decode the argument list
  my $insert   = $args{'insert'}   || 0;
  my $update   = $args{'update'}   || 0;
  my $PK       = $args{'PK_name'}  || $args{'PK'} || '';
  my $PK_value = $args{'PK_value'} || '';

  my $rowdata_ref = $args{'rowdata_ref'}
  || die "ERROR[$SUB_NAME]: rowdata not passed!";
  my $table_name = $args{'table_name'} 
  || die "ERROR[$SUB_NAME]:table_name not passed!";


  #### Get the file_prefix if it was specified, and otherwise guess
  my $module = $sbeams->getSBEAMS_SUBDIR();

  #### Microarray uses the new schema and this is just a quick hack to get it
  #### working.  This will  need to populate biosequence_external_xref in the
  #### future, using an INSERT, INSERT, UPDATE triplet for new sequences.
  #### FIX ME!!!
  if ($module eq 'Microarray') {
      #print "$rowdata_ref->{dbxref_id}\t";
      delete ($rowdata_ref->{biosequence_accession});
      delete ($rowdata_ref->{dbxref_id});
  }


  #### If the biosequence_desc bloats beyond 1024, limit it
  if (length($rowdata_ref->{biosequence_desc}) > 1024) {
    print "\nWARNING: truncanting description for ".
      $rowdata_ref->{biosequence_name}." to 1024 characters\n";
    $rowdata_ref->{biosequence_desc} = substr($rowdata_ref->{biosequence_desc},
      0,1024);
  }

  #### INSERT/UPDATE the row
  my $result = $sbeams->insert_update_row(insert=>$insert,
					  update=>$update,
					  table_name=>$table_name,
					  rowdata_ref=>$rowdata_ref,
					  PK=>$PK,
					  PK_value => $PK_value,
					  verbose=>$VERBOSE,testonly=>$TESTONLY
					  );

  return;
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


  #### Encoding popular among a bunch of databases
  #### Can be overridden later on a case-by-case basis
  if ($rowdata_ref->{biosequence_name} =~ /^SW.{0,1}\:(.+)$/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '1';
  }

  if ($rowdata_ref->{biosequence_name} =~ /^PIR.\:(.+)$/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '6';
  }

  if ($rowdata_ref->{biosequence_name} =~ /^GP.{0,1}\:(.+)_\d$/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '8';
  }


  #### Conversion rules for the IPI database
  if ($rowdata_ref->{biosequence_name} =~ /^IPI:(IPI[\d\.]+)$/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '9';
  }



  #### Special conversion rules for Drosophila genome, e.g.:
  #### >Scr|FBgn0003339|CT1096|FBan0001030 "transcription factor" mol_weight=44264  located on: 3R 84A6-84B1; 
  if ($biosequence_set_name eq "Drosophila aa_gadfly Database" ||
      $biosequence_set_name eq "Drosophila na_gadfly Nucleotide Database") {
    @other_names = split('\|',$rowdata_ref->{biosequence_name});
    $n_other_names = scalar(@other_names);
    if ($n_other_names > 1) {
       $rowdata_ref->{biosequence_gene_name} = $other_names[0];
       $rowdata_ref->{biosequence_accession} = $other_names[1];
       $rowdata_ref->{dbxref_id} = '2';
    }
  }


  #### Special conversion rules for Human Contig, e.g.:
  #### >Contig109 fasta_990917.300k.no_chimeric_4.Contig38095 1 767 REPEAT: 15 318 REPEAT: 320 531 REPEAT: 664 765


  #### Special conversion rules for NRP, e.g.:
  #### >SWN:AAC2_MOUSE Q9ji91 mus musculus (mouse). alpha-actinin 2 (alpha actinin skeletal muscle isoform 2) (f-actin cross linking protein). 8/2001


  #### Special conversion rules for Human NCI, e.g.:
  #### >SWN:3BP1_HUMAN Q9y3l3 homo sapiens (human). sh3-domain binding protein 1 (3bp-1). 3/2002 [MASS=66765]
  #### >SW:AKA7_HUMAN O43687 homo sapiens (human). a-kinase anchor protein 7 (a-kinase anchor protein 9 kda). 5/2000 [MASS=8838]
  #### >PIR1:SNHUC3 multicatalytic endopeptidase complex (EC 3.4.99.46) chain C3 - human [MASS=25899]
  #### >PIR2:S17526 aconitate hydratase (EC 4.2.1.3) - human (fragments) [MASS=6931]
  #### >PIR4:T01781 probable pol protein pseudogene - human (fragment) [MASS=13740]
  #### >GPN:AF345332_1 Homo sapiens SWAN mRNA, complete cds; SH3/WW domain anchor protein in the nucleus. [MASS=97395]
  #### >GP:AF119839_1 Homo sapiens PRO0889 mRNA, complete cds; predicted protein of HQ0889. [MASS=6643]
  #### >GP:BC001812_1 Homo sapiens, clone IMAGE:2959521, mRNA, partial cds. [MASS=5769]
  #### >3D:2clrA HUMAN CLASS I HISTOCOMPATIBILITY ANTIGEN (HLA-A 0201) COMPLEXED WITH A DECAMERIC [MASS=31808]
  #### >TFD:TFDP00561 : HOX 2.2 ((human)) polypeptide [MASS=25574]
  if ($biosequence_set_name eq "Human NCI Database") {
    #### Nothing special, uses generic SW, PIR, etc. encodings above
  }


  #### Special conversion rules for Yeast NCI from regis, e.g.:
  #### SW:ACEA_YEAST P28240 saccharomyces cerevisiae (baker's yeast). isocitrate lyase (ec 4.1.3.1) (isocitrase) (isocitratase) (icl). 2/1996 [MASS=62409]

  if ($biosequence_set_name eq "Yeast NCI Database") {
    #### Nothing special, uses generic SW, PIR, etc. encodings above
  }

  if ($biosequence_set_name eq "ISB Yeast Database") {
      $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
  }

  #### Special conversion rules for Yeast genome, e.g.:
  #### >ORFN:YAL014C YAL014C, Chr I from 128400-129017, reverse complement
  if ($biosequence_set_name eq "yeast_orf_coding" || $biosequence_set_name eq "Yeast ORFs Database") {
    if ($rowdata_ref->{biosequence_desc} =~ /([\w\-]+)\s([\w\-\:]+), .+/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
       $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
       $rowdata_ref->{dbxref_id} = '7';
    }
  }

  #### Conversion Rules for SGD:
  #### >ORFN:YAL001C TFC3 SGDID:S0000001, Chr I from 147591-147660,147751-151163, reverse complement
  if ($biosequence_set_name eq "SGD Yeast ORF Database"){
    if ($rowdata_ref->{biosequence_desc} =~ /([\w-]+)\sSGDID\:([\w-]+), .+/ ) {
	$rowdata_ref->{biosequence_gene_name} = $1;
	$rowdata_ref->{biosequence_accession} = $2;
	$rowdata_ref->{dbxref_id} = '7';
    }
  }

  #### Special conversion rules for DQA, DBQ, DRB exons, e.g.:
  #### >DQB1_0612_exon1
  if ($biosequence_set_name =~ /Allelic exons/) {
    if ($rowdata_ref->{biosequence_name} =~ /^([A-Za-z0-9]+)_/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
    }
    $rowdata_ref->{biosequence_desc} = $rowdata_ref->{biosequence_name};
  }

  #### Special conversion rules for Halobacterium genome, e.g.:
  #### >gene-275_2467-rpl31e
  if ($biosequence_set_name eq "halobacterium_orf_coding") {
    if ($rowdata_ref->{biosequence_name} =~ /-(\w+)$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
   }
  }

  #### Special conversion rules for Human FASTA file, e.g.:
  ####>ACC:AA406372|zv10c10.s1 Soares_NhHMPu_S1 Homo sapiens cDNA clone IMAGE:753234 3' similar to gb:X59739_rna1 ZINC FINGER X-CHROMOSOMAL PROTEIN (HUMAN );, mRNA sequence.
  if ($biosequence_set_name eq "Human BioSequence Database") {
    if ($rowdata_ref->{biosequence_name} =~ /^ACC\:([\w-]+)\|/) {
	$rowdata_ref->{biosequence_gene_name} = $1;
	$rowdata_ref->{biosequence_accession} = $1;
	$rowdata_ref->{dbxref_id} = '8';
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


  #### If there's codon bias lookup information, set it
  if (defined($fav_codon_frequency)) {
    if ($fav_codon_frequency->{$rowdata_ref->{biosequence_name}}) {
      $rowdata_ref->{fav_codon_frequency} =
        $fav_codon_frequency->{$rowdata_ref->{biosequence_name}};
    }
  }


  #### If the calc_n_transmembrane_regions flag is set, do the calculation
  if (defined($OPTIONS{"calc_n_transmembrane_regions"}) &&
      defined($rowdata_ref->{biosequence_seq}) &&
      $rowdata_ref->{biosequence_seq} ) {
    $rowdata_ref->{n_transmembrane_regions} = 
      SBEAMS::Proteomics::Utilities::calcNTransmembraneRegions(
        peptide=>$rowdata_ref->{biosequence_seq},
        calc_method=>'NewMethod');
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
  $biosequence_name =~ s/\'/\'\'/g;


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


###############################################################################
# readCodonBiasFile
###############################################################################
sub readCodonBiasFile {
  my %args = @_;
  my $SUB_NAME = "readCodonBiasFile";


  #### Decode the argument list
  my $source_file = $args{'source_file'}
   || die "ERROR[$SUB_NAME]: source_file not passed";
  # Don't bother getting the output data struct since it's a global


  unless ( -f $source_file ) {
    $fav_codon_frequency->{return_status} = 'FAIL';
    die("Unable to find codon bias file '$source_file'");
  }


  open(CODONFILE,"$source_file") ||
    die("Unable to open codon bias file '$source_file'");


  #### Read the header column
  my $line;
  $line = <CODONFILE>;
  my $tmp;
  my $biosequence_name;
  my @columns;
  my @words;


  #### Read in all the data putting it into the hash
  print "Reading codon bias file...\n";
  while ($line = <CODONFILE>) {
    @columns = split("\t",$line);
    $tmp = $columns[3];
    @words = split(/\s/,$tmp);
    $biosequence_name = $words[0];
    $fav_codon_frequency->{$biosequence_name} = $columns[2];
  }

  close(CODONFILE);

  $fav_codon_frequency->{return_status} = 'SUCCESS';
  return;

}


