#!/usr/local/bin/perl

###############################################################################
# Program     : GetResultset.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program dumps the ResultSet data to the user
#               in various formats
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
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

use lib "$FindBin::Bin/../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$sbeams = new SBEAMS::Connection;

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
  my @possible_parameters = qw ( rs_set_name format remove_markup );


  #### Read in all the passed parameters into %parameters hash
  foreach $element (@possible_parameters) {
    $parameters{$element}=$q->param($element);
  }
  my $apply_action  = $q->param('apply_action');
  my $remove_markup = $parameters{remove_markup};

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
  unless ($parameters{rs_set_name}) {
    print "ERROR: not all needed parameters were passed.  This should never ".
      "happen!  Please report this error.<BR>\n";
    return;
  }


  #### Read in the result set
  $sbeams->readResultSet(resultset_file=>$parameters{rs_set_name},
    resultset_ref=>$resultset_ref,query_parameters_ref=>\%parameters);
  my $nrows = scalar(@{$resultset_ref->{data_ref}});


  #### Default format is Tab Separated Value
  $parameters{format} = "tsv" unless $parameters{format};
	my $content_type = ( $parameters{format} =~ /tsv/i ) ? "Content-type: text/tab-separated-values\n\n" :
                     ( $parameters{format} =~ /excel/i ) ? "Content-type: text/tab-separated-values\n\n" : '';

  if ( $content_type )  { # Works now since downloads can be tsv or excel,
		                      # will need tweaking if we add xml.
    print $content_type;
    print join("\t",@{$resultset_ref->{column_list_ref}}),"\n";

		if ( $remove_markup ) {
      for ( $i = 0; $i < $nrows; $i++ ) {
	  		my @row = @{$resultset_ref->{data_ref}->[$i]};
		  	my @return_row;
			  for my $item ( @row ) {
				  $item =~ s/<[^>]*>//gm;
				  $item =~ s/\&nbsp\;//gm;
    			push @return_row, $item;
	    	}
        print join("\t",@return_row),"\n";
			}
    } else {
      for ( $i = 0; $i < $nrows; $i++ ) {
        print join("\t",@{$resultset_ref->{data_ref}->[$i]}),"\n";
			}
		}

  } else {

    $sbeams->printPageHeader();
    print "<BR><BR>ERROR: Unrecognized format '$parameters{format}'<BR>\n";
    $sbeams->printPageFooter();

  }



} # end handle_request


