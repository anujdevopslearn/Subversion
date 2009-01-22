#!/usr/local/bin/perl -w

###############################################################################
# Description : Script will pull all
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

my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

#### Create and initialize SSRCalc object with 3.0
use lib '/net/db/src/SSRCalc/ssrcalc';
$ENV{SSRCalc} = '/net/db/src/SSRCalc/ssrcalc';
use SSRCalculator;
my $SSRCalculator = new SSRCalculator;
$SSRCalculator->initializeGlobals3();
$SSRCalculator->ReadParmFile3();

use SBEAMS::Proteomics::PeptideMassCalculator;
my $massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator;

my $prog_name = $FindBin::Script;
my $usage = <<EOU;
Usage: $prog_name [ options ]
-v  --verbose     print maximal info 
-q  --quiet       print minimal info 
-t  --test        test only, db not updated
-r  --recalc      recalculate all values, not just nulls 

  # If none of the below options is specified, all three will be updated
-m  --mw          Update molecular weight
-p  --pi          Update isoelectric point
-h  --hp          Update relative hydrophobicity  
EOU

my %opts;

#### Process options
unless (GetOptions(\%opts,"verbose","quiet","test","recalc","mw","hp","pi")) {
  die "\n$usage";
}

# If none is specified, update all
unless ( $opts{mw} || $opts{hp} || $opts{pi} ) {
  $opts{pi}++;
  $opts{mw}++;
  $opts{hp}++;
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
  my $where = ( $opts{recalc} ) ? '' : qq~
  WHERE ( peptide_isoelectric_point IS NULL or 
          peptide_isoelectric_point = 0 or 
          molecular_weight IS NULL or 
          molecular_weight = 0 or
          SSRCalc_relative_hydrophobicity IS NULL or 
          SSRCalc_relative_hydrophobicity = 0 )
  ~;

  my $select = $sbeams->evalSQL( <<"  END_SQL" );
  SELECT peptide_id, peptide_sequence, peptide_isoelectric_point,molecular_weight,
         SSRCalc_relative_hydrophobicity
  FROM $TBAT_PEPTIDE
  $where
  ORDER BY peptide_id
  END_SQL

  my $dbh = $sbeams->getDBHandle();
  $dbh->{AutoCommit} = 0;
  $dbh->{RaiseError} = 1;
  my $sth = $dbh->prepare($select);
  $sth->execute();
  my @allpeps;
  while ( my @row = $sth->fetchrow_array() ) {
    push @allpeps, \@row;
  }
  $sth->finish();
  my $cnt = 0;

  my %calc_vals;
  my %fields = ( mw => 'molecular_weight',
                 pi => 'peptide_isoelectric_point',
                 hp => 'SSRCalc_relative_hydrophobicity',
               );
  
  print "Running against $TBAT_PEPTIDE, 5 seconds to quit if that is incorrect:\n" ;
  sleep 5;


#  print STDERR join( "\t", qw(ID Seq MW_db MW diff ppm pI_db pI HP_db HP ) ) . "\n";
  for my $row ( @allpeps ) {
    $cnt++;
    unless ( $cnt % 100 ){
      $dbh->commit();
      print '*';
    }
    print "\n" unless $cnt % 5000;
    my $sequence = $row->[1];
    
    $calc_vals{mw} = $massCalculator->getPeptideMass( sequence => $sequence,
                                                     mass_type => 'monoisotopic'
                                                    );

    $calc_vals{pi} = $atlas->calculatePeptidePI( sequence => $sequence );

    if ($SSRCalculator->checkSequence($sequence) && $sequence !~ /X/) {
      $calc_vals{hp} = $SSRCalculator->TSUM3($sequence);
    } else {
      print "WARNING: peptide '$sequence' contains residues invalid for SSRCalc\n" if $opts{verbose};
    }

    my $items = '';
    for ( qw( mw pi hp ) ) {
      if ( $opts{$_} ) {
        if ( !defined $calc_vals{$_} || $calc_vals{$_} == '' ) {
          $calc_vals{$_} = 'NULL' ;
        }
        $items .= ( $items ) ? ",\n" : "SET \n";
        $items .= " $fields{$_} = $calc_vals{$_}" 
      }
    }

    my $update =<<"    END_UPDATE";
UPDATE $TBAT_PEPTIDE $items 
WHERE peptide_id = $row->[0]
    END_UPDATE
#   print "$update\n" if $opts{verbose};

    next if $opts{test};
    $sbeams->do( $update );
  }
  $dbh->commit();
  my $t1 = new Benchmark;
  print "Processed $cnt rows\n" unless $opts{quiet};
  print "Operation took: " . timestr(timediff( $t1, $t0 )) . "\n" if $opts{verbose};

} # end main


