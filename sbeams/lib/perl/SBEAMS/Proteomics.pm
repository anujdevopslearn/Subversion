package SBEAMS::Proteomics;

###############################################################################
# Program     : SBEAMS::Proteomics
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Proteomics specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Proteomics::DBInterface;
use SBEAMS::Proteomics::HTMLPrinter;
use SBEAMS::Proteomics::TableInfo;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Utilities;

@ISA = qw(SBEAMS::Proteomics::DBInterface
          SBEAMS::Proteomics::HTMLPrinter
          SBEAMS::Proteomics::TableInfo
          SBEAMS::Proteomics::Settings
          SBEAMS::Proteomics::Utilities
         );


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
