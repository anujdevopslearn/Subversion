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

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $dbh $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);
use DBI;
#use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q);;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
#$q = new CGI;
$sbeams = new SBEAMS::Connection;

use SBEAMS::Cytometry;
use SBEAMS::Cytometry::Settings;
use SBEAMS::Cytometry::Tables;
use SBEAMS::Cytometry::TableInfo;
$sbeamsMOD = new SBEAMS::Cytometry;

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
# Set maximum post (file upload) to 30 MB
$CGI::POST_MAX = 1024 * 30000;
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
   permitted_work_groups_ref=>['Cytometry_user','Cytometry_admin','Immunostain_user','Admin'],
  ));

  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);


  $TABLE_NAME = $parameters{'TABLE_NAME'}
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


  #### Decide what action to take based on information so far
  if ($parameters{"GetFile"} && $parameters{"$PK_COLUMN_NAME"}) {
    getFile(); return;
  }
  $sbeamsMOD->printPageHeader();
  if      ($parameters{action} eq 'VIEWRESULTSET') { printOptions();
  } elsif ($parameters{action} eq 'REFRESH') { printEntryForm();
  } elsif ($parameters{action} eq 'SAVE TEMPLATE') { saveTemplate();
  } elsif ($parameters{action} eq 'SET FIELDS TO THIS TEMPLATE') {
    printEntryForm();
  } elsif ($parameters{action} eq 'DELETE THIS TEMPLATE') {
    deleteTemplate(
      selected_template => $parameters{selected_template},
      program_file_name => $PROGRAM_FILE_NAME,
    );
  } elsif ($parameters{action}) { processEntryForm();
  } elsif ($q->param('apply_action_hidden')) { printEntryForm();
  } elsif ($q->param('ShowEntryForm')) {
    if (uc($TABLE_NAME) eq "CY_FCS_RUN")
    {
      my $infoString = "<center><b>
      All non-required Fields can be left blank.<br>In this case the values from the header of  the FSC file to be uploaded  will be 
      used to populate the missing information<br>
      </b><br></center>";
      print $infoString;
    }
    printEntryForm();
  } elsif ($parameters{"$PK_COLUMN_NAME"}) { printEntryForm();
  } else { printOptions(); }

  $sbeamsMOD->printPageFooter();


} # end main



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
    if ( uc($TABLE_NAME) eq "CY_FCS_RUN" )
  {
    
             
      return "Error: project  not defined" if !$parameters{project_id};
      
    my $errstr = checkPermission( fkey => 'project_id',
                                  fval => $parameters{project_id},
                                  pval => $parameters{fcs_run_id},
                                  action => $parameters{action},
                                  tname => $TABLE_NAME );

    return ( $errstr ) if $errstr;
    
    
#if it is an insert , need to 
    
  }
  
   if ( uc($TABLE_NAME) eq "CY_CYTOMETRY_SAMPLE" )
  {
      return "Error: fcs_run_id not defined" if !$parameters{project_id};

    my $errstr = checkPermission( fkey => 'project_id',
                                  fval => $parameters{project_id},
                                  pval => $parameters{cytometry_sample_id},
                                  action => $parameters{action},
                                  tname => $TABLE_NAME );

    return ( $errstr ) if $errstr;
  }
  
  
  
  if ( uc($TABLE_NAME) eq "CY_SORT_ENTITY" )
  {
     return "Error: sort_entity_id not defined" if !$parameters{project_id};

    my $errstr = checkPermission( fkey => 'project_id',
                                  fval => $parameters{project_id},
                                  pval => $parameters{sort_entity_id},
                                  action => $parameters{action},
                                  tname => $TABLE_NAME );

    return ( $errstr ) if $errstr;
  }


 if ( uc($TABLE_NAME) eq "CY_TISSUE_TYPE" )
  {
    
    return "Error: tissue_type_id not defined" if !$parameters{project_id};

    my $errstr = checkPermission( fkey => 'project_id',
                                  fval => $parameters{project_id},
                                  pval => $parameters{tissue_type_id},
                                  action => $parameters{action},
                                  tname => $TABLE_NAME );

    return ( $errstr ) if $errstr;
  }

 if ( uc($TABLE_NAME) eq "CY_MEASURED_PARAMETERS" )
  {
    
    return "Error: tissue_type_id not defined" if !$parameters{project_id};

    my $errstr = checkPermission( fkey => 'project_id',
                                  fval => $parameters{project_id},
                                  pval => $parameters{tissue_type_id},
                                  action => $parameters{action},
                                  tname => $TABLE_NAME );

    return ( $errstr ) if $errstr;
  }
  
  #### If table XXXX
  elsif ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";
  }


  #### Otherwise, no special processing, so just return empty string
  return '';

} # end preUpdateDataCheck


###############################################################################
# postUpdateOrInsertHook
#
# This is a hook to do some processing after the record has been updated
# or inserted.
###############################################################################
sub postUpdateOrInsertHook {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};
  my $pk_value = $args{'pk_value'};

  if ( uc($TABLE_NAME) eq "CY_FCS_RUN" )
  {
    if ($parameters{'action'} = 'INSERT')
    {
      my $saveFile = $TABLE_NAME.'/'.$parameters{fcs_run_id}.'_original_filepath.dat';
      $parameters{'savedFile'} = $saveFile; 
      my $string;
       foreach my $key (keys %parameters)
       {
         $string .= " ".$key ."==".$parameters{$key}; 
       }
      
       my $result = `/usr/local/bin/perl ./loadFcsWeb.pl $string
#      parameters{'processFile'} $parameters{project_id}`;
         if ($result != 1)
       {
         #delete the record
         #print the error statement
         return "Error: Could not upload $parameters{original_filepath} == $result" if $result != 1;
       }
     }
  }
  
  
  
  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";
  }


  #### Otherwise, no special processing, so just return undef
  return;

} # end postUpdateOrInsertHook

