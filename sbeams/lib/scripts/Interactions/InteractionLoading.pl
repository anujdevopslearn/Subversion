#!/usr/local/bin/perl -w
use strict;
use FileHandle;
use DirHandle;
use Getopt::Long;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../../perl";
#use FreezeThaw qw( freeze thaw );

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
	$organismType, $interactionGroups,$confidenceScores,$assayTypes,$pubMed, $interactionGroupsOrganism, $fhError, $fhLog, $regTypes, %locusIDProteinHash,  %locusIDmRNAHash);
  my (%locusProteinArray, %locusmRNAArray);
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
    my %organismType = $sbeams->selectTwoColumnHash(qq /Select Upper(full_name),organism_id from $TB_ORGANISM /);
    $organismType =\%organismType;
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
	%locusIDProteinHash = $sbeams->selectTwoColumnHash( qq/Select protein, locus_id from locuslink.dbo.refseq/); 
	%locusIDmRNAHash = $sbeams->selectTwoColumnHash( qq/Select mRNA, locus_id from locuslink.dbo.refseq/); 
     
   
        
      foreach my $key (keys %locusIDProteinHash)
      {
        push @{$locusProteinArray{$locusIDProteinHash{$key}}} ,$key
      }
    
	 foreach my $key (keys %locusIDmRNAHash)
     {
        push @{$locusmRNAArray{$locusIDmRNAHash{$key}}} ,$key
     }
     
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
			Error(\@infoArray, "bioentity1_type or organism1 is not defined");
			delete $INFOPROTEIN1{$count-2};
			next;
		}
		
		if($INFOPROTEIN1{$count-2}->{bioentityCanName1} =~/(xm)|(nm)(xp)/i and $INFOPROTEIN1{$count-2}->{bioentityType1} =~ /protein/i)
        {
				$INFOPROTEIN1{$count-2}->{bioentityCanGeneName1} = $INFOPROTEIN1{$count-2}->{bioentityCanName1};
				undef($INFOPROTEIN1{$count-2}->{bioentityCanName1});
		}
		
		if($INFOPROTEIN1{$count-2}->{bioentityFullName1} =~/(xm_\d)|(nm_\d)/i and $INFOPROTEIN1{$count-2}->{bioentityType1} =~ /protein/i){
				$INFOPROTEIN1{$count-2}->{bioentityCanGeneName1} = $INFOPROTEIN1{$count-2}->{bioentityFullName1};
				undef($INFOPROTEIN1{$count-2}->{bioentityFullName1});
		}
        
          if ($INFOPROTEIN1{$count-2}->{bioentityCanName1}  !~ /^\d+$/)
         {
              my $canName = $INFOPROTEIN1{$count-2}->{bioentityCanName1};
              delete$INFOPROTEIN1{$count-2}->{bioentityCanName1};
              push @{$INFOPROTEIN1{$count-2}->{bioentityCanName1}},$canName;
          }     
        
        
        
# Not implemented 		
#		if($INFOPROTEIN1{$count-2}->{bioentityReg1} and !($regTypes->{$INFOPROTEIN1{$count-2}->{bioentityReg1}}))
#		{
#				Error (\@infoArray," $INFOPROTEIN1{$count-2}->{bioentityReg1}: no such type in  $TBIN_REGULATOR_FEATURE_TYPE table");
#				delete $INFOPROTEIN1{$count-2};
#				next;
#		}
#
		if ($INFOPROTEIN1{$count-2}->{group} and !$interactionGroups->{$INFOPROTEIN1{$count-2}->{group}})
		{
				Error (\@infoArray," $INFOPROTEIN1{$count-2}->{group}: this group is not in $TBIN_INTERACTION_GROUP table");
				delete $INFOPROTEIN1{$count-2};
				next;
		}
#need to make sure that a group is associated with this organism
		my @rows;
		my $interactionGroupQuery = qq /select interaction_group_id from $TBIN_INTERACTION_GROUP
		where interaction_group_name ='$INFOPROTEIN1{$count-2}->{group}' 
		and organism_id = $organismName->{$INFOPROTEIN1{$count-2}->{organismName1}}/;
		@rows = $sbeams->selectOneColumn($interactionGroupQuery);					
		if ($INFOPROTEIN1{$count-2}->{group} and !(scalar(@rows)))
		{
				
				Error (\@infoArray," $INFOPROTEIN1{$count-2}->{group}: this group is not associated with the given organism in $TBIN_INTERACTION_GROUP table");
				delete $INFOPROTEIN1{$count-2};
				next;
		}
		else
		{
			$INFOPROTEIN1{$count-2}->{group} =  $rows[0];
		}
		
		
		
		if ($INFOPROTEIN1{$count-2}->{bioentityCanName1} =~ /^\d+$/ and ($INFOPROTEIN1{$count-2}->{bioentityType1} =~ /protein/i  or  $INFOPROTEIN1{$count-2}->{bioentityType1} =~ /molecul/i))
		{
			my $locusID = 	$INFOPROTEIN1{$count-2}->{bioentityCanName1};
            print "1locusid:  $locusID\n";
         
			delete$INFOPROTEIN1{$count-2}->{bioentityCanName1};
            if (defined ($locusProteinArray{$locusID}))
            {
                push @{$INFOPROTEIN1{$count-2}->{bioentityCanName1}}, @{$locusProteinArray{$locusID}};
               # foreach my $key (@{$INFOPROTEIN1{$count-2}->{bioentityCanName1}})
               # {
                #     print "this is iiii $key\n";
               # }
               
             }
              else
			{
                 push @{$INFOPROTEIN1{$count-2}->{bioentityCanName1}},$locusID;                 
				 Error (\@infoArray, "$locusID  could not find PROTEIN for this locusID");
				
			}
		}
      
        
		if ($INFOPROTEIN1{$count-2}->{bioentityCanName1} =~ /^\d+$/ and $INFOPROTEIN1{$count-2}->{bioentityType1} =~ /dna/i )
		{
			my $locusID = 	$INFOPROTEIN1{$count-2}->{bioentityCanName1};
			delete$INFOPROTEIN1{$count-2}->{bioentityCanName1};
             if (defined ($locusmRNAArray{$locusID}))
             {
               push @{$INFOPROTEIN1{$count-2}->{bioentityCanName1}}, @{$locusmRNAArray{$locusID}};
             }
             else
			{
			     push @{$INFOPROTEIN1{$count-2}->{bioentityCanName1}},$locusID;     
				Error (\@infoArray," $locusID: could not find RNA for this locusID");
			}
			
		}
         if (ref($INFOPROTEIN1{$count-2}->{bioentityCanName1}) eq "SCALAR")
        {
            my $scalar = $INFOPROTEIN1{$count-2}->{bioentityCanName1}; 
            delete$INFOPROTEIN1{$count-2}->{bioentityCanName1};
            push @{$INFOPROTEIN1{$count-2}->{bioentityCanName1}},$scalar;
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
       $INFOPROTEIN2{$count-2}->{bioentityCanName2} =~ s/^\s*(\d+)\s*$/$1/;
        print "aa$INFOPROTEIN2{$count-2}->{bioentityCanName2} aa\n";
        print "tt$INFOPROTEIN2{$count-2}->{bioentityType2} tt\n";
        ;
			
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
         if ($INFOPROTEIN2{$count-2}->{bioentityCanName2} !~ /^\d+$/)
         {
              my $canName = $INFOPROTEIN2{$count-2}->{bioentityCanName2};
              delete$INFOPROTEIN2{$count-2}->{bioentityCanName2};
              push @{$INFOPROTEIN2{$count-2}->{bioentityCanName2}},$canName;
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
		@rows = $sbeams->selectOneColumn($interactionGroupQuery);					
		if ($INFOPROTEIN2{$count-2}->{group} and !(scalar(@rows)))
		{
				Error (\@infoArray,"$INFOPROTEIN2{$count-2}->{group}: this group is not associated with the given organism in $TBIN_INTERACTION_GROUP table");
				delete $INFOPROTEIN2{$count-2};
				next;
		}
		else
		{
			$INFOPROTEIN2{$count-2}->{group} =  $rows[0];
		}
		
		if ($INFOPROTEIN2{$count-2}->{bioentityCanName2} =~ /^\d+$/ and 
        ($INFOPROTEIN2{$count-2}->{bioentityType2} =~ /protein/i  or  $INFOPROTEIN2{$count-2}->{bioentityType1} =~ / molecul/i))
		{
			my $locusID = $INFOPROTEIN2{$count-2}->{bioentityCanName2};
             print "locus2 $locusID\n";
              
            if( $locusID =~ /3958/){
              print "lsocus: $locusID\n";
              
            }
			delete$INFOPROTEIN2{$count-2}->{bioentityCanName2};
             if (defined ($locusProteinArray{$locusID}))
             {
               push @{$INFOPROTEIN2{$count-2}->{bioentityCanName2}}, @{$locusProteinArray{$locusID}};
             }
             
			else
            #( ! $INFOPROTEIN2{$count-2}->{bioentityCanName2})
			{
                 push @{$INFOPROTEIN2{$count-2}->{bioentityCanName2}},$locusID;           
			#	$INFOPROTEIN2{$count-2}->{bioentityCanName2} = $locusID;
				Error  (\@infoArray, "$locusID could not find PROTEIN for this locsuID");
				#delete $INFOPROTEIN2{$count-2};
				#next;
			}
		}
    				
		if ($INFOPROTEIN2{$count-2}->{bioentityCanName2} =~ /^\d+$/ and $INFOPROTEIN2{$count-2}->{bioentityType2} =~ /dna/i )
		{
          
        
			my $locusID = $INFOPROTEIN2{$count-2}->{bioentityCanName2};
			delete$INFOPROTEIN2{$count-2}->{bioentityCanName2};
            if (defined ($locusmRNAArray{$locusID}))
            {
              push @{$INFOPROTEIN2{$count-2}->{bioentityCanName2}} , @{$locusmRNAArray{$locusID}};
            }
            else
            #if ( ! $INFOPROTEIN2{$count-2}->{bioentityCanName2})
			{
                 push @{$INFOPROTEIN2{$count-2}->{bioentityCanName2}},$locusID;     
			#	$INFOPROTEIN2{$count-2}->{bioentityCanName2} = $locusID;
				Error  (\@infoArray,"$locusID: could not find  RNA for this locsuID");
				#delete $INFOPROTEIN2{$count-2};
				#next;
			}
		}
	
        if (! ref($INFOPROTEIN2{$count-2}->{bioentityCanName2}))
        {
          
          my $scalar = $INFOPROTEIN2{$count-2}->{bioentityCanName2}; 
          delete$INFOPROTEIN2{$count-2}->{bioentityCanName2};
           push @{$INFOPROTEIN2{$count-2}->{bioentityCanName2}},$scalar;
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
		$INTERACTION{$count-2}->{organismName} =  $infoArray[$interactionHash{'organismName2'}];
		print "$INTERACTION{$count-2}->{organismName}\n";
		
		$INTERACTION{$count-2}->{'group'} = $infoArray[$interactionHash{'group'}];
		$INTERACTION{$count-2}->{'group'} =~ s/[\s+\n+\t+\r+]$//g;
		$INTERACTION{$count-2}->{'group'} =~ s/^[\s+\n+\t+\r+]//g;
#      $NTERACTION{$count-2}->{group} =~ s/^([a-z]+)\s+([a-z]+)$/$1 $2/i;
	#	$INTERACTION{$count-2}->{confidence_score} =~ s/\s*//g;
		$INTERACTION{$count-2}->{group}= uc($INTERACTION{$count-2}->{group});
		
		my @row = $sbeams->selectOneColumn ("select interaction_group_id from $TBIN_INTERACTION_GROUP i 
		join $TB_ORGANISM sb on i.organism_id = sb.organism_id 
		where i.interaction_group_name = \'$INTERACTION{$count-2}->{group}\'
		and (sb.organism_name = 	\'$INTERACTION{$count-2}->{organismName}\'
		or common_name = 	\'$INTERACTION{$count-2}->{organismName}\'
		or full_name =	\'$INTERACTION{$count-2}->{organismName}\' ) ");
		$INTERACTION{$count-2}->{group}  = $row[0];   
		print " $INTERACTION{$count-2}->{group}\n";
		
		 if (! $INTERACTION{$count-2}->{group})
		 {
			 print "Detected error: Interactiongroup is not specified\n";
			Error(\@infoArray, "interactionType is not specified");
			delete $INTERACTION{$count-2};
			next;
		 }
	
		
		$INTERACTION{$count-2}->{'interType'} = 'Protein-DNA'  if $INTERACTION{$count-2}->{'interType'} eq 'pd';		
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
#		if 7($INTERACTION{$count-2}->{bioentityReg2} and !($regTypes->{$INTERACTION{$count-2}->{bioentityReg2}}))
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
;
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
					 
        #             foreach my $key (keys %pubRowData)
        #             {
        #               print "$key === $pubRowData{$key}\n";
        #            }
        #             getc;
                     
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
			and IG.interaction_group_id = \'$hashRef->{$record}->{'group'}\'";

			my $commonClause =  qq / and BE.bioentity_common_name = /;
			my $canonicalClause = qq / and bioentity_canonical_name in (  /;
			my $groupByClause = qq / group by BE.bioentity_id/;
			my $bioentityQueryCommon; 
			my $bioentityQueryCanonical;
			my ($commonName,$canName);
            
             print "this is the canName before: @{$hashRef->{$record}->{'bioentityCanName'.$num}}\n";;
            
            $commonName =$hashRef->{$record}->{'bioentityComName'.$num} if ($hashRef->{$record}->{'bioentityComName'.$num});
           $commonName = escapeString ($hashRef->{$record}->{'bioentityComName'.$num}) if ($hashRef->{$record}->{'bioentityComName'.$num});
           $canName = join ', ' ,(map{escapeString($_)} @{$hashRef->{$record}->{'bioentityCanName'.$num}}) if($hashRef->{$record}->{'bioentityCanName'.$num});
             print "this is the canName after:  $canName\n";
           if (!($hashRef->{$record}->{'bioentityComName'.$num}))
			{
#4,5

					$commonClause = '';
			}
			else 
			{

				$commonClause .= $commonName;
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
					$canonicalClause .= $canName .")";
#4,5

					$bioentityQueryCanonical = $bioentityQuery.$canonicalClause.$groupByClause;
			}
			
			if ($commonClause and $canonicalClause)
			{
			
#the canonicalClause may  have an array canonicalNames
#check how many records came back
#if number of records > 1 
#do the common query , 
#check if the bioentitycaname is also in the array of canonicalNames, +ose ids are matching 
#if no ids are matching
 
            
				
#need to make sure we are pulling the same record
                    

					my @rows = $sbeams->selectOneColumn($bioentityQueryCommon);	
				
					my $nrows = scalar(@rows);
					my $bioentityIDCommon = $rows[0] if $nrows == 1;
					$bioentityIDCommon = 0 if $nrows == 0; 
					if ($nrows >1)
					{
                      
					ErrorLog ("<br>Query: bioentityCommonQuery (commonName: $commonName)<br> returned $nrows rows of data! These are possible duplicates.\n<br> No records were updated",
					$hashRef->{$record});
					delete $INTERACTION{$record};
                    }
#now we know the bioentityID from the common query					
 
                				
                   print "$bioentityQueryCanonical\n";
                  
					@rows = $sbeams->selectOneColumn($bioentityQueryCanonical);	
					$nrows = scalar(@rows);
                    my %hashID;
                    my $haveID = 0;
                    print "number of rows $nrows\n";
                    if ($nrows > 0)
                    {
                      $haveID = 1;
                      for(my $count = 0; $count < $nrows; $count ++)
                      {
                        
                        $hashID{$rows[$count]} = 1;
                      }
                    }
                    
#now we know all the possible bioentityIDs from the canonical query

#test the combinations 
#no records for canonical, one record from the commom
#if the canonical name from the common record is null or a common name then update it with the frist np or nm number of the locusid
#if is an np number try to find the match  i n the possible uploadable canonical names
#not, somehow the canonical names are do not match, write an error                       
                    print "this is haveID $haveID\n";
                   
                   if ($bioentityIDCommon  and	scalar(keys %hashID) < 1)
                    {
                      
                      my $query = "select bioentity_canonical_name from $TBIN_BIOENTITY where bioentity_id = $bioentityIDCommon";
                     @rows = $sbeams->selectOneColumn($query);
                      print "name: $rows[0]\n";
                        if ($rows[0] !~ /^n[pmu]/i)
                        {
                          print "here\n";
                          
# update the record with the first canonicalName of the array                 
                            $insert = 1 unless ($bioentityIDCommon);
							$update = 0 unless (!$insert);
                            
                            $hashRef->{$record}->{'bioentityCanName'.$num} = ${$hashRef->{$record}->{'bioentityCanName'.$num}}[0];
                            my $bioentityPK = insertOrUpdateBioentity($hashRef->{$record},$num,$bioentityIDCommon,$insert,$update); 
		
							if($INTERACTION{$record} and $bioentityPK)
							{	
								$INTERACTION{$record}->{'bioentityID'.$num} = $bioentityPK;
							}
                  
                        }
                        
                         else
                        {
                          
                          
                          
                          
                          
                          	ErrorLog ("<br>Query: bioentityCommonQuery (commonName: $commonName).<br>  $bioentityIDCommon: the bioentity_Canonical_Name ( $rows[0] ) for this organism ($hashRef->{$record}->{'organismName'.$num})
                            is not contained within the possible  upload CanonicalNames. <br> $canName<br> No records were updated<br>"  ,$hashRef->{$record} );
                           delete $INTERACTION{$record};
                        }
             
                    }
# no common ID but 1 or more canonical ID                       
                        elsif (!$bioentityIDCommon and scalar(keys %hashID) > 0)
                        {
 # update the first record encountered                         
                          $bioentityIDCommon = (sort keys(%hashID))[0];
                          $insert = 1 unless ($bioentityIDCommon);
						  $update = 0 unless (!$insert);
                            
                          $hashRef->{$record}->{'bioentityCanName'.$num} = ${$hashRef->{$record}->{'bioentityCanName'.$num}}[0];
                          my $bioentityPK = insertOrUpdateBioentity($hashRef->{$record},$num,$bioentityIDCommon,$insert,$update); 
		
						    if($INTERACTION{$record} and $bioentityPK)
							{	
								$INTERACTION{$record}->{'bioentityID'.$num} = $bioentityPK;
							}
                       
						}
# 1 common ID and one or more canonical  ID                        
                        elsif ($bioentityIDCommon and scalar(keys %hashID) >0)
                        {
                          my $found = 0;
                          MATCH:
                          foreach my $key (keys %hashID)
                          {  
                            if ($key == $bioentityIDCommon)
                            {
                                my $query = "select bioentity_canonical_name from $TBIN_BIOENTITY where bioentity_id = $key";
                                @rows = $sbeams->selectOneColumn($query);
                                $insert = 1 unless ($bioentityIDCommon);
                                $update = 0 unless (!$insert);
                                $hashRef->{$record}->{'bioentityCanName'.$num} = $rows[0];
                                 my $bioentityPK = insertOrUpdateBioentity($hashRef->{$record},$num,$bioentityIDCommon,$insert,$update); 
		
						        if($INTERACTION{$record} and $bioentityPK)
                                {	
                                  $INTERACTION{$record}->{'bioentityID'.$num} = $bioentityPK;
                                }
                         
                                 $found = 1;
                                 last MATCH if $found;; 
                            }
                          }
                          if (! $found)
                          {
                               
                                 my $idString =  join ', ', keys(%hashID);                               
                                 ErrorLog ("<br>Query: bioentityCommonQuery (commonName: $commonName).<br>  $bioentityIDCommon: this  bioentity_id  for this organism ($hashRef->{$record}->{'organismName'.$num})
                                is not contained within the possible  bioentity_ids ( $idString ) generated by the canonical query ( $canName )<br> No records were updated<br>"  ,$hashRef->{$record} );
                         
                                 delete $INTERACTION{$record};  
                          }
                        }
            }
                          
                          
			else 
			{
								
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
                    $hashRef->{$record}->{'bioentityCanName'.$num} = $rows[0];
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
;
		$rowData{bioentity_common_name} = ($record->{'bioentityComName'.$num}) if ($record->{"bioentityComName".$num});	
		$rowData{bioentity_canonical_name} =$record->{'bioentityCanName'.$num} if ($record->{'bioentityCanName'.$num});	
		$rowData{bioentity_Full_Name} = ($record->{'bioentityFullName'.$num}) if ($record->{"bioentityFullName".$num});
		$rowData{bioentity_canonical_gene_name} = ($record->{'bioentityCanGeneName'.$num}) if ($record->{"bioentityCanGeneName".$num});
		$rowData{bioentity_Aliases} = ($record->{'bioentityAliasName'.$num}) if ($record->{"bioentityAliases".$num});
		$rowData{bioentity_location}= ($record->{'bioentityLoc'.$num}) if ($record->{"bioentityLoc".$num});
		
		if ($insert)
		{					 
				$rowData{bioentity_type_id}= $bioentityType->{$record->{'bioentityType'.$num}};
				$rowData{organism_id} = $organismName->{$record->{'organismName'.$num}};
##############################################################
##############################################################

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
			
#			print "$hashRef->{$record}->{group}\n";
						
			my $update = 1; 
			my $insert = 0;
			my $interactionQuery = qq / select Interaction_id from $TBIN_INTERACTION 
			where bioentity1_id = $hashRef->{$record}->{bioentityID1} and 
			bioentity2_id = $hashRef->{$record}->{bioentityID2} /;
			
#			print "$interactionQuery\n";
						
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
		print  "group: $record->{group}\n";
		print "$interactionTypes->{$record->{interType}}\n";
		
		my %rowData; 
		$rowData{interaction_group_id} = $record->{group};
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
		print $fhError join "\t", (@$arrayRef) if defined($arrayRef); ;
	    print $fhError "\t$error\n";

}
#specifies Database errors
sub ErrorLog
{
		my ($error,$record) = @_;
		foreach my $key (keys %{$record})
		{
                if ($key =~/bioentityCanName/i)
               {
                    print $fhLog "\n$key ====  ";
                    my $name = join ', ' ,@{$record->{$key}};
                    print $fhLog "$name<br>\n";
               }
               else
               {
                 print $fhLog "\n$key  ===  $record->{$key}<br>\n";
               }
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
      $word =~ s/^\s+//;
      $word =~ s/\s+$//;
      my $escapedWord = "'".$word."'";
      return $escapedWord;
    # return $word; 
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
