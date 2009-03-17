#!/tools64/bin/perl

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use Batch;
use SetupPipeline;
use Site;
use strict;
use lib "../../lib/perl";

use vars qw ($sbeams $sbeamsMOD $utilities $q $cgi $log $verbose $testonly
             $current_contact_id $current_username
            );

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::SolexaTrans::Tables;

use SBEAMS::SolexaTrans::Solexa;
use SBEAMS::SolexaTrans::SolexaUtilities;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SolexaTrans;
$utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
$utilities->setSBEAMS($sbeams);

$sbeamsMOD->setSBEAMS($sbeams);

$cgi = $q;

# Create the global CGI instance
#our $cgi = new CGI;

exit unless ($current_username = $sbeams->Authenticate());

if ($cgi->param('jobname')) {
    canceljob();
} else {
    form();
}

#### Subroutine: form
# Print the show job results form
####
sub form {
        $sbeams->output_mode('html'); 
        $sbeamsMOD->printPageHeader();

	site_header("Cancel Job");
	
	print h1("Cancel Job");
        print start_form(-method=>'GET', -name=>'Cancel Job', -action=>'cancel.cgi');
	print p("Enter the job name:");
        print p(textfield("jobname", "", 30));
	print submit("submit", "Cancel Job");
	print end_form;

    print <<'END';
<h2>Quick Help</h2>

<p>
This form allows you to cancel jobs currently running. You must 
know the job name to do so.
</p>
END
	
	site_footer();
        $sbeamsMOD->printPageFooter();
}

#### Subroutine: canceljob
# Show job results
####
sub canceljob {
    my ($job, $id);

    # job is the full path of the job (/solexa/hood/<project name>/SolexaTrans/<job name>/
    my $jobname = $cgi->param('jobname') || error("No Job supplied");
    $jobname =~ s/^\s|\s$//g;

    grep(/stp-ssid[0-9]{1,6}-[a-zA-Z0-9]{8}/, $jobname) ||
	error("Invalid job name");
	
    my $analysis_id = $utilities->check_sbeams_job('jobname' => $jobname);
    error("Could not find a job with that name in SolexaTrans") unless $analysis_id;
    my $path = $utilities->get_sbeams_job_output_directory('jobname' => $jobname);

    opendir(DIR, "$path") ||
       error("Cannot find that job name");
    closedir(DIR);
	
    open(ID, "$path/$jobname/id") ||
	    error("That job is no longer running");
    $id = <ID>;
    close(ID);
    if (!$id) { error("No PID in job ID"); }
    $job = new Batch;
    $job->type($BATCH_SYSTEM);
    $job->name($jobname);
    $job->id($id);
    $job->cancel ||
	    error("Couldn't cancel job");
    unlink("$path/$jobname/id");
    rename("$path/$jobname/indexerror.html", "$path/$jobname/index.html") || 
            error("couldn't rename $path/$jobname/indexerror.html to $path/$jobname/index.html");
    open(ERR, ">>$path/$jobname/$jobname.err") || error("Couldn't write artificial out file $path/$jobname/$jobname.err");
    print ERR "Job canceled by user\n";

    my $rowdata_ref = {
                         status => 'CANCELED',
                         status_time => 'CURRENT_TIMESTAMP',
                      };
    print ERR "updating job status in db with\n";
    $sbeams->updateOrInsertRow(
                                 table_name => $TBST_SOLEXA_ANALYSIS,
                                 rowdata_ref => $rowdata_ref,
                                 PK => 'solexa_analysis_id',
                                 PK_value => $analysis_id,
                                 return_PK=>0,
                                 update=>1,
                                 add_audit_parameters=>1,
                               );
    close(ERR);
    $sbeamsMOD->printPageHeader();

    
    print h1("Cancel Job"),
    p("Job successfully canceled: <strong>$jobname</strong>");
    print "<div style=\"width:80%;\">&nbsp;</div>\n";
    $sbeams->printPageFooter();
}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

        $sbeamsMOD->printPageHeader();
	
	print h1("Cancel Job");

	print h2("Error:");
	print p($error);
	
        $sbeamsMOD->printPageFooter();
	
	exit(1);
}
