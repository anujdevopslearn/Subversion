#!/usr/local/bin/perl -w

###############################################################################
# Program     : checkUserGroups.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script compares user data in the database with the
#               local yp passwd file.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
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

use lib "$FindBin::Bin/../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          If set, rows in the database are not changed or added
  --check             Just print information about what would be done
  --NIS_group         Specify the name of the NIS group from which to
                      extract users
  --SBEAMS_group      Name of the SBEAMS group into which to add users
  --privilege_level   Name of the privilege level the users should get
  --include_users     Comma-separated list of users to process
  --exclude_users     Comma-separated list of users to exclude from processing

 e.g.:  $PROG_NAME --check --NIS yeast --SBEAMS Yeast --priv data_groupmodifier

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "NIS_group:s","SBEAMS_group:s","privilege_level:s",
        "include_users:s","exclude_users:s","check",
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
#   work_group=>'Admin',
    work_group=>'Developer',
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);


} # end main


###############################################################################
# handleRequest
###############################################################################
sub handleRequest {
  my %args = @_;

  #### Set the command-line options
  my $NIS_group = $OPTIONS{"NIS_group"} || '';
  my $SBEAMS_group = $OPTIONS{"SBEAMS_group"} || '';
  my $privilege_level = $OPTIONS{"privilege_level"} || '';
  my $include_users = $OPTIONS{"include_users"} || '';
  my $exclude_users = $OPTIONS{"exclude_users"} || '';
  my $NOWRITE =  $OPTIONS{"check"} || 0;


  #### Verify required parameters
  unless ($SBEAMS_group) {
    print "ERROR: You must specify a --SBEAMS_group\n\n";
    print "$USAGE";
    exit;
  }


  #### Verify required parameters
  unless ($NIS_group || $include_users) {
    print "ERROR: You must specify either --NIS_group or --include_users\n\n";
    print "$USAGE";
    exit;
  }


  #### If there are any parameters left, complain and print usage
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Get the work_group_id for the supplied name
  my $work_group_id;
  unless ($work_group_id = $sbeams->get_work_group_id($SBEAMS_group)) {
    die "Failed to get work_group_id for '$SBEAMS_group'";
  }


  #### Get the privilege_levels
  my $sql;
  $sql = qq~
    SELECT name,privilege_id
      FROM $TB_PRIVILEGE P
     WHERE record_status != 'D'
  ~;
  my %privilege_ids = $sbeams->selectTwoColumnHash($sql);


  #### Parse the include and exclude users
  my @exclude_users = split(',',$exclude_users);
  my @include_users = split(',',$include_users);
  my @group_members;


  if ($NIS_group) {
    my ($group_list) = `/usr/bin/ypmatch $NIS_group group`;
    $group_list =~ s/[\n\r]//g;
    my @columns = split(/:/,$group_list);
    my $NIS_group_id = $columns[2];

    $group_list =~ s/.+://;
    @group_members = split(",",$group_list);

    my @users = `/usr/bin/ypcat passwd`;
    foreach my $user (@users) {
      my @parsed_line = split(":",$user);
      my $username = $parsed_line[0];
      my $grp = $parsed_line[3];
      if ($grp == $NIS_group_id) {
	push(@group_members,$username);
      }
    }

  } else {
    @group_members = @include_users;
  }

  foreach my $member (sort @group_members) {

    #### Skip to the next if this one is exclude
    next if (grep { /$member/ } @exclude_users);

    #### Skip to the next if this one isn't include
    if ($include_users) {
      next unless (grep { /$member/ } @include_users);
    }


    #### See if the user exists in the database
    my ($contact_id) = $sbeams->getContact_id($member);
    if ($contact_id) {

      print "$member($contact_id): ";

    } else {

      print "$member(?): (not in db)\n";

      my ($line) = `/usr/bin/ypmatch $member passwd`;
      $line =~ s/[\n\r]//g;

      #### If this user isn't even there, then squawk
      unless ($line) {
	print "  ERROR: User $member isn't even in NIS!!\n";
	next;
      }

      #### Extract information from passwd file
      my @parsed_line = split(":",$line);
      $line = $parsed_line[4];
      @parsed_line = split(",",$line);
      my $real_name = $parsed_line[0] || '';
      my @name_parts = split(/\s+/,$real_name);
      my $first_name = $name_parts[0] || '';
      my $last_name = $name_parts[1] || '';
      my $department = $parsed_line[2] || '';
      print "    add: $real_name ($department)\n";

      #### Define the data columns for the new contact
      my %rowdata = (
        first_name => $first_name,
	last_name => $last_name,
	contact_type_id => 2,
	organization_id => 1,
      );

      #### INSERT the row
      $contact_id = $sbeams->updateOrInsertRow(
  	insert => 1,
  	table_name => $TB_CONTACT,
  	rowdata_ref => \%rowdata,
        PK => 'contact_id',
        return_PK => 1,
        add_audit_parameters => 1,
  	verbose => $VERBOSE,
  	testonly => $TESTONLY,
      ) unless ($NOWRITE);


      #### Define the data columns for the new user_login
      %rowdata = (
        contact_id => $contact_id,
	username => $member,
	privilege_id => 20,
      );

      #### INSERT the row
      my $user_login_id = $sbeams->updateOrInsertRow(
  	insert => 1,
  	table_name => $TB_USER_LOGIN,
  	rowdata_ref => \%rowdata,
        PK => 'user_login_id',
        return_PK => 1,
        add_audit_parameters => 1,
  	verbose => $VERBOSE,
  	testonly => $TESTONLY,
      ) unless ($NOWRITE);

    }

    #### Make sure we have a contact_id now or skip
    unless ($contact_id) {
      print "\n";
      next;
    }


    #### Get the work groups that the user belongs to
    $sql = qq~
    	SELECT work_group_name,P.name
    	  FROM user_login UL
    	  JOIN user_work_group UWG ON ( UL.contact_id = UWG.contact_id )
    	  JOIN work_group WG ON ( UWG.work_group_id = WG.work_group_id )
    	  JOIN $TB_PRIVILEGE P ON ( UWG.privilege_id = P.privilege_id )
    	 WHERE username = '$member'
    	 ORDER BY username,work_group_name
    ~;

    my %groups = $sbeams->selectTwoColumnHash($sql);
    if (%groups) {
      print "--current: ",join(',',keys(%groups)),"\n" if ($VERBOSE);
    }


    #### If the user is already a member of this group
    if (grep { /$SBEAMS_group/ } keys(%groups)) {

     print "OK - already a member at level ".
       $groups{$SBEAMS_group}."\n";


    #### If not, then we need to add
    } else {

      unless ($privilege_ids{$privilege_level}) {
	print "ERROR: Unable to resolve privilege_level '$privilege_level' ".
	  "which is needed to added new user_work_group records.\n\n";
	return;
      }

      print "add to $SBEAMS_group group as $privilege_level\n";

      my %rowdata = (
        contact_id => $contact_id,
	work_group_id => $work_group_id,
	privilege_id => $privilege_ids{$privilege_level},
      );

      $sbeams->updateOrInsertRow(
  	insert => 1,
  	table_name => $TB_USER_WORK_GROUP,
  	rowdata_ref => \%rowdata,
        PK => 'user_work_group_id',
        return_PK => 1,
        add_audit_parameters => 1,
  	verbose => $VERBOSE,
  	testonly => $TESTONLY,
      ) unless ($NOWRITE);

    }

    print "\n";

  } # end foreach member


} # end handleRequest


