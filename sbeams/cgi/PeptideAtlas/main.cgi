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

    print <<"    END";
        <BR>
    END

    my $atlas_build_id = $parameters{atlas_build_id} || '';

    my $atlas_build_name = '';

    ## only have atlas_build_name, get atlas_build_id too to pass on to neighboring cgi's
    if ( $atlas_build_id )
    {

        my $sql = qq~
            SELECT atlas_build_name
            FROM $TBAT_ATLAS_BUILD
            WHERE atlas_build_id = '$atlas_build_id'
            AND record_status != 'D'
            ~;

        #$sbeams->display_sql(sql=>$sql);

        my ($tmp) = $sbeams->selectOneColumn($sql) or
            die "Cannot complete $sql ($!)";

        if ($tmp)
        {

            $parameters{atlas_build_name} = $tmp;

        }

    }


    ## if tab menu is requested, display tabs and append parameters to PROG_NAME
#   if ( $parameters{_tab} )
#   {
        my $parameters_string = $sbeamsMOD->printTabMenu(
            parameters_ref => \%parameters,
            program_name => $PROG_NAME,
            );

        ##print "<BR>parameters_string:$parameters_string<BR>";

        $PROG_NAME = $PROG_NAME.$parameters_string;
#   }

    print "<BR>";

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

    #### Get a hash of available atlas builds
    my $sql = qq~
        SELECT atlas_build_id,atlas_build_name
        FROM $TBAT_ATLAS_BUILD
        WHERE project_id IN ( $accessible_project_ids )
        AND record_status!='D'
    ~;
    my %atlas_build_names = $sbeams->selectTwoColumnHash($sql);

    #### Get the passed parameters
    my $protein_name = $parameters{"protein_name"} || $parameters{"biosequence_name"};

    #### If no atlas_build_id has been set, choose the latest human one.
    #### FIXME. Come up with a better way of doing this.
    unless ($atlas_build_id) {
        $atlas_build_id = 48;
    }


    #### If the output_mode is HTML, then display the form
    if ($sbeams->output_mode() eq 'html') {

        print "<P>";

        print "<nobr>";


        print $q->start_form(-method=>"POST",
                             -action=>"$base_url",
                            );

        print "PeptideAtlas Build: ";

        print $q->popup_menu(-name => "atlas_build_id",
                             -values => [ keys(%atlas_build_names) ],
                             -labels => \%atlas_build_names,
                             -default => $atlas_build_id,
                            );

        print "&nbsp;&nbsp;";

        print $q->submit(-name => "query",
                         -value => 'QUERY',
                         -label => 'SELECT');

        print $q->endform;

        print "</nobr>";

        print "</P>";

    }

    $parameters{atlas_build_id} = $atlas_build_id;

    my $sql = qq~
        SELECT atlas_build_name
        FROM $TBAT_ATLAS_BUILD
        WHERE atlas_build_id = '$atlas_build_id'
        AND record_status != 'D'
        ~;

    #$sbeams->display_sql(sql=>$sql);

    my ($tmp) = $sbeams->selectOneColumn($sql) or
        die "Cannot complete $sql ($!)";

    if ($tmp)
    {

        $parameters{atlas_build_name} = $tmp;

    }


} # end showMainPage
