#!/usr/local/bin/perl

###############################################################################
# $Id: peptideSearch.cgi 4280 2006-01-13 06:02:10Z dcampbel $
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use CGI::Carp qw(fatalsToBrowser croak);
use Data::Dumper;

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::Glycopeptide;
use SBEAMS::Glycopeptide::Settings;
use SBEAMS::Glycopeptide::Tables;

use SBEAMS::Glycopeptide::Get_glyco_seqs;
use SBEAMS::Glycopeptide::Glyco_query;

# Global Variables
###############################################################################
#
my $sbeams = new SBEAMS::Connection;
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

my $sbeamsMOD = new SBEAMS::Glycopeptide;
$sbeamsMOD->setSBEAMS($sbeams);

my $glyco_query_o = new SBEAMS::Glycopeptide::Glyco_query;
$glyco_query_o->setSBEAMS($sbeams);

my $predicted_track_type = "Predicted Peptides";
my $id_track_type 		 = 'Identified Peptides';


main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main 
{ 
  my $current_username;
    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate(
        permitted_work_groups_ref=>['Glycopeptide_user','Glycopeptide_admin','Glycopeptide_readonly'],
        #connect_read_only=>1,
# allow_anonymous_access=>0,
    ));


    #### Read in the default input parameters
    my %parameters;
    my $n_params_found = $sbeams->parse_input_parameters(
        q=>$q,
        parameters_ref=>\%parameters
        );


    ## get project_id to send to HTMLPrinter display
    my $project_id = $sbeams->getCurrent_project_id();

    #### Process generic "state" parameters before we start
    $sbeams->processStandardParameters(parameters_ref=>\%parameters);
   
	  my $content = '<I><FONT COLOR=GREEN> Coming soon </FONT></I>';	

    $sbeamsMOD->display_page_header(project_id => $project_id);
    print $sbeams->getGifSpacer(800);
    print "$content";
		$sbeamsMOD->display_page_footer();

} # end main
       # permitted_work_groups_ref=>['Glycopeptide_user','Glycopeptide_admin',
