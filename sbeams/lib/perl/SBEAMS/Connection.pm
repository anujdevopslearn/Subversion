package SBEAMS::Connection;

###############################################################################
# Program     : SBEAMS::Connection
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Perl Module to handle all SBEAMS connection issues, including
#               authentication and DB connections.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA);


use SBEAMS::Connection::Authenticator;
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::DBInterface;
use SBEAMS::Connection::HTMLPrinter;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::Settings;


@ISA = qw(SBEAMS::Connection::Authenticator 
          SBEAMS::Connection::DBConnector
          SBEAMS::Connection::DBInterface 
          SBEAMS::Connection::HTMLPrinter
          SBEAMS::Connection::TableInfo
          SBEAMS::Connection::Settings);


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

1;

__END__
###############################################################################
###############################################################################
###############################################################################
