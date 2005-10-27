#!/usr/local/bin/perl -w

#####################################################################
# Program	: SQLMethodsTest.t  (version for Proteomics module)
# Author	: Jeff Howbert <peak.list@verizon.net>
# $Id$
#
# Description	: This script exercises specific methods in
#		  the Proteomics module, primarily to confirm that
#		  the SQL in them executes correctly when passed to
#                 different database instances.
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
use lib( "$Bin/../.." );         # path to $SBEAMS/lib/perl directory
use Test::More;


###############################################################################
# BEGIN
###############################################################################
BEGIN {
    plan tests => 9;
    use_ok( 'SBEAMS::Connection' );
    use_ok( 'SBEAMS::Connection::Settings' );
    use_ok( 'SBEAMS::Connection::Tables' );
    use_ok( 'SBEAMS::Proteomics' );
    use_ok( 'SBEAMS::Proteomics::Tables' );
} # end BEGIN


###############################################################################
# END
###############################################################################
END {
    breakdown();
} # end END


###############################################################################
# MAIN
###############################################################################
use vars qw ( $sbeams $sbeamsMOD );   # for instantiating Connection and
                                      # Proteomics objects

ok($sbeams = SBEAMS::Connection->new(),"create main SBEAMS object");
ok($sbeamsMOD = SBEAMS::Proteomics->new(),"create SBEAMS Proteomics object");
$sbeamsMOD->setSBEAMS( $sbeams );     # set main SBEAMS object

#### Authenticate the current user
my $current_username;
ok($current_username = $sbeams->Authenticate(
			 permitted_work_groups_ref=>['Admin'],
			 #connect_read_only=>1,
			),"authenticate current user");



#######################################################
# Test individal methods here
#######################################################

ok( callProteomicsPm(), 'call method getProjectData()' );
if ( $@ ) {
  print "$@\n";
}






###############################################################################
# callProteomicsPm
###############################################################################
sub callProteomicsPm {              # make direct call to method containing SQL
    my @project_ids = ( 1, 2, 3 );    # dummy list of project ids
    eval {
	$sbeamsMOD->getProjectData( projects => \@project_ids );
    };
    $@ ? return ( 0 ) : return ( 1 );
}


###############################################################################
# breakdown
###############################################################################
sub breakdown {
#    print "After the script, there was ... END\n\n";
}



################################################################################

1;

__END__

################################################################################
################################################################################
################################################################################

=head1  SQLMethodsTest.t

=head2  DESCRIPTION

This script exercises specific methods in the Proteomics module, primarily
to confirm that the SQL in them executes correctly when passed to different
database instances.

Executable currently located in sbeams/lib/perl/t/Proteomics.

=head2  USAGE


=head2  KNOWN BUGS AND LIMITATIONS


=head2  AUTHOR

Jeff Howbert <peak.list@verizon.net>

=cut
