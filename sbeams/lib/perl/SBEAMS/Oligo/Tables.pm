package SBEAMS::Oligo::Tables;

###############################################################################
# Program     : SBEAMS::Oligo::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Oligo module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

	$TBOG_BIOSEQUENCE_SET
    $TBOG_BIOSEQUENCE
    $TBOG_BIOSEQUENCE_PROPERTY_SET
    $TBOG_OLIGO_HIT
    $TBOG_OLIGO
    $TBOG_OLIGO_ANNOTATION
    $TBOG_OLIGO_TYPE
    $TBOG_SELECTED_OLIGO
    $TBOG_OLIGO_SEARCH
    $TBOG_SEARCH_TOOL
    $TBOG_OLIGO_PARAMETER_SET
    $TBOG_FEATURAMA_STATISTIC
    $TBOG_OLIGO_SET
    $TBOG_OLIGO_SET_TYPE
    $TBOG_OLIGO_OLIGO_SET
    $TBOG_POLYMER_TYPE
    $TBOG_DBXREF

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

	$TBOG_BIOSEQUENCE_SET
    $TBOG_BIOSEQUENCE
    $TBOG_BIOSEQUENCE_PROPERTY_SET
    $TBOG_OLIGO_HIT
    $TBOG_OLIGO
    $TBOG_OLIGO_ANNOTATION
    $TBOG_OLIGO_TYPE
    $TBOG_SELECTED_OLIGO
    $TBOG_OLIGO_SEARCH
    $TBOG_SEARCH_TOOL
    $TBOG_OLIGO_PARAMETER_SET
    $TBOG_FEATURAMA_STATISTIC
    $TBOG_OLIGO_SET
    $TBOG_OLIGO_SET_TYPE
    $TBOG_OLIGO_OLIGO_SET
    $TBOG_POLYMER_TYPE
    $TBOG_DBXREF

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Oligo};


$TB_ORGANISM                      = "${core}organism";

$TBOG_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBOG_BIOSEQUENCE           = "${mod}biosequence";
$TBOG_BIOSEQUENCE_PROPERTY_SET   = "${mod}biosequence_property_set";
$TBOG_OLIGO_HIT             = "${mod}oligo_hit";
$TBOG_OLIGO_ANNOTATION      = "${mod}oligo_annotation";
$TBOG_OLIGO_TYPE            = "${mod}oligo_type";
$TBOG_SELECTED_OLIGO        = "${mod}selected_oligo";
$TBOG_OLIGO_SEARCH          = "${mod}oligo_search";
$TBOG_SEARCH_TOOL           = "${mod}search_tool";
$TBOG_OLIGO_PARAMETER_SET   = "${mod}oligo_parameter_set";
$TBOG_FEATURAMA_STATISTIC   = "${mod}featurama_statistic";
$TBOG_OLIGO_SET             = "${mod}oligo_set";
$TBOG_OLIGO_SET_TYPE        = "${mod}oligo_set_type";
$TBOG_OLIGO_OLIGO_SET       = "${mod}oligo_oligo_set";
$TBOG_POLYMER_TYPE          = "$DBPREFIX{Microarray}polymer_type";
$TBOG_DBXREF                = "$DBPREFIX{ProteinStructure}dbxref";




