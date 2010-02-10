#!/usr/local/bin/perl -w
# PeptideAtlas protein information postprocessor.
# Called after createPipelineInput.pl and step02 (mapping) of pipeline.
# Takes as input a protlist file produced by createPipelineInput
#  and generates a protIdentlist and protRelationship file,
#  optionally choosing a preferred protID for each identification
# protlist consists of lines like this:
# 328,ENSP00000352019 IPI00552590,0.0000,0.1417,subsumed,ENSP000000009
# prot_group_id, list indisting protIDs, prob., conf., presence_level,
#   highest scoring canonical for prot_group, subsumed_by, est_ng_per_ml,
#   abundance_uncertainty
#
# Terry Farrah 2009 ISB

# 11/11/09: added protein group size to protIdentlist
#  Counts everything except identicals.


use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $DATABASE $current_contact_id $current_username
            );


use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::ProtInfo;

use vars qw ($PROG_NAME $USAGE %OPTIONS);
$| = 1; #disable output buffering

my $USAGE = <<EOU;
USAGE: $0 [OPTIONS]
Takes as input a protlist file produced by createPipelineInput
 and generates two files, PeptideAtlasInput.PAprot{Identlist,Relationships},
 gathering additional identicals.
Options:
  --infile       default: PeptideAtlasInput.PAprotlist
  --dupfile      default: duplicate_groups.txt
  --organism_id  Integer. For choosing preferred protIDs. Default: 2 (human)
  --help         print this usage guide
Deprecated options. Use with caution; not maintained, AND, only protIDs for
sequence-identical proteins are considered, when one really wants to
consider all indistinguishable proteins:
  --preferred_protIDs  choose preferred protIDs for PeptideAtlasInput.PAprot*
       Generally not needed; createPipelineInput already selects preferred.
  --PAidentlist   optional PAidentlist file to process.
                 Changes protIDs to preferred ones.
EOU


#### Process options
unless (GetOptions(\%OPTIONS,"infile:s", "dupfile:s", "help",
         "preferred_protIDs", "PAidentlist:s", "organism_id:i"
  )) {   print "$USAGE";
  exit;
}
if ($OPTIONS{help}) {
  print $USAGE;
  exit;
}

my $infile = $OPTIONS{infile} || "PeptideAtlasInput.PAprotlist";
my $dupfile = $OPTIONS{dupfile} || "duplicate_groups.txt";
my $preferred_patterns_aref = [];
my $organism_id = $OPTIONS{organism_id} || 0;
if (! $organism_id ) {
  print STDERR "WARNING: no organism_id given. Rules for human DB will be used when choosing which, among identical seqs, to label indistinguishable.\n";
  $organism_id = 2;
}
$preferred_patterns_aref =
  SBEAMS::PeptideAtlas::ProtInfo::read_protid_preferences(
    organism_id=>$organism_id,
);
my $n_patterns = scalar @{$preferred_patterns_aref};
if ( $n_patterns == 0 ) {
print "WARNING: No protein identifier patterns found ".
      "for organism $organism_id! ".
      "No sequence database will be preferred over another.\n";
}

my $PAidentlist = $OPTIONS{PAidentlist};
my $preferred_protIDs = $OPTIONS{preferred_protIDs};

# Processing PAidentlist file
if ($PAidentlist) {
  print "Processing $PAidentlist.\n";
  print "Will not try to createPeptideAtlasInput.PAprot{Identlist,Relationships}.\n";
# Copy file to tmp and open
  if ( ! -e $PAidentlist) {
    print "PAidentlist file $PAidentlist does not exist.\n";
    exit;
  }
  system ("cp $PAidentlist $PAidentlist.pre-swissify");
  open ( PAFILE, "$PAidentlist.pre-swissify") || die
    "Cannot open $PAidentlist.pre-swissify for reading.\n";
  open ( PAOUTFILE, ">$PAidentlist") || die
    "Cannot open $PAidentlist for writing.\n";
  # For each line in file
  while (my $line = <PAFILE>) {
    #  Get protein (field 11)
    chomp ($line);
    my @fields = split(" ", $line);
    my $protID = $fields[10];
    #  Possibly get a preferred protID
    my $primary_protID = find_preferred_protid(
      protid=>$protID,
      dupfile=>$dupfile,
      organism_id=>$organism_id
    );
    #  Substitute into line
    $fields[10] = $primary_protID;
    $line = join("\t",@fields);
    #  output line
    print PAOUTFILE "$line\n";
  }
  exit
}

#### Standard vanilla usage starts here.
#### Open files and write header lines to them.
open (INFILE, $infile) || die "Cannot open $infile for reading.\n";
my $identlistfile =  "PeptideAtlasInput.PAprotIdentlist";
open (IDENTFILE, ">$identlistfile") ||
   die "Cannot open $identlistfile for writing.\n";
print IDENTFILE
"protein_group_number,biosequence_name,probability,confidence,n_observations,n_distinct_peptides,level_name,represented_by_biosequence_name,subsumed_by_biosequence_name,estimated_ng_per_ml,abundance_uncertainty,is_covering,group_size\n";

my $relationshipfile =  "PeptideAtlasInput.PAprotRelationships";
open (RELFILE, ">$relationshipfile") ||
   die "Cannot open $relationshipfile for writing.\n";
print RELFILE "protein_group_number,reference_biosequence_name,related_biosequence_name,relationship_name\n";

####  PAprotlist line format:
# 0 $protein_group_number,
# 1 $biosequence_names (space separated),
# 2 $probability,
# 3 $confidence,        
# 4 $n_observations,
# 5 $n_distinct_peptides,
# 6 $level_name,
# 7 $represented_by_biosequence_name,
# 8 $subsumed_by_biosequence_name_list (space separated),
# 9 $estimated_ng_per_ml
# 10 $abundance_uncertainty
# 11 $is_covering
# 12 (in ouput, not in input) -- group size

my $protein_group_number_idx = 0;
my $biosequence_names_idx = 1;
my $probability_idx = 2;
my $confidence_idx = 3;
my $n_observations_idx = 4;
my $n_distinct_peptides_idx = 5;
my $level_name_idx = 6;
my $represented_by_biosequence_name_idx = 7;
my $subsumed_by_biosequence_name_list_idx = 8;
my $estimated_ng_per_ml_idx = 9;
my $abundance_uncertainty_idx = 10;
my $is_covering_idx = 11;
my $group_size_idx = 12;

my $n_input_fields = 12;

#### For each protein in PAprotlist file, including indistinguishables
#### (and, at this stage, indistinguishables INCLUDE identicals),
####  hash to all identicals.
my $duphash = {};
my $line = <INFILE>;  #throw away header line
for $line (<INFILE>) {
  chomp ($line);
  # need third arg for split, otherwise trailing null fields discarded
  my @fields = split(",", $line, $n_input_fields);
  my @protIDs = split(" ", $fields[1]);
  my @dupIDs;
  for my $protID (@protIDs) {
    #print "$protID\n";
    my $dupIDs_aref = get_dupIDs($protID, $dupfile);
    @dupIDs = @{$dupIDs_aref};
    if (scalar(@dupIDs) > 0) {
      for my $dupID  (@dupIDs) {
        if ($protID ne $dupID) {
	  $duphash->{$protID}->{$dupID} = 1;
        }
      }
    }
  }
}
close (INFILE);


#### Print hash
if (0) {
print "Here is the hash!\n";
my @protkeys = keys(%{$duphash});
for my $protID (@protkeys) {
  my @dupkeys = keys(%{$duphash->{$protID}});
  for my $dupID (@dupkeys) {
    print "$protID $dupID\n";
  }
}
}

open (INFILE, $infile) || die "Cannot open $infile for reading.\n";

my @prot_idents = ();
my %group_size = ();

my $firstline = 1;
for my $line (<INFILE>) {
  chomp ($line);
  my @fields = split(",", $line, $n_input_fields);
  my @all_fields = split(",", $line);
  if ((scalar @all_fields) > $n_input_fields) {
    print "WARNING: more than $n_input_fields fields in input line\n";
  }
  if ($firstline) {
    if ($fields[$protein_group_number_idx] =~ /protein_group/) {
      next;  #skip header line if any
    }
    $firstline = 0;
  }
  my $protein_group = $fields[$protein_group_number_idx];
  my @protIDs = split(" ", $fields[$biosequence_names_idx]);
  my $presence_level = $fields[$probability_idx];
  my @subsumed_by_list = ();
  my $subsumed_by_protID;
  @subsumed_by_list = split(' ',
       $fields[$subsumed_by_biosequence_name_list_idx]);
  # arbitrarily select the first subsumed_by protID to store
  if (scalar @subsumed_by_list > 0 ) {
    $subsumed_by_protID = $subsumed_by_list[0];
  } else {
    $subsumed_by_protID = "";
  }
  # n_obs field expects an int. but these days we're sometimes using
  # float (if apportioning PSMs to prots). Force it to int. 09/18/09.
  $fields[$n_observations_idx] = int $fields[$n_observations_idx];

  #### Choose preferred protID for primary and represented_by
  my $primary_protID;
  if ( $preferred_protIDs ) {
    $primary_protID = get_preferred_protid_from_list(
      protid_list_ref=>\@protIDs,
      preferred_patterns_aref => $preferred_patterns_aref,
     );
    if ( $fields[$represented_by_biosequence_name_idx] ne "") {
      $fields[$represented_by_biosequence_name_idx] =
        find_preferred_protid(
	  protid=>$fields[$represented_by_biosequence_name_idx],
	  dupfile=>$dupfile,
	  organism_id=>$organism_id,
	)
    }
    if ( $subsumed_by_protID ne "" ) {
      $subsumed_by_protID =
	find_preferred_protid(
	  protid=>$subsumed_by_protID,
	  dupfile=>$dupfile,
	  organism_id=>$organism_id,
	)
    }
  } else {
    $primary_protID = $protIDs[0];
  }

# DEBUGGING
#  for my $protID (@protIDs) {
#    print "$protID "; #  }
#  print "==> $primary_protID\n";

  ####  a little test Oh wait, this isn't supposed to be true all the
  #### time, not when we have multiple canonicals.
#  if ( $fields[$level_name_idx] eq "canonical" ) {
#    ok ($fields[$biosequence_names_idx] eq
#        $fields[$represented_by_biosequence_name_idx],
#        "For canonical, biosequence_name == represented_by_bioseq_name");
#  }

  #### Store reference to fields in an array.
  $fields[$biosequence_names_idx] = $primary_protID;
  $fields[$subsumed_by_biosequence_name_list_idx] = $subsumed_by_protID;
  my $prot_ident_ref = \@fields;
  push (@prot_idents, $prot_ident_ref);

  #### Count the primary protID in the tally for the group size
  if (! defined $group_size{$protein_group} ) {
    $group_size{$protein_group} = 1;
  } else {
    $group_size{$protein_group}++;
  }

  #### For each remaining protID, assign as indistinguishable or identical
  my %processed_protIDs;
  my $preferred_protID;
  my @identical_protIDs;
  # First, gather all identicals to primary and store as identical
  $processed_protIDs{$primary_protID} = 1;
  @identical_protIDs = keys(%{$duphash->{$primary_protID}});
  for my $protID (@identical_protIDs) {
    print RELFILE "$protein_group,$primary_protID,$protID,identical\n";
    $processed_protIDs{$protID} = 1;
  }
  # Now, partition remaining into sets of identicals, choose one from
  #  each set to mark as indistinguishable, and mark others as
  #  identical to that.
  for my $protID (@protIDs) {
    # Skip if we've already processed this one
    if (! defined $processed_protIDs{$protID}) {
      # Gather all protIDs identical to this one, including itself.
      @identical_protIDs = keys(%{$duphash->{$protID}});
      push (@identical_protIDs, $protID);
      # If this one is not the primary protID ...
      # Find preferred protID among all identicals, including self
      $preferred_protID = get_preferred_protid_from_list(
        protid_list_ref=>\@identical_protIDs,
	preferred_patterns_aref => $preferred_patterns_aref,
       );
      # Store preferred one as indistinguishable from primary
      print RELFILE "$protein_group,$primary_protID,$preferred_protID,indistinguishable\n";
      # Note that we've processed the protIDs for the preferred one
      $processed_protIDs{$preferred_protID} = 1;
      # Store others as identical to preferred
      for my $protID2 (@identical_protIDs) {
	if ( $protID2 ne $preferred_protID) {
	  print RELFILE "$protein_group,$preferred_protID,$protID2,identical\n";
	  $processed_protIDs{$protID2} = 1;
	}
      }
      # Count this indistinguishable in the tally for the group
      $group_size{$protein_group}++;
    }
  }
}


### Write protein identifications to protIdentlist.
for my $prot_ident (@prot_idents) {
  my @fields = @{$prot_ident};
  # get protein group size and add it as another field
  my $protein_group = $fields[$protein_group_number_idx];
  $fields[$group_size_idx] = $group_size{$protein_group};
  my $line = join(",",@fields);
  print IDENTFILE "$line\n";
}
close (IDENTFILE);


sub get_dupIDs {
  ### given a protID and a duplicate_entries file,
  ### returns list of identical IDs, including input ID.
  my $protID = shift;
  my $dupfile = shift;
  my @dupIDs = ();

  # -w matches whole words only, but hyphen seems to count as
  # whitespace so doesn't help deal with swiss-prot varsplice
  if ( ! -e $dupfile ) {
    die "get_dupIDs(): can't find duplicate entries file $dupfile.\n";
  }
  my @duplines = `grep -w "$protID" $dupfile`;
  my $dupline;
  # find line with actual exact whole-word match
  for my $line (@duplines) {
    if (($line =~ /\s$protID\s/) || ($line =~ /^$protID\s/) ||
	($line =~ /\s$protID\$/)) {
      #print $line;
      $dupline = $line;
      last;
    }
  }
  if (defined $dupline) {
    @dupIDs = split(" ", $dupline);
  }
  return (\@dupIDs);
}

# Given a protID, get all the sequence-identical protIDs
# and return the most preferred one.
# We really want to consider all indistinguishable protIDs, not
# just the sequence-identical ones.
sub find_preferred_protid {
  my %args = @_;
  my $protID = $args{protID};
  my $dupfile = $args{dupfile};
  my $organism_id = $args{organism_id} || 0;

  #  Get all duplicate IDs
  my $dupIDs_aref = get_dupIDs($protID, $dupfile);
  my @dupIDs = @{$dupIDs_aref};
  #  Choose preferred one.
  my $primary_protID = $protID;
  if (scalar(@dupIDs) > 0) {
    $primary_protID = get_preferred_protid_from_list(
      protid_list_ref=>$dupIDs_aref,
      preferred_patterns_aref => $preferred_patterns_aref,
     );
  }
  return ($primary_protID);
}
