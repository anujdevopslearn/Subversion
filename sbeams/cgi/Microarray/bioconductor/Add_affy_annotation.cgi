#!/usr/local/bin/perl -w

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
#importTSVFile

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
my $base_out_dir = $sbeamsMOD->get_ANNOTATION_OUT_FOLDER();
my $base_html_dir ="$HTML_BASE_DIR/tmp/Microarray/Add_affy_annotation";
my $open_file_url = "$CGI_BASE_DIR/Microarray/View_Affy_files.cgi";
my @all_errors = ();
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
  #$PROJECT_ID =  $affy_o->find_analysis_project_id($q->param('token'));
  
  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);
 

  #### Decide what action to take based on information so far
  if (defined($parameters{'Upload Files'}) ) {
   	$sbeamsMOD->printPageHeader();
    	upload_files(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();

  }elsif($parameters{'merge_annotaion_files'} eq 'Merge Files'){
	$sbeamsMOD->printPageHeader();
    	merge_files(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }else {
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
	
	
	my $annotation_file_ref = read_annotation_library_dir();

 	print h2("Add Affy Annotation to a Data File"),
 		  br(),br(),
 		  h2("Select or Upload a Annotation File"),
 		  start_multipart_form(),
 		  $q->scrolling_list(-name   =>'affy_annotation_file',
 		  					 -values => $annotation_file_ref,
 		  				 	-size =>5,
 		  				),
 		  br(),
 		  b("--- or ---"),
 		  br(),
 		  $q->filefield(-name=>'user_annotation_file',
                            -size=>50,
                            -maxlength=>80),
          p("Info: Add a annotation file that contains columns of annotation data that will be 
             appended to one or many data files.<br>
             At least one column must contain affy probe ids, the other columns will be avalible for annotating
             a data file.  The file can be be comma or tab delimited but must contain column headers.
            "),
          br(),br(),
          hr(),
          h2("Upload data file to annotate"),
          br(),br(),
          $q->filefield(-name=>'user_data_file',
          					-size=>50,
                            -maxlength=>80),
          p("Info: Provide a text file to annotate.<br> 
             The file must have a header and one of the columns must be 
          	 Affy probe set ids.
            "),
             $q->submit(-name=>'Upload Files',
                        ),
             $q->end_form;
   
} # end handle_request


###############################################################################
# upload_files
#
# Check to see that we have both a valid annotation file and data files
###############################################################################
sub upload_files {
  
  my %args = @_;
  	
  my %parameters = %{ $args{ref_parameters} };
  
  our $fh_anno = '';
  our $fh_data = ''; 	
  my $anno_file = '';
  if ( $parameters{user_annotation_file} =~ /\w/ &&  $parameters{affy_annotation_file} =~ /\w/){
  	print "ERROR: You can only supply one annotation file";
  }
  
  if (exists $parameters{affy_annotation_file}){
  	$anno_file = "$AFFY_ANNO_PATH/$parameters{affy_annotation_file}";
  }
  
  if ($fh_anno = $q->upload('user_annotation_file')){
 
  }else{
  		open $fh_anno, "$anno_file" or
  			die "Cannot not find annotation file";
  }
  unless ($fh_anno){
  	print "ERROR:You need to upload an annotation file";
  }
  $log->debug("grab annotation column names");
  my %header_info = grab_file_header($fh_anno);
  my @annotation_col_names = @{ $header_info{headers_aref} };
  
  #if we have a token it means we are coming here from a bioconductor page 
  #and we will read a directory looking for data files
  #otherwise we need to make sure we hava a valid data file
  my @data_column_names = ();
  
  if ($fm->token()){
  	@data_column_names = check_for_data_files($fm->token());
  }else{
  	unless ($fh_data = $q->upload('user_data_file')){
  		die "There are no data files to Read";
  	}
  	$log->debug("parse data column names");
  	my %header_info = grab_file_header($fh_data);
  	@data_column_names = @ {$header_info{headers_aref} };
  }
  
  
  ##Save the data if we need to.  Don't save if we are coming from the bioconductor page
  
  my $anno_out_file_name = '';
  unless(exists $parameters{affy_annotation_file}){
  	$anno_out_file_name = save_file(FH=> $fh_anno,
  			  				FILE_TYPE =>"ANNOTATION",
  			 				);
  }
  
  my $data_out_file_name = '';
  unless($fm->token()){
  	$data_out_file_name = save_file(FH=> $fh_data,
  			  			  			FILE_TYPE =>"DATA",
  			  			  			COLUMN_HEADERS => \@data_column_names
  			  			  );
  }

  #now collect all the params we have so far
  my %usable_params = (token => $fm->token,
  				    anno_columns => \@annotation_col_names,
  				    data_columns => \@data_column_names,
  				    anno_out_file_name => $anno_out_file_name,
  				    data_out_file_name => $data_out_file_name,
  				   	affy_annotation_file => $parameters{'affy_annotation_file'},
  				   );
  
  make_select_columns_page(useable_params => \%usable_params);
   
}


##############################################################################
# make_select_columns_page
#
# Make a cgi page to allow the user to select the columns to annotate from
###############################################################################
sub make_select_columns_page {
	my %args = @_;
	my $usable_parms_href = $args{useable_params};
	
	print h2("Please Choose the Annotation Columns to add to the data file(s)"),
		  br(),
		  $q->start_form(),
		  $q->scrolling_list(-name=>'anno_columns',
                  			-values=>$usable_parms_href->{'anno_columns'},
                  			-default => undef,
                  			-size => 9,
                  			-multiple => 'true',
                  			
          ),
          br(),
          hr(),
          br(),
           h2("Columns currently in the data file"),
           h3("View the Columns currently in the data file(s)"),
           $q->scrolling_list(-name=>'data_columns',
                  -values=>$usable_parms_href->{'data_columns'},
                  -default => undef,
                  -size => 9,
                  -multiple => 'true',
          ),
          $q->hidden(-name => 'token',
          			 -default => $usable_parms_href->{'token'},
          			 ),
          $q->hidden(-name => 'anno_out_file_name',
          			 -default => $usable_parms_href->{'anno_out_file_name'},
          			 ),
          $q->hidden(-name => 'data_out_file_name',
          			 -default => $usable_parms_href->{'data_out_file_name'},
          			 ),
          			 
          $q->hidden(-name => 'affy_annotation_file',
          			 -default => $usable_parms_href->{'affy_annotation_file'},
          			 ),
           br(),
           $q->submit(-name=>'merge_annotaion_files',
                        -value=>'Merge Files'),
           $q->end_form;
          
          	
}
##############################################################################
# grab_file_header
#
# Read the first row of the file and return an array of column headers
# Give a file handle return an array of column names
###############################################################################
sub grab_file_header {
	my $fh = shift;
	
	
	my $line = '';
	while (<$fh>){
		s/\s$//g; #delete any end of line characters
		
		s/^"//g;	#ha funny put quote in to keep syntax higlighting happy in eclipse -->"
		s/$"//g;
		$line = $_;
		last;
	}
	$log->debug("FILE LINE '$line'");
	#test for the presents of a comma or tab to find the seperator type
	my $seperator = '';
	if ($line =~ /\t/){
		$seperator = "\t";
	}elsif($line =~ /","/){
		$seperator = '","';
	}elsif($line =~ /,/){
		$seperator = ',';
	}
	die "Cannot not Find a Comma or Tab type seperator in your file '$line'" unless ($seperator);
	
	my @headers = split /$seperator/, $line;
	$log->debug("HEADER SEPERATOR  '$seperator'");
	die "There does not appear to be enough columns in this file" unless(scalar @headers > 1);
	return (headers_aref =>\@headers,
			seperator => $seperator,
			);
}


##############################################################################
# read_annotation_library_dir
#
# Read the Affy library folder and give the use the choice of the annotation file to use
#
###############################################################################
sub read_annotation_library_dir {
 
 opendir (DIRS, "$AFFY_ANNO_PATH") or 
 	die "Cannot Read dir '$AFFY_ANNO_PATH' $!";
 	
 my @affy_anno_files = grep /\.csv/, readdir DIRS;
 my @sorted_files = sort  @affy_anno_files;
 return \@sorted_files;
}

##############################################################################
# save_file
#
# Store_file to disk
#
###############################################################################
sub save_file {
  my %args = @_;
  
  my $fh = $args{FH};
  my $file_type = $args{FILE_TYPE};
  my @column_headers = @{ $args{COLUMN_HEADERS} };
  
  my $data = (join "\t", @column_headers) . "\n";	#FIX ME if the data is comma delimited this is really bad.....
  while (<$fh>){
  	$data .= $_;
  }
  
  my $file_name = $$ . "_$file_type.tsv";
  my $full_path = "$base_out_dir/$file_name";
  
  open (OUT, ">$full_path") or 
  	die "CANNOT OPEN OUT FILE TO SAVE '$full_path' $!";
  print OUT $data;
  close OUT;
  return $file_name;
  
}

##############################################################################
# check_for_data_files
#
# reach into a analysis directory check to make sure the files are there and then
#read a file to pull the column names
###############################################################################
sub check_for_data_files {
	my $path = $fm->path();
	my @filenames = $fm->filenames();
	
	my @good_file_names = grep /\.full_txt/, @filenames; #names of the Diff expressed file name
	if (scalar @good_file_names > 0){
		#grab the column head from the first file (going to assume they are all the same)
		my $file_name = $good_file_names[0];
		my $full_file_name = "$path/$file_name";
		open our $fh, "$full_file_name" or 
			die "Cannot open file '$full_file_name' $!";
		$log->debug("check for data_file grab column headers");
		my %header_info = grab_file_header($fh);
		my @col_names = @{ $header_info{'headers_aref'} };
		$log->debug("BIOCONDUCTOR ANLYSIS FILE HEADER NAMES '@col_names'");
		return @col_names;
	}
	
		
}


###############################################################################
# merge_files
#
# Merge the annotation data into the data files
###############################################################################
sub merge_files {
  
	my %args = @_;
  	my %parameters = %{ $args{ref_parameters} };
 
 	my $anno_library_path = '';
	if ( $parameters{anno_out_file_name} =~ /\w/){
		$anno_library_path = "$base_out_dir/$parameters{anno_out_file_name}";
	}elsif($parameters{affy_annotation_file} =~ /\w/){
		$anno_library_path = "$AFFY_ANNO_PATH/$parameters{affy_annotation_file}";
	}else{
		print h2("ERROR:Could not find the annotation file to use");
	}
 	$log->debug("ABOUT TO READ ANNOTATION DATA");
 	my $annotation_data_href = read_annotation_library(file_path => $anno_library_path,
 												  annotation_columns =>$parameters{anno_columns} 
 												  );
 	$log->debug("ABOUT TO ADD ANNOTATION DATA");											  
 	my @out_html_paths = add_anno_to_data(annotation_data_href =>$annotation_data_href,
 					 					  ref_parameters => $args{ref_parameters},
 					 					);
 					 					
 	print_out_paths_to_data(@out_html_paths);

} 

###############################################################################
# print_out_paths_to_data
#
# Print out a nice little html page to show the user where to get there data
###############################################################################
sub print_out_paths_to_data {
	my @out_paths = @_;
	my $show_file_url  = "$open_file_url?action=view_file"; 
	my $download_file_url = "$open_file_url?action=download"; 
	
	my %data_types = ();
	
	##FIX ME TO USE THE VIEW AFFY FILE SCRIPT
	my $html = qq~ <table border=0>
					<tr>
					<th class='grey_bg'>Count</th>
					<th class='grey_bg'>Show File</th>
					<th class='grey_bg'>Download File</th>
					</tr>			
				~;
	
	
	for (my $i=0; $i <= $#out_paths ; $i++){
		my ($file_root_name, $file_ext);
		if ($out_paths[$i] =~ /(.+?)\.(.*)/){
			$file_root_name = $1;
			$file_ext = $2;
		}else{
			$log->debug("ERROR: CANNOT PARSE FILE EXTENSION FROM FILE FOR '$out_paths[$i]'");
		}
		my $file_count =  $i + 1;
		$html .= qq~ <tr>
						<td>$file_count</td>
						<td><a href="$show_file_url&annotated_file=$file_root_name&file_ext=$file_ext">Show File </a></td>
						<td><a href="$download_file_url&annotated_file=$file_root_name&file_ext=$file_ext">Get File </a></td>
					  </tr>
					~;
	}
					
	$html .= "</table>";
	print $html;
	print_errors() if (@all_errors);
}

###############################################################################
# add_anno_to_data
#
# Add the annotation to the data
###############################################################################
sub add_anno_to_data {
	my %args = @_;
  	my $annotation_data_href = $args{annotation_data_href};
  	my %parameters = %{ $args{ref_parameters} };
  	
  	my @out_html_paths = ();

##Prep the annotation column headers
	my $annotation_column_headers = $annotation_data_href->{ANNO_COLUMN_NAMES};
	$annotation_column_headers =~ s/,/\t/g; #change any commas to tabs


## if the token is present it means we have data from a bioconductor run therefore we will be annotating 
##multipule files.  If it is not we are going to annotate the users data
	my @all_data_files = ();
	if ($fm->token()){
	 	@all_data_files = grep /\.full_txt/, $fm->filenames(); #names of the Diff expressed file name
		##append on the full file pahth
		my $out_file_path = $fm->filepath();
		@all_data_files = grep "$out_file_path/$_"  ,@all_data_files;
		
	}elsif($parameters{data_out_file_name} =~ /\.tsv/){
		push @all_data_files, "$base_out_dir/$parameters{data_out_file_name}";
	}else{
		die "CANNOT FIND DATA FILE TO ADD ANNOTATION TO";
	}
	$log->debug("All files to Add annotation to '@all_data_files'");
## loop thru all the data files and add the annotation
	
	foreach my $data_file (@all_data_files){
		print "Starting to Annotate '$data_file'<br>";
		
		open our $fh_data, "$data_file" or
			die "Cannot open Data file for Reading '$data_file' $!";
		
		my %header_info = grab_file_header($fh_data);
		my @column_headers = @{ $header_info{headers_aref} };
  		my $seperator = $header_info{seperator};
  		
  		my $affy_probe_setid_col_numb = find_affy_probe_set_col_numb(@column_headers);
		$log->debug("AFFY COLUMN ID '$affy_probe_setid_col_numb'");
		
	##Add the Annotation Columns headers to the Data column headers.
		my $data_column_headers = join "$seperator",@column_headers;
		$log->debug("DATA FILE COLUMN HEADERS **'$data_column_headers\t$annotation_column_headers'");
		push my @all_data, "$data_column_headers\t$annotation_column_headers";
		
	##loop thru the data file, pull the affy id and get the annotation from the annotation hash
		while (<$fh_data>){
			s/\s$//g; #delete any end of line characters
			my @data = split /$seperator/, $_;
			#$log->debug("AFFY ID FROM DATA'$data[$affy_probe_setid_col_numb]'");
			if (exists $annotation_data_href->{$data[$affy_probe_setid_col_numb]}){
	#pull out the tab delimited string of anno information for this probe id
				my $anno_data = $annotation_data_href->{$data[$affy_probe_setid_col_numb]};
				push @data, $anno_data;
			}else{
				record_error("Cannot find annotation for probe id\t$data[$affy_probe_setid_col_numb]");
			}
			push @all_data, join "\t", @data;
		}
		close $fh_data;
		
		sleep 1;
		open OUT , ">$data_file" or
			die "Cannot open data file for writing '$data_file' $!";
		print OUT join "\n", @all_data;
		my $root_file_name = basename($data_file);
		my $out_html_path = "$root_file_name";
		push @out_html_paths, $out_html_path;
	}
	return @out_html_paths;
}

###############################################################################
# record_error
#
# Collect any errors that the user should know about
###############################################################################
sub record_error {
	push @all_errors, shift;
}
##############################################################################
# print_errors
#
# print any errors the user should know about
###############################################################################
sub print_errors {
	
	print "<table>
			<tr>
				<td class='grey_bg' >Count</td>
				<td class='grey_bg'>Error</td>
			</tr>
		 ";
	for (my $i=0; $i <= $#all_errors ; $i++){
		
		print "<tr><td>" . ($i+1) . "</td>", 
			  "<td>$all_errors[$i]</td></tr>";
	}
	
	print "</table>";
					
	
}

###############################################################################
# read_annotation_library
#
# Read the annotation file and return it as 
###############################################################################
sub read_annotation_library {
	my %args = @_;
  	my $file_path = $args{file_path};
  	my $annotation_columns = $args{annotation_columns};
  	
  	my %anno_data = ();
  	$log->debug("ANNO FILE PATH** '$file_path'"); 
  	$log->debug("ANNO COLUMNS '$annotation_columns'");
  	
  	open our $fh, "$file_path" or 
  		die "Cannot open Annotation file for reading '$file_path' $!";
  		
  	my %header_info = grab_file_header($fh);
  #	$log->debug(Dumper(\%header_info));
  	my @column_headers = @{ $header_info{headers_aref} };
  	my $affy_probe_setid_col_numb = find_affy_probe_set_col_numb(@column_headers);
  	my @get_these_anno_columns = find_annotaion_column_numbs(all_anno_columns =>\@column_headers,
  															 wanted_columns   =>$annotation_columns,
  															 );
  	$anno_data{ANNO_COLUMN_NAMES} = $annotation_columns;
  	
  	$log->debug("COLUMN NUMBERS TO GET '@get_these_anno_columns'");
  ##Actually parse and collect the data we want
  	my $count = 0;
  	my $seperator = $header_info{seperator};
  	while (<$fh>){
  		s/\s$//g; #delete any end of line characters
  		s/^"//g;	
		s/"$//g;	#ha funny put quote in to keep syntax higlighting happy in eclipse -->"
  		my @data = split /$seperator/, $_;
  		
  		$anno_data{$data[$affy_probe_setid_col_numb]} = join "\t", @data[@get_these_anno_columns];
  		$count ++;
  		#if ($count > 10){
  		#	$log->debug(Dumper(\%anno_data));
 		#	die; 		
	  	#}
  	}
  	return \%anno_data;
}

###############################################################################
# find_affy_probe_set_col_numb
#
# Find the column number that contains the Affy Probe set ID 
###############################################################################
sub find_affy_probe_set_col_numb {
	my @column_headers = @_;
	my $col_number = '';
	for (my $i=0; $i <= $#column_headers ; $i++){
		my $col_name = $column_headers[$i];
		if ($col_name =~ /probe/i){
			return $i;
		}
	}
	die "Could not find the Affy Probe Set ID column with these Column names '@column_headers'";
	
}
###############################################################################
# find_annotaion_column_numbs
#
# Find all the column numbers for the annotation columns requested by the user
###############################################################################
sub find_annotaion_column_numbs {
	my %args = @_;
	my @column_headers = @{ $args{all_anno_columns} };
	my $annotation_columns = $args{wanted_columns};
	my @wanted_columns = split /,/, $annotation_columns;
	
	my @wanted_col_numbs = ();
	foreach my $wanted_column (@wanted_columns){
		my $found_flag = 0;
		for (my $i=0; $i <= $#column_headers ; $i++){
			if ($wanted_column =~ /$column_headers[$i]/){
				push @wanted_col_numbs, $i;
				$found_flag = 1;
			}
		}
		die "CANNOT FIND ANNOTAION COLUMN FOR '$wanted_column'" unless $found_flag;
		
	}
	return @wanted_col_numbs;
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

} # end evalSQL


