package SetupPipeline;

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
our @EXPORT = qw/rand_token jobsummary 
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


#### Subroutine: jobsummary
# Creates the job summary table using pairs of arguments
####
sub jobsummary {
	my @args = @_;
	my $jobsummary = <<END;
<h3>Job Summary:</h3>
<table border="0" cellpadding="3" cellspacing="3">	
END
	
	for (my $i = 0; $i < @args; $i += 3) {
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
    my ($dir,$jobname) = @_;
   
    
    # Create job directory
    print STDERR "JOB DIR1 '$dir/$jobname'\n";
  	 umask(0000);					#delete for production
	 my $umask = umask();			#delete for production
    mkdir("$dir/$jobname", 0775) || 			
		return("Couldn't create result directory. '$dir/$jobname' ");
    #chown(-1, 1052, "$dir/$jobname");
    return undef;
}


#### Subroutine: create_files
# Creates the directory and files for running the job
####
sub create_files {
    my %args = @_;
    my $dir = $args{dir};
    my $job_dir = $args{job_dir};
    my $jobname = $args{jobname};
    my $title = $args{title};
    my $jobsummary = $args{jobsummary};
    my $output = $args{output};
    my $refresh = $args{refresh};
    my $perl_script = $args{script};
    my $email = $args{email};
    
    # Create job directory
    #print STDERR "JOB DIR2 '$dir/$jobname'\n";
    unless (-d "$job_dir/$jobname"){
#	    umask(0000);					#delete for production
#		my $umask = umask();			#delete for production
	    
	    mkdir("$job_dir/$jobname", 0775) || 			
			return("Couldn't create result directory. '$job_dir/$jobname' ");
            chmod(0777,"$job_dir/$jobname");		#delete for production
    }

    # Create perl script that runs pipeline
    my $perl_script_name = $job_dir.'/'.$jobname.'/'.$jobname.'.pl';
    open(SCRIPT, ">$perl_script_name") ||
       return("Couldn't create perl script file. '$job_dir/$jobname/$jobname.pl' ");
    print SCRIPT $perl_script;
    close SCRIPT;
    chmod(0777,$perl_script_name) ||
      return("Couldn't change the mode of perl script. '$perl_script_name' ");

    # Generate Shell script
    my $sh = generate_sh( output_dir => $dir, 
                          job_dir => $job_dir, 
                          jobname => $jobname, 
                          email => $email, 
                          perl_script => $perl_script_name
                          );

    open (SH, ">$job_dir/$jobname/$jobname.sh") ||
      return("Couldn't create shell script. '$job_dir/$jobname/$jobname.sh' ");
    print SH $sh;
    close (SH);
    chmod(0777,"$job_dir/$jobname/$jobname.sh") ||
      return("Couldnt change the mode of shell script. '$job_dir/$jobname/$jobname.sh' ");

    # Create processing index file
	open(INDEX, ">$job_dir/$jobname/index.html") ||
		return("Couldn't create HTML file.");
	print INDEX <<END;
<html>
<head>
<title>$title - Running</title>
<meta http-equiv="refresh" content="$refresh">
<meta http-equiv="pragma" content="no-cache">
<meta http-equiv="expires" content="-1">
</head>
<body bgcolor="#FFFFFF">
<h3>Running...</h3>
<p><a href="$RESULT_URL?action=view_file&analysis_folder=$job_dir/$jobname&analysis_file=index&file_ext=html">Click here</a> to manually refresh.</p>
<p><a href="$CGI_URL/cancel.cgi?jobname=$jobname" target="_parent">Click here</a> to cancel the job.</p>
$jobsummary
</body>
</html>
END
	close(INDEX);
	chmod(0666, "$job_dir/$jobname/index.html");
	
	# Create results index file
	open(INDEXRESULT, ">$job_dir/$jobname/indexresult.html") ||
		return("Couldn't create HTML file.");
	print INDEXRESULT <<END;
<html>
<head>
<title>$title</title>
</head>
<body bgcolor="#FFFFFF">
$output
<h3>Output Archive:</h3>
<a href="$RESULT_URL?action=download&analysis_folder=$job_dir/$jobname&analysis_file=$jobname&file_ext=tar.gz">$jobname.tar.gz</a><br>
$jobsummary
</body>
</html>
END
	close(INDEXRESULT);
	chmod(0666, "$job_dir/$jobname/indexresult.html");
	
	# Create error index file
	open(INDEXERROR, ">$job_dir/$jobname/indexerror.html") ||
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
<p><a href="$RESULT_URL?action=view_file&analysis_folder=$job_dir/$jobname&analysis_file=$jobname&file_ext=err">Click here</a> to see the error.</p>
<p>To re-run or delete this job, go the the <a href="$CGI_URL/status.cgi?jobname=$jobname" target="_parent">Status Page</a>.</p>
$jobsummary
</body>
</html>
END
	close(INDEXERROR);
	chmod(0666, "$job_dir/$jobname/indexerror.html");
    
	return undef;
}

#### Subroutine: generate_sh
# Generate the shell script to run the perl script and move files
####
sub generate_sh {
   my (%argHash)=@_;
    my @required_opts=qw(output_dir job_dir email jobname perl_script);
    my @missing=grep {!defined $argHash{$_}} @required_opts;
    die "missing opts: ",join(', ',@missing)." from supplied ",join(', ',%argHash) if @missing;

    my ($output_dir,$job_dir,$email,$jobname,$perl_script)=
        @argHash{qw(output_dir job_dir email jobname perl_script)};

    my $sh=<<"SH";
#!/bin/sh
#PBS -N $jobname
#PBS -M $email
#PBS -m ea
#PBS -o $jobname.out
#PBS -e $job_dir/$jobname/$jobname.err

touch $job_dir/$jobname/timestamp

SH

    my $cmd="/tools64/bin/perl $perl_script";

    die "$perl_script not found and/or not executable: $!" unless -x $perl_script;
#    $qsub.="perl $base_dir/echo.pl $opts\n"; # leave this around for debugging
    $sh.= "$cmd\n";

	
  $sh .= <<END;
STATUS=\$?
if ([[ \$STATUS == 0 ]]) then
  mv $job_dir/$jobname/indexresult.html $job_dir/$jobname/index.html
  touch $job_dir/$jobname/index.html
END

#  $sh .= $DEBUG ? "" : <<END;
  #rm $job_dir/$jobname/$jobname.sh			#REMEMBER TO TURN BACK ON
  #rm $output_dir/$jobname/$jobname.pl
  #rm $output_dir/$jobname/$jobname.out
  #rm $output_dir/$jobname/$jobname.err
  #rm $output_dir/$jobname/indexerror.html
  #rm $output_dir/$jobname/id
#END

  # RESULT_URL is a cgi path - ie: "$CGI_BASE_DIR/SolexaTrans/View_Solexa_files.cgi";

  $sh .= $email ? <<END : "";
  sendmail -r $ADMIN_EMAIL $email <<END_EMAIL
From: Bioconductor Web Interface <$ADMIN_EMAIL>
Subject: Job Completed: $jobname
To: $email

Your job has finished processing. See the results here:
$SERVER_BASE_DIR$RESULT_URL?action=view_file&jobname=$jobname&analysis_file=index&file_ext=html

END_EMAIL
END

  $sh .= <<END;
  tar -czf /tmp/$jobname.tar.gz -C $job_dir $jobname
  mv /tmp/$jobname.tar.gz $job_dir/$jobname
END

  $sh .= <<END;
  cp -r $job_dir/$jobname/*.tags $output_dir
  cp -r $job_dir/$jobname/*.ambg $output_dir
  cp -r $job_dir/$jobname/*.unkn $output_dir
  cp -r $job_dir/$jobname/*.stats $output_dir
  cp -r $job_dir/$jobname/*.cpm $output_dir
  chmod 777 $job_dir/$jobname
  chmod 777 $output_dir
else 
  mv $job_dir/$jobname/indexerror.html $job_dir/$jobname/index.html
#  touch $job_dir/$jobname/index.html
#  rm $job_dir/$jobname/indexresult.html
END
 
    $sh .= $email ? <<END : "";
  sendmail -r $ADMIN_EMAIL $email <<END_EMAIL
From: Bioconductor Web Interface <$ADMIN_EMAIL>
Subject: Job Error: $jobname
To: $email

There was a problem while processing your job. See the error here:
$SERVER_BASE_DIR$RESULT_URL?action=view_file&jobname=$jobname&analysis_file=index&file_ext=html

END_EMAIL
END

    $sh .= <<END;
fi
chmod 777 $job_dir/$jobname/*
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


