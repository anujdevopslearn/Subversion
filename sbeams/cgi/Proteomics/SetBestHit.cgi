#!/usr/local/bin/perl

###############################################################################
# Program     : SetBestHit.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               set the best_hit_flag for a given search_hit_id (and
#               correspondingly clear the flag for other hits)
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($q $sbeams $sbeamsPROT $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);
use DBI;
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
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Global Variables
###############################################################################
main();


###############################################################################
# Main Program:
#
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Print the header, do what the program does, and print footer
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
    $current_work_group_id = $sbeams->getCurrent_work_group_id;
    $current_work_group_name = $sbeams->getCurrent_work_group_name;
    $current_project_id = $sbeams->getCurrent_project_id;
    $current_project_name = $sbeams->getCurrent_project_name;
    $dbh = $sbeams->getDBHandle();


    # Enable for debugging
    if (0==1) {
      print "Content-type: text/html\n\n";
      my ($ee,$ff);
      foreach $ee (keys %ENV) {
        print "$ee =$ENV{$ee}=<BR>\n";
      }
      foreach $ee ( $q->param ) {
        $ff = join(",",$q->param($ee));
        print "$ee=$ff<BR>\n";
      }
    }


    updateBestHitFlag();


} # end processRequests


###############################################################################
# updateBestHitFlag
###############################################################################
sub updateBestHitFlag {

  my ($i,$element,$key,$value,$line,$result,$sql);
  my %parameters;


  $sbeams->printUserContext();
  print qq~
	<P>
	<H2>Return Status</H2>
	$LINESEPARATOR
	<P>
  ~;


  #### Define the possible passed parameters
  my @columns = ("search_hit_id");


  #### Read the form values for each column
  foreach $element (@columns) {
    $parameters{$element}=$q->param($element);
    #print "$element = $parameters{$element}<BR>\n";
  }


  #### verify that needed parameters were passed
  unless ($parameters{search_hit_id}) {
    print "ERROR: not all needed parameters were passed.  This should never ".
      "happen!  Record was not updated.<BR>\n";
    return;
  }


  #### Find the corresponding search_id for this record
  $sql = "SELECT search_id FROM $TBPR_SEARCH_HIT ".
         " WHERE search_hit_id = '$parameters{search_hit_id}'";
  my ($search_id) = $sbeams->selectOneColumn($sql);
  unless ($search_id) {
    print "ERROR: Unable to determine the search_id from search_hit_id".
      " = '$parameters{search_hit_id}'.  This really should never ".
      "happen!  Record was not updated.<BR>\n";
    return;
  }


  #print "search_id = $search_id<BR><BR><BR>\n";


  #### Prepare the clearing information into the hash
  my %rowdata;
  $rowdata{best_hit_flag} = '';


  #### Clear the previous best_hit_flags
  #### Note that I have lied about the PK here, so the UPDATE actually
  #### updates all search_hits for this search.  This might possibly cause
  #### some problems later if insert_update_row starts trying to do
  #### security checking
  $result = $sbeams->insert_update_row(update=>1,
    table_name=>"$TBPR_SEARCH_HIT",
    rowdata_ref=>\%rowdata,PK=>"search_id",
    PK_value => $search_id,
    #,verbose=>1,testonly=>1
  );


  #### Now set the best_hit_flag for the desired search_hit
  $rowdata{best_hit_flag} = 'U';
  $result = $sbeams->insert_update_row(update=>1,
    table_name=>"$TBPR_SEARCH_HIT",
    rowdata_ref=>\%rowdata,PK=>"search_hit_id",
    PK_value => $parameters{search_hit_id},
    #,verbose=>1,testonly=>1
  );


  my $back_button = $sbeams->getGoBackButton();
  if ($result) {
    print qq~
	<B>UPDATE was successful!</B><BR><BR>
	Please note that although the data has
	been changed in the database, previous web pages will still show the
	old value.  Redo the [QUERY] to see the updated data table<BR><BR>
	<CENTER>$back_button</CENTER>
	<BR><BR>
    ~;
  } else {
    print qq~
	UPDATE has failed!  This should never happen.  Please report this<BR>
	<CENTER>$back_button</CENTER>
	<BR><BR>
    ~;
  }


} # end updateBestHitFlag


