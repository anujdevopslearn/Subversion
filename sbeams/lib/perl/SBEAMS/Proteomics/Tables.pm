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

    $TBPR_PROTEOMICS_EXPERIMENT_REQUEST
    $TBPR_EXPERIMENT_TYPE
    $TBPR_INSTRUMENT_TYPE
    $TBPR_INSTRUMENT
    $TBPR_REQUEST_STATUS
    $TBPR_FUNDING_STATUS

    $TBPR_PROCESSING_STATUS
    $TBPR_RAW_DATA_FILE

    $TBAPD_PEPTIDE_SUMMARY
    $TBAPD_PEPTIDE_SUMMARY_EXPERIMENT
    $TBAPD_PEPTIDE
    $TBAPD_MODIFIED_PEPTIDE
    $TBAPD_MODIFIED_PEPTIDE_PROPERTY
    $TBAPD_PEPTIDE_PROPERTY_TYPE

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

    $TBPR_PROTEOMICS_EXPERIMENT_REQUEST
    $TBPR_EXPERIMENT_TYPE
    $TBPR_INSTRUMENT_TYPE
    $TBPR_INSTRUMENT
    $TBPR_REQUEST_STATUS
    $TBPR_FUNDING_STATUS

    $TBPR_PROCESSING_STATUS
    $TBPR_RAW_DATA_FILE

    $TBAPD_PEPTIDE_SUMMARY
    $TBAPD_PEPTIDE_SUMMARY_EXPERIMENT
    $TBAPD_PEPTIDE
    $TBAPD_MODIFIED_PEPTIDE
    $TBAPD_MODIFIED_PEPTIDE_PROPERTY
    $TBAPD_PEPTIDE_PROPERTY_TYPE

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

$TBPR_PROTEOMICS_EXPERIMENT_REQUEST  = "${mod}proteomics_experiment_request";
$TBPR_EXPERIMENT_TYPE             = "${mod}experiment_type";
$TBPR_INSTRUMENT_TYPE             = "${mod}instrument_type";
$TBPR_INSTRUMENT                  = "${mod}instrument";
$TBPR_REQUEST_STATUS              = "${mod}request_status";
$TBPR_FUNDING_STATUS              = "${mod}funding_status";

$TBPR_PROCESSING_STATUS           = "${mod}processing_status";
$TBPR_RAW_DATA_FILE               = "${mod}raw_data_file";

$TBAPD_PEPTIDE_SUMMARY            = "APD.dbo.peptide_summary";
$TBAPD_PEPTIDE_SUMMARY_EXPERIMENT = "APD.dbo.peptide_summary_experiment";
$TBAPD_PEPTIDE                    = "APD.dbo.peptide";
$TBAPD_MODIFIED_PEPTIDE           = "APD.dbo.modified_peptide";
$TBAPD_MODIFIED_PEPTIDE_PROPERTY  = "APD.dbo.modified_peptide_property";
$TBAPD_PEPTIDE_PROPERTY_TYPE      = "APD.dbo.peptide_property_type";



