package SBEAMS::PeptideAtlas::KeySearch;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::KeySearch
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::KeySearch

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::KeySearch

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
smart searching the database by keywords.

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
use SBEAMS::PeptideAtlas::Tables;


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
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
# rebuildKeyIndex
###############################################################################
sub rebuildKeyIndex {
  my $METHOD = 'rebuildKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Set verbosity level if provided or not yet set
  my $verbose = $args{verbose};
  if ($verbose) {
    $VERBOSE = $verbose;
  } elsif ($VERBOSE) {
  } else {
    $VERBOSE = 0;
  }

  #### Set testonly flag if provided or not yet set
  my $testonly = $args{testonly};
  if ($testonly) {
    $TESTONLY = $testonly;
  } elsif ($TESTONLY) {
  } else {
    $TESTONLY = 0;
  }

  print "INFO[$METHOD]: Rebuilding key index..." if ($VERBOSE);

  #### Retreive parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $organism_name = $args{organism_name}
    or die("ERROR[$METHOD]: Parameter organism_name not passed");

  my $organism_id = $sbeams->get_organism_id( organism => $organism_name );
    die( "Unable to find organism ID for $organism_name" ) if !$organism_id;

  my $organism_specialized_build = $args{organism_specialized_build};

  if ($organism_name =~ /^Human$|^Mouse$/i ) {

    my $GOA_directory = $args{GOA_directory}
      or die("ERROR[$METHOD]: Parameter GOA_directory not passed");

    $self->dropKeyIndex(
      atlas_build_id => $atlas_build_id,
      organism_specialized_build => $organism_specialized_build,
    );

    print "Loading protein keys from GOA...\n";
    $self->buildGoaKeyIndex(
      GOA_directory => $GOA_directory,
      organism_name => lc($organism_name), 
      organism_id => $organism_id, 
      atlas_build_id => $atlas_build_id,
    );

    print "Loading peptides keys...\n";
    $self->buildPeptideKeyIndex(
      organism_id => $organism_id,
      atlas_build_id => $atlas_build_id,
    );

    print "\n";

  }


  if ($organism_name eq 'Yeast') {

    my $SGD_directory = $args{SGD_directory}
      or die("ERROR[$METHOD]: Parameter SGD_directory not passed");

    $self->dropKeyIndex(
      atlas_build_id => $atlas_build_id,
      organism_specialized_build => $organism_specialized_build,
    );

    print "Loading protein keys from SGD_features.tab...\n";
    $self->buildSGDKeyIndex(
      SGD_directory => $SGD_directory,
      atlas_build_id => $atlas_build_id,
    );

    print "Loading peptides keys...\n";
    $self->buildPeptideKeyIndex(
      organism_id=>$organism_id,
      atlas_build_id=>$atlas_build_id,
    );

    print "\n";

  }


  #my $sql = "CREATE NONCLUSTERED INDEX idx_search_key_name ON $TBAT_SEARCH_KEY ( search_key_name )";
  #$sbeams->executeSQL($sql);

  return(1);

} # end rebuildKeyIndex



###############################################################################
# dropKeyIndex: Drop all existing search keys in the search_key table
###############################################################################
sub dropKeyIndex {
  my $METHOD = 'dropKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  print "INFO[$METHOD] Dropping key index for atlas_build_id=$atlas_build_id...\n"
    if ($VERBOSE);

  unless ($sbeams) {
    die("ERROR[$METHOD]: sbeams object is not defined. Use setSBEAMS() method");
  }

  #my $sql = "DROP INDEX $TBAT_SEARCH_KEY.idx_search_key_name";
  #$sbeams->executeSQL($sql);

  my $sql = "DELETE FROM $TBAT_SEARCH_KEY WHERE atlas_build_id = '$atlas_build_id'";
  $sbeams->executeSQL($sql);

  return(1);

} # end dropKeyIndex



###############################################################################
# buildGoaKeyIndex
###############################################################################
sub buildGoaKeyIndex {
  my $METHOD = 'buildGoaKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  print "INFO[$METHOD]: Building GOA key index...\n" if ($VERBOSE);

  my $GOA_directory = $args{GOA_directory}
    or die("ERROR[$METHOD]: Parameter GOA_directory not passed");

  unless (-d $GOA_directory) {
    die("ERROR[$METHOD]: '$GOA_directory' is not a directory");
  }

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $organism_name = $args{organism_name}
    or die("ERROR[$METHOD]: Parameter organism_name not passed");

  # Use passed organism ID if available, else use lookup.
  my $organism_id = $args{organism_id} || 
                    $sbeams->get_organism_id( organism => $args{organism_name} ) ||
    die("ERROR[$METHOD]: Unable to determine organism_id for $args{organism_name}");

  #### Open the provided GOA xrefs file
  my $GOA_file = "$GOA_directory/${organism_name}.xrefs";
  open(INFILE,$GOA_file)
    or die("ERROR[$METHOD]: Unable to open file '$GOA_file'");

  #### Read the GOA gene_associations file
  my $associations = $self->readGOAAssociations(
    assocations_file => "$GOA_directory/gene_association.goa_${organism_name}",
  );

  #### Get the list of proteins that have a match
  my $matched_proteins = $self->getNProteinHits(
    organism_id => $args{organism_id},
    atlas_build_id => $atlas_build_id,
  );

  #### Read all the data
  my $line;
  my $counter = 0;

  while ($line=<INFILE>) {
    chomp($line);
    my ($Database,$Accession,$IPI,$UniProtSP,$UniProtTR,$Ensembl,$RefSeqNP,
        $RefSeqXP,$Hinv,$proteins,$HGNCgenew,$EntrezGene,$UNIPARC,
	$UniGene) = split(/\t/,$line);

    if (0) {
      print "-------------------------------------------------\n";
      print "Database=$Database\n";
      print "Accession=$Accession\n";
      print "IPI=$IPI\n";
      print "UniProtSP=$UniProtSP\n";
      print "UniProtTR=$UniProtTR\n";
      print "Ensembl=$Ensembl\n";
      print "RefSeqNP=$RefSeqNP\n";
      print "RefSeqXP=$RefSeqXP\n";
      print "Hinv=$Hinv\n";
      print "proteins=$proteins\n";
      print "HGNCgenew=$HGNCgenew\n";
      print "EntrezGene=$EntrezGene\n";
      print "UNIPARC=$UNIPARC\n";
      print "UniGene=$UniGene\n";
    }


    #### Skip if we don't have an ENSP number
    unless ($Ensembl) {
      #print "WARNING[$METHOD]: No ENSP for $Database:$Accession. Ignoring..\n";
      next;
    }

    #### Split the Ensembl ID's
    my @Ensembl_IDS = splitEntities(list=>$Ensembl,delimiter=>';');
    my $n_Ensembl_IDS = scalar(@Ensembl_IDS);

    if ($n_Ensembl_IDS == 0) {
      print "WARNING[$METHOD]: No valid ENSP for $Database:$Accession. Ignoring..\n" if ($VERBOSE > 1);
      next;
    }


    #### Build a list of protein links
    my @links;

    if ($Database and $Accession) {
      $Database = 'UniProt' if ($Database eq 'SP');
      my @tmp = ($Database,$Accession,40);
      push(@links,\@tmp);
    }

    if ($IPI) {
      my @list = splitEntities(list=>$IPI,delimiter=>';');
      foreach my $item ( @list ) {
        my @tmp = ('IPI',$item,9);
        push(@links,\@tmp);
      }
    }

    if ($UniProtTR) {
      my @list = splitEntities(list=>$UniProtTR);
      foreach my $item ( @list ) {
        my @tmp = ('UniProt/TrEMBL',$item,35);
        push(@links,\@tmp);
      }
    }

    if ($RefSeqNP) {
      my @list = splitEntities(list=>$RefSeqNP,delimiter=>';');
      foreach my $item ( @list ) {
	$item =~ s/^\w://;
        my @tmp = ('RefSeq',$item,39);
        push(@links,\@tmp);
      }
    }

    if ($RefSeqXP) {
      my @list = splitEntities(list=>$RefSeqXP,delimiter=>';');
      foreach my $item ( @list ) {
	$item =~ s/^\w://;
        my @tmp = ('RefSeq',$item,39);
        push(@links,\@tmp);
      }
    }

    if ($EntrezGene) {
      my @list = splitEntities(list=>$EntrezGene,delimiter=>';');
      foreach my $item ( @list ) {
        my @pair = split(/,/,$item);
        my @tmp = ('Entrez GeneID',$pair[0],37);
        push(@links,\@tmp);
        my @tmp2 = ('Entrez Gene Symbol',$pair[1],38);
        push(@links,\@tmp2);
      }
    }

    if ($UniGene) {
      my @list = splitEntities(list=>$UniGene,delimiter=>';');
      foreach my $item ( @list ) {
        my @tmp = ('UniGene',$item);
        push(@links,\@tmp);
      }
    }


    my $handle = "$Database:$Accession";
    if ($associations->{$handle}) {
      if ($associations->{$handle}->{Symbol}) {
        my @tmp = ('UniProt Symbol',$associations->{$handle}->{Symbol},35);
        push(@links,\@tmp);
      }
      if ($associations->{$handle}->{DB_Object_Name}) {
        my @tmp = ('Full Name',$associations->{$handle}->{DB_Object_Name});
        push(@links,\@tmp);
      }
    }


    #### Write the links for each Ensembl IP
    foreach my $Ensembl_ID (@Ensembl_IDS) {

      #### Strip HAVANA prefix
      $Ensembl_ID =~ s/HAVANA://;

      #### Insert an entry for the Ensembl ID itself
      my %rowdata = (
        search_key_name => $Ensembl_ID,
        search_key_type => 'Ensembl Protein',
        search_key_dbxref_id => 20,
        organism_id => 2,
        atlas_build_id => $atlas_build_id,
        resource_name => $Ensembl_ID,
        resource_type => 'Ensembl Protein',
        resource_url => "GetProtein?atlas_build_id=$atlas_build_id&protein_name=$Ensembl_ID&action=QUERY",
        resource_n_matches => $matched_proteins->{$Ensembl_ID},
      );
      $sbeams->updateOrInsertRow(
        insert => 1,
        table_name => "$TBAT_SEARCH_KEY",
        rowdata_ref => \%rowdata,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
      );

      foreach my $link (@links) {
        #print "    ".join("=",@{$link})."\n";
        my %rowdata = (
          search_key_name => $link->[1],
	  search_key_type => $link->[0],
	  search_key_dbxref_id => $link->[2],
          organism_id => 2,
          atlas_build_id => $atlas_build_id,
	  resource_name => $Ensembl_ID,
	  resource_type => 'Ensembl Protein',
	  resource_url => "GetProtein?atlas_build_id=$atlas_build_id&protein_name=$Ensembl_ID&action=QUERY",
          resource_n_matches => $matched_proteins->{$Ensembl_ID},
        );
        $sbeams->updateOrInsertRow(
          insert => 1,
          table_name => "$TBAT_SEARCH_KEY",
          rowdata_ref => \%rowdata,
          verbose=>$VERBOSE,
          testonly=>$TESTONLY,
        );
      }
    }

    $counter++;
    print "$counter... " if ($counter/100 eq int($counter/100));

    #my $xx=<STDIN>;

  } # endwhile ($line=<INFILE>)

    close(INFILE);

} # end buildGoaKeyIndex



###############################################################################
# readGOAAssociations
###############################################################################
sub readGOAAssociations {
  my $METHOD = 'readGOAAssociations';
  my $self = shift || die ("self not passed");
  my %args = @_;

  print "INFO[$METHOD]: Reading GOA assocations file...\n" if ($VERBOSE);

  my $assocations_file = $args{assocations_file}
    or die("ERROR[$METHOD]: Parameter assocations_file not passed");

  #### Open the provided GOA xrefs file
  open(ASSOCINFILE,$assocations_file)
    or die("ERROR[$METHOD]: Unable to open file 'assocations_file'");

  #### Read all the data
  my $line;
  my %associations;

  while ($line=<ASSOCINFILE>) {
    chomp($line);
    my ($Database,$Accession,$Symbol,$Qualifier,$GOid,$Reference,$Evidence,
        $With,$Aspect,$DB_Object_Name,$Synonym,$DB_Object_Type,
        ) = split(/\t/,$line);

    if (0) {
      print "-------------------------------------------------\n";
      print "Database=$Database\n";
      print "Accession=$Accession\n";
      print "Symbol=$Symbol\n";
      print "Qualifier=$Qualifier\n";
      print "GOid=$GOid\n";
      print "Reference=$Reference\n";
      print "Evidence=$Evidence\n";
      print "With=$With\n";
      print "Aspect=$Aspect\n";
      print "Synonym=$Synonym\n";
      print "DB_Object_Name=$DB_Object_Name\n";
    }

    $associations{"$Database:$Accession"}->{Symbol} = $Symbol;
    $associations{"$Database:$Accession"}->{DB_Object_Name} = $DB_Object_Name;

  } # endwhile ($line=<ASSOCINFILE>)

  close(ASSOCINFILE);
  return(\%associations);

} # end readGOAAssociations



###############################################################################
# buildSGDKeyIndex
###############################################################################
sub buildSGDKeyIndex {
  my $METHOD = 'buildSGDKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  print "INFO[$METHOD]: Building SGD key index...\n" if ($VERBOSE);

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $SGD_directory = $args{SGD_directory}
    or die("ERROR[$METHOD]: Parameter SGD_directory not passed");

  unless (-d $SGD_directory) {
    die("ERROR[$METHOD]: '$SGD_directory' is not a directory");
  }

  #### Open the provided SGD_features.tab file
  my $SGD_file = "$SGD_directory/SGD_features.tab";
  open(INFILE,$SGD_file)
    or die("ERROR[$METHOD]: Unable to open file '$SGD_file'");


  #### Get the list of proteins that have a match
  my $matched_proteins = $self->getNProteinHits(
    organism_id=>3,
    atlas_build_id=>$atlas_build_id,
  );


  #### Read all the data
  my $line;
  my $counter = 0;

  while ($line=<INFILE>) {
    chomp($line);
    my ($SGDID,$feature_type,$feature_qualifier,$feature_name,$gene_name,
        $aliases,$chromosome_string,$chr_junk,$chromosome,
	$chr_start,$chr_end,$strand,
        $gene_pos,$seq_version,$unknown_version,$description,
       ) = split(/\t/,$line);

    #### Skip if this isn't an ORF
    unless ($feature_type eq 'ORF') {
      next;
    }

    if (0) {
      print "-------------------------------------------------\n";
      print "SGDID=$SGDID\n";
      print "feature_type=$feature_type\n";
      print "feature_qualifier=$feature_qualifier\n";
      print "feature_name=$feature_name\n";
      print "gene_name=$gene_name\n";
      print "chromosome_string=$chromosome_string\n";
      print "chr_junk=$chr_junk\n";
      print "chromosome=$chromosome\n";
      print "chr_start=$chr_start\n";
      print "chr_end=$chr_end\n";
      print "strand=$strand\n";
      print "gene_pos=$gene_pos\n";
      print "seq_version=$seq_version\n";
      print "unknown_version=$unknown_version\n";
      print "description=$description\n";
    }


    #### Skip if we don't have a feature_name
    unless ($feature_name) {
      print "WARNING: No feature_name for SGDID $SGDID. Skipping...\n";
      next;
    }

    #### Build a list of protein links
    my @links;

    if ($SGDID) {
      my @tmp = ('SGD ID',$SGDID);
      push(@links,\@tmp);
    }

    if ($feature_qualifier) {
      my @tmp = ('ORF qualifier',$feature_qualifier);
      push(@links,\@tmp);
    }

    if ($feature_name) {
      my @tmp = ('ORF name',$feature_name);
      push(@links,\@tmp);
    }

    if ($gene_name) {
      my @tmp = ('Gene name',$gene_name);
      push(@links,\@tmp);
    }

    if ($aliases) {
      my @list = splitEntities(list=>$aliases,delimiter=>'\|');
      foreach my $item ( @list ) {
        my @tmp = ('Alias',$item);
        push(@links,\@tmp);
      }
    }

    if ($description) {
      my @tmp = ('Description',$description);
      push(@links,\@tmp);
    }


    foreach my $link (@links) {
      #print "    ".join("=",@{$link})."\n";
      my %rowdata = (
        search_key_name => $link->[1],
        search_key_type => $link->[0],
        search_key_dbxref_id => $link->[2],
        organism_id => 3,
        atlas_build_id => $atlas_build_id,
        resource_name => $feature_name,
        resource_type => 'Yeast ORF Name',
        resource_url => "GetProtein?atlas_build_id=$atlas_build_id&protein_name=$feature_name&action=QUERY",
        resource_n_matches => $matched_proteins->{$feature_name},
      );
      $sbeams->updateOrInsertRow(
        insert => 1,
        table_name => "$TBAT_SEARCH_KEY",
        rowdata_ref => \%rowdata,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
      );
    }


    $counter++;
    print "$counter... " if ($counter/100 eq int($counter/100));

    my $xx=<STDIN> if (0);

  } # endwhile ($line=<INFILE>)

  print "\n";
  close(INFILE);

} # end buildGoaKeyIndex



###############################################################################
# splitEntities: Split a semi-colon separated list of items into an array
###############################################################################
sub splitEntities {
  my $SUB = 'splitEntities';
  my %args = @_;

  my $list = $args{list};
  my $delimiter = $args{delimiter} || ';';

  my @tmp_IDS = split(/$delimiter/,$list);
  my @IDS;
  foreach my $ID ( @tmp_IDS ) {
    next if ($ID =~ /^\s*$/);
    push(@IDS,$ID);
  }

  return(@IDS);

} # end splitEntities



###############################################################################
# buildPeptideKeyIndex
###############################################################################
sub buildPeptideKeyIndex {
  my $METHOD = 'buildPeptideKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $organism_id = $args{organism_id}
    or die("ERROR[$METHOD]: Parameter organism_id not passed");

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  print "INFO[$METHOD]: Building Peptide key index...\n" if ($VERBOSE);

  #### Get all the peptides for this build
  my $sql = qq~
       SELECT peptide_accession,peptide_sequence,n_observations
         FROM $TBAT_PEPTIDE P
         JOIN $TBAT_PEPTIDE_INSTANCE PI ON (P.peptide_id = PI.peptide_id)
        WHERE PI.atlas_build_id = '$atlas_build_id'
  ~;
  my @peptides = $sbeams->selectSeveralColumns($sql);

  my $counter = 0;

  #### Loop over each one, inserting records for both the accession numbers
  #### and the sequences
  foreach my $peptide ( @peptides ) {

    #### Register an entry for the PAp accession number
    my %rowdata = (
      search_key_name => $peptide->[0],
      search_key_type => 'PeptideAtlas',
      organism_id => $organism_id,
      atlas_build_id => $atlas_build_id,
      resource_name => $peptide->[0],
      resource_type => 'PeptideAtlas peptide',
      resource_url => "GetPeptide?atlas_build_id=$atlas_build_id&searchWithinThis=Peptide+Name&searchForThis=$peptide->[0]&action=QUERY",
      resource_n_matches => $peptide->[2],
    );
    $sbeams->updateOrInsertRow(
      insert => 1,
      table_name => "$TBAT_SEARCH_KEY",
      rowdata_ref => \%rowdata,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

    #### Register an entry for the peptide sequence
    my %rowdata = (
      search_key_name => $peptide->[1],
      search_key_type => 'peptide sequence',
      organism_id => $organism_id,
      atlas_build_id => $atlas_build_id,
      resource_name => $peptide->[0],
      resource_type => 'PeptideAtlas peptide',
      resource_url => "GetPeptide?atlas_build_id=$atlas_build_id&searchWithinThis=Peptide+Name&searchForThis=$peptide->[0]&action=QUERY",
      resource_n_matches => $peptide->[2],
    );
    $sbeams->updateOrInsertRow(
      insert => 1,
      table_name => "$TBAT_SEARCH_KEY",
      rowdata_ref => \%rowdata,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );

    $counter++;
    print "$counter... " if ($counter/100 eq int($counter/100));

  }

  return(1);

} # end buildPeptideKeyIndex



###############################################################################
# getNProteinHits
###############################################################################
sub getNProteinHits {
  my $METHOD = 'getNProteinHits';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $organism_id = $args{organism_id}
    or die("ERROR[$METHOD]: Parameter organism_id not passed");

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  #### Get all the peptides in the database, regardless of build
  my $sql = qq~
       SELECT biosequence_name,SUM(n_observations) AS N_obs
         FROM $TBAT_PEPTIDE_INSTANCE PI
         JOIN $TBAT_ATLAS_BUILD AB ON (AB.atlas_build_id = PI.atlas_build_id)
         JOIN $TBAT_PEPTIDE_MAPPING PIM
              ON (PIM.peptide_instance_id = PI.peptide_instance_id)
         JOIN $TBAT_BIOSEQUENCE B
              ON (B.biosequence_id = PIM.matched_biosequence_id)
        WHERE AB.atlas_build_id = '$atlas_build_id'
        GROUP BY biosequence_name
  ~;
  my %proteins = $sbeams->selectTwoColumnHash($sql);

  return(\%proteins);

} # end getNProteinHits



###############################################################################
# getProteinSynonyms
###############################################################################
sub getProteinSynonyms {
  my $METHOD = 'getProteinSynonyms';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $resource_name = $args{resource_name} || return;


  #### Get all the peptides in the database, regardless of build
  my $sql = qq~
       SELECT DISTINCT search_key_name,search_key_type,accessor,accessor_suffix
         FROM $TBAT_SEARCH_KEY SK
         LEFT JOIN $TB_DBXREF D
              ON ( SK.search_key_dbxref_id = D.dbxref_id )
        WHERE resource_name = '$resource_name'
        ORDER BY search_key_type,search_key_name
  ~;
  my @synonyms = $sbeams->selectSeveralColumns($sql);

  return @synonyms;

} # end getProteinSynonyms


sub checkAtlasBuild {
  my $self = shift;
  my %args = @_;
  die "Missing required argument build_id" if !$args{build_id};
  
  my $sbeams = $self->getSBEAMS();
  print "sbeams is $sbeams";
  my ($cnt) = $sbeams->selectrow_array( <<"  END" );
  SELECT COUNT(*) 
  FROM $TBAT_ATLAS_BUILD 
  WHERE atlas_build_id = $args{build_id}
  AND record_status = 'N'
  END
  return $cnt;
}



###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Eric W. Deutsch (edeutsch@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
