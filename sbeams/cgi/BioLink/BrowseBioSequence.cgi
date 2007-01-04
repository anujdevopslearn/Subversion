#!/usr/local/bin/perl

###############################################################################
# Program     : BrowseBioSequence.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               browse through BioSequences.
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

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS $DBType );

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::BioLink;
use SBEAMS::BioLink::Settings;
use SBEAMS::BioLink::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::BioLink;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


#use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
#$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
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
  if ($parameters{action} eq "UPDATE") {
    updatePreferredReference();
  } else {
    $sbeamsMOD->display_page_header(
      navigation_bar=>$parameters{navigation_bar});
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

  my $search_hit_id  = $q->param('search_hit_id');
  my $label_peptide  = $q->param('label_peptide') || '';


  #### Set some specific settings for this program
  my $CATEGORY="BioSequence Search";
  $TABLE_NAME="BL_BrowseBioSequence" unless ($TABLE_NAME);
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
  }


  #### Apply any parameter adjustment logic


  #### Display the user-interaction input form
  $sbeams->display_input_form(
    TABLE_NAME=>$TABLE_NAME,CATEGORY=>$CATEGORY,apply_action=>$apply_action,
    PROGRAM_FILE_NAME=>$PROGRAM_FILE_NAME,
    parameters_ref=>\%parameters,
    input_types_ref=>\%input_types,
    mask_user_context => 0,
  );


  #### Display the form action buttons
  $sbeams->display_form_buttons(TABLE_NAME=>$TABLE_NAME);


  #### Finish the upper part of the page and go begin the full-width
  #### data portion of the page
  $sbeams->display_page_footer(close_tables=>'YES',
    separator_bar=>'YES',display_footer=>'NO');



  #########################################################################
  #### Process all the constraints

  #### Build BIOSEQENCE_SET constraint
  my $biosequence_set_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.biosequence_set_id",
    constraint_type=>"int_list",
    constraint_name=>"BioSequence Set",
    constraint_value=>$parameters{biosequence_set_id} );
  return if ($biosequence_set_clause eq '-1');


  #### Build BIOSEQUENCE_NAME constraint
  my $biosequence_name_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.biosequence_name",
    constraint_type=>"plain_text",
    constraint_name=>"BioSequence Name",
    constraint_value=>$parameters{biosequence_name_constraint} );
  return if ($biosequence_name_clause eq '-1');


  #### Build BIOSEQUENCE_NAME constraint
  my $biosequence_gene_name_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.biosequence_gene_name",
    constraint_type=>"plain_text",
    constraint_name=>"BioSequence Gene Name",
    constraint_value=>$parameters{biosequence_gene_name_constraint} );
  return if ($biosequence_gene_name_clause eq '-1');


  #### Build BIOSEQUENCE_SEQ constraint
  my $biosequence_seq_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.biosequence_seq",
    constraint_type=>"plain_text",
    constraint_name=>"BioSequence Sequence",
    constraint_value=>$parameters{biosequence_seq_constraint} );
  return if ($biosequence_seq_clause eq '-1');
  $biosequence_seq_clause =~ s/\*/\%/g;


  #### Build BIOSEQUENCE_DESC constraint
  my $biosequence_desc_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.biosequence_desc",
    constraint_type=>"plain_text",
    constraint_name=>"BioSequence Description",
    constraint_value=>$parameters{biosequence_desc_constraint} );
  return if ($biosequence_desc_clause eq '-1');


  #### Build MOLECULAR FUNCTION constraint
  my $molecular_function_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"MFA.annotation",
    constraint_type=>"plain_text",
    constraint_name=>"Molecular Function",
    constraint_value=>$parameters{molecular_function_constraint} );
  return if ($molecular_function_clause eq '-1');


  #### Build BIOLOGICAL PROCESS constraint
  my $biological_process_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BPA.annotation",
    constraint_type=>"plain_text",
    constraint_name=>"Biological Process",
    constraint_value=>$parameters{biological_process_constraint} );
  return if ($biological_process_clause eq '-1');


  #### Build CELLULAR COMPONENT constraint
  my $cellular_component_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"CCA.annotation",
    constraint_type=>"plain_text",
    constraint_name=>"Cellular Component",
    constraint_value=>$parameters{cellular_component_constraint} );
  return if ($cellular_component_clause eq '-1');


  #### Build INTERPRO PROTEIN DOMAIN constraint
  my $protein_domain_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"IPDA.annotation",
    constraint_type=>"plain_text",
    constraint_name=>"InterPro Protein Domain",
    constraint_value=>$parameters{protein_domain_constraint} );
  return if ($protein_domain_clause eq '-1');


  #### Build FAVORED CODON FREQUENCY constraint
  my $fav_codon_frequency_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BPS.fav_codon_frequency",
    constraint_type=>"flexible_float",
    constraint_name=>"Favored Codon Frequency",
    constraint_value=>$parameters{fav_codon_frequency_constraint} );
  return if ($fav_codon_frequency_clause eq '-1');


  #### Build NUMBER OF TRANSMEMBRANE REGIONS constraint
  my $n_transmembrane_regions_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BPS.n_transmembrane_regions",
    constraint_type=>"flexible_int",
    constraint_name=>"Number of Transmembrane regions",
    constraint_value=>$parameters{n_transmembrane_regions_constraint} );
  return if ($n_transmembrane_regions_clause eq '-1');


  #### Build SORT ORDER
  my $order_by_clause = "";
  if ($parameters{sort_order}) {
    if ($parameters{sort_order} =~ /SELECT|TRUNCATE|DROP|DELETE|FROM|GRANT/i) {
      print "<H4>Cannot parse Sort Order!  Check syntax.</H4>\n\n";
      return;
    } else {
      $order_by_clause = " ORDER BY $parameters{sort_order}";
    }
  }


  #### Build ROWCOUNT constraint
  $parameters{row_limit} = 5000
    unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=1000000);

  my $limit = $sbeams->buildLimitClause( row_limit => $parameters{row_limit} );

  #### Define some variables needed to build the query
  my $group_by_clause = "";
  my $final_group_by_clause = "";
  my @column_array;
  my $peptide_column = "";
  my $count_column = "";


  #### If the user opted to see the GO columns, add them in
  my @additional_columns = ();
  if ( $parameters{display_options} =~ /ShowGOColumns/ ||
       $molecular_function_clause.$biological_process_clause.
       $cellular_component_clause.$protein_domain_clause ) {
    @additional_columns = (
      ["molecular_function","MFA.annotation","Molecular Function"],
      ["molecular_function_GO","MFA.external_accession","molecular_function_GO"],
      ["biological_process","BPA.annotation","Biological Process"],
      ["biological_process_GO","BPA.external_accession","biological_process_GO"],
      ["cellular_component","CCA.annotation","Cellular Component"],
      ["cellular_component_GO","CCA.external_accession","cellular_component_GO"],
      ["interpro_protein_domain","IPDA.annotation","InterPro Protein Domain"],
      ["interpro_protein_domain_GO","IPDA.external_accession","interpro_protein_domain_GO"],
    );
  }

  #### If the user opted to see GO columns or provided some GO constraints,
  #### then join in the GO tables
  my $GO_join = "";
  if ( $parameters{display_options} =~ /ShowGOColumns/ ||
       $molecular_function_clause.$biological_process_clause.
       $cellular_component_clause.$protein_domain_clause ) {
    $GO_join = qq~
        LEFT JOIN $TBBL_ANNOTATED_GENE AG
             ON ( BS.biosequence_accession = AG.gene_accession )
        LEFT JOIN $TBBL_GENE_ANNOTATION MFA
             ON ( AG.annotated_gene_id = MFA.annotated_gene_id
                   AND MFA.gene_annotation_type_id = 1 AND MFA.idx = 0 )
        LEFT JOIN $TBBL_GENE_ANNOTATION BPA
             ON ( AG.annotated_gene_id = BPA.annotated_gene_id
                   AND BPA.gene_annotation_type_id = 2 AND BPA.idx = 0 )
        LEFT JOIN $TBBL_GENE_ANNOTATION CCA
             ON ( AG.annotated_gene_id = CCA.annotated_gene_id
                   AND CCA.gene_annotation_type_id = 3 AND CCA.idx = 0 )
        LEFT JOIN $TBBL_GENE_ANNOTATION IPDA
             ON ( AG.annotated_gene_id = IPDA.annotated_gene_id
                   AND IPDA.gene_annotation_type_id = 4 AND IPDA.idx = 0 )
    ~;
  }


  #### Add in some extra columns if the user wants to see them
  if ( $parameters{display_options} =~ /ShowExtraProteinProps/ ) {
    @additional_columns = (
      ["fav_codon_frequency","STR(BPS.fav_codon_frequency,10,3)","Favored Codon Frequency"],
      ["n_transmembrane_regions","BPS.n_transmembrane_regions","Number of Transmembrane Regions"],
      @additional_columns,
    );
  }


  #### Define the desired columns in the query
  #### [friendly name used in url_cols,SQL,displayed column title]
  my @column_array = (
    ["biosequence_id","BS.biosequence_id","biosequence_id"],
    ["biosequence_set_id","BS.biosequence_set_id","biosequence_set_id"],
    ["set_tag","BSS.set_tag","set_tag"],
    ["biosequence_name","BS.biosequence_name","biosequence_name"],
    ["biosequence_gene_name","BS.biosequence_gene_name","gene_name"],
#    ["accessor","DBX.accessor","accessor"],
    ["biosequence_accession","BS.biosequence_accession","accession"],
    @additional_columns,
    ["biosequence_desc","BS.biosequence_desc","description"],
    ["biosequence_seq","BS.biosequence_seq","sequence"],
  );


  #### Adjust the columns definition based on user-selected options
  if ( $parameters{display_options} =~ /MaxSeqWidth/ ) {
    $max_widths{'biosequence_seq'} = 100;
  }
  if ( $parameters{display_options} =~ /ShowSQL/ ) {
    $show_sql = 1;
  }
  if ( $parameters{display_options} =~ /ShowSetAndName/ ) {
    @column_array=@column_array[2..3];
  }


  #### Build the columns part of the SQL statement
  my %colnameidx = ();
  my @column_titles = ();
  my $columns_clause = $sbeams->build_SQL_columns_list(
    column_array_ref=>\@column_array,
    colnameidx_ref=>\%colnameidx,
    column_titles_ref=>\@column_titles
  );

  #### Define the SQL statement
  $sql = qq~
      SELECT $limit->{top_clause} $columns_clause
        FROM $TBBL_BIOSEQUENCE BS
        LEFT JOIN $TBBL_BIOSEQUENCE_SET BSS
             ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
--        LEFT JOIN $TB_DBXREF DBX ON ( BS.dbxref_id = DBX.dbxref_id )
        $GO_join
       WHERE 1 = 1
      $biosequence_set_clause
      $biosequence_name_clause
      $biosequence_gene_name_clause
      $biosequence_seq_clause
      $biosequence_desc_clause
      $molecular_function_clause
      $biological_process_clause
      $cellular_component_clause
      $n_transmembrane_regions_clause
      $fav_codon_frequency_clause
      $order_by_clause
      $limit->{trailing_limit_clause}
   ~;


  #### Certain types of actions should be passed to links
  my $pass_action = "QUERY";
  $pass_action = $apply_action if ($apply_action =~ /QUERY/i); 

  my $module_prefix = $sbeams->getModulePrefix() . '_';

  #### Define the hypertext links for columns that need them
  %url_cols = ('set_tag' => "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=${module_prefix}biosequence_set&biosequence_set_id=\%$colnameidx{biosequence_set_id}V",
               'accession' => "\%$colnameidx{accessor}V\%$colnameidx{accesssion}V",
               'Molecular Function' => "http://www.ebi.ac.uk/ego/QuickGO?mode=display&entry=\%$colnameidx{molecular_function_GO}V",
               'Molecular Function_ATAG' => 'TARGET="WinExt"',
               'Molecular Function_OPTIONS' => {semicolon_separated_list=>1},
               'Biological Process' => "http://www.ebi.ac.uk/ego/QuickGO?mode=display&entry=\%$colnameidx{biological_process_GO}V",
               'Biological Process_ATAG' => 'TARGET="WinExt"',
               'Biological Process_OPTIONS' => {semicolon_separated_list=>1},
               'Cellular Component' => "http://www.ebi.ac.uk/ego/QuickGO?mode=display&entry=\%$colnameidx{cellular_component_GO}V",
               'Cellular Component_ATAG' => 'TARGET="WinExt"',
               'Cellular Component_OPTIONS' => {semicolon_separated_list=>1},
               'InterPro Protein Domain' => "http://www.ebi.ac.uk/interpro/IEntry?ac=\%$colnameidx{interpro_protein_domain_GO}V",
               'InterPro Protein Domain_ATAG' => 'TARGET="WinExt"',
               'InterPro Protein Domain_OPTIONS' => {semicolon_separated_list=>1},
    );


  #### Define columns that should be hidden in the output table
  %hidden_cols = ('biosequence_set_id' => 1,
                  'biosequence_id' => 1,
                  'accessor' => 1,
                  'molecular_function_GO' => 1,
                  'biological_process_GO' => 1,
                  'cellular_component_GO' => 1,
                  'interpro_protein_domain_GO' => 1,
   );



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


    #### If the output format is selected to be SequenceFormat
    if ( $parameters{display_options} =~ /SequenceFormat/ ) {
      displaySequenceView(
        resultset_ref=>$resultset_ref,
        label_peptide=>$label_peptide,
        url_cols_ref=>\%url_cols
      );


    #### Otherwise display the resultset in conventional style
    } else {
      $sbeams->displayResultSet(rs_params_ref=>\%rs_params,
  	  url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols,
  	  max_widths=>\%max_widths,resultset_ref=>$resultset_ref,
  	  column_titles_ref=>\@column_titles,
          base_url=>$base_url,query_parameters_ref=>\%parameters,
      );

      #### Display the resultset controls
      $sbeams->displayResultSetControls(rs_params_ref=>\%rs_params,
        resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters,
        base_url=>$base_url
      );

    }


    #### If a search_hit_id was supplied, give the user the option of
    #### updating the search_hit with a new protein
    my $nrows = @{$resultset_ref->{data_ref}};
    if ($search_hit_id && $nrows > 1) {
      print qq~
      	<FORM METHOD="post" ACTION="$PROGRAM_FILE_NAME"><BR><BR>
      	There are multiple proteins that contain this peptide.  If you
      	want to set a different protein as the preferred one, select it
      	from the list box below and click [UPDATE]<BR><BR>
      	<SELECT NAME="biosequence_id" SIZE=5>
      ~;

      my $biosequence_id_colindex =
        $resultset_ref->{column_hash_ref}->{biosequence_id};
      my $biosequence_name_colindex =
        $resultset_ref->{column_hash_ref}->{biosequence_name};
      foreach $element (@{$resultset_ref->{data_ref}}) {
        print "<OPTION VALUE=\"",$element->[$biosequence_id_colindex],"\">",
          $element->[$biosequence_name_colindex],"</OPTION>\n";
      }

      print qq~
      	</SELECT><BR><BR>
      	<INPUT TYPE="hidden" NAME="search_hit_id"
      	  VALUE="$search_hit_id">
      	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
      	<INPUT TYPE="submit" NAME="apply_action" VALUE="UPDATE">
      	</FORM><BR><BR>
      ~;

    }


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
# evalSQL: Callback for translating global table variables to names
###############################################################################
sub evalSQL {
  my $sql = shift;

  return eval "\"$sql\"";

} # end evalSQL






###############################################################################
# displaySequenceView: Display the resultset in a FASTA-style format
###############################################################################
sub displaySequenceView {
  my %args = @_;
  my $SUB_NAME = 'displaySequenceView';


  #### Decode the argument list
  my $resultset_ref = $args{'resultset_ref'}
   || die "ERROR[$SUB_NAME]: resultset_ref not passed";
  my $label_peptide = $args{'label_peptide'} || '';


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql,$file);


  #### Get the indices of the columns
  my $biosequence_name_column =
    $resultset_ref->{column_hash_ref}->{biosequence_name};
  my $description_column =
    $resultset_ref->{column_hash_ref}->{biosequence_desc};
  my $sequence_column =
    $resultset_ref->{column_hash_ref}->{biosequence_seq};
  my $accessor_column =
    $resultset_ref->{column_hash_ref}->{accessor};
  my $accession_column =
    $resultset_ref->{column_hash_ref}->{biosequence_accession};


  #### Get some information about the resultset
  my $data_ref = $resultset_ref->{data_ref};
  my $nrows = scalar(@{$data_ref});


  #### Define some variables
  my ($row,$pos);
  my ($biosequence_name,$description,$sequence,$seq_length);
  my ($accessor,$accession);


  #### Display each row in FASTA format
  print "Click on the gene name below to follow the link to the source ".
    "database.<BR><BR>\n\n";
  print "<PRE>\n";
  foreach $row (@{$data_ref}) {

    #### Pull out data for this row into names variables
    $biosequence_name = $row->[$biosequence_name_column];
    $description = $row->[$description_column];
    $accessor = $row->[$accessor_column];
    $accession = $row->[$accession_column];

    #### Find all instances of the possibly-supplied peptide in the sequence
    $sequence = $row->[$sequence_column];
    my %start_positions;
    my %end_positions;
    if ($label_peptide) {
      my $pos = -1;
      while (($pos = index($sequence,$label_peptide,$pos)) > -1) {
        $start_positions{$pos} = 1;
        $end_positions{$pos+length($label_peptide)} = 1;
        $pos++;
      }
    }


    #### Write out the gene name and description
    print "><font color=\"green\">";
    if ($accessor && $accession) {
      print "<A HREF=\"$accessor$accession\">$biosequence_name</A>";
    } else {
      print "$biosequence_name";
    }
    print "</font> <font color=\"purple\">$description</font>\n";


    #### Write out the sequence in a pretty format, possibly labeled
    #### with a highlighted string of bases/residues
    if (0 == 1) {
      print "$sequence\n";
    } else {
      $seq_length = length($sequence);
      $i = 0;
      while ($i < $seq_length) {
  	print "</B></font>" if ($end_positions{$i});
  	print "<font color=\"red\"><B>" if ($start_positions{$i});
  	print substr($sequence,$i,1);
  	$i++;
  	if ($i % 100 == 0) {
  	  print "\n";
  	} elsif ($i % 10 == 0) {
  	  print " ";
  	}

      }

      print "\n\n";

    }

  }

  print "</PRE>\n";

  return;

}




