#!/usr/local/bin/perl -w

###############################################################################
# Program     : checkUsers.pl
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
  --include_users     Comma-separated list of users to process
  --exclude_users     Comma-separated list of users to exclude from processing

 e.g.:  $PROG_NAME --check --NIS yeast --SBEAMS Yeast --priv data_groupmodifier

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "include_users:s","exclude_users:s",
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
    work_group=>'Admin',
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
  my $include_users = $OPTIONS{"include_users"} || '';
  my $exclude_users = $OPTIONS{"exclude_users"} || '';


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


  my @exclude_users = split(',',$exclude_users);
  unless (@exclude_users) {
    @exclude_users = qw( access condor db2as db2fenc1 db2guest db2inst1
      finch gbrowse geap geospiza kuchkar licor qtem sbeams software
      sqladmin );
  };


  my ($unixgroup,$dbgroup,$group_list,$member,$group,$line);
  my ($contact_id,$work_group_id,$sql_query,$sql_statement);
  my (@group_members,@groups,@results,@parsed_line);


  #### Get the list of everyone in passwd
  my @contacts = `/usr/bin/ypcat passwd`;


  #### Get all current user_logins
  my $sql = qq~
    SELECT username,contact_id
      FROM $TB_USER_LOGIN
     WHERE record_status != 'D'
  ~;
  my %user_logins = $sbeams->selectTwoColumnHash($sql);


  #### Loop over each group
  foreach $member (sort @contacts) {

    @parsed_line = split(":",$member);
    my $username = $parsed_line[0];

    $line = $parsed_line[4];
    @parsed_line = split(",",$line);
    my $real_name = $parsed_line[0];
    my @name_parts = split(/\s+/,$real_name);
    my $first_name = $name_parts[0];
    my $last_name = $name_parts[1];
    my $department = $parsed_line[2];


    next if (grep { /$username/ } @exclude_users);


    #### See if the user exists in the database
    $contact_id = $user_logins{$username};

    if ($contact_id) {
      #print "$username: $contact_id\n";
      $user_logins{$username} = 0;

    } else {
      print "$username ($real_name): username not in SBEAMS\n";

      my $qqfirst_name = $sbeams->convertSingletoTwoQuotes($first_name);
      my $qqlast_name = $sbeams->convertSingletoTwoQuotes($last_name);
      $sql = qq~
	SELECT contact_id
	  FROM $TB_CONTACT
	 WHERE first_name = '$qqfirst_name'
	   AND last_name = '$qqlast_name'
      ~;
      my ($contact_id) = $sbeams->selectOneColumn($sql);
      if ($contact_id) {
	print "  but they do seem to be a contact with id $contact_id\n";
      }


    }

  }


  print "\nSBEAMS user_logins without yppasswd user_logins\n";
  foreach my $key ( sort(keys(%user_logins)) ) {
    my $value = $user_logins{$key};
    if ($value) {
      print "$key: ???\n";
    }

  }


} # end handleRequest






