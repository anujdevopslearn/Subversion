#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_terms.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script bulk loads ontology terms from a special
#               format tsv file, usually created in Excel or similar
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

use vars qw (%ontology_ids %term_type_ids %relationship_type_ids);


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::Ontology;
use SBEAMS::Ontology::Settings;
use SBEAMS::Ontology::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Ontology;
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
  --source_file       Name of the source file from which data are loaded
  --bootstrap         Used only for the very first initial load.  Needed
                      because OntologyOntology is circularly referential.
                      After running with bootstrap run again without to
                      fix circular references

 e.g.:  $PROG_NAME --source_file inputfile.txt

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "source_file:s","bootstrap",
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
    work_group=>'Ontology_admin',
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
  my $source_file = $OPTIONS{"source_file"} || '';
  my $bootstrap = $OPTIONS{"bootstrap"} || '';


  #### Verify required parameters
  unless ($source_file) {
    print "ERROR: You must specify a source_file\n\n";
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


  #### Open the source file
  unless (open(INFILE,"$source_file")) {
    print "ERROR: Unable to open for reading source_file '$source_file'\n\n";
    return;
  }


  #### Read in the first line to get the column names
  my $line = <INFILE>;
  $line =~ s/[\r\n]//g;
  my @column_names = split("\t",$line);
  my $n_columns = @column_names;


  #### Verify that the number of column titles is correct
  if ($n_columns != 8) {
    print "ERROR: Expected to file a file with 8 columns but did not.  Check ".
      "that the specified file is really of correct format.";
    return;
  }

  #### Verify that the column titles are as expected
  my @ref_columns = ('source_ontology','subject_term_type','subject_term_name',
    'relationship_type','predicate_term_name','object_term_type',
    'object_term_name','object_term_definition');
  for (my $i=0; $i<$n_columns; $i++) {
    if ($column_names[$i] =~ /^\"(.*)\"$/) {
      $column_names[$i] = $1;
    }
    if ($ref_columns[$i] ne $column_names[$i]) {
      print "ERROR: File header verification failed.\n";
      print " Expected column $i to be '$ref_columns[$i]' but it appears ".
	"to be '$column_names[$i]'.  This is unexpected and we cannot ".
          "continue.  Please resolve and retry.\n";
      return;
    }
  }


  #### Build the index of column names and indices
  my %idx;
  my $i = 0;
  foreach my $column_name ( @column_names ) {
    print "$i\t'$column_name'\n";
    $idx{$column_name} = $i;
    $i++;
  }


  #### Loop over all lines and process them
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;

    #### Skip blank lines
    next if ($line =~ /^\s*$/);

    #### Extract data
    my @columns = split(/\t/,$line);
    my ($source_ontology,$subject_term_type,$subject_term_name,
	$relationship_type,$predicate_term_name,$object_term_type,
	$object_term_name,$object_term_definition) = @columns;


    #### Undocumented mechanism for exiting early
    if ($source_ontology =~ /^stop/i) {
      print "STOPPED EARLY by directive in file: '$source_ontology'\n";
      last;
    }


    #### Add the subject term if not already there
    my $subject_term_id = addTerm(
      ontology_tag => $source_ontology,
      term_name => $subject_term_name,
      term_type => $subject_term_type,
      bootstrap => $bootstrap,
    );
    unless ($subject_term_id > 0) {
      print "ERROR: Unable to create term '$subject_term_name'\n";
      return;
    }


    #### Add the object term if not already there
    my $object_term_id = addTerm(
      ontology_tag => $source_ontology,
      term_name => $object_term_name,
      term_type => $object_term_type,
      term_definition => $object_term_definition,
      bootstrap => $bootstrap,
    );
    unless ($object_term_id > 0) {
      print "ERROR: Unable to create term '$object_term_name'\n";
      return;
    }


    #### If there's a relationship defined
    if ($relationship_type) {

      #### Add the relationship if not already there
      my $relationship_id = addRelationship(
        ontology_tag => $source_ontology,
        subject_term_id => $subject_term_id,
        object_term_id => $object_term_id,
        relationship_type => $relationship_type,
        bootstrap => $bootstrap,
      );
      unless ($relationship_id > 0) {
        print "ERROR: Unable to create relationship $subject_term_name ".
	  "$relationship_type $object_term_name\n";
        return;
      }

    #### Else if no relationship
    } else {

      #### If this is a Root record, that's okay
      if ($subject_term_type eq 'Root') {
	# OK
      } else {
	print "ERROR: No relationship defined where there should be for ".
	  "$subject_term_name\n";
      }

    }

    print ".";

  }

  print "\n\n";

  return;

}



###############################################################################
# addTerm
###############################################################################
sub addTerm {
  my %args = @_;

  my $ontology_tag = $args{'ontology_tag'} || die "ontology_tag not passed";
  my $term_name = $args{'term_name'} || die "term_name not passed";
  my $term_type = $args{'term_type'} || die "term_type not passed";
  my $term_definition = $args{'term_definition'};
  my $bootstrap = $args{'bootstrap'};


  #### Clean up the term definition
  if (defined($term_definition)) {
    if ($term_definition =~ /^\"(.*)\"$/) {
      $term_definition = $1;
    }
  }


  #### Load ontology_ids if not yet available
  unless (%ontology_ids) {
    my $sql = qq~
      SELECT ontology_tag,ontology_id
        FROM $TBON_ONTOLOGY
       WHERE record_status != 'D'
    ~;
    %ontology_ids = $sbeams->selectTwoColumnHash($sql);
  }


  #### Get the ontology_id
  my $ontology_id = $ontology_ids{$ontology_tag};
  unless ($ontology_id) {
    print "ERROR: Unrecognized source_ontology tag '$ontology_tag'\n";
    return -1;
  }


  #### Load term_type_ids if not yet available
  unless (%term_type_ids) {
    my $sql;

    if ($bootstrap) {
      $sql = qq~
        SELECT CT.term_name,CT.ontology_term_id
          FROM $TBON_ONTOLOGY_TERM CT
         WHERE CT.ontology_id = 1
           AND CT.record_status != 'D'
      ~;
    } else {
      $sql = qq~
        SELECT CT.term_name,CT.ontology_term_id
          FROM $TBON_ONTOLOGY_TERM PT
         INNER JOIN $TBON_ONTOLOGY_TERM_RELATIONSHIP R
               ON ( PT.ontology_term_id = R.subject_term_id )
         INNER JOIN $TBON_ONTOLOGY_TERM CT
               ON ( R.object_term_id = CT.ontology_term_id)
         WHERE PT.ontology_id = 1
           AND PT.term_name = 'TermType'
           AND CT.record_status != 'D'
      ~;
    }
    %term_type_ids = $sbeams->selectTwoColumnHash($sql);

 }


  #### Get the term_type_id
  my $term_type_id = $term_type_ids{$term_type};
  unless ($term_type_id) {
    if ($bootstrap) {
      $term_type_id = 1;
    } else {
      print "ERROR: Unrecognized term_type '$term_type'\n";
      return -1;
    }
  }


  #### Check to see if this term is already in the database
  my $sql = qq~
    SELECT ontology_term_id
      FROM $TBON_ONTOLOGY_TERM T
     WHERE term_name = '$term_name'
       AND ( term_type_term_id = '$term_type_id' OR term_type_term_id = 1 )
       AND ontology_id = $ontology_id
  ~;
  my (@ontology_term_ids) = $sbeams->selectOneColumn($sql);


  #### Define some things
  my $insert = 0;
  my $update = 0;
  my %rowdata;


  #### If not found, we should INSERT
  if (scalar(@ontology_term_ids) == 0) {
    $insert = 1;
    %rowdata = (ontology_id => $ontology_id,
		term_type_term_id => $term_type_id,
		term_name => $term_name,
		);
    if (defined($term_definition)) {
      $rowdata{term_definition} = $term_definition;
    }

  #### If found, we should UPDATE
  #### We should really probably assess the current state and compare
  #### and deal with deleted records
  } elsif (scalar(@ontology_term_ids) == 1) {
    $update = 1;
    %rowdata = (ontology_id => $ontology_id,
		term_type_term_id => $term_type_id,
		term_name => $term_name,
		);
    if (defined($term_definition)) {
      $rowdata{term_definition} = $term_definition;
    }

  #### Else there are too many records
  } else {
    die "ERROR: Too many rows returned from $sql";
  }

  #### INSERT or UPDATE the record
  my $result = $sbeams->updateOrInsertRow(
    insert=>$insert,
    update=>$update,
    table_name=>$TBON_ONTOLOGY_TERM,
    rowdata_ref=>\%rowdata,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
    PK=>'ontology_term_id',
    PK_value=>$ontology_term_ids[0],
    return_PK => 1,
    add_audit_parameters=>1,
  );

  return($result);

} # end addTerm



###############################################################################
# addRelationship
###############################################################################
sub addRelationship {
  my %args = @_;

  my $ontology_tag = $args{'ontology_tag'} || die "ontology_tag not passed";
  my $subject_term_id = $args{'subject_term_id'}
    || die "subject_term_id not passed";
  my $object_term_id = $args{'object_term_id'}
    || die "object_term_id not passed";
  my $relationship_type = $args{'relationship_type'}
    || die "relationship_type not passed";
  my $bootstrap = $args{'bootstrap'};


  #### Get the ontology_id
  my $ontology_id = $ontology_ids{$ontology_tag};
  unless ($ontology_id) {
    print "ERROR: Unrecognized source_ontology tag '$ontology_tag'\n";
    return -1;
  }


  #### Load relationship_type_ids if not yet available
  unless (%relationship_type_ids) {
    my $sql;

    if ($bootstrap) {
      $sql = qq~
        SELECT CT.term_name,CT.ontology_term_id
          FROM $TBON_ONTOLOGY_TERM CT
         WHERE CT.ontology_id = 1
           AND CT.record_status != 'D'
      ~;
    } else {
      $sql = qq~
        SELECT CT.term_name,CT.ontology_term_id
          FROM $TBON_ONTOLOGY_TERM PT
         INNER JOIN $TBON_ONTOLOGY_TERM_RELATIONSHIP R
               ON ( PT.ontology_term_id = R.subject_term_id )
         INNER JOIN $TBON_ONTOLOGY_TERM CT
               ON ( R.object_term_id = CT.ontology_term_id)
         WHERE PT.ontology_id = 1
           AND PT.term_name = 'RelationshipType'
           AND CT.record_status != 'D'
      ~;
    }
    %relationship_type_ids = $sbeams->selectTwoColumnHash($sql);

 }


  #### Get the relationship_type_id
  my $relationship_type_id = $relationship_type_ids{$relationship_type};
  unless ($relationship_type_id) {
    if ($bootstrap) {
      $relationship_type_id = 1;
    } else {
      print "ERROR: Unrecognized term_type '$relationship_type'\n";
      return -1;
    }
  }


  #### Check to see if a relationship is already in the database
  my $sql = qq~
    SELECT ontology_term_relationship_id
      FROM $TBON_ONTOLOGY_TERM_RELATIONSHIP R
     WHERE subject_term_id = '$subject_term_id'
       AND object_term_id = '$object_term_id'
  ~;
  my (@ontology_relationship_ids) = $sbeams->selectOneColumn($sql);


  #### Define some things
  my $insert = 0;
  my $update = 0;
  my %rowdata;


  #### If not found, we should INSERT
  if (scalar(@ontology_relationship_ids) == 0) {
    $insert = 1;
    %rowdata = (ontology_id => $ontology_id,
		subject_term_id => $subject_term_id,
		object_term_id => $object_term_id,
		relationship_type_term_id => $relationship_type_id,
		);

  #### If found, we should UPDATE
  #### We should really probably assess the current state and compare
  #### and deal with deleted records
  } elsif (scalar(@ontology_relationship_ids) == 1) {
    $update = 1;
    %rowdata = (subject_term_id => $subject_term_id,
		object_term_id => $object_term_id,
		relationship_type_term_id => $relationship_type_id,
		);

  #### Else there are too many records
  } else {
    die "ERROR: Too many rows returned from $sql";
  }

  #### INSERT or UPDATE the record
  my $result = $sbeams->updateOrInsertRow(
    insert=>$insert,
    update=>$update,
    table_name=>$TBON_ONTOLOGY_TERM_RELATIONSHIP,
    rowdata_ref=>\%rowdata,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
    PK=>'ontology_term_relationship_id',
    PK_value=>$ontology_relationship_ids[0],
    return_PK => 1,
    add_audit_parameters=>1,
  );

  return($result);


} # end addRelationship


