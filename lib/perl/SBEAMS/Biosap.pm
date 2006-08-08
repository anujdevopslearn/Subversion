package SBEAMS::Biosap;

###############################################################################
# Program     : SBEAMS::Biosap
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Biosap specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Biosap::DBInterface;
use SBEAMS::Biosap::HTMLPrinter;
use SBEAMS::Biosap::TableInfo;
use SBEAMS::Biosap::Settings;

@ISA = qw(SBEAMS::Biosap::DBInterface
          SBEAMS::Biosap::HTMLPrinter
          SBEAMS::Biosap::TableInfo
          SBEAMS::Biosap::Settings);


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
