#!/usr/local/bin/perl -w

###############################################################################
# Program      : update_sample_repository_identifiers.pl 
# Author       : Zhi Sun 
# $Id: 
# 
# Description  : update repository_identifiers in sample table. 
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use XML::Writer;
use IO::File;
use Encode;
$|++;

use lib "$FindBin::Bin/../../perl";

use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TEST);
use vars qw ($q $sbeams $sbeamsMOD $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name);

#### Set up SBEAMS modules
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;


## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ( $current_username = $sbeams->Authenticate(
    #connect_read_only=>1,
    allow_anonymous_access => 1,
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));


###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME 

Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
    )) {
    die "\n$USAGE";
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TEST = $OPTIONS{"testonly"} || 0;

if ($DEBUG) {
    print "Options settings:\n";
    print "  VERBOSE = $VERBOSE\n";
    print "  QUIET = $QUIET\n";
    print "  DEBUG = $DEBUG\n";
    print "  TESTONLY = $TEST\n";
}

my $sql = qq~
 SELECT S.SAMPLE_ID, 
        PDR.DATASET_IDENTIFIER, 
        PDR.RELATED_DATABASE_ENTRIES
  FROM $TBAT_PUBLIC_DATA_REPOSITORY PDR
  JOIN $TB_PROJECT P ON (PDR.PROJECT_ID = P.PROJECT_ID)
  JOIN $TBPR_PROTEOMICS_EXPERIMENT E ON (E.PROJECT_ID = P.PROJECT_ID)
  JOIN $TBPR_SEARCH_BATCH SB ON (E.EXPERIMENT_ID = SB.EXPERIMENT_ID)
  JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON (SB.SEARCH_BATCH_ID = ASB.PROTEOMICS_SEARCH_BATCH_ID)
  JOIN $TBAT_SAMPLE S ON (ASB.SAMPLE_ID = S.SAMPLE_ID)
  WHERE S.record_status = 'N'
~;

my @rows = $sbeams->selectSeveralColumns ($sql);

$sql = qq~
	 SELECT S.sample_id, 
		SE.DATASETIDENTIFIER,
		SE.PX_IDENTIFIER
	FROM $TBAT_SEL_EXPERIMENT SE
	JOIN $TBAT_SAMPLE S ON (S.SAMPLE_ID = SE.SAMPLE_ID)
~;
my @results  = $sbeams->selectSeveralColumns ($sql);
push @rows , @results;

my %data = ();
foreach my $row (@rows){
  my ($sid, $id, $rid) = @$row; 
  if($id){
    $id =~ s/\s+//g;
    next if ($id =~ /^$/);
    foreach my $s (split(/([,;])/, $id)){
      next if ($s =~ /^$/);
      $data{$sid}{$s} =1;
    }
  }
  if($rid){
    $rid =~ s/\s+//g;
    next if ($rid =~ /^$/);
    foreach my $s (split(/[,;]/, $rid)){
      next if ($s =~ /^$/);
      $data{$sid}{$s} = 1;
    }
  }
}  
foreach my $sample_id (keys %data){
  my $repository_identifiers =  join(",", sort {$a cmp $b} keys %{$data{$sample_id}});
  my %rowdata = (
    repository_identifiers => $repository_identifiers
    );
  print "$sample_id\t$repository_identifiers\n";
  my $success = $sbeams->updateOrInsertRow(
			 update =>1,
			 table_name=>$TBAT_SAMPLE,
			 rowdata_ref=>\%rowdata,
			 PK => 'sample_id',
			 PK_value => $sample_id,
			 return_PK => 1,
			 verbose=>$VERBOSE,
			 testonly=>$TEST,
			);
}

$sql = qq~
 SELECT TOP 1 REPOSITORY_IDENTIFIERS 
  FROM $TBAT_SAMPLE
  WHERE repository_identifiers like 'PrePX%' 
  ORDER BY CAST (REPLACE(REPOSITORY_IDENTIFIERS, 'PrePX', '') AS INT) DESC 
~;

my @ids = $sbeams->selectOneColumn ($sql);
my $counter = 1;
if (@ids){
  $ids[0] =~ /PrePX(\d+)/;
  $counter = $1;
  $counter++;
}
print "PrePX max counter $counter\n";

$sql =  qq~
  SELECT distinct S.sample_id , P.project_id, P.name,S.sample_publication_ids, ASB.data_location, S.date_created 
  FROM $TBAT_SAMPLE S 
  JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON (ASB.SAMPLE_ID = S.SAMPLE_ID)
  JOIN $TBPR_SEARCH_BATCH SB ON  (SB.SEARCH_BATCH_ID = ASB.PROTEOMICS_SEARCH_BATCH_ID)  
  JOIN $TBPR_PROTEOMICS_EXPERIMENT E ON (E.EXPERIMENT_ID = SB.EXPERIMENT_ID)
  JOIN $TB_PROJECT P ON (E.PROJECT_ID = P.PROJECT_ID)
  WHERE S.repository_identifiers is null
  ORDER By S.date_created 
~;

my %project_repository_identifier = ();
@rows = $sbeams->selectSeveralColumns ($sql);
foreach my $row(@rows){
  my ($sample_id, $project_id,$name,$pub,$loc,$date) = @$row;
  my $repository_identifiers;
 
  if ($name =~/Human PeptideAtlas 2012-07/i){
    $loc =~ s/^\///;
    if ($loc =~ /^([^\/]+\/[^\/]+\/).*$/){
      $project_id = $1;
    }else{
      $project_id = $loc;
    }
  }

	if (defined $project_repository_identifier{$project_id}){
		 $repository_identifiers = $project_repository_identifier{$project_id};
	}else{
		$repository_identifiers = 'PrePX' . $counter;
		$project_repository_identifier{$project_id} = $repository_identifiers;
    $counter++;
	}
	#print "$sample_id\t$project_id\t$repository_identifiers\t$name\t$loc\n"; 
  my %rowdata = (
    repository_identifiers => $repository_identifiers
    );
  print "$sample_id\t$repository_identifiers\n";
  my $success = $sbeams->updateOrInsertRow(
       update =>1,
       table_name=>$TBAT_SAMPLE,
       rowdata_ref=>\%rowdata,
       PK => 'sample_id',
       PK_value => $sample_id,
       return_PK => 1,
       verbose=>$VERBOSE,
       testonly=>$TEST,
      );

}

 
