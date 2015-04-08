#!/usr/local/bin/perl

###############################################################################
# Program     : downloadFile.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: GetResultSet.cgi 6656 2011-01-24 19:04:50Z dcampbel $
#
# Description : This CGI program dumps the ResultSet data to the user
#               in various formats
#
# SBEAMS is Copyright (C) 2000-2014 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use LWP::UserAgent;
use HTTP::Request;

use lib "$FindBin::Bin/../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$sbeams = new SBEAMS::Connection;

# Don't turn off buffering, as this slows performance
# $|++;

#use CGI;
#$q = new CGI;


###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag to level n
  --testonly          Set testonly flag which simulates INSERTs/UPDATEs only

 e.g.:  $PROG_NAME --verbose 2 keyword=value

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","quiet")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "   VERBOSE = $VERBOSE\n";
  print "     QUIET = $QUIET\n";
  print "     DEBUG = $DEBUG\n";
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
    #permitted_work_groups_ref=>['xxx','yyy'],
    #connect_read_only=>1,
    allow_anonymous_access=>1,
  ));


  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  #### Process generic "state" parameters before we start
  #$sbeams->processStandardParameters(parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if (defined($parameters{action}) && $parameters{action} eq "???") {
    # Some action
  } else {
    #$sbeams->display_page_header();
    handle_request(ref_parameters=>\%parameters);
    #$sbeams->display_page_footer();
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

  #### Define some general variables
  my ($i,$element,$key,$value,$line,$result,$sql);
  my %parameters;
  my %resultset = ();
  my $resultset_ref = \%resultset;


  #### Define the parameters that can be passed by CGI
  my @possible_parameters = qw( tmp_file format name raw_download );

  #### Read in all the passed parameters into %parameters hash
  foreach $element (@possible_parameters) {
    $parameters{$element}=$q->param($element);
  }

  #### Resolve the keys from the command line if any
  my ($key,$value);
  foreach $element (@ARGV) {
    if ( ($key,$value) = split("=",$element) ) {
      $parameters{$key} = $value;
    } else {
      print "ERROR: Unable to parse '$element'\n";
      return;
    }
  }


  #### verify that needed parameters were passed
  for my $param ( @possible_parameters ) {
    die "missing required parameter $param" unless defined $parameters{$param};
  }

  #### Default format is Tab Separated Value
  $parameters{format} = "tsv" unless $parameters{format};
  my $header = $sbeams->get_http_header( mode => $parameters{format}, filename => $parameters{name} );
  print $header;

  # Currently only option, but could use this to fetch a file and force download.
  if ( $parameters{tmp_file} ) {
    my $file = "$PHYSICAL_BASE_DIR/tmp/$parameters{tmp_file}";
    $file = $parameters{tmp_file} unless -e $file;

    my $size = prettyBytes( -s $file );

    if ( $parameters{raw_download} ) {
      $log->info( "starting file cat, size is $size " . time() );
      system( "cat $file" );
      $log->info( "finished file cat " . time() );

    } else {
      open FIL, $file || exit;

      $log->info( "starting file read, size is $size " . time() );
      while ( my $line = <FIL> ) {
        $line =~ s/\&nbsp\;//gm;
        print $line;
      }
      $log->info( "finished file read " . time() );
      close FIL;
    }
  } else {
    # Currently a no-op?
    my $ua = LWP::UserAgent->new();
    my $link = 'http://www.peptideatlas.org';
  }



#  #### Default format is Tab Separated Value
#  $parameters{format} = "tsv" unless $parameters{format};
#  my $header = $sbeams->get_http_header( mode => $parameters{format}, filename => $parameters{name} );
#  print $header;
#  print $file_contents;


} # end handle_request

sub prettyBytes {
 my $size = $_[0];
 for my $units ('Bytes','KB','MB','GB','TB','PB') {
    return sprintf("%.1f",$size) . " $units" if $size < 1024;
    $size /= 1024;
 }
}

