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

use vars qw($VERSION @ISA @EXPORT 
    $DBTITLE
    $DBVERSION
    %DBPREFIX
    $BGCOLOR
    $BARCOLOR
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
    $DBVERSION
    %DBPREFIX
    $BGCOLOR
    $BARCOLOR
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


#### Set some initial parameter settings
$DBTITLE = 'SBEAMS';


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
    $SERVER_BASE_DIR .= 'db.systemsbiology.net';
  }

#### Otherwise, we're probably not coming through HTTP, so just set it
} else {
  $SERVER_BASE_DIR        = 'http://db.systemsbiology.net';
}


#### Decide which version settings to use based the script location
my $SBEAMS_INSTANCE =  "$FindBin::Bin";
my $subdir = $SBEAMS_INSTANCE;
$subdir =~ s/^.*\///;
setSBEAMS_SUBDIR('dummy',$subdir);


#### Set some database prefixes to be appended before the actualy table
#### names.  For databases that don't support cross-database queries
#### (e.g. PostgreSQL 7.2), the entries should be empty strings "".
$DBPREFIX{Core} = 'sbeams.dbo.';
$DBPREFIX{Proteomics} = 'proteomics.dbo.';
$DBPREFIX{Biosap} = 'Biosap.dbo.';
$DBPREFIX{BEDB} = 'BEDB.dbo.';


#### Set version-specific parameters
if ( $SBEAMS_INSTANCE =~ /\/dev1\// ) {
  $DBVERSION              = 'Dev Branch 1';
  $BGCOLOR                = '#FF9999';
  $HTML_BASE_DIR          = '/dev1/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/dev1/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/dev1/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev2\// ) {
  $DBVERSION              = 'Dev Branch 2';
  $BGCOLOR                = '#FFFF99';
  $HTML_BASE_DIR          = '/dev2/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/dev2/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/dev2/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev5\// ) {
  $DBVERSION              = 'Dev Branch 5';
  $BGCOLOR                = '#336699';
  $HTML_BASE_DIR          = '/dev5/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/dev5/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/dev5/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev6\// ) {
  $DBVERSION              = 'Dev Branch 6';
  $BGCOLOR                = '#008b45';
  $HTML_BASE_DIR          = '/dev6/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/dev6/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/dev6/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev7\// ) {
  $DBVERSION              = 'Dev Branch 7';
  $BGCOLOR                = '#cc00cc';
  $HTML_BASE_DIR          = '/dev7/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/dev7/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/dev7/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev8\// ) {
  $DBVERSION              = 'Dev Branch 8';
  $BGCOLOR                = '#ff702f';
  $HTML_BASE_DIR          = '/dev8/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/dev8/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/dev8/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/ext\// ) {
  $DBVERSION              = 'External Access';
  $BGCOLOR                = '#99DD99';
  $HTML_BASE_DIR          = '/ext/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/ext/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/ext/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/mysqldev1\// ) {
  $DBVERSION              = 'MySQL Dev Branch 1';
  $BGCOLOR                = '#FFFF99';
  $HTML_BASE_DIR          = '/mysqldev1/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/mysqldev1/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/mysqldev1/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/macrogenics\// ) {
  $DBVERSION              = 'Macrogenics';
  $BGCOLOR                = '#BFD8D8';
  $HTML_BASE_DIR          = '/macrogenics/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/macrogenics/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/macrogenics/sbeams";
  $DBPREFIX{Core}         = 'MGProteomics.dbo.';
  $DBPREFIX{Proteomics}   = 'MGProteomics.dbo.';

} else {
  $DBVERSION              = '<FONT COLOR=red>Primary</FONT>';
  $BGCOLOR                = '#BFD8D8';
  $HTML_BASE_DIR          = '/sbeams';
  $PHYSICAL_BASE_DIR      = "/net/dblocal/www/html/sbeams";
  $UPLOAD_DIR             = "/net/dblocal/data/sbeams";
}


#### Set some additional settings which depend on version-specific parameters
$BARCOLOR               = '#cdd1e7';
$DATA_DIR               = "$HTML_BASE_DIR/data";
$CGI_BASE_DIR           = "$HTML_BASE_DIR/cgi";
$OPTIONARROW            = "<P><IMG SRC=\"$HTML_BASE_DIR/images/yellow-arrow.gif\">&nbsp;";
$LINESEPARATOR          = "<P><IMG SRC=\"$HTML_BASE_DIR/images/smalline.gif\">&nbsp;";
$MESSAGE_WIDTH          = '350';




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


1;

