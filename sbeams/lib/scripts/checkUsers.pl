#!/usr/local/bin/perl

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
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($sbeams $dbh $PROGRAM_FILE_NAME
             $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name);
use lib qw (../perl);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

$sbeams = new SBEAMS::Connection;
$| = 1;


###############################################################################
# Global Variables
###############################################################################
$PROGRAM_FILE_NAME = 'checkUsers.pl';
main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main {

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username =
        $sbeams->Authenticate(work_group=>'Admin'));

    #### Print the header, do what the program does, and print footer
    $sbeams->printTextHeader();
    showMainPage();
    $sbeams->printTextFooter();

} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub showMainPage {

  $current_username = $sbeams->getCurrent_username;
  $current_contact_id = $sbeams->getCurrent_contact_id;
  $current_work_group_id = $sbeams->getCurrent_work_group_id;
  $current_work_group_name = $sbeams->getCurrent_work_group_name;


  $sbeams->printUserContext(style=>'TEXT');
  print "\n";


  my $NOWRITE = 1;

  #### Define a mapping of YP groups to SBEAMS groups
  my %groupMapping = (
    proteomics => "Proteomics_user",
    comp_bio => "Comp_Bio"
  );

  my @excluded_users = qq( db2inst1 sbeams geospiza geap jbuhler access
    badzioch db2guest sqladmin software db2fenc1 3700user kuchkar licor
    db2as );


  my ($unixgroup,$dbgroup,$group_list,$member,$group,$line);
  my ($contact_id,$work_group_id,$sql_query,$sql_statement);
  my (@group_members,@groups,@results,@parsed_line);


  #### Loop over each group
  my @contacts = `/usr/bin/ypcat passwd`;

  my $sql = "SELECT username,contact_id FROM $TB_USER_LOGIN WHERE record_status != 'D'";
  my %user_logins = $sbeams->selectTwoColumnHash($sql);

  foreach $member (@contacts) {

    @parsed_line = split(":",$member);
    my $username = @parsed_line[0];

    $line = $parsed_line[4];
    @parsed_line = split(",",$line);
    my $real_name = $parsed_line[0];
    my @name_parts = split(/\s+/,$real_name);
    my $first_name = $name_parts[0];
    my $last_name = $name_parts[1];
    my $department = $parsed_line[2];


    next if (grep { /$username/ } @excluded_users);

    #### See if the user exists in the database
    $contact_id = $user_logins{$username};

    if ($contact_id) {
      #print "$username: $contact_id\n";
      $user_logins{$username} = 0;

    } else {
      print "$username: (not in db)\n";
    }

  }


  print "SBEAMS user_logins without yppasswd user_logins\n";
  while ( my ($key,$value) = each %user_logins) {
    if ($value) {
      print "$key: ???\n";
    }

  }


} # end showMainPage






