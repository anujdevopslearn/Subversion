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

    $TBPH_SEQUNCE_MODIFICATION
    $TBPH_PLASMID
    $TBPH_STRAIN
    $TBPH_CELL_TYPE
    $TBPH_MATING_TYPE
    $TBPH_PLOIDY
    $TBPH_CONSTRUCTION_METHOD
    $TBPH_ARRAY_QUANTITATION
    $TBPH_ARRAY_QUANTITATION_SUBSET
    $TBPH_SPOT_QUANTITATION
    $TBPH_PLATE
    $TBPH_PLATE_LAYOUT
    $TBPH_CONDITION
    $TBPH_CONDITION_REPEAT
    $TBPH_STRAIN_BEHAVIOR
    $TBPH_ALLELE  
    $TBPH_SUBSTRAIN_BEHAVIOR
    
    $TBPH_COLI_MARKER
    $TBPH_YEAST_SELECTION_MARKER
    $TBPH_YEAST_ORIGIN
    $TBPH_PLASMID_TYPE
    $TBPH_CITATION
    $TBPH_STRAIN_BACKGROUND
    $TBPH_STRAIN_STATUS

    $TBPH_QUERY_OPTION
);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
    $TB_PROTOCOL

    $TBPH_BIOSEQUENCE_SET
    $TBPH_BIOSEQUENCE

    $TBPH_SEQUNCE_MODIFICATION
    $TBPH_PLASMID
    $TBPH_STRAIN
    $TBPH_CELL_TYPE
    $TBPH_MATING_TYPE
    $TBPH_PLOIDY
    $TBPH_CONSTRUCTION_METHOD
    $TBPH_ARRAY_QUANTITATION
    $TBPH_ARRAY_QUANTITATION_SUBSET
    $TBPH_SPOT_QUANTITATION
    $TBPH_PLATE
    $TBPH_PLATE_LAYOUT
    $TBPH_CONDITION
    $TBPH_CONDITION_REPEAT
    $TBPH_STRAIN_BEHAVIOR
    $TBPH_ALLELE  
    $TBPH_SUBSTRAIN_BEHAVIOR

    $TBPH_COLI_MARKER
    $TBPH_YEAST_SELECTION_MARKER
    $TBPH_YEAST_ORIGIN
    $TBPH_PLASMID_TYPE
    $TBPH_CITATION
    $TBPH_STRAIN_BACKGROUND
    $TBPH_STRAIN_STATUS

    $TBPH_QUERY_OPTION
);



$TB_ORGANISM                      = 'organism';
$TB_PROTOCOL                      = 'protocol';

$TBPH_BIOSEQUENCE_SET             = 'PhenoArray.dbo.biosequence_set';
$TBPH_BIOSEQUENCE                 = 'PhenoArray.dbo.biosequence';
$TBPH_SEQUNCE_MODIFICATION        = 'PhenoArray.dbo.sequence_modification';
$TBPH_PLASMID                     = 'PhenoArray.dbo.plasmid';
$TBPH_STRAIN                      = 'PhenoArray.dbo.strain';
$TBPH_CELL_TYPE                   = 'PhenoArray.dbo.cell_type';
$TBPH_MATING_TYPE                 = 'PhenoArray.dbo.mating_type';
$TBPH_PLOIDY                      = 'PhenoArray.dbo.ploidy';
$TBPH_CONSTRUCTION_METHOD         = 'PhenoArray.dbo.construction_method';
$TBPH_ARRAY_QUANTITATION          = 'PhenoArray.dbo.array_quantitation';
$TBPH_ARRAY_QUANTITATION_SUBSET   = 'PhenoArray.dbo.array_quantitation_subset';
$TBPH_SPOT_QUANTITATION           = 'PhenoArray.dbo.spot_quantitation';
$TBPH_PLATE                       = 'PhenoArray.dbo.plate';
$TBPH_PLATE_LAYOUT                = 'PhenoArray.dbo.plate_layout';
$TBPH_CONDITION                   = 'PhenoArray.dbo.condition';
$TBPH_CONDITION_REPEAT            = 'PhenoArray.dbo.condition_repeat';
$TBPH_STRAIN_BEHAVIOR             = 'PhenoArray.dbo.strain_behavior';
$TBPH_ALLELE                      = 'PhenoArray.dbo.allele';
$TBPH_SUBSTRAIN_BEHAVIOR          = 'PhenoArray.dbo.substrain_behavior';

$TBPH_COLI_MARKER                 = 'PhenoArray.dbo.coli_marker';
$TBPH_YEAST_SELECTION_MARKER      = 'PhenoArray.dbo.yeast_selection_marker';
$TBPH_YEAST_ORIGIN                = 'PhenoArray.dbo.yeast_origin';
$TBPH_PLASMID_TYPE                = 'PhenoArray.dbo.plasmid_type';
$TBPH_CITATION                    = 'PhenoArray.dbo.citation';
$TBPH_STRAIN_BACKGROUND           = 'PhenoArray.dbo.strain_background';
$TBPH_STRAIN_STATUS               = 'PhenoArray.dbo.strain_status';

$TBPH_QUERY_OPTION                = 'PhenoArray.dbo.query_option';

