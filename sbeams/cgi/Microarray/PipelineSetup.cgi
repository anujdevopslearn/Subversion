#!/usr/local/bin/perl 

###############################################################################
# Program     : ProcessProject.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to submit a processing
#		job to process a set of experiments in a project.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsMA $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);

use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;

use lib "/net/arrays/Pipeline/tools/lib";
require "QuantitationFile.pl";

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMA = new SBEAMS::Microarray;
$sbeamsMA->setSBEAMS($sbeams);

###############################################################################
# Global Variables
###############################################################################
main();


###############################################################################
# Main Program:
#x
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main { 

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate());

  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);
  
  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);

  #### Print the header, do what the program does, and print footer
  $sbeamsMA->printPageHeader();
  handle_request(parameters_ref=>\%parameters);
  $sbeamsMA->printPageFooter();


} # end main


###############################################################################
# handleRequest
#
# Test for specific form variables and process the request 
# based on what the user wants to do. 
###############################################################################
sub handle_request {
  my %args = @_;
  my $parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$parameters_ref};
  my $tab = $parameters{'tab'} || "main";
  $parameters{'project_id'} = $sbeams->getCurrent_project_id();
  $parameters{'username'} = $sbeams->getCurrent_username();

  ## Establish user settings.  Is this necessary anymore?
  establish_settings();

  ## Print standard page header
  $sbeams->printUserContext();

  #### Decide where to go based on form values
  if ($tab eq 'main') {
	print_start_screen(parameters_ref=>\%parameters);
  }elsif($tab eq 'preprocess') {
	print_preprocess_screen(parameters_ref=>\%parameters);
  }elsif($tab eq 'mergereps') {
	print_mergereps_screen(parameters_ref=>\%parameters);
  }elsif($tab eq 'file_output') {
	print_file_output_screen(parameters_ref=>\%parameters);
  }elsif($tab eq 'finalize') {
	print_final_screen(parameters_ref=>\%parameters);
  }elsif($tab eq 'process') {
	send_to_pipeline(parameters_ref=>\%parameters);
  }


} # end processRequests



###############################################################################
# Print Start Screen
###############################################################################
sub print_start_screen {
  my %args = @_;
  my $parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$parameters_ref};

  ## Standard Variables
  my $sql;
  my @rows;
  my $current_project = $parameters{'project_selector'} || $sbeams->getCurrent_project_id();
  my $selectedFiles = $parameters{'selectedFiles'} || "";

  ## Processing to remove duplicates and sort the selectedFiles
  my @unsorted = split /,/,$selectedFiles;
  my (@temp, @unique);
  my %seen = ();
	
  foreach my $item (@unsorted) {
	push(@temp, $item) unless $seen{$item}++;
  }
  @unique = sort  @temp;
  shift @unique unless $unique[0] =~ /\w/;
  $selectedFiles = join (",",@unique);

  print_start_screen_javascript();

  ## Print Introductory Header
  print qq~
  <H2><U>Data Processing Pipeline</U></H2>\n
  <BR>
	Step 1: Determine Files to Process
  <FORM METHOD="POST" NAME="fileChooser"><BR>
	<INPUT TYPE="button" NAME="clearFiles" VALUE="Reset Files" OnClick="Javascript:clearFileList()">
  <INPUT TYPE="button" NAME="actionButton" VALUE="Next-->" OnClick="prepareForSubmission()">
  $LINESEPARATOR
  <BR>
  <FONT COLOR="red"><B>
Instructions:<BR>
 </FONT>
 Select Files that you would like to send through the pipeline</B>
  <BR>
	<INPUT TYPE="hidden" NAME="selectedFiles" VALUE="$selectedFiles">
	<INPUT TYPE="hidden" NAME="tab" VALUE="">
  <TABLE>
    <TR VALIGN="CENTER">
    <TD>
  ~;

  ## SQL to get projects that a user can see AND contains arrays
  my $work_group_name = $sbeams->getCurrent_work_group_name();
  $sql = qq~
      SELECT P.project_id,P.project_tag,P.name,UL.username,
             MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL
                      ELSE GPP.privilege_id END) AS "best_group_privilege_id",
             MIN(CASE WHEN P.PI_contact_id = $current_contact_id THEN 10
                      ELSE UPP.privilege_id END) AS "best_user_privilege_id",
			COUNT (AR.array_request_id) AS 'array_requests'
      FROM $TB_PROJECT P
     INNER JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id = UL.contact_id )

      LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
      ON ( P.project_id = UPP.project_id AND UPP.contact_id='$current_contact_id' )

      LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
      ON ( P.project_id = GPP.project_id )

      LEFT JOIN $TB_PRIVILEGE PRIV
      ON ( GPP.privilege_id = PRIV.privilege_id )

      LEFT JOIN $TB_USER_WORK_GROUP UWG
      ON ( GPP.work_group_id = UWG.work_group_id AND UWG.contact_id='$current_contact_id' )

      LEFT JOIN $TB_WORK_GROUP WG
      ON ( UWG.work_group_id = WG.work_group_id )

      LEFT JOIN $TBMA_ARRAY_REQUEST AR
      ON ( AR.project_id = P.project_id )

      WHERE 1=1
      AND P.record_status != 'D'
      AND UL.record_status != 'D'
      AND ( UPP.record_status != 'D' OR UPP.record_status IS NULL )
      AND ( GPP.record_status != 'D' OR GPP.record_status IS NULL )
      AND ( PRIV.record_status != 'D' OR PRIV.record_status IS NULL )
      AND ( UWG.record_status != 'D' OR UWG.record_status IS NULL )
      AND ( WG.record_status != 'D' OR WG.record_status IS NULL )
      ~;

  unless ($work_group_name eq "Admin" || $work_group_name eq "Microarray_admin") {
    $sql .= qq~
      AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40
            OR P.PI_contact_id = '$current_contact_id' )
      AND ( WG.work_group_name IS NOT NULL OR UPP.privilege_id IS NOT NULL
            OR P.PI_contact_id = '$current_contact_id' )
			~;
  }

  $sql .= qq~
      GROUP BY P.project_id,P.project_tag,P.name,UL.username
      ORDER BY UL.username,P.project_tag
  ~;

  my @rows = $sbeams->selectSeveralColumns($sql);

  my @project_names = ();

  foreach my $element (@rows) {
    if($element->[6] > 0 || $element->[5] == 10 || $element->[4] == 10){
      push(@project_names,"$element->[2] ($element->[0])");
    }
  }

	
  ## Start SELECT
  print qq~
  <TABLE>
	<TR>
	  <TD>
		<SELECT NAME="project_selector" onChange="Javascript:submit()">
      ~;

  ## Print OPTIONs.  Make current project the default SELECTED one.
  foreach my $option(@project_names){
    $option =~ /(.*)\((\d+)\)/;
	if ($2 == $current_project){
	  print "<OPTION VALUE=\"$2\" SELECTED>$1\n";
	}else {
	  print "<OPTION VALUE=\"$2\">$1\n";
	}
  }

  ## End SELECT
  print qq~
	    </SELECT>
	  </TD>
	</TR>
	<TR>
	  <TD ALIGN="right">
	  <INPUT TYPE="button" NAME="add_slides" VALUE="Add Arrays" onClick="updateArrays()">
	  </TD>
	</TR>
  </TABLE>
  </TD>
  <TD>
      ~;


  ## Print arrays affiliated with the project
  if ($current_project > 0) {
    $sql = qq~
SELECT	A.array_id,A.array_name,
	ARSM1.name AS 'Sample1Name',D1.dye_name AS 'sample1_dye',
	ARSM2.name AS 'Sample2Name',D2.dye_name AS 'sample2_dye',
	AQ.stage_location
  FROM $TBMA_ARRAY_REQUEST AR
  LEFT JOIN $TBMA_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM1 ON ( ARSL.array_request_slide_id = ARSM1.array_request_slide_id AND ARSM1.sample_index=0)
  LEFT JOIN $TBMA_LABELING_METHOD LM1 ON ( ARSM1.labeling_method_id = LM1.labeling_method_id )
  LEFT JOIN $TBMA_DYE D1 ON ( LM1.dye_id = D1.dye_id )
  LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM2 ON ( ARSL.array_request_slide_id = ARSM2.array_request_slide_id AND ARSM2.sample_index=1)
  LEFT JOIN $TBMA_LABELING_METHOD LM2 ON ( ARSM2.labeling_method_id = LM2.labeling_method_id )
  LEFT JOIN $TBMA_DYE D2 ON ( LM2.dye_id = D2.dye_id )
  LEFT JOIN $TBMA_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN $TBMA_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
 WHERE AR.project_id=$current_project
   AND AQ.array_quantitation_id IS NOT NULL
   AND AR.record_status != 'D'
   AND A.record_status != 'D'
   AND ASCAN.record_status != 'D'
   AND AQ.record_status != 'D'
   AND AQ.data_flag != 'BAD'
 ORDER BY A.array_name
     ~;
  }else {
    print qq~
  <H2>Project_id is not valid.  Please contact <A HREF="mailto:mjohnson\@systemsbiology.org">mjohnson</A> regarding this problem</h2>
  ~;
  }

  my @project_arrays = $sbeams->selectSeveralColumns($sql);

  ## Start SELECT and blank
  print qq~
      <SELECT NAME="project_arrays" SIZE=7 MULTIPLE>
      ~;

  ## Print OPTIONs.  Make current project the default SELECTED one.
  my %array_location;
  foreach my $option(@project_arrays){
    my $name = "$option->[2]($option->[3]) vs. $option->[4]($option->[5])";
    print qq~
      <OPTION VALUE=\"$option->[0]\">$name
    ~;
		$array_location{$option->[0]} = $option->[6];
  }

  ## End SELECT for project
  print qq~
      </TD>
      </TR>
      </TABLE>
      </SELECT>
			~;

	## File Status of each file that has been selected
	print qq~
	  <BR>
	  File Status:
	  <BR>
	  ~;

	## SQL to Track down stage_location information from selected arrays
  if ($selectedFiles) {
	$sql = qq~
SELECT	A.array_id,A.array_name,
	ARSM1.name AS 'Sample1Name',D1.dye_name AS 'sample1_dye',
	ARSM2.name AS 'Sample2Name',D2.dye_name AS 'sample2_dye',
	AQ.stage_location
  FROM $TBMA_ARRAY_REQUEST AR
  LEFT JOIN $TBMA_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM1 ON ( ARSL.array_request_slide_id = ARSM1.array_request_slide_id AND ARSM1.sample_index=0)
  LEFT JOIN $TBMA_LABELING_METHOD LM1 ON ( ARSM1.labeling_method_id = LM1.labeling_method_id )
  LEFT JOIN $TBMA_DYE D1 ON ( LM1.dye_id = D1.dye_id )
  LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM2 ON ( ARSL.array_request_slide_id = ARSM2.array_request_slide_id AND ARSM2.sample_index=1)
  LEFT JOIN $TBMA_LABELING_METHOD LM2 ON ( ARSM2.labeling_method_id = LM2.labeling_method_id )
  LEFT JOIN $TBMA_DYE D2 ON ( LM2.dye_id = D2.dye_id )
  LEFT JOIN $TBMA_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN $TBMA_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
	WHERE A.array_id IN ($selectedFiles)
   AND AQ.array_quantitation_id IS NOT NULL
   AND AR.record_status != 'D'
   AND A.record_status != 'D'
   AND ASCAN.record_status != 'D'
   AND AQ.record_status != 'D'
   AND AQ.data_flag != 'BAD'
	ORDER BY A.array_id
	~; 

	my @selected_arrays = $sbeams->selectSeveralColumns($sql);
	foreach my $result_id (@selected_arrays){
	  my $id = $result_id->[0];
	  my $name = "$result_id->[2]($result_id->[3]) vs. $result_id->[4]($result_id->[5])";
	  my $quant_file = $result_id->[6];

	  #### If the data file is okay
	  if ( -e $quant_file ) {
		print "<FONT COLOR=\"green\">$quant_file Verified -- Array \#$id</FONT><BR>\n";
	  } else {
		print "<FONT COLOR=\"red\">ERROR: $quant_file -- Array \#$id</FONT>".
		  "&nbsp;<A HREF=\"mailto:mjohnson\@systemsbiology.org\"> Notify Array Core</A><BR>\n";
	  }
	}
	print qq~
	  </FORM>
	  ~;
	return;
  }
}

###############################################################################
# Print Start Screen Javascript
###############################################################################
sub print_start_screen_javascript {
	my $javascript = qq~
<SCRIPT LANGUAGE="Javascript">
function updateArrays() {
  var currentList = document.fileChooser.project_arrays;
	var selectedFiles = document.fileChooser.selectedFiles.value;
	var fileSelected = "false"
  for(var i=currentList.length;i>=0;i--){
    if((currentList.options[i]!=null) && (currentList.options[i].selected)){
			var newFile = currentList.options[i].value;
			selectedFiles += "," + newFile;
			fileSelected = "true"
	  }
  }
	document.fileChooser.selectedFiles.value = selectedFiles;
	if (fileSelected == "true") {
		document.fileChooser.submit();
	}else {
		return;
	}
}

function clearFileList() {
	document.fileChooser.selectedFiles.value = "";
	document.fileChooser.submit();
}

function prepareForSubmission() {
	if (document.fileChooser.selectedFiles.value == "") {
		alert("Need to Select Files");
		return;
  }else {
		document.fileChooser.tab.value="preprocess";
		document.fileChooser.submit();
  }
}

</SCRIPT>		
			~;
	print $javascript;
}





###############################################################################
# Print Preprocess
###############################################################################
sub print_preprocess_screen {
  my %args = @_;
  my $parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$parameters_ref};

  ## Standard Variables
  my $sql;
  my @rows;
  my $current_project = $parameters{'project_selector'} || $sbeams->getCurrent_project_id();

  my $selectedFiles = $parameters{'selectedFiles'} || "";

  ## Processing to remove duplicates and sort the selectedFiles
  my @unsorted = split /,/,$selectedFiles;
  my (@temp, @unique);
  my %seen = ();
	
  foreach my $item (@unsorted) {
	push(@temp, $item) unless $seen{$item}++;
  }

  @unique = sort  @temp;
  shift @unique unless $unique[0] =~ /\w/;
  $selectedFiles = join (",",@unique);

  print_preprocess_javascript();

  ## Print Introductory Header
  print qq~
  <H2><U>Data Processing Pipeline</U></H2>\n
  <BR>
	Step 2: Background Subtraction and Normalization
  <FORM METHOD="POST" NAME="preprocessForm"><BR>
	<INPUT TYPE="hidden" NAME="selectedFiles" VALUE="$selectedFiles">
	<INPUT TYPE="hidden" NAME="tab" VALUE="">
	<INPUT TYPE="button" VALUE="<--Back" OnClick="history.go(-1)">
  <INPUT TYPE="button" NAME="actionButton" VALUE="Next-->" OnClick="prepareForSubmission()">
  $LINESEPARATOR
  <BR>
  <FONT COLOR="red"><B>
Instructions:<BR>
 </FONT>
In this step, the spot intensity data is merged with spot location information.<br>
Background subtraction and normalization follows. More information can be found at [URL]</B>
  <BR>
  <TABLE>
    <TR VALIGN="CENTER">
    <TD>
  ~;

	print qq~
<!-- Preprocess Section -->

    <BR>
	  <TABLE>

<!-- Background Subtraction -->
	  <TR>
	    <TD ALIGN="right">
	    <INPUT NAME="BGSubtractButton" TYPE="button" VALUE="Add Background Subtraction" onClick="addToPP(this.name)">
	    </TD>
	    <TD>
	    <IMG SRC="../../images/ma_left_arrow.gif">
	    </TD>
	    <TD>
	    <SELECT NAME="BGSelector">
	      <OPTION NAME="localBG" VALUE="Local Background" SELECTED>Local Background
	      <OPTION NAME="smoothedBG" VALUE="Smoothed Background">Smoothed Background
	    </SELECT>
	    </TD>
	  </TR>

<!-- Normalization -->
	  <TR>
	    <TD ALIGN="right">
	    <INPUT NAME="normalizeButton" TYPE="button" VALUE="Add Normalization" onClick="addToPP(this.name)">
	    </TD>
	    <TD>
	    <IMG SRC="../../images/ma_left_arrow.gif">
	    </TD>
	    <TD>
	    <SELECT NAME="normSelector">
	      <OPTION NAME="medNorm" VALUE="Median Normalization" SELECTED>Median Normalization
	      <OPTION NAME="bumNorm" VALUE="Bumgarner Normalization">Bumgarner Normalization
	    </SELECT>
	    </TD>
	  </TR>

<!-- Filters -->
	  <TR>
	    <TD ALIGN="right">
	    <INPUT NAME="filterButton" TYPE="button" VALUE="Add Filter" onClick="addToPP(this.name)">
	    </TD>
	    <TD>
	    <IMG SRC="../../images/ma_left_arrow.gif">
	    </TD>
	    <TD>
	    <SELECT NAME="filterSelector">
	      <OPTION NAME="localBGfilter" VALUE="close to local background" SELECTED>close to local background
	      <OPTION NAME="smoothBGfilter" VALUE="close to smoothed background">close to smoothed background
	      <OPTION NAME="controlfilter" VALUE="close to control spots">close to control spots
	      <OPTION NAME="absentprintFilter"VALUE="absent in print batch (less stringent)">absent in print batch (less stringent)
	      <OPTION NAME="marginalprintFilter" VALUE="marginal or absent in print batch (more stringent)">marginal or absent in print batch (more stringent)
	      <OPTION NAME="failedPCRFilter" VALUE="failed PCR">failed PCR
	    </SELECT>
	    </TD>
	  </TR>

<!-- Scale to Value -->
          <TR>
	    <TD ALIGN="right">
	    <INPUT NAME="scaleButton" TYPE="button" VALUE="Add Scale" onClick="addToPP(this.name)">
	    </TD>
	    <TD>
	    <IMG SRC="../../images/ma_left_arrow.gif">
	    </TD>
	    <TD>
	    <B>Scale median value to</B>&nbsp;
            <INPUT TYPE="text" SIZE="10" NAME="scaleValue" onChange="verifyNumber(this.value,this.name)">
	    </TD>
	  </TR>

	  </TABLE>

<!-- Text/Graphic Description of Preprocessing Steps -->
	  <TABLE>
	  <TR>
	    <TD>
	    <SELECT NAME="ppRecipe" SIZE="10" MULTIPLE>
	      <OPTION NAME="startSpacer" VALUE="startPP">---------------START OF PREPROCESS---------------
	      <OPTION NAME="endSpacer" VALUE="endPP">-----------------END OF PREPROCESS----------------
	    </SELECT>
	    </TD>
	    <TD>
	    <INPUT TYPE="button" NAME="ppUpButton" VALUE="Move Up" onClick="moveUp(document.preprocessForm.ppRecipe,1)"><BR>
	    <INPUT TYPE="button" NAME="ppDownButton" VALUE="Move Down" onClick= "moveDown(document.preprocessForm.ppRecipe,1)"><BR>
	    <INPUT TYPE="button" NAME="ppRemove" VALUE="Remove" onClick="removeFromPP()">
	    </TD>
	  </TR>
	  </TABLE>
<!-- End Preprocess Section -->
~;
}



###############################################################################
# Print Preprocess Javascript
###############################################################################
sub print_preprocess_javascript {
	my $javascript = qq~
<SCRIPT LANGUAGE="Javascript">

function prepareForSubmission() {
	var ppList = document.preprocessForm.ppRecipe;
	for (var i=1; i<ppList.length-1;i++){
			ppList.options[i].selected = true;
	}
		document.preprocessForm.tab.value="mergereps";
		document.preprocessForm.submit();
}

function moveUp(list, start){
  //'start' is determines where on the list this is applicable.
  //This was added to cement the position of the first/last elements
  if (list.options.selectedIndex < start) return;
  for(var i=0; i<(list.options.length); i++){
    if(list.options[i].selected &&
      list.options[i] != "" &&
      list.options[i] != list.options[start]){
      var tmpOptionValue = list.options[i].value;
      var tmpOptionText  = list.options[i].text;

      list.options[i].value   = list.options[i-1].value;
      list.options[i].text    = list.options[i-1].text;

      list.options[i-1].value = tmpOptionValue;
      list.options[i-1].text  = tmpOptionText;

      list.options[i-1].selected = true;
      list.options[i].selected = false;
    }
  }
}

function moveDown(list, start){
  //'start' is determines where on the list this is applicable.
  //This was added to cement the position of the first/last elements
  var start = (list.options.length-1 -start);
  if (list.options.selectedIndex > start) return;
  for (var i=list.options.length-1; i>=0; i--){
    if(list.options[i].selected &&
       list.options[i] != "" &&
       list.options[i] != list.options[start]){
      var tmpOptionValue = list.options[i+1].value;
      var tmpOptionText  = list.options[i+1].text;

      list.options[i+1].value = list.options[i].value;
      list.options[i+1].text  = list.options[i].text;

      list.options[i].value = tmpOptionValue;
      list.options[i].text  = tmpOptionText;

      list.options[i+1].selected = true;
      list.options[i].selected = false;
    }
  }
}


function verifyNumber(testValue,testLocation){
  var location;
  if(testLocation=="preprocessBaseValue"){location=document.preprocessForm.preprocessBaseValue;}
  if(testLocation=="preprocessSatValue") {location=document.preprocessForm.preprocessSatValue;}
  if(testLocation=="preprocessScaleValue"){location=document.preprocessForm.preprocessScaleValue;}

  //need just an integer
  if(testLocation=="errorModel" || testLocation=="repValue"){
    var number = parseInt(testValue);
    if(isNaN(number)){
      alert(testValue+" not a number");
      location.value ="";
      return;
    }
    else{location.value = number;return;}
  }

  //need double/float
  var number = parseFloat(testValue);
  if(isNaN(number)){
    alert(testValue+" not a number");
    location.value = "";
    return;
  }
  else{location.value = number;return;}
}//end verifyNumber


//addToPP-- adds item to PreProcess menu
function addToPP(name){
  var valueToAdd;
  if (name == "BGSubtractButton") {
    valueToAdd = document.preprocessForm.BGSelector.options[document.preprocessForm.BGSelector.selectedIndex].value;
  }else if (name == "normalizeButton") {
    valueToAdd = document.preprocessForm.normSelector.options[document.preprocessForm.normSelector.selectedIndex].value;
  }else if (name == "filterButton") {
    valueToAdd = document.preprocessForm.filterSelector.options[document.preprocessForm.filterSelector.selectedIndex].value;
  }else if (name == "scaleButton") {
	  if (document.preprocessForm.scaleValue.value == "") {
			alert ("Select Scale Value");
			return;
	  }else {
			valueToAdd = "Scale Median To " + document.preprocessForm.scaleValue.value;
	  }
  }

  var length = document.preprocessForm.ppRecipe.length;
  var recipe = document.preprocessForm.ppRecipe;
  //duplicate the endPP item and change the previous endPP item to the processing option
  recipe.options[recipe.length] = new Option(recipe.options[length-1].text, recipe.options[length-1].value);
  recipe.options[recipe.length - 2].text = valueToAdd;//2 instead of 1 because the length has increased by 1
  recipe.options[recipe.length - 2].value= valueToAdd;
}

function removeFromPP(){
  var ppList  = document.preprocessForm.ppRecipe;
  for (var i=ppList.length-2; i>0; i--){
    if (ppList.options[i].selected){
      ppList.options[i] = null;
    }
  }
}


</SCRIPT>		
			~;
	print $javascript;
}



###############################################################################
# Print mergereps screen
###############################################################################
sub print_mergereps_screen {
  my %args = @_;
  my $parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$parameters_ref};

  ## Standard Variables
  my $sql;
  my @rows;
  my $current_project = $parameters{'project_selector'} || $sbeams->getCurrent_project_id();
  my $selected_files = $parameters{'selectedFiles'};
  my $pp_recipe = $parameters{'ppRecipe'};

  print_mergereps_javascript();

  ## Print Introductory Header
  print qq~
  <H2><U>Data Processing Pipeline</U></H2>\n
  <BR>
	Step 3: Replicate Merging and Statisical Significance
  <FORM METHOD="POST" NAME="mergerepsForm"><BR>
	<INPUT TYPE="hidden" NAME="selectedFiles" VALUE="$selected_files">
	<INPUT TYPE="hidden" NAME="ppRecipe" VALUE="$pp_recipe">
	<INPUT TYPE="hidden" NAME="mergeRecipe" VALUE="">
	<INPUT TYPE="hidden" NAME="vsRecipe" VALUE="">
	<INPUT TYPE="hidden" NAME="tab" VALUE="">
	<INPUT TYPE="button" VALUE="<--Back" OnClick="history.go(-1)">
  <INPUT TYPE="button" NAME="actionButton" VALUE="Next-->" OnClick="prepareForSubmission()">
  $LINESEPARATOR
  <BR>
  <FONT COLOR="red"><B>
Instructions:<BR>
  </FONT>
	<B><FONT SIZE="-1" COLOR="#006600">Merge Replicates:</B>&nbsp;
    <A HREF="Javascript:getDirections('http://www.systemsbiology.org/ArrayProcess/readme/mergeReps.html')">
    <img src="$HTML_BASE_DIR/images/redqmark.gif" border=0 alt="Help">
    </A>
    <BR>
    <TABLE BORDER=0>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="errorModel" VALUE="-opt">
      </TD>
      <TD>
      &nbsp;Minimum &lt;num&gt; replicate measurements:&nbsp;
      &nbsp;<INPUT TYPE="text" NAME="errorModelValue" size="10" onChange="processNumber(this.value,'errorModel');">
      &nbsp;<a href="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?help_text_id=6','Help','width=400,height=300,resizable=yes');return false"><img src="$HTML_BASE_DIR/images/redqmark.gif" border=0 alt="Help"></a>
      </TD>
    </TR>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="excludeGenes" VALUE="-exclude" onClick="checkSwitch('general')" CHECKED>
      </TD>
      <TD>
      &nbsp;Use general list of bad genes
      </TD>
    </TR>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="excludeLocalGenes" VALUE="-exclude" onClick="checkSwitch('local')">
      </TD>
      <TD>
	&nbsp;Select local file of bad genes:
      </TD>
    </TR>
    <TR>
      <TD>
	&nbsp;
      </TD>
      <TD>
	&nbsp;<INPUT TYPE = "text" NAME = "excludeFile"  SIZE=50>
	&nbsp;<A HREF="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?help_text_id=7','Help','width=400,height=300,resizable=yes');return false">
	<img src="$HTML_BASE_DIR/images/redqmark.gif" border=0 alt="Help">
	</A>
	<br><FONT SIZE="-2">*must specify full path of bad gene file
      </TD>
    </TR>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="filterGenes"  VALUE="-filter" CHECKED>
      </TD>
      <TD>
	&nbsp;Filter Outliers
	&nbsp;<a href="#" onClick="window.open('$HTML_BASE_DIR/cgi/help_popup.cgi?help_text_id=8','Help','width=400,height=300,resizable=yes');return false"><img src="$HTML_BASE_DIR/images/redqmark.gif" border=0 alt="Help"></a>
      </TD>
    </TR>
    </TABLE>
    <BR>
    <B><FONT SIZE="-1" COLOR="#006600">VERA/SAM:</B>&nbsp;<A HREF="Javascript:getDirections('http://www.systemsbiology.org/VERAandSAM')"><img src="$HTML_BASE_DIR/images/redqmark.gif" border=0 alt="Help"></A>
    <BR>
    <TABLE BORDER=0>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="useVERAandSAM"  VALUE="useVS" CHECKED>
      </TD>
      <TD>
	&nbsp;<FONT COLOR="red">Use VERA and SAM</FONT>
	&nbsp;<A HREF="Javascript:getDirections('http://www.systemsbiology.org/VERAandSAM')"><img src="$HTML_BASE_DIR/images/redqmark.gif" border=0 alt="Help"></A>
      </TD>
    </TR>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="veraCrit" VALUE="critValue">
      </TD>
      <TD>
	&nbsp;Cease Optimization when changes per step are less than:
	&nbsp;<INPUT TYPE="text" NAME="veraCritValue" size="10" onChange="processNumber(this.value,'veraCritValue')">
      </TD>
    </TR>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="veraEvolFlag" VALUE="-evol">
      </TD>
      <TD>
	&nbsp;Generate file showing how parameters converge
      </TD>
    </TR>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="debugFlag" VALUE="-debug">
      </TD>
      <TD>
	&nbsp;Generate debug file
      </TD>
    </TR>
    <TR>
      <TD>
      <INPUT TYPE="checkbox" NAME="modelFlag" VALUE="-model">
      </TD>
      <TD>
	&nbsp;Use your own error model
	&nbsp;<INPUT TYPE="file"     NAME="modelFile" size=30>
      </TD>
    </TR>
		</TABLE>
		</FORM>
 ~;
}

###############################################################################
# Print Mergereps Javascript
###############################################################################
sub print_mergereps_javascript {
	my $javascript = qq~
<SCRIPT LANGUAGE="Javascript">

function getDirections(URL){
  var newWindow;
  newWindow = window.open(URL);
}

function prepareForSubmission () {
	var mergeRecipe =	document.mergerepsForm.mergeRecipe;
	var vsRecipe = document.mergerepsForm.vsRecipe;
	
	var mergeRec = "";
	var vsRec = "";

  if (document.mergerepsForm.errorModel.checked == true && 
			document.mergerepsForm.errorModelValue.value==""){
		alert("no value set for MergeReps: replicate count.");
		return false;
  }

  if (document.mergerepsForm.excludeLocalGenes.checked == true && 
			document.mergerepsForm.excludeFile.value==""){
		alert("No 'Bad Gene' file specified.");
		return false;
  }

  if (document.mergerepsForm.veraCrit.checked == true && 
			document.mergerepsForm.veraCritValue.value=="") {
		alert("no value set for VERA's delta value for optimization.");
		return false;
  }
  if (document.mergerepsForm.veraCrit.checked == false && 
			document.mergerepsForm.veraCritValue.value != ""){
			alert("no delta value set for VERA.");
			return false;
  }

//'opt' flag
	if (document.mergerepsForm.errorModel.checked == true){
			mergeRec += "opt:" + document.mergerepsForm.errorModelValue.value + ","; 
	}
//'exclude' flag
	if (document.mergerepsForm.excludeGenes.checked == true){
			mergeRec += "exclude:/net/arrays/Pipeline/tools/etc/excluded_gene_names,";
	}
	if (document.mergerepsForm.excludeLocalGenes.checked == true) {
			mergeRec += "exclude:"+document.mergerepsForm.excludeFile.value+",";
	}
//'filter' flag
	if (document.mergerepsForm.filterGenes.checked == true) {
		mergeRec += "filter";
  }


	if (document.mergerepsForm.useVERAandSAM.checked == true){
			vsRec += "useVS,";
		if (document.mergerepsForm.veraCrit.checked == true) {
			vsRec += "crit:" + document.mergerepsForm.veraCritValue.value + ",";
	  }
		if (document.mergerepsForm.veraEvolFlag.checked == true){
			vsRec += "evol,";
		}
		if (document.mergerepsForm.debugFlag.checked == true){
			vsRec +="debug,";
		}
		if (document.mergerepsForm.modelFlag.checked == true){
				vsRec +="model:"+document.mergerepsForm.modelFile.value;
		}
	}

	mergeRecipe.value = mergeRec;
	vsRecipe.value = vsRec;
	document.mergerepsForm.tab.value = "file_output";
	document.mergerepsForm.submit();
}

	function checkTheBox(location){
		var valuebox;
		var box;
		if (location == 'errorModel'){
			valuebox = document.mergerepsForm.errorModelValue.value;
			box = document.mergerepsForm.errorModel;
	  }
		if (location == 'veraCritNumber'){
				valuebox = document.mergerepsForm.veraCritValue.value;
				box = document.mergerepsForm.veraCrit;
		}
		if (valuebox != ""){
				box.checked = true;
		}
	}

function checkSwitch(location){
  var primary;
  var secondary;
  if (location == 'general'){
    primary   = document.mergerepsForm.excludeGenes;
    secondary = document.mergerepsForm.excludeLocalGenes;
  }
  if (location == 'local'  ){
    primary   = document.mergerepsForm.excludeLocalGenes;
    secondary = document.mergerepsForm.excludeGenes;
  }
  if (primary.checked){secondary.checked = false;}
}//end checkSwitch


function processNumber(testValue,testLocation){
  var location;
  if(testLocation=="veraCritValue")      {location=document.mergerepsForm.veraCritValue;}
  if(testLocation=="errorModel")         {location=document.mergerepsForm.errorModel;}

  //need just an integer
  if(testLocation=="errorModel"){
    var number = parseInt(testValue);
    if(isNaN(number)){
      alert(testValue+" not a number");
      location.value ="";
      return;
    }else{
			location.value = number;
			checkTheBox('errorModel');
			return;
	  }
  }

  //need double/float
  var number = parseFloat(testValue);
  if(isNaN(number)){
    alert(testValue+" not a number");
    location.value = "";
    return;
  }
  else{
		location.value = number;
		checkTheBox('veraCritNumber');
		return;
  }
}//end processNumber

</SCRIPT>		
			~;
	print $javascript;
}


###############################################################################
# Print_file_output screen
###############################################################################
sub print_file_output_screen {
  my %args = @_;
  my $parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$parameters_ref};

  ## Standard Variables
  my $sql;
  my @rows;
  my $current_project = $parameters{'project_selector'} || $sbeams->getCurrent_project_id();
  my $user = $sbeams->getCurrent_username();
  my $selected_files = $parameters{'selectedFiles'};
  my $pp_recipe = $parameters{'ppRecipe'};
  my $merge_recipe = $parameters{'mergeRecipe'};
  my $vs_recipe = $parameters{'vsRecipe'};

  print_file_output_javascript();

  ## Print Introductory Header
  print qq~
  <H2><U>Data Processing Pipeline</U></H2>\n
  <BR>
	Step 4: File Output Selection and Database Loading
  <FORM METHOD="POST" NAME="fileOutputForm"><BR>
	<INPUT TYPE="hidden" NAME="selectedFiles" VALUE="$selected_files">
	<INPUT TYPE="hidden" NAME="ppRecipe" VALUE="$pp_recipe">
	<INPUT TYPE="hidden" NAME="mergeRecipe" VALUE="$merge_recipe">
	<INPUT TYPE="hidden" NAME="vsRecipe" VALUE="$vs_recipe">
	<INPUT TYPE="hidden" NAME="tab" VALUE="">
	<INPUT TYPE="button" VALUE="<--Back" OnClick="history.go(-1)">
  <INPUT TYPE="button" NAME="actionButton" VALUE="Next-->" OnClick="prepareForSubmission()">
  $LINESEPARATOR
  <BR>
  <FONT COLOR="red"><B>
Instructions:<BR>
  </FONT>
	Select which files you want kept in your project directory.<BR> 
	The data processing parameters are always kept on file.<BR>
	Should you decide that you need a file that hasn\'t been saved, contact <A HREF="mailto:mjohnson\@systemsbiology.org">mjohnson</A> to rerun your processing.<BR><BR><BR>

	<INPUT TYPE="checkbox" NAME="emailNotify" VALUE="notify" CHECKED> Email Notify Process Completion
	<INPUT TYPE="text" NAME="emailAddress" SIZE="50" VALUE="$user\@systemsbiology.org"><BR>

		Select project output directory: <SELECT NAME="outputDirectory">
	~;

	## Print all projects for which the user has write access
  my $work_group_name = $sbeams->getCurrent_work_group_name();
  $sql = qq~
      SELECT P.project_id,P.project_tag,P.name,UL.username,
             MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL
                      ELSE GPP.privilege_id END) AS "best_group_privilege_id",
             MIN(CASE WHEN P.PI_contact_id = $current_contact_id THEN 10
                      ELSE UPP.privilege_id END) AS "best_user_privilege_id",
			COUNT (AR.array_request_id) AS 'array_requests'
      FROM $TB_PROJECT P
     INNER JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id = UL.contact_id )

      LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
      ON ( P.project_id = UPP.project_id
	   AND UPP.contact_id='$current_contact_id' )

      LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
      ON ( P.project_id = GPP.project_id )

      LEFT JOIN $TB_PRIVILEGE PRIV
      ON ( GPP.privilege_id = PRIV.privilege_id )

      LEFT JOIN $TB_USER_WORK_GROUP UWG
      ON ( GPP.work_group_id = UWG.work_group_id
	   AND UWG.contact_id='$current_contact_id' )

      LEFT JOIN $TB_WORK_GROUP WG
      ON ( UWG.work_group_id = WG.work_group_id )

      LEFT JOIN $TBMA_ARRAY_REQUEST AR
      ON ( AR.project_id = P.project_id )

      WHERE 1=1
      AND P.record_status != 'D'
      AND UL.record_status != 'D'
      AND ( UPP.record_status != 'D' OR UPP.record_status IS NULL )
      AND ( GPP.record_status != 'D' OR GPP.record_status IS NULL )
      AND ( PRIV.record_status != 'D' OR PRIV.record_status IS NULL )
      AND ( UWG.record_status != 'D' OR UWG.record_status IS NULL )
      AND ( WG.record_status != 'D' OR WG.record_status IS NULL )
      ~;

  unless ($work_group_name eq "Admin" || $work_group_name eq "Microarray_admin") {
    $sql .= qq~
      AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40
            OR P.PI_contact_id = '$current_contact_id' )
      AND ( WG.work_group_name IS NOT NULL OR UPP.privilege_id IS NOT NULL
            OR P.PI_contact_id = '$current_contact_id' )
			~;
  }

  $sql .= qq~
      GROUP BY P.project_id,P.project_tag,P.name,UL.username
      ORDER BY UL.username,P.project_tag
  ~;

  my @rows = $sbeams->selectSeveralColumns($sql);

  my @project_names = ();

  foreach my $element (@rows) {
    if($element->[6] > 0 || $element->[5] == 10 || $element->[4] == 10){
      push(@project_names,"$element->[2] ($element->[0])");
    }
  }

  ## Print OPTIONs.  Make current project the default SELECTED one.
  foreach my $option(@project_names){
	$option =~ /(.*)\((\d+)\)/;
	if ($2 eq $current_project){
	  print qq~
				 <OPTION VALUE=\"$2\" SELECTED>$1 (\#$2)
				 ~;
	}else {
	  print qq~
				 <OPTION VALUE=\"$2\">$1 (\#$2)
				 ~;
	}
  }

print qq~
		</SELECT>

    <TABLE BORDER="3" BORDERCOLOR="#888888">
	  <TR BGCOLOR="\#1C3887" >
	    <TD><FONT COLOR="white">Keep?</FONT></TD>
	    <TD><FONT COLOR="white">File Type</FONT></TD>
	    <TD><FONT COLOR="white">File Description</FONT></TD>
	    <TD><FONT COLOR="white">File Suffix</FONT></TD>
    </TR>
		<TR>
		  <TD><INPUT TYPE="checkbox" name="keepDappleFiles" CHECKED></TD>
			<TD>Dapple File</TD>
			<TD>Files from spotfinding on AnalyzerDG are changed to another format so they can be sent through the pipeline.  These files don\'t contain any information that is not in the AnalyzerDG files</TD>
			<TD>.dapple or .dapplefmt</TD>
		</TR>
		<TR>
		  <TD><INPUT TYPE="checkbox" name="keepRepFiles" CHECKED></TD>
			<TD>Rep File</TD>
			<TD>Files after background subtraction and normalization</TD>
			<TD>.rep</TD>
		</TR>
		<TR>
			<TD><INPUT TYPE="checkbox" name="keepRepImageFiles" CHECKED></TD>			
			<TD>Rep Image</TD>
			<TD>Scatter plot images of intensities (e.g. Cy3 vs. Cy5)</TD>
			<TD>.rep.jpg</TD>
		</TR>
		<TR>
			<TD><INPUT TYPE="checkbox" name="keepFTFiles" CHECKED></TD>
			<TD>File Table</TD>
			<TD>Used to identify the direction (e.g. Cy3 vs. Cy5 OR Cy5 vs. Cy3) of each file prior to merging replicates</TD>
			<TD>.ft</TD>
		</TR>
		<TR>
			<TD><INPUT TYPE="checkbox" name="keepMergeFiles" CHECKED></TD>
			<TD>Merge File</TD>
			<TD>Data table of merged replicates for each reporter</TD>
			<TD>.opt.merge or .all.merge</TD>
		</TR>
		<TR>
			<TD><INPUT TYPE="checkbox" name="keepModelFiles" CHECKED></TD>
			<TD>Model File</TD>
			<TD>Error Model parameters created by VERA</TD>
			<TD>.model</TD>
		</TR>
		<TR>
			<TD><INPUT TYPE="checkbox" name="keepSigFiles" CHECKED></TD>
			<TD>Sig File</TD>
			<TD>Table of merged replicates and statistical analysis of differential expression</TD>
			<TD>.sig</TD>
		</TR>
		<TR>
			<TD><INPUT TYPE="checkbox" name="keepCloneFiles" CHECKED></TD>
			<TD>Clone File</TD>
			<TD>Table of merged replicates and statistical analysis of differential expression.  Additional biological and identification information is added.</TD>
			<TD>.clone</TD>
		</TR>
		</TABLE>
		<BR>
		</FORM>
~;
#		Would you like these data loaded into SBEAMS? This will overwrite any condition data you\'ve loaded.<BR>
#		<INPUT TYPE="radio" NAME="dataLoad" VALUE="Yes" CHECKED>Yes, load these data into SBEAMS
#		<INPUT TYPE="radio" NAME="dataLoad" VALUE="No">No, do <FONT COLOR="red">not</FONT> load these
#		</FORM>
#		~;
}



###############################################################################
# Print File Output Javascript
###############################################################################
sub print_file_output_javascript {
	my $javascript = qq~
<SCRIPT LANGUAGE="Javascript">
function prepareForSubmission () {
	document.fileOutputForm.tab.value = "finalize";
	document.fileOutputForm.submit();
}

</SCRIPT>		
			~;
	print $javascript;
}




###############################################################################
# Print Finalize screen
###############################################################################
sub print_final_screen {
  my %args = @_;
  my $parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$parameters_ref};

  ## Standard Variables
  my $sql;
  my @rows;
  my $day = (localtime)[3];
  my $month = (localtime)[4] + 1;
  my $year = (localtime)[5] + 1900;
 
  print_final_screen_javascript();

  ## Print Introductory Header
  print qq~
  <H2><U>Data Processing Pipeline</U></H2>\n
  <BR>
	Step 5: Pipeline Finalization
  <FORM METHOD="POST" NAME="finalForm"><BR>
	<INPUT TYPE="hidden" NAME="tab" VALUE="">
	<INPUT TYPE="hidden" NAME="workingDir" VALUE = "$parameters{'outputDirectory'}">
	<INPUT TYPE="button" VALUE="<--Back" OnClick="history.go(-1)">
  <INPUT TYPE="button" NAME="actionButton" VALUE="Send to Pipeline!" OnClick="prepareForSubmission()">
  $LINESEPARATOR
  <BR>
  <FONT COLOR="red"><B>
Instructions:<BR>
  </FONT>
Add a project title, comments, and verify the plan file.<BR><BR>
	Title of this processing event (timestamp is default): <INPUT TYPE="text" name="proc_name">
	<BR>
	Add any comments you wish to have filed with this particular data processing.
	<BR>
	<TEXTAREA NAME="projectComments" ROWS="10" COLS="70">
Project ID:  $parameters{'outputDirectory'}
Date:  $month-$day-$year  (month-day-year)
User:  $parameters{'username'}
Project Comments:
	</TEXTAREA>
<BR>
<BR>
Your comments will be appended to processing plan, which is written below for manual editing.<BR>
Editing this file is not recommended unless you are familiar with how to manipulate it.<BR>
<TEXTAREA NAME = "planFileText" COLS = 70 ROWS = 25>
~;


## Create Plan File

## Printing Preprocess Information
	# Get Slide Information
	my $sql_query = qq~
SELECT	A.array_name,
	ARSM1.name AS 'Sample1Name',D1.dye_name AS 'sample1_dye',
	ARSM2.name AS 'Sample2Name',D2.dye_name AS 'sample2_dye',
	AQ.array_quantitation_id,AQ.data_flag AS 'quan_flag',
	AQ.stage_location,AL.source_filename AS 'key_file'
  FROM $TBMA_ARRAY_REQUEST AR
  LEFT JOIN $TBMA_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM1 ON ( ARSL.array_request_slide_id = ARSM1.array_request_slide_id AND ARSM1.sample_index=0)
  LEFT JOIN $TBMA_LABELING_METHOD LM1 ON ( ARSM1.labeling_method_id = LM1.labeling_method_id )
  LEFT JOIN $TBMA_DYE D1 ON ( LM1.dye_id = D1.dye_id )
  LEFT JOIN $TBMA_ARRAY_REQUEST_SAMPLE ARSM2 ON ( ARSL.array_request_slide_id = ARSM2.array_request_slide_id AND ARSM2.sample_index=1)
  LEFT JOIN $TBMA_LABELING_METHOD LM2 ON ( ARSM2.labeling_method_id = LM2.labeling_method_id )
  LEFT JOIN $TBMA_DYE D2 ON ( LM2.dye_id = D2.dye_id )
  LEFT JOIN $TBMA_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN $TBMA_ARRAY_LAYOUT AL ON ( A.layout_id = AL.layout_id )
  LEFT JOIN $TBMA_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN $TBMA_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
 WHERE A.array_id IN ($parameters{'selectedFiles'})
   AND AQ.array_quantitation_id IS NOT NULL
   AND AR.record_status != 'D'
   AND A.record_status != 'D'
   AND ASCAN.record_status != 'D'
   AND AQ.record_status != 'D'
   AND AQ.data_flag != 'BAD'
 ORDER BY A.array_name
     ~;
  #print "$sql_query\n";
  my @rows = $sbeams->selectSeveralColumns($sql_query);

  # Preprocess variables
  my $preprocess_commands = "";
  my @preprocess_options = split /,/,$parameters{'ppRecipe'};

  # Mergereps variables
  my %mergereps_conditions;
  my @mr_info;

  # Map/Key file for postSam
  my $postSam_key_file;

  foreach my $element (@rows) {
	my ($array_name, 
		$sample1_name, $sample1_dye,
		$sample2_name, $sample2_dye,
		$quantitation_id, $data_flag,
		$quantitation_file, $key_file) = @{$element};

	$postSam_key_file = $key_file;

	if (-e $quantitation_file) {
	  
	  ## Preprocess command
	  my $rep_file = $quantitation_file;
	  $rep_file =~ s(^.*/)();				
	  $rep_file =~ s(\..+)(\.rep);	
	  $preprocess_commands = "#PREPROCESS\n".
		"file_name = $quantitation_file\n".
		"map_file = $key_file\n".
		"output_file = $rep_file\n".
		"preprocess_option = Integrate Hi-Lo Scans\n";
	  
	  foreach my $pp_option (@preprocess_options) {
		$preprocess_commands .= "preprocess_option = $pp_option\n";
	  }
	  $preprocess_commands .= "EXECUTE = preprocess\n\n";
	  ## End Preprocess command

	  ## Print Preprocess Commands
	  print $preprocess_commands;


	  ## Read into the quantitation file
	  my %quantitation_data = readQuantitationFile(inputfilename=>"$quantitation_file",
												   headeronly=>1);
	  
	  unless ($quantitation_data{success}) {
		#print "#--- $quantitation_data{error_msg}";
	  }else {
		my @channels = @{$quantitation_data{channels}};
		my $number_of_channels = scalar(@channels);
		my $first_channel = "ch1";
		my $other_channel = "ch".($number_of_channels/2 + 1);#handles hi-lo scans
		my $channel_direction = "";
		
		## Loop over each channel to determine direction
		foreach my $channel (@channels) {
		  my @parts = ($channel->{channel_label},$channel->{fluorophor});
		  $parts[1] =~ /(\d+)/;
		  my $number_part = $1;
		  my $match_flag = 0;

		  if ($sample1_dye =~ /$number_part/) {
			$match_flag = 1;
			if ($parts[0] eq $first_channel) {
			  $channel_direction = "f";
			}
			if ($parts[0] eq $other_channel) {
			  $channel_direction = "r";
			}
		  } 
		  if ($sample2_dye =~ /$number_part/) {
			if ($match_flag) { print "\#WARNING[PipelineSetup.cgi]:Double match!\n"; }
			$match_flag = 2;
			if ($parts[0] eq $first_channel) {
			  $channel_direction = "r";
			}
			if ($parts[0] eq $other_channel) {
			  $channel_direction = "f";
			}
		  }
		  unless ($match_flag) {
			print "\#WARNING[PipelineSetup.cgi]:Unable to match file name '$parts[1]' with either dye.\n";
		  }
		} # end foreach $channel (@channels)

		## Each value in the merge hash is a ref to another hash that contains forward and reverse files
		# Samples names that are identical  (e.g. 'C_vs_C') are temporarily altered to add cardinality
		# (e.g 'C_vs_C++++')

		my $array_condition;
		if ($sample1_name eq $sample2_name){
		  $array_condition = "$sample1_name"."_vs_"."$sample2_name\+\+\+\+";
		}else {
		  $array_condition = "$sample1_name"."_vs_"."$sample2_name";
		}
		my @temp = ($rep_file, $channel_direction, $array_condition);
		push @mr_info, \@temp;	
	  }
	}
  }


  ##  Mergereps Commands

  # organize & print out conditions
  my $merge_commands = $parameters{'mergeRecipe'};
  my @vera_sam_conditions;
  my $mergereps_commands="";
  
  while (@mr_info){
	my $first_array_ref = shift @mr_info;
	$mergereps_commands .=  "\#MERGEREPS\n";
	$mergereps_commands .=  "condition_name = $first_array_ref->[2]\n";
	$mergereps_commands .= "file_name = $first_array_ref->[0]\n";
	$mergereps_commands .= "file_direction = $first_array_ref->[1]\n";

	# Cycle through the remaining arrays and see if they have the same condition
    my @temp_mr_info;
	foreach my $t (@mr_info){

	  if ($t->[2] eq $first_array_ref->[2]) {

		$mergereps_commands .= "file_name = $t->[0]\n";
		$mergereps_commands .= "file_direction = $t->[1]\n";

	  }else {

		my $reversed_condition = $t->[2];
		$reversed_condition =~ s/(.*)_vs_(.*)/$2_vs_$1/;
		if ($reversed_condition eq $first_array_ref->[2]) {
		  $mergereps_commands .= "file_name = $t->[0]\n";
		  my $reversed_file_direction = $t->[1];
		  $reversed_file_direction =~ tr/rf/fr/;
		  $mergereps_commands .= "file_direction = $reversed_file_direction\n";
		}else {
		  push @temp_mr_info, $t;
		}

	  }


	}

	@mr_info = @temp_mr_info;
 
	# Mergereps options
	if ($merge_commands =~ /opt:(\d+)\,?/){
	  $mergereps_commands .= "mergereps_optimization_flag = true\n";
	  $mergereps_commands .= "mergereps_optimization_value = $1\n";
	}
	
	if ($merge_commands =~ /exclude:(.*)\,/){
	  $mergereps_commands .= "mergereps_exclude_flag = true\n";
	  $mergereps_commands .= "mergereps_exclude_value = $1\n";
	}
	$mergereps_commands .= "output_file = $first_array_ref->[2]\.merge\n";
	$mergereps_commands .= "EXECUTE = mergeReps\n\n";

	# Earlier, we appended a '++++' to sample2 of conditions that had identical sample names.
	# Here, we remove them.
	$mergereps_commands =~ s/\+{4}//g;
	push @vera_sam_conditions, $first_array_ref->[2];
  }
  print $mergereps_commands;

  ## Print VERA and SAM Commands
  ## Print postSam commands
  my $vs_parameters = $parameters{'vsRecipe'};

  if ($vs_parameters =~ /^useVS/) {
	foreach my $vs_cond (@vera_sam_conditions) {
	  my $vs_commands = "";

	  # Earlier, we appended a '++++' to sample2 of conditions that had identical sample names.
	  # Here, we remove them.
	  $vs_cond =~ s/\+{4}//g;

	  $vs_commands = "\#VERA/SAM\n".
		"file_name = $vs_cond\.all\.merge\n".
		"vera_output_file = $vs_cond\.model\n".
		"sam_output_file = $vs_cond\.sig\n";
	  
	  if ($vs_parameters =~ /crit:(\d*\.?\d*)\,/) {
		$vs_commands .= "vera_critical_delta_flag = true\n".
		  "vera_critical_delat_value= $1\n";
	  }
	  if ($vs_parameters =~ /evol\,/) {
		$vs_commands .= "vera_evolution_flag = true\n".
		  "vera_evolution_value = xxxxx\n";
	  }
	  if ($vs_parameters =~ /debug\,/){
		$vs_commands .= "vera_debugging_file_flag = true\n".
		  "vera_debugging_file_value = xxxxx\n".
		  "sam_debugging_file_flag = true\n".
		  "sam_debugging_file_value = xxxxx\n";
	  }
	  if ($vs_parameters =~ /model:(.*)/){
		$vs_commands .= "vera_initial_choice_flag = true\n".
		  "vera_initial_choice_value= $1\n";
	  }
	  $vs_commands .= "EXECUTE = vera_and_sam\n\n";

	  $vs_commands .= "\#POSTSAM\n".
		"file_name = $vs_cond\.sig\n".
		"key_file = $postSam_key_file\n".
		"output_file = $vs_cond\.clone\n".
		"EXECUTE = postSam\n\n";

	  print $vs_commands;
	}
  }

  ## Print Load Conditions Commands
#  if ($parameters{'dataLoad'} eq 'Yes'){
#	print "#LOAD CONDITIONS\n";
#	print "project = ".$parameters{'outputDirectory'}."\n";
#	foreach my $c (@vera_sam_conditions) {
#	  print "CONDITION = $c\n";
#	}
#	print "EXECUTE = load_conditions\n\n";
#  }


  ## Print which files to keep
  my $trim_commands = "";
  unless ($parameters{'keepDappleFiles'}){
	$trim_commands .= "REMOVE = Dapple\n";
  }	
  unless ($parameters{'keepRepFiles'}){
	$trim_commands .=  "REMOVE = Rep\n";
  }
  unless ($parameters{'keepRepImageFiles'}){
	$trim_commands .=  "REMOVE = RepImage\n";
  }
  unless ($parameters{'keepFTFiles'}){
	$trim_commands .=  "REMOVE = FileTable\n";
  }
  unless ($parameters{'keepMergeFiles'}){
	$trim_commands .=  "REMOVE = Merge\n";
  }
  unless ($parameters{'keepModelFiles'}){
	$trim_commands .=  "REMOVE = Model\n";
  }
  unless ($parameters{'keepSigFiles'}){
	$trim_commands .=  "REMOVE = Sig\n";
  }
  unless ($parameters{'keepCloneFiles'}){
	$trim_commands .=  "REMOVE = Clone\n";
  }
  if($trim_commands) {
	$trim_commands = "\#TRIM DIRECTORY\n".$trim_commands;
	$trim_commands .="EXECUTE = trim_directory\n\n";
  }
  print $trim_commands;

  ## Print Emailer
  my $email_commands = "";
  if ($parameters{'emailNotify'}){
	$email_commands = "\#EMAIL NOTIFY\n";
	$email_commands .= "notify_value = $parameters{'emailAddress'}\n";
	$email_commands .= "EXECUTE = email_notify\n\n";
	print $email_commands;
  }

  print qq~
</TEXTAREA>
</FORM>
~;

}

###############################################################################
# Print Final Screen Javascript
###############################################################################
sub print_final_screen_javascript {
	my $javascript = qq~
<SCRIPT LANGUAGE="Javascript">
function prepareForSubmission () {
	document.finalForm.tab.value = "process";
	document.finalForm.submit();
}

</SCRIPT>		
			~;
	print $javascript;
}



###############################################################################
# Send To Pipeline
###############################################################################
sub send_to_pipeline {
  my %args = @_;
  my $parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$parameters_ref};

  ## Standard Variables
  my $prog_name = "PipelineSetup.cgi";
  my $command_file_content = $parameters{'planFileText'};
  my $project = $parameters{'workingDir'};
  my $pipeline_comments = $parameters{'projectComments'};
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  my $timestr = strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);
  my $proc_subdir = $parameters{'proc_name'} || $timestr;
  
  ## Directories
  my $queue_dir = "/net/arrays/Pipeline/queue";
#	my $queue_dir = "/users/mjohnson/test_site/queue";
  my $output_dir = "/net/arrays/Pipeline/output";
#	my $output_dir = "/users/mjohnson/test_site/output";
  my $arraybot_working_dir = "project_id/$project/$proc_subdir";

  ## Plan/Control File
  my $plan_filename = "job$timestr.testPlan";
  my $control_filename = "job$timestr.control";
  my $log_filename = "job$timestr.log";

  #### Verify that the plan file does not already exist
  if ( -e $plan_filename ) {
	print qq~
	Wow, the job filename '$plan_filename' already exists!<BR>
	Please go back and click PROCESS again.  If this happens twice
	in a row, something is very wrong.  Contact edeutsch.<BR>\n
	~;
	return;
  }

  ## try to eliminate bug-causing namings
  $arraybot_working_dir =~ s/\s/_/g;
  $arraybot_working_dir =~ s/\'/_/g;
  $arraybot_working_dir =~ s/\"/_/g;
  $arraybot_working_dir =~ s/\./_/g;
	
  ## Make Project Directory
  my $project_dir = "$output_dir/project_id/$project";
  if ( -d $project_dir ) {
	print scalar localtime," [$prog_name] Base directory already exists\n<BR>";
  } else {
	unless (mkdir($project_dir, 0666)) {
	  print scalar localtime," [$prog_name] Cannot create project directory $project_dir\n<BR>";
	}
  }


	## Make Working Directory 
	my $working_dir = "$output_dir/project_id/$project/$proc_subdir";
	if ( -d $working_dir ) {
	  print scalar localtime," [$prog_name] working directory exists -- timestamping this one\n<BR>";
	  $working_dir .= $timestr;
	  $arraybot_working_dir .= $timestr;
	}
	else{
	  mkdir($working_dir, 0666);
	}



#	## Write Project Comments
#	print "<BR>Writing project comments to working directory:$proc_subdir</BR>";
#	open (COMMENTSFILE,">$queue_dir/comments$timestr") ||
#			croak ("Unable to write comments $queue_dir/comments$timestr ");
#	print COMMENTSFILE $pipeline_comments;
#	close (COMMENTSFILE);
#	chmod (0666,"$queue_dir/comments$timestr");


	#### Write the plan file
	print "<BR>Writing processing plan file '$plan_filename'<BR>\n";
	open(PLANFILE,">$queue_dir/$plan_filename") ||
      croak("Unable to write to file '$queue_dir/$plan_filename'");
	print PLANFILE $command_file_content;
	close(PLANFILE);
	chmod (0777,"$queue_dir/$plan_filename");

	#### Write the control file
	print "<BR>Writing job control file '$control_filename'<BR>\n";
	open(CONTROLFILE,">$queue_dir/$control_filename") ||
      croak("Unable to write to file '$queue_dir/$control_filename'");
	print CONTROLFILE "submitted_by=$current_username\n";
	print CONTROLFILE "working_dir=$arraybot_working_dir\n";
	print CONTROLFILE "status=SUBMITTED\n";
	close(CONTROLFILE);
	chmod (0777,"$queue_dir/$control_filename");


    print "Done!<BR><BR>\n";

    print qq~
	The plan and job control files have been successfully written to the
	queue.  Your job will be processed in the order received.  You can
	see the log file of your job by clicking on the link below:<BR><BR>

        Well, theres no link yet, but paste this into a unix window:<BR><BR>

	cd $working_dir<BR>
	if ( -e $log_filename ) tail -f $log_filename<BR>

	<BR><BR><BR>
    ~;

}



###########################################################################
# establish_settings
###########################################################################
sub establish_settings{
  $current_username = $sbeams->getCurrent_username;
  $current_contact_id = $sbeams->getCurrent_contact_id;
  $current_work_group_id = $sbeams->getCurrent_work_group_id;
  $current_work_group_name = $sbeams->getCurrent_work_group_name;
  $current_project_id = $sbeams->getCurrent_project_id;
  $current_project_name = $sbeams->getCurrent_project_name;
  $dbh = $sbeams->getDBHandle();
  return;
}










