package SBEAMS::BioLink::Tables;

###############################################################################
# Program     : SBEAMS::BioLink::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::BioLink module which provides
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
    $TBBL_QUERY_OPTION

    $TBBL_POLYMER_TYPE
    $TBBL_RELATIONSHIP_TYPE
    $TBBL_RELATIONSHIP
    $TBBL_EVIDENCE
    $TBBL_EVIDENCE_SOURCE

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBBL_BIOSEQUENCE_SET
    $TBBL_DBXREF
    $TBBL_BIOSEQUENCE
    $TBBL_QUERY_OPTION

    $TBBL_POLYMER_TYPE
    $TBBL_RELATIONSHIP_TYPE
    $TBBL_RELATIONSHIP
    $TBBL_EVIDENCE
    $TBBL_EVIDENCE_SOURCE

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{BioLink};

$TB_ORGANISM                      = "${core}organism";

$TBBL_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBBL_DBXREF                = "${mod}dbxref";
$TBBL_BIOSEQUENCE           = "${mod}biosequence";
$TBBL_QUERY_OPTION          = "${mod}query_option";

$TBBL_POLYMER_TYPE          = "${mod}polymer_type";
$TBBL_RELATIONSHIP_TYPE     = "${mod}relationship_type";
$TBBL_RELATIONSHIP          = "${mod}relationship";
$TBBL_EVIDENCE              = "${mod}evidence";
$TBBL_EVIDENCE_SOURCE       = "${mod}evidence_source";






