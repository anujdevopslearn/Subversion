package SBEAMS::Proteomics::Tables;

###############################################################################
# Program     : SBEAMS::Proteomics::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_PROTEIN_DATABASE
    $TB_PROTEOMICS_EXPERIMENT
    $TB_FRACTION
    $TB_SEARCH_BATCH
    $TB_SEARCH_BATCH_KEYVALUE
    $TB_SEARCH_BATCH_PARAMETER
    $TB_SEARCH
    $TB_SEARCH_HIT
    $TB_MSMS_SCAN
    $TB_MSMS_SPECTRUM

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_PROTEIN_DATABASE
    $TB_PROTEOMICS_EXPERIMENT
    $TB_FRACTION
    $TB_SEARCH_BATCH
    $TB_SEARCH_BATCH_KEYVALUE
    $TB_SEARCH_BATCH_PARAMETER
    $TB_SEARCH
    $TB_SEARCH_HIT
    $TB_MSMS_SCAN
    $TB_MSMS_SPECTRUM

);


$TB_PROTEIN_DATABASE        = 'proteomics.dbo.protein_database';
$TB_PROTEOMICS_EXPERIMENT   = 'proteomics.dbo.proteomics_experiment';
$TB_FRACTION                = 'proteomics.dbo.fraction';
$TB_SEARCH_BATCH            = 'proteomics.dbo.search_batch';
$TB_SEARCH_BATCH_KEYVALUE   = 'proteomics.dbo.search_batch_keyvalue';
$TB_SEARCH_BATCH_PARAMETER  = 'proteomics.dbo.search_batch_parameter';
$TB_SEARCH                  = 'proteomics.dbo.search';
$TB_SEARCH_HIT              = 'proteomics.dbo.search_hit';
$TB_MSMS_SCAN               = 'proteomics.dbo.msms_scan';
$TB_MSMS_SPECTRUM           = 'proteomics.dbo.msms_spectrum';







