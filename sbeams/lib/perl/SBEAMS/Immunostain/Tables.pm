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
    $TBIS_ASSAY    
    $TBIS_ASSAY_IMAGE 
	
    $TBIS_ASSAY_UNIT_EXPRESSION 
    $TBIS_STRUCTURAL_UNIT 
    $TBIS_EXPRESSION_LEVEL
	
	$TBIS_ABUNDANCE_LEVEL
	$TBIS_SURGICAL_PROCEDURE
	$TBIS_CLINICAL_DIAGNOSIS
	$TBIS_GENOME_COORDINATES
	
	$TBIS_ASSAY_IMAGE_SUBFIELD 
	$TBIS_DETECTION_METHOD
	$TBIS_ASSAY_CHANNEL
	$TBIS_PROBE 
	$TBIS_ONTOTLOGY 
	$TBIS_ONTOLOGY_TERM  
	$TBIS_ONTOLOGY_TERM_RELATIONSHIP
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
     $TBIS_ASSAY     
    $TBIS_ASSAY_IMAGE 
	
    $TBIS_ASSAY_UNIT_EXPRESSION  
    $TBIS_STRUCTURAL_UNIT
    $TBIS_EXPRESSION_LEVEL
	
	$TBIS_ABUNDANCE_LEVEL
	$TBIS_SURGICAL_PROCEDURE
	$TBIS_CLINICAL_DIAGNOSIS
	$TBIS_GENOME_COORDINATES
	
	$TBIS_ASSAY_IMAGE_SUBFIELD 
	$TBIS_DETECTION_METHOD
	$TBIS_ASSAY_CHANNEL  
	$TBIS_PROBE
	$TBIS_ONTOTLOGY 
	$TBIS_ONTOLOGY_TERM  
	$TBIS_ONTOLOGY_TERM_RELATIONSHIP

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
$TBIS_ASSAY    = "${mod}assay";
 $TBIS_ASSAY_IMAGE   = "${mod}assay_image";
	
    $TBIS_ASSAY_UNIT_EXPRESSION   = "${mod}assay_unit_expression";
    $TBIS_STRUCTURAL_UNIT   = "${mod}structural_unit";
    $TBIS_EXPRESSION_LEVEL   = "${mod}expression_level";
	
	$TBIS_ABUNDANCE_LEVEL   = "${mod}abundance_level"; 
	$TBIS_SURGICAL_PROCEDURE   = "${mod}surgical_procedure"; 
	$TBIS_CLINICAL_DIAGNOSIS   = "${mod}clinical_diagnosis"; 
	$TBIS_GENOME_COORDINATES   = "${mod}genome_coordinates"; 
	
	$TBIS_ASSAY_IMAGE_SUBFIELD     = "${mod}assay_image_subfield";
	$TBIS_DETECTION_METHOD    = "${mod}detection_method";
	$TBIS_ASSAY_CHANNEL    = "${mod}assay_channel";
	$TBIS_PROBE    = "${mod}probe";
	$TBIS_ONTOTLOGY   = "${mod}ontology";
	$TBIS_ONTOLOGY_TERM    = "${mod}ontology_term"; 
	$TBIS_ONTOLOGY_TERM_RELATIONSHIP    = "${mod}ontology_term_relationship";

