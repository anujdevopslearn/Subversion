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

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;
use SBEAMS::Connection::DataTable;

use SBEAMS::ProteinStructure;
use SBEAMS::ProteinStructure::Settings;
use SBEAMS::ProteinStructure::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::ProteinStructure;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


#use CGI;
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
  my $project_id = $sbeams->getCurrent_project_id;

  # Check the permissions the user has on this project
  my $best_permission = $sbeams->get_best_permission();
  if ( $best_permission > 40 ) {
    print "You are not permitted to view this project";
    return;
  }


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

  # Create new tabmenu item.  This may be a $sbeams object method in the future.
  my $tabmenu = SBEAMS::Connection::TabMenu->new( cgi => $q );

  # Preferred way to add tabs.  label is required, helptext optional
  $tabmenu->addTab( label => 'Current Project', 
                    helptext => 'View details of current Project' );
  $tabmenu->addTab( label => 'My Projects', 
                    helptext => 'View all projects owned by me' );
  $tabmenu->addTab( label => 'Recent Resultsets', 
                    helptext => 'View recent SBEAMS resultsets' );
  $tabmenu->addTab( label => 'Accessible Projects', 
                    helptext => 'View projects I have access to' );

  ##########################################################################
  #### Print out some recent resultsets

  # Scalar to hold content.  In this case we add content to tabmenu, not required
  my $content;

  # conditional block to exec code based on selected tab.
  if ( $tabmenu->getActiveTabName() eq 'Current Project' ){ # Current project info
   
    # Show info about current project
    if ( $project_id ) {
      $content = $sbeams->getProjectDetailsTable( project_id => $project_id ); 
      # Also add module-specific content
      $content .= getProjectInformation( $project_id, $best_permission );
    } else {
      $content = "No project currently set";
    }

  # or exec code based on tab index.  Tabs are indexed in the order they are 
  # added, starting at 1.  
  } elsif ( $tabmenu->getActiveTab() == 2 ){
    # Projects owned by the user
    $content = $sbeams->getProjectsYouOwn();

  } elsif ( $tabmenu->getActiveTabName() eq 'Recent Resultsets' ){
    # Show resultsets
    $content = $sbeams->getRecentResultsets() ;

  } elsif ( $tabmenu->getActiveTab() == 4 ){
    # Projects user has access to
    $content = $sbeams->getProjectsYouHaveAccessTo();

  }

  # Add content to tabmenu (if desired). 
  $tabmenu->addContent( $content );

  # The stringify method is overloaded to call the $tabmenu->asHTML method.  
  # This simplifies printing the object in a print block. 
  print "$tabmenu";
  

  return;

} # end handleResquest

sub getProjectInformation {

  my $project_id = shift;
  my $best_permission = shift;
  my $content = '';

  my $sql =<<"  END";
  SELECT BS.project_id, BS.biosequence_set_id,BS.set_tag,BS.set_name,
         COUNT( B.biosequence_id ) AS num_bioseqs, COUNT( BA.biosequence_annotation_id ) AS num_annot
  FROM $TBPS_BIOSEQUENCE_SET BS
  LEFT OUTER JOIN $TBPS_BIOSEQUENCE B
  ON BS.biosequence_set_id = B.biosequence_set_id
  LEFT OUTER JOIN $TBPS_BIOSEQUENCE_ANNOTATION BA
  ON BA.biosequence_id = B.biosequence_id
  WHERE BS.project_id = '$project_id'
  AND BS.record_status != 'D'
 -- AND BA.record_status != 'D'
 --  AND B.record_status != 'D'
  GROUP BY project_id, BS.biosequence_set_id, set_tag, set_name
  ORDER BY BS.set_tag
  END
  my @rows = $sbeams->selectSeveralColumns($sql);

  my $bio_table = SBEAMS::Connection::DataTable->new( BORDER => 0, WIDTH =>'40%',
                                                      CELLPADDING => 2 );
  my $imgpad = "<IMG SRC='$HTML_BASE_DIR/images/space.gif' WIDTH='20' HEIGHT='1'>";
  $bio_table->addRow( [ $imgpad, 'ID', 'Biosequence Set Name', 'Set Tag', '# Proteins', '# Annotations' ] );
  $bio_table->setHeaderAttr( UNDERLINE => 1, BOLD => 0 );

  my $urlbase = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME";

  foreach my $row (@rows) {
    # Link to name
    $row->[3] =<<"    END_LINK";
    <A HREF="${urlbase}=PS_biosequence_set&biosequence_set_id=$row->[1]">
    $row->[3]</A>
    END_LINK

    $bio_table->addRow( [$imgpad, $row->[1],$row->[2],$row->[3],$row->[4],$row->[5] ]  );
  }
  $bio_table->setColAttr( ROWS => [1..$bio_table->getRowNum()], COLS => [1..6],
                          NOWRAP => 1 );
  $bio_table->setColAttr( ROWS => [2..$bio_table->getRowNum()], COLS => [5,6],
                          ALIGN => 'RIGHT' );

  # If user can write to this project, invite them to register another experiment
  my $addlink =<<"  END_LINK";
  <BR>
  <A HREF="${urlbase}=Project&ShowEntryForm=1">[Add a new project]
  </A>
  END_LINK

  if ( scalar( @rows ) ) {
    $content .= "<B>Biosequence Sets in this project:<B><BR>$bio_table";
  } else {
    $content .= "No data in this project";
  }

  $content .= $addlink if $best_permission < 40; 
  return $content;

}


