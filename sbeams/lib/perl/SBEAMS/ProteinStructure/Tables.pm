package SBEAMS::ProteinStructure::Tables;

###############################################################################
# Program     : SBEAMS::ProteinStructure::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::ProteinStructure module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBPS_BIOSEQUENCE_SET
    $TBPS_POLYMER_TYPE
    $TBPS_DBXREF
    $TBPS_BIOSEQUENCE
    $TBPS_BIOSEQUENCE_PROPERTY_SET
    $TBPS_QUERY_OPTION

    $TBPS_DOMAIN_MATCH
    $TBPS_DOMAIN_MATCH_TYPE
    $TBPS_DOMAIN_MATCH_SOURCE

    $TBPS_DOMAIN
    $TBPS_BIOSEQUENCE_ANNOTATION
    $TBPS_TEST_TABLE
);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBPS_BIOSEQUENCE_SET
    $TBPS_POLYMER_TYPE
    $TBPS_DBXREF
    $TBPS_BIOSEQUENCE
    $TBPS_BIOSEQUENCE_PROPERTY_SET
    $TBPS_QUERY_OPTION

    $TBPS_DOMAIN_MATCH
    $TBPS_DOMAIN_MATCH_TYPE
    $TBPS_DOMAIN_MATCH_SOURCE

    $TBPS_DOMAIN
    $TBPS_BIOSEQUENCE_ANNOTATION
    $TBPS_TEST_TABLE

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{ProteinStructure};

$TB_ORGANISM                      = "${core}organism";

$TBPS_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBPS_POLYMER_TYPE          = "$DBPREFIX{Microarray}polymer_type";
$TBPS_DBXREF                = "${mod}dbxref";
$TBPS_BIOSEQUENCE           = "${mod}biosequence";
$TBPS_BIOSEQUENCE_PROPERTY_SET  = "${mod}biosequence_property_set";
$TBPS_QUERY_OPTION          = "${mod}query_option";

$TBPS_DOMAIN_MATCH          = "${mod}domain_match";
$TBPS_DOMAIN_MATCH_TYPE     = "${mod}domain_match_type";
$TBPS_DOMAIN_MATCH_SOURCE   = "${mod}domain_match_source";

$TBPS_DOMAIN                = "${mod}domain";
$TBPS_BIOSEQUENCE_ANNOTATION   = "${mod}biosequence_annotation";
$TBPS_TEST_TABLE            = "${mod}test_table";

