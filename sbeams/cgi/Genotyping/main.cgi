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
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use File::Basename;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::Genotyping;
use SBEAMS::Genotyping::Settings;
use SBEAMS::Genotyping::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Genotyping;
$sbeamsMOD->setSBEAMS($sbeams);

# use CGI;
#$q = new CGI;


###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag to level n
  --testonly          Set testonly flag which simulates INSERTs/UPDATEs only

 e.g.:  $PROG_NAME --verbose 2 keyword=value

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","quiet")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "   VERBOSE = $VERBOSE\n";
  print "     QUIET = $QUIET\n";
  print "     DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
$PROGRAM_FILE_NAME = basename( $0 );
my $display_submission_details_cgi_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/Display_submission_details.cgi";

main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    #permitted_work_groups_ref=>['xxx','yyy'],
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if (defined($parameters{action}) && $parameters{action} eq "???") {
    # Some action
  } else {
    $sbeamsMOD->display_page_header();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->display_page_footer();
  }


} # end main



###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Print out the current user information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();


  #### Write some welcoming text
  print qq~

	<P>You are successfully logged into the $DBTITLE -
        $SBEAMS_PART system.  This module allows users to submit a
        new request to the Genotyping Facility, or check on the status
        of an existing request.  Please choose your tasks from the
        menu bar on the left.</P>

	<P>This system is still under active development.  Please
	report bugs, problems, difficulties, and suggestions to
        <B>kdeutsch\@systemsbiology.org</B>.</P>
  ~;


  my $html_ref = $sbeams->getMainPageTabMenu( cgi => $q );

  print qq~
  <BR>
  $$html_ref
  ~;

  my $content;
  my $project_id = $sbeams->getCurrent_project_id();

  if ( $project_id ) {
    my $sql = qq~
               SELECT experiment_id
                 FROM $TBGT_EXPERIMENT
                WHERE project_id = $project_id
    ~;

    $content = '<h2 class="med_gray_bg">Experiment Information</h2>';
    my @experiment_rows = $sbeams->selectSeveralColumns($sql);

    #### If there are experiments, display the status of each, either in an
    #### overall summary, or detailed view
    if (@experiment_rows) {

      if ($parameters{expt_format} eq "summary") {
        #make summary view
        $content .= make_experiment_summary_html(exp_results_set_aref => \@experiment_rows);
      } else {
        #make detailed view
        $content .= make_detailed_experiment_html(exp_results_set_areg => \@experiment_rows);
      }
    } else {
      if ($project_id == -99) {
        $content .= qq~	<TR><TD WIDTH="100%">You do not have access to this project.  Contact the owner of this project if you want to have access.</TD></TR>\n ~;
      } else {
        $content .= qq~	<TR><TD COLSPAN=2 class='red_bg'>No genotyping experiments registered in this project.</TD></TR> \n~;
      }
    }

  }

  #### Finish the table
  $content .= qq~
	</TABLE></TD></TR>
	</TABLE>
  ~;

  print $content;

} # end handle_request


###############################################################################
# make_experiment_summary_html
#
# Return a block of html to print a experimental summary
###############################################################################

sub make_experiment_summary_html {
	my %args = @_;
	my $results_set_array_ref = $args{exp_results_set_aref};
	
	my @rows = @{$results_set_array_ref};

#tag below with colspan=3 would be better suited as colspan=$#search_batch_rows+1, though expts are -not- sorted by number of search batches at this time


	my $content .= qq~
<TABLE BORDER=0>
<tr>
<th align=left><font color="green">- Experiment Name</font> : Description</th>
<th nowrap>View/Edit<br/>Record</th>
</tr>
    ~;
	my $experiment_status_counter = 0;
	foreach my $row (@rows) {
	  my ($experiment_id) = @{$row};

	  #### Select summary info from experiment_status
	  my $sql = qq~
	SELECT E.experiment_tag,ESS.experiment_status_state_name,ES.estimated_completion_date
	  FROM $TBGT_EXPERIMENT_STATUS ES
	 INNER JOIN $TBGT_EXPERIMENT E
	       ON ( ES.experiment_id = E.experiment_id )
         INNER JOIN $TBGT_EXPERIMENT_STATUS_STATE ESS
               ON ( ES.experiment_status_state_id = ESS.experiment_status_state_id)
	 WHERE ES.experiment_id = '$experiment_id'
	 ORDER BY E.experiment_tag
      ~;
      my @experiment_status_rows = $sbeams->selectSeveralColumns($sql);

      $experiment_status_counter++;
      if (($experiment_status_counter % 2) == 1){
	  $content .= "<TR BGCOLOR='#efefef'> \n";
      }else{
	  $content .= "<TR> \n";
      }
      $content .= qq~
	<TD NOWRAP>- <font color="green">$experiment_id</font></TD>
	<TD NOWRAP ALIGN=CENTER><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=GT_experiment&experiment_id=$experiment_id">[View/Edit]</A></TD>
      ~;

      foreach my $experiment_status_row (@experiment_status_rows) {
        my ($experiment_tag,$experiment_status_state_name,$est_completion_date) = @{$experiment_status_row};
        $content .= qq~
	  <TD>&nbsp;&nbsp;&nbsp;<font color="green">$experiment_tag</font></TD>
        ~;
      }

	  $content .= qq~
      	</TR>
      ~;
    }
	return $content;
}
