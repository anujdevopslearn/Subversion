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

use SBEAMS::Connection qw($q $log);
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

  my $sql =<<"  END";
SELECT biosource_name, age, organism_name, organization_id, external_id, gender, BSO.investigators, patient_id, biosource_description, tissue_type_name, bio_group_name, source_type, well_id, biosample_name, experiment_name, original_volume, location_name
  FROM $TBBM_BIOSAMPLE BSA 
    JOIN $TBBM_BIOSOURCE BSO ON BSA.biosource_id = BSO.biosource_id
    JOIN $TB_ORGANISM O ON O.organism_id = BSO.organism_id
    JOIN $TBBM_TISSUE_TYPE TT ON TT.tissue_type_id = BSO.tissue_type_id
    JOIN $TBBM_BIO_GROUP BG ON BSO.biosource_group_id = BG.bio_group_id
    JOIN $TBBM_STORAGE_LOCATION SL ON BSA.storage_location_id =  SL.storage_location_id 
    JOIN $TBBM_EXPERIMENT EX ON BSA.experiment_id =  EX.experiment_id 
  WHERE biosample_id = $params->{sample_id}
  END
  my $row = $sbeams->selectrow_hashref( $sql ) || {};
  $log->debug( $sql );

  for my $key ( keys( %$row ) ) {
    next unless defined $row->{$key};
    next if $key =~ /record_status|created_by_id|modified_by_id|date_modified|date_created|owner_group_id/;
    $stable->addRow( [ $key, $row->{$key} ] );
  }

  my $attr_sql =<<"  ENDSQL";
  SELECT A.attribute_name, BSOA.attribute_value
  FROM $TBBM_BIOSOURCE_ATTRIBUTE BSOA 
  JOIN $TBBM_ATTRIBUTE A ON A.attribute_id = BSOA.attribute_id
  WHERE BSOA.biosource_id = (SELECT biosource_id FROM $TBBM_BIOSAMPLE BSA WHERE biosample_id = $params->{sample_id} )
  ENDSQL
  
  my @attrs = $sbeams->selectSeveralColumns( $attr_sql );
  for my $attr (@attrs) {
#    next if $key =~ /record_status|created_by_id|modified_by_id|date_modified|date_created|owner_group_id/;
    if ( $attr->[1] ) {
      $stable->addRow( [ "$attr->[0] => $attr->[1]", undef ] );
    } else {
      $stable->addRow( [ "$attr->[0]", undef ] );
    }
  }


  print <<"  END";
  <H1>Details for $row->{biosample_name} (ID: $params->{sample_id})</H1>
	<BR>
  $stable
	<BR>
  END

} # end showMainPage


