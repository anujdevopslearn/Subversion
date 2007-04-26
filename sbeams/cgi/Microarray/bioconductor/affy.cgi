#!/usr/local/bin/perl -w

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use FileManager;
use Batch;
use BioC;
use Site;
use strict;


use XML::LibXML;
use FindBin;

use lib "$FindBin::Bin/../../../lib/perl";
use SBEAMS::Connection qw($log $q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::DataTable;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::Affy_Analysis;


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



# Create the global FileManager instance
our $fm = new FileManager;

# Handle initializing the FileManager session
if ($cgi->param('files_token') ) {
    my $token = $cgi->param('files_token') ;
	

	if ($fm->init_with_token($BC_UPLOAD_DIR, $token)) {
	    error('Upload session has no files') if !($fm->filenames > 0);
	} else {
	    error("Couldn't load session from token: ". $cgi->param('files_token')) if
	        $cgi->param('files_token');
	}
}else{
	error("Cannot start session no param 'files_token'");
}

if (! $cgi->param('step')) {
  $sbeamsMOD->printPageHeader();
	step1();
	$sbeamsMOD->printPageFooter();
    
} elsif ($cgi->param('step') == 1) {
  $sbeamsMOD->printPageHeader();
	step2();
	$sbeamsMOD->printPageFooter();
} elsif ($cgi->param('step') == 2) {
   step3();
} else {
   error('There was an error in form input.');
}

#### Subroutine: step1
# Make step 1 form
####
sub step1 {

	#print $cgi->header;    
	#site_header('Affymetrix Expression Analysis: affy');
	
	print h1('Affymetrix Expression Analysis: affy'),
	      h2('Step 1:'),
	      start_form,
	      hidden('step', 1),
	      p('Enter upload manager token:', textfield('token', $fm->token, 30)),
	      p('Enter number of CEL files:', textfield('numfiles', '', 10)),
	      submit("Next Step"),
	      end_form,
	      p(a({-href=>"upload.cgi"}, "Go to Upload Manager"));

    print <<'END';
<h2>Quick Help</h2>

<p>
affy performs low-level analysis of Affymetrix data and calculates
expression summaries for each of the probe sets. It processes the
data in three main stages: background correction, normalization,
and summarization. There are a number of different methods that
can be used for each of those stages. affy can also be configured
to handle PM-MM correction in several different ways.
</p>

<p>
To get started with affy, first upload all of your CEL files with
the upload manager. Make sure to note your upload manager token.
Next you must specify the number of CEL files to process. Generally,
you should process all the CEL files for an experiment at once, to
take maximum advantage of cross-chip normalization.
</p>
END
	
	site_footer();
}

#### Subroutine: step2
# Handle step 1, make step 2 form
####
sub step2 {
	
	my $numfiles = $cgi->param('numfiles');
	my %labels;
	
	if (grep(/[^0-9]|^$/, $numfiles) || !($numfiles > 0)) {
	    error('Please enter an integer greater than 0.');
	}

	 site_header('Affymetrix Expression Analysis: affy');
	
  my $normalization_token = $cgi->param('normalization_token');
	
	print h1('Affymetrix Expression Analysis: affy'),
	      h2('Step 2:'),
	      start_form, 
	      hidden('files_token', $fm->token),
	      hidden(-name=>'step', -default=>2, -override=>1),
	      hidden(-name=>'normalization_token', -value=>$normalization_token),
	      hidden(-name=>'analysis_id', -value=>$cgi->param('analysis_id')),
	      hidden('numfiles', $cgi->param('numfiles')),
	      p("Select files for expression analysis:");
	      
	print '<table>',
	      Tr(th('#'), th('File'), th('Sample Name'));
	

  my $file_info = parse_sample_groups_file( data_type => 'file_info',
                                            folder    => $normalization_token );
  my @file_names = @{$file_info->{file_names}};
  unless ( scalar @file_names == $numfiles ) {
    $log->error( "Mismatch! $numfiles reported, but found " . scalar( @file_names) );
  }
  my $i = 0;
	
	for my $sample_name ( @file_names ) {
    
    # Cache original name 
    my $file_name = $sample_name;
    
    # Remove the .CEL suffix to make a nice sample name
    $sample_name =~ s/\.CEL$//;	

    my $default_names = $cgi->param( 'default_sample_names' ) ||  'file_root';
    if ( $default_names eq 'sample_tag' ) {
      my $stagSQL =<<"      END";
      SELECT sample_tag 
      FROM $TBMA_AFFY_ARRAY_SAMPLE AAS JOIN  $TBMA_AFFY_ARRAY AA
      ON AAS.affy_array_sample_id = AA.affy_array_sample_id
      WHERE file_root = '$sample_name'
      END
      my ( $tag ) = $sbeams->selectOneColumn( $stagSQL );
      $sample_name = $tag if $tag;
    }
        
	    
    print Tr(td($i+1),
	           td({-bgcolor=>"#CCCCCC"},
	            	$cgi->textfield(-name=>"file$i",
                                -default=>$file_name,
                                -override=>1,
                                -size=>40,
                                -onFocus=>"this.blur()" )),
	             
	           td(textfield('sampleNames', $sample_name, 40)));
    $i++;
	}

  my $email = $sbeams->getEmailAddress();
	
	print '</table>',
		  p("Choose the processing method:"),
		  p($cgi->radio_group('process', ['RMA','GCRMA','PLIER'], 'RMA','true')),
		  "---- or ----",
		  p($cgi->radio_group('process', ['Custom'], '-')),
		  '<ul><table>',
		  Tr(td({-style=>"text-align: right"}, "Background Correction:"), 
		     td(popup_menu('custom', ['none', 'rma', 'rma2', 'mas' ], 'rma'))),
		  Tr(td({-style=>"text-align: right"}, "Normalization:"),
		     td(popup_menu('custom', ['quantiles', 'quantiles.robust', 'loess', 'contrasts', 'constant', 'invariantset', 'qspline', 'vsn'], 'quantiles'))),
		  Tr(td({-style=>"text-align: right"}, "PM Correction:"),
		     td(popup_menu('custom', ['mas', 'pmonly', 'subtractmm'], 'pmonly'))),
		  Tr(td({-style=>"text-align: right"}, "Summarization:"),
		     td(popup_menu('custom', ['avgdiff', 'liwong', 'mas', 'medianpolish', 'playerout', 'rlm'], 'medianpolish'))),
		  '</table></ul>',
		  p($cgi->checkbox('log2trans','checked','YES','Log base 2 transform the results (required for multtest)')),
		  p($cgi->checkbox('MVAplot','checked','YES','Produce MVA scatter plot among members of each sample group?')),
		  p($cgi->checkbox('corrMat','checked','YES','Produce correlation matrix for this normalization set?')),
		  p('Enter description for analysis set (optional)<BR>', $cgi->textfield('user_description', '', 40)),
		  p("E-mail address where you would like your job status sent: (optional)", br(), textfield('email', $email, 40)),
	      p(submit("Start Normalization")),
	      end_form;
	
    print <<'END';
<h2>Quick Help</h2>

<p>
For information about each of the processing methods, see Ben
Bolstad's PDF vignette, <a
href="http://www.bioconductor.org/repository/devel/vignette/builtinMethods.pdf">affy:
Built-in Processing Methods</a>. Not all of the methods work with
one another so consult that document first.
</p>

<p>
Variance Stabilization (vsn) is a background correction and
normalization method written as an add-on to affy. If you use it,
make sure to set background correction to "none" as vsn already
does this. For more information, see Wolfgang Huber's PDF vignette,
<a
href="http://www.bioconductor.org/repository/devel/vignette/vsn.pdf">Robust
calibration and variance stabilization with VSN</a>.
</p>

<p>
GCRMA is an expression measure developed by Zhijin Wu and Rafael
A. Irizarry.  It pools MM probes with similar GC content to form
a pseudo-MM suitable for background correction of those probe pairs.
To use GCRMA, select either gcrma-eb or gcrma-mle for Background
Correction and rlm for Summarization. For further information,
please see their paper currently under preparation, <a
href="http://www.biostat.jhsph.edu/~ririzarr/papers/gcpaper.pdf">A
Model Based Background Adjustement for Oligonucleotide Expression
Arrays</a>.  Also, please note that the gcrma R package is currenly
a developmental version.
</p>
END
#  $sbeams->printCGIParams( $cgi );
	
	site_footer();
}

#### Subroutine: step3
# Handle step 2, redirect web browser to results
####
sub step3 {
	my $jobname = '';

  
  # Modified to allow user to specify description on step_2 form.
  my $udesc = $cgi->param( 'user_description' ); 
  my $analysis_id = $cgi->param( 'analysis_id' ); 
  if ( $udesc && $analysis_id ) {
    $sbeams->updateOrInsertRow( table_name => $TBMA_AFFY_ANALYSIS ,
                               rowdata_ref => { user_description => $udesc },
                                   PK_name => 'affy_analysis_id',
                                  PK_value => $analysis_id,
                                    update => 1 );

    my ( $parent_id ) = $sbeams->selectOneColumn( <<"    END" );
    SELECT parent_analysis_id FROM $TBMA_AFFY_ANALYSIS 
    WHERE affy_analysis_id = $analysis_id 
    END

    if( $parent_id ) {
      $sbeams->updateOrInsertRow( table_name => $TBMA_AFFY_ANALYSIS ,
                                 rowdata_ref => { user_description => $udesc },
                                     PK_name => 'affy_analysis_id',
                                    PK_value => $parent_id,
                                      update => 1 );

    }
  }
	
	
	if ($cgi->param('normalization_token') ){
		$jobname = $cgi->param('normalization_token');
	}else{
		$jobname = "affy-norm" . rand_token();	
	}

	my (@filenames, $script, $output, $jobsummary, $custom, $error, $args, $job);
	my @custom = $cgi->param('custom');
	
	for (my $i = 0; $i < $cgi->param('numfiles'); $i++) {
		my $debug = $fm->path();
		error("File does not exist.") if !$fm->file_exists($cgi->param("file$i"));
			
		$filenames[$i] = $cgi->param("file$i");
	}
	
	if ($cgi->param('email') && !check_email($cgi->param('email'))) {
		error("Invalid e-mail address.");
	}
	
	if ($cgi->param('process') eq "Custom" && !expresso_safe(@custom)) {
	    error("Invalid custom processing method combination");
	}
	
	$output = <<END;
<h3>Show analysis Data:</h3>
<a href="$CGI_BASE_DIR/Microarray/bioconductor/upload.cgi?_tab=2&token=$jobname&show_norm_files=1">Show Files</a>
<h3>Output Files:</h3>
<a href="$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=${jobname}_annotated&file_ext=txt">${jobname}_annotated.txt</a><br>
<a href="$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=$jobname&file_ext=exprSet">$jobname.exprSet</a><br>
END
	
	$args = "";
	if ($cgi->param('process') eq "Custom") {
	    $args = ": " . join(' -> ', $cgi->param('custom'));
	}
	if ($cgi->param('process') eq "GCRMA") {
	    $args = "";  
	}
  my $log2trans = ($cgi->param('log2trans') ) ? "TRUE" : "FALSE";	   
  my $MVAplot = ($cgi->param('MVAplot') ) ? "TRUE" : "FALSE";	   
  my $corrMat = ($cgi->param('corrMat') ) ? "TRUE" : "FALSE";	   
	
	$jobsummary = jobsummary('Files', join(', ', @filenames),
                           'Sample&nbsp;Names', join(', ', $cgi->param('sampleNames')),
                           'Processing', scalar($cgi->param('process')) . $args,
                           'Log 2 Transform', $log2trans,
                           'MVAplot', $MVAplot,	   
                           'corrMat', $corrMat,	   
			#  'Copy&nbsp;back', $cgi->param('fmcopy') ? "Yes" : "No",
                           'E-Mail', scalar($cgi->param('email')));

  # update db with analysis run info, add user defined sample names to XML file
	 my @db_jobsummary = ('File Names =>' . join(', ', @filenames),
			     'Log 2 Transform' .  $cgi->param('log2trans')?"Yes":"No",
			     'Sample Names =>' . join(', ', $cgi->param('sampleNames')),
			     'Processing =>'. $cgi->param('process')
			   );
  update_analysis_table(@db_jobsummary);

  # Moved this up so as we can fetch the current names
  my @all_samples = $cgi->param('sampleNames');
  update_xml_file(token		=> $jobname,
    				sample_names=>\@all_samples,
    				file_name   =>\@filenames );

  if ( $cgi->param( 'MVAplot' ) || $cgi->param( 'corrMat' ) ) {
    $output .=<<"    END";
    <H3>Image files:</H3>
    <A HREF=$RESULT_URL?action=view_file&analysis_folder=$jobname&analysis_file=image_index&file_ext=html>
    View all image files inline</A><BR>
    END
  }

  # Table to hold images
  my $img_table = SBEAMS::Connection::DataTable->new(BORDER=>1);

  if ( $cgi->param('corrMat') ) {
    my $raw_url = "$RESULT_URL?action=view_image&analysis_folder=$jobname&analysis_file=raw_correlation_matrix&file_ext=png";
    my $norm_url = "$RESULT_URL?action=view_image&analysis_folder=$jobname&analysis_file=normalized_correlation_matrix&file_ext=png";

    # Add links to main results page
    $output .=<<"    END";
    <a href="$raw_url">Raw correlation matrix</a><br>
    <a href="$norm_url">Normalized correlation matrix</a><br>
    END
    
    # Add links to image page
    $img_table->addRow( [ "<A HREF=$raw_url target=_images ><IMG SRC='$raw_url' BORDER=0 WIDTH=600></A>" ] ); 
    $img_table->addRow( [ "<H2>Raw Correlation Matrix</H2>" ] );
    $img_table->addRow( [ "<A HREF=$raw_url target=_images ><IMG SRC='$norm_url' BORDER=0 WIDTH=600></A>" ] ); 
    $img_table->addRow( [ "<H2>Normalized Correlation Matrix</H2>" ] );
  }

  if ( $cgi->param('MVAplot') ) {
    # Need to see which ones we'll have plots for 
    my $info = BioC::parse_sample_groups_file( folder    => $jobname, 
                                               data_type => 'file_info' );

    # Hash keyed by group name, will hold number of files in group. 
    my %group_files;
    foreach ( @{$info->{sample_groups}} ) {
      $group_files{$_}++;
    }

    my %seenit;
    for my $grp ( @{$info->{sample_groups}} ) {

      # Only want to do this once
      next if $seenit{$grp};
      $seenit{$grp}++;

      # No plot if there is only one file in the group
      next if $group_files{$grp} < 2;

      my $mva_url = "$RESULT_URL?action=view_image&analysis_folder=$jobname&analysis_file=${grp}_MVA_matrix&file_ext=png";

      # Add links to main results page
      $output .= "<a href='$mva_url'>MVA comparison for file group $grp</a><br>";

      # Add links to image page
      $img_table->addRow( [ "<A HREF=$mva_url TARGET=_images BORDER=0><IMG SRC=$mva_url BORDER=0 WIDTH=600></A>" ] );
      $img_table->addRow( [ "<H2>MVA scatter plot for file group <B>$grp</B></H2>" ] );
    }
  }
  $img_table->setColAttr( ROWS => [1..$img_table->getRowNum()], COLS => [1], ALIGN=>'CENTER' );

  # This should be wrapped into create_files call, but not yet...
  createImageIndexPage( content => $img_table, path => "$RESULT_DIR/$jobname/" );

	$script = generate_r( jobname => $jobname, 
                        log2trans => $log2trans,
                        MVAplot => $MVAplot,
                        corrMat => $corrMat
                        );
	
	$error = create_files($jobname, $script, $output, $jobsummary, 15, 
	                      "Affymetrix Expression Analysis", $cgi->param('email'));
	error($error) if $error;
    
    $job = new Batch;
    $job->type($BATCH_SYSTEM);
    $job->script("$RESULT_DIR/$jobname/$jobname.sh");
    $job->name($jobname);
    $job->out("$RESULT_DIR/$jobname/$jobname.out");
    $job->submit ||
    	error("Couldn't start job in $RESULT_DIR");
    open(ID, ">$RESULT_DIR/$jobname/id") || error("Couldn't write job id file");
    print ID $job->id;
    close(ID);
    log_job($jobname, "Affymetrix Expression Analysis", $fm);

    print $cgi->redirect("job.cgi?name=$jobname");
}


#+
#
#-
sub createImageIndexPage {
  my %args = @_;
  my $page =<<"  END_PAGE";
<HTML>
<HEAD>
<TITLE='Normalization Images'></TITLE>
</HEAD>
<BODY>
<H2>Click on any image to see a larger version</H2><BR>
$args{content}
</BODY>
</HTML>
  END_PAGE
  open( IDX, ">$args{path}image_index.html" ) || die "Unable to open image index page";
  print IDX $page;
  close IDX;
}


#### Subroutine: generate_r
# Generate an R script to process the data
####
sub generate_r {
  my %args = @_;
  my $jobname = $args{jobname};
  my $info = BioC::parse_sample_groups_file( folder    => $jobname, 
                                             data_type => 'file_info' );

  my @files = @{$info->{file_names}};
	my @sampleNames = @{$info->{sample_names}};

  my $celfiles = \@files;
	$log->debug( join( ":::", @files) );
	$log->debug( join( ":::", @sampleNames) );
  
	my $celpath = $fm->path;
	my $process = $cgi->param('process');
	my @custom = $cgi->param('custom');
	my $fmcopy = $cgi->param('fmcopy');
	my $script;
	
	my $slide_type_name = $affy_o->find_slide_type_name(file_names=>$celfiles);
	
	# Escape double quotes to prevent nasty hacking
	for (@$celfiles) { s/\"/\\\"/g }
	for (@sampleNames) { s/\"/\\\"/g }
	$process =~ s/\"/\\\"/g;
	for (@custom) { s/\"/\\\"/g }
	
	# Make R variables out of the perl variables
  $script = <<END;
# fxn to create MVA plot for sets of arrays (courtesy BMarzolf)
mva.pairs.custom <- function (x, labels = colnames(x), log.it = TRUE, span = 2/3, 
    family.loess = "gaussian", digits = 3, line.col = 2, main = "MVA plot", 
    ...) 
{
    if (log.it) 
        x <- log2(x)
    J <- dim(x)[2]
    frame()
    old.par <- par(no.readonly = TRUE)
    on.exit(par(old.par))
    par(mfrow = c(J, J), mgp = c(0, 0.2, 0), mar = c(1, 1, 1, 
        1), oma = c(1, 1.4, 2, 1))
    for (j in 1:(J - 1)) {
        par(mfg = c(j, j))
        plot(1, 1, type = "n", xaxt = "n", yaxt = "n", xlab = "", 
            ylab = "")
        text(1, 1, labels[j], cex = .75)
        for (k in (j + 1):J) {
            par(mfg = c(j, k))


            yy <- rm.na(x[, j] - x[, k]);
            xx <- rm.na((x[, j] + x[, k])/2);

            if ( length(yy) != length(xx) ) {
              print( paste( "Error, vector lengths differ:", length(xx), "is not equal to", length(yy) ) );
            }

            sigma <- IQR(yy, na.rm =  TRUE );
            mean <- median(yy);

            subset <- sample(1:length(x), min(c(10000, length(x))))
            ma.plot(xx, yy, tck = 0, subset = subset, show.statistics = FALSE, 
                pch = ".", xlab = "", ylab = "", tck = 0, ...)
            par(mfg = c(k, j))
            txt <- format(sigma, digits = digits)
            txt2 <- format(mean, digits = digits)
            plot(c(0, 1), c(0, 1), type = "n", ylab = "", xlab = "", 
                xaxt = "n", yaxt = "n")
            text(0.5, 0.5, paste(paste("Median:", txt2), paste("IQR:", 
                txt), sep = "\n"), cex = 1 )
        }
    }
    par(mfg = c(J, J))
    plot(1, 1, type = "n", xaxt = "n", yaxt = "n", xlab = "", 
        ylab = "")
    text(1, 1, labels[J], cex = 1)
    mtext("A", 1, outer = TRUE, cex = 1.5)
    mtext("M", 2, outer = TRUE, cex = 1.5, las = 1)
    mtext(main, 3, outer = TRUE, cex = 1.5)
    invisible()
}
  
filenames <- c("@{[join('", "', @$celfiles)]}")
filepath <- "$celpath"
samples <- c("@{[join('", "', @sampleNames)]}")
process <- "$process"
custom <- c("@{[join('", "', @custom)]}")
log2trans <- $args{log2trans}
MVAplot <- $args{MVAplot}
corrMat <- $args{corrMat}
lib_path <- "$R_LIBS"
chip.name <- "$slide_type_name"
path.to.annotation <- "$AFFY_ANNO_PATH/"

END

# Count the files in each group
my %group_files;
foreach my $grp ( @{$info->{sample_groups}} ) {
  $grp =~ s/ +/_/g;
  $group_files{$grp}++;
}

# Generate plot code/dimensions for MVA and correlation plots.
my %mva_dim;
my $mva_code = '';
my $idx = 1;
my $tot = 0;
my %seenit;
foreach my $grp ( @{$info->{sample_groups}} ) {

  $grp =~ s/ +/_/g;
  
  # Will do this only once per group
  next if $seenit{$grp};
  $seenit{$grp}++;

  my $first = $idx;
  my $last = $first + $group_files{$grp} - 1;
  $idx = $last + 1;

  # If we have only one member in the group, don't try to do an MVA plot
  next unless ( $group_files{$grp} > 1 );

  $tot++;
  my $height = 3 + .12* $group_files{$grp};
  my $width  = 4 + .16* $group_files{$grp};

  $mva_code .=<<"  END_CODE";
  # Do MVA (scatterplot) matrix for $grp 
  bitmap( "$RESULT_DIR/$jobname/${grp}_MVA_matrix.png", height=$height, width=$width, res = 72*4, pointsize = 10)
  mva.pairs.custom(Matrix[,$first:$last])
  dev.off()
  END_CODE
}

my %corr_dims = ( height => 6, # + .04*$tot,
                  width  => 4 + .04*$tot,
                );

  # Main data processing, entirely R
  $script .= <<"END";
.libPaths(lib_path)
library(Biobase)
library(tools)
library(limma)
library(marray)
library(affy)
library(matchprobes)
library(splines)
library(gcrma)
library(vsn)
library(plier)
package.version('affy');
package.version('Biobase');
package.version('tools');
package.version('limma');
package.version('marray');
package.version('gcrma');
package.version('matchprobes');
package.version('splines');
package.version('vsn');

print ( paste( Sys.time(), "Loaded libraries" ));

bgcorrect.methods <- c(bgcorrect.methods, "gcrma")
normalize.AffyBatch.methods <- c(normalize.AffyBatch.methods, "vsn")
express.summary.stat.methods <- c(express.summary.stat.methods, "rlm")

#read in the annotation file
annot <- read.table(paste (path.to.annotation ,chip.name,"_annot.csv",sep=""),sep=",")
annot.orders <- order(annot[-1,1])
annot.header <- as.matrix(annot[1,])
annot.noheader <- annot[-1,]
annot.grab.columns <- c( grep("Representative Public ID",annot.header),grep("Gene Symbol",annot.header),grep("Gene Title",annot.header),grep("LocusLink",annot.header) )
print ( paste( Sys.time(), "Read annotation files" ));

# Set working directory, and read CEL files
setwd(filepath)

# Various circumstances dictate running affybatch
if (process == "Custom" || MVAplot || corrMat) {
  affybatch <- ReadAffy(filenames = filenames)
}

# Output a correlation matrix for pre-normalization data if requested.
if (corrMat) {
  pm <- pm(affybatch)# grab perfect match intensities
  affybatch.cor <- cor(pm)
  gray.colors <- gray(1:100/100) # define a grayscale color set
  numChips <- dim(exprs(affybatch))[2]
#  bitmap("$RESULT_DIR/$jobname/raw_correlation_matrix.png", height=$corr_dims{height}, width=$corr_dims{width}, res = 72*4, pointsize = 10)
  bitmap("$RESULT_DIR/$jobname/raw_correlation_matrix.png", height=$corr_dims{height}, res = 72*4, pointsize = 10)
  par(mar=c(3,3,3,9))
  image(x=1:numChips,y=1:numChips,affybatch.cor,col=gray.colors,zlim=c(min(affybatch.cor),1))
  title(paste("Correlation Matrix(Raw), black:R=",trunc(min(affybatch.cor)*100)/100,"white:R=1"),cex.main=numChips/15)
  for(i in 1:numChips) {
    name <- row.names(pData(affybatch))[i]
    text(numChips+1,i,name,xpd=TRUE,adj=c(0,0.5),cex=0.666)
  }
  dev.off() # dev.off() causes image file to be written
}

if (process == "RMA") {
#    exprset <- rma(ReadAffy(filenames = filenames))
# This is causing an error on Linux but not Mac OS X
# More investigation needed
    exprset <- justRMA(filenames = filenames) #changed 10.21.04 Bruz
}
if (process == "GCRMA"){
exprset <- justGCRMA(filenames = filenames)

}
if (process == "PLIER"){
exprset <- justPlier(eset=ReadAffy(filenames = filenames),normalize=TRUE)
exprs(exprset) <- log2( 2^exprs(exprset) + 16 )
}

if (process == "Custom") {
    bgcorrect.param <- list()
    if (custom[1] == "gcrma-eb") {
        custom[1] <- "gcrma"
        gcgroup <- getGroupInfo(affybatch)
        bgcorrect.param <- list(gcgroup, estimate = "eb", rho = 0.8, step = 60, 
                                lower.bound = 1, triple.goal = TRUE)
    }
    if (custom[1] == "gcrma-mle") {
        custom[1] <- "gcrma"
        gcgroup <- getGroupInfo(affybatch)
        bgcorrect.param <- list(gcgroup, estimate = "mle", rho = 0.8, 
                                baseline = 0.25, triple.goal = TRUE)
    }
    exprset <- expresso(affybatch, bgcorrect.method = custom[1],
                        bgcorrect.param = bgcorrect.param,
                        normalize.method = custom[2],
                        pmcorrect.method = custom[3],
                        summary.method = custom[4])
}
colnames(exprset\@exprs) <- samples
log2methods <- c("medianpolish", "mas", "rlm")
if (log2trans) {
    if (process == "Custom" && !(custom[4] %in% log2methods)) {
        exprset\@exprs <- log2(exprset\@exprs)
        exprset\@se.exprs <- log2(exprset\@se.exprs)
    }
} else {
    if (process == "RMA" || process == "Custom" && custom[4] %in% log2methods) {
        exprset\@exprs <- 2^exprset\@exprs
        exprset\@se.exprs <- 2^exprset\@se.exprs
    }
}

END


    # Output results
$script .= <<END;
#Add in the annotaion information
Matrix <- exprs(exprset)

if( corrMat ) {
  # Make correlation matrix of normalized data
  affybatch.cor <- cor(Matrix)
  bitmap("$RESULT_DIR/$jobname/normalized_correlation_matrix.png", height=$corr_dims{height}, res = 72*4, pointsize = 10)
  par(mar=c(3,3,3,9))
  image(x=1:numChips,y=1:numChips,affybatch.cor,col=gray.colors,zlim=c(min(affybatch.cor),1))
  title(paste("Correlation Matrix(normalized),black:R=",trunc(min(affybatch.cor)*100)/100,"white:R=1"),cex.main=numChips/15)
  for(i in 1:numChips) {
  name <- row.names(pData(affybatch))[i]
  text(numChips+1,i,name,xpd=TRUE,adj=c(0,0.5),cex=0.666)
  }
  dev.off()
}


  

if (MVAplot) {
  $mva_code
}

  
output <- cbind(Matrix)
output.orders <- order(row.names(Matrix))
output.annotated <- cbind(row.names(Matrix)[output.orders],annot.noheader[annot.orders,annot.grab.columns],output[output.orders,])
headings <- c("Probesets",annot.header[1,annot.grab.columns],sampleNames(exprset))
write.table(output.annotated,file="$RESULT_DIR/$jobname/${jobname}_annotated.txt" ,sep="\t",quote=FALSE,col.names = headings,row.names=FALSE)
#End writing out annotated table

save(exprset, file = "$RESULT_DIR/$jobname/$jobname.exprSet")
#Turn off writing just a plain non-annotated file
#write.table(exprs(exprset), "$RESULT_DIR/$jobname/$jobname.txt", quote = FALSE, 
#            sep = "\t", col.names = sampleNames(exprset))
END

$script .= $fmcopy ? <<END : "";
save(exprset, file = "$celpath/$jobname.exprSet")
END

return $script;
}

#### Subroutine: expresso_safe
# Check to see if the expresso call is valid and methods will work together
# Returns 1 if valid and 0 if not
####
sub expresso_safe {
	my ($bgcorrect, $normalize, $pmcorrect, $summary) = @_;

	if ($bgcorrect eq "rma" && $pmcorrect ne "pmonly") {
		return 0;
	}

	if (($summary eq "mas" || $summary eq "medianpolish") &&
		$pmcorrect eq "subtractmm") {
		return 0;
	}

	if ($normalize eq "vsn" && $bgcorrect ne "none") {
		return 0;
	}

	return 1;
}

#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

	print $cgi->header;    
	site_header("Affymetrix Expression Analysis: affy");
	
	print h1("Affymetrix Expression Analysis: affy"),
	      h2("Error:"),
	      p($error);
	
	print "DEBUG INFO<br>";
	my @param_names = $cgi->param;
	foreach my $p (@param_names){
		print $p, " => ", $cgi->param($p),br; 
	}
	site_footer();
	
	exit(1);
}


#### Subroutine: Update Analysis record
# Once an analysis run has start update the db record with the switches that were used
# Give a hash from the cgi->parms;
# Return 1 for succesful update 0 for a failure
####
sub update_analysis_table {
	my @db_jobsummary = @_;
	my $analysis_data = join ('// ', @db_jobsummary);
#	my %cgi_params = @_;
	my $analysis_id = $cgi->param('analysis_id');
#	my @R_switches = qw(process custom log2trans path sampleNames);
#	my $analysis_data = '';
	
	error("Analysis ID not FOUND '$analysis_id'") unless ($analysis_id =~ /^\d/);
	
#	foreach my $key (@R_switches){
#		if (exists $cgi_params{$key}){
#			my $val = $cgi_params{$key} ? $cgi_params{$key} : "Not Set";
#			$analysis_data .=  "$key=>$val //";
#		}
#	}
#	$analysis_data =~ s/[^a-zA-Z0-9\/_\.=>  ]/__/g;	#remove any junk from the analsysis annotation note
#	$log->debug("ANALYSIS ANNO '$analysis_data'");
	my $rowdata_ref = { 	analysis_description  => $analysis_data,	
						        
					  };
					  
	 
	 my $result = $sbeams->updateOrInsertRow(
	 		update=>1,
            table_name=>$TBMA_AFFY_ANALYSIS,
            rowdata_ref=>$rowdata_ref,
            PK=>'affy_analysis_id',
            PK_value=>$analysis_id,
            return_PK=>1,
            verbose=>0,
            testonly=>0,
            add_audit_parameters=>1,
            );
}

#### Subroutine: update_xml_file
# Once an analysis run has started update the xml sample group file with the sample names used
# return 1 for success 0 for failure
####
sub update_xml_file {
	
	my %args = @_;
	my $folder_name = $args{token};
  my $all_sample_names_aref = $args{sample_names};
  my @all_filenames = @{ $args{file_name} };
    
  my $xml_file = "$BC_UPLOAD_DIR/$folder_name/$SAMPLE_GROUP_XML";
  my $parser = XML::LibXML->new();
	my $doc = $parser->parse_file( $xml_file);	
  my $root  = $doc->getDocumentElement;
    
  my %class_numbers = ();
	my $class_count = 0;
  ##need to convert the sample name to a number since R only wants two classes for t-testing O and 1
  ##First frind the reference sample node to use as the class 0	
		
  #$sample_groups{SAMPLE_NAMES}{$sample_name} = "$class";  
  
   my $reference_sample_group_node = $root->findnodes('//reference_sample_group');
   
   my $reference_sample_group = $reference_sample_group_node->to_literal;

   if ($reference_sample_group){
     $class_numbers{$reference_sample_group} = $class_count;
  	 $class_count ++;
   }else{
     error("Cannot find the reference sample group node");
   }
  
  
    for(my $i=0; $i <= $#all_filenames; $i++){
    	my $file_name = $all_filenames[$i];
    	my $sample_name = $all_sample_names_aref->[$i];
    	my $found_flag = 'F';
    	my $x_path = "//file_name[.='$file_name']";
	    my $count = 0;
	    foreach my $c ($root->findnodes($x_path)) {
			$found_flag = 'T';
			my $sample_group = $c->findnodes('./@sample_group_name')->string_value();
			$c->setAttribute("sample_name", $sample_name);
		    
		    my $node_val = $c->to_literal;
		    
		   
### Need to add a class number that will be used by R in the t-test and anova test.  It cannot use
### a sample_group name for determing the different classes....
		    my $class = '';
		    
		    if (exists $class_numbers{$sample_group}){		
				$class = $class_numbers{$sample_group};
			}else{
				$class_numbers{$sample_group} = $class_count;
				$class = $class_numbers{$sample_group};
				$class_count ++;
			}
	    	$c->setAttribute("class_number", $class);
	    	 
	 
	    	 
#    	 print STDERR "NODE VAL '$sample_group' CLASS '$class'\n";
	   
	    	if ($count > 1){
	    		error("Updating XML Error: More then two files with the same name $file_name");
	    	}
	    	$count ++;
	    }
    	  print STDERR "COULD NOT FIND NODE FOR FILE '$file_name'" unless $found_flag eq 'T';
	}
	
	
	my $state = $doc->toFile($xml_file, 1);	#1 is the xml format to produce, it will make a nice looking indented pattern
     
}
    				
    				
    				

