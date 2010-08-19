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
    $TBBL_BIOSEQUENCE_PROPERTY_SET
    $TBBL_BIOSEQUENCE_ANNOTATION
    $TBBL_QUERY_OPTION

    $TBBL_POLYMER_TYPE
    $TBBL_RELATIONSHIP_TYPE
    $TBBL_RELATIONSHIP
    $TBBL_EVIDENCE
    $TBBL_EVIDENCE_SOURCE

    $TBBL_BLAST_RESULTS
    $TBBL_CBIL_GENOME_COORDINATES
    $TBBL_DOTS_TO_LOCUSLINK

    $TBBL_MGED_ONTOLOGY_RELATIONSHIP 
    $TBBL_MGED_ONTOLOGY_TERM

    $TBBL_ONTOLOGY_RELATIONSHIP_TYPE
    $TBBL_ONTOLOGY_TERM_TYPE

    $TBBL_ANNOTATED_GENE
    $TBBL_GENE_ANNOTATION
    $TBBL_GENE_ANNOTATION_TYPE
    $TBBL_ANNOTATION_HIERARCHY_LEVEL

    $TBBL_GAGGLE_STORE
    $TBBL_DATA_OBJECT
    $TBBL_DATA_OBJECT_TYPE
    $TBBL_HYPOTHESIS

    $TBBL_KEGG_PATHWAY
    $TBBL_KEGG_ORGANISM
    $TBBL_KEGG_GENE
    $TBBL_KEGG_PATHWAY_GENES

    $TBBL_ORTHOLOG

    $TBBL_ORGANISM_NAMESPACE
);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBBL_BIOSEQUENCE_SET
    $TBBL_DBXREF
    $TBBL_BIOSEQUENCE
    $TBBL_BIOSEQUENCE_PROPERTY_SET
    $TBBL_BIOSEQUENCE_ANNOTATION
    $TBBL_QUERY_OPTION

    $TBBL_POLYMER_TYPE
    $TBBL_RELATIONSHIP_TYPE
    $TBBL_RELATIONSHIP
    $TBBL_EVIDENCE
    $TBBL_EVIDENCE_SOURCE

    $TBBL_BLAST_RESULTS
    $TBBL_CBIL_GENOME_COORDINATES
    $TBBL_DOTS_TO_LOCUSLINK

    $TBBL_MGED_ONTOLOGY_RELATIONSHIP 
    $TBBL_MGED_ONTOLOGY_TERM

    $TBBL_ONTOLOGY_RELATIONSHIP_TYPE
    $TBBL_ONTOLOGY_TERM_TYPE

    $TBBL_ANNOTATED_GENE
    $TBBL_GENE_ANNOTATION
    $TBBL_GENE_ANNOTATION_TYPE
    $TBBL_ANNOTATION_HIERARCHY_LEVEL

    $TBBL_GAGGLE_STORE
    $TBBL_DATA_OBJECT
    $TBBL_DATA_OBJECT_TYPE
    $TBBL_HYPOTHESIS

    $TBBL_KEGG_PATHWAY
    $TBBL_KEGG_ORGANISM
    $TBBL_KEGG_GENE
    $TBBL_KEGG_PATHWAY_GENES

    $TBBL_ORTHOLOG

    $TBBL_ORGANISM_NAMESPACE
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{BioLink};

$TB_ORGANISM                      = "${core}organism";

$TBBL_BIOSEQUENCE_SET       = "${mod}biosequence_set";
$TBBL_DBXREF                = "${mod}dbxref";
$TBBL_BIOSEQUENCE           = "${mod}biosequence";
$TBBL_BIOSEQUENCE_PROPERTY_SET = "${mod}biosequence_property_set";
$TBBL_BIOSEQUENCE_ANNOTATION   = "${mod}biosequence_annotation";
$TBBL_QUERY_OPTION          = "${mod}query_option";

$TBBL_POLYMER_TYPE          = "${mod}polymer_type";
$TBBL_RELATIONSHIP_TYPE     = "${mod}relationship_type";
$TBBL_RELATIONSHIP          = "${mod}relationship";
$TBBL_EVIDENCE              = "${mod}evidence";
$TBBL_EVIDENCE_SOURCE       = "${mod}evidence_source";

$TBBL_BLAST_RESULTS         = "${mod}blast_results";
$TBBL_CBIL_GENOME_COORDINATES  = "${mod}cbil_genome_coordinates";
$TBBL_DOTS_TO_LOCUSLINK = "${mod}dots_to_locuslink";

$TBBL_MGED_ONTOLOGY_RELATIONSHIP = "${mod}MGEDOntologyRelationship";
$TBBL_MGED_ONTOLOGY_TERM	= "${mod}MGEDOntologyTerm";

$TBBL_ONTOLOGY_RELATIONSHIP_TYPE  = "${mod}OntologyRelationshipType";
$TBBL_ONTOLOGY_TERM_TYPE           = "${mod}OntologyTermType";

$TBBL_ANNOTATED_GENE = "${mod}annotated_gene";
$TBBL_GENE_ANNOTATION = "${mod}gene_annotation";
$TBBL_GENE_ANNOTATION_TYPE = "${mod}gene_annotation_type";
$TBBL_ANNOTATION_HIERARCHY_LEVEL = "${mod}annotation_hierarchy_level";

$TBBL_GAGGLE_STORE = "${core}gaggle_store";
$TBBL_DATA_OBJECT = "${mod}data_object";
$TBBL_DATA_OBJECT_TYPE = "${mod}data_object_type";
$TBBL_HYPOTHESIS = "${mod}hypothesis";

$TBBL_KEGG_PATHWAY = "${mod}kegg_pathway";
$TBBL_KEGG_ORGANISM = "${mod}kegg_organism";
$TBBL_KEGG_GENE = "${mod}kegg_gene";
$TBBL_KEGG_PATHWAY_GENES = "${mod}kegg_pathway_genes";

$TBBL_ORTHOLOG  = "${mod}ortholog";
$TBBL_ORGANISM_NAMESPACE = "${mod}organism_namespace";
1;
