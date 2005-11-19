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
use SBEAMS::Biomarker::Biosample;
use SBEAMS::Biomarker::Settings;


## Globals ##
my $sbeams = new SBEAMS::Connection;
my $biomarker = new SBEAMS::Biomarker;
my $biosample = new SBEAMS::Biomarker::Biosample;
my $program = basename( $0 );

$biomarker->setSBEAMS($sbeams);
$biosample->set_sbeams($sbeams);

use constant DEFAULT_VOLUME => 10;

{ # Main 

  # Authenticate user.
  my $current_username = $sbeams->Authenticate() || die "Authentication failed";

  # Process cgi parameters
  my $params = process_params();

  my $content = 'placeholder';
  $params->{apply_action} ||= 'new_run';

  # Decision block, what type of page are we going to display?
  if ( $params->{apply_action} eq 'Create run' ) {
    my $status = create_run( $params );
    
    # Where to go from here? redirect?
    # print $q->redirect( 'lcms_run_list.cgi' );

    if ( $status !~ /Error/ ) {
      $sbeams->set_page_message( msg => $status, type => 'Info' );
      $content = $biomarker->lcms_run_list($params);
    } else {
      # Give them back the page
      $sbeams->set_page_message( msg => $status, type => 'Error' );
      $q->delete( 'apply_action' );
      print $q->redirect( $q->self_url() );
      exit;
    }

  } elsif ( $params->{apply_action} eq 'list_runs'  ) {
    $content = $biomarker->lcms_run_list($params);

  } else {
    $content = get_lcms_form($params);
  }

  # Print cgi headers
  $biomarker->printPageHeader();

  # Don't think I really need this, but...
  $sbeams->printUserContext();

  print $content;
  $sbeams->printCGIParams( $q );
  $biomarker->printPageFooter();

} # end Main

#+
# Read/process CGI parameters
#-
sub process_params {
  my $params = {};

  # Standard SBEAMS processing
  $sbeams->parse_input_parameters( parameters_ref => $params, q => $q );

#for ( keys( %$params ) ){ print "$_ = $params->{$_}<BR>" } 

  # Process "state" parameters
  $sbeams->processStandardParameters( parameters_ref => $params );

  return $params;
}


#+
# Print lc/ms form
#-
sub get_lcms_form {

  my $params = shift;

  # hash of select lists for the form
  my %input = get_input_fields_hash( $params );

  # hash of labels for form
  my %labels = get_labels_hash( $params );

  my $ftable = SBEAMS::Connection::DataTable->new( BORDER => 0, 
                                              CELLSPACING => 2,
                                              CELLPADDING => 2
                                                 );

   my @b = $biomarker->get_form_buttons( name => 'apply_action', 
                                        value => 'Create run', 
                                        types => [ qw(submit reset) ] );

  my $buttons = join "&nbsp;&nbsp;", @b;
  $log->info( $buttons );

  # LC subform
  $ftable->addRow( [$labels{ms_run_name}, $input{ms_run_name},
                    $labels{treatment_id}, $input{treatment_id} ] );
  $ftable->addRow( [ $labels{lc_gradient_program}, $input{lc_gradient_program},                                        
                    $labels{injection_volume}, $input{injection_volume}, ] );
  $ftable->addRow( [$labels{lc_run_description}, $input{lc_run_description} ] );

  # MS subform
  $ftable->addRow( [$labels{ms_instrument}, $input{ms_instrument}, 
                    $labels{ms_protocol}, $input{ms_protocol} ] );
  $ftable->addRow( [$labels{nstring}, $input{nstring}, undef, undef ] );
  $ftable->addRow( [$labels{ms_run_parameters}, $input{ms_run_parameters} ] );
  $ftable->addRow( [$labels{ms_run_description}, $input{ms_run_description} ] );
  $ftable->addRow( [$labels{biosample_id}, $input{biosample_id} ] );
  $ftable->addRow( [$buttons] );

  # General caption/field rows
  $ftable->setColAttr( ROWS=>[1..8], COLS=>[1,3], ALIGN => 'RIGHT' );
  $ftable->setColAttr( ROWS=>[1..8], COLS=>[2,4], ALIGN => 'LEFT' );
  
  # description rows
  $ftable->setColAttr( ROWS=>[3,6,7,8], COLS=>[2], COLSPAN => 3 );

  # Sample row
  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1], COLSPAN => 4,
                                                      ALIGN => 'CENTER');

  # Captions
  $ftable->setColAttr( ROWS=>[1..$ftable->getRowNum()], COLS=>[1], VALIGN => 'TOP' );

  # Get javascript for experiment/samples interaction
  my $expt_js = $biomarker->get_treatment_change_js('lcms_run');

  # Return form
  return <<"  END";
  <H3>New LC/MS run</H3>
  $expt_js
  <FORM NAME=lcms_run METHOD=POST>
  <TABLE BORDER=1 BGCOLOR='#DDDDDD'>
   <TR><TD></TD></TR>
   <TR><TD>$ftable</TD></TR>
   <TR><TD></TD></TR>
  </TABLE>
  <INPUT TYPE=HIDDEN NAME=apply_action_hidden VALUE=''>
  </FORM>
	<BR>
  END

} # end get_treatment_form

#+
#
#
#-
sub get_labels_hash {
  
  return(  ms_run_name => "<DIV TITLE='Title for prep'><B>LC/MS run name:</B></DIV>",
           lc_run_description => "<DIV TITLE='Details of this particular LC run'><B>LC run desc:</B></DIV>",
           ms_run_description => "<DIV TITLE='Details of this particular MS run'><B>MS run desc:</B></DIV>",
           experiment_id => "<DIV TITLE='Experiment containing samples'><B>Experiment:</B></DIV>",
           treatment_id => "<DIV TITLE='Treatment containing samples'><B>Prep:</B></DIV>",
           injection_volume => "<DIV TITLE='Volume of sample analyzed'><B>Inj. volume:</B></DIV>",
           lc_gradient_program => "<DIV TITLE='Gradient used for chromatography'><B>LC gradient:</B></DIV>",
           ms_protocol => "<DIV TITLE='Protocol used for MS analysis'><B>MS Protocol:</B></DIV>",
           ms_instrument => "<DIV TITLE='MS instrument used'><B>Mass Spectrometer:</B></DIV>",
           nstring => "<DIV TITLE='String to use for replicates in sample name'><B>Replicate names:</B></DIV>" ,
           ms_run_parameters => "<DIV TITLE='Parameters/settings for MS'><B>MS parameters:</B></DIV>" ,
           biosample_id => "<DIV TITLE='Sample(s) run on LC/MS'><B>LC/MS sample(s):</B></DIV>"  );

}

#+
# 
#-
sub get_input_fields_hash {

  my $p = shift;
  my %fields;

  # Get list of experiments from db 
  $fields{experiment_id} = $biomarker->get_experiment_select( writable => 1,
                                   current => [$p->{experiment_id}] );

  # Get list of experiments from db 
  $fields{treatment_id} = $biomarker->get_treatment_select( writable => 1,
                                   current => [$p->{treatment_id}] );

  # Get list of gradient from db 
  $fields{lc_gradient_program} = $biomarker->get_gradient_select( types => ['glycocap'],
                                                                current => [$p->{lc_gradient_program}] );

  # Get list of ms protcols from db 
  $fields{ms_protocol} = $biomarker->get_protocol_select( types => ['mass_spec'],
                                                           name => 'ms_protocol',
                                                       current => [$p->{ms_protocol}] );

  # Get list of instruments from db 
  $fields{ms_instrument} = $biomarker->get_ms_instrument_select( types => ['mass_spec'],
                                                          current => [$p->{ms_instrument}] );

  # Get list of acceptable name strings
  $fields{nstring} = $biomarker->get_replicate_names_select( current => [$p->{replicate_names}] );

# Set some appropriate defaults
  $p->{injection_volume} ||= DEFAULT_VOLUME;

  for ( qw( ms_run_parameters ms_run_name ms_run_description lc_run_description ) ) {
    $p->{$_} ||= '';
  }

  # Injection volume
  $fields{injection_volume} =<<"  END";
  <INPUT TYPE=TEXT NAME=injection_volume VALUE=$p->{injection_volume} SIZE=7></INPUT>
  END

  # ms_run name
  $fields{ms_run_name} =<<"  END";
  <INPUT TYPE=TEXT NAME=ms_run_name VALUE=$p->{ms_run_name} ></INPUT>
  END

  # ms_run_parameters name
  $fields{ms_run_parameters} =<<"  END";
  <INPUT TYPE=TEXT NAME=ms_run_parameters VALUE=$p->{ms_run_parameters} ></INPUT>
  END

  # LC run description
  $fields{lc_run_description} =<<"  END";
  <TEXTAREA NAME=lc_run_description ROWS=2 COLS=64 WRAP=VIRTUAL>
  $p->{lc_run_description}
  </TEXTAREA>
  END

  # MS run description
  $fields{ms_run_description} =<<"  END";
  <TEXTAREA NAME=ms_run_description ROWS=2 COLS=64 WRAP=VIRTUAL>
  $p->{ms_run_description}
  </TEXTAREA>
  END

  $fields{biosample_id} = $biomarker->get_lcms_sample_select( types => ['glyco'],
                                                              params => $p );

  return( %fields );

}

#+
# Create new lcms run
#-
sub create_run {

  my $params = shift;

#  my $cache = $sbeams->getSessionAttribute( key => $params->{_session_key} );
#  for ( keys( %$cache ) ) {
#    print "$_ => $cache->{$_}<BR>";
#  }
#  my $treat = $cache->{treatment};
#  for ( keys %$treat ) { print "$_ => $treat->{$_}<BR>"; }
  
  # Cache initial values
  my $ac = $sbeams->isAutoCommit();
  my $re = $sbeams->isRaiseError();

  # Set up transaction
  $sbeams->initiate_transaction();

  eval {
    # Create new run;
    my %run; 
    for my $tag ( qw(lc_gradient_program ms_instrument ms_protocol
                     ms_run_parameters injection_volume ms_run_name 
                     lc_run_description ms_run_description ) ) {
      $run{$tag} = $params->{$tag};
      $log->error("$tag => $run{$tag}");
      print STDERR "$tag => $run{$tag}";
    }

    my $lcms_run_id = $biomarker->insert_lcms_run( data_ref => \%run );
    die 'Run creation failed' unless $lcms_run_id;

    $biosample->insert_lcms_run_samples( biosample_id => $params->{biosample_id}, 
                                         ms_run_id    => $lcms_run_id );

# S experiment_id
# S lc_gradient_program,                                        
# S ms_instrument
# S ms_protocol
# S nstring
# T ms_run_parameters
# T injection_volume
# T ms_run_name
# TA lc_run_description
# TA ms_run_description
# MS biosample_id

    # Change status of samples

  };   # End eval block

  if ( $@ ) {
    print STDERR "$@\n";
    $sbeams->rollback_transaction();
    return "Error: Unable to insert lcms run";
  }  # End eval catch-error block
  my @ids = split ',', $params->{biosample_id};
  my $cnt = scalar( @ids );
  $sbeams->commit_transaction();
  $sbeams->setAutoCommit( $ac );
  $sbeams->setRaiseError( $re );
  return "LC/MS run $params->{ms_run_name} created with $cnt samples";
}
