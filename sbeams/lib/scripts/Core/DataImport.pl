#!/usr/local/bin/perl

###############################################################################
# Program     : DataImport.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script imports data from an SBEAMS database export
#               file into an SBEAMS database
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use XML::Parser;
use Data::Dumper;


use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username
            );
use vars qw ($content_handler);
use vars qw ($table_info $post_update);


#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$sbeams = new SBEAMS::Connection;

use SBEAMS::UESC::Tables;
use SBEAMS::Immunostain::Tables;


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] parameters
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          Set to not actually write to database
  --source_file xxxx  Output file to which data information are dumped

 e.g.:  $PROG_NAME --source_file SBEAMSdata.xml

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "source_file:s")) {
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
exit 0;



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'Admin'
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


  #### Define standard variables
  my ($i,$element,$element_value,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $source_file = $OPTIONS{"source_file"} || '';


  #### If there are any parameters left, complain and print usage
  if ($ARGV[0]){
    print "ERROR: Unresolved parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }


  #### Print out the user context header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  my $result = importTableData(
    source_file => $source_file,
  );

  return;

} # end handleRequest



###############################################################################
# importTableData
###############################################################################
sub importTableData {
  my %args = @_;

  #### Process the arguments list
  my $source_file = $args{'source_file'} || die "source_file not passed";


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Read in the command file into a buffer
  open(INFILE,$source_file)
     || die("Unable to open command_file '$source_file'");
  my $xml = '';
  while ($line = <INFILE>) {
    $xml .= $line;
  }
  close(INFILE);


  #### Set up the XML parser and parse the XML in the buffer
  my $parser = new XML::Parser(Handlers => {Start => \&start_element});
  $parser->parse($xml);

  return 1;

} # end importTableData



###############################################################################
# start_element
###############################################################################
sub start_element {
  my $handler = shift;
  my $element = shift;
  my %attrs = @_;

  #### If this is the main containter tag, just return
  return if ($element eq 'SBEAMS_EXPORT');


  #### Get information about this table
  unless (defined($table_info->{$element}->{db_table_name})) {
    getTableInfo(table_name=>$element);
  }


  #### Check to see if the primary key is there
  my $PK_column_name = $table_info->{$element}->{PK_column_name};
  my $orig_PK_value = $attrs{$PK_column_name};
  my $PK_value = undef;
  my $return_PK = 1;
  my $insert = 1;
  my $update = 0;
  if ($PK_column_name) {

    #### If there is a primary key provided, let's examine it more closely
    if ($attrs{$PK_column_name}) {

      my $result = determineDataPresence(
        table_name=>$element,
        attributes=>\%attrs,
      );

      #### If this row is present and identical, then there's nothing to do
      if ($result->{present} eq 'YES' && $result->{identical} eq 'YES') {
        $insert = 0;
        $update = 0;
        $PK_value = $result->{PK_value};

      #### If this row is determined to be already present, then update
      } elsif ($result->{present} eq 'YES') {
        $insert = 0;
        $update = 1;
        $PK_value = $result->{PK_value};
        $return_PK = 0;
        delete($attrs{$PK_column_name});

      #### Otherwise get rid of the PK and INSERT
      } else {
        print "INFO: $element:$attrs{$PK_column_name} was provided.  It ".
          "will be removed from the column list and auto-gen'ed\n";
        delete($attrs{$PK_column_name});
      }



    #### If the primary key value is not provided.  Could be trouble.
    #### But in principle as long as no one has to refer to it, fine.
    } else {
      print "WARNING: Record for table $element does not appear to have ".
        "a $PK_column_name attribute.  Unusual.\n"
        if ($VERBOSE > 1);
      $return_PK = 0;
    }


    #### Some tables just don't have a primary key.  Could be trouble.
  } else {
    print "WARNING: Table $element does not appear to use a PK.  Unusual.\n"
      if ($VERBOSE > 1);
  }


  #### If deemed necessary, UPDATE or INSERT the data
  my $returned_PK;
  if ($insert + $update > 0) {
    $returned_PK = $sbeams->updateOrInsertRow(
      insert=>$insert,
      update=>$update,
      table_name=>$table_info->{$element}->{real_table_name},
      rowdata_ref=>\%attrs,
      PK_name=>$PK_column_name,
      PK_value=>$PK_value,
      return_PK=>$return_PK,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );


    #### If we wanted a PK to come back, verify that we got it
    if ($return_PK) {
      print "INFO: Received PK $returned_PK back from database\n";
      unless ($returned_PK >= 1) {
        die("ERROR: Unable to get PK from database\n");
      }

    #### Else verify that we got true back and set the PK
    } else {
      unless ($returned_PK == 1) {
        die("ERROR: Unable to update record in database\n");
      }
      $returned_PK = $PK_value;
    }

  }


  #### Set the map of PK's in the input file to the database
  print "INFO: PK in file is $returned_PK in database\n";
  $content_handler->{$element}->{PK_map}->{orig_PK_value} = $returned_PK;


}



###############################################################################
# determineDataPresence
###############################################################################
sub determineDataPresence {
  my %args = @_;

  #### Process the arguments list
  my $table_name = $args{'table_name'} || die "table_name not passed";
  my $attributes_ref = $args{'attributes'} || die "attributes not passed";
  my %attributes = %{$attributes_ref};

  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);

  #### Define a return status structure
  my $return_status;
  $return_status->{present} = '?';
  $return_status->{identical} = '?';


  #### Get information about this table
  unless (defined($table_info->{$table_name}->{db_table_name})) {
    getTableInfo(table_name=>$table_name);
  }


  #### Check to see if the primary key is there
  my $PK_column_name = $table_info->{$table_name}->{PK_column_name};
  my $orig_PK_value = $attributes{$PK_column_name};
  my $real_table_name = $table_info->{$table_name}->{real_table_name};


  #### If there is one, see if the database already has a record with that ID
  $sql = "SELECT * FROM $real_table_name ".
         " WHERE $PK_column_name = '$orig_PK_value'";
  #print "$sql\n";
  my @rows = $sbeams->selectHashArray($sql);
  my $nrows = scalar(@rows);

  #### Die if more than one row comes back
  if ($nrows > 1) {
    die("ERROR: Too many rows returned for $sql");
  }


  #### If exactly one row was returned, determine similarity
  my $PK_similarity = 0;
  if ($nrows == 1) {

    #### Calculate the similarity between old and new data
    $PK_similarity = calcRowDiff(
      old_row => \%attributes,
      new_row => $rows[0],
    );

    if ($PK_similarity == 1.0) {
      print "INFO: This record is already in the database and up-to-date\n"
        if ($VERBOSE > 1);
      $return_status->{present} = 'YES';
      $return_status->{identical} = 'YES';
      $return_status->{PK_value} = $orig_PK_value;
      return $return_status;
    }

  }


  #### If no rows were returned, or the PK row isn't very similar,
  #### try doing a search based on the key columns
  my $key_similarity;
  if ($nrows == 0 || $PK_similarity < 0.7) {
    #### Write this part!

  }


  #### Decide what to return based on whether the data were found


  if ($PK_similarity > 0.7) {
    print "INFO: This record is already in the database but needs to be ".
      "updated.\n" if ($VERBOSE > 1);
    $return_status->{present} = 'YES';
    $return_status->{identical} = 'NO';
    $return_status->{PK_value} = $orig_PK_value;
    return $return_status;
  }


  print "INFO: This record is not in the database and needs to be ".
    "updated.\n" if ($VERBOSE > 1);
  $return_status->{present} = 'NO';
  return $return_status;

} # end determineDataPresence



###############################################################################
# calcRowDiff
###############################################################################
sub calcRowDiff {
  my %args = @_;

  #### Process the arguments list
  my $old_row_ref = $args{'old_row'} || die "old_row not passed";
  my $new_row_ref = $args{'new_row'} || die "new_row not passed";

  #### Process inputs into nice hashes and a duplicate that we can mod
  my %old_row = %{$old_row_ref};
  my %new_row = %{$new_row_ref};
  my %new_row_tmp = %new_row;


  #### Define the audit columns
  my %creation_columns = (
    date_created => 1, created_by_id => 1,
  );
  my %modification_columns = (
    date_modified => 1, modified_by_id => 1,
  );


  #### Define a score and a normalization factor
  my $score = 0;
  my $normalization = 0;


  #### Loop over each row in the old and check the new
  while (my ($key,$value) = each %old_row) {

    #### If this attribute exists in the new data
    if (exists($new_row{$key})) {
      my $value2 = $new_row{$key};
      if ($value eq $value2) {
        print "  Column $key: equal ($value=$value2)\n" if ($VERBOSE > 1);
        if ($creation_columns{$key}) {
          $score += 10;
          $normalization += 9;
        } elsif ($modification_columns{$key}) {
          $score += 1;
        } else {
          $score++;
        }
      } else {
        print "  Column $key: UNEQUAL ($value=/=$value2)\n" if ($VERBOSE > 1);
        if ($creation_columns{$key}) {
          $score -= 1;
        } elsif ($modification_columns{$key}) {
          $score -= 0;
        } else {
          $score -= 0;
        }
      }


    #### Else if it does not exist
    } else {
      $score--;
    }

    $normalization++;

  }

  print "Similarity score: ",$score / $normalization,
    " ($score / $normalization)\n" if ($VERBOSE > 1);
  return $score / $normalization;

} # end calcRowDiff



###############################################################################
# getTableInfo
###############################################################################
sub getTableInfo {
  my %args = @_;

  #### Process the arguments list
  my $table_name = $args{'table_name'} || die "table_name not passed";

  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);

  #### Get the table_properties for the specified table_name
  $sql = "SELECT *
            FROM $TB_TABLE_PROPERTY
           WHERE table_name = '$table_name'
  ";
  my @rows = $sbeams->selectHashArray($sql);
  my $nrows = scalar(@rows);
  if ($nrows != 1) {
    die("ERROR: Expected 1 row but got $nrows rows from:\n$sql\n");
  }

  #### Extract the data into the table_info hash
  my $row = $rows[0];
  while ( ($key,$value) = each %{$row}) {
    $table_info->{$table_name}->{$key} = $value;
  }


  #### Do the translation between db_table_name and real_table_name
  my $db_table_name = $table_info->{$table_name}->{db_table_name};
  #print "  db_table_name = ",$db_table_name,"\n";
  my ($real_table_name) = evalSQL($db_table_name);
  #print "  real_table_name = ",$real_table_name,"\n";
  unless ($real_table_name) {
    die("Unable to translate '$table_name' into a real table ".
      "name.  This can sometimes happen because there isn't a ".
      " use SBEAMS::<modulename>::Tables.pm at the top of this program");
  }
  $table_info->{$table_name}->{real_table_name} = $real_table_name;


  #### Get the table_columns for the specified table_name
  $sql = "SELECT *
            FROM $TB_TABLE_COLUMN
           WHERE table_name = '$table_name'
  ";
  my @rows = $sbeams->selectHashArray($sql);
  my $nrows = scalar(@rows);
  if ($nrows < 1) {
    die("ERROR: Did not get any rows from:\n$sql\n");
  }


  #### Extract the data into the table_info hash
  foreach my $row (@rows) {
    my $column_name = $row->{column_name};
    $table_info->{$table_name}->{columns}->{$column_name} = $row;
  }


  return 1;

} # end getTableInfo



###############################################################################
# evalSQL
#
# Callback for translating Perl variables into their values,
# especially the global table variables to table names
###############################################################################
sub evalSQL {
  my $sql = shift;

  return eval "\"$sql\"";

} # end evalSQL



