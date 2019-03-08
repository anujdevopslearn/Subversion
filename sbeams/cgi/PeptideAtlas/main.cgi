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

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::DataTable;
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
        'PeptideAtlas_readonly', 'PeptideAtlas_exec'],
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
#    $sbeams->printCGIParams($q);


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

#           ( SELECT COUNT(*) FROM $TBAT_PEPTIDE_INSTANCE WHERE 
#             atlas_build_id = AB.atlas_build_id AND n_observations > 1 ) AS n_distinct
#           ( SELECT SUM(n_distinct_multiobs_peptides) 
#             FROM $TBAT_SEARCH_BATCH_STATISTICS SBS JOIN
#                  $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB 
#               ON ABSB.atlas_build_search_batch_id = SBS.atlas_build_search_batch_id
#             WHERE atlas_build_id = AB.atlas_build_id ) AS n_distinct
    #### Get a list of available atlas builds
    my $sql = qq~
    SELECT AB.atlas_build_id, atlas_build_name, atlas_build_description,
           default_atlas_build_id, organism_specialized_build, organism_name,
           ( SELECT max(cumulative_n_peptides)
             FROM $TBAT_SEARCH_BATCH_STATISTICS SBS JOIN
                  $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB 
               ON ABSB.atlas_build_search_batch_id = SBS.atlas_build_search_batch_id
             WHERE atlas_build_id = AB.atlas_build_id) AS n_distinct
    FROM $TBAT_ATLAS_BUILD AB JOIN $TBAT_BIOSEQUENCE_SET BS
      ON AB.biosequence_set_id = BS.biosequence_set_id
    JOIN $TB_ORGANISM O ON BS.organism_id = O.organism_id
    LEFT JOIN $TBAT_DEFAULT_ATLAS_BUILD DAB 
      ON DAB.atlas_build_id = AB.atlas_build_id
    WHERE AB.project_id IN ( $accessible_project_ids )
		AND AB.atlas_build_id IN ( SELECT DISTINCT atlas_build_id FROM $TBAT_PEPTIDE_INSTANCE )
    AND ( DAB.record_status IS NULL OR DAB.record_status != 'D' )
    AND AB.record_status != 'D'
    AND BS.record_status != 'D'
    AND NOT ( DAB.organism_id IS NULL 
              AND default_atlas_build_id IS NOT NULL ) -- keep global default from showing up 2x
    ORDER BY organism_name ASC, 
              atlas_build_name ASC, organism_specialized_build ASC, AB.atlas_build_id DESC
    ~;
    my @atlas_builds = $sbeams->selectSeveralColumns($sql);

    my $default_build_name = '';
    foreach my $atlas_build ( @atlas_builds ) {
      if ($atlas_build->[0] == $atlas_build_id) {
      	$default_build_name = $atlas_build->[1];
      }
			$atlas_build->[2] = $sbeams->escapeXML( value => $atlas_build->[2] );
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
  my ( $tr, $link ) = $sbeams->make_table_toggle( name    => 'atlas_build_select',
                                                  visible => 0,
                                                  tooltip => 'Show/Hide Section',
                                                  imglink => 1,
                                                  textlink => 1,
                                                  tr_asref => 1,
                                                  hidetext => 'View default builds',
                                                  showtext => 'View all builds',
                                                  sticky  => 1 );

  print qq~
  <P>Below is a listing of the PeptideAtlas builds available to
  you.  Your current default build is checked.  Other
  PeptideAtlas pages will show you information from the
  selected default build.  Click on any of the radio buttons
  below to select another build as your default. Your
  selection is stored in a cookie and future accesses
  to PeptideAtlas in this session will use the selected build</P>
  <P>Your current build is: <font color="red">$default_build_name</font></P>
  $link
  ~;

  my $table = SBEAMS::Connection::DataTable->new();

  my $rows = $table->getRowNum();
  $parameters{newstyle} = 1 if !defined $parameters{newstyle};
  if ( !$parameters{newstyle} ) { # old school, name and description
    foreach my $atlas_build ( @atlas_builds ) {
      my @trinfo;
      my $selected = '';
      if ($atlas_build->[0] == $atlas_build_id) {
        $selected = 'CHECKED ';
      }
      if ( !$atlas_build->[3] ) {
        @trinfo = ( $tr =~ /(NAME)=('[^']+')\s+(ID)=('[^']+')\s+(CLASS)=('[^']+')/ );
      }

      $atlas_build->[0] =<<"      END";
      <INPUT $selected TYPE="radio" NAME="atlas_build_id" VALUE="$atlas_build->[0]" onclick=blur() onchange="switchAtlasBuild()">
      END

      $table->addRow( [@{$atlas_build}[0..2]] );
      $rows = $table->getRowNum();
      $table->setRowAttr(  COLS => [1..3], ROWS => [$rows], @trinfo );
    }
    $table->setColAttr(  COLS => [2], ROWS => [1..$rows], BGCOLOR => '#cccccc', NOWRAP => 1 );
    $table->setColAttr(  COLS => [3], ROWS => [1..$rows], BGCOLOR => '#eeeeee' );
  } else {
#    SELECT AB.atlas_build_id, atlas_build_name, atlas_build_description,
#           default_atlas_build_id, organism_specialized_build, organism_name, n_distinct

    $table->addRow( [ '', 'Build Name', '# distinct', 'Organism', 'is_def', 'Description' ] );
    $table->setRowAttr(  COLS => [1..6], ROWS => [1], BGCOLOR => '#bbbbbb', ALIGN=>'CENTER' );
    $table->setHeaderAttr( BOLD => 1 );
    foreach my $atlas_build ( @atlas_builds ) {
      my @row;
      my @trinfo;
      my $selected = '';
      my $bgcolor = '#dddddd';
      if ($atlas_build->[0] == $atlas_build_id) {
        $selected = 'CHECKED ';
      }
      if ( !$atlas_build->[3] ) {
        if ( $selected ne 'CHECKED ' ) { # We will show the current build regardless
          $log->debug( "checking is $atlas_build->[0]" );
          @trinfo = ( $tr =~ /(NAME)=('[^']+')\s+(ID)=('[^']+')\s+(CLASS)=('[^']+')/ );
        }
        $bgcolor = '#eeeeee';
      } 

      $row[1] =<<"      END";
      <A HREF=buildDetails?atlas_build_id=$atlas_build->[0] TITLE="View details of Atlas Build $atlas_build->[1]">
      $atlas_build->[1]</A>
      END
      $row[0] =<<"      END";
      <INPUT $selected TYPE="radio" NAME="atlas_build_id" VALUE="$atlas_build->[0]" onchange="switchAtlasBuild()">
      END
      $row[2] = $atlas_build->[6];
      $row[3] = $atlas_build->[5];
      $row[5] = $sbeams->truncateStringWithMouseover( string => $atlas_build->[2], len => 50 );
      $row[4] = $atlas_build->[4] || '';
      $row[4] = ( !$atlas_build->[3] ) ? 'N' : ( $row[4] ) ?
                "<SPAN CLASS=popup_help TITLE='$atlas_build->[4]'>Y</SPAN>" : 'Y';

      $table->addRow( \@row );
      $rows = $table->getRowNum();
      $table->setRowAttr(  COLS => [1..6], ROWS => [$rows], BGCOLOR => $bgcolor, @trinfo );
    }
    $table->setColAttr(  COLS => [1..6], ROWS => [1..$rows], NOWRAP => 1 );
    $table->setColAttr(  COLS => [3], ROWS => [1..$rows], ALIGN => 'RIGHT' );
    $table->setColAttr(  COLS => [4,5], ROWS => [1..$rows], ALIGN => 'CENTER' );
#    $table->setColAttr(  COLS => [3], ROWS => [1..$rows], BGCOLOR => '#eeeeee' );
  } # end else
  print "$table";
  print $q->hidden( "apply_action", '');
  print $q->end_form;

  }


} # end showMainPage
