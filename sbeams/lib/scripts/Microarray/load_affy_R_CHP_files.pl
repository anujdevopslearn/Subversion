#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_affy_R_CHP_files.pl
# Author      : Pat Moss <pmoss@systemsbiology.org>
#
# Description : This script will run on a cron job, scanning a directory tree looking
#		cel files to convert into R_CHP files
#
# notes	      :Current crontab running from /users/pmoss/Cron_tab/Mossy_cron_tab.txt
###############################################################################
our $VERSION = '1.00';

=head1 NAME

load_affy_R_CHP_files.pl - Produce and load data from R_CHP files SBEAMS::Microarray tables

=head1 SYNOPSIS

  --run_mode <add_new or update or delete>  [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
    --base_directory  <file path> Override the default directory to start searching for files
    --file_extension <space separated list> Override the default File extensions to search for.
    --testonly         Information in the database is not altered

=head1 DESCRIPTION

This script will run on a cron job, scanning a directory tree looking
for affy cel files converting them to R_CHP files.  An R_CHP files is a CEL file ran through R
with the Mas5.0 algrotrium.  This produces signal intensites that have a very high correlation to the
values output from the Affy GCOS software.  It should be noted that the actual signal intensity will be
different from the Affy software.  Also the p-detection threshold will be different then what Affy computes
and the correlation between R_CHP and reguar Affy CHP files has been showen to have about 70+% correlation


=head2 EXPORT

Nothing


=head1 SEE ALSO

SBEAMS::Microarray::Affy;
SBEAMS::Microarray::Affy_file_groups;
SBEAMS::Microarray::Affy_Analysis
SBEAMS::Microarray::Settings; #contains the default file extensions and file path to find Affy files of interest

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
#use File::Find;
use Data::Dumper;
use XML::XPath;
use XML::Parser;
use XML::XPath::XMLParser;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $q $sbeams_affy $sbeams_affy_groups
             $PROG_NAME $USAGE %OPTIONS 
			 $VERBOSE $QUIET $DEBUG 
			 $DATABASE $TESTONLY $PROJECT_ID 
			 $CURRENT_USERNAME 
			 $SBEAMS_SUBDIR
			 $BASE_DIRECTORY
			 @FILE_TYPES
			 $RUN_MODE
            		 %HOLD_COVERSION_VALS
			 %data_to_find
			 $METHOD
			 $RECOMPUTE_R
	    );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray::Tables;

use SBEAMS::Microarray::Affy;
use SBEAMS::Microarray::Affy_file_groups;
use SBEAMS::Microarray::Affy_Analysis;


$sbeams = new SBEAMS::Connection;

$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$sbeams_affy = new SBEAMS::Microarray::Affy_Analysis;
$sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;
$sbeams_affy->setSBEAMS($sbeams);
$sbeams_affy_groups->setSBEAMS($sbeams);

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;

my @run_modes = qw(add_new update delete);

$USAGE = <<EOU;
$PROG_NAME is used to find and load Affy arrays into SBEAMS. 


Usage: $PROG_NAME --run_mode <add_new, update, delete>  [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
    --base_directory  <file path> Override the default directory to start searching for files
    --file_extension <space separated list> Override the default File extensions to search for.
    --testonly         Information in the database is not altered

Run Mode Notes:
 add_new : will find all cel files for each unique root_file_name run R, parse the data and upload into the database
 
 update  : This will run just like add_new but it will find and re-compute and re-load all R_CHP files.  
 	   If the defualt protocol ID is the same the script will stomp all the old data
  
 delete  : NOT FUNCTIONAL DELETE FROM THE DATABASE
Examples;
1) ./$PROG_NAME --run_mode add_new 	 # typical mode, adds any new files
2) ./$PROG_NAME --run_mode update --redo_R yes or no	 # Re upload the data and or re-compute the R run
EOU

		
		
#### Process options
unless (GetOptions(\%OPTIONS,
		   "run_mode:s",
		   "verbose:i",
		   "quiet",
		   "debug:i",
		   "array:s",
		   "both:s",
		   "delete_all:s",
		   "method:s",
		   "base_directory:s",
		   "file_types:s",
		   "redo_R:s",
		   "testonly")) {
  print "$USAGE";
  exit;
}



$VERBOSE    = $OPTIONS{verbose} || 0;
$QUIET      = $OPTIONS{quiet};
$DEBUG      = $OPTIONS{debug};
$TESTONLY   = $OPTIONS{testonly};
$RUN_MODE   = $OPTIONS{run_mode};
$RECOMPUTE_R = $OPTIONS{redo_R};




my $val = grep {$RUN_MODE eq $_} @run_modes;

die "*** RUN_MODE DOES NOT LOOK GOOD '$RUN_MODE' ***\n $USAGE" unless ($val);

if ($RUN_MODE eq 'update' ){		#if update mode check to see if --method <name> is set correctly
	#FIX ME

};

##############################
##Setup a few global variables
if ($OPTIONS{base_directory}){
	$BASE_DIRECTORY = $OPTIONS{base_directory};
}else{
	$BASE_DIRECTORY = $sbeams_affy->get_AFFY_DEFAULT_DIR();	#get method in SBEAMS::Microarray::Settings.pm
}

if ($OPTIONS{file_types}) {
	@FILE_TYPES = split /\s+/,$OPTIONS{file_types};
}else{
	@FILE_TYPES =  $sbeams_affy->get_AFFY_FILES();
}
############################


if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  RUN_MODE = $RUN_MODE\n";
  print "  BASE_DIR = $BASE_DIRECTORY\n";
  print "  FILE_TYPE = @FILE_TYPES\n";
  print "  TESTONLY = $OPTIONS{testonly}\n";
 
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
$sbeams_affy_groups->base_dir($BASE_DIRECTORY);
$sbeams_affy_groups->file_extension_names(@FILE_TYPES);
$sbeams_affy_groups->verbose($VERBOSE);
$sbeams_affy_groups->debug($DEBUG);

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
	
## Presently, force module to be microarray and work_group to be Microarray_admin  XXXXXX what does this do and is it needed
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


	if ( $RUN_MODE eq 'add_new' || $RUN_MODE eq 'update') {
	
		if ($RUN_MODE eq 'update'){
			unless ($RECOMPUTE_R =~ /YES|NO/i){
				die "*** update run mode must have --redo_R command argument ***\n$USAGE\n";
			}
		}
		
		$sbeams_affy_groups->read_dirs();			#Read the affy dirs containing all the data.  Sets global object in Affy_file_groups
		
		find_affy_R_CHP(object => $sbeams_affy_groups);		#find files to make
	
		add_R_CHP_data(object => $sbeams_affy);			#add all the data to the database
	
	
		write_error_log(object => $sbeams_affy_groups);
		print "ERROR: PROJECT WITH NO PROJECT ID's\n";
		
	
	}elsif( $RUN_MODE eq 'delete') {
		die "SORRY RUN MODE NOT YET SUPPORTED\n";
	}else{
		die "This is not a valid run mode '$RUN_MODE'\n $USAGE";
	}
}

###############################################################################
# add_R_CHP_data
#
#Take all the objects that were created making R files
###############################################################################
sub add_R_CHP_data {
	my $SUB_NAME = 'add_affy_arrays';
	my %args = @_;
	
	my $sbeams_affy = $args{'object'};
	
	
	foreach my $affy_o ($sbeams_affy->registered) {
		my $id = '';
		next unless ($id = $affy_o->get_affy_array_id);				#Some Affy objects might not be used to store array data.  This appears bad
	 	
		my $update_flag = 0;
		if   ( $affy_o->R_CHP_file_name() && $RUN_MODE ne 'update'){ 	#skip over the R_CHP files that already exists unless we are in update mode
			print "SKIPPING '" . $affy_o->R_CHP_file_name() . "' NOT IN UPDATE MODE\n" if ($VERBOSE > 0);
			next;
		}
		$update_flag = 1 if $RUN_MODE eq 'update';	
			
		next unless (($id >= 173 && $id < 178) || ($id >= 225 && $id <= 249) );			#testing only to constrain to certain array ids
		my $file_name = $affy_o->get_afa_file_root;
		print "ARRAY ID '$id'\n";
		
		my $cel_file = $sbeams_affy_groups->get_file_path( root_file_name => $file_name,#will have to access the CHP file path from the affy_groups object
							    	   file_ext 	 => 'CEL',);							
		
		
		print "ROOT NAME '$file_name'\nCEL FILE PATH '$cel_file'\n" if ($VERBOSE);
		
		
		if ($RECOMPUTE_R =~ /YES/i || $RUN_MODE eq 'add_new'){
			my $results=  $affy_o->make_R_CHP_file(cel_file => $cel_file,		#run R to make R_CHP files
				      file_name => $file_name,
				     );
			print "FINISHED RUNNING make_R_CHP_file for $file_name\n";
		
			my $tag_result = $affy_o->tag_R_CHP_file();				#add the protocol information to the file
			print "TAGGED FILE '$tag_result'\n" if ($VERBOSE);
		
		
		
			unless ($results == 1){							#check for errors running R
				print "RESULTS OF MAKING R_CHP FILE '$results\n" if ($VERBOSE);
				next;
			}
		
		}
		
		
		
		print "\n\nUploading data for '$file_name'\n";
		
		my $base_dir = dirname($cel_file);
		$affy_o->parse_R_CHP_file(verbose  => $VERBOSE,			#parse the R_CHP file and add the data to the database
					  testonly => $TESTONLY,
					  debug	   => $DEBUG,
					  update   => $update_flag,
					  );					
							
		
	}
}


###############################################################################
# find_affy_R_CHP
#
#For each group of files found in the main affy directory check for a R_CHP file 
#if a group does not have a file make an affy object
###############################################################################
sub find_affy_R_CHP {
	my $SUB_NAME = 'find_affy_R_CHP';
	
	
	my %args = @_;
	
	my $sbeams_affy_groups = $args{object};
	
	foreach my $file_name ( $sbeams_affy_groups->sorted_root_names() ) {				
		
		#next unless ($sbeams_affy_groups->check_file_group(root_file_name => $file_name) eq 'YES');
		
		my $sample_tag	= '';
		if ($file_name =~ /^\d+_\d+_(.*)/){				#Parse the Sample tag from the root_file name example 20040707_05_PAM2B-80
			$sample_tag = $1;
			
		}else{
			$sbeams_affy_groups->group_error(root_file_name => $file_name,
								 error => "CANNOT FIND SAMPLE NAME FROM ROOT NAME",
							);
			next;
		}
		
		
		my $sbeams_affy = new SBEAMS::Microarray::Affy_Analysis;	#make new affy instances
		
										#find the array_id. Will assume the array has been uploaded by load_affy_array_files.pl
		my $affy_array_id = $sbeams_affy_groups->find_affy_array_id(root_file_name => $file_name);
		if ($affy_array_id){
				$sbeams_affy->set_affy_array_id($affy_array_id);			
			
		}else{
				
			$sbeams_affy_groups->group_error(root_file_name => $file_name,
							 error => "CANNOT FIND AFFY ARRAY ID",
							);
			next;	 						#if the root file name is not in the database move on, somehow it has not been added yet	
		}
		
		$sbeams_affy->set_afa_file_root($file_name);
		$sbeams_affy->set_afs_sample_tag($sample_tag);			#set the sample_tag, within a project this should be a unique name
		
#########################################################################
### Determine if a R_CHP file exists and set the path to it if it does 

		if (my $R_CHP_file =  $sbeams_affy_groups->get_file_path( root_file_name => $file_name,
									  file_ext 	 => 'R_CHP', 
								        )
		   )
		{
		   	print "R CHP FILE EXISTS '$file_name'\n" if ($VERBOSE);	
			$sbeams_affy->R_CHP_file_name($R_CHP_file);		#set the path to the R_CHP file, this will be the only way to differentiate which ones are to be update 
			
		}else{
			print "NEED TO MAKE R CHP FILE for '$file_name'\n" if ($VERBOSE);
		}
	}
}		
			

###############################################################################
# write_error_log	
#
# Collect information about files that do have enough information to upload and print out a nice file
# so someone can go and fix the problem
###############################################################################
	
sub write_error_log{
	
	my %args = @_;
	
	my $sbeams_affy_groups = $args{object};

	
	my $SUB_NAME = 'write_error_log';
	
	
	open ERROR_LOG, ">../../../tmp/Microarray/AFFY_ADD_R_CHP_FILES_LOG.txt" or 
		die "CANNOT OPEN AFFY ERROR LOG $!\n";
	
	my $date = `date`;
	chomp $date;
	print ERROR_LOG "TIME OF RUN '$date'\n";
	
	my $count = 1;
	
	foreach my $file_name ($sbeams_affy_groups->sorted_root_names()) {
		
		if (my $error = $sbeams_affy_groups->group_error(root_file_name => $file_name) ){
					
			print ERROR_LOG "$count\t$error\n";
			
			
			foreach my $file_path ( $sbeams_affy_groups->get_file_group(root_file_name => $file_name)) {
				
				print ERROR_LOG "\t\t$file_path\n";
			
			}
			
			$count ++;
		}
		
	}
}
		
