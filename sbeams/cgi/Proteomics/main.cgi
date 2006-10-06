#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This program shows a users personal view of the data
#
# SBEAMS is Copyright (C) 2000-2006 Institute for Systems Biology
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
use Data::Dumper;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $prot_exp_obj $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Proteomics::Proteomics_experiment;


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Proteomics;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$prot_exp_obj = new SBEAMS::Proteomics::Proteomics_experiment;

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
my $manage_table_url_samples = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_sample";
my $add_sample_cgi_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/Add_proteomic_sample.cgi";

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


  #### Write some simple descriptive test
  print qq~
	<P>The SBEAMS - Proteomics module provides an interface for you to
	manage and explore your LC-MS/MS datasets.  Please check your
	current work group above and change it if desired. Use the tabs
	below to access information about projects and experiments.
	Individual queries may be accessed by name to the left.</P>
  ~;


  #### Create new tabmenu item.
  my $tabmenu = SBEAMS::Connection::TabMenu->new(
    cgi => $q,
    # paramName => 'mytabname', # uses this as cgi param
    # maSkin => 1,   # If true, use MA look/feel
    # isSticky => 0, # If true, pass thru cgi params 
    # boxContent => 0, # If true draw line around content
    # labels => \@labels # Will make one tab per $lab (@labels)
  );


  #### Add the individual tab items
  $tabmenu->addTab( label => 'Current Project',
		    helptext => 'View details of current Project' );
  $tabmenu->addTab( label => 'My Projects',
		    helptext => 'View all projects owned by me' );
  $tabmenu->addTab( label => 'Accessible Projects',
		    helptext => 'View projects I have access to' );
  $tabmenu->addTab( label => 'Recent Resultsets',
		    helptext => "View recent $SBEAMS_SUBDIR resultsets" );


  ##########################################################################
  #### Buffer to hold content.
  my $content;

  #### Conditional block to exec code based on selected tab


  #### Print out details on the current default project
  if ( $tabmenu->getActiveTabName() eq 'Current Project' ){
    my $project_id = $sbeams->getCurrent_project_id();
    if ( $project_id ) {
      $content = $sbeams->getProjectDetailsTable(
        project_id => $project_id
      );

      $content .= getCurrentProjectDetails(
        ref_parameters => \%parameters,
      );

    }


  #### Print out all projects owned by the user
  } elsif ( $tabmenu->getActiveTabName() eq 'My Projects' ){
    $content = $sbeams->getProjectsYouOwn();


  #### Print out all projects user has access to
  } elsif ( $tabmenu->getActiveTabName() eq 'Accessible Projects' ){
    $content = $sbeams->getProjectsYouHaveAccessTo();


  #### Print out some recent resultsets
  } elsif ( $tabmenu->getActiveTabName() eq 'Recent Resultsets' ){

    $content = $sbeams->getRecentResultsets() ;

  }


  #### Add content to tabmenu (if desired).
  $tabmenu->addContent( $content );

  #### Display the result
  print $tabmenu->asHTML();


} # end handle_request



###############################################################################
# getCurrentProjectDetails
#
# Return a block of a details about the experiments in the current project
###############################################################################
sub getCurrentProjectDetails {
  my %args = @_;

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
  my $project_id = $sbeams->getCurrent_project_id();

  #### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);
  my @rows;
   
  #### Define a buffer for content
  my $content = '';
  
  

  #### If the current user is not the owner, the check that the
  #### user has privilege to access this project
  if ($project_id > 0) {

    my $best_permission = $sbeams->get_best_permission();

    #### If not at least data_reader, set project_id to a bad value
    $project_id = -99 unless ($best_permission > 0 && $best_permission <=40);

  }


  my @experiment_rows = $prot_exp_obj->get_experiment_info(project_id=>$project_id);#rows
  my @all_samples_results = $prot_exp_obj->get_sample_info(project_id=>$project_id);


  $content .= '<h2 class="med_gray_bg">Experiment Information';
  #### If there are experiments, display them in one of two formats: compact or full
  if (@experiment_rows) {

      my $expt_frmt = 'full';  # default value
      if ($parameters{expt_format}){
	  $expt_frmt = $parameters{expt_format};
	  if ($sbeams->getSessionAttribute(key => 'ProteomicsExperimentFormat') ne $expt_frmt) {
	      $sbeams->setSessionAttribute(key => 'ProteomicsExperimentFormat',
					   value=>$expt_frmt);
	  }

      } elsif ($sbeams->getSessionAttribute(key => 'ProteomicsExperimentFormat')){
	  $expt_frmt = $sbeams->getSessionAttribute(key => 'ProteomicsExperimentFormat');
      }


	if ($expt_frmt eq "compact"){
	        $content .= "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font size=\"-2\">[ <a href=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?_tab=1&expt_format=full\">Full</a> | COMPACT ]</font></h2>";
		#make "the condensed table";
		$content .= make_compact_experiment_html(exp_results_set_aref => \@experiment_rows);
  	}else{
	        $content .= "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<font size=\"-2\">[ FULL | <a href=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?_tab=1&expt_format=compact\">Compact</a> ]</font></h2>";

		##make the full-size results table
   		$content .= make_full_experiment_html(exp_results_set_aref => \@experiment_rows,
						      sample_results_set_aref => \@all_samples_results);
	}

  }else{
    $content .= '</h2>';
    if ($project_id == -99) {
      $content .= qq~	<TR><TD WIDTH="100%">You do not have access to this project.  Contact the owner of this project if you want to have access.</TD></TR>\n ~;
    } else {
      $content .= qq~	<TR><TD COLSPAN=2 class='red_bg'>No proteomics experiments registered in this project.</TD></TR> \n~;
    }
  }


		

  #### If the current user is the owner of this project, invite the
  #### user to register another experiment
  if ($sbeams->isProjectWritable()) {
    $content .= qq~
        <TR class='white_bg'><TD COLSPAN=4><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment&ShowEntryForm=1&project_id=$project_id">[Register another experiment]</A></TD></TR>
    	<TR class='white_bg'><TD COLSPAN=4><IMG SRC='$HTML_BASE_DIR/images/clear.gif' HEIGHT=20 ></TD></TR>
    ~;
  }
	
	$content .= make_all_samples_for_project_html(sample_results_set_aref => \@all_samples_results,
						      project_id => $project_id,
						      );
	
 #### Finish the table 
  $content .= qq~
	</TABLE></TD></TR>
	</TABLE>
  ~;
 
} # getCurrentProjectDetails



###############################################################################
# getMiscLinks
#
# Return a block of a bunch of other misc links
###############################################################################
sub getMiscLinks {

  return qq~
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

} # end getMiscLinks


##############################################################################
# make_option_list
#
# Return make little forms showing the samples for a particular experiment
###############################################################################
sub make_option_list{
	my %args = @_;
	my $all_sample_info_aref     = $args{sample_info};
	my $samles_per_exp_info_aref = $args{experiment_info}; 
	my $experiment_id			 = $args{experiment_id};
	my %seen = ();	
	my @unique_sample_name = ();

	#$log->debug(Dumper($all_sample_info_aref));
##make hash of the samples in this experiment
	foreach my $exp_sample_info (@{$samles_per_exp_info_aref}){
		#$log->debug("SAMPLE TAG1 '$exp_sample_info->[1]'");
		$seen{$exp_sample_info->[0]} = 1;
	}
	
	#$log->debug('SEEN', Dumper(\%seen));

##Grab on the sample names not already listed for this experiment
	foreach my $sample_info (@{$all_sample_info_aref}){
		push (@unique_sample_name, 	$sample_info) unless exists $seen{$sample_info->[0]}; #remember its a aref that is being entered
	}
##Make the option list html		
	my $html = '';
	
	
	
	my $html_options = '';
	$html_options .= "<option></option>"; #Add a blank option to the top of the list so nothing is displayed initally
	foreach my $sample_info_aref (@unique_sample_name){
		 my $sample_tag = $sample_info_aref->[1];
	     my $proteomics_sample_id = $sample_info_aref->[0];
	    #$log->debug("SAMPLE TAG '$sample_tag'");
	     $html_options .= "<OPTION VALUE=$proteomics_sample_id>$sample_tag</OPTION>";
	}
	
	$html  = qq~ 
		  <table border=0>
		   <tr>
		     <td>Associate a previous Project sample with this experiment</td>
		   <tr>
		    <td>
			   <FORM ACTION="Add_proteomic_sample.cgi" NAME="AddSample__$experiment_id" TARGET='add_sample'>
			   		<INPUT TYPE="hidden" NAME="experiment_id" VALUE="$experiment_id">
			   		<INPUT TYPE="hidden" NAME="action" VALUE="Add_sample">
			   		<SELECT NAME="sample_id" onChange="submitsample(this)">
						$html_options
					</SELECT>
				
			   </FORM>
			  </td>
			</tr>
		</table>
			~;
	#Only return the form if there is data to display
	$html = @unique_sample_name ?$html: '&nbsp;' ;

	return $html;
}


###############################################################################
# make_compact_experiment_html
#
# Return a block of html to print a compact experimental form
###############################################################################
sub make_compact_experiment_html {
    my %args = @_;
    my $results_set_array_ref = $args{exp_results_set_aref};

    my @rows = @{$results_set_array_ref};

    my $content .= qq~
<TABLE BORDER=0>
 <tr>
 <th align=left><font color="green">- Experiment Name</font> : Description</th>
 <th nowrap>View/Edit<br/>Record</th>
 <th>Fraction<br/>Data</th>
 <th nowrap><font color="green">Search Batch</font><br/>(SBEAMS number: <font color="blue">High-Probability Peptides</font>&nbsp;--<font color="blue">Annotation</font>)<th>
 </tr>
    ~;
    my $search_batch_counter = 0;
    foreach my $row (@rows) {
	my ($experiment_id,$experiment_tag,$experiment_name) = @{$row};

	#### Find out what search_batches exist for this experiment
	my $sql = qq~
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
	    $content .= "<TR VALIGN='top' BGCOLOR='#efefef'> \n";
	}else{
	    $content .= "<TR VALIGN='top'> \n";
	}
	$content .= qq~
	<TD NOWRAP>- <font color="green">$experiment_tag:</font> $experiment_name</TD>
	<TD NOWRAP ALIGN=CENTER><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment&experiment_id=$experiment_id">[View/Edit]</A></TD>
	<TD NOWRAP ALIGN=CENTER><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeFractions?action=QUERYHIDE&QUERY_NAME=PR_SummarizeFractions&experiment_id=$experiment_id">[View]</A></TD>
	<TD>
      ~;

	foreach my $search_batch_row (@search_batch_rows) {
	    my ($search_batch_id,$search_batch_subdir,$set_tag) = @{$search_batch_row};
	    $content .= qq~
	    &nbsp;&nbsp;&#8211;&nbsp;<font color="green">$set_tag</font> ($search_batch_id:&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizePeptides?action=QUERY&QUERY_NAME=PR_SummarizePeptides&search_batch_id=$search_batch_id&probability_constraint=\%3E.9&n_annotations_constraint=%3E0&sort_order=tABS.row_count%20DESC&display_options=GroupReference&input_form_format=minimum_detail">P&gt;0.9</A>&nbsp;--&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizePeptides?action=QUERY&QUERY_NAME=PR_SummarizePeptides&search_batch_id=$search_batch_id&annotation_status_id=Annot&n_annotations_constraint=%3E0&sort_order=tABS.row_count%20DESC&display_options=GroupReference&input_form_format=minimum_detail">Annot</A>)<BR/>
	    ~;
	}

	$content .= qq~
	</TD>
      	</TR>
	~;
    }
    return $content;
}


##############################################################################
# make_full_experiment_html
#
# Return a block of html to print a full experimental form
###############################################################################
sub make_full_experiment_html {
	my ($content);
	
	
	my %args = @_;
	my $results_set_array_ref = $args{exp_results_set_aref};
	my $sample_set_array_ref  = $args{sample_results_set_aref};
	
	my @rows = @{$results_set_array_ref};
	my @all_samples_results = @{$sample_set_array_ref};
	
	my $project_id = $sbeams->getCurrent_project_id();
	
	
	 foreach my $row (@rows) {
      my ($experiment_id,$experiment_tag,$experiment_name) = @{$row};

      #### Find out what search_batches exist for this experiment
    my  $sql = qq~
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


##Look for sample information for one expeiment
	$sql = qq~
SELECT ps.proteomics_sample_id, ps.sample_tag
FROM $TBPR_PROTEOMICS_SAMPLE ps
JOIN $TBPR_EXPERIMENTS_SAMPLES es ON (ps.proteomics_sample_id = es.proteomics_sample_id)
WHERE es.experiment_id = $experiment_id
~;

	my @samples_per_exp_results = $sbeams->selectSeveralColumns($sql);
#	$log->debug(Dumper(\@samples_per_exp_results));
	
###collect some html to display the sample info or make a default message with a link to add some info
	my $sample_info_html = '';
 	if (@samples_per_exp_results  ){
	   $sample_info_html = "<table border=0>";
	   foreach my $sample_info_aref (@samples_per_exp_results){
	      my $sample_tag = $sample_info_aref->[1];
	      my $proteomics_sample_id = $sample_info_aref->[0];
	      
	    #  $log->debug("SAMPLE TAG '$sample_tag' SAMPLE_ID '$proteomics_sample_id'");
	      $sample_info_html .= qq ~
	      	<tr>
	      	  <td >$sample_tag</td>
	      	  <td >
	      	    <a href="$manage_table_url_samples&proteomics_sample_id=$proteomics_sample_id&ShowEntryForm=1">Edit/View
	      	  </td>
	      	</tr>
	      ~;
	   }
	   
  ###Provide a drop down to select a sample already entered for this project
	  
	   my $sample_option_list_html = make_option_list(sample_info => \@all_samples_results,
							  experiment_info => \@samples_per_exp_results,
							  experiment_id   => $experiment_id);
   ###Only display the drop down if user has write access
	   if  ($sbeams->isProjectWritable()){
		   $sample_info_html .= qq~
		   	<TR>
		   	 <TD>
			   	$sample_option_list_html
			 </TD>
			</TR>
		  
		   ~;
		  
	  ##Provide a link to add a new sample associated with with this experiment
		    $sample_info_html .= qq ~
		      <TR>
		   	   <TD>
		        <br>
		  		  <a href="$add_sample_cgi_url?experiment_id=$experiment_id&action=Pick_sample" target='_blank'>View All Proteomic Samples</a>
		  	   </TD>
			  </TR>
		  	
		  	~;
	   }
	   $sample_info_html .= "</TABLE>";#close the table
	   
	}else{
  ##If no samples have been associated with this experiment show some defualt info if they have write access 
	  if  ($sbeams->isProjectWritable()){
	      my $sample_option_list_html = make_option_list(sample_info => \@all_samples_results,
							     experiment_info => [],
							     experiment_id   => $experiment_id);

		  $sample_info_html .= "No Samples Registered for this project<br>";
		  $sample_info_html .= $sample_option_list_html;
		  $sample_info_html .=  "<a href='$add_sample_cgi_url?experiment_id=$experiment_id&action=Pick_sample' target='_blank'>View All Proteomic Samples</a>";
	  }	
	}  
	
	
	##Print out the full experiment info
     $content .= qq~
<TABLE CLASS='table_setup'>
     <TR CLASS='rev_gray'>
	   <TD NOWRAP COLSPAN=2 WIDTH=300>- <font color="white">$experiment_tag</font>: $experiment_name</TD>
       <TD NOWRAP ALIGN='CENTER' COLSPAN=2 WIDTH=300 ><A CLASS='blue_button' HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment&experiment_id=$experiment_id">View/Edit Experiment Description</A></TD>
     </TR>
     <TR class='grey_bg'>
       <TD><IMG SRC='$HTML_BASE_DIR/images/clear.gif' HEIGHT=25></TD>
	   <TD ALIGN='LEFT'><b>Sample Information</b></TD>
	   <TD COLSPAN=2 ALIGN='CENTER' >$sample_info_html</TD>
     </TR>	

     <TR class='lite_blue_bg'>
	 <TD><IMG SRC='$HTML_BASE_DIR/images/clear.gif' HEIGHT=25></TD>
	 <TD ALIGN='LEFT'>MS Run Information</TD>
	  <TD NOWRAP COLSPAN=2 ALIGN='CENTER'>
	    <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeFractions?action=QUERYHIDE&QUERY_NAME=PR_SummarizeFractions&experiment_id=$experiment_id">&nbsp;&nbsp;Number of MS Runs: @count_ms_runs</A>
	  </TD>
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

        $content .= qq~
	     <TR>
	    	<TD>&nbsp;</TD>
	  		<TD ALIGN=LEFT>Search batch $search_batch_subdir ($search_batch_id) against <font color="green">[$set_tag]</font></TD>
			<TD ALIGN=CENTER> <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizePeptides?action=QUERY&QUERY_NAME=PR_SummarizePeptides&search_batch_id=$search_batch_id&probability_constraint=\%3E.9&n_annotations_constraint=%3E0&sort_order=tABS.row_count%20DESC&display_options=GroupReference&input_form_format=minimum_detail">PeptideProphet Summary<br/>(P &gt; 0.9)</A></TD>
     ~;
		if (@protein_summary_status){#ProteinProphet annotation is available
			$content .= qq~ <TD ALIGN=CENTER>ProteinProphet Summary<br/><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseProteinSummary?protein_group_probability_constraint=%3E0.9&QUERY_NAME=PR_BrowseProteinSummary&search_batch_id=$search_batch_id&action=QUERY">View</A>&nbsp; <FONT COLOR="#CCCCCC">[ADD]</FONT></TD> ~;
	    }else{ #allow the user to add ProteinProphet annotation
		 	$content .= qq~ <TD ALIGN=CENTER>ProteinProphet Summary<br/><FONT COLOR="#CCCCCC">View</FONT>&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/UploadProteinSummary?search_batch_id=$search_batch_id">[ADD]</A></TD> ~;
	    }

		$content .= qq~
		</TR>
		~;
      }
        $content .= qq~
		<TR><TD COLSPAN=3>&nbsp;</TD></TR>
        ~;
  }#close foreach looping rows of experiments


	return ($content);	
}#close make_full_experiment_html

##############################################################################
# make_all_samples_for_project_html
#
# Return a block of html to print out all the samples for this project
###############################################################################
sub make_all_samples_for_project_html {
	my ($content);
	my %args = @_;
	
	my $sample_set_array_ref  = $args{sample_results_set_aref};
	my $project_id = $args{project_id};
	
	
	
	my $content = '';
	my @all_samples_results = @{$sample_set_array_ref};
	##Add in a view for all the samples associated with this project
	
	$content .= qq~ <TR class='white_bg'>
	 				 <TD colspan=4>
	 				 <H2 class='med_gray_bg'>Sample Information</H2>
	 				</TR>
	 			~;
	if (@all_samples_results){
	
	 $content .= qq~ 
	 				<TR>
	   				 <TD colspan=4>
	   				  <br>
				      <TABLE class='table_setup'>
					  <TR>
					    <TD colspan=3 class='rev_gray'>
					      <h3>View All Samples for the project</h3>
					    </TD>
					  <TR>
					  <TR class='grey_bg'>
					    <TH>Count</TH>
					    <TH>Sample Tag</TH>
					    <TH>Link</TH>
					  </TR>
					
				~;
				
	my $row_count = 1;
	foreach my $sample_aref (@all_samples_results){
		my $sample_tag = $sample_aref->[1];
	    my $proteomics_sample_id = $sample_aref->[0];
	    $content .= $q->Tr(
	    		    $q->td({class=>'pad_cell'}, $row_count),
	    		    $q->td({class=>'pad_cell'}, $sample_tag),
	    		    $q->td({class=>'pad_cell'}, "<a href='$manage_table_url_samples&ShowEntry_Form=1&proteomics_sample_id=$proteomics_sample_id'>View/Edit Record</a>"),
	    		    );
	    $row_count ++;
	}
	
	$content .= qq~ </TABLE>
				    </TD>
				   </TR>
				   <TR>
				     <TD>
				       <a href="$manage_table_url_samples&ShowEntryForm=1&project_id=$project_id" target='_blank'>Add New Sample to database</a>
				   	 </TD>
				   </TR>
				 ~;
	}else{
		#if no sample print default message
		$content .= qq~ 
					<TR class='white_bg'>
					  <TD colspan=4>
					   <p class='red_bg'>No proteomic samples registered for this project</p>
					 <a href="$manage_table_url_samples&ShowEntryForm=1&project_id=$project_id" target='_blank'>[Add Proteomic Sample]</a>
					   	  
					  </TD>
					</TR>
					
					~;
					
	}
	return $content;
}

	
