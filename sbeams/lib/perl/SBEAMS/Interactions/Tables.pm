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

use SBEAMS::Connection::Settings;


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


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{glue};


$TB_ORGANISM                      = "${core}organism";
$TBIN_QUERY_OPTION                = "${mod}query_option";

$TBIN_BIOENTITY                   = "${mod}bioentity";
$TBIN_BIOENTITY_TYPE              = "${mod}bioentity_type";
$TBIN_BIOENTITY_ATTRIBUTE         = "${mod}bioentity_attribute";
$TBIN_BIOENTITY_ATTRIBUTE_TYPE    = "${mod}bioentity_attribute_type";
$TBIN_REGULATORY_FEATURE          = "${mod}regulatory_feature";
$TBIN_REGULATORY_FEATURE_TYPE     = "${mod}regulatory_feature_type";
$TBIN_INTERACTION                 = "${mod}interaction";
$TBIN_INTERACTION_GROUP           = "${mod}interaction_group";
$TBIN_INTERACTION_TYPE            = "${mod}interaction_type";
$TBIN_BIOENTITY_STATE             = "${mod}bioentity_state";
$TBIN_CONFIDENCE_SCORE            = "${mod}confidence_score";

$TBIN_ASSAY                       = "${mod}assay";
$TBIN_ASSAY_TYPE                  = "${mod}assay_type";
$TBIN_SAMPLE_TYPE                 = "${mod}sample_type";
$TBIN_PUBLICATION                 = "${mod}publication";
$TBIN_PUBLICATION_CATEGORY        = "${mod}publication_category";


$TBIN_BIOSEQUENCE_SET             = "${mod}biosequence_set";
$TBIN_BIOSEQUENCE                 = "${mod}biosequence";
$TBIN_BIOSEQUENCE_DBXREF          = "${mod}dbxref";

