package SBEAMS::Proteomics::Tables;

###############################################################################
# Program     : SBEAMS::Proteomics::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TB_BIOSEQUENCE_SET
    $TB_BIOSEQUENCE
    $TB_PROTEOMICS_EXPERIMENT
    $TB_FRACTION
    $TB_SEARCH_BATCH
    $TB_SEARCH_BATCH_PARAMETER
    $TB_SEARCH_BATCH_PARAMETER_SET
    $TB_SEARCH
    $TB_SEARCH_HIT
    $TB_SEARCH_PROTEIN
    $TB_ICAT_QUANTITATION
    $TB_MSMS_SCAN
    $TB_MSMS_SPECTRUM_PEAK

    $TB_SEARCH_HIT_ANNOTATION
    $TBPR_ANNOTATION_LABEL
    $TBPR_ANNOTATION_CONFIDENCE
    $TBPR_ANNOTATION_SOURCE
    $TBPR_QUERY_OPTION

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TB_BIOSEQUENCE_SET
    $TB_BIOSEQUENCE
    $TB_PROTEOMICS_EXPERIMENT
    $TB_FRACTION
    $TB_SEARCH_BATCH
    $TB_SEARCH_BATCH_PARAMETER
    $TB_SEARCH_BATCH_PARAMETER_SET
    $TB_SEARCH
    $TB_SEARCH_HIT
    $TB_SEARCH_PROTEIN
    $TB_ICAT_QUANTITATION
    $TB_MSMS_SCAN
    $TB_MSMS_SPECTRUM_PEAK

    $TB_SEARCH_HIT_ANNOTATION
    $TBPR_ANNOTATION_LABEL
    $TBPR_ANNOTATION_CONFIDENCE
    $TBPR_ANNOTATION_SOURCE
    $TBPR_QUERY_OPTION

);


$TB_ORGANISM                = 'sbeams.dbo.organism';

$TB_BIOSEQUENCE_SET         = 'proteomics.dbo.biosequence_set';
$TB_BIOSEQUENCE             = 'proteomics.dbo.biosequence';
$TB_PROTEOMICS_EXPERIMENT   = 'proteomics.dbo.proteomics_experiment';
$TB_FRACTION                = 'proteomics.dbo.fraction';
$TB_SEARCH_BATCH            = 'proteomics.dbo.search_batch';
$TB_SEARCH_BATCH_PARAMETER  = 'proteomics.dbo.search_batch_parameter';
$TB_SEARCH_BATCH_PARAMETER_SET  = 'proteomics.dbo.search_batch_parameter_set';
$TB_SEARCH                  = 'proteomics.dbo.search';
$TB_SEARCH_HIT              = 'proteomics.dbo.search_hit';
$TB_SEARCH_HIT_PROTEIN      = 'proteomics.dbo.search_hit_protein';
$TB_ICAT_QUANTITATION       = 'proteomics.dbo.ICAT_quantitation';
$TB_MSMS_SCAN               = 'proteomics.dbo.msms_scan';
$TB_MSMS_SPECTRUM_PEAK      = 'proteomics.dbo.msms_spectrum_peak';

$TB_SEARCH_HIT_ANNOTATION  = 'proteomics.dbo.search_hit_annotation';
$TBPR_ANNOTATION_LABEL     = 'proteomics.dbo.annotation_label';
$TBPR_ANNOTATION_CONFIDENCE= 'proteomics.dbo.annotation_confidence';
$TBPR_ANNOTATION_SOURCE    = 'proteomics.dbo.annotation_source';
$TBPR_QUERY_OPTION         = 'proteomics.dbo.query_option';







