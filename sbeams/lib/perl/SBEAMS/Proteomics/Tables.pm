package SBEAMS::Proteomics::Tables;

###############################################################################
# Program     : SBEAMS::Proteomics::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which provides
#               a level of abstraction to the database tables.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBPR_BIOSEQUENCE_SET
    $TBPR_BIOSEQUENCE
    $TBPR_BIOSEQUENCE_PROPERTY_SET

    $TBPR_PROTEOMICS_EXPERIMENT
    $TBPR_GRADIENT_PROGRAM
    $TBPR_GRADIENT_DELTA
    $TBPR_FRACTIONATION_TYPE
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
    $TBAPD_PEPTIDE_IDENTIFIER
    $TBAPD_PEPTIDE
    $TBAPD_MODIFIED_PEPTIDE
    $TBAPD_MODIFIED_PEPTIDE_PROPERTY
    $TBAPD_PEPTIDE_PROPERTY_TYPE

    $TBPR_POSSIBLE_PEPTIDE

    $TBPR_PUBLICATION_CATEGORY
    $TBPR_PUBLICATION_RATING
    $TBPR_PUBLICATION

    $TBPR_SEARCH_BATCH_PROTEIN_SUMMARY
    $TBPR_PROTEIN_SUMMARY
    $TBPR_PROTEIN_SUMMARY_HEADER
    $TBPR_PROTEIN_SUMMARY_DATA_FILTER
    $TBPR_PROTEIN_GROUP
    $TBPR_PROTEIN
    $TBPR_INDISTINGUISHABLE_PROTEIN
    $TBPR_PEPTIDE
    $TBPR_PEPTIDE_PARENT_PROTEIN
    $TBPR_INDISTINGUISHABLE_PEPTIDE
    $TBPR_SUMMARY_QUANTITATION

    $TBBL_GENE_ANNOTATION
    $TBPR_BIOSEQUENCE_ANNOTATED_GENE

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBPR_BIOSEQUENCE_SET
    $TBPR_BIOSEQUENCE
    $TBPR_BIOSEQUENCE_PROPERTY_SET

    $TBPR_PROTEOMICS_EXPERIMENT
    $TBPR_GRADIENT_PROGRAM
    $TBPR_GRADIENT_DELTA
    $TBPR_FRACTIONATION_TYPE
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
    $TBAPD_PEPTIDE_IDENTIFIER
    $TBAPD_PEPTIDE
    $TBAPD_MODIFIED_PEPTIDE
    $TBAPD_MODIFIED_PEPTIDE_PROPERTY
    $TBAPD_PEPTIDE_PROPERTY_TYPE

    $TBPR_POSSIBLE_PEPTIDE

    $TBPR_PUBLICATION_CATEGORY
    $TBPR_PUBLICATION_RATING
    $TBPR_PUBLICATION

    $TBPR_SEARCH_BATCH_PROTEIN_SUMMARY
    $TBPR_PROTEIN_SUMMARY
    $TBPR_PROTEIN_SUMMARY_HEADER
    $TBPR_PROTEIN_SUMMARY_DATA_FILTER
    $TBPR_PROTEIN_GROUP
    $TBPR_PROTEIN
    $TBPR_INDISTINGUISHABLE_PROTEIN
    $TBPR_PEPTIDE
    $TBPR_PEPTIDE_PARENT_PROTEIN
    $TBPR_INDISTINGUISHABLE_PEPTIDE
    $TBPR_SUMMARY_QUANTITATION

    $TBBL_GENE_ANNOTATION
    $TBPR_BIOSEQUENCE_ANNOTATED_GENE

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Proteomics};
my $APD = $DBPREFIX{APD};
my $BioLink = $DBPREFIX{BioLink};


$TB_ORGANISM                      = "${core}organism";

$TBPR_BIOSEQUENCE_SET             = "${mod}biosequence_set";
$TBPR_BIOSEQUENCE                 = "${mod}biosequence";
$TBPR_BIOSEQUENCE_PROPERTY_SET    = "${mod}biosequence_property_set";

$TBPR_PROTEOMICS_EXPERIMENT       = "${mod}proteomics_experiment";
$TBPR_GRADIENT_PROGRAM            = "${mod}gradient_program";
$TBPR_GRADIENT_DELTA              = "${mod}gradient_delta";
$TBPR_FRACTIONATION_TYPE          = "${mod}fractionation_type";
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

$TBAPD_PEPTIDE_SUMMARY            = "${APD}peptide_summary";
$TBAPD_PEPTIDE_SUMMARY_EXPERIMENT = "${APD}peptide_summary_experiment";
$TBAPD_PEPTIDE_IDENTIFIER         = "${APD}peptide_identifier";
$TBAPD_PEPTIDE                    = "${APD}peptide";
$TBAPD_MODIFIED_PEPTIDE           = "${APD}modified_peptide";
$TBAPD_MODIFIED_PEPTIDE_PROPERTY  = "${APD}modified_peptide_property";
$TBAPD_PEPTIDE_PROPERTY_TYPE      = "${APD}peptide_property_type";

$TBPR_POSSIBLE_PEPTIDE            = "${mod}possible_peptide";

$TBPR_PUBLICATION_CATEGORY        = "${mod}publication_category";
$TBPR_PUBLICATION_RATING          = "${mod}publication_rating";
$TBPR_PUBLICATION                 = "${mod}publication";

$TBPR_SEARCH_BATCH_PROTEIN_SUMMARY= "${mod}search_batch_protein_summary";
$TBPR_PROTEIN_SUMMARY             = "${mod}protein_summary";
$TBPR_PROTEIN_SUMMARY_HEADER      = "${mod}protein_summary_header";
$TBPR_PROTEIN_SUMMARY_DATA_FILTER = "${mod}protein_summary_data_filter";
$TBPR_PROTEIN_GROUP               = "${mod}protein_group";
$TBPR_PROTEIN                     = "${mod}protein";
$TBPR_INDISTINGUISHABLE_PROTEIN   = "${mod}indistinguishable_protein";
$TBPR_PEPTIDE                     = "${mod}peptide";
$TBPR_PEPTIDE_PARENT_PROTEIN      = "${mod}peptide_parent_protein";
$TBPR_INDISTINGUISHABLE_PEPTIDE   = "${mod}indistinguishable_peptide";
$TBPR_SUMMARY_QUANTITATION        = "${mod}summary_quantitation";

$TBBL_GENE_ANNOTATION             = "${BioLink}gene_annotation";
$TBPR_BIOSEQUENCE_ANNOTATED_GENE  = "${mod}biosequence_annotated_gene";



