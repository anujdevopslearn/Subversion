#!/usr/local/bin/perl -w
# PeptideAtlas protein information postprocessor.
# Called after createPipelineInput.pl and step02 (mapping) of pipeline.
# Takes as input a protlist file produced by createPipelineInput
#  and generates a protIdentlist and protRelationship file,
#  optionally choosing a preferred protID for each identification
# protlist consists of lines like this:
# 328,ENSP00000352019 IPI00552590,0.0000,0.1417,subsumed,ENSP000000009
# prot_group_id, list indisting protIDs, prob., conf., presence_level,
#   highest scoring canonical for prot_group

use strict;
use Getopt::Long;
#use XML::Xerces;
#use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../../perl";
#use lib "/regis/sbeams/lib";

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
 and generates two files,
 PeptideAtlasInput.PAprot{Identlist,Relationships},
 gathering additional identicals and optionally
 choosing a preferred protID for each identification.
Or, refreshes a PAidentlist file to preferred protIDs.
Options:
  --infile       default: PeptideAtlasInput.PAprotlist
  --dupfile      default: duplicate_groups.txt
  --preferred_protIDs  choose preferred protIDs for PeptideAtlasInput.PAprot*
       Generally not needed; createPipelineInput already selects preferred.
  --PAidentlist   optional PAidentlist file to process.
                 Changes protIDs to preferred ones.
  --help         print this usage guide
EOU


#### Process options
unless (GetOptions(\%OPTIONS,"infile:s", "dupfile:s", "help",
         "preferred_protIDs", "PAidentlist:s",
  )) {   print "$USAGE";
  exit;
}
if ($OPTIONS{help}) {
  print $USAGE;
  exit;
}

my $infile = $OPTIONS{infile} || "PeptideAtlasInput.PAprotlist";
my $dupfile = $OPTIONS{dupfile} || "duplicate_groups.txt";
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
    my $primary_protID = find_preferred_protid($protID, $dupfile);
    #  Substitute into line
    $fields[10] = $primary_protID;
    $line = join("\t",@fields);
    #  output line
    print PAOUTFILE "$line\n";
  }
  exit
}

#### Standard vanilla usage starts here.
#### Open files
open (INFILE, $infile) || die "Cannot open $infile for reading.\n";
my $identlistfile =  "PeptideAtlasInput.PAprotIdentlist";
open (IDENTFILE, ">$identlistfile") ||
   die "Cannot open $identlistfile for writing.\n";
print IDENTFILE
"protein_group_number,biosequence_name,probability,confidence,n_observations,n_distinct_peptides,level_name,represented_by_biosequence_name,subsumed_by_biosequence_name,estimated_ng_per_ml,abundance_uncertainty\n";

my $relationshipfile =  "PeptideAtlasInput.PAprotRelationships";
open (RELFILE, ">$relationshipfile") ||
   die "Cannot open $relationshipfile for writing.\n";
print RELFILE "protein_group_number,reference_biosequence_name,related_biosequence_name,relationship_name\n";

#### For each protein in this file, including indistinguishables,
####  hash to all identicals.
my $duphash = {};
my $line = <INFILE>;  #throw away header line
for $line (<INFILE>) {
  chomp ($line);
  my @fields = split(",", $line);
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
####  For each line in file (format is as follows:)
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
my $maxfields = 11;

my $firstline = 1;
for my $line (<INFILE>) {
  chomp ($line);
  my @fields = split(",", $line);
  if ($firstline) {
    if ($fields[0] =~ /protein_group/) {
      next;  #skip header line if any
    }
    $firstline = 0;
  }
  my $nfields = scalar (@fields);
  my $protein_group = $fields[0];
  my @protIDs = split(" ", $fields[1]);
  my $presence_level = $fields[4];
  my @subsumed_by_list = ();
  my $subsumed_by_protID;
  if ($nfields >= 9) {
    @subsumed_by_list = split(' ',$fields[8]);
    # arbitrarily select the first subsumed_by protID to store
    if (scalar @subsumed_by_list > 0 ) {
      $subsumed_by_protID = $subsumed_by_list[0];
    } else {
      $subsumed_by_protID = "";
    }
  }
  # n_obs field expects an int. but these days we're sometimes using
  # float. Force it to int. 09/18/09.
  $fields[4] = int $fields[4];
  if ($nfields > $maxfields) {
    print "WARNING: more than $maxfields fields in input line\n";
  }

  #### Choose preferred protID for primary and represented_by
  my $primary_protID;
  if ($preferred_protIDs) {
    $primary_protID = get_preferred_protid_from_list(\@protIDs);
    if ($nfields >=8 ) {
      $fields[7] = find_preferred_protid($fields[7], $dupfile);
    }
    if ( ( $nfields >= 9 ) && ( $subsumed_by_protID ne "" )) {
      $subsumed_by_protID =
	 find_preferred_protid($subsumed_by_protID, $dupfile);
    }
  } else {
    $primary_protID = $protIDs[0];
  }

# DEBUGGING
#  for my $protID (@protIDs) {
#    print "$protID "; #  }
#  print "==> $primary_protID\n";

  ####  Write to new protIdentlist file
  $fields[1] = $primary_protID;
  if ($nfields >= 9) {
    $fields[8] = $subsumed_by_protID;
  }
  $line = join(",",@fields);
  print IDENTFILE "$line\n";

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
      $preferred_protID = get_preferred_protid_from_list(\@identical_protIDs);
      # Store preferred one as indistinguishable from primary
      print RELFILE "$protein_group,$primary_protID,$preferred_protID,indistinguishable\n";
      $processed_protIDs{$preferred_protID} = 1;
      # Store others as identical to preferred
      for my $protID2 (@identical_protIDs) {
	if ( $protID2 ne $preferred_protID) {
	  print RELFILE "$protein_group,$preferred_protID,$protID2,identical\n";
	  $processed_protIDs{$protID2} = 1;
	}
      }
    }
  }
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
  my $protID = shift;
  my $dupfile = shift;

  #  Get all duplicate IDs
  my $dupIDs_aref = get_dupIDs($protID, $dupfile);
  my @dupIDs = @{$dupIDs_aref};
  #  Choose preferred one.
  my $primary_protID = $protID;
  if (scalar(@dupIDs) > 0) {
    $primary_protID = get_preferred_protid_from_list($dupIDs_aref);
  }
  return ($primary_protID);
}
