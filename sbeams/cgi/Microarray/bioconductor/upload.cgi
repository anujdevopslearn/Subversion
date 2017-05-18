#!/usr/local/bin/perl -w

###############################################################################
# Program     : GetExpression
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This program that allows users to
#              view affy gene expression intensity
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
use Tie::IxHash;
use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use File::stat;
use POSIX;
use FileManager;
use Site;
use BioC;
use strict;
use CGI::Carp 'fatalsToBrowser';
use Data::Dumper;
use File::Copy;
use Getopt::Long;
use FindBin;
use XML::Writer;
use IO;


use lib "$FindBin::Bin/../../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $affy_o $data_analysis_o $cgi $current_username $USER_ID
  $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
  $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME $q
  @MENU_OPTIONS %CONVERSION_H *sym);

use SBEAMS::Connection qw($log $q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;
use SBEAMS::Connection::Merge_results_sets;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::Affy_file_groups;
use SBEAMS::Microarray::Affy_Analysis;
use SBEAMS::Microarray::Affy_Annotation;


$sbeams    = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$affy_o = new SBEAMS::Microarray::Affy_Analysis;
$affy_o->setSBEAMS($sbeams);

my $sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;
$sbeams_affy_groups->setSBEAMS($sbeams);		#set the sbeams object into the sbeams_affy_groups

# Create the global FileManager instance
our $fm = new FileManager;


#$cgi = new CGI;
#using a single cgi in instance created during authentication
$cgi = $q;

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE     = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless ( GetOptions( \%OPTIONS, "verbose:s", "quiet", "debug:s" ) ) {
	print "$USAGE";
	exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET   = $OPTIONS{"quiet"}   || 0;
$DEBUG   = $OPTIONS{"debug"}   || 0;
if ($DEBUG) {
	print "Options settings:\n";
	print "  VERBOSE = $VERBOSE\n";
	print "  QUIET = $QUIET\n";
	print "  DEBUG = $DEBUG\n";
	print "OBJECT TYPES 'sbeamMOD' = " . ref($sbeams) . "\n";
	#print Dumper($sbeams);
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################

my $base_url         = "$CGI_BASE_DIR/Microarray/bioconductor/$PROG_NAME";
my $manage_table_url =
  "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=MA_";
my $open_file_url = "$CGI_BASE_DIR/Microarray/View_Affy_files.cgi";
my $multtest_url = "$CGI_BASE_DIR/Microarray/bioconductor/multtest.cgi";
my $make_java_files_url = "$CGI_BASE_DIR/Microarray/bioconductor/Make_MEV_jws_files.cgi";
my $geo_submission_url = "$CGI_BASE_DIR/Microarray/bioconductor/Create_GEO_file.cgi";

main();
exit(0);

###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

	#### Do the SBEAMS authentication and exit if a username is not returned
	exit
	  unless (
		$current_username = $sbeams->Authenticate(
			permitted_work_groups_ref =>
			  [ 'Microarray_user', 'Microarray_admin', 'Admin' ],
			#connect_read_only=>1,
			#allow_anonymous_access=>1,
		)
	  );

	#### Read in the default input parameters
	my %parameters;
	my $submit = $cgi->param('Submit');

  # Second submit botton which leads to gene pattern pipeline pages. 
  if ( !$submit ) {
    $submit = $cgi->param('gpSubmit');
  }

	my $token = $cgi->param('token');
	my $delete_sub = $cgi->param('delete_sub');
	
	
	my $n_params_found = $sbeams->parse_input_parameters(
		q              => $cgi,
		parameters_ref => \%parameters
	);

	#### Process generic "state" parameters before we start
	$sbeams->processStandardParameters( parameters_ref => \%parameters );

  # Do some permissions checking early
  if ( defined $submit && grep $submit, write_ops($submit) ) {
    unless ( $sbeams->isProjectWritable( admin_override => 0 ) ) {
      $sbeams->set_page_message( type => 'Error',
                                  msg => <<"      END" );
      Unable to complete request, you lack write access to the current project.
      END
     print $q->redirect( 'upload.cgi' );
     exit;
    }
  } elsif  ( defined $submit && grep $submit, modify_ops($submit) ) {
    unless ( $sbeams->isProjectModifiable( admin_override => 0 ) ) {
      $sbeams->set_page_message( type => 'Error',
                                  msg => <<"      END" );
      Unable to complete request, you lack modify access to the current project.
      END
     print $q->redirect( 'upload.cgi' );
     exit;
    }
  }
	
	#### Decide what action to take based on information so far

	if (defined($submit) && $submit eq "Show Job") {
	    showjob($token);
	} elsif (defined($submit) && $submit eq "Complete File Grouping") {
     affy($token);
	} elsif (defined($submit) && $submit =~ /Exon_Array_Analysis|Custom_CDF_Analysis/ ) {
		$sbeamsMOD->printPageHeader();
    my $content = launch_gp_pipeline($token);
		handle_request( ref_parameters => \%parameters, content => $content );
		$sbeamsMOD->printPageFooter();
	} elsif (defined($submit) && $submit eq "multtest") {
		multtest($token);
	} elsif (defined($submit) && $submit eq "annaffy") {
		annaffy($token);

##Delete setup
	}elsif(defined($delete_sub) 
			&& $delete_sub eq "GO"){
		$sbeamsMOD->printPageHeader();
		delete_data_setup(ref_parameters => \%parameters);
		$sbeamsMOD->printPageFooter();
##Default print page
	}else {

		$sbeamsMOD->printPageHeader();
		handle_request( ref_parameters => \%parameters );
		$sbeamsMOD->printPageFooter();
	}

}    # end main



###############################################################################
# Handle Request
###############################################################################
sub handle_request {
	my %args = @_;

	#### Process the arguments list
	my $ref_parameters = $args{'ref_parameters'}
	  || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};
	
	my $submit = $parameters{Submit};

	$sbeams->printUserContext();
	
  # Create new tabmenu item.  This may be a $sbeams object method in the future.
	my $tabmenu = SBEAMS::Connection::TabMenu->new( cgi => $cgi,
                                                  maSkin => 1,   # If true, use MA look/feel
                                                 );

  	
  	
  	# Preferred way to add tabs.  label is required, helptext optional
  	$tabmenu->addTab( label => 'File Groups', helptext => 'View Groups of affy Files' );
  	$tabmenu->addTab( label => 'Normalized Data', helptext => 'View completed normalized analysis runs' );
  	$tabmenu->addTab( label => 'Analysis Results', helptext => 'View differential expression runs' );
  
	print "<br>";
	
  if( $sbeams->isProjectWritable( admin_override => 0) ) {
    # Add button/form to start a new analysis session
	  start_button(); 
  } else {
    print $sbeams->getPopupDHTML();
    my $title = $q->escape('Project Permissions');
    my $text = $q->escape( <<"    END" );
    You lack write permission to the current project.  To create an analysis
    session, please switch to a project for which you have write privilege, 
    or request write privileges from the PI of the current project
    END
    my $url = "$HTML_BASE_DIR/cgi/help_popup.cgi?text=$text;title=$title;email_link=no";

    print <<"    END";  
    <FONT COLOR="green"> Cannot create new analysis session in current project </FONT>
    <A HREF="" onclick='popitup("$url")'> (details) </A>
	  <br>
	  <br>
    END

    my $deadend =<<"    END";  
    <SCRIPT LANGUAGE="javascript">
    function submit_form() {
      document.INFO_FORM.submit();
      return true;
    }
    </SCRIPT>
    <FORM METHOD=POST ACTION="../../help_popup.cgi" NAME=INFO_FORM>
    <INPUT TYPE=HIDDEN NAME=title VALUE="Project Permissions">
    <INPUT TYPE=HIDDEN NAME=text VALUE="Project Permission info">
    <FONT COLOR="green"> Unable to create new analysis session</FONT>
    <A onclick="submit_form()" TARGET=info_window> details </A>
    </FORM>
    END
  }

	print "$tabmenu";

  if ( $args{content} ) {
    print $args{content};
    return;
  }

  my $project = $sbeams->getCurrent_project_id();
  $data_analysis_o = $affy_o->check_for_analysis_data( project_id => $project );
													
	if ($data_analysis_o == 0 ){
		unless (defined($submit)) {
		print "<h2>Sorry, there are no previous analysis sessions.</h2><br>
				<p>To Start a new session Click on the Start new Analysis Session button above.";
		
		return ;
		}
	}


  
  # See if token is present and make $fm (file manager) object if possible.
	check_for_token();	

  

###Choose the correct tab or default to the first tab File Groups
	if ( $tabmenu->getActiveTab() == 2 
		|| $submit eq 'Continue File Grouping' 
		|| $submit eq 'files_sample_group_pairs'){
		my $folder_names_aref = $data_analysis_o->check_for_analysis_data_type(
			analysis_name_type => 'normalization'
		    );
		
		if (defined($submit) && $submit eq "files_sample_group_pairs"){
			affy();
		}elsif($cgi->param('show_norm_files') == 1){
			display_files(analysis_name_type => 'normalization');
		
		}elsif($submit eq 'Show Old Analysis' 
			||( ref($data_analysis_o) 
	 		&& ref($folder_names_aref) 
	 		&& $submit ne 'Continue File Grouping' 
	 		&& $submit ne 'Submit Group Names'
	 		&! $cgi->param('number_of_groups')
	 		)
	 		){
			
			show_previous_normalization_groups($folder_names_aref);
		}else{
			make_group_arrays_form();
		}
###Show previous anlaysis runs
	}elsif( $tabmenu->getActiveTab() == 3 ){
		if ($cgi->param('show_analysis_files') == 1){
			display_files(analysis_name_type => 'differential_expression');
		}else{
			show_previous_analysis_groups();
		}
###Default to the file tab
	}else{	
		
		$sbeamsMOD->change_views_javascript();
		$sbeamsMOD->updateCheckBoxButtons_javascript();
		
		if ($fm && $fm->token() && $submit ne 'Show Old Analysis'){			
											#go here if the user has choosen some arrays to add to a folder
			if (defined($submit) && $submit eq "Add Arrays") {
				upload_files();
			}
				
			filelist( $fm->token() );		#list all the files in this particular dir
			print_display_files_form();
			
											#if there is some analysis data And we made it this far Show the previous data
		}elsif(ref($data_analysis_o)  ){
			show_previous_file_groups();
		}elsif($data_analysis_o == 0){
			print "<h2>No Previous Data Sets</h2><br>";	
		}else{
			print "NO TOKEN SET<br>";
		}
		
	}

}    #end handle_request

###############################################################
#check for token
###############################################################
sub check_for_token {
	
	my $submit = $cgi->param('Submit');
	my $token  = $cgi->param('token') ;
	my $analysis_id = '';
	my ($status);
	# Handle initializing the FileManager session
		
	if ($token) {
		
		unless ( $fm->init_with_token($Site::BC_UPLOAD_DIR, $token)) {
			undef $fm;
			$status = "Couldn't load session from token: $token";
			
		}
		
	###Set the analysis_id it always should be present in the cgi param string.....
		
		if ($fm->analysis_id($cgi->param('analysis_id')) == 0) {
		}else{
			 $status = "Could not find the analysis_id cgi param";
		}
		
		
		
		if (defined($submit) && $submit eq "Delete Checked Files") {
	
			my @filenames = $cgi->param('files');
			$log->debug("FILES TO DELETE '@filenames'");
		#Check to make sure we have some thing that looks like a file name
		# if the user chooses to cancell a delete a white spaced filled array comes back
			return unless ($filenames[0] =~ /^\w/);
			if (scalar(@filenames) > 0) {
				$fm->remove(@filenames) || ($status = "Error while deleting files.");
			}
			$log->debug("DELETE STATUS '$status'<br>");
		}
		if ($status){
			die"Cannot Delete Files '$status' <br>";
		}	
	
	} elsif (defined($submit) && $submit eq "Start Session") {
		
		$USER_ID = $affy_o->get_user_id_from_user_name($current_username);
		my $project_id	= $sbeams->getCurrent_project_id();
		#print "PROJECT ID '$project_id' ABOUT TO ENTER NEW FOLDER ANALYSIS<br>";
		$fm->create($Site::BC_UPLOAD_DIR) || error("Couldn't create new session");
		
		my $rowdata_ref = {folder_name => $fm->token(),
						   user_id => $USER_ID,
						   project_id => $project_id,
						   affy_analysis_type_id => $affy_o->find_analysis_type_id("file_groups"),
						   analysis_description => "Adding new file group session " .localtime ,
						  };
		$analysis_id = $affy_o->add_analysis_session(rowdata_ref => $rowdata_ref);
		$fm->analysis_id($analysis_id);
		$cgi->param('_tab',1);
		$log->debug( " NEW ANALYSIS TOKEN '". $fm->token(). " ANALYSIS ID ". $fm->analysis_id);
							  
	} else {
		$log->debug("TOKEN IS NULL\n");
		
		undef $fm;
	}	
	

}#end check for token
###############################################################################
# print_display_files_form 
# Show all the arrays that can provide data
###############################################################################
sub print_display_files_form {
	  my %args = @_;
	
	 	
		my %parameters = $args{'ref_parameters'};
	  	my $project_id = $sbeams->getCurrent_project_id();	#project ID from the usercontext 
		my $analysis_id = '';
		if (defined $cgi->param('analysis_id')){
			$analysis_id = 	$cgi->param('analysis_id');
		}else{
			$analysis_id = $fm->analysis_id;
		}
		#print Dumper ($fm);
		error("No Analysis ID set") unless $analysis_id;
###project ids from the form showing all projects with affy array data.	
		my @additional_project_ids = $cgi->param('apply_action_hidden');	
		
		my $all_project_ids = '';
###Glue together all the possible project ids	
###If we only have the projectId from the usercontext use it as the default		
		if ($project_id && !@additional_project_ids){		
			push @additional_project_ids, $project_id;
		}
		
		if (@additional_project_ids){
			$all_project_ids = join ",", @additional_project_ids;
		}else{
			$all_project_ids = $project_id;
		}
	
		
		my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || '';

		my %rs_params = $sbeams->parseResultSetParams(q=>$cgi);

		my %url_cols      = ();
	  	my %hidden_cols   = ();
	  	my $limit_clause  = '';
	  	my @column_titles = ();
	  	my %max_widths 	  = ();

		  #### Define some variables for a query and resultset
	  	my %resultset = ();
	  	my $resultset_ref = \%resultset;

		my @downloadable_file_types = ();
	  	my @default_file_types      = ();
	  	my @diplay_files  = ();
	  	
	  	@default_file_types = qw(CEL);
	  	#@display_file_types(R_CHP);
	  	@downloadable_file_types = qw(CEL);				#Will use these file extensions

		my $sql = '';
		
    my @all_affy_arrays_project = $sbeams_affy_groups->get_projects_with_arrays();

    # Now that we've fetched the arrays that have data, prune this based on 
    # which projects the user is allowed to access.  
    my @accessible_projects = $sbeams->getAccessibleProjects();
    my @accessible_array_projects;
    foreach my $proj_ref ( @all_affy_arrays_project ) { 
      push @accessible_array_projects, $proj_ref if grep ( /^$proj_ref->[0]$/, @accessible_projects )
    }


#############################################
## Make form to print all availiable projects
    
    my $project_form;
		
		$project_form .= <<'END';
			<h2 class='grey_bg'> Select Additional Projects To view arrays to include in analysis</h2>
			<FORM NAME="MainForm" METHOD="GET" ACTION=""> 
      <INPUT TYPE=HIDDEN NAME=project_select_change VALUE='FALSE'></INPUT>
			<SELECT NAME="apply_action_hidden" MULTIPLE SIZE=10  onChange="refreshDocument()">	
END
		
		foreach my $proj_array_ref (@accessible_array_projects) {
			my ($proj_id, $user_name__proj_name) = @{$proj_array_ref};
			
			if (grep{ $_ == $proj_id} @additional_project_ids){	#look to see what projects have allready been selected
				$project_form .= "<OPTION SELECTED VALUE='$proj_id'> $user_name__proj_name - ($proj_id)\n";
			}else{
				$project_form .= "<OPTION VALUE='$proj_id'> $user_name__proj_name - ($proj_id)\n";
			}
		}

	$project_form .= join( ' ', "</SELECT>", 
	       "<input type='hidden' name='token' value='". $fm->token() ."'>\n",
	       "<input type='hidden' name='analysis_id' value='$analysis_id'>\n",
	       "</FORM>" );
		
#################################	
	  ## Print the data

		my @array_ids = $affy_o->find_chips_with_data(project_id => $all_project_ids);	#find affy_array_ids in the, could be multipule arrays with differnt protocols usedfor quantification
		  

		my $constraint_data = join " , ", @array_ids;
		my $constraint_column = "afa.affy_array_id";
		my $constraint        = "AND $constraint_column IN ($constraint_data)";

		if ( !$constraint_data ) {
			$project_form .= "<BR><B>No data found for current project\n";
		} else {

      # This will collect STDOUT into a scalar, fetched below with a call 
      # to fetchSTDOUT 
      $sbeams->collectSTDOUT();


		  print "<h2 class='grey_bg'> Please Select the arrays to utilize in the analysis pipeline </h2>";

      # Start the form to choose the arrays 
			print $cgi->start_form( -name   => 'all_arrays', 
				-action => "$CGI_BASE_DIR/Microarray/bioconductor/upload.cgi",
        -onsubmit => 'return check_array_types()' ); 

      $sbeamsMOD->make_checkbox_control_table(
        box_names          => \@downloadable_file_types,
        default_file_types => \@default_file_types,
      );

      $sql = $sbeams_affy_groups->get_affy_arrays_sql(
        project_id => $all_project_ids, #return a sql statement to display all the arrays for a particular project
        constraint => $constraint
      );
      %url_cols = (
        'Sample_Tag' =>"${manage_table_url}affy_array_sample&affy_array_sample_id=\%3V",
        'File_Root' => "${manage_table_url}affy_array&affy_array_id=\%0V",
      );

      %hidden_cols = (
        'Sample_ID' => 1,
        'Array_ID'  => 1,
      );

      # Print out the data
      $rs_params{page_size} = 1000;    #need to override the default 50 row max display for a page
      if ( $apply_action eq "VIEWRESULTSET" ) {
        $sbeams->readResultSet(
          resultset_file       => $rs_params{set_name},
          resultset_ref        => $resultset_ref,
          query_parameters_ref => \%parameters,
          resultset_params_ref => \%rs_params,
        );
      } else {
        # Fetch the results from the database server
        $sbeams->fetchResultSet(
          sql_query     => $sql,
          resultset_ref => $resultset_ref,
        );
      }

      ####################################################################
      # Need to Append data onto the data returned from fetchResultsSet in 
      # order to use the writeResultsSet method to display a nice html table
      unless ( exists $parameters{Display_Data} ) {
        
        my $m_sbeams = SBEAMS::Connection::Merge_results_sets->new();
        
        $m_sbeams->append_new_data( 
          resultset_ref => $resultset_ref,
          file_types    => \@downloadable_file_types,    #append on new values to the data_ref foreach column to add
          default_files => \@default_file_types,
          display_files => \@diplay_files,  #Names for columns which will have urls to pop  open files
          image_url	=> '<a href=View_Affy_files.cgi?action=view_image&affy_array_id=$pk_id&file_ext=$display_file>View</a>',
          text_url	=> '<a href=View_Affy_files.cgi?action=view_file&affy_array_id=$pk_id&file_ext=$display_file>View</a>',
          find_file_object => $sbeams_affy_groups,		#send in an object that has a method called check_for_file that will be called, the method will be called with three arguments
          );
        
      }
        
      ####################################################################
        
      #### Store the resultset and parameters to disk resultset cache
      $rs_params{set_name} = "SETME";
      $sbeams->writeResultSet(
        resultset_file_ref   => \$rs_params{set_name},
        resultset_ref        => $resultset_ref,
        query_parameters_ref => \%parameters,
        resultset_params_ref => \%rs_params,
        query_name           => "$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
      );
        
      #### Set the column_titles to just the column_names
      @column_titles = @{ $resultset_ref->{column_list_ref} };
        
      #print "COLUMN NAMES 1 '@column_titles'<br>";
        
      #### Display the resultset
      $sbeams->displayResultSet(
        resultset_ref        => $resultset_ref,
        query_parameters_ref => \%parameters,
        rs_params_ref        => \%rs_params,
        url_cols_ref         => \%url_cols,
        hidden_cols_ref      => \%hidden_cols,
        max_widths           => \%max_widths,
        column_titles_ref    => \@column_titles,
        base_url             => "$base_url?token=".$fm->token()."&apply_action_hidden=$all_project_ids&analysis_id=$analysis_id",
      );
        

      print $cgi->hidden( -name   => 'token',
                         -default => $fm->token(),),
            $cgi->hidden(-name   =>'analysis_id',
                         -default =>$fm->analysis_id(),),
            $cgi->hidden(-name  =>"apply_action_hidden",
                         -value =>"$all_project_ids"),
            $cgi->hidden(-name   =>'array_type',
                         -value  => 'naiive' ),
            $cgi->hidden(-name   =>'analysis_type',
                         -value  => 'naiive' ),
            $cgi->br,
            $cgi->submit( -name  => 'Submit',
                          -value => 'Add Arrays',
                          -title => 'Make file groups for normalization and analysis',
                          -onclick => "set_analysis_type('file_grouping')" ); 

      my $array_types = get_array_types( $resultset_ref );
      my $exon_types  = get_exon_types();

      print <<"      END";
      <SCRIPT>
        function set_analysis_type(a_type) {
          document.all_arrays.analysis_type.value = a_type;
        }
      function check_array_types(){
        var checkboxes = document.all_arrays.get_all_files;
        $array_types
        var type = 'naiive';
        for ( var i = 0; i < checkboxes.length; i++ ) {
          if ( checkboxes[i].checked ) {
            if ( type == 'naiive' ) {
              type = arraytypes[checkboxes[i].value];
            } else if ( type != arraytypes[checkboxes[i].value] ) {
              // alert and return if we have more than one
              alert ( "All arrays must be of the same type for this analysis" );
              return false;
            }
          }
        }
        if ( type == 'naiive' ) {
          alert( "You must select at least one array" );
          return false;
        }
        document.all_arrays.array_type.value = type;

        // FIXME make this configurable
        var exon_allowed = new Object;
        $exon_types

        var filegroup_allowed = new Object;
        filegroup_allowed['HG-U133_Plus_2'] = true;
        filegroup_allowed['Mouse430_2'] = true;
        filegroup_allowed['YG_S98'] = true;
        filegroup_allowed['HG-Focus'] = true;
        filegroup_allowed['HG_U95A'] = true;
        filegroup_allowed['HG-U133A'] = true;
        filegroup_allowed['HG-U133B'] = true;
        filegroup_allowed['Hu6800'] = true;
        filegroup_allowed['MG_U74Av2'] = true;
        filegroup_allowed['MG_U74Bv2'] = true;
        filegroup_allowed['MG_U74Cv2'] = true;
        filegroup_allowed['HG-U133A_2'] = true;
        filegroup_allowed['Rat230_2'] = true;
        filegroup_allowed['Rhesus'] = true;
        filegroup_allowed['ATH1-121501'] = true;
        filegroup_allowed['Soybean'] = true;
	filegroup_allowed['MoGene-1_0-st-v1'] = true;
	filegroup_allowed['Yeast_2'] = true;

        if ( document.all_arrays.analysis_type.value == 'exon_array_pipeline' ) {
          if ( !exon_allowed[type] ) {
            alert ( "Selected array type " + type + " is not valid for this type of analysis"  );
            return false;
          }
         // No longer going to redirect from here
         // alert( "You will be redirected to the Gene Pattern server for this analysis" );
         // document.all_arrays.action="http://deimos:8081/gptrigger/ExonArrayAnalysis";
 
        } else if ( document.all_arrays.analysis_type.value == 'file_grouping' ) {
          if ( !filegroup_allowed[type] ) {
            alert ( "Selected array type " + type + " is not valid for this type of analysis" );
            return false;
          }
        } else {
// Modified to allow custom CDF processing
//          alert("Unknown analysis type, quitting" );
//          return false;
        }
        return true;
      }
      </SCRIPT>
      END

      # Show a submit button to the exon array pipeline only if we have qualified arrays.
      if ( $sbeamsMOD->show_exon_pipeline && has_exon_arrays( $array_types ) ) {
        print <<"        END";
        <INPUT TYPE=SUBMIT NAME=gpSubmit TITLE='Submit job to GenePattern exon array analysis pipeline' VALUE=Exon_Array_Analysis ONCLICK="set_analysis_type('exon_array_pipeline')"> 
        END
      } elsif ( $sbeamsMOD->show_expression_pipeline() ) {
        print <<"        END";
        <INPUT TYPE=SUBMIT NAME=gpSubmit TITLE='Submit job to GenePattern alternate CDF analysis pipeline' VALUE=Custom_CDF_Analysis ONCLICK="set_analysis_type('custom_cdf_pipeline')"> 
        END
      }
      
      print $cgi->reset;
      
      print $cgi->end_form;
        
      print "<br><h>";
        
      # This returns the collected standard output (and fixes STDOUT)
      my $stdout = $sbeams->fetchSTDOUT(); 
      $project_form .= $stdout;
    }
        
    if ( $fm->filenames() ) {
      
      my $hidetext = '<B>Hide</B>';
      my $showtext = '<B>Show</B>';

      my $toggle = $sbeams->make_toggle_section ( content => $project_form,
                                                  visible => 0,
                                                  textlink => 1,
                                                  sticky => 1,
                                                  imglink => 1,
                                                  hidetext => $hidetext,
                                                  showtext => $showtext,
                                               neutraltext => 'CEL file selection form',
                                                  name => '_project_cel_files',);
      print $toggle;

    } else {
      print $project_form;
    }
      
	}

sub get_array_types {
  my $rs_ref = shift;
  my $dataref = $rs_ref->{data_ref};
  my $colref = $rs_ref->{column_hash_ref};
  my $arraytypes = "var arraytypes = new Object;\n";
  for my $row ( @$dataref ) {
    my $design = $row->[$colref->{'Affy Chip Design'}];
    my $chipname = $row->[$colref->{'Array_ID'}] . '__CEL';
    $arraytypes .= "          arraytypes['$chipname'] = '$design';\n";
  }
  return $arraytypes;
}

sub get_exon_types {
  my @exon_names = exon_array_names();
  my $exon_types = '';
  for my $en ( @exon_names ) {
    $exon_types .= q(exon_allowed[') . $en . q('] = true;) . "\n";
  }
  return $exon_types;
#        exon_allowed['MoEx-10-st-v1'] = true;
}

sub exon_array_names {
  return qw(MoEx-1_0-st-v1 MoEx-10-st-v1 HuEx-1_0-st-v2);
}

sub has_exon_arrays {
  my $array_types = shift;
  my @names = exon_array_names();
  for my $name ( @names ) {
    return 1 if $array_types =~ /$name/;
  }
  return 0;
}

#### Subroutine: start#################################################
# Session new session
#####################################################
sub start_button {
	my ($status, $token) = @_;
	my $tab_number = $cgi->param('_tab')? $cgi->param('_tab'): 5;

  # Switched to manual FORM declaration, start_form method wouldn't allow
  # needed override of '_tab' parameter.
  my $start =<<"  END";
  <FORM ACTION='upload.cgi' enctype="application/x-www-form-urlencoded">
    <INPUT TYPE=hidden NAME='_tab' VALUE=1>
  END
	print table({border=>0},
		  Tr({class=>'grey_bg'},
		    td(
		      h3("Start a New Analysis Session")), 
	      	td( $start, 
	      	  submit("Submit", "Start Session"))),
	      end_form),
	      br;

=head1
    print <<'END';
<h2>Quick Help</h2>

<p>HELP IS OUT OF DATE FROM THE START SUB ROUTINE
The upload manager is used to input files for processing by
Bioconductor. When you start a new session, you are given a token
which allows you to return to that session and access the files
from Bioconductor tools. Once in a session, you may optionally save
that token in a web-browser cookie. The cookie will last for one
week.
</p>

<p>OUT OF DATE
You should consider the upload manager, as well as any results you
create, to be temporary storage. Files will be periodically removed
to prevent the disk from filling up. You can generally count on
files lasting for at least a week, although we do not back them up
so that may not be the case should an unexpected disk failure occur.
Please download and save any results you wish to keep for an extended
period of time. You may always re-upload exprSets or aafTables for
further processing at a later date.
</p>
END
=cut
	return 0;
}

#### Subroutine: filelist#################################################
# Primary file listing screen
#####################################################
sub filelist {
	my ($token) = @_;
	my @filenames = $fm->filenames;
	my $basepath = $fm->path;
	my ($filestat, $size, $date);

	return unless @filenames;
  my $select_changed = $q->param( 'project_select_change' );
  if ( !$select_changed || $select_changed eq 'FALSE' ) {
    $sbeams->unstickToggleSection(stuck_name => '_project_cel_files');
  }
	print h2("Current File Listing"),
	       start_multipart_form(-name=>'Selectedfiles_form'),
	      hidden(-name=>'token', -default=>$fm->token, -override=>1),
	      hidden(-name=>'_tab', -value=>'2'),
	      hidden(-name=>'analysis_id', -value=>$fm->analysis_id),
	      br;
	
	if (@filenames != 0) {
		
		print '<table>',
			  Tr(th(), th('File Name'), th({-colspan=>2}, 'Size (bytes)'), th({-colspan=>2}, 'Date'));
		
		for (my $i = 0; $i < @filenames; $i++) {
			$filestat = stat("$basepath/$filenames[$i]");
      die ("Missing file $i: $basepath/$filenames[$i]") unless $filestat;
			$size = $filestat->size;
			$date = strftime("%a %b %e %H:%M:%S %Y", localtime($filestat->mtime));
			print Tr(td('<input type="checkbox" name="files" value="' . $filenames[$i] . '" CHECKED>'), 
					 td($filenames[$i]), td({-width=>25}),
					 td({-style=>"text-align: right"}, $size), td({-width=>25}),
					 td({-style=>"text-align: right"}, $date));
		}
				
		print '</table><BR>';
	}
	
	#print p(@filenames . " files", br, hr);
	
	if (@filenames != 0) {
	
		print 
			  table({-cellspacing=>2, -cellpadding=>1}, 
					Tr({-class=>"grey_bg"}, td(""), 
					   td(submit("Submit", "Continue File Grouping")),
					   #td(submit(-name=>"Submit", -value=>"Delete Checked Files", -onClick=>'return confirm("Really delete checked files?")')))), 
			td(submit(-name=>"Submit", -value=>"Delete Checked Files", -onclick=>"changetabnumber()")))) 
	}    
	      
	print h3("Proceed to next step, or choose more files below");

	print end_form;	
	
}

#### Subroutine: showjob#################################################
# Show the results from the job that produced the specified file
#####################################################
sub showjob {

	my @filenames = $cgi->param('files');
	my $jobname;
	
	error("You must select a single file to show its job") if (@filenames != 1);
	
	if ($filenames[0] =~ /([a-z]{1,6}-[a-zA-Z0-9]{8})\..+/) {
		$jobname = $1;
	} else {
	    error("That file name does not have an associated job");
	}
	
	opendir(DIR, "$RESULT_DIR/$jobname") ||
	    error("The job results associated with that file no longer exist");
	closedir(DIR);
	
	print $cgi->redirect("job.cgi?name=$jobname");
}

#### Subroutine: affy#################################################
# Use checked files with affy
#####################################################
sub affy {
	#my $parent_analysis_token = shift;
	my $parent_analysis_id = $cgi->param('analysis_id');
	unless ($parent_analysis_id =~ /^\d/){
		error("Cannot find parent analysis id.  affy sub FOUND '$parent_analysis_id' ");
		return;
	}
	my @param_keys = $cgi->param;
	
	my @file_name_keys = grep {/^SG_/} @param_keys;
	my @all_sample_group_names = ();
	my @filenames = ();
	
	my $previous_token = $cgi->param('previous_token');
	
	error("Cannot find previous token FOUND '$previous_token'")unless $previous_token;
	

###Build the file names array and sample group array. Also remove the prefix from sample names
	foreach my $file_name_key (@file_name_keys){
		my $sample_group_name = $cgi->param($file_name_key);
		push @all_sample_group_names, $sample_group_name;
		$file_name_key =~ s/^SG_//;				
		push @filenames, $file_name_key;
	}
	#print "SAMPLE GROUP NAMES FILE NAMES <br>";
	#print Dumper(\@all_sample_group_names, \@filenames);
	unless (scalar @filenames == scalar @all_sample_group_names){
		error("Number of Filenames and Array Sample Groups are not the SAME, Please Fix the Problem");
		return;
	}
	
my  $fm = new FileManager;
### Resgister the start of a normalization run	
	$USER_ID = $affy_o->get_user_id_from_user_name($current_username);
	my $project_id	= $sbeams->getCurrent_project_id();
	#print "PROJECT ID '$project_id' ABOUT TO ENTER NEW NORMALIZATION ANALYSIS<br>";
	my $token = "affynorm-" . rand_token();	
	my $error = create_directory($token);
	error($error) if $error;
	
	
	my $rowdata_ref = {folder_name => $token,
					   user_id => $USER_ID,
					   project_id => $project_id,
					   parent_analysis_id => $parent_analysis_id,
					   affy_analysis_type_id => $affy_o->find_analysis_type_id("normalization"),
					   analysis_description => "Adding New Normalization Session",
					  };
	
	my $analysis_id = $affy_o->add_analysis_session(rowdata_ref => $rowdata_ref);
	my $reference_sample_group = $cgi->param('reference_sample_group');
	error("Could not find reference sample group for xml file") unless $reference_sample_group;
	
### Make XML file to contain the file sample group information
	my $path = "$RESULT_DIR/$token";
	my $xml_out_file = "$path/$SAMPLE_GROUP_XML";
	my $date = `date`;
	my $output = new IO::File(">$xml_out_file");

	my $wr = new XML::Writer (  OUTPUT => $output, DATA_MODE => 'true', DATA_INDENT => 2, NEWLINED => 'true' );

	$wr->startTag('file_sample_group_info');
		
		$wr->startTag('date');
			$wr->characters($date);
		$wr->endTag();
		$wr->startTag('analysis_id');
			$wr->characters($analysis_id);
		$wr->endTag();
		$wr->startTag('previous_token',  'analysis_id'=>$parent_analysis_id);
			$wr->characters($previous_token);
		$wr->endTag();
#add in the name of the sample that can be considered the reference sample
		$wr->startTag('reference_sample_group');
			$wr->characters($reference_sample_group);
		$wr->endTag();
		
		$wr->startTag('sample_groups');
			for (my $i=0; $i <= $#filenames ; $i++){
				my $filename = $filenames[$i];
				my $sample_group_name = $all_sample_group_names[$i];
				
				$wr->startTag('file_name', 'sample_group_name'=>$sample_group_name);
					$wr->characters($filename);
				$wr->endTag();
			}
		$wr->endTag();
	$wr->endTag();
			
	$wr->end();
	$output->close();


	my $default_names = $cgi->param( 'default_sample_names' ) || '';
  if ( $default_names ) {
    $default_names = "&default_sample_names=$default_names";
  }

  
###Redirect to the Affy Script page
	my $url = "affy.cgi?step=1&files_token=$previous_token&numfiles=" . @filenames;
	$url .= "&normalization_token=$token&analysis_id=$analysis_id${default_names}";
	
	#print "URL TO REDIR TO '$url'<br>";
	error("You must select at least one file for affy") if (!@filenames);
	
	print $cgi->redirect($url);
}


#+
# launch_gp_pipeline 
#
# Subroutine builds a form to collect info prior to launching off to GP trigger
# resource.  Initally just for exon arrays, now to be used for alternative CDF
# normalization of expression arrays as well.
#-
sub launch_gp_pipeline {

# create normalization record
# print form with action => deimos
# sayonara!

# Sort out the parameters that were sent over.
	my $parent_analysis_id = $cgi->param('analysis_id');
	unless ($parent_analysis_id =~ /^\d/){
		error("Cannot find parent analysis id.  affy sub FOUND '$parent_analysis_id' ");
		return;
	}
	my @param_keys = $cgi->param;
	
	my @sample_groups = ();
	my @filenames = $cgi->param('get_all_files');
	
	my $parent_token = $cgi->param('token');
	
  my $analysis_type = $cgi->param('analysis_type');
  my $array_type = $cgi->param('array_type');
  my $submit = $cgi->param('gpSubmit');

  # Need global $fm...
  $fm = new FileManager;
  $fm->init_with_token($Site::BC_UPLOAD_DIR, $parent_token);

# Write symlinks into analysis directory, returns info -> root mapping hash
  my $file_root = upload_files();

#  my @p = $q->param();
#  for my $p ( @p ) { $log->debug( "param: $p => " . $q->param($p) ); }
  
  # We haven't gone through the grouping process, use a constant value here.
  my $sample_group = 'normalization_only';
	my $reference_sample_group = $sample_group;
	
  ### Resgister the start of a normalization run	
	my $user_id = $affy_o->get_user_id_from_user_name($current_username);
	my $project_id	= $sbeams->getCurrent_project_id();

  # Create new directory/bioC token 
	my $token = "affynorm-" . rand_token();	
  my $analysis_id = 123456;
	my $error = create_directory($token);
	error($error) if $error;

  my $desc = ( $analysis_type =~ /exon_array/ ) ? "Exon Array Normalization" :
	                                                "Custom CDF Normalization";
  
  # Create analysis record in the database.
	my $rowdata_ref = {folder_name => $token,
					   user_id => $user_id,
					   project_id => $project_id,
					   parent_analysis_id => $parent_analysis_id,
					   affy_analysis_type_id => $affy_o->find_analysis_type_id("normalization"),
					   analysis_description => $desc,
					  };
	
	my $analysis_id = $affy_o->add_analysis_session(rowdata_ref => $rowdata_ref);
	
  # create some semblance of an XML grouping file
	my $path = "$RESULT_DIR/$token";
	my $xml_out_file = "$path/$SAMPLE_GROUP_XML";
	my $date = `date`;
	my $output = new IO::File(">$xml_out_file");

	my $wr = new XML::Writer (  OUTPUT      => $output, 
                              DATA_MODE   => 'true', 
                              DATA_INDENT => 2, 
                              NEWLINED    => 'true' );

	$wr->startTag('file_sample_group_info');
		
		$wr->startTag('date');
			$wr->characters($date);
		$wr->endTag();
		$wr->startTag('analysis_id');
			$wr->characters($analysis_id);
		$wr->endTag();
		$wr->startTag('previous_token',  'analysis_id'=>$parent_analysis_id);
			$wr->characters($parent_token);
		$wr->endTag();
		$wr->startTag('reference_sample_group');
			$wr->characters($reference_sample_group);
		$wr->endTag();
		
		$wr->startTag('sample_groups');
			for (my $i=0; $i <= $#filenames ; $i++){
				my $filename = $filenames[$i];
				my $sample_group_name = $sample_group;
				
				$wr->startTag('file_name', 'sample_group_name'=>$sample_group_name);
					$wr->characters($filename);
				$wr->endTag();
			}
		$wr->endTag();
	$wr->endTag();
			
	$wr->end();
	$output->close();

## Print form with mapping database select list, submits to exon pipeline
  # Gather missing params and other values
  my %cookie = $q->cookie( 'SBEAMSName' );
  my $cookie = $q->cookie( -name => 'SBEAMSName',
                           -path => $HTML_BASE_DIR,
                          -value => \%cookie );

  my $email = $sbeams->getEmailAddress() || $sbeams->getCurrent_username();
  my $db_map_select = get_db_map_select();
  my $map_version_select = get_map_version_select();
  my $map_norm_method_select = get_norm_method_select();
  my $file_input = '';
  for my $file ( @filenames ) {
    $file_input .= "<INPUT TYPE=hidden NAME=get_all_files VALUE=$file>\n";
#    $file_input .= "<INPUT TYPE=hidden NAME=file_root VALUE=$file_root->{$file}>\n";
    $file_input .= "<INPUT TYPE=hidden NAME=file_info VALUE='$file_root->{$file}::::$file'>\n";
  }
#  my $gp_trigger_URL='http://deimos:8081/gptrigger/ExonArrayAnalysis';
#  my $gp_trigger_URL='/devDC/sbeams/cgi/showparams.cgi';
  my $gp_trigger_URL = $sbeamsMOD->get_gp_URI() || '';

  # Calculate server 'root', $q doesn't have exactly what we need...
  my $path = $HTML_BASE_DIR;
  $path = '/' . $path unless $HTML_BASE_DIR =~ /^\//;
  my $url = $q->url( -base => 1 ) . $path;

  my $cdf_types = $sbeamsMOD->get_custom_cdf_types();
  $array_type = $cdf_types->{$array_type} || $array_type;
  
  # Assemble FORM HTML
  my $gp_pipeline_form =<<"  END_FORM";
  You are submitting a job to the Gene Pattern analysis pipeline, please select a mapping
  database.  This is the database to which the array probe sequences will be mapped 
  for this analysis.
  <BR>
  <BR>
  <FORM NAME=gp_exon_array ACTION='$gp_trigger_URL' METHOD=POST>
  <TABLE>
  <TR><TD ALIGN=right><B>Mapping database:</B></TD><TD ALIGN=left> $db_map_select</TD></TR>
  <TR><TD ALIGN=right><B>Mapping version:</B></TD><TD ALIGN=left> $map_version_select</TD></TR>
  <TR><TD ALIGN=right><B>Normalization Method</B></TD><TD ALIGN=left>$map_norm_method_select</TD></TR>
  </TABLE>
  <BR>
  <BR>
  $file_input
  <INPUT TYPE=hidden NAME=CEL_token VALUE='$parent_token'>
  <INPUT TYPE=hidden NAME=parent_analysis_id VALUE='$parent_analysis_id'>
  <INPUT TYPE=hidden NAME=normalization_token VALUE='$token'>
  <INPUT TYPE=hidden NAME=analysis_id VALUE='$analysis_id'>
  <INPUT TYPE=hidden NAME=project_id VALUE='$project_id'>
  <INPUT TYPE=hidden NAME=user_email VALUE='$email'>
  <INPUT TYPE=hidden NAME=cookie VALUE='$cookie'>
  <INPUT TYPE=hidden NAME=array_type VALUE='$array_type'>
  <INPUT TYPE=hidden NAME=sbeams_server VALUE='$url'>
  <INPUT TYPE=hidden NAME=analysis_type VALUE='$analysis_type'>
  <INPUT TYPE=submit NAME=gpSubmit VALUE='Submit job'><INPUT TYPE=reset>
  </FORM>
  END_FORM
 
  # Send it back for rendering
  return $gp_pipeline_form;
}

#+
# Returns select list with current Exon array mapping dbs
#-
sub get_norm_method_select {
  my $select =  "<SELECT NAME=normalization_method>\n";
  for my $k ( qw(RMA GC-RMA Plier) ) {
    $select .= "<option value=$k>$k</option>\n";
  }
  $select .=  "</SELECT>\n";
  return $select;
}

#+
# Returns select list with current Exon array mapping dbs
#-
sub get_db_map_select {
  my $dbs = $sbeamsMOD->get_cdf_dbs();
  my $order = $sbeamsMOD->get_cdf_db_order();
  my $select =  "<SELECT NAME=db_name>\n";
  my $selected = 'SELECTED'; # Will select the first
  for my $k ( @$order ) {
    $select .= "<option value=$k $selected>$dbs->{$k}</option>\n";
    $selected = '';
  }
  $select .=  "</SELECT>\n";
  return $select;
}

#### Subroutine: multtest#################################################
#+
# Returns select list with current Exon array mapping dbs
#-
sub get_map_version_select {
  my $dbs = $sbeamsMOD->get_cdf_versions();
  my $order = $sbeamsMOD->get_cdf_version_order();
  my $select =  "<SELECT NAME=db_version>\n";
  my $selected = 'SELECTED'; # Will select the first
  for my $k ( @$order ) {
    $select .= "<option value=$k $selected>$dbs->{$k}</option>\n";
    $selected = '';
  }
  $select .=  "</SELECT>\n";
  return $select;
}

#### Subroutine: multtest#################################################
# Use checked file with multtest
#####################################################
sub multtest {
	my $token = shift;
	my @filenames = $cgi->param('files');
	my $url = "multtest.cgi?step=1&token=$token";
	
	error("You must select only one file for multtest") if (@filenames != 1);
	
	$url .= '&file=' . $filenames[0];
	
	print $cgi->redirect($url);
}

#### Subroutine: annaffy#################################################
# Use checked file with annaffy
#####################################################
sub annaffy {
	my $token = shift;
	my @filenames = $cgi->param('files');
	my $url = 'annaffy.cgi?token=' . $fm->token;
	
	error("You must select only one file for annaffy") if (@filenames != 1);
	
	$url .= '&file=' . $filenames[0];
	
	print $cgi->redirect($url);
}

#### Subroutine: error#################################################
# Print out an error message and exit
#####################################################
sub error {
    my ($error) = @_;

	print $cgi->header;    
	site_header("Upload Manager");
	
	print h1("Upload Manager"),
	      h2("Error:"),
	      p($error);
	
	foreach my $key ($cgi->param){
		
		print "$key => " . $cgi->param($key) . "<br>";
	}
	
	exit(1);
}

# Return a list of 'submit' types that require write access
sub write_ops {
  my $submit = shift || return;
  return ( 'Complete File Grouping',
           'Continue File Grouping',
           'Exon_Array_Analysis',
           'multtest',
           'annaffy',
		       'files_sample_group_pairs',
		       'Submit Group Names',
		       'Start Session',
		       'Add Arrays' );
}

# Return a list of 'submit' types that require write access
sub modify_ops {
  my $submit = shift || return;
  return ( 'Delete Checked Files',
           'Delete Analysis Run'
         );
}

###############################################################################
# make_group_arrays_form
#
# Make a form to allow users to group arrays and select an array to be used as the reference sample
###############################################################################
sub make_group_arrays_form{
	
	my $number_of_sample_groups = 2;	#default to two sample groups, will most likly be changed below
	my @all_sample_group_names = ();
	my @sample_group_names = ();
	my @files = $cgi->param('files');
	my $token = $cgi->param('token');
	my $analysis_id = $fm->analysis_id();
	
	#print "ANALYSIS ID '$analysis_id'<br>";
		
###Find the sample group names 
	if ($cgi->param('all_sample_group_names') ) {
		@all_sample_group_names = $cgi->param('all_sample_group_names');
	}else{
		@all_sample_group_names = $affy_o->find_sample_group_names(cel_file_names => \@files );
	}
	unless (@all_sample_group_names){
		print "ERROR:Cannot Find Any Sample Group Names<br>";
		return;
	}

  my $sample_group_form = '';
	
###Find the number of sample groups
	if($cgi->param('number_of_groups')){
		$number_of_sample_groups = $cgi->param('number_of_groups');
		my @names  = $cgi->param('sample_group_names');
		my @groups = $cgi->param('sample_group_order');
		
		@sample_group_names = order_sample_groups (sample_group_names => \@names,
												   sample_group_order => \@groups,
												  );
				
	}else{
		@sample_group_names = condense_sample_groups(@all_sample_group_names);
		$number_of_sample_groups = scalar @sample_group_names;
	}
	
  $sbeams->unstickToggleSection(stuck_name => '_project_cel_files');
###Make the form to control the number of sample groups
	$sample_group_form .= "<h2 class='grey_bg'>Choose the number of Sample Comparison Groups</h2>\n<br>";
	
	
			
	if ($number_of_sample_groups > 0){
		$sample_group_form .= $cgi->start_form(-name => 'number_option_groups');
		$sample_group_form .= join( ' ', $cgi->hidden(-name=>'files', -values=>\@files),
		$cgi->hidden(-name=>"_tab", -value=>'2'),
		$cgi->hidden(-name=>"all_sample_group_names", -value=>\@all_sample_group_names),
		$cgi->hidden(-name=>"token", -value=>$token),
		$cgi->hidden(-name=>"analysis_id", -value=>$analysis_id) );
		
		$sample_group_form .= $cgi->textfield(-name		=> 'number_of_groups',
                             -default	=> $number_of_sample_groups,
                             -size   	=> 10,
                             -maxlength => 3,
					 		 -onChange  =>"javascript:document.number_option_groups.submit();");
	}else{
		$sample_group_form .= "ERROR: Cannot find the number of sample groups<br>";
    print $sample_group_form;
		return;
	}
	
	
###Print out the Sample Group Names form elements
	$sample_group_form .= qq~ <h2 class='grey_bg'>Sample Groups</h2> <br>
		  	<table border=0>
		 	  <tr>
		 	    <td>Group</td>
		 	    <td>Order</td>
		 	    <td>Sample Group Name</td>
		 	    <td>Reference Sample *</td>
		  ~;

	#my @sample_group_order = split /,/, $cgi->param('sample_group_order');	#should return a comma seperated list of numbers
	
	#print "SAMPLE GROUP ORDER NUMBERS '@sample_group_order'";	
	for (my $i = 0; $i < $number_of_sample_groups; $i++){
		
		my $default_name = $sample_group_names[$i] ? $sample_group_names[$i] : "Default Sample Group $i";
		
		my $checked_html = "CHECKED" if ($i == 0);
		$sample_group_form .= Tr(
				td({class=>'grey_bg'}, "Sample Group"),
				td($cgi->textfield(-name=>"sample_group_order",
                            	   -default	=> $i + 1,
                            	   -size   	=> 3,
                            	   -maxlength	=>2,
                                 -override => 1,
					 		                   -onChange  =>"javascript:document.getElementById('Submit').disabled=true;",
				 			       )),
				td($cgi->textfield(-name=>'sample_group_names',
                            	   -default	=> "$default_name",
                            	   -size   	=> 30,
                            	   -maxlength	=>50,
				 			   	               -override => 1,
					 		                   -onChange  =>"javascript:document.getElementById('Submit').disabled=true;",
				 			       )),
				 			       
				td("<input type='radio' name='reference_sample_group' value='$default_name' $checked_html>"),
			   );
		
	}
	
	$sample_group_form .= "</table>";
	
	$sample_group_form .= join( " ", br,
		  $cgi->submit(-name=>"update_order", 
		  			   -value=>"Update Order",
		  			   -onClick=>"javascript:document.number_option_groups.submit()"
		  			   ),
		  $cgi->submit(-name=>"Submit", 
                   -value=>"Submit Group Names",
                   -Id=>"Submit"),
		  br,
		  $cgi->end_form() );
	
	$sample_group_form .= <<END;
 <p>The Reference Sample, will be compared to all additional samples groups provided if you whish to run t-test
between two different sample groups.
The "control group" should almost always be the Reference Sample, 
so that positive Log ratios indicate
increased expression in the experimental group and vice versa.
</p>
<p>Please Click "Update Order" if the Sample Group Names are changed</p>
* Please note that the reference sample can be ignored at the analysis so just two sample groups can be compared
to one another.  
</p>
END
	
	#print "NUMBER OF GROUPS '$number_of_sample_groups'<br>";
	
###Print out the radio buttons to pair up sample groups to file names	
	if ($cgi->param('Submit') eq 'Submit Group Names'){
#Group and order the files within the different sample groups	
		my ($ordered_files_aref, $ordered_all_sample_groups_aref) = 
		order_all_files(files_names 	  => \@files,
						all_sample_groups => \@all_sample_group_names,
						sample_groups	  => \@sample_group_names,
						);		 
		
		my @ordered_files = @$ordered_files_aref;
		my @ordered_all_sample_groups = @$ordered_all_sample_groups_aref;
		
    my $group_member_form = '';
		$group_member_form .= "<h2 class='grey_bg'>Select the File Sample groups</h2><br>";
				
		$group_member_form .= join( '', $cgi->start_form(-name => 'file_groups', -method => 'POST'),
			  $cgi->hidden(-name=>"_tab", -value=>'2'),
			  $cgi->hidden(-name=>"previous_token", -value=>$token),
			  $cgi->hidden(-name=>"analysis_id", -value=>$analysis_id),
			  $cgi->hidden(-name=>"reference_sample_group", -value=>$cgi->param('reference_sample_group') ) );
		
		$group_member_form .= "<table border=1>\n";
		
		for(my $i; $i<=$#ordered_files; $i++){
			my $file = $ordered_files[$i];
			my $escaped_file_name = $file;
			$escaped_file_name =~ s/\+/%2B/g; #users wanted to use + in file names it needs to be escaped for the cgi page to work correctly
			$group_member_form .= Tr(
						td({class=>'grey_bg'}, "$file"),
						td( $cgi->radio_group(-name=>"SG_$escaped_file_name",
	                             -values=>\@sample_group_names,
	                             -default=>$ordered_all_sample_groups[$i],
	                             )),
	                );       
		}
		$group_member_form .= "</table><br>";	
    $group_member_form .= <<"    END";
        <B>Default sample names:</B> 
          <INPUT TYPE="radio" NAME="default_sample_names" VALUE="sample_tag" CHECKED>Sample Tag
          <INPUT TYPE="radio" NAME="default_sample_names" VALUE="file_root"> File Root
          <BR><BR>
    END

    my $info = h3("Complete file grouping, or change group info below<BR>");

		$group_member_form .= $cgi->submit(-name=>"Submit", -value=>"Complete File Grouping") .	
		 	                    $cgi->end_form() . $info;

    my $hidetext = '<B>Hide</B>';
    my $showtext = '<B>Show</B>';


    my $toggle = $sbeams->make_toggle_section ( content => $sample_group_form,
                                                visible => 0,
                                                textlink => 1,
                                                imglink => 1,
                                                hidetext => '<B>Hide</B>',
                                                showtext => '<B>Show</B>',
                                             neutraltext => 'Sample grouping form',
                                                name => 'sample_group_form');
      print $group_member_form . '<BR>';
      print $toggle;
        
	} else {
    print "$sample_group_form";    
  }
}

###############################################################################
# order_all_files
#
# group and order the file names within sample groups
###############################################################################
sub order_all_files{
	my %args = @_;
	
  # Files in order from cgi params
	my @files = @{ $args{files_names} };
  
  # Sample groups in order from db
	my @all_sample_group_names = @{ $args{all_sample_groups} };

  # groups defined by user
	my @user_sample_groups 	   = @{ $args{sample_groups} };

  my %file_names_groups_h = ();
  #make a hash from the two arrays....tricky
  @file_names_groups_h{@files} = @all_sample_group_names;
	
  my @final_file_order = ();
  my @final_groups_order = ();
	 
	 
  #Need to out put a list of all the file names and a array of what
  #sample group each file belongs to.  This will be used to make the list
  #of radio buttons to allow the user to select which sample belongs to each group.
	
  #If the user changes the sample group names there is no way to figure out what
  #file belongs to which sample group.  So if a group is missing or changes to
  #who knows what group the files under the unknown Group

  # Modified 6/2006 to maintain user specified group order.
  my %groups_to_files;
 
  foreach my $file_name (keys %file_names_groups_h ){
    my $orginal_group_name = $file_names_groups_h{$file_name};
    my $new_group = '';
		
    foreach my $user_group_name (@user_sample_groups){
      if ($user_group_name eq $orginal_group_name){
      # print "Matched original to user group name '$orginal_group_name'\n";
      $new_group = $orginal_group_name;
      last;
      }
    }
		
    $new_group ||= 'Unknown';
		
    push @final_groups_order, $new_group ;
    push @final_file_order, $file_name;
    $groups_to_files{$new_group} ||= [];
    # Push each file into an arrayref keyed by its group
    push @{$groups_to_files{$new_group}}, $file_name;
	}
	
	my %final_h = ();
	@final_h{@final_file_order} = @final_groups_order;
	
	my @final_file_order_sorted = ();
	my @final_groups_order_sorted = ();
	
  # loop through user-ordered groups
  for my $group ( @user_sample_groups ){
    
    # User defined groups won't have any files
    next unless ref( $groups_to_files{$group} ) eq 'ARRAY';

    # Loop through files in a particular group, adding them
    for my $file ( @{$groups_to_files{$group}} ){
      push @final_file_order_sorted, $file;
      push @final_groups_order_sorted, $group;
    }
  }
	
  # If the user specified a number of groups smaller than the original, we have
  # to push the extras on the end.
  for my $file ( @files ) {
    unless ( grep /$file/, @final_file_order_sorted ) {
      push @final_file_order_sorted, $file;
    }
  }
#  $log->debug("FINAL FILE ORDER". Dumper(\@final_file_order_sorted));
	
  unless (  @final_file_order_sorted == @files) {
    error("Mismatch in the number of files selected.") 
  }
		
		
  return (\@final_file_order_sorted, \@final_groups_order_sorted);
}

###############################################################################
# order_sample_groups
#
# Order the sample groups according to the users input 
###############################################################################
sub order_sample_groups{
	my %args = @_;
	my @sample_group_names = @{ $args{'sample_group_names'} };
	my $sample_group_order_aref =  $args{'sample_group_order'};
	return @sample_group_names unless ($sample_group_order_aref);
	
	my @ordered_names = ();
	my %sort_index = ();
#generate a map of orginal index order of the sample_group_order.
	for (my $i=0; $i < @$sample_group_order_aref ; $i++){
		$sort_index{$sample_group_order_aref->[$i]} = $i;  #group sort number => orginal index number
	}	
	my @sorted_keys = sort{ $a<=> $b} keys %sort_index;
	
	foreach my $key (@sorted_keys){
		my $index_number = $sort_index{$key};
		my $group_name = $sample_group_names[$index_number]; 
		push @ordered_names, $group_name;
	}
	
	unless (@ordered_names == @sample_group_names){
		error("Sorry:The order of the sample groups was confusing.  Please check the numbers and try again");
	} 
	
	return @ordered_names;
	
}
###############################################################################
# show_previous_analysis_groups
#
# Shows previous folders containing analysis sessions
###############################################################################

sub show_previous_analysis_groups{
	
	
	my $folder_names_aref = $data_analysis_o->check_for_analysis_data_type(analysis_name_type => 'differential_expression');
	if  ($folder_names_aref  == 0){															 
		print "Sorry No Previous analysis sessions<br>";
		return;
	}
	
##fm instance might not exists yet if this is a new browser and we are just looking at previous data runs
	unless (ref($fm)){
		 $fm = new FileManager;
	}
	my $html = qq~  
				<table>
				<tr class="grey_bg">
				 <th>Analysis Info</th>
				 <th>Normalization Group Info</th>
				 <th>User Name</th>
				 <th>Analysis Date</th>
				 <th>Show Analysis Page</th>
				 <th>Has Analysis Data</th>
				 <th>Number of files</th>
				 <th>User Description</th>
				 <th>Analysis Description</th> 
				</tr>
				~;
				

	foreach my $folder (@$folder_names_aref){
	
		unless ( $fm->init_with_token($Site::BC_UPLOAD_DIR, $folder)) {
			next;
		}
		my @filenames = $fm->filenames();
		my $file_count = scalar @filenames;
		my $has_norm_data = (grep {/aafTable/} @filenames) ? "Yes":"No";
		
		
		
		my ($analysis_id, 
			$user_desc, 
			$analysis_desc, 
			$parent_analysis_id,
			$analysis_date,
			$username) = $data_analysis_o->get_analysis_info(
											analysis_name_type => 'differential_expression',
											folder_name => $folder,
											info_types	=> ["analysis_id",
															"user_desc", 
															"analysis_desc", 
															"parent_analysis_id",
															"analysis_date",
															"user_login_name"],
											truncate_data => 1,
											);               
	
		$html .= qq~
					   <tr>
						<td><a class='edit_menuButton' href="${manage_table_url}affy_analysis&affy_analysis_id=$analysis_id">Edit Info</a></td>
						<td><a class='edit_menuButton' href="${manage_table_url}affy_analysis&affy_analysis_id=$parent_analysis_id">Edit Norm. Info</a></td>
						<td>$username</td>
						<td>$analysis_date</td>
						<td><a href="?show_analysis_files=1&token=$folder&_tab=3">Show files</a></td>
						<td>$has_norm_data</td>
						<td> $file_count Files</td>
						<td>$user_desc</td>
					   	<td>$analysis_desc</td>
					   </tr>
					~;
					
		
	}
	print $html;
	print "</table>";
	
}
###############################################################################
# condense_sample_groups
#
# look through all the sample groups and return the unique names as an array
#
###############################################################################
sub condense_sample_groups{
	my @all_sample_group_names = @_;
	my %unique_names = ();
	foreach my $group_name (@all_sample_group_names){
		if (exists $unique_names{$group_name}){
			$unique_names{$group_name}++;
		}else{
			$unique_names{$group_name} = 1;
		}
	}
	return (sort keys %unique_names);
}
###############################################################################
# show_previous_file_groups
#
# upload the files requested by the user to a particular direcotry
###############################################################################

sub show_previous_file_groups{
	
	
	my $folder_names_aref = $data_analysis_o->check_for_analysis_data_type(analysis_name_type => 'file_groups');
	unless (ref($folder_names_aref)){
		print "Sorry No Previous analysis sessions<br>";
	}
	
##fm instance might not exists yet if this is a new browser and we are just looking at previous data runs
	unless (ref($fm)){
		 $fm = new FileManager;
	}
	my $html = qq~  
				<table>
				<tr class="grey_bg">
				 <th>Analysis Info</th>
				 <th>User Name</th>
				 <th>Analysis Date</th>
				 <th>Show Files</th>
				 <th>Number of files</th>
				 <th>User Description</th>
				 <th>Analysis Description</th> 
				</tr>
				~;
				
	foreach my $folder (@$folder_names_aref){
	
	
		
		unless ( $fm->init_with_token($Site::BC_UPLOAD_DIR, $folder)) {
			next;
		}
		my $file_count = scalar $fm->filenames();
		
		my ($analysis_id, 
			$user_desc, 
			$analysis_desc,
			$analysis_date,
			$username) = $data_analysis_o->get_analysis_info(
											analysis_name_type => 'file_groups',
											folder_name => $folder,
											info_types	=> ["analysis_id",
															"user_desc", 
															"analysis_desc",
															"analysis_date",
															"user_login_name"],
											truncate_data => 1,
											);               
	
		$html .= qq~
					   <tr>
						<td><a class='edit_menuButton' href="${manage_table_url}affy_analysis&affy_analysis_id=$analysis_id">Edit</a></td>
						<td>$username</td>
						<td>$analysis_date</td>
						<td><a href="?token=$folder&analysis_id=$analysis_id">Show files</a></td>
						<td> $file_count Files</td>
						<td>$user_desc</td>
					   	<td>$analysis_desc</td>
					   </tr>
					~;
					
		
	}
	print $html;
	print "</table>";
	
}

###############################################################################
# show_previous_normalization_groups
#
# Shows previous folders containing normalization sessions
###############################################################################

sub show_previous_normalization_groups{
	
	
	my $folder_names_aref = $data_analysis_o->check_for_analysis_data_type(analysis_name_type => 'normalization');
	unless (ref($folder_names_aref)){
		print "Sorry No Previous analysis sessions<br>";
	}
	
##fm instance might not exists yet if this is a new browser and we are just looking at previous data runs
	unless (ref($fm)){
		 $fm = new FileManager;
	}
	my $html = qq~  
				<table>
				<tr class="grey_bg">
				 <th>Analysis Info</th>
				 <th>File Group&nbsp;Info</th>
				 <th>User Name</th>
				 <th>Analysis Date</th>
				 <th>Show Normalization Page</th>
				 <th>Has Normalized Data</th>
				 <th>Number of files</th>
				 <th>User Description</th>
				 <th>Analysis Description</th> 
				</tr>
				~;
				
	foreach my $folder (@$folder_names_aref){
	
		unless ( $fm->init_with_token($Site::BC_UPLOAD_DIR, $folder)) {
			next;
		}
		my @filenames = $fm->filenames();
		my $file_count = scalar @filenames;
		my $has_norm_data = (grep {/exprSet/} @filenames) ? "Yes":"No";
		
		
		
		my ($analysis_id, 
			$user_desc, 
			$analysis_desc, 
			$parent_analysis_id,
			$analysis_date,
			$username) = $data_analysis_o->get_analysis_info(
											analysis_name_type => 'normalization',
											folder_name => $folder,
											info_types	=> ["analysis_id",
															"user_desc", 
															"analysis_desc", 
															"parent_analysis_id",
															"analysis_date",
															"user_login_name"
															],
											truncate_data => 1,
											);               
	
		$html .= qq~
					   <tr>
						<td><a class='edit_menuButton' href="${manage_table_url}affy_analysis&affy_analysis_id=$analysis_id">Edit</a></td>
						<td><a class='edit_menuButton' href="${manage_table_url}affy_analysis&affy_analysis_id=$parent_analysis_id">Edit Group</a></td>
						<td>$username</td>
						<td>$analysis_date</td>
						<td><a href="?show_norm_files=1&token=$folder&_tab=2">Show files</a></td>
						<td>$has_norm_data</td>
						<td> $file_count Files</td>
						<td>$user_desc</td>
					   	<td>$analysis_desc</td>
					   </tr>
					~;
					
		
	}
	print $html;
	print "</table>";
	
}


###############################################################################
# upload_files
#
# upload the files requested by the user to a particular direcotry
###############################################################################
sub upload_files {
  my @array_file_names = $cgi->param('get_all_files');
  my $path = $fm->path();
  my $return;
  my %file_root;

  foreach  my $array_info (@array_file_names){
    my ($array_id, $file_ext) = split /__/, $array_info;  #example array_info "134__CEL"
    my ($affy_file_root, $file_path) =	$sbeams_affy_groups->get_file_path_from_id(affy_array_id=>$array_id);
    my $cel_file = "$file_path/$affy_file_root.$file_ext";
    #my $out_path = "$path/$affy_file_root.$file_ext";
    my $out_path = "$path/$affy_file_root.$file_ext";
		
    my $command_line = "ln -s $cel_file $path";
    #print "ln COMMAND LINE $command_line<br>";
    $return = system($command_line);
    $file_root{$array_info} = $affy_file_root;
  }
  return ( \%file_root ); 
}

###############################################################################
# display_files
#
# Show the files within an analysis Directory
###############################################################################
sub display_files {

	my %args = @_;
	my $analysis_name_type = $args{analysis_name_type};
	my @filenames = $fm->filenames();
	my $token = $fm->token();
	
#	$log->debug("PATH '" . $fm->path());
# $log->debug("FILES '@filenames'");
	my ($analysis_id, $user_desc, $analysis_desc, $parent_analysis_id) = $data_analysis_o->get_analysis_info(
											analysis_name_type => $analysis_name_type,
											folder_name => $token,
											info_types	=> ["analysis_id","user_desc", "analysis_desc", "parent_analysis_id"],
											);

	my $start_analysis_run_html = '';
### Make html chunk if this is a normalization analysis_name_type
		if ($analysis_name_type eq 'normalization'){
			$start_analysis_run_html =
			Tr(
			  td({class=>'grey_header', colspan=>'2'}, "Start Additional Analysis"),
			);
			$start_analysis_run_html .= 
			Tr(
			  td({class=>'grey_bg'}, "Multipule t-test"),
			  td("<a href='$multtest_url?token=$token&file=$token.exprSet&step=1'>Start Multtest</a>"),
			 );
			$start_analysis_run_html .= 
			Tr(
			  td({class=>'grey_bg'}, "Process file to view in Mev"),
			  td("<a href='$make_java_files_url?token=$token'>Start Mev</a>"),
			 );
			$start_analysis_run_html .=
			Tr(
			  td({class=>'grey_header', colspan=>'2'}, "Prepare GEO Submission"),
			);
			$start_analysis_run_html .= 
			Tr(
			  td({class=>'grey_bg'}, "Create GEO submission file"),
			  td("<a href='$geo_submission_url?token=$token'>Prepare GEO submission</a>"),
			 );
		}elsif($analysis_name_type eq 'differential_expression'){
			$start_analysis_run_html =
			Tr(
			  td({class=>'grey_header', colspan=>'2'}, "Add Results to Get Expression"),
			);
			$start_analysis_run_html .= 
			Tr(
			  td({class=>'grey_bg'}, "Add Data"),
			  td(table({-border=>0},
				  Tr(
				   th({class=>'grey_bg'}, "Link"),
				   th({class=>'grey_bg'}, "Info")
				  ),
				  Tr(
				   td("<a href='$CGI_BASE_DIR/Microarray/bioconductor/Upload_affy_get_expression_data.cgi?token=$token'>Add Data Link</a>"),
				   td("Add data to the get expression table<br>GetExprssion allows different data sets to be combined and view in Cytoscape or other programs")
				  )
				 ), #close the mini-table
				),  #close the cell
			  );#close the row
		
      my $gaggle_link =
      Tr(
        td({class=>'grey_header', colspan=>'2'}, "Add Results to Gaggle Express"),
      );
      $gaggle_link .= 
      Tr(
        td({class=>'grey_bg'}, "Add Data"),
        td(table({-border=>0},
          Tr(
            th({class=>'grey_bg'}, "Link"),
            th({class=>'grey_bg'}, "Info")
          ),
          Tr(
            td("<a href='$CGI_BASE_DIR/Microarray/fetchConditionFile?action=initialize;token=$token'>Add Gaggle Data</a>"),
            td("Store experimental data using the DataLoader")
          )
        ), #close the mini-table
      ),  #close the cell
    );#close the row

    $start_analysis_run_html .= $gaggle_link if 0;

		}
	
	
	print $cgi->table({border=>0},
			Tr(
			  td({class=>'grey_header', colspan=>'2'}, "Analysis Run Info"),
			),
			Tr(
			  td({class=>'grey_bg'}, "Edit Data"),
			  td("<a target='Win1' class='edit_menuButton' href='${manage_table_url}affy_analysis&affy_analysis_id=$analysis_id'>Edit Analysis Description</a>"),
			),
			Tr(
			  td({class=>'grey_bg'}, "Parent Analysis Data"),
			  td( ($parent_analysis_id =~ /^\d/)? "<a class='edit_menuButton' href='${manage_table_url}affy_analysis&affy_analysis_id=$parent_analysis_id'>Edit Parent Analysis Description</a>" : "No Data"),
			),
			#make delete button
			Tr(
			  td({class=>'grey_bg'}, "Delete Analysis Run"),			
			  td($cgi->start_form(-name => 'delete_run'),
			     hidden('delete_sub', 'GO'),
			     hidden('analysis_id',$analysis_id),
			     hidden('parent_analysis_id', $parent_analysis_id),
			     submit(-name=>"delete_analysis_run_setup", -value=>"Delete Analysis Run", -class=>'red_bg')
			  )
			),
			Tr(
			  td({class=>'grey_bg'}, "User Description"),
			  td($user_desc),
			),
			Tr(
			  td({class=>'grey_bg'}, "Analyis Description"),
			  td($analysis_desc),
			),br,br,
### Add in start analysis link if needed
			$start_analysis_run_html,

### Start the File part of the table
			Tr(
			  td({class=>'grey_header', colspan=>'2'}, "Analysis Run Files"),
			),
			Tr(
			  td({class=>'grey_bg'}, "Data"),
			  td(make_table(file_type=>'data',
			  				file_names => \@filenames,
			  				token	 => $token,
			  				analysis_type => $analysis_name_type,
			  				) ),
			 ),
			 Tr(
			  td({class=>'grey_bg'}, "R Files"),
			  td(make_table(file_type=>'R_files',
			  				file_names => \@filenames,
			  				token	 => $token,
			  				analysis_type => $analysis_name_type,
			  				) ),
			 ),
			
			);#end of table


}
###############################################################################
# make_table
#
# Make a file of all the file types
###############################################################################
sub make_table {
	my %args = @_;
	my $file_type = $args{'file_type'};
	my @filenames = @ { $args{'file_names'} };
	my $token = $args{token};
	my $analysis_name_type = $args{analysis_type};
	
	my %data_types = ();
	my $show_file_url  = "$open_file_url?action=view_file"; 
	my $download_file_url = "$open_file_url?action=download"; 
	
### Make a hash that knows about all the file types that it should display	

	my $t = tie (%data_types, "Tie::IxHash", 
						data => {
							files => {
								  normtxt =>  
								 		{REG_EXP => '(affynorm-.+?_annotated)(txt)',
										  DESC	  => 'Data From R',
										  SHOW	 => 1,
										},
								  difftxt =>  
								 		{REG_EXP => '(mt-.+?_(.+?))\.(txt)',
										  DESC	  => 'Data From R',
										  SHOW	 => 1,
										},
								 
								  html =>
								  	 	{REG_EXP => '(mt-.+?_(.+?))\.(html)',
										 DESC	 => 'Html file generated by R',
										 SHOW	 => 1,
										 DATA_TYPE => 'differential_expression'
										},
								  difftxt_full =>  
								 		{REG_EXP => '(mt-.+?_(.+?))\.(full_txt)$',
										  DESC	  => 'All genes from R analysis run',
										  SHOW	 => 1,
										},
								  canonical_difftxt_full =>  
								 		{REG_EXP => '(mt-.+?_(.+?))\.(full_txt_canonical)',
										  DESC	  => 'All genes from R analysis run, updated canonical names',
										  SHOW	 => 1,
										},
								  anno_norm =>
								  	 	{REG_EXP => '(.*annotated)\.(txt)',
										 DESC	 => 'Annotated expression values file',
										 SHOW	 => 1,
										 DATA_TYPE => 'normalization'
										},
							},
						},
					
						 R_files => {
							files => {
								
									R =>{REG_EXP => '(.*)\.(R)',
									 	 DESC	 => 'R Script',
										 SHOW	 => 1,
										},
									html =>
										{REG_EXP => '(index)\.(html)',
									 	 DESC	 => 'Completed Job -- Html File',
										 SHOW	 => 1,
										},
									err => 
										{REG_EXP => '(.*)\.(err)',
									 		DESC	 => 'R Error File',
											SHOW	 => 1,
										},
									exprSet =>
										{REG_EXP => '(.*)\.(exprSet)',
										 DESC	 => 'R Binary affy library expression file',
										 SHOW	 => 0,
										},
									gunzip =>
										{REG_EXP => '(.*)\.(tar.gz)',
										 DESC	 => 'Tar Gunzip Archive of Analysis',
										 SHOW	 => 0,
										},
									xml =>
										{REG_EXP => '(.*)\.(xml)',
										 DESC	 => 'XML file showing groupings',
										 SHOW	 => 1,
										 DATA_TYPE => 'normalization',
										},
									
							 }
						}
						);

	
	my $file_types_href = $data_types{$file_type}{files};	#Get a href to all the file types that should be displayed for the table we are about to make
	
	my $html = qq~ <table border=0>
					<tr>
					<th class='grey_bg'>Show File</th>
					<th class='grey_bg'>Download File</th>
					<th class='grey_bg'>Info</th>
					</tr>			
				~;
				
	
	
	foreach my $file_key (keys %{ $file_types_href } ){
		
		my $reg_exp = $file_types_href->{$file_key}{REG_EXP};
		my $desc    = $file_types_href->{$file_key}{DESC};
		my $show_flag = $file_types_href->{$file_key}{SHOW};
		my $data_type = $file_types_href->{$file_key}{DATA_TYPE};
		
		next if (defined $data_type && $data_type ne $analysis_name_type);
		
		my $extension = '';
		my $file_name = '';
		foreach my $file (@filenames){
			if ($file =~ /$reg_exp/){
				$file_name = $1;
			    $extension = $3?$3:$2;#Tricky...  If a 3rd grouping is in the regexp the extension will be the last of the groupings 
			  	my $unique_condition_id = '';
			  	if( defined $3){ 
			  		$unique_condition_id = $2; 
			  		$unique_condition_id = "$unique_condition_id:";	#Format to make Ouput look nice
			  	}
				my $info = "&analysis_folder=$token&analysis_file=$file_name&file_ext=$extension";
				my $download_anchor_tag = $file_name 
					? "<a href='$download_file_url$info'>Get</a>" 
					: '---';
				
				my $show_anchor_tag = ($show_flag && $file_name )? 
					"<a href='$show_file_url$info'>Show</a>"
					: '---';
			
				
				
				$html .= qq~ <tr>
				  				<td>$show_anchor_tag</td>
				  				<td>$download_anchor_tag</td>
				  				<td>$unique_condition_id $desc</td>
							 </tr>
						 ~;
				 
			}
		}
	}
	
	$html .= "</table>";
	return $html;					
						
}					
##############################################################################
# delete_data_setup
#
# Check to make sure user has correct permissions to delete data and if so delete the 
#analysis info and mark the records in the data base as 'D'eleted...
#user can only delete data if no other data uses it as a parent.
###############################################################################					
sub delete_data_setup {
	my %args = @_;
	my $ref_parameters = $args{ref_parameters};

	my $best_permission = $sbeams->get_best_permission();

#make sure this user has permission to edit this data
	if ($best_permission <= SBEAMS::Connection::Permissions::DATA_ADMIN ||
		$best_permission <= SBEAMS::Connection::Permissions::DATA_MODIFIER ||
		$best_permission <= SBEAMS::Connection::Permissions::DATA_GROUP_MOD ){
		#print  "Permissions are good for this user";
	}else{
		error("Sorry You do do not have the proper group permissions to delete this data.  
		Please talked to the Project PI to be added to the correct modifier group")
	}
##
	my $analysis_id = $ref_parameters->{analysis_id};
	my $previous_analysis_id = $ref_parameters->{orginal_analysis_id_to_delete};
	my $delete_action = $ref_parameters->{delete_anlaysis_action};
	
	my $analysis_o = $affy_o->find_child_analysis_runs($analysis_id);
	
# log->debug(Dumper($analysis_o));
	
##If the analysis has child analysis runs make a form for the user to delete them first
	if (ref $analysis_o && $delete_action ne 'delete_run'){
	
		print_delete_child_data_form(analysis_obj => $analysis_o,
									 analysis_id  => $analysis_id,  );
	
	}elsif($delete_action eq 'confirmed_delete'){
		$log->debug("ABOUT TO DELETE DB ROW FOR '$analysis_id'");
		delete_data(ref_parameters => $ref_parameters);
		
		my $analysis_o = $affy_o->find_child_analysis_runs($previous_analysis_id);
		if (ref $analysis_o){
			print_delete_child_data_form(analysis_obj => $analysis_o,
								 analysis_id  => $previous_analysis_id,  );
		}else{
			print_return_to_main_analysis_form_link();
		}
		
	}else{
		print table(
					Tr(
					  td(
					    h3({class=>"orange_bg"},
					    "Are you sure you wish to delete this data"
					    )
					  )
					),
					Tr(
					   	td($cgi->start_form(-name => 'delete_run'),
		     			hidden('delete_sub', 'GO'),
		     			hidden('delete_anlaysis_action', "confirmed_delete"),
		     			hidden('analysis_id',$analysis_id),
		     			hidden(-name=>'orginal_analysis_id_to_delete',
						     		-value=>[$previous_analysis_id],
						     		),
		     			submit("delete_analysis_run_confirmed", "YES"),
			     		submit("delete_analysis_run_confirmed", "NO")
			     		)
					  
					)
			 );#end_table
	}
}				

#############################################################################
# print_return_to_main_analysis_form_link
#
# If user has no more data to delete present a link to go back to the tab they 
#were on before deleting data
###############################################################################	

sub print_return_to_main_analysis_form_link {

	my $from_url = $cgi->referer();
	$from_url =~ s/show.+?token.+?&//; #want to remove remove everything upto the tab setting
	
	print p(b("Done Deleting data, click 
	<a href='$from_url'>here </a>
	to go back to the overview."));
	return;
}
					
#############################################################################
# delete_data
#
# Delete the analysis info and mark the records in the database as 'D'eleted...
#user can only delete data if no other data uses it as a parent.
###############################################################################						
	
sub delete_data{
	my %args = @_;
	my $ref_parameters = $args{ref_parameters};
	my $analysis_id = $ref_parameters->{analysis_id};
	my $confirm_status = $ref_parameters->{delete_analysis_run_confirmed};
	my $folder_name = $affy_o->find_analysis_folder_name($analysis_id);
	die "Analysis Id '$analysis_id' does not look good" unless ($analysis_id =~ /^\d+$/);
	$log->debug("DELETE DATA: Analysis ID '$analysis_id' FOLDER NAME '$folder_name'");
	my $return_info = '';
	
##Change the database from N to 'D'
	if($confirm_status eq 'YES'){
		$return_info = $affy_o->delete_analysis_session(analysis_id =>$analysis_id);
		$return_info = "Database Deleted analysis_id $return_info<br>";
##Now delete the folder holding the data
		print "<h3>Starting to delete old files</h3><br>";
		$affy_o->delete_analysis_folder(analysis_folder=>"$folder_name");
		print "<hr>";
	
	}else{
		$return_info = 'Analysis Run Was Not Deleted';
		
	}
	die "Could not change database to delete Affy Analysis id '$analysis_id' " unless $return_info;
		
		print "<p>Delete Info:$return_info</p><br/>"

	
	
	

}

#############################################################################
# print_delete_child_data_form
#
# 
###############################################################################
sub print_delete_child_data_form{
	my %args = @_;
	
	my $analysis_o = $args{analysis_obj};
	my $analysis_id = $args{analysis_id};
	
	my @analysis_types = $analysis_o->get_analysis_types();
	$log->debug("ANALYSIS TYPES '@analysis_types'");
	
	print $cgi->start_table(),
					Tr(
					  td({colspan=>2},
					    h2({class=>"orange_bg"},
					    "Warning the data to be deleted has child analysis runs which must be deleted first"
					    )
					  )
					),
					Tr(
					  td({colspan=>2,  class=>'grey_bg'}, 
					  	"Look Below to see the data that needs to be delted first"
					  )
					);
		
		
			  
		foreach my $analysis_type (@analysis_types){
			print Tr(
				  	td({class=>'grey_header', colspan=>2}, "Analysis Type: $analysis_type")
				  	
				  );
			
			my $folder_names_aref = $analysis_o->check_for_analysis_data_type(analysis_name_type => $analysis_type);  
			
			$log->debug("FOLDER NAMES ", Dumper($folder_names_aref));
			
			foreach my $folder (@$folder_names_aref){
			
				my ($child_analysis_id, 
				$child_user_desc, 
				$child_analysis_desc, 
				$child_parent_analysis_id,
				$child_analysis_date,
				$child_username) =   $analysis_o->get_analysis_info(
											analysis_name_type => $analysis_type,
											folder_name => $folder,
											info_types	=> ["analysis_id",
															"user_desc", 
															"analysis_desc", 
															"parent_analysis_id",
															"analysis_date",
															"user_login_name"],
											truncate_data => 1,
											);         
				
				my $user_background_color = ($current_username eq $child_username )? 'grey_bg': 'orange_bg';
				
				$log->debug("$child_analysis_id, 
				$child_user_desc, 
				$child_analysis_desc, 
				$child_parent_analysis_id,
				$child_analysis_date,
				$child_username");
				
				
				print Tr(
						td({colspan=>2, class=>'grey_header', align=>'center'}, "Analysis Info")
					   ),
					   Tr(
						td({class=>'grey_bg'}, "Delete Analysis Run"),			
						td($cgi->start_form(-name => 'delete_run'),
						     hidden(-name=>"delete_sub", -value=>['GO']),
						     hidden(-name=>'orginal_analysis_id_to_delete',
						     		-value=>[$analysis_id],  
						     		-override => 1),
						     hidden(-name=>'analysis_id',
						     		-value=>[$child_analysis_id],
						     		-override => 1),
						     hidden(-name=>'parent_analysis_id', 
						     		-value=>[$child_parent_analysis_id], 
						     		-override => 1),
						     submit(-name=>"delete_analysis_run_setup", -value=>"Delete Analysis Run",-class=>'red_bg'),
						     $cgi->end_form(),
						  )
						), 
					  
					  Tr(
						td({class=>'grey_bg'},  "Run ID"),
						td("<a  href='${manage_table_url}affy_analysis&affy_analysis_id=$child_analysis_id'>$folder</a></td>")
					  ),
					  Tr(
						td({class=>'grey_bg'},  "Date"),
						td("$child_analysis_date")
					  ),
					  Tr(
						td({class=>$user_background_color},  "User Name"),
						td("$child_username")
					  ),
					  
					  Tr(
						td({class=>'grey_bg'},  "User Description"),
						td("$child_user_desc")
					  ),
					  Tr(
						td({class=>'grey_bg'},  "Analysis Description"),
						td("$child_analysis_desc")
					  ),
			}
		}
		$cgi->end_table();



}
