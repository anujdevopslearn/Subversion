#!/usr/local/bin/perl

###############################################################################
# Program      : setup_PASSEL_load.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Set up user, user_login, user_work_group, project, publication,
#  and sample records for a PASSEL load.
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
$|++;

use lib "$FindBin::Bin/../../perl";
use SBEAMS::PeptideAtlas::LoadSRMExperiment;

use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);
use vars qw ($q $sbeams $sbeamsMOD $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name);

use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ( $current_username = $sbeams->Authenticate(
    allow_anonymous_access => 1,
  ));


$current_contact_id = $sbeams->getCurrent_contact_id;
# This is returning 1, but prev SEL_run records used 40.
$current_work_group_id = $sbeams->getCurrent_work_group_id;
$current_work_group_id = 40;

my $loader = new SBEAMS::PeptideAtlas::LoadSRMExperiment;

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
  --testonly                  If set, rows in the database are not changed or added

  --created_by_id             ID of user running this script. REQUIRED.
                                Terry=667 Zhi=668 EricD=2
  --contact_id                Either this, or first_name/last_name/org, required
  --first_name
  --last_name
  --organization_id           If not provided, will be created using
                               organization_name and organization_type
  --organization_name
  --organization_type         univ (default), gov, nonprofit, profit
  --email                     Email address of contact. Optional.

  --sample_id                 If using existing sample.
  --project_id                If using existing project.

  If sample or project need to be created, project_name and project_tag are required.
  --project_name              E.g., "Whole yeast lysate SRM (Yee, et al.)"
  --project_tag               No spaces. E.g., "yee_yeast_srm"
  --description               Free text description of project.  Optional.

  --publication_id            Either this, or pubmed_id, or pub_name required
  --pubmed_id                 
  --pub_name                  When not yet in PubMed. Up to 255 chars.
                              Include author, brief title, publication status.
  E.g., "Zgoda, et al. (2012), Chromosome 18 transcriptome profiling (in press)"

  --organism_id               Optional.
  --instrument_id             Required. Must look up in Instrument table.
                              TSQ=28 QSTAR=30 Velos=20 5500QTrap=25
			      QTOF6530=31 QTOF=19 6410QQQ=34 6460QQQ=27     

  --contributors              Required. A list of names.

  --source_type               Natural (default), recomb, or synthetic.
  --is_public                 If data is to be public. Default: off
                                already loaded.

 e.g.:  $PROG_NAME --contact_id 815 --project_name 'KLK assay for PCa plasma samples (Nilsson, et al.)' --project_tag Ch19_KLK_bloodplasma --pub_name 'Rezeli, et al. (2012) Kallikrein assay for plasma (submitted)' --instrument_id 37 --contributors ' A. Vagvari, K. Sjodin, M. Rezeli'
EOU

####
#### Process options
####
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
         "contact_id:i", "first_name:s", "last_name:s",
	 "organization_name:s", "organization_type:s",
	 "organization_id:i", "project_id:i", "project_name:s", "project_tag:s",
	 "description:s", "pubmed_id:i", "pub_name:s", "publication_id:i",
	 "organism_id:i", "instrument_id:i", "contributors:s",
	 "source_type:s", "is_public", "created_by_id:i","email:s",
	 "sample_id:i",
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


my $contact_id = $OPTIONS{"contact_id"};
my $first_name = $OPTIONS{"first_name"};
my $last_name = $OPTIONS{"last_name"};
my $organization_id = $OPTIONS{"organization_id"};
my $organization = $OPTIONS{"organization_name"};
my $organization_type = $OPTIONS{"organization_type"} || 'univ';
my $org_type_id;
my $email = $OPTIONS{"email"};

if (! $contact_id &&
    ! ($first_name && $last_name &&
      ( $organization_id || $organization ))) {
   print "$PROG_NAME: if contact_id not provided, must provide first_name, last_name, and organization_id (or organization_name for new organization) to create new contact.\n";
   print $USAGE;
   exit;
}

my $project_id = $OPTIONS{"project_id"};
my $sample_id = $OPTIONS{"sample_id"};
my $project_name = $OPTIONS{"project_name"};
my $project_tag = $OPTIONS{"project_tag"};
my $description = $OPTIONS{"description"};
if (! ($project_id && $sample_id) && ! ($project_name &&  $project_tag) ) {
   print "$PROG_NAME: if project_id and sample_id not both provided, project_name and project_tag are both required.\n";
   print $USAGE;
   exit;
}

my $publication_id = $OPTIONS{"publication_id"};
my $pubmed_id = $OPTIONS{"pubmed_id"};
my $pub_name = $OPTIONS{"pub_name"};
if (!$publication_id && ! $pubmed_id && ! $pub_name ) {
   print "$PROG_NAME: Must provide existing publication_id, PubMed ID, or, if not yet in PubMed, a short publication name including first author, year, and brief title.\n";
   print $USAGE;
   exit;
}

my $organism_id = $OPTIONS{"organism_id"};
my $instrument_id = $OPTIONS{"instrument_id"};
if (!$instrument_id)  {
    print "$PROG_NAME: instrument_id required.";
    print $USAGE;
    exit;
  };

my $contributors = $OPTIONS{"contributors"};
if (!$contributors)  {
    print "$PROG_NAME: contributors required.";
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


my $is_public = $OPTIONS{"is_public"};
my $created_by_id = $OPTIONS{"created_by_id"};
if (! $created_by_id) {
  print "$PROG_NAME: must provide --created_by_id.\n";
  print "$USAGE";
  exit;
}



###############################################################################
###
### Main section: Create all necessary records
###
###############################################################################
my $rowdata_ref;

if (! $contact_id) {
  if (! $organization_id) {
    if (! $organization ) {
      print "$PROG_NAME: if contact_id not provided, must provide organization_id (or organization_name to create new organization record).\n";
      print $USAGE;
      exit;
    } else {
      print "Creating organizaton record for $organization, type $organization_type.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
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
    }
  print "About to create organization $organization, type_id $org_type_id ($organization_type).\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
    $rowdata_ref = {};  #clear hash   
    $rowdata_ref->{'organization_type_id'} = $org_type_id;
    $rowdata_ref->{'organization'} = $organization;
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

  print "Creating contact for $first_name $last_name in organization $organization_id\n";

  # First, check for valid organization_id
  my $sql = qq~
  SELECT organization FROM $TB_ORGANIZATION
  WHERE organization_id = '$organization_id'
  ~;
  my ($organization) = $sbeams->selectOneColumn($sql);
  if (!$organization) {
    print "$PROG_NAME: invalid organization_id $organization_id.\n";
    exit;
  } else {
    print "Organization: $organization.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  }

  print "About to create contact for $first_name, $last_name, organization $organization_id, email $email, data_producer.\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  $rowdata_ref = {};  #clear hash   
  $rowdata_ref->{'first_name'} = $first_name;
  $rowdata_ref->{'last_name'} = $last_name;
  $rowdata_ref->{'organization_id'} = $organization_id;
  $rowdata_ref->{'email'} = $email if $email;
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
#### Create user login
####
# Check to see if user login exists for this contact_id
my $sql = qq~
SELECT username FROM $TB_USER_LOGIN
WHERE contact_id = '$contact_id'
~;
my ($username) = $sbeams->selectOneColumn($sql);

# If not, create one

if (!$username) {
  # Keep trying various usernames until a new one is found.
  my $len = 1;
  my $maxlen = length($first_name);
  while ($len <= $maxlen) {
    my $first_initial = substr($first_name, 0, $len);
    $username = lc ($first_initial . $last_name );
    my $sql = qq~
    SELECT user_login_id FROM $TB_USER_LOGIN
    WHERE username = '$username'
    ~;
    my ($user_login_id) = $sbeams->selectOneColumn($sql);
    last if (! $user_login_id);
    $len++;
  }
  if ($len == $maxlen) {
    print "$PROG_NAME: Can't create new username from $first_name, $last_name.\n";
    exit;
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
  $rowdata_ref->{'created_by_id'} = $created_by_id;
  $rowdata_ref->{'modified_by_id'} = $created_by_id;
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
  $rowdata_ref->{'created_by_id'} = $created_by_id;
  $rowdata_ref->{'modified_by_id'} = $created_by_id;
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

# If project_id provided, check that it exists.
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
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  }
  # If not provided, create one.
} else {
  print "About to create project $project_name ($project_tag), PI contact $contact_id, description '$description', budget NA .\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  $rowdata_ref = {};  #clear hash
  $rowdata_ref->{'name'} = $project_name;
  $rowdata_ref->{'project_tag'} = $project_tag;
  $rowdata_ref->{'PI_contact_id'} = $contact_id;
  $rowdata_ref->{'created_by_id'} = $created_by_id;
  $rowdata_ref->{'modified_by_id'} = $created_by_id;
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
  $rowdata_ref->{'created_by_id'} = $created_by_id;
  $rowdata_ref->{'modified_by_id'} = $created_by_id;
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
if ($publication_id) {
  my $retrieved_publication_id;
  # check that this publication_id exists.
  my $sql = qq~
  SELECT publication_id, publication_name FROM $TBAT_PUBLICATION
  WHERE publication_id = '$publication_id'
  ~;
  ($retrieved_publication_id, $pub_name) =
     $sbeams->selectOneColumn($sql);
  if (! $retrieved_publication_id) {
    print "$PROG_NAME: invalid publication_id $publication_id.\n";
    exit;
  } else {
    print "Publication $publication_id, $pub_name is valid.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  }
} elsif ($pubmed_id) {
  # see whether a publication already exists for this pubmed_id
  my $sql = qq~
  SELECT publication_id, publication_name FROM $TBAT_PUBLICATION
  WHERE pubmed_id = '$pubmed_id'
  ~;
  ($publication_id, $pub_name) =
     $sbeams->selectOneColumn($sql);
  if ($publication_id) {
    print "Publication $publication_id, $pub_name is already loaded for PubMed ID $pubmed_id; no need to create new one.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  } else {
    use SBEAMS::Connection::PubMedFetcher;
    my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
    my $pubmed_info = $PubMedFetcher->getArticleInfo($pubmed_id);
    if ($pubmed_info) {
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
    # If we can't auto-retrieve, construct a
    # publication_name for the user, rather than dying. TODO
    } else {
      print "$PROG_NAME: Can't retrieve info for pubmed ID $pubmed_id.\n";
      exit;
    }
  }
} else {
  $pub_name .= " (submitted)" if ($pub_name !~ /submitted/i);
  print "About to create abbreviated publication record for $pub_name.\n" if $VERBOSE;
  print "Press RETURN to continue" if $VERBOSE;
  my $answer = <STDIN> if $VERBOSE;
  $rowdata_ref = {};  #clear hash
  $rowdata_ref->{'publication_name'} = $pub_name;
  $rowdata_ref->{'created_by_id'} = $created_by_id;
  $rowdata_ref->{'modified_by_id'} = $created_by_id;
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

####
#### Create sample and print sample_id
####
# If sample_id provided, check that it exists.
if ($sample_id) {
  my $sql = qq~
  SELECT sample_tag FROM $TBAT_SAMPLE
  WHERE sample_id = '$sample_id'
  ~;
  my ($sample_tag) = $sbeams->selectOneColumn($sql);
  if (!$sample_tag) {
    print "$PROG_NAME: Invalid sample ID $sample_id.\n";
    print $USAGE;
    exit;
  } else {
    print "Sample ID $sample_id found to be $sample_tag.\n" if $VERBOSE;
    print "Press RETURN to continue" if $VERBOSE;
    my $answer = <STDIN> if $VERBOSE;
  }
  # If not provided, create one.
} else {
  my $sample_title = $project_name;
  my $sample_tag = $project_tag;
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
  $rowdata_ref->{'created_by_id'} = $created_by_id;
  $rowdata_ref->{'modified_by_id'} = $created_by_id;
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
print "Done.\n" if $VERBOSE;

### End main program
