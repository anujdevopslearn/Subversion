package SBEAMS::UESC;

###############################################################################
# Program     : SBEAMS::UESC
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - UESC specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::UESC::DBInterface;
use SBEAMS::UESC::HTMLPrinter;
use SBEAMS::UESC::TableInfo;
use SBEAMS::UESC::Settings;

@ISA = qw(SBEAMS::UESC::DBInterface
          SBEAMS::UESC::HTMLPrinter
          SBEAMS::UESC::TableInfo
          SBEAMS::UESC::Settings);


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
