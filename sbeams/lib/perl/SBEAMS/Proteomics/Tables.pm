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

    $TBPR_BIOSEQUENCE_SET
    $TBPR_BIOSEQUENCE

    $TBPR_PROTEOMICS_EXPERIMENT
    $TBPR_GRADIENT_PROGRAM
    $TBPR_GRADIENT_DELTA
    $TBPR_FRACTION
    $TBPR_SEARCH_BATCH
    $TBPR_SEARCH_BATCH_PARAMETER
    $TBPR_SEARCH_BATCH_PARAMETER_SET
    $TBPR_SEARCH
    $TBPR_SEARCH_HIT
    $TBPR_SEARCH_HIT_PROTEIN
    $TBPR_QUANTITATION
    $TBPR_MSMS_SPECTRUM
    $TBPR_MSMS_SPECTRUM_PEAK

    $TBPR_SEARCH_HIT_ANNOTATION
    $TBPR_ANNOTATION_LABEL
    $TBPR_ANNOTATION_CONFIDENCE
    $TBPR_ANNOTATION_SOURCE
    $TBPR_QUERY_OPTION

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBPR_BIOSEQUENCE_SET
    $TBPR_BIOSEQUENCE

    $TBPR_PROTEOMICS_EXPERIMENT
    $TBPR_GRADIENT_PROGRAM
    $TBPR_GRADIENT_DELTA
    $TBPR_FRACTION
    $TBPR_SEARCH_BATCH
    $TBPR_SEARCH_BATCH_PARAMETER
    $TBPR_SEARCH_BATCH_PARAMETER_SET
    $TBPR_SEARCH
    $TBPR_SEARCH_HIT
    $TBPR_SEARCH_HIT_PROTEIN
    $TBPR_QUANTITATION
    $TBPR_MSMS_SPECTRUM
    $TBPR_MSMS_SPECTRUM_PEAK

    $TBPR_SEARCH_HIT_ANNOTATION
    $TBPR_ANNOTATION_LABEL
    $TBPR_ANNOTATION_CONFIDENCE
    $TBPR_ANNOTATION_SOURCE
    $TBPR_QUERY_OPTION

);


$TB_ORGANISM                  = 'sbeams.dbo.organism';

$TBPR_BIOSEQUENCE_SET         = 'proteomics.dbo.biosequence_set';
$TBPR_BIOSEQUENCE             = 'proteomics.dbo.biosequence';

$TBPR_PROTEOMICS_EXPERIMENT   = 'proteomics.dbo.proteomics_experiment';
$TBPR_GRADIENT_PROGRAM        = 'proteomics.dbo.gradient_program';
$TBPR_GRADIENT_DELTA          = 'proteomics.dbo.gradient_delta';
$TBPR_FRACTION                = 'proteomics.dbo.fraction';
$TBPR_SEARCH_BATCH            = 'proteomics.dbo.search_batch';
$TBPR_SEARCH_BATCH_PARAMETER  = 'proteomics.dbo.search_batch_parameter';
$TBPR_SEARCH_BATCH_PARAMETER_SET  = 'proteomics.dbo.search_batch_parameter_set';
$TBPR_SEARCH                  = 'proteomics.dbo.search';
$TBPR_SEARCH_HIT              = 'proteomics.dbo.search_hit';
$TBPR_SEARCH_HIT_PROTEIN      = 'proteomics.dbo.search_hit_protein';
$TBPR_QUANTITATION            = 'proteomics.dbo.quantitation';
$TBPR_MSMS_SPECTRUM           = 'proteomics.dbo.msms_spectrum';
$TBPR_MSMS_SPECTRUM_PEAK      = 'proteomics.dbo.msms_spectrum_peak';

$TBPR_SEARCH_HIT_ANNOTATION  = 'proteomics.dbo.search_hit_annotation';
$TBPR_ANNOTATION_LABEL       = 'proteomics.dbo.annotation_label';
$TBPR_ANNOTATION_CONFIDENCE  = 'proteomics.dbo.annotation_confidence';
$TBPR_ANNOTATION_SOURCE      = 'proteomics.dbo.annotation_source';
$TBPR_QUERY_OPTION           = 'proteomics.dbo.query_option';







