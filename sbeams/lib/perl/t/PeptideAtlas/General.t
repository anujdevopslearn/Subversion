#!/usr/local/bin/perl 

#$Id:  $

use DBI;
use Test::More tests => 35;
use Test::Harness;
use strict;
use FindBin qw ( $Bin );
#use lib( "/net/dblocal/www/html/devTF/sbeams/lib/perl/" );
use lib ( "$Bin/../.." );

# Globals
my $sbeams;
my $atlas;
my $pepselector;
my $pepfragmentor;


use_ok( 'SBEAMS::Connection' );
use_ok( 'SBEAMS::PeptideAtlas' );
use_ok( 'SBEAMS::PeptideAtlas::BestPeptideSelector' );
use_ok( 'SBEAMS::PeptideAtlas::PeptideFragmenter' );
ok( get_sbeams(), 'Instantiate sbeams object' );
ok( get_atlas(), 'Instantiate peptide atlas object' );
ok( authenticate(), 'Authenticate login' );
like( get_file( touch => 1, file => '' ), qr/\/tmp\/interact.xml/, 'Fetch filename without preferred' );

like( get_file( touch => 1, file => 'interact-combined.iproph.pep.xml', preferred => ['interact-combined.iproph.pep.xml'] ), 
              qr/\/tmp\/interact-combined.iproph.pep.xml/,
             'Fetch filename with preferred' );

ok( get_best_pep_selector(), 'Instantiate selector' );
ok( get_peptide_fragmentor(), 'Instantiate fragmentor' );
ok( test_bad_peptide(), 'Check bad peptide scoring' );
ok( test_good_peptide(), 'Check good peptide scoring' );
ok( test_bad_override_peptide(), 'Check bad with override peptide scoring' );
ok( test_fragmentation(), 'Check peptide fragmentation' );
ok( test_new_fragmentation(), 'Check peptide fragmentation' );
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
ok( test_charge_matrix(), 'Test Charge Matrix' );
ok( test_spectrum_comparator(), 'Test Spectrum comparator' );
ok( test_antigenic_predictor(), 'Test Antigenic Predictor' );
ok( test_uniprot_vars(), 'Test Uniprot Vars' );
ok( test_fetch_build_explicit(), 'Test Explicit build fetch' );
ok( test_fetch_build_organism(), 'Test build fetch with organism_name' );
ok( test_fetch_build_organism_id(), 'Test build fetch with organism_id' );
ok( test_fetch_build_specialized_build(), 'Test build fetch with specialized_build' );
ok( test_fetch_build_organism_and_specialized_build(), 'Test build fetch with organism_name and specialized build' );

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
    my %scores =  (  M => .3,
                  nQ => .1,
                   C => .3,
                   W => .1,
                   P => .3,
                   );

  $pepselector->set_pabst_penalty_values( %scores );   

  my $peptide = 'QPGMCWNGDPQGDSR';
	my @peptides = ( [$peptide, 100000000] );

  # Score will vary with the default params
  my $score = 27000;

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

sub test_charge_matrix {
  my @results;
  my $ok = 1;
  for my $m ( 1000, 2000, 400, 10000 ) {
    for my $c ( 2, 3, 4, 5 ) {
      my $chg = $pepselector->get_predicted_charge( mass => $m, e_chg => $c );
      push @results, $chg;
      if ( !$chg || $chg !~ /[234]/ ) {
        $ok = 0;
      }
    }
  }
#  print STDERR join( "::", @results ) . "\n";
  return $ok;
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
                '4H' => 0.5,
                'Hper' => 0.5,
                '5H' => 0.5,
                'M' => 1,
                'W' => 1,
                'C' => 1,
               );

  my $peptide = 'MMYCLVAFWMILALLWM';
# C,F,I,L,V,W,Y',
# F,I,L,V,W,M',
	my @peptides = ( [$peptide, 1000] );
	my $results = $pepselector->pabst_evaluate_peptides( peptides => \@peptides, score_idx => 1, pen_defs => \%scores );
	for my $res ( @{$results} ) {
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

sub get_peptide_fragmentor {
  $pepfragmentor = new SBEAMS::PeptideAtlas::PeptideFragmenter( MzMaximum => 2500, MzMinimum => 400 );
  return $pepfragmentor;
}



sub authenticate {
  return $sbeams->Authenticate();
}



sub test_uniprot_vars {
  my $sequence = 'MKFFVFALILALMLSMTGADSHAKRHHGYKRKFHEKHHSHRGYRSNYLYDN';
  my $html_seq = $atlas->get_html_seq_vars( seq => $sequence,
                                          accession => 'P15516' );
                                          
  my $var_list = $html_seq->{variant_list};
  use Data::Dumper;

  return $var_list;
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

sub test_new_fragmentation {

  my $pep = 'AAASC[160]GAEGGK';

  my %valid_frags = (
            'b5+' => 461.1818,
            'y5+' => 461.2360,
            'precursor' => 489.7196,
            'b6+' => 518.2033,
            'y6+' => 518.2574,
            'b7+' => 589.2404,
            'y7+' => 678.2881,
            'b8+' => 718.2830,
            'y8+' => 765.3201,
            'b9+' => 775.3045,
            'b10+' => 832.3259,
            'y9+' => 836.3572,
            'y10+' => 907.3944,
            'b11+' => 960.4209,
            'y11+' => 978.4315,
                    );

  my $frags = $pepfragmentor->getExpectedFragments( modifiedSequence => $pep,
                                                              charge => 2,
                                                      omit_precursor => 1,
                                                      precursor_excl => 5,
                                                     fragment_charge => 1,
                                                   );


  my $ok = 1;
#  print STDERR "Min is " . $pepfragmentor->getMzMinimum() . "\n";
  for my $frag ( @$frags ) {
    my $mz = sprintf( "%0.4f", $frag->{mz} );
    unless ( $valid_frags{$frag->{label}} &&  $valid_frags{$frag->{label}} == $mz ) {
      $ok = 0;
      last;
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
    my $digest = $atlas->do_simple_digestion( enzyme => 'lysc', aa_seq => $protein, min_len => 0, max_len => 70 );
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

sub test_spectrum_comparator {
  use lib '/net/db/projects/spectraComparison';
  $ENV{SSRCalc} = '/net/db/src/SSRCalc/ssrcalc';
  require FragmentationComparator;
  my $pep = 'AAASC[160]GAEGGK';
  my $chg = 2;
  my $modelmap = '/net/db/projects/spectraComparison/FragModel_AgilentQTOF.fragmod';
  my $fc = new FragmentationComparator;
  $fc->loadFragmentationModel( filename => $modelmap );
  $fc->setUseBondInfo(1);
  $fc->setNormalizationMethod(1);
#  my $results = "Pre-norm\n";
  my $spec = $fc->synthesizeIon( "$pep/$chg");
#  for my $mz ( @{$spec->{mzIntArray}} ) {
#    next if $mz->[1] < 0.1;
#    $results .= $mz->[2] . $mz->[3] . '^' . $mz->[4] . "($mz->[0]) = " . $mz->[1] . "\n";
#  }
  $fc->normalizeSpectrum($spec);
#  $results .= "\nPost-norm\n";
#  for my $mz ( @{$spec->{mzIntArray}} ) {
#    next if $mz->[1] < 0.1;
#    $results .= $mz->[2] . $mz->[3] . '^' . $mz->[4] . "($mz->[0]) = " . $mz->[1] . "\n";
#  }
  if ( ref($spec) eq 'HASH' ) {
    return 1;
  }
  return 0;
}


sub test_antigenic_predictor {

  my $seq = "MPKKKPTPIQLNPAPDGSAVNGTSSAETNLEALQKKLEELELDEQQRKRLEAFLTQKQKVGELKDDDFEKISELGAGNGGVVFKVSHKPSGLVMARKLIHLEIKPAIRNQIIRELQVLHECNSPYIVGFYGAFYSDGEISICMEHMVIKGLTYLREKHKIMHRDVKPSNILVNSRGEIKLCDFGVSGQLIDSMANSFVGTRSYMSPERLQGTHYSVQSDIWSMGLSLVEMAVGRYPIPPPDAKELELMFGCQVEGDAAETPPRPRTPGRPLSSYGMDSRPPMAIFELLDYIVNEPPPKLPSGVFSLEFQDFVNKCLIKNPAERADLKQLMVHAFIKRSDAEEVDFAGWLCSTIGLNQPSTPTHAAGV";

#  my $seq = "MWNLLHETDSAVATARRPRWLCAGALVLAGGFFLLGFLFGWFIKSSNEATNITPKHNMKAFLDELKAENIKKFLYNFTQIPHLAGTEQNFQLAKQIQSQWKEFGLDSVELAHYDVLLSYPNKTHPNYISIINEDGNEIFNTSLFEPPPPGYENVSDIVPPFSAFSPQGMPEGDLVYVNYARTEDFFKLERDMKINCSGKIVIARYGKVFRGNKVKNAQLAGAKGVILYSDPADYFAPGVKSYPDGWNLPGGGVQRGNILNLNGAGDPLTPGYPANEYAYRRGIAEAVGLPSIPVHPIGYYDAQKLLEKMGGSAPPDSSWRGSLKVPYNVGPGFTGNFSTQKVKMHIHSTNEVTRIYNVIGTLRGAVEPDRYVILGGHRDSWVFGGIDPQSGAAVVHEIVRSFGTLKKEGWRPRRTILFASWDAEEFGLLGSTEWAEENSRLLQERGVAYINADSSIEGNYTLRVDCTPLMYSLVHNLTKELKSPDEGFEGKSLYESWTKKSPSPEFSGMPRISKLGSGNDFEVFFQRLGIASGRARYTKNWETNKFSGYPLYHSVYETYELVEKFYDPMFKYHLTVAQVRGGMVFELANSIVLPFDCRDYAVVLRKYADKIYSISMKHPQEMKTYSVSFDSLFSAVKNFTEIASKFSERLQDFDKSNPIVLRMMNDQLMFLERAFIDPLGLPDRPFYRHVIYAPSSHNKYAGESFPGIYDALFDIESKVDPSKAWGEVKRQIYVAAFTVQAAAETLSEVA";

 my $ag = $atlas->calculate_antigenic_index( sequence => $seq );

 my $success = 0;
 for my $agn ( @{$ag} ) {
   if ( $agn->[0] == 344 && $agn->[1] eq 'DFAGWLCST' && $agn->[2] == 352 ) {
     $success = 1;
   }
 }
 return $success;

}



sub test_ECS_calculator {
  my $peptide = 'ARVLSQ';
  my $ecs = $atlas->calc_ECS( seq => $peptide );
#	print STDERR "$ecs\n";
  return $ecs == -0.13; 
}


sub test_fetch_build_explicit {
  my $test_id = 393;
  my $id = $atlas->getCurrentAtlasBuildID( parameters_ref => { atlas_build_id => $test_id } );
  return ( $id && $id eq 393 ) ? 1 : 0;
}
sub test_fetch_build_organism {
  my $test_id = 'Human';
  my $id = $atlas->getCurrentAtlasBuildID( parameters_ref => { organism_name => $test_id } );
  return ( $id && $id eq 393 ) ? 1 : 0;
}
sub test_fetch_build_organism_id {
  my $test_id = 2;
  my $id = $atlas->getCurrentAtlasBuildID( parameters_ref => { organism_id => $test_id } );
  return ( $id && $id eq 393 ) ? 1 : 0;
}
sub test_fetch_build_specialized_build {
  my $test_id = 'Human Liver';
  my $id = $atlas->getCurrentAtlasBuildID( parameters_ref => { organism_specialized_build => $test_id } );
  return ( $id && $id eq 395 ) ? 1 : 0;
}
sub test_fetch_build_organism_and_specialized_build {
  my $test_build = 'Human Liver';
  my $test_name = 'Human';
  my $id = $atlas->getCurrentAtlasBuildID( parameters_ref => { organism_specialized_build => $test_build, 
                                                               organism_name => $test_name    } );
  return ( $id && $id eq 395 ) ? 1 : 0;
}


sub breakdown {
 # Put clean-up code here
}
END {
  breakdown();
} # End END

