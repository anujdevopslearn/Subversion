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
use vars qw ($sbeams $sbeamsMOD $sbeams_affy_groups $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS $DISPLAY_SUMMARY);
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;


use SBEAMS::Microarray::Affy;
use SBEAMS::Microarray::Affy_file_groups;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;

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

  if($parameters{'hide_twocolor'}) {  
		$CONFIG_SETTING{MA_HIDE_TWO_COLOR} = 1;
	}



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
	site = "${uri}SubmitArrayRequest.cgi?TABLE_NAME=MA_array_request&array_request_id="+id;
    }
    else {
	site = "${uri}SubmitArrayRequest.cgi?TABLE_NAME=MA_array_request&ShowEntryForm=1";
    }
    var newWindow = window.open(site);
}

function viewImage(status){
    var site;
    if (status == 'old') {
	//alert ("scan images not available to be viewed.  Will be developed later");
    var id = document.images.chooser.options[document.images.chooser.selectedIndex].value
    var site = "${uri}ManageTable.cgi?TABLE_NAME=MA_array_scan&array_scan_id="+id
    }
    else {
	//alert ("scan images not on a network share.");
        var site = "${uri}ManageTable.cgi?TABLE_NAME=$TBMA_ARRAY_SCAN&ShowEntryForm=1";
    }
    var newWindow = window.open(site);
}

function viewQuantitation(status){
    var site;
    if (status == 'old') {
	var id = document.quantitations.chooser.options[document.quantitations.chooser.selectedIndex].value;
	site = "${uri}ManageTable.cgi?TABLE_NAME=MA_array_quantitation&array_quantitation_id="+id;
    }
    else {
	site = "${uri}ManageTable.cgi?TABLE_NAME=MA_array_quantitation&ShowEntryForm=1";
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
  my (%array_requests, %array_scans, %quantitation_files);

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
	

  if($parameters{'mode'} eq "miame_status") { 
    print_miame_status_tab(); 

  } elsif($parameters{'mode'} eq "management") { 
    print_management_tab(); 

  } else {
    print "<BR>";
    my $menu = $sbeams->getMainPageTabMenuObj( cgi => $q );
    my $info = get_project_info( parameters_ref => \%parameters,
                                 return_all     => 1 );

    my $fb = "<FONT COLOR=green>";
    my $fe = '</FONT>';
    my $details = '';
    if ( 1 ) { # show regardless! $info->{chips} ){
      $details .=<<"      END";
      <TR><TD></TD><TD COLSPAN=2><B>$fb Number Affy Chips:$fe</B> $info->{chips}</TD></TR> 
      END
    }
    if ( 1 ) { # Show regardless! $info->{conditions} ){
      $details .=<<"      END";
      <TR><TD></TD><TD COLSPAN=2><B>$fb Uploaded Conditions:$fe</B> $info->{conditions}</TD></TR> 
      END
    }
    if ( $info->{quants} || $info->{requests} || $info->{scans} ){
      $details .=<<"      END";
      <TR><TD></TD><TD COLSPAN=2><B>$fb Array Quantitations:$fe</B> $info->{quants}</TD></TR> 
      <TR><TD></TD><TD COLSPAN=2><B>$fb Array Requests:$fe</B> $info->{requests}</TD></TR> 
      <TR><TD></TD><TD COLSPAN=2><B>$fb Array Scans:$fe</B> $info->{scans}</TD></TR> 
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
	  if ( !$parameters{_tab} || $parameters{_tab} == 1 ) {
       print_summary_tab(parameters_ref=>\%parameters); 
	  }
  }
	  exit;

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
  my @tab_titles = ("Summary","MIAME Status","Management","Data Pipeline", "Data Download", "Permissions");
  my $tab_titles_ref = \@tab_titles;
  my $page_link = 'main.cgi';

  #### Summary Section 
  if ($parameters{'tab'} eq "summary"){
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>0);
      print_summary_tab(parameters_ref=>\%parameters); 
  }
  elsif($parameters{'tab'} eq "miame_status") { 
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>1);
      print_miame_status_tab(); 
  }
  elsif($parameters{'tab'} eq "management") { 
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>2);
      print_management_tab();
  }
  elsif($parameters{'tab'} eq "data_pipeline") {
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>3);
      print_data_pipeline_tab(parameters_ref=>\%parameters)
  }elsif($parameters{'tab'} =~ "data_download") {
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>4);
      print_data_download_tab(ref_parameters=>$ref_parameters); 
  }
  elsif($parameters{'tab'} eq "permissions") {
      $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			     page_link=>$page_link,
			     selected_tab=>5);
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
  my (%array_requests, %array_scans, %quantitation_files);
  my $project_id = $sbeams->getCurrent_project_id();
  my ($project_name, $project_tag, $project_status, $project_desc);
  my ($pi_first_name, $pi_last_name, $pi_contact_id, $username);


  # Get all the 2 color array information for this project
  my $n_array_requests = 0;
  my $n_array_scans = 0;
  my $n_array_quantitations = 0;
  if ($project_id > 0) {

  $sql = qq~
  SELECT array_request_id, n_slides, date_created 
  FROM $TBMA_ARRAY_REQUEST
  WHERE project_id = '$project_id'
  AND record_status != 'D'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row(@rows){
	  my @temp_row = @{$row};
	  $array_requests{$temp_row[0]} = "$temp_row[2] ($temp_row[1] slides)";
	  $n_array_requests++;
  }


  $sql = qq~
  SELECT COUNT(ASCAN.array_scan_id) AS 'Scans', 
         COUNT(AQ.array_quantitation_id) AS 'Quantitations'
  FROM $TBMA_ARRAY A
  LEFT JOIN $TBMA_ARRAY_SCAN ASCAN ON (A.array_id = ASCAN.array_id)
  LEFT JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( AQ.array_scan_id = ASCAN.array_scan_id )
  WHERE A.project_id = '$project_id'
  AND A.record_status != 'D'
  ~;

  @rows = $sbeams->selectSeveralColumns($sql);
  ($n_array_scans, $n_array_quantitations) = @{$rows[0]};
  }

  # Check for any Conditions that match this project ID
 
 my $n_condition_count = '';
 
 if ($project_id > 0) {
 	$sql = qq~
		SELECT count(condition_id)
		FROM $TBMA_COMPARISON_CONDITION  
		WHERE project_id = $project_id
		AND record_status != 'D'
		~;
  	($n_condition_count) = $sbeams->selectOneColumn($sql);
  }



  # Count the number of affy chips for this project
  my $n_affy_chips = 0;

  if ($project_id > 0) {
	$sql = qq~ 	SELECT count(afa.affy_array_id)
		   	FROM $TBMA_AFFY_ARRAY afa
		   	JOIN $TBMA_AFFY_ARRAY_SAMPLE afs ON (afa.affy_array_sample_id = afs.affy_array_sample_id)
		   	WHERE afs.project_id = $project_id 
			AND afa.record_status != 'D'
			AND afs.record_status != 'D'
			
		~;
	 ($n_affy_chips) = $sbeams->selectOneColumn($sql);	
  }  

  unless( $args{return_all} ) {
    return ($n_condition_count, $n_array_scans, $n_affy_chips);
  } else {
    return { quants     => $n_array_quantitations, 
             conditions => $n_condition_count,
             requests   => $n_array_requests, 
             scans      => $n_array_scans, 
             chips      => $n_affy_chips
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
 # my $current_contact_id = $sbeams->getCurrent_contact_id();
  #my (%array_requests, %array_scans, %quantitation_files);
  my $project_id = $sbeams->getCurrent_project_id();
  my ($project_name, $project_tag, $project_status, $project_desc);
 # my ($pi_first_name, $pi_last_name, $pi_contact_id, $username);

#print out some project info and return the number of hits for the following data types
 my ($n_condition_count, $n_array_scans, $n_affy_chips) = get_project_info(parameters_ref =>$parameters_ref);
########################################################################################
### Set some of the usful vars
my %resultset = ();
my $resultset_ref = \%resultset;
my %max_widths;
my %rs_params = $sbeams->parseResultSetParams(q=>$q);
my $base_url = "$CGI_BASE_DIR/Microarray/main.cgi";
my $manage_table_url = "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=MA_";

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


my $default_data_type = "AFFY";

my %count_types = ( CONDITION 	=> { 	COUNT => $n_condition_count, # $n_condition_count,
		   			POSITION => 3,
				   },
		   
		   TWO_COLOR	=> { 	COUNT => $n_array_scans,
					POSITION => 2,
				   },
		   
		   AFFY		=> {	COUNT => $n_affy_chips,
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
			page_link	=> "main.cgi",
			selected_tab	=> $selected_tab_numb
	        );
		
		


#########################################################################################	
#### Print the SUMMARY DATA OUT



if ($display_type eq 'TWO_COLOR' ) {


	####  Project Status Section ####
	$sql = qq~
       SELECT A.array_id,A.array_name,
	ARSM1.name AS "Sample1Name",ARSM2.name AS "Sample2Name",
	AR.array_request_id,ARSL.array_request_slide_id,
	AR.date_created AS "date_requested",
	PB.printing_batch_id,PB.date_started AS "date_printed",
	H.hybridization_id,H.date_hybridized,
	ASCAN.array_scan_id,ASCAN.date_scanned,ASCAN.data_flag AS "scan_flag",
	AQ.array_quantitation_id,AQ.date_quantitated,AQ.data_flag AS "quan_flag",
	ARSM1.array_request_sample_id AS "array_request_sample_id1",
	ARSM2.array_request_sample_id AS "array_request_sample_id2"
	FROM $TBMA_ARRAY_REQUEST AR
  	LEFT JOIN $TBMA_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )  
  	LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM1 ON ( ARSL.array_request_slide_id = ARSM1.array_request_slide_id AND ARSM1.sample_index=0)
  	LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM2 ON ( ARSL.array_request_slide_id = ARSM2.array_request_slide_id AND ARSM2.sample_index=1)
  	LEFT JOIN $TBMA_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  	LEFT JOIN $TBMA_PRINTING_BATCH PB ON ( A.printing_batch_id = PB.printing_batch_id )
  	LEFT JOIN $TBMA_HYBRIDIZATION H ON ( A.array_id = H.array_id )
  	LEFT JOIN $TBMA_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  	LEFT JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
      WHERE AR.project_id=$project_id
   	AND ARSL.array_request_slide_id IS NOT NULL
   	AND ( AR.record_status != 'D' OR AR.record_status IS NULL )
   	AND ( A.record_status != 'D' OR A.record_status IS NULL )
   	AND ( PB.record_status != 'D' OR PB.record_status IS NULL )
   	AND ( H.record_status != 'D' OR H.record_status IS NULL )
   	AND ( ASCAN.record_status != 'D' OR ASCAN.record_status IS NULL )
   	--AND ( AQ.record_status != 'D' OR AQ.record_status IS NULL )
 	ORDER BY A.array_name,AR.array_request_id,ARSL.array_request_slide_id
        ~;
       
      

   
	   %url_cols = ('array_name' => "${manage_table_url}array&array_id=%0V",
		 	'Sample1Name' => "${manage_table_url}array_request_sample&array_request_sample_id=%17V",
		 	'Sample2Name' => "${manage_table_url}array_request_sample&array_request_sample_id=%18V",
		 	'date_requested' => "$CGI_BASE_DIR/Microarray/SubmitArrayRequest.cgi?TABLE_NAME=MA_array_request&array_request_id=%4V",
		  	'date_printed' => "${manage_table_url}printing_batch&printing_batch_id=%7V", 
		  	'date_hybridized' => "${manage_table_url}hybridization&hybridization_id=%9V", 
		 	'date_scanned' => "${manage_table_url}array_scan&array_scan_id=%11V", 
			'date_quantitated' => "${manage_table_url}array_quantitation&array_quantitation_id=%14V", 
		 	 );

	   %hidden_cols = ('array_id' => 1,
		     	'array_request_id' => 1,
				'array_request_slide_id' => 1,
		    	'printing_batch_id' => 1,
				'date_printed' => 1,
		    	'hybridization_id' => 1,
		     	'array_scan_id' => 1,
		     	'array_quantitation_id' => 1,
		    	'array_request_sample_id1' => 1,
		     	'array_request_sample_id2' => 1,
			     );


###############################################################################
###Print data for the expression condititons
	
	}elsif($display_type eq 'CONDITION') {
		
		
		$sql = qq~
		   		SELECT condition_id, condition_name, comment
				FROM $TBMA_COMPARISON_CONDITION 
				WHERE project_id = $project_id
				AND record_status != 'D'
			~;
		
		 %url_cols = (
		 	 	'condition_id' => "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=MA_comparison_condition&condition_id=\%0V",
		 	 	'condition_name' => "$CGI_BASE_DIR/Microarray/GetExpression?condition_id=\%0V",
			     );

  		 %hidden_cols = ('array_id' => 1,
		     		);
	
	}elsif($display_type eq 'AFFY') {
		
		$sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;
		$sbeams_affy_groups->setSBEAMS($sbeams);				#set the sbeams object into the affy_groups_object
		
		 $sql = $sbeams_affy_groups->get_affy_arrays_sql(project_id    => $project_id, );
		
		
		
		 %url_cols = (
		 	 	'File_Root' => "${manage_table_url}affy_array&affy_array_id=\%1V",
				'Sample_Tag'	=> "${manage_table_url}affy_array_sample&affy_array_sample_id=\%4V",
			     );

  		 
		 %hidden_cols = ('Sample_ID' => 1,
		     		 'Array_ID' => 1,
				);
	
	}else{
		print FOO "<h2>SORRY THERE IS NOTHING TO SHOW</h2>";
	
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

	if($display_type eq 'AFFY') {
    $sbeams->addResultsetNumbering( rs_ref  => $resultset_ref,
                               colnames_ref => \@column_titles,
                                  list_name => 'Array num' );
  }

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
  	my %parameters	 	= % { $args{param_hash} };		#parameters may be produce when using readResults sets method, instead of reading directly from the cgi param method
	
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
  <TD><A HREF="MIAMEStatus.cgi?tab=array_design">Detailed Information</A></TD>
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
<A HREF="../../doc/Microarray/MIAME_checklist.doc">-Download MIAME Checklist</A>
$LINESEPARATOR
      !;
  return;
}
  

###############################################################################
# print_management_tab
###############################################################################
sub print_management_tab {
  my %args = @_;
  my $SUB_NAME = "print_management_tab";
  
  ## Decode argument list
  my $project_id = $sbeams->getCurrent_project_id();

  ## Define standard variables
  my ($sql, @rows);
  my (%array_requests, $n_array_requests);
  my (%array_scans, $n_array_scans);
  my (%quantitation_files, $n_quantitation_files);

  $sql = qq~
      SELECT array_request_id, n_slides, date_created 
      FROM $TBMA_ARRAY_REQUEST
      WHERE project_id = '$project_id'
      AND record_status != 'D'
      ~;
  @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row(@rows){
      my @temp_row = @{$row};
      $array_requests{$temp_row[0]} = "$temp_row[2] ($temp_row[1] slides)";
      $n_array_requests++;
  }
  
  $sql = qq~
      SELECT ASCAN.array_scan_id, ASCAN.stage_location
      FROM $TBMA_ARRAY_SCAN ASCAN
      JOIN $TBMA_ARRAY A ON ( A.array_id = ASCAN.array_id )
      JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( AQ.array_scan_id = ASCAN.array_scan_id )
      WHERE A.project_id = '$project_id'
      AND ASCAN.record_status != 'D'
      AND A.record_status != 'D'
      AND AQ.record_status != 'D'
      ~;
  %array_scans = $sbeams->selectTwoColumnHash($sql);
  
  $sql = qq~
      SELECT AQ.array_quantitation_id, AQ.stage_location
      FROM $TBMA_ARRAY_SCAN ASCAN
      JOIN $TBMA_ARRAY A ON ( A.array_id = ASCAN.array_id )
      JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( AQ.array_scan_id = ASCAN.array_scan_id )
      WHERE A.project_id = '$project_id'
      AND ASCAN.record_status != 'D'
      AND A.record_status != 'D'
      AND AQ.record_status != 'D'
      ~;
  %quantitation_files = $sbeams->selectTwoColumnHash($sql);
  
  foreach my $key (keys %array_scans) {
      $n_array_scans++;
  }
  foreach my $key (keys %quantitation_files){
      $n_quantitation_files++;
  }

  print qq~
<H1>Project Management:</H1>
<IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="100%" HEIGHT="1">
  ~;

  print qq~
<FORM NAME="requests">
<TABLE>
<TR><TD><B>Array Requests</B></TD></TR>
<TR><TD><SELECT NAME="chooser">
  ~;
  
  foreach my $key(keys %array_requests) {
      print qq~ <OPTION value = "$key">$array_requests{$key} ~;
  }

  print qq~
</SELECT></TD></TR>
<TR>
  <TD>
  <INPUT TYPE="button" name="arButton" value="Go To Record" onClick="viewRequest('old')">
  <INPUT TYPE="button" name="newARButton" value="Add New Record" onClick="viewRequest('new')">
  </TD>
</TR>
</TABLE>
</FORM>
	
<BR>
      
<FORM NAME="images">
<TABLE>
<TR><TD><B>Array Images</B></TD></TR>
<TR><TD><SELECT name="chooser">
        ~;
  
  foreach my $key(keys %array_scans) {
      my $name = $array_scans{$key};
      $name =~ s(^.*/)();
      print qq~ <OPTION value="$key">$name ~;
  }
  
  print qq~
</SELECT></TD></TR>
<TR>
  <TD>
  <INPUT TYPE="button"name="aiButton" value="Go To Record" onClick="viewImage('old')">
  <INPUT TYPE="button"name="newAIButton" value="Add New Record" onClick="viewImage('new')">
  </TD>
</TR>
</TABLE>
</FORM>
      
<BR>

<FORM NAME="quantitations">
<TABLE>
<TR><TD><B>Array Quantitation</B></TD></TR>
<TR><TD><SELECT name="chooser">
        ~;

  foreach my $key (keys %quantitation_files) {
      my $name = $quantitation_files{$key};
      $name =~ s(^.*/)();
      print qq~ <OPTION value="$key">$name ~;
  }
  print qq~
</SELECT></TD></TR>
<TR>
  <TD>
  <INPUT TYPE="button"name="aqButton"value="Go to Record" onClick="viewQuantitation('old')">
  <INPUT TYPE="button"name="newAQButton"value="Add New Record" onClick="viewQuantitation('new')">
  </TD>
</TR>
</TABLE>
</FORM>
$LINESEPARATOR
  ~;
  return;
}
###############################################################################
# print_data_pipeline_tab
###############################################################################
sub print_data_pipeline_tab {
  my %args = @_;
  my $SUB_NAME = "print_data_pipeline_tab";
  
	my $parameters_ref = $args{'parameters_ref'} || die "ERROR[$SUB_NAME] No parameters passed\n";
	
  	my ($n_condition_count, $n_array_scans, $n_affy_chips) = get_project_info(parameters_ref =>$parameters_ref);

	my $html  = '';

#	if(($n_condition_count + $n_array_scans + $n_affy_chips) > 0){
#
  # Changed condition to show affy pipeline iff user can write to project.
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
  <td><a href="$CGI_BASE_DIR/Microarray/bioconductor/upload.cgi">Affy Analysis Pipeline</a></td>
  <td>Analyze Affymetrix CEL files and view the data in a variety of ways.....</td>
 </tr>
END
		if ($n_affy_chips > 0){
			$html .= <<END;
 <tr>
  <td><a href="$CGI_BASE_DIR/Microarray/bioconductor/Add_affy_annotation.cgi">Add Additional Affy Annotation</a></td>
  <td>Very simple web page to add add additional Affy annotation to a file of interest</td>
 </tr>
END
		}
		
		if($n_array_scans > 0){
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
  <td><a href="$CGI_BASE_DIR/Microarray/GetExpression">Get Expression</a></td>
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
# print_two_color_analysis_download_info
###############################################################################
sub print_two_color_analysis_download_info {
  my %args = @_;
  my $SUB_NAME = "print_two_color_analysis_download_info";
  
  ## Decode argument list
  my $project_id = $sbeams->getCurrent_project_id();

  ## Hyperlink processing folders in this directory
  my $output_dir = "/net/arrays/Pipeline/output/project_id/".$project_id;
  opendir (PROJECTDIR, $output_dir);
  my @dir_contents = readdir PROJECTDIR;


 print qq~
<H1>Data Analysis:</H1>
<UL>
  <LI><A HREF="PipelineSetup.cgi">Submit a New Job to the Two Color Analysis Pipeline</A>
  <LI><A HREF="http://db.systemsbiology.net/software/ArrayProcess/" TARGET="_blank">What is the Two Color Data Processing Pipeline?</A>
</UL>
$LINESEPARATOR
      ~;


	print  qq~ 
<BR><BR>
<B>Processing Events:</B><BR>
<TABLE  BORDER>
<TR BGCOLOR="#CCFFFF" BORDERCOLOR="#000000">
  <TD>Directory Title</TD>
	<TD>Processing Date</TD>
</TR>
~;

  foreach my $content (@dir_contents) {
	my $content_dir = "$output_dir/$content";
	next if ($content eq "." || $content eq "..");
	if (-d $content_dir) {
	  my $processed_date = getProcessedDate(file=>$content_dir);
	  print qq ~
<TR>
  <TD ALIGN="right"><A HREF=\"DataAnalysis.cgi?project_id=$project_id&proc_event=$content\">$content</A></TD>
	<TD ALIGN="right">$processed_date</TD>
</TR>
~;
	}
  }
  print "</TABLE>";

  ## Define standard variables
  my ($sql, @rows);

  # Data Analysis Section
  my $output_dir = "/net/arrays/Pipeline/output/project_id/".$project_id;
  my @pdf_list = glob("$output_dir/*.pdf");
  my @log_list = glob("$output_dir/*.log");
  my @sig_list = glob("$output_dir/*.sig");
  my @clone_list = glob("$output_dir/*.clone");
  my @merge_list = glob("$output_dir/*.merge");
  my @rep_list = glob("$output_dir/*.rep");
  my @matrix_list = glob("$output_dir/matrix_output");
  my @zip_file = glob ("$output_dir/*.zip");
  my @tav_list = glob ("$output_dir/*.tav");

 	## Display TAV Options if there are such files
	if ($tav_list[0]) {
	print qq~
<FORM NAME="tavForm" METHOD="GET" ACTION="http://db.systemsbiology.net:8080/microarray/sbeams">
<INPUT TYPE="hidden" NAME="project_id" VALUE="">
<INPUT TYPE="hidden" NAME="selectedFiles" VALUE="">
<INPUT TYPE="hidden" NAME="tab" VALUE="data_pipeline">
<TABLE>
<TR VALIGN="center"><TD><B>MeV Files</B></TD></TR>
<TR>
  <TD>
  <SELECT NAME="tavChooser" MULTIPLE SIZE="10">
        ~;
	foreach my $tav(@tav_list) {
	  my $temp = $tav;
	  $temp=~s(^.*/)();
	  print qq~<OPTION value="$temp">$temp~;
        }
	print qq~
  </SELECT>
  </TD>
  <TD>
  <A HREF="http://www.tigr.org/software/tm4/mev.html" TARGET="_blank"><IMG SRC="../../images/ma_mev_logo.gif"></A>
  </TD>
</TR>
<TR>
  <TD>
  <INPUT TYPE="button" name="mevButton" value="View Selected Files in MeV" onClick="Javascript:startMev($project_id)">
  </TD>
</TR>
<TR><TD></TD></TR>
</TABLE>
</FORM>
~;
      }

      print qq~
<FORM NAME="outputFiles" METHOD="POST">
<TABLE>
      ~;

  ## Display ZIP file Options if there are such files
  if ($zip_file[0]){
      $zip_file[0]=~ s(^.*/)();
      print qq~
<TR>
  <TD>
  <A HREF="ViewFile.cgi?action=download&FILE_NAME=$zip_file[0]"><B>Download zipped file of entire project directory</B></A>
  </TD>
</TR>
 <TR><TD></TD></TR>
 ~;
  }

  ## Display Rep File Options if there are such files
  if ($rep_list[0]){
    print qq~
<TR VALIGN="center"><TD><B>Rep Files</B></TD></TR>
<TR>
  <TD>
  <SELECT NAME="repChooser">
~;
    foreach my $rep(@rep_list) {
      my $temp = $rep;
      $temp =~ s(^.*/)();
      print qq~<OPTION value="$temp">$temp~;
    }
    print qq~
  </SELECT>
  </TD>
</TR>
<TR>
  <TD><INPUT TYPE="button" name="repButton" value="download" onClick="Javascript:actionRepFile()"></TD>
</TR>
<TR><TD></TD></TR>
~;
  }

  ## Display Merge File  Options if there are such files
  if ($merge_list[0]) {
    print qq~
<TR>
  <TD><B>Merge Files</B></TD>
</TR>
<TR>
  <TD>
  <SELECT NAME="mergeChooser">
			 ~;
    foreach my $merge(@merge_list) {
	my $temp = $merge;
	$temp =~ s(^.*/)();
	print qq~<OPTION value="$temp">$temp~;
    }
    print qq~
  </SELECT>
  </TD>
</TR>
<TR>
  <TD><INPUT TYPE="button" name="repButton" value="download" onClick="Javascript:actionMergeFile()"></TD>
</TR>
<TR><TD></TD></TR>
  ~;
  }
	
  ## Display Clone File Options if there are such files
  if ($clone_list[0]) {
    print qq~
<TR>
  <TD><B>Clone Files</B></TD>
</TR>
<TR>
  <TD>
  <SELECT NAME="cloneChooser">
    ~;
    foreach my $clone(@clone_list) {
      my $temp = $clone;
      $temp =~ s(^.*/)();
      print qq~ <OPTION value="$temp">$temp~;
    }
    print qq~
  </SELECT>
  </TD>
</TR>
<TR>
  <TD>
  <INPUT TYPE="button" name="repButton" value="download" onClick="Javascript:actionCloneFile()">
  </TD>
</TR>
<TR><TD></TD></TR>
  ~;
  }

  ## Display Sig File Options if there are such files
  if ($sig_list[0]) {
    print qq~
<TR>
  <TD><B>Sig Files</B></TD>
</TR>
<TR>
  <TD>
  <SELECT NAME="sigChooser">
    ~;
    foreach my $sig(@sig_list) {
      my $temp = $sig;
      $temp =~ s(^.*/)();
      print qq~ <OPTION value="$temp">$temp~;
    }
    print qq~
  </SELECT>
  </TD>
</TR>
<TR>
  <TD><INPUT TYPE="button" name="repButton" value="download" onClick="Javascript:actionSigFile()"></TD>
</TR>
<TR><TD></TD></TR>
  ~;
  }

  ## Display Log Fil Options if there are such files
  if ($log_list[0]) {
    print qq~
<TR><TD><B>Log Files</B></TD></TR>
<TR>
  <TD>
  <SELECT NAME="logChooser">
  ~;

    foreach my $log(@log_list) {
      my $temp = $log;
      $temp =~ s(^.*/)();
      print qq~ <OPTION value="$temp">$temp~;
    }
    print qq~
  </SELECT>
  </TD>
</TR>
<TR>
  <TD>
  <INPUT TYPE="button" name="logButtonView" value="view" onClick="Javascript:actionLogFile('view')">
  <INPUT TYPE="button" name="logButtonGet" value="download" onClick="Javascript:actionLogFile('get')">
  </TD>
</TR>
  ~;
  }

  ## Finish up table
  print qq~
</TABLE>
</FORM>
$LINESEPARATOR
~;

  return;
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
	my $base_url = "$CGI_BASE_DIR/Microarray/main.cgi?tab=data_download";
	my $manage_table_url = "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=MA_";

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
	
	if (exists $parameters{Get_Data}){			#come here if the user has choosen some files to download
		
		if ( $parameters{Get_Data} eq 'GET_AFFY_ARRAY_FILES') {			#value of the button submiting Affy files to be zipped
		
			$sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;
			$sbeams_affy_groups->setSBEAMS($sbeams);			#set the sbeams object into the affy_groups_object
		
			my $date = `date +%F`;						#Get the date with a command line call Example 2004-07-16
			$date =~ s/\s//g;						#remove any white space from the command line call
		
			my $out_file_name    = "${date}_affy_zip_request_$$.zip";	#make the full file name with the process_id on the end to keep it some what unique				
		
			my @files_to_zip = collect_files(parameters => \%parameters);
		
		
   
   ##########################################################################
   ### Print out some nice table showing what is being exported
		
			
		
			my $arrays_id_string =  $parameters{get_all_files}; 		#example '37__CEL,38__CEL,45__CEL,46__CEL,46__XML'
		
			my @array_ids = split /,/, $arrays_id_string;			#remove any redundant affy_ids since one affy_array_id might have multipule file extensions
		
			my %unique_array_ids = map {split /__/} @array_ids;
		
			my $arrays = join ",", sort keys %unique_array_ids;
		
		
			$sql = $sbeams_affy_groups->get_all_affy_info_sql(affy_array_ids => $arrays, );
		
			
			my $tab_results = $sbeams_affy_groups->export_data_array_sample_info(sql =>$sql);
		
 				
			if (@files_to_zip) {						#collect the files and zip and print to stdout
				zip_data(files 		=> \@files_to_zip,
				         zip_file_name	=> $out_file_name,
					 parameters 	=> \%parameters,
			                 affy_groups_obj => $sbeams_affy_groups,
					 array_info	=> $tab_results,
					 );
				
   			}	
    		
    		
			exit;
			
		}elsif($parameters{Get_Data} eq 'SHOW_TWO_COLOR_DATA'){
			print "DO SOMETHING COOL";	
		}
	
  ###############################################################################
  ##Start looking for data that can be downloaded for this project
	
	}else{										#if user has not selected data to download come here
	
		print qq~
		<BR>
		<TABLE WIDTH="100%" BORDER=0>
		  <TR>
		    <TD><h2>Please select data to download</h2></TD></TR>
		~;
	
###Get some summary data for all the data types that can be downloaded	
	#### Count the number of affy chips for this project
		my $n_affy_chips = 0;
		my $n_two_color_runs = 0;
		
		if ($project_id > 0) {
			my $sql = qq~ 	SELECT count(afa.affy_array_id)
		   			FROM $TBMA_AFFY_ARRAY afa, $TBMA_AFFY_ARRAY_SAMPLE afs 
					WHERE afs.project_id = $project_id 
					AND afa.affy_array_sample_id = afs.affy_array_sample_id
			
				~;
			($n_affy_chips) = $sbeams->selectOneColumn($sql);	
 		}
 ##Check to see if there is some TWO_COLOR analysis data
 
 	my $output_dir = "/net/arrays/Pipeline/output/project_id/".$project_id;
  	opendir (PROJECTDIR, $output_dir);
  	my @dir_contents = readdir PROJECTDIR;
	$n_two_color_runs = scalar @dir_contents;
	
	
		print qq~
		  <TR>
		    <TD COLSPAN="2"><B>Number LAffy Chips:  $n_affy_chips</B></TD>
		  </TR>
		  <TR>
		    <TD COLSPAN="2"><B>Number Two Color Analysis Files:  $n_two_color_runs</B></TD>
		  </TR>
		</TABLE>
		<p>
		~;
	#############
	###Add different types of data to download
	
  #################################################################################
  ##Set up the hash to control what sub tabs we might see
	
		my $default_data_type = "AFFY";

		my %count_types = ( AFFY	=> {	COUNT => $n_affy_chips,
		   									POSITION => 0,
		   		   		   	   			},	
							TWO_COLOR 	=> { 	COUNT => $n_two_color_runs,  #$n_condition_count  ##HARD CODE FOR TESTING ONLY
		   										POSITION => 1,
					   		   				},
		   	   	   		);


		my @tabs_names = make_tab_names(%count_types);

	
		
		($display_type, $selected_tab_numb) =	pick_data_to_show (default_data_type    => $default_data_type, 
							    		   		tab_types_hash 	=> \%count_types,
							    		   		param_hash		=> \%parameters,
							   		   );

		my $tabs_exists = display_sub_tabs(	display_type 	=> $display_type,
				       			tab_titles_ref	=>\@tabs_names,
								page_link		=>"main.cgi",
								selected_tab	=> $selected_tab_numb,
	     					    parent_tab  	=> $parameters{'tab'},
	     					   );
	
  #####################################################################################
  ### Show the data that can be downloaded
	
		
		if ($display_type eq 'AFFY'){
		
			$sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;

			@downloadable_file_types = $sbeamsMOD->get_AFFY_FILES;
			@default_file_types = qw(CEL);							  #default file type to turn on the checkbox
			@diplay_files	    = qw(XML RPT INFO JPEG EGRAM_PF.jpg EGRAM_T.jpg EGRAM_F.jpg);		  #files that should have urls constructed to open the file in the browser	
		
			$sbeams_affy_groups->setSBEAMS($sbeams);					  #set the sbeams object into the affy_groups_object
		
			$sql = $sbeams_affy_groups->get_affy_arrays_sql(project_id    => $project_id, ); #return a sql statement to display all the arrays for a particular project
						     			
		 	%url_cols = (
		 	 		#'Array_ID' 	=> "$CGI_BASE_DIR/Microarray/main.cgi?tab=data_download&download_type=AFFY&affy_sample_id=\%0V",
			     		'Sample_Tag'	=> "${manage_table_url}affy_array_sample&affy_array_sample_id=\%3V",
			     	     	'File_Root' 	=> "${manage_table_url}affy_array&affy_array_id=\%0V",
				     	
				     );

  		 
			 %hidden_cols = ('Sample_ID' => 1,
			     		 'Array_ID'  => 1,	
					);
	
	
		}elsif($display_type eq 'TWO_COLOR'){
			print_two_color_analysis_download_info();
			return;
		}else{
			print "<h2>Sorry No Data to download for this project</h2>" ;
			return;
		} 
	}
	
  ###################################################################
  ## Print the data 
		
	unless (exists $parameters{Get_Data}) {
		print $q->start_form(-name =>'download_filesForm',						#start the form to download affy files
				     -action=>"$CGI_BASE_DIR/Microarray/main.cgi",
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
  	
	if ($display_type eq 'AFFY' &! exists $parameters{Get_Data}) {
		
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
                	       	 -value=>'GET_AFFY_ARRAY_FILES');			#will need to change value if other data sets need to be downloaded
	
		
		print $q->reset;
		print $q->end_form;
		
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
	my @file_types    = @{$args{file_types}};	#array ref of columns to add 
	my @default_files = @{$args{default_files}};	#array ref of column names that should be checked
	my @display_files = @{$args{display_files}};	#array ref of columns to make which will have urls to files to open
	
	my $aref = $$resultset_ref{data_ref};		#data is stored as an array of arrays from the $sth->fetchrow_array each row a row from the database holding an aref to all the values
	
	
	
   ########################################################################################
	foreach my $display_file (@display_files){		#First, add the Columns for the files that can be viewed directly
		
		
		foreach my $row_aref (@{$aref} ) {		
			
			my $array_id  = $row_aref->[0];		#need to make sure the query has the array_id in the first column since we are going directly into the array of arrays and pulling out values		
			my $root_name = $row_aref->[1];	
								#loop through the files to make sure they exists.  If they do not don't make a check box for the file
			my $file_exists = check_for_file(	affy_array_id => $array_id, 
								file_root_name =>$root_name, 
								file_extension =>$display_file,
							);
		
			
			my $anchor = '';
			if (($display_file eq 'JPEG' || $display_file =~ /EGRAM/) && $file_exists){
				$anchor = "<a href=View_Affy_files.cgi?action=view_image&affy_array_id=$array_id&file_ext=$display_file>View</a>";
			#print STDERR "ITS A JPEG '$display_file'\n";
			}elsif ($file_exists){			#make a url to open this file
				$anchor = "<a href=View_Affy_files.cgi?action=view_file&affy_array_id=$array_id&file_ext=$display_file>View</a>";
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
		
		foreach my $row_aref (@{$aref} ) {		#serious breach of encapsulation,  !!!! De-reference the data array and pushes new values onto the end
			
			my $array_id  = $row_aref->[0];		#need to make sure the query has the array_id in the first column since we are going directly into the array of arrays and pulling out values			
			my $root_name = $row_aref->[1];
			
								#loop through the files to make sure they exists.  If they do not don't make a check box for the file
			my $file_exists = check_for_file(	affy_array_id => $array_id, 
								file_root_name =>$root_name, 
								file_extension =>$file_ext,
							);
			
			
			my $input = '';
			if ($file_exists){			#make Check boxes for all the files that are present <array_id__File extension> example 48__CHP
				$input = "<input type='checkbox' name='get_all_files' value='${array_id}__$file_ext' $checked>";
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
	
	my $array_id = $args{affy_array_id};
	my $root_name = $args{file_root_name};
	my $file_ext = $args{file_extension};					#Fix me same query is ran to many times, store the data localy
	
	my $sql = qq~  SELECT fp.file_path 
			FROM $TBMA_AFFY_ARRAY afa, $TBMA_FILE_PATH fp 
			WHERE afa.file_path_id = fp.file_path_id
			AND afa.affy_array_id = $array_id
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
	my $sbeams_affy_groups = $args{affy_groups_obj};
	my $zip_file_name   = $args{zip_file_name};
	my $array_info	    = $args{array_info};
	
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
	
	$member = $zip->addString($array_info, "Array_info.txt");
	
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
#Parse out the Affy array id's and query the db to collect the file paths needed to reterieve the data files
#return array of full file paths
###############################################################################
sub collect_files  {
	my $SUB_NAME = 'collect_files';
	
	my %args = @_;
	
	my %parameters =  %{ $args{parameters} };
	
	
	
	my $file_ids = $parameters{get_all_files};
		
	my @all_ids = split /,/, $file_ids; 						 #example '37__CEL,38__CEL,45__CEL,46__CEL'   <array_id__FILE_EXT>,next array
	
	
	if ($VERBOSE > 0 ) {
		print "ARRAY ID's '@all_ids'\n";
	}
	
	
	my %previous_paths = ();
	my @files_to_zip = ();
	
	foreach my $file_id (@all_ids) {
		my ($affy_array_id , $file_ext) = split /__/, $file_id;
		
		my $file_path = '';
		
		if ($DEBUG>0){
			print "ARRAY ID '$affy_array_id' FILE EXT '$file_ext'\n";
		}
		
		
		if (exists $previous_paths{$affy_array_id}) {				#if this array ID has been seen before, pull it out of a temp hash instead of doing a query
			$file_path = "$previous_paths{$affy_array_id}{BASE_PATH}/$previous_paths{$affy_array_id}{ROOT_NAME}.$file_ext";
		
		}else{
			my ($file_root, $file_base_path) = $sbeams_affy_groups->get_file_path_from_id(affy_array_id => $affy_array_id); #method in Microarry::Affy_file_groups.pm
			
			$file_path = "$file_base_path/$file_root.$file_ext";
			
			$previous_paths{$affy_array_id}{BASE_PATH} = $file_base_path;	#put the data into memory for quick access if the same array_id is used, since one root_file name might have multiple extensions
			$previous_paths{$affy_array_id}{ROOT_NAME} = $file_root;
			
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
	
	open ERROR_LOG, ">>AFFY_ZIP_ERROR_LOGS.txt"
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
	my $base_url = "$CGI_BASE_DIR/Microarray/main.cgi";
	my $manage_table_url = "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=MA_";

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





