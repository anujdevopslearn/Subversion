package SBEAMS::Genotyping::Tables;

###############################################################################
# Program     : SBEAMS::Genotyping::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Genotyping module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBGT_BIOSEQUENCE_SET
    $TBGT_DBXREF
    $TBGT_BIOSEQUENCE
    $TBGT_BIOSEQUENCE_PROPERTY_SET

    $TBGT_EXPERIMENT
    $TBGT_SAMPLE
    $TBGT_POOLING_SET
    $TBGT_DNA_TYPE
    $TBGT_REQUESTED_GENOTYPING_ASSAY
    $TBGT_COST_SCHEME

    $TBGT_QUERY_OPTION

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBGT_BIOSEQUENCE_SET
    $TBGT_DBXREF
    $TBGT_BIOSEQUENCE
    $TBGT_BIOSEQUENCE_PROPERTY_SET

    $TBGT_EXPERIMENT
    $TBGT_SAMPLE
    $TBGT_POOLING_SET
    $TBGT_DNA_TYPE
    $TBGT_REQUESTED_GENOTYPING_ASSAY
    $TBGT_COST_SCHEME

    $TBGT_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Genotyping};

$TB_ORGANISM                = "${core}organism";

$TBGT_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBGT_DBXREF                = "${mod}dbxref";
$TBGT_BIOSEQUENCE           = "${mod}biosequence";
$TBGT_BIOSEQUENCE_PROPERTY_SET   = "${mod}biosequence_property_set";
$TBGT_EXPERIMENT            = "${mod}experiment";
$TBGT_SAMPLE                = "${mod}sample";
$TBGT_POOLING_SET           = "${mod}pooling_set";
$TBGT_DNA_TYPE              = "${mod}dna_type";
$TBGT_REQUESTED_GENOTYPING_ASSAY = "${mod}requested_genotyping_assay";
$TBGT_COST_SCHEME           = "${mod}cost_scheme";
$TBGT_QUERY_OPTION          = "${mod}query_option";



