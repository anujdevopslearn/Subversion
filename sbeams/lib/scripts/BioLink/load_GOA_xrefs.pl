#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_GOA_xrefs.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script updates the BioLink relationship database
#               based on the data from the GOA xrefs data
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
             $DATABASE
             $current_contact_id $current_username
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::BioLink;
use SBEAMS::BioLink::Settings;
use SBEAMS::BioLink::Tables;

$sbeams = SBEAMS::Connection->new();
$sbeamsMOD = SBEAMS::BioLink->new();
$sbeamsMOD->setSBEAMS($sbeams);

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
  --delete_existing    Delete the existing biosequences for this set before
                       loading.  Normally, if there are existing biosequences,
                       the load is blocked.
  --update_existing    Update the existing biosequence set with information
                       in the file
  --check_status       Is set, nothing is actually done, but rather
                       a summary of the data is printed

 e.g.:  $PROG_NAME --check_status

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
		   "delete_existing","update_existing","check_status",
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
    work_group=>'BioLink_user',
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
  my $delete_existing = $OPTIONS{"delete_existing"} || '';
  my $update_existing = $OPTIONS{"update_existing"} || '';
  my $check_status = $OPTIONS{"check_status"} || '';


  #### FIXME
  $DATABASE = 'BioLink.dbo.';


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Get the evidence_source for this load
  my $load_evidence_source_id = get_evidence_source_id(
    evidence_source_tag => 'GOAxrefs');
  unless ($load_evidence_source_id) {
    die("Unable to determine the evidence_source_id for this load");
  }


  #### Define the biosequence set translations
  my %genelynx_namespaces = (
    HuRefseqNP => 'HuRefseqNP',
    HuIPI => 'HuIPI',
  );

  #### Make the list of namespaces to extract
  my $genelynx_list = join("','",keys(%genelynx_namespaces));

  #### Create the lookup hash for biosequence_set_ids
  my %biosequence_set_ids;
  while ( my ($key,$value) = each %genelynx_namespaces ) {
    $biosequence_set_ids{$value} = get_biosequence_set_id(
      biosequence_set_tag => $value);
    unless ($biosequence_set_ids{$value}) {
      die("Unable to determine the biosequence_set_id for $value");
    }
  }


  #### Generate the dataset to load
  $sql = qq~
    SELECT ipi_accession,refseq_np_ids
      FROM BioLink.dbo.goa_xref
  ~;

  my @rows = $sbeams->selectSeveralColumns($sql);


  #### Loop over all the input data, updating the BioLink database
  my $counter = 0;
  foreach my $row (@rows) {

    #### Extract the data from the row
    my $biosequence_name1 = $row->[0];
    my $biosequence_name2 = $row->[1];

    #### Validate BS1
    if (!defined($biosequence_name1) || $biosequence_name1 eq '') {
      print "WARNING[row $counter]: IPI number missing for row $counter\n";
      $counter++;
      next;
    }
    if ($biosequence_name1 =~ /([\ \;])/) {
      print "WARNING[row $counter]: IPI accession '$biosequence_name1' contains illegal ".
        "character '$1'!  Skipping...\n";
      $counter++;
      next;
    }


    #### Validate BS2
    if (!defined($biosequence_name2) || $biosequence_name2 eq '') {
      print "WARNING[row $counter]: NP number missing for row $counter. Skipping\n";
      $counter++;
      next;
    }
    $biosequence_name2 =~ s/[;\s]+$//g;
    my @names2 = split(";",$biosequence_name2);
    if (scalar(@names2) > 1) {
      print "WARNING[row $counter]: More than one NP number is associated with ".
        "IPI accession '$biosequence_name1': '$biosequence_name2'. ".
        "Skipping...\n";
      $counter++;
      next;
    }
    $biosequence_name2 = $names2[0];


    #### Set the relationship
    $result = setRelationship(
      biosequence_set_id1 => $biosequence_set_ids{HuRefseqNP},
      biosequence_name1 => $biosequence_name2,
      biosequence_set_id2 => $biosequence_set_ids{HuIPI},
      biosequence_name2 => $biosequence_name1,
      relationship_type_id => 1,
      evidence_source_id => $load_evidence_source_id,
    );

    $counter++;
    print "$counter..." if ($counter % 100 == 0);



  } # end foreach


  return;

}



###############################################################################
# get_biosequence_set_id
###############################################################################
sub get_biosequence_set_id {
  my %args = @_;
  my $SUB_NAME = 'get_biosequence_set_id';

  #### Decode the argument list
  my $biosequence_set_tag = $args{'biosequence_set_tag'}
   || die("ERROR[$SUB_NAME]: biosequence_set_tag not passed");


  #### Get id for this biosequence_set_tag from database
  my $sql = qq~
    SELECT BSS.biosequence_set_id
      FROM ${DATABASE}biosequence_set BSS
     WHERE BSS.set_tag = '$biosequence_set_tag'
       AND BSS.record_status != 'D'
  ~;
  my @rows = $sbeams->selectOneColumn($sql);
  my $nrows = scalar(@rows);

  #### If exactly one row was fetched, return it
  return($rows[0]) if ($nrows == 1);

  #### If nothing was returned, return 0
  return(0) if ($nrows == 0);

  #### If more than one row was returned, die
  die("ERROR[$SUB_NAME]: Query$sql\nreturned $nrows of data!");

} # end get_biosequence_set_id



###############################################################################
# get_biosequence_id
###############################################################################
sub get_biosequence_id {
  my %args = @_;
  my $SUB_NAME = 'get_biosequence_id';

  #### Decode the argument list
  my $biosequence_set_id = $args{'biosequence_set_id'}
   || die("ERROR[$SUB_NAME]: biosequence_set_id not passed");
  my $biosequence_name = $args{'biosequence_name'}
   || die("ERROR[$SUB_NAME]: biosequence_name not passed");
  my $create_if_not_existing = $args{'create_if_not_existing'}
   || die("ERROR[$SUB_NAME]: create_if_not_existing not passed");


  #### Get id for this biosequence_name from database
  my $sql = qq~
    SELECT BS.biosequence_id
      FROM ${DATABASE}biosequence BS
     WHERE BS.biosequence_name = '$biosequence_name'
       AND BS.biosequence_set_id = '$biosequence_set_id'
  ~;
  my @rows = $sbeams->selectOneColumn($sql);
  my $nrows = scalar(@rows);


  #### If exactly one row was fetched, return it
  return($rows[0]) if ($nrows == 1);


  #### If nothing was returned
  if ($nrows == 0) {

    #### If user wants the record created if it doesn't exist, do it
    if ($create_if_not_existing) {
      my %rowdata = (
        biosequence_set_id => $biosequence_set_id,
        biosequence_name => $biosequence_name,
        biosequence_desc => '',
      );

      my $returned_PK = $sbeams->insert_update_row(
        insert => 1,
        table_name => "${DATABASE}biosequence",
        rowdata_ref => \%rowdata,
        PK => "biosequence_id",
        return_PK => 1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY
      );

      return($returned_PK);

    #### Else just return 0
    } else {
      return 0;
    }

  }


  #### If more than one row was returned, die
  die("ERROR[$SUB_NAME]: Query$sql\nreturned $nrows of data!");


} # end get_biosequence_set_id



###############################################################################
# get_evidence_source_id
###############################################################################
sub get_evidence_source_id {
  my %args = @_;
  my $SUB_NAME = 'get_evidence_source_id';

  #### Decode the argument list
  my $evidence_source_tag = $args{'evidence_source_tag'}
   || die("ERROR[$SUB_NAME]: evidence_source_tag not passed");


  #### Get id for this biosequence_set_tag from database
  my $sql = qq~
    SELECT ES.evidence_source_id
      FROM ${DATABASE}evidence_source ES
     WHERE ES.evidence_source_tag= '$evidence_source_tag'
       AND ES.record_status != 'D'
  ~;
  my @rows = $sbeams->selectOneColumn($sql);
  my $nrows = scalar(@rows);

  #### If exactly one row was fetched, return it
  return($rows[0]) if ($nrows == 1);

  #### If nothing was returned, return 0
  return(0) if ($nrows == 0);

  #### If more than one row was returned, die
  die("ERROR[$SUB_NAME]: Query$sql\nreturned $nrows of data!");

} # end get_evidence_source_id




###############################################################################
# setRelationship
###############################################################################
sub setRelationship {
  my %args = @_;
  my $SUB_NAME = 'setRelationship';


  #### Decode the argument list
  my $biosequence_set_id1 = $args{'biosequence_set_id1'}
   || die "ERROR[$SUB_NAME]: biosequence_set_id1 not passed";
  my $biosequence_name1 = $args{'biosequence_name1'}
   || die "ERROR[$SUB_NAME]: biosequence_name1 not passed";
  my $biosequence_set_id2 = $args{'biosequence_set_id2'}
   || die "ERROR[$SUB_NAME]: biosequence_set_id2 not passed";
  my $biosequence_name2 = $args{'biosequence_name2'}
   || die "ERROR[$SUB_NAME]: biosequence_name2 not passed";

  my $relationship_type_id = $args{'relationship_type_id'}
   || die "ERROR[$SUB_NAME]: relationship_type_id not passed";
  my $evidence_source_id = $args{'evidence_source_id'}
   || die "ERROR[$SUB_NAME]: evidence_source_id not passed";


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Get the biosequence_ids
  my $biosequence_id1 = get_biosequence_id(
    biosequence_set_id => $biosequence_set_id1,
    biosequence_name => $biosequence_name1,
    create_if_not_existing => 1,
  );

  my $biosequence_id2 = get_biosequence_id(
    biosequence_set_id => $biosequence_set_id2,
    biosequence_name => $biosequence_name2,
    create_if_not_existing => 1,
  );


  #### See if there's already this very relationship
  $sql = qq~
    SELECT R.relationship_id,E.evidence_id,E.evidence_source_id
      FROM ${DATABASE}relationship R
     INNER JOIN ${DATABASE}evidence E
           ON ( R.relationship_id = E.relationship_id )
     WHERE R.biosequence1_id = '$biosequence_id1'
       AND R.biosequence2_id = '$biosequence_id2'
       AND R.relationship_type_id = '$relationship_type_id'
  ~;

  my @relationships = $sbeams->selectSeveralColumns($sql);
  my $n_relationships = scalar(@relationships);


  #### If there is already such a relationship
  if ($n_relationships > 0) {

    #### If there's already this relationship, see if it's from the
    #### current evidence_source
    my $existing_record = '';
    foreach my $row (@relationships) {
      if ($row->[2] == $evidence_source_id) {
        if ($existing_record) {
          die("ERROR[$SUB_NAME]: More than one record with the same ".
              "evidence_source_id from $sql");
        } else {
	  $existing_record = $row
        }
      }
    }

    #### If it is from the current evidence_source, then touch it
    if ($existing_record) {
      print "This relationship exists already. Touch it\n" if ($VERBOSE);
      return;
    }


    #### There's already a relationship, but not from this evidence_source
    #### so add a new line of evidence
    addEvidence(
      relationship_id => $relationships[0]->[0],
      evidence_source_id => $evidence_source_id,
    );


  #### Otherwise this is a new relationship
  } else {

    #### If this is a "is the canonical name for" relationship,
    #### special rules apply
    if ($relationship_type_id == 1) {

      my $canonical_biosequence_id = get_canonical_biosequence_id(
        biosequence_id => $biosequence_id1,
      );

      #### If it is itself, then we're all set
      if ($canonical_biosequence_id &&
          $canonical_biosequence_id == $biosequence_id1) {
      }

      #### If not, then the situation is complicated and fixing needs to
      #### be done.  FIX ME
      if ($canonical_biosequence_id &&
          $canonical_biosequence_id != $biosequence_id1 &&
          !$TESTONLY) {
        print("OH NO: The canonical name I want to have already has a ".
            "different canonical name.  This condition not yet handled.");
        my $sql = "SELECT biosequence_id,biosequence_name ".
          "FROM $TBBL_BIOSEQUENCE WHERE biosequence_id IN ( ".
          "$biosequence_id1,$canonical_biosequence_id )";
        my %biosequence_names = $sbeams->selectTwoColumnHash($sql);
        print "I wanted to say that '$biosequence_name1' is the canonical ".
          "name for '$biosequence_name2', but I find that '".
          "$biosequence_names{$biosequence_id1}' already has a canonical ".
          "name of' $biosequence_names{$canonical_biosequence_id}'\n";

        exit;
      }

      #### If it has no canonical name, then make itself its canonical name
      unless ($canonical_biosequence_id) {
        $result = addRelationship(
          biosequence_id1 => $biosequence_id1,
          biosequence_id2 => $biosequence_id1,
          relationship_type_id => 1,
          evidence_source_id => $evidence_source_id,
        );
      }

    }


    #### Add the relationship and evidence
    my $relationship_id = addRelationship(
      biosequence_id1 => $biosequence_id1,
      biosequence_id2 => $biosequence_id2,
      relationship_type_id => 1,
    );

    my $evidence_id = addEvidence(
      relationship_id => $relationship_id,
      evidence_source_id => $evidence_source_id,
    );


  }


} # end setRelationship



###############################################################################
# addEvidence
###############################################################################
sub addEvidence {
  my %args = @_;
  my $SUB_NAME = 'addEvidence';

  #### Decode the argument list
  my $relationship_id = $args{'relationship_id'}
   || die "ERROR[$SUB_NAME]: relationship_type_id not passed";
  my $evidence_source_id = $args{'evidence_source_id'}
   || die "ERROR[$SUB_NAME]: evidence_source_id not passed";


  #### Define the row data to go in
  my %rowdata = (
    relationship_id => $relationship_id,
    evidence_source_id => $evidence_source_id,
  );

  my $returned_PK = $sbeams->updateOrInsertRow(
    insert => 1,
    table_name => "${DATABASE}evidence",
    rowdata_ref => \%rowdata,
    PK => "evidence_id",
    return_PK => 1,
    add_audit_parameters => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY
  );

  return($returned_PK);


} # end addEvidence



###############################################################################
# addRelationship
###############################################################################
sub addRelationship {
  my %args = @_;
  my $SUB_NAME = 'addRelationship';

  #### Decode the argument list
  my $biosequence_id1 = $args{'biosequence_id1'}
   || die "ERROR[$SUB_NAME]: biosequence_id1 not passed";
  my $biosequence_id2 = $args{'biosequence_id2'}
   || die "ERROR[$SUB_NAME]: biosequence_id2 not passed";
  my $relationship_type_id = $args{'relationship_type_id'}
   || die "ERROR[$SUB_NAME]: relationship_type_id not passed";


  #### Define the row data to go in
  my %rowdata = (
    biosequence1_id => $biosequence_id1,
    biosequence2_id => $biosequence_id2,
    relationship_type_id => $relationship_type_id,
  );

  my $returned_PK = $sbeams->updateOrInsertRow(
    insert => 1,
    table_name => "${DATABASE}relationship",
    rowdata_ref => \%rowdata,
    PK => "relationship_id",
    return_PK => 1,
    add_audit_parameters => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY
  );

  return($returned_PK);


} # end addRelationship



###############################################################################
# get_canonical_biosequence_id
###############################################################################
sub get_canonical_biosequence_id {
  my %args = @_;
  my $SUB_NAME = 'get_canonical_biosequence_id';

  #### Decode the argument list
  my $biosequence_id = $args{'biosequence_id'}
   || die("ERROR[$SUB_NAME]: biosequence_id not passed");


  #### Get id for this biosequence_name from database
  my $sql = qq~
    SELECT CBS.biosequence_id
      FROM ${DATABASE}biosequence BS
     INNER JOIN ${DATABASE}relationship R
           ON ( BS.biosequence_id = R.biosequence2_id )
     INNER JOIN ${DATABASE}biosequence CBS
           ON ( R.biosequence1_id = CBS.biosequence_id )
     WHERE BS.biosequence_id = '$biosequence_id'
       AND R.relationship_type_id = 1
  ~;
  #print "$sql\n";
  my @rows = $sbeams->selectOneColumn($sql);
  my $nrows = scalar(@rows);


  #### If exactly one row was fetched, return it
  return($rows[0]) if ($nrows == 1);

  #### If nothing was returned, return 0
  return(0) if ($nrows == 0);

  #### If more than one row was returned, die
  die("ERROR[$SUB_NAME]: Query$sql\nreturned $nrows of data!");


} # end get_biosequence_set_id



