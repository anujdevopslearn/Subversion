#!/usr/local/bin/perl

###############################################################################
# Program     : BrowseSNPHit.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               browse through SNP Blast hits.
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
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::SNP;
use SBEAMS::SNP::Settings;
use SBEAMS::SNP::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SNP;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
$q = new CGI;


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
  my $CATEGORY="SNP Hit Search";
  $TABLE_NAME="SN_BrowseSNPHit" unless ($TABLE_NAME);
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

  #### Build SNP_ACCESSION constraint
  my $snp_accession_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"SI.snp_accession",
    constraint_type=>"plain_text",
    constraint_name=>"SNP Accession",
    constraint_value=>$parameters{snp_accession_constraint} );
  return if ($snp_accession_clause == -1);


  #### Build SNP_SOURCE_ACCESSION constraint
  my $snp_instance_source_accession_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"SI.snp_instance_source_accession",
    constraint_type=>"plain_text",
    constraint_name=>"SNP Instance Source Accession",
    constraint_value=>$parameters{snp_instance_source_accession_constraint} );
  return if ($snp_instance_source_accession_clause == -1);


  #### Build SNP_SOURCE constraint
  my $snp_source_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"SI.snp_source",
    constraint_type=>"int_list",
    constraint_name=>"SNP Source",
    constraint_value=>$parameters{snp_source_constraint} );
  return if ($snp_source_clause == -1);


  #### Build BIOSEQENCE_SET constraint
  my $biosequence_set_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.biosequence_set_id",
    constraint_type=>"int_list",
    constraint_name=>"BioSequence Set",
    constraint_value=>$parameters{biosequence_set_id} );
  return if ($biosequence_set_clause == -1);

  #### Build Validation Status constraint
  my $validation_status_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"SI.validation_status",
    constraint_type=>"text_list",
    constraint_name=>"Validation Status",
    constraint_value=>$parameters{validation_status_constraint} );
  return if ($validation_status_clause == -1);

  #### Build IDENTIFIED PERCENT constraint
  my $identified_percent_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"ABS.identified_percent",
    constraint_type=>"flexible_float",
    constraint_name=>"Identified Percent",
    constraint_value=>$parameters{identified_percent_constraint} );
  return if ($identified_percent_clause == -1);

  #### Build MATCH TO QUERY RATIO constraint
  my $match_to_query_ratio_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"convert(real,ABS.match_length)/ABS.query_length*100",
    constraint_type=>"flexible_float",
    constraint_name=>"Match to Query Ratio",
    constraint_value=>$parameters{match_to_query_ratio_constraint} );
  return if ($match_to_query_ratio_clause == -1);

  #### Build ROWCOUNT constraint
  $parameters{row_limit} = 50000
    unless ($parameters{row_limit} > 0);
  my $limit_clause = "TOP $parameters{row_limit}";


  #### Define the desired columns in the query
  #### [friendly name used in url_cols,SQL,displayed column title]
  my @column_array = (
    ["snp_instance_id","SI.snp_instance_id","SNP Instance ID"],
    ["dbSNP_accession","S.dbSNP_accession","dbSNP Accession"],
    ["celera_accession","S.celera_accession","Celera Accession"],
    ["snp_accession","SI.snp_accession","SNP Accession"],
    ["snp_instance_source_accession","SI.snp_instance_source_accession","SNP Instance Source Accession"],
    ["allele_id","A.allele_id","Allele Id"],
    ["set_tag","BSS.set_tag","BioSequence Set Tag"],
    ["biosequence_name","BS.biosequence_name","BioSequence Name"],
    ["end_fiveprime_position","ABS.end_fiveprime_position","End Fiveprime Position"],
    ["strand","ABS.strand","Strand"],
    ["identified_percent","ABS.identified_percent","Percent"],
    ["match_ratio","convert(numeric(5,2),convert(real,ABS.match_length)/ABS.query_length)*100","Match Ratio"],
    ["validation_status","SI.validation_status","Validation Status"],
  );


  #### Limit the width of the Sequence column if user selected
  if ( $parameters{display_options} =~ /ShowSequence/ ) {
    @column_array = ( @column_array,
      ["snp_sequence","convert(varchar(1000),SI.trimmed_fiveprime_sequence)+'['+SI.allele_string+']'+convert(varchar(1000),SI.trimmed_threeprime_sequence)","SNP Sequence"],
    );
  }

  #### Set flag to display SQL statement if user selected
  if ( $parameters{display_options} =~ /ShowSQL/ ) {
    $show_sql = 1;
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
SELECT SI.snp_instance_id,BSS.biosequence_set_id AS ref_id,
       MAX(ABS.identified_percent) AS 'identified_percent'
  INTO #tmp1
  FROM $TBSN_SNP_INSTANCE SI
  JOIN $TBSN_SNP_SOURCE SS on (SS.snp_source_id = SI.snp_source_id)
  JOIN $TBSN_ALLELE A on (A.snp_instance_id = SI.snp_instance_id)
  JOIN $TBSN_ALLELE_BLAST_STATS ABS on (ABS.query_sequence_id = A.query_sequence_id)
  JOIN $TBSN_BIOSEQUENCE BS on (BS.biosequence_id = ABS.matched_biosequence_id)
  JOIN $TBSN_BIOSEQUENCE_SET BSS ON (BSS.biosequence_set_id = BS.biosequence_set_id)
 WHERE 1=1
$identified_percent_clause
$match_to_query_ratio_clause
$biosequence_set_clause
$snp_accession_clause
$snp_instance_source_accession_clause
$snp_source_clause
 GROUP BY SI.snp_instance_id,BSS.biosequence_set_id

---

SELECT $limit_clause $columns_clause
  FROM $TBSN_SNP_INSTANCE SI
  JOIN $TBSN_SNP S ON (SI.snp_id = S.snp_id)
  JOIN $TBSN_SNP_SOURCE SS on (SS.snp_source_id = SI.snp_source_id)
  JOIN $TBSN_ALLELE A on (A.snp_instance_id = SI.snp_instance_id)
  JOIN $TBSN_ALLELE_BLAST_STATS ABS on (ABS.query_sequence_id = A.query_sequence_id)
  JOIN $TBSN_BIOSEQUENCE BS on (BS.biosequence_id = ABS.matched_biosequence_id)
  JOIN $TBSN_BIOSEQUENCE_SET BSS ON (BSS.biosequence_set_id = BS.biosequence_set_id)
  JOIN #tmp1 tt
    ON ( SI.snp_instance_id = tt.snp_instance_id
   AND BSS.biosequence_set_id = tt.ref_id AND ABS.identified_percent = tt.identified_percent )
 WHERE 1=1
$identified_percent_clause
$match_to_query_ratio_clause
$biosequence_set_clause
$validation_status_clause
ORDER BY SI.snp_instance_id,BSS.set_tag,BS.biosequence_id
  ~;


  #### Certain types of actions should be passed to links
  my $pass_action = "QUERY";
  $pass_action = $apply_action if ($apply_action =~ /QUERY/i);


  #### Define the hypertext links for columns that need them
  %url_cols = ('set_tag' => "$CGI_BASE_DIR/SNP/ManageTable.cgi?TABLE_NAME=biosequence_set&biosequence_set_id=\%$colnameidx{biosequence_set_id}V",
               'accession' => "\%$colnameidx{uri}V\%$colnameidx{accesssion}V",
  );


  #### Define columns that should be hidden in the output table
  %hidden_cols = ('biosequence_set_id' => 1,
                  'biosequence_id' => 1,
                  'uri' => 1,
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
      $sbeams->fetchResultSet(sql_query=>$sql,
        resultset_ref=>$resultset_ref);


      #### Post process the resultset
      postProcessResultset(rs_params_ref=>\%rs_params,
        resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters,
      ) if defined($parameters{biosequence_rank_list_id});

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


###############################################################################
# postProcessResultset
#
# Callback for translating Perl variables into their values,
# especially the global table variables to table names
###############################################################################
sub postProcessResultset {
  my %args = @_;

  my ($i,$element,$key,$value,$line,$result,$sql);

  #### Process the arguments list
  my $resultset_ref = $args{'resultset_ref'};
  my $rs_params_ref = $args{'rs_params_ref'};
  my $query_parameters_ref = $args{'query_parameters_ref'};

  my ($bioseq_rank_list) = $sbeams->selectOneColumn("SELECT rank_list_file from $TBSN_BIOSEQUENCE_RANK_LIST
    where biosequence_rank_list_id = '$query_parameters_ref->{biosequence_rank_list_id}'");

  my %rs_params = %{$rs_params_ref};
  my %parameters = %{$query_parameters_ref};


  #### Read in biosequence rank list file and create hash out of its contents
  open (RANKLIST,"$UPLOAD_DIR/$bioseq_rank_list") ||
    die "Cannot open $UPLOAD_DIR/$bioseq_rank_list";

  my %rankhash;
  my ($set_tag,$seq_name,$row,$snp_instance_id,$prev_snp_instance_id);
  $i=0;
  while (<RANKLIST>) {
    $_ =~ s/[\r\n]//g;
    next if $_ =~ /^set_tag/;
    ($set_tag,$seq_name) = split(/\t/,$_);
    $rankhash{"$set_tag|$seq_name"}=$i;
    $i++;
  }

  my $n_rows = scalar(@{$resultset_ref->{data_ref}});

  my $prevpos=-1;
  my $prev_snp_instance_id = -1;
  my ($part1,$part2,$test_index);
  my $best_index = 999999;
  my $best_index_row_reference;
  my @new_data_array;
  #### Loop over each row in the resultset
  for ($row=0;$row<$n_rows-1; $row++) {
    my $snp_instance_column_index = $resultset_ref->{column_hash_ref}->{snp_instance_id};
    my $set_tag_column_index = $resultset_ref->{column_hash_ref}->{set_tag};
    my $biosequence_name_column_index = $resultset_ref->{column_hash_ref}->{biosequence_name};
    $snp_instance_id = $resultset_ref->{data_ref}->[$row]->[$snp_instance_column_index];
    if (($snp_instance_id != $prev_snp_instance_id) && ($row != 0)) {
      push(@new_data_array,$best_index_row_reference);
      #print "best index = $best_index<br>\n";
      $best_index = 999999;
    }
    $part1 = $resultset_ref->{data_ref}->[$row]->[$set_tag_column_index];
    $part2 = $resultset_ref->{data_ref}->[$row]->[$biosequence_name_column_index];
    $test_index = $rankhash{"$part1|$part2"};
    $test_index = 999998 unless defined($test_index);
    #print "field  = $part1|$part2<br>\n";;
    #print "sii = $snp_instance_id<br>\n";
    #print "test index = $test_index<br>\n";
        if ($test_index < $best_index) {
      $best_index_row_reference = $resultset_ref->{data_ref}->[$row];
      $best_index = $test_index;
    }
    $prev_snp_instance_id = $snp_instance_id;
  }
  push(@new_data_array,$best_index_row_reference);
  #print "final rows = ",scalar(@new_data_array),"<br>\n";
  $resultset_ref->{data_ref} = \@new_data_array;

  #### Print out some debugging information about the returned resultset:
  if (0 == 1) {
    my $HTML = "<br>\n";
    print "<BR><BR>resultset_ref = $resultset_ref$HTML\n";
    while ( ($key,$value) = each %{$resultset_ref} ) {
      printf("%s = %s$HTML\n",$key,$value);
    }
    #print "columnlist = ",
    #  join(" , ",@{$resultset_ref->{column_list_ref}}),"<BR>\n";
    print "nrows = ",scalar(@{$resultset_ref->{data_ref}}),"$HTML\n";
    print "rs_set_name=",$rs_params{set_name},"$HTML\n";
 }

  return 1;



} # end postProcessResult
