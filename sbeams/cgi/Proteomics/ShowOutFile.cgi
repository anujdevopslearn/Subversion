#!/usr/local/bin/perl

###############################################################################
# Program     : ShowOutFile.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program displays the requested .out file
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
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
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($q $sbeams $sbeamsPROT
             $current_contact_id $current_username );
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsPROT = new SBEAMS::Proteomics;
$sbeamsPROT->setSBEAMS($sbeams);


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
    permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin',
      'Proteomics_readonly'],
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
  ));

  #### Print the header, figure and do what the user want, and print footer
  $sbeamsPROT->printPageHeader();
  processRequests();
  $sbeamsPROT->printPageFooter();

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
  my ($i,$element,$key,$value,$sql);

  $sbeams->printUserContext();


  #### Define the parameters that can be passed by CGI
  my @possible_parameters = qw ( search_id );
  my %parameters;


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
  unless ($parameters{search_id}) {
    print "ERROR: not all needed parameters were passed.  This should never ".
      "happen!  Please report this error.<BR>\n";
    return;
  }


  #### Find the corresponding information for this search_id
  $sql = qq~
	SELECT SB.data_location+'/'+F.fraction_tag AS 'location',
	       F.fraction_tag+'/'+S.file_root+'.out' AS 'name',
               S.file_root,SB.data_location,F.fraction_tag
	  FROM $TBPR_SEARCH S
	 INNER JOIN $TBPR_SEARCH_BATCH SB
               ON ( S.search_batch_id = SB.search_batch_id )
	 INNER JOIN $TBPR_MSMS_SPECTRUM MS
               ON ( S.msms_spectrum_id = MS.msms_spectrum_id )
	 INNER JOIN $TBPR_FRACTION F ON ( MS.fraction_id = F.fraction_id )
	 WHERE search_id = '$parameters{search_id}'
  ~;

  my @rows = $sbeams->selectSeveralColumns($sql);
  unless (@rows) {
    print "ERROR: Unable to find any location for search_id".
      " = '$parameters{search_id}'.  This really should never ".
      "happen!  Please report the problem.<BR>\n";
    return;
  }

  my $location = $rows[0]->[0];
  my $name = $rows[0]->[1];
  my $file_root = $rows[0]->[2];
  my $data_location = $rows[0]->[3];
  my $fraction_tag = $rows[0]->[4];


  print "<H3>File: $name</H3>\n";

  my $filename = "$location/$file_root.out";
  unless ($filename =~ /^\//) {
    $filename = $RAW_DATA_DIR{Proteomics}."/$filename";
  }

  #### Instead of accessing the .out file directly, pull it out of the .tgz
  my $use_tgz_file = 1;
  if ($use_tgz_file) {
    $filename = "tar -xzOf $RAW_DATA_DIR{Proteomics}/$data_location/".
      "$fraction_tag.tgz ./$file_root.out|";
  }

  if ( $use_tgz_file || -e $filename ) {
    my $line;
    print "<PRE>\n";
    unless (open(INFILE,$filename)) {
      print "Cannot open file!!<BR>\n";
    }
    while ($line=<INFILE>) {
      chomp $line;
      print "$line\n";
    }
    print "</PRE><BR>\n";
  } else {
    print "Cannot find filename '$filename'<BR>\n";
  }




} # end printEntryForm


