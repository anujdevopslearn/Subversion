package SBEAMS::BioLink;

###############################################################################
# Program     : SBEAMS::BioLink
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - BioLink specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::BioLink::DBInterface;
use SBEAMS::BioLink::HTMLPrinter;
use SBEAMS::BioLink::TableInfo;
use SBEAMS::BioLink::Settings;

@ISA = qw(SBEAMS::BioLink::DBInterface
          SBEAMS::BioLink::HTMLPrinter
          SBEAMS::BioLink::TableInfo
          SBEAMS::BioLink::Settings);


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
