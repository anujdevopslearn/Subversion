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

use SBEAMS::Connection::GenericXMLImporter;


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] parameters
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          Set to not actually write to database
  --source_file xxxx  Source XML file which is to be imported
  --create_data_model         Set if the data model is to be created, i.e.
                                learned by studying the XML file
  --schema_file ccc           Set the fileroot of the output schema files
  --destination_type ccc      Set the destination database server type
  --load_data                 Set if the data is to be INSERTed into the
                                database
        (one of: mssql, mysql, pgsql, oracle)

 e.g.:  $PROG_NAME --source_file SBEAMSdata.xml

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "source_file:s","schema_file:s","destination_type:s",
  "create_data_model","load_data","database_prefix:s",
  )) {
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
  my $create_data_model = $OPTIONS{"create_data_model"};
  my $schema_file = $OPTIONS{"schema_file"};
  my $destination_type = $OPTIONS{"destination_type"};
  my $load_data = $OPTIONS{"load_data"};
  my $database_prefix = $OPTIONS{"database_prefix"};


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



  #### Create GenericXMLImporter object
  my $importer = new SBEAMS::Connection::GenericXMLImporter;


  #### Create the data model if requested
  if ($create_data_model) {
    my $result = $importer->createDataModel(
      source_file => $source_file,
      verbose => 1,
      schema_file => $schema_file,
      destination_type => $destination_type,
    );
  }


  #### There probably should be a mechanism to executing the
  #### contents of the CREATE TABLE statements here


  #### INSERT the data if requested
  if ($load_data) {
    my $result = $importer->insertData(
      source_file => $source_file,
      schema_file => $schema_file,
      db_connection => $sbeams,
      database_prefix => $database_prefix,
      verbose => $VERBOSE,
      testonly => $TESTONLY,
    );
  }



  print "\n";

  return;

} # end handleRequest



