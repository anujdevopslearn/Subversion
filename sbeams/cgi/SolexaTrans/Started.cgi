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
$PROGRAM_FILE_NAME = 'Started.cgi';
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

  print_getting_started(ref_parameters=>$ref_parameters); 
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
# print_getting_started
###############################################################################
sub print_getting_started {
   my %args = @_;
 
  my @columns = ();
  my $sql = '';
  
  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  my $base_url = "$CGI_BASE_DIR/SolexaTrans/Started.cgi";
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

  print qq~
    <h1>Getting Started</h1>
    <p>The SolexaTransPipeline allows you to take export files from the Illumina Solexa Pipeline and 
      match the Tags that were found to genes in a list of genomes.</p>

    <p>The main page of the SBEAMS SolexaTrans module is intended as an overall control panel.  The table
      underneath the project information displays one row per sample in the project.  If a sample is missing,
      then it has not been imported yet.  For each sample, it displays the most current job, but other jobs
      are available from the select box in that row.  Following the job information is job control options
      that allows the user to view the job, perform various job actions and retrive the results of the 
      SolexaTrans pipeline.</p>
    <p>&nbsp;</p>
    <ul>
      <li><b>Prequisites</b>
          <ul style="padding-top: 10px;">
            <li> <u>Run Samples</u>
              <p>Solexa samples are run on the Solexa machine by creating a sample
                and delivering it to the core facility then entering sample information in the core
                facility information system - <a href="http://db/slimseq/">SlimSeq</a>.
              </p>
            </li>
            <li> <u>Import information</u>
              <p>The SBEAMS system imports information from SlimSeq on a daily basis.
                A STP administrator can be mailed to run the import as necessary.  
                Mail <a href="mailto:dmauldin\@systemsbiology.org">Denise Mauldin</a>.
              </p>
            </li>
            <li> <u>Project Permissions</u>
              <p>SBEAMS assumes a strict interpretation of project permissions.  
                New projects are created in SBEAMS automatically and the person who is listed as submitting
                the sample in SlimSeq is assigned as the project administrator.  In addition, the SlimSeq
                lab group is given read access to the project.  The project administrator can add new
                people to the project via the SBEAMS interface (SBEAMS Home -> View/Edit Access Privileges 
                for the current project).
                Samples that do not have a submitter are assigned to the core facility administrator - Bruz Marzolf.
                STP administrators can also add and modify permissions.
              </p>
            </li>
          </ul>
      </li>
    <p>&nbsp;</p>
      <li><b>Step 1 - Sample Information</b>
        <ul style="padding-top: 10px;">
          <li><u>Viewing Sample Information</u> 
            <p>Sample information from SlimSeq can be viewed in the SolexaTrans module.  Quality control information
              is available by clicking on the <a href="SampleQC.cgi">SampleQC</a> link in the left navigation bar. 
              The Solexa Pipeline Summary file is available by clicking on <a href="dataDownload.cgi">Download Data</a>
              and subsequently clicking on 'View' under the Summary column for the sample you wish to view.
            </p>
          </li>
          <li><u>Editing Sample Information</u>  
            <p>Sample information from the SlimSeq system cannot be edited in the SBEAMS interface.  You must edit this
              information via the SlimSeq website and then re-import the data from SlimSeq.  However, SBEAMS has some
              additional fields that may be useful for containing information or developing analyses.  These fields
              are left blank by default but can be edited by clicking on the 'Sample Tag' of the sample you wish to
              edit.
            </p>
          </li>
        </ul>
      </li>
    <p>&nbsp;</p>
      <li><b>Step 2 - Running the STP</b>
        <ul style="padding-top: 10px;">
            <li> <u>Start a Job</u> 
              <p>There are two ways to start a job in the SolexaTrans Pipeline.  The first is to click on 'Start Job'
              next to the appropriate sample in the main page.  This starts a single job.  The second is to click on
              'Start Pipeline' in the left navigation bar.  This allows the user to select multiple samples to run
              STP information for.
            </li>
            <li> <u>Set Pipeline Options</u> -
              <p>Once samples have been selected, the STP options page appears.  The options are filled with default
                options that are appropriate for the sample indicated.  For example, mouse samples default to having
                mouse RefSeq as their genome.  All samples default to having the appropriate restriction enzyme 
                selected for the sample preparation kit that was used.

                For more information about Pipeline Options, click on the 'Help' link in the Options page.
              </p>
            </li>
        </ul>
      </li>
    <p>&nbsp;</p>
      <li><b>Step 3 - Getting STP Results</b>
        <ul style="padding-top: 10px;">
          <li><u>Download Data</u> 
            <p>Once the STP Job has reached a 'PROCESSED', 'UPLOADING', or 'COMPLETED' status, the STP files
              are available for download using the <a href="dataDownload.cgi">Download Data</a> EXPLORE link.
            </p>
            <p>The EXPLORE link will open a window that automatically paths to where STP data is stored on the 
              RUNE fileserver.
            </p>
          </li>
          <li><u>Get Counts</u>  
            <p>The Get Counts tool is an interface to the STP database.</p>
            <ul>
              <li> GENE QUERY -
                <p> Information from the STP about genes is automatically uploaded into the STP database when the
                  job finishes running.  Therefore, jobs with a status of 'PROCESSED', 'UPLOADING', or 'COMPLETED'
                  have complete GENE QUERY information in the <a href="GetCounts">Get Counts</a> tool.
                </p>
              </li>
              <li> TAG QUERY - 
                <p>Information from the STP about tags is NOT automatically uploaded into the STP database (because
                  the upload process takes around 2 days and this information is not necessarily relevant to 
                  every user).  In order to upload Tag information, users need to start an upload job.</p>
                <p>It is recommended that if you want to look at TAG information that you should use the raw STP files
                 rather than the Get Counts tool.
                </p>
                <p>Therefore, information from the STP about tags is only available in jobs with the 'COMPLETED' 
                    job status.
                </p>
            </ul>
          </li>
        </ul>
      </li>
    </ul>

  ~;
}

sub postProcessResultset {
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

