#!/usr/local/bin/perl

###############################################################################
# Program     : Create_GEO_file.cgi
# Author      : Bruz Marzolf <bmarzolf@systemsbiology.org>
# $Id: GetAffy_GeneIntensity.cgi 5163 2006-10-13 17:55:31Z dcampbel $
#
# Description : Take a normalized Affy data set and array annotations
#               and produce a SOFTtext file for GEO submission
#
# SBEAMS is Copyright (C) 2000-2006 Institute for Systems Biology
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
use FileManager;
use Site;
use Spreadsheet::ParseExcel;

$| = 1;

use lib "$FindBin::Bin/../../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $affy_o $q $current_contact_id $current_username
  $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
  $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
  @MENU_OPTIONS %CONVERSION_H $fm $data_analysis_o $cgi *sym);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Merge_results_sets;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::Affy_file_groups;
use SBEAMS::Microarray::Affy_Analysis;
use SBEAMS::Microarray::Affy_Annotation;

use Data::Dumper;
$sbeams    = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

my $sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;
$sbeams_affy_groups->setSBEAMS($sbeams)
  ;    #set the sbeams object into the sbeams_affy_groups

$affy_o = new SBEAMS::Microarray::Affy_Analysis;
$affy_o->setSBEAMS($sbeams);

use POSIX qw(log10 pow);
use CGI qw(:standard);

#$q = new CGI;

$cgi = $q;

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE     = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless ( GetOptions( \%OPTIONS, "verbose:s", "quiet", "debug:s" ) ) {
	print "$USAGE";
	exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET   = $OPTIONS{"quiet"}   || 0;
$DEBUG   = $OPTIONS{"debug"}   || 0;
if ($DEBUG) {
	print "Options settings:\n";
	print "  VERBOSE = $VERBOSE\n";
	print "  QUIET = $QUIET\n";
	print "  DEBUG = $DEBUG\n";
	print "OBJECT TYPES 'sbeamMOD' = " . ref($sbeams) . "\n";
	print Dumper($sbeams);
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################

my $base_url         = "$CGI_BASE_DIR/Microarray/bioconductor/$PROG_NAME";
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
	exit
	  unless (
		$current_username = $sbeams->Authenticate(
			permitted_work_groups_ref => [
				'Microarray_user', 'Microarray_admin',
				'Admin',           'Microarray_readonly'
			],

			#connect_read_only=>1,
			allow_anonymous_access => 1,
		)
	  );

	#### Read in the default input parameters
	my %parameters;
	my $n_params_found = $sbeams->parse_input_parameters(
		q              => $q,
		parameters_ref => \%parameters
	);

	#### Process generic "state" parameters before we start
	$sbeams->processStandardParameters( parameters_ref => \%parameters );

	#### Decide what action to take based on information so far
	if ( $parameters{'output_mode'} =~ /excel/ )
	{    #print out results sets in different formats
		print_output_mode_data( ref_parameters => \%parameters );
	}
	else {
		$sbeamsMOD->printPageHeader();
		handle_request( ref_parameters => \%parameters );
		$sbeamsMOD->printPageFooter();
	}

}    # end main

###############################################################################
# Handle Request
###############################################################################
sub handle_request {
	my %args = @_;

	#### Get token
	my $token = $cgi->param('token');
	
	#### Process the arguments list
	my $ref_parameters = $args{'ref_parameters'}
	  || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};

	# put token in SBEAMS parameters hash
	$parameters{'token'} = $token;

	#### Define some generic varibles
	my ( $i, $element, $key, $value, $line, $result, $sql );

	#### Read in the standard form values
	my $apply_action = $parameters{'action'}
	  || $parameters{'apply_action'}
	  || '';

	if ( $apply_action eq '' ) {
		print_gather_data_page( ref_parameters => \%parameters );
	}
	elsif ( $apply_action eq 'download_file' ) {
		print_download_file_page( ref_parameters => \%parameters );
	}

}    #end handle_request

###############################################################################
# Print Gather Data Page
###############################################################################
sub print_gather_data_page {
	my %args           = @_;
	my $parameters_ref = $args{'ref_parameters'};
	my %parameters     = %{$parameters_ref};

	my $token = $parameters{'token'};

	## Get analysis description
	my $project = $sbeams->getCurrent_project_id();
	$data_analysis_o =
	  $affy_o->check_for_analysis_data( project_id => $project );

	my ( $analysis_id, $user_desc, $analysis_desc, $parent_analysis_id,
		$analysis_date, $username )
	  = $data_analysis_o->get_analysis_info(
		analysis_name_type => 'normalization',
		folder_name        => $token,
		info_types         => [
			"analysis_id",   "user_desc",
			"analysis_desc", "parent_analysis_id",
			"analysis_date", "user_login_name"
		],
		truncate_data => 0,
	  );

	## Parse out file roots from analysis description
	$analysis_desc =~ /File\ Names\ \=\>(.*?).CEL\<br.*Processing\ =>(.*)\Z/;

	my @file_roots = split /\.CEL,\s+/, $1;
	my $file_roots = join "','", @file_roots;
	$file_roots = "\'" . $file_roots . "\'";

	my $processing_method = $2;

	## Grab all database array info based on file roots
	my $sql = $sbeams_affy_groups->get_affy_geo_info_sql(
		file_roots =>
		  $file_roots #return a sql statement to display all the arrays for a particular project
	);
	my @selected_arrays = $sbeams->selectSeveralColumns($sql);

	## Check if there are multiple arrays with the same file_root
	my %seen_roots;
	my $duplicate_roots = 0;
  # tabbed string of CEL files to save for later
  my $tabbed_CEL_paths = "";
	foreach my $array (@selected_arrays) {
    $tabbed_CEL_paths .= ${$array}[23] . "/" . ${$array}[1] . ".CEL\t";
		if ( $seen_roots{$array} == 1 ) {
			$duplicate_roots = 1;
		}
		$seen_roots{$array} = 1;
	}

	if ( $duplicate_roots == 1 ) {
		print qq~
    <H2><U>GEO Submission File Generator</U></H2>\n
    <B>Your selection at least one array that seems to have two redundant
    records in SBEAMS. Please seek help from the Microarray Facility or
    SBEAMS developers to remedy this problem.</B>
    ~;
	}
	else {
		## Generate tabular data for original sample info text box
		my $tabbed_text =
		  generate_tabular_sample_info( \@file_roots, \@selected_arrays,
			$processing_method );

		## Generate download URL
#my $base_url = "$CGI_BASE_DIR/Microarray/bioconductor/Create_GEO_file.cgi";
#my $excel_url = "$base_url\/geo_sample_info.xls?token=$token?output_mode=excel";
		my $excel_url = "$base_url?token=$token&output_mode=excel"; 

		## Print page
		print qq~
    <H2><U>GEO Submission File Generator</U></H2>\n
    <FORM METHOD="POST" NAME="data_form" ENCTYPE="multipart/form-data"><BR>
  	<B>Original Sample Information:</B>
    <BR>
  	<TEXTAREA NAME="original_sample_data" ROWS="10" COLS="70" READONLY="true">$tabbed_text</TEXTAREA>
    <BR>
    <BR>
    <A HREF="$excel_url">Download to Excel</A>
    <H4>Editing your sample information:</H4>
    <OL>
    	<LI>Click the 'Download to Excel' link above to open your sample
    	information in Excel.</LI>
    	<LI>Edit your sample information in the spreadsheet, making sure 
    	that every field is filled in. Save your Excel file.</LI>
    	<LI>Use the 'Browse...' button below to specify your editied
    	Excel file.</LI>
    	<LI>Press the button below labeled <B>Create GEO SOFTtext</B></LI>
    </OL>
    <B> -- OR -- </B>
    <OL>
    	<LI>Copy the contents of the text
    	field above and paste into your spreadsheet software.</LI>
    	<LI>Edit your sample information in the spreadsheet, making sure 
    	that every field is filled in.</LI>
    	<LI>Copy the information from your spreadsheet 
    	and paste it into the text box below.</LI>
    	<LI>Press the button below labeled <B>Create GEO SOFTtext</B></LI>
    </OL>
    <BR>
    <B>Edited Sample Information:</B>
    <BR>
  	<TEXTAREA NAME="edited_sample_data" ROWS="10" COLS="70"></TEXTAREA>
    <BR>
    <B> -- OR -- </B>
    <BR>
    Edited Excel file: <INPUT TYPE="file" NAME="edited_info_file" SIZE="50" MAXLENGTH="80"/>
    <BR>
    <BR>
    <INPUT TYPE="hidden" NAME="token" VALUE="$token">
    <INPUT TYPE="hidden" NAME="apply_action" VALUE="download_file">
    <INPUT TYPE="hidden" NAME="cel_files" VALUE="$tabbed_CEL_paths">
    <INPUT TYPE="submit" VALUE="Create GEO SOFTtext">
    </FORM>
    ~;
	}
}

###############################################################################
# Finds arrays based on a given token and produces a tabular text of the
# sample information for those arrays
###############################################################################
sub get_sample_info_tabbed_text_from_token {
	my $token = shift @_;

	## Get analysis description
	my $project = $sbeams->getCurrent_project_id();
	$data_analysis_o =
	  $affy_o->check_for_analysis_data( project_id => $project );

	my ( $analysis_id, $user_desc, $analysis_desc, $parent_analysis_id,
		$analysis_date, $username )
	  = $data_analysis_o->get_analysis_info(
		analysis_name_type => 'normalization',
		folder_name        => $token,
		info_types         => [
			"analysis_id",   "user_desc",
			"analysis_desc", "parent_analysis_id",
			"analysis_date", "user_login_name"
		],
		truncate_data => 0,
	  );

	## Parse out file roots from analysis description
	$analysis_desc =~ /File\ Names\ \=\>(.*?).CEL\<br.*Processing\ =>(.*)\Z/;

	my @file_roots = split /\.CEL,\s+/, $1;
	my $file_roots = join "','", @file_roots;
	$file_roots = "\'" . $file_roots . "\'";

	my $processing_method = $2;

	## Grab all database array info based on file roots
	my $sql = $sbeams_affy_groups->get_affy_geo_info_sql(
		file_roots =>
		  $file_roots #return a sql statement to display all the arrays for a particular project
	);
	my @selected_arrays = $sbeams->selectSeveralColumns($sql);

	my $tabbed_text =
	  generate_tabular_sample_info( \@file_roots, \@selected_arrays,
		$processing_method );

	return $tabbed_text;
}

###############################################################################
# Generate tabular text string containing sample info
###############################################################################
sub generate_tabular_sample_info {
	my $file_roots        = shift @_;
	my $selected_arrays   = shift @_;
	my $processing_method = shift @_;

	## Standard protocol texts
	my $hybridization_protocol =
	    "Following fragmentation, ten micrograms of adjusted cRNA from"
	  . "each sample was hybridized for 16 hours at 45 deg C to Affymetrix GeneChip";

	my $scan_protocol =
	    "Scanning was performed using the Affymetrix GeneChip 3000 Scanner. "
	  . "Images were processed into CEL files with the Affymetrix GCOS software.";

	my $data_protocol =
	    "Raw CEL intensity data were $processing_method "
	  . "normalized using R/Bioconductor";

	my $tabbed_text;

	## Header description row
	$tabbed_text .=
	    "Field Description:\t"
	  . "Short, Unique Name for Array\t"
	  . "Provide a unique title that describes this Sample. We suggest that "
    . "you use the system [biomaterial]-[condition(s)]-[replicate number], "
    . "e.g., Muscle_exercised_60min_rep2.\t"
	  . "Briefly identify the biological material and the experimental "
	  . "variable(s), e.g., vastus lateralis muscle, exercised, 60 min.\t"
	  . "Identify the organism(s) from which the biological material was derived.\t"
	  . "List all available characteristics of the biological source, "
	  . "including factors not necessarily under investigation, e.g., "
	  . "Strain: C57BL/6 Gender: female Age: 45 days Tissue: bladder tumor "
	  . "Tumor stage: Ta You can provide as much text as you need to "
	  . "thoroughly describe your biological samples.\t"
	  . "Describe any treatments applied to the biological material "
	  . "prior to extract preparation. You can include as much text as you "
	  . "need to thoroughly describe the protocol; it is strongly recommended "
	  . "that complete protocol descriptions are provided within your submission.\t"
	  . "Describe the conditions that were used to grow or maintain organisms "
	  . "or cells prior to extract preparation. You can include as much text as "
	  . "you need to thoroughly describe the protocol; it is strongly recommended "
	  . "that complete protocol descriptions are provided within your submission.\t"
	  . "Specify the type of molecule that was extracted from the biological material.\t"
	  . "Describe the protocol used to isolate the extract material. You can "
	  . "include as much text as you need to thoroughly describe the protocol; it is strongly recommended that complete protocol descriptions are provided within your submission.\t"
	  . "Specify the compound used to label the extract e.g., biotin, Cy3, Cy5, 33P.\t"
	  . "Describe the protocol used to label the extract. You can include as "
	  . "much text as you need to thoroughly describe the protocol; it is "
	  . "strongly recommended that complete protocol descriptions are provided "
	  . "within your submission.\t"
	  . "Describe the protocols used for hybridization, blocking and washing, "
	  . "and any post-processing steps such as staining. You can include as "
	  . "much text as you need to thoroughly describe the protocol; it is "
	  . "strongly recommended that complete protocol descriptions are provided "
	  . "within your submission.\t"
	  . "Describe the scanning and image acquisition protocols, hardware, and "
	  . "software. You can include as much text as you need to thoroughly "
	  . "describe the protocol; it is strongly recommended that complete "
	  . "protocol descriptions are provided within your submission.\t"
	  . "Include any additional information not provided in the other fields, "
	  . "or paste in broad descriptions that cannot be easily dissected into "
	  . "the other fields.\t"
	  . "Provide details of how data in the VALUE column of your table were "
	  . "generated and calculated, i.e., normalization method, data selection "
	  . "procedures and parameters, transformation algorithm (e.g., MAS5.0), "
	  . "and scaling parameters. You can include as much text as you need to "
	  . "thoroughly describe the processing procedures.\t"
	  . "Reference the Platform upon which this hybridization was performed. "
	  . "Reference the Platform accession number (GPLxxx) if the Platform "
	  . "already exists in GEO\t"
    . "Affymetrix CEL file name\n";

	## Header row
	$tabbed_text .=
	    "GEO Field:\t"
	  . "\^SAMPLE\t"
	  . "\!Sample_title\t"
	  . "\!Sample_source_name_ch1\t"
	  . "\!Sample_organism_ch1\t"
	  . "\!Sample_characteristics_ch1\t"
	  . "\!Sample_treatment_protocol_ch1\t"
	  . "\!Sample_growth_protocol_ch1\t"
	  . "\!Sample_molecule_ch1\t"
	  . "\!Sample_extract_protocol_ch1\t"
	  . "\!Sample_label_ch1\t"
	  . "\!Sample_label_protocol_ch1\t"
	  . "\!Sample_hyb_protocol\t"
	  . "\!Sample_scan_protocol\t"
	  . "\!Sample_description\t"
	  . "\!Sample_data_processing\t"
	  . "\!Sample_platform_id\t"
    . "\!Sample_supplementary_file\n";

	## Data rows
	for my $i ( 0 .. $#{$selected_arrays} ) {
		my @array     = @{ @{$selected_arrays}[$i] };
		my $file_root = @{$file_roots}[$i];

		# determine array platform, if stored in the slide_type comment
		$array[6] =~ /.*GEO\:(.*?)\s+/;
		my $geo_platform = $1;

		$tabbed_text .= "$array[0]\t" . "$array[1]\t" .    # SAMPLE
		  "$array[2]\t" .                  # Sample_title
		  "\t" .                           # Sample_source_name_ch1
		  "$array[3]\t" .                  # Sample_organism_ch1
		  "$array[4]\t" .                  # Sample_characteristics_ch1
		  "$array[5]\t" .                  # Sample_treatment_protocol_ch1
		  "\t" .                           # Sample_growth_protocol_ch1
		  "total RNA\t" .                  # Sample_molecule_ch1
		  "\t" .                           # Sample_extract_protocol_ch1
		  "biotin\t" .                     # Sample_label_ch1
		  "\t" .                           # Sample_label_protocol_ch1
		  "$hybridization_protocol\t" .    # Sample_hyb_protocol_ch1
		  "$scan_protocol\t" .             # Sample_scan_protocol_ch1
		  "\t" .                           # Sample_description
		  "$data_protocol\t" .             # Sample_data_processing
		  "$geo_platform\t" .              # Sample_platform_id
      "$file_root" . ".CEL\n";         # Sample_supplementary_file
	}

	return $tabbed_text;
}

###############################################################################
# Print Download File Page
###############################################################################
sub print_download_file_page {
	my %args           = @_;
	my $parameters_ref = $args{'ref_parameters'};
	my %parameters     = %{$parameters_ref};

	## Print out top of page
	print qq~
	    <H2><U>GEO Submission File Generator</U></H2>\n
	~;

	my $original_text = $parameters{'original_sample_data'};

  ## Get CEL file paths
  my $tabbed_CEL_files = $parameters{'cel_files'};
  my @cel_files = split /\t/, $tabbed_CEL_files;

	my $edited_text;
	## Load in Excel file if provided
	if ( $parameters{'edited_info_file'} ne "" ) {
		my $fh = $q->upload('edited_info_file');
		$edited_text =
			parse_excel_sample_info_file( $fh );
	}
	else {
		$edited_text = $parameters{'edited_sample_data'};
	}

	my $original_table_ref = tabbed_text_to_table($original_text);
	my $edited_table_ref   = tabbed_text_to_table($edited_text);

	my @original_table = @{$original_table_ref};
	my @edited_table   = @{$edited_table_ref};

	## Ensure that size of array is the same, and that there are not blank fields
	my $parsing_error = "";

	if ( $#original_table != $#edited_table ) {
		$parsing_error =
		  "Number of arrays in edited text doesn't match original table.";
	}
	else {
		for my $i ( 0 .. $#original_table ) {
			my @original_elements = @{ $original_table[$i] };
			my @edited_elements   = @{ $edited_table[$i] };
			if ( $#original_elements != $#edited_elements ) {
				$parsing_error =
					"Columns for $original_elements[1] differ from original table";
			}
			else {
				foreach my $element (@edited_elements) {
					if ( $element eq "" ) {
						$parsing_error = "Blank field in $original_elements[1]";
					}
				}
			}
		}
	}

	## Complain and don't try further processing if there's a parsing error
	if ( $parsing_error ne "" ) {
		print qq~
		    Your edited array info table had the following problem:
		    <BR><BR>
		    <B>$parsing_error</B>
		    <BR><BR>
		    Please go back, fix this and try again.
		~;
	}
	## If there are no parsing errors, go ahead with GEO file creation
	else {
		## Read in the expression data
		my $token                = $parameters{'token'};
		my $expression_data_file =
		  "$BC_UPLOAD_DIR/$token/${token}_annotated.txt";
		my $expression_data_ref =
		  parse_expression_data_file($expression_data_file);
		my %expression_data = %{$expression_data_ref};

		## Merge and write out a SOFTtext file
		my $geo_file = "$BC_UPLOAD_DIR/$token/${token}.geo";
		open OUT, ">$geo_file"
		  or error("Cannot write to GEO file $geo_file $!");

		# discard header description row
		shift @edited_table;

		# grab off actual GEO headers
		my $headings_ref  = shift @edited_table;
		my @headings      = @{$headings_ref};
		my @probeset_list = @{ $expression_data{'probeset_names'} };
		print "Merging sample information and expression data.";
		foreach my $array_sample_ref (@edited_table) {
			my @array_sample = @{$array_sample_ref};
			foreach my $i ( 1 .. $#array_sample ) {
				print OUT $headings[$i], " = ", $array_sample[$i], "\n";
			}
			print OUT "#ID_REF\n", "#VALUE = normalized log2 signal\n",
			  "!sample_table_begin\n", "ID_REF\tVALUE\n";

			my @array_data = @{ $expression_data{ $array_sample[2] } };
			foreach my $i ( 0 .. $#probeset_list ) {
				print OUT $probeset_list[$i], "\t", $array_data[$i], "\n";
			}
			print OUT "!sample_table_end\n";

			# print progress dot
			print ".";
		}

    ## zip .geo file and CEL files
		my $zip_file = "$BC_UPLOAD_DIR/$token/${token}_geo.zip";
    my $zip_command = "zip -j $zip_file $geo_file ";
    foreach my $cel (@cel_files) {
      $zip_command .= "$cel "
    }
    # first remove any previous zip, then generate new one    
    system("rm $zip_file >/dev/null");
    system($zip_command . ">/dev/null");

		## Print remainder of page, with a link to the GEO file and instructions
		my $download_zip_file_url =
		    "$CGI_BASE_DIR/Microarray/View_Affy_files.cgi"
		  . "?action=download&analysis_folder=$token"
		  . "&analysis_file=$token" . "_geo&file_ext=zip";
		print qq~
		    <H4>Your GEO submission file has been created successfully. It can
		    be downloaded by <A HREF="$download_zip_file_url">clicking here</A></H4>
		    <H4>In order to submit your data to GEO, you will need to follow
		    these steps:</H4>
		    <OL>
		    	<LI>Click the download link above, and save the zip file to your computer.</LI>
		    	<LI>Go to the GEO direct deposit page at 
		    	<A HREF="http://www.ncbi.nlm.nih.gov/projects/geo/submission/depslip.cgi">
		   		http://www.ncbi.nlm.nih.gov/projects/geo/submission/depslip.cgi</A></LI>
		   		<LI>Choose <B>SOFTtext</B> as your file format</LI>
		   		<LI>Browse to find the zip file you saved to your computer.</LI>
		   		<LI>Set 'Submission kind' to <B>new</B></LI>
		   		<LI>Enter a release data, which should be chosen to fall on or after the
		   		date your publication is released. If you don't know this date, you can
		   		choose a date up to a year away, and then come back to GEO and update
		   		the release date when you know when your publication will come out.
		   		Alternatively, if the data belongs to an existing publication,
		   		you can choose the box for immediate release.</LI>
		   		<LI>Click 'Submit'</LI>
          <LI>After your submission zip file has been uploaded, the GEO site will ask
          you to identify the master file. Select the first file, which should
          have a name ending in .geo, and choose the 'Submit' button at the bottom
          of the page.</LI>
		   	</OL>
		~;
	}
}

###############################################################################
# Take a single text string with tabs and new line characters, and
# break it into an array
###############################################################################
sub tabbed_text_to_table {
	my $text = shift @_;

	my @info_table;

	$text =~ s/\r\n/\n/g;

	#print $text;
	my @array_of_lines = split /\n/, $text;
	foreach my $line (@array_of_lines) {
		my @elements = split /\t/, $line;
		push @info_table, \@elements;
	}

	return \@info_table;
}

###############################################################################
# Take an expression file and parse into an array of arrays
###############################################################################
sub parse_expression_data_file {
	my $file = shift @_;

	open IN, $file or error("Cannot open expression data file $file $!");
	my $line;
	my @elements;

	## look for first numerical value in second line to determine where
	## data starts
	$line = <IN>;
	chomp($line);
	@elements = split /\t/, $line;
	my $first_data_column = -1;
	my @column_names;
	for my $i ( 0 .. $#elements ) {
		if ( $elements[$i] =~ /\d+/ && $first_data_column < 0 ) {
			$first_data_column = $i;
		}
		push @column_names, $elements[$i];
	}
	close(IN);

	#print "first data column is $first_data_column\n";
	## Read in real data
	open IN, $file or error("Cannot open expression data file $file $!");
	$line = <IN>;    # discard header
	my %data;
	while ( $line = <IN> ) {
		chomp($line);
		@elements = split /\t/, $line;
		push @{ $data{'probeset_names'} }, $elements[0];
		for my $i ( $first_data_column .. $#elements ) {
			push @{ $data{ $column_names[$i] } }, $elements[$i];
		}
	}
	close(IN);

	return \%data;
}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
	my ($error) = @_;

	print h2("GEO Submission File Generator"), h3("Error:"), p($error);

	print "DEBUG INFO<br>";
	my @param_names = $cgi->param;
	foreach my $p (@param_names) {
		print $p, " => ", $cgi->param($p), br;
	}
	site_footer();

	exit(1);
}

###############################################################################
# Force download of Excel file with sample info
###############################################################################
sub print_output_mode_data {
	my %args           = @_;
	my $parameters_ref = $args{'ref_parameters'};
	my %parameters     = %{$parameters_ref};

	my $token = $cgi->param('token');

	print "Content-type: application/force-download \n";
	print "Content-type: application/excel \n";
	print "Content-Disposition: filename=geo_sample_info.xls\n\n";

	my $original_text = get_sample_info_tabbed_text_from_token($token);

	print $original_text;
}

###############################################################################
# Parse out sample info from an Excel file
###############################################################################
sub parse_excel_sample_info_file {
	my $fh = shift @_;
	
	my $oExcel = new Spreadsheet::ParseExcel;

	my $oBook = $oExcel->Parse($fh);
	my ( $iR, $iC, $oWkS, $oWkC );

	my $tabular_text = "";

	my $iSheet = 0;
	  $oWkS = $oBook->{Worksheet}[$iSheet];
	for (
		my $iR = $oWkS->{MinRow} ;
		defined $oWkS->{MaxRow} && $iR <= $oWkS->{MaxRow} ;
		$iR++
	  )
	{
		for (
			my $iC = $oWkS->{MinCol} ;
			defined $oWkS->{MaxCol} && $iC <= $oWkS->{MaxCol} ;
			$iC++
		  )
		{
			$oWkC = $oWkS->{Cells}[$iR][$iC];
			$tabular_text .= $oWkC->Value if ($oWkC);
			$tabular_text .= "\t" if $iC < $oWkS->{MaxCol};
		}
		$tabular_text .= "\n";
	}

	return $tabular_text;
}
