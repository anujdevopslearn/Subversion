package SBEAMS::BEDB::Tables;

###############################################################################
# Program     : SBEAMS::BEDB::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::BEDB module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_ORGANISM

    $TBBE_BIOSEQUENCE_SET
    $TBBE_BIOSEQUENCE

    $TBBE_EST_LIBRARY
    $TBBE_EST

    $TBBE_QUERY_OPTION

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_ORGANISM

    $TBBE_BIOSEQUENCE_SET
    $TBBE_BIOSEQUENCE

    $TBBE_EST_LIBRARY
    $TBBE_EST

    $TBBE_QUERY_OPTION

);


$TB_ORGANISM                = 'sbeams.dbo.organism';

$TBBE_BIOSEQUENCE_SET       = 'BEDB.dbo.biosequence_set';
$TBBE_BIOSEQUENCE           = 'BEDB.dbo.biosequence';

$TBBE_EST_LIBRARY           = 'BEDB.dbo.est_library';
$TBBE_EST                   = 'BEDB.dbp.est';

$TBBE_QUERY_OPTION          = 'BEDB.dbo.query_option';


