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
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;


use SBEAMS::Immunostain;
use SBEAMS::Immunostain::Settings;
use SBEAMS::Immunostain::Tables;

$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Immunostain;
$sbeamsMOD->setSBEAMS($sbeams);


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
    permitted_work_groups_ref=>['Immunostain_user','Immunostain_admin',
      'Immunostain_readonly','Admin'],
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


  #### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);
  my @rows;


  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();


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
	             <TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Owner:</B> $PI_name</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Access Privileges:</B> <A HREF="$CGI_BASE_DIR/ManageProjectPrivileges">[View/Edit]</A></TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Slides:</B></TD></TR>
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
	SELECT SS.stained_slide_id,stain_name,
               SB.specimen_block_id,specimen_block_name,
               A.antibody_id,antibody_name
	  FROM $TBIS_STAINED_SLIDE SS
	  LEFT JOIN $TBIS_SPECIMEN_BLOCK SB
	       ON ( SS.specimen_block_id = SB.specimen_block_id )
	  LEFT JOIN $TBIS_ANTIBODY A
	       ON ( SS.antibody_id = A.antibody_id )
	 WHERE project_id = '$project_id'
	   AND SS.record_status != 'D'
	 ORDER BY specimen_block_name,antibody_name,stain_name
    ~;
    @rows = $sbeams->selectSeveralColumns($sql);
  } else {
    @rows = ();
  }


  #### If there are experiments, display them
  if (@rows) {

    foreach my $row (@rows) {

      my ($stained_slide_id,$stain_name,$specimen_block_id,$specimen_block_name,$antibody_id,$antibody_name) = @{$row};

      print qq~
	<TD NOWRAP>- <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_stained_slide&stained_slide_id=$stained_slide_id">$stain_name</A></TD>
	<TD NOWRAP>&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_antibody&antibody_id=$antibody_id">$antibody_name</A></TD>
	<TD NOWRAP>&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_specimen_block&specimen_block_id=$specimen_block_id">$specimen_block_name</A></TD>
      ~;

      print qq~
	</TR>
      ~;
    }


    print qq~
        <TR><TD COLSPAN=4><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_stained_slide&ShowEntryForm=1&project_id=$project_id">[Add another slide]</A></TD></TR>
    ~;

  } else {
    if ($project_id == -99) {
      print "	<TR><TD WIDTH=\"100%\">You do not have access to this project.  Contact the owner of this project if you want to have access.</TD></TR>\n";
    } else {
      print "	<TR><TD WIDTH=\"100%\">NONE</TD></TR>\n";
    }
  }


  #### Finish the table
  print qq~
	</TABLE></TD></TR>
	</TABLE>
  ~;



  ##########################################################################
  #### Print out all projects owned by the user
  $sbeams->printProjectsYouOwn();



  ##########################################################################
  #### Print out all projects user has access to
  $sbeams->printProjectsYouHaveAccessTo();


  ##########################################################################
  #### Print out some recent resultsets
  $sbeams->printRecentResultsets();



  ##########################################################################
  #### Finish with a disclaimer
  print qq~
	<BR>
	<BR>
	This system and this module in particular are still under
	active development.  Please be patient and report bugs,
	problems, difficulties, as well as suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>
  ~;



  return;

}


