#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This program shows a users personal view of the data
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
use vars qw ($sbeams $sbeamsMOD $prot_exp_obj $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q);
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

$prot_exp_obj = new SBEAMS::Proteomics::Proteomics_experiment();
$prot_exp_obj->setSBEAMS($sbeams);

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
my $manage_table_url_samples = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=PR_proteomics_sample";

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
  if ($parameters{action} eq "Add_sample") {
    $sbeamsMOD->display_page_header();
    upload_data(ref_parameters=>\%parameters);
    $sbeamsMOD->display_page_footer();
  }elsif($parameters{action} =~ "Pick_sample"){
  	
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
  
  


  #### Print Info On how to associate A sample to a experiment
  print h2("Associate a sample to a proteomics experiment");
  my $project_id = $sbeams->getCurrent_project_id();
  my $html_info = $sbeams->getProjectDetailsTable(project_id=>$project_id);
  print h2("THIS IS NOT DONE");


}


###############################################################################
# Upload Data
###############################################################################
sub upload_data {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
  
  my $sample_id = $parameters{sample_id};
  my $experiment_id = $parameters{experiment_id};
  
   
  die ("Need to provide sample_id you gave '$sample_id'") unless $sample_id =~ /^\d/;
  die ("Need to provide experiment_id you gave '$experiment_id'") unless $experiment_id =~ /^\d/;
  
  my $return_info = $prot_exp_obj->add_sample_to_experiments_samples_linker_table(
  										  experiment_id => $experiment_id,
  										  sample_id		=> $sample_id
  									);
  	if ($return_info > 0){
  		
  		my $experiment_tag = $prot_exp_obj->get_experiment_tag(experiment_id => $experiment_id);
  		my $sample_tag     = $prot_exp_obj->get_sample_tag(sample_id => $sample_id);
  		
  		print h2("Succesfully Added Sample '$sample_tag' To Experiment:$experiment_tag"),
  		h3("To associate another another sample to this experiment click below"),
  		"<a href='Add_proteomic_sample.cgi?experiment_id=$experiment_id&action=Pick_sample'>Add new sample</a>",
  		br(),
  		"&nbsp; -- or --",
  		br(),
  		button(-name=>'closewindow',
                          -value=>'Close Window',
                          -onClick=>"javascript:window.close();"),
  	}else{
  		print h2("There was an error adding sample_id '$sample_id to experiment_id '$experiment_id'"),
  			  br(),
  			  p("ERROR:'$return_info'");
  	}
  	
 
}


###############################################################################
# pick_sample
# Assoicate a sample to a experiment id
###############################################################################
sub pick_sample {
  my %args = @_;
	#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
  
  my $experiment_id = $parameters{experiment_id};
  
  my $experiment_tag 		= $prot_exp_obj->get_experiment_tag(experiment_id => $experiment_id);
  
  my @all_sample_names 		= $prot_exp_obj->get_all_sample_names();
  my $formated_option_list 	= $prot_exp_obj->format_option_list(results_set_ref => \@all_sample_names);
  my $blank_option_list 	= $prot_exp_obj->format_option_list(results_set_ref => \@all_sample_names, 
  															    make_blank =>1);
  
  print h2("Pick one sample to associate with Proteomic Experiment: '$experiment_tag'"),
  		
  		start_form(-name=>'pick_sample'),
  		table({border=>0},
  		  Tr(
  		    td({class=>'grey_header'}, "All Proteomic Samples"),
		  	td("&nbsp;"),
			td({class=>'grey_header'}, "Choosen Sample"),
  		  ),
  		  Tr(
  		    td("<SELECT NAME='all_sample_id' id='list1' size=10> $formated_option_list</SELECT>"
		  	),
		  	td("<input type='button' value=' --> ' onclick=\"add2list('list1','list2')\" />"
		       
		    	,br(),"<input type='button' value=' <-- ' onclick=\"removefromlist('list1','list2')\" />"
			),
		    td("<select name='sample_id' id='list2' size='10'>$blank_option_list</select>"),
		  ),
		  Tr(
		    td(submit(-name		=>'Add Sample', 
		    		  -onClick=>"submitsample(this)"),
		      br(),
		  	  button(-name=>'closewindow',
                          -value=>'Close Window',
                          -onClick=>"javascript:window.close();"),
		  	  
		  	  hidden(-name		=>'action', 
		  		 	 -value		=>'Add_sample',
		  		 	 -override 	=> 1,),
		  	  hidden(-name		=>'experiment_id',
		  		 	 -value		=>$experiment_id,
		  		 	 -override 	=> 1,),
		  	),
		  	td("&nbsp;"),
		  	td("&nbsp;"),
		  ),
		  
  		  endform(),
  		  
  		  );#end the table
  		  
  	print br(),br(),
  		  table(
  			Tr(
  		     td({class=>'grey_bg'}, "Add New Sample to database"),
  		     td("<a href='$manage_table_url_samples&ShowEntryForm=1'>Add Sample</a>"),
  		  	)
  		  );
  		
}

