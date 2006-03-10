package SBEAMS::SIGID;

###############################################################################
# Program     : SBEAMS::SIGID
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - SIGID specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::SIGID::DBInterface;
use SBEAMS::SIGID::HTMLPrinter;
use SBEAMS::SIGID::TableInfo;
use SBEAMS::SIGID::Settings;

@ISA = qw(SBEAMS::SIGID::DBInterface
          SBEAMS::SIGID::HTMLPrinter
          SBEAMS::SIGID::TableInfo
          SBEAMS::SIGID::Settings);


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
