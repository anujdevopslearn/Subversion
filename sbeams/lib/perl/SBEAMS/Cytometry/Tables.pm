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
    $TBCY_MEASURED_PARAMETERS
    $TBCY_FCS_RUN_PARAMETERS
    $TBCY_FCS_DATA_POINT
    
    
   $TBCY_FCS_RUN_PARAMETER
	$TBCY_DATA_POINTS
	$TBCY_CONVERSION_DATA

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
    $TBCY_QUERY_OPTION

    $TBCY_FCS_RUN
    $TBCY_MEASURED_PARAMETERS
    $TBCY_FCS_RUN_PARAMETERS
    $TBCY_FCS_DATA_POINT
    
    $TBCY_FCS_RUN_PARAMETER
		$TBCY_DATA_POINTS
	 $TBCY_CONVERSION_DATA

  
  
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Cytometry};

$TB_ORGANISM                = "${core}organism";
$TBCY_QUERY_OPTION          = "${mod}query_option";

$TBCY_FCS_RUN               = "${mod}fcs_run";
$TBCY_MEASURED_PARAMETERS   = "${mod}measured_parameters";
$TBCY_FCS_RUN_PARAMETERS  = "${mod}fcs_run_parameters";  
$TBCY_FCS_DATA_POINT   = "${mod}fcs_data_point";

$TBCY_FCS_RUN_PARAMETER     = "${mod}fcs_run_parameter";
$TBCY_DATA_POINTS = "${mod}data_points";
$TBCY_CONVERSION_DATA = "${mod}conversion_data";






