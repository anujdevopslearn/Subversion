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
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username %hash_to_sort
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

my $INTRO = '_displayIntro';
my $START = '_start';
my $ERROR = '_error';
my $ANTIBODY = '_processAntibody';
my $STAIN = '_processStain';
my $CELL = '_processCells';
my (%indexHash,%editorHash);
#possible actions (pages) displayed
my %actionHash = (
	$INTRO	=>	\&displayIntro,
	$START	=>	\&displayMain,
	$ANTIBODY =>	 \&processAntibody,
	$STAIN 	=>	 \&processStain,
	$CELL	=>	\&processCells,
	$ERROR	=>	\&processError
	);


main();
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main 
{
		
#### Do the SBEAMS authentication and exit if a username is not returned

 exit unless ($current_username = $sbeams->Authenticate(
    permitted_work_groups_ref=>['Immunostain_user','Immunostain_admin',
      'Immunostain_readonly','Admin'],
   connect_read_only=>1,
   allow_anonymous_access=>1,
  ) );
  

#### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
#$sbeams->printDebuggingInfo($q);
#### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);

  #### Decide what action to take based on information so far
 # if ($parameters{action} eq "_processCells") {
# special handling when cells are processed
#		processCells(ref_parameters=>\%parameters);
#	}
#	else
#	{
# normal handling for anything else			
	$sbeamsMOD->display_page_header();
#	}
    handle_request(ref_parameters=>\%parameters);  
   $sbeamsMOD->display_page_footer();
  


} # end main



###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;
	print qq~	<TABLE WIDTH="100%" BORDER=0> ~;
	print qq~
				<H2>Welcome to the SCGAP Urologic Epithelial Stem Cells Public Data Access Page</H2>
				<TR><TD><P>This project is one component of the Stem Cell Genome Anatomy Projects (SCGAP) supported by the National Institute of Diabetes & Digestive & Kidney Disease (NIDDK).
				To read more about the specifics of this project  click on the links under the Project Information tab on the left. </TD></tr>
				<tr><td><p>Here are quick links to summarized data generated for:</td></tr>
				<tr><td><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&tissue_type_id=1&organism_id=2&display_options=MergeLevelsAndPivotCellTypes"> Human Prostate tissue</a></td></tr> 
	      	     <tr><td><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&tissue_type_id=4&organism_id=2&display_options=MergeLevelsAndPivotCellTypes"> Human Bladder tissue</a></td></tr> 
	      	    <tr><td><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&tissue_type_id =&organism_id=6&display_options=MergeLevelsAndPivotCellTypes"> Mouse Prostate tissue</a></td></tr> 
	      	    <tr><td><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&tissue_type_id=4&organism_id=6&display_options=MergeLevelsAndPivotCellTypes"> Mouse Bladder tissue</a></td></tr> 
	      	    <tr></tr>
				 <tr><td>For a more detailed search and analysis of our data <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi">click </a>here.</td></tr>
				 <TD WIDTH="100%"><TABLE BORDER=0>~	;
	  
=comment
#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
#### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);
	my @rows;
	 $current_contact_id = $sbeams->getCurrent_contact_id();
#### Show current user context information
#  $sbeams->printUserContext();
=cut
	print "</table>";
	
}
__END__

