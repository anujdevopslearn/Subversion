package SBEAMS::Ontology;

###############################################################################
# Program     : SBEAMS::Ontology
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Ontology specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Ontology::DBInterface;
use SBEAMS::Ontology::HTMLPrinter;
use SBEAMS::Ontology::TableInfo;
use SBEAMS::Ontology::Settings;

@ISA = qw(SBEAMS::Ontology::DBInterface
          SBEAMS::Ontology::HTMLPrinter
          SBEAMS::Ontology::TableInfo
          SBEAMS::Ontology::Settings);


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
