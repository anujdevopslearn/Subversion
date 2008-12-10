package SBEAMS::SolexaTrans;

###############################################################################
# Program     : SBEAMS::SolexaTrans
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - SolexaTrans specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::SolexaTrans::DBInterface;
use SBEAMS::SolexaTrans::HTMLPrinter;
use SBEAMS::SolexaTrans::TableInfo;
use SBEAMS::SolexaTrans::Settings;

@ISA = qw(SBEAMS::SolexaTrans::DBInterface
          SBEAMS::SolexaTrans::HTMLPrinter
          SBEAMS::SolexaTrans::TableInfo
          SBEAMS::SolexaTrans::Settings);


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
