#!/usr/local/bin/perl 


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $q1 $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME $project_id
             $search_tool_id $gene_set_tag $chromosome_set_tag @MENU_OPTIONS);
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Oligo;
use SBEAMS::Oligo::Settings;
use SBEAMS::Oligo::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Oligo;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use CGI;
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
  if ($parameters{action} eq "???") {
    # Some action
  }else {
    $sbeamsMOD->printPageHeader();
    print_javascript();
    handle_request(ref_parameters=>\%parameters,
                   user=>$current_username);
    $sbeamsMOD->printPageFooter();
  }


} # end main


###############################################################################
# print_javascript 
##############################################################################
sub print_javascript {

print qq~
<SCRIPT LANGUAGE="Javascript">
<!--

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
  my $SUB = "handle_request";
  my $current_username = $args{user} || 
	die "[BUG-$SUB]: username not passed\n";
  my $sql;
  my @rows;
  

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  print "<H1> Add New Oligo </H1>";
  
  
  # start the form
  # the statement shown defaults to POST method, and action equal to this script
  print $q->start_form;  

  # print the form elements
  print
    "Enter gene name: ",$q->textfield(-name=>'gene'),
    $q->p,
    "Enter sequence: ",$q->textarea(-name=>'sequence'),
    $q->p,
    "Select organism: ",
    $q->popup_menu(-name=>'organism',
	               -values=>['halobacterium-nrc1','haloarcula marismortui']),
    $q->p,
    "Select oligo set type: ",
    $q->p,
    $q->popup_menu(-name=>'set_type',
                   -values=>['Gene Expression', 'Gene Knockout']),
	$q->p,
	$q->popup_menu(-name=>'type_extension',
				   -values=>['a','b','c','d','e','for','rev']),
    
    $q->p,
    $q->submit(-name=>"Add Oligo");

  # end of the form
    print $q->end_form,
    $q->hr; 
        

  if ($q->request_method() eq "POST" ) {
    my $gene = $parameters{gene};
    my $sequence = $parameters{sequence};
    my $organism = $parameters{organism};
    my $set_type = $parameters{set_type};
	my $type_extension = $parameters{type_extension};

    ####get project_id, chromosome set_tag, gene set_tag
    if($organism eq "halobacterium-nrc1"){
	  $project_id = 425;
      $chromosome_set_tag = "halobacterium_genome";
      $gene_set_tag = "halobacterium_orfs";
	}else{
	  $project_id = 424;    ##must be haloarcula marismortui
      $chromosome_set_tag = "haloarcula_genome";
      $gene_set_tag = "haloarcula_orfs";
	}

    ####search tool id
    $search_tool_id = 5;  #for user defined oligo

   


    my $oligo_search_id;
    $oligo_search_id = add_oligo_search_record(user=>$current_username,
											 project=>$project_id);


    my $gene_biosequence_set_id = add_oligo_parameter_set_record(
    oligo_search_id=>$oligo_search_id,
    gene_set_tag=>$gene_set_tag,
	chromosome_set_tag=>$chromosome_set_tag
															);
  
    insert_oligo(project_id=>$project_id,
					search_tool_id=>$search_tool_id,
					oligo_search_id=>$oligo_search_id,
				    type_extension=>$type_extension,
					biosequence_set_id=>$gene_biosequence_set_id,   
                    sequence=>$sequence           
					);
    
  }


  return;

} # end handle_request


######################################################################
# add_oligo_search_record
######################################################################
sub add_oligo_search_record{
  my %args = @_;

  ## Variables
  my $current_username = $args{user} || die "[ERROR]: username not passed\n";
  my $project_id = $args{project} || die "[ERROR]: project not passed\n";
  my $sql;
  my @rows;
  
  ## Get oligo_types that correspond to oligo_set_type
  
  my $search_id_code = get_timestamp();

  ## Populate oligo_search table
  my %rowdata = ('project_id' => $project_id,                 
				 'search_tool_id' => $search_tool_id,
				 'search_id_code' => $search_id_code,
				 'search_username' => $current_username,
				 'comments' => "created by Add_Oligo.cgi");

  my $rowdata_ref = \%rowdata; 

  my $oligo_search_id = $sbeams->updateOrInsertRow(
	table_name => "$TBOG_OLIGO_SEARCH",
		print_SQL=>1,
        rowdata_ref => $rowdata_ref,
        insert => 1,
        return_PK => 1,
        testonly => 0, 
        verbose => 0,
        add_audit_parameters => 1 );
    undef %rowdata;
  

  return $oligo_search_id;
  }


######################################################################
# get_timestamp
######################################################################
sub get_timestamp {
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
  return sprintf("%d-%02d-%02d_%02d:%02d:%02d",
      1900+$year,$mon+1,$mday,$hour,$min,$sec);
}


######################################################################
# add_oligo_parameter_set_record
######################################################################
sub add_oligo_parameter_set_record{
  my %args = @_;

  ## Variables
  my $SUB = "add_oligo_parameter_set_record";
  my $oligo_search_id = $args{oligo_search_id} || 
	die "[BUG-$SUB]: oligo_search_id not passed\n";
  my $gene_tag = $args{gene_set_tag} ||
	die "[BUG-$SUB]: gene_set_tag not passed\n";
  my $chrom_tag = $args{chromosome_set_tag} ||
	die "[BUG-$SUB]: chromosome_set_tag not passed\n";

  my $sql;  
  my @rows;

  ## Find biosequence_set_ids corresponding to gene tag
  $sql = qq~
SELECT biosequence_set_id 
  FROM $TBOG_BIOSEQUENCE_SET
 WHERE set_tag = '$gene_tag'
   AND record_status != 'D'
   ~;
  my @rows = $sbeams->selectOneColumn($sql);
  if ( scalar(@rows) == 0 ) {
	print "[ERROR]: no biosequence set found with tag $gene_tag\n";
	exit;
  }elsif ( scalar(@rows) > 1 ) {
	print "[WARNING]: Multiple ids found for $gene_tag.  Using first one.\n";
  }
  my $gene_library_id = $rows[0];

  ## Find biosequence_set_ids corresponding to chrom tag
  $sql = qq~
SELECT biosequence_set_id 
  FROM $TBOG_BIOSEQUENCE_SET
 WHERE set_tag = '$chrom_tag'
   AND record_status != 'D'
   ~;
  my @rows = $sbeams->selectOneColumn($sql);
  if ( scalar(@rows) == 0 ) {
	print "[ERROR]: no biosequence set found with tag $chrom_tag\n";
	exit;
  }elsif ( scalar(@rows) > 1 ) {
	print "[WARNING]: Multiple ids found for $chrom_tag.  Using first one.\n";
  }
  my $chromosome_library_id = $rows[0];

  my %rowdata =('oligo_search_id' => $oligo_search_id,
				'gene_library_id'=>$gene_library_id,
				'chromosome_library_id'=>$chromosome_library_id);
  
 $sbeams->updateOrInsertRow(
	table_name => "$TBOG_OLIGO_PARAMETER_SET",
		print_SQL=>1,
        rowdata_ref => \%rowdata,
        insert => 1,
        return_PK => 1,
        testonly => 0, 
        verbose => 0 
        );
  
  return $gene_library_id;
}


######################################################################
# insert_oligo
######################################################################
sub insert_oligo {
  my %args = @_;

  ## Variables
  my $sql;
  my @rows;
  my $counter = 0;

  my $SUB="insert_oligo";
  my $oligo_search_id = $args{oligo_search_id} ||
	die "[BUG-$SUB]: oligo_search_id not passed.\n";
  my $search_tool_id = $args{search_tool_id} ||
	die "[BUG-$SUB]: search_tool_id not passed\n";
  my $biosequence_set_id = $args{biosequence_set_id} ||
	die "[BUG-$SUB]: biosequence_set_id not passed.\n";
  my $project_id = $args{project_id} ||
	die "[BUG-$SUB]: project_id not passed\n";
  my $sequence = $args{sequence} ||
	die "[BUG-$SUB]: sequence not passed\n";
  my $type_extension = $args{type_extension} ||
	die "[BUG-$SUB]: type extension not passed\n";

  #my %oligo_types = %{$oligo_types_ref};
  my %selected_oligos;


  ## Get the ID of the oligo (INSERTing a record, if necessary)
  my $oligo_id = get_oligo(project_id=>$project_id,
							   sequence=>$sequence);
  my %rowdata;


  ## Find the oligo type extension (ie: a,b,c,d,e,for,rev)
  ## Also, find biosequence_id
  my $oligo_type_id;
  if ($type_extension eq "a") {
    $oligo_type_id = "1";
  }elsif ($type_extension eq "b") {
    $oligo_type_id = "2";
  }elsif($type_extension eq "c") {
    $oligo_type_id = "3";
  }elsif ($type_extension eq "d") {
    $oligo_type_id = "4";
  }elsif ($type_extension eq "e") {
	$oligo_type_id = "5";
  }elsif($type_extension eq "for") {
	$oligo_type_id = "6";
  }elsif($type_extension eq "rev") {
	$oligo_type_id = "7";
  }else{
	print "[WARNING]: no type extension selected\n";
  }


  ## Create a hash for information that we'll need.
  $rowdata{oligo_search_id} = $oligo_search_id;
  $rowdata{oligo_id} = $oligo_id;
  $rowdata{oligo_type_id} = $oligo_type_id;
  $rowdata{biosequence_id} = '';
  $rowdata{start_coordinate} = '';
  $rowdata{stop_coordinate} = '';
  $rowdata{synthetic_start} = '';
  $rowdata{synthetic_stop} = '';



  ## Do special parsing depending on which genome set is being loaded
  ##  The returned hash should be ONLY what is to be loaded into the DB!
  #special_parsing(rowdata_ref=>\%rowdata,
	#	 search_tool_id=>$search_tool_id,
	#	 biosequence_set_id=>$biosequence_set_id,
	#	 sequence=>$sequence);

  ## Verify that we haven't loaded this oligo_type/oligo combination yet
  my $key = $oligo_search_id.
	$rowdata{oligo_id}.
	$rowdata{oligo_type_id}.
	$rowdata{biosequence_id}.
	$rowdata{start_coordinate}.
	$rowdata{threeprime_distance};
	#$rowdata{synthetic_start}.
	#$rowdata{synthetic_stop};

  if ( $selected_oligos{$key} ) {
	print "[WARNING]: Potential duplicate oligo loaded\n";
  }
            
  
	  
  ## INSERT the selected_oligo record
  my $selected_oligo_id = $sbeams->updateOrInsertRow(table_name=>$TBOG_SELECTED_OLIGO,
													  rowdata_ref=>\%rowdata,
													  insert=>1,
													  return_PK=>1,
													  testonly=>0,
													  verbose=>0,
													  );  ##################took out add_audit_parameters=>1
   


 


}


######################################################################
# get_oligo
######################################################################
sub get_oligo {
  my %args = @_;
  my $oligo_id;

  ## Variables
  my $SUB = "get_oligo";
  my $sequence = $args{sequence} || 
	die "[BUG-$SUB]: oligo sequence not passed\n";
  my $project_id = $args{project_id} ||
	die "[BUG-$SUB]: project_id not passed\n";

  ## Strip out any non-sequence (whitespace, numbers) characers
  $sequence =~ s/\s//g;
  $sequence =~ s/\d//g;

  my $length = length($sequence);

  ## See if there is already a matching oligo (within the project) 
  my $sql = qq~
   SELECT O.oligo_id
     FROM $TBOG_OLIGO O
LEFT JOIN $TBOG_OLIGO_ANNOTATION OA ON (O.oligo_id = OA.oligo_id)
    WHERE O.sequence_length = '$length'
      AND O.feature_sequence = '$sequence'
      AND OA.project_id = '$project_id'
      AND OA.record_status != 'D'
	  ~;
  my @rows = $sbeams->selectOneColumn($sql);
  

  ## INSERT record or return an ID, based upon the returned result
  if ( scalar(@rows) > 1 ) {
	print "[WARNING]: Yikes! multiple oligos appear to have a sequence".
	  " of \'$sequence\' and a length of $length.  Using the first one.\n";
	$oligo_id = $rows[0];
  } elsif ( scalar(@rows) == 1 ) {
	$oligo_id = $rows[0];
  } else{

	## In this case, we need to INSERT the oligo record...
	my %rowdata;
	$rowdata{sequence_length} = $length;
	$rowdata{feature_sequence} = $sequence;
	$oligo_id = $sbeams->updateOrInsertRow(table_name=>$TBOG_OLIGO,
										   rowdata_ref=>\%rowdata,
										   insert=>1,
										   return_PK=>1,
										   testonly=>0,
										   verbose=>0);
	undef %rowdata;

	## ...AND INSERT the oligo_annotation record
	my %rowdata;
	$rowdata{oligo_id} = $oligo_id;
	$rowdata{project_id} = $project_id;
	$rowdata{in_stock} = 'N'; #default is it's not in stock
	$sbeams->updateOrInsertRow(table_name=>$TBOG_OLIGO_ANNOTATION,
							   rowdata_ref=>\%rowdata,
							   insert=>1,
							   testonly=>0,
							   verbose=>0);
  }
  return $oligo_id;
}
