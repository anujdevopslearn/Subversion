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
use SBEAMS::Connection::Settings qw(:default $LOG_BASE_DIR);
use SBEAMS::Connection::Log;


#### Set up new variables
use vars qw(@ISA @EXPORT 
            $SBEAMS_PART
            $AFFY_DEFAULT_DIR
            @AFFY_DEFAULT_FILES
            %CUSTOM_CDF
            %CDF_DBS
            $AFFY_NORMALIZATION_PIPELINES
            %CDF_VERSIONS
            $AFFY_ZIP_REQUEST_DIR
            $AFFY_R_CHP_ANALYSIS_PROTOCOL
            $BIOCONDUCTOR_DELIVERY_PATH
            $ADD_ANNOTATION_OUT_FOLDER
            $AFFY_TMP_DIR
            $AFFY_LOG_DIR
);

my $log = SBEAMS::Connection::Log->new();

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $SBEAMS_PART 
    $AFFY_TMP_DIR
);

my $affy_file_types = $CONFIG_SETTING{MA_AFFY_DEFAULT_FILES} || '';
@AFFY_DEFAULT_FILES = split ( /\s/, $affy_file_types);


# Convert any relative paths to absolute paths
for my $k qw(MA_LOG_BASE_DIR MA_AFFY_PROBE_DIR MA_BIOC_DELIVERY_PATH
             MA_ANNOTATION_OUT_PATH MA_AFFY_TMP_DIR MA_AFFY_ZIP_REQUEST_DIR
             MA_AFFY_ANNOTATION_PATH ) {
  next unless defined $CONFIG_SETTING{$k};
  if ( $CONFIG_SETTING{$k} !~ /^\// ) {
    my $delim = ($PHYSICAL_BASE_DIR =~ /\/$/) ? '' : '/';
    $CONFIG_SETTING{$k} = $PHYSICAL_BASE_DIR . $delim . $CONFIG_SETTING{$k};
  }
}


#Edit Location to suit installation requirements
$AFFY_LOG_DIR               = $CONFIG_SETTING{MA_LOG_BASE_DIR} || '';
$AFFY_DEFAULT_DIR           = $CONFIG_SETTING{MA_AFFY_PROBE_DIR} || '';
$BIOCONDUCTOR_DELIVERY_PATH = $CONFIG_SETTING{MA_BIOC_DELIVERY_PATH} || '';
$ADD_ANNOTATION_OUT_FOLDER  = $CONFIG_SETTING{MA_ANNOTATION_OUT_PATH} || '';
$AFFY_TMP_DIR               = $CONFIG_SETTING{MA_AFFY_TMP_DIR} || '';
$AFFY_ZIP_REQUEST_DIR       = $CONFIG_SETTING{MA_AFFY_ZIP_REQUEST_DIR} || '';


#Current protocol that describes the R script to produce the CHP like file
$AFFY_R_CHP_ANALYSIS_PROTOCOL = $CONFIG_SETTING{MA_AFFY_R_CHP_PROTOCOL} || '';


#### Override variables from main Settings.pm
$SBEAMS_SUBDIR          = 'Microarray';
$SBEAMS_PART            = 'Microarray';

#### Process custom CDF options -
$AFFY_NORMALIZATION_PIPELINES = $CONFIG_SETTING{MA_NORMALIZATION_PIPELINES} || '';
# Supported CHIP types
my $custom_cdf_types = $CONFIG_SETTING{MA_CUSTOM_CDF} || '';
my @cdf_types = split ( /,\s*/, $custom_cdf_types);
for my $type ( @cdf_types ) {
  my ( $k, $v ) = split /:/, $type;
  next unless $k && $v;
  $CUSTOM_CDF{$k} = $v;
}
# installed DB mappings
my $cdf_dbs = $CONFIG_SETTING{MA_CDF_DBS} || '';
my @db_order; # convenience, allow order to be preserved
my @dbs = split ( /,\s*/, $cdf_dbs);
for my $db ( @dbs ) {
  my ( $k, $v ) = split /:/, $db;
  next unless $k && $v;
  push @db_order, $k;
  $CDF_DBS{$k} = $v;
}
# DB mapping versions
my @version_order; # convenience, allow order to be preserved
my $cdf_vers = $CONFIG_SETTING{MA_CDF_VERSIONS} || '';
my @vers = split ( /,\s*/, $cdf_vers);
for my $ver ( @vers ) {
  my ( $k, $v ) = split /:/, $ver;
  next unless $k && $v;
  push @version_order, $k;
  $CDF_VERSIONS{$k} = $v;
}

##############################
### Methods to access data ###
##############################

#+
# get_affy_log_dir
#
#-
sub get_affy_log_dir {
  my $self = shift;

  my $dir = ( $AFFY_LOG_DIR ) ? $AFFY_LOG_DIR :
            ( $LOG_BASE_DIR ) ? $LOG_BASE_DIR :  "$PHYSICAL_BASE_DIR/var/logs";

  if ( !$dir ) {
    $log->warn( 'No logging dir configured' );
  } elsif ( !-e $log ) {
    $log->warn( "Logging dir, $log, does not exist" );
  }

  return $dir;
}

#+
# get_R_exe_path
#
# returns configured path to R executable
#-
sub get_R_exe_path {
  my $self = shift;

  my $rpath = $CONFIG_SETTING{MA_R_EXE_PATH} || '';

  if ( !$rpath ) {
    $log->warn( 'No path to R specified' );
  }

  return $rpath;
}

#+
# get_R_lib_path
#
# returns configured path to R libraries
#-
sub get_R_lib_path {
  my $self = shift;

  my $rlib = $CONFIG_SETTING{MA_R_LIB_PATH} || '';

  if ( !$rlib ) {
    $log->warn( 'No path to R library specified' );
  }

  return $rlib;
}

#+
# get_admin_email
#
# returns configured path to admin_email
#-
sub get_admin_email {
  my $self = shift;

  my $rlib = $CONFIG_SETTING{MA_ADMIN_EMAIL} || '';
  ( $rlib ) = $DBADMIN  =~ /(\w+\@\w+\.\w+)/ unless ( $rlib );

  if ( !$rlib ) {
    $log->warn( 'No Admin email configured! ' );
  }

  return $rlib;
}

#+
# get_batch_system
#
# returns configured batch system, one of fork, sge, pbs
#-
sub get_batch_system {

  return $CONFIG_SETTING{MA_BATCH_SYSTEM} || 'fork';

}

#######################################################
# get_affy_temp_dir_path
# get the path to the top level temp directory
#######################################################
sub get_affy_temp_dir_path {
	my $self = shift;
   
    	return $AFFY_TMP_DIR;
}

#######################################################
# affy_bioconductor_delivery_path
# get the path to the bioconductory delivery folder
#######################################################
sub affy_bioconductor_delivery_path {
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

#+
# return config value for gene pattern URI if any
#-
sub get_gp_URI {
  return $CONFIG_SETTING{MA_GENE_PATTERN_URI} || '';
}

#+
# should button for exon array pipeline be shown?
#-
sub show_exon_pipeline {
  my $self = shift;
  my $uri = $self->get_gp_URI();
  unless ( $uri ) {
    # short circuit if URI not defined
    $log->warn( "Missing GP URI" ) if $AFFY_NORMALIZATION_PIPELINES;
    return '';
  }
  return ( $AFFY_NORMALIZATION_PIPELINES =~ /Exon/i );
}

#+
# should button for expression array pipeline be shown?
#-
sub show_expression_pipeline {
  my $self = shift;
  my $uri = $self->get_gp_URI();
  unless ( $uri ) {
    # short circuit if URI not defined
    $log->warn( "Missing GP URI" ) if $AFFY_NORMALIZATION_PIPELINES;
    return '';
  }
  return ( $AFFY_NORMALIZATION_PIPELINES =~ /Expression/i );
}

#+
# return hashref of installed custom CDF files 
#-
sub get_custom_cdf_types {
  return \%CUSTOM_CDF;
}

#+
# 
# return hashref of custom CDF dbs 
#-
sub get_cdf_dbs {
  return \%CDF_DBS;
}

#+
# array ref with ordered db keys
#-
sub get_cdf_db_order {
  return \@db_order;
}

#+
# return hashref of custom CDF version 
#-
sub get_cdf_versions {
  return \%CDF_VERSIONS;
}

#+
# array ref with ordered version keys
#-
sub get_cdf_version_order {
  return \@version_order;
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

#+
# Utility method to return path to affy annotation files.
#-
sub get_affy_annotation_path {
  my $apath = $CONFIG_SETTING{MA_AFFY_ANNOTATION_PATH} || '';
  # Trim trailing spaces
  $apath =~ s/\s+$//g;
  return $apath || "$PHYSICAL_BASE_DIR/var/Microarray/Affy_data/annotation";
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

