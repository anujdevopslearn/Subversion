package SBEAMS::Inkjet::DBInterface;

###############################################################################
# Program     : SBEAMS::Inkjet::DBInterface
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Inkjet module which handles
#               general communication with the database.
#
###############################################################################


use strict;
use vars qw(@ERRORS);
use CGI::Carp qw(fatalsToBrowser croak);
use DBI;



###############################################################################
# Global variables
###############################################################################


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
# 
###############################################################################

# Add stuff as appropriate



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Connection::DBControl - Perl extension for providing common database methods

=head1 SYNOPSIS

  Used as part of this system

    use SBEAMS::Connection;
    $adb = new SBEAMS::Connection;

    $dbh = $adb->getDBHandle();   

    This needs to change!

=head1 DESCRIPTION

    This module is inherited by the SBEAMS::Connection module, 
    although it can be used on its own. Its main function
    is to provide a single set of database methods to be used 
    by all programs included in this application.

=head1 METHODS

=item B<applySqlChange()>

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cut
