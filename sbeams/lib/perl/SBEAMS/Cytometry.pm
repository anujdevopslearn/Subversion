package SBEAMS::Cytometry;

###############################################################################
# Program     : SBEAMS::Cytometry
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Cytometry specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Cytometry::DBInterface;
use SBEAMS::Cytometry::HTMLPrinter;
use SBEAMS::Cytometry::TableInfo;
use SBEAMS::Cytometry::Settings;

@ISA = qw(SBEAMS::Cytometry::DBInterface
          SBEAMS::Cytometry::HTMLPrinter
          SBEAMS::Cytometry::TableInfo
          SBEAMS::Cytometry::Settings);


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
