package SBEAMS::PhenoArray;

###############################################################################
# Program     : SBEAMS::PhenoArray
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - PhenoArray specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::PhenoArray::DBInterface;
use SBEAMS::PhenoArray::HTMLPrinter;
use SBEAMS::PhenoArray::TableInfo;
use SBEAMS::PhenoArray::Settings;

@ISA = qw(SBEAMS::PhenoArray::DBInterface
          SBEAMS::PhenoArray::HTMLPrinter
          SBEAMS::PhenoArray::TableInfo
          SBEAMS::PhenoArray::Settings);


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
