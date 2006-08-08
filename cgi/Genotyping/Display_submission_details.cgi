#!/usr/local/bin/perl

###############################################################################
# Program     : Display_submission_details.cgi
# Author      : Kerry Deutsch <kdeutsch@systemsbiology.org>
#
#
# Description : This program displays detailed information on how to submit
#               a genotyping request to the core facility.
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

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD  $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::Genotyping;
use SBEAMS::Genotyping::Settings;
use SBEAMS::Genotyping::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Genotyping;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI qw/:standard -nosticky/;

#use CGI;
#$q = new CGI;


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
my $manage_table_url_samples = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=GT_sample";

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
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
 #$sbeams->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "Add_sample") {
    $sbeamsMOD->display_page_header();
    upload_data(ref_parameters=>\%parameters);
    $sbeamsMOD->display_page_footer();
  } elsif ($parameters{action} =~ "Pick_sample") {
	
    $sbeamsMOD->display_page_header();
    pick_sample(ref_parameters=>\%parameters);
    $sbeamsMOD->display_page_footer();

  }else {
    #if no experiment is present print all project and experiments
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


  ##Get the Project information


  #### Print Info On how to submit a genotyping request
  print qq!
        <font color=red>TO SUBMIT A GENOTYPING REQUEST:</font>

        <UL>

        <LI> Know the Project under which the submission should be
        entered.  If there isn\'t one yet, create it by clicking
        [Projects] [Add Project]

        <LI> Select the request options with [Experiments] [Add Experiment]

        <LI> Two forms are required: a Sample file and a SNP file.
        Example of the required formats can be seen by clicking <A HREF="$HTML_BASE_DIR/doc/Genotyping/SampleFileColumnDefinitions.php">[File formats]</A>.

        <LI> After submitting the request, you will receive an email
        with a cost estimate and approximate delivery date.</UL><BR><BR>

        <font color=red>PLEASE READ THE FOLLOWING CAREFULLY:</font><BR><BR>

        <B> DNA criteria </B>

        <UL>
        <LI> DNA should be quantified using a SNA specific
        method.  We recommend the Pico Green method (Molecular
        Probes catalog number R-21495 http://www.molecularprobes.com)
        or the Hoechst Dye 33258 method.

        <LI> All DNAs must be normalized to a concentration of
        approximately 25 ng/&#181;l.  The total amount of DNA required
        is dependent on the number of SNPs to be studied and is
        defined for each project.

        <LI> DNA stock must be diluted in ddH<SUB>2</SUB>0.

        <LI> A brief description of the DNA extraction protocol(s)
        should be included.</UL><BR><BR>

        <B>Shipping instructions</B>

        <UL>
        <LI> Wells A1 through A4 must remain empty for controls.

        <LI> Plates should not be directly stacked on one another.
        The well bottoms may pierce the foil lids.  Place the foam
        packing material pads between plates.

        <LI> The lids must be sealed tightly and completely.  We
        suggest the use of devices such as the MJ Research Roller for
        Microseal Film (catalog number MSR-0001) or the Corning
        Storage Mat Applicator (catalog number 3081).

        <LI> DNA must be solidly frozen prior to shipment and remain
        frozen to avoid the possibility of cross contamination or
        degradation.  Plates must be shipped on sufficient dry ice to
        ensure that the samples remain frozen.

        <LI> DNA should be shipped overnight express.</UL><BR>

	<BR>
	This system is still under active development.  Please be
	patient and report bugs, problems, difficulties, suggestions to
	<B>kdeutsch\@systemsbiology.org</B>.
	<BR>
	<BR>

    !;

}
