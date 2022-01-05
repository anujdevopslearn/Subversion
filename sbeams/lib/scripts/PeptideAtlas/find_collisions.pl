#!/usr/local/bin/perl 

use strict;
use POSIX;
use Getopt::Long;
use File::Basename;

$|++; # don't buffer output
use lib( "/net/dblocal/www/html/devDC/sbeams/lib/perl/" );
use SBEAMS::Connection;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;
my $sbeams = new SBEAMS::Connection;
my $dbh = $sbeams->getDBHandle();

#### Create and initialize SSRCalc object with 3.0
use lib '/net/db/src/SSRCalc/ssrcalc';
$ENV{SSRCalc} = '/net/db/src/SSRCalc/ssrcalc';
use SSRCalculator;
my $SSRCalculator = new SSRCalculator;
$SSRCalculator->initializeGlobals3();
$SSRCalculator->ReadParmFile3();

# 0 => PepSeq
# 1 => Pepcharg
# 2 => Frag
# 3 => FragCharge
# 4 => IsoType
# 5 => Q1
# 6 => Q3
# 7 => CE
# 8 => ModPepSeq
# 9 => annotations (optional)
# Loop over hamid peptides.  Pull out info.
my %ssr;
my $args = process_args();
my $q1_window = $args->{parent_ion_window} || 1;
my $q3_window = $args->{fragment_ion_window} || 1;
my $ssr_window = $args->{ssr_calc_window} || 5;
my $h_thresh = $args->{height_threshold} || 250;
my $c_lib = $args->{consensus_lib} || 5;

my %inclusion_list;
my %seq2acc;
my %peptide2acc;
my @sequences;

my $outfile = "cspace_Q1_${q1_window}_Q3_${q3_window}_SSR_${ssr_window}_PH_${h_thresh}_CL_${c_lib}";
$outfile .= '_iCAT' if $args->{include_icat};
$outfile .= '_WO' if $args->{weight_by_nobs};
$outfile .= '.tsv';


if ( $args->{use_outfile} ) {
  open ( OUT, ">$outfile" ) || die "Unable to open $outfile";
  print "Will print results to $outfile\n";
}


{ #Main

  my $cnts = fetch_peptide_counts();

  if ( $args->{inclusion_list} && $args->{reference_db} ) {
    get_fasta();
    get_inclusion();
  }

  open ( TRANS, $args->{transitions} ) || usage( "Unable to open $args->{transitions}" );
  my %cnt_stats;
  while ( my $line = <TRANS> ) {
    chomp $line;
    my @line = split( "\t", $line, -1 );
  
    if ( $line[0] eq 'PepSeq' ) {
      if ( $args->{use_outfile} ) {
        print OUT join( "\t", @line, 'SSR', 'total_collisions', 'collision_intensity_sum' ) . "\n";
      } else {
        print join( "\t", @line, 'SSR', 'total_collisions', 'collision_intensity_sum' ) . "\n";
      }
      next;
    }
 

    my $s_ssr = calc_ssr( $line[0] );
  
    my $q1_delta = $q1_window/2;
    my $q3_delta = $q3_window/2;
    my $q1_range = ($line[5] - $q1_delta ) . " AND " . ($line[5] + $q1_delta);
    my $q3_range = ($line[6] - $q3_delta) . " AND " . ($line[6] + $q3_delta);
    my $sql = qq~
    SELECT mz_exact Q1, mz Q3, modified_sequence, sequence, relative_intensity,
           peak_label, CLS.consensus_library_spectrum_id, CLS.charge, collision_energy
    FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM CLS 
    JOIN $TBAT_CONSENSUS_LIBRARY_SPECTRUM_PEAK CLSP 
    ON CLS.consensus_library_spectrum_id = CLSP.consensus_library_spectrum_id
    WHERE consensus_library_id = $c_lib 
    AND mz_exact BETWEEN $q1_range
    AND mz BETWEEN $q3_range
    AND modified_sequence <> '$line[8]'
    AND relative_intensity > $h_thresh
    ~;
#    print "$sql\n"; exit;
  
  
  	my $sth = $sbeams->get_statement_handle( $sql );
    my $total = 0;
    my $sum = 0;
		my @spectra;
  	while( my @row = $sth->fetchrow_array() ) {
      unless ( $args->{include_icat} ) {
        if ( $row[2] =~ /(C\[330|C\[339|C\[545|C\[553|C\[303|C\[312)/ ) {
#          print STDERR "ICATagory one: $1\n";
          next;
          $cnt_stats{icat}++;
        } else {
          $cnt_stats{nonicat}++;
        }
      }

      # Minimum n_obs
      my $n_obs = 1;
      if ( $cnts->{$row[6]} ) {
        $n_obs = $cnts->{$row[6]};
        $cnt_stats{seen}++;
      } else {
        $cnt_stats{miss}++;
      }
      my $weight = $n_obs**0.5;
#      my $weight = $n_obs/1000;
#      if ( $weight > 1 ) { $cnt_stats{over}++; $weight = 1;
#      } elsif ( $weight < 0.01 ) { $cnt_stats{under}++; $weight = 0.01; }

      my $peak_score = $row[4] * $weight;
      $peak_score = $row[4] if !$args->{weight_by_nobs};

      my $t_ssr = calc_ssr( $row[3] );
      if ( abs( $t_ssr - $s_ssr ) > $ssr_window ) {
  #      print "Kicking T ssr is $t_ssr, S ssr is $s_ssr for $line[0] and $row[3]\n";
        $cnt_stats{ssr_fail}++;
      } else {
        $cnt_stats{ssr_pass}++;
  #      print "Using T ssr is $t_ssr, S ssr is $s_ssr for $line[0] and $row[3]\n";

				my $clean_seq = $row[2];
        $clean_seq =~ s/\[[^\]]+]//g;
         
        # Will now apply inclusion list logic, if applicatable
        if ( $args->{inclusion_list} && $args->{reference_db} ) {
          if ( !$peptide2acc{$clean_seq} ) {
            #$peptide2acc{$peptide}->{$acc}++;
            map_peptide( $clean_seq );
          }
          my $is_match = 0;
          for my $acc ( keys( %{$peptide2acc{$clean_seq}} ) ) {
            if ( $inclusion_list{$acc} ) {
#              print "Freaking $acc is included!\n";
              $cnt_stats{list_match}++;
              $is_match++;
              last;
            } else {
              $cnt_stats{list_mismatch}++;
#              print "Ain't got no $acc!\n";
            }
          }
          next unless $is_match;
        }
         



        $total++;
        $sum += $peak_score;
#    SELECT
#    0 mz_exact Q1,
#    1 mz Q3,
#    2 modified_sequence,
#    3 sequence,
#    4 relative_intensity
#    5 peak_label,
#    6 CLS.consensus_library_spectrum_id,
#    7 CLS.charge
#
#    PepSeq  clean
#    Pepcharg  7
#    Frag  5
#    FragCharge ''
#    IsoType  ''
#    Q1  0
#    Q3  1
#    CE
#    ModPepSeq 2
#    Group  'Contaminant'
#    total_collisions ''
#    collision_intensity_sum ''

        $row[8] = $row[8] || '-';
        $row[0] = sprintf( "%0.2f", $row[0] );
        $row[1] = sprintf( "%0.2f", $row[1] );
        $t_ssr = sprintf( "%0.2f", $t_ssr );
#				push @spectra,  [@row[2,0,1,4,5],'','','','','','end'];
        my @peak_label = split( ",", $row[5] );
        $row[5] = $peak_label[0];
				push @spectra,  [$clean_seq, @row[7,5], '-','-', @row[0,1,8,2], 'Contaminant', $t_ssr, '-', $row[4] ];
      }
    }
    $s_ssr = sprintf( "%0.2f", $s_ssr );
    if ( $args->{use_outfile} ) {

      # Original, no threshold mode
			if ( !defined $args->{display_collisions} ) {
        print OUT join( "\t", @line, $s_ssr, $total, $sum ) . "\n";
      # Newer, show spectra if over threshold mode
      } elsif ( $sum > $args->{display_collisions} ) {
        print OUT join( "\t", @line, $s_ssr, $total, $sum ) . "\n";
#        print OUT join( "\t", qw( pepseq Q1 Q3 rel_intensity peak_label ) ) . "\n";
        for my $s ( @spectra ) {
          print OUT join( "\t", @$s ) . "\n";
        }
			}

    } else {

      # Original, no threshold mode
			if ( !defined $args->{display_collisions} ) {
        print join( "\t", @line, $s_ssr, $total, $sum ) . "\n";
      # Newer, show spectra if over threshold mode
      } elsif ( $sum > $args->{display_collisions} ) {
        print join( "\t", @line, $s_ssr, $total, $sum ) . "\n";
#        print  join( "\t", qw( pepseq Q1 Q3 rel_intensity peak_label ) ) . "\n";
        for my $s ( @spectra ) {
          print  join( "\t", @$s ) . "\n";
        }
			}
    }
  
  }
  for my $k ( keys ( %cnt_stats ) ) { print STDERR "$k => $cnt_stats{$k}\n"; }
  close OUT if $args->{use_outfile};

} # End main

sub map_peptide {

  my $peptide = shift || return '';
  $peptide2acc{$peptide} ||= {};
  my @matches = grep( /$peptide/, @sequences );
#  print "$peptide matches " . scalar( @matches ) . " sequences\n";
  for my $seq ( @matches ) {
    for my $acc ( @{$seq2acc{$seq}} ) {
      $peptide2acc{$peptide}->{$acc}++;
#      print "ACC is $acc\n";
    }
  }
}

sub get_fasta {
#my $acc2peptide;
  return unless $args->{reference_db};
  open FSA, $args->{reference_db} || die "Unable to open file $args->{reference_db}";
  my $acc;
  my $seq;

  while ( my $line = <FSA> ) {
    chomp $line;
    if ( $line =~ /^>/ ) {
      if ( $seq ) {
        $seq =~ s/\s//gm;
        $seq = uc($seq);
        $seq2acc{$seq} ||= [];
        push @{$seq2acc{$seq}}, $acc;
        $seq = '';
      }
      $acc = $line;
      $acc =~ s/^>//g;
    } else {
      $seq .= $line;
    }
  }
  # Last line
  $seq =~ s/\s//gm;
  $seq = uc($seq);
  push @{$seq2acc{$seq}}, $acc;
  $seq = '';
  
  @sequences = keys(%seq2acc);

}

sub get_inclusion {
  return unless $args->{inclusion_list};
  open INCL, $args->{inclusion_list} || die "Unable to open file $args->{inclusion_list}";
  while ( my $line = <INCL> ) {
    chomp $line;
    $inclusion_list{$line}++;
  }
}

sub get_matches {
}

sub calc_ssr {
  my $pep = shift || die;
  if ( !$ssr{$pep} ) {
    $ssr{$pep} = $SSRCalculator->TSUM3($pep);
  }
  return $ssr{$pep};
}

sub usage {
  my $msg = shift || '';
  print qq~
  $msg

  Usage: $0 -t transitions_file [ -p 1 -f 1 -s 5 ]

   -t, --transitions         File containing list of transitions
   -p, --parent_ion_window   Size of mz window for parent (q1) ion, default 1.
   -f, --fragment_ion_window Size of mz window for fragment (q3) ion, default 1.
   -s, --ssr_calc_window     Size of ssr calc window for peptide defaults to 5.
   -h, --height_threshold    Height threshold for peak inclusion default 250
   -c, --consensus_lib       Consensus library_id used Default 5
   -u, --use_outfile         Use outputfile name based on settings 
   -b, --build_id            Atlas build id (for spectral counting)
   --include_icat            Exclude ICAT spectra, i.e. C330, 339, 545, 553,
                             303, and 312.
   -w, --weight_by_nobs      Weight peak height by the number of observations,
                             requires atlas_build_id
   -d, --display_collisions  If set, will display all potential collisions
                             over threshold value provided.
   -r, --reference_db        Fasta file of reference seqs against which to map
   --inclusion_list          List of proteins to be included in search

  END


  ~;
  exit;
}


sub process_args {
  my %args;
  GetOptions( \%args, 'transitions=s', 'parent_ion_window=f', 'use_outfile',
              'fragment_ion_window=f', 'ssr_calc_window=f', 'weight_by_nobs',
              'height_threshold=i', 'consensus_lib=i', 'build_id=i',
              'include_icat', 'display_collisions=i', 'reference_db:s',
              'inclusion_list:s' ) || usage();

  usage('Missing required param transitions') unless $args{transitions};
  return \%args;
}


sub fetch_peptide_counts {

  return {} unless $args->{build_id};
  my $msg = $sbeams->update_PA_table_variables($args->{build_id});

  my $sql = qq~
  SELECT consensus_library_spectrum_id, MPI.n_observations 
  FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM CLS
  JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI ON modified_sequence = modified_peptide_sequence
  JOIN $TBAT_PEPTIDE_INSTANCE PI ON MPI.peptide_instance_id = PI.peptide_instance_id
  WHERE charge = peptide_charge
  AND consensus_library_id = $c_lib
  AND atlas_build_id = $args->{build_id}
  ~;

  my %cnts;
	my $sth = $sbeams->get_statement_handle( $sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $cnts{$row[0]} = $row[1];
  }
  return \%cnts;
}


# For each Q1/Q3 pair, fetch Q3 peaks within 0.5 Th of each
# Sum these, and print out a 'collision index'.



__DATA__



PepSeq  Pepcharg        Frag    FragCharge      IsoType Q1      Q3      CE
DEIFVNLANK      2       y5      1       Light   581.8093        559.3204        31.10   DEIFVNLANK
DEIFVNLANK      2       y6      1       Light   581.8093        658.3888        31.10   DEIFVNLANK
DEIFVNLANK      2       y7      1       Light   581.8093        805.4572        31.10   DEIFVNLANK



sub getTransitions {

  my $sql =<<"  END";
  SELECT DISTINCT biosequence_name, PI.best_probability, PI.n_observations,
  PI.n_samples, PI.n_protein_mappings, PI.n_genome_locations, PI.preceding_residue,
  PI.following_residue, MPA.q1_mz, MPA.q3_mz, MPA.peptide_charge, MPA.q3_peak_intensity, 
  MPA.q3_ion_label, P.peptide_sequence
  FROM $TBAT_PEPTIDE P 
  JOIN $TBAT_PEPTIDE_INSTANCE PI ON (PI.peptide_id = P.peptide_id)
  JOIN $TBAT_PEPTIDE_MAPPING PM ON PM.peptide_instance_id = PI.peptide_instance_id
  JOIN $TBAT_BIOSEQUENCE BS ON BS.biosequence_id = PM.matched_biosequence_id
  JOIN $TBAT_MODIFIED_PEPTIDE_ANNOTATION MPA ON MPA.peptide_sequence = P.peptide_sequence
  WHERE PI.atlas_build_id IN ( 123 )
  AND biosequence_name LIKE 'Y%'
  ORDER BY biosequence_name, P.peptide_sequence, q3_peak_intensity DESC
  END

	my $sth = $sbeams->get_statement_handle( $sql );
	my @names = @{$sth->{NAME}};
	my %proteins;
	my %peptides;
	my %failure; 
	my %nofailure; 
	my %nmapper; 
  my $nrows = 0;
	my $mc = 0;
	my $ntt = 0;
	my $nmap = 0;
	while( my @row = $sth->fetchrow_array() ) {
#		last if $nrows++ > 10000;
		my $seq = $row[13];
		next if $failure{$seq . $row[8]};

		$proteins{$row[0]}++;
		$peptides{$row[13]} ||= {};

    # Weed out the bad apples
		if ( $seq =~ /[^P][RK].+/ ) {
			$failure{$seq . $row[8]} ||= {};
			$failure{$seq . $row[8]}->{mc}++;
			$mc++;
			next;
#			print "MC found in $seq\n";
		}

		if ( ($seq !~ /[RK]$/ && $row[7] ne '-')
         && ( $row[6] !~ /[RK-]/ )) {
			$failure{$seq . $row[8]} ||= {};
			$failure{$seq . $row[8]}->{ntt}++;
			$ntt++;
			next;
#			print "NTT bad for $row[6]." . $seq . ".$row[7]" . "\n";
		}

		if ( $row[4] > 1 && !$nmapper{$seq . $row[8]} ) {
#			$failure{$seq} ||= {};
#			$failure{$seq}->{nmap}++;
			$nmapper{$seq . $row[8]}++;
			$nmap++;
		}

		$nofailure{$seq . $row[8]}++;
		$peptides{$row[13]}->{$row[8]} ||= [];
#		$peptides{$row[13]}->{8} ||= {};
#		$peptides{$row[13]}->{8}->{peaks} ||= [];
#		next if scalar(@{$peptides{$row[13]}->{8}->{peaks}}) > 2;
#		push @{$peptides{$row[13]}->{8}->{peaks}}, $row[11] . '::::' . $row[9];
#		next if scalar(@{$peptides{$row[13]}->{$row[8]}}) > 2;
		push @{$peptides{$row[13]}->{$row[8]}}, $row[11] . '::::' . $row[9];
	}
  my @passed = sort( keys( %nofailure ) );
  my @all_peps = sort( keys( %peptides ) );
  my @all_prots = sort( keys( %proteins ) );
  my @failures = sort( keys( %failure ) );
	my $fail = scalar( @failures );
	my $peps = scalar( @all_peps );
	my $pass = scalar( @passed );
	my $prots = scalar( @all_prots );
	my $total = $fail + $pass;

	my $fail_rate = sprintf( "%0.2f", ($fail/$total) );

	print "$fail peptide ions of $total failed, $pass passed, for a failure rate of $fail_rate.\n";
	print "($mc MC and $ntt NTT < 2; $peps distinct peptide and $prots distinct proteins)\n";

  my %stats = ( q1_safe => 0, 
	              q1_high => 0 );
	my %intensity = ( m1_8 => 0,
	                  m1_6 => 0,
                    m1_4 => 0,
                    m1_0 => 0,
	                  f1_8 => 0,
	                  f1_6 => 0,
                    f1_4 => 0,
                    f1_0 => 0 );

  my %failover;

	for my $peptide ( @all_peps ) {
		for my $q1 ( sort { $a <=> $b } keys( %{$peptides{$peptide}} ) ) {
#			print "Q1 is $q1\n";
#			next;

      # get arrays of mz and intensity for given peptide/q1 pair
			my @trans = @{$peptides{$peptide}->{$q1}};
			my @mz;
			my @int;
			for my $i ( 0..7 ) {
        ( $int[$i], $mz[$i] ) = split( "::::", $trans[$i] );
			}

			if ( $q1 <= 1000 ) {
				$stats{q1_safe}++;
				if ( $mz[0] <= 1000 && $mz[1] <= 1000 && $mz[2] <= 1000 ) {
					$stats{safe_top_three}++;
				}

				if ( $int[0] > 8000 ) {
					$intensity{m1_8}++;
				} elsif (  $int[0] > 6000 ) {
					$intensity{m1_6}++;
				} elsif (  $int[0] > 4000 ) {
					$intensity{m1_4}++;
				} else {
					$intensity{m1_0}++;
				}

			} else {
				$stats{q1_high}++;
				if ( $mz[0] <= 1000 && $mz[1] <= 1000 && $mz[2] <= 1000 ) {
					$stats{high_top_three}++;
				}
			}

      my $cnt = 0;
			while ( $mz[$cnt] > 1000 ) {
				$cnt++;
			}

      if ( $mz[$cnt] > 1000 ) {
				$stats{all_high}++;
			} else {
				my $key = 1 + $cnt;
				$failover{$key}++;
				next unless $cnt;
				if ( $int[$cnt] > 8000 ) {
					$intensity{f1_8}++;
				} elsif (  $int[$cnt] > 6000 ) {
					$intensity{f1_6}++;
				} elsif (  $int[$cnt] > 4000 ) {
					$intensity{f1_4}++;
				} else {
					$intensity{f1_0}++;
				}
			}

		}
	}
  for my $k ( sort ( keys( %stats ) ) ) {
	  print "$k => $stats{$k}\n";
  }
  for my $k ( sort ( keys( %intensity ) ) ) {
	  print "$k => $intensity{$k}\n";
  }
  for my $k ( sort {$a <=> $b } ( keys( %failover ) ) ) {
	  print "$k => $failover{$k}\n";
  }
}


__DATA__

0	biosequence_name
1	best_probability
2	n_observations
3	n_samples
4	n_protein_mappings
5	n_genome_locations
6	preceding_residue
7	following_residue
8	q1_mz
9	q3_mz
10	peptide_charge
11	q3_peak_intensity
12	q3_ion_label
13	peptide_sequence
