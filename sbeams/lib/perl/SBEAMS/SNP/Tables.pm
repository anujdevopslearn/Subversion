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
use vars qw(@ISA @EXPORT
    $TB_ORGANISM

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
)
;


$TB_ORGANISM                     = 'sbeams.dbo.organism';
			
$TBSN_BIOSEQUENCE_SET            = 'SNP.dbo.biosequence_set';
$TBSN_BIOSEQUENCE                = 'SNP.dbo.biosequence';
			
$TBSN_SNP                        = 'SNP.dbo.snp';
$TBSN_SNP_SOURCE                 = 'SNP.dbo.snp_source';
$TBSN_SOURCE_VERSION             = 'SNP.dbo.source_version';
$TBSN_SNP_INSTANCE               = 'SNP.dbo.snp_instance';
$TBSN_ALLELE                     = 'SNP.dbo.allele';
$TBSN_ALLELE_FREQUENCY           = 'SNP.dbo.allele_frequency';
$TBSN_ALLELE_BLAST_STATS         = 'SNP.dbo.allele_blast_stats';
$TBSN_QUERY_SEQUENCE             = 'SNP.dbo.query_sequence';
$TBSN_BIOSEQUENCE_RANK_LIST      = 'SNP.dbo.biosequence_rank_list';
			
$TBSN_QUERY_OPTION               = 'SNP.dbo.query_option';
			
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


