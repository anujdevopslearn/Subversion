#!/usr/local/bin/perl
# Skeleton for executing a few SQL queries into SBEAMS.
# Just set $query to the query you want, and go!
# June 2009  Terry Farrah

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

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ( $current_username = $sbeams->Authenticate(
    allow_anonymous_access => 1,
  ));


$current_contact_id = $sbeams->getCurrent_contact_id;
# This is returning 1, but prev SEL_run records used 40.
$current_work_group_id = $sbeams->getCurrent_work_group_id;
$current_work_group_id = 40;
#$current_work_group_name = $sbeams->getCurrent_work_group_name;
# date_created is filled in automatically.

# Get from command line SEL_experiment_id, list of spectrum filenames.
if (!scalar @ARGV) {
  print "Usage: $0 SEL_experiment_id spec_fname1 spec_fname2 ...\n";
  print "  Inserts SEL_run records into the PASSEL database\n";
  print "  Generally, spectrum filenames should not include path.\n";
  exit();
}
my $SEL_experiment_id = shift @ARGV;
my @spectrum_filenames = @ARGV;

for my $spectrum_filename (@spectrum_filenames) {

  # We do not need to specify SEL_run_id because it is the primary key
  # and will autoincrement.
  my $query = qq~
   INSERT INTO $TBAT_SEL_RUN
      (SEL_experiment_id, spectrum_filename,
      created_by_id,modified_by_id,owner_group_id,record_status)
    VALUES
      ($SEL_experiment_id, '$spectrum_filename',
       $current_contact_id, $current_contact_id, $current_work_group_id,'N')
  ~;
  print $query;

  $sbeams->do( $query );
}
