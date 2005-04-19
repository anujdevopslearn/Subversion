package SBEAMS::PeptideAtlas::Tables;

###############################################################################
# Program     : SBEAMS::PeptideAtlas::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::PeptideAtlas module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM
    $TBBL_POLYMER_TYPE

    $TBAT_BIOSEQUENCE_SET
    $TBAT_DBXREF
    $TBAT_BIOSEQUENCE
    $TBAT_BIOSEQUENCE_PROPERTY_SET
    $TBAT_QUERY_OPTION

    $TBAT_ATLAS_BUILD
    $TBAT_SAMPLE
    $TBAT_ATLAS_BUILD_SAMPLE
    $TBAT_PEPTIDE
    $TBAT_PEPTIDE_INSTANCE
    $TBAT_PEPTIDE_INSTANCE_SAMPLE
    $TBAT_PEPTIDE_MAPPING
    $TBAT_PUBLICATION
    $TBAT_BIOSEQUENCE_ANNOTATED_GENE
    $TBAT_BIOSEQUENCE_ANNOTATION

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
    $TBBL_POLYMER_TYPE

    $TBAT_BIOSEQUENCE_SET
    $TBAT_DBXREF
    $TBAT_BIOSEQUENCE
    $TBAT_BIOSEQUENCE_PROPERTY_SET
    $TBAT_QUERY_OPTION

    $TBAT_ATLAS_BUILD
    $TBAT_SAMPLE
    $TBAT_ATLAS_BUILD_SAMPLE
    $TBAT_PEPTIDE
    $TBAT_PEPTIDE_INSTANCE
    $TBAT_PEPTIDE_INSTANCE_SAMPLE
    $TBAT_PEPTIDE_MAPPING

    $TBAT_PUBLICATION
    $TBAT_BIOSEQUENCE_ANNOTATED_GENE
    $TBAT_BIOSEQUENCE_ANNOTATION
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{PeptideAtlas};
my $BioLink = $DBPREFIX{BioLink};

$TB_ORGANISM                = "${core}organism";
$TBBL_POLYMER_TYPE          = "${BioLink}polymer_type";

$TBAT_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBAT_DBXREF                = "${mod}dbxref";
$TBAT_BIOSEQUENCE           = "${mod}biosequence";
$TBAT_BIOSEQUENCE_PROPERTY_SET = "${mod}biosequence_property_set";
$TBAT_QUERY_OPTION          = "${mod}query_option";

$TBAT_ATLAS_BUILD           = "${mod}atlas_build";
$TBAT_SAMPLE                = "${mod}sample";
$TBAT_ATLAS_BUILD_SAMPLE    = "${mod}atlas_build_sample";
$TBAT_PEPTIDE               = "${mod}peptide";
$TBAT_PEPTIDE_INSTANCE      = "${mod}peptide_instance";
$TBAT_PEPTIDE_INSTANCE_SAMPLE  = "${mod}peptide_instance_sample";
$TBAT_PEPTIDE_MAPPING       = "${mod}peptide_mapping";
$TBAT_PUBLICATION           = "${mod}publication";
$TBAT_BIOSEQUENCE_ANNOTATED_GENE = "${mod}biosequence_annotated_gene";
$TBAT_BIOSEQUENCE_ANNOTATION = "${mod}biosequence_annotation";


