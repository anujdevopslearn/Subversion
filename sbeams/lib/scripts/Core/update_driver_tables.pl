#!/usr/local/bin/perl -w

###############################################################################
# Program     : update_driver_tables.pl
# Author      : Kerry Deutsch <kdeutsch@systemsbiology.org>
# $Id$
#
# Description : This script updates the table_property and
#               table_column tables in the database from TSV files
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = new SBEAMS::Connection;

use CGI;
$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] input_filename
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          Do not actually execute the SQL

 e.g.:  $PROG_NAME \$CONFDIR/Core/Core_table_property.txt

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "delete_existing")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
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
    work_group=>'Developer',
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Decide what action to take based on calling information
  my $action = $parameters{action} || '';
  if ($action eq "???") {
    # Some action
  } else {
    $sbeams->printPageHeader() unless ($QUIET);
    updateDriverTable(ref_parameters=>\%parameters);
    $sbeams->printPageFooter() unless ($QUIET);
  }


} # end main



###############################################################################
# updateDriverTable
###############################################################################
sub updateDriverTable {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"};


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### If delete_existing is set, the TRUNCATE the tables and exit
  if ($delete_existing) {
    print "DELETing existing data in driver tables...\n";
    unless ($TESTONLY) {
      $sbeams->executeSQL('DELETE FROM $TB_TABLE_PROPERTY');
      $sbeams->executeSQL('DELETE FROM $TB_TABLE_COLUMN');
    }
    print "Driver tables DELETEd.  Start reloading data.\n";
    return;
  }


  #### If a parameter is not supplied, print usage and bail
  unless ($ARGV[0]) {
    print $USAGE;
    exit 0;
  }


  #### Set the name file
  my $source_file = $ARGV[0];
  unless ( -e "$source_file" ) {
    die("Cannot find file '$source_file'");
  }


  #### Determine the format of the file
  unless (open(INFILE,"$source_file")) {
    die("File '$source_file' exists but cannot be opened");
  }


  #### Read in the first line and try to determine what the columns are
  $line = <INFILE>;
  $line =~ s/[\r\n]//g;
  my @column_names = split("\t",$line);
  my $n_columns = @column_names;
  close(INFILE);


  #### List all the actual column names for code generation
  #print "'",join("','",@column_names),"'\n";
  #return;


  #### If there are 10 columns, verify it's a table_property file and update
  if ($n_columns == 10) {
    my @ref_columns = ('table_name','Category','table_group',
      'manage_table_allowed','db_table_name','PK_column_name',
      'multi_insert_column','table_url','manage_tables','next_step');
    for ($i=0; $i<$n_columns; $i++) {
      if ($column_names[$i] =~ /^\"(.*)\"$/) {
        $column_names[$i] = $1;
      }
      if ($ref_columns[$i] ne $column_names[$i]) {
        print "ERROR: File header verification failed.\n";
	print " Expected column $i to be '$ref_columns[$i]' but it appears ".
          "to be '$column_names[$i]'.  This is unexpected and we cannot ".
          "continue.  Please resolve and retry.\n";
        return;
      }
    }

    update_table_property(source_file=>$source_file);
    return;

  #### If there are 22 columns, verify it's a table_column file and update
  } elsif ($n_columns == 22) {
    my @ref_columns = ('table_name','column_index','column_name',
      'column_title','datatype','scale','precision','nullable',
      'default_value','is_auto_inc','fk_table','fk_column_name',
      'is_required','input_type','input_length','onChange','is_data_column',
      'is_display_column','is_key_field','column_text','optionlist_query',
      'url');
    for ($i=0; $i<$n_columns; $i++) {
      if ($column_names[$i] =~ /^\"(.*)\"$/) {
        $column_names[$i] = $1;
      }
      if ($ref_columns[$i] ne $column_names[$i]) {
        print "ERROR: File header verification failed.\n";
	print " Expected column $i to be '$ref_columns[$i]' but it appears ".
          "to be '$column_names[$i]'.  This is unexpected and we cannot ".
          "continue.  Please resolve and retry.\n";
        return;
      }
    }

    update_table_column(source_file=>$source_file);
    return;

  #### If there is 1 column, verify it's a manual update file and update
  } elsif ($n_columns == 1) {
    if ($line ne '#MANUAL updates to table_column') {
      print "ERROR: File header verification failed.\n";
        print " Expected line 1 to be '#MANUAL updates to table_column', ".
        "but it's not.  This is unexpected and we cannot ".
        "continue.  Please resolve and retry.\n";
      return;
    }

    executeManualCommands(source_file=>$source_file);
    return;

  #### Else we don't know what kind of file this is
  } else {
    print "ERROR: File '$source_file' is not recognized as either a ".
      "table_property file or a table_column_file.  It must be one of ".
      "these two.  Update failed.\n";
    return;
  }



} # end updateDriverTable



###############################################################################
# update_table_property
###############################################################################
sub update_table_property {
  my %args = @_;


  #### Process the arguments list
  my $source_file = $args{'source_file'} || die "source_file not passed";


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Define column map
  my %column_map = (
    '0'=>'table_name',
    '1'=>'category',
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
  my %transform_map = (
  );


  #### Define the UPDATE constraints
  my %update_keys = (
    'table_name'=>'0',
  );


  #### Do the transfer
  print "\nTransferring $source_file -> table_property";
  $sbeams->transferTable(
    src_conn=>$sbeams,
    source_file=>$source_file,
    delimiter=>"\t",
    skip_lines=>'1',
    dest_PK_name=>'table_property_id',
    dest_conn=>$sbeams,
    column_map_ref=>\%column_map,
    transform_map_ref=>\%transform_map,
    table_name=>$TB_TABLE_PROPERTY,
    update=>1,
    update_keys_ref=>\%update_keys,
    verbose => $VERBOSE,
    testonly => $TESTONLY,
  );


  print "\n";

  #### Insure that the file is in DOS carriage return format
  $sbeams->unix2dosFile(file=>$source_file) unless ($TESTONLY);

  return;


} # end update_table_property



###############################################################################
# update_table_column
###############################################################################
sub update_table_column {
  my %args = @_;


  #### Process the arguments list
  my $source_file = $args{'source_file'} || die "source_file not passed";


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Define column map
  my %column_map = (
    '0'=>'table_name',
    '1'=>'column_index',
    '2'=>'column_name',
    '3'=>'column_title',
    '4'=>'data_type',
    '5'=>'data_scale',
    '6'=>'data_precision',
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
  my %transform_map = (
  );


  #### Define the UPDATE constraints
  my %update_keys = (
    'table_name'=>'0',
    'column_name'=>'2',
  );


  #### Do the transfer
  print "\nTransferring $source_file -> table_column";
  $sbeams->transferTable(
    src_conn=>$sbeams,
    source_file=>$source_file,
    delimiter=>"\t",
    skip_lines=>'1',
    dest_PK_name=>'table_column_id',
    dest_conn=>$sbeams,
    column_map_ref=>\%column_map,
    transform_map_ref=>\%transform_map,
    table_name=>$TB_TABLE_COLUMN,
    update=>1,
    update_keys_ref=>\%update_keys,
    verbose => $VERBOSE,
    testonly => $TESTONLY,
  );


  print "\n";


  #### Insure that the file is in DOS carriage return format
  $sbeams->unix2dosFile(file=>$source_file) unless ($TESTONLY);

  return;


} # end update_table_column



###############################################################################
# executeManualCommands
#
# This is really quick and dirty and not very safe or elegant.  FIXME.
###############################################################################
sub executeManualCommands {
  my %args = @_;


  #### Process the arguments list
  my $source_file = $args{'source_file'} || die "source_file not passed";


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Open the file
  unless (open(INFILE,"$source_file")) {
    die("Cannot open file '$source_file'");
  }


  #### And just execute it
  print "Executing manual commands...\n";


  #### Read in all the data at once
  $sql = '';
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    next if ($line =~ /^\#/);
    next if ($line =~ /^\s*$/);
    if ($line =~ /^GO$/) {
      print "-------------\n$sql\n\n" if ($VERBOSE);
      $sbeams->executeSQL($sql) unless ($TESTONLY);
      $sql = '';

    } else {
      $sql .= "$line\n";
    }

  }


  #### If there's anything left in the buffer, run that too
  if ($sql gt '') {
    print "-------------\n$sql\n\n" if ($VERBOSE);
    $sbeams->executeSQL($sql) unless ($TESTONLY);
  }


  close(INFILE);
  print "done.\n";


  #### Insure that the file is in DOS carriage return format
  $sbeams->unix2dosFile(file=>$source_file) unless ($TESTONLY);

  return;


} # end executeManualCommands

