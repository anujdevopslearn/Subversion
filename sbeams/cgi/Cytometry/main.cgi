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
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($q $sbeams $sbeamsMOD $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Cytometry;
use SBEAMS::Cytometry::Settings;
use SBEAMS::Cytometry::Tables;


$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Cytometry;
$sbeamsMOD->setSBEAMS($sbeams);


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
      #connect_read_only=>1,
      #allow_anonymous_access=>1,
      permitted_work_groups_ref=>['Cytometry_user','Cytometry_admin','Admin'],
    ));

	#### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
#$sbeams->printDebuggingInfo($q);
#### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);
	
    #### Print the header, do what the program does, and print footer
	
	# normal handling for anything else			
	$sbeamsMOD->display_page_header();
	 handle_request(ref_parameters=>\%parameters);  
   $sbeamsMOD->display_page_footer();
  

} # end main


###############################################################################
# Show the main welcome page
###############################################################################

sub handle_request 
{
 my %args = @_;


#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
#### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);
  my @rows;
	
  $current_contact_id = $sbeams->getCurrent_contact_id();

 
#### Show current user context information
  $sbeams->printUserContext();

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
  

#### If the current user is not the owner, the check that the
#### user has privilege to access this project
  if ($project_id > 0) {

    my $best_permission = $sbeams->get_best_permission();

#### If not at least data_reader, set project_id to a bad value
    $project_id = -99 unless ($best_permission > 0 && $best_permission <=40);

  }
  
#### Get all the experiments for this project
	my $action = $parameters{'action'};
	print qq~	<TABLE WIDTH="100%" BORDER=0> ~;
#loading the default page (Intro)
#my $sub = $actionHash{$action} || $actionHash{$INTRO};

my $sub = 1;
if ($sub )  {
		#print some info about this project
		#only on the main page
		
		print qq~
				<H1>Current Project: <A class="h1" HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">$project_name</A></H1>
				<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	      <TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
				<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag</TD></TR>
				<TR><TD></TD><TD COLSPAN="2"><B>Owner:</B> $PI_name</TD></TR>
				<TR><TD></TD><TD COLSPAN="2"><B>Access Privileges:</B> <A HREF="$CGI_BASE_DIR/ManageProjectPrivileges">[View/Edit]</A></TD></TR>
				<TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	      <TD WIDTH="100%"><TABLE BORDER=0>
		  ~ if ($action eq '_displayIntro' || !$action) ;

#### If the project_id wasn't reverted to -99, display information about it
		if ($project_id == -99) 
		{
			print "	<TR><TD WIDTH=\"100%\">You do not have access to this project.  Contact the owner of this project if you want to have access.</TD></TR>\n";
		}
		else
		{
			showMainPage(ref_parameters=>\%parameters,project_id=>$project_id);
		}
		
#could not find a sub
	}
	else {
		print_fatal_error("Could not find the specified routine: $sub");
	
	}
	print "</table>";
	
}

####----------------------------------------------------------------------------------
sub showMainPage {

	 my %args = @_;
	 #### get the project id
	 my $project_id = $args{'project_id'} || die "project_id not passed";
	 
	 my $organismSql = qq~ select organism_id,organism_name from 
	 sbeams.dbo.organism ~; 
	
	my %organismHash = $sbeams->selectTwoColumnHash($organismSql);
	
	my $sql = "select  fcs_run_id,Organism_id , project_designator, sample_name, filename, run_date 
	 from $TBCY_FCS_RUN where project_id = '$project_id' order by project_designator";
	 
	 my @rows = $sbeams->selectSeveralColumns($sql);
	 my %hash;
	my $count = 1; 
	 if (@rows)
	 {
		print "<br><center><h4> Current Cytometry data for this project</h4></center><br>";
		print "<table border=2>"; 
		foreach my $row(@rows)
		{
			my ($fcsID,$organismID, $projectDes, $sampleName, $fileName, $runDate) = @{$row};
			$runDate =~ s/^(.*?)\s0.*$/$1/;
			my @array;
#		print "$count ==  $projectDes  == $organismID == ,$sampleName == $fileName === $runDate <br>";
			$projectDes = uc($projectDes);
			push @array,( $sampleName, $organismHash{$organismID},$fileName, $runDate);
			$hash{$projectDes}->{$fcsID} = \ @array;
			$count++;
		}	
			
		foreach my $key (keys %hash)
		{
			print " <tr><td> <b>Project Designator: </b>$key</td></tr>";
			print "<tr><td><b>Sample Name</b></td><td><b>Organism</b></td><td><b>File Name</b></td><td><b>Run Date</b></td></tr>";
			foreach my $kk (keys %{$hash{$key}})
			{ 
				print "<tr>";
				my $count = 0;
				foreach my $element (@{$hash{$key}->{$kk}})
				{
					if ($count == 0)
					{
						print qq ~<td>  <a href=http://db.systemsbiology.net/devMK/sbeams/cgi/Cytometry/ManageTable.cgi?TABLE_NAME=CY_fcs_run&fcs_run_id=$kk>$element</a></td>~;
					}
					else 
					{
						print "<td>$element</td>";
					}
					$count++;
				}
				print "</tr>";
			}
		}
	 }
	 else
	 { 
		 print "	<TR><TD WIDTH=\"100%\"><B><font color=red><NOWRAP>This project contains no Cytometry Data</NOWRAP></font></B></TD></TR>\n";
	}
		
 #### Finish the table
  print qq~
	</TABLE></TD></TR>
	</TABLE>~;
    	
	  ##########################################################################
  #### Print out all projects owned by the user
	$sbeams->printProjectsYouOwn() if $sbeams->getCurrent_contact_id();
  ##########################################################################
  #### Print out all projects user has access to
  $sbeams->printProjectsYouHaveAccessTo()  if $sbeams->getCurrent_contact_id();
  ##########################################################################
  #### Print out some recent resultsets
  $sbeams->printRecentResultsets()  if $sbeams->getCurrent_contact_id();

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
=comment
    print qq!
	<BR>
	You are successfully logged into the $DBTITLE - $SBEAMS_PART system.
	Please choose your tasks from the menu bar on the left.<P>
	<BR>
	This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>

	<UL>
	<LI> Here is the starter stub for the Cytometry area.
	</UL>

	<BR>
	<BR>
    !;
=cut

} # end showMainPage


