package SBEAMS::GEAP::Tables;

###############################################################################
# Program     : SBEAMS::GEAP::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::GEAP module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_SOURCE_DB

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_SOURCE_DB

);


$TB_SOURCE_DB           = 'geap.dbo.source_db';


