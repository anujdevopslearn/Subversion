#!/usr/local/bin/perl -w

###############################################################################
# Program     : generate_schema.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script generates SQL DROP/CREATE/ALTER statements
#               for different flavors of database based on the
#               table_property and table_column TSV files
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
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG
             $current_contact_id $current_username
            );

require "./generate_schema.pllib";

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
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --table_property_file ccc   Set the name of table_property file
  --table_column_file ccc     Set the name of table_property file
  --schema_file ccc           Set the name of the output schema file
  --destination_type ccc      Set the destination database server type
        (one of: mssql, mysql, pgsql, oracle)

 e.g.:  $PROG_NAME --table_prop \$CONFDIR/Core/Core_table_property.txt \\
                           --table_col \$CONFDIR/Core/Core_table_column.txt \\
                           --schema_file Core_CreateTables.mssql \\
                           --destination_type mssql

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
  "table_property_file:s","table_column_file:s","schema_file:s",
  "destination_type:s")) {
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
  #exit unless ($current_username = $sbeams->Authenticate(
  #  work_group=>'Developer',
  #));

  #### Normally the authenticator guesses modes, so do it manually
  $sbeams->guessMode();


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
    generateSchema(ref_parameters=>\%parameters);
    $sbeams->printPageFooter() unless ($QUIET);
  }


} # end main



###############################################################################
# generateSchema
###############################################################################
sub generateSchema {
  my %args = @_;


  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #### Set the command-line options
  my $table_property_file = $OPTIONS{"table_property_file"};
  my $table_column_file = $OPTIONS{"table_column_file"};
  my $schema_file = $OPTIONS{"schema_file"};
  my $destination_type = $OPTIONS{"destination_type"};


  #### Define some generic variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set an error buffer
  my $errors = "";

  #### If there are any left over parameters, print usage and bail
  if ($ARGV[0]) {
    $errors = "ERROR: Unable to parse parameter '".$ARGV[0]."'!\n";
  }


  #### Make sure all parameters were passed
  unless ($table_property_file && $table_column_file &&
          $schema_file && $destination_type) {
    $errors .= "ERROR: You must specify a value for all parameters ".
      "table_property_file, table_column_file, schema_file, ".
      "destination_type.\n";
  }


  #### If there are any left over parameters, print usage and bail
  if ($errors) {
    print "$errors\n";
    print $USAGE;
    exit 0;
  }


  #### Define the structures into which the files are loaded
  my $table_properties;
  my $table_columns;


  #### Verify the table_property file is openable
  unless ( -e "$table_property_file" ) {
    die("Cannot find file '$table_property_file'");
  }
  unless (open(INFILE,"$table_property_file")) {
    die("File '$table_property_file' exists but cannot be opened");
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


  #### If there are 10 columns, verify it's a table_property file and load
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

    print "Reading $table_property_file\n" unless ($QUIET);
    $table_properties = readTableProperty(source_file=>$table_property_file);

  #### Else we don't know what kind of file this is
  } else {
    print "ERROR: File '$table_property_file' does not have ".
      "the right number of columns.  Verify file.\n";
    return;
  }



  #### Verify the table_column file is openable
  unless ( -e "$table_column_file" ) {
    die("Cannot find file '$table_column_file'");
  }
  unless (open(INFILE,"$table_column_file")) {
    die("File '$table_column_file' exists but cannot be opened");
  }


  #### Read in the first line and try to determine what the columns are
  $line = <INFILE>;
  $line =~ s/[\r\n]//g;
  @column_names = split("\t",$line);
  $n_columns = @column_names;
  close(INFILE);


  #### List all the actual column names for code generation
  #print "'",join("','",@column_names),"'\n";
  #return;


  #### If there are 22 columns, verify it's a table_column file and load
  if ($n_columns == 22) {
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

    print "Reading $table_column_file\n" unless ($QUIET);
    $table_columns = readTableColumn(source_file=>$table_column_file);

  #### Else we don't know what kind of file this is
  } else {
    print "ERROR: File '$table_property_file' does not have ".
      "the right number of columns.  Verify file.\n";
    return;
  }


  #### Generate the schema based on the input data
  print "Generating schema for $destination_type\n" unless ($QUIET);
  writeSchema(
    table_properties => $table_properties,
    table_columns => $table_columns,
    schema_file => $schema_file,
    destination_type => $destination_type,
  );

  print "Done.\n\n" unless ($QUIET);


} # end generateSchema


