package SBEAMS::Connection::Settings;

###############################################################################
# Program     : SBEAMS::Connection::Settings
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               setting location-dependant variables.
#
###############################################################################

use strict;
use FindBin;
use Data::Dumper;


use vars qw($VERSION @ISA @EXPORT 
    $DBTITLE
    $DBINSTANCE
    $DBVERSION
    $DBCONFIG
    %DBPREFIX
    %RAW_DATA_DIR
    $BGCOLOR
    $BARCOLOR
    $HOSTNAME
    $SERVER_BASE_DIR
    $CGI_BASE_DIR
    $HTML_BASE_DIR
    $DATA_DIR
    $OPTIONARROW
    $LINESEPARATOR
    $MESSAGE_WIDTH
    $PHYSICAL_BASE_DIR
    $UPLOAD_DIR
    $SBEAMS_SUBDIR
    );

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $DBTITLE
    $DBINSTANCE
    $DBVERSION
    $DBCONFIG
    %DBPREFIX
    %RAW_DATA_DIR
    $BGCOLOR
    $BARCOLOR
    $HOSTNAME
    $SERVER_BASE_DIR
    $CGI_BASE_DIR
    $HTML_BASE_DIR
    $DATA_DIR
    $OPTIONARROW
    $LINESEPARATOR
    $MESSAGE_WIDTH
    $PHYSICAL_BASE_DIR
    $UPLOAD_DIR
    $SBEAMS_SUBDIR
    );


#### Decide which version settings to use based the script location
my $SBEAMS_PATH =  "$FindBin::Bin";
my $subdir = $SBEAMS_PATH;
$subdir =~ s/^.*\///;
$subdir = '' if ($subdir eq 'cgi');  # Clear it if it's the top cgi directory
setSBEAMS_SUBDIR('dummy',$subdir);


#### Read in local configuration information from SBEAMS.conf file
$DBCONFIG = readMainConfFile();
#print Dumper($DBCONFIG);


#### Set instance-specific parameters
if ( $SBEAMS_PATH =~ /\/(dev\d)\// ) {
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


#### Now that we've determined the instance, extract the relevant settings
#print Dumper($DBCONFIG->{$DBINSTANCE});
$DBTITLE = $DBCONFIG->{$DBINSTANCE}->{DBTITLE};
$DBVERSION = $DBCONFIG->{$DBINSTANCE}->{DBVERSION};
$BGCOLOR = $DBCONFIG->{$DBINSTANCE}->{BGCOLOR};
$BARCOLOR = $DBCONFIG->{$DBINSTANCE}->{BARCOLOR};
$HTML_BASE_DIR = $DBCONFIG->{$DBINSTANCE}->{HTML_BASE_DIR};
$PHYSICAL_BASE_DIR = $DBCONFIG->{$DBINSTANCE}->{PHYSICAL_BASE_DIR};
$UPLOAD_DIR = $DBCONFIG->{$DBINSTANCE}->{UPLOAD_DIR};
$HOSTNAME = $DBCONFIG->{$DBINSTANCE}->{HOSTNAME};
%DBPREFIX = %{$DBCONFIG->{$DBINSTANCE}->{DBPREFIX}};
%RAW_DATA_DIR = %{$DBCONFIG->{$DBINSTANCE}->{RAW_DATA_DIR}};


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
  $SERVER_BASE_DIR = 'http://$HOSTNAME';
}


#### Set some additional settings which depend on version-specific parameters
$DATA_DIR       = "$HTML_BASE_DIR/data";
$CGI_BASE_DIR   = "$HTML_BASE_DIR/cgi";
$OPTIONARROW    = "<P><IMG SRC=\"$HTML_BASE_DIR/images/yellow-arrow.gif\">&nbsp;";
$LINESEPARATOR  = "<P><IMG SRC=\"$HTML_BASE_DIR/images/smalline.gif\">&nbsp;";
$MESSAGE_WIDTH  = '350';




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


