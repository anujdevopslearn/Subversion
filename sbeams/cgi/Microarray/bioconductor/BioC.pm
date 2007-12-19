package BioC;

use FileManager;
use POSIX;
use Digest::MD5 qw/md5_base64/;
use IPC::Open3;
use XML::LibXML;
use Site;
use strict;
use FindBin;

use lib "$FindBin::Bin/../../../lib/perl";
use SBEAMS::Connection::Settings;


our @ISA = qw/Exporter/; 
our @EXPORT = qw/rand_token check_email jobsummary 
				create_files start_job parse_sample_groups_file 
				first_key_val add_upload_expression_button
                 log_job parse_exprSet parse_aafTable create_directory/;

#### Subroutine: rand_token
# Generate a random token 8 characters long
####
sub rand_token {
	my $token = md5_base64(time * $$);
	$token =~ s/[+\/=]//g;
	return substr($token, 0, 8);
}

#### Subroutine: check_email
# Checks if e-mail address of user is a valid one. Returns 1 if valid.
####
sub check_email {
    my ($address) = @_;
    my $host;

	# More strict test, doesn't allow whitespace
	grep(/^[_a-zA-Z0-9-]+(\.[_a-zA-Z0-9-]+)*\@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$/, $address) ||
		return 0;
	
	# check that host in email address is ok
	$address =~ /([^\@]*)\@(.*)/;               # extract user and host names
	$host = $2;
	
	return 1;
}

#### Subroutine: jobsummary
# Creates the job summary table using pairs of arguments
####
sub jobsummary {
	my @args = @_;
	my $jobsummary = <<END;
<h3>Job Summary:</h3>
<table border="0" cellpadding="3" cellspacing="3">	
END
	
	for (my $i = 0; $i < @args; $i += 2) {
		$jobsummary .= '<tr><td align="right" valign="top">';
		$jobsummary .= $args[$i];
		$jobsummary .= '</td><td bgcolor="#CCCCCC">';
		$jobsummary .= defined($args[$i+1]) ? $args[$i+1] : "";
		$jobsummary .= "</td></tr>\n";
	}
	
	$jobsummary .= <<END;
</table>
END
	
}

#### Subroutine: create_directory ########################################
# Creates a directory 
#
########################################################
sub create_directory {
    my ($jobname) = @_;
   
    
    # Create job directory
    print STDERR "JOB DIR1 '$RESULT_DIR/$jobname'\n";
  	 umask(0000);					#delete for production
	 my $umask = umask();			#delete for production
    mkdir("$RESULT_DIR/$jobname", 0775) || 			
		return("Couldn't create result directory. '$RESULT_DIR/$jobname' ");
    #chown(-1, 1052, "$RESULT_DIR/$jobname");
    return undef;
}


#### Subroutine: create_files
# Creates the directory and files for running the job
####
sub create_files {
    my ($jobname, $script, $output, $jobsummary, $refresh, $title, $email) = @_;
    my $sh;
    
    # Create job directory
    #print STDERR "JOB DIR2 '$RESULT_DIR/$jobname'\n";
    unless (-d "$RESULT_DIR/$jobname"){
	    umask(0000);					#delete for production
		my $umask = umask();			#delete for production
	    
	    mkdir("$RESULT_DIR/$jobname", 0775) || 			
			return("Couldn't create result directory. '$RESULT_DIR/$jobname' ");
		
    }
	# Create R script file
	open(SCRIPT, ">$RESULT_DIR/$jobname/$jobname.R") ||
		return("Couldn't create R script file. '$RESULT_DIR/$jobname/$jobname.R' ");
	print SCRIPT $script;
	close(SCRIPT);
	
	# Create shell script file
  my $size = ( $jobname =~ /affynorm/ ) ? 1 : 4;
	$sh = generate_sh($jobname, $email, $size);
	open(SH, ">$RESULT_DIR/$jobname/$jobname.sh") ||
		return("Couldn't create shell script file.");
	print SH $sh;
	close(SH);
	chmod(0777, "$RESULT_DIR/$jobname/$jobname.sh");
	
    # Create processing index file
	open(INDEX, ">$RESULT_DIR/$jobname/index.html") ||
		return("Couldn't create HTML file.");
	print INDEX <<END;
<html>
<head>
<title>$title - Processing</title>
<meta http-equiv="refresh" content="$refresh">
<meta http-equiv="pragma" content="no-cache">
<meta http-equiv="expires" content="-1">
</head>
<body bgcolor="#FFFFFF">
<h3>Processing...</h3>
<p><a href="$RESULT_URL$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=index&file_ext=html">Click here</a> to manually refresh.</p>
<p><a href="$BIOC_URL/cancel.cgi?name=$jobname" target="_parent">Click here</a> to cancel the job.</p>
$jobsummary
</body>
</html>
END
	close(INDEX);
	chmod(0666, "$RESULT_DIR/$jobname/index.html");
	
	# Create results index file
	open(INDEXRESULT, ">$RESULT_DIR/$jobname/indexresult.html") ||
		return("Couldn't create HTML file.");
	print INDEXRESULT <<END;
<html>
<head>
<title>$title</title>
</head>
<body bgcolor="#FFFFFF">
$output
<h3>Output Archive:</h3>
<a href="$RESULT_URL?action=download&analysis_folder=$jobname&analysis_file=$jobname&file_ext=tar.gz">$jobname.tar.gz</a><br>
$jobsummary
</body>
</html>
END
	close(INDEXRESULT);
	
	# Create error index file
	open(INDEXERROR, ">$RESULT_DIR/$jobname/indexerror.html") ||
		return("Couldn't create HTML file.");
	print INDEXERROR <<END;
<html>
<head>
<title>$title - Error</title>
</head>
<body bgcolor="#FFFFFF">
<h3>Error:</h3>
<p>An error occured while processing the job. Please check the
input and try again. If the problem persists, please contact the
<a href="mailto:$ADMIN_EMAIL">site administrator</a>.</p>
<p><a href="$RESULT_URL$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=$jobname&file_ext=err">Click here</a> to see the error.</p>
$jobsummary
</body>
</html>
END
	close(INDEXERROR);
    
	return undef;
}

#### Subroutine: generate_sh
# Generate the shell script to run R
####
sub generate_sh {
	my ($jobname, $email, $resize) = @_;
  $resize ||= 4;
	my $sh;
	
	$sh = <<END;
#!/bin/sh
$SH_HEADER
R_LIBS=$R_LIBS
export R_LIBS
$R_BINARY --no-save < $RESULT_DIR/$jobname/$jobname.R 2> $RESULT_DIR/$jobname/$jobname.err
STATUS=\$?
if ([[ \$STATUS == 0 ]]) then
  if ([[ -n `find $RESULT_DIR/$jobname -name '*.png'` ]]) then
    for i in $RESULT_DIR/$jobname/*.png; do
      pngtopnm \$i | pnmscale -r $resize | pnmtopng > \$i.tmp
      mv \$i.tmp \$i
    done
  fi
  mv $RESULT_DIR/$jobname/indexresult.html $RESULT_DIR/$jobname/index.html
  touch $RESULT_DIR/$jobname/index.html
END

    $sh .= $DEBUG ? "" : <<END;
  #rm $RESULT_DIR/$jobname/$jobname.sh			#REMEMBER TO TURN BACK ON
  #rm $RESULT_DIR/$jobname/$jobname.R
  #rm $RESULT_DIR/$jobname/$jobname.out
  #rm $RESULT_DIR/$jobname/$jobname.err
  rm $RESULT_DIR/$jobname/indexerror.html
  rm $RESULT_DIR/$jobname/id
END
 
    $sh .= $email ? <<END : "";
  sendmail -r $ADMIN_EMAIL $email <<END_EMAIL
From: Bioconductor Web Interface <$ADMIN_EMAIL>
Subject: Job Completed: $jobname
To: $email

Your job has finished processing. See the results here:
$SERVER_BASE_DIR$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=index&file_ext=html

END_EMAIL
END

    $sh .= <<END;
  tar -czf /tmp/$jobname.tar.gz -C $RESULT_DIR $jobname
  mv /tmp/$jobname.tar.gz $RESULT_DIR/$jobname/ 
else 
  mv $RESULT_DIR/$jobname/indexerror.html $RESULT_DIR/$jobname/index.html
  touch $RESULT_DIR/$jobname/index.html
#  rm $RESULT_DIR/$jobname/indexresult.html
  chgrp affydata $RESULT_DIR/$jobname/$jobname.tar.gz
  chmod g+rw $RESULT_DIR/$jobname/*
END
 
    $sh .= $email ? <<END : "";
  sendmail -r $ADMIN_EMAIL $email <<END_EMAIL
From: Bioconductor Web Interface <$ADMIN_EMAIL>
Subject: Job Error: $jobname
To: $email

There was a problem while processing your job. See the error here:
$SERVER_BASE_DIR$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=error&file_ext=html

END_EMAIL
END

    $sh .= <<END;
fi
exit \$STATUS
END
}

#### Subroutine: log_job
# Log a job in a special file in the file manager. Returns a textual error
# message on failure.
####
sub log_job {
	my ($jobname, $title, $fm) = @_;
	my $path = $fm->path;
	my $time = time();
	
	return undef if (! $fm || ! $fm->path);
	
	#open(LOG, ">>$path/.log") ||
	 #   return("Couldn't write to log file");
	#print LOG "$jobname\t$title\t$time\n";
	#close(LOG);
	
	return undef;
}

#### Subroutine: parse_exprSet
# Parses exprSet properties out of an R data file
####
sub parse_exprSet {
	my ($filename, $name, $sampleNames, $geneNames, $annotation) = @_;
	my ($pid, $rdrfh, $wtrfh);
	my $error = "Unexpected error during parse. R not available?";
	
	$pid = open3($wtrfh, $rdrfh, 0, $R_LOCAL_BIN, '--no-save', '--quiet') ||
	    return("Couldn't start R.");
	
	print $wtrfh <<'END';
parseExprSet <- function(filename) {
  library(affy);
	if (!file.exists(filename))
		stop("File does not exist")
	name <- load(filename)
	if (length(name) != 1)
		stop("Wrong number of objects in file")
	expr <- get(name)
	if (class(expr) != "exprSet" && class(expr) != "ExpressionSet" )
		stop("Invalid object class")
	cat("\nname: ", name, "\n", sep = "")

# Changed DSC 06/2007, for new ExpressionSet  
#	samples <- colnames(attributes(expr)$exprs)
  samples <- colnames(exprs(expr))
  
  eset_obj <- attributes(expr);
	if (is.null(samples))
    stop("No sample names" )
	samples <- paste(samples, collapse = "\t")
	cat("\nsampleNames: ", samples, "\n", sep = "")

# Changed DSC 06/2007, for new ExpressionSet  
#	genes <- row.names(attributes(expr)$exprs)
	genes <- row.names(exprs(expr))

	if (is.null(genes))
		stop("No gene names")
	genes <- paste(genes, collapse = "\t")
	cat("\ngeneNames: ", genes, "\n", sep = "")

	cat("\nannotation: ", attributes(expr)$annotation, "\n", sep = "")
	cat("Parse Done\n")
}
END
	
	print { $wtrfh } "parseExprSet(\"$filename\")\n";
	
	while (<$rdrfh>) {
		if (/^(Error.*)/) {
			$error = read_error($rdrfh, $1);
			last;
		} elsif ($name && /^name: (.*)/) {
			$$name = $1;
		} elsif ($sampleNames && /^sampleNames: (.*)/) {
			@$sampleNames = split(/\t/, $1);
		} elsif ($geneNames && /^geneNames: (.*)/) {
			@$geneNames = split(/\t/, $1);
		} elsif ($annotation && /^annotation: (.*)/) {
			$$annotation = $1;
		} elsif (/^Parse Done/) {
			undef $error;
			last;
		}
	}
	
	print { $wtrfh } "\nq()\n";
	
	close($rdrfh);
	close($wtrfh);
	
	return $error;
}



#### Subroutine: parse_aafTable
# Parses aafTable properties out of an R data file
####
sub parse_aafTable {
	my ($filename, $name, $colnames, $colclasses, $probeids, $numrows) = @_;
	my ($pid, $rdrfh, $wtrfh);
	my $error = "Unexpected error during parse. R not available?";
	
	$pid = open3($wtrfh, $rdrfh, 0, $R_LOCAL_BIN, '--no-save', '--quiet') ||
	    return("Couldn't start R.");
	
	print $wtrfh <<'END';
parseAafTable <- function(filename) {
	if (!file.exists(filename))
		stop("File does not exist")
	name <- load(filename)
	if (length(name) != 1)
		stop("Wrong number of objects in file")
	aaftable <- get(name)
	if (class(aaftable) != "aafTable")
		stop("Invalid object class")
	cat("\nname: ", name, "\n", sep = "")

	colnames <- names(attributes(aaftable)$table)
	if (is.null(colnames))
		stop("No column names")
	colnames <- paste(colnames, collapse = "\t")
	cat("\ncolnames: ", colnames, "\n", sep = "")
	
	colclasses <- character(length(attributes(aaftable)$table))
	for (i in 1:length(colclasses))
	    colclasses[i] <- class(attributes(aaftable)$table[[i]][[1]])
	colclasses <- paste(colclasses, collapse = "\t")
	cat("\ncolclasses: ", colclasses, "\n", sep = "")

	probeids <- attributes(aaftable)$probeids
	probeids <- paste(probeids, collapse = "\t")
	cat("\nprobeids: ", probeids, "\n", sep = "")

	numrows <- length(attributes(aaftable)$table[[1]])
	cat("\nnumrows: ", numrows, "\n", sep = "")
	cat("Parse Done\n")
}
END
	
	print { $wtrfh } "parseAafTable(\"$filename\")\n";
	
	while (<$rdrfh>) {
		if (/^(Error.*)/) {
			$error = read_error($rdrfh, $1);
			last;
		} elsif ($name && /^name: (.*)/) {
			$$name = $1;
		} elsif ($colnames && /^colnames: (.*)/) {
			@$colnames = split(/\t/, $1);
		} elsif ($colclasses && /^colclasses: (.*)/) {
			@$colclasses = split(/\t/, $1);
		} elsif ($probeids && /^probeids: (.*)/) {
			@$probeids = split(/\t/, $1);
		} elsif ($numrows && /^numrows: (.*)/) {
			$$numrows = $1;
		} elsif (/^Parse Done/) {
		    undef $error;
			last;
		}
	}
	
	print { $wtrfh } "\nq()\n";
	
	close($rdrfh);
	close($wtrfh);
	
	undef @$probeids if ($probeids && @$probeids && $$probeids[1] eq "");
	
	return $error;
}

#### Subroutine: read_error
# Finishes reading an R error out of a filehandle
####
sub read_error {
	my ($fh, $error) = @_;
	
	while (<$fh>) {
		last if (/Execution halted/);
		$error .= $_;
	}
	
	$error =~ s/Error.*:\s*//s;
	chomp($error);
	
	return $error;
}

#### Subroutine: parse_sample_groups_file
# Parse the XML file containing the sample group information
#Return a hash of values
####
sub parse_sample_groups_file{
	my %args = @_;
	my $folder_name = $args{folder};
	my $data_type = $args{data_type};
	my $file = "$BC_UPLOAD_DIR/$folder_name/$SAMPLE_GROUP_XML";
	my $parse_setup = XML::LibXML->new();			#Object for parsing the file

	my $doc = $parse_setup->parse_file("$file");
	my $root  = $doc->getDocumentElement;
	my $xpath = 'file_sample_group_info/sample_groups/file_name';
	my $file_names_ns = $doc->findnodes($xpath);

	my %sample_groups = ();
	#print STDERR "IN PARSE SAMPLE";

	if ($data_type eq 'get_reference_sample'){
		my $reference_sample_group_node = $root->findnodes('//reference_sample_group');
    	my $reference_sample_group = $reference_sample_group_node->to_literal;
		
		return $reference_sample_group
	}

  #return just the sample group names and the class number 
	
	if ($data_type eq 'sample_group_ids'){
		#print STDERR "IN SAMPLE GROUP IDS SUB ";
		foreach my $file_name_node ($file_names_ns->get_nodelist) {	
			
			my $sample_group = $file_name_node->findnodes('./@sample_group_name')->string_value();
			my $class_number = $file_name_node->findnodes('./@class_number')->string_value();
			$sample_groups{$class_number} = $sample_group;
			
			#print STDERR "SAMPLE GROUP $sample_group => $class_number";
		}
		return ( \%sample_groups);
	}
	
  # return reference to hash with defined keys, each of which points to an arrayref
  # of some particular data associated with a file
  if ($data_type eq 'file_info'){
  my %info;
  foreach my $file_name_node ($file_names_ns->get_nodelist) {	
    push @{$info{file_names}}, $file_name_node->to_literal();
    push @{$info{sample_groups}}, $file_name_node->findnodes('./@sample_group_name')->string_value();
    push @{$info{sample_names}}, $file_name_node->findnodes('./@sample_name')->string_value();
    push @{$info{class_numbers}}, $file_name_node->findnodes('./@class_number')->string_value();
    }
  return ( \%info );
  }
	
	my $order_count = 1;
	foreach my $file_name_node ($file_names_ns->get_nodelist) {	
		my $sample_group = $file_name_node->findnodes('./@sample_group_name')->string_value();
		my $sample_name = $file_name_node->findnodes('./@sample_name')->string_value();
		my $class_number = $file_name_node->findnodes('./@class_number')->string_value();
		
		my $file_name = $file_name_node->to_literal;
	
		$sample_groups{$sample_group}{$file_name} = $order_count;
		$order_count++;
		
		$sample_groups{SAMPLE_NAMES}{$sample_name} = $class_number;
		
		#print "FILE NAME '$file_name' SMAPLE GROUP '$sample_group'\n";
	
	}
	return ( \%sample_groups);
	
}
#### Subroutine: first_key_val
# return the first key of a href
####
sub first_key_val{
		my $href = shift;
		
		foreach my $k (keys %$href){
			return $href->{$k};
		}
		
}


#### Subroutine: add_upload_expression_button
# Make button to upload files into GetExpression table
####

sub add_upload_expression_button{
	my %args = @_;
	my $token = $args{token};
	
my $html = <<END;
<br>
<h3>
	<a href="$CGI_BASE_DIR/Microarray/bioconductor/Upload_affy_get_expression_data.cgi?token=$token">
		Add Conditions to Get Expression Table
	</a>
</h3>
<br>
END
	return ($html);
                                  

}
