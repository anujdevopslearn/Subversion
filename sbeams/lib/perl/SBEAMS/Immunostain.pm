package SBEAMS::Immunostain;

###############################################################################
# Program     : SBEAMS::Immunostain
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Immunostain specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Immunostain::DBInterface;
use SBEAMS::Immunostain::HTMLPrinter;
use SBEAMS::Immunostain::TableInfo;
use SBEAMS::Immunostain::Settings;

@ISA = qw(SBEAMS::Immunostain::DBInterface
          SBEAMS::Immunostain::HTMLPrinter
          SBEAMS::Immunostain::TableInfo
          SBEAMS::Immunostain::Settings);


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
