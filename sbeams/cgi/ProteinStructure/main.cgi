#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
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

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::ProteinStructure;
use SBEAMS::ProteinStructure::Settings;
use SBEAMS::ProteinStructure::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::ProteinStructure;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use CGI;
$q = new CGI;


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
$PROGRAM_FILE_NAME = 'main.cgi';
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
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin',
    #  'Proteomics_readonly'],
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


  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();


  #### Write some welcoming text
  print qq~

	<P> You are successfully logged into the <B>$DBTITLE -
	$SBEAMS_PART</B> system.  This module is designed as a repository
	for protein structure prediction software data products,
	specifically PDB-BLAST, PFAM Search, TMHMM, Ginzu, and
	Rosetta.  Data products may be queried and annotated.</P>

	<P>Please choose your tasks from the menu bar on the left.</P>

	<P> This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions
	to <B>edeutsch\@systemsbiology.org</B>.</P>
  ~;


  ##########################################################################
  #### Print out current project information

  my ($sql,@rows);

  #### Get information about the current project from the database
  $sql = qq~
	SELECT UC.project_id,P.name,P.project_tag,P.project_status,
               P.PI_contact_id
	  FROM $TB_USER_CONTEXT UC
	 INNER JOIN $TB_PROJECT P ON ( UC.project_id = P.project_id )
	 WHERE UC.contact_id = '$current_contact_id'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  my $project_id = '';
  my $project_name = 'NONE';
  my $project_tag = 'NONE';
  my $project_status = 'N/A';
  my $PI_contact_id = 0;
  if (@rows) {
    ($project_id,$project_name,$project_tag,$project_status,$PI_contact_id) = @{$rows[0]};
  }
  my $PI_name = $sbeams->getUsername($PI_contact_id);

  #### Print out some information about this project
  print qq~
	<H1>Current Project: <A class="h1" HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">$project_name</A></H1>
	<TABLE WIDTH="100%" BORDER=0>
	<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	             <TD COLSPAN="2" WIDTH="100%"><B>Project Name:</B> $project_name</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">[View/Edit]</A></TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Owner:</B> $PI_name</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Access Privileges:</B> <A HREF="$CGI_BASE_DIR/ManageProjectPrivileges">[View/Edit]</A></TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Status:</B> $project_status</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Biosequence Sets:</B></TD></TR>
	<TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	                 <TD WIDTH="100%"><TABLE BORDER=0>
  ~;


  #### If the current user is not the owner, the check that the
  #### user has privilege to access this project
  if ($project_id > 0) {

    my $best_permission = $sbeams->get_best_permission();

    #### If not at least data_reader, set project_id to a bad value
    $project_id = -99 unless ($best_permission > 0 && $best_permission <=40);

  }


  #### Get all the experiments for this project
  if ($project_id > 0) {
    $sql = qq~
	SELECT BSS.biosequence_set_id,BSS.set_tag,BSS.set_name
	  FROM $TBPS_BIOSEQUENCE_SET BSS
	 WHERE BSS.project_id = '$project_id'
	   AND BSS.record_status != 'D'
	 ORDER BY BSS.set_tag
    ~;
    @rows = $sbeams->selectSeveralColumns($sql);
  } else {
    @rows = ();
  }


  #### If there are biosequence_sets, display them
  if (@rows) {
    foreach my $row (@rows) {
      my ($biosequence_set_id,$biosequence_set_tag,$biosequence_set_name) =
	@{$row};

      print qq~
	<TR><TD NOWRAP>- <font color="green">$biosequence_set_tag:</font> $biosequence_set_name</TD>
	<TD NOWRAP>&nbsp;&nbsp;&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PS_biosequence_set&biosequence_set_id=$biosequence_set_id">[View/Edit]</A></TD>
      ~;


      #### Find out how many biosequences for this set
      $sql = qq~
	SELECT COUNT(*)
	  FROM $TBPS_BIOSEQUENCE
	 WHERE biosequence_set_id = '$biosequence_set_id'
      ~;
      my ($biosequence_count) = $sbeams->selectOneColumn($sql);

      #### Find out how many biosequences for this set
      $sql = qq~
	SELECT COUNT(*)
	  FROM $TBPS_BIOSEQUENCE_ANNOTATION BSA
         INNER JOIN $TBPS_BIOSEQUENCE BS
	       ON ( BSA.biosequence_id = BS.biosequence_id )
	 WHERE biosequence_set_id = '$biosequence_set_id'
      ~;
      my ($annotation_count) = $sbeams->selectOneColumn($sql);

        print qq~
	  <TD>&nbsp;&nbsp;&nbsp;$biosequence_count proteins&nbsp;&nbsp;&nbsp;<font color="green">$annotation_count annotations</font></TD>
        ~;

      print qq~
	</TR>
      ~;
    }
  } else {
    if ($project_id == -99) {
      print "	<TR><TD WIDTH=\"100%\">You do not have access to this project.  Contact the owner of this project if you want to have access.</TD></TR>\n";
    } else {
      print "	<TR><TD WIDTH=\"100%\">NONE</TD></TR>\n";
    }
  }


  #### If the current user is the owner of this project, invite the
  #### user to register another experiment
  if ($current_contact_id == $PI_contact_id) {
    print qq~
        <TR><TD COLSPAN=4><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment&ShowEntryForm=1">[Register another experiment]</A></TD></TR>
    ~;
  }


  #### Finish the table
  print qq~
	</TABLE></TD></TR>
	</TABLE>
  ~;



  ##########################################################################
  #### Print out some recent resultsets

  $sbeams->printRecentResultsets();


  ##########################################################################
  #### Print out all projects owned by the user

  $sbeams->printProjectsYouOwn();


  ##########################################################################
  #### Print out all projects user has access to

  $sbeams->printProjectsYouHaveAccessTo();


  return;


} # end handleResquest


