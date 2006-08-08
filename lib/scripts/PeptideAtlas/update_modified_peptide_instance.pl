#!/usr/local/bin/perl -w

###############################################################################
# Description : Update modified_peptide_instance with mass calculations
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use Benchmark;

use lib "$FindBin::Bin/../../perl";

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::Glycopeptide;

my $sbeams = new SBEAMS::Connection;
my $sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


my $prog_name = $FindBin::Script;
my $usage = <<EOU;
Usage: $prog_name [ options ]
-v  --verbose     print maximal info
-q  --quiet       print minimal info
-t  --test        test only, db not updated
-r  --recalc      recalculate all values, not just nulls
EOU



#### Process options
my %opts;
unless (GetOptions(\%opts,"verbose","quiet","test","recalc")) {
  die "\n$usage";
}



{ # Main Program:

  my $t0 = new Benchmark;


  #### Do the SBEAMS authentication and exit if a username is not returned
  my $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin');
  unless( $current_username ) {
    print "You must be a member of Peptide Atlas Admin to run this script\n";
    print $usage;
    exit 1;
  }


  use SBEAMS::Proteomics::PeptideMassCalculator;
  my $calculator = new SBEAMS::Proteomics::PeptideMassCalculator;


  my $where = ( $opts{recalc} ) ? '' : qq~
  WHERE ( monoisotopic_peptide_mass IS NULL or
          average_peptide_mass IS NULL or
          monoisotopic_parent_mz IS NULL or
          average_parent_mz IS NULL )
  ~;

  my $sql = qq~
    SELECT modified_peptide_instance_id,peptide_charge,
           modified_peptide_sequence
      FROM $TBAT_MODIFIED_PEPTIDE_INSTANCE
    $where
  ~;

  my @allpeps = $sbeams->selectSeveralColumns($sql);

  my $cnt = 0;
  foreach my $row ( @allpeps ) {
    $cnt++;
    unless ( $cnt % 100 ){
      print "$cnt..." unless $opts{quiet};;
    }

    my ($modified_peptide_instance_id,$peptide_charge,
	$modified_peptide_sequence) = @{$row};

    my %rowdata = (
      monoisotopic_peptide_mass => $calculator->getPeptideMass(
				     sequence => $modified_peptide_sequence,
                                     mass_type => 'monoisotopic',
                                   ),
      average_peptide_mass => $calculator->getPeptideMass(
			   	     sequence => $modified_peptide_sequence,
                                     mass_type => 'average',
                                   ),
      monoisotopic_parent_mz => $calculator->getPeptideMass(
				     sequence => $modified_peptide_sequence,
                                     mass_type => 'monoisotopic',
                                     charge => $peptide_charge,
                                   ),
      average_parent_mz => $calculator->getPeptideMass(
				     sequence => $modified_peptide_sequence,
                                     mass_type => 'average',
                                     charge => $peptide_charge,
                                   ),
    );


    $sbeams->updateOrInsertRow(
      update=>1,
      table_name=>$TBAT_MODIFIED_PEPTIDE_INSTANCE,
      rowdata_ref=>\%rowdata,
      PK => 'modified_peptide_instance_id',
      PK_value => $modified_peptide_instance_id,
      verbose=>$opts{verbose},
      testonly=>$opts{test},
    );

  }

  my $t1 = new Benchmark;

  print "\nProcessed $cnt rows\n" unless $opts{quiet};
  print "Operation took: " . timestr(timediff( $t1, $t0 )) . "\n"
    unless $opts{quiet};

} # end main


