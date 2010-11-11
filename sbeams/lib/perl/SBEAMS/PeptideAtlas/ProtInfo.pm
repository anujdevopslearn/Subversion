package SBEAMS::PeptideAtlas::ProtInfo;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::ProtInfo
# Author      : Terry Farrah <tfarrah@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::ProtInfo

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::ProtInfo

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
things related to PeptideAtlas protein identifications.

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::AtlasBuild;


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);
our @EXPORT = qw(
 get_preferred_protid_from_list
 read_protid_preferences
);


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $VERBOSE = 0;
    $TESTONLY = 0;
    return($self);
} # end new


###############################################################################
# setSBEAMS: Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
} # end setSBEAMS



###############################################################################
# getSBEAMS: Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS



###############################################################################
# setTESTONLY: Set the current test mode
###############################################################################
sub setTESTONLY {
    my $self = shift;
    $TESTONLY = shift;
    return($TESTONLY);
} # end setTESTONLY



###############################################################################
# setVERBOSE: Set the verbosity level
###############################################################################
sub setVERBOSE {
    my $self = shift;
    $VERBOSE = shift;
    return($VERBOSE);
} # end setVERBOSE



###############################################################################
# loadBuildProtInfo -- Loads all protein identification info for build
###############################################################################
sub loadBuildProtInfo {
  my $METHOD = 'loadBuildProtInfo';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $atlas_build_directory = $args{atlas_build_directory}
    or die("ERROR[$METHOD]: Parameter atlas_build_directory not passed");


  #### Find and open files.
  my $ident_file = "$atlas_build_directory/".
    "PeptideAtlasInput.PAprotIdentlist";
  my $relation_file = "$atlas_build_directory/".
    "PeptideAtlasInput.PAprotRelationships";

  unless (open(IDENTFILE,$ident_file)) {
    print "ERROR: Unable to open for read file '$ident_file'\n";
    return;
  }
  unless (open(RELFILE,$relation_file)) {
    print "ERROR: Unable to open for read file '$relation_file'\n";
    return;
  }


  #### Loop through all protein identifications and load

  my $unmapped = 0;
  my $unmapped_represented_by = 0;
  my $unmapped_subsumed_by = 0;
  my $loaded = 0;
  my $already_in_db = 0;
  my $nan_count = 0;

  # Input is PA.protIdentlist file
  # Process one line at a time
  my $nfields = 13;
  my $line = <IDENTFILE>;  #throw away header line
  while ($line = <IDENTFILE>) {
    chomp ($line);
    my ($protein_group_number,
	$biosequence_name,
	$probability,
	$confidence,
        $n_observations,
        $n_distinct_peptides,
	$level_name,
	$represented_by_biosequence_name,
	$subsumed_by_biosequence_name,
        $estimated_ng_per_ml,
        $abundance_uncertainty,
        $is_covering,
        $seq_unique_prots_in_group) = split(",", $line, $nfields);
#    if (! $subsumed_by_biosequence_name) {
#      $subsumed_by_biosequence_name = '';
#    }
    if ($estimated_ng_per_ml eq '') {
      $estimated_ng_per_ml = 'NULL';
    }
#    if (! $abundance_uncertainty) {
#      $abundance_uncertainty = '';
#    }


    # I don't know what to do with nan. Let's set it to zero.
    if ($probability eq "nan") {
      $nan_count++;
      $probability = "0.0";
    }
    if ($confidence eq "nan") {
      $nan_count++;
      $confidence = "0.0";
    }

    # skip UNMAPPED proteins.
    if ($biosequence_name =~ /UNMAPPED/) {
      $unmapped++;
      next;
    }
    if ($represented_by_biosequence_name =~ /UNMAPPED/) {
      $unmapped_represented_by++;
      next;
    }
    if ($subsumed_by_biosequence_name =~ /UNMAPPED/) {
      $unmapped_subsumed_by++;
      next;
    }

    my $inserted = $self->insertProteinIdentification(
       atlas_build_id => $atlas_build_id,
       biosequence_name => $biosequence_name,
       protein_group_number => $protein_group_number,
       level_name => $level_name,
       represented_by_biosequence_name => $represented_by_biosequence_name,
       probability => $probability,
       confidence => $confidence,
       n_observations => $n_observations,
       n_distinct_peptides => $n_distinct_peptides,
       subsumed_by_biosequence_name => $subsumed_by_biosequence_name,
       estimated_ng_per_ml => $estimated_ng_per_ml,
       abundance_uncertainty => $abundance_uncertainty,
       is_covering => $is_covering,
       seq_unique_prots_in_group => $seq_unique_prots_in_group,
    );

    if ($inserted) {
      $loaded++;
    } else {
      $already_in_db++;
    }
  }

  if ( 1 || $VERBOSE ) {
    print "$loaded entries loaded into protein_identification table.\n";
    print "$already_in_db protIDs were already in table so not loaded.\n";
    print "$unmapped UNMAPPED entries ignored.\n";
    print "$unmapped_represented_by entries with UNMAPPED represented_by".
	   " identifiers ignored.\n";
    print "$unmapped_subsumed_by entries with UNMAPPED subsumed_by".
	   " identifiers ignored.\n";
    if ($nan_count) {
      print "$nan_count probability/confidence values of nan set to 0.0.\n";
    }
  }

  #### Loop through all protein relationships and load

  $unmapped = 0;
  my $unmapped_reference = 0;
  $loaded = 0;
  $already_in_db = 0;

  # Input is PA.protRelationships file
  # Process one line at a time
  $line = <RELFILE>;  #throw away header line
  while ($line = <RELFILE>) {
    chomp ($line);
    my ($protein_group_number,
        $reference_biosequence_name,
	$related_biosequence_name,
	$relationship_name,
	) = split(",", $line);

    # skip UNMAPPED proteins.
    if ($related_biosequence_name =~ /UNMAPPED/) {
      $unmapped++;
      next;
    }

    my $inserted = $self->insertBiosequenceRelationship(
       atlas_build_id => $atlas_build_id,
       protein_group_number => $protein_group_number,
       reference_biosequence_name => $reference_biosequence_name,
       related_biosequence_name => $related_biosequence_name,
       relationship_name => $relationship_name,
    );


    if ($inserted) {
      $loaded++;
    } else {
      $already_in_db++;
    }
  }

  if ( 1 || $VERBOSE ) {
    print "$loaded entries loaded into biosequence_relationship table.\n";
    print "$already_in_db relationships were already in table so not loaded.\n";
    print "$unmapped UNMAPPED entries ignored.\n";
    print "$unmapped_reference entries with UNMAPPED reference".
	   " identifiers ignored.\n";
  }

} # end loadBuildProtInfo



###############################################################################
# insertProteinIdentification --
###############################################################################
sub insertProteinIdentification {
  my $METHOD = 'insertProteinIdentification';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");
  my $biosequence_name = $args{biosequence_name}
    or die("ERROR[$METHOD]: Parameter biosequence_name not passed");
  my $protein_group_number = $args{protein_group_number}
    or die("ERROR[$METHOD]: Parameter protein_group_number not passed");
  my $level_name = $args{level_name}
    or die("ERROR[$METHOD]: Parameter level_name not passed");
  my $represented_by_biosequence_name =
          $args{represented_by_biosequence_name}
    or die("ERROR[$METHOD]: Parameter represented_by_biosequence_name ".
          "not passed");
  my $probability = $args{probability};
  my $confidence = $args{confidence};
  my $n_observations = $args{n_observations};
  my $n_distinct_peptides = $args{n_distinct_peptides};
  my $subsumed_by_biosequence_name = $args{subsumed_by_biosequence_name};
  my $estimated_ng_per_ml = $args{estimated_ng_per_ml};
  my $abundance_uncertainty = $args{abundance_uncertainty};
  my $is_covering = $args{is_covering};
  my $seq_unique_prots_in_group = $args{seq_unique_prots_in_group};

  our $counter;

  #### Get the biosequence_ids
  my $biosequence_id = $self->get_biosequence_id(
    biosequence_name => $biosequence_name,
    atlas_build_id => $atlas_build_id,
  );
  my $represented_by_biosequence_id = $self->get_biosequence_id(
    biosequence_name => $represented_by_biosequence_name,
    atlas_build_id => $atlas_build_id,
  );
  my $subsumed_by_biosequence_id = '';
  if ($subsumed_by_biosequence_name) {
    $subsumed_by_biosequence_id = $self->get_biosequence_id(
      biosequence_name => $subsumed_by_biosequence_name,
      atlas_build_id => $atlas_build_id,
    );
  }

  #### Get the presence_level_id
  my $presence_level_id = $self->get_presence_level_id(
    level_name => $level_name,
  );

  #### Check to see if this protein_identification is in the database
  my $protein_identification_id = $self->get_protein_identification_id(
    biosequence_id => $biosequence_id,
    atlas_build_id => $atlas_build_id,
  );


  #### If not, INSERT it
  if ($protein_identification_id) {
    if ($VERBOSE) {
      print STDERR "WARNING: Identification info for $biosequence_name".
                 " ($biosequence_id) already in database\n";
    }
    return ('');
  } else {
    $protein_identification_id = $self->insertProteinIdentificationRecord(
      biosequence_id => $biosequence_id,
      atlas_build_id => $atlas_build_id,
      protein_group_number => $protein_group_number,
      presence_level_id => $presence_level_id,
      represented_by_biosequence_id => $represented_by_biosequence_id,
      probability => $probability,
      confidence => $confidence,
      n_observations => $n_observations,
      n_distinct_peptides => $n_distinct_peptides,
      subsumed_by_biosequence_id => $subsumed_by_biosequence_id,
      estimated_ng_per_ml => $estimated_ng_per_ml,
      abundance_uncertainty => $abundance_uncertainty,
      is_covering => $is_covering,
      seq_unique_prots_in_group => $seq_unique_prots_in_group,
    );
    return ($protein_identification_id);
  }


} # end insertProteinIdentification



###############################################################################
# insertProteinIdentificationRecord --
###############################################################################
sub insertProteinIdentificationRecord {
  my $METHOD = 'insertProteinIdentificationRecord';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $biosequence_id = $args{biosequence_id}
    or die("ERROR[$METHOD]:Parameter biosequence_id not passed");
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]:Parameter atlas_build_id not passed");
  my $protein_group_number = $args{protein_group_number}
    or die("ERROR[$METHOD]:Parameter protein_group_number not passed");
  my $presence_level_id = $args{presence_level_id}
    or die("ERROR[$METHOD]:Parameter presence_level_id not passed");
  my $represented_by_biosequence_id = $args{represented_by_biosequence_id}
    or die("ERROR[$METHOD]:Parameter represented_by_biosequence_id not passed");
  my $probability = $args{probability};
  my $confidence = $args{confidence};
  my $n_observations = $args{n_observations};
  my $n_distinct_peptides = $args{n_distinct_peptides};
  my $subsumed_by_biosequence_id = $args{subsumed_by_biosequence_id};
  my $estimated_ng_per_ml = $args{estimated_ng_per_ml};
  my $abundance_uncertainty = $args{abundance_uncertainty};
  my $is_covering = $args{is_covering};
  my $seq_unique_prots_in_group = $args{seq_unique_prots_in_group};

  #### Define the attributes to insert
  my $rowdata = {
     biosequence_id => $biosequence_id,
     atlas_build_id => $atlas_build_id,
     protein_group_number => $protein_group_number,
     presence_level_id => $presence_level_id,
     represented_by_biosequence_id => $represented_by_biosequence_id,
     probability => $probability,
     confidence => $confidence,
     n_observations => $n_observations,
     n_distinct_peptides => $n_distinct_peptides,
     subsumed_by_biosequence_id => $subsumed_by_biosequence_id,
     estimated_ng_per_ml => $estimated_ng_per_ml,
     abundance_uncertainty => $abundance_uncertainty,
     is_covering => $is_covering,
     seq_unique_prots_in_group => $seq_unique_prots_in_group,
  };

  #### Insert protein identification record
  my $protein_identification_id = $sbeams->updateOrInsertRow(
    insert => 1,
    table_name => $TBAT_PROTEIN_IDENTIFICATION,
    rowdata_ref => $rowdata,
    PK => 'protein_identification_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  return($protein_identification_id);

} # end insertProteinIdentificationRecord


###############################################################################
# insertBiosequenceRelationship --
###############################################################################
sub insertBiosequenceRelationship {
  my $METHOD = 'insertBiosequenceRelationship';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");
  my $protein_group_number = $args{protein_group_number}
    or die("ERROR[$METHOD]: Parameter protein_group_number not passed");
  my $reference_biosequence_name = $args{reference_biosequence_name}
    or die("ERROR[$METHOD]: Parameter reference_biosequence_name not passed");
  my $related_biosequence_name = $args{related_biosequence_name}
    or die("ERROR[$METHOD]: Parameter related_biosequence_name not passed");
  my $relationship_name = $args{relationship_name}
    or die("ERROR[$METHOD]: Parameter relationship_name not passed");

  our $counter;

  #### Get the biosequence_ids
  my $reference_biosequence_id = $self->get_biosequence_id(
    biosequence_name => $reference_biosequence_name,
    atlas_build_id => $atlas_build_id,
  );
  my $related_biosequence_id = $self->get_biosequence_id(
    biosequence_name => $related_biosequence_name,
    atlas_build_id => $atlas_build_id,
  );

  #### Get the relationship_type_id
  my $relationship_type_id = $self->get_biosequence_relationship_type_id(
    relationship_name => $relationship_name,
  );

  #### Check to see if this biosequence_relationship is in the database
  my $biosequence_relationship_id = $self->get_biosequence_relationship_id(
    atlas_build_id => $atlas_build_id,
    reference_biosequence_id => $reference_biosequence_id,
    related_biosequence_id => $related_biosequence_id,
  );

  #### If not, INSERT it
  if ($biosequence_relationship_id) {
    if ($VERBOSE) {
      print STDERR "WARNING: Relationship between $reference_biosequence_name".
                 "and $related_biosequence_name already in database\n";
    }
    return ('');
  } else {
    $biosequence_relationship_id = $self->insertBiosequenceRelationshipRecord(
      atlas_build_id => $atlas_build_id,
      protein_group_number => $protein_group_number,
      reference_biosequence_id => $reference_biosequence_id,
      related_biosequence_id => $related_biosequence_id,
      relationship_type_id => $relationship_type_id,
    );
    return ($biosequence_relationship_id);
  }


} # end insertBiosequenceRelationship



###############################################################################
# insertBiosequenceRelationshipRecord --
###############################################################################
sub insertBiosequenceRelationshipRecord {
  my $METHOD = 'insertBiosequenceRelationshipRecord';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");
  my $protein_group_number = $args{protein_group_number}
    or die("ERROR[$METHOD]: Parameter protein_group_number not passed");
  my $reference_biosequence_id = $args{reference_biosequence_id}
    or die("ERROR[$METHOD]: Parameter reference_biosequence_id not passed");
  my $related_biosequence_id = $args{related_biosequence_id}
    or die("ERROR[$METHOD]:Parameter related_biosequence_id not passed");
  my $relationship_type_id = $args{relationship_type_id}
    or die("ERROR[$METHOD]:Parameter relationship_type_id not passed");


  #### Define the attributes to insert
  my $rowdata = {
     atlas_build_id => $atlas_build_id,
     protein_group_number => $protein_group_number,
     reference_biosequence_id => $reference_biosequence_id,
     related_biosequence_id => $related_biosequence_id,
     relationship_type_id => $relationship_type_id,
  };

  #### Insert protein identification record
  my $biosequence_relationship_id = $sbeams->updateOrInsertRow(
    insert => 1,
    table_name => $TBAT_BIOSEQUENCE_RELATIONSHIP,
    rowdata_ref => $rowdata,
    PK => 'biosequence_relationship_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  return($biosequence_relationship_id);

} # end insertBiosequenceRelationshipRecord


###############################################################################
# get_biosequence_id --
###############################################################################
sub get_biosequence_id {
  my $METHOD = 'get_biosequence_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $biosequence_name = $args{biosequence_name}
    or die("ERROR[$METHOD]: Parameter biosequence_name not passed");
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $query = qq~
	SELECT BS.biosequence_id
	FROM $TBAT_BIOSEQUENCE BS, $TBAT_ATLAS_BUILD AB
	WHERE
	AB.atlas_build_id = $atlas_build_id AND
	AB.biosequence_set_id = BS.biosequence_set_id AND
	BS.biosequence_name = '$biosequence_name'
  ~;
  my ($biosequence_id) = $sbeams->selectOneColumn($query) or
       die "\nERROR: Unable to find the biosequence_id" .
       " with $query\n\n";

  return $biosequence_id;

} # end get_biosequence_id



###############################################################################
# get_protein_identification_id --
###############################################################################
sub get_protein_identification_id {
  my $METHOD = 'get_protein_identification_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $biosequence_id = $args{biosequence_id};
  my $biosequence_name;
  my $query;
  if (! $biosequence_id ) {
    $biosequence_name = $args{biosequence_name}
      or die("ERROR[$METHOD]: Neither parameter biosequence_id nor biosequence_name passed");
  }
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  #### Lookup and return protein_identification_id
  if ( $biosequence_id ) {
    $query = qq~
	SELECT protein_identification_id
	FROM $TBAT_PROTEIN_IDENTIFICATION
	WHERE
	atlas_build_id = $atlas_build_id AND
	biosequence_id = '$biosequence_id'
    ~;
  } else {
    $query = qq~
	SELECT PID.protein_identification_id
	FROM $TBAT_PROTEIN_IDENTIFICATION PID,
	     $TBAT_BIOSEQUENCE BS
	WHERE
	PID.atlas_build_id = $atlas_build_id AND
        PID.biosequence_id = BS.biosequence_id AND
	BS.biosequence_name = '$biosequence_name'
    ~;
  }
  my ($protein_identification_id) = $sbeams->selectOneColumn($query);

  return $protein_identification_id;

} # end get_protein_identification_id


###############################################################################
# get_presence_level_id --
###############################################################################
sub get_presence_level_id {
  my $METHOD = 'get_presence_level_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $level_name = $args{level_name}
    or die("ERROR[$METHOD]: Parameter level_name not passed");

  my $query = qq~
	SELECT protein_presence_level_id
	FROM $TBAT_PROTEIN_PRESENCE_LEVEL
	WHERE level_name = '$level_name'
  ~;
  my ($presence_level_id) = $sbeams->selectOneColumn($query) or
       die "\nERROR: Unable to find the presence_level_id" .
       " with $query\n\n";

  return $presence_level_id;

} # end get_presence_level_id


###############################################################################
# get_biosequence_relationship_type_id --
###############################################################################
sub get_biosequence_relationship_type_id {
  my $METHOD = 'get_biosequence_relationship_type_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $relationship_name = $args{relationship_name}
    or die("ERROR[$METHOD]: Parameter relationship_name not passed");

  my $query = qq~
	SELECT biosequence_relationship_type_id
	FROM $TBAT_BIOSEQUENCE_RELATIONSHIP_TYPE
	WHERE relationship_name = '$relationship_name'
  ~;
  my ($biosequence_relationship_type_id) = $sbeams->selectOneColumn($query) or
       die "\nERROR: Unable to find the biosequence_relationship_type_id" .
       " with $query\n\n";

  return $biosequence_relationship_type_id;

} # end get_biosequence_relationship_type_id




###############################################################################
# get_biosequence_relationship_id  --
###############################################################################
sub get_biosequence_relationship_id {
  my $METHOD = 'get_biosequence_relationship_id';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");
  my $reference_biosequence_id = $args{reference_biosequence_id}
    or die("ERROR[$METHOD]: Parameter reference_biosequence_id not passed");
  my $related_biosequence_id = $args{related_biosequence_id}
    or die("ERROR[$METHOD]:Parameter related_biosequence_id not passed");

  #### Lookup and return biosequence_relationship_id
  my $query = qq~
	SELECT biosequence_relationship_id
	FROM $TBAT_BIOSEQUENCE_RELATIONSHIP
	WHERE
	atlas_build_id = '$atlas_build_id' AND
	reference_biosequence_id = '$reference_biosequence_id' AND
	related_biosequence_id = '$related_biosequence_id'
  ~;
  my ($biosequence_relationship_id) = $sbeams->selectOneColumn($query);

  return $biosequence_relationship_id;

} # end get_biosequence_relationship_id


###############################################################################
# get_preferred_protid_from_list  --
###############################################################################
# Given a list of protein identifiers, return our most preferred one.

sub get_preferred_protid_from_list {

  my %args = @_;
  my $protid_list_ref = $args{'protid_list_ref'};
  my $preferred_patterns_aref = $args{'preferred_patterns_aref'};
  my $debug = 0;

  # if no list of preferred patterns given, just return the first protID
  # calling program should warn user.
  if ( ( ! defined $preferred_patterns_aref ) || ! $preferred_patterns_aref ) {
    print "WARNING! just returning first protid\n";
    return $protid_list_ref->[0];
  }
  print "preferred_patterns_aref is defined.\n" if ($debug);

  my @preferred_patterns = @{$preferred_patterns_aref};
  my $protid;

  # first, sort the protid list so that the order of the identifiers in
  # the list doesn't affect what is returned from this function.
  my @protid_list = sort(@{$protid_list_ref});
  my $n_protids = scalar @protid_list;
  print "$n_protids protids\n" if ($debug);

  # check for protID regex's in order of preference
  for my $pattern (@preferred_patterns) {
    print "Checking pattern: $pattern\n" if ($debug);
    # skip empty patterns (some priority slots may be empty)
    if (! $pattern ) {
      next;
    }
    for $protid (@protid_list) {
      print "  Checking $protid vs. $pattern\n" if ($debug);
      if (($protid =~ /$pattern/) && ($protid !~ /UNMAPPED/)) {
	return $protid;
      }
    }
  }

  # if non matched, select any non-DECOY, non-UNMAPPED ID
  #print "Now, just selecting any non-DECOY, non-UNMAPPED ID\n";
  for $protid (@protid_list) {
    if (($protid !~ /^DECOY_/) && ($protid !~ /UNMAPPED/)) {
      return $protid;
    }
  }

  # otherwise, return the first ID
  return $protid_list[0];
}

###############################################################################
# read_protid_preferences --
###############################################################################
# Read from a flat file the priorities and regexes for each type of
# protein identifier for a given organism.

sub read_protid_preferences {

  my $SUBROUTINE = 'loadBuildProtInfo';
  my %args = @_;

  my $organism_id = $args{'organism_id'}
    or die("ERROR[$SUBROUTINE]: Parameter organism_id not passed");
  
  my $pipeline_dir = $CONFIG_SETTING{PeptideAtlas_PIPELINE_DIRECTORY};
  my $preference_filepath = "$pipeline_dir/../etc/protid_priorities.csv";
  open (PREF, $preference_filepath) or
    die("ERROR[$SUBROUTINE]: preference_filepath can't be opened for reading");

  my $org_idx = 0;
  my $db_idx = 1;
  my $priority_idx = 2;
  my $regex_idx = 3;
  my $n_fields = 4;

  # read header and check to see if it's what we expect
  my $line = <PREF>;
  chomp $line;
  my @field_names = split (",", $line);
  my $n_field_names = scalar @field_names;

  if ( ($n_field_names != $n_fields) or
       ($field_names[$org_idx] ne "organism_id") or
       ($field_names[$db_idx] ne "database_type") or
       ($field_names[$priority_idx] ne "priority") or
       ($field_names[$regex_idx] ne "regex") ) {
    print "WARNING: mismatch between $preference_filepath header line and $SUBROUTINE\n";
  }

  my @preferred_patterns = ();

  while ($line = <PREF>) {
    if ($line !~ /^#/) {
      chomp $line;
      # need third arg to split so commas in regex aren't
      # seen as field separators
      my @fields = split (",", $line, $n_fields);
      if ( $fields[$org_idx] != $organism_id ) {
        next;
      }
      #print "$fields[$db_idx] $fields[$priority_idx] $fields[$regex_idx]\n";
      my $priority = $fields[$priority_idx];
      my $regex = $fields[$regex_idx];
      if ( defined $preferred_patterns[$priority] ) {
      print "WARNING[$SUBROUTINE]: more than one regex at priority $priority\n";
      }
      $preferred_patterns[$priority] = $regex;
    }
  }
 
  return \@preferred_patterns;
}


###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Terry Farrah (tfarrah@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
