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

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_PROTOCOL
    $TB_PROTOCOL_TYPE
    $TB_HARDWARE
    $TB_HARDWARE_TYPE
    $TB_SOFTWARE
    $TB_SOFTWARE_TYPE
    $TBMA_SLIDE_TYPE
    $TBMA_COST_SCHEME
    $TBMA_SLIDE_TYPE_COST
    $TBMA_MISC_OPTION
    $TB_ORGANISM
    $TBMA_LABELING_METHOD
    $TBMA_DYE
    $TBMA_XNA_TYPE
    $TBMA_ARRAY_REQUEST
    $TBMA_ARRAY_REQUEST_SLIDE
    $TBMA_ARRAY_REQUEST_SAMPLE
    $TBMA_SAMPLE_PROTOCOL
    $TBMA_ARRAY_REQUEST_OPTION
    $TBMA_SLIDE_MODEL
    $TBMA_SLIDE_LOT
    $TBMA_SLIDE
    $TBMA_PRINTING_BATCH
    $TBMA_ARRAY_LAYOUT
    $TBMA_ARRAY
    $TBMA_LABELING
    $TBMA_HYBRIDIZATION
    $TBMA_ARRAY_SCAN
    $TBMA_ARRAY_QUANTITATION
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
    $TBMA_SLIDE_TYPE
    $TBMA_COST_SCHEME
    $TBMA_SLIDE_TYPE_COST
    $TBMA_MISC_OPTION
    $TB_ORGANISM
    $TBMA_LABELING_METHOD
    $TBMA_DYE
    $TBMA_XNA_TYPE
    $TBMA_ARRAY_REQUEST
    $TBMA_ARRAY_REQUEST_SLIDE
    $TBMA_ARRAY_REQUEST_SAMPLE
    $TBMA_SAMPLE_PROTOCOL
    $TBMA_ARRAY_REQUEST_OPTION
    $TBMA_SLIDE_MODEL
    $TBMA_SLIDE_LOT
    $TBMA_SLIDE
    $TBMA_PRINTING_BATCH
    $TBMA_ARRAY_LAYOUT
    $TBMA_ARRAY
    $TBMA_LABELING
    $TBMA_HYBRIDIZATION
    $TBMA_ARRAY_SCAN
    $TBMA_ARRAY_QUANTITATION
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


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Microarray};


$TB_ORGANISM            = "${core}organism";

$TB_PROTOCOL            = "${mod}protocol";
$TB_PROTOCOL_TYPE       = "${mod}protocol_type";
$TB_HARDWARE            = "${mod}hardware";
$TB_HARDWARE_TYPE       = "${mod}hardware_type";
$TB_SOFTWARE            = "${mod}software";
$TB_SOFTWARE_TYPE       = "${mod}software_type";
$TBMA_SLIDE_TYPE          = "${mod}slide_type";
$TBMA_COST_SCHEME         = "${mod}cost_scheme";
$TBMA_SLIDE_TYPE_COST     = "${mod}slide_type_cost";
$TBMA_MISC_OPTION         = "${mod}misc_option";
$TBMA_LABELING_METHOD     = "${mod}labeling_method";
$TBMA_DYE                 = "${mod}dye";
$TBMA_XNA_TYPE            = "${mod}xna_type";
$TBMA_ARRAY_REQUEST       = "${mod}array_request";
$TBMA_ARRAY_REQUEST_SLIDE = "${mod}array_request_slide";
$TBMA_ARRAY_REQUEST_SAMPLE= "${mod}array_request_sample";
$TBMA_SAMPLE_PROTOCOL   = "${mod}sample_protocol";
$TBMA_ARRAY_REQUEST_OPTION= "${mod}array_request_option";
$TBMA_SLIDE_MODEL         = "${mod}slide_model";
$TBMA_SLIDE_LOT           = "${mod}slide_lot";
$TBMA_SLIDE               = "${mod}slide";
$TBMA_PRINTING_BATCH      = "${mod}printing_batch";
$TBMA_ARRAY_LAYOUT        = "${mod}array_layout";
$TBMA_ARRAY               = "${mod}array";
$TBMA_LABELING            = "${mod}labeling";
$TBMA_HYBRIDIZATION       = "${mod}hybridization";
$TBMA_ARRAY_SCAN          = "${mod}array_scan";
$TBMA_ARRAY_QUANTITATION  = "${mod}array_quantitation";
$TBMA_BIOSEQUENCE_SET   = "${mod}biosequence_set";
$TBMA_BIOSEQUENCE       = "${mod}biosequence";

$TBMA_BIOSEQUENCE_EXTERNAL_XREF = "${mod}biosequence_external_xref";
$TBMA_EXTERNAL_REFERENCE        = "${mod}external_reference";
$TBMA_EXTERNAL_REFERENCE_TYPE   = "${mod}external_reference_type";
$TBMA_POLYMER_TYPE              = "${mod}polymer_type";
$TBMA_ARRAY_ELEMENT     = "${mod}array_element";
$TBMA_CHANNEL           = "${mod}channel";

$TBMA_SERVER            = "${mod}server";
$TBMA_FILE_PATH         = "${mod}file_path";
$TBMA_FILE_LOCATION     = "${mod}file_location";
$TBMA_FILE_TYPE         = "${mod}file_type";
$TBMA_QUANTITATION_TYPE = "${mod}quantitation_type";

$TBMA_QUERY_OPTION      = "${mod}query_option";
$TBMA_CONDITION         = "${mod}condition";
$TBMA_GENE_EXPRESSION   = "${mod}gene_expression";

