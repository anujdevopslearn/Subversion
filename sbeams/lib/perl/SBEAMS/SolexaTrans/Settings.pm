package SBEAMS::SolexaTrans::Settings;

###############################################################################
# Program     : SBEAMS::SolexaTrans::Settings
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: Settings.pm 4504 2006-03-07 23:49:03Z edeutsch $
#
# Description : This is part of the SBEAMS::SolexaTrans module which handles
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
	$SLIMSEQ_URI
	$SLIMSEQ_USER
	$SLIMSEQ_PASS
	$SOLEXA_DEFAULT_DIR
	@SOLEXA_DEFAULT_FILES
	$ST_LOG_BASE_DIR
	$ST_SOLEXA_ZIP_REQUEST_DIR
	$SOLEXA_LOG_DIR
	$SOLEXA_TMP_DIR
	$SOLEXA_ZIP_REQUEST_DIR
	$SOLEXA_DELIVERY_PATH
	$ADD_ANNOTATION_OUT_FOLDER
        $SOLEXA_MYSQL_HOST
        $SOLEXA_MYSQL_USER
        $SOLEXA_MYSQL_PASS
        $SOLEXA_MYSQL_DB
        $SOLEXA_BABEL_HOST
        $SOLEXA_BABEL_USER
        $SOLEXA_BABEL_PASS
        $SOLEXA_BABEL_DB
        $SOLEXA_EXPORT_FILE_FORMAT
);

my $log = SBEAMS::Connection::Log->new();

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $SBEAMS_PART
    $SOLEXA_TMP_DIR
    $SOLEXA_MYSQL_HOST
    $SOLEXA_MYSQL_USER
    $SOLEXA_MYSQL_PASS
    $SOLEXA_MYSQL_DB
    $SOLEXA_BABEL_HOST
    $SOLEXA_BABEL_USER
    $SOLEXA_BABEL_PASS
    $SOLEXA_BABEL_DB
    $SOLEXA_EXPORT_FILE_FORMAT
);

my $solexa_file_types = $CONFIG_SETTING{ST_SOLEXA_DEFAULT_FILES} || '';
@SOLEXA_DEFAULT_FILES = split ( /\s/, $solexa_file_types);

# Convert any relative paths to absolute paths
for my $k ( qw(ST_LOG_BASE_DIR SOLEXA_DELIVERY_PATH
             SOLEXA_TMP_DIR ST_SOLEXA_ZIP_REQUEST_DIR
             ) ) {
  next unless defined $CONFIG_SETTING{$k};
  if ( $CONFIG_SETTING{$k} !~ /^\// ) {
    my $delim = ($PHYSICAL_BASE_DIR =~ /\/$/) ? '' : '/';
    $CONFIG_SETTING{$k} = $PHYSICAL_BASE_DIR . $delim . $CONFIG_SETTING{$k};
  }
}

### Edit Location to suit installation requirements
$SOLEXA_LOG_DIR            = $CONFIG_SETTING{ST_LOG_BASE_DIR} || '';
$SLIMSEQ_URI               = $CONFIG_SETTING{ST_SLIMSEQ_URI} || '';
$SLIMSEQ_USER              = $CONFIG_SETTING{ST_SLIMSEQ_USER} || '';
$SLIMSEQ_PASS              = $CONFIG_SETTING{ST_SLIMSEQ_PASS} || '';
$SOLEXA_DEFAULT_DIR	   = $CONFIG_SETTING{ST_SOLEXA_RUN_DIR} || '';
$SOLEXA_TMP_DIR            = $CONFIG_SETTING{ST_SOLEXA_TMP_DIR} || '';
$SOLEXA_ZIP_REQUEST_DIR    = $CONFIG_SETTING{ST_SOLEXA_ZIP_REQUEST_DIR} || '';
$SOLEXA_DELIVERY_PATH      = $CONFIG_SETTING{ST_SOLEXA_DELIVERY_PATH} || '';
$ADD_ANNOTATION_OUT_FOLDER = $CONFIG_SETTING{ST_ANNOTATION_OUT_PATH} || '';
$SOLEXA_MYSQL_HOST         = $CONFIG_SETTING{ST_MYSQL_HOST} || '';
$SOLEXA_MYSQL_USER         = $CONFIG_SETTING{ST_MYSQL_USER} || '';
$SOLEXA_MYSQL_PASS         = $CONFIG_SETTING{ST_MYSQL_PASS} || '';
$SOLEXA_MYSQL_DB           = $CONFIG_SETTING{ST_MYSQL_DB} || '';
$SOLEXA_BABEL_HOST         = $CONFIG_SETTING{ST_BABEL_HOST} || '';
$SOLEXA_BABEL_USER         = $CONFIG_SETTING{ST_BABEL_USER} || '';
$SOLEXA_BABEL_PASS         = $CONFIG_SETTING{ST_BABEL_PASS} || '';
$SOLEXA_BABEL_DB           = $CONFIG_SETTING{ST_BABEL_DB} || '';

#### Define new variables
$SBEAMS_PART            = 'SolexaTrans';


#### Override variables from main Settings.pm
$SBEAMS_SUBDIR          = 'SolexaTrans';


##############################
### Methods to access data ###
##############################

#+
# get_solexa_log_dir
#
#-
sub get_solexa_log_dir {
  my $self = shift;

  my $dir = ( $SOLEXA_LOG_DIR ) ? $SOLEXA_LOG_DIR :
            ( $LOG_BASE_DIR ) ? $LOG_BASE_DIR :  "$PHYSICAL_BASE_DIR/var/logs";

  if ( !$dir ) {
    $log->warn( 'No logging dir configured' );
  } elsif ( !-e $log ) {
    $log->warn( "Logging dir, $log, does not exist" );
  }

  return $dir;
}

#######################################################
# get_solexa_temp_dir_path
# get the path to the top level temp directory
#######################################################
sub get_solexa_temp_dir_path {
        my $self = shift;

        return $SOLEXA_TMP_DIR;
}

#######################################################
# get_SOLEXA_DEFAULT_DIR
# get the default solexa data directory
#######################################################
sub get_SOLEXA_DEFAULT_DIR {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_DEFAULT_DIR;

}

#######################################################
# set_SOLEXA_DEFAULT_DIR
# Set the path to the solexa data dir otherwise use the default listed above in the define new variables section
# Return the value set for $SOLEXA_DEFAULT_DIR
#######################################################
sub set_SOLEXA_DEFAULT_DIR {
        my $either = shift;
        my $file_path = shift;

         my $class = ref($either) || $either;

         if (-e $file_path){

                $SOLEXA_DEFAULT_DIR = $file_path;
                print "SET SOLEXA DATA DIR '$SOLEXA_DEFAULT_DIR'\n";
        }

        return $SOLEXA_DEFAULT_DIR;
}


#######################################################
# get_SOLEXA_FILES
# get the default solexa files extensions need for uploading a complete set of files
#######################################################
sub get_SOLEXA_FILES {
    my $either = shift;

    my $class = ref($either) || $either;                #class level method no need to get the class name
    return @SOLEXA_DEFAULT_FILES;
}

#######################################################
# set_SOLEXA_FILES
# Set the default solexa files extensions need for uploading a complete set of files.
# Use the default files listed in the define new variables section above if no files are given
# Return the new value(s) set in the @SOLEXA_DEFAULT_FILES
#######################################################
sub set_SOLEXA_FILES {
        my $either = shift;
        my $files_aref = shift;

         my $class = ref($either) || $either;

         if ($$files_aref[0] =~ /^\.\w/){

                @SOLEXA_DEFAULT_FILES = @{$files_aref};
                print "SET SOLEXA FILES '@SOLEXA_DEFAULT_FILES'\n";
        }
        return @SOLEXA_DEFAULT_FILES;
}

#######################################################
# get_SLIMSEQ_URI
# get the SLIMarray URI
#######################################################
sub get_SLIMSEQ_URI {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SLIMSEQ_URI;
}

#######################################################
# get_SLIMSEQ_USER
# get the SLIMarray user
#######################################################
sub get_SLIMSEQ_USER {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SLIMSEQ_USER;
}

#######################################################
# get_SLIMSEQ_PASS
# get the SLIMarray password
#######################################################
sub get_SLIMSEQ_PASS {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SLIMSEQ_PASS;
}

#######################################################
# ZIP_REQUEST_DIR
# get the default to read and write requests to
#######################################################
sub get_ZIP_REQUEST_DIR {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_ZIP_REQUEST_DIR;

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

                $SOLEXA_DEFAULT_DIR = $file_path;
                print "SET SOLEXA ZIP DIR '$SOLEXA_ZIP_REQUEST_DIR'\n";
        }

        return $SOLEXA_ZIP_REQUEST_DIR;
}

#######################################################
# solexa_delivery_path
# get the path to the delivery folder 
#######################################################
sub solexa_delivery_path {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_DELIVERY_PATH;
}

#######################################################
# get_ANNOTATION_OUT_FOLDER
# get the default folder to hold files generated by the Add_solexa_annotation script
#######################################################
sub get_ANNOTATION_OUT_FOLDER {
    my $either = shift;

    my $class = ref($either) || $either;
    return $ADD_ANNOTATION_OUT_FOLDER;

}

#######################################################
# get_SOLEXA_MYSQL_HOST
# 
#######################################################
sub get_SOLEXA_MYSQL_HOST {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_MYSQL_HOST;

}

#######################################################
# get_SOLEXA_MYSQL_USER
# 
#######################################################
sub get_SOLEXA_MYSQL_USER {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_MYSQL_USER;

}

#######################################################
# get_SOLEXA_MYSQL_PASS
# 
#######################################################
sub get_SOLEXA_MYSQL_PASS {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_MYSQL_PASS;

}

#######################################################
# get_SOLEXA_MYSQL_DB
# 
#######################################################
sub get_SOLEXA_MYSQL_DB {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_MYSQL_DB;

}

#######################################################
# get_SOLEXA_BABEL_HOST
# 
#######################################################
sub get_SOLEXA_BABEL_HOST {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_BABEL_HOST;

}

#######################################################
# get_SOLEXA_BABEL_USER
# 
#######################################################
sub get_SOLEXA_BABEL_USER {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_BABEL_USER;

}

#######################################################
# get_SOLEXA_BABEL_PASS
# 
#######################################################
sub get_SOLEXA_BABEL_PASS {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_BABEL_PASS;

}

#######################################################
# get_SOLEXA_BABEL_DB
# 
#######################################################
sub get_SOLEXA_BABEL_DB {
    my $either = shift;

    my $class = ref($either) || $either;
    return $SOLEXA_BABEL_DB;

}


#+
# get_admin_email
#
# returns configured path to admin_email
#-
sub get_admin_email {
  my $self = shift;

  my $rlib = $CONFIG_SETTING{ST_ADMIN_EMAIL} || '';
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

  return $CONFIG_SETTING{ST_BATCH_SYSTEM} || 'fork';

}


#+
# get_R_exe_path
#
# returns configured path to R executable
#-
sub get_R_exe_path {
  my $self = shift;

  my $rpath = $CONFIG_SETTING{ST_R_EXE_PATH} || '';

  if ( !$rpath ) {
    $log->warn( 'No path to R specified' );
  }

  return $rpath;
}

#+
# get_local_R_exe_path
#
# returns configured path to local R executable.  If not specified, uses
# global R exe setting (ST_R_EXE_PATH)
#-
sub get_local_R_exe_path {
  my $self = shift;

  my $rpath = $CONFIG_SETTING{ST_LOCAL_R_EXE_PATH} || $self->get_R_exe_path();

  if ( !$rpath ) {
    $log->warn( 'No path to R specified' );
  }

  return $rpath;
}

#+
# get_local_R_lib_path
#
# returns configured path to local R libraries.  If not specified, uses
# global R exe setting (ST_R_LIB_PATH)
#-
sub get_local_R_lib_path {
  my $self = shift;

  my $rpath = $CONFIG_SETTING{ST_LOCAL_R_LIB_PATH} || $self->get_R_lib_path();

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

  my $rlib = $CONFIG_SETTING{ST_R_LIB_PATH} || '';

  if ( !$rlib ) {
    $log->warn( 'No path to R library specified' );
  }

  return $rlib;
}

#+
# Utility method to return path to affy annotation files.
#-
sub get_solexa_annotation_path {
  my $apath = $CONFIG_SETTING{ST_SOLEXA_ANNOTATION_PATH} || '';
  # Trim trailing spaces
  $apath =~ s/\s+$//g;
  return $apath || "$PHYSICAL_BASE_DIR/var/SolexaTrans/Solexa_data/annotation";
}


1;
