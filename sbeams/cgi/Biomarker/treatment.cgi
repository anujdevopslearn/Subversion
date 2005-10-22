#!/usr/local/bin/perl

###############################################################################
# Program treatment.cgi    
# $Id: $
#
# Description : Form for describing a laboratory manipulation or treatment
# of a set of samples.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use lib qw (../../lib/perl);
use File::Basename;

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;

use SBEAMS::Biomarker;
use SBEAMS::Biomarker::Settings;

## Globals ##
my $sbeams = new SBEAMS::Connection;
my $biomarker = new SBEAMS::Biomarker;
$biomarker->setSBEAMS($sbeams);
my $program = basename( $0 );

main();


sub main { 
  my $current_username = $sbeams->Authenticate() || die "Authentication failed";

  $biomarker->printPageHeader();
  my $params = process_params();
  if ( $params->{apply_action} eq 'process_treatment' ) {
    my $status = process_treatment( $params );
    # Where to go from here? redirect?
    print $status;
  } else {
    print_treatment_form( $params );
  }
  $biomarker->printPageFooter();

} # end main

sub process_params {
  my $params = {};
  # Process parameters
  $sbeams->parse_input_parameters( parameters_ref => $params,
                                                 q => $q
                                 );
  # Process "state" parameters
  $sbeams->processStandardParameters( parameters_ref => $params );
  return $params;
}

sub print_treatment_form {
  my $params = shift;

# Don't think I need this...
#  $sbeams->printUserContext();

  my $treatment_list = $biomarker->get_treatment_select(types => ['glycocap']);

  print <<"  END";
  <H1>Process Samples</H1>
  <FORM NAME=sample_treatment>
  </FORM>
	<BR>
  END

} # end showMainPage


