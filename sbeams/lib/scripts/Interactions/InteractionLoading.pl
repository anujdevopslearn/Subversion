#!/usr/local/bin/perl -w
use strict;
use FileHandle;
use DirHandle;
use Getopt::Long;
use Data::Dumper;
use FindBin;
#use FreezeThaw qw( freeze thaw );
use lib qw (../perl ../../perl);
use vars qw ($PROG_NAME $q $sbeamsMOD $sbeams $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            $current_contact_id $current_username );

			
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Interactions;
use SBEAMS::Interactions::Settings;
use SBEAMS::Interactions::Tables;


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Interactions;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
 --verbose n          Set verbosity level.  default is 0
 --quiet              Set flag to print nothing at all except errors
 --debug n            Set debug flag
 --testonly           If set, rows in the database are not changed or added
 --source_file XXX    Source file name from which data are to be updated
 							It is a tab delimited txt file
 --check_status       Is set, nothing is actually done, but rather
                       a summary of what should be done is printed
--error_file	Error file name to which loading errors are printed
 e.g.:  $PROG_NAME --check_status --source_file  /users/bob/source.txt  --error_file  /users/bob/error.txt
EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
		   "source_file:s","check_status", "error_file:s",
		  )) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}

	
#we need the available data as global data from the lookup tables to make sure the user entered valid data
#ref to all lookup tables
my (%INFOPROTEIN1,
	%INFOPROTEIN2,
	%INTERACTION, @columnOrder, %columnHashProtein1, %columnHashProtein2, %interactionHash,$bioentityState,$bioentityType,$organismName,$interactionTypes,
	$interactionGroups,$confidenceScores,$assayTypes,$pubMed, $interactionGroupsOrganism, $fhError, $fhLog, $regTypes, %locusIDProteinHash,  %locusIDmRNAHash);

main();
exit;

sub main
{
		 #### Do the SBEAMS authentication and exit if a username is not returned
		 exit unless ($current_username = $sbeams->Authenticate(
		 work_group=>'Interactions_user',
  ));


	
###Housekeeping, should be in a conf file
@columnOrder = 
qw / Organism_bioentity1_name
	 Bioentity1_type
	 Bioentity1_common_name
	 Bioentity1_canonical_name
	 Bioentity1_full_name
	 Bioentity1_canonical_gene_name
	 Bioentity1_aliases
	 Bioentity1_location
	 Bioentity1_state
	 Bioentity1_regulatory_feature
	 Interaction_type
	 Organism_bioentity2_name
	 Bioentity2_common_name
	 Bioentity2_canonical_name
	 Bioentity2_full_name
	 Bioentity2_aliases
	 Bioentity2_type
	 Bioentity2_regulatory_feature
	 Bioentity2_location
	 Interaction_group
	 Confidence_score
	 Interaction_description
	 Assay_name
	 Assay_type
	 Publication_ids/;
#get the indexes of all columns
my %indexHash;
my $indexCount = 0;	 
foreach my $column (@columnOrder)
{
		$indexHash{$column} = $indexCount;
		$indexCount++;
}
	 
	 
#this should be read from a conf file
%columnHashProtein1 = (
organismName1 => $indexHash{Organism_bioentity1_name},
	bioentityComName1 =>$indexHash{Bioentity1_common_name}, 
	bioentityCanName1 =>$indexHash{Bioentity1_canonical_name},
	bioentityCanGeneName1 => $indexHash{Bioentity1_canonical_gene_name},
	bioentityFullName1	=>$indexHash{Bioentity1_full_name}, 
	bioentityAliasName1 =>$indexHash{Bioentity1_aliases},
	bioentityType1 =>$indexHash{Bioentity1_type},
	bioentityReg1	=>$indexHash{Bioentity1_regulatory_feature},
	bioentityLoc1 =>$indexHash{Bioentity1_location},
	group => $indexHash{Interaction_group},);
	

%columnHashProtein2 = (
	organismName2	=>$indexHash{Organism_bioentity2_name},
	bioentityComName2	=>$indexHash{Bioentity2_common_name},
	bioentityCanName2 =>	$indexHash{Bioentity2_canonical_name}, 	
	bioentityFullName2	=>$indexHash{Bioentity2_full_name},
	bioentityAliasName2	=>	$indexHash{Bioentity2_aliases},
	bioentityType2	=>$indexHash{Bioentity2_type},
	bioentityReg2	=>$indexHash{Bioentity2_regulatory_feature},
	bioentityLoc2	=>	$indexHash{Bioentity2_location},
	group =>$indexHash{Interaction_group});

	
%interactionHash = (
	organismName1	=>$indexHash{Organism_bioentity1_name},
	bioentityComName1	=>	$indexHash{Bioentity1_common_name},	
	bioentityCanName1	=>$indexHash{Bioentity1_canonical_name},
	bioentityCanGeneName1 =>$indexHash{Bioentity1_canonical_gene_name},
	bioentityType1	=>	$indexHash{Bioentity1_type},
	bioentityState1	=>$indexHash{Bioentity1_state},
	organismName2	=>$indexHash{Organism_bioentity2_name}, 
	bioentityComName2	=>$indexHash{Bioentity2_common_name},
	bioentityCanName2	=>$indexHash {Bioentity2_canonical_name},
	bioentityType2	=>$indexHash{Bioentity2_type},
	interType	=>$indexHash{Interaction_type},
	group	=>	$indexHash{Interaction_group},
	interaction_description =>$indexHash{Interaction_description},
	assay_name =>$indexHash{Assay_name},
	assay_type=> $indexHash{Assay_type},
	pubMedID	=>	$indexHash{Publication_ids},
	confidence_score => $indexHash{Confidence_score});
	
#getting data from all the lookup tables
#table, column, column
#		my %bioentityState = ($sbeams->selectTwoColumnHash(qq /Select bioentity_state_id, bioentity_state_name from $TBIN_BIOENTITY_STATE/));  
	my %bioentityState = $sbeams->selectTwoColumnHash(qq /Select Upper(bioentity_state_name), bioentity_state_id from $TBIN_BIOENTITY_STATE/);  
	$bioentityState = \%bioentityState;
	my %bioentityType = $sbeams->selectTwoColumnHash(qq /Select Upper(bioentity_type_name),bioentity_type_id from $TBIN_BIOENTITY_TYPE/);
	$bioentityType = \%bioentityType;
	my %organismName = $sbeams->selectTwoColumnHash(qq /Select Upper(organism_name),organism_id from $TB_ORGANISM /);
	$organismName = \%organismName;

	
	my %interactionTypes = $sbeams->selectTwoColumnHash(qq /Select Upper(interaction_type_name), interaction_type_id from $TBIN_INTERACTION_TYPE/);
	$interactionTypes = \%interactionTypes;
	my %interactionGroups = $sbeams->selectTwoColumnHash(qq /Select Upper(interaction_group_name), interaction_group_id from $TBIN_INTERACTION_GROUP/);
	$interactionGroups = \%interactionGroups;
	my %confidenceScores = $sbeams->selectTwoColumnHash(qq /Select (confidence_score_name),confidence_score_id from $TBIN_CONFIDENCE_SCORE/);
	$confidenceScores = \%confidenceScores;
	my %assayTypes = $sbeams->selectTwoColumnHash(qq /Select Upper(assay_type_name), assay_type_id from $TBIN_ASSAY_TYPE/);
	$assayTypes = \%assayTypes;
	my %regTypes = $sbeams->selectTwoColumnHash (qq /Select Upper(regulatory_feature_type_name), regulatory_feature_type_id from $TBIN_REGULATORY_FEATURE_TYPE/);
	$regTypes = \%regTypes; 
	my %pubMed = $sbeams->selectTwoColumnHash (qq /Select pubmed_ID, publication_id from $TBIN_PUBLICATION/);
	$pubMed = \%pubMed;
	%locusIDProteinHash = $sbeams->selectTwoColumnHash( qq/Select locus_id, protein from locuslink.dbo.refseq/); 
	%locusIDmRNAHash = $sbeams->selectTwoColumnHash( qq/Select locus_id,mRNA from locuslink.dbo.refseq/); 
	
	$sbeams->printPageHeader() unless ($QUIET);
	processFile();
#at this point we have either 
#records in INFOPROTEIN1 with no matching in INFOPROTEIN2 and INTERACTION
#records in INFOPROTEIN1 and matching records in INFOPROTEIN2 but no INTERACTION
#records in INFOPROTEIN1 and matching records in INFOPROTEIN2 and INTERACTION
#these subroutines look for dupes, if found update record otherwise insert a new record
		print "checking, populating the database for current Bioentity1 entries\n";	
		checkPopulateBioentity(\%INFOPROTEIN1,1);	
		print "checking, populating the database for current Bioentity2 entries\n";	
		checkPopulateBioentity(\%INFOPROTEIN2,2);
		print "checking, populating the database for current Interactions entries\n";	
		checkPopulateInteraction(\%INTERACTION);
		$sbeams->printPageFooter() unless ($QUIET);
}


sub processFile
{
	
	
#	my $caseFile = shift;
#	my $source_file = $ARGV[0];	
	my $source_file = $OPTIONS{"source_file"} || '';
	my $check_status = $OPTIONS{"check_status"} || '';
	my $errorFile =$OPTIONS{"error_file"} || '';
	 unless ($QUIET)
	 {
		 $sbeams->printUserContext();
		 print "\n";
	 }

  #### Verify that source_file was passed and exists
  unless ($source_file) 
  {
	  print "ERROR: You must supply a --source_file parameter\n$USAGE\n";
	  exit;
  }
  unless (-e $source_file)
  {
	  print "ERROR: Supplied source_file '$source_file' not found\n";
	  exit;
  }
  unless ( $errorFile)
   {
	  print "ERROR: You must supply a  --error_file parameter\n$USAGE\n";
	  exit;
  }
	my $count = 1;
	
  #### Print out the header

#errorLogs
#make them global
	(my $fileID) = $errorFile =~ /^(.*\.).*$/;
	my $errorLog = $fileID."htm";
	$fhError = new FileHandle (">$errorFile") or die "can not open $!";
	Error(\@columnOrder);
	$fhLog = new FileHandle (">$errorLog") or die "can not open $!";
	print $fhLog "<html><body><br>"; 

	open (INFILE, $source_file) or die "$!";
	while (my $line = <INFILE>) 
	{ 
#do not take empty lines or the column header line but
#need to make sure the columns are in the correct order 
#		$line =~ s/[\r\n]//g;
		next if $line =~ /^\s*$/;

		next if $count == 1 and do
		{ 
			$line =~ s/[\r\n]//g;	
			my @excelColumns;
			my @colHeadArray = push @excelColumns, split /\t/, $line;
			
			while (@columnOrder)
			{
					my $a = shift @columnOrder;
			
					my $b = ucfirst(shift @excelColumns);
					
					if ($a ne $b)
					{
							print "Incorrect ColumnOrder!!!\n ColumnName: $a is incorrect\n";
							exit;
					}
			}
			$count++;
		};
#getting the lines and putting columnheader specified info into Hashtables
		$line =~ s/[\r\n]//g;
		
		my @infoArray;
		push @infoArray, split /\t/, $line;
		@infoArray = @infoArray[0..24];
		
		$count++;	
#bioentity1
#as we populate the hash check for valid data entry, if invalid, write an error and go to
#the next line		
		print "checking bioentity1 requirements\n";
		foreach my $column (sort keys %columnHashProtein1)
		{
		
		 $infoArray[$columnHashProtein1{$column}] =~ s/^\s*//;
		 $infoArray[$columnHashProtein1{$column}] =~ s/\s*$//;
		 $INFOPROTEIN1{$count-2}->{$column} = $infoArray[$columnHashProtein1{$column}];
			
		}
		
		$INFOPROTEIN1{$count-2}->{organismName1} = uc($INFOPROTEIN1{$count-2}->{organismName1});
		print "aa $INFOPROTEIN1{$count-2}->{organismName1} aa\n";
		$INFOPROTEIN1{$count-2}->{bioentityReg1} = uc($INFOPROTEIN1{$count-2}->{bioentityReg1});
		$INFOPROTEIN1{$count-2}->{group} = $infoArray[$columnHashProtein1{group}];
		$INFOPROTEIN1{$count-2}->{group} =~ s/[\s+\n+\t+\r+]$//g;
		$INFOPROTEIN1{$count-2}->{group} =~ s/^[\s+\n+\t+\r+]//g;
		$INFOPROTEIN1{$count-2}->{group} =~ s/^([a-z]+)\s+([a-z]+)$/$1 $2/i;
		$INFOPROTEIN1{$count-2}->{group}= uc($INFOPROTEIN1{$count-2}->{group});
		$INFOPROTEIN1{$count-2}->{bioentityType1} = uc($INFOPROTEIN1{$count-2}->{bioentityType1});
		
				
		if (!($INFOPROTEIN1{$count-2}->{bioentityComName1}) and !($INFOPROTEIN1{$count-2}->{bioentityCanName1}))
		{
			print "Detected error1: bioentity1_common_name and bioentiy1_canonical_name\n";
			Error(\@infoArray, "bioentity1_common_name and bioentiy_canonical_name are not defined");
			delete $INFOPROTEIN1{$count-2};
			next;	
		}
		if (($INFOPROTEIN1{$count-2}->{bioentityComName1} =~ /null/i) or($INFOPROTEIN1{$count-2}->{bioentityCanName1} =~ /null/i))
		{
			print "Detected error1: null is not allowed\n";
			Error(\@infoArray, "NULL is not allowed for bioentity1_common_name or bioentiy1_canonical_name");
			delete $INFOPROTEIN1{$count-2};
			next;	
		}
		
		unless ($bioentityType->{$INFOPROTEIN1{$count-2}->{bioentityType1}} and 
 		$organismName->{$INFOPROTEIN1{$count-2}->{organismName1}}) 
		{
			print "Detected error1: type1 or organism1 not defined \n";
			print "$bioentityType->{$INFOPROTEIN1{$count-2}->{bioentityType1}}   -----   $organismName->{$INFOPROTEIN1{$count-2}->{organismName1}} \n ";
			
			Error(\@infoArray, "bioentity1_type or organism1 is not defined");
			delete $INFOPROTEIN1{$count-2};
			next;
		}
		
		if($INFOPROTEIN1{$count-2}->{bioentityCanName1} =~/(xm)|(nm)(xp)/i and $INFOPROTEIN1{$count-2}->{bioentityType1} =~ /protein/i){
				print "this is a gene_name_identifier\n";
				$INFOPROTEIN1{$count-2}->{bioentityCanGeneName1} = $INFOPROTEIN1{$count-2}->{bioentityCanName1};
				undef($INFOPROTEIN1{$count-2}->{bioentityCanName1});
		}
		
		if($INFOPROTEIN1{$count-2}->{bioentityFullName1} =~/(xm_\d)|(nm_\d)/i and $INFOPROTEIN1{$count-2}->{bioentityType1} =~ /protein/i){
				print "this is a gene_name_identifier\n";
				$INFOPROTEIN1{$count-2}->{bioentityCanGeneName1} = $INFOPROTEIN1{$count-2}->{bioentityFullName1};
				undef($INFOPROTEIN1{$count-2}->{bioentityFullName1});
		}
#		
#		if($INFOPROTEIN1{$count-2}->{bioentityReg1} and !($regTypes->{$INFOPROTEIN1{$count-2}->{bioentityReg1}}))
#		{
#				Error (\@infoArray," $INFOPROTEIN1{$count-2}->{bioentityReg1}: no such type in  $TBIN_REGULATOR_FEATURE_TYPE table");
#				delete $INFOPROTEIN1{$count-2};
#				next;
#		}
#
		if ($INFOPROTEIN1{$count-2}->{group} and !$interactionGroups->{$INFOPROTEIN1{$count-2}->{group}})
		{
				print "$INFOPROTEIN1{$count-2}->{group} not found \n";
			
				Error (\@infoArray," $INFOPROTEIN1{$count-2}->{group}: this group is not in $TBIN_INTERACTION_GROUP table");
				delete $INFOPROTEIN1{$count-2};
				next;
		}
#need to make sure that a group is associated with this organism
		my $interactionGroupQuery = qq /select interaction_group_id from $TBIN_INTERACTION_GROUP
		where interaction_group_name ='$INFOPROTEIN1{$count-2}->{group}' 
		and organism_id = $organismName->{$INFOPROTEIN1{$count-2}->{organismName1}}/;
								
		if ($INFOPROTEIN1{$count-2}->{group} and !(scalar($sbeams->selectOneColumn($interactionGroupQuery))))
		{
				
				Error (\@infoArray," $INFOPROTEIN1{$count-2}->{group}: this group is not associated with the given organism in $TBIN_INTERACTION_GROUP table");
				delete $INFOPROTEIN1{$count-2};
				next;
		}
		
		if ($INFOPROTEIN1{$count-2}->{bioentityCanName1} =~ /^\d+$/ and $INFOPROTEIN1{$count-2}->{bioentityType1} =~ /protein/i )
		{
			my $locusID = 	$INFOPROTEIN1{$count-2}->{bioentityCanName1};
			delete$INFOPROTEIN1{$count-2}->{bioentityCanName1};
			$INFOPROTEIN1{$count-2}->{bioentityCanName1} = $locusIDProteinHash{	$locusID};
			if ( ! $INFOPROTEIN1{$count-2}->{bioentityCanName1})
			{
				$INFOPROTEIN1{$count-2}->{bioentityCanName1} = $locusID;
				Error (\@infoArray, "$INFOPROTEIN1{$count-2}->{bioentityCanName1}: could not find PROTEIN for this locsuID");
				
			}
		}
		
		if ($INFOPROTEIN1{$count-2}->{bioentityCanName1} =~ /^\d+$/ and $INFOPROTEIN1{$count-2}->{bioentityType1} =~ /dna/i )
		{
			my $locusID = 	$INFOPROTEIN1{$count-2}->{bioentityCanName1};
			delete$INFOPROTEIN1{$count-2}->{bioentityCanName1};
			$INFOPROTEIN1{$count-2}->{bioentityCanName1} = $locusIDmRNAHash{$locusID};
			if ( ! $INFOPROTEIN1{$count-2}->{bioentityCanName1})
			{
				$INFOPROTEIN1{$count-2}->{bioentityCanName1} = $locusID;
				Error (\@infoArray,"$INFOPROTEIN1{$count-2}->{bioentityCanName1}: could not find RNA for this locsuID");
			#	delete $INFOPROTEIN1{$count-2};
			#	next;
			}
			
		}
		
#bioentity2				
		print "checking bioentity2 requirements\n";
		foreach my $column (sort keys %columnHashProtein2)
		{
			$infoArray[$columnHashProtein2{$column}] =~ s/^\s*//;
			$infoArray[$columnHashProtein2{$column}] =~ s/\s*$//;	
			$INFOPROTEIN2{$count-2}->{$column} = $infoArray[$columnHashProtein2{$column}];
#in case there is no protein2 defined one can not add an empty protein and interaction
#however keep the count going so the the record numbers are the same across all hashes		
		}
		$INFOPROTEIN2{$count-2}->{'group'} = $infoArray[$columnHashProtein2{'group'}];
		$INFOPROTEIN2{$count-2}->{'group'} =~ s/[\s+\n+\t+\r+]$//g;
		$INFOPROTEIN2{$count-2}->{'group'} =~ s/^[\s+\n+\t+\r+]//g;
		$INFOPROTEIN2{$count-2}->{group} =~ s/^([a-z]+)\s+([a-z]+)$/$1 $2/i;
		$INFOPROTEIN2{$count-2}->{group}= uc($INFOPROTEIN2{$count-2}->{group});
		$INFOPROTEIN2{$count-2}->{bioentityType2} = uc($INFOPROTEIN2{$count-2}->{bioentityType2});
		$INFOPROTEIN2{$count-2}->{bioentityReg2} = uc($INFOPROTEIN2{$count-2}->{bioentityReg2});
		$INFOPROTEIN2{$count-2}->{organismName2} = uc($INFOPROTEIN2{$count-2}->{organismName2});
			
		if (!($INFOPROTEIN2{$count-2}->{'bioentityComName2'})	and (!($INFOPROTEIN2{$count-2}->{'bioentityCanName2'})))
		{
						print "Detected error2a: bioentity2 is not specified, bioentity1 has been added to the database\n";
						Error(\@infoArray,"bioentity2 is not specified, bioentity1 has been added to the database");
						delete $INFOPROTEIN2{$count-2};
#we do not bother looking at the interaction columns (maybe need to write an error to the file)
					  next;
		}
		if (($INFOPROTEIN2{$count-2}->{bioentityComName2} =~ /null/i) or($INFOPROTEIN2{$count-2}->{bioentityCanName2} =~ /null/i))
		{
			print "Detected error2: null is not allowed\n";
			Error(\@infoArray, "NULL is not allowed for bioentity2_common_name or bioentiy2_canonical_name");
			delete $INFOPROTEIN2{$count-2};
			next;	
		}
		
		unless ($bioentityType->{$INFOPROTEIN2{$count-2}->{bioentityType2}} and 
 			$organismName->{$INFOPROTEIN2{$count-2}->{organismName2}}) 
		{
		
			Error(\@infoArray, "bioentity2_type or organism2 is not defined, bioentity1 has been added to the database");
			delete $INFOPROTEIN2{$count-2};
			next;
		}
		
		if($INFOPROTEIN2{$count-2}->{bioentityCanName2} =~ /(nm)|(xm)/i and $INFOPROTEIN2{$count-2}->{bioentityType2} =~ /protein/i)
		{
				$INFOPROTEIN2{$count-2}->{bioentityCanGeneName2} = $INFOPROTEIN2{$count-2}->{bioentityCanName2};
				undef($INFOPROTEIN2{$count-2}->{bioentityCanName2});
				
		}
		if($INFOPROTEIN2{$count-2}->{bioentityFullName2} =~/(xm_\d)|(nm_\d)/i and $INFOPROTEIN2{$count-2}->{bioentityType2} =~ /protein/i){
				print "this is a gene_name_identifier\n";
				$INFOPROTEIN2{$count-2}->{bioentityCanGeneName1} = $INFOPROTEIN2{$count-2}->{bioentityFullName2};
				undef($INFOPROTEIN2{$count-2}->{bioentityFullName2});
		}
	
#need to make sure that a group is associated with this organism
		$interactionGroupQuery = qq /select interaction_group_id from $TBIN_INTERACTION_GROUP
		where interaction_group_name = '$INFOPROTEIN2{$count-2}->{group}' 
		and organism_id = $organismName->{$INFOPROTEIN2{$count-2}->{organismName2}}/;		
		
		if ($INFOPROTEIN2{$count-2}->{group} and !(scalar($sbeams->selectOneColumn($interactionGroupQuery))))
		{
				Error (\@infoArray,"$INFOPROTEIN2{$count-2}->{group}: this group is not associated with the given organism in $TBIN_INTERACTION_GROUP table");
				delete $INFOPROTEIN2{$count-2};
				next;
		}
		
		if ($INFOPROTEIN2{$count-2}->{bioentityCanName2} =~ /^\d+$/ and $INFOPROTEIN2{$count-2}->{bioentityType2} =~ /protein/i )
		{
			my $locusID = $INFOPROTEIN2{$count-2}->{bioentityCanName2};
			delete$INFOPROTEIN2{$count-2}->{bioentityCanName2};
			$INFOPROTEIN2{$count-2}->{bioentityCanName2} = $locusIDProteinHash{$locusID};
			if ( ! $INFOPROTEIN2{$count-2}->{bioentityCanName2})
			{
				$INFOPROTEIN2{$count-2}->{bioentityCanName2} = $locusID;
				Error  (\@infoArray,"$INFOPROTEIN2{$count-2}->{bioentityCanName2}: could not find PROTEIN for this locsuID");
				#delete $INFOPROTEIN2{$count-2};
				#next;
			}
			
		
		}
		
		if ($INFOPROTEIN2{$count-2}->{bioentityCanName2} =~ /^\d+$/ and $INFOPROTEIN2{$count-2}->{bioentityType2} =~ /dna/i )
		{
			my $locusID = $INFOPROTEIN2{$count-2}->{bioentityCanName2};
			delete$INFOPROTEIN2{$count-2}->{bioentityCanName2};
			$INFOPROTEIN2{$count-2}->{bioentityCanName2} = $locusIDmRNAHash{$locusID};
			if ( ! $INFOPROTEIN2{$count-2}->{bioentityCanName2})
			{
				$INFOPROTEIN2{$count-2}->{bioentityCanName2} = $locusID;
				Error  (\@infoArray,"$INFOPROTEIN2{$count-2}->{bioentityCanName2}: could not find  RNA for this locsuID");
				#delete $INFOPROTEIN2{$count-2};
				#next;
			}
		}
		
		
		
		
#		
#		if($INFOPROTEIN2{$count-2}->{bioentityReg2} and !($regTypes->{$INFOPROTEIN2{$count-2}->{bioentityReg2}}))
#		{
#				Error (\@infoArray," $INFOPROTEIN2{$count-2}->{bioentityReg1}: no such type in  $TBIN_REGULATOR_FEATURE_TYPE table");
#				delete $INFOPROTEIN1{$count-2};
#				next;
#		}
#
#interaction				
print "checking interaction requirements\n";
		foreach my $column (sort keys %interactionHash)
		{
				$infoArray[$interactionHash{$column}] =~ s/^\s*//;
				$infoArray[$interactionHash{$column}] =~ s/\s*$//;
				$INTERACTION{$count-2}->{$column} = $infoArray[$interactionHash{$column}];
#in case there is no interaction defined, one can not add an empty interaction 
#however keep the count going so the the record numbers are the same across all hashes
		}
#			if (!($infoArray[$interactionHash{'interType'}]))
	#		{	
		#			print "$INTERACTION{$count-2}->{$column}\n";
			#		getc;
		#			print "Detected error: Interactiontype is not specified\n";
			#		Error(\@infoArray, "interactionType is not specified");
			#		delete $INTERACTION{$count-2};
			#		next;
		#	}
	#	}
#assay type, reg type, confidence score, state
#may not be defined, however if they are then they need to 
#have a match in the lookup tables
		$INTERACTION{$count-2}->{'group'} = $infoArray[$interactionHash{'group'}];
		$INTERACTION{$count-2}->{'group'} =~ s/[\s+\n+\t+\r+]$//g;
		$INTERACTION{$count-2}->{'group'} =~ s/^[\s+\n+\t+\r+]//g;
		$INTERACTION{$count-2}->{group} =~ s/^([a-z]+)\s+([a-z]+)$/$1 $2/i;
		$INTERACTION{$count-2}->{confidence_score} =~ s/\s*//g;
		$INTERACTION{$count-2}->{group}= uc($INTERACTION{$count-2}->{group});		
		$INTERACTION{$count-2}->{'interType'} = uc($INTERACTION{$count-2}->{'interType'});
		$INTERACTION{$count-2}->{bioentityState1} = uc($INTERACTION{$count-2}->{bioentityState1});
		$INTERACTION{$count-2}->{assay_type} = uc ($INTERACTION{$count-2}->{assay_type});
	#	$INTERACTION{$count-2}->{confidence_score} =  ($INTERACTION{$count-2}->{confidence_score});

		if (!$INTERACTION{$count-2}->{'interType'}) 
		{
				print "Detected error: Interactiontype is not specified\n";
				Error(\@infoArray, "interactionType is not specified");
				delete $INTERACTION{$count-2};
				next;
		}
				
		if ($INTERACTION{$count-2}->{'interType'} and !($interactionTypes->{$INTERACTION{$count-2}->{interType}}))
		{
				Error(\@infoArray, "interaction is not specified");
				delete $INTERACTION{$count-2};
				next;
		}
		
		if ($INTERACTION{$count-2}->{bioentityState1} and !($bioentityState->{$INTERACTION{$count-2}->{bioentityState1}}))
		{
				Error(\@infoArray, "$INTERACTION{$count-2}->{bioentityState1}:  bioentityState1 is not in the database");
				delete $INTERACTION{$count-2};
				next;
		}
#		$INTERACTION{$count-2}->{bioentityReg1} = ucfirst ($INTERACTION{$count-2}->{bioentityReg1});
#		if ($INTERACTION{$count-2}->{bioentityReg1} and !($regTypes->{$INTERACTION{$count-2}->{bioentityReg1}}))
#		{
#				Error (\@infoArray," $INTERACTION{$count-2}->{bioentityReg1}:  bioentityReg1 is not in the database");
#				delete $INTERACTION{$count-2};
#				next;
#		}
#		$INTERACTION{$count-2}->{bioentityReg2} = ucfirst ($INTERACTION{$count-2}->{bioentityReg2});
#		if ($INTERACTION{$count-2}->{bioentityReg2} and !($regTypes->{$INTERACTION{$count-2}->{bioentityReg2}}))
#		{
#				Error (\@infoArray," $INTERACTION{$count-2}->{bioentityReg2}:  bioentityReg2 is not in the database");
#				delete $INTERACTION{$count-2};
#				next;
#		}
		if ($INTERACTION{$count-2}->{assay_type} and !($assayTypes->{$INTERACTION{$count-2}->{assay_type}}))
		{
				Error (\@infoArray," $INTERACTION{$count-2}->{assay_type}:  assayType is not in the database");
				delete $INTERACTION{$count-2};
				next;
		}
		if ($INTERACTION{$count-2}->{confidence_score} and !($confidenceScores->{$INTERACTION{$count-2}->{confidence_score}}))
		{
			print " $INTERACTION{$count-2}->{confidence_score}\n";
			
				Error (\@infoArray," $INTERACTION{$count-2}->{confidence_score}:  confidenceScore is not in the database");
				delete $INTERACTION{$count-2};
				next;
		}
		
	
		
		if ($INTERACTION{$count-2}->{pubMedID})# and !($pubMed->{$INTERACTION{$count-2}->{pubMedID}}))
		{
#get the pubMedID
 	  	
			 my %pubRowData;
			 my $publicationID = 0;
			 use SBEAMS::Connection::PubMedFetcher;
			 my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
			 my $pubmed_info = $PubMedFetcher->getArticleInfo(
			 	PubMedID=>$INTERACTION{$count-2}->{pubMedID});
				if ($pubmed_info) {
							my %keymap = (
							MedlineTA=>'journal_name',
							AuthorList=>'author_list',
							Volume=>'volume_number',
							Issue=>'issue_number',
							AbstractText=>'abstract',
							ArticleTitle=>'title',
							PublishedYear=>'published_year',
							MedlinePgn=>'page_numbers',
							PublicationName=>'publication_name',
							
							);
							while (my ($key,$value) = each %{$pubmed_info})
							{ 
									
									if ($keymap{$key}) 
									{
											$pubRowData{$keymap{$key}} = $value;
											$pubRowData{$keymap{$key}} =~ s/^([\w\W]{250}).*$/$1/ if (256 < length($pubRowData{$keymap{$key}}));
									}
							}		 
							
					print "ID: $INTERACTION{$count-2}->{pubMedID}	\n";	
							
						my $ll = length($pubRowData{$keymap{AuthorList}});
						$pubRowData{$keymap{AuthorList}} =~ s/^([\w\W]{250}).*$/$1/ if (256 < length($pubRowData{$keymap{AuthorList}}));
						$pubRowData{'pubmed_id'} = $INTERACTION{$count-2}->{pubMedID};
				 		
					my $insert = 1;
					my $update = 0;
					 print "$insert ----- $update";
				
					 if ($pubMed->{$INTERACTION{$count-2}->{pubMedID}})
					 {
							 $insert = 0;
							 $update = 1;
							 $publicationID = $pubMed->{$INTERACTION{$count-2}->{pubMedID}};
					 }
					 
					 	 print "$insert ----- $update   ----------$pubMed->{$INTERACTION{$count-2}->{pubMedID}} ";
					 
							my $returned_PK = $sbeams->updateOrInsertRow(
							insert => $insert,
							update => $update,
							table_name => "$TBIN_PUBLICATION",
							rowdata_ref => \%pubRowData,
							PK => "publication_id",
							PK_value => $publicationID,
							return_PK => 1,
							verbose=>$VERBOSE,
							testonly=>$TESTONLY,
							add_audit_parameters => 1
							);      
						$pubMed->{$INTERACTION{$count-2}->{pubMedID}} = $returned_PK; 
						
						
						print "thus pk $returned_PK\n";
						print "$pubMed->{$INTERACTION{$count-2}->{pubMedID}}\n";
						$INTERACTION{$count-2}->{pubMedID} = $returned_PK
					
																
				}			
				else
				{
						
						Error (\@infoArray," $INTERACTION{$count-2}->{pubMedID}:  pubMedID is not found in public database");
						delete $INTERACTION{$count-2};
						next;
				}
		} #if
	} #while
} #sub processFile

sub checkPopulateBioentity
{
	my $hashRef = shift;
	my $num = shift;
	my $SUB_NAME = "$0::checkPopulateBioentity";
		
#perform a query using the common_name or canonical_name, type of bioentity and organism_name
#only one row should be returned
#if one: do an update
#if none: do an insert
#if many: raise an error
#same with the protein2

#if the test fails delete the corresponding record from the interationHash
#at the end only correct records should be left in the interactionHash	

	foreach my $record (keys %{$hashRef}) 
	{
			print "Record:  $record\n";
			
			my $update = 1; 
			my $insert = 0;
#possible scenerios:
#-1- comName is known but not canName and only canName is in database => insert
#-2- comName is known but not canName and only comName is in database => update

#-3- comName and canName are known but only one or the other is in database => update, 2 queries
#query with comName query with canName if one or the other returns a row do an update

#-4- canName is known but not comName and only comName is in database => insert
#-5- canName is known but not comName and only canName is in database => update

#-6- comName and canName is known but the database has a different matching pair => error

#need todo several queries to the database to make sure we know what case we are dealing with 
#and what to do 

			my $bioentityQuery = "Select BE.bioentity_id
			from $TBIN_BIOENTITY BE
			join $TBIN_BIOENTITY_TYPE BT on (BE.bioentity_type_id = BT.bioentity_type_id)
			full outer join $TBIN_INTERACTION I on (BE.bioentity_id = I.bioentity1_id)
			full outer join $TBIN_INTERACTION I2 on (BE.bioentity_id = I2.bioentity2_id)
			full outer join $TB_ORGANISM SDO on (BE.organism_id = SDO.organism_id)
			full outer join $TBIN_INTERACTION_GROUP IG on (SDO.organism_id = IG.organism_id)
			where BT.bioentity_type_name = \'$hashRef->{$record}->{'bioentityType'.$num}\'
			and SDO.organism_name = \'$hashRef->{$record}->{'organismName'.$num}\' 
			and IG.interaction_group_name = \'$hashRef->{$record}->{'group'}\'";

			my $commonClause =  qq / and BE.bioentity_common_name = /;
			my $canonicalClause = qq / and bioentity_canonical_name =  /;
			my $groupByClause = qq / group by BE.bioentity_id/;
			my $bioentityQueryCommon; 
			my $bioentityQueryCanonical;
			my ($commonName,$canName);
			$commonName = escapeString ($hashRef->{$record}->{'bioentityComName'.$num}) if ($hashRef->{$record}->{'bioentityComName'.$num});
			$canName = escapeString($hashRef->{$record}->{"bioentityCanName".$num})if($hashRef->{$record}->{'bioentityCanName'.$num});
			
	
			
			
			
			if (!($hashRef->{$record}->{'bioentityComName'.$num}))
			{
#4,5

					$commonClause = '';
			}
			else 
			{

				$commonClause .= "\'". $commonName ."\'";
#1,2
				$bioentityQueryCommon = $bioentityQuery.$commonClause.$groupByClause;
				
			}
			if (!($hashRef->{$record}->{'bioentityCanName'.$num}))
			{
#1,2

					$canonicalClause = '';
			}
			else 
			{
					$canonicalClause .= "\'". $canName ."\'";
#4,5

					$bioentityQueryCanonical = $bioentityQuery.$canonicalClause.$groupByClause;
					print "got it";
					
			}
			
			if ($commonClause and $canonicalClause)
			{
			
				
#need to make sure we are pulling the same record
		print "$bioentityQueryCommon\n";
		
					my @rows = $sbeams->selectOneColumn($bioentityQueryCommon);	
					my $nrows = scalar(@rows);
					my $bioentityIDCommon = $rows[0] if $nrows == 1;
					$bioentityIDCommon = 0 if $nrows == 0; 
					if ($nrows >1)
					{
					print "ERROR\n";
					ErrorLog ("$SUB_NAME:\nQuery: bioentityCommonQuery returned $nrows of data!\n",
					$hashRef->{$record});
					delete $INTERACTION{$record};
					next;
					}
					print "$bioentityQueryCanonical\n";
					@rows = $sbeams->selectOneColumn($bioentityQueryCanonical);	
					$nrows = scalar(@rows);
					my $bioentityIDCanonical = $rows[0] if $nrows == 1;
					$bioentityIDCanonical = 0 if $nrows == 0; 
					if ($nrows >1)
					{
							ErrorLog ("$SUB_NAME:\nQuery: bioentityCanonicalQuery returned $nrows of data!\n",
							$hashRef->{$record});
							delete $INTERACTION{$record};
							next;
					}
					
					if ($bioentityIDCommon and !$bioentityIDCanonical)
					{  
							my $subCommonQuery = "Select bioentity_canonical_name from $TBIN_BIOENTITY
							where bioentity_common_name =\'$commonName\'";
							
							 my @returnedRow = $sbeams->selectOneColumn($subCommonQuery);
							 if ($returnedRow[0])
							 {
									 ErrorLog ("$SUB_NAME:<br>Database Query: subCommonQuery returned bioentity_canonical_Name:<br><b>$returnedRow[0]</b> for bioenity_common_Name: <b>$hashRef->{$record}->{'bioentityComName'.$num}</b>.<br>The upload canonical name is:<b>$hashRef->{$record}->{'bioentityCanName'.$num}</b>",
									 $hashRef->{$record});
									 delete $INTERACTION{$record};
									 next;
							 }
					}
					elsif (!$bioentityIDCommon and $bioentityIDCanonical)
					{
							my $subCanonicalQuery = "Select bioentity_common_name from $TBIN_BIOENTITY
							where bioentity_common_name = \'$canName\'"; 
							my @returnedRow = $sbeams->selectOneColumn($subCanonicalQuery);
							if ($returnedRow[0])
							{
									ErrorLog ("$SUB_NAME:<br>Database Query: subCanonicalQuery returned bioentity_common_Name:<br><b>$returnedRow[0]</b> for bioentity_canonical_Name: <b>$hashRef->{$record}->{'bioentityCanName'.$num}<b>. The upload common name is: <b>$hashRef->{$record}->{'bioentityComName'.$num}</b><br><br>",
									$hashRef->{$record});
									delete $INTERACTION{$record};
									next;
							}
					}
					
					if (($bioentityIDCommon eq $bioentityIDCanonical)
							or ($bioentityIDCanonical and $bioentityIDCommon ==0) or ($bioentityIDCommon and $bioentityIDCanonical ==0))
					{
							print "Identical bioentity_Id:\n";
#need to use bioentity_id = 0 unless one of them is defined and set $insert and $update
							$bioentityIDCommon=$bioentityIDCanonical unless ($bioentityIDCommon);	
							$insert = 1 unless ($bioentityIDCommon);
							$update = 0 unless (!$insert);
							 							 
#If one or no row was fetched, do a update or insert based on the presence of bioentityID
							
							
							my $bioentityPK = insertOrUpdateBioentity($hashRef->{$record},$num,$bioentityIDCommon,$insert,$update); 
########do an insert or update for bioentity reg features##############
#							if $bioentityPK
#							{
#							}
################							
							if($INTERACTION{$record} and $bioentityPK)
							{	
								$INTERACTION{$record}->{'bioentityID'.$num} = $bioentityPK;
							}
							next;
					}
#ids returned are different from each other, something is seriously wrong, write to the errorlog
					else
					{
							ErrorLog("$SUB_NAME:\n Query:  bioentityQueryCommon and bioentityQueryCanonical returned bioentity_id:\n Common:  $bioentityIDCommon and Canonical: $bioentityIDCanonical !\n\n",
							$hashRef->{$record});
							delete $INTERACTION{$record};
							next;
					}
			}
			elsif ($commonClause and !$canonicalClause)
			{
					print "only bioentity_common_name is known\n";
					print "$bioentityQueryCommon\n";
					my @rows = $sbeams->selectOneColumn($bioentityQueryCommon);	
					my $nrows = scalar(@rows);
					my $bioentityIDCommon = $rows[0] if $nrows == 1;
					$bioentityIDCommon = 0 if $nrows == 0; 
					if ($nrows >1)
					{
							ErrorLog ("$SUB_NAME:\nQuery: bioentityCommonQuery returned $nrows of data!\n",
							$hashRef->{$record});
							delete $INTERACTION{$record};
							next;
					}
					$insert = 1 unless ($bioentityIDCommon);
					$update = 0 unless (!$insert);
					
					my $bioentityPK = insertOrUpdateBioentity($hashRef->{$record},$num,$bioentityIDCommon,$insert,$update); 
					if($INTERACTION{$record} and $bioentityPK)
					{	
							$INTERACTION{$record}->{'bioentityID'.$num} = $bioentityPK;
					}
					next;
  				
			}
			else 
			{
					print "only bioentity_canonical_name is known\n";
					my @rows = $sbeams->selectOneColumn($bioentityQueryCanonical);	
					my $nrows = scalar(@rows);
					my $bioentityIDCanonical = $rows[0] if $nrows == 1;
					$bioentityIDCanonical = 0 if $nrows == 0; 
					if ($nrows >1)
					{
							ErrorLog ("$SUB_NAME:\nQuery: bioentityCommonQuery returned $nrows of data!\n",
							$hashRef->{$record});
							delete $INTERACTION{$record};
							next;
					}
					$insert = 1 unless ($bioentityIDCanonical);
					$update = 0 unless (!$insert);
					
					my $bioentityPK = insertOrUpdateBioentity($hashRef->{$record},$num,$bioentityIDCanonical,$insert,$update); 
					if($INTERACTION{$record} and $bioentityPK)
					{	
							$INTERACTION{$record}->{'bioentityID'.$num} = $bioentityPK;
					}
					next;
  				
			}
	} #foreach
}	#sub checkPopulateBioentity


sub insertOrUpdateBioentity
{
		my ($record,$num,$bioentityID,$insert,$update) = @_;
		if($insert)
		{
				print "inserting a BIOENTITY\n";
		}
		else 
		{
				print "updating BIOENTITY: $bioentityID\n";
		}
		
		
		
		my %rowData;
		$rowData{bioentity_common_name} = escapeString($record->{'bioentityComName'.$num}) if ($record->{"bioentityComName".$num});	
		$rowData{bioentity_canonical_name} = escapeString($record->{'bioentityCanName'.$num}) if ($record->{"bioentityCanName".$num});	
		$rowData{bioentity_Full_Name} = escapeString($record->{'bioentityFullName'.$num}) if ($record->{"bioentityFullName".$num});
		$rowData{bioentity_canonical_gene_name} = escapeString($record->{'bioentityCanGeneName'.$num}) if ($record->{"bioentityCanGeneName".$num});
		$rowData{bioentity_Aliases} = escapeString($record->{'bioentityAliasName'.$num}) if ($record->{"bioentityAliases".$num});
		$rowData{bioentity_location}= escapeString($record->{'bioentityLoc'.$num}) if ($record->{"bioentityLoc".$num});
		
		if ($insert)
		{					 
				$rowData{bioentity_type_id}= $bioentityType->{$record->{'bioentityType'.$num}};
				$rowData{organism_id} = $organismName->{$record->{'organismName'.$num}};
##############################################################
##############################################################
=comment
#need to insert a group - organism association
#only need to check this if there was an insert of an bioentity
#FOR THIS TO TAKE EFFECT WE NEED TO CHANGE SOME CONSTRAINS ON THE INTERACTION_GROUP TABLE
#FOR NOW WE STOP PROCESSING THE RECORD IF WE ENCOUNTER A MISSING INTERACTION_GROUP_ID	
			my $interactionGroupQuery = qq /select interaction_group_id from $TBIN_INTERACTION_GROUP
				where interaction_group_name = '$record->{group}' 
				and organism_id = $organismName->{$record->{'organismName2'.$num}}/;		
				my %groupRowData;
				$groupRowData{organism_id} = $organismName->{$record->{'organismName2'.$num}};
				$groupRowData{interaction_group_name} =  $record->{group};
				if(!scalar($sbeams->selectOneColumn($interactionGroupQuery)))
				{
						my $groupUpdate = 0; 
						my $groupInsert = 1;
						my $interactionGroupID = 0;
						
						my $groupReturned_PK = $sbeams->updateOrInsertRow(
							insert => $groupInsert,
							update => $groupUpdate,
							table_name => "$TBIN_INTERACTION_GROUP",
							rowdata_ref => \%rowData,
							PK => "interaction_group_id",
							PK_value => $interactionGroupID,
							return_PK => 1,
							verbose=>$VERBOSE,
							testonly=>$TESTONLY,
							add_audit_parameters => 1
							);
				}
=cut
#############################################################
#############################################################
	}
	
########testing	
#	if ($rowData{bioentity_common_name} eq 'MD-2'){
#			foreach my $key (keys %rowData)
#			{
#					print "$key --- $rowData{$key}\n";
#			getc;}
#	}
#########	
			

		my $returned_PK = $sbeams->updateOrInsertRow(
				insert => $insert,
				update => $update,
				table_name => "$TBIN_BIOENTITY",
				rowdata_ref => \%rowData,
				PK => "bioentity_id",
				PK_value => $bioentityID,
				return_PK => 1,
				verbose=>$VERBOSE,
				testonly=>$TESTONLY,
				add_audit_parameters => 1
				);
		
		return $returned_PK;
		
#need to insert a group - organism association
#only need to check this if there was an insert of an bioentity 		
		
}

		
sub checkPopulateInteraction
{
	my $hashRef = shift;
	my $SUB_NAME = "$0::checkPopulateInteraction";
			
	foreach my $record (keys %{$hashRef}) 
	{
			
			my $update = 1; 
			my $insert = 0;
			my $interactionQuery = qq / select Interaction_id from $TBIN_INTERACTION I
			where bioentity1_id = $hashRef->{$record}->{bioentityID1} and 
			bioentity2_id = $hashRef->{$record}->{bioentityID2}/;
						
			my @rows = $sbeams->selectOneColumn($interactionQuery);	
			my $nrows = scalar(@rows);
			my $interactionID = $rows[0] if $nrows == 1;
			$interactionID = 0 if $nrows == 0; 
			if ($nrows >1)
			{
					ErrorLog ("$SUB_NAME:\nQuery: interactionQuery returned $nrows of data!\n",
					$hashRef->{$record});
					next;
			}
			$insert = 1 unless ($interactionID);
			$update = 0 unless (!$insert);
#If one or no row was fetched, do a update or insert based on the presence of bioentityID
			my $interactionPK = insertOrUpdateInteraction($hashRef->{$record},$interactionID,$insert,$update)	if ($nrows ==1 or $nrows ==0);
			next;
			
	}
}


sub insertOrUpdateInteraction
{
		my($record,$interactionID,$insert,$update) = @_;
		if($insert)
		{
				print "inserting an INTERACTION\n: $record->{bioentityID1}  ====  $record->{bioentityID2}\n";
		}
		else 
		{
				print "updating INTERACTION: $interactionID\n";
		}
		print "  $record->{pubMedID}";
		my %rowData; 
		$rowData{interaction_group_id} = $interactionGroups->{$record->{group}} if ($record->{group});
		$rowData{bioentity1_id} = $record->{bioentityID1};
		$rowData{bioentity1_state_id} = $bioentityState->{$record->{bioentityState1}} if ($record->{bioentityState1});
#		$rowData{regulatory_feature1_id} = $regTypes->{$record->{bioentityReg1}} if ($record->{bioentityReg1});
		$rowData{interaction_type_id} = $interactionTypes->{$record->{interType}};
		$rowData{bioentity2_id} = $record->{bioentityID2};
		$rowData{bioentity2_state_id} = $bioentityState->{$record->{bioentityState1}} if ($record->{bioentityState1});
#		$rowData{regulatory_feature2_id} = $regTypes->{$record->{bioentityReg1}} if ($record->{bioentityReg1});
		$rowData{assay_id} = $assayTypes->{$record->{assay_type}} if ($record->{assay_type}); 
		$rowData{confidence_score_id} = $confidenceScores->{$record->{confidence_score}} if ($record->{confidence_scores});
		$rowData{interaction_name} = $record->{interactionName} if ($record->{interactionName});
		$rowData{interaction_description} = escapeString($record->{interaction_description}) if ($record->{interaction_description});		
		$rowData{assay_id} = $assayTypes->{$record->{assay_type}} if($record->{assay_type});
		$rowData{publication_id} = $record->{pubMedID} if ($record->{pubMedID});
		
		my $returned_PK = $sbeams->updateOrInsertRow(
				insert => $insert,
				update => $update,
				table_name => "$TBIN_INTERACTION",
				rowdata_ref => \%rowData,
				PK => "interaction_id",
				PK_value => $interactionID,
				return_PK => 1,
				verbose=>$VERBOSE,
				testonly=>$TESTONLY,
				add_audit_parameters => 1
				);
		return $returned_PK;
}
	
#specifies data input errors
sub  Error
{
		my($arrayRef,$error) = @_;
#	foreach my $column (@$arrayRef)
#{
#	print $fhError "$column\t";
				
#	}
#	print $fhError "$error\n";
		print $fhError join "\t", (@$arrayRef);
	  print $fhError "\t$error\n";

}
#specifies Database errors
sub ErrorLog
{
		my ($error,$record) = @_;
		foreach my $key (keys %{$record})
		{
				print $fhLog "\n$key  ===  $record->{$key}<br>\n";
		}
		print $fhLog "\n\n$error<br><br>\n\n";
		
}	


sub escapeString {
      my $word = $_[0];
      return undef unless (defined($word));
      $word =~ s/\\/\\\\/g;    
      $word =~ s/\'/\'\'/g;
      $word =~ s/\"/\'\"/g;
      $word =~ s/%/\'%/g;  
			$word =~ s/\./\'\./g;
      return $word;
    }
	

__END__



 







foreach my $key (keys %INFOPROTEIN1)
{
		print "$key\n";
		foreach my $ok (keys %{$INFOPROTEIN1{$key}})
		{
				print "$INFOPROTEIN1{$key}->{$ok}\n";
		}
	#	print "$INFOPROTEIN1->{$key}->{comName1}\n";
}
