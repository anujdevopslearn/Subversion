package SBEAMS::GEAP;

###############################################################################
# Program     : SBEAMS::GEAP
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - GEAP specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::GEAP::DBInterface;
use SBEAMS::GEAP::HTMLPrinter;
use SBEAMS::GEAP::TableInfo;
use SBEAMS::GEAP::Settings;

@ISA = qw(SBEAMS::GEAP::DBInterface
          SBEAMS::GEAP::HTMLPrinter
          SBEAMS::GEAP::TableInfo
          SBEAMS::GEAP::Settings);


###############################################################################
# Global Variables
###############################################################################
$VERSION = '0.02';


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


###############################################################################
# Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
}


###############################################################################
# Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return($sbeams);
}


###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################
