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
    $TBAT_SAMPLE_PUBLICATION
    
    $TBAT_IPI_VERSION
    $TBAT_IPI_XREFS
    $TBAT_IPI_DATA
    $TBAT_CELLULAR_LOCATION
    $TBAT_GLYCO_SITE
    $TBAT_IDENTIFIED_PEPTIDE
    $TBAT_PREDICTED_PEPTIDE
    $TBAT_PEPTIDE_TO_TISSUE
    $TBAT_TISSUE_TYPE
    $TBAT_GLYCO_SAMPLE
    $TBAT_IDENTIFIED_TO_IPI
    $TBAT_SYNTHESIZED_PEPTIDE

    $TBAT_SEARCH_KEY
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
    $TBAT_SAMPLE_PUBLICATION
    
    $TBAT_IPI_VERSION
    $TBAT_IPI_XREFS
    $TBAT_IPI_DATA
    $TBAT_CELLULAR_LOCATION
    $TBAT_GLYCO_SITE
    $TBAT_IDENTIFIED_PEPTIDE
    $TBAT_PREDICTED_PEPTIDE
    $TBAT_PEPTIDE_TO_TISSUE
    $TBAT_TISSUE_TYPE
    $TBAT_GLYCO_SAMPLE
    $TBAT_IDENTIFIED_TO_IPI
    $TBAT_SYNTHESIZED_PEPTIDE

    $TBAT_SEARCH_KEY
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{PeptideAtlas};
my $glycomod = $DBPREFIX{GlycoPeptide} || $DBPREFIX{PeptideAtlas};
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
$TBAT_SAMPLE                = "${mod}sample";
$TBAT_SAMPLE_PUBLICATION    = "${mod}sample_publication";

$TBAT_IPI_VERSION	    	= "${glycomod}ipi_version";
$TBAT_IPI_XREFS	    	= "${glycomod}ipi_xrefs";
$TBAT_IPI_DATA			= "${glycomod}ipi_data";
$TBAT_CELLULAR_LOCATION		= "${glycomod}cellular_location";
$TBAT_GLYCO_SITE		= "${glycomod}glyco_site";
$TBAT_IDENTIFIED_PEPTIDE	= "${glycomod}identified_peptide";
$TBAT_PREDICTED_PEPTIDE		= "${glycomod}predicted_peptide";
$TBAT_PEPTIDE_TO_TISSUE		= "${glycomod}peptide_to_tissue";
$TBAT_TISSUE_TYPE			= "${glycomod}tissue_type";
$TBAT_IDENTIFIED_TO_IPI= "${glycomod}identified_to_ipi";
$TBAT_GLYCO_SAMPLE   = "${glycomod}glyco_sample";
$TBAT_SYNTHESIZED_PEPTIDE	= "${glycomod}synthesized_peptide";

$TBAT_SEARCH_KEY                = "${mod}search_key";


