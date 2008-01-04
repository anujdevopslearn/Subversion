#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: main.cgi 3243 2005-03-21 09:02:00Z edeutsch $
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
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
use vars qw ($q $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
#use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;

use SBEAMS::PeptideAtlas;

use SBEAMS::Glycopeptide;
use SBEAMS::Glycopeptide::Settings;
use SBEAMS::Glycopeptide::Tables;

my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
my $glyco = new SBEAMS::Glycopeptide;
$glyco->setSBEAMS($sbeams);


###############################################################################
# Global Variables
###############################################################################
$PROGRAM_FILE_NAME = 'main.cgi';
main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate(
       # permitted_work_groups_ref=>['Glycopeptide_user','Glycopeptide_admin']
       allow_anonymous_access=>1

    ));

    # Introductory text, content;
    my $intro;
    my $content = '';

    # Auth succeeds, check that it has a peptide sequence.
    my $params = process_params();
    if ( !$params->{query_peptide_seq} ) {
      $intro =<<"      END";
      <CLASS=missing_required_parameter> Missing required parameter query_peptide_seq
      </CLASS>
      END

    } elsif ( $params->{get_content} ) {

      $content = get_content( $params );
      print $q->header();
      print <<"      EOP";
      <HTML>
        <HEAD>
        <STYLE TYPE="text/css">
         .invalid_parameter_value  {  font-family: Helvetica, Arial, sans-serif; font-size: 12pt; text-decoration: none; color: #FC0; font-style: Oblique; }
        </STYLE>
        </HEAD>
        <BODY>
        $content
        </BODY>
      </HTML>
      EOP
      exit;

    } else {

      # Get intro that describes spectrast concensus spectrum.
      $intro = get_intro();
      $content = get_iframe( $params );
#      print $intro;

    }
    
    # For now, assume this is gonna be a web page.
    $glyco->printPageHeader();
    print $sbeams->getGifSpacer(800) . "<BR>";

    print $intro;
    print $content;
    $glyco->printPageFooter();

} # end main

sub get_iframe {
  my $url = $q->self_url() . ';get_content=true';
  return "<IFRAME SRC=$url HEIGHT='960' WIDTH='840' />";
}

sub get_intro {
  return qq~ <P><DIV CLASS=section_title> View SpectraST consensus spectrum (courtesy H. Lam) </DIV></P> ~;
}

sub process_params {
  my $params = {};
  # Process parameters
  $sbeams->parse_input_parameters( parameters_ref => $params,
                                                 q => $q );
  # Process "state" parameters
  $sbeams->processStandardParameters( parameters_ref => $params );
  return $params;
}

sub get_content {

  my $params = shift;

  $params->{prefer_PAC} ||= '';

  # If so, fetch offset, else print error
  my $offset = $glyco->fetchSpectrastOffset( pep_seq => $params->{query_peptide_seq},
                                            pref_pac => $params->{prefer_PAC} );

  if ( !$offset ) {
    return <<"    END_CONTENT";
    <CLASS=invalid_parameter_value> Unable to find spectrum for peptide sequence:
      $params->{query_peptide_seq}
    </CLASS>
    END_CONTENT
  }
  
  # With offset, set iframe source to output of plotSpectrast - show timer until it shows up
  return $glyco->getSpectrastViewer( offset  => $offset, 
                                     pep_seq => $params->{query_peptide_seq});
   
} # end showMainPage


