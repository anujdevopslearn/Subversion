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

use vars qw($VERSION @ISA @EXPORT 
    $DBTITLE
    $DBVERSION
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
$DBTITLE                = 'SBEAMS';
$SERVER_BASE_DIR        = 'http://db';


#### Decide which version settings to use based on $ENV{SCRIPT_NAME} or
#### $ENV{SBEAMS_INSTANCE}
my $SBEAMS_INSTANCE;
$SBEAMS_INSTANCE = $ENV{SCRIPT_NAME} if ($ENV{SCRIPT_NAME});
$SBEAMS_INSTANCE = $ENV{SBEAMS_INSTANCE} if ($ENV{SBEAMS_INSTANCE});
$SBEAMS_INSTANCE = $ENV{PWD} unless ($SBEAMS_INSTANCE);
$SBEAMS_INSTANCE = "production" unless ($SBEAMS_INSTANCE);


#### Set version-specific parameters
if ( $SBEAMS_INSTANCE =~ /\/dev1\// ) {
  $DBVERSION              = 'Dev Branch 1';
  $BGCOLOR                = '#FF9999';
  $HTML_BASE_DIR          = '/dev1/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/dev1/sbeams";
  $UPLOAD_DIR             = "/local/data/dev1/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev2\// ) {
  $DBVERSION              = 'Dev Branch 2';
  $BGCOLOR                = '#FFFF99';
  $HTML_BASE_DIR          = '/dev2/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/dev2/sbeams";
  $UPLOAD_DIR             = "/local/data/dev2/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev5\// ) {
  $DBVERSION              = 'Dev Branch 5';
  $BGCOLOR                = '#336699';
  $HTML_BASE_DIR          = '/dev5/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/dev5/sbeams";
  $UPLOAD_DIR             = "/local/data/dev5/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev6\// ) {
  $DBVERSION              = 'Dev Branch 6';
  $BGCOLOR                = '#008b45';
  $HTML_BASE_DIR          = '/dev6/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/dev6/sbeams";
  $UPLOAD_DIR             = "/local/data/dev6/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev7\// ) {
  $DBVERSION              = 'Dev Branch 7';
  $BGCOLOR                = '#cc00cc';
  $HTML_BASE_DIR          = '/dev7/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/dev7/sbeams";
  $UPLOAD_DIR             = "/local/data/dev7/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/dev8\// ) {
  $DBVERSION              = 'Dev Branch 8';
  $BGCOLOR                = '#cccc00';
  $HTML_BASE_DIR          = '/dev8/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/dev8/sbeams";
  $UPLOAD_DIR             = "/local/data/dev8/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/ext\// ) {
  $DBVERSION              = 'External Access';
  $BGCOLOR                = '#99DD99';
  $HTML_BASE_DIR          = '/ext/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/ext/sbeams";
  $UPLOAD_DIR             = "/local/data/ext/sbeams";

} elsif ( $SBEAMS_INSTANCE =~ /\/mysqldev1\// ) {
  $DBVERSION              = 'MySQL Dev Branch 1';
  $BGCOLOR                = '#FFFF99';
  $HTML_BASE_DIR          = '/mysqldev1/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/mysqldev1/sbeams";
  $UPLOAD_DIR             = "/local/data/mysqldev1/sbeams";

} else {
  $DBVERSION              = '<FONT COLOR=red>Primary</FONT>';
  $BGCOLOR                = '#BFD8D8';
  $HTML_BASE_DIR          = '/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/sbeams";
  $UPLOAD_DIR             = "/local/data/sbeams";
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

