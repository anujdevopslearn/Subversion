package SBEAMS::SNP;

###############################################################################
# Program     : SBEAMS::SNP
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - SNP specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::SNP::DBInterface;
use SBEAMS::SNP::HTMLPrinter;
use SBEAMS::SNP::TableInfo;
use SBEAMS::SNP::Settings;

@ISA = qw(SBEAMS::SNP::DBInterface
          SBEAMS::SNP::HTMLPrinter
          SBEAMS::SNP::TableInfo
          SBEAMS::SNP::Settings);


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
