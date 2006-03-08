#!/usr/local/bin/perl -w

###############################################################################
# Program treatment.cgi    
# $Id: $
#
# Description : Form and processing logic for applying laboratory 
# manipulation or treatment to a set of samples.
#
# SBEAMS is Copyright (C) 2000-2006 Institute for Systems Biology
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
use SBEAMS::Biomarker::Tables;


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
  $params->{apply_action} ||= 'new_treatment';

  # Decision block, what type of page are we going to display?
  if ( $params->{apply_action} eq 'process_treatment' ) {
    my $status = process_treatment( $params );

    if ( $status !~ /Error/ ) { # Insertion completed OK
      $sbeams->set_page_message( msg => $status, type => 'Info' );
      $content = $biomarker->treatment_list($params);
    } else {
      # Give them back the page
      $sbeams->set_page_message( msg => $status, type => 'Error' );
      $q->delete( 'apply_action' );

# Is this superfluous?
#      print $q->redirect( $q->self_url() );
#      exit;
    }

  } elsif ( $params->{apply_action} eq 'new_treatment' ) {
    $content = treatment_form($params);

  } elsif ( $params->{apply_action} eq 'Review' ) {
    $content = verify_change( $params );

  } elsif ( $params->{apply_action} eq 'list_treatments' ) {
    $content = $biomarker->treatment_list($params);

  } elsif ( $params->{apply_action} eq 'treatment_details' ) {
    $content = treatment_details( $params );

  } else {
    $sbeams->set_page_message( msg => "Error: Unknown action specified", type => 'Error' );
    $q->delete( 'apply_action' );

    $content = '';

  }

  # Print cgi headers
  $biomarker->printPageHeader();
  # Don't think I really need this, but...
  $sbeams->printUserContext();

  print $content;
  $biomarker->printPageFooter( close_tables=>'NO');

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

sub error_redirect {
  my $msg = shift || '';
  my $type = shift || 'Error';
  $sbeams->set_page_message( msg => $msg, type => $type );
  print $q->redirct( "treatmentList.cgi" );
  exit;
}

#+
# Print treatment form
#-
sub treatment_form {

  my $params = shift;

  # hash of select lists for the form
  my %input = get_input_fields_hash( $params );

  # hash of labels for form
  my %labels = get_labels_hash( $params );

  my $ftable = SBEAMS::Connection::DataTable->new( BORDER => 0, 
                                              CELLSPACING => 2,
                                              CELLPADDING => 2
                                                 );

   my @b = $biomarker->get_form_buttons( name => 'apply_action', value => 'Review', 
                             types => [ qw(submit reset) ] );
  my $buttons = join "&nbsp;&nbsp;", @b;
  $log->info( $buttons );

  $ftable->addRow( [$labels{treat_name}, $input{treat_name},
                    $labels{experiment}, $input{experiment} ] );
  $ftable->addRow( [$labels{treat_desc}, $input{treat_desc} ] );
  $ftable->addRow( [$labels{input}, $input{input},
                    $labels{output}, $input{output}, ] );
  $ftable->addRow( [$labels{treatment}, $input{treatment}, 
                    $labels{protocol}, $input{protocol} ] );
  $ftable->addRow( [$labels{replicate}, $input{replicate}, 
                    $labels{nstring}, $input{nstring} ] );
  $ftable->addRow( [$labels{input_vol}, $input{input_vol}, 
                    $labels{output_vol}, $input{output_vol} ] );
  $ftable->addRow( [$labels{storage_loc}, $input{storage_loc}, 
                    $labels{notebook_page}, $input{notebook_page} ] );
  $ftable->addRow( [$labels{samples}, $input{samples} ] );
  $ftable->addRow( [$buttons] );

  $ftable->setColAttr( ROWS=>[2, $ftable->getRowNum() - 1 ], COLS=>[2], 
                       COLSPAN => 3 );
  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1], COLSPAN => 4,
                       ALIGN => 'LEFT' );
#  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1,2], COLSPAN => 2, 
#                       ALIGN => 'CENTER' );
#  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1], COLSPAN => 4 );
  $ftable->setColAttr( ROWS=>[1, 3..$ftable->getRowNum() - 1 ], COLS=>[1,3], 
                       ALIGN => 'RIGHT' );
  $ftable->setColAttr( ROWS=>[1..$ftable->getRowNum()], COLS=>[1], VALIGN => 'TOP' );
  $ftable->setColAttr( ROWS=>[$ftable->getRowNum()], COLS=>[1], ALIGN => 'CENTER' );

  # Get javascript for experiment/samples interaction
  my $expt_js = $biomarker->get_experiment_change_js('sample_treatment');

  # Print form
  return <<"  END";
  <H2>New sample treatment</H2><BR>
  $expt_js
  <FORM NAME=sample_treatment METHOD=POST>
  <TABLE BORDER=1 BGCOLOR='#DDDDDD'>
   <TR><TD></TD></TR>
   <TR><TD>$ftable</TD></TR>
   <TR><TD></TD></TR>
  </TABLE>
  <INPUT TYPE=HIDDEN NAME=apply_action_hidden VALUE=''>
  </FORM>
	<BR>
  END

} # end treatment_form

#+
#
#
#-
sub get_labels_hash {

  my %labels = 
    ( 
    treat_name => "<DIV TITLE='Title for prep'><B>Prep name:</B></DIV>",
    treat_desc => "<DIV TITLE='Prep description'><B>Prep description:</B></DIV>",
    experiment => "<DIV TITLE='Experiment containing samples'><B>Experiment:</B></DIV>",
    input => "<DIV TITLE='Input sample type'><B>Input type:</B></DIV>",
    output => "<DIV TITLE='Output sample type'><B>Output type:</B></DIV>",
    treatment => "<DIV TITLE='Process to be applied'><B>Treatment type:</B></DIV>",
    protocol => "<DIV TITLE='Specific protocol for treatment'><B>Protocol:</B></DIV>",
    replicate => "<DIV TITLE='Number of prep replicates'><B># replicates:</B></DIV>",
    nstring => "<DIV TITLE='String to use for reps in sample name'><B>Replicate names:</B></DIV>" ,
    input_vol => "<DIV TITLE='Input volume of samples used in prep'><B>Input volume(&mu;l):</B></DIV>" ,
    output_vol => "<DIV TITLE='Final volume of prepped samples'><B>Output volume(&mu;l):</B></DIV>" ,
    notebook_page => "<DIV TITLE='Reference notebook number/page number'><B>Notebook/page:</B></DIV>" ,
    storage_loc => "<DIV TITLE='Storage location of prepped samples'><B>Storage location:</B></DIV>" ,
    samples => "<DIV TITLE='Samples to process'><B>Prep samples:</B></DIV>" ,
    );
    return( %labels );

}

#+
# 
#-
sub get_input_fields_hash {

  my $p = shift;
  my %fields;

  # Get list of experiments from db 
  $fields{experiment} = $biomarker->get_experiment_select( writable => 1,
                                   current => [$p->{experiment_id}] );

  # Get list of treatment_types from db 
  $fields{treatment} = $biomarker->get_treatment_type_select( 
                                                        types => ['glycocap'],
                                            current => [$p->{treatment_type}] );

  error_redirect( "No experiments found, please switch projects" ) 
                                                   unless $fields{treatment};

  # Get list of sample_types from db 
  $fields{input} = $biomarker->get_sample_type_select(  current => [$p->{input_type}],
                                                  include_types => ['source'],
                                                  exclude_types => [],
                                                           name => 'input_type',
                                                     );

  # Get list of output sample_types from db 
  $fields{output} = $biomarker->get_sample_type_select( current => [$p->{output_type}], 
                                                  exclude_types => [ 'source' ],
                                                           name => 'output_type'
                                                      );

  # Get list of protcols from db 
  $fields{protocol} = $biomarker->get_protocol_select( types => ['glycocapture'],
                                                       current => [$p->{protocol_id}] );

  # Get list of acceptable name strings
  $fields{nstring} = $biomarker->get_replicate_names_select( current => [$p->{replicate_names}] );

# Set some appropriate defaults
  $p->{num_replicates} ||= 1;

  for ( qw( input_volume output_volume ) ) {
    $p->{$_} ||= DEFAULT_VOLUME;
  }

  for ( qw( notebook_page treatment_description treatment_name ) ) {
    $p->{$_} ||= '';
  }

  # Get list of acceptable name strings
  $fields{replicate} =<<"  END";
  <INPUT TYPE=TEXT NAME=num_replicates VALUE=$p->{num_replicates} SIZE=7></INPUT>
  END

  # Input volume
  $fields{input_vol} =<<"  END";
  <INPUT TYPE=TEXT NAME=input_volume VALUE=$p->{input_volume} SIZE=7></INPUT>
  END

  # Output volume
  $fields{output_vol} =<<"  END";
  <INPUT TYPE=TEXT NAME=output_volume VALUE=$p->{output_volume} SIZE=7></INPUT>
  END

  # Notebook page
  $fields{notebook_page} =<<"  END";
  <INPUT TYPE=TEXT NAME=notebook_page VALUE=$p->{notebook_page} ></INPUT>
  END

  # treatment name
  $fields{treat_name} =<<"  END";
  <INPUT TYPE=TEXT NAME=treatment_name VALUE=$p->{treatment_name} ></INPUT>
  END

  # Treatment description
  $fields{treat_desc} =<<"  END";
  <TEXTAREA NAME=treatment_description ROWS=2 COLS=64 WRAP=VIRTUAL>
  $p->{treatment_description}
  </TEXTAREA>
  END

  # Storage location
  $fields{storage_loc} = $biomarker->get_storage_loc_select();


  $fields{samples} = $biomarker->get_treatment_sample_select( types => ['glyco'],
                                                             params => $p );

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
  my $params = shift;
  my $cache = $sbeams->getSessionAttribute( key => $params->{_session_key} );
  for ( keys( %$cache ) ) {
    print STDERR "$_ => $cache->{$_}\n";
  }
  my $treat = $cache->{treatment};
#  for ( keys %$treat ) { print "$_ => $treat->{$_}<BR>"; }
  
  # Cache initial values
  my $ac = $sbeams->isAutoCommit();
  my $re = $sbeams->isRaiseError();

  # Set up transaction
  $sbeams->initiate_transaction();

  eval {
  # insert treatment record
    my $treatment_id = $biomarker->insert_treatment( data_ref => $treat );
  # insert new samples
    my $status = $biosample->insert_biosamples(    bio_group => $treat->{treatment_name},
                                                treatment_id => $treatment_id,
                                                    data_ref => $cache->{children} );
  };   # End eval block

  my $status;
  if ( $@ ) {
    print STDERR "$@\n";
    $sbeams->rollback_transaction();
    $status = "Error: Unable to create treatment/samples";
  } else { 

    # want to calculate the number of new samples created.  $cache->{children}
    # is a hash keyed by parent_biosample_id and a arrayref of individual kids
    # as a value.  
    my $cnt = scalar( keys( %{$cache->{children}} ) );
    for my $child ( keys(  %{$cache->{children}} ) ) {
      my $reps = scalar( @{$cache->{children}->{$child}} );
      $cnt = $cnt * $reps;
      last;  # Just need the first one
    }

    $status = "Successfully created treatment with $cnt new samples";
    $sbeams->commit_transaction();
  }# End eval catch-error block

  $sbeams->setAutoCommit( $ac );
  $sbeams->setRaiseError( $re );
  return $status;
}

#+
# Renders intermediate page to display summary info on 
# the changes that will occur if user approves treatment 'settings'.
#-
sub verify_change {
  my $params = shift;

  # is there an old value?
  my $old_map = {};
  if ( $params->{_session_key} ) {
    $old_map = $sbeams->getSessionAttribute( key => $params->{_session_key} );
    # Stomp old value 
    $sbeams->setSessionAttribute( key => $params->{_session_key}, value => undef );
  }
  $log->debug( "deleting session attr key => $params->{_session_key}, val was $old_map" );

  my $sample_maps = $biosample->get_treatment_mappings( p_ref => $params );

  # fetch and cache new values
  my $session_key = $sbeams->getRandomString( num_chars => 20 );
  $sbeams->setSessionAttribute( key => $session_key,  value => $sample_maps );
  $log->debug( "set new attr w/ key => $session_key, val is $sample_maps" );

  # Cache new key value
  $params->{_session_key} = $session_key;
  my $map = $sbeams->getSessionAttribute( key => $params->{_session_key} );
  $log->debug( "got new attr w/ key => $params->{_session_key}, val is $map" );
  

  my $sample_info = $biomarker->treatment_sample_content( sample_map => $sample_maps, 
                                                               p_ref => $params ); 

  my $tname = $params->{treatment_name};
  my $cnt = 0;
  if ( $params->{biosample_id} ) {
    ($cnt) = $params->{biosample_id} =~ tr/,/,/;
    $cnt++;
  }
  my $new_cnt = $cnt * $params->{num_replicates};

  my $summary_table = get_treatment_summary( p_ref => $params,
                                              cnt => $cnt,
                                              new_cnt => $new_cnt ); 
#  $summary_table->addRow( [ $sample_info ] );
#  $summary_table->setColAttr( ROWS=>[ $summary_table->getRowNum() ], COLS=>[1],
#                              COLSPAN => 4, ALIGN => 'CENTER' );

  my $ttype = $biomarker->get_treatment_type($params->{treatment_type_id});

  my $verify_message =<<"  END";
  <TABLE WIDTH=500><TR><TD>
  This shows the potential results of treatment $tname ($ttype) to the
  $cnt samples shown below.  This will result in $new_cnt samples being 
  created.  Please check this info, and click 'process samples' button if you
  wish to continue, or click 'back' to return to the form and modify any 
  information.
  </TD></TR></TABLE>
  END

  my $verify_page =<<"  END";
  <H2>Verify Samples</H2><BR>
  <P>$verify_message</P>
  <BR>
  <FORM NAME=verify_samples METHOD=POST>
  <TABLE>
  <TR><TD ALIGN=CENTER>$summary_table</TD></TR>
  <TR><TD ALIGN=CENTER>&nbsp;</TD></TR>
  <TR><TD ALIGN=CENTER>$sample_info</TD></TR>
  </TABLE>
  <img src="$HTML_BASE_DIR/images/clear.gif" width="300" height=2> 
  </FORM>
	<BR>
  END
  
  return $verify_page;
#  my $error_ref = $sample_maps->{errors};
#  my $treatment_ref = $sample_maps->{treatment};

  # Print message about how many samples were specified, and show
  # sample->sample mapping

}

sub get_treatment_summary {
  my %args = @_;
  my %p = %{$args{p_ref}};
  my $exp_name = $biomarker->get_experiment_name($p{experiment_id});
  my %label = get_labels_hash();
  my $table = SBEAMS::Connection::DataTable->new( BORDER => 1 );
  $table->addRow( [$label{experiment}, $exp_name, 
                   $label{treat_name}, $p{treatment_name} ] );
  $table->addRow( ['<B># input samples:</B>', $args{cnt}, 
                   '<B># new samples:</B>', $args{new_cnt} ] );
  $table->addRow( [$label{input_vol}, $p{input_volume}, 
                   $label{output_vol }, $p{output_volume} ] );
  $table->addRow( [$label{treat_desc}, $p{treatment_description}] );

  $table->setColAttr( ROWS=>[ $table->getRowNum() ], COLS=>[2], 
                       COLSPAN => 3 );
  $table->setColAttr( ROWS=>[1..$table->getRowNum()], COLS=>[1,3],
                       ALIGN => 'RIGHT' );
  $table->setColAttr( ROWS=>[1..$table->getRowNum()], COLS=>[2,4], 
                       ALIGN => 'LEFT' );

  return $table;
}

sub treatment_details {
  my $params = shift;
  
  my $stable = SBEAMS::Connection::DataTable->new();

  my $row = $sbeams->selectrow_hashref( <<"  END" ) || {};
  SELECT treatment_name,  treatment_type_name, treatment_description, input_volume, 
         number_fractions, notebook_page, treatment_status, 
   ( SELECT COUNT(*) FROM $TBBM_BIOSAMPLE WHERE treatment_id = $params->{treatment_id} ) AS total_samples,
   ( SELECT COUNT(distinct parent_biosample_id) FROM $TBBM_BIOSAMPLE WHERE treatment_id = $params->{treatment_id} ) AS input_samples
  FROM $TBBM_TREATMENT t JOIN  $TBBM_TREATMENT_TYPE tt ON t.treatment_type_id = tt.treatment_type_id 
  WHERE treatment_id = $params->{treatment_id}
  END

  $log->error( $sbeams->evalSQL( <<"  EBD" ) );
  SELECT treatment_name,  treatment_type_name, treatment_description, input_volume, 
         number_fractions, notebook_page, treatment_status, 
   ( SELECT COUNT(*) FROM $TBBM_BIOSAMPLE WHERE treatment_id = $params->{treatment_id} ) AS total_samples,
   ( SELECT COUNT(distinct parent_sample_id) FROM $TBBM_BIOSAMPLE WHERE treatment_id = $params->{treatment_id} ) AS input_samples
  FROM $TBBM_TREATMENT t JOIN  $TBBM_TREATMENT_TYPE tt ON t.treatment_type_id = tt.treatment_type_id 
  WHERE treatment_id = $params->{treatment_id}
  EBD

  for my $key ( keys( %$row ) ) {
    $stable->addRow( [ $key, $row->{$key} ] );
  }

  return <<"  END";
  <H1>Details for $row->{treatment_type_name} $row->{treatment_name} (ID: $params->{treatment_id})</H1>
	<BR>
  $stable
	<BR>
  END

  return;
  $sbeams->set_page_message( msg => 'Show details functionality is not yet complete', type => 'Info' );
  $q->delete( $q->param() );
  my $url = $q->self_url() . "?apply_action=list_treatments";
  print $q->redirect( $url );
  exit;
}

