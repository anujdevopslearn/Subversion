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


my $START = '_start';
my $ERROR = '_error';
my $ANTIBODY = '_processAntibody';
my $STAIN = '_processStain';
my $CELL = '_processCells';
my (%indexHash,%editorHash);
#possible actions (pages) displayed
my %actionHash = (
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
  exit unless ($current_username = $sbeams->Authenticate(
    permitted_work_groups_ref=>['Immunostain_user','Immunostain_admin',
      'Immunostain_readonly','Admin'],
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
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
  # Some action
		processCells(ref_parameters=>\%parameters);
	}
	else
	{
    $sbeamsMOD->display_page_header();
    handle_request(ref_parameters=>\%parameters);  
    $sbeamsMOD->display_page_footer();
  }


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


  #### Show current user context information
  $sbeams->printUserContext();
  $current_contact_id = $sbeams->getCurrent_contact_id();


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

  #### Print out some information about this project
  print qq~
	<H1>Current Project: <A class="h1" HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">$project_name</A></H1>
	<TABLE WIDTH="100%" BORDER=0>
	<TR><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	             <TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Project Tag:</B> $project_tag</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Owner:</B> $PI_name</TD></TR>
	<TR><TD></TD><TD COLSPAN="2"><B>Access Privileges:</B> <A HREF="$CGI_BASE_DIR/ManageProjectPrivileges">[View/Edit]</A></TD></TR>
	<TR><TD></TD><TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	                 <TD WIDTH="100%"><TABLE BORDER=0>
  ~;

	
  #### If the current user is not the owner, the check that the
  #### user has privilege to access this project
  if ($project_id > 0) {

    my $best_permission = $sbeams->get_best_permission();

    #### If not at least data_reader, set project_id to a bad value
    $project_id = -99 unless ($best_permission > 0 && $best_permission <=40);

  }
	my $antibodyOption;
	my $stainOption;
	my $cellOption;
  #### Get all the experiments for this project
  if ($project_id > 0)
	{
			my $action = $parameters{'action'};
#loading the default page (start)
			my $sub = $actionHash{$action} || $actionHash{$START};
			if ($sub)
			{
					&$sub (ref_parameters=>\%parameters);
			}
			else
			{
					print_fatal_error("Could not find the specified routine: $sub");
			}
	}
	
	 else {
    if ($project_id == -99) {
      print "	<TR><TD WIDTH=\"100%\">You do not have access to this project.  Contact the owner of this project if you want to have access.</TD></TR>\n";
    } else {
      print "	<TR><TD WIDTH=\"100%\">NONE</TD></TR>\n";
    }
  }
}

  #### Finish the table
	
	
			
sub displayMain
{
		my $antibodyOption;
		my $stainOption;
		my $cellOption;
    my $sql = qq~
		select sp.specimen_id, ss.stained_slide_id ,si.slide_image_id,sbo.organism_name 
		from $TBIS_STAINED_SLIDE ss
		left join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id
		left join $TBIS_SPECIMEN sp on sb.specimen_id = sp.specimen_id
		left join sbeams.dbo.organism sbo on sp.organism_id = sbo.organism_id
		left join $TBIS_SLIDE_IMAGE si on ss.stained_slide_id = si.stained_slide_id 
		order by ORGANisM_NAME 
		~;	
    my @rows = $sbeams->selectSeveralColumns($sql);
		$antibodyOption = $sbeams->buildOptionList("Select antibody_id, antibody_name from $TBIS_ANTIBODY order by sort_order", "sELECTED","MULTIOPTIONLIST");
		$stainOption = $sbeams->buildOptionList("Select stained_slide_id, stain_name from $TBIS_STAINED_SLIDE order by stain_name", "Selected","MULTIOPTIONLIST");
		$cellOption = $sbeams->buildOptionList("Select cell_type_id,cell_type_name from $TBIS_CELL_TYPE order by sort_order", "Selected","MULTIOPTIONLIST");
 
	
  #### If there are experiments, display them
 	my (%hash,%stainedSlideHash,%imageHash);
	my (@specList,@slideList,@imageList);

	if (@rows)
	{
    foreach my $row (@rows)
		{
			my ($specimenID,$stainedSlideID,$slideImageID,$organismName) = @{$row};
			
			$hash{$organismName}->{'specimenID'}++ if $specimenID and !scalar(grep /$specimenID/ ,@specList);
			$hash{$organismName}->{stainID}++ if $stainedSlideID and !scalar(grep /$stainedSlideID/ ,@slideList);
			$hash{$organismName}->{imageID}++ if $slideImageID and !scalar(grep /$slideImageID/ ,@imageList);
			 
			push @specList, $specimenID;
			push @slideList, $stainedSlideID;
			push @imageList, $slideImageID;
			
		}
		

		print qq *
		<tr></tr><tr></tr>
		<td><H4>Project Name: UESC </H4></td></tr><tr>
		*; 
		foreach my $key (sort keys %hash)
		{
			
			print qq~
			<td><b>$key</b></td></tr>
			<tr><td>Total Number of Specimens: $hash{$key}->{specimenID}</td></tr>
			<tr><td>Total Number of Stains: $hash{$key}->{stainID}</td></tr>
			<tr><td>Total Number of Images: $hash{$key}->{imageID}</td></tr>
			<tr></tr><tr></tr>
      ~;
		}

		print $q->start_form;
		print qq~ <TR><TD NOWRAP>Summarized Data keyed on  Antibody: </TD><td align=center><Select Name="antibody_id" Size=6 Multiple> <OPTION VALUE = "all">ALL ~;
		print "$antibodyOption";
		print q~</td><td><td><input type ="submit" name= "SUBMIT" value = "QUERY"></td>~;
		print "<input type= hidden name=\"action\" value = \"$ANTIBODY\">";
		print $q->end_form;
		print $q->start_form;
		print qq~ <tr></tr><TR><TD NOWRAP>Summarized Data keyed on Stains: </TD><td align=center><Select Name="stained_slide_id" Size=6 Multiple> <OPTION VALUE = "all">ALL ~;
		print "$stainOption";
		print q~</td><td><td><input type ="submit" name= "SUBMIT" value = "QUERY"></td>~;
		print "<input type= hidden name=\"action\" value = \"$STAIN\">";
		print $q->end_form;
		print $q->start_form;
		print qq~ <tr></tr><TR><TD NOWRAP>Summarized Data keyed on CellType: </TD><td align=center><Select Name="cell_type_id" Size=6 Multiple> <OPTION VALUE = "all">ALL ~;
		print "$cellOption";
		print q~</td><td><td><input type ="submit" name= "SUBMIT" value = "QUERY"></td> ~;
		print " <input type= hidden name=\"action\" value =\"$CELL\">";		
		print $q->end_form;
	#	(under development)</TD></TR>
	#<TR><TD NOWRAP>Summarize Stains</A> (under devlopment)</TD></TR>
	#^;    
	
	
  } 
	else
	{
			@rows = (); 
  }


  #### Finish the table
  print qq~
	</TABLE></TD></TR>
	</TABLE>
  ~;



  ##########################################################################
  #### Print out all projects owned by the user
  $sbeams->printProjectsYouOwn();



  ##########################################################################
  #### Print out all projects user has access to
  $sbeams->printProjectsYouHaveAccessTo();


  ##########################################################################
  #### Print out some recent resultsets
  $sbeams->printRecentResultsets();



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

sub processAntibody
{

	my %args = @_;
#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
	my %resultset = ();
  my $resultset_ref = \%resultset;
	
	my $includeClause = $parameters{antibody_id};
	if ($includeClause eq 'all')
	{ 
			$includeClause = "Select antibody_id from $TBIS_ANTIBODY";
	}
	
	my $query = "select ab.antibody_name,ab.antibody_id,
	ss.stain_name,
	ss.stained_slide_id,
	cell_type_name, ct.cell_type_id,ct.sort_order,
	level_name,
	at_level_percent,
	si.slide_image_id,
	si.raw_image_file,
	si.processed_image_file,
	si.image_magnification,
	sbo.organism_name
	from $TBIS_STAINED_SLIDE ss
	left join $TBIS_ANTIBODY ab on ss.antibody_id = ab.antibody_id
	left join $TBIS_STAIN_CELL_PRESENCE scp on ss.stained_slide_id = scp.stained_slide_id
	left join $TBIS_CELL_PRESENCE_LEVEL cpl on scp.cell_presence_level_id = cpl.cell_presence_level_id 
	left join $TBIS_CELL_TYPE ct on scp.cell_type_id = ct.cell_type_id
	left join $TBIS_SLIDE_IMAGE si on ss.stained_slide_id = si.stained_slide_id
	left join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id
	left join $TBIS_SPECIMEN s on sb.specimen_id = s.specimen_id 
	left join sbeams.dbo.organism sbo on s.organism_id = sbo.organism_id
	where ab.antibody_id  in ( $includeClause ) order by ab.sort_order, ct.sort_order";
	


	$sbeams->fetchResultSet(sql_query=>$query,resultset_ref=>$resultset_ref,);
    
	my $columHashRef = $resultset_ref->{column_hash_ref};
  my $dataArrayRef = $resultset_ref->{data_ref};
  my ($count, $prevStainedSlideId,$indexCounter) = 0;
	my (%stainHash,%cellHash,%stainIdHash,%imageIdHash, %imageProcessedHash,%percentHash,%countHash,,%antibodyHash, %cellTypeHash);
	my ($prevStain,$prevAntibody);
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
		my $stainNameIndex = 	$resultset_ref->{column_hash_ref}->{stain_name};
		my $stainedSlideIdIndex = 	$resultset_ref->{column_hash_ref}->{stained_slide_id};
		my $cellNameIndex = 	$resultset_ref->{column_hash_ref}->{cell_type_name};
		my $cellNameIdIndex = 	$resultset_ref->{column_hash_ref}->{cell_type_id};
		my $levelIndex = 	$resultset_ref->{column_hash_ref}->{level_name};
		my $levelPercentIndex = 	$resultset_ref->{column_hash_ref}->{at_level_percent};
		my $slideImageIdIndex = $resultset_ref->{column_hash_ref}->{slide_image_id};
		my $rawImageFileIndex = $resultset_ref->{column_hash_ref}->{raw_image_file};
		my $processedImageFileIndex  =  $resultset_ref->{column_hash_ref}->{processed_image_file};
		my $magnificationIndex = $resultset_ref->{column_hash_ref}->{image_magnification};
		my $organismNameIndex =  $resultset_ref->{column_hash_ref}->{organism_name};
		my $stainCount = 0;
		for (@{$resultset_ref->{data_ref}})
		{
	  		my @row = @{$resultset_ref->{data_ref}[$indexCounter]};
				my $antibody = $row[$antibodyIndex];
				my $stainName = $row[$stainNameIndex];
				my $stainedSlideId = $row[$stainedSlideIdIndex];
				my $cellType = $row[$cellNameIndex];
				my $level = lc($row[$levelIndex]);
				my $atLevelPercent = $row[$levelPercentIndex];
				my $organismName = $row[$organismNameIndex];
				my $cellTypeId = $row[$cellNameIdIndex];
#count number of Stains for an antibody
				$stainCount++ if $prevStain ne $stainName and $prevAntibody eq $antibody;
#get all the images for a Stain
				my $imageProcessedFlag = 'raw_image_file';
				my $imageName = $row[$rawImageFileIndex];
				$imageName = $row[$processedImageFileIndex] if $row[$processedImageFileIndex];
				$imageProcessedFlag = 'processed_image_file' if  $row[$processedImageFileIndex];
				$stainHash{$antibody}->{$organismName}->{$stainName}->{$imageName} = $row[$magnificationIndex];		
				$countHash{$antibody}++ if !$stainIdHash{$stainName};
				$stainIdHash{$stainName} = $stainedSlideId;
				$imageIdHash{$imageName} = $row[$slideImageIdIndex] if $imageName;
				$imageProcessedHash{$imageName} = $imageProcessedFlag;
				
				
				
				
#get all the cell types and the number of the stains available per intensity level per celltype per antibody
#this is the number of instances a cell type stains at a certain level
				$cellHash{$antibody}->{$cellType}->{$level}++ if $cellType;
		  
#get the average percent of staining per celltype per level
#number of total percent level of intensity (at this level) for a celltype/total number of available stains		

				$percentHash{$antibody}->{$cellType}->{intense} +=	$atLevelPercent if $row[$levelIndex] eq 'intense';			
				$percentHash{$antibody}->{$cellType}->{equivocal} += $atLevelPercent if $row[$levelIndex] eq 'equivocal'; 	
				$percentHash{$antibody}->{$cellType}->{none} += $atLevelPercent if $row[$levelIndex] eq 'none';
				$cellTypeHash{$cellType} = $row[$cellNameIdIndex];
				$antibodyHash{$antibody} = $row[$antibodyIdIndex];
				$indexCounter ++;
				$prevStain = $stainName;
				$prevAntibody = $antibody;
		}	
		

		
			
#no info for this antibody
#	print "<tr><td align=left><b>$value :</b></TD></tr><tr></tr><tr></tr><tr><td>Total Number of Stains: </td>";
#	print "<TD align=center> No Stains available for this Antibody</TD></TR>";
	
#have some results for this antibody
#count how many experiments, detailed info about staining pattern and print out the stain images


		
	 %hash_to_sort = %stainHash;	
		foreach my $antibodyKey (sort bySortOrder keys %stainHash)
		{

			print "<tr></tr><tr></tr><tr></tr><tr><td align=left><font color =\"#D60000\"><h5>$antibodyKey</h5></font></TD><tr><td><b>Total Number of Stains:</b> </td>";
			print "<td align=center>$countHash{$antibodyKey}</td></tr><tr></tr>";
			print "<tr><td align=left><b>Staining Summmary:</b></td></tr>";
			print qq~ <tr><td></td><td align=center colspan=3><b>Average Percentage</b></td><td>&nbsp;&nbsp;&nbsp;</td><td align=center colspan=3><b>Number of charaterized Stains</b></td></tr>
			<tr><td align = left> Cell Type </td><td align=center>Intense</td><td align=center> Equivocal </td><td align=center> None </td></tr> ~if $cellHash{$antibodyKey};
			
			%hash_to_sort = %{$cellHash{$antibodyKey}} if $cellHash{$antibodyKey};
			foreach my $cell (sort bySortOrder keys %{$cellHash{$antibodyKey}})
			{   
					my $percentIntense = $percentHash{$antibodyKey}->{$cell}->{'intense'}/$cellHash{$antibodyKey}->{$cell}->{intense} if $cellHash{$antibodyKey}->{$cell}->{intense};
					my $percentEquivocal = $percentHash{$antibodyKey}->{$cell}->{'equivocal'}/$cellHash{$antibodyKey}->{$cell}->{equivocal} if $cellHash{$antibodyKey}->{$cell}->{equivocal};
					my $percentNone = $percentHash{$antibodyKey}->{$cell}->{'none'}/$cellHash{$antibodyKey}->{$cell}->{none} if $cellHash{$antibodyKey}->{$cell}->{none};
					$percentIntense =~ s/^(.*\.\d{3}).*$/$1/;
					$percentEquivocal =~ s/^(.*\.\d{3}).*$/$1/;
					$percentNone =~ s/^(.*\.\d{3}).*$/$1/;
					
					print "<tr><td align=left><A HREF=\"$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&antibody_id=$antibodyHash{$antibodyKey}&cell_type_id=$cellTypeHash{$cell}&display_options=MergeLevelsAndPivotCellTypes\">$cell</A></td>";
					print "<td align=center>$percentIntense</td><td align=center>$percentEquivocal</td><td align=center>$percentNone</td>";
					print "<td></td><td align=center>$cellHash{$antibodyKey}->{$cell}->{'intense'}</td></tr>";
					#<td align=center>$cellHash{$antibodyKey}->{$cell}->{'equivocal'}</td><td align=center>$cellHash{$antibodyKey}->{$cell}->{'none'}</td>";
					 
			}	
			
			print "<tr></tr><tr></tr><tr><td><b>Individual Stains</b></td><td align=center colspan=4><b>Available Images</b></td></tr><tr></tr>";
			
		foreach my $species (keys %{$stainHash{$antibodyKey}})
			{
					print "<tr><td align=left><b>$species :</b></td></tr><tr></tr>";
					
					foreach my $stain (keys %{$stainHash{$antibodyKey}->{$species}})
					{
							my $stainID = $stainIdHash{$stain};
							print qq~ <tr><TD NOWRAP>- <A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/main.cgi?action=_processStain&stained_slide_id=$stainID">$stain</A></TD>~;
							
							%hash_to_sort = %{$stainHash{$antibodyKey}->{$species}->{$stain}};
							foreach my $image (sort bySortOrder keys %{$stainHash{$antibodyKey}->{$species}->{$stain}})
							{
									my $magnification = $stainHash{$antibodyKey}->{$species}->{$stain}->{$image};
									my $imageID = $imageIdHash{$image};
									my $flag = $imageProcessedHash{$image};
									print qq~ <TD NOWRAP align = center>- <A HREF= "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_slide_image&slide_image_id=$imageID&GetFile=$flag"> $magnification x</A></td>~ if $imageID;  
							}
							print "</tr><tr></tr>";
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

#	foreach my $key (keys %parameters)
#	{
#			print " $key lll $parameters{$key}<br>";
#	}


	my $includeClause = $parameters{stained_slide_id};
	if ($includeClause eq 'all')
	{ 
			$includeClause = "Select stained_slide_id from $TBIS_STAINED_SLIDE";
	}
	
	my $query = "Select
	sbo.organism_name,
	tt.tissue_type_name, tt.tissue_type_description, 
	sp.surgical_procedure_name, sp.surgical_procedure_description,
	cd.clinical_diagnosis_name, clinical_diagnosis_description,
	s.specimen_name, s.specimen_id, 
	sb.specimen_block_name, sb.specimen_block_level,sb.anterior_posterior,sb.specimen_block_side,sb.specimen_block_id,
	ss.stain_name,ss.stained_slide_id,ss.cancer_amount_cc,ss.preparation_date,
	si.image_name,si.slide_image_id,si.image_magnification,si.raw_image_file, si.processed_image_file,
	a.antibody_name, a.antibody_id, 
	an.antigen_name, an.alternate_names,
	scp.at_level_percent,
	ct.cell_type_name,ct.cell_type_id, 
	cpl.level_name
	from $TBIS_STAINED_SLIDE ss
	left join $TBIS_SPECIMEN_BLOCK sb on ss.specimen_block_id = sb.specimen_block_id
	left join $TBIS_SPECIMEN s on sb.specimen_id = s.specimen_id
	left join $TBIS_TISSUE_TYPE tt on s.tissue_type_id = tt.tissue_type_id
	left join $TBIS_SURGICAL_PROCEDURE sp on s.surgical_procedure_id = sp.surgical_procedure_id
	left join $TBIS_CLINICAL_DIAGNOSIS cd on s.clinical_diagnosis_id = cd.clinical_diagnosis_id
	left join $TBIS_SLIDE_IMAGE si on ss.stained_slide_id = si.stained_slide_id 
	left join $TBIS_ANTIBODY a on ss.antibody_id = a.antibody_id
	left join $TBIS_STAIN_CELL_PRESENCE scp on ss.stained_slide_id = scp.stained_slide_id
	left join $TBIS_CELL_TYPE ct on scp.cell_type_id = ct.cell_type_id
	left join $TBIS_CELL_PRESENCE_LEVEL cpl on scp.cell_presence_level_id = cpl.cell_presence_level_id
	left join $TBIS_ANTIGEN an on a.antigen_id = an.antigen_id
	left join sbeams.dbo.organism sbo on s.organism_id = sbo.organism_id 
	where ss.stained_slide_id in ($includeClause) order by sbo.sort_order, ct.sort_order,a.sort_order";

	
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
		#					$stainCE
							$stainCellHash{$stainName}->{$cellType}->{intense} = $levelPercent if $level eq 'intense';
							$stainCellHash{$stainName}->{$cellType}->{equivocal} = $levelPercent if $level eq 'equivocal';
							$stainCellHash{$stainName}->{$cellType}->{none} = $levelPercent if $level eq 'none';
							$cellTypeHash{$cellType}=$cellTypeId;
					}
					
			}
#"<tr></tr><tr></tr><tr></tr><tr><td align=left><font color =\"#D60000\"><h5>$antibodyKey
#				print "<table><tr>\n";
				my $what = "Mouse";
				my $loopCount = 0;
				LOOP:						
				%hash_to_sort = %stainSpecimenHash;
				foreach my $keyStain (sort bySortOrder keys %stainSpecimenHash)
				{
						next if $stainOrganismHash{$keyStain} eq $what;
						print "<tr></tr><tr></tr><tr></tr><tr><td align=left><font color =\"D60000\">&nbsp;&nbsp;&nbsp;<h5>$keyStain</h5></font></td></tr>";
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
						}	
						
			
				if ( $stainSpecimenBlockHash{$keyStain})
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
				
				print "<tr><td align=left><b>Available Images:</b></td>" if $stainImageHash{$keyStain};
				my $line = 1;
				%hash_to_sort = %{$stainImageHash{$keyStain}} if $stainImageHash{$keyStain};
						foreach my $imageKey (sort bySortOrder keys %{$stainImageHash{$keyStain}})
						{ 
								my $magnification = $stainImageHash{$keyStain}->{$imageKey};
								my $flag = $imageFlagHash{$imageKey};
								my $imageID = $imageHash{$imageKey};
								print "<tr><td></td>" if $line != 1;
								print qq~ <td>&nbsp;&nbsp;&nbsp;$imageKey</td><td>&nbsp;&nbsp;&nbsp;<A HREF ="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=IS_slide_image&slide_image_id=$imageID&GetFile=$flag">$magnification x </A></td></tr>~;
								$line ++;
						}
						
						print qq~  <tr><td align=left><b>Cell Type Characterization:</b></td></tr><tr></tr>
						<td></td><td align=left><b>Cell Type</b></td><td align=center><b>Intense</b></td><td align=center><b>Equivocal</b></td><td align=center><b>None</b></td></tr><tr></tr>~ if $stainCellHash{$keyStain};
						%hash_to_sort = %{$stainCellHash{$keyStain}} if $stainCellHash{$keyStain};


#	my $celltypeId = $parameters{cell_type_id};
#	my $redirectURL = qq~$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&cell_type_id=~;
#	my $queryString = "$celltypeId&display_options=MergeLevelsAndPivotCellTypes";


						foreach my $cellKey (sort bySortOrder keys %{$stainCellHash{$keyStain}})
						{
							my $cellId = $cellTypeHash{$cellKey};
							my $antiId = $antibodyHash{$antibodyName};
							my $redirectURL = qq~$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&cell_type_id=~;
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
	if ($includeClause eq 'all')
	{ 
			$parameters{cell_type_id} ='';
	}

	my $celltypeId = $parameters{cell_type_id};
	my $redirectURL = qq~$CGI_BASE_DIR/$SBEAMS_SUBDIR/SummarizeStains?action=QUERY&cell_type_id=~;
	my $queryString = "$celltypeId&display_options=MergeLevelsAndPivotCellTypes";
#	print "$celltypeId";
	
  print $q->redirect($redirectURL.$queryString);

}

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
