#!/usr/local/bin/perl -T


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);
use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Microarray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use CGI;
$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value kay=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
	print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET   = $OPTIONS{"quiet"} || 0;
$DEBUG   = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(
    parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
    # Some action
  }else {
    $sbeamsMOD->printPageHeader();
    if ($parameters{'UPDATEMIAME'}) { updateMIAMEInfo(parameters_ref=>\%parameters); }
    print_javascript();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }


} # end main


###############################################################################
# print_javascript 
##############################################################################
sub print_javascript {

print qq~
<SCRIPT LANGUAGE="Javascript">
<!--

var characters = new RegExp("[A-Za-z0-9]");

function prepareForSubmission(category){

    var all = new RegExp("all");
    var other = new RegExp("other");
    var expDesign = new RegExp("experiment_design");
   
    if (all.test(category) || expDesign.test(category)) {
	var chooser = document.miame.expTypeChooser;
	var expOther = document.miame.otherExpType.value;

	if (other.test(chooser.options[chooser.selectedIndex].value) && !characters.test(expOther)){
	    expOther = prompt ("You selected the 'Other' experiment type.  Please enter the experiment type");
	    if (!characters.test(expOther)){
		document.miame.exTypeChooser.selectedIndex = 0;
		return FALSE;}
	}else {
	    expOther = document.miame.otherExpType.value;
	}


	if (other.test(chooser.options[chooser.selectedIndex].value)) {
	    document.miame.expType.value = "other(";
	    document.miame.expType.value += expOther;
	    document.miame.expType.value += ")";
	}else {
	    document.miame.expType.value = chooser.options[chooser.selectedIndex].value;
	}
	
	var efo1box = document.miame.expFactOther1;
	var efo1text = document.miame.otherExpFact1;
	
	if (efo1box.checked && !characters.test(efo1text.value)) {
	    var r1 = prompt("No value set for Experimental Factor.  Click Cancel if you don't want to use this factor.  Otherwise, enter the factor below");
	    if (r1) { efo1text.value = r1; }
	    else    { efo1box.checked = false; }
	       	     
	}
	
	var qc1box = document.miame.qc_other1;
	var qc1text = document.miame.otherQCStep1;
	
	if (qc1box.checked && !characters.test(qc1text.value)) {
	    var r1 = prompt("No value set for Quality Control Step.  Click Cancel if you don't want to use this factor.  Otherwise, enter the factor below");
	    if (r1) { qc1text.value = r1; }
	    else    { qc1box.checked = false; }
	       	     
	}
    }
}

function checkForText(chooser, textSite){
    if (chooser.options[chooser.selectedIndex].value == 'other' && 
	characters.test(textSite.value)) {
	var answer=prompt("No Experimental Type set.  Enter one below or click Cancel if you do not wish to change your Experimental Type setting..") ;
	if(answer){
	    textSite.value = answer;
	}else {
	    chooser.selectedIndex = 0;
	}
    }
}

function setToOther(theChooser, theText) {
    if (characters.test(theText.value) == true) {
	theChooser.selectedIndex = theChooser.length -1;
    }
    else if (theChooser.selectedIndex == theChooser.length -1) {
	theChooser.selectedIndex = 0;
    }
}

function verifyNumber(location){
    if (!characters.test(location.value)) {
	location.value ="";
	return;
    }

    var number = parseInt(location.value);
    if(isNaN(number)){
	alert(location.value+" not a number");
	location.value ="";
	return;
    }
    else{location.value = number;return;}
}

function allowTyping() {
		if (document.miame.commonRef[0].checked != true) {
				document.miame.commonRefText.blur();
		}
}

function eraseText() {
		document.miame.commonRefText.value="";
}

//-->
</SCRIPT>
~;
return 1;
}

###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  #### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);
  my @rows;

  #### Define variables for Summary Section
  my $project_id = $sbeams->getCurrent_project_id();; 
  my $category = $parameters{CATEGORY} || "all";
  my $project_name = 'NONE';
  my (%array_requests, %array_scans, %quantitation_files);

  #### Show current user context information
  #$sbeams->printUserContext();
	$sbeams->printUserChooser();
	
  $current_contact_id = $sbeams->getCurrent_contact_id();
  $project_name = $sbeams->getCurrent_project_name();


  #### Print tabs
  my @tab_titles = ("Summary","MIAME Status","Management","Data Analysis","Permissions");
  my $tab_titles_ref = \@tab_titles;
  my $page_link = 'ProjectHome.cgi';

  $sbeamsMOD->print_tabs(tab_titles_ref=>$tab_titles_ref,
			 page_link=>$page_link,
			 selected_tab=>1);

  #### Print out some information about this project
  print qq~
	<H1><CENTER>MIAME Status of $project_name : $category</CENTER></H1>
	<FONT COLOR="green"><B>This is the first draft of a tool to ensure data is MIAME complaint<BR>Please email <A HREF="mailto:mjohnson\@systemsbiology.org">mjohnson</A> with any suggestions on how to improve this!</B></FONT><BR>
	<A HREF="ProjectHome.cgi?tab=miame_status">back to MIAME home</A>
	<FORM NAME="miame" METHOD="POST" onSubmit ="prepareForSubmission('$category')">
	<INPUT TYPE="hidden" NAME="CATEGORY" VALUE="$category">
  ~;

  #### Experiment Design Section
  if ($category =~ /experiment_design/ || $category eq "all"){
      printExperimentDesignSection(parameters=>\%parameters);
  }

  #### Array Design Section
  if ($category =~ /array_design/ || $category eq "all"){
      printArrayDesignSection(parameters=>\%parameters);
  }

  #### Sample Information Section
  if ($category =~ /sample_information/ || $category eq "all"){
      printSampleInformationSection(parameters=>\%parameters);
  }

  #### Labeling Section
  if ($category =~ /labeling_and_hybridization/ || $category eq "all"){
      printLabelingAndHybridizationSection(parameters=>\%parameters);
  }
  
  #### Measurements Section
  if ($category =~ /measurements/ || $category eq "all"){
      printMeasurementsSection(parameters=>\%parameters);
  }


  #}
	print "$LINESEPARATOR<BR>";

  return;

} # end handle_request

###############################################################################
# printExperimentDesignSection
#
# Mappings (12-23-02):
#
# Type of Experiment       -> comment in project table
# Experimental Factors     -> comment in project table
# Number of Hybridizations -> comment in project table
# Reference used for Hyb.  ->
# Hybridization Design     ->
# Quality Control Steps    ->
# URL                      -> URI in project table
#
###############################################################################
sub printExperimentDesignSection {
    my %args = @_;
    my $SUB_NAME="printExperimentDesignSection";

    #### Decode the argument list
    my $parameters_ref = $args{'parameters'};
    my %parameters = %{$parameters_ref};

    #### Define standard variables
    my (@rows,$sql,$mod_date,$uri);
    my ($additional_information, $module_information);
    my ($exp_type,$exp_desc,$exp_factors);
		my ($exp_desc_bool,$exp_type_bool,$exp_factors_bool);
		my ($num_hyb,$qc_steps,$common_ref,$common_ref_text);
		my ($num_hyb_bool,$qc_steps_bool,$common_ref_bool);
    my $project_id = $sbeams->getCurrent_project_id();

    #### Experimental Design info is stored in the project table
    $sql = qq~
	SELECT P.additional_information, P.description, P.uri, P.date_modified
	FROM $TB_PROJECT P
	WHERE P.project_id=\'$project_id\'
	AND P.record_status != 'D'
    ~;
    @rows = $sbeams->selectSeveralColumns($sql);
    
    if (@rows){
	($additional_information, $exp_desc, $uri, $mod_date) = @{$rows[0]};
    }

    ## Extract <microarray> portion
    $additional_information =~ /<microarray>(.*)<\/microarray>/;
    $module_information = $1;
    
    if ($exp_desc){$exp_desc_bool = 'TRUE';}
    else{$exp_desc_bool = 'FALSE';}

    if (defined($module_information)) {
				if ($module_information =~ /<exp_type>(.*)<\/exp_type>/) {
						$exp_type = $1;
						$exp_type_bool = 'TRUE';
				}else {
						$exp_type_bool = 'FALSE';
				}
				if ($module_information =~ /<exp_factors>(.*)<\/exp_factors>/) {
						$exp_factors = $1;
						$exp_factors_bool = 'TRUE';
				}else {
						$exp_factors_bool = 'FALSE';
				}
				if ($module_information =~ /<num_hybs>(.*)<\/num_hybs>/) {
						$num_hyb = $1;
						$num_hyb_bool = 'TRUE';
				}else {
						$num_hyb_bool = 'FALSE';
				}
				if ($module_information =~ /<qc_steps>(.*)<\/qc_steps>/) {
						$qc_steps = $1;
						$qc_steps_bool = 'TRUE';
				}else {
						$qc_steps_bool = 'FALSE';
				}
				if ($module_information =~/<common_ref>(.*)<\/common_ref>/) {
						$common_ref = $1;
						if ($common_ref eq 'yes'){
								$module_information =~/<common_ref_text>(.*)<\/common_ref_text>/;
								$common_ref_text = $1;
						}
						$common_ref_bool = 'TRUE';
				}else {
						$common_ref_bool = 'FALSE';
				}
		}
	

    #### print HTML
    print qq~
    $LINESEPARATOR
    <H2><FONT COLOR="red">Experimental Design</FONT> - 
    ~;

    ## Determine MIAME compliance
    if ($exp_desc_bool eq 'TRUE' &&
	$exp_type_bool eq 'TRUE' &&
	$exp_factors_bool eq 'TRUE' &&
	$num_hyb_bool eq 'TRUE' &&
	$qc_steps_bool eq 'TRUE' &&
	$common_ref_bool eq 'TRUE'){
	print qq~<FONT COLOR="green">MIAME Compliant</FONT>~;
    }
    else{
	print qq~NOT MIAME Compliant~;
    }

		## Print "More Info" button
		my $title = "MIAME Requirements";
		my $text = qq~<B>MIAME Requirements for Experiment Design:</B><UL><LI>Type of experiment</LI><UL><LI>for example, normal vs. diseased tissue, time course, or gene knock-out</LI></UL><LI>Experimental factors</LI><UL><LI>parameters or conditions tested such as time, dose, or genetic variation</LI></UL><LI>The number of hybridizations performed in the experiment.</LI><LI>The type of reference used for the hybridizations, if any.</LI><LI>Hybridization design</LI><UL><LI>if applicable, a description of the comparisons made in each hybridization</LI></UL><LI>Quality control steps taken: for example, replicates or dye swaps.</LI><LI>URL of any supplemental websites or database accession numbers</LI></UL>~;

		print qq~
		<a href="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?text=$text','Help','width=450,height=400,resizable=yes');return false"><img src="$HTML_BASE_DIR/images/info.jpg" border=0 alt="Help"></a>
		~;

		## Begin printing Experiment Design Section
    print qq~</H2>
    <H3><FONT COLOR="red">last modified on $mod_date</FONT><H3>
    <TABLE CELLSPACING=0 CELLPADDING=0 BORDER="3"BORDERCOLOR="#000000">
    <TR><TD>
    <TABLE CELLSPACING=0 CELLPADDIN=0>
    <TR BGCOLOR="#CCFFFF" BORDERCOLOR="#000000">
      <TD><B>Experiment Description:</B></TD>
      <TD><TEXTAREA NAME="expDesc" COLS="50" ROWS="10">$exp_desc</TEXTAREA></TD>
    </TR>
    <TR BGCOLOR="#FFFFFF" BORDER="0">
      <TD><B>Type of Experiment:</B></TD>
      <TD><br>
        <SELECT NAME="expTypeChooser">
    ~;

    my $expTypeTemplate = qq~
        <OPTION VALUE="nothing">
	<OPTION VALUE="all pairs">All Pairs
	<OPTION VALUE="amplification labeling">Amplification Labeling
	<OPTION VALUE="binding site id">Binding Site Identification
	<OPTION VALUE="cell cycle">Cell Cycle
	<OPTION VALUE="cell type comparison">Cell Type Comparison
	<OPTION VALUE="cellular modification">Cellular Modification
	<OPTION VALUE="circadian rhythm">Circadian Rhythm
	<OPTION VALUE="development or differentiation">Development or Differentiation
	<OPTION VALUE="disease state">Disease State
	<OPTION VALUE="dose response">Dose Response
	<OPTION VALUE="dye swap">Dye Swap
	<OPTION VALUE="family history">Family History
	<OPTION VALUE="genetic modification">Genetic Modification
	<OPTION VALUE="gene knockout">Gene Knockout Study
	<OPTION VALUE="genotyping">Genotyping design
	<OPTION VALUE="growth condition">Growth Condition design
	<OPTION VALUE="hardware variation">Hardware Variation design
	<OPTION VALUE="injury">Injury design
	<OPTION VALUE="loop">Loop design
	<OPTION VALUE="normal vs. diseased">Normal vs. Diseased
	<OPTION VALUE="normalization testing">Normalization Testing design
	<OPTION VALUE="operator variation">Operator Variation design
	<OPTION VALUE="operon id">Operon Identification design
	<OPTION VALUE="pathogenicity">Pathogenicity design
	<OPTION VALUE="quality control testing">Quality Control Testing
	<OPTION VALUE="reference">Reference 
	<OPTION VALUE="replciate">Replicate
	<OPTION VALUE="rna stability">RNA stability
	<OPTION VALUE="secreted protein identification">Secreted Protein Identification
	<OPTION VALUE="self vs. self">Self vs. Self
	<OPTION VALUE="software variation">Software Variation
	<OPTION VALUE="species">Species
	<OPTION VALUE="stimulus or stress">Stimulus or Stress
	<OPTION VALUE="strain or line">Strain or Line
	<OPTION VALUE="time course">Time Course
	<OPTION VALUE="transcript identification">Transcript Identification
	<OPTION VALUE="translational bias">Translational Bias
	<OPTION VALUE="other">Other
	~;

    $expTypeTemplate =~ s(\"$exp_type\")(\"$exp_type\" SELECTED);
    if ($exp_type =~ /^other\((.*)\)/) {
	$expTypeTemplate =~ s(\"other\")(\"other\" SELECTED);
    }

    print qq~
	$expTypeTemplate
	</SELECT>
        Other:
    ~;

    my $otherExpTemplate = qq~
	<INPUT TYPE="text" NAME="otherExpType" onChange="setToOther(this.form.expTypeChooser, this.form.otherExpType)">
    ~;

    if ($exp_type =~/^other\((.*)\)/) {
	my $subst = $1;
	$otherExpTemplate =~ s(>)(VALUE=\"$subst\">);
    }

    print qq~
        $otherExpTemplate
	<INPUT TYPE="hidden" NAME="expType">
      </TD>
    </TR>
    <TR><TD></TD></TR>
    <TR BGCOLOR="#CCFFFF">
      <TD VALIGN="top"><B>Experimental Factors:</B></TD>
      <TD>
      <TABLE>
        <TR><TD>
    ~;


    #NOTE - this array is duplicated in the updateMIAMEInfo subroutine 
    my @factors = ("age","cell line","cell type",
		   "compound","developmental stage", "disease state",
		   "dose","genetic variation","genotype",
		   "organism part","post-transcriptional gene silencing","protocol",
		   "sex/mating type","species","strain", 
		   "temperature","time","tissue type",
		   "other");


    my $expFactorsTemplate ="<TABLE>\n";
    for (my $i=0;defined($factors[$i]);$i++) {
	my $val = $i%3;
	my $factor = $factors[$i];

	if ($val == 0) {
	    $expFactorsTemplate .= "<TR>\n";
	}
	$expFactorsTemplate .= "<TD><INPUT TYPE=\"checkbox\" NAME=\"$factor\">$factor</TD>\n";
	if ($val == 2) {
	    $expFactorsTemplate .= "</TR>\n";
	}
    }
    $expFactorsTemplate .= "</TABLE>\n";

    my @factors = split ',',$exp_factors;
    foreach my $factor(@factors) {
	$expFactorsTemplate =~ s(>$factor<\/TD>)(CHECKED>$factor<\/TD>);
	if ($factor =~ /^other\((.*)\)/) {
	    my $subst = $1;
	    $expFactorsTemplate =~ s(>Other)(CHECKED>Other);
	    $expFactorsTemplate =~ s(\"otherExpFact1\")(\"otherExpFact1\" VALUE=\"$subst\");
	}
    }

    print qq~
	$expFactorsTemplate
	</TD></TR>
      </TABLE>
      </TD>
    </TR>
    <TR><TD></TD></TR>
    <TR BGCOLOR="#FFFFFF">
      <TD><B>\# of Hybridizations</B></TD>
      <TD>
        <INPUT="text" NAME="numHyb" SIZE="5" VALUE="$num_hyb" onChange="verifyNumber(this)">
      </TD>
    </TR>
    <TR><TD></TD></TR>
    <TR BGCOLOR="#CCFFFF">
      <TD><B>Common Reference Used in Hybs?</B></TD>
      <TD>
      ~;
    if ($common_ref eq 'yes'){
	print qq~
	    <INPUT TYPE="radio" NAME="commonRef" VALUE="yes"CHECKED onClick="Javascript:document.miame.commonRefText.focus()">YES
	    ~;
    }else {
	print qq~
	    <INPUT TYPE="radio" NAME="commonRef" VALUE="yes" onClick="Javascript:document.miame.commonRefText.focus()">YES
	    ~;
    }
    if ($common_ref eq 'no') {
	print qq~
	    <INPUT TYPE="radio" NAME="commonRef" VALUE="no" onClick="eraseText()" CHECKED>NO
	    ~;
    }else {
	print qq~
	    <INPUT TYPE="radio" NAME="commonRef" VALUE="no" onClick="eraseText()">NO
	    ~;
    }
    print qq~
	</TD>
      </TR>
      <TR BGCOLOR="#CCFFFF">
        <TD><B>If so, describe reference</B></TD>
        <TD>
	~;
    if ($common_ref_text){
	print qq~
	    <INPUT TYPE="text" NAME="commonRefText" VALUE="$common_ref_text" onFocus="Javascript:allowTyping()">
	    ~;
    }else {
	print qq~
	    <INPUT TYPE="text" NAME="commonRefText" VALUE="$common_ref_text" onFocus="Javascript:allowTyping()">
	    ~;
    }
    print qq~
	</TD>
      </TR>
      <TR><TD></TD></TR>
      <TR BGCOLOR="#FFFFFF">
      <TD VALIGN="top"><B>Quality Control Steps:</B></TD>
    ~;

    my $qcTemplate = qq~
      <TD>
        <TABLE>
	<TR>
	  <TD><INPUT TYPE="checkbox" NAME="reps">replicates</TD>
	  <TD><INPUT TYPE="checkbox" NAME="dyeSwap">dye swapping</TD>
	</TR>
	<TR>
	  <TD><INPUT TYPE="checkbox" NAME="spikeIns">spike-in controls</TD>
	  <TD><INPUT TYPE="checkbox" NAME="qc_other1">Other  <INPUT TYPE="text" NAME="otherQCStep1"</TD>
	</TR>
	</TABLE>
      </TD>
      ~;

    @factors = split ',', $qc_steps;
    foreach my $factor(@factors) {
				$qcTemplate =~ s(>$factor<\/TD>)(CHECKED>$factor<\/TD>);
				if ($factor =~ /^other\((.*)\)/) {
						my $subst = $1;
						$qcTemplate =~ s(>Other)(CHECKED>Other);
						$qcTemplate =~ s(\"otherQCStep1\")(\"otherQCStep1\" VALUE=\"$subst\");
				}
    }
    print qq~
    $qcTemplate
    </TR>
    <TR><TD></TD></TR>
    <TR BGCOLOR="#CCFFFF">
      <TD><B>Supplemental URL</B></TD>
      <TD><INPUT TYPE="text" NAME="url" SIZE="50" VALUE="$uri"></TD>
    </TR>
    </TABLE>
    </TD></TR>
    </TABLE>
    <INPUT TYPE="hidden" NAME="expHyb">
    ~;

  my $permission = $sbeams->get_best_permission();
  if ($permission <= 10){
  print qq~
			<BR>
      <INPUT TYPE="submit" NAME="UPDATEMIAME" VALUE="Update Information">
      </FORM>
  ~;
  }
    return;
}


###############################################################################
# printArrayDesignSection
#
# Mappings(12-23-02):
#
# Platform type                     -> printing_batch protocol
# Surface and coating specs         -> slide_model comment
# Availability of array             -> printing_batch protocol
# Other general design specs        -> printing_batch protocol
# Reporter of each feature          -> Map file
# Reporter type                     -> Map file
# Reporter DB ref                   -> 
# Reporter sequence                 -> Map file (arrayDesign)
# Commercial array?                  
#   -Manufacturer                    ->
#   -Catalog Number                  ->
#   -Manufacturer's URL              ->
# Non-Commercials array?            
#   -source of reporter              -> Map file
#   -method of reporter preparation  -> 
#   -spotting protocol               -> 
#   -other treatment                 -> 
#
###############################################################################
sub printArrayDesignSection {
    my %args = @_;
    my $SUB_NAME="printArrayDesignSection";

    #### Decode the argument list
    my $parameters_ref = $args{'parameters'};
    my %parameters = %{$parameters_ref};

    #### Define standard variables
    my ($sql, @rows);
    my ($base_url,%url_cols,%hidden_cols);
    my $miame_compliant = 1;
    my $project_id = $sbeams->getCurrent_project_id();

    #### Get arrays that are used in the project
    $sql = qq~
	SELECT	A.array_id,A.array_name,PB.number_of_spots,
	PR.name AS 'protocol_name', PR.protocol_id, AL.source_filename AS 'key_file', SM.comment
	FROM $TB_ARRAY_REQUEST AR
	LEFT JOIN $TB_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
	LEFT JOIN $TB_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
	LEFT JOIN $TB_ARRAY_LAYOUT AL ON ( A.layout_id = AL.layout_id )
	LEFT JOIN $TB_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
	LEFT JOIN $TB_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
	LEFT JOIN $TB_PRINTING_BATCH PB ON ( PB.printing_batch_id = A.printing_batch_id)
	LEFT JOIN $TB_PROTOCOL PR ON (PR.protocol_id = PB.protocol_id)
	LEFT JOIN $TB_SLIDE S ON (S.slide_id = A.slide_id)
	LEFT JOIN $TB_SLIDE_LOT SL ON (SL.slide_lot_id = S.slide_lot_id)
	LEFT JOIN $TB_SLIDE_MODEL SM ON (SM.slide_model_id = SL.slide_model_id)
	WHERE AR.project_id='$project_id'
	AND AR.record_status != 'D'
	AND A.record_status != 'D'
	AND ASCAN.record_status != 'D'
	AND AQ.record_status != 'D'
	AND AQ.data_flag != 'BAD'
	ORDER BY A.array_name
	~;
    @rows = $sbeams->selectSeveralColumns($sql);

    ## If we find a 'NULL' in the array, we are not MIAME compliant
    foreach my $row_ref (@rows) {
	my @temp_row = @{$row_ref};
	foreach my $value (@temp_row) {
	    unless ($value) { $miame_compliant = 0; }
	}
    }
    
    ## if no records, no miame compliance
    unless (@rows) {
	$miame_compliant = 0;
    }

    #### print HTML
    print qq~
    $LINESEPARATOR
    <H2><FONT COLOR="red">Array Design</FONT> - 
    ~;

    ## Determine MIAME compliance
    if ($miame_compliant == 1){
	print qq~<FONT COLOR="green">MIAME Compliant</FONT>~;
    }else {
	print qq~NOT MIAME Compliant~;
    }
		## Print "More Info" Button
		my $title = "MIAME Requirements";
		my $text = qq~<B>MIAME Requirements for Array Design:</B><UL><LI>General array design, including:<UL><LI>the platform type (whether the array is a spotted glass array, an in situ synthesized array, etc.)</LI><LI>surface and coating specifications (when known-- often commercial suppliers do not provide this data)</LI><LI>the availability of the array (the name or make of commercially available arrays)</LI></UL><LI>For each feature (spot) on the array, its location on the array and the ID of its respective reporter (molecule present on each spot) should be given.</LI><LI>For each reporter, its type (e.g., cDNA or oligonucleotide) should be given, along with information that characterizes the reporter molecule unambiguously, in the form of appropriate database reference(s) and sequence (if available).</LI><LI>For commercial arrays: a reference to the manufacturer should be provided, including a catalogue number and references to the manufacturers website if available.</LI><LI>For non-commercial arrays, the following details should be provided:</LI><UL><LI>The source of the reporter molecules: for example, the cDNA or oligo collection used, with references.</LI><LI>The method of reporter preparation.</LI><LI>The spotting protocols used, including the array substrate, the spotting buffer, and any post-printing processing, including cross-linking.</LI><LI>Any additional treatment performed prior to hybridization.</LI></UL></UL>~;

		print qq~
		<a href="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?text=$text','Help','width=450,height=600,resizable=yes');return false"><img src="$HTML_BASE_DIR/images/info.jpg" border=0 alt="Help"></a></H2>
		~;


    if (@rows){
	## Print of MIAME criteria
	print qq~
	    <TABLE BORDER>
	    <TR BGCOLOR="\#1C3887">
	    <TD><FONT COLOR="white">Array Design Name</FONT></TD>
	    <TD><FONT COLOR="white">Platform Type/Availability</FONT></TD>
	    <TD><FONT COLOR="white">Surface/Coating Specs</FONT></TD>
	    <TD><FONT COLOR="white">Physical Dimensions</FONT></TD>
	    <TD><FONT COLOR="white">\# of Features</FONT></TD>
	    <TD><FONT COLOR="white">Reporter Information</FONT></TD>
	    </TR>
	    ~;
	
	foreach my $row_ref(@rows) {
	    my ($array_id,$array_name,$spot_count,$protocol_name,$protocol_id,$key_file,$comment) = @{$row_ref};
	    my $map_file = $key_file;
	    $map_file =~ s/key\s*/map/;
	    my $map_location = $map_file;
	    $map_file =~ s(.*/)();
	    $comment =~ /MIAME surface coating:\s+\"?(.*)\"?/;
	    my $spec = $1;
	    $comment =~ /MIAME physical dimensions:\s+\"?(.*)\"?/;
	    my $dim = $1;
	    print qq~
		<TR>
		<TD><A HREF="$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=array&array_id=$array_id" TARGET="_blank">$array_name</A></TD>
		<TD><A HREF="$CGI_BASE_DIR/Microarray/ManageTable.cgi?TABLE_NAME=protocol&protocol_id=$protocol_id" TARGET="_blank">$protocol_name</A></TD>
		<TD>$spec</TD>
		<TD>$dim</TD>
		<TD>$spot_count</TD>
		<TD>
		<A HREF="$CGI_BASE_DIR/Microarray/ViewFile.cgi?FILE_NAME=$map_file&action=download">[Download]</A> <A HREF="$CGI_BASE_DIR/Microarray/ViewFile.cgi?FILE_NAME=$map_file&action=view" TARGET="_blank">[View]</A>
		</TD>
		</TR>
		~;
	}
	
	print qq~
	    </TABLE>
			<BR>
	    ~;
    }else{
	print qq~
	    <H2>No Records for this Project</H2>
	    ~;
    }
    return;
}


###############################################################################
# printSampleInformationSection
#
# Mappings(12-23-02):
#
# Name of Organism            -> sample_desc in sample table
# Provider of sample          -> sample_desc in sample table
# Developmental stage         -> sample_desc in sample table
# Strain                      -> sample_desc in sample table
# Age                         -> sample_desc in sample table
# Gender                      -> sample_desc in sample table
# Disease State               -> sample_desc in sample table
# Manipulation of Sample      -> sample_desc in sample table
# Protocol preparing for Hyb. -> sample_desc in sample table
# Labeling Protocol(s)->
# External controls (spikes)->
#
###############################################################################
sub printSampleInformationSection {
    my %args = @_;
    my $SUB_NAME="printSampleInformationSection";

    #### Decode the argument list
    my $parameters_ref = $args{'parameters'};
    my %parameters = %{$parameters_ref};

    #### Define standard variables
    my ($sql, @rows, $comment, $expType, );

    #### print HTML
    print qq~
    $LINESEPARATOR
    <H2><FONT COLOR="red">Sample Information</FONT> - 
    ~;

    ## Determine MIAME compliance
    if (1==0){
	print qq~<FONT COLOR="green">MIAME Compliant</FONT>~;
    }else {
	print qq~NOT MIAME Compliant~;
    }
		## Print "More Info" Button
		my $title = "MIAME Sample Requirements";
		my $text = qq~<B>MIAME Sample Requirements:</B><BR><UL><LI>Organism Name</LI><LI>Provider of Sample</LI><LI>Developmental Stage</LI><LI>Strain</LI><LI>Age</LI><LI>Gender</LI><LI>Disease State</LI><LI>Manipulation of Sample</LI><LI>Hybridization extract preparation protocol</LI><LI>External controls added to bybridization extraction</LI></UL>~;
		print qq~
		<a href="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?text=$text','Help','width=450,height=400,resizable=yes');return false"><img src="$HTML_BASE_DIR/images/info.jpg" border=0 alt="Help"></a></H2>
		~;


    print qq~
				<p>
				<B>SBEAMS is under construction to handle sample information effectively.</B>
				</p>
				~;
    return;
}


###############################################################################
# printLabelingAndHybridizationSection
###############################################################################
sub printLabelingAndHybridizationSection {
    my %args = @_;
    my $SUB_NAME="printLabelingAndHybridizationSection";

    #### Decode the argument list
    my $parameters_ref = $args{'parameters'};
    my %parameters = %{$parameters_ref};

    #### Define standard variables
    my ($labeling_hybridization_sql);
    my (@rows, $comment, $expType);
    my $miame_compliant = 1;
    my $project_id = $sbeams->getCurrent_project_id();

    #### print HTML
    print qq~
    $LINESEPARATOR
    <H2><FONT COLOR="red">Labeling and Hybridization</FONT> - 
    ~;

    ## SQL to extract information 
    $labeling_hybridization_sql = qq~
	SELECT A.array_name, A.array_id,
	       LPR.name,LPR.protocol_id,L.labeling_id,
	       HPR.name,HPR.protocol_id,H.hybridization_id,
	       ARSMPL.name,ARSMPL.array_request_sample_id
	FROM $TB_ARRAY_REQUEST AR
	LEFT JOIN $TB_ARRAY_REQUEST_SLIDE ARSL ON (ARSL.array_request_id = AR.array_request_id)
	LEFT JOIN $TB_ARRAY_REQUEST_SAMPLE ARSMPL ON (ARSMPL.array_request_slide_id = ARSL.array_request_slide_id)
	LEFT JOIN $TB_LABELING L ON (L.array_request_sample_id = ARSMPL.array_request_sample_id)
	LEFT JOIN $TB_PROTOCOL LPR ON (LPR.protocol_id = L.protocol_id)
	LEFT JOIN $TB_ARRAY A ON (A.array_request_slide_id = ARSL.array_request_slide_id)
	LEFT JOIN $TB_HYBRIDIZATION H ON (H.array_id = A.array_id)
	LEFT JOIN $TB_PROTOCOL HPR ON (HPR.protocol_id = H.protocol_id)
	WHERE 1=1
	AND AR.project_id = '$project_id'
	AND A.record_status != 'D'
	AND AR.record_status != 'D'
	ORDER BY A.array_name
	~;
    @rows = $sbeams->selectSeveralColumns($labeling_hybridization_sql);

    ## if we have no records, we're not miame compliant
    unless (@rows) {
	$miame_compliant = 0;
    }

    ## If we find a 'NULL' in the array, we are not MIAME compliant
    foreach my $row_ref (@rows) {
	my @temp_row = @{$row_ref};
	foreach my $value (@temp_row) {
	    unless ($value) { $miame_compliant = 0; }
	}
    }
    
    ## Determine MIAME compliance
    if ($miame_compliant == 1){
	print qq~<FONT COLOR="green">MIAME Compliant</FONT>~;
    }else {
	print qq~NOT MIAME Compliant~;
    }
	
		##Print "More Info" Button
		my $title = "MIAME Labeling/Hybridization Requirements";
		my $text = qq~<B>Labeling/Hybridization Requirements</B><UL><LI>Labeling protocol(s)</LI><LI>The protocol and conditions used during hybridization, blocking and washing</LI></UL>~;
		print qq~
		<a href="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?text=$text','Help','width=450,height=400,resizable=yes');return false"><img src="$HTML_BASE_DIR/images/info.jpg" border=0 alt="Help"></a></H2>
		~;


    if (@rows){
	## start table
	print qq~
	    <TABLE BORDER>
	    <TR BGCOLOR="\#1C3887">
	    <TD><FONT COLOR="white">Array Name</FONT></TD>
	    <TD><FONT COLOR="white">Array Request Sample Name/ID</FONT></TD>
	    <TD><FONT COLOR="white">Labeling</FONT></TD>
	    <TD><FONT COLOR="white">Hybridization</FONT></TD>
	    </TR>
	    ~;
	
	foreach my $row_ref (@rows) {
	    my ($array_name, $array_id,$lab_prot_name, $lab_prot_id, $lab_id,$hyb_prot_name, $hyb_prot_id,$hyb_id,$arsmpl_name,$arsmpl_id) = @{$row_ref};
	    print qq~
		<TR>
		<TD><A HREF="ManageTable.cgi?TABLE_NAME=array&array_id=$array_id" TARGET="_blank">$array_name</A></TD>
		<TD>$arsmpl_name ($arsmpl_id)</TD>
		~;

	    ## Print Labeling Information
	    if ($lab_prot_name) {
		print qq~
		    <TD>$lab_prot_name <BR><A HREF="ManageTable.cgi?TABLE_NAME=protocol&protocol_id=$lab_prot_id" TARGET="_blank">[Protocol]</A> <A HREF="ManageTable.cgi?TABLE_NAME=labeling&labeling_id=$lab_id" TARGET="_blank">[Record]</A></TD>
		    ~;
	    }else {
		print qq~
		    <TD><FONT COLOR="red">No Labeling Record</FONT><BR><A HREF="ManageTable.cgi?TABLE_NAME=labeling&ShowEntryForm=1" TARGET="_blank">[Insert Record]</TD></TD>
		    ~;
	    }
	    
	    ## Print Hyb Information
	    if ($hyb_prot_name) {
		print qq~
		    <TD>$hyb_prot_name <BR><A HREF="ManageTable.cgi?TABLE_NAME=protocol&protocol_id=$hyb_prot_id" TARGET="_blank">[Protocol]<A HREF="ManageTable.cgi?TABLE_NAME=hybridization&hybridization_id=$hyb_id" TARGET="_blank">[Record]</A></TD>
		    ~;
	    }else {
		print qq~
		    <TD><FONT COLOR="red">No Hybridization Record</FONT><BR><A HREF="ManageTable.cgi?TABLE_NAME=hybridization&ShowEntryForm=1" TARGET="_blank">[Insert Record]</TD>
		    ~;
	    }
	    
	    ## end row
	    print qq~
		</TR>
		~;
	}
	## end table
	print qq~
	    </TABLE>
			<BR>
	    ~;
    }else {
	print qq~
	    <H2>No Records for this Project</H2>
	    ~;
    }		
    return;
}


###############################################################################
# printMeasurementsSection
#
# scan protocol            -> protocol (protocol_type.name = 'array_scanning'
# image analysis           -> protocl (protocol_type.name = 'image_analysis'
# image analysis output    -> array_quantitation page
# data processing protocol -> Data Processing Webpage
###############################################################################
sub printMeasurementsSection {
    my %args = @_;
    my $SUB_NAME="printMeasurementsSection";

    #### Decode the argument list
    my $parameters_ref = $args{'parameters'};
    my %parameters = %{$parameters_ref};

    #### Define standard variables
    my ($sql, @rows, $comment, $expType);
    my $miame_compliant = 1;
    my $project_id = $sbeams->getCurrent_project_id();

    #### print HTML
    print qq~
    $LINESEPARATOR
    <H2><FONT COLOR="red">Measurements</FONT> - 
    ~;

    $sql = qq~
	SELECT A.array_name,A.array_id,ASPR.name, ASPR.protocol_id,ASCAN.array_scan_id,AQPR.name, AQPR.protocol_id,AQUANT.array_quantitation_id,AQUANT.stage_location
	FROM $TB_ARRAY A
	LEFT JOIN $TB_PROJECT PR ON (PR.project_id = A.project_id)
	LEFT JOIN $TB_ARRAY_SCAN ASCAN ON (ASCAN.array_id = A.array_id)
	LEFT JOIN $TB_PROTOCOL ASPR ON (ASPR.protocol_id = ASCAN.protocol_id)
	LEFT JOIN $TB_ARRAY_QUANTITATION AQUANT ON (AQUANT.arraY_scan_id = ASCAN.array_scan_id)
	LEFT JOIN $TB_PROTOCOL AQPR ON (AQPR.protocol_id = AQUANT.protocol_id)
	WHERE 1=1
	AND PR.project_id = '$project_id'
	AND A.record_status != 'D'
	AND ASCAN.record_status != 'D'
	AND AQUANT.record_status != 'D'
	~;
    @rows = $sbeams->selectSeveralColumns($sql);

    ## if there are no records, no miame compliance
    unless (@rows){
	$miame_compliant = 0;
    }

    ## go through records to make sure something exists
    foreach my $row_ref (@rows){
	my @temp = @{$row_ref};
	foreach my $value (@temp){
	    unless ($value) {$miame_compliant = 0;}
	}
    }

    ## Determine MIAME compliance
    if ($miame_compliant == 1){
	print qq~<FONT COLOR="green">MIAME Compliant</FONT>~;
    }else {
	print qq~NOT MIAME Compliant~;
    }

		## Print "More Info" Button
		my $title = "MIAME Measurements/Quantitation Requirements";
		my $text = qq~<B>Measurement Data Requirements</B><UL><LI>The quantitations based on the images</LI><LI>The set of quantitations from several arrays upon which the authors base their conclusions. While access to images of raw data is not required (although its value is unquestionable), authors should make every effort to provide the following:</LI><UL><LI>Type of scanning hardware and software used: this information is appropriate for a materials and methods section</LI><LI>Type of image analysis software used: specifications should be stated in the materials and methods</LI><LI>A description of the measurements produced by the image-analysis software and a description of which measurements were used in the analysis</LI><LI>The complete output of the image analysis before data selection and transformation (spot quantitation matrices)</LI><LI>Data selection and transformation procedures</LI><LI>Final gene expression data table(s) used by the authors to make their conclusions after data selection and transformation (gene expression data matrices)</LI></UL></UL>~;
		print qq~
		<a href="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?text=$text','Help','width=450,height=500,resizable=yes');return false"><img src="$HTML_BASE_DIR/images/info.jpg" border=0 alt="Help"></a></H2>
		~;


    if (@rows) {
    ## start table
	print qq~
	    <TABLE BORDER>
	    <TR BGCOLOR="\#1C3887">
	    <TD><FONT COLOR="white">Array Name</FONT></TD>
	    <TD><FONT COLOR="white">Array Scan Protocol/Record</FONT></TD>
	    <TD><FONT COLOR="white">Image Analysis Protocol/Record</FONT></TD>
	    <TD><FONT COLOR="white">Data Processing Protocol</FONT></TD>
	    </TR>
	    ~;
	
	foreach my $row_ref (@rows) {
	    my ($array_name,$array_id,$scan_protocol_name,$scan_protocol_id,$array_scan_id,$quant_protocol_name,$quant_protocol_id,$array_quant_id,$array_quant_location) = @{$row_ref};
	    print qq~
	    <TR>
	    <TD><A HREF="ManageTable.cgi?TABLE_NAME=array&array_id=$array_id" TARGET="_blank">$array_name</A></TD>
	    ~;


	    ## Array Scan Protocol
	    if ($array_scan_id){
	    print qq~
	    <TD>
	    $scan_protocol_name<BR>
	    <A HREF="ManageTable.cgi?TABLE_NAME=protocol&protocol_id=$scan_protocol_id" TARGET="_blank">[View Protocol]</A> 
	    <A HREF="ManageTable.cgi?TABLE_NAME=array_scan&array_scan_id=$array_scan_id" TARGET="_blank">[View Record]</A>
	    </TD>
	    ~;
	    }else {
	    print qq~
	    <TD>
	    <FONT COLOR="red">No Record</FONT><BR>
	    <A HREF="ManageTable.cgi?TABLE_NAME=array_scan&ShowEntryForm=1" TARGET="_blank">[Insert Record]</A>
	    </TD>
	    ~;
	    }

	    ## Image Analysis Protocol
	    if ($array_quant_id){
	    print qq~
	    <TD>
	    $quant_protocol_name<BR>
	    <A HREF="ManageTable.cgi?TABLE_NAME=protocol&protocol_id=$quant_protocol_id" TARGET="_blank">[View Protocol]</A> 
	    <A HREF="ManageTable.cgi?TABLE_NAME=array_quantitation&array_quantitation_id=$array_quant_id" TARGET="_blank">[View Record]</A>
	    </TD>
	    ~;
	    }else {
	    print qq~
	    <TD>
	    <A HREF="ManageTable.cgi?TABLE_NAME=array_scan&ShowEntryForm=1" TARGET="_blank">[Insert Record]</A>
	    </TD>
	    ~;
	    }

	    print qq~
	    <TD><A HREF="http://db.systemsbiology.net/software/ArrayProcess/" TARGET="_blank">Pipeline Documentation</A></TD>
	    </TR>
	    ~;
	}
    ## end table
    print qq~
	</TABLE>
	<BR>
	~;
    }
    else{
	print qq~
	<H2>No Records for this project</H2>
	~;
    }
    return;
}

###############################################################################
# updateMIAMEInfo
###############################################################################
sub updateMIAMEInfo {
  my %args = @_;

  #### Process the arguments list
  my $parameters_ref = $args{'parameters_ref'}
    || die "parameters_ref not passed";
  my %parameters = %{$parameters_ref};


  #### Defined standard variables
  my (@rows, $sql, $category);
  my ($comment, %rowdata, $rowdata_ref);
  my $additional_information = "";
  $category = $parameters{'CATEGORY'};
  my $project_id = $sbeams->getCurrent_project_id();

  #######################
  ## Experiment Design ##
  #######################
  if ($category=~ /experiment_design/ || $category eq "all") {

      ## Experiment Description
      if($parameters{'expDesc'} =~ /\w/) {
	  $rowdata{'description'} = $parameters{'expDesc'};
      }
      
      ## Experiment Type
      my $exp_type = $parameters{'expType'};
      
      if ($exp_type !~ /^nothing$/){
	  if ($exp_type =~ /^other$/){
	      my $other = $parameters{'otherExpType'};
	      $additional_information .= "<exp_type>other\($other\)<\/exp_type>";
	  }
	  else{
	      $additional_information .= "<exp_type>$exp_type<\/exp_type>";    
	  }
      }

      ## Experimental Factors
      my $exp_factors;
      my @factors = {"age","cell line","cell type",
		     "compound","developmental stage", "disease state",
		     "dose","genetic variation","genotype",
		     "organism part","post-transcriptional gene silencing","protocol",
		     "sex/mating type","species","strain", 
		     "temperature","time","tissue type",
		     "other"};

      foreach my $factor (@factors){
	  if ($parameters{$factor} eq 'on') {
	      if ($factor eq 'other') {
		  $exp_factors .= "$factor($parameters{'otherExpFact1'}),"
	      }else {
		  $exp_factors .= "$factor,";
	      }
	  }
      }
		    
      if ($exp_factors){ chop($exp_factors); }

      if ($exp_factors) {
	  $additional_information .= "<exp_factors>".$exp_factors."<\/exp_factors>";
      }

      ## # of Hybridizations
      if ($parameters{'numHyb'}) {
	  $additional_information .= "<num_hybs>".$parameters{'numHyb'}."<\/num_hybs>";
      }

			## Is a common reference used?
			if ($parameters{'commonRef'}){
					$additional_information .="<common_ref>".$parameters{'commonRef'}."<\/common_ref>";
			}
			##Description of common ref
			if ($parameters{'commonRefText'} && $parameters{'commonRef'} eq 'yes') {
					$additional_information .="<common_ref_text>".$parameters{'commonRefText'}."<\/common_ref_text>";
			}

      ## Quality Control Steps
      my $qc_steps;
      if ($parameters{'reps'} eq 'on') {
	  $qc_steps .= "replicates,";
      }
      if ($parameters{'dyeSwap'} eq 'on') {
	  $qc_steps .= "dye swapping,";
      }
			if ($parameters{'spikeIns'} eq 'on') {
					$qc_steps .="spike-in controls,";
			}
      if ($parameters{'qc_other1'} eq 'on') {
	  $qc_steps .= "other($parameters{'otherQCStep1'}),";
      }

      if ($qc_steps){ chop($qc_steps); }

      if ($qc_steps) {
	  $additional_information .= "<qc_steps>".$qc_steps."<\/qc_steps>";
      }

      
      ## Finish with everything that goes in the 'additional_information' field
      $rowdata{'additional_information'} = update_module(module=>'microarray',
																												 content=>$additional_information);
      

      ## Project URI
      if ($parameters{'url'}) {
	  $rowdata{'uri'} = $parameters{'url'};
      }else {
	  $rowdata{'uri'} = "";
      }
      

      $rowdata_ref= \%rowdata;
      $sbeams->updateOrInsertRow(table_name=>'project',
				 rowdata_ref=>$rowdata_ref,
				 update=>1,
				 PK_name=>'project_id',
				 PK_value=>$project_id,
				 add_audit_parameters=>1
				 );

      ## Clear out hash
      foreach my $key(keys %rowdata) {
	  delete($rowdata{$key});
      }

  }

  return;
}

###############################################################################
# update_module- returns 'additional_information' data
###############################################################################
sub update_module {
  my %args = @_;
  my $SUB_NAME = "update_module";

  ## Process the arguments list
  my $module = $args{'module'}
  || die "ERROR[$SUB_NAME]: module not passed";
  my $content = $args{'content'};
#  my $parameters_ref = $args{'parameters'};
#  my %parameters = %{$parameters_ref};
 
  ## Define standard variables
  my ($sql, @rows);
  my (%rowdata, $rowdata_ref);
  my $current_project_id = $sbeams->getCurrent_project_id;
  my ($additional_information, $module_information);

  ## Get 'additional information' column
  $sql = qq~
      SELECT additional_information
      FROM project
      WHERE project_id = $current_project_id
      AND record_status != 'D'
      ~;
  
  @rows = $sbeams->selectOneColumn($sql);
  
  ## get '$module' section
  if (@rows){
      $additional_information = $rows[0];
      if ($additional_information =~ /<$module>.*<\/$module>/) {
	  $additional_information =~ s(<$module>.*<\/$module>)(<$module>$content<\/$module>);
      }else {
	  $additional_information .= "<$module>$content<\/$module>";
      }
  }else {
      $additional_information = "<$module>$content<\/$module>";
  }

  return $additional_information
}



###############################################################################
# getUserProfile
###############################################################################
sub getUserProfile {
  my %args = @_;
  my $SUB_NAME = "getUserProfile";

  #### Decode the argument list
  my $contact_id = $args{'contact_id'}
  || die "ERROR[$SUB_NAME]:contact_id was not passed";

  #### Define standard variables
  my (%profile);

  $profile{'username'} = $sbeams->getCurrent_username;
  $profile{'contact_id'} = $sbeams->getCurrent_contact_id;
  $profile{'work_group_id'} = $sbeams->getCurrent_work_group_id;
  $profile{'work_group_name'} = $sbeams->getCurrent_work_group_name;
  $profile{'project_id'} = $sbeams->getCurrent_project_id;
  $profile{'project_name'} = $sbeams->getCurrent_project_name;
  $profile{'user_context_id'} = $sbeams->getCurrent_user_context_id;

  return %profile;
}

###############################################################################
#                                                                             #
#                          UNUSED/DEPRECATED CODE                             #
#                                                                             #
###############################################################################

###############################################################################
# getPermissions- NOT USED!
###############################################################################
#sub getPermissions {
#  my %args = @_;
#  my $SUB_NAME = "getPermissions";
#
#  #### Decode the argument list
#  my $project_id = $args{'project_id'} || -1;
#  my $contact_id = $args{'contact_id'} || -1;
#  my $preference = $args{'preference'} || "best";
#
#  if ( $project_id < 0 || $contact_id < 0 ) {
#      die "ERROR[$SUB_NAME]: either contact_id or project_id MUST be specified";
#  }
#
#  #### Define standard variables
#  my ($sql, @rows);
#
#  #### If project_id and contact_id are submitted
#  $sql = qq~
#      SELECT UL.username,
#      MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL ELSE GPP.privilege_id END) AS "best_group_privilege_id",
#      MIN(UPP.privilege_id) AS "best_user_privilege_id"
#      FROM project P
#      JOIN user_login UL ON (P.PI_contact_id = UL.contact_id)
#      LEFT JOIN user_project_permission UPP ON( P.project_id = UPP.project_id)
#      LEFT JOIN group_project_permission GPP ON(P.project_id = GPP.project_id)
#      LEFT JOIN privilege PRIV ON(GPP.privilege_id = PRIV.privilege_id)
#      LEFT JOIN user_work_group UWG ON (GPP.work_group_id = UWG.work_group_id)
#      LEFT JOIN work_group WG ON (UWG.work_group_id = WG.work_group_id)
#      WHERE 1=1
#      AND P.record_status != 'D'
#      AND UL.record_status != 'D'
#      AND (UPP.record_status != 'D' OR UPP.record_status IS NULL)
#      AND (GPP.record_status != 'D' OR GPP.record_status IS NULL)
#      AND (PRIV.record_status != 'D' OR PRIV.record_status IS NULL)
#      AND (UWG.record_status != 'D' OR UWG.record_status IS NULL)
#      AND (WG.record_status != 'D' OR WG.record_status IS NULL)
#      AND P.project_id = '$project_id'
#      AND UL.contact_id = '$contact_id'
#      AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40 )
#      AND ( WG.work_group_name IS NOT NULL OR UPP.privilege_id IS NOT NULL )
#      GROUP BY P.project_id,P.project_tag,P.name,UL.username
#      ORDER BY UL.username,P.project_tag
#      ~;
#
#  @rows = $sbeams->selectSeveralColumns($sql);
#  my ($group_id, $user_id) = @{$rows[0]};
#
#  my $return_id;
#
#  if ($preference eq "worst") {
#      ($group_id < $user_id) ? $return_id = $group_id : $return_id = $user_id;
#  }elsif ($preference eq "best") {
#      ($group_id > $user_id) ? $return_id = $group_id : $return_id = $user_id;
#  }elsif ($preference eq "group") {
#      $return_id = $group_id;
#  }else {
#      $return_id = $user_id;
#  }
#
#  return $return_id;
#}


###############################################################################
# getPermissionsTwo- NOT USED!
###############################################################################
#
#sub getPermissionsTwo {
#  #### If username is submitted
#  my $sql = qq~
#      SELECT P.project_id,P.project_tag,P.name,UL.username,
#      MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL ELSE GPP.privilege_id END) AS "best_group_privilege_id",
#      MIN(UPP.privilege_id) AS "best_user_privilege_id"
#      FROM project P
#      JOIN user_login UL ON ( P.PI_contact_id = UL.contact_id )
#      LEFT JOIN user_project_permission UPP
#      ON ( P.project_id = UPP.project_id AND UPP.contact_id='101' )
#      LEFT JOIN group_project_permission GPP ON ( P.project_id = GPP.project_id )
#      LEFT JOIN privilege PRIV ON ( GPP.privilege_id = PRIV.privilege_id )
#      LEFT JOIN user_work_group UWG ON ( GPP.work_group_id = UWG.work_group_id
#					 AND UWG.contact_id='101' )
#      LEFT JOIN work_group WG ON ( UWG.work_group_id = WG.work_group_id )
#      WHERE 1=1
#      AND P.record_status != 'D'
#      AND UL.record_status != 'D'
#      AND ( UPP.record_status != 'D' OR UPP.record_status IS NULL )
#      AND ( GPP.record_status != 'D' OR GPP.record_status IS NULL )
#      AND ( PRIV.record_status != 'D' OR PRIV.record_status IS NULL )
#      AND ( UWG.record_status != 'D' OR UWG.record_status IS NULL )
#      AND ( WG.record_status != 'D' OR WG.record_status IS NULL )
#      AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40 )
#      AND ( WG.work_group_name IS NOT NULL OR UPP.privilege_id IS NOT NULL )
#      GROUP BY P.project_id,P.project_tag,P.name,UL.username
#      ORDER BY UL.username,P.project_tag
#  ~;
#
#}
