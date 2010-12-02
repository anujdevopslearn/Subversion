#!/usr/local/bin/perl 

#$Id:  $

use DBI;
use Test::More tests => 23;
use Test::Harness;
use strict;
use FindBin qw ( $Bin );
use lib( "$Bin/../.." );

# Globals
my $sbeams;
my $atlas;
my $pepselector;

use_ok( 'SBEAMS::Connection' );
use_ok( 'SBEAMS::PeptideAtlas' );
use_ok( 'SBEAMS::PeptideAtlas::BestPeptideSelector' );
ok( get_sbeams(), 'Instantiate sbeams object' );
ok( get_atlas(), 'Instantiate peptide atlas object' );
ok( authenticate(), 'Authenticate login' );
like( get_file( touch => 1, file => '' ), qr/\/tmp\/interact.xml/, 'Fetch filename without preferred' );

like( get_file( touch => 1, file => 'interact-combined.iproph.pep.xml', preferred => ['interact-combined.iproph.pep.xml'] ), 
              qr/\/tmp\/interact-combined.iproph.pep.xml/,
             'Fetch filename with preferred' );

ok( get_best_pep_selector(), 'Instantiate selector' );
ok( test_bad_peptide(), 'Check bad peptide scoring' );
ok( test_good_peptide(), 'Check good peptide scoring' );
ok( test_bad_override_peptide(), 'Check bad with override peptide scoring' );
ok( test_fragmentation(), 'Check peptide fragmentation' );
ok( test_fragment_order(), 'Check fragment ordering' );
ok( get_SSR_calculator(), 'Get SSRCalc calculator' );
ok( calculate_SSR(), 'Calculate SSR' );
ok( test_hydrophobic_peptide(), 'Check hydrophobic peptide scoring and annotation' );
ok( test_ECS_calculator(), 'Test ECS hydrophobicity calculator' );
ok( test_peptide_list_scoring() , 'Test peptide list scoring' );
ok( test_aspn_digest() , 'Test AspN Digestion' );
ok( test_gluc_digest() , 'Test GluC Digestion' );
ok( test_lysc_digest() , 'Test LysC Digestion' );
ok( test_orig_lysc_digest() , 'Test Original LysC Digestion' );


sub test_bad_peptide {
# A very bad peptide, should hit the following penalties!
#  Code    Penal   Description
#  M       .3      Exclude/Avoid M
#  nQ      .1      Exclude N-terminal Q
#  C       .7      Avoid C (dirty peptides don't come alkylated but can be)
#  W       .2      Exclude W
#  NG      .3      Avoid dipeptide NG
#  DP      .3      Avoid dipeptide DP
#  QG      .3      Avoid dipeptide QG
#  nxxG    .3      Avoid nxxG
#  nGPG    .1      Exclude nxyG where x or y is P or G
#  D       .9      Slightly penalize D or S in general?
#  S       .9      Slightly penalize D or S in general?
#
#  changed...
#
#    my %scores =  (  M => .3,
#                  nQ => .1,
#                  nE => .4,
#                  Xc => .5,
#                   C => .3,
#                   W => .1,
#                   P => .3,
#                  NG => .5,
#                  DP => .5,
#                  QG => .5,
#                  DG => .5,
#                nxxG => .3,
#                nGPG => .1,
#                   D => 1.0,
#                   S => 1.0 );
#
  my $peptide = 'QPGMCWNGDPQGDSR';
	my @peptides = ( [$peptide, 100000000] );

  # Score will vary with the default params
  my $score = 85737500;

	my $results = $pepselector->pabst_evaluate_peptides( peptides => \@peptides, score_idx => 1 );
	for my $res ( @{$results} ) {

    # approx...
    $res->[4] = int($res->[4] + 0.5);
		if ( $res->[4] == $score ) {
      return 1;
    } else {
      return 0;
    }
	}
}

sub test_bad_override_peptide {
  my %scores = ( M => 1,
                nQ => 1,
                C => 1,
                W => 1,
                P => 1,
                NG => 1,
                DP => 1,
                QG => 1,
                nxxG => 1,
                nGPG => 1,
                D => 1,
                S => 1 );

  my $peptide = 'QPGMCWNGDPQGDSR';
	my @peptides = ( [$peptide, 1000] );
	my $results = $pepselector->pabst_evaluate_peptides( peptides => \@peptides, score_idx => 1, pen_defs => \%scores );
	for my $res ( @{$results} ) {
		if ( int($res->[4]) == 1000 ) {
      return 1;
    } else {
      return 0;
    }
	}
}

sub test_hydrophobic_peptide {

  my %scores = ( 
                'M' => 1,
                'C' => 1,
                '4H' => 0.5,
                'Hper' => 0.5,
                '5H' => 0.5,
               );

  my $peptide = 'MMYCLVAFWMILALLWM';
# C,F,I,L,V,W,Y',
# F,I,L,V,W,M',
	my @peptides = ( [$peptide, 1000] );
	my $results = $pepselector->pabst_evaluate_peptides( peptides => \@peptides, score_idx => 1, pen_defs => \%scores );
	for my $res ( @{$results} ) {
#    print STDERR join( ", ", @{$res} ) . "\n";
    if ( int($res->[4]) == 125 && $res->[2] =~ /4H/ && $res->[2] =~ /Hper/ && $res->[2] =~ /5H/ ) {
      return 1;
    } else {
      return 0;
    }
  }
}

sub test_good_peptide {
  my $peptide = 'AGNTLLDIIK';
	my @peptides = ( [$peptide, 1000] );
	my $results = $pepselector->pabst_evaluate_peptides( peptides => \@peptides, score_idx => 1 );
	for my $res ( @{$results} ) {
		if ( int($res->[4]) == 1000 ) {
      return 1;
    } else {
      return 0;
    }
	}
	return 1;
}


sub test_peptide_list_scoring {
  my $p1 = 'AGNTLLDIIK';
  my $p2 = 'DAGNTLLDIIK';

  my %pephash = ( 'AAAAAAAAAAAA' => 1,
                  'DAGNTLLDIIK' => 1 );

	my @peptides = ( [$p1, 1000], [$p2, 1000] );
	my $results = $pepselector->pabst_evaluate_peptides( peptides => \@peptides, 
                                                      score_idx => 1,
                                               chk_peptide_hash => \%pephash,
                                               peptide_hash_scr => 2,
                                                      );
# 0 PEP
# 1 IN_SCR
# 2 ANNOT
# 3 SYN_SCR
# 4 MERG_SCR  
  my $result = 1;
	for my $res ( @{$results} ) {
#    print STDERR join( ":", @{$res} ) . "\n";

		if ( $res->[0] eq 'AGNTLLDIIK' ) {
      if ( $res->[2] && $res->[2] =~ /PepL/ ) {
        $result = 0;
      } 
      if ( $res->[4] != 1000 ) {
        $result = 0;
      }
    }
		if ( $res->[0] eq 'DAGNTLLDIIK' ) {
      if ( !$res->[2] || $res->[2] !~ /PepL/ ) {
        $result = 0;
      } 
      if ( $res->[4] != 2000 ) {
        $result = 0;
      }
    }
	}
	return $result;
}



sub get_file {
	my %args = @_;
	$args{file} ||= 'interact.xml';
	$args{preferred} ||= [];
	if ( $args{touch} ) {
		open( FIL, ">/tmp/$args{file}" ) || die( "unable to open file!" );
		close FIL;
	}

	my $result = $atlas->findPepXMLFile( search_path => '/tmp', preferred_names => $args{preferred} );
	if ( $args{touch} ) {
		system "rm /tmp/$args{file}";
	}
	return $result;
}


sub get_sbeams {
  $sbeams = new SBEAMS::Connection;
  return $sbeams;
}

sub get_atlas {
  $atlas = new SBEAMS::PeptideAtlas;
  $atlas->setSBEAMS( $sbeams );
  return $atlas;
}

sub get_best_pep_selector {
	$pepselector = new SBEAMS::PeptideAtlas::BestPeptideSelector;
	return $pepselector;
}


sub authenticate {
  return $sbeams->Authenticate();
}

sub test_fragmentation {
#  my $pep = 'AFQSAYPEFSR';
  my $pep = 'AAASGAEGGK';

  my $frags = $pepselector->generate_fragment_ions( peptide_seq => $pep,
                                                         max_mz => 2500,
                                                         min_mz => 400,
                                                           type => 'P',
                                                 precursor_excl => 5, 
                                                         charge => 2,
                                                 omit_precursor => 1
                                                  );

  my $ok = 0;
  for my $frag ( @$frags ) {
    if ( $frag->[0] eq 'AAASGAEGGK' && sprintf( "%0.3f", $frag->[2] ) == 409.704 && $frag->[6] eq 'y' && $frag->[7] == 5 ) {
      $ok++;      
#    } else {
#      print STDERR "$frag->[0], $frag->[6], $frag->[7], $frag->[2], " . sprintf( "%0.3f", $frag->[2] ) . "\n";
    }
  }
  return $ok;
}

sub test_fragment_order {

#  my $pep = 'AFQSAYPEFSR';
  my $pep = 'AAASGAEGGK';

  my $frags = $pepselector->generate_fragment_ions( peptide_seq => $pep,
                                                         max_mz => 2500,
                                                         min_mz => 100,
                                                           type => 'P',
                                                 precursor_excl => 5, 
                                                         charge => 2,
                                                 omit_precursor => 1
                                                  );

  # TBD
  for my $frag ( @$frags ) {
#      print STDERR join( ', ', @$frag ) . "\n";
  }


  my $frag_list = $pepselector->order_fragments( $frags );
  for my $frag ( @$frag_list ) {
#      print STDERR join( ', ', @$frag ) . "\n";
  }


	my $ok;
	if ( scalar( @{$frags} ) == scalar( @{$frag_list} ) ) {
		$ok++;
	}
  return 1;
}

sub get_SSR_calculator {
  $atlas->{_ssrCalc} = $atlas->getSSRCalculator();
}

sub calculate_SSR {
  my $pep_seq = 'DVQIILDSNITK';
  my $ssr = $atlas->calc_SSR( seq => $pep_seq );
#  print STDERR "SSR is $ssr\n";
  return sprintf( "%0.2f", $ssr ) == 31.69;
}


sub test_aspn_digest {
  my %protein = ( 'DAAAAADBBBBBBBDCCCCCCCCCCDEEEEE' => [ qw( DAAAAA DBBBBBBB DCCCCCCCCCC DEEEEE ) ],
                  'DAAAAADBBBBBBBDCCCCCCCCCCDEEEEED' => [ qw( DAAAAA DBBBBBBB DCCCCCCCCCC DEEEEE D ) ],
                  'AAAAADBBBBBBBDCCCCCCCCCCDEEEEE' => [ qw( AAAAA DBBBBBBB DCCCCCCCCCC DEEEEE ) ],
                  'AAAAADBBBBBBBDCCCCCCCCCCDEEEEED' => [ qw( AAAAA DBBBBBBB DCCCCCCCCCC DEEEEE D ) ],
      );
  my $err = 0;
  for my $protein ( keys( %protein ) ) {
    my @peps = @{$protein{$protein}};
    my $digest = $atlas->do_simple_digestion( enzyme => 'AspN', aa_seq => $protein );
#    print STDERR $protein ." => " . join( '__', @{$digest} ) . "\n";
    if ( scalar @{$digest} != scalar @peps ) {
#      print STDERR "scalar is wrong:" . scalar( @{$digest} ) . "\n";
      $err++;
    }
    for my $pep ( @{$digest} ) {
      unless ( grep /^$pep$/, @peps ) {
        $err++;
      }
    }
    for my $pep ( @peps ) {
      unless ( grep /^$pep$/, @{$digest} ) {
        $err++;
      }
    }
  }
  return ( $err ) ? 0 : 1;
}


sub test_gluc_digest {
  my %protein = ( 'EAAAAAEBBBBBBBECCCCCCCCCCEDD' => [ qw( E AAAAAE BBBBBBBE CCCCCCCCCCE DD ) ],
                  'EAAAAAEBBBBBBBECCCCCCCCCCEDDE' => [ qw( E AAAAAE BBBBBBBE CCCCCCCCCCE DDE ) ],
                  'AAAAAEBBBBBBBECCCCCCCCCCEDDE' => [ qw( AAAAAE BBBBBBBE CCCCCCCCCCE DDE ) ],
                  'AAAAAEBBBBBBBECCCCCCCCCCEDD' => [ qw( AAAAAE BBBBBBBE CCCCCCCCCCE DD ) ],
      );
  my $err = 0;
  for my $protein ( keys( %protein ) ) {
    my @peps = @{$protein{$protein}};
    my $digest = $atlas->do_simple_digestion( enzyme => 'gluc', aa_seq => $protein );
#    print STDERR $protein ." => " . join( '__', @{$digest} ) . "\n";
    if ( scalar @{$digest} != scalar @peps ) {
#      print STDERR "scalar is wrong:" . scalar( @{$digest} ) . "\n";
      $err++;
    }
    for my $pep ( @{$digest} ) {
      unless ( grep /^$pep$/, @peps ) {
        $err++;
      }
    }
    for my $pep ( @peps ) {
      unless ( grep /^$pep$/, @{$digest} ) {
        $err++;
      }
    }
  }
  return ( $err ) ? 0 : 1;
}

sub test_lysc_digest {
  my %protein = ( 'KAAAAAKBBBBBBBKCCCCCCCCCCKDD' => [ qw( K AAAAAK BBBBBBBK CCCCCCCCCCK DD ) ],
                  'KAAAAAKBBBBBBBKCCCCCCCCCCKDDK' => [ qw( K AAAAAK BBBBBBBK CCCCCCCCCCK DDK ) ],
                  'AAAAAKBBBBBBBKCCCCCCCCCCKDDK' => [ qw( AAAAAK BBBBBBBK CCCCCCCCCCK DDK ) ],
                  'AAAAAKBBBBBBBKCCCCCCCCCCKDD' => [ qw( AAAAAK BBBBBBBK CCCCCCCCCCK DD ) ],
      );
  my $err = 0;
  for my $protein ( keys( %protein ) ) {
    my @peps = @{$protein{$protein}};
    my $digest = $atlas->do_simple_digestion( enzyme => 'lysc', aa_seq => $protein );
#    print STDERR $protein ." => " . join( '__', @{$digest} ) . "\n";
    if ( scalar @{$digest} != scalar @peps ) {
#      print STDERR "scalar is wrong:" . scalar( @{$digest} ) . "\n";
      $err++;
    }
    for my $pep ( @{$digest} ) {
      unless ( grep /^$pep$/, @peps ) {
        $err++;
      }
    }
    for my $pep ( @peps ) {
      unless ( grep /^$pep$/, @{$digest} ) {
        $err++;
      }
    }
  }
  return ( $err ) ? 0 : 1;
}

sub test_orig_lysc_digest {
  my %protein = ( 'KAAAAAKBBBBBBBKCCCCCCCCCCKDD' => [ qw( K AAAAAK BBBBBBBK CCCCCCCCCCK DD ) ],
                  'KAAAAAKBBBBBBBKCCCCCCCCCCKDDK' => [ qw( K AAAAAK BBBBBBBK CCCCCCCCCCK DDK ) ],
                  'AAAAAKBBBBBBBKCCCCCCCCCCKDDK' => [ qw( AAAAAK BBBBBBBK CCCCCCCCCCK DDK ) ],
                  'AAAAAKBBBBBBBKCCCCCCCCCCKDD' => [ qw( AAAAAK BBBBBBBK CCCCCCCCCCK DD ) ],
      );
  my $err = 0;
  for my $protein ( keys( %protein ) ) {
    my @peps = @{$protein{$protein}};
    my $digest = $atlas->do_LysC_digestion( enzyme => 'lysc', aa_seq => $protein );
#    print STDERR $protein ." => " . join( '__', @{$digest} ) . "\n";
    if ( scalar @{$digest} != scalar @peps ) {
#      print STDERR "scalar is wrong:" . scalar( @{$digest} ) . "\n";
      $err++;
    }
    for my $pep ( @{$digest} ) {
      unless ( grep /^$pep$/, @peps ) {
        $err++;
      }
    }
    for my $pep ( @peps ) {
      unless ( grep /^$pep$/, @{$digest} ) {
        $err++;
      }
    }
  }
  return ( $err ) ? 0 : 1;
}



sub test_ECS_calculator {
  my $peptide = 'ARVLSQ';
  my $ecs = $atlas->calc_ECS( seq => $peptide );
#	print STDERR "$ecs\n";
  return $ecs == -0.13; 
}


sub breakdown {
 # Put clean-up code here
}
END {
  breakdown();
} # End END
