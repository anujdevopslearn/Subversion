package SBEAMS::Microarray::Settings;

###############################################################################
# Program     : SBEAMS::Microarray::Settings
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Microarray module which handles
#               setting location-dependant variables.
#
###############################################################################


use strict;

#### Begin with the main Settings.pm
use SBEAMS::Connection::Settings;


#### Set up new variables
use vars qw(@ISA @EXPORT 
    $SBEAMS_PART
    $AFFY_DEFAULT_DIR
    @AFFY_DEFAULT_FILES
    $AFFY_ZIP_REQUEST_DIR
    $AFFY_R_CHP_ANALYSIS_PROTOCOL
	$BIOCONDUCTOR_DELIVERY_PATH
	$ADD_ANNOTATION_OUT_FOLDER
);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $SBEAMS_PART 
);


#### Define new variables
$SBEAMS_PART            = 'MicroArray';
$AFFY_DEFAULT_DIR	= '/net/arrays/Affymetrix/core/probe_data';
@AFFY_DEFAULT_FILES	= qw(CHP CEL XML RPT R_CHP JPEG EGRAM_PF.jpg EGRAM_T.jpg EGRAM_F.jpg);		#files that will be used to determine if a group of files, all sharing the same basename, are all present when uploading Affy arrays 

$AFFY_ZIP_REQUEST_DIR 	= '/net/arrays/Affy_Zip_Request';

$AFFY_R_CHP_ANALYSIS_PROTOCOL = 'R Mas5.0 CHP';				#Current protocol that describes the R script to produce the CHP like file

$BIOCONDUCTOR_DELIVERY_PATH = '/net/arrays/Affymetrix/core/data_analysis/delivery';#/net/dblocal/www/html/devPM/sbeams/bioconductor/delivery
$ADD_ANNOTATION_OUT_FOLDER = "$PHYSICAL_BASE_DIR/tmp/Microarray/Add_affy_annotation";
#### Override variables from main Settings.pm
$SBEAMS_SUBDIR          = 'Microarray';



### Methods to access data

#######################################################
# affy_bioconductor_devlivery_path
# get the path to the bioconductory delivery folder
#######################################################
sub affy_bioconductor_devlivery_path {
	my $self = shift;
   
    	return $BIOCONDUCTOR_DELIVERY_PATH;
}



#######################################################
# get_affy_r_chp_protocol
# get the default affy files extensions need for uploading a complete set of files
#######################################################
sub get_affy_r_chp_protocol {
	my $either = shift;
    
    	my $class = ref($either) || $either;		#class level method no need to get the class name
    	return $AFFY_R_CHP_ANALYSIS_PROTOCOL;
}

#######################################################
# get_AFFY_FILES
# get the default affy files extensions need for uploading a complete set of files
#######################################################
sub get_AFFY_FILES {
				    
    my $either = shift;
    
    my $class = ref($either) || $either;		#class level method no need to get the class name
    return @AFFY_DEFAULT_FILES;
    
}


#######################################################
# set_AFFY_FILES
# Set the default affy files extensions need for uploading a complete set of files.
# Use the default files listed in the define new variables section above if no files are given
# Return the new value(s) set in the @AFFY_DEFAULT_FILES
#######################################################
sub set_AFFY_FILES {
	
	my $either = shift;
	my $files_aref = shift;
	
	 my $class = ref($either) || $either;
	 
	 if ($$files_aref[0] =~ /^\.\w/){
	 	
		@AFFY_DEFAULT_FILES = @{$files_aref};
		print "SET AFFY FILES '@AFFY_DEFAULT_FILES'\n"; 
	}
	return @AFFY_DEFAULT_FILES;
}
	

#######################################################
# get_AFFY_DEFAULT_DIR
# get the default affy data directory 
#######################################################
sub get_AFFY_DEFAULT_DIR {
    my $either = shift;
    
    my $class = ref($either) || $either;
    return $AFFY_DEFAULT_DIR;
    
}

#######################################################
# set_AFFY_DEFAULT_DIR
# Set the path to the affy data dir otherwise use the default listed above in the define new variables section
# Return the value set for $AFFY_DEFAULT_DIR
#######################################################
sub set_AFFY_DEFAULT_DIR {
	
	my $either = shift;
	my $file_path = shift;
	
	 my $class = ref($either) || $either;
	 
	 if (-e $file_path){
	 	
		$AFFY_DEFAULT_DIR = $file_path;
		print "SET AFFY DATA DIR '$AFFY_DEFAULT_DIR'\n"; 
	}
	
	return $AFFY_DEFAULT_DIR;
}

#######################################################
# ZIP_REQUEST_DIR
# get the default to read and write requests to  
#######################################################
sub get_ZIP_REQUEST_DIR {
    my $either = shift;
    
    my $class = ref($either) || $either;
    return $AFFY_ZIP_REQUEST_DIR;
    
}

#######################################################
# set_ZIP_REQUEST_DIR
# Set the path to the affy zip request otherwise use the default listed above in the define new variables section
# Return the value set for $AFFY_DEFAULT_DIR
#######################################################
sub set_ZIP_REQUEST_DIR {
	
	my $either = shift;
	my $file_path = shift;
	
	 my $class = ref($either) || $either;
	 
	 if (-e $file_path){
	 	
		$AFFY_DEFAULT_DIR = $file_path;
		print "SET AFFY ZIP DIR '$AFFY_ZIP_REQUEST_DIR'\n"; 
	}
	
	return $AFFY_ZIP_REQUEST_DIR;
}

#######################################################
# get_ANNOTATION_OUT_FOLDER
# get the default folder to hold files generated by the Add_affy_annotation script
#######################################################
sub get_ANNOTATION_OUT_FOLDER {
    my $either = shift;
    
    my $class = ref($either) || $either;
    return $ADD_ANNOTATION_OUT_FOLDER;
    
}
1;

