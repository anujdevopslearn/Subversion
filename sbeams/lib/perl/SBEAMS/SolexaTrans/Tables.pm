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

    $TBST_BIOSEQUENCE_TAG
    $TBST_BIOSEQUENCE_TAG_COUNT
    $TBST_BIOSEQUENCE_TAG_AMBIGUOUS

    $TBST_MISC_OPTION
    $TBST_QUERY_OPTION
    $TBST_SERVER
    $TBST_FILE_PATH

    $TBST_TREATMENT
    $TBST_COMPARISON_CONDITION
    $TBST_SOLEXA_INSTRUMENT
    $TBST_SOLEXA_REFERENCE_GENOME
    $TBST_SOLEXA_PIPELINE_RESULTS

    $TBST_SOLEXA_RUN
    $TBST_SOLEXA_RUN_PROTOCOL

    $TBST_SOLEXA_SAMPLE
    $TBST_SOLEXA_SAMPLE_PROTOCOL
    $TBST_SOLEXA_SAMPLE_PREP_KIT
    $TBST_SOLEXA_SAMPLE_TREATMENT

    $TBST_SOLEXA_FLOW_CELL
    $TBST_SOLEXA_FLOW_CELL_LANE
    $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES
    $TBST_RESTRICTION_ENZYME
);


require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBST_BIOSEQUENCE_SET
    $TBST_DBXREF
    $TBST_BIOSEQUENCE
    $TBST_BIOSEQUENCE_PROPERTY_SET

    $TBST_BIOSEQUENCE_TAG
    $TBST_BIOSEQUENCE_TAG_COUNT
    $TBST_BIOSEQUENCE_TAG_AMBIGUOUS

    $TBST_MISC_OPTION
    $TBST_QUERY_OPTION
    $TBST_SERVER
    $TBST_FILE_PATH

    $TBST_TREATMENT
    $TBST_COMPARISON_CONDITION
    $TBST_SOLEXA_INSTRUMENT
    $TBST_SOLEXA_REFERENCE_GENOME
    $TBST_SOLEXA_PIPELINE_RESULTS

    $TBST_SOLEXA_RUN
    $TBST_SOLEXA_RUN_PROTOCOL

    $TBST_SOLEXA_SAMPLE
    $TBST_SOLEXA_SAMPLE_PROTOCOL
    $TBST_SOLEXA_SAMPLE_PREP_KIT
    $TBST_SOLEXA_SAMPLE_TREATMENT

    $TBST_SOLEXA_FLOW_CELL
    $TBST_SOLEXA_FLOW_CELL_LANE
    $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES
	
    $TBST_RESTRICTION_ENZYME
);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{SolexaTrans};

my $modST = 'SolexaTrans.dbo.';

$TB_ORGANISM                   	   	= "${core}organism";

$TBST_BIOSEQUENCE_SET       		= "${modST}biosequence_set";
$TBST_DBXREF                		= "${modST}dbxref";
$TBST_BIOSEQUENCE           		= "${modST}biosequence";
$TBST_BIOSEQUENCE_PROPERTY_SET 		= "${modST}biosequence_property_set";

$TBST_BIOSEQUENCE_TAG			= "${modST}biosequence_tag";
$TBST_BIOSEQUENCE_TAG_COUNT		= "${modST}biosequence_tag_count";
$TBST_BIOSEQUENCE_TAG_AMBIGUOUS		= "${modST}biosequence_tag_ambiguous";

$TBST_MISC_OPTION			= "${modST}misc_option";
$TBST_QUERY_OPTION        		= "${modST}query_option";
$TBST_SERVER				= "${modST}server";
$TBST_FILE_PATH				= "${modST}file_path";

$TBST_TREATMENT				= "${modST}treatment";
$TBST_COMPARISON_CONDITION		= "${modST}comparison_condition";
$TBST_SOLEXA_INSTRUMENT			= "${modST}solexa_instrument";
$TBST_SOLEXA_REFERENCE_GENOME		= "${modST}solexa_reference_genome";
$TBST_SOLEXA_PIPELINE_RESULTS		= "${modST}solexa_pipeline_results";

$TBST_SOLEXA_RUN			= "${modST}solexa_run";
$TBST_SOLEXA_RUN_PROTOCOL		= "${modST}solexa_run_protocol";

$TBST_SOLEXA_SAMPLE			= "${modST}solexa_sample";
$TBST_SOLEXA_SAMPLE_PROTOCOL		= "${modST}solexa_sample_protocol";
$TBST_SOLEXA_SAMPLE_PREP_KIT		= "${modST}solexa_sample_prep_kit";
$TBST_SOLEXA_SAMPLE_TREATMENT		= "${modST}solexa_sample_treatment";

$TBST_SOLEXA_FLOW_CELL			= "${modST}solexa_flow_cell";
$TBST_SOLEXA_FLOW_CELL_LANE		= "${modST}solexa_flow_cell_lane";
$TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES	= "${modST}solexa_flow_cell_lane_samples";

$TBST_RESTRICTION_ENZYME		= "${modST}restriction_enzyme";



