#!/tools64/bin/perl 


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use Data::Dumper;
use File::Basename;
use File::Path qw(mkpath);
use Site;
use Batch;
use SetupPipeline;
use Help;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $sbeams_solexa_groups $utilities $q 
             $current_contact_id $current_username $current_email
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS $DISPLAY_SUMMARY);
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::SolexaTrans;
use SBEAMS::SolexaTrans::Settings;
use SBEAMS::SolexaTrans::Tables;

use SBEAMS::SolexaTrans::Solexa;
use SBEAMS::SolexaTrans::Solexa_file_groups;
use SBEAMS::SolexaTrans::SolexaTransPipeline;
use SBEAMS::SolexaTrans::SolexaUtilities;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SolexaTrans;
$utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

$sbeamsMOD->setSBEAMS($sbeams);
$utilities->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
$sbeams_solexa_groups->setSBEAMS($sbeams);		#set the sbeams object into the solexa_groups_object

#use CGI;
#$q = new CGI;
#$cgi = $q;


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
$QUIET   = $OPTIONS{"quiet"} || 0;
$DEBUG   = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
$PROGRAM_FILE_NAME = 'main.cgi';
$DISPLAY_SUMMARY = "DISPLAY_SUMMARY";		#key used for a CGI param

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
  if  ($parameters{output_mode} =~ /xml|tsv|excel|csv/){		#print out results sets in different formats
    print_output_mode_data(parameters_ref=>\%parameters);
  }else{
    $sbeamsMOD->printPageHeader();
    print_javascript();
    # THIS MAY BREAK IN FUTURE IF YOU TRY TO HAVE THE FORM ON THIS PAGE SUBMIT AND STILL USE THE JOB SELECTION BOXES
    create_javascript_hashes() unless $parameters{'Get_Data'};
    $sbeamsMOD->updateSampleCheckBoxButtons_javascript();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }
   

} # end main

###############################################################################
# print_javascript 
##############################################################################
sub print_javascript {

    my $uri = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/";

#google.load("prototype","1.6");
print qq~
<script type="text/javascript" src="http://www.google.com/jsapi"></script>
<script type="text/javascript">
google.load("prototype","1.6");
<!--
<!-- $uri -->

function confirmSubmit(message) {
  var agree = confirm(message);
  if (agree) 
    return true;
  else
    return false;
}

function handleJobSelectChange(event) {
  var element = Event.element(event);
  var name = \$(element).readAttribute("name");
  var sample_id = name.split("__",1);
  var sa_id = 'sa'+\$(element).getValue();

  var status = info[sa_id]['STATUS'];
  var result = info[sa_id]['RESULT'];
  var params = info[sa_id]['PARAMS'];
  var control = info[sa_id]['CONTROL'];

  var status_div = sample_id + '__status';
  \$(status_div).innerHTML = status;
  
  var result_div = sample_id + '__params';
  \$(result_div).innerHTML = params;

  var result_div = sample_id + '__result';
  \$(result_div).innerHTML = result;

  var control_div = sample_id + '__control';
  \$(control_div).innerHTML = control;
}

function testFunc(){
 alert("clicked");
}   
    //Determines what browser is being used and what OS is being used.
    // convert all characters to lowercase to simplify testing
    var agt=navigator.userAgent.toLowerCase();
    
// *** BROWSER VERSION ***
    var is_nav  = ((agt.indexOf('mozilla')!=-1) && (agt.indexOf('spoofer')==-1)
                && (agt.indexOf('compatible') == -1) && (agt.indexOf('opera')==-1)
									 && (agt.indexOf('webtv')==-1));
var is_ie   = (agt.indexOf("msie") != -1);
var is_opera = (agt.indexOf("opera") != -1);

// *** PLATFORM ***
    var is_win   = ( (agt.indexOf("win")!=-1) || (agt.indexOf("16bit")!=-1) );
var is_mac    = (agt.indexOf("mac")!=-1);
var is_sun   = (agt.indexOf("sunos")!=-1);
var is_linux = (agt.indexOf("inux")!=-1);
var is_unix  = ((agt.indexOf("x11")!=-1) || is_linux);

//-->
</SCRIPT>
~;
return 1;
}

sub create_javascript_hashes{
  print qq~
<SCRIPT TYPE="TEXT/JAVASCRIPT">
~;

  my %job_results = ();
  my $job_results_ref = \%job_results;
  my $project_id = $sbeams->getCurrent_project_id; 
  if (!$project_id) {
    error("You must set a project using the Project selector to continue");
  }
  my $sql = $sbeams_solexa_groups->get_sample_job_status_sql(project_id => $project_id);

  $sbeams->fetchResultSet( sql_query => $sql,
                           resultset_ref => $job_results_ref );
  
  my $aref = $$job_results_ref{data_ref};
  my $jobid_idx = $job_results_ref->{column_hash_ref}->{Job_ID};
  my $jobname_idx = $job_results_ref->{column_hash_ref}->{Job_Name};
  my $status_idx  = $job_results_ref->{column_hash_ref}->{Job_Status};
  my $sample_idx  = $job_results_ref->{column_hash_ref}->{Sample_ID};

  my %info;
  foreach my $row_aref (@{$aref} ) {
    my $slimseq_sample_id = $row_aref->[$sample_idx];
    my $jobname = $row_aref->[$jobname_idx];
    my $status = $row_aref->[$status_idx];
    my $jobid = $row_aref->[$jobid_idx];

    my $control;
    my $result;

    #need to make sure the query has the slimseq_sample_id in the first column
    #    since we are going directly into the array of arrays and pulling out values
    # the six statuses are: QUEUED, RUNNING, UPLOADING, COMPLETED, PROCESSED, CANCELED
    if ($status eq 'QUEUED') {
      # if it's queued we want to offer the ability to cancel the job
      $control = "<a href=\"cancel.cgi?jobname=$jobname\">Cancel Job</a>";
      $result = "<a href=\"View_Solexa_files.cgi?action=view_file&jobname=$jobname\">View Job</a>";
    } elsif ($status eq 'RUNNING') {
      # if it's running we want to offer the ability to cancel the job
      $control = "<a onclick=\"return confirmSubmit(\\'This job is running.  Are you sure you want to cancel this job?\\')\" href=\"cancel.cgi?jobname=$jobname\">Cancel Job</a>";
      $result = "<a href=\"View_Solexa_files.cgi?action=view_file&jobname=$jobname\">View Job</a>";
    } elsif ($status eq 'CANCELED') {
      $control = "<a href=\"Samples.cgi?jobname=$jobname\">Restart Job</a>";
      $result = "";
    } elsif ($status eq 'UPLOADING') {
      $control = "No Actions";
      $result = "<a href=\"dataDownload.cgi?slimseq_sample_id=$slimseq_sample_id&jobname=$jobname\">Results</a>";
    } elsif ($status eq 'PROCESSED') { 
      # processed means that the STP finished but the upload failed to the SolexaTrans database
      $control = "<a href=\"upload.cgi?jobname=$jobname\">Restart Upload</a>";
      $result = "<a href=\"dataDownload.cgi?slimseq_sample_id=$slimseq_sample_id&jobname=$jobname\">Results</a>";
    } elsif ($status eq 'COMPLETED') {
      $control = "<a onclick=\"return confirmSubmit(\\'This job has completed.  Are you sure you want to restart this job?\\')\" href=\"Samples.cgi?jobname=$jobname\">Restart Job</a>";
      $result = "<a href=\"dataDownload.cgi?slimseq_sample_id=$slimseq_sample_id&jobname=$jobname\">Results</a>";
    } else {
      $control = "ERROR: Contact admin";
      $result = "ERROR: Contact admin";
    }

    $info{$jobid}{'PARAMS'} = "<a href=Status.cgi?jobname=$jobname>View Params</a>";
    $info{$jobid}{'STATUS'} = $status;
    $info{$jobid}{'CONTROL'} = $control;
    $info{$jobid}{'RESULT'} = $result;


  } # end foreach row

  print "info = {\n";

  foreach my $jobid (keys %info) {
      print "sa$jobid:{";
      print "STATUS:'".$info{$jobid}{'STATUS'}."',";
      print "CONTROL:'".$info{$jobid}{'CONTROL'}."',";
      print "PARAMS:'".$info{$jobid}{'PARAMS'}."',";
      print "RESULT:'".$info{$jobid}{'RESULT'}."'},\n";
  }
  print "};\n";
#  var info = { 
#                    sa71:{STATUS:'COMPLETED',CONTROL:'STUFF',RESULT:'MORESTUFF'},
#                    sa72:{STATUS:'COMPLETED',CONTROL:'STUFF',RESULT:'MORESTUFF'}
#                 };


print qq~
</SCRIPT>
~;

return 1;
}
                      

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


  #### Define variables for Summary Section
  my $project_id = $parameters{PROJECT_ID} || $sbeams->getCurrent_project_id; 
  if (!$project_id) {
    error("You must set a project using the Project selector to continue");
  }
  my $pi_first_name = '';
  my $pi_last_name = '';
  my $username = '';
  my $project_name = 'NONE';
  my $project_tag = 'NONE';
  my $project_status = 'N/A';
  my $pi_contact_id;
  my (%array_requests, %array_scans, %quantitation_files);

  ## Need to add a MainForm in order to facilitate proper movement between projects.  Otherwise some cgi params that we don't want might come through.
  print qq~ <FORM METHOD="post" NAME="MainForm">
       <INPUT TYPE="hidden" NAME="apply_action_hidden" VALUE="">
       <INPUT TYPE="hidden" NAME="set_current_work_group" VALUE="">
       <INPUT TYPE="hidden" NAME="set_current_project_id" VALUE="">
  </form>
  ~;

  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();
  $current_email = $sbeams->getEmail($current_contact_id); 
  if (!$current_email) { 
    $log->error("User $current_username with contact_id $current_contact_id does not have an email in the contact table.");
    die("No email in SBEAMS database.  Please contact an administrator to set your email before using the SolexaTrans Pipeline");
  }


#  if ($parameters{jobname} && !$parameters{step}) {
#    $parameters{step} = 1;
#  }

  print qq!<div id="help_options" style="float: right;"><a href="javascript://;" onclick="toggle_help('help');">Help</a></div>!;
    print qq(<div id="help" style="display:none">);
    print help_all();
    print "</div>\n";

  # Show the project widget
  my $html_ref = $sbeams->getMainPageTabMenu( cgi => $q );
  print $$html_ref;
  print "<br>";

  if ($parameters{Get_Data} eq 'Compare Samples') {
    print_sample_comparison(ref_parameters=>$ref_parameters);
  } elsif ($parameters{Get_Data} eq 'Draw Plots') {
    print_sample_plots(ref_parameters=>$ref_parameters);
  } elsif (!$parameters{Get_Data}) {
    print_sample_selection(ref_parameters=>$ref_parameters);
  } else {
    error("There was an error with step selection.");
  }
  return;

}# end handle_request


###############################################################################
# display_sub_tabs  
#
#Determine which sub tabs should be shown.  Used to make tabs for data types within a
# a data section
###############################################################################

sub display_sub_tabs {
	my %args = @_;
	
	my $display_type	= $args{display_type};
	my @tabs_names	 	= @ {$args{tab_titles_ref} };
	my $page_link 		= $args{page_link};
	my $selected_tab_numb 	= $args{selected_tab};
	my $parent_tab 		= $args{parent_tab};
	
	$log->debug("SUB TAB INFO ".  Dumper(\%args));
	my $count = 0;
	foreach my $tab_name (@tabs_names){
		#loop through the tabs to display.  When we get to the one that is the 
		# "selected" one use it's array position number as the selected_tab count
		if ($display_type eq $tab_name){			
			#print "TAB NAME '$tab_name' '$selected_tab_numb' '$count'<br>";
			$sbeamsMOD->print_tabs(tab_titles_ref	=>\@tabs_names,
			     			page_link	=>$page_link,
			     			selected_tab	=>$count,
			     			parent_tab	=>$parent_tab,);
			return 1;		
		}
		$count ++;
	}
	#if there is nothing to show.  Make sure to have a backstop to print out a message when chooseing the data to print 
}


###############################################################################
# make_tab_names  
#
#Take a hash and and sort the keys by their position key and only return ones with data
###############################################################################

sub make_tab_names {
	my $SUB_NAME = "make_tab_names";
	my %types_h = @_;
	
        #order which the tabs will be displayed on the screen
	my @tab_names = sort { $types_h{$a}{POSITION} <=> $types_h{$b}{POSITION}} keys %types_h; 

        #only make tabs for data types with data
	@tab_names =  grep { $types_h{$_}{COUNT} > 0 } (@tab_names);				
	return @tab_names

}
###############################################################################
# pick_data_to_show  
#Used to determine which data set should be shown.  
#Order of making a decision.  CGI param, default data type(if it has data), any data type that has data
###############################################################################
sub pick_data_to_show {
	
	my %args = @_;
	
	my $default_data_type 	=    $args{default_data_type};
	my %data_types_h 	= % {$args{tab_types_hash} };
  	my %parameters	 	= % { $args{param_hash} };		
        #parameters may be produce when using readResults sets method, instead of reading directly from the cgi param method
	
	my $SUB_NAME = "pick_data_to_show";
	
	#Need to choose what type of data summary to display  
	
	my $all_cgi_tab_val = '';
	
        #if there is a cgi parm with the 'tab' key use it for the data type to display
	if ($all_cgi_tab_val = $parameters{tab} ){				
		foreach my $cgi_tab_val (split /,/,$all_cgi_tab_val ){
			$cgi_tab_val = uc $cgi_tab_val;
			
                        #need to make sure the tab param is not coming from other parts of the program.
                        # this will ensure it's one of the tabs we are interested in
			if (grep { $cgi_tab_val eq $_} keys %data_types_h){	
			 
                                #make sure the tab has data, a user might have switched projects to one without this type of data
				if ($data_types_h{$cgi_tab_val}{COUNT} > 0){	
                                        #need to return the upper case value since the print tabs method will make it lower case
					return (uc $cgi_tab_val, 0);		
				}
			}
		}
	}

	#if the default value comes in and it has data to display, show it.
	return ($default_data_type, 0) if ( $data_types_h{$default_data_type}{COUNT} > 0);	
	
	
        #Else loop through all the data types and show the first one that has data to display in the summary
	foreach my $data_type (keys %data_types_h){
		
		if ($data_types_h{$data_type}{COUNT} > 0) {		
			return ($data_type, 0);
		}else{
			#print "NOTHING FOR '$data_type'<br>";
		}
		
	}
	
	
	return 'NOTHING TO SHOW';		#if there is nothing to display come here
	
}


###############################################################################
# print_sample_selection
###############################################################################
sub print_sample_selection {
  	my %args = @_;
  
	my @columns = ();
	my $sql = '';
	
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %max_widths;
	my %rs_params = $sbeams->parseResultSetParams(q=>$q);
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/main.cgi";
	my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

	my %url_cols      = ();
	my %hidden_cols   = ();
	my $limit_clause  = '';
	my @column_titles = ();
        my $cbox;
  	
	my ($display_type, $selected_tab_numb);
  	
	my $solexa_info;	
	my @default_checkboxes      = ();
	my @checkbox_columns      = ();
  	
  	#$sbeams->printDebuggingInfo($q);
	#### Process the arguments list
 	my $ref_parameters = $args{'ref_parameters'} || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};

	my $project_id = $sbeams->getCurrent_project_id();
        if (!$project_id) {
          error("You must set a project using the Project selector to continue");
        }
	
	my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

	## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
	if ($parameters{set_current_project_id}) {
		$apply_action = 'QUERY';
	}
 

  #################################################################################
  ##Set up the hash to control what sub tabs we might see
	
	my $default_data_type = 'SOLEXA_SAMPLE';

	my %count_types = ( SOLEXA_SAMPLE	=> {	COUNT => 1,
	   						POSITION => 0,
	   		   			   }	
	   	   	   );

	my @tabs_names = make_tab_names(%count_types);

	($display_type, $selected_tab_numb) =	pick_data_to_show (default_data_type    => $default_data_type,
				    		   		   tab_types_hash 	=> \%count_types,
				    		   		   param_hash		=> \%parameters,
						   		   );

	display_sub_tabs(	display_type  	=> $display_type,
	             		tab_titles_ref	=>\@tabs_names,
	                  	page_link	    => 'main.cgi',
	                  	selected_tab	  => $selected_tab_numb,
                     		parent_tab  	  => $parameters{'tab'},
                   );
	
  #####################################################################################
  ### Show the sample choices

        %hidden_cols = (
                         'Sample_ID' => 1
                        );
	
	if ($apply_action eq 'QUERY' || $apply_action eq 'VIEWRESULTSET') {	
		if ($display_type eq 'SOLEXA_SAMPLE'){
		  	print $solexa_info; # header info generated earlier

			@default_checkboxes = qw(Select_Sample);  #default file type to turn on the checkbox
			@checkbox_columns = qw(Select_Sample);
		        # set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups->setSBEAMS($sbeams);
		
		        # return a sql statement to display all the arrays for a particular project
			$sql = $sbeams_solexa_groups->get_sample_results_sql(project_id    => $project_id, );
						     			
		 	%url_cols = ( 'Sample Tag'	=> "${manage_table_url}solexa_sample&slimseq_sample_id=\%1V",
				      'Select_Sample _OPTIONS' => { 'embed_html' => 1 }
				     );
                                  

		}else{
			print "<h2>Sorry, no samples qualify for the SolexaTrans pipeline in this project</h2>" ;
			return;
		} 
	
     } # end apply action eq QUERY
  ###################################################################
  ## Print the data 
		
 	# start the form to run STP on solexa samples
	print $q->start_form(-name =>'select_samplesForm');

  ###################################################################
  ## get field->checkbox HTML for selecting samples
  	$cbox = $sbeamsMOD->get_sample_select_cbox( box_names => \@checkbox_columns,
                               default_file_types => \@default_checkboxes );

  ###################################################################
  #### If the apply action was to recall a previous resultset, do it
	if ($apply_action eq "VIEWRESULTSET") {
  	  $sbeams->readResultSet(
    	 	resultset_file=>$rs_params{set_name},
     	 	resultset_ref=>$resultset_ref,
     	 	query_parameters_ref=>\%parameters,
    	  	resultset_params_ref=>\%rs_params,
   	 	);
	} else {
	  # Fetch the results from the database server
	  $sbeams->fetchResultSet( sql_query => $sql,
	                     resultset_ref => $resultset_ref );

#    $sbeams->addResultsetNumbering( rs_ref       => $resultset_ref, 
#                                    colnames_ref => \@column_titles,
#                                    list_name => 'Sample num' );	
 
          if ($#{$resultset_ref->{data_ref}} <0 ) {
			print "<h2>Sorry, no samples qualify for the SolexaTrans pipeline in this project</h2>" ;
			return;
		} 
 
    ####################################################################
    ## Need to prepend data onto the data returned from fetchResultsSet in order 
    # to use the writeResultsSet method to display a nice html table
   	  if ($display_type eq 'SOLEXA_SAMPLE') {
		
                create_job_select(resultset_ref=>$resultset_ref); 

		prepend_checkbox( resultset_ref => $resultset_ref,
				  checkbox_columns => \@checkbox_columns,
				  default_checked => \@default_checkboxes,
				  checkbox => $cbox,
				);

    	  }  

   	} # End read or fetch resultset block

   	# Set the column_titles to just the column_names, reset first.
   	@column_titles = ();
   	#  @column_titles = map "$_<INPUT NAME=foo TYPE=CHECKBOX CHECKED></INPUT>", @column_titles;
   	for my $title ( @{$resultset_ref->{column_list_ref}} ) {
     	  if ( $cbox->{$title} ) {
    	     push @column_titles, "$title $cbox->{$title}";
     	  } else {
    	     push @column_titles, $title;
     	  }
   	}

        ###################################################################
  
    	  $log->info( "writing" );
    	  #### Store the resultset and parameters to disk resultset cache
    	  $rs_params{set_name} = "SETME";
    	  $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
		  	    resultset_ref=>$resultset_ref,
			    query_parameters_ref=>\%parameters,
			    resultset_params_ref=>\%rs_params,
  			    query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
	  		   );

	#### Display the resultset
	$sbeams->displayResultSet(resultset_ref=>$resultset_ref,
				query_parameters_ref=>\%parameters,
				rs_params_ref=>\%rs_params,
				url_cols_ref=>\%url_cols,
				hidden_cols_ref=>\%hidden_cols,
				max_widths=>\%max_widths,
				column_titles_ref=>\@column_titles,
				base_url=>$base_url,
				no_escape=>1,
				nowrap=>1,
				show_numbering=>1,
				);
        if ($apply_action eq 'QUERY' || $apply_action eq 'VIEWRESULTSET') {
		print   $q->br,
        "Compare Samples is only valid on jobs that are 'UPLOADING', 'PROCESSED' or 'COMPLETED', other jobs will be ignored.<br>\n",
                        $q->checkbox(-name=>'regenerate_plots',
                                     -value=>'no',
                                     -label => 'Check to regenerate all selected plots'
                                     ),
                        $q->br,
			$q->submit(-name=>'Get_Data',
				#will need to change value if other data sets need to be run
                	       	 -value=>'Compare Samples'),
                        $q->submit(-name=>'Get_Data',
                                   -value=>'Draw Plots')
                        ;
	
		
		print $q->reset;
		print $q->endform;
	}
	#### Display the resultset controls
	$sbeams->displayResultSetControls(resultset_ref=>$resultset_ref,
					  query_parameters_ref=>\%parameters,
					  rs_params_ref=>\%rs_params,
					  base_url=>$base_url,
					 );
	
}

###############################################################################
# print_sample_comparison
###############################################################################
sub print_sample_comparison {
  	my %args = @_;
  
	my @columns = ();
	my $sql = '';
	
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %max_widths;
	my %rs_params = $sbeams->parseResultSetParams(q=>$q);
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/main.cgi";
	my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

	my %url_cols      = ();
	my %hidden_cols   = ();
	my $limit_clause  = '';
	my @column_titles = ();
  	
	my ($display_type, $selected_tab_numb);
  	
	my $solexa_info;	
	my @default_checkboxes      = ();
	my @checkbox_columns      = ();
  	
  	#$sbeams->printDebuggingInfo($q);
	#### Process the arguments list
 	my $ref_parameters = $args{'ref_parameters'} || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};

	my $project_id = $sbeams->getCurrent_project_id();
        if (!$project_id) {
          error("You must set a project using the Project selector to continue");
        }
	
	my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

	## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
	if ($parameters{set_current_project_id}) {
		$apply_action = 'QUERY';
	}

  #################################################################################
  ##Set up the hash to control what sub tabs we might see
	
	my $default_data_type = 'SOLEXA_SAMPLE';

	my %count_types = ( SOLEXA_SAMPLE	=> {	COUNT => 1,
	   						POSITION => 0,
	   		   			   }	
	   	   	   );

	my @tabs_names = make_tab_names(%count_types);

	($display_type, $selected_tab_numb) =	pick_data_to_show (default_data_type    => $default_data_type,
				    		   		   tab_types_hash 	=> \%count_types,
				    		   		   param_hash		=> \%parameters,
						   		   );

	display_sub_tabs(	display_type  	=> $display_type,
	             		tab_titles_ref	=>\@tabs_names,
	                  	page_link	    => 'main.cgi',
	                  	selected_tab	  => $selected_tab_numb,
                     		parent_tab  	  => $parameters{'tab'},
                   );


        if ($apply_action eq "VIEWRESULTSET") {
        	  $sbeams->readResultSet(
          	 	resultset_file=>$rs_params{set_name},
     	        	resultset_ref=>$resultset_ref,
     	 	        query_parameters_ref=>\%parameters,
          	  	resultset_params_ref=>\%rs_params,
          	 	);
	} else {


          if ( $parameters{Get_Data} eq 'Compare Samples') {
            if ($parameters{select_samples}) {
              ##########################################################################
              ### Print out some nice table
              #example '37__Select_Sample,38__Select_Sample,45__Select_Sample,46__Select_Sample,46__Select_Sample'
              my $samples_id_string =  $parameters{select_samples};
              my @sample_ids = split(/,/, $samples_id_string);
              my %unique_sample_ids = map {split(/__/, $_) } @sample_ids;

              foreach my $sample (keys %unique_sample_ids) {
                my $solexa_analysis_id = $parameters{"${sample}__job_select"};
                next unless $solexa_analysis_id;
  
                $sql = $sbeams_solexa_groups->get_detailed_sample_results_sql(slimseq_sample_id => $sample,
                                                                              solexa_analysis_id => $solexa_analysis_id,
                                                                             );

                my %sample_resultset = ();
                my $sample_resultset_ref = \%sample_resultset;
	        # Fetch the results from the database server
                $sbeams->fetchResultSet( sql_query => $sql,
	                                 resultset_ref => $sample_resultset_ref );
                if (defined $sample_resultset_ref->{data_ref}->[0]) {
                  if (scalar (keys %$resultset_ref) < 1) {
                     $resultset_ref = $sample_resultset_ref;
                  } else {
                    push(@{$resultset_ref->{data_ref}}, $sample_resultset_ref->{data_ref}->[0]);
                  }
                }       
                
              }

              %hidden_cols = (
                                "Sample_ID" => 1,
                                "Job_Name" => 1,
                             );

              #### Append the Results Links
              append_filtered_result_links(resultset_ref => $resultset_ref,
                       );


            } else { # no parameter{select_samples}
              $log->error( "User submitted no samples\n" );
              $sbeams->handle_error(message => 'No samples selected, please press back and select samples.',
                                                error_type => 'SolexaTrans_error');
            }
  
          } else {
            $log->error("In Run Pipeline, but Get_Data was not set correctly\n");
            $sbeams->handle_error(message=>"Incorrect step, please go back to the first step and try again.",
                                  error_type=>"SolexaTrans_error");

          }


        } # end if resultset

   	# Set the column_titles to just the column_names, reset first.
   	@column_titles = ();
   	#  @column_titles = map "$_<INPUT NAME=foo TYPE=CHECKBOX CHECKED></INPUT>", @column_titles;
   	for my $title ( @{$resultset_ref->{column_list_ref}} ) {
    	     push @column_titles, $title;
   	}

        ###################################################################
  
    	  $log->info( "writing" );
    	  #### Store the resultset and parameters to disk resultset cache
    	  $rs_params{set_name} = "SETME";
    	  $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
		  	    resultset_ref=>$resultset_ref,
			    query_parameters_ref=>\%parameters,
			    resultset_params_ref=>\%rs_params,
  			    query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
	  		   );

	#### Display the resultset
	$sbeams->displayResultSet(resultset_ref=>$resultset_ref,
				query_parameters_ref=>\%parameters,
				rs_params_ref=>\%rs_params,
				url_cols_ref=>\%url_cols,
				hidden_cols_ref=>\%hidden_cols,
				max_widths=>\%max_widths,
				column_titles_ref=>\@column_titles,
				base_url=>$base_url,
				no_escape=>1,
				nowrap=>1,
				show_numbering=>1,
				);
	
		
	#### Display the resultset controls
#	$sbeams->displayResultSetControls(resultset_ref=>$resultset_ref,
#					  query_parameters_ref=>\%parameters,
#					  rs_params_ref=>\%rs_params,
#					  base_url=>$base_url,
#					 );
	
}

###############################################################################
# print_sample_plots
###############################################################################
sub print_sample_plots {
  	my %args = @_;
  
	my @columns = ();
	my $sql = '';
	
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %max_widths;
	my %rs_params = $sbeams->parseResultSetParams(q=>$q);
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/main.cgi";
	my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

	my %url_cols      = ();
	my %hidden_cols   = ();
	my $limit_clause  = '';
	my @column_titles = ();
  	
	my ($display_type, $selected_tab_numb);
  	
	my $solexa_info;	
	my @default_checkboxes      = ();
	my @checkbox_columns      = ();
  	
  	#$sbeams->printDebuggingInfo($q);
	#### Process the arguments list
 	my $ref_parameters = $args{'ref_parameters'} || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};

	my $project_id = $sbeams->getCurrent_project_id();
        if (!$project_id) {
          error("You must set a project using the Project selector to continue");
        }

	my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

	## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
	if ($parameters{set_current_project_id}) {
		$apply_action = 'QUERY';
	}

  #################################################################################
  ##Set up the hash to control what sub tabs we might see
	
	my $default_data_type = 'SOLEXA_SAMPLE';

	my %count_types = ( SOLEXA_SAMPLE	=> {	COUNT => 1,
	   						POSITION => 0,
	   		   			   }	
	   	   	   );

	my @tabs_names = make_tab_names(%count_types);

	($display_type, $selected_tab_numb) =	pick_data_to_show (default_data_type    => $default_data_type,
				    		   		   tab_types_hash 	=> \%count_types,
				    		   		   param_hash		=> \%parameters,
						   		   );

	display_sub_tabs(	display_type  	=> $display_type,
	             		tab_titles_ref	=>\@tabs_names,
	                  	page_link	    => 'main.cgi',
	                  	selected_tab	  => $selected_tab_numb,
                     		parent_tab  	  => $parameters{'tab'},
                   );


        if ($apply_action eq "VIEWRESULTSET") {
        	  $sbeams->readResultSet(
          	 	resultset_file=>$rs_params{set_name},
     	        	resultset_ref=>$resultset_ref,
     	 	        query_parameters_ref=>\%parameters,
          	  	resultset_params_ref=>\%rs_params,
          	 	);
	} else {


          if ( $parameters{Get_Data} eq 'Draw Plots') {
            if ($parameters{select_samples}) {
              ##########################################################################
              ### Print out some nice table
              #example '37__Select_Sample,38__Select_Sample,45__Select_Sample,46__Select_Sample,46__Select_Sample'
              my $samples_id_string =  $parameters{select_samples};
              my @sample_ids = split(/,/, $samples_id_string);
              my %unique_sample_ids = map { split(/__/, $_) } @sample_ids;
              my %sample_info;

              foreach my $sample (keys %unique_sample_ids) {
                my $solexa_analysis_id = $parameters{"${sample}__job_select"};

                if (!$solexa_analysis_id) { next; }  # skips samples that don't have jobs
                my $status_ref = $utilities->check_sbeams_job_status(solexa_analysis_id => $solexa_analysis_id);
                my ($status, $status_time) = @$status_ref;
                if ($status ne 'UPLOADING' && $status ne 'PROCESSED' && $status ne 'COMPLETED') {
                    print "The job selected for sample $sample is still $status. Cannot draw a plot.".
                          "  Select another job or wait for the job to finish.<br>";
                    next;
                }
  
                $sql = $sbeams_solexa_groups->get_sample_job_output_directory_sql(slimseq_sample_id => $sample,
                                                                                  solexa_analysis_id => $solexa_analysis_id,
                                                                                 );

                my %sample_resultset = ();
                my $sample_resultset_ref = \%sample_resultset;
	        # Fetch the results from the database server
                $sbeams->fetchResultSet( sql_query => $sql,
	                                 resultset_ref => $sample_resultset_ref );

                my $out_dir;
                if (defined $sample_resultset_ref->{data_ref}->[0]) {
                  $out_dir = $sample_resultset_ref->{data_ref}->[0]->[0];
                  $out_dir .= '/' unless $out_dir =~ /\/$/;
                } else {
                  error("No output directory found for slimseq_sample_id $sample and analysis_id $solexa_analysis_id");
                }
                my $project_name = $sbeams->getCurrent_project_name;
                my $cpm_file = $out_dir.$project_name.'.'.$sample.'.cpm';
                $sample_info{$sample}{'OUTDIR'} = $out_dir;
                $sample_info{$sample}{'CPM'} = $cpm_file;
                $sample_info{$sample}{'BASE'} = $project_name.'.'.$sample;
                $sample_info{$sample}{'SA_ID'} = $solexa_analysis_id;

              } # end foreach key sample_info
#print Dumper(\%sample_info);

              my @samples = sort { $a <=> $b} keys %sample_info;
              my @ss = @samples;
              foreach my $sample1 ( @samples) {
                shift(@ss);
                foreach my $sample2 (@ss) {
                  if ($sample1 == $sample2) { next; }
                  my $s1_name = $utilities->get_sbeams_full_sample_name(slimseq_sample_id => $sample1);
                  my $s2_name = $utilities->get_sbeams_full_sample_name(slimseq_sample_id => $sample2);
                  my $s1_job_name = $utilities->get_sbeams_jobname(solexa_analysis_id => $sample_info{$sample1}{"SA_ID"});
                  my $s2_job_name = $utilities->get_sbeams_jobname(solexa_analysis_id => $sample_info{$sample2}{"SA_ID"});

                  print "Drawing plot for Sample $sample1 - $s1_name (job ".
                        "<a href=\"Status.cgi?solexa_analysis_id=".$sample_info{$sample1}{"SA_ID"}."\">".$s1_job_name."</a>)".
                        " vs Sample $sample2 - $s2_name (job ".
                        "<a href=\"Status.cgi?solexa_analysis_id=".$sample_info{$sample2}{"SA_ID"}."\">".$s2_job_name."</a>)<br>";
                  my $filename1 = $sample_info{$sample1}{'CPM'};
                  my $filename2 = $sample_info{$sample2}{'CPM'};
                  my $sa_id1 = $sample_info{$sample1}{'SA_ID'}; # solexa_analysis_id
                  my $sa_id2 = $sample_info{$sample2}{'SA_ID'}; # solexa_analysis_id

                  my $pngbase = 'ssid'.$sample1.'-said'.$sa_id1.'_vs_ssid'.$sample2.'-said'.$sa_id2;

                  my $plot_path1 = $sample_info{$sample1}{'OUTDIR'}.$pngbase.'.png';
                  my $plot_path2 = $sample_info{$sample2}{'OUTDIR'}.$pngbase.'.png';


                  my $zoom_path1 = $sample_info{$sample1}{'OUTDIR'}.$pngbase.'_zoom.png';
                  my $zoom_path2 = $sample_info{$sample2}{'OUTDIR'}.$pngbase.'_zoom.png';


                  # look to see if a plot exists
                  my $plot_exists = '';
                  if (-e $plot_path1 && -e $plot_path2) {
                    $plot_exists = $plot_path1;
                  } elsif (-e $plot_path1 && ! -e $plot_path2) {
                    system("cp $plot_path1 $plot_path2");
                    $plot_exists = $plot_path1;
                  } elsif (-e $plot_path2 && ! -e $plot_path2) {
                    system("cp $plot_path2 $plot_path1");
                    $plot_exists = $plot_path2;
                  }
                  
                  my $imgref = $HTML_BASE_DIR.'/images/tmp/SolexaTrans';
                  if ($plot_exists && !$parameters{'regenerate_plots'}) {
                    print "Using cached plot<br>";
                    system("cp $plot_exists $IMG_BASE_DIR");
                    print "<img src=\"$imgref/$pngbase.png\"><br><br>";
                  } else {
                    # if the CPM files exists
                    if (! -e $filename1) {
                      print "$filename1 does not exist<br>";
                      next;
                    }
                    if (! -e $filename2) {
                      print "$filename2 does not exist<br>";
                      next;
                    }

                   

                    # if the plot doesn't exist, then generate it
                    my $tmp_path = '/solexa/trans/tmp/'.$pngbase.'.png';
                    my $tmp_zoom = '/solexa/trans/tmp/'.$pngbase.'_zoom.png';

                    my $rscript = get_r_plot_script();
                    $rscript =~ s/SAMPLE1/$sample1 - $s1_name/g;
                    $rscript =~ s/SAMPLE2/$sample2 - $s2_name/g;
  
                    $rscript =~ s/FILENAME1/$filename1/;
                    $rscript =~ s/FILENAME2/$filename2/;
  
                    $rscript =~ s/ZOOM_FILENAME/$tmp_zoom/;
                    $rscript =~ s/PNG_FILENAME/$tmp_path/;

#                    print "R is \n";
#                    print $rscript."\n\n\n";
                    my $now = time;
                    my $rscript_base = '/solexa/trans/tmp/plot-'.$sample1.'_'.$sample2.'-'.$now;
                    my $rscript_name = $rscript_base.'.R';
                    open OUT, ">$rscript_name" or die "Can't write R file: $rscript_name\n";
                    print OUT $rscript;
                    close OUT;

                    my $rscript_err = $rscript_base.'.err';

                    my $cmd = "$R_BINARY CMD BATCH --slave $rscript_name 1>&2 $rscript_err";
                    system("$cmd");# == 0 || R_error($cmd, $rscript_err);
                    my $cp_cmd = "cp $tmp_path $IMG_BASE_DIR";
                    system("$cp_cmd");
                    print "<img src=\"$imgref/$pngbase.png\">";
                    print "<br><br>\n";
                    my $save_cmd1 = "cp $tmp_path $plot_path1";
                    system("$save_cmd1");
                    my $save_cmd2 = "cp $tmp_path $plot_path1";
                    system("$save_cmd2");
                  }
                }
              }


            } else { # no parameter{select_samples}
              $log->error( "User submitted no samples\n" );
              $sbeams->handle_error(message => 'No samples selected, please press back and select samples.',
                                                error_type => 'SolexaTrans_error');
            }
  
          } else {
            $log->error("In Run Pipeline, but Get_Data was not set correctly\n");
            $sbeams->handle_error(message=>"Incorrect step, please go back to the first step and try again.",
                                  error_type=>"SolexaTrans_error");

          }


        } # end if resultset


}

sub R_error{
  my $cmd = shift;
  my $rscript_err = shift;
                         open(ERR,"$rscript_err") || warn "Can't open R error text";
                         my $text = <ERR>;
                         close ERR;
                         die "System command failed - $cmd \nERROR $text \nRC: $?\n";
}

sub postProcessResultset {
}

###############################################################################
# create_job_select
###############################################################################
sub create_job_select {
	my %args = @_;
	
	my $resultset_ref = $args{resultset_ref};
	#data is stored as an array of arrays from the $sth->fetchrow_array 
	# each row is a row from the database holding an aref to all the values
	my $aref = $$resultset_ref{data_ref};		
	
  	my $id_idx = $resultset_ref->{column_hash_ref}->{"Sample ID"};
        my $solexastatus_idx = $resultset_ref->{column_hash_ref}->{"Solexa Status"};
	
   	########################################################################################
 	my $anchor = '';
 	my $pad = '&nbsp;&nbsp;&nbsp;';
	foreach my $row_aref (@{$aref} ) {

	  #need to make sure the query has the slimseq_sample_id in the first column 
	  #    since we are going directly into the array of arrays and pulling out values
	  my $slimseq_sample_id  = $row_aref->[$id_idx];
          my $solexa_status = $row_aref->[$solexastatus_idx];

          # get job information 
          my %job_results = ();
          my $job_results_ref = \%job_results;
          my $sql = $sbeams_solexa_groups->get_jobs_by_sample_id_sql(slimseq_sample_id => $slimseq_sample_id);
          
	  $sbeams->fetchResultSet( sql_query => $sql,
	                           resultset_ref => $job_results_ref );

          my $iref = $$job_results_ref{data_ref};
          my $jobid_idx = $job_results_ref->{column_hash_ref}->{Job_ID};
          my $jobname_idx = $job_results_ref->{column_hash_ref}->{Job_Name};
          my $jobstatus_idx = $job_results_ref->{column_hash_ref}->{Job_Status};
          my $jobtag_idx = $job_results_ref->{column_hash_ref}->{Job_Tag};
          my $jobtime_idx = $job_results_ref->{column_hash_ref}->{Job_Created};

          if ($solexa_status eq 'completed') {
            # Create the select boxes for Job selection
            my $num_jobs = scalar (@{$job_results_ref->{data_ref}});
            if ($num_jobs > 1) {
              $anchor = qq(<SELECT name="${slimseq_sample_id}__job_select" id="${slimseq_sample_id}__job_select">);
              foreach my $row_iref (@{$iref}) {
                my $jobtag = $row_iref->[$jobtag_idx];
                $anchor .= '<OPTION VALUE="'.$row_iref->[$jobid_idx].'">';
                if ($jobtag && $jobtag ne '') {
                  $anchor .= $jobtag. " - ".$row_iref->[$jobtime_idx]."</OPTION>\n";
                } else {
                  $anchor .= $row_iref->[$jobtime_idx]."</OPTION>\n";
                }
              }
              $anchor .= '</SELECT>';
              $anchor .= '<script type="text/javascript"> Event.observe("'.$slimseq_sample_id.'__job_select","change",handleJobSelectChange);</script>'."\n";
            } elsif ($num_jobs == 1) {
              $anchor = qq(<INPUT type="hidden" name="${slimseq_sample_id}__job_select" id="${slimseq_sample_id}__job_select" value=");
              $anchor .= $iref->[0]->[$jobid_idx];
              $anchor .= '" />'.$iref->[0]->[$jobtime_idx];
            } else {
              $anchor = "No Jobs for this sample";
            }
          } else {
            $anchor = 'Waiting for Solexa Pipeline to finish';
          }
	  
          push(@$row_aref, $anchor);

          # Create the Job Control info
          # we're only creating one entry here, the text will be changed by javascript
          my $jobid = $iref->[0]->[$jobid_idx];
          my $jobtime = $iref->[0]->[$jobtime_idx];
          my $jobname = $iref->[0]->[$jobname_idx];
          my $status = $iref->[0]->[$jobstatus_idx];

          my $status_anchor;
          # add the status to the hash
          $status_anchor = '<div id="'.$slimseq_sample_id.'__status">'.$status.'</div>' if $solexa_status eq 'completed';
          push(@$row_aref, $status_anchor);


          my $control;
          if ($solexa_status eq 'completed') {
            $control = '<div id="'.$slimseq_sample_id.'__control">';
            if ($status eq 'QUEUED') {
              # if it's running we want to offer the ability to cancel the job
              $control .= "<a href=cancel.cgi?jobname=$jobname>Cancel Job</a>";
            } elsif ($status eq 'RUNNING') {
              # if it's running we want to offer the ability to cancel the job
              $control .= "<a onclick=\"return confirmSubmit('This job is running.  Are you sure you want to cancel this job?')\" href=cancel.cgi?jobname=$jobname>Cancel Job</a>";
            } elsif ($status eq 'CANCELED') {
              $control .= "<a href=Samples.cgi?jobname=$jobname>Restart Job</a>";
            } elsif ($status eq 'UPLOADING') {
              $control .= "No Actions";
            } elsif ($status eq 'PROCESSED') {
              $control .= "<a href=upload.cgi?jobname=$jobname>Start Upload</a>";
            } elsif ($status eq 'COMPLETED') {
              $control .= qq!
              <a onclick="return confirmSubmit('This job has completed.  Are you sure you want to restart this job?')" href=Samples.cgi?jobname=$jobname>Restart Job</a>
              !;
            } elsif ($status eq '') {
              $control .= "<a href=\"Samples.cgi?step=2&slimseq_sample_id=$slimseq_sample_id\">Start Job</a>";
            } else {
              $control .= "ERROR: Contact admin";
            }
         
            $control .= '</div>';
          }
          push(@$row_aref, $control);

          # Create the View Params Link
          my $view_params;
          if ($solexa_status eq 'completed') {
            $view_params = "<div id=\"".$slimseq_sample_id."__params\"><a href=Status.cgi?jobname=$jobname>View Params</a></div>";
          }
          push @$row_aref, $view_params;


          # Create the Results Link
          my $result = '<div id="'.$slimseq_sample_id.'__result">';
          if ($status eq 'QUEUED') {
            # if it's running we want to offer the ability to cancel the job
            $result .= "<a href=View_Solexa_files.cgi?action=view_file&jobname=$jobname>View Job</a>";
          } elsif ($status eq 'RUNNING') {
            # if it's running we want to offer the ability to cancel the job
            $result .= "<a href=View_Solexa_files.cgi?action=view_file&jobname=$jobname>View Job</a>";
          } elsif ($status eq 'CANCELED') {
            $result .= "";
          } elsif ($status eq 'UPLOADING') {
            $result .= "<a href=dataDownload.cgi?slimseq_sample_id=$slimseq_sample_id&jobname=$jobname>Results</a>";
          } elsif ($status eq 'PROCESSED') {
            $result .= "<a href=dataDownload.cgi?slimseq_sample_id=$slimseq_sample_id&jobname=$jobname>Results</a>";
          } elsif ($status eq 'COMPLETED') {
            $result .= "<a href=dataDownload.cgi?slimseq_sample_id=$slimseq_sample_id&jobname=$jobname>Results</a>";
          } elsif ($status eq '') {
            $result .= '';
          } else {
            $result .= "ERROR: Contact admin";
          }

          $result .= '</div>';
          push(@$row_aref, $result);


	} # end foreach row
		
        if ( 1 ){
	    #need to add the column headers into the resultset_ref since DBInterface display results will reference this
	    push @{$resultset_ref->{column_list_ref}} , "Select Job";
            my $idx = $#{$resultset_ref->{column_list_ref}};
	    $resultset_ref->{column_hash_ref}->{"Select Job"} = $idx; 

	    push @{$resultset_ref->{column_list_ref}} , "Job Controls";
            my $idx = $#{$resultset_ref->{column_list_ref}};
	    $resultset_ref->{column_hash_ref}->{"Job Controls"} = $idx; 

	    push @{$resultset_ref->{column_list_ref}} , "Job Status";
            my $idx = $#{$resultset_ref->{column_list_ref}};
	    $resultset_ref->{column_hash_ref}->{"Job Status"} = $idx; 

	    push @{$resultset_ref->{column_list_ref}} , "Job Params";
            my $idx = $#{$resultset_ref->{column_list_ref}};
	    $resultset_ref->{column_hash_ref}->{"Job Params"} = $idx; 

	    push @{$resultset_ref->{column_list_ref}} , "Results";
            my $idx = $#{$resultset_ref->{column_list_ref}};
	    $resultset_ref->{column_hash_ref}->{"Results"} = $idx; 

	    #need to append a value for every column added otherwise the column headers will not show
	    append_precision_data($resultset_ref);
	    append_precision_data($resultset_ref);
	    append_precision_data($resultset_ref);
	    append_precision_data($resultset_ref);
	    append_precision_data($resultset_ref);
        }
	

}

###############################################################################
# append_filtered_result_links
#
# Append on the more columns of data which can then be shown via the displayResultSet method
###############################################################################
 # this is only called from print_sample_comparison, which filters all the jobs and only includes
 # the ones that actually have results, so we can assume here that all have results
sub append_filtered_result_links {
        my %args = @_;

        my $resultset_ref = $args{resultset_ref};

        #data is stored as an array of arrays from the $sth->fetchrow_array
        # each row is a row from the database holding an aref to all the values
        my $aref = $$resultset_ref{data_ref};

        my $jobname_idx = $resultset_ref->{column_hash_ref}->{Job_Name};
        my $sample_idx  = $resultset_ref->{column_hash_ref}->{Sample_ID};

        ########################################################################################
        my $anchor = '';
        my $pad = '&nbsp;&nbsp;&nbsp;';

        foreach my $row_aref (@{$aref} ) {

          #need to make sure the query has the slimseq_sample_id in the first column
          #    since we are going directly into the array of arrays and pulling out values
          my $jobname  = $row_aref->[$jobname_idx];
          my $sample = $row_aref->[$sample_idx];

          $anchor = "<a href=dataDownload.cgi?slimseq_sample_id=$sample&jobname=$jobname>Results</a>";

          push @$row_aref, $anchor;             #append on the new data
        } # end foreach row

        if ( 1 ){
            #need to add the column headers into the resultset_ref since DBInterface display results will reference this
            push @{$resultset_ref->{column_list_ref}} , "Results";

            #need to append a value for every column added otherwise the column headers will not show
            append_precision_data($resultset_ref);
        }


}





###############################################################################
# prepend_checkbox
#
# prepend a checkbox which can then be shown via the displayResultSet method
###############################################################################

sub prepend_checkbox {
	my %args = @_;
	
	my $resultset_ref = $args{resultset_ref};
	my @default_checked = @{$args{default_checked}};	#array ref of column names that should be checked
	my @checkbox_columns = @{$args{checkbox_columns}};	#array ref of columns of checkboxes to make
	my $cbox = $args{checkbox} || {};
	
	#data is stored as an array of arrays from the $sth->fetchrow_array 
	# each row is a row from the database holding an aref to all the values
	my $aref = $$resultset_ref{data_ref};		
	
  	my $id_idx = $resultset_ref->{column_hash_ref}->{Sample_ID};

    	my @new_data_ref;
   	########################################################################################
	foreach my $checkbox_column (@checkbox_columns){
 	   my $pad = '&nbsp;&nbsp;&nbsp;';
	   foreach my $row_aref (@{$aref} ) {		
	      my $checked = ( grep /$checkbox_column/, @default_checked ) ? 'checked' : '';
      
	      #need to make sure the query has the slimseq_sample_id in the first column 
	      #    since we are going directly into the array of arrays and pulling out values
	      my $slimseq_sample_id  = $row_aref->[$id_idx];		

      	      my $link = "<input type='checkbox' name='select_samples' $checked value='VALUE_TAG' >";
	      my $value = $slimseq_sample_id.'__Select_Sample';
	      $link =~ s/VALUE_TAG/$value/;

              my $anchor = "$pad $link";
	      unshift @$row_aref, $anchor;		#prepend on the new data	
	   } # end foreach row
		
           if ( 1 ){
 		#add on column header for each of the file types
	   	#need to add the column headers into the resultset_ref since DBInterface display results will reference this
		unshift @{$resultset_ref->{column_list_ref}} , "$checkbox_column"; 
		
		#need to append a value for every column added otherwise the column headers will not show
		prepend_precision_data($resultset_ref);				   
    	   }
	} # end foreach checkbox_column
}

###############################################################################
# check_for_file_existance
#
# Pull the file base path from the database then do a file exists on the full file path
###############################################################################
sub check_for_file {
	my %args = @_;
	
	my $solexa_sample_id = $args{solexa_sample_id};
	my $slimseq_sample_id = $args{slimseq_sample_id};
        my $file_name = $args{file_name};
	my $file_ext = $args{file_extension};		#Fix me same query is ran to many times, store the data localy

	if ((!$solexa_sample_id || !$file_name || !$slimseq_sample_id) || !$file_ext) { return "ERROR: Must supply 'solexa_sample_id' or 'slimseq_sample_id' or 'file_name' and 'file_ext'\n"; }
        my $where = '';
        if ($solexa_sample_id) {
           $where = "WHERE ss.solexa_sample_id = '".$solexa_sample_id."'";
        } elsif ($slimseq_sample_id) {
           $where = "WHERE ss.slimseq_sample_id = '".$slimseq_sample_id."'";
        }

	my $path;
	if ($file_ext eq 'ELAND') {
	 	my $sql = qq~  SELECT eo.file_path
			FROM $TBST_SOLEXA_SAMPLE ss
			LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls ON
                          (ss.solexa_sample_id = sfcls.solexa_sample_id)
                        LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl ON
                          (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                        LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr ON
                          (sfcl.flow_cell_lane_id = spr.flow_cell_lane_id)
                        LEFT JOIN $TBST_FILE_PATH eo ON
                          (spr.eland_output_file_id = eo.file_path_id)
                        $where
                        AND ss.record_status != 'D'
                        AND sfcls.record_status != 'D'
                        AND sfcl.record_status != 'D'
                        AND spr.record_status != 'D'
                        AND eo.record_status != 'D'
		   ~;
		($path) = $sbeams->selectOneColumn($sql);
	} elsif ($file_ext eq 'RAW') {
		 	my $sql = qq~  SELECT rdp.file_path
			FROM $TBST_SOLEXA_SAMPLE ss
			LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls ON
                          (ss.solexa_sample_id = sfcls.solexa_sample_id)
                        LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl ON
                          (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                        LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr ON
                          (sfcl.flow_cell_lane_id = spr.flow_cell_lane_id)
                        LEFT JOIN $TBST_FILE_PATH rdp ON
                          (spr.raw_data_path_id = rdp.file_path_id)
                        $where
                        AND ss.record_status != 'D'
                        AND sfcls.record_status != 'D'
                        AND sfcl.record_status != 'D'
                        AND spr.record_status != 'D'
                        AND rdp.record_status != 'D'
		   ~;
		($path) = $sbeams->selectOneColumn($sql);
	} elsif ($file_ext eq 'SUMMARY') {
		 	my $sql = qq~  SELECT sf.file_path
			FROM $TBST_SOLEXA_SAMPLE ss
			LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls ON
                          (ss.solexa_sample_id = sfcls.solexa_sample_id)
                        LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl ON
                          (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                        LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr ON
                          (sfcl.flow_cell_lane_id = spr.flow_cell_lane_id)
                        LEFT JOIN $TBST_FILE_PATH sf ON
                          (spr.summary_file_id = sf.file_path_id)
                        $where
                        AND ss.record_status != 'D'
                        AND sfcls.record_status != 'D'
                        AND sfcl.record_status != 'D'
                        AND spr.record_status != 'D'
                        AND sf.record_status != 'D'
		   ~;
		($path) = $sbeams->selectOneColumn($sql);
	} elsif ($file_name) {
          $path = $file_name.'.'.$file_ext;
        } else {
          return("This file extension is not supported");
        }

	$log->debug("FILE PATH '$path'");
	if (-e $path){
    		if ( -r $path ) { 
		  return 1;
		} else {
      		  $log->error( "File: $path exists but is not readable\n" );
		  return 0;
    		}
	}else{
    		$log->error( "File: $path does not exist\n" );
		return 0;
	}
}

###############################################################################
# prepend_precision_data
#
# need to prepend a value for every column added otherwise the column headers will not show
###############################################################################


sub prepend_precision_data {
	my $resultset_ref = shift;
	
	my $aref = $$resultset_ref{precisions_list_ref};	
	
	unshift @$aref, 10;					
	
	$$resultset_ref{precisions_list_ref} = $aref;

			
        my $nref = $$resultset_ref{types_list_ref};
        unshift @$nref, 'int';
        $$resultset_ref{types_list_ref} = $nref;
#	print "AREF '$aref'<br>";
	
#	foreach my $val (@$aref){
#		print "$val<br>";
#	}	
	
}
###############################################################################
# append_precision_data
#
# need to append a value for every column added otherwise the column headers will not show
###############################################################################


sub append_precision_data {
	my $resultset_ref = shift;
	
	
	my $aref = $$resultset_ref{precisions_list_ref};	
	
	push @$aref, '-10';					
	
	$$resultset_ref{precisions_list_ref} = $aref;


        my $nref = $$resultset_ref{types_list_ref};
        push @$nref, '';
        $$resultset_ref{types_list_ref} = $nref;
			
	#print "AREF '$aref'<br>";
	
	#foreach my $val (@$aref){
	#	print "$val<br>";
	#}
	
}

sub get_r_plot_script {
  
  my $script = <<END;
setwd('/solexa/trans/tmp/')
options(echo=FALSE)
CPM_1 <- read.table("FILENAME1", row.names=1)
colnames(CPM_1) <- c("Genome ID","Count","CPM")
topten <- CPM_1[order(CPM_1[,3],decreasing=TRUE)[1:10],]

CPM_2 <- read.table("FILENAME2",row.names=1)
colnames(CPM_2) <- c("Genome ID","Count","CPM")

one <- CPM_1[,3]
names(one) <- rownames(CPM_1)

two <- CPM_2[,3]
names(two) <- rownames(CPM_2)

merged <- merge(one, two,by.x=0,by.y=0,sort=FALSE)
comb <- merged[,2-3]
rownames(comb) <- merged[,1]

corc <- cor(comb[,1], comb[,2])

png(filename = "ZOOM_FILENAME")
ylim <- c(0,1000)
xlim <- c(0,1000)
plot(comb,xlab="Sample SAMPLE1",ylab="Sample SAMPLE2",ylim=ylim,xlim=xlim)
abline(lm(comb[,2] ~ comb[,1]))
t <- paste("Correlation Coefficient: ",corc)
legend("topright",t)

# display full plot
png(filename = "PNG_FILENAME")
yl <- max(comb[,2]) + 1000
ylim <- c(0,yl)
xl <- max(comb[,1])
xlim <- c(0,xl)

plot(comb,xlab="Sample SAMPLE1",ylab="Sample SAMPLE2",ylim=ylim,xlim=xlim)
abline(lm(comb[,2] ~ comb[,1]))
t <- paste("Correlation Coefficient: ",corc)
legend("topright",t)

onehigh <- comb[which(comb[,1] > 2000),]
twohigh <- comb[which(comb[,2] > 2000),]
END

return $script;
}


###############################################################################
# error_log
###############################################################################
sub error_log {
	my $SUB_NAME = 'error_log';
	
	my %args = @_;
	
	die "Must provide key value pair for 'error' \n" unless (exists $args{error});
	
	open ERROR_LOG, ">>AFFY_ZIP_ERROR_LOGS.txt"
		or die "$SUB_NAME CANNOT OPEN ERROR LOG $!\n";
		
	my $date = `date`;
	
	print ERROR_LOG "$date\t$args{error}\n";
	close ERROR_LOG;
	
	die "$date\t$args{error}\n";
}



###############################################################################
# getProcessedDate
#
# Given a file name, the associated timestamp is returned
###############################################################################
sub getProcessedDate {
    my %args= @_;
    my $SUB_NAME="getProcessedDate";

    my $file = $args{'file'};
## Get the last modification date from this file
    my @stats = stat($file);
    my $mtime = $stats[9];
    my $source_file_date;
    if ($mtime) {
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime($mtime);
	$source_file_date = sprintf("%d-%d-%d %d:%d:%d",
				    1900+$year,$mon+1,$mday,$hour,$min,$sec);
	if ($VERBOSE > 0){print "INFO: source_file_date is '$source_file_date'\n";}
    }else {
	$source_file_date = "CURRENT_TIMESTAMP";
	print "WARNING: Unable to determine the source_file_date for ".
	    "'$file'.\n";
    }
    return $source_file_date;
}

###############################################################################
# print_output_mode_data
#
# If the user selected to see the data in a differnt mode come here and print it out
###############################################################################
sub print_output_mode_data {
	my %args= @_;
	my $SUB_NAME="print_output_mode_data";

	my $parameters_ref = $args{'parameters_ref'} || die "ERROR[$SUB_NAME] No parameters passed\n";
	my %parameters = %{$parameters_ref};
	my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

	
	my %resultset = ();
	my $resultset_ref = \%resultset;
	
	my %rs_params = $sbeams->parseResultSetParams(q=>$q);
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/main.cgi";
	my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

	my $current_contact_id = $sbeams->getCurrent_contact_id();
	my $project_id = $sbeams->getCurrent_project_id();
        if (!$project_id) {
          error("You must set a project using the Project selector to continue");
        }
	

	my %max_widths = ();
	my %url_cols = ();
	my %hidden_cols  =(
                            'Select_Sample' => 1,
                            'Select Job' => 1,
                            'Job Controls' =>1,
                            'Job Status' =>1,
                            'Job Params' => 1,


                          );
	my $limit_clause = '';
	my @column_titles = ();
	

	if ($apply_action eq "VIEWRESULTSET") {
   		$sbeams->readResultSet(
     	 	resultset_file=>$rs_params{set_name},
     	 	resultset_ref=>$resultset_ref,
     	 	query_parameters_ref=>\%parameters,
    	  	resultset_params_ref=>\%rs_params,
   	 	);
	}else{
	  	die "SORRY BUT I CAN'T FIND A RESULTS SET TO READ<br>\n";
	}

 	
	 #### Build ROWCOUNT constraint
	 $parameters{row_limit} = 5000
   	 unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=1000000);
  	 $limit_clause = $sbeams->buildLimitClause(row_limit=>$parameters{row_limit});


		#### Set the column_titles to just the column_names
		@column_titles = @{$resultset_ref->{column_list_ref}};
	
		#### Display the resultset
		$sbeams->displayResultSet(	resultset_ref=>$resultset_ref,
						query_parameters_ref=>\%parameters,
						rs_params_ref=>\%rs_params,
						url_cols_ref=>\%url_cols,
						hidden_cols_ref=>\%hidden_cols,
						max_widths=>\%max_widths,
						column_titles_ref=>\@column_titles,
						base_url=>$base_url,
					);
}



#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

        print $q->header;
        site_header("SolexaTransPipeline: Samples");

        print $q->h1("SolexaTransPipeline: Samples"),
              $q->h2("Error:"),
              $q->p($error);
                foreach my $key ($q->param){

                print "$key => " . $q->param($key) . "<br>";
        }
        site_footer();

        exit(1);
}

