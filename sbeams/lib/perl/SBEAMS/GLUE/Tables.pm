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
    $TBGL_QUERY_OPTION

    $TBGL_BIOENTITY
    $TBGL_BIOENTITY_TYPE
    $TBGL_BIOENTITY_ATTRIBUTE
    $TBGL_BIOENTITY_ATTRIBUTE_TYPE
    $TBGL_REGULATORY_FEATURE
    $TBGL_REGULATORY_FEATURE_TYPE
    $TBGL_INTERACTION
    $TBGL_INTERACTION_GROUP
    $TBGL_INTERACTION_TYPE
    $TBGL_BIOENTITY_STATE
    $TBGL_CONFIDENCE_SCORE

    $TBGL_ASSAY
    $TBGL_ASSAY_TYPE
    $TBGL_SAMPLE_TYPE
    $TBGL_PUBLICATION
    $TBGL_PUBLICATION_CATEGORY
    
    $TBGL_BIOSEQUENCE_SET
    $TBGL_BIOSEQUENCE
    $TBGL_BIOSEQUENCE_DBXREF

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
    $TBGL_QUERY_OPTION

    $TBGL_BIOENTITY
    $TBGL_BIOENTITY_TYPE
    $TBGL_BIOENTITY_ATTRIBUTE
    $TBGL_BIOENTITY_ATTRIBUTE_TYPE
    $TBGL_REGULATORY_FEATURE
    $TBGL_REGULATORY_FEATURE_TYPE
    $TBGL_INTERACTION
    $TBGL_INTERACTION_GROUP
    $TBGL_INTERACTION_TYPE
    $TBGL_BIOENTITY_STATE
    $TBGL_CONFIDENCE_SCORE

    $TBGL_ASSAY
    $TBGL_ASSAY_TYPE
    $TBGL_SAMPLE_TYPE
    $TBGL_PUBLICATION
    $TBGL_PUBLICATION_CATEGORY

    $TBGL_BIOSEQUENCE_SET
    $TBGL_BIOSEQUENCE
    $TBGL_BIOSEQUENCE_DBXREF

);


$TB_ORGANISM                = 'sbeams.dbo.organism';
$TBGL_QUERY_OPTION          = 'glue.dbo.query_option';

$TBGL_BIOENTITY             = 'glue.dbo.bioentity';
$TBGL_BIOENTITY_TYPE        = 'glue.dbo.bioentity_type';
$TBGL_BIOENTITY_ATTRIBUTE   = 'glue.dbo.bioentity_attribute';
$TBGL_BIOENTITY_ATTRIBUTE_TYPE        = 'glue.dbo.bioentity_attribute_type';
$TBGL_REGULATORY_FEATURE    = 'glue.dbo.regulatory_feature';
$TBGL_REGULATORY_FEATURE_TYPE   = 'glue.dbo.regulatory_feature_type';
$TBGL_INTERACTION           = 'glue.dbo.interaction';
$TBGL_INTERACTION_GROUP     = 'glue.dbo.interaction_group';
$TBGL_INTERACTION_TYPE      = 'glue.dbo.interaction_type';
$TBGL_BIOENTITY_STATE       = 'glue.dbo.bioentity_state';
$TBGL_CONFIDENCE_SCORE      = 'glue.dbo.confidence_score';

$TBGL_ASSAY                 = 'glue.dbo.assay';
$TBGL_ASSAY_TYPE            = 'glue.dbo.assay_type';
$TBGL_SAMPLE_TYPE           = 'glue.dbo.sample_type';
$TBGL_PUBLICATION           = 'glue.dbo.publication';
$TBGL_PUBLICATION_CATEGORY  = 'glue.dbo.publication_category';


$TBGL_BIOSEQUENCE_SET       = 'glue.dbo.biosequence_set';
$TBGL_BIOSEQUENCE           = 'glue.dbo.biosequence';
$TBGL_BIOSEQUENCE_DBXREF    = 'glue.dbo.dbxref';

