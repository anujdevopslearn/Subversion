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

    $TBSN_QUERY_OPTION

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBSN_BIOSEQUENCE_SET
    $TBSN_BIOSEQUENCE

    $TBSN_SNP
    $TBSN_SNP_SOURCE

    $TBSN_QUERY_OPTION

);


$TB_ORGANISM                = 'sbeams.dbo.organism';

$TBSN_BIOSEQUENCE_SET       = 'SNP.dbo.biosequence_set';
$TBSN_BIOSEQUENCE           = 'SNP.dbo.biosequence';

$TBSN_SNP                   = 'SNP.kdeutsch.snp';
$TBSN_SNP_SOURCE            = 'SNP.kdeutsch.snp_source';

$TBSN_QUERY_OPTION          = 'SNP.dbo.query_option';


