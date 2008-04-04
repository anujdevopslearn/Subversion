package SBEAMS::Glycopeptide::Tables;

###############################################################################
# Program     : SBEAMS::Glycopeptide::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: Tables.pm 1827 2003-11-27 00:43:01Z edeutsch $
#
# Description : This is part of the SBEAMS::Glycopeptide module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBGP_BIOSEQUENCE_SET
    $TBGP_DBXREF
    $TBGP_BIOSEQUENCE
    $TBGP_BIOSEQUENCE_PROPERTY_SET
    $TBGP_QUERY_OPTION

    $TBGP_IPI_VERSION
    $TBGP_IPI_DATA
    $TBGP_IPI_XREFS
    $TBGP_CELLULAR_LOCATION
    $TBGP_GLYCOSITE
    $TBGP_OBSERVED_PEPTIDE
    $TBGP_OBSERVED_TO_IPI
    $TBGP_OBSERVED_TO_GLYCOSITE
    $TBGP_IDENTIFIED_PEPTIDE
    $TBGP_PREDICTED_PEPTIDE
    $TBGP_PEPTIDE_TO_SAMPLE
    $TBGP_TISSUE_TYPE
    $TBGP_UNIPEP_SAMPLE
    $TBGP_IDENTIFIED_TO_IPI
    $TBGP_SYNTHESIZED_PEPTIDE
    $TBGP_PEPTIDE_SEARCH
    $TBGP_IDENTIFIED_TO_GLYCOSITE
    $TBGP_PREDICTED_TO_GLYCOSITE
    $TBGP_UNIPEP_BUILD
    $TBGP_BUILD_TO_SEARCH
    $TBGP_ORTHOLOG_TO_IPI
);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBGP_BIOSEQUENCE_SET
    $TBGP_DBXREF
    $TBGP_BIOSEQUENCE
    $TBGP_BIOSEQUENCE_PROPERTY_SET
    $TBGP_QUERY_OPTION

    $TBGP_IPI_VERSION
    $TBGP_IPI_XREFS
    $TBGP_IPI_DATA
    $TBGP_CELLULAR_LOCATION
    $TBGP_GLYCOSITE
    $TBGP_IDENTIFIED_PEPTIDE
    $TBGP_OBSERVED_PEPTIDE
    $TBGP_OBSERVED_TO_IPI
    $TBGP_OBSERVED_TO_GLYCOSITE
    $TBGP_PREDICTED_PEPTIDE
    $TBGP_PEPTIDE_TO_SAMPLE
    $TBGP_TISSUE_TYPE
    $TBGP_UNIPEP_SAMPLE
    $TBGP_IDENTIFIED_TO_IPI
    $TBGP_SYNTHESIZED_PEPTIDE
    $TBGP_PEPTIDE_SEARCH
    $TBGP_IDENTIFIED_TO_GLYCOSITE
    $TBGP_PREDICTED_TO_GLYCOSITE
    $TBGP_UNIPEP_BUILD
    $TBGP_BUILD_TO_SEARCH
    $TBGP_ORTHOLOG_TO_IPI
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Glycopeptide};
my $BioLink = $DBPREFIX{BioLink};

$TB_ORGANISM                      = "${core}organism";

$TBGP_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBGP_DBXREF                = "${mod}dbxref";
$TBGP_BIOSEQUENCE           = "${mod}biosequence";
$TBGP_BIOSEQUENCE_PROPERTY_SET   = "${mod}biosequence_property_set";
$TBGP_QUERY_OPTION          = "${mod}query_option";

$TBGP_IPI_VERSION	    	= "${mod}ipi_version";
$TBGP_IPI_XREFS	    	= "${mod}ipi_xrefs";
$TBGP_IPI_DATA			= "${mod}ipi_data";
$TBGP_CELLULAR_LOCATION		= "${mod}cellular_location";
$TBGP_GLYCOSITE		= "${mod}glycosite";
$TBGP_OBSERVED_PEPTIDE	= "${mod}observed_peptide";
$TBGP_OBSERVED_TO_IPI	= "${mod}observed_to_ipi";
$TBGP_OBSERVED_TO_GLYCOSITE	= "${mod}observed_to_glycosite";
$TBGP_IDENTIFIED_PEPTIDE	= "${mod}identified_peptide";
$TBGP_PREDICTED_PEPTIDE		= "${mod}predicted_peptide";
$TBGP_PEPTIDE_TO_SAMPLE		= "${mod}peptide_to_sample";
$TBGP_TISSUE_TYPE			= "${mod}tissue_type";
$TBGP_IDENTIFIED_TO_IPI= "${mod}identified_to_ipi";
$TBGP_UNIPEP_SAMPLE   = "${mod}unipep_sample";
$TBGP_SYNTHESIZED_PEPTIDE	= "${mod}synthesized_peptide";
$TBGP_PEPTIDE_SEARCH			= "${mod}peptide_search";
$TBGP_IDENTIFIED_TO_GLYCOSITE = "${mod}identified_to_glycosite";
$TBGP_PREDICTED_TO_GLYCOSITE = "${mod}predicted_to_glycosite";
$TBGP_UNIPEP_BUILD = "${mod}unipep_build";
$TBGP_BUILD_TO_SEARCH = "${mod}build_to_search";
$TBGP_ORTHOLOG_TO_IPI = "${mod}ortholog_to_ipi";

1;
