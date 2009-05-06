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
use vars qw ($sbeams $sbeamsMOD $sbeams_solexa_groups $utilities $q $cgi
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

$sbeamsMOD->setSBEAMS($sbeams);
$utilities->setSBEAMS($sbeams);
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
$PROGRAM_FILE_NAME = 'SampleQC.cgi';
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

print qq~
<script type="text/javascript">
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
#  if (!$current_email) { 
#    $log->error("User $current_username with contact_id $current_contact_id does not have an email in the contact table.");

#die("No email in SBEAMS database.  Please contact an administrator to set your email before using the SolexaTrans Pipeline");
#  }

  print qq!<div id="help_options" style="float: right;"><a href="javascript://;" onclick="toggle_help('help');">Help</a></div>!;
    print qq(<div id="help" style="display:none">);
    print help_gen_tools();
    print "</div>\n";

  print_sample_info_tab(ref_parameters=>$ref_parameters); 
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
# print_sample_info_tab
###############################################################################
sub print_sample_info_tab {
  	my %args = @_;
  
	my @columns = ();
	my $sql = '';
	
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %max_widths;
	my %rs_params = $sbeams->parseResultSetParams(q=>$q);
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/SampleQC.cgi";
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
        my $group_name = 'hoodlab';  # THIS NEEDS TO BE UPDATED WHEN SOLEXATRANS PROJECTS ARE NOT ONLY FOR HOODLAB
	
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
		                  	page_link	    => 'SampleQC.cgi',
		                  	selected_tab	  => $selected_tab_numb,
	                     		parent_tab  	  => $parameters{'tab'},
	                   ) if ( $n_solexa_samples );
	
  #####################################################################################
  ### Show the sample choices
	
		
		if ($display_type eq 'SOLEXA_SAMPLE'){
		  	print $solexa_info; # header info generated earlier

			$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

		        # set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups->setSBEAMS($sbeams);
	
                        if ($parameters{'filter_jobs_slimseq_sample_id'}) {
                          $sql = $sbeams_solexa_groups->get_slimseq_sample_qc_sql(project_id => $project_id,
                                 constraint=>'AND ss.slimseq_sample_id = '.$parameters{'filter_jobs_slimseq_sample_id'}
                                            );
                        } else {
  		          # return a sql statement to display all the arrays for a particular project
			  $sql = $sbeams_solexa_groups->get_slimseq_sample_qc_sql(project_id    => $project_id, );
                        }
						     			
		 	%url_cols = ( 'Sample Tag'	=> "${manage_table_url}solexa_sample&slimseq_sample_id=\%0V",
				     );
                        %hidden_cols = (
                                          "Sample ID" => 1,
                                         'Job Name' => 1,
                                      );

		}else{
			print "<h2>Sorry, no samples qualify for the SolexaTrans pipeline in this project</h2>" ;
			return;
		} 
	} # end if parameters{Get_Data} 
	
  ###################################################################
  ## Print the data 
		
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

 

          append_summary_file_link(resultset_ref => $resultset_ref);
 
   	} # End read or fetch resultset block
	
   	# Set the column_titles to just the column_names, reset first.
   	@column_titles = ();
   	for my $title ( @{$resultset_ref->{column_list_ref}} ) {
    	     push @column_titles, $title;
   	}

	# start a form to print a select box for the sample filtering
#        print $q->start_form(-name =>'filterJobs_Form');
#	print_filter_job_select(resultset_ref=> $resultset_ref);
#        print $q->submit(-name=>'filter_job',
#                         -value=>"Show Job"
#                         );
#        print $q->end_form;

        ###################################################################
  
    	  $log->info( "writing resultset with query parameters ".Dumper(\%parameters) );
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
	
#	unless ($parameters{Get_Data}) {
#		print "<h3>To input parameters for the Pipeline run, click the button below<br>";
		
#		print   $q->br,
#			$q->submit(-name=>'Get_Data',
				#will need to change value if other data sets need to be run
#                	       	 -value=>'RUN_PIPELINE');			
	
		
#		print $q->reset;
		print $q->endform;
		
#	}
	
	
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
# append_summary_file_link
#
# Append on the more columns of data which can then be shown via the displayResultSet method
###############################################################################

sub append_summary_file_link {
	my %args = @_;
	
	my $resultset_ref = $args{resultset_ref};
	
	#data is stored as an array of arrays from the $sth->fetchrow_array 
	# each row is a row from the database holding an aref to all the values
	my $aref = $$resultset_ref{data_ref};		
	
  	my $id_idx = $resultset_ref->{column_hash_ref}->{Sample_ID};

   	########################################################################################
 	my $anchor = '';
 	my $pad = '&nbsp;&nbsp;&nbsp;';
	foreach my $row_aref (@{$aref} ) {

	  #need to make sure the query has the slimseq_sample_id in the first column 
	  #    since we are going directly into the array of arrays and pulling out values
	  my $slimseq_sample_id  = $row_aref->[$id_idx];		
          my $view_summary = qq~<a href="View_Solexa_files.cgi?action=view_html&slimseq_sample_id=$slimseq_sample_id&file_type=SUMMARY" target="_summary">View Summary File</a>~;
			
          push @$row_aref, $view_summary;		#append on the new data	
	} # end foreach row
		
        if ( 1 ){
	    #need to add the column headers into the resultset_ref since DBInterface display results will reference this
	    push @{$resultset_ref->{column_list_ref}} , "Summary File"; 
		
	    #need to append a value for every column added otherwise the column headers will not show
	    append_precision_data($resultset_ref);				   
        }
	
	
}

sub print_filter_job_select {
	my %args = @_;
	my $resultset_ref = $args{resultset_ref};
	
	#data is stored as an array of arrays from the $sth->fetchrow_array 
	# each row is a row from the database holding an aref to all the values
	my $aref = $$resultset_ref{data_ref};		
	
  	my $id_idx = $resultset_ref->{column_hash_ref}->{Sample_ID};
        my $samplename_idx = $resultset_ref->{column_hash_ref}->{"Full_Sample_Name"};
        print "<SELECT name=\"filter_jobs_slimseq_sample_id\">\n";
        my %samples;
        foreach my $row_aref(@$aref) {
          my $slimseq_sample_id = $row_aref->[$id_idx];
          my $slimseq_sample_name = $row_aref->[$samplename_idx];
          next if ($samples{$slimseq_sample_id});
          print "<OPTION value=\"$slimseq_sample_id\">$slimseq_sample_name</OPTION>";
          $samples{$slimseq_sample_id} = $slimseq_sample_name;
        }
        print "</SELECT>\n";

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
         $limit_clause = $sbeams->buildLimitClause(row_limit=>$parameters{row_limit});


                #### Set the column_titles to just the column_names
                @column_titles = @{$resultset_ref->{column_list_ref}};

                #### Display the resultset
                $sbeams->displayResultSet(      resultset_ref=>$resultset_ref,
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

