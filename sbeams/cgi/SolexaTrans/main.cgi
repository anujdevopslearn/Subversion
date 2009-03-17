#!/usr/local/bin/perl 


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use Data::Dumper;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Basename;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $sbeams_solexa_groups $q $current_contact_id $current_username
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


use SBEAMS::SolexaTrans::Solexa_file_groups;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SolexaTrans;

$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

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

  # Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    # connect_read_only=>1,
    # allow_anonymous_access=>1,
    # permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));


  # Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  # Process generic "state" parameters before we start
  $sbeams->processStandardParameters( parameters_ref=>\%parameters);

  if  ( $parameters{output_mode} =~ /xml|tsv|excel|csv/){
    # print out results sets in different formats
    print_output_mode_data(parameters_ref=>\%parameters);
  }else{
    # Gonna return a web page.
    $sbeamsMOD->printPageHeader();
    print_javascript();
    $sbeamsMOD->updateCheckBoxButtons_javascript();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }
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
function viewRequest(status){
    var site;
    if (status == 'old') {
	var id = document.requests.chooser.options[document.requests.chooser.selectedIndex].value;
	site = "${uri}SubmitArrayRequest.cgi?TABLE_NAME=MA_solexa_request&solexa_request_id="+id;
    }
    else {
	site = "${uri}SubmitArrayRequest.cgi?TABLE_NAME=MA_solexa_request&ShowEntryForm=1";
    }
    var newWindow = window.open(site);
}

function viewImage(status){
    var site;
    if (status == 'old') {
	alert ("scan images not available to be viewed.  Will be developed later");
    //var id = document.images.chooser.options[document.images.chooser.selectedIndex].value
    //var site = "${uri}ManageTable.cgi?TABLE_NAME=ST_solexa_scan&solexa_scan_id="+id
    }
    else {
	alert ("scan images not on a network share.");
        //var site = "${uri}ManageTable.cgi?TABLE_NAME=$TBST_SOLEXA_SAMPLE&ShowEntryForm=1";
    }
    var newWindow = window.open(site);
}

function viewQuantitation(status){
    var site;
    if (status == 'old') {
	var id = document.quantitations.chooser.options[document.quantitations.chooser.selectedIndex].value;
	site = "${uri}ManageTable.cgi?TABLE_NAME=MA_solexa_quantitation&solexa_quantitation_id="+id;
    }
    else {
	site = "${uri}ManageTable.cgi?TABLE_NAME=MA_solexa_quantitation&ShowEntryForm=1";
    }
    var newWindow = window.open(site);
}

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
  my (%solexa_requests, %solexa_flow_cell_lanes, %quantitation_files);

  ## Need to add a MainForm in order to facilitate proper movement between projects.  Otherwise some cgi params that we don't want might come through.
  print qq~ <FORM METHOD="post" NAME="MainForm" action="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi">
       <INPUT TYPE="hidden" NAME="apply_action_hidden" VALUE="">
       <INPUT TYPE="hidden" NAME="set_current_work_group" VALUE="">
       <INPUT TYPE="hidden" NAME="set_current_project_id" VALUE="">
  </form>
  ~;

  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();
	

    print "<BR>";
    my $menu = $sbeams->getMainPageTabMenuObj( cgi => $q );
    my $info = get_project_info( parameters_ref => \%parameters,
                                 return_all     => 1 );

    my $fb = "<FONT COLOR=green>";
    my $fe = '</FONT>';
    my $details = '';
    if ( 1 ) { # show regardless! $info->{samples} ){
      $details .=<<"      END";
      <TR><TD></TD><TD COLSPAN=2><B>$fb Number Solexa Samples:$fe</B> $info->{samples}</TD></TR> 
      END
    }
    if ( 1 ) { # show regardless! $info->{lanes} ){
      $details .=<<"      END";
      <TR><TD></TD><TD COLSPAN=2><B>$fb Number Solexa Lanes:$fe</B> $info->{lanes}</TD></TR> 
      END
    }
    if ( 1 ) { # Show regardless! $info->{conditions} ){
      $details .=<<"      END";
      <TR><TD></TD><TD COLSPAN=2><B>$fb Uploaded Conditions:$fe</B> $info->{conditions}</TD></TR> 
      END
    }
    if ( $menu->getActiveTab == 1 ) {
      my $rpad = '<TR><TD>&nbsp;</TD></TR>';
      my $content = $menu->getContent();
#      $content =~ s/\<PRE_PRIVILEGES_HOOK\>/$details/;
      $content =~ s/\<POST_PRIVILEGES_HOOK\>/$rpad $details/;
      $menu->addContent( $content );
    }
	  print "$menu";
  #	print "<BR><HR><BR>";
  #	print $menu->asMA_HTML();
	  print "<BR><BR>";
  #	print "<BR><TABLE WIDTH=50%><TR><TD><HR></TD></TR></TABLE><BR><BR>";
#  if ( !$parameters{_tab} || $parameters{_tab} == 1 ) {
#       print_summary_tab(parameters_ref=>\%parameters); 
#  }
  

  #### Get information about the current project from the database
  $sql = qq~
	SELECT P.name,P.project_tag,P.project_status, C.first_name, C.last_name, C.contact_id, UL.username
	  FROM $TB_PROJECT P
	  JOIN $TB_CONTACT C ON ( P.PI_contact_id = C.contact_id )
	  JOIN $TB_USER_LOGIN UL ON ( UL.contact_id = C.contact_id)
	WHERE P.project_id = '$project_id'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  if (@rows) {
    ($project_name,$project_tag,$project_status,$pi_first_name,$pi_last_name,$pi_contact_id,$username) = @{$rows[0]};
  }

  #### print_tabs
#  my @tab_titles = ("Summary","Management","Data Analysis", "Permissions");
#  my @tab_titles = ("Summary","Data Download","Permissions");
  my @tab_titles = ("Summary","Permissions");
  my $tab_titles_ref = \@tab_titles;
  my $page_link = 'main.cgi';

  #### Summary Section 
  if ($parameters{'tab'} eq "summary"){
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>0);
      print_summary_tab(parameters_ref=>\%parameters); 
  }
#  elsif($parameters{'tab'} eq "management") { 
#      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
#			     page_link=>$page_link,
#			     selected_tab=>1);
#      print_management_tab();
#  }
#  elsif($parameters{'tab'} =~ "data_download") {
#      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
#			     page_link=>$page_link,
#			     selected_tab=>1);
#      print_data_download_tab(ref_parameters=>$ref_parameters); 
#  }
  elsif($parameters{'tab'} eq "permissions") {
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>2);
      print_permissions_tab(ref_parameters=>$ref_parameters); 
  }
  else{
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>0);
      print_summary_tab(parameters_ref=>\%parameters);
  	
  }
  return;

}# end handle_request

###############################################################################
# get_project_info
###############################################################################
sub get_project_info {
  my %args = @_;
  my $SUB_NAME = "get_project_info";
  
	my $parameters_ref = $args{'parameters_ref'} || die "ERROR[$SUB_NAME] No parameters passed\n";
	my %parameters = %{$parameters_ref};
 

  ## Define standard variables
  my ($sql, @rows);
  my $current_contact_id = $sbeams->getCurrent_contact_id();
  my (%solexa_requests, %solexa_samples, %solexa_flow_cell_lanes, %quantitation_files);
  my $project_id = $sbeams->getCurrent_project_id();
  my ($project_name, $project_tag, $project_status, $project_desc);
  my ($pi_first_name, $pi_last_name, $pi_contact_id, $username);


  # Check for any Conditions that match this project ID
 
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

  # Count the number of solexa samples for this project
  my $n_solexa_samples = 0;

  if ($project_id > 0) {
	$sql = qq~ 	SELECT count(ss.solexa_sample_id)
			FROM $TBST_SOLEXA_SAMPLE ss 
		   	WHERE ss.project_id = $project_id 
			AND ss.record_status != 'D'
		~;
	 ($n_solexa_samples) = $sbeams->selectOneColumn($sql);	
  }  


  # Count the number of solexa lanes for this project
  my $n_solexa_flow_cell_lanes = 0;

  if ($project_id > 0) {
	$sql = qq~ 	SELECT count(sfcl.flow_cell_lane_id)
		   	FROM $TBST_SOLEXA_FLOW_CELL_LANE sfcl
			JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on 
				sfcl.flow_cell_lane_id = sfcls.flow_cell_lane_id
			JOIN $TBST_SOLEXA_SAMPLE ss on 
				sfcls.solexa_sample_id = ss.solexa_sample_id
		   	WHERE ss.project_id = $project_id 
			AND ss.record_status != 'D'
			AND sfcls.record_status != 'D'
			AND sfcl.record_status != 'D'
		~;
	 ($n_solexa_flow_cell_lanes) = $sbeams->selectOneColumn($sql);	
  }  

  unless( $args{return_all} ) {
    return ($n_condition_count, $n_solexa_samples, $n_solexa_flow_cell_lanes);
  } else {
    return { 
             conditions => $n_condition_count,
             samples    => $n_solexa_samples,
             lanes      => $n_solexa_flow_cell_lanes
           };
  }
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
  #my $current_contact_id = $sbeams->getCurrent_contact_id();
  #my (%solexa_requests, %solexa_flow_cells, %quantitation_files);
  my $project_id = $sbeams->getCurrent_project_id();
  my ($project_name, $project_tag, $project_status, $project_desc);
  #my ($pi_first_name, $pi_last_name, $pi_contact_id, $username);

  #print out some project info and return the number of hits for the following data types
  my ($n_condition_count, $n_solexa_samples, $n_solexa_flow_cell_lanes) = get_project_info(parameters_ref =>$parameters_ref);

  ########################################################################################
  ### Set some of the usful vars
  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  my $base_url = "$CGI_BASE_DIR/SolexaTrans/main.cgi";
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


#  my $default_data_type = "SOLEXA_FLOW_CELL_LANE";
  my $default_data_type = "SOLEXA_SAMPLE";
  
  my %count_types = ( CONDITION 		=> { 	COUNT => $n_condition_count, # $n_condition_count,
				   			POSITION => 3,
						   },
		   
		   SOLEXA_SAMPLE		=> {	COUNT => $n_solexa_samples,
		   					POSITION => 1,
				   		   },
		   SOLEXA_FLOW_CELL_LANE	=> {	COUNT => $n_solexa_flow_cell_lanes,
		   					POSITION => 2,
		   				   }	
		   );


  my @tabs_names = make_tab_names(%count_types);


  my ($display_type, $selected_tab_numb) = pick_data_to_show (default_data_type   => $default_data_type, 
							    tab_types_hash 	=> \%count_types,
							    param_hash		=> \%parameters,
							   );
							
							
  display_sub_tabs(	display_type 	=> $display_type,
			tab_titles_ref	=> \@tabs_names,
			page_link	=> "main.cgi",
			selected_tab	=> $selected_tab_numb
	        );
		
  #########################################################################################	
  #### Print the SUMMARY DATA OUT

	if($display_type eq 'CONDITION') {
		
		$sql = qq~
		   		SELECT condition_id, condition_name, comment
				FROM $TBST_COMPARISON_CONDITION 
				WHERE project_id = $project_id
				AND record_status != 'D'
			~;
		
		 %url_cols = (
		 	 	'condition_id' => "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_comparison_condition&condition_id=\%0V",
		 	 	'condition_name' => "$CGI_BASE_DIR/SolexaTrans/GetExpression?condition_id=\%0V",
			     );

  		 %hidden_cols = ('solexa_flow_cell_id' => 1,
		     		);
	}elsif($display_type eq 'SOLEXA_SAMPLE') {
		
		$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
		$sbeams_solexa_groups->setSBEAMS($sbeams);				#set the sbeams object into the solexa_groups_object
		
		 $sql = $sbeams_solexa_groups->get_solexa_sample_sql(project_id    => $project_id, );
		
		 %url_cols = (
				'Sample_Tag'	=> "${manage_table_url}solexa_sample&solexa_sample_id=\%0V",
			     );

  		 
		 %hidden_cols = (
		     		 'Sample_ID' => 1
				);
	
	}elsif($display_type eq 'SOLEXA_FLOW_CELL_LANE') {
		
		$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
		$sbeams_solexa_groups->setSBEAMS($sbeams);				#set the sbeams object into the solexa_groups_object
		
		 $sql = $sbeams_solexa_groups->get_solexa_flow_cell_lane_sql(project_id    => $project_id, );
		
		 %url_cols = (
				'Sample_Tag'	=> "${manage_table_url}solexa_sample&solexa_sample_id=\%0V",
				'Solexa_Flow_Cell_Lane_ID'	=> "${manage_table_url}solexa_flow_cell_lane&solexa_flow_cell_lane_id=\%3V",
			     );

  		 
		 %hidden_cols = (
				 'Sample_ID' => 1
				);
	
	}else{
		print "<h2>SORRY THERE IS NOTHING TO SHOW</h2>";
	
		return;
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

#	if($display_type eq 'SOLEXA_FLOW_CELL_LANE') {
#	    $sbeams->addResultsetNumbering( rs_ref  => $resultset_ref,
 #                              colnames_ref => \@column_titles,
  #                                list_name => 'Flow Cell ID' );
#	}

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
				  base_url=>$base_url,
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
	
	my $count = 0;
	foreach my $tab_name (@tabs_names){
		#loop through the tabs to display.  When we get to the one that is the 
		# "selected" one use it's solexa position number as the selected_tab count
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
	
	my @tab_names = sort { $types_h{$a}{POSITION} <=> $types_h{$b}{POSITION}} keys %types_h; #order which the tabs will be displayed on the screen

	@tab_names =  grep { $types_h{$_}{COUNT} > 0 } (@tab_names);				#only make tabs for data types with data
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
	#parameters may be produce when using readResults sets method, instead of reading directly from the cgi param method
  	my %parameters	 	= % { $args{param_hash} };		
	
	my $SUB_NAME = "pick_data_to_show";
	
	#Need to choose what type of data summary to display  
	my $all_cgi_tab_val = '';
	
	if ($all_cgi_tab_val = $parameters{tab} ){				#if there is a cgi parm with the 'tab' key use it for the data type to display
		foreach my $cgi_tab_val (split /,/,$all_cgi_tab_val ){
			$cgi_tab_val = uc $cgi_tab_val;
			
			if (grep { $cgi_tab_val eq $_} keys %data_types_h){	#need to make sure the tab param is not coming from other parts of the program. this will unsure it's one of the tabs we are interested in
			 
				if ($data_types_h{$cgi_tab_val}{COUNT} > 0){	#make sure the tab has data, a user might have switched projects to one without this type of data
					return (uc $cgi_tab_val, 0);		#need to return the upper case value since the print tabs method will make it lower case
				}
			}
		}
	}
									#if the default value comes in and it has data to display, show it.
	
	return ($default_data_type, 0) if ( $data_types_h{$default_data_type}{COUNT} > 0);	
	
	
	foreach my $data_type (keys %data_types_h){
		
		if ($data_types_h{$data_type}{COUNT} > 0) {		#Else loop through all the data types and show the first one that has data to display in the summary
			return ($data_type, 0);
		}else{
			#print "NOTHING FOR '$data_type'<br>";
		}
		
	}
	
	
	return 'NOTHING TO SHOW';					#if there is nothing to display come here
	
}


###############################################################################
# print_miame_status_tab
###############################################################################
sub print_miame_status_tab {
  my %args = @_;
  my $SUB_NAME = "print_miame_status_tab";
  
  ## Decode argument list
  my $project_id = $sbeams->getCurrent_project_id();

  ## Define standard variables

  print qq!

<H1>MIAME Status:</H1>
<IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="100%" HEIGHT="1"><BR>
<TABLE CELLSPACING="5">
<TR><TD></TD></TR>
<TR>
  <TD>Experiment Design</TD>
  <TD><A HREF="MIAMEStatus.cgi?tab=experiment_design">Detailed Information</A></TD>
</TR>
<TR>
  <TD>Array Design</TD>
  <TD><A HREF="MIAMEStatus.cgi?tab=solexa_design">Detailed Information</A></TD>
</TR>
<TR>
  <TD>Sample Information</TD>
  <TD><A HREF="MIAMEStatus.cgi?tab=sample_information">Detailed Information</A></TD>
</TR>
<TR>
  <TD>Labeling and Hybridization</TD>
  <TD><A HREF="MIAMEStatus.cgi?tab=labeling_and_hybridization">Detailed Information</A></TD>
</TR>
<TR>
  <TD>Measurements</TD>
  <TD><A HREF="MIAMEStatus.cgi?tab=measurements">Detailed Information</A></TD>
</TR>
<TR>
  <TD></TD>
  <TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
</TR>
</TABLE><BR>
<B>Links</B><BR>
<A HREF="http://www.mged.org/Workgroups/MIAME/miame.html" target="_blank">-MIAME Website</A><BR>
<A HREF="../../doc/SolexaTrans/MIAME_checklist.doc">-Download MIAME Checklist</A>
$LINESEPARATOR
      !;
  return;
}
  

###############################################################################
# print_management_tab
###############################################################################
#sub print_management_tab {
#  my %args = @_;
#  my $SUB_NAME = "print_management_tab";
#  
#  ## Decode argument list
#  my $project_id = $sbeams->getCurrent_project_id();
#
#  ## Define standard variables
#  my ($sql, @rows);
#  my (%solexa_requests, $n_solexa_requests);
#  my (%solexa_flow_cells, $n_solexa_flow_cell_lanes);
#  my (%quantitation_files, $n_quantitation_files);
#
#  $sql = qq~
#      SELECT solexa_request_id, n_slides, date_created 
#      FROM $TBST_SOLEXA_FLOW_CELL_REQUEST
#      WHERE project_id = '$project_id'
#      AND record_status != 'D'
#      ~;
#  @rows = $sbeams->selectSeveralColumns($sql);
#  foreach my $row(@rows){
#      my @temp_row = @{$row};
#      $solexa_requests{$temp_row[0]} = "$temp_row[2] ($temp_row[1] slides)";
#      $n_solexa_requests++;
#  }
#  
#  $sql = qq~
#      SELECT ASCAN.solexa_scan_id, ASCAN.stage_location
#      FROM $TBMA_ARRAY_SCAN ASCAN
#      JOIN $TBMA_ARRAY A ON ( A.solexa_flow_cell_id = ASCAN.solexa_flow_cell_id )
#      JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( AQ.solexa_scan_id = ASCAN.solexa_scan_id )
#      WHERE A.project_id = '$project_id'
#      AND ASCAN.record_status != 'D'
#      AND A.record_status != 'D'
#      AND AQ.record_status != 'D'
#      ~;
#  %solexa_flow_cells = $sbeams->selectTwoColumnHash($sql);
#  
#  $sql = qq~
#      SELECT AQ.solexa_quantitation_id, AQ.stage_location
#      FROM $TBMA_ARRAY_SCAN ASCAN
#      JOIN $TBMA_ARRAY A ON ( A.solexa_flow_cell_id = ASCAN.solexa_flow_cell_id )
#      JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( AQ.solexa_scan_id = ASCAN.solexa_scan_id )
#      WHERE A.project_id = '$project_id'
#      AND ASCAN.record_status != 'D'
#      AND A.record_status != 'D'
#      AND AQ.record_status != 'D'
#      ~;
#  %quantitation_files = $sbeams->selectTwoColumnHash($sql);
#  
#  foreach my $key (keys %solexa_flow_cells) {
#      $n_solexa_flow_cell_lanes++;
#  }
#  foreach my $key (keys %quantitation_files){
#      $n_quantitation_files++;
#  }
#
#  print qq~
#<H1>Project Management:</H1>
#<IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="100%" HEIGHT="1">
#  ~;
#
#  print qq~
#<FORM NAME="requests">
#<TABLE>
#<TR><TD><B>Array Requests</B></TD></TR>
#<TR><TD><SELECT NAME="chooser">
#  ~;
#  
#  foreach my $key(keys %solexa_requests) {
#      print qq~ <OPTION value = "$key">$solexa_requests{$key} ~;
#  }
#
#  print qq~
#</SELECT></TD></TR>
#<TR>
#  <TD>
#  <INPUT TYPE="button" name="arButton" value="Go To Record" onClick="viewRequest('old')">
#  <INPUT TYPE="button" name="newARButton" value="Add New Record" onClick="viewRequest('new')">
#  </TD>
#</TR>
#</TABLE>
#</FORM>
#	
#<BR>
#      
#<FORM NAME="images">
#<TABLE>
#<TR><TD><B>Array Images</B></TD></TR>
#<TR><TD><SELECT name="chooser">
#        ~;
#  
#  foreach my $key(keys %solexa_flow_cells) {
#      my $name = $solexa_flow_cells{$key};
#      $name =~ s(^.*/)();
#      print qq~ <OPTION value="$key">$name ~;
#  }
#  
#  print qq~
#</SELECT></TD></TR>
#<TR>
#  <TD>
#  <INPUT TYPE="button"name="aiButton" value="Go To Record" onClick="viewImage('old')">
#  <INPUT TYPE="button"name="newAIButton" value="Add New Record" onClick="viewImage('new')">
#  </TD>
#</TR>
#</TABLE>
#</FORM>
#      
#<BR>
#
#<FORM NAME="quantitations">
#<TABLE>
#<TR><TD><B>Array Quantitation</B></TD></TR>
#<TR><TD><SELECT name="chooser">
#        ~;
#
#  foreach my $key (keys %quantitation_files) {
#      my $name = $quantitation_files{$key};
#      $name =~ s(^.*/)();
#      print qq~ <OPTION value="$key">$name ~;
#  }
#  print qq~
#</SELECT></TD></TR>
#<TR>
#  <TD>
#  <INPUT TYPE="button"name="aqButton"value="Go to Record" onClick="viewQuantitation('old')">
#  <INPUT TYPE="button"name="newAQButton"value="Add New Record" onClick="viewQuantitation('new')">
#  </TD>
#</TR>
#</TABLE>
#</FORM>
#$LINESEPARATOR
#  ~;
#  return;
#}
###############################################################################
# print_data_pipeline_tab
###############################################################################
sub print_data_pipeline_tab {
  my %args = @_;
  my $SUB_NAME = "print_data_pipeline_tab";
  
	my $parameters_ref = $args{'parameters_ref'} || die "ERROR[$SUB_NAME] No parameters passed\n";
	
  	my ($n_condition_count, $n_solexa_samples, $n_solexa_flow_cell_lanes) = get_project_info(parameters_ref =>$parameters_ref);

	my $html  = '';

#	if(($n_condition_count + $n_solexa_flow_cell_lanes + $n_solexa_chips) > 0){
#
  # Changed condition to show solexa pipeline iff user can write to project.
  my $canWriteProject = $sbeams->isProjectWritable();
	if( $canWriteProject ){
		$html = <<END;
<table>
 <tr class="grey_header" border=1>
  <td>Analysis Type</td>
  <td>Description</td>
 </tr>
END

			$html .= <<END;
 <tr>
  <td><a href="$CGI_BASE_DIR/SolexaTrans/bioconductor/upload.cgi">Solexa Analysis Pipeline</a></td>
  <td>Analyze Solexametrix CEL files and view the data in a variety of ways.....</td>
 </tr>
END
	
		if($n_solexa_flow_cell_lanes > 0){
$html .= <<END;
 <tr>
  <td><A HREF="PipelineSetup.cgi">Submit a New Job to the Two Color Analysis Pipeline</A></td>
  <td>Process Two Color Arrays.  
  	<A HREF="http://db.systemsbiology.net/software/ArrayProcess/" TARGET="_blank">What is the Two Color Data Processing Pipeline?</A> 
  </td>
 </tr>
END

		}
		
		if($n_condition_count){
$html .= <<END;
 <tr>
  <td><a href="$CGI_BASE_DIR/SolexaTrans/GetExpression">Get Expression</a></td>
  <td>Retrieve data from the Get Expression table.....</td>
 </tr>
END

		}
		
		$html .= "</table>";
	}else{#end of if clause to print any data 	
		$html = "<b>You lack permission to write to this project</b>";
	}
	print $html;
}

###############################################################################
# print_data_download_tab
###############################################################################
sub print_data_download_tab {
  	my %args = @_;
  	my $resultset_ref = '';
	my @columns = ();
	my $sql = '';
	
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %max_widths;
	my %rs_params = $sbeams->parseResultSetParams(q=>$q);
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/main.cgi?tab=data_download";
	my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=MA_";

	my %url_cols      = ();
	my %hidden_cols   = ();
	my $limit_clause  = '';
	my @column_titles = ();
  	
	my ($display_type, $selected_tab_numb);
  	
	
	my @downloadable_file_types = ();
	my @default_file_types      = ();
	my @diplay_files  = ();
  	
	#### Process the arguments list
 	my $ref_parameters = $args{'ref_parameters'}
    		|| die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};
  	my $project_id = $sbeams->getCurrent_project_id();
	
	my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

	## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
	if ($parameters{set_current_project_id}) {
		$apply_action = 'QUERY';
	}
  
  ###############################################################################
  ##First check to see if the user already has selected some data to download
	
	#come here if the user has choosen some files to download
	if (exists $parameters{Get_Data}){			
           print "get data is ".$parameters{Get_Data}."<br><bR>\n";		
		#value of the button submiting Solexa files to be zipped
		if ( $parameters{Get_Data} eq 'GET_SOLEXA_FLOW_CELL_FILES') {
		
			#set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
			$sbeams_solexa_groups->setSBEAMS($sbeams);			
		
			#Get the date with a command line call Example 2004-07-16
			my $date = `date +%F`;						
			$date =~ s/\s//g;						
		
			#make the full file name with the process_id on the end to keep it some what unique	
			my $out_file_name    = "${date}_solexa_zip_request_$$.zip";	
		
			my @files_to_zip = collect_files(parameters => \%parameters);
   
   			##########################################################################
  			### Print out some nice table showing what is being exported
		
			#example '37__CEL,38__CEL,45__CEL,46__CEL,46__XML'
			my $solexas_id_string =  $parameters{get_all_files}; 		
		
			# remove any redundant solexa_flow_cell_ids since one solexa_flow_cell_id 
			# might have multiple file extensions
			my @solexa_flow_cell_lane_ids = split /,/, $solexas_id_string;			
		
			my %unique_solexa_flow_cell_lane_ids = map {split /__/} @solexa_flow_cell_lane_ids;
		
			my $solexas = join ",", sort keys %unique_solexa_flow_cell_lane_ids;
		
			$sql = $sbeams_solexa_groups->get_all_solexa_info_sql(solexa_flow_cell_lane_ids => $solexas, );
			
			my $tab_results = $sbeams_solexa_groups->export_data_solexa_sample_info(sql =>$sql);
 				
			#collect the files and zip and print to stdout
			if (@files_to_zip) {						
				zip_data(files 		=> \@files_to_zip,
				         zip_file_name	=> $out_file_name,
					 parameters 	=> \%parameters,
			                 solexa_groups_obj => $sbeams_solexa_groups,
					 solexa_info	=> $tab_results,
					 );
				
   			}	
    		
			exit;
			
		} # end if Get_Data eq GET_SOLEXA_FLOW_CELL_FILES
	
	###############################################################################
	##Start looking for data that can be downloaded for this project
	
	#if user has not selected data to download come here
	}else{
	
#		print qq~
#		<BR>
#		<TABLE WIDTH="100%" BORDER=0>
#		  <TR>
#		    <TD><h2>Please select data to download</h2></TD></TR>
#		~;
	
		##Get some summary data for all the data types that can be downloaded	
		## Count the number of solexa lanes for this project
		my $n_solexa_flow_cell_lanes = 0;
		
		if ($project_id > 0) {
			my $sql = qq~ 	
			SELECT count(sfcl.flow_cell_lane_id)
                        FROM $TBST_SOLEXA_FLOW_CELL_LANE sfcl
                        JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on
                                sfcl.flow_cell_lane_id = sfcls.flow_cell_lane_id
                        JOIN $TBST_SOLEXA_SAMPLE ss on
                                sfcls.solexa_sample_id = ss.solexa_sample_id
                        WHERE ss.project_id = $project_id
                        AND ss.record_status != 'D'
                        AND sfcls.record_status != 'D'
                        AND sfcl.record_status != 'D'
				~;
			($n_solexa_flow_cell_lanes) = $sbeams->selectOneColumn($sql);	
 		}

		my $n_solexa_samples = 0;
		if ($project_id > 0) {
			my $sql = qq~
				SELECT count(ss.solexa_sample_id)
				FROM $TBST_SOLEXA_SAMPLE ss
				WHERE ss.project_id = $project_id
				AND ss.record_status != 'D'
			~;
			($n_solexa_samples) = $sbeams->selectOneColumn($sql);
		}
 
#		my $output_dir = "/net/solexa/Pipeline/output/project_id/".$project_id;
#		opendir (PROJECTDIR, $output_dir);
#		my @dir_contents = readdir PROJECTDIR;
	
#		print qq~
#		  <TR>
#		    <TD COLSPAN="2"><B>Number Solexa Lanes:  $n_solexa_flow_cell_lanes</B></TD>
#		  </TR>
#		</TABLE>
#		<p>
#		~;
		#############
		###Add different types of data to download
		
		#################################################################################
	  	##Set up the hash to control what sub tabs we might see
	
		my $default_data_type = "SOLEXA_SAMPLE";

		my %count_types = ( SOLEXA_FLOW_CELL_LANE	=> {	COUNT => $n_solexa_flow_cell_lanes,
				   					POSITION => 1
		   		   				   },
				    SOLEXA_SAMPLE 		=> { 	COUNT => $n_solexa_samples,
								     	POSITION => 0
								   }
				  );

		my @tabs_names = make_tab_names(%count_types);

		($display_type, $selected_tab_numb) =	pick_data_to_show (default_data_type    => $default_data_type, 
							    		  	tab_types_hash 	=> \%count_types,
							    		   	param_hash	=> \%parameters,
							   		   );

		my $tabs_exists = display_sub_tabs(	display_type 	=> $display_type,
				       			tab_titles_ref	=>\@tabs_names,
							page_link	=>"main.cgi",
							selected_tab	=> $selected_tab_numb,
	     					    	parent_tab  	=> $parameters{'tab'},
	     					   );
	
		#####################################################################################
		### Show the data that can be downloaded
	
		if ($display_type eq 'SOLEXA_SAMPLE'){
		
			$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

			@downloadable_file_types = $sbeamsMOD->get_SOLEXA_FILES;
			#default file type to turn on the checkbox
			@default_file_types = qw(ELAND);

			#files that should have urls constructed to open the file in the browser	
			@diplay_files	    = qw(SUMMARY RAW);
		
			#set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups->setSBEAMS($sbeams);
		
			#return a sql statement to display all the solexa flow cell lanes for a particular project
			$sql = $sbeams_solexa_groups->get_solexa_sample_sql(project_id    => $project_id, ); 
						     			
		 	%url_cols = (
		 	 		'Sample_ID' 	=> "$CGI_BASE_DIR/SolexaTrans/main.cgi?tab=data_download&download_type=SOLEXA_SAMPLE&solexa_sample_id=\%0V",
			     		'Sample_Tag'	=> "${manage_table_url}solexa_sample&solexa_sample_id=\%3V",
				     );

  		 
			 %hidden_cols = (
					);

		} elsif ($display_type eq 'SOLEXA_FLOW_CELL_LANE'){
		
			$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

			@downloadable_file_types = $sbeamsMOD->get_SOLEXA_FILES;

			#default file type to turn on the checkbox
			@default_file_types = qw(ELAND);

			#files that should have urls constructed to open the file in the browser	
			@diplay_files	    = qw(SUMMARY RAW);
		
			#set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups->setSBEAMS($sbeams);
		
			#return a sql statement to display all the solexas for a particular project
			$sql = $sbeams_solexa_groups->get_solexa_flow_cell_lane_sql(project_id    => $project_id );
						     			
		 	%url_cols = (
			     		'Sample_Tag'	=> "${manage_table_url}solexa_sample&solexa_sample_id=\%3V",
				     );

  		 
			 %hidden_cols = (
					);
	
		}else{
			print "<h2>Sorry No Data to download for this project</h2>" ;
			return;
		} 
	}
	
  ###################################################################
  ## Print the data 
		
	unless (exists $parameters{Get_Data}) {
		print $q->start_form(-name =>'download_filesForm',						#start the form to download solexa files
				     -action=>"$CGI_BASE_DIR/SolexaTrans/main.cgi",
				     );
				     			
  		print $q->hidden(-name=>'tab',									#make sure to include the name of the tab we are on
				 -value=>'parameters{tab}',
				 );
  ###################################################################
  ## Make a small table to show some checkboxes so a user can click once to turn on or off all the files in a particular group	
		
		print "<br>";
		
		$sbeamsMOD->make_checkbox_control_table( box_names => \@downloadable_file_types, 
							default_file_types => \@default_file_types,
							);
		
	}
  ###################################################################
  #### If the apply action was to recall a previous resultset, do it
 	 
	 if ($apply_action eq "VIEWRESULTSET") {
   		$sbeams->readResultSet(
     	 	resultset_file=>$rs_params{set_name},
     	 	resultset_ref=>$resultset_ref,
     	 	query_parameters_ref=>\%parameters,
    	  	resultset_params_ref=>\%rs_params,
   	 	);
	  }
		
		
		
	#### Fetch the results from the database server
    	$sbeams->fetchResultSet(sql_query=>$sql,
				resultset_ref=>$resultset_ref,
				);
 
  ####################################################################
  ## Need to Append data onto the data returned from fetchResultsSet in order to use the writeResultsSet method to display a nice html table
  	
	if ($display_type eq 'SOLEXA_FLOW_CELL_LANE' &! exists $parameters{Get_Data}) {
		
		append_new_data(resultset_ref => $resultset_ref, 
				file_types    => \@downloadable_file_types,			#append on new values to the data_ref foreach column to add
				default_files => \@default_file_types,
				display_files => \@diplay_files					#Names for columns which will have urls to pop open files
				);
	}
  
  ####################################################################
  
	#### Store the resultset and parameters to disk resultset cache
	$rs_params{set_name} = "SETME";
	$sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
				resultset_ref=>$resultset_ref,
				query_parameters_ref=>\%parameters,
				resultset_params_ref=>\%rs_params,
				query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
				);
		
		
#### Set the column_titles to just the column_names
	@column_titles = @{$resultset_ref->{column_list_ref}};
	#print "COLUMN NAMES 1 '@column_titles'<br>";
		
  for my $title ( @column_titles ) {
    print "$title <BR>\n";
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
				);
					
	
	unless ($parameters{Get_Data}) {
		print "<h3>To start the download click the button below<br>";
		print "<h3>A single Zip file will be downloaded to a location of your choosing *</h3>";
		print "<p>*Please note that the actual file size being downloaded will be about half the size the browser maybe indicating</p>";
		
		
		print   $q->br,
			$q->submit(-name=>'Get_Data',
                	       	 -value=>'GET_SOLEXA_FLOW_CELL_LANE_FILES');			#will need to change value if other data sets need to be downloaded
	
		
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
# append_new_data
#
# Append on the more columns of data which can then be shown via the displayResultSet method
###############################################################################

sub append_new_data {
	my %args = @_;
	
	my $resultset_ref = $args{resultset_ref};
	my @file_types    = @{$args{file_types}};	#solexa ref of columns to add 
	my @default_files = @{$args{default_files}};	#solexa ref of column names that should be checked
	my @display_files = @{$args{display_files}};	#solexa ref of columns to make which will have urls to files to open
	
	my $aref = $$resultset_ref{data_ref};		#data is stored as an solexa of solexas from the $sth->fetchrow_solexa each row a row from the database holding an aref to all the values
	
	
	
   ########################################################################################
	foreach my $display_file (@display_files){		#First, add the Columns for the files that can be viewed directly
		
		
		foreach my $row_aref (@{$aref} ) {		
			
			my $solexa_flow_cell_id  = $row_aref->[0];		#need to make sure the query has the solexa_flow_cell_id in the first column since we are going directly into the solexa of solexas and pulling out values		
			my $root_name = $row_aref->[1];	
								#loop through the files to make sure they exists.  If they do not don't make a check box for the file
			my $file_exists = check_for_file(	solexa_flow_cell_id => $solexa_flow_cell_id, 
								file_root_name =>$root_name, 
								file_extension =>$display_file,
							);
		
			
			my $anchor = '';
			if ($file_exists){			#make a url to open this file
				$anchor = "<a href=View_Solexa_files.cgi?action=view_file&solexa_flow_cell_id=$solexa_flow_cell_id&file_ext=$display_file>View</a>";
			}else{
				$anchor = "No File";
			}
			
			push @$row_aref, $anchor;		#append on the new data	
		}
		
		push @{$resultset_ref->{column_list_ref}} , "View $display_file";  #add on column header for each of the file types
										   #need to add the column headers into the resultset_ref since DBInterface display results will reference this
		
		append_precision_data($resultset_ref);				   #need to append a value for every column added otherwise the column headers will not show
	}
	
	
   ########################################################################################
	
	foreach my $file_ext (@file_types) {			#loop through the column names to add checkboxes
		my $checked = '';
		if ( grep {$file_ext eq $_} @default_files) {
			$checked = "CHECKED";
		}
		
		foreach my $row_aref (@{$aref} ) {		#serious breach of encapsulation,  !!!! De-reference the data solexa and pushes new values onto the end
			
			my $solexa_flow_cell_id  = $row_aref->[0];		#need to make sure the query has the solexa_flow_cell_id in the first column since we are going directly into the solexa of solexas and pulling out values			
			my $root_name = $row_aref->[1];
			
								#loop through the files to make sure they exists.  If they do not don't make a check box for the file
			my $file_exists = check_for_file(	solexa_flow_cell_id => $solexa_flow_cell_id, 
								file_root_name =>$root_name, 
								file_extension =>$file_ext,
							);
			
			
			my $input = '';
			if ($file_exists){			#make Check boxes for all the files that are present <solexa_flow_cell_id__File extension> example 48__CHP
				$input = "<input type='checkbox' name='get_all_files' value='${solexa_flow_cell_id}__$file_ext' $checked>";
			}else{
				$input = "No File";
			}
			
			push @$row_aref, $input;		#append on the new data		
			
			
		}
	
		push @{$resultset_ref->{column_list_ref}} , "$file_ext";	#add on column header for each of the file types
										#need to add the column headers into the resultset_ref since DBInterface display results will refence this
		
		append_precision_data($resultset_ref);				#need to append a value for every column added otherwise the column headers will not show
	
	}
	
}
###############################################################################
# check_for_file_existance
#
# Pull the file base path from the database then do a file exists on the full file path
###############################################################################
sub check_for_file {
	my %args = @_;
	
	my $flow_cell_lane_id = $args{flow_cell_lane_id};
	my $root_name = $args{file_root_name};
	my $file_ext = $args{file_extension};					#Fix me same query is ran to many times, store the data localy
	
	my $sql = qq~  SELECT fp.file_path
			FROM $TBST_SOLEXA_PIPELINE_RESULTS spr, $TBST_FILE_PATH fp 
			WHERE spr.eland_output_file_id = fp.file_path_id
			AND spr.flow_cell_lane_id = $flow_cell_lane_id
		   ~;
	my ($path) = $sbeams->selectOneColumn($sql);
	
	my $file_path = "$path/$root_name.$file_ext";
	
	if (-e $file_path){
		return 1;
	}else{
		#print "MISSING FILE '$file_path'<br/>";
		return 0;
	}
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
# zip_data
#Take all the data and zip it up 
###############################################################################
sub zip_data  {
	my $SUB_NAME = 'zip_data';
	
	my %args = @_;
	
	my @files_to_zip = @ { $args{files} };
	my %parameters 	 = % { $args{parameters} };
	my $sbeams_solexa_groups = $args{solexa_groups_obj};
	my $zip_file_name   = $args{zip_file_name};
	my $solexa_info	    = $args{solexa_info};
	
	if ($VERBOSE > 0 ) {
		print "FILES TO ZIP '@files_to_zip'\n";
	}
	
	my $zip = Archive::Zip->new();
	my $member = '';
	my $compressed_size = '';
	my $uncompressed_size = '';
	
	foreach my $file_path ( @files_to_zip){
		
		my ($file, $dir, $ext) = fileparse( $file_path) ;
		$member = $zip->addFile( $file_path, "$file$ext") ;	#don't use the full file path for the file names, just use the file name
	
		$compressed_size   += $member->compressedSize();
		$uncompressed_size += $member->uncompressedSize();
	}
	
	$member = $zip->addString($solexa_info, "Array_info.txt");
	
	print "Content-Disposition: filename=$zip_file_name\n";
	print "Content-Length: $compressed_size\n"; 
	print "Content-Transfer-Encoding: binary\n";
	print "Content-type: application/force-download \n\n";
	
	unless ($zip->writeToFileHandle( 'STDOUT', 0 )  == 'AZ_OK') {
		
		error_log(error => "$SUB_NAME: Unable to write out Zipped file for '$zip_file_name' ");
	}

	########### MAKE A ZIP LOG TO SEE WHAT IS BEING WRITTEN OUT
	
	return($compressed_size, $uncompressed_size);
	
}



###############################################################################
# collect_files
#Parse out the Solexa solexa id's and query the db to collect the file paths needed to reterieve the data files
#return solexa of full file paths
###############################################################################
sub collect_files  {
	my $SUB_NAME = 'collect_files';
	
	my %args = @_;
	
	my %parameters =  %{ $args{parameters} };
	
	
	
	my $file_ids = $parameters{get_all_files};
		
	my @all_ids = split /,/, $file_ids; 						 #example '37__CEL,38__CEL,45__CEL,46__CEL'   <solexa_flow_cell_id__FILE_EXT>,next solexa
	
	
	if ($VERBOSE > 0 ) {
		print "SOLEXA RUN ID's '@all_ids'\n";
	}
	
	
	my %previous_paths = ();
	my @files_to_zip = ();
	
	foreach my $file_id (@all_ids) {
		my ($solexa_flow_cell_id , $file_ext) = split /__/, $file_id;
		
		my $file_path = '';
		
		if ($DEBUG>0){
			print "SOLEXA RUN ID '$solexa_flow_cell_id' FILE EXT '$file_ext'\n";
		}
		
		
		if (exists $previous_paths{$solexa_flow_cell_id}) {			#if this solexa ID has been seen before, pull it out of a temp hash instead of doing a query
			$file_path = "$previous_paths{$solexa_flow_cell_id}{BASE_PATH}/$previous_paths{$solexa_flow_cell_id}{ROOT_NAME}.$file_ext";
		
		}else{
			my ($file_root, $file_base_path) = $sbeams_solexa_groups->get_file_path_from_id(solexa_flow_cell_id => $solexa_flow_cell_id); #method in SolexaTrans::Solexa_file_groups.pm
			
			$file_path = "$file_base_path/$file_root.$file_ext";
			
			$previous_paths{$solexa_flow_cell_id}{BASE_PATH} = $file_base_path;	#put the data into memory for quick access if the same solexa_flow_cell_id is used, since one root_file name might have multiple extensions
			$previous_paths{$solexa_flow_cell_id}{ROOT_NAME} = $file_root;
			
		}	
		if ($VERBOSE > 0 ) {
			print "FILE PATH '$file_path'\n";
		}
		push @files_to_zip, $file_path;
	}
	
	return @files_to_zip;
}
	

###############################################################################
# error_log
###############################################################################
sub error_log {
	my $SUB_NAME = 'error_log';
	
	my %args = @_;
	
	die "Must provide key value pair for 'error' \n" unless (exists $args{error});
	
	open ERROR_LOG, ">>SOLEXA_ZIP_ERROR_LOGS.txt"
		or die "$SUB_NAME CANNOT OPEN ERROR LOG $!\n";
		
	my $date = `date`;
	
	print ERROR_LOG "$date\t$args{error}\n";
	close ERROR_LOG;
	
	die "$date\t$args{error}\n";
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
