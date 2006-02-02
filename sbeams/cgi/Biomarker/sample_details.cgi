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
use SBEAMS::Biomarker::Tables;

## Globals ##
my $sbeams = new SBEAMS::Connection;
my $biomarker = new SBEAMS::Biomarker;
$biomarker->setSBEAMS($sbeams);
my $program = basename( $0 );

main();


sub main { 
  my $current_username = $sbeams->Authenticate() || die "Authentication failed";

  my $params = process_params();
  $biomarker->printPageHeader();
  print_sample_details( $params );
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

  unless ( $params->{sample_id} ) {
    $sbeams->set_page_message( msg => "Missing required parameter sample_id", 
                              type => 'Error' );
    print $q->redirect( 'main.cgi' );
    exit;
  }
  return $params;
}

sub print_sample_details {
  my $params = shift;
  $sbeams->printUserContext();
  my $stable = SBEAMS::Connection::DataTable->new();

  my $row = $sbeams->selectrow_hashref( <<"  END" ) || {};
  SELECT * FROM $TBBM_BIOSAMPLE
  WHERE biosample_id = $params->{sample_id}
  END

  print STDERR $sbeams->evalSQL( <<"  EBD" );
  SELECT * FROM $TBBM_BIOSAMPLE WHERE biosample_id = $params->{sample_id}
  EBD

  for my $key ( keys( %$row ) ) {
    $stable->addRow( [ $key, $row->{$key} ] );
  }
  

  print <<"  END";
  <H1>Details for $row->{biosample_name} (ID: $params->{sample_id})</H1>
	<BR>
  $stable
	<BR>
  END

} # end showMainPage


