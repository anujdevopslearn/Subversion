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

use SBEAMS::Connection::Settings;


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
    $TBPR_USER_ANNOTATION_LABEL
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
    $TBPR_USER_ANNOTATION_LABEL
    $TBPR_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Proteomics};


$TB_ORGANISM                      = "${core}organism";

$TBPR_BIOSEQUENCE_SET             = "${mod}biosequence_set";
$TBPR_BIOSEQUENCE                 = "${mod}biosequence";

$TBPR_PROTEOMICS_EXPERIMENT       = "${mod}proteomics_experiment";
$TBPR_GRADIENT_PROGRAM            = "${mod}gradient_program";
$TBPR_GRADIENT_DELTA              = "${mod}gradient_delta";
$TBPR_FRACTION                    = "${mod}fraction";
$TBPR_SEARCH_BATCH                = "${mod}search_batch";
$TBPR_SEARCH_BATCH_PARAMETER      = "${mod}search_batch_parameter";
$TBPR_SEARCH_BATCH_PARAMETER_SET  = "${mod}search_batch_parameter_set";
$TBPR_SEARCH                      = "${mod}search";
$TBPR_SEARCH_HIT                  = "${mod}search_hit";
$TBPR_SEARCH_HIT_PROTEIN          = "${mod}search_hit_protein";
$TBPR_QUANTITATION                = "${mod}quantitation";
$TBPR_MSMS_SPECTRUM               = "${mod}msms_spectrum";
$TBPR_MSMS_SPECTRUM_PEAK          = "${mod}msms_spectrum_peak";

$TBPR_SEARCH_HIT_ANNOTATION       = "${mod}search_hit_annotation";
$TBPR_ANNOTATION_LABEL            = "${mod}annotation_label";
$TBPR_ANNOTATION_CONFIDENCE       = "${mod}annotation_confidence";
$TBPR_ANNOTATION_SOURCE           = "${mod}annotation_source";
$TBPR_USER_ANNOTATION_LABEL       = "${mod}user_annotation_label";
$TBPR_QUERY_OPTION                = "${mod}query_option";







