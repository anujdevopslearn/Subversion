package SBEAMS::GLUE::Tables;

###############################################################################
# Program     : SBEAMS::GLUE::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::GLUE module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBGL_SOURCE_DB

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBGL_SOURCE_DB

);


$TB_ORGANISM                = 'sbeams.dbo.organism';

$TBGL_SOURCE_DB             = 'toes.dbo.source_db';


