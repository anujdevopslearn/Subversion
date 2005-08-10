#!/usr/local/bin/perl 


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
require "/net/arrays/Pipeline/tools/bin/log_processor.pl";

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
    handle_request(ref_parameters=>\%parameters);
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
  my $SUB_NAME = "handle_request";

  ## Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  ## Show current user context information
  $sbeams->printUserContext();
  my $project_id = $parameters{'project_id'} || $sbeams->getCurrent_project_id();
  my $proc_event = $parameters{'proc_event'};

  my $output_dir = "/net/arrays/Pipeline/output/project_id";
  my $proc_dir = "$output_dir/$project_id/$proc_event";

  ## Comments
  if (-e "$proc_dir/comments") {
	print "<B><U>Processing Comments</U></B><BR>\n";
	open (COMMENTS, "$proc_dir/comments");
	while (<COMMENTS>) {
	  print "$_<BR>\n";
	}
  }
	
  ## Log Parser
  print "<B><U>Processing Summary</U></B><BR>\n";
  my @parsed_log = parse_log($proc_dir);
  print "<B><BR>";
  if (@parsed_log) {
	foreach my $line (@parsed_log){
	  print "$line<BR>\n";
	}
  }
  print "</B>\n";

  ## Files for Download
  my @log_list = glob("$output_dir/*.log");
  my @sig_list = glob("$output_dir/*.sig");
  my @clone_list = glob("$output_dir/*.clone");
  my @merge_list = glob("$output_dir/*.merge");
  my @rep_list = glob("$output_dir/*.rep");
  my @matrix_list = glob("$output_dir/matrix_output");
  my @zip_file = glob ("$output_dir/*.zip");
  my @tav_list = glob ("$output_dir/*.tav");


	## Scatter Plots
	print "<BR>\n";
	print "<B><U>Scatter Plots</U></B><BR>\n";
	print "<TABLE>\n";
	my @scatter_plots = glob("$proc_dir/*\.jpg");
	my $counter = 0;
	foreach my $image (@scatter_plots){
	  if (-e "$image"){
		my $title = $image;
		$title =~ s(^.*/)();
		if ($counter % 2 == 0){
		  print "<TR>\n";
	    }
		print qq~
		  <TD VALIGN="center"><B>$title</B></TD>
		  <TD><IMG SRC="http://db.systemsbiology.net/sbeams/cgi/Microarray/ViewFile.cgi?SUBDIR=$proc_event&FILE_NAME=$title&action=view_image" WIDTH=\"250\"><BR></TD>
		  ~;
		if ($counter % 2 == 1) {
		  print "</TR>\n";
		}
		$counter++;
	  }
	}
  print "</TABLE>\n";
  return;
} # end handle_request
