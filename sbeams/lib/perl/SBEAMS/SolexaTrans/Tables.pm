package SBEAMS::SolexaTrans::Tables;

###############################################################################
# Program     : SBEAMS::SolexaTrans::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: Tables.pm 4504 2006-03-07 23:49:03Z edeutsch $
#
# Description : This is part of the SBEAMS::SolexaTrans module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBST_BIOSEQUENCE_SET
    $TBST_DBXREF
    $TBST_BIOSEQUENCE
    $TBST_BIOSEQUENCE_PROPERTY_SET
    $TBST_QUERY_OPTION

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBST_BIOSEQUENCE_SET
    $TBST_DBXREF
    $TBST_BIOSEQUENCE
    $TBST_BIOSEQUENCE_PROPERTY_SET
    $TBST_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{SolexaTrans};

$TB_ORGANISM                      = "${core}organism";

$TBST_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBST_DBXREF                = "${mod}dbxref";
$TBST_BIOSEQUENCE           = "${mod}biosequence";
$TBST_BIOSEQUENCE_PROPERTY_SET   = "${mod}biosequence_property_set";
$TBST_QUERY_OPTION          = "${mod}query_option";



