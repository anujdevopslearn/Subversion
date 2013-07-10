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
# 01/10/11: added norm_PSMs_per_100K
# 02/08/13: sped up by reading duplicate_groups.txt into hash
#           accommodate PAB extensions

use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../../perl";

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
		 May make occasional mistakes with PAB peptides.
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
      "for organism $organism_id!\n".
      "Protein identifiers will be chosen for indistinguishables\n".
      " according to rules for human.\n";
}

my $PAidentlist = $OPTIONS{PAidentlist};
my $preferred_protIDs = $OPTIONS{preferred_protIDs};

# Read duplicate_groups file; store in a hash.
my $dup_href = read_duplicate_groups(
  dupfile => $dupfile,
);

# If --PAidentlist, then update identifiers in PAidentlist file & exit.
# 2013: this functionality hasn't been used in years.
if ($PAidentlist) {
  process_PAidentlist(
    PAidentlist => $PAidentlist,
    dup_href => $dup_href,
    organism_id => $organism_id,
  );
  exit;
}

#### Open output files and write header lines to them.
open (my $infh, $infile) || die "Cannot open $infile for reading.\n";
my $identlistfile =  "PeptideAtlasInput.PAprotIdentlist";
open (my $identfh, ">$identlistfile") ||
   die "Cannot open $identlistfile for writing.\n";
print $identfh
"protein_group_number,biosequence_name,probability,confidence,n_observations,n_distinct_peptides,level_name,represented_by_biosequence_name,subsumed_by_biosequence_name,estimated_ng_per_ml,abundance_uncertainty,is_covering,group_size,norm_PSMs_per_100K\n";

my $relationshipfile =  "PeptideAtlasInput.PAprotRelationships";
open (my $relfh, ">$relationshipfile") ||
   die "Cannot open $relationshipfile for writing.\n";
print $relfh "protein_group_number,reference_biosequence_name,related_biosequence_name,relationship_name\n";


### Define columns
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
# Final field in input (PAprotlist)
my $norm_PSMs_per_100K_input_idx = 12;
# Final 2 fields in output (PAprotIdentlist) are different; we squeeze
# in one more:
my $group_size_idx = 12;
my $norm_PSMs_per_100K_output_idx = 13;

my $n_input_fields = 13;


### Separate identicals from indistinguishables, and write to
### protRelationships file.
print "Processing $infile and writing identical/indistinguishable relationships to $relationshipfile ...\n";

my $group_size_href = {};
my $prot_idents_aref =
write_protRelationships(
  infh => $infh,
  relfh => $relfh,
  n_input_fields => $n_input_fields,
  protein_group_number_idx => $protein_group_number_idx,
  biosequence_names_idx => $biosequence_names_idx,
  probability_idx => $probability_idx,
  n_observations_idx => $n_observations_idx,
  subsumed_by_biosequence_name_list_idx => 
    $subsumed_by_biosequence_name_list_idx,
  group_size_idx => $group_size_idx,
  group_size_href => $group_size_href,
  norm_PSMs_per_100K_input_idx => $norm_PSMs_per_100K_input_idx,
  norm_PSMs_per_100K_output_idx => $norm_PSMs_per_100K_output_idx,
);


### Write protein identifications to protIdentlist.
print "Writing protein identifications to $identlistfile ...\n";
write_protIdentlist (
  prot_idents_aref => $prot_idents_aref,
  identfh => $identfh,
  protein_group_number_idx => $protein_group_number_idx,
  group_size_idx => $group_size_idx,
  group_size_href => $group_size_href,
);


###############################################################################
# Subroutines
###############################################################################

sub get_dupIDs {
  ### given a protID and a hash of duplicates;
  ### returns list of identical IDs, excluding input ID.
  my $protID = shift;
  my $dup_href = shift;

  my @dupIDs = keys %{$dup_href->{$protID}};
  return (\@dupIDs);
}

# Given a protID, get all the sequence-identical protIDs
# and return the most preferred one.
# We really want to consider all indistinguishable protIDs, not
# just the sequence-identical ones.
sub find_preferred_protid_for_identical_seq {
  my %args = @_;
  my $protID = $args{protID};
  my $dup_href = $args{dup_href};
  my $organism_id = $args{organism_id} || 0;

  #  Get all duplicate IDs
  my $dupIDs_aref = get_dupIDs($protID, $dup_href);
  my @dupIDs = ($protID, @{$dupIDs_aref});
  #  Choose preferred one.
  my $primary_protID = $protID;
  if (scalar(@dupIDs) > 0) {
    $primary_protID = 
  SBEAMS::PeptideAtlas::ProtInfo::get_preferred_protid_from_list(
      protid_list_ref=>$dupIDs_aref,
      preferred_patterns_aref => $preferred_patterns_aref,
     );
  }
  return ($primary_protID);
}

sub read_duplicate_groups{
  my %args = @_;
  my $dupfile = $args{'dupfile'};

  my $dup_href = {};
  my $count = 0;
  print "Reading $dupfile; hashing all identifiers to the identifiers for their non-self, sequence-identical duplicates ...\n";
  open(my $dupfh, $dupfile) || die "Can't open $dupfile for reading.";
  <$dupfh>;  #throw away header line
  while (my $line = <$dupfh>) {
    chomp $line;
    my @protids = split('\t', $line);
    # Hash each protid to all other identical protids. Exclude self.
    for my $protid (@protids) {
      for my $protid2 (@protids) {
	$dup_href->{$protid}->{$protid2} = 1
	    if ($protid ne $protid2);
      }
    }
    $count++;
    if ($count % 10000 == 0) {
      print $count;
    } elsif ($count % 1000 == 0) {
      print ".";
    }
  }
  print "\n" if $count >= 1000;
  return $dup_href;
}

# 2013: this functionality hasn't been used in years.
sub process_PAidentlist {
  my %args = @_;
  my $PAidentlist = $args{'PAidentlist'};
  my $dup_href = $args{'dup_href'};
  my $organism_id = $args{'organism_id'};

  print "Substituting preferred protIDs into $PAidentlist.\n";
  print "Will not try to createPeptideAtlasInput.PAprot{Identlist,Relationships}.\n";
  print "WARNING: may make bad selections for proteins with PAB extensions! .\n";
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
    # Note: if this peptide matches the PAB extension for the original
    #  protid, it's possible that this will replace the protid with
    #  one that lacks the extension. But unlikely, because Swiss-Prot
    #  is most preferred, and Swiss-Prot+Trembl have the PAB extensions.
    my $primary_protID = find_preferred_protid_for_identical_seq(
      protid=>$protID,
      dup_href=>$dup_href,
      organism_id=>$organism_id
    );
    #  Substitute into line
    $fields[10] = $primary_protID;
    $line = join("\t",@fields);
    #  output line
    print PAOUTFILE "$line\n";
  }
}


sub write_protRelationships {
  my %args = @_;
  my $infh = $args{'infh'};
  my $relfh = $args{'relfh'};
  my $n_input_fields = $args{'n_input_fields'};
  my $protein_group_number_idx = $args{'protein_group_number_idx'};
  my $biosequence_names_idx = $args{'biosequence_names_idx'};
  my $probability_idx = $args{'probability_idx'};
  my $n_observations_idx = $args{'n_observations_idx'};
  my $subsumed_by_biosequence_name_list_idx = 
    $args{'subsumed_by_biosequence_name_list_idx'};
  my $group_size_idx = $args{'group_size_idx'};
  my $group_size_href = $args{'group_size_href'};
  my $norm_PSMs_per_100K_input_idx = $args{'norm_PSMs_per_100K_input_idx'};
  my $norm_PSMs_per_100K_output_idx = $args{'norm_PSMs_per_100K_output_idx'};

  my $prot_idents_aref;
  my $firstline = 1;
  my $count = 0;
  my $warning_count = 0;
  for my $line (<$infh>) {
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
    my @indist_protIDs = split(" ", $fields[$biosequence_names_idx]);
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
    #### Since 2009, this functionality has not been used.
    #### Note that this can possibly (though rarely) fail with PAB peptides.
    ####  In particular, if the current protid is Trembl with PAB peps,
    ####   and it is identical to Swiss-Prot.
    my $primary_protID;
    $primary_protID = $indist_protIDs[0];
    if ( $preferred_protIDs ) {
      $primary_protID = 
    SBEAMS::PeptideAtlas::ProtInfo::get_preferred_protid_from_list(
	protid_list_ref=>\@indist_protIDs,
	preferred_patterns_aref => $preferred_patterns_aref,
       );
      if ( $fields[$represented_by_biosequence_name_idx] ne "") {
	$fields[$represented_by_biosequence_name_idx] =
	  find_preferred_protid_for_identical_seq(
	    protid=>$fields[$represented_by_biosequence_name_idx],
	    dup_href=>$dup_href,
	    organism_id=>$organism_id,
	  )
      }
      if ( $subsumed_by_protID ne "" ) {
	$subsumed_by_protID =
	  find_preferred_protid_for_identical_seq(
	    protid=>$subsumed_by_protID,
	    dup_href=>$dup_href,
	    organism_id=>$organism_id,
	  )
      }
    }

    #### Store reference to @fields in an array.
    $fields[$biosequence_names_idx] = $primary_protID;
    # get norm_PSMs_per_100K from input fields before we overwrite it
    my $norm_PSMs_per_100K = $fields[$norm_PSMs_per_100K_input_idx];
    $fields[$subsumed_by_biosequence_name_list_idx] = $subsumed_by_protID;
    $fields[$group_size_idx] = '';  # will be filled in later
    if (! defined $norm_PSMs_per_100K) {
      printf "WARNING: Final field $norm_PSMs_per_100K_input_idx (norm PSMs per 100K) is empty in input file, record %d.\n", $count+1 if $warning_count < 5;
      $warning_count++;
      print "=>Warning for norm PSMs per 100K turned off for remainder of processing.\n" if ($warning_count == 5);
      $norm_PSMs_per_100K = '';
    }
    $fields[$norm_PSMs_per_100K_output_idx] = $norm_PSMs_per_100K;
    my $prot_ident_aref = \@fields;
    push (@{$prot_idents_aref}, $prot_ident_aref);

    #### Count the primary protID in the tally for the group size
    if (! defined $group_size_href->{$protein_group} ) {
      $group_size_href->{$protein_group} = 1;
    } else {
      $group_size_href->{$protein_group}++;
    }

    #### For each remaining protID, assign as indistinguishable or identical
    my %processed_protIDs;
    my $preferred_protID;
    my @identical_protIDs;
    # First, from among all indistiguishables to primary, gather all
    # that are identical
    $processed_protIDs{$primary_protID} = 1;
    # 02/07/13: with the addition of PAB extensions, there may be
    # proteins in the duphash that are not in @indist_protIDs. More
    # specifically, duphash considers identity up to the asterisk,
    # but two prots suchly identical may be distinguishable due to PAB
    # peptide hits.
    #@identical_protIDs = keys(%{$duphash->{$primary_protID}});
    @identical_protIDs = ();
    for my $indist_protID (@indist_protIDs) {
      push(@identical_protIDs, $indist_protID)
	if defined $dup_href->{$primary_protID}->{$indist_protID};
    }
  #--------------------------------------------------
  #   print "Gathered identicals to primary ${primary_protID}.\n";
  #   for my $indist_protID (@identical_protIDs) {
  #     print "$indist_protID ";
  #   }
  #   print "\n";
  #-------------------------------------------------- 
    for my $ident_protID (@identical_protIDs) {
      print $relfh "$protein_group,$primary_protID,$ident_protID,identical\n";
      $processed_protIDs{$ident_protID} = 1;
    }
    # Now, partition remaining into sets of identicals, choose one from
    #  each set to mark as indistinguishable, and mark others as
    #  identical to that.
  #--------------------------------------------------
  #   print "About to gather identicals to remaining indistinguishables.\n";
  #-------------------------------------------------- 
    for my $protID (@indist_protIDs) {
      # Skip if we've already processed this one
      if (! defined $processed_protIDs{$protID}) {
	# Gather all protIDs identical to this one, including self
	#@identical_protIDs = keys(%{$duphash->{$protID}});
	@identical_protIDs = ($protID);
	for my $protID2 (@indist_protIDs) {
	  push(@identical_protIDs, $protID2)
	    if defined $dup_href->{$protID}->{$protID2};
	}
  #--------------------------------------------------
  #   print "Gathered identicals to ${protID}.\n";
  #   for my $protID (@identical_protIDs) {
  #     print "$protID ";
  #   }
  #   print "\n";
  #-------------------------------------------------- 
	# Find preferred protID among all identicals, including self
	$preferred_protID = 
    SBEAMS::PeptideAtlas::ProtInfo::get_preferred_protid_from_list(
	  protid_list_ref=>\@identical_protIDs,
	  preferred_patterns_aref => $preferred_patterns_aref,
	 );
	# Store preferred one as indistinguishable from primary
	print $relfh "$protein_group,$primary_protID,$preferred_protID,indistinguishable\n";
	# Note that we've processed the protIDs for the preferred one
	$processed_protIDs{$preferred_protID} = 1;
	# Store others as identical to preferred
	for my $protID2 (@identical_protIDs) {
	  if ( $protID2 ne $preferred_protID) {
	    print $relfh "$protein_group,$preferred_protID,$protID2,identical\n";
	    $processed_protIDs{$protID2} = 1;
	  }
	}
	# Count this indistinguishable in the tally for the group
	$group_size_href->{$protein_group}++;
      }
    }
    $count++;
    if ($count % 10000 == 0) {
      print $count;
    } elsif ($count % 1000 == 0) {
      print ".";
    }
  }
  print "\n" if $count >= 1000;
  close $infh;
  return $prot_idents_aref;
}


sub write_protIdentlist {
  my %args = @_;
  my $prot_idents_aref = $args{'prot_idents_aref'};
  my $identfh = $args{'identfh'};
  my $protein_group_number_idx = $args{'protein_group_number_idx'};
  my $group_size_href = $args{'group_size_href'};
  my $group_size_idx = $args{'group_size_idx'};

  my $count = 0;
  my $warning_count = 0;
  for my $prot_ident (@{$prot_idents_aref}) {
    my @fields = @{$prot_ident};
    # get protein group size and add it as another, final field
    my $protein_group = $fields[$protein_group_number_idx];
    my $group_size = $group_size_href->{$protein_group};
    if (! defined $group_size) {
      printf "WARNING: No value available to ouput for field $group_size_idx (group size), input file record %d.\n", $count+1 if $warning_count < 5;
      $warning_count++;
      print "=>Warning for group size turned off for remainder of processing.\n" if ($warning_count == 5);
      $group_size = '';
    }
    $fields[$group_size_idx] = $group_size;
    my $line = join(",",@fields);
    print $identfh "$line\n";
    $count++;
    if ($count % 10000 == 0) {
      print $count;
    } elsif ($count % 1000 == 0) {
      print ".";
    }
  }
  print "\n" if $count >= 1000;
  close ($identfh);
}
