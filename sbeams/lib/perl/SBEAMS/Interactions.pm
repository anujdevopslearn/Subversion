package SBEAMS::Interactions;

###############################################################################
# Program     : SBEAMS::Interactions
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Interactions specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Interactions::DBInterface;
use SBEAMS::Interactions::HTMLPrinter;
use SBEAMS::Interactions::TableInfo;
use SBEAMS::Interactions::Settings;

@ISA = qw(SBEAMS::Interactions::DBInterface
          SBEAMS::Interactions::HTMLPrinter
          SBEAMS::Interactions::TableInfo
          SBEAMS::Interactions::Settings);


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
