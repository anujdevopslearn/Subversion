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

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_PROTEIN_DATABASE
    $TB_PROTEOMICS_EXPERIMENT

);


$TB_PROTEIN_DATABASE        = 'proteomics.dbo.protein_database';
$TB_PROTEOMICS_EXPERIMENT   = 'proteomics.dbo.proteomics_experiment';


