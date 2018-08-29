#!/usr/local/bin/perl -w

###############################################################################
# Program      : PA2ProteomeXchange.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
#  For a PeptideAtlas dataset or PASSEL experiment, retrieve some info
#   and output a ProteomExchange submission XML file.
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use XML::Writer;
use IO::File;
use Encode;
$|++;

use lib "$FindBin::Bin/../../perl";

use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);
use vars qw ($q $sbeams $sbeamsMOD $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name);

#### Set up SBEAMS modules
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;


## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ( $current_username = $sbeams->Authenticate(
    #connect_read_only=>1,
    allow_anonymous_access => 1,
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));

$current_contact_id = $sbeams->getCurrent_contact_id;
$current_work_group_id = $sbeams->getCurrent_work_group_id;
$current_work_group_name = $sbeams->getCurrent_work_group_name;


###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME --expt_id 73 --PX_acc PXD000296
     \$SBEAMS/lib/scripts/PeptideAtlas/PA2ProteomeXchange.pl --npr 1 \
     --PX_accession PXD000111 --verbose 3 --PA_accession PAe003970,PAe003971 \
     --RPX_accession RPXD000650 

     \$SBEAMS/lib/scripts/PeptideAtlas/PA2ProteomeXchange.pl --expt_id 47 \
       --PX_accession PXD0000622 --changeLog "Update XML version"

Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  One of --expt_id or --PA_accession is required.
  --expt_id                   PASSEL SEL_experiment_id(s), comma separated
  --PA_accession              PeptideAtlas sample accession(s), e.g.  PAe003970,
                               comma separated

  --PX_accession              ProteomeXchange accession (required)
  --RPX_accession             Reprocessed ProteomeXchange dataset accession
  --title                     Submission title (default: title retrieved from
				database for first expt_id/PA_accession)

  --PX_version                Version number (default 1)
  --npr                       Not a peer-reviewed dataset
  --changeLog                 add change log
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly","help",
        "expt_id:s", "PX_accession:s", "PX_version:i", "npr", "PA_accession:s",
	"title:s", 'RPX_accession:s',"changeLog:s"
    )) {

    die "\n$USAGE";
}

if ($OPTIONS{"help"}) {
  print "\n$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;

if ($DEBUG) {
    print "Options settings:\n";
    print "  VERBOSE = $VERBOSE\n";
    print "  QUIET = $QUIET\n";
    print "  DEBUG = $DEBUG\n";
    print "  TESTONLY = $TESTONLY\n";
}

my $expt_id = $OPTIONS{"expt_id"};
my $PA_accession = $OPTIONS{"PA_accession"};
if (! ( $PA_accession || $expt_id ) ) {
  print "${PROG_NAME}: expt_id or PA_accession required.\n";
  print $USAGE;
  exit;
}

my $title = $OPTIONS{"title"} || '';
my $RPX_accession = $OPTIONS{"RPX_accession"};
  
my $PX_accession = $OPTIONS{"PX_accession"};
if (! $PX_accession) {
  print "${PROG_NAME}: PX_accession required.\n";;
  print $USAGE;
  exit;
}

my $PX_version = $OPTIONS{"PX_version"} || 1;
my $changeLog = $OPTIONS{"changeLog"} || ''; 

###############################################################################
###
### Main section: Get info and write into the ProteomeXchange submission XML file
###
###############################################################################

# Open output file and create an instance of the XML writer
my $output;
if($RPX_accession){
  $output= IO::File->new(">ProteomeXchange_submission_${RPX_accession}.xml");
}else{
  $output = IO::File->new(">ProteomeXchange_submission_${PX_accession}.xml");
}
my $writer = XML::Writer->new(
  OUTPUT=>$output,
  DATA_MODE=>1,
  DATA_INDENT=>2,
  # The below ends up expanding 2-byte special chars into double
  # 2-byte chars. Go figure. Removing it seems to do no harm.
  #ENCODING=>'UTF-8',
);

# Get the info needed for the submission from the database
# and store in a hash
my %px_info = ();
my $combined_px_info_href = \%px_info;

if ( ! $RPX_accession ){
	if ($expt_id) {
		my @list = split(",",$expt_id);
		for my $id (@list) {
			my $px_info_href = {};
			get_PASSEL_info(
				expt_id => $id,
				px_info_href => $px_info_href,
			);
			$combined_px_info_href =
				merge_px_info($combined_px_info_href, $px_info_href);
		}
	}elsif ($PA_accession ){
		my @list = split(",",$PA_accession);
		for my $id (@list) {
			my $px_info_href = {};
			get_PeptideAtlas_info(
				PA_accession => $id,
				px_info_href => $px_info_href,
			);
			$combined_px_info_href =
				merge_px_info($combined_px_info_href, $px_info_href);
		}
  }
	# Write the info to an XML file
	write_PX_XML (
		writer => $writer,
		px_info_href => $combined_px_info_href,
		PX_accession => $PX_accession,
		PX_version => $PX_version,
		title => $title,
    changeLog => $changeLog,
	);
}else{
  if (! ($PX_accession && $PA_accession)){
    die "need PXD and PA accession\n";
  }
  my $px_info_href = {};
  get_PXD_info(
    PA_accession => $PA_accession,
    px_info_href => $px_info_href,
    PX_accession => $PX_accession,
    RPX_accession => $RPX_accession,
  );
  $combined_px_info_href = merge_px_info($combined_px_info_href, $px_info_href);
  # Write the info to an XML file
  write_PX_XML (
    writer => $writer,
    px_info_href => $combined_px_info_href,
    PX_accession => $RPX_accession,
    PX_version => $PX_version,
    original_PX_acc => $PX_accession,
    changeLog => $changeLog,
  ); 
}     

# Close the output file
$output->close();



###############################################################################
###
### Subroutines
###
###############################################################################

## get infomation from original PXD submission
sub get_PXD_info {
  my %args = @_;
  my $px_info_href =$args{px_info_href};

  ## get xml file from 
  ## http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=$PX_accession&outputMode=XML&test=no
  use LWP::Simple;
  use XML::Simple;

  my $url = "http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=$PX_accession&outputMode=XML&test=no";
  my $content = get $url or die "Couldn't get $url";
  my $xml = new XML::Simple;
  my $result = $xml->XMLin($content);  
  #use Data::Dumper;
  #print Dumper($result);
  #my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
  #$year += 1900;
  #$mon++;
  #my $date = "$year\-$mon\-$mday";

  #$px_info_href->{announceDatae} = $date; 
  $px_info_href->{subm_name} = 'Zhi Sun';
  $px_info_href->{subm_email} = 'zhi.sun@systemsbiology.org';
  $px_info_href->{datasetIdentifier} = $args{RPX_accession}; 
	$px_info_href->{submitter_organization} = 'Institute for Systems Biology'; 
	$px_info_href->{lab_head_full_name} = 'Eric Deutsch';
	$px_info_href->{lab_head_email} = 'edeutsch@systemsbiology.org'; 
	$px_info_href->{lab_head_organization} = 'Institute for Systems Biology';
	$px_info_href->{lab_head_country} = '';
  $px_info_href->{hostingRepository} = 'PeptideAtlas';
  $px_info_href->{expt_description} = $result->{DatasetSummary}{Description} ." Reprocessed by PeptideAtlas;";
  $px_info_href->{expt_title} = 'Reprocessed: ' . $result->{DatasetSummary}{title};
  $px_info_href->{ReviewLevel} = 'not peer reviewed';  
  $px_info_href->{RepositorySupport} = 'Supported  dataset by repository';
  $px_info_href->{DatasetOrigin} = $args{PXD_accession};
  $px_info_href->{organism_name} = $result->{SpeciesList}{Species}{cvParam}{'taxonomy: scientific name'}{value};
  $px_info_href->{ncbi_taxonomy_id} = $result->{SpeciesList}{Species}{cvParam}{'taxonomy: NCBI TaxID'}{value};
  $px_info_href->{instrument_name} = $result->{InstrumentList}{Instrument}{cvParam}{name};
  #@{$px_info_href->{modifications_href}} = '';

  $px_info_href->{pub_status} = 'unpublished';
  push @{$px_info_href->{curator_keywords_aref}}, $result->{KeywordList}{cvParam}{value} ;
  my @list = split(",",$PA_accession);
  my @tmp;
  my $cnt = '';
  foreach my $acc (@list){
    push @tmp , "PeptideAtlas_raw";
    push @tmp , "ftp://ftp.peptideatlas.org/pub/PeptideAtlas/Repository/$acc";
    $cnt++;
  }
  $px_info_href->{fulldatasetlinks_aref} = \@tmp;
  @{$px_info_href->{datasetfiles_aref}} = ();
  @{$px_info_href->{repositoryrecords_aref}} = ();
  ## get modification from iprophet file
	my @mod_hash = ();
  foreach my $acc (@list){
    my $sql = qq~
      SELECT S.SAMPLE_ACCESSION,
      ASB.DATA_LOCATION + '/' + ASB.SEARCH_BATCH_SUBDIR
			FROM $TBAT_SAMPLE S
			JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON ( S.SAMPLE_ID = ASB.SAMPLE_ID)
      WHERE S.SAMPLE_ACCESSION = '$acc'
    ~;
    my %data_location = $sbeams->selectTwoColumnHash($sql);
    my $dir = '/regis/sbeams/archive/'.$data_location{$acc} ;
    if ($dir) {
			opendir DIR, $dir;
			my @mods ;
			while(my $entry = readdir DIR) {
				next if($entry !~ /.xml$/ || $entry =~ /prot/ || ! -e "$dir/$entry");
				print "Checking $entry for mods\n" if $VERBOSE >2;
				@mods  = `egrep '<aminoacid_modification|search_engine|<terminal_modification' $dir/$entry`;
				last;
			}
			my $nmods = scalar @mods;
			print "Found $nmods mods\n" if $VERBOSE >1;
			foreach my $mod (@mods){
				my $residue;
				my $mass;
				print "$mod\n" if $VERBOSE > 2;
				if($mod =~ /(aminoacid|terminus)="(\w)" massdiff="([\d\.]+)" mass="([\d\.]+)".*variable="."/){
					$residue = $2;
					$mass = sprintf "%d", int($3 + 0.5);
					print "Parsed a mod! $residue $mass\n" if $VERBOSE > 1;
					@mod_hash = ( @mod_hash, get_modification_hash(residue=>$residue,mass=>$mass,) ) ;
				}
      }
    }
  }
  my %mod_hash = @mod_hash;
  $px_info_href->{modifications_href} = \%mod_hash;
}


sub get_PASSEL_info {
  my %args = @_;
  my $expt_id = $args{expt_id};
  my $px_info_href = $args{px_info_href};
  
  # Check that this experiment exists; get title and sample_accession
  my $query = qq~
  SELECT sele.experiment_title, s.sample_accession
  FROM $TBAT_SEL_EXPERIMENT sele
  JOIN $TBAT_SAMPLE s
  on s.sample_id = sele.sample_id
  WHERE sele.SEL_experiment_id = '$expt_id';
  ~;
  my @rows = $sbeams->selectSeveralColumns($query);
  if (! @rows) {
    print "${PROG_NAME}: No such experiment $expt_id\n";
    exit();
  }
  my ($expt_title, $sample_accession) = @{$rows[0]};

  $px_info_href->{expt_title} = $expt_title;

  # Get sample infos
  get_sample_info (
    sample_accession => $sample_accession,
    px_info_href => $px_info_href,
  );

  # Get additional info from PASS
  get_PASS_info (
    expt_id => $expt_id,
    px_info_href => $px_info_href,
  );

  # Get info on publications
  get_publication_info (
    px_info_href => $px_info_href,
  );

  # Get modifications from PASS description file
  my ( $residue, $mass, @mod_hash );
  my $mod_string = $px_info_href->{PASS_mod_string};
  while ($mod_string =~ /([A-Z])([+-]\d{1,3})/g) {
    $residue = $1;
    $mass = $2;
    @mod_hash = ( @mod_hash, get_modification_hash(residue=>$residue,mass=>$mass,) ) ;
  }
  if (($mod_string =~ /(0.997)/) || ($mod_string =~ /(1.994)/) ||
    ($mod_string =~ /(2.991)/) || ($mod_string =~ /(3.988)/)) {
    $mass = int($1 + 0.5);
    @mod_hash = ( @mod_hash, get_modification_hash(residue=>'',mass=>$mass,) ) ;
  }
  my %mod_hash = @mod_hash;
  $px_info_href->{modifications_href} = \%mod_hash;

  # Fill in some generic keywords
  $px_info_href->{curator_keywords_aref} = ['selected reaction monitoring', 'SRM', 'targeted'];

  # Construct and store the dataset links
  $px_info_href->{fulldatasetlinks_aref} = [
  "PASSEL_raw",
    "http://www.PeptideAtlas.org/PASS/$px_info_href->{datasetIdentifier}",
  "PASSEL_experiment",
    "https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetSELExperiments?SEL_experiment_id=$expt_id",
  "PASSEL_results",
    "https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetSELTransitions?row_limit=5000&SEL_experiments=$expt_id&QUERY_NAME=AT_GetSELTransitions&action=QUERY&uploaded_file_not_saved=1&apply_action=QUERY",
  ];

  # Get other information TODO
  $px_info_href->{pi_affiliation} = '';
  $px_info_href->{subm_affiliation} = '';
  $px_info_href->{datasetfiles_aref} = [];
  $px_info_href->{repositoryrecords_aref} = [];
}


sub get_PeptideAtlas_info {
  my %args = @_;
  my $PA_accession = $args{PA_accession};
  my $px_info_href = $args{px_info_href};

  # Check that this sample exists; get title
  my $query = qq~
  SELECT sample_title
  FROM $TBAT_SAMPLE
  WHERE sample_accession = '$PA_accession';
  ~;
  my ($sample_title) = $sbeams->selectOneColumn($query);
  if (! $sample_title) {
    print "${PROG_NAME}: No such sample $PA_accession\n";
    exit();
  }
  $px_info_href->{expt_title} = $sample_title;

  # Get sample infos
  get_sample_info (
    sample_accession => $PA_accession,
    px_info_href => $px_info_href,
  );

  # Get info on publications
  get_publication_info (
    px_info_href => $px_info_href,
  );

  # Get modifications from search results
  $px_info_href->{modifications_href} = {};
  my $dir = $px_info_href->{data_directory};
  if ($dir) {
    opendir DIR, $dir;
    my @mods ;
    while(my $entry = readdir DIR) {
      next if($entry !~ /.xml$/ || $entry =~ /prot/ || ! -e "$dir/$entry");
      print "Checking $entry for mods\n" if $VERBOSE >2;
      @mods  = `egrep '<aminoacid_modification|search_engine|<terminal_modification' $dir/$entry`;
      last;
    }
    my $nmods = scalar @mods;
    print "Found $nmods mods\n" if $VERBOSE >1;
    my @mod_hash = ();
    foreach my $mod (@mods){
      my $residue;
      my $mass;
      print "$mod\n" if $VERBOSE > 2;
      if($mod =~ /(aminoacid|terminus)="(\w)" massdiff="([\d\.]+)" mass="([\d\.]+)".*variable="."/){
				$residue = $2;
				$mass = sprintf "%d", int($3 + 0.5);
				print "Parsed a mod! $residue $mass\n" if $VERBOSE > 1;
				@mod_hash = ( @mod_hash, get_modification_hash(residue=>$residue,mass=>$mass,) ) ;
      }
    }
    my %mod_hash = @mod_hash;
  }

  # Fill in some generic keywords
  $px_info_href->{curator_keywords_aref} = ['tandem mass spectrometry', 'LC-MS/MS', 'shotgun'];

  # Construct and store the dataset links
  $px_info_href->{fulldatasetlinks_aref} = [
  "PeptideAtlas_catalog",
    "http://www.peptideatlas.org/repository",
  "PeptideAtlas_raw",
    "ftp://ftp.peptideatlas.org/pub/PeptideAtlas/Repository/${PA_accession}/",
  ];


  # Get other information TODO
  $px_info_href->{pi_affiliation} = '';
  $px_info_href->{subm_affiliation} = '';
  $px_info_href->{datasetfiles_aref} = [];
  $px_info_href->{repositoryrecords_aref} = [];
}


# Given a residue and a massdiff, push a string and a code onto
# an array. Strings & codes come from PSI OBO.
# http://www.ontobee.org/browser/rdf.php?o=MI&iri=http://purl.obolibrary.org/obo/MI_0192
sub get_modification_hash {
  my %args = @_;
  my $residue = $args{residue};
  my $massdiff = $args{mass};
  my @mods = ();
  if($residue =~ /(K|Y)/ && $massdiff == 144){
    push (@mods, 'iTRAQ4plex-114 reporter+balance reagent acylated residue', '01485');
  }
  #if($residue eq 'Y' && $massdiff = 144){
  #  push (@mod, 'iTRAQ4plex-114 reporter+balance reagent O4\'-acylated tyrosine', '1488');
  #}
  #if($residue eq 'n' && $massdiff = 144){
  #  push (@mod , 
  #}
  if($residue eq 'n' && $massdiff == 42){
    push (@mods, 'acetylated residue' , '00394');
  }
  if ($residue eq 'C' && $massdiff == 57) {
    push ( @mods, 'S-carboxamidomethyl-L-cysteine' , '01060' );
  }
  if($residue eq 'C' && $massdiff == 58){
    push (@mods, 'iodoacetic acid derivatized amino-terminal residue', '01084');
  }
  if ($residue eq 'C' && $massdiff == 105) {
    push ( @mods, 'L-selenocysteine (Cys)', '00686' );
    push ( @mods, 'iodoacetamide derivatized residue', '00397' );
  }
  if ($residue eq 'M' && $massdiff == 16) {
    push ( @mods, 'L-methionine sulfoxide', '00719' );
  }
  if ($residue eq 'K' && $massdiff == 6) {
    push ( @mods, '6x(13)C labeled L-lysine', '01334' );
  }
  if ($residue eq 'K' && $massdiff == 8) {
    push ( @mods, '6x(13)C,2x(15)N labeled L-lysine', '00582' );
  }
  if ($residue eq 'K' && $massdiff == 42){
    push ( @mods, 'N2-acetyl-L-lysine', '00057'); 
  }
  if ($residue eq 'K' && $massdiff == 68){
    push ( @mods, 'N6-crotonyl-L-lysine', '01892');
  }

  if ($residue eq 'R' && $massdiff == 6) {
    push ( @mods, '6x(13)C labeled L-arginine', '01331' );
  }
  if ($residue eq 'R' && $massdiff == 10) {
    push ( @mods, '6x(13)C,4x(15)N labeled L-arginine', '00587' );
  }
  if ($residue eq 'S' && ($massdiff == 80 || $massdiff == 79)) {
    push ( @mods, 'O-phospho-L-serine', '00046' );
  }
  if ($residue eq 'L' && $massdiff == 6) {
    push ( @mods, '6x(13)C labeled L-leucine', '01332' );
  }
  if (($massdiff >= 1) && ($massdiff <= 4)) {
    push ( @mods, 'isotope labeled residue', '00702' );
  }

  return @mods;
}


sub get_publication_info {
  my %args = @_;
  my $px_info_href = $args{px_info_href};
  my $publication_ids = $px_info_href->{publication_ids};

# We have publication_id numbers, now get info on each publication.

# If there is a publication record ($px_info_href->{pub_status} eq 'published), use that.
#  (and if no PubMed ID, call it pending).
# Else, call it unpublished.

# Check publication IDs to see if any are submitted (79) or unpublished (62).
  # If yes, record the fact and remove these IDs from the list.
# 12/07/12: we are retiring the use of submitted.
  my @publication_ids = split (",", $publication_ids);
  my %pubid_hash = map { $_ => 1 } @publication_ids;
  $px_info_href->{pub_status} = 'unpublished'; #default to unpublished
  if ($pubid_hash{79}) {
    $px_info_href->{pub_status} = 'submitted';
    delete $pubid_hash{79};
  } elsif ($pubid_hash{62}) {
    $px_info_href->{pub_status} = 'unpublished';
    delete $pubid_hash{62};
  }
  # If there are any publication IDs left, they are for real publications.
  if (scalar keys %pubid_hash) {
    if ($VERBOSE>1) {
      print "Publication IDs: ";
      for my $key (keys %pubid_hash) {
				print "$key ";
      }
      print "\n";
    }
    $px_info_href->{pub_status} = 'published';
  } else {
    if ($VERBOSE>1) {
      print "No publication IDs other than 62 or 79.\n";
    }
  }

  print "Publication record in PeptideAtlas is $px_info_href->{pub_status}\n" if $VERBOSE;

  # If we have actual publications ...
  if ($px_info_href->{pub_status} eq 'published') {
    # for each publication_id, store relevant infos in px_info hash
    for my $pub (keys %pubid_hash) {
      my $query = qq~
      SELECT pubmed_ID, publication_name, keywords, title, author_list, journal_name,
      published_year, volume_number, issue_number, page_numbers, uri, abstract
      FROM $TBAT_PUBLICATION
      WHERE publication_id = '$pub'
      ~;
      my @rows = $sbeams->selectSeveralColumns($query);
      my $pub_aref = $rows[0]; #TODO do we know for sure there's only one?
      print "$pub_aref->[1] \n";
      if ($pub_aref->[0] eq '' && $pub_aref->[3]  eq '' && $pub_aref->[1] ne ''){
        $px_info_href->{pub_href}->{$pub}->{refline} .= "$pub_aref->[1]";
        next;
      }
      $px_info_href->{pub_href}->{$pub} = {};
      $px_info_href->{pub_href}->{$pub}->{pubmed_id} = $pub_aref->[0] || '';
      $px_info_href->{pub_href}->{$pub}->{pub_name} = $pub_aref->[1] || '';
      $px_info_href->{pub_href}->{$pub}->{pub_keywords} = $pub_aref->[2] || '';
      my $pub_title = $pub_aref->[3] || '';
      my $author_list = $pub_aref->[4] || '';
      my $journal_name = $pub_aref->[5] || '';
      my $published_year = $pub_aref->[6] || '';
      my $volume_number = $pub_aref->[7] || '';
      my $issue_number = $pub_aref->[8] || '';
      my $page_numbers = $pub_aref->[9] || '';
      $px_info_href->{pub_href}->{$pub}->{pub_uri} = $pub_aref->[10] || '';
      $px_info_href->{pub_href}->{$pub}->{pub_abstract} = $pub_aref->[11] || '';
      $px_info_href->{pub_href}->{$pub}->{refline} = "$author_list,";
      $px_info_href->{pub_href}->{$pub}->{refline} .= " $pub_title" if $pub_title;
      $px_info_href->{pub_href}->{$pub}->{journal_name} = "$journal_name" if $journal_name;
      $px_info_href->{pub_href}->{$pub}->{refline} .= " $published_year" if $published_year;
      if ($volume_number) {
				$px_info_href->{pub_href}->{$pub}->{refline} .= " $volume_number";
				if ($issue_number) {
					$px_info_href->{pub_href}->{$pub}->{refline} .= "($issue_number)";
					if ($page_numbers) {
						$px_info_href->{pub_href}->{$pub}->{refline} .= ":$page_numbers";
					}
				}
      }
    }
  }
}


sub get_sample_info {
  my %args = @_;
  my $sample_accession = $args{sample_accession};
  my $px_info_href = $args{px_info_href};

  my $query = qq~
  SELECT
  S.sample_description,
  O.full_name,
  O.ncbi_taxonomy_id,
  I.instrument_name,
  C_PROJ.last_name,
  C_PROJ.first_name,
  C_PROJ.middle_name,
  C_PROJ.email,
  C_PROJ.uri,
  C_PROJ.job_title,
  ORG_PROJ.organization,
  S.sample_title,
  S.sample_title,
  S.sample_date,
  S.data_contributors,
  ASB.data_location,
  S.primary_contact_email,
  S.sample_id,
  S.sample_publication_ids,
  ASB.search_batch_subdir,
  I2.instrument_name
  FROM $TBAT_SAMPLE S
  LEFT JOIN $TB_ORGANISM O ON O.organism_id = S.organism_id
  LEFT JOIN $TBPR_INSTRUMENT I ON I.instrument_id = S.instrument_model_id
  LEFT JOIN $TBPR_INSTRUMENT_TYPE IT ON IT.instrument_type_id = I.instrument_type_id
  LEFT JOIN $TB_PROJECT PROJ ON PROJ.project_id = S.project_id
  LEFT JOIN $TB_CONTACT C_PROJ ON C_PROJ.contact_id = PROJ.PI_contact_id
  LEFT JOIN $TB_ORGANIZATION ORG_PROJ ON ORG_PROJ.organization_id = C_PROJ.organization_id
  LEFT JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON ( S.SAMPLE_ID = ASB.SAMPLE_ID)
  LEFT JOIN $TBPR_SEARCH_BATCH  PSB ON (ASB.PROTEOMICS_SEARCH_BATCH_ID = PSB.SEARCH_BATCH_ID)
  LEFT JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON (PSB.EXPERIMENT_ID = PE.EXPERIMENT_ID)
  LEFT JOIN $TBPR_INSTRUMENT I2 ON (PE.INSTRUMENT_ID = I2.INSTRUMENT_ID)
  WHERE S.sample_accession = '$sample_accession'
  ;
  ~;
  print $query if $DEBUG;

  my @rows = $sbeams->selectSeveralColumns($query);
  my $n_rows = scalar @rows;
  print "$n_rows rows returned\n" if $DEBUG;
  my $info_aref = $rows[0];
  $px_info_href->{expt_description} = $info_aref->[0]||'';
  $px_info_href->{expt_description} =~ s/[\r\n]/ /g;
  $px_info_href->{organism_name} = $info_aref->[1] || '';
  $px_info_href->{ncbi_taxonomy_id} = $info_aref->[2] || '';
  my $last_name = $info_aref->[4];
  my $first_name = $info_aref->[5] || '';
  my $middle_name = $info_aref->[6];
  $px_info_href->{pi_name} = $first_name;
  $px_info_href->{pi_name} .= " $middle_name" if $middle_name;
  $px_info_href->{pi_name} .= " $last_name" if $last_name;
  $px_info_href->{pi_email} = $info_aref->[7] || '';
  $px_info_href->{pi_uri} = $info_aref->[8] || '';
  $px_info_href->{pi_job_title} = $info_aref->[9] || '';
  $px_info_href->{pi_organization} = $info_aref->[10] || '';
  $px_info_href->{experiment_title} = $info_aref->[11];
  $px_info_href->{instrument_name} = $info_aref->[3] || $info_aref->[20] || '';
  $px_info_href->{release_date} = $info_aref->[13] || '';
# trim away the time; leave only the date
  $px_info_href->{release_date} =~ /(\d{4}-\d{2}-\d{2}) \d{2}:\d{2}:\d{2}/;
  $px_info_href->{release_date} = $1;
  my @contributors = split(",", $info_aref->[14]);
  $px_info_href->{subm_name} = $contributors[0];
  $px_info_href->{subm_email} = $info_aref->[16];
  my $data_location = $info_aref->[15];
  $px_info_href->{sample_id} = $info_aref->[17] || '';
  $px_info_href->{publication_ids} = $info_aref->[18];
  my $search_batch_subdir = $info_aref->[19];
  if ($data_location && $search_batch_subdir) {
    $px_info_href->{data_directory} =
      '/regis/sbeams/archive/'.${data_location}.'/'.${search_batch_subdir};
    print "dir = $px_info_href->{data_directory}\n" if $DEBUG;
  } else {
    print "Unable to retrieve data_location and/or search_batch_subdir, therefore cannot extract mods from search result files.\n";
  }
}


sub get_PASS_info {
  my %args = @_;
  my $expt_id = $args{expt_id};
  my $px_info_href = $args{px_info_href};

  my $query = qq~
  select 
  PASSD.publicReleaseDate,
  PASSS.lastName, PASSS.firstName,
  PASSS.emailAddress,
  PASSD.datasetIdentifier,
  PASSD.submitter_organization,
  PASSD.lab_head_full_name,
  PASSD.lab_head_email,
  PASSD.lab_head_organization,
  PASSD.lab_head_country
  FROM $TBAT_SEL_EXPERIMENT SELE
  JOIN $TBAT_PASS_DATASET PASSD
  ON PASSD.datasetIdentifier = SELE.datasetIdentifier
  JOIN $TBAT_PASS_SUBMITTER PASSS
  ON PASSS.submitter_id = PASSD.submitter_id
  WHERE SELE.SEL_experiment_id = '$expt_id'
  ~;

  my @rows = $sbeams->selectSeveralColumns($query);
  my $n_rows = scalar @rows;
  print "$n_rows rows returned\n" if $DEBUG;

  if ($n_rows) {
    my $info_aref = $rows[0];

    $px_info_href->{release_date} = $info_aref->[0] || '';
    # trim away the time; leave only the date
    $px_info_href->{release_date} =~ /(\d{4}-\d{2}-\d{2}) \d{2}:\d{2}:\d{2}/;
    $px_info_href->{release_date} = $1;
    my $last_name = $info_aref->[1];
    my $first_name = $info_aref->[2] || '';
    $px_info_href->{subm_name} = $first_name;
    $px_info_href->{subm_name} .= " $last_name" if $last_name;
    $px_info_href->{subm_email} = $info_aref->[3];
    my $datasetIdentifier = $info_aref->[4] || '';
    $px_info_href->{datasetIdentifier} = $datasetIdentifier;
    $px_info_href->{submitter_organization} = $info_aref->[5] || '';
    $px_info_href->{lab_head_full_name} = $info_aref->[6] || '';
    $px_info_href->{lab_head_email} = $info_aref->[7] || '';
    $px_info_href->{lab_head_organization} = $info_aref->[8] || '';
    $px_info_href->{lab_head_country} = $info_aref->[9] || '';

    ### Parse out some infos from the PASS description file
    my $passdir = "/proteomics/peptideatlas2/home/$datasetIdentifier";
    my $pass_descr = "$passdir/${datasetIdentifier}_DESCRIPTION.txt";
    print "PASS description file is $pass_descr\n" if $VERBOSE;
    my $publication_name;
    my $mod_string;
    open (my $infh, $pass_descr) || die "Can't open $pass_descr for reading.\n";
    while (my $line = <$infh>) {
      chomp $line;
      $line =~ s/[\r\n]+//g;  # get rid of all flavors of newlines
      if ($line =~ /^publication:\t(.*)/) {
				$publication_name = $1;
      } elsif ($line =~ /^massModifications:\t(.*)/) {
				$mod_string = $1;
      }
    }
    $px_info_href->{PASS_publication_name} = $publication_name;
    $px_info_href->{PASS_mod_string} = $mod_string;
    print "PASS publication: $publication_name\n" if $VERBOSE;
    print "PASS mods: $mod_string\n" if $VERBOSE;
    close $infh;
  } else {
    print "Could not retrieve PASS info for experiment $expt_id.\n";
  }
}



# Merge the info from one dataset with the combined info of those datasets
# processed so far.
sub merge_px_info {
  my $combined_px_info_href = shift;
  my $new_px_info_href = shift;

  # 02/27/13: For now, just add any additional FullDatasetLinks that
  #   reference raw data or results, and merge descriptions.
  #  Assume that, if we are merging multiple experiments or datasets
  #  into a single ProteomeXchange submission, they will share
  #  identical publication(s), keywords, species, instruments,
  #  modifications, and contacts.

  # if the combined hash is non-empty, then add new infos to it
  if (%{$combined_px_info_href}) {

    # add dataset links
    my %new_fulldatasetlinks_hash =
      @{$new_px_info_href->{fulldatasetlinks_aref}};

    for my $name (keys %new_fulldatasetlinks_hash) {
      my $value = $new_fulldatasetlinks_hash{$name};
      if (($name =~ /_raw/) || ($name =~ /_results/)) {
				push ( @{$combined_px_info_href->{fulldatasetlinks_aref}}, $name, $value);
      }
    }

    # add descriptions
    $combined_px_info_href->{expt_description} .= " ### " .
      $new_px_info_href->{expt_description}
      unless $combined_px_info_href->{expt_description} eq
	$new_px_info_href->{expt_description};

  # otherwise, just copy the entire new hash to the combined hash
  # because the "new" one is the first.
  } else {
    $combined_px_info_href = $new_px_info_href;
  }

  return $combined_px_info_href;
}


# Write XML
sub write_PX_XML {

  my %args = @_;
  my $px_info_href = $args{px_info_href};
  my $title = $args{title} || $px_info_href->{expt_title};
  my $PX_accession = $args{PX_accession};
  my $PX_version = $args{PX_version};
  my $original_PX_acc = $args{original_PX_acc} || '';
  my $changeLog = $args{changeLog} || '';
  my $cv_acc;
  my $cv_ref;


  ###
  ### Header stuff
  ###
  $writer->xmlDecl("UTF-8");

  $writer->startTag("ProteomeXchangeDataset",
    "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
    "xsi:noNamespaceSchemaLocation"=>"proteomeXchange-1.2.0.xsd",
    "id"=>"${PX_accession}.${PX_version}",
    "formatVersion"=>"1.2.0",
  );

     
         
#--------------------------------------------------
# $writer->startTag("ChangeLog");
#   $writer->startTag("ChangeLogEntry",
#   "version" => 1,
#   "date" => "2012-05-18" ,);
#     $writer->characters("Initial submission");
#   $writer->endTag("ChangeLogEntry");
# $writer->endTag("ChangeLog");
#-------------------------------------------------- 
  my ($sec,$min,$hour,$mday,$mon,$year,
    $wday,$yday,$isdst) = gmtime time;
  $year += 1900;
  $mon++;
  my $today_gmt_date = sprintf "%4d-%02d-%02d", $year, $mon, $mday;
  $writer->startTag("CvList");
  $writer->emptyTag("Cv",
            id => 'MS' ,
            fullName => 'PSI-MS',
            version => "4.1.12",
            uri => "https://raw.githubusercontent.com/HUPO-PSI/psi-ms-Cv/master/psi-ms.obo",
            );
  $writer->emptyTag("Cv",
            id => 'PRIDE' ,
            fullName=> 'PRIDE Ontology',
            version=> "noVersion", 
            uri=>"http://ebi-pride.googlecode.com/svn/trunk/pride-core/schema/pride_cv.obo",
            );
  $writer->emptyTag("Cv",
            id => 'MOD' ,
            fullName=>"PSI-MOD", 
            version=>"1.2",
            uri=>"https://raw.githubusercontent.com/HUPO-PSI/psi-mod-CV/master/PSI-MOD.obo",
            );
  $writer->emptyTag("Cv",
            id => 'UNIMOD' ,
            fullName=>"UNIMOD",
            version=>"1.2",
            uri=>"http://www.unimod.org/obo/unimod.obo",
            );

  $writer->endTag("CvList");


  if($changeLog){
    $writer->startTag("ChangeLog");
    $writer->startTag("ChangeLogEntry",
       date => "$today_gmt_date",
    );
    $writer->characters("$changeLog");
    $writer->endTag("ChangeLogEntry");
    $writer->endTag("ChangeLog");
  }
  ###
  ### Dataset info
  ###
  $writer->startTag("DatasetSummary",
    "announceDate" => "$today_gmt_date",
    "title" => $title,
    "hostingRepository" => "PeptideAtlas",
  );
  $writer->startTag("Description");
  $writer->characters("$px_info_href->{expt_description}");
  $writer->endTag("Description");

  $writer->startTag("ReviewLevel");
  $cv_ref = 'MS';
  $cv_acc = $OPTIONS{'npr'} ? '1002855': '1002854';
  my $cv_name = $OPTIONS{'npr'} ? "Non peer-reviewed dataset" :
  "Peer-reviewed dataset";
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>$cv_name,
  );
  $writer->endTag("ReviewLevel");

  ### OR 0000417 for Unsupported dataset by repository
  $writer->startTag("RepositorySupport");
  $cv_ref = 'MS';
  $cv_acc = '1002856';
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"Supported dataset by repository",
  );
  $writer->endTag("RepositorySupport");

  $writer->endTag("DatasetSummary");

  $writer->startTag("DatasetIdentifierList");
  $writer->startTag("DatasetIdentifier");
  $cv_ref = "MS";
  $cv_acc = 1001919;
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"ProteomeXchange accession number",
    "value"=>"$PX_accession",
  );
  $cv_ref = "MS";
  $cv_acc = 1001921;
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"ProteomeXchange accession number version number",
    "value"=>"$PX_version",
  );
  $writer->endTag("DatasetIdentifier");
  $writer->endTag("DatasetIdentifierList");

  # Another option is 0000397 Data derived from previous dataset
  $writer->startTag("DatasetOriginList");
  $writer->startTag("DatasetOrigin");
  $cv_ref = 'MS';
  if($PX_accession =~ /^RPX[DT]/){
    $cv_acc = '1002863';
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"Data derived from previous dataset",
    );
		$cv_ref = "MS";
		$cv_acc = "1001919";
		$writer->emptyTag("cvParam",
			"cvRef"=>"$cv_ref",
			"accession"=>"${cv_ref}:$cv_acc",
			"name"=>"ProteomeXchange accession number",
			"value"=>"$original_PX_acc",
		);
  }else{
		$cv_acc = '0000402';
		$writer->emptyTag("cvParam",
			"cvRef"=>"$cv_ref",
			"accession"=>"${cv_ref}:$cv_acc",
			"name"=>"Original data",
		);
		#$cv_ref = "MS";
		#$cv_acc = "1001919";
		#$writer->emptyTag("cvParam",
		#	"cvRef"=>"$cv_ref",
		#	"accession"=>"${cv_ref}:$cv_acc",
		#	"name"=>"ProteomeXchange accession number",
		#	"value"=>"${PX_accession}",
		#);
  }
  $writer->endTag("DatasetOrigin");
  $writer->endTag("DatasetOriginList");


  ###
  ### Species
  ###
  $writer->startTag("SpeciesList");
  $writer->startTag("Species");
  $cv_ref = "MS";
  $cv_acc = 1001469;
  $writer->emptyTag("cvParam",
    "cvRef"=>$cv_ref,
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"taxonomy: scientific name",
    "value"=>"$px_info_href->{organism_name}",
  );
  $cv_acc = 1001467;
  $writer->emptyTag("cvParam",
    "cvRef"=>$cv_ref,
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"taxonomy: NCBI TaxID",
    "value"=>"$px_info_href->{ncbi_taxonomy_id}",
  );
  $writer->endTag("Species");
  $writer->endTag("SpeciesList");


  ###
  ### Instruments
  ###
  ### http://www-bs2.informatik.uni-tuebingen.de/services/OpenMS/analysisXML/psi-ms.obo
  my $instrument_id;
  my $instrument_name = $px_info_href->{instrument_name};
  if ($instrument_name =~ /q.{0,1}tof/i) {
    $instrument_id = "Q-ToF";
  } elsif ($instrument_name =~ /q.{0,1}trap/i) {
    $instrument_id = "Q-Trap";
  } elsif ($instrument_name =~ /triple.*quad/i) {
    $instrument_id = "QQQ";
  } elsif ($instrument_name =~ /tsq/i or $instrument_name =~ /vantage/i) {
    $instrument_id = "TSQ";
  } else {
    $instrument_id = "other";
  }

  $writer->startTag("InstrumentList");
  $writer->startTag("Instrument", "id"=>"$instrument_id");
  $cv_ref = "MS";
  #$cv_acc = 1000870;
  my %instrument_cv_acc = (
    '4000 QTRAP' => 1000139,
    '4000 Q-Trap' => 1000139,
    '6500 QTRAP' => 1002581,
    'Q TRAP' => 1000187,
    'Q-Tof micro' => 1000189,
    'QSTAR' => 1000190,
    'TSQ Quantum' => 1000199,
    'TSQ Vantage' => 1001510,
    'LTQ' => 1000447,
    'LTQ FT' => 1000448,
    'LTQ Orbitrap' => 1000449,
    'LTQ Orbitrap XL' => 1000556,
    'LTQ FT Ultra' => 1000557,
    'QSTAR Elite' => 1000655,
    'QSTAR XL' => 1000657,
    'QTRAP 5500' => 1000931,
    'TripleTOF 5600' => 1000932,
    '6420 Triple Quadrupole LC/MS' => 1002444,
    '6410 Triple Quadrupole LC/MS' => 1000477,
    '6460 Triple Quadrupole LC/MS' => 1002445,
    '6490 Triple Quadrupole LC/MS' => 1002446, 
    'LTQ Orbitrap Velos' => 1001742,
    'Xevo TQ-S' => 1001792,
  );
  if($instrument_name =~ /AB SCIEX 5500 QTrap/){
    $instrument_name = 'QTRAP 5500';
  }
  
  if(defined $instrument_cv_acc{$instrument_name}){
    $cv_acc = $instrument_cv_acc{$instrument_name};
		$writer->emptyTag("cvParam",
			"cvRef"=>"$cv_ref",
			"accession"=>"${cv_ref}:$cv_acc",
			"name"=>"$instrument_name",
		);
  }else{
    die "cannot find cv_acc for $instrument_name\nplease look up here\n".
        "http://www-bs2.informatik.uni-tuebingen.de/services/OpenMS/analysisXML/psi-ms.obo\n";
  }


  $writer->endTag("Instrument");
  $writer->endTag("InstrumentList");


  ###
  ### Modifications
  ###
  $writer->startTag("ModificationList");
  if (! scalar keys %{$px_info_href->{modifications_href}}) {
    $cv_ref = "MS";
    $cv_acc = '1002864';
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"No PTMs are included in the dataset",
    );
  } else {
    for my $mod (keys %{$px_info_href->{modifications_href}}) {
      $cv_acc = $px_info_href->{modifications_href}->{$mod};  #need
      $writer->emptyTag("cvParam",
			"cvRef"=>'MOD',
			"accession"=>"MOD:$cv_acc",
			"name"=>"$mod",
      );
    }
  }
  $writer->endTag("ModificationList");


  ###
  ### Contacts
  ###
  $writer->startTag("ContactList");
  $writer->startTag("Contact", "id"=>"c001");
  $cv_ref = "MS";
  #$cv_acc = 1001266;
  $cv_acc = 1002332;
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"lab head", 
  );
  if (defined $px_info_href->{lab_head_full_name}) {
    $cv_acc = 1000586;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact name",
      "value"=>"$px_info_href->{lab_head_full_name}",
    );
  }
  if (defined $px_info_href->{lab_head_organization}) {
    $cv_acc = 1000590;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      #"name"=>"contact affiliation", not found
      "name"=>"contact affiliation",
      "value"=>"$px_info_href->{lab_head_organization}",
    );
  }
  if (defined $px_info_href->{lab_head_email}) {
    $cv_acc = 1000589;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact email",
      "value"=>"$px_info_href->{lab_head_email}",
    );
  }
#--------------------------------------------------
#   $cv_acc = 1000588;
#   $writer->emptyTag("cvParam",
#     "cvRef"=>"$cv_ref",
#     "accession"=>"${cv_ref}:$cv_acc",
#     "name"=>"contact URL",
#     "value"=>"$px_info_href->{pi_uri}",
#   );
#-------------------------------------------------- 
  $writer->endTag("Contact");
  $writer->startTag("Contact", "id"=>"c002");
  $cv_acc = 1002037;
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"dataset submitter",
  );
#--------------------------------------------------
#   $cv_acc = 1000000;  #need
#   $writer->emptyTag("cvParam",
#     "cvRef"=>"$cv_ref",
#     "accession"=>"${cv_ref}:$cv_acc",
#     "name"=>"contact role",
#     "value"=>"Data submitter",
#   );
#-------------------------------------------------- 
  $cv_acc = 1000586;
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"contact name",
    "value"=>"$px_info_href->{subm_name}",
  );
  if (defined $px_info_href->{submitter_organization}) {
    $cv_acc = 1000590;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact affiliation",
      "value"=>"$px_info_href->{submitter_organization}",
    );
  }
  $cv_acc = 1000589;
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"contact email",
    "value"=>"$px_info_href->{subm_email}",
  );
#--------------------------------------------------
#     $cv_acc = 1000588;
#     $writer->emptyTag("cvParam",
#       "cvRef"=>"$cv_ref",
#       "accession"=>"${cv_ref}:$cv_acc",
#       "name"=>"contact URL",
#       "value"=>"$px_info_href->{subm_uri}",
#     );
#-------------------------------------------------- 
  $writer->endTag("Contact");
  $writer->endTag("ContactList");


  ###
  ### Publications
  ###
  $writer->startTag("PublicationList");

# Accepted manuscript is 0000399 ( for possible future reference )

  if ($px_info_href->{pub_status} eq 'published') {
    for my $pub (keys %{$px_info_href->{pub_href}}) {

      my $ph = $px_info_href->{pub_href}->{$pub};

      my $refline = $ph->{refline};
      $refline =~ s/[\r\n]+//g;  # get rid of all flavors of newlines

      # If pub_name has "submitted", then alone should be our refline.
      #   ?????
      #if ($ph->{pub_name} !~ /submitted/i) {
      if ($ph->{pubmed_id}) {
				print "Pubmed ID is $ph->{pubmed_id}\n" if $VERBOSE;
				$writer->startTag("Publication", "id"=>"PMID$ph->{pubmed_id}");
				$cv_ref = "MS";
				$cv_acc = 1000879;
				$writer->emptyTag("cvParam",
					"cvRef"=>"$cv_ref",
					"accession"=>"${cv_ref}:$cv_acc",
					"name"=>"PubMed identifier",
					"value"=>$ph->{pubmed_id},
				);
      # Show as "submitted" if no PubMed ID (not exactly correct
      #  because pubmed ID is delayed somewhat after publication)
      } else {
				$writer->startTag("Publication", "id"=>"submitted01");
				$cv_ref = "MS";
				$cv_acc = "1002858";   
				$writer->emptyTag("cvParam",
					"cvRef"=>"$cv_ref",
					"accession"=>"${cv_ref}:$cv_acc",
					"name"=>"Dataset with its publication pending",
				); 
        $refline =~ s/\s?\(\d{4}\)/, submitted/;
      }
      $cv_ref = "MS";
      $cv_acc = "1002866";
      $writer->emptyTag("cvParam",
				"cvRef"=>"$cv_ref",
				"accession"=>"${cv_ref}:$cv_acc",
				"name"=>"Reference",
				"value"=>"$refline",
      );
      $writer->endTag("Publication");
    }
  } elsif ($px_info_href->{pub_status} eq 'submitted' &&
           $px_info_href->{publication_name} &&
           $px_info_href->{publication_name} !~ /unpublished/i &&
			 $px_info_href->{publication_name} !~ /not published/i) {
				$writer->startTag("Publication", "id"=>"submitted01");
				$cv_ref = "MS";
				$cv_acc = "1002858";    # need to update in future
				$writer->emptyTag("cvParam",
				"cvRef"=>"$cv_ref",
				"accession"=>"${cv_ref}:$cv_acc",
				"name"=>"Dataset with its publication pending",
			);
			$cv_ref = "MS";
			$cv_acc = "1002866";
			$writer->emptyTag("cvParam",
				"cvRef"=>"$cv_ref",
				"accession"=>"${cv_ref}:$cv_acc",
				"name"=>"Reference",
				"value"=>"$px_info_href->{publication_name} , submitted",
    );
    $writer->endTag("Publication");

  } else {
    $writer->startTag("Publication", "id"=>"unpublished01");
    $cv_ref = "MS";
    $cv_acc = '1002853';
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"Dataset with no associated published manuscript",
    );
    $writer->endTag("Publication");
  }
  $writer->endTag("PublicationList");


  ###
  ### Keywords
  ###
  # Assume there are at least some keywords,
  #  and open a KeywordList element.
  $writer->startTag("KeywordList");
  # Print the curator keywords
  for my $keyword ( @{$px_info_href->{curator_keywords_aref}} ) {
    $cv_ref = "MS";
    $cv_acc = 1001926;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"curator keyword",
      "value"=>"$keyword",
    );
  }
  # Create and print a combined list of keywords from all publications
  my @pub_keywords;
  for my $pub (keys %{$px_info_href->{pub_href}}) {
    @pub_keywords = ( @pub_keywords, split (",",
	$px_info_href->{pub_href}->{$pub}->{pub_keywords}) );
  }

  for my $keyword ( @pub_keywords  ) {
    $cv_acc = 1001924;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"journal article keyword",
      "value"=>"$keyword",
    );
  }
  $writer->endTag("KeywordList");

  ###
  ### Dataset links.
  ###
  $writer->startTag("FullDatasetLinkList");
  $cv_ref = "MS";
  $cv_acc = 1000000;  #for those cvParams not yet official

  # This is a clunky, non-extensible way to handle the possible dataset links.
  my %uri_string = (
    PeptideAtlas_catalog =>
      "PeptideAtlas dataset repository catalog URI",
    PeptideAtlas_raw =>
      "PeptideAtlas dataset URI",
    PASSEL_experiment =>
      "PASSEL experiment URI",
    PASSEL_results =>
      "PASSEL transition group browser URI",
    PASSEL_raw =>
      "PeptideAtlas dataset URI",
  );

  my @name_link_pairs = @{$px_info_href->{fulldatasetlinks_aref}};
  while ( my $name = shift @name_link_pairs) {
    my $value = shift @name_link_pairs;
    # Here is the clunky part.
    $cv_acc = 1002031 if ($name =~ /PASSEL_results/);
    $cv_acc = 1002032 if ($name =~ /_raw/);
    $cv_acc = 1002420 if ($name =~ /PASSEL_experiment/);
    $writer->startTag("FullDatasetLink");
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>$uri_string{$name},
      "value"=>$value,
    );
    $writer->endTag("FullDatasetLink");
  }
  $writer->endTag("FullDatasetLinkList");

  my @datasetfiles = @{$px_info_href->{datasetfiles_aref}};
  if (scalar @datasetfiles) {
    $writer->startTag("DatasetFileList");
    for my $file (@datasetfiles) {
      $writer->startTag("DatasetFile");
      $writer->endTag("DatasetFile");
    }
    $writer->endTag("DatasetFileList");
  }


  ###
  ### Repository records TODO
  ###
  my @repositoryrecords = @{$px_info_href->{repositoryrecords_aref}};
  if (scalar @repositoryrecords) {
    $writer->startTag("RepositoryRecordList");
    for my $file (@repositoryrecords) {
      $writer->startTag("RepositoryRecord");
      $writer->endTag("RepositoryRecord");
    }
    $writer->endTag("RepositoryRecordList");
  }

#--------------------------------------------------
# $writer->startTag("SourceFileRef");
# $writer->startTag("PublicationRef");
# $writer->startTag("InstrumentRef");
# $writer->startTag("SampleList");
# $writer->startTag("Sample");
# $writer->startTag("AnnotationList");
# $writer->startTag("AdditionalInformation");
#-------------------------------------------------- 

  $writer->endTag("ProteomeXchangeDataset");
  $writer->end();
}
