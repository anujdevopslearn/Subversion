package SBEAMS::Proteomics::Settings;

###############################################################################
# Program     : SBEAMS::Proteomics::Settings
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which handles
#               setting location-dependant variables.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;

#### Begin with the main Settings.pm
use SBEAMS::Connection::Settings;


#### Set up new variables
use vars qw(@ISA @EXPORT 
    $SBEAMS_PART
);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
    $SBEAMS_PART
);


#### Define new variables
$SBEAMS_PART            = 'Proteomics';


#### Override variables from main Settings.pm
$SBEAMS_SUBDIR          = 'Proteomics';
