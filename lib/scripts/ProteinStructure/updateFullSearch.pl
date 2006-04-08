#!/usr/local/bin/perl

###############################################################################
# Program     : updateFullSearch.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script downloads full ProteinStructure searches
#               and caches the files for user searches
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
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
use Data::Dumper;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
	    );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::Client;



###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n          Set verbosity level.  default is 0
  --quiet              Set flag to print nothing at all except errors
  --debug n            Set debug flag
  --testonly           If set, rows in the database are not changed or added
  --create_cache       If set, create the cache files

 e.g.:  $PROG_NAME --create_cache

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
		   "create_cache",
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


#### If there are any unresolved parameters, exit
if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit;


###############################################################################
# main
###############################################################################
sub main {

  #### Create SBEAMS client object and define SBEAMS server URI
  my $sbeamsclient = new SBEAMS::Client;
  my $server_uri = "http://db.systemsbiology.net/dev2/sbeams";


  #### Define the relevant search sets
  my %search_sets = (
    3 => 'Hm',
    2 => 'Halo',
  );


  #### Get the GetDomains dump for Hm and Halo
  foreach my $set ( 3,2 ) {

    #### Define the desired command and parameters
    my $server_command = "ProteinStructure/BrowseBioSequence.cgi";
    my $command_parameters = {
      project_id => 150,
      biosequence_set_id => $set,
      display_options => "ShowExtraProteinProps,NoSequence",
      output_mode => "tsv",
      apply_action => "QUERY",
      SBEAMSentrycode => 'DF45jasj23jh',
    };

    #### Fetch the data
    fetchData(
      sbeamsclient => $sbeamsclient,
      server_uri => $server_uri,
      server_command => $server_command,
      command_parameters => $command_parameters,
      set_name => $search_sets{$set},
    );


    #### Define the desired command and parameters
    my $server_command = "ProteinStructure/GetDomainHits";
    my $command_parameters = {
      project_id => 150,
      biosequence_set_id => $set,
      display_options => "ShowExtraProteinProps,ApplyChilliFilter",
      output_mode => "tsv",
      apply_action => "QUERY",
      SBEAMSentrycode => 'DF45jasj23jh',
    };

    #### Fetch the data
    fetchData(
      sbeamsclient => $sbeamsclient,
      server_uri => $server_uri,
      server_command => $server_command,
      command_parameters => $command_parameters,
      set_name => $search_sets{$set},
    );

  }


  return 1;

}



###############################################################################
# fetchData
###############################################################################
sub fetchData {
  my %args = @_;
  my $SUB_NAME = 'fetchData';

  #### Decode the argument list
  my $sbeamsclient = $args{'sbeamsclient'} || die('ERROR: no sbeams_client');
  my $server_uri = $args{'server_uri'} || die('ERROR: no server_uri');
  my $server_command = $args{'server_command'}
    || die('ERROR: no server_command');
  my $command_parameters = $args{'command_parameters'}
    || die('ERROR: no command_parameters');
  my $set_name = $args{'set_name'} || die('ERROR: no set_name');


  print "Fetching $server_command data for $set_name...\n";

  #### Fetch the desired data from the SBEAMS server
  my $resultset = $sbeamsclient->fetch_data(
    server_uri => $server_uri,
    server_command => $server_command,
    command_parameters => $command_parameters,
  );


  #### Stop if the fetch was not a success
  unless ($resultset->{is_success}) {
    print "ERROR: Unable to fetch data.\n\n";
    exit;
  }


  #### Since we got a successful resultset, print some things about it
  unless ($resultset->{data_ref}) {
    print "ERROR: Unable to parse data result.  See raw_response:\n\n";
    print $resultset->{raw_response},"\n\n";
    exit;
  }

  #### Calculate the number of rows and columns
  my $ncols = scalar(@{$resultset->{column_list_ref}}),"\n";
  my $nrows = scalar(@{$resultset->{data_ref}}),"\n\n";


  #### Determine and check the base data dir
  my $base = "$PHYSICAL_BASE_DIR/var/ProteinStructure";
  unless ( -d $base ) {
    reportError(message=>"[$PROG_NAME][$SUB_NAME]: Data base dir '$base' ".
		"does not exist");
  }

  #### Determine the datatype
  my $cmdname = 'unknown';
  $cmdname = 'Biosequences'
    if ($server_command eq 'ProteinStructure/BrowseBioSequence.cgi');
  $cmdname = 'DomainHits'
    if ($server_command eq 'ProteinStructure/GetDomainHits');


  #### Determine the final output file
  my $outfile = "$base/${set_name}_$cmdname.tsv";


  #### Check that the number of rows returned is reasonable
  if ($nrows < 2900) {
    reportError(message=>"[$PROG_NAME][$SUB_NAME]: Would have written less ".
		"than 2900 rows to '$outfile' which is out of bounds.");
  };


  #### Try to open outfile for write
  open(OUTFILE,">$outfile") ||
    reportError(message=>"[$PROG_NAME][$SUB_NAME]: Unable to open '$outfile' ".
		"for write");

  #### Write out the result
  print "Writing to $outfile...\n";
  print OUTFILE $resultset->{raw_response};

  close(OUTFILE);

  return 1;

}


###############################################################################
# reportError
###############################################################################
sub reportError {
  my %args = @_;
  my $SUB_NAME = 'reportError';

  #### Decode the argument list
  my $message = $args{'message'} || '';

  print "ERROR: $message\n\n";

  exit(0);

}
