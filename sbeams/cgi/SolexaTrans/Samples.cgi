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

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $sbeams_solexa_groups $q $cgi
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

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SolexaTrans;

$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

#use CGI;
#$q = new CGI;
$cgi = $q;


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
$PROGRAM_FILE_NAME = 'Samples.cgi';
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
	my $pid = '';
# 	if ($parameters{Get_Data} eq 'GET_SOLEXA_FILES') {
  	
#		print_run_pipeline_tab(ref_parameters => \%parameters);	#skip printing the headers since we will be piping out binary data and will use different Content headers
   	
#   	}else {
#    		if  ($parameters{output_mode} =~ /xml|tsv|excel|csv/){		#print out results sets in different formats
#      			print_output_mode_data(parameters_ref=>\%parameters);
       				
#		}else{
    
       			$sbeamsMOD->printPageHeader();
       			print_javascript();
			$sbeamsMOD->updateSampleCheckBoxButtons_javascript();
       			handle_request(ref_parameters=>\%parameters);
       			$sbeamsMOD->printPageFooter();
#		}
#  	}
   

} # end main


###############################################################################
# print_javascript 
##############################################################################
sub print_javascript {

    my $uri = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/";

print qq~
<SCRIPT LANGUAGE="Javascript">
<!--
<!-- $uri -->
function actionLogFile(action){
    var id = document.outputFiles.logChooser.options[document.outputFiles.logChooser.selectedIndex].value;
    if (action == "get") {
	getFile(id);
    } else {
	viewFile(id);
    }
}		
    
function actionRepFile(){
  var id = document.outputFiles.repChooser.options[document.outputFiles.repChooser.selectedIndex].value;
  getFile(id);
}
function actionMergeFile(){
  var id = document.outputFiles.mergeChooser.options[document.outputFiles.mergeChooser.selectedIndex].value;
  getFile(id);
}
function actionSigFile(){
  var id = document.outputFiles.sigChooser.options[document.outputFiles.sigChooser.selectedIndex].value;
  getFile(id);
}
function actionCloneFile(){
  var id = document.outputFiles.cloneChooser.options[document.outputFiles.cloneChooser.selectedIndex].value;
  getFile(id);
}


function getFile(id){
    var site = "$uri/ViewFile.cgi?action=download&FILE_NAME="+id;
    window.location = site;
}
		
function viewFile(id){
    var site = "$uri/ViewFile.cgi?action=view&FILE_NAME="+id;
    var newWindow = window.open(site);
}

function startMev(project_id){
    document.tavForm.project_id.value=project_id;
    
    var tavList = document.tavForm.tavChooser;
    var tavArray;
    var isFirst = 1;
    for (var i=0;i<tavList.length;i++){
	if (tavList.options[i].selected) {
	    if (isFirst == 1){
		isFirst = 0;
		tavArray = tavList.options[i].value;
	    }else {
		tavArray += "," + tavList.options[i].value;
	    }
	}
    }
    
    document.tavForm.selectedFiles.value = tavArray;
    document.tavForm.submit();
    
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
  print_run_pipeline_tab(ref_parameters=>$ref_parameters); 
  return;

}# end handle_request

###############################################################################
# print_project_info
###############################################################################
sub print_project_info {
  my %args = @_;
  my $SUB_NAME = "print_project_info";
  
	my $parameters_ref = $args{'parameters_ref'} || die "ERROR[$SUB_NAME] No parameters passed\n";
	my %parameters = %{$parameters_ref};
 

  ## Define standard variables
  my ($sql, @rows);
  my $current_contact_id = $sbeams->getCurrent_contact_id();
  my $project_id = $sbeams->getCurrent_project_id();
  my ($project_name, $project_tag, $project_status, $project_desc);
  my ($pi_first_name, $pi_last_name, $pi_contact_id, $username);

  #### Get information about the current project from the database
  $sql = qq~
	SELECT P.name,P.project_tag,P.project_status,P.description,C.first_name,C.last_name,C.contact_id,UL.username
	  FROM $TB_PROJECT P
	  JOIN $TB_CONTACT C ON ( P.PI_contact_id = C.contact_id )
	  JOIN $TB_USER_LOGIN UL ON ( UL.contact_id = C.contact_id)
	WHERE P.project_id = '$project_id'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  if (@rows) {
    ($project_name,$project_tag,$project_status,$project_desc,$pi_first_name,$pi_last_name,$pi_contact_id,$username) = @{$rows[0]};
  }

  #### Print out some information about this project
  print qq~

<H1>Summary of $project_name (ID \#$project_id):</H1>
<B>
<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">[Edit Project Description]</A>
</B><BR>

<TABLE WIDTH="100%" BORDER=0>
<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
    <TD COLSPAN="2" WIDTH="100%"><B>PI: </B>$pi_first_name $pi_last_name</TD></TR>
<TR><TD></TD><TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag</TD></TR>
<TR><TD></TD><TD COLSPAN="2"><B>Description:</B>$project_desc</TD></TR>
  ~;


#######################################################################################
#### Check for any Conditions that match this project ID
 
 my $n_condition_count = '';
 
 if ($project_id > 0) {
 	$sql = qq~
		SELECT count(condition_id)
		FROM $TBST_COMPARISON_CONDITION  
		WHERE project_id = $project_id
		AND record_status != 'D'
		~;
	($n_condition_count) = $sbeams->selectOneColumn($sql);
}

print qq~
<TR><TD></TD><TD COLSPAN="2"><B>Number Conditions:  $n_condition_count</B></TD></TR>
<TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD></TR>
~;
########################################################################################
#### Count the number of solexa runs for this project
my $n_solexa_runs = 0;

if ($project_id > 0) {
	$sql = qq~ 	SELECT count(sr.solexa_run_id)
		   	FROM $TBST_SOLEXA_RUN sr
		   	JOIN $TBST_SOLEXA_SAMPLE ss ON (sr.solexa_sample_id = ss.solexa_sample_id)
		   	WHERE ss.project_id = $project_id 
			AND sr.record_status != 'D'
			AND ss.record_status != 'D'
			
		~;
	($n_solexa_runs) = $sbeams->selectOneColumn($sql);	
}  

print qq~
<TR><TD></TD><TD COLSPAN="2"><B>Number Solexa runs:  $n_solexa_runs</B></TD></TR>
<TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD></TR>
~;
########################################################################################
#print out the final links and html to complete the inital summary table
print qq~

<TR><TD></TD><TD COLSPAN="2"><B>Access Privileges:</B><A HREF="$CGI_BASE_DIR/ManageProjectPrivileges">[View/Edit]</A></TD></TR>    
<TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD></TR>
</TABLE>
$LINESEPARATOR 
<br/>

~;	
	
 return ($n_condition_count, $n_solexa_runs);
}

###############################################################################
# print_summary_tab
###############################################################################
sub print_summary_tab {
  my %args = @_;
  my $SUB_NAME = "print_summary_tab";
  
	my $parameters_ref = $args{'parameters_ref'} || die "ERROR[$SUB_NAME] No parameters passed\n";
	my %parameters = %{$parameters_ref};
  my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

	## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
	if ($parameters{set_current_project_id}) {$apply_action = 'QUERY';}

  ## Define standard variables
  my ($sql, @rows);
 # my $current_contact_id = $sbeams->getCurrent_contact_id();
  #my (%array_requests, %array_scans, %quantitation_files);
  my $project_id = $sbeams->getCurrent_project_id();
  my ($project_name, $project_tag, $project_status, $project_desc);
 # my ($pi_first_name, $pi_last_name, $pi_contact_id, $username);

#print out some project info and return the number of hits for the following data types
 my ($n_condition_count, $n_solexa_runs) = print_project_info(parameters_ref =>$parameters_ref);
########################################################################################
### Set some of the usful vars
my %resultset = ();
my $resultset_ref = \%resultset;
my %max_widths;
my %rs_params = $sbeams->parseResultSetParams(q=>$q);
my $base_url = "$CGI_BASE_DIR/SolexaTrans/Samples.cgi";
my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

my %url_cols = ();
my %hidden_cols  =();
my $limit_clause = '';
my @column_titles = ();


#### If the apply action was to recall a previous resultset, do it
  if ($apply_action eq "VIEWRESULTSET"  && $apply_action ne 'QUERY') {
   	
	$sbeams->readResultSet(
     	 resultset_file=>$rs_params{set_name},
     	 resultset_ref=>$resultset_ref,
     	 query_parameters_ref=>\%parameters,
    	  resultset_params_ref=>\%rs_params,
   	 );
	 
  }

########################################################################################
#### Check to see what data should be displayed on the summary section of the page.  
####If there is more then one source the script will default to the condition summary first


my $default_data_type = "CONDITION";

my %count_types = ( CONDITION 	=> { 	COUNT => $n_condition_count,
		   			POSITION => 0,
				   },
		   
		   SOLEXA_RUN		=> {	COUNT => $n_solexa_runs,
		   			POSITION => 1,
		   		   }	
		   );


my @tabs_names = make_tab_names(%count_types);


my ($display_type, $selected_tab_numb) = pick_data_to_show (default_data_type   => $default_data_type, 
							    tab_types_hash 	=> \%count_types,
							    param_hash		=> \%parameters,
							   );
							
							
display_sub_tabs(	display_type 	=> $display_type,
			tab_titles_ref	=> \@tabs_names,
			page_link	=> "Samples.cgi",
			selected_tab	=> $selected_tab_numb
	        );
		
		


#########################################################################################	
#### Print the SUMMARY DATA OUT



###############################################################################
###Print data for the expression condititons
	
	if($display_type eq 'CONDITION') {
		
		
		$sql = qq~
		   		SELECT condition_id, condition_name, comment
				FROM $TBST_COMPARISON_CONDITION 
				WHERE project_id = $project_id
				AND record_status != 'D'
			~;
		
		 %url_cols = (
		 	 	'condition_id' => "$CGI_BASE_DIR/SolexaTrans/GetExpression?condition_id=\%V",
			     );

  		 %hidden_cols = ('solexa_run_id' => 1,
		     		);
	
	}elsif($display_type eq 'SOLEXA_RUN') {
		
		$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
		$sbeams_solexa_groups->setSBEAMS($sbeams);				#set the sbeams object into the solexa_groups_object
		
		 $sql = $sbeams_solexa_groups->get_solexa_runs_sql(project_id    => $project_id, );
		
		
		
		 %url_cols = (
				'Sample_Tag'	=> "${manage_table_url}solexa_sample&solexa_sample_id=\%3V",
			     );

  		 
		 %hidden_cols = ('Sample_ID' => 1,
		     		 'Run_ID' => 1,
				);
	
	}else{
		return undef;
	}

#########################################################################
####  Actually print the data 	

 	 
 	 #### Build ROWCOUNT constraint
	  $parameters{row_limit} = 5000
   	 unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=1000000);
  	   $limit_clause = $sbeams->buildLimitClause(row_limit=>$parameters{row_limit});


	#### If the action contained QUERY, then fetch the results from
	#### the database
	if ($apply_action =~ /QUERY/i) {
		
    		
	#### Fetch the results from the database server
    		$sbeams->fetchResultSet(sql_query=>$sql,
					resultset_ref=>$resultset_ref,
					);

	#### Store the resultset and parameters to disk resultset cache
		$rs_params{set_name} = "SETME";
		$sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
					resultset_ref=>$resultset_ref,
					query_parameters_ref=>\%parameters,
					resultset_params_ref=>\%rs_params,
					query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
					);
 	}
	
	
	#### Set the column_titles to just the column_names
	@column_titles = @{$resultset_ref->{column_list_ref}};
	
	
	
	
	#### Display the resultset
	$sbeams->displayResultSet(resultset_ref=>$resultset_ref,
				  query_parameters_ref=>\%parameters,
				  rs_params_ref=>\%rs_params,
				  url_cols_ref=>\%url_cols,
				  hidden_cols_ref=>\%hidden_cols,
				  max_widths=>\%max_widths,
				  column_titles_ref=>\@column_titles,
				  base_url=>$base_url
				 );

	#### Display the resultset controls
	$sbeams->displayResultSetControls(resultset_ref=>$resultset_ref,
					  query_parameters_ref=>\%parameters,
					  rs_params_ref=>\%rs_params,
					  base_url=>$base_url,
					  );
	

	

}

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
# print_run_pipeline_tab
###############################################################################
sub print_run_pipeline_tab {
  	my %args = @_;
  
  
  	my $resultset_ref = '';
	my @columns = ();
	my $sql = '';
	
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %max_widths;
	my %rs_params = $sbeams->parseResultSetParams(q=>$q);
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/Samples.cgi";
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
	
	my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

	## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
	if ($parameters{set_current_project_id}) {
		$apply_action = 'QUERY';
	}
  
  ###############################################################################
  ##First check to see if the user already has selected some data to run
	
	#come here if the user has chosen some files to run the STP on
	if (exists $parameters{Get_Data}){			
		#value of the button submitting previous form
		if ( $parameters{Get_Data} eq 'RUN_PIPELINE') {
	           if ($parameters{select_samples}) {	
		##########################################################################
		### Print out some nice table
			#example '37__CEL,38__CEL,45__CEL,46__CEL,46__XML'
			my $samples_id_string =  $parameters{select_samples}; 
			my @sample_ids = split(/,/, $samples_id_string);
			my %unique_sample_ids = map {split(/__/, $_) } @sample_ids;
			my $samples = join(",", sort keys %unique_sample_ids);

		        $sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
		        $sbeams_solexa_groups->setSBEAMS($sbeams);		#set the sbeams object into the solexa_groups_object

			$sql = $sbeams_solexa_groups->get_solexa_pipeline_run_info_sql(slimseq_sample_ids => $samples, 
                                                                                       project_id => $project_id
                                                                                      );

                        # hide the really long file paths from displaying
			%hidden_cols = ( 
                                  'ELAND_Output_File' => 1,
                                  'Raw_Data_Path' => 1,
					            );

                        # need some code to start a qsub job

		  } else {
      		    $log->error( "User submitted no samples\n" );
                    $sbeams->handle_error(message => 'No samples selected, please press back and select samples.', 
                                          error_type => 'SolexaTrans_error');
                  }
	
		}
	
  ###############################################################################
  ##Start looking for data that can be run with the SolexaTrans pipeline
	
	#if user has not selected samples to run come here
	} else {										
	
		###Get some summary data for all the samples that can be run
		#### Count the number of solexa samples for this project
		my $n_solexa_samples = 0;
		
		if ($project_id > 0) {
			my $sql = qq~ 
		      SELECT count(ss.solexa_sample_id)
		  	FROM $TBST_SOLEXA_SAMPLE ss 
			LEFT JOIN $TBST_SOLEXA_SAMPLE_PREP_KIT sspk
			  ON (ss.solexa_sample_prep_kit_id = sspk.solexa_sample_prep_kit_id)
		  	WHERE ss.project_id = $project_id 
			AND sspk.restriction_enzyme is not null
			AND sspk.record_status <> 'D'
      			AND ss.record_status <> 'D'
			~;
			($n_solexa_samples) = $sbeams->selectOneColumn($sql);	
 		}
    
	 	my $solexa_info =<<"    END";
		<BR>
		<TABLE WIDTH="50%" BORDER=0>
		  <TR>
		   <TD>
        <B>
        This page shows the<FONT COLOR=RED> $n_solexa_samples </FONT> Solexa
        samples in this project that can be entered into the SolexaTrans Pipeline.
	Click the checkboxes next to each sample to select that sample for the pipeline.
	Then click 'RUN_PIPELINE' to go to the next step.
        </B> 
       </TD></TR>
       <TR><TD></TD></TR>
		</TABLE>
    END
	

  #################################################################################
  ##Set up the hash to control what sub tabs we might see
	
		my $default_data_type = 'SOLEXA_SAMPLE';

		my %count_types = ( SOLEXA_SAMPLE	=> {	COUNT => $n_solexa_samples,
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
		                  	page_link	    => 'Samples.cgi',
		                  	selected_tab	  => $selected_tab_numb,
	                     		parent_tab  	  => $parameters{'tab'},
	                   ) if ( $n_solexa_samples );
	
  #####################################################################################
  ### Show the sample choices
	
		
		if ($display_type eq 'SOLEXA_SAMPLE'){
		  	print $solexa_info; # header info generated earlier

			$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

			@default_checkboxes = qw(Select_Sample);  #default file type to turn on the checkbox
			@checkbox_columns = qw(Select_Sample);
		        # set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups->setSBEAMS($sbeams);
		
		        # return a sql statement to display all the arrays for a particular project
			$sql = $sbeams_solexa_groups->get_slimseq_sample_pipeline_sql(project_id    => $project_id, );
						     			
		 	%url_cols = ( 'Sample_Tag'	=> "${manage_table_url}solexa_sample&slimseq_sample_id=\%1V",
				      'Select_Sample _OPTIONS' => { 'embed_html' => 1 }
				     );

		}else{
			print "<h2>Sorry, no samples qualify for the SolexaTrans pipeline in this project</h2>" ;
			return;
		} 
	} # end if parameters{Get_Data} 
	
  ###################################################################
  ## Print the data 
		
	unless (exists $parameters{Get_Data}) {
    		# start the form to run STP on solexa samples
		print $q->start_form(-name =>'select_samplesForm');
				     			
		#make sure to include the name of the tab we are on
  		print $q->hidden(-name=>'tab',									
				 -value=>'parameters{tab}',
				 );
	
		print "<br>";
        }

  ###################################################################
  ## get field->checkbox HTML for selecting samples
  	my $cbox = $sbeamsMOD->get_sample_select_cbox( box_names => \@checkbox_columns,
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
  
 
    ####################################################################
    ## Need to prepend data onto the data returned from fetchResultsSet in order 
    # to use the writeResultsSet method to display a nice html table
 
   	  if ($display_type eq 'SOLEXA_SAMPLE') {
            if (!exists $parameters{Get_Data}) {
		
		prepend_checkbox( resultset_ref => $resultset_ref,
				  checkbox_columns => \@checkbox_columns,
				  default_checked => \@default_checkboxes,
				  checkbox => $cbox,
				);
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

   	} # End read or fetch resultset block
	
        # now that we have the results, go through them and start the pipeline jobs
        if ($parameters{Get_Data}) {
          my %solexaJobs;

          #data is stored as an array of arrays from the $sth->fetchrow_array 
          # each row is a row from the database holding an aref to all the values
          my $aref = $$resultset_ref{data_ref};		
          
  	  my $id_idx = $resultset_ref->{column_hash_ref}->{Sample_ID};
          my $eland_idx = $resultset_ref->{column_hash_ref}->{ELAND_Output_File};
          my $raw_data_path_idx = $resultset_ref->{column_hash_ref}->{Raw_Data_Path};
          my $tag_length_idx = $resultset_ref->{column_hash_ref}->{Tag_Length};
          my $genome_idx = $resultset_ref->{column_hash_ref}->{Genome};
          my $organism_idx = $resultset_ref->{column_hash_ref}->{Organism};
          my $motif_idx = $resultset_ref->{column_hash_ref}->{Motif};
          my $lane_idx = $resultset_ref->{column_hash_ref}->{Lane};
          ########################################################################################
          # this foreach loop goes through each row that was retrieved from teh database
          # and organizes the files into a file structure that has one entry for each
          # raw directory path - this is what STP expects to receive. 
          foreach my $row_aref ( @{$aref} ) {		
	    my $slimseq_sample_id  = $row_aref->[$id_idx];
            my $eland_file = $row_aref->[$eland_idx];
            my $raw_data_path = $row_aref->[$raw_data_path_idx];
            my $tag_length = $row_aref->[$tag_length_idx];
            my $genome = $row_aref->[$genome_idx];
            my $organism = $row_aref->[$organism_idx];
            my $motif = $row_aref->[$motif_idx];
            my $lane = $row_aref->[$lane_idx];

#           Since we're taking the existance of the files on the word of the database, it'd be
#            really good to check to see if the file does exist.
#           The simple case doesn't work because the web server user doesn't have access to /solexa/*
#           Ideally this would be some sort of script execution that would run as a user that
#            would have access to all /solexa files but only be able to check for file existance
#            die "ELAND file $eland_file does not exist or is not available" unless -e $eland_file;

            my $jobname = 'stp-ssid'.$slimseq_sample_id.'-'.rand_token();

#            my $pipeline_output_directory = $raw_data_path.'/SolexaTransPipeline';
             my $pipeline_output_directory = $sbeamsMOD->solexa_delivery_path();
             my @raw_dirs = split(/\//, $raw_data_path);
             my $flow_cell_dir = pop(@raw_dirs); # remove flow cell
             my $new_dir = join("/", @raw_dirs);
             $new_dir .= '/SolexaTrans/'.$flow_cell_dir.'/';
             print "Writing to directory $new_dir<br>\n";
            my @job_summary_info = (
                                    'Sample IDs',$slimseq_sample_id,
                                    'ELAND File',$eland_file,
                                    'Tag Length',$tag_length,
                                    'Genome',$genome,
                                    'Organism',$organism,
                                    'Motif',$motif,
                                    'Lane',$lane,
                                    'Output Directory',$pipeline_output_directory
                                    );

            my $jobsummary = jobsummary(@job_summary_info); # method in SetupPipeline.pm

            my $partial_url = "$CGI_BASE_DIR/SolexaTrans/View_Solexa_files.cgi?action=view_file&job=$jobname&analysis_file=$jobname";

            # links to view the tag counts etc
            my $out_links = <<OUTL;
<h3>Output Files</h3>
<a href='$partial_url&file_ext=html'>$jobname.html</a><br>
<a href='$partial_url&file_ext=txt'>$jobname.txt</a><br>
OUTL

            my $output = <<END;
<h3>Show Analysis Data:</h3>
<a href="$CGI_BASE_DIR/SolexaTrans/View_Solexa_files.cgi?_tab=3&token=$jobname&show_analysis_files=1">Show Files</a>
$out_links
END

            print "Starting a new SolexaTransPipeline job with Slimseq sample id $slimseq_sample_id<br>\n";
            my $perl_script = generate_perl(
                                              "Sample_ID" => $slimseq_sample_id,
                                              "ELAND_Output_File" => $eland_file,
                                              "Raw_Data_Path" => $raw_data_path,
                                              "Tag_Length" => $tag_length,
                                              "Genome" => $genome,
                                              "Organism" => $organism,
                                              "Motif" => $motif,
                                              "Jobname" => $jobname,
                                              "Lane" => $lane,
                                              "Output_Dir" => $pipeline_output_directory,
                                              "Jobsummary" => $jobsummary,
                              ); 

            my $error = create_files( 
                                        dir => $pipeline_output_directory,
                                        jobname => $jobname,
                                        title => $sbeams->getCurrent_project_name,
                                        jobsummary => $jobsummary,
                                        output => $output,
                                        refresh => 20,
                                        script => $perl_script,
                                        email => $current_email,
                                    );

             error($error) if $error;

            my $job = new Batch;
            $job->cputime('12:00:00'); # default at 12 hours for now
            $job->type($BATCH_SYSTEM);
            $job->script("$pipeline_output_directory/$jobname/$jobname.sh");
            $job->name($jobname);
            $job->out("$pipeline_output_directory/$jobname/$jobname.out");
#            $job->submit || error("Couldn't start a job for $jobname");
            open (ID, ">$pipeline_output_directory/$jobname/id") || 
              error("Couldn't write out an id for $jobname in $pipeline_output_directory/$jobname/id");
            print ID $job->id;
            close(ID);


print "<br>\n";
print "<br>\n";

            $solexaJobs{$slimseq_sample_id} = $jobname;


          } # end foreach file_path     

          append_job_link( resultset_ref => $resultset_ref,
			    jobs => \%solexaJobs,
                          );

        } # end if parameters{Get_Data}


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
	
	unless ($parameters{Get_Data}) {
		print "<h3>To input parameters for the Pipeline run, click the button below<br>";
		
		print   $q->br,
			$q->submit(-name=>'Get_Data',
				#will need to change value if other data sets need to be run
                	       	 -value=>'RUN_PIPELINE');			
	
		
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

sub postProcessResultset {
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
# append_job_link
#
# Append on the more columns of data which can then be shown via the displayResultSet method
###############################################################################

sub append_job_link {
	my %args = @_;
	
	my $resultset_ref = $args{resultset_ref};
	my %jobs = %{$args{jobs}};
	
	#data is stored as an array of arrays from the $sth->fetchrow_array 
	# each row is a row from the database holding an aref to all the values
	my $aref = $$resultset_ref{data_ref};		
	
  	my $id_idx = $resultset_ref->{column_hash_ref}->{Sample_ID};
	
	
    	my @new_data_ref;
   	########################################################################################
 	my $anchor = '';
 	my $pad = '&nbsp;&nbsp;&nbsp;';
	foreach my $row_aref (@{$aref} ) {

	  #need to make sure the query has the slimseq_sample_id in the first column 
	  #    since we are going directly into the array of arrays and pulling out values
	  my $slimseq_sample_id  = $row_aref->[$id_idx];		
          my $job = $jobs{$slimseq_sample_id};
	  $anchor = "<a href=View_Solexa_files.cgi?action=view_file&analysis_folder=$job&analysis_file=index&file_ext=html>View Job</a>";
			
          push @$row_aref, $anchor;		#append on the new data	
	} # end foreach row
		
        if ( 1 ){
	    #need to add the column headers into the resultset_ref since DBInterface display results will reference this
	    push @{$resultset_ref->{column_list_ref}} , "View Job"; 
		
	    #need to append a value for every column added otherwise the column headers will not show
	    append_precision_data($resultset_ref);				   
        }
	
	
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
	
	push @$aref, '-10';					
	
	$$resultset_ref{precisions_list_ref} = $aref;
			
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
			
	#print "AREF '$aref'<br>";
	
	#foreach my $val (@$aref){
	#	print "$val<br>";
	#}
	
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
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/Samples.cgi";
	my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

	my $current_contact_id = $sbeams->getCurrent_contact_id();
	my $project_id = $sbeams->getCurrent_project_id();
	

	my %max_widths = ();
	my %url_cols = ();
	my %hidden_cols  =();
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
  	   my $limit_clause = $sbeams->buildLimitClause(row_limit=>$parameters{row_limit});


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


###############################################################################
# print_permissions_tab
###############################################################################
sub print_permissions_tab {
  my %args = @_;
  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  
  $sbeams->print_permissions_table(ref_parameters=>$ref_parameters, no_permissions=>1);
}

sub generate_perl {
    my (%argHash)=@_;
    my @required_opts=qw(Sample_ID ELAND_Output_File Raw_Data_Path Tag_Length Genome Organism Motif Lane Output_Dir Jobname Jobsummary);
    my @missing=grep {!defined $argHash{$_}} @required_opts;
    die "missing opts: ",join(', ',@missing) if @missing;

    my ($sample_id, $eland_file, $raw_data_path, $tag_length, $genome, $organism, $motif, $lane, $output_dir, $jobname, $jobsummary)=
        @argHash{qw(Sample_ID ELAND_Output_File Raw_Data_Path Tag_Length Genome Organism Motif Lane Output_Dir Jobname Jobsummary)};

    my $project_name = $sbeams->getCurrent_project_name;
    my $project_id = $sbeams->getCurrent_project_id;

    # base_dir is where the script is called from
    # export_dir is where the input comes from (s_\d_export.txt)
    # project_dir is where the files are stored while being processed
    # output_dir is where the results go

    my $pscript=<<"PEND";
#!/tools64/bin/perl

use strict;
use warnings;
use lib "$PHYSICAL_BASE_DIR/lib/perl";
use SBEAMS::SolexaTrans::Solexa_file_groups;
use SBEAMS::SolexaTrans::SolexaTransPipeline;
use SBEAMS::Connection;
use SBEAMS::Connection::Tablaes;

my \$verbose = 1;   # these should be 0 for production
my \$testonly = 1;

my \$sbeams = new SBEAMS::Connection;
my \$utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
\$utilities->setSBEAMS(\$sbeams);


PEND

  $pscript.=<<"PEND2";
            my \$output_dir_id = \$utilities->check_sbeams_file_path(file_path => '$output_dir');
            if (!\$output_dir_id) {
               my \$output_server_id = \$utilities->check_sbeams_server("server_name" => "RUNE");
               if (\$output_server_id =~ /ERROR/) { die \$output_server_id; }

               \$output_dir_id = \$utilities->insert_file_path(file_path => '$output_dir',
                                                               file_path_name => 'Output Directory for job $jobname',
                                                               file_path_desc => '',
                                                               server_id => \$output_server_id,
                                                               );
            }

            # insert the job information before calling STP to process
            my \$rowdata_ref = {
                                jobname => $jobname,
                                solexa_sample_id => $sample_id,
                                output_directory_id => \$output_dir_id,
                                analysis_description => $jobsummary,
                                project_id => $project_id,
                                status => 'PROCESSING',
                                status_time => CURRENT_TIMESTAMP,
                              };

            my \$analysis_id = \$sbeams->updateOrInsertRow(
                                                          table_name=>\$TBST_SOLEXA_ANALYSIS,
                                                          rowdata_ref => \$rowdata_ref,
                                                          PK=>'solexa_analysis_id',
                                                          return_PK=>1,
                                                          insert=>1,
                                                          verbose=>\$verbose,
                                                          testonly=>\$testonly,
                                                          add_audit_parameters=>1,
                                                        );
PEND2

  $pscript.=<<"PEND3";
            # sample id is slimseq sample id
            my \$pipeline = SBEAMS::SolexaTrans::SolexaTransPipeline->new(
                                project_name=>'$project_name',
                                output_dir=> '$output_dir/$jobname', # output_dir must include flow cell information
                                ref_genome=> '$organism|$genome',
                                ref_org=> '$organism',
                                export_file=>'$eland_file',
                                tag_length=> '$tag_length',
                                lane => '$lane',
                                ss_sample_id => '$sample_id',  # slimseq sample id
                                motif => '$motif',
                                db_host=>'$SOLEXA_MYSQL_HOST', db_name=>'$SOLEXA_MYSQL_DB',
                                db_user=>'$SOLEXA_MYSQL_USER', db_pass=>'$SOLEXA_MYSQL_PASS',
                                babel_db_host=>'$SOLEXA_BABEL_HOST',
                                babel_db_name=>'$SOLEXA_BABEL_DB',
                                babel_db_user=>'$SOLEXA_BABEL_USER',
                                babel_db_pass=>'$SOLEXA_BABEL_PASS',
                          );
PEND3



   $pscript.=<<"PEND4";
            \$pipeline->run();

            my \$statsref = \$pipeline->read_stats;
#            tags_${sample_id}_total
#            tags_${sample_id}_unique
#            ambg_${sample_id}_total
#            ambg_${sample_id}_unique
#            unkn_${sample_id}_total
#            unkn_${sample_id}_unique
#            total_tags
#            total_unique

            \$rowdata_ref{"total_tags"}         = \$statsref->{total_tags};
            \$rowdata_ref{"total_unique_tags"}  = \$statsref->{total_unique};
            \$rowdata_ref{"match_tags"}         = \$statsref->{tags_${sample_id}_total};
            \$rowdata_ref{"match_unique_tags"}  = \$statsref->{tags_${sample_id}_unique};
            \$rowdata_ref{"ambg_tags"}          = \$statsref->{ambg_${sample_id}_total};
            \$rowdata_ref{"ambg_unique_tags"}   = \$statsref->{ambg_${sample_id}_unique};
            \$rowdata_ref{"unkn_tags"}          = \$statsref->{unkn_${sample_id}_total};
            \$rowdata_ref{"unkn_unique_tags"}   = \$statsref->{unkn_${sample_id}_unique};
            \$rowdata_ref{"solexa_analysis_id"} = \$analysis_id;
            \$rowdata_ref{"status"}             = 'COMPLETED';

            \$sbeams->updateOrInsertRow(
                                         table_name=>\$TBST_SOLEXA_ANALYSIS,
                                         rowdata_ref => $rowdata_ref,
                                         PK=>'project_id',
                                         return_PK=>1,
                                         insert=>1,
                                         verbose=>$self->verbose,
                                         testonly=>$self->testonly,
                                         add_audit_parameters=>1,
                                        );

PEND4

return $pscript;
}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

        print $cgi->header;
        site_header("SolexaTransPipeline: Samples");

        print $cgi->h1("SolexaTransPipeline: Samples"),
              $cgi->h2("Error:"),
              $cgi->p($error);
                foreach my $key ($cgi->param){

                print "$key => " . $cgi->param($key) . "<br>";
        }
        site_footer();

        exit(1);
}

