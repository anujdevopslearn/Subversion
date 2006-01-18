package SBEAMS::Glycopeptide;

###############################################################################
# Program     : SBEAMS::Glycopeptide
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Glycopeptide specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Glycopeptide::DBInterface;
use SBEAMS::Glycopeptide::HTMLPrinter;
use SBEAMS::Glycopeptide::TableInfo;
use SBEAMS::Glycopeptide::Settings;

@ISA = qw(SBEAMS::Glycopeptide::DBInterface
          SBEAMS::Glycopeptide::HTMLPrinter
          SBEAMS::Glycopeptide::TableInfo
          SBEAMS::Glycopeptide::Settings);


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
