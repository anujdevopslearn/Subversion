package SBEAMS::Inkjet::Tables;

###############################################################################
# Program     : SBEAMS::Inkjet::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Inkjet module which provides
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

    $TBIJ_SLIDE_TYPE
    $TBIJ_COST_SCHEME
    $TBIJ_SLIDE_TYPE_COST

    $TBIJ_MISC_OPTION
    $TBIJ_QUERY_OPTION
    $TBIJ_LABELING_METHOD
    $TBIJ_DYE
    $TBIJ_XNA_TYPE

    $TBIJ_ARRAY_REQUEST
    $TBIJ_ARRAY_REQUEST_SLIDE
    $TBIJ_ARRAY_REQUEST_SAMPLE
    $TBIJ_SAMPLE_PROTOCOL
    $TBIJ_ARRAY_REQUEST_OPTION

    $TBIJ_SLIDE_MODEL
    $TBIJ_SLIDE_LOT
    $TBIJ_SLIDE
    $TBIJ_PRINTING_BATCH
    $TBIJ_ARRAY_LAYOUT
    $TBIJ_ARRAY
    $TBIJ_LABELING
    $TBIJ_HYBRIDIZATION
    $TBIJ_ARRAY_SCAN
    $TBIJ_ARRAY_QUANTITATION

    $TBIJ_BIOSEQUENCE_SET
    $TBIJ_BIOSEQUENCE
    $TBIJ_BIOSEQUENCE_EXTERNAL_XREF
    $TBIJ_EXTERNAL_REFERENCE
    $TBIJ_EXTERNAL_REFERENCE_TYPE
    $TBIJ_POLYMER_TYPE
    $TBIJ_ARRAY_ELEMENT
    $TBIJ_CHANNEL

    $TBIJ_SERVER
    $TBIJ_FILE_PATH
    $TBIJ_FILE_LOCATION
    $TBIJ_FILE_TYPE
    $TBIJ_QUANTITATION_TYPE

    $TBIJ_CONDITION
    $TBIJ_GENE_EXPRESSION
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

    $TBIJ_SLIDE_TYPE
    $TBIJ_COST_SCHEME
    $TBIJ_SLIDE_TYPE_COST

    $TBIJ_MISC_OPTION
    $TBIJ_QUERY_OPTION
    $TBIJ_LABELING_METHOD
    $TBIJ_DYE
    $TBIJ_XNA_TYPE

    $TBIJ_ARRAY_REQUEST
    $TBIJ_ARRAY_REQUEST_SLIDE
    $TBIJ_ARRAY_REQUEST_SAMPLE
    $TBIJ_SAMPLE_PROTOCOL
    $TBIJ_ARRAY_REQUEST_OPTION

    $TBIJ_SLIDE_MODEL
    $TBIJ_SLIDE_LOT
    $TBIJ_SLIDE
    $TBIJ_PRINTING_BATCH
    $TBIJ_ARRAY_LAYOUT
    $TBIJ_ARRAY
    $TBIJ_LABELING
    $TBIJ_HYBRIDIZATION
    $TBIJ_ARRAY_SCAN
    $TBIJ_ARRAY_QUANTITATION

    $TBIJ_BIOSEQUENCE_SET
    $TBIJ_BIOSEQUENCE
    $TBIJ_BIOSEQUENCE_EXTERNAL_XREF
    $TBIJ_EXTERNAL_REFERENCE
    $TBIJ_EXTERNAL_REFERENCE_TYPE
    $TBIJ_POLYMER_TYPE
    $TBIJ_ARRAY_ELEMENT
    $TBIJ_CHANNEL

    $TBIJ_SERVER
    $TBIJ_FILE_PATH
    $TBIJ_FILE_LOCATION
    $TBIJ_FILE_TYPE
    $TBIJ_QUANTITATION_TYPE

    $TBIJ_CONDITION
    $TBIJ_GENE_EXPRESSION
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Inkjet};
#### Fudge to allow hard-coding to this module resistant to search and replace
my $modMARR = $DBPREFIX{'M'.'icroarray'};


$TB_ORGANISM              = "${core}organism";
$TB_PROTOCOL              = "${mod}protocol";
$TB_PROTOCOL_TYPE         = "${mod}protocol_type";
$TB_HARDWARE              = "${core}hardware";
$TB_HARDWARE_TYPE         = "${core}hardware_type";
$TB_SOFTWARE              = "${core}software";
$TB_SOFTWARE_TYPE         = "${core}software_type";

$TBIJ_SLIDE_TYPE          = "${mod}slide_type";
$TBIJ_COST_SCHEME         = "${mod}cost_scheme";
$TBIJ_SLIDE_TYPE_COST     = "${mod}slide_type_cost";

$TBIJ_MISC_OPTION         = "${modMARR}misc_option";
$TBIJ_QUERY_OPTION        = "${modMARR}query_option";
$TBIJ_LABELING_METHOD     = "${modMARR}labeling_method";
$TBIJ_DYE                 = "${modMARR}dye";
$TBIJ_XNA_TYPE            = "${modMARR}xna_type";

$TBIJ_ARRAY_REQUEST       = "${mod}array_request";
$TBIJ_ARRAY_REQUEST_SLIDE = "${mod}array_request_slide";
$TBIJ_ARRAY_REQUEST_SAMPLE= "${mod}array_request_sample";
$TBIJ_SAMPLE_PROTOCOL     = "${mod}sample_protocol";
$TBIJ_ARRAY_REQUEST_OPTION= "${modMARR}array_request_option";

$TBIJ_SLIDE_MODEL         = "${mod}slide_model";
$TBIJ_SLIDE_LOT           = "${mod}slide_lot";
$TBIJ_SLIDE               = "${mod}slide";
$TBIJ_PRINTING_BATCH      = "${mod}printing_batch";
$TBIJ_ARRAY_LAYOUT        = "${mod}array_layout";
$TBIJ_ARRAY_ELEMENT       = "${mod}array_element";
$TBIJ_ARRAY               = "${mod}array";
$TBIJ_LABELING            = "${mod}labeling";
$TBIJ_HYBRIDIZATION       = "${mod}hybridization";
$TBIJ_ARRAY_SCAN          = "${mod}array_scan";
$TBIJ_ARRAY_QUANTITATION  = "${mod}array_quantitation";

$TBIJ_BIOSEQUENCE_SET     = "${modMARR}biosequence_set";
$TBIJ_BIOSEQUENCE         = "${modMARR}biosequence";
$TBIJ_BIOSEQUENCE_EXTERNAL_XREF = "${modMARR}biosequence_external_xref";
$TBIJ_EXTERNAL_REFERENCE        = "${modMARR}external_reference";
$TBIJ_EXTERNAL_REFERENCE_TYPE   = "${modMARR}external_reference_type";
$TBIJ_POLYMER_TYPE              = "${modMARR}polymer_type";
$TBIJ_CHANNEL                   = "${modMARR}channel";

$TBIJ_SERVER              = "${modMARR}server";
$TBIJ_FILE_PATH           = "${modMARR}file_path";
$TBIJ_FILE_LOCATION       = "${modMARR}file_location";
$TBIJ_FILE_TYPE           = "${modMARR}file_type";
$TBIJ_QUANTITATION_TYPE   = "${modMARR}quantitation_type";

$TBIJ_CONDITION           = "${mod}condition";
$TBIJ_GENE_EXPRESSION     = "${mod}gene_expression";

