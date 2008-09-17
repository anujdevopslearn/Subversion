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

  my $organism_id = $sbeams->get_organism_id( organism => $organism_name )
    or die( "ERROR[$METHOD] Unable to find organism ID for $organism_name" );

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


  if ($organism_name eq 'Halobacterium') {

    my $reference_directory = $args{reference_directory}
      or die("ERROR[$METHOD]: Parameter reference_directory not passed");

    $self->dropKeyIndex(
      atlas_build_id => $atlas_build_id,
      organism_specialized_build => $organism_specialized_build,
    );

    print "Loading protein keys from SBEAMS and reference files...\n";
    $self->buildHalobacteriumKeyIndex(
      reference_directory => $reference_directory,
      atlas_build_id => $atlas_build_id,
    );

    print "Loading peptides keys...\n";
    $self->buildPeptideKeyIndex(
      organism_id=>$organism_id,
      atlas_build_id=>$atlas_build_id,
    );

    print "\n";

  }


  if ($organism_name eq 'Streptococcus') {

    my $reference_directory = $args{reference_directory}
      or die("ERROR[$METHOD]: Parameter reference_directory not passed");

    $self->dropKeyIndex(
      atlas_build_id => $atlas_build_id,
      organism_specialized_build => $organism_specialized_build,
    );

    print "Loading protein keys from SBEAMS and reference files...\n";
    $self->buildStreptococcusKeyIndex(
      reference_directory => $reference_directory,
      atlas_build_id => $atlas_build_id,
    );

    print "Loading peptides keys...\n";
    $self->buildPeptideKeyIndex(
      organism_id=>$organism_id,
      atlas_build_id=>$atlas_build_id,
    );

    print "\n";

  }


  if ($organism_name eq 'Leptospira interrogans') {

    my $reference_directory = $args{reference_directory}
      or die("ERROR[$METHOD]: Parameter reference_directory not passed");

    $self->dropKeyIndex(
      atlas_build_id => $atlas_build_id,
      organism_specialized_build => $organism_specialized_build,
    );

    print "Loading protein keys from SBEAMS and reference files...\n";
    $self->buildLeptospiraKeyIndex(
      reference_directory => $reference_directory,
      atlas_build_id => $atlas_build_id,
    );

    print "Loading peptides keys...\n";
    $self->buildPeptideKeyIndex(
      organism_id=>$organism_id,
      atlas_build_id=>$atlas_build_id,
    );

    print "\n";

  }



  if ($organism_name eq 'Drosophila') {

    my $reference_directory = $args{reference_directory}
      or die("ERROR[$METHOD]: Parameter reference_directory not passed");

    $self->dropKeyIndex(
      atlas_build_id => $atlas_build_id,
      organism_specialized_build => $organism_specialized_build,
    );

    print "Loading protein keys from SBEAMS and reference files...\n";
    $self->buildDrosophilaKeyIndex(
      reference_directory => $reference_directory,
      atlas_build_id => $atlas_build_id,
    );

    print "Loading peptides keys...\n";
    $self->buildPeptideKeyIndex(
      organism_id=>$organism_id,
      atlas_build_id=>$atlas_build_id,
    );

    print "\n";

  }


  if ($organism_name eq 'Pig') {

    my $reference_directory = $args{reference_directory}
      or die("ERROR[$METHOD]: Parameter reference_directory not passed");

    $self->dropKeyIndex(
      atlas_build_id => $atlas_build_id,
      organism_specialized_build => $organism_specialized_build,
    );

    print "Loading protein keys from SBEAMS and reference files...\n";
    $self->buildPigKeyIndex(
      reference_directory => $reference_directory,
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
  #my $GOA_file = "$GOA_directory/${organism_name}.xrefs";
  my $GOA_file = "$GOA_directory/ipi.".uc($organism_name).".xrefs";
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

    #### The database entry itself may be one of the other types in
    #### which case it's not repeated later, so map the initial
    #### entries to something else
    if ($Database && $Accession) {
      if ($Database =~ /ENSEMBL/) {
	$Ensembl = $Accession;
      } elsif ($Database =~ /REFSEQ/) {
	$RefSeqNP = $Accession;
      }
    }


    #### Skip if we don't have an ENSP number
    unless ($Ensembl) {
      #print "WARNING[$METHOD]: No ENSP for $Database:$Accession. Ignoring..\n";
      #next;
      $Ensembl = '';
    }

    #### Split the Ensembl ID's
    my @Ensembl_IDS = splitEntities(list=>$Ensembl,delimiter=>';');
    my $n_Ensembl_IDS = scalar(@Ensembl_IDS);

    if ($n_Ensembl_IDS == 0) {
      #print "WARNING[$METHOD]: No valid ENSP for $Database:$Accession. Ignoring..\n" if ($VERBOSE > 1);
      #next;
      @Ensembl_IDS = ( 'NO_ENSP' );
      $n_Ensembl_IDS = scalar(@Ensembl_IDS);
    }


    #### Build a list of protein links
    my @links;

    if ($Database and $Accession) {
      $Database = 'UniProt' if ($Database eq 'SP');
      $Database = 'TrEMBL' if ($Database eq 'TR');
      my @tmp = ($Database,$Accession,40);
      push(@links,\@tmp) unless ($Database =~ /ENSEMBL/);
    }

    if ($IPI) {
      my @list = splitEntities(list=>$IPI,delimiter=>';');
      foreach my $item ( @list ) {
        my @tmp = ('IPI',$item,9);
        push(@links,\@tmp);
      }
      #### If there was no Ensembl ID, then replace with IPI IDs if any
      if ($Ensembl_IDS[0] eq 'NO_ENSP') {
	@Ensembl_IDS = @list;
	$n_Ensembl_IDS = scalar(@Ensembl_IDS);
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
	$item =~ s/^\w+://;
        my @tmp = ('RefSeq',$item,39);
        push(@links,\@tmp);
      }
    }

    if ($RefSeqXP) {
      my @list = splitEntities(list=>$RefSeqXP,delimiter=>';');
      foreach my $item ( @list ) {
	$item =~ s/^\w+://;
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
      if ($associations->{$handle}->{Symbol} &&
        $associations->{$handle}->{Symbol} ne $Accession) {
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
        organism_id => $organism_id,
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
          organism_id => $organism_id,
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


  #### Read the contents of the UniProtKB mapping file
  my $UP_file = "$SGD_directory/UniProtKB_identifiers_from_AlainGateau.txt";
  my %UniProtAccessions;
  open(INFILE,$UP_file)
    or die("ERROR[$METHOD]: Unable to open file '$UP_file'");
  while (my $line = <INFILE>) {
    chomp($line);
    next if ($line =~ /^\s*$/);
    if ($line =~ /^(\S+)\sDR\s+PeptideAtlas;\s([\w\d\-]+);/) {
      $UniProtAccessions{$2} = $1;
    } else {
      print "ERROR: Unable to parse line '$line'\n";
    }
  }
  close(INFILE);


  #### Open the provided SGD_features.tab file
  my $SGD_file = "$SGD_directory/SGD_features.tab";
  open(INFILE,$SGD_file)
    or die("ERROR[$METHOD]: Unable to open file '$SGD_file'");

  my $organism_id = 3;

  #### Get the list of proteins that have a match
  my $matched_proteins = $self->getNProteinHits(
    organism_id=>$organism_id,
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

    if ($UniProtAccessions{$feature_name}) {
      my @tmp = ('UniProtKB',$UniProtAccessions{$feature_name});
      push(@links,\@tmp);
      print "UniProtKB: $feature_name=$UniProtAccessions{$feature_name}\n";
    } else {
      print "UniProtKB: $feature_name not found\n";
    }


    foreach my $link (@links) {
      #print "    ".join("=",@{$link})."\n";
      my %rowdata = (
        search_key_name => $link->[1],
        search_key_type => $link->[0],
        search_key_dbxref_id => $link->[2],
        organism_id => $organism_id,
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
# buildHalobacteriumKeyIndex
###############################################################################
sub buildHalobacteriumKeyIndex {
  my $METHOD = 'buildHalobacteriumKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  print "INFO[$METHOD]: Building Halobacterium key index...\n" if ($VERBOSE);

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $reference_directory = $args{reference_directory}
    or die("ERROR[$METHOD]: Parameter reference_directory not passed");

  unless (-d $reference_directory) {
    die("ERROR[$METHOD]: '$reference_directory' is not a directory");
  }

  my $organism_id = 4;

  #### Load the ancient ORF names and create a lookup table
  my $reference_file = "$reference_directory/ORFmatches-edited.txt";
  my %oldORFnames;
  open(INFILE,$reference_file)
    or die("ERROR[$METHOD]: Unable to open file '$reference_file'");
  while (my $line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my ($ORFname,$VNGname) = split("\t",$line);
    if ($VNGname) {
      $oldORFnames{$VNGname} = $ORFname;
    }
  }
  close(INFILE);


  #### Get the list of proteins that have a match
  my $matched_proteins = $self->getNProteinHits(
    organism_id=>$organism_id,
    atlas_build_id=>$atlas_build_id,
  );


  #### Fetch the latest data from SBEAMS
  use SBEAMS::Client;
  my $remote_sbeams = new SBEAMS::Client;
  my $server_uri = "https://db.systemsbiology.net/sbeams";


  #### Define the desired command and parameters
  my $server_command = "ProteinStructure/BrowseBioSequence.cgi";
  my $command_parameters = {
    biosequence_set_id => 5,
    #biosequence_gene_name_constraint => "bo%", for testing
    display_options => "limit_sequence_width",
    SBEAMSentrycode => "DF45jasj23jh",
  };


  #### Fetch the desired data from the SBEAMS server
  my $resultset = $remote_sbeams->fetch_data(
    server_uri => $server_uri,
    server_command => $server_command,
    command_parameters => $command_parameters,
  );

  #### Stop if the fetch was not a success
  unless ($resultset->{is_success}) {
    print "ERROR: Unable to fetch data.\n\n";
    exit;
  }
  unless ($resultset->{data_ref}) {
    print "ERROR: Unable to parse data result.  See raw_response.\n\n";
    exit;
  }

  #### Find the indexes of the columns of interest
  my @columns_names = qw ( biosequence_name biosequence_gene_name
    biosequence_accession aliases functional_description );
  my %idx;
  foreach my $column_name ( @columns_names ) {
    my $offset = $resultset->{column_hash_ref}->{$column_name};
    if ($offset gt '') {
      $idx{$column_name} = $offset;
    } else {
      die("ERROR: Unable to find column $column_name");
    }
  }

  #### Loop over all input rows processing information
  my $counter = 0;
  foreach my $row (@{$resultset->{data_ref}}) {

    my $biosequence_name = $row->[$idx{biosequence_name}];
    next unless ($biosequence_name);

    #### Build a list of protein links
    my @links;

    if ($biosequence_name) {
      my @tmp = ('ORF Name',$biosequence_name);
      push(@links,\@tmp);
    }

    my $biosequence_gene_name = $row->[$idx{biosequence_gene_name}];
    if ($biosequence_gene_name &&
      $biosequence_gene_name ne $biosequence_name) {
      my @tmp = ('Common Name',$biosequence_gene_name);
      push(@links,\@tmp);
    }

    my $biosequence_accession = $row->[$idx{biosequence_accession}];
    if ($biosequence_accession) {
      my @tmp = ('Gene ID',$biosequence_accession);
      push(@links,\@tmp);
    }

    my $functional_description = $row->[$idx{functional_description}];
    if ($functional_description) {
      my @tmp = ('Functional Description',$functional_description);
      push(@links,\@tmp);
    }

    my $ancient_name = $oldORFnames{$biosequence_name};
    if ($ancient_name) {
      my @tmp = ('Old ORF Name',$ancient_name);
      push(@links,\@tmp);
    }


    foreach my $link (@links) {
      #print "    ".join("=",@{$link})."\n";
      my %rowdata = (
        search_key_name => $link->[1],
        search_key_type => $link->[0],
        search_key_dbxref_id => $link->[2],
        organism_id => $organism_id,
        atlas_build_id => $atlas_build_id,
        resource_name => $biosequence_name,
        resource_type => 'Halobacterium ORF Name',
        resource_url => "GetProtein?atlas_build_id=$atlas_build_id&protein_name=$biosequence_name&action=QUERY",
        resource_n_matches => $matched_proteins->{$biosequence_name},
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

  } # endfor each row

  print "\n";

} # end buildHalobacteriumKeyIndex


###############################################################################
# buildStreptococcusKeyIndex
###############################################################################
sub buildStreptococcusKeyIndex {
  my $METHOD = 'buildStreptococcusKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  print "INFO[$METHOD]: Building Streptococcus key index...\n" if ($VERBOSE);

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $reference_directory = $args{reference_directory}
    or die("ERROR[$METHOD]: Parameter reference_directory not passed");

  unless (-d $reference_directory) {
    die("ERROR[$METHOD]: '$reference_directory' is not a directory");
  }

  my $organism_id = 25;
  my %proteins;



  #### Load information from ptt file
  my $reference_file = "$reference_directory/NC_002737.ptt";

  #### Open file and skip header
  my $header;
  open(INFILE,$reference_file)
    or die("ERROR[$METHOD]: Unable to open file '$reference_file'");
  while ($header = <INFILE>) {
    last if ($header =~ /^Location/);
  }

  #### Create an array and hash of the columns
  $header =~ s/[\r\n]//g;
  my @columns_names = split("\t",$header);
  my %columns_names;
  my $index = 0;
  foreach my $column_name ( @columns_names ) {
    $columns_names{$column_name} = $index;
    #print "Column '$column_name'= $index\n";
    $index++;
  }

  #### Load data
  while (my $line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my @columns = split("\t",$line);
    my $protein_name = "gi|".$columns[$columns_names{PID}];
    $proteins{$protein_name}->{gi} = $protein_name;
    $proteins{$protein_name}->{ORF_name} = $columns[$columns_names{'Synonym'}];
    $proteins{$protein_name}->{gene_name} = $columns[$columns_names{'Gene'}];
    $proteins{$protein_name}->{COG} = $columns[$columns_names{'COG'}];
    $proteins{$protein_name}->{full_name} = $columns[$columns_names{'Product'}];
  }
  close(INFILE);


  #### Load information from gff file
  my $reference_file = "$reference_directory/NC_002737.gff";

  #### Open file and skip header
  open(INFILE,$reference_file)
    or die("ERROR[$METHOD]: Unable to open file '$reference_file'");
  while (my $line = <INFILE>) {
    last if ($line =~ /^##Type/);
  }

  #### Load data
  while (my $line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my @columns = split("\t",$line);
    next unless ($columns[2] eq 'CDS');

    my $mish_mash = $columns[8];
    my @keyvaluepairs = split(";",$mish_mash);


    my ($key,$value,$gi,$refseq,$geneID,$note);
    foreach my $keyvaluepair ( @keyvaluepairs ) {

      if ( $keyvaluepair =~ /(\w+)=(.+)/ ) {
	$key = $1;
	$value = $2;
      } else {
	print "WARNING: Unable to parse '$keyvaluepair' into key=value\n";
	next;
      }
      #print "keyvaluepair: $key=$value\n";

      if ($key eq 'db_xref') {
	if ($value =~ /^GI:(\d+)$/) {
	  $gi = $1;
	} elsif ($value =~ /^GeneID:(\d+)$/) {
	  $geneID = $1;
	} else {
	  print "WARNING: unable to parse db_ref '$key=$value'\n";
	}
      }

      if ($key eq 'protein_id') {
	$refseq = $value;
      }

      if ($key eq 'note') {
	$note = $value;
	$note =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
      }

    }

    unless ($gi) {
      print "WARNING: No gi number for line '$line'\n";
      next;
    }

    my $protein_name = "gi|$gi";

    if ($refseq) {
      $proteins{$protein_name}->{RefSeq} = $refseq;
      $proteins{$protein_name}->{combined} = "$protein_name|ref|$refseq|";
    }

    if ($geneID) {
      $proteins{$protein_name}->{'Entrez GeneID'} = $geneID;
    }

    if ($note) {
      if (length($note) > 800) {
	$note = substr($note,0,800)."....";
      }
      $proteins{$protein_name}->{'Functional_Note'} = $note;
    }

  }
  close(INFILE);


  #### Get the list of proteins that have a match
  my $matched_proteins = $self->getNProteinHits(
    organism_id=>$organism_id,
    atlas_build_id=>$atlas_build_id,
  );


  #### Loop over all input rows processing information
  my $counter = 0;
  foreach my $biosequence_name (keys(%proteins)) {

    #### Build a list of protein links
    my @links;

    if ($biosequence_name) {
      my @tmp = ('gi Accession',$biosequence_name);
      push(@links,\@tmp);
    }

    foreach my $key ( qw (ORF_name gene_name COG full_name RefSeq combined Functional_Note) ) {
      if (exists($proteins{$biosequence_name}->{$key})) {
	my @tmp = ($key,$proteins{$biosequence_name}->{$key});
	push(@links,\@tmp);
      }
    }

    foreach my $link (@links) {
      #print "    ".join("=",@{$link})."\n";
      my %rowdata = (
        search_key_name => $link->[1],
        search_key_type => $link->[0],
        search_key_dbxref_id => $link->[2],
        organism_id => $organism_id,
        atlas_build_id => $atlas_build_id,
        resource_name => $biosequence_name,
        resource_type => 'S. pyogenes accession',
        resource_url => "GetProtein?atlas_build_id=$atlas_build_id&protein_name=$biosequence_name&action=QUERY",
        resource_n_matches => $matched_proteins->{$biosequence_name},
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

    #my $xx=<STDIN>;

  } # endfor each biosequence

  print "\n";

} # end buildStreptococcusKeyIndex


###############################################################################
# buildLeptospiraKeyIndex
###############################################################################
sub buildLeptospiraKeyIndex {
  my $METHOD = 'buildLeptospiraKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  print "INFO[$METHOD]: Building Leptospira key index...\n" if ($VERBOSE);

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $reference_directory = $args{reference_directory}
    or die("ERROR[$METHOD]: Parameter reference_directory not passed");

  unless (-d $reference_directory) {
    die("ERROR[$METHOD]: '$reference_directory' is not a directory");
  }

  my $organism_id = 27;
  my %proteins;



  #### Load information from ptt file
  my $reference_file = "$reference_directory/NC_005823.ptt";

  #### Open file and skip header
  my $header;
  open(INFILE,$reference_file)
    or die("ERROR[$METHOD]: Unable to open file '$reference_file'");
  while ($header = <INFILE>) {
    last if ($header =~ /^Location/);
  }

  #### Create an array and hash of the columns
  $header =~ s/[\r\n]//g;
  my @columns_names = split("\t",$header);
  my %columns_names;
  my $index = 0;
  foreach my $column_name ( @columns_names ) {
    $columns_names{$column_name} = $index;
    #print "Column '$column_name'= $index\n";
    $index++;
  }

  #### Load data
  while (my $line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my @columns = split("\t",$line);
    my $protein_name = "gi|".$columns[$columns_names{PID}];
    $proteins{$protein_name}->{gi} = $protein_name;
    $proteins{$protein_name}->{ORF_name} = $columns[$columns_names{'Synonym'}];
    $proteins{$protein_name}->{gene_name} = $columns[$columns_names{'Gene'}];
    $proteins{$protein_name}->{COG} = $columns[$columns_names{'COG'}];
    $proteins{$protein_name}->{full_name} = $columns[$columns_names{'Product'}];
  }
  close(INFILE);


  #### Load information from gff file
  my $reference_file = "$reference_directory/NC_005823.gff";

  #### Open file and skip header
  open(INFILE,$reference_file)
    or die("ERROR[$METHOD]: Unable to open file '$reference_file'");
  while (my $line = <INFILE>) {
    last if ($line =~ /^##Type/);
  }

  #### Load data
  while (my $line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my @columns = split("\t",$line);
    next unless ($columns[2] eq 'CDS');

    my $mish_mash = $columns[8];
    my @keyvaluepairs = split(";",$mish_mash);


    my ($key,$value,$gi,$refseq,$geneID,$note);
    foreach my $keyvaluepair ( @keyvaluepairs ) {

      if ( $keyvaluepair =~ /(\w+)=(.+)/ ) {
	$key = $1;
	$value = $2;
      } else {
	print "WARNING: Unable to parse '$keyvaluepair' into key=value\n";
	next;
      }
      #print "keyvaluepair: $key=$value\n";

      if ($key eq 'db_xref') {
	if ($value =~ /^GI:(\d+)$/) {
	  $gi = $1;
	} elsif ($value =~ /^GeneID:(\d+)$/) {
	  $geneID = $1;
	} else {
	  print "WARNING: unable to parse db_ref '$key=$value'\n";
	}
      }

      if ($key eq 'protein_id') {
	$refseq = $value;
      }

      if ($key eq 'note') {
	$note = $value;
	$note =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
      }

    }

    unless ($gi) {
      print "WARNING: No gi number for line '$line'\n";
      next;
    }

    my $protein_name = "gi|$gi";

    if ($refseq) {
      $proteins{$protein_name}->{RefSeq} = $refseq;
      $proteins{$protein_name}->{combined} = "$protein_name|ref|$refseq|";
    }

    if ($geneID) {
      $proteins{$protein_name}->{'Entrez GeneID'} = $geneID;
    }

    if ($note) {
      if (length($note) > 800) {
	$note = substr($note,0,800)."....";
      }
      $proteins{$protein_name}->{'Functional_Note'} = $note;
    }

  }
  close(INFILE);


  #### Get the list of proteins that have a match
  my $matched_proteins = $self->getNProteinHits(
    organism_id=>$organism_id,
    atlas_build_id=>$atlas_build_id,
  );


  #### Loop over all input rows processing information
  my $counter = 0;
  foreach my $biosequence_name (keys(%proteins)) {

    #### Debugging
    #print "protein=",$biosequence_name,"\n";
    #print "protein(combined)=",$proteins{$biosequence_name}->{combined},"\n";


    #### Build a list of protein links
    my @links;

    if ($biosequence_name) {
      my @tmp = ('gi Accession',$biosequence_name);
      push(@links,\@tmp);
    }

    foreach my $key ( qw (ORF_name gene_name COG full_name RefSeq combined Functional_Note) ) {
      if (exists($proteins{$biosequence_name}->{$key})) {
	my @tmp = ($key,$proteins{$biosequence_name}->{$key});
	push(@links,\@tmp);
      }
    }

    foreach my $link (@links) {
      #print "    ".join("=",@{$link})."\n";
      my %rowdata = (
        search_key_name => $link->[1],
        search_key_type => $link->[0],
        search_key_dbxref_id => $link->[2],
        organism_id => $organism_id,
        atlas_build_id => $atlas_build_id,
        resource_name => $proteins{$biosequence_name}->{combined},
        resource_type => 'L. interrogans accession',
        resource_url => "GetProtein?atlas_build_id=$atlas_build_id&protein_name=$proteins{$biosequence_name}->{combined}&action=QUERY",
        resource_n_matches => $matched_proteins->{$proteins{$biosequence_name}->{combined}},
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

    #my $xx=<STDIN>;

  } # endfor each biosequence

  print "\n";

} # end buildLeptospiraKeyIndex


###############################################################################
# buildDrosophilaKeyIndex
###############################################################################
sub buildDrosophilaKeyIndex {
  my $METHOD = 'buildDrosophilaKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  print "INFO[$METHOD]: Building Drosophila key index...\n" if ($VERBOSE);

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $reference_directory = $args{reference_directory}
    or die("ERROR[$METHOD]: Parameter reference_directory not passed");

  unless (-d $reference_directory) {
    die("ERROR[$METHOD]: '$reference_directory' is not a directory");
  }

  my $organism_id = 8;

  #### Get the list of proteins that have a match
  my $matched_proteins = $self->getNProteinHits(
    organism_id=>$organism_id,
    atlas_build_id=>$atlas_build_id,
  );


  #### Create a link from gene names to protein names
  my %gene2protein;
  my $protein_file = "$reference_directory/Drosophila_melanogaster.pep.fa";
  open(INFILE,$protein_file) || die("ERROR: Unable to open '$protein_file'");
  while (my $line = <INFILE>) {
    if ($line =~ /^>([\w\d\-]+)/) {
      my $protein = $1;
      my $gene;
      if ($protein =~ /^(CG\d+)/) {
	$gene = $1;
      } else {
	print "WARNING: Unable to find gene name in '$protein'\n";
      }
      $gene2protein{$gene}->{$protein} = 1;
      #print "Read mapping: $gene -> $protein\n";
    }
  }
  close(INFILE);


  #### Open the GOA file
  my $GOA_file = "$reference_directory/17.D_melanogaster.goa";
  open(INFILE,$GOA_file)
    or die("ERROR[$METHOD]: Unable to open file '$GOA_file'");


  #### Read all the data
  my $counter = 0;
  my $previous_id = 'xx';

  while (my $line=<INFILE>) {
    chomp($line);
    my @columns = split(/\t/,$line);
    my $UniProt_id = $columns[1];
    my $UniProt_name = $columns[2];
    next unless ($UniProt_id);
    next if ($UniProt_id eq $previous_id);
    $previous_id = $UniProt_id;

    my $description = $columns[9];

    my ($aliases,$full_name) = split(": ",$description);
    my @aliases = split(", ",$aliases);


    #### Build a list of protein links
    my @links;

    if ($UniProt_id) {
      my @tmp = ('UniProt ID',$UniProt_id);
      push(@links,\@tmp);
    }

    if ($UniProt_name) {
      my @tmp = ('UniProt Name',$UniProt_name);
      push(@links,\@tmp);
    }

    if ($full_name) {
      my @tmp = ('Full Name',$full_name);
      push(@links,\@tmp);
    }

    my $gene_name;
    if ($aliases) {
      my @list = splitEntities(list=>$aliases,delimiter=>', ');
      foreach my $item ( @list ) {
        my @tmp = ('Alias',$item);
	if ($item =~ /CG.+/) {
	  $gene_name = $item;
	} else {
	  push(@links,\@tmp);
	}
      }
    }

    if ($gene_name) {
      my @tmp = ('Gene name',$gene_name);
      push(@links,\@tmp);
    }


    my @feature_names;
    if ($gene_name) {
      if ($gene2protein{$gene_name}) {
	foreach my $protein ( keys(%{$gene2protein{$gene_name}}) ) {
	  push(@feature_names,$protein);
	}
      }
    }
    unless (@feature_names) {
      push(@feature_names,'UNKNOWN');
    }


    if (0) {
      print "-------------------------------------------------\n";
      print "UniProt_id=$UniProt_id\n";
      print "UniProt_name=$UniProt_name\n";
      print "description=$description\n";
      print "full_name=$full_name\n";
      print "aliases=$aliases\n";
      print "gene_name=$gene_name\n";
    }

    #### Loop over all proteins
    foreach my $feature_name ( @feature_names ) {
      my @temp_links = @links;
      my @tmp = ('Protein name',$feature_name);
      push(@temp_links,\@tmp);
      foreach my $link (@temp_links) {
	#print "    ".join("=",@{$link})."\n";
	my %rowdata = (
          search_key_name => $link->[1],
          search_key_type => $link->[0],
          search_key_dbxref_id => $link->[2],
          organism_id => $organism_id,
          atlas_build_id => $atlas_build_id,
          resource_name => $feature_name,
          resource_type => 'Drosophila Protein',
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
    }


    $counter++;
    print "$counter... " if ($counter/100 eq int($counter/100));

    my $xx=<STDIN> if (0);

  } # endfor each row

  print "\n";

} # end buildDrosophilaKeyIndex


###############################################################################
# buildPigKeyIndex
###############################################################################
sub buildPigKeyIndex {
  my $METHOD = 'buildPigKeyIndex';
  my $self = shift || die ("self not passed");
  my %args = @_;

  print "INFO[$METHOD]: Building Pig key index...\n" if ($VERBOSE);

  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $reference_directory = $args{reference_directory}
    or die("ERROR[$METHOD]: Parameter reference_directory not passed");

  unless (-d $reference_directory) {
    die("ERROR[$METHOD]: '$reference_directory' is not a directory");
  }

  my $organism_id = 30;
  my %proteins;



  #### Load information from ptt file
  my $reference_file = "$reference_directory/Pig_combined.fasta";
  print "Reading $reference_file\n" if ($VERBOSE);
  open(INFILE,$reference_file)
    or die("ERROR[$METHOD]: Unable to open file '$reference_file'");

  #### Load data
  while (my $line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    if ($line =~ /^>/) {
      if ($line =~ /^>(\S+)/) {
	my $protein_name = $1;
	if ($line =~ /^>\S+\s+(.+)$/) {
	  my $description = $1;
	  if ($description =~ /^(.+) - Sus scrofa \(Pig\)\s*/) {
	    $proteins{$protein_name}->{full_name} = $1;
	  } elsif ($description =~ /^(.+) \(PRRSV\)\s*$/) {
	    $proteins{$protein_name}->{full_name} = $1;
	  } elsif ($description =~ /^(.+) \([A-Z0-9]+\)\s*$/) {
	    $proteins{$protein_name}->{full_name} = $1;
	  } elsif ($description =~ /^(.+) \[Sus scrofa\]\s*$/) {
	    my $description = $1;
	    if ($description =~ /\](.+?)$/) {
	      $proteins{$protein_name}->{full_name} = $1;
	    }
	    if ($description =~ /([PQ][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])/) {
	      $proteins{$protein_name}->{UniProt} = $1;
	    }
	    if ($description =~ /([PQ][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]_PIG)/) {
	      $proteins{$protein_name}->{UniProt} = $1;
	    }
	    if ($description =~ /(NP_[\d\.])/) {
	      $proteins{$protein_name}->{RefSeq} = $1;
	    }
	  } else {
	    $proteins{$protein_name}->{full_name} = $description;
	  }
	}
      }
    }
  }
  close(INFILE);


  #### Get the list of proteins that have a match
  my $matched_proteins = $self->getNProteinHits(
    organism_id=>$organism_id,
    atlas_build_id=>$atlas_build_id,
  );


  #### Loop over all input rows processing information
  my $counter = 0;
  foreach my $biosequence_name (keys(%proteins)) {

    #### Debugging
    #print "protein=",$biosequence_name,"\n";
    #print "protein(combined)=",$proteins{$biosequence_name}->{combined},"\n";


    #### Build a list of protein links
    my @links;

    if ($biosequence_name) {
      my @tmp = ('Accession',$biosequence_name);
      push(@links,\@tmp);
    }

    foreach my $key ( qw (full_name UniProt) ) {
      if (exists($proteins{$biosequence_name}->{$key})) {
	my @tmp = ($key,$proteins{$biosequence_name}->{$key});
	push(@links,\@tmp);
      }
    }

    foreach my $link (@links) {
      #print "    ".join("=",@{$link})."\n";
      my %rowdata = (
        search_key_name => substr($link->[1],0,255),
        search_key_type => $link->[0],
        search_key_dbxref_id => $link->[2],
        organism_id => $organism_id,
        atlas_build_id => $atlas_build_id,
        resource_name => $biosequence_name,
        resource_type => 'Pig accession',
        resource_url => "GetProtein?atlas_build_id=$atlas_build_id&protein_name=$proteins{$biosequence_name}->{combined}&action=QUERY",
        resource_n_matches => $matched_proteins->{$biosequence_name},
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

    #my $xx=<STDIN>;

  } # endfor each biosequence

  print "\n";

} # end buildPigKeyIndex




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
