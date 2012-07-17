#!/usr/local/bin/perl

###############################################################################
# Program      : PASSEL2ProteomeXchange.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
#  For a given PASSEL SEL_experiment_id, retrieve some info about
#   that experiment and output a ProteomExchange submission XML file.
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
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --expt_id                   PASSEL SEL_experiment_id (required)
  --PX_accession              ProteomeXchange accession (required)
  --PX_version                Version number (default 1)

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly","help",
        "expt_id:i", "PX_accession:s", "PX_version:i",
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
if (! $expt_id) {
  print "${PROG_NAME}: expt_id required.\n";;
  print $USAGE;
  exit;
}
  
my $PX_accession = $OPTIONS{"PX_accession"};
if (! $PX_accession) {
  print "${PROG_NAME}: PX_accession required.\n";;
  print $USAGE;
  exit;
}

my $PX_version = $OPTIONS{"PX_version"} || 1;
  

###############################################################################
###
### Main section: Get info and write into the ProteomeXchange submission XML file
###
###############################################################################

# Check that this experiment exists
my $query = qq~
  SELECT experiment_title
  FROM $TBAT_SEL_EXPERIMENT
  WHERE SEL_experiment_id = '$expt_id';
~;

my ($title) = $sbeams->selectOneColumn($query);
if (! $title) {
  print "${PROG_NAME}: No such experiment $expt_id\n";
  exit();
}

my $output = IO::File->new(">PASSEL_ProteomeXchange_submission_${PX_accession}.xml");
my $writer = XML::Writer->new(
  OUTPUT=>$output,
  DATA_MODE=>1,
  DATA_INDENT=>2,
  # The below ends up expanding 2-byte special chars into double
  # 2-byte chars. Go figure. Removing it seems to do no harm.
  #ENCODING=>'UTF-8',
);

# Get info on the experiment
my $query = qq~
  SELECT
    S.sample_description,
    O.full_name,
    O.ncbi_taxonomy_id,
    I.instrument_name,
    C_PROJ.last_name, C_PROJ.first_name,
    C_PROJ.middle_name,
    C_PROJ.email,
    C_PROJ.uri,
    C_PROJ.job_title,
    ORG_PROJ.organization,
    SELE.experiment_title,
    IT.instrument_type_name,
    PASSD.publicReleaseDate,
    PASSS.lastName, PASSS.firstName,
    PASSS.emailAddress,
    PASSD.datasetIdentifier,
    S.sample_publication_ids
  FROM $TBAT_SEL_EXPERIMENT SELE
  JOIN $TBAT_SAMPLE S
  ON S.sample_id = SELE.sample_id
  JOIN $TB_ORGANISM O
  ON O.organism_id = S.organism_id
  JOIN $TBPR_INSTRUMENT I
  ON I.instrument_id = S.instrument_model_id
  JOIN $TBPR_INSTRUMENT_TYPE IT
  ON IT.instrument_type_id = I.instrument_type_id
  JOIN $TB_PROJECT PROJ
  ON PROJ.project_id = SELE.project_id
  JOIN $TB_CONTACT C_PROJ
  ON C_PROJ.contact_id = PROJ.PI_contact_id
  JOIN $TB_ORGANIZATION ORG_PROJ
  ON ORG_PROJ.organization_id = C_PROJ.organization_id
  JOIN $TBAT_PASS_DATASET PASSD
  ON PASSD.datasetIdentifier = SELE.datasetIdentifier
  JOIN $TBAT_PASS_SUBMITTER PASSS
  ON PASSS.submitter_id = PASSD.submitter_id
  WHERE SELE.sel_experiment_id = $expt_id
  ;
~;

my @rows = $sbeams->selectSeveralColumns($query);
my $n_rows = scalar @rows;
print "$n_rows rows returned\n" if $DEBUG;
my $info_aref = $rows[0];
my $expt_description = $info_aref->[0];
my $organism_name = $info_aref->[1];
my $ncbi_taxonomy_id = $info_aref->[2];
my $instrument_name = $info_aref->[3];
my $last_name = $info_aref->[4];
my $first_name = $info_aref->[5];
my $middle_name = $info_aref->[6];
my $pi_name = $first_name;
$pi_name .= " $middle_name" if $middle_name;
$pi_name .= " $last_name";
my $pi_email = $info_aref->[7];
my $pi_uri = $info_aref->[8];
my $pi_job_title = $info_aref->[9];
my $pi_organization = $info_aref->[10];
my $experiment_title = $info_aref->[11];
my $instrument_type_name = $info_aref->[12];
my $release_date = $info_aref->[13];
# trim away the time; leave only the date
$release_date =~ /(\d{4}-\d{2}-\d{2}) \d{2}:\d{2}:\d{2}/;
$release_date = $1;
$last_name = $info_aref->[14];
$first_name = $info_aref->[15];
my $subm_name = $first_name;
$subm_name .= " $last_name";
my $subm_email = $info_aref->[16];
my $datasetIdentifier = $info_aref->[17];
my $publication_ids = $info_aref->[18];



### Need to get appropriate contact info, perhaps from PASS instead of from
### PeptideAtlas project.

my $pi_affiliation = '';  #TODO
my $subm_affiliation = '';  #TODO

# Get modifications TODO
my @modifications = ();

my $refline = '';
my $pub_status = 'published';
my $pubmed_id = '';

my @curator_keywords = ('selected reaction monitoring', 'SRM', 'targeted');
my @pub_keywords = ();
my @fulldatasetlinks = ();
my @datasetfiles = ();
my @repositoryrecords = ();


# Write XML
my $cv_acc;
my $cv_ref;

$writer->xmlDecl("UTF-8");

$writer->startTag("ProteomeXchangeDataset",
  "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
  "xsi:noNamespaceSchemaLocation"=>"proteomeXchange-draft-07.xsd",
  "id"=>"${PX_accession}.${PX_version}",
  "formatVersion"=>"1.0.0",
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

$writer->startTag("DatasetSummary",
  # What is announceDate? We need this.
  "announceDate" => "$release_date",
  "title" => "HUPO PPP2 PE submission" ,
  "hostingRepository" => "PeptideAtlas",
);
  $writer->startTag("Description");
    $writer->characters("$expt_description");
  $writer->endTag("Description");

  ### OR 0000415 for Non peer-reviewed dataset
  $writer->startTag("ReviewLevel");
      $cv_ref = 'PRIDE';
      $cv_acc = '0000414';
      $writer->emptyTag("cvParam",
	"cvRef"=>"$cv_ref",
	"accession"=>"${cv_ref}:$cv_acc",
	"name"=>"Peer-reviewed dataset",
      );
  $writer->endTag("ReviewLevel");

  ### OR 0000417 for Unsupported dataset by repository
  $writer->startTag("RepositorySupport");
      $cv_ref = 'PRIDE';
      $cv_acc = '0000416';
      $writer->emptyTag("cvParam",
	"cvRef"=>"$cv_ref",
	"accession"=>"${cv_ref}:$cv_acc",
	"name"=>"Supported dataset by respository",
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

$writer->startTag("DatasetOriginList");
  $writer->startTag("DatasetOrigin");
    $cv_ref = 'PRIDE';
    $cv_acc = '0000397';
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
      "value"=>"${PX_accession}",
    );
  $writer->endTag("DatasetOrigin");
$writer->endTag("DatasetOriginList");

$writer->startTag("SpeciesList");
  $writer->startTag("Species");
    $cv_ref = "MS";
    $cv_acc = 1001469;
    $writer->emptyTag("cvParam",
      "cvRef"=>'PSI-MS',
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"taxonomy: scientific name",
      "value"=>"$organism_name",
    );
    $cv_acc = 1001467;
    $writer->emptyTag("cvParam",
      "cvRef"=>'PSI-MS',
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"taxonomy: NCBI TaxID",
      "value"=>"$ncbi_taxonomy_id",
    );
  $writer->endTag("Species");
$writer->endTag("SpeciesList");

$writer->startTag("InstrumentList");
  # not sure instrument_type_name is what we want.
  # The value usually doesn't validate. Seems brief "Q-ToF" or "Q-Trap"
  # is required.
  $writer->startTag("Instrument", "id"=>"$instrument_type_name");
    $cv_ref = "MS";
    $cv_acc = 1000870;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"$instrument_name",
    );
  $writer->endTag("Instrument");
$writer->endTag("InstrumentList");


$writer->startTag("ModificationList");
if (! scalar @modifications) {
  $cv_ref = "PRIDE";
  $cv_acc = '0000398';
  $writer->emptyTag("cvParam",
    "cvRef"=>"$cv_ref",
    "accession"=>"${cv_ref}:$cv_acc",
    "name"=>"No PTMs are included in the dataset",
  );
} else {
  $cv_acc = 1000001;  #need
  for my $mod (@modifications) {
    $writer->emptyTag("cvParam",
      "cvRef"=>'PSI-MOD',
      "accession"=>"PSI-MOD:$cv_acc",
      "name"=>"$mod",
    );
  }
}
$writer->endTag("ModificationList");

$writer->startTag("ContactList");
  $writer->startTag("Contact", "id"=>"c001");
    $cv_ref = "MS";
    $cv_acc = 1001266;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"role type", 
      "value"=>"Principal investigator for project (as listed in PeptideAtlas)",
    );
    $cv_acc = 1000586;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact name",
      "value"=>"$pi_name",
    );
    $cv_acc = 1000590;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      #"name"=>"contact affiliation", not found
      "name"=>"contact organization",
      "value"=>"$pi_affiliation",
    );
    $cv_acc = 1000589;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact email",
      "value"=>"$pi_email",
    );
    $cv_acc = 1000588;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact URL",
      "value"=>"$pi_uri",
    );
  $writer->endTag("Contact");
  $writer->startTag("Contact", "id"=>"c002");
    $cv_acc = 1000000;  #need
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact role",
      "value"=>"Data submitter",
    );
    $cv_acc = 1000586;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact name",
      "value"=>"$subm_name",
    );
#--------------------------------------------------
#     $cv_acc = 1000000;  #need
#     $writer->emptyTag("cvParam",
#       "cvRef"=>"$cv_ref",
#       "accession"=>"${cv_ref}:$cv_acc",
#       "name"=>"contact affiliation",
#       "value"=>"$subm_affiliation",
#     );
#-------------------------------------------------- 
    $cv_acc = 1000589;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"contact email",
      "value"=>"$subm_email",
    );
#--------------------------------------------------
#     $cv_acc = 1000588;
#     $writer->emptyTag("cvParam",
#       "cvRef"=>"$cv_ref",
#       "accession"=>"${cv_ref}:$cv_acc",
#       "name"=>"contact URL",
#       "value"=>"$subm_uri",
#     );
#-------------------------------------------------- 
  $writer->endTag("Contact");
$writer->endTag("ContactList");

$writer->startTag("PublicationList");
if ($pub_status eq 'submitted') {
  $writer->startTag("Publication", "id"=>"submitted01");
    $cv_ref = "PRIDE";
    $cv_acc = "0000067";
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"Reference reporting this experiment",
      "value"=>"$refline",
    );
  $writer->endTag("Publication");
} elsif ($pub_status eq 'unpublished') {
  $writer->startTag("Publication", "id"=>"unpublished01");
    $cv_ref = "PRIDE";
    $cv_acc = '0000412';
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"Dataset with no associated published manuscript",
    );
  $writer->endTag("Publication");
} else {
  my @publication_ids = split (",", $publication_ids);
  for my $pub (@publication_ids) {
    my $query = qq~
      SELECT pubmed_ID, publication_name, keywords, title, author_list, journal_name,
	published_year, volume_number, issue_number, page_numbers, uri, abstract
      FROM $TBAT_PUBLICATION
      WHERE publication_id = '$pub';
    ~;
    my @rows = $sbeams->selectSeveralColumns($query);
    my $pub_aref = $rows[0];
    $pubmed_id = $pub_aref->[0];
    my $pub_name = $pub_aref->[1];
    my $pub_keywords = $pub_aref->[2];
    @pub_keywords = @pub_keywords, split (",", $pub_keywords);
    my $title = $pub_aref->[3];
    my $author_list = $pub_aref->[4];
    my $journal_name = $pub_aref->[5];
    my $published_year = $pub_aref->[6];
    my $volume_number = $pub_aref->[7];
    my $issue_number = $pub_aref->[8];
    my $page_numbers = $pub_aref->[9];
    my $pub_uri = $pub_aref->[10];
    my $pub_abstract = $pub_aref->[11];
    my $refline = "$author_list, $title, $journal_name $published_year $volume_number($issue_number):$page_numbers";
    $writer->startTag("Publication", "id"=>"PMID$pubmed_id");
    $cv_ref = "MS";
      $cv_acc = 1000879;
      $writer->emptyTag("cvParam",
	"cvRef"=>"$cv_ref",
	"accession"=>"${cv_ref}:$cv_acc",
	"name"=>"PubMed identifier",
        "value"=>$pubmed_id,
      );
    $cv_ref = "PRIDE";
    $cv_acc = "0000067";
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"Reference reporting this experiment",
      "value"=>"$refline",
    );
    $writer->endTag("Publication");
  }
}
$writer->endTag("PublicationList");

my @keywords = @curator_keywords, @pub_keywords;
if (scalar @keywords) {
  $writer->startTag("KeywordList");
  for my $keyword (@curator_keywords) {
    $cv_ref = "MS";
    $cv_acc = 1001926;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"curator keyword",
      "value"=>"$keyword",
    );
  }
  for my $keyword (@pub_keywords) {
    $cv_acc = 1001924;
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"journal article keyword",
      "value"=>"$keyword",
    );
  }
  $writer->endTag("KeywordList");
}

$writer->startTag("FullDatasetLinkList");
  $writer->startTag("FullDatasetLink");
    $cv_ref = "MS";
    $cv_acc = 1000000;  #need; not found
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"PeptideAtlas dataset URI",
      "value"=>"http://www.PeptideAtlas.org/PASS/$datasetIdentifier",
    );
  $writer->endTag("FullDatasetLink");
  $writer->startTag("FullDatasetLink");
    $cv_acc = 1000000;  #need; not found in OLS
    $writer->emptyTag("cvParam",
      "cvRef"=>"$cv_ref",
      "accession"=>"${cv_ref}:$cv_acc",
      "name"=>"PASSEL transition group browser URI",
      "value"=>"https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetSELTransitions?row_limit=5000&SEL_experiments=$expt_id&QUERY_NAME=AT_GetSELTransitions&action=QUERY&uploaded_file_not_saved=1&apply_action=QUERY",
    );
  $writer->endTag("FullDatasetLink");
$writer->endTag("FullDatasetLinkList");

if (scalar @datasetfiles) {
  $writer->startTag("DatasetFileList");
  for my $file (@datasetfiles) {
    $writer->startTag("DatasetFile");
    $writer->endTag("DatasetFile");
  }
  $writer->endTag("DatasetFileList");
}

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
# $writer->startTag("ModificationList");
# $writer->startTag("AnnotationList");
# $writer->startTag("AdditionalInformation");
#-------------------------------------------------- 

$writer->endTag("ProteomeXchangeDataset");
$writer->end();
$output->close();

### End main program
