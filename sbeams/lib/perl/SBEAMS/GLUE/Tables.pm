package SBEAMS::GLUE::Tables;

###############################################################################
# Program     : SBEAMS::GLUE::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::GLUE module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBGL_BIOENTITY
    $TBGL_BIOENTITY_TYPE
    $TBGL_REGULATORY_FEATURE
    $TBGL_REGULATORY_FEATURE_TYPE
    $TBGL_ASSAY
    $TBGL_INTERACTION
    $TBGL_BIOENTITY_STATE
    $TBGL_INTERACTION_TYPE
    $TBGL_CONFIDENCE_SCORE

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBGL_BIOENTITY
    $TBGL_BIOENTITY_TYPE
    $TBGL_REGULATORY_FEATURE
    $TBGL_REGULATORY_FEATURE_TYPE
    $TBGL_ASSAY
    $TBGL_INTERACTION
    $TBGL_BIOENTITY_STATE
    $TBGL_INTERACTION_TYPE
    $TBGL_CONFIDENCE_SCORE

);


$TB_ORGANISM                = 'sbeams.dbo.organism';

$TBGL_BIOENTITY             = 'glue.dbo.bioentity';
$TBGL_BIOENTITY_TYPE        = 'glue.dbo.bioentity_type';
$TBGL_REGULATORY_FEATURE    = 'glue.dbo.regulatory_feature';
$TBGL_REGULATORY_FEATURE_TYPE   = 'glue.dbo.regulatory_feature_type';
$TBGL_ASSAY                 = 'glue.dbo.assay';
$TBGL_INTERACTION           = 'glue.dbo.interaction';
$TBGL_BIOENTITY_STATE       = 'glue.dbo.bioentity_state';
$TBGL_INTERACTION_TYPE      = 'glue.dbo.interaction_type';
$TBGL_CONFIDENCE_SCORE      = 'glue.dbo.confidence_score';

