#!/usr/local/bin/perl -w

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

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Biomarker;
use SBEAMS::Biomarker::Settings;


## Globals ##
my $sbeams = new SBEAMS::Connection;
my $biomarker = new SBEAMS::Biomarker;
$biomarker->setSBEAMS($sbeams);
my $program = basename( $0 );


{ # Main 

  # Authenticate user.
  my $current_username = $sbeams->Authenticate() || die "Authentication failed";

  # Process cgi parameters
  my $params = process_params();
#  $sbeams->printCGIParams( $q );

  # Print cgi headers
  $biomarker->printPageHeader();

  # Decision block, what type of page are we going to display?
  if ( $params->{apply_action} eq 'process_treatment' ) {
    my $status = process_treatment( $params );
    # Where to go from here? redirect?
    print $status;

  } elsif ( $params->{apply_action} eq 'Review' ) {
    my $status = verify_change( $params );

  } else {
    print_treatment_form( $params );

  }

  $biomarker->printPageFooter();

} # end Main

#+
# Read/process CGI parameters
#-
sub process_params {
  my $params = {};
  
  # Standard SBEAMS processing
  $sbeams->parse_input_parameters( parameters_ref => $params, q => $q );

  # Process "state" parameters
  $sbeams->processStandardParameters( parameters_ref => $params );

  return $params;
}


#+
# Print treatment form
#-
sub print_treatment_form {

  my $params = shift;

  # hash of select lists for the form
  my %input = get_input_fields_hash( $params );

  # hash of labels for form
  my %labels = get_labels_hash( $params );

  # Don't think I really need this, but...
  $sbeams->printUserContext();

  my $ftable = SBEAMS::Connection::DataTable->new( BORDER => 1, 
                                              CELLSPACING => 2,
                                              CELLPADDING => 2
                                                 );

   my @b = get_form_buttons( name => 'apply_action', value => 'Review', 
                             types => [ qw(submit reset) ] );
  my $buttons = join "&nbsp;&nbsp;", @b;
  $log->info( $buttons );

  $ftable->addRow( [$labels{experiment}, $input{experiment} ] );
  $ftable->addRow( [$labels{input}, $input{input},
                    $labels{output}, $input{output}, ] );
  $ftable->addRow( [$labels{treatment}, $input{treatment}, 
                    $labels{protocol}, $input{protocol} ] );
  $ftable->addRow( [$labels{replicate}, $input{replicate}, 
                    $labels{nstring}, $input{nstring} ] );
  $ftable->addRow( [$labels{samples}, $input{samples} ] );
  $ftable->addRow( [$buttons] );

  $ftable->setColAttr( ROWS=>[1, $ftable->getRowNum()- 1 ], COLS=>[2], 
                       COLSPAN => 3 );
  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1], COLSPAN => 4,
                       ALIGN => 'LEFT' );
#  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1,2], COLSPAN => 2, 
#                       ALIGN => 'CENTER' );
#  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1], COLSPAN => 4 );
  $ftable->setColAttr( ROWS=>[1..$ftable->getRowNum() - 1 ], COLS=>[1,3], 
                       ALIGN => 'RIGHT', VALIGN => 'TOP' );

  # Get javascript for experiment/samples interaction
  my $expt_js = $biomarker->get_experiment_change_js();

  # Print form
  print <<"  END";
  <H1>Process Samples</H1>
  $expt_js
  <FORM NAME=sample_treatment>
  $ftable
  <INPUT TYPE=HIDDEN NAME=apply_action_hidden VALUE=''>
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
    samples => "<DIV TITLE='Samples to process'><B>Prep samples:</B></DIV>" ,
    );
    return( %labels );

}

#+
# 
#-
sub get_input_fields_hash {

  my $params = shift;
  my %fields;

  # Get list of experiments from db 
  $fields{experiment} = $biomarker->get_experiment_select( writable => 1,
                                   current => [$params->{experiment_id}] );

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

  $fields{samples} = $biomarker->get_treatment_sample_list( types => ['glyco'],
                                                           params => $params );

  return( %fields );

}

#+
# Returns array of HTML form buttons
#
# arg types    arrayref, required, values of submit, back, reset
# arg name     name of submit button (if any)
# arg value    value of submit button (if any)
# arg back_name     name of submit button (if any)
# arg back_value    value of submit button (if any)
# arg reset_value    value of reset button (if any)
#-
sub get_form_buttons {
  my %args = @_;
  $args{name} ||= 'Submit';
  $args{value} ||= 'Submit';
  $args{back_name} ||= 'Back';
  $args{back_value} ||= 'Back';
  $args{reset_value} ||= 'Reset';
  $args{types} ||= [];

  my @b;

  for my $type ( @{$args{types}} ) {
    push @b, "<INPUT TYPE=SUBMIT NAME=$args{name} VALUE=$args{value}>" if $type =~ /^submit$/i; 
    push @b, "<INPUT TYPE=SUBMIT NAME=$args{back_name} VALUE=$args{back_value}>" if $type =~ /^back$/i; 
    push @b, "<INPUT TYPE=RESET VALUE=$args{reset_value}>" if $type =~ /^reset$/i; 
  }
  return @b;
}

#+
# Apply user-defined changes, create new samples
#-
sub process_treatment {
  print "Process_treatment<BR>";
}

#+
# display summary page showing the changes that will occur 
#-
sub verify_change {
  my $param_ref = shift;
  my %p = %{$param_ref};

}
