#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
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
use vars qw ($q $sbeams $sbeamsMOD $PROG_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);


###############################################################################
# Global Variables
###############################################################################
$PROG_NAME = 'main.cgi';
main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main
{
    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate(
        permitted_work_groups_ref=>['PeptideAtlas_user','PeptideAtlas_admin',
        'PeptideAtlas_readonly'],
        #connect_read_only=>1,
        allow_anonymous_access=>1,
    ));


    #### Read in the default input parameters
    my %parameters;
    my $n_params_found = $sbeams->parse_input_parameters(
        q=>$q,
        parameters_ref=>\%parameters
        );

    if ( $parameters{reset_id} && $parameters{reset_id} eq 'true' ) {
      $sbeamsMOD->clearBuildSettings();
    }

    ## get project_id to send to HTMLPrinter display
    my $project_id = $sbeamsMOD->getProjectID(
        atlas_build_name => $parameters{atlas_build_name},
        atlas_build_id => $parameters{atlas_build_id}
        );


    #### Process generic "state" parameters before we start
    $sbeams->processStandardParameters(parameters_ref=>\%parameters);
    #$sbeams->printDebuggingInfo($q);


    #### Decide what action to take based on information so far
    if ($parameters{action} eq "???") {

        # Some action
 
    } else {

        $sbeamsMOD->display_page_header(project_id => $project_id);

        handle_request(ref_parameters=>\%parameters);

        $sbeamsMOD->display_page_footer();

    }




} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub handle_request {

    my %args = @_;

    #### Process the arguments list
    my $ref_parameters = $args{'ref_parameters'}
        || die "ref_parameters not passed";

    my %parameters = %{$ref_parameters};


  #### Get the current atlas_build_id based on parameters or session
  my $atlas_build_id = $sbeamsMOD->getCurrentAtlasBuildID(
    parameters_ref => \%parameters,
  );
  if (defined($atlas_build_id) && $atlas_build_id < 0) {
    #### Don't return. Let the user pick from a valid one.
    #return;
  }


  #### Get the HTML to display the tabs
  my $tabMenu = $sbeamsMOD->getTabMenu(
    parameters_ref => \%parameters,
    program_name => $PROG_NAME,
  );
  if ($sbeams->output_mode() eq 'html') {
    print "<BR>\n";
    print $tabMenu->asHTML() if ($sbeams->output_mode() eq 'html');
    print "<BR>\n";
  }


    #### Read in the standard form values
    my $apply_action  = $parameters{'action'} || $parameters{'apply_action'};
    my $TABLE_NAME = $parameters{'QUERY_NAME'};


    #### Set some specific settings for this program
    my $PROGRAM_FILE_NAME = $PROG_NAME;
    my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME";
    my $help_url = "$CGI_BASE_DIR/help_popup.cgi";


    #### Get a list of accessible project_ids
    my @accessible_project_ids = $sbeams->getAccessibleProjects();
    my $accessible_project_ids = join( ",", @accessible_project_ids ) || '0';

    #### Get a list of available atlas builds
    my $sql = qq~
        SELECT atlas_build_id,atlas_build_name,atlas_build_description
          FROM $TBAT_ATLAS_BUILD
         WHERE project_id IN ( $accessible_project_ids )
           AND record_status!='D'
         ORDER BY atlas_build_name
    ~;
    my @atlas_builds = $sbeams->selectSeveralColumns($sql);

    my $default_build_name = '';
    foreach my $atlas_build ( @atlas_builds ) {
      if ($atlas_build->[0] == $atlas_build_id) {
	$default_build_name = $atlas_build->[1];
      }
    }

    #### If the output_mode is HTML, then display the form
    if ($sbeams->output_mode() eq 'html') {

        print qq~
        <script LANGUAGE="Javascript">
          function switchAtlasBuild() {
            document.AtlasBuildList.apply_action.value = "GO";
            document.AtlasBuildList.submit();
          }
        </script>
        ~;

        print $q->start_form(-method=>"POST",
                             -action=>"$base_url",
			     -name=>"AtlasBuildList",
                            );

	unless ($default_build_name) {
	  $default_build_name = qq~<FONT COLOR="red"> - NONE - </FONT>~;
	}

        print qq~
<P>Below is a listing of the PeptideAtlas builds available to
you.  Your current default build is checked.  Other
PeptideAtlas pages will show you information from the
selected default build.  Click on any of the radio buttons
below to select another build as your default. Your
selection is stored in a cookie and future accesses
to PeptideAtlas in this session will use the selected build</P>
<P>Your current build is: <font color="red">$default_build_name</font></P>
        ~;

        print qq~<TABLE>~;

	foreach my $atlas_build ( @atlas_builds ) {
	  my $selected = '';
	  if ($atlas_build->[0] == $atlas_build_id) {
	    $selected = 'CHECKED ';
	  }
	  print qq~
            <TR><TD><INPUT $selected TYPE="radio" NAME="atlas_build_id"
                  VALUE="$atlas_build->[0]" onchange="switchAtlasBuild()"></TD>
                <TD bgcolor="cccccc">$atlas_build->[1]</TD>
                <TD bgcolor="eeeeee">$atlas_build->[2]</TD>
            </TR>

          ~;
        }
        print "</TABLE>";

        #print $q->submit(-name => "query",
        #                 -value => 'QUERY',
        #                 -label => 'SELECT');
        print $q->hidden( "apply_action", '');

        print $q->endform;

    }


} # end showMainPage
