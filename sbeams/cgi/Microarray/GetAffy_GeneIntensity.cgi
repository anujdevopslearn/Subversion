#!/usr/local/bin/perl

###############################################################################
# Program     : GetAffy_GeneIntensity.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This program that allows users to
#              view affy gene expression intensity
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $affy_o $q $current_contact_id $current_username
  $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
  $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
  @MENU_OPTIONS %CONVERSION_H *sym);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Merge_results_sets;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::Affy_file_groups;
use SBEAMS::Microarray::Affy_Analysis;
use SBEAMS::Microarray::Affy_Annotation;

use Data::Dumper;
$sbeams    = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$affy_o = new SBEAMS::Microarray::Affy_Analysis;
$affy_o->setSBEAMS($sbeams);

use POSIX qw(log10 pow);
use CGI qw(:standard);
#$q = new CGI;

# working range 10-10000, 3 logs wide 
use constant MAX_DATA_SPREAD => 3; 

# Use 250 hex colors, omitting the 6 lightest
use constant CONVERSION_F => 250/MAX_DATA_SPREAD; 
make_color_h();

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
	print Dumper($sbeams);
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################

my $base_url         = "$CGI_BASE_DIR/Microarray/$PROG_NAME";
my $manage_table_url =
  "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=MA_";

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
			  [ 'Microarray_user', 'Microarray_admin', 'Admin', 'Microarray_readonly' ],

			#connect_read_only=>1,
			allow_anonymous_access=>1,
		)
	  );
 #$log->debug( "Current username is $current_username" );
 #$log->printStack( 'debug' ); 
	#### Read in the default input parameters
	my %parameters;
	my $n_params_found = $sbeams->parse_input_parameters(
		q              => $q,
		parameters_ref => \%parameters
	);

	# $sbeams->printDebuggingInfo($q);

	#### Process generic "state" parameters before we start
	$sbeams->processStandardParameters( parameters_ref => \%parameters );

	#### Decide what action to take based on information so far
	if ( defined( $parameters{action} ) && $parameters{action} eq "???" ) {
		# Some action
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
#  $log->debug( $q->self_url());

	#### Process the arguments list
	my $ref_parameters = $args{'ref_parameters'}
	  || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};

	#### Define some generic varibles
	my ( $i, $element, $key, $value, $line, $result, $sql );

	#### Define some variables for a query and resultset
	my %resultset     = ();
	my $resultset_ref = \%resultset;
	my ( %url_cols, %hidden_cols, %max_widths, $show_sql );

	#### Read in the standard form values
	my $apply_action = $parameters{'action'}
	  || $parameters{'apply_action'}
	  || '';
	my $TABLE_NAME = $parameters{'QUERY_NAME'};
	my $query_type = $parameters{display_type}
	  || 'Simple';    #what type of query display interface to show

###############################################
### Check to see if we need to display data

	if ( $apply_action eq 'SIMPLE_QUERY' & !$parameters{display_type} ) {
		show_data( ref_parameters => \%parameters );
		return;
	}elsif ( $apply_action eq 'SHOW_ANNO' ) {
		show_annotation( ref_parameters => \%parameters );
		return;
	}

###############################################
### if we made it to here we need to display the query form

	if (   $query_type eq 'Advanced'
		|| $parameters{QUERY_NAME}
		|| ($parameters{apply_action} 
		&& $parameters{display_type} ne 'Simple')  )
	{  #QUERY_NAME only set if print_full_form sub has been previously activated

		print_full_form( ref_parameters => \%parameters );

	}else {
		$sbeamsMOD->change_views_javascript();
		$sbeamsMOD->updateCheckBoxButtons_javascript();
		print_simple_form( \%parameters );
		show_arrays();
	}

}    #end handle_request

###############################################################################
# print_full_form
###############################################################################

sub print_full_form {

	my %args = @_;

	my %parameters = %{ $args{'ref_parameters'} };
	my $project_id = $sbeams->getCurrent_project_id();

	my %rs_params = $sbeams->parseResultSetParams( q => $q );

	my %url_cols      = ();
	my %hidden_cols   = ();
	my $limit_clause  = '';
	my @column_titles = ();
	my @previous_column_titles = ();
	my %max_widths    = ();
	my $show_sql      = '';
	#### Define some variables for a query and resultset
	my %resultset     = ();
	my $resultset_ref = \%resultset;

	my @downloadable_file_types = ();
	my @default_file_types      = ();
	my @diplay_files            = ();

	#### Define some generic varibles
	my ( $i, $element, $key, $value, $line, $result, $sql, @tmp );

	#### Read in the standard form values
	my $apply_action = $parameters{'action'}
	  || $parameters{'apply_action'}
	  || '';
	my $TABLE_NAME = $parameters{'QUERY_NAME'};

	#print "ACTION = '$apply_action'<br>";

	#### Set some specific settings for this program
	my $CATEGORY = "Get Affy Gene Intensity Values";
	$TABLE_NAME = "MA_GetAffy_GeneIntensity" unless ($TABLE_NAME);
	($PROGRAM_FILE_NAME) =
	  $sbeamsMOD->returnTableInfo( $TABLE_NAME, "PROGRAM_FILE_NAME" );
	my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME";
    my $manage_table_url = "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=MA_";
	#### Get the columns and input types for this table/query
	my @columns = $sbeamsMOD->returnTableInfo( $TABLE_NAME, "ordered_columns" );
	my %input_types = $sbeamsMOD->returnTableInfo( $TABLE_NAME, "input_types" );

	#### Read the input parameters for each column
	my $n_params_found = $sbeams->parse_input_parameters(
		q               => $q,
		parameters_ref  => \%parameters,
		columns_ref     => \@columns,
		input_types_ref => \%input_types
	);

	#### If the apply action was to recall a previous resultset, do it
	my %rs_params = $sbeams->parseResultSetParams( q => $q );
	if ( $apply_action eq "VIEWRESULTSET" ) {
		$sbeams->readResultSet(
			resultset_file       => $rs_params{set_name},
			resultset_ref        => $resultset_ref,
			query_parameters_ref => \%parameters,
			resultset_params_ref => \%rs_params,
			column_titles_ref => \@previous_column_titles,
		);
		$n_params_found = 99;
	}

	#### Set some reasonable defaults if no parameters supplied
	unless ( $parameters{input_form_format} ) {
		$parameters{input_form_format} = "minimum_detail";
	}

	#### Apply any parameter adjustment logic
	unless ( $parameters{project_id} ) {
		$parameters{project_id} = $sbeams->getCurrent_project_id();
	}

	show_other_query_page( type_to_show => 'Simple' )
	  unless $rs_params{output_mode};

	$sbeams->display_input_form(
		TABLE_NAME        => $TABLE_NAME,
		CATEGORY          => $CATEGORY,
		apply_action      => $apply_action,
		PROGRAM_FILE_NAME => $PROGRAM_FILE_NAME,
		parameters_ref    => \%parameters,
		input_types_ref   => \%input_types,
	);

	#### Display the form action buttons
	$sbeams->display_form_buttons( TABLE_NAME => $TABLE_NAME );

	#### Finish the upper part of the page and go begin the full-width
	#### data portion of the page
	$sbeams->display_page_footer(
		close_tables   => 'YES',
		separator_bar  => 'YES',
		display_footer => 'NO'
	);

	#########################################################################
	#### Process all the constraints

	#### Build PROJECT_ID constraint
	my $project_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "afs.project_id",
		constraint_type   => "int_list",
		constraint_name   => "Projects",
		constraint_value  => $parameters{project_id}
	);
	return if ( $project_clause eq '-1' );
	
	#### Build AFFY_ARRAY constraint
	my $affy_array_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "afa.affy_array_id",
		constraint_type   => "int_list",
		constraint_name   => "Affy Array",
		constraint_value  => $parameters{affy_array_id}
	);
	return if ( $affy_array_clause eq '-1' );

	#### Build GENOME_COORINATES constraint

	my $genome_coordinates_clause = '';
	if ( $parameters{genome_coordinates_constraint} ) {
		$genome_coordinates_clause =
		  convertGenomeCoordinates(
			genome_coordinates => $parameters{genome_coordinates_constraint}, );
		return if ( $genome_coordinates_clause eq '-1' );
	}
	#### If there is no genome_coordiante_constriant check to see if there is a request to show genomic data
	#### If so set the $parameters{genome_coordinates_#constraint} to a true val, which will then 
	#### add the columns to the output
	our $show_genome_2nd_query = '';
	unless($parameters{genome_coordinates_constraint}){
		#print STDERR "NO CONSTRIANT\n";
		if ($parameters{display_options} =~ /Show_Genome_position/){
				#print STDERR "I SEE CONSTRIANT\n";
				$show_genome_2nd_query = 'Y';
		}
	}

	#### Build PROBE SET ID constraint
	my $probe_set_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "anno.probe_set_id",
		constraint_type   => "plain_text",
		constraint_name   => "Affy Probe Set ID",
		constraint_value  => $parameters{probe_set_id_constraint}
	);
	return if ( $probe_set_clause eq '-1' );

	#### Build GENE TITLE constraint
	my $gene_title_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "anno.gene_title",
		constraint_type   => "plain_text",
		constraint_name   => "Gene Title",
		constraint_value  => $parameters{gene_title_constraint}
	);
	return if ( $gene_title_clause eq '-1' );

	#### Build GENE SYMBOL constraint
	my $gene_symbol_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "anno.gene_symbol",
		constraint_type   => "plain_text",
		constraint_name   => "Gene Symbol Constriants",
		constraint_value  => $parameters{gene_symbol_constraint}
	);
	return if ( $gene_symbol_clause eq '-1' );

	#### Build DBXREF constraint Name of the database an accession number came from
	our $dbxref_tag_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "dbxref.dbxref_tag",
		constraint_type   => "plain_text",
		constraint_name   => "Database Number Database",
		constraint_value  => $parameters{dbxref_tag_constraint}
	);
	return if ( $dbxref_tag_clause eq '-1' );

	#### Build DB_ID constraint	Actual accession number from a database
	our $db_id_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "db_links.db_id",
		constraint_type   => "plain_text",
		constraint_name   => "Accession Number",
		constraint_value  => $parameters{db_id_constraint}
	);
	return if ( $db_id_clause eq '-1' );

	#### Build Detection Call constraint
	our $detection_call_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "gi.detection_call",
		constraint_type   => "plain_text",
		constraint_name   => "Detection Call",
		constraint_value  => $parameters{detection_call_constraint}
	);
	return if ( $detection_call_clause eq '-1' );

	#### Build Detection P-Value Constraint constraint
	our $detection_p_value_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "gi.detection_p_value",
		constraint_type   => "flexible_float",
		constraint_name   => "Detection P-value",
		constraint_value  => $parameters{detection_p_value_constraint}
	);
	return if ( $detection_p_value_clause eq '-1' );

	#### Build Go Constraint constraint
	our $go_description_clause_2nd_query = $sbeams->parseConstraint2SQL(
		constraint_column => "go.gene_ontology_description",
		constraint_type   => "plain_text",
		constraint_name   => "Go Description Constriant",
		constraint_value  => $parameters{go_description_constraint}
	);
	return if ( $go_description_clause_2nd_query eq '-1' );
	

	our $go_sql_2nd_query_aref = '';
	#### Build Go Column Constraint ##Will build statements later on just set a flag for now
	if ($parameters{display_options} =~ /GO_/){
		
		 $go_sql_2nd_query_aref = 'Y';
	}
	return if ( $go_sql_2nd_query_aref eq '-1' );

	#print STDERR "GO CLAUSE '$go_sql_2nd_query_aref\n";
	#### Build Trans membrane Domain Constraint 
	our $trans_membrane_clause_2nd_query = $sbeams->parseConstraint2SQL(
		constraint_column => "tm.number_of_domains",
		constraint_type   => "flexible_float",
		constraint_name   => "Trans Membrane Number",
		constraint_value  => $parameters{trans_membrane_constraint}
	);
	return if ( $trans_membrane_clause_2nd_query eq '-1' ); 
	
	#### Build Protein Family Constraint  
	our $protein_family_clause_2nd_query = $sbeams->parseConstraint2SQL(
		constraint_column => "pf.description",
		constraint_type   => "plain_text",
		constraint_name   => "Protein Family",
		constraint_value  => $parameters{protein_families_constraint}
	);
	return if ( $protein_family_clause_2nd_query eq '-1' );
	
	#### Build Protein Domain Constraint 
	our $protein_doamin_clause_2nd_query = $sbeams->parseConstraint2SQL(
		constraint_column => "pd.protein_domain_description",
		constraint_type   => "plain_text",
		constraint_name   => "Protein Family",
		constraint_value  => $parameters{protein_domain_constraint}
	);
	return if ( $protein_doamin_clause_2nd_query eq '-1' );
	

	

	#### Build Signal constraint
	our $signal_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "gi.signal",
		constraint_type   => "flexible_float",
		constraint_name   => "Gene Stop Alignment bp",
		constraint_value  => $parameters{signal_constraint}
	);
	return if ( $signal_clause eq '-1' );

	#### Build Annotation Set constraint	Must use an annotation set id otherwise it will look through everything
	my $annotation_set_id = '';
	if ( $parameters{annotation_set_constraint} ) {
		$annotation_set_id = $parameters{annotation_set_constraint};
	}else {
		$annotation_set_id = $affy_o->get_annotation_set_id(
			affy_array_ids => $parameters{affy_array_id},
			project_id     => $parameters{project_id}
		);
	}

	my $annotation_set_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "anno_set.affy_annotation_set_id",
		constraint_type   => "int_list",
		constraint_name   => "Annotation Set ID",
		constraint_value  => $annotation_set_id
	);
	return if ( $annotation_set_clause eq '-1' );

	#### Build PROTOCOL_ID  constraint	PROTOCOL used to do the R_CHP analysis
	my $r_chp_protocol_id_clause = $sbeams->parseConstraint2SQL(
		constraint_column => "gi.protocol_id",
		constraint_type   => "int_list",
		constraint_name   => "R_CHP Protocol",
		constraint_value  => $parameters{protocol_id_constraint}
	);
	return if ( $r_chp_protocol_id_clause eq '-1' );
###END BUILD CONSTRIANTS
##############################################################################

	#### Build SORT ORDER
	my $order_by_clause = "";
	if ( $parameters{sort_order} ) {
		if ( $parameters{sort_order} =~
			/SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i )
		{
			print "<H4>Cannot parse Sort Order!  Check syntax.</H4>\n\n";
			return;
		}
		else {
			$order_by_clause = " ORDER BY $parameters{sort_order}";
		}
	}

	#### Build ROWCOUNT constraint
	$parameters{row_limit} = 10000
	  unless ( $parameters{row_limit} > 0
		&& $parameters{row_limit} <= 1000000 );
	my $limit_clause =
	  $sbeams->buildLimitClause( row_limit => $parameters{row_limit} );

	#### Define some variables needed to build the query
	my $group_by_clause = "";
	my @column_array;

	#### Get some information about the arrays involved
	my %affy_array_names;
	%affy_array_names = getArrayNames( $parameters{affy_array_id} )
	  if ( $parameters{affy_array_id} );

	my @array_names_and_ids;

	#### Define the available data columns.  Add more columns here that will be optional for the user #STR(gi.signal,8,2)
	my %available_columns = (
		"gi.signal"         => [ "signal", "gi.signal", "Affy Signal" ],
		"gi.detection_call" => [
			"detection_call", "gi.detection_call", "Affy R_CHP Detection Call"
		],
		"gi.detection_p_value" => [
			"detection_p_value", "gi.detection_p_value",
			"Affy R_CHP Detection P-value"
		],
		"gi.protocol_id" =>
		  [ "protocol_id", "gi.protocol_id", "R_CHP Protocol ID" ],

		"align.match_chromosome" =>
		  [ "match_chrom", "align.match_chromosome", "Match Chromosome" ],
		"align.gene_start" =>
		  [ "gene_start", "align.gene_start", "Gene Start" ],
		"align.gene_stop" => [ "gene_stop", "align.gene_stop", "Gene Stop" ],
		"align.percent_identity" =>
		  [ "percent_identity", "align.percent_identity", "Percent Match" ],

		"dbxref.dbxref_tag" =>
		  [ "database_name", "dbxref.dbxref_tag", "Database Name" ],
		"db_links.db_id" => [
			"database_accession_number", 
			"db_links.db_id",
			"Database Accession Number"
			],
		);

	#### If the user does not choose which data columns to show, set defaults
	my @additional_columns = ();
	my $display_columns    = $parameters{display_columns};
	unless ( defined( $parameters{display_columns} )
		&& $parameters{display_columns} )
	{
		#### If this is a pivoted query, just choose two interesting data columns
		if ( $parameters{display_options} =~ /PivotConditions/ ) {
			$display_columns = "gi.signal,gi.detection_call,gi.detection_p_value";
			#### Else, select them all
		}else {
			$display_columns =
			  "gi.signal,gi.detection_call,gi.detection_p_value";
		}
	}
	my $additional_group_by_clauses = '';
	### Look through the constraints that have data and make sure to add a column to the output

	add_constraint_columns(
		additional_cols        => \@additional_columns,
		avalible_columns       => \%available_columns,
		genome_coor_constraint => $parameters{genome_coordinates_constraint},
		default_columns        => $display_columns,
		additional_group_by_clauses => \$additional_group_by_clauses,
		display_options 	   => $parameters{display_options},
	);

	#### Make array of columns to display
	my @display_data_columns_a = split( ",", $display_columns );

#### If the Pivot is chosen, then define some things special
	my $aggregate_type        = "MAX";

	my $annotation_id_group_by 	= "anno.affy_annotation_id";
	my $probe_set_id_group_by   = "gi.probe_set_id";
	my $gene_title_group_by     = "anno.gene_title";
	my $gene_symbol_group_by    = "anno.gene_symbol";
	
	my $match_chrom_group_by   = '';
	my $gene_start_group_by    = '';
	my $gene_stop_group_by     = '';
	my $percent_match_group_by = '';

	if ($genome_coordinates_clause ) {
		 $match_chrom_group_by   = "align.match_chromosome";
		 $gene_start_group_by    = "align.gene_start";
		 $gene_stop_group_by     = "align.gene_stop";
		 $percent_match_group_by = "align.percent_identity";
	}

#### If this is a pivot query, design the aggregate data columns
	if ( $parameters{display_options} =~ /PivotConditions/ ) {
		my @affy_array_ids = split( /,/, $parameters{affy_array_id} );
		
		unless (@affy_array_ids){
			print "<h3>Please Select Some Arrays to Pivot the data On</h3>";
			die;
		}
		my $counter = 1;
		foreach my $id (@affy_array_ids) {
			foreach my $option (@display_data_columns_a) {
				if ( defined( $available_columns{$option} ) ) {
					my @elements = @{ $available_columns{$option} };
					$elements[0] = $affy_array_names{$id} . '__' . $elements[0];
					$elements[1] =
					    "$aggregate_type(CASE WHEN gi.affy_array_id = $id "
					  . "THEN $elements[1] ELSE NULL END)";
					$elements[2] = $affy_array_names{$id} . ' ' . $elements[2];
					push( @additional_columns, \@elements );
				}
			}
			$counter++;
		}

		my $first_group_by = "GROUP BY $probe_set_id_group_by";
		$group_by_clause = 	join ",",	($first_group_by,
										$annotation_id_group_by,
										$gene_title_group_by,
		  								$gene_symbol_group_by,
		  								$match_chrom_group_by,
					  					$gene_start_group_by,
					  					$gene_stop_group_by,
					  					$percent_match_group_by,
		  								$additional_group_by_clauses,
		  								);
		$group_by_clause =~ s/,{2,}/,/g;			#Remove any groups of commas and replace by with one
		$group_by_clause =~ s/,$//;					#hack to remove any commas at the end of the line
		 
	}else{

		  	foreach my $option (@display_data_columns_a) {				#mix together the default and any additonal columns to display
		  		
		  		if (defined($available_columns{$option})) {
		  			push(@additional_columns,$available_columns{$option});
		  		}
		  	}
	}

		  #### Define the desired columns in the query
		  #### [friendly name used in url_cols,SQL,displayed column title]	
		  my @column_array = (
		  ["affy_annotation_id", "anno.affy_annotation_id", "Annotation_ID"],
		  ["sample_id", "afs.affy_array_sample_id", "Sample_ID"],
		  ["sample_tag", "afs.sample_tag", "Sample Tag"],
		  ["probe_set_id","gi.probe_set_id","Probe Set ID"],
		  ["gene_symbol","anno.gene_symbol","Gene Symbol"],
		  @additional_columns,
		  ["file_root","afa.file_root","Affy File Root"],
		  ["full_sample_name", "afs.full_sample_name", "Sample Name"],
		  ["gene_title","anno.gene_title","Gene Title"], 	
		  );
		  
		  #### Hack to remove columns if GROUPing.  Must remove sample information since we are grouping on the data columns
		  if ($parameters{display_options} =~ /PivotConditions/){
		  	my $add_col_element_number = 5;
		  	my $count_additional_columns = scalar @additional_columns;
		  	my $end_element = ($add_col_element_number + $count_additional_columns) - 1;

		 	 @column_array = @column_array[0,3,4,$add_col_element_number..$end_element,-1];	#only take along the stuff we need leave behind the sample info

		  }
 #print STDERR "ADDITIONAL COLUMNS";
 #print STDERR Dumper (\@additional_columns);
		  #### Set the show_sql flag if the user requested
		  if ( $parameters{display_options} =~ /ShowSQL/ ) {
		  	$show_sql = 1;
		  }

		  #### Build the columns part of the SQL statement			#populates %colnameidx key =friendly name [0], key = coumn index
		  															#take the column names from the previous results set if this is not a query
		  
		  my %colnameidx     = ($apply_action eq 'VIEWRESULTSET') ? %{$resultset_ref->{column_hash_ref}} : ();
		     @column_titles  = ($apply_action eq 'VIEWRESULTSET') ? @previous_column_titles : ();
		
		  my $columns_clause = $sbeams->build_SQL_columns_list(		#makes columns_clause from the @column_array example $columns_clause .= "afa.file_root AS 'file_root'"  $column_array[1] AS $column_array[0]
		  column_array_ref=>\@column_array,
		  colnameidx_ref=>\%colnameidx,
		  column_titles_ref=>\@column_titles
		  );
#print STDERR Dumper(\%colnameidx);
		  #additional tables to add joins on only if there is a constraint added

		  my %additional_tables =(
		  db_links => "JOIN $TBMA_AFFY_DB_LINKS db_links ON (anno.affy_annotation_id = db_links.affy_annotation_id)",
		  align	   => "JOIN $TBMA_ALIGNMENT align ON (anno.affy_annotation_id = align.affy_annotation_id)",

		  dbxref   => "JOIN $TBMA_AFFY_DB_LINKS db_links ON (anno.affy_annotation_id = db_links.affy_annotation_id)". #NEED TO MAKE SURE THE db_link table join is included too
		              "JOIN $TB_DBXREF dbxref ON (db_links.dbxref_id = dbxref.dbxref_id)",

		   );

		  my $table_joins = produce_SQL_joins(column_clause 	=> $columns_clause,
		  								      additional_tables   => \%additional_tables,
		  									 );
		  #print "<br>EXTRA TABLE TO ADD '$table_joins'<br>";

		  #### In some cases, we need to have a subselect clause
		  my $subselect_clause = '';
		  if ( $parameters{display_options} =~ /AllConditions/ ) {
			  $subselect_clause = qq~
			  AND gi.probe_set_id IN (
			  SELECT DISTINCT gi.probe_set_id
			  FROM $TBMA_AFFY_ARRAY afa
			  INNER JOIN $TBMA_AFFY_ARRAY_SAMPLE afs
			  ON ( afa.affy_array_sample_id = afs.affy_array_sample_id )
			  INNER JOIN $TBMA_AFFY_GENE_INTENSITY gi
			  ON ( afa.affy_array_id = gi.affy_array_id )
			  INNER JOIN $TBMA_AFFY_ANNOTATION anno
			  ON (gi.probe_set_id = anno.probe_set_id)
			  INNER JOIN $TBMA_AFFY_ANNOTATION_SET anno_set
			  ON (anno_set.affy_annotation_set_id = anno.affy_annotation_set_id)
			  $table_joins
			  WHERE 1 = 1
			  $project_clause
			  $affy_array_clause
			  $probe_set_clause
			  $gene_symbol_clause
			  $gene_title_clause
	
			  $dbxref_tag_clause
			  $db_id_clause
	
			  $detection_call_clause
			  $detection_p_value_clause
			  $signal_clause
	
			  $genome_coordinates_clause
	
			  $annotation_set_clause
			  $r_chp_protocol_id_clause
			 
			  )
			  ~;
			  #### Remove contraints that might limit conditions
			  $detection_call_clause 	  = '';
			  $detection_p_value_clause = '';
			  $signal_clause 		  = '';
		  }

		  #### Define the SQL statement
		  $sql = qq~
		  SELECT $limit_clause->{top_clause}
		  $columns_clause
		  FROM $TBMA_AFFY_ARRAY afa
		  INNER JOIN $TBMA_AFFY_ARRAY_SAMPLE afs
		  ON ( afa.affy_array_sample_id = afs.affy_array_sample_id )
		  INNER JOIN $TBMA_AFFY_GENE_INTENSITY gi
		  ON ( afa.affy_array_id = gi.affy_array_id )
		  INNER JOIN $TBMA_AFFY_ANNOTATION anno
		  ON (gi.probe_set_id = anno.probe_set_id)
		  INNER JOIN $TBMA_AFFY_ANNOTATION_SET anno_set
		  ON (anno_set.affy_annotation_set_id = anno.affy_annotation_set_id)
		  $table_joins
		  WHERE 1 = 1
		  $project_clause
		  $affy_array_clause
		  $probe_set_clause
		  $gene_symbol_clause
		  $gene_title_clause

		  $dbxref_tag_clause
		  $db_id_clause

		  $detection_call_clause
		  $detection_p_value_clause
		  $signal_clause

		  $genome_coordinates_clause

		  $annotation_set_clause
		  $r_chp_protocol_id_clause
		  
		  $subselect_clause
		  
		  $group_by_clause
		  $limit_clause->{trailing_limit_clause}
		  ~;

		  #$show_sql = 1;
		  #### Certain types of actions should be passed to links
		  my $pass_action = "QUERY";
		  $pass_action = $apply_action if ($apply_action =~ /QUERY/i);

		
		  #### Define columns that should be hidden in the output table
		  %hidden_cols = (
		  	'Sample_ID'  => 1,
		  	'Annotation_ID' =>1,
			'GO Biological Process Link' => 1,		  
		    'GO Cellular Component Link' => 1,
		    'GO Molecular Function Link' => 1,
		   
		  );

#########################################################################
#### If QUERY or VIEWRESULTSET was selected, display the data

		  if ($apply_action =~ /QUERY/i || $apply_action eq "VIEWRESULTSET") {

			  #### If the action contained QUERY, then fetch the results from
			  #### the database
			  if ($apply_action =~ /QUERY/i) {
	
				  #### Show the SQL that will be or was executed
				  $sbeams->display_sql(sql=>$sql) if ($show_sql);
		    
				  #### Fetch the results from the database server
				  $sbeams->fetchResultSet(
				  sql_query=>$sql,
				  resultset_ref=>$resultset_ref,
				  );
#print STDERR Dumper($resultset_ref);

		 
		  
		
#################################################################
### Look to see if we need to do any 2nd queries which will gather data from any child tables
		
		if ( have_2nd_queires() ){
		 	my $m_sbeams = SBEAMS::Connection::Merge_results_sets->new();
			
			my $all_pk = $m_sbeams ->get_pk_from_results_set(results_set    => $resultset_ref, 
			  												pk_column_name => "affy_annotation_id",
			  								 				);
	
			##Look to see if we need to make some GO sql statments
			 my %second_sql_statements = ();
			 if  ($go_sql_2nd_query_aref eq 'Y'){
			 
			 	%second_sql_statements = convert_GO_display_options(display_param => $parameters{display_options},
		 														  go_desc_clause => $go_description_clause_2nd_query,	
		 														  all_pk => $all_pk,
		 														  );
			 }elsif ($go_description_clause_2nd_query){	#come here if the user only provided a term to constrain the GO data but did not indicate which columns
			 	%second_sql_statements = convert_GO_display_options(display_param => 'ALL',
		 														  	go_desc_clause => $go_description_clause_2nd_query,	
		 													  		all_pk => $all_pk,
		 														    );
			 }else{
			 }
			 
			#####Check for other secondary queries to run
			if ($protein_family_clause_2nd_query){
					$second_sql_statements{Protein_Family} = qq~SELECT  
															  pf.affy_annotation_id,
															  pf.description AS "Protein Family Description", 
															  pf.e_value AS "Protein Family E-value", 
															  db.db_id AS "Protein Family DB_ID"
															  FROM  $TBMA_PROTEIN_FAMILIES pf
															  JOIN $TBMA_AFFY_DB_LINKS db ON (pf.affy_db_links_id = db.affy_db_links_id)
															  WHERE pf.affy_annotation_id IN ($all_pk)
															  $protein_family_clause_2nd_query
															  ~;
			}
			if($protein_doamin_clause_2nd_query){
				$second_sql_statements{Protein_Domain} = qq~   SELECT
															  pd.affy_annotation_id,
															  pd.protein_domain_description AS "Protein Domain Description", 
															  db.db_id AS "Protein Domain DB_ID"
															  FROM  $TBMA_PROTEIN_DOMAIN pd
															  JOIN $TBMA_AFFY_DB_LINKS db ON (pd.affy_db_links_id = db.affy_db_links_id)
															  WHERE pd.affy_annotation_id IN ($all_pk)
															  $protein_doamin_clause_2nd_query
													     ~;
			}
			if($trans_membrane_clause_2nd_query	){								
				$second_sql_statements{Trans_Membrane_Domain} = qq~SELECT
																tm.affy_annotation_id,
															    tm.number_of_domains AS "Number of Predicted Trans Membrane Domains"
															    FROM  $TBMA_TRANS_MEMBRANE tm
															    WHERE tm.affy_annotation_id IN ($all_pk)
															    $trans_membrane_clause_2nd_query
															  ~;
			}
			
			if($show_genome_2nd_query){								
				#print STDERR "ABOUT TO ADD 2 QUERY\n";
				$second_sql_statements{Alignments} = qq~SELECT
																align.affy_annotation_id,
															    align.match_chromosome AS "Chromosome",
															    align.gene_start AS "Gene Start",
															    align.gene_stop AS "Gene End",
															    align.percent_identity AS "Precent Identity"
															    FROM  $TBMA_ALIGNMENT align
															    WHERE align.affy_annotation_id IN ($all_pk)
															  ~;
			}
			

	####################################################################
	###Run The sql queires		
			my $seconds_data_sets_aref = $m_sbeams->run_sql_statments(%second_sql_statements);
			
			foreach my $second_resultset_ref (@ {$seconds_data_sets_aref} ){	#loop thru all the secondary results sets appending the data to the main results set
			
				$m_sbeams->condense_results_set(results_set => $second_resultset_ref, #first condense down the results sets 
		  									merge_key => "affy_annotation_id",
		 							 	   );
			
				
				$m_sbeams->merge_results_sets( main_results_set => $resultset_ref,
											   column_to_append_after => 'gene_title',
											   merge_column_name =>	'affy_annotation_id',
											   second_results_set => $second_resultset_ref,
											   display_columns => \@column_titles,
											  );
											  
	
					
			}					 	   
		
			%colnameidx = %{ $resultset_ref->{column_hash_ref} } ;	#since we are adding data to the resultset has we also need to update the %colnameidx which is used in the construction of the URLs
			#print STDERR Dumper ($resultset_ref);
		}
		
		
								
#################################################################
		  
		  #### Store the resultset and parameters to disk resultset cache
		  $rs_params{set_name} = "SETME";
		  $sbeams->writeResultSet(
		  resultset_file_ref=>\$rs_params{set_name},
		  resultset_ref=>$resultset_ref,
		  query_parameters_ref=>\%parameters,
		  resultset_params_ref=>\%rs_params,
		  query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
		  column_titles_ref=>\@column_titles,
		  );
	 }#End of the QUERY ONLY IF STATMENT
	
	 #### Define the hypertext links for columns that need them
		my $anno_base_url     = "$CGI_BASE_DIR/Microarray/$PROG_NAME?action=SHOW_ANNO&annotation_set_id=$annotation_set_id";
		  %url_cols = (
		 	'Probe Set ID'=> "$anno_base_url&probe_set_id=\%V",
		  	'Sample Tag'	=> "${manage_table_url}affy_array_sample&affy_array_sample_id=\%0V",
		  	'GO Biological Process Description' => "http://www.ebi.ac.uk/ego/QuickGO?mode=display&entry=\%$colnameidx{'GO Biological Process Link'}V",
            'GO Biological Process Description_ATAG' => 'TARGET="WinExt"',
            'GO Biological Process Description_OPTIONS' => {semicolon_separated_list=>1},
		  
			'GO Cellular Component Description' => "http://www.ebi.ac.uk/ego/QuickGO?mode=display&entry=\%$colnameidx{'GO Cellular Component Link'}V",
            'GO Cellular Component Description_ATAG' => 'TARGET="WinExt"',
            'GO Cellular Component Description_OPTIONS' => {semicolon_separated_list=>1},
            
            'GO Molecular Function Description' => "http://www.ebi.ac.uk/ego/QuickGO?mode=display&entry=\%$colnameidx{'GO Molecular Function Link'}V",
            'GO Molecular Function Description_ATAG' => 'TARGET="WinExt"',
            'GO Molecular Function Description_OPTIONS' => {semicolon_separated_list=>1},	  
		  
		  
		  );  	 

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

		  #### Display a plot of data from the resultset
		  $sbeams->displayResultSetPlot(
		  rs_params_ref=>\%rs_params,
		  resultset_ref=>$resultset_ref,
		  query_parameters_ref=>\%parameters,
		  column_titles_ref=>\@column_titles,
		  base_url=>$base_url,
		  );

		  #### If QUERY was not selected, then tell the user to enter some parameters
		  } else {
		  	if ($sbeams->invocation_mode() eq 'http') {
		  	print "<H4>Select parameters above and press QUERY</H4>\n";
		  } else {
		  	print "You need to supply some parameters to contrain the query\n";
		  }
	}

}

  ###############################################################################
  # getArrayNames: return a hash of the arrays
  #         names of the supplied list of id's.
  #         This might need to be more complicated if condition names
  #         are duplicated under different projects or such.
  ###############################################################################
sub getArrayNames {
  my $array_ids = shift || die "getArrayNames: missing array_ids";

		  #my @array_ids = split(/,/,$array_ids);

		  #### Get the data for all the specified affy_array_ids
  my $sql = qq~
  			SELECT affy_array_id,file_root
  			FROM $TBMA_AFFY_ARRAY
  			WHERE affy_array_id IN ( $array_ids )
 		 ~;

		  # print "GET ARRAY NAMES SQL '$sql'<br>";
  my %hash = $sbeams->selectTwoColumnHash($sql);

	return %hash;
} # end getArrayNames

###############################################################################
# print_simple_form
###############################################################################
sub print_simple_form {
  my $params = shift;

  for my $p ( qw( probe_set_id gene_name accession_number ) ) {
    $params->{$p} = '' unless defined $params->{$p};
  }
  # Make this sticky?
  my $cp = ( $params->{coalesce_probesets} ) ? 'CHECKED' : '';
  my $cr = ( $params->{coalesce_replicates} ) ? 'CHECKED' : '';

  $sbeams->printUserContext();

  print "<br><hr>";
  show_other_query_page(type_to_show=>'Advanced');
  print $q->start_form({-name=>'get_all_files'});		#Same form element is used for the array check boxes
  print "<br/>";

  print get_documentation_link() . "<BR>";

  print $q->table( {-border=>0},
		  caption({-class=>'grey_bg'},'Simple Query'),
		  Tr({-class=>'grey_bg'},
		  td("Affy Probe Set ID"),
		  td($q->textfield( -name=>'probe_set_id',
                  		  -size=>25,
                  		  -value=>$params->{probe_set_id},
                        -maxlength=>2560)),
  ),
		  Tr( {-class=>'grey_bg'},
		  td("Gene Name"),
		  td($q->textfield(-name=>'gene_name',
		  -size=>25,
		  -maxlength=>2560)),
		  ),
		  Tr( {-class=>'grey_bg'},
		  td("Accession Number"),
		  td($q->textfield(-name=>'accession_number',
		  -size=>25,
		  -maxlength=>2560)),

      Tr( {-class=>'grey_bg'},
		  td("Coalesce probesets"),
		  td("<INPUT TYPE=checkbox name='coalesce_probesets' $cp></INPUT>")
      ),

		  Tr( {-class=>'grey_bg'},
		  td("Coalesce replicates"),
		  td("<INPUT TYPE=checkbox name='coalesce_replicates' $cr></INPUT>")
      ),

      
		  Tr(
		  td("'%' is wildcard character")),
		  Tr(
		  td("'_' is single character wildcard")),
		  Tr(
		  td("character range search '[a-m]'; no other regexps supported")),
		  )
  
  );

  print "<br/>";
  print $q->submit( -name=>'submit_query', -value=>'Run Query');
  print $q->hidden(-name=>'action', -default=>'SIMPLE_QUERY');
  print "<p><hr><p>";
}

###############################################################################
# show_arrays Show all the arrays that can provide data
###############################################################################
	sub show_arrays {

		my %args = @_;

		my %parameters = $args{'ref_parameters'};
	  	my $project_id = $sbeams->getCurrent_project_id();

		my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || '';
		
		my %rs_params = $sbeams->parseResultSetParams(q=>$q);
		$rs_params{page_size} = 500;	#need to override the default 50 row max display for a page
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

		my $sql = '';

		@default_file_types = qw(R_CHP);
	  	#@display_file_types(R_CHP);
	  	@downloadable_file_types = qw(R_CHP);				#Will use these file extensions

		  ## Print the data

		my @array_ids = $affy_o->find_chips_with_R_CHP_data(project_id => $project_id);	#find affy_array_ids in the, could be multipule arrays with differnt protocols usedfor quantification
    $log->debug( "Found $#array_ids array IDs" );
		  

		my $constraint_data = join " , ", @array_ids;
		my $constraint_column = "afa.affy_array_id";
		my $constraint        = "AND $constraint_column IN ($constraint_data)";
#$log->debug("AFFY ARRAY IDS '$constraint_data'");
		unless ($constraint_data) {
			print
			  "SORRY NO DATA FOR THIS PROJECT\n";
			return;
		}

		print "<h2 class='grey_bg'> Choose the arrays to view data from </h2>";

		unless ( exists $parameters{Get_Data} ){    #start the form to select which affy arrays to display data from

			print $q->start_form(
				-name => 'get_all_files'
				,    
				-action => "$CGI_BASE_DIR/Microarray/$PROG_NAME",
			);

			$sbeamsMOD->make_checkbox_control_table(
				box_names          => \@downloadable_file_types,
				default_file_types => \@default_file_types,
			);

		}

		my $sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;


		$sbeams_affy_groups->setSBEAMS($sbeams);    #set the sbeams object into the affy_groups_object

		$sql = $sbeams_affy_groups->get_affy_arrays_sql(
			project_id => $project_id
			, #return a sql statement to display all the arrays for a particular project
			constraint => $constraint
		);
#$log->debug("SQL '$sql'");
		%url_cols = (
			'Sample_Tag' =>"${manage_table_url}affy_array_sample&affy_array_sample_id=\%3V",
			'File_Root' => "${manage_table_url}affy_array&affy_array_id=\%0V",
		);

		%hidden_cols = (
			'Sample_ID' => 1,
			'Array_ID'  => 1,
		);

################################################################################
### Print out the data

		if ( $apply_action eq "VIEWRESULTSET" ) {
			$sbeams->readResultSet(
				resultset_file       => $rs_params{set_name},
				resultset_ref        => $resultset_ref,
				query_parameters_ref => \%parameters,
				resultset_params_ref => \%rs_params,
			);
		}

		#### Fetch the results from the database server
		$sbeams->fetchResultSet(
			sql_query     => $sql,
			resultset_ref => $resultset_ref,
		);

		####################################################################
		## Need to Append data onto the data returned from fetchResultsSet in order to use the writeResultsSet method to display a nice html table

		unless ( exists $parameters{Display_Data} ) {

			#overloading this method, change names to indicate what it is doing
			append_new_data(
				resultset_ref => $resultset_ref,
				file_types    => \@downloadable_file_types
				,    #append on new values to the data_ref foreach column to add
				default_files => \@default_file_types,
				display_files =>
				  \@diplay_files #Names for columns which will have urls to pop open files
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
			base_url             => "$base_url?display_type=Simple",
		);

		#$log->debug(Dumper(\%rs_params));

			print $q->br,
			  $q->submit(
				-name  => 'submit_query',
				-value => 'simple_query'
			  )
			  ; #will need to change value if other data sets need to be downloaded

			print $q->reset;
			
			print $q->end_form;

			print "<br><h>";

		

	}

###############################################################################
# append_new_data
#
# Append on the more columns of data which can then be shown via the displayResultSet method
###############################################################################

	sub append_new_data {
		my %args = @_;

		my $resultset_ref = $args{resultset_ref};
		my @file_types    = @{ $args{file_types} }; 	  #array ref of columns to add
		my @default_files = @{ $args{default_files} };    #array ref of column names that should be checked
		my @display_files = @{ $args{display_files} }; 	  #array ref of columns to make which will have urls to files to open

		my $aref =
		  $$resultset_ref{data_ref}; #data is stored as an array of arrays from the $sth->fetchrow_array each row a row from the database holding an aref to all the values

		########################################################################################
		foreach my $display_file (@display_files){    #First, add the Columns for the files that can be viewed directly

			foreach my $row_aref ( @{$aref} ) {

				my $array_id  = $row_aref->[0] ; #need to make sure the query has the array_id in the first column since we are going directly into the array of arrays and pulling out values
				my $root_name = $row_aref->[1];

#loop through the files to make sure they exists.  If they do not don't make a check box for the file
				my $file_exists = check_for_file(
					affy_array_id  => $array_id,
					file_root_name => $root_name,
					file_extension => $display_file,
				);

				my $anchor = '';
				if ( $display_file eq 'JPEG' && $file_exists ) {
					$anchor =
"<a href=View_Affy_files.cgi?action=view_image&affy_array_id=$array_id&file_ext=$display_file>View</a>";

				}elsif ($file_exists) {    			#make a url to open this file
					$anchor =
"<a href=View_Affy_files.cgi?action=view_file&affy_array_id=$array_id&file_ext=$display_file>View</a>";
				}else {
					$anchor = "No File";
				}

				push @$row_aref, $anchor;    		#append on the new data
			}

			push @{ $resultset_ref->{column_list_ref} }, "View $display_file";    #add on column header for each of the file types
			 #need to add the column headers into the resultset_ref since DBInterface display results will reference this

			append_precision_data($resultset_ref); 	#need to append a value for every column added otherwise the column headers will not show
		}

		########################################################################################

		foreach my $file_ext (@file_types){       #loop through the column names to add checkboxes
			my $checked = '';
			if ( grep { $file_ext eq $_ } @default_files ) {
				$checked = "CHECKED";
			}

			foreach my $row_aref ( @{$aref} )
			{ #serious breach of encapsulation,  !!!! De-reference the data array and pushes new values onto the end

				my $array_id  = $row_aref->[0]; #need to make sure the query has the array_id in the first column since we are going directly into the array of arrays and pulling out values
				my $root_name = $row_aref->[1];

#loop through the files to make sure they exists.  If they do not don't make a check box for the file
				my $file_exists = check_for_file(
					affy_array_id  => $array_id,
					file_root_name => $root_name,
					file_extension => $file_ext,
				);

				my $input = '';
				if ($file_exists)
				{ #make Check boxes for all the files that are present <array_id__File extension> example 48__CHP
					$input = "<input type='checkbox' name='get_all_files' value='${array_id}__$file_ext' $checked>";
				}
				else {
					$input = "<input type='checkbox' name='get_all_files' value='${array_id}__$file_ext' $checked>";
				}

				push @$row_aref, $input;    #append on the new data

			}

			push @{ $resultset_ref->{column_list_ref} },
			  "$file_ext";    #add on column header for each of the file types
			 #need to add the column headers into the resultset_ref since DBInterface display results will refence this

			append_precision_data($resultset_ref)
			  ; #need to append a value for every column added otherwise the column headers will not show

		}

	}

###############################################################################
	# show_data
###############################################################################
	sub show_data {
		my %args       = @_;
		my %parameters = %{ $args{ref_parameters} };

		#### Define some variables for a query and resultset
		my %resultset     = ();
		my $resultset_ref = \%resultset;
		my ($sql);
	
		my %rs_params        = $sbeams->parseResultSetParams( q => $q);
		my $base_url         = "$CGI_BASE_DIR/Microarray/$PROG_NAME";
		my $manage_table_url =
		  "$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=MA_";

		my %url_cols      = ();
		my %hidden_cols   = ();
		my $limit_clause  = '';
		my @column_titles = ();
		my %max_widths    = ();

##########################################################################
### Convert the array_ids__File Ext checkbox names to array_ids only

		my $arrays_id_string =
		  $parameters{get_all_files}; #example '37__CEL,38__CEL,45__CEL,46__CEL,46__XML'

		my @array_ids = split /,/, $arrays_id_string
		  ; #remove any redundant affy_ids since one affy_array_id might have multipule file extensions

		my %unique_array_ids = map { split /__/ } @array_ids;

		my $arrays = join ",", sort keys %unique_array_ids;

		unless ($arrays) {
			print
"<h2>Please Go Back and select some arrays to display data from</h2>";
			return;
		}

		#### Build PROBE SET ID constraint probe_set_id
		my $probe_set_id_clause = $sbeams->parseConstraint2SQL(
			constraint_column => "gi.probe_set_id",
			constraint_type   => "plain_text",
			constraint_name   => "Probe Set IS",
			constraint_value  => $parameters{probe_set_id}
		);

		#### Build GENE NAME constraint
		my $gene_name_clause = $sbeams->parseConstraint2SQL(
			constraint_column => "anno.gene_name",
			constraint_type   => "plain_text",
			constraint_name   => "Gene Name",
			constraint_value  => $parameters{gene_name}
		);

		#### Build ACCESSION NUMBER
		my $accession_number_clause = $sbeams->parseConstraint2SQL(
			constraint_column => "link.db_id",
			constraint_type   => "plain_text",
			constraint_name   => "Accession Number",
			constraint_value  => $parameters{accession_number}
		);

		return
		  if ( $probe_set_id_clause eq '-1' )
		  ; #FIX ME NEED TO DO SOMETHIING WITH THE RETURN VALUE TO INDICATE THE CONSTRAINT DID NOT WORK or do we.....
		return if ( $gene_name_clause        eq '-1' );
		return if ( $accession_number_clause eq '-1' );

		unless ( $probe_set_id_clause
			|| $gene_name_clause
			|| $accession_number_clause )
		{

			print "<h2>Please Enter A Query Term </h2>";
			return;
		}

		#make the SQL Query

		my $annotation_set_id =
		  $affy_o->get_annotation_set_id( affy_array_ids => $arrays );

		my $R_CHP_protocol_id =
		  $affy_o->get_r_chp_protocol( affy_array_ids => $arrays )
		  ;   #FIX ME NEED LOGIC TO WARN USER IF MORE THEN ONE PORTOCOL IS FOUND

		$sql = $affy_o->get_affy_intensity_data_sql(
			affy_array_ids     => $arrays,
			annotation_display => 'lite'
			,    #control if a little or a lot of annotation should be displayed nothing implemneted yet
			constraints => [
				$probe_set_id_clause, $gene_name_clause,
				$accession_number_clause,
			],
			r_chp_protocol => $R_CHP_protocol_id,
			annotation_id  => $annotation_set_id,
		);
#$sbeams->display_sql(sql=>$sql);
#$log->debug( $sql );
		#### Fetch the results from the database server
		$sbeams->fetchResultSet(
			sql_query     => $sql,
			resultset_ref => $resultset_ref,
		);

		
		convert_data(
			resultset_ref => $resultset_ref
			, #data_display_type html turn values into colors, text show the numbers
			data_display_type => 'html',
			annotation_set_id => $annotation_set_id,
      coalesce_replicates => $parameters{coalesce_replicates},
      coalesce_probesets => $parameters{coalesce_probesets}
		);

		
	}

sub deconvert_numerical_data {
  my @deconverted;
  foreach my $num (@_) {
    my $trans =  10**(($num/CONVERSION_F)+1); 
    my $converted = ( ( $trans - int($trans) ) > 0.5 ) ? int( $trans + 1 ) : int( $trans );
#    $log->debug( "$num => $converted" );
#      $converted = 1 if $converted < 1;
#      $converted = 250 if $converted > 250;
    push @deconverted, $converted;
  }
  return @deconverted;
}

##############################################################################
# convert_numerical_data
#
# Convert an array of numbers to log10 based numbers and round to nearest int
###############################################################################
sub convert_numerical_data {
  my @converted_data = ();
  foreach my $original (@_) {
#      my $converted =  int( ( CONVERSION_F * log10($_) ) );
    my $num = ( $original < 10 ) ? 10 : 
              ( $original > 10000 ) ? 10000 : $original;

    my $trans = ( CONVERSION_F * (log10($num) - 1 ) );
    my $converted = ( ( $trans - int($trans) ) > 0.5 ) ? int( $trans + 1 ) : int( $trans );
#    $log->debug( "$num => $trans => $converted" );
#      $converted = 1 if $converted < 1;
#      $converted = 250 if $converted > 250;
    push @converted_data, $converted;
  }
  return @converted_data;
}
##############################################################################
	# make_color_h
	#
	# Make a hash to hold the grey scale color conversion map
###############################################################################
sub make_color_h {

  my @digit = reverse(qw(0 1 2 3 4 5 6 7 8 9 A B C D E F));

  my $count = 0;
  for ( my $i = 0 ; $i <= $#digit ; $i++ ) {
    for ( my $j = 0 ; $j <= $#digit ; $j++ ) {
      # Going to skip the lightest colors...
      if ( $digit[$i] eq 'F' &&  $digit[$j] =~ /F|E|D|C|B/ ) {
        next;
      }
      $CONVERSION_H{$count++} = "$digit[$i]$digit[$j]" x 3; # make the hex grey color
    }
  }
  return;
  print "<TABLE>\n";
  for my $k ( sort { $a <=> $b }( keys( %CONVERSION_H ) ) ) { print FIL "<TR><TD BGCOLOR=$CONVERSION_H{$k}>$k</TD></TR>\n"; }
  print  "</TABLE>\n";
}

##############################################################################
# print_table_legend
#
#  make a description of what all the boxes are
###############################################################################
sub print_table_legend {
  my $coalesced = shift;
  my $table_cells = '';

  my $end_space = MAX_DATA_SPREAD + 1;
  my @log_space = 2 .. $end_space ;

  print qq~ <hr>
  <P>
  <H3 class='grey_bg'>Affy R_CHP Intensity Values Key</H3>
  ~;

  $table_cells = "<table border=0>";
  $table_cells .= "<tr><td NOWRAP=1>10 (and below) </td>";    #start the first row of the table

  my $start_range; # = 10;
  my $end_range; #   = 10;
  my $key_count = 0;
  my @range = 0 .. int(CONVERSION_F);

  foreach my $log_base (@log_space) {    #loop thru the log space
    my $end_range = convert_number($log_base);
    my $and_above = ( $end_range ==  10000 ) ? ' (and above)' : '';

    for ( my $i = 0 ; $i <= $#range; $i += 2 ) { # for each log show the number of cells the space is broken into
      my ( $decon ) = deconvert_numerical_data( $key_count );
      $table_cells .= "<td bgcolor='$CONVERSION_H{$key_count}' width=6><DIV TITLE='$decon'> &nbsp;</DIV></td>";
      $key_count += 2;
      die( "COUNT AT $key_count I= $i SOME THING IS WORONG MAKING TABLE LEGEND<br>") if $key_count == 258;
    }

    my $exp_end_range = 1;
    if ( $end_range == 10 ) { $exp_end_range = 10; 
    } elsif ( $end_range == 100 ) { $exp_end_range = "10<SUP>2</SUP>"; 
    } elsif ( $end_range == 1000 ) { $exp_end_range = "10<SUP>3</SUP>"; 
    } elsif ( $end_range == 10000 ) { $exp_end_range = "10<SUP>4</SUP>"; 
    } elsif ( $end_range == 100000 ) { $exp_end_range = "10<SUP>5</SUP>"; 
    }  

    # end the row give the number in real space not log space
    $table_cells .= "<td NOWRAP=1>$end_range $and_above</td></tr>";
    # start the new row
    $table_cells .= "<tr><td>" . ( $end_range + 1 ) . "</td>" unless ( $log_base == $end_space );
      $start_range = $end_range + 1;
  }

  #information about the present absent calls
  unless ( $coalesced ) {
    $table_cells .=
"<tr><td class='present_cell'>Present Call No border</td><td class='present_cell' bg_color=#FFFFFF width=7 height=7>&nbsp;</td></tr>";
    $table_cells .=
"<tr><td class='marginal_cell'>Marginal Call Blue border</td><td class='marginal_cell' bg_color=#0000FF width=7 height=7>&nbsp;</td></tr>";
    $table_cells .=
"<tr><td class='absent_cell'>Absent Call Red border</td><td class='absent_cell' bg_color=#FFFFFF width=7 height=7>&nbsp;</td></tr>";
  }

  $table_cells .= "</table>";
  print $table_cells;
  return;

  print "<TABLE>\n";
#  for my $k ( sort { $a <=> $b }( keys( %CONVERSION_H ) ) ) { 
  for my $k ( qw( 1 5 10 50 100 500 1000 5000 10000 50000 100000 ) ) { 
  my ( $converted ) = convert_numerical_data($k);
  my $fb = ( $converted <= 125 ) ? '' : '<FONT COLOR=white>';
  my $fe = ( $converted <= 125 ) ? '' : '</FONT>';
  print "<TR><TD BGCOLOR=$CONVERSION_H{$converted}>$fb $k => $converted $fe</TD></TR>\n";
  }
  print  "</TABLE>\n";
  return;

  my $tab = '<TABLE><TR>';
  my $space = '&nbsp;';
  for ( my $i = 0; $i <= MAX_DATA_SPREAD; $i += .25 ) {
    $tab .= "<TD bgcolor='$CONVERSION_H{$i}' width=4>$space</TD>";
  }
  $tab .= '</TR></TABLE>';
  print $tab;
}

##############################################################################
	# convert_number
	#raise 10 to the given exp number
##############################################################################
	sub convert_number {

		my $number = shift;

		return sprintf( "%.0f", pow( 10, $number ) );
	}
##############################################################################
# make_table_cells
#
# supply an array of numbers convert to log10 then make a table cell for each number with a grey scale background
#return an array of table cells
###############################################################################
	sub make_table_cells {

		my %args = @_;

		my @numerical_data  = @{ $args{numerical_data} };
		my @detection_calls = @{ $args{detection_call} };

		my @converted_data = convert_numerical_data(@numerical_data);

		my @table_cells = ();

		for ( my $i = 0 ; $i <= $#numerical_data ; $i++ ) {
			my $number         = $converted_data[$i];
			my $detection_call = $detection_calls[$i];

			my $class    = '';
			my $bg_color = '';
      my $title = 'Signal = ' . sprintf( "%0.2f", $numerical_data[$i] );
   		my $cell_val = "<DIV TITLE= '$title'> &nbsp;</DIV>";
			if ( exists $CONVERSION_H{$number} ) {
				$bg_color = $CONVERSION_H{$number};

			}
			else {
#        $log->debug( "for number $i, numeric is $numerical_data[$i] and converted is $number; color is $CONVERSION_H{$number}" );
				$bg_color = '#000000'
				  ; #if the value is very low set the bg_color to Black and put "L" in the cell to indicate what we did
				$cell_val = 'L';
			}

			if ( $detection_call eq 'P' || $args{coalesced} ) {
				$class = 'present_cell';
			}
			elsif ( $detection_call eq 'M' ) {
				$class = 'marginal_cell';
			}
			elsif ( $detection_call eq 'A' ) {
				$class = 'absent_cell';
			}
			else {
			}

			push @table_cells,
			  "<td bgcolor='$bg_color' class='$class' width=16>$cell_val</td>";

		}
		return @table_cells;
	}

##############################################################################
 # convert_data
 #
 # Take the resultset_ref pivot the data and add color for the expression values
###############################################################################
sub convert_data {

#gi.probe_set_id), afa.file_root, gi.affy_array_id, gi.signal, gi.detection_call, anno.gene_symbol, anno.gene_title, gi.protocol_id
  my %args = @_;

  my $resultset_ref     = $args{resultset_ref};
  my $data_display_type = $args{data_display_type};
  my $annotation_set_id = $args{annotation_set_id};
  $args{coalesce_replicates} ||= '';
  $args{coalesce_probesets} ||= '';
  my $rep_key = ( $args{coalesce_replicates} ) ? 'sample_group_name' : 'file_root';
  my $id_key = ( $args{coalesce_probesets} ) ? 'gene_symbol' : 'probe_set_id';
  my $coalesced = ( $args{coalesce_replicates} || $args{coalesce_probesets} ) ? 1 : 0;

  my $anno_base_url     =
"$CGI_BASE_DIR/Microarray/$PROG_NAME?action=SHOW_ANNO&annotation_set_id=$annotation_set_id";

  # data is stored as an array of arrays from the $sth->fetchrow_array 
  my $aref = $$resultset_ref{data_ref}; 

  # see if query hit anything
  unless ( defined $$aref[0] ) { 
    print "<h2>Sorry Your Search Did Term Did Not Return Any Results Please Try Again</h2>";
  return;
  }

		

  my @column_titles = @{ $resultset_ref->{column_list_ref} };
    
  # going to make a hash of hashes to do the pivot
  my %pivot_h = ();
  foreach my $aref_row (@$aref) {
    my %data_h = make_hash_of_row( aref         => $aref_row,
                                   column_names => \@column_titles );
#      for my $k ( keys( %data_h ) ) { print "$k => $data_h{$k}\n<BR>"; }
#      $log->debug( $data_h{sample_group_name} );
#      exit;

  # load the pivot hash with data  Very strange way to look at entering data into
  # a hash of hashes of hashes....  Yes, very strange indeed (DSC)
    $pivot_h{$data_h{$id_key}}{R_PROTOCOL}{$data_h{protocol_id}}{ARRAYS}{$data_h{$rep_key}}->{TOT_SIGNAL} += $data_h{signal};
    $pivot_h{$data_h{$id_key}}{R_PROTOCOL}{$data_h{protocol_id}}{ARRAYS}{$data_h{$rep_key}}->{NUMBER}++;
    $pivot_h{$data_h{$id_key}}{R_PROTOCOL}{$data_h{protocol_id}}{ARRAYS}{$data_h{$rep_key}}->{DETECTION_CALL} = $data_h{detection_call};
#			$pivot_h{$data_h{$id_key}}{R_PROTOCOL}{$data_h{protocol_id}}{ARRAYS}{$data_h{$rep_key}}->{SIGNAL} = $data_h{signal};
    $pivot_h{$data_h{$id_key}}{R_PROTOCOL}{$data_h{protocol_id}}{ARRAYS}{$data_h{$rep_key}}->{SIGNAL} = 
    $pivot_h{$data_h{$id_key}}{R_PROTOCOL}{$data_h{protocol_id}}{ARRAYS}{$data_h{$rep_key}}->{TOT_SIGNAL}/ 
    $pivot_h{$data_h{$id_key}}{R_PROTOCOL}{$data_h{protocol_id}}{ARRAYS}{$data_h{$rep_key}}->{NUMBER}; 

    for my $k ( qw( TOT_SIGNAL NUMBER DETECTION_CALL SIGNAL AVERAGE ) ) {
      $log->debug( "$data_h{$id_key}->$k => $pivot_h{$data_h{$id_key}}{R_PROTOCOL}{$data_h{protocol_id}}{ARRAYS}{$data_h{$rep_key}}->{$k}" ) if $data_h{gene_symbol} eq 'KLK14';
# && $data_h{sample_group_name} eq 'CD104t' ); 
    }
    $log->debug( "" ) if $data_h{gene_symbol} eq 'KLK14'; #if ( $data_h{$id_key} eq '242127_at' && $data_h{sample_group_name} eq 'CD104t' ); 

    #load the pivot hash with annotation
    $pivot_h{ $data_h{$id_key} }{ANNOTATION} = { GENE_SYMBOL => $data_h{gene_symbol},
                                                 GENE_TITLE  => $data_h{gene_title} };

  }

=head 1	

example view of pivot hash
	
		my $$id_key = $data_h{$id_key};
	
	    	$pivot_h{$$id_key} = { 
						  R_PROTOCOL => { 
								$data_h{protocol_id} =>
											{ARRAYS => {	#using the file_root name instead of the array id check for problems of uniquness .....
												     $data_h{$rep_key} => { SIGNAL 	   => $data_h{signal},
												     			    DETECTION_CALL => $data_h{detection_call},
															   },
													     },
									         	 },
								},
								
						  ANNOTATION => {GENE_SYMBOL => $data_h{gene_symbol}, 
						  		  GENE_TITLE  => $data_h{gene_title},
								  },
					     };
		

=cut

  #print Dumper (\%pivot_h);

  # rearange the data to make a new results set


  my @data_rows            = ();
  my @new_column_names     = ();

  push @new_column_names, "Affy Probe Set ID" unless $args{coalesce_probesets};
  push @new_column_names, "Gene Symbol";

  my $count = 1;
  foreach my $probe_set_id ( sort keys %pivot_h ) {
    my @column_of_data;
    # Add the probeset id iff we didn't coalesce probesets into genes
    push @column_of_data, $probe_set_id unless $args{coalesce_probesets};
    # Add the gene symbol
    push @column_of_data, $pivot_h{$probe_set_id}{ANNOTATION}{GENE_SYMBOL};

    foreach my $r_protocol_href ( sort keys %{ $pivot_h{$probe_set_id}{R_PROTOCOL} } ) {
      my @numerical_data = ();
      my @detection_call = ();
      foreach my $arrays_href ( sort (keys %{$pivot_h{$probe_set_id}{R_PROTOCOL}{$r_protocol_href}{ARRAYS}}) ) {
#        $log->debug( "here comes $arrays_href" );
        # collect the numerical data to color the cells	#collect the signal intensity
        push @numerical_data, $pivot_h{$probe_set_id}{R_PROTOCOL}{$r_protocol_href}{ARRAYS}{$arrays_href}{SIGNAL}; 
        push @detection_call, $pivot_h{$probe_set_id}{R_PROTOCOL}{$r_protocol_href}{ARRAYS}{$arrays_href}{DETECTION_CALL};

        # Collect the array file_root names.  Removed protocol 05/2006 DSC
        # push @new_column_names, "${arrays_href}_P_${r_protocol_href}_CALL" if $count == 1;
        push @new_column_names, make_table_name(${arrays_href}) if $count == 1;
      }
      #return list of table cells with bk_ground coloring
      my @table_cells = make_table_cells( numerical_data => \@numerical_data,
                                          detection_call => \@detection_call,
                                          coalesced => $coalesced );

      # compute the mean and max intensity, useful for sorting the data
      my ( $avg_intensity, $max_intensity ) = compute_mean(@numerical_data); 

      push @column_of_data, [@table_cells];

      push @column_of_data, $avg_intensity, $max_intensity;
      push @new_column_names, "Mean Intensity", "Max Intensity" if $count == 1;

      $count++;
    }
    push @column_of_data, $pivot_h{$probe_set_id}{ANNOTATION}{GENE_TITLE};
    push @data_rows, [@column_of_data];
  }
  push @new_column_names, "Gene Title";

  # Begin to print out the content 
  print "<table border=0> <tr>";

  my $back_link = get_back_link();
  my $total_columns = scalar( @new_column_names );
  print "<TD ALIGN=left COLSPAN=$total_columns>$back_link</TD></TR><TR>";

  foreach my $col_name (@new_column_names) {   #Print out the Column names
    print "<td class='grey_bg'>$col_name</td>";
  }
  print "</tr>\n";

#  my @sorted_data = sort_data_rows(@data_rows);
#  foreach my $row (@sorted_data) { 
  # Print out the data rows
  foreach my $row (sort { $a->[1] cmp $b->[1] }(@data_rows)) { 
    print "<tr>";
    my $col_number = 1;
    my $cnt = 0;
    foreach my $col (@$row) { # print the data
      $cnt++;
      # add link to annotation page
      if ( $col_number == 1 && !$args{coalesce_probesets} ) { 
        print "<td class='anno_cell'><a href='$anno_base_url&$id_key=$col'>$col</a></td>";
        $col_number++;
        next;
      }
      if ( ref($col) eq 'ARRAY' ) { # dereference the colored table cells
        print join "", @$col;
        next;
      } 
      if ( $cnt == @$row ) {
        $col = $sbeams->truncateStringWithMouseover( string => $col, len => 40 )
      }
      print "<td class='anno_cell'>$col</td>";
    }
    print "</tr>\n";
  }
  print "</table>\n";
  print_table_legend( $coalesced );
}

sub get_documentation_link {
  return '<A HREF=http://scgap.systemsbiology.net/doc/gene_expression_search.pdf>Search Help</A>';
}

sub get_back_link {
  
  my $full_url = $q->self_url();
  
  $q->delete( 'output_mode' );
  my $back_url = $q->self_url();

  $q->delete( 'click_all_files' );
  $q->delete( 'probe_set_id' );
  $q->delete( 'gene_name' );
  $q->delete( 'accession_number' );
  $q->delete( 'submit_query' );
  $q->delete( 'action' );

  my $newsearch_url = $q->self_url();

  return <<"  END" if $sbeams->output_mode() =~ /print/;
  <STYLE>
  .hideme { display: none; }
  </STYLE>

  <SCRIPT>
  function printWindow( ) {
    var printbutton = document.getElementById( 'print_button' );
    printbutton.className='hideme';
    window.print();
    var backbutton = document.getElementById( 'back_button' );
    backbutton.className='';
  }
  </SCRIPT>

  <DIV ID=print_button name=print_button CLASS=''><A HREF='javascript:printWindow()'>Print Window</A></DIV>
  <A HREF=$back_url ID=back_button class=hideme> Back </A>
  END

  return "<A HREF=$newsearch_url>New Search</A>&nbsp;&nbsp;<A HREF=$full_url;output_mode=print>Printable View</A>";
}

###############################################################################
	# sort_data_rows
	#
	# Sort the data on the mean intensity value for each gene
###############################################################################
	sub sort_data_rows {
    my @in = @_;
#    for my $row( @in ) { $log->debug( "Symbol is $row->[1]" ); }
    my @out = sort { $a->[3] <=> $b->[3] } @_; #the mean value is in the 3 column
#   for my $row( @out ) { $log->debug( "Symbol is $row->[1]" ); }
    return @out;
	}
###############################################################################
	# compute_mean
	#
	# Take a list of numbers and return the mean and Max intensity
###############################################################################
	sub compute_mean {

		my $max_numb = 0;
		my $total    = '';
		foreach my $val (@_) {
			if ( $val > $max_numb ) {
				$max_numb = $val;
			}

			$total += $val;
		}

		my $mean = sprintf( "%.2f", $total / scalar(@_) );
		$max_numb = sprintf( "%.2f", $max_numb );
		return ( $mean, $max_numb );

	}
###############################################################################
	# make_table_name
	#
	# Take the column name and turn it side ways
###############################################################################
	sub make_table_name {
    my $name = shift;
    my $agent = $q->user_agent();

    my $table = "<table border=0>";

    # Will print sideways for IE
    if ( $agent =~ /MSIE.*6/ ) {
      $table .= "<tr valign='bottom'><td class='med_vert_cell'>$name</td></tr>";
      $table .= "</table>";
      return $table;
    }

		my @letters = split //, $name;

		my $count = 0;
		foreach my $letter (@letters) {
			$letter =~ s/_/|/;
			$letter =~ s/\s/***/g;

    $table .= "<tr valign='bottom'><td class='med_cell'>$letter</td></tr>";
    if ( $count > 30 ) {
      print "<td class='med_cell'>...</td>";
      last;
    }

		}
		$table .= "</table>";
      return $table;
	}

###############################################################################
# make_hash_of_row
#
# take an aref and the column names and make a hash key = column name, val= value from database
###############################################################################
sub make_hash_of_row {
  my %args = @_;

  my $aref = $args{aref};
  my @column_names = @{ $args{column_names} };
  my %hash;
  for ( my $i = 0 ; $i <= $#column_names ; $i++ ) {
    my $val = $$aref[$i];

    # Parse the Sample tag from the root_file name example 20040707_05_PAM2B-80
    if ( $column_names[$i] eq 'file_root' ) {
      if ( $val =~ /^\d+_\d+_(.*)/ ) { 
			  $val = $1;
		  }
    }
    my $key = $column_names[$i];
    $hash{$key} = $val;
  }
  return %hash;
}

###############################################################################
# check_for_file_existance
#
# Pull the file base path from the database then do a file exists on the full file path
###############################################################################
	sub check_for_file {
		my %args = @_;

		my $array_id  = $args{affy_array_id};
		my $root_name = $args{file_root_name};
		my $file_ext  =
		  $args{file_extension}; #Fix me same query is ran to many times, store the data localy

		my $sql = qq~  SELECT fp.file_path 
			FROM $TBMA_AFFY_ARRAY afa, $TBMA_FILE_PATH fp 
			WHERE afa.file_path_id = fp.file_path_id
			AND afa.affy_array_id = $array_id
		   ~;
		my ($path) = $sbeams->selectOneColumn($sql);

		my $file_path = "$path/$root_name.$file_ext";

		if ( -e $file_path ) {
			return 1;
		}
		else {

			#print "MISSING FILE '$file_path'<br/>";
			return 0;
		}
	}

###############################################################################
	# show_annotation
	#
	# Show an annotation page if needed
###############################################################################
	sub show_annotation {
		my $affy_anno = new SBEAMS::Microarray::Affy_Annotation;
		$affy_anno->setSBEAMS($sbeams);

		my %args       = @_;
		my %parameters = %{ $args{ref_parameters} };

		#### Define some variables for a query and resultset
		my %resultset     = ();
		my $resultset_ref = \%resultset;
		my ($sql);

		my %rs_params = $sbeams->parseResultSetParams( q => $q );
		my $base_url  = "$CGI_BASE_DIR/Microarray/$PROG_NAME";
		my $affy_url  = "https://www.affymetrix.com/LinkServlet?probeset=";
		my $source_url = "http://genome-www5.stanford.edu/cgi-bin/source/sourceResult?option=Number&choice=Gene&criteria="; #Query with GB Acc number
		
		
		
		my %url_cols      = ();
		my %hidden_cols   = ();
		my $limit_clause  = '';
		my @column_titles = ();
		my %max_widths    = ();

##########################################################################
###

		#### Build PROBE SET ID constraint
		my $probe_set_id_clause = $sbeams->parseConstraint2SQL(
			constraint_column => "anno.probe_set_id",
			constraint_type   => "plain_text",
			constraint_name   => "Probe Set IS",
			constraint_value  => $parameters{probe_set_id}
		);

		#### Build Annotation Set ID constriant
		my $annotation_set_id_clause = $sbeams->parseConstraint2SQL(
			constraint_column => "anno.affy_annotation_set_id",
			constraint_type   => "int",
			constraint_name   => "Annotation Set ID",
			constraint_value  => $parameters{annotation_set_id}
		);

		my %links_h = $affy_anno->get_dbxref_accessor_urls(); 	#return results as a hash example  dbxref_id 16 => LocusLink__http://www.ncbi.nlm.nih.gov/LocusLink/

		$sql = $affy_anno->get_annotation_sql();    			#returns just the sql text

	  my $limit_clause = $sbeams->buildLimitClause( row_limit => 1 );

    $sql .= <<"    END";
    $annotation_set_id_clause
    $probe_set_id_clause
    $limit_clause->{trailing_limit_clause};
    END

    $sql =~ s/SELECT/SELECT $limit_clause->{top_clause} affy_annotation_id,/; 
#		$sbeams->display_sql(sql=>$sql);

		my @anno_data = $sbeams->selectHashArray($sql);

		print "<table border=0>";

		my $html = '';

		foreach my $record_href (@anno_data) {
			my %record_h = %{$record_href};

			my $annotation_id      = $record_h{affy_annotation_id};
			
			#Grab all the external Links
			my %external_db_acc_numbs =
			  $affy_anno->get_db_acc_numbers($annotation_id);

			#Grab the protein familiy info then format the data into a small table
			my @protein_info = $affy_anno->get_protein_family_info($annotation_id);
			
			my $protein_family_info = format_protein_info(protein_info =>\@protein_info,
														accessor_urls =>\%links_h,
														);
			#Grab the proetin domain info
			 @protein_info = $affy_anno->get_protein_domain_info($annotation_id);
			my $protein_domain_info = format_protein_info(protein_info =>\@protein_info,
														accessor_urls =>\%links_h,
														);
			#Grab the Interpro info
			my @interpro_info = $affy_anno->get_interpro_info($annotation_id);
			my $interpro_info = format_protein_info(protein_info =>\@interpro_info,
														accessor_urls =>\%links_h,
														);
			#Grab the number of Transmembrane domains
			my @tm_domain_info = $affy_anno->get_transmembrane_info($annotation_id);
			
			my $tm_domain_html = format_trans_membrane_info(\@tm_domain_info);
			
			#Grab the alignment info get_alignment_info
			my @alignment_info = $affy_anno->get_alignment_info($annotation_id);
			my $alignment_table = format_alignment_info(alingment_info => \@alignment_info);
			
			#Grab the GO info and format it 
			my @go_info = $affy_anno->get_go_info($annotation_id);
			my $go_table = format_go_info(go_info => \@go_info,
											accessor_urls =>\%links_h,
										  );
			
			my $probe_set_id   = $record_h{probe_set_id};
			my $pathways_html  = nice_format( $record_h{pathway} );
			my $external_links = make_links(
							accessor_urls => \%links_h,
							db_acc_numbs  => \%external_db_acc_numbs,
							);
							
			#format the Annotation notes info
			my $annotation_html = format_annotation_info(record_href => \%record_h);
						
			
	#print "AFFY anno id '$annotation_id'<br>";
			$html = qq~ 
				<tr>
			       <td class='blue_bg' colspan=2>Affy Info</td>
			    </tr>
				<tr>
			      <td class='grey_bg'>Affy Chip Name</td>
			      <td>$record_h{Affy_Chip}</td>
			    </tr>
			    <tr>
			      <td class='grey_bg'>Probe Set ID</td>
			      <td><a href='$affy_url$probe_set_id'>$probe_set_id</a></td>
			    </tr>
			    
			    
			    <tr>
			       <td class='blue_bg' colspan=2>Genome Info</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Annotaion Date</td>
			       <td>$record_h{Annotation_Date}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Genome Build</td>
			       <td>$record_h{Genome_Version}</td>
			    </tr>
			    
			    
			    <tr>
			       <td class='blue_bg' colspan=2>Gene </td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Gene Symbol</td>
			       <td>$record_h{gene_symbol}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Gene Title</td>
			       <td>$record_h{gene_title}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Chromosomal Location</td>
			       <td>$record_h{chromosomal_location}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Chromosomal Alignments</td>
			       <td>$alignment_table</td>
			    </tr>
			    
			    
			    <tr>
			       <td class='blue_bg' colspan=2>External Links</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>SOURCE</td>
			       <td><a href="$source_url$record_h{representative_public_id}">$record_h{representative_public_id}</a></td>
			    </tr>
			   <tr>
			       <td class='grey_bg'>External Links</td>
			       <td>$external_links</td>
			    </tr>
			    
			 
				<tr>
			       <td class='blue_bg' colspan=2>Protein Info</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Protein Family Info</td>
			       <td>$protein_family_info</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Protein Domain Info</td>
			       <td>$protein_domain_info</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Interpro</td>
			       <td>$interpro_info</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Pathways</td>
			       <td>$pathways_html</td>
			    </tr>
			  	<tr>
			       <td class='grey_bg'>Number of Transmembrane Domains</td>
			       <td>$tm_domain_html</td>
			    </tr>
			  	
			  	<tr>
			       <td class='blue_bg' colspan=2>Go Information</td>
			    </tr>
			  	<tr>
			       <td class='grey_bg'>Go Info</td>
			       <td>$go_table</td>
			    </tr>
			  	
			  	
			  	<tr>
			       <td class='blue_bg' colspan=2>Probe Design Info</td>
			    </tr>
			  	<tr>
			       <td class='grey_bg'>Sequence Type</td>
			       <td>$record_h{sequence_type}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Sequence Source</td>
			       <td>$record_h{sequence_source}</td>
			    </tr>
			  	<tr>
			       <td class='grey_bg'>Transcript ID</td>
			       <td>$record_h{transcript_id}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Target Description Feature</td>
			       <td>$record_h{target_description_feature}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Target Description</td>
			       <td>$record_h{target_description}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Target Description Note</td>
			       <td>$record_h{target_description_note}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>Archival Unigene Cluster</td>
			       <td>$record_h{archival_unigene_cluster}</td>
			    </tr>
			    <tr>
			       <td class='grey_bg'>representative_public_id</td>
			       <td>$record_h{representative_public_id}</td>
			    </tr>
			 
			 	
			 	<tr>
			       <td class='blue_bg' colspan=2>Affy Annotation Information</td>
			    </tr>
			 	$annotation_html
			 
			  ~;
			print $html;
			print "</table>";
		}
	}

###############################################################################
# make_links
#
#combine the links accessor url with the actual db accession numbers and return a small table
###############################################################################
	sub make_links {
		my %args = @_;

		my %accessor_urls         = %{ $args{accessor_urls} };
		my %external_db_acc_numbs = %{ $args{db_acc_numbs} };
		my $html                  = '';
		$html = "<table border=0>";

		foreach my $db_id ( sort keys %external_db_acc_numbs ) {
			my $dbxref_id = $external_db_acc_numbs{$db_id};
			my $url_info  = $accessor_urls{$dbxref_id};
			my ( $dbxref_tag, $accessor_url ) = split /__/, $url_info;

			$html .=
"<tr><td><a href='$accessor_url$db_id' target='_blank'>$dbxref_tag $db_id</a></td></tr>";
		}
		$html .= "</table>";
		return $html;

	}

###############################################################################
# nice_format
#
#if a piece of data from the affy annotaion file still has multipule records break it appart
#and format it in a nice mannor
###############################################################################
	sub nice_format {
		my $record_val = shift;

		my @parts = split /\/\/\//, $record_val;
		my $html  = '';

		$html = "<table border=0>";
		foreach my $part (@parts) {

			$html .= " <tr> <td>$part</td> </tr>";

		}
		$html .= "</table>";
	}

###############################################################################
# format_annotation_info
#
#Format the affy Annotation information into a nice little table
###############################################################################
sub format_annotation_info {
	my %args = @_;
	my $record_href = $args{record_href};
	
	
	my $html = '';
	my @annotation_keys = qw(annotation_description
							 transcript_assignment
							 annotation_transcript_cluster
							 annotation_notes
							);
	foreach my $key (@annotation_keys){
			
			my $anno_info_chunk = $record_href->{$key};
			my $formated_info = nice_format($anno_info_chunk);
			#print "KEY '$key'   FORMATED '$anno_info_chunk<br/>";
			 $html .= qq~<tr>
		       				<td class='grey_bg'>$key</td>
		       				<td>$formated_info</td>
		    			</tr>
		    		 	~;
				
	}
	return $html;
}
		
###############################################################################
# format_trans_membrane_info
#Format the tm predictions as a nice little table
###############################################################################
sub format_trans_membrane_info {
	my $array_of_hrefs = shift;	#data returned from sql query as array of hash refs
	
	my $html = qq~<table border='0'>
				 		<tr>
				 		  <td class='grey_bg'>Protein Accession Number</td>
				 		  <td class='grey_bg'>Number of TM domains</td>
				 		</tr>
				 ~;
				 
	foreach my $href (@{$array_of_hrefs}) {
		my $numb_tm_domains = $href->{number_of_domains};
		my $protein_id = $href->{protein_accession_numb};
			$html .= qq~<tr>
						  <td>$protein_id</td>
						  <td>$numb_tm_domains</td>
						 </tr>
						~;
	}
	
	$html .= "</table>";
	return $html;
}
	
###############################################################################
# format_go_info
#Format the protein info or protein domain into a nice html table
###############################################################################
sub format_go_info {
	my %args = @_;
	
	my %accessor_urls  =  % {$args{accessor_urls} };
	my @go_info_a = @{ $args{go_info} };
	my $html = "<table border=0>";
	my $biol_flag = 0;
	my $molfunc_flag = 0;
	my $compartment_flag = 0;
	
	foreach my $go_href (@go_info_a){
		my $go_type = $$go_href{gene_ontology_name_type};
		my $go_base_url = $accessor_urls{$$go_href{dbxref_id}};
		
		
		
		if ($go_type eq "Gene Ontology Biological Process"){		#Gene Ontology Biological Process
				
			unless ($biol_flag){					#Make header Rows
				$html .= make_go_header("Gene Ontology Biological Process");
				$biol_flag = 1;
			}
		}elsif ($go_type eq "Gene Ontology Cellular Component"){
				unless ($compartment_flag){			#Make header Rows
					$html .= make_go_header("Gene Ontology Cellular Component");
					$compartment_flag = 1;
				}
		}elsif ($go_type eq "Gene Ontology Molecular Function"){
				unless ($molfunc_flag){				#Make header Rows
					$html .= make_go_header("Gene Ontology Molecular Function");
					$molfunc_flag = 1;
				}
		}else{
		}
		
		$html .= make_go_row(go_href 	 =>$go_href,
				 			 go_base_url => $go_base_url
				 		    );
					
		
	}
	$html .= "</table>";
	return $html;
}
###############################################################################
# Make header lines for go talbe
###############################################################################
sub make_go_header {
		my $go_type = shift;
		my $html = "";
		my $html .= qq~
						<tr>
						  <td colspan=3 class='blue_bg'>$go_type</td>
						</tr>
					   <tr>
		   				<td class='grey_bg'>Link</td>
		   				<td class='grey_bg'>Description</td>
		   				<td class='grey_bg'>Evidence</td>
		   			   </tr>
		   			  ~;
		return $html;
}
###############################################################################
# Make a row for a go annotation table
###############################################################################
sub make_go_row{
		my %args = @_;
		my $go_href = $args{go_href};
		my $go_base_url = $args{go_base_url};
		my ($db_name, $url) = split /__/, $go_base_url;
		
		my $html .= qq~ <tr>
						<td><a href="$url$$go_href{db_id}">$$go_href{db_id}</a></td>
						<td>$$go_href{gene_ontology_description}</td>
						<td>$$go_href{gene_ontology_evidence}</td>
					  </tr>
				    ~;
		return $html;
}
###############################################################################
# format_alignment_info
#Format the alignment info into a nice html table
###############################################################################
sub format_alignment_info {
	my %args = @_;
	my @alignment_info = @ {$args{alingment_info} };
	
	my $html = "<table border=0>";
	foreach my $align_href (@alignment_info){
		
		$html .= qq~<tr>
					<td>$$align_href{match_chromosome}</td>
					<td>$$align_href{gene_start} - $$align_href{gene_stop}</td>
					<td>Strand ($$align_href{gene_orientation})</td>
					<td>$$align_href{percent_identity} % identity</td>
				  </tr>
				~;
	}	
	$html .= "</table>";
	return $html;
}
###############################################################################
# format_protein_info
#Format the protein info or protein domain into a nice html table
###############################################################################
sub format_protein_info {
	my %args = @_;
	
	my %accessor_urls  =  % {$args{accessor_urls} };
	my @protein_info_a = @{ $args{protein_info} };
	
	my $html = "<table border=0>";
	foreach my $row_href (@protein_info_a){
			
			my ($external_db_name, $url) = split /__/, $accessor_urls{$$row_href{dbxref_id}};
			my $desc = '';
			if (exists $$row_href{description}){					#desc from protein_families table
				 $desc = $$row_href{description};
			}elsif(exists $$row_href{protein_domain_description}){	#desc from protein_domains table
				$desc = $$row_href{protein_domain_description};
			}
				
			my $db_id = $$row_href{db_id};
			
			$html .= qq ~<tr>
							<td><a href="$url$db_id">$external_db_name $db_id</a></td>
							<td>$desc</td>
						 </tr>
						~;
	}
	$html .= "</table>";
	
	return $html;
	 
}
###############################################################################
	# evalSQL
	#
	# Callback for translating Perl variables into their values,
	# especially the global table variables to table names
###############################################################################
	sub evalSQL {
		my $sql = shift;

		return eval "\"$sql\"";

	}    # end evalSQL

###############################################################################
# show_other_query_page: Make a small button to flip between the big and little query
###############################################################################

	sub show_other_query_page {
		my %args          = @_;
		my $query_to_show = $args{type_to_show};
    if ( $query_to_show eq 'Advanced' ) {
      return '' if $sbeams->isGuestUser();
    }

		print $q->start_form()
		  ;    #Select if user wants to see simple or full interface
		print
		  "Click Button to use the '$query_to_show' Query Interface  &nbsp;";
		print $q->submit(
			-name  => 'display_type',
			-value => "$query_to_show",
		);
		print $q->end_form()

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
# produce_SQL_joins
#
# Search through all the column headers going into a SQL query and pull out the table alias
#if it exists in the additional_tables hash pull out it's value and return all the matches
#Return string of SQL table join statments
###############################################################################
	sub produce_SQL_joins {
		my %args = @_;

		my $column_clause =
		  $args{column_clause}; #example  / afa.file_root AS "file_root",gi.probe_set_id AS "probe_set_id" /
		my %additional_tables = %{ $args{additional_tables} };

		my @columns    = split /,/, $column_clause;
		my $tablejoins = '';

		if ( $column_clause =~ /dbxref\./ ){ 		#hack to remove this table only if the dbxref table is going to be used since it will include the
			delete $additional_tables{db_links}; 		#join of affy_annotation to affy_db_link we don't want to see it twice
		}

		foreach my $column (@columns) {

			#print "COLUMN '$column'<br>";
			if ( $column =~ /(\w.+?)\..+? AS/ ) {    #grab just the table alias

				if ( exists $additional_tables{$1} ) {
					$tablejoins .= $additional_tables{$1};

					#print "FOUND MATCH '$tablejoins'<br>";
					delete $additional_tables{$1
					  }; #need to remove the key from the hash since we don't want to add multiple join statments to the SQL query
				}
				else {

					#print "CANNOT FIND '$1' in ADDITIONAL TABLES<br>";
				}
			}
		}

		return $tablejoins;
	}

###############################################################################
# have_2nd_queires
#
# Look to see if any second query constriants exists
###############################################################################
	sub have_2nd_queires {
		foreach my $key ( keys %main:: ){
		 #look throught the main symbol hash for any globals that end with _2nd_query These should be coming from the build constrinat cluases
			next unless ($key =~ /2nd_query$/ || $key =~ /_2nd_query_aref/);
			#print STDERR "SECOND QUERY NAME '$key'<br>\n";
			local *sym = $main::{$key};
			
			next unless $sym =~ /\w/;		#make sure there is a value
			#print STDERR "VALUE '$sym'<br>\n";
			return 1;				#if a var is found retrun a true val
		}
		return 0;
	}
###############################################################################
# add_constraint_columns
#
# Need to look through the constriants the user has supplied if they where activated.  If so we need to make sure we
#add the column to SQL select statment.
###############################################################################
	sub add_constraint_columns {
		my %args                   = @_;
		my $additional_col_aref    = $args{additional_cols};
		my %avalible_columns       = %{ $args{avalible_columns} };
		my $genome_coor_constriant = $args{genome_coor_constraint};
		my $default_columns        = $args{default_columns};
		my $additional_group_by_clauses_ref = $args{additional_group_by_clauses};
		my $display_parameter	   = $args{display_options};
		
		my $pivot_query_flag = 0;
		if ($display_parameter =~ /PivotConditions/ ){
			$pivot_query_flag = 1;
			
		}
		
		my @default_columns = split /,/, $default_columns; #Need to remove the default columns so they do not show up twice in the output
		  
		foreach my $table_name (@default_columns) {
			#print STDERR "DEFAULT '$table_name'\n";
			delete $avalible_columns{$table_name}
			  if exists $avalible_columns{$table_name};
		}

		KEY:foreach my $key ( keys %main:: )
		{ #look throught the main symbol hash for any globals that end with _clause These should be coming from the build constrinat cluases
			next unless $key =~ /_clause$/;
			local *sym = $main::{$key};
			if ($sym){#example  " AND ( align.match_chromosome LIKE 'chr6') " OR " AND align.gene_start >2000"
			 
				    #print "CLAUSE VALUE '$sym'<br>";
				if ( $sym =~ /AND.+?(\w+\.\w+)/ ){ #grab the table.column info from the SQL constriant
					   
						if ( exists $avalible_columns{$1} ){
					 		
					 	if ($pivot_query_flag){		#if this is a pivot query there are some things do not want to have in the pivot group by columns
							if  ($1 eq "gi.signal"){ #anything in this array will not be added to the select columns nor the group by statement
								
								next KEY;			
							}else{
								
								$$additional_group_by_clauses_ref .= ",$1";	
							}
						}
					 
					 #if everything works out this should be a key in the avalible_columns hash
						 #Attach the value which is anno array holding some table column information
						push @{$additional_col_aref}, $avalible_columns{$1};
						#need to collect column names to add to a group by clause if this query is going to be used for a pivot query
						
					}
				}
			}
		}
		
		if ($genome_coor_constriant)
		{ #if there is a genome coordinate constriant be sure to add the columns to the output
			    #print "GENOME COORD $genome_coor_constriant<br>";
			push @{$additional_col_aref},
			  $avalible_columns{"align.match_chromosome"};
			push @{$additional_col_aref}, $avalible_columns{"align.gene_start"};
			push @{$additional_col_aref}, $avalible_columns{"align.gene_stop"};
			push @{$additional_col_aref}, $avalible_columns{"align.percent_identity"};
			  
		}
				
}
					
 		
###############################################################################
# convert_GO_display_options
#If there was a display parameter given to display some GO annotaion figure out which columns they were 
# and make sql statments to run to return the data
###############################################################################
sub convert_GO_display_options {
 	my %args = @_;

		#### Process the arguments list
	my $display_parameter = $args{'display_param'};
	my $go_description_clause_2nd_query = $args{go_desc_clause};
	my $all_pk = $args{all_pk};
	
	my @go_sql_statments = ();
	#my @second_sql_names = ();		#need to a give names for each sql statement.  Will be come the column name in the merged dataset
	my %all_sql_statments = ();
	my $constraint = '';
	my $sql_fragment = qq~
			 	SELECT  
			  	go.affy_annotation_id,
			  	go.gene_ontology_description AS "HOOK_VAL Description", 
			  	go.gene_ontology_evidence AS "HOOK_VAL Evidence", 
			  	db.db_id AS "HOOK_VAL Link"
	 			FROM $TBMA_GENE_ONTOLOGY go
				JOIN $TBMA_GENE_ONTOLOGY_TYPE gt ON (go.gene_ontology_type_id = gt.gene_ontology_type_id)
				JOIN  $TBMA_AFFY_DB_LINKS  db ON(go.affy_db_links_id = db.affy_db_links_id) 
				WHERE
				go.affy_annotation_id IN ($all_pk)
				$go_description_clause_2nd_query
				~;
	
	
	###Produce sql statments if the user selected certain GO columns to dispaly or if the user only entered  
	###a term to constrian the GO data then build all the queries if no column constriant was given
	
	if ((my @go_columns = ($display_parameter =~ /(GO_[BMC]\w*)/g)) || ($display_parameter eq 'ALL')) {
		
		foreach my $go_type (@go_columns) {
			
			if ($go_type =~ /biological/i || $display_parameter eq 'ALL') {
				
				my $updated_sql = update_sql_fragment(sql_fragment => $sql_fragment,
								    				  hook_val => "GO Biological Process",
								    			      );
					$all_sql_statments{GO_Biological_Process} =  qq~ 
														$updated_sql
														AND gt.gene_ontology_name_type like 'Gene Ontology Biological Process'\n
														~;
				
				
			}elsif ($go_type =~ /cellular/i || $display_parameter eq 'ALL'){
				my $updated_sql = update_sql_fragment(sql_fragment => $sql_fragment,
								    				  hook_val => "GO Cellular Component",
								    			      );
				$all_sql_statments{GO_Cellular_Component} = qq~ 
							 								$updated_sql
							 							AND gt.gene_ontology_name_type like 'Gene Ontology Cellular Component'\n
							 							~;
				
			}elsif ($go_type =~ /molecular/i || $display_parameter eq 'ALL'){
				my $updated_sql = update_sql_fragment(sql_fragment => $sql_fragment,
								    				  hook_val => "GO Molecular Function",
								    			      );
				
				
				$all_sql_statments{GO_Molecular_Function} = qq~ 
							 									$updated_sql
																AND gt.gene_ontology_name_type like 'Gene Ontology Molecular Function'\n
							 								~;
				
			}else{
			}
			
		}
		
		
	}	

	return %all_sql_statments;
}
###############################################################################
# update_sql_fragment
#Take a fragement of sql and replace all HOOK_VAL with the value passed in
###############################################################################
sub update_sql_fragment {
 	my %args = @_;
 	my $sql_frag =  $args{sql_fragment};			    
	my $hook_val = $args{hook_val};
	
	$sql_frag =~ s/HOOK_VAL/$hook_val/g;
	return $sql_frag;
}
	
	
###############################################################################
	# convertGenomeCoordinates
	#
	# Convert one or more genome coordinate strings of the form
	# hg16:chr15:123456-12347+ to a constriant for using in the sql query
###############################################################################
	sub convertGenomeCoordinates {
		my %args = @_;

		#### Process the arguments list
		my $genome_coordinates = $args{'genome_coordinates'};
		return unless ($genome_coordinates);

		#### Split the coordinates on semicolon
		my @genome_coordinates = split( /;/, $genome_coordinates );

		#### Define an aray to hold probe_set_ids
		my @probe_set_ids = ();

		#### Define the genome_build to affy_annotation set genome version
		my %build2_annoset_genome = (
			'hg16' => 'July 2003 (NCBI 34)',
			'hg17' => 'May 2004 (NCBI 35)',
			'mm4'  => 'October 2003 (NCBI 32)',
			'mm5'  => 'May 2004 (NCBI 33)',
		);

		#### Loop over each one and try the conversion
		my $sql_constraint = '';
		foreach my $coordinate_str (@genome_coordinates) {
			if ( $coordinate_str =~ /(.+)?:chr(.+)?:(\d+)-(\d+)([\-\+\?])/ ) {

				my $genome_build_id = $1;
				my $chromosome      = $2;
				my $start_pos       = $3;
				my $end_pos         = $4;
				my $strand          = $5;

				my $anno_set_genome_name = $build2_annoset_genome{$genome_build_id};
				unless ($anno_set_genome_name) {
					print
					  "ERROR: Invalid genome_build_id '$genome_build_id'<BR>\n";
					return (-1);
				}

				$sql_constraint = qq~  
     				AND align.match_chromosome = 'chr$chromosome'
     				AND anno_set.genome_version = '$anno_set_genome_name'
				AND  ( align.gene_start BETWEEN $start_pos AND $end_pos OR
                 			align.gene_stop BETWEEN $start_pos AND $end_pos OR
                 			$start_pos BETWEEN align.gene_start AND align.gene_stop ) 
      			    ~;

			}else {
			
				print
"ERROR: Unable to parse coordinate string '$coordinate_str'<BR>\n";
				return (-1);
			}
		}

		return ($sql_constraint);
	}
