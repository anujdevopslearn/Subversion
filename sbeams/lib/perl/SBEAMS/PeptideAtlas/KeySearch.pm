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
    return($sbeams);
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
  my $GOA_directory = $args{GOA_directory}
    or die("ERROR[$METHOD]: Parameter GOA_directory not passed");

  $self->dropKeyIndex();

  print "Loading protein keys from GOA...\n";
  $self->buildGoaKeyIndex(
    GOA_directory => $GOA_directory,
    organism_name => 'human',
  );

  print "Loading peptides keys...\n";
  $self->buildPeptideKeyIndex();

  print "\n";

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

  print "INFO[$METHOD] Dropping key index...\n" if ($VERBOSE);

  unless ($sbeams) {
    die("ERROR[$METHOD]: sbeams object is not defined. Use setSBEAMS() method");
  }

  #my $sql = "DROP INDEX $TBAT_SEARCH_KEY.idx_search_key_name";
  #$sbeams->executeSQL($sql);

  my $sql = "DELETE FROM $TBAT_SEARCH_KEY";
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

  my $organism_name = $args{organism_name}
    or die("ERROR[$METHOD]: Parameter organism_name not passed");

  #### Open the provided GOA xrefs file
  my $GOA_file = "$GOA_directory/${organism_name}.xrefs";
  open(INFILE,$GOA_file)
    or die("ERROR[$METHOD]: Unable to open file '$GOA_file'");

  #### Read the GOA gene_associations file
  my $associations = $self->readGOAAssociations(
    assocations_file => "$GOA_directory/gene_association.goa_${organism_name}",
  );

  #### Read all the data
  my $line;
  my $counter = 0;

  while ($line=<INFILE>) {
    chomp($line);
    my ($Database,$Accession,$IPI,$UniProtSP,$UniProtTR,$Ensembl,$RefSeqNP,
        $RefSeqXP,$TAIR,$Hinv,$proteins,$HGNCgenew,$EntrezGene,$UNIPARC,
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
      print "TAIR=$TAIR\n";
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
    my @Ensembl_IDS = splitEntities($Ensembl);
    my $n_Ensembl_IDS = scalar(@Ensembl_IDS);

    if ($n_Ensembl_IDS == 0) {
      print "WARNING[$METHOD]: No valid ENSP for $Database:$Accession. Ignoring..\n" if ($VERBOSE > 1);
      next;
    }


    #### Build a list of protein links
    my @links;

    if ($Database and $Accession) {
      $Database = 'UniProt' if ($Database eq 'SP');
      my @tmp = ($Database,$Accession);
      push(@links,\@tmp);
    }

    if ($IPI) {
      my @list = splitEntities($IPI);
      foreach my $item ( @list ) {
        my @tmp = ('IPI',$item);
        push(@links,\@tmp);
      }
    }

    if ($UniProtTR) {
      my @list = splitEntities($UniProtTR);
      foreach my $item ( @list ) {
        my @tmp = ('UniProt/TrEMBL',$item);
        push(@links,\@tmp);
      }
    }

    if ($RefSeqNP) {
      my @list = splitEntities($RefSeqNP);
      foreach my $item ( @list ) {
        my @tmp = ('RefSeq',$item);
        push(@links,\@tmp);
      }
    }

    if ($RefSeqXP) {
      my @list = splitEntities($RefSeqXP);
      foreach my $item ( @list ) {
        my @tmp = ('RefSeq',$item);
        push(@links,\@tmp);
      }
    }

    if ($EntrezGene) {
      my @list = splitEntities($EntrezGene);
      foreach my $item ( @list ) {
        my @pair = split(/,/,$item);
        my @tmp = ('Entrez GeneID',$pair[0]);
        push(@links,\@tmp);
        my @tmp2 = ('Entrez Gene Symbol',$pair[1]);
        push(@links,\@tmp2);
      }
    }

    if ($UniGene) {
      my @list = splitEntities($UniGene);
      foreach my $item ( @list ) {
        my @tmp = ('UniGene',$item);
        push(@links,\@tmp);
      }
    }


    my $handle = "$Database:$Accession";
    if ($associations->{$handle}) {
      if ($associations->{$handle}->{Symbol}) {
        my @tmp = ('UniProt Symbol',$associations->{$handle}->{Symbol});
        push(@links,\@tmp);
      }
      if ($associations->{$handle}->{DB_Object_Name}) {
        my @tmp = ('Full Name',$associations->{$handle}->{DB_Object_Name});
        push(@links,\@tmp);
      }
    }


    #### Write the links for each Ensembl IP
    foreach my $Ensembl_ID (@Ensembl_IDS) {

      #### Insert an entry for the Ensembl ID itself
      my %rowdata = (
        search_key_name => $Ensembl_ID,
        search_key_type => 'Ensembl Protein',
        resource_name => $Ensembl_ID,
        resource_type => 'Ensembl Protein',
        resource_url => "GetProtein?atlas_build_id=70&protein_name=$Ensembl_ID&action=QUERY",
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
	  resource_name => $Ensembl_ID,
	  resource_type => 'Ensembl Protein',
	  resource_url => "GetProtein?atlas_build_id=70&protein_name=$Ensembl_ID&action=QUERY",
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
# splitEntities: Split a semi-colon separated list of items into an array
###############################################################################
sub splitEntities {
  my $SUB = 'splitEntities';
  my $string = shift;

  my @tmp_IDS = split(/;/,$string);
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

  print "INFO[$METHOD]: Building Peptide key index...\n" if ($VERBOSE);

  #### Get all the peptides in the database, regardless of build
  my $sql = qq~
       SELECT peptide_accession,peptide_sequence
         FROM $TBAT_PEPTIDE
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
      resource_name => $peptide->[0],
      resource_type => 'PeptideAtlas peptide',
      resource_url => "GetPeptide?atlas_build_id=70&searchWithinThis=Peptide+Name&searchForThis=$peptide->[0]&action=QUERY",
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
      resource_name => $peptide->[0],
      resource_type => 'PeptideAtlas peptide',
      resource_url => "GetPeptide?atlas_build_id=70&searchWithinThis=Peptide+Name&searchForThis=$peptide->[0]&action=QUERY",
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
