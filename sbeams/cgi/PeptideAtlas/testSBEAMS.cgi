#!/usr/local/bin/perl

###############################################################################
# Program     : GetAnnotations
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: GetHaloAnnotations 4767 2006-06-13 23:39:49Z dcampbel $
#
# Description : This CGI program that allows users to
#               browse through annotated proteins very simply
#
# SBEAMS is Copyright (C) 2000-2017 by Eric Deutsch
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
use LWP::UserAgent;
use HTTP::Request;

my $ua = LWP::UserAgent->new();


use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $q $current_contact_id $current_username);

use SBEAMS::Connection qw( $q $log );
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::BestPeptideSelector;


$sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
my $best_peptide = new SBEAMS::PeptideAtlas::BestPeptideSelector;
$best_peptide->setAtlas( $atlas );
$best_peptide->setSBEAMS( $sbeams );


{ # Main program

  # Do the SBEAMS authentication and exit if a username is not returned
  $current_username = $sbeams->Authenticate( connect_read_only => 1 ) || die;

  #### Read in the default input parameters
  my %parameters;
  $sbeams->parse_input_parameters( q=>$q, parameters_ref => \%parameters);

  my $base = $q->url( -base => 1 );

  my $id = $atlas->getCurrentAtlasBuildID( parameters_ref => {organism_name => 'human' } );
  my $pabst_build_id = $best_peptide->get_pabst_build( organism_name => 'human' );
  

#https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/Search?search_key=ENSP00000374576&build_type_name=Any&action=GO
  # TODO 
  # Add in some CGI params to /make these more useful!

	my %links = ( "Search" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/Search", 
	                            PARAMS => {search_key=>'ENSP00000371493', build_type_name=>'Any', action=>'GO' }, 
															STRINGS => ['Human ' ] },
                "Main" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/main.cgi",  
								            PARAMS => { '_tab' => 2 },
								            STRINGS => [ qw(Human) ] },

                "buildDetails" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/buildDetails",  
								            PARAMS => { atlas_build_id => $id, '_tab' => 2 },
								            STRINGS => [ ] },


                "GetPeptide" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/GetPeptide",  PARAMS => { '_tab' => 3, 
								                                                                                     atlas_build_id => 377,
																																																		 searchWithinThis => 'Peptide+Name',
																																																		 searchForThis => 'PAp00085360',
																																																		 action => 'query' }, 
																																												STRINGS => [ qw(NKLPFLYSSQGPQAVR PAp00085360 Genome Observed )] },

								"GetPeptides" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/GetPeptides",  
								                   PARAMS => { '_tab' => 4,
                                               atlas_build_id => $id,
                                               peptide_sequence_constraint => 'VLHPLEG%25',
                                               QUERY_NAME=> 'AT_GetPeptides',
                                               action=> 'QUERY' },
																	 STRINGS => [ qw(VLHPLEGAVVIIFK Empirical) ] },

								"GetProteins" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/GetProteins",
                                   PARAMS => { '_tab' => 6,
																	             atlas_build_id => $id,
                                               biosequence_name_constraint => 'ENSP00000222%25',
                                               QUERY_NAME => 'AT_GetProteins',
																	             action => 'QUERY' },
																	STRINGS => [qw( ENSG00000105401 Mappings ) ] },
#								atlas_build_id=213
#								biosequence_name_constraint=ENSP00000222%25
#								QUERY_NAME=AT_GetProteins
#								action=QUERY
								"Summarize" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/Summarize_Peptide",  PARAMS => { searchForThis=>'VSFLSALEEYTK', output_mode=>'html', Submit=>'Submit' }, STRINGS => [ 'Human' ] },
								"GetTransitions" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/GetTransitions", PARAMS => { pabst_build_id=>$pabst_build_id,protein_name_constraint=>'P06731',action=>'QUERY',default_search=>1 }, STRINGS => [ qw(Source) ] },

								"ShowPathways" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/showPathways",
								                    PARAMS => { apply_action => 'pathway_details',
                                                     path_id => 'path:hsa02010',
                                                    path_def => 'ABC transporters - General - Homo sapiens (human)'
																							},
																	  STRINGS => [] },

								"GetProtein" => { URI => "$base/$CGI_BASE_DIR/PeptideAtlas/GetProtein", 
								                  PARAMS => { '_tab' => 5, atlas_build_id => $id, protein_name => 'P08697', action=> 'QUERY' },
																	STRINGS => [ 'SERPINF2' ]  },



 		 );

  $sbeams->display_page_header( minimal_header => "YES",
	                              navagation_bar => "NO" );
  print "Testing pages, please be patient...<BR><BR>";
	print "<A NAME=top></A><TABLE WIDTH=600 BORDER=1>\n";

	print qq~
 	<TR BGCOLOR='#EDEDED'>
    <TD ALIGN=CENTER>Page</TD>
    <TD ALIGN=CENTER>Status</TD>
    <TD ALIGN=CENTER>Size(kb)</TD>
    <TD ALIGN=CENTER>Time(sec)</TD>
 	</TR>
 	~;


	for my $l ( sort ( keys( %links ) ) ) {
#  for my $l ( 'Summarize' )  {  
    my $params = '';
		my $sep = '?';
		for my $p ( keys( %{$links{$l}->{PARAMS}} ) ) {
		  $params .= $sep;
			$params .= $p . '=' . $links{$l}->{PARAMS}->{$p};
			$sep = ';';
		}
    $links{$l}->{URI} .= $params;
    $links{$l}->{PARAM_STRING} = $params;
    
		my $pre = time();
    my $response = $ua->request( HTTP::Request->new( GET => "$links{$l}->{URI}" ) );

		# Start out conservative
		my $style = 'red_bg';
		my $status = 'ERR';

		if ( $response->is_success() ) {
  		$style = 'yel_bg'; 
		  $status = 'OK';
		}

    my $section = $response->content();
		my $post = time();
		my $time = ( $post - $pre ) || 1;
		if ( $section !~ /SBEAMS_PAGE_ERROR/gmi ) { 
			$style = 'grn_bg' 
    }

		my $size = sprintf( "%0.1f", (length( $section )/1000) );

    for my $string ( @{$links{$l}->{STRINGS}} ) {
			if ( !grep /$string/, $section ) {
				$style = 'yel_bg' unless $style eq 'red_bg';
				$status = 'STR';
				$log->warn( "page $l missing $string!" );
        last;
			}
		}

		print qq~
		<TR>
      <TD ALIGN=RIGHT><B>$l [ </B><A HREF='#$l'>jump to</A><B> | </B><A HREF='$links{$l}->{URI}' TARGET=$l>open link </A><B> ]</B></TD>
      <TD ALIGN=CENTER CLASS=$style>$status</TD>
      <TD ALIGN=RIGHT>$size</TD>
      <TD ALIGN=RIGHT>$time</TD>
		</TR>
		~;
	}
	print "</TABLE>\n<BR><BR>\n";


  my $cnt = 0;
	for my $l ( sort( keys( %links ) ) ) {
		$cnt++;
		my $pstring = $links{$l}->{PARAM_STRING} || 'no params';
		$pstring =~ s/\?//g;
		$pstring =~ s/;/, /g;
		print <<"    END";
		<BR><H3>$l:</H3> <A HREF=$links{$l}{URI}>$pstring</A> | <A NAME='$l'></A><A HREF='#top'>top</A>
		<IFRAME NAME=$cnt HEIGHT=750 WIDTH=900 frameborder=0 src='$links{$l}->{URI}'></IFRAME>
		<BR>
		<HR>
    END
	}
  $sbeams->display_page_footer();

}

__DATA__




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
# PUBLICLY ACCESSIBLE PROJECTS
###############################################################################
my $PUBLIC_PROJECTS = "275,385,398,558,587";
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
    permitted_work_groups_ref=>['ProteinStructure_user',
      'ProteinStructure_admin','ProteinStructure_readonly','Admin'],
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  $q->delete('page_only');

  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "xxxx") {
  } elsif ( $current_username eq 'ext_halo' ) {
    if ( $parameters{page_only} ) {
      print $sbeamsMOD->get_page_only_header();
      print "<BASE TARGET='_top'>\n";
      handle_request(ref_parameters=>\%parameters);
      print $sbeamsMOD->get_page_only_footer();
    } else {
      my $url = $q->self_url();
      $url .= ( $url =~ /\?/ ) ? ';page_only=yes' : '?page_only=yes';
      $sbeamsMOD->display_page_header( navigation_bar=>$parameters{navigation_bar}, centered=>1 );
      print "<IFRAME NAME='sbeams_content' HEIGHT=750 WIDTH=520 frameborder=0 src='$url'></IFRAME>";
      $sbeamsMOD->display_page_footer();
    }
  	
  }else {
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


  #### Set some specific settings for this program
  my $PROGRAM_FILE_NAME="GetHaloAnnotations";
  my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME";


  #### Get the columns and input types for this table/query
  my @columns = ( 'search_scope','search_key' );
  my %input_types = ( 'optionlist','text' );


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
  #$parameters{display_options} = 'ShowSQL';


  #### Display the user-interaction input form
  if ($sbeams->output_mode() eq 'html') {
    my @options = ( 'All','GeneSymbol','ORFName',
					'FullGeneName','ECNumbers','Aliases',
					'RedundantORFs' );

    my %options = ( 'GeneSymbol' => 'Gene Symbol',
					'ORFName' => 'ORF Name',
					'FullGeneName' => 'Full Gene Name',
					'ECNumbers' => 'EC Number',
					'Aliases' => 'Aliases',
					'RedundantORFs' => 'Redundant ORFs',
					'All' => 'All Attributes',
					);

    #### Build the option list
    my $optionlist = '';
    foreach my $key ( @options ) {
      my $flag = '';
      $flag = 'SELECTED' if ($parameters{search_scope} eq $key);
      $optionlist .= "<OPTION VALUE=\"$key\" $flag>$options{$key}</OPTION>\n";
    };
	

    print qq~
<P><FORM NAME="SearchForm" ACTION="$base_url" METHOD="POST">
Search
<SELECT NAME="search_scope">
$optionlist
</SELECT> for
<INPUT NAME="search_key" TYPE="text" SIZE="35" VALUE="$parameters{search_key}">
<INPUT NAME="protein_biosequence_set_id" TYPE="hidden" VALUE="$parameters{protein_biosequence_set_id}">
<INPUT NAME="dna_biosequence_set_id" TYPE="hidden" VALUE="$parameters{dna_biosequence_set_id}">
<INPUT TYPE="submit" NAME="action" VALUE="GO">
<BR>
 
$LINESEPARATOR
~;
  }

  #########################################################################
  #### Process all the constraints

  #### Build BIOSEQUENCE_SET constraint
  my $form_test = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.biosequence_set_id",
    constraint_type=>"int_list",
    constraint_name=>"BioSequence Set",
    constraint_value=>$parameters{protein_biosequence_set_id});
  return if ($form_test eq '-1');

  #### Verify that the selected biosequence_sets are permitted
  my @protein_ids;
  if ($parameters{protein_biosequence_set_id}) {
	@protein_ids = verify_biosequence_set_ids(ids => $parameters{protein_biosequence_set_id});
  }
  my @dna_ids;
  if ($parameters{dna_biosequence_set_id}) {
	@dna_ids = verify_biosequence_set_ids(ids => $parameters{dna_biosequence_set_id});
  }

  $parameters{protein_biosequence_set_id} = join(',',@protein_ids);
  $parameters{dna_biosequence_set_id} = join(',',@dna_ids);

  #### If no valid biosequence_set_id was selected, stop here
  unless ($parameters{protein_biosequence_set_id}) {
    $sbeams->reportException(
      state => 'ERROR',
      type => 'INSUFFICIENT CONSTRAINTS',
      message => "You must select at least one valid Biosequence Set",
    );
    return;
  }

  #### Set the input constraint to only allow that which is valid
  $sql = qq~
	SELECT project_id
	FROM $TBPS_BIOSEQUENCE_SET
	WHERE biosequence_set_id IN ( $parameters{protein_biosequence_set_id} )
	 AND record_status != 'D'
    ~;
  my @project_ids = $sbeams->selectOneColumn($sql);
  my $project_list = join (",",@project_ids);

  #### Build Protein BIOSEQUENCE_SET constraint
  my $protein_biosequence_set_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.biosequence_set_id",
    constraint_type=>"int_list",
    constraint_name=>"Protein BioSequence Set",
    constraint_value=>$parameters{protein_biosequence_set_id} );
  return if ($protein_biosequence_set_clause eq '-1');

  #### Build DNA BIOSEQUENCE_SET constraint
  my $dna_biosequence_set_clause;
  if ($parameters{dna_biosequence_set_id}) {
	my $result = $sbeams->parseConstraint2SQL(
      constraint_column=>"DBS.biosequence_set_id",
      constraint_type=>"int_list",
      constraint_name=>"DNA BioSequence Set",
      constraint_value=>$parameters{dna_biosequence_set_id} );
	$dna_biosequence_set_clause = $result if ($result ne '-1');
  }

  #### Build SEARCH SCOPE constraint
  my $search_scope_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.search_scope",
    constraint_type=>"plain_text",
    constraint_name=>"Search Scope",
    constraint_value=>$parameters{search_scope},
  );
  return if ($search_scope_clause eq '-1');

  #### Build SEARCH KEY constraint
  my $search_key_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"BS.search_key",
    constraint_type=>"plain_text",
    constraint_name=>"Search Key",
    constraint_value=>$parameters{search_key},
  );
  return if ($search_key_clause eq '-1');


  #### Identify clauses now for repetitive constraints
  my $orf_name_clause = '';
  my $gene_symbol_clause = '';
  my $ec_number_clause = '';
  my $full_gene_name_clause = '';
  my $functional_description_clause = '';
  my $duplicate_biosequences_clause = '';
  my $alias_clause = '';

  my $complete_search_keys = $parameters{search_key};
  $complete_search_keys =~ s/\s*\[AND\]\s*/_AND_/g;
  my @search_keys = split /[\s+,;]/, $complete_search_keys;

  # Remove [AND]s in parameters for searchExternal
  $complete_search_keys =~ s/_AND_/ /g;
  $parameters{search_key} = $complete_search_keys;

  foreach my $search_key (@search_keys) {
	next if ($search_key=~/^\s?$/);

	# remove '_AND_', in the case of [AND] searches
	$search_key =~ s/_AND_/ /g;
	$search_key = "\%$search_key\%";

	#### Build ORF NAME constraint
	my $temp_orf_name_clause = '';
	if ($parameters{search_scope} =~ /(ORFName|All)/) {
	  $temp_orf_name_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"BS.biosequence_accession",
        constraint_type=>"plain_text",
        constraint_name=>"ORF Name",
        constraint_value=>$search_key,
      );
	}
	return if ($temp_orf_name_clause eq '-1');
	$temp_orf_name_clause =~ s/AND/ OR/;
	$orf_name_clause .= $temp_orf_name_clause;

	#### Build GENE SYMBOL constraint
	my $temp_gene_symbol_clause = '';
	if ($parameters{search_scope} =~ /(GeneSymbol|All)/) {
	  if (defined($search_key) &&
		  $search_key gt '' &&
		  $search_key !~ /[%_]/) {
		$search_key = "$search_key\%";
	  };
	  $temp_gene_symbol_clause = $sbeams->parseConstraint2SQL(
        constraint_column=>"BSA.gene_symbol",
      	constraint_type=>"plain_text",
      	constraint_name=>"Gene Symbol",
      	constraint_value=>$search_key,
      );
	}
	return if ($temp_gene_symbol_clause eq '-1');
	$temp_gene_symbol_clause =~ s/AND/ OR/;
	$gene_symbol_clause .= $temp_gene_symbol_clause;

	#### Build EC NUMBER constraint
	my $temp_ec_number_clause = '';
	if ($parameters{search_scope} =~ /(ECNumbers|ECNumbers_exact|All)/) {
	  if (defined($search_key) &&
		  $search_key gt '' &&
		  $search_key !~ /[%_]/ &&
		  $parameters{search_scope} !~ /ECNumbers_exact/) {
		$search_key = "$search_key\%";
	  };
	  $temp_ec_number_clause = $sbeams->parseConstraint2SQL(
      	constraint_column=>"BSA.EC_numbers",
      	constraint_type=>"plain_text",
      	constraint_name=>"EC Number",
      	constraint_value=>$search_key,
      );
	}
	return if ($temp_ec_number_clause eq '-1');
	$temp_ec_number_clause =~ s/AND/ OR/;
	$ec_number_clause .= $temp_ec_number_clause;

	#### Build FULL GENE NAME constraint
	my $temp_full_gene_name_clause = '';
	if ($parameters{search_scope} =~ /(FullGeneName|All)/) {
	  if (defined($search_key) &&
		  $search_key gt '' &&
		  $search_key !~ /[%_]/) {
		$search_key = "$search_key\%";
	  };
	  $temp_full_gene_name_clause = $sbeams->parseConstraint2SQL(
      	constraint_column=>"BSA.full_gene_name",
      	constraint_type=>"plain_text",
      	constraint_name=>"Full Gene Name",
      	constraint_value=>$search_key,
      );
	}
	return if ($temp_full_gene_name_clause eq '-1');
	$temp_full_gene_name_clause =~ s/AND/ OR/;
	$full_gene_name_clause .= $temp_full_gene_name_clause;

	#### Build DUPLICATE BIOSEQUENCES constraint
	my $temp_duplicate_biosequences_clause = '';
	if ($parameters{search_scope} =~ /(RedundantORFs|All)/) {
	  if (defined($search_key) &&
		  $search_key gt "" &&
		  $search_key !~ /[%_]/) {
		$search_key = "$search_key\%";
	  };
	  $temp_duplicate_biosequences_clause = $sbeams->parseConstraint2SQL(
	   	 constraint_column=>"BSPS.duplicate_biosequences",
	   	 constraint_type=>"plain_text",
       	 constraint_name=>"Redundant ORFs",
       	 constraint_value=>$search_key,
      );
	}
	return if ($temp_duplicate_biosequences_clause eq '-1');
	$temp_duplicate_biosequences_clause =~ s/AND/ OR/;
	$duplicate_biosequences_clause .= $temp_duplicate_biosequences_clause;


	#### Build FUNCTIONAL DESCRIPTION constraint
	my $temp_functional_description_clause = '';
	if ($parameters{search_scope} =~ /(All)/) {
	  if (defined($search_key) &&
		  $search_key gt "" &&
		  $search_key !~ /[%_]/) {
		$search_key = "$search_key\%";
	  };
	  $temp_functional_description_clause = $sbeams->parseConstraint2SQL(
	   	 constraint_column=>"BSA.functional_description",
	   	 constraint_type=>"plain_text",
       	 constraint_name=>"Gene Function",
       	 constraint_value=>$search_key,
      );
	}
	return if ($temp_functional_description_clause eq '-1');
	$temp_functional_description_clause =~ s/AND/ OR/;
	$functional_description_clause .= $temp_functional_description_clause;


	#### Build ALIASES constraint
	my $temp_alias_clause = '';
	if ($parameters{search_scope} =~ /(Aliases|All)/) {
	  if (defined($search_key) &&
		  $search_key gt "" &&
		  $search_key !~ /[%_]/) {
		$search_key = "$search_key\%";
	  };
	  $temp_alias_clause = $sbeams->parseConstraint2SQL(
	   	 constraint_column=>"BSA.aliases",
	   	 constraint_type=>"plain_text",
       	 constraint_name=>"Aliases",
       	 constraint_value=>$search_key,
      );
	}
	return if ($temp_alias_clause eq '-1');
	$temp_alias_clause =~ s/AND/ OR/;
	$alias_clause .= $temp_alias_clause;

	#### Sepcial handling for scope of 'All'
	if ($parameters{search_scope} =~ /All/) {
	  my $result = searchExternal(query_parameters_ref => \%parameters,);
	  if ($result) {
		$orf_name_clause .= $sbeams->parseConstraint2SQL(
        constraint_column=>"BS.biosequence_name",
        constraint_type=>"plain_text",
        constraint_name=>"ORF Name",
        constraint_value=>$result,
      );
		$gene_symbol_clause = '';
		$ec_number_clause = '';
		$full_gene_name_clause = '';
		$alias_clause = '';
		$duplicate_biosequences_clause = '';
		$functional_description_clause = '';
		$orf_name_clause =~ s/AND/ OR/;
	  }
	}

  }



  #### No LIMITs
  my $limit_clause = '';


  #### Define some variables needed to build the query
  my $group_by_clause = "";
  my $final_group_by_clause = "";
  my @column_array;
  my $peptide_column = "";
  my $count_column = "";

  #### Define the desired columns in the query
  #### [friendly name used in url_cols references,SQL,displayed column title]
  my @column_array = (
    ["protein_biosequence_id","BS.biosequence_id","protein_biosequence_id"],
    ["biosequence_annotation_id","BSA.biosequence_annotation_id","biosequence_annotation_id"],
    ["biosequence_name","BS.biosequence_name","ORF Name"],
    ["gene_symbol","BSA.gene_symbol","Gene Symbol"],
    ["functional_description","BSA.functional_description","Gene Function"],
	["chromosome","BSPS.chromosome","Chromosome"],
	["start","BSPS.start_in_chromosome","Start"],
	["stop","BSPS.end_in_chromosome","Stop"],
	["gene_aliases","BSA.aliases","Aliases"],
    ["duplicate_sequences","BSPS.duplicate_biosequences","Redundant ORFs"],
	["comment","BSA.comment","Comment"],
    ["protein_biosequence_accession","BS.biosequence_accession","protein_biosequence_accession"],
  );

  if ($dna_biosequence_set_clause) {
	push @column_array, ["dna_biosequence_id","DBS.biosequence_id","dna_biosequence_id"];
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
      SELECT $limit_clause $columns_clause
        FROM $TBPS_BIOSEQUENCE BS
        LEFT JOIN $TBPS_BIOSEQUENCE_SET BSS
             ON ( BS.biosequence_set_id = BSS.biosequence_set_id )
        LEFT JOIN $TBPS_BIOSEQUENCE_ANNOTATION BSA
	     ON ( BS.biosequence_id = BSA.biosequence_id )
		LEFT JOIN $TBPS_BIOSEQUENCE_PROPERTY_SET BSPS
             ON ( BSPS.biosequence_id = BS.biosequence_id )
			 ~;

  $sql .= qq~
        LEFT JOIN $TBPS_BIOSEQUENCE DBS 
             ON ( DBS.biosequence_name = BS.biosequence_name )
			 ~ if ($dna_biosequence_set_clause);

  $sql .= qq~
       WHERE 1 = 1
      $protein_biosequence_set_clause
	  ~;

  $sql .= $dna_biosequence_set_clause if ($dna_biosequence_set_clause);

  $sql .= qq~
         AND ( 0 = 1
           $orf_name_clause
           $gene_symbol_clause
           $ec_number_clause
           $full_gene_name_clause
		   $alias_clause
		   $functional_description_clause
		   $duplicate_biosequences_clause
             )
		 AND BS.biosequence_seq IS NOT NULL
      ORDER BY BS.biosequence_name
   ~;

  my @rows = $sbeams->selectSeveralColumns($sql);

  #### Start the table
  my $table_html;
  my $chrom_color = "#FF9933";
  my $pnrc100_color = "#CC66CC";
  my $pnrc200_color = "#00CCCC";

  my $item_count = scalar(@rows);
  if ($sbeams->output_mode() eq 'html') {
	$table_html = qq~

	<TABLE NOBORDER>
	<TR>
	  <TD BGCOLOR="$chrom_color">&nbsp;&nbsp&nbsp;&nbsp</TD>
	  <TD>  Chromosome</TD>
	  <TD>&nbsp;</TD>
	  <TD BGCOLOR="$pnrc100_color">&nbsp;&nbsp&nbsp;&nbsp</TD>
	  <TD>  pNRC100</TD>
	  <TD>&nbsp;</TD>
	  <TD BGCOLOR="$pnrc200_color">&nbsp;&nbsp&nbsp;&nbsp</TD>
	  <TD>  pNRC200</TD>
	</TR>
	</TABLE>

	<!-----------  Data Table Beginning ------------->
	<TABLE BORDER="1" BORDERCOLOR="#888888">


	<!----------- Header Row ------------------------>
	<TR BGCOLOR="\#1C3887">
	  <TD ALIGN="CENTER"><FONT COLOR="#FFFFFF"><INPUT TYPE="button" NAME="focusButton" VALUE="Focus" onClick="focusSearch()"></TD>
	  <TD ALIGN="CENTER"><FONT COLOR="#FFFFFF">Links</FONT></TD>
	  <TD ALIGN="CENTER"><FONT COLOR="#FFFFFF">Coordinates</FONT></TD>
	  <TD ALIGN="CENTER"><FONT COLOR="#FFFFFF">ORF Name</FONT></TD>
	  <TD ALIGN="CENTER"><FONT COLOR="#FFFFFF">Gene Symbol</FONT></TD>
	  <TD ALIGN="CENTER"><FONT COLOR="#FFFFFF">Aliases</FONT></TD>
	  <TD ALIGN="CENTER"><FONT COLOR="#FFFFFF">Function</FONT></TD>
	  ~;
	$table_html .= qq~
	  <TD ALIGN="CENTER"><FONT COLOR="#FFFFFF">Comments</FONT></TD>
	  ~ if ($sbeams->getCurrent_username() ne 'ext_halo');

	$table_html .= qq~
	</TR>
	~;
  
	# Keep track of protein and dna biosequence IDs
	my @p_ids;
	my @d_ids;
	my @array_expression_genes = ();

	# Get accessible conditions
	my @accessible_project_ids = $sbeams->getAccessibleProjects();
	my $project_ids_clause = join ",", @accessible_project_ids;
	my $halo_conditions_sql = qq~
		SELECT condition_id
		FROM $TBMA_COMPARISON_CONDITION
		WHERE project_id IN ($PUBLIC_PROJECTS)
		~;
	my @conditions = $sbeams->selectOneColumn ($halo_conditions_sql);
	my $condition_ids_clause = join ",", @conditions;

	my $counter = 0;
  # list to store gaggle data
  my @glist;

	foreach my $row (@rows) {
	  my $protein_biosequence_id    = $row->[0];
	  my $biosequence_annotation_id = $row->[1];
	  my $biosequence_name          = $row->[2];
	  my $gene_symbol               = $row->[3] || "[+]";
	  my $functional_description    = $row->[4] || "[+]";
	  my $chromosome                = $row->[5] || "[+]";
	  my $start                     = $row->[6] || "[+]";
	  my $stop                      = $row->[7] || "[+]";
	  my $aliases                   = $row->[8] || "[+]";
	  my $duplicate_biosequences    = $row->[9];
	  my $comments                  = $row->[10] || "[+]";
	  $comments =~ s/\t/ /g;
	  $comments =~ s/\n/\<BR\>/g;
	  my $biosequence_accession     = $row->[11] || "[+]";
	  my $dna_biosequence_id        = $row->[12] if ($row->[12]);
	  push @p_ids, $protein_biosequence_id;
	  push @d_ids, $dna_biosequence_id if ($dna_biosequence_id);

    push @glist, $biosequence_name;

	  #### Special (fragile?) handling for halo aliases
	  my @alias_items = split ",", $aliases;
	  my $NCBI_PID_BASE = "http://www.ncbi.nlm.nih.gov/sutils/blink.cgi?pid=";
#	  my $COG_BASE = "http://www.ncbi.nlm.nih.gov/COG/new/release/cow.cgi?cog=";
	  my $COG_BASE = "http://www.ncbi.nlm.nih.gov/COG/old/palox.cgi?txt=";

	  foreach my $item (@alias_items) {
		if ($item =~ /^\d+$/) {
		  $item = "<A HREF=\"$NCBI_PID_BASE$item\" TARGET=\"Win1\" onmouseover=\"showTooltip(event,'NCBI Protein Annotation')\" onmouseout=\"hideTooltip()\">$item</A>";
		}elsif ($item =~ /^COG.*/) {
		  $item = "<A HREF=\"$COG_BASE$item\" TARGET=\"Win1\" onmouseover=\"showTooltip(event,'COG Protein Annotation')\" onmouseout=\"hideTooltip()\">$item</A>";
		}else {
		  $item = "<A HREF=\"GetHaloAnnotations?search_scope=All&search_key=$item&action=GO&dna_biosequence_set_id=$parameters{dna_biosequence_set_id}&protein_biosequence_set_id=$parameters{protein_biosequence_set_id}&apply_action=QUERY\" onmouseover=\"showTooltip(event,'Search SBEAMS for this gene')\" onmouseout=\"hideTooltip()\">$item</A>";
		}
	  }
	  my $add_an_alias = "<A HREF=\"ManageTable.cgi?TABLE_NAME=PS_biosequence_annotation&biosequence_annotation_id=$biosequence_annotation_id&biosequence_id=$protein_biosequence_id&ShowEntryForm=1\" onmouseover=\"showTooltip(event,'Add Alias to $biosequence_name')\" onmouseout=\"hideTooltip()\" target=\"annotation\">[+]</A>";
	  push @alias_items, $add_an_alias if ($sbeams->getCurrent_username() ne 'ext_halo');

	  $aliases = join ",",@alias_items;

    

	  $table_html  .= qq~

		<!-------- row $counter ---------->
		<TR>

		<!-------- check box -------->
		<TD ALIGN="CENTER">
		<INPUT TYPE="checkbox" name="focus$counter" value="$biosequence_name">
		</TD>

		<!-------- Links ------------>
		<TD NOWRAP>
		<TABLE NOBORDER CELLPADDING="0" CELLSPACING="0">
		<TR>
		~;

	  my $microbes_online_url = 'http://www.microbesonline.org/cgi-bin/keywordSearch.cgi?type=0&mapId=MAPID&term=1&locus=0&hit=0&disp=0&homolog=0&format=1&favorites=&taxTyping=halo&taxSelector=64091&taxId=64091&keyword='.$biosequence_name;
	  my $microbes_online_link =  getColorizedTD (tag=>'Microbes Online',
												  text=>'O',
												  data=>$biosequence_name,
												  target=>'microbes_onlines',
												  link=>$microbes_online_url,
												  tooltip=>"Microbes Online Search for$biosequence_name");

	 

	  push @array_expression_genes,$biosequence_name;
	  my $array_expression_link = getColorizedTD (tag=>'Gene Expression',
												  text=>'M',
												  data=>$biosequence_name,
												  target=>'array_expression',
												  link=>"$CGI_BASE_DIR/Microarray/GetHaloExpression?canonical_name_constraint=$biosequence_name&condition_id=$condition_ids_clause&row_limit=10000&input_form_format=minimum_detail&QUERY_NAME=MA_GetExpression&action=QUERY&apply_action=QUERY",
												  tooltip=>"Microarray Data Containing $biosequence_name");


	  my $dna_link = getColorizedTD (tag=>'DNA Sequences',
									 data=>$dna_biosequence_id,
									 text=>'D',
									 target=>'sequence',
									 link=>"BrowseBioSequence.cgi?project_id=$project_list&biosequence_set_id=$parameters{dna_biosequence_set_id}&biosequence_id_constraint=$dna_biosequence_id&action=QUERYHIDE&display_options=SequenceFormat&display_mode=FASTA",
									 tooltip=>"DNA sequence in FASTA format");
	  
	  my $prot_link = getColorizedTD (tag=>'Protein Sequences',
									  data=>$protein_biosequence_id,
									  text=>'P',
									  target=>'sequence',
									  link=>"BrowseBioSequence.cgi?project_id=$project_list&biosequence_set_id=$parameters{protein_biosequence_set_id}&biosequence_id_constraint=$protein_biosequence_id&action=QUERYHIDE&display_options=SequenceFormat&display_mode=FASTA",
									  tooltip=>"Protein sequence in FASTA format");
	  my $annot_link = getColorizedTD (tag=>'Annotations',
									   data=>$biosequence_annotation_id,
									   text=>'A',
									   target=>'annotation',
									   link=>"ManageTable.cgi?TABLE_NAME=PS_biosequence_annotation&biosequence_annotation_id=$biosequence_annotation_id&biosequence_id=$protein_biosequence_id&ShowEntryForm=1",
									   tooltip=>"Edit Annotation (restricted)");
	  
	  ## put a space in between redundant ORFs so the tooltip will wrap the text
	  $duplicate_biosequences =~ s/,/, /g;
	  my $tip = "None";
	  if ($duplicate_biosequences) {
		$tip = $duplicate_biosequences;
	  }
	  my $duplicates_link =  getColorizedTD (tag=>'Redundant ORFs',
											data=>$duplicate_biosequences,
											text=>'R',
											link=>"GetHaloAnnotations?search_scope=All&search_key=$biosequence_name&action=GO&dna_biosequence_set_id=$parameters{dna_biosequence_set_id}&protein_biosequence_set_id=$parameters{protein_biosequence_set_id}&apply_action=QUERY",
											tooltip=>"Redundant ORFS: $tip");
	


	  $table_html .= qq~
		$dna_link
		~if ($dna_biosequence_id);

	  $table_html .= qq~
		$prot_link
		$annot_link
		$microbes_online_link
		$array_expression_link
		$duplicates_link
		</TR>
		</TABLE>
		</TD>

		<!-------------- Coordinate Information ------------->
		<TD ~;

	  if ($chromosome eq "Chromosome") {
		$table_html .= "BGCOLOR=\"$chrom_color\"";
	  }elsif ($chromosome eq "pNRC100") {
		$table_html .= "BGCOLOR=\"$pnrc100_color\"";
	  }elsif ($chromosome eq "pNRC200") {
		$table_html .= "BGCOLOR=\"$pnrc200_color\"";
	  }	

	  $table_html .= qq~><A HREF="SequenceViewer.cgi?biosequence_id=$protein_biosequence_id" onmouseover="showTooltip(event,'View ORF in chromosomal context')" onmouseout="hideTooltip()">$start..$stop</A></TD>

	  <!----------------- ORF Name -------------------->
	  <TD><B>$biosequence_name</B></TD>
	  <!----------------- Gene Symbol -------------------->
	  <TD><B>$gene_symbol</B></TD>
	  <!----------------- Aliases -------------------->
	  <TD>$aliases</TD>
	  <!----------------- Function -------------------->
	  <TD><A HREF="$CGI_BASE_DIR/ProteinStructure/GetDomainHits?project_id=150&biosequence_set_id=$parameters{protein_biosequence_set_id}&biosequence_accession_constraint=$biosequence_accession&action=QUERYHIDE&display_options=ApplyChilliFilter" onmouseover="showTooltip(event,'View Domain Hits')" onmouseout="hideTooltip()" target="function">$functional_description</A></TD>
	  ~;



	  $table_html .= qq~
	  <!----------------- Comments -------------------->
	  <TD><A HREF="ManageTable.cgi?TABLE_NAME=PS_biosequence_annotation&biosequence_annotation_id=$biosequence_annotation_id&biosequence_id=$protein_biosequence_id&ShowEntryForm=1" target="annotation">$comments</A></TD>
	  ~ if ($sbeams->getCurrent_username() ne 'ext_halo');

	  $table_html .= qq~
	</TR>
	~;
	  $counter++;
	}

  my $gXML = $sbeams->getGaggleXML( object => 'namelist', 
                                      type => 'direct',
                                      name => "Orf names",
                                      data => \@glist,
                                     start => 1, 
                                       end => 1,
                                  organism => 'Halobacterium sp.');
  print "$gXML\n";

	# End the table
	$table_html .= qq~
	  </TABLE>
	  </FORM></P>

   <!---------- Javascript for table checkboxes -------------->
   <SCRIPT LANGUAGE="Javascript">
   var focusBoxes = new Array($item_count);
	~;
	for (my $m=0;$m<$item_count;$m++) {
	  $table_html .= "focusBoxes[".$m."] = document.SearchForm.focus".$m.";\n";
	}
	$table_html .=qq~

   function focusSearch(){
	 var count = 0;
	 var key ="";
	 for (var temp=0;temp<$item_count;temp++) {
	   if (focusBoxes[temp].checked){
		 count++;
		 key += focusBoxes[temp].value+",";
	   }
	 }
	 if (count > 0) {
	   document.SearchForm.search_key.value=key;
//	   alert(document.SearchForm.search_key.value);
	   document.SearchForm.submit();
	 }else{
	   alert('Need at least one box checked!');
	   return;
	 }
   }
    </SCRIPT>
	  ~;

	## PREPEND summary links
	print "<BR><B><FONT COLOR=\"red\">$counter</FONT> Results Returned</B><BR>";
	$table_html = qq~
	  <A HREF="GetHaloAnnotations?search_scope=$parameters{search_scope}&search_key=$parameters{search_key}&action=GO&dna_biosequence_set_id=$parameters{dna_biosequence_set_id}&protein_biosequence_set_id=$parameters{protein_biosequence_set_id}&apply_action=QUERY&output_mode=tsv">-Download Tab-delimited Summary</A><BR>
	  ~ . $table_html;
	if (@p_ids) {
	  my $p_list = join ",", @p_ids;
	  $table_html = qq~
	  <A HREF="BrowseBioSequence.cgi?project_id=$project_list&biosequence_set_id=$parameters{protein_biosequence_set_id}&biosequence_id_constraint=$p_list&action=QUERYHIDE&display_options=SequenceFormat&display_mode=FASTA">-View all Protein Entries</A><BR>
	  ~ . $table_html;
	}
	if (@d_ids) {
	  my $d_list = join ",", @d_ids;
	  $table_html = qq~
	  <A HREF="BrowseBioSequence.cgi?project_id=$project_list&biosequence_set_id=$parameters{dna_biosequence_set_id}&biosequence_id_constraint=$d_list&action=QUERYHIDE&display_options=SequenceFormat&display_mode=FASTA">-View all DNA Entries</A><BR>
	  ~ . $table_html;
	}
	if (@array_expression_genes) {
	  my $array_expression_ids = join "%3B", @array_expression_genes;
	  $table_html = qq~
		<A HREF="$CGI_BASE_DIR/Microarray/GetHaloExpression?condition_id=$condition_ids_clause&canonical_name_constraint=$array_expression_ids&row_limit=10000&input_form_format=minimum_detail&QUERY_NAME=MA_GetExpression&action=QUERY&apply_action=QUERY&sort_order=condition_name" TARGET="array_expression">-View Microarray data</A><BR>
		<A HREF="$CGI_BASE_DIR/Microarray/GetHaloExpression?condition_id=$condition_ids_clause&canonical_name_constraint=$array_expression_ids&row_limit=10000&input_form_format=minimum_detail&QUERY_NAME=MA_GetExpression&action=QUERY&apply_action=QUERY&sort_order=condition_name&output_mode=tsv">-Download Microarray data</A><BR>
		~ . $table_html;
	}

	#### Print HTML
	print $table_html;

  }elsif ($sbeams->output_mode() =~ /tsv|csv|excel/) {
	
	#### If the invocation_mode is http, provide a header
	my $delimiter = "\t";
	my $header = "Content-type: text/tab-separated-values\n\n";
	if ($sbeams->invocation_mode() eq 'http') {
	  if ($sbeams->output_mode() =~ /tsv/) {
		$header = "Content-type: text/tab-separated-values\n\n";
		$delimiter = "\t";
	  } elsif ($sbeams->output_mode() =~ /csv/) {
		$header = "Content-type: text/comma-separated-values\n\n";
		$delimiter = ",";
	  } elsif ($sbeams->output_mode() =~ /excel/) {
		$header = "Content-type: application/excel\n\n";
		$delimiter = "\t";
	  }
	}
	print $header if ($sbeams->invocation_mode() eq 'http');

	print "ORF Name\tChromosome\tCoordinates\tGene Symbol\tFunction\tAliases\tRedundant ORFs";
	print "\tComments" if ($sbeams->getCurrent_username() ne 'ext_halo');
	print "\n";

	foreach my $row (@rows) {
	  my $protein_biosequence_id    = $row->[0];
	  my $biosequence_annotation_id = $row->[1];
	  my $biosequence_name          = $row->[2];
	  my $gene_symbol               = $row->[3];
	  my $functional_description    = $row->[4];
	  my $chromosome                = $row->[5];
	  my $start                     = $row->[6];
	  my $stop                      = $row->[7];
	  my $aliases                   = $row->[8];
	  my $duplicate_biosequences    = $row->[9];
	  my $comments                  = $row->[10];
	  $comments =~ s/\s+/ /g;
	  my $biosequence_accession     = $row->[11];
	  my $dna_biosequence_id        = $row->[12] if ($row->[12]);

	  my @line =  ($biosequence_name,
				   $chromosome,
				   "$start..$stop",
				   $gene_symbol,
				   $functional_description,
				   $aliases,
				   $duplicate_biosequences,
				   $comments);

	  # remove 'comments' if user eq ext_halo
	  pop @line if ($sbeams->getCurrent_username() eq 'ext_halo');
	  print join ($delimiter, @line);
	  print "\n";
	}
  }

  if ($sbeams->invocation_mode() ne 'http') {
	print "You need to supply some parameters to contrain the query\n";
  }

} # end handle_request



###############################################################################
# getColorizedTD- returns a <TD> </TD> tagset
###############################################################################
sub getColorizedTD {
  my %args = @_;
  my $tag  = $args{'tag'};
  my $data = $args{'data'};
  my $text = $args{'text'};
  my $link = $args{'link'};
  my $target = $args{'target'};
  my $tooltip = $args{'tooltip'};
  $tooltip = "NO $tag" unless ($tooltip) ;

  my $go_color = "#66FF33";
  my $stop_color = "#FF0033";

  my $html = "<TD";
  if ($data && $link) {
	$html .= " BGCOLOR=\"$go_color\">";
  }else {
	$html .= " BGCOLOR=\"$stop_color\">";
  }

  $html .= "<A";
  $html .= " HREF=\"$link\"" if ($data && $link);
  $html .= " onmouseover=\"showTooltip(event,'$tooltip')\" onmouseout=\"hideTooltip()\"" if ($tooltip);
  $html .= " target=\"$target\"" if ($target);
  $html .= ">";
  

  $html .= $text;

  if ($data && $link) {
	$html .= "</A>";
  }
  
  $html .= "</TD>";
  return $html;
}


###############################################################################
# evalSQL: Callback for translating global table variables to names
###############################################################################
sub evalSQL {
  my $sql = shift;

  return eval "\"$sql\"";

} # end evalSQL


sub verify_biosequence_set_ids {
  my %args = @_;
  my $ids = $args{'ids'} || die "biosequence_set_ids need to be passed.";
  
  my $sql = qq~
	SELECT biosequence_set_id,project_id
	FROM $TBPS_BIOSEQUENCE_SET
	WHERE biosequence_set_id IN ( $ids )
	 AND record_status != 'D'
    ~;
    my %project_ids = $sbeams->selectTwoColumnHash($sql);
    my @accessible_project_ids = $sbeams->getAccessibleProjects();
    my %accessible_project_ids;
    foreach my $id ( @accessible_project_ids ) {
      $accessible_project_ids{$id} = 1;
    }

    my @input_ids = split(',',$ids);
    my @verified_ids;
    foreach my $id ( @input_ids ) {

      #### If the requested biosequence_set_id doesn't exist
      if (! defined($project_ids{$id})) {
		$sbeams->reportException(
          state => 'ERROR',
          type => 'BAD CONSTRAINT',
          message => "Non-existent biosequence_set_id = $id specified",
        );

      #### If the project for this biosequence_set is not accessible
      } elsif (! defined($accessible_project_ids{$project_ids{$id}})) {
		$sbeams->reportException(
          state => 'ERROR',
          type => 'PERMISSION DENIED',
          message => "Your current privilege settings do not allow you to access biosequence_set_id = $id.  See project owner to gain permission.",
        );

      #### Else, let it through
      } else {
		push(@verified_ids,$id);
      }

    }

  return @verified_ids;
}


################################################################################
# searchExternal: A method to search an external file for any matching info
###############################################################################
sub searchExternal {
  my %args = @_;

  #### Process the arguments list
  my $query_parameters_ref = $args{'query_parameters_ref'};

  #### Determine which external data source to search
  my %abbreviations = (
    '3' => 'Hm', # Hm
    '2' => 'Halo', # Halobac
  );

  my $abbreviation = $abbreviations{$query_parameters_ref->{protein_biosequence_set_id}};
  unless ($abbreviation) {
    print "ERROR: Unable to find a file for this dataset<BR>\n";
    return 0;
  }

  #### Search both the DomainHits and Biosequences files
  my %biosequence_accessions;
  foreach my $filetype ( qw (DomainHits Biosequences) ) {

    #### Open the file
    my $file = "${abbreviation}_$filetype.tsv";
    my $fullfile = "/net/dblocal/www/html/sbeams/var/$SBEAMS_SUBDIR/$file";
    open(INFILE,$fullfile) || die("ERROR: Unable to open $fullfile");

    #### Parse header line
    my $line = <INFILE>;
    $line =~ s/[\r\n]//g;

    my @column_list = split("\t",$line);

    #### Convert the array into a hash of names to column numbers
    my $i = 0;
    my %column_hash;
    foreach my $element (@column_list) {
      $column_hash{$element} = $i;
      $i++;
    }
    my $col = $column_hash{'biosequence_name'};
    unless ($col) {
      print "ERROR: Could not find column 'biosequence_accession'<BR>";
      $col = 0;
    }

    #### Get the search_spec
    my $search_spec = $query_parameters_ref->{search_key};
    $search_spec =~ s/\./\\./g;

    my @specs = split(/[\s+,;]/,$search_spec);

    #### Search through the file looking for matches
    while ($line = <INFILE>) {
      $line =~ s/[\r\n]//g;
      my $match = 0;
      foreach my $spec (@specs) {
		if ($line =~ /$spec/i) {
		  $match = 1;
		  last;
		}
      }

      #### If there was a match, save this accession
	  if ($match) {
	   my @columns = split("\t",$line);
		$biosequence_accessions{$columns[$col]}++;
      }
    }

    close(INFILE);

  }

#  print join(";",keys(%biosequence_accessions)),"\n";

  return join(";",keys(%biosequence_accessions));

} # end searchExternal

