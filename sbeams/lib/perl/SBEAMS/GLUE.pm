package SBEAMS::GLUE;

###############################################################################
# Program     : SBEAMS::GLUE
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - GLUE specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::GLUE::DBInterface;
use SBEAMS::GLUE::HTMLPrinter;
use SBEAMS::GLUE::TableInfo;
use SBEAMS::GLUE::Settings;

@ISA = qw(SBEAMS::GLUE::DBInterface
          SBEAMS::GLUE::HTMLPrinter
          SBEAMS::GLUE::TableInfo
          SBEAMS::GLUE::Settings);


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
