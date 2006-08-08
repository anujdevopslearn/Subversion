#!/usr/bin/perl -w

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
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

if ($cgi->param('Search Text')) {
    text();
} elsif ($cgi->param('Search Gene Ontology')) {
    go();
} elsif ($cgi->param('text')) {
    text();
} elsif ($cgi->param('go')) {
    go();
} else {
    form();
}

#### Subroutine: form
# Make search form form
####
sub form {
	my ($name, @colnames, @probeids, $err);

	print $cgi->header;    
	site_header('Affymetrix Probe Annotation: annaffy search');
	
	print h1('Affymetrix Probe Annotation: annaffy search'),
	      start_form,
	      hidden('step', 1),
	      p('Chip:'), 
		  p(popup_menu('chip', ['hgu133a', 'hgu133b', 'hgu95av2', 'hgu95b', 
		                        'hgu95c', 'hgu95d', 'hu6800', 'mgu74av2', 
		                        'mgu74b', 'mgu74c', 'rgu34a', 'rgu34b', 
		                        'rgu34c', 'rae230a', 'rae230b', 'YEAST'])),
	      p("E-mail address where you would like your job status sent: (optional)", br,
            textfield('email', '', 40));
    
    print h3('Text:'),
		  p(textfield('text', '', 40)),
		  p('Metadata Type: ', 
		    popup_menu('colnames', ['Probe', 'Symbol', 'Description', 
		                            'Function', 'Chromosome', 
		                            'Chromosome Location', 'GenBank', 
		                            'LocusLink', 'Cytoband', 'UniGene', 
		                            'PubMed', 'Gene Ontology', 'Pathway'])),
	      p(submit("Search Text"));
	      
	print h3('Gene Ontology ID:'),
		  p(textfield('go', '', 40)),
		  p(checkbox('descendents','checked','YES','Include descendents')),
	      p(submit("Search Gene Ontology"));
	      
	print end_form;
	
	print <<'END';
<h2>Quick Help</h2>

<p>
Search terms can be separated by either commas or semicolons.
</p>

<p>
Text searches are exact but case insensitive. Each search term is
treated as a Perl compatible regular expression.  For example, to
find BMP2-5, enter <strong>bmp[2-5]</strong> as the search text
and select Symbol as the metadata type.
</p>

<p>
To map a set of GenBank accession numbers onto a set of probe ids,
simply paste all the GenBank ids into the text field as a comma
separated list. (Spaces are okay.) Select GenBank for the metadata
type.
</p>

<p>
Gene Ontology ids can be entered either as bare integers or the
familiar GO:XXXXXXX format. A good site for finding gene ontology
ids is <a href="http://www.godatabase.org/">AmiGO</a>.
</p>
END
	
	site_footer();
}

#### Subroutine: text
# Handle text search, redirect web browser to results
####
sub text {
	my $jobname = "aafs-" . rand_token();
    my $text = $cgi->param('text');
    $text =~ s/^\s+|\s+$//g;
    $text =~ s/\s+[,;]|[,:]\s+/,/g;
	my @text = split(/[,;]/, $text);
	my ($script, $output, $jobsummary, $error, $job);
	
	if (!$cgi->param('colnames')) {
		error("No data columns specified.");
	}
	if (!$cgi->param('text')) {
		error("Please enter text to search.");
	}
	if ($cgi->param('email') && !check_email($cgi->param('email'))) {
		error("Invalid e-mail address.");
	}
	
	$script = generate_r_text($jobname, [@text]);
	
	$output = <<END;
<h3>Output Files:</h3>
<a href="$jobname.html">$jobname.html</a><br>
<a href="$jobname.txt">$jobname.txt</a><br>
END

	$jobsummary = jobsummary("Chip", scalar($cgi->param('chip')),
	                         "Metadata&nbsp;Type", join(', ', $cgi->param('colnames')),
	                         "Text", join(', ', @text),
	                         'E-Mail', scalar($cgi->param('email')));

	$error = create_files($jobname, $script, $output, $jobsummary, 5, 
	                      "Affymetrix Probe Search", $cgi->param('email'));
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
    log_job($jobname, $cgi->param('colnames') . " Search", $fm);
    
    print $cgi->redirect("job.cgi?name=$jobname");
}

#### Subroutine: generate_r_text
# Generate an R script to process the data
####
sub generate_r_text {
    my ($jobname, $text) = @_;
    my $chip = $cgi->param('chip');
    my @colnames = $cgi->param('colnames');
    my ($script);
    
    # Escape double quotes to prevent nasty hacking
    $chip =~ s/\"/\\\"/g;
    for (@colnames) { s/\"/\\\"/g }
    for (@$text) { s/\"/\\\"/g }
    
    $script .= <<END;
chip <- "$chip"
colnames <- c("@{[join('", "', @colnames)]}")
text <- c("@{[join('", "', @$text)]}")
END

    # Main data processing, entirely R
	$script .= <<'END';
library(annaffy)
probeids <- aafSearchText(chip, colnames, text)
if (!length(probeids))
    stop("No probe ids found")
colnames <- unique(c("Probe", colnames))
ann <- aafTableAnn(probeids, chip, colnames)
probeidstext <- strwrap(paste(probeids, collapse = ", "), width = 80)
END

    # Output results
	$script .= <<END;
saveHTML(ann, "$RESULT_DIR/$jobname/$jobname.html", "Affymetrix Probe Search")
outfile <- file("$RESULT_DIR/$jobname/$jobname.txt", "w")
cat(probeidstext, file = outfile, sep = "\\n")
close(outfile)
END

	return $script;
}

#### Subroutine: go
# Handle Gene Ontology search, redirect web browser to results
####
sub go {
	my $jobname = "aafs-" . rand_token();
    my $go = $cgi->param('go');
    $go =~ s/^\s+|\s+$//g;
    $go =~ s/\s+[,;]|[,:]\s+/,/g;
	my @go = split(/[,;]/, $go);
	my ($script, $output, $jobsummary, $error, $job);
	
	if (!$cgi->param('go')) {
		error("Please enter a Gene Ontology id to search.");
	}
	if (!grep(/[0-9]/, $cgi->param('go'))) {
		error("Gene Ontology ids must have numeric characters.");
	}
	if ($cgi->param('email') && !check_email($cgi->param('email'))) {
		error("Invalid e-mail address.");
	}
	
	$script = generate_r_go($jobname, [@go]);
	
	$output = <<END;
<h3>Output Files:</h3>
<a href="$jobname.html">$jobname.html</a><br>
<a href="$jobname.txt">$jobname.txt</a><br>
END

	$jobsummary = jobsummary("Chip", scalar($cgi->param('chip')),
	                         'Gene&nbsp;Ontology&nbsp;ids', join(', ', @go),
	                         'Descendents', $cgi->param('descendents') ? "Yes" : "No",
	                         'E-Mail', scalar($cgi->param('email')));

	$error = create_files($jobname, $script, $output, $jobsummary, 5, 
	                      "Affymetrix Probe Search", $cgi->param('email'));
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
    log_job($jobname, "Gene Ontology ID Search", $fm);
    
    print $cgi->redirect("job.cgi?name=$jobname");
}

#### Subroutine: generate_r_go
# Generate an R script to process the data
####
sub generate_r_go {
    my ($jobname, $go) = @_;
    my $chip = $cgi->param('chip');
    my $descendents = $cgi->param('descendents');
    my ($script);
    
    # Escape double quotes to prevent nasty hacking
    $chip =~ s/\"/\\\"/g;
    
    # Strip out non numeric characters
    for (@$go) { s/[^0-9]//g }
    
    $script .= <<END;
chip <- "$chip"
go <- c("@{[join('", "', @$go)]}")
descendents <- @{[$descendents ? "TRUE" : "FALSE"]}
END

    # Main data processing, entirely R
	$script .= <<'END';
library(annaffy)
probeids <- aafSearchGO(chip, go, descendents)
if (!length(probeids))
    stop("No probe ids found")
colnames <- c("Probe", "Gene Ontology")
ann <- aafTableAnn(probeids, chip, colnames)
probeidstext <- strwrap(paste(probeids, collapse = ", "), width = 80)
END

    # Output results
	$script .= <<END;
saveHTML(ann, "$RESULT_DIR/$jobname/$jobname.html", "Affymetrix Probe Search")
outfile <- file("$RESULT_DIR/$jobname/$jobname.txt", "w")
cat(probeidstext, file = outfile, sep = "\\n")
close(outfile)
END

	return $script;
}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

	print $cgi->header;    
	site_header("Affymetrix Probe Annotation: annaffy search");
	
	print h1("Affymetrix Probe Annotation: annaffy search"),
	      h2("Error:"),
	      p($error);
	
	site_footer();
	
	exit(1);
}
