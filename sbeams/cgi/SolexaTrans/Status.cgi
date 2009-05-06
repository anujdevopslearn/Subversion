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
$PROGRAM_FILE_NAME = 'Status.cgi';
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
  exit unless ($current_username = $sbeams->Authenticate());

  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters( parameters_ref=>\%parameters);

  #### Decide what action to take based on information so far
  if ($parameters{output_mode} =~ /xml|tsv|excel|csv/) {
    print_output_mode_data(parameters_ref=>\%parameters);
  } else {
    $sbeamsMOD->printPageHeader();
    print_javascript();
    handle_request(ref_parameters => \%parameters);
    $sbeamsMOD->printPageFooter();
  }

} # end main


###############################################################################
# print_javascript
###############################################################################
sub print_javascript {
  my $uri = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/";
  print qq~
<script type='text/JavaScript' src="$HTML_BASE_DIR/usr/javascript/scw.js"></script>
<script type="text/javascript">
<!--
<!-- $uri -->
function confirmSubmit(\$message) {
  var agree = confirm(\$message);
  if (agree)
    return true;
  else
    return false;
}
var filter_state = 'none';
function toggle_filter(layer_ref) {
  if (filter_state == 'inline') {
    filter_state = 'none';
  } else {
    filter_state = 'inline';
  }
  if (document.all) { //IS IE 4 or 5 (or 6 beta)
  eval( "document.all." + layer_ref + ".style.display = filter_state");
  }
  if (document.layers) { //IS NETSCAPE 4 or below
  document.layers[layer_ref].display = filter_state;
  }
  if (document.getElementById && !document.all) {
  filter = document.getElementById(layer_ref);
  filter.style.display = filter_state;
  }
}
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
 $current_contact_id = $sbeams->getCurrent_contact_id();
  $sbeams->printUserContext();

  print qq!
    <div>
    &nbsp;
    <div id="help_options" style="float: right;">
      <a href="javascript://;" onclick="toggle_help('help');">Help</a>
    </div>
    <div id="help" style="display:none">
    !;
  print help_gen_jobs();
  print "</div>\n";


  if ($parameters{jobname} || $parameters{solexa_analysis_id}) {
     print_detailed_status(parameters_ref => \%parameters);
  }else {
     print_status_page(parameters_ref=>\%parameters);
  }
  print "</div>";
  return;

}

###############################################################################
# print_status_page
###############################################################################
sub print_status_page {
  my %args = @_;
  my $SUB_NAME = "print_status_page";
  
  my $parameters_ref = $args{'parameters_ref'} || die "ERROR[$SUB_NAME] No parameters passed\n";
  my %parameters = %{$parameters_ref};
  my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';

  ## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
  if ($parameters{set_current_project_id}) {$apply_action = 'QUERY';}

  ## Define standard variables
  my ($sql, @rows);
  my $project_id = $sbeams->getCurrent_project_id();
  my ($project_name, $project_tag, $project_status, $project_desc);

  ########################################################################################
  ### Set some of the useful vars
  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  my $base_url = "$CGI_BASE_DIR/SolexaTrans/Status.cgi";
  my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

  my %url_cols = ();
  my %hidden_cols  =();
  my $limit_clause = '';
  my @column_titles = ();

  my $show_sql;

  #### If the apply action was to recall a previous resultset, do it
  if ($apply_action eq "VIEWRESULTSET"  && $apply_action ne 'QUERY') {
   	
	$sbeams->readResultSet(
     	 resultset_file=>$rs_params{set_name},
     	 resultset_ref=>$resultset_ref,
     	 query_parameters_ref=>\%parameters,
    	  resultset_params_ref=>\%rs_params,
   	 );
	 
  }
  print qq!
    <div id="filter_options" style="float: right; margin-right: 10px;">
      <a href="javascript://;" onclick="toggle_filter('filter');">Advanced Search</a>
    </div>
    <div id="filter" style="display:none">
    !;
  #########################################################################
  #### Print the form
  my $TABLE_NAME = $parameters{'QUERY_NAME'};
  $TABLE_NAME="ST_StatusSearch" unless ($TABLE_NAME);
  ($PROGRAM_FILE_NAME) =
    $sbeamsMOD->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");

  #### Get the columns and input types for this table/query
  my @columns = $sbeamsMOD->returnTableInfo($TABLE_NAME,"ordered_columns");
  my %input_types =
    $sbeamsMOD->returnTableInfo($TABLE_NAME,"input_types");

    #### Read the input parameters for each column
#    my $n_params_found = $sbeams->parse_input_parameters(
#      q=>$q,parameters_ref=>\%parameters,
#      columns_ref=>\@columns,input_types_ref=>\%input_types);

  $sbeams->display_input_form(
        TABLE_NAME=>$TABLE_NAME,CATEGORY=>$CATEGORY,apply_action=>$apply_action,
        PROGRAM_FILE_NAME=>$PROGRAM_FILE_NAME,
        parameters_ref=>\%parameters,
        input_types_ref=>\%input_types,
        mask_user_context=>1,
        form_name=>'SampleForm'
      );

  $sbeams->display_form_buttons(TABLE_NAME=>$TABLE_NAME);

  print qq(</div>);

  #########################################################################
  ### Define the constraints

  #### Build ROWCOUNT constraint
  $parameters{row_limit} = 10000
    unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=1000000);
  my $limit_clause = $sbeams->buildLimitClause(
     row_limit=>$parameters{row_limit});

  #### Build SLIMSEQ_SAMPLE_ID constraint
  my $slimseq_sample_id_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"ss.slimseq_sample_id",
    constraint_type=>"plain_text",
    constraint_name=>"Sample ID",
    constraint_value=>$parameters{slimseq_sample_id_constraint} );
  return if ($slimseq_sample_id_clause eq '-1');

  #### Build SAMPLE_TAG constraint
  my $sample_tag_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"ss.sample_tag",
    constraint_type=>"plain_text",
    constraint_name=>"Sample Tag",
    constraint_value=>$parameters{sample_tag_constraint} );
  return if ($sample_tag_clause eq '-1');

  #### Build FULL_SAMPLE_NAME constraint
  my $full_sample_name_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"ss.full_sample_name",
    constraint_type=>"plain_text",
    constraint_name=>"Full Sample Name",
    constraint_value=>$parameters{full_sample_name_constraint} );
  return if ($full_sample_name_clause eq '-1');

  #### Build JOB_TAG constraint
  my $job_tag_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"sa.job_tag",
    constraint_type=>"plain_text",
    constraint_name=>"Job Tag",
    constraint_value=>$parameters{job_tag_constraint} );
  return if ($job_tag_clause eq '-1');


  #### Build JOB_STATUS constraint
  my $job_status_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"sa.status",
    constraint_type=>"plain_text",
    constraint_name=>"Job Status",
    constraint_value=>$parameters{job_status_constraint} );
  return if ($job_status_clause eq '-1');

  # parseConstraint2SQL doesn't support datetime
  #### Build JOB_STATUS_UPDATED_START constraint
#  my $job_status_updated_start_clause = $sbeams->parseConstraint2SQL(
#    constraint_column=>"sa.status_time",
#    constraint_type=>"plain_text",
#    constraint_name=>"Job Status Updated Start",
#    constraint_value=>$parameters{job_status_updated_start_constraint} );
#  return if ($job_status_updated_start_clause eq '-1');
  my $job_status_updated_start_clause = " AND sa.status_time > '".$parameters{job_status_updated_start_constraint}."'" if $parameters{job_status_updated_start_constraint};

  #### Build JOB_STATUS_UPDATED_END constraint
#  my $job_status_updated_end_clause = $sbeams->parseConstraint2SQL(
#    constraint_column=>"sa.status_time",
#    constraint_type=>"plain_text",
#    constraint_name=>"Job Status Updated End",
#    constraint_value=>$parameters{job_status_updated_end_constraint} );
#  return if ($job_status_updated_end_clause eq '-1');
  my $job_status_updated_end_clause = " AND sa.status_time < '".$parameters{job_status_updated_end_constraint}."'" if $parameters{job_status_updated_end_constraint};

  #### Define the desired columns in the query
  #### [friendly name used in url_cols,SQL,displayed column title]
    #["external_identifier",$extid_column,"External Identifier"],
  my @column_array = (
    ["Job_Name","sa.jobname","Job_Name"],
    ["Sample_ID","ss.slimseq_sample_id","Sample ID"],
    ["Sample_Tag","ss.sample_tag","Sample Tag"],
    ["Full_Sample_Name","ss.full_sample_name","Full Sample Name"],
    ["Job_Tag","sa.job_tag","Job Tag"],
    ["Job_Status","sa.status","Job Status"],
    ["Job_Status_Updated","sa.status_time","Job Status Updated"],
    ["Job_ID","sa.solexa_analysis_id","Job ID"],
  );

  #### Build the columns part of the SQL statement
  my %colnameidx = ();
  my @column_titles = ();
  my $columns_clause = $sbeams->build_SQL_columns_list(
    column_array_ref=>\@column_array,
    colnameidx_ref=>\%colnameidx,
    column_titles_ref=>\@column_titles
  );

 #### Set the show_sql flag if the user requested
  if ( $parameters{display_options} =~ /ShowSQL/ ) {
    $show_sql = 1;
  }

  my $sql = qq~
                SELECT $limit_clause->{top_clause} $columns_clause
                FROM $TBST_SOLEXA_ANALYSIS sa
                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr on
                  (sa.solexa_pipeline_results_id = spr.solexa_pipeline_results_id)
                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                  (spr.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on
                  (sfcl.flow_cell_lane_id = sfcls.flow_cell_lane_id)
                LEFT JOIN $TBST_SOLEXA_SAMPLE ss ON
                  (sfcls.solexa_sample_id = ss.solexa_sample_id)
                WHERE ss.project_id IN ($project_id)
                AND spr.record_status != 'D'
                AND sfcl.record_status != 'D'
                AND sfcls.record_status != 'D'
                AND ss.record_status != 'D'
                $slimseq_sample_id_clause
                $sample_tag_clause
                $full_sample_name_clause
                $job_status_clause
                $job_tag_clause
                $job_status_updated_start_clause
                $job_status_updated_end_clause
                $limit_clause->{trailing_limit_clause}
                ORDER BY sa.slimseq_sample_id, sa.status_time
           ~;



  #########################################################################
  ### Get the SQL
		
      $sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
      $sbeams_solexa_groups->setSBEAMS($sbeams);				
		
#      $sql = $sbeams_solexa_groups->get_sample_job_status_sql(project_id    => $project_id, );
		
      %url_cols = (
#                      'Job_Name'        => "${base_url}?jobname=\%0V",
		      'Sample_Tag'	=> "${manage_table_url}solexa_sample&solexa_sample_id=\%1V",
		      'Job_Tag'	        => "${manage_table_url}solexa_analysis&solexa_analysis_id=\%7V",
                    );

  		 
      %hidden_cols = (
                      'Job_Name' => 1,
                      'Sample_ID' => 1,
                      'Job_ID' => 1,
		      );
	

  #########################################################################
  ####  Actually print the data 	

 	 
  #### If the action contained QUERY, then fetch the results from
  #### the database
  if ($apply_action =~ /QUERY/i || $apply_action =~ /REFRESH/i) {

    #### Show the SQL that will be or was executed
    $sbeams->display_sql(sql=>$sql) if ($show_sql);

    		
    #### Fetch the results from the database server
    $sbeams->fetchResultSet(sql_query=>$sql,
			    resultset_ref=>$resultset_ref,
			   );

    append_job_controls(resultset_ref => $resultset_ref,
                       );

    #### Append the Results Links
    append_result_links(resultset_ref => $resultset_ref,
                       );

    #### Store the resultset and parameters to disk resultset cache
    $rs_params{set_name} = "SETME";
    $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
		      	    resultset_ref=>$resultset_ref,
			    query_parameters_ref=>\%parameters,
			    resultset_params_ref=>\%rs_params,
			    query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
			   );


  } #end action = QUERY
  
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
# print_detailed_status
###############################################################################
sub print_detailed_status {
  my %args = @_;
  my $SUB_NAME = "print_detailed_status";
  
  my $parameters_ref = $args{'parameters_ref'} || die "ERROR[$SUB_NAME] No parameters passed\n";
  my %parameters = %{$parameters_ref};
  my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || 'QUERY';
  die "ERROR: Must supply a jobname to get detailed information.\n" if (!$parameters{"jobname"} && !$parameters{"solexa_analysis_id"});
 
  ## HACK: If set_current_project_id is a parameter, we do a 'QUERY' instead of a 'VIEWRESULTSET'
  if ($parameters{set_current_project_id}) {$apply_action = 'QUERY';}

  ## Define standard variables
  my ($sql, @rows);

  ########################################################################################
  ### Set some of the useful vars
  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  my $base_url = "$CGI_BASE_DIR/SolexaTrans/Status.cgi";
  my $manage_table_url = "$CGI_BASE_DIR/SolexaTrans/ManageTable.cgi?TABLE_NAME=ST_";

  my $project_id = $sbeams->getCurrent_project_id();

  my %url_cols = ();
  my %hidden_cols  =();
  my $limit_clause = '';
  my @column_titles = ();
    
  my $jobname;
  if ($parameters{jobname}) {
    $jobname = $parameters{"jobname"};
    if ($jobname =~ /,/) {
       my @jobs = split(/,/, $jobname);
       my %unique_jobs;
       map { $unique_jobs{$_} = 1 } @jobs;
       my @new_jobs = sort keys %unique_jobs;
       $jobname = shift(@new_jobs);
       if (scalar @new_jobs > 0) {
         print "Multiple jobs were passed in to detailed job viewer - displaying information for $jobname only.<br>";
         print "Ignoring ".join(",", @new_jobs);
      }
    }

    grep(/stp-ssid[0-9]{1,6}-[a-zA-Z0-9]{8}/, $jobname) ||
              die("Invalid job name - $jobname");
  }

  my $sa_id;
  if ($parameters{"solexa_analysis_id"}) {
    $sa_id = $parameters{solexa_analysis_id};
    if ($sa_id =~ /,/) {
      my @sa_ids = split(/,/, $sa_id);
      my %unique_saids;
      map { $unique_saids{$_} = 1} @sa_ids;
      my @new_saids = sort keys %unique_saids;
      $sa_id = shift(@new_saids);
      if (scalar @new_saids > 0) {
        print "Multiple jobs were passed in to detailed job viewer - displaying information for $sa_id only.<br>";
        print "Ignoring ".join(",", @new_saids);
      }
    }
  }
  
  my $default_data_type = "SOLEXA_SAMPLE";

  my %count_types = ( 
		          SOLEXA_SAMPLE		=> {	COUNT => 1,
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
			page_link	=> "Status.cgi",
			selected_tab	=> $selected_tab_numb
	        );
		
		



  #### If the apply action was to recall a previous resultset, do it
  if ($apply_action eq "VIEWRESULTSET"  && $apply_action ne 'QUERY') {
   	
    $sbeams->readResultSet(
     	 resultset_file=>$rs_params{set_name},
     	 resultset_ref=>$resultset_ref,
     	 query_parameters_ref=>\%parameters,
    	  resultset_params_ref=>\%rs_params,
   	 );
	 
  }

  $sbeams_solexa_groups = new SBEAMS::SolexaTrans::Solexa_file_groups;
  $sbeams_solexa_groups->setSBEAMS($sbeams);
  if ($jobname) {
    $sql = $sbeams_solexa_groups->get_detailed_job_status_sql('jobname' => $jobname, );
  } elsif ($sa_id) {
    $sql = $sbeams_solexa_groups->get_detailed_job_status_sql('solexa_analysis_id' => $sa_id);
  }
		
  %url_cols = (
		      'Sample_Tag'	=> "${manage_table_url}solexa_sample&solexa_sample_id=\%3V",
              );

  		 
  %hidden_cols = (
                      #'Sample_ID' => 1,
		 );
	
  #########################################################################
  ####  Actually print the data 	

 	 
  #### If the action contained QUERY, then fetch the results from
  #### the database
  if ($apply_action =~ /QUERY/i) {
		
    #### Fetch the results from the database server
    $sbeams->fetchResultSet(sql_query=>$sql,
			    resultset_ref=>$resultset_ref,
			   );

    #### Append the Job Control Links
    append_job_controls(resultset_ref => $resultset_ref,
                       );

    #### Append the Results Links
    append_result_links(resultset_ref => $resultset_ref,
                       );

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
#    print $column_titles[$i]." val ".$aref->[$i]."<br>";
      my @info = ($column_titles[$i],$aref->[$i]);
      push(@{$new_results{data_ref}}, \@info);
    }

    my @row_color_list = ("#E0E0E0","#C0D0C0");
    %color_scheme = (
                        header_background => '#0000A0',
                        change_n_rows => 1,
                        color_list => \@row_color_list,
                      );

 
    #### Store the resultset and parameters to disk resultset cache
    $rs_params{set_name} = "SETME";
    $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
		      	    resultset_ref=>\%new_results,
			    query_parameters_ref=>\%parameters,
			    resultset_params_ref=>\%rs_params,
			    query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
			   );
                       

  if ($jobname) {
    $base_url .= '?jobname='.$jobname;
  } elsif ($sa_id) {
    $base_url .= '?solexa_analysis_id='.$sa_id;
  }

  my $sai_ref = shift(@{$new_results{data_ref}}); # ref to an array that has a hash inside
  my $solexa_analysis_id = $sai_ref->[1];

  if (!$jobname) {
    $jobname = $new_results{data_ref}[0]->[1];
  }
  #### Display the resultset
  $sbeams->displayResultSet(resultset_ref=>\%new_results,
			    url_cols_ref=>\%new_url_cols,
			    hidden_cols_ref=>\%new_hidden_cols,
			    max_widths=>\%max_widths,
			    column_titles_ref=>\@new_column_titles,
			    base_url=>$base_url,
                            row_color_scheme_ref => \%color_scheme,
                            rs_params_ref => \%rs_params,
			   );


  my $job_parameters_ref={};
  $sql = $sbeams_solexa_groups->get_job_parameters_sql('solexa_analysis_id' => $solexa_analysis_id );
  $sbeams->fetchResultSet(sql_query=>$sql,
			    resultset_ref=>$job_parameters_ref,
			   );

  my $param_display_idx = $job_parameters_ref->{column_hash_ref}->{param_display};
  my $param_value_idx = $job_parameters_ref->{column_hash_ref}->{param_value};

  # convert the data_ref into an array that jobsummary understands
  my $jref = $$job_parameters_ref{data_ref};
  my @nref;
  foreach my $ijref (@$jref) {
    
    # replace the genome id with the genome name
    if ($ijref->[$param_display_idx] eq 'Genome') {
        my $gids = $ijref->[$param_value_idx];
        my $genome_name = '';
        my @genome_ids;
        if ($gids =~ /,/) {
          @genome_ids = split(/,/, $gids);
        } else {
          push(@genome_ids, $gids);
        }
        foreach my $gid (@genome_ids) {
          $genome_name .= $utilities->get_sbeams_biosequence_set_name(biosequence_set_id => $gid).', ';
        }
        $genome_name =~ s/, $//;

        $ijref->[$param_value_idx] = $genome_name;
    }

    # add jobname to job directory
    if ($ijref->[$param_display_idx] eq 'Job Directory') {
        $ijref->[$param_value_idx] .= '/'.$jobname;
    }

    # add jobname to job directory
    if ($ijref->[$param_display_idx] eq 'Upload Tags') {
        my $readable_tag_option = $utilities->get_sbeams_query_option(option_type=>'JP_upload_options',
                                                                      option_key =>$ijref->[$param_value_idx]
                                                                     );
        $ijref->[$param_value_idx] = $readable_tag_option;
    }


    foreach my $entry (@$ijref) {
      push(@nref, $entry);
    }
  }

  my $jobsummary = jobsummary(@nref); # method in SetupPipeline.pm
  my $ja = ":&nbsp;<a href=\"$CGI_BASE_DIR/SolexaTrans/View_Solexa_files.cgi?action=view_file&jobname=$jobname\">View Job</a>";
  my $ca = ":&nbsp;<a href=\"$CGI_BASE_DIR/SolexaTrans/cancel.cgi?jobname=$jobname\">Cancel Job</a>";
  my $links = $ja . $ca;
  $jobsummary =~ s/:/$links/;
  print $jobsummary;

  } #end action = QUERY
  else {
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
  }

  #### Display the resultset controls
#  $sbeams->displayResultSetControls(resultset_ref=>$resultset_ref,
#				    query_parameters_ref=>\%parameters,
#				    rs_params_ref=>\%rs_params,
#				    base_url=>$base_url,
#				   );



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
           my $limit_clause = $sbeams->buildLimitClause(row_limit=>$parameters{row_limit});


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
# append_job_controls
#
# Append on the more columns of data which can then be shown via the displayResultSet method
###############################################################################

sub append_job_controls {
        my %args = @_;

        my $resultset_ref = $args{resultset_ref};

        #data is stored as an array of arrays from the $sth->fetchrow_array
        # each row is a row from the database holding an aref to all the values
        my $aref = $$resultset_ref{data_ref};

        my $jobname_idx = $resultset_ref->{column_hash_ref}->{Job_Name};
        my $status_idx  = $resultset_ref->{column_hash_ref}->{Job_Status};
        my $sample_idx  = $resultset_ref->{column_hash_ref}->{Sample_ID};

        my @new_data_ref;
        ########################################################################################
        my $anchor = '';
        my $pad = '&nbsp;&nbsp;&nbsp;';
        foreach my $row_aref (@{$aref} ) {

          #need to make sure the query has the slimseq_sample_id in the first column
          #    since we are going directly into the array of arrays and pulling out values
          my $jobname  = $row_aref->[$jobname_idx];
          # the six statuses are: QUEUED, RUNNING, CANCELED, UPLOADING, PROCESSED, COMPLETED
          my $status   = $row_aref->[$status_idx];

           if ($status eq 'QUEUED') {
            # if it's running we want to offer the ability to cancel the job
            $anchor = "<a href=cancel.cgi?jobname=$jobname>Cancel Job</a>";
          } elsif ($status eq 'RUNNING') {
            # if it's running we want to offer the ability to cancel the job
            $anchor = "<a onclick=\"return confirmSubmit('This job is running.  Are you sure you want to cancel this job?')\" href=cancel.cgi?jobname=$jobname>Cancel Job</a>";
          } elsif ($status eq 'CANCELED') {
            $anchor = "<a href=Samples.cgi?jobname=$jobname>Restart Job</a>";
          } elsif ($status eq 'UPLOADING') {
            $anchor = "No Actions";
          } elsif ($status eq 'PROCESSED') {
            $anchor = "<a href=upload.cgi?jobname=$jobname>Restart Upload</a>";
          } elsif ($status eq 'COMPLETED') {
            $anchor = qq!
            <a onclick="return confirmSubmit('This job has completed.  Are you sure you want to restart this job?')" href=Samples.cgi?jobname=$jobname>Restart Job</a>
            !;
          } else {
            $anchor = "ERROR: Contact admin";
          }

          my $view_params = "<a href=Status.cgi?jobname=$jobname>View Params</a>";
          push @$row_aref, $view_params;

          push @$row_aref, $anchor;             #append on the new data

        } # end foreach row

        if ( 1 ){
            #need to add the column headers into the resultset_ref since DBInterface display results will reference this
            push @{$resultset_ref->{column_list_ref}} , "Job Parameters";
            push @{$resultset_ref->{column_list_ref}} , "Job Controls";

            #need to append a value for every column added otherwise the column headers will not show
            append_precision_data($resultset_ref);
            append_precision_data($resultset_ref);
        }


}

###############################################################################
# append_result_links
#
# Append on the more columns of data which can then be shown via the displayResultSet method
###############################################################################

sub append_result_links {
        my %args = @_;

        my $resultset_ref = $args{resultset_ref};

        #data is stored as an array of arrays from the $sth->fetchrow_array
        # each row is a row from the database holding an aref to all the values
        my $aref = $$resultset_ref{data_ref};

        my $jobname_idx = $resultset_ref->{column_hash_ref}->{Job_Name};
        my $status_idx  = $resultset_ref->{column_hash_ref}->{Job_Status};
        my $sample_idx  = $resultset_ref->{column_hash_ref}->{Sample_ID};

        my @new_data_ref;
        ########################################################################################
        my $anchor = '';
        my $pad = '&nbsp;&nbsp;&nbsp;';
        foreach my $row_aref (@{$aref} ) {

          #need to make sure the query has the slimseq_sample_id in the first column
          #    since we are going directly into the array of arrays and pulling out values
          my $jobname  = $row_aref->[$jobname_idx];
          # the four statuses are: RUNNING, CANCELED, UPLOADING, COMPLETED
          my $status   = $row_aref->[$status_idx];
          my $sample = $row_aref->[$sample_idx];

           if ($status eq 'QUEUED') {
            # if it's running we want to offer the ability to cancel the job
            $anchor = "<a href=View_Solexa_files.cgi?action=view_file&jobname=$jobname>View Job</a>";
          } elsif ($status eq 'RUNNING') {
            # if it's running we want to offer the ability to cancel the job
            $anchor = "<a href=View_Solexa_files.cgi?action=view_file&jobname=$jobname>View Job</a>";
          } elsif ($status eq 'CANCELED') {
            $anchor = "";
          } elsif ($status eq 'UPLOADING') {
            $anchor = "<a href=dataDownload.cgi?slimseq_sample_id=$sample&jobname=$jobname>Results</a>";
          } elsif ($status eq 'PROCESSED') {
            $anchor = "<a href=dataDownload.cgi?slimseq_sample_id=$sample&jobname=$jobname>Results</a>";
          } elsif ($status eq 'COMPLETED') {
            $anchor = "<a href=dataDownload.cgi?slimseq_sample_id=$sample&jobname=$jobname>Results</a>";
          } else {
            $anchor = "ERROR: Contact admin";
          }

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
        #       print "$val<br>";
        #}

}



###############################################################################
# error_log
###############################################################################
sub error_log {
	my $SUB_NAME = 'error_log';
	
	my %args = @_;
	
	die "Must provide key value pair for 'error' \n" unless (exists $args{error});
	
	open ERROR_LOG, ">>STATUS_ERROR_LOGS.txt"
		or die "$SUB_NAME CANNOT OPEN ERROR LOG $!\n";
		
	my $date = `date`;
	
	print ERROR_LOG "$date\t$args{error}\n";
	close ERROR_LOG;
	
	die "$date\t$args{error}\n";
}




