package SBEAMS::Biomarker::Tables;

###############################################################################
# Program     : SBEAMS::Biomarker::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Biomarker module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    
    $TB_ORGANISM

    $TBBL_BIOSEQUENCE_SET
    $TBBL_DBXREF
    $TBBL_BIOSEQUENCE
    $TBBL_BIOSEQUENCE_PROPERTY_SET
    $TBBL_QUERY_OPTION
		$TBBM_TREATMENT
		$TBBM_TREATMENT_TYPE

    $TBBM_BIOSOURCE
    $TBBM_BIOSAMPLE
    $TBBM_DISEASE
    $TBBM_ATTRIBUTE_TYPE
    $TBBM_ATTRIBUTE
    $TBBM_BIOSOURCE_ATTRIBUTE
    $TBBM_BIOSAMPLE_ATTRIBUTE
    $TBBM_BIOSOURCE_DISEASE
    $TBBM_STORAGE_LOCATION
    $TBBM_ANALYSIS_FILE
    $TBBM_EXPERIMENT
    $TBBM_TREATEMENT_TYPE
    $TBBM_TREATMENT
);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBBL_BIOSEQUENCE_SET
    $TBBL_DBXREF
    $TBBL_BIOSEQUENCE
    $TBBL_BIOSEQUENCE_PROPERTY_SET
    $TBBL_QUERY_OPTION
		$TBBM_TREATMENT
		$TBBM_TREATMENT_TYPE

    $TBBM_BIOSOURCE
    $TBBM_BIOSAMPLE
    $TBBM_DISEASE
    $TBBM_ATTRIBUTE_TYPE
    $TBBM_ATTRIBUTE
    $TBBM_BIOSOURCE_ATTRIBUTE
    $TBBM_BIOSAMPLE_ATTRIBUTE
    $TBBM_BIOSOURCE_DISEASE
    $TBBM_STORAGE_LOCATION
    $TBBM_ANALYSIS_FILE
    $TBBM_EXPERIMENT
    $TBBM_TREATEMENT_TYPE
    $TBBM_TREATMENT
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $bl   = $DBPREFIX{BioLink};
my $mod  = $DBPREFIX{Biomarker};

$TB_ORGANISM                      = "${core}organism";

$TBBL_BIOSEQUENCE_SET       = "${bl}biosequence_set";
$TBBL_DBXREF                = "${bl}dbxref";
$TBBL_BIOSEQUENCE           = "${bl}biosequence";
$TBBL_BIOSEQUENCE_PROPERTY_SET   = "${bl}biosequence_property_set";
$TBBL_QUERY_OPTION          = "${bl}query_option";

$TBBM_BIOSOURCE           = "${mod}biosource";
$TBBM_BIOSAMPLE           = "${mod}biosample";
$TBBM_DISEASE             = "${mod}disease";
$TBBM_ATTRIBUTE_TYPE      = "${mod}attribute_type";
$TBBM_ATTRIBUTE           = "${mod}attribute";
$TBBM_BIOSOURCE_ATTRIBUTE = "${mod}biosource_attribute";
$TBBM_BIOSAMPLE_ATTRIBUTE = "${mod}biosample_attribute";
$TBBM_BIOSOURCE_DISEASE   = "${mod}attribute";
$TBBM_STORAGE_LOCATION    = "${mod}storage_location";
$TBBM_ANALYSIS_FILE       = "${mod}analysis_file";
$TBBM_EXPERIMENT          = "${mod}experiment";
$TBBM_TREATMENT             = "${mod}treatment";
$TBBM_TREATMENT_TYPE        = "${mod}treatment_type";


1;
