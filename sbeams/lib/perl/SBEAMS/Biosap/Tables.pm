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

use SBEAMS::Connection::Settings;

use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBBS_BIOSEQUENCE_SET
    $TBBS_BIOSEQUENCE
		$TBBS_BIOSEQUENCE_PROPERTY_SET
		$TBBS_DBXREF
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
		$TBBS_BIOSEQUENCE_PROPERTY_SET
		$TBBS_DBXREF
    $TBBS_BIOSAP_SEARCH
    $TBBS_FEATURAMA_PARAMETER
    $TBBS_FEATURAMA_STATISTIC
    $TBBS_FILTERBLAST_STATISTIC
    $TBBS_FEATURE
    $TBBS_FEATURE_HIT

    $TBBS_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Biosap};

$TB_ORGANISM                = "${core}organism";

$TBBS_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBBS_BIOSEQUENCE           = "${mod}biosequence";
$TBBS_BIOSEQUENCE_PROPERTY_SET = "${mod}biosequence_property_set";
$TBBS_DBXREF                = "${mod}dbxref";
$TBBS_BIOSAP_SEARCH         = "${mod}biosap_search";
$TBBS_FEATURAMA_PARAMETER   = "${mod}featurama_parameter";
$TBBS_FEATURAMA_STATISTIC   = "${mod}featurama_statistic";
$TBBS_FILTERBLAST_STATISTIC = "${mod}filterblast_statistic";
$TBBS_FEATURE               = "${mod}feature";
$TBBS_FEATURE_HIT           = "${mod}feature_hit";

$TBBS_QUERY_OPTION          = "${mod}query_option";


