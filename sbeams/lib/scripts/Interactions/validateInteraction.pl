#!usr/local/bin/perl -w
use strict;
use lib qw (../perl ../../perl);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Interactions;
use SBEAMS::Interactions::Settings;
use SBEAMS::Interactions::Tables;

#use DBI qw(:sql_types); 
use vars qw ($DSNGLUE $DSNSBEAMS);
$DSNGLUE = "GLUE";
$DSNSBEAMS = "SBEAMS";
my $dbhGlue;
my $dbhSbeams;

my ($sbeams, $sbeamsMOD);
my %typeErrorHash; 
my %nameErrorHash;
my ($day, $month, $year)  =(localtime)[3,4,5]; 
my $time = $day.$month.$year;

    $sbeams = new SBEAMS::Connection;
    $sbeamsMOD = new SBEAMS::Interactions;
    $sbeamsMOD->setSBEAMS($sbeams);
    $sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
main();
sub main 
{
#$dbhGlue = DBI->connect("DBI:ODBC:$DSNGLUE","","") or die "can not connect $!";
#$dbhSbeams = DBI->connect("DBI:ODBC:$DSNSBEAMS", "", "")  or die "can not connect $!";
  lookUp();
  recordInfo(); 
}

sub lookUp
{
			
		my $bioOrganismQuery =  "select b.organism_id from $TBIN_BIOENTITY b
    group by b.organism_id";
  
     my $typeQuery = "select b.bioentity_type_id, bioentity_type_name from $TBIN_BIOENTITY b
    join $TBIN_BIOENTITY_TYPE bt on b.bioentity_type_id = bt.bioentity_type_id 
    group by b.bioentity_type_id, bioentity_type_name order by bt.bioentity_type_name";
		
    my $organismQuery = "select organism_id, organism_name from  sbeams.dbo.organism"; 
    
    my %organismHash;
    my %organismBioHash;
    my %typeHash;
    my %hugeDataHash;
    my %dupeHash;
    
    my %hash = $sbeams->selectTwoColumnHash($typeQuery);
    foreach my $key (keys %hash)
    {
      $typeHash{$key} = $hash{$key};
    }

    my @rows = $sbeams->selectOneColumn($bioOrganismQuery);
    foreach my $record (@rows)
    {
      $organismBioHash{$record} = 1;
    }
    
    
    my %hash = $sbeams->selectTwoColumnHash($organismQuery);
    foreach my $key (keys %hash)
    {
        if ($organismBioHash{$key})
        {
          $organismBioHash{$key} = $hash{$key}
        };
     }

=comment
###################################################
#--------- windows
		my $sth = $dbhGlue->prepare($typeQuery);
		$sth->execute();
		while (my $hashRef = $sth->fetchrow_hashref())
    {
      print "query: $hashRef->{bioentity_type_id} ---  $hashRef->{bioentity_type_name}\n";
      $typeHash{$hashRef->{bioentity_type_id}} = $hashRef->{bioentity_type_name}
    }
    
    $sth =  $dbhGlue->prepare ($bioOrganismQuery);
    $sth->execute();
    while (my $hashRef = $sth->fetchrow_hashref())
    {
      $organismBioHash{$hashRef->{organism_id}} = 1;
    }
    
    while ((my $or,my  $id) = each %organismBioHash)
    {
      print "$or == $id\n";
    } 
   
   $sth =  $dbhSbeams->prepare ($organismQuery);
   $sth->execute();
    while (my $hashRef = $sth->fetchrow_hashref())
    {
      if ($organismBioHash{$hashRef->{organism_id}})
      {
        $organismBioHash{$hashRef->{organism_id}} = $hashRef->{organism_name}
       };
    }
   while ((my $or,my  $id) = each %organismBioHash)
   {
     print "$or == $id\n";
    }
#----------- end of windows
###########################   
=cut 
 
#now get the duplicates bioentities based on the bioentity_common_name or the bioentity_canonical_name
#for each organism
my %seenHash; 
my @bioentitySelect = qw /bioentity_common_name  bioentity_canonical_name/; 

 
 foreach my $select (@bioentitySelect)
 {
   foreach my $key (keys %organismBioHash)
   {
     $key = 'NULL'  if !$key;; 

     print "$select --- $key\n";

     my $groupQuery = "select $select from $TBIN_BIOENTITY
     where organism_id = $key  and record_status = \'N\'
     group by $select
     having count( $select) >1"; 
         
    my @rows = $sbeams->selectOneColumn($groupQuery);
    foreach my $name(@rows)
    {
      push @{$dupeHash{$select}->{$key}}, $name;
    }
    
=comment
###################################
#--------- windows    
    
   $sth= $dbhGlue->prepare($groupQuery); 
     print "$groupQuery\n";
    $sth->execute();
    while (my $name = $sth->fetchrow_array())
    {
      push @{$dupeHash{$select}->{$key}}, $name;
     }
#------- end windows
#################################
=cut 
     
   }
 }
 #commonName
 #now get the complete data for the bioentity
 #if the type is different and the canonical_name the same report it
 #if the type is the same report it 
foreach my $type (keys %dupeHash)
{
  my $bioentityTypeName = 'bioentity_common_name';
  foreach my $org (keys %{$dupeHash{$type}})
  {
    print "$org\n";
    foreach my $bioentity (@{$dupeHash{$type}->{$org}})
    {
      print "$bioentity\n";
     
      my %hashIDType;
      my %hashIDName;
      my %hashTypeID;
      my %hashNameID; 
      $bioentityTypeName = 'bioentity_canonical_name' if $type == 'bioentity_common_name';      
      my $query = "Select bioentity_id, bioentity_type_id, $bioentityTypeName from $TBIN_BIOENTITY where $type = \'$bioentity\' and organism_id = $org and record_status = \'N\'";
      
      my @array = $sbeams->selectSeveralColumns($query);      
      my $count = 0; 
      while ($count < scalar(@array))
      {
        print "ddd  $array[$count]->[0] --- $array[$count]->[1]\n";
        
        $hashIDType{$array[$count]->[0]} = $array[$count]->[1]; 
        $hashIDName{$array[$count]->[0]} = $array[$count]->[2];
        $hashTypeID{$array[$count]->[1]} ->{$array[$count]->[0]} = 1;
        $hashNameID{$array[$count]->[2]}-> {$array[$count]->[0]} = 1;
        $count++;
      }
     
=comment
################################
#-------- windows     
      $sth= $dbhGlue->prepare($query); 
      
     print "$query\n";
   
      $sth->execute();
      while (my ($id, $typeId, $nameType) = $sth->fetchrow_array())
      {
        $hashIDType{$id} = $typeId; 
        $hashIDName{$id} = $bioentity;
        $hashTypeID{$typeId} ->{$id} = 1;
        $hashNameID{$bioentity}-> {$id} = 1;
      }
#---------- end windows      
###########################
=cut
      
      foreach my $ids (keys %hashIDType)
      {
#the value DNA, RNA, protein
        my $typeID = $hashIDType{$ids};
#cannonical or commonName
        my $nName = $hashIDName{$ids};     
#loop through bioentity types 
        foreach my $typeIDD (keys %hashTypeID)
        {
#loop over the bioentity ids keyed on the bioentity_type_id          
          foreach my $idd (keys %{$hashTypeID{$typeIDD}})
          {
# next if the id is same as the outer loop
#next if we alreadu seen this id            
            next if $idd == $ids;
            next if $seenHash{$ids};
# if the type of the outer bioentity_id is the same as the type of the inner bioentity_id 
#report it since either the common_name or the canonical_name are the same 
#therefore this is a duplicate             
            if ($typeIDD == $typeID)
            {
               print   " type error:  $idd === $ids\n";
              $seenHash{$ids} = $idd;
              $seenHash{$idd} = $ids;
              $typeErrorHash{$idd} = $ids;
            }
#if the types are different then make sure either the  common or canonical Name is also different
            else
            {
#loop over the ids in  hashNameID which is keyed on the particular common or canonical Name               
              foreach my $iddd (keys %{$hashNameID{$nName}})
              {
#if the ids are different report it since the common or canonical Names and but the type is different                
                if ($iddd != $ids) 
                {
                  print  "name error: $iddd  ===  $ids\n";
                  $seenHash {$ids} = $iddd;
                  $seenHash{$iddd} = $ids;
                  $nameErrorHash{$iddd} = $ids;
                }
              }
            }
          }
        }
      }
    }
  }
}
}

sub recordInfo
{ 
  my $outFile = '/users/mkorb/Interaction/dupeCheck'.$time.'_Dupe.txt';
  open (FileEx," > $outFile");
 
  print FileEx "bioentity_id\tbioentity_common_name\tbioentity_canonical_name\t bioentity_full_name\t bioentity_canonical_gene_name\t bioentity_type_name\torganism_id\n";
 
  foreach my $id1 (keys %typeErrorHash)
  {
   print "this is $id1 \n";
    
    my $query = "select bioentity_id, bioentity_common_name, bioentity_canonical_name,
bioentity_full_name, bioentity_canonical_gene_name, bioentity_type_name,organism_id
from $TBIN_BIOENTITY b
join $TBIN_BIOENTITY_TYPE bt on b.bioentity_type_id = bt.bioentity_type_id
where bioentity_id in ($id1, $typeErrorHash{$id1})";
    
    my @array = $sbeams->selectSeveralColumns($query);
    my $count = 0; 
    while ($count < scalar(@array))
    {
      my $id= $array[$count]->[0];
      my $common= $array[$count]->[1];
      my $canonical= $array[$count]->[2];
      my $full= $array[$count]->[3];
      my $gene= $array[$count]->[4];
      my $type = $array[$count]->[5];
      my $organ = $array[$count]->[6];
      print FileEx"$id\t$common\t$canonical\t$full\t$gene\t$type\t$organ\n";
      $count++;
    }
    print FileEx "\n";  
    
=comment    
#############################
#-----windows
    my $sth =$dbhGlue->prepare($query);
    $sth->execute(); 
  
  while (my ($id, $common, $canonical, $full, $gene, $type) = $sth->fetchrow_array())
  {
      print FileEx "$id\t$common\t$canonical\t$full\t$gene\t$type\n";
  }
  print FileEx "\n";
#----------------- end windows
#################################  
=cut

  
 } 
  print FileEx "\n\n";
 
 
  foreach my $id1 (keys %nameErrorHash)
 {
     my $query = "select bioentity_id, bioentity_common_name, bioentity_canonical_name,
bioentity_full_name, bioentity_canonical_gene_name, bioentity_type_name, organism_id
from $TBIN_BIOENTITY B 
join $TBIN_BIOENTITY_TYPE BT on b.bioentity_type_id = bt.bioentity_type_id
where bioentity_id in ($id1, $nameErrorHash{$id1})";

   my @array = $sbeams->selectSeveralColumns($query);
   my $count = 0; 
   while ($count < scalar(@array))
   {
      my $id= $array[$count]->[0];
      my $common= $array[$count]->[1];
      my $canonical= $array[$count]->[2];
      my $full= $array[$count]->[3];
      my $gene= $array[$count]->[4];
      my $type = $array[$count]->[5];
      my $organ = $array[$count]->[6];
      print FileEx"$id\t$common\t$canonical\t$full\t$gene\t$type\t$organ\n";
      $count++;
     
   }
    print FileEx "\n";  


=comment
########################
#------------- windows    
 my $sth =$dbhGlue->prepare($query);
  $sth->execute(); 
  
  while (my ($id, $common, $canonical, $full, $gene, $type) = $sth->fetchrow_array())
  {
    print FileEx "$id\t$common\t$canonical\t$full\t$gene\t$type\n";
  }
  print FileEx "\n";
  
#--------- end windows
##########################
=cut  
  
 }
} 
__END__
           
           
        if $hashTypeID{$typeID}->{$id}  and $hash
          
 
 #canonicalName
 #if the type is the same report it








   
}
    
__END__    
    
    my $arrayRef =  $sth->fetchall_arrayref();		
		
    foreach my $row (@$arrayRef)
		{
	#my ($id, $name) = @$row;
    $organismHash{$row->[0]} = $row->[1];
		}
    
    foreach my $key (keys %hash) 
    {
      print "$key == $hash{$key}";
    }
    
    
	}

