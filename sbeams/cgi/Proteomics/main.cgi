#!/usr/local/bin/perl -T

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This program shows a users personal view of the data
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
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

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Proteomics;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use CGI;
$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value kay=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
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
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(
    parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
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


  #### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);
  my @rows;


  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();


  #### Get information about the current project from the database
  $sql = qq~
	SELECT UC.project_id,P.name,P.project_tag,P.project_status
	  FROM $TB_USER_CONTEXT UC
	  JOIN $TB_PROJECT P ON ( UC.project_id = P.project_id )
	 WHERE UC.contact_id = '$current_contact_id'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  my $project_id = '';
  my $project_name = 'NONE';
  my $project_tag = 'NONE';
  my $project_status = 'N/A';
  if (@rows) {
    ($project_id,$project_name,$project_tag,$project_status) = @{$rows[0]};
  }

  #### Print out some information about this project
  print qq~
	<H1>Current Project: <A class="h1" HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">$project_name</A></H1>
	<TABLE WIDTH="100%" BORDER=0>
	<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	             <TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Experiments:</B></TD></TR>
	<TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	                 <TD WIDTH="100%"><TABLE BORDER=0>
  ~;


  #### Get all the experiments for this project
  if ($project_id > 0) {
    $sql = qq~
	SELECT experiment_id,experiment_tag,experiment_name
	  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
	 WHERE project_id = '$project_id'
	 ORDER BY experiment_tag
    ~;
    @rows = $sbeams->selectSeveralColumns($sql);
  } else {
    @rows = ();
  }


  #### If there are experiments, display them
  if (@rows) {
    foreach my $row (@rows) {
      my ($experiment_id,$experiment_tag,$experiment_name) = @{$row};

      #### Find out what search_batches exist for this experiment
      $sql = qq~
	SELECT SB.search_batch_id,SB.search_batch_subdir,BSS.set_tag
	  FROM $TBPR_SEARCH_BATCH SB
	  JOIN $TBPR_BIOSEQUENCE_SET BSS
	       ON ( SB.biosequence_set_id = BSS.biosequence_set_id )
	 WHERE SB.experiment_id = '$experiment_id'
	 ORDER BY BSS.set_tag,SB.search_batch_subdir
      ~;
      my @search_batch_rows = $sbeams->selectSeveralColumns($sql);

      print qq~
	<TR><TD NOWRAP>- <font color="green">$experiment_tag:</font> $experiment_name</TD>
	<TD NOWRAP>&nbsp;&nbsp;&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment&experiment_id=$experiment_id">[View/Edit]</A></TD>
	<TD NOWRAP>&nbsp;&nbsp;&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeFractions?action=QUERYHIDE&QUERY_NAME=PR_SummarizeFractions&experiment_id=$experiment_id">[View Fractions]</A></TD>
      ~;

      foreach my $search_batch_row (@search_batch_rows) {
        my ($search_batch_id,$search_batch_subdir,$set_tag) = @{$search_batch_row};
        print qq~
	  <TD>&nbsp;&nbsp;&nbsp;<font color="green">$set_tag</font> ($search_batch_id:&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizePeptides?action=QUERY&QUERY_NAME=PR_SummarizePeptides&search_batch_id=$search_batch_id&probability_constraint=\%3E.9&n_annotations_constraint=%3E0&sort_order=tABS.row_count%20DESC&display_options=GroupReference&input_form_format=minimum_detail">P&gt;0.9</A>&nbsp;--&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizePeptides?action=QUERY&QUERY_NAME=PR_SummarizePeptides&search_batch_id=$search_batch_id&annotation_status_id=Annot&n_annotations_constraint=%3E0&sort_order=tABS.row_count%20DESC&display_options=GroupReference&input_form_format=minimum_detail">Annot</A>)</TD>
        ~;
      }


      print qq~
	</TR>
      ~;
    }
  } else {
    print "	<TR><TD WIDTH=\"100%\">NONE</TD></TR>\n";
  }


  #### Finish the table
  print qq~
	</TABLE></TD></TR>
	</TABLE>
  ~;



  ##########################################################################
  #### Print out all projects owned by the user
  print qq~
	<H1>Projects You Own:</H1>
	<TABLE WIDTH="50%" BORDER=0>
	<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
  ~;


  #### Get all the projects owned by the user
  $sql = qq~
	SELECT project_id,project_tag,P.name
	  FROM $TB_PROJECT P
	 WHERE PI_contact_id = '$current_contact_id'
	 ORDER BY project_tag
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  if (@rows) {
    my $firstflag = 1;
    foreach my $row (@rows) {
      my ($project_id,$project_tag,$project_name) = @{$row};
      print "	<TR><TD></TD>" unless ($firstflag);
      print "	<TD WIDTH=\"100%\">- <A HREF=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?set_current_project_id=$project_id\">$project_tag:</A> $project_name</TD></TR>\n";
      $firstflag=0;
    }
  } else {
    print "	<TD WIDTH=\"100%\">NONE</TD></TR>\n";
  }


  #### Finish the table
  print qq~
	</TABLE>
  ~;



  ##########################################################################
  #### Print out all projects user has access to
  print qq~
	<H1>Projects You Have Access To:</H1>
	<TABLE WIDTH="50%" BORDER=0>
	<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
  ~;


  #### Get the privilege level names
  my %privilege_names = $sbeams->selectTwoColumnHash(
    "SELECT privilege_id,name FROM $TB_PRIVILEGE WHERE record_status != 'D'"
  );


  #### Get all the projects user has access to
  $sql = qq~
	SELECT P.project_id,P.project_tag,P.name,UL.username,
               MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL ELSE GPP.privilege_id END) AS "best_group_privilege_id",
               MIN(UPP.privilege_id) AS "best_user_privilege_id"
	  FROM $TB_PROJECT P
	  JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id = UL.contact_id )
	  LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
	       ON ( P.project_id = UPP.project_id
	            AND UPP.contact_id='$current_contact_id' )
	  LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
	       ON ( P.project_id = GPP.project_id )
	  LEFT JOIN $TB_PRIVILEGE PRIV
	       ON ( GPP.privilege_id = PRIV.privilege_id )
	  LEFT JOIN $TB_USER_WORK_GROUP UWG
	       ON ( GPP.work_group_id = UWG.work_group_id
	            AND UWG.contact_id='$current_contact_id' )
	  LEFT JOIN $TB_WORK_GROUP WG
	       ON ( UWG.work_group_id = WG.work_group_id )
	 WHERE P.record_status != 'D'
	   AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40 )
           AND ( WG.work_group_name IS NOT NULL OR UPP.privilege_id IS NOT NULL )
         GROUP BY P.project_id,P.project_tag,P.name,UL.username
	 ORDER BY UL.username,P.project_tag
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  if (@rows) {
    my $firstflag = 1;
    foreach my $row (@rows) {
      my ($project_id,$project_tag,$project_name,$username,
          $best_group_privilege_id,$best_user_privilege_id) =
        @{$row};
      print "	<TR><TD></TD>" unless ($firstflag);

      #### Select the lowest permission and translate to a name
      $best_group_privilege_id = 9999
        unless (defined($best_group_privilege_id));
      $best_user_privilege_id = 9999
        unless (defined($best_user_privilege_id));
      my $best_privilege_id = $best_group_privilege_id;
      $best_privilege_id = $best_user_privilege_id if
        ($best_user_privilege_id < $best_privilege_id);
      my $privilege_name = $privilege_names{$best_privilege_id} || '???';

      print "	<TD><NOBR>- <A HREF=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?set_current_project_id=$project_id\">$username - $project_tag:</A> $project_name</NOBR></TD><TD><font color=\"red\">$privilege_name</font></TD></TR>\n";
      $firstflag=0;
    }
  } else {
    print "	<TD WIDTH=\"100%\">NONE</TD></TR>\n";
  }


  #### Finish the table
  print qq~
	</TABLE>
  ~;



    print qq~
	<H1>Other Links:</H1>
	The navigation bar on the left will take you to the various
	capabilities available thus far, or choose from this more
	descriptive list:
	<UL>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project">Manage Project information</a> (Click to add a new project under which to register experiments)
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment">Manage Experiment information</a> (Click to add information about a proteomics experiment; required before data load)
	<P>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeFractions">Summarize fractions/spectra over one or more experiments</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizePeptides">Summarize proteins/peptides over one or more experiments</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/CompareExperiments">Compare number of proteins/peptides found over two or more experiments</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/GetSearchHits">Browse possible peptide identifications from sequest searches</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseBioSequence.cgi">Browse biosequences in the database</a>
	<P>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_biosequence_set">Manage BioSequence Database information</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_dbxref">Manage Database Cross-reference information</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_gradient_program">Manage Gradient Program information</a>
	<P>
	<LI><a href="http://db.systemsbiology.net:8080/proteomicsToolkit/">Access Proteomics Toolkit Interface</a>
	<LI><a href="$HTML_BASE_DIR/doc/$SBEAMS_SUBDIR/${SBEAMS_PART}_Schema.gif">View GIF of the database schema</a>
	<LI><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/flycat.cgi">Go to the prototype FLYCAT interface</a>
	</UL>

	<BR>
	<BR>
	This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>

  ~;



  return;

} # end handle_request


