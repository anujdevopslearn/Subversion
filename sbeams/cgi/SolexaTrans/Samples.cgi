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
use UploadPipeline;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $sbeams_solexa_groups $utilities $q 
             $current_contact_id $current_username $current_email
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS $DISPLAY_SUMMARY);
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX qw(strftime);

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

# test code commented out for testing the generation of the perl script
#            my $perl_script = generate_perl(
#                                              "Sample_ID" => '92',
#                                              "SPR_ID" => '71',
#                                              "ELAND_Output_File" => '/solexa/hood/DTRA_lung/081203_HWI-EAS427_FC30JRDAAXX/Data/IPAR_1.01/Bustard1.9.5_10-12-2008_sbsuser/GERALD_10-12-2008_sbsuser/s_6_export.txt',
#                                              "Raw_Data_Path" => '/solexa/hood/DTRA_lung/081203_HWI-EAS427_FC30JRDAAXX/Data/IPAR_1.01/Bustard1.9.5_10-12-2008_sbsuser/GERALD_10-12-2008_sbsuser/',
#                                              "Tag_Length" => '18',
#                                              "Genome" => '1,2,3',
#                                              "Organism" => 'Human',
#                                              "Motif" => 'GATC',
#                                              "Jobname" => 'test',
#                                              "Lane" => '6',
#                                              "Truncate" => '2',
#                                              "Patman_max_mismatches"=>'2',
#                                              "Fuse"=>100,
#                                              "Output_Dir" => '/users/dmauldin/core/data_analysis/delivery/test',
#                                              "Analysis_ID" => '26',
#                              ); 

#print $perl_script;

#exit;

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

function confirmSubmit() {
  var agree = confirm("This job has been previously run.  Press OK to continue to job submission, or cancel to be redirected to the results page for this job.");
  if (agree) 
    return true;
  else
    return false;
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

  if ($parameters{jobname} && !$parameters{step}) {
    $parameters{step} = 2;
  }

  print qq!<div id="help_options" style="float: right;"><a href="javascript://;" onclick="toggle_help('help');">Help</a></div>!;
    print qq(<div id="help" style="display:none">);
    print help_gen_jobs();
    print "</div>\n";

  if (!$parameters{step} || $parameters{step} == 1) {
    print_sample_selection(ref_parameters=>$ref_parameters);
  } elsif ($parameters{step} == 2) {
    if ($parameters{jobname}) {
      $ref_parameters = get_form_data(ref_parameters=>$ref_parameters);
    } else {
      $ref_parameters = get_form_defaults(ref_parameters=>$ref_parameters);
    }
    print_pipeline_form(ref_parameters=>$ref_parameters);
  } elsif ($parameters{step} == 3) {
    start_pipeline_jobs(ref_parameters=>$ref_parameters); 
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
    
	 	$solexa_info =<<"    END";
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

			@default_checkboxes = qw(Select_Sample);  #default file type to turn on the checkbox
			@checkbox_columns = qw(Select_Sample);
		        # set the sbeams object into the solexa_groups_object
			$sbeams_solexa_groups->setSBEAMS($sbeams);
		
		        # return a sql statement to display all the arrays for a particular project
			$sql = $sbeams_solexa_groups->get_slimseq_sample_pipeline_sql(project_id    => $project_id, );

		 	%url_cols = ( 'Sample_Tag'	=> "${manage_table_url}solexa_sample&slimseq_sample_id=\%1V",
				      'Select_Sample _OPTIONS' => { 'embed_html' => 1 }
				     );
                        %hidden_cols = ( 'Sample_ID' => 1);

		}else{
			print "<h2>Sorry, no samples qualify for the SolexaTrans pipeline in this project</h2>" ;
			return;
		} 
	
  ###################################################################
  ## Print the data 
		
 	# start the form to run STP on solexa samples
	print $q->start_form(-name =>'select_samplesForm');

	print "<br>";

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
	
	        print   $q->hidden(-name=>'step',-default=>2,-override=>1);	
		print   $q->br,
			$q->submit(-name=>'Get_Data',
				#will need to change value if other data sets need to be run
                	       	 -value=>'Set Parameters');
	
		
		print $q->reset;
		print $q->endform;
		
	#### Display the resultset controls
	$sbeams->displayResultSetControls(resultset_ref=>$resultset_ref,
					  query_parameters_ref=>\%parameters,
					  rs_params_ref=>\%rs_params,
					  base_url=>$base_url,
					 );
	
}

###############################################################################
# print_pipeline_form
# step 2 of starting pipeline jobs
###############################################################################
sub print_pipeline_form {
  	my %args = @_;
  
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
  
	
	$solexa_info =<<"    END";
		<BR>
		<TABLE WIDTH="50%" BORDER=0>
		  <TR>
		   <TD>
        <B>
        Alter default job parameters below and press continue to select samples for this SolexaTrans Pipeline run.
        </B> 
       </TD></TR>
       <TR><TD></TD></TR>
		</TABLE>
    END
	

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
	                  	page_link	    => 'Samples.cgi',
	                  	selected_tab	  => $selected_tab_numb,
                     		parent_tab  	  => $parameters{'tab'},
                  );
	
  #####################################################################################
  ### Get Table info

  my $TABLE_NAME = $parameters{'QUERY_NAME'};
  $TABLE_NAME="ST_JobParameters" unless ($TABLE_NAME);
  ($PROGRAM_FILE_NAME) =
    $sbeamsMOD->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");

  #### Get the columns and input types for this table/query
  my @columns = $sbeamsMOD->returnTableInfo($TABLE_NAME,"ordered_columns");
  my %input_types =
    $sbeamsMOD->returnTableInfo($TABLE_NAME,"input_types");

  #### Read the input parameters for each column
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters,
    columns_ref=>\@columns,input_types_ref=>\%input_types);

  my %unique_sample_ids;
  if ($parameters{select_samples}) {	

      ##########################################################################
      ### Print out some nice table
      #example '37__CEL,38__CEL,45__CEL,46__CEL,46__XML'
      my $samples_id_string =  $parameters{select_samples}; 
      my @sample_ids = split(/,/, $samples_id_string);
      %unique_sample_ids = map {split(/__/, $_) } @sample_ids;
  } elsif ($parameters{slimseq_sample_id}) {
    $unique_sample_ids{$parameters{slimseq_sample_id}} = 1;
  }

  if (scalar keys %unique_sample_ids > 0) {
    # hash reference to hash{organism_name} = biosequence_set_id (organism_id in SBEAMS system)
    my $ref_org_biosequence_id = get_biosequence_set_defaults();

    print qq(<table name="OUTER">\n);
    print "<tr><td>\n";
    print qq( <FORM METHOD="post" ACTION="$PROGRAM_FILE_NAME" NAME="MainForm">\n);
    foreach my $sample (sort {$a <=> $b} ( keys %unique_sample_ids)) {

      # get specific information about this sample from the SolexaTrans database
      my $org_sql = $sbeams_solexa_groups->get_solexa_pipeline_form_sql(slimseq_sample_id => $sample);
     
      my @sample_info = $sbeams->selectSeveralColumns($org_sql);
      my $org_name = $sample_info[0]->[0];
      my $tag_length = $sample_info[0]->[1];
      my $enzyme_id = $sample_info[0]->[2];
      my $sample_name = $sample_info[0]->[3];
      my $index = $ref_org_biosequence_id->{$org_name};

      # overwrite the default parameters with specific parameters if they exist
      $parameters{'biosequence_set_ids__$parameters{id}'} = $index if ($index > 0);
      $parameters{'tag_length__$parameters{id}'} = $tag_length if ($tag_length > 0);
      $parameters{'restriction_enzyme__$parameters{id}'} = $enzyme_id if ($enzyme_id > 0);
      $parameters{'motif__$parameters{id}'} = $enzyme_id if ($enzyme_id > 0);

      # if a job was supplied, get information and overwrite defaults
      my %previous_params;
      if ($parameters{jobname}) {
        my $sql = $sbeams_solexa_groups->get_form_job_data_sql(jobname => $parameters{"jobname"});
        %previous_params = $sbeams->selectTwoColumnHash($sql);
      }

      my %form_params = (%parameters, %previous_params);
      # display a table for each sample of the parameters
      print qq(<table style="border:black 1px solid; border-bottom: 0px; margin: 0px 0px 0px 0px;">\n); 
      print "<tr><td colspan=3>";
      print "<h1>Sample Options for $sample_name ($sample)</h1>\n";
      print "</td>";

 #     my $analysis_id = $utilities->check_sbeams_duplicate_job("jobsummary" => \@job_summary_info);

      print "</tr>";
      $sbeams->display_input_form(
        TABLE_NAME=>$TABLE_NAME,CATEGORY=>$CATEGORY,apply_action=>$apply_action,
        PROGRAM_FILE_NAME=>$PROGRAM_FILE_NAME,
        parameters_ref=>\%form_params,
        input_types_ref=>\%input_types,
        id=>$sample,
        mask_user_context=>1,
        mask_query_constraints=>1,
        mask_form_start=>1,
      );
      print "</table>\n";
    }
#    print "</td></tr>";
#    print "<tr><td>";
  }
	print   
                $q->hidden(-name=>'step',-default=>3,-override=>2),
                '<table style="border-top: 1px solid black; width:100%; margin: 0px; padding: 0px;"><tr><td>',
		$q->submit(-name=>'Get_Data',
			#will need to change value if other data sets need to be run
               	       	 -value=>'Run Pipeline');
	
		
	print $q->reset, "</td></tr></table></table>\n";
        foreach my $param (keys %parameters) {
          print $q->hidden(-name=>$param,
                           -value=>$parameters{$param}
                          ) unless $param eq 'step' || $input_types{$param} || $param eq 'Get_Data';
        }



	print $q->endform;
		

}




###############################################################################
# start_pipeline_jobs
###############################################################################
sub start_pipeline_jobs {
  	my %args = @_;
  
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
        my ($name, $pass, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwnam($current_username);

        # This is crude and only gets the first group in the group list, therefore
        # if a user has multiple groups and the directory they want to write to is
        # not the first group, it may cause jobs to fail
        # Currently this is commented out since it was causing more problems than good
        # The ISB solexa output directories are set with a sticky group and should set the correct permissions
#        my ($group_name, $passwd, $grid, $members) = getgrgid($gid);
	
	my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

	## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
	if ($parameters{set_current_project_id}) {
		$apply_action = 'QUERY';
	}

  if ( $parameters{Get_Data} eq 'Run Pipeline') {
    my %unique_sample_ids;
    if ($parameters{select_samples}) {	

      ##########################################################################
      ### Print out some nice table
      #example '37__CEL,38__CEL,45__CEL,46__CEL,46__XML'
      my $samples_id_string =  $parameters{select_samples}; 
      my @sample_ids = split(/,/, $samples_id_string);
      %unique_sample_ids = map {split(/__/, $_) } @sample_ids;

    } elsif ($parameters{slimseq_sample_id}) {
      $unique_sample_ids{$parameters{slimseq_sample_id}} = 1;
    }

    if (scalar keys %unique_sample_ids > 0 ) {
      my $samples = join(",", sort keys %unique_sample_ids);

      $sql = $sbeams_solexa_groups->get_solexa_pipeline_run_info_sql(slimseq_sample_ids => $samples, 
                                                                     project_id => $project_id
                                                                    );

      # hide the really long file paths from displaying
      %hidden_cols = ( 
                       "SPR_ID" => 1,
                       "Sample_ID" => 1,
                       'ELAND_Output_File' => 1,
                       'Raw_Data_Path' => 1,
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
	
  # Fetch the results from the database server
  $sbeams->fetchResultSet( sql_query => $sql,
                           resultset_ref => $resultset_ref );

  my $TABLE_NAME = $parameters{'QUERY_NAME'};
  $TABLE_NAME="ST_JobParameters" unless ($TABLE_NAME);
  ($PROGRAM_FILE_NAME) =
    $sbeamsMOD->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");
#  my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME";

  #### Get the columns and input types for this table/query
  my @columns = $sbeamsMOD->returnTableInfo($TABLE_NAME,"ordered_columns");
 
  # now that we have the results, go through them and start the pipeline jobs
  my %solexaJobs;

  # create a display resultset that contains
  # Sample ID, Jobname, Job Tag, Organism, Lane, Tag Length, Motif
  my $new_resultset_ref;
  $new_resultset_ref->{'page_size'} = 100;
  $new_resultset_ref->{'types_list_ref'} = ['int','varchar','varchar','varchar','int','varchar','varchar'];
  $new_resultset_ref->{'precisions_list_ref'} = [4,50,2000,2000,4,2000,2000];
  $new_resultset_ref->{'column_hash_ref'} = { 'Sample ID' => 0,
                                              'Jobname' => 1,
                                              'Job_Tag' => 2,
                                              'Organism' => 3,
                                              'Lane' => 4,
                                              'Tag Length' => 5,
                                              'Motif' => 6
                                            };
  $new_resultset_ref->{'row_counter'} = 0;
  $new_resultset_ref->{'row_pointer'} = 0;
  $new_resultset_ref->{'column_list_ref'} = ['Sample ID','Jobname','Job Tag','Organism','Lane','Tag Length','Motif'];
  $new_resultset_ref->{'data_ref'} = [];
 
  #data is stored as an array of arrays from the $sth->fetchrow_array 
  # each row is a row from the database holding an aref to all the values
  my $aref = $$resultset_ref{data_ref};		
          
  my $id_idx = $resultset_ref->{column_hash_ref}->{Sample_ID};
  my $spr_id_idx = $resultset_ref->{column_hash_ref}->{SPR_ID}; # solexa_pipeline_results_id
  my $eland_idx = $resultset_ref->{column_hash_ref}->{ELAND_Output_File};
  my $raw_data_path_idx = $resultset_ref->{column_hash_ref}->{Raw_Data_Path};
  my $lane_idx = $resultset_ref->{column_hash_ref}->{Lane};
  my $organism_idx = $resultset_ref->{column_hash_ref}->{Organism};
#  my $tag_length_idx = $resultset_ref->{column_hash_ref}->{Tag_Length};
#  my $genome_idx = $resultset_ref->{column_hash_ref}->{Genome};
#  my $motif_idx = $resultset_ref->{column_hash_ref}->{Motif};

  ########################################################################################
  # this foreach loop goes through each row that was retrieved from teh database
  # and organizes the files into a file structure that has one entry for each
  # raw directory path - this is what STP expects to receive. 
  my $new_data_ref;
  foreach my $row_aref ( @{$aref} ) {
    my $slimseq_sample_id  = $row_aref->[$id_idx];
    my $solexa_pipeline_results_id  = $row_aref->[$spr_id_idx];
    my $eland_file = $row_aref->[$eland_idx];
    my $raw_data_path = $row_aref->[$raw_data_path_idx];
    my $lane = $row_aref->[$lane_idx];
    my $organism = $row_aref->[$organism_idx];
 
#    my $tag_length = $row_aref->[$tag_length_idx];
#    my $genome = $row_aref->[$genome_idx];
#    my $motif = $row_aref->[$motif_idx];

    my $tag_length = $parameters{'tag_length__'.$slimseq_sample_id};
    my @genomes = $parameters{'biosequence_set_ids__'.$slimseq_sample_id};
    my $truncate = $parameters{'truncate__'.$slimseq_sample_id};
    my $fuse = $parameters{'fuse__'.$slimseq_sample_id} || 0;
    my $patman_max_mismatches = $parameters{'patman_max_mismatches__'.$slimseq_sample_id};
    my $res_enzyme_id = $parameters{'restriction_enzyme__'.$slimseq_sample_id};
    my $motif = $utilities->get_sbeams_restriction_enzyme_motif("enzyme_id" => $res_enzyme_id);
    my $upload_tags = $parameters{'upload_tags__'.$slimseq_sample_id};
    my $job_tag = $parameters{'job_tag__'.$slimseq_sample_id};

#           Since we're taking the existance of the files on the word of the database, it'd be
#            really good to check to see if the file does exist.
#           The simple case doesn't work because the web server user doesn't have access to /solexa/*
#           Ideally this would be some sort of script execution that would run as a user that
#            would have access to all /solexa files but only be able to check for file existance
#            die "ELAND file $eland_file does not exist or is not available" unless -e $eland_file;


    my $jobname;
    if ($parameters{jobname} && $parameters{jobname} =~ /^stp-ssid/) {
      $jobname = $parameters{jobname};
    } else {
     $jobname = 'stp-ssid'.$slimseq_sample_id.'-'.rand_token();
    }

    my @new_line;
    push(@new_line, $slimseq_sample_id);
    push(@new_line, $jobname);
    push(@new_line, $job_tag);
    push(@new_line, $organism);
    push(@new_line, $lane);
    push(@new_line, $tag_length);
    push(@new_line, $motif);
    push(@{$new_resultset_ref->{'data_ref'}}, \@new_line);

    my $pipeline_job_directory = $sbeamsMOD->solexa_delivery_path();
    my @raw_dirs = split(/\//, $raw_data_path);
    my $flow_cell_dir = pop(@raw_dirs); # remove flow cell
    my $pipeline_output_directory = join("/", @raw_dirs);
    $pipeline_output_directory .= '/SolexaTrans/'.$flow_cell_dir.'/';

    # each line is param_display, param_value, param_key
    # param_key is the programmatic value
    my @job_summary_info = (
                             'Sample ID',$slimseq_sample_id,'NULL',
                             'ELAND File',$eland_file,'NULL',
                             'Tag Length',$tag_length,'tag_length__'.$slimseq_sample_id,
                             'Genome',@genomes,'biosequence_set_ids__'.$slimseq_sample_id,
                             'Organism',$organism,'NULL',
                             'Motif',$motif,'NULL',
                             'Restriction Enzyme ID',$res_enzyme_id,'restriction_enzyme__'.$slimseq_sample_id,
                             'Lane',$lane,'NULL',
                             'Pipeline Results ID',$solexa_pipeline_results_id,'NULL',
                             'Job Directory',$pipeline_job_directory,'NULL',
                             'Sequence Truncate',$truncate,'truncate__'.$slimseq_sample_id,
                             'Patman Max Mismatches',$patman_max_mismatches,'patman_max_mismatches__'.$slimseq_sample_id,
                             'File Truncate',$fuse,'fuse__'.$slimseq_sample_id,
                             'Upload Tags',$upload_tags,'upload_tags__'.$slimseq_sample_id,
                             'Job Tag',$job_tag,'job_tag__'.$slimseq_sample_id,
                           );

    my $jobsummary = jobsummary(@job_summary_info); # method in SetupPipeline.pm

#    my $analysis_id = $utilities->check_sbeams_duplicate_job("jobsummary" => \@job_summary_info);
#            if ($analysis_id =~ /ERROR/) {
#             error("$analysis_id");
#            if ($analysis_id) {
#              print "Job already exists for sample $slimseq_sample_id with duplicate parameters.<br>\n";
#              print "If you want to re-run a job, find the job via the Status page and delete or re-run it.<br>\n";
#              $jobname = $utilities->get_sbeams_jobname("solexa_analysis_id" => $analysis_id);

#              $solexaJobs{$slimseq_sample_id} = "$pipeline_output_directory/$jobname";

#              next;
#            }

    my $partial_url = "$CGI_BASE_DIR/SolexaTrans/View_Solexa_files.cgi?action=view_file&jobname=$jobname&analysis_file=$jobname";

    # links to view the tag counts etc
    my $out_links = <<OUTL;
<h3>Output Files</h3>
<a href='$partial_url&file_ext=html'>$jobname.html</a><br>
<a href='$partial_url&file_ext=txt'>$jobname.txt</a><br>
OUTL

    my $anchor='';
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

    $anchor = 'file://///'.$path;

    my $output = <<END;
<h3>Show Analysis Data:</h3>
<a href="$anchor">Show Files</a>
$out_links
END

    my $output_dir_id = $utilities->check_sbeams_file_path(file_path => $pipeline_output_directory);
    if (!$output_dir_id) {
      my $output_server_id = $utilities->check_sbeams_server("server_name" => "RUNE");
      if ($output_server_id =~ /ERROR/) { error($output_server_id); }

      $output_dir_id = $utilities->insert_file_path(file_path => $pipeline_output_directory,
                                                    file_path_name => 'Output Directory for SolexaTrans job',
                                                    file_path_desc => '',
                                                    server_id => $output_server_id,
                                                   );
    }

    my $ana_id = $utilities->insert_or_update_sbeams_solexa_analysis(
                                                     'jobname' => $jobname,
                                                     'slimseq_sample_id' => $slimseq_sample_id,
                                                     'output_dir_id' => $output_dir_id,
                                                     'analysis_description' => 'SolexaTrans Job',
                                                     'project_id' => $project_id,
                                                     'status' => 'QUEUED',
                                                     'status_time' => 'CURRENT_TIMESTAMP',
                                                     'SPR_ID' => $solexa_pipeline_results_id,
                                                     'job_tag' => $job_tag,
                                                     'params' => \@job_summary_info,
                                                    );
    $sbeams->handle_error(message=>$ana_id) if $ana_id =~ /ERROR/;

    my $job_time = $utilities->get_sbeams_job_date_created(solexa_analysis_id => $ana_id);
    if (!$job_time || $job_time == 0) {
     $log->warn("Time could not be retrieved for the date_created for job $ana_id");
     $job_time = strftime "%Y%m%d%H%M%S",localtime; # a timestamp of YearMonthDayHourMinuteSecond
    }

    $pipeline_output_directory = $pipeline_output_directory.$job_time.'/';
    print "Writing to directory $pipeline_output_directory<br>\n";
    $output_dir_id = $utilities->check_sbeams_file_path(file_path => $pipeline_output_directory);
    if (!$output_dir_id) {
      my $output_server_id = $utilities->check_sbeams_server("server_name" => "RUNE");
      if ($output_server_id =~ /ERROR/) { error($output_server_id); }

      $output_dir_id = $utilities->insert_file_path(file_path => $pipeline_output_directory,
                                                    file_path_name => 'Output Directory for SolexaTrans job '.$jobname,
                                                    file_path_desc => '',
                                                    server_id => $output_server_id,
                                                   );
    }

    push(@job_summary_info,'Job Directory');
    push(@job_summary_info,$pipeline_job_directory);
    push(@job_summary_info,'NULL');
     
    $ana_id = $utilities->insert_or_update_sbeams_solexa_analysis(
                                                     'jobname' => $jobname,
                                                     'slimseq_sample_id' => $slimseq_sample_id,
                                                     'output_dir_id' => $output_dir_id,
                                                     'analysis_description' => 'SolexaTrans Job',
                                                     'project_id' => $project_id,
                                                     'status' => 'QUEUED',
                                                     'status_time' => 'CURRENT_TIMESTAMP',
                                                     'SPR_ID' => $solexa_pipeline_results_id,
                                                     'params' => \@job_summary_info,
                                                    );
    $sbeams->handle_error(message=>$ana_id) if $ana_id =~ /ERROR/;

    print "Starting a new SolexaTransPipeline job with Slimseq sample id $slimseq_sample_id<br>\n";

    my $perl_script = generate_perl(
                                              "Sample_ID" => $slimseq_sample_id,
                                              "SPR_ID" => $solexa_pipeline_results_id,
                                              "ELAND_Output_File" => $eland_file,
                                              "Raw_Data_Path" => $raw_data_path,
                                              "Tag_Length" => $tag_length,
                                              "Genome" => join(",",@genomes),
                                              "Organism" => $organism,
                                              "Motif" => $motif,
                                              "Jobname" => $jobname,
                                              "Lane" => $lane,
                                              "Truncate" =>$truncate,
                                              "Patman_max_mismatches"=>$patman_max_mismatches,
                                              "Fuse"=>$fuse,
                                              "Output_Dir" => $pipeline_output_directory,
                                              "Job_Dir" => $pipeline_job_directory,
                                              "Analysis_ID" => $ana_id,
                                              "Upload_Tags" => $upload_tags,
                              ); 


    my $error = create_files( 
                                        dir => $pipeline_output_directory,
                                        job_dir => $pipeline_job_directory,
                                        jobname => $jobname,
                                        title => $sbeams->getCurrent_project_name,
                                        jobsummary => $jobsummary,
                                        output => $output,
                                        refresh => 20,
                                        script => $perl_script,
                                        email => $current_email
                                    );
    error($error) if $error;

    my $job = new Batch;
    $job->cputime('48:00:00'); # default at 48 hours for now
    $job->type($BATCH_SYSTEM);
    $job->script("$pipeline_job_directory/$jobname/$jobname.sh");
    $job->name($jobname);
#    $job->group($group_name); # commented out, read note where group_name is set
    $job->out("$pipeline_job_directory/$jobname/$jobname.out");
    $job->queue("dev");
    eval{
    $job->submit;
    };
    if ($@) {
     error("Couldn't start a job for $jobname - $@");
    }
    #$job->submit || error("Couldn't start a job for $jobname - ");
    open (ID, ">$pipeline_job_directory/$jobname/id") || 
      error("Couldn't write out an id for $jobname in $pipeline_job_directory/$jobname/id");
    print ID $job->id;
    close(ID);
    chmod(0666,"$pipeline_job_directory/$jobname/id");

    print "<br>\n";
    print "<br>\n";

    $solexaJobs{$slimseq_sample_id} = "$pipeline_job_directory/$jobname";


  } # end foreach row     

  append_job_link( resultset_ref => $new_resultset_ref,
		   jobs => \%solexaJobs,
                 );

  # Set the column_titles to just the column_names, reset first.
  @column_titles = ();
  for my $title ( @{$new_resultset_ref->{column_list_ref}} ) {
    push @column_titles, $title;
  }

  ###################################################################
  
  $log->info( "writing" );
  #### Store the resultset and parameters to disk resultset cache
  $rs_params{set_name} = "SETME";
  $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
		  	  resultset_ref=>$new_resultset_ref,
			  query_parameters_ref=>\%parameters,
			  resultset_params_ref=>\%rs_params,
  			  query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
	  		 );


  #### Display the resultset
  $sbeams->displayResultSet(resultset_ref=>$new_resultset_ref,
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
	unshift @$aref, '-10';					
	$$resultset_ref{precisions_list_ref} = $aref;

        my $bref = $$resultset_ref{types_list_ref};
        unshift(@$bref, 'int');
        $$resultset_ref{types_list_ref} = $bref;
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

###############################################################################
# generate_perl
###############################################################################
sub generate_perl {
    my (%argHash)=@_;
    my @required_opts=qw(Sample_ID SPR_ID ELAND_Output_File Raw_Data_Path Tag_Length Genome Organism Motif Lane Truncate Patman_max_mismatches Fuse Output_Dir Job_Dir Jobname Analysis_ID Upload_Tags);
    my @missing=grep {!defined $argHash{$_}} @required_opts;
    die "missing opts: ",join(', ',@missing) if @missing;

    my ($sample_id, $spr_id, $eland_file, $raw_data_path, $tag_length, $genome, $organism, $motif, $lane, $truncate, $patman_max_mismatches, $fuse, $output_dir, $job_dir, $jobname, $analysis_id, $upload_tags)=
        @argHash{qw(Sample_ID SPR_ID ELAND_Output_File Raw_Data_Path Tag_Length Genome Organism Motif Lane Truncate Patman_max_mismatches Fuse Output_Dir Job_Dir Jobname Analysis_ID Upload_Tags)};

    my $project_name = $sbeams->getCurrent_project_tag; # this is project tag because the STP code insists on using
                                                        # the 'project_name' field as part of the output directory path
                                                        # and other file names
    my $project_id = $sbeams->getCurrent_project_id;

    # base_dir is where the script is called from
    # export_dir is where the input comes from (s_\d_export.txt)
    # project_dir is where the files are stored while being processed
    # output_dir is where the results go

    my $pscript=<<"PEND";
#!/tools64/bin/perl

use Carp;
use strict;
use warnings;
use lib "$PHYSICAL_BASE_DIR/lib/perl";
use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::SolexaTrans::Solexa_file_groups;
use SBEAMS::SolexaTrans::SolexaTransPipeline;
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::SolexaTrans::SolexaUtilities;
use POSIX qw(strftime);
use File::Path;

my \$verbose = 1;   # these should be 0 for production
my \$testonly = 0;

my \$sbeams = new SBEAMS::Connection;
my \$utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
\$utilities->setSBEAMS(\$sbeams);

my \$current_username = \$sbeams->Authenticate();

my \$sample_id = '$sample_id';
my \$project_name = '$project_name';
my \$lane = '$lane';
my \$analysis_id = '$analysis_id';
my \@genomes = ( $genome );
my \$tag_analysis_format_file = '$PHYSICAL_BASE_DIR'.'/lib/conf/SolexaTrans/tag_analysis3.fmt';
my \$gene_analysis_format_file = '$PHYSICAL_BASE_DIR'.'/lib/conf/SolexaTrans/gene_analysis.fmt';

PEND

  $pscript.=<<"PEND2";
            my \$output_dir_id = \$utilities->check_sbeams_file_path(file_path => '$output_dir');
            if (!\$output_dir_id) {
               my \$output_server_id = \$utilities->check_sbeams_server("server_name" => "RUNE");
               if (\$output_server_id =~ /ERROR/) { die \$output_server_id; }

               \$output_dir_id = \$utilities->insert_file_path(file_path => '$output_dir',
                                                               file_path_name => 'Output Directory for SolexaTrans job',
                                                               file_path_desc => '',
                                                               server_id => \$output_server_id,
                                                               );
            }

            # insert the job information before calling STP to process
            my \$rowdata_ref = {
                                jobname => '$jobname',
                                slimseq_sample_id => \$sample_id,
                                output_directory_id => \$output_dir_id,
                                project_id => $project_id,
                                status => 'RUNNING',
                                status_time => 'CURRENT_TIMESTAMP',
                                solexa_pipeline_results_id => '$spr_id',
                              };

            \$sbeams->updateOrInsertRow(
                                                          table_name=>\$TBST_SOLEXA_ANALYSIS,
                                                          rowdata_ref => \$rowdata_ref,
                                                          PK=>'solexa_analysis_id',
                                                          PK_value=>\$analysis_id,
                                                          return_PK=>1,
                                                          update=>1,
                                                          verbose=>\$verbose,
                                                          testonly=>\$testonly,
                                                          add_audit_parameters=>1,
                                                        );
PEND2

  $pscript.=<<"PEND3";

            {

            # sample id is slimseq sample id
            my \$pipeline = SBEAMS::SolexaTrans::SolexaTransPipeline->new(
                                project_name=>\$project_name,
                                output_dir=> '$job_dir/$jobname', # job directory, copy files to output directory later
                                genome_ids => \\\@genomes,
                                ref_org=> '$organism',
                                export_file=>'$eland_file',
                                tag_length=> '$tag_length',
                                lane => \$lane,
                                patman_max_mismatches => $patman_max_mismatches,
                                fuse => $fuse,
                                ss_sample_id => \$sample_id,  # slimseq sample id
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
            \$rowdata_ref->{"total_tags"}         = \$statsref->{total_tags};
            \$rowdata_ref->{"total_unique_tags"}  = \$statsref->{total_unique};
            \$rowdata_ref->{"match_tags"}         = \$statsref->{tags_total};
            \$rowdata_ref->{"match_unique_tags"}  = \$statsref->{tags_unique};
            \$rowdata_ref->{"ambg_tags"}          = \$statsref->{ambg_total};
            \$rowdata_ref->{"ambg_unique_tags"}   = \$statsref->{ambg_unique};
            \$rowdata_ref->{"unkn_tags"}          = \$statsref->{unkn_total};
            \$rowdata_ref->{"unkn_unique_tags"}   = \$statsref->{unkn_unique};
            \$rowdata_ref->{"total_genes"}        = \$statsref->{cpm_unique};

PEND4

    # upload_tags 1 = YES, 2 = NO
    # PROCESSED = finished running STP but not uploaded to ST database
    $pscript .= qq(\$rowdata_ref->{"status"}             = 'UPLOADING';) if $upload_tags == 1;

    $pscript .= qq(\$rowdata_ref->{"status"}             = 'PROCESSED';) if $upload_tags == 2;


    $pscript .= <<"PEND5";

            \$sbeams->updateOrInsertRow(
                                         table_name=>\$TBST_SOLEXA_ANALYSIS,
                                         rowdata_ref => \$rowdata_ref,
                                         PK=>'solexa_analysis_id',
                                         PK_value => \$analysis_id,
                                         update=>1,
                                         verbose=>\$verbose,
                                         testonly=>\$testonly,
                                         add_audit_parameters=>1,
                                        );

            \$pipeline = undef;

            }

            # make sure the output directory is created - Do this in perl because mkpath
            # will create a recursive structure whereas a simple mkdir will fail if 
            # more than one of the directories needs to be created
            my \@created = mkpath(qw($output_dir),{verbose=>1},);
            print "Created \$_\n" for \@created;
PEND5

  # THE METHODS IN THIS SECTION ARE IN UploadPipeline.pm

  # always add the CPM info
  $pscript .= upload_gene_info();
  $pscript .= perl_process_genes('cpm', $job_dir.'/'.$jobname);

  # upload the TAG and AMBIGUOUS info if user selected
  # upload_tags 1 = YES , 2 = NO
  if ($upload_tags == 1) {

   $pscript .= upload_tag_info();

    my $tag_script = perl_process_tags('MATCH', $job_dir.'/'.$jobname);
#    my $unkn_script = perl_process_tags('UNKNOWN', $job_dir.'/'.$jobname);
    my $ambg_script = perl_process_tags('AMBIGUOUS', $job_dir.'/'.$jobname);
  
    $pscript .= $tag_script;
#    $pscript .= $unkn_script;
    $pscript .= $ambg_script;


    $pscript .= alter_db_status('COMPLETED');

  } # end if upload_tags

return $pscript;
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

###############################################################################
# get_form_defaults
###############################################################################
sub get_form_defaults {
  my %args = @_;
  my $ref_parameters = $args{'ref_parameters'} || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  my $sql = $sbeams_solexa_groups->get_form_defaults_sql();
  my %defaults = $sbeams->selectTwoColumnHash($sql);

  foreach my $default (keys %defaults) {
   $parameters{$default} = $defaults{$default};
  }

  return \%parameters;
}


###############################################################################
# get_form_data 
###############################################################################
sub get_form_data {
  my %args = @_;
  my $ref_parameters = $args{'ref_parameters'} || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  my $job_sql = $sbeams_solexa_groups->get_detailed_job_status_sql(jobname => $parameters{jobname});
  my @job_info = $sbeams->selectSeveralColumns($job_sql);
  $parameters{select_samples} = $job_info[0]->[14].'__Select_Sample';
  $parameters{Get_Data} = 'Set Parameters';

  my $sql = $sbeams_solexa_groups->get_form_job_data_sql(jobname => $parameters{"jobname"});
  my @rows = $sbeams->selectSeveralColumns($sql);

  #go through parameters
  foreach my $row (@rows) {
#    $parameters{$row->[0]} = $row->[1] if ($row->[0]); 
  }

  return \%parameters;
}


###############################################################################
# get_biosequence_set_defaults
# Returns SBEAMS hash ref
###############################################################################
sub get_biosequence_set_defaults {
        my $method = 'get_biosequence_set_defaults';
        my $self = shift;

        # option_key for JP_biosequence_set_defaults is organism_id
        # option_value for JP_biosequence_set_defaults is biosequence_set_id
        my $sql = qq~
                SELECT option_key, option_value
                FROM $TBST_QUERY_OPTION
                WHERE option_type = 'JP_biosequence_set_defaults'
                  AND RECORD_STATUS != 'D'
        ~;

        my %defaults = $sbeams->selectTwoColumnHash($sql);

        if ((scalar (keys %defaults)) > 0) {
          return \%defaults;
        } else {
          return undef;
        }
}

