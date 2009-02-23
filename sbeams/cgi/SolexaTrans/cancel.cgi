#!/usr/bin/perl -w

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use Batch;
use SetupPipeline;
use Site;
use strict;

# Create the global CGI instance
our $cgi = new CGI;

if ($cgi->param('name')) {
    canceljob();
} else {
    form();
}

#### Subroutine: form
# Print the show job results form
####
sub form {

    print $cgi->header;    
	site_header("Cancel Job");
	
	print h1("Cancel Job"),
	      start_form(-method=>'GET'),
	      p("Enter the job name:"),
	      p(textfield("name", "", 30)),
	      submit("submit", "Cancel Job"),
	      end_form;

    print <<'END';
<h2>Quick Help</h2>

<p>
This form allows you to cancel jobs currently running. You must 
know the job name to do so.
</p>
END
	
	site_footer();
}

#### Subroutine: canceljob
# Show job results
####
sub canceljob {
    my ($job, $id);

	my $jobname = $cgi->param('name');
	$jobname =~ s/^\s|\s$//g;
	
	grep(/[a-z]{1,6}-[a-zA-Z0-9]{8}/, $jobname) ||
		error("Invalid job name");
	
	opendir(DIR, "$RESULT_DIR/$jobname") ||
	    error("The results for that job name no longer exist");
	closedir(DIR);
	
	open(ID, "$RESULT_DIR/$jobname/id") ||
	    error("That job is no longer running");
	$job = new Batch;
    $job->type($BATCH_SYSTEM);
	$job->name($cgi->param('name'));
	$job->id(<ID>);
	close(ID);
	$job->cancel ||
	    error("Couldn't cancel job");
	unlink("$RESULT_DIR/$jobname/id");
	rename("$RESULT_DIR/$jobname/indexerror.html", "$RESULT_DIR/$jobname/index.html");
	open(ERR, ">$RESULT_DIR/$jobname/$jobname.err") || error("Couldn't write error file");
    print ERR "Job canceled by user";
    close(ERR);
	
	print $cgi->header;    
	site_header("Cancel Job");
	
	print h1("Cancel Job"),
	      p("Job successfully canceled: <strong>$jobname</strong>");
	
	site_footer();
}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

	print $cgi->header;    
	site_header("Cancel Job");
	
	print h1("Cancel Job"),
	      h2("Error:"),
	      p($error);
	
	site_footer();
	
	exit(1);
}
