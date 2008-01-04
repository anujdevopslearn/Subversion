package SBEAMS::Glycopeptide::Utilities;

use SBEAMS::Connection qw( $log );
use SBEAMS::Glycopeptide::Tables;

use constant HYDROGEN_MASS => 1.0078;
use Bio::Graphics::Panel;

sub new {
  my $class = shift;
  my $this = {};
  bless $this, $class;
  return $this;
}

#+
# Routine counts the number of times pepseq matches protseq
# -
sub match_count {
  my $self = shift;
  my %args = @_;
  return unless $args{pepseq} && $args{protseq};

  my @cnt = split( $args{pepseq}, $args{protseq}, -1 );
  return $#cnt;
}

#+
# Routine finds and returns 0-based start/end coordinates of pepseq in protseq
# -
sub map_peptide_to_protein {
	my $self = shift;
	my %args = @_;
	my $pep_seq = $args{pepseq};
	my $protein_seq = $args{protseq};
  die 'doh' unless $pep_seq && $protein_seq;

  if ( $args{multiple_mappings} ) {
    my $posn = $self->get_site_positions( seq => $protein_seq,
                                      pattern => $pep_seq );
    my @posn;
    for my $pos ( @$posn ) {
      my @p = ( $pos, $pos + length( $pep_seq ) );
      push @posn, \@p;
    }
    return \@posn;
  }
	
	if ( $protein_seq =~ /$pep_seq/ ) {
		my $start_pos = length($`);    
		my $stop_pos = length($pep_seq) + $start_pos;  
		return ($start_pos, $stop_pos);	
	}else{
		return;
	}
}

#+
# @nparam aa_seq
# @nparam min_len
# @nparam max_len
# @nparam flanking
#-
sub do_tryptic_digestion {
  my $self = shift;
  my %args = @_;

  # Check for required params
  my $missing;
  for my $param ( qw( aa_seq ) ) {
    $missing = ( $missing ) ? $missing . ',' . $param : $param if !defined $args{$param};
  }
  die "Missing required parameter(s) $missing" if $missing;
  
  # Set default param values
  $args{flanking} ||= 0;
  $args{min_len} ||= 1;
  $args{max_len} ||= 10e6;

  # Store list to pass back
  my @peptides;
  
  # previous, current, next amino acid
  my ( $prev, $curr, $next );

  # current peptide and length
  my ($peptide, $length);

  my @aa = split "", $args{aa_seq};

  for ( my $i = 0; $i <= $#aa; $i++ ) {

    # Set the values for the position stores
    $prev = ( !$i ) ? '-' : $aa[$i - 1];
    $curr = $aa[$i];
    $next = ( $i == $#aa ) ? '-' : $aa[$i + 1];
#    print STDERR "i:$i, prev:$prev, curr:$curr, next:$next, aa:$#aa, pep:$peptide, len:$length flk:$args{flanking}\n";

    if ( !$peptide ) { # assumes we won't start with a non-aa character
      $peptide .= ( $args{flanking} ) ? "$prev.$curr" : $curr; 
      $length++;
      if ( $curr =~ /[RK]/i ) {
        if ( $next !~ /P/ ) {
          $peptide .= ( $args{flanking} ) ? ".$next" : ''; 
          if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
            push @peptides, $peptide 
          }
          $peptide = '';
          $length = 0;
        }
      }
    } elsif ( $curr !~ /[a-zA-Z]/ ) { # Probably a modification symbol
      $peptide .= @curr;
      $length++;
    } elsif ( $curr =~ /[RK]/i ) {
      if ( $next =~ /P/ ) {
        $peptide .= $curr;
        $length++;
      } else { 
        $length++;
        $peptide .= ( $args{flanking} ) ? "$curr.$next" : $curr; 
        if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
          push @peptides, $peptide 
        }
        $peptide = '';
        $length = 0;
      }
    } elsif ( $i == $#aa ) {
      $length++;
      $peptide .= ( $args{flanking} ) ? "$curr.$next" : $curr; 
      if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
        push @peptides, $peptide 
      }
      $peptide = '';
      $length = 0;
    } else {
      $length++;
      $peptide .= $curr; 
#      die "What the, i:$i, prev:$prev, curr:$curr, next:$next, aa:$#aa, pep:$peptide, len:$length\n";
    }
  }
  return \@peptides;
}


#+
# Routine generates standard 'tryptic' peptide from observed sequence,
# i.e. -.SHGTLFK.N
# -
sub getDigestPeptide {
  my $self = shift;
  my %args = @_;
  for my $req ( qw( begin end protseq ) ) {
    die "Missing required parameter $req" unless defined $args{$req};
  }
  my $length =  $args{end} - $args{begin};
  my $seq = '';
  if ( !$args{begin} ) {
    $seq = substr( '-' . $args{protseq}, $args{begin}, $length + 2 );
  } elsif ( $args{end} == length($args{protseq}) ) {
    $seq = substr( $args{protseq} . '-' , $args{begin} -1, $length + 2 );
  } else {
    $seq = substr( $args{protseq}, $args{begin} -1, $length + 2 );
  }
  $seq =~ s/^(.)(.*)(.)$/$1\.$2\.$3/;
  return $seq;
}

# Returns reference to an array holding the 0-based indices of a pattern 'X'
# in the peptide sequence
sub get_site_positions {
  my $self = shift;
  my %args = @_;
  $args{pattern} = 'N.[S|T]' if !defined $args{pattern};
  my $idx = $args{index_base} || 0;
  return unless $args{seq};

  my @posn;
  while ( $args{seq} =~ m/$args{pattern}/g ) {
    my $posn = length($`);
    push @posn, ($posn + $idx);# pos($string); # - length($&) # start position of match
  }
#  $log->debug( "Found $posn[0] for NxS/T in $args{seq}\n" );
  return \@posn;
}

sub get_current_prophet_cutoff {
  my $self = shift;
  my $sbeams = $self->getSBEAMS() || new SBEAMS::Connection;
  my $cutoff = $sbeams->get_cgi_param( 'glyco_prophet_cutoff' );
  if ( $cutoff ) {
    $self->set_prophet_cutoff( $cutoff );
  } else  {
    $cutoff = $sbeams->getSessionAttribute( key => 'glyco_prophet_cutoff' );
  }
  $cutoff ||= 0.8; 
  return $cutoff;
}

sub get_current_build_name {
  my $self = shift;

  if ( $self->{_build_name} && $self->{_build_name} ne 'unknown' ) {
    return $self->{_build_name};
  }

  my $build_id = $self->get_current_build();

  my $sbeams = $self->getSBEAMS();

  my ( $build_name ) = $sbeams->selectrow_array( <<"  END" );
  SELECT build_name FROM $TBGP_UNIPEP_BUILD 
  WHERE unipep_build_id  = $build_id
  END
  $self->{_build_name} = $build_name || 'unknown';
  return $self->{_build_name};

}
  
# Stubs
sub get_current_build {
  my $self = shift;
  my %args = @_;

  $log->debug( "getting current build, yo" );
  # Check self for value
  return $self->{_build_id} if ( $self->{_build_id} ); 
  $log->debug( "didn't have one cached" );


  my $sbeams = $self->getSBEAMS();
  if ( $sbeams->isGuestUser() ) {
  $log->debug( "getting current build, as guest" );

  # Unset session build
  $sbeams->setSessionAttribute( key   => 'unipep_build_id',
                                value => '' );
  # Get database default?
    ( $build_id ) = $sbeams->selectrow_array( <<"    END" );
    SELECT unipep_build_id FROM $TBGP_UNIPEP_BUILD WHERE is_default  = 1
    END

    # Last option
    $build_id ||= 1;

    $self->set_current_build( build_id => $build_id );
    $log->debug( "setting current build to $build_id as guest" );
    return $build_id 
  }

  my $sbeams = $self->getSBEAMS();

  my $build_id = $sbeams->getSessionAttribute( key   => 'unipep_build_id' );
  $log->debug( "Got current build to $build_id from session" ) if $build_id;

  if ( $build_id ) {
    $self->set_current_build( build_id => $build_id );
    return $build_id 
  }
  
  # Get database default?
  ( $build_id ) = $sbeams->selectrow_array( <<"  END" );
  SELECT unipep_build_id FROM $TBGP_UNIPEP_BUILD WHERE is_default  = 1
  END
  $log->debug( "Got default build to $build_id " ) if $build_id;

  # Last option
  $build_id ||= 1;
  $log->debug( "Just set build_id to 1: $build_id " ) if $build_id;

  $self->set_current_build( build_id => $build_id );
  return $build_id 
}

sub set_current_build {
  my $self = shift;
  my %args = @_;

  # Nothing to set
  return unless $args{build_id};
  # Nothing to set

  unless ( $self->is_valid_build( build_id => $args{build_id} ) ) {
    $log->error( "invalid build ID specified" );
    return '';
  }
  
  # Make sure we have an sbeams object
  my $sbeams = $self->getSBEAMS();

  # Cache in the object
  $self->{_build_id} = $args{build_id};

  # Cache in the session
  $sbeams->setSessionAttribute( key   => 'unipep_build_id',
                                value => $args{build_id} );

  return 1;
}

sub get_current_organism {
  my $self = shift;
  my $build_id = $self->get_current_build();

  my $sbeams = $self->getSBEAMS();
  my $sql =<<"  END";
  SELECT organism_name 
    FROM $TBGP_IPI_VERSION IV 
    JOIN $TB_ORGANISM O 
      ON O.organism_id = IV.organism_id
    JOIN $TBGP_PEPTIDE_SEARCH PS 
      ON PS.ref_db_id = IV.ipi_version_id
    JOIN $TBGP_BUILD_TO_SEARCH BTS 
      ON BTS.search_id = PS.peptide_search_id
    JOIN $TBGP_UNIPEP_BUILD UB 
      ON BTS.build_id = UB.unipep_build_id
  WHERE unipep_build_id = $build_id
  END
  my ( $organism ) = $sbeams->selectrow_array( $sql );
  $log->debug( "Org is $organism" );
  $log->debug( "SQL is \n" . $sbeams->evalSQL( $sql ) );

  return $organism || 'Human';

  
}

sub is_valid_build {
  my $self = shift;
  my %args = @_;

  # Did we get a reasonable value?
  if ( !$args{build_id} ) {
    $log->error( "Must pass build_id as a named param" );
    return 0;
  } elsif ( $args{build_id} !~ /^\d+$/ ) {
    $log->error( "build_id must be a number" );
    return 0;
  }

  # Make sure we have an sbeams object
  my $sbeams = $self->getSBEAMS();

  # See if it is in the database
  ( $build_id ) = $sbeams->selectrow_array( <<"  END" );
  SELECT COUNT(*) 
  FROM $TBGP_UNIPEP_BUILD 
  WHERE unipep_build_id = $args{build_id} 
  END

  return $build_id;
}

sub get_current_motif_type {
  my $self = shift;
  my $build_id = $self->get_current_build();

  my $sbeams = $self->getSBEAMS();
  # Check db for motif type
  my ( $motif ) = $sbeams->selectrow_array( <<"  END" );
  SELECT motif_type 
  FROM $TBGP_UNIPEP_BUILD 
  WHERE unipep_build_id = $build_id 
  END
  return ( $motif =~ /glyco/ ) ? 'glycopeptide' : 'phospho';
}

sub get_transmembrane_info {
  my $self = shift;
  my %args = @_;
  return unless $args{tm_info};
  my $string = $args{tm_info};
  my $plen = $args{end} || '_END_';

  my @tminfo;
  my $start = 0;
  my $side = '';
  my ($posn, $beg, $end );
  while ( $string =~ m/[^oi]*[oi]/g ) {
    next unless $&;
    my $range = $&;
    my ($beg, $end);
    if ( !$side ) {
      $side = ( $range eq 'i' ) ? 'intracellular' : 'extracellular';
      $posn = 1;
    } else {
      $range =~ m/(\d+)\-(\d+)([io])/g;
      $beg = $1;
      $end = $2;
      push @tminfo, [ $side, $posn, ($beg - 1) ];
      push @tminfo, ['tm', $beg, $end ];
      $posn = $end + 1;
      $side = ( $3 eq 'i' ) ? 'intracellular' : 'extracellular';
    }
  }
  push @tminfo, [ $side, $posn, $plen ];
  return \@tminfo;
}

sub getCurrentBuild {
  my $self = shift;
  my $sql = "Select ipi_version_name FROM $TBGP_IPI_VERSION";
  my ( $build ) = $self->getSBEAMS->selectrow_array( $sql );
  $build = 'V15';  # Fixme!
}

sub set_prophet_cutoff {
  my $self = shift;
  my $cutoff = shift || return;
  my $sbeams = $self->getSBEAMS();
  $sbeams->setSessionAttribute( key => 'glyco_prophet_cutoff',
                              value => $cutoff );
  return 1;
}

sub clean_pepseq {
  my $this = shift;
  my $seq = shift || return;
  $seq =~ s/\-MET\(O\)/m/g;
  $seq =~ s/N\*/n/g;
  $seq =~ s/N\#/n/g;
  $seq =~ s/M\#/m/g;
  $seq =~ s/d/n/g;
  $seq =~ s/U/n/g;
  
  # Phospho
  $seq =~ s/T\*/t/g;
  $seq =~ s/S\*/s/g;
  $seq =~ s/Y\*/y/g;
  $seq =~ s/T\&/t/g;
  $seq =~ s/S\&/s/g;
  $seq =~ s/Y\&/y/g;

  # Trim off leading/lagging amino acids
  $seq =~ s/^.\.//g;
  $seq =~ s/\..$//g;
  return $seq;
}

sub mh_plus_to_mass {
  my $self = shift;
  my $mass = shift || return;
  return $mass - HYDROGEN_MASS;
}

sub mass_to_mh_plus {
  my $self = shift;
  my $mass = shift || return;
  return $mass + HYDROGEN_MASS;
}


sub get_charged_mass {
  my $self = shift;
  my %args = @_;
  return unless $args{mass} && $args{charge};
#  my $hmass = 1.00794;
  my $hmass = HYDROGEN_MASS;
  return sprintf( '%0.4f', ( $args{mass} + $args{charge} * $hmass )/ $args{charge} ); 
}

###############################################################################
# getResidueMasses: Get a hash of masses for each of the residues
###############################################################################
sub getResidueMasses {
  my %args = @_;
  my $SUB_NAME = 'getResidueMasses';

  #### Define the residue masses
  my %residue_masses = (
    I => 113.1594,   # Isoleucine
    V =>  99.1326,   # Valine
    L => 113.1594,   # Leucine
    F => 147.1766,   # Phenyalanine
    C => 103.1388,   # Cysteine
    M => 131.1926,   # Methionine
    A =>  71.0788,   # Alanine
    G =>  57.0519,   # Glycine
    T => 101.1051,   # Threonine
    W => 186.2132,   # Tryptophan
    S =>  87.0782,   # Serine
    Y => 163.1760,   # Tyrosine
    P =>  97.1167,   # Proline
    H => 137.1411,   # Histidine
    E => 129.1155,   # Glutamic Acid (Glutamate)
    Q => 128.1307,   # Glutamine
    D => 115.0886,   # Aspartic Acid (Aspartate)
    N => 114.1038,   # Asparagine
    K => 128.1741,   # Lysine
    R => 156.1875,   # Arginine

    X => 118.8860,   # Unknown, avg of 20 common AA.
    B => 114.5962,   # avg N and D
    Z => 128.6231,   # avg Q and E
#  '#' => 0.9848
  );

  $residue_masses{C} += 57.0215 if $args{alkyl_cys};
  return \%residue_masses;
}


###############################################################################
# getMonoResidueMasses: Get a hash of masses for each of the residues
###############################################################################
sub getMonoResidueMasses {
  my %args = @_;
  my $SUB_NAME = 'getResidueMasses';

  #### Define the residue masses
  my %residue_masses = (
    G => 57.021464,
    D => 115.02694,
    A => 71.037114,
    Q => 128.05858,
    S => 87.032029,
    K => 128.09496,
    P => 97.052764,
    E => 129.04259,
    V => 99.068414,
    M => 131.04048,
    T => 101.04768,
    H => 137.05891,
    C => 103.00919,
    F => 147.06841,
    L => 113.08406,
    R => 156.10111,
    I => 113.08406,
    N => 114.04293,
    Y => 163.06333,
    W => 186.07931 ,
#   '#' => 0.98401,
    
    X => 118.8057,   # Unknown, avg of 20 common AA.
    B => 114.5349,   # avg N and D
    Z => 128.5506,   # avg Q and E
    );

  $residue_masses{C} += 57.0215 if $args{alkyl_cys};
  return \%residue_masses;
}
    
sub calculatePeptideMass {
  my $self = shift;
  my %args = @_;

  # Must specify sequence
  die "Missing required parameter sequence" unless $args{sequence};
  $args{alkyl_cys} ||= '';

  # Mass of subject peptide
  my $mass = 0;
  # Ref to hash of masses
  my $rmass;

  if ( $args{average} ) {
    $rmass = getResidueMasses( %args );
    $mass += 18.0153; # N and C termini have extra H, OH.
  } else {
    $rmass = getMonoResidueMasses( %args );
    $mass += 18.0105; # N and C termini have extra H, OH.
  }

  # has leading.sequence.lagging format trim all but sequence
  if ( $args{flanking} ) {
    $args{sequence} = substr( $args{sequence}, 2, length( $args{sequence} ) - 4 )
  }

  my $bail;
  while ( $args{sequence} !~ /^[a-zA-Z]+$/ ) {
    die "Had to bail\n" if $bail++ > 10;
    if ( $args{sequence} =~ /([a-zA-Z][*#@])/ ) {
      my $mod = $1;
      my $orig = $mod;
      $orig =~ s/[@#*]//;
      if ( $mod =~ /M/ ) {
        $mass += 15.9949;
        print "$args{sequence} => Got a mod M\n";
      } elsif ( $mod =~ /C/ ) {
        print "$args{sequence} => Got a mod C\n";
        $mass += 57.0215;
      } elsif ( $mod =~ /N/ ) {
        $mass += 0.9848;
        print "$args{sequence} => Got a mod N\n";
      } elsif ( $mod =~ /S|T|Y/ ) {
        $mass += 79.996;
        print "$args{sequence} => Got a mod S/T/Y\n";
      } else {
        die "Unknown modification $mod!\n";
      }
      unless ( $args{sequence} =~ /$mod/ ) {
        die "how can it not match?";
      }
#      print "mod is >$mod<, orig is >$orig<, seq is $args{sequence}\n";
      if ( $mod =~ /(\w)\*/ ) {
#        print "Special\n";
        $args{sequence} =~ s/$1\*//;
      } else {
        $args{sequence} =~ s/$mod//;
      }
#      $args{sequence} =~ s/N\*//;
      print "mod is $mod, orig is $orig, seq is $args{sequence}\n";
    }
  }
  

  my $seq = uc( $args{sequence} );
  my @seq = split( "", $seq );
  foreach my $r ( @seq ) {
    if ( !defined $rmass->{$r} ) {
      $log->error("Undefined residue $r in getPeptideMass");
      $rmass->{$r} = $rmass->{X} # Assign 'average' mass.
    }
    $mass += $rmass->{$r};
  }

  return sprintf( "%0.4f", $mass);
}

#+
# Returns hashref with isoelectric points of various single amino acids.
#-
sub getResidueIsoelectricPoints {
  my $self = shift;
  my %pi = ( A => 6.00,
             R => 11.15,
             N => 5.41,
             D => 2.77,
             C => 5.02,
             Q => 5.65,
             E => 3.22,
             G => 5.97,
             H => 7.47,
             I => 5.94,
             L => 5.98,
             K => 9.59,
             M => 5.74,
             F => 5.48,
             P => 6.30,
             S => 5.68,
             T => 5.64,
             W => 5.89,
             Y => 5.66,
             V => 5.96,
             
             X => 6.03,   # Unknown, avg of 20 common AA.
             B => 4.09,   # avg N and D
             Z => 4.44   # avg Q and E 
           );
  return \%pi;
}


#+ 
# Simple minded pI calculator, simply takes an average.
#-
sub calculatePeptidePI_old {
  my $self = shift;
  my %args = @_;
  die "Missing required parameter sequence" unless $args{sequence};
  $self->{_rpka} ||= $self->getResiduePKAs();
  my $seq = uc( $args{sequence} );
  my @seq = split( "", $seq );
#  my $pi = 2.2 + 9.5; # Average C and N terminal pKA
  my $pi = 3.1 + 8.0; # Average C and N terminal pKA
  my $cnt = 2;        # We have termini, if nothing else
  foreach my $r ( @seq ) {
    next if !defined $self->{_rpka}->{$r}; 
#    print "Calculating with $self->{_rpka}->{$r}\n";
    $pi += $self->{_rpka}->{$r};
    $cnt++;
  }
#  print "total pi is $pi, total cnt is $cnt\n";
  return sprintf( "%0.1f", $pi/$cnt );
}


#+
# pI calculator algorithm taken from proteomics toolkit 'Isotope Servlet'
#-
sub calculatePeptidePI {
  my $self = shift;
  my %args = @_;
  die "Missing required parameter sequence" unless $args{sequence};

  # Get pKa values
  $self->{_rpkav} ||= $self->getResiduePKAvalues();
  my %pka = %{$self->{_rpkav}};

  # split sequence into an array
  my $seq = uc( $args{sequence} );
  my @seq = split "", $seq;
  my %cnt;

  my $side_total = 0;
  for my $aa ( keys(%pka) ) {
    # Only consider amino acids that can carry a charge
    next unless $pka{$aa}->[2];

    # Count the occurences of each salient amino acid (C, D, E, H, K, R, Y)
    $cnt{$aa} = eval "$seq =~ tr/$aa/$aa/";
    $side_total += $cnt{$aa};
  }

  # pKa at C/N termini vary by amino acid
  my $nterm_pka = $pka{$seq[0]}->[1];
  my $cterm_pka = $pka{$seq[$#seq]}->[0];

  # Range of pH values
  my $ph_min = 0;
  my $ph_max = 14;
  my $ph_mid;

  # Don't freak out if we can't converge
  my $max_iterations = 200;

  # This is all approximate anyway
  my $precision = 0.01;

  # Loop de loop
  for( my $i = 0; $i <= $max_iterations; $i++ ) {
    $ph_mid =  $ph_min + ($ph_max - $ph_min)/2; 

    # Positive contributors
    my $cNter = 10**-$ph_mid / ( 10**-$nterm_pka + 10**-$ph_mid );
    my $carg  = $cnt{R} * 10**-$ph_mid / ( 10**-$pka{R}->[2] + 10**-$ph_mid );
    my $chis  = $cnt{H} * 10**-$ph_mid / ( 10**-$pka{H}->[2] + 10**-$ph_mid );
    my $clys  = $cnt{K} * 10**-$ph_mid / ( 10**-$pka{K}->[2] + 10**-$ph_mid );

    # Negative contributors
    my $cCter = 10**-$cterm_pka / ( 10**-$cterm_pka + 10**-$ph_mid );
    my $casp  = $cnt{D} * 10**-$pka{D}->[2] / ( 10**-$pka{D}->[2] + 10**-$ph_mid );
    my $cglu  = $cnt{E} * 10**-$pka{E}->[2] / ( 10**-$pka{E}->[2] + 10**-$ph_mid );
    my $ccys  = $cnt{C} * 10**-$pka{C}->[2] / ( 10**-$pka{C}->[2] + 10**-$ph_mid );
    my $ctyr  = $cnt{Y} * 10**-$pka{Y}->[2] / ( 10**-$pka{Y}->[2] + 10**-$ph_mid );
    
    # Charge, trying to minimize absolute value
    my $charge = $carg + $clys + $chis + $cNter - ($casp + $cglu + $ctyr + $ccys + $cCter);
    
    if ( $charge > 0.0) {
      $ph_min = $ph_mid; 
    } else {
      $ph_max = $ph_mid;
    }
    last if abs($ph_max - $ph_min) < $precision;
  }

  # Let lack of return precision reflect the fact that this is an estimate 
  return sprintf( "%0.1f", ($ph_max + $ph_min)/ 2 );
}

#+
# Returns ref to hash of one-letter amino acid => arrayref of N, 
# C and side-chain pKa values
#-
sub getResiduePKAvalues {
  my $self = shift;
                   #-COOH  -NH3  -R grp
  my %pka = ( A => [ 3.55, 7.59, 0.0 ],

              D => [ 4.55, 7.50, 4.05 ], # IS => ionizable sidechain
              N => [ 3.55, 7.50, 0.0 ],
              B => [ 4.35, 7.50, 2.0 ], # Asx

              C => [ 3.55, 7.50, 9.00  ], # IS

              E => [ 4.75, 7.70, 4.45 ], # IS
              Q => [ 3.55, 7.00, 0.0 ],
              Z => [ 4.15, 7.25, 2.2 ], # Glx

              F => [ 3.55, 7.50, 0.0 ],
              G => [ 3.55, 7.50, 0.0 ],
              H => [ 3.55, 7.50, 5.98  ], # IS
              I => [ 3.55, 7.50, 0.0 ],
              K => [ 3.55, 7.50, 10.0 ], # IS
              L => [ 3.55, 7.50, 0.0 ],
              M => [ 3.55, 7.00, 0.0 ],
              P => [ 3.55, 8.36, 0.0 ],
              R => [ 3.55, 7.50, 12.0  ], # IS
              S => [ 3.55, 6.93, 0.0  ],
              T => [ 3.55, 6.82, 0.0  ],
              V => [ 3.55, 7.44, 0.0 ],
              W => [ 3.55, 7.50, 0.0 ],
              Y => [ 3.55, 7.50, 10.0 ], # IS
              
              X => [ 3.55, 7.50, 2.3 ], # Unknown aa
              );

  return \%pka;
}


#+
# Returns hash of amino acid to pKa value; various tables exist.
#-
sub getResiduePKAs {
  my $self = shift;
  my $old = shift;
  my %pka1 = ( C => 8.4, 
               D => 3.9,
               E => 4.1,
               H => 6.0,
               K => 10.5,
               R => 12.5,
               Y => 10.5 );
  return \%pka1 if $old;

  my %pka = ( C => 9.0, 
              D => 4.05,
              E => 4.45,
              H => 5.98,
              K => 10.0,
              R => 12.0,
              Y => 10.0 );

  return \%pka;
}

#+
# Runs mass search vs database
#-
sub runBulkSearch {
  my $self = shift;
  my %args = @_;

  my @ids = @{$args{ids}};
  @ids = map { "'" . $_ . "'" } @ids;

  my $sbeams = $self->getSBEAMS();
  my $ids = join( ',', @ids );

  my $build_id = $self->get_current_build();
  my $cutoff = $self->get_current_prophet_cutoff();

  my $type = ( $args{id_type} eq 'swp' ) ? 'swiss_prot_acc' :
             ( $args{id_type} eq 'sym' ) ? 'protein_symbol' : 'ipi_accession_number';


  my $sql =<<"  END";
  SELECT DISTINCT ipi_accession_number, swiss_prot_acc, ID.ipi_data_id,
             observed_peptide_sequence, protein_symbol, protein_name, 
             OP.observed_peptide_id, peptide_prophet_score, peptide_mass, 
             delta_cn, synonyms
  FROM $TBGP_IPI_DATA ID 
  JOIN $TBGP_OBSERVED_TO_IPI OTI ON ID.ipi_data_id = OTI.ipi_data_id
  JOIN $TBGP_OBSERVED_PEPTIDE OP ON OP.OBSERVED_peptide_id = OTI.OBSERVED_peptide_id
  JOIN $TBGP_PEPTIDE_SEARCH PS ON PS.peptide_search_id = OP.peptide_search_id
  JOIN $TBGP_BUILD_TO_SEARCH BTS ON BTS.search_id = PS.peptide_search_id
  WHERE peptide_prophet_score >= $cutoff
   AND BTS.build_id = $build_id 
   AND $type IN ( $ids )
   ORDER BY ipi_accession_number, synonyms, swiss_prot_acc
  END
  $log->debug( $sql );

  my @results = $sbeams->selectSeveralColumns( $sql );
  return \@results;
}

sub getIPIGlycosites {
  my $self = shift;
  my %args = @_;
  return undef unless $args{ipi_data_id};

  my $sbeams = $self->getSBEAMS();

  my $sql =<<"  END";
  SELECT glycosite_id, protein_glycosite_position
  FROM $TBGP_GLYCOSITE 
  WHERE ipi_data_id = $args{ipi_data_id}
  END

  my @rows = $sbeams->selectSeveralColumns( $sql );
  return \@rows;
}



#+
# Runs mass search vs database
#-
sub runMassSearch {
  my $self = shift;
  my %args = @_;

  my @results = ( 'Group', 'Search Mass', 'IPI', 'Sequence', 'DB Mass', 'Delta', 'Protein Name', '# ox Met' );

  my $sbeams = $self->getSBEAMS();

  my $sql;
  if ( !$args{search} eq 'pred' ) {
    $sql =<<"    END";
    SELECT DISTINCT ipi_accession_number, CAST( predicted_peptide_sequence AS VARCHAR) ,
           experimental_peptide_mass, protein_name, 
           ABS( experimental_peptide_mass - SEARCHMASS ) delta
    FROM biomarker.dbo.predicted_peptide PP JOIN biomarker.dbo.ipi_data ID
    ON ID.ipi_data_id = PP.ipi_data_id
    WHERE ( (experimental_peptide_mass BETWEEN MINMASS AND MAXMASS )  OXCLAUSE )
    AND predicted_peptide_sequence LIKE '%#%'
    ORDER BY ABS( experimental_peptide_mass - SEARCHMASS ) ASC, experimental_peptide_mass ASC
    END
  } else {
    $sql =<<"    END";
    SELECT DISTINCT ipi_accession_number, identified_peptide_sequence,
           experimental_peptide_mass, protein_name,
           ABS( experimental_peptide_mass - SEARCHMASS ) delta
    FROM biomarker.dbo.identified_peptide IP JOIN biomarker.dbo.identified_to_ipi ITI
    ON ITI.identified_peptide_id = IP.identified_peptide_id
    JOIN biomarker.dbo.ipi_data ID
    ON ID.ipi_data_id = ITI.ipi_data_id
    WHERE ( (experimental_peptide_mass BETWEEN MINMASS AND MAXMASS )  OXCLAUSE )
    ORDER BY ABS( experimental_peptide_mass - SEARCHMASS ) ASC, experimental_peptide_mass ASC
    END
  }

  my $cnt;
  my @all_matches;
  for my $mass ( @{$args{masses}} ) {
    $log->debug( "MASS IS: $mass" );
    $cnt++;
    chomp $mass;
    my @matches;

#    Add proton mass?
#    my $mass = $mz * $ch - 1.0072;

    my $tolerance;
    if ( $args{mw_units} eq 'ppm' ) {
      my $mppm = $mass/1000000;
      $tolerance = $args{mass_window}/2*$mppm;
    } else {
      $tolerance = $args{mass_window}/2;
    }
    my $minmass = $mass - $tolerance;
    my $maxmass = $mass + $tolerance;

    my $ox_mass = 15.9949;

    my $ox_clause = '';
    if ( $args{ox_met} ) {
      my $ox_min = $minmass + $ox_mass;
      my $ox_max = $maxmass + $ox_mass;
      $ox_clause .= " OR ( experimental_peptide_mass BETWEEN $ox_min AND $ox_max ) \n"; 
      if ( $args{ox_met} > 1 ) {
        my $ox_min = $minmass + 2 * $ox_mass;
        my $ox_max = $maxmass + 2 * $ox_mass;
        $ox_clause .= " OR ( experimental_peptide_mass BETWEEN $ox_min AND $ox_max ) \n"; 
      }
    }

    my $mass_sql = $sql;
    $mass_sql =~ s/MINMASS/$minmass/g;
    $mass_sql =~ s/MAXMASS/$maxmass/g;
    $mass_sql =~ s/OXCLAUSE/$ox_clause/g;
    $mass_sql =~ s/SEARCHMASS/$mass/g;
   $log->debug( $mass_sql );

    my @results = $sbeams->selectSeveralColumns( $mass_sql );
    if ( scalar @results ) {
      for my $result ( @results ) {
        my $ox_num = 0;
        if ( $args{ox_met} ) {
          # Searched with ox_met, looking for +16 and maybe +32
          if ( $args{ox_met} > 1 ) {
          $log->debug( "Croaker " . $args{ox_met} .  " $result->[4] " );
            if ( $result->[2] > ($maxmass + $ox_mass) ) {
              if ( $result->[1] =~ /\..*M.*M.*\./ ) {
                $ox_num = 2;
              } else {
                $log->debug( "skippy" . $result->[1] );
                next;
              }
            } elsif ( $result->[2] > $maxmass ) {
              if ( $result->[1] =~ /\..*M.*\./ ) {
                $log->debug( "$result->[1] matched!" );
                $ox_num = 1;
              } else {
                $log->debug( "skiipy" . $result->[1] );
                next;
              }
            }
          }
        }
        $ox_num = ( $result->[4] > 1 ) ? 1 : 0;
        $log->debug( "pushing $result->[1]" );
        my @row = ( $cnt, $mass, @$result, $ox_num );
        push @matches, \@row;
      }
    } 
    unless ( scalar @matches ) {
        push @matches, [$cnt, $mass, 'n/a', 'n/a', 'n/a', 'n/a', 'n/a', 'n/a' ];
    }
    push @all_matches, @matches;
  }
  return \@all_matches;
}

1;

