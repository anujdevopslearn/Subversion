package SBEAMS::MicroArrayWeb;

###############################################################################
# Program     : SBEAMS::MicroArrayWeb
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Perl Module to handle all SBEAMS-MicroArray specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::MicroArrayWeb::DBInterface;
use SBEAMS::MicroArrayWeb::HTMLPrinter;
use SBEAMS::MicroArrayWeb::TableInfo;
use SBEAMS::MicroArrayWeb::Settings;

@ISA = qw(SBEAMS::MicroArrayWeb::DBInterface
          SBEAMS::MicroArrayWeb::HTMLPrinter
          SBEAMS::MicroArrayWeb::TableInfo
          SBEAMS::MicroArrayWeb::Settings);


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
