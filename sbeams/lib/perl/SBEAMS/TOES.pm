package SBEAMS::TOES;

###############################################################################
# Program     : SBEAMS::TOES
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - TOES specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::TOES::DBInterface;
use SBEAMS::TOES::HTMLPrinter;
use SBEAMS::TOES::TableInfo;
use SBEAMS::TOES::Settings;

@ISA = qw(SBEAMS::TOES::DBInterface
          SBEAMS::TOES::HTMLPrinter
          SBEAMS::TOES::TableInfo
          SBEAMS::TOES::Settings);


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
