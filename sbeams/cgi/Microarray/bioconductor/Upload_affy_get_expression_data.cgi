#!/tools/bin/perl -w

###############################################################################
# Program     : Upload_affy_get_expression_data
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This program that allows users to
#               upload data into the get expression table
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

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use POSIX;
use FileManager;
use Batch;
use BioC;
use Site;
use strict;
use Data::Dumper;
use File::Basename;
$Data::Dumper::Pad = "<br>";
$Data::Dumper::Pair = "<br><br>";

$| = 1;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../../../lib/perl";

use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username $affy_o
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME $PROJECT_ID
             @MENU_OPTIONS);

use SBEAMS::Connection qw($log $q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::Affy_Analysis;

use Data::Dumper;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$affy_o = new SBEAMS::Microarray::Affy_Analysis;
$affy_o->setSBEAMS($sbeams);


# Create the global FileManager instance
our $fm = new FileManager;



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
$TESTONLY   = $OPTIONS{testonly};
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $OPTIONS{testonly}\n";
print "OBJECT TYPES 'sbeamMOD' = " .ref($sbeams). "\n";
print Dumper($sbeams);
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
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
  exit unless ($current_username = $sbeams->Authenticate(
    permitted_work_groups_ref=>['Microarray_user','Microarray_admin','Admin'],
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
  ));
 
  if ($q->param('token') ) {
    my $token = $q->param('token');
    
	if ($fm->init_with_token($BC_UPLOAD_DIR, $token)) {
	    error('Upload session has no files') if !($fm->filenames > 0);
	} else {
	    error("Couldn't load session from token: ". $q->param('token')) if
	        $q->param('token');
	}
  }
#grab the project Id from the database given the token.  Do not default to the current sbeams project since 
#it could be different
  $PROJECT_ID =  $affy_o->find_analysis_project_id($q->param('token'));
  
  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if (defined($parameters{'Upload Conditions'}) && $parameters{'Upload Conditions'} eq "Upload Conditions") {
   $sbeamsMOD->printPageHeader(minimal_header=> 'YES', navigation_bar=>'NO');
    	upload_files(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
    
  } else {
    $sbeamsMOD->printPageHeader();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
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
  my $apply_action=$parameters{'action'} || $parameters{'apply_action'} || '';
  my $TABLE_NAME = $parameters{'QUERY_NAME'};


  #### Set some specific settings for this program
  my $CATEGORY="Get Expression Values";
  $TABLE_NAME="MA_GetExpression" unless ($TABLE_NAME);
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


	my %args = @_;
	my $analysis_name_type = $args{analysis_name_type};
	my $warning_flag = 0;
	
	my @filenames = $fm->filenames();
	my @condition_names = $q->param('condition_name');
	my @condition_ids = $q->param('condition_ids');
	my $token = $fm->token();
	$log->debug("ALL CONDITION NAMES '@condition_names'");
	#print "PATH '" . $fm->path(). "<br>";
	#print "FILES '@filenames'<br>";
	
###Print out table to control which conditions should be added to the database	
	print "<table>", 
	       Tr(td({-class=>'rev_gray'},["&nbsp;", "File Name", "Condition Name", "Upload File"])),
	       start_form(), 
	       hidden('token', $fm->token);
	my @all_condition_ids = ();
	my $file_count = 0;
	foreach my $file (@filenames) {
		
		next unless ($file =~ /(mt-.+?_(.+?))\.(full_txt)$/);
		my $file_root = $1;
		my $condition_name = $2;
		my $ext = $3;	
		
		my $condition_id = '';
##If the user changed the name use the new name instead of the one parsed from the name above
		
		if (defined $condition_names[$i]){
			$log->debug("TAKEING CONDITION NAME FROM param NEW NAME '$condition_names[$file_count]'");
			$condition_name = $condition_names[$file_count];
			
		}
		$file_count ++;
		
		$log->debug("CONDITION NAME = '$condition_name'  ");
		
		#return the condition id or zero for ones that do not exists
		$condition_id = check_for_condition($condition_name);
		
		my $checked_flag = $condition_id ? 0:1;
##If the condition exists in the db send out a big fat warning else show "Upload"
		my $condition_warning = $condition_id ?
		"<h3 align='center'>Warning </h3>This condition all ready exists in the database.  
		If you want to delete the old data Check the box and continue the upload<h3>" :
		"Upload";
		my $warning_bg = $condition_id?'orange_bg':'grey_bg';
		$warning_flag = $warning_bg eq 'orange_bg'? 1:0;
		push @all_condition_ids , $condition_id;
		
		
		print 
			Tr(
			td({-class=>$warning_bg}, $condition_warning),
			td($q->textarea(-name=>"file_name",
                            -default=>$file,
                            -override=>1,
                            -rows=>2,
	             			  -columns=>40,
                            -STYLE=>"background-color:CCCCCC",
                            -onFocus=>"this.blur()" )),
	             
	             td(textarea(-name=>'condition_name', 
	             			  -default=>$condition_name, 
	             			  -rows=>2,
	             			  -columns=>40,
	             			  -override=>1
	             			  )
	              ),
	          	 td($q->checkbox(-name=>'upload_condition_cb',
	          	 				 -checked=>$checked_flag, 
	          	 				 -label=>'', 
	          	 				 -value=>'YES'
	          	 				 )
	          	 ),
	          );
	}
	
	print "</table>",
		  $q->hidden(-name=>'condition_ids', 
		  			 -default=>\@all_condition_ids,
		  			 -override=>1), 
		  p(submit("Upload Conditions")),
	 	  p(submit("Check Condition Names")),
	 	  end_form;

	if ($warning_flag) {
		print br,p({-class => 'orange_bg'}, "To preserve the data already in the database please change the name and 
		for files with a warning label.  To check if the name is unique click to Check Condition Names button");
	}else{
		print br,p({-class => 'grey_bg'}, 
		"Any of the condition names may be changed.<br>
		If you do change a name a name, please click <br>
		the Check Condition Name button to see if the<br>
		new name is unique or not");
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
# getConditionNames: return a hash of the conditions  XXXXXXXXXXXXX    NOT NEEDED
#         names of the supplied list of id's.
#         This might need to be more complicated if condition names
#         are duplicated under different projects or such.
###############################################################################
sub getConditionNames {
  my $condition_ids = shift || die "getConditionNames: missing condition_ids";

  #my @condition_ids = split(/,/,$condition_ids);

  #### Get the data for all the specified condition_ids
  my $sql = qq~
      SELECT condition_id,condition_name
        FROM $TBMA_CONDITION
       WHERE condition_id IN ( $condition_ids )
  ~;
  my %hash = $sbeams->selectTwoColumnHash($sql);

  return %hash;

} # end getConditionNames


###############################################################################
# upload_files
###############################################################################
sub upload_files {
  	my %args = @_;
  	my %parameters = %{ $args{ref_parameters} };
  
  	my @files 		    = $q->param('file_name');
	my @condition_names = $q->param('condition_name');
	my @checked_files   = $q->param('upload_condition_cb');
	my @condition_ids 	= $q->param('condition_ids');
	
	my $file_path = $fm->path();
	unless(@files){
		print "<h3>Sorry No files were selected</h3>";
		return;
	}
	
	my $file_count = scalar @files;
	my $estimated_wait = 2 * $file_count;
	
	#Using the print header methods will make a huge table containg the header, navigation tabs and any
	#data that we will print out and since this is a long running method IE will not show the page until every thing is
	#done which is not what we want.  So print a end table tag to stop the "master" table and print out our data so the 
	#user will get some feed back
	#print "</table></table>";
	print "<table>
			  <tr>
			    <td class='orange_bg' colspan='2'>
			    Warning: The upload could take at least 2 minutes per file.<br> 
			    Estimated wait <font color='red'>$estimated_wait</font> mins.	
				</td>
			  </tr>
		   </table>";

	my $organism_id 	= '';
	my $ogranism_name 	= '';
	for (my $i=0; $i <= $#files ; $i++){
		
		
		next unless($checked_files[$i] eq 'YES');
		my $file = $files[$i];
		my $condition_id = $condition_ids[$i];
		my $condition_name = $condition_names[$i];
		my $full_file_path = "$file_path/$file";
		print qq~<table>
				<tr>
			      <td class='grey_bg'>Starting to upload</td>
		         <td>$file</td>
		         </tr>
		        </table>
		 		~;
		 print qq~<table>
		         <tr>
		          <!-- Blank Cell to hold any print message output during the upload process -->
		          <td>
		         ~;
		
		my $column_map_ref = getColumnMapping(source_file=>"$full_file_path");
		
		my $processed_date = getProcessedDate(file=>"$full_file_path");
		
	## We need to record the organism id in the condition table, go find the info....
	##Warning: Going to assume that only one type of chip, at least one species, will be used in 
	## this analysis session. Therfore we only need to do this once to find the organism
		if ($i == 0) {
			my $analysis_info = $affy_o->return_analysis_description( folder_name=>$fm->token() );
			
			my @root_file_names = ();
			my @organism_ids 	= ();
			my @organism_names 	= ();
		
			if($analysis_info){
			
				@root_file_names = $affy_o->parse_file_names_from_analysis_description(analysis_description =>$analysis_info);
			}
			if (defined $root_file_names[0]){
				@organism_ids = $affy_o->find_organism_id_from_file_root(file_names_aref=>\@root_file_names);
			}
			if ($organism_ids[0] =~ /^\d/){
				@organism_names = $affy_o->find_organism_name_form_ids(organism_id_aref => \@organism_ids);
			}
			if (scalar(@organism_names) > 1){
				print "<b class='orange_bg'>Warning There is more then one Organism within these file Will use just the first one '@organism_names'</b>";
			}
			$ogranism_name = $organism_names[0];
			$organism_id   = $organism_ids[0];
			$log->debug("
			ANALYSIS INFO '$analysis_info'\n
			ROOT FILE NAME '@root_file_names'\n
			ORG IDS '@organism_ids'\n
			ORG NAMES '@organism_names'\n
			ORGANISM NAME '$ogranism_name' ORG ID '$organism_id'");
		}
		
		$condition_id = insertCondition(processed_date=>$processed_date,
									  condition=>$condition_name,
									  condition_id=>$condition_id,
									  organism_id =>$organism_id,);
	
		$log->debug("CONDITION ID '$condition_id'");

		my $upload_file_name = make_cononical_name_file( source_file=>"$full_file_path",
													     organism_name	 => "$ogranism_name",);
		
		insertGeneExpression(condition_id=>$condition_id,
						   column_map_ref=>$column_map_ref,
						   source_file=>"$upload_file_name",
						   #id_hash=>$bs_hash_ref,
						   delimiter => "\t");
		
		print "	</td>
			   </tr>
			   <tr>
			   	<td><b>Upload Done</b></td>
			   </tr>
			  </table><br>";	#end the html row for each file
	}
	
	print "<b>Go to Get Expression Page <a href='$CGI_BASE_DIR/Microarray/GetExpression'>here</a></b>";
	
	
	#print Dumper(\%parameters);
  
  
}

###############################################################################
## check_files
## Check to see if files to be upload allready have a condition in the db.
## If so make a page to allow the user to re-upload the files (stomping) the data in the db
## Return 1 if files exists else return 0 if condition name does not exists in db
###############################################################################
sub check_files {
  	my %args = @_;
  	
  	my %parameters = %{ $args{ref_parameters} };
  
	my @files 		    = $q->param('file_name');
	my @condition_names = $q->param('condition_name');
	my @checked_files   = $q->param('upload_condition_cb');
	my @stomp_file		= $q->param('stomp_previous');
	
	my @all_files = ();
	my @all_condition_names =();
	
	my $html = '';
	
	

	

}
###############################################################################
# check_for_condition
#Query for a condition id 
#retrun id if present else return 0
###############################################################################
sub check_for_condition {
  my $condition_name = shift;
  #### Get the data for all the specified condition_ids
  my $sql = qq~
      SELECT condition_id
        FROM $TBMA_CONDITION
       WHERE condition_name like '$condition_name' 
  ~;
  my ($condition_id) = $sbeams->selectOneColumn($sql);
  
  if ($condition_id){
  	return ($condition_id);
  }else{
  	return 0;
  }
  
}



###############################################################################
# getColumnMapping
#
# Make a hash mapping the file column numbers to database column names
###############################################################################
sub getColumnMapping {
	  my %args = @_;
	  my $SUB_NAME = "getColumnMapping";
	
	  ## Decode the argument list
	  my $source_file = $args{'source_file'}
	  || die "no source file passed in find_column_hash";
	
	  my $file_type;
	
	  ## Open file and  make sure file exists
	  open(INFILE,"$source_file") || die "Unable to open $source_file";
	
	  ## Check to make sure file is in the correct format
	  my ($line,$element,%column_hash, @column_names);
	  my $n_columns = 0;
	
	  ## Get first line and split it by tabs
	  #print "Opening $source_file\n";
	  while ($n_columns < 1){
	    $line = <INFILE>;
	    $line =~ s/\#//;
	    chomp($line);
	    @column_names = split "\t", $line;
	    $n_columns = @column_names;
	  }
	close(INFILE);
	
	
	## Determine what type of file/organism we have
  if (!defined ($file_type)){
    if   ($line =~ /FDR/) {
	  $file_type = "fdr_map";
	}elsif($line =~ /Adjusted p-value/) {
	  $file_type = "t_test_map";
	}elsif( $line =~ /Log_2_Expression_Ratio/){
		$file_type = "ratios_only_map";
  	}else {
	  $log->error("File column mapping is not recognized for file '$source_file'\n");
	  die ("Error: cannot recognize file type from the files column headers.  Please report this error");
	}
  }

  print "# Will load file according to $file_type scheme\n";

  ## Get appropriate mapping of column headers to database fields
  my $header_hash_ref = getHeaderHash (file_type=>$file_type);
 
  my %header_hash = %{$header_hash_ref};
	


  ## Move through column headings and map headers to column numbers
  my $counter = 0;
  foreach my $header (@column_names) {
    foreach my $key (keys %header_hash) {
      #Allow the header hash key to 
      #$log->debug("HEADER '$header' KEY '$key'");
      if ($key =~ /^$header/){
	  	$column_hash{$counter} = $header_hash{$key};
      }
    }
    $counter++;
  }

  ## add column 1000 to store biosequence_id
  $column_hash{'1000'} = 'condition_id';

  return (\%column_hash);
}


###############################################################################
# getProcessedDate
#
# Given a file name, the associated timestamp is returned
###############################################################################
sub getProcessedDate {
    my %args= @_;
    my $SUB_NAME="getProcessedDate";

    my $file = $args{'file'};

## Get the last modification date from this file
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
#
# Given a condition name (and condition_id, if available), a record will be 
# INSERTed or UPDATEd in the condition table
###############################################################################
sub insertCondition {
    my %args = @_;
    my $SUB_NAME = "insertCondition";

## Define local variables
    my $condition = $args{'condition'};
    my $condition_id = $args{'condition_id'};
    my $processed_date = $args{'processed_date'};
    my $organism_id	   = $args{'organism_id'};
    my (%rowdata, $rowdata_ref,$pk);
    my ($insert, $update) = 0;
$log->debug("ORGANISM_ID ID '$organism_id'");
    ($condition_id) ? $update = 1 : $insert = 1;

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
	$rowdata{'organism_id'} = $organism_id;
	$rowdata_ref = \%rowdata;
	$pk = $sbeams->updateOrInsertRow(table_name=>$TBMA_CONDITION,
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
	$rowdata{'organism_id'} = $organism_id;
	$rowdata_ref = \%rowdata;
	$pk  = $sbeams->updateOrInsertRow(table_name=>$TBMA_CONDITION,
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
  my %args = @_;
  my $SUB_NAME = "insertGeneExpression";

  ## Define local variables
  my $condition_id = $args{'condition_id'} 
  || die "ERROR[$SUB_NAME]: condition_id must be set\n";
  my $source_file = $args{'source_file'};
  my $id_hash_ref = $args{'id_hash'};
  my $set_tag = $OPTIONS{'set_tag'};
  my $column_map_ref = $args{'column_map_ref'} 
  || die "ERROR[$SUB_NAME]:column mapping reference needs to be set\n";
  my %column_map = %{$column_map_ref};
  my $delimiter = $args{'delimiter'} || "\t";

  #### Deutsch changed.  What if the user asked from 0?  This breaks.
  #my $skip_lines = $args{'skip_lines'} || 1;
  my $skip_lines = $args{'skip_lines'};
  $skip_lines = 1 unless (defined($skip_lines));

  ## Define standard variables
  my $CURRENT_CONTACT_ID = $sbeams->getCurrent_contact_id();
  my ($sql, @rows);

  ## See if there are gene_expression entries with the specified id. DELETE, if so.
  $sql = qq~
      SELECT gene_expression_id
      FROM $TBMA_GENE_EXPRESSION
      WHERE condition_id = '$condition_id'
      ~;
  @rows = $sbeams->selectOneColumn($sql);

  if (@rows) {
    
    print "<b>Records exist for this condition.  Starting to DELETE old records</b><br>";
    
    $sql = "DELETE FROM $TBMA_GENE_EXPRESSION WHERE condition_id = '$condition_id'";
    $sbeams->executeSQL($sql);
    #print"Done Deleting Old Data<br>";
  }


  ## Define Transform Map
  my $full_name_column;
  my $common_name_column;
  foreach my $key (keys %column_map) {
    if ($column_map{$key} eq "full_name") {
      $full_name_column = $key;
    }elsif($column_map{$key} eq "common_name") {
      $common_name_column = $key;
    }
  }

  my %transform_map = ('1000'=>sub{return $condition_id;},
					   $full_name_column=>sub{return substr shift @_ ,0,1024;}, 
					   $common_name_column=>sub{return substr shift @_,0,255;},
					   );

  ## For debugging purposes, we can print out the column mapping
  if ($VERBOSE > 0) {
    print "\n Column Mapping for $source_file:\n";
    while ( (my $k,my $v) = each %column_map ) {
      if (ref($v) eq "ARRAY"){
	foreach my $t (@{$v}) {
	  print "$k => $t\n";
        }
      }else {
	print "$k => $v\n";
      }
    }
  }
  
  if ($TESTONLY) {
    print "\n$TESTONLY- TEST ONLY MODE\n";
  }
  print "\nTransferring $source_file -> gene_expression";
  $sbeams->transferTable(source_file=>$source_file,
						 delimiter=>$delimiter,
						 skip_lines=>$skip_lines,
						 dest_PK_name=>'gene_expression_id',
						 dest_conn=>$sbeams,
						 column_map_ref=>\%column_map,
						 transform_map_ref=>\%transform_map,
						 table_name=>$TBMA_GENE_EXPRESSION,
						 insert=>1,
						 verbose=>$VERBOSE,
						 testonly=>$TESTONLY,
						 );
    
  ## Insert biosequences, if set_tag was specified
  if ($set_tag && $id_hash_ref) {
    my %id_hash = %{$id_hash_ref};
    $sql = qq~
	SELECT GE.gene_name, GE.second_name, GE.gene_expression_id
	FROM $TBMA_GENE_EXPRESSION GE
	WHERE GE.condition_id = '$condition_id'
	~;
    @rows = $sbeams->selectHashArray($sql);

    my %ge_hash;

    ## make the final hash
    foreach my $temp_row (@rows) {
      my %temp_hash = %{$temp_row};
      $ge_hash{$temp_hash{'gene_name'}} = $temp_hash{'gene_expression_id'};
      $ge_hash{$temp_hash{'canonical_name'}} = $temp_hash{'gene_expression_id'};
    }

    ## For each gene_expression record, try to find a corresponding biosequence
    while ( my($key,$value) = each %ge_hash ){
      my $result =  $id_hash{$key};
      if ($result){
	if ($VERBOSE > 0) {
	  print "UPDATEing $key\n";
        }
	my $ge_id = $value;
	my %rowdata;
	$rowdata{'biosequence_id'} = $result;
	my $rowdata_ref = \%rowdata;
	$sbeams->updateOrInsertRow(table_name=>$TBMA_GENE_EXPRESSION,
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
# getHeaderHash
#
# Returns a hash mapping of column headers to fields in the database
#
###############################################################################
sub getHeaderHash {
  my %args = @_;
  my $SUB_NAME = "getHeaderHash";
  my $file_type = $args{'file_type'} || "generic";
  my %hash;

  if ($file_type eq "fdr_map") {
    %hash = ("Probe_set_id"  => ['reporter_name','gene_name'],
				"Gene_Symbol"   => 'common_name',
				"Gene_Title"    => 'full_name',
				Unigene         => 'external_identifier',
				LocusLink       => 'second_name',
				"Public_ID"     => 'canonical_name',
				FDR             => 'false_discovery_rate',
				Log_10_Ratio    => 'log10_ratio',
				
    
	     );
  }elsif ($file_type eq "t_test_map") {
    %hash = (	"Probe_set_id"  => ['reporter_name','gene_name'],
    			"Gene_Symbol"   => 'common_name',
				"Gene_Title"    => 'full_name',
				Unigene         => 'external_identifier',
				LocusLink       => 'second_name',
				"Public_ID"     => 'canonical_name',
				"Adjusted p-value" => 'p_value',
				Log_10_Ratio    => 'log10_ratio',
				
			 );
  }elsif($file_type eq "ratios_only_map"){
  	%hash = (	"Probe_set_id"  => ['reporter_name','gene_name'],
    			"Gene_Symbol"   => 'common_name',
				"Gene_Title"    => 'full_name',
				Unigene         => 'external_identifier',
				LocusLink       => 'second_name',
				"Public_ID"     => 'canonical_name',
				"Log_10_Expression_Ratio"    => 'log10_ratio',
				
			 );
  }else{
  	$log->error("Unrecognized file type '$file_type' for getHeaderHash");
  	die "Error: Could not find conversion hash for file type '$file_type'";
  }
  ## Add Universal hash mappings for all files
  $hash{'mu_X'} = 'mu_x';
  $hash{'mu_Y'} = 'mu_y';
  return \%hash;
};

###############################################################################
# make_cononical_name_file
#
# Need to tweak the files so we upload the "correct" cononical_name.
#Currently the column Public_ID derived from the affy annotation file "Representative Public ID" 
#is uploaded in to gene_expression cononical name field.  
#Affy usually give a DNA genbank accession number but the perfered value would be 
#the Ref Seq Protein ID then Locuslink id and finally we will use the Public_ID if nothing else can
#be found.  This will allow matching to other data sets in the Get expression cgi page and 
#mathcing to GO annotation sets......
#
###############################################################################
sub make_cononical_name_file {
  my %args = @_;
 
													  	
  my $file = $args{'source_file'};
  my $organism_name = $args{'organism_name'};


#if this is a yeast chip do not touch the data use the default ORF names
  if ($organism_name =~ /Yeast/i){
  	return $file;
  }
  
  open DATA, "$file" ||
  	die "Cannot open data file for reading $file $!";
  	
  	my @all_data = ();
  	my $count = 0;
  	my @header = ();
  	my %header_h = ();
  	while (<DATA>){
  		my @columns = split /\t/, $_;
  		
  	##Grab the header column
  		if ($count == 0){
  			push @all_data, ( join "\t", @columns);
  			@header = @columns;
  			for (my $i=0; $i <= $#columns ; $i++){
				my $column_name = $columns[$i];
				$header_h{$column_name} = $i;
			}
  			
  			$count ++;
  			next;
  		}
  		#if ($count < 5){
  		#	$log->debug(join " ** ", @columns);
  		#}
  		
  		#Remember that the column names in the analysis files do not exactlly match the names
  		#within the Affy annotation file, so be sure to use the correct name
  		my $ref_seq_id 	  = clean_id($columns[$header_h{"Refseq_protein_ID"}]);
  		my $locus_link_id = clean_id($columns[$header_h{"LocusLink"}]);
  		my $rep_seq_id	  = $columns[$header_h{"Public_ID"}];
  		
  		my $new_canonical_id = '';
  		if ($ref_seq_id =~ /^N/){#Refseq Id should start with NP_ddddd
  			$new_canonical_id = $ref_seq_id;
  		}elsif($locus_link_id =~ /^\d/){
  			$new_canonical_id = $locus_link_id;
  		}else{
  		}
  		$new_canonical_id =~ s/\W//g;	#Remove any white space
  		if ($new_canonical_id){
  			$columns[$header_h{"Public_ID"}] = $new_canonical_id;
  		}
  		
  		if ($count < 5){
  			$log->debug(join " ** ", @columns);
  		}
  		push @all_data, (join "\t", @columns);
  			
  		#########
  		##Select the new file name, and write out the data......
  		$count ++;
  		
  	}
  my($file_name, $dir, $ext) = fileparse($file);
  my $out_file = "$dir${file_name}_canonical$ext";
  $log->debug("OUT FILE '$out_file'");
  open OUT, ">$out_file" ||
  	die "ERROR:Cannot open Canonical name out file $out_file $!";
  	
  	print OUT @all_data;
  	close OUT;
  	return $out_file;
  
}
###############################################################################
# clean_id
# some affy annotation has multiuple id's in the same field seperated with ///
#
###############################################################################
sub clean_id{
	my $val = shift;
	$val =~ s!///.*!!;
	return $val;
}
	
