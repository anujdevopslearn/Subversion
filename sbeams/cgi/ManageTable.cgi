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
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
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

$sbeamsMOD = $sbeams;

require 'ManageTable.pllib';

use constant DATA_ADMIN => 10;


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
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
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
  } elsif ($parameters{action}) { processEntryForm();
  } elsif ($q->param('apply_action_hidden')) { printEntryForm();
  } elsif ($q->param('ShowEntryForm')) { printEntryForm();
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

  my $param_ref = $args{'parameters_ref'};

  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    $param_ref->{YYYY} = 'XXXX' unless ($param_ref->{YYYY});

  } elsif ($TABLE_NAME eq "project") {
    # If we're inserting a new record, set the current contact as default PI
    if ( !defined $param_ref->{PI_contact_id} ) {
    $param_ref->{PI_contact_id} ||= $sbeams->getCurrent_contact_id();
    }

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
    
  } elsif ($TABLE_NAME eq "project") {
    # If updating project need to know existing PI and contact.priv <= DATA_ADM 
    if ( $parameters{apply_action} eq 'UPDATE' ) {
      my $contact_id = $sbeams->getCurrent_contact_id();
      
      my ( $original_pi ) = $sbeams->selectOneColumn( <<"      END" );
      SELECT pi_contact_id FROM $TB_PROJECT
      WHERE project_id = $parameters{project_id}
      END
      $query_parameters_ref->{original_pi} = $original_pi;
      return if $original_pi eq $parameters{PI_contact_id};
      
      # Make sure current user has admin on this project if PI changed
      my $best = $sbeams->get_best_permission (
                                          project_id => $parameters{project_id},
                                          contact_id => $contact_id
                                               );
      unless ( $best && $best <= DATA_ADMIN ) {
        return "You must be an administrator on this project to edit the PI";
      }
    } 
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
   
  my $contact_id = $sbeams->getCurrent_contact_id();
  my $work_group_id = $sbeams->getCurrent_work_group_id();

  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";

  } elsif ($TABLE_NAME eq "project") { # Project AMD has extra baggage
    use constant DEBUG => 1;

    my $priv; my $stat;
    # Prepare hashes for updates/inserts
    # Values needed for INSERT into user_proj_perms
    my %insertUPP = ( project_id => $parameters{project_id},
                   privilege_id => DATA_ADMIN,
                   comment => 'Autocreated by SBEAMS',
                   record_status => 'N' );

    # Values needed for UPDATE of user_proj_perms
    my %updateUPP = ( privilege_id => DATA_ADMIN, record_status => 'N' );

    # Common values for updateOrInsertRow
    my %updOrInsInfo = ( table_name => $TB_USER_PROJECT_PERMISSION,
                         add_audit_parameters => 1,
                       );
    my $project = $parameters{project_id};
    my $orig_pi = $parameters{original_pi};
    my $pi_contact = $parameters{PI_contact_id};
                         
    if ( $parameters{apply_action} eq 'INSERT' ) { 

      if ( $pi_contact != $contact_id ) { 
        # We inserted by proxy. Insert contact_id as a user_project admin

        $sbeams->updateOrInsertRow( %updOrInsInfo,
                                    insert => 1,
                                    rowdata_ref => 
                                    { %insertUPP, contact_id => $contact_id } 
                                  );
      }

    } elsif ( $parameters{apply_action} eq 'UPDATE' ) { 
      # UPDATE; PI changed ?

      if ( $orig_pi != $pi_contact ) {
        # Yes; PI == contact ?  
      
        # Fetch existing UPP entries for contact and original pi
        my $upp_orig_pi = $sbeams->getUserProjectPermission(
                                                      project_id => $project,
                                                      contact_id => $orig_pi
                                                           );
        my $upp_contact = $sbeams->getUserProjectPermission(
                                                      project_id => $project,
                                                      contact_id => $contact_id
                                                           );
        my $upp_new_pi = $sbeams->getUserProjectPermission(
                                                      project_id => $project,
                                                      contact_id => $pi_contact
                                                           );

        # Since the pi changed, we need to make sure the current PI doesn't
        # have a stray upp record. 
        if ( !defined $$upp_new_pi{id} ) {
          # No; we're cool 
        } else {
          # Yes; 'delete' old record
          if ( $$upp_new_pi{status} ne 'D' ) {
          $sbeams->updateOrInsertRow( %updOrInsInfo,
                                      update => 1,
                                      PK_value => $$upp_new_pi{id},
                                      PK_name => 'user_project_permission_id',
                                      rowdata_ref => 
                                       { %updateUPP, record_status => 'D' } 
                                );
          }
        } # end upp exists block

        
        if ( $contact_id == $pi_contact ) {
          # Yes.  upp record needed for original_pi, cannot exist for new one

          # Does upp entry already exist for original_pi? 
          if ( !defined $$upp_orig_pi{id} ) {
            # No; insert upp for c 
            $sbeams->updateOrInsertRow( %updOrInsInfo,
                                        insert => 1,
                                        rowdata_ref => 
                                         { %insertUPP, contact_id => $orig_pi } 
                                  );
          } else {
            # Yes; upgrade to admin iff necessary 
            if ( $$upp_orig_pi{privilege} != DATA_ADMIN ||
                 $$upp_orig_pi{status} eq 'D' ) {

            $sbeams->updateOrInsertRow( %updOrInsInfo,
                                        update => 1,
                                        PK_value => $$upp_orig_pi{id},
                                        PK_name => 'user_project_permission_id',
                                        rowdata_ref => 
                                         { %updateUPP } 
                                      );
            }
          } # end upp_exists block

          # upp entry for contact? contact now = pi, delete entry if it exists
          if ( !defined $$upp_contact{id} ) {
            # No; we're cool 
          } else {
            # Yes; 'delete' old record
            if ( $$upp_contact{status} ne 'D' ) {
            $sbeams->updateOrInsertRow( %updOrInsInfo,
                                        update => 1,
                                        PK_value => $$upp_contact{id},
                                        PK_name => 'user_project_permission_id',
                                        rowdata_ref => 
                                         { %updateUPP, record_status => 'D' } 
                                  );
            }
          } # end upp_exists block

        } else {
          # No; upp record needed for contact AND original pi

          # Does contact have existing record?
          if ( !defined $$upp_contact{id} ) { 
            # No; insert 
            $sbeams->updateOrInsertRow( %updOrInsInfo,
                                        insert => 1,
                                        rowdata_ref => 
                                         { %insertUPP, contact_id => $contact_id } 
                                      );

          } else {
            # Yes; upgrade to admin iff necessary 
            if ( $$upp_contact{privilege} != DATA_ADMIN ||
                 $$upp_contact{status} eq 'D' ) {

            $sbeams->updateOrInsertRow( %updOrInsInfo,
                                        update => 1,
                                        PK_value => $$upp_contact{id},
                                        PK_name => 'user_project_permission_id',
                                        rowdata_ref => 
                                         { %updateUPP } 
                                      );
            }
          }
            # Now the same for the original pi
          if ( !defined $$upp_orig_pi{id} ) { 
            # No; insert 
            $sbeams->updateOrInsertRow( %updOrInsInfo,
                                        insert => 1,
                                        rowdata_ref => 
                                         { %insertUPP, contact_id => $orig_pi } 
                                      );
          } else {
            # Yes; upgrade to admin iff necessary 
            if ( $$upp_orig_pi{privilege} != DATA_ADMIN ||
                 $$upp_orig_pi{status} eq 'D' ) {

            $sbeams->updateOrInsertRow( %updOrInsInfo,
                                        update => 1,
                                        PK_value => $$upp_orig_pi{id},
                                        PK_name => 'user_project_permission_id',
                                        rowdata_ref => 
                                         { %updateUPP } 
                                      );

            } 

          } # end upp_exists block

        } # end contact = current_pi

      } else {
        # PI unchanged, do nothing
      } # end contact = original_pi
         
    } elsif ( $parameters{apply_action} eq 'DELETE' ) {
      # DELETE; will we even get here? 
    } else {
      # Shouldn't get here
      print STDERR "Unknown action, report this error\n";
    } # end apply_action block
    
  } # end tablename eq 'XXX' block


  #### Otherwise, no special processing, so just return undef
  return;

} # end postUpdateOrInsertHook

