#!/usr/local/bin/perl -w


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $TESTONLY $DEBUG $DATABASE
             $current_contact_id $current_username $LAYOUT_ID $SPOT_NUMBER
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::TableInfo;
$sbeams = SBEAMS::Connection->new();

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] --array_id <num> --file_name <file>
Options:
  --verbose n          Set verbosity level.  default is 0
  --quiet              Set flag to print nothing at all except errors
  --debug n            Set debug flag
  --array_id n         Specify the array for which you want the map file
  --layout_id n        Specify the layout_id instead of the array id
  --file_name <name>   Specify the file name for the map file
EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
  "array_id=s","layout_id=s","file_name=s")) {
  print "$USAGE";
  exit;
}


#### Set Global Variables and execute main()
$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}

main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Try to determine which module we want to affect
  my $module = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ($module eq 'Proteomics') {
    $work_group = "${module}_admin";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Biosap') {
    $work_group = "Biosap";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'SNP') {
    $work_group = "SNP";
    $DATABASE = $DBPREFIX{$module};
  }
  if ($module eq 'Microarray') {
    $work_group = "Arrays";
    $DATABASE = $DBPREFIX{$module};
  }


  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>$work_group,
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest { 
  my %args = @_;
  my $SUB_NAME = "handleRequest";

  #### Define standard variables
  my ($array_id, $sql, $layout_id, $file_name);
  my (@array_layout_ids, $n_array_layouts);
  my (@map_results);

  #### Set the command-line options
  my $array_id = $OPTIONS{"array_id"} || -1;
  my $layout_id = $OPTIONS{"layout_id"} || -1;
  if ($array_id < 0 && $layout_id < 0) {
      die "ERROR[$SUB_NAME]: Either a layout or array id must be specified!\n\n\n$USAGE";
  }
  my $file_name = $OPTIONS{"file_name"}
  || die "ERROR[$SUB_NAME]: Please specify an output file name!\n";

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  unless ($layout_id) {
      #### Get array_layout_id
      $sql = qq~
	  SELECT layout_id
	  FROM ${DATABASE}array
	  WHERE array_id = '$array_id'
	  AND record_status != 'D'
	  ~;
      
      @array_layout_ids = $sbeams->selectOneColumn($sql);
      $n_array_layouts = @array_layout_ids;
      
      unless($n_array_layouts == 1) {
	  die "ERROR[$SUB_NAME]: Multiple layout_ids returned.  This should not happen.";
      }
      
      $layout_id = pop(@array_layout_ids);
  }

  #### Get all relevant map file information
  $sql = qq~
      SELECT AE.meta_row, AE.meta_column, AE.rel_row, AE.rel_column, BS.biosequence_name, BS.biosequence_name
      FROM ${DATABASE}array_element AE
      JOIN ${DATABASE}biosequence BS ON (AE.biosequence_id = BS.biosequence_id)
      WHERE AE.layout_id = '$layout_id'
      ORDER BY AE.meta_row, AE.meta_column, AE.rel_row, AE.rel_column
      ~;

  @map_results = $sbeams->selectSeveralColumns($sql);

  #### Print out map file
  open OUTFILE, ">$file_name" or die "ERROR[$SUB_NAME]:can not write out to $file_name";
  print OUTFILE "zoneRow\tzoneCol\trow\tcol\tORF_Name\tgene_name\n";

  foreach my $feature (@map_results){
      for (my $i=0; $i<6;$i++){
	  print OUTFILE "$feature->[$i]\t";
      }
      print OUTFILE"\n";
  }
  close OUTFILE;
}


