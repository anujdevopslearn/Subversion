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
my %fileIDHash;
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
my ($day, $month, $year)  =(localtime)[3,4,5]; 
my $time = $day.$month.$year;
my $outFile; 
main();
exit;
sub main
{
		 #### Do the SBEAMS authentication and exit if a username is not returned
		 exit unless ($current_username = $sbeams->Authenticate(
		 work_group=>'Developer',
  ));


my $sql = "select filename, original_filepath from cytometry.dbo.fcs_run";
 %fileHash = $sbeams->selectTwoColumnHash($sql);
 my $idSql =  "select original_filepath + \'/\' + filename, fcs_run_id  from cytometry.dbo.fcs_run";
%fileIDHash = $sbeams->selectTwoColumnHash($idSql);
  
my $startDir = $ARGV[0]; 

print "$startDir\n";
my ($tag) = $startDir =~ /^.*\/(.*)\/$/;
print "$tag\n";

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



sub processFile 
{
  my $fcsFile = shift;
  return if $fcsFile !~ /\.fcs$/i;
  return if $fcsFile !~ /\/\d{4}/;
  my %hash;
  
  if (-e $fcsFile)
  { 
    print "this is: $fcsFile\n";
    
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
  
  
sub loadHash 
{  
    my $hashRef = shift; 
    my ($dirName,$fileName) = $hashRef->{File} =~ /(.*)\/(.*)$/;
    my $project_id;
    $project_id = 397; 
    $project_id = 409  if $hashRef->{File} =~ /IkB-GFP/i;
     if ($fileHash{$fileName} ne $dirName) 
     {
       my %insertRecord;
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
        my $record = insertRecord (%insertRecord);
        print LOG "PK:   $record\n";
#load up all the datapoints
        getDataPoints($hashRef->{File}, $record)
    }
    else 
    {
       my $query = "Select top 1dp. fcs_run_id  from $TBCY_DATA_POINTS dp 
	    where dp.fcs_run_id = $fileIDHash{$hashRef->{File}}";
       my @rows = $sbeams->selectOneColumn($query);
	    my $fileID = $rows[0] if scalar(@rows == 1);;
	     if ($fileID) 
       {
         print LOG "File and datapoints already exist:  $hashRef->{File} \n";
         delete $fileIDHash{$hashRef->{File}};
         return;
       }
       else
       {
         getDataPoints($hashRef->{File}, $fileIDHash{$hashRef->{File}});
          delete $fileIDHash{$hashRef->{File}};
       }
    }
}
  
sub insertRecord
{
  
  	my %hashRecord  = @_;
   
		my $table = "cytometry.dbo.fcs_run";
		my $pK = 0; 
    my $pkName = "fcs_run_id";
    my $insert = 1;
    my $update = 0.;
		my $PK = $sbeams->updateOrInsertRow(
						insert => $insert,
						update => $update,
						table_name =>$table,
						rowdata_ref => \%hashRecord,
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
  
  
sub data2
 {

   my $PK = shift;
   my  $infile   = shift(@_);
   my  $offset   = shift(@_);
   my $size     = shift(@_); # not used
   my $n_params = shift(@_);
   my $n_events = shift(@_);
   my %incol    = @_; # This hash contains the column assignments for the
                    # parameters in the input datafile.  See the main
                    # code for details.
					
	my ($fileName) = $infile =~ /^.*\/(.*)$/; 

    # Next, we deal with any parameters which are not among the "standard
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
	fcs.filename = \'$fileName\' and confirmed = 1";
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
      $dataHash{confirmed} = 1;
    
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


sub getDataPoints
{
	
	my %args = @_;
=comment
	foreach my $k (keys %parameters)
		{
				print "$k  ==== $parameters{$k}<br>";
		}	
=cut
	
  
  
  my $infile = shift; 
  my $filePK = shift;
  print LOG " added datapoints:  $infile\n";
# Strip out all of the keyword-value pairs.
	my @header = read_fcs_header($infile);	
	my @keywords = get_fcs_keywords($infile,@header);
	my %values = get_fcs_key_value_hash(@keywords);
  my %inParsParam;
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

	data2( $filePK,$infile,$header[3],2,$num_par,$num_events,%inpars);	
  
  
  }
  

