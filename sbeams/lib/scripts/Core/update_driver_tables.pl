#!/usr/local/bin/perl

###############################################################################
# Program     : update_driver_tables.pl
# Author      : Kerry Deutsch <kdeutsch@systemsbiology.org>
#
# Description : This script updates the latest copy of the table_property and
#               table_column columns to database
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;

use lib qw (../../perl);
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG
            );

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::SNP;
use SBEAMS::SNP::Settings;
use SBEAMS::SNP::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::SNP;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = "update_tables.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value kay=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME --quiet

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
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
    work_group=>'SNP',
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
    $sbeamsMOD->printPageHeader();
    update_table_property(ref_parameters=>\%parameters);
    update_table_column(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }


} # end main



###############################################################################
# update_table_property
###############################################################################
sub update_table_property {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Define column map
  my %column_map = (
    '0'=>'table_name',
    '1'=>'Category',
    '2'=>'table_group',
    '3'=>'manage_table_allowed',
    '4'=>'db_table_name',
    '5'=>'PK_column_name',
    '6'=>'multi_insert_column',
    '7'=>'table_url',
    '8'=>'manage_tables',
    '9'=>'next_step',
  );


  #### Define the transform map
  #### (see ~kdeutsch/SNPS/celera/bin/transfer_celera_to_SNP.pl)
  my %transform_map = (
  );


  #### Define the UPDATE constraints
  my %update_keys = (
    'table_name'=>'0',
  );


  #### Do the transfer
  print "\nTransferring SNP_table_property.txt -> dbo.table_property";
  $sbeams->transferTable(
    src_conn=>$sbeams,
    source_file=>'../../conf/SNP/SNP_table_property.txt',
    delimiter=>'\t',
    skip_lines=>'1',
    dest_PK_name=>'table_property_id',
    dest_conn=>$sbeams,
    column_map_ref=>\%column_map,
    transform_map_ref=>\%transform_map,
    table_name=>"sbeams.dbo.table_property",
    update=>1,
    update_keys_ref=>\%update_keys,
  );


  print "\n";

  $sbeams->unix2dosFile(file=>'../../conf/SNP/SNP_table_property.txt');

  return;


} # end update_table_property

###############################################################################
# update_table_column
###############################################################################
sub update_table_column {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Define column map
  my %column_map = (
    '0'=>'table_name',
    '1'=>'column_index',
    '2'=>'column_name',
    '3'=>'column_title',
    '4'=>'datatype',
    '5'=>'scale',
    '6'=>'precision',
    '7'=>'nullable',
    '8'=>'default_value',
    '9'=>'is_auto_inc',
    '10'=>'fk_table',
    '11'=>'fk_column_name',
    '12'=>'is_required',
    '13'=>'input_type',
    '14'=>'input_length',
    '15'=>'onChange',
    '16'=>'is_data_column',
    '17'=>'is_display_column',
    '18'=>'is_key_field',
    '19'=>'column_text',
    '20'=>'optionlist_query',
    '21'=>'url',
 );


  #### Define the transform map
  #### (see ~kdeutsch/SNPS/celera/bin/transfer_celera_to_SNP.pl)
  my %transform_map = (
  );


  #### Define the UPDATE constraints
  my %update_keys = (
    'table_name'=>'0',
    'column_name'=>'2',
  );


  #### Do the transfer
  print "\nTransferring SNP_table_column.txt -> dbo.table_column";
  $sbeams->transferTable(
    src_conn=>$sbeams,
    source_file=>'../../conf/SNP/SNP_table_column.txt',
    delimiter=>'\t',
    skip_lines=>'1',
    dest_PK_name=>'table_column_id',
    dest_conn=>$sbeams,
    column_map_ref=>\%column_map,
    transform_map_ref=>\%transform_map,
    table_name=>"sbeams.dbo.table_column",
    update=>1,
    update_keys_ref=>\%update_keys,
  );


  print "\n";

  $sbeams->unix2dosFile(file=>'../../conf/SNP/SNP_table_column.txt');

  return;


} # end update_table_column



###############################################################################
###############################################################################
###############################################################################
###############################################################################

