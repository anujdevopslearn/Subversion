package SBEAMS::Biosap::Tables;

###############################################################################
# Program     : SBEAMS::Biosap::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Biosap module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBBS_BIOSEQUENCE_SET
    $TBBS_BIOSEQUENCE

    $TBBS_BIOSAP_SEARCH
    $TBBS_FEATURAMA_PARAMETER
    $TBBS_FEATURAMA_STATISTIC
    $TBBS_FILTERBLAST_STATISTIC
    $TBBS_FEATURE
    $TBBS_FEATURE_HIT

    $TBBS_QUERY_OPTION

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBBS_BIOSEQUENCE_SET
    $TBBS_BIOSEQUENCE

    $TBBS_BIOSAP_SEARCH
    $TBBS_FEATURAMA_PARAMETER
    $TBBS_FEATURAMA_STATISTIC
    $TBBS_FILTERBLAST_STATISTIC
    $TBBS_FEATURE
    $TBBS_FEATURE_HIT

    $TBBS_QUERY_OPTION

);


$TB_ORGANISM                = 'sbeams.dbo.organism';

$TBBS_BIOSEQUENCE_SET       = 'biosap.dbo.biosequence_set';
$TBBS_BIOSEQUENCE           = 'biosap.dbo.biosequence';

$TBBS_BIOSAP_SEARCH         = 'biosap.dbo.biosap_search';
$TBBS_FEATURAMA_PARAMETER   = 'biosap.dbo.featurama_parameter';
$TBBS_FEATURAMA_STATISTIC   = 'biosap.dbo.featurama_statistic';
$TBBS_FILTERBLAST_STATISTIC = 'biosap.dbo.filterblast_statistic';
$TBBS_FEATURE               = 'biosap.dbo.feature';
$TBBS_FEATURE_HIT           = 'biosap.dbo.feature_hit';

$TBBS_QUERY_OPTION          = 'biosap.dbo.query_option';


