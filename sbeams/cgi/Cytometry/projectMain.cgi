#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Martin Korb <mkorb@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
#   and everything else
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use Benchmark;
use Text::Wrap;
use Data::Dumper;
use GD::Graph::xypoints;
use vars qw ($q $sbeams $sbeamsMOD $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Cytometry::Alcyt;
use SBEAMS::Cytometry;
use SBEAMS::Cytometry::Settings;
use SBEAMS::Cytometry::Tables;

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::Utilities;

$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Cytometry;
$sbeamsMOD->setSBEAMS($sbeams);


###############################################################################
# Global Variables
###############################################################################
my $VERBOSE;
my $TESTONLY;
$PROGRAM_FILE_NAME = 'main.cgi';

my $INTRO = '_displayIntro';
my $START = '_start';
my $ERROR = '_error';
my $PROCESSFILE = '_processFile';
my $GETGRAPH = '_getGraph';
my $CELL = '_processCells';
my $GETANOTHERGRAPH = '_getAnotherGraph';
my $SPECRUN = '_specifyRun';
my $IMMUNOLOAD = '_immunoLoad';
my (%indexHash,%editorHash,%inParsParam);

#possible actions (pages) displayed
my %actionHash = (
	$INTRO	=>	\&displayIntro,
	$START	=>	\&displayMain,
	$PROCESSFILE =>	 \&processFile,
	$GETGRAPH 	=>	 \&getGraph,
	$CELL	=>	\&processCells,
	$ERROR	=>	\&processError,
	$GETANOTHERGRAPH =>	\&getAnotherGraph,
    $SPECRUN => \&specifyRun,
    $IMMUNOLOAD => \&immunoLoad
	);
my $attributeSql = "select measured_parameters_id, measured_parameters_name from $TBCY_MEASURED_PARAMETERS";
my  %attributeHash = $sbeams->selectTwoColumnHash($attributeSql);
 
main();
exit(0);
###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned

    exit unless ($current_username = $sbeams->Authenticate(
      #connect_read_only=>1,
     permitted_work_groups_ref=>['Cytometry_user','Cytometry_admin','Admin','Cytometry_readonly'],
     allow_anonymous_access=>1,
   ));
   
	#### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
#$sbeams->printDebuggingInfo($q);
#### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);

  ;
    #### Print the header, do what the program does, and print footer
	
	# normal handling for anything else			
	$sbeamsMOD->display_page_header();
    handle_request(ref_parameters=>\%parameters);  
   $sbeamsMOD->display_page_footer();
  

} # end main


###############################################################################
# Show the main welcome page
###############################################################################

sub handle_request 
{
  my %args = @_;


#### Process the arguments list
    my $ref_parameters = $args{'ref_parameters'}
      || die "ref_parameters not passed";
    my %parameters = %{$ref_parameters};
    
    
    
    
#### Define some generic varibles
     my ($i,$element,$key,$value,$line,$result,$sql);
     my @rows;
     $current_contact_id = $sbeams->getCurrent_contact_id();

 #### Show current user context information
      $sbeams->printUserContext();

  #### Get information about the current project from the database
    $sql = qq~
    SELECT UC.project_id,P.name,P.project_tag,P.project_status,
               P.PI_contact_id
               FROM $TB_USER_CONTEXT UC
               INNER JOIN $TB_PROJECT P ON ( UC.project_id = P.project_id )
               WHERE UC.contact_id = '$current_contact_id'
               ~;
     @rows = $sbeams->selectSeveralColumns($sql);

     my $project_id = '';
     my $project_name = 'NONE';
     my $project_tag = 'NONE';
     my $project_status = 'N/A';
     my $PI_contact_id = 0;
     if (@rows)
     {
       ($project_id,$project_name,$project_tag,$project_status,$PI_contact_id) = @{$rows[0]};
     }
     my $PI_name = $sbeams->getUsername($PI_contact_id);
  
#### If the current user is not the owner, the check that the
#### user has privilege to access this project
     if ($project_id > 0) 
     {
       my $best_permission = $sbeams->get_best_permission();
#### If not at least data_reader, set project_id to a bad value
      $project_id = -99 unless ($best_permission > 0 && $best_permission <=40);
     }
  
#### Get all the experiments for this project
   my $action = $parameters{'action'};
 ;
     
     
  #### Define some variables for a query and resultset
  my %resultset = ();
  my $resultset_ref = \%resultset;
  my (%url_cols,%hidden_cols,%max_widths,$show_sql);

  
  
    #### Read in the standard form values
  my $apply_action  = $parameters{'action'} || $parameters{'apply_action'};
  my $TABLE_NAME = $parameters{'QUERY_NAME'};
  
  #### Set some specific settings for this program
  my $CATEGORY="Cytometry Sample";
  $TABLE_NAME="CY_cytometry_sample" unless ($TABLE_NAME);
  ($PROGRAM_FILE_NAME) =
    $sbeamsMOD->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");
  my $base_url = "$CGI_BASE_DIR/Cytometry/projectMain.cgi";
  
  #### Get the columns and input types for this table/query
  my @columns = $sbeamsMOD->returnTableInfo($TABLE_NAME,"ordered_columns");
  my %input_types = 
    $sbeamsMOD->returnTableInfo($TABLE_NAME,"input_types");
    
  
  #### Read the input parameters for each column
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters,
    columns_ref=>\@columns,input_types_ref=>\%input_types);


  #### If the apply action was to recall a previous resultset, do it
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  if ($apply_action eq "VIEWRESULTSET") {
    $sbeams->readResultSet(resultset_file=>$rs_params{set_name},
        resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters);
   
  }
  
 
  #### Apply any parameter adjustment logic
  unless ($parameters{project_id}) {
    $parameters{project_id} = $sbeams->getCurrent_project_id();
  }

  my $projectID = $parameters{project_id};
  
    #### Build ROWCOUNT constraint
  $parameters{row_limit} = 5000  
  unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=1000000);
  my $limit_clause = $sbeams->buildLimitClause(
   row_limit=>$parameters{row_limit});


  #### Define some variables needed to build the query
  my @column_array;
  my @additional_columns = ();

  
  #### Define the desired columns in the query
  #### [friendly name used in url_cols,SQL,displayed column title]

  @column_array = (
    ["fcs_run_id","FR.fcs_run_id","Fcs ID" ], #need hypertext link
    ["organism", "SBO.full_name","Organism Name"],
    ["sample_name",  "FR.sample_name", "Sample Name"],
    ["sample_tag", "CS.sample_tag", "Sample Name Tag"], #$need hypertext link
    ["cytometry_sample_id", "cytometry_sample_id","cytometry_sample_id"],
    ["sort_entity", "SE.sort_entity_name","Sort Entity"],
    ["tissue_type",  "TT.tissue_type_name","Tissue Type"],
    ["sortedCellType", "FR.sortedCellType", "Cell Type"],
    ["showFlag", "FR.showFlag","Displayed"],
    ["fcs_run_description", "FR.fcs_run_description", "Description"],
    ["project_id","FR.project_id","project_id"],
    @additional_columns,
  );
   
  #### Build the columns part of the SQL statement
  my %colnameidx = ();
  my @column_titles = ();
  my $columns_clause = $sbeams->build_SQL_columns_list(
    column_array_ref=>\@column_array,
    colnameidx_ref=>\%colnameidx,
    column_titles_ref=>\@column_titles
  );



  #### Build the query
  $sql = qq~
    SELECT $limit_clause->{top_clause} $columns_clause
      FROM $TBCY_FCS_RUN FR
      LEFT JOIN $TBCY_SORT_ENTITY SE
           ON ( FR.sort_entity_id = SE.sort_entity_id)
      LEFT JOIN $TBCY_TISSUE_TYPE TT
           ON ( FR.tissue_type_id = TT.tissue_type_id)
      LEFT JOIN $TBCY_SORT_TYPE ST ON ( FR.sort_type_id = ST.sort_type_id)
      LEFT JOIN $TB_ORGANISM SBO ON (FR.organism_id = SBO.organism_id)
      LEFT JOIN $TBCY_CYTOMETRY_SAMPLE CS ON (FR.fcs_run_id = CS.fcs_run_id)
       WHERE 1 = 1
       AND FR.record_status != 'D'
       AND FR.project_id = $project_id
     $limit_clause->{trailing_limit_clause}
    ~;
 %hidden_cols = ('cytometry_sample_id' => 1);
  #### Certain types of actions should be passed to links
  my $pass_action = "QUERY";
  $pass_action = $apply_action if ($apply_action =~ /QUERY/i);
  

  #### Define the hypertext links for columns that need them
  %url_cols = (
    	       'Fcs ID' => "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_fcs_run&fcs_run_id=\%V",
    	      'Fcs_id_ATAG' => 'TARGET="Win1"',
               'Sample Name'  => "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_fcs_run &fcs_run_id=\%$colnameidx{fcs_run_id}V",
    	       'Sample Name_ATG' => 'TARGET="Win1"',
                       
    	       'Sample Name Tag' => "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_cytometry_sample&cytometry_sample_id=\%4V",
    	       'Sample Name Tag_ATG' => 'TARGET="Win1"',
    	         );

  
  
  
   #########################################################################
  #### If QUERY or VIEWRESULTSET was selected, display the data
  
    #### If the action contained QUERY, then fetch the results from
    #### the database
   my $apply_action  = $parameters{'action'} || $parameters{'apply_action'};
   


    if ($apply_action =~ /QUERY/i || $apply_action eq "VIEWRESULTSET") {

            
      if ($apply_action =~ /QUERY/i)
      {
   
        #### Fetch the results from the database server
      $sbeams->fetchResultSet(
        sql_query=>$sql,
        resultset_ref=>$resultset_ref,
      );

      #### Store the resultset and parameters to disk resultset cache
      $rs_params{set_name} = "SETME";
      $sbeams->writeResultSet(
        resultset_file_ref=>\$rs_params{set_name},
        resultset_ref=>$resultset_ref,
        query_parameters_ref=>\%parameters,
        resultset_params_ref=>\%rs_params,
        query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
      );
    }

    #### Display the resultset
    $sbeams->displayResultSet(
      resultset_ref=>$resultset_ref,
      query_parameters_ref=>\%parameters,
      rs_params_ref=>\%rs_params,
      url_cols_ref=>\%url_cols,
      hidden_cols_ref=>\%hidden_cols,
      max_widths=>\%max_widths,
      column_titles_ref=>\@column_titles,
      base_url=>$base_url,
    );


    #### Display the resultset controls
    $sbeams->displayResultSetControls(
      resultset_ref=>$resultset_ref,
      query_parameters_ref=>\%parameters,
      rs_params_ref=>\%rs_params,
      base_url=>$base_url,
    );

}
    
}
__END__     
     
 
__END__
		


