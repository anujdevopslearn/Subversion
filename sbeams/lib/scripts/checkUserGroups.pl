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
$PROGRAM_FILE_NAME = 'importLayoutInfo.pl';
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


    #### Define a mapping of YP groups to SBEAMS groups
    my %groupMapping = (
      proteomics => "Proteomics_user",
      comp_bio => "Comp_Bio"
    );

    my $NOWRITE = 1;

    my @excluded_users = ( "culloden","visigoth1","lfeltz","administrator",
      "mharris","rwelti","mrobinson","jroach","jbuhler","asmit",
      "aamiry","btjaden","nesvi","mjohnson" );
    @excluded_users = ();


    my ($unixgroup,$dbgroup,$group_list,$member,$group,$line);
    my ($contact_id,$work_group_id,$sql_query,$sql_statement);
    my (@group_members,@groups,@results,@parsed_line);


    # Set PATH to something innocuous to keep Taint happy
    $ENV{PATH}="/bin:/usr/bin";


    #### Loop over each group
    while ( ($unixgroup,$dbgroup) = each %groupMapping ) {

      unless ($work_group_id = $sbeams->get_work_group_id($dbgroup)) {
        die "Failed to get work_group_id for 'dbgroup'";
      }

      ($group_list) = `/usr/bin/ypmatch $unixgroup group`;
      $group_list =~ s/[\n\r]//g;
      $group_list =~ s/.+://;
      @group_members = split(",",$group_list);

      foreach $member (@group_members) {

        next if (grep { /$member/ } @excluded_users);

        #### See if the user exists in the database
        ($contact_id) = $sbeams->getContact_id($member);
        unless ($contact_id) {
          print "$member: (not in db)\n";

          ($line) = `/usr/bin/ypmatch $member passwd`;
          $line =~ s/[\n\r]//g;
          @parsed_line = split(":",$line);
          $line = $parsed_line[4];
          @parsed_line = split(",",$line);
          my $real_name = $parsed_line[0];
          my @name_parts = split(/\s+/,$real_name);
          my $first_name = $name_parts[0];
          my $last_name = $name_parts[1];
          my $department = $parsed_line[2];
          print "    add: $real_name ($department)\n";

          $sql_statement = "INSERT INTO $TB_CONTACT ".
            "( first_name,last_name,contact_type_id,organization_id,department,".
            "created_by_id,modified_by_id,owner_group_id ) ".
            "VALUES ( '$first_name','$last_name',2,1,'$department',".
            "$current_contact_id,$current_contact_id,$current_work_group_id )";
          print "$sql_statement\n";
          $sbeams->executeSQL($sql_statement) unless $NOWRITE;

          ($contact_id) = $sbeams->getLastInsertedPK() unless $NOWRITE;

          $sql_statement = "INSERT INTO $TB_USER_LOGIN ".
            "( contact_id,username,privilege_id,".
            "created_by_id,modified_by_id,owner_group_id ) ".
            "VALUES ( $contact_id,'$member',30,".
            "$current_contact_id,$current_contact_id,$current_work_group_id )";
          print "$sql_statement\n";
          $sbeams->executeSQL($sql_statement) unless $NOWRITE;


        } else {
          print "$member: $contact_id\n";
        }


        #### Get the work groups that the user belongs to
        $sql_query = qq~
		SELECT work_group_name
		  FROM user_login UL
		  JOIN user_work_group UWG ON ( UL.contact_id = UWG.contact_id )
		  JOIN work_group WG ON ( UWG.work_group_id = WG.work_group_id )
		 WHERE username = '$member'
		 ORDER BY username,work_group_name
        ~;

        @groups = $sbeams->selectOneColumn($sql_query);
        if (@groups) {

          foreach $group (@groups) {
            print "$member: $group\n";
          }

        }

        unless (grep { /$dbgroup/ } @groups) {
          $sql_statement = "INSERT INTO $TB_USER_WORK_GROUP ".
            "( contact_id,work_group_id,privilege_id,created_by_id,modified_by_id,".
            "owner_group_id ) ".
            "VALUES ( $contact_id,$work_group_id,30,$current_contact_id,".
            "$current_contact_id,$current_work_group_id )";
          print "$sql_statement\n";
          $sbeams->executeSQL($sql_statement) unless $NOWRITE;
        }

        print "\n";
      }

    }



} # end showMainPage






