package SBEAMS::Immunostain::Tables;

###############################################################################
# Program     : SBEAMS::Immunostain::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Immunostain module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT 
    $TB_ORGANISM
    $TB_PROTOCOL
    $TB_PROTOCOL_TYPE

    $TBIS_BIOSEQUENCE_SET
    $TBIS_DBXREF
    $TBIS_BIOSEQUENCE
    $TBIS_QUERY_OPTION

    $TBIS_ANTIBODY
    $TBIS_ANTIGEN
    $TBIS_TISSUE_TYPE
    $TBIS_SPECIMEN
    $TBIS_SPECIMEN_BLOCK
    $TBIS_STAINED_SLIDE
    $TBIS_SLIDE_IMAGE

    $TBIS_STAIN_CELL_PRESENCE
    $TBIS_CELL_TYPE
    $TBIS_CELL_PRESENCE_LEVEL
		$TBIS_ABUNDANCE_LEVEL
			
		$TBIS_SURGICAL_PROCEDURE
		$TBIS_CLINICAL_DIAGNOSIS

);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM
    $TB_PROTOCOL
    $TB_PROTOCOL_TYPE

    $TBIS_BIOSEQUENCE_SET
    $TBIS_DBXREF
    $TBIS_BIOSEQUENCE
    $TBIS_QUERY_OPTION

    $TBIS_ANTIBODY
    $TBIS_ANTIGEN
    $TBIS_TISSUE_TYPE
    $TBIS_SPECIMEN
    $TBIS_SPECIMEN_BLOCK
    $TBIS_STAINED_SLIDE
    $TBIS_SLIDE_IMAGE

    $TBIS_STAIN_CELL_PRESENCE
    $TBIS_CELL_TYPE
    $TBIS_CELL_PRESENCE_LEVEL
		$TBIS_ABUNDANCE_LEVEL
			
		$TBIS_SURGICAL_PROCEDURE
		$TBIS_CLINICAL_DIAGNOSIS

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{Immunostain};

$TB_ORGANISM                = "${core}organism";
$TB_PROTOCOL                = "${core}protocol";
$TB_PROTOCOL_TYPE           = "${core}protocol_type";

$TBIS_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBIS_DBXREF                = "${mod}dbxref";
$TBIS_BIOSEQUENCE           = "${mod}biosequence";
$TBIS_QUERY_OPTION          = "${mod}query_option";

$TBIS_ANTIBODY              = "${mod}antibody";
$TBIS_ANTIGEN               = "${mod}antigen";
$TBIS_TISSUE_TYPE           = "${mod}tissue_type";
$TBIS_SPECIMEN              = "${mod}specimen";
$TBIS_SPECIMEN_BLOCK        = "${mod}specimen_block";
$TBIS_STAINED_SLIDE         = "${mod}stained_slide";
$TBIS_SLIDE_IMAGE           = "${mod}slide_image";

$TBIS_STAIN_CELL_PRESENCE   = "${mod}stain_cell_presence";
$TBIS_CELL_TYPE             = "${mod}cell_type";
$TBIS_CELL_PRESENCE_LEVEL   = "${mod}cell_presence_level";
$TBIS_ABUNDANCE_LEVEL				= "${mod}abundance_level";

$TBIS_SURGICAL_PROCEDURE		= "${mod}surgical_procedure";
$TBIS_CLINICAL_DIAGNOSIS		= "${mod}clinical_diagnosis";

