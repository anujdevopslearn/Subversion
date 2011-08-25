#!/usr/local/bin/perl

###############################################################################
# Program      : map_PASSEL_to_swissprot.pl
# Author       : Terry Farrah <tfarrah@systemsbiology.org>
# $Id: 
# 
# Description  :
# Map all peptides in an SRM experiment to the Swiss-Prot entries in the
# latest biosequence set for the organism and store in
# table SEL_peptide_ion_protein. Experiment data must already be loaded.
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
$|++;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Authenticator;

use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::LoadSRMExperiment;


use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);

$sbeams = new SBEAMS::Connection;
my $loader = new SBEAMS::PeptideAtlas::LoadSRMExperiment;

###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --title foo                 Map peptides for experiment "foo".
  --number N                  Map peptides for experiment N.
  --glyco                     Glycocapture. D's replace N's in NX[ST].
 
 e.g.:  $PROG_NAME --num 4

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "title:s", "number:i", "glyco",
    )) {

    die "\n$USAGE";
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

my $SEL_experiment_id = $OPTIONS{"number"};
my $experiment_title = $OPTIONS{"title"};
if ((! $SEL_experiment_id) && (! $experiment_title)) {
  print "$USAGE\nMust specify either --title or --number.\n";
  exit();
} elsif ($experiment_title && $SEL_experiment_id ) {
  print "$USAGE\nCannot specify both --title and --number.\n";
  exit();
}

# Get experiment number if not given
my $sql;
if (! $SEL_experiment_id && $experiment_title) {
  $sql = qq~
    SELECT SELE.SEL_experiment_id
    FROM $TBAT_SEL_EXPERIMENT SELE
    WHERE SELE.experiment_title = '$experiment_title';
  ~;

  ($SEL_experiment_id) = $sbeams->selectOneColumn($sql);
  die "$experiment_title  not found" if (! $SEL_experiment_id);

} else {
  # Else, check that experiment number exists

  $sql = qq~
    SELECT SELE.SEL_experiment_id
    FROM $TBAT_SEL_EXPERIMENT SELE
    WHERE SELE.SEL_experiment_id = '$SEL_experiment_id';
  ~;

  my ($result) = $sbeams->selectOneColumn($sql);
  die "SEL_experiment_id $SEL_experiment_id  not found" if (! $result);
}


###############################################################################
###
### Main section: Map peptides.
###
###############################################################################



### Map peptides to Swiss-Prot proteins
$loader->map_peps_to_swissprot (
    SEL_experiment_id => $SEL_experiment_id,
    glyco => $OPTIONS{'glyco'},
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
);

### End main program
