#!/usr/local/bin/perl 

###############################################################################
# Program     : get_prot_info_for_bss.pl
# Author      : Terry Farrah <tfarrah@systemsbiology.org>
#
# Description : Fetches chromosomal info and misc. protein info
#               on proteins in a biosequence set using the
#               Ensembl perl API and stores it in a tsv file.
#
###############################################################################

use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin";
use lib "/net/db/projects/PeptideAtlas/pipeline/lib/ensembl-67/modules";
use lib "/net/db/projects/PeptideAtlas/pipeline/bin";
use lib "$FindBin::Bin/../../perl";

use PeptideFilesGenerator;

use vars qw (%OPTIONS $VERBOSE $QUIET $DEBUG $TESTONLY $PROG_NAME $USAGE);

#### Do not buffer STDOUT
$|++;

use DBI;
use Storable;
use Data::Dumper;
#use Bio::SeqIO;
use Bio::SearchIO;

### use the Ensembl perl API to access our (now local copy of) the
### Ensembl SQL database. NOTE: as of April 2010, version of API used
### in this script is obsolete.  TODO: port to latest version of API.
use Bio::EnsEMBL::DBSQL::TranscriptAdaptor;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::TopLevelAssemblyMapper;
use Bio::EnsEMBL::DBSQL::CoordSystemAdaptor;
use Bio::EnsEMBL::DBSQL::KaryotypeBandAdaptor;
use Bio::EnsEMBL::AssemblyMapper;
use Bio::EnsEMBL::Mapper;
use Bio::EnsEMBL::Mapper::Coordinate;
use ProtFeatures;
use SBEAMS::PeptideAtlas::ProtInfo;


###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag

  These two options are always required:
  --bss_fasta_file       Path to fasta (input) file
  --prot_coords_file     Path to protein coordinates (output) file

  At least one of the four "get" options below is required:
  --getProtProps         get protein properties info from Swiss-Prot descr
  --getSwissIdents       get latest Swiss-Prot accessions for organism
                           requires --organism_name
  --urlSwissProt         base URL for Swiss-Prot species-specific fasta
                           used by getSwissIdents.
  default: ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/proteomes";
  --getEnsemblChromInfo  get protein chromosomal info from Ensembl
                           for Ensembl identifiers.
                           This info can also be assigned to Swiss-Prot
			   identifiers by using getSwissChromInfo.
  --getSwissChromInfo    get (limited) protein chromosomal info
			   directly from Swiss-Prot, if Homo_sapiens.
			   Then, use Swiss-Prot cross-references to
			   grab info gotten from Ensembl with
                           getEnsemblChromInfo and assign to
                           Swiss-Prot idents.
                           Uses the following two params:
  --urlSwissChrom        base URL for Swiss-Prot chromosomal info
                           (default http://www.uniprot.org/docs)
  --pathSwissProt        local path for Swiss-Prot flatfile uniprot_sprot.dat
                           (default /data/seqdb/uniprot_sprot)

  All of the options below are required with getEnsemblChromInfo:
  --organism_name        Genus_species of organism (e.g. Homo_sapiens)
  --mysqldbhost          Hostname of MySQL DB of Ensembl tables (try mysql)
  --mysqldbname          Ensembl MySQL database name
  --mysqldbuser          User name to login to Ensembl MySQL host (try guest)
  --mysqldbpsswd         Password for username (try guest)
EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s",
"organism_name:s",
"biosequence_set_id:s", "getEnsemblChromInfo", "getSwissChromInfo",
"getProtProps", "getSwissIdents",
"mysqldbpsswd:s","mysqldbuser:s","mysqldbhost:s","mysqldbname:s",
"bss_fasta_file:s",
"prot_coords_file:s","urlSwissChrom:s","urlSwissProt:s","pathSwissProt:s",
))
{
    print "\n$USAGE\n";
    exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;


main();
exit;


###############################################################################
# main
###############################################################################
sub main
{
  #### If no command to do anything, print usage
  unless ( ( $OPTIONS{'getEnsemblChromInfo'}  ||
             $OPTIONS{'getSwissChromInfo'} ||
             $OPTIONS{'getProtProps'} ||
             $OPTIONS{'getSwissIdents'})
           && $OPTIONS{'prot_coords_file'} && $OPTIONS{'bss_fasta_file'})
  {
    print "\n$USAGE\n";
    return;
  }

  my $protids_href = {};
  my $prot_coords_href = {};
  my $swiss_idents_href;
  my $prot_coords_file = $OPTIONS{'prot_coords_file'};
  my $urlSwissChrom = $OPTIONS{'urlSwissChrom'} ||
                              "http://www.uniprot.org/docs";
  my $urlSwissProt = $OPTIONS{'urlSwissProt'} ||
  "ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/proteomes";
  #"http://www.uniprot.org/uniprot";
  my $pathSwissProt = $OPTIONS{'pathSwissProt'} || 
			      "/data/seqdb/uniprot_sprot";

  #### Read fasta file to get protein identifiers and descriptions for this BSS
  getProtDesc (
    bss_fasta_file => $OPTIONS{bss_fasta_file},
    protids_href => $protids_href,
  );

  #### If the getSwissIdents step is requested
  if ($OPTIONS{'getSwissIdents'}) {
    unless ($OPTIONS{'organism_name'} 
    ) {
      print "\n$USAGE\n";
      print "ERROR: Must supply organism_name with getSwissIdents.\n ";
      return;
    }

    getSwissIdents(
      protids_href => $protids_href,
      prot_coords_href => $prot_coords_href,
      base_url_prot =>  $urlSwissProt,
      #path_prot =>  $pathSwissProt,
      genus_species => $OPTIONS{'organism_name'},
    );
    my $n_idents = scalar keys %{$prot_coords_href};
    print "$n_idents entries in protein coordinates hash.\n";
  }

  #### If the getEnsemblChromInfo step is requested
  if ($OPTIONS{'getEnsemblChromInfo'}) {
    unless ($OPTIONS{'mysqldbname'} 
    && $OPTIONS{'mysqldbhost'} && $OPTIONS{'mysqldbuser'}
    && $OPTIONS{'mysqldbpsswd'} 
    ) {
      print "\n$USAGE\n";
      print "ERROR: Must supply mysqldbname, ".
             "mysqldbhost, mysqldbuser, and mysqldbpsswd.\n ";
      return;
    }

    my $host = $OPTIONS{'mysqldbhost'};
    my $user = $OPTIONS{'mysqldbuser'};
    my $password = $OPTIONS{'mysqldbpsswd'};
    my $dbname = $OPTIONS{'mysqldbname'};
    my $refcode = 'ensembl';

    my ($db,$transcript_adaptor);
    my ($kary_adaptor,$slice_adaptor);

    ### connect to the Ensembl database
    $db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
      -host => $host,
      -user => $user,
      -pass => $password,
      -dbname => $dbname,
    );
    ### create "adaptors" to retreive various objects
    ### such as exons, transcripts, and genes.
    $transcript_adaptor = $db->get_TranscriptAdaptor();
    $kary_adaptor = $db->get_KaryotypeBandAdaptor();
    $slice_adaptor = $db->get_SliceAdaptor();

    getEnsemblChromInfo(
      db => $db, 
      transcript_adaptor => $transcript_adaptor,
      kary_adaptor => $kary_adaptor,
      slice_adaptor => $slice_adaptor,
      refcode => $refcode,
      protids_href => $protids_href,
      prot_coords_href => $prot_coords_href,
    );
    my $n_idents = scalar keys %{$prot_coords_href};
    print "$n_idents entries in protein coordinates hash.\n";
  }

  #### If the getSwissChromInfo step is requested
  if ($OPTIONS{'getSwissChromInfo'}) {

    getSwissChromInfo(
      protids_href => $protids_href,
      prot_coords_href => $prot_coords_href,
      base_url_chrom =>  $urlSwissChrom,
      #base_url_prot =>  $urlSwissProt,
      path_prot =>  $pathSwissProt,
      ensembl_info_avail => $OPTIONS{'getEnsemblChromInfo'},
      genus_species => $OPTIONS{'organism_name'},
    );
    my $n_idents = scalar keys %{$prot_coords_href};
    print "$n_idents entries in protein coordinates hash.\n";
  }
  
  #### If the getProtProps step is requested
  if ($OPTIONS{'getProtProps'}) {

    getProtProps(
      protids_href => $protids_href,
      prot_coords_href => $prot_coords_href,
    );
    my $n_idents = scalar keys %{$prot_coords_href};
    print "$n_idents entries in protein coordinates hash.\n";
  }
  
  #### Write out all the protein coordinate info collected into a file.
  print "\nWriting chromosomal info to ${prot_coords_file}.\n";
  writeProtCoords(
    prot_coords_href => $prot_coords_href,
    prot_coords_file => $prot_coords_file,
  )
}


###############################################################################
# getSwissIdents -- download latest Swiss-Prot fasta file for species and
  # populate a hash of identifiers
###############################################################################
sub getSwissIdents
{
  my %args = @_;
  my $protids_href = $args{protids_href} || die "need protids_href";
  my $prot_coords_href = $args{prot_coords_href} || die "need prot_coords_href";
  #my $path_prot = $args{path_prot} || die "need path_prot";
  my $genus_species = $args{genus_species} || die "need genus_species";
  my $base_url_prot = $args{base_url_prot} || die "need base_url_prot";
  my $swiss_species;

  # Get the Swiss-Prot string for the requested species
  my $swiss_species = SBEAMS::PeptideAtlas::ProtInfo::get_swiss_prot_species
    ($genus_species);
  if (!$swiss_species) {
    print "Script doesn't know Swiss-Prot abbreviation for ${genus_species}.\n";
    exit;
  }

  # Download Swiss-Prot fasta file for organism and get the doclines
  # This is preferable to using the all-species fasta file
  # maintained by Kerry on local disk, because it includes varsplic
  # idents. (Or it seemed to a few days ago ... today, 1/14/13, it
  # doesn't.)

  my $n_idents = scalar keys %{$prot_coords_href};
#--------------------------------------------------
#   my $sprot_fname = "${path_prot}/uniprot_sprot.fasta";
#   open (my $infh, $sprot_fname) || die "Can't open $sprot_fname.";
#   print "Reading latest Swiss-Prot fasta file from $sprot_fname.\n";
#-------------------------------------------------- 
  my $full_url = $base_url_prot . "/" . $swiss_species . ".fasta.gz";
  print "Slurping latest Swiss-Prot $genus_species fasta file from ${full_url}.\n";
  my $swiss_doclines = `wget -q -O - $full_url | zcat | grep "^>"`;
  # Store all of the idents in a hash
    my @lines = split ("\n", $swiss_doclines);
    my $n_lines = scalar @lines;
    print "$n_lines lines read\n";
    for my $line (@lines) {
#--------------------------------------------------
#     while (my $line = <$infh>) {
#-------------------------------------------------- 
    if ($line =~ /^>sp\|(\S+?)\|.*_${swiss_species}.*$/) {
      my $ident = $1;
      $prot_coords_href->{$ident}->{is_swiss} = 1;
    }
  }
#--------------------------------------------------
#   close $infh;
#-------------------------------------------------- 

  # Finally, set all idents in varsplic format to is_swiss.
  my $counter = 0;
  for my $ident (keys %{$prot_coords_href}) {
    if ($ident =~ /^\w{6}-\d+$/) {
      $prot_coords_href->{$ident}->{is_swiss} = 1;
      $counter++;
    }
  }
  print "Found $counter varspic idents and assigned to them is_swiss.\n";
}

###############################################################################
# getProtDesc -- read protein identifiers from a fasta file into a hash
###############################################################################
sub getProtDesc
{
    my %args = @_;

    my $bss_fasta_file = $args{bss_fasta_file} || die "need bss_fasta_file";

    my $protids_href = $args{protids_href} || die "need protids_href";

    print "Reading biosequence set fasta file $bss_fasta_file\n";
    open(INFILE,"$bss_fasta_file") ||
        die("ERROR: Unable to open '$bss_fasta_file'");

    my $prot_count = 0;

    while( my $line = <INFILE> ) {
      chomp($line);
      next if ( $line !~ /^>/ );
      $line =~ /^>(\S*)\s*(.*)$/;
      my $prot_id = $1;
      my $prot_desc = $2;

      if ($prot_id) {
        $protids_href->{$prot_id} = $prot_desc;
      }
   }
}

###############################################################################
# getEnsemblChromInfo - 
###############################################################################
sub getEnsemblChromInfo
{
   my %args = @_;

   my $db = $args{db} || "";

   my $kary_adaptor = $args{kary_adaptor} || "";

   my $slice_adaptor = $args{slice_adaptor} || "";

   my $transcript_adaptor = $args{transcript_adaptor} || "";

   my $refcode = $args{refcode} || "";

   my $protids_href = $args{protids_href} || die "need protids_href";

   my $prot_coords_href = $args{prot_coords_href} ||
        die "need prot_coords_href";

   print "Getting coordinates from Ensembl.\n";

   my $prot_count = 0;

   for my $protid (keys %{$protids_href}) {
        $prot_count++;
        print "." if (($prot_count % 1000) == 0);
        print "$prot_count" if (($prot_count % 10000) == 0);
	### FOR DEBUGGING ONLY!!
	#last if ($prot_count > 20000);

	getEnsemblCoords(
  	             $protid,
                     $db,
                     $kary_adaptor,
                     $slice_adaptor,
                     $transcript_adaptor,
                     $prot_coords_href);
   }
   print "\n";
}

###############################################################################
# getSwissChromInfo - 
###############################################################################
# Get the chromsomal information for the Swiss-Prot identifiers.
# First, if human, get what Swiss-Prot has to offer directly: chromosome and
# locus only. Then, if Ensembl info has been gathered, use Swiss-Prot
# cross-references to find out which Ensembl protein each Swiss-Prot
# entry corresponds to, and grab that info, which includes start, end,
# and strand.

sub getSwissChromInfo
{
  my %args = @_;

  my $protids_href = $args{protids_href} || die "need protids_href";
  my $prot_coords_href = $args{prot_coords_href} ||
  die "need prot_coords_href";
  my $base_url_chrom = $args{base_url_chrom} || die "need base_url_chrom";
  #my $base_url_prot = $args{base_url_prot} || die "need base_url_prot";
  my $path_prot = $args{path_prot} || die "need path_prot";
  my $ensembl_info_avail = $args{ensembl_info_avail} || 0;
  my $genus_species = $args{genus_species};


  my $outfile;

  # Can only get chrom. info from Swiss-Prot for human. Possible for
  # yeast, also; just haven't written the code for it.
  if ($genus_species =~ /homo.*sapiens/i) {
    print "Getting chromosome/locus from Swiss-Prot.\nChromosome ";

    #### For each chromosome, get the info from Swiss-Prot.
    # FOR DEBUGGING
    #for my $chrom ('01','02','05','y',) {
    for my $chrom ('01','02','03','04','05','06','07','08','09','10','11',
      '12','13','14','15','16','17','18','19','20','21','22', 'x','y',) {
      print "$chrom...";
      my $file = "humchr$chrom.txt";
      my $url = "$base_url_chrom/$file";
      $outfile = "/tmp/$file";
      my $status = system("wget -q $url -O $outfile");

      open (INFILE, $outfile) || die "Can't open $outfile";
      # Throw away junk
      my $count = 0;
      while ( my $line = <INFILE>) {
	chomp;
	my ($gene, $locus, $protid ) = split(/\s+/, $line);
	my $chromosome="";
	#print "$gene $locus $protid\n";
	if ( ( defined $protid ) && ( defined $protids_href->{$protid}) ) {
	  if ( defined $locus ) {
	    $locus =~ /^(\w{1,2})[pqc]/;
	    $chromosome = $1;
	    if (! defined $chromosome) {
	      $locus =~ /^(\w{1,2})$/;
	      $chromosome = $1;
	    }
	    $prot_coords_href->{$protid}->{chromosome} = $chromosome;
	    $prot_coords_href->{$protid}->{locus} = $locus;
	  }
	  $count++;
	}
      }
      close (INFILE);
      my $status = `rm -f $outfile`;
    }
    print "\n";
  }

  # Now, get the info for each Swiss-Prot identifer from Ensembl if
  # available.
  if ($ensembl_info_avail) {
    print "Getting Ensembl cross-references for Swiss-Prot.\n";
    # First, read the Swiss-Prot flatfile into a hash.
    my $sprot_fname = "${path_prot}/uniprot_sprot.dat";
    open (my $infh, $sprot_fname) || die "Can't open $sprot_fname.";
    # Get just the species we care about.
    # need to do species correctly. TODO
    my $swiss_species = SBEAMS::PeptideAtlas::ProtInfo::get_swiss_prot_species
      ($genus_species);
    if (!$swiss_species) {
      print "Script doesn't know Swiss-Prot abbreviation for ${genus_species}.\n";
      exit;
    }
    my $n_records = 0;
    my $in_species = 0;
    my $protid;
    my $got_ensembl = 0;
    print "Reading latest Swiss-Prot complete flatfile from $sprot_fname.\n";
    while (my $line = <$infh>) {
      chomp $line;
      if ($line =~ /_${swiss_species}/) {
	$in_species = 1;
      } elsif ($line =~ /^ID/ && $in_species) {
	$in_species = 0;
      } elsif ($line =~ /^AC   (\S+?);/) {
	$protid = $1;
	$n_records++;
	print "." if (($n_records % 10000) == 0);
	print "$n_records" if (($n_records % 100000) == 0);
	$got_ensembl = 0;
      } elsif ($in_species) {
	if ($line =~ "^DR   Ensembl;" && !$got_ensembl) {
	  my $ensembl_id = "";
	  if ($line =~ /(ENSP\d{11});/) {
	    $ensembl_id = $1;
	    if (defined $prot_coords_href->{$ensembl_id}) {
	      $prot_coords_href->{$protid}->{start} =
	      $prot_coords_href->{$ensembl_id}->{start};
	      $prot_coords_href->{$protid}->{end} =
	      $prot_coords_href->{$ensembl_id}->{end};
	      $prot_coords_href->{$protid}->{strand} =
	      $prot_coords_href->{$ensembl_id}->{strand};
	      $prot_coords_href->{$protid}->{chromosome} =
	      $prot_coords_href->{$ensembl_id}->{chromosome};
	      $prot_coords_href->{$protid}->{locus} =
	      $prot_coords_href->{$ensembl_id}->{locus};
	      $got_ensembl = 1;
	    }
	  }
	}
      }
    }
    print "\nDone reading flatfile.\n";
    my $n_idents = scalar keys %{$prot_coords_href};
    print "$n_idents entries in protein coordinates hash.\n";

    my $prot_count = 0;
    print "Getting infos for varsplic from canonicals.\n";
    # Go through varsplic idents and copy info from their canonicals
    for my $protid ( sort keys %{$protids_href} ) {
      if (SBEAMS::PeptideAtlas::ProtInfo::is_uniprot_identifier($protid)) {
	if ($protid =~ /^(\w{6})-\d+$/) {  #if is varsplic
	  # grab base form of ident
	  my $base_id = $1;
	  if (defined $prot_coords_href->{$base_id}) {
	    $prot_coords_href->{$protid}->{start} =
	    $prot_coords_href->{$base_id}->{start};
	    $prot_coords_href->{$protid}->{end} =
	    $prot_coords_href->{$base_id}->{end};
	    $prot_coords_href->{$protid}->{strand} =
	    $prot_coords_href->{$base_id}->{strand};
	    $prot_coords_href->{$protid}->{chromosome} =
	    $prot_coords_href->{$base_id}->{chromosome};
	    $prot_coords_href->{$protid}->{locus} =
	    $prot_coords_href->{$base_id}->{locus};
	  }
	  $prot_count++;
	  #   print "." if (($prot_count % 100) == 0);
	  #   print "$prot_count" if (($prot_count % 1000) == 0);
	}
      }
    }
    `rm -f $outfile`;
    #print "\n";
  }
}


###############################################################################
# getProtProps
###############################################################################
sub getProtProps
{
  my %args = @_;

  my $protids_href = $args{protids_href} || die "need protids_href";

  my $prot_coords_href = $args{prot_coords_href} ||
  die "need prot_coords_href";

  print "Getting protein info from Swiss-Prot descriptions.\n";

  for my $protid ( keys %{$protids_href} ) {
    #only look at Uniprot identifiers (including splice variants)
    if (SBEAMS::PeptideAtlas::ProtInfo::is_uniprot_identifier($protid)) {

      $prot_coords_href->{$protid}->{ig} = 
      is_immunoglobulin ($protids_href->{$protid});

      $prot_coords_href->{$protid}->{keratin} = 
      is_keratin ($protids_href->{$protid} );

    }
  }

  sub is_immunoglobulin {
    my $desc = shift;
    return (1) if (
      (( $desc =~ /immunoglobulin/i ) || ( $desc =~ /Ig\s/))
      &&
      ! (( $desc =~ /receptor/i ) ||
	( $desc =~ /like/i ) ||
	( $desc =~ /domain/i ) ||
	( $desc =~ /superfamily/i ) ||
	( $desc =~ /similar/i ) ||
	( $desc =~ /associated/i ) ||
	( $desc =~ /binding protein/i ) ||
	( $desc =~ /-Ig/i ))
    );
    return (0);
  }

  sub is_keratin {
    my $desc = shift;
    return (1) if (
      ($desc =~ /keratin/i)
      &&
      ! (( $desc =~ /keratinocyte/i ) ||
	( $desc =~ /receptor/i ) ||
	( $desc =~ /like/i ) ||
	( $desc =~ /domain/i ) ||
	( $desc =~ /superfamily/i ) ||
	( $desc =~ /similar/i ) ||
	( $desc =~ /associated/i ) ||
	( $desc =~ /binding protein/i ))
    );
    return (0);
  }
}


###############################################################################
# getEnsemblCoords -- use bioperl with Ensembl database and blast results
# to map the peptide CDS coordinates to chromosomal coordinates
#
# @param $stableId
# @param $db
# @param $kary_adaptor
# @param $slice_adaptor
# @param $transcript_adaptor
# @param $prot_coords_href
###############################################################################
sub getEnsemblCoords
{
  my ($stableId, $db,
    $kary_adaptor, $slice_adaptor,
    $transcript_adaptor, $prot_coords_href)
  = @_;

  if ($stableId =~ /^ENS/ ||
    ($OPTIONS{'organism_name'} eq 'Saccharomyces_cerevisiae' && $stableId =~ /^Y/) ||
    ($OPTIONS{'organism_name'} eq 'Drosophila_melanogaster' && $stableId =~ /^FB/)) {

    #### Get the genomic coordinates for this match
    #### Given the Ensembl ID for this protein, get a transcript object.
    my $transcript =
    $transcript_adaptor->fetch_by_translation_stable_id($stableId);
    if ( !defined $transcript ) {
      print STDERR "Unable to create transcript object $stableId\n";
    } else {
      my $transcript_stable_id = $transcript->stable_id();
      my $tr_seq_region = $transcript->slice->seq_region_name();
      my $tr_start = $transcript->start() || "";
      my $tr_end   = $transcript->end() || "";
      my $tr_strand = $transcript->strand() || "";
      my $chr_name = $transcript->slice()->seq_region_name || "";

      # Get chromosomal band info
      my $transcript_slice =
      $slice_adaptor->fetch_by_transcript_stable_id($transcript_stable_id);
      my @band_objects =
      $kary_adaptor->fetch_all_by_Slice ( $transcript_slice );
      my $band_object = $band_objects[0];
      my @bands = @{$band_object};   # all bands for this slice
      my $band_name = "";
      $band_name = $bands[0]->name() if (scalar @bands > 0);
      my $locus = "$chr_name$band_name";

      if ($tr_strand == -1) { $tr_strand = '-'; }
      else { $tr_strand = '+'; }

      ### Store chromosomal info for protein.
      $prot_coords_href->{$stableId}->{start} = $tr_start;
      $prot_coords_href->{$stableId}->{end} = $tr_end;
      $prot_coords_href->{$stableId}->{strand} = $tr_strand;
      $prot_coords_href->{$stableId}->{chromosome} = $chr_name;
      $prot_coords_href->{$stableId}->{locus} = $locus;
    }
  }
}

###############################################################################
# writeProtCoords -- store chromosomal coordinate/locus info for proteins
###############################################################################
sub writeProtCoords {
  my %args = @_;

  my $prot_coords_file = $args{prot_coords_file} ||
  die "need prot_coords_file";
  my $prot_coords_href = $args{prot_coords_href} ||
  die "need prot_coords_href";

  open(PROTCOORD,">$prot_coords_file");
  for my $stableId (sort keys %{$prot_coords_href}) {
    print PROTCOORD 
    "$stableId\t".
    "$prot_coords_href->{$stableId}->{start}\t".
    "$prot_coords_href->{$stableId}->{end}\t".
    "$prot_coords_href->{$stableId}->{strand}\t".
    "$prot_coords_href->{$stableId}->{chromosome}\t".
    "$prot_coords_href->{$stableId}->{locus}\t".
    "$prot_coords_href->{$stableId}->{ig}\t".
    "$prot_coords_href->{$stableId}->{keratin}\t".
    "$prot_coords_href->{$stableId}->{is_swiss}\t".
    "\n";
  }
  close(PROTCOORD);
}
