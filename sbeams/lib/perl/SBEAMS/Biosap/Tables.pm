package SBEAMS::Biosap::Tables;

###############################################################################
# Program     : SBEAMS::Biosap::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Biosap module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBBS_BIOSEQUENCE_SET

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBBS_BIOSEQUENCE_SET

);


$TB_ORGANISM                = 'sbeams.dbo.organism';

$TBBS_BIOSEQUENCE_SET       = 'biosap.dbo.biosequence_set';


