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

    $TBPR_QUERY_OPTION
    $TBPR_BIOSEQUENCE_SET
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

    $TBPR_QUERY_OPTION
    $TBPR_BIOSEQUENCE_SET
);


$TB_ORGANISM                = 'sbeams.dbo.organism';

$TBSN_BIOSEQUENCE_SET       = 'geap.dbo.biosequence_set';
$TBSN_BIOSEQUENCE           = 'geap.dbo.biosequence';

$TBSN_SNP                   = 'geap.dbo.snp';
$TBSN_SNP_SOURCE            = 'geap.dbo.snp_source';

$TBSN_QUERY_OPTION          = 'geap.dbo.query_option';

#### BIG UGLY FUDGE
$TBPR_QUERY_OPTION          = 'proteomics.dbo.query_option';
$TBPR_BIOSEQUENCE_SET       = 'proteomics.dbo.biosequence_set';


