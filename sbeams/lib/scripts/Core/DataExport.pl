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
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
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

# Testing use of new freetds/DBDSybase
#use lib( "/net/db/dcampbel/projects/programs/lib/x86_64-linux-thread-multi-ld/" );
use DBI;
use DBD::Sybase;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams
             $PROG_NAME %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username
             $content_handler $table_info );

my $written_count = 0;

#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$sbeams = new SBEAMS::Connection;

processOptions();

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
#
my $dbh = $sbeams->getDBHandle();
$sbeams->setRaiseErrorOn();
my %stmts;

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
    $sbeams->Authenticate(permitted_work_groups_ref=>['Admin','Developer']
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
  my $map_audit_user_to = $OPTIONS{"user_map_to"} || '';
  my $map_audit_group_to = $OPTIONS{"workgroup_map_to"} || '';
  my $synonyms = $OPTIONS{"synonyms"} || '';


  #### If there are any parameters left, complain and print usage
  if ($ARGV[0]){
    print "ERROR: Unresolved parameter '$ARGV[0]'.\n";
    printUsage();
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
    open(OUTFIL,">$output_file")
      || die ("Unable to open output file '$output_file'");
  }


  my $writer = new XML::Writer(
    DATA_INDENT => 4,
    DATA_MODE => 'TRUE',
  );
  #$writer->xmlDecl();
  #$writer->startTag("SBEAMS_EXPORT");
  print OUTFIL "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print OUTFIL "<SBEAMS_EXPORT>\n";

  if ( $synonyms ) {
    print OUTFIL "  <synonym_cols\n";
    my @pairs = split( ",", $synonyms );
    for my $pair ( @pairs ) {
      my ( $n, $v ) = split "=", $pair;
      print OUTFIL qq(    $n="$v"\n);
    }
    print OUTFIL "  />\n";
  }

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
  print OUTFIL "</SBEAMS_EXPORT>\n";
	exit;

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

  my $fk_column = $args{fk_column} || '';
  my $fk_value = $args{fk_value} || '';

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
  $sql .= " WHERE $qualifiers \n" if ($qualifiers);
  $sql .= " ORDER BY $args{fk_column} \n" if ($args{fk_column});
  $sql = evalSQL($sql);

	if ( $OPTIONS{sql_only} ) {
		print "$sql \n\n";
		return;
	}
  
  my $handle;
  if ( $fk_column && $fk_value ) {
    my $stmt_key = $real_table_name .  '_' . $fk_column;
    $stmts{$stmt_key} ||= $dbh->prepare( "SELECT * FROM $real_table_name WHERE $fk_column = ?" );
    $handle = $stmts{$stmt_key};
    $handle->execute( $args{fk_value} );
  } else {
    $handle = $sbeams->get_statement_handle( $sql );
  }

  #  Original call creates 2 arrays of size = num_rows, changed DSC 11/2006
  #  my @rows = $sbeams->selectHashArray($sql);
  #### Loop over each row, writing out the data
  while ( my $row = $handle->fetchrow_hashref() ) {
  
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

  unless ( $written_count % 10000 ) {
    print STDERR "Memory at " . memusage() . " after $written_count\n" 
  }
  $written_count++;

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
    my $written_status = $table_info->{$table_handle}->{written_records}->{$PK_value};
    if ($written_status == 1) {
      return 1;
    } elsif ( $written_status == 99 ) {
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
      $row->{$key} = $sbeams->escapeXML( value => $row->{$key} );
    } else {
      delete($row->{$key});
    }
  }

  #### If we're cascading, look for references that need to be defined first
  if ($cascade) {

    #### Remember that writing of this record is pending to detect
    #### circular references
    if ($PK_column_name && $PK_value) {
      $table_info->{$table_handle}->{written_records}->{$PK_value} = 99;
    }

    while ( ($key,$value) = each %{$row}) {

      if ( !$OPTIONS{pseudo_keys} ) {
        next unless $table_info->{$table_handle}->{columns}->{$key}->{data_type} =~ /int/i;
      }

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
          if ( $written_status == 99 ) {
            print "WARNING: $table_handle:$PK_value: Caught request to write ".
              "out an already pending record which is then circular.  Remedy ".
              "will be to write out the record as is but note that upon".
              "loading these data, this will require a two-step ".
              "INSERT/UPDATE unless foreign keys are not enforced\n"
              if ($VERBOSE>1);
            #$row->{$key} = "1xxxxxxxxx($value)";

          } elsif ($written_status == 1) {
            print "INFO: $table_handle:$PK_value: Already wrote ".
              "$key = '$value'\n" if ($VERBOSE>1);
            next;

          #### Otherwise go ahead and request to have it written out
          } else {
            print "INFO: $table_handle:$PK_value: Deferring to resolve ".
              "$key = '$value'\n" if ($VERBOSE>1);
            my $result = exportTableData(
              table_name => $fk_table,
              fk_column => $fk_column,
              fk_value => $value,
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
    $table_info->{$table_handle}->{written_records}->{$PK_value} = 1;
  }


  #### Write out the row
  #$writer->emptyTag($table_handle,%{$row});
  if (1 == 1) {
    print OUTFIL "    <$table_handle";
    while ( ($key,$value) = each %{$row}) {
      print OUTFIL "\n        $key=\"$value\"";
    }
    print OUTFIL " />\n";
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
           ORDER BY column_name ASC
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

  die("Unrecognized element '$element'")
    unless ($element eq 'export_data' || $element eq 'export_command_list');
  return if ($element eq 'export_command_list');

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

  return $sbeams->evalSQL($sql);

} # end evalSQL


sub processOptions {
 
  # map_audit_xxx_to provided for backwards compatability.
  GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
              "output_file:s","command_file:s","recursive", 'help',
              "user_map_to:i", "pseudo_keys:i", "workgroup_map_to:i", 
              'synonyms:s', 'map_audit_user_to:i', 'map_audit_group_to:i',
							'sql_only');

  $OPTIONS{map_audit_user_to} ||= $OPTIONS{user_map_to}; 
  $OPTIONS{map_audit_group_to} ||= $OPTIONS{workgroup_map_to}; 
  $OPTIONS{pseudo_keys} = 1 unless defined $OPTIONS{pseudo_keys}; 

  # Pleas for help get precedence
  printUsage() if $OPTIONS{help};

  for my $cmd ( 'command_file' ) {
    printUsage( "Missing required parameter: $cmd" ) unless $OPTIONS{$cmd};
  }
  
  $OPTIONS{cascade} = $OPTIONS{recursive};
}

sub memusage {
  my @results = `ps -o pmem,pid $$`;
  my $mem = '';
  for my $line  ( @results ) {
    chomp $line;
    my $pid = $$;
    if ( $line =~ /\s*(\d+\.*\d*)\s+$pid/ ) {
      $mem = $1;
      last;
    }
  }
  $mem .= '% (' . time() . ')';
  return $mem;
}

sub printUsage {

  my $msg = shift || '';

  print <<"  EOU";

  $msg

  Usage: $0 -c cmd_file [ -o out_file -v -q -d -r ]
  Options:
  -c,  --command_file        File of instructions as to what data to export.
  -d,  --debug n             Set debug flag
  -h,  --help                Print this usage info and quit.
  -o,  --output_file         Output file to which to write XML
  -p,  --pseudo_keys         Allow pseudo key relationships (varchar key lists)
                             0 = False, 1 = true = default
  -q,  --quiet               Set flag to print nothing at all except errors
  -r,  --recursive           Recursive export (cascade), get dependent records.
  -u,  --user_map_to n       User (contact_id) to which to map audit info.
  -v,  --verbose n           Set verbosity level.  default is 0
  -s,  --synonyms            Synonym column mappings, temporary fix to foreign
                             key mismatch issue.  Expects comma separated list
                             of column=synonym pairs.
  -w,  --work_group_map_to n Work_group_id id to which to map audit info.

  e.g.:  $PROG_NAME --command_file test.exportcmd --output_file SBEAMSdata.xml

  Command file format is XMLish, e.g.:
  <export_data table_name="mytable" qualifiers="some_attr=some_value"/>

  or:
  <export_data table_name="work_group" qualifiers="work_group_id IN (1,2,3)"/>

  EOU

  # Hasta la vista!
  exit();
}
