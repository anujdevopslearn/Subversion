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
    $TB_ORGANISM
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
    $TBMA_QUERY_OPTION
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

    $TBMA_CONDITION
    $TBMA_GENE_EXPRESSION
    
    $TBMA_AFFY_ARRAY_SAMPLE
    $TBMA_AFFY_ARRAY
    $TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL
    $TBMA_AFFY_ARRAY_PROTOCOL
);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
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
    $TBMA_QUERY_OPTION
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

    $TBMA_CONDITION
    $TBMA_GENE_EXPRESSION

    $TBMA_AFFY_ARRAY_SAMPLE
    $TBMA_AFFY_ARRAY
    $TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL
    $TBMA_AFFY_ARRAY_PROTOCOL
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Microarray};
#### Fudge to allow hard-coding to this module resistant to search and replace
my $modMARR = $DBPREFIX{'M'.'icroarray'};


$TB_ORGANISM              = "${core}organism";
$TB_PROTOCOL              = "${core}protocol";
$TB_PROTOCOL_TYPE         = "${core}protocol_type";
$TB_HARDWARE              = "${core}hardware";
$TB_HARDWARE_TYPE         = "${core}hardware_type";
$TB_SOFTWARE              = "${core}software";
$TB_SOFTWARE_TYPE         = "${core}software_type";

$TBMA_SLIDE_TYPE          = "${mod}slide_type";
$TBMA_COST_SCHEME         = "${mod}cost_scheme";
$TBMA_SLIDE_TYPE_COST     = "${mod}slide_type_cost";

$TBMA_MISC_OPTION         = "${modMARR}misc_option";
$TBMA_QUERY_OPTION        = "${modMARR}query_option";
$TBMA_LABELING_METHOD     = "${modMARR}labeling_method";
$TBMA_DYE                 = "${modMARR}dye";
$TBMA_XNA_TYPE            = "${modMARR}xna_type";

$TBMA_ARRAY_REQUEST       = "${mod}array_request";
$TBMA_ARRAY_REQUEST_SLIDE = "${mod}array_request_slide";
$TBMA_ARRAY_REQUEST_SAMPLE= "${mod}array_request_sample";
$TBMA_SAMPLE_PROTOCOL     = "${mod}sample_protocol";
$TBMA_ARRAY_REQUEST_OPTION= "${modMARR}array_request_option";

$TBMA_SLIDE_MODEL         = "${mod}slide_model";
$TBMA_SLIDE_LOT           = "${mod}slide_lot";
$TBMA_SLIDE               = "${mod}slide";
$TBMA_PRINTING_BATCH      = "${mod}printing_batch";
$TBMA_ARRAY_LAYOUT        = "${mod}array_layout";
$TBMA_ARRAY_ELEMENT       = "${mod}array_element";
$TBMA_ARRAY               = "${mod}array";
$TBMA_LABELING            = "${mod}labeling";
$TBMA_HYBRIDIZATION       = "${mod}hybridization";
$TBMA_ARRAY_SCAN          = "${mod}array_scan";
$TBMA_ARRAY_QUANTITATION  = "${mod}array_quantitation";

$TBMA_BIOSEQUENCE_SET     = "${modMARR}biosequence_set";
$TBMA_BIOSEQUENCE         = "${modMARR}biosequence";
$TBMA_BIOSEQUENCE_EXTERNAL_XREF = "${modMARR}biosequence_external_xref";
$TBMA_EXTERNAL_REFERENCE        = "${modMARR}external_reference";
$TBMA_EXTERNAL_REFERENCE_TYPE   = "${modMARR}external_reference_type";
$TBMA_POLYMER_TYPE              = "${modMARR}polymer_type";
$TBMA_CHANNEL                   = "${modMARR}channel";

$TBMA_SERVER              = "${modMARR}server";
$TBMA_FILE_PATH           = "${modMARR}file_path";
$TBMA_FILE_LOCATION       = "${modMARR}file_location";
$TBMA_FILE_TYPE           = "${modMARR}file_type";
$TBMA_QUANTITATION_TYPE   = "${modMARR}quantitation_type";

$TBMA_CONDITION           = "${mod}condition";
$TBMA_GENE_EXPRESSION     = "${mod}gene_expression";

$TBMA_AFFY_ARRAY_SAMPLE	  = "${mod}affy_array_sample";
$TBMA_AFFY_ARRAY	  = "${mod}affy_array";

$TBMA_AFFY_ARRAY_SAMPLE_PROTOCOL = "${mod}affy_array_sample_protocol";
$TBMA_AFFY_ARRAY_PROTOCOL	= "${mod}affy_array_protocol";


1;
