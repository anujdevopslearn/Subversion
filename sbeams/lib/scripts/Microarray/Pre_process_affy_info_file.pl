#!/usr/local/bin/perl -w

###############################################################################
# Program     : Pre_process_affy_info_file.pl
# Author      : Pat Moss <pmoss@systemsbiology.org>
#
# Description : Small script to take a tab delimited file containing information to annotate 
#arrays and samples for a bunch of CEL file to be loaded and make an indivuial INFO file for each CEL file. 
# In addition this script will be able add a prefix to a CEL file to
#make sure it conforms to the ISB affy array naming convention
#
#
###############################################################################
###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use File::Basename;
use File::Copy;
use Data::Dumper;

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
			 $RUN_MODE
             $INFO_FILE
			 $BASE_DIRECTORY
	    	 %HOLD_COVERSION_VALS
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

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;

my @run_modes = qw(make_new update );

$USAGE = <<EOU;
$PROG_NAME is make info files from a master info file and re-name cel files if needed. 

Give a path to the file to be processed. File MUST be within the folder containg all the CEL files to process

Usage: $PROG_NAME --run_mode <make_new>  --info_file <pathtofile> [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
     	  
    

Run Mode Notes:
 make_new : will read the file and make an info file for each CEL file in the master info file
 update : Re-read the master file and make all the info files
 	  Removes all the samples and array information
Examples;
1) ./$PROG_NAME --run_mode make_new --info_file give/path_to_file/info.txt	# typical mode, to make baby info files and make new CEL file names
2) ./$PROG_NAME --run_mode update --info_file give/path_to_file/info.txt	#re-make all the info files
EOU

		
		
#### Process options
unless (GetOptions(\%OPTIONS,
		   "run_mode:s",
		   "verbose:i",
		   "quiet",
		   "debug:i",
		   "method:s",
		   "info_file:s",
		   
		   )) {
  print "$USAGE";
  exit;
}



$VERBOSE    = $OPTIONS{verbose} || 0;
$QUIET      = $OPTIONS{quiet};
$DEBUG      = $OPTIONS{debug};
$TESTONLY   = $OPTIONS{testonly};
$RUN_MODE   = $OPTIONS{run_mode};
$INFO_FILE = $OPTIONS{info_file};

my $val = grep {$RUN_MODE eq $_} @run_modes;

die "*** RUN_MODE DOES NOT LOOK GOOD '$RUN_MODE' ***\n $USAGE" unless ($val);

$BASE_DIRECTORY = dirname($INFO_FILE);
die "INFO file '$INFO_FILE' Cannot be found" unless (-e $INFO_FILE);
############################


if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  RUN_MODE = $RUN_MODE\n";
  print "  BASE_DIR = $BASE_DIRECTORY\n";
 

}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
%HOLD_COVERSION_VALS = ();
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


	if ( $RUN_MODE eq 'make_new' || $RUN_MODE eq 'update' ) {
		my $master_href = read_master_info_file();		#extract useful bits of information
		
		
		rename_cel_files(master_href =>$master_href,
						 run_mode => $RUN_MODE,
						 );
		
		make_info_files(master_href =>$master_href);		#add all the data to the database
	
	}else{
		print "Sorry but '$RUN_MODE' is not a known run_mode, please try again\n";
	}
	
}

###############################################################################
# read_master_info_file
#
# Read a tab delimited file containing all the annotation that a user could possibly want to upload
###############################################################################
sub read_master_info_file {
	open DATA, "$INFO_FILE" ||
		die "Cannot open MASTER info file '$INFO_FILE'\n";
	my @column_names = ();
	my $count = 0;
	my %master_info = ();
	while (<DATA>){
		s/\s+$//g;	#remove any white space at the end of a line
		next if (/^#/); #skip lines that begin with a pound
		if (/File Prefix/){	#capture the header line info
			@column_names  = split /\t/,$_;
			$count ++;
			next;
		}
		my @hold = split /\t/, $_;
		my %hold_hash = ();
		for (my $i=0; $i <= $#column_names ; $i++){
			$master_info{$count}{$column_names[$i]} = $hold[$i];
		}
		check_for_minimal_amount_of_data(record=>$master_info{$count});
		$count++;
	}
	close DATA;
	#Debug stuff
	#print Dumper(%master_info);
	#foreach my $key_count( sort {$a<=>$b} keys %master_info ){
	#	foreach my $header (keys %{$master_info{$key_count}} ){
	#		print "$key_count => $header => $master_info{$key_count}{$header}\n";
	#	}
	#}
	
	return \%master_info;
}		
###############################################################################
# rename_cel_files
#
# Rename the CEL file to conform to the Institutes file name format 
#currently the format is like 20040707_05_PAM2B-80 (YYYYMMDD_01_SAMPLE_TAG) 
#01 is the number of scans for that day
###############################################################################
sub rename_cel_files {
	my %args = @_;
	my $master_href = $args{master_href};
	
	foreach my $key_numb ( sort {$a<=>$b} keys %{$master_href}){
		my $prefix 				= $master_href->{$key_numb}->{'File Prefix'};
		my $orginal_file_name 	= $master_href->{$key_numb}->{'CEL FILE NAME'};
		next unless ($orginal_file_name);
		my $new_file_name = "${prefix}_$orginal_file_name";
		if ($RUN_MODE eq 'make_new'){	
			print "ORGINAL NAME '$orginal_file_name' NEW '$new_file_name'\n";
			if ($orginal_file_name && -e "$BASE_DIRECTORY/$orginal_file_name"){
				print "ORGINAL NAME '$orginal_file_name' NEW '$new_file_name'\n";
				move("$BASE_DIRECTORY/$orginal_file_name", "$BASE_DIRECTORY/$new_file_name") or
					die "Cannot Move file '$BASE_DIRECTORY/$orginal_file_name'\n";
			
				print "'MOVE $BASE_DIRECTORY/$orginal_file_name', '$BASE_DIRECTORY/$new_file_name' \n";
			}
		}
		#Reset the CEL FILE NAME to utilize the prefix name
		$master_href->{$key_numb}->{'CEL FILE NAME'} = $new_file_name;
		
	}
	#print Dumper($master_href);
}
###############################################################################
# make_info_files
#
# Take the info from the master info file and make a file for each row
###############################################################################
sub make_info_files {
	my %args = @_;
	my $master_href = $args{master_href};
	
	foreach my $key_numb ( sort {$a<=>$b} keys %{$master_href}){
		
		my $file_name 	= $master_href->{$key_numb}->{'CEL FILE NAME'};
		
		my ($file, $dir, $ext) = fileparse("$BASE_DIRECTORY/$file_name",  qr/\..*/);
		
		print "FILE '$file' FILE NAME '$file_name'\n" if ($VERBOSE > 0); 
		
		my $out_file = "$BASE_DIRECTORY/$file.INFO";
		next unless ($file =~ /^\w/);
		
		open OUT , ">$out_file" ||
			die "Cannot open OUT file '$out_file'\n";
		
		print "$key_numb MAKE INFO FILE '$out_file'\n";
		
		foreach my $header (sort keys %{$master_href->{$key_numb}} ){
			next if $header eq 'File Prefix';				  #Do not out put this name to baby info files
			next unless $master_href->{$key_numb}->{$header}; #make sure there is some data
			print OUT "$header=>$master_href->{$key_numb}->{$header}\n";
		}
	}
}
###############################################################################
# check_for_minimal_amount_of_data
#
# Perform some sanity checks on the data to make sure it will at least hava a chance of 
#uploading
###############################################################################
sub check_for_minimal_amount_of_data {
	my %args = @_;
	my $record_href = $args{record};
	#print Dumper($record_href);
	
	#Check to make sure the file name contains no strange characters
	if($record_href->{'CEL FILE NAME'} =~ /([^a-zA-Z0-9._-])/g){
	   die "FILE NAMES CANNOT CONTAIN '$1' CHARACTERS in FILE NAME '$record_href->{'CEL FILE NAME'}'\n";
	}
	
	#check for the array_type
	my $array_type_header = 'Array Type';
	if ($record_href->{$array_type_header}){
		unless ($sbeams_affy->find_slide_type_id(slide_name => $record_href->{$array_type_header}) ){
			throw_error(column_name=>$array_type_header,
						record	   =>$record_href,
						error_report=>"Could not find $array_type_header for '$record_href->{$array_type_header}'",
					  );
		}
	}
	
	#check the project name
	my $project_header = 'Project Name';
	if ($record_href->{$project_header}){
		unless ($sbeams_affy->find_project_id(project_name => $record_href->{$project_header}) ){
		
			throw_error(column_name=>$project_header,
						record	   =>$record_href,
						error_report=>"Could not find $project_header for '". $record_href->{$project_header} ."'",
					  );
		}
	}
	
	#check the user name
	my $username_header = 'Username';
	if ($record_href->{$username_header}){
		unless ($sbeams_affy->find_user_login_id(username => $record_href->{$username_header}) ){
		
			throw_error(column_name=>$username_header,
						record	   =>$record_href,
						error_report=>"Could not $username_header for '". $record_href->{$username_header} ."'",
					  );
		}
	}
	
	#check the ogranism name
	my $organism_header = 'organism-common_name';
	if ($record_href->{$organism_header}){
		unless ($sbeams_affy->find_organism_id(organism_name => $record_href->{$organism_header}) ){
		
			throw_error(column_name=>$organism_header,
						record	   =>$record_href,
						error_report=>"Could not find $organism_header for '". $record_href->{$organism_header} ."'",
					  );
		}
	}
	
	

	
}
###############################################################################
# check_for_to_see_if_query_has_been_ran
#
# Before running a query make see if we have already run the query
###############################################################################
sub check_for_to_see_if_query_has_been_ran {
	my %args = @_;
	my $column_name = $args{column_name};
	my $data_val = $args{column_name};
	
	 
	if (exists $HOLD_COVERSION_VALS{$column_name}) {			#if the value has been used before in a query and it returned an id just reuse the previous id instead of requiring 
		if ($VERBOSE > 0){
			print "VAL '$data_val' for '$column_name' HAS BEEN SEEN BEFORE RETURNING",
			 " DATA '$HOLD_COVERSION_VALS{$column_name}' FROM CONVERSION VAL HASH\n";	
		}
		return $HOLD_COVERSION_VALS{$column_name};
	}else{
		return 0;
	}
	
}

###############################################################################
# throw_error
#
# print a nice looking error message
###############################################################################
sub throw_error {

	my %args = @_;
	
	my $column_name = $args{column_name};
	my $record_href 	= $args{record};
	my $error_msg 	= $args{error_report};

	print "ERROR: DATA FOR '" . $record_href->{'CEL FILE NAME'}.
	      " COLUMN '$column_name'\n$error_msg\n";
	      
	
}
