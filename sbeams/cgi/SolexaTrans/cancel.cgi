#!/tools64/bin/perl

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use Batch;
use SetupPipeline;
use Site;
use Data::Dumper;
use Time::Local;
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
    # job is the full path of the job (/solexa/hood/<project name>/SolexaTrans/<job name>/
    my $jobname = $cgi->param('jobname') || error("No Job supplied");
    $jobname =~ s/^\s|\s$//g;

    grep(/stp-ssid[0-9]{1,6}-[a-zA-Z0-9]{8}/, $jobname) ||
	error("Invalid job name");
	
    my $analysis_id = $utilities->check_sbeams_job('jobname' => $jobname);
    error("Could not find a job with that name in SolexaTrans") unless $analysis_id;
    my $status_ref = $utilities->check_sbeams_job_status('jobname' => $jobname);
    my $status = $status_ref->[0];
    my $status_time = $status_ref->[1];
    if ($status ne 'QUEUED' && $status ne 'RUNNING') {
      if ($status eq 'CANCELED' || $status eq 'PROCESSED') {
        result("Job has already been canceled (Canceled at $status_time).");
      } else {
        my $ctime = `date +'%Y-%m-%d'`;
        my ($cyear, $cmonth, $cday) = split(/-/, $ctime);
        my ($syear, $smonth, $sday) = split(/-/, $status_time);
        my $cdate = timelocal(0,0,0,$cday, $cmonth -1, $cyear -1900);
        my $sdate = timelocal(0,0,0,$sday, $smonth -1, $syear -1900);
        my $diff = abs(($cdate - $sdate)/86400);
        if ($diff < 2) {  # if the number of days between the current day and the last status time update is less than 2
                          # then we want to not cancel the job.
          result("Job is currently '$status' and cannot be canceled. Status last updated at $status_time.");
        } else { # cancel the job because the job has likely died 
          my $path = $utilities->get_sbeams_job_output_directory('jobname' => $jobname);

          unlink("$path/$jobname/id");
          rename("$path/$jobname/indexerror.html", "$path/$jobname/index.html") || 
            update_db($analysis_id, "Couldn't rename $path/$jobname/indexerror.html to $path/$jobname/index.html",'PROCESSED');
          open(ERR, ">>$path/$jobname/$jobname.err") || 
            update_db($analysis_id, "Couldn't write artificial out file $path/$jobname/$jobname.err",'PROCESSED');
          print ERR "Job has been in UPLOADING status for more than 2 days.  Upload likely timed out. Job status set to PROCESSED.\n";
          close(ERR);

          update_db($analysis_id, "Job has been in UPLOADING status for more than 2 days. Upload likely timed out.  Job status set to PROCESSED.", $status);
        }
      }
    }  else { # job can be canceled, so start cancel procedure

#      my $path = $utilities->get_sbeams_job_output_directory('jobname' => $jobname);

      # no longer store job directory in 
      my $path = $sbeamsMOD->solexa_delivery_path();

      opendir(DIR, "$path/$jobname") ||
       update_db($analysis_id, "Cannot find that job name on disk - $path/$jobname");
      closedir(DIR);
    
      open(ID, "$path/$jobname/id") ||
	    update_db($analysis_id, "Could not find id for job $jobname - path is incorrect or job is no longer running.");
      my $id = <ID>;
      close(ID);
      if (!$id) { update_db($analysis_id, "No PID in job ID"); }
      my $job = new Batch;
      $job->type($BATCH_SYSTEM);
      $job->name($jobname);
      $job->id($id);
      $job->cancel ||
	    update_db($analysis_id, "That job is not currently running");

      unlink("$path/$jobname/id");
      rename("$path/$jobname/indexerror.html", "$path/$jobname/index.html") || 
            update_db($analysis_id, "Job canceled, but couldn't rename $path/$jobname/indexerror.html to $path/$jobname/index.html");
      open(ERR, ">>$path/$jobname/$jobname.err") || 
            update_db($analysis_id, "Job canceled, but couldn't write artificial out file $path/$jobname/$jobname.err");
      print ERR "Job canceled by user\n";
      close(ERR);

      update_db($analysis_id, "Job successfully canceled: <strong>$jobname</strong>");
   }
}

sub update_db {
  my $analysis_id = shift;
  my $message = shift;
  my $status = shift || 'CANCELED';

  my $rowdata_ref = {
                       status => $status,
                       status_time => 'CURRENT_TIMESTAMP',
                    };

  $sbeams->updateOrInsertRow(
                              table_name => $TBST_SOLEXA_ANALYSIS,
                              rowdata_ref => $rowdata_ref,
                              PK => 'solexa_analysis_id',
                              PK_value => $analysis_id,
                              return_PK=>0,
                              update=>1,
                              add_audit_parameters=>1,
                            );

  result($message. '. Status is '.$status);

}

#### Subroutine: result
# Print out an result message and exit
####
sub result {
    my ($result) = @_;

        $sbeamsMOD->printPageHeader();
	
	print h1("Cancel Job");

	print h2("Results:");
	print p($result);
	
        $sbeamsMOD->printPageFooter();
	
	exit(1);
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
