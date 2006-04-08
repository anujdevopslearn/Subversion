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

  my $params = process_params();
  $params->{apply_action} ||= 'show form';

  if ( $params->{apply_action} eq 'Upload file' ) {
    process_upload( $params );
  } elsif ( $params->{apply_action} eq 'show form' ) {
    $biomarker->printPageHeader();
    print_upload_form( $params );
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

sub print_upload_form {
  my $params = shift;
  $sbeams->printUserContext();
  
  my $pad = '&nbsp;' x 5;
  my $namelist = $biomarker->get_experiment_select();
  my $template_link = "$pad<A HREF=$HTML_BASE_DIR/doc/Biomarker/workbook_template.xls>download template</A>";
  my @buttons = $biomarker->get_form_buttons( name => 'apply_action', 
                                             value => 'Upload file', 
                                             types => [ qw(submit reset) ] );
  my $buttons = join $pad, @buttons;

  print <<"  END";
  <H1>Upload samples</H1>
  <FORM>
  <TABLE BORDER=0>
  <TR><TD ALIGN=RIGHT><B>Experiment:</B></TD><TD>$namelist</TD></TR>
  <TR><TD ALIGN=RIGHT><B>Upload name:</B></TD><TD><INPUT TYPE=TEXT SIZE=30></TD></TR>
  <TR><TD ALIGN=RIGHT><B>Sample file:</B></TD><TD><INPUT TYPE=FILE NAME=workbook SIZE=30>$template_link</TD></TR>
  <TR><TD ALIGN=RIGHT><B>Type:</B></TD>
    <TD>$pad Excel <INPUT TYPE=RADIO NAME=type CHECKED VALUE=xls></INPUT>
    Tab-text <INPUT TYPE=RADIO NAME=type VALUE=tabtext> </INPUT></TD>
  </TR>
  <TR><TD></TD><TD ALIGN=LEFT>$buttons</TD></TR>
  </TABLE>
  </FORM>
	<BR>
  END
#<TR><TD COLSPAN=2 ALIGN=CENTER>$buttons</TD>

} # end showMainPage

sub process_upload {
  my $params = shift;
  $sbeams->set_page_message( msg => 'This functionality is not yet complete', type => 'Info' );
  $q->delete( 'apply_action' );
  $q->delete( 'workbook' );
  print $q->redirect( $q->self_url() );
  exit;
}

