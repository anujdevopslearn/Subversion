#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username %hash_to_sort
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Ontology::Tables;
use SBEAMS::Ontology::TableInfo;
use SBEAMS::Immunostain;
use SBEAMS::Immunostain::Settings;
use SBEAMS::Immunostain::Tables;


$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Immunostain;
$sbeamsMOD->setSBEAMS($sbeams);


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
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}




###############################################################################
# Set Global Variables and execute main()
###############################################################################

my $INTRO = '_displayIntro';
my $START = '_start';
my $ERROR = '_error';
my $ANTIBODY = '_processAntibody';
my $STAIN = '_processStain';
my $CELL = '_processCells';
my (%indexHash,%editorHash);
#possible actions (pages) displayed
my %actionHash = (
	$INTRO	=>	\&displayIntro,
	$START	=>	\&displayMain,
	$ANTIBODY =>	 \&processAntibody,
	$STAIN 	=>	 \&processStain,
	$CELL	=>	\&processCells,
	$ERROR	=>	\&processError
	);

main();
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main 
{
		
#### Do the SBEAMS authentication and exit if a username is not returned
#this will allows guest witout password and username
  exit unless ($current_username = $sbeams->Authenticate(
    permitted_work_groups_ref=>['Immunostain_user','Immunostain_admin',
      'Immunostain_readonly','Admin'],
    allow_anonymous_access=>1,
    #connect_read_only=>1,
  ));


#### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
#$sbeams->printDebuggingInfo($q);
#### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);

  #### Decide what action to take based on information so far
  if ($parameters{action} eq "_processCells") {
# special handling when cells are processed
		processCells(ref_parameters=>\%parameters);
	}
	else
	{
# normal handling for anything else			
	$sbeamsMOD->display_page_header();
	}
    handle_request(ref_parameters=>\%parameters);  
   $sbeamsMOD->printPageFooter();
  


} # end main



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
	
  $current_contact_id = $sbeams->getCurrent_contact_id();

	 
#### Show current user context information
  $sbeams->printUserContext();
 

#### Get information about the current project from the database
  $sql = qq~
	SELECT UC.project_id,P.name,P.project_tag,P.project_status,
               P.PI_contact_id
	  FROM $TB_USER_CONTEXT UC
	 INNER JOIN $TB_PROJECT P ON ( UC.project_id = P.project_id )
	 WHERE UC.contact_id = '$current_contact_id'
  ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  my $project_id = '';
  my $project_name = 'NONE';
  my $project_tag = 'NONE';
  my $project_status = 'N/A';
  my $PI_contact_id = 0;
  if (@rows) {
    ($project_id,$project_name,$project_tag,$project_status,$PI_contact_id) = @{$rows[0]};
  }
  my $PI_name = $sbeams->getUsername($PI_contact_id);
  

#### If the current user is not the owner, the check that the
#### user has privilege to access this project
  if ($project_id > 0) {

    my $best_permission = $sbeams->get_best_permission();

#### If not at least data_reader, set project_id to a bad value
    $project_id = -99 unless ($best_permission > 0 && $best_permission <=40);

  }

#### Get all the experiments for this project
	my $action = $parameters{'action'};
	print qq~	<TABLE WIDTH="100%" BORDER=0> ~;
#loading the default page (Intro)
my $sub = $actionHash{$action} || $actionHash{$INTRO};


if ($sub )  {
		#print some info about this project
		#only on the main page
		
		print qq~
				<H1>Current Project: <A class="h1" HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">$project_name</A></H1>
				<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	      <TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
				<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag</TD></TR>
				<TR><TD></TD><TD COLSPAN="2"><B>Owner:</B> $PI_name</TD></TR>
				<TR><TD></TD><TD COLSPAN="2"><B>Access Privileges:</B> <A HREF="$CGI_BASE_DIR/ManageProjectPrivileges">[View/Edit]</A></TD></TR>
				<TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	      <TD WIDTH="100%"><TABLE BORDER=0>
		  ~ if ($action eq '_displayIntro' || !$action) ;
		checkGO();
#### If the project_id wasn't reverted to -99, display information about it
		if ($project_id == -99) 
		{
			print "	<TR><TD WIDTH=\"100%\">You do not have access to this project.  Contact the owner of this project if you want to have access.</TD></TR>\n";
		}
		else
		{
			&$sub(ref_parameters=>\%parameters,project_id=>$project_id);
		}
		
#could not find a sub
	}
	else {
		print_fatal_error("Could not find the specified routine: $sub");
	
	}
	print "</table>";
	
}

#beginning page
sub displayIntro
{
	 my %args = @_;

	 
#data for the grand summary	 

#/*total number of stains*/
my $totalStainsSql = qq /select count(*) from $TBIS_ASSAY/;

#/*number of imaged stains*/
my $imagedStainsSql = qq/ select assay_name from $TBIS_ASSAY ss
join $TBIS_ASSAY_CHANNEL ac on ss.assay_id = ac.assay_id
join $TBIS_ASSAY_IMAGE si on ac.assay_channel_id  = si.assay_channel_id
group by assay_name/;

#/*number of char. stains*/
my $charStainsSql = qq/ select assay_name from $TBIS_ASSAY ss
join $TBIS_ASSAY_CHANNEL	 ac on ss.assay_id = ac.assay_id
join $TBIS_ASSAY_UNIT_EXPRESSION scp on ac.assay_channel_id = scp.assay_channel_id
group by assay_name/;

#/*total number of antibodies*/
my $totalAntibodySql = qq / select count(*) from $TBIS_ANTIBODY/;

#/*number of characterized anitbodies*/
my $charAntibodySql = qq / select antibody_name from $TBIS_ASSAY ss
join $TBIS_ASSAY_CHANNEL ac on ss.assay_id = ac.assay_id
join $TBIS_ASSAY_UNIT_EXPRESSION  scp on ac.assay_channel_id = scp.assay_channel_id
join $TBIS_ANTIBODY ab on ac.antibody_id = ab.antibody_id group by antibody_name/;

#/*total number of antibodies*/
my $totalProbeSql = qq / select count(*) from $TBIS_PROBE/;

#number of characterized probes
my $charProbeSql = qq / select probe_name from $TBIS_ASSAY ss
join $TBIS_ASSAY_CHANNEL ac on ss.assay_id = ac.assay_id
join $TBIS_ASSAY_UNIT_EXPRESSION  scp on ac.assay_channel_id = scp.assay_channel_id
join $TBIS_PROBE p on ac.antibody_id = p.probe_id group by probe_name/;

#/*total number of images*/
my $totalImagesSql = qq / select count(*) from $TBIS_ASSAY_IMAGE/;

#/*number of unique images */
my $uniqueImagesSql = qq / select assay_image_id  from $TBIS_ASSAY_IMAGE where patindex('%- %', image_name) != 0/; 

	 
my $totalStains =($sbeams->selectOneColumn($totalStainsSql))[0];	 
my $imagedStains = scalar($sbeams->selectOneColumn($imagedStainsSql));
my $charStains  = scalar($sbeams->selectOneColumn($charStainsSql));
my $totalAntibody  = ($sbeams->selectOneColumn($totalAntibodySql))[0];
my $charAntibody  = scalar($sbeams->selectOneColumn($charAntibodySql));
my $totalImages  = ($sbeams->selectOneColumn($totalImagesSql))[0];
my $uniqueImages  = scalar($sbeams->selectOneColumn($uniqueImagesSql));
#not used
my $totalProbe = ($sbeams->selectOneColumn($totalProbeSql))[0];
my $charProbe = scalar($sbeams->selectOneColumn($charProbeSql));
	 
#### get the project id
  my $project_id = $args{'project_id'} || die "project_id not passed";
#load the javascript functions
#get the tissue and the organisms for this project and display them as check boxes				
my $organismSql = qq~ select s.organism_id,organism_name from $TBIS_SPECIMEN s
		join $TB_ORGANISM sdo on s.organism_id = sdo.organism_id	 WHERE s.project_id = '$project_id'
		group by organism_name,s.organism_id ~;
my %organismHash = $sbeams->selectTwoColumnHash($organismSql);
		
my $tissueSql = qq~ select s.tissue_type_id,tissue_type_name from $TBIS_SPECIMEN s
		join $TBIS_TISSUE_TYPE tt on s.tissue_type_id = tt.tissue_type_id 	WHERE s.project_id = '$project_id'  
		group by tissue_type_name,s.tissue_type_id ~;	
#get all the data (specimen, stains, slides) for this project and display the data 		
my %tissueHash = $sbeams->selectTwoColumnHash($tissueSql);
    my $sql = qq~
		select sp.specimen_id, ss.assay_id ,si.assay_image_id,sbo.organism_name,tt.tissue_type_name,sb.specimen_block_id,
                       sbo.organism_id,tt.tissue_type_id
		from $TBIS_ASSAY ss
		left join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id
		left join $TBIS_SPECIMEN sp on sb.specimen_id = sp.specimen_id
		left join $TBIS_TISSUE_TYPE tt on sp.tissue_type_id = tt.tissue_type_id
		left join $TB_ORGANISM sbo on sp.organism_id = sbo.organism_id
		LEFT JOIN $TBIS_ASSAY_CHANNEL ac ON ss.assay_id = ac.assay_id
		left join $TBIS_ASSAY_IMAGE si on ac.assay_channel_id = si.assay_channel_id
		WHERE SP.project_id = '$project_id'
		order by Organism_Name 
		~;	
    my @rows = $sbeams->selectSeveralColumns($sql);

#### If there are experiments, display them


 		my (%hash,%stainedSlideHash,%imageHash,%tissueTypeHash);
	 my %organism_ids;
	 my %tissue_type_ids;

#we got some data for this project		
		if (@rows)
		{
		
	  foreach my $row (@rows)
		{
			my ($specimenID,$stainedSlideID,$slideImageID,$organismName,$tissueName,$specimenBlockID,$organism_id,$tissue_type_id) = @{$row};
			$organism_ids{$organismName} = $organism_id;
			$tissue_type_ids{$tissueName} = $tissue_type_id;

			$hash{$organismName}->{specimenID}->{count}++ if ($specimenID and
        !exists($hash{$organismName}->{specimenID}->{$specimenID}));
			$hash{$organismName}->{stainedSlideID}->{count}++ if ($stainedSlideID and
        !exists($hash{$organismName}->{stainedSlideID}->{$stainedSlideID}));
			$hash{$organismName}->{slideImageID}->{count}++ if ($slideImageID and
        !exists($hash{$organismName}->{slideImageID}->{$slideImageID}));
      $hash{$organismName}->{specimenID}->{$specimenID} = 1;
      $hash{$organismName}->{stainedSlideID}->{$stainedSlideID} = 1;
      $hash{$organismName}->{slideImageID}->{$slideImageID} = 1;
			$hash{$organismName}->{specimenBlockID}->{$specimenBlockID} = 1 if $specimenBlockID;
			$tissueTypeHash{$tissueName}->{$organismName}->{specimenID}->{count}++ if ($specimenID and 
			!exists($tissueTypeHash{$tissueName}->{$organismName}->{specimenID}->{$specimenID}));
			$tissueTypeHash{$tissueName}->{$organismName}->{stainedSlideID}->{count}++ if ($stainedSlideID and 
			!exists($tissueTypeHash{$tissueName}->{$organismName}->{stainedSlideID}->{$stainedSlideID}));
			$tissueTypeHash{$tissueName}->{$organismName}->{slideImageID}->{count}++ if ($slideImageID and 
			!exists($tissueTypeHash{$tissueName}->{$organismName}->{slideImageID}->{$slideImageID}));
			$tissueTypeHash{$tissueName}->{$organismName}->{specimenID}->{$specimenID} = 1;
     	$tissueTypeHash{$tissueName}->{$organismName}->{stainedSlideID}->{$stainedSlideID} = 1;
			$tissueTypeHash{$tissueName}->{$organismName}->{slideImageID}->{$slideImageID} = 1;
			$tissueTypeHash{$tissueName}->{$organismName}->{specimenBlockID}->{$specimenBlockID} = 1 if $specimenBlockID;
		}
					
		my $mouseString = join ', ', keys %{$hash{Mouse}->{specimenBlockID}};
		my $humanString = join ', ', keys %{$hash{Human}->{specimenBlockID}};
		my $mouseBladderString = join ', ', keys %{$tissueTypeHash{Bladder}->{Mouse}->{specimenBlockID}};
		my $mouseNormalProstateString = join ', ', keys %{$tissueTypeHash{'Normal Prostate'}->{Mouse}->{specimenBlockID}};
		my $humanBladderString = join ', ', keys %{$tissueTypeHash{Bladder}->{Human}->{specimenBlockID}};
		my $humanNormalProstateString = join ', ', keys %{$tissueTypeHash{'Normal Prostate'}->{Human}->{specimenBlockID}};
		
		print qq *
		<tr></tr><tr></tr>
		*; 
#Grand Summary		
print qq *	<tr><td><b><font color =red>Project Grand Summary :</b></font></td></tr><tr></tr><tr></tr><tr>
			<td colspan = 2><UL>
			<li>Total Number of Stains: $totalStains
				<ul>
				<li>Number of characterized Stains: $charStains
				<li>Number of Stains with Images: $imagedStains
				</ul>
			<li>Total Number of Antibodies: $totalAntibody
				<ul>
				<li>Number of  Antibodies with Tissue Characterization: $charAntibody
				</ul>
			<li>Total Number of Images (includes magnified views of identical Samples) : $totalImages
				<ul>
				<li>Total Number of distinct Images (distinct Images of different Samples)  : $uniqueImages
				</ul>
			</ul>
			<td>
			</tr><tr></tr><tr></tr>*;
			
#summary by organismtype		
		print "<tr><td><b><font color=red>Project Summary by Organism:</b></font></td></tr><tr></tr><tr></tr><tr>";
		foreach my $key (sort keys %hash)
		{
			print "<td colspan=2><B>$key </B><A HREF=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERYHIDE&organism_id=$organism_ids{$key}&display_options=MergeLevelsAndPivotCellTypes\"><b>[Full CD Specificity Summary]</A></b></td>";
		}
		
		print "</tr><tr>";
		foreach my $key (sort keys %hash)
		{
		print qq~
			<td colspan = 2><UL>
      <LI>Total Number of Specimens: $hash{$key}->{specimenID}->{count}
			<LI>Total Number of Stains: $hash{$key}->{stainedSlideID}->{count}
			<LI>Total Number of Images: $hash{$key}->{slideImageID}->{count}
      </UL>
      </td>~;
		}
		print "</tr>
			<tr></tr><tr></tr>";
    
#summary  by tissuetype
	print "<tr><td><b><font color =red>Project Summary by TissueType:</b></font></td></tr><tr></tr><tr></tr><tr>";
	foreach my $key (sort keys %tissueTypeHash)
		{
				print "<tr><td colspan=2><b>$key</B><td></tr><tr>";
				foreach my $organism (sort keys %hash)
				{
						print "<td colspan = 2 nowrap><UL>";
						print "<LI> Organism: <b>$organism </b><A HREF=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERYHIDE&tissue_type_id=$tissue_type_ids{$key}&organism_id=$organism_ids{$organism}&display_options=MergeLevelsAndPivotCellTypes\"><b>[Full CD Specificity Summary]</A></b>";
					print qq~
			<LI>Total Number of Specimens: $tissueTypeHash{$key}->{$organism}->{specimenID}->{count}
			<LI>Total Number of Stains: $tissueTypeHash{$key}->{$organism}->{stainedSlideID}->{count}
			<LI>Total Number of Images: $tissueTypeHash{$key}->{$organism}->{slideImageID}->{count}
      </UL>
      </td>~;
				}
				print "</tr><tr></tr>";
			}
	print "</tr><tr></tr><tr></tr>";

#creating the checkboxes
		print qq~ <tr></tr><tr><td><b><font color="red">Select one or more of the following Options to view Stain, Antibody, Celltype Characterization and Image data related to your selection</font></B><td></tr><tr></tr>~;
		print $q->start_form (-onSubmit=>"return checkForm()");
	
			foreach my $key (keys %organismHash)
			{
				print qq~ <tr><td><input type="checkbox" name="$organismHash{$key}" value="$key">$organismHash{$key}</td></tr>~;
			}
#display the check boxes
			foreach my $key (keys %tissueHash)
			{
				if($tissueHash{$key} eq 'Normal Prostate')
				{
						print qq~ <tr><td><input type="checkbox" name="NProstate" value="$key">$tissueHash{$key}</td></tr>~;
						next;
				}
				print qq~ <tr><td><input type="checkbox" name="$tissueHash{$key}" value="$key">$tissueHash{$key}</td></tr>~;
			}
			print q~<tr></tr><tr><td><input type ="submit" name= "SUBMIT" value = "QUERY"></td></tr> ~;
			print "<input type= hidden name=\"action\" value = \"$START\">";
			print $q->end_form;
		}#end of if data was found for this project
		
#no data was found		
		else
		{
			 print "	<TR><TD WIDTH=\"100%\"><B><NOWRAP>This project contains no IHC Data</NOWRAP></B></TD></TR>\n";
		}
		
		 #### Finish the table
  print qq~
	</TABLE></TD></TR>
	</TABLE>~;

  ##########################################################################
  #### Print out all projects owned by the user
	$sbeams->printProjectsYouOwn() if $sbeams->getCurrent_contact_id() ne 107;



  ##########################################################################
  #### Print out all projects user has access to
  $sbeams->printProjectsYouHaveAccessTo()  if $sbeams->getCurrent_contact_id() ne 107;


  ##########################################################################
  #### Print out some recent resultsets
  $sbeams->printRecentResultsets()  if $sbeams->getCurrent_contact_id() ne 107;



  ##########################################################################
  #### Finish with a disclaimer
  print qq~
	<BR>
	<BR>
	This system and this module in particular are still under
	active development.  Please be patient and report bugs,
	problems, difficulties, as well as suggestions to
	<B>edeutsch\@systemsbiology.org</B>.<P>
	<BR>
	<BR>
  ~;

  return;
		
}
		

sub displayMain
{ 
	my %args = @_;
	my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  
	my %parameters = %{$ref_parameters};
#### Process the arguments list
  	my $project_id = $args{'project_id'} || die "project_id not passed";
	#		foreach my $k (keys %parameters)
	#	{
	#			print "$k  ==== $parameters{$k} <br>";
	#	}
	
#populate tbe option list based on what the user checked on the intro page		
my $antibodySql = "select ab.antibody_id, ab.antibody_name from $TBIS_ANTIBODY ab
join $TBIS_ASSAY_CHANNEL ac on ab.antibody_id = ac.antibody_id
join $TBIS_ASSAY ss on ac.assay_id = ss.assay_id 
join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id 
join $TBIS_SPECIMEN s on sb.specimen_id = s.specimen_id 
join $TBIS_TISSUE_TYPE tt on s.tissue_type_id = tt.tissue_type_id
join $TB_ORGANISM sbo on s.organism_id = sbo.organism_id 
where ".buildSqlClause(ref_parameters=>\%parameters) . "group by ab.antibody_id,ab.antibody_name,ab.sort_order order by ab.sort_order"; 

my $stainSql = "select ss.assay_id, assay_name from $TBIS_ASSAY ss
join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id 
join $TBIS_SPECIMEN s on sb.specimen_id = s.specimen_id 
join $TBIS_TISSUE_TYPE tt on s.tissue_type_id = tt.tissue_type_id
join $TB_ORGANISM sbo on s.organism_id = sbo.organism_id 
where ".buildSqlClause(ref_parameters=>\%parameters) . " group by ss.assay_id,ss.assay_name order by ss.assay_name"; 

my $cellSql = "select ct.structural_unit_id, structural_unit_name from $TBIS_STRUCTURAL_UNIT ct
join $TBIS_ASSAY_UNIT_EXPRESSION scp on ct.structural_unit_id = scp.structural_unit_id
join $TBIS_ASSAY_CHANNEL ac on scp.assay_channel_id = ac.assay_channel_id
join $TBIS_ASSAY ss on ac.assay_id = ss.assay_id
join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id 
join $TBIS_SPECIMEN s on sb.specimen_id = s.specimen_id 
join $TBIS_TISSUE_TYPE tt on s.tissue_type_id = tt.tissue_type_id
join $TB_ORGANISM sbo on s.organism_id = sbo.organism_id 
where ".buildSqlClause(ref_parameters=>\%parameters) .  "group by ct.structural_unit_id,ct.structural_unit_name, ct.sort_order order by ct.sort_order";
 
	
		my $buildClause = buildSqlClause(ref_parameters=>\%parameters);
		my $antibodyOption;
		my $stainOption;
		my $cellOption;
#### Process the arguments list
  	my $project_id = $args{'project_id'} || die "project_id not passed";

	  $antibodyOption = $sbeams->buildOptionList($antibodySql, "Selected","MULTIOPTIONLIST");
		my %antibodyOptionHash = $sbeams->selectTwoColumnHash($antibodySql);
#collecting all relevant antibody_ids for the user's check 
		my $antibodyString = join ',',keys %antibodyOptionHash;
		
		$stainOption = $sbeams->buildOptionList($stainSql, "Selected","MULTIOPTIONLIST");
		my %stainOptionHash = $sbeams->selectTwoColumnHash($stainSql);
#collecting all revelant stain_ids for the user's check
		my $stainString = join ',',keys %stainOptionHash;

		$cellOption = $sbeams->buildOptionList($cellSql, "Selected","MULTIOPTIONLIST");
		my %cellOptionHash = $sbeams->selectTwoColumnHash($cellSql);
#collecting all relevant cell_type_ids for the user's check
		my $cellString = join ',', keys %cellOptionHash; 
#displaying the individual option boxes			
		print $q->start_form;
		print qq~ <TR><TD NOWRAP width = 300>Summarized Data keyed on  Antibody: </TD><td align=center width = 200><Select Name="antibody_id" Size=6 Multiple> <OPTION VALUE = "all">ALL ~;
		print "$antibodyOption";
		print q~</td><td><td width = 150><input type ="submit" name= "SUBMIT1" value = "QUERY"></td>~;
		print "<input type= hidden name=\"action\" value = \"$ANTIBODY\">";
		print "<input type = hidden name =\"selection\" value = \"$antibodyString\">";
		print "<input type = hidden name =\"buildClause\" value = \"$buildClause\">";
		print $q->end_form;

		print $q->start_form;
		print qq~ <tr></tr><TR><TD NOWRAP>Summarized Data keyed on Stains: </TD><td align=center><Select Name="stained_slide_id" Size=6 Multiple> <OPTION VALUE = "all">ALL ~;
		print "$stainOption";
		print q~</td><td><td><input type ="submit" name= "SUBMIT2" value = "QUERY"></td>~;
		print "<input type= hidden name=\"action\" value = \"$STAIN\">";
		print "<input type = hidden name =\"selection\" value = \"$stainString\">";
		print "<input type = hidden name =\"buildClause\" value = \"$buildClause\">";
		print $q->end_form;

		print $q->start_form;
		print qq~ <tr></tr><TR><TD NOWRAP>Summarized Data keyed on CellType: </TD><td align=center><Select Name="cell_type_id" Size=6 Multiple> <OPTION VALUE = "all">ALL ~;
		print "$cellOption";
		print q~</td><td><td><input type ="submit" name= "SUBMIT3" value = "QUERY"></td> ~;
		print " <input type= hidden name=\"action\" value =\"$CELL\">";		
		print "<input type = hidden name =\"selection\" value = \"$cellString\">";
		print "<input type = hidden name =\"buildClause\" value = \"$buildClause\">";
		print $q->end_form;
#query button is disabled if there are no cell types for this user's query
		if (!$cellString)
		{
				my $func = "disableQuery()";
				print "<script>$func</script>"
		}
#### Finish the table
  print qq~
	</TABLE></TD></TR>
	</TABLE>
  ~;
  return;
}

sub processAntibody
{

	my %args = @_;
#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
	my %resultset = ();
  my $resultset_ref = \%resultset;
	my %parameters = %{$ref_parameters};
#		foreach my $k (keys %parameters)
#		{
#				print "$k  ==== $parameters{$k}<br>";
#		}

#whcih antibodies to display
	my $includeClause = $parameters{antibody_id};
	$includeClause = 'all' if !$includeClause;
	if ($includeClause eq 'all' )
	{ 			
			$includeClause = $parameters{selection};
	}
	my $limitClause;
	$limitClause  = " and " .$parameters{buildClause} if $parameters{buildClause};
#get some CD information	
	my $sqlCoord = qq~ select antibody_name, 
	alternate_names,
	biosequence_accession,
	genome_location+genome_strand,
	accessor
	from $TBIS_ANTIBODY ab
	left join $TBIS_ANTIGEN an on ab.antigen_id = an.antigen_id
	left join $TBIS_BIOSEQUENCE bs on an.biosequence_id = bs.biosequence_id
	left join Immunostain.dbo.genome_coordinates gc on bs.biosequence_accession = gc.locus_link_id
	left join $TBIS_BIOSEQUENCE_SET bss on bs.biosequence_set_id = bss.biosequence_set_id
	left join sbeams.dbo.organism sbo on bss.organism_id = sbo.organism_id
	left join $TBIS_DBXREF dbx on bs.dbxref_id = dbx.dbxref_id 
	where ab.antibody_id in ($includeClause) and set_Name ='LocusLink' and 
	dbxref_name = 'LocusLink' ~;

	
	my @genomeCoord = $sbeams->selectSeveralColumns($sqlCoord);
	my %genomeHash;
	foreach my $genome (@genomeCoord)
	{
			my %hash;
			my($name,$alternateName,$locusID,$genomeLocation,$url) = @{$genome};
			$hash{alternateName} = $alternateName;
			$hash{locusLinkID} = $locusID;
			$hash{locusLinkUrl} = $url."LocRpt.cgi?l=".$locusID;
			$hash{genomeLocation} = $genomeLocation;
			$hash{genomeLocationUrl} = 'http://genome.ucsc.edu/cgi-bin/hgTracks?org=Human&db=hg16&position='.$name;
			$genomeHash{$name}->{attributes} = \%hash;  
	}		

	my $query = "select ab.antibody_name,ab.antibody_id,
	ss.assay_name,	ss.assay_id,
	structural_unit_name, ct.structural_unit_id,ct.sort_order,
	level_name,
	at_level_percent,
	si.assay_image_id,	si.raw_image_file,	si.processed_image_file,	si.image_magnification,
	sbo.organism_name,
	ISNULL(ac.assay_channel_name, ss.assay_name + ' - chan ' + cast(ac.channel_index as varchar)) as assay_channel_name, ac.assay_channel_id,
	cpl.level_name
	from $TBIS_ASSAY ss
	left join $TBIS_ASSAY_CHANNEL ac on ss.assay_id = ac.assay_id
	left join $TBIS_ANTIBODY ab on ac.antibody_id = ab.antibody_id
	left join $TBIS_ASSAY_UNIT_EXPRESSION  scp on ac.assay_channel_id = scp.assay_channel_id
	left join $TBIS_EXPRESSION_LEVEL cpl on scp.expression_level_id = cpl.expression_level_id 
	left join $TBIS_STRUCTURAL_UNIT ct on scp.structural_unit_id = ct.structural_unit_id
	left join $TBIS_ASSAY_IMAGE si on ac.assay_channel_id =  si.assay_channel_id
	left join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id
	left join $TBIS_SPECIMEN s on sb.specimen_id = s.specimen_id 
	left join $TBIS_TISSUE_TYPE tt on s.tissue_type_id = tt.tissue_type_id
	left join $TB_ORGANISM sbo on s.organism_id = sbo.organism_id
	where ab.antibody_id  in ( $includeClause ) $limitClause order by ab.sort_order, ct.sort_order";

	$sbeams->fetchResultSet(sql_query=>$query,resultset_ref=>$resultset_ref,);
    
	my $columHashRef = $resultset_ref->{column_hash_ref};
  my $dataArrayRef = $resultset_ref->{data_ref};
  my ($count, $prevStainedSlideId,$indexCounter) = 0;
	my (%stainHash,%cellHash,%stainIdHash,%stainCellHash,%stainLevelHash,%imageIdHash, %imageProcessedHash,%percentHash,%countHash,,%antibodyHash, %cellTypeHash);
	my ($prevStain,$prevAntibody, %stainChannelHash, %channelHash, %antibodyHash);
#arrange the data in a result set we can easily use
	my $rowCount = scalar(@{$resultset_ref->{data_ref}});
	
#	print "<br><A Href=\"$CGI_BASE_DIR\/$SBEAMS_SUBDIR\/main.cgi\">Back to Main Page <\/A><H4><center><font color=\"red\">Antibody Summary</font></center></H4>";
print "<tr><td></td><td align=center><H4><font color=\"red\">Antibody Summary</font></center></H4></td></tr><tr><td></td><td align=center><A Href=\"$CGI_BASE_DIR\/$SBEAMS_SUBDIR\/main.cgi\">Back to Main Page <\/A></td></tr>"; 

	if ($rowCount < 1)
	{
		print "<tr></tr><tr></tr><TD align=center><b>No Data available for this Antibody </b></TD></TR>";
	}
	else
	{
		my $antibodyIndex = 	$resultset_ref->{column_hash_ref}->{antibody_name};
		my $antibodyIdIndex = 	$resultset_ref->{column_hash_ref}->{antibody_id};
		my $stainNameIndex = 	$resultset_ref->{column_hash_ref}->{assay_name};
		my $stainedSlideIdIndex = 	$resultset_ref->{column_hash_ref}->{assay_id};
		my $cellNameIndex = 	$resultset_ref->{column_hash_ref}->{structural_unit_name};
		my $cellNameIdIndex = 	$resultset_ref->{column_hash_ref}->{structural_unit_id};
		my $levelIndex = 	$resultset_ref->{column_hash_ref}->{level_name};
		my $levelPercentIndex = 	$resultset_ref->{column_hash_ref}->{at_level_percent};
		my $slideImageIdIndex = $resultset_ref->{column_hash_ref}->{assay_image_id};
		my $rawImageFileIndex = $resultset_ref->{column_hash_ref}->{raw_image_file};
		my $processedImageFileIndex  =  $resultset_ref->{column_hash_ref}->{processed_image_file};
		my $magnificationIndex = $resultset_ref->{column_hash_ref}->{image_magnification};
#### channel		
		my $channelNameIndex =  $resultset_ref->{column_hash_ref}->{assay_channel_name};
		my $chanIdIndex =  $resultset_ref->{column_hash_ref}->{assay_channel_id};
#######
		my $organismNameIndex =  $resultset_ref->{column_hash_ref}->{organism_name};
		my $stainCount = 0;
		for (@{$resultset_ref->{data_ref}})
		{
	  		my @row = @{$resultset_ref->{data_ref}[$indexCounter]};
				my $antibody = $row[$antibodyIndex];
				my $antibodyNameID = $row[$antibodyIdIndex];
				my $stainName = $row[$stainNameIndex];
				my $stainedSlideId = $row[$stainedSlideIdIndex];
				my $cellType = $row[$cellNameIndex];
				my $level = lc($row[$levelIndex]);
				my $atLevelPercent = $row[$levelPercentIndex];
				my $organismName = $row[$organismNameIndex];
				my $cellTypeId = $row[$cellNameIdIndex];
######### channel
				my $channelName = $row[$channelNameIndex];
				my $channelID = $row[$chanIdIndex];
#################			
#count number of Stains for an antibody
				$stainCount++ if $prevStain ne $stainName and $prevAntibody eq $antibody;
#get all the images for a Stain
				my $imageProcessedFlag = 'raw_image_file';
				my $imageName = $row[$rawImageFileIndex];
				$imageName = $row[$processedImageFileIndex] if $row[$processedImageFileIndex];
				$imageProcessedFlag = 'processed_image_file' if  $row[$processedImageFileIndex];
########## channel
#				$stainHash{$antibody}->{$organismName}->{$stainName}->{$imageName} = $row[$magnificationIndex];
				$stainHash{$antibody}->{$organismName}->{$stainName}->{$channelName}->{$imageName} = $row[$magnificationIndex];
				$stainChannelHash{$stainName} = $channelName; 
				$channelHash{$channelName} = $channelID;
############				
				$countHash{$antibody}++ if !$stainIdHash{$stainName};
				$stainIdHash{$stainName} = $stainedSlideId;
				$imageIdHash{$imageName} = $row[$slideImageIdIndex] if $imageName;
				$imageProcessedHash{$imageName} = $imageProcessedFlag;
				$antibodyHash{$antibody} = $antibodyNameID;
				
				
#get all the cell types and the number of the stains available per intensity level per celltype per antibody
#this is the number of instances a cell type stains at a certain level
				$cellHash{$antibody}->{$cellType}->{intense}++ if !$stainCellHash{$stainName}->{$cellType} and  $cellType and defined($atLevelPercent); 
				$cellHash{$antibody}->{$cellType}->{equivocal}++  if !$stainCellHash{$stainName}->{$cellType} and   $cellType and defined($atLevelPercent);
				$cellHash{$antibody}->{$cellType}->{none}++ if !$stainCellHash{$stainName}->{$cellType} and  $cellType and defined($atLevelPercent);
				$cellHash{$antibody}->{$cellType}->{count}++if !$stainCellHash{$stainName}->{$cellType} and  $cellType;
#get the average percent of staining per celltype per level
#number of total percent level of intensity (at this level) for a celltype/total number of available stains		

$percentHash{$antibody}->{$cellType}->{intense} +=	$atLevelPercent if $row[$levelIndex] eq 'intense' and defined($atLevelPercent) and !$stainLevelHash{$stainName}->{intense}->{$cellType};			
$percentHash{$antibody}->{$cellType}->{equivocal} += $atLevelPercent if $row[$levelIndex] eq 'equivocal' and defined($atLevelPercent)	and !$stainLevelHash{$stainName}->{equivocal}->{$cellType};
$percentHash{$antibody}->{$cellType}->{none} += $atLevelPercent if $row[$levelIndex] eq 'none' and defined($atLevelPercent) and !$stainLevelHash{$stainName}->{none}->{$cellType};	
				$cellTypeHash{$cellType} = $row[$cellNameIdIndex];
				$antibodyHash{$antibody} = $row[$antibodyIdIndex];
				$indexCounter ++;
				$prevStain = $stainName;
				$prevAntibody = $antibody;
				$stainCellHash{$stainName}->{$cellType} = 1;
				$stainLevelHash{$stainName}->{$level}->{$cellType} = 1; 
		}	
		
#have some results for this antibody
#count how many experiments, detailed info about staining pattern and print out the stain images
	 %hash_to_sort = %stainHash;	
#antibody
		foreach my $antibodyKey (sort bySortOrder keys %stainHash)
		{
			my $antibodyID = $antibodyHash{$antibodyKey};
			print "<tr></tr><tr></tr><tr></tr><tr><td align=left><A HREF=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERYHIDE&antibody_id=$antibodyID&display_options=MergeLevelsAndPivotCellTypes\"><h4><font color =\"#D60000\">$antibodyKey</h4></font></a></TD></tr>";
			print "<tr></tr>";
			print "<tr><td align=left><b>Alternate names:</b>&nbsp;&nbsp;$genomeHash{$antibodyKey}->{attributes}->{alternateName}</td></tr>";
			print "<tr><td align=left><b>Locuslink ID:</b><a href =$genomeHash{$antibodyKey}->{attributes}->{locusLinkUrl}>&nbsp;&nbsp;  $genomeHash{$antibodyKey}->{attributes}->{locusLinkID}</a></td></tr>";
			print "<tr><td align=left><b>Genome Coordinates:</b><a href =$genomeHash{$antibodyKey}->{attributes}->{genomeLocationUrl}>&nbsp;&nbsp;  $genomeHash{$antibodyKey}->{attributes}->{genomeLocation}</a></td></tr>";
		
			print "<tr><td><b>Total Number of Stains:</b> </td>";
		
		
			print "<td align=center>$countHash{$antibodyKey}</td></tr><tr></tr>";
			print "<tr><td align=left><b>Staining Summmary:</b></td></tr>";
			print qq~ <tr><td></td><td align=center colspan=3><b>Average Percentage</b></td><td align=center><b>Number of charaterized Stains</b></td></tr>
			<tr><td align = left> Cell Type </td><td align=center>Intense</TD><TD align=center>Equivocal</td><td align=center>None</td></tr> ~if $cellHash{$antibodyKey};
			
			%hash_to_sort = %{$cellHash{$antibodyKey}} if $cellHash{$antibodyKey};
#all about the characterization of the celltypes
			foreach my $cell (sort bySortOrder keys %{$cellHash{$antibodyKey}})
			{   
					my $percentIntense = $percentHash{$antibodyKey}->{$cell}->{'intense'}/$cellHash{$antibodyKey}->{$cell}->{intense} if $cellHash{$antibodyKey}->{$cell}->{intense};
					my $percentEquivocal = $percentHash{$antibodyKey}->{$cell}->{'equivocal'}/$cellHash{$antibodyKey}->{$cell}->{equivocal} if $cellHash{$antibodyKey}->{$cell}->{equivocal};
					my $percentNone = $percentHash{$antibodyKey}->{$cell}->{'none'}/$cellHash{$antibodyKey}->{$cell}->{none} if $cellHash{$antibodyKey}->{$cell}->{none};
					$percentIntense =~ s/^(.*\.\d{3}).*$/$1/;
					$percentEquivocal =~ s/^(.*\.\d{3}).*$/$1/;
					$percentNone =~ s/^(.*\.\d{3}).*$/$1/;
					
					print "<tr><td align=left><A HREF=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&antibody_id=$antibodyHash{$antibodyKey}&structural_unit_id=$cellTypeHash{$cell}&display_options=MergeLevelsAndPivotCellTypes\">$cell</A></td>";
					print "<td align=center>$percentIntense</td><td align=center>$percentEquivocal</td><td align=center>$percentNone</td>";
					print "<td align=center>$cellHash{$antibodyKey}->{$cell}->{'count'}</td></tr>";
					#<td align=center>$cellHash{$antibodyKey}->{$cell}->{'equivocal'}</td><td align=center>$cellHash{$antibodyKey}->{$cell}->{'none'}</td>";
					 
			}	
			
#			print "<tr></tr><tr></tr><tr><td><b>Individual Stains</b></td><td align=center><b>Available Images</b></td></tr><tr></tr>";

#all about the stains			
			foreach my $species (keys %{$stainHash{$antibodyKey}})
			{
					print "<tr><td align=left><b>$species :</b></td></tr><tr></tr>";
					print qq~  <tr><td align=let>
						<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_assay&ShowEntryForm=1">Add a Stain</A></td></tr>~;
#stain
					foreach my $stain (keys %{$stainHash{$antibodyKey}->{$species}})
					{
							my $stainID = $stainIdHash{$stain};
							print "<tr><ul><td align=left><b><li>Stain</b></td></tr>";
							print qq~ <tr><TD NOWRAP align=left>- <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?action=_processStain&stained_slide_id=$stainID">$stain</A></TD></tr>~;
							print "</li>";
#channel							
							if ($stainHash{$antibodyKey}->{$species}->{$stain})
							{
								
								my $number = scalar (keys(%{$stainHash{$antibodyKey}->{$species}->{$stain}}));
								$number ++;
								print "<tr><td align=center><b><li>Channel</b></td></tr>";
								print qq~<tr><td align=center><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_assay_channel&assay_id=$stainID&channel_index=$number&antibody_id=$antibodyID&ShowEntryForm=1"> Add a Channel</A></td></tr>~;
							    %hash_to_sort = %{$stainHash{$antibodyKey}->{$species}->{$stain}};
								my $channelString ='';
								my $imageString = '';
								foreach my $channel (sort bySortOrder keys %{$stainHash{$antibodyKey}->{$species}->{$stain}})			
								{
									my $channelId = $channelHash{$channel};
									print qq~ <tr><TD NOWRAP align=center>- <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_assay_channel&assay_channel_id=$channelId&ShowEntryForm=1">$channel</A></TD>~;
									print "</li>";
#images									
									if ($stainHash{$antibodyKey}->{$species}->{$stain}->{$channel})
									{
										print  "<tr><td align=right><b><li>Images</b></td></tr>";
										print qq~ <tr><td align=right><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_assay_image&assay_channel_id=$channelId&ShowEntryForm=1"> Add an Image</A></td></tr>~;
							 			foreach my $image (sort bySortOrder keys %{$stainHash{$antibodyKey}->{$species}->{$stain}->{$channel}})
										{
											my $magnification = $stainHash{$antibodyKey}->{$species}->{$stain}->{$channel}->{$image};
											my $imageID = $imageIdHash{$image};
											my $flag = $imageProcessedHash{$image};
											$imageString .=  "  - <A HREF= \"$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_assay_image&assay_image_id=$imageID&GetFile=$flag\" TARGET=image> $magnification x&nbsp\;&nbsp\<\/A>" if $imageID;
										}
										print "<TD align =right colspan=2>$imageString</td>";
										print "</tr></li></ul>";
									}
								}
							}
						}
				}
		}
	print "</table>";
	}
}


sub processStain
{

	my %args = @_;
#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
	my %resultset = ();
  my $resultset_ref = \%resultset;
	
	my (%cellHash,%stainHash,%percentHash);
=comment
	foreach my $key (keys %parameters)
	{
			print " $key ---- $parameters{$key}<br>";
	}
=cut

#which stains to display
	my $includeClause = $parameters{stained_slide_id};
	$includeClause = 'all' if !$includeClause;
	if ($includeClause eq 'all')
	{ 
			$includeClause = $parameters{selection};
	}
	
	my $query = "Select
	sbo.organism_name,
	tt.tissue_type_name, tt.tissue_type_description, 
	sp.surgical_procedure_name, sp.surgical_procedure_description,
	cd.clinical_diagnosis_name, clinical_diagnosis_description,
	s.specimen_name, s.specimen_id, 
	sb.specimen_block_name, sb.specimen_block_level,sb.anterior_posterior,sb.specimen_block_side,sb.specimen_block_id,
	ss.assay_name,ss.assay_id,ss.cancer_amount_cc,ss.preparation_date,
	si.image_name,si.assay_image_id,si.image_magnification,si.raw_image_file, si.processed_image_file,
	a.antibody_name, a.antibody_id, 
	an.antigen_name, an.alternate_names,
	scp.at_level_percent,
	ct.structural_unit_name,ct.structural_unit_id,
	cpl.level_name
	from $TBIS_ASSAY ss
	left join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id
	left join $TBIS_SPECIMEN s on sb.specimen_id = s.specimen_id
	left join $TBIS_TISSUE_TYPE tt on s.tissue_type_id = tt.tissue_type_id
	left join $TBIS_SURGICAL_PROCEDURE sp on s.surgical_procedure_term_id = sp.surgical_procedure_id
	left join $TBIS_CLINICAL_DIAGNOSIS cd on s.clinical_diagnosis_term_id = cd.clinical_diagnosis_id
	left join $TBIS_ASSAY_CHANNEL ac on ss.assay_id = ac.assay_id
	left join $TBIS_ASSAY_IMAGE si on ac.assay_channel_id  = si.assay_channel_id 
	left join $TBIS_ANTIBODY a on ac.antibody_id = a.antibody_id
	left join $TBIS_ASSAY_UNIT_EXPRESSION  scp on ac.assay_channel_id = scp.assay_channel_id
	left join $TBIS_STRUCTURAL_UNIT ct on scp.structural_unit_id = ct.structural_unit_id
	left join $TBIS_EXPRESSION_LEVEL cpl on scp.expression_level_id = cpl.expression_level_id
	left join $TBIS_ANTIGEN an on a.antigen_id = an.antigen_id
	left join $TB_ORGANISM sbo on s.organism_id = sbo.organism_id 
	where ss.assay_id in ($includeClause) order by sbo.sort_order, ct.sort_order,a.sort_order";

	my @rows = $sbeams->selectSeveralColumns($query);
  
print "<tr><td></td><td align=center><H4><font color=\"red\">Stain Summary</font></center></H4></td></tr><tr><td></td><td align=center><A Href=\"$CGI_BASE_DIR\/$SBEAMS_SUBDIR\/main.cgi\">Back to Main Page <\/A></td></tr>"; 
#	arrange the data in a result set we can easily use
	if (scalar(@rows) < 1)
	{
		print "<tr></tr><tr></tr><TD align=center><b>No Data available for this Stain </b></TD></TR>";
	}
	else
	{
			my (%stainDateHash,%stainOrganismHash,%stainIdHash,%stainAntibodyHash,%antibodyHash,%stainSpecimenHash,%specimenHash,%stainSpecimenBlockHash,
			%specimenBlockHash,%stainImageHash,%imageHash,%imageFlagHash,%stainCellHash,%stainTissueHash,
			%stainTissueHash,%antibodyAntigenHash, %organismStainHash,%cellTypeHash);
			
			
			foreach my $row (@rows)
			{			
					my($organismName,$tissueName,$tissueDesc,
					$surgicalProc,$surgicalDesc,
					$clinicalName, $clinicalDesc,
					$specimenName,$specimenId,
					$specimenBlock, $specimenLevel,$specimenAP, $specimenSide,$specimenBlockId,
					$stainName, $stainId, $cancerCC,$prepDate,
					$imageName,$imageId, $imageMag, $imageRaw, $imageProcessed,
					$antibody, $antibodyId,
					$antigen, $antigenAlternate,
					$levelPercent,
					$cellType,$cellTypeId,
					$level) = @{$row};
					$prepDate =~ s/^(\d{4}-\d{2}-\d{2}).*$/$1/;
					$cancerCC =~ s/^(\d?\.\d\d?).*$/$1/;
					
=comment				
					print "<b>a $organismName<br>b $tissueName<br>,c $tissueDesc<br>,
					d $surgicalProc<br>,e $surgicalDesc,<br>
					f $clinicalName<br>, g $clinicalDesc<br>,
					h $specimenName<br>i ,$specimenId<br>,
				j	$specimenBlock<br>,k  $specimenLevel<br>, l $specimenAP<br>, m $specimenSide<br>,n $specimenBlockId<br>,
					o  $stainName<br>,p  $stainId<br>, q $cancerCC<br>r ,$prepDate<br>,
				s 	$imageName<br>t ,$imageId<br>,v  $imageMag<br>,w  $imageRaw<br>, x $imageProcessed<br>,
				y 	$antibody<br>,z $antibodyId<br>,
				aa 	$antigen<br>,bb $antigenAlternate<br>,
				cc 	$levelPercent<br>,
				dd 	$cellType<br>,
				ee	$level<br></b>";
=cut					
#all about the oraganism
					$organismStainHash{$organismName}->{$stainName} = 1;

#all about the stain
					$stainDateHash{$stainName}= $prepDate;
					$stainOrganismHash{$stainName} = $organismName;
					$stainIdHash{$stainName} = $stainId;
					$stainTissueHash{$stainName} = $tissueName;
#all about the antibody 					
					$stainAntibodyHash{$stainName}->{$antibody}->{$antigen} = $antigenAlternate;
					$antibodyHash{$antibody} = $antibodyId;
					$antibodyAntigenHash{$antibody}= $antigen;
#all about the specimen
					unless (! $specimenName)
					{	
						$surgicalProc =~ s/(\?)/: /;	
						$stainSpecimenHash{$stainName}->{$specimenName}->{$tissueName}->{presence} = 1;	
						$stainSpecimenHash{$stainName}->{$specimenName}->{$tissueName}->{diagnosis} = $clinicalName  if $clinicalName;
						$stainSpecimenHash{$stainName}->{$specimenName}->{$tissueName}->{diagnosisDesc} = $clinicalDesc if $clinicalDesc;
						$stainSpecimenHash{$stainName}->{$specimenName}->{$tissueName}->{surgical} = $surgicalProc if $surgicalProc;
						$stainSpecimenHash{$stainName}->{$specimenName}->{$tissueName}->{surgicalDesc} = $surgicalDesc if $surgicalDesc;
						$stainSpecimenHash{$stainName}->{$specimenName}->{$tissueName}->{tissueDesc} = $tissueDesc if $tissueDesc;
						$stainSpecimenHash{$stainName}->{$specimenName}->{$tissueName}->{cancerCC} = $cancerCC if $cancerCC;
						$specimenHash{$specimenName}=$specimenId;
						$stainTissueHash{$specimenName} = $tissueName;
					}
#all about the specimenBlock
					if ( $specimenBlock)
					{
						
						$stainSpecimenBlockHash{$stainName}->{$specimenBlock}->{presence} = 1;	
						$specimenAP =~ /a/i?$specimenAP = 'Anterior':$specimenAP='Posterior' if $specimenAP;	
						$specimenSide =~/r/i?$specimenSide='Right':$specimenSide='Left' if($specimenSide); 
						$stainSpecimenBlockHash{$stainName}->{$specimenBlock}->{level} = $specimenLevel if $specimenLevel;
						$stainSpecimenBlockHash{$stainName}->{$specimenBlock}->{laterality} = $specimenAP if $specimenAP;
						$stainSpecimenBlockHash{$stainName}->{$specimenBlock}->{side} = $specimenSide if $specimenSide;
						$specimenBlockHash{$specimenBlock} = $specimenBlockId;
					}
#all about the images
					unless (! $imageName)
					{
							my $imageProcessedFlag = 'raw_image_file';
							$imageProcessedFlag = 'processed_image_file' if  $imageProcessed;
							$stainImageHash{$stainName}->{$imageName} = $imageMag;
							$imageHash{$imageName} = $imageId; 
							$imageFlagHash{$imageName} = $imageProcessedFlag;
					}
					
					if ($cellType)
					{
							$level = lc($level);
							$stainCellHash{$stainName}->{$cellType}->{intense} = $levelPercent if $level eq 'intense';
							$stainCellHash{$stainName}->{$cellType}->{equivocal} = $levelPercent if $level eq 'equivocal';
							$stainCellHash{$stainName}->{$cellType}->{none} = $levelPercent if $level eq 'none';
							$cellTypeHash{$cellType}=$cellTypeId;
					}
					
			}
#"<tr></tr><tr></tr><tr></tr><tr><td align=left><font color =\"#D60000\"><h5>$antibodyKey
				
				my $what = "Mouse";
				my $loopCount = 0;
				LOOP:						
				%hash_to_sort = %stainSpecimenHash;
				foreach my $keyStain (sort bySortOrder keys %stainSpecimenHash)
				{
						next if $stainOrganismHash{$keyStain} eq $what;
						print "</td><tr></tr><tr></tr><tr></tr><tr><td align=left><font color =\"D60000\">&nbsp;&nbsp;&nbsp;<h5>$keyStain</h5></font></td></tr>";
						print "<tr><td align=left><b>Species:</b></td><td align=left>&nbsp;&nbsp;&nbsp;$stainOrganismHash{$keyStain}</td></tr>";
						print "<tr><td align=left><b>Tissue Type:</b></td><td align=left>&nbsp;&nbsp;&nbsp; $stainTissueHash{$keyStain}</td></tr>";
						print "<tr><td align=left><b>PreparationDate:</b></td><td align=left>&nbsp;&nbsp;&nbsp;$stainDateHash{$keyStain}</td></tr>";
						print "<tr><td align=left><b>Antibody:</b></td>";
						my $antibodyName;
						%hash_to_sort =  %{$stainAntibodyHash{$keyStain}} if $stainAntibodyHash{$keyStain};
						foreach my $antibodyKey (sort bySortOrder keys %{$stainAntibodyHash{$keyStain}})
						{
								$antibodyName = $antibodyKey;
								print qq~ <td align=left>&nbsp;&nbsp;&nbsp;<A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?action=_processAntibody&antibody_id=$antibodyHash{$antibodyKey}">$antibodyKey</A></td><tr>
								<td align=left><b>Antigen Alternate Names:</b></td><td>&nbsp;&nbsp;&nbsp;
								$stainAntibodyHash{$keyStain}->{$antibodyKey}->{$antibodyAntigenHash{$antibodyKey}}</td></tr> ~;
						
						}
						foreach my $specimenKey (keys %{$stainSpecimenHash{$keyStain}})
						{
								print qq~ <tr><td align=left><b>Specimen Name:</b></td><td>&nbsp;&nbsp;&nbsp;<A HREF= "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_specimen&specimen_id=$specimenHash{$specimenKey}"</A>$specimenKey</td></tr>~;
								
								foreach my $tissueKey(keys %{$stainSpecimenHash{$keyStain}->{$specimenKey}})
								{
									if ($stainTissueHash{$keyStain} =~ /prostate/i)
									{
										my $record = $stainSpecimenHash{$keyStain}->{$specimenKey}->{$tissueKey};	
										print "<tr><td align=left><b>Tissue Name:</b></td><td>&nbsp;&nbsp;&nbsp;$tissueKey</td><td><b>Tissue Desc:</b></td><td align=center>&nbsp;&nbsp;&nbsp;$record->{tissueDesc}</td></tr>";
										print "<tr><td align=left><b>Clinical Diagnosis:</b></td><td>&nbsp;&nbsp;&nbsp;$record->{diagnosis}</td>";
										print "<td><b>Diagnosis Desc</b></td><td align=center>&nbsp;&nbsp;&nbsp;$record->{diagnosisDesc}</td>" unless ($record->{diagnosisDesc}=~/please describe/i or !($record->{diagnosisDesc}));;
										print "</tr>";
										print "<tr><td align=left><b>Surgical Procedure:</b></td><td>&nbsp;&nbsp;&nbsp;$record->{surgical}</td>";
										print "<td><b>Surgical Desc:</b></td><td align=center>&nbsp;&nbsp;&nbsp;$record->{surgicalDesc}</td>" unless ($record->{surgicalDesc} =~/please describe/i or !($record->{surgicalDesc}));		
										print "</tr>";
										print "<tr><td align=left><b>Amount of Cancer:</b></td><td>&nbsp;&nbsp;&nbsp;$record->{cancerCC} cc</td> </tr>" if $record->{cancerCC};
									}
									else 
									{
										print "<tr><td></td></tr>";
									}
								}
						}	
						
			
				if ( $stainSpecimenBlockHash{$keyStain})
				{
					if ($stainTissueHash{$keyStain}=~ /prostate/i)
					{
							print qq~ <tr><td align=left><b>SpecimenBlock:</B></td>
						<td align=left><b>Name</b></td>~;
						print q~ <td align=center><B>Level</B></td><td align=center><b>Laterality</b></td>
						<td align=center><b>Side</b></td> ~ if $stainTissueHash{$keyStain} !~ /bladder/i;
						print "</tr>";
						
						foreach my $specimenBlockKey (keys %{$stainSpecimenBlockHash{$keyStain}})
						{
								print qq~<tr><td></td><td>&nbsp;&nbsp;&nbsp;<A HREF= "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_specimen_block&specimen_block_id=$specimenBlockHash{$specimenBlockKey}"</A>$specimenBlockKey</td>~;
								print qq~<td align=center>$stainSpecimenBlockHash{$keyStain}->{$specimenBlockKey}->{level}</td>
											   <td align=center>$stainSpecimenBlockHash{$keyStain}->{$specimenBlockKey}->{laterality}</td>
												 <td align=center>$stainSpecimenBlockHash{$keyStain}->{$specimenBlockKey}->{side}</td></tr>~;
						}
					}
					else 
					{
						print "<tr><td width =350> </td></tr>";
					}
					
				}	
				
				print "<tr><td align=left><b>Available Images:</b></td>" if $stainImageHash{$keyStain};
				my $line = 1;
				%hash_to_sort = %{$stainImageHash{$keyStain}} if $stainImageHash{$keyStain};
						foreach my $imageKey (sort bySortOrder keys %{$stainImageHash{$keyStain}})
						{ 
								my $magnification = $stainImageHash{$keyStain}->{$imageKey};
								my $flag = $imageFlagHash{$imageKey};
								my $imageID = $imageHash{$imageKey};
								print "<tr><td></td>" if $line != 1;
								print qq~ <td width=200>&nbsp;&nbsp;&nbsp;$imageKey</td><td>&nbsp;&nbsp;&nbsp;<A HREF ="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_assay_image&assay_image_id=$imageID&GetFile=$flag"TARGET=image>$magnification x </A></td></tr>~;
								$line ++;
						}
						
						print qq~  <tr><td align=left><b>Cell Type Characterization:</b></td></tr><tr></tr>
						<td></td><td align=left><b>Cell Type</b></td><td align=center><b>Intense</b></td><td align=center><b>Equivocal</b></td><td align=center><b>None</b></td></tr><tr></tr>~ if $stainCellHash{$keyStain};
						%hash_to_sort = %{$stainCellHash{$keyStain}} if $stainCellHash{$keyStain};

						foreach my $cellKey (sort bySortOrder keys %{$stainCellHash{$keyStain}})
						{
							my $cellId = $cellTypeHash{$cellKey};
							my $antiId = $antibodyHash{$antibodyName};
							my $redirectURL = qq~$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&structural_unit_id=~;
							my $queryString = "$cellId&antibody_id=$antiId&display_options=MergeLevelsAndPivotCellTypes";
							my $record = $stainCellHash{$keyStain}->{$cellKey};	
							print "<tr><td></td><td align=left><A HREF=$redirectURL$queryString>
							$cellKey</A></td><td align=center>$record->{intense}</td><td align=center>$record->{equivocal}</td><td align=center>$record->{none}</td></tr>";	
						}		
				}
#this is a hack 
#as number of stains increased I decided to sort by organism without wanting to change much code
				$loopCount++;
				$what = "Human";
				goto LOOP if $loopCount ==1;
		}		
	
}

#when processing the cell type, the user is redirected to SummarizeStains
sub processCells
{
		

		
	my %args = @_;
#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
	my %resultset = ();
  my $resultset_ref = \%resultset;
	
	my $includeClause = $parameters{cell_type_id};
	$includeClause = 'all' if !$includeClause;
	if ($includeClause eq 'all')
	{ 
				 
			$parameters{cell_type_id} = $parameters{selection};
	}

	my $celltypeId = $parameters{cell_type_id};
	my $redirectURL = qq~$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&structural_unit_id=~;
	my $queryString = "$celltypeId&display_options=MergeLevelsAndPivotCellTypes";
	
  print $q->redirect($redirectURL.$queryString);
}



#cubersome routine to build the sqlClause
#always get the organism_id from sbo since it is the pk(sbeam.dbo.organism)
#always get the tissue_type_id from tt since it is the pk(tissue_type)
sub buildSqlClause
{
	my %args = @_;
#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
	my %resultset = ();
  my $resultset_ref = \%resultset;

	
	my $oString =  join ',',$parameters{Human},$parameters{Mouse};
	$oString =~ s/^\,//;
	$oString =~ s/\,$//;
	$oString = qq~ sbo.organism_id in (~.$oString.")" if ($oString);
	
	
	my $tString =  join ',',$parameters{Bladder},$parameters{'NProstate'};
	$tString =~ s/^\,//;
	$tString =~ s/\,$//;
	$tString = qq ~tt.tissue_type_id in (~.$tString .")" if ($tString);
	
	my $totalClause;	
	$totalClause = $oString if $oString;
	$totalClause = $tString if $tString;
	$totalClause = $oString ." and ". $tString if ($oString and $tString);
	
	return $totalClause;
}
	
#javascript stuff	
sub checkGO
{
#making sure an option is checked	
	print q~ <script language=javascript type="text/javascript"> ~;
	print <<CHECK;
	function checkForm()
	{
			var Prostate = "Normal Prostate";
			
			if ((document.forms[3].Human.checked)||(document.forms[3].Mouse.checked)||(document.forms[3].NProstate.checked)||(document.forms[3].Bladder.checked))
			{
					return true;
			}
			alert ("ERROR: You need to specify at least one Option" );
			return false;
			
		
	}
CHECK
#disbaling query button
	print <<QUERY;
	
	function disableQuery()
	{
			document.forms[5].SUBMIT3.disabled = true;
	}
QUERY
print "<\/script>";
	
}		

#sorting the Hashes
sub bySortOrder {

  #### First sort by the value
  if ($hash_to_sort{$a} <=> $hash_to_sort{$b})
	{
	    return $hash_to_sort{$a} <=> $hash_to_sort{$b};

  #### And if those are equal, sort by key
  }
	else 
	{
    return $a cmp $b;
  }
}
