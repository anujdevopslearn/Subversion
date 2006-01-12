#!/usr/local/bin/perl 


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
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


#use CGI;
#$q = new CGI;


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
    connect_read_only=>1,
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

  $sbeams->output_mode('cytoscape');
  my $header = $sbeams->get_http_header();

  #### Decide what action to take based on information so far
  if ($parameters{action} eq "????") {
    # Some action 
  }

  ##  Retrieves individual data sets
  elsif ($parameters{action} eq "get_data") {
	$header =~ s/html/plain/;
	print "$header\n";
	get_data(ref_parameters=>\%parameters);
  }

  ## Retrieves a CytoXML document (i.e. one 'experiment')
  elsif ($parameters{action} eq "xml") {
	$header =~ s/html/plain/;
	print "$header\n";
	print_xml(ref_parameters=>\%parameters);
  }

  ## Retrieves URLs to all the 'experiments' a user can access
  else {
	$header =~ s/html/plain/;
	print "$header\n";
	handle_primary_request(ref_parameters=>\%parameters);
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
# get date
###############################################################################
sub get_date {
  my %args = @_;
  my $SUB_NAME = "get_date";

  my $day = (localtime)[3];
  my $month = (localtime)[4] + 1;
  my $year = (localtime)[5] + 1900;

  return sprintf("%4d-%02d-%02d",$year,$month,$day);

}

###############################################################################
# Handle Request
###############################################################################
sub handle_primary_request {
  my %args = @_;
  my $SUB_NAME = "handle_primary_request";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  my @accessible_projects = $sbeams->getAccessibleProjects();
  my $project_list = join ',',@accessible_projects; 

  my $sql = qq~
SELECT condition_id, condition_name
  FROM $TBMA_COMPARISON_CONDITION
 WHERE project_id IN ($project_list)
 ~;

  my %conditions = $sbeams->selectTwoColumnHash($sql);

  foreach my $proj (@accessible_projects) {
	print "$SERVER_BASE_DIR$CGI_BASE_DIR/$SBEAMS_SUBDIR/CytoLink.cgi?action=xml&project_id=".$proj."\n";
  }

  return;

} # end handle_request


###############################################################################
# Print XML
###############################################################################
sub print_xml {
  my %args = @_;
  my $SUB_NAME = "print_xml";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
  my $desired_ids = $parameters{'project_id'} || 
	join(',',$sbeams->getAccessibleProjects());
  my @project_ids = split ',', $desired_ids;
  my $keyword = $parameters{'keyword'};


  my $current_conditions = "";
  my $condition_xml = "";

  ## Special Handling: This reads a text file that provides (for example):
  ##     -breakdown of a "project" into "experiments"
  ##     -variables associated with each "experiment"
  ##
  ## Only ONE experiment is returned.
  my @data = get_supporting_data(project_id=>$project_ids[0],
								 keyword=>$keyword);

  return if (scalar(@data) == 0);

  my $experiment = $data[0]->[1];
  my $species = $data[0]->[4];
  my $strain = $data[0]->[8];
  my $perturbation = $data[0]->[9];
  my $manipulation_type = $data[0]->[10];
  my $manipulated_variable = $data[0]->[11];

  ## XML Header
  print "<?xml version=\"1.0\" ?>\n\n";

  ## Start a new <experiment>
  my $date = get_date();
  print"<experiment name=\"$experiment\" date=\"$date\">\n\n";
		
  ## Insert <predicate> information
  print "\t<predicate category=\'species\' value=\'$species\'\/>\n";
  print "\t<predicate category=\'strain\' value=\'$strain\'\/>\n";
  print "\t<predicate category=\'perturbation\' value=\'$perturbation\'\/>\n";
  print "\t<predicate category=\'manipulationType\' value=\'$manipulation_type\'\/>\n";
  print "\t<predicate category=\'manipulatedVariable\' value=\'$manipulated_variable\'\/>\n\n";

  foreach my $row (@data) {
	my ($pid, $experiment, $cond_id, 
		$cond_name, $species, $variable_name, 
		$variable_value, $variable_units, $strain, 
		$perturbation,$manipulatedType, $manipulatedVariable) = @{$row};


	## Split variable names, values,and units, based upon colons 
	my @variable_names = split ":", $variable_name;
	my @variable_values = split ":", $variable_value;
	my @variable_units = split ":", $variable_units;

	if (scalar(@variable_names) != scalar(@variable_values) &&
		scalar(@variable_names) != scalar(@variable_units)) {
	  print "SBEAMS ERROR: check spreadsheet to ensure that variable information is correct!\n";
	}

	$current_conditions .="$cond_id,";

	$condition_xml .= "\t<condition alias=\'$cond_name\'>\n";
	for (my $i =0;$i < scalar(@variable_names); $i++) {
	  $condition_xml .= "\t\t<variable name=\'$variable_names[$i]\' ".
		"value=\'$variable_values[$i]\' ";
		if ($variable_units[$i]){
		  $condition_xml .= "units=\'$variable_units[$i]\' ";
		}
	  $condition_xml .= "\/>\n";
	}
	$condition_xml .= "\t<\/condition>\n\n";

  }

  ## remove trailing comma
  chop($current_conditions);

  ## print <dataset> info
  print "\t<dataset status=\'primary\' type=\'log10 ratios\'>\n";
  print "\t\t<uri> http://db/dev7/sbeams/cgi/Microarray/CytoLink.cgi?".
	"action=get_data&amp;condition_id=$current_conditions&amp;data_type=log10_ratio </uri>\n";
  print "\t</dataset>\n\n";

  print "\t<dataset status=\'derived\' type=\'lambdas\'>\n";
  print "\t\t<uri> http://db/dev7/sbeams/cgi/Microarray/CytoLink.cgi?".
	"action=get_data&amp;condition_id=$current_conditions&amp;&amp;data_type=lambda </uri>\n";
  print "\t</dataset>\n\n";

  print $condition_xml;

  ## end <experiment>
  print "</experiment>\n\n";
}


###############################################################################
# Get Supporting Data
# Given a project ID, return a 2-D array of data from the cytolink_data file.
###############################################################################
sub get_supporting_data {
  my %args = @_;
  my $SUB_NAME = "get_supporting_data";

  ## Process the arguments list
  my $project_id = $args{'project_id'}
    || die "project_id not passed";
  my $keyword = $args{'keyword'} || '\w+';

  my @project_data;

  open(INFILE, "cytolink_data.tsv") || die "could not open cytolink_data.tsv\n";

  while (<INFILE>) {
	chomp();
	next if ($_ =~ /^\#/);
	## Create an array for the condition
	my @row = split "\t";

	## Skip if it's not associated with our project.
	if ($row[0] != $project_id){
	  next;
	}else {
	  if ($row[1] =~ /$keyword/) {
		push @project_data, \@row;
	  }
	}
  }
  close (INFILE);
  return @project_data;
}



###############################################################################
# Get Data
###############################################################################
sub get_data {
  my %args = @_;
  my $SUB_NAME = "get_data";
  my $sql;

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  my $data_type = $parameters{'data_type'};
  my $condition_id = $parameters{'condition_id'};
  my $project_id = $parameters{'project_id'};

  ## A project will trump a condition in creating the list of conditions
  my @desired_conditions;
  if ($project_id) {

	$sql = qq~
SELECT condition_id
  FROM $TBMA_COMPARISON_CONDITION
 WHERE project_id IN ($project_id)
 ~;
	@desired_conditions = $sbeams->selectOneColumn($sql);
	$condition_id = join ",", @desired_conditions;
  } else{
	@desired_conditions = split /,/, $condition_id;
  }

  ## Verify that condition is readable to the user
  my @accessible_projects = $sbeams->getAccessibleProjects();
  my $project_list = join ',',@accessible_projects; 

  my $sql = qq~
SELECT condition_id, condition_name
  FROM $TBMA_COMPARISON_CONDITION
 WHERE project_id IN ($project_list)
 ~;
  my %valid_conditions = $sbeams->selectTwoColumnHash($sql);

  ## If data type is valid, retrieve information for readable conditions
  if ($data_type) {
	my $sql = "\nSELECT GE.canonical_name,\n";

	## For output screen
	print "GENE";

	foreach my $condition (@desired_conditions) {

	  if (my $condition_name = $valid_conditions{$condition}) {

		## For output screen
		print "\t$condition_name";

		$sql .= "MAX(CASE WHEN GE.condition_id = $condition THEN GE.lambda".
		  " ELSE NULL END) AS \"$condition_name\",\n";
	  }

	}
	## For output screen
	print "\n";

	
	## get rid of last comma in these case statements
	$sql =~ s/,\n$/\n/;

	$sql .= qq~
  FROM $TBMA_COMPARISON_CONDITION C
 INNER JOIN $TBMA_GENE_EXPRESSION GE ON ( C.condition_id = GE.condition_id )
  LEFT JOIN microarray.dbo.biosequence BS ON ( GE.biosequence_id = BS.biosequence_id )
 WHERE 1 = 1
   AND C.condition_id IN ( $condition_id )
 GROUP BY GE.canonical_name
 ORDER BY GE.canonical_name ASC
 ~;

	my @expression_values = $sbeams->selectSeveralColumns($sql);

	## Print data, if any is returned
	if (@expression_values){
	  foreach my $value (@expression_values) {
		my $gene_line = join "\t", @{$value};
		print $gene_line."\n";
	  }
	}

  }

  return;

} # end handle_request
