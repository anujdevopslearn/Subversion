use vars qw ($IN_BIOENTITY $IN_INTERACTION $IN_BIOENTITY_MEMBER);
use strict;
use DBI; 
use FileHandle;
use DirHandle;
use HMK::HmkConnection;
use Data::Dumper;
use FreezeThaw qw( freeze thaw );

my %tableHash = ('IN_BIOENTITY' => 'bioentity',
									'IN_INTERACTION' => 'interactions'
);
my (%INFOPROTEIN1,
	%INFOPROTEIN2,
	%INTERACTION);
my $MODULE = "TIR MOdule";
#here are the clomumn arrangements for the spreadsheet
#organisName1[0],bioentityComName1[1], bioentityCanName1[2], bioentityFullName1[3], bioentityAliasesName1[4],bioentityTypeName1[5],
#bioentityLoc1[6], bioentityState1[7], bioentityReg1[8],
#interactionType [9],
#organismName2[10], bioentityComName2[11], bioentityCanName2[12], bioentityFullName2[13], bioentityAliasName2[14],
#bioentityTypeName2[15], bioentityLoc2[16], bioentityState2[17], bioentityReg2[18], interaction_group[19]
#confidence_score[20], interaction_description[21], assy_name[22], assay_type[23], publication_ids[24]
my %columnHashProtein1 = (
 organismName1 => 0,
 bioentityComName1 => 1, 
 bioentityCanName1 =>	2,
 bioentityFullName1	=>	3, 
 bioentityAliasName1 =>	4,
 bioentityTypeName1 =>	5,
bioentityLoc1 =>	6);
my %columnHashProtein2 = (
organismName2	=> 10,
bioentityComName2	=>	11,
bioentityCanName2 =>	12, 
bioentityFullName2	=>	13,
bioentityAliasName2	=>	14,
bioentityTypeName2	=>	15,
bioentityLoc2	=>	16);
my %interactionHash = (
organismName1	=>	0,
bioentityComName1	=>	1,	
bioentityCanName1	=>	2,
bioentityType1	=>	5,
bioentityState1	=>	7,
bioentityReg1	=>	8,
organismName2	=>	10, 
bioentityComName2	=>	11,
bioentityCanName2	=>	12,
bioentityType2	=>	15,
bioentityState1	=>	17,
bioentityReg1	=>	18,
interType	=>	9,
group	=>	19,
comment	=>	21);


#we need the available lookups to make sure the user entered a valid name
my $recordCon = new HMK::HmkConnection;
#table, column, column
my $bioentityState = $con->lookUp("bioentity_state", "bioentity_state_id", "bioentity_state_name");  
my $bioentityType = $con->lookUp("bioentity_tpe", "bioentiy_type_id", "bioentity_type_name");
my $organismName = $con->lookUp("sbeams.dbo.organism", "organism_id", "organism_name");
my $interactionTyps = $recordCon->lookup("interaction_type", "interaction_type_id" "interaction_type_name");


#looking for a txt, tab delmited file in the current dir
#or an excel spreadsheet get the dir as a command line argument 

my $dir = $ARGV[0]			;
unless (-e $dir) 
{
	print "Starting Dir does not exist\n";
	die;
}
$dir =~ s%[\/\\]$%%;
my $sourceDir = new DirHandle $dir; 
while (defined (my $filename = $sourceDir->read()))
{
	next unless $filename =~ /txt$/;
	ProcessFile("$dir/$filename");
}


sub ProcessFile
{
	my $caseFile = shift;
	my $count = 1;
	open (INFILE, $caseFile) or die "$!";
	while (my $line = <INFILE>) 
	{ 
#do not take empty lines or the column header line
		next if $line =~ /^\n$/;
		next if $count == 1 and do {$count++};
#getting the lines and putting columnheader specified info into Hashtables
		my @infoArray;
		push @infoArray, split /\t/, $line;
		$count++;
		foreach my $column (keys %columnHashProtein1)
		{
			$INFOPROTEIN1{$count-2}->{$column} = $infoArray[$columnHashProtein1{$column}];
		}
		$INFOPROTEIN1{$count-2}->{group} = $infoArray[$interactionHash{group}];
				
		foreach my $column (keys %columnHashProtein2)
		{
			$INFOPROTEIN2{$count-2}->{$column} = $infoArray[$columnHashProtein2{$column}];
#in case there is no protein2 defined one can not add an empty protein and interaction
#however keep the count going so the the record numbers are the same across all hashes		
			 if (!defined($infoArray[$columnHashProtein2{'bioentityComName2'}])
								and (!defined($infoArray[$columnHashProtein2{'bioentityConName2'}])))
				{
						delete $INFOPROTEIN2{$count-2};
						last;
				}
		}
		$INFOPROTEIN2{$count-2}->{'group'} = $infoArray[$interactionHash{'group'}];
				
		foreach my $column (sort keys %interactionHash)
		{
				$INTERACTION{$count-2}->{$column} = $infoArray[$interactionHash{$column}];
#in case there is no interaction definded, one can not add an empty interaction 
#however keep the count going so the the record numbers are the same across all hashes
		if (!($infoArray[$interactionHash{'interType'}]))
		{
					delete $INTERACTION{$count-2};
					last;
		}
	}
}
__END__
#dupchecking on %INFOPROTEIN1
checkdupe(\%INFOPROTEIN1);
#my @columnArrayProtein1 = qw /organismName1 comName1 canName1 fullName1 alName1 typeName1 loc1/;
#my @columnArrayProtein2 = qw /organismName2 comName2 canName2 fullName2 alName2 typeName2 loc2/;
#my @interactionArray = qw/organismName1 comName1 typeName1 organismName2 comName2 typeName2 interType group/;
sub checkdupe
{
	my $hashRef = shift; 		
#first check for bioentity1
#check that the organism_name and bioentity_type_name are actually valid database entries
#if present check for an update or insert or return an error and delete the record from the interactionhash
#and go the next record
#perform a query using the common_name or canonical_name, type of bioentity and organism_name
#only one row should be returned
#if more than one return an Error
#if one: do an update
#if none: do an insert
#same with the protein2
#if we have an interaction record in which both entities appear, do an update and delete the hash record
#last insert the remaining records -from the interactionhash	
	
my $dupSql = <<SQL;	
Select BE.bioentity_common_name, BE.bioentity_canonical_name,BT.bioentity_type_name,BS.bioentity_state_name,
IG.interaction_group_name,SDO.organism_name
from bioentity BE
join bioentity_type BT on (BE.bioentity_type_id = BT.bioentity_type_id)
join interaction I on (BE.bioentity_id = I.bioentity1_id)
join interaction I2 on (BE.bioentity_id = I2.bioentity2_id)
full outer join bioentity_state BS on (I.bioentity1_state_id = BS.bioentity_state_id)
full outer join bioentity_state BS1 on (I2.bioentity2_state_id = BS1.bioentity_state_id)
join interaction_group IG on (I.interaction_group_id = IG.interaction_group_id)
join sbeams.dbo.organism SDO on (IG.organism_id = SDO.organism_id)
where (BE.bioentity_common_name = ? or BE.bioentity_canonoical_name = ?) and BT.bioentity_type_name = ?
and IG.interaction_group_name = ? and SDO.organism_name = ?
SQL

	my $sth = $recordCon->{dbh}->prepare($dupSql);
	foreach my $record (keys %{$hashRef}) 
	{
			my @rows = $recordCon->selectOneColumn($dupSql,$dupSql{$key}->{bioentityComName1},$dupSql{$key}->{bioentityConName1},
			$dupSql{$key}->{bioentityTypeName1},$MODULE, $dupSql{$key}->{organismName1});
  
			my $nrows = scalar(@rows);

#### If exactly one row was fetched, return it, do a update
  	$recordCon->insertOrUpdate(1,$record) if ($nrows == 1);
		next;
#### If nothing was returned, return 0, do an insert
  	$recordCon->insertOrUpdate(0,$record) if ($nrows == 0);
		next;
#### If more than one row was returned, write to file, delete the record from the hash
  	warn ("ERROR[$SUB_NAME]: Query: dupsql returned $nrows of data!\n
		$dupSql{$key}->{bioentityComName1}\n$dupSql{$key}->{bioentityConName1}\n
		$dupSql{$key}->{bioentityTypeName1}\n$MODULE, $dupSql{$key}->{organismName1}\n");
		delete $INTERACTION{$record};
		delete $
		
	}

}




 







foreach my $key (keys %INFOPROTEIN1)
{
		print "$key\n";
		foreach my $ok (keys %{$INFOPROTEIN1{$key}})
		{
		print "$ok\n";
		print "$INFOPROTEIN1{$key}->{$ok}\n";
		}
	#	print "$INFOPROTEIN1->{$key}->{comName1}\n";
}
