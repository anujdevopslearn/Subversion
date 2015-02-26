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
 more_likely_protein_identification
 stronger_presence_level
 is_uniprot_identifier
);


###############################################################################
# Constructor
###############################################################################
sub new {
    # TMF: forgive my self-tutorial comments below.
    my $this = shift;  #either this package, or a reference to it.
    my $class = ref($this) || $this;  #if a ref, deref it.
    my $self = {};  # a hash ref to an empty hash
    bless $self, $class; # assoc a class with the hash: this is the magic! now we can call methods on self. 
    $VERBOSE = 0;  # initialize these two global variables
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
  my $nfields = 14;
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
        $seq_unique_prots_in_group,
        $norm_PSMs_per_100K,
	  ) = split(",", $line, $nfields);
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

    $level_name =~ s/\s+from.*//;

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
       norm_PSMs_per_100K => $norm_PSMs_per_100K,
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
  my $norm_PSMs_per_100K = $args{norm_PSMs_per_100K};

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
      norm_PSMs_per_100K => $norm_PSMs_per_100K,
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
  my $norm_PSMs_per_100K = $args{norm_PSMs_per_100K};

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
     norm_PSMs_per_100K => $norm_PSMs_per_100K,
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
  my $swiss_prot_href = $args{'swiss_prot_href'};
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

  # If we were given a hash of Swiss-Prot ids, see if we have one
  # of those. If so, this is the most preferred.
  if (defined $swiss_prot_href) {
    for $protid (@protid_list) {
      print "  Checking $protid in Swiss-Prot hash\n" if ($debug);
      if ((defined $swiss_prot_href->{$protid}) && ($protid !~ /UNMAPPED/)) {
	return $protid;
      }
    }
  }

  # Next, check for protID regex's in order of preference
  for my $pattern (@preferred_patterns) {
    print "Checking pattern: $pattern\n" if ($debug);
    # skip empty patterns (some priority slots may be empty)
    if (! $pattern ) {
      next;
    }
    for $protid (@protid_list) {
      print "  Checking $protid vs. $pattern\n" if ($debug);
      if (($protid =~ /$pattern/) && ($protid !~ /UNMAPPED/) && ($protid !~ /DECOY/)) {
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
    if ( ( $line !~ /^#/ ) && ( $line !~ /^\s*$/ ) ) {
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
# more_likely_protein_identification
###############################################################################
# Given info on two protein identifications, return the one with the
# properties making it more likely to actually have been observed:
# 0. Swiss-Prot identifier
# 1. higher prob
# 2. more observations
# 3. more distinct peptides
# 4. more total enzymatic termini
# 5. in the covering set
# 6. more preferred name (e.g. Ensembl > IPI)
# 12/27/12: element 0 added to top of list
# 01/17/13: Swiss-Prot differentiated from Uniprot via hash

sub more_likely_protein_identification {
  my %args = @_;
  my $preferred_patterns_aref = $args{'preferred_patterns_aref'};
  my $swiss_prot_href = $args{'swiss_prot_href'};
  my $protid1 = $args{'protid1'};
  my $protid2 = $args{'protid2'};
  return $protid1 if ($protid1 eq $protid2);
#  return $protid1 if ($protid2 =~ /DECOY/);
#  return $protid2 if ($protid1 =~ /DECOY/);
  my $swiss_prot_overrides_all_else = 1;  #added 12/27/12

  # Note that if no hash of Swiss-Prot idents is provided,
  # we will prefer *all* Uniprot idents over all else.
  # Careful, this may not be what we want.
  my $is_swiss1 = (defined $swiss_prot_href)?
      (defined $swiss_prot_href->{$protid1}) : is_uniprot_identifier($protid1);
  my $is_swiss2 = (defined $swiss_prot_href)?
      (defined $swiss_prot_href->{$protid2}) : is_uniprot_identifier($protid2);
  my $prob1 = $args{'prob1'} || 0;
  my $prob2 = $args{'prob2'} || 0;
  my $nobs1 = $args{'nobs1'} || 0;
  my $nobs2 = $args{'nobs2'} || 0;
  my $npeps1 = $args{'npeps1'} || 0;
  my $npeps2 = $args{'npeps2'} || 0;
  my $enz_termini1 = $args{'enz_termini1'} || 0;
  my $enz_termini2 = $args{'enz_termini2'} || 0;
  my $presence_level1 = $args{'presence_level1'} || 'none';
  my $presence_level2 = $args{'presence_level2'} || 'none';

  if ($swiss_prot_overrides_all_else) {
    return $protid1 if ($is_swiss1 > $is_swiss2);
    return $protid2 if ($is_swiss1 < $is_swiss2);
  }
  return $protid1 if ($prob1 > $prob2);
  return $protid2 if ($prob1 < $prob2);
  return $protid1 if ($nobs1 > $nobs2);
  return $protid2 if ($nobs1 < $nobs2);
  return $protid1 if ($npeps1 > $npeps2);
  return $protid2 if ($npeps1 < $npeps2);
  return $protid1 if ($enz_termini1 > $enz_termini2);
  return $protid2 if ($enz_termini1 < $enz_termini2);
  return $protid1 if
     (stronger_presence_level($presence_level1, $presence_level2));
  return $protid2 if
     (stronger_presence_level($presence_level2, $presence_level1));

  my @protid_list = ($protid1, $protid2);
  my $preferred_protein_name = 
    SBEAMS::PeptideAtlas::ProtInfo::get_preferred_protid_from_list(
      protid_list_ref=>\@protid_list,
      preferred_patterns_aref => $preferred_patterns_aref,
      swiss_prot_href => $swiss_prot_href,
  );
  return $preferred_protein_name;
}
  
###############################################################################
# stronger_presence_level
###############################################################################
sub stronger_presence_level {
  my $level1 = shift;
  my $level2 = shift;

  if ($level1 eq 'none') {
    return ( 0 );
  } elsif ($level1 eq 'canonical') {
    return ($level2 ne 'canonical');
  } elsif ($level1 eq 'possibly_distinguished') {
    return (($level2 ne 'canonical') && ($level2 ne 'possibly_distinguished'));
  } elsif ($level1 eq 'ntt-subsumed') {
    return ($level2 eq 'subsumed');
  } elsif ($level1 eq 'subsumed' ) {
    return ( 0 );
  } else {
    print "ERROR: unknown presence level $level1\n";
    return ( 0 );
  }
}



###############################################################################
# is_uniprot_identifier
###############################################################################
# The regex below works for human, mouse, pig, and cow, at least.
sub is_uniprot_identifier {
  my $protid = shift;
  # regex's identical to those in $PIPELINE/etc/protid_priorities.csv
  # and originally gotten from swiss-prot website
  return (($protid =~ /^[O-Q]\d\w{3}\d$/) ||
          ($protid =~ /^[O-Q]\d\w{3}\d-\d+$/) ||
          ($protid =~ /^[A-N,R-Z]\d[A-Z]\w\w\d$/) ||
          ($protid =~ /^[A-N,R-Z]\d[A-Z]\w\w\d-\d+$/));
}


###############################################################################
# get_swiss_prot_species
#   Return the string used by Swiss-Prot in its ABC_HUMAN style identifiers
###############################################################################
sub get_swiss_prot_species {
  my $genus_species = shift;

  if ($genus_species =~ /homo.*sapiens/i) {
    return "HUMAN";
  } elsif ($genus_species =~ /mus.*musculus/i) {
    return "MOUSE";
  } elsif ($genus_species =~ /bos.*taurus/i) {
    return "BOVIN";
  } elsif ($genus_species =~ /sus.*scrofa/i) {
    return "PIG";
  } elsif ($genus_species =~ /saccharomyces.*cerevisiae/i) {
    return "YEAST";
  } elsif ($genus_species =~ /drosophila.*melanogaster/i) {
    return "DROME";
  } elsif ($genus_species =~ /eschericia.*coli/i) {
    return "ECOLI";
  } elsif ($genus_species =~ /rattus.*norvegicus/i) {
    return "RAT";
  } elsif ($genus_species =~ /(danio.*rerio|zebrafish)/){
    return "DANRE";
  } else {
    return "";
  }
}


###############################################################################
# filter_swiss_prot
#   Given list of biosequence IDs, return only those in Swiss-Prot.
#   Assumes the dbxref_id field for Swiss-Prot biosequences has been set to 1
#   (for some builds, it's set to the value for Uniprot, which is 35)
###############################################################################
sub filter_swiss_prot {
  my $self = shift;
  my %args = @_;
  my $bssid = $args{bssid};
  my $atlas_build_id = $args{atlas_build_id};
  my $protid_aref = $args{protid_aref} ||
     die "filter_swiss_prot: need protid_aref<br>\n";
  my @swiss_bsids = ();

  die "filter_swiss_prot: need either bssid or atlas_build_id.\n"
    if (! (defined $bssid || defined $atlas_build_id));

  if (@{$protid_aref}) {
    if ( ! defined $bssid ) {
      my $sql = qq~
      SELECT biosequence_set_id
      FROM $TBAT_ATLAS_BUILD
      WHERE atlas_build_id = $atlas_build_id
      ~;
      ($bssid) = $sbeams->selectOneColumn($sql);
      die "filter_swiss_prot: can't get bssid for atlas $atlas_build_id<br>\n"
      if (! $bssid);
    }

    my $protids = "'" . join ("','", @{$protid_aref}) . "'" ;
    my $sql = qq~
      SELECT biosequence_id
      FROM $TBAT_BIOSEQUENCE
      WHERE biosequence_set_id = $bssid
      AND biosequence_id in ($protids)
      AND dbxref_id = 1;
    ~;
    @swiss_bsids = $sbeams->selectOneColumn($sql);
  }
  return \@swiss_bsids;
}

###############################################################################
# get_swiss_prot_hash
#   Return a hash of Swiss-Prot identifiers for a given biosequence set,
#    including any varsplic idents in the set.
#   Assumes the dbxref_id field for Swiss-Prot biosequences has been set to 1
#   (for some builds, it's set to the value for Uniprot, which is 35)
###############################################################################
sub get_swiss_prot_hash {
  my $self = shift;
  my %args = @_;
  my $bssid = $args{bssid};
  my $atlas_build_id = $args{atlas_build_id};
  my $swiss_prot_href;

  die "get_swiss_prot_hash: need either bssid or atlas_build_id.\n"
    if (! (defined $bssid || defined $atlas_build_id));

  if ( ! defined $bssid ) {
    if ( defined $atlas_build_id ) {
      my $sql = qq~
	SELECT biosequence_set_id
	FROM $TBAT_ATLAS_BUILD
	WHERE atlas_build_id = $atlas_build_id
      ~;
      ($bssid) = $sbeams->selectOneColumn($sql);
    }
  }

  if ( defined $bssid ) {
    my $sql = qq~
    SELECT biosequence_id,biosequence_name, dbxref_id
    FROM $TBAT_BIOSEQUENCE
    WHERE biosequence_set_id = $bssid
    ~;
    my @rows = $sbeams->selectSeveralColumns($sql);
    my %var;
    foreach my $row (@rows) {
      my $biosequence_id = $row->[0];   #not currently used
      my $biosequence_name = $row->[1];
      my $dbxref_id = $row->[2];
      if ((defined $dbxref_id) && ($dbxref_id == 1 || $dbxref_id == 1135)) {
        if ( $biosequence_name =~ /\-[23456789]/ ) {
          $var{$biosequence_name}++;
          $swiss_prot_href->{$biosequence_name}++;
        } else {
          $swiss_prot_href->{$biosequence_name}++;
        }
      }
    }
    my $var = scalar( keys( %var ) );
    my $sp = scalar( keys( %{$swiss_prot_href} ) );
    print STDERR "Saw $sp Swiss Prot and $var Varsplic entries\n";
  }
  return $swiss_prot_href;
}

###############################################################################
# get_swiss_idents_in_build
#   Returns a hash of Swiss-Prot identifiers seen in an atlas build at
#   any presence level.
###############################################################################
sub get_swiss_idents_in_build {
  my $self = shift;
  my %args = @_;
  my $atlas_build_id = $args{atlas_build_id} || die
      "get_swiss_idents_in_build: need atlas_build_id";
  my $canonical = $args{canonical};

  my $swiss_prot_href = $self->get_swiss_prot_hash(
    atlas_build_id => $atlas_build_id,
  );
  my $all_idents_in_build_href = $self->get_all_idents_in_build(
    atlas_build_id => $atlas_build_id,
  );
  my $swiss_idents_in_build_href = ();
  for my $ident (keys %{$all_idents_in_build_href}) {
    $swiss_idents_in_build_href->{$ident} = 1
      if defined $swiss_prot_href->{$ident};
  }
  
  if ($canonical) {
    my %canonical_idents;
    for my $ident (keys %{$swiss_idents_in_build_href}) {
      my $canonical = substr($ident, 0, 6);
      $canonical_idents{$canonical} = 1;
    }
    $swiss_idents_in_build_href = \%canonical_idents;
  }

  return $swiss_idents_in_build_href;
}

###############################################################################
# get_all_idents_in_build
#   Returns a hash of all protein identifiers seen in an atlas build at
#   any presence level.  Also called the exhaustive list.
###############################################################################
sub get_all_idents_in_build {
  my $self = shift;
  my %args = @_;
  my $atlas_build_id = $args{atlas_build_id} ||
      "get_all_idents_in_build: need atlas_build_id";

  # Get all idents with presence level (canonical, possibly_distinguished, etc.)
  my $sql = qq~
    select bs.biosequence_name
    from $TBAT_BIOSEQUENCE bs
    join $TBAT_PROTEIN_IDENTIFICATION pi
    on pi.biosequence_id = bs.biosequence_id
    where pi.atlas_build_id = $atlas_build_id;
  ~;
  my @idents = $sbeams->selectOneColumn($sql);

  # Get all idents that are indistinguishable or identical
  $sql = qq~
    select bs.biosequence_name
    from $TBAT_BIOSEQUENCE bs
    join $TBAT_BIOSEQUENCE_RELATIONSHIP br
    on br.related_biosequence_id = bs.biosequence_id
    where br.atlas_build_id = $atlas_build_id;
  ~;
  my @related_idents = $sbeams->selectOneColumn($sql);
#--------------------------------------------------
#   my %all_idents_in_build_test = map {$_ => 1 } @related_idents;
#   my $n_idents = scalar keys %all_idents_in_build_test;
#   print STDERR "$n_idents idents in related_idents\n";
#   print STDERR "A6NC86 is in hash\n" if $all_idents_in_build_test{'A6NC86'};
#   print STDERR "A8MXU9 is in hash\n" if $all_idents_in_build_test{'A8MXU9'};
#   print STDERR "P43487 is in hash\n" if $all_idents_in_build_test{'P43487'};
#   print STDERR "A0A5B9 is in hash\n" if $all_idents_in_build_test{'A0A5B9'};
#-------------------------------------------------- 

  @idents = (@idents, @related_idents);
  my $n_idents = scalar @idents;
  #print STDERR "$n_idents ident in combined idents, related_idents\n";
  my %all_idents_in_build = map {$_ => 1 } @idents;
#--------------------------------------------------
#   my $n_idents = scalar keys %all_idents_in_build;
#   print STDERR "$n_idents ident in nonredundant hash\n";
#   print STDERR "A6NC86 is in hash\n" if $all_idents_in_build{'A6NC86'};
#   print STDERR "A8MXU9 is in hash\n" if $all_idents_in_build{'A8MXU9'};
#   print STDERR "P43487 is in hash\n" if $all_idents_in_build{'P12314'};
#   print STDERR "A0A5B9 is in hash\n" if $all_idents_in_build{'A0A5B9'};
#-------------------------------------------------- 


  return \%all_idents_in_build;

}

#############################################################################
###  Update_protInfo when spectrum annotation update
#############################################################################
sub update_protInfo{
  my $METHOD = 'update_protInfo';
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id\n";
  my $action = $args{action} || die "need action term\n"; 
  my $spectrum_annotation_id = $args{spectrum_annotation_id} || die "need spectrum_annotation_id\n";;

  my $sql = qq~
    SELECT 	BS.BIOSEQUENCE_NAME,
            PRI.PROTEIN_IDENTIFICATION_ID,
            PRI.PRESENCE_LEVEL_ID, 
						PRI.N_OBSERVATIONS,
						PRI.N_DISTINCT_PEPTIDES, 
						PI.PEPTIDE_INSTANCE_ID,
						PI.N_OBSERVATIONS
		FROM $TBAT_SPECTRUM_ANNOTATION SA
		JOIN $TBAT_SPECTRUM_IDENTIFICATION SI ON (SA.SPECTRUM_IDENTIFICATION_ID = SI.SPECTRUM_IDENTIFICATION_ID)
		JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI ON (SI.MODIFIED_PEPTIDE_INSTANCE_ID = MPI.MODIFIED_PEPTIDE_INSTANCE_ID)
		JOIN $TBAT_PEPTIDE_INSTANCE PI ON (PI.PEPTIDE_INSTANCE_ID = MPI.PEPTIDE_INSTANCE_ID)
		JOIN $TBAT_PEPTIDE_MAPPING PM ON (PM.PEPTIDE_INSTANCE_ID = PI.PEPTIDE_INSTANCE_ID)
		JOIN $TBAT_BIOSEQUENCE BS ON (BS.BIOSEQUENCE_ID = PM.MATCHED_BIOSEQUENCE_ID )
		JOIN $TBAT_PROTEIN_IDENTIFICATION PRI ON (PRI.BIOSEQUENCE_ID = BS.BIOSEQUENCE_ID)
		WHERE PRI.ATLAS_BUILD_ID = $atlas_build_id 
         AND spectrum_annotation_id = $spectrum_annotation_id 
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);
  my %peptide_instance_id = ();
  foreach my $row(@rows){
    my ($prot,$prot_id,$presence_level_id, $prot_n_obs,$prot_n_peps,$pi_id,$pep_n_obs) = @$row;
    if ($action =~ /add/i){
      $pep_n_obs++;
      $prot_n_obs++;
    }elsif($action =~ /remove/i){
      $pep_n_obs--;
      $prot_n_obs--;
    }
    if ($action =~ /add/i){
      if($pep_n_obs == 1){
        ## protein recovered if protein was rejected 
        $presence_level_id = 13 if($presence_level_id == 12);
      }
    }elsif($action =~ /remove/i){
      $prot_n_peps-- if(!$pep_n_obs);
      ## protein rejected if prot_n_peps goes from 1 -> 0
      $presence_level_id = 12 if(! $prot_n_peps);
    }
		my $rowdata = {n_observations => $pep_n_obs};
		update_table (table_name => $TBAT_PEPTIDE_INSTANCE,
										key => 'peptide_instance_id',
										key_value => $pi_id,
										rowdata_ref => $rowdata) if (! $peptide_instance_id{$pi_id});
      
    $rowdata = {presence_level_id => $presence_level_id};
    ## update protein identification table
    update_table( table_name => $TBAT_PROTEIN_IDENTIFICATION,
									key => 'PROTEIN_IDENTIFICATION_ID',
									key_value => $prot_id,
									rowdata_ref => $rowdata);
    $peptide_instance_id{$pi_id} = 1;
  }
}
#############################################################################
###  Update_protInfo_using_annotation
#############################################################################
sub update_protInfo_all_annotation {
  my $METHOD = 'Update_protInfo_using_annotation';
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id\n";
  my $sql = qq~
    SELECT 	BS.BIOSEQUENCE_NAME, 
            PRI.PROTEIN_IDENTIFICATION_ID, 
						PRI.N_OBSERVATIONS,
						PRI.N_DISTINCT_PEPTIDES, 
            PRI.PRESENCE_LEVEL_ID,
						PI.PEPTIDE_INSTANCE_ID,
						PI.N_OBSERVATIONS, 
						COUNT (SI.SPECTRUM_IDENTIFICATION_ID ) AS N_SPEC_REMOVED
		FROM $TBAT_SPECTRUM_ANNOTATION SA
		JOIN $TBAT_SPECTRUM_IDENTIFICATION SI ON (SA.SPECTRUM_IDENTIFICATION_ID = SI.SPECTRUM_IDENTIFICATION_ID)
		JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI ON (SI.MODIFIED_PEPTIDE_INSTANCE_ID = MPI.MODIFIED_PEPTIDE_INSTANCE_ID)
		JOIN $TBAT_PEPTIDE_INSTANCE PI ON (PI.PEPTIDE_INSTANCE_ID = MPI.PEPTIDE_INSTANCE_ID)
		JOIN $TBAT_PEPTIDE_MAPPING PM ON (PM.PEPTIDE_INSTANCE_ID = PI.PEPTIDE_INSTANCE_ID)
		JOIN $TBAT_BIOSEQUENCE BS ON (BS.BIOSEQUENCE_ID = PM.MATCHED_BIOSEQUENCE_ID )
		JOIN $TBAT_PROTEIN_IDENTIFICATION PRI ON (PRI.BIOSEQUENCE_ID = BS.BIOSEQUENCE_ID)
		WHERE SA.SPECTRUM_ANNOTATION_LEVEL_ID > 2 AND SA.IDENTIFIED_PEPTIDE_SEQUENCE = MPI.MODIFIED_PEPTIDE_SEQUENCE
		AND PRI.ATLAS_BUILD_ID = $atlas_build_id 
		AND SA.RECORD_STATUS  != 'D'
    GROUP BY PRI.PROTEIN_IDENTIFICATION_ID,
            PRI.N_OBSERVATIONS,
            PRI.N_DISTINCT_PEPTIDES,
            PI.PEPTIDE_INSTANCE_ID,
            PI.N_OBSERVATIONS,
            PRI.PRESENCE_LEVEL_ID,
            BS.BIOSEQUENCE_NAME 
    ORDER BY PRI.PROTEIN_IDENTIFICATION_ID 
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);
  my %peptide_instance_id = ();
  my $pre_prot_id = '';
  my $pre_prot = '';
  my $pre_presence_level_id ='';
  my $new_prot_n_peps;
  my $new_prot_n_obs;
  foreach my $row(@rows){
    my ($prot,$prot_id,$prot_n_obs,$prot_n_peps,$presence_level_id,$pi_id,$pep_n_obs,$n_spec_removed) = @$row;
    if ($prot_id ne $pre_prot_id){
      if ($pre_prot_id ne ''){
        if (! $new_prot_n_peps ){
          $pre_presence_level_id = 12;
        }
        #print "$pre_prot, $new_prot_n_obs,$new_prot_n_peps, $pre_presence_level_id\n";
        my $rowdata = { presence_level_id => $pre_presence_level_id };
        ## update protein identification table
        update_table( table_name => $TBAT_PROTEIN_IDENTIFICATION,
											key => 'protein_identification_id',
											key_value => $pre_prot_id,
											rowdata_ref => $rowdata);
     }
     $new_prot_n_peps = $prot_n_peps;
     $new_prot_n_obs = $prot_n_obs;
   }
		$pep_n_obs -= $n_spec_removed;
		$new_prot_n_obs -= $n_spec_removed;
		if (! $pep_n_obs ){
			$new_prot_n_peps--;
		}
		## update peptide n_obs 
		my $rowdata = {n_observations => $pep_n_obs };
		update_table (table_name => $TBAT_PEPTIDE_INSTANCE,
									key => 'peptide_instance_id',
									key_value => $pi_id,
									rowdata_ref => $rowdata) if (! $peptide_instance_id{$pi_id});
    $peptide_instance_id{$pi_id} = 1;
		$pre_prot_id = $prot_id;
		$pre_prot = $prot;
		$pre_presence_level_id = $presence_level_id;
  }
  if (! $new_prot_n_peps ){
    $pre_presence_level_id = 12;
  }
  my $rowdata = { presence_level_id => $pre_presence_level_id };

  update_table( table_name => $TBAT_PROTEIN_IDENTIFICATION,
                key => 'protein_identification_id',
                key_value => $pre_prot_id,
                rowdata_ref => $rowdata);

}

sub update_table {
  my %args = @_;
  my $rowdata_ref = $args{rowdata_ref};
  my $key_value = $args{key_value};
  my $key = $args{key};
  my $table_name = $args{table_name};

	my $PK = $sbeams->updateOrInsertRow(
			update => 1,
			table_name => $table_name, 
			rowdata_ref => $rowdata_ref,
			PK => $key, 
			PK_value => $key_value,
			return_PK => 1,
			verbose=>$VERBOSE,
			testonly=>$TESTONLY,
	);
}
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
