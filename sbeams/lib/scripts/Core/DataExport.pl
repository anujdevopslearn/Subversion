#!/usr/local/bin/perl

###############################################################################
# Program     : DataExport.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script exports data from an SBEAMS database
#               suitable for importing ino another SBEAMS database or
#               for other work.  Currently supported formats are:
#               XML
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
use XML::Writer;
use IO;


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
  --output_file xxxx  Output file to which data information are dumped
  --command_file xxxx Input file containing the instructions on what data
                      are to be dumped
  --cascade           Set flag to cascade, writing all dependent records

 e.g.:  $PROG_NAME --command_file test.exportcmd --output_file SBEAMSdata.xml

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "output_file:s","command_file:s","cascade","map_audit_user_to:i",
  "map_audit_group_to:i",
)) {
  print "$USAGE";
  exit;
}
$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 1;
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
  my $output_file = $OPTIONS{"output_file"} || '';
  my $command_file = $OPTIONS{"command_file"} || '';
  my $cascade = $OPTIONS{"cascade"} || '';
  my $map_audit_user_to = $OPTIONS{"map_audit_user_to"} || '';
  my $map_audit_group_to = $OPTIONS{"map_audit_group_to"} || '';


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


  #### Define an array of commands to export
  my @export_list;


  #### If an input command_file was specified, read it
  if ($command_file) {
    @export_list = readCommandFile(source_file =>$command_file);
    die("Unable to parse command_file") unless (@export_list);
  }


  #### If an output_file was specified open it
  if ($output_file) {
    open(STDOUT,">$output_file")
      || die ("Unable to open output file '$output_file'");
  }


  my $writer = new XML::Writer(
    DATA_INDENT => 4,
    DATA_MODE => 'TRUE',
  );
  #$writer->xmlDecl();
  #$writer->startTag("SBEAMS_EXPORT");
  print STDOUT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print STDOUT "<SBEAMS_EXPORT>\n";

  #### Loop over each command, exporting the results
  foreach my $command (@export_list) {

    my $result = exportTableData(
      table_name => $command->{table_name},
      qualifiers => $command->{qualifiers},
      writer => $writer,
      cascade => $cascade,
      map_audit_user_to => $map_audit_user_to,
      map_audit_group_to => $map_audit_group_to,
    );

  }

  #### Write out the final container tag
  #$writer->endTag("SBEAMS_EXPORT");
  print STDOUT "</SBEAMS_EXPORT>\n";

  return;

} # end handleRequest



###############################################################################
# exportTableData
###############################################################################
sub exportTableData {
  my %args = @_;

  #### Process the arguments list
  my $table_handle = $args{'table_name'} || die "table_name not passed";
  my $qualifiers = $args{'qualifiers'} || '';
  my $writer = $args{'writer'} || die "writer not passed";
  my $cascade = $args{'cascade'} || 0;
  my $map_audit_user_to = $OPTIONS{"map_audit_user_to"} || '';
  my $map_audit_group_to = $OPTIONS{"map_audit_group_to"} || '';


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Get information about this table
  unless (defined($table_info->{$table_handle}->{db_table_name})) {
    getTableInfo(table_name=>$table_handle);
  }

  my ($real_table_name) = $table_info->{$table_handle}->{real_table_name};
  #print "  real_table_name = ",$real_table_name,"\n";
  unless ($real_table_name) {
    die("Unable to get real_table_name from '$table_handle'");
  }


  #### Define the SQL statement to fetch the data
  $sql = "SELECT * FROM $real_table_name";
  $sql .= " WHERE $qualifiers" if ($qualifiers);
  $sql = evalSQL($sql);


  #### Fetch the appropriate rows from the database
  #print "$sql\n";
  my @rows = $sbeams->selectHashArray($sql);


  #### Loop over each row, writing out the data
  foreach my $row (@rows) {

    my $result = exportDataRow(
      table_name => $table_handle,
      writer => $writer,
      cascade => $cascade,
      row => $row,
    );

    if ($result != 1) {
      die("ERROR: Received bad return value from exportDataRow(): $result");
    }

  }


  return 1;

} # end exportTableData



###############################################################################
# exportDataRow
###############################################################################
sub exportDataRow {
  my %args = @_;

  #### Process the arguments list
  my $table_handle = $args{'table_name'} || die "table_name not passed";
  my $writer = $args{'writer'} || die "writer not passed";
  my $cascade = $args{'cascade'} || 0;
  my $row = $args{'row'} || die "row not passed";
  my $map_audit_user_to = $OPTIONS{"map_audit_user_to"} || '';
  my $map_audit_group_to = $OPTIONS{"map_audit_group_to"} || '';


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Determine the PK of this row if available
  my $PK_column_name = $table_info->{$table_handle}->{PK_column_name};
  my $PK_value;
  if ($PK_column_name) {
    $PK_value = $row->{$PK_column_name};
    unless (defined($PK_value)) {
      die("Wanted to find PK_value for PK_column_name '$PK_column_name'".
        "but did not!");
    }
    #### If we already wrote out this one, skip it
    my $written_status =
      $table_info->{$table_handle}->{written_records}->{$PK_value};
    if ($written_status eq 'YES') {
      return 1;
    }
    if ($written_status eq 'PENDING') {
      print "WARNING: $table_handle:$PK_value: Circular reference to ".
        "partially written record!\n" if ($VERBOSE>1);
      return -99;
    }
  }


  #### If there is a request to set audit trail columns to Admin do it
  if ($map_audit_user_to) {
    $row->{created_by_id} = $map_audit_user_to
      if (exists($row->{created_by_id}));
    $row->{modified_by_id} = $map_audit_user_to
      if (exists($row->{modified_by_id}));
  }
  if ($map_audit_group_to) {
    $row->{owner_group_id} = $map_audit_group_to
       if (exists($row->{owner_group_id}));
  }


  #### Remove NULL attributes and escape special characters
  while ( ($key,$value) = each %{$row}) {
    if (defined($value) && $value gt '') {
      $row->{$key} =~ s/\&/&amp;/g;
      $row->{$key} =~ s/\</&lt;g/;
      $row->{$key} =~ s/\>/&gt;/g;
    } else {
      delete($row->{$key});
    }
  }

  #### If we're cascading, look for references that need to be defined first
  if ($cascade) {

    #### Remember that writing of this record is pending to detect
    #### circular references
    if ($PK_column_name && $PK_value) {
      $table_info->{$table_handle}->{written_records}->{$PK_value} =
        'PENDING';
    }

    while ( ($key,$value) = each %{$row}) {
      if ($table_info->{$table_handle}->{columns}->{$key}->{fk_table}) {
        my $fk_table =
          $table_info->{$table_handle}->{columns}->{$key}->{fk_table};
        my $fk_column =
          $table_info->{$table_handle}->{columns}->{$key}->{fk_column_name};

        #### Check to see if we're self_referential
        if ($fk_table eq $table_handle &&
            $value eq $PK_value) {
          print "INFO: $table_handle:$PK_value: Cascade stops at ".
            "self-referential record\n" if ($VERBOSE>1);

        #### Do not export Admin contacts and work_group
        } elsif ( ($fk_table eq 'work_group' &&
                   $value eq 1) ||
                  ($fk_table eq 'contact' &&
                   $value eq 1) ) {
          print "INFO: $table_handle:$PK_value: Not cascading Admin ".
            "record $key = '$value'\n" if ($VERBOSE>1);

        #### Otherwise, export this record first.
        } else {

          #### If the written status of this one is PENDING, then trouble
          my $written_status = 
            $table_info->{$fk_table}->{written_records}->{$value};
          if ($written_status eq 'PENDING') {
            print "WARNING: $table_handle:$PK_value: Caught request to write ".
              "out an already pending record which is then circular.  Remedy ".
              "will be to write out the record as is but note that upon".
              "loading these data, this will require a two-step ".
              "INSERT/UPDATE unless foreign keys are not enforced\n"
              if ($VERBOSE>1);
            #$row->{$key} = "1xxxxxxxxx($value)";

          } elsif ($written_status eq 'YES') {
            print "INFO: $table_handle:$PK_value: Already wrote ".
              "$key = '$value'\n" if ($VERBOSE>1);
            next;

          #### Otherwise go ahead and request to have it written out
          } else {
            print "INFO: $table_handle:$PK_value: Deferring to resolve ".
              "$key = '$value'\n" if ($VERBOSE>1);
            my $result = exportTableData(
              table_name => $fk_table,
              qualifiers => "$fk_column = '$value'",
              writer => $writer,
              cascade => $cascade,
            );
          }
        }
      }
    }
  }


  #### Remember that we wrote out this record
  if ($PK_column_name && $PK_value) {
    #print "Wrote $PK_column_name:$PK_value\n";
    $table_info->{$table_handle}->{written_records}->{$PK_value} = 'YES';
  }


  #### Write out the row
  #$writer->emptyTag($table_handle,%{$row});
  if (1 == 1) {
    print STDOUT "    <$table_handle";
    while ( ($key,$value) = each %{$row}) {
      print STDOUT "\n        $key=\"$value\"";
    }
    print STDOUT " />\n";
  }


  return 1;

} # end exportDataRow



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
# readCommandFile
###############################################################################
sub readCommandFile {
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


  #### Define an array for commands and put in the content_handler
  my @command_list;
  $content_handler->{command_list} = \@command_list;

  #### Set up the XML parser and parse the XML in the buffer
  my $parser = new XML::Parser(Handlers => {Start => \&start_element});
  $parser->parse($xml);

  return(@command_list);

} # end readCommandFile



###############################################################################
# start_element
###############################################################################
sub start_element {
  my $handler = shift;
  my $element = shift;
  my %attrs = @_;

  die("Unrecognized element '$element'") unless ($element eq 'export_data');

  #### Define a hash ref holder for this command
  my $command_parameters;

  #### Verify and store the table_name attribute
  if ($attrs{table_name}) {
    $command_parameters->{table_name} = $attrs{table_name};
  } else {
    die("no table_name was specified");
  }

  #### Verify and store the qualifiers attribute
  if ($attrs{qualifiers}) {
    $command_parameters->{qualifiers} = $attrs{qualifiers};
  } else {
    $command_parameters->{qualifiers} = '';
  }

  push(@{$content_handler->{command_list}},$command_parameters);

}



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



