#!/usr/local/bin/perl

###############################################################################
# Program     : coordinateLookup.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : CGI to allow lookup of information from a set of genome 
# coordinates
#
# SBEAMS is Copyright (C) 2000-2005 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;

use lib qw (../../lib/perl);

use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::BioLink;
use SBEAMS::BioLink::Settings;
use SBEAMS::BioLink::Tables;
use SBEAMS::BioLink::GenomeCoordinates qw( getProbesets );

my $sbeams = new SBEAMS::Connection;
my $sbeamsMOD = new SBEAMS::BioLink;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
my $cgi = new CGI;
my %params;
use constant TNAME => 'BL_coordinate_lookup';


###############################################################################
# Main Program:
###############################################################################
{

  # Authenticate, exit on failure
  exit unless ( $sbeams->Authenticate() );

  # Read input parameters, parse then into various hashes
  $sbeams->parse_input_parameters( parameters_ref => \%params, q => $cgi ); 
  my %rs_params = $sbeams->parseResultSetParams( q => $cgi );
  $params{action} ||= 'QUERY';
  $params{output_mode} ||= 'html';

  # Get some additional setup information
  my %input_types = $sbeamsMOD->returnTableInfo( TNAME ,"input_types");
  my $viewrs = ( $params{action} eq 'VIEWRESULTSET' ) ? 1 : 0;
  my $base = $cgi->url( -absolute => 1 );
  
  # What's an sbeams page without a resultset?
  my $rsref = {};

  # We're going to be needing these a lot, the extras shouldn't hurt...
  my @args = (  resultset_file       => $rs_params{set_name},
                resultset_file_ref   => \$rs_params{set_name},  # redundant much?
                rs_params_ref        => \%rs_params,  # redundant much?
                query_parameters_ref => \%params,
                parameters_ref       => \%params,  # redundant much?
                base_url             => $base, 
                input_types_ref      => \%input_types,
                TABLE_NAME           => TNAME,          
                resultset_ref        => $rsref
             );
  
  if ( $viewrs ) { # Are we viewing an existing resultset?
    $sbeams->readResultSet( @args );
  } else {  # Get resultset from GenomeCoordinates->getProbesets();
    $rsref = getProbesets( coordinate_string => $params{coordinates} );
    $args[$#args] = $rsref;
  }

  if ( $params{output_mode} ne 'html' ) {
    # Hmm, do I have to do anything here?
    $sbeams->displayResultSet( @args );

  } else { # HTML mode
    $sbeamsMOD->display_page_header(navigation_bar=>$params{navigation_bar});
    $sbeams->display_input_form( @args );

    $sbeams->display_form_buttons( TABLE_NAME => TNAME );
    addSpacing();

    # Only do the following if we have a bona fide resultset.
    if ( $rsref ) {
      $rs_params{set_name} = "SETME";
      $sbeams->writeResultSet( @args );
      $sbeams->displayResultSet( @args );
      $sbeams->displayResultSetControls( @args );
    }
    $sbeamsMOD->display_page_footer();
  }

  exit(0);

} # end main

sub addSpacing {
    print "<TR><TD></TD></TR><TR><TD></TD></TR><TR><TD></TD></TR>";
}
