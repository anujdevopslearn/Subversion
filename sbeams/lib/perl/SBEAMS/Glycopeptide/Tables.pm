package SBEAMS::Glycopeptide::Tables;

###############################################################################
# Program     : SBEAMS::Glycopeptide::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: Tables.pm 1827 2003-11-27 00:43:01Z edeutsch $
#
# Description : This is part of the SBEAMS::Glycopeptide module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBModTmpTAG_BIOSEQUENCE_SET
    $TBModTmpTAG_DBXREF
    $TBModTmpTAG_BIOSEQUENCE
    $TBModTmpTAG_BIOSEQUENCE_PROPERTY_SET
    $TBModTmpTAG_QUERY_OPTION

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBModTmpTAG_BIOSEQUENCE_SET
    $TBModTmpTAG_DBXREF
    $TBModTmpTAG_BIOSEQUENCE
    $TBModTmpTAG_BIOSEQUENCE_PROPERTY_SET
    $TBModTmpTAG_QUERY_OPTION

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Glycopeptide};

$TB_ORGANISM                      = "${core}organism";

$TBModTmpTAG_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBModTmpTAG_DBXREF                = "${mod}dbxref";
$TBModTmpTAG_BIOSEQUENCE           = "${mod}biosequence";
$TBModTmpTAG_BIOSEQUENCE_PROPERTY_SET   = "${mod}biosequence_property_set";
$TBModTmpTAG_QUERY_OPTION          = "${mod}query_option";



