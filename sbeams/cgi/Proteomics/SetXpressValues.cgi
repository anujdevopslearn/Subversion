#!/usr/local/bin/perl

###############################################################################
# Program     : SetXpressValues.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               set the calculated xpress values for a quantitated peak
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
use lib qw (../../lib/perl);
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


    setXpressValues();


} # end processRequests


###############################################################################
# updateBestHitFlag
###############################################################################
sub setXpressValues {

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
  my @columns = ("LightFirstScan","LightLastScan","LightMass","HeavyFirstScan","HeavyLastScan","HeavyMass","DatFile","ChargeState","OutFile","MassTol","bXpressLight1","quantitation_id","LightQuanValue","HeavyQuanValue","NewLink","NewQuan","InteractDir","OutputFile");


  #### Provide the mapping between database columns and parameter names
  my %column_mapping = (
    "d0_intensity" => "LightQuanValue",
    "d8_intensity" => "HeavyQuanValue",
    "d0_first_scan" => "LightFirstScan",
    "d0_last_scan" => "LightLastScan",
    "d0_mass" => "LightMass",
    "d8_first_scan" => "HeavyFirstScan",
    "d8_last_scan" => "HeavyLastScan",
    "d8_mass" => "HeavyMass",
    "norm_flag" => "bXpressLight1",
    "mass_tolerance" => "MassTol",
  );


  #### Read the form values for each column
  foreach $element (@columns) {
    $parameters{$element}=$q->param($element);
    print "$element = $parameters{$element}<BR>\n";
  }


  #### verify that needed parameters were passed
  unless ($parameters{quantitation_id}) {
    print "ERROR: not all needed parameters were passed.  This should never ".
      "happen!  Record was not updated.<BR>\n";
    return;
  }



  #### Verify that this quantitation_id exists
  $sql = "SELECT quantitation_id FROM $TBPR_QUANTITATION ".
         " WHERE quantitation_id = '$parameters{quantitation_id}'";
  my ($search_id) = $sbeams->selectOneColumn($sql);
  unless ($search_id) {
    print "ERROR: Unable to find quantitation_id".
      " = '$parameters{search_hit_id}'.  This really should never ".
      "happen!  Record was not updated.<BR>\n";
    return;
  }


  #### Prepare the clearing information into the hash
  my %rowdata;
  while ( ($key,$value) = each %column_mapping ) {
    $rowdata{$key} = $parameters{$value};
  }
  $rowdata{date_modified} = "CURRENT_TIMESTAMP";
  $rowdata{modified_by_id} = $current_contact_id;
  $rowdata{manually_changed} = "*";


  #### Update the record
  print "<BR><BR><BR>\n<PRE>";
  $result = $sbeams->insert_update_row(update=>1,
    table_name=>"$TBPR_QUANTITATION",
    rowdata_ref=>\%rowdata,PK=>"quantitation_id",
    PK_value => $parameters{quantitation_id},
    #,verbose=>1,testonly=>1
  );
  print "\n\n</PRE>\n";


  #### Report the result of the UPDATE
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


} # end setXpressValues


