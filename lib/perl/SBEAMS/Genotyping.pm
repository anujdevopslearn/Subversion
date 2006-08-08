package SBEAMS::Genotyping;

###############################################################################
# Program     : SBEAMS::Genotyping
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Genotyping specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Genotyping::DBInterface;
use SBEAMS::Genotyping::HTMLPrinter;
use SBEAMS::Genotyping::TableInfo;
use SBEAMS::Genotyping::Settings;

@ISA = qw(SBEAMS::Genotyping::DBInterface
          SBEAMS::Genotyping::HTMLPrinter
          SBEAMS::Genotyping::TableInfo
          SBEAMS::Genotyping::Settings);


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
