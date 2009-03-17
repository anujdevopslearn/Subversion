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


use SBEAMS::SolexaTrans::Solexa;
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
$PROGRAM_FILE_NAME = 'dataDownload.cgi';
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
 	if ($parameters{Get_Data} eq 'GET_SOLEXA_FILES') {
  	
                #skip printing the headers since we will be piping out binary data and will use different Content headers
		print_data_download_tab(ref_parameters => \%parameters);	
   	
   	}else {
                #print out results sets in different formats
    		if  ($parameters{output_mode} =~ /xml|tsv|excel|csv/){		
      			print_output_mode_data(parameters_ref=>\%parameters);
		}else{
    
       			$sbeamsMOD->printPageHeader();
       			print_javascript();
			$sbeamsMOD->updateCheckBoxButtons_javascript();
       			handle_request(ref_parameters=>\%parameters);
       			$sbeamsMOD->printPageFooter();
		}
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

  if ($parameters{slimseq_sample_id}) {
    print_detailed_download_tab(ref_parameters=>$ref_parameters);
  } else {
    print_data_download_tab(ref_parameters=>$ref_parameters); 
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
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/dataDownload.cgi";
	my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

	my %url_cols      = ();
	my %hidden_cols   = ();
	my $limit_clause  = '';
	my @column_titles = ();
  	
	my ($display_type, $selected_tab_numb);
  	
	my $solexa_info;	
	my @downloadable_file_types = ();
	my @default_file_types      = ();
	my @display_files  = ();
  	
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
  ##First check to see if the user already has selected some data to download
	
        #come here if the user has chosen some files to download
	if (exists $parameters{Get_Data}){			
		
                #value of the button submiting Solexa files to be zipped
		if ( $parameters{Get_Data} eq 'GET_SOLEXA_FILES') {			
		
			$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
                        #set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups->setSBEAMS($sbeams);			
		
                        #Get the date with a command line call Example 2004-07-16
			my $date = `date +%F`;						
			$date =~ s/\s//g;						
		
                        #make the full file name with the process_id on the end to keep it some what unique 	
			my $out_file_name    = "${date}_solexa_sample_zip_request_$$.zip";	
		
			my @files_to_zip = collect_files(parameters => \%parameters);
                        $log->error("files to zip after collect ".join(", ",@files_to_zip));
   
                        ##########################################################################
                        ### Print out some nice table showing what is being exported
		
			my $slimseqs_id_string =  $parameters{get_all_files};
		
                        #remove any redundant fcl_ids since one solexa_flow_cell_lane_id might have multiple file extensions
			my @slimseq_sample_ids = split /,/, $slimseqs_id_string;
		
			my %unique_slimseq_sample_ids = map {split /__/} @slimseq_sample_ids;
		
			my $slimseqs = join ",", sort keys %unique_slimseq_sample_ids;
		
			$sql = $sbeams_solexa_groups->get_download_info_sql(slimseq_sample_ids => $slimseqs );
			
			my $tab_results = $sbeams_solexa_groups->export_data_sample_info(sql =>$sql);

			if (@files_to_zip) {						#collect the files and zip and print to stdout
				zip_data(files 		=> \@files_to_zip,
				         zip_file_name	=> $out_file_name,
					 parameters 	=> \%parameters,
			                 solexa_groups_obj => $sbeams_solexa_groups,
					 sample_info	=> $tab_results,
					 );
				
   			}	
    		
    		
			exit;
			
		}elsif($parameters{Get_Data} eq 'SHOW_TWO_COLOR_DATA'){
			print STDERR "DO SOMETHING COOL";	
		}
	
        ###############################################################################
        ##Start looking for data that can be downloaded for this project
	
        #if user has not selected data to download come here
	}else{										
	
          ###Get some summary data for all the data types that can be downloaded	
	  #### Count the number of solexa runs for this project
	  my $n_solexa_samples = 0;
		
	  if ($project_id > 0) {
	     my $sql = qq~ 
		      SELECT count(ss.solexa_sample_id)
		  	FROM $TBST_SOLEXA_SAMPLE ss 
		  	WHERE ss.project_id = $project_id 
      			AND ss.record_status <> 'D'
			~;
	    ($n_solexa_samples) = $sbeams->selectOneColumn($sql);	
 	  }
    
          my $solexa_info =<<"    END";
		<BR>
		<TABLE WIDTH="75%" BORDER=0>
		  <TR>
		   <TD>
        <B>
        This page shows the<FONT COLOR=RED> $n_solexa_samples </FONT> Solexa
        samples in this project.  Use the checkboxes underneath the individual
        file types to select one or more files for download, then press the 
        <span style="white-space: nowrap">"GET SOLEXA FILES"</span> button at the bottom of the page.  The checkboxes
        in the column headings can be used to toggle all the checkboxes for a
        particular file type.  All selected files will be packaged into a zip
        archive, to make the download easier.<br><br>

        ELAND files are VERY LARGE.  It is recommended that you use the 'Explore' link to 
        locate these files on the shared filesystem and manipulate them from that location.<br><br>

        Each Flow Cell has a summary file that includes information for all
        of the lanes of that Flow Cell.  Therefore, if samples below have the
        same Flow Cell, the Summary 'View' link will point to the same file.<br><br>

        The "Explore" link only works in Internet Explorer or if you have an addon for
        Firefox called "IE Tab" that is available <a href="https://addons.mozilla.org/en-US/firefox/addon/1419">here</a>.
        If you have that addon, right click on the link and click "Open Link in IE Tab".
        </B> 
       </TD></TR>
       <TR><TD></TD></TR>
		</TABLE>
    END

	
	#############
	###Add different types of data to download
	
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
	                  	page_link	    => 'dataDownload.cgi',
	                  	selected_tab	  => $selected_tab_numb,
                     		parent_tab  	  => $parameters{'tab'},
                   ) if ( $n_solexa_samples );
	
      #####################################################################################
      ### Show the data that can be downloaded
	
		
      if ($display_type eq 'SOLEXA_SAMPLE'){
	 print $solexa_info;

	 $sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

	 @downloadable_file_types = $sbeamsMOD->get_SOLEXA_FILES;
	 @default_file_types = qw();  #default file type to turn on the checkbox

	 @display_files = qw(RawDataPath SUMMARY ELAND);
		
         # set the sbeams object into the solexa_groups_object
	 $sbeams_solexa_groups->setSBEAMS($sbeams);
		
         # return a sql statement to display all the arrays for a particular project
	 $sql = $sbeams_solexa_groups->get_slimseq_sample_sql(project_id    => $project_id, );
						     			
	 %url_cols = ( 'Sample_Tag'	=> "${manage_table_url}solexa_sample&slimseq_sample_id=\%0V",
				          );
  		 
	 %hidden_cols = ( 
		    	 );
	
	
      }else{
			print "<h2>Sorry No Data to download for this project</h2>" ;
			return;
      } 
    } # end else parameters{Get_Data}
	
    ###################################################################
    ## Print the data 
		
    unless (exists $parameters{Get_Data}) {
      # start the form to download solexa files
		print $q->start_form(-name =>'download_filesForm');
				     			
      #make sure to include the name of the tab we are on
      print $q->hidden(-name=>'tab',									
  	      	       -value=>'parameters{tab}',
		      );
      ###################################################################
      ## Make a small table to show some checkboxes so a user can click once to turn
      ##  on or off all the files in a particular group	
		
      print "<br>";
		
		
    }

    # get field->checkbox HTML for selecting files for download form
    my $cbox = $sbeamsMOD->get_file_cbox( box_names => \@downloadable_file_types, 
                                          default_file_types => \@default_file_types );

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

#        $sbeams->addResultsetNumbering( rs_ref       => $resultset_ref, 
#                                        colnames_ref => \@column_titles,
#                                        list_name => 'Flow Cell Lane Number' );	
  
 
      ####################################################################
      ## Need to Append data onto the data returned from fetchResultsSet in order 
      # to use the writeResultsSet method to display a nice html table
  	
      if ($display_type eq 'SOLEXA_SAMPLE' &! exists $parameters{Get_Data}) {
        append_new_data( resultset_ref => $resultset_ref, 
                        #append on new values to the data_ref foreach column to add
		        file_types    => \@downloadable_file_types,
			default_files => \@default_file_types,
                        display_files => \@display_files,       #Names for columns which will have urls to pop open files
                        file_checkbox => $cbox
		       );
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
      print "<h3>To start the download click the button below<br>";
      print "<h3>A single Zip file will be downloaded to a location of your choosing *</h3>";
		
		
      print   $q->br,
	      $q->submit(-name=>'Get_Data',
                    	 -value=>'GET_SOLEXA_FILES'); #will need to change value if other data sets need to be downloaded
	
		
      print $q->reset;
      print $q->endform;
		
    }
	
	
    #### Display the resultset controls
#    $sbeams->displayResultSetControls(resultset_ref=>$resultset_ref,
#		    		      query_parameters_ref=>\%parameters,
#				      rs_params_ref=>\%rs_params,
#				      base_url=>$base_url,
#				     );
	
}

###############################################################################
# print_detailed_download_tab
###############################################################################
sub print_detailed_download_tab {
  	my %args = @_;
  
  
  	my $resultset_ref = '';
	my @columns = ();
	my $sql = '';
	
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %max_widths;
	my %rs_params = $sbeams->parseResultSetParams(q=>$q);
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/dataDownload.cgi";
	my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

	my %url_cols      = ();
	my %hidden_cols   = ();
	my $limit_clause  = '';
	my @column_titles = ();
  	
	my ($display_type, $selected_tab_numb);
  	
	my $solexa_info;	
	my @downloadable_file_types = ();
	my @default_file_types      = ();
	my @display_files  = ();
  	
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
  ##First check to see if the user already has selected some data to download
	
        #come here if the user has chosen some files to download
	if (exists $parameters{Get_Data}){			
		
                #value of the button submiting Solexa files to be zipped
		if ( $parameters{Get_Data} eq 'GET_SOLEXA_FILES') {			
		
			$sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
                        #set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups->setSBEAMS($sbeams);			
		
                        #Get the date with a command line call Example 2004-07-16
			my $date = `date +%F`;						
			$date =~ s/\s//g;						
		
                        #make the full file name with the process_id on the end to keep it some what unique 	
			my $out_file_name    = "${date}_solexa_sample_zip_request_$$.zip";	
		
			my @files_to_zip = collect_files(parameters => \%parameters);
                        $log->error("files to zip after collect ".join(", ",@files_to_zip));
   
                        ##########################################################################
                        ### Print out some nice table showing what is being exported
		
			my $slimseqs_id_string =  $parameters{get_all_files};
		
                        #remove any redundant sample_ids 
			my @slimseq_sample_ids = split /,/, $slimseqs_id_string;
			my %unique_slimseq_sample_ids = map {split /__/} @slimseq_sample_ids;
			my $slimseqs = join ",", sort keys %unique_slimseq_sample_ids;
		
			$sql = $sbeams_solexa_groups->get_download_info_sql(slimseq_sample_ids => $slimseqs );
			
			my $tab_results = $sbeams_solexa_groups->export_data_sample_info(sql =>$sql);

                        #collect the files and zip and print to stdout
			if (@files_to_zip) {						
				zip_data(files 		=> \@files_to_zip,
				         zip_file_name	=> $out_file_name,
					 parameters 	=> \%parameters,
			                 solexa_groups_obj => $sbeams_solexa_groups,
					 sample_info	=> $tab_results,
					 );
				
   			}	
    		
			exit;
			
		}
	
        ###############################################################################
        ##Start looking for data that can be downloaded for this project
	
        #if user has not selected data to download come here
	}else{										
	  ###Get some summary data for all the data types that can be downloaded	
	  #### Count the number of solexa runs for this project
	  my $n_solexa_samples = 0;
		
	  if ($project_id > 0) {
	     my $sql = qq~ 
		      SELECT count(ss.solexa_sample_id)
		  	FROM $TBST_SOLEXA_SAMPLE ss 
		  	WHERE ss.project_id = $project_id 
      			AND ss.record_status <> 'D'
			~;
	    ($n_solexa_samples) = $sbeams->selectOneColumn($sql);	
 	  }
 
          my $solexa_info =<<"    END";
		<BR>
		<TABLE WIDTH="75%" BORDER=0>
		  <TR>
		   <TD>
        <B>
        Use the checkboxes underneath the individual
        file types to select one or more files for download, then press the 
        <span style="white-space: nowrap">"GET SOLEXA FILES"</span> button at the bottom of the page.  The checkboxes
        in the column headings can be used to toggle all the checkboxes for a
        particular file type.  All selected files will be packaged into a zip
        archive, to make the download easier.<br><br>

        ELAND files are VERY LARGE.  It is recommended that you use the 'Explore' link to 
        locate these files on the shared filesystem and manipulate them from that location.<br><br>

        Each Flow Cell has a summary file that includes information for all
        of the lanes of that Flow Cell.  Therefore, if samples below have the
        same Flow Cell, the Summary 'View' link will point to the same file.<br><br>

        The "Explore" link only works in Internet Explorer or if you have an addon for
        Firefox called "IE Tab" that is available <a href="https://addons.mozilla.org/en-US/firefox/addon/1419">here</a>.
        If you have that addon, right click on the link and click "Open Link in IE Tab".
        </B> 
       </TD></TR>
       <TR><TD></TD></TR>
		</TABLE>
    END

	
	#############
	###Add different types of data to download
	
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
	                  	page_link	    => 'dataDownload.cgi',
	                  	selected_tab	  => $selected_tab_numb,
                     		parent_tab  	  => $parameters{'tab'},
                   );
	
      #####################################################################################
      ### Show the data that can be downloaded
      if ($display_type eq 'SOLEXA_SAMPLE'){
	 print $solexa_info;

	 $sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;

	 @downloadable_file_types = $sbeamsMOD->get_SOLEXA_FILES;
	 @default_file_types = qw();  #default file type to turn on the checkbox

	 @display_files = qw(RawDataPath SUMMARY ELAND);
		
         # set the sbeams object into the solexa_groups_object
	 $sbeams_solexa_groups->setSBEAMS($sbeams);
		
         # return a sql statement to display all the arrays for a particular project
	 $sql = $sbeams_solexa_groups->get_slimseq_sample_sql(project_id    => $project_id, 
                                                              constraint => "and ss.slimseq_sample_id = ".$parameters{"slimseq_sample_id"},
                                                             );
						     			
	 %url_cols = ( 'Sample_Tag'	=> "${manage_table_url}solexa_sample&slimseq_sample_id=\%0V",
				          );
  		 
	 %hidden_cols = ( 
		    	 );
	
	
      }else{
			print "<h2>Sorry No Data to download for this project</h2>" ;
			return;
      } 
    } # end else parameters{Get_Data}
	
    ###################################################################
    ## Print the data 
		
    unless (exists $parameters{Get_Data}) {
      # start the form to download solexa files
      print $q->start_form(-name =>'download_filesForm');
				     			
      #make sure to include the name of the tab we are on
      print $q->hidden(-name=>'tab',									
  	      	       -value=>'parameters{tab}',
		      );
      ###################################################################
      ## Make a small table to show some checkboxes so a user can click once to turn
      ##  on or off all the files in a particular group	
      print "<br>";
    }

    # get field->checkbox HTML for selecting files for download form
    my $cbox = $sbeamsMOD->get_file_cbox( box_names => \@downloadable_file_types, 
                                          default_file_types => \@default_file_types );

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

#        $sbeams->addResultsetNumbering( rs_ref       => $resultset_ref, 
#                                        colnames_ref => \@column_titles,
#                                        list_name => 'Flow Cell Lane Number' );	
  
 
      ####################################################################
      ## Need to Append data onto the data returned from fetchResultsSet in order 
      # to use the writeResultsSet method to display a nice html table
  	
      if ($display_type eq 'SOLEXA_SAMPLE' &! exists $parameters{Get_Data}) {
        append_new_data( resultset_ref => $resultset_ref, 
                        #append on new values to the data_ref foreach column to add
		        file_types    => \@downloadable_file_types,
			default_files => \@default_file_types,
                        display_files => \@display_files,       #Names for columns which will have urls to pop open files
                        file_checkbox => $cbox
		       );
      }
  
      ###################################################################


      #### Set the column_titles to just the column_names
      @column_titles = @{$resultset_ref->{column_list_ref}};

      #data is stored as an array of arrays from the $sth->fetchrow_array
      # each row is a row from the database holding an aref to all the values
      # this retrieves one row, so the first row is all we need to retrieve
      my $aref = $$resultset_ref{data_ref}->[0];
      my %new_results;
      my %new_url_cols = ();
      my %new_hidden_cols = ();
      my @new_column_titles = ('Parameter', 'Value');
      my %color_scheme = ();

      $new_results{precisions_list_ref} = [50,50];
      $new_results{column_list_ref} = \@new_column_titles;

      for (my $i=0; $i < scalar (@$aref); $i++) {
#      print $column_titles[$i]." val ".$aref->[$i]."<br>";
        my @info = ($column_titles[$i],$aref->[$i]);
        push(@{$new_results{data_ref}}, \@info);
      }

      my @row_color_list = ("#E0E0E0","#C0D0C0");
      %color_scheme = (
                        header_background => '#0000A0',
                        change_n_rows => 1,
                        color_list => \@row_color_list,
                      );

  
      $log->info( "writing" );
      #### Store the resultset and parameters to disk resultset cache
      $rs_params{set_name} = "SETME";
      $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
		  	      resultset_ref=>\%new_results,
			      query_parameters_ref=>\%parameters,
			      resultset_params_ref=>\%rs_params,
  			      query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
	  		     );

      $resultset_ref = \%new_results;

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
      print "<h3>To start the download click the button below<br>";
      print "<h3>A single Zip file will be downloaded to a location of your choosing *</h3>";
		
		
      print   $q->br,
	      $q->submit(-name=>'Get_Data',
                    	 -value=>'GET_SOLEXA_FILES'); #will need to change value if other data sets need to be downloaded
	
		
      print $q->reset;
      print $q->endform;
		
    }
	
	
    #### Display the resultset controls
#    $sbeams->displayResultSetControls(resultset_ref=>$resultset_ref,
#		    		      query_parameters_ref=>\%parameters,
#				      rs_params_ref=>\%rs_params,
#				      base_url=>$base_url,
#				     );
	
}

sub postProcessResultset {
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
	my $cbox = $args{file_checkbox} || {};
	
        #data is stored as an array of arrays from the $sth->fetchrow_array
        #each row a row from the database holding an aref to all the values
	my $aref = $$resultset_ref{data_ref};		
	
        my $id_idx = $resultset_ref->{column_hash_ref}->{Sample_ID};
	
        my @new_data_ref;
        ########################################################################################
	foreach my $display_file (@display_files){		#First, add the Columns for the files that can be viewed directly
		
          my $anchor = '';
          my $pad = '&nbsp;&nbsp;&nbsp;';
	  foreach my $row_aref (@{$aref} ) {		

              my $checked = ( grep /$display_file/, @default_files ) ? 'checked' : '';
      
			
              #need to make sure the query has the slimseq_sample_id in the first column
              #since we are going directly into the array of arrays and pulling out values		
	      my $slimseq_sample_id  = $row_aref->[$id_idx];

	      #loop through the files to make sure they exists.  If they do not don't make a check box for the file
	      my $file_exists = check_for_file(	slimseq_sample_id => $slimseq_sample_id, 
						file_type =>$display_file,
					      );

              my $link = "<input type='checkbox' name='get_all_files' $checked value='VALUE_TAG' >";
              my $value = $slimseq_sample_id . '__' . $display_file;
              $link =~ s/VALUE_TAG/$value/;

	      if (($display_file eq 'JPEG') && $file_exists){
	        $anchor = "<a href=View_Solexa_files.cgi?action=view_image&slimseq_sample_id=".$slimseq_sample_id.
                          "&file_type=$display_file>View</a>";
                $anchor .= "$pad $link" if $display_file;
		#print STDERR "ITS A JPEG '$display_file'\n";
              } elsif (($display_file eq 'ELAND') && $file_exists) {
                $anchor = "Download";
                $anchor .= "$pad $link" if $display_file;
	      } elsif (($display_file eq 'RawDataPath') && $file_exists) {
		my $raw_path = $sbeams_solexa_groups->get_file_path_from_id(slimseq_sample_id => $slimseq_sample_id,
                                                                            file_type => 'RAW');
                my $server = $sbeams_solexa_groups->get_server(file_path => $raw_path);
                if ($server =~ /ERROR/) { die $server; } 
                $raw_path =~ s/^\///g;
                my @dirs = split(/\//, $raw_path);
                shift(@dirs); # remove /solexa
                unshift(@dirs, $server);  # add server
                my $flow_cell = pop(@dirs); # remove last entry and save
                push(@dirs, 'SolexaTrans');
                push(@dirs, $flow_cell);
                my $path = join("\\", @dirs);
                $anchor = '<a href="file://///'.$path.'">Explore</a>';
              }elsif ($file_exists){			#make a url to open this file
		$anchor = ( $display_file eq 'TXT' ) ? '' :
                    "<a href=View_Solexa_files.cgi?action=view_file&slimseq_sample_id=$slimseq_sample_id&file_type=$display_file>View</a>"; 
                $anchor .= "$pad $link" if $display_file;
	      }else{
		$anchor = "No File";
	      }
			
	      push @$row_aref, $anchor;		#append on the new data	
	  } # end foreach row
		
          if ( 1 ){
            #add on column header for each of the file types
            #need to add the column headers into the resultset_ref since DBInterface display results will reference this
	    push @{$resultset_ref->{column_list_ref}} , "$display_file";  
		
            #need to append a value for every column added otherwise the column headers will not show
            append_precision_data($resultset_ref);				   
          }
	} # end foreach display_file
	
          
	
   ########################################################################################
	
#	foreach my $file_type (@file_types) {			#loop through the column names to add checkboxes
#          my $checked = '';
#		if ( grep {$file_type eq $_} @default_files) {
#			$checked = "CHECKED";
#		}


		
#		foreach my $row_aref (@{$aref} ) {		#serious breach of encapsulation,  !!!! De-reference the data array and pushes new values onto the end
			
#			my $solexa_sample_id  = $row_aref->[$id_idx];		#need to make sure the query has the solexa_run_id in the first column since we are going directly into the array of arrays and pulling out values			
#			my $root_name = $row_aref->[$file_idx];
			
								#loop through the files to make sure they exists.  If they do not don't make a check box for the file
#			my $file_exists = check_for_file(	solexa_sample_id => $solexa_sample_id, 
#								file_typeension =>$file_ext,
#							);
			
			
#			my $input = '';
#			if ($file_exists){			#make Check boxes for all the files that are present <array_id__File extension> example 48__CHP
#$input = "<input type='checkbox' name='get_all_files' value='${solexa_sample_id}__$file_type' $checked>";
#			}else{
#				$input = "No File";
#			}
			
#	push @$row_aref, $input;		#append on the new data		
			
			
#		}
	
#push @{$resultset_ref->{column_list_ref}} , "$file_type";	#add on column header for each of the file types
										#need to add the column headers into the resultset_ref since DBInterface display results will refence this
		
#		append_precision_data($resultset_ref);				#need to append a value for every column added otherwise the column headers will not show
	
#	}
	
}
###############################################################################
# check_for_file_existance
#
# Pull the file base path from the database then do a file exists on the full file path
###############################################################################
sub check_for_file {
	my %args = @_;
	
	my $slimseq_sample_id = $args{slimseq_sample_id};
	my $solexa_sample_id = $args{solexa_sample_id};
	my $file_type = $args{file_type};					#Fix me same query is ran to many times, store the data localy
	if (  (!$slimseq_sample_id || !$solexa_sample_id) && !$file_type) { return "ERROR: Must supply 'solexa_sample_id' or 'slimseq_sample_id' and 'file_ext'\n"; }

        my $where;
        if ($slimseq_sample_id && !$solexa_sample_id) {
           $where = "WHERE ss.slimseq_sample_id = '$slimseq_sample_id'";
        } elsif (!$slimseq_sample_id && $solexa_sample_id) {
           $where = "WHERE ss.solexa_sample_id = '$solexa_sample_id'";
        } else {
           $where = "WHERE ss.slimseq_sample_id = '$slimseq_sample_id'";
        }

	my $path;
	if ($file_type eq 'ELAND') {
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
	} elsif ($file_type eq 'RawDataPath') {
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
	} elsif ($file_type eq 'SUMMARY') {
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
	}

#	my $file_path = "$path/$root_name.$file_type";
	
#	$log->debug("FILE PATH '$file_path'");
	$log->error("FILE PATH '$path'");
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
	my $sample_info	    = $args{sample_info};

	if ($VERBOSE > 0 ) {
		print "FILES TO ZIP '@files_to_zip'\n";
	}
	
	my $zip = Archive::Zip->new();
	my $compressed_size = '';
	my $uncompressed_size = '';

        my $dir_name = $sbeams->getCurrent_project_name() . '_files/';
        $dir_name =~ s/\s/_/g;

	my $member = $zip->addDirectory( $dir_name );
        $compressed_size   += $member->compressedSize();
        $uncompressed_size += $member->uncompressedSize();
	
	foreach my $file_path ( @files_to_zip){
		
	   my ($file, $dir, $ext) = fileparse( $file_path) ;
           unless ( -e $file_path ) {
              $log->error( "File $file_path does not exist" );
              next;
            }
            # don't use the full file path for the file names, just use the file name
	    my $member = $zip->addFile( $file_path, "$dir_name$file$ext");
            unless ( ref $member ) {
              $log->error( "Add to zip file failed for $file_path" );
              next;
            }
	
            $log->error("filepath after addfiile $file_path" );
	    $compressed_size   += $member->compressedSize();
	    $uncompressed_size += $member->uncompressedSize();
	} # foreach filepath
	
	$member = $zip->addString($sample_info, $dir_name . 'Sample_info.txt');
	
	print "Content-Disposition: filename=$zip_file_name\n";
        # Was only a (bad) estimate, seemed to cause Firefox significant grief
        #	print "Content-Length: $compressed_size\n"; 
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
#Parse out the Solexa fcl id's and query the db to collect the file paths needed to reterieve the data files
#return array of full file paths
###############################################################################
sub collect_files  {
	my $SUB_NAME = 'collect_files';
	my %args = @_;
	
	my %parameters =  %{ $args{parameters} };
	my $file_ids = $parameters{get_all_files};

	my @all_ids = split /,/, $file_ids;
	
	if ($VERBOSE > 0 ) {
		print "ID's '@all_ids'\n";
	}
	
	my %previous_paths = ();
	my @files_to_zip = ();
	
	foreach my $file_id (@all_ids) {
		my ($sample_id , $file_type) = split /__/, $file_id;
		
		my $file_path = '';
		
		if ($DEBUG>0){
			print "SLIMSEQ SAMPLE ID '$sample_id' FILE TYPE '$file_type'\n";
		}
		
                #if this sample ID has been seen before, pull it out of a temp hash instead of doing a query
#		if (exists $previous_paths{$solexa_sample_id}{$file_type} && $previous_paths{$solexa_sample_id}{$file_type}) {
#		  $file_path = "$previous_paths{$solexa_sample_id}{$file_type}";
#		}else{
                  #method in SolexaTrans::Solexa_file_groups.pm
		  my ($file_path) = $sbeams_solexa_groups->get_file_path_from_id(slimseq_sample_id => $sample_id,
                                                                                 file_type => $file_type,
                                                                                ); 
			
                  #put the data into memory for quick access if the same solexa_sample_id is used
#		  $previous_paths{$solexa_sample_id}{$file_type} = $file_path;	
#		}	
	        $log->error("file_path $file_path in collect_files");	

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
	my $base_url = "$CGI_BASE_DIR/SolexaTrans/dataDownload.cgi";
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



