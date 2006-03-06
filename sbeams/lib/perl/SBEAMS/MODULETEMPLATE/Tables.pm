package SBEAMS::SIGID::Tables;

###############################################################################
# Program     : SBEAMS::SIGID::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::SIGID module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBSI_BIOSEQUENCE_SET
    $TBSI_DBXREF
    $TBSI_BIOSEQUENCE
    $TBSI_BIOSEQUENCE_PROPERTY_SET
    $TBSI_QUERY_OPTION

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBSI_BIOSEQUENCE_SET
    $TBSI_DBXREF
    $TBSI_BIOSEQUENCE
    $TBSI_BIOSEQUENCE_PROPERTY_SET
    $TBSI_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{SIGID};

$TB_ORGANISM                      = "${core}organism";

$TBSI_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBSI_DBXREF                = "${mod}dbxref";
$TBSI_BIOSEQUENCE           = "${mod}biosequence";
$TBSI_BIOSEQUENCE_PROPERTY_SET   = "${mod}biosequence_property_set";
$TBSI_QUERY_OPTION          = "${mod}query_option";



