package SBEAMS::UESC::Tables;

###############################################################################
# Program     : SBEAMS::UESC::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::UESC module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBUESC_BIOSEQUENCE_SET
    $TBUESC_DBXREF
    $TBUESC_BIOSEQUENCE
    $TBUESC_QUERY_OPTION

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBUESC_BIOSEQUENCE_SET
    $TBUESC_DBXREF
    $TBUESC_BIOSEQUENCE
    $TBUESC_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{UESC};

$TB_ORGANISM                      = "${core}organism";

$TBUESC_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBUESC_DBXREF                = "${mod}dbxref";
$TBUESC_BIOSEQUENCE           = "${mod}biosequence";
$TBUESC_QUERY_OPTION          = "${mod}query_option";



