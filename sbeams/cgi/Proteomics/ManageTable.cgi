#!/usr/local/bin/perl

###############################################################################
# Program     : ManageTable.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               manage the contents of a table.
#               This means viewing, inserting, updating,
#               and deleting records.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../lib/perl ../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $dbh $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
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
use SBEAMS::Connection::TableInfo;
$q = new CGI;
$sbeams = new SBEAMS::Connection;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Proteomics::TableInfo;
$sbeamsMOD = new SBEAMS::Proteomics;

$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

require 'ManageTable.pllib';



###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value kay=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
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
# Set maximum post (file upload) to 10 MB
$CGI::POST_MAX = 1024 * 10000;
main();
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
    permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));

  $TABLE_NAME = $q->param('TABLE_NAME')
    || croak "TABLE_NAME not specified."; 

  croak "This TABLE_NAME=$TABLE_NAME cannot be managed by this program."
    unless ($sbeamsMOD->returnTableInfo($TABLE_NAME,
      "ManageTableAllowed"))[0] eq "YES";

  ($CATEGORY) = $sbeamsMOD->returnTableInfo($TABLE_NAME,"CATEGORY");
  ($PROGRAM_FILE_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,
    "PROGRAM_FILE_NAME");
  ($DB_TABLE_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,"DB_TABLE_NAME");
  ($PK_COLUMN_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,
    "PK_COLUMN_NAME");
  @MENU_OPTIONS = $sbeamsMOD->returnTableInfo($TABLE_NAME,"MENU_OPTIONS");

  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);


  #### Print the header, do what the program does, and print footer
  $sbeamsMOD->printPageHeader();
  processRequests(ref_parameters=>\%parameters);
  $sbeamsMOD->printPageFooter();

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

    # Decide where to go based on form values
    if      ($q->param('apply_action') eq 'VIEWRESULTSET') { printOptions();
    } elsif ($q->param('apply_action')) { processEntryForm();
    } elsif ($q->param('apply_action_hidden')) { printEntryForm();
    } elsif ($q->param('ShowEntryForm')) { printEntryForm();
    } elsif ($q->param("$PK_COLUMN_NAME")) { printEntryForm();
    } else { printOptions();
    } # end if

} # end processRequests



###############################################################################
# preFormHook
#
# This is a hook to do some processing before all the lines of data entry
# form have been displayed based on the current table name.  This might be
# used to set some defaults or something.
###############################################################################
sub preFormHook {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};


  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    $query_parameters_ref->{YYYY} = 'XXXX'
      unless ($query_parameters_ref->{YYYY});
  }


  #### For search_hit_annotations, set the source to be "by hand" unless
  #### there's already a value
  if ($TABLE_NAME eq "search_hit_annotation") {
    $query_parameters_ref->{annotation_source_id} = 1
      unless ($query_parameters_ref->{annotation_source_id});
  }


  #### Otherwise, no special processing, so just return undef
  return;

} # end preFormHook



###############################################################################
# postFormHook
#
# This is a hook to do some processing after all the lines of data entry
# form have been displayed but before the table has been closed based on
# the current table name.
###############################################################################
sub postFormHook {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};


  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";
  }


  #### Otherwise, no special processing, so just return undef
  return;

} # end postFormHook



###############################################################################
# preUpdateDataCheck
#
# For certain tables, there are additional checks that should be made before
# an INSERT or UPDATE is performed.
###############################################################################
sub preUpdateDataCheck {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};


  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";
  }


  #### Otherwise, no special processing, so just return empty string
  return '';

} # end preUpdateDataCheck


