package SBEAMS::Connection::DBConnector;

###############################################################################
# Program     : SBEAMS::Connection::DBConnector
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               connections to the database.
#
###############################################################################


use strict;
use vars qw($DB_SERVER $DB_DATABASE $DB_USER $DB_PASS $DB_RO_USER $DB_RO_PASS
            $DB_DRIVER $DB_DSN $DB_TYPE $dbh
            $BIOSAP_DB $PROTEOMICS_DB $PHENOARRAY_DB $SNP_DB);
use DBI;
use SBEAMS::Connection::Settings;


###############################################################################
# DBI Connection Variables
###############################################################################
if ( $DBVERSION eq "Dev Branch 1" ) {
  $DB_SERVER   = 'mssql';
  $DB_DATABASE = 'sbeamsdev';
  $DB_USER     = 'sbeams';
  $DB_PASS     = 'SB444';
  $DB_DRIVER   = "DBI:Sybase:server=$DB_SERVER;database=$DB_DATABASE";
  $DB_TYPE     = "MS SQL Server";
  $BIOSAP_DB   = "BioSap.dbo.";
  $PROTEOMICS_DB = "Proteomics.dbo.";
  $PHENOARRAY_DB = "PhenoArray.dbo.";
  $SNP_DB      = "SNP.dbo.";

} elsif ( $DBVERSION eq "Dev Branch 2" ) {
  $DB_SERVER   = 'mssql';
  $DB_DATABASE = 'sbeams';
  $DB_USER     = 'sbeams';
  $DB_PASS     = 'SB444';
  $DB_RO_USER  = 'sbeamsro';
  $DB_RO_PASS  = 'guest';
  $DB_DRIVER   = "DBI:Sybase:server=$DB_SERVER;database=$DB_DATABASE";
  $DB_TYPE     = "MS SQL Server";
  $BIOSAP_DB   = "BioSap.dbo.";
  $PROTEOMICS_DB = "Proteomics.dbo.";
  $PHENOARRAY_DB = "PhenoArray.dbo.";
  $SNP_DB      = "SNP.dbo.";

} elsif ( $DBVERSION eq "Dev Branch 5" ) {
  $DB_SERVER   = 'mssql';
  $DB_DATABASE = 'sbeams';
  $DB_USER     = 'sbeams';
  $DB_PASS     = 'SB444';
  $DB_DRIVER   = "DBI:Sybase:server=$DB_SERVER;database=$DB_DATABASE";
  $DB_TYPE     = "MS SQL Server";
  $BIOSAP_DB   = "BioSap.dbo.";
  $PROTEOMICS_DB = "Proteomics.dbo.";
  $PHENOARRAY_DB = "PhenoArray.dbo.";
  $SNP_DB      = "SNP.dbo.";

} elsif ( $DBVERSION eq "Dev Branch 6" ) {
  $DB_SERVER   = 'mssql';
  $DB_DATABASE = 'sbeams';
  $DB_USER     = 'sbeams';
  $DB_PASS     = 'SB444';
  $DB_DRIVER   = "DBI:Sybase:server=$DB_SERVER;database=$DB_DATABASE";
  $DB_TYPE     = "MS SQL Server";
  $BIOSAP_DB   = "BioSap.dbo.";
  $PROTEOMICS_DB = "Proteomics.dbo.";
  $PHENOARRAY_DB = "PhenoArray.dbo.";
  $SNP_DB      = "SNP.dbo.";

} elsif ( $DBVERSION eq "Dev Branch 7" ) {
  $DB_SERVER   = 'mssql';
  $DB_DATABASE = 'sbeams';
  $DB_USER     = 'sbeams';
  $DB_PASS     = 'SB444';
  $DB_DRIVER   = "DBI:Sybase:server=$DB_SERVER;database=$DB_DATABASE";
  $DB_TYPE     = "MS SQL Server";
  $BIOSAP_DB   = "BioSap.dbo.";
  $PROTEOMICS_DB = "Proteomics.dbo.";
  $PHENOARRAY_DB = "PhenoArray.dbo.";
  $SNP_DB      = "SNP.dbo.";

} elsif ( $DBVERSION eq "Dev Branch 8" ) {
  $DB_SERVER   = 'mssql';
  $DB_DATABASE = 'sbeams';
  $DB_USER     = 'sbeams';
  $DB_PASS     = 'SB444';
  $DB_DRIVER   = "DBI:Sybase:server=$DB_SERVER;database=$DB_DATABASE";
  $DB_TYPE     = "MS SQL Server";
  $BIOSAP_DB   = "BioSap.dbo.";
  $PROTEOMICS_DB = "Proteomics.dbo.";
  $PHENOARRAY_DB = "PhenoArray.dbo.";
  $SNP_DB      = "SNP.dbo.";

} elsif ( $DBVERSION eq "MySQL Dev Branch 1" ) {
  $DB_SERVER   = 'mysql';
  $DB_DATABASE = 'sbeams';
  $DB_USER     = 'sbeams';
  $DB_PASS     = 'SB444';
  $DB_DRIVER   = "DBI:mysql:$DB_DATABASE:$DB_SERVER";
  $DB_TYPE     = "MySQL";
  $BIOSAP_DB   = "biosap.";
  $PROTEOMICS_DB = "proteomics.";

} else {
  $DB_SERVER   = 'mssql';
  $DB_DATABASE = 'sbeams';
  $DB_USER     = 'sbeams';
  $DB_PASS     = 'SB444';
  $DB_RO_USER  = 'sbeamsro';
  $DB_RO_PASS  = 'guest';
  $DB_DRIVER   = "DBI:Sybase:server=$DB_SERVER;database=$DB_DATABASE";
  $DB_TYPE     = "MS SQL Server";
  $BIOSAP_DB   = "BioSap.dbo.";
  $PROTEOMICS_DB = "Proteomics.dbo.";
  $PHENOARRAY_DB = "PhenoArray.dbo.";
  $SNP_DB      = "SNP.dbo.";
}



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
# db Connect
#
# Perform the actual database connection open call via DBI.  This should
# be database independent, but hasn't been tested with several databases.
# Some databases may not support the "USE databasename" syntax.
# This should never be called except by getDBHandle().
###############################################################################
sub dbConnect {
    my $self = shift;
    my %args = @_;

    my $connect_read_only = $args{'connect_read_only'} || "";

    #### Set error handling attributes
    my (%error_attr) = (
      PrintError => 0,
      RaiseError => 0
    );

    #### Try to connect to database
    my $dbh;
    if ($connect_read_only) {
      $dbh = DBI->connect("$DB_DRIVER","$DB_RO_USER","$DB_RO_PASS",\%error_attr)
        or die "$DBI::errstr";
    } else {
      $dbh = DBI->connect("$DB_DRIVER","$DB_USER","$DB_PASS",\%error_attr)
        or die "$DBI::errstr";
    }

    #### This should only be used if the database cannot be specified in
    #### the DSN string
    #$dbh->do("use $DB_DATABASE") if $DB_DATABASE;

    return $dbh;
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
# get DB Handle
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
# get DB Server
#
# Return the servername of the database
###############################################################################
sub getDBServer {
    return $DB_SERVER;
}


###############################################################################
# get DB Driver
#
# Return the driver name (DSN string) of the database connection.
###############################################################################
sub getDBDriver {
    return $DB_DRIVER;
}


###############################################################################
# get DB Type
#
# Return the Server Type of the database connection.
###############################################################################
sub getDBType {
    return $DB_TYPE;
}


###############################################################################
# getBIOSAP_DB
#
# Return the BIOSAP_DB of the database connection.
###############################################################################
sub getBIOSAP_DB {
    return $BIOSAP_DB;
}


###############################################################################
# getPROTEOMICS_DB
#
# Return the PROTEOMICS_DB of the database connection.
###############################################################################
sub getPROTEOMICS_DB {
    return $PROTEOMICS_DB;
}


###############################################################################
# getPHENOARRAY_DB
#
# Return the PHENOARRAY_DB of the database connection.
###############################################################################
sub getPHENOARRAY_DB {
    return $PHENOARRAY_DB;
}


###############################################################################
# getSNP_DB
#
# Return the SNP_DB of the database connection.
###############################################################################
sub getSNP_DB {
    return $SNP_DB;
}


###############################################################################
# get DB Database
#
# Return the database name of the connection.
###############################################################################
sub getDBDatabase {
    return $DB_DATABASE;
}


###############################################################################
# get DB User
#
# Return the username used to open the connection to the database.
###############################################################################
sub getDBUser {
    return $DB_USER;
}




###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Connection::DBConnector - Perl extension for providing a common database connection

=head1 SYNOPSIS

  Used as part of this system

    use SBEAMS::Connection;
    $adb = new SBEAMS::Connection;

    $dbh = $adb->getDBHandle();

=head1 DESCRIPTION

    This module is inherited by the SBEAMS::Connection module, 
    although it can be used on its own. Its main function
    is to provide a single database connection to be used 
    by all programs included in this application.

=head1 METHODS

=item B<getDBHandle()>

    Returns the current database handle (opening a connection if one does
    not yet exist, connected using the variables set in the DBConnector.pm
    file. 

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cut
