#!/usr/local/bin/perl -w

#$Id: $

use DBI;
use Test::More tests => 9;
use Test::Harness;
use strict;

use FindBin qw($Bin);
use lib( "$Bin/../.." );
use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
my $sbeams = SBEAMS::Connection->new();

sub setup { 
}
BEGIN { setup() }

$|++; # unbuffer output

# comment out to troubleshoot
# close(STDERR);

my $glyco;

{  # Main test block

 
  # Can we use and instantiate module?
  use_ok( 'SBEAMS::Glycopeptide' );
  ok ( $glyco = SBEAMS::Glycopeptide->new(), "Instantiate glyco" );


  # Check tryptic digestion
  ok( test_tryptic_digestion(), 'Testing digestion' );

  # Check glycosite detection
  ok( test_glycosite_detection(), 'Testing Glycosite parser' );

  # Check glycosite detection
  ok( test_multiglycosite_detection(), 'Testing multi-site mapping' );

  use_ok( 'SBEAMS::Glycopeptide::Glyco_peptide_load' );
  ok ( test_motif_context(), "Get motif context" );

  ok ( test_cleanseq(), "Test sequence cleanup" );
  
  ok ( test_pepmass(), "Test mass calculation" );


} # End main block

### Subroutines ###

sub test_motif_context {
  my $ok = 1;

  # shorty
  my $seq = 'xxxxNXSxxxx';
  my $site = 4;
  my $gp = SBEAMS::Glycopeptide::Glyco_peptide_load->new();
  my $context = $gp->motif_context( 'seq', $seq, 'site', $site );
  $ok = 0 if $context ne '-xxxxNXSxxxx-';

  # exact
  $seq = 'xxxxxNXSxxxxx';
  $site = 5;
  $context = SBEAMS::Glycopeptide::Glyco_peptide_load->motif_context( 'seq', $seq, 'site', $site );
  $ok = 0 if $context ne 'xxxxxNXSxxxxx';

  # longish
  $seq = 'AAAxxxxxNXSxxxxxBBB';
  $site = 8;
  $context = SBEAMS::Glycopeptide::Glyco_peptide_load->motif_context( 'seq', $seq, 'site', $site );
  $ok = 0 if $context ne 'xxxxxNXSxxxxx';

  return $ok;


}


sub test_tryptic_digestion {
  my @peps = ( '-.R.A', 'R.AAKPAARPAAK.B', 'K.BBBBBR.C', 'R.CCCCCK.-' );
  my $seq = 'RAAKPAARPAAKBBBBBRCCCCCK';
  my $peps = $glyco->do_tryptic_digestion( aa_seq => $seq, 
                                           flanking => 1   );
  my $test = 1;
  for ( my $i = 0; $i <= $#{$peps}; $i++ ) {
    $test = 0 unless $peps[$i] eq $peps->[$i];
  }

  @peps = ( '-.AAAAAAK.B', 'K.BBBBB.-' );
  $seq = 'AAAAAAKBBBBB';
  $peps = $glyco->do_tryptic_digestion( aa_seq => $seq, 
                                           flanking => 1   );
  for ( my $i = 0; $i <= $#{$peps}; $i++ ) {
    $test = 0 unless $peps[$i] eq $peps->[$i];
  }

  return $test;
}

sub test_glycosite_detection {
  my $seq = 'AAAAAKAANATAAAAAAANTAAAANSAAAANASAAANKT';
  my $peps = $glyco->do_tryptic_digestion( aa_seq => $seq, 
                                           flanking => 1   );

  my $motif = 'N.[ST]';
  my $sites = $glyco->get_site_positions( seq => $seq, pattern => $motif );
  my $test = 1;

  my @sites = ( 8, 30, 36 );

  for ( my $i = 0; $i <= $#sites; $i++ ) {
#    print "$i) calc: $sites->[$i]\tman: $sites[$i]\n";
#    print substr( $seq, $sites[$i], 3 ) . "\n";
    $test = 0 unless $sites[$i] eq $sites->[$i];
  }
  return $test;

}


sub test_multiglycosite_detection {
  my $seq = 'AAAAAKAANATAAAAAAANTAAAANSAAAANASAAANKT';

  my $motif = 'N.[ST]';
  my $sites = $glyco->map_peptide_to_protein( protseq => $seq,
                                          multiple_mappings => 1,
                                          pepseq => $motif );
  my $test = 1;

  my @sites = ( 8, 30, 36 );

  for ( my $i = 0; $i <= $#sites; $i++ ) {
    my @prow = @{$sites->[$i]};
    $test = 0 unless $prow[0] == $sites[$i];
    $test = 0 unless $prow[1] == $prow[0] + 6;
  }
  return $test;
}


sub test_cleanseq {
  my $test = 1;

  my $before = 'N.N*N#ASDF.K';
  my $after = 'NNASDF';
  $test = 0 if $after ne uc($glyco->clean_pepseq($before));

  $before = 'N.NHTGYMPLCVASDFQWERTYHKLPIMN.K';
  $after = 'NHTGYMPLCVASDFQWERTYHKLPIMN';
  $test = 0 if $after ne uc($glyco->clean_pepseq($before));

  return $test;
    
  
}

sub test_pepmass {
  my $result = 1;
  my @seq = ( 'ACDEFGHIKLMNPQRSTVWY', 'ELVISQHASTERD',
               'AAAAA', 'CCCCC', 'DDDDD' );
  my @mass = ( 2394.1249, 1483.7267, 373.1961, 533.0565, 593.1453  );

  for ( my $i = 0; $i <= $#seq; $i++ ) {
    my $calcmass = $glyco->calculatePeptideMass(sequence => $seq[$i] );
#    print "$mass[$i] vs $calcmass\n";
#    $result = 0 if abs( 1 - $calcmass/$mass[$i] ) > 10e-7;# 0.000001; 
#    $result = 0 if abs( 1 - 1000/1000.001 ) >  10e-7;# 0.000001; 
    my $delta = abs($calcmass - $mass[$i]);
    $result = 0 if $delta && $calcmass/$delta < 1e6; 
  }
  return $result;
}


END {
  breakdown();
} # End END

sub breakdown { 
}

