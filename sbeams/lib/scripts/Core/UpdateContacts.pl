#!/usr/local/bin/perl

###############################################################################
# Program     : UpdateContacts.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script writes out to or reads in from a TSV file
#               (readable/writable by Excel) local contact information
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
$TESTONLY = $OPTIONS{"testonly"} || 0;
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
    $sbeams->Authenticate(work_group=>'Arrays'
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
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Set the command-line options
  my $source_file = $OPTIONS{"source_file"} || '';
  my $output_file = $OPTIONS{"output_file"} || '';

  $TESTONLY = $OPTIONS{'testonly'} || 0;
  $TESTONLY = 1;


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
             DepO.organization AS 'department',
             GrpO.organization AS 'group',
             LabO.organization AS 'lab',
	     C.location,C.alternate_location,C.phone,C.phone_extension,
	     C.cell_phone,
             C.comment
        FROM $TB_CONTACT C
        LEFT JOIN $TB_USER_LOGIN UL ON (C.contact_id=UL.contact_id)
        LEFT JOIN $TB_CONTACT_TYPE CT ON (C.contact_type_id=CT.contact_type_id)
        LEFT JOIN $TB_CONTACT SC ON (C.supervisor_contact_id=SC.contact_id)
        LEFT JOIN $TB_ORGANIZATION DepO
             ON (C.department_id=DepO.organization_id)
        LEFT JOIN $TB_ORGANIZATION GrpO ON (C.group_id=DepO.organization_id)
        LEFT JOIN $TB_ORGANIZATION LabO ON (C.lab_id=DepO.organization_id)
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
      print OUTFILE join("\t",@{$element}),"\n";
    }
    close(OUTFILE);


  } elsif ($source_file) {

    #### Check to make sure file exists

    #### Check to make sure file is correct format

    #### Load lookup hashes for supervisor, department, lab, etc.

    #### Execute $sbeams->transferTable() to update contact table

    #### Execute $sbeams->transferTable() to update user_login

  } else {
    print "ERROR: Must supply either source_file or output_file.\n";
    print "$USAGE";
    return;
  }



} # end handleRequest

