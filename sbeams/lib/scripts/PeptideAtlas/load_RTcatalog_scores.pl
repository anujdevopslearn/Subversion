#!/usr/local/bin/perl 

###############################################################################
# Program     : load_RTcatalog_scores.pl
# Author      : zsun <zsun@systemsbiology.org>
# 
#
# Description : This script load the database for RTcatalog values
#
###############################################################################

use strict;
use Getopt::Long;
use File::Basename;
use FindBin;
#### Set up SBEAMS modules
use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use vars qw ($sbeams $atlas $q $current_username $PROG_NAME $USAGE %opts
             $QUIET $VERBOSE $DEBUG $TESTONLY $TESTVARS $CHECKTABLES );

# don't buffer output
$|++;

## Globals
$sbeams = new SBEAMS::Connection;
$atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
$PROG_NAME = basename( $0 );
## Set up environment
$ENV{SSRCalc} = '/net/db/src/SSRCalc/ssrcalc';

my $SSRCalculator = new SSRCalculator;
$SSRCalculator->initializeGlobals3();
$SSRCalculator->ReadParmFile3();

## Process options
GetOptions( \%opts,"verbose:s","quiet","debug:s","testonly",
		        "input_file:s", 'instrument_name:s', 'elution_time_type:s',
            'help', 'update_peptide_info' ) || usage( "Error processing options" );

$VERBOSE = $opts{"verbose"} || 0;
$QUIET = $opts{"quiet"} || 0;
$DEBUG = $opts{"debug"} || 0;
$TESTONLY = $opts{"testonly"} || 0;

if($opts{"help"}){
 usage();
}


if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  $current_username = $sbeams->Authenticate( work_group=>'PeptideAtlas_admin' ) || exit;

  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  my %args = @_;
  my $input_file = $opts{"input_file"};
  my $instrument = $opts{"instrument_name"};
  my $elution_time_type = $opts{"elution_time_type"};
  #### If specified, read the file in to fill the table
  if ( $input_file ) {
    print "Fill table\n";
    fillTable( source_file => $input_file,
                instrument => $instrument,
        elution_time_type => $elution_time_type );
  }
  return;

} # end handleRequest


###############################################################################
# fillTable, fill $TBAT_elution_time table
###############################################################################
sub fillTable{
  my $SUB = 'fillTable';
  my %args = @_;
  my $source_file = $args{source_file} ||  
                       usage("ERROR[$SUB]: parameter source_file not provided");
  my $instrument =  $args{instrument} || 
                       usage("ERROR[$SUB]: parameter instrument name  not provided");
  my $elution_time_type = $args{elution_time_type} || 
                        usage("ERROR[$SUB]: parameter elution_time_type  not provided");
  unless ( -e $source_file ) {
    usage("ERROR[$SUB]: Cannot find file '$source_file'");
  }

   ### ELUTION_TIME_TYPE
   # elution_time_type_id
   # elution_time_type
   # source_instrument_type_id
   # is_observed

   ### get the elution_time_type_id
   my $sql = qq~
     SELECT ELUTION_TIME_TYPE_ID
     FROM $TBAT_ELUTION_TIME_TYPE ETT, $TBAT_INSTRUMENT_TYPE IT
     WHERE ETT.SOURCE_INSTRUMENT_TYPE_ID= IT.INSTRUMENT_TYPE_ID
     AND IT.INSTRUMENT_TYPE_NAME LIKE '$instrument'
     AND ETT.elution_time_type = '$elution_time_type'
   ~;


   my ($elution_time_type_id ) = $sbeams->selectOneColumn($sql);
   if( ! $elution_time_type_id){
     die "cannot find elution_time_type_id for elution_time_type=$elution_time_type 
          and INSTRUMENT_TYPE_NAME=$instrument\nplease update the ELUTION_TIME_TYPE table first\n";
   }

   open(INFILE,$source_file) or
     die("ERROR[$SUB]: Cannot open file '$source_file'");

  my $counter = 0;

  ## get a list of ELUTION_TIME_ID which have matching elution_time_type_id, peptide_sequence and modified_peptide_sequence
  $sql = qq~
      SELECT ET.MODIFIED_PEPTIDE_SEQUENCE, 
             ET.ELUTION_TIME_ID, 
             ET.ELUTION_TIME
      FROM $TBAT_ELUTION_TIME ET
      WHERE ET.elution_time_type_id = $elution_time_type_id
    ~;

  my @rows = $sbeams->selectSeveralColumns($sql);
  my %elution_time_record =();
  foreach my $row (@rows){
    my ($modSeq, $elution_time_id, $elution_time) = @{$row};
    $elution_time = sprintf("%.6f", $elution_time);
    $elution_time_record{$modSeq}{id} = $elution_time_id;
    $elution_time_record{$modSeq}{elution_time} = $elution_time;
  }
   
  ## get a list of peptide sequence that have SSRCalc Hp value
  $sql = qq~
      SELECT ET.PEPTIDE_SEQUENCE
      FROM $TBAT_ELUTION_TIME ET
      WHERE ET.elution_time_type_id = 4
    ~;
  @rows = $sbeams->selectOneColumn($sql);
  my %elution_time_SSRCalc = map{$_ => 1} @rows;

  while ( my $line = <INFILE> ) {
    next if($line =~ /Median/i);
    chomp($line);
    my @columns = split(/\s+/,$line);
    # 0 Peptide  
    # 1 Median  
    # 2 SIQR  
    # 3 Mean  
    # 4 Stdev  
    # 5 Min  
    # 6 N

    # Hard-coded n_columns check
    if ( scalar( @columns ) != 7 ) {
      print "$line: ", scalar( @columns ) , " != 7 \n";
      next;
    }

    my $modSeq = $columns[0];
    my $median = $columns[1];
    my $SIQR = $columns[2];
    my $mean = $columns[3]; 
    my $stdev = $columns[4];
    my $min = $columns[5];
    my $obs = $columns[6];
    my $pepSeq = $modSeq;
    $pepSeq =~ s/[\[\]\d]//g;

    ## round to integer 
    #$mean = sprintf("%.0f", $mean);
    #print  $mean/60 , "\t";
    $mean = sprintf("%.6f", $mean/60);
    #print "$mean\n";

    ### ELUTION_TIME

    # elution_time_id
    # elution_time_type_id
    # elution_time
    # peptide_sequence
    # modified_peptide_sequence

    # Insert row in elution_time table
    my %rowdata;
    if(defined $elution_time_record{$modSeq}){
      next if($elution_time_record{$modSeq}{elution_time} == $mean );
      %rowdata=(elution_time =>$mean);
      $sbeams->updateOrInsertRow( update => 1,
                                 table_name  => $TBAT_ELUTION_TIME,
                                 rowdata_ref => \%rowdata,
                                     verbose => $VERBOSE,
                                          PK => 'elution_time_id',
                                    PK_value => $elution_time_record{$modSeq}{id},
                                 testonly    => $TESTONLY );

     }else{
        %rowdata=(    peptide_sequence => $pepSeq,
                  elution_time_type_id => $elution_time_type_id,
             modified_peptide_sequence => $modSeq,
                          elution_time => $mean
                 );
       my $id  = $sbeams->updateOrInsertRow(
																		insert => 1,
														   table_name  => $TBAT_ELUTION_TIME,
															 rowdata_ref => \%rowdata,
															 verbose     => $VERBOSE,
															return_PK    => 1,
																				PK => 'elution_time_id',
															 testonly    => $TESTONLY );
       ## insert SSRCalc HP for the peptide
       next if(defined $elution_time_SSRCalc{$pepSeq});
       my $hPhoby = sprintf("%.6f", $SSRCalculator->TSUM3($pepSeq));
       %rowdata=(    peptide_sequence => $pepSeq,
                  elution_time_type_id => 4,
             modified_peptide_sequence => $pepSeq,
                          elution_time => $hPhoby
                 );
       
       $id  = $sbeams->updateOrInsertRow(
                                    insert => 1,
                               table_name  => $TBAT_ELUTION_TIME,
                               rowdata_ref => \%rowdata,
                               verbose     => $VERBOSE,
                              return_PK    => 1,
                                        PK => 'elution_time_id',
                               testonly    => $TESTONLY );

       $elution_time_SSRCalc{$pepSeq} = 1;
    }
    $counter++;
    print "$counter." if($counter%100 == 0);
  }
  print "$counter rows update or inserted\n";

} # end fillTable

sub usage {
  my $msg = shift || '';
  print <<"  EOU";
  $msg


  Usage: $PROG_NAME [opts]
  Options:
    --verbose n            Set verbosity level.  default is 0
    --quiet                Set flag to print nothing at all except errors
    --debug n              Set debug flag
    --testonly             If set, rows in the database are not changed or added
    --help                 print this usage and exit.
    --input_file           Name of file 
    --instrument_name           QTOF,QQQ,QTrap5500,QTrap4000,TSQ,IonTrap                  
    --elution_time_type    RT_catalog Chipcube, RT_catalog QTrap5500, RT_calc, SSRCalc

   e.g.: $PROG_NAME --list
         $PROG_NAME --input_file 'QT55_allTHR_noGRAD_MAXRT3600_CHROMS.rtcat' --instrument_name 'QTrap5500' \
                     --elution_time_type 'RT_catalog QTrap5500'
  EOU
  exit;
}

__DATA__
Peptide  Median  SIQR  Mean  Stdev  Min  N
ADRPFWICLTGFTTDSPLYEECVR        2457.81 3.304   2457.85 5.19127 2451.3  5
