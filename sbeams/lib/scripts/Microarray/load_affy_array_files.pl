#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_affy_array_files.pl
# Author      : Pat Moss <pmoss@systemsbiology.org>
#
# Description : This script will run on a cron job, scanning a directory tree looking
#		for new affy files. The data will be entered into the SBEAMS affy_array and
#		affy_array_sample microarray database tables
#
# notes	      :Current crontab running from /users/pmoss/Cron_tab/Mossy_cron_tab.txt
###############################################################################
our $VERSION = '1.00';

=head1 NAME

load_affy_array_files.pl - Load affy files into SBEAMS::Microarray tables

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
for new affy files. The data will be entered into the SBEAMS affy_array and
affy_array_sample microarray database tables this 


=head2 EXPORT

Nothing


=head1 SEE ALSO

SBEAMS::Microarray::Affy;
SBEAMS::Microarray::Affy_file_groups;

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
  		 @BAD_PROJECTS
  		 $METHOD
  		 $UPDATE_ARRAY
  		 $DELETE_ARRAY
  		 $DELETE_BOTH
  		 $DELETE_ALL
      );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray::Tables;

use SBEAMS::Microarray::Affy;
use SBEAMS::Microarray::Affy_file_groups;



$sbeams = new SBEAMS::Connection;

$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$sbeams_affy = new SBEAMS::Microarray::Affy;
$sbeams_affy->setSBEAMS($sbeams);
$sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;

$sbeams_affy_groups->setSBEAMS($sbeams);

#use CGI;
#$q = CGI->new();

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
    --base_directory   <file path> Override the default directory to start
                       searching for files
    --file_extension   <space separated list> Override the default File
                       extensions to search for.
    --testonly         Information in the database is not altered

Run Mode Notes:
 add_new : will only upload new files if the file_root name is unique
 
 update --method \<space separated list\>: 
 	Update run mode runs just like the add_new mode, parsing and gathering 
  information.  It will upload NEW files if it finds them, but if the root_file
  name has been previously set this method will update the data pointed to by
  the method flag
  
  Must provide a --method command line flag followed by a comma separated list
  of method names.  Data will be updated only for fields with a valid method 
  name always overriding the data in the database See Affy.pm for the names of
  the setters
  
  Will also accept array number(s) to specifically update instead of all the 
  arrays.  Set the --array_id flag and give some ids comma separated.
 
 delete 

  --array <affy_array_id> OR <root_file_name> Delete the array but LEAVES
    the sample, can be a comma separated list
  --both <affy_array_id> OR <root_file_name>  Deletes the array and sample, can
    be a comma separated list
  --delete_all YES
    Removes all the samples and array information

Examples;

# typical mode, adds any new files
1) ./$PROG_NAME --run_mode add_new 			        

# will parse the sample tag information and stomp the data in the database 	  
2) ./$PROG_NAME --run_mode update --method set_afs_sample_tag   

3) ./$PROG_NAME --run_mode update --method set_afs_sample_tag --array_id 507,508

4) ./$PROG_NAME --run_mode update --method show_all_methods

# Delete the array with the file root given but LEAVES the sample
5) ./$PROG_NAME --run_mode delete --array 20040609_02_LPS1-50	

# removes both the array and sample records for the two root_file names
6) ./$PROG_NAME --run_mode delete --both 20040609_02_LPS1-40 20040609_02_LPS1-50	

#REMOVES ALL ARRAYS AND SAMPLES....Becareful
7) ./$PROG_NAME --run_mode delete --delete_all YES			

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
  	   "testonly",
  	   "array_id:s")) {
  print "$USAGE";
  exit;
}



$VERBOSE    = $OPTIONS{verbose} || 0;
$QUIET      = $OPTIONS{quiet};
$DEBUG      = $OPTIONS{debug} || 0;
$TESTONLY   = $OPTIONS{testonly};
$RUN_MODE   = $OPTIONS{run_mode};

$METHOD		= $OPTIONS{method};

$UPDATE_ARRAY = $OPTIONS{array_ids};

$DELETE_ARRAY = $OPTIONS{array};
$DELETE_BOTH  = $OPTIONS{both};
$DELETE_ALL   = $OPTIONS{delete_all};

my $val = grep {$RUN_MODE eq $_} @run_modes;

unless ($val) {
  print "\n*** Invalid or missing run_mode: $RUN_MODE ***\n\n $USAGE"; 
  exit;
}


if ($RUN_MODE eq 'update' ){		#if update mode check to see if --method <name> is set correctly
  unless ($METHOD =~ /^set/ || $METHOD =~ /^show/ ) {
  	print "\n*** Must provide a --method command line argument when updating data ***$USAGE\n";
  	exit;
  		
  }

  check_setters($METHOD);

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
  print "  METHOD = $METHOD\n";
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
  
  	print "Reading Directories\n";
  	$sbeams_affy_groups->read_dirs();			#Read the affy dirs containing all the data.  Sets global object in Affy_file_groups
  	print "Starting to Read files\n";
#    print Dumper($sbeams_affy_groups);
  	parse_affy_data(object => $sbeams_affy_groups);		#extract useful bits of information
  	print "Starting to Add Arrays\n";
  	add_affy_arrays(object => $sbeams_affy);		#add all the data to the database
  
  
  	write_error_log(object => $sbeams_affy_groups);
  	if (@BAD_PROJECTS){
  		print "ERROR: PROJECT WITH NO PROJECT ID's\n";
  		print @BAD_PROJECTS;
  	}
  
  }elsif( $RUN_MODE eq 'delete') {
  	unless ($DELETE_ARRAY || $DELETE_BOTH || $DELETE_ALL) {
  		die "*** Please provide command line arg --both or --array with a valid affy array_id when attempting to delete data\n",
  		"Or provide the command line arg --delete_all YES\n",
  		"You provided '$DELETE_ARRAY' or '$DELETE_BOTH'\n ***\n$USAGE";
  	}
  	
  	delete_affy_data();
  }else{
  	die "This is not a valid run mode '$RUN_MODE'\n $USAGE";
  }
}

###############################################################################
# add_affy_arrays
#
#Take all the objects that were created reading the files and add (or update) data to the affy_array table
###############################################################################
sub add_affy_arrays {
  my $SUB_NAME = 'add_affy_arrays';
  my %args = @_;
  
  my $sbeams_affy = $args{'object'};
  
  
  foreach my $affy_o ($sbeams_affy->registered) {
  	
  	next unless ($affy_o->get_afs_project_id);			#Some Affy objects might not be used to store array data.  This appears bad
  	
  	
  	#return the affy_array_id if the array is already in the db otherwise return 0
  	my $db_affy_array_id = $sbeams_affy_groups->find_affy_array_id(root_file_name => $affy_o->get_afa_file_root());	
  								
  	if ( $db_affy_array_id == 0){					
  		if ($VERBOSE > 0) {
  			print "ADDING OBJECT '". $affy_o->get_afa_file_root(). "'\n";
  			
  		}	
  	
  		
  		
  		
  		my $rowdata_ref =    	{ 	
  					 file_root 		=> $affy_o->get_afa_file_root,
  					 array_type_id  => $affy_o->get_afa_array_type_id,
  					 user_id 		=> $affy_o->get_afa_user_id,
  					 processed_date	=> $affy_o->get_afa_processed_date ? $affy_o->get_afa_processed_date: 'CURRENT_TIMESTAMP',
  					 affy_array_sample_id=>$affy_o->get_afs_affy_array_sample_id  , 	
  				     file_path_id	=> $affy_o->get_afa_file_path_id, 
  					 affy_array_protocol_ids => $affy_o->get_afa_affy_array_protocol_ids,
  					 comment 		=>$affy_o->get_afa_comment,
  					};   
  		
  		my $new_affy_array_id = $sbeams->updateOrInsertRow(
  						table_name=>$TBMA_AFFY_ARRAY,
  			   			rowdata_ref=>$rowdata_ref,
  			   			return_PK=>1,
  			   			verbose=>$VERBOSE,
  			   			testonly=>$TESTONLY,
  			   			insert=>1,
  			   			PK=>'affy_array_id',
  			   		   	add_audit_parameters=>1,
  					        );
  	
  		
  		if ($new_affy_array_id){
  			add_protocl_information(object 		=> $affy_o,
  						affy_array_id	=> $new_affy_array_id
  						);
  		}
  		
  	}elsif ($db_affy_array_id =~ /^\d/   && $RUN_MODE eq 'update'){		#come here if the root_file name has been seen before
  	
  		if ($VERBOSE > 0) {
  			print "UPDATEING DATA '" . $affy_o->get_afa_file_root . "'\n",
  				"METHODS '$METHOD' ARRAY_ID '$db_affy_array_id'\n";
  		}
  		
  		update_data(	object   => $affy_o,
  				array_id => $db_affy_array_id,
  			   	method	 => $METHOD,
  			   );
  	
  	
  	}else{
  		
  		if ($VERBOSE > 0 ){
  			print Dumper("BAD OBJECT MISSING STUFF" . $affy_o);
  		}
  	}
  }
}


###############################################################################
# add_protocl_information
#
#Add protocol information to the linking tables and affy array and affy sample tables
###############################################################################
sub add_protocl_information {
  my $SUB_NAME = 'add_protocl_information';
  
  my %args = @_;
  my $affy_o = $args{object};
  my $affy_array_id = $args{affy_array_id};
  
  my $affy_array_sample_id = $affy_o->get_afs_affy_array_sample_id();
  
  my $sample_protocol_val     = $affy_o->get_afs_affy_sample_protocol_ids();
  my $affy_array_protocol_val = $affy_o->get_afa_affy_array_protocol_ids();
  $sample_protocol_val = '' if !defined $sample_protocol_val;
  my @sample_ids = split /,/, $sample_protocol_val;			#might be comma delimited list of protocol_ids
  
  
  foreach my $protocol_id ( @sample_ids ){				#add protocols to the sample protocol linking table

  	my $clean_table_name = $TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL;	#the returnTableInfo cannot contain the database name on Example Microarray.dbo.affy_array
  				
  	$clean_table_name =~ s/.*\./MA_/;				#remove everything upto the last period
  			
  	my ($PK_COLUMN_NAME) = $sbeams->returnTableInfo($clean_table_name,"PK_COLUMN_NAME");	#get the column name for the primary key
  		
  	my $rowdata_ref = { 	affy_array_sample_id 	=> $affy_array_sample_id,
  				protocol_id		=> $protocol_id,
  			  }; 
  
  	
  	
  	my $affy_array_sample_protocol_id = $sbeams->updateOrInsertRow(				#add the affy array sample protocol data to the linking table
  						table_name=>$TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL,
  			   			rowdata_ref=>$rowdata_ref,
  			   			return_PK=>1,
  			   			verbose=>$VERBOSE,
  			   			testonly=>$TESTONLY,
  			   			insert=>1,
  			   			PK=>$PK_COLUMN_NAME,
  			   		   	add_audit_parameters=>1,
  					   );
  	if ($VERBOSE > 0){
  		print "ADD PROTOCOL '$protocol_id' to SAMPLE LINKING TABLE '$affy_array_sample_protocol_id' for SAMPLE '$affy_array_sample_id'\n";
  	}
  
  }
   #################################################################################
   ###Add the protocols to the array linking table
        $affy_array_protocol_val = '' if !defined $affy_array_protocol_val;
  my @array_p_ids = split /,/, $affy_array_protocol_val;			#might be comma delimited list of protocol_ids
  
  
  foreach my $protocol_id ( @array_p_ids ){				#add protocols to the sample protocol linking table

  	my $clean_table_name = $TBMA_AFFY_ARRAY_PROTOCOL;		#the returnTableInfo cannot contain the database name on Example Microarray.dbo.affy_array
  				
  	$clean_table_name =~ s/.*\./MA_/;				#remove everything upto the last period
  			
  	my ($PK_COLUMN_NAME) = $sbeams->returnTableInfo($clean_table_name,"PK_COLUMN_NAME");	#get the column name for the primary key
  		
  	my $rowdata_ref = { 	affy_array_id 		=> $affy_array_id,
  				protocol_id		=> $protocol_id,
  			  }; 
  
  	
  	
  	my $affy_array_protocol_id = $sbeams->updateOrInsertRow(				#add the affy array sample protocol data to the linking table
  						table_name=>$TBMA_AFFY_ARRAY_PROTOCOL,
  			   			rowdata_ref=>$rowdata_ref,
  			   			return_PK=>1,
  			   			verbose=>$VERBOSE,
  			   			testonly=>$TESTONLY,
  			   			insert=>1,
  			   			PK=>$PK_COLUMN_NAME,
  			   		   	add_audit_parameters=>1,
  					   );
  	if ($VERBOSE > 0){
  		print "ADD PROTOCOL '$protocol_id' to AFFY ARRAY LINKING TABLE '$affy_array_protocol_id' for ARRAY '$affy_array_id'\n";
  	}
  
  }


} #end of protocol uploads
###############################################################################
# update_data
#
# If data needs to be update come here
###############################################################################
sub update_data {
  my $SUB_NAME = 'update_data';
  
  if ($VERBOSE > 0) {
  	print "IM GOING TO UPDATE DATA\n";
  }
  my %args = @_;
  
  my $affy_o      		= $args{object};
  my $affy_array_id  = $args{array_id};
  my $method_names 	= $args{method};

  my %table_names = ( afa   => $TBMA_AFFY_ARRAY,
  		    afs   => $TBMA_AFFY_ARRAY_SAMPLE,
  		    afap  => $TBMA_AFFY_ARRAY_PROTOCOL,		#will use these if we need to update the linking tables
  		    afsp  => $TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL,
  		  );  

  my @methods = split /,/, $args{method};
  print "ALL METHODS '@methods'\n" if ($VERBOSE >0)	;
###############################################################################################
##Start looping through all the methods	
  foreach my $method (@methods) {
  #parse the method name to figure out what table and column to update
  #example set_afs_sample_tag  TABLE types afs => (af)fy array (s)ample or afa => (af)fy (a)rray 	
  	if ($method =~ /set_(af.+?)_(.*)/){			
  		my $table_type = $1;
  		my $table_name = $table_names{$table_type};	#table name for the data to update
  

  		my $column_name = $2;
  		#bit dorky but we want to call the get_(method) but on the command line we entered set_(method)
  		$method =~ s/set_/get_/;			
  								
  		my $rowdata_ref ={};
  		
  		##if we have a list of arrays to update just update a few specific arrays
  		if ($UPDATE_ARRAY){
  		 	
  		 	if (grep {$affy_array_id == $_} split /,/, $UPDATE_ARRAY){
  		 		$rowdata_ref = { 	$column_name  => $affy_o->$method(),	
  					
  				  };  
  		 	}
  		}else{
  		 	$rowdata_ref = { 	$column_name  => $affy_o->$method(),	
  					
  				  };  
  		}
  		
  		
  		#the returnTableInfo cannot contain the database name for Example Microarray.dbo.affy_array
  		my $clean_table_name = $table_name;		
  		#remove everything upto the last period and append on the db prefix to make MA_affy_array
  		$clean_table_name =~ s/.*\./MA_/;		
  		
  		#get the column name for the primary key
  		my ($PK_COLUMN_NAME) = $sbeams->returnTableInfo($clean_table_name,"PK_COLUMN_NAME");	
  		
  		my $pk_value = '';
  		#if we are updating data in the affy_array table then we can use the affy_array_id which was passed in
  		if ($table_type eq 'afa'){			
  			$pk_value = $affy_array_id;
  		#if we are going to update data in the sample table use the affy_array_id and find the affy_sample_id
  		}elsif( $table_type eq 'afs'){			
  			
  			$pk_value = $sbeams_affy_groups->find_affy_array_sample_id(affy_array_id => $affy_array_id);
  		}
  		
  		
  		if ($method =~ /protocol_ids$/){		#if this is a method to update the protocol_ids we will need to update the data in the linking tables too.
  			my $protocol_prefix = "${table_type}p"; #append a "p" to figure out which protocol linking table to update
  			
  			update_linking_table(	object 	   => $affy_o,
  						fk_value   => $pk_value,	#will need the foreign key to update the linking table
  						method	   => $method,
  					    linking_table_name => $table_names{$protocol_prefix},
  						
  			);
  		}
  		
  		
  		if ($DEBUG > 0) {
  			print "UPDATE DATA FOR TABLE '$table_name' CLEAN NAME '$clean_table_name' \n", 
  				"PK_NAME = '$PK_COLUMN_NAME', PK_value = '$pk_value'\n",
  				"COLUMN NAME '$column_name' DATA '" . $affy_o->$method() . "'\n";
  			
  			print Dumper($rowdata_ref);
  		}
  		
  		
 ####################################################################################################
 ### Updating the Organization id
  		
  		if ($method =~ /afa_user_id$/){					#if we are updating the user ID for whatever reason we will have to update the sample_provider_organization_id too, since it is found by quering with the 
  										#user_login_id
  			
  			my $table_name = $TBMA_AFFY_ARRAY_SAMPLE;
  			my $clean_table_name = $TBMA_AFFY_ARRAY_SAMPLE;		#the returnTableInfo cannot contain the database name for Example Microarray.dbo.affy_array
  			$clean_table_name =~ s/.*\./MA_/;			#remove everything upto the last period and append on the db prefix to make MA_affy_array
  		
  			my ($PK_COLUMN_NAME) = $sbeams->returnTableInfo($clean_table_name,"PK_COLUMN_NAME");	#get the column name for the primary key
  		
  			
  			my $pk_value = $sbeams_affy_groups->find_affy_array_sample_id(affy_array_id => $affy_array_id);
  			
  			
  			my $user_login_id = $affy_o->get_afa_user_id;
  			
  			my $org_id = get_organization_id(user_login_id => $user_login_id);
  			
  			my $rowdata_ref = { 	sample_provider_organization_id  => $org_id,	
  					        
  				  	  };  
  			
  			if ($DEBUG > 0) {
  			print "UPDATE DATA FOR ORGANIZATION '$table_name' CLEAN NAME '$clean_table_name' \n", 
  				"USER ID = '$user_login_id' PK_NAME = '$PK_COLUMN_NAME', PK_value = '$pk_value'\n",
  				"COLUMN NAME '$column_name' DATA '$org_id' \n";
  			
  			print Dumper($rowdata_ref);
  			}
  			
  			
  			my $returned_id = $sbeams->updateOrInsertRow(
  						table_name=>$table_name,
  			   			rowdata_ref=>$rowdata_ref,
  			   			return_PK=>1,
  			   			verbose=>$VERBOSE,
  			   			testonly=>$TESTONLY,
  			   			update=>1,
  			   			PK_name => $PK_COLUMN_NAME,
  						PK_value=> $pk_value,
  			   		   	add_audit_parameters=>1,
  					   );
  		}
####################################################################################################			
### Update the data
  		my $returned_id = $sbeams->updateOrInsertRow(
  						table_name=>$table_name,
  			   			rowdata_ref=>$rowdata_ref,
  			   			return_PK=>1,
  			   			verbose=>$VERBOSE,
  			   			testonly=>$TESTONLY,
  			   			update=>1,
  			   			PK_name => $PK_COLUMN_NAME,
  						PK_value=> $pk_value,
  			   		   	add_audit_parameters=>1,
  					   );
  		
  		
  	}else{
  		print "ERROR Cannot Parse Method name '$method' to update data\n";
  	}
  }

}

###############################################################################
# update_linking_table
#
#If the data in the protocol_ids column is updated, usually a comma delimited list of protocol ids, we will need to change
#the data within the linking table too.  This subroutine will first delete ALL protocol ids from the linking table for a particular affy_array_id
#then insert the new records
###############################################################################
sub update_linking_table {
  my $SUB_NAME = 'update_linking_table';
  my %args = @_;
  
  my $affy_o 	  	= $args{object};
  my $fk_value 	  	= $args{fk_value};		#this will be the affy_array_id or affy_array_sample_id
  my $method 	  	= $args{method};		
  my $linking_table_name 	= $args{linking_table_name};	#Linking table name that will be updated full database table name Example Microarray.dbo.affy_array
  
  my $c_linking_table_name = $linking_table_name;		#the returnTableInfo cannot contain the database name for Example Microarray.dbo.affy_array
  $c_linking_table_name =~ s/.*\./MA_/;			#remove everything upto the last period and append on the db prefix to make MA_affy_array
  		
  
  
  my ($foregin_key_column_name, $foreign_tbl_name) = $sbeams->returnTableInfo($c_linking_table_name, 'fk_tables'); 	#to figure out what table we were updating
  
  my ($PK_COLUMN_NAME) = $sbeams->returnTableInfo($c_linking_table_name,"PK_COLUMN_NAME");				#get the column name for the primary key
  
  delete_linking_table_records(	fk_value   	    => $fk_value,
  			 	fk_column_name      => $foregin_key_column_name,
  			 	protocol_table_name => $linking_table_name,
  			     );
  
  
  my $project_ids = $affy_o->$method();		#grab the comma delimited list of protocol ids
  
  my @all_ids = split/,/, $project_ids;		#split them apart
  
  foreach my $protocol_id (@all_ids){		#foreach protocol id insert the data into the linking table
  						
  	
  	my $rowdata_ref = { 	$foregin_key_column_name => $fk_value,
  				protocol_id		 => $protocol_id,
  			  }; 
  
  	
  	
  	my $affy_array_protocol_id = $sbeams->updateOrInsertRow(				#add the affy array sample protocol data to the linking table
  						table_name=>$linking_table_name,
  			   			rowdata_ref=>$rowdata_ref,
  			   			return_PK=>1,
  			   			verbose=>$VERBOSE,
  			   			testonly=>$TESTONLY,
  			   			insert=>1,
  			   			PK=>$PK_COLUMN_NAME,
  			   		   	add_audit_parameters=>1,
  					   );
  					
  }
} 
###############################################################################
# delete_linking_table_records
#
#Delete the records for a given a fk in a protocol linking table
###############################################################################
sub delete_linking_table_records {
  my $SUB_NAME = 'delete_linking_table_records';
  
  my %args = @_;
  
  my $fk_value 	   = $args{fk_value};			#this will be the affy_array_id or affy_array_sample_id
  my $table_name 	   = $args{protocol_table_name};	#Linking table name that will be updated
  my $fk_column_name = $args{fk_column_name};		#Column in the linking column that holds the foregin key
  
  my $sql = qq~ 	delete 
  		from $table_name
  		where $fk_column_name = $fk_value
  	     ~;
  
  
  
  if ($VERBOSE > 0) {
  	print "DELETE LINKING TABLE PROTOCOLS WITH SQL STATEMENT\n$sql\n";
  }
  my $delete_count = $sbeams->executeSQL(sql=>$sql);
  
  if ($delete_count == 0){
  	print "ERROR: COULD NOT DELETE PROTOCOL FROM PROTOCOL LINKING TABLE '$table_name'\n";
  }
  
}
  
  
###############################################################################
# parse_affy_data
#
#For each group of files found in the main affy directory check to see if the minimal amount of data is present
#then parse and the XML file to extract relevant information to put into the database.
###############################################################################
sub parse_affy_data {
  my $SUB_NAME = 'parse_affy_data';
  
  
  my %args = @_;
  
  my $sbeams_affy_groups = $args{object};
  
  foreach my $file_name ( $sbeams_affy_groups->sorted_root_names() ) {				
    print "$file_name\n" if $VERBOSE;
  	
  	#next unless ($file_name =~ /3AJZ/);
  	#print "FILE NAME '$file_name'\n";
  	next unless ($sbeams_affy_groups->check_file_group(root_file_name => $file_name) eq 'YES');
  	
  	my $return = $sbeams_affy_groups->check_previous_arrays(root_name => $file_name);	#return the affy_array_id if the array is already in the db
  	if ($return != 0 && $RUN_MODE eq 'add_new'){
  		if ($VERBOSE > 0){
  			print "FILE ROOT IS ALREADY IN DATABASE AND WE ARE NOT IN UPDATE MODE SKIP PARSING '$file_name'\n";
  		}
  		next;
  	}
  	
  	my $sample_tag	= '';
  	if ($file_name =~ /^\d+_\d+_(.*)/){				#Parse the Sample tag from the root_file name example 20040707_05_PAM2B-80
  		$sample_tag = $1;
  		
  	}else{
  		$sbeams_affy_groups->group_error(root_file_name => $file_name,
  							 error => "CANNOT FIND SAMPLE NAME FROM ROOT NAME",
  						);
  		next;
  	}
  	
  	
  	
  	my $sbeams_affy = new SBEAMS::Microarray::Affy;			#make new affy instances
  	
  	$sbeams_affy->set_afa_file_root($file_name);			
  	
  	print "FILE NAME IS '$file_name'\n" if ($VERBOSE >0);
  	
  	
  	$sbeams_affy->set_afs_sample_tag($sample_tag);			#set the sample_tag, within a project this should be a unique name
  	
##Load up the base path info.  Assume that the CEL file will always be present
  	my $basepath = dirname($sbeams_affy_groups->get_file_path(root_file_name => $file_name,
  								  file_ext 	 => 'CEL', 
  								  ));
  		
  		my $base_path_id = get_file_path_id( basepath => $basepath);
  		
  		if ($VERBOSE> 0) {
  			print "BASENAME '$basepath' CONVERTED TO FILE_PATH_ID '$base_path_id'\n";
  		}
  		
  		$sbeams_affy->set_afa_file_path_id($base_path_id);	
  	
  	
  	
  	if (my $xml_file =  $sbeams_affy_groups->get_file_path( root_file_name 	=> $file_name,
  								file_ext 	=> 'XML', 
  							      )
  	   )   {		   
  	   	parse_xml_files(file   		=> $xml_file,
  				affy_object 	=> $sbeams_affy,
  				affy_group_obj 	=> $sbeams_affy_groups,
  				root_file 	=> $file_name,
  				sample_tag	=> $sample_tag,
  				);
  	}elsif(my $info_file = $sbeams_affy_groups->get_file_path(root_file_name => $file_name,
  								  file_ext 	 => 'INFO', 
  								  )
  	      )   {
  	  	parse_info_file(file   => $info_file,
  						object => $sbeams_affy,
  						affy_group_obj 	=> $sbeams_affy_groups,
  						root_file 	=> $file_name,
  						sample_tag	=> $sample_tag,
  				       );
  	}else{
  		print "****NO REFERENCE DATA FOR '$file_name'\n";
  	}
  }
}
  
###############################################################################
#get_file_path_id	
#
#Change the file base path to an id
###############################################################################
sub get_file_path_id {
  my $SUB_NAME = 'get_file_path_id';
  
  my $basepath = '';
  
  my %args = @_;
  
  $basepath = $args{basepath};
  
 
  if (exists $HOLD_COVERSION_VALS{BASE_PATH}{$basepath}) {		#first check to see if this path has been seen before, if so pull it from memory
  	return $HOLD_COVERSION_VALS{BASE_PATH}{$basepath};		#return the file_path.file_path_id
  }
  
  
  									#if we have not seen the base path look in the database to see if has been entered 
  my $sql = qq~ 	SELECT file_path_id
  		FROM $TBMA_FILE_PATH
  		WHERE file_path like '$basepath'
  	   ~;
  
  my @rows = $sbeams->selectOneColumn($sql);		
  if (@rows){
  	$HOLD_COVERSION_VALS{BASE_PATH}{$basepath} = $rows[0];
  	return $rows[0];						#return the file_path.file_path_id
  }
  
  
  unless(@rows){
  	
  my $rowdata_ref = { 	file_path_name => 'Path to Affy Data',	#if the base path has not been seen insert a new record
  			file_path 	=> $basepath,
  			server_id=> 1, 				#hack to default to server id 1.  FIX ME
  		};   
  		
  		
  		if ($DEBUG > 0) {
  			print "SQL DATA\n";
  			print Dumper($rowdata_ref);
  		}
  		my $file_path_id = $sbeams->updateOrInsertRow(
  						table_name=>$TBMA_FILE_PATH,
  			   			rowdata_ref=>$rowdata_ref,
  			   			return_PK=>1,
  			   			verbose=>$VERBOSE,
  			   			testonly=>$TESTONLY,
  			   			insert=>1,
  			   			PK=>'file_path_id',
  			   		   	add_audit_parameters=>1,
  					   );
  	
  	$HOLD_COVERSION_VALS{BASE_PATH}{$basepath} = $file_path_id;
  	return $file_path_id
  }		   
  
  
}

###############################################################################
#parse_xml_files	
#
#If one of the group of files is a MAGE-XML file with the file extension XML parse it for the user, using the passed in x-path statement
###############################################################################
sub parse_xml_files {
  my $SUB_NAME = 'parse_xml_files';
  
  my %args = @_;
  
  my $xml_file = $args{'file'};
  my $sbeams_affy = $args{'affy_object'};
  my $sbeams_affy_groups = $args{'affy_group_obj'};
  my $root_file   = $args{'root_file'};
  my $sample_tag = $args{'sample_tag'};
   				
  	
  print "XML FILE NAME '$xml_file'\n" if ($VERBOSE > 0);
  		
  my $xml_string = xml_string($xml_file);			#terrible hack to prevent the file from being validated with the external dtd
  		
  		
  my $xp = XML::XPath->new(xml => $xml_string);

  # Added new parsing capabilities, some of which can't be easily handled by 
  # the existing define-fetch-populate-insert methodology.

  # Collect specific set of keys and store as key=val
  # pairs in affy_array_sample.sample_treatment field
  my $biomat_base = 'MAGE-ML/BioMaterial_package/BioMaterial_assnlist/BioSource/PropertySets_assnlist/NameValueType[@name="FIELDNAME"]/@value', 
  my $expt_base = 'MAGE-ML/Experiment_package/Experiment_assnlist/Experiment/PropertySets_assnlist/NameValueType[@name="FIELDNAME"]/@value', 
  
  my %values;
  my %paths;
  my @keys;
  my $sample_treatment;
  
  my @biokeys = ( 'Array User Name', 'Stimulus 1', 'Stimulus 1 Type', 
                'Stimulus 1 Modifier', 'Time 1', 'Stimulus 2', 'Stimulus 2 Type',
                'Stimulus 2 Modifier', 'Time 2', 'Sex', 'Strain', 'Protocol',
                'Sample Template Name', 'Cell Type' );
  my @expkeys = ( 'Replicate', 'Investigator', 'Barcode', 'Experiment Template Name' );
  
  my $cnt = 0;
  
  for my $key ( @biokeys, @expkeys ) {
  
    my $path = ( $cnt++ > $#biokeys ) ? $expt_base : $biomat_base;
    $path =~ s/FIELDNAME/$key/;
  
    my $nodeset = $xp->find($path);         # Grab the node pointed by the xpath expression
    if ( $nodeset ) {
      foreach my $node ($nodeset->get_nodelist) {
        my $val = XML::XPath::XMLParser::as_string($node);
        $val =~ /value="([^"]*)"/;
        $values{$key} = $1;
        $sample_treatment .= $key . '=' .  $values{$key} . "\n";
      }
    }
  }
  
  $sbeams_affy->set_afs_treatment_description( $sample_treatment );
  $sbeams_affy->set_afs_strain_or_line( $values{Strain} );
  $sbeams_affy->set_afs_sex_ontology_term_id( $values{Sex} );
  $sbeams_affy->set_afs_cell_type( $values{'Cell Type'} );
  $sbeams_affy->set_afs_data_flag( 'OK' );
  $sbeams_affy->set_treatment_values( \%values );
  		
  # Hash keys <Table_abbreviation _ column name> which should also match the 
  # method names in Affy.pm using a direct X-path to the needed data.  Data in
  # the XML file usually the text name but the program will turn most of them 
  # into ID's for storage in the database the sort order is critical since the
  # project_id needs to be determined first.  If it is not found none of the 
  # additional data will be searched for moved most of the sql to covert a name
  # or tag to an id to the Affy.pm mod.  Note the the SQL_METHOD methods are in
  # single quotes and they will be eval(ed) later
  %data_to_find = ( 	AFS_PROJECT_ID =>  {		X_PATH	=> 'MAGE-ML/BioMaterial_package/BioMaterial_assnlist/BioSource/Characteristics_assnlist/OntologyEntry[@category="Affymetrix:Sample Project"]/@value',
                      VAL	=> '',
                      SORT	=> 1,
                      SQL_METHOD =>'$sbeams_affy->find_project_id(project_name=>$val, do_not_die => 1)' },
  
  			AFA_USER_ID    => 	{	X_PATH  => 'MAGE-ML/BioMaterial_package/BioMaterial_assnlist/BioSource/PropertySets_assnlist/NameValueType[@name="Array User Name"]/@value',  #same as Project_name xpath, could not get substring xpath expressions to work 
  					 		SORT	=> 2,
  					 		VAL	=> '',
  					 		SQL_METHOD => '$sbeams_affy->find_user_login_id(username=>$val)',
  					 		},
  			
  			AFS_ORGANISM_ID  =>	{	X_PATH  => 'MAGE-ML/BioMaterial_package/BioMaterial_assnlist/BioSource/MaterialType_assn/OntologyEntry/@value',
  					 		VAL	=> '',
  					 		SORT	=> '3',
  					 		SQL_METHOD => '$sbeams_affy->find_organism_id(organism_name=>$val)',
  					 		
  						},
  			
  			AFA_ARRAY_TYPE_ID =>    {  	X_PATH  => 'MAGE-ML/ArrayDesign_package/ArrayDesign_assnlist/PhysicalArrayDesign/@name',
  					 		VAL	=> '',
  					 		SORT	=> 4,
  					 		SQL_METHOD => '$sbeams_affy->find_slide_type_id(slide_name=>$val)',
  					 		
  						  },
  					
  		 	AFS_SAMPLE_GROUP_NAME    =>{	X_PATH  => 'MAGE-ML/BioMaterial_package/BioMaterial_assnlist/BioSource/@name',
  					          	VAL	=> '',
  					          	SORT	=> 5,
  					 
  					           },	  
  			
  			AFA_PROCESSED_DATE       =>{	X_PATH  =>'MAGE-ML/BioAssay_package/BioAssay_assnlist/PhysicalBioAssay/BioAssayTreatments_assnlist/ImageAcquisition/ProtocolApplications_assnlist/ProtocolApplication/@activityDate',
  					 		VAL	=> '',
  					 		SORT	=> 6,
  							FORMAT  => '$val =~ s/T|Z/ /g', 	#example Affy time stamp '2004-07-07T19:58:00Z' SQL format '2004-07-09 13:22:59.98'
  					            },
  			
  		### Protocols:used on arrays and samples  ####
  			AFA_HYB_PROTOCOL       	 =>{	X_PATH  =>'MAGE-ML/Protocol_package/Protocol_assnlist/Protocol/@name',
  					 		VAL	=> '',
  					 		SORT	=> 7,
  							SQL	=> "	SELECT protocol_id
  					 	  			FROM $TB_PROTOCOL
  									WHERE name like 'AFFY HOOK_VAL'",	#values in the protocol table should have a pre-fix "AFFY "
  							####need SQL	
  					            },
  			AFA_SCAN_PROTOCOL         =>{	
  					 		VAL	=> 'AFFY Scanning',			#Hard coded to single protocol
  					 		SORT	=> 8,
  							SQL	=> "	SELECT protocol_id
  					 	  			FROM $TB_PROTOCOL
  									WHERE name like 'HOOK_VAL'",
  								
  					            },
  		AFA_FEATURE_EXTRACTION_PROTOCOL   =>{	
  					 		VAL	=> 'AFFY Feature Extraction',		#Hard coded to single protocol
  					 		SORT	=> 9,
  							SQL	=> "	SELECT protocol_id
  					 	  			FROM $TB_PROTOCOL
  									WHERE name like 'HOOK_VAL'",
  								
  					            },			   		
  		   	AFA_CHP_GENERATION_PROTOCOL=>{	
  					 		VAL	=> 'AFFY GCOS CHP Generation',		#Hard coded to single protocol
  					 		SORT	=> 10,
  							SQL	=> "	SELECT protocol_id
  					 	  			FROM $TB_PROTOCOL
  									WHERE name like 'HOOK_VAL'",
  								
  					            },	
  			
  			AFA_AFFY_ARRAY_PROTOCOL_IDS =>{	
  					 		VAL	=> '',	#Used to collect comma delimited list of array protocols
  					 		SORT	=> 11,
  								
  					            },
  		
  		AFS_AFFY_SAMPLE_PROTOCOL_IDS =>{	
  					 		VAL	=> '',	#Used to collect comma delimited list of sample protocols
  					 		SORT	=> 12,	#Currently nothing to collect!! At upload time the script will not know how much starting RNA the user used which determines what protocol to use
  								
  					            },		    
  		
  		#### End of protocol section ###
  			AFS_AFFY_ARRAY_SAMPLE_ID  =>{	VAL 	 => "$sample_tag",		#bit of a hack, will query on the sample_tag and project_id which must be unique
  					  		SORT	 =>  100,			#really want this to go last since it will insert the affy_array_sample if it cannot find the Sample tag in the database.  And it needs some information collected by some of the other hash elements before it does so.	
  					  		SQL	 => "	SELECT affy_array_sample_id
  					 				FROM $TBMA_AFFY_ARRAY_SAMPLE
  									WHERE sample_tag like 'HOOK_VAL'",
  					
  					  		CONSTRAINT => '"AND project_id = " . $data_to_find{AFS_PROJECT_ID}{VAL}',
  					 	     },
  		);
  		
  		
#############################################################################################################################
  									#loop through the data_to_find keys pulling data from the XML files and converting the human readable names to id within the database
  foreach my $data_key (sort {$data_to_find{$a}{'SORT'} 		
  				<=> 
  			$data_to_find{$b}{'SORT'} }keys %data_to_find
  	         ) 
  		 {							#start foreach loop
  	
  	
  	my $val = '';

##########################################################################################
##check to see if there is a X_PATH statement to use for searching the MAGE XML file	
  	if (my $xpath = $data_to_find{$data_key}{X_PATH}){		
  		
  		if ($VERBOSE > 0) {
  			print "XPATH '$xpath'\n";
  		}
  		
  		my $nodeset = $xp->find($xpath); 				# Grab the node pointed by the xpath expression
    			
    			foreach my $node ($nodeset->get_nodelist) {
        			
    				$val = XML::XPath::XMLParser::as_string($node); #convert the node to text
  			if ($VERBOSE > 0){
  				print "FOUND NODE '$val'\n";
  			}
  			
  			$val =~ s/.+?="(.*)"/$1/; 					#Strip off the attribute name Example 'value="T4 knockout"'
  		}
  	}elsif($data_key =~ /protocol_ids$/i){				#skip setting any data for .*PROTOCOL_IDS methods since they will be set after the arrays are uploaded and to protocol id's will be generated within the linking tables
  		next;
  	
  	}else{
  		$val = $data_to_find{$data_key}{VAL};			#use the default VAL from the data_to_find hash if No XPATH statement
  	}
  	
  	
  	unless ($val) {
  		$sbeams_affy_groups->group_error(root_file_name => $root_file,
  						 error => "CANNOT FIND VAL FOR '$data_key' EITHER BY XPATH OR DEFAULT, THIS IS NOT GOOD",
  						);
  		next;
  	}
  	
  	my $id_val = '';			
  		
  	if ($VERBOSE > 0){
  		print "$data_key => '$val'\n";
  	}
##########################################################################################			
###if the data $val needs to be converted to a id value from the database run the little sql statement to do so				
  	if ($data_to_find{$data_key}{SQL} || $data_to_find{$data_key}{SQL_METHOD}) {			
  	
  	 	$id_val = convert_val_to_id( 	value    => $val,
  				   			sql    	 => $data_to_find{$data_key}{SQL},
  				   	      	sql_method => $data_to_find{$data_key}{SQL_METHOD},
  				   	      	data_key => $data_key,
  					     	affy_obj => $sbeams_affy,
  					     );
  	}elsif($data_to_find{$data_key}{FORMAT}){
  			
  		$id_val = format_val	( value    => $val,
  				   	  transform=> $data_to_find{$data_key}{FORMAT},
  				   	);
  	}else{
  		$id_val = $val;					#if the val from the XML does not need to be convert or formatted give it back
  	}
  		
#store the results of the conversion (if needed) no matter what the results are			
  	$data_to_find{$data_key}{VAL} = $id_val;		
##########################################################################################
#collected errors in the all_files_h and print them to the log file			
  	if  ($id_val =~ /ERROR/) {				
  		$sbeams_affy_groups->group_error(root_file_name => $root_file,
  						 error => "$id_val",
  						);
  		print "$id_val\n";
  			
  			
  		if ($data_key eq 'AFS_PROJECT_ID') {			#TESTING 
  			
  			push @BAD_PROJECTS, ($xml_file, "\t$val\n");
  		}
  			
  		return;						#if error converting the data to an id do not bother looking at the rest of the data move on to the next group of files
  			
  	}else{
  		set_data(value  => $id_val,			#collect the 'Good' data in Affy objects
  			 key    => $data_key,
  			 object => $sbeams_affy,
  		         );
  	}
  				
  }
  
}

###############################################################################
# format_time_val	
# format a piece of data according to the perl statement given which will be  given to an eval statement
###############################################################################
sub format_val {
  my $SUB_NAME = 'format_val';
  my %args = @_;
  
  my $val = $args{'value'};
  my $transform_statment = $args{'transform'};
  
  eval $transform_statment;				#bit tricky.. the variable $val is in the statment to be eval(ed) therefore setting the value
  
  if ($VERBOSE >0 ) {
  	print "TRANSFORMED TIME '$val'\n";
  
  }
  
  return $val;
}
  


###############################################################################
# convert_val_to_id	
# convert the data returned by the X-path into an ID if there is a sql statment to do it
# Will have to substitute the value passed in into the SQL replacing the "HOOK_VAL"
#
# Maybe should be called 'convert val to id and oh, incidentally insert an
# affy_array_sample record if you are so inclined.  Why on earth is this here!?
# 
###############################################################################
sub convert_val_to_id {
  my $SUB_NAME = 'convert_val_to_id';
  
  my %args = @_;
  
  my $val = $args{'value'};
  my $sql = $args{'sql'};
  my $sql_method = $args{'sql_method'};
  
  my $data_key    = $args{'data_key'};
  my $sbeams_affy = $args{'affy_obj'};
  
  print "STARTING $SUB_NAME\n" if ($VERBOSE>0);
  return unless ($sql || $sql_method)  && $val;
  
  
  	###########################################	
   
  if (exists $HOLD_COVERSION_VALS{$data_key}{$val}) {			#if the value has been used before in a query and it returned an id just reuse the previous id instead of requiring 
  	if ($VERBOSE > 0){
  		print "VAL '$val' for '$data_key' HAS BEEN SEEN BEFORE RETURNING",
  		 " DATA '$HOLD_COVERSION_VALS{$data_key}{$val}' FROM CONVERSION VAL HASH\n";	
  	}
  	return $HOLD_COVERSION_VALS{$data_key}{$val}
  }
  	###########################################	
  
  my @rows = ();
  if($sql){
  	$sql =~ s/HOOK_VAL/$val/;								#replace the 'HOOK_VAL' in the sql query with the $val
  	
  	if (exists $data_to_find{$data_key}{'CONSTRAINT'}) {					#if there is a constraint to attach to the sql attach the value to the sql statment
  		my $constraint = '';
  		
  		$constraint = eval  $data_to_find{$data_key}{'CONSTRAINT'};			#takes the value from the CONSTRAINT key, then does an eval on the perl statement returning the value which can then be appended to the sql statment
  		
  		if ($@){
  			print "ERROR: COULD NOT ADD CONSTRAINT to SQL '$@'\n";
  			die;
  		}
  		
  		if ($VERBOSE > 0 ) {
  			print "ADDING CONSTRAINT TO SQL '$constraint'\n";
  		}
  		$sql .= $constraint;
  	}	
  	print "ABOUT TO RUN SQL'$sql'\n" if ($VERBOSE>0);
  	@rows = $sbeams->selectOneColumn($sql);
  }elsif($sql_method && $val){
  	print "SQL METHOD TO RUN '$sql_method'\n" if ($VERBOSE>0);
  	
  	@rows = eval $sql_method;			#eval the sql_method which will point to a method in Affy.pm, that should convert a name tag to the database id
  		
  		if ($@){
  			print "ERROR: COULD NOT RUN METHOD '$sql_method' '$@'\n";
  			die;
  		}
  }
  
  
  
  if ($VERBOSE > 0){
  	print "SUB '$SUB_NAME' SQL '$sql'\n";
  	print "DATA TO CONVERT '$data_key' RESULTS '@rows'\n";
  }
  
  if (defined $rows[0] && $rows[0] =~ /^\d/){									#if the query works it will give back a id, if not it will try and find a default value below
  	$HOLD_COVERSION_VALS{$data_key}{$val} = $rows[0];
  	return $rows[0];
  
  }else{
  	if ($data_key eq 'AFS_AFFY_ARRAY_SAMPLE_ID') {							#if there was no affy_sample_id then the record needs to be inserted
  		
  		my $organization_id = get_organization_id(user_login_id => $data_to_find{AFA_USER_ID}{VAL});	#Grab the organization_id if there is a valid user_login_id
  	
  		my $rowdata_ref = { 	
  					project_id 					=> $sbeams_affy->get_afs_project_id(),		#get the project_id, should always be the first piece of data to be converted
  					sample_tag 					=> $sbeams_affy->get_afs_sample_tag(),
  					sample_group_name 			=> $sbeams_affy->get_afs_sample_group_name(),
  					affy_sample_protocol_ids 	=> $sbeams_affy->get_afs_affy_sample_protocol_ids(),
 				   	sample_preparation_date		=> $sbeams_affy->get_afs_sample_preparation_date()? 
  				   									$sbeams_affy->get_afs_sample_preparation_date(): 
  				   									'CURRENT_TIMESTAMP' , 	#default to current time stamp, user is the only one who knows this data
            sample_provider_organization_id =>$organization_id,
            organism_id 				=> $sbeams_affy->get_afs_organism_id(),    
            strain_or_line 				=> $sbeams_affy->get_afs_strain_or_line(),
  					individual 					=> $sbeams_affy->get_afs_individual(),
  					sex_ontology_term_id 		=> $sbeams_affy->get_afs_sex_ontology_term_id(),
  					age 						=> $sbeams_affy->get_afs_age(),
  					organism_part				=> $sbeams_affy->get_afs_organism_part(),
  					cell_line 					=> $sbeams_affy->get_afs_cell_line(),
  					cell_type 					=> $sbeams_affy->get_afs_cell_type(),
  					disease_state 				=> $sbeams_affy->get_afs_disease_state(),
  					rna_template_mass 			=> $sbeams_affy->get_afs_rna_template_mass(),
  					protocol_deviations 		=> $sbeams_affy->get_afs_protocol_deviations(),
  					sample_description 			=> $sbeams_affy->get_afs_sample_description(),
  					treatment_description 		=> $sbeams_affy->get_afs_treatment_description(),
  					comment 					=> $sbeams_affy->get_afs_comment(),
  					data_flag 					=> $sbeams_affy->get_afs_data_flag(),
  				   };   
  		
      if ($DEBUG) {
  			print "SQL DATA\n";
  			print Dumper($rowdata_ref);
  		}
  		my $sample_id = $sbeams->updateOrInsertRow(
  						table_name=>$TBMA_AFFY_ARRAY_SAMPLE,
  			   			rowdata_ref=>$rowdata_ref,
  			   			return_PK=>1,
  			   			verbose=>$VERBOSE,
  			   			testonly=>$TESTONLY,
  			   			insert=>1,
  			   			PK=>'affy_array_sample_id',
  			   		   	add_audit_parameters=>1,
  					   );
  			   
  		
  		print "SAMPLE ID '$sample_id'\n";

      if ( $sample_id ) {
        insert_treatment_records( sample_id => $sample_id,
                                  sbeams_affy => $sbeams_affy );
      }
  		
  		unless ($sample_id){
  			return "ERROR: COULD NOT ENTER SAMPLE FOR SAMPLE TAG '" . 
  			$sbeams_affy->get_afs_sample_tag() ."'\n";
  		}
  		
  		return $sample_id;		#SHOULD CHECK THIS
  	
  	}
  	
  	return "ERROR: CANNOT FIND ID CONVERTING '$data_key' FOR VAL '$val'";
  }
}


sub insert_treatment_records {
  my %args = @_;
  return unless $args{sample_id}  || $args{sbeams_affy};
  my $treatments = $args{sbeams_affy}->get_treatment_values();
  for my $treatment ( @{$treatments} ) {
    my $treat_id = $sbeams->updateOrInsertRow( PK => 'treatment_id',
                                      table_name  => $TBMA_TREATMENT,
                                      rowdata_ref => $treatment,
                                        return_PK => 1,
                                          verbose => $VERBOSE,
                                         testonly => $TESTONLY,
                                           insert => 1,
                             add_audit_parameters => 1,
                                              );
    print "added treatment $treat_id \n" if $DEBUG;

    next unless $treat_id;
    # Add any treatment to sample links
    my $rowdata = { treatment_id => $treat_id,
                    affy_array_sample_id => $args{sample_id } };
  		
    my $ast_id = $sbeams->updateOrInsertRow( PK => 'affy_sample_treatment_id',
                                    table_name  => $TBMA_AFFY_SAMPLE_TREATMENT,
                                    rowdata_ref => $rowdata,
                                      return_PK => 1,
                                        verbose => $VERBOSE,
                                       testonly => $TESTONLY,
                                         insert => 1,
                           add_audit_parameters => 0,
                                            );
    
  }

}

###############################################################################
# get_organization_id	
# 
# given the user_login_id get the organization id
###############################################################################
sub get_organization_id {
  my $SUB_NAME = 'get_organization_id';

  my %args = @_;
  
  my $user_login_id = $args{'user_login_id'};
  
  return unless ($user_login_id =~ /^\d+$/);
  
  if (exists $HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id}) {			#if the user_id has been seen before return the org_id
  
  	return $HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id};
  	
  }
  
  my $sql = qq~ 	SELECT o.organization_id, organization 
  		FROM $TB_ORGANIZATION o, $TB_CONTACT c, $TB_USER_LOGIN ul
  		WHERE ul.user_login_id = $user_login_id AND
  		ul.contact_id = c.contact_id AND
  		c.organization_id = o.organization_id
  	  ~;
  
  my @rows = $sbeams->selectOneColumn($sql);
  
  if ($rows[0]) { 
  	$HOLD_COVERSION_VALS{'ORG_VAL'}{$user_login_id} = $rows[0];		#save the user_id Organization_id for future access
  	return $rows[0];
  
  }else{
  	return ;
  }
}

###############################################################################
# set_data	
# convert the data_to_find hash key to a method name and set the data in the affy object
#
###############################################################################
sub set_data {
  my $SUB_NAME = 'set_data';
  
  my %args = @_;
  
  my $sbeams_affy = $args{'object'};
  
  my $data_key = lc ($args{'key'});
  my $method_name = "set_$data_key";		#make the method name to call to the Microarray::Affy class
  
  if ($VERBOSE > 0){
  	print "METHOD NAME '$method_name' VAL '$args{value}'\n";
  }
  
  $sbeams_affy->$method_name($args{'value'});	#set the value
}
  

###############################################################################
#xml_string	
#
#Hack to remove the reference of the file being stand alone which will prevent the
#external dtd from being loaded.  Could not prevent XML::Parser from trying to load the dtd even with XML::Checker::Parser. Might have been using it incorrectly???
###############################################################################

sub xml_string {
  my $SUB_NAME = 'xml_string';
  
  my $file = shift;
  
  open XML, $file or 
  	die "CANNOT open XML FILE '$file' $!\n";
  	
  my $data = '';
  
  while (<XML>){
  	$data .= $_;
  }
  close XML;
  
  if ($data =~ s/<\?xml.+?MAGE-ML\.dtd">//s){
  	return $data;
  }else{
  	print "$data";
  	die "CANNOT FIND XML HEADER";
  }
}

###############################################################################
# delete_affy_data
#
# If the run_mode is delete come here and delete some data
###############################################################################

sub delete_affy_data {
  my $SUB_NAME = 'delete_affy_data';

  my %table_child_relationship = ();
  my @all_array_root_names = ();
  my $table_name = '';
  my @sample_ids_to_delete = ();
  
  
  if ( $DELETE_ARRAY ) {							#Come here if just going to delete the array but leave the sample
  	
  	@all_array_root_names = split /\s+/, $DELETE_ARRAY;		#might be space separated list of arrays root names to delete
  	
  	%table_child_relationship = (					#table relationship needed by deleteRecordsAndChildren
      				affy_array => 'affy_array_protocol(C)',		#delete the array and the children in the affy_array_protocol table
      		
   				);
  	
  
  	foreach my $root_name ( @all_array_root_names) {
  		
  		my $affy_array_id = $sbeams_affy_groups->find_affy_array_id(root_file_name => $root_name);
  		
  		unless ($affy_array_id) {
  			print "THE ROOT FILE NAME '$root_name' WAS NOT FOUND IN THE DATABASE SO NOTHING WILL BE DELETED\n";
  			next;
  		}
  		
  		if ($VERBOSE > 0) {
  			print "ABOUT TO DELETE ARRAY '$root_name' with AFFY_ARRAY_ID '$affy_array_id'\n";
  		}
  		my $result = $sbeams->deleteRecordsAndChildren(
         					table_name 	=> "$table_name",
         					table_child_relationship => \%table_child_relationship,
         					delete_PKs 	=> [ $affy_array_id ],
         					delete_batch 	=> 10000,
         					database 	=> $DATABASE,
         					verbose 	=> $VERBOSE,
         					testonly 	=> $TESTONLY,
  					);
  		
  		print "RESULT '$result' OF DELETING '$root_name'\n";
  	}
  
  
  
  }elsif ($DELETE_BOTH){							#Come here if both the array and sample info need to be deleted
  
  	@all_array_root_names = split /\s+/, $DELETE_BOTH;		#might be space separated list of arrays root names to delete
  	
  	%table_child_relationship = (					#table relationship needed by deleteRecordsAndChildren
      				
      				affy_array => 'affy_array_protocol(C)',		#Below it will utilize this hash to delete the affy_array rows then loop back and take out the sample rows
  			affy_array_sample => 'affy_array_sample_protocol(C)',
  			);

  	
  	
  	foreach my $table_name ( ('affy_array', 'affy_array_sample')) {	#need to loop through the different tables to delete the arrays first then the samples because of a constraint between arrays and samples
  			
  		if ($table_name eq 'affy_array'){
  		
  			
  			foreach my $root_name ( @all_array_root_names) {	#DELETE the affy_array and child records
  				my $affy_array_id = $sbeams_affy_groups->find_affy_array_id(root_file_name => $root_name);
  				
  				unless ($affy_array_id) {
  					print "THE ROOT FILE NAME '$root_name' WAS NOT FOUND IN THE DATABASE SO NOTHING WILL BE DELETED\n";
  					next;
  				}
  			
  			
  				my $affy_array_sample_id = $sbeams_affy_groups->find_affy_array_sample_id(affy_array_id => $affy_array_id);
  				
  				push @sample_ids_to_delete,$affy_array_sample_id; #hold the sample ids until the arrays are gone.  Assume for now that only one array points to sample
  			
  			
  				my $result = $sbeams->deleteRecordsAndChildren(
         							table_name 	=> "$table_name",
         							table_child_relationship => \%table_child_relationship,
         							delete_PKs 	=> [ $affy_array_id ],
         							delete_batch 	=> 10000,
         							database 	=> $DATABASE,
         							verbose 	=> $VERBOSE,
         							testonly 	=> $TESTONLY,
  							);
  			
  			}	
  				
  		}elsif($table_name eq 'affy_array_sample'){			#DELETE THE Samples and child records
  			
  			
  			if (@sample_ids_to_delete){				#make sure there are samples to delete
  				my $PK_ids_to_delete = join ",", @sample_ids_to_delete;
  			
  				
  				
  				if ($VERBOSE > 0){
  					print "ABOUT TO DELETE SAMPLESssss '$PK_ids_to_delete'\n";
  				}
  			
  				
  				my $result = $sbeams->deleteRecordsAndChildren(
         							table_name 	=> "$table_name",
         							table_child_relationship => \%table_child_relationship,
         							delete_PKs 	=> [ $PK_ids_to_delete ],
         							delete_batch 	=> 10000,
         							database 	=> $DATABASE,
         							verbose 	=> $VERBOSE,
         							testonly 	=> $TESTONLY,
  							);
  			}
  		}		
  	}		
  }elsif($DELETE_ALL){
  	
  	QUESTION:{
  	print "********* ARE YOU SURE YOU WANT TO DELETE ALL ARRAYS AND SAMPLES ???? *************\n";
  	
  	my $answer = <STDIN>;
  	if ($answer =~ /^[nN]/){
  		print "OK I WILL NOT DELETE ANYTHING\n";
  	}elsif($answer =~ /^[Yy]/) {
  		print "OK I WILL DELETE ALL ARRAY AND SAMPLES IN 5 secs... LAST CHANCE push crtl-c TO ABORT....\n";
  		sleep 5;
  	
  		my @all_names_to_delete = $sbeams_affy_groups->get_all_affy_file_root_names();  #pull all the names from affy_arrays and reset to global $DELETE_BOTH to the names
  												#method returns zero if nothing to return
  		die "Nothing to delete\n" if !$all_names_to_delete[0];			
  		
  		$DELETE_BOTH = join "\n\t\t\t", @all_names_to_delete;
  		print "NAMES TO DELETE\t $DELETE_BOTH\n";
  		
  		
  		delete_affy_data();								#re-run the delete_sub with the new parameters															
  	
  	}else{
  		print "Sorry I do not understand your answer, Type Y or N\n";
  		QUESTION:redo;
  	}
  	}
  
  
  	
  
  
  }
  	
}

###############################################################################
# check_setters	
#
# Check to see if a method exists in the Affy object
###############################################################################

sub check_setters{
  my $SUB_NAME = 'check_setters';
  my $command_line_method = shift;
  
  my @methods = split /,/, $command_line_method;		#methods could be a comma delimited list
  
  	
  foreach my $method ( @methods) {
  
  	if ($method =~ /protocol_id$/){				#not currently setup to just update the linking table only.  Need to update the affy_array or sample tables protocl ids first which will automatically update the linking tables
  		print  "*** The update section cannot update the linking table only, please run a method ending with protocol_ids ***\n\n";
  	
  	
  	}elsif(exists $main::SBEAMS::Microarray::Affy::{$method} ){	#Check in the affy package for all the setters
  		if ($VERBOSE >0){
  		
  			print "METHOD LOOKS GOOD '$method'\n";
  		}
  		
  		
  		next;
  	}
  	
  	print "*** This is not a method I recognize '$method' ***\n";
  	print "*** Here are the known methods ***\n";
  
  	foreach my $key (sort keys %main::SBEAMS::Microarray::Affy::){ #loop through the package symbol tables for the Affy.pm module and print all the set(ter) methods
  		if ($key =~ /^set/){
  			next if ($key =~ /protocol_id$/);		#skip the protocol_id methods which would try and update the linking table which is not good
  			print "$key\n";
  		}
  	}
  	die $USAGE;
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
  
  
  open ERROR_LOG, ">../../../tmp/Microarray/AFFY_ERROR_LOG.txt" or 
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
##############################################################################
# parse_info_file	
#
# Parse the info file usually associated with external arrays.
###############################################################################
  
sub parse_info_file{

  my %args = @_;
  my $info_file = $args{file};
  my $sbeams_affy = $args{object};
  my $root_file = $args{root_file};
  
  
  
  my $sbeams_affy_groups = $args{'affy_group_obj'};
  my $sample_tag = $args{'sample_tag'};
  
  
  open INFO, "$info_file" ||
  	die "Cannot open info file '$info_file'\n";
  my %info_data = ();
  while (<INFO>){
  	s/\s$//g;		#remove any white space at the end of the line
  	my($header, $val) = split /=>/, $_;
  	$info_data{$header} = $val;
  }
  #Hash keys <Table_abbreviation _ column name> which should also match the method names in Affy.pm
  	
  					
  %data_to_find = ( 	AFS_PROJECT_ID =>  {		HEADER	=> 'Project Name',
  				   	 		VAL	=> '',
  					 		SORT	=> 1,
  					 		SQL_METHOD =>'$sbeams_affy->find_project_id(project_name=>$val, do_not_die => 1)',
  					 		FILE_VAL_REQUIRED => 'YES',
  					 	},
  
  			AFA_USER_ID    => 	{	HEADER  => 'Username',
  					 		SORT	=> 2,
  					 		VAL	=> '',
  					 		SQL_METHOD => '$sbeams_affy->find_user_login_id(username=>$val)',
  					 		FILE_VAL_REQUIRED => 'YES',
  					 		},
  			
  			AFS_ORGANISM_ID  =>	{	HEADER  => 'organism_common_name',
  					 		VAL	=> '',
  					 		SORT	=> 3,
  					 		SQL_METHOD => '$sbeams_affy->find_organism_id(organism_name=>$val)',
  					 		FILE_VAL_REQUIRED => 'YES',
  						},
  			
  			AFA_ARRAY_TYPE_ID =>    {  	HEADER  => 'Array Type',
  					 		VAL	=> '',
  					 		SORT	=> 4,
  					 		SQL_METHOD => '$sbeams_affy->find_slide_type_id(slide_name=>$val)',
  					 		FILE_VAL_REQUIRED => 'YES',
  						  },
  			
  			
  			
  			
  			AFS_SAMPLE_TAG    =>{	HEADER  => 'sample_tag',
  					          	VAL	=> '',
  					          	SORT	=> 5,
  					 			FILE_VAL_REQUIRED => 'YES',
  					           },	  
  			AFS_SAMPLE_GROUP_NAME    =>{	HEADER  => 'sample_group_name',
  					          	VAL	=> '',
  					          	SORT	=> 6,
  					 			FILE_VAL_REQUIRED => 'YES',
  					           },
  			#
  			AFS_SAMPLE_PREPARATION_DATE   =>{	HEADER  => 'sample_preparation_date',
  					          	VAL	=> '',
  					          	SORT	=> 31,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_FULL_SAMPLE_NAME    =>{	HEADER  => 'full_sample_name',
  					          	VAL	=> '',
  					          	SORT	=> 7,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			#DEFAULT TO THE USER_id ORGANIZATION ID
  			#AFS_SAMPLE_PROVIDER_ORGANIZATION    =>{	HEADER  => 'sample_sample_provider_organization',
  			#		          	VAL	=> '',
  			#		          	SORT	=> 8,
  			#		 			FILE_VAL_REQUIRED => 'NO',
  			#		 			SQL_METHOD => 'get_organization_id(user_login_id => $data_to_find{AFA_USER_ID}{VAL})'
  			#		           },
  			AFS_STRAIN_OR_LINE    =>{	HEADER  => 'strain_or_line',
  					          	VAL	=> '',
  					          	SORT	=> 9,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_INDIVIDUAL    =>{	HEADER  => 'individual',
  					          	VAL	=> '',
  					          	SORT	=> 10,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_SEX_ONTOLOGY_TERM_ID    =>{	HEADER  => 'SEX',
  					          	VAL	=> '',
  					          	SORT	=> 11,
  					 			FILE_VAL_REQUIRED => 'NO',
  					            SQL_METHOD => '$sbeams_affy->find_ontology_id(ontology_term => $val, do_not_die =>1 )',
  					           },
  			AFS_AGE    =>{	HEADER  => 'AGE',
  					          	VAL	=> '',
  					          	SORT	=> 11,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_ORGANISM_PART    =>{	HEADER  => 'organism_part',
  					          	VAL	=> '',
  					          	SORT	=> 12,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_CELL_LINE    =>{	HEADER  => 'cell_line',
  					          	VAL	=> '',
  					          	SORT	=> 13,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_CELL_TYPE    =>{	HEADER  => 'cell_type',
  					          	VAL	=> '',
  					          	SORT	=> 14,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_DISEASE_STATE    =>{	HEADER  => 'disease_state',
  					          	VAL	=> '',
  					          	SORT	=> 15,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_RNA_TEMPLATE_MASS    =>{	HEADER  => 'rna_template_mass',
  					          	VAL	=> '',
  					          	SORT	=> 16,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_PROTOCOL_DEVIATIONS    =>{	HEADER  => 'sample_protocol_deviations',
  					          	VAL	=> '',
  					          	SORT	=> 17,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_SAMPLE_DESCRIPTION    =>{	HEADER  => 'sample_description',
  					          	VAL	=> '',
  					          	SORT	=> 18,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_TREATMENT_DESCRIPTION    =>{	HEADER  => 'sample_treatment_description',
  					          	VAL	=> '',
  					          	SORT	=> 19,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFS_COMMENT    =>{	HEADER  => 'sample_comment',
  					          	VAL	=> '',
  					          	SORT	=> 20,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },
  			AFA_COMMENT    =>{	HEADER  => 'array_comment',
  					          	VAL	=> '',
  					          	SORT	=> 21,
  					 			FILE_VAL_REQUIRED => 'NO',
  					           },		           		           		           		           		           		           
  					          		           		           		           		           		           		           		           		           		           
  			
  		
  		#### End of protocol section ###
  			AFS_AFFY_ARRAY_SAMPLE_ID  =>{	VAL 	 => $sample_tag,		#bit of a hack, will query on the sample_tag and project_id which must be unique
  					  		SORT	 =>  100,			#really want this to go last since it will insert the affy_array_sample if it cannot find the Sample tag in the database.  And it needs some information collected by some of the other hash elements before it does so.	
  					  		SQL	 => "	SELECT affy_array_sample_id
  					 				FROM $TBMA_AFFY_ARRAY_SAMPLE
  									WHERE sample_tag like 'HOOK_VAL'",
  					
  					  		CONSTRAINT => '"AND project_id = " . $data_to_find{AFS_PROJECT_ID}{VAL}',
  					 	     },
  		);
  		
  		
#############################################################################################################################
#loop through the data_to_find keys pulling data from the INFO files and converting the human readable names to id within the database
  foreach my $data_key (sort {$data_to_find{$a}{'SORT'} 		
  				<=> 
  			$data_to_find{$b}{'SORT'} }keys %data_to_find
  	         ) 
  		 {							#start foreach loop
  	
  
  my $val = '';
  
##########################################################################################
##Pull the value from the info file
  	if (my $header = $data_to_find{$data_key}{HEADER}){		
  		
  		if ($VERBOSE > 0) {
  			print "FIND DATA FOR HEADER '$header'\n";
  		}
  		
  		$val = $info_data{$header};		
  	}else{
  		$val = $data_to_find{$data_key}{VAL};			#use the default VAL from the data_to_find hash if No XPATH statement
  	}
  	
  	
  	if ( $data_to_find{$data_key}{FILE_VAL_REQUIRED} && 
                      $data_to_find{$data_key}{FILE_VAL_REQUIRED} eq 'YES' &! $val) {
  		$sbeams_affy_groups->group_error(root_file_name => $root_file,
  						 error => "CANNOT FIND VAL FOR '$data_key' EITHER FROM THE INFO".
  							 "FILE OR DEFAULT, THIS IS NOT GOOD.  Please EDIT THE FILE AND TRY AGAIN",
  						);
  		next;
  	}
  	
  			
  		
  	if ($VERBOSE > 0){
  		print "$data_key => '$val'\n";
  	}
##########################################################################################			
###if the data $val needs to be converted to a id value from the database run the little sql statement to do so				
  	my $id_val = '';	
  	
  	if ($data_to_find{$data_key}{SQL} || $data_to_find{$data_key}{SQL_METHOD}) {			
  	
  	 	$id_val = convert_val_to_id( 	value    => $val,
  				   			sql    	 => $data_to_find{$data_key}{SQL},
  				   	      	sql_method => $data_to_find{$data_key}{SQL_METHOD},
  				   	      	data_key => $data_key,
  					     	affy_obj => $sbeams_affy,
  					     );
  	}elsif($data_to_find{$data_key}{FORMAT}){
  			
  		$id_val = format_val	( value    => $val,
  				   	  transform=> $data_to_find{$data_key}{FORMAT},
  				   	);
  	}else{
  		$id_val = $val;					#if the val from the INFO FILE does not need to be convert or formatted give it back
  	}
  
  
  
  
  #store the results of the conversion (if needed) no matter what the results are			
  	$data_to_find{$data_key}{VAL} = $id_val;		
##########################################################################################
#collected errors in the all_files_h and print them to the log file			
  	if  ( defined $id_val && $id_val =~ /ERROR/) {				
  		$sbeams_affy_groups->group_error(root_file_name => $root_file,
  						 error => "$id_val",
  						);
  		print "$id_val\n";
  			
  			
  		if ($data_key eq 'AFS_PROJECT_ID') {			#TESTING 
  			
  			push @BAD_PROJECTS, ($info_file, "\t$val\n");
  		}
  			
  		return;						#if error converting the data to an id do not bother looking at the rest of the data move on to the next group of files
  			
  	}else{
  		
  		set_data(value  => $id_val,			#collect the 'Good' data in Affy objects
  			 key    => $data_key,
  			 object => $sbeams_affy,
  		         );
  	}
  }
}
