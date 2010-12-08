#!/usr/local/bin/perl -w

###############################################################################
# Program	: PeptideMassCalculator.t
# Author	: Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description	: This script tests the PeptideMassCalculator module
#                 to validate some resulting masses.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public
# License (GPL) version 2 as published by the Free Software
# Foundation.  It is provided WITHOUT ANY WARRANTY.  See the full
# description of GPL terms in the LICENSE file distributed with this
# software.
###############################################################################

use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );         # path to $SBEAMS/lib/perl directory
use Test::More;


###############################################################################
# BEGIN
###############################################################################
BEGIN {
    plan tests => 8;
    use_ok( 'SBEAMS::Proteomics::PeptideMassCalculator' );
} # end BEGIN


###############################################################################
# END
###############################################################################
END {
} # end END


###############################################################################
# MAIN
###############################################################################

ok( my $calculator = SBEAMS::Proteomics::PeptideMassCalculator->new(),
  "create calculator object" );

####
my $mass;

$mass = $calculator->getPeptideMass(
				    sequence => 'QCTIPADFK',
				    mass_type => 'monoisotopic',
				   );
#print "$mass\n";
ok ( sprintf("%.4f",$mass) == 1021.4903,
     "Neutral monoisotopic mass of QCTIPADFK = 1021.4903" );

####

$mass = $calculator->getPeptideMass(
				    sequence => 'QCTIPADFK',
				    mass_type => 'average',
				   );
#print "$mass\n";
ok ( sprintf("%.4f",$mass) == 1022.1794,
     "Neutral average mass of QCTIPADFK = 1022.1794" );

####

$mass = $calculator->getPeptideMass(
				    sequence => 'QCTIPADFK',
				    mass_type => 'monoisotopic',
				    charge => 1,
				   );
#print "$mass\n";
ok ( sprintf("%.4f",$mass) == 1022.4981,
     "+1 monoisotopic mass of QCTIPADFK = 1022.4981" );

####

$mass = $calculator->getPeptideMass(
				    sequence => 'QCTIPADFK',
				    mass_type => 'monoisotopic',
				    charge => 2,
				   );
#print "$mass\n";
ok ( sprintf("%.4f",$mass) == 511.7530,
     "+2 monoisotopic mass of QCTIPADFK = 511.7530" );

####

$mass = $calculator->getPeptideMass(
				    sequence => 'QC[160]TIPADFK',
				    mass_type => 'monoisotopic',
				    charge => 2,
				   );
#print "$mass\n";
ok ( sprintf("%.4f",$mass) == 540.2637,
     "+2 monoisotopic mass of QC[160]TIPADFK = 540.2637" );

####

$mass = $calculator->getPeptideMass(
				    sequence => 'QC[160]TIPADFK',
				    mass_type => 'monoisotopic',
				    charge => 0,
				   );
#print "$mass\n";
ok ( sprintf("%.4f",$mass) == 1078.5117,
     "Neutral monoisotopic mass of QC[160]TIPADFK = 1078.5117" );

####


###############################################################################

1;

__END__

###############################################################################
###############################################################################
###############################################################################

=head1  PeptideMassCalculator.t

=head2  DESCRIPTION

This script is a crude test of the PeptideMassCalculator class

=head2  USAGE


=head2  KNOWN BUGS AND LIMITATIONS


=head2  AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=cut
