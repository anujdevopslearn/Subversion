package SBEAMS::Interactions::Tables;

###############################################################################
# Program     : SBEAMS::Interactions::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Interactions module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_ORGANISM
    $TBIN_QUERY_OPTION

    $TBIN_BIOENTITY
    $TBIN_BIOENTITY_TYPE
    $TBIN_BIOENTITY_ATTRIBUTE
    $TBIN_BIOENTITY_ATTRIBUTE_TYPE
    $TBIN_REGULATORY_FEATURE
    $TBIN_REGULATORY_FEATURE_TYPE
    $TBIN_INTERACTION
    $TBIN_INTERACTION_GROUP
    $TBIN_INTERACTION_TYPE
    $TBIN_BIOENTITY_STATE
    $TBIN_CONFIDENCE_SCORE

    $TBIN_ASSAY
    $TBIN_ASSAY_TYPE
    $TBIN_SAMPLE_TYPE
    $TBIN_PUBLICATION
    $TBIN_PUBLICATION_CATEGORY
    
    $TBIN_BIOSEQUENCE_SET
    $TBIN_BIOSEQUENCE
    $TBIN_BIOSEQUENCE_DBXREF

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
    $TBIN_QUERY_OPTION

    $TBIN_BIOENTITY
    $TBIN_BIOENTITY_TYPE
    $TBIN_BIOENTITY_ATTRIBUTE
    $TBIN_BIOENTITY_ATTRIBUTE_TYPE
    $TBIN_REGULATORY_FEATURE
    $TBIN_REGULATORY_FEATURE_TYPE
    $TBIN_INTERACTION
    $TBIN_INTERACTION_GROUP
    $TBIN_INTERACTION_TYPE
    $TBIN_BIOENTITY_STATE
    $TBIN_CONFIDENCE_SCORE

    $TBIN_ASSAY
    $TBIN_ASSAY_TYPE
    $TBIN_SAMPLE_TYPE
    $TBIN_PUBLICATION
    $TBIN_PUBLICATION_CATEGORY

    $TBIN_BIOSEQUENCE_SET
    $TBIN_BIOSEQUENCE
    $TBIN_BIOSEQUENCE_DBXREF

);


$TB_ORGANISM                = 'sbeams.dbo.organism';
$TBIN_QUERY_OPTION          = 'glue.dbo.query_option';

$TBIN_BIOENTITY             = 'glue.dbo.bioentity';
$TBIN_BIOENTITY_TYPE        = 'glue.dbo.bioentity_type';
$TBIN_BIOENTITY_ATTRIBUTE   = 'glue.dbo.bioentity_attribute';
$TBIN_BIOENTITY_ATTRIBUTE_TYPE        = 'glue.dbo.bioentity_attribute_type';
$TBIN_REGULATORY_FEATURE    = 'glue.dbo.regulatory_feature';
$TBIN_REGULATORY_FEATURE_TYPE   = 'glue.dbo.regulatory_feature_type';
$TBIN_INTERACTION           = 'glue.dbo.interaction';
$TBIN_INTERACTION_GROUP     = 'glue.dbo.interaction_group';
$TBIN_INTERACTION_TYPE      = 'glue.dbo.interaction_type';
$TBIN_BIOENTITY_STATE       = 'glue.dbo.bioentity_state';
$TBIN_CONFIDENCE_SCORE      = 'glue.dbo.confidence_score';

$TBIN_ASSAY                 = 'glue.dbo.assay';
$TBIN_ASSAY_TYPE            = 'glue.dbo.assay_type';
$TBIN_SAMPLE_TYPE           = 'glue.dbo.sample_type';
$TBIN_PUBLICATION           = 'glue.dbo.publication';
$TBIN_PUBLICATION_CATEGORY  = 'glue.dbo.publication_category';


$TBIN_BIOSEQUENCE_SET       = 'glue.dbo.biosequence_set';
$TBIN_BIOSEQUENCE           = 'glue.dbo.biosequence';
$TBIN_BIOSEQUENCE_DBXREF    = 'glue.dbo.dbxref';

