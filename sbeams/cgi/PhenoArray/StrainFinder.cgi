#!/usr/local/bin/perl 

###############################################################################
# Program     : StrainFinder
# Author      : Rowan
# This finds strains.
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
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
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PhenoArray;
use SBEAMS::PhenoArray::Settings;
use SBEAMS::PhenoArray::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PhenoArray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use CGI qw( :standard);
$q = new CGI;


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
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
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
    #connect_read_only=>1,allow_anonymous_access=>1
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
    # Some action
  } else {
    $sbeamsMOD->display_page_header();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->display_page_footer();
  }


} # end main



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


  #### Define some variables for a query and resultset
  my %resultset = ();
  my $resultset_ref = \%resultset;
  my (%url_cols,%hidden_cols,%max_widths,$show_sql);


  #### Read in the standard form values
  my $apply_action  = $parameters{'action'} || $parameters{'apply_action'};
  my $TABLE_NAME = $parameters{'QUERY_NAME'};


  #### Set some specific settings for this program
  my $CATEGORY="StrainFinder";
  $TABLE_NAME="PH_StrainFinder" unless ($TABLE_NAME);
  ($PROGRAM_FILE_NAME) =
    $sbeamsMOD->returnTableInfo($TABLE_NAME,"PROGRAM_FILE_NAME");
  my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME";


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
    $n_params_found = 99;
  }


  #### Set some reasonable defaults if no parameters supplied
  unless ($n_params_found) {
    $parameters{input_form_format} = "minimum_detail";
  }


  #### Apply any parameter adjustment logic
  #none


  #### Display the user-interaction input form
  $sbeams->display_input_form(
    TABLE_NAME=>$TABLE_NAME,CATEGORY=>$CATEGORY,apply_action=>$apply_action,
    PROGRAM_FILE_NAME=>$PROGRAM_FILE_NAME,
    parameters_ref=>\%parameters,
    input_types_ref=>\%input_types,
  );


  #### Display the form action buttons
  $sbeams->display_form_buttons(TABLE_NAME=>$TABLE_NAME);


  #### Finish the upper part of the page and go begin the full-width
  #### data portion of the page
  $sbeams->display_page_footer(close_tables=>'YES',
    separator_bar=>'YES',display_footer=>'NO');



  #########################################################################
  #### Process all the constraints

  #### Build CellType constraint
  my $cell_type_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"CT.cell_type_id",
    constraint_type=>"int_list",
    constraint_name=>"Cell Type List",
    constraint_value=>$parameters{cell_type} );
  return if ($cell_type_clause == -1);


  #### Build StrainBackground constraint
  my $strain_bg_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"SB.strain_background_id",
    constraint_type=>"int_list",
    constraint_name=>"Strain Background List",
    constraint_value=>$parameters{strain_background} );
  return if ($strain_bg_clause == -1);

  ### Build CITATION constraint 
  my $citation_clause =  $sbeams->parseConstraint2SQL(
    constraint_column=>"C.citation_id",
    constraint_type=>"int_list",
    constraint_name=>"Citation List",
    constraint_value=>$parameters{citation_id} );
  return if ( $citation_clause == -1 );

  ### Build ALLELE NAME constraint
  my $allele_name_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BSA.biosequence_name",
    constraint_type=>"plain_text",
    constraint_name=>"Allele Name",
    constraint_value=>$parameters{allele_name} );
  return if ($allele_name_clause == -1);


  ### Build ALLELE DESC constraint
  my $allele_desc_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BSA.biosequence_desc",
    constraint_type=>"plain_text",
    constraint_name=>"Allele Description",
    constraint_value=>$parameters{allele_desc} );
  return if ($allele_desc_clause == -1);

### Build LOCUS NAME constraint
  my $locus_name_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BSL.biosequence_name",
    constraint_type=>"plain_text",
    constraint_name=>"Locus Name",
    constraint_value=>$parameters{locus_name} );
  return if ($locus_name_clause == -1);

### Build LOCUS DESC constraint
  my $locus_desc_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BSL.biosequence_desc",
    constraint_type=>"plain_text",
    constraint_name=>"Locus Description",
    constraint_value=>$parameters{locus_desc} );
  return if ($locus_desc_clause == -1);

  #### Build ROWCOUNT constraint
  #$parameters{row_limit} = 1000
  #  unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=1000000);
  #my $limit_clause = "TOP $parameters{row_limit}";


  #### Define the desired columns in the query
  #### [friendly name used in url_cols,SQL,displayed column title]
  my @column_array = (
    ["strain_name","S.strain_name","Strain Name"],
    ["cell_type","CT.cell_type_description","Cell Type"],
    ["strain_background","SB.strain_background_name","Strain Background"],
    ["citation_id","C.citation_id","citation_id"],
    ["allele_name","BSA.biosequence_name","Allele Name"],
    ["allele_desc","BSA.biosequence_desc","Allele Desc."],
    ["locus_name","BSL.biosequence_name","Locus Name"],
    ["locus_desc","BSL.biosequence_desc","Locus Desc."],
    ["strain_id","S.strain_id","strain_id"],
                      );


  #### Build the GROUP BY clause
  my $group_by_clause = "";
  foreach $element (@column_array) {
    if ($element->[0] ne 'n_scans' && $element->[0] ne 'TIC_plot') {
      $group_by_clause .= "," if ($group_by_clause);
      $group_by_clause .= $element->[1];
    }
  }


  #### Build the columns part of the SQL statement
  my %colnameidx = ();
  my @column_titles = ();
  my $columns_clause = $sbeams->build_SQL_columns_list(
    column_array_ref=>\@column_array,
    colnameidx_ref=>\%colnameidx,
    column_titles_ref=>\@column_titles
  );

  my $TBPH_ALLELE;
  #### Define the SQL statement
  $sql = qq~
  SELECT $columns_clause
      FROM PhenoArray.dbo.allele A
      LEFT JOIN $TBPH_STRAIN S ON ( A.strain_id = S.strain_id )
      LEFT JOIN $TBPH_BIOSEQUENCE BSA ON ( A.allele_biosequence_id = BSA.biosequence_id )
      LEFT JOIN $TBPH_BIOSEQUENCE BSL ON ( A.locus_biosequence_id = BSL.biosequence_id )
      LEFT JOIN $TBPH_CITATION C ON ( S.reference_citation_id = C.citation_id )
      LEFT JOIN $TBPH_CELL_TYPE CT ON ( S.cell_type_id = CT.cell_type_id )
      LEFT JOIN $TBPH_STRAIN_BACKGROUND SB ON ( S.strain_background_id = SB.strain_background_id )
  WHERE 
  S.record_status like '%'
      $cell_type_clause
      $strain_bg_clause
      $citation_clause
      $allele_name_clause
      $allele_desc_clause
      $locus_desc_clause
      $locus_name_clause
      ~;

  print "<PRE>$sql</PRE><BR>\n";
  

  #### Certain types of actions should be passed to links
  my $pass_action = "QUERY";
  $pass_action = $apply_action if ($apply_action =~ /QUERY/i); 

  #### Define the hypertext links for columns that need them
  %url_cols = (
               'Strain Name' => "$CGI_BASE_DIR/PhenoArray/StrainFinder.cgi?strain_id=\%$colnameidx{strain_id}V",               );

  #### Define columns that should be hidden in the output table
  %hidden_cols = (strain_id => 1 );


  if ( $q->param("strain_id") ) {
      print "<h2>StrainId Found</h2><br>";
      my $strain_id = $q->param("strain_id");
      print "<h3>$strain_id</h3><br>";

#TODO: something cool

      #my @genotype_array = $sbeams->selectHashArray("$sql AND S.strain_id = $strain_id");

      #foreach my $strain (  @genotype_array ) {
       #   foreach my $allele ( %{$genotype_array[0]} ) {
          
        #      print "${genotype_array[0]}{$allele}";
         # }

      #}


  }


  #########################################################################
  #### If QUERY or VIEWRESULTSET was selected, display the data
  if ($apply_action =~ /QUERY/i || $apply_action eq "VIEWRESULTSET") {

    #### Show the SQL that will be or was executed
    $sbeams->display_sql(sql=>$sql) if ($show_sql);

    #### If the action contained QUERY, then fetch the results from
    #### the database
    if ($apply_action =~ /QUERY/i) {

      #### Fetch the results from the database server
      $sbeams->fetchResultSet(sql_query=>$sql,
        resultset_ref=>$resultset_ref);

      #### Store the resultset and parameters to disk resultset cache
      $rs_params{set_name} = "SETME";
      $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
        resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters);
    }

    #### Display the resultset
    $sbeams->displayResultSet(rs_params_ref=>\%rs_params,
        url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols,
        max_widths=>\%max_widths,resultset_ref=>$resultset_ref,
        column_titles_ref=>\@column_titles,
        base_url=>$base_url,query_parameters_ref=>\%parameters,
    );


    #### Display the resultset controls
    $sbeams->displayResultSetControls(rs_params_ref=>\%rs_params,
        resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters,
        base_url=>$base_url);


    

  #### If QUERY was not selected, then tell the user to enter some parameters
  } else {
    if ($sbeams->invocation_mode() eq 'http') {
      print "<H4>Select parameters above and press QUERY</H4>\n";
    } else {
      print "You need to supply some parameters to contrain the query\n";
    }
  }

  
} # end handle_request



###############################################################################
# evalSQL
#
# Callback for translating Perl variables into their values,
# especially the global table variables to table names
###############################################################################
sub evalSQL {
  my $sql = shift;

  return eval "\"$sql\"";

} # end evalSQL






