#!/usr/local/bin/perl -w

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use BioC;
use Site;
use strict;
use FindBin;
use lib "$FindBin::Bin/../../../lib/perl";
use SBEAMS::Connection qw($log $q);
use SBEAMS::Connection::Settings;
use SBEAMS::SolexaTrans::Tables;

use SBEAMS::SolexaTrans;
use SBEAMS::SolexaTrans::Settings;
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::SolexaTrans::Solexa_Analysis;


use vars qw ($sbeams $solexa_o $sbeamsMOD $cgi $q $current_username $USER_ID
  $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
  $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
  @MENU_OPTIONS %CONVERSION_H);


$sbeams    = new SBEAMS::Connection;
$solexa_o  = new SBEAMS::SolexaTrans::solexa_Analysis;
$solexa_o->setSBEAMS($sbeams);

$sbeamsMOD = new SBEAMS::SolexaTrans;
$sbeamsMOD->setSBEAMS($sbeams);

# Create the global CGI instance
#our $cgi = new CGI;
#using a single cgi in instance created during authentication
$cgi = $q;


if ($cgi->param('name')) {
    showjob();
} elsif ($cgi->param('topframe')) {
    topframe();
} else {
    error("Sorry there has been an error submiting the job");
}


#### Subroutine: showjob
# Show job results
####
sub showjob {

	my $jobname = $cgi->param('name');
	$jobname =~ s/^\s|\s$//g;
	
	grep(/[a-z]{1,8}-[a-zA-Z0-9]{8}/, $jobname) ||
		error("Invalid job name '$jobname'");
	
my $url = "$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=index&file_ext=html";	
   print $cgi->redirect("$url");
	
}

#### Subroutine: topframe
# Print the top frame for use in the frameset
####
sub topframe {

    print $cgi->header;    
	print "<html>
		     <body>",
		     site_header(),
		   " </body>
		   <html>";		

}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

	print $cgi->header;    
	site_header("Job Results Lookup");
	
	print h1("Job Results Lookup"),
	      h2("Error:"),
	      p($error);
	
	site_footer();
	
	exit(1);
}
