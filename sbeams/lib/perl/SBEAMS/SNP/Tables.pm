package SBEAMS::SNP::Tables;

###############################################################################
# Program     : SBEAMS::SNP::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::SNP module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;


use vars qw(@ISA @EXPORT
    $TB_ORGANISM

    $TBSN_SNP_PLATE
    $TBSN_PLATE_TYPE
    $TBSN_INSTRUMENT
    $TBSN_INSTRUMENT_TYPE

    $TBSN_BIOSEQUENCE_SET
    $TBSN_BIOSEQUENCE

    $TBSN_SNP
    $TBSN_SNP_SOURCE
    $TBSN_SOURCE_VERSION
    $TBSN_SNP_INSTANCE
    $TBSN_ALLELE
    $TBSN_ALLELE_FREQUENCY
    $TBSN_ALLELE_BLAST_STATS
    $TBSN_QUERY_SEQUENCE
    $TBSN_BIOSEQUENCE_RANK_LIST
    $TBSN_ASSAY_ORDER_LIST

    $TBSN_ASSAY_REQUEST
    $TBSN_COST_SCHEME

    $TBSN_EXPORT_RESULTS
    $TBSN_MANUAL_GENOTYPE_CALL

    $TBSN_QUERY_OPTION

    $TBGT_HUMAN_STR_LOCI
    $TBGT_HUMAN_PCR_CONDITIONS

    $TBGT_MOUSE_SSR_LOCI
    $TBGT_MOUSE_PCR_CONDITIONS
    $TBGT_MOUSE_PCR_CONDITIONS2

    $TBGT_PCR_INFORMATION
    $TBGT_PCR_PROJECTS
    $TBGT_USER_INFO

    $TBGT_ASSAY_MOUSE_LOCUS_LIST
    $TBGT_ASSAY_PCR_HUMAN_LOCUS_LIST

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBSN_SNP_PLATE
    $TBSN_PLATE_TYPE
    $TBSN_INSTRUMENT
    $TBSN_INSTRUMENT_TYPE

    $TBSN_BIOSEQUENCE_SET
    $TBSN_BIOSEQUENCE

    $TBSN_SNP
    $TBSN_SNP_SOURCE
    $TBSN_SOURCE_VERSION
    $TBSN_SNP_INSTANCE
    $TBSN_ALLELE
    $TBSN_ALLELE_FREQUENCY
    $TBSN_ALLELE_BLAST_STATS
    $TBSN_QUERY_SEQUENCE
    $TBSN_BIOSEQUENCE_RANK_LIST
    $TBSN_ASSAY_ORDER_LIST

    $TBSN_ASSAY_REQUEST
    $TBSN_COST_SCHEME

    $TBSN_EXPORT_RESULTS
    $TBSN_MANUAL_GENOTYPE_CALL

    $TBSN_QUERY_OPTION

    $TBGT_HUMAN_STR_LOCI
    $TBGT_HUMAN_PCR_CONDITIONS

    $TBGT_MOUSE_SSR_LOCI
    $TBGT_MOUSE_PCR_CONDITIONS
    $TBGT_MOUSE_PCR_CONDITIONS2

    $TBGT_PCR_INFORMATION
    $TBGT_PCR_PROJECTS
    $TBGT_USER_INFO

    $TBGT_ASSAY_MOUSE_LOCUS_LIST
    $TBGT_ASSAY_PCR_HUMAN_LOCUS_LIST

);


#### Get the appropriate database prefixes for the SBEAMS core and this module
my $core = $DBPREFIX{Core};
my $mod = $DBPREFIX{SNP};

my $sequenom = 'SEQUENOM..SEQUENOM.';


$TB_ORGANISM                     = "${core}organism";
			
$TBSN_SNP_PLATE                  = "${mod}snp_plate";
$TBSN_PLATE_TYPE                 = "${mod}plate_type";
$TBSN_INSTRUMENT                 = "${mod}instrument";
$TBSN_INSTRUMENT_TYPE            = "${mod}instrument_type";

$TBSN_BIOSEQUENCE_SET            = "${mod}biosequence_set";
$TBSN_BIOSEQUENCE                = "${mod}biosequence";
			
$TBSN_SNP                        = "${mod}snp";
$TBSN_SNP_SOURCE                 = "${mod}snp_source";
$TBSN_SOURCE_VERSION             = "${mod}source_version";
$TBSN_SNP_INSTANCE               = "${mod}snp_instance";
$TBSN_ALLELE                     = "${mod}allele";
$TBSN_ALLELE_FREQUENCY           = "${mod}allele_frequency";
$TBSN_ALLELE_BLAST_STATS         = "${mod}allele_blast_stats";
$TBSN_QUERY_SEQUENCE             = "${mod}query_sequence";
$TBSN_BIOSEQUENCE_RANK_LIST      = "${mod}biosequence_rank_list";
$TBSN_ASSAY_ORDER_LIST           = "${mod}assay_order_list";
$TBSN_ASSAY_REQUEST              = "${mod}assay_request";
$TBSN_COST_SCHEME                = "${mod}cost_scheme";

$TBSN_EXPORT_RESULTS             = "${sequenom}EXPORT_RESULTS_VIEW";
$TBSN_MANUAL_GENOTYPE_CALL       = "${mod}manual_genotype_call";
			
$TBSN_QUERY_OPTION               = "${mod}query_option";
			
$TBGT_HUMAN_STR_LOCI             = 'ACCESSTEMP.dbo.human_str_loci';
$TBGT_HUMAN_PCR_CONDITIONS       = 'ACCESSTEMP.dbo.human_pcr_conditions';
			
$TBGT_MOUSE_SSR_LOCI             = 'ACCESSTEMP.dbo.mouse_ssr_loci';
$TBGT_MOUSE_PCR_CONDITIONS       = 'ACCESSTEMP.dbo.mouse_pcr_conditions';
$TBGT_MOUSE_PCR_CONDITIONS2      = 'ACCESSTEMP.dbo.mouse_pcr_conditions2';
			
$TBGT_PCR_INFORMATION            = 'ACCESSTEMP.dbo.pcr_information';
$TBGT_PCR_PROJECTS               = 'ACCESSTEMP.dbo.pcr_projects';
$TBGT_USER_INFO                  = 'ACCESSTEMP.dbo.user_info';

$TBGT_ASSAY_MOUSE_LOCUS_LIST     = 'ACCESSTEMP.dbo.pcr_assay_mouse_locus_list';
$TBGT_ASSAY_PCR_HUMAN_LOCUS_LIST = 'ACCESSTEMP.dbo.pcr_assay_human_locus_list';


