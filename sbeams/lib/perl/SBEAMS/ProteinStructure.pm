package SBEAMS::ProteinStructure;

###############################################################################
# Program     : SBEAMS::ProteinStructure
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - ProteinStructure specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::ProteinStructure::DBInterface;
use SBEAMS::ProteinStructure::HTMLPrinter;
use SBEAMS::ProteinStructure::TableInfo;
use SBEAMS::ProteinStructure::Settings;

@ISA = qw(SBEAMS::ProteinStructure::DBInterface
          SBEAMS::ProteinStructure::HTMLPrinter
          SBEAMS::ProteinStructure::TableInfo
          SBEAMS::ProteinStructure::Settings);


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
