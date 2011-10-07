#!/usr/local/bin/perl 

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
use Data::Dumper;

use lib "$FindBin::Bin/../../perl";

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Proteomics::PeptideMassCalculator;

# Initialize globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use lib '/net/db/src/SSRCalc/ssrcalc';
$ENV{SSRCalc} = '/net/db/src/SSRCalc/ssrcalc';
use SSRCalculator;
my $SSRCalculator = new SSRCalculator;
$SSRCalculator->initializeGlobals3();
$SSRCalculator->ReadParmFile3();

my $massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator;


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


  my %stats;

{ # Main Program:

  my $t0 = new Benchmark;


  #### Do the SBEAMS authentication and exit if a username is not returned
  my $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin');
  unless( $current_username ) {
    print "You must be a member of Peptide Atlas Admin to run this script\n";
    print $usage;
    exit 1;
  }

  # Fetch id_str to peptide from APD.peptide_identifier
  my $id2seq = get_peptide_identifiers();

  # Fetch accession to sequence from peptideatlas.peptide 
  my $acc2seq = get_peptide_accessions();

  for my $id ( keys( %{$id2seq} ) ) {
    my $rowdata = { peptide_accession => $id,
                    peptide_sequence => $id2seq->{$id} };

    if ( !$acc2seq->{$id} ) {
      $stats{nomatch}++;

      calc_peptide_info( $rowdata );
#      die Dumper( $rowdata );
    } else {
      $stats{match}++;
      die Dumper( $rowdata );
    }
  }


#    $sbeams->updateOrInsertRow(
#      update=>1,
#      table_name=>$TBAT_MODIFIED_PEPTIDE_INSTANCE,
#      rowdata_ref=>\%rowdata,
#      PK => 'modified_peptide_instance_id',
#      PK_value => $modified_peptide_instance_id,
#      verbose=>$opts{verbose},
#      testonly=>$opts{test},
#    );

  my $t1 = new Benchmark;

#  print "\nProcessed $cnt rows\n" unless $opts{quiet};
  print "Operation took: " . timestr(timediff( $t1, $t0 )) . "\n"
    unless $opts{quiet};

  for my $k ( sort( keys( %stats ) ) ) {
    print STDERR "$k => $stats{$k}\n";
  }
} # end main

sub get_peptide_identifiers {

  my $sql = "SELECT peptide_identifier_str, peptide FROM $TBAPD_PEPTIDE_IDENTIFIER WHERE peptide = 'GLGTDEDTLIEILAS'";
  my $sth = $sbeams->get_statement_handle( $sql );
  my %id2pep;
  my %pep2id;
  while ( my @row = $sth->fetchrow_array() ) {
    die "duplicate for $row[0] " if $id2pep{$row[0]}; 
    $id2pep{$row[0]} = $row[1];

    die "duplicate for $row[1] " if $pep2id{$row[1]}; 
    $pep2id{$row[1]} = $row[0];
  }
  print "read " . scalar( keys( %id2pep ) ) . " accessions \n";
  print Dumper ( %id2pep );
#  print Dumper ( %pep2id );
  return \%id2pep;
}

sub get_peptide_accessions {

  my $sql = "SELECT peptide_accession, peptide_sequence FROM $TBAT_PEPTIDE WHERE peptide_sequence = 'GLGTDEDTLIEILAS'";
  die "$sql";
  my $sth = $sbeams->get_statement_handle( $sql );
  my %id2pep;
  my %pep2id;
  while ( my @row = $sth->fetchrow_array() ) {
    die "duplicate for $row[0] " if $id2pep{$row[0]}; 
    $id2pep{$row[0]} = $row[1];

    die "duplicate for $row[1] " if $pep2id{$row[1]}; 
    $pep2id{$row[1]} = $row[0];
  }
  print "read " . scalar( keys( %id2pep ) ) . " accessions \n";
  print Dumper ( %id2pep );
#  print Dumper ( %pep2id );
  return \%id2pep;
}

sub calc_peptide_info {

  my $rowdata = shift || die "must pass hashref!";

  $rowdata->{peptide_length} = length( $rowdata->{peptide_sequence} );

  $rowdata->{molecular_weight} = $massCalculator->getPeptideMass( sequence => $rowdata->{peptide_sequence},
                                           mass_type => 'monoisotopic'
                                          );

  $rowdata->{peptide_isoelectric_point} = $atlas->calculatePeptidePI( sequence => $rowdata->{peptide_sequence} );

  $rowdata->{SSRCalc_relative_hydrophobicity} = '';

  if ($SSRCalculator->checkSequence($rowdata->{peptide_sequence}) && $rowdata->{peptide_sequence} !~ /XZBUJ/) {
    $rowdata->{SSRCalc_relative_hydrophobicity} = sprintf( "%0.1f", $SSRCalculator->TSUM3($rowdata->{peptide_sequence} ));
  }

}
