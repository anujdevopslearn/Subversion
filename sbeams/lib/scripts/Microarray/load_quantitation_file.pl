#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_quantitation_file.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads a quantitation file to SBEAMS
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use Cwd;
use lib qw (../perl ../../perl);
require "/net/arrays/Pipeline/tools/lib/QuantitationFile.pl";

use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $TESTONLY $DEBUG $DATABASE
             $current_username $UPDATE_EXISTING $HELP
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] --scan_file <file> \
                            --quantitation_file <file> \
                            --scan_protocol_id <number> \
                            --quantitation_protocol_id <number> \
                            --array_id <number>
Options:
    --help
    --quiet
    --verbose <0|1|2>
    --debug   <0|1|2>
    --testonly
    --scan_file <scan file>
    --quantitiation_file <quantitation file>
    --scan_protocol_id <number>
    --quantiation_protocol_id <number>
    --array_id <number>
 e.g.:  $PROG_NAME --verbose 1 

EOU

#my ($i,$key,$value,@values,$n_values,$line,$counter,$sql);


GetOptions(\%OPTIONS, "quiet","verbose:s","help","debug:s","testonly",
	   "scan_file=s","quantitation_file=s","scan_protocol_id=i",
	   "quantitation_protocol_id=i", "array_id=i");

unless(defined(%OPTIONS)) {
    print $USAGE;
    exit;
}

main();
exit(0);

###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### we want to affect the Microarray portion of the database
  my $work_group = "Arrays";
  $DATABASE = $DBPREFIX{'Microarray'};

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>$work_group,
  ));

  #### Define standard variables
  my ($scan_file,$quant_file, $s_protocol, $q_protocol, $array_id);

  #### Decode command line variables
  $VERBOSE    = $OPTIONS{"verbose"} || 0;
  $QUIET      = $OPTIONS{"quiet"} || 0;
  $DEBUG      = $OPTIONS{"debug"} || 0;
  $TESTONLY   = $OPTIONS{"testonly"} || 0;
  $HELP       = $OPTIONS{"help"} || 0;
  $scan_file  = $OPTIONS{"scan_file"};
  $quant_file = $OPTIONS{"quantitation_file"};
  $s_protocol = $OPTIONS{"scan_protocol_id"};
  $q_protocol = $OPTIONS{"quantitation_protocol_id"};
  $array_id   = $OPTIONS{"array_id"};

  if ($HELP){
      print $USAGE;
      exit (0);
  }
 
  if ($DEBUG) {
      print "Current Settings:\n";
      print "VERBOSE = $VERBOSE\n";
      print "QUIET   = $QUIET\n";
      print "DEBUG   = $DEBUG\n";
      print "scan file = $scan_file\n";
      print "quantitation file = $quant_file\n";
      print "scan protocol ID = $s_protocol\n";
      print "quantitation protocol ID = $q_protocol\n";
      print "array ID = $array_id\n";
  }
  
  handleRequest(scan_file=>$scan_file,quant_file=>$quant_file,
		s_protocol=>$s_protocol, q_protocol=>$q_protocol,
		array_id=>$array_id);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest { 
  my %args = @_;
  my $SUB_NAME = "handleRequest";
  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }

  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);
  my ($scan_file,$scan_file_path, $scan_file_type, $scan_file_name, $scan_file_location_id);
  my ($quant_file,$quant_file_path, $quant_file_type, $quant_file_name, $quant_file_location_id);
  my ($s_protocol, $q_protocol, $array_id);
  my (@array_channel_scan_ids, @scan_quantitation_ids);


  #### Decode argument list
  $scan_file  = $args{"scan_file"}
  || die "ERROR[$SUB_NAME]: scan_file not passed!\n";
  $quant_file = $args{"quant_file"}
  || die "ERROR[$SUB_NAME]: quant_file not passed!\n";
  $s_protocol = $args{"s_protocol"}
  || die "ERROR[$SUB_NAME]: s_protocol not passed!\n";
  $q_protocol = $args{"q_protocol"}
  || die "ERROR[$SUB_NAME]: q_protocol not passed!\n";
  $array_id   = $args{"array_id"}
  || die "ERROR[$SUB_NAME]: array_id not passed!\n";

  #### Input scan quantitation file information
  ($quant_file_path, $quant_file_name) = get_file_information(source_file=>$quant_file);
  $quant_file_type = get_file_type(file=$quant_file_name);
  unless ($quant_file_type eq 'Quantitation File') {
      die "$quant_file_name was not determined to be a quantitation file!";
  }
  $quant_file_location_id = insert_update_file_information(file_name=>$quant_file_name,
							    file_path=>$quant_file_path,
							    file_type=>$quant_file_type);

  #### Input array channel scan file information
  ($scan_file_path, $scan_file_name) = get_file_information(source_file=>$scan_file);
  $scan_file_type = get_file_type(file=$scan_file_name);
  unless($scan_file_type eq 'Quantiation File') {
      die "$scan_file_name was not determined to be scan image!";
  }
  $scan_file_location_id = insert_update_file_information(file_name=>$scan_file_name,
							  file_path=>$scan_file_path,
							  file_type=>$scan_file_type);

  #### Read in quantitation file
  my %data = readQuantitationFile(inputfilename=>"$quant_file",
				  verbose=>$VERBOSE);
  unless (%data){
      die "\nUnable to load data from $quant_file_name\n";
  }

  #### Using number of channels, populate array_channel_scan
  my %parameters = %{$data{parameters}};

  print map { "$_ => $parameters{$_}\n" } keys %parameters;
  my $channel_count = ${$data{parameters}}{n_channels};
  print "channel count = $channel_count";
  print "--> $array_id\n";

  @array_channel_scan_ids = insert_update_array_channel_scan(array=>$array_id,
							     protocol=>$s_protocol,
							     channel_count=>$channel_count,
							     file_id=>$scan_file_location_id);

  #### Handle scan_quantitation information
  my $acs_ref = \@array_channel_scan_ids;
  @scan_quantitation_ids = insert_update_scan_quantitation(file=>$quant_file,
							   protocol=>$q_protocol,
							   scan_ref=>$acs_ref,
							   file_id=>$quant_file_location_id);

  #### Deal with actual quantitation data
  my $data_ref = \%data;;
  insert_update_scan_element (array=>$array_id,
			       data=>$data_ref,
			       scan_ids=>\@scan_quantitation_ids);


} #end handleRequest

###############################################################################
# insert_update_scan_element
###############################################################################
sub insert_update_scan_element {
    my %args = @_;
    my $SUB_NAME = "insert_update_scan_element";
    if ($DEBUG > 0) {print "\n\nEntering $SUB_NAME\n\n"; }

    #### Define standard variables
    my ($sql, $array_id, $layout_id, $data_ref, $n_scan_elements);
    my ($scan_ref,@scan_ids, $scan_id, $scan_id_ref);
    my (@values, @column_tags);
    my (@layout_ids, $n_layout_ids);
    my (@element_ids, $element_id, $n_element_ids);
    my (@scan_element_ids);
    my ($insert,$update);

    #### Decode argument list
    $array_id = $args{"array"}
    || die "ERROR[$SUB_NAME]: array_id not passed!\n";
    $data_ref = $args{"data"}
    || die "ERROR[$SUB_NAME]: data reference not passed!\n";
    $scan_ref = $args{"scan_ids"}
    || die "ERROR[$SUB_NAME]: scan_id_ref not passed!\n";

    @values = @{$data_ref->{"spots"}};
    @column_tags = @{$data_ref->{"column_tags"}};
    @scan_ids = @{$scan_ref};

    #### Get layout_id from array table
    $sql = qq~
	SELECT A.layout_id
	FROM ${DATABASE}array A
	WHERE A.array_id = $array_id
	AND A.record_status != 'D'
    ~;

    @layout_ids = $sbeams->selectOneColumn($sql);
    $n_layout_ids = @layout_ids;

    #### Check to see if there's exactly one layout_id
    if ($n_layout_ids  < 1) {
	die "ERROR[$SUB_NAME]: no layout_id found. \"$array_id\" probably is not defined!\n\n";
    }
    unless( $n_layout_ids == 1) {
	print "WARNING[$SUB_NAME]: more than one layout_id found!\n";
    }
    $layout_id = pop(@layout_ids);

    #### Get required array_elements
    $sql = qq~
	SELECT element_id, meta_row, meta_column, rel_row, rel_column
	FROM ${DATABASE}array_element 
	WHERE layout_id = $layout_id
    ~;

    @element_ids = $sbeams->selectSeveralColumns($sql);
    $n_element_ids = @element_ids;

    #### Check to see that an array_element exists
    unless ($n_element_ids  >0) {
	die "ERROR[$SUB_NAME]: no layout_id found for array \'$array_id\'!\n\n";
    }

    #### Make a hash of row/col information to element id
    my %id_hash;
    
    foreach my $holder (@element_ids) {
#	print "$holder->[1],$holder->[2],$holder->[3],$holder->[4]=>$holder->[0]\n";
#	my $pause = <STDIN>;
	$id_hash{$holder->[1],
		 $holder->[2], 
		 $holder->[3], 
		 $holder->[4]} = $holder->[0];
    }

    #### Find out if the appropriate scan_element info is already populated
    $sql = qq~
	SELECT array_element_id, scan_element_id
	FROM ${DATABASE}scan_element
	WHERE scan_quantitation_id = '$scan_id'
	~;
    
    my %scan_elements = $sbeams->selectTwoColumnHash($sql);
    my ($n_scan_elements) = %scan_elements;

    if ($n_scan_elements == $n_element_ids  && $n_scan_elements > 0) {
	$insert = 0;
	$update = 1;
    }else{
	$insert = 1;
	$update = 0;
    }

    print "scan count = $#scan_ids\n";
    print "element count = $n_element_ids\n";

    for(my $i=0;$i<=$#scan_ids;$i++) {
	for(my $j=0;$j<=$#element_ids;$j++) {
	    my (%rowdata, $rowdata_ref, $return_id);
	    $rowdata{scan_quantitation_id} = "$scan_ids[$i]";
	    $rowdata{array_element_id} = "$element_ids[$j]->[0]";
	    $rowdata_ref = \%rowdata;

	    if ($update) {
		my $PK_value = $scan_elements{$element_ids[$j]->[0]}
		|| die "ERROR[$SUB_NAME]: trying to UPDATE, but no pk_value found\n\n";
		
		$return_id = $sbeams->insert_update_row(insert=>$insert,
							update=>$update,
							table_name=>"${DATABASE}scan_element",
							rowdata_ref=>$rowdata_ref,
							PK=>"scan_element_id",
							PK_value=>"$PK_value",
							return_PK=>1,
							verbose=>$VERBOSE,
							testonly=>$TESTONLY,
							add_audit_parameters=>1
							);
	    }else {
		$return_id = $sbeams->insert_update_row(insert=>$insert,
							update=>$update,
							table_name=>"${DATABASE}scan_element",
							rowdata_ref=>$rowdata_ref,
							PK=>"scan_element_id",
							return_PK => 1,
							verbose=>$VERBOSE,
							testonly =>$TESTONLY,
							add_audit_parameters=>1
							);
	    }
	    push (@scan_element_ids, $return_id);
	}
    }


    #### Scan_element is populated.  Proceed to scan_element_quantitation


    #### Check if scan_element_quantitation has already been populated
    #### If it has, add the id to an array of ids to UPDATE instead of INSERT
    my %update_ids;
    foreach my $scan_element_id(@scan_element_ids) {
	$sql = qq!
	    SELECT scan_element_quantitation_id
	    FROM ${DATABASE}scan_element_quantitation
	    WHERE quantitation_type_id = '$quant_type_id'
	    AND scan_element_id = '$scan_element_id'
	    !;
	my ($n_scan_element_ids) = $sbeams->selectOneColumn($sql);
	if ($n_scan_element_ids == 0) {
	    $update{$scan_element_id} = $scan_element_quantitation_id; 
	}
    }

    #### Link quantitation_type_id with what we see in the quantitation file
    my %types = define_quantitation_type_ids();
   
    #### Find out coordinate columns
    my ($mrow, $mcol, $rrow, $rcol);
    for (my $j=0;$j<=$#column_tags;$j++) {
	if ($column_tags[$j] =~ /^(metaRow|meta_row)$/i){
	    $mrow = $j;
	}elsif($column_tags[$j] =~ /^(metaCol|meta_col)$/i){
	    $mcol = $j;
	}elsif($column_tags[$j] =~ /^(relRow|rel_row)$/i){
	    $rrow = $j;
	}elsif($column_tags[$j] =~ /^(relCol|rel_col)/i){
	    $rcol = $j;
	}
    }
    unless ($mrow && $mcol && $rrow && $rcol) {
	die "ERROR[$SUB_NAME]: coordinates not fully assigned\n";
    }

    #### Go through each spot, extract info to get scan_element_id, INSERT or UPDATE
    for (my $t=0;defined($values[$t]);$t++) {
	my $scan_element_id = $id_hash{${values[$t]}[$mrow], 
				       ${values[$t]}[$mcol],
				       ${values[$t]}[$rrow],
				       ${values[$t]}[$rcol]};
	
	for (my $counter=0;$counter<=$#column_tags;$counter++) {
	    my ($rowdata, $rowdata_ref, $quant_type_id);
	    $column_tags[$counter] =~ /(ch\d+_)(.*)/;
	    $quant_type_id = $types{$2};
	    $rowdata{scan_element_id} = '$scan_element_id';
	    $rowdata{quantitation_type_id} = '$quant_type_id';
	    $rowdata{scan_quantitation_number} =${values[$t]}[$counter];
	    $rowdata_ref = \%rowdata;
	    
	    if (exists($types{$2})){
		if (exists($update{$scan_element_id})){
		    my $PK_value = $update{$can_element_id};
		    $return_id = $sbeams->insert_update_row(insert=>0,
							    update=>1,
							    table_name=>"${DATABASE}scan_element_quantitation",
							    rowdata_ref=>$rowdata_ref,
							    PK=>"scan_quantitation_id",
							    return_PK => 1,
							    PK_value=>$PK_value,
							    verbose=>$VERBOSE,
							    testonly=>$TESTONLY, 
							    add_audit_parameters=>1
							    );
		}else{ 
		    $return_id = $sbeams->insert_update_row(insert=>1,
							    update=>0,
							    table_name=>"${DATABASE}scan_element_quantitation",
							    rowdata_ref=>$rowdata_ref,
							    PK=>"scan_quantitation_id",
							    return_PK => 1,
							    verbose=>$VERBOSE,
							    testonly=>$TESTONLY, 
							    add_audit_parameters=>1
							    );
	    }
	    #### PROGRESS ENDS HERE
#	    printf ("%25s = %s,%s\n", $column_tags[$counter], ${$values[$t]}[$counter],$quant_type);
#	    print "Press enter to continue...\n";
#	    my $pause = <STDIN>;
	    }
	}
    }
}
    

###############################################################################
# define_quantiation_type_ids
###############################################################################
sub define_quantitation_type_ids {
    my %args = @_;
    my $SUB_NAME = "define_quantitation_type_ids";
    if ($DEBUG > 0) {print "\nEntering $SUB_NAME\n";}

    #### Define standard variables
    my ($sql, $i, $j);
    my (@rows, @names, @ids);
    my (%return_ids);


    #### Get quantitation type names from the database
    $sql = qq~
	SELECT quantitation_type_id, quantitation_type_name
	FROM ${DATABASE}quantitation_type
	WHERE record_status != 'D'
    ~;

    @rows = $sbeams->selectSeveralColumns($sql);

    #### Connect the quantitation type names with the ones from quantitationFile.pl
    
    for ($i=0;defined($rows[$i]);$i++) {
	if ($rows[$i][1] =~ /Foreground Mean Intensity/){
	    $rows[$i][1] = "mean_intensity";
	}elsif ($rows[$i][1] =~ /Foreground Median Intensity/){
	    $rows[$i][1] = "median_intensity";
	}elsif ($rows[$i][1] =~ /Foreground Normalized Intensity/){
	    $rows[$i][1] = "norm_intensity";
	}elsif ($rows[$i][1] =~ /Background Mean Intensity/){
	    $rows[$i][1] = "mean_bkg";
	}elsif ($rows[$i][1] =~ /Background Median Intensity/){
	    $rows[$i][1] = "median_bkg";
	}elsif ($rows[$i][1] =~ /Background Normalized Intensity/){
	    $rows[$i][1] = "norm_bkg";
	}elsif ($rows[$i][1] =~ /Spot Total Intensity/){
	    $rows[$i][1] = "total_intensity";
	}elsif ($rows[$i][1] =~ /Foreground Standard Deviation/){
	    $rows[$i][1] = "inten_stdev";
	}elsif ($rows[$i][1] =~ /Background Standard Deviation/) {
	    $rows[$i][1] = "bkg_stdev";
	}elsif ($rows[$i][1] =~ /Spot Confidence/) {
	    $rows[$i][1] = "confidence";
	}elsif ($rows[$i][1] =~ /Spot Peak Intensity/) {
	    $rows[$i][1] = "peak_intensity";
	}elsif ($rows[$i][1] =~ /Foreground Pixel Count/) {
	    $rows[$i][1] = "spot_pixels";
	}elsif ($rows[$i][1] =~ /Background Pixel Count/) {
	    $rows[$i][1] = "bkg_pixels";
	}elsif ($VERBOSE == 2){
	    print "$rows[$i][1] was not mapped to anything\n";
	}
	$return_ids{$rows[$i][1]} = $rows[$i][0];
    }


    return %return_ids;

} # end define_quantitation_ids

###############################################################################
# insert_update_scan_quantitation
# NOTE: THIS DOES NOT DEAL WITH PROTOCOL DEVIATIONS!  FIX ME!
###############################################################################
sub insert_update_scan_quantitation {
    my %args = @_;
    my $SUB_NAME = "insert_update_scan_quantitation";
    if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n"; }

    #### Define standard variables

    my ($sql,$file,$file_id,$file_name, $n_quant_ids,$acs_id,$protocol);
    my ($insert, $update);
    my (@acs_ids, $acs_ref, @quant_ids);
    my (@return_ids, $return_id);

    #### Decode argument list
    $acs_ref = $args{"scan_ref"}
    || die "ERROR[$SUB_NAME]: array_channel_scan_ids not passed!\n";
    $file_id = $args{"file_id"}
    || die "ERROR[$SUB_NAME]: file_locatioN_id not passed!\n";
    $protocol = $args{"protocol"}
    || die "ERROR[$SUB_NAME]: no protocol passed!\n";
    $file = $args{"file"}
    || die "ERROR[$SUB_NAME]: file not passed!\n";

    @acs_ids = @$acs_ref;
    #### See if the scan_quantitations already exist
    $sql = qq~
	SELECT scan_quantitation_id
	FROM ${DATABASE}scan_quantitation
	WHERE file_location_id = $file_id
	AND record_status != 'D'
    ~;

    @quant_ids = $sbeams->selectOneColumn($sql);
    $n_quant_ids = @quant_ids;

    #### if there are files there, we only want to UDPATE
    if ($n_quant_ids == 0){
	$insert = 1;
	$update = 0;
    }
    else {
	$insert = 0;
	$update = 1;
    }

    $file_name = $file;
    $file_name =~ s(.*/)();

    for (my $i=0; $i<=$#acs_ids;$i++) {
	my (%rowdata, $rowdata_ref, $return_id);

	$rowdata{array_scan_id} = "$acs_ids[$i]";
	$rowdata{scan_quantitation_name} = "$file_name";
	$rowdata{protocol_id} = "$protocol";
	$rowdata{include_flag} = "1"; #what does include_flag do?
	$rowdata{file_location_id} = "$file_id";
	$rowdata_ref = \%rowdata;
	
	if ($update) {
	    my $PK_value = $quant_ids[$i];
	    $return_id = $sbeams->insert_update_row(insert=>$insert,
						    update=>$update,
						    table_name=>"${DATABASE}scan_quantitation",
						    rowdata_ref=>$rowdata_ref,
						    PK=>"scan_quantitation_id",
						    PK_value=>$PK_value,
						    return_PK => 1,
						    verbose=>$VERBOSE,
						    testonly=>$TESTONLY, 
						    add_audit_parameters=>1
						    );
	} else {
	    $return_id = $sbeams->insert_update_row(insert=>$insert,
						    update=>$update,
						    table_name=>"${DATABASE}scan_quantitation",
						    rowdata_ref=>$rowdata_ref,
						    PK=>"scan_quantitation_id",
						    return_PK => 1,
						    verbose=>$VERBOSE,
						    testonly=>$TESTONLY, 
						    add_audit_parameters=>1
						    );
	}
	push (@return_ids, $return_id);
    }
    return @return_ids;

} # end insert_update_scan_quantitation

###############################################################################
# insert_update_array_channel_scan
# NOTE: NEEDS FIXING!  PROTOCOL DEVIATION DOES NOT GET ADDRESSED!
###############################################################################
sub insert_update_array_channel_scan {
    my %args = @_;
    my $SUB_NAME = "insert_update_array_channel_scan";
    if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n"; }

    #### Define standard variables
    my ($sql, $channel_count, $file_id, $i, $protocol,$array_id);
    my (%rowdata, $rowdata_ref);
    my ($update, $insert);
    my (@return_ids, $return_id);

    #### Decode argument list
    $channel_count = $args{"channel_count"}
    || die "ERROR[$SUB_NAME]: channel_count not passed!\n";
    $file_id = $args{"file_id"}
    || die "ERROR[$SUB_NAME]: file_id not passed!\n";
    $protocol = $args{"protocol"}
    || die "ERROR[$SUB_NAME]: protocol not passed!\n";
    $array_id = $args{"array"}
    || die "ERROR[$SUB_NAME]: array_id not passed!\n";

    #### See if the array_channel_scan already exists
    $sql = qq~
	SELECT ACS.array_scan_id 
	FROM ${DATABASE}array_channel_scan ACS
	WHERE ACS.file_location_id = $file_id
	AND ACS.protocol_id = $protocol
	AND ACS.record_status != 'D'
    ~;

    my @array_channel_scan_ids = $sbeams->selectOneColumn($sql) ;
    my $n_array_channel_scan_ids = @array_channel_scan_ids;

    #### Determine whether to INSERT or UPDATE.
    if ($n_array_channel_scan_ids == $channel_count) {
	$update = 1;
	$insert = 0;
    }elsif($n_array_channel_scan_ids == 0) {
	$update = 0;
	$insert = 1;		    
    }else {
	die "ERROR[$SUB_NAME]: channel_scan_ids not equal to channel_count!\n"; 
    }

    #### INSERT/UPDATE the array_channel_scan data for each channel
    #### For each channel, get the id, and then fire up the info
    $sql = qq~
	SELECT channel_id
	FROM ${DATABASE}channel
	WHERE record_status != 'D'
    ~;

    my @channel_ids = $sbeams->selectOneColumn($sql);
    
    for($i=0;$i<$channel_count;$i++) {
	my $channel_id = $channel_ids[$i];
	my $temp = 1;	
	my $return_id;
	$rowdata{array_id} = "$array_id";
	$rowdata{protocol_id} = "$protocol";
	$rowdata{channel_id} ="$channel_id";
	$rowdata{include_flag} = "$temp"; #what does include_flag do?
	$rowdata{file_location_id} = "$file_id";

	$rowdata_ref = \%rowdata;
	
	if ($update) {
	    my $PK_value = $array_channel_scan_ids[$i];
	    $return_id = $sbeams->insert_update_row(insert=>$insert,
						    update=>$update,
						    table_name=>"${DATABASE}array_channel_scan",
						    rowdata_ref=>$rowdata_ref,
						    PK=>"array_scan_id",
						    PK_value => $PK_value,
						    return_PK => 1,
						    verbose=>$VERBOSE,
						    testonly=>$TESTONLY,
						    add_audit_parameters=>1
						    );   				    
	}else{
	    $return_id = $sbeams->insert_update_row(insert=>$insert,
						       update=>$update,
						       table_name=>"${DATABASE}array_channel_scan",
						       rowdata_ref=>$rowdata_ref,
						       PK=>"array_scan_id",
						       return_PK => 1,
						       verbose=>$VERBOSE,
						       testonly=>$TESTONLY,
						       add_audit_parameters=>1
						       );
	    
	}
	push (@return_ids, $return_id);
    }
    return @return_ids;
} # end insert_update_array_channel_scan


###############################################################################
# get_file_information
###############################################################################
sub get_file_information {
    my %args = @_;
    my $SUB_NAME = "get_file_information";
    if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n"; }
    
    #### Define standard variables
    my ($file_dir, $file_name, $source_file);

    #### Decode argument list
    $source_file = $args{'source_file'}
    || die "ERROR[$SUB_NAME]: source file not passed!\n";

    #### Deal with tildes
    $source_file =~ s{^~([^/]*)}{$1 ? (getpwnam($1))[7]:($ENV{HOME}||(getpwuid($>))[7])}ex;

    #### Separate file name from file's directory
    $source_file =~ /(.*\/.*\/)(.*)/;
    $file_dir  = $1;
    $file_name = $2;

    #### Alter directory if we have a relative path
    if ($file_dir !~ /^\//) {
	my $current_dir = cwd();
	$file_dir = $current_dir."/".$file_dir;
    }
    
    #### Verify that the separation was successful
    if (!defined($file_dir) || !defined($file_name)) {
	print "ERROR[$SUB_NAME]: could not extract file name and directory\n";
	exit 0;
    }

    #### Verify that the file exists
    my $test_path = $file_dir.$file_name;
    unless(-e $test_path) {
	die "ERROR[$SUB_NAME]: $test_path does not seem to exist!\n";
    }

    return ($file_dir, $file_name);
} # end get_file_information

###############################################################################
# get_file_type
# IMPROVE ME!: Currently looks at suffix.  This can be augmented significantly
###############################################################################
sub get_file_type {
    my %args = @_;
    my $SUB_NAME = "get_file_type";
    if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n";}

    #### Define standard variables
    my ($file_type, $file_name);

    #### Decode argument list
    $file_name = $args{'file'}
    || die "ERROR[$SUB_NAME]: file name not passed!\n";

    ####Check suffix for file type
    if ($file_name =~ /\.tif$/) {
	$file_type = 'Scan Image';
    }
    elsif($file_name =~ /\.csv$/) {
	$file_type = 'Quantitation File';
    }
    else {
	$file_type = 'Unknown';
    }
    
    return $file_type;
} # end get_file_type
    
	
###############################################################################
# insert_update_file_information
###############################################################################
sub insert_update_file_information {
    my %args = @_;
    my $SUB_NAME = "insert_update_file_information";
    if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n";}
    
    #### Define standard variables
    my ($sql, $file_name, $file_path, $file_type);
    my ($file_path_PK, $file_type_PK, $file_location_PK);
    
    #### Decode the argument list
    $file_name = $args{'file_name'}
    || die "ERROR[$SUB_NAME]: file name not passed!\n";
    $file_path = $args{'file_path'}
    || die "ERROR[$SUB_NAME]: file path not passed!\n";
    $file_type = $args{'file_type'}
    || die "ERROR[$SUB_NAME]: file type not passed!\n";

    my $module = $sbeams->getSBEAMS_SUBDIR();
    
    #### Address file path information
    $sql = qq~
	SELECT FP.file_path_id
	FROM ${DATABASE}file_path FP
	WHERE FP.file_path = '$file_path'
	AND FP.record_status != 'D'
    ~;

    my @file_path_ids = $sbeams->selectOneColumn($sql);
    my $n_file_paths = @file_path_ids;

    my (%file_path_rowdata, $file_path_rowdata_ref, $file_path_PK);

    #print "--->FILE PATH UPDATE<---\n\n";

    if ($n_file_paths > 1) {
	die "ERROR[$SUB_NAME]: more than one file path!\n";
    } 
    elsif ($n_file_paths == 1) {
	$file_path_PK =  $file_path_ids[0];
	print "file_path already exists: Aborting INSERT\n\n";
    }
    else {
	#### INSERT the file_path information
	
	#FIX ME: Should we use different information for all these fields?
	$file_path_rowdata{file_path}        = "$file_path";
	$file_path_rowdata{file_path_name}   = "$file_path";
	$file_path_rowdata{file_path_desc}   = "$file_path";
	$file_path_rowdata{server_id}        = "1";

	$file_path_PK = 'file_path_id';
	$file_path_rowdata_ref = \%file_path_rowdata;

	if ($VERBOSE > 0) {print "INSERTing file path information\n";}
	$file_path_PK = $sbeams->insert_update_row(insert=>1,
						   update=>0,
						   table_name=>"${DATABASE}file_path",
						   rowdata_ref=>$file_path_rowdata_ref,
						   PK=>"file_path_id",
						   return_PK => 1,
						   verbose=>$VERBOSE,
						   testonly=>$TESTONLY,
						   add_audit_parameters=>1
						   );	
    }

    #### Address file type information
    $sql = qq~
	SELECT FT.file_type_id
	FROM ${DATABASE}file_type FT
	WHERE FT.file_type_name = '$file_type'
	AND FT.record_status != 'D'
    ~;

    my @file_type_ids = $sbeams->selectOneColumn($sql);
    my $n_file_types = @file_type_ids;


    my (%file_type_rowdata, $file_type_rowdata_ref, $file_type_PK);

    print "--->FILE TYPE UPDATE<---\n\n";

    if ($n_file_types > 1) {
	die "ERROR[$SUB_NAME]: more than one file type!\n";
    }
    elsif ( $n_file_types == 1) {
	$file_type_PK = $file_type_ids[0];
	print "file_type already exists: Aborting INSERT\n\n";
    }
    else{
	$file_type_rowdata{file_type_name} = $file_type;
	$file_type_rowdata_ref = \%file_type_rowdata;

	if ($VERBOSE > 0) {print "INSERTing file_type information\n";}
	$file_type_PK = $sbeams->insert_update_row(insert=>1,
						   update=>0,
						   table_name=>"${DATABASE}file_type",
						   rowdata_ref=>$file_type_rowdata_ref,
						   PK=>"file_type_id",
						   return_PK=>1,
						   verbose=>$VERBOSE,
						   testonly=>$TESTONLY,
						   add_audit_parameters=>1
						   );
    }

    #### Address file location information
    $sql = qq~
	SELECT FL.file_location_id
	FROM ${DATABASE}file_location FL
	WHERE FL.file_name  = '$file_name'
	AND FL.file_type_id = '$file_type_PK'
	AND FL.file_path_id = '$file_path_PK'
	AND FL.record_status != 'D'
    ~;

    my @file_location_ids = $sbeams->selectOneColumn($sql);
    my $n_file_locations = @file_location_ids;


    my (%file_location_rowdata, $file_location_rowdata_ref, $file_location_PK);

    #print "--->FILE LOCATION UPDATE<---\n\n";

    if ($n_file_locations > 1) {
	die "ERROR[$SUB_NAME]: more than one file location!\n\n";
    }
    elsif ($n_file_locations == 1) {
	print "file \"$file_name\" already exists: Aborting INSERT\n\n";
	$file_location_PK = $file_location_ids[0];
    }
    else {
	$file_location_rowdata{file_name} = $file_name;
	$file_location_rowdata{file_type_id} = $file_type_PK;
	$file_location_rowdata{file_path_id} = $file_path_PK;
	$file_location_rowdata_ref = \%file_location_rowdata;

	if ($VERBOSE > 0) {print "INSERTing file_location information\n";}
	$file_location_PK = $sbeams->insert_update_row(insert=>1,
						       update=>0,
						       table_name=>"${DATABASE}file_location",
						       rowdata_ref=>$file_location_rowdata_ref,
						       PK=>"file_location_id",
						       return_PK=>1,
						       verbose=>$VERBOSE,
						       testonly=>$TESTONLY,
						       add_audit_paramters=>1
						       );
    }
    return $file_location_PK;
} # end insert_update_file_information







###############################################################################
# get_quantitation_file - NOT USED
###############################################################################
#sub get_quantitation_file {
#    my %args = @_;
#    my $SUB_NAME = "get_quantitation_file";
#    
#    #### Define standard variables
#    my ($file_location_id, $sql);
#
#    #### Decode argument list
#    $file_location_id = $args{'file_location_id'}
#    || die "ERROR[$SUB_NAME]: file_location_id not passed!\n";
#    
#    $file_type_name = $args{'file_type_name'}
#    || die "ERROR[$SUB_NAME]: file_type_name not passed!\n";
#
#    #### Get file name and path
#    $sql = qq~
#	SELECT FL.file_name, FP.file_path_name
#	FROM ${DATABASE}file_location FL
#	LEFT JOIN ${DATABASE}file_type FT ON (FL.file_type_id = FT.file_type_id)
#	LEFT JOIN ${DATABASE}file_path FP ON (FL.file_path_id = FP.file_path_id)
#	WHERE FL.file_location_id = '$file_location_id'
#	AND FT.file_type_name = '$file_type_name'
#	AND FL.record_status != 'D'
#    ~;
#    
#    my @rows = $sbeams->selectSeveralColumns($sql);
#
#    my %status;
#    $status{file_name} = $rows[0]->[0];
#    $status{file_path} = $rows[0]->[1];
#
#    unless(defined($status{file_name})) {
#	die "ERROR[$SUB_NAME]: could not retrieve file name\n";
#    }
#    unless(defined($status{file_path})) {
#	die "ERROR[$SUB_NAME] : could not retrive file path\n";
#    }
#   
#    #### make sure file path ends in /
#    if ($status{file_path} !~ /.*\/$/){
#	$status{file_path} .= "/";
#    }
#	
#    return $status{file_path}.$status{file_name};
#}

###############################################################################
# print_protocol_options
###############################################################################
sub print_protocol_options {
    my %args = @_;
    my $SUB_NAME = "print_protocol_options";
    if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n"; }
    
    #### Define standard variables
    my ($table, $field, $sql, $i);
    
    #### Decode argument list
    $table = $args{'table'}
    || die "ERROR[$SUB_NAME]: table not passed!\n";
    $field = $args{'field'}
    || die "ERROR[$SUB_NAME]: field not passed!\n";
    
    #### Get all items with appropriate table/field
    $sql = qq~
	SELECT P.name, ACS.protocol_id
	FROM ${DATABASE}protocol P
	LEFT JOIN ${DATABASE}array_channel_scan ACS ON (ACS.protocol_id = p.protocol_id)
	WHERE P.record_status != 'D'
	AND ACS.record_status != 'D'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);
    my @protocol_names = $rows[0]->[0];
    my @protocol_ids = $rows[0]->[1];
    
    print "List of Protocol IDs and Names:\n";
    for ($i=0; defined($protocol_names[$i]); $i++) {
	print "$protocol_ids[$i]\t$protocol_names[$i]\n ";
    }
    return;
} #end print_protocol_options
	
###############################################################################
# load_quantitation_file
###############################################################################
#sub load_quantitation_file {
#    my %args = @_;
#    my $SUB_NAME = "load_quantitation_file";
#    if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n"; }

    #### Define standard variables
#    my($file_name, $sql);

    #### Decode argument list
#    $file_name = $args{'file_name'}
#    || die "ERROR[$SUB_NAME]: file_name not passed!\n";
    
    #### Read in file
#    my %data = readQuantitationFile(inputfile_name=>"$file_name");
#    unless (%data){
#	die "\nUnable to load data from $file_name\n";
#    }
#} # end load_quantitation_file

###############################################################################
# insert_scan_quantitaiton
###############################################################################
#sub insert_scan_quantitation {
#    my %args = @_;
#    my $SUB_NAME = "insert_scan_quantitation";
#    if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n";}

    #### Define standard variables
#    my ($sql, $insert, $update, $scan_quantitation_id, $n_scan_quantitations);
#    my @scan_quantitations;

    #### Decode the argument list
#    my $file_name = $args{'file_name'}
#    || die "ERROR[$SUB_NAME]: file name not passed\n";
#    my $file_path = $args{'file_path'}
#    || die "ERROR[$SUB_NAME]: file path not passed\n";
#    my $file_location_id = $args{'file_location_id'}
#    || die "ERROR[$SUB_NAME]: file_location_id not passed.  ".
#	"This is indicative of something wrong in previous steps\n";

    #### Get db sub-directory
#    my $module = $sbeams->getSBEAMS_SUBDIR();

    #### read in quantitation file
#    my %data = readQuantitationFile(inputfilename=>"$file_path\/$file_name",
#				    verbose=>$VERBOSE,
#				    headeronly=>0);

    #### If nothing is returned, then something's wrong
#    unless (%data) {
#	die "\nERROR[$SUB_NAME]: No data was loaded from $file_name!\n";
#    }
#} # end insert_scan_quantitaiton



######################  OLDER STUFF ####################

###############################################################################
# get_quantitation_file_status
###############################################################################
sub get_quantitation_file_status { 
  my %args = @_;
  my $SUB_NAME = 'get_quantitation_file_status';
  if ($DEBUG > 0) { print "\n\nEntering $SUB_NAME\n\n";}


  #### Decode the argument list
  my $file_location_id = $args{'file_location_id'}
   || die "ERROR[$SUB_NAME]: file_location_id not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Get information about this file_location_id from database
  $sql = qq~
      SELECT SQ.scan_quantitation_id,SQ.scan_quantitation_name,FL.file_name,FP.file_path_name
      FROM ${DATABASE}scan_quantitation SQ
      LEFT JOIN ${DATABASE}file_location FL ON (SQ.file_location_id = FL.file_location_id)
      LEFT JOIN ${DATABASE}file_path FP ON (FL.file_path_id = FP.file_path_id)
      WHERE SQ.scan_quantitation_id = '$file_location_id'
      AND SQ.record_status != 'D'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);


  #### Put the information in a hash
  my %status;
  $status{biosequence_set_id} = $rows[0]->[0];
  $status{set_name} = $rows[0]->[1];
  $status{set_tag} = $rows[0]->[2];
  $status{set_path} = $rows[0]->[3];

  #### Get the number of rows for this biosequence_set_id from database
  $sql = qq~
          SELECT count(*) AS 'count'
            FROM ${DATABASE}scan_quantitation SQ
           WHERE SQ.scan_quantitation_id = '$file_location_id'
  ~;
  my ($n_rows) = $sbeams->selectOneColumn($sql);


  #### Put the information in a hash
  $status{n_rows} = $n_rows;


  #### Return information
  return \%status;

} # end  get_quantitation_file_status

