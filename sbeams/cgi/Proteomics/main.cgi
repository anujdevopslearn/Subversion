#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This program shows a users personal view of the data
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
	<TR><TD></TD><TD COLSPAN="2"><B>Experiments:</B>&nbsp;&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi">Full Listing</A>&nbsp;&mdash;&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?expt_format=compact">Compact</A></TD></TR>
	<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD> 
	                 <TD WIDTH="100%" ALIGN=LEFT>
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
	SELECT experiment_id,experiment_tag,experiment_name
	  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
	 WHERE project_id = '$project_id'
	   AND PE.record_status != 'D'
	 ORDER BY experiment_tag
    ~;
    @rows = $sbeams->selectSeveralColumns($sql);
  } else {
    @rows = ();
  }


  #### If there are experiments, display them in one of two formats: compact or full
  if (@rows) {

      if ($parameters{expt_format} eq "compact"){
#print "the condensed table";
#tag below with colspan=3 would be better suited as colspan=$#search_batch_rows+1, though expts are -not- sorted by number of search batches at this time
print qq~
<TABLE BORDER=1>
  <tr>
<th align=left><font color="green">- Experiement Name</font> : Description</th>
<th nowrap>View/Edit<br/>Data</th>
<th>Fraction<br/>Data</th>
<th colspan=4 nowrap><font color="green">Search Batch</font><br/>(SBEAMS number: <font color="blue">High-Probability Peptides</font>&nbsp;--<font color="blue">Annotation</font>)<th>
</tr>
    ~;
      my $search_batch_counter = 0;
    foreach my $row (@rows) {
      my ($experiment_id,$experiment_tag,$experiment_name) = @{$row};

      #### Find out what search_batches exist for this experiment
      $sql = qq~
	SELECT SB.search_batch_id,SB.search_batch_subdir,BSS.set_tag
	  FROM $TBPR_SEARCH_BATCH SB
	 INNER JOIN $TBPR_BIOSEQUENCE_SET BSS
	       ON ( SB.biosequence_set_id = BSS.biosequence_set_id )
	 WHERE SB.experiment_id = '$experiment_id'
	 ORDER BY BSS.set_tag,SB.search_batch_subdir
      ~;
      my @search_batch_rows = $sbeams->selectSeveralColumns($sql);

      $search_batch_counter++;
      if (($search_batch_counter % 2) == 1){
	  print qq( <TR BGCOLOR="#efefef"> \n);
      }else{
	  print qq( <TR> \n);
      }
      print qq~
	<TD NOWRAP>- <font color="green">$experiment_tag:</font> $experiment_name</TD>
	<TD NOWRAP ALIGN=CENTER><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment&experiment_id=$experiment_id">[View/Edit]</A></TD>
	<TD NOWRAP ALIGN=CENTER><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeFractions?action=QUERYHIDE&QUERY_NAME=PR_SummarizeFractions&experiment_id=$experiment_id">[View]</A></TD>
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
#print the full-size results table
    foreach my $row (@rows) {
      my ($experiment_id,$experiment_tag,$experiment_name) = @{$row};

      #### Find out what search_batches exist for this experiment
      $sql = qq~
	SELECT SB.search_batch_id,SB.search_batch_subdir,BSS.set_tag
	  FROM $TBPR_SEARCH_BATCH SB
	 INNER JOIN $TBPR_BIOSEQUENCE_SET BSS
	       ON ( SB.biosequence_set_id = BSS.biosequence_set_id )
	 WHERE SB.experiment_id = '$experiment_id'
	 ORDER BY BSS.set_tag,SB.search_batch_subdir
      ~;
      my @search_batch_rows = $sbeams->selectSeveralColumns($sql);
#need to issue query for number of MS runs
$sql = qq~
SELECT COUNT(*)
FROM $TBPR_FRACTION
WHERE experiment_id = '$experiment_id'
    ~;
my @count_ms_runs = $sbeams->selectOneColumn($sql);

      print qq~
<TABLE BORDER=0 CELLPADDING=2 CELLSPACING=0>
      <TR BGCOLOR="#efefef">
	<TD NOWRAP COLSPAN=2 WIDTH=300>- <font color="green">$experiment_tag:</font> $experiment_name</TD>
        <TD NOWRAP ALIGN=CENTER COLSPAN=2 WIDTH=300><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment&experiment_id=$experiment_id">[View/Edit Experiment Description]</A></TD>
     </TR>
      <TR BGCOLOR="#efefef">
	  <TD>&nbsp;</TD>
	<TD NOWRAP COLSPAN=3 ALIGN=LEFT><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeFractions?action=QUERYHIDE&QUERY_NAME=PR_SummarizeFractions&experiment_id=$experiment_id">&nbsp;&nbsp;Number of MS Runs: @count_ms_runs</A></TD>
      </TR>
      ~;

      foreach my $search_batch_row (@search_batch_rows) {
        my ($search_batch_id,$search_batch_subdir,$set_tag) = @{$search_batch_row};

    $sql = qq ~
      SELECT protein_summary_id
       FROM $TBPR_SEARCH_BATCH_PROTEIN_SUMMARY
      WHERE search_batch_id = '$search_batch_id'
     ~;
      my @protein_summary_status = $sbeams->selectOneColumn($sql);

        print qq~
     <TR>
    <TD>&nbsp;</TD>
  <TD ALIGN=LEFT>Search batch $search_batch_id against <font color="green">[$set_tag]</font></TD>
<TD ALIGN=CENTER> <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizePeptides?action=QUERY&QUERY_NAME=PR_SummarizePeptides&search_batch_id=$search_batch_id&probability_constraint=\%3E.9&n_annotations_constraint=%3E0&sort_order=tABS.row_count%20DESC&display_options=GroupReference&input_form_format=minimum_detail">PeptideProphet Summary<br/>(P &gt; 9)</A></TD>
    ~;
	if (@protein_summary_status){#ProteinProphet annotation is available
	print qq~ <TD ALIGN=CENTER>ProteinProphet Summary<br/><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseProteinSummary?protein_group_probability_constraint=%3E0.9&QUERY_NAME=PR_BrowseProteinSummary&search_batch_id=$search_batch_id&action=QUERY">View</A>&nbsp; <FONT COLOR="#CCCCCC">[ADD]</FONT></TD> ~;
    } else { #allow the user to add ProteinProphet annotation
	print qq~ <TD ALIGN=CENTER>ProteinProphet Summary<br/><FONT COLOR="#CCCCCC">View</FONT>&nbsp;<!-- not available yet -->[ADD]</TD> ~;
    }

print qq~
</TR>
    ~;
      }
      print qq~
<TR><TD COLSPAN=3>&nbsp;</TD></TR>
      ~;
  }

}
  
  
  } else {
    if ($project_id == -99) {
      print qq~	<TR><TD WIDTH="100%">You do not have access to this project.  Contact the owner of this project if you want to have access.</TD></TR>\n ~;
    } else {
      print qq~	<TR><TD COLSPAN=2><FONT COLOR=RED>No experiments available, please <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment">add</A> an experiment.</TD></TR> \n~;
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
  #### Print out all projects owned by the user

  $sbeams->printProjectsYouOwn();



  ##########################################################################
  #### Print out all projects user has access to

  $sbeams->printProjectsYouHaveAccessTo();


  ##########################################################################
  #### Print out some recent resultsets

  $sbeams->printRecentResultsets();


  ##########################################################################
  #### Print out a bunch of other misc links

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
	This system and this module in particular are still under
	active development.  Please be patient and report bugs,
	problems, difficulties, as well as suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>

  ~;



  return;

} # end handle_request


