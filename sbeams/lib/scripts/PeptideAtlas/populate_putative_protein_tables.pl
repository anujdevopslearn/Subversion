#!/usr/local/bin/perl -w
# Populate tables to keep records on non-Swiss-Prot proteins
# that we think we have evidence for.
# Terry Farrah  February 2013


use strict;
$| = 1;  #disable output buffering

use vars qw ($q $sbeams $sbeamsMOD $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name);


#### Set up SBEAMS modules
use lib "/net/dblocal/www/html/devTF/sbeams/lib/perl";
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;


## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

#print "Authenticating!\n";

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ( $current_username = $sbeams->Authenticate(
    #connect_read_only=>1,
    allow_anonymous_access => 1,
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));

#print "Done authenticating!\n";

$current_contact_id = $sbeams->getCurrent_contact_id;
$current_work_group_id = $sbeams->getCurrent_work_group_id;
$current_work_group_name = $sbeams->getCurrent_work_group_name;

my $bss_id = 122;   #latest biosequence set as of February 2013
my $TESTONLY = 0;
my $VERBOSE = 0;

my $atlas_output_dir = "/net/db/projects/PeptideAtlas/pipeline/output";
my $atlas_build_dir = "HumanPublic_201301_PAB";

# We need a list of non-Swiss-Prot identifiers that we have evidence for
# Can be created thusly:
# (1) Using any method you wish, create a file named sprot.list that contains all identifiers, INCLUDING VARSPLIC, in the Swiss-Prot version of interest.
# Be sure to include varsplic! There should be about 37,000 identifiers in the file (one per line).
# (2) Create the covering list for the atlas build
# egrep '1,[0-9]{0,9},[0-9\.]{0,9}$' DATA_FILES/PeptideAtlasInput.PAprotIdentlist | awk 'BEGIN{FS=","}{print $2}' | sort | grep -v DECOY | grep -v UNMAPPED  >| PAprotlist_covering_protids
# (3) Take the difference between the two lists:
# comm -3 -2 PAprotlist_covering_protids DATA_FILES/sprot.list | grep -v "^......-." >| PAprotlist_covering_protids_not_Swiss
my $protein_file = "${atlas_output_dir}/${atlas_build_dir}/DATA_FILES/PAprotlist_covering_protids_not_Swiss";

# We need the entries from the peptide_mapping.tsv file that map to those identifiers but not to Swiss-Prot.
# Needs file peptides_mappable_to_swiss.tsv, created thusly:
# (1) awk 'BEGIN{FS="\t"}{print $2}' peptide_mapping_swiss.tsv | sort | uniq >| peptides_mappable_to_swiss.tsv
# (2) $SBEAMS/lib/scripts/PeptideAtlas/find_peps_not_in_swiss.pl > peptide_mapping_not_swiss.tsv # Must run in same directory as peptide_mapping.tsv and peptides_mappable_to_swiss.tsv
my $peptide_file = "${atlas_output_dir}/${atlas_build_dir}/DATA_FILES/peptide_mapping_not_swiss.tsv";

# open data files
open (my $protfh, $protein_file) || die "Can't open $protein_file";
open (my $pepfh, $peptide_file) || die "Can't open $peptide_file";

# for each biosequence name, get the biosequence_id and store in a hash
my $bioseq_href;
while (my $protid = <$protfh>) {
  chomp $protid;
  my $query = qq~
    SELECT bs.biosequence_id
    FROM $TBAT_BIOSEQUENCE BS
    WHERE BS.biosequence_name = '$protid'
    AND BS.biosequence_set_id = '$bss_id'
  ~;
  my ($bs_id) = $sbeams->selectOneColumn($query);
  if ( defined $bs_id) {
    $bioseq_href->{$protid}->{bs_id} = $bs_id;
    #print "$protid\t$bs_id\n";
  } else {
    print "ERROR: no biosequence found for $protid, bss $bss_id\n"
  }
}
close $protfh;

# for each peptide mapping, if the biosequence is in our list, hash to the peptide.
my $pepid_href;
while (my $line = <$pepfh>) {
  chomp $line;
  my ($acc, $pepseq, $protid, $start, $end) = split("\t", $line);
  if (defined $bioseq_href->{$protid}) {
    $bioseq_href->{$protid}->{peps}->{$acc} = $pepseq;
    #print "$protid\t$acc\t$pepseq\n";
    # get the peptide_id using the peptide_accession
    my $query = qq~
      SELECT p.peptide_id
      FROM $TBAT_PEPTIDE P
      WHERE P.peptide_accession = '$acc'
    ~;
    my ($peptide_id) = $sbeams->selectOneColumn($query);
    if ( defined $peptide_id) {
      $pepid_href->{$acc} = $peptide_id;
      #print "$acc\t$peptide_id\n";
    } else {
      print "ERROR: no peptide record found for $acc\n"
    }
  }
}

# for each protein, create a putative_protein record
#  and a putative_protein_peptide record for each of its
#  mapped peptides.
for my $protid (keys %{$bioseq_href}) {

  my $rowdata_href = {
    biosequence_id => $bioseq_href->{$protid}->{bs_id},
    added_to_nextprot => 'N',
  };
  my $putative_protein_id = $sbeams->updateOrInsertRow(
    insert => 1,
    table_name => $TBAT_PUTATIVE_PROTEIN,
    rowdata_ref => $rowdata_href,
    PK => 'putative_protein_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );
  $bioseq_href->{$protid}->{putative_protein_id} = $putative_protein_id;
  #print "$putative_protein_id\n";

  for my $acc (keys %{$bioseq_href->{$protid}->{peps}}) {
    my $peptide_id = $pepid_href->{$acc};
    my $rowdata_href = {
      putative_protein_id => $putative_protein_id,
      peptide_id => $peptide_id,
    };
    $sbeams->updateOrInsertRow(
      insert => 1,
      table_name => $TBAT_PUTATIVE_PROTEIN_PEPTIDE,
      rowdata_ref => $rowdata_href,
      PK => 'putative_protein_peptide_id',
      return_PK => 1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );
  }
}

# for each peptide, create a putative_peptide record
for my $acc (keys %{$pepid_href}) {
  my $peptide_id = $pepid_href->{$acc};
  #print "$peptide_id\n";
  my $rowdata_href = {
    peptide_id => $peptide_id,
    added_to_nextprot => 'N',
  };
  $sbeams->updateOrInsertRow(
    insert => 1,
    table_name => $TBAT_PUTATIVE_PEPTIDE,
    rowdata_ref => $rowdata_href,
    PK => 'putative_peptide_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );
}

# We are done!
