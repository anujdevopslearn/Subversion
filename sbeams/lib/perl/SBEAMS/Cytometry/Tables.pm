package SBEAMS::Cytometry::Tables;

###############################################################################
# Program     : SBEAMS::Cytometry::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Cytometry module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM
    $TBCY_QUERY_OPTION

    $TBCY_FCS_RUN
    $TBCY_FCS_RUN_PARAMETER

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
    $TBCY_QUERY_OPTION

    $TBCY_FCS_RUN
    $TBCY_FCS_RUN_PARAMETER

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Cytometry};

$TB_ORGANISM                = "${core}organism";
$TBCY_QUERY_OPTION          = "${mod}query_option";

$TBCY_FCS_RUN               = "${mod}fcs_run";
$TBCY_FCS_RUN_PARAMETER     = "${mod}fcs_run_parameter";



