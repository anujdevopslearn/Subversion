package SBEAMS::PhenoArray::Tables;

###############################################################################
# Program     : SBEAMS::PhenoArray::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::PhenoArray module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_ORGANISM
    $TB_PROTOCOL

    $TBPH_BIOSEQUENCE_SET
    $TBPH_BIOSEQUENCE

    $TBPH_BIOSEQUNCE_MODIFICATION
    $TBPH_PLASMID
    $TBPH_SUBSTRAIN
    $TBPH_REFERENCE_STRAIN
    $TBPH_MATING_TYPE
    $TBPH_PLOIDY
    $TBPH_ARRAY_QUANTITATION
    $TBPH_ARRAY_QUANTITATION_SUBSET
    $TBPH_SPOT_QUANTITATION
    $TBPH_PLATE
    $TBPH_PLATE_LAYOUT
    $TBPH_CONDITION
    $TBPH_CONDITION_REPEAT
    $TBPH_SUBSTRAIN_BEHAVIOR

    $TBPH_QUERY_OPTION
);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
    $TB_PROTOCOL

    $TBPH_BIOSEQUENCE_SET
    $TBPH_BIOSEQUENCE

    $TBPH_BIOSEQUNCE_MODIFICATION
    $TBPH_PLASMID
    $TBPH_SUBSTRAIN
    $TBPH_REFERENCE_STRAIN
    $TBPH_MATING_TYPE
    $TBPH_PLOIDY
    $TBPH_ARRAY_QUANTITATION
    $TBPH_ARRAY_QUANTITATION_SUBSET
    $TBPH_SPOT_QUANTITATION
    $TBPH_PLATE
    $TBPH_PLATE_LAYOUT
    $TBPH_CONDITION
    $TBPH_CONDITION_REPEAT
    $TBPH_SUBSTRAIN_BEHAVIOR

    $TBPH_QUERY_OPTION
);



$TB_ORGANISM                      = 'organism';
$TB_PROTOCOL                      = 'protocol';

$TBPH_BIOSEQUENCE_SET             = 'PhenoArray.dbo.biosequence_set';
$TBPH_BIOSEQUENCE                 = 'PhenoArray.dbo.biosequence';
$TBPH_BIOSEQUNCE_MODIFICATION     = 'PhenoArray.dbo.biosequence_modification';
$TBPH_PLASMID                     = 'PhenoArray.dbo.plasmid';
$TBPH_SUBSTRAIN                   = 'PhenoArray.dbo.substrain';
$TBPH_REFERENCE_STRAIN            = 'PhenoArray.dbo.reference_strain';
$TBPH_MATING_TYPE                 = 'PhenoArray.dbo.mating_type';
$TBPH_PLOIDY                      = 'PhenoArray.dbo.ploidy';
$TBPH_ARRAY_QUANTITATION          = 'PhenoArray.dbo.array_quantitation';
$TBPH_ARRAY_QUANTITATION_SUBSET   = 'PhenoArray.dbo.array_quantitation_subset';
$TBPH_SPOT_QUANTITATION           = 'PhenoArray.dbo.spot_quantitation';
$TBPH_PLATE                       = 'PhenoArray.dbo.plate';
$TBPH_PLATE_LAYOUT                = 'PhenoArray.dbo.plate_layout';
$TBPH_CONDITION                   = 'PhenoArray.dbo.condition';
$TBPH_CONDITION_REPEAT            = 'PhenoArray.dbo.condition_repeat';
$TBPH_SUBSTRAIN_BEHAVIOR          = 'PhenoArray.dbo.substrain_behavior';

$TBPH_QUERY_OPTION                = 'PhenoArray.dbo.query_option';


