#!/tools/bin/perl -w

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use POSIX;
use FileManager;
use Batch;
use BioC;
use Site;
use strict;
use Data::Dumper;
$Data::Dumper::Pad = "<br>";
$Data::Dumper::Pair = "<br><br>";


use FindBin;

use lib "$FindBin::Bin/../../../lib/perl";
use SBEAMS::Connection qw($log $q);
use SBEAMS::Connection::Settings;
use SBEAMS::Microarray::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::Affy_file_groups;
use SBEAMS::Microarray::Affy_Analysis;
use SBEAMS::Microarray::Affy_Annotation;





use vars qw ($sbeams $affy_o $sbeamsMOD $cgi $current_username $USER_ID
  $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
  $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
  @MENU_OPTIONS %CONVERSION_H);


$sbeams    = new SBEAMS::Connection;
$affy_o = new SBEAMS::Microarray::Affy_Analysis;
$affy_o->setSBEAMS($sbeams);

$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);

#### Do the SBEAMS authentication and exit if a username is not returned
	exit
	  unless (
		$current_username = $sbeams->Authenticate(
			permitted_work_groups_ref =>
			  [ 'Microarray_user', 'Microarray_admin', 'Admin' ],
			#connect_read_only=>1,
			#allow_anonymous_access=>1,
		)
	  );
##### Set some global vars
$PROG_NAME = $FindBin::Script;
my $base_url         = "$CGI_BASE_DIR/Microarray/bioconductor/$PROG_NAME";
my $affy_annotation_url = "$CGI_BASE_DIR/Microarray/GetAffy_GeneIntensity.cgi?action=SHOW_ANNO&probe_set_id=";

#####



# Create the global CGI instance
#our $cgi = new CGI;
#using a single cgi in instance created during authentication
$cgi = $q;

#### Read in the default input parameters
	my %parameters;
	my $n_params_found = $sbeams->parse_input_parameters(
		q              => $cgi,
		parameters_ref => \%parameters
	);

#### Process generic "state" parameters before we start
	$sbeams->processStandardParameters( parameters_ref => \%parameters );

### SAM test
our %sam_stats = ('sam' => "Welch's t-statistic");
our %sam_procs = ('sam' => "Run SAM......");


# Test statistic descriptions
our %tests = ('t'=>'two-sample Welch t-test (unequal variances)',
			  't.equalvar'=>'two-sample t-test (equal variances)',
			  'wilcoxon'=>'standardized rank sum Wilcoxon test',
			  'f'=>'F-test',
			  'pairt'=>'paired t-test',
			  'blockf'=>'block F-test');

# Multiple testing procedure descriptions
our %procs = ('Bonferroni'=>'Bonferroni single-step FWER',
              'Holm'=>'Holm step-down FWER',
              'Hochberg'=>'Hochberg step-up FWER',
              'SidakSS'=>'Sidak single-step FWER',
              'SidakSD'=>'Sidak step-down FWER',
              'BH'=>'Benjamini & Hochberg step-up FDR',
              'BY'=>'Benjamini & Yekutieli step-up FDR',
              'q'=>'Storey q-value single-step pFDR',
              'maxT'=>'Westfall & Young maxT permutation FWER',
              'minP'=>'Westfall & Young minP permutation FWER');

# Limit descriptions
our %limits = ('total'=>'a total number of', 
	           'teststat'=>'absolute test statistics greater than',
	           'rawp'=>'raw p-values less than', 
	           'adjp'=>'adjusted p-values less than');


# Create the global FileManager instance
our $fm = new FileManager;

# Handle initializing the FileManager session
if ($cgi->param('token') ) {
    my $token = $cgi->param('token');
    
	if ($fm->init_with_token($BC_UPLOAD_DIR, $token)) {
	    error('Upload session has no files') if !($fm->filenames > 0);
	} else {
	    error("Couldn't load session from token: ". $cgi->param('token')) if
	        $cgi->param('token');
	}
}

if (! $cgi->param('step')) {
    step1();
} elsif ($cgi->param('step') == 1) {
    $sbeamsMOD->printPageHeader();
    step2();
    $sbeamsMOD->printPageFooter();
} elsif ($cgi->param('step') == 2) {
    step3();
} elsif ($cgi->param('step') == 3) {
    step4();
} else {
    error('There was an error in form input.');
}

#### Subroutine: step1
# Make step 1 form
####
sub step1 {

	#print $cgi->header;    
	#site_header('Multiple Testing: multtest');
	
	print h1('Multiple Testing: multtest'),
	      h2('Step 1: NO LONGER WORKS PLEASE GO TO THE START OF THE UPLOAD PAGE AND TRY AGAIN'),
	    
	      p(a({-href=>"upload.cgi"}, "Go to Upload Manager"));

    
	
	site_footer();
}

#### Subroutine: step2
# Handle step 1, make step 2 form
####
sub step2 {
	my $test_stat = '';
	
	my $sample_groups_href = parse_sample_groups_file( folder =>$fm->token() );
	
	my $sample_group_count = (scalar keys %$sample_groups_href) - 1;#need to subtract one since one key is static {SAMPLE_NAMES}
	
	#print $cgi->header;    
	site_header();
	
	
	my $default_test_info = '';
	if (scalar $sample_group_count > 2){
		$test_stat = 'ANOVA';
		$default_test_info = <<'END';
<p>
You have more then 2 sample groups to compare.
To find differentially expressed genes you can run SAM or a one of t-test statistics
with some form of Multiple testing procedure.
Since you have more then two sample groups unless you choose some type of ANOVA test statistic
all the sample groups will be compared in a pairwise manor producing files of all the possible sample group 
pairs compared to the reference sample group.

</p>
END
	}else{
		$test_stat = 't_test';
		$default_test_info = << 'END';
You have 2 sample groups it appears you would like to run SAM
END
	}
	
	
	print h1('Multiple Testing: multtest'),
	      h2('Step 2:'),
	      start_form, 
	      hidden('token', $fm->token),
	      hidden(-name=>'step', -default=>2, -override=>1),
	      hidden(-name=>'numclasses', -default=>$sample_group_count, -override=>1),
	      hidden(-name=>'file', -default=>$cgi->param('file'), -override=>1),
	      p($default_test_info),
	      p('Select the test statistic'),
	     $cgi->radio_group(-name	=> 'test_stat',
                           -values  => ['SAM', 
                           				't_test'
                   					   ],
                           -default => 'SAM',
                           -linebreak=>'true',
                           ),
	      p(submit("Next Step")),
	      end_form;
	
	print <<'END';
<h2>Quick Help</h2>

<p>
For t-tests and Wilcoxon tests, there must only be 2 experimental
classes (generally a control and experimental class). However, for
the ANOVA F-test, you may have more than two classes.
</p>
<p>
SAM analysis description from Tusher et al. [1]  "SAM identifies genes with statistically significant changes in expression by assimilating 
a set of gene-specific <em>t</em> tests.  Each gene is assigned a score on the basis of its change 
in gene expression relative to the standard deviation of repeated measurements for that gene.  Genes with
scores greater than a threshold are deemed potentially significant.  The percentage of such genes
identified by chance is the false discovery rate (FDR).  To estimate the FDR, nonsense genes are identified
by analyzing permutations of the measurements.  The threshold can be adjusted to identify smaller or larger sets
of genes, and FDRs are calculated for each set."<br>
1)  Significance analysis of microarrays applied to the ionizing radiation response.
Proc Natl Acad Sci U S A. 2001 Apr 24;98(9):5116-21. Epub 2001 Apr 17. Erratum in: Proc Natl Acad Sci U S A 2001 Aug 28;98(18):10515. 

<p>
multtest includes several tests for differences in means (t-test,
F-test, etc.) as well as a number of procedures for controlling
the error rate for many simultaneous hypotheses. Such control is
very important in the context of microarray experiments. Additionally,
multtest provides the ability to make specific hypotheses about
groups of genes within a microarray experiment and can select genes
that meet certain testing criteria. Finally, muttest produces three
diagnostic plots, an MA plot, a quantile-quantile plot, and a
multiple testing procedure selectivity plot.
</p>

END

}

#### Subroutine: step3
# Handle step 2, make step 3 form
####
sub step3 {
	my $filename = $cgi->param('file');
	my $sample_groups_href = parse_sample_groups_file( folder => $fm->token() );
	
	my $test_stat = $cgi->param('test_stat');
	
	my $numclasses = $cgi->param('numclasses');
	my @filenames = $fm->filenames;
	my ($name, @sampleNames, $annotation, $err);
	
	my $token = $cgi->param('token');

	
	error('Please select an exprSet.') if !$filename;
	error('File not found.') if !$fm->file_exists($filename);
	if (grep(/[^0-9]|^$/, $numclasses) || !($numclasses > 0)) {
	    error('Please enter an integer greater than 0.');
	}
	
	$err = parse_exprSet($fm->path . "/$filename", \$name, \@sampleNames, 0, \$annotation);
	error($err) if $err;
###Print out the site header
	$sbeamsMOD->printPageHeader();
	$sbeams->printStyleSheet();
	site_header();
	
	print h1('Multiple Testing: multtest'),
	      h2('Step 3:'),
	      start_form, 
	      hidden('token', $fm->token),
	      hidden(-name=>'step', -default=>3, -override=>1),
	      hidden('file', $filename),
	      hidden('name', $name),
	      hidden('numsamples', scalar @sampleNames),
	      p("Sample Groups and Files:");
	 print "<table>";  
	
	my @classes = ();
### Print out little table showing files for each sample_group
	foreach my $sample_group (
						map {$_->[0]}
						sort {$a->[1] <=> $b->[1]}
						map {  [$_, &first_key_val( $sample_groups_href->{$_})] } 
	 					keys %$sample_groups_href){
		next if $sample_group eq 'SAMPLE_NAMES'; #skip key not pointing a sample group
			
		my $array_count = scalar keys %{ $sample_groups_href->{$sample_group} };
		print Tr(
			  td({-class=>'med_gray_bg'},"Sample Group"),
			  td({-class=>'rev_gray'},$sample_group)
			),
			Tr(
			  td($array_count > 1 ? {-class=>'grey_bg'}: {-class=>'orange_bg'}, 
			     $array_count > 1 ? "$array_count Files":"Warning: Minimum number of arrays for statistical tests is not met. At least two arrays are needed"  
			     ),
			  td([sort keys  %{ $sample_groups_href->{$sample_group} } ])
			);
	}
	print '</table>';

#	my @classes = (0 .. $numclasses-1, "Ignore");
	
	for (my $i = 0; $i < @sampleNames; $i++) {
	    my $sample_name = $sampleNames[$i];
	   	if (exists $sample_groups_href->{SAMPLE_NAMES}{$sample_name}){ 
    		my $class_number = $sample_groups_href->{SAMPLE_NAMES}{$sample_name};
    		print hidden (-name=>"class$i", -default=>$class_number, -override=>1);
    	}else{
    		print "CANNOT FIND CLASS FOR SAMPLE '$sample_name'<br>";
    	}
	    
	      # print Tr(td($sampleNames[$i]),
	   #          td(radio_group("class$i", \@classes, floor($i/(@sampleNames)*$numclasses))));
	}
	
	
	
	if ($test_stat eq 't_test'){
		print_t_test_controls();
	}elsif($test_stat eq 'SAM'){
		print_sam_controls();
	}else{
		print "<h2>Sorry method '$test_stat' not yet implemented</h2>";
		return;
	}
	
	 print p(checkbox('exprs','checked','YES','Include expression values in results')),
		  
		  p("Web Page Title:", br, textfield('title', 'Results:', 40)),
	      p("E-mail address where you would like your job status sent: (optional)", br,
            textfield('email', '', 40)),
          p(submit("Submit Job")),
	      hidden(-name=>'test_stat', -default=>$test_stat, -override=>1),
	      end_form;
	
	
	
	
    print <<'END';
<h2>Quick Help</h2>

<p>
The control group should almost always be in a lower class than
the experimental group so that positive test statistics indicate
increased expression and vice versa. 

</p>
<b>SAM -- Significance Analysis of Microarrays</b>
<p>
SAM.
It is possible to perform one and two class analyses using either 
a modified t-statistic or a (standardized) Wilcoxon rank statistic, 
and a multiclass analysis using a modified F-statistic.
</p>
<!-- Link to interal ISB copy of the paper -->
<p>For more information about SAM, click <a href='http://affy/pdf/44.pdf'>here</a> 
to view the paper by Tusher et al. 
</p>


<hr>
<p>
For more information about multiple testing, see these two papers:
</p>

<p>
Y. Ge, S. Dudoit, and T. P. Speed (2003). Resampling-based multiple
testing for microarray data analysis. <em>TEST</em>, Vol. 12, No.
1, p.  1-44 (plus discussion p. 44-77) <a
href="http://www.stat.berkeley.edu/~gyc/633.pdf">[PDF]</a>
</p>

<p>
S. Dudoit, J. P. Shaffer, and J. C. Boldrick (2003). Multiple
hypothesis testing in microarray experiments. <em>Statistical
Science</em>, Vol. 18, No. 1, p. 71-103. <a
href="http://www.bepress.com/cgi/viewcontent.cgi?article=1014&context=ucbbiostat">[PDF]</a>
</p>
END
	
    $sbeamsMOD->printPageFooter();
}





#### Subroutine: step4
# Handle step 3, redirect web browser to results
####
sub step4 {
	my $sample_groups_info_href = parse_sample_groups_file( folder => $fm->token(), data_type =>'sample_group_ids' );
	my $jobname = "mt-" . rand_token();
	my $test_stat = $cgi->param('test_stat');
	my $genenames = $cgi->param('genenames');
	$genenames =~ s/[,;"']/ /g;
	my @genenames = split(' ', $genenames);
	my ($script, $output, $jobsummary, $limit, @classlabel, $error, $job);
	
	if (grep(/[^0-9\.]|^$/, $cgi->param('limitnum')) || !($cgi->param('limitnum') > 0)) {
	    error('Please enter an number greater than 0.');
	}
	if ($cgi->param('email') && !check_email($cgi->param('email'))) {
		error("Invalid e-mail address.");
	}
	if (! $fm->file_exists($cgi->param('file'))) {
		error("File does not exist.");
	}
	
	my %count_groups =();
	for (my $i = 0; $i < $cgi->param('numsamples'); $i++) {
		my $class_numb = $cgi->param("class$i");
#need to see if any groups of arrays have a single array, flag error if so since 
#none of the statistical test will work with a single array
		if (exists $count_groups{$class_numb} ){
			$count_groups{$class_numb} ++;
		}else{
			$count_groups{$class_numb} = 1;
		}
		 
		$classlabel[$i] = $cgi->param("class$i");
	}
	
	check_for_single_array_group(%count_groups);

##If we are doing a pairwise analysis we might have more then one output file so we need to be aware of this information
	

	our @condition_names = ();
	our @condition_ids = ();
	my @class_a = ();
	my @sample_names_a = ();
	my $out_links = '';
	
	if ($cgi->param('test_stat') =~ /SAM|t_test/ && $cgi->param('test') !~ /f/){
		
		##Make some html that will be printed after analysis is complete
		my $button_html = add_upload_expression_button(token=>$jobname);
		
		foreach my $class_numb ( sort keys %{ $sample_groups_info_href }){
			push @class_a,  $class_numb;
			push @sample_names_a, $sample_groups_info_href->{$class_numb};
			$log->debug("CLASS NUMB => SAMPLE NAME " . $sample_groups_info_href->{$class_numb});
			
		}
##Setup little loop to make condition names which will be used to make unique file names and nice human readable names
		for (my $i=0; $i <= $#class_a ; $i++){
			next if $i == 0;
			my $condition_id = "$class_a[0]_vs_$class_a[$i]";
			my $condition_name = "$sample_names_a[0]_vs_$sample_names_a[$i]";
			$log->debug( "CONDITION ID '$condition_id' CONDITION SAMPLE '$condition_name'");
			
			$condition_name =~ s/\W//g;		#Clean up the name remove any non word characters
			push @condition_names, $condition_name;
			push @condition_ids, $condition_id;
			
#if we are looping through t-test or fdr analysis ouput then we need add links to the graphs 
			my $parital_url = "$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=${jobname}_$condition_name";
			my $parital_image_url = "$RESULT_URL?action=view_image&analysis_folder=$jobname&analysis_file=${jobname}_$condition_name";
			my $maqq = (grep(/^t/, $cgi->param('test'))) ? 
			"<img src='${parital_image_url}_ma&file_ext=png'>
			 <img src='${parital_image_url}_qq&file_ext=png'>" 
			: "";
			my $rvsa = ($cgi->param('limittype') eq 'fdr_cutoff') ? 
			"<img src='${parital_image_url}_delta&file_ext=png'>
			 <img src='${parital_image_url}_samplot&file_ext=png'>": 
			"<p><img src='${parital_image_url}_rvsa&file_ext=png'></p>";
			
#remove link to text version of html out	
#	<a href="$out_file.txt">$condition_name.txt</a><br>		
			$out_links .= <<END;
<h3>Output Files: $condition_name</h3>
<a href="$parital_url&file_ext=html">$condition_name.html</a><br>
<a href="$parital_url&file_ext=full_txt">All Genes - $condition_name.txt</a><br>
<a href="$RESULT_URL?action=download&analysis_folder=$jobname&analysis_file=$jobname&file_ext=aafTable">$condition_name.aafTable</a><br>			
$maqq
$rvsa
$button_html

END
			
		}
	}#End if 
##Either use the out links produced above or default to the simple ones below mainly by ANOVA type tests	
my $parital_url 	  = "$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=$jobname";
my $parital_image_url = "$RESULT_URL?action=view_image&analysis_folder=$jobname&analysis_file=$jobname";
				
	$out_links = $out_links ? 
	$out_links: 
"<h3>Output Files:</h3>
<a href='$parital_url&file_ext=html'>$jobname.html</a><br>
<a href='$parital_url&file_ext=txt'>$jobname.txt</a><br>
<a href='$RESULT_URL?action=download&analysis_folder=$jobname&analysis_file=$jobname'>$jobname.aafTable</a><br>
<p><img src='$parital_image_url&file_ext=rvsa.png'></p>";
			


$output = <<END;
<h3>Show analysis Data:</h3>
<a href="$CGI_BASE_DIR/Microarray/bioconductor/upload.cgi?_tab=3&token=$jobname&show_analysis_files=1">Show Files</a>
$out_links
END


	
###Gather information about the Files and Samples
### Use the file names to find what type of arrays they are and retrive the array name

	my $sample_groups_href = parse_sample_groups_file( folder => $fm->token() );
	my @classes 		= ();
	my @cell_file_names = ();
	foreach my $sample_group (sort keys %$sample_groups_href){
		next if $sample_group eq 'SAMPLE_NAMES';
		push @classes, $sample_group;
		push @cell_file_names,  keys %{ $sample_groups_href->{$sample_group} };
	}
	
	
	my $slide_type_name = $affy_o->find_slide_type_name(file_names=>[@cell_file_names]);
	error("Could not find Slide type name for Arrays @cell_file_names") unless $slide_type_name;
	
	
### Generate R script
	if ($cgi->param('limittype') eq 'fdr_cutoff'){
		$script = generate_sam_r(
						 jobname 	 => $jobname, 
						 classlabels => [@classlabel], 
						 condition_ids  => \@condition_ids,
						 condition_names=> \@condition_names,
						 genenames   => [@genenames],
						 slide_type_name  => $slide_type_name
						 
						 );
	}else{
		$script = generate_r(
						 jobname 	 => $jobname, 
						 classlabels => [@classlabel], 
						 condition_ids  => \@condition_ids,
						 condition_names=> \@condition_names,
						 genenames   => [@genenames],
						 slide_type_name  => $slide_type_name
						 );
	}

	my $limit_type = $limits{$cgi->param('limittype')} ? $limits{$cgi->param('limittype')}: $cgi->param('limittype');
	
	$limit = $cgi->param('limit') ? $limit_type . " " . 
	         $cgi->param('limitnum') : "None";
	
	my @job_summary_info = ('File', scalar($cgi->param('file')),
	                         'Class&nbsp;labels', join(', ', @classlabel),
	                         'File Names', join(', ',  @cell_file_names),
	                         'Class Names', join(', ', @sample_names_a),
	                         'Class Ids', join(', ', @class_a),
	                         'Test', $tests{$cgi->param('test')}?$tests{$cgi->param('test')}:$cgi->param('test_stat'),
	                         'Raw&nbsp;p-values', scalar($cgi->param('rawpcalc')),
	                         'Side', scalar($cgi->param('side')),
	                         'Procedure', $procs{$cgi->param('proc')},
	                         'Limit', $limit,
	                         'Gene&nbsp;names', join(', ', @genenames),
	                         'Expression', $cgi->param('exprs') ? "Yes" : "No",
	                         'Copy&nbsp;back', $cgi->param('fmcopy') ? "Yes" : "No",
	                         'Title', scalar($cgi->param('title')),
	                         'E-Mail', scalar($cgi->param('email')));
##Want differnt format in the database to track the job description so make it so....	                         
	 my @db_jobsummary = (	 'File Names =>'. join(', ',  @cell_file_names),
	 						 'Class&nbsp;labels =>'.  join(', ', @classlabel),
	 						 'Class Names =>'. join(', ', @sample_names_a),
	                         'Class Ids =>'  . join(', ', @class_a),
	                         'Test =>' . $tests{$cgi->param('test')}?$tests{$cgi->param('test')}:$cgi->param('test_stat'),
	                         'File =>' . scalar($cgi->param('file')),
	                         'Raw&nbsp;p-values =>'. scalar($cgi->param('rawpcalc')),
	                         'Side =>'. scalar($cgi->param('side')),
	                         'Procedure =>'. $procs{$cgi->param('proc')},
	                         "Limit => $limit",
	                         'Gene&nbsp;names =>' . join(', ', @genenames),
	                         'Expression =>' . ($cgi->param('exprs') ? "Yes" : "No"),
	                         'Copy&nbsp;back =>'. ($cgi->param('fmcopy') ? "Yes" : "No"),
	                         'Title =>'. scalar($cgi->param('title')),
	                         );
	
	$jobsummary = jobsummary(@job_summary_info);
	
	$error = create_files($jobname, $script, $output, $jobsummary, 20, 
	                      $cgi->param('title'), $cgi->param('email'));
	error($error) if $error;
	
	#Calculate the cpu time needed.  Inital test Affy Mouse chips could process < 7 comparisions in a hour
	my $chips_per_hour = 5;
	my $condition_count = scalar @condition_names;
	my $cpu_time = '';
	unless ($condition_count < $chips_per_hour){
		$cpu_time = ceil($condition_count/5);
		#format cpu time in HH:MM:SS
		$cpu_time = "$cpu_time:00:00";
	}
	$log->debug("CPU TIME '$cpu_time'");
	
	$job = new Batch;
    $job->cputime($cpu_time);
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

### Add info about analysis run to the database
	my $USER_ID = $affy_o->get_user_id_from_user_name($current_username);
	my $project_id	= $sbeams->getCurrent_project_id();
	
	my $data_analysis_o = $affy_o->check_for_analysis_data(project_id=>$project_id);
	error("Cannot Log New analysis Run") unless ($data_analysis_o);
	
	my ($folder_name) = grep {s/\.exprSet$//} ($cgi->param('file'));

	my $previous_analysis_id = '';
	($previous_analysis_id, undef) = $data_analysis_o->find_analysis_id(folder_name         =>$folder_name,
																        analysis_name_type  =>'normalization',
																        );
	$log->debug("PREVIOUS FOLDER NAME '$folder_name' PREVIOUS ANALYSIS ID '$previous_analysis_id' "); 
	my $rowdata_ref = {folder_name => $jobname,
					   user_id => $USER_ID,
					   project_id => $project_id,
					   parent_analysis_id => $previous_analysis_id,
					   affy_analysis_type_id => $affy_o->find_analysis_type_id("differential_expression"),
					   analysis_description => (join "//", @db_jobsummary),
					  };
	my $analysis_id = $affy_o->add_analysis_session(rowdata_ref => $rowdata_ref);


    print $cgi->redirect("job.cgi?name=$jobname");
}

#### Subroutine: generate_r
# Generate an R script to process the data
####
sub generate_r {
	my %args = @_;
	my $jobname    = $args{jobname};
	my $classlabel = $args{classlabels};
	my $genenames  = $args{genenames};
	my $slide_type_name  = $args{slide_type_name};
	
	my $conditions_ids_aref  = $args{condition_ids};
	my $conditions_names_aref  = $args{condition_names};
	
	
	
	my $fmpath = $fm->path;
	my $filename = $cgi->param('file');
	my $name = $cgi->param('name');
	my $proc = $cgi->param('proc');
	my $test = $cgi->param('test');
	my $rawpcalc = $cgi->param('rawpcalc');
	my $side = $cgi->param('side');
	my $limit = $cgi->param('limit');
	my $limittype = $cgi->param('limittype');
	my $limitnum = $cgi->param('limitnum');
	my $exprs = $cgi->param('exprs');
	my $title = $cgi->param('title');
	my $fmcopy = $cgi->param('fmcopy');
	my $script;
	my $annotation_info = add_r_annotation_info();
	# Escape double quotes to prevent nasty hacking
	$filename =~ s/\"/\\\"/g;
	$name =~ s/\"/\\\"/g;
	for (@$classlabel) { s/\"/\\\"/g }
	$proc =~ s/\"/\\\"/g;
	$test =~ s/\"/\\\"/g;
	$rawpcalc =~ s/\"/\\\"/g;
	$side =~ s/\"/\\\"/g;
	$limittype =~ s/\"/\\\"/g;
	$limitnum =~ s/\"/\\\"/g;
	$title =~ s/\"/\\\"/g;
	
	# Make R variables out of the perl variables
	$script = <<END;
jobname <- "$jobname"
load("$fmpath/$filename")
exprset <- get("$name")
classlabel <- c("@{[join('", "', @$classlabel)]}")
proc <- "$proc"
test <- "$test"
rawpcalc <- "$rawpcalc"
side <- "$side"
limit <- @{[$limit ? "TRUE" : "FALSE"]}
limittype <- "$limittype"
limitnum <- as.numeric("$limitnum")
genenames <- c("@{[join('", "', @$genenames)]}")
rlibpath <- "$R_LIBS"
if (!nchar(genenames[1]))
    genenames <- NULL
exprs <- @{[$exprs ? "TRUE" : "FALSE"]}
in.title <- "$title"

condition.ids <- c("@{[join('", "', @$conditions_ids_aref)]}")
condition.names <- c("@{[join('", "', @$conditions_names_aref)]}")


path.to.annotation <- "$AFFY_ANNO_PATH"
annotation.url <- "$affy_annotation_url"
chip.name <- "$slide_type_name"

##Add annotation info
$annotation_info
##End annotation setup
END

	# Main data processing, entirely R
	$script .= <<'END';
.libPaths(rlibpath)
library(Biobase)
library(multtest)
library(annaffy)
library(webbioc)

#Turn the annotation matrix into a dataframe
anno.df      <- data.frame(anno.matrix,  row.names = anno.matrix[,"Probe_set_id"])
full.anno.df <- data.frame(anno.matrix,  row.names = anno.matrix[,"Probe_set_id"])
#row.names(anno.df) <- anno.df$Probe_set_id
#HACK need to delete out the extra column of probe_ids for the html output
#and need to remove the url column from the text output
anno.df$Probe_set_id       <- NULL
full.anno.df$Probe_set_url <- NULL
##Make aaftable object from the annotation data
anno.aaftable      <- aafTableFrame(anno.df, signed = FALSE)
full.anno.aaftable <-aafTableFrame(full.anno.df, signed = FALSE)


##If we are doing ANOVA like test then do not loop all the conditions
if (any (grep("f", test)) ) {
	unique.classes <- classlabel
	
}else{
	unique.classes <- unique(classlabel)
}

for (class.numb in unique.classes){
	class.numb <- as.numeric(class.numb)
	if (class.numb == 0) {next}

##If this an ANOVA Like test then do not try and loop data
	if (any(grep("f", test)) ) {
		  cols <- which(classlabel != "Ignore")
		  current.classlabel <- as.integer(classlabel[cols])
		  condition.name <- "All_samples"
		  	
		  outFileRoot <- jobname
		  
	}else{
##Grab the cols for this particular loop
			cols <- c(which(classlabel == 0), which(classlabel == class.numb))
			current.classlabel <- as.integer(classlabel[cols])
##Change in classlabels greater than 1 to 1
			current.classlabel[which(current.classlabel>1)] <- 1
		
		if (length(condition.ids)>=1){
			condition.id <- condition.ids[class.numb] 
			condition.name <- condition.names[class.numb]
			outFileRoot <- paste(jobname, "_", condition.name, sep="")
			print (outFileRoot)
		}
	}
	
	#initilize and set the title
	title <- in.title
	title <- paste(title, condition.name)
	
	
	X <- exprs(exprset)[,cols]
	selected <- geneNames(exprset) %in% genenames
	if (!sum(selected) && !is.null(genenames))
	    stop("None of the entered gene names were found in the exprSet.")
	if (!sum(selected))
	    selected <- !selected
	mtdata <- mt.wrapper(proc, X[selected,,drop=F], current.classlabel, test, rawpcalc, side)
	index <- mtdata$index
	teststat <- mt.teststat(X, current.classlabel, test)
	adjp <- mtdata$adjp
	lim <- ! logical(dim(mtdata)[1])
	if (limit) {
		if (limittype == "total" && limitnum < length(lim))
		    lim[(limitnum+1):length(lim)] <- FALSE
		if (limittype == "teststat")
		    lim <- (abs(mtdata$teststat) > limitnum)
		if (limittype == "rawp")
		    lim <- (mtdata$rawp < limitnum)
		if (limittype == "adjp")
		    lim <- (mtdata$adjp < limitnum)
		if (!sum(lim))
		    stop("Specified limit produces no results.")
	}
	full.mtdata <- mtdata
	mtdata <- mtdata[lim,,drop=F]
	row.names(mtdata) <- geneNames(exprset)[which(selected)[index[lim]]]
	row.names(full.mtdata) <- geneNames(exprset)
	mtdata <- mtdata[2:4]
	full.mtdata <- full.mtdata[2:4]
	
	out.colnames <- c(paste(test, "statistic"), 
	 			  "raw p-value", 
	               paste("Adjusted p-value", proc, "-value", sep = ""))
	               
	colnames(mtdata)      <- out.colnames
	colnames(full.mtdata) <- out.colnames
	
	aaftable <- merge(aafTableFrame(mtdata[1], signed = (side == "abs")),
	                  aafTableFrame(mtdata[2:3]));
	                  
	#full.aaftable <- merge(aafTableFrame(full.mtdata[1], signed = (side == "abs")),
	#                  aafTableFrame(full.mtdata[2:3]));
	                  
	if (max(current.classlabel) == 1) {
	    x <- as.numeric(mean(as.data.frame(2^t(X[,(current.classlabel == 0)]))))
	    y <- as.numeric(mean(as.data.frame(2^t(X[,(current.classlabel == 1)]))))
	    fold <- y/x
	    foldlog2 <- log2(y/x)
    	foldlog10 <-log10(y/x)
#attach the log2 and log10 ratios to the output

	    my.colnames <- c("Fold Change", 
	    				 "mu_X",
	    				 "mu_Y",
	    				 "Log2 Ratio", 
	    				 "Log10 Ratio", 
	    				 colnames(mtdata))
    	mtdata <- cbind(fold[index[lim]], 
    					x[index[lim]],
    					y[index[lim]],
    					foldlog2[index[lim]], 
    					foldlog10[index[lim]], 
    					mtdata)
    	full.mtdata <- cbind(fold, 
    						 x,
    						 y,
    						 foldlog2, 
    						 foldlog10, 
    						 full.mtdata)
    
    	colnames(mtdata)     <- my.colnames
    	colnames(full.mtdata)<- my.colnames
    
    
    	aaftable <- merge(aafTable(items = list("Fold Change" = fold[index[lim]],
    							        "mu_X" =x[index[lim]],
    							        "mu_Y" = y[index[lim]],
    							        "Log2 Ratio"  = foldlog2[index[lim]],
    							        "Log10 Ratio" = foldlog10[index[lim]],
    							   		), colnames(items)
    							   		
    							   ), aaftable)
	}
	if (exprs) {
		mtdata <- cbind(mtdata, exprs(exprset)[index[lim],cols])
	    full.mtdata <- cbind(full.mtdata, exprs(exprset)[,cols])
	    aaftable <- merge(aaftable, aafTableInt(exprset[which(selected)[index[lim]],cols]))
	}
	if (!limit)
	    lim <- !lim
	limall <- logical(dim(X)[1])
	limall[which(selected)[lim[order(index)]]] <- TRUE;
	
	

END

	# Output results
	$script .= <<END;
#Write out the limited results set
limout.aaftable <- merge(full.anno.aaftable, aaftable)
saveText(limout.aaftable, 
paste("$RESULT_DIR/$jobname/", outFileRoot, ".txt", sep = ""), 
colnames = colnames(limout.aaftable)
)


#write out annotated HTML File
saveHTML(merge(anno.aaftable, aaftable), paste("$RESULT_DIR/$jobname/", outFileRoot, ".html", sep = ""), title)
##Write out the full results set
allData.aaftable <- aafTableFrame(full.mtdata, signed = FALSE)
out.aaftable <- merge(full.anno.aaftable, allData.aaftable)
saveText(out.aaftable, 
paste("$RESULT_DIR/$jobname/", outFileRoot, ".full_txt", sep = ""), 
colnames = colnames(out.aaftable)
)

END

	$script .= $fmcopy ? <<END : "";
save(aaftable, file = "$fmpath/$jobname.aafTable")
END

    # MA plot
    $script .= (grep(/t/, $test)) ? <<END : "";
bitmap(paste("$RESULT_DIR/$jobname/", outFileRoot, "_ma.png", sep = ""), res = 72*4, pointsize = 12)
macoords <- matrix(c(log2(sqrt(x*y)), log2(y/x)), ncol = 2)
plot(macoords, main=paste(condition.name,"M vs. A Plot"), xlab="A", ylab="M", type="n")
points(macoords[!selected,,drop=F], pch=20, col=grey(.5))
points(macoords[selected & !limall,,drop=F], pch=20)
points(macoords[selected & limall,,drop=F], pch=20, col="red")
dev.off()
END

    # Normal QQ plot
    $script .= (grep(/t/, $test)) ? <<END : "";
bitmap(paste("$RESULT_DIR/$jobname/", outFileRoot, "_qq.png", sep = ""), res = 72*4, pointsize = 12)
qqcoords <- qqnorm(teststat, type="n")
qqcoords <- matrix(c(qqcoords[[1]], qqcoords[[2]]), ncol = 2)
points(qqcoords[!selected,,drop=F], pch=20, col=grey(.5))
points(qqcoords[selected & !limall,,drop=F], pch=20)
points(qqcoords[selected & limall,,drop=F], pch=20, col="red")
qqline(teststat)
dev.off()
END

    # Selectivity plot
    $script .= <<END;
bitmap(paste("$RESULT_DIR/$jobname/", outFileRoot, "_rvsa.png", sep = ""), res = 72*4, pointsize = 12)
alpha <- seq(0, 0.99, length = 100)
r <- mt.reject(adjp[!is.na(adjp)], alpha)[["r"]]
plot(alpha, r, main = "Multiple Testing Procedure Selectivity", 
     xlab = "Error rate", ylab = "Number of rejected hypotheses", 
     type = "l")
if (limit)
    points(alpha[r<=sum(lim)], r[r<=sum(lim)], type = "l", col = "red")
dev.off()
END

$script .= <<END;
if (any(grep("f", test))){break} #do not loop if this is an ANOVA like test
} #end of for loop to loop conditions 
save(aaftable, file = "$RESULT_DIR/$jobname/$jobname.aafTable" )

END


}
#####################END generate_r

#### Subroutine: generate_sam_r
# Generate an R script to process the data using siggene bioconductor to run sam
####
sub generate_sam_r {
	my %args = @_;
	my $jobname    = $args{jobname};
	my $classlabel = $args{classlabels};
	my $conditions_ids_aref  = $args{condition_ids};
	my $conditions_names_aref  = $args{condition_names};
	my $slide_type_name  = $args{slide_type_name};
	
	
	my $fmpath = $fm->path;
	my $filename = $cgi->param('file');
	my $name = $cgi->param('name');
	
	my $limit = $cgi->param('limit');
	my $limittype = $cgi->param('limittype');
	my $limitnum = $cgi->param('limitnum');
	my $gene_limitnum = $cgi->param('gene_limitnum');
	my $exprs = $cgi->param('exprs');	#provide expression numbers in output
	my $title = $cgi->param('title');
	
	my $annotation_info = add_r_annotation_info();
	my $sort_data_frame = sortdataframe();
	my $script;
	
	# Escape double quotes to prevent nasty hacking
	$filename =~ s/\"/\\\"/g;
	$name =~ s/\"/\\\"/g;
	for (@$classlabel) { s/\"/\\\"/g }
	#$proc =~ s/\"/\\\"/g;
	#$test =~ s/\"/\\\"/g;
	#$rawpcalc =~ s/\"/\\\"/g;
	#$side =~ s/\"/\\\"/g;
	$limittype =~ s/\"/\\\"/g;
	$limitnum =~ s/\"/\\\"/g;
	$title =~ s/\"/\\\"/g;
	
	# Make R variables out of the perl variables
	$script = <<END;
load("$fmpath/$filename")
jobname <- "$jobname"
exprset <- get("$name")
classlabel <- c("@{[join('", "', @$classlabel)]}")

condition.ids <- c("@{[join('", "', @$conditions_ids_aref)]}")
condition.names <- c("@{[join('", "', @$conditions_names_aref)]}")

limit <- @{[$limit ? "TRUE" : "FALSE"]}
limittype <- "$limittype"
limitnum <- as.numeric("$limitnum")
gene.limitnum <- as.numeric("$gene_limitnum")
rlibpath <- "$R_LIBS"
exprs <- @{[$exprs ? "TRUE" : "FALSE"]}
in.title <- "$title"

path.to.annotation <- "$AFFY_ANNO_PATH"
annotation.url <- "$affy_annotation_url"
chip.name <- "$slide_type_name"

##Add annotation info
$annotation_info
##End annotation setup

##Add function to sort data frames
$sort_data_frame
##End function to sort data frames


END

	# Main data processing, entirely R
	$script .= <<'END';
.libPaths(rlibpath)
library(affy)
library(siggenes)
library(webbioc)


unique.classes <- unique(classlabel)

for (class.numb in unique.classes){
	class.numb <- as.numeric(class.numb)
	if (class.numb == 0) {next}
##Grab the cols for this particular loop
	cols <- c(which(classlabel == 0), which(classlabel == class.numb))
	current.classlabel <- as.integer(classlabel[cols])
##Change in classlabels greater than 1 to 1
	current.classlabel[which(current.classlabel>1)] <- 1
	
	if (length(condition.ids)>=1){
		condition.id <- condition.ids[class.numb] 
		condition.name <- condition.names[class.numb]
		outFileRoot <- paste(jobname, "_", condition.name, sep="")
		print (outFileRoot)
	}
##initilize the title var each loop
	title <- in.title
	
	Matrix <- exprs(exprset)[,cols]
	sam.output<-sam(Matrix,current.classlabel,rand=123)

#make a small matrix to hold the FDR cuttoffs and the ratio data
	numb.loops <- 1000
	delta.list <- seq(numb.loops)/50
	
	matrix.column.names <- c(
							"FDR", 
							"SAM_ratio", 
							"mu_X",
							"mu_Y",
							"Log_2_Ratio", 
							"Log_10_Ratio")
							
	gatherdataMatrix <- cbind(anno.matrix, matrix(data=1, nrow=length(anno.probesetid),ncol=length(matrix.column.names) ))
	
	colnames(gatherdataMatrix) <- c(colnames(anno.matrix), matrix.column.names)
	rownames(gatherdataMatrix) <- rownames(Matrix)
	
##Make the log 2 ratios from the data
	 x <- as.numeric(mean(as.data.frame(2^t(exprs(exprset)[,which(classlabel == 0)]))))
     y <- as.numeric(mean(as.data.frame(2^t(exprs(exprset)[,which(classlabel == class.numb)]))))
    foldlog2 <- log2(y/x)
    foldlog10 <-log10(y/x)
    gatherdataMatrix[,"mu_X"]   <- x
    gatherdataMatrix[,"mu_Y"]   <- y
    gatherdataMatrix[,"Log_2_Ratio"]   <- foldlog2
    gatherdataMatrix[,"Log_10_Ratio"]  <- foldlog10
    

	last.delta.cutoff <- 0
##Loop through all the fdr points collecting data fdr, fold change 
	for(i in 1:numb.loops){
		sum.sam.output <- try( summary(sam.output,delta.list[i],ll=FALSE))
 
		if (class(sum.sam.output) == "try-error" || i == numb.loops){
#if we are breaking out of the list since there are no more genes then set the last delta cutoff
#which produced some genes which will be used for graphing
			last.delta.cutoff <- delta.list[i-1]
			print (paste("LAST DELTA", last.delta.cutoff , "CONDITION" , condition.name, "I COUNT ", i))
			break
		}else{
 			gatherdataMatrix[sum.sam.output$row.sig.genes,"FDR"] <- sum.sam.output$mat.fdr[1,5]
			gatherdataMatrix[sum.sam.output$mat.sig[,1],"SAM_ratio"] <- sum.sam.output$mat.sig[,6]

		}
	}
##Convert data to a dataframe
	output.df <- data.frame(gatherdataMatrix)
	allData.output.df <- data.frame(gatherdataMatrix)
	
#HACK -- Need to cast all the data columns to numeric since they think they are class factor 
#see ?factor for more info
	for (n in matrix.column.names){
		output.df[[n]] <- as.numeric(levels(output.df[[n]] ))[output.df[[n]]]
		allData.output.df[[n]] <- as.numeric(levels(allData.output.df[[n]]))[allData.output.df[[n]]]
	}


	lim <- ! logical(dim(output.df)[1])
if (limit) {
	
	if (limittype == "fdr_cutoff"){
	    lim <- (output.df$FDR <= limitnum/100)
		if(length(which(lim)) > gene.limitnum){
			
			title = paste(title, 
						  "Genes Found at less then or equal to", 
						  limitnum, 
						  "% FDR <br> Sample Groups:", 
						  condition.name,
						  "<br>",
						  "Number of Differential expressed Genes",
						  length(which(lim)),
						  "<br>",
						  "Number of False Positives",
						  round(length(which(lim)) * (limitnum/100))
						  )#end of paste
						  
			output.df <- output.df[which(lim),]
		}else{
##if no genes were found at the predefined cutoff then start to search upwards looking for some genes
			newlimitNumb <- limitnum
			repeat{
				newlimitNumb <- newlimitNumb + 1

				lim <- (output.df$FDR <= newlimitNumb/100)
				if(length(which(lim)) > gene.limitnum){
					title = paste(title, 
							      "Genes Found with less then <font color='RED'>", 
							      newlimitNumb, 
							      "% FDR </font><br>Sample Groups:", 
							      condition.name,
							       "<br>",
								  "Number of Differential expressed Genes",
								  length(which(lim)),
								  "<br>",
								  "Number of False Positives",
								  round(length(which(lim)) * (newlimitNumb/100))
								  )#end of paste
							      
					output.df <- output.df[which(lim),]
					break
				}
				if(newlimitNumb > 95){
					title = paste(title, " Genes Found with greater then <font color='RED'>95% FDR</font>", newlimitNumb, "% FDR<br>Sample Groups:",condition.name)
					break
				}
			}
		}
			
	}
###Convert the FDR ratio to a percentage in both the dataframe and gatherdataMatrix
output.df$FDR <- output.df$FDR * 100
allData.output.df$FDR  <- allData.output.df$FDR * 100

###Sort the dataframe on the FDR column
output.df <- sort.data.frame(output.df, ~ +FDR)
allData.output.df<- sort.data.frame(allData.output.df, ~ +FDR)

##HACK: delete out the extra Column Probe_set_url from the allData.output.df since
##we don't want url's in the text output nor do we want the extra probe column in html output...
allData.output.df$Probe_set_url <- NULL
output.df$Probe_set_id <- NULL

###See if expression data should be outputed too
	if (exprs) {
		indexExprs.geneNames <- geneNames(exprset) %in% rownames(output.df)   
		index.allData <- geneNames(exprset) %in% rownames(allData.output.df)
	##Write a special aaftable that knows about exprssion data.  It will turn the values green in the output
		exp.aaftable <- aafTableInt(exprset[which(indexExprs.geneNames),cols])
		#output.df <- cbind(output.df, exprs(exprset)[which(indexExprs.geneNames),cols])
  	    allData.output.df <- cbind(allData.output.df, exprs(exprset)[which(index.allData),cols])
	}

END

$script .= <<END;
###Make aafTable object
	aaftable <- aafTableFrame(output.df, signed = FALSE)
	if (exprs){
		html.aaftable <- merge(aaftable,exp.aaftable)
	}else{
		html.aaftable <- aaftable
	}
	
	saveHTML(html.aaftable, paste("$RESULT_DIR/$jobname/", outFileRoot, ".html", sep = ""), title)
##Want to output the full data set in addition to just  differentially expressed genes.
	
	allData.aaftable <- aafTableFrame(allData.output.df, signed = FALSE)
		
	saveText(allData.aaftable, paste("$RESULT_DIR/$jobname/", outFileRoot, ".full_txt", sep = ""), colnames = colnames(allData.aaftable))
##Make some plots 
delta.graph.xstart <- 1.5
if(last.delta.cutoff < delta.graph.xstart){
	delta.graph.xstart <- .2
}
bitmap(paste("$RESULT_DIR/$jobname/", outFileRoot, "_delta.png", sep = ""), res = 72*4, pointsize = 12)
plot(sam.output, seq(delta.graph.xstart,last.delta.cutoff,.1))
dev.off()	

bitmap(paste("$RESULT_DIR/$jobname/", outFileRoot, "_samplot.png", sep = ""), res = 72*4, pointsize = 12)
plot(sam.output, last.delta.cutoff)
dev.off()
}#end of limit loop

}#end of the for loop to loop conditions 
save(aaftable, file = "$RESULT_DIR/$jobname/$jobname.aafTable")

END

}
####END generate_sam_r





#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

	print $cgi->header;    
	site_header("Multiple Testing: multtest");
	
	print h1("Multiple Testing: multtest"),
	      h2("Error:"),
	      p($error);
		foreach my $key ($cgi->param){
		
		print "$key => " . $cgi->param($key) . "<br>";
	}
	site_footer();
	
	exit(1);
}

#### Subroutine: print_t_test_controls
# Print out the web form section to start t-test analyis
####
sub print_t_test_controls{
	
	print '<br><br><table><tr><td>',
		 p("Differential Expression/Null Hypothesis Test:"),
		  p(scrolling_list('test', ['t', 't.equalvar', 'wilcoxon', 'f', 'pairt', 'blockf'], 
		                   ['t'], 6, '', \%tests)),
		  p("Raw/Nominal p-value calculation:"),
	      p(radio_group('rawpcalc', ['Parametric', 'Permutation'], 'Parametric')),
	      p("Side/Rejection Region:"),
	      p(radio_group('side', ['abs', 'upper', 'lower'], 'abs')),
	      '</td><td style="width: 25px"></td><td style="vertical-align: top">',
	      p("Multiple testing procedure:"),
	      p(scrolling_list('proc', ['Bonferroni', 'Holm', 'Hochberg', 'SidakSS', 'SidakSD', 
	                                'BY', 'BH', 'q', 'maxT', 'minP'], ['Bonferroni'], 10, '', \%procs)),
	      '</td></tr></table>',
	      p(checkbox('limit', 'checked', 'YES', ''),
	        "Limit results to",
	        popup_menu('limittype', ['total', 'adjp', 'rawp', 'teststat'], 'total', \%limits),
	        textfield('limitnum', 100, 10)),
	      p("Test only these gene names: (optional)", br, textarea('genenames', '', 5, 80)),
	      
	      '</td></tr></table>';
	     
}
#### Subroutine: print_sam_controls
# Print out the web form to start SAM analysis
####
sub print_sam_controls{


	print '<br><br>',
		  '<table><tr><td>',
		  p("Run SAM Analysis Two-class Unpaired Assuming Unequal Variances"),
		  p(checkbox('limit', 'checked', 'YES', ''),
		  "Limit the HTML Results to FDR percent cut off", 
		  hidden(-name=>'limittype', -default=>'fdr_cutoff'),
		  textfield(-name=>'limitnum',
                -default	=> 2,
                -size   	=> 3,
                -maxlength	=>3,
			 	-override => 1,
			 	), "% AND at least",
		  textfield(-name=>'gene_limitnum',
                -default	=> 10,
                -size   	=> 3,
                -maxlength	=>3,
			 	-override => 1,
			 	), "Genes"
		  ),;
			 	
}	      



#### Subroutine: add_r_annotation_info
# Return a chunk of R code to read in a Affy annotation file and extract certain columns
####
sub add_r_annotation_info {
	my $r_code = << 'END';
#read in the annotation file and make aafTable object
#Hard coded Affy Column NAMES BEWARE.......
annot <- read.csv(paste (path.to.annotation, "/" ,chip.name,"_annot.csv",sep=""),header=T)

#Grab all probeset ids from data frame make sure to cast to character class
anno.probesetid <- as.character(annot$Probe.Set.ID)
##Make urls for all the probeset ids
url.list <- c()
for ( id in anno.probesetid){
	url.list <- append(url.list, paste("<a href='", annotation.url, id, "'>", id, "</a>", sep=""), after=length(url.list))
}

anno.matrix <- cbind(
 "Probe_set_id" = anno.probesetid,
 "Probe_set_url" = url.list,
 "Gene_Symbol"= substr(as.character(annot$Gene.Symbol),1,254), 
 "Gene_Title" = substr(as.character(annot$Gene.Title),1,1023),
 "Unigene"    = substr(as.character(annot$UniGene.ID),1,254), 
 "LocusLink"  = substr(as.character(annot$LocusLink),1,254),
 "Public_ID"  = substr(as.character(annot$Representative.Public.ID),1,254),
 "Refseq_protein_ID" = substr(as.character(annot$RefSeq.Protein.ID),1,254)
)


END

return $r_code;
	
}


#### Subroutine: sortdataframe
# Return a chunk of R code. Function to sort a data frame
####
sub sortdataframe{
	my $r_code = <<'END';
	
sort.data.frame <- function(form,dat){
  # Author: Kevin Wright
  # Some ideas from Andy Liaw
  #   http://tolstoy.newcastle.edu.au/R/help/04/07/1076.html

  # Use + for ascending, - for decending.  
  # Sorting is left to right in the formula
  
  # Useage is either of the following:
  # library(nlme); data(Oats)
  # sort.data.frame(~-Variety+Block,Oats) # Note: levels(Oats$Block)
  # sort.data.frame(Oats,~nitro-Variety)

  # If dat is the formula, then switch form and dat
  if(inherits(dat,"formula")){
    f=dat
    dat=form
    form=f
  }
  if(form[[1]] != "~")
    stop("Formula must be one-sided.")

  # Make the formula into character and remove spaces
  formc <- as.character(form[2]) 
  formc <- gsub(" ","",formc) 
  # If the first character is not + or -, add +
  if(!is.element(substring(formc,1,1),c("+","-")))
    formc <- paste("+",formc,sep="")

  # Extract the variables from the formula
  if(exists("is.R") && is.R()){
    vars <- unlist(strsplit(formc, "[\\+\\-]"))    
  }
  else{
    vars <- unlist(lapply(unpaste(formc,"-"),unpaste,"+"))
  }
  vars <- vars[vars!=""] # Remove spurious "" terms

  # Build a list of arguments to pass to "order" function
  calllist <- list()
  pos=1 # Position of + or -
  for(i in 1:length(vars)){
    varsign <- substring(formc,pos,pos)
    pos <- pos+1+nchar(vars[i])
    if(is.factor(dat[,vars[i]])){
      if(varsign=="-")
        calllist[[i]] <- -rank(dat[,vars[i]])
      else
        calllist[[i]] <- rank(dat[,vars[i]])
    }
    else {
      if(varsign=="-")
        calllist[[i]] <- -dat[,vars[i]]
      else
        calllist[[i]] <- dat[,vars[i]]
    }
  }
  dat[do.call("order",calllist),]

}
END
	
	return($r_code);

}#end of sub

#### Subroutine: check_for_single_array_group
# loop thru a hash if a sample group only has one array throw an error
####
sub check_for_single_array_group {
	my %hash = @_;
	
	foreach my $k (keys %hash){
		if ( $hash{$k} == 1){
			error("Sample Group '$k' only has one Array and this is not allowed for any of the statistical test.  Please fix the problem and try again");
		}
	}
}

