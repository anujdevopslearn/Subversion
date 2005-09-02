#!/usr/local/bin/perl 


#########################################################################
# Program  	: Search_Oligo.cgi
# Authors	: Patrick Mar <pmar@systemsbiology.org>,
#             Michael Johnson <mjohnson@systemsbiology.org>
#
# Other contributors : Eric Deutsch <edeutsch@systemsbiology.org>
# 
# Description : Implements the search and display of oligos, Asks
# users to enter search criteria and queries the database appropriately
#
#               
#
# Last modified : 9/1/05
#########################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $cg $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Oligo;
use SBEAMS::Oligo::Settings;
use SBEAMS::Oligo::Tables;

use SBEAMS::ProteinStructure;
use SBEAMS::ProteinStructure::Settings;
use SBEAMS::ProteinStructure::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Oligo;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
$cg = new CGI;


###############################################################################
# Set Global Variables and execute main()
###############################################################################
$PROGRAM_FILE_NAME = 'Search_Oligo.cgi';
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  ## Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate());

  ## Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$cg,parameters_ref=>\%parameters);

  #Uncomment for debugging mode
  #$sbeams->printDebuggingInfo($cg);

  my $apply_action = $parameters{'action'} || $parameters{'apply_action'};

  ## Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);

  ## Decide what action to take based on information so far
  if ($parameters{apply_action} eq "???") {
    # Some action
  }elsif ($apply_action eq "VIEWRESULTSET" ||
		  $apply_action eq "QUERY") {
    $sbeamsMOD->printPageHeader();
    handle_request(ref_parameters=>\%parameters);
	$sbeamsMOD->printPageFooter();
  }else {
    $sbeamsMOD->printPageHeader();
	print_entry_form(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }

} # end main



###############################################################################
# print_entry_form - Prints the form that will ask user to input info.
# necessary for the query
###############################################################################
sub print_entry_form {
  my %args = @_;
  my $SUB_NAME = "print_entry_form";

  ## Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
  || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  ## start the form
  ## the statement shown defaults to POST method, and action equal to this script
  print "<H1> Oligo Search</H1>";
  
  print $cg->start_form;  
  
  ## Print the form elements
  print
    "Genes: ",$cg->textarea(-name=>'genes'),
    $cg->p,
    "Organism: ",
    $cg->popup_menu(-name=>'organism',
	               -values=>['halobacterium-nrc1']),
    $cg->p,
    "Select oligo set type to search: ",
    $cg->p,
    $cg->popup_menu(-name=>'set_type',
                   -values=>['Gene Knockout', 'Other']),
    
    $cg->p,
	$cg->submit(-name=>"action", value=>"QUERY");

  # end of the form
  print $cg->end_form,
      $cg->hr; 

  return;
}

###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;
  my $SUB_NAME = "handle_request";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  ## Useful Variables
  my $apply_action = $parameters{'action'} || $parameters{'apply_action'};
  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$cg);
  my $base_url = "$CGI_BASE_DIR/Oligo/Search_Oligo.cgi";

  my %url_cols;
  my %hidden_cols;
  my @column_titles = ();
  my $limit_clause = '';

  ## These were selected by the user
  my $organism = $parameters{organism};
  my $set_type = $parameters{set_type};

  ## If the apply action was to recall a previous resultset, do it
  if ($apply_action eq "VIEWRESULTSET"  && $apply_action ne 'QUERY') {
	$sbeams->readResultSet(resultset_file=>$rs_params{set_name},
						   resultset_ref=>$resultset_ref,
						   query_parameters_ref=>\%parameters,
						   resultset_params_ref=>\%rs_params,
						   );
	}

  
  ## Stuff gene names from text area into array
  my $genes = $parameters{genes};
  my @gene_array = split(/\s\n/,$genes);   
    
  ## Decide whether to search knockouts or expression
  my $set_type_search;    #The part of the sql query below that depends on set type value
  if ($set_type eq 'Gene Expression') {
	$set_type_search = "(OT.oligo_type_name='halo_exp_for' OR OT.oligo_type_name='halo_exp_rev')";      
  }elsif($set_type eq 'Gene Knockout'){
	$set_type_search = "(OT.oligo_type_name='halo_ko_a' OR OT.oligo_type_name='halo_ko_b' OR OT.oligo_type_name='halo_ko_c' OR OT.oligo_type_name='halo_ko_d' OR OT.oligo_type_name='halo_ko_e' OR OT.oligo_type_name='halo_ko_f' OR OT.oligo_type_name='halo_ko_g' OR OT.oligo_type_name='halo_ko_h')";
  }elsif($set_type eq 'Other'){
	$set_type_search = "(OT.oligo_type_name='halo_generic')";
  }else{
	#print "Error: Invalid oligo type selected. ";
  }

  ## Find the biosequence set_tag
  my $set_tag;
  if ($organism eq 'haloarcula marismortui') {
	$set_tag = "'haloarcula_orfs'";
  }elsif($organism eq 'halobacterium-nrc1'){
	$set_tag = "'halobacterium_orfs'";
  }else{
	print "ERROR: No organism type selected.\n";
  }

  ## Process for each individual gene in array
  foreach my $gene (@gene_array) {

    my $common_name = lc $gene;
   
    
    ## Strip gene name of letters and get just the gene number (in case of partial entry)
	$gene =~ /[a-z,A-Z]*(\d*)[a-z,A-Z]*/;
	my $gene_number = $1; 
	
    ## Search for vng synonym of common name, Use the local coordinate files as lookup tables
    ## Note that in many cases, common name is the same as canonical name
	if($organism eq 'halobacterium-nrc1'){
	  open(A, "halobacterium.txt") || die "Could not open halobacterium.txt";
	}elsif($organism eq 'haloarcula marismortui'){
	  open(A, "haloarcula.txt") || die "Could not open haloarcula.txt";
	}else{
	  open(A, "halobacterium.txt") || die "Could not open halobacterium.txt"; #default = nrc-1
	}

	while(<A>){
	  my @temp = split;
	  if($common_name =~ /[a-z,A-Z]*\d+[a-z,A-Z]*/ && 
		                          ("VNG".$gene_number."C" eq $temp[0] || 
								   "VNG".$gene_number."H" eq $temp[0] ||
								   "VNG".$gene_number."G" eq $temp[0] ) ){
		$common_name = lc $temp[1];
	  }
	  if(lc $gene eq lc $temp[1]){  #if a common name was entered
		$gene = $temp[0];     #assign $gene to the equivalent canonical name
	  }
	}  
	close(A);

	## Define the desired columns in the query
	## [friendly name used in url_cols,SQL,displayed column title]
	my @column_array = (
						["Primer","BS.biosequence_name","Oligo"],
						["Oligo_type","OT.oligo_type_name","Oligo Type"],
						["Primer_Sequence","OG.feature_sequence","Oligo Sequence"],
						["Length","OG.sequence_length","Length"],
						["Oligo","OG.oligo_id","Oligo"],
						["GC Content", "OA.GC_content", "GC Content"],
						["Melting Temperature", "OG.melting_temp", "Melting Temperature"],
						["Secondary Structure", "OA.secondary_structure", "Secondary Structure"],
						["In_Stock","OA.in_stock","In Stock"],
						["Location", "OA.location", "Location"],
						["Comments", "SO.comments", "Comments"]
						);

	####Build the columns part of the SQL statement
	my %colnameidx = ();
	my $columns_clause = $sbeams->build_SQL_columns_list(
            column_array_ref=>\@column_array,
            colnameidx_ref=>\%colnameidx,
            column_titles_ref=>\@column_titles
															   );
  
	#Code to search for identical genes
	my $warning_phrase = "WARNING: Identical Genes Found: ";
	my @identical_matches = ();
	open(OPEN_FILE, "halobacterium.txt") || die "Could not open halobacterium.txt";	
	while(<OPEN_FILE>){
	  my @temp = split;
	  if($common_name eq lc $temp[1]){  #get VNG numbers of all identical genes
		$warning_phrase = $warning_phrase . "$temp[0] ";
		#append $temp[0] to identical match array;
		unshift(@identical_matches, $temp[0]);
	  }
	}  
	close(OPEN_FILE);

    if(exists $identical_matches[1]) {
	  print "<H3>$warning_phrase</H3>";
	}

    #Search for all identical genes 
	foreach my $match (@identical_matches) {

	  $match =~ /[a-z,A-Z]*(\d*)[a-z,A-Z]*/;
	  $gene_number = $1; 
	  
	  ####SQL query command
	  my $sql = qq~ SELECT $columns_clause
		FROM $TBOG_SELECTED_OLIGO SO
		LEFT JOIN $TBOG_BIOSEQUENCE BS ON (BS.biosequence_id=SO.biosequence_id)
		LEFT JOIN $TBOG_OLIGO_TYPE OT ON (SO.oligo_type_id=OT.oligo_type_id)
		LEFT JOIN $TBOG_OLIGO OG ON (OG.oligo_id=SO.oligo_id)
		LEFT JOIN $TBOG_OLIGO_ANNOTATION OA ON (OA.oligo_id=OG.oligo_id)
		LEFT JOIN $TBOG_BIOSEQUENCE_SET BSS ON (BSS.biosequence_set_id=BS.biosequence_set_id)
		WHERE BS.biosequence_name LIKE '%$gene_number%' AND $set_type_search AND BSS.set_tag=$set_tag
		~;
	  
	  
	  ##Define the hypertext links for columns that need them
	  my %url_cols = ('Primer_Sequence' => "./Display_Oligo_Detailed.cgi?Gene=%0V&Oligo_type=%1V&Oligo_Sequence=%2V&In_Stock=%7V");
	  
	  ## Define columns that should be hidden in the output table
	  my %hidden_cols = ('Oligo_type' => 1,
						 'Oligo' => 1,
						 'Comments' => 1);
	  
	  my %hidden_cols_download = ('Oligo_type' => 1,
								  'Oligo' => 1, 
								  'Length' => 1,
								  'GC Content' => 1,
								  'Melting Temperature' => 1,
								  'Secondary Structure' => 1,
								  'In_Stock' => 1,
								  'Location' => 1);
	  
	  ## ROWCOUNT
	  $parameters{row_limit} = 5000
		unless ($parameters{row_limit} > 0 && $parameters{row_limit}<=1000000);
	  $limit_clause = $sbeams->buildLimitClause(row_limit=>$parameters{row_limit});
	  
	  ## Prevent execution of query for Haloarcula Knockouts, which hasn't been written yet
	  unless($organism eq 'haloarcula_marismortui' && $set_type eq 'Gene Knockout'){
		
		## If the action contained QUERY, then fetch the results from SBEAMS
		if ($apply_action ne "VIEWRESULTSET") {
		  
		  ## Fetch the results from the database server
		  $sbeams->fetchResultSet(sql_query=>$sql,
								  resultset_ref=>$resultset_ref,
								  );
		  
		  #### Store the resultset and parameters to disk resultset cache
		  $rs_params{set_name} = "SETME";
		  $sbeams->writeResultSet(resultset_file_ref=>\$rs_params{set_name},
								  resultset_ref=>$resultset_ref,
								  query_parameters_ref=>\%parameters,
								  resultset_params_ref=>\%rs_params,
								  query_name=>"$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME",
								  );
		}
		
		## Set the column_titles to just the column_names
		@column_titles = @{$resultset_ref->{column_list_ref}};
		
		## Make additional modifications to display table
		modify_table(resultset_ref => $resultset_ref);	
		
		## Display the resultset
		$sbeams->displayResultSet(resultset_ref=>$resultset_ref,
								  query_parameters_ref=>\%parameters,
								  rs_params_ref=>\%rs_params,
								  url_cols_ref=>\%url_cols,
								  hidden_cols_ref=>\%hidden_cols,
								  column_titles_ref=>\@column_titles,
								  base_url=>$base_url,
								  );
		
   	
		## Option(s) for Downloading Oligos
		print qq~
		  <A HREF="./Download_Options.cgi?gene=$match&organism=$organism&set_tag=$set_tag&set_type_search=$set_type_search&gene_number=$gene_number">View Download Options</A><BR>
		  ~;
		
        ## Options for Displaying Oligo in Chromosomal Context
        ## This uses Michael Johnson's SequenceViewer script in the ProteinStructure database
		my $id = get_ProteinStructure_biosequence_id(vng=>$gene);
        print qq~ 
		<BR><A HREF="$CGI_BASE_DIR/ProteinStructure/SequenceViewer.cgi?biosequence_id=$id&mode=OLIGO">Graphical View (Only Default Oligos Shown)</A><BR>
		~;
	  }
	}
	
  }
  
  ## Back button
  print qq~
	<BR><A HREF="$CGI_BASE_DIR/Oligo/Search_Oligo.cgi">Search again</A><BR>  
	~;

  ## The Add Oligo link has been taken out as that is not ready yet.
  ## <BR><A HREF="$CGI_BASE_DIR/Oligo/Add_Oligo.cgi">Add New Oligo</A><BR><BR>

  return;

} # end handle_request



##############################################################################
# modify_table - Make additional modifications to SBEAMS table such as primer name
##############################################################################
sub modify_table{  
    my %args = @_;

    ## Access the resultset and pull out necessary arguments to reformat the oligo
    ## name into: <gene>.<extension type>

	my $resultset_ref = $args{resultset_ref};

    my $aref = $$resultset_ref{data_ref};
 
    my $full_oligo_name = "";
    foreach my $row_aref (@{$aref} ) { 
      if ($row_aref->[1] =~ /halo_exp_(.*)/ || $row_aref->[1] =~ /halo_ko_(.*)/) {
		$full_oligo_name = $row_aref->[0] . "." . $1; 
	  }
      $row_aref->[0] = $full_oligo_name;
	}
}


##############################################################################
# get_ProteinStructure_biosequence_id
#
# returns biosequence_id from the biosequence table in ProteinStructure
# expects as parameter: vng - the number in the VNG name of the gene
##############################################################################
sub get_ProteinStructure_biosequence_id {
  my %args = @_;
  
  my $VNG = $args{vng};
  
  ## Reformat VNG name
  ## Make sure that parameter is just the gene number
  if($VNG =~ /[a-z,A-Z]*(\d*)[a-z,A-Z]*/) {
   	$VNG = $1;
  } 
  ## If VNG ends with a letter, get rid of it
  $VNG = "VNG" . $VNG;

  ## Search for all matches (could be same sequence, multiple genes)
  my $sql = qq~
	use ProteinStructure2
	SELECT BS.biosequence_id
	FROM $TBPS_BIOSEQUENCE BS
	WHERE BS.biosequence_name LIKE '$VNG%'
	~;

  my @ids = $sbeams->selectOneColumn($sql);
  my $id = $ids[0];  

  return $id;
  
}
	

