#!/usr/local/bin/perl

###############################################################################
# Program     : UpdateContacts.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script writes out to or reads in from a TSV file
#               (readable/writable by Excel) local contact information
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TESTONLY
             $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name);


#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$sbeams = new SBEAMS::Connection;


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] parameters
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --debug             Set to not actually write to database
  --source_file xxxx  Input TSV file from which contact information is loaded
  --output_file xxxx  Output TSV file to which contact information is dumped

 e.g.:  $PROG_NAME --output_file ISBcontacts.tsv

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "output_file:s","source_file:s")) {
  print "$USAGE";
  exit;
}
$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 1;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  DBVERSION = $DBVERSION\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit 0;



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'Microarray_admin'
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


  #### Define standard variables
  my ($i,$element,$element_value,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $source_file = $OPTIONS{"source_file"} || '';
  my $output_file = $OPTIONS{"output_file"} || '';

  $TESTONLY = $OPTIONS{'testonly'} || 0;
  #$TESTONLY = 1;


  #### If there are any parameters left, complain and print usage
  if ($ARGV[0]){
    print "ERROR: Unresolved parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }



  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }

  #### If an output_file was specified
  if ($output_file) {

    #### SQL to get all the data out of contacts
    $sql = qq ~
      SELECT UL.username,C.last_name,C.first_name,C.middle_name,
             CT.contact_type_name,C.job_title,
             SC.first_name+' '+SC.last_name AS 'supervisor_name',
             C.is_at_local_facility,C.photo_filename,
	     OrgO.organization AS 'organization',
             DepO.organization AS 'department',
             LabO.organization AS 'lab',
             GrpO.organization AS 'group',
	     C.location,C.alternate_location,C.phone,C.phone_extension,
	     C.cell_phone,C.pager,C.is_messenging_pager,C.home_phone,
	     C.fax,C.email,C.alternate_email,C.comment
	FROM $TB_CONTACT C     
        LEFT JOIN $TB_USER_LOGIN UL ON (C.contact_id=UL.contact_id AND UL.record_status != 'D')
        LEFT JOIN $TB_CONTACT_TYPE CT ON (C.contact_type_id=CT.contact_type_id)
        LEFT JOIN $TB_CONTACT SC ON (C.supervisor_contact_id=SC.contact_id)
	LEFT JOIN $TB_ORGANIZATION OrgO ON (C.organization_id=OrgO.organization_id)
	LEFT JOIN $TB_ORGANIZATION DepO ON (C.department_id=DepO.organization_id)
        LEFT JOIN $TB_ORGANIZATION LabO ON (C.lab_id=LabO.organization_id)
        LEFT JOIN $TB_ORGANIZATION GrpO ON (C.group_id=GrpO.organization_id)
       WHERE C.record_status != 'D'
       ORDER BY C.last_name,C.first_name
    ~;


    #### Fetch the results from the database server
    my %resultset = ();
    my $resultset_ref = \%resultset;
    $sbeams->fetchResultSet(sql_query=>$sql,
      resultset_ref=>$resultset_ref);


    #### Write the resultset.  There should be a method for this.
    #### displayResultSet already does this, but wants to do it to stdout
    open(OUTFILE,">$output_file") || die "Unable to open $output_file";
    print OUTFILE join("\t",@{$resultset_ref->{column_list_ref}}),"\n";
    foreach $element (@{$resultset_ref->{data_ref}}) {
	foreach $element_value(@{$element}){
	    $element_value =~ s/[\r\n\t]//g;
	}
      print OUTFILE join("\t",@{$element}),"\n";
    }
    close(OUTFILE);


  } elsif ($source_file) {

    #### Check to make sure file exists
      open(INFILE,"$source_file") || die "Unable to open $source_file";

    #### Check to make sure file is in the correct format
      $line = <INFILE>;
      $line =~ s/[\r\n]//g;
      my @column_names = split("\t", $line);
      my $n_columns = @column_names;
      close(INFILE);
      if ($n_columns == 25){
	  my @ref_columns = ('username', 'last_name', 'first_name', 'middle_name', 
			     'contact_type_name','job_title','supervisor_name',
			     'is_at_local_facility','photo_filename','organization',
			     'department','lab','group','location','alternate_location',
			     'phone','phone_extension','cell_phone','pager',
			     'is_messenging_pager','home_phone','fax','email',
			     'alternate_email','comment');
	  for ($i=0; $i<$n_columns;$i++){
	    if ($column_names[$i] =~ /^\"(.*)\"$/) {
		$column_names[$i] = $1;
	    }
	    if ($ref_columns[$i] ne $column_names[$i]){
		print "ERROR: File header verification failed.\n";
		print " Expected column $i to be '$ref_columns[$i]' but it appears ".
		    "to be '$column_names[$i]'.  This is unexpected and we cannot ".
		    "continue.  Please resolve and retry.\n";
		return;
	    }
	  }
      } else {
         print "ERROR: File header verification failed (number of column headers).\n";
      }



    #### Load lookup hashes for supervisor, department, lab, etc.
    $sql = "SELECT contact_type_name,contact_type_id FROM $TB_CONTACT_TYPE ".
	   "WHERE record_status !='D'";
      #print "\n---contact type ids---\n$sql\n";
      my %contact_type_ids = $sbeams->selectTwoColumnHash($sql);
    

    $sql = "SELECT first_name + ' ' + last_name, contact_id FROM $TB_CONTACT ".
	   "WHERE record_status !='D'";
      #print "\n---supervisor ids---\n$sql\n";
    my %supervisor_ids = $sbeams->selectTwoColumnHash($sql);


    $sql = "SELECT organization, organization_id ".
	   "FROM $TB_ORGANIZATION O ".
	   "JOIN organization_type OT ON (O.organization_type_id=OT.organization_type_id) ".
	   "WHERE organization_type_name IN ('Non-profit organization','For-profit company','UNKNOWN') AND O.record_status !='D'";
      #print "\n---organization ids---\n$sql\n";
    my %organization_ids = $sbeams->selectTwoColumnHash($sql);

   
    $sql = "SELECT organization, organization_id ".
	   "FROM $TB_ORGANIZATION O ".
	   "JOIN organization_type OT ON (O.organization_type_id=OT.organization_type_id) AND O.record_status !='D'".
	   "WHERE organization_type_name = 'Department' ";
      #print "\n---department ids---\n$sql\n";
    my %department_ids = $sbeams->selectTwoColumnHash($sql);

	  
    $sql = "SELECT organization, organization_id ".
	   "FROM $TB_ORGANIZATION O ".
	   "JOIN organization_type OT ON (O.organization_type_id=OT.organization_type_id) ".
	   "WHERE organization_type_name = 'Group' AND O.record_status !='D'";
      #print "\n---group ids---\n$sql\n";
    my %group_ids = $sbeams->selectTwoColumnHash($sql);


    $sql = "SELECT organization, organization_id ".
	   "FROM $TB_ORGANIZATION O ".
	   "JOIN organization_type OT ON (O.organization_type_id=OT.organization_type_id) ".
	   "WHERE organization_type_name = 'Lab' AND O.record_status !='D'";
      #print "\n---lab ids---\n$sql\n";
    my %lab_ids = $sbeams->selectTwoColumnHash($sql);


    #### Define column map
      my %column_map = (
	'1'=>'last_name',
	'2'=>'first_name',
	'3'=>'middle_name',
	'4'=>'contact_type_id',
	'5'=>'job_title',
	'6'=>'supervisor_contact_id',
	'7'=>'is_at_local_facility',
	'8'=>'photo_filename',
	'9'=>'organization_id',
	'10'=>'department_id',
	'11'=>'lab_id',
	'12'=>'group_id',
	'13'=>'location',
	'14'=>'alternate_location',
	'15'=>'phone',
	'16'=>'phone_extension',
	'17'=>'cell_phone',
	'18'=>'pager',
        '19'=>'is_messenging_pager',
        '20'=>'home_phone',
        '21'=>'fax',
        '22'=>'email',
        '23'=>'alternate_email',
	'24'=>'comment'
      );


  #### Define the transform map
  #### (see sbeams/lib/scripts/PhenoArray/update_plasmids.pl)
  my %transform_map = (
    '4' => \%contact_type_ids,
    '6' => \%supervisor_ids,
    '9' => \%organization_ids,
    '10'=> \%department_ids,
    '11'=> \%lab_ids,
    '12'=> \%group_ids,
     );

  my %update_keys = (
    'last_name'=>'1',
    'first_name'=>'2',
    'middle_name'=>'3',
     );


    #### Define a hash to receive the contact_ids
    my %username_contact_ids = ();

    #### Execute $sbeams->transferTable() to update contact table
    #### See ./update_driver_tables.pl
      print "\nTransferring $source_file -> contact";
      $sbeams->transferTable(
	source_file=>$source_file,
	delimiter=>'\t',
	skip_lines=>'1',
	dest_PK_name=>'contact_id',
	dest_conn=>$sbeams,
	column_map_ref=>\%column_map,
	transform_map_ref=>\%transform_map,
	table_name=>$TB_CONTACT,
	update=>1,
	update_keys_ref=>\%update_keys,
	verbose=>$VERBOSE,
	testonly=>$TESTONLY,
	add_audit_parameters=>1,
        newkey_map_ref=>\%username_contact_ids,
        src_PK_column=>0,
      );



    #### Create the array of usernames to update
    print "\n----\n";
    my @usernames_data = ();
    while ( ($key,$value) = each %username_contact_ids) {
      if ($key) {
        push(@usernames_data,[$key,$value,30]);
      }
    }


    #### Define column map
    my %column_map = (
      '0'=>'username',
      '1'=>'contact_id',
      '2'=>'privilege_id',
    );


    #### Define the transform map
    #### (see sbeams/lib/scripts/PhenoArray/update_plasmids.pl)
    my %transform_map = (
    );

    my %update_keys = (
      'contact_id'=>'1',
     );


    #### Execute $sbeams->transferTable() to update user_login table
    #### See ./update_driver_tables.pl
    print "\nTransferring $source_file -> user_login";
    $sbeams->transferTable(
      source_array_ref=>\@usernames_data,
      dest_PK_name=>'user_login_id',
      dest_conn=>$sbeams,
      column_map_ref=>\%column_map,
      transform_map_ref=>\%transform_map,
      table_name=>$TB_USER_LOGIN,
      update=>1,
      update_keys_ref=>\%update_keys,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
      add_audit_parameters=>1,
    );










    #### Execute $sbeams->transferTable() to update user_login
#	  print "\nTransferring $source_file -> user_login";
#	  $sbeams->transferTable(
#				 source_file=>$source_file,
#				 delimiter=>'\t',
#				 skip_lines=>'1',
#				 dest_PK_name=>'user_login_id',
#				 dest_conn=>$sbeams,
#				 column_map_ref=>##add
#				 transform_map_ref=>#add
#				 table_name=>"mjohnson.dbo.user_login",
#				 update->1,
#				 update_keys_ref=>#add,
#				 verbose=>$VERBOSE,
#				 testonly=>$TESTONLY,
#				 );
  } else {
    print "ERROR: Must supply either source_file or output_file.\n";
    print "$USAGE";
    return;
  }



} # end handleRequest
