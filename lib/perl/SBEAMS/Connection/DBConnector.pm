package SBEAMS::Connection::DBConnector;

###############################################################################
# Program     : SBEAMS::Connection::DBConnector
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               connections to the database.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use DBI;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Encrypt;
use SBEAMS::Connection::Log;

use vars qw($dbh);
my $log = SBEAMS::Connection::Log->new();


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
# setNewDBHandle
#
#  Force refresh of sbeams dbhandle via dbConnect().  Any args for dbConnect
#  (such as connect_read_only) are passed through.
###############################################################################
sub setNewDBHandle {
    my $self = shift;
    my %args = @_;
    $dbh = $self->dbConnect(%args);
}

###############################################################################
# setRaiseErrorOn
#  Set attribute for the global $dbh. 
###############################################################################
sub setRaiseErrorOn {
    my $self = shift;
    $dbh->{RaiseError} = 1;
}

###############################################################################
# setRaiseErrorOff
#  Set attribute for the global $dbh. 
###############################################################################
sub setRaiseErrorOff {
    my $self = shift;
    $dbh->{RaiseError} = 0;
}

###############################################################################
# setAutoCommitOn
#  Set attribute for the global $dbh. 
###############################################################################
sub setAutoCommitOn {
    my $self = shift;
    $dbh->{AutoCommit} = 1;
}

###############################################################################
# setAutoCommitOff
#  Set attribute for the global $dbh. 
###############################################################################
sub setAutoCommitOff {
    my $self = shift;
    $dbh->{AutoCommit} = 0;
}

###############################################################################
# setDBHandle
#
#  Explicitly assign the dbhandle. 
###############################################################################
sub setDBHandle {
    my $self = shift;
    my %args = @_;
    if ( $args{dbh} ) {
      $dbh = $args{dbh};
    }
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
# dbConnect
#
# Perform the actual database connection open call via DBI.  This should
# be database independent, but hasn't been tested with many databases.
# This should never be called directly except by getDBHandle().
###############################################################################
sub dbConnect {
    my $self = shift;
    my %args = @_;

    #### Decode the argument list
    my $connect_read_only = $args{'connect_read_only'} || "";
    $log->info( "Read-only transaction" ) if $connect_read_only;

    #### Set error handling attributes
    my (%error_attr) = (
      PrintError => 0,
      RaiseError => 0
    );


    #### Get the needed connection variables
    my $DB_TYPE = $self->getDBType();
    my $DB_SERVER = $self->getDBServer();
    my $DB_DATABASE = $self->getDBDatabase();
    my $DB_USER = $self->getDBUser();
    my $DB_PASS = _getDBPass();
    my $DB_RO_USER = $self->getDBROUser();
    my $DB_RO_PASS = _getDBROPass();
    my $DB_DRIVER = $self->getDBDriver();
    my $ENC_KEY = $self->_getEncryptionKey();
    $DB_DRIVER = eval "\"$DB_DRIVER\"";

    $DBADMIN = _getDBAdmin();

    if ( !$ENC_KEY ) { # Couldn't get key.  Set bogus value so decrypt won't die
      $log->warn("WARNING: Failed to find encryption key in SBEAMS.conf"); 
      $ENC_KEY = 1;
    }
    
    # Attempt to decrypt passwords
    my $db_ro_pass = decryptPassword( pass => $DB_RO_PASS, key => $ENC_KEY );
    my $db_pass = decryptPassword(  pass => $DB_PASS , key => $ENC_KEY);

    if ( $db_pass ) { # Decryption succeeded, use decrypted passwd.
      $DB_PASS = $db_pass;
    } elsif ( !$connect_read_only ) { 
      # Decryption failed, log warning.
      $log->warn( <<"      END_WARN" );
WARNING: Decryption failed for main sbeams password. Reverting to insecure
connection mode. Please contact $DBADMIN
KEY: $ENC_KEY
      END_WARN
    }
    if ( $db_ro_pass ) { # Decryption succeeded, use decrypted passwd.
      $DB_RO_PASS = $db_ro_pass;
    } elsif ( $connect_read_only ) { # Decryption failed, log warning.
      $log->warn( <<"      END_WARN" );
WARNING: Decryption failed for read-only sbeams password. Reverting to insecure
connection mode. Please contact $DBADMIN
KEY: $ENC_KEY
      END_WARN
    }

    #### Try to connect to database
    my $this_dbh;
    if ($connect_read_only) {
      $this_dbh = DBI->connect($DB_DRIVER,$DB_RO_USER,$DB_RO_PASS,\%error_attr);
    } else {
      $this_dbh = DBI->connect($DB_DRIVER,$DB_USER,$DB_PASS,\%error_attr);
    }
    $DBADMIN ||= '';
    my $error = $DBI::errstr || '';
    if ( !$this_dbh ) {
      my $err =<<"      END_ERR";
WARNING: Database server is temporarily offline.  We hope to have this resolved quickly,  please contact $DBADMIN: if you have any questions.
      END_ERR
    $log->error( $err );
    die ( $err );
    }

    # Place any DB specific initialization calls here
    if ( !$DB_TYPE ) {

      die( 'Database type not defined, cannot continue' );
      
    } elsif ( $DB_TYPE && $DB_TYPE =~ /mysql/i ) {
      
      # Set mysql mode to honor || as concatenation symbol
      $this_dbh->do( "SET sql_mode=PIPES_AS_CONCAT" );

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
# getDBServer
#
# Return the servername of the database.
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
# set DB Type
# Cache a user-defined value in the sbeams object.
###############################################################################
sub setDBType {
  my $self = shift;
  $self->{DB_TYPE} = shift;
}

###############################################################################
# get DB Type
#
# Return the server type of the database connection.
###############################################################################
sub getDBType {
  my $self = shift;
  return $self->{DB_TYPE} || $DBCONFIG->{$DBINSTANCE}->{DB_TYPE};
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
# Return the username used to open the connection to the RDBMS.
###############################################################################
sub getDBUser {
  return $DBCONFIG->{$DBINSTANCE}->{DB_USER};
}

###############################################################################
# decryptPassword  Passed an encrypted password and an encryption key, routine
# will return decrypted password.
# 
# narg pass       encrypted password (required)
# narg key        encryption key (required)
#
# ret             decrypted password
###############################################################################
sub decryptPassword {
  my %args = @_;
  for( qw( pass key ) ) {
    die "Missing arguement $_" if !$_;
  }

  my $cryptor = SBEAMS::Connection::Encrypt->new( key => $args{key},
                                                  encrypted => $args{pass} );
  return $cryptor->decrypt();
} # End decryptPassword


###############################################################################
# _getEncryptionKey
#
# Return the password used to open the connection to the RDBMS.
###############################################################################
sub _getEncryptionKey {
  # We are using the value for INSTALL_DATE in sbeams.conf for crypt key
  my $key = $DBCONFIG->{$DBINSTANCE}->{INSTALL_DATE};

  # Can't work with undefined key string
  return undef if !defined $key;

  # Older versions of IDEA can only handle 16-bit keys; we'll get rid of 
  # spaces and :s, as they don't add much to the randomness anyway
  $key =~ s/[\s\:]//g;

  # Should we do a substring here?
  $key = substr( $key, 0, 16 ); 
  return $key;
}

###############################################################################
# _getDBPass
#
# Return the password used to open the connection to the RDBMS.
###############################################################################
sub _getDBPass {
  return $DBCONFIG->{$DBINSTANCE}->{DB_PASS};
}


###############################################################################
# getDBROUser
#
# Return the username used to open a read-only connection to the RDBMS.
###############################################################################
sub getDBROUser {
  return $DBCONFIG->{$DBINSTANCE}->{DB_RO_USER};
}


###############################################################################
# _getDBROPass
#
# Return the password used to open the connection to the RDBMS.
###############################################################################
sub _getDBROPass {
  return $DBCONFIG->{$DBINSTANCE}->{DB_RO_PASS};
}

###############################################################################
# _getDBAdmin
#
# Return the site administrator contact info.
###############################################################################
sub _getDBAdmin {
  return $DBCONFIG->{$DBINSTANCE}->{DBADMIN};
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


=item * B<dbConnect()>

    Perform the actual database connection open call via DBI.  This should
    be database independent, but has not been tested with many databases.
    This should never be called directly except by getDBHandle().


=item * B<dbDisconnect()>

    Forcibly disconnect from the RDBMS.  This is usually only necessary
    when authentication fails.


=item * B<getDBServer()>

    Return the servername of the database.


=item * B<getDBDriver()>

    Return the driver name (DSN string) of the database connection.


=item * B<getDBType()>

    Return the server type of the database connection.  This is defined
    in the conf file.  See that file for supported options.


=item * B<getBIOSAP_DB() and similar>

    This is old and fusty and should be removed in favor of a
    getModuleDatabasePrefix()


=item * B<getDBDatabase()>

    Return the database name of the connection.


=item * B<getDBUser()>

    Return the username used to open the connection to the RDBMS.


=item * B<getDBROUser()>

    Return the username used to open a read-only connection to the RDBMS.

=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

