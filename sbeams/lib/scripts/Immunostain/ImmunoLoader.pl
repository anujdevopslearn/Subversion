#!/usr/local/bin/perl -w
use strict;
use FileHandle;
use DirHandle;
use Getopt::Long;
use Data::Dumper;
use FindBin;
#use FreezeThaw qw( freeze thaw );
use lib qw (../perl ../../perl);
use vars qw ($q $immunoCon %columnHeaderHash @columnIndex %easyHash $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username );

use SBEAMS::Immunostain;
use SBEAMS::Immunostain::Settings;
use SBEAMS::Immunostain::Tables;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$immunoCon = new SBEAMS::Connection;



my $PROG_NAME = $FindBin::Script;

$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n          Set verbosity level.  default is 0
  --quiet              Set flag to print nothing at all except errors
  --debug n            Set debug flag
  --testonly           If set, rows in the database are not changed or added
  --source_file XXX    Source file name from which data are to be updated
  --check_status       Is set, nothing is actually done, but rather
                       a summary of what should be done is printed

 e.g.:  $PROG_NAME --check_status --source_file 45277084.htm

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
		   "source_file:s","check_status",
		  ))
{
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG)
{
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}

	
main();
exit;
#global lookup hash
my (%tissueType,%surgProc,%clinDiag,%cellType,%cellPresenceLevel,%confHash,$fhError, %antiBody, %abundanceLevel, $lastName);

sub main
{
		 #### Do the SBEAMS authentication and exit if a username is not returned
		 exit unless ($current_username = $immunoCon->Authenticate(
		 work_group=>'Developer',
  ));

	 %columnHeaderHash = (
		0	=>	'specimen block',
		1	=>	'block antibody section index',
		2	=>	'patient age',
		3	=>	'surgical procedure',
		4	=>	'clinical diagnosis',
		5	=>	'tissue block level',		
		6	=>	'tissue block side (R/L)',
		7	=>	'block location anterior-posterior',
		8	=>	'antibody',
		9	=>	'characterization contact last name',
		10	=>	'stain intensity',	
		11	=>	'% atrophic glands at each staining intensity',
		12	=>	'% normal glands at each staining intensity',	
		13	=>	'% hyperplastic glands at each staining intensity',
		14	=>	'stain intensity',
		15	=>	'% basal cells at each staining intensity',
		16	=>	'% Stromal Fibromuscular cells at each staining intensity',
		17	=>	'% Endothelial cells at each staining intensity',
		18	=>	'% Perineural cells at each staining intensity',
		19	=>	'% Nerve Sheath cells at each staining intensity',
		20	=>	'Leukocyte abundance (rare, moderate, high, most)',
		21	=>	'Amount of cancer in section (cc)',
		22	=>	'stain intensity',
		23	=>	'% of tumor that is Gleason pattern 3',
		24	=>	'% Gleason pattern 3 cancer at each staining intensity',
		25	=>	'% of tumor that is Gleason pattern 4',
		26	=>	'% Gleason pattern 4 cancer at each staining intensity',
		27	=>	'% of tumor that is Gleason pattern 5',
		28	=>	'% Gleason pattern 5 cancer at each staining intensity',
		29	=>	'comment'
		);
		
		@columnIndex = keys (%columnHeaderHash);
		%easyHash = (
		0	=>	'sb',
		1	=>	'tsn',
		2	=>	'pa',
		3	=>	'sp',
		4	=>	'cd',
		5	=>	'tbl',		
		6	=>	'rl',
		7	=>	'blap',
		8	=>	'ab',
		9 =>	'person',
		10	=>	'si',	
		11	=>'Atrophic glands',
		12		=>'Normal glands',	
		13		=>'Hyperplastic glands',
		15	=>	'Basal Epithelial Cells',
		16		=>'Stromal Fibromuscular Cells',
		17		=>'Stromal Endothelial Cells',
		18	=>	'Stromal Perineural Cells',
		19	=>	'Stromal Nerve Sheath Cells',
		20	=>	'Stromal Leukocytes',
		21	=>	'cancer',
		23	=>	'Gleason Pattern 3 Percent',
		24	=>	'Gleason Pattern 3',
		25	=>	'Gleason Pattern 4 Percent',
		26	=>	'Gleason Pattern 4',
		27	=>	'Gleason Pattern 5 Percent',
		28	=>	'Gleason Pattern 5',
		29	=>	'comment'
		);
#getting some lookUp values		
		%tissueType = $immunoCon->selectTwoColumnHash (qq /Select tissue_type_name, tissue_type_id from $TBIS_TISSUE_TYPE/);
		%surgProc = $immunoCon->selectTwoColumnHash	(qq /Select surgical_procedure_tag, surgical_procedure_id from $TBIS_SURGICAL_PROCEDURE/);
		%clinDiag = $immunoCon->selectTwoColumnHash (qq /Select clinical_diagnosis_tag, clinical_diagnosis_id from $TBIS_CLINICAL_DIAGNOSIS/);
		%cellType = $immunoCon->selectTwoColumnHash (qq / Select cell_type_name, cell_type_id from $TBIS_CELL_TYPE/);
		%cellPresenceLevel = $immunoCon->selectTwoColumnHash (qq / Select level_name, cell_presence_level_id from $TBIS_CELL_PRESENCE_LEVEL/);
		%antiBody = $immunoCon->selectTwoColumnHash (qq / Select antibody_name, antibody_id from $TBIS_ANTIBODY/);
		%abundanceLevel = $immunoCon->selectTwoColumnHash (qq /Select abundance_level_name, abundance_level_id from $TBIS_ABUNDANCE_LEVEL/);	
#getting some default config values
	open (CONF, "ImmunoConf.conf") or die "can not find ./ImmunoConf.conf file:\n$!";
	while (my $line = <CONF>) 
	{ 	
			next if $line =~ /^#/;
			$line =~ s/[\n\r]//g;
			next if $line =~ /^\s*$/;
			my ($key,$value) = split /==/, $line;
			$confHash{$key} = $value;
	}
	close CONF;
	
	processFile ();
		
	
}


sub processFile
{

		my $sourceFile = $OPTIONS{"source_file"} || '';
		my $check_status = $OPTIONS{"check_status"} || '';
		(my $errorFile) = $sourceFile =~ /.*\/(.*)$/;
		$errorFile = "ImmunostainError_".$errorFile;
	 $fhError = new FileHandle (">/users/mkorb/Immunostain/inputData/$errorFile") or die " $errorFile  can not open $!";

	
	 
 	open (FH,"$sourceFile") or die "$sourceFile  $!";
	my $lineCount = 0;
	my $blockID = 0;
	my $slideID = 0;
	my $specimenID = 0;
	my $update = 1;
	my $insert = 0;
	my $selectFlag = 1;
	my ($gleason3,$gleason4,$gleason5,$specimenName,$sectionIndex,$stainName,$lastNamem, $abundanceLevelLeuk,$comment,$cancer);
	while (my $line = <FH>) 
	{
			next if $line =~ /^\s*$/;
	
			unless ($lineCount)
			{
				$line =~ s/[\n\r]//g;
				my @columnOrderArray = split /\t/, $line;
				foreach my $columnIndex (keys %columnHeaderHash)
				{
						$columnHeaderHash{$columnIndex} =~ s/^\s*(.*)\s*$/$1/;
						$columnOrderArray[$columnIndex] =~ s/^\s*(.*)\s*$/$1/;
						$columnOrderArray[$columnIndex] =~ s/\"//g;
						$columnOrderArray[$columnIndex] =~ s/\s+/ /g;
						next if ($columnHeaderHash{$columnIndex} eq $columnOrderArray[$columnIndex]);
						print "incorrect ColumnOrder: $columnIndex $columnHeaderHash{$columnIndex} ==== $columnOrderArray[$columnIndex] \n";
						die ;
				}
				$lineCount++;	
				next;
			}
			$lineCount++;
			print "lineCount: $lineCount\n";
			$line =~ s/[\n\r]//g;
	
#look at the row
			my @infoArray = split	/\t/, $line ;
#go to the next row if all fields are empty
			my @undefArray;
#next row if there is no data in the row
			push @undefArray ,@infoArray[0..8], @infoArray[10..12],@infoArray[14..20], @infoArray[22..27];
			my $string = "";
			$string = join "",@undefArray;
			next if $string eq '';
#put everything in a hash for easier handling
			my %infoHash;
			foreach my $keys (keys %columnHeaderHash)
			{
				next if $keys == 22;
				next if $keys == 14;
				next if ($infoArray[$keys]) eq '';
					$infoHash{$easyHash{$keys}} = $infoArray[$keys]; 
			}
			
			foreach my $key (keys %infoHash)
			{
					print "$key --- $infoHash{$key}\n";
			}
			
			
			undef($infoHash{pa}) if $infoHash{pa} eq '?';
#now fill serveral %rowdata to insert or update
#first create a rowdata for the specimenblock group
#this is the first line of a 3 line record
		if ($infoHash{sb})
		{ 
				if (!$antiBody{$infoHash{ab}})
				{
						print "no good\n";
						Error (\@infoArray,"$infoHash{ab} is not in the database");
						next;
				}	 
			($specimenName) = $infoHash{sb} =~ /^(.*\d)/;
			my $blockQuery = qq/Select specimen_block_id from $TBIS_SPECIMEN_BLOCK where specimen_block_name = \'$infoHash{sb}\'/;
				
				my @block  = $immunoCon->selectOneColumn($blockQuery);
				my $nrows = scalar(@block);
				$blockID = $block[0] if $nrows == 1;
				$blockID = 0 if $nrows == 0;
				if(!$blockID)
				{
						$update = 0;
						$insert = 1;
						
				}
#this data is the same for all 3 rows and changes only for a new antibody 				
				$gleason3 = $infoArray[23];
				$gleason4 = $infoArray[25];
				$gleason5 = $infoArray[27];
				$sectionIndex = $infoArray[1];
				$stainName = $infoHash{ab} .' '. $infoHash{sb} .' '. $infoHash{tsn};
				$lastName = $infoHash{person};
				$abundanceLevelLeuk = $infoHash{'Stromal Leukocytes'};
				$comment = $infoHash{'comment'};
				$selectFlag = 1;
		
		
		}
#make sure that the other specimen column are empty
		else 
		{
				$selectFlag = 0;
				if(defined($infoArray[0]))
				{
						Error (\@infoArray,"expect empty specimenRecord for $blockID\n");
				}
		}
#need to do the Select query and update query for the specimen block only once				
		if($selectFlag)
		{
#update specimen table
				my $specimenUpdate = 1; 
				my $specimenInsert = 0;
				my $specQuery = qq /select s.specimen_id,
				s.tissue_type_id,		
				s.surgical_procedure_id,
				s.individual_age,			
				s.organism_id,
				s.project_id,
				s.specimen_name,
				s.clinical_diagnosis_id
				from $TBIS_SPECIMEN s				
			 	where s.specimen_name = \'$specimenName\'/;


				my @specRow = $immunoCon->selectSeveralColumns($specQuery);	
				my $nrows = scalar(@specRow);
				if ($nrows > 1)
				{		
						Error (\@infoArray, "$specimenID returned $nrows rows\n");
						die;
						next;
				}
				$specimenID = $specRow[0]->[0] if $nrows == 1;
				
				if ($nrows > 1)
				{		
						Error (\@infoArray, "$specimenID returned $nrows rows\n");
						die;
						next;
				}
				$specimenID = 0 if $nrows == 0;
				if (! $specimenID)
				{
						$specimenUpdate = 0;
						$specimenInsert = 1;
				}
				
				
				my %specRowData; 
				$specRowData{tissue_type_id} = $tissueType{$confHash{tissue_type_name}} unless $specRow[0]->[1] eq $tissueType{$confHash{tissue_type_name}};
				$specRowData{surgical_procedure_id} = $surgProc{$infoHash{sp}} unless $specRow[0]->[2] == $surgProc{$infoHash{sp}};
				$specRowData{clinical_diagnosis_id} = $clinDiag{$infoHash{cd}} unless $specRow[0]->[3] == $clinDiag{$infoHash{cd}};
				$specRowData{individual_age} = $infoHash{pa} unless $specRow[0]->[5] eq $infoHash{pa};
				$specRowData{organism_id} = $confHash{organism_id} unless $specRow[0]->[4] == $confHash{organism_id};
				$specRowData{project_id} = $confHash{project_id} unless $specRow[0]->[-1] == $confHash{project_id};				
				$specRowData{specimen_name} = $specimenName if $specimenInsert;
				my $specimenReturnedPK = updateInsert(\%specRowData,$specRow[0]->[0],"specimen_id",$insert,$update,$TBIS_SPECIMEN);
									
#update the specimen_block table

				my @block = $immunoCon->selectSeveralColumns(qq /select specimen_block_level,anterior_posterior,
				specimen_block_side,protocol_id	from $TBIS_SPECIMEN_BLOCK sb 
				where sb.specimen_block_id = $blockID/ );	
						
				my %blockRowData; 
				$blockRowData{specimen_block_level} = $infoHash{bl} unless $block[0]->[0] eq $infoHash{tbl};
				$blockRowData{anterior_posterior} = $infoHash{blap} unless $block[0]->[1] eq $infoHash{blap};
				$blockRowData{specimen_block_side} = $infoHash{rl} unless $block[0]->[2] eq $infoHash{rl};
				$blockRowData{protocol_id} = $confHash{protocol_id} unless $block[0]->[3] == $confHash{protocol_id};
				$blockRowData{specimen_id} = $specimenReturnedPK;
				$blockRowData{specimen_block_name} = $infoHash{sb} if $insert; 																	
				my $blockReturnedPK =  updateInsert(\%blockRowData,$blockID,"specimen_block_id",
				$insert,$update,$TBIS_SPECIMEN_BLOCK);
#this way we can all see it				
				$blockID = $blockReturnedPK;
		
				
#now process the slides per blockID/tissue_section/antibody
		my $slideInsert= 0; 
		my $slideUpdate = 1;
		my $slideQuery =  qq / select st.stained_slide_id,st.cancer_amount_cc,
		st.project_id,st.protocol_id,st.stain_name,st.section_index,st.comment,st.antibody_id from
		$TBIS_STAINED_SLIDE st
		join $TBIS_ANTIBODY ab on st.antibody_Id = ab.antibody_id
		join $TBIS_SPECIMEN_BLOCK  sb on sb.specimen_block_id = st.specimen_block_id 
		where ab.antibody_name = \'$infoHash{ab}\' and sb.specimen_block_id = $blockID and st.section_Index = $sectionIndex/;
		my @slides  = $immunoCon->selectSeveralColumns($slideQuery);  
		
		$nrows = scalar(@slides);
		if ($nrows > 1)
		{	
				Error (\@infoArray, "$blockID returned $nrows rows\n");
				die;
				next;
		}
				
	 $slideID = $slides[0]->[0] if $nrows == 1;
	$slideID = 0 if $nrows == 0;
		my $cc = $slides[0]->[1];
		if (! $slideID)
		{
			$slideUpdate = 0;
			$slideInsert = 1;
		}
#update, insert the cancer level
		 		
		my %slideRowData; 
		print "$infoHash{ab}   ---   $antiBody{$infoHash{ab}}\n";
		$slideRowData{cancer_amount_cc} = $infoHash{cancer} if ($infoHash{cancer} ne $cc);
		$slideRowData{project_id} = $confHash{project_id} unless $slides[0]->[2] == $confHash{project_id};
		$slideRowData{protocol_id} = $confHash{protocol_id} unless $slides[0]->[3] == $confHash{protocol_id};
		$slideRowData{specimen_block_id} = $blockID;
		$slideRowData{antibody_id} = $antiBody{$infoHash{ab}} unless $slides[0]->[-1] == $antiBody{$infoHash{ab}};
		$slideRowData{stain_name} = $stainName unless $slides[0]->[4] eq $stainName;
		$slideRowData{section_index} = $sectionIndex unless $slides[0]->[5] eq $sectionIndex;
		$slideRowData{comment} = $infoHash{person} if ($slides[0]->[6] ne $infoHash{person});
		my $returnedSlidePK = updateInsert(\%slideRowData,$slideID, "stained_slide_id",$slideInsert,$slideUpdate,$TBIS_STAINED_SLIDE); 
		$slideID = $returnedSlidePK;
			
		} #end of selectFlag
		
	
#loop through all the intensity levels and cell types update if needed or do an insert				
#need to map the cell types from the database to the celltypes (column header) in the spreadsheet
		
		
		foreach my $cellLine (keys %cellType)
		{
				print "$cellLine\n";
				print "$infoHash{$cellLine}\n";
				print "$cellPresenceLevel{$infoHash{si}}\n";
		
		
				
				next if $cellLine eq 'Normal Cells';
				next if $cellLine =~ /(Luminal)|(Cancerous)/i;
				
		if (!exists($infoHash{$cellLine}))
				 {
						 print "ne\n";
				 }
				
				
				my $cellQuery;				
				my $cellUpdate = 1;
				my $cellInsert = 0;
				
				
				if ($cellLine eq 'Stromal Leukocytes') 
				{
										 $cellQuery = qq /select cp.stain_cell_presence_id, cp.stained_slide_id, cp.cell_type_id,
										 cp.cell_type_percent,cp.cell_presence_level_id,abundance_level_id, cp.at_level_percent
										 from $TBIS_STAIN_CELL_PRESENCE cp
										 inner join $TBIS_CELL_TYPE ct on cp.cell_type_id = ct.cell_type_id
										 where ct.cell_type_name = \'$cellLine\' and stained_slide_id = $slideID/;
				}
				else
				{									
									$cellQuery = qq /select cp.stain_cell_presence_id, cp.stained_slide_id, cp.cell_type_id,
									cp.cell_type_percent,cp.cell_presence_level_id,abundance_level_id, cp.at_level_percent
									from $TBIS_STAIN_CELL_PRESENCE cp
									inner join $TBIS_CELL_PRESENCE_LEVEL cpl on cp.cell_presence_level_id = cpl.cell_presence_level_id
									inner join $TBIS_CELL_TYPE ct on cp.cell_type_id = ct.cell_type_id
									where cpl.level_name = \'$infoHash{si}\' and ct.cell_type_name = \'$cellLine\' and stained_slide_id = $slideID/;
				}
									
									
									#			print "$cellQuery\n";
	#			print "$infoHash{$cellLine}\n";
	#			getc;
				my @cellPresence = $immunoCon->selectSeveralColumns($cellQuery); 
								
				if(scalar(@cellPresence) == 0)
				{
							$cellUpdate = $cellInsert;
							$cellInsert = 1;
				}
				elsif (scalar(@cellPresence)> 1)
				{
						Error(\@infoArray, "returned more than one row for this cellline: $cellLine\n");
				}
				
				
#this is good for 3 rows of data				
			if ($cellLine eq 'Stromal Leukocytes') 
			{
					$infoHash{$cellLine} = $abundanceLevelLeuk;
			
			}

					
			my %cellLineRowData;
			$cellLineRowData{stained_slide_id} = $slideID if ($cellInsert);
			$cellLineRowData{cell_type_id} = $cellType{$cellLine};# if($cellInsert);
			$cellLineRowData{cell_presence_level_id} = $cellPresenceLevel{$infoHash{si}} if($cellLine ne 'Stromal Leukocytes');
			$cellLineRowData{at_level_percent} = $infoHash{$cellLine} unless ($cellLine eq 'Stromal Leukocytes' or $infoHash{$cellLine} eq $cellPresence[0]->[-1]);
			$cellLineRowData{abundance_level_id} = $abundanceLevel{$infoHash{$cellLine}} if $cellLine eq 'Stromal Leukocytes';
			$cellLineRowData{comment} = $comment; 
	#		$abundanceLevel{$abundanceLevelLeuk} if $cellLine eq 'Stromal Leukocytes' and $abundanceLevel{$abundanceLe;
#figureing out which Gleason cell line we have and what to update or insert
			if ($cellLine =~ /^Gleason/i)
			{
					my ($num) = $cellLine =~ /\d$/;
					my $gleason = $gleason5;
					$gleason = $gleason3 unless $num == 4 or $num = 5;
					$gleason = $gleason4 unless $num == 5;
					$cellLineRowData{cell_type_percent} = $gleason unless $cellPresence[0]->[3] eq $gleason;
			}
		
#			foreach my $kk (keys %cellLineRowData) 
#		{
#				print "$kk --- $cellLineRowData{$kk}\n";
#		}
#		getc;
			my $returnedStainCellPresencePK = updateInsert(\%cellLineRowData,$cellPresence[0]->[0], "stain_cell_presence_id",$cellInsert,$cellUpdate,$TBIS_STAIN_CELL_PRESENCE); 
			
		}
							
	} #while loop
	
} #sub routine processFile()



sub updateInsert 
{
		my ($hashRef, $pK, $pkName,$insert,$update,$table) = @_;
		
			
		my $PK = $immunoCon->updateOrInsertRow(
						insert => $insert,
						update => $update,
						table_name => "$table",
						rowdata_ref => $hashRef,
						PK => "$pkName",
						PK_value => $pK,
						return_PK => 1,
						verbose=>$VERBOSE,
						testonly=>$TESTONLY,
						add_audit_parameters => 1
						);
						
			return $PK; 
}


sub Error 
{
		my($arrayRef,$error) = @_;
		print $fhError  join "\t", (@$arrayRef);
		print $fhError "\t,$error\n"; 

}
