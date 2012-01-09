#!/usr/local/bin/perl
###############################################################################
# load peptide cross speceies (human, mouse, yeast) 
# mapping using existing data in the table based on input biosequence set ids
###############################################################################

use strict;
use Getopt::Long;
use FindBin;
$|++;

use lib "$ENV{SBEAMS}/lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $TEST @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
$sbeams = new SBEAMS::Connection;
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);


$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --setids            
 e.g.:  $PROG_NAME --verbose 1 --debug 1 --setids "103,104,105"  ...

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:i","quiet","debug:i","test:i", "setids:s")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TEST = $OPTIONS{"test"} || 0;
my $biosequence_set_ids = $OPTIONS{"setids"};
if($biosequence_set_ids !~ /(\d+),(\d+),(\d+)/){
  die print "need a set of Human, mouse and yeast bioseqence set id\n";
}

my @set_ids = split(",", $biosequence_set_ids);
$biosequence_set_ids = join (",", sort {$a <=> $b} @set_ids );

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}

my $sql =  qq~
  SELECT  PROTEOTYPIC_PEPTIDE_MAPPING_ID, PROTEOTYPIC_PEPTIDE_XSPECIES_MAPPING_ID
  FROM $TBAT_PROTEOTYPIC_PEPTIDE_XSPECIES_MAPPING
  WHERE biosequence_set_ids = '$biosequence_set_ids'
~;

my %existing_id =  $sbeams->selectTwoColumnHash($sql);

my $sql = qq~
  SELECT PTP.PEPTIDE_SEQUENCE , PTPM.PROTEOTYPIC_PEPTIDE_MAPPING_ID, BSS.ORGANISM_ID ,
  SUM(PTPM.N_SPSNP_MAPPING + PTPM.N_ENSP_MAPPING + PTPM.N_IPI_MAPPING + PTPM.N_SGD_MAPPING) as CNT
  FROM $TBAT_PROTEOTYPIC_PEPTIDE PTP
  JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PTPM ON (PTP.PROTEOTYPIC_PEPTIDE_ID = PTPM.PROTEOTYPIC_PEPTIDE_ID)
  JOIN $TBAT_BIOSEQUENCE BS ON ( PTPM.SOURCE_BIOSEQUENCE_ID = BS.BIOSEQUENCE_ID )
  JOIN $TBAT_BIOSEQUENCE_SET BSS ON (BS.BIOSEQUENCE_SET_ID = BSS.BIOSEQUENCE_SET_ID)
  WHERE BS.BIOSEQUENCE_SET_ID IN ($biosequence_set_ids)
  AND BS.BIOSEQUENCE_NAME NOT LIKE 'DECOY%'
  GROUP BY PTP.PEPTIDE_SEQUENCE, PTPM.PROTEOTYPIC_PEPTIDE_MAPPING_ID, BSS.ORGANISM_ID 
  ORDER BY PTP.PEPTIDE_SEQUENCE
~;


my @rows = $sbeams->selectSeveralColumns($sql);

my $pre_pep = '';
my $n_human_mapping = 0;
my $n_mouse_mapping = 0;
my $n_yeast_mapping = 0;
my @ids =();
foreach my $row (@rows){
  my ($pep,$id,$org_id,$n_mapping) = @$row;
  print "$pep,$id,$org_id,$n_mapping\n" if $VERBOSE;
  if($pre_pep ne '' and $pre_pep ne $pep){
     foreach my $id (@ids){
       #print "$id $n_human_mapping $n_mouse_mapping $n_yeast_mapping\n";
				my %rowdata =(
					 'n_human_mapping' => $n_human_mapping, 
					 'n_mouse_mapping' => $n_mouse_mapping,
					 'n_yeast_mapping' => $n_yeast_mapping,
					 'biosequence_set_ids' => $biosequence_set_ids,
				);
				$rowdata{ 'proteotypic_peptide_mapping_id'} = $id;
				if(not defined $existing_id{$id} ){
					$existing_id{$id} = 1;
					$sbeams->insert_update_row(
						insert=>1,
						table_name=>"$TBAT_PROTEOTYPIC_PEPTIDE_XSPECIES_MAPPING",
						rowdata_ref=>\%rowdata,
						PK=>'proteotypic_peptide_xspecies_mapping_id',
						verbose=>$VERBOSE, 
						test => $TEST,
					);
				}else{
					$sbeams->insert_update_row(
						update=>1,
						table_name=>"$TBAT_PROTEOTYPIC_PEPTIDE_XSPECIES_MAPPING",
						rowdata_ref=>\%rowdata,
						PK=>'proteotypic_peptide_xspecies_mapping_id',
						PK_value=> $existing_id{$id},
						verbose=>$VERBOSE,
						test => $TEST,
					);
				}
     }
     $n_human_mapping = 0;
     $n_mouse_mapping = 0;
     $n_yeast_mapping = 0;
     @ids = ();
  }
  if($org_id == 2 ){
     $n_human_mapping = $n_mapping;
  }elsif($org_id == 6){
     $n_mouse_mapping = $n_mapping;
  }elsif($org_id == 3){
     $n_yeast_mapping= $n_mapping;
  }
  $pre_pep = $pep;
  push @ids , $id;
}

exit;
