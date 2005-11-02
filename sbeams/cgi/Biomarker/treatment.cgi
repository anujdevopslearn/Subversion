#!/usr/local/bin/perl

###############################################################################
# Program treatment.cgi    
# $Id: $
#
# Description : Form and processing logic for applying laboratory 
# manipulation or treatment to a set of samples.
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

{ # Main 

  my $current_username = $sbeams->Authenticate() || die "Authentication failed";

  my $params = process_params();
  $biomarker->printPageHeader();

  if ( $params->{apply_action} eq 'process_treatment' ) {
    my $status = process_treatment( $params );
    # Where to go from here? redirect?
    print $status;
  } else {
    print_treatment_form( $params );
  }
  $biomarker->printPageFooter();

} # end Main

sub process_params {
  my $params = {};
  
  # Standard SBEAMS processing
  $sbeams->parse_input_parameters( parameters_ref => $params, q => $q );

  # Process "state" parameters
  $sbeams->processStandardParameters( parameters_ref => $params );

  return $params;
}

sub print_treatment_form {

  my $params = shift;

  # hash of select lists for the form
  my %input = get_input_fields_hash( $params );

  # hash of labels for form
  my %labels = get_labels_hash( $params );

  # Don't think I really need this, but...
  $sbeams->printUserContext();

  my $sample_list = $biomarker->get_treatment_sample_list( types => ['glyco'],
                                                          params => $params );

  my $ftable = SBEAMS::Connection::DataTable->new( BORDER => 1, 
                                              CELLSPACING => 2,
                                              CELLPADDING => 2
                                                 );


  $ftable->addRow( [$labels{experiment}, $input{experiment} ] );
  $ftable->addRow( [$labels{input}, $input{input},
                    $labels{output}, $input{output}, ] );
  $ftable->addRow( [$labels{treatment}, $input{treatment}, 
                    $labels{protocol}, $input{protocol} ] );
  $ftable->addRow( [$labels{replicate}, $input{replicate}, 
                    $labels{nstring}, $input{nstring} ] );
  $ftable->addRow( [$sample_list] );

  $ftable->setColAttr( ROWS=>[1], COLS=>[2], COLSPAN => 3 );
  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1], COLSPAN => 4 );
  $ftable->setColAttr( ROWS=>[1..$ftable->getRowNum() - 1], COLS=>[1,3], ALIGN => 'RIGHT' );

  print <<"  END";
  <H1>Process Samples</H1>
  <FORM NAME=sample_treatment>
  $ftable
  </FORM>
	<BR>
  END

} # end print_treatment_form

#+
#
#
#-
sub get_labels_hash {

  my %labels = 
    ( 
    experiment => "<DIV TITLE='Experiment containing samples'><B>Experiment:</B></DIV>",
    input => "<DIV TITLE='Input sample type'><B>Input type:</B></DIV>",
    output => "<DIV TITLE='Output sample type'><B>Output type:</B></DIV>",
    treatment => "<DIV TITLE='Process to be applied'><B>Treatment type:</B></DIV>",
    protocol => "<DIV TITLE='Specific protocol for treatment'><B>Protocol:</B></DIV>",
    replicate => "<DIV TITLE='Number of prep replicates'><B># replicates:</B></DIV>",
    nstring => "<DIV TITLE='String to use for reps in sample name'><B>Replicate names:</B></DIV>" ,
    );
    return( %labels );

}


#+
#
#
#-
sub get_input_fields_hash {

  my $params = shift;
  my %fields;

  # Get list of experiments from db 
  $fields{experiment} = $biomarker->get_experiment_select( current => [], writable => 1 );

  # Get list of treatment_types from db 
  $fields{treatment} = $biomarker->get_treatment_type_select( types => ['glycocap'],
                                                        current => [] );

  # Get list of sample_types from db 
  $fields{input} = $biomarker->get_sample_type_select(  current => [],
                                                  include_types => ['source'],
                                                  exclude_types => [],
                                                           name => 'input_type',
                                                     );

  # Get list of output sample_types from db 
  $fields{output} = $biomarker->get_sample_type_select( current => [], 
                                                  exclude_types => [ 'source' ],
                                                           name => 'output_type'
                                                      );

  # Get list of protcols from db 
  $fields{protocol} = $biomarker->get_protocol_select( types => ['glycocap'],
                                                       current => [] );

  # Get list of acceptable name strings
  $fields{nstring} = $biomarker->get_replicate_names_select();

  # Get list of acceptable name strings
  $fields{replicate} = qq~
  <INPUT TYPE=TEXT NAME=replicate></INPUT>
  ~;

  return( %fields );

}

