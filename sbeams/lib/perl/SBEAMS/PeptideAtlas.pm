package SBEAMS::PeptideAtlas;

###############################################################################
# Program     : SBEAMS::PeptideAtlas
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - PeptideAtlas specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::PeptideAtlas::DBInterface;
use SBEAMS::PeptideAtlas::HTMLPrinter;
use SBEAMS::PeptideAtlas::TableInfo;
use SBEAMS::PeptideAtlas::Settings;

@ISA = qw(SBEAMS::PeptideAtlas::DBInterface
          SBEAMS::PeptideAtlas::HTMLPrinter
          SBEAMS::PeptideAtlas::TableInfo
          SBEAMS::PeptideAtlas::Settings);


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
