#!/usr/local/bin/perl

###############################################################################
# Program     : GetResultset.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program dumps the ResultSet data to the user
#               in various formats
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Basic SBEAMS setup
###############################################################################
use strict;
use lib qw (../lib/perl);
use vars qw ($q $sbeams $sbeamsPROT
             $current_contact_id $current_username );
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;


###############################################################################
# Define global variables if any and execute main()
###############################################################################
main();


###############################################################################
# Main Program:
#
# If $sbeams->Authenticate() succeeds, print header, process the CGI request,
# print the footer, and end.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    #connect_read_only=>1,
    #### This allows automated,passwordless access to resultsets
    allow_anonymous_access=>1
  ));


    #### Don't print the headers, and provide the data
    #$sbeamsPROT->printPageHeader();
    processRequests();
    #$sbeamsPROT->printPageFooter();

} # end main


###############################################################################
# Process Requests
#
# Test for specific form variables and process the request
# based on what the user wants to do.
###############################################################################
sub processRequests {
    $current_username = $sbeams->getCurrent_username;
    $current_contact_id = $sbeams->getCurrent_contact_id;


    # Enable for debugging
    if (0==1) {
      print "Content-type: text/html\n\n";
      my ($ee,$ff);
      foreach $ee (keys %ENV) {
        print "$ee =$ENV{$ee}=<BR>\n";
      }
      foreach $ee ( $q->param ) {
        $ff = $q->param($ee);
        print "$ee =$ff=<BR>\n";
      }
    }


    #### Only one view available for this program
    printEntryForm();


} # end processRequests



###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

  #### Define some general variables
  my ($i,$element,$key,$value,$line,$result,$sql);
  my %parameters;
  my %resultset = ();
  my $resultset_ref = \%resultset;


  #### Define the parameters that can be passed by CGI
  my @possible_parameters = qw ( rs_set_name format );


  #### Read in all the passed parameters into %parameters hash
  foreach $element (@possible_parameters) {
    $parameters{$element}=$q->param($element);
  }
  my $apply_action  = $q->param('apply_action');


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


  if (uc($parameters{format}) eq "TSV") {

    print "Content-type: text/tab-separated-values\n\n";

    print join("\t",@{$resultset_ref->{column_list_ref}}),"\n";
    for ($i=0; $i<$nrows; $i++) {
      print join("\t",@{$resultset_ref->{data_ref}->[$i]}),"\n";
    }

  } elsif (uc($parameters{format}) eq "EXCEL") {

    print "Content-type: application/excel\n\n";

    print join("\t",@{$resultset_ref->{column_list_ref}}),"\n";
    for ($i=0; $i<$nrows; $i++) {
      print join("\t",@{$resultset_ref->{data_ref}->[$i]}),"\n";
    }

  } else {

    $sbeamsPROT->printPageHeader();
    print "<BR><BR>ERROR: Unrecognized format '$parameters{format}'<BR>\n";
    $sbeamsPROT->printPageFooter();

  }



} # end printEntryForm


