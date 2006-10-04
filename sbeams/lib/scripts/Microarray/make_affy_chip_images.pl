#!/usr/local/bin/perl -w

###############################################################################
# Program     : make_affy_chip_images.pl
# Author      : Bruz Marzolf <bmarzolf@systemsbiology.org>
#
# Description : This script will scan a directory tree looking
#		cel files to convert into images
#
###############################################################################
our $VERSION = '1.00';

=head1 NAME

make_affy_chip_images.pl - Produce images of arrays based on feature intensities

=head1 SYNOPSIS

  --ids <affy_array_ids to make images for, separated by commas>
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    

=head1 DESCRIPTION

This script will run an R/Bioconductor script to generate an image from Affymetrix CEL data as a bitmap of feature intensities.

=head2 WARNING

Nothing


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
            		 %HOLD_COVERSION_VALS
			 %data_to_find
			 $METHOD
	    	 $ARRAYS_TO_PROCESS
       		 %CONFIG_SETTING
       		 $LOG_BASE_DIR
	    );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings qw(:default $LOG_BASE_DIR);
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
$PROG_NAME is used to make images of affy chips.


Usage: $PROG_NAME --ids <affy_array_ids to make images for>
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
  
 delete  : NOT FUNCTIONAL DELETE FROM THE DATABASE
Example;
1) ./$PROG_NAME --ids 123,124,134  #give the affy_array_ids of arrays to make images for
EOU
	
		
#### Process options
unless (GetOptions(\%OPTIONS,
		   "ids:s",
		   "verbose:i",
		   "quiet",
		   "debug:i")) {
  die $USAGE;
 
}


$VERBOSE    = $OPTIONS{verbose} || 0;
$QUIET      = $OPTIONS{quiet};
$DEBUG      = $OPTIONS{debug};
$ARRAYS_TO_PROCESS = $OPTIONS{ids};

unless ( $ARRAYS_TO_PROCESS ) {
	die "No affy array ids provided\n\n$USAGE";
}

$BASE_DIRECTORY = $sbeams_affy->get_AFFY_DEFAULT_DIR();	#get method in SBEAMS::Microarray::Settings.pm
@FILE_TYPES =  $sbeams_affy->get_AFFY_FILES();

############################


if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  ARRAYS_TO_PROCESS = $ARRAYS_TO_PROCESS\n"; 
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

		$sbeams_affy_groups->read_dirs();			#Read the affy dirs containing all the data.  Sets global object in Affy_file_groups
		
		find_affy_R_CHP(object => $sbeams_affy_groups);		#find files to make
	
		make_images(object => $sbeams_affy);			#add all the data to the database
	
	
		write_error_log(object => $sbeams_affy_groups);
}

###############################################################################
# make_images
#
#Take all the objects that were created making R files
###############################################################################
sub make_images {
	my $SUB_NAME = 'make_images';
	my %args = @_;
	
	my $sbeams_affy = $args{'object'};
	
	
	foreach my $affy_o ($sbeams_affy->registered) {
		my $id = '';
		next unless ($id = $affy_o->get_affy_array_id);				#Some Affy objects might not be used to store array data.  This appears bad
		
		if ($ARRAYS_TO_PROCESS){									#if there are specific files to update only update these files
				my @arrays_to_process_a = split /,/,$ARRAYS_TO_PROCESS;
				next unless (grep {$id == $_} @arrays_to_process_a);
		}
		
		my $file_name = $affy_o->get_afa_file_root;
		print "ARRAY ID '$id'\n";
		
		my $cel_file = $sbeams_affy_groups->get_file_path( root_file_name => $file_name,#will have to access the CHP file path from the affy_groups object
							    	   file_ext 	 => 'CEL',);							
		
		print "ROOT NAME '$file_name'\nCEL FILE PATH '$cel_file'\n" if ($VERBOSE);
		

		my $results=  $affy_o->make_chip_jpeg_file(cel_file => $cel_file,		#run R to make R_CHP files
			      file_name => $file_name,
			     );
		
		print "FINISHED RUNNING make_chip_jpeg_file for $file_name\n";
	
		
		unless ($results == 1){							#check for errors running R
			print "RESULTS OF R RUN DO NOT LOOK GOOD. Skipping upload\n";
			print "RESULTS OF R CODE '$results\n" if ($VERBOSE);
			next;
		}	
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
		print "\nAFFY ARRAY ID '$affy_array_id' FOR FILE '$file_name'\n" if ($VERBOSE);
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
		
		my $sql = $sbeams_affy_groups->get_all_affy_info_sql(affy_array_ids => $affy_array_id);

		$sbeams->display_sql(sql=>$sql) if ($VERBOSE > 1);
		my ($array_info_href) = $sbeams->selectHashArray($sql);		#bit dorkey running huge query just to find the organism name
		my $organisim_name = $$array_info_href{Organism};
		my $slide_type = $$array_info_href{'Slide Type'};
		
		print "ORGANISIM NAME '$organisim_name'\nSLIDE TYPE '$slide_type'" if ($VERBOSE > 0);
		
		$sbeams_affy->set_organism($organisim_name);	#set the organisim name
		$sbeams_affy->set_array_slide_type($slide_type); 	#set the slide type
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

  my $logdir = $sbeams_affy->get_affy_log_dir();

  unless ( -e $logdir ) {
    print STDERR "Error log not configured or does not exist: $logdir\n";     
  }
	
  open ERROR_LOG, ">$logdir/AFFY_ADD_R_CHP_FILES_LOG.txt" ||
                              die "Cannot open affy error log in $logdir: $!\n";
	
  my $date = `date`;
  chomp $date;
  print ERROR_LOG "TIME OF RUN '$date'\n";
	
  my $count = 1;
	
  foreach my $file_name ($sbeams_affy_groups->sorted_root_names()) {

    if ( my $error = $sbeams_affy_groups->group_error(root_file_name => $file_name) ) {
					
      print ERROR_LOG "$count\t$error\n";
      foreach my $file_path ( $sbeams_affy_groups->get_file_group(root_file_name => $file_name)) {
        print ERROR_LOG "\t\t$file_path\n";
      }
      $count ++;
    }
  }
}
		
