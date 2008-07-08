package SBEAMS::PeptideAtlas::Settings;

###############################################################################
# Program     : SBEAMS::PeptideAtlas::Settings
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::PeptideAtlas module which handles
#               setting location-dependant variables.
#
###############################################################################


use strict;

#### Begin with the main Settings.pm
use SBEAMS::Connection::Settings( qw(:default ) );


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
$SBEAMS_PART            = 'PeptideAtlas';

#### Override variables from main Settings.pm
$SBEAMS_SUBDIR          = 'PeptideAtlas';

sub getSSRCalcDir {
  my $self = shift;
  return $CONFIG_SETTING{SSRCALC_ENV} || '/net/db/src/SSRCalc/ssrcalc';
}
