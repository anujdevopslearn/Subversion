package SBEAMS::MODULETEMPLATE;

###############################################################################
# Program     : SBEAMS::MODULETEMPLATE
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - MODULETEMPLATE specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::MODULETEMPLATE::DBInterface;
use SBEAMS::MODULETEMPLATE::HTMLPrinter;
use SBEAMS::MODULETEMPLATE::TableInfo;
use SBEAMS::MODULETEMPLATE::Settings;

@ISA = qw(SBEAMS::MODULETEMPLATE::DBInterface
          SBEAMS::MODULETEMPLATE::HTMLPrinter
          SBEAMS::MODULETEMPLATE::TableInfo
          SBEAMS::MODULETEMPLATE::Settings);


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
