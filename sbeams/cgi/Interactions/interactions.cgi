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
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS $HTMLFILE $BIOENTITY_URL $INTERACTION_URL $BASEDIR);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;

use SBEAMS::Interactions;
use SBEAMS::Interactions::Settings;
use SBEAMS::Interactions::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Interactions;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
$q = new CGI;

my $DISPLAY = '_display';
my $ERROR = '_error';
my $CHECKINPUT = '_checkInput';
my $PROJECT = '_getProject';
my $INTERACTIONUSER = '_getInteractionUser';

my %actionHash = ($DISPLAY => \&display,
		  $ERROR =>	\&error,
		  $CHECKINPUT => \&checkInput,
		  $PROJECT => \&getProject,
		  $INTERACTIONUSER =>\&getInteractionUser
		  );
		  

	
###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag to level n
  --testonly          Set testonly flag which simulates INSERTs/UPDATEs only

 e.g.:  $PROG_NAME --verbose 2 keyword=value

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","quiet")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "   VERBOSE = $VERBOSE\n";
  print "     QUIET = $QUIET\n";
  print "     DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}

$DEBUG =1;

###############################################################################
# Global Variables
###############################################################################
$PROGRAM_FILE_NAME = 'interactions.cgi';
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main { 
	
#Do the SBEAMS authentication and exit if a username is not returned
	exit unless ($current_username = $sbeams->Authenticate(
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin',
    #  'Proteomics_readonly'],
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
  	if ($parameters{action} eq "???")
	{
    # Some action
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
	
  my %parameterHash = @_;

  #### Process the arguments list
  my $ref_parameters = $parameterHash{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
  
 
  my ($i,$element,$key,$value,$line,$result,$sql);
  my @rows;
  #### Show current user context information
  $current_contact_id = $sbeams->getCurrent_contact_id();
  
  #### Get all the experiments for this project
my $action = $parameters{'action'};

#loading the default page (Intro)
my $sub = $actionHash{$action} || $actionHash{$DISPLAY};
  #||$actionHash{$INTERACTIONUSER};
  if  ($action eq "getProject")
  { 
	getProject(ref_parameters=>\%parameters);
  }
  elsif ($action eq "getInteractionUser")
  {
	  getInteractionUser(ref_parameters=>\%parameters);
  }
  elsif ($action eq "display")
  {
	display(ref_parameters=>\%parameters);
  }
=comment	
	if ($sub )	{ 
			&$sub(ref_parameters=>\%parameters);
	}
#could not find a sub
	else
	{
		print_fatal_error("Could not find the specified routine: $sub");
	}
=cut
}
	
sub display
{
	my $htmlFile;
	my %parameterHash = @_;
#### Process the arguments list
  my $ref_parameters = $parameterHash{'ref_parameters'}
    || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};

if ($DEBUG)
{	
	foreach my $key (keys %parameters)
	{
		print "$key ===  $parameters{$key}<br>";
	}
}
my $devSite;
$devSite = $parameters{server_name};
my $site; 
($site) = $devSite=~ /(dev.*?)\//i; 

 $BASEDIR = "/net/dblocal/www/html/".$site."/sbeams/tmp/Interactions/";


#	$BASEDIR = "/net/dblocal/www/html/sbeams/tmp/Interactions/";
$BIOENTITY_URL =$parameters{server_name}."cgi/Interactions/ManageTable.cgi?TABLE_NAME=IN_bioentity&bioentity_id=";
$INTERACTION_URL = $parameters{server_name}. "cgi/Interactions/ManageTable.cgi?TABLE_NAME=IN_interaction&interaction_id=";
	$htmlFile = $parameters{filename} .".html";
	if(! -d  $BASEDIR)
	{
		mkdir ($BASEDIR) || die "Can not open make $BASEDIR $!"; 
	}

	open (File, ">>$BASEDIR$htmlFile") or print "can not open $htmlFile $!";
print File "<html><body><h3> Result Summary  For Selected Interaction</h3><br>";
print File "<center><b>You can edit  your  Sbeams entries by clicking on the links</b></center><br>";

print File "<br><pre>";
	my $organismSql = "select upper( full_name), organism_id  from sbeams.dbo.organism";
	my $organismNameSql = " select upper( organism_Name), organism_id  from sbeams.dbo.organism";
	my $interactionTypeSql = "select interaction_type_name, interaction_type_id from $TBIN_INTERACTION_TYPE";	
	my $bioentityTypeSql = "select upper(bioentity_type_name), bioentity_type_id from $TBIN_BIOENTITY_TYPE";
	
	my %organismHash = $sbeams->selectTwoColumnHash($organismSql);
	my %organismNameHash = $sbeams->selectTwoColumnHash($organismNameSql);
	my %interactionTypeHash = $sbeams->selectTwoColumnHash($interactionTypeSql);
	my %bioentityTypeHash = $sbeams->selectTwoColumnHash($bioentityTypeSql);
	
	my %bioentityHash={};
#passed parameters
  #### Build PROJECT_ID constraint
 	 my $project_clause = $sbeams->parseConstraint2SQL(
    constraint_column=>"IG.project_id",
    constraint_type=>"int_list",
    constraint_name=>"Projects",
    constraint_value=>$parameters{project_id} );
	
	
	$bioentityHash{canSource} = $parameters{canonicalName1};
	$bioentityHash{comSource} =$parameters{commonName1};
	$bioentityHash{typeSource} = uc ($parameters{moleculeType1});	
	$bioentityHash{typeSource} = 'Protein'	if ($parameters{canonicalName1} =~ /^([nx])[pctgrw].*/i and ! defined($parameters{moleculeType1}));
	$bioentityHash{typeSource} = 'DNA'  if ($parameters{canonicalName1} =~ /^(nm_).*/i and ! defined($parameters{moleculeType1}));
	$bioentityHash{organismSource} = uc($parameters{species1}) unless $parameters{species1} =~ /unknown/i ;
	my $species1ID;
	$species1ID = $organismHash{$bioentityHash{organismSource}}; # unless $parameters{species1} =~ /unknown/i ;
	$species1ID = $organismNameHash{$bioentityHash{organismSource}} unless defined($species1ID);	

	
	
	$bioentityHash{canTarget} = $parameters{canonicalName2};
	$bioentityHash{comTarget} =$parameters{commonName2};
	$bioentityHash{typeTarget} = uc($parameters{moleculeType2});	
	$bioentityHash{typeTarget} = 'Protein'  if ( $parameters{canonicalName2} =~ /^([nx])[pctgrw].*/i and ! defined($parameters{moleculeType2}));
	$bioentityHash{typeTarget} = 'DNA'  if ($parameters{canonicalName2} =~ /^(nm_).*/i and ! defined($parameters{moleculeType2}));
	$bioentityHash{organismTarget} =  uc($parameters{species2}) unless $parameters{species2} =~ /unknown/i ;
	my $species2ID;
	$species2ID = $organismHash{$bioentityHash{organismTarget}};
	$species2ID = $organismNameHash{$bioentityHash{organismTarget}} unless defined($species2ID);
	
	$bioentityHash{interaction} = $parameters{interactionType};

	
		
print File "Bioenity Source Type:  $bioentityHash{typeSource}\n" if $bioentityHash{typeSource};
print File "Bioenity Target Type:  $bioentityHash{typeTarget}\n" if $bioentityHash{typeTarget};
	if(!defined( $bioentityHash{typeSource}))
	{
print File "\n<b> Configuring Source and Target  Bioentity Type</b>\n\n";	
		if ($parameters{interactionType} =~ /pp/i)
		{
			$bioentityHash{typeSource} = 'PROTEIN';
			$bioentityHash{typeTarget} = 'PROTEIN';
		}
		elsif (($parameters{interactionType} =~ /dp/i) or( $parameters{interactionType} =~/.*dna\s*-\s*protein.*/i))
		{
			$bioentityHash{typeSource} = 'DNA';
			$bioentityHash{typeTarget} = 'PROTEIN';
		}	
		elsif (($parameters{interactionType} =~ /pd/i) or ( $parameters{interactionType} =~/.*protein\s*-\s*dna.*/i))
		{
			$bioentityHash{typeSource} = 'PROTEIN';
			$bioentityHash{typeTarget} = 'DNA';
		}		
		else
		{
			if  ($bioentityHash{typeSource})
			{
				print File "Bioenity Source Type:  $bioentityHash{typeSource}\n";
				if ($bioentityHash{typeSource})
				{
					print File "Bioenity Target Type:  $bioentityHash{typeTarget}\n";
				}
			}
			else
			{
			$bioentityHash{typeSource} = 'Protein';
print File  " Could not determine bioentityType for Source Bioentity\n
Used BioentityType: Protein as default\n";
			}
		}
	}
	
	if(!defined( $bioentityHash{typeTarget}))
	{
		$bioentityHash{typeTarget} = 'Protein';
print File "Could not determine  bioentityType for Target Bioentity\n;
Used BioentityType: Protein as default\n";
	}

#bioentity flag;	
	my $isPresent = 1;
#do we have  bioentity1
print File "\n\n<b><font size =3 color=red>Searching Sbeams Database for Source Bioentity</font></b>\n\n";
print File "Used the following parameters: \n
CanonicalName: $bioentityHash{canSource}\n"; 

	
	$bioentityHash{idSource}= checkForBioentity($bioentityHash{canSource});
	
#we do not have this bioentity
	if(! $bioentityHash{idSource}) 
	{
print File "Could not find Source Bioentity in database\n";
		$isPresent = 0;
#making sure we have an organism from cytoscape		
		if (! defined($species1ID))
		{
print File "\n<b>Checking for organism of Source Bioentity</b>\n\n"; 
			$species1ID =	$organismHash{ uc(getOrganism($bioentityHash{canSource}))};
			$species1ID = $organismHash{'OTHER'}  unless (defined($species1ID));
print File "Could not identify Organism for Source Bioentity\n
Used Organism: \"Other\" as default\n" if $bioentityHash{organismSource} eq "Other";
		}
		
		$bioentityHash{idSource} = addToBioentityTable($bioentityHash{canSource}, $bioentityTypeHash{$bioentityHash{typeSource}},$species1ID);
print File "\n<b>Created a New  bioentity for the Source Node with the following parameters:\n\n</b>
Canonical Name:  $bioentityHash{canSource}\n
Bioentity Type: $bioentityHash{typeSource}\n
Organism: $organismHash{$species1ID}\n
		
Added NEW  bioenity_id: $bioentityHash{idSource}\n 
Link::  <a href = $BIOENTITY_URL$bioentityHash{idSource} target = sbeams>$BIOENTITY_URL$bioentityHash{idSource}</a>\n";
	}
	else 
	{
print File "\n<b>Found Source Bioentity.</b>\n
Did not update Source Bioentity Entry\n
<a href  =$BIOENTITY_URL$bioentityHash{idSource } target=sbeams>$BIOENTITY_URL$bioentityHash{idSource}</a>\n";
	}
	
print File "\n\n<b><font size = 3 color = red>Searching Sbeams Database for Target Bioentity</font></b>\n\n";
print File "Used the following parameters: \n
CanonicalName: $bioentityHash{canTarget}\n";
	#do we have  bioentity2
	$bioentityHash{idTarget}= checkForBioentity($bioentityHash{canTarget});
	

#we do not have this bioentity
	if(! $bioentityHash{idTarget}) 
	{
		$isPresent = 0;
			print File "Could not find Target Bioentity in database\n";
#making sure we have an organism from cytoscape		
		if (defined($species2ID))
		{
print File "\n<b>Checking for organism of Target Bioentity</b>\n\n";
			$species2ID =	$organismHash{ uc(getOrganism($bioentityHash{canTarget}))};
			$species2ID = $organismHash{'OTHER'}  unless (defined($species2ID));
print File "Could not identify Organism for Target Bioentity\n
Used Organism: \"Other\" as default\n" if $bioentityHash{organismTarget} eq "Other";
		}
		
		$bioentityHash{idTarget} = addToBioentityTable($bioentityHash{canTarget},$bioentityTypeHash{ $bioentityHash{typeTarget}},$organismHash{$bioentityHash{organismTarget}});
print File "\n<b>Created a New  bioentity for the Target Node with the following parameters:</b>\n\n
Canonical Name:  $bioentityHash{canTarget}\n
Bioentity Type: $bioentityHash{typeTarget}\n
Organism: $bioentityHash{organismTarget}\n
		
Added NEW  bioenity_id: $bioentityHash{idTarget}\n
Link:  <a href = $BIOENTITY_URL$bioentityHash{idTarget} target =sbeams>$BIOENTITY_URL$bioentityHash{idTarget}</a>\n";
	}
	else 
	{ 
print File "\n<b>Found Target Bioentity.</b>\n
 Did not update Target Bioentity Entry\n
Link: <a href =  $BIOENTITY_URL$bioentityHash{idTarget} target=sbeams>$BIOENTITY_URL$bioentityHash{idTarget}</a>\n";
	}
	
print File "\n\n<b><font size = 3 color = red>Searching Sbeams for Selected Interaction</font></b>\n\n";;
	if($isPresent)
	{
		if (!$interactionTypeHash{$bioentityHash{interactionType}})
		{
print File "Could not find the specified interaction type in the database:  --   $bioentityHash{interaction}    --    \n
Used interaction type \"Interacts with\" as default\n";
			$bioentityHash{interactionType} = "Interacts with";
		}
		
		my $interactionID = checkForInteraction($bioentityHash{idSource}, $bioentityHash{idTarget});
		if(! $interactionID)
		{	
		my $interactionID = addToInteractionTable ($bioentityHash{idSource}, $bioentityHash{idTarget}, $interactionTypeHash{$bioentityHash{interactionType}},$parameters{set_interaction_group_id});
print File " \n<b>Created a NEW Interaction with the following parameters:</b>\n\n
Bioentity Source ID: $bioentityHash{idSource}\n
Bioentity Target ID: $bioentityHash{idTarget}\n
InteractionType:  $bioentityHash{interactionType}\n

Added NEW interactionID:  $interactionID\n
Link: <a href=  $INTERACTION_URL$interactionID target=sbeams> $INTERACTION_URL$interactionID</a>\n";
		}
		else 
		{
print File "\n<b>Found pre-exsisting Interaction</b>\n
Link: <a href = $INTERACTION_URL$interactionID target=sbeams> $INTERACTION_URL$interactionID</a>\n";
		}
	}
	else
	{	
		if (!$interactionTypeHash{$bioentityHash{interactionType}})
		{
print File " Could not find the specified interaction type in the database:  --   $bioentityHash{interactionType}    --    \n
Used interaction type \"Interacts with\" as default\n";
			$bioentityHash{interactionType} = "Interacts with";
		}

		my $interactionID = addToInteractionTable ($bioentityHash{idSource}, $bioentityHash{idTarget}, $interactionTypeHash{$bioentityHash{interactionType}},$parameters{set_interaction_group_id});                       
print File " \n<b>Created a NEW Interaction with the following parameters:</b>\n\n
Bioentity Source ID: $bioentityHash{idSource}\n
Bioentity Target ID: $bioentityHash{idTarget}\n
InteractionType:  $bioentityHash{interactionType}\n

Added NEW interactionID:  $interactionID\n
Link: <a href =$INTERACTION_URL$interactionID target=sbeams> $INTERACTION_URL$interactionID</a>\n";
	}

print File "</pre><br><br><hr size =3><br><br></body></html>";
	close File;
}
	
	sub getProject
	{ 
			my %parameterHash = @_;
#### Process the arguments list
  my $ref_parameters = $parameterHash{'ref_parameters'}
    || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};
	

		
		my $projectIDSql = "SELECT DISTINCT P.project_id,UL.username+\' -\ '+P.name FROM sbeams.dbo.project P 
INNER JOIN $TBIN_INTERACTION_GROUP IG ON ( P.project_id = IG.project_id ) 
LEFT JOIN sbeams.dbo.USER_LOGIN UL ON ( P.PI_contact_id=UL.contact_id ) 
WHERE P.record_status != 'D' ORDER BY UL.username+\' -\ '+P.name,P.project_id";
		
		print "<!--Project-->\n";
		my %projectHash = $sbeams->selectTwoColumnHash($projectIDSql);
		foreach my $key	(keys %projectHash) 
		{
			print "$key\t$projectHash{$key}\n";
		}
		print "<!--EndProject-->\n";
	}
	
	
	sub getInteractionUser
	{
			my %parameterHash = @_;
#### Process the arguments list
  my $ref_parameters = $parameterHash{'ref_parameters'}
    || die "ref_parameters not passed";
	my %parameters = %{$ref_parameters};

		
		my $interactionUserSql = qq /SELECT interaction_group_id,UL.username+' - '+P.project_tag+' - '+O.organism_name+' - '+IG.interaction_group_name 
		FROM $TBIN_INTERACTION_GROUP IG 
		INNER JOIN sbeams.dbo.PROJECT P ON ( IG.project_id = P.project_id ) INNER JOIN
		sbeams.dbo.USER_LOGIN UL ON ( P.PI_contact_id = UL.contact_id ) INNER JOIN 
		sbeams.dbo.organism O ON ( IG.organism_id = O.organism_id )
		where P.project_id = $parameters{set_current_project_id}
		ORDER BY UL.username,P.project_tag,O.organism_name,IG.interaction_group_name/;
	
		print "$interactionUserSql\n" if $DEBUG;
		print "<!--InteractionUser-->\n";
		my %interactionUserHash = $sbeams->selectTwoColumnHash($interactionUserSql);
		foreach my $key	(keys %interactionUserHash) 
		{
			print "$key\t$interactionUserHash{$key}\n";
		}
		print "<!--EndInteractionUser-->\n";
	
	}
	
	sub getOrganism
	{ 
		my $can = shift; 
		my $organism = 0;
	
		my $sql = qq / Select organism from locuslink.dbo.loci l 
			join locuslink.dbo. refseq rs on l.locus_id = rs.locus_id 
			where (rs.mrna ='$can' or protein = '$can') /;
		
			
		my @rows = $sbeams->selectOneColumn($sql);
		my $nrows = scalar(@rows);
		$organism = $rows[0] if $nrows == 1;
		return $organism;
		
	}
			
 
	sub checkForBioentity
	{
		my $can = shift; 
		my $whereClause;
		my $bioentityID = 0;
		$whereClause = qq /bioentity_canonical_name ='$can'/;
		my $bioentitySql = qq / select bioentity_id from $TBIN_BIOENTITY where $whereClause/;
		my @rows = $sbeams->selectOneColumn($bioentitySql);	
		my $nrows = scalar(@rows);
		$bioentityID = $rows[0] if $nrows == 1;
		return $bioentityID;
	} 

	sub addToBioentityTable
	{
		my ($canName,$type,$organism) = @_;
		my $insert=1;
		my $update=0;
		my $id = 0;
		my %rowData;
	
		$rowData{bioentity_canonical_name} = $canName;	
		$rowData{bioentity_type_id}= $type;
		$rowData{organism_id} = $organism;		
	
		
		my $returned_PK = $sbeams->updateOrInsertRow(
							insert => $insert,
							update => $update,
							table_name => "$TBIN_BIOENTITY",
							rowdata_ref => \%rowData,
							PK => "bioentity_id",
							PK_value => $id,
							return_PK => 1,
							verbose=>$VERBOSE,
							testonly=>$TESTONLY,
							add_audit_parameters => 1
							);  

		return $returned_PK;
	}
	
	sub checkForInteraction 
	{
		my  ($id1, $id2) = @_;
		my $interactionID = 0;
		my $interactionSql = qq / select interaction_id from $TBIN_INTERACTION  where bioentity1_id = $id1 and bioentity2_id = $id2/;
		print "$interactionSql\n" if $DEBUG;
		my @rows = $sbeams->selectOneColumn($interactionSql);	
		my $nrows = scalar(@rows);
		$interactionID = $rows[0] if $nrows == 1;
		return $interactionID;
	}
	sub addToInteractionTable
	{
		my ($id1,$id2,$type,$interactionGroupID) = @_;
		my $insert=1;
		my $update=0;
		my $id = 0;
		my %rowData;
		$rowData{bioentity1_id} = $id1;	
		$rowData{bioentity2_id} = $id2;	
		$rowData{interaction_type_id}= $type;
		$rowData{interaction_group_id} = $interactionGroupID;
		
		my $returned_PK = $sbeams->updateOrInsertRow(
							insert => $insert,
							update => $update,
							table_name => "$TBIN_INTERACTION",
							rowdata_ref => \%rowData,
							PK => "interaction_id",
							PK_value => $id,
							return_PK => 1,
							verbose=>$VERBOSE,
							testonly=>$TESTONLY,
							add_audit_parameters => 1
							);
							
		return $returned_PK;
	}



__END__


		

  
  
  
  
  
  
  
