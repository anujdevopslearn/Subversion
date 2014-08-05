#!/usr/local/bin/perl

###############################################################################
# Program      : setup_PASSEL_load.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Set up user, user_login, user_work_group, project, publication,
#  and sample records for a PASSEL load.
#
# Get firstName, lastName, emailAddress, publicReleaseDate,
#     finalizedDate, datasetTag, datasetTitle, datasetType
#     from PASS_dataset and PASS_submitter
# Check datasetTitle
# Check datasetTag
# Set project_name (=datasetTitle)
# Get summary, publication, species, instruments, massModifications,
#     contributors from description file
#   If no publication, pubication = Unpublished
#   If publication is a pubmedID, transform to an actual citation
# Infer and check last name of lead author (publication)
# Create and check brief dataset title (datasetTitle, author)
# Infer and check year (publication)
# Create and check pub_name (publication, author)
# Infer and check organism (species)
# Infer and check mQuest_machine (instruments)
# Set experiment_tag (directory name) (=datasetTag)
# Set project_tag (=datasetTag)
# Check for existing contact_id (firstName, lastName)
# Check for existing user_login (contact_id)
# If so, get username (user_login)
# Check for existing project (username)
# Ask user for Instrument ID (instruments)
# 
# If no contact record
#   If organization_id given, check. Set to UNKNOWN if invalid.
#   If no organization_id given
#     If no organization_name given
#       Organization=UNKNOWN
#     Else
#       Create organization
#   Create contact record (firstName, lastName, organization)
# Create user_login and username if needed (contact_id)
# Create user_group association if needed (contact_id)
# Create project if needed (project_name, project_tag, contact_id)
# Create group_project_permission if needed (project_id)
# Create publication if needed (publication) 
#   if publication_id, we're done.
#   if pubmed_id, we have a procedure.
#   else, insert abbreviated pubication record using $pub_name as is.
# Create sample (project_name, project_tag, organism_id, description, instrument_id, publication_id, contributors, source_type, is_public)
# Set is_public to True if we've passed the public release date
#   and is_public not set on command line
#
# Create data directory
# Copy data into data directory
#

###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use DateTime;
$|++;

use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection::PubMedFetcher;
use SBEAMS::PeptideAtlas::LoadSRMExperiment;

use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);
use vars qw ($q $sbeams $sbeamsMOD $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name);

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
    allow_anonymous_access => 1,
  ));


$current_contact_id = $sbeams->getCurrent_contact_id;
$current_work_group_id = $sbeams->getCurrent_work_group_id;

my $pass_dir = '/regis/passdata/home';

###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
                              When nonzero, waits for user confirm at each step.
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or
                                added and no new directories are created.

  --pass_identifier           e.g. PASS00129. Required
  --no_create_login           Don't create user login. Default: do if needed
     (Submitter needs login so that SBEAMS user interface will work
      properly, but as of summer 2013 we are no longer giving them
      the login -- instead they will use reviewer login.)
  --pass_dir                  default: /regis/passdata/home

  If this is not a PASS submission, info can be provided using the
  following options. Or, PASS info can be overridden with these options:

  --contact_id                Either this, or firstName/lastName/org, required
  --firstName
  --lastName
  --emailAddress
  --organization_id           If not provided, will be created using
                               organization_name and organization_type
                               Otherwise, UNKNOWN will be used.
  --organization_name
  --organization_type         univ (default), gov, nonprofit, profit

  --sample_id                 If using existing sample.
  --project_id                If using existing project.
  --project_name              E.g., "Whole yeast lysate SRM (Yee, et al.)"
  --project_tag               No spaces. E.g., "yee_yeast_srm"
  --description               Free text description of project.  Optional.

  --publication_id            Either this, or one of the 3 below required
  --pubmed_id                    
  --pub_name                  When not yet in PubMed. Up to 255 chars.
                              Format: Peng, et al. (2012)
  --unpublished

  --organism_id               Optional but highly recommended.
  --instrument_id             Must look up in Instrument table. Samples:
                              TSQ=28 QSTAR=30 Velos=20 5500QTrap=25
			      QTOF6530=31 QTOF=19 6410QQQ=34 6460QQQ=27     

  --contributors              A list of names.

  --source_type               Natural (default), recomb, or synthetic.
  --is_public                 If data is to be public. Default: use
                                PASS public release date, else not public.

EOU

####
#### Process options
####
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
         "contact_id:i", "firstName:s", "lastName:s", "emailAddress:s",
	 "organization_name:s", "organization_type:s",
	 "organization_id:i", "project_id:i", "project_name:s", "project_tag:s",
	 "description:s", "pubmed_id:i", "pub_name:s", "publication_id:i",
         "unpublished",
	 "organism_id:i", "instrument_id:i", "contributors:s",
	 "source_type:s", "is_public",
	 "sample_id:i","no_create_login","pass_identifier:s",
   "pass_dir:s"
    )) {

    die "\n$USAGE";
}

if ($OPTIONS{"help"}) {
  print $USAGE;
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

my $pass_identifier = $OPTIONS{"pass_identifier"} || die $USAGE;
if ($pass_identifier !~ /PASS\d{5}/) {
  print "ERROR: PASS identifier must be of form PASS00123\n";
  exit;
}
my $pass_path = $pass_dir . '/' . $pass_identifier;
if (! -d $pass_path) {
  print "ERROR: Directory $pass_path not found.\n";
  exit;
}


my $contact_id = $OPTIONS{"contact_id"};
my $firstName = $OPTIONS{"firstName"};
my $lastName = $OPTIONS{"lastName"};
my $emailAddress = $OPTIONS{"emailAddress"};
my $organization_id = $OPTIONS{"organization_id"};
my $organization = $OPTIONS{"organization_name"};
my $organization_type = $OPTIONS{"organization_type"} || 'univ';
my $org_type_id;
if ($organization_type =~ /univ/i ) {
  $org_type_id = 7;
} elsif ($organization_type =~ /gov/i ) {
  $org_type_id = 9;
} elsif ($organization_type =~ /non.*prof/i ) {
  $org_type_id = 1;
} elsif ($organization_type =~ /prof/i ) {
  $org_type_id = 2;
} else {
  print "$PROG_NAME: invalid organization_type $organization_type.\n";
  print $USAGE;
  exit;
}

if (! $pass_identifier) {
  if (! $contact_id &&
    ! ($firstName && $lastName &&
      ( $organization_id || $organization ))) {
    print "$PROG_NAME: if neither pass_identifier nor contact_id provided, must provide firstName, lastName, and organization_id (or organization_name for new organization) to create new contact.\n";
    print $USAGE;
    exit;
  }
}

my $project_id = $OPTIONS{"project_id"};
if ($project_id) {
  my $sql = qq~
  SELECT name FROM $TB_PROJECT
  WHERE project_id = '$project_id'
  ~;
  my ($project_name) = $sbeams->selectOneColumn($sql);
  if (!$project_name) {
    print "$PROG_NAME: Invalid project ID $project_id.\n";
    print $USAGE;
    exit;
  } else {
    print "Project ID $project_id found to be $project_name.\n" if $VERBOSE;
  }
}

my $sample_id = $OPTIONS{"sample_id"};
my $sample_tag;
if ($sample_id) {
  my $sql = qq~
  SELECT sample_tag FROM $TBAT_SAMPLE
  WHERE sample_id = '$sample_id'
  ~;
  ($sample_tag) = $sbeams->selectOneColumn($sql);
  if (!$sample_tag) {
    print "$PROG_NAME: Invalid sample ID $sample_id.\n";
    print $USAGE;
    exit;
  } else {
    print "Sample ID $sample_id found to be $sample_tag.\n" if $VERBOSE;
  }
}

my $project_name = $OPTIONS{"project_name"};
my $project_tag = $OPTIONS{"project_tag"};
my $description = $OPTIONS{"description"};
if (! ($project_id && $sample_id) && !$pass_identifier &&
    ! ($project_name &&  $project_tag) ) {
   print "$PROG_NAME: if project_id and sample_id not both provided, project_name and project_tag are both required (unless PASS identifier provided).\n";
   print $USAGE;
   exit;
}

my $publication_id = $OPTIONS{"publication_id"};
my $pubmed_id = $OPTIONS{"pubmed_id"};
my $pub_name = $OPTIONS{"pub_name"};
my $unpublished = $OPTIONS{"unpublished"};
if (!$pass_identifier && !$publication_id && ! $pubmed_id && ! $pub_name &&
    ! $unpublished) {
   print "$PROG_NAME: If PASS identifier not provided, must provide existing publication_id, PubMed ID, or, if not yet in PubMed, a short publication name such as Feng, et al. (2014), or specify --unpublished\n";
   print $USAGE;
   exit;
}
# Check for valid publication_id or pubmed_id
my $pubmed_info;
if ($publication_id) {
  my $sql = qq~
  SELECT publication_name FROM $TBAT_PUBLICATION
  WHERE publication_id = '$publication_id'
  ~;
  ($pub_name) = $sbeams->selectOneColumn($sql);
  if (! $pub_name) {
    print "$PROG_NAME: invalid publication_id $publication_id.\n";
    exit;
  } else {
    print "Publication $publication_id, $pub_name is valid.\n" if $VERBOSE;
  }
} elsif ($pubmed_id) {
  my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
  $pubmed_info = $PubMedFetcher->getArticleInfo($pubmed_id);
  if (!$pubmed_info) {
    print "$PROG_NAME: Can't retrieve info for pubmed ID $pubmed_id.\n";
    exit;
  }
}



my $organism_id = $OPTIONS{"organism_id"};
my $instrument_id = $OPTIONS{"instrument_id"};
if (!$pass_identifier && !$instrument_id)  {
    print "$PROG_NAME: instrument_id required unless PASS identifier provided.";
    print $USAGE;
    exit;
  };

my $contributors = $OPTIONS{"contributors"};
if (!$pass_identifier && !$contributors)  {
    print "$PROG_NAME: contributors required unless PASS identifier provided.";
    print $USAGE;
    exit;
  };

my $source_type = $OPTIONS{"source_type"} || 'natural';
if (($source_type ne 'recomb') &&
    ($source_type ne 'synthetic') &&
    ($source_type ne 'natural')) {
  print "$PROG_NAME: source_type must be natural, recomb, or synthetic.\n";
  print $USAGE;
  exit;
}


my $is_public_option = defined $OPTIONS{"is_public"};
my $no_create_login = $OPTIONS{"no_create_login"};


###############################################################################
###
###  Get infos from PASS_dataset, PASS_submitter, and description file.
###
###############################################################################

# Get infos on the submitter
my $sql = qq~
  select
  PS.firstName,
  PS.lastName,
  PS.emailAddress,
  PDS.publicReleaseDate,
  PDS.finalizedDate,
  PDS.datasetTag,
  PDS.datasetTitle,
  PDS.datasetType
  from $TBAT_PASS_DATASET PDS
  join $TBAT_PASS_SUBMITTER PS
  on PS.submitter_id = PDS.submitter_id
  where  PDS.datasetIdentifier = '$pass_identifier';
~;

my @rows = $sbeams->selectSeveralColumns($sql);
if (! @rows) {
  print "No record in PASS_dataset for ${pass_identifier}\n";
  exit;
}
if (scalar @rows > 1) {
  print "WARNING: Multiple records in PASS_dataset for ${pass_identifier}; using first\n";
}
my ($firstName1, $lastName1, $emailAddress1, $publicReleaseDate,
    $finalizedDate, $datasetTag, $datasetTitle, $datasetType) =
  @{$rows[0]};

# Use retrieved values only if no values provided on command line
$firstName = $firstName1 if !$firstName;
$lastName = $lastName1 if !$lastName;
$emailAddress = $emailAddress1 if !$emailAddress;

if (length($finalizedDate) < 10) {
  print "Finalized date is specified as $finalizedDate.\n" if $VERBOSE;
  print "It looks like it hasn't been finalized. Proceed anyway? " if $VERBOSE;
  my $answer = <STDIN>;
}

if ($datasetType ne 'SRM') {
  print "WARNING: datasetType is $datasetType; should be SRM.\n";
  print "Continue? " if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
}

$datasetTitle = checkWithUser(
  entry=>$datasetTitle,
  desc=>"Descriptive title",
  ask=>1,
) if $VERBOSE;


## TODO: request 40-character title from submitter
$project_name = $datasetTitle if !$project_name;

if (length($datasetTag) >20) {
  my $long_tag = $datasetTag;
  $datasetTag = substr($long_tag, 0, 20);
  print "WARNING tag $long_tag is longer than 20 characters; truncated to $datasetTag.\n";
}
$datasetTag = checkWithUser(
  entry=>$datasetTag,
  desc=>"Experiment/project/sample tag",
  specs=>"20 chars max, no spaces",
  ask=>1,
) if $VERBOSE;

my $pass_descr_file = $pass_path . "/${pass_identifier}_DESCRIPTION.txt";

# Read and parse PASS description file

print "Parsing $pass_descr_file.\n" if $VERBOSE;
my ( $summary,  $publication, $instruments,
    $species, $massModifications);
# A list of all the fields in the PASS Description file.
### TODO: error-proof for probability that fields will change!!
my @fields = ("identifier", "type", "tag", "title", "summary", "contributors",
  "publication", "growth", "treatment", "extraction", "separation", "digestion",
  "acquisition", "informatics", "instruments", "species", "massModifications",);
my %fields = map {$_ => 1} @fields;
my $author;
open (my $infh, $pass_descr_file) || die "Can't open ${pass_descr_file}.";

# First, pre-process the file so that each field is on a single line.
my @lines;
my $prev_line = '';
while (my $line = <$infh>) {
  chomp $line;
  if (($line =~ /^(\S+):/) && (defined $fields{$1})) {
    push (@lines, $prev_line);
    $prev_line = $line;
  } else {
    $prev_line .= $line;
  }
}
push (@lines, $prev_line);

for my $line (@lines) {
  chomp $line;
  if ($line =~ /^summary:\s*(.*)$/) {
    $summary = $1;
    $summary =~ s/^\s*//g;
    $summary =~ s/\s*$//g;
    print "Summary: $summary\n" if $VERBOSE;
    #use this for Project Description
    $description = $summary if !$description;
  } elsif ($line =~ /^publication:\s*(.*)$/) {
    $publication = $1;
    $publication =~ s/^\s*//g;
    $publication =~ s/\s*$//g;
    print "Publication: $publication\n" if $VERBOSE;
  } elsif ($line =~ /^species:\s*(.*)$/) {
    $species = $1;
    $species =~ s/^\s*//g;
    $species =~ s/\s*$//g;
    print "Species: $species\n" if $VERBOSE;
  } elsif ($line =~ /^instruments:\s*(.*)$/) {
    $instruments = $1;
    $instruments =~ s/^\s*//g;
    $instruments =~ s/\s*$//g;
    print "Instruments: $instruments\n" if $VERBOSE;
  } elsif ($line =~ /^massModifications:\s*(.*)$/) {
    $massModifications = $1;
    $massModifications =~ s/^\s*//g;
    $massModifications =~ s/\s*$//g;
    print "Mass modifications: $massModifications\n" if $VERBOSE;
  } elsif ($line =~ /^contributors:\s*(.*)$/) {
    if (! $contributors) {
      $contributors = $1;
      $contributors =~ s/^\s*//g;
      $contributors =~ s/\s*$//g;
      print "Contributors: $contributors\n" if $VERBOSE;
    }
  }
}
### TODO: handle unusual characters in Contributors and Publication

# Some post-processing...

# Publication postprocessing
$publication = 'Unpublished' if (! $publication);
($pubmed_id) = $publication =~ /(\d{8})/ if !$pubmed_id;
if ($pubmed_id) {
  my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
  $pubmed_info = $PubMedFetcher->getArticleInfo(
    PubMedID=>$pubmed_id,);
  if ($pubmed_info) {
    $publication = $pubmed_info->{AuthorList}. ", " .
                   $pubmed_info->{ArticleTitle}. ", " .
                   $pubmed_info->{MedlineTA}. " (" .  # or PublicationName
                   $pubmed_info->{PublishedYear}. ")";
    print "Retrieved publication: $publication\n" if $VERBOSE;
  } else {
    print "WARNING: Could not retrieve info for PubmedID $pubmed_id.\n";
    print " Proceeding as though no PubmedID were provided.\n";
  }
}

# Create brief dataset title, appending lead author if any.
my $datasetTitleBrief = $datasetTitle;
if (length($datasetTitleBrief) > 40) {
  $datasetTitleBrief = substr($datasetTitleBrief, 0, 37) . "...";
}

if ($publication !~ /unpublished/i) {
  ($author) = split (/ / , $publication);
  $author =~ s/,$//;
  $author = checkWithUser(
    entry=>$author,
    desc=>"Lead author last name",
    ask=>1,
  ) if $VERBOSE;
  $datasetTitleBrief .= " ($author)";
}

$datasetTitleBrief = checkWithUser(
  entry=>$datasetTitleBrief,
  desc=>"Short title for PASSEL experiment browser",
  specs=>"max 55 characters",
  ask=>1,
) if $VERBOSE;


if (! $pub_name) {
  if ($publication =~ /unpublished/i) {
    $pub_name = 'Unpublished';
  } else {
    my ($year) = ($publication =~ /(20\d\d)/);
    $year = checkWithUser(
      entry=>$year,
      desc=>"Publication year",
      specs=>"blank if Submitted or Unpublished",
      ask=>1,
    ) if $VERBOSE;
    $pub_name = "$author, et al.";
    $pub_name .= " ($year)" if $year;
    $pub_name .= " (submitted)" if ($publication =~ m/submitted/i);
  }
  $pub_name = checkWithUser(
    entry=>$pub_name,
    desc=>"Publication name",
    specs=>"Unless unpublished, format is Li, et al. (2012)",
    ask=>1,
  ) if $VERBOSE;
}

# Organism
my @rows = ();
my $ask = 1;
if (! $organism_id) {
  while (scalar @rows != 1) {
    $species = checkWithUser(
      entry=>$species,
      desc=>"Organism name",
      specs=>"must be organism_name, common_name, full_name, or abbreviation from organism table",
      ask=>$ask,
    ) if $VERBOSE;

    $sql = qq~
    select organism_id, organism_name
    from $TB_ORGANISM
    where organism_name = '$species' OR
    common_name = '$species' OR
    full_name = '$species' OR
    abbreviation = '$species'
    ~;
    @rows = $sbeams->selectSeveralColumns($sql);

    print "Can't find entry in organism table for $species.\n" unless @rows;
    print "Try looking it up in https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/ManageTable.cgi?TABLE_NAME=organism\n" unless @rows;

    $ask = 0;
  }
  print "Found $rows[0]->[1] (ID=$rows[0]->[0]) in organism table.\n"
    if $VERBOSE;
  $organism_id = $rows[0]->[0];
}


# Instrument
print qq~
Which record from Instrument table best matches $instruments?
Samples: 
      TSQ=28 QSTAR=30 Velos=20 5500QTrap=25 4000QTrap=15
      QTOF6530=31 QTOF=19 6410QQQ=34 6460QQQ=27     
      Waters Xevo TQ-S=35
Or go to https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/ManageTable.cgi?TABLE_NAME=PR_instrument and select a different one, or create a new one.
  ~;
my $instrument_id=0;
while (! $instrument_id) {
  my $answer = '';
  while ($answer !~ /^\d+$/) {
    print "Enter desired instrument ID: ";
    $answer = <STDIN>;
    chomp $answer;
  }
  # check to see that it's valid
  my $sql = qq~
  select instrument_id from $TBPR_INSTRUMENT
  where instrument_id = '$answer'
  ~;
  ($instrument_id) = $sbeams->selectOneColumn($sql);
  print "Invalid instrument_id.\n" if !$instrument_id;
}
print "Found instrument (ID=$instrument_id) in Instrument table.\n"
  if $VERBOSE;

# Public release date. If specified on command line, use that.
# Otherwise, check date specified in PASS submission.
my $is_public=0;
if ($is_public_option) {
  $is_public = 1;
} elsif ($publicReleaseDate) {
  print "Public release date is specified as $publicReleaseDate.\n" if $VERBOSE;
  my ($year, $month, $date) =
     ($publicReleaseDate =~ /(^\d{4})-(\d{2})-(\d{2})/);
  print "Year $year Month $month Day $date\n" if $VERBOSE;
  my $dt_release = DateTime->new(
    year => $year,
    month => $month,
    day => $date,
  );
  $is_public = (DateTime->today() >= $dt_release);
}
if ($VERBOSE) {
  if ($is_public) {
    print "Dataset will be immediately public.\n";
  } else {
    print "Dataset will not be set to public.\n";
  }
}



# Figure out mmap_machine type for mMap
# Must be TSQ or QTRAP, or QQQ
my $mmap_machine;
if ( $instruments =~ /tsq/i ) { $mmap_machine ='TSQ'; }
  elsif ( $instruments =~ /qtrap/i ) { $mmap_machine ='QTRAP'; }
  elsif ( $instruments =~ /q-trap/i ) { $mmap_machine ='QTRAP'; }
  elsif ( $instruments =~ /5500/i ) { $mmap_machine ='QTRAP'; }
  elsif ( $instruments =~ /qqq/i ) { $mmap_machine ='QQQ'; }
  elsif ( $instruments =~ /quadrupole/i ) { $mmap_machine ='QQQ'; }
  elsif ( $instruments =~ /triple/i ) { $mmap_machine ='QQQ'; }
  else { $mmap_machine = 'QTRAP';}
$mmap_machine = checkWithUser(
  entry=>$mmap_machine,
  desc=>"mMap machine",
  specs=>"one of TSQ, QQQ, or QTRAP; use QTRAP for \"other\"",
  ask=>1,
) if $VERBOSE;

my $experiment_tag = $datasetTag;
$project_tag = $datasetTag if !$project_tag;

# Is there an existing contact for this user?
if (! $contact_id) {
  my $sql = qq~
    select contact_id
    from $TB_CONTACT
    where Last_Name = '$lastName'
    and First_name = '$firstName'
  ~;
  ($contact_id) = $sbeams->selectOneColumn($sql);
  if ($VERBOSE) {
    if ($contact_id) {
      print "Found contact_id $contact_id for $firstName $lastName.\n";
    } else {
      print "Could not find contact record for $firstName $lastName.\n";
    }
  }
}

# If there is an existing contact for this user,
# is there also an existing user_login? If so, fetch username.
my $username;
if ($contact_id){
  my $sql = qq~
  SELECT username FROM $TB_USER_LOGIN
  WHERE contact_id = '$contact_id'
  ~;
  ($username) = $sbeams->selectOneColumn($sql);
  if ($VERBOSE) {
    if ($username) {
      print "Found user_login $username for $firstName $lastName (contact_id = $contact_id).\n";
    } else {
      print "Could not find user_login for $firstName $lastName (contact_id = $contact_id).\n";
    }
  }
}

# If there is an existing username for this user,
# and there is no project_id specified on command line,
#  are there existing projects? If so, shall we re-use any of them?
if (!$project_id) {
  if ($username) {
    my $sql = qq~
    SELECT project_id, project_tag, name
    FROM $TB_PROJECT P
    JOIN $TB_USER_LOGIN UL
    ON UL.contact_id = PI_contact_id
    WHERE UL.username = '$username'
    ~;
    my @rows = $sbeams->selectSeveralColumns($sql);
    if (! @rows) {
      print "No existing projects for $username.\n" if $VERBOSE;
    } else {
      my $n = scalar @rows;
      print "$n projects found for $username:\n";
      for (my $i=1; $i<=$n; $i++) {
	print "$i) $rows[$i-1]->[2]\n";
      }
      print "Which would you like to use (ENTER if none)? ";
      my $answer = <STDIN>;
      chomp $answer;
      while ( ! ( $answer eq '' || (($answer =~ /^\d+$/) && ($answer <= $n)))) {
	printf "Enter number between 1 and %d, or ENTER to create new: ", $n;
	$answer = <STDIN>;
        chomp($answer);
      }
      if ($answer) {
	$project_id = $rows[$answer-1]->[0];
        print "Selected project $project_id, $rows[$answer-1]->[2]\n" if $VERBOSE;
      } else {
        print "New project will be created in a little while.\n" if $VERBOSE;
      }
    }
  }
}
    

my $project = 'SRM';



###############################################################################
###
###  Create all necessary records and directories
###
###############################################################################
print "About to create database records" if $VERBOSE;
print " (ONLY A SIMULATION because \$TESTONLY is set)" if ($TESTONLY && $VERBOSE);
print ", keep hitting return unless something is amiss.\n" if $VERBOSE;
print "Press RETURN to continue" if $VERBOSE;
my $answer = <STDIN> if $VERBOSE;

my $rowdata_ref;

if (! $contact_id) {
  if (! $organization_id) {
    if (! $organization ) {
      $organization_id = 5;  #UNKNOWN organization
    } else {
      print "Creating organizaton record for $organization, type $organization_type.\n" if $VERBOSE;
      print "Press RETURN to continue" if $VERBOSE;
      my $answer = <STDIN> if $VERBOSE;
    }
    if (! $organization_id) {
      print "About to create organization $organization, type_id $org_type_id ($organization_type).\n" if $VERBOSE;
      print "Press RETURN to continue" if $VERBOSE;
      my $answer = <STDIN> if $VERBOSE;
      $rowdata_ref = {};  #clear hash   
      $rowdata_ref->{'organization_type_id'} = $org_type_id;
      $rowdata_ref->{'organization'} = $organization;
      $rowdata_ref->{'created_by_id'} = $current_contact_id;
      $rowdata_ref->{'modified_by_id'} = $current_contact_id;
      $organization_id = $sbeams->updateOrInsertRow(
	insert=>1,
	table_name=>$TB_ORGANIZATION,
	rowdata_ref=>$rowdata_ref,
	PK => 'organization_id',
	return_PK => 1,
	verbose=>$VERBOSE,
	testonly=>$TESTONLY,
      );
      print "Created organization $organization_id.\n" if $VERBOSE;
      print "Press RETURN to continue" if $VERBOSE;
      my $answer = <STDIN> if $VERBOSE;
    }
  }

  print "Creating contact for $firstName $lastName in organization $organization_id\n";

  # First, check for valid organization_id
  my $sql = qq~
  SELECT organization FROM $TB_ORGANIZATION
  WHERE organization_id = '$organization_id'
  ~;
  my ($organization) = $sbeams->selectOneColumn($sql);
  if (!$organization) {
    print "$PROG_NAME: invalid organization_id $organization_id.\n";
    print "Using UNKNOWN.\n";
    $organization_id = 5;
  } else {
    print "Organization: $organization.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  }

  print "About to create contact for $firstName, $lastName, organization $organization_id, email $emailAddress, data_producer.\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  $rowdata_ref = {};  #clear hash   
  $rowdata_ref->{'first_name'} = $firstName;
  $rowdata_ref->{'last_name'} = $lastName;
  $rowdata_ref->{'organization_id'} = $organization_id;
  $rowdata_ref->{'email'} = $emailAddress if $emailAddress;
  $rowdata_ref->{'contact_type_id'} = 8; #data_producer
  $contact_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TB_CONTACT,
    rowdata_ref=>$rowdata_ref,
    PK => 'contact_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );
  print "Created contact $contact_id.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
}

####
#### Create user login if necessary
####
if (!$no_create_login) {

  # If we didn't find an existing user_login for this contact, create one

  if (!$username) {
    # Keep trying various usernames until a new one is found.
    my $len = 1;
    my $maxlen = length($firstName);
    while ($len <= $maxlen) {
      my $first_initial = substr($firstName, 0, $len);
      $username = lc ($first_initial . substr($lastName,0,9) );
      my $sql = qq~
      SELECT user_login_id FROM $TB_USER_LOGIN
      WHERE username = '$username'
      ~;
      my ($user_login_id) = $sbeams->selectOneColumn($sql);
      last if (! $user_login_id);
      $len++;
    }
    if ($len == $maxlen) {
      print "$PROG_NAME: Can't create new username from $firstName, $lastName.\n";
      exit;  ## extremely unlikely
    }
    print "Creating user login for $username\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;

    # encode password using code lifted from $SBEAMS/lib/perl/ManageTable.pllib
    my $salt = (rand() * 220);
    my $encrypted_password = crypt("passel", $salt);
    print "About to create user login for contact $contact_id, username $username, encrypted password $encrypted_password ('passel' unencrypted), data_modifier.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
    $rowdata_ref = {};  #clear hash
    $rowdata_ref->{'password'} = $encrypted_password;
    $rowdata_ref->{'privilege_id'} = 20; #data_modifier
    $rowdata_ref->{'contact_id'} = $contact_id;
    $rowdata_ref->{'created_by_id'} = $current_contact_id;
    $rowdata_ref->{'modified_by_id'} = $current_contact_id;
    $rowdata_ref->{'username'} = $username;
    my $user_login_id = $sbeams->updateOrInsertRow(
      insert=>1,
      table_name=>$TB_USER_LOGIN,
      rowdata_ref=>$rowdata_ref,
      PK => 'user_login_id',
      return_PK => 1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );
    print "Created user_login $user_login_id for $username.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  } else {
    print "Username $username already exists for this contact; no need to create username.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  }
}


####
#### Create user group association
####

# First, see if needed association already exists.
my $sql = qq~
SELECT user_work_group_id FROM $TB_USER_WORK_GROUP
WHERE contact_id = '$contact_id'
AND work_group_id = 39
AND privilege_id = 20
~;
my ($user_work_group_id) = $sbeams->selectOneColumn($sql);
if (! $user_work_group_id) {
  print "About to create user work group for contact $contact_id, work_group_id 39 (PeptideAtlas_user), privilege_id 20 (data_modifier).\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  $rowdata_ref = {};  #clear hash
  $rowdata_ref->{'contact_id'} = $contact_id;
  $rowdata_ref->{'work_group_id'} = 39; #PeptideAtlas_user
  $rowdata_ref->{'privilege_id'} = 20; #data_modifier
  $rowdata_ref->{'created_by_id'} = $current_contact_id;
  $rowdata_ref->{'modified_by_id'} = $current_contact_id;
  my $user_work_group_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TB_USER_WORK_GROUP,
    rowdata_ref=>$rowdata_ref,
    PK => 'user_work_group_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );
  print "Created user_work_group $user_work_group_id for contact $contact_id\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
} else {
  print "user_work_group already exists for contact $contact_id, PeptideAtlas_user, data_modifier.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
}

####
#### Create project
####

# If no project_id provided, create one
if (! $project_id) {
  print "About to create project $project_name ($project_tag), PI contact $contact_id, description '$description', budget NA .\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  $rowdata_ref = {};  #clear hash
  $rowdata_ref->{'name'} = $project_name;
  $rowdata_ref->{'project_tag'} = $project_tag;
  $rowdata_ref->{'PI_contact_id'} = $contact_id;
  $rowdata_ref->{'created_by_id'} = $current_contact_id;
  $rowdata_ref->{'modified_by_id'} = $current_contact_id;
  $rowdata_ref->{'description'} = $description if ($description);
  $rowdata_ref->{'budget'} = 'NA';
  $project_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TB_PROJECT,
    rowdata_ref=>$rowdata_ref,
    PK => 'project_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );
  print "Created project $project_id, $project_tag, '$project_name'\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
}

####
#### Create group_project_permission
####

# First, see if needed association already exists.
my $sql = qq~
SELECT group_project_permission_id FROM $TB_GROUP_PROJECT_PERMISSION
WHERE project_id = '$project_id'
AND work_group_id = 40
AND privilege_id = 10
~;
my ($group_project_permission_id) = $sbeams->selectOneColumn($sql);
# If it doesn't, create it.
if (! $group_project_permission_id) {
  print "About to create group project permission for project $project_id, work_group_id 40 (PeptideAtlas_admin), privilege_id 10 (administrator). This will allow the PeptideAtlas team to administer this project.\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  $rowdata_ref = {};  #clear hash
  $rowdata_ref->{'project_id'} = $project_id;
  $rowdata_ref->{'work_group_id'} = 40; #PeptideAtlas_admin
  $rowdata_ref->{'privilege_id'} = 10; #administrator
  $rowdata_ref->{'created_by_id'} = $current_contact_id;
  $rowdata_ref->{'modified_by_id'} = $current_contact_id;
  my $group_project_permission_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TB_GROUP_PROJECT_PERMISSION,
    rowdata_ref=>$rowdata_ref,
    PK => 'group_project_permission_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );
  print "Created group project permission $group_project_permission_id for project $project_id\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
} else {
  print "group_project_permission $group_project_permission_id already exists for project $project_id, PeptideAtlas_admin, administrator.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
}


####
#### Create publication, if necessary
####
my $insert_publication_record = 0;
if (!$publication_id) {
  if ($pubmed_id) {
    # see whether a publication already exists for this pubmed_id
    my $sql = qq~
    SELECT publication_id, publication_name FROM $TBAT_PUBLICATION
    WHERE pubmed_id = '$pubmed_id'
    ~;
    ($publication_id, $pub_name) = $sbeams->selectOneColumn($sql);
    if ($publication_id) {
      print "Publication $publication_id, $pub_name is already loaded for PubMed ID $pubmed_id; no need to create new one.\n" if $VERBOSE;
      print "Press RETURN to continue" if $VERBOSE;
      my $answer = <STDIN> if $VERBOSE;
    } elsif ($pubmed_info) {
      my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
      my %keymap = (
	MedlineTA=>'journal_name',
	AuthorList=>'author_list',
	Volume=>'volume_number',
	Issue=>'issue_number',
	AbstractText=>'abstract',
	ArticleTitle=>'title',
	PublishedYear=>'published_year',
	MedlinePgn=>'page_numbers',
	PublicationName=>'publication_name',
      );
      $pub_name = $pubmed_info->{'PublicationName'};
      $rowdata_ref = {};  #clear hash
      print "About to create full publication record for $pub_name.\n" if $VERBOSE;
      while (my ($key,$value) = each %{$pubmed_info}) {
	print "$key=$value=\n" if $VERBOSE;
	if ($keymap{$key}) {
	  $rowdata_ref->{$keymap{$key}} = $value;
	  print "Mapped to $keymap{$key}\n" if $VERBOSE;
	}
      }
      print "Press RETURN to continue" if $VERBOSE;
      my $answer = <STDIN> if $VERBOSE;
      $insert_publication_record = 1;
    } else {
      print "$PROG_NAME: ERROR in program logic -- pubmed_info should have been defined by now.\n";
      exit;
    }
  } elsif ($unpublished || ($pub_name eq 'Unpublished')) {
    $publication_id = 62   #special record for Unpublished
  } else {
    print "About to create abbreviated publication record for $pub_name.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
    $rowdata_ref = {};  #clear hash
    $rowdata_ref->{'publication_name'} = $pub_name;
    $rowdata_ref->{'created_by_id'} = $current_contact_id;
    $rowdata_ref->{'modified_by_id'} = $current_contact_id;
    $insert_publication_record = 1;
  }

  if ($insert_publication_record) {
    $publication_id = $sbeams->updateOrInsertRow(
      insert=>1,
      table_name=>$TBAT_PUBLICATION,
      rowdata_ref=>$rowdata_ref,
      PK => 'publication_id',
      return_PK => 1,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );
    print "Created publication $publication_id for $pub_name\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  }
}

####
#### Create sample and print sample_id
####
# If sample_id provided, check that it exists.
if (! $sample_id) {
  $sample_tag = $project_tag if !$sample_tag;
  my $sample_title = $project_name;
  print "About to create sample $sample_title ($sample_tag), project_id $project_id, description '$description', organism_id $organism_id, instrument_model_id $instrument_id, sample_publication_ids $publication_id, data_contributors $contributors, peptide_source_type $source_type, is_public '$is_public'.\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  $rowdata_ref = {};  #clear hash
  $rowdata_ref->{'project_id'} = $project_id;
  $rowdata_ref->{'organism_id'} = $organism_id if ($organism_id);
  $rowdata_ref->{'sample_tag'} = $sample_tag;
  #$rowdata_ref->{'original_experiment_tag'} = $sample_tag; #correct field name?
  $rowdata_ref->{'sample_title'} = $sample_title;
  $rowdata_ref->{'sample_description'} = $description if ($description);
  $rowdata_ref->{'instrument_model_id'} = $instrument_id;
  $rowdata_ref->{'sample_publication_ids'} = $publication_id;
  $rowdata_ref->{'data_contributors'} = $contributors;
  $rowdata_ref->{'peptide_source_type'} = $source_type;
  $rowdata_ref->{'is_public'} = $is_public;
  $rowdata_ref->{'created_by_id'} = $current_contact_id;
  $rowdata_ref->{'modified_by_id'} = $current_contact_id;
  $sample_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TBAT_SAMPLE,
    rowdata_ref=>$rowdata_ref,
    PK => 'sample_id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );
  print "Created sample $sample_id, $sample_tag, '$sample_title'\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
}

### TODO: check for an existing regis subdirectory for this person

### TODO: need to check for mProphet file in PASS directory  mPro*xls??
# What decoy algorithm was used?  Has a random value been added to the Q1s?
# Has the pepseq been reversed? Or ?
my $mpro_file = '';

#### Create the archive directory
my $archive_dir = '/regis/sbeams/archive';
my $submitter_dir = $archive_dir . "/$username";
if ( ! -d  $submitter_dir ) {
  print "Creating directory $submitter_dir\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  print " (not really, test only)\n" if $TESTONLY;
  my $error = system ("mkdir $submitter_dir") unless $TESTONLY;
  if ($error && ! $TESTONLY) {
    print "mkdir $submitter_dir failed\n";
    exit;
  }
}
my $project_dir = $submitter_dir . "/$project";
if ( ! -d  $project_dir ) {
  print "Creating directory $project_dir\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  print " (not really, test only)\n" if $TESTONLY;
  my $error = system("mkdir $project_dir") unless $TESTONLY;
  if ($error && ! $TESTONLY) {
    print "mkdir $project_dir failed\n";
    exit;
  }
}
my $expdir = $project_dir . "/$experiment_tag";
if ( ! -d  $expdir ) {
  print "Creating directory $expdir\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  print " (not really, test only)\n" if $TESTONLY;
  my $error = system("mkdir $expdir") unless $TESTONLY;
  if ($error && ! $TESTONLY) {
    print "mkdir $expdir failed\n";
    exit;
  }
}
print "Copying files from $pass_path to $expdir\n" if $VERBOSE;
print "Press RETURN to continue" if $VERBOSE;
my $answer = <STDIN> if $VERBOSE;
print " (not really, test only)\n" if $TESTONLY;
my $error = system("cp -aP ${pass_path}/* $expdir") unless $TESTONLY;
if ($error && ! $TESTONLY) {
  print "cp -aP ${pass_path}/* $expdir  failed\n";
  exit;
}

# Figure out what type of raw files you have
# TODO: figure out proper directory for raw files
# TODO: run qconvert on regis.
my $raw_extension;
if ( -e "${expdir}/*.d") {
  $raw_extension = "d";
  print "We have .d files!\n";
} elsif ( -e "${expdir}/*.RAW") {
  $raw_extension = "RAW";
  print "We have .RAW files!\n";
} elsif ( -e "${expdir}/*.raw") {
  $raw_extension = "raw";
  print "We have .raw files!\n";
} elsif ( -e "${expdir}/*.wiff") {
  $raw_extension = "wiff";
  print "We have .wiff files!\n";
} else {
  print "Unknown raw file type in $expdir; not one of .d, .raw, or .wiff\n";
  #exit;
}

#### Convert all raw files  using one of the below
#qconvert *.d
#qconvert *.raw
#qconvert --convertWith msconvert *.wiff

# TODO: check the converted files before we proceed.

if ($VERBOSE) {
  print "Done.\n" if $VERBOSE;
  print "Execute these commands in shell, and copy into recipe:\n";
  print "export PASS=$pass_identifier\n";
  print "export TITLE=$datasetTitle\n";
  print "export PROJECT_ID=$project_id\n";
  print "export SAMPLE_ID=$sample_id\n";
  print "export CONTACT_ID=$contact_id\n";
  print "export EXPDIR=$expdir\n";
  print "export MMAP_MACHINE=$mmap_machine\n";
}

### End main program

###############################################################################
###
### checkWithUser: allow user to enter, verify, or modify a data string
###
###############################################################################

sub checkWithUser {
  my %argv = @_;
  my $entry = $argv{entry};
  my $desc = $argv{desc};
  my $specs = $argv{specs} ||  '';
  my $ask = $argv{ask} || 0;

  my $answer = 'n';
  # Optionally, ask user if they want to change the current value
  if ($ask) {
    print "\n$desc: $entry\n";
    print "Requirements: $specs\n" if $specs;
    print "OK? ";
    $answer = <STDIN>;
    while ($answer !~ /[yYnN]/) {
      print "OK? (y/n) ";
      $answer = <STDIN>;
    }
  }
  # Get value from user and ask them to confirm.
  while ($answer !~ /^y/i) {
    print "Enter different $desc\n";
    $entry = <STDIN>;
    chomp $entry;
    print "Here is what you entered:\n";
    print $entry, "\n";
    print "OK now? ";
    $answer = <STDIN>;
    while ($answer !~ /[yYnN]/) {
      print "OK now? (y/n) ";
      $answer = <STDIN>;
    }
  }
  return $entry;
}

