package SBEAMS::Connection::Settings;

###############################################################################
# Program     : SBEAMS::Connection::Settings
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               setting location-dependant variables.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use FindBin;
use Data::Dumper;



use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
    $DBTITLE
    $DBADMIN
    $DBINSTANCE
    $DBVERSION
    $DBCONFIG
    %DBPREFIX
    %RAW_DATA_DIR
    $BGCOLOR
    $BARCOLOR
    $HOSTNAME
    $CYTOSCAPE_URL
    $SERVER_BASE_DIR
    $CGI_BASE_DIR
    $HTML_BASE_DIR
    $DATA_DIR
    $OPTIONARROW
    $LINESEPARATOR
    $MESSAGE_WIDTH
    $PHYSICAL_BASE_DIR
    $UPLOAD_DIR
    $RESULTSET_DIR
    $SBEAMS_PART
    $SBEAMS_SUBDIR
    $LOGGING_LEVEL
    $LOG_BASE_DIR
    $LOGIN_DURATION
    $SESSION_REAUTH
    $SMBAUTH
    %CONFIG_SETTING
    $SBEAMS_VERSION
    );

require Exporter;
@ISA = qw (Exporter);

@EXPORT_OK = qw($LOGGING_LEVEL $LOG_BASE_DIR $LOGIN_DURATION 
                $SESSION_REAUTH $SMBAUTH );
@EXPORT = qw (
    $DBTITLE
    $DBADMIN
    $DBINSTANCE
    $DBVERSION
    $DBCONFIG
    %DBPREFIX
    %RAW_DATA_DIR
    $BGCOLOR
    $BARCOLOR
    $HOSTNAME
    $CYTOSCAPE_URL
    $SERVER_BASE_DIR
    $CGI_BASE_DIR
    $HTML_BASE_DIR
    $DATA_DIR
    $OPTIONARROW
    $LINESEPARATOR
    $MESSAGE_WIDTH
    $PHYSICAL_BASE_DIR
    $UPLOAD_DIR
    $RESULTSET_DIR
    $SBEAMS_SUBDIR
    $SBEAMS_PART
    %CONFIG_SETTING
    $SBEAMS_VERSION

    );
my @default = @EXPORT;
#push @EXPORT, 'default';

%EXPORT_TAGS = ( default => \@default );


#### Decide which version settings to use based the script location
my $SBEAMS_PATH =  "$FindBin::Bin";
my $subdir = $SBEAMS_PATH;

# Replaced this regex, due to problems at UW where their PATH had a trailing
# slash that was causing the subdir name to become ''.  DSC 2005-09-01  
$subdir =~ s/^.*\/([^\/]+)\/*/$1/;

# Old version, just in case we need to roll back.
# $subdir =~ s/^.*\///;


$subdir = '' if ($subdir eq 'cgi');  # Clear it if it's the top cgi directory
setSBEAMS_SUBDIR('dummy',$subdir);

###Set the current version of SBEAMS ##
$SBEAMS_VERSION = "0.23-dev";

#### Read in local configuration information from SBEAMS.conf file
$DBCONFIG = readMainConfFile();
#print Dumper($DBCONFIG);
#print "Content-type: text/html\n\nSOURCE_FILE=".
#      $DBCONFIG->{__SOURCE_FILE}."<BR>\n";

#### Set instance-specific parameters
$SBEAMS_PATH = $DBCONFIG->{__SOURCE_FILE};
if ( $ENV{SBEAMS_DBINSTANCE} ) {
  $DBINSTANCE = $ENV{SBEAMS_DBINSTANCE};

} elsif ( $SBEAMS_PATH =~ /\/(dev\d)\// ) {
  $DBINSTANCE = $1;

} elsif ( $SBEAMS_PATH =~ /\/(dev[A-Z][A-Z])\// ) {
  $DBINSTANCE = $1;

} elsif ( $SBEAMS_PATH =~ /\/ext\// ) {
  $DBINSTANCE = 'ext';

} elsif ( $SBEAMS_PATH =~ /\/mysqldev1\// ) {
  $DBINSTANCE = 'mysqldev1';

} elsif ( $SBEAMS_PATH =~ /\/macrogenics\// ) {
  $DBINSTANCE = 'macrogenics';

} else {
  $DBINSTANCE = 'main';

}

#### Make sure that there are settings for this instance
#print "DBINSTANCE = $DBINSTANCE\n";
unless (defined($DBCONFIG->{$DBINSTANCE})) {
  die("Attempt to invoke non-existent dev instance $DBINSTANCE\n");
}

extractInstanceParams();



###############################################################################
# extractInstanceParams
#
# Once db instance is determined, extract working settingss for all parameters
# needed for db connection
###############################################################################
sub extractInstanceParams {
#print Dumper($DBCONFIG->{$DBINSTANCE});
    $DBTITLE = $DBCONFIG->{$DBINSTANCE}->{DBTITLE};
    $DBVERSION = $DBCONFIG->{$DBINSTANCE}->{DBVERSION};
    $DBADMIN = $DBCONFIG->{$DBINSTANCE}->{DBADMIN};
    $BGCOLOR = $DBCONFIG->{$DBINSTANCE}->{BGCOLOR};
    $BARCOLOR = $DBCONFIG->{$DBINSTANCE}->{BARCOLOR};
    $HTML_BASE_DIR = $DBCONFIG->{$DBINSTANCE}->{HTML_BASE_DIR};
    $PHYSICAL_BASE_DIR = $DBCONFIG->{$DBINSTANCE}->{PHYSICAL_BASE_DIR};
    $UPLOAD_DIR = $DBCONFIG->{$DBINSTANCE}->{UPLOAD_DIR};
    $RESULTSET_DIR = $DBCONFIG->{$DBINSTANCE}->{RESULTSET_DIR} || 'tmp/queries'; #legacy
    $HOSTNAME = $DBCONFIG->{$DBINSTANCE}->{HOSTNAME};
    $CYTOSCAPE_URL = $DBCONFIG->{$DBINSTANCE}->{CYTOSCAPE_URL};
    %DBPREFIX = %{$DBCONFIG->{$DBINSTANCE}->{DBPREFIX}};
    %RAW_DATA_DIR = %{$DBCONFIG->{$DBINSTANCE}->{RAW_DATA_DIR}};
    $LOGGING_LEVEL = $DBCONFIG->{$DBINSTANCE}->{LOGGING_LEVEL};
    $LOG_BASE_DIR = $DBCONFIG->{$DBINSTANCE}->{LOG_BASE_DIR};
    $LOGIN_DURATION = $DBCONFIG->{$DBINSTANCE}->{LOGIN_DURATION};
    $SESSION_REAUTH = $DBCONFIG->{$DBINSTANCE}->{SESSION_REAUTH};
    $SMBAUTH = \%{$DBCONFIG->{$DBINSTANCE}->{SMBAUTH}};

    my $config_setting = $DBCONFIG->{$DBINSTANCE}->{CONFIG_SETTING} || {};
    %CONFIG_SETTING = %{$config_setting};

# Translate relative paths to absolute.
    for my $arg ( $UPLOAD_DIR, $RESULTSET_DIR  ) {
	if ( $arg !~ /^\// ) {
	    my $delim = ($PHYSICAL_BASE_DIR =~ /\/$/) ? '' : '/'; 
	    $arg = $PHYSICAL_BASE_DIR . $delim . $arg;
	}
    }

# Translate relative paths to absolute.
    for my $key ( keys(%CONFIG_SETTING)  ) {
      for my $arg ( qw(JNLP_KEYSTORE)  ) {
	if ( $CONFIG_SETTING{$arg} !~ /^\// ) {
	    my $delim = ($PHYSICAL_BASE_DIR =~ /\/$/) ? '' : '/'; 
	    $CONFIG_SETTING{$arg} = $PHYSICAL_BASE_DIR . $delim . $CONFIG_SETTING{$arg};
        }
      }
    }


#### Determine what the BASE URL is: first pull out some environment variables
    my $_server_port = $ENV{SERVER_PORT} || "";
    my $_http_host = $ENV{HTTP_HOST} || "";
    my $_script_name = $ENV{SCRIPT_NAME} || "";

### If a SERVER_PORT was defined, then build the BASE URL
    if ($_server_port) {
	if ($_server_port eq '443') {
	    $SERVER_BASE_DIR = "https://";
	} else {
	    $SERVER_BASE_DIR = "http://";
	}

	if ($_http_host) {
	    $SERVER_BASE_DIR .= $_http_host;
	} else {
	    $SERVER_BASE_DIR .= $HOSTNAME;
	}

#### Otherwise, we're probably not coming through HTTP, so just set it
    } else {
      $HOSTNAME = '' if !defined $HOSTNAME;
      $SERVER_BASE_DIR = "http://$HOSTNAME";
    }

#### Set some additional settings which depend on version-specific parameters
    $DATA_DIR       = "$HTML_BASE_DIR/data";
    $CGI_BASE_DIR   = "$HTML_BASE_DIR/cgi";
    $OPTIONARROW    = "<P><IMG SRC=\"$HTML_BASE_DIR/images/yellow-arrow.gif\">&nbsp;";
    $LINESEPARATOR  = "<P><IMG SRC=\"$HTML_BASE_DIR/images/smalline.gif\">&nbsp;";
    $MESSAGE_WIDTH  = '350';

}


###############################################################################
# getSBEAMS_SUBDIR
#
# Get the current value of SBEAMS_SUBDIR, which can be changed by
# subpackages
###############################################################################
sub getSBEAMS_SUBDIR {
    my $self = shift || die("parameter self not passed");

    $SBEAMS_SUBDIR = '' unless (defined($SBEAMS_SUBDIR));

    return $SBEAMS_SUBDIR;

}


###############################################################################
# setSBEAMS_SUBDIR
#
# Set the current value of SBEAMS_SUBDIR, ususally by subpackages
###############################################################################
sub setSBEAMS_SUBDIR {
    my $self = shift || die("parameter self not passed");
    my $newsubdir = shift || '';

    $SBEAMS_SUBDIR = $newsubdir;

    return $SBEAMS_SUBDIR;

}


################################################################################
## setSBEAMS_BASEDIR
##
## Set the current value of SBEAMS_BASEDIR, ususally by subpackages
################################################################################
#sub setSBEAMS_BASEDIR {
#    my $self = shift || die("parameter self not passed");
#    my $newbasedir = shift || '';
#
#    $SBEAMS_BASEDIR = $newbasedir;
#
#    return $SBEAMS_BASEDIR;
#
#}



###############################################################################
# getWWWUID
#
# Return the UID of the web server user (often 'apache' or 'nobody')
###############################################################################
sub getWWWUID {
  return $DBCONFIG->{$DBINSTANCE}->{WWW_UID};
}


###############################################################################
# getCryptKey
#
# Return the Crypt Key used to authenticate cookies.  It should
# be changed at regular intervals for added security.
###############################################################################
sub getCryptKey {
  return $DBCONFIG->{$DBINSTANCE}->{CRYPT_KEY};
}

###############################################################################
# get_version	
#
# Return the current version of sbeams.  Hard coded !!!
###############################################################################
sub get_sbeams_version {
  
  return $SBEAMS_VERSION;
}


###############################################################################
# getSite	
#
# Returns the site of this SBEAMS instance, e.g. "ISB", "ETH", etc.
# as specified in the SBEAMS .conf file. This is used to enable
# special functionality in the code base which is expected to only
# work at a particular site for the moment
###############################################################################
sub getSite {
  my $site = '';
  $site = $CONFIG_SETTING{SITE} if ($CONFIG_SETTING{SITE});
  return $site;
}

sub getServerURI {
  my $sbeams = shift;
  return $SERVER_BASE_DIR;
}

sub getCGIBaseURI {
  my $sbeams = shift;
  return $SERVER_BASE_DIR . $CGI_BASE_DIR;
}

sub getDeniedGuestUsers {
  my $sbeams = shift;
  my $denied_string = $CONFIG_SETTING{DenyGuestPrivileges} if ($CONFIG_SETTING{DenyGuestPrivileges});
	return [] unless $denied_string;

  $denied_string =~ s/\s//g;
	my @denied = split( ',', $denied_string, -1 );
	return \@denied;
#	CONFIG_SETTING{DenyGuestPrivileges} = ext_mrm,ext_halo
}


###############################################################################
# readMainConfFile: Read the contents of the main conf file
###############################################################################
sub readMainConfFile {
  my %args = @_;

  #### Define some basic stuff
  my $SUB_NAME = 'readMainConfFile';


  #### Start an error buffer to print verbose information if we fail
  my $ERROR_BUFFER = "Searching \@INC for conf file...\n";
  my $most_likely_place = "????";


  #### Try to find the conf file based on @INC
  foreach my $libdir (@INC) {
    $ERROR_BUFFER .=  "Trying $libdir\n";
    my $likely_conf_file = "$libdir/../conf/SBEAMS.conf";

    #### Guess as to what the most likely place is
    if ($most_likely_place eq '????' && -e "$libdir/../../../sbeams") {
      $most_likely_place = $likely_conf_file;
    }

    #### See if there's a conf file where we expect and read it if so
    if (-e $likely_conf_file) {
      $ERROR_BUFFER .= "Found conf file $likely_conf_file\n";
      return readIniFile(source_file => $likely_conf_file);
    } else {
      $ERROR_BUFFER .= "Expected to find a conf file at $likely_conf_file\n";
    }
  }


  #### If we got this far, we failed to find a conf file.  Woe.
  die("$SUB_NAME: ERROR: Searched for a conf file and couldn't find it.\n".
    "Perhaps you need to create one in $most_likely_place.  We tried:\n".
    "$ERROR_BUFFER\n\n");

} # end readMainConfFile


sub getEmailAddress {
  my $this = shift;
  my %args = @_;
  our $TB_CONTACT;
  $args{contact_id} ||= $this->getCurrent_contact_id();
  my $contact = $this->evalSQL( '$TB_CONTACT' );
  my $sql =<<"  END";
  SELECT email FROM $contact WHERE contact_id = $args{contact_id}
  END
  my ( $email ) = $this->getDBHandle()->selectrow_array( $sql ); 
  return $email || '';
}

###############################################################################
# readIniFile: Read the contents of a .ini style file
###############################################################################
sub readIniFile {
#  my $self = shift || croak("parameter self not passed");
  my %args = @_;


  #### Define some basic stuff
  my $SUB_NAME = 'readIniFile';
  my ($i,$line);


  #### Decode the argument list
  my $source_file = $args{'source_file'}
    || die "$SUB_NAME: Must provide a source_file";
  my $verbose = $args{'verbose'} || 0;


  #### Verify the existence of the file
  return unless ($source_file);
  unless ( -e $source_file ) {
    print "$SUB_NAME: source_file '$source_file' does not exist\n"
      if ($verbose);
    return;
  }


  #### Open the file
  unless (open(INFILE,"$source_file")) {
    die("$SUB_NAME: Cannot open source_file '$source_file'");
  }

  #### Set up a hash reference to hold all the configuration data
  my $config;
  $config->{CONFIG_LOADED} = 'NOT YET';


  #### If the source_file is a relative path, expand it
  if ($source_file =~ /^\./) {
    use Cwd;
    $source_file = cwd()."/".$source_file;
  }
  $config->{__SOURCE_FILE} = $source_file;


  #### Read in all the modules
  my $current_section = '';
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;            # strip CRs
    next if ($line =~ /^\s*\#/);     # Ignore lines startin with #
    next if ($line =~ /^\s+$/);      # Ignore lines with only spaces
    next unless ($line);             # Ignore empty lines

    #### If this is the beginning of a new section, set it
    if ($line =~ /^\s*\[(.+)\]\s*$/) {
      if ($1) {
        $current_section = $1;

        #### If there's already a [default] section, start from it
        if ($config->{default}) {
          my $serialized_default = Dumper($config->{default});
          my $VAR1;
          eval $serialized_default;
          $config->{$current_section} = $VAR1;
        }

      } else {
        die("$SUB_NAME: ERROR reading section name");
      }
      next;
    }

    #### If this looks like a key=value pair, process it
    if ($line =~ /^\s*(\S+)\s*\=\s*(.*)$/) {

      #### Make sure we know what section we're currently processing
      unless ($current_section) {
        print "WARNING: $SUB_NAME: key/value pair before section header.".
          "Assuming start of section [default]\n";
        $current_section = "default";
      }
      my $key = $1;
      my $value = $2;

      #### If there are {}'s in key, parse further and nest it 1 level deeper
      if ($key =~ /^(.+)\{(.+)\}$/) {
        my $key1 = $1;
        my $key2 = $2;
        $config->{$current_section}->{$key1}->{$key2} = $value;

      #### Otherwise it's just a plain key=value pair
      } else {
        $config->{$current_section}->{$key} = $value;
      }

    #### Otherwise we don't know what to do with this so complain
    } else {
      print "ERROR: $SUB_NAME: Unable to parse line:\n";
      print "$line\n";
    }

  }

  close(INFILE);


  #### Return reference to the hash of all config information
  $config->{CONFIG_LOADED} = 'SUCCESS';
  return $config;

} # end readIniFile

#+
# Method returns appropriate module prefix, based on SBEAMS_SUBDIR
#-
sub getModulePrefix {
  my $self = shift;
  my %prefix = ( BEDB => 'BE',
                 BioLink => 'BL',
                 Biosap => 'BS',
                 Cytometry => 'CY',
                 Genotyping => 'GT',
                 Immunostain => 'IS',
                 Inkjet => 'IJ',
                 Interactions => 'IN',
                 Microarray => 'MA',
                 Oligo => 'OG',
                 PeptideAtlas => 'AT',
                 PhenoArray => 'PH',
                 ProteinStructure => 'PS',
                 Proteomics => 'PR',
                 SNP => 'SN'
                ); 
  return( $prefix{$SBEAMS_SUBDIR} || '' );
}

#+
# Utility method returns configured java path or default
#-
sub get_java_path {
  return $CONFIG_SETTING{JAVA_PATH} || '/usr/java/bin/';
}

#+
# Utility method returns configured keystore
#-
sub get_jnlp_keystore {
  return $CONFIG_SETTING{JNLP_KEYSTORE} || '/var/keystore/';
}

#+
# Utility method returns configured keystore_passwd
#-
sub get_keystore_passwd {
  return $CONFIG_SETTING{KEYSTORE_PASSWD} || 'fixme';
}

#+
# Utility method returns configured keystore_alias
#-
sub get_keystore_alias {
  return $CONFIG_SETTING{KEYSTORE_ALIAS} || 'sbeamsDEV';
}



###############################################################################

1;

__END__

###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::Settings

SBEAMS Core settings definition file

=head2 SYNOPSIS

See SBEAMS::Connection for usage synopsis.

=head2 DESCRIPTION

This pm provides the logic for setting up all the site/instance dependant
settings for SBEAMS


=head2 METHODS

=over

=item * none



=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut


