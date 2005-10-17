#!/usr/local/bin/perl -w

#####################################################################
# Program	: SQLTest.t
# Author	: Jeff Howbert <peak.list@verizon.net>
# $Id$
#
# Description	: This script exercises specific SQL statements in a
#		  variety of modules, primarily to confirm they
#		  execute correctly when passed to different SQL
#		  engines.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public
# License (GPL) version 2 as published by the Free Software
# Foundation.  It is provided WITHOUT ANY WARRANTY.  See the full
# description of GPL terms in the LICENSE file distributed with this
# software.
#####################################################################

use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );         # path to SBEAMS directory
use Test::More;

my @args;

BEGIN {
#    print "ARGV = @ARGV\n";
    @args = @ARGV;
    if ( ! ( @args ) ) {
	@args = ( 'dev1' );
    }
    plan tests => 5 + @args;
    use_ok( 'SBEAMS::Connection' );
    use_ok( 'SBEAMS::Connection::Settings' );
    use_ok( 'SBEAMS::Connection::Tables' );
    use_ok( 'SBEAMS::Proteomics' );
    use_ok( 'SBEAMS::Proteomics::Tables' );
#    print "Before the script, there was ... BEGIN\n";
} # end BEGIN
END {
    breakdown();
} # end END

my @project_ids = ( 1, 2, 3 );   # dummy list of project ids
use vars qw ( $sbeams $prot );   # for instantiating Connection and
                                 # Proteomics objects
 
$sbeams = SBEAMS::Connection->new() ||
    die "Couldn't create new Connection object\n";
$prot = SBEAMS::Proteomics->new() ||
    die "Couldn't create new Proteomics object\n";
$prot->setSBEAMS( $sbeams );     # set main SBEAMS object

foreach my $instance ( @args ) {      # process each db instance
    if ( ! defined ( $DBCONFIG->{ $instance } ) ) {
	print "\nInstance $instance is not defined in SBEAMS.conf.\n";
	next;
    }
    $DBINSTANCE = $instance;          # set global db instance value for use
                                      #      with $DBCONFIG
    extractInstanceParams;            # call on Connection::Settings to update
                                      #      db instance parameters 
    
    print "\n#####################################################################\n";
    print "\nTesting instance $DBINSTANCE at DB_SERVER = " .
	"$DBCONFIG->{ $DBINSTANCE }->{ DB_SERVER }, " .
	"DB_DATABASE = $DBCONFIG->{ $DBINSTANCE }->{ DB_DATABASE }\n\n";

    eval { $sbeams->setNewDBHandle(); };        # force refresh of db handle to new instance

    # update db table names to correct values for this db instance
    setCoreTableNamesForPerl;                   # call on Connection::Tables
    setProteomicsTableNamesForPerl;             # call on Proteomics::Tables

    ok( callProteomicsPm(), 'called Proteomics.pm getProjectData' );
    if ( $@ ) {
	print "$@\n";
    }
    #######################################################
    # place additional calls to modules containing SQL here
    #######################################################
}

print "\n";

sub callProteomicsPm {                # make direct call to method containing SQL
    eval {
	$prot->getProjectData( projects => \@project_ids );
    };
    $@ ? return ( 0 ) : return ( 1 );
}

sub breakdown {
#    print "After the script, there was ... END\n\n";
}

################################################################################

1;

__END__

################################################################################
################################################################################
################################################################################

=head1  SQLTest.t

=head2  DESCRIPTION

This script exercises specific SQL statements in a variety of modules,
primarily to confirm they execute correctly when passed to different SQL
engines.

Executable currently located in sbeams/lib/perl/t/Core.

=head2  USAGE

Invoke on the command line as "SQLTest.t [ arg1 arg2 ... ]", where name of
script is followed zero or more arguments, each argument being the name of
a database instance used by the SBEAMS system.  The database instance names
should be the same as the names appearing as section headings in SBEAMS.conf.

Sample usages:

SQLTest.t               # defaults to "SQLTest.t dev1"
SQLTest.t mysql
SQLTest.t mssql
SQLTest.t mysql mssql
SQLTest.t dev1 mssql mysql

=head2  KNOWN BUGS AND LIMITATIONS

1) "SQLTest.t default" gives errors.
2) "SQLTest.t xxx", where xxx is not one of the database instance names
used in SBEAMS.conf, gives appropriate notification, but throws off the
count of tests.
3) Running the script with against a database instance that is valid
within SBEAMS.conf but inaccessible may cause premature termination
of the script.

=head2  AUTHOR

Jeff Howbert <peak.list@verizon.net>

=cut
