#!/usr/local/bin/perl -w
use strict;
use File::Find;
use FindBin;
use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $VERBOSE $TESTONLY $current_username);

use SBEAMS::Connection;
use SBEAMS::Cytometry::Alcyt;
use SBEAMS::Cytometry;
use SBEAMS::Cytometry::Settings;
use SBEAMS::Cytometry::Tables;

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$sbeams = new SBEAMS::Connection; 
$sbeamsMOD = new SBEAMS::Cytometry;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

my %fileHash; 
my( %fileIDHash, %attributeHash, %paramHash , %tissueHash, %entityHash, %sortTypeHash);

my ($day, $month, $year)  =(localtime)[3,4,5]; 
my $time = $day.$month.$year;
my ($outFile, $project_id); 

main();
exit;
sub main
{
  
		 #### Do the SBEAMS authentication and exit if a username is not returned
		 exit unless ($current_username = $sbeams->Authenticate(
         work_group=> 'Cytometry_admin',
  ));

;   
############################################
#change the watchDir to your watch directory
############################################
my $WATCHDIR  = "/users/mkorb/cytometry/";  

############################################
#pass the data directory and the project id 
###########################################
my $startDir = $ARGV[0] or die "no valid startDir\n";
$project_id = $ARGV[1] or die "not a valid project_id\n"; 


my ($watch) = $startDir =~ /.*\/(.*?)\/$/; 
my $watchFile = $WATCHDIR.$watch."watch";
my ($tag) = $startDir =~ /^.*\/(.*)\/$/;

####################################################
#change the Load log directory to your directory 
###################################################
my $LOGFILE = "/users/mkorb/cytometry/Load/". $time.$tag."_loadCyt.txt";
open(LOG,"> $LOGFILE") or die "can not find $LOGFILE $!";; 

################################################
#check if we have a previous watch file (maybe a large upload is happening)
#abort nicley if we do
################################################ 
eval
{
   open( File, "$watchFile") or die "can not $!"; 
} ;
close File;
print "watch file found\n" if (! $@); 
print LOG "watch file found\n" and do( exit)  if (! $@);

open (File, ">$watchFile") or die "can not open $watchFile $!";
print LOG "watch file: $watchFile\n";

##################################################################
#get some data from the database for dupe checking, lookup values and project_id
##################################################################
my $projectSql = "select name from $TB_PROJECT where project_id = $project_id";
my @projectRow = $sbeams->selectOneColumn($projectSql);
if (scalar(@projectRow)<1)
{
  print LOG "$project_id does not exist in database\n";
  print "$project_id does not exist in database\n  Upload is being aborted\n";
  close LOG; 
   exit;
}
my $tissueSql = "select lower (left (tissue_type_name,1)), tissue_type_id  from $TBCY_TISSUE_TYPE";
%tissueHash = $sbeams->selectTwoColumnHash($tissueSql);
 
my $sortTypeSql = "select upper(sort_type_abbrev), sort_type_id  from $TBCY_SORT_TYPE";
%sortTypeHash = $sbeams->selectTwoColumnHash($sortTypeSql);

my $entitySql = "select upper(sort_entity_name), sort_entity_id from $TBCY_SORT_ENTITY";
%entityHash = $sbeams->selectTwoColumnHash($entitySql);

my $sql = "select filename, original_filepath from $TBCY_FCS_RUN where project_id = $project_id";
 %fileHash = $sbeams->selectTwoColumnHash($sql);
 my $idSql =  "select original_filepath + \'/\' + filename, fcs_run_id  from $TBCY_FCS_RUN where project_id = $project_id";
%fileIDHash = $sbeams->selectTwoColumnHash($idSql);

my $attributeSql = "select measured_parameters_name, measured_parameters_id from $TBCY_MEASURED_PARAMETERS";
 %attributeHash = $sbeams->selectTwoColumnHash($attributeSql);
 
my $runParamSql = "Select fcs_run_id from $TBCY_FCS_RUN_PARAMETERS group by fcs_run_id";
my @rows = $sbeams->selectOneColumn($runParamSql);
foreach my $fileID(@rows)
{
  $paramHash{$fileID} = 1;
}    
  
  
find(\&wanted, $startDir);
unlink $watchFile; 
}
#####################################
#recursing the $start_dir
#################################### 
sub wanted
{
  	my $file = $File::Find::name if -f;
	my $dir = $File::Find::dir;
  	processFile($file)
	
}
#################################################
#LOGIC:
# if the file exist 
#get the the key - value pairs of the parameters in the header and put them into a hash
#add the filepath as a value to the hash
#pass a ref of the hash to loadHash subroutine
#else 
# write to the log that the file was not found
################################################
sub processFile 
{
  my $fcsFile = shift;
  print "this is the file to be checked: $fcsFile\n";

#################################
#do some basic checking on the file encountered
################################  
  return if ! defined($fcsFile); 
  return  if ($fcsFile !~ /\.fcs$/i);
#DATE  
  return if $fcsFile !~ /\/\d{4}/;
  my %hash;

  if (-e $fcsFile)
  { 
#####################################
#this is a call to Alcyt.pm
####################################
     print "getting all the values\n";       
    %hash = get_fcs_key_value_hash_from_file($fcsFile);
    $hash{File} = $fcsFile;
     my $fcsRunID = loadDataHash(\%hash);
     
   }
   else 
   {
     print LOG "file does not exist:   $fcsFile\n";
     print "file does not exist:   $fcsFile\n";

   }
}
  
# tests if  data about this file already exists in the table fcs_run
# if not then uses value from the header of the file ($hashRef) and inserts it to fields in fcs_run
# the pk is returned
# the file path and pk is passed to the getDataPoints subroutine
# else
# test if we have data points about this file in the table data_points 
# if yes do nothing
# else
# the file path and pk is passed to the getDataPoints subroutine
sub loadDataHash 
{  
    my $hashRef = shift; 
    my ($dirName,$fileName) = $hashRef->{File} =~ /(.*)\/(.*)$/;
    my $fileID = $fileIDHash{$hashRef->{File}};
    my $outfile = $PHYSICAL_BASE_DIR ."/data/Cytometry/".$fileID. "_". $fileName;
    print LOG  "tmp file for storing Hash variable: $outfile\n";
    print  "tmp file for storing Hash variable: $outfile\n";
    return if (-e $outfile) and do {print LOG "tmp data file already exist\n"; print "tmp file: $outfile already exists\n";};

################################
# is this file in the database ? 
################################  

     if ($fileHash{$fileName} ne $dirName) 
     {
       $fileHash{$fileName} = $dirName; 
       my %insertRecord;
       my $tableName = "$TBCY_FCS_RUN";
       my $pkName = "fcs_run_id";
       print LOG "inserting a new Record:  $hashRef->{File}\n\n";     
       print "inserting a new Record:  $hashRef->{File}\n\n";     
######################################
# getting several values from the header of the fcs file
# see the fcs file documentation in cytometry/doc      
######################################
       $insertRecord{fcs_run_Description} = $hashRef->{'$CYT'} .",  ". $hashRef->{'$P4N'} .",  " . $hashRef->{'$P5N'} ;
       $insertRecord{sortedCellType} = $hashRef->{'$CELLS'};
       
       my $sampleName = $hashRef->{'$SMNO'}; 
       my ($sortEntity,$tissueType, $sortType);
       my ($sortPK, $entityPK, $tissuePK) = 0;
####################################
# we expect a certain naming convention for the sample name
# it will not break if we don't
####################################
       if ($sampleName =~ /^\d+-\d+[pb]_[a-z]_/i)
       {
         ($sortEntity) = $sampleName =~/^.*_(.*)$/;
         ($sortType) = $sampleName =~/^._([a-z])_/i;
         ($tissueType) = $sampleName =~ /^.*?([pbt])_/i;
          if (defined ($sortEntity))
          {
            $sortPK = $entityHash{uc $sortEntity} if defined ($entityHash{uc $sortEntity});
             if (!$sortPK)
             {
               my %entityRecord;
               my $insert = 1;
               $entityRecord{sort_entity_name} = $sortEntity;
               $entityPK = insertRecord(\%entityRecord, $insert, $TBCY_SORT_ENTITY, "sort_entity_id", 1); 
             }
          }
          
          $sortPK  = $sortTypeHash{uc $sortType};
          $tissuePK = $tissueHash{lc $tissueType};
       }
######################
# insert the record 
######################               
       $insertRecord{sample_name} = $hashRef->{'$SMNO'} || 'not specified';
       $insertRecord{project_id} = $project_id;
       $insertRecord{n_data_points} = $hashRef->{'$TOT'};
       $insertRecord{operator} = $hashRef->{'$OP'};
       $insertRecord {institution} = $hashRef->{'$INST'};
       $insertRecord{comment} = $hashRef->{'$COM'};
       $insertRecord{filename} = $fileName;
       $insertRecord{original_filepath} = $dirName;
       $insertRecord{run_date} =  $hashRef->{'$DATE'};
       $insertRecord{organism_id} = 2;
       $insertRecord{project_designator} = $hashRef->{'$EXP'};
       $insertRecord{showFlag} = 1; 
       $insertRecord{sort_type_id} = $sortPK if ($sortPK);
       $insertRecord{sort_entity_id} = $entityPK if ($entityPK);
       $insertRecord{tissue_type_id} = $tissuePK if ($tissuePK) ;
        my $insert = 1;
        my $record = insertRecord (\%insertRecord , $insert,$tableName, $pkName,1);
        print LOG "created fcs_run record: $fileName ---- $record\n";
        print "created fcs_run record: $fileName ---- $record\n";
########################
#load the datapoints (passing in the path to the file, the primary key
######################## 
        getDataPoints($hashRef->{File}, $record)
    }
#####################
# file is already in fcs_run, however do we also have the data
#####################    
     else 
    {
       my $query = "Select  frp.fcs_run_id   from $TBCY_FCS_RUN_PARAMETERS  frp
       join $TBCY_FCS_RUN fr on frp.fcs_run_id = fr.fcs_run_id 
	    where fr.fcs_run_id = $fileIDHash{$hashRef->{File}} group by frp.fcs_run_id";
       my @rows = $sbeams->selectOneColumn($query);
       my $fileID = $rows[0] if scalar(@rows == 1);
       if ($fileID) 
       {
         my $tmpFile = $fileID."_".$fileName;
            if( -e "$PHYSICAL_BASE_DIR/data/Cytometry/$tmpFile")
            {
              print LOG "datapointFile already exist:  $tmpFile \n";
              print "datapointFile already exist:  $tmpFile \n";
              next;
            }
            else 
            { 
              print LOG "adding datapointFile:   $tmpFile \n";
              print "adding datapointFile:   $tmpFile \n";
              getDataPoints($hashRef->{File}, $fileID);
               
            }
              delete $fileIDHash{$hashRef->{File}};
         }
     }
}
  
  


 
# #########################
#LOGIC:
# get the values of the $P[0-9]N keys
# test if we have such a parameter in the measured_parameters table
# if we do not, add it,  get the pK back and add it to the attribute hash (attributeHash{measured_parameters_name} = pk)
# add the mesured_parameter_name and its column position in the file to the %inpars Hash
# after we are done looping through the $P[0-9]N keys 
# pass the fcs_run_id, filepath, headerValue[3], 2, number of parameters, total_number of events, %inpars Hash to the recordDataPoints subroutine
############################
 sub getDataPoints
{
	my %args = @_;

	my $infile = shift; 
    my $filePK = shift;
    my $fileName = shift;
    print LOG " added datapoints:  $infile\n";
# Strip out all of the keyword-value pairs.
	my @header = read_fcs_header($infile);	
	my @keywords = get_fcs_keywords($infile,@header);
	my %values = get_fcs_key_value_hash(@keywords);
    my %inParsParam;
    my (%inpars, %parsPosPk);
   
    
    foreach my $key (keys %values)
	{	
		if ($key =~ /\$P(\d+)N/i)
		{
            my $position = $1;
			$values{$key} =~ s/^[\s\n]+//g;
			$values{$key} =~ s/[\s\n]+$//g;
			next if $values{$key} =~ /adc/i;
            next if $values{$key} =~ /^c[lot].*/i;
            next if $values{$key} =~/^lut.*/i; 
#######################
#TEST:
# print "this is the $key ---- $values{$key} ---- $position\n";
#######################
    
#need to look if we have these attributes in the table
#if we do not add them     

         if (! $attributeHash{$values{$key}})
         {
           my $insert = 1;
           my %dataHash; 
           my $tableName = "$TBCY_MEASURED_PARAMETERS";
           my $pkName = "measured_parameters_id";
           $dataHash{measured_parameters_name} = $values{$key};
           $dataHash{project_id} = $project_id;
           my $record = insertRecord (\%dataHash ,$insert, $tableName, $pkName,1);
           print LOG" Creating a new measured_parameters record for: $values{$key}  ----- $record\n"; 
           $attributeHash{$values{$key}} = $record
         }
# position = PK of the measured_parameters_name (measured_parameters_id)   
        $inpars{$position} = $values{$key};
        $parsPosPk{$position} = $attributeHash{$values{$key}};
    
        }
	 }
    my $num_events = $values{'$TOT'};
    my $num_par =  $values{'$PAR'};
    
# insert fcs_run_id and measured_parameters_id into fcs_run_parameters
      my $tableName = "$TBCY_FCS_RUN_PARAMETERS";
      my $pkName = " fcs_run_parameters_id";
      my $paramQuery = "Select fcs_run_id from $TBCY_FCS_RUN_PARAMETERS";
      if (!$paramHash{$filePK})
      {
        foreach my $position (keys %parsPosPk)
        {
          my $insert = 1; 
          my %dataHash; 
          $dataHash{fcs_run_id} = $filePK;
          $dataHash{measured_parameters_id} = $parsPosPk{$position};
          $parsPosPk{$position} = insertRecord(\%dataHash,$insert,$tableName, $pkName,1);
           print LOG "Creating a new fcs_measured_parameters record for: $position ---- $parsPosPk{$position}\n";
          }
      }
      
      recordDataPoints( $filePK,$infile,$header[3],2,$num_par,$num_events,\ %inpars);
}

#########################
#all the data is collected into a perl variable 
#and written out to the disk. 
#the file for the variable is unique since it contains a fcs_run_id
#the variable is read in again when one displays the graph on the website
#########################


  
sub recordDataPoints
{
   my $PK = shift;
   my  $infile   = shift(@_);
   my  $offset   = shift(@_); #where the data actually starts
   my $size     = shift(@_); # not used
   my $n_params = shift(@_); #$PAR
   my $n_events = shift(@_);  # $TOT
   my $posPk = shift(@_);  # keyed on position = fcs_run_parameters_id 
  	my ($fileName) = $infile =~ /^.*\/(.*)$/; 
    $fileName = $PK."_".$fileName;
     my $outfile = $PHYSICAL_BASE_DIR ."/data/Cytometry/".$fileName;

    print LOG "writing the tempHash: $outfile \n";
    print "writing the tempHash: $outfile \n";
    my $dummy; 
# Read in the data, sort it out into the correct columns, and dump
# it to the output file.
    open(FCSFILE,"$infile") or die "dump_data: Can't find input file $infile.";
    binmode(FCSFILE);
    read(FCSFILE,$dummy,$offset); # read over header and text sections.
    my $data;
    my %event;
    for (my $event_num = 1 ; $event_num <= $n_events; $event_num++) 
	{          
# %event{measured_parameters_id} = data 
        for (my $param = 1; $param <= $n_params; $param++)
        {
 # This assumes a 16 bit data word.  Not the best way to do this.
    	  read(FCSFILE,$data,2);
           next if( !defined( $posPk->{$param}));
           push @{$event{$posPk->{$param}}}, unpack("S", $data);
        }
	}
    my $temp_hash_ref = \%event;
    open(OUTFILE,">$outfile") || die "Cannot open $outfile    $!\n";
    printf OUTFILE Data::Dumper->Dump( [$temp_hash_ref] );
    close(OUTFILE);
    close(FCSFILE);
   
 }
 
sub insertRecord
{
  
  	my $hashRecord  =shift;
    my $insert = shift;
   	my $table =shift;;
	my $pkName = shift;
    my $add = shift;
    my $pK = 0;
    my $update = 0;
    if ($insert == 1)
    {
      $update = 0;
    }
    else
    {
      $update = 1;
    };
	my $PK = $sbeams->updateOrInsertRow(
						insert => $insert,
						update => $update,
						table_name =>$table,
						rowdata_ref => $hashRecord,
						PK => $pkName,
						PK_value => $pK,
						return_PK => 1,
						verbose=>$VERBOSE,
						testonly=>$TESTONLY,
						add_audit_parameters => $add
						);
						
			return $PK; 
}

  
  
  

