#!/usr/local/bin/perl
use strict;
use File::Find;
use FindBin;
#use lib qw (../perl ../../perl);
use lib qw (/net/dblocal/www/html/sbeams/lib/perl);

use vars qw ($sbeams $VERBOSE $TESTONLY $current_username);

use SBEAMS::Cytometry;
use SBEAMS::Cytometry::Settings;
use SBEAMS::Cytometry::Tables;
use SBEAMS::Cytometry::Alcyt; 

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::Utilities;


$sbeams = new SBEAMS::Connection; 
my %fileHash; 
my( %fileIDHash, %attributeHash);

my ($day, $month, $year)  =(localtime)[3,4,5]; 
my $time = $day.$month.$year;
my $outFile; 
main();
exit;
sub main
{
		 #### Do the SBEAMS authentication and exit if a username is not returned
		 exit unless ($current_username = $sbeams->Authenticate(
		 work_group=>'Cytometry_user',
  ));


my $sql = "select filename, original_filepath from cytometry.dbo.fcs_run_test";
 %fileHash = $sbeams->selectTwoColumnHash($sql);
 my $idSql =  "select original_filepath + \'/\' + filename, fcs_run_id  from cytometry.dbo.fcs_run_test";
%fileIDHash = $sbeams->selectTwoColumnHash($idSql);

#selects all the parameters to be measured  and which have been seen before 
my $attributeSql = "select measured_parameters_name, measured_parameters_id from cytometry.dbo.measured_parameters";
 %attributeHash = $sbeams->selectTwoColumnHash($attributeSql);
 
 
my $startDir = $ARGV[0]; 
#my $startDir = "/net/cytometry/IkB-GFP/2004-06-28/";
#$startDir = "/net/db/projects/StemCell/FCS/072104/";

my ($tag) = $startDir =~ /^.*\/(.*)\/$/;


$outFile = "/users/mkorb/cytometry/Load/". $time.$tag."_loadCyt.txt";
open(LOG,"> $outFile"); 
find(\&wanted, $startDir);
doTheOtherFiles();

}

#recursing the dir
sub wanted
{
	my $file = $File::Find::name if -f;
	my $dir = $File::Find::dir;
       
	processFile($file)
	
}


# if the file exist 
#get the the key - value pairs of the parameters in the header and put them into a hash
#add the filepath as a value to the hash
#pass a ref of the hash to loadHash subroutine
#else 
# write to the log that the file was not found
sub processFile 
{
  my $fcsFile = shift;
  return if $fcsFile !~ /\.fcs$/i;
  return if $fcsFile !~ /\/\d{4}/;
  my %hash;
  print "\nNew file stats\n";
  if (-e $fcsFile)
  { 
    print "found the path for the file: $fcsFile\n";
    
    %hash = get_fcs_key_value_hash_from_file($fcsFile);
    $hash{File} = $fcsFile;
     my $fcsRunID = loadHash(\%hash);
     
   }
  else 
  {
    print LOG "file does not exist:   $fcsFile\n";
    print " $fcsFile ===  could not find it\n";
  }
}
  
  
  
# determines the project_id based on the filepath
# tests if  data about this file already exists in the table fcs_run
# if not then uses value from the header of the file ($hashRef) and inserts it to fields in fcs_run
# the pk is returned
# the file path and pk is passed to the getDataPoints subroutine
# else
# test if we have data points about this file in the table data_points 
# if yes do nothing
# else
# the file path and pk is passed to the getDataPoints subroutine
sub loadHash 
{  
    my $hashRef = shift; 
    my ($dirName,$fileName) = $hashRef->{File} =~ /(.*)\/(.*)$/;
    my $project_id;
    $project_id = 397; 
    $project_id = 409  if $hashRef->{File} =~ /IkB-GFP/i;
#file in fcs_run ?   
     if ($fileHash{$fileName} ne $dirName) 
     {
       
       my %insertRecord;
       my $tableName = "cytometry.dbo.fcs_run_test";
       my $pkName = "fcs_run_id";
       print LOG "inserting record:  $hashRef->{File}\n";     
       $insertRecord{fcs_run_Description} =  $hashRef->{'$SMNO'}." ". $hashRef->{'$CYT'}." ". $hashRef->{'$P4N'}." " . $hashRef->{'$P5N'};
       $insertRecord{sample_name} = $hashRef->{'$CELLS'};
       $insertRecord{project_designator} = $hashRef->{'$PROJ'};
       $insertRecord{n_data_points} = $hashRef->{'$TOT'};
       $insertRecord{filename} = $fileName;
       $insertRecord{original_filepath} = $dirName;
       $insertRecord{run_date} =  $hashRef->{'$DATE'};
       $insertRecord{organism_id} = 2;
       $insertRecord{project_id} = $project_id;
        my $record = insertRecord (\%insertRecord , $tableName, $pkName);
        print LOG "PK:   $record\n";
        print "created fcs_run record: $fileName ---- $record\n";
#load the datapoints (the path to the file, the primary key 
        getDataPoints($hashRef->{File}, $record)
    }
#file in fcs_run, do we have data in data_points?    
    else 
    {
       my $query = "Select  frp.fcs_run_id   from cytometry.dbo.fcs_run_parameters  frp
       join cytometry.dbo.fcs_run_test fr on frp.fcs_run_id = fr.fcs_run_id 
	    where fr.fcs_run_id = $fileIDHash{$hashRef->{File}} group by frp.fcs_run_id";
       my @rows = $sbeams->selectOneColumn($query);
       my $fileID = $rows[0] if scalar(@rows == 1);
#yes we do , do nothing
	     if ($fileID) 
       {
          print "File and datapoints already exist:  $hashRef->{File} \n";
          print LOG "File and datapoints already exist:  $hashRef->{File} \n";
          delete $fileIDHash{$hashRef->{File}};
          return;
       }
#no we don't  therefor get the data       
       else
       {
          getDataPoints($hashRef->{File}, $fileIDHash{$hashRef->{File}});
          delete $fileIDHash{$hashRef->{File}};
       }
    }
}  
  


 
# -----------------------------------------------------------------------------------------------------------
# get the values of the $P[0-9]N keys
# test if we have such a parameter in the measured_parameters table
# if we do not, add it,  get the pK back and add it to the attribute hash (attributeHash{measured_parameters_name} = pk)
# add the mesured_parameter_name and its column position in the file to the %inpars Hash
# after we are done looping through the $P[0-9]N keys 
# pass the fcs_run_id, filepath, headerValue[3], 2, number of parameters, total_number of events, %inpars Hash to the recordDataPoints subroutine
 sub getDataPoints
{
	my %args = @_;

	my $infile = shift; 
  my $filePK = shift;
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
  #    print "this is the $key ---- $values{$key} ---- $position\n";
    
#need to look if we have these attributes in the table
#if we do not add then     
       if (! $attributeHash{$values{$key}})
       {
           my %dataHash; 
           my $tableName = "cytometry.dbo.measured_parameters";
           my $pkName = "measured_parameters_id";
           $dataHash{measured_parameters_name} = $values{$key};
           my $record = insertRecord (\%dataHash , $tableName, $pkName);
           print " Creating a new measured_parameters record for: $values{$key}  ----- $record\n"; 
           $attributeHash{$values{$key}} = $record
         }
     
        
        $inpars{$values{$key}} = $position; #measured_parameters_name (blue, red...) = position, 
        $parsPosPk{$position} = $attributeHash{$values{$key}};  # position = PK of the measured_parameters_name (measured_parameters_id)
	#   $inParsParam{$optionHash{$values{$key}}} = $1;
		  }
	  }
    my $num_events = $values{'$TOT'};
    #print "<br><b>Number of events:</b> $num_events\n<br>";
    my $num_par =  $values{'$PAR'};
    
   # insert fcs_run_id and measured_parameters_id into fcs_run_parameters
      my $tableName = "cytometry.dbo.fcs_run_parameters";
      my $pkName = " fcs_run_parameters_id";
      foreach my $position (keys %parsPosPk)
      {
         my %dataHash; 
         $dataHash{fcs_run_id} = $filePK;
         $dataHash{measured_parameters_id} = $parsPosPk{$position};
         $parsPosPk{$position} = insertRecord(\%dataHash,$tableName, $pkName);
         print "Creating a new fcs_measured_parameters record for: $position ---- $parsPosPk{$position}\n";
       # $parsPosPk{$position} = $fcsRunParamID; 
      }
=comment      
      foreach my $key (keys %inpars)
      {
        print "$key  88888 $inpars{$key}\n";
      }
      getc;
      
       foreach my $key (keys %parsPosPk)
      {
        print "$key  88888 $parsPosPk{$key}\n";
      }
      getc;
=cut      
      
      recordDataPoints( $filePK,$infile,$header[3],2,$num_par,$num_events,\ %parsPosPk);

}
  
    
  
# the parsing code is mostly legacy code
# now we need to go through each measured_parameters in the %inpars Hash and create a record in the fcs_run_parameter table 
# and also insert the measured_parameters_id ,datapoint value into the fcs_run_datapoint table  
# 
#data2( $filePK,$infile,$header[3],2,$num_par,$num_events,%inpars);  
sub recordDataPoints
{

   my $PK = shift;
   my  $infile   = shift(@_);
   my  $offset   = shift(@_); #where the data actually starts
   my $size     = shift(@_); # not used
   my $n_params = shift(@_); #$PAR
   my $n_events = shift(@_);  # $TOT
 #  my $incol    =  shift(@_);  #keyed on measured_parameters_name = position   also pk = attributeHash{measured_parameters_name}
   my $posPk = shift(@_);  # keyed on position = fcs_run_parameters_id 
  	my ($fileName) = $infile =~ /^.*\/(.*)$/; 
    
=comment    
    print "$n_events == $n_params\n";
    
    foreach my $key (keys %{$posPk})
    {
      print "$key  ----  $posPk->{$key}\n";
    }
    getc;
=cut
    my $dummy; 
    # Read in the data, sort it out into the correct columns, and dump
    # it to the output file.
    open(FCSFILE,"$infile") or die "dump_data2: Can't find input file $infile.";
    read(FCSFILE,$dummy,$offset); # read over header and text sections.
    my $data;
    print "Creating data value records:\n number of events: $n_events\n number of param: $n_params\n";
		for (my $event_num = 1 ; $event_num <= $n_events; $event_num++) 
		{
# %event{measured_parameters_id} = data 
        my %event;
        for (my $param = 1; $param <= $n_params; $param++)
        {
 # This assumes a 16 bit data word.  Not the best way to do this.
	    		  read(FCSFILE,$data,2);
           # print "$posPk->{$param}\n";
           # getc;
            $event{$posPk->{$param}} = unpack("S",$data);  #%event{fcs_tun_parameters_id} = dataValue
        }
	
	#	my $time = $event[$incol{timelow}] + 4096 * ($event[$incol{timehigh}]);
    my $insert = 1;
		my $update = 0;
		my $pK = 0;

		  my %dataHash;
      my $tableName = "cytometry.dbo.fcs_data_point";
      my $pkName = "fcs_data_point_id";
      foreach my  $point (keys %event)
      {
        $dataHash{fcs_data_value} = $event{$point}; 
			  $dataHash{fcs_run_parameters_id} = $point; 
       # $dataHash{confirmed} = 1;
         my $pk = insertRecord(\%dataHash,$tableName, $pkName);
    	}
    }
 
	close(FCSFILE);
 }



  
sub insertRecord
{
  
  	my $hashRecord  =shift;
   	my $table =shift;;
		my $pkName = shift;
    
    my $pK = 0; 
    my $insert = 1;
    my $update = 0.;
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
						add_audit_parameters => 1
						);
						
			return $PK; 
}
  
#if there any other files in the database and there are not in the directory we know about 
#do them now  
sub doTheOtherFiles  
{
  foreach my $unKnownFile (keys %fileIDHash)
  {
    processFile($unKnownFile);
  }
}
  
  
  

