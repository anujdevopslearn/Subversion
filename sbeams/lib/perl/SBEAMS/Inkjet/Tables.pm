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
use vars qw(@ISA @EXPORT 
    $TB_MISC_OPTION
    $TB_ORGANISM

    $TBIJ_PROTOCOL
    $TBIJ_PROTOCOL_TYPE
    $TBIJ_HARDWARE
    $TBIJ_HARDWARE_TYPE
    $TBIJ_SOFTWARE
    $TBIJ_SOFTWARE_TYPE
    $TBIJ_SLIDE_TYPE
    $TBIJ_COST_SCHEME
    $TBIJ_SLIDE_TYPE_COST
    $TBIJ_LABELING_METHOD
    $TBIJ_MISC_OPTION
    $TBIJ_DYE
    $TBIJ_XNA_TYPE
    $TBIJ_ARRAY_REQUEST
    $TBIJ_ARRAY_REQUEST_SLIDE
    $TBIJ_ARRAY_REQUEST_SAMPLE
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

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_MISC_OPTION
    $TB_ORGANISM

    $TBIJ_PROTOCOL
    $TBIJ_PROTOCOL_TYPE
    $TBIJ_HARDWARE
    $TBIJ_HARDWARE_TYPE
    $TBIJ_SOFTWARE
    $TBIJ_SOFTWARE_TYPE
    $TBIJ_SLIDE_TYPE
    $TBIJ_COST_SCHEME
    $TBIJ_SLIDE_TYPE_COST
    $TBIJ_LABELING_METHOD
    $TBIJ_MISC_OPTION
    $TBIJ_DYE
    $TBIJ_XNA_TYPE
    $TBIJ_ARRAY_REQUEST
    $TBIJ_ARRAY_REQUEST_SLIDE
    $TBIJ_ARRAY_REQUEST_SAMPLE
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

);


$TB_MISC_OPTION              = 'sbeams.dbo.misc_option';
$TB_ORGANISM                 = 'sbeams.dbo.organism';

$TBIJ_PROTOCOL               = 'inkjet.dbo.protocol';
$TBIJ_PROTOCOL_TYPE          = 'inkjet.dbo.protocol_type';
$TBIJ_HARDWARE               = 'inkjet.dbo.hardware';
$TBIJ_HARDWARE_TYPE          = 'inkjet.dbo.hardware_type';
$TBIJ_SOFTWARE               = 'inkjet.dbo.software';
$TBIJ_SOFTWARE_TYPE          = 'inkjet.dbo.software_type';
$TBIJ_SLIDE_TYPE             = 'inkjet.dbo.slide_type';
$TBIJ_COST_SCHEME            = 'inkjet.dbo.cost_scheme';
$TBIJ_SLIDE_TYPE_COST        = 'inkjet.dbo.slide_type_cost';
$TBIJ_LABELING_METHOD        = 'sbeams.dbo.labeling_method';
$TBIJ_MISC_OPTION            = 'inkjet.dbo.misc_option';
$TBIJ_DYE                    = 'arrays.dbo.dye';
$TBIJ_XNA_TYPE               = 'sbeams.dbo.xna_type';
$TBIJ_ARRAY_REQUEST          = 'inkjet.dbo.array_request';
$TBIJ_ARRAY_REQUEST_SLIDE    = 'inkjet.dbo.array_request_slide';
$TBIJ_ARRAY_REQUEST_SAMPLE   = 'inkjet.dbo.array_request_sample';
$TBIJ_ARRAY_REQUEST_OPTION   = 'inkjet.dbo.array_request_option';
$TBIJ_SLIDE_MODEL            = 'inkjet.dbo.slide_model';
$TBIJ_SLIDE_LOT              = 'inkjet.dbo.slide_lot';
$TBIJ_SLIDE                  = 'inkjet.dbo.slide';
$TBIJ_PRINTING_BATCH         = 'inkjet.dbo.printing_batch';
$TBIJ_ARRAY_LAYOUT           = 'inkjet.dbo.array_layout';
$TBIJ_ARRAY                  = 'inkjet.dbo.array';
$TBIJ_LABELING               = 'inkjet.dbo.labeling';
$TBIJ_HYBRIDIZATION          = 'inkjet.dbo.hybridization';
$TBIJ_ARRAY_SCAN             = 'inkjet.dbo.array_scan';
$TBIJ_ARRAY_QUANTITATION     = 'inkjet.dbo.array_quantitation';


