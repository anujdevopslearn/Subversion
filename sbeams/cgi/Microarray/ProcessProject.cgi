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

    #### Print the header, do what the program does, and print footer
    $sbeamsMA->printPageHeader();
    processRequests();
    $sbeamsMA->printPageFooter();


} # end main


###############################################################################
# Process Requests
#
# Test for specific form variables and process the request 
# based on what the user wants to do. 
###############################################################################
sub processRequests {
    $current_username = $sbeams->getCurrent_username;
    $current_contact_id = $sbeams->getCurrent_contact_id;
    $current_work_group_id = $sbeams->getCurrent_work_group_id;
    $current_work_group_name = $sbeams->getCurrent_work_group_name;
    $current_project_id = $sbeams->getCurrent_project_id;
    $current_project_name = $sbeams->getCurrent_project_name;
    $dbh = $sbeams->getDBHandle();


    # Enable for debugging
    if (0==1) {
      print "Content-type: text/html\n\n";
      my ($ee,$ff);
      foreach $ee (keys %ENV) {
        print "$ee =$ENV{$ee}=<BR>\n";
      }
      foreach $ee ( $q->param ) {
        $ff = $q->param($ee);
        print "$ee =$ff=<BR>\n";
      }
    }


    #### Decide where to go based on form values
    if   ($q->param('PROCESS'))  {createFile();}
    elsif($q->param('FINALIZE')) {submitJob();}
    else { printEntryForm();}


} # end processRequests



###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

    my %parameters;
    my $element;
    my $sql_query;
    my (%url_cols,%hidden_cols);

    my $CATEGORY="Welcome to the Test Pipeline Tool!";
    my $SECONDARY_MESSAGE="Please send commments/bugs/etc. to <A HREF=\"mailto:mjohnson\@systemsbiology.org\">mjohnson</A>";

    my $apply_action  = $q->param('apply_action');
    my $update_action = $q->param('UPDATE_CART');#mj
    $parameters{project_id} = $q->param('project_id');


    # If we're coming to this page for the first time, and there is a
    # default project set, then automatically select that one and GO!
    if ( ($parameters{project_id} eq "") && ($current_project_id > 0) ) {
      $parameters{project_id} = $current_project_id;
      $apply_action = "QUERY";
    }


    $sbeams->printUserContext();
    print qq!
        <H2>$CATEGORY</H2>
	<BR>$SECONDARY_MESSAGE<BR>
        $LINESEPARATOR
        <FORM METHOD="post">
        <TABLE>
    !;


    # ---------------------------
    # Query to obtain column information about the table being managed
    $sql_query = qq~
	SELECT project_id,username+' - '+name
	  FROM $TB_PROJECT P
	  LEFT JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id=UL.contact_id )
	 ORDER BY username,name
    ~;
    my $optionlist = $sbeams->buildOptionList(
           $sql_query,$parameters{project_id});


    print qq!
          <TR><TD><B>Project:</B></TD>
          <TD><SELECT NAME="project_id">
          <OPTION VALUE=""></OPTION>
	   $optionlist</SELECT></TD>
          <TD BGCOLOR="E0E0E0">Select the Project Name</TD>
          </TD></TR>
    !;


    # ---------------------------
    # Show the QUERY, REFRESH, and Reset buttons
   print qq!
	<TR><TD COLSPAN=2>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="QUERY">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="reset"  VALUE="Reset">
         </TR></TABLE>
         </FORM>
    !;


    $sbeams->printPageFooter("CloseTables");
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";

    # --------------------------------------------------
    if ($parameters{project_id} > 0) {
      $sql_query = qq~
SELECT	A.array_id,A.array_name,
	ARSM1.name AS 'Sample1Name',D1.dye_name AS 'sample1_dye',
	ARSM2.name AS 'Sample2Name',D2.dye_name AS 'sample2_dye',
	AQ.array_quantitation_id,AQ.data_flag AS 'quan_flag',
	AQ.stage_location,AL.source_filename AS 'key_file'
  FROM array_request AR
  LEFT JOIN array_request_slide ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN array_request_sample ARSM1 ON ( ARSL.array_request_slide_id = ARSM1.array_request_slide_id AND ARSM1.sample_index=0)
  LEFT JOIN labeling_method LM1 ON ( ARSM1.labeling_method_id = LM1.labeling_method_id )
  LEFT JOIN arrays.dbo.dye D1 ON ( LM1.dye_id = D1.dye_id )
  LEFT JOIN array_request_sample ARSM2 ON ( ARSL.array_request_slide_id = ARSM2.array_request_slide_id AND ARSM2.sample_index=1)
  LEFT JOIN labeling_method LM2 ON ( ARSM2.labeling_method_id = LM2.labeling_method_id )
  LEFT JOIN arrays.dbo.dye D2 ON ( LM2.dye_id = D2.dye_id )
  LEFT JOIN array A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN array_layout AL ON ( A.layout_id = AL.layout_id )
  LEFT JOIN array_scan ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN array_quantitation AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
 WHERE AR.project_id=$parameters{project_id}
   AND AQ.array_quantitation_id IS NOT NULL
   AND AR.record_status != 'D'
   AND A.record_status != 'D'
   AND ASCAN.record_status != 'D'
   AND AQ.record_status != 'D'
   AND AQ.data_flag != 'BAD'
 ORDER BY A.array_name
     ~;

      my $base_url = "$CGI_BASE_DIR/ManageTable.cgi?TABLE_NAME=";
      %url_cols = ('array_name' => "${base_url}array&array_id=%0V",
                   'quan_flag' => "${base_url}array_quantitation&array_quantitation_id=%6V", 
      );

      %hidden_cols = ('array_id' => 1,
                      'array_quantitation_id' => 1,
      );


    } else {
      $apply_action="BAD SELECTION";
    }


    if ($apply_action eq "QUERY") {
      $sbeams->displayQueryResult(sql_query=>$sql_query,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols);



      my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
      my $rv  = $sth->execute or croak $dbh->errstr;

      my @rows;
      my @row;
      while (@row = $sth->fetchrow_array) {
        my @temprow = @row;
        push(@rows,\@temprow);
      }

      $sth->finish;
      print qq~
        <FORM METHOD="post">
      ~;


      my @group_names;
      my %group_names_hash;
      my @slide_group_names;
      my @slide_rowrefs;
      my @slide_directions;


      foreach $element (@rows) {
        my $sample1name = $$element[2];
        my $sample2name = $$element[4];
        my $forcondition = "${sample1name}_vs_${sample2name}";
        my $revcondition = "${sample2name}_vs_${sample1name}";
        my $thiscondition;
        my $direction = "";

        if (defined($group_names_hash{$forcondition})) {
          $direction = "f";
          $thiscondition = $forcondition;
        }

        if (defined($group_names_hash{$revcondition})) {
          $direction = "r";
          $thiscondition = $revcondition;
        }

        unless ($direction) {
          $direction = "f";
          $thiscondition = $forcondition;
          push(@group_names,$thiscondition);
          $group_names_hash{$thiscondition}=$thiscondition;
        }

        push(@slide_group_names,$thiscondition);
        push(@slide_rowrefs,$element);
        push(@slide_directions,$direction);
      }


      my $group;
      my $error_flag = 0;
      my ($quantitation_file,$qf_status);
      my (@ERRORS,@command_file);
      my (@results,@parts);
      my @project_outline;#mj

      foreach $group (@group_names) {
	
        my $row_counter=0;
        my $first_flag=1;
        my $channel_direction = "";
        foreach $element (@slide_group_names) {

          if ($element eq $group) {
	
            if ($first_flag) {
              my $cmd_line = "$group ${$slide_rowrefs[$row_counter]}[9] EXP";
              push (@command_file,$cmd_line);
              $first_flag=0;
            }

            #### Verify that the data file is okay
            $quantitation_file = ${slide_rowrefs[$row_counter]}[8];

            my $sample1_dye = ${slide_rowrefs[$row_counter]}[3];
            my $sample2_dye = ${slide_rowrefs[$row_counter]}[5];
            $qf_status = "";

            #### If the data file is okay
            if ( -e $quantitation_file ) {

              $qf_status = "&nbsp;&nbsp;&nbsp;&nbsp;--- ".
                           "<FONT COLOR=green>File exists</FONT>";
              #### Run a parse program on it to see which channel is which dye
              #@results = `../lib/perl/SBEAMS/scripts/parseQAheader.pl --verify "$quantitation_file"`;
              my %quantitation_data = readQuantitationFile(inputfilename=>"$quantitation_file",
                headeronly=>1);

              unless ($quantitation_data{success}) {
                $qf_status = "&nbsp;&nbsp;&nbsp;&nbsp;--- ".
                             "<FONT COLOR=red>$quantitation_data{error_msg}</FONT>";
              } else {
#                print "According to sample names, direction should ".
#                      "be $slide_directions[$row_counter]<BR>\n";
                #### Pull out the channel information
                my @channels = @{$quantitation_data{channels}};
                my $channel;

                #### Loop over each channel
                foreach $channel (@channels) {
                  @parts = ($channel->{channel_label},$channel->{fluorophor});
                  #print "$parts[0] = $parts[1]<BR>\n";
                  $parts[1] =~ /(\d+)/;
                  my $number_part = $1;
                  my $match_flag = 0;


                  if ($sample1_dye =~ /$number_part/) {
                    $match_flag = 1;
                    if ($parts[0] eq "ch1") {
                      $channel_direction = "f";
                    }
                    if ($parts[0] eq "ch2") {
                      $channel_direction = "r";
                    }
                  }

                  if ($sample2_dye =~ /$number_part/) {
                    if ($match_flag) { print "Whoah!  Double match!<BR>\n"; }
                    $match_flag = 2;
                    if ($parts[0] eq "ch1") {
                      $channel_direction = "r";
                    }
                    if ($parts[0] eq "ch2") {
                      $channel_direction = "f";
                    }
                  }
                  unless ($match_flag) {
                    print "Unable to match file name '$parts[1]' with ".
                        "either dye.<BR>\n";
                  }
                } # endforeach

                if ($channel_direction eq "r") {
                  $slide_directions[$row_counter] =~ tr/fr/rf/;
                } else {
                  #keep direction the same
                }


                $qf_status = "&nbsp;&nbsp;&nbsp;&nbsp;--- ".
                             "<FONT COLOR=green>File verified</FONT>";

              } # endelse


            #### If the data file is not found
            } else {
              $error_flag++;
              $qf_status = "&nbsp;&nbsp;&nbsp;&nbsp;--- ".
                           "<FONT COLOR=red>FILE MISSING</FONT>";
              push(@ERRORS,"Unable to find file $quantitation_file");

            }

            #### Print out the quantitation file row
            my $cmd_line = "$quantitation_file ".
                  $slide_directions[$row_counter];
            push (@command_file,$cmd_line);

            print "$quantitation_file ".
                  "<FONT COLOR=red>$slide_directions[$row_counter]</FONT> ".
                  "$qf_status<BR>\n";

          }

          $row_counter++;
        }

      }
      print qq~
	</FORM><BR>
      ~;


#######################################
 ###  Start Pipeline Customization   ###
  #######################################
print qq~

<SCRIPT LANGUAGE="Javascript">
<!--



//Opens a new browser window for documentation on pipieline components
function getDirections(URL){
  var newWindow;
  newWindow = window.open(URL);
}

//makes sure only one checkbox is checked at a time
//function switchBool(source){
//  if (source=="base"){
//    if(pipelineConfig.preprocessBase == true){pipelineConfig.preprocessBase=false;}
//    else{pipelineConfig.preprocessBase=true;}
//  }
//  else if (source=="sat"){
//    if(pipelineConfig.preprocessSat == true){pipelineConfig.preprocessSat=false;}
//    else{pipelineConfig.preprocessSat=true;}
//  }
//  else if(source=="opt"){
//    if(pipelineConfig.veraOptimization==true){pipelineConfig.veraOptimization=false;}
//    else{pipelineConfig.veraOptimization=true;}
//  }
//  else {alert("something is wrong-contact mjohnson");}
//}//end switchBool


//function setNorm(source){
//  if(source=="median")   {pipelineConfig.preprocessNormalize = "median";}
//  else if(source=='mean'){pipelineConfig.preprocessNormalize = "mean";}
//  else if(source=='none'){pipelineConfig.preprocessNormalize = "none";}
//  else{alert("something is wrong-contact mjohnson");}
//}//end setNorm


function addItem(dir){
  var bufferList = document.choiceList.fileList;
  var destinationList;
  if (dir == "forward"){destinationList = document.choiceList.forwardSelectionList;}
  if (dir == "reverse"){destinationList = document.choiceList.reverseSelectionList;}
  for(var i=bufferList.length;i>=0;i--){
    if((bufferList.options[i]!=null) && (bufferList.options[i].selected)){
      //check mergeCondsList and add condition to list if not present
	var re = /\.key:(.*_vs_.*):/;
      var cond = re.exec(bufferList.options[i].value);
      var alreadyExists = false;
      for (var j=0; j<document.choiceList.forwardSelectionList.length; j++){
	var test = re.exec(document.choiceList.forwardSelectionList.options[j].value);
	if (cond[1] == test[1]){
	  alreadyExists = true;
	  break;
	}
      }
      //Superfluous error checking- ensure files does not exist in currently used files
	for(var k=0; k<document.choiceList.reverseSelectionList.length; k++){
	  var test = re.exec(document.choiceList.reverseSelectionList.options[k].value);
	  if (cond[1] == test[1]){
	    alreadyExists = true;
	    break;
	  }
	}
      if (!alreadyExists){
	var mergeList = document.choiceList.mergeCondsList;
	mergeList.options[mergeList.length] = new Option(cond[1], cond[1]);
      }
      destinationList.options[destinationList.length] = new Option(bufferList.options[i].text,
								   bufferList.options[i].value);
      bufferList.options[i] = null;
    }
  }
}

//for use in removing items from file lists, ensure only forward or reverse files are selected
function adjust(direction){
  var otherSelectionList;
  if (direction == "forward"){otherSelectionList = document.choiceList.reverseSelectionList;}
  else                       {otherSelectionList = document.choiceList.forwardSelectionList;}
  for(var i=0;i<otherSelectionList.length;i++){
    otherSelectionList.options[i].selected=false;
  }
}//end adjust
	
function dealWithMergeConds(list){
  //remove from mergeCondsList
  //1. see if others within the group exist
  //2. if not, remove group name

  var mergeCondsList  = document.choiceList.mergeCondsList;
  var unusedMergeConds= document.choiceList.mergeBufferList;
  var group = list.value;
  var re = /\.key:(.*_vs_.*):/;
  var cond = re.exec(group);
  var forwardFiles = document.choiceList.forwardSelectionList;
  var reverseFiles = document.choiceList.reverseSelectionList;

  //see if condition exists in currently selected files
  var groupStillExists = checkExists(forwardFiles, cond[1]);
  if (!groupStillExists){
    groupStillExists = checkExists(reverseFiles, cond[1]);
  }

  //we now know if the condition still exists or not
  if (!groupStillExists){
    //remove condition from list of possible mergeConds
    for (var x=(mergeCondsList.length-1);x>=0;x--){
      if (cond[1] == mergeCondsList.options[x].value){
	mergeCondsList.options[x] = null;
      }
    }
    //also check buffer list in mergeConds section
    for (var y=(unusedMergeConds.length-1);y>=0;y--){
      if (cond[1] == unusedMergeConds.options[y].value){
	unusedMergeConds.options[y] = null;
      }
    }
  }

}

function checkExists(checkList, checkAgainst){
  var groupStillExists = false;
  var re = /\.key:(.*_vs_.*):/;
  for (var a=(checkList.length-1);a>=0;a--){
    var test = re.exec(checkList.options[a].value);
    if (checkAgainst == test[1] && checkList.options[a].selected == false){
      groupStillExists = true;
      break;
    }
  }
  return groupStillExists;
}


function removeItem() {
  var bufferList             = document.choiceList.fileList;
  var bufferListLength       = bufferList.length;
  var list;
  var listLength;

  list       = document.choiceList.forwardSelectionList;
  listLength = list.length;
  for (var h = 1; h<=2; h++){
    for(var i=(listLength-1);i>=0;i--){
      if((list.options[i]!=null)&&(list.options[i].selected==true)){
	dealWithMergeConds(list.options[i]);
	var uniqueCheck = true;
	for(var j=(bufferListLength-1);j>=0;j--){
	  if (list.options[i].value == bufferList.options[j].value){
	    uniqueCheck = false;
	    break;
	  }
	}
	if (uniqueCheck == true){
	  bufferList.options[bufferListLength] = new Option(list.options[i].text,
							    list.options[i].value);
	  bufferListLength++;
	}
	list.options[i] =null;
      }
    }
    list       = document.choiceList.reverseSelectionList;
    listLength = list.length;
  }
}//end removeItem

function checkSwitch(location){
  var primary;
  var secondary;
  if (location == 'general'){
    primary   = document.choiceList.excludeGenes;
    secondary = document.choiceList.excludeLocalGenes;
  }
  if (location == 'local'  ){
    primary   = document.choiceList.excludeLocalGenes;
    secondary = document.choiceList.excludeGenes;
  }
  if (primary.checked){secondary.checked = false;}
}//end checkSwitch

function verifyNumber(testValue,testLocation){
  var location;
  if(testLocation=="preprocessBaseValue"){location=document.choiceList.preprocessBaseValue;}
  if(testLocation=="preprocessSatValue") {location=document.choiceList.preprocessSatValue;}
  if(testLocation=="preprocessScaleValue"){location=document.choiceList.preprocessScaleValue;}
  if(testLocation=="veraCritValue")      {location=document.choiceList.veraCritValue;}
  if(testLocation=="lambdaValue")        {location=document.choiceList.lambdaValue;}
  if(testLocation=="ratioValue")         {location=document.choiceList.ratioValue;}
  if(testLocation=="stdevValue")         {location=document.choiceList.stdevValue;}
  if(testLocation=="errorModel")         {location=document.choiceList.errorModel;}
  if(testLocation=="repValue")           {location=document.choiceList.repValue;}

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

function moveUp(){
  var mergeList = document.choiceList.mergeCondsList;

  for(var i=0; i<mergeList.options.length; i++){
    if(mergeList.options[i].selected &&
       mergeList.options[i] != "" &&
       mergeList.options[i] != mergeList.options[0]){
      var tmpOptionValue = mergeList.options[i].value;
      var tmpOptionText  = mergeList.options[i].text;
      mergeList.options[i].value   = mergeList.options[i-1].value;
      mergeList.options[i].text    = mergeList.options[i-1].text;
      mergeList.options[i-1].value = tmpOptionValue;
      mergeList.options[i-1].text  = tmpOptionText;
      mergeList.options[i-1].selected = true;
      mergeList.options[i].selected = false;
    }
  }
}

function moveDown(){
  var mergeList = document.choiceList.mergeCondsList;

  for (var i=mergeList.options.length-1; i>=0; i--){
    if(mergeList.options[i].selected &&
       mergeList.options[i] != "" &&
       mergeList.options[i+1] != mergeList.options[mergeList.options.length]){
      var tmpOptionValue = mergeList.options[i+1].value;
      var tmpOptionText  = mergeList.options[i+1].text;
      mergeList.options[i+1].value = mergeList.options[i].value;
      mergeList.options[i+1].text  = mergeList.options[i].text;
      mergeList.options[i].value = tmpOptionValue;
      mergeList.options[i].text  = tmpOptionText;
      mergeList.options[i+1].selected = true;
      mergeList.options[i].selected = false;
    }
  }
}

function testForText(){
  var filename = document.choiceList.excludeFile;
  if(filename.value == ""){
    document.choiceList.excludeGenes.checked = true;
    document.choiceList.excludeLocalGenes.checked = false;
  }
  else{
    document.choiceList.excludeLocalGenes.checked = true;
    document.choiceList.excludeGenes.checked = false;
  }
}

function addMerge(){
  var bufferList = document.choiceList.mergeBufferList;
  var mergeList  = document.choiceList.mergeCondsList;
  for (var i=bufferList.length-1;i>=0;i--){
    if (bufferList.options[i].selected){
      mergeList.options[mergeList.length] = new Option(bufferList.options[i].text,
						       bufferList.options[i].value);
      bufferList.options[i] = null;
    }
  }
}

function omitMerge(){
  var bufferList = document.choiceList.mergeBufferList;
  var mergeList  = document.choiceList.mergeCondsList;
  for (var i=mergeList.length-1; i>=0; i--){
    if (mergeList.options[i].selected){
      bufferList.options[bufferList.length] = new Option (mergeList.options[i].text,
							  mergeList.options[i].value);
      mergeList.options[i] = null;
    }
  }
}

function prepareForSubmission(){
  var forwardList = document.choiceList.forwardSelectionList;
  for (var i=0;i<forwardList.length;i++){
    forwardList.options[i].selected = true;
  }

  var reverseList = document.choiceList.reverseSelectionList;
  for (var i=0;i<reverseList.length;i++){
    reverseList.options[i].selected=true;
  }

  var mergeList = document.choiceList.mergeCondsList;
  for (var i=0;i<mergeList.length;i++){
    mergeList.options[i].selected= true;
  }

  if (document.choiceList.preprocessBase.checked == true && document.choiceList.preprocessBaseValue.value=="")
    if(!confirm("no base value set for Preprocess.  Click OK if you're not using a base value.  Click Cancel to provide a value."))
      {return false;}
    else
      {document.choiceList.preprocessBase.checked = false;}

  if (document.choiceList.preprocessBase.checked==false && document.choiceList.preprocessBaseValue.value !=""){
    if(confirm("Preprocess base value set, but checkbox not checked.  Click OK to use the base value.  Click Cancel to refrain from using it."))
      {document.choiceList.preprocessBase.checked = true;}
    else
      {document.choiceList.preprocessBaseValue.value ="";}
  }


  if (document.choiceList.preprocessSat.checked == true && document.choiceList.preprocessSatValue.value=="")
    if(!confirm("no saturation value set for Preprocess.  Click OK if you're not using a saturation value.  Click Cancel to provide a value."))
      {return false;}
    else
      {document.choiceList.preprocessSat.checked = false;}

  if (document.choiceList.preprocessSat.checked==false && document.choiceList.preprocessSatValue.value !=""){
    if(confirm("Saturation value set, but checkbox not checked.  Click OK to use the value.  Click Cancel to refrain from using it."))
      {document.choiceList.preprocessSat.checked = true;}
    else
      {document.choiceList.preprocessSatValue.value ="";}
  }



  if (document.choiceList.preprocessScale.checked == true && document.choiceList.preprocessScaleValue.value=="")
    if(!confirm("no value set for Preprocess' scale.  Click OK if you're not using a value.  Click Cancel to provide a value."))
      {return false;}
    else
      {document.choiceList.preprocessScale.checked = false;}

  if (document.choiceList.preprocessScale.checked == false && document.choiceList.preprocessScaleValue.value !=""){
    if(confirm("You have entered a scale value for preprocess, but you haven't checked the box.  Click OK to use the value.  Click Cancel to refrain from using it."))
      {document.choiceList.preprocessScale.checked = true;}
    else
      {document.choiceList.preprocessScaleValue.value = "";}
  }



  if (document.choiceList.errorModel.checked == true && document.choiceList.errorModelValue.value=="")
    if(!confirm("no value set for MergeReps optimization.  Click OK if you're not using a value.  Click Cancel to provide a value."))
      {return false;}
    else
      {document.choiceList.errorModel.checked = false;}

  if (document.choiceList.errorModel.checked == false && document.choiceList.errorModelValue.value != ""){
    if (confirm("You have entered a min. number of replicates for mergereps, but you haven't check the box.  Click OK to use the value.  Click Cancel to refrain from using it."))
      {document.choiceList.errorModel.checked = true;}
    else
      {docuemnt.choiceList.errorModelValue.value = "";}
  }


  if (document.choiceList.veraCrit.checked == true && document.choiceList.veraCritValue.value=="")
    if(!confirm("no value set for VERA's delta value for optimization.  Click OK if you're not using a value.  Click Cancel to provide a value."))
      {return false;}
    else
      {document.choiceList.veraCrit.checked = false;}

  if (document.choiceList.veraCrit.checked == false && document.choiceList.veraCritValue.value != ""){
    if (confirm("You have entered a delta value at which VERA stops , but you haven't check the box.  Click OK to use the value.  Click Cancel to refrain from using it."))
      {document.choiceList.veraCrit.checked = true;}
    else
      {docuemnt.choiceList.veraCritValue.value = "";}
  }
}
//-->
</SCRIPT>
~;
##########################################################
##########################################################


print qq~
$LINESEPARATOR<BR>
<FONT COLOR="red"><B>Step 1 of 3: Choose Files</B></FONT>
  <FORM METHOD="post"NAME="choiceList" onSubmit="return prepareForSubmission()">
    <TABLE BORDER=0>
    <TR>
      <TD VALIGN="top">
    Forward Files:<BR>
    <SELECT NAME="forwardSelectionList" SIZE=4 MULTIPLE onChange="adjust('forward')">
~;

      my $testfilename;
      my $mapfilename;
      my $shortname;
      my $testkeyfilename;
      my $name;
      my $tempVal;
      my $direction;
      for( my $i=0;$i<=$#rows;$i++ ){
	$direction = $slide_directions[$i];
	if ($direction eq "f"){
	  $testfilename  = ${$rows[$i]}[8];
	  $mapfilename   = ${$rows[$i]}[9];
	  $shortname   =  $testfilename;
	  $shortname   =~ (s/^.*\///);
          $name = $slide_group_names[$i];
          chomp $direction;
	  $tempVal = "$testfilename".":$mapfilename".":$slide_group_names[$i]".":$direction";
	print qq~
	  <OPTION value="$tempVal">$shortname ($name)
          ~;
        }
      }

print qq~
</SELECT>
<BR>
Reverse Files:<BR>
<SELECT NAME="reverseSelectionList" SIZE=4 MULTIPLE onChange="adjust('reverse')">
~;
      for( my $i=0;$i<=$#rows;$i++ ){
	$direction = $slide_directions[$i];
	if ($direction eq "r"){
	  $testfilename  = ${$rows[$i]}[8];
	  $mapfilename   = ${$rows[$i]}[9];
	  $shortname   =  $testfilename;
	  $shortname   =~ (s/^.*\///);
          $name = $slide_group_names[$i];
	  chomp $direction;
	  $tempVal = "$testfilename".":$mapfilename".":$slide_group_names[$i]".":$direction";
          print qq~
	  <OPTION value="$tempVal">$shortname ($name)
          ~;
        }
      }
print qq~
</SELECT>
  </TD>

  <TD VALIGN="top">
  <CENTER>
  <BR><BR>
    <INPUT NAME="forwardButton" TYPE="button" VALUE="<--Add to Forward" onClick="addItem('forward')">
    <BR><BR>
    <INPUT NAME="removeButton"  TYPE="button" VALUE="Remove-->" onClick="removeItem()">
    <BR><BR>
    <INPUT NAME="reverseButton" TYPE="button" VALUE="<--Add to Reverse" onClick="addItem('reverse')">
  <BR><BR>
~;
print qq~
  </CENTER>
  </TD>

  <TD VALIGN="top">
  Available Files:
  <BR>
  <SELECT name="fileList" SIZE=10 MULTIPLE></SELECT>
   </TD>
   </TR>
   </TABLE>

$LINESEPARATOR<BR>
<FONT COLOR="red"><B>Step 2 of 3: Optional Pipeline Configurations</B><BR>
                     -Default values used if not selected<BR>
                     -Click on Pipeline Component title for documentation</FONT>
     <BR>
     <B><A HREF="Javascript:getDirections('http://www.systemsbiology.org/ArrayProcess/readme/preProcess.html')">PreProcess:</A></B>
     <TABLE>
     <TR>
      <TD VALIGN="top">
	  <INPUT TYPE="checkbox" NAME="preprocessBase" VALUE="-base">Use Base Value:<BR>
	  <INPUT TYPE="checkbox" NAME="preprocessSat" VALUE="-sat" CHECKED>Saturating Intensity:<BR>
          <INPUT TYPE="checkbox" NAME="preprocessScale" VALUE="-scale">Scale to Value:<BR>
      </TD>
      <TD>
          <INPUT TYPE="text" NAME="preprocessBaseValue" onChange="verifyNumber(this.value,'preprocessBaseValue')"><BR>
          <INPUT TYPE="text" NAME="preprocessSatValue" onChange="verifyNumber(this.value,'preprocessSatValue')" VALUE="65535"><BR>
          <INPUT TYPE="text" NAME="preprocessScaleValue"onChange="verifyNumber(this.value,'preprocessScaleValue')"><BR>
      </TD>
     </TR>
<BR>
     <TR>
      <TD VALIGN="top">
	  Normalizing Method:<BR>
	  <INPUT TYPE="radio" NAME="normalization" VALUE="median" CHECKED>Median
          <INPUT TYPE="radio" NAME="normalization" VALUE="none"  >None
      </TD>
     </TR>
     <TD>
       <INPUT TYPE="checkbox" NAME="preprocessDebug" VALUE="-debug">Generate debug file<BR>
     </TD>
     </TABLE>
     <BR>
     <B><A HREF="Javascript:getDirections('http://www.systemsbiology.org/ArrayProcess/readme/mergeReps.html')">MergeReps:</A></B>
     <BR>
       <INPUT TYPE="checkbox" NAME="errorModel" VALUE="-opt">Only return those genes that are represented by at least &lt;num&gt; replicate measurements
       <INPUT TYPE="text"     NAME="errorModelValue" onChange="verifyNumber(this.value,'errorModel')"><BR>
       <INPUT TYPE="checkbox" NAME="excludeGenes" VALUE="-exclude" onClick="checkSwitch('general')" CHECKED>Use general list of bad genes<BR>
       <INPUT TYPE="checkbox" NAME="excludeLocalGenes" VALUE="-exclude" onClick="checkSwitch('local')">Select local file of bad genes
       <INPUT TYPE = "text" NAME = "excludeFile"  SIZE=30>*must specify full path of bad gene file<BR>
       <INPUT TYPE="checkbox" NAME="filterGenes"  VALUE="-filter" CHECKED> Filter Outliers<BR>
     <BR>
     <B><A HREF="Javascript:getDirections(http://www.systemsbiology.org/VERAandSAM)">VERA/SAM:</A></B><BR>
        <INPUT TYPE="checkbox" NAME="useVERAandSAM"  VALUE="useVS" CHECKED><FONT COLOR="red">Use VERA and SAM</FONT><BR>
        <INPUT TYPE="checkbox" NAME="veraCrit" VALUE="critValue">Cease Optimization when changes per step are less than:
	<INPUT TYPE="text" NAME="veraCritValue" onChange="verifyNumber(this.value,'veraCritValue')">
     <BR>
        <INPUT TYPE="checkbox" NAME="veraEvolFlag" VALUE="-evol">Generate file showing how parameters converge<BR>
        <INPUT TYPE="checkbox" NAME="debugFlag" VALUE="-debug">Generate debug file<BR>
        <INPUT TYPE="checkbox" NAME="modelFlag" VALUE="-model">Use your own error model
        <INPUT TYPE="file"     NAME="modelFile" size=30<BR>
      <BR>
     <B><A HREF="Javascript:getDirections('http://www.systemsbiology.org/ArrayProcess/readme/mergeConds.html')">MergeConds:</A></B><BR>
       <FONT COLOR="red">-only used with more than one condition</FONT><BR>
       <TABLE>
       <TR>
       <TD VALIGN = "top">
        Conditions:<BR>
       <SELECT NAME= "mergeCondsList" SIZE=10 MULTIPLE>
      ~;

my %unique_group;
my $test_item;
my @unique_groups;
foreach $test_item(@slide_group_names){
  push (@unique_groups, $test_item) unless $unique_group{$test_item}++;
}
for (my $i=0;$i<=$#unique_groups;$i++){
  print qq~
    <OPTION VALUE="$unique_groups[$i]">$unique_groups[$i]
  ~;
}

print qq~
     </SELECT>
     </TD>
     <TD>
     Unused Conditions:<BR>
     <SELECT NAME = "mergeBufferList" SIZE=10 MULTIPLE></SELECT>
     <BR>
     </TD>
     </TR>
     <TR>
     <TD>
     <INPUT TYPE = "button" NAME = "upButton" VALUE ="Move Up " OnClick="moveUp()">
     <INPUT TYPE = "button" NAME = "downButton" VALUE ="Move Down" OnClick= "moveDown()">
     </TD>
     </TR>
     <TR>
     <TD>
     <INPUT TYPE = "button" NAME = "omitFile" VALUE =" Remove " OnClick="omitMerge()">
     <INPUT TYPE = "button" NAME = "addFILE"  VALUE ="      Add      "    OnClick="addMerge()">
     <BR>
     </TD>
     </TR>
     </TABLE>
     <TABLE>
     <TR>
      <TD>
       <INPUT TYPE = "checkbox" NAME = "lambdaFlag" VALUE = "-lam">Lambda &#62;&#61; &#60;num&#62; <BR>
       <INPUT TYPE = "checkbox" NAME = "ratioFlag"  VALUE = "-rat">Ratio  &#62;&#61; &#60;num&#62;<BR>
       <INPUT TYPE = "checkbox" NAME = "stdevFlag"  VALUE = "-std">Standard Devation &#62;&#61;  &#60;num&#62;<BR> 
       <INPUT TYPE = "checkbox" NAME = "repFlag"    VALUE = "-n">Gene represented at least &lt;num&gt; times
      </TD>
      <TD>
       <INPUT TYPE = "text" NAME = "lambdaValue" onChange="verifyNumber(this.value,'lambdaValue')"><BR>
       <INPUT TYPE = "text" NAME = "ratioValue"  onChange="verifyNumber(this.value,'ratioValue')"><BR>
       <INPUT TYPE = "text" NAME = "stdevValue"  onChange="verifyNumber(this.value,'stdevValue')"><BR>
       <INPUT TYPE = "text" NAME = "repValue"    onChange="verifyNumber(this.value,'repValue')"><BR>
      </TD>
     </TR>
     </TABLE>
     <B><FONT COLOR="green">Miscellaneous</FONT></B><BR>
      <INPUT TYPE="checkbox" NAME="postSam" VALUE = "ps">Use postSam (adds info from key file to .sig file)<BR>
      <INPUT TYPE="checkbox" NAME="notify">email notification<BR>
      -Type comma-separated email addresses (\@systemsbiology is implied, unless otherwise specified)<BR> 
     <INPUT TYPE="text" NAME="addresses" SIZE="50"><BR>
     $LINESEPARATOR<BR>
     <FONT COLOR="red"><B>Step 3 of 3: Proceed to Final Stage!</B></FONT><BR>
     <INPUT TYPE="hidden" NAME="project_id" VALUE = "$parameters{project_id}">
     <INPUT TYPE="submit" NAME="PROCESS" VALUE="Proceed to Verification and Submission Page"><BR>
    </FORM>
     ~;
      } else {
	print "<H4>Select parameters above and press QUERY\n";
      }
} # end printEntryForm

  ####################################
 ### End Pipeline Customization   ###
####################################
sub createFile{
  my @forward_files = $q->param('forwardSelectionList');
  my @reverse_files = $q->param('reverseSelectionList');

#Preprocess values:
  my $base          = $q->param('preprocessBase');
  my $baseValue     = $q->param('preprocessBaseValue');
  my $sat           = $q->param('preprocessSat');
  my $satValue      = $q->param('preprocessSatValue');
  my $scale         = $q->param('preprocessScale');
  my $scaleValue    = $q->param('preprocessScaleValue');
  my $norm          = $q->param('normalization');
  my $preprocDebug  = $q->param('preprocessDebug');

#MergeReps values:

  my $replicate     = $q->param('errorModel');
  my $replicateValue= $q->param('errorModelValue');
  my $exclude = 0;
  my $excludeFile;
  my $defaultFile = "/net/arrays/Pipeline/dev7/tools/etc/excluded_gene_names";
  my $temp = $q->param('excludeGenes');
  if ($temp){
    $exclude = $temp;
    $excludeFile = $defaultFile;
  }
  else{
    $temp = $q->param('excludeLocalGenes');
    if ($temp){
      $exclude = $temp;
      $excludeFile = $q->param('excludeFile');
    }
  }
  my $filter = $q->param('filterGenes');

#VERA values:
  my $useVandS     = $q->param('useVERAandSAM');
  my $veraFlag     = $q->param('veraCrit');
  my $veraValue    = $q->param('veraCritValue');
  my $veraEvolFile = $q->param('veraEvolFlag');
  my $veraDebug    = $q->param('debugFlag');
  my $veraModelFlag= $q->param('modelFlag');
  my $veraModelFile= $q->param('modelFile');

#mergeConds values
  my @merge_files  = $q->param('mergeCondsList');
  my $lambdaFlag   = $q->param('lambdaFlag');
  my $lambdaValue  = $q->param('lambdaValue');
  my $ratioFlag    = $q->param('ratioFlag');
  my $ratioValue   = $q->param('ratioValue');
  my $stdevFlag    = $q->param('stdevFlag');
  my $stdevValue   = $q->param('stdevValue');
  my $repFlag      = $q->param('repFlag');
  my $repValue     = $q->param('repValue');

#Miscellaneous values
  my $postSam      = $q->param('postSam');
  my $notify       = $q->param('notify');
  my $addresses    = $q->param('addresses');

#File Creating Variables
  my $project_id = $q->param('project_id');
  my $printLine;
  my $BASE_DIR = "/net/arrays/Pipeline/dev7";
  my $OUTPUT_DIR = "$BASE_DIR/output";

print qq~
  <P> This is the plan file that will be submitted.<BR>
    If you care to manually alter the file, you may do so in this textbox.<BR>
    [I will add a link to a page on how to manually alter files here]<BR>
    Click &quot;Submit to Pipeline&quot; to continue</P>
  <FORM METHOD = "post" NAME = "planFile">
  <INPUT TYPE = "submit" NAME = "FINALIZE" VALUE = "Submit to Pipeline"><BR>
  <INPUT TYPE = "hidden" NAME = "id" VALUE = "$project_id">
  <TEXTAREA NAME = "planFileText" COLS = 70 ROWS = 25>~;

#Printing Default Parameters
print qq~#DEFAULT PARAMETERS
preprocess_base_flag          = false
preprocess_normalizatin_flag  = false
preprocess_saturation_flag    = false
preprocess_scale_flag         = false
preprocess_debug_flag         = false

preprocess_base_value          = xxxxx
preprocess_normalization_value = median
preprocess_saturation_value    = xxxxx
preprocess_scale_value         = xxxxx
preprocess_debug_value         = xxxxx

mergereps_optimization_flag = false
mergereps_filter_flag      = false
mergereps_exclude_flag      = false

mergereps_optimization_value = xxxxx
mergereps_filter_value       = on
mergereps_exclude_value      = $BASE_DIR/tools/etc/excluded_gene_names

vera_evolution_flag      = false
vera_initial_choice_flag = false
vera_critical_delta_flag = false
vera_debugging_file_flag = false

vera_evolution_value      = xxxxx
vera_initial_choice_value = xxxxx
vera_critical_delta_value = xxxxx
vera_debugging_file_value  = xxxxx

sam_debugging_file_flag = false
sam_debugging_file_value = xxxxx

mergeconds_lambda_flag   = false
mergeconds_ratio_flag    = false
mergeconds_stdev_flag    = false
mergeconds_rep_flag      = false

mergeconds_lambda_value  = xxxxx
mergeconds_ratio_value   = xxxxx
mergeconds_stdev_value   = xxxxx
mergeconds_rep_value     = xxxxx

postSam_flag             = false
postSam_value            = xxxxx

email_notify             = xxxxx
EXECUTE = default_parameters\n\n
~;


  my %conditions;
  my $file;
  my $direction;
  my $mapfile;
  my @fileLine;
  my $forPostSam; #need a key file for postSam

#Printing Preprocess Information
  for(my $x = 0;$x<2;$x++){
    my @direction_files;
    if ($x==0) {@direction_files = @forward_files;}
    if ($x==1) {@direction_files = @reverse_files;}
    foreach $file(@direction_files){
      @fileLine = split /:/,$file;
      my $preprocess_output = $fileLine[0];
      $preprocess_output =~ s(^.*/)();
      $preprocess_output =~ s/\..*/\.rep/;
      $forPostSam = $fileLine[1];
      push @{$conditions{$fileLine[2]}}, $preprocess_output;
      if($x==0){
	push @{$conditions{$fileLine[2]}},"f";
      }else{
	push @{$conditions{$fileLine[2]}}, "r";
      }
      $printLine="#PREPROCESS\nfile_name = $fileLine[0]\nmap_file = $fileLine[1]\noutput_file = $preprocess_output\n";
      if ($base){$printLine.= "preprocess_base_flag = true\npreprocess_base_value = $baseValue\n";}
      if ($sat) {$printLine.= "preprocess_saturation_flag = true\npreprocess_saturation_value= $satValue\n";}
      if ($norm ne "median"){$printLine.="preprocess_normalization_flag = true\npreprocess_normalization_value = $norm\n";}
      if ($scale){$printLine.="preprocess_scale_flag = true\npreprocess_scale_value = $scaleValue\n";}
      if ($preprocDebug){$printLine.="preprocess_debug_flag = true\npreprocess_debug_value = xxxxxn\n";}
      $printLine.="EXECUTE = preprocess\n\n";
      print $printLine;
    }
  }

#Printing MergeReps Information
  my $key;
  my @condition_files;
  my @files;
  my $condition;
  foreach $key (keys %conditions){
    my $merge_output = $key;
    $merge_output .= ".merge";
    $printLine = "#MERGEREPS\ncondition_name = $key\n";
    @files = @{$conditions{$key}};
    foreach $condition(@files){
      if ($condition eq "r" || $condition eq "f"){
	$printLine.="file_direction = $condition\n";
      }
      else{$printLine.="file_name = $condition\n";}
    }
    $printLine.="output_file = $merge_output\n";
    if ($replicate){$printLine.="mergereps_optimization_flag = true\nmergereps_optimization_value= $replicateValue\n";}
    if ($exclude)  {$printLine.="mergereps_exclude_flag = true\nmergereps_exclude_value = $excludeFile\n";}
    if (!$filter)  {$printLine.="mergereps_filter_flag = false\nmergereps_filter_value = off\n";}
    $printLine.="EXECUTE = mergeReps\n\n";
    print $printLine;
  }

#Printing VERA/SAM Options
  if ($useVandS){
    foreach $key(keys %conditions){
      $printLine = "#VERA/SAM\nfile_name = $key.merge\nvera_output_file = $key.model\nsam_output_file = $key.sig\n";
      if ($veraFlag){$printLine.="vera_critical_delta_flag = true\nvera_critical_delat_value= $veraValue\n";}
      if ($veraEvolFile){$printLine.="vera_evolution_flag = true\nvera_evolution_value = xxxxx\n";}
      if ($veraDebug){$printLine.="vera_debugging_file_flag = true\nvera_debugging_file_value = xxxxx\nsam_debugging_file_flag = true\nsam_debugging_file_value = xxxxx\n";}
      if ($veraModelFlag){$printLine.="vera_initial_choice_flag = true\nvera_initial_choice_value= $veraModelFile\n";}
      $printLine.="EXECUTE = vera_and_sam\n\n";
      print $printLine;
    }
  }

#Printing MergeConds Information
  if ($#merge_files>1){
    my $mergeLoopVar;
    $printLine = "#MERGECONDS\n";
    foreach $mergeLoopVar (@merge_files){
      $printLine.= "condition_name = $mergeLoopVar\n";
    }
    if ($lambdaFlag){$printLine.="mergeconds_lambda_flag = true\nmergeconds_lambda_value = $lambdaValue\n";}
    if ($ratioFlag){$printLine.="mergeconds_ratio_flag = true\nmergeconds_ratio_value = $ratioValue\n";}
    if ($stdevFlag){$printLine.= "mergeconds_stdev_flag = true\nmergeconds_stdev_value = $stdevValue\n";}
    if ($repFlag){$printLine.="mergeconds_rep_flag = true\nmergeconds_rep_value = $repValue\n";}
    $printLine.="EXECUTE = mergeConds\n\n";
    print $printLine;
  }

#Printing Miscellaneous Information
  if ($postSam){
    my $key;
    my @conditions_files;
    my @files;
    my $condition;
    foreach $key(keys %conditions){
      my $postSam_input = $key;
      $postSam_input .=".sig";
      my $postSam_output = $key;
      $postSam_output .=".clone";
      $printLine = "#POSTSAM\n";
      $printLine .= "file_name = $postSam_input\n";
      $printLine .= "key_file  = $forPostSam\n";
      $printLine .= "output_file = $postSam_output\n";
      $printLine .= "EXECUTE = postSam\n\n";
      print $printLine;
    }
  }
  if ($notify){
    $printLine = "#EMAIL NOTIFY\n";
    my @names = split/,/,$addresses;
    my $temp_key;
    foreach $temp_key(@names){
      if($temp_key =~ /\@/){
	$printLine .= "notify_value = $temp_key\n";
      }
      else{
	$printLine .= "notify_value = $temp_key";
	$printLine .= "\@systemsbiology.org\n";
      }
    }
    $printLine .= "EXECUTE = email_notify\n\n";
    print $printLine;
  }


  print qq~</TEXTAREA></FORM>~;
#  if ($print){close (PLAN);}
}



###############################################################################
# submit Job
###############################################################################
sub submitJob {
    my $command_file_content = $q->param('planFileText');
    my $project_id = $q->param('id');

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $timestr = strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);

    my $plan_filename = "job$timestr.planFile";
    my $control_filename = "job$timestr.control";
    my $log_filename = "job$timestr.log";

    my $queue_dir = "/net/arrays/Pipeline/dev7/queue";



    #### Verify that the plan file does not already exist
    if ( -e $plan_filename ) {
      print qq~
	Wow, the job filename '$plan_filename' already exists!<BR>
	Please go back and click PROCESS again.  If this happens twice
	in a row, something is very wrong.  Contact edeutsch.<BR>\n
      ~;
      return;
    }


    #### Write the plan file
    print "Writing processing plan file '$plan_filename'<BR>\n";
    open(PLANFILE,">$queue_dir/$plan_filename") ||
      croak("Unable to write to file '$queue_dir/$plan_filename'");
    print PLANFILE $command_file_content;
    close(PLANFILE);


    #### Write the control file
    print "Writing job control file '$control_filename'<BR>\n";
    open(CONTROLFILE,">$queue_dir/$control_filename") ||
      croak("Unable to write to file '$queue_dir/$control_filename'");
    print CONTROLFILE "submitted_by=$current_username\n";
    print CONTROLFILE "project_id=$project_id\n";
    print CONTROLFILE "status=SUBMITTED\n";
    close(CONTROLFILE);


    print "Done!<BR><BR>\n";

    print qq~
	The plan and job control files have been successfully written to the
	queue.  Your job will be processed in the order received.  You can
	see the log file of your job by clicking on the link below:<BR><BR>

        Well, theres no link yet, but paste this into a unix window:<BR><BR>

	cd /net/arrays/Pipeline/dev7/output/project_id/$project_id<BR>
	if ( -e $log_filename ) tail -f $log_filename<BR>

	<BR><BR><BR>
    ~;

}













