#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_affy_annotation_files.pl
# Author      : Pat Moss <pmoss@systemsbiology.org>
#
# Description : This scirpt will parse a Annotation file from Affymetrix.  Affymetrix provides a file for each chip
# in csv format with 38 columns of data.  The data will parsed and loaded into affy_annotation tables within sbeams 
#
#
###############################################################################
our $VERSION = '1.00';

=head1 NAME

load_affy_annotation_files.pl - Load affy annotation files into SBEAMS::Microarray tables

=head1 SYNOPSIS

  --run_mode <update or delete>  [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
    --base_directory  <file path> Override the default directory to start searching for files
    --testonly         Information in the database is not altered

=head1 DESCRIPTION

"update" is the Default run mode which will take the file_name give on the command line and load it into the database.
If the file has already been loaded it will delete all the old data and upload the file once again


=head2 EXPORT

Nothing


=head1 SEE ALSO

SBEAMS::Microarray::Affy;
SBEAMS::Microarray::Affy_file_groups;

SBEAMS::Microarray::Settings; #contains the default file extensions and file path to find Affy annotation files
=head1 AUTHOR

Pat Moss, E<lt>pmoss@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Pat Moss

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut

###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use File::Basename;

use Data::Dumper;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $q $sbeams_affy $sbeams_affy_groups $sbeams_affy_anno
             $PROG_NAME $USAGE %OPTIONS 
			 $VERBOSE $QUIET $DEBUG 
			 $DATABASE $TESTONLY $PROJECT_ID 
			 $CURRENT_USERNAME 
			 $SBEAMS_SUBDIR
			 $RUN_MODE
            		 $FILE_NAME
			 $START_TIME			
	    );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray::Tables;

use SBEAMS::Microarray::Affy;
use SBEAMS::Microarray::Affy_file_groups;
use SBEAMS::Microarray::Affy_Annotation;

$sbeams = new SBEAMS::Connection;

$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

#$sbeams_affy 	    = new SBEAMS::Microarray::Affy;
#$sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;
$sbeams_affy_anno   = new SBEAMS::Microarray::Affy_Annotation;
$sbeams_affy_anno->setSBEAMS($sbeams);
$|++;

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;

my @run_modes = qw(update delete);

$USAGE = <<EOU;
$PROG_NAME is used to load Affy annotation files into SBEAMS. 


Usage: $PROG_NAME --run_mode <update, delete> --file_name <full_path to annotation file>[OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
    --base_directory  <file path> Override the default directory to start searching for files
    --testonly         Information in the database is not altered

Run Mode Notes:
 
 update Default run mode will take the file_name give on the command line and load into the database.
 	If the file has already been loaded it will delete all the old data and upload the file once again
 	
 delete Will delete all the annotation for a given file_name

EOU

		
		
#### Process options
unless (GetOptions(\%OPTIONS,
		   "run_mode:s",
		   "verbose:i",
		   "quiet",
		   "debug:i",
		   "delete_all:s",
		   "method:s",
		   "file_name:s",
		   "testonly")) {
  print "$USAGE";
  exit;
}



$VERBOSE    = $OPTIONS{verbose} || 0;
$QUIET      = $OPTIONS{quiet};
$DEBUG      = $OPTIONS{debug};
$TESTONLY   = $OPTIONS{testonly};
$RUN_MODE   = $OPTIONS{run_mode};

$FILE_NAME = $OPTIONS{file_name};


my $val = grep {$RUN_MODE eq $_} @run_modes;

die "*** RUN_MODE DOES NOT LOOK GOOD '$RUN_MODE' ***\n $USAGE" unless ($val);

die "*** PLEASE PROVIDE A FILE NAME ***\n $USAGE" unless $FILE_NAME;



if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  RUN_MODE = $RUN_MODE\n";
  print "  FILE_NAME = $FILE_NAME\n";
  print "  TESTONLY = $OPTIONS{testonly}\n";

}


###############################################################################
# Set Global Variables and execute main()
###############################################################################

$sbeams_affy_anno->verbose($VERBOSE);
$sbeams_affy_anno->debug($DEBUG);
$sbeams_affy_anno->testonly($TESTONLY);
$START_TIME = `date`;
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
  if ($module eq 'Microarray') {
	$work_group = "Microarray_admin";
	$DATABASE = $DBPREFIX{$module};
 	print "DATABASE '$DATABASE'\n" if ($DEBUG);
  }
 

#### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($CURRENT_USERNAME = $sbeams->Authenticate(
		work_group=>$work_group,
	 ));
	
## Presently, force module to be microarray and work_group to be Microarray_admin  
  if ($module ne 'Microarray') {
	print "WARNING: Module was not Microarray.  Resetting module to Microarray\n";
	$work_group = "Microarray_admin";
	$DATABASE = $DBPREFIX{$module};
	}


  	$sbeams->printPageHeader() unless ($QUIET);
  	handleRequest();
 	$sbeams->printPageFooter() unless ($QUIET);

	

} # end main



###############################################################################
# handleRequest
#
# Handles the core functionality of this script
###############################################################################
sub handleRequest {
  	my %args = @_;
  	my $SUB_NAME = "handleRequest";


	if ( $RUN_MODE eq 'update') {
		add_affy_annotation();
		
		write_error_log(object => $sbeams_affy_anno);
		
	}elsif( $RUN_MODE eq 'delete') {
		
		
		delete_affy_annotation();
	}else{
		die "This is not a valid run mode '$RUN_MODE'\n $USAGE";
	}
}

###############################################################################
# add_affy_annotation
#
#Parse the Affymetrix annotation csv file and put into database. IF the file contains the same Annotation Date as the one in the 
#data base it will delete the previous version and then add the information.  If the date is different it will add the data.  Expect affy to produce a new file
#quarterly
###############################################################################
sub add_affy_annotation {
		$sbeams_affy_anno->database($DATABASE);
		$sbeams_affy_anno->parse_data_file($FILE_NAME);					
		
		
		
		if ($DEBUG >1) {
			print Dumper ($sbeams_affy_anno);
		}
		my $count = 0;
		my $total_record_count = $sbeams_affy_anno->get_record_count;
		while (my $record_href = $sbeams_affy_anno->get_record){
			
			my $affy_anno_pk = $sbeams_affy_anno->add_record_to_annotation_table(record =>$record_href,);
			
			$sbeams_affy_anno->add_record_to_affy_db_links( record =>$record_href,
									affy_annotation_pk => $affy_anno_pk);
									
											#A bunch of data will parsed and added to sub tables
			$sbeams_affy_anno->add_data_child_tables( record =>$record_href,	
								  affy_annotation_pk => $affy_anno_pk);

			if ($VERBOSE >0){
				print "$count - $affy_anno_pk\n";
			}
			if ($count % 100 == 0){
				printf "ENTERED $count records of '$total_record_count' Percent Done:%.2f\n",  ($count/$total_record_count)*100 ;
			}
			
			$count ++;	
		}
	my $end_time = `date`;	
	
	print "Finished uploading '$count' Records\n",
	      "START TIME '$START_TIME'\n", 
	      "END   TIME '$end_time'\n";

}
###############################################################################
# write_error_log	
#
# Collect information about files that do have enough information to upload and print out a nice file
# so someone can go and fix the problem
###############################################################################
	
sub write_error_log{
	
	my %args = @_;
	
	my $sbeams_affy_anno = $args{object};

	my($file_base_name, undef, undef) = fileparse($FILE_NAME);
	my $SUB_NAME = 'write_error_log';
	
	
	open ERROR_LOG, ">../../../tmp/Microarray/AFFY_ANNO_LOGS/AFFY_ANNO_ERROR_LOG_$file_base_name.txt" or 
		die "CANNOT OPEN AFFY ERROR LOG $!\n";
	
	my $date = `date`;
	chomp $date;
	print ERROR_LOG "TIME OF RUN '$date'\n";
	
	my $count = 1;
	
			
	print ERROR_LOG $sbeams_affy_anno->anno_error();
			
		
}
		
