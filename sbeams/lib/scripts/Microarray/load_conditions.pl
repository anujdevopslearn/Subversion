#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_array_elements.pl
# Author      : Michael Johnson <mjohnson@systemsbiology.org>
#
# Description : This script goes to the appropriate directory to search for
#               .sig/.merge files and subsequently loads the condition
#               and corresponding data into SBEAMS.  Sorry for the horrible use
#               of global variables!
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET $DEBUG $DATABASE $TESTONLY
						 $PROJECT_ID $current_contact_id $current_username 
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::TableInfo;
$sbeams = SBEAMS::Connection->new();

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME --project_id n [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag
    --project_id <num> Set project_id. 'all' is an option.  This is required.
    --directory <path> Set directory that contains data files.  Default is the
                       project directory in: 
                       /net/arrays/Pipeline/output/project_id/
    --file_name <name> Set a single file to be uploaded
		--set_tag <name>   Determines which biosequence set to use when populating
                       the gene_expression table
    --testonly         Information in the database is not altered
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:i","quiet","debug:i",
  "project_id:s","directory:s","file_name:s","set_tag:s","testonly")) {
  print "$USAGE";
  exit;
}

$PROJECT_ID = $OPTIONS{project_id} || die "ERROR: project_id MUST be specified!\n";
$VERBOSE    = $OPTIONS{verbose} || 0;
$QUIET      = $OPTIONS{quiet};
$DEBUG      = $OPTIONS{debug};
$TESTONLY   = $OPTIONS{testonly};

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $OPTIONS{verbose}\n";
  print "  QUIET = $OPTIONS{quiet}\n";
  print "  DEBUG = $OPTIONS{debug}\n";
  print "  PROJECT_ID = $OPTIONS{project_id}\n";
  print "  DIRECTORY = $OPTIONS{directory}\n";
  print "  FILE_NAME = $OPTIONS{file_name}\n";
  print "  TESTONLY = $OPTIONS{testonly}\n";
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

  #### Try to determine which module we want to affect
  my $module = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ($module eq 'Microarray') {
    $work_group = "Microarray_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Proteomics') {
    $work_group = "${module}_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Biosap') {
    $work_group = "Biosap";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'SNP') {
    $work_group = "SNP";
    $DATABASE = $DBPREFIX{$module};
  }

  ## Presently, force module to be microarray
  if ($module ne 'Microarray') {
      print "WARNING: Module was not Microarray.  Resetting module to Microarray\n";
      $work_group = "Microarray_admin";
      $DATABASE = $DBPREFIX{$module};
  }

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>$work_group,
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  # HACK - to load all conditions, for all projects, we simply change PROJECT_ID
  if ($PROJECT_ID eq 'all') {
      my @directories = glob("/net/arrays/Pipeline/output/project_id/base_directory/*");
      foreach my $directory (@directories) {
	  $PROJECT_ID = $directory;
	  $PROJECT_ID =~ s(^.*/)();
	  handleRequest();

      }
  }else {
      handleRequest();
  }
  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest { 
  my %args = @_;

  #### Define standard variables
  my ($sql, @rows);
	my (%final_hash);
	
  #### Set the command-line options
  my $directory = $OPTIONS{'directory'} || "/net/arrays/Pipeline/output/project_id/$PROJECT_ID";
  my $file_name = $OPTIONS{'file_name'};
  my $set_tag = $OPTIONS{'set_tag'};
  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }
  
  ## If set_tag is set, get biosequences
  if ($set_tag) {
      $sql = qq~
	  SELECT BS.biosequence_id, BS.biosequence_name, BS.biosequence_gene_name
	  FROM biosequence BS
	  LEFT JOIN biosequence_set BSS ON (BSS.biosequence_set_id = BS.biosequence_set_id)
	  WHERE BSS.set_tag = '$set_tag'
	  and BS.record_status != 'D'
	  ~;
      @rows = $sbeams->selectHashArray($sql);
      ## make the final hash
      foreach my $temp_row (@rows) {
	  my %temp_hash = %{$temp_row};
	  $final_hash{$temp_hash{'biosequence_gene_name'}} = $temp_hash{'biosequence_id'};
	  $final_hash{$temp_hash{'biosequence_name'}} = $temp_hash{'biosequence_id'};
      }
      
#		#### Print hash for testing
#		my @keys = keys %final_hash;
#		my @values = values %final_hash;
#		my $counters = 0;
#		while(@keys && $counters <10) {
#				print (pop(@keys), '=', pop(@values), "\n");
#				$counters++;
#		}
      
  }
  
  
  ## Try to find .sig (SAM output) files first
  my @sig_files = glob("$directory/*\.sig");
  if (@sig_files > 0) {
      foreach my $sig_file (@sig_files) {
	  $sig_file =~ s(^.*/)();
	  $sig_file =~ /(.*)\.sig$/;
	  my $condition = $1;
	  my $processed_date = getProcessedDate(file=>"$directory/$sig_file");
	  my $condition_id;
	  
	  ##See if condition already exists in the database
	  $sql = qq~
	      SELECT condition_id
	      FROM condition
	      WHERE condition_name = '$condition'
	      AND record_status != 'D'
	      ~;
	  @rows = $sbeams->selectOneColumn($sql);
	  my $n_rows = @rows;
	  
	  if ($n_rows < 1) {
	      print "->INSERTing $condition\n";
	      $condition_id = insertCondition(insert=>1,
					      processed_date=>$processed_date,
					      condition=>$condition);
	  }else {
	      print "->UPDATEing $condition\n";
	      $condition_id = insertCondition(update=>1,
					      processed_date=>$processed_date,
					      condition=>$condition,
					      condition_id=>$rows[0]);
	  }
	  if ($set_tag){
	      insertGeneExpression(condition_id=>$condition_id,
				   source_file=>"$directory/$sig_file",
				   id_hash=>\%final_hash);
	  }else {
	      insertGeneExpression(condition_id=>$condition_id,
				   source_file=>"$directory/$sig_file");
	  }
      }
  }else {
      if ($VERBOSE > 0) {
	  print "\n->No .sig files were found:  now searching for .all.merge files\n";
      }
      my @merge_files = glob("$directory/*\.all\.merge");
      foreach my $merge_file (@merge_files) {
	  $merge_file =~ s(^.*/)();
	  $merge_file =~ /(.*)\.all\.merge$/;
	  my $condition = $1;
	  my $processed_date = getProcessedDate("$directory/$merge_file");
	  my $condition_id;
	  
	  ##See if condition already exists in the database
	  $sql = qq~
	      SELECT condition_id
	      FROM condition
	      WHERE condition_name = '$condition'
	      AND record_status != 'D'
	      ~;
	  @rows = $sbeams->selectOneColumn($sql);
	  my $n_rows = @rows;
	  
	  if ($n_rows < 1) {
	      print "->INSERTing $condition\n";
	      $condition_id = insertCondition(insert=>1,
					      processed_date=>$processed_date,
					      condition=>$condition);							
	  }else {
	      print "->UPDATEing $condition\n";
	      $condition_id = insertCondition(update=>1,
					      processed_date=>$processed_date,
					      condition=>$condition,
					      condition_id=>$rows[0]);
	  }
	  
	  if ($set_tag){
	      insertGeneExpression(condition_id=>$condition_id,
				   source_file=>"$directory/$merge_file",
				   id_hash=>\%final_hash);
	  }else {
	      insertGeneExpression(condition_id=>$condition_id,
				   source_file=>"$directory/$merge_file");
	  }
      }
  }
  return;
}

###############################################################################
# getProcessedDate
###############################################################################
sub getProcessedDate {
    my $SUB_NAME="getProcessedDate";
    my %args= @_;
    my $file = $args{'file'};
    #### Get the last modification date from this file
    my @stats = stat($file);
    my $mtime = $stats[9];
    my $source_file_date;
    if ($mtime) {
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime($mtime);
	$source_file_date = sprintf("%d-%d-%d %d:%d:%d",
				    1900+$year,$mon+1,$mday,$hour,$min,$sec);
	if ($VERBOSE > 0){print "INFO: source_file_date is '$source_file_date'\n";}
    }else {
	$source_file_date = "CURRENT_TIMESTAMP";
	print "WARNING: Unable to determine the source_file_date for ".
	    "'$file'.\n";
    }
    return $source_file_date;
}


###############################################################################
# insertCondition
###############################################################################
sub insertCondition {
    my $SUB_NAME = "insertCondition";
    my %args = @_;
    my $condition = $args{'condition'};
    my $insert = $args{'insert'} || 0;
    my $update = $args{'update'} || 0;
    my $condition_id = $args{'condition_id'};
    my $processed_date = $args{'processed_date'};
    my (%rowdata, $rowdata_ref,$pk);
    
    if ($insert + $update != 1){
	die "ERROR[$SUB_NAME]:You need to set insert OR update to 1\n";
    }
    if($update == 1 && !defined($condition_id)){
	die "ERROR[$SUB_NAME]:UPDATE requires update and condition_id flag\n";
    }
    
    if ($insert == 1) {
	$rowdata{'condition_name'} = $condition;
	$rowdata{'project_id'} = $PROJECT_ID;
	$rowdata{'processed_date'} = $processed_date;
	$rowdata_ref = \%rowdata;
	$pk = $sbeams->updateOrInsertRow(table_name=>'condition',
					 rowdata_ref=>$rowdata_ref,
					 return_PK=>1,
					 verbose=>$VERBOSE,
					 testonly=>$TESTONLY,
					 insert=>1,
					 add_audit_parameters=>1);
    }elsif ($update == 1) {
	$rowdata{'condition_name'} = $condition;
	$rowdata{'project_id'} = $PROJECT_ID;
	$rowdata{'processed_Date'} = $processed_date;
	$rowdata_ref = \%rowdata;
	$pk  = $sbeams->updateOrInsertRow(table_name=>'condition',
					  rowdata_ref=>$rowdata_ref,
					  return_PK=>1,
					  verbose=>$VERBOSE,
					  testonly=>$TESTONLY,
					  update=>1,
					  PK=>'condition_id',
					  PK_value=>$condition_id,
					  add_audit_parameters=>1);
    }
    return $pk;
}		


###############################################################################
# insertGeneExpression
###############################################################################
sub insertGeneExpression {
    my $SUB_NAME = "insertGeneExpression";
    my %args = @_;
    my $condition_id = $args{'condition_id'} 
    || die "ERROR[$SUB_NAME]: condition_id must be set\n";
    my $source_file = $args{'source_file'};
    my $id_hash_ref = $args{'id_hash'};
    my $set_tag = $OPTIONS{'set_tag'};
    my $current_contact_id = $sbeams->getCurrent_contact_id();
    my ($sql, @rows);
    
    ## See if there are gene_expression entries with the specified id. DELETE, if so.
    ## NEEDS WORK
    $sql = qq~
	SELECT gene_expression_id
	FROM gene_expression
	WHERE condition_id = '$condition_id'
	~;
    @rows = $sbeams->selectOneColumn($sql);
    
    if ($VERBOSE > 0) {
	print "Records exist for this condition.  Will DELETE them, then re-INSERT\n";
    }
    foreach my $gene_expression_id (@rows){
	$sql = "DELETE FROM gene_expression WHERE gene_expression_id='$gene_expression_id'";
	$sbeams->executeSQL($sql);
    }
    
    ## Define Column Map
    my ($gene_name_column,$second_name_column,%column_map)= findColumnMap(source_file=>$source_file);
    my %transform_map = ('1000'=>sub{return $condition_id;});
    
    #### Execute $sbeams->transferTable() to update contact table
    #### See ./update_driver_tables.pl
    if ($TESTONLY) {
	print "\n$TESTONLY- TEST ONLY MODE\n";
    }
    print "\nTransferring $source_file -> array_element";
    $sbeams->transferTable(source_file=>$source_file,
			   delimiter=>'\s+',
			   skip_lines=>'2',
			   dest_PK_name=>'gene_expression_id',
			   dest_conn=>$sbeams,
			   column_map_ref=>\%column_map,
			   transform_map_ref=>\%transform_map,
			   table_name=>'gene_expression',
			   insert=>1,
			   verbose=>$VERBOSE,
			   testonly=>$TESTONLY,
			   );
    
    ## Insert biosequences, if set_tag was specified
    if ($set_tag && $id_hash_ref) {
	my %id_hash = %{$id_hash_ref};
	$sql = qq~
	    SELECT GE.gene_name, GE.second_name, GE.gene_expression_id
	    FROM gene_expression GE
	    WHERE GE.condition_id = '$condition_id'
	    ~;
	@rows = $sbeams->selectHashArray($sql);
	
	my %ge_hash;
	
	## make the final hash
	foreach my $temp_row (@rows) {
	    my %temp_hash = %{$temp_row};
	    $ge_hash{$temp_hash{'gene_name'}} = $temp_hash{'gene_expression_id'};
	    $ge_hash{$temp_hash{'second_name'}} = $temp_hash{'gene_expression_id'};
	}
	
	
	## For each gene_expression record, try to find a corresponding biosequence
	while ( my($key,$value) = each %ge_hash ){
	    my $result =  $id_hash{$key};
	    if ($result){
		print "UPDATEing $key\n";
		my $ge_id = $value;
		my %rowdata;
		$rowdata{'biosequence_id'} = $result;
		my $rowdata_ref = \%rowdata;
		$sbeams->updateOrInsertRow(table_name=>'gene_expression',
					   rowdata_ref=>$rowdata_ref,
					   return_PK=>0,
					   verbose=>$VERBOSE,
					   testonly=>$TESTONLY,
					   update=>1,
					   PK=>'gene_expression_id',
					   PK_value=>$ge_id);
	    }
	}
	close(INFILE);
    }
}


###############################################################################
# findColumnMap
###############################################################################
sub findColumnMap {
  my %args = @_;
  my $SUB_NAME = "findColumnMap";

  #### Decode the argument list
  my $source_file = $args{'source_file'} 
  || die "no source file passed in find_column_hash";
  
  #### Open file and  make sure file exists
  open(INFILE,"$source_file") || die "Unable to open $source_file";

  #### Check to make sure file is in the correct format
  my ($line,$element,%column_hash, @column_names);
  my $n_columns = 0;

	print "Opening $source_file\n";
  while ($n_columns < 1){
    $line = <INFILE>;
		$line =~ s/\#//;
    chomp($line);
    @column_names = split '\s+', $line;
    $n_columns = @column_names;
  }
  close(INFILE);

  #### Go through the elements and see if they match a database field
  my $counter = 0;
	my ($gene_name_column, $second_name_column);
  foreach $element (@column_names) {
      if ( $element =~ /^GENE_NAME/ ) {
	  $column_hash{$counter} = 'gene_name';
#					print "gene_name at column $counter\n";
	  $gene_name_column = $counter;
      }
      elsif ( $element =~ /^DESCRIPT\./ ) {
	  $column_hash{$counter} = 'second_name';
#					print "second_name at column $counter\n";
	  $second_name_column = $counter;
      }
      elsif ( $element =~ /^RATIO/ ) {
	  $column_hash{$counter} = 'log10_ratio';
#					print "log10_ratio at column $counter\n";
      }
      elsif ( $element =~ /^STD$/ ) {
	  $column_hash{$counter} = 'log10_std_deviation';
#					print "log10_std_deviation at column $counter\n";
      }
      elsif ( $element =~ /^lambda/) {
	  $column_hash{$counter} = 'lambda';
#					print "lambda at column $counter\n";
      }
      elsif ( $element =~ /^mu_X/ ) {
	  $column_hash{$counter} = 'mu_X';
#					print "mu_x at column $counter\n";
      }
      elsif ( $element =~ /^mu_Y/ ) {
	  $column_hash{$counter} = 'mu_Y';
#					print "mu_y at column $counter\n";
      }
      $counter++;
  }
  
  ## add column 1000 to store biosequence_id
  $column_hash{'1000'} = 'condition_id';
  
  return ($gene_name_column, $second_name_column, %column_hash);
}
