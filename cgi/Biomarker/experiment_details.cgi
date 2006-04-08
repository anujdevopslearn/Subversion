#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# $Id: $
#
# Description : Displays info/data for a particular experiment.
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
  print_experiment_details( $params );
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

sub print_experiment_details {
  my $params = shift;
  $sbeams->printUserContext();
#  my $etable = SBEAMS::Connection::DataTable->new();
  my $details = $biomarker->get_experiment_details($params->{experiment_id});
  my $samples = $biomarker->get_experiment_samples($params->{experiment_id});
  my $experiment_name = $biomarker->get_experiment_name( $params->{experiment_id} );
  

  print <<"  END";
  <H1>Samples in $experiment_name</H1>
  $details
	<BR>
  $samples
	<BR>
  END

} # end showMainPage


