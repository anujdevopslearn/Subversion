#!/usr/local/bin/perl -w

###############################################################################
# Program     : updateAntigens.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script updates the antigens and antibodies and related
#               information.
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Immunostain;
use SBEAMS::Immunostain::Settings;
use SBEAMS::Immunostain::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Immunostain;
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
  --verbose n          Set verbosity level.  default is 0
  --quiet              Set flag to print nothing at all except errors
  --debug n            Set debug flag
  --testonly           If set, rows in the database are not changed or added
  --source_file XXX    Source file name from which data are to be updated
  --check_status       Is set, nothing is actually done, but rather
                       a summary of what should be done is printed

 e.g.:  $PROG_NAME --check_status --source_file 45277084.htm

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
		   "source_file:s","check_status",
		  )) {
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
    work_group=>'Immunostain_user',
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
  my $check_status = $OPTIONS{"check_status"} || '';


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Verify that source_file was passed and exists
  unless ($source_file) {
    print "ERROR: You must supply a --source_file parameter\n$USAGE\n";
    return;
  }
  unless (-e $source_file) {
    print "ERROR: Supplied source_file '$source_file' not found\n";
    return;
  }


  #### Parse the source_file into rows of data
  my $new_data = parse_source_file(
    source_file => $source_file);
  unless ($new_data->{SUCCESS}) {
    print "ERROR: Unable to parse source_file\n";
    return;
  }


  #### For each for of CD data, update the database with it
  foreach my $row ( @{$new_data->{rows}} ) {

    my $antigen_name = $row->{antigen_name};

    #### INSERT or UPDATE this antigen based on the parsed information
    update_antigen(
      antigen_name => $antigen_name,
      antigen_attributes => $row,
    );


  }

  return;

}



###############################################################################
# parse_source_file
###############################################################################
sub parse_source_file {
  my %args = @_;
  my $SUB_NAME = 'parse_source_file';

  #### Decode the argument list
  my $source_file = $args{'source_file'}
   || die("ERROR[$SUB_NAME]: source_file not passed");


  #### Open the file
  unless (open(INFILE,$source_file)) {
    print "ERROR: Unable to open '$source_file'\n";
    return 0;
  }


  #### Skip header
  my $line;
  while ($line = <INFILE>) {
    last if ( $line =~ /<TD><B>CD molecule<\/B><\/TD>/ );
  }
  while ($line = <INFILE>) {
    last if ( $line =~ /<TR>/ );
  }
  $line = <INFILE>;


  #### Create an array to store the data in and result hash
  my @rows;
  my %result;
  $result{SUCCESS} = 0;


  #### Loop through the file until we're done
  while (1) {

    my %data;

    #### Parse antigen_name
    if ( $line =~ /<TD>(.+)<\/TD>/ ) {
      $data{antigen_name} = $1;
      if ($data{antigen_name} =~ /(\d+)/) {
        $data{antigen_number} = $1;
      } else {
        $data{antigen_number} = 9999;
      }
    } else {
      print "ERROR parsing at step 1: '$line'";
    }

    #### Parse alternate_names
    if ( $line =~ /<TD>(.+)<\/TD>/ ) {
      $data{alternate_names} = $1;
    } else {
      print "ERROR parsing at step 2: '$line'";
    }

    #### Parse locus_link_id
    if ( $line =~ /<TD>(.+)<\/TD>/ ) {
      $data{locus_link_id} = $1;
    } else {
      print "ERROR parsing at step 3: '$line'";
    }


    #### Parse cross reference link
    if ( $line =~ /<TD>(.+)<\/TD>/ ) {
      $data{xref_link} = $1;
    } else {
      print "ERROR parsing at step 4: '$line'";
    }

    #### Push this hash onto the @rows array
    push(@rows,\%data);

    #### Decide if we're done
    while ($line = <INFILE>) {
      next if ( $line =~ /^\s*$/ );
      last if ($line =~ /<TR>/);
      last if ($line =~ /<\/TABLE>/);
    }
    last if ($line =~ /<\/TABLE>/);

    #### Read the next line
    $line = <INFILE>;

  }


  #### Close and return
  close(INFILE);
  $result{SUCCESS} = 1;
  $result{rows} =\@rows;

  return \%result;


} # end parse_source_file



###############################################################################
# decomposeDatum
###############################################################################
sub decomposeDatum {
  my $data = shift;

  my %decomposition;
  $decomposition{name} = '';
  $decomposition{link} = '';

  if ($data =~ /<A HREF="(.+)">(.+)<\/A>/) {
    $decomposition{name} = $2;
    $decomposition{link} = $1;
  } else {
    $decomposition{name} = $data;
  }

  $decomposition{name} = '' if ($decomposition{name} =~ /^\s*&nbsp;\s*$/);

  return \%decomposition;

} # end decomposeDatum



###############################################################################
# get_antigen_id
###############################################################################
sub get_antigen_id {
  my %args = @_;
  my $SUB_NAME = 'get_antigen_id';

  #### Decode the argument list
  my $antigen_name = $args{'antigen_name'}
   || die("ERROR[$SUB_NAME]: antigen_name not passed");


  #### Get id for this antigen from database
  my $sql = qq~
    SELECT antigen_id
      FROM $TBIS_ANTIGEN
     WHERE antigen_name = '$antigen_name'
       AND record_status != 'D'
  ~;
  my @rows = $sbeams->selectOneColumn($sql);
  my $nrows = scalar(@rows);

  #### If exactly one row was fetched, return it
  return($rows[0]) if ($nrows == 1);

  #### If nothing was returned, return 0
  return(0) if ($nrows == 0);

  #### If more than one row was returned, die
  die("ERROR[$SUB_NAME]: Query$sql\nreturned $nrows of data!");

} # end get_antigen_id



###############################################################################
# update_antigen
###############################################################################
sub update_antigen {
  my %args = @_;
  my $SUB_NAME = 'update_antigen';

  #### Decode the argument list
  my $antigen_name = $args{'antigen_name'}
   || die("ERROR[$SUB_NAME]: antigen_name not passed");
  my $antigen_attributes = $args{'antigen_attributes'}
   || die("ERROR[$SUB_NAME]: antigen_attributes not passed");


  #### Eventually we should check for/insert/update a biosequence here
  1;


  #### See if this antigen already exists
  my $antigen_id = get_antigen_id(
    antigen_name => $antigen_name,
  );


  #### If so, UPDATE it; if not INSERT it
  my $insert = 1;
  my $update = 0;
  if ($antigen_id) {
    $update = 1;
    $insert = 0;
    print "Antigen '$antigen_name' already exists with id $antigen_id\n";
  } else {
    print "Antigen '$antigen_name' does not yet exist.  Add it.\n";
  }


  #### Define the rowdata to be INSERTed/UPDATEd
  my %rowdata = (
    antigen_name => $antigen_name,
    alternate_names => $antigen_attributes->{alternate_names},
    sort_order => $antigen_attributes->{antigen_number},
  );


  #### Do the INSERT/UPDATE
  my $returned_PK = $sbeams->updateOrInsertRow(
    insert => $insert,
    update => $update,
    table_name => "$TBIS_ANTIGEN",
    rowdata_ref => \%rowdata,
    PK => "antigen_id",
    PK_value => $antigen_id,
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY
  );

  #### Verify we got the PK back
  unless ($returned_PK) {
    die("ERROR: PK not returned from database\n");
  }


  #### See if there's an antibody corresponding to this antigen_id
  1;


} # end update_antigen



