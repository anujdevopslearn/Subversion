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
    $SERVER_BASE_DIR
    $CGI_BASE_DIR
    $HTML_BASE_DIR
    $DATA_DIR
    $OPTIONARROW
    $LINESEPARATOR
    $MESSAGE_WIDTH
    $PHYSICAL_BASE_DIR
    $UPLOAD_DIR
    );

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $DBTITLE
    $DBVERSION
    $BGCOLOR
    $SERVER_BASE_DIR
    $CGI_BASE_DIR
    $HTML_BASE_DIR
    $DATA_DIR
    $OPTIONARROW
    $LINESEPARATOR
    $MESSAGE_WIDTH
    $PHYSICAL_BASE_DIR
    $UPLOAD_DIR
    );


$DBTITLE                = 'SBEAMS';
$SERVER_BASE_DIR        = 'http://db';


if ( $ENV{SCRIPT_NAME} =~ /dev1/ ) {
  $DBVERSION              = 'Dev Branch 1';
  $BGCOLOR                = '#FF9999';
  $HTML_BASE_DIR          = '/dev1/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/dev1/sbeams";
  $UPLOAD_DIR             = "/local/data/dev1/sbeams";

} elsif ( $ENV{SCRIPT_NAME} =~ /dev2/ ) {
  $DBVERSION              = 'Dev Branch 2';
  $BGCOLOR                = '#FFFF99';
  $HTML_BASE_DIR          = '/dev2/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/dev2/sbeams";
  $UPLOAD_DIR             = "/local/data/dev2/sbeams";

} elsif ( $ENV{SCRIPT_NAME} =~ /ext/ ) {
  $DBVERSION              = 'External Access';
  $BGCOLOR                = '#99DD99';
  $HTML_BASE_DIR          = '/ext/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/ext/sbeams";
  $UPLOAD_DIR             = "/local/data/ext/sbeams";

} else {
  $DBVERSION              = '<FONT COLOR=red>Full Production</FONT>';
  $BGCOLOR                = '#BFD8D8';
  $HTML_BASE_DIR          = '/sbeams';
  $PHYSICAL_BASE_DIR      = "/local/www/html/sbeams";
  $UPLOAD_DIR             = "/local/data/sbeams";
}


$DATA_DIR               = "$HTML_BASE_DIR/data";
$CGI_BASE_DIR           = "$HTML_BASE_DIR/cgi";
$OPTIONARROW            = "<P><IMG SRC=\"$HTML_BASE_DIR/images/yellow-arrow.gif\">&nbsp;";
$LINESEPARATOR          = "<P><IMG SRC=\"$HTML_BASE_DIR/images/smalline.gif\">&nbsp;";
$MESSAGE_WIDTH          = '350';



