#!/usr/bin/perl -w

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use FileManager;
use Batch;
use BioC;
use Site;
use strict;

# Create the global CGI instance
our $cgi = new CGI;

# Create the global FileManager instance
our $fm = new FileManager;

# Handle initializing the FileManager session
if ($cgi->param('token') || $cgi->cookie('bioctoken')) {
    my $token = $cgi->param('token') ? $cgi->param('token') : 
                                       $cgi->cookie('bioctoken');
	if ($fm->init_with_token($UPLOAD_DIR, $token)) {
	    error('Upload session has no files') if !($fm->filenames > 0);
	} else {
	    error("Couldn't load session from token: ". $cgi->param('token')) if
	        $cgi->param('token');
	}
}

if ($cgi->param('token') && ! $cgi->param('file')) {
    select_file();
} elsif (! $cgi->param('step')) {
    step1();
} elsif ($cgi->param('step') == 1) {
    step2();
} else {
    error('There was an error in form input.');
}

#### Subroutine: step1
# Make step 1 form
####
sub step1 {
	my $filename = $cgi->param('file');
	my ($name, @colnames, @probeids, $err);
	if ($filename) {
		error('File not found.') if !$fm->file_exists($filename);
		$err = parse_aafTable($fm->path . "/$filename", \$name, \@colnames, 0, \@probeids, 0);
	    error($err) if $err;
	}

	print $cgi->header;    
	site_header('Affymetrix Probe Annotation: annaffy');
	
	print h1('Affymetrix Probe Annotation: annaffy'),
	      start_form,
	      hidden('step', 1),
	      '<table>',
		  '<tr><td style="vertical-align: top">',
	      p('Probe IDs:');
	      
	if ($filename) {
	    print hidden('token', $fm->token),
	          hidden('file', $filename),
	          hidden('name', $name),
	          hidden('probeids', join(', ', @probeids)),
	          p("<strong>", scalar @probeids, " in $filename</strong>"),
	          p("aafTable Columns:"),
	          p(scrolling_list('tablecols', [@colnames], [], scalar @colnames, 'true'));
	} else {
	    print p(textarea('probeids', '', 18, 30));
	}
	
	print '</td><td style="width: 25px"></td><td valign="top">',
		  p('Chip:'), 
		  p(popup_menu('chip', ['hgu133a', 'hgu133b', 'hgu95av2', 'hgu95b', 
		                        'hgu95c', 'hgu95d', 'hu6800', 'mgu74av2', 
		                        'mgu74b', 'mgu74c', 'rgu34a', 'rgu34b', 
		                        'rgu34c', 'rae230a', 'rae230b', 'YEAST'])),
		  p('Data Columns:'),
		  p(scrolling_list('colnames', ['Probe', 'Symbol', 'Description', 
		                                'Function', 'Chromosome', 
		                                'Chromosome Location', 'GenBank', 
		                                'LocusLink', 'Cytoband', 'UniGene', 
		                                'PubMed', 'Gene Ontology', 'Pathway'],
		                   [], 13, 'true')),
	      '</table>',
	      p('Web Page Title:', br(),
	        textfield('title', 'Affymetrix Probe Listing', 40)),
	      p("E-mail address where you would like your job status sent: (optional)", br(),
            textfield('email', '', 40)),
	      submit("Submit Job"),
	      end_form,
	      start_form,
	      p('Upload manager token:'),
	      p(textfield('token', $fm->token, 30)),
	      submit("Load File for Annotation"),
	      end_form;
	
	print <<'END';
<h2>Quick Help</h2>

<p>
Probe IDs can be separated by any combination of whitespace, commas,
semicolons, or quotation marks.
</p>

<p>
On a Macintosh, use Command-Click to select multiple items from
the data column list. On a PC, use Control-Click.
</p>

<p>
The e-mail address you provide will only give you information about
the completion status of your job. Make sure to bookmark the
following page as the URL will not come in the e-mail. The server
will delete your results after approximately a week. Probe annotations
typically take anywhere from 15 seconds (25 probes) to 13 minutes
(22,000 probes).
</p>

<p>
For further information, see the <a
href="/index.php?page=docs/annaffy.shtml">documentation page</a>.
</p>

<h2>Sample Data</h2>

<p>
Chip: hgu133a
</p>

<p>
207734_at, 218967_s_at, 217222_at, 65438_at, 207183_at, 215255_at,
202550_s_at, 212012_at, 215985_at, 202728_s_at, 204857_at, 212489_at,
41657_at, 219421_at, 205268_s_at, 221046_s_at, 222152_at, 213784_at,
207085_x_at, 215869_at, 202044_at, 217187_at, 205314_x_at, 206411_s_at,
215244_at
</p>
END
	
	site_footer();
}

#### Subroutine: select_file
# Make file selection form
####
sub select_file {
	my @filenames = $fm->filenames;

	print $cgi->header;
	site_header('Affymetrix Probe Annotation: annaffy');
	
	print h1('Affymetrix Probe Annotation: annaffy'),
	      start_form, 
	      hidden('token', $fm->token),
	      p("Select an aafTable for further annotation:"),
	      p(scrolling_list('file', \@filenames)),
	      p(submit("Next Step"));
	
	site_footer();
}

#### Subroutine: step2
# Handle step 1, redirect web browser to results
####
sub step2 {
	my $jobname = "aaf-" . rand_token();
	my $probeids = $cgi->param('probeids');
	$probeids =~ s/[,;"']/ /g;
	my @probeids = split(' ', $probeids);
	my ($script, $output, $jobsummary, $error, $job);
	
	if (!@probeids) {
		error("No probe ids specified.");
	}
	if (!$cgi->param('colnames')) {
		error("No data columns specified.");
	}
	if ($cgi->param('email') && !check_email($cgi->param('email'))) {
		error("Invalid e-mail address.");
	}
	
	$script = generate_r($jobname, [@probeids]);
	
	$output = <<END;
<h3>Output Files:</h3>
<a href="$jobname.html">$jobname.html</a><br>
<a href="$jobname.txt">$jobname.txt</a><br>
END

	$jobsummary = jobsummary("Probe&nbsp;IDs", join(', ', @probeids),
	                         "Chip", scalar($cgi->param('chip')),
	                         "Data&nbsp;Columns", join(', ', $cgi->param('colnames'), $cgi->param('tablecols')),
	                         "File", scalar($cgi->param('file')),
	                         "Title", scalar($cgi->param('title')),
	                         "E-Mail", scalar($cgi->param('email')));

	$error = create_files($jobname, $script, $output, $jobsummary, 5, 
	                      $cgi->param('title'), $cgi->param('email'));
	error($error) if $error;
	
	$job = new Batch;
    $job->type($BATCH_SYSTEM);
    $job->script("$RESULT_DIR/$jobname/$jobname.sh");
    $job->name($jobname);
    $job->out("$RESULT_DIR/$jobname/$jobname.out");
    $job->submit ||
    	error("Couldn't start job");
    open(ID, ">$RESULT_DIR/$jobname/id") || error("Couldn't write job id file");
    print ID $job->id;
    close(ID);
    log_job($jobname, $cgi->param('title'), $fm);
    
    print $cgi->redirect("job.cgi?name=$jobname");
}

#### Subroutine: generate_r
# Generate an R script to process the data
####
sub generate_r {
    my ($jobname, $probeids) = @_;
    my $chip = $cgi->param('chip');
    my @colnames = $cgi->param('colnames');
    my $title = $cgi->param('title');
    my ($script, $filename, $name, @tablecols, $fmpath);
    if ($cgi->param('tablecols')) {
        $filename = $cgi->param('file');
        $name = $cgi->param('name');
        @tablecols = $cgi->param('tablecols');
        $fmpath = $fm->path;
    }
  
    # Escape double quotes to prevent nasty hacking
    for (@$probeids) { s/\"/\\\"/g }
    $chip =~ s/\"/\\\"/g;
    for (@colnames) { s/\"/\\\"/g }
    $title =~ s/\"/\\\"/g;
    if ($cgi->param('tablecols')) {
        $filename =~ s/\"/\\\"/g;
        $name =~ s/\"/\\\"/g;
        for (@tablecols) { s/\"/\\\"/g }
    }
  
  	# Make R variables out of the perl variables
  	$script = $cgi->param('tablecols') ? <<END : "";
load("$fmpath/$filename")
aaftable <- get("$name")
tablecols <- c("@{[join('", "', @tablecols)]}")
END
  	$script .= <<END;
probeids <- c("@{[join('", "', @$probeids)]}")
chip <- "$chip"
colnames <- c("@{[join('", "', @colnames)]}")
title <- "$title"
END
  	
  	# Main data processing, entirely R
	$script .= <<'END';
library(annaffy)
ann <- aafTableAnn(probeids, chip, colnames)
END
	$script .= $cgi->param('tablecols') ? <<END : "";
ann <- merge(ann, aaftable[,tablecols, drop = FALSE]);
END

	# Output results
	$script .= <<END;
saveHTML(ann, "$RESULT_DIR/$jobname/$jobname.html", title)
saveText(ann, "$RESULT_DIR/$jobname/$jobname.txt")
END

	return $script;
}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

	print $cgi->header;    
	site_header("Affymetrix Probe Annotation: annaffy");
	
	print h1("Affymetrix Probe Annotation: annaffy"),
	      h2("Error:"),
	      p($error);
	
	site_footer();
	
	exit(1);
}