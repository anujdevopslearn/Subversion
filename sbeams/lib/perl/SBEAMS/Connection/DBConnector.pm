package SBEAMS::Connection::DBConnector;

###############################################################################
# Program     : SBEAMS::Connection::DBConnector
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               connections to the database.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use DBI;
use SBEAMS::Connection::Settings;

use vars qw($dbh);


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
# dbConnect
#
# Perform the actual database connection open call via DBI.  This should
# be database independent, but hasn't been tested with several databases.
# This should never be called except by getDBHandle().
###############################################################################
sub dbConnect {
    my $self = shift;
    my %args = @_;

    #### Decode the argument list
    my $connect_read_only = $args{'connect_read_only'} || "";

    #### Set error handling attributes
    my (%error_attr) = (
      PrintError => 0,
      RaiseError => 0
    );


    #### Get the needed connection variables
    my $DB_SERVER = $self->getDBServer();
    my $DB_DATABASE = $self->getDBDatabase();
    my $DB_USER = $self->getDBUser();
    my $DB_PASS = _getDBPass();
    my $DB_RO_USER = $self->getDBROUser();
    my $DB_RO_PASS = _getDBROPass();
    my $DB_DRIVER = $self->getDBDriver();
    $DB_DRIVER = eval "\"$DB_DRIVER\"";


    #### Try to connect to database
    my $this_dbh;
    if ($connect_read_only) {
      $this_dbh = DBI->connect($DB_DRIVER,$DB_RO_USER,$DB_RO_PASS,\%error_attr)
        or die "$DBI::errstr";
    } else {
      $this_dbh = DBI->connect($DB_DRIVER,$DB_USER,$DB_PASS,\%error_attr)
        or die "$DBI::errstr";
    }


    #### This should only be used if the database cannot be specified in
    #### the DSN string.  In fact, it can sometimes have a nasty side effect
    #### if used: if the Perl DBI decides to automatically open a second
    #### connection (for example to execute a query while an existing
    #### resultset is open) this bit of code may not be executed for the
    #### new connection, possibly leading to nasty confusion.
    #$this_dbh->do("use $DB_DATABASE") if $DB_DATABASE;


    return $this_dbh;
}


###############################################################################
# dbDisconnect
#
# Disconnect from the database.
###############################################################################
sub dbDisconnect {
    my $self = shift;
    $dbh->disconnect()
      or die "Error disconnecting from database: $DBI::errstr";
    return 1;
}


###############################################################################
# getDBHandle
#
# Returns the current database connection handle to be used by any query.
# If the database handle doesn't yet exist, dbConnect() is called to create
# one.
###############################################################################
sub getDBHandle {
    my $self = shift;

    $dbh = $self->dbConnect(@_) unless defined($dbh);

    return $dbh;
}


###############################################################################
# getDBServer
#
# Return the servername of the database
###############################################################################
sub getDBServer {
  return $DBCONFIG->{$DBINSTANCE}->{DB_SERVER};
}


###############################################################################
# getDBDriver
#
# Return the driver name (DSN string) of the database connection.
###############################################################################
sub getDBDriver {
  return $DBCONFIG->{$DBINSTANCE}->{DB_DRIVER};
}


###############################################################################
# get DB Type
#
# Return the Server Type of the database connection.
###############################################################################
sub getDBType {
  return $DBCONFIG->{$DBINSTANCE}->{DB_TYPE};
}


###############################################################################
# getBIOSAP_DB
#
# Return the BIOSAP_DB of the database connection.
###############################################################################
sub getBIOSAP_DB {
  return $DBCONFIG->{$DBINSTANCE}->{DBPREFIX}->{Biosap};
}


###############################################################################
# getPROTEOMICS_DB
#
# Return the PROTEOMICS_DB of the database connection.
###############################################################################
sub getPROTEOMICS_DB {
  return $DBCONFIG->{$DBINSTANCE}->{DBPREFIX}->{Proteomics};
}


###############################################################################
# getPHENOARRAY_DB
#
# Return the PHENOARRAY_DB of the database connection.
###############################################################################
sub getPHENOARRAY_DB {
  return $DBCONFIG->{$DBINSTANCE}->{DBPREFIX}->{PhenoArray};
}


###############################################################################
# getSNP_DB
#
# Return the SNP_DB of the database connection.
###############################################################################
sub getSNP_DB {
  return $DBCONFIG->{$DBINSTANCE}->{DBPREFIX}->{SNP};
}


###############################################################################
# get DB Database
#
# Return the database name of the connection.
###############################################################################
sub getDBDatabase {
  return $DBCONFIG->{$DBINSTANCE}->{DB_DATABASE};
}


###############################################################################
# getDBUser
#
# Return the username used to open the connection to the database.
###############################################################################
sub getDBUser {
  return $DBCONFIG->{$DBINSTANCE}->{DB_USER};
}


###############################################################################
# _getDBPass
#
# Return the password used to open the connection to the database.
###############################################################################
sub _getDBPass {
  return $DBCONFIG->{$DBINSTANCE}->{DB_PASS};
}


###############################################################################
# getDBROUser
#
# Return the username used to open a read-only connection to the database.
###############################################################################
sub getDBROUser {
  return $DBCONFIG->{$DBINSTANCE}->{DB_ROUSER};
}


###############################################################################
# _getDBROPass
#
# Return the password used to open the connection to the database.
###############################################################################
sub _getDBROPass {
  return $DBCONFIG->{$DBINSTANCE}->{DB_RO_PASS};
}




###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::DBConnector

SBEAMS Core database connection methods

=head2 SYNOPSIS

See SBEAMS::Connection for usage synopsis.

=head2 DESCRIPTION

This module is inherited by the SBEAMS::Connection module, although it
can be used on its own. Its main function is to provide a single
database connection to be used by all programs included in this
application.


=head2 METHODS

=over

=item * B<getDBHandle()>

    Returns the current database handle (opening a connection if one does
    not yet exist) for a connection defined in the config file.



=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

