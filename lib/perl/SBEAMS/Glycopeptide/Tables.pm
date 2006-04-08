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
    $TBGP_IPI_XREFS
    $TBGP_IPI_DATA
    $TBGP_CELLULAR_LOCATION
    $TBGP_GLYCO_SITE
    $TBGP_IDENTIFIED_PEPTIDE
    $TBGP_PREDICTED_PEPTIDE
    $TBGP_PEPTIDE_TO_TISSUE
    $TBGP_TISSUE_TYPE
    $TBGP_GLYCO_SAMPLE
    $TBGP_IDENTIFIED_TO_IPI
    $TBGP_SYNTHESIZED_PEPTIDE
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
    $TBGP_GLYCO_SITE
    $TBGP_IDENTIFIED_PEPTIDE
    $TBGP_PREDICTED_PEPTIDE
    $TBGP_PEPTIDE_TO_TISSUE
    $TBGP_TISSUE_TYPE
    $TBGP_GLYCO_SAMPLE
    $TBGP_IDENTIFIED_TO_IPI
    $TBGP_SYNTHESIZED_PEPTIDE
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
$TBGP_GLYCO_SITE		= "${mod}glyco_site";
$TBGP_IDENTIFIED_PEPTIDE	= "${mod}identified_peptide";
$TBGP_PREDICTED_PEPTIDE		= "${mod}predicted_peptide";
$TBGP_PEPTIDE_TO_TISSUE		= "${mod}peptide_to_tissue";
$TBGP_TISSUE_TYPE			= "${mod}tissue_type";
$TBGP_IDENTIFIED_TO_IPI= "${mod}identified_to_ipi";
$TBGP_GLYCO_SAMPLE   = "${mod}glyco_sample";
$TBGP_SYNTHESIZED_PEPTIDE	= "${mod}synthesized_peptide";

1;
