#!/usr/local/bin/perl

###############################################################################
# Program     : update_plasmid.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script updates the latest copy of plasmids_fm5 to the
#               plasmid table
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;

use lib qw (../../perl);
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TESTONLY
            );

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PhenoArray;
use SBEAMS::PhenoArray::Settings;
use SBEAMS::PhenoArray::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PhenoArray;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = "update_plasmid.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value kay=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME --quiet

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
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
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>'Phenotype_user',
    #connect_read_only=>1,allow_anonymous_access=>1
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
    # Some action
  } else {
    $sbeamsMOD->display_page_header();
    handle_request(ref_parameters=>\%parameters);
    $sbeamsMOD->display_page_footer();
  }


} # end main



###############################################################################
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"} || 0;
  $TESTONLY = $OPTIONS{"testonly"} || 0;
  $DATABASE = $OPTIONS{"database"} || $sbeams->getPHENOARRAY_DB();


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### If a parameter is not supplied, print usage and bail
  #unless ($ARGV[0] && $ARGV[1]) {
  #  print $USAGE;
  #  exit 0;
  #}


  #### First get some of the lookup table values
  $sql = "SELECT coli_marker_name,coli_marker_id FROM $TBPH_COLI_MARKER ".
    "WHERE record_status !='D'";
  my %coli_marker_ids = $sbeams->selectTwoColumnHash($sql);

  $sql = "SELECT yeast_selection_marker_tag,yeast_selection_marker_id ".
    "FROM $TBPH_YEAST_SELECTION_MARKER WHERE record_status !='D'";
  my %yeast_selection_marker_ids = $sbeams->selectTwoColumnHash($sql);

  $sql = "SELECT yeast_origin_tag,yeast_origin_id ".
    "FROM $TBPH_YEAST_ORIGIN WHERE record_status !='D'";
  my %yeast_origin_ids = $sbeams->selectTwoColumnHash($sql);

  my %undef_to_1 = (undef=>'1');


  #### Define the query to get data from plasmids_fm5
  $sql = qq~
	SELECT 'B'+STRAIN_ID_,PLASMID_NA,VECTOR_,YEAST_ORIG,
               INSERT_GEN,COLI_STRAI,
               COLI_MARKE,YEAST_DELE,CLONED_BY_,DATE_,SOURCE_,REFERENCE_,
               COMMENTS_,1 AS 'plasmid_type_id'
	  FROM ${DATABASE}plasmids_fm5
         ORDER BY CONVERT(int,STRAIN_ID_)
  ~;


  #### Define column map
  my %column_map = (
    '0'=>'plasmid_strainID',
    '1'=>'plasmid_name',
    '2'=>'vector',
    '3'=>'yeast_origin_id',
    '4'=>'plasmid_insert',
    '5'=>'coli_strain',
    '6'=>'coli_marker_id',
    '7'=>'yeast_selection_marker_id',
    '8'=>'cloned_by',
    '9'=>'cloned_date',
    '10'=>'source',
    '11'=>'reference',
    '12'=>'comment',
    '13'=>'plasmid_type_id',
  );


  #### Define the transform map
  #### (see ~kdeutsch/SNPS/celera/bin/transfer_celera_to_SNP.pl)
  my %transform_map = (
    '3' => \%yeast_origin_ids,
    '6' => \%coli_marker_ids,
    '7' => \%yeast_selection_marker_ids,
    #'13' => \%undef_to_1,
  );


  #### Define the UPDATE constraints
  my %update_keys = (
    'plasmid_strainID'=>'0',
  );


  #### Do the transfer
  print "\nTransferring plasmids_fm5 -> plasmid";
  $sbeams->transferTable(
    src_conn=>$sbeams,
    #source_file=>"$FindBin::Bin/../../refdata/PhenoArray/GalitskiBaterialStrainsExport.tab",
    sql=>$sql,
    src_PK_name=>'STRAIN_ID_',
    src_PK_column=>'0',
    dest_PK_name=>'plasmid_id',
    dest_conn=>$sbeams,
    column_map_ref=>\%column_map,
    transform_map_ref=>\%transform_map,
    table_name=>"$TBPH_PLASMID",
    update=>1,
    update_keys_ref=>\%update_keys,
    testonly=>$TESTONLY,
    verbose=>$VERBOSE,
  );


  print "\n";


  return;


} # end handle_request



###############################################################################
###############################################################################
###############################################################################
###############################################################################

