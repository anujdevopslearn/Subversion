#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_theo_proteotypic_scores.pl
# Author      : Ning Zhang <nzhang@systemsbiology.org>
# 
#
# Description : This script load the database for theoretical proteotypic scores
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TESTVARS $CHECKTABLES
            );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --testonly             If set, rows in the database are not changed or added
  --list                 If set, list the available builds and exit
  --delete_set           If set, will delete the records of of specific biosequence set in the table
  --set_tag              Name of the biosequence set tag  
  --input_file           Name of the file that has Parag and Indiana scores
  

 e.g.: $PROG_NAME --list
       $PROG_NAME --set_tag \'YeastCombNR_20070207_ForwDecoy\' --input_file \'proteotypic_peptide.txt\'
       $PROG_NAME --delete_set \'YeastCombNR_20070207_ForwDecoy\'
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
		   "list","delete:s","set_tag:s","input_file:s",
		  )) {

  die "\n$USAGE";

}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";

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
  exit unless (
    $current_username = $sbeams->Authenticate(
      work_group=>'PeptideAtlas_admin')
  );

  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  my %args = @_;

  ##### PROCESS COMMAND LINE OPTIONS AND RESTRICTIONS #####

  #### Set the command-line options
  my $bioseq_set_tag = $OPTIONS{"set_tag"};
  my $delete_set_tag = $OPTIONS{"delete_set"};
  my $input_file = $OPTIONS{"input_file"};


  #### If there are any unresolved parameters, exit
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }


  #### If a listing was requested, list and return
  if ($OPTIONS{"list"}) {
    use SBEAMS::PeptideAtlas::AtlasBuild;
    my $builds = new SBEAMS::PeptideAtlas::AtlasBuild();
    $builds->setSBEAMS($sbeams);
    $builds->listBuilds();
    return;
  }


  #### Verify that bioseq_seq_tag was supplied
  my $bioseq_set_id = getBioseqSetID(set_tag => $bioseq_set_tag,);
  print "bioseq_set_id $bioseq_set_id\n";
  unless ($bioseq_set_id) {
    print "\nERROR: couldn't find the bioseq set --$bioseq_set_tag\n\n";
    die "\n$USAGE";
  }


  #### Get the atlas_build_id for the name
  #my $atlas_build_id = getAtlasBuildID(bioseq_set_id => $bioseq_set_id,);

  #unless ($atlas_build_id) {
  #  die("ERROR: Unable to find the atlas_build_id for corresponding bioseq_set ".
 #	"$bioseq_set_tag.  Use --list to see a listing");
 # }


  #### If specified, read the file in to fill the table
  
  if ($input_file) {
    fillTable(
	      bioseq_set_id => $bioseq_set_id,
	      source_file => $input_file,
	     );
  }

  if($delete_set_tag){
    my $delete_bioseq_set_id = getBioseqSetID(set_tag => $delete_set_tag,);
    deleteTable(bioseq_set_id => $delete_bioseq_set_id,);
  }


  return;

} # end handleRequest

##############################################################################
#getBioseqSetID  -- return a bioseq_set_id
##############################################################################
sub getBioseqSetID {
  my $SUB = 'getBioseqSetID';
  my %args = @_;

  print "INFO[$SUB] Getting bioseq_set_id....." if ($VERBOSE);
  my $bioseq_set_tag = $args{set_tag} or
    die("ERROR[$SUB]: parameter set_tag not provided");
  
  my $sql = qq~
    SELECT biosequence_set_id
      FROM $TBAT_BIOSEQUENCE_SET
     WHERE set_tag = '$bioseq_set_tag'
  ~;

  

  my ($bioseq_set_id) = $sbeams->selectOneColumn($sql);

  print "bioseq_set_id: $bioseq_set_id\n" if ($VERBOSE);
  return $bioseq_set_id;
}

###############################################################################
# getAtlasBuildID -- Return an atlas_build_id
###############################################################################
sub getAtlasBuildID {
  my $SUB = 'getAtlasBuildID';
  my %args = @_;

  print "INFO[$SUB] Getting atlas_build_id..." if ($VERBOSE);

  my $bioseq_set_id  = $args{bioseq_set_id} or
    die("ERROR[$SUB]: parameter bioseq_set_id not provided");

  my $sql = qq~
    SELECT atlas_build_id,atlas_build_name
      FROM $TBAT_ATLAS_BUILD
     WHERE record_status != 'D'
           AND biosequence_set_id = '$bioseq_set_id'
     ORDER BY atlas_build_name
  ~;

  my ($atlas_build_id) = $sbeams->selectOneColumn($sql);

  print "$atlas_build_id\n" if ($VERBOSE);
  return $atlas_build_id;

} # end getAtlasBuildID



###############################################################################
# fillTable, fill $TBAT_proteotypic_peptide
###############################################################################
sub fillTable{
  my $SUB = 'fillTable';
  my %args = @_;

  my $bioseq_set_id = $args{bioseq_set_id};
  
  my $source_file = $args{source_file} or
    die("ERROR[$SUB]: parameter source_file not provided");

  unless ( -e $source_file ) {
    die("ERROR[$SUB]: Cannot find file '$source_file'");
  }

  #first get bioseq_name and bioseq_id using $bioseq_set_id
  my $sql = qq~
     SELECT biosequence_name, biosequence_id
       FROM $TBAT_BIOSEQUENCE
      WHERE biosequence_set_id = '$bioseq_set_id'
  ~;

  my %bioseq_hash = $sbeams->selectTwoColumnHash($sql);

  #then get pepseq and pepid
  $sql = qq~
  SELECT peptide_sequence, peptide_id
    FROM $TBAT_PEPTIDE
  ~;

  my %pepseq_hash = $sbeams->selectTwoColumnHash($sql);

  #Then loop over the $source_file

  open(INFILE,$source_file) or
    die("ERROR[$SUB]: Cannot open file '$source_file'");

  my $line;
  my $proName;
  my $prevAA;
  my $pepSeq;
  my $endAA;
  my $paragScoreESI;
  my $paragScoreICAT;
  my $indianaScore;

  while ($line = <INFILE>) {
    chomp($line);
    my @columns = split("\t",$line);
    $proName = $columns[0];
    $prevAA = $columns[1];
    $pepSeq = $columns[2];
    $endAA = $columns[3];
    $paragScoreESI = $columns[4];
    $paragScoreICAT = $columns[5];
    $indianaScore = $columns[6];

    #print "proName $proName\n";
    my $matched_bioseq_id;

    #get biosequence_id
    
    $matched_bioseq_id = $bioseq_hash{$proName};
 
  
    #print "matched_bioseq_id $matched_bioseq_id\n";
    #now need to get $matched_pep_id
    my $matched_pep_id;
    
    $matched_pep_id = $pepseq_hash{$pepSeq};
      
    
    my %rowdata=(
		 source_biosequence_id=>$matched_bioseq_id,
		 matched_peptide_id=>$matched_pep_id,
		 preceding_residue=>$prevAA,
		 peptide_sequence=>$pepSeq,
		 following_residue=>$endAA,
		 peptidesieve_ESI=>$paragScoreESI,
		 peptidesieve_ICAT=>$paragScoreICAT,
		 detectabilitypredictor_score=>$indianaScore,
		);
    
    $sbeams->updateOrInsertRow(
			       insert=>1,
			       table_name=>$TBAT_PROTEOTYPIC_PEPTIDE,
			       rowdata_ref=>\%rowdata,
			       verbose=>$VERBOSE,
			       testonly=>$TESTONLY,
			      );
  }

  close(INFILE);



} # end fillTable




