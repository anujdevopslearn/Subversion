package SBEAMS::Tools;

###############################################################################
# Program     : SBEAMS::Tools
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Perl Module to handle all SBEAMS - Tools specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Tools::DBInterface;
use SBEAMS::Tools::HTMLPrinter;
use SBEAMS::Tools::TableInfo;
use SBEAMS::Tools::Settings;

@ISA = qw(SBEAMS::Tools::DBInterface
          SBEAMS::Tools::HTMLPrinter
          SBEAMS::Tools::TableInfo
          SBEAMS::Tools::Settings);


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
