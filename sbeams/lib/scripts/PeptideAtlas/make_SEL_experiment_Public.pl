#!/usr/local/bin/perl -w

###############################################################################
# Program     : make_SEL_experiment_Public.pl  
# Author      : Zhi Sun
#
# Description : make sample public and add guest user to related project 
#
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Time::Local; 
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $ATLAS_BUILD_ID 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TEST
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
  --expt_id
  --test                 Test only, don't write records
e.g.: ./$PROG_NAME --sample_id 73 --publication_id 3
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","test",
       "expt_id:s",
    )) {

    die "\n$USAGE";

}


$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TEST = $OPTIONS{"test"} || 0;

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
      $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
  );

  my $expt_id = $OPTIONS{expt_id} or die "need to have expt_id\n";

  my $sql = qq~ 
    SELECT SAMPLE_ID, PROJECT_ID 
    FROM $TBAT_SEL_EXPERIMENT
    WHERE SEL_EXPERIMENT_ID = $expt_id and record_status != 'D'
  ~;
  
  my @row = $sbeams->selectSeveralColumns($sql);
  if(@row > 1){
    die "more than one sample_id and project_id for $expt_id\n";
  }  
  print "sample_id $row[0]->[0], project_id $row[0]->[1]\n";

  updateSample ($row[0]->[0]);
  addProjectGuestPermission ($row[0]->[1]);

} # end handleRequest



###############################################################################
# 
###############################################################################
sub updateSample {
  my $sample_id = shift;

	 my %rowdata = (
		 'is_public' => 'Y'
   );	

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
  if ($success =~ /^\d+$/  and $success eq $sample_id){
    print "update sample success\n";
  }else{ 
    print "fail to update sample: $success\n";
  } 

}

sub addProjectGuestPermission {
  my $project_id = shift;
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	$year += 1900;
	$mon++;
	my $date = "$year\-$mon\-$mday $hour:$min:$sec";
  my $sql = qq~
    SELECT USER_PROJECT_PERMISSION_ID 
    FROM $TB_USER_PROJECT_PERMISSION 
    where project_id = $project_id and  contact_id = 107
  ~;
  my @result = $sbeams->selectOneColumn($sql);
  my $current_contact_id = $sbeams->getCurrent_contact_id;
  my $current_work_group_id = $sbeams->getCurrent_work_group_id;
  
  if (! @result){
		my %rowdata = ( 
			privilege_id => '40',
			project_id => $project_id,
			contact_id => '107',
			date_created       =>  $date,
			created_by_id      =>  $current_contact_id,
			date_modified      =>  $date,
			modified_by_id     =>  $current_contact_id,
			owner_group_id     =>  $current_work_group_id,
			record_status      =>  'N',);
		

    my $success = $sbeams->updateOrInsertRow(
     insert =>1,
     table_name=>$TB_USER_PROJECT_PERMISSION,
     rowdata_ref=>\%rowdata,
     PK => 'USER_PROJECT_PERMISSION_ID',
     return_PK => 1,
     verbose=>$VERBOSE,
     testonly=>$TEST,
    );
    if ($success =~ /^\d+$/){
      print "update USER_PROJECT_PERMISSION success\n";
    }else{
      print "fail to update USER_PROJECT_PERMISSION: $success\n";
    }
 
  }
}


