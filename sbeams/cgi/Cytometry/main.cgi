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
# Get the script set up with everything it will need
###############################################################################
use strict;
use Alcyt;
use Text::Wrap;
use Data::Dumper;
use GD::Graph::xypoints;
use vars qw ($q $sbeams $sbeamsMOD $PROGRAM_FILE_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;

use SBEAMS::Cytometry;
use SBEAMS::Cytometry::Settings;
use SBEAMS::Cytometry::Tables;

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::Utilities;

$q   = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Cytometry;
$sbeamsMOD->setSBEAMS($sbeams);


###############################################################################
# Global Variables
###############################################################################
my $VERBOSE;
my $TESTONLY;
$PROGRAM_FILE_NAME = 'main.cgi';

my $INTRO = '_displayIntro';
my $START = '_start';
my $ERROR = '_error';
my $PROCESSFILE = '_processFile';
my $GETGRAPH = '_getGraph';
my $CELL = '_processCells';
my $GETANOTHERGRAPH = '_getAnotherGraph';
my (%indexHash,%editorHash,%inParsParam);
#possible actions (pages) displayed
my %actionHash = (
	$INTRO	=>	\&displayIntro,
	$START	=>	\&displayMain,
	$PROCESSFILE =>	 \&processFile,
	$GETGRAPH 	=>	 \&getGraph,
	$CELL	=>	\&processCells,
	$ERROR	=>	\&processError,
	$GETANOTHERGRAPH =>	\&getAnotherGraph
	);
	my %optionHash = (
		'FLS' => 'fl',
		'RED' => 're',
		'PLS' => 'pl',
		'BLUE' => 'bl',
		'GREEN' => 'gr',
		'pulse width' => 'pw',
		'LOG(FLS)' => 'fl',
		'Hoechst Red' => 're',
		'Hoechst red' => 're',
		'ADC12' => 'aaa',
		'ADC12' => 'bbb',
		'LOG(PLS)' => 'pl',
		'Hoechst Blue' => 'bl',
		'Hoechst blue' => 'bl',
		'xxx' => 'wave',
		'LUT DECISION' => 'lut',
		'CLASS DECISION'  =>'cls',
		'COUNTER' => 'cts',
		'yyy' => 'spec',
		'www' => 'gr',
		'zzz' => 'rate',
		'qqq' => 'time',
		'uuu' => 'event No.' );

	my %indexHash = (
		' event No.'	=>	0,
		time 	=>	1,
		rate	=>	2,
		cls		=>	3,
		cts		=>	4,
		lut		=>	5,
		pw 	=>	6,
		fl		=>	7,
		pl		=>	8,
		wave	=>	9,
		spec	=>	10,
		bl	=>	11,
		gr	=>	12,
		re	=>	13);
		
		my %columnHash = $sbeams->selectTwoColumnHash("Select upper(file_Column),database_column from $TBCY_CONVERSION_DATA");
main();
exit(0);
###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned

    exit unless ($current_username = $sbeams->Authenticate(
      #connect_read_only=>1,
      allow_anonymous_access=>1,
     permitted_work_groups_ref=>['Cytometry_user','Cytometry_admin','Admin'],
   ));

	#### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
#$sbeams->printDebuggingInfo($q);
#### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);
	
    #### Print the header, do what the program does, and print footer
	
	# normal handling for anything else			
	$sbeamsMOD->display_page_header();
	 handle_request(ref_parameters=>\%parameters);  
   $sbeamsMOD->display_page_footer();
  

} # end main


###############################################################################
# Show the main welcome page
###############################################################################

sub handle_request 
{
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
	my $sub = $actionHash{$action} || $actionHash{$INTRO};
#loading the default page (Intro)
#my $sub = $actionHash{$action} || $actionHash{$INTRO};
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
	      <TD WIDTH="80%"><TABLE BORDER=0>
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

####----------------------------------------------------------------------------------
sub displayIntro {

	 my %args = @_;
	 #### get the project id
	 my $project_id = $args{'project_id'} || die "project_id not passed";
	 
	 my $organismSql = qq~ select organism_id,organism_name from 
	 sbeams.dbo.organism ~; 
	
	my %organismHash = $sbeams->selectTwoColumnHash($organismSql);
	
	my $sql = "select  fcs_run_id,Organism_id , project_designator, sample_name, filename, run_date 
	 from $TBCY_FCS_RUN where project_id = $project_id order by project_designator";
  
	 my @rows = $sbeams->selectSeveralColumns($sql);
	 my %hashFile;
	my $count = 1; 
	 if (@rows)
	 {
		print "<br><center><h4> Current Cytometry data for this project</h4></center><br>";
		print "<table border=2>"; 
		foreach my $row(@rows)
		{
			my ($fcsID,$organismID, $projectDes, $sampleName, $fileName, $runDate) = @{$row};
			$runDate =~ s/^(.*?)\s0.*$/$1/;
			my @array;
#		print "$count ==  $projectDes  == $organismID == ,$sampleName == $fileName === $runDate <br>";
			$projectDes = uc($projectDes);
			push @array,( $sampleName, $organismHash{$organismID},$fileName, $runDate);
			
		#	$hashFile{$projectDes}->{$fcsID} = \ @array;
			$hashFile{$projectDes}->{$fcsID}->{'Sample Name'} = $sampleName;
			$hashFile{$projectDes}->{$fcsID}->{Organism} = $organismHash{$organismID};
			$hashFile{$projectDes}->{$fcsID}->{'File Name'} = $fileName;
			$hashFile{$projectDes}->{$fcsID}->{'Run Date'} = $runDate;
			$hashFile{$projectDes}->{$fcsID}->{'Create Graph'} = $fileName;
			
			
			$count++;
		}	
			
		foreach my $key (keys %hashFile)
		{
			print "<tr><td> <b>Project Designator: </b>$key</td></tr>";
			print "<tr><td><b>Sample Name</b></td><td><b>Organism</b></td><td><b>File Name</b></td><td><b>Run Date</b></td><td>Create Graph</td></tr>";
			foreach my $id (keys %{$hashFile{$key}})
			{ 
			print qq ~<tr>
			<td> <a href=$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=CY_fcs_run&fcs_run_id=$id>$hashFile{$key}->{$id}->{'Sample Name'}</td>
			<td>$hashFile{$key}->{$id}->{Organism} </td>
			<td>$hashFile{$key}->{$id}->{'File Name'}</td> 
			<td>$hashFile{$key}->{$id}->{'Run Date'} </td>
			<td><a href=$CGI_BASE_DIR/$SBEAMS_SUBDIR/main2.cgi?action=$PROCESSFILE&fileID=$id > Create Graph</a></td></tr>~;
			}
		}	
	 }
	 
	 else
	 { 
		 print "	<TR><TD WIDTH=\"100%\"><B><font color=red><NOWRAP>This project contains no Cytometry Data</NOWRAP></font></B></TD></TR>\n";
	}
		
 #### Finish the table
  print qq~
	</TABLE></TD></TR>
	</TABLE>~;
    	
	  ##########################################################################
  #### Print out all projects owned by the user
	$sbeams->printProjectsYouOwn() if $sbeams->getCurrent_contact_id();
  ##########################################################################
  #### Print out all projects user has access to
  $sbeams->printProjectsYouHaveAccessTo()  if $sbeams->getCurrent_contact_id();
  ##########################################################################
  #### Print out some recent resultsets
  $sbeams->printRecentResultsets()  if $sbeams->getCurrent_contact_id();

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

} # end showMainPage

sub processFile
{

		my %args = @_;
#### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
	my %resultset = ();
  my $resultset_ref = \%resultset;
  my %parameters = %{$ref_parameters};
=comment
	foreach my $k (keys %parameters)
		{
				print "$k  ==== $parameters{$k}<br>";
		}
=cut
	my $fileQuery = "select original_filepath +'/' + filename as completeFile from $TBCY_FCS_RUN where fcs_run_id = $parameters{fileID}";
	my $storeFile = "$PHYSICAL_BASE_DIR/images/tmp/$parameters{fileID}"."\.txt";
	if (-e $storeFile and !$parameters{storeFile})
	{
		unlink $storeFile;
	}


	my @row = $sbeams->selectOneColumn($fileQuery);

	my $infile = $row[0];  #'/net/db/projects/StemCell/FCS/102403/'.$parameters{fileName};
  my ($fileName) =$infile =~ /^.*\/(.*)$/;
	my @header = read_fcs_header($infile);	
	my @keywords = get_fcs_keywords($infile,@header);
	my %values = get_fcs_key_value_hash(@keywords);

	 if (! $parameters{graphNum})
	 {
		 print "<br><center><h4>Assembling the data points.<br></h4></center><br><br>";
		 print "<center><br>Number of parameters measured: $values{'$PAR'}<br><br>";
		 print "<b>Measured parameters:</b><br>";
		 print "Choose the X and Y coordinates<br>";
	}
#		my $string;
	my (%cytoParameters) ;
	foreach my $key (keys %values)
	{	
		if ($key =~ /\$P(\d+)N/i)
		{
			my $position = $1;
			$values{$key} =~ s/^[\s\n]+//g;
			$values{$key} =~ s/[\s\n]+$//g;
			next if $values{$key} =~ /adc/i;
			$cytoParameters{$key} = $values{$key};
#				$postionHash{$optionHash{$values{$key}}} = $1;
#				$string .= " -".$optionHash{$values{$key}}." ".$1;			
		}
	}


  my $databaseUpdate;
	my $fileID = 0;
	my $query = "Select top 1dp. fcs_run_id  from $TBCY_DATA_POINTS dp 
	left join $TBCY_FCS_RUN  fcs on dp.fcs_run_id = fcs.fcs_run_id where
	fcs.filename = \'$fileName\'";
	my @rows = $sbeams->selectOneColumn($query);
	$fileID = $rows[0] if scalar(@rows == 1);;
	if ($fileID) 
	{
		$databaseUpdate = 0;
	}
	else
  {
    $databaseUpdate = 1;
  }

	if ($values{'$PAR'})
	{
#		checkGo();
#   print "<br>file  ======   $fileName<br>fileid ==== $fileID<br>database  +++  $databaseUpdate<br>";
		print qq~ <center><table><tr>~if (! $parameters{graphNum});
		print qq ~<td width = 300></td><td><center><table border><tr>~ if ($parameters{graphNum});
		print qq~ <td >x-axis</td><td>y-axis</td></tr>\n~;
		print qq~ <tr><td colspan=2><hr size =2></td></tr>~;
    
		print $q->start_form (-onSubmit=>"return checkRadioButton($databaseUpdate) ") if  (! $parameters{graphNum});
   	print $q->start_form (-onSubmit=>"return checkAnotherRadioButton()") if  ($parameters{graphNum});
    
		print qq ~ </td><tr><td align=left colspan=2> Create a new graph based on this graph's X and Y  datapoints<br> by specifying the range of the datapoints<td><tr>~ 
		if( $parameters{graphNum});
				
		foreach my $key (keys %cytoParameters)
		{
			
			my $upperKey = uc($cytoParameters{$key});
			if ( ! $parameters{graphNum})
			{
				print qq~ <tr><td><input type="radio" name="xbox" value="$columnHash{$upperKey}">$cytoParameters{$key}</td\n>~;
				print qq~ <td><input type="radio" name="ybox" value="$columnHash{$upperKey}">$cytoParameters{$key}</td></tr> \n~;
			}
			else 
			{
				print qq~ <tr><td><input type="radio" name="xboxAnother" value="$columnHash{$upperKey}">$cytoParameters{$key}</td>\n ~;
				print qq~ <td><input type="radio" name="yboxAnother" value="$columnHash{$upperKey}">$cytoParameters{$key}</td></tr>\n~;
			}
		}
		
		print qq~ <input type=hidden name="inFile" value="$infile">
		<input type =hidden name="fileID" value="$parameters{fileID}">
		<input type=hidden name="storeFile" value="$storeFile">~;
	
		 if ( ! $parameters{graphNum})
		 {
			 print qq~<input type= hidden name="action" value = "$GETGRAPH">  ~ ;
			 print qq~<tr></tr><tr><td><input type ="submit" name= "SUBMIT" value = "SUBMIT PARAMETERS"></td></tr> </table></center> ~;
					 
		 }
		 else
		 {
			 print qq ~
			<tr><td> <b>Select min X-coordinates</b></td> <td><b>Select min Y-coordinates</B></td></tr>~ ;  
			my $staticMinX = $parameters{minX};
			my $staticMaxX = $parameters{maxX};
			my $staticMinY = $parameters{minY};
			my $staticMaxY  = $parameters{maxY};
			my (@xOptionArray, @yOptionArray);
			while ($parameters{minX} < $parameters{maxX})
			{
			#	next if ! defined($parameters{minX});
				push @xOptionArray, $parameters{minX};
				$parameters{minX} += 200;
			}
			
			 while ($parameters{minY} < $parameters{maxY})
			{
		#		next if ! defined($parameters{minY});
				push @yOptionArray, $parameters{minY};
				$parameters{minY} += 200;
			}
			my $count = 0;
			print qq~<tr><td><Select name="xBoxMin" size =3>~;
			foreach my $number (@xOptionArray)
			{
        if ($count ==0 )
        {
          print qq ~ <option selected value=$number>$number~;
          $count ++;
        }
        else
        {
				print qq ~ <option value=$number>$number~;
        }
			}
      $count = 0;
			print qq~</td><td><Select name="yBoxMin" size =3>~;
			foreach my $number (@yOptionArray)
			{
        if ($count ==0 )
        {
          print qq ~ <option selected value=$number>$number~;
          $count ++;
        }
        else
        {
				print qq ~ <option value=$number>$number~;
        }
			}
			$count = 0;
			print "</td></tr><tr><tr><td><b>Select max X-coordinates</b></td> <td><b>Select max Y-coordinates</b></td></tr>";
			print qq~<tr><td><Select name="xBoxMax" size =3>~;
			for(my $c = scalar(@xOptionArray)-1; $c > -1; $c--)
			{
        if ($count == 0)
        {
          print qq ~ <option selected value=$xOptionArray[$c]>$xOptionArray[$c]~;
          $count ++; 
        }
        else
        {
          print qq ~ <option value=$xOptionArray[$c]>$xOptionArray[$c]~;
        }
			}
			print qq~</td><td><Select name="yBoxMax" size =3>~;
		$count = 0;
			for(my $c = scalar(@yOptionArray)-1; $c > -1; $c--)
			{
        if ($count == 0)
        {
          print qq ~ <option selected value=$yOptionArray[$c]>$yOptionArray[$c]~;
          $count ++; 
        }
        else
        {
          print qq ~ <option value=$yOptionArray[$c]>$yOptionArray[$c]~;
        }
			}
			print qq ~</td></tr>~;			
			 print qq~<input type= hidden name="action" value = "$GETANOTHERGRAPH"> 
			 <input type=hidden name ="graphNum" value=1> 
			 <input type=hidden name="xbox" value="$parameters{xbox}">
			 <input type=hidden name="ybox" value="$parameters{ybox}">
			 <input type=hidden name="maxX" value="$staticMaxX">
			 <input type=hidden name="minX" value="$staticMinX">
			 <input type=hidden name="maxY" value="$staticMaxY">
			 <input type=hidden name="minY" value="$staticMinY">~; 
			 
			 print qq~<tr></tr><tr><td align=center colspan=2><input type ="submit" name= "SUBMIT" value = "SUBMIT PARAMETERS"></td></tr> ~;
			 print "</table></center></tr><tr></tr>";
		 }
		 
		print $q->end_form; 
	}
	else
	{
		print "<h4><center><br><br>Unable to process file: $infile.<br>$!<br> <br>Please see your Admin<br></center></h4>";
	}
}
# Read in the header to determine where the text and data sections are in
# in the file.

sub getAnotherGraph
{

	my %args = @_;
#### Process the arguments list
 	 my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %parameters = %{$ref_parameters};
=comment
	foreach my $k (keys %parameters)
		{
				print "$k  ==== $parameters{$k}<br>";
		}	
=cut

	my $parametersRef = createGraph( \%parameters);
	printGraph ($parametersRef);
	
}


sub getGraph
{
	
	my %args = @_;
#### Process the arguments list
 	 my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};
	my %resultset = ();
	my $resultset_ref = \%resultset;
	my %parameters = %{$ref_parameters};
=comment
	foreach my $k (keys %parameters)
		{
				print "$k  ==== $parameters{$k}<br>";
		}	
=cut
	my $infile = $parameters{inFile};
# Strip out all of the keyword-value pairs.
	my @header = read_fcs_header($infile);	
	my @keywords = get_fcs_keywords($infile,@header);
	my %values = get_fcs_key_value_hash(@keywords);

	foreach my $key (keys %values)
	{	
		if ($key =~ /\$P(\d+)N/i)
		{
			my $position = $1;
			$values{$key} =~ s/^[\s\n]+//g;
			$values{$key} =~ s/[\s\n]+$//g;
			next if $values{$key} =~ /adc/i;
			$inParsParam{$optionHash{$values{$key}}} = $1;
		}
	}

# Write the header parameters to the output file.
# Also add the standard column headings.

	my $num_events = $values{'$TOT'};
	print "<br><b>Number of events:</b> $num_events\n<br>";
	my $num_par =  $values{'$PAR'};

	my %inpars = ();
	($inpars{timelow},$inpars{timehigh}) = get_time_par(@keywords);
	$inpars{lut}      = get_lut_par(@keywords);
	$inpars{cls}      = get_cls_par(@keywords);
	$inpars{cts}      = get_cts_par(@keywords);
	$inpars{pw}       = $inParsParam{pw} || 0;   #get_pw_par(@keywords); 
	$inpars{fls}      =  $inParsParam{fl} || 0;
	$inpars{pls}      = $inParsParam{pl} || 0;
	$inpars{wave}     = $inParsParam{wave} || 0;
	$inpars{spec}     = $inParsParam{spec} || 0;
	$inpars{blue}     = $inParsParam{bl} || 0;
	$inpars{green}    =$inParsParam{gr} || 0;;
	$inpars{red}      = $inParsParam{re} || 0;

	data2($infile,$header[3],2,$num_par,$num_events,%inpars);	
	my $parametersRef = createGraph( \%parameters);
	printGraph ($parametersRef);
}
	#			<TR rOWSPAN="2">
		#	<TD COLSPAN="2">
sub printGraph 
{
	my $parameterRef = shift;
	$parameterRef->{graphNum} =1;
	my $imgsrcbuffer = '&nbsp;';
    
	open (TXT, "$parameterRef->{storeFile}") or die $!;
	my $count =1;
	my @imageArray;
	while (my $imageFile = <TXT>)
	{ 
		chomp $imageFile;

		push @imageArray,$imageFile;
	}
	my $prevImage = "xxxx";
	foreach my $image (@imageArray)
	{
		next if $image  =~ /$prevImage/i and do $count --;
		if ($count == 1)
		{
	#			<TR rOWSPAN="2"> 	
			my $imgsrcbuffer ='&nbsp;';
			$imgsrcbuffer = "<IMG SRC=\"$image\">";
			print qq~<TR ROWSPAN="2">
			<td >
			$imgsrcbuffer</td> ~;
			 processFile(ref_parameters=>$parameterRef);
			 print "</tr>";
		}
		else 
		{		   
			print qq~<TR rOWSPAN="2">~if (!$count%2);
			my $imgsrcbuffer ='&nbsp;';
			$imgsrcbuffer = "<IMG SRC=\"$image\">";
			print "<td align=left>	$imgsrcbuffer	</TD>";
			print "</tr>" if ($count%2);
		}
		$prevImage = "_orig";
		$count ++;
	}
	print "</table>";
		
}
		  
#create radio button and x - y min and max 
#regraph this with the original graph and other graphs	
#create hidden field to know how many time this page appeared

sub createGraph 
{
	my ($paramRef) = @_;	
=comment
	foreach my $key (keys %{$paramRef})
	{
		print "this is before $key ===  $paramRef->{$key}<br>";
	}
=cut
	my $xMinCoor = $paramRef->{xBoxMin} || 0;	
	my  $xMaxCoor = $paramRef->{xBoxMax} || 1000000;
	my $yMinCoor = $paramRef->{yBoxMin} || 0;
	my $yMaxCoor = $paramRef->{yBoxMax} || 1000000;
	my $xCoorAnother = $paramRef->{xboxAnother};
	my $yCoorAnother = $paramRef->{yboxAnother};

	my $xCoor = $paramRef->{xbox};
	my $yCoor = $paramRef->{ybox};
	
	my $fileID = $paramRef->{fileID};
	my $inFile = $paramRef->{inFile};
	my ($fileName) = $inFile =~ /^.*\/(.*)$/;
	
	my $maxX = $paramRef->{maxX} || 0; 
	my $maxY =$paramRef->{maxY} || 0; 
	
	my $minX =  1000000;
	$minX = $paramRef->{minX} if defined($paramRef->{minX});
	my $minY = 1000000;
	$minY = $paramRef->{minY} if defined($paramRef->{minY});

	my (@xArray,@yArray);
	my @rows = [];
#first Graph
	my $graphQuery = "Select $xCoor,$yCoor from $TBCY_DATA_POINTS cy
	join $TBCY_FCS_RUN fc on cy. fcs_run_id = fc.fcs_run_id  where 
	filename = \'$fileName\'";
	
	 @rows = $sbeams->selectSeveralColumns($graphQuery) if (!$paramRef->{graphNum}); 	
#all subsequent Graphs
	my $anotherGraphQuery = "Select $xCoorAnother, $yCoorAnother from $TBCY_DATA_POINTS cy 
	 where cy.data_points_id in (select data_points_id from $TBCY_DATA_POINTS where
	$xCoor >=  $xMinCoor and $xCoor <= $xMaxCoor and $yCoor >= $yMinCoor and $yCoor <=  $yMaxCoor and fcs_run_id = $fileID)"; 

	 @rows = $sbeams->selectSeveralColumns($anotherGraphQuery) if ($paramRef->{graphNum}); 	
	
	my $count = 0;
	foreach my $row (@rows)
	{

		next if  $count%5 and (!$paramRef->{graphNum}); 	
		my ($xData, $yData) = @{$row}; 
		$maxX = $xData if ($maxX <$xData and (!$paramRef->{graphNum}));
		$minX = $xData if ($minX > $xData and (!$paramRef->{graphNum}));
		push @xArray,$xData;
		$maxY = $yData  if ($maxY <$yData and (!$paramRef->{graphNum})); 	
		$minY = $yData if ($minY > $yData and  (!$paramRef->{graphNum}));
		push @yArray,$yData;
	}
	my $tmpfile;
	$tmpfile = "plot.$$.@{[time]}_orig.png" if (!$paramRef->{graphNum}); 
	$tmpfile = "plot.$$.@{[time]}.png" if ($paramRef->{graphNum}); 
	
	my @data=([@xArray],[@yArray]);
#foreach my $pp (keys %{$paramRef})
#{
#	print "$pp === $paramRef->{$pp}<br>";
#}

	my $xLabel = $xCoor;
	$xLabel = $xCoorAnother. "  ". $xMinCoor. " - " .$xMaxCoor  if ($xCoorAnother);
	my $yLabel = $yCoor;
	$yLabel = $yCoorAnother. "  " .$yMinCoor. " - " .$yMaxCoor  if ($yCoorAnother);
	my $graph;
	$graph = GD::Graph::xypoints->new(500,380) if (! $paramRef->{graphNum} );
	$graph = GD::Graph::xypoints->new(350,230) if ($paramRef->{graphNum} );
	 if (! $paramRef->{graphNum} )
	 {
		 $graph->set(
             x_label           =>$xLabel,
             y_label           => $yLabel,
             title             => $inFile,
			 x_number_format => \&formatNum,
			 y_number_format => \&formatNum,
			 x_tick_number => 25,
			 y_tick_number => 25,
			 long_ticks        => 0,
			 markers => 7,
			 show_value => 1,
			 marker_size => .1,
			  x_max_value =>$maxX,
			   y_max_value       => $maxY
			   );
	 }
	else
	{		   
		$graph->set(			   
		      x_label           =>$xLabel,
             y_label           => $yLabel,
              x_number_format => \&formatNum,
			 y_number_format => \&formatNum,
			 x_tick_number => 10,
			 y_tick_number => 10,
			 long_ticks        => 0,
			 markers => 7,
			 show_value => 1,
			 marker_size => .1,
		   );
	}
			   
	 
     my $gd = $graph->plot(\@data);
     open(IMG, ">$PHYSICAL_BASE_DIR/images/tmp/$tmpfile") or die $!;
     binmode IMG;
     print IMG $gd->png;
     close IMG;
 #### Provide the link to the image
 	my $imageFile = "$HTML_BASE_DIR/images/tmp/$tmpfile";
	open (TXT, ">>$paramRef->{storeFile}") or die $!;
	print TXT "$imageFile\n";
	close TXT;
	
	$paramRef-> {maxX} = $maxX;
	$paramRef-> {maxY} = $maxY;
	$paramRef-> {minX} = $minX;
	$paramRef-> {minY} = $minY;
=comment	
		foreach my $key (keys %{$paramRef})
	{
		print "this is create Graph $key ===  $paramRef->{$key}<br>";
	}
=cut
	return ($paramRef);
  	
}

sub formatNum
{
	my $value = shift;
	$value =~ s/^(\d+)\.\d*$/$1/;
	return $value;
}


sub data2
 {

   my  $infile   = shift(@_);
   my  $offset   = shift(@_);
   my $size     = shift(@_); # not used
   my $n_params = shift(@_);
   my $n_events = shift(@_);
   my %incol    = @_; # This hash contains the column assignments for the
                    # parameters in the input datafile.  See the main
                    # code for details.
					
	my ($fileName) = $infile =~ /^.*\/(.*)$/; 

    # Next, we deal with any parameters which are not amoung the "standard
    # set".  There is probably a slicker way to do this but I don't have
    # time to think about it right now.

# Define an array which contains the indices of all parameters.
	my( @cols,@unnamed);
    for (my $i = 1; $i <= $n_params; $i++) {
	$cols[$i] = $i;
    }

    while ((my($key,$value)) = each %incol) {
	$cols[$value] = 0;
    }  

    my $j = 0;
    for (my $i = 1; $i <= $n_params; $i++) {
	if ($cols[$i] != 0) {
	    $unnamed[$j] = $cols[$i];
	    $j++;
	}
    }
    open(FCSFILE,"$infile") or die "dump_data: Can't find input file $infile.";

    # Throw away all of the bits up to the data part of the file.
    my $pre_text = $offset;
    my $dummy = "";
    read(FCSFILE,$dummy,$offset);

    # Initialize the event array.
    my @firstevent = ();
	my $data;
    # Read the first event in order to get the starting time.
    for (my $param = 1; $param <= $n_params; $param++) {
	read(FCSFILE,$data,2);
	$firstevent[$param] = unpack("S",$data);
    }
    my $time0 = ( $firstevent[$incol{timelow}]) + 4096 * ($firstevent[$incol{timehigh}] ); 
    close(FCSFILE); # For ease of understanding the code and to avoid
                    # duplicating code, we close the file, then re-open
                    # it and read in the first event again along with the
                    # rest of the data.

    # Read in the data, sort it out into the correct columns, and dump
    # it to the output file.
    open(FCSFILE,"$infile") or die "dump_data2: Can't find input file $infile.";
    read(FCSFILE,$dummy,$offset); # read over header and text sections.
	my $fileID = 0;
	my $query = "Select top 1dp. fcs_run_id  from $TBCY_DATA_POINTS dp 
	left join $TBCY_FCS_RUN  fcs on dp.fcs_run_id = fcs.fcs_run_id where
	fcs.filename = \'$fileName\'";
	my @rows = $sbeams->selectOneColumn($query);
	$fileID = $rows[0] if scalar(@rows == 1);;
	if ($fileID) 
	{
		return;
	}
	else
	{
    
		my $fileQuery = "Select fcs_run_id from $TBCY_FCS_RUN where filename = \'$fileName\'";		
		my @rows = $sbeams->selectOneColumn($fileQuery);
		my $runID = $rows[0];		
		my @event;
		for (my $event_num = 1 ; $event_num <= $n_events; $event_num++) 
		{
			for (my $param = 1; $param <= $n_params; $param++)
			{
	    # This assumes a 16 bit data word.  Not the best way to do this.
	    		read(FCSFILE,$data,2);
				$event[$param] = unpack("S",$data);
			}
	
	# Compute the time from the two 12-bit values.  Subtract off the
	# time of the earliest event in the file.
	# June 12, 2003.  Change this to not subtract off the initial time
	# to allow concatenation of multiple files while preserving the time.
	# $time = $event[$incol{timelow}] + 4096 * ($event[$incol{timehigh}])  - $time0; 
			my $time = $event[$incol{timelow}] + 4096 * ($event[$incol{timehigh}]);
			my $insert = 1;
			my $update = 0;
			my $pK = 0;
			my %dataHash;	
			$dataHash{lut} = $event[$incol{lut}]; 
			$dataHash{cls} = $event[$incol{cls}]; 
			$dataHash{cts} = $event[$incol{cts}]; 
			$dataHash{pw}= $event[$incol{pw}]; 
			$dataHash{fls} = $event[$incol{fls}]; 
			$dataHash{pls} = $event[$incol{pls}]; 
			$dataHash{wave} = $event[$incol{wave}]; 
			$dataHash{spec} = $event[$incol{spec}]; 
			$dataHash{blue} = $event[$incol{blue}]; 
			$dataHash{green} = $event[$incol{green}];
			$dataHash{red} = $event[$incol{red}]; 
			$dataHash{fcs_run_id} = $runID; 
		
			my $returned_PK = $sbeams->updateOrInsertRow(
				insert => $insert,
				update => $update,
				table_name => "$TBCY_DATA_POINTS",
				rowdata_ref => \%dataHash,
				PK => "data_points_id",
				PK_value => $pK,
				return_PK => 1,
				verbose=>$VERBOSE,
				testonly=>$TESTONLY,
				add_audit_parameters => 1
				);
		}
	}
	close(FCSFILE);
 }

sub printMessage
{
		print "<center><b>This is first time this file has been accessed.<br> Data points need to be loaded into the Database.<br> This may take a few minutes.<br> Please be patient</B><br></center>";
		return; 
}
	
sub checkGO
{
  
  print q~ <script language=javascript type="text/javascript"> ~;
	print <<QUERY;
	function checkRadioButton( databaseCheck)
  {
     
 //  var  isXChecked = false;
 // alert (isXChecked );
   alert (databaseCheck);
   var num = document.forms.length;
 //alert(num);
   
   for (var c =0; c<document.forms[3].xbox.length;c++)
		{
      if (document.forms[3].xbox[c].checked ==true)
      {
         isXChecked = true;
      }
    }
   
    if (isXChecked == false)
    { 
      alert ("ERROR: You need to specify a valid X parameter" );
      return false;
    }

   var isYChecked = false;
		for (var c =0; c<document.forms[3].ybox.length;c++)
		{
      if (document.forms[3].ybox[c].checked == true)
      {
        isYChecked = true;
      }
    }
    
    if ( isYChecked == false)
    { 
      alert ("ERROR: You need to specify a valid Y parameter" );
      return false;
   }
   if (databaseCheck >0)
  {
    if (confirm ("This is first time this file is being  accessed. Data points need to be loaded into the Database. This may take a few minutes. Please be patient"))
    {
      return;
    }
    else
    { 
      return false; 
    }
   }
	
   
}   
 function checkAnotherRadioButton()
   {
    var  isAnotherXChecked = false;
   //alert (isAnotherXChecked);
   
   var num = document.forms.length;
   //alert(num);
   
    for (var c =0; c<document.forms[3].xboxAnother.length;c++)
		{
      if (document.forms[3].xboxAnother[c].checked ==true)
      {
         isAnotherXChecked = true;
      }
    }
   
    if (isAnotherXChecked == false)
    { 
      alert ("ERROR: You need to specify a valid X parameter" );
      return false;
    }

   var isAnotherYChecked = false;
		for (var c =0; c<document.forms[3].yboxAnother.length;c++)
		{
      if (document.forms[3].yboxAnother[c].checked == true)
      {
        isAnotherYChecked = true;
      }
    }
    
    if (! isAnotherYChecked)
    { 
      alert ("ERROR: You need to specify a valid Y parameter" );
      return false;
    }

    var  xMinIndex = document.forms[3].xBoxMin.options.selectedIndex;
    var xMaxIndex = document.forms[3].xBoxMax.options.selectedIndex;
    var xMinValue = document.forms[3].xBoxMin.options[xMinIndex].value;
    var xMaxValue = document.forms[3].xBoxMax.options[xMaxIndex].value;

    
    if (eval(xMinValue) >= eval( xMaxValue))
     {
       alert ("X max needs to be greater than X min");
       return false;
     }
      
      var yMinIndex = document.forms[3].yBoxMin.options.selectedIndex;
      var yMaxIndex = document.forms[3].yBoxMax.options.selectedIndex;
      var yMinValue = document.forms[3].yBoxMin.options[yMinIndex].value;
      var yMaxValue = document.forms[3].yBoxMax.options[yMaxIndex].value;
    
    if (eval(yMinValue) >= eval( yMaxValue))
    {
      alert ("Y max needs to be greater than Y min");
      return false;
    }
    
    
    
    
    
 }       

QUERY
print "<\/script>";
}
__END__
		


