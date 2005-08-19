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

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $bl = $DBPREFIX{Biolink};
my $mod = $DBPREFIX{Biomarker};

$TB_ORGANISM                      = "${core}organism";

$TBBL_BIOSEQUENCE_SET       = "${bl}biosequence_set";
$TBBL_DBXREF                = "${bl}dbxref";
$TBBL_BIOSEQUENCE           = "${bl}biosequence";
$TBBL_BIOSEQUENCE_PROPERTY_SET   = "${bl}biosequence_property_set";
$TBBL_QUERY_OPTION          = "${bl}query_option";
$TBBM_TREATMENT             = "${mod}treatment";
$TBBM_TREATMENT_TYPE        = "${mod}treatment_type";



