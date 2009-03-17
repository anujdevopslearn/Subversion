#!/usr/local/bin/perl 

###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use Data::Dumper;
use File::Basename;
use LWP::UserAgent;
use JSON;
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

# Template currently isn't installed in /tools
use lib qw (/local/wwwspecial/prion/software/GDxBase/lib/);
use Template;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS $DISPLAY_SUMMARY $template);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::SolexaTrans;
use SBEAMS::SolexaTrans::Settings;
use SBEAMS::SolexaTrans::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SolexaTrans;

$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$template = Template->new(INCLUDE_PATH => ['templates']);

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
$PROGRAM_FILE_NAME = 'JCR.cgi';
$DISPLAY_SUMMARY = "DISPLAY_SUMMARY";		#key used for a CGI param

main();
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  # Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    # connect_read_only=>1,
    # allow_anonymous_access=>1,
    # permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));


  # Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  # Process generic "state" parameters before we start
  $sbeams->processStandardParameters( parameters_ref=>\%parameters);

  if  ( $parameters{output_mode} =~ /xml|tsv|excel|csv/){
    # print out results sets in different formats
    print_output_mode_data(parameters_ref=>\%parameters);
  }else{
    # Gonna return a web page.
    $sbeamsMOD->printPageHeader();
    print_javascript();
    $sbeamsMOD->updateCheckBoxButtons_javascript();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }
} # end main


###############################################################################
# print_javascript 
##############################################################################
sub print_javascript {

    my $uri = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/";

print qq~
<SCRIPT LANGUAGE="Javascript">
<!--
<!-- $uri -->
function testFunc(){
 alert("clicked");
}   
    //Determines what browser is being used and what OS is being used.
    // convert all characters to lowercase to simplify testing
    var agt=navigator.userAgent.toLowerCase();
    
// *** BROWSER VERSION ***
    var is_nav  = ((agt.indexOf('mozilla')!=-1) && (agt.indexOf('spoofer')==-1)
                && (agt.indexOf('compatible') == -1) && (agt.indexOf('opera')==-1)
									 && (agt.indexOf('webtv')==-1));
var is_ie   = (agt.indexOf("msie") != -1);
var is_opera = (agt.indexOf("opera") != -1);

// *** PLATFORM ***
    var is_win   = ( (agt.indexOf("win")!=-1) || (agt.indexOf("16bit")!=-1) );
var is_mac    = (agt.indexOf("mac")!=-1);
var is_sun   = (agt.indexOf("sunos")!=-1);
var is_linux = (agt.indexOf("inux")!=-1);
var is_unix  = ((agt.indexOf("x11")!=-1) || is_linux);

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


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Define variables for Summary Section
  my $project_id = $parameters{PROJECT_ID} || $sbeams->getCurrent_project_id; 

  ## Need to add a MainForm in order to facilitate proper movement between projects.  
  # Otherwise some cgi params that we don't want might come through.
  print qq~ <FORM METHOD="post" NAME="MainForm" action="$CGI_BASE_DIR/$SBEAMS_SUBDIR/JCR.cgi">
       <INPUT TYPE="hidden" NAME="apply_action_hidden" VALUE="">
       <INPUT TYPE="hidden" NAME="set_current_work_group" VALUE="">
       <INPUT TYPE="hidden" NAME="set_current_project_id" VALUE="">
  </form>
  ~;

  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();

  my $json = new JSON;
  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  $ua->env_proxy;

  my $url = 'http://retina:8080/addama-rest/nextgen-samples/path/Samples/Sample-1';
  my $base_url = 'http://retina:8080/addama-rest/nextgen-samples/path/Samples/';
  my $sample = 'Sample-1';
  if ($parameters{sample}) {
    $sample = $parameters{sample};
  }

  my $response = $ua->get($base_url.$sample);

  if ($response->is_success) {
    my $content = $response->content;
    my $sample = $json->decode($content);
    my $file = 'sample.tt';
    $template->process($file,$sample) || die "Template process failed: ", $template->error(),"\n";
  } else {
    print $response->status_line;
  }
  return;

}# end handle_request



###############################################################################
# error_log
###############################################################################
sub error_log {
	my $SUB_NAME = 'error_log';
	
	my %args = @_;
	
	die "Must provide key value pair for 'error' \n" unless (exists $args{error});
	
	open ERROR_LOG, ">>SOLEXA_ERROR_LOGS.txt"
		or die "$SUB_NAME CANNOT OPEN ERROR LOG $!\n";
		
	my $date = `date`;
	
	print ERROR_LOG "$date\t$args{error}\n";
	close ERROR_LOG;
	
	die "$date\t$args{error}\n";
}


