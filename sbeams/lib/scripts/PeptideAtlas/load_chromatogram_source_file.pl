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
use Data::Dumper;

#### Set up SBEAMS modules
use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use vars qw ($sbeams $atlas $q $current_username );

# don't buffer output
$|++;

## Globals
$sbeams = new SBEAMS::Connection;
$atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
## Set up environment
$ENV{SSRCalc} = '/net/db/src/SSRCalc/ssrcalc';


## Process options
my %opts;
GetOptions( \%opts,"verbose:s", "quiet", "testonly",
		        "source_file:s", 'delete', 'project_id=s', 
            "instrument_name=s", 'load', 'organism_id=s',
            'help', ) || usage( "Error processing options" );

$opts{verbose} ||= 0;
$opts{organism_id} ||= 2;

if ( $opts{'delete'} ) {
  $opts{source_file} ||= 'No-op';
}

if ( $opts{help} ) {
  print Dumper( %opts );
}

my @mia;
for my $req ( qw ( source_file project_id ) ) {
  push @mia, $req unless defined $opts{$req};
}
if ( @mia ) {
  my $mia_str = join( ',', @mia );
  usage( "missing required arguement(s) $mia_str" );
}

unless ( $opts{load} || $opts{'delete'} ) {
  usage( "must provide either load or delete mode" );
}

if($opts{"help"}){
 usage();
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

  #### If specified, read the file in to fill the table
  if ( 1 ) {
    print "Fill table\n";
    fillTable( %opts );

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
  my $instrument =  $args{instrument_name} || 
                       usage("ERROR[$SUB]: parameter instrument name  not provided");

  my $instr_sql = qq~
  SELECT instrument_type_id 
  FROM $TBAT_INSTRUMENT_TYPE
  WHERE instrument_type_name = '$instrument'
  ~;
  my $ids = $sbeams->selectrow_hashref( $instr_sql ) || die "Unable to find instr type for $instrument";

  my $instr_id = $ids->{instrument_type_id} || die "Unable to find ID for $instrument";
  if ( $opts{'delete'} ) {
    print STDERR "Beginning delete of $instrument ( $instr_id ) entries in 5 seconds\n";
    sleep 5;
    for my $aa ( 'A'..'Z' ) {
      print "Deleting $aa...\n";
      my $delsql = "DELETE FROM $TBAT_CHROMATOGRAM_SOURCE_FILE WHERE instrument_type_id = $instr_id AND peptide_ion LIKE '$aa%'";
      $sbeams->do( $delsql );
    }
    exit 1;
  }

  my $source_set_sql = qq~
  SELECT MAX( source_file_set )
  FROM $TBAT_CHROMATOGRAM_SOURCE_FILE
  ~;
  my @sets = $sbeams->selectrow_array( $source_set_sql ); # || die "Unable to find source sets";

  my $source_set = $sets[0] || 0;
  $source_set++;

  unless ( -e $source_file ) {
    usage("ERROR[$SUB]: Cannot find file '$source_file'");
  }

  open(SRCFILE,$source_file) or die("ERROR[$SUB]: Cannot open file '$source_file'");

  my $counter = 0;

  while ( my $line = <SRCFILE> ) {
    next if($line =~ /^pepion/i);
    chomp($line);
    my @cols = split(/\t/,$line,-1);

    # Hard-coded n_columns check
    if ( scalar( @cols ) != 6 ) {
      print "$line: ", scalar( @cols ) , " != 6 \n";
      die;
      next;
    }

    $cols[4] ||= '';
# pepion	modified_seq	charge	path	scan	instrument
    # Insert row in elution_time table
    my %rowdata = ( instrument_type_id => $instr_id,
                    peptide_ion => $cols[0],
                    modified_sequence => $cols[1],
                    charge => $cols[2],
                    mzML_path => $cols[3],
                    scan_number => $cols[4],
                    project_id => $opts{project_id},
                    source_file_set => $source_set,
                    organism_id => $opts{organism_id}
                    );

#    die Dumper( %rowdata );

#instrument_type_id	peptide_ion	mzML_path	scan_number	modified_sequence	charge	score
#3	AAAAWALGQIGR2	/proteomics/peptideatlas/archive/rmoritz/HumanMRMAtlas/QT5500/xtandem-p4/5Q20110813_ISBHJRXXX000410_W1_P3_r01.mzML	353	AAAAWALGQIGR	2	

     $sbeams->updateOrInsertRow( insert => 1,
                             table_name => $TBAT_CHROMATOGRAM_SOURCE_FILE,
                            rowdata_ref => \%rowdata,
                            verbose     => $opts{verbose},
                            testonly    => $opts{testonly} );

    $counter++;
    print "$counter." if($counter%100 == 0);
  }
  print "$counter rows update or inserted\n";

} # end fillTable

sub usage {
  my $msg = shift || '';
#GetOptions( \%opts,"verbose:s", "quiet", "testonly",
#		        "source_file:s", 'delete', 'project_id=s', 
#            'help', ) || usage( "Error processing options" );
  my $program = basename( $0 );
  print <<"  EOU";
  $msg

  Usage: $program [opts]

   $program --source_file chromat_info_file --instrument_name 'QTrap5500 --load' 

  Options:
    --verbose n            Set verbosity level.  default is 0
    --quiet                Set flag to print nothing at all except errors
    --debug n              Set debug flag
    --testonly             If set, rows in the database are not changed or added
    --help                 print this usage and exit.
    --delete               Delete paths of this type
    --organism_id          Organism_id of data
    --source_file          Name of file 
    --instrument_name      QTOF,QQQ,QTrap5500,QTrap4000,TSQ,IonTrap - used for 
                           delete, provided in input file for load               
    --project_id           Project with which to associate this set
    --load                 load source file 

  EOU
  exit;
}

__DATA__
pepion	modified_seq	charge	path	scan	instrument
AAAAAAAAAAR2	AAAAAAAAAAR	2	/proteomics/peptideatlas/archive/rmoritz/HumanMRMAtlas/QT5500/xtandem-p4/5Q20111025_ISBHJRXXX000516_W1_P3_r01.mzML	55	QTrap5500
AAAAAAAAAK2	AAAAAAAAAK	2	/regis/sbeams4/working/edeutsch/HumanMRMAtlas/QTrap5500/Runs_By_Order/ZH_JPT/JPT04/XTKM/Z5Q20101103_ISBHJKXXX000800_W1_P2_r01.mzML	42	QTrap5500
AAAAAAAAAVSR2	AAAAAAAAAVSR	2	/regis/sbeams4/working/edeutsch/HumanMRMAtlas/QTrap5500/Runs_By_Order/ZH/zh_pan_proteome/ISB_QT5500/XTKM/5Q20110704_ZH-R48_W1_P1_r01.mzML	82	QTrap5500
AAAAAAALQAK2	AAAAAAALQAK	2	/proteomics/peptideatlas/archive/rmoritz/HumanMRMAtlas/QQQ2/Dec2011/Dec22/QQQ20111222_ISBHJKXXX000015_2_W1_P3-r001.mzML		QQQ
AAAAAAQSEGDEDRPGER3	AAAAAAQSEGDEDRPGER	3	/proteomics/peptideatlas/archive/rmoritz/HumanMRMAtlas/QQQ2/Feb2011/Feb23/QQQ20110223_ISBHJRXXX001063_1_w1_p3-r001.mzML		QQQ
AAAAAGAPPGALGC[160]K2	AAAAAGAPPGALGC[160]K	2	/proteomics/peptideatlas/archive/rmoritz/HumanMRMAtlas/QQQ2/Jan2012/Jan13/QQQ20120113_ISBHJKXXX000490_2_2_W1_P3-r001.mzML		QQQ
AAAAEPPVIELGAR2	AAAAEPPVIELGAR	2	/regis/sbeams4/working/edeutsch/HumanMRMAtlas/QTrap4000/Runs_By_Order/ZH_JPT/JPT02/XTKM/Z4Q20100913_ISBHJRXXX000419_W1_P2_r01.mzML	78	Qtrap4000
AAAAEPPVIELGAR3	AAAAEPPVIELGAR	3	/regis/sbeams4/working/edeutsch/HumanMRMAtlas/QTrap4000/Runs_By_Order/ZH_JPT/JPT02/XTKM/Z4Q20100913_ISBHJRXXX000419_W1_P2_r01.mzML	82	Qtrap4000
AAAAMAALER2	AAAAMAALER	2	/regis/sbeams4/working/edeutsch/HumanMRMAtlas/QTrap4000/Runs_By_Order/ZH_JPT/JPT03/XTKM/Z4Q20100911_ISBHJRMXX000557_W1_P2_r01.mzML	11	Qtrap4000
