package SBEAMS::BEDB;

###############################################################################
# Program     : SBEAMS::BEDB
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - BEDB specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::BEDB::DBInterface;
use SBEAMS::BEDB::HTMLPrinter;
use SBEAMS::BEDB::TableInfo;
use SBEAMS::BEDB::Settings;

@ISA = qw(SBEAMS::BEDB::DBInterface
          SBEAMS::BEDB::HTMLPrinter
          SBEAMS::BEDB::TableInfo
          SBEAMS::BEDB::Settings);


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
