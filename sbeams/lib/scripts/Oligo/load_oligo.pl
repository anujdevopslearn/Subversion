#!/usr/local/bin/perl -w


######################################################################
# Program  	: load_oligo.pl
# Authors	: Patrick Mar <pmar@systemsbiology.org>,
#             Michael Johnson <mjohnson@systemsbiology.org>
#
# Other contributors : Eric Deutsch <edeutsch@systemsbiology.org>
# 
# Description : Populates the following tables in the Oligo database -
#		        oligo_parameter_set
#               oligo_search
#               selected_oligo
#               oligo
#               oligo_annotation
#
#               Future work might include update/delete_existing
#
# Last modified : 8/26/04
######################################################################


######################################################################
# Generic SBEAMS setup
######################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $q $module $work_group $USAGE %OPTIONS 
			 $QUIET $VERBOSE $DEBUG $DATABASE $TESTONLY $PROG_NAME
             $current_contact_id $current_username);

####Setup SBEAMS core module####
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

$PROG_NAME = "load_oligo.pl";

######################################################################
# Command line stuff
######################################################################
$USAGE = <<EOU;
Usage: load_oligo.pl [OPTIONS]
Options:

  ## REQUIRED parameters.  They must be set 
  --search_tool_id n     The search tool that was used to 
                          create this oligo set.
  --gene_set_tag n       The biosequence set this set of oligos 
                          belong to (ORF set)
  --chromosome_set_tag n The chromosome file
  --oligo_file           FASTA-formatted oligo file

  ## User Options
  --project_id n         (Default: current project ID)         


  ## Developer Options
  --verbose n            Set verbosity level. (Default: 0)
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --testonly             If set, rows in the database are not 
                          changed or added


 e.g.:  $PROG_NAME \
                   --search_tool_id 1 \
                   --oligo_set_type_name halo_5_oligo_knockout \
                   --gene_set_tag haloarcula_orfs \
                   --chromosome_set_tag haloarcula_genome \
                   --oligo_file haloarcula_oligos.fasta

EOU

#### Process options ####
unless (GetOptions(\%OPTIONS,
				   "search_tool_id=s",
				   "gene_set_tag=s",
				   "chromosome_set_tag=s",
				   "oligo_file=s",
				   "project_id:s",
				   "verbose:s",
				   "quiet",
				   "debug:s",
				   "testonly")){
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 1;
if($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}


######################################################################
# Set Global Variables and execute main()
######################################################################
main();
exit(0);


######################################################################
# Main:
# 
# Call $sbeams->Authenticate() and exit if it fails or continue if it 
#   works
######################################################################
sub main{

  ## Variables
  my $current_username;
  my $project_id;
  my $sql;
  my @rows;

  ## Prep Work
  $current_username = authenticate_user(); 
  $project_id = check_command_line();

  ## Handle the Task
  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest(user=>$current_username,
				project=>$project_id);
  $sbeams->printPageFooter() unless ($QUIET);
}



######################################################################
# handleRequest
######################################################################
sub handleRequest {
  my %args = @_;

  ## Variables
  my $SUB = "handleRequest";
  my $current_username = $args{user} || 
	die "[BUG-$SUB]: username not passed\n";
  my $project_id = $args{project} || 
	die "[BUG-$SUB]: project not passed\n";
  my $sql;
  my @rows;


  my $oligo_search_id;
  my $oligo_types_ref;
  $oligo_search_id = add_oligo_search_record(user=>$current_username,
											 project=>$project_id);


  $gene_biosequence_set_id = add_oligo_parameter_set_record(
     oligo_search_id=>$oligo_search_id,
     gene_set_tag=>$OPTIONS{gene_set_tag},
	 chromosome_set_tag=>$OPTIONS{chromosome_set_tag}
															);
  
  handle_oligo_file{project_id=>$OPTIONS{project_id},
					file=>$OPTIONS{oligo_file},
					search_tool_id=>$OPTIONS{search_tool_id},
					oligo_search_id=>$oligo_search_id,
					biosequence_set_id=>$gene_biosequence_set_id
					);

}



######################################################################
# handleOligoFile
######################################################################
sub handle_oligo_file {
  my %args = @_;

  ## Variables
  my $sql;
  my @rows;

  my $SUB="handle_oligo_file";
  my $oligo_file = $args{file} ||
	die "[BUG-$SUB]: oligo file not passed.\n";
  my $oligo_search_id = $args{oligo_search_id} ||
	die "[BUG-$SUB]: oligo_search_id not passed.\n";
  my $search_tool_id = $args{search_tool_id} ||
	die "[BUG-$SUB]: search_tool_id not passed\n";
  my $biosequence_set_id = $args{biosequence_set_id} ||
	die "[BUG-$SUB]: biosequence_set_id not passed.\n";
  my $project_id = $args{project_id} ||
	die "[BUG-$SUB]: project_id not passed\n";

  my %oligo_types = %{$oligo_types_ref};
  my %selected_oligos;

  ## Verify that the oligo file exists
  unless (open(INFILE,"$oligo_file")) {die("Cannot open file '$oligo_file'");}

  ## Read the file, following the example by load_biosequence_set.pl
  my $loopflag = 1;
  my ($line,$information,$sequence,$insert,$update);
  my ($biosequence_id,$biosequence_name,$biosequence_desc,$biosequence_seq);

  $information = "####";

  while ($loopflag) {

    ## At the end of file, set loopflag to 0, but finish this loop, writing
    ## the last entry to the database
    unless (defined($line=<INFILE>)) {
      $loopflag = 0;
      $line = ">BOGUS DESCRIPTION";
    }

    ## Strip CRs of all flavors
    $line =~ s/[\n\r]//g;

    ## If the line has a ">" and it's not the first, write the
    ## previous sequence to the database
    if (($line =~ />/) && ($information ne "####")) {

	  ## Get the ID of the oligo (INSERTing a record, if necessary)
	  my $oligo_id = get_oligo(project_id=>$project_id,
							   sequence=>$sequence);

	  ## INSERT the selected_oligo record
	  my %rowdata;
	  $information =~ /^(.*?)>(.*)/;
	  my $rowdata{header} = $2;
	  my $header = $2;

      ## Print a warning if malformed
      if ($1) {
		print "\nWARNING: Header line possibly malformed:\n$information\n".
		  "Ignoring all characters before >\n";
      }


	  ## Create a hash for information that we'll need.
	  $rowdata{oligo_search_id} = $oligo_search_id;
	  $rowdata{oligo_id} = $oligo_id;
	  $rowdata{oligo_type_id} = '';
	  $rowdata{biosequence_id} = '';
	  $rowdata{start_coordinate} = '';
	  $rowdata{threeprime_distance} = '';
	  $rowdata{synthetic_start} = '';
	  $rowdata{synthetic_stop} = '';


      ## Do special parsing depending on which genome set is being loaded
	  ##  The returned hash should be ONLY what is to be loaded into the DB!
      special_parsing(rowdata_ref=>\%rowdata,
					  search_tool_id=>$search_tool_id,
					  biosequence_set_id=>$biosequence_set_id,
					  sequence=>$sequence);

	  ## Verify that we haven't loaded this oligo_type/oligo combination yet
	  my $key = $oligo_search_id.
		$rowdata{oligo_id}.
		$rowdata{oligo_type_id}.
		$rowdata{biosequence_id}.
		$rowdata{start_coordinate}.
		$rowdata{threeprime_distance}.
		$rowdata{synthetic_start}.
		$rowdata{synthetic_stop};

	  if ( $selected_oligos{$key} ) {
		print "[WARNING]: Potential duplicate oligo \'$header\' loaded\n";
	  }

	  ## INSERT the selected_oligo record
	  $selected_oligo_id = $sbeams->updateOrInsertRow(table_name=>$TBOG_SELECTED_OLIGO,
													  rowdata_ref=>\%rowdata,
													  insert=>1,
													  return_PK=>1,
													  testonly=>$TESTONLY,
													  verbose=>$VERBOSE,
													  add_audit_parameters=>1);

	  $selected_oligos{$key} = $selected_oligo_id;
	  $counter++;

      ## Reset temporary holders
      $information = "";
      $sequence = "";

      ## Add this one to the list of already seen
      $biosequence_names{$rowdata{biosequence_name}} = 1;

      print "$counter..." if ($counter % 100 == 0);
    }

    #### If the line has a ">" then parse it
    if ($line =~ />/) {
      $information = $line;
      $sequence = "";

    #### Otherwise, it must be sequence data
    } else {
      $sequence .= $line;
    }

  }


  close(INFILE);
  print "\n$counter rows INSERTed\n";

}


######################################################################
# special_parsing
#
# SPECIAL HANDLING BASED UPON SEARCH TOOL
#
# Search Tool Reference and Corresponding Types
# 
# 1 => "create_halobacterium_ko.pl"
# 2 => "create_haloarcula_expr.pl"
# 3 => "create_halobacterium_expr.pl"
#
######################################################################
sub special_parsing {
  my %args=@_;
  my $SUB="special_parsing";

  my $rowdata_ref = $args{rowdata_ref} ||
	die "[BUG-$SUB]: rowdata_ref not passed\n";
  my $search_tool_id = $args{search_tool_id} ||
	die "[BUG-$SUB]: search_tool_id not passed\n";
  my $bs_set_id = $args{biosequence_set_id} ||
	die "[BUG-$SUB]: biosequence_set_id not passed\n";
  my $sequence = $args{sequence} ||
	die "[BUG-$SUB]: sequence not passed\n";

  my $header = $rowdata_ref->{header};

  ## Get search tool name, which is better than using ID
  my $sql = qq~
SELECT search_tool_name
  FROM $TBOG_SEARCH_TOOL
 WHERE search_tool_id = $search_tool_id
 ~;
  my @rows = $sbeams->selectOneColumn($sql);
  my $search_tool_name = $rows[0];
  
  ## Sample FASTA entry for:
  # "create_halobacterium_ko.pl"
  # "create_haloarcula_expr.pl"
  # "create_halobacterium_expr.pl"
  #
  #    >VNG0019H.a   100329   100439
  #    ACTGACTGactgactgactg
  # 
  # NOTE: synthetic sequence is capitalized

  if ($search_tool_name eq "create_halobacterium_ko.pl" ||
	  $search_tool_name eq "create_haloarcula_expr.pl" ||
	  $search_tool_name eq "create_halobacterium_expr.pl" ) {

	$header =~ /(\w+)\.(\w+)\s+(\d+)\s(\d+)/;
	$rowdata_ref->{start_coordinate} = $3;
	$rowdata_ref->{biosequence_id} = get_biosequence_id(name=>$1,
														set_id=>$bs_set_id);

	## Get Oligo Type
	my $type = $2;
	my $oligo_type_id;
	if ($type eq "a") {
	  $oligo_type_id = "1";
	}elsif ($type eq "b") {
	  $oligo_type_id = "2";
	}elsif($type eq "c") {
	  $oligo_type_id = "3";
	}elsif ($type eq "d") {
	  $oligo_type_id = "4";
	}elsif ($type eq "e") {
	  $oligo_type_di = "5";
	}elsif($type eq "for") {
	  $oligo_type = "6";
	}elsif($type eq "rev") {
	  $oligo_type = "7";
	}else{
	  print "[WARNING]: no oligo_type \'$type\' for oligo \'$header\'.\n";
	}

	if ($oligo_type_id){
	  $rowdata_ref->{oligo_type_id} = $oligo_type_id;
	}

	## Search sequence for capitalized (i.e. synthetic) sequence
	my ($synth_start, $synth_stop);
	my @seq = split //, $sequence;
	for (my $m=0;$m<=$#seq;$m++) {
	  if ( $seq[$m]=~/[A-Z]/) {
		$synth_start = $m;
		while ( $seq[$m++] =~ /[A-Z]/ ) {
		  $synth_stop = $m;
		}
		last;
	  }
	}

	## Load Synthetic Start/Stop Coordinates
	print "Synthetic Start = $synth_start\n";
	print "Synthetic Stop = $synth_stop\n";
	if ($synth_start && $synth_stop) {
	  $rowdata_ref->{synthetic_start} = $synth_start;
	  $rowdata_ref->{synthetic_stop} = $synth_stop;
	}

  }


KEEP FILLING ME IN!!!!


  delete($rowdata_ref->{header});

}


######################################################################
# get_biosequence_id
######################################################################
sub get_biosequence_id {
  my %args = @_;
  my $SUB="get_biosequence_id";
  my $name = $args{name} ||
	die "[BUG-$SUB]: name not passed\n";
  my $set_id = $args{bs_set_id} ||
	die "[BUG-$SUB]: bs_set_id not passed\n";

  my $sql = qq~
SELECT biosequence_id
  FROM $TBOG_BIOSEQUENCE
 WHERE biosequence_name = '$name'
   AND biosequence_set_id = '$set_id'
   ~;
  my @rows = $sbeams->selectOneColumn($sql);
  if ( scalar(@rows) == 0 ){
	print "[ERROR]: No biosequence found with name \'$name\'\n";
	exit;
  }elsif ( scalar(@rows) > 1 ) {
	print "[WARNING-$SUB]: multiple biosequence names match to $name.".
	  "Returning first one\n";
  }
  return $rows[0];
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
										   testonly=>$TESTONLY,
										   verbose=>$VERBOSE);
	undef %rowdata;

	## ...AND INSERT the oligo_annotation record
	my %rowdata;
	$rowdata{oligo_id} = $oligo_id;
	$rowdata{project_id} = $project_id;
	$rowdata{in_stock} = 'N'; #default is it's not in stock
	$sbeams->updateOrInsertRow(table_name=$TBOG_OLIGO_ANNOTATION,
							   rowdata_ref=>\%rowdata,
							   insert=>1,
							   testonly=>$TESTONLY,
							   verbose=>$VERBOSE);
  }
  return $oligo_id;
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
        testonly => 1, 
        verbose => $VERBOSE,
        add_audit_parameters => 1 );

  return $gene_library_id;
}



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
  my $search_tool_id = $OPTIONS{search_tool_id};
  my $search_id_code = get_timestamp();

  ## Populate oligo_search table
  my %rowdata = ('project_id' => $project_id,
				 'search_tool_id' => $OPTIONS{search_tool_id},
				 'search_id_code' => $search_id_code,
				 'search_username' => $current_username,
				 'search_date' => $OPTIONS{datetime},
				 'comments' => "created by load_oligo.pl");

  my $rowdata_ref = \%rowdata; 

  my $oligo_search_id = $sbeams->updateOrInsertRow(
	table_name => "$TBOG_OLIGO_SEARCH",
		print_SQL=>1,
        rowdata_ref => $rowdata_ref,
        insert => 1,
        return_PK => 1,
        testonly => 1, 
        verbose => $VERBOSE,
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
# check_command_line - verifies command line is cool
######################################################################
sub check_command_line {
  print "[STATUS]: Verifying Command Line Options...\n";

  ## Standard Variables
  my $sql;
  my @rows;

  #### Process the commmand line

  ## Required arguments
  my $search_tool_id = $OPTIONS{"search_tool_id"};
  my $gene_set_tag = $OPTIONS{"gene_set_tag"} || '';
  my $chromosome_set_tag = $OPTIONS{"chromosome_set_tag"} || '';

  unless ($search_tool_id && 
		  $oligo_set_type_name && 
		  $gene_set_tag &&
		  $chromosome_set_tag) {
	print $USAGE;
	exit;
  }

  ## Data Loading Options
#  my $delete_existing = $OPTIONS{"delete_existing"};
#  my $update_existing = $OPTIONS{"update_existing"};
#  if ( defined($delete_existing) && defined($update_existing) ) {
#	print "[ERROR]: Select delete_existing OR update_existing...not both.\n";
#	exit;
#  }elsif ( !defined($delete_existing) && !defined($update_existing) ) {
#	print "[STATUS]: INSERTing instead of UPDATEing or DELETEing\n";
#	$OPTIONS{load_option} = "insert";
#  }
#
#  if ($delete_existing){
#	print "[STATUS]: Delete Existing selected\n";
#	$OPTIONS{load_option} = "delete";
#  }else {
#	print "[STATUS]: Update Existing selected\n";
#	$OPTIONS{load_option} = "update";
#  }

  ## Data Loading Time/Date
#  if ( !defined($OPTIONS{datetime}) ) {
	$OPTIONS{datetime} = "CURRENT_TIMESTAMP";
#  } 
  my $datetime = $OPTIONS{datetime};
  print "[STATUS]: Load Date = $datetime\n";

  ## Verify the search tool and oligo set types.
  $sql = qq~
SELECT search_tool_id, search_tool_name
  FROM $TBOG_SEARCH_TOOL
 WHERE search_tool_id = '$search_tool_id'
   AND record_status != 'D'
 ~;
  @rows = $sbeams->selectSeveralColumns($sql);
  if ( scalar(@rows) == 1 ) {
	print "[STATUS]: Search Tool - $rows[0]->[1]\n";
  }else{
	print "[ERROR]: search tool not found\n";
	exit;
  }
  ## If user doesn't specify project_id, use current project_id####
  my $project_id = $OPTIONS{"project_id"} || $sbeams->getCurrent_project_id();
  
  ## Verify that the user can write to the project
  my @writable_projects = $sbeams->getWritableProjects();
  my $project_is_writable = 0;
  foreach my $proj (@writable_projects) {
	if ($proj == $project_id) {
	  $project_is_writable = 1;
	}
  }
  unless ($project_is_writable == 1) {
	print "[ERROR] project id $project_id is NOT writable.\n";
	exit;
  }

  return $project_id;

} #end check_command_line



######################################################################
#  authenticate_user - performs authentication and verification
######################################################################
sub authenticate_user {
  print "[STATUS]: Authenticating user...\n";

  #### User Authentication
  my $module = 'Oligo';
  my $work_group = 'Oligo_admin';
  $DATABASE = $DBPREFIX{$module};

  ## Exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(work_group=>$work_group));
  
  return $current_username;
}


