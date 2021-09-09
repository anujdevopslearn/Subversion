#!/usr/local/bin/perl -w

###############################################################################
# Program     : updateProteotypicScores.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: load_atlas_build.pl 3719 2005-07-22 03:36:26Z nking $
#
# Description : This script updates the database for proteotypic scores
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
             $ATLAS_BUILD_ID
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
  --atlas_build_name     Name of the atlas build to process
  --export_file          Name of the file into which to export protein names
                         and peptide sequences, suitable to use with Parag
                         Mallick's proteotypic calculator
  --update_observed      If set, empirical proteotypic scores are calculated
  --proteotypic_file     overrides default proteotypic file names.

 e.g.: $PROG_NAME --list
       $PROG_NAME --atlas_build_name \'Human_P0.9_Ens26_NCBI35\'
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "list","atlas_build_name:s","export_file:s","update_observed",
        "proteotypic_file:s",
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
  my $atlas_build_name = $OPTIONS{"atlas_build_name"};


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


  #### Verify that atlas_build_name was supplied
  unless ($atlas_build_name) {
    print "\nERROR: You must specify an --atlas_build_name\n\n";
    die "\n$USAGE";
  }


  #### Get the atlas_build_id for the name
  my $atlas_build_id = getAtlasBuildID(
    atlas_build_name => $atlas_build_name,
  );
  unless ($atlas_build_id) {
    die("ERROR: Unable to find the atlas_build_id for atlas_build_name ".
	"$atlas_build_name.  Use --list to see a listing");
  }

  my $msg = $sbeams->update_PA_table_variables($atlas_build_id);

  #### If specified, export the build for proteotypic calculation
  my $export_file = $OPTIONS{export_file};
  if ($export_file) {
    exportForProteotypicCalculation(
      atlas_build_id => $atlas_build_id,
      export_file => $export_file,
    );
  }


  #### If specified, update the empirical proteotypic scores
  if ($OPTIONS{update_observed}) {
    updateObservedProteotypicScores(
      atlas_build_id => $atlas_build_id,
      %OPTIONS
    );
  }

  return;

} # end handleRequest



###############################################################################
# getAtlasBuildID -- Return an atlas_build_id
###############################################################################
sub getAtlasBuildID {
  my $SUB = 'getAtlasBuildID';
  my %args = @_;

  print "INFO[$SUB] Getting atlas_build_id..." if ($VERBOSE);

  my $atlas_build_name = $args{atlas_build_name} or
    die("ERROR[$SUB]: parameter atlas_build_name not provided");

  my $sql = qq~
    SELECT atlas_build_id,atlas_build_name
      FROM $TBAT_ATLAS_BUILD
     WHERE record_status != 'D'
           AND atlas_build_name = '$atlas_build_name'
     ORDER BY atlas_build_name
  ~;

  my ($atlas_build_id) = $sbeams->selectOneColumn($sql);

  print "$atlas_build_id\n" if ($VERBOSE);
  return $atlas_build_id;

} # end getAtlasBuildID



###############################################################################
# exportForProteotypicCalculation -- Export the build to a format suitable
#     for use with Parag's Proteotypic calculator
###############################################################################
sub exportForProteotypicCalculation {
  my $SUB = 'exportForProteotypicCalculation';
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  my $export_file = $args{export_file} or
    die("ERROR[$SUB]: parameter export_file not provided");


  my $peptides = getAllPeptides(
    atlas_build_id => $atlas_build_id,
  );

  my $n_peptides;
  unless ($peptides && scalar(@{$peptides})) {
    die("ERROR[$SUB]: No peptides returned from getAllPeptides()");
  }

  print scalar(@{$peptides})." peptides returned\n";

  open(OUTFILE,">$export_file") or
    die("ERROR[$SUB]: Unable to write to '$export_file'");

  foreach my $peptide ( @{$peptides} ) {
    print OUTFILE "$peptide->[0]\t$peptide->[1]\n";
  }

  close(OUTFILE);

  return;

} # end exportForProteotypicCalculation



###############################################################################
# getAllPeptides -- Get all of the peptides for this build
###############################################################################
sub getAllPeptides {
  my $SUB = 'getAllPeptides';
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  print "INFO[$SUB] Getting all peptides for build $atlas_build_id...\n"
    if ($VERBOSE);


  #### SQL to get all the peptide mappings
  my $sql = qq~
     SELECT PI.peptide_instance_id,
            PI.preceding_residue || P.peptide_sequence || PI.following_residue
       FROM $TBAT_PEPTIDE_INSTANCE PI
      INNER JOIN $TBAT_PEPTIDE P
            ON ( PI.peptide_id = P.peptide_id )
      WHERE 1 = 1
        AND PI.atlas_build_id = '$atlas_build_id'
      ORDER BY PI.peptide_instance_id
  ~;

  my @peptides = $sbeams->selectSeveralColumns($sql);

  return \@peptides;

} # end getAllPeptides


###############################################################################
# getAllPeptideMappings -- Get all of the peptides mappings for this build
###############################################################################
sub getAllPeptideMappings {
  my $SUB = 'getAllPeptideMappings';
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  print "INFO[$SUB] Getting all peptides for build $atlas_build_id...\n"
    if ($VERBOSE);

  my $sql = qq~
      SELECT PI.peptide_instance_id ,PIS.sample_id
      FROM $TBAT_PEPTIDE_INSTANCE PI
      JOIN $TBAT_PEPTIDE_INSTANCE_SAMPLE PIS ON (PIS.PEPTIDE_INSTANCE_ID = PI.PEPTIDE_INSTANCE_ID)
      WHERE PI.atlas_build_id = '$atlas_build_id'
  ~;
  my $sth = $sbeams->get_statement_handle($sql);
  my %pi_sample_id=();
  while( my @row = $sth->fetchrow_array() ) { 
    my ($peptide_instance_id, $sample_id) = @row;
    $pi_sample_id{$peptide_instance_id}{$sample_id} =1;
  }
  #### SQL to get all the peptide mappings
   $sql = qq~
     SELECT distinct PI.peptide_instance_id,BS.biosequence_name,
            PI.original_protein_name,
            PI.preceding_residue || P.peptide_sequence || PI.following_residue
       FROM $TBAT_PEPTIDE_INSTANCE PI
      INNER JOIN $TBAT_PEPTIDE P
            ON ( PI.peptide_id = P.peptide_id )
       LEFT JOIN $TBAT_PEPTIDE_MAPPING PM
            ON ( PI.peptide_instance_id = PM.peptide_instance_id )
       LEFT JOIN $TBAT_BIOSEQUENCE BS
            ON ( PM.matched_biosequence_id = BS.biosequence_id )
      WHERE 1 = 1
        AND PI.atlas_build_id = '$atlas_build_id'
  ~;
  $sth = $sbeams->get_statement_handle($sql);
  
  my @peptide_mappings =();
  while( my @row = $sth->fetchrow_array() ) { 
    my ($peptide_instance_id, $prot, $ori_prot,$seq) =@row;
    $prot = '' unless $prot;
    my $ids = join(",", keys %{$pi_sample_id{$peptide_instance_id}});;
    push @peptide_mappings, [($peptide_instance_id,$prot,$ori_prot,$ids,$seq)]; 
  }

  return \@peptide_mappings;

} # end getAllPeptideMappings


###############################################################################
# updateObservedProteotypicScores
###############################################################################
sub updateObservedProteotypicScores {
  my $SUB = 'updateObservedProteotypicScores';
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  my $peptides = getAllPeptideMappings(
    atlas_build_id => $atlas_build_id,
  );

  my $n_peptides;
  unless ($peptides && scalar(@{$peptides})) {
    die("ERROR[$SUB]: No peptides returned from getAllPeptides()");
  }

  print scalar(@{$peptides})." peptides returned\n";

  my ($protein,$search_batch_id,$search_batch_ids);
  my %proteins;

  #### First figure out how many samples saw this protein
  foreach my $peptide ( @{$peptides} ) {

    #### Determine the mapped or else original protein name
    $protein = $peptide->[1];
    unless ($protein) {
      $protein = $peptide->[2];
    }

    #### Get the list of search_batch_ids and build them by protein
    $search_batch_ids = $peptide->[3];
    my @search_batch_ids = split(",",$search_batch_ids);
    foreach $search_batch_id ( @search_batch_ids ) {
      $proteins{$protein}->{$search_batch_id} = 1;
    }

  }


  my %peptide_scores;

  #### Now loop over each peptide and calculate proteotypic score
  foreach my $peptide ( @{$peptides} ) {
    #### Determine the mapped or else original protein name
    $protein = $peptide->[1];
    unless ($protein) {
      $protein = $peptide->[2];
    }

    #### Calculate the number of samples for the protein and peptide
    my $peptide_instance_id = $peptide->[0];
    $search_batch_ids = $peptide->[3];
    my $n_protein_samples = scalar(keys(%{$proteins{$protein}}));
    my @peptide_samples = split(",",$search_batch_ids);
    my $n_peptide_samples = scalar(@peptide_samples);
    my $proteotypic_score = $n_peptide_samples / $n_protein_samples;

    if ($peptide_scores{$peptide_instance_id}) {
      if ($peptide_scores{$peptide_instance_id}->{score} < $proteotypic_score ) {
				$peptide_scores{$peptide_instance_id}->{score} = $proteotypic_score;
				$peptide_scores{$peptide_instance_id}->{n_search_batch_ids} = $n_peptide_samples;
				$peptide_scores{$peptide_instance_id}->{n_protein_samples} = $n_protein_samples;
       	$peptide_scores{$peptide_instance_id}->{sequence} = $peptide->[4];
       	$peptide_scores{$peptide_instance_id}->{protein_name} = $peptide->[1];
      }

    } else {
      $peptide_scores{$peptide_instance_id}->{score} = $proteotypic_score;
      $peptide_scores{$peptide_instance_id}->{n_search_batch_ids} = $n_peptide_samples;
      $peptide_scores{$peptide_instance_id}->{n_protein_samples} = $n_protein_samples;
      $peptide_scores{$peptide_instance_id}->{sequence} = $peptide->[4];
      $peptide_scores{$peptide_instance_id}->{protein_name} = $peptide->[1];
    }

  }



  my $predicted_scores;
  if (-e 'calculated_proteotypic.tsv') {
    $predicted_scores = readPredictorOutput(
      source_file => 'calculated_proteotypic.tsv',
    );
  } else {
    print "WARNING: Unable to find 'calculated_proteotypic.tsv'. All ".
      "calculated values will be 0\n";
    $predicted_scores->{'N/A'} = 1;
  }

  $args{proteotypic_file} ||= 'AB_' . $atlas_build_id . '_proteotypic-scores.tsv';
  open(OUTFILE,">$args{proteotypic_file}") or
    die("ERROR[$SUB]: Unable to write to '$args{proteotypic_file}'");
  my $export_file2 = $args{proteotypic_file};
  $export_file2 =~ s/\.tsv$/-simplified.tsv/;
  $export_file2 .= '-simplified.tsv' if $export_file2 !~ /simplified/;
  open(OUTFILE2,">$export_file2") or
    die("ERROR[$SUB]: Unable to write to '$export_file2'");

  print OUTFILE "peptide_instance_id\tflanked_peptide_sequence\tn_peptide_samples\t".
    "n_protein_samples\tproteotypic_fraction\tpredicted_score\tprotein_name\n";


  #### Hash for tracking proteins containing proteotypic peptides
  my %proteoproteins;
  my %threeplusproteins;

  my $proteotypic_score_threshold = 0.3;
  my $counter = 0;

  foreach my $peptide ( keys(%peptide_scores) ) {

    if ($predicted_scores->{'N/A'}) {
      $predicted_scores->{$peptide} = 0;
    }

    if ($peptide_scores{$peptide}->{n_protein_samples} > 2 &&
	exists($predicted_scores->{$peptide})) {

      print OUTFILE $peptide."\t".
        $peptide_scores{$peptide}->{sequence}."\t".
	$peptide_scores{$peptide}->{n_search_batch_ids}."\t".
        $peptide_scores{$peptide}->{n_protein_samples}."\t".
	sprintf("%4.3f",$peptide_scores{$peptide}->{score})."\t".
	sprintf("%4.3f",$predicted_scores->{$peptide})."\t".
        $peptide_scores{$peptide}->{protein_name}."\n";

      print OUTFILE2 $peptide."\t".
	$peptide_scores{$peptide}->{n_search_batch_ids}."\t".
        $peptide_scores{$peptide}->{n_protein_samples}."\t".
	sprintf("%4.3f",$peptide_scores{$peptide}->{score})."\t".
	sprintf("%4.3f",$predicted_scores->{$peptide})."\n";

      #### Store protein information for later histogram calculation
      my $protein_name = $peptide_scores{$peptide}->{protein_name};
      $threeplusproteins{$protein_name}++;
      if ($peptide_scores{$peptide}->{score} > $proteotypic_score_threshold) {
	      $proteoproteins{$protein_name}->{$peptide} = $peptide_scores{$peptide}->{score} || '';
      }

    }

    #### Update database records
    my %rowdata = (
      n_samples => $peptide_scores{$peptide}->{n_search_batch_ids},
      n_protein_samples => $peptide_scores{$peptide}->{n_protein_samples},
      empirical_proteotypic_score => $peptide_scores{$peptide}->{score},
      predicted_proteotypic_score => $predicted_scores->{$peptide},
    );
    $sbeams->updateOrInsertRow(
      update=>1,
      table_name=>$TBAT_PEPTIDE_INSTANCE,
      rowdata_ref=>\%rowdata,
      PK => 'peptide_instance_id',
      PK_value => $peptide,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

    #### Show progress
    $counter++;
    if ($counter/100 == int($counter/100)) {
      print "$counter...";
    }

  }


  close(OUTFILE);
  close(OUTFILE2);
  print "\n$counter rows updated.\n";


  #### Calculate histogram of how many proteotypic peptides per protein
  my %peptide_counts;
  foreach my $proteoprotein ( keys(%proteoproteins) ) {
    my $n_peptides = scalar(keys(%{$proteoproteins{$proteoprotein}}));
    $peptide_counts{$n_peptides}++;
  }


  print "\nNumber of proteins observed in more than 2 samples: ".
    scalar(keys(%threeplusproteins))."\n";
  print "With proteotypic threshold $proteotypic_score_threshold\n";
  print "Number of proteins with at least one proteotypic peptide: ".
    scalar(keys(%proteoproteins))."\n";


  foreach my $count ( sort numerically (keys(%peptide_counts)) ) {
    print "$count\t$peptide_counts{$count}\n";
  }


  return;

} # end updateObservedProteotypicScores



###############################################################################
# readPredictorOutput
###############################################################################
sub readPredictorOutput {
  my $SUB = 'readPredictorOutput';
  my %args = @_;

  my $source_file = $args{source_file} or
    die("ERROR[$SUB]: parameter source_file not provided");

  unless ( -e $source_file ) {
    die("ERROR[$SUB]: Cannot find file '$source_file'");
  }

  open(INFILE,$source_file) or
    die("ERROR[$SUB]: Cannot open file '$source_file'");

  my $line;
  my $peptides;

  while ($line = <INFILE>) {
    chomp($line);
    my @columns = split("\t",$line);
    my $peptide_instance_id = $columns[0];
    my $sequence = $columns[1];
    my $chopped_sequence = $sequence;
    chop($chopped_sequence);
    my $score;

    if ($sequence =~ /^[RK]/ && $chopped_sequence =~ /[RK]$/) {
      if ($sequence =~ /C/) {
	$score = $columns[5];
      } else {
	$score = $columns[4];
      }

      $peptides->{$peptide_instance_id} = $score;

    }

  }

  close(INFILE);

  return $peptides;

} # end readPredictorOutput



###############################################################################
# numerically
###############################################################################
sub numerically {
 
  return $a <=> $b;
 
} # end numerically
 
 
