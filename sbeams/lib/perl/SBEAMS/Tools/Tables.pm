package SBEAMS::Tools::Tables;

###############################################################################
# Program     : SBEAMS::Tools::Tables
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Tools module which provides
#               a level of abstraction to the database tables.
#
###############################################################################


use strict;
use vars qw(@ISA @EXPORT 
    $TB_BLXXXX

);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $TB_BLXXXX

);


$TB_BLXXXX              = 'protocol';


