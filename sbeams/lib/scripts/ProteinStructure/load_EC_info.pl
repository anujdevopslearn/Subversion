#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_EC_info.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads information from some of Rich's custom
#               PDB and PFAM to EC mapping files
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::ProteinStructure;
use SBEAMS::ProteinStructure::Settings;
use SBEAMS::ProteinStructure::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::ProteinStructure;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

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
  --delete_existing   Delete the existing data before trying to load
  --domain_match_type Update the data with information in the file
  --source_file       Name of the source file from which data are loaded
  --source_type       Type of source file from which to load.
                      Current these are: RichPDB, RichPFAM

 e.g.:  $PROG_NAME --update --source_file inputfile.txt --source_type RichPDB

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "delete_existing","update_existing",
        "domain_match_type:s","source_type:s","source_file:s",
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
  print "  DBVERSION = $DBVERSION\n";
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
    work_group=>'ProteinStructure_admin',
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
  my $delete_existing = $OPTIONS{"delete_existing"} || 0;
  my $update_existing = $OPTIONS{"update_existing"} || 0;

  my $source_file = $OPTIONS{"source_file"} || '';
  my $source_type = $OPTIONS{"source_type"} || '';
  my $domain_match_type = $OPTIONS{"domain_match_type"} || '';

  #### Verify required parameters
  unless ($source_type && $source_file) {
    print "ERROR: You must specify a source_type\n\n";
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

  #### Verify the source_file
  unless ( -e "$source_file" ) {
    print "ERROR: Unable to access source_file '$source_file'\n\n";
    return;
  }


  #### Verify the source_type
  my $domain_match_type_id = 0;
  if ($source_type eq 'RichPDB') {
    $domain_match_type_id = 6;
  } elsif ($source_type eq 'RichPFAM') {
    $domain_match_type_id = 4;
  } else {
    print "ERROR: Unrecognized source type '$source_type'\n\n";
    return;
  }


  #### define a data has to preload all data into
  my %data;


  #### Open the source file
  unless (open(INFILE,"$source_file")) {
    print "ERROR: Unable to open for reading source_file '$source_file'\n\n";
    return;
  }


  #### If this is RichPDB format:
  if ($source_type eq 'RichPDB') {
    my $line;
    while ($line = <INFILE>) {
      $line =~ s/[\r\n]//g;
      my @columns = split(/\s+/,$line);
      my $pdb_id = $columns[0];
      if (length($pdb_id) < 4 || length($pdb_id) > 6) {
  	print "  ERROR: PDB ID '$pdb_id' out of bounds.\n";
      }

      my @EC_numbers = split(",",$columns[1]);
      foreach my $EC_number (@EC_numbers) {
  	if ($EC_number =~ /[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+/) {
  	  if (exists($data{$pdb_id}) && $data{$pdb_id}->{prev_line} ne $line) {
  	    print "WARNING: duplicate non-matching PDB entry $pdb_id\n";
  	    print "  $data{$pdb_id}->{prev_line}\n";
  	    print "  $line\n";
  	    # but proceed
  	  }
  	  $data{$pdb_id}->{EC_numbers}->{$EC_number} = 1;
  	  $data{$pdb_id}->{prev_line} = $line;
  	} else {
  	  print "ERROR: Unrecognized EC number '$EC_number' for $pdb_id\n";
  	}
      }
    }
  }


  #### If this is RichPFAM format:
  if ($source_type eq 'RichPFAM') {
    my $line;
    while ($line = <INFILE>) {
      $line =~ s/[\r\n]//g;
      my @columns = split(/\s+/,$line);
      my $pfam_id = $columns[1];
      if (length($pfam_id) !=7) {
  	print "  ERROR: PFAM ID '$pfam_id' out of bounds.\n";
      }

      if (scalar(@columns) < 3) {
        print "ERROR: Insufficient columns for '$line'\n";
        next;
      }

      my @EC_numbers = split(",",$columns[2]);
      foreach my $EC_number (@EC_numbers) {
  	if ($EC_number =~ /[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+/) {
  	  $data{$pfam_id}->{EC_numbers}->{$EC_number} = 1;
  	} else {
  	  print "ERROR: Unrecognized EC number '$EC_number' for $pfam_id\n";
  	}
      }
    }
  }


  #### Store the information
  my $counter = 0;
  foreach my $domain_name (keys %data) {
    my %rowdata;
    $rowdata{domain_match_type_id} = $domain_match_type_id;
    $rowdata{domain_name} = $domain_name;
    $rowdata{EC_numbers} = join(';',
      sort(keys(%{$data{$domain_name}->{EC_numbers}})));

    my $result = $sbeams->updateOrInsertRow(
      insert=>1,
      table_name=>$TBPS_DOMAIN,
      rowdata_ref=>\%rowdata,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

    $counter++;
    print "$counter..." if ($counter % 100 == 0);
  }


  print "\n";


} # end handleRequest
