package SBEAMS::Microarray::Tables;

###############################################################################
# Program     : SBEAMS::Microarray::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Microarray module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_PROTOCOL
    $TB_PROTOCOL_TYPE
    $TB_HARDWARE
    $TB_HARDWARE_TYPE
    $TB_SOFTWARE
    $TB_SOFTWARE_TYPE
    $TB_SLIDE_TYPE
    $TB_COST_SCHEME
    $TB_SLIDE_TYPE_COST
    $TB_MISC_OPTION
    $TB_ORGANISM
    $TB_LABELING_METHOD
    $TB_DYE
    $TB_XNA_TYPE
    $TB_ARRAY_REQUEST
    $TB_ARRAY_REQUEST_SLIDE
    $TB_ARRAY_REQUEST_SAMPLE
    $TB_ARRAY_REQUEST_OPTION
    $TB_SLIDE_MODEL
    $TB_SLIDE_LOT
    $TB_SLIDE
    $TB_PRINTING_BATCH
    $TB_ARRAY_LAYOUT
    $TB_ARRAY
    $TB_LABELING
    $TB_HYBRIDIZATION
    $TB_ARRAY_SCAN
    $TB_ARRAY_QUANTITATION
    $TBMA_BIOSEQUENCE_SET
    $TBMA_BIOSEQUENCE
    $TBMA_BIOSEQUENCE_EXTERNAL_XREF
    $TBMA_EXTERNAL_REFERENCE
    $TBMA_EXTERNAL_REFERENCE_TYPE
    $TBMA_POLYMER_TYPE
    $TBMA_ARRAY_ELEMENT
    $TBMA_CHANNEL
    $TBMA_SERVER
    $TBMA_FILE_PATH
    $TBMA_FILE_LOCATION
    $TBMA_FILE_TYPE
    $TBMA_QUANTITATION_TYPE

    $TBMA_QUERY_OPTION
    $TBMA_CONDITION
    $TBMA_GENE_EXPRESSION
);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_PROTOCOL
    $TB_PROTOCOL_TYPE
    $TB_HARDWARE
    $TB_HARDWARE_TYPE
    $TB_SOFTWARE
    $TB_SOFTWARE_TYPE
    $TB_SLIDE_TYPE
    $TB_COST_SCHEME
    $TB_SLIDE_TYPE_COST
    $TB_MISC_OPTION
    $TB_ORGANISM
    $TB_LABELING_METHOD
    $TB_DYE
    $TB_XNA_TYPE
    $TB_ARRAY_REQUEST
    $TB_ARRAY_REQUEST_SLIDE
    $TB_ARRAY_REQUEST_SAMPLE
    $TB_ARRAY_REQUEST_OPTION
    $TB_SLIDE_MODEL
    $TB_SLIDE_LOT
    $TB_SLIDE
    $TB_PRINTING_BATCH
    $TB_ARRAY_LAYOUT
    $TB_ARRAY
    $TB_LABELING
    $TB_HYBRIDIZATION
    $TB_ARRAY_SCAN
    $TB_ARRAY_QUANTITATION
    $TBMA_BIOSEQUENCE_SET
    $TBMA_BIOSEQUENCE
    $TBMA_BIOSEQUENCE_EXTERNAL_XREF
    $TBMA_EXTERNAL_REFERENCE
    $TBMA_EXTERNAL_REFERENCE_TYPE
    $TBMA_POLYMER_TYPE
    $TBMA_ARRAY_ELEMENT
    $TBMA_CHANNEL
    $TBMA_SERVER
    $TBMA_FILE_PATH
    $TBMA_FILE_LOCATION
    $TBMA_FILE_TYPE
    $TBMA_QUANTITATION_TYPE

    $TBMA_QUERY_OPTION
    $TBMA_CONDITION
    $TBMA_GENE_EXPRESSION
);


$TB_PROTOCOL            = 'protocol';
$TB_PROTOCOL_TYPE       = 'protocol_type';
$TB_HARDWARE            = 'hardware';
$TB_HARDWARE_TYPE       = 'hardware_type';
$TB_SOFTWARE            = 'software';
$TB_SOFTWARE_TYPE       = 'software_type';
$TB_SLIDE_TYPE          = 'slide_type';
$TB_COST_SCHEME         = 'cost_scheme';
$TB_SLIDE_TYPE_COST     = 'slide_type_cost';
$TB_MISC_OPTION         = 'misc_option';
$TB_ORGANISM            = 'organism';
$TB_LABELING_METHOD     = 'labeling_method';
$TB_DYE                 = 'arrays.dbo.dye';
$TB_XNA_TYPE            = 'xna_type';
$TB_ARRAY_REQUEST       = 'array_request';
$TB_ARRAY_REQUEST_SLIDE = 'array_request_slide';
$TB_ARRAY_REQUEST_SAMPLE= 'array_request_sample';
$TB_ARRAY_REQUEST_OPTION= 'array_request_option';
$TB_SLIDE_MODEL         = 'slide_model';
$TB_SLIDE_LOT           = 'slide_lot';
$TB_SLIDE               = 'slide';
$TB_PRINTING_BATCH      = 'printing_batch';
$TB_ARRAY_LAYOUT        = 'array_layout';
$TB_ARRAY               = 'array';
$TB_LABELING            = 'labeling';
$TB_HYBRIDIZATION       = 'hybridization';
$TB_ARRAY_SCAN          = 'array_scan';
$TB_ARRAY_QUANTITATION  = 'array_quantitation';
$TBMA_BIOSEQUENCE_SET   = 'biosequence_set';
$TBMA_BIOSEQUENCE       = 'biosequence';
$TBMA_BIOSEQUENCE_EXTERNAL_XREF = 'biosequence_external_xref';
$TBMA_EXTERNAL_REFERENCE = 'external_reference';
$TBMA_EXTERNAL_REFERENCE_TYPE = 'external_reference_type';
$TBMA_POLYMER_TYPE      = 'polymer_type';
$TBMA_ARRAY_ELEMENT     = 'array_element';
$TBMA_CHANNEL = 'channel';
$TBMA_SERVER='server';
$TBMA_FILE_PATH='file_path';
$TBMA_FILE_LOCATION='file_location';
$TBMA_FILE_TYPE='file_type';
$TBMA_QUANTITATION_TYPE='quantitation_type';

$TBMA_QUERY_OPTION      = "query_option";
$TBMA_CONDITION         = "condition";
$TBMA_GENE_EXPRESSION   = "gene_expression";

