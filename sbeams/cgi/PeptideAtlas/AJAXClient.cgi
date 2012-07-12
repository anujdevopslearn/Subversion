#!/usr/local/bin/perl

###############################################################################
# Program     : AJAXClient.cgi
# $Id: $
#
# Description : Script responds to AJAX requests from Peptide Atlas scripts and 
# returns desired information as JSON object.
#
# SBEAMS is Copyright (C) 2000-2012 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ( $q $sbeams $atlas $PROG_NAME
             $current_contact_id $current_username );
use lib qw (../../lib/perl);

use CGI::Carp qw(fatalsToBrowser croak);
use JSON;
use Data::Dumper;

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::DataTable;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

###############################################################################
# Global Variables
###############################################################################
$sbeams = new SBEAMS::Connection;
$atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

my $json = new JSON;
my %params;

main();

###############################################################################
# Main Program:
###############################################################################
sub main
{
    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ( $current_username = $sbeams->Authenticate(      connect_read_only => 1, 
                                                             allow_anonymous_access => 1 ) 
                                                           );
    #### Read in the default input parameters
    my $n_params_found = $sbeams->parse_input_parameters( q => $q, 
                                             parameters_ref => \%params
                                                        );
  print $sbeams->get_http_header();
  print process_query();

} # end main


sub process_query {

  if ( $params{source} eq 'GetTransitions_SourceSelect' ) {
    return GetTransitions_SourceSelect();
  } elsif ( $params{source} eq 'GetTransitions_ElutionTimeSelect' ) {
    return GetTransitions_ElutionTimeSelect();
  } else {
    return $params{source};
  }
}

sub GetTransitions_SourceSelect {

  my @select;

  if ( $params{pabst_build_id} && $params{pabst_build_id} =~ /^\d+$/ ) {

    my $sql = qq~
    SELECT CASE WHEN instrument_type_name = 'QQQ' THEN 'Agilent QQQ' ELSE instrument_type_name END AS instrument_type_name, IT.instrument_type_id
    FROM $TBAT_PABST_BUILD_RESOURCE PBR
    JOIN $TBAT_CONSENSUS_LIBRARY CL ON CL.consensus_library_id = PBR.resource_id
    JOIN $TBAT_INSTRUMENT_TYPE IT on IT.instrument_type_id = PBR.instrument_type_id
    WHERE resource_type = 'spectral_lib'
    AND pabst_build_id = $params{pabst_build_id} 
    AND is_source_instrument = 'Y'
    UNION ALL
    SELECT instrument_type_name, IT.instrument_type_id
    FROM $TBAT_INSTRUMENT_TYPE IT
    WHERE instrument_type_name = 'Predicted'
    ~;
		print STDERR $sql;

    my $sth = $sbeams->get_statement_handle( $sql );
    while ( my @row = $sth->fetchrow_array() ) {
      push @select, { optionValue => $row[1], optionText => $row[0] };
    }

  }

  if ( scalar( @select ) < 2 ) {
    @select = ();
    my $sql = qq~
      SELECT CASE WHEN instrument_type_name = 'QQQ' THEN 'Agilent QQQ' ELSE instrument_type_name END AS instrument_type_name, instrument_type_id
      FROM $TBAT_INSTRUMENT_TYPE
      WHERE is_source_instrument = 'Y'
    ~;
    my $sth = $sbeams->get_statement_handle( $sql );
    while ( my @row = $sth->fetchrow_array() ) {
      push @select, { optionValue => $row[1], optionText => $row[0] };
    }
  }

  my $json_text = $json->encode( \@select ); 
  return $json_text;
}


sub GetTransitions_ElutionTimeSelect {

  my @select;

  if ( $params{pabst_build_id} && $params{pabst_build_id} =~ /^\d+$/ ) {

    my $build_resources = $atlas->fetchBuildResources( pabst_build_id => $params{pabst_build_id} );

    my $resource_clause = "WHERE elution_time_type LIKE 'SSR%'";
    if ( $build_resources->{elution_time_set} ) {
      $resource_clause = " WHERE elution_time_set IN ( " . join( ',', keys( %{$build_resources->{elution_time_set}} ) ) . " ) ";
    }

    my $sql = qq~
    SELECT DISTINCT elution_time_type, ET.elution_time_type_id
    FROM $TBAT_ELUTION_TIME ET 
    JOIN $TBAT_ELUTION_TIME_TYPE ETT on ET.elution_time_type_id = ETT.elution_time_type_id
    $resource_clause
    ORDER BY elution_time_type ASC
    ~;

   $log->debug( $sql );
    

    my $sth = $sbeams->get_statement_handle( $sql );
    while ( my @row = $sth->fetchrow_array() ) {
      push @select, { optionValue => $row[1], optionText => $row[0] };
    }

  }

  my $json_text = $json->encode( \@select ); 
  $log->debug( $json_text );
  return $json_text;
}

