package SBEAMS::PeptideAtlas::Utilities;

use List::MoreUtils qw(uniq);

use lib "/net/db/projects/PeptideAtlas/lib/Swissknife/lib";
use vars qw( $sbeams $resultset_ref );

use SWISS::Entry;
use SWISS::FTs;
use SBEAMS::Connection qw( $log $q );
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ProtInfo;
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Proteomics::PeptideMassCalculator;

use constant HYDROGEN_MASS => 1.0078;
use Storable qw( nstore retrieve dclone );
use Bio::Graphics::Panel;
use Data::Dumper;

use strict;

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
					  pattern => $pep_seq,
            );
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
  } else {
    return;
  }
}

#+
# @nparam aa_seq
# @nparam enzyme
# @nparam min_len
# @nparam max_len
#-
sub do_simple_digestion {
  my $self = shift;
  my %args = @_;

  # Check for required params
  my $missing;
  for my $param ( qw( aa_seq enzyme ) ) {
    $missing = ( $missing ) ? $missing . ',' . $param : $param if !defined $args{$param};
  }
  die "Missing required parameter(s) $missing" if $missing;

  my $enz = lc( $args{enzyme} );

  if ( !grep /$enz/, qw( gluc trypsin lysc lysarg_r lysarg_k cnbr aspn lysarginase chymotrypsin ) ) {
    $log->debug( "Unknown enzyme $enz" );
    return;
  }

  if ( $enz =~ /chymotrypsin/ ) {
    return $self->do_chymotryptic_digestion( %args );
  } elsif (  $enz =~ /trypsin/ ) {
    return $self->do_tryptic_digestion( %args );
  } elsif (  $enz =~ /lysarginase/ ) {
    my $kpos = $self->do_simple_digestion( %args, enzyme => 'lysarg_k' );
    my $rpos = $self->do_simple_digestion( %args, enzyme => 'lysarg_r' );
    my @sorted = ( sort { $a <=> $b } @{$kpos}, @{$rpos} );
    return \@sorted;
  }

  # trypsin, GluC, LysC, and CNBr clip Cterminally
  my $term = 'C';

  # N side cutters 
  if ( $enz eq 'aspn' || $enz =~ /lysarg/  ) {
    $term = 'N' 
  }

  my %regex = ( aspn => 'D',
                gluc => 'E',
                lysc => 'K',
                lysarg_r => 'R',
                lysarg_k => 'K',
                cnbr => 'M',
              );
  
  my @peps = split( /$regex{$enz}/, $args{aa_seq} );

  my @fullpeps;
  my $cnt = 0;
  for my $pep ( @peps ) {
    if ( $term eq 'N' ) {
      # Don't add pivot AA to first peptide
      if ( $cnt++ ) {
        $pep = $regex{$enz} . $pep;
#      } elsif ( $args{aa_seq} =~ /^$regex{$enz}/ ) {
#        $pep = $regex{$enz} . $pep;
      }
    } else {
      if ( $cnt++ < $#peps ) {
        $pep .= $regex{$enz};
      } elsif ( $args{aa_seq} =~ /$regex{$enz}$/ ) {
        $pep .= $regex{$enz};
      }
    }
    if ( $pep ) {
      next if ( $args{min_len} && length( $pep ) < $args{min_len} ); 
      next if ( $args{max_len} && length( $pep ) > $args{max_len} ); 
      push @fullpeps, $pep;
    }
  }
  if ( $term eq 'N' && $args{aa_seq} =~ /$regex{$enz}$/ ) {
    push @fullpeps, $regex{$enz} unless ( $args{min_len} && 1 < $args{min_len} ); 
  }

  if ( $args{positions} ) {
    my @posns;
    my $currpos = 0;
    for my $pep ( @fullpeps ) {
      $currpos += length( $pep ); 
      push @posns, $currpos;
    }
    return \@posns;
  }
  return \@fullpeps;
}


#+
# @nparam aa_seq
# @nparam min_len
# @nparam max_len
# @nparam flanking
#-
sub do_LysC_digestion {
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
      if ( $curr =~ /[K]/i ) {
	$peptide .= ( $args{flanking} ) ? ".$next" : ''; 
	if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
	  push @peptides, $peptide 
	}
	$peptide = '';
	$length = 0;
      }
    } elsif ( $curr !~ /[a-zA-Z]/ ) { # Probably a modification symbol
      $peptide .= $curr;
      $length++;
    } elsif ( $curr =~ /[K]/i ) {
      $length++;
      $peptide .= ( $args{flanking} ) ? "$curr.$next" : $curr; 
      if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
        push @peptides, $peptide 
      }
      $peptide = '';
      $length = 0;
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
# @nparam aa_seq
# @nparam min_len
# @nparam max_len
# @nparam flanking
#-
sub do_full_tryptic_digestion {
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
  $args{split_asterisk} = 1 if !defined $args{split_asterisk};

  # Store list to pass back
  my @peptides;

  # If we get option to split on '*' peptides, do this with recursive calls
  if ( $args{split_asterisk} ) {
    my @seqs = split( /\*/, $args{aa_seq} );
    for my $seq ( @seqs ) {
      my $sub_tryp = $self->do_full_tryptic_digestion( %args, aa_seq => $seq, split_asterisk => 0 );
      push @peptides, @{$sub_tryp};
    }
    return \@peptides;
  }

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
      $peptide .= $curr;
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
    if ( $i == $#aa && $peptide eq $aa[$i] ) {
      push @peptides, $aa[$i] if $args{min_len} < 2;
    }
  }

  if ( $args{positions} ) {
    my @posns;
    my $currpos = 0;
    for my $pep ( @peptides ) {
      $currpos += length( $pep ); 
      push @posns, $currpos;
    }
    return \@posns;
  }

  return \@peptides;
}

sub do_simple_tryptic_digestion {
  my $self = shift;
  my %args = @_;
  return $self->do_tryptic_digestion( %args );
}

sub do_tryptic_digestion {
  my $self = shift;
  my %args = @_;

  # Check for required params
  my $missing;
  for my $param ( qw( aa_seq ) ) {
    $missing = ( $missing ) ? $missing . ',' . $param : $param if !defined $args{$param};
  }
  die "Missing required parameter(s) $missing" if $missing;

  if ( $args{flanking} || $args{aa_seq} =~ /\d/ ) {
    return $self->do_full_tryptic_digestion( %args );
  }
  
  # Set default param values
  $args{min_len} ||= 1;
  $args{max_len} ||= 10e9;
  $args{split_asterisk} = 1 if !defined $args{split_asterisk};


  # Store list to pass back
  my @peptides;

  # If we get option to split on '*' peptides, do this with recursive calls
  if ( $args{split_asterisk} ) {
    my @seqs = split( /\*/, $args{aa_seq} );
    for my $seq ( @seqs ) {
      my $sub_tryp = $self->do_tryptic_digestion( %args, aa_seq => $seq, split_asterisk => 0 );
      push @peptides, @{$sub_tryp};
    }
  } else {
    for my $cpep ( split(/(?!P)(?<=[RK])/, $args{aa_seq} ) ) {
      next if length( $cpep ) < $args{min_len};
      next if length( $cpep ) > $args{max_len};
      push @peptides, $cpep;
    }
  }
  return \@peptides;
}

#+
# @nparam aa_seq
# @nparam min_len
# @nparam max_len
# @nparam flanking
#-
sub do_chymotryptic_digestion {
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
      if ( $curr =~ /[FWY]/i ) {
        $peptide .= ( $args{flanking} ) ? ".$next" : ''; 
        if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
          push @peptides, $peptide 
        }
        $peptide = '';
        $length = 0;
      }
    } elsif ( $curr !~ /[a-zA-Z]/ ) { # Probably a modification symbol
      $peptide .= $curr;
      $length++;
    } elsif ( $curr =~ /[FWY]/i ) {
      $length++;
      $peptide .= ( $args{flanking} ) ? "$curr.$next" : $curr; 
      if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
        push @peptides, $peptide 
      }
      $peptide = '';
      $length = 0;
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
  if ( $args{positions} ) {
    my @posns;
    my $currpos = 0;
    for my $pep ( @peptides ) {
      $currpos += length( $pep ); 
      push @posns, $currpos;
    }
    return \@posns;
  }
  return \@peptides;
}


#+
# @nparam aa_seq
# @nparam min_len
# @nparam max_len
# @nparam flanking
#-
sub do_gluc_digestion {
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
      if ( $curr =~ /[DE]/i ) {
        $peptide .= ( $args{flanking} ) ? ".$next" : ''; 
        if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
          push @peptides, $peptide 
        }
        $peptide = '';
        $length = 0;
      }
    } elsif ( $curr !~ /[a-zA-Z]/ ) { # Probably a modification symbol
      $peptide .= $curr;
      $length++;
    } elsif ( $curr =~ /[DE]/i ) {
      $length++;
      $peptide .= ( $args{flanking} ) ? "$curr.$next" : $curr; 
      if ( $length <= $args{max_len} && $length >= $args{min_len} ) {
        push @peptides, $peptide 
      }
      $peptide = '';
      $length = 0;
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

#########################
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

#
# Add predicted tryptic peptides, plus glycosite record if appropriate.
#
sub getGlycoPeptides {
  my $self = shift;
  my %args = @_;
  my $sbeams = $self->getSBEAMS();
  my $idx = $args{index} || 0;

  my $err;
  for my $opt ( qw( seq ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $args{$opt};
  }
  die ( "Missing required parameter(s): $err in " . $sbeams->get_subname() ) if $err;

  $log->debug( "Input sequence is $args{seq}" );

  # Arrayref of glycosite locations
  my $sites = $self->get_site_positions( seq => $args{seq},
					 pattern => 'N[^P][S|T]' );
#  $log->debug( "Sites found at:\n" . join( "\n", @$sites ) );

  my $peptides = $self->do_tryptic_digestion( aa_seq => $args{seq} );
#  $log->debug( "Peptides found at:\n" . join( "\n", @$peptides ) );

  # Hash of start => sequence for glcyopeps
  my %glyco_peptides;
  my $symbol = $args{symbol} || '*';

  # Index into protein
  my $p_start = 0;
  my $p_end = 0;

  my $site = shift( @$sites );

  for my $peptide ( @$peptides ) {
    last if !$site;
    my $site_seq = substr( $args{seq}, $site, 3 ); 
#    $log->debug( "site is $site: $site_seq ");
#    $log->debug( "peptide is $peptide" );

    $p_end = $p_start + length($peptide);
    my $curr_start = $p_start;
    $p_start = $p_end;
    my $calc_seq = substr( $args{seq}, $curr_start, length($peptide) ); 
#    $log->debug( "calc peptide is $calc_seq" );

    if ( $site > $p_end ) {
#      $log->debug( "$curr_start - $p_end doesn't flank $site yet" );
      # Need another peptide 
      next;
    } elsif ( $site < $p_end ) {
      $log->debug( "storing glycopeptide $peptide containing site $site_seq ($site)" );
#      $log->debug( "$site is flanked by $curr_start - $p_end" );
      # Store the peptide
      if ( $args{annot} ) {
        my $site_in_peptide = $site - $curr_start;
#        $log->debug( "Pre peptide is $peptide" );
#        $log->debug( "Site in peptide is $site_in_peptide, which is an " . substr( $peptide, $site_in_peptide, 1 ) );
        substr( $peptide, $site_in_peptide, 1, "N_" );
#        $log->debug( "Aft peptide is $peptide" );
      }
      $glyco_peptides{$curr_start + $idx} = $peptide;
#      $glyco_residue{$peptide . '::' . $curr_start} = [ $site - $curr_start ];
      $site = shift( @$sites );
    }
#
    # get the next site not in this peptide
    while( defined $site && $site < $p_end ) {
      if ( $args{annot} ) {
        my $cnt = $peptide =~ tr/_/_/;
        my $site_in_peptide = $site - $curr_start + $cnt;
#        $log->dezug( "Pre peptide is $peptide (has $cnt sites" );
#        $log->debug( "Site in peptide is $site_in_peptide, which is an " . substr( $peptide, $site_in_peptide, 1 ) );
        substr( $peptide, $site_in_peptide, 1, "N$symbol" );
#        $log->debug( "Aft peptide is $peptide" );
      }
      $glyco_peptides{$curr_start + $idx} = $peptide;
#      $log->debug( "burning $site: " . substr( $args{seq}, $site, 3 ) );
      $site = shift( @$sites );
#      $log->debug( "Set 
    }
  }
  # If user desires motif-bound N's to be annotated
#  if ( $args{annot} ) { my $symbol = $args{symbol} || '*'; for my $k (keys( %glyco_peptides ) ) { for my $site ( @{$glyco_residue{$k}} ) { } } }
  for my $k ( keys( %glyco_peptides ) ) {
    my $peptide = $glyco_peptides{$k};
    $peptide =~ s/_/$symbol/g;
    $glyco_peptides{$k} = $peptide;
  }
  return \%glyco_peptides;
}

# Returns reference to an array holding the 0-based indices of a pattern 'X'
# in the peptide sequence
sub get_peptide_coords {
  my $self = shift;
  my %args = @_;
  my $pep_str = join("','", @{$args{peptides}});

  my $sbeams = $self->getSBEAMS() || new SBEAMS::Connection;
  my $sql = qq~
			SELECT PEPTIDE_SEQUENCE, PM.START_IN_BIOSEQUENCE
			FROM $TBAT_PEPTIDE_MAPPING PM
			JOIN $TBAT_PEPTIDE_INSTANCE PI ON (PI.PEPTIDE_INSTANCE_ID = PM.PEPTIDE_INSTANCE_ID)
			JOIN $TBAT_PEPTIDE P ON (P.PEPTIDE_ID = PI.PEPTIDE_ID)
			JOIN $TBAT_BIOSEQUENCE B ON B.BIOSEQUENCE_ID = PM.MATCHED_BIOSEQUENCE_ID
			WHERE PEPTIDE_SEQUENCE IN ('$pep_str')
			AND PI.ATLAS_BUILD_ID = $args{atlas_build_id} 
			AND B.BIOSEQUENCE_NAME = '$args{accession}' 
   ~;
  my @rows = $sbeams->selectSeveralColumns($sql);
  my %peptide_coords=();
  foreach my $row (@rows){
    push @{$peptide_coords{$row->[0]}}, $row->[1];
  }
  return %peptide_coords;

}
# Returns reference to an array holding the 0-based indices of a pattern 'X'
# in the peptide sequence
sub get_site_positions {
  my $self = shift;
  my %args = @_;
  $args{pattern} = 'N[^P][S|T]' if !defined $args{pattern};
  my $idx = $args{index_base} || 0;
  return unless $args{seq};

  my $seq = $args{seq};
  my $pattern = $args{pattern};
  if ( $args{l_agnostic} ) {
    $seq =~ s/I/L/g;
    $pattern =~ s/I/L/g;
  }

  my @posn;
  while ( $seq =~ m/$pattern/g ) {
    my $posn = length($`);
    push @posn, ($posn + $idx);# pos($string); # - length($&) # start position of match
  }
#  $log->debug( "Found $posn[0] for NxS/T in $args{seq}\n" );
  return \@posn;
}

sub get_current_prophet_cutoff {
  my $self = shift;
  my $sbeams = $self->getSBEAMS() || new SBEAMS::Connection;
  my $cutoff = $sbeams->get_cgi_param( 'prophet_cutoff' );
  if ( !$cutoff ) {
    $cutoff = $sbeams->getSessionAttribute( key => 'prophet_cutoff' );
  }
  $cutoff ||= 0.8; 
  $self->set_prophet_cutoff( $cutoff );
  return $cutoff;
}


#+
# Routine returns ref to hash of seq positions where pattern seq matches 
# subject sequence
#
# @narg peptides   ref to array of sequences to use to map to subject sequence
# @narg atlas_build_id        
#
# @ret $coverage   ref to hash of seq_posn -> is_covered
#-

sub get_snp_coverage_hash {
  my $self = shift;
  my %args = @_;
  my $error = '';
  my $coverage = {};
  my $alt_aa = $args{alt};
  my $primary = $args{primary};
  # check for required args
  for my $arg( qw( peptide_coords peptides pos) ) {
    next if defined $args{$arg};
    my $err_arg = ( $error ) ? ", $arg" : $arg;
    $error ||= 'Missing required param(s): ';
    $error .= $err_arg
  }
  if ( $error ) {
    $log->error( $error );
    return;
  }
  unless ( ref $args{peptides} eq 'ARRAY' ) {
    $log->error( $error );
    return;
  }
  my $peptide_coords = $args{peptide_coords};
  for my $peptide ( @{$args{peptides}}  )  {
    my @posn;   
    my @aas = split(//, $peptide);
    if (defined $peptide_coords->{$peptide}){
      foreach my $start(@{$peptide_coords->{$peptide}}){
        if ($alt_aa ne '*'){
					if ($start <= $args{pos} && $start+length($peptide) > $args{pos}){
						my $idx = $args{pos} - $start;
            if (($aas[$idx] eq $alt_aa )||($alt_aa =~ /[IL]/ && $aas[$idx]=~ /[IL]/) ){ 
  					  push @posn, $start;
            }else{
               ## 0 base
               $primary->{$peptide} = $start - 1;
            }       
					}
        }else{
          if (($start + length($peptide) == $args{pos}) || 
               ($start == $args{pos} + 1) ){
             push @posn, $start;; 
					}else{
             if ($start <= $args{pos} && $start+length($peptide) > $args{pos}){
                $primary->{$peptide} = $start - 1;
             } 
          }
        }
        
      }
      for my $p ( @posn ) {
        for ( my $i = 0; $i < length($peptide); $i++ ){
          my $covered_posn = $p + $i -1;
          $coverage->{$covered_posn}++;
          $coverage->{pep}{$peptide} = 1
        }
      }
    } 
  }
  return $coverage;
}
#+
# Routine returns ref to hash of seq positions where pattern seq matches 
# subject sequence
#
# @narg peptides   ref to array of sequences to use to map to subject sequence
# @narg seq        Sequence against which pattern is mapped
#
# @ret $coverage   ref to hash of seq_posn -> is_covered
#-
sub get_coverage_hash {
  my $self = shift;
  my %args = @_;
  my $error = '';

  my $coverage = {};

  # check for required args
  for my $arg( qw( seq peptides ) ) {
    next if defined $args{$arg};
    my $err_arg = ( $error ) ? ", $arg" : $arg;
    $error ||= 'Missing required param(s): ';
    $error .= $err_arg
  }
  if ( $error ) {
    $log->error( $error );
    return;
  }
  unless ( ref $args{peptides} eq 'ARRAY' ) {
    $log->error( $error );
    return;
  }
  $args{offset} ||= 0;

  my $seq = $args{seq};
  $seq =~ s/[^a-zA-Z]//g unless $args{nostrip};
  for my $peptide ( @{$args{peptides}}  )  {

    my $posn = $self->get_site_positions( pattern => $peptide,
            seq => $seq,
            );
#    die Dumper $posn if $peptide eq 'CQSFLDHMK';
    for my $p ( @$posn ) {
      $coverage->{pep}{$peptide} =1;
      for ( my $i = 0; $i < length($peptide); $i++ ){
        my $covered_posn = $p + $i + $args{offset};
        $coverage->{$covered_posn}++;
      }
    }
  }

  return $coverage;
}
sub get_coverage_hash_db {
  my $self = shift;
  my %args = @_;
  my $error = '';
  my $coverage = {};
  # check for required args
  for my $arg( qw( peptide_coords peptides primary_protein_sequence) ) {
    next if defined $args{$arg};
    my $err_arg = ( $error ) ? ", $arg" : $arg;
    $error ||= 'Missing required param(s): ';
    $error .= $err_arg
  }
  if ( $error ) {
    $log->error( $error );
    return;
  }
  unless ( ref $args{peptides} eq 'ARRAY' ) {
    $log->error( $error );
    return;
  }
  my $peptide_coords = $args{peptide_coords};
  my $primary_protein_sequence = $args{primary_protein_sequence};
  $primary_protein_sequence =~ s/I/L/g;

  my %tmp = ();
  for my $peptide ( @{$args{peptides}}  )  {
    my @posn;
    my $match = 1;
    my $il_neu_peptide = $peptide;
    $il_neu_peptide =~ s/I/L/g;
    $match = 0 if ($primary_protein_sequence !~ /$il_neu_peptide/);
    if (defined $peptide_coords->{$peptide}){
      foreach my $start(@{$peptide_coords->{$peptide}}){
				for ( my $i = 0; $i < length($peptide); $i++ ){
					my $covered_posn = $start + $i -1;
          if ($match){
					  $coverage->{$covered_posn}{primary}++;
            $tmp{$covered_posn} =1;
          }
          $coverage->{$covered_posn}{all}++;
				}
			}
    } 
  }
  #print join(",", sort {$a <=> $b} keys %tmp). '<BR>';
  return $coverage;
}


#+
# coverage          ref to coverage hash for primary annotation
# cov_class         CSS class for primary annotation
# sec_cover         ref to coverage hash for secondary annotation.  Must be a 
#                   subset of the primary!
# sec_class         CSS class for primary annotation
# seq               Sequence to be processed, a la --A--AB-
#-
sub highlight_sequence {
  my $self = shift;
  my %args = @_;

  my $error = '';
  # check for required args
  for my $arg( qw( seq coverage ) ) {
    next if defined $args{$arg};
    my $err_arg = ( $error ) ? ", $arg" : $arg;
    $error ||= 'Missing required param(s): ';
    $error .= $err_arg
  }
  if ( $error ) {
    $log->error( $error );
    return $args{seq};
  }

  # Default value
  my $class = $args{cov_class} || 'pa_observed_sequence';
  $args{sec_cover} ||= {};

  if ( $args{sec_cover} ) {
    $args{sec_class} ||= $args{cov_class};
  }

  my $coverage = $args{coverage};

  my @aa = split( '', $args{seq} );
  my $return_seq = '';
  my $cnt = 0;
  my $in_coverage = 0;
  my $span_closed = 1;

  my %class_value = ( curr => 'pri',
		      prev => 'sec' );


  for my $aa ( @aa ) {

    $class_value{prev} = $class_value{curr};

    # use secondary color if applicable
    if ( $args{sec_cover}->{$cnt} ) {
      $class_value{curr} = 'sec';
      $class = $args{sec_class} 
    } else {
      $class_value{curr} = 'pri';
      $class = $args{cov_class} 
    }
    my $class_close = ( $class_value{curr} eq  $class_value{prev} ) ? 0 : 1;

    if ( $aa eq '-' ) {
      if ( $in_coverage && !$span_closed ) {
        $return_seq .= "</span>$aa";
        $span_closed++;
      } else {
        $return_seq .= $aa;
      }
    } else { # it is an amino acid
      if ( $coverage->{$cnt} ) {
        if ( $in_coverage ) { # already in
          if ( $span_closed ) {  # Must have been jumping a --- gap
            $span_closed = 0;
            $return_seq .= "<span class=$class>$aa";
          } else {
            $return_seq .= $aa;
          }
        } else {
          $in_coverage++;
          $span_closed = 0;
          $return_seq .= "<span class=$class>$aa";
        }
      } else { # posn not covered!
        if ( $in_coverage ) { # were in, close now
          $return_seq .= "</span>$aa";
          $in_coverage = 0;
          $span_closed++;
        } else {
          $return_seq .= $aa;
        }
      }
      $cnt++;
    }
  }

  # Finish up
  if ( $in_coverage && !$span_closed ) {
    $return_seq .= '</span>';
  }
  return $return_seq;
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
  for my $aa ( @seq ) { $cnt{$aa}++ };
  
  # Fight warnings
  for my $aa ( qw(C D E H K R Y) ) {
    $cnt{$aa} ||= 0;
  }

  my $side_total = 0;

  for my $aa ( keys(%pka) ) {
    # Only consider amino acids that can carry a charge
    next unless $pka{$aa}->[2];

    # Count the occurences of each salient amino acid (C, D, E, H, K, R, Y)
    $side_total += $cnt{$aa} if $cnt{$aa};
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

  # pH midpoint is the average of max and min
  $ph_mid = ($ph_max + $ph_min)/2; 

  # Let lack of return precision reflect the fact that this is an estimate 
  return sprintf( "%0.1f", $ph_mid );
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

sub make_tags {
  my $self = shift;
  my $input = shift || return;
  my $tags = shift || {};

  for ( my $i = 0; $i <= $input->{number}; $i++ ){
    if ($input->{snp_start} && $input->{snp_start}->[$i]){
			$tags->{$input->{snp_start}->[$i]} .= "<SPAN onmouseout=\"hideTooltip()\" onmouseover=\"".
                                        "showTooltip(event,'only observed by VARIANT peptides')\" class=$input->{snp_class}>";
			$tags->{$input->{snp_end}->[$i]} .= "</SPAN>";
    }else{
      if($input->{start}->[$i] ne ''){
			  $tags->{$input->{start}->[$i]} .= "<SPAN class=$input->{class}>";
			  $tags->{$input->{end}->[$i]} .= "</SPAN>";
      }
    }
  }
  return $tags;
}


sub get_html_seq {
  my $self = shift;
  my $seq = shift;
  my $tags = shift;

  my @values = ( ['<PRE><SPAN CLASS=pa_sequence_font>'] );
  my $cnt = 0;
  for my $aa ( split( "", $seq ) ) {
    my @posn;
    if ( $tags->{$cnt} && $tags->{$cnt} ne '</SPAN>' ) {
      push @posn, $tags->{$cnt};
    }
    push @posn, $aa;
    if ( $tags->{$cnt} && $tags->{$cnt} eq '</SPAN>' ) {
      push @posn, $tags->{$cnt};
    }

    $cnt++;

    unless ( $cnt % 10 ) {
      push @posn, '<SPAN CLASS=white_bg>&nbsp;</SPAN>';
    }
    push @posn, "\n" unless ( $cnt % 100 );
    push @values, \@posn;
  }
  push @values, ['</SPAN></PRE>'];
  my $str = '';
  for my $a ( @values ) {
    $str .= join( "", @{$a} );
  }
  return $str;
}

sub assess_protein_peptides {
  my $self = shift;
  my %args = ( use_len => 1,
               min_len => 7,
               max_len => 40,
               use_ssr => 1,
               min_ssr => 10,
               max_ssr => 60,
               use_sig => 1,
               use_tm => 1,
               @_ );
  my $sbeams = $self->getSBEAMS();

  # If no sequence given, will extract
  if ( !$args{seq} ) {
    my $error = 0;
    for my $arg ( qw( build_id accession ) ) {
      if ( ! $args{$arg} ) {
        $log->warn( "missing required argument $arg\n" );
        $error++;
      }
    }
    return '' if $error;

    my $protein_sql = qq~
    SELECT biosequence_seq 
    FROM $TBAT_BIOSEQUENCE B
    JOIN $TBAT_ATLAS_BUILD AB
      ON AB.biosequence_set_id = B.biosequence_set_id
    WHERE AB.atlas_build_id = $args{build_id}
    AND ( biosequence_accession = '$args{accession}'
       OR biosequence_name = '$args{accession}' )
    ~;

    my $sth = $sbeams->get_statement_handle( $protein_sql );

    while ( my @row = $sth->fetchrow_array() ) {
      my @seqs = split( /\*/, $row[0] );
      #$args{seq} = $seqs[0];
      $args{seq} = $row[0];
      last;
    }
  }
  unless ( $args{seq} ) {
    $log->warn( "No sequence found" );
    return '';
  }
  my %fail = ( len => 0, ssr => 0 );
  my $peps = $self->do_tryptic_digestion( aa_seq => $args{seq} ); 
#  die Dumper( $peps );
  my $swiss = $args{swiss} || {};

  my %tm;
  if ( $swiss->{TRANSMEM} ) {
    for my $tm ( @{$swiss->{TRANSMEM}} ) {
      next unless ( $tm->{start} && $tm->{end} );
      die "ugh" unless ( $tm->{start} < $tm->{end} );
      for ( my $site = $tm->{start}; $site <= $tm->{end}; $site++ ) {
        $tm{$site}++;
      }
    }
  }

  my %sig;
  if ( $swiss->{SIGNAL} ) {
    for my $sig ( @{$swiss->{SIGNAL}} ) {
      next unless ( $sig->{start} && $sig->{end} );
      die "ugh" unless ( $sig->{start} < $sig->{end} );
      for ( my $site = $sig->{start}; $site <= $sig->{end}; $site++ ) {
        $sig{$site}++ if $args{use_sig};
      }
    }
  }


  my %len_ok;
  my %len; # failing len peptides
  for my $pep ( @{$peps} ) {
    my $plen = length( $pep );
    if ( $plen >= $args{min_len} && $plen <= $args{max_len} ) {
      $len_ok{$pep}++;
    } else {
      if( $args{use_len} ) {
        $len{$pep}++;
        $fail{len}++;
      }
    }
  }

  my $calc = $self->getSSRCalculator();
  my %ssr_ok;
  my %ssr;
  my %ssr_seen;
  my %all_ssr;
  if ( $args{use_ssr} ) {
    for my $pep ( @{$peps} ) {
#      next if ( $args{use_len} && !$len_ok{$pep} );
      next if $ssr_seen{$pep}++;
      if ($calc->checkSequence($pep) ){
        my $ssr ||= $calc->TSUM3($pep);
        $all_ssr{$pep} = $ssr;
        if ( $ssr >= $args{min_ssr} && $ssr <= $args{max_ssr} ) {
          $ssr_ok{$pep}++;
        } else {
          $fail{ssr}++;
          $ssr{$pep}++;
        }
      }
    }
  }

  my %tm_peps;
  my %sig_peps;
  my %fail_status;
  my @pepinfo;
  my %passing;
  my %failing;
  my $total = 0;
  my $passing = 0;
  my $likely_str = '';
  for my $pep ( @{$peps} ) {
    my $status = 'OK';
    my $start = $total + 1;
    $total += length( $pep );
    my $end = $total;
    my $tallied = 0; # Just once
    if ( $args{use_len} && !$len_ok{$pep} ) {
      $likely_str .= 0 x length( $pep ) unless $tallied++;
      $status ||= 'Length';
      $fail_status{Length}++;
    } 

    if ( $args{use_sig} && ($sig{$start} || $sig{$end}) ) {
      $likely_str .= 0 x length( $pep ) unless $tallied++;
      $status ||= 'SIG';
      $fail_status{SIG}++;
      $sig_peps{$pep}++;
    } else {
      for my $pos ( sort { $a <=> $b } ( keys( %sig ) ) ) {
        if ( $pos >= $start && $pos <= $end ) {
          $likely_str .= 0 x length( $pep ) unless $tallied++;
          $status ||= 'SIG';
          $fail_status{SIG}++;
          $sig_peps{$pep}++;
          last;
        }
      }
    }
    if ( $args{use_tm} && ($tm{$start} || $tm{$end}) ) {
      $likely_str .= 0 x length( $pep ) unless $tallied++;
      $status ||= 'TM';
      $fail_status{TM}++;
      $tm_peps{$pep}++;
    } else {
      for my $pos ( sort { $a <=> $b } ( keys( %tm ) ) ) {
        if ( $args{use_tm} && $pos >= $start && $pos <= $end ) {
          $likely_str .= 0 x length( $pep ) unless $tallied++;
          $status ||= 'SIG';
          $fail_status{SIG}++;
          $tm_peps{$pep}++;
          last;
        }
      }
    } 
    if ( $args{use_ssr} && !$ssr_ok{$pep} ) {
      $likely_str .= 0 x length( $pep ) unless $tallied++;
      $status ||= 'SSR';
    } 
    if ( !$tallied ){
      $passing += length( $pep );
      $likely_str .= 1 x length( $pep );
      $passing{$pep}++;
    } else {
      $failing{$pep}++;
    }
    push @pepinfo, { seq => $pep, 
		     start => $start, 
                     end => $end, 
		     status => $status,
		     len => length( $pep ),
		     ssr => $all_ssr{$pep} || 0
    };
  }
  
  my @passing = keys( %passing );
  my @failing = keys( %failing );
  return ( { peptides => \@pepinfo,
             pass_len => $passing,
	     failure =>  \%fail,
	     total_len => $total,
	     passing => \%passing,
	     failing => \%failing,
	     num_passing => scalar( @passing ),
	     likely_str => $likely_str,
	     ssr => \%ssr,
	     len => \%len,
	     tm => \%tm_peps,
	     sig => \%sig_peps, 
	     percent_likely => sprintf( "%0.1f", 100*($passing/$total)) } );
}


sub get_html_seq_vars {
  my $self = shift;
  my %args = @_;
  my $is_trypsin_build = $args{is_trypsin_build} || 'Y';
  my %return = ( seq_display => '',
                 clustal_display => '',
                 variant_list => [ [qw( Type Num Start End Info )] ] );
  my $organism = $args{organism} || ''; 
  my $seq = $args{seq} || return '';

  my $ruler = '';
  my $ruler_cnt = ' ';
  my $acnt = 1;
  for my $aa ( split //, $seq ) {
    if ( $acnt % 10 ) {
      $ruler .= '-';
    } else {
      $ruler_cnt .= sprintf( "% 10d", $acnt );;
      $ruler .= '|';
    }

    $acnt++;
  }
  $ruler_cnt =~ s/ /\&nbsp;/g;

  my $tags = $args{tags};
  my $peps = $args{peptides} || [];

  my %peps;
  for my $pep ( @{$peps} ) {
    $peps{$pep}++;
  }
  my $whitespace = '<SPAN CLASS="white_bg">&nbsp;</SPAN>';
  my $cnt = 0;
  my $line_len = 0;
  my $prev_aa = '-';

  my %values = ( tryp =>    [ ['<PRE><SPAN CLASS="pa_sequence_font">'] ],
								 inter =>   [ ['<PRE><SPAN CLASS="pa_sequence_font">'] ],
								 alt_enz => [ ['<PRE><SPAN CLASS="pa_sequence_font">'] ],
                 nosp =>    [ ['<PRE><SPAN CLASS="pa_sequence_font">'] ] );

  for my $aa ( split( "", $seq ) ) {
    my @posn;
    if ( $tags->{$cnt} && $tags->{$cnt} ne '</SPAN>' ) {
      push @posn, $tags->{$cnt};
    }
    push @posn, $aa;
    if ( $tags->{$cnt} && $tags->{$cnt} eq '</SPAN>' ) {
      push @posn, $tags->{$cnt};
    }

    $cnt++;

    my @iposn = @posn;
    my @tposn = @posn;
    my @nsposn = @posn;

    unless ( $cnt % 10 ) {
      push @iposn, $whitespace;
    }
    push @nsposn, "<span class='pa_sequence_counter'>$cnt</span>\n" unless ( $cnt % 100 );
    push @iposn,  "<span class='pa_sequence_counter'>$cnt</span>\n" unless ( $cnt % 100 );

    if ( $aa =~ /\*/ || $prev_aa =~ /\*/ ) {
      my $idx = scalar( @{$values{tryp}} );
      push @{$values{tryp}->[$idx]}, $whitespace;
    } elsif ( $prev_aa =~ /[KR]/ && $aa ne 'P' ) {
      my $idx = scalar( @{$values{tryp}} );
      push @{$values{tryp}->[$idx]}, $whitespace;
      if ( $line_len > 100 ) {
        push @{$values{tryp}->[$idx]}, "\n";
        $line_len = 0;
      }
    }

    push @{$values{tryp}}, \@tposn;
    push @{$values{nosp}}, \@nsposn;
    push @{$values{alt_enz}}, \@posn;
    push @{$values{inter}}, \@iposn;
    $prev_aa = $aa;
    $line_len++;
  }

  push @{$args{alt_enz}}, 'lysarginase';

  my $alt_enzyme_info = {};
  if( $is_trypsin_build eq 'N'){
    $alt_enzyme_info = $self->get_alt_enzyme( %args );
  }

  push @{$values{tryp}},   ['</SPAN></PRE>'];
  push @{$values{nosp}},   ['</SPAN></PRE>'];
  push @{$values{alt_enz}},['</SPAN></PRE>'];
  push @{$values{inter}},  ['</SPAN></PRE>'];
  my $str = qq~
    <SCRIPT TYPE="text/javascript">
    function setSeqView() {
      var seqView = document.getElementById( "seqView" );
      var seqViewVal = seqView.value;

      // Store selection in cookie so it is 'sticky'
      var name = 'sequence_view';
//      var date = new Date();
//      date.setTime(date.getTime()+(5*1000));
//      var expires = "; expires="+date.toGMTString();
//      var cookie = name+"="+seqViewVal+expires+"; path=/";
      var cookie = name + "=" + seqViewVal;
      document.cookie = cookie;

      var newContent = document.getElementById( seqViewVal ).innerHTML;
      document.getElementById( "seq_display" ).innerHTML = newContent;
    }
    </SCRIPT>
  ~;
  my %divs = ( tryp => '<DIV ID=tryp style="display:none">',
               nosp => '<DIV ID=nosp style="display:none">',
               inter => '<DIV ID=inter style="display:none">'  );

  my @alt_enz = ();
  for my $enz ( sort( keys( %{$alt_enzyme_info} ) ) ) {
    next if $enz =~ /^trypsin/;
    $divs{$enz} = "<DIV ID=$enz style='display:none'>",
    push @alt_enz, $enz; 
    $values{$enz} = dclone( $values{alt_enz} );

    my $row_posn = 0;
    my $prev = 0;
    for my $posn ( @{$alt_enzyme_info->{$enz}} ) {
      push @{$values{$enz}->[$posn]}, $whitespace; 
      $row_posn += $posn - $prev;
#      $log->warn( "enz is $enz, posn is $posn, prev is $prev, and rowposn $row_posn" );
      if ( $row_posn >= 100 ) {
#        $log->warn( "Adding newline" );
        push @{$values{$enz}->[$posn]}, "\n"; 
        $row_posn = 0;
      }
      $prev = $posn;
    }
  }

  my %div_txt;
  for my $seq_type ( qw( nosp inter tryp ), @alt_enz ) {
    next if $seq_type =~ /^trypsin/;
    $div_txt{$seq_type} = $divs{$seq_type};
    for my $a ( @{$values{$seq_type}} ) {
      next unless ref($a);
      next unless ref($a) eq 'ARRAY';
      $div_txt{$seq_type} .= join( "", @{$a} );
    }
    $div_txt{$seq_type} .= '</DIV>';
  }

  my $display_div;
  my $selected = '';
  my $iselect = '';
  my $tselect = '';
  if( $args{digest_type} && $div_txt{$args{digest_type}} ){
    $display_div = $div_txt{$args{digest_type}};
    $display_div =~ s/display:none/display:block;margin-left:15px;/g;
    if (length($seq) > 2700){
      $display_div =~ s/ID=$args{digest_type}/ID=seq_display CLASS='clustal_peptide'/;
    }else{
      $display_div =~ s/ID=$args{digest_type}/ID=seq_display/;
    }

    if ( $args{digest_type} eq 'tryp' ) {
      $tselect = "selected";
    } elsif ( $args{digest_type} eq 'inter' ) {
      $iselect = "selected";
    }
  } elsif($is_trypsin_build eq 'Y'){
    $display_div = $div_txt{tryp};
    $display_div =~ s/display:none/display:block/g;
    $display_div =~ s/ID=tryp/ID=seq_display/;
    $tselect = "selected";
  } else {
    $display_div = $div_txt{inter};
    $display_div =~ s/display:none/display:block/g;
    $display_div =~ s/ID=inter/ID=seq_display/;
    $iselect = "selected";
  }

  $str .= qq~
    <FORM>
    <B>Sequence Display Mode:</B> 
    <SELECT onChange=setSeqView() NAME=seqView ID="seqView">
      <OPTION VALUE=inter $iselect> Interval
      <OPTION VALUE=nosp>  No Space
      <OPTION VALUE=tryp $tselect>  Trypsin
  ~;

  my %lc2name = ( aspn => 'AspN', 
                  gluc => 'GluC',
                  lysc => 'LysC',
		           trypsin => 'Trypsin',
          chymotrypsin => 'Chymotrypsin',
           lysarginase => 'LysArgiNase' );

  for my $enz ( @alt_enz ) {
    next if $enz =~ /^trypsin/;
    my $sel = ( $args{digest_type} && $args{digest_type} eq $enz ) ? 'selected' : '';
    $str .= "    <OPTION VALUE=$enz $sel> $lc2name{$enz} \n";
  }

  $str .= qq~
    </SELECT>
    </FORM>
   ~;


  $str .= $display_div;
  $str .= $div_txt{tryp};
  $str .= $div_txt{inter};
  $str .= $div_txt{nosp};
  for my $enz ( @alt_enz ) {
    next if $enz =~ /^trypsin/;
    $str .= $div_txt{$enz};
  }
  $return{seq_display} = $str;
  if ( $args{swiss} ){
    $self->{_swiss} = $args{swiss};
  } else {
    $self->{_swiss} = $self->get_uniprot_annotation( %args );
  }
  my $swiss = $self->{_swiss};

  # Or if there are no variants.
  #return \%return unless $swiss->{success};

  my $is_html = ( $self->getSBEAMS()->output_mode() eq 'html' ) ? 1 : 0;
  if ( $swiss->{fasta_seq} ne $args{seq} ) {
    $log->error( "Drift detected between biosequence and uniprot_db tables" );
    $log->error( "$args{accession}, $args{build_id}" );
  }
  $return{has_variants} = $swiss->{has_variants};
  $return{has_modres} = $swiss->{has_modres};

  my $snp_cover = $self->get_snp_coverage( swiss => $swiss );
  my $conflict_cover = $self->get_conflict_coverage( swiss => $swiss );
  for my $cnf ( keys( %{$conflict_cover} ) ) {
    $snp_cover->{$cnf} ||= $conflict_cover->{$cnf};
  }

  my %coverage_coords;
  my @global_clustal = ( [ '', $ruler_cnt], [ '', $ruler ] );
  my $primary_clustal = [ 'Primary', $seq ];
  my %peptide_coordinate_db = $self->get_peptide_coords(atlas_build_id => $args{build_id},
                               peptides => $peps,
                               accession => $args{accession});
  $coverage_coords{$primary_clustal->[0]} = $self->get_coverage_hash_db(peptide_coords => \%peptide_coordinate_db,
                                                                        peptides => $peps,
                                                                        primary_protein_sequence => $args{seq});

  push @global_clustal, $primary_clustal;

  my %type2display = ( VARIANT => 'VARIANT',
											 CHAIN => 'Chain',
											 INIT_MET => 'InitMet',
											 SIGNAL => 'Signal',
											 PROPEP => 'Propep',
                       PEPTIDE => 'Chain',
      );
  # Removed CONFLICT peptides.
  my @obs;
  my @unobs;
  my %obs_snps;
  ## primary sequence for snp site. If the snp contain peptide don't have snp on 
  ## the site, it will be consider the sequence from primary sequence
  my %primary;

  for my $type ( qw( INIT_MET SIGNAL PROPEP PEPTIDE CHAIN VARIANT ) ) {
    my $snpcnt = 1;
    print "DDDD$type" if ($type eq 'VARIANT' && $args{caching});

    for my $entry ( @{$swiss->{$type}} ) {
      my $alt = $entry->{seq};
      my $snpname = $type2display{$type} .  '_' . $snpcnt;
      push @global_clustal, [ $snpname, $entry->{seq}];
      ## if sequence in dat file same as the one in the db. use coor in db
      if ( $type eq 'VARIANT' && $seq eq  $swiss->{fasta_seq}){
        $entry->{info} =~ /\w\s+\-\>\s+(\S)/; 
        my $alt_aa = $1;
        if ($alt_aa){
          $coverage_coords{$snpname} = $self->get_snp_coverage_hash(peptide_coords => \%peptide_coordinate_db,
								   peptides => $peps,
								   pos => $entry->{start},
								   alt => $alt_aa,
                   primary=>\%{$primary{$snpcnt}});
          print "$snpcnt..." if ($snpcnt % 1000 == 0 && $args{caching});
        }
      }
      my $var_string = '';
      $snpcnt++;
      my ( $vtype, $vnum ) = split( /_/, $snpname );
      if ( $type eq 'VARIANT' ) {
        my %sorted;
				my $skey = $entry->{start} - 1;
				if ( $coverage_coords{Primary}->{$skey} ) {
					$obs_snps{$vnum} = $entry;
					#push @obs, [ $vtype, $vnum, $entry->{start}, $entry->{end}, $entry->{info}, 'seen' ];
        }else{
					push @unobs, [ $vtype, $vnum, $entry->{start}, $entry->{end}, $entry->{info}, 'notseen' ];
        }
      } else {
        push @{$return{variant_list}}, [ $vtype, $vnum, $entry->{start}, $entry->{end}, $entry->{info} ];
      }
    }
    print "\n" if ($args{caching});
  } 

  my %clustal_middle_vnum =();

  # Here we are getting coverage depth for just observed SNPS
  my %site_specific_nobs;
  my $t0 = time;
  
  if ( scalar keys %obs_snps || @unobs){ 
    my $pnobs = $args{peptide_nobs};
    my %snp_only;
    # First see which peptides have snp
    for my $pep ( keys( %{$pnobs} ) ) {
      my $posn = $self->get_site_positions( seq => $args{seq},
					    pattern => $pep,
              index_base => 1, 
					    l_agnostic => 1 );
      if ( scalar( @{$posn} ) ) {
        #$primary{$pep} = $posn->[0];
      } else {
        $snp_only{$pep}++;
      }
    }  

    my %unique_evidence;
    my %snp_evidence_used;
    if ( scalar( keys( %snp_only ) ) ) {
      my %inst2seq = reverse( %{$args{seq2instance}} );
      my $pi_str = '';
      my $sep = '';
      for my $pep ( keys( %snp_only ) ) {
        $pi_str .= $sep . $args{seq2instance}->{$pep};
        $sep = ',';
      }

      my $nmap_sql = qq~
        SELECT PEPTIDE_INSTANCE_ID, COUNT(DISTINCT MATCHED_BIOSEQUENCE_ID)
        FROM $TBAT_PEPTIDE_MAPPING PM
        JOIN $TBAT_BIOSEQUENCE B
          ON B.biosequence_id = PM.matched_biosequence_id
        WHERE peptide_instance_id IN ( $pi_str )
        GROUP BY peptide_instance_id
      ~;

      if ($organism =~ /Arabidopsis/i){
        $nmap_sql = qq~
					SELECT PEPTIDE_INSTANCE_ID, COUNT(DISTINCT MATCHED_BIOSEQUENCE_ID)
					FROM $TBAT_PEPTIDE_MAPPING PM
					JOIN $TBAT_BIOSEQUENCE B
						ON B.biosequence_id = PM.matched_biosequence_id
					WHERE peptide_instance_id IN ( $pi_str )
					AND B.biosequence_name like 'AT%'
					GROUP BY peptide_instance_id
				~;
      }
      my $sbeams = $self->getSBEAMS();
      my $sth = $sbeams->get_statement_handle( $nmap_sql );
      while ( my @row = $sth->fetchrow_array() ) {
        next if $row[1] > 1;
        my $seq = $inst2seq{$row[0]};
				$unique_evidence{$seq} = $row[1];
      }
    }

    my $seq_len = length(  $args{seq} );
    # Next loop over seen snps, and count primary and SNPPY counts
    my @obs;
    my @obs_ref_only; 
    for my $vnum ( sort {$a <=> $b} keys  %obs_snps  ) {
      my $entry = $obs_snps{$vnum};
      my $snp = "VARIANT_$vnum";
      my $site = $entry->{start};
      my $snpped_seq = $args{seq};
      $entry->{info} =~ /(\w)\s+\-\>\s+(\S)/;
      my $pre = $1;
      my $post = $2;
      eval { substr( $snpped_seq, $site - 1, 1, $post ) };
      if ( $@ ) {
        $log->error( "Error in VARIANT substring" );
        $log->error( $@ );
        $log->error( Dumper( $obs_snps{$snp} ) );
        $log->error( Dumper( %args ) );
        if ( $site > length( $snpped_seq ) ) {
          $log->error( "VARIANT position has exceeded length of sequence!" );
          last;
        }
        next;
      }
      my $pre_aa = substr( $args{seq}, $site - 1, 1 );
      my $post_aa = substr( $snpped_seq, $site - 1, 1 );

      $site_specific_nobs{$snp} ||= {};
      $site_specific_nobs{$snp}->{pre_aa} ||= $pre_aa;
      $site_specific_nobs{$snp}->{post_aa} ||= $post_aa;
      $site_specific_nobs{$snp}->{site} = $site;
#      $log->info( "$pre and $post from $obs_snps{$snp}->{info}; Seq munging yeilds $pre_aa and $post_aa " );

      for my $ppep ( keys( %{$primary{$vnum}} ) ) {
        if ( $primary{$vnum}{$ppep} <= $site && $site <= $primary{$vnum}{$ppep} + length($ppep)) {
          $site_specific_nobs{$snp}->{$pre_aa} += $args{peptide_nobs}->{$ppep};
          $site_specific_nobs{total}->{$snp} += $args{peptide_nobs}->{$ppep};
          $site_specific_nobs{$snp}->{opeptides} ||= {};
          $site_specific_nobs{$snp}->{opeptides}->{$ppep}++;
        }
      }

      for my $spep ( keys( %snp_only ) ) {
        if (defined $coverage_coords{$snp}->{pep}{$spep}){
          #print "$spep seems to map to to snpped sequence for $site<br>\n";
          $snp_evidence_used{$spep}++;
          $site_specific_nobs{$snp}->{$post_aa} += $args{peptide_nobs}->{$spep};
          $site_specific_nobs{unique} ||= {};
          $site_specific_nobs{unique}->{$snp} ||= 0;
          $site_specific_nobs{unique}->{$snp} += $args{peptide_nobs}->{$spep} if $unique_evidence{$spep};
          $site_specific_nobs{$snp}->{peptides} ||= {};
          $site_specific_nobs{$snp}->{peptides}->{$spep}++;
          $site_specific_nobs{total}->{$snp} += $args{peptide_nobs}->{$spep};
        }
      }
			if ( $site_specific_nobs{total}->{$snp} && $site_specific_nobs{$snp}->{$post_aa} / $site_specific_nobs{total}->{$snp} > 0 ){
				 push @obs, ['VARIANT', $vnum, $entry->{start}, $entry->{end}, $entry->{info}, 'seen' ];
         $clustal_middle_vnum{top}{$snp} =1;
			}else{
        if ($organism =~ /Arabidopsis/i){
				   push @obs_ref_only, ['VARIANT', $vnum, $entry->{start}, $entry->{end}, $entry->{info}, 'seen' ];
           $clustal_middle_vnum{top}{$snp} =1; 
        }else{
           ##build not searched for snps
          push @obs_ref_only, ['VARIANT', $vnum, $entry->{start}, $entry->{end}, $entry->{info}, 'notseen' ];
          $clustal_middle_vnum{bottom}{$snp} =1; 
        }
			}
    }
    
    push @{$return{variant_list}}, @obs, @obs_ref_only, @unobs;
  } # End get SNP abundance loop (whew)
  # 2014-11 - Want to sort observed variants above those not observed. 
  # pre-SNP go to top, seen SNP go to middle, and unseen go to bottom.
  my @clustal_top;
  my @clustal_bottom;
  my @clustal_middle_top=();
  my @clustal_middle_bottom=();
   for my $track ( @global_clustal ) {
    if ( $track->[0] && $track->[0] =~ /VARIANT_(\d+)/ ) {
      if ( $obs_snps{$1} ) {
         if ($clustal_middle_vnum{top}{$track->[0]}){
           push @clustal_middle_top, $track;
         }elsif ($clustal_middle_vnum{bottom}{$track->[0]}){
           push @clustal_middle_bottom, $track;
         }
      } else {
        push @clustal_bottom, $track;
      }
    } else {
      push @clustal_top, $track;
    }
  } 

  @global_clustal = ( @clustal_top, @clustal_middle_top, @clustal_middle_bottom, @clustal_bottom ); 

  my $t1 = time;
  my $td = $t1 - $t0;
  $return{site_nobs} = \%site_specific_nobs;
  # Add modified residues track
  my $cover = $self->get_modres_coverage( $swiss );
  if ( $swiss->{has_modres} ) {
    my $modres_seq = $self->add_modres_cover_css( seq => $seq, cover => $cover );
    push @global_clustal, [ 'ModifiedResidues', $modres_seq ];
  }

  my $trypsites = $primary_clustal->[1];
  $trypsites =~ s/[KR]P/--/g;
  $trypsites =~ s/[^KR]/-/g;
  push @global_clustal, [ 'TrypticSites', $trypsites ] if ($is_trypsin_build eq 'Y');

  my $clustal_display .= $self->get_clustal_display( alignments => \@global_clustal, 
						     dup_seqs => {},
						     pepseq => 'ZORRO',
						     snp_cover => $snp_cover,
						     coverage => \%coverage_coords,
						     acc2bioseq_id => {},
						     %args );

  $return{clustal_display} = $clustal_display;

  return \%return;
}

sub get_alt_enzyme {
  my $self = shift;
  my %args = @_;
  my %return;
  return \%return unless $args{alt_enz};
  return \%return unless $args{seq};
  for my $enz( sort( @{$args{alt_enz}} ) ) {
    my $posn = $self->do_simple_digestion( aa_seq => $args{seq},
                                           enzyme => $enz,
					   positions => 1 );
    $return{$enz} = $posn;
  }
  return \%return;
}

sub get_modres_coverage {
  my $self = shift;
  my $swiss = shift;

  my %cover;
  for my $item ( @{$swiss->{CARBOHYD}} ) {
    $cover{$item->{start}} = qq~<span class=pa_glycosite TITLE="$item->{info}">MODIFIED_AA_PLACEHOLDER</span>~;
  }
  for my $item ( @{$swiss->{MOD_RES}} ) {
    my $class = ( $item->{info} =~ /phospho/i ) ? 'pa_phospho_font' :
                ( $item->{info} =~ /acetyl/i ) ? 'pa_acetylated_font' : 'pa_modified_aa_font' ;

    $cover{$item->{start}} = qq~<span class=$class TITLE="$item->{info}">MODIFIED_AA_PLACEHOLDER</span>~;
  }
  return \%cover;
}

sub get_snp_coverage {
  my $self = shift;
  my %args = @_;
  my $cnt = 1;
  my %snp_cover;
  for my $item ( @{$args{swiss}->{VARIANT}} ) {
    my $key = 'VARIANT_' . $cnt++; 
    $snp_cover{$key} = $item->{annot};
  }
  return \%snp_cover;
}

sub get_conflict_coverage {
  my $self = shift;
  my %args = @_;
  my $cnt = 1;
  my %snp_cover;
  for my $item ( @{$args{swiss}->{CONFLICT}} ) {
    my $key = 'SeqConflict_' . $cnt++; 
    $snp_cover{$key} = $item->{annot};
  }
  return \%snp_cover;
}

sub add_modres_cover_css {
  my $self = shift;
  my %args = @_;
  my $cnt = 0;
  my @seq = split( '', $args{seq} );
  my @ret_seq;
  my $in_tag = 0;
  for my $aa ( @seq ) {
    if ( $aa =~ /\</ ) {
      $in_tag++;
    } elsif ( $aa =~ /\>/ ) {
      $in_tag--;
    } elsif ( $in_tag ) {
      # no-op
    } else {
      $cnt++;
      if ( $args{cover}->{$cnt} ) {
        my $new_aa = $args{cover}->{$cnt};
        $new_aa =~ s/MODIFIED_AA_PLACEHOLDER/$aa/;
        $aa = $new_aa;
      }
    }
    push @ret_seq, $aa;
  }
  return join( '', @ret_seq );
}


sub add_snp_cover_css {
  my $self = shift;
  my %args = @_;
  my $cnt = 0;
  my @seq = split( '', $args{seq} );
  my @ret_seq;
  my $in_tag = 0;
  for my $aa ( @seq ) {
    if ( $aa =~ /\</ ) {
      $in_tag++;
    } elsif ( $aa =~ /\>/ ) {
      $in_tag--;
    } elsif ( $in_tag ) {
      # no-op
    } else {
      $cnt++;
      if ( $args{cover}->{$cnt} ) {
        $aa = $args{cover}->{$cnt};
      }
    }
    push @ret_seq, $aa;
  }
  return join( '', @ret_seq );
}


sub get_uniprot_variant_seq {
  my $self = shift;
  my %args = @_;

  my $seq = { seq => '', annot => {} };
  my $dash_seq = $args{fasta_seq};
  $dash_seq =~ s/\w/\-/g;

  my $seqlen = length( $args{fasta_seq} );
  my $context_len = 40;
  my $context_start = 40;

  if ( $args{type} eq 'INIT_MET' ) { # Sequence is 2..end
    my @aa = split( //, $args{fasta_seq} );
    $aa[0] = '-';
    $seq->{seq} = join( '', @aa );
#    $seq->{seq} = substr( $args{fasta_seq}, 0, 1 );

  } elsif ( $args{type} =~ /CHAIN|PEPTIDE|PROPEP/ ) { # Sequence is annotated chain sequence
    $seq->{seq} = '-' x ( $args{start} - 1 ) . 
                  substr( $args{fasta_seq}, $args{start} - 1, $args{end} - $args{start} + 1 ) .
                  '-' x ($seqlen - $args{end});

  } elsif ( 0 ) { # Deprecated, SNP shows as stand-alone peptide
    my $tryp = $self->do_tryptic_digestion( aa_seq => $args{fasta_seq} );
    my $pos = -1;
    my $snp_pep = '';
    my $idx = 0;
    my $newtryp = 0;
    $args{info} =~ /^\s*(\w)\s*\-\>\s*(\w)/;
    my $original = $1;
    my $altered = $2;
    for my $pep ( @{$tryp} ) {
      $pos += length( $pep );
      if ( $pos >= $args{start} ) {
        $args{match} = $pep; 
        $args{'pos'} = $pos; 
        my $sub_idx = $pos - $args{start};
        my @aa = split( '', $pep );
        $log->debug( "AA is $aa[$sub_idx] from $sub_idx in $pos and $args{start} - $args{info}, tryp is $pep" );
#        die "Mismatch in SNP sequence $args{info}" unless $aa[$sub_idx] eq $original;
        $aa[$sub_idx] = $altered;
        $seq->{annot} = { $args{start} => qq~<span class=pa_snp_font TITLE="$args{info}">$altered</span>~ };
        $seq->{seq} = join( '', @aa );
        if ( $#aa == $sub_idx ) {
          $newtryp++;
        }
        last;
      }
      $idx++;
    }
    $seq->{seq} .= $tryp->[$idx++] if $newtryp;

  } elsif ( $args{type} eq 'VARIANT' || $args{type} eq 'CONFLICT' ) { # with snp_context (15)
    my $snp_context = 2;
    $args{info} =~ /^\s*(\w+)\s*\-\>\s*(\S+)/;
    my $original = $1;
    my $altered = $2;
    if ( $args{type} eq 'CONFLICT' && length( $original ) != length( $altered ) ) {
#      $log->debug( "Skipping CONFLICT $args{info} because $original and $altered are different!" );
      next;
    }
    if ( $original && length( $original ) > 1 || length( $altered ) > 1 )  {
#      $log->debug( "Skipping $args{info} because $original or $altered are > 1" );
      next;
    }
    my $tryp = $self->do_tryptic_digestion( aa_seq => $args{fasta_seq} );
    my @pre;
    my @post;
    my $snp_seq;
    my $pos = 0;
    my $found = 0;
    my $relpos;
    my $newtryp_added = 0;
    for ( my $idx = 0; $idx < scalar( @{$tryp} ); $idx++ ) {
      my $tryptic = $tryp->[$idx];
      $pos += length( $tryptic );
      if ( $pos >= $args{start} ) {
        if ( !$found ) {
          $args{altered} = $altered;
          $args{original} = $original;

          # A bit of trickery if we changed from a basic to a non-basic AA
          if ( $original =~ /[KR]/ && $altered !~ /[KR]/ && $args{start} == $pos && $tryptic !~ /P[KR]$/ ) {
            $idx++;
            my $new_tryp = $tryp->[$idx];
            $pos += length( $new_tryp );
            $tryptic .= $new_tryp;
          }

          my $prev = $pos - length( $tryptic );
          my @aa = split( //, $tryptic );
          $relpos = $args{start} - $prev - 1;
          next if $relpos < 0;
          next unless $aa[$relpos] eq $original;
          $aa[$relpos] = $altered;
          $snp_seq = join( '', @aa ); 
          $seq->{annot} = { $args{start} => qq~<span class=pa_snp_font TITLE="$args{info}">$altered</span>~ };
          $found++;
        } else {
          if ( $args{altered} !~ /[KR]/ && $args{original} =~ /[KR]/ && !$newtryp_added ) {
            $newtryp_added++;
            $snp_seq .= $tryptic;
          } else {
            push @post, $tryptic;
          }
        }
      } else {
        push @pre, $tryptic;
      }
    }
    my $nside = $relpos;
    my $cside = length( $snp_seq ) - $relpos;
    my $c_context = '';
    my $n_context = '';
    for my $pep ( reverse( @pre ) ) {
      if ( $nside < $snp_context || $nside < 30 ) {
        $snp_seq = $pep . $snp_seq;
        $nside += length( $pep );
      } else {
        $n_context .= '-' x length( $pep );
      }
    }
    for my $pep ( @post ) {
      if ( $cside < $snp_context || $cside < 30 ) {
        $snp_seq .= $pep;
        $cside += length( $pep );
      } else {
        $c_context .= '-' x length( $pep );
      }
    }
    $snp_seq ||= '';
    $seq->{seq} = $n_context . $snp_seq . $c_context;

  } elsif ( $args{type} eq 'SIGNAL' ) { # Sequence is signal start->end 
    my $seqend = ( $seqlen < $context_len ) ? $seqlen : $context_len;
    $seq->{seq} = substr( $args{fasta_seq}, 0, $args{end} ) . '-' x ( $seqlen - $args{end} );
  } else { # Should never get here...
  }
  if ($seq->{seq} =~ /\*/){$seq->{seq} =~ s/\*.*/\*/;}

  return $seq;
}

sub get_uniprot_annotation {
  my $self = shift;
  my %args = ( show_all_snps => 0,
               use_nextprot => 0,
               @_ );

  my %annot = ( success => 0,
                all_vars => [], 
                has_modres => 0,
                has_variants => 0,
               );

  return \%annot unless $args{accession};

  my $build_id = $args{build_id};
  return if (! $build_id);
  my $np_clause = "AND is_nextprot = 'N'";
  $np_clause = "AND is_nextprot = 'Y'" if $args{use_nextprot};

  my $sql = qq~
  SELECT file_path, entry_offset, entry_name
  FROM $TBAT_UNIPROT_DB UD 
  JOIN $TBAT_UNIPROT_DB_ENTRY UDE ON (UD.uniprot_db_id = UDE.uniprot_db_id )
  JOIN $TBAT_ATLAS_BUILD AB ON (AB.biosequence_set_id = UD.biosequence_set_id) 
  WHERE entry_accession = '$args{accession}'
  AND AB.atlas_build_id = $build_id
  $np_clause
  ORDER BY uniprot_db_entry_id DESC
  ~;

  my $sbeams = $self->getSBEAMS();
  my @results = $sbeams->selectrow_array( $sql );
  #print " file_path, entry_offset, entry_name " . join(",", @results) . "\n";

  my $entry = $self->read_uniprot_dat_entry( path => $results[0],
					     offset => $results[1] );

  if ( !$entry ) {
    return \%annot;
  }
  $annot{success}++;

  # Read the entry
  if ( $entry ) {
    my $swiss = SWISS::Entry->fromText($entry);
    $swiss->fullParse();
    my $fasta = $swiss->toFasta();
    my @fasta = split( /\n/, $fasta );
    my $fasta_seq = join( '', @fasta[1..$#fasta] );
    $fasta_seq =~ s/\s//g;
    $fasta_seq = uc($fasta_seq);
    $annot{fasta_seq} = $fasta_seq;

    if ( $swiss->{FTs} ) {

      for my $var ( @{$swiss->{FTs}->{list}} ) {
        if ( $var->[0] =~ /CHAIN/ || 
             $var->[0] =~ /SIGNAL/ || 
             $var->[0] =~ /INIT_MET/ || 
             $var->[0] =~ /TRANSMEM/ || 
             $var->[0] =~ /TOPO_DOM/ || 
             $var->[0] =~ /VARIANT/ && $var->[3] =~ /dbSNP/ || 
             $var->[0] =~ /VARIANT/  && $args{show_all_snps} || # dbsnp conditionally req.
             $var->[0] =~ /MOD_RES/ ||
             $var->[0] =~ /PROPEP/ || 
             $var->[0] =~ /PEPTIDE/ || 
             $var->[0] =~ /CONFLICT/ || 
             $var->[0] =~ /CARBOHYD/ ) {

          # Start and end should always be numeric, but somehow are not...
          for my $key ( 1, 2 ) {
            $var->[$key] =~ s/\D//g;
          }
          next if $var->[0] eq 'CHAIN' && $var->[1] == 2 && $var->[2] == length($fasta_seq);
          next if $var->[0] eq 'CHAIN' && $var->[1] == 1 && $var->[2] == length($fasta_seq);

          next unless ( defined $var->[1] && defined $var->[2] &&
                        $var->[1] =~ /^\d+$/ && $var->[2] =~ /^\d+$/  );

          my %var = ( type => $var->[0],
                     start => $var->[1],
                       end => $var->[2],
                      info => $var->[3] );


          my $var_seq = $self->get_uniprot_variant_seq ( %var, fasta_seq => $fasta_seq ); 


          $var{seq} = $var_seq->{seq};
          $var{annot} = $var_seq->{annot};

          $annot{$var{type}} ||= [];

          push @{$annot{$var{type}}}, \%var; 
          if ( $var->[0] =~ /MOD_RES|CARBOHYD/ ) {
            $annot{has_modres}++;
          } elsif ( $var->[0] ne 'CONFLICT' ) { # Not yet using these
            $annot{has_variants}++;
          }
        }

      }
    }
    if ( $swiss->{PE} ) {
      $swiss->{PE}->{text} =~ /^\s*(\d):\s*(.*)$/;
      $annot{PE}->{value} = $1;
      $annot{PE}->{text} = $2;
    }
  }
  return \%annot;
}

sub read_uniprot_dat_entry {
  my $self = shift;
  my %args = @_;
  return '' unless $args{path} && defined( $args{offset} );

  # Reset local record separator, read an entire record at a time

  local $/ = "\n//\n";
  open DAT, $args{path} || return '';
  seek( DAT, $args{offset}, 0 );

  my $entry = '';
  while ( my $record = <DAT> ) {
    $entry = $record;
    last;
  }
  close DAT;
  return $entry;
}

sub get_clustal_coordinates {
  my $self = shift;
  my $coords = { start => 999, len => 999, seq => '', alignment => {} };
  my $clustal = shift || return $coords;  

  my $seq = $clustal->[1]->[1];
  $seq =~ /^(-*)([^-]+)(-*)/;
  $coords->{start} = length( $1 );
  $coords->{seq} = $2;
  $coords->{len} = length( $2 );

  my $align = substr( $clustal->[2]->[1], $coords->{start}, $coords->{len} );

  my $acnt = 1;
  for my $ro ( split( //, $align ) ) {
    $coords->{alignment}->{$acnt}++ unless $ro =~ /\*/;
    $acnt++;
  }
  return $coords;
}


sub get_clustal_display {
  my $self = shift;
  my %args = ( acc_color => '#0090D0', @_ );

  my $sbeams = $self->getSBEAMS();

  my $align_spc;
  my $name_spc;
  my $table_rows = '';
  my $scroll_class = ( scalar( @{$args{alignments}} ) > 16 ) ? 'clustal_peptide' : 'clustal';

  my $style = '';
  my $style2= '';
  my $px = 0;
  my $counter = 0;
  my $n_alignment = scalar @{$args{alignments}};

  for (my $i=0; $i<$n_alignment; $i++){
    my $seq = $args{alignments}[$i];
    my $sequence = $seq->[1];

    next if($i>1000 && $seq->[0] =~ /VAR/);
    if ( $seq->[0] =~ /\&nbsp;/  ) {
    } else {
      $sequence = $self->highlight_sites( seq => $sequence, 
                                          acc => $seq->[0], 
                                          nogaps => 1,
                                          track => $seq->[0],
																					coverage => $args{coverage}->{$seq->[0]});
    }

    if ( $args{snp_cover} ) {
      if ( $args{snp_cover}->{$seq->[0]} ) {
        $sequence = $self->add_snp_cover_css( seq => $sequence, cover => $args{snp_cover}->{$seq->[0]} );
      }
    }

    if ( $seq->[0] ) {
      if ($seq->[0] eq 'Primary'){
				$style2= "style ='position: sticky; top: ${px}px;left: 0px;z-index:6;background:#f3f1e4'";
				$style = "style ='position: sticky; top: ${px}px;z-index:3;background:#f3f1e4'";
				$px += 15;
      }
      else {
				$style2= "style ='position: sticky; left: 0px;z-index:4;background:#f3f1e4'";
      }
      $table_rows .= qq~
      <TR >
        <TD ALIGN=right class=pa_sequence_font $style2>$seq->[0]:</TD>
        <TD NOWRAP=1 class=pa_sequence_font $style >$sequence</TD>
      </TR>
      ~;
      $style = '';
      $style2= '';
    } else {
      $style2= "style ='position: sticky; top: ${px}px;left: 0px;z-index:6;background:#f3f1e4'";
      $style = "style ='position: sticky; top: ${px}px;left: 0px;z-index:5;background:#f3f1e4'";
      $px += 15;
      $table_rows .= qq~
      <TR>
        <TD ALIGN=right class=pa_sequence_font $style2></TD>
        <TD NOWRAP=1 class=pa_sequence_font $style>$sequence</TD>
      </TR>
      ~;
      $style = '';
      $style2= '';
    }
    $counter++;
  }


  my $scroll_js = q(
  <SCRIPT TYPE="text/javascript">
  </SCRIPT>
  );

  my $xsjs = q(
  function postpos (e) {
//    alert( $(".clustal").scrollLeft() );
  }
  var skip = false;
  $("#clustal_dummy_wrap").scroll(function () {
    alert( "scroll dummy" )
    $("#clustal_wrap").scrollLeft($("#clustal_dummy_wrap").scrollLeft());
  });
  $("#clustal_wrap").scroll(function () { 
    alert( "scroll wrap" )
    $("#clustal_dummy_wrap").scrollLeft($("#clustal_wrap").scrollLeft());
  });
  $("#clustal_dummy_wrap").scroll(function () {
    if (skip){skip=false; return;} else skip=true; 
    $("#clustal_wrap").scrollLeft($("#clustal_dummy_wrap").scrollLeft());
  });
  $("#clustal_wrap").scroll(function () { 
    $("#clustal_dummy_wrap").scrollLeft($("#clustal_wrap").scrollLeft());
  });


  $(function(){
   $(".clustal_dummy_wrap").scroll(function(){
    $(".clustal").scrollLeft($(".clustal_dummy_wrap").scrollLeft());
   });
   $(".clustal").scroll(function(){
    $(".clustal_dummy_wrap").scrollLeft($(".clustal").scrollLeft());
   });
   });
	<DIV CLASS="clustal_dummy_wrap">
 	  <DIV CLASS="clustal_dummy">
    </DIV>
  </DIV>
	<DIV CLASS="clustal_wrap">
  </DIV>
  );

  my $display = qq~
  $scroll_js

   <DIV CLASS="$scroll_class" ID="clustal">
     <FORM METHOD=POST NAME="custom_alignment">
     <TABLE BORDER=0 CELLPADDNG=3 style='position: relative'>
        $table_rows
     </TABLE>
   </DIV>
	~;

  return $display;
}


sub highlight_sites {
  my $self = shift;
  my %args = @_;
#  die Dumper( %args ) if $args{acc} eq 'SNP_38';
  my $coverage = $args{coverage};
  my $track = $args{track};

  my @aa = split( '', $args{seq} );
  my $return_seq = '';
  my $cnt = 0;
  my $in_coverage = 0;
  my $in_primarysnp_coverage = 0;
  my $seq_started = 0;

  for my $aa ( @aa ) {
    if ( $args{nogaps} && $aa eq '-' ) {
      if ( $seq_started ) {
				if ( $in_coverage ) {
					$return_seq .= "</span>$aa";
					$in_coverage = 0;
			  } else {
					$return_seq .= $aa;
				}
      } else {
				$return_seq .= $aa;
      }
    } else { # it is an amino acid
      $seq_started++;
      if ($track eq 'Primary' && $coverage->{$cnt} && ! $coverage->{$cnt}{primary}){# primary track covered by snp
				if ( $in_primarysnp_coverage ) { # already in
					$return_seq .= $aa;
				} else {
          if ($in_coverage){
            $return_seq .= "</span>";
            $in_coverage =0;
          }
					$in_primarysnp_coverage++;
          $return_seq .= "<span class=pa_snp_observed_sequence>$aa";
        }
      }elsif(($track eq 'Primary' && $coverage->{$cnt} && $coverage->{$cnt}{primary}) || #primary track covered 
             ($track ne 'Primary' && $coverage->{$cnt})){ # non-primary track covered 
        if ( $in_coverage ) { # already in
          $return_seq .= $aa;
        } else {
          if ($in_primarysnp_coverage){
            $return_seq .= "</span>";
            $in_primarysnp_coverage=0; 
          }
          $in_coverage++;
          $return_seq .= "<span class=pa_observed_sequence>$aa";
        }
      }else { # posn not covered!
				if ( $in_coverage || $in_primarysnp_coverage){# were in, close now
          $return_seq .= "</span>$aa";
          $in_primarysnp_coverage=0;
          $in_coverage = 0;
        }else{ 
					$return_seq .= $aa;
				}
      }
    }
    $cnt++;
  }
  if ( $in_coverage ) {
    $return_seq .= '</span>';
  }
#  print Dumper( $return_seq ) if $args{acc} eq 'SNP_38';
  return $return_seq;

  my $dump = "$return_seq\n";
  if ( $args{acc} =~ /Chain/ ) {
    for my $site ( sort { $a <=> $b }(  keys( %{$args{coverage}} ) ) ) {
      $dump .= "$site => $args{coverage}->{$site}\n";
    }
#    die Dumper( $dump );
  }
}


sub make_qtrap5500_target_list {
  my $self = shift;
  my %args = @_;

  my $data = $args{data} || die;
  my $col_idx = $args{col_idx} || 
  {  'Protein' => 0,
     'Pre AA' => 1,
     'Sequence' => 2,
     'Fol AA' => 3,
     'Adj SS' => 4,
     'SSRT' => 5,
     'Source' => 6,
     'q1_mz' => 7,
     'q1_chg' => 8,
     'q3_mz' => 9,
     'q3_chg' => 10,
     'Label' => 11,
     'RI' => 12 };

# 0 'Protein',
# 1 'Pre AA',
# 2 'Sequence',
# 3 'Fol AA',
# 4 'Adj SS',
# 5 'SSRT',
# 6 'Source',
# 7 'q1_mz',
# 8 'q1_chg',
# 9 'q3_mz',
# 10 'q3_chg',
# 11 'Label',
# 12 'RI',
#
# 0 'CE_range
# Q1,Q3,RT,sequence/annotation,CE,,Comment
# 537.2933,555.30475,25.97,LLEYTPTAR.P49841.2y5.heavy,29.140903,,
  my $head = 0;
  my $csv_file = '';
  for my $row ( @{$data} ) {
    next unless $head++;
    my $protein = $self->extract_link( $row->[$col_idx->{Protein}] );
    my $seq = $row->[$col_idx->{Sequence}];
    if ( $args{remove_mods} ) {
      $seq =~ s/\[\d+\]//g;
    }
    my $ce = $self->get_qtrap5500_ce( medium_only => 1, mz => $row->[$col_idx->{q1_mz}], charge => $row->[$col_idx->{q1_chg}] );
    my $seq_string = join( '.', $seq, $protein, $row->[$col_idx->{q1_chg}] . $row->[$col_idx->{Label}] . '-' . $row->[$col_idx->{q3_chg}] );
    my $rt = $args{rt_file}->{$seq} || 'RT';
    $csv_file .= join( ',', $row->[$col_idx->{q1_mz}], $row->[$col_idx->{q3_mz}], $rt, $seq_string, $ce, 'Auto-generated' ) . "\n";
  }
  my $sbeams = $self->getSBEAMS();
  my $file_path = $sbeams->writeSBEAMSTempFile( content => $csv_file );

  return $file_path;
}

# For Thermo TSQ
sub calculate_thermo_ce {
  # process args
  my $self = shift;
  my %args = @_;
  for my $req_arg ( qw( mz charge ) ) {
    unless ( $args{$req_arg} ) {
      $log->warn( "Missing required argument $req_arg" );
      return '';
    }
  }

  # calculate CE  
  my $ce;
  if ($args{charge} == 2) {
    $ce = ( 0.034 * $args{mz} ) + 3.314;
  } elsif ($args{charge} == 3) {
    $ce = ( 0.044 * $args{mz} ) + 3.314;
  } else {
    $ce = ( 0.044 * $args{mz} ) + 3.314;
  }
  return sprintf( "%0.2f", $ce );
}

# For Agilent QTOF and QQQ
sub calculate_agilent_ce {
  # process args
  my $self = shift;
  my %args = @_;
  for my $req_arg ( qw( mz charge ) ) {
    unless ( $args{$req_arg} ) {
      $log->warn( "Missing required argument $req_arg" );
      return '';
    }
  }

  if ( $args{empirical_ce} && $args{seq} && $args{ion} ) {
    if ( !$self->{_SRM_CE} ) {
      $self->{_SRM_CE} = retrieve( "/net/db/projects/PeptideAtlas/MRMAtlas/analysis/CE_extraction/global_values/SRM_CE.sto" );
    }
    my $pepion = $args{seq} . '/' . $args{charge};
    if ( $self->{_SRM_CE}->{$pepion} &&  $self->{_SRM_CE}->{$pepion}->{$args{ion}} ) {
      return sprintf( "%0.1f", $self->{_SRM_CE}->{$pepion}->{$args{ion}}->{max_ce} );
    }
  }

  # calculate CE  
  my $ce;
  if ( $args{charge} == 2 || $args{charge} == 1 ) {
    $ce = ( (2.93*$args{mz})/100 ) + 6.72;
  } else {
    $ce = ( (3.6*$args{mz} )/100 ) -4.8;
    $ce = 0 if $ce < 0;
  }
  return sprintf( "%0.1f", $ce );
}

# For ABISCIEX QTRAP4000 and 5500
sub calculate_abisciex_ce {
  # process args
  my $self = shift;
  my %args = @_;
  for my $req_arg ( qw( mz charge ) ) {
    unless ( $args{$req_arg} ) {
      $log->warn( "Missing required argument $req_arg" );
      return '';
    }
  }

  # calculate CE  
  my $ce;
  if    ( $args{charge} == 1 ) { 
    $ce = 0.058 * $args{mz} + 9; 
  } elsif ( $args{charge} == 2 ) { 
    $ce = 0.044 * $args{mz} + 5.5;
  } elsif ( $args{charge} == 3 ) { 
    $ce = 0.051 * $args{mz} + 0.5;
  } elsif ( $args{charge} > 3 )  { 
    $ce = 0.05 * $args{mz} + 2; 
#    $ce = 0.003 * $args{mz} + 2; 
  }
  $ce = 75 if ( $ce > 75 ); 
  return sprintf( "%0.2f", $ce );
}

sub get_qqq_unscheduled_transition_list {
  my $self = shift;
  my %opts = @_;

  my $tsv = $opts{method} || return '';
  $opts{empirical_ce} = $opts{params}->{empirical_ce} || 0;
  $opts{calc_rt} = $opts{params}->{calc_rt} || 0;

  my $method = qq~MRM
Compound Name	ISTD?	Precursor Ion	MS1 Res	Product Ion	MS2 Res	Dwell	Fragmentor	Collision Energy	Cell Accelerator Voltage	Polarity
~;

  my $w = 'Wide';
  my $f = 125;
  my $d = 10;
  my $v = 5;
  my $u = 'Unit';
  my $p = 'Positive';

  my %ce;

  for my $row ( @{$tsv} ) {
    my @line = @{$row};
    next if $line[0] eq 'Protein';
    my $acc = $line[0];
    $acc =~ s/\s+$//g;

    my $seq = $line[2];
    my $q1 = $line[6];
    my $q1c = $line[7];
    my $q3 = $line[8];
    my $q3c = $line[9];
    my $lbl = $line[10];
    my $ion = $q1c . $lbl . '-' . $q3c;
    
    my $rtd = 5;
    my $name = $seq . '.' . $acc . '.' . $ion;

    my $full_lbl = $lbl;
    $full_lbl .= '^' . $q3c if $q3c > 1;

    my $ce_key = $seq . $q1c;
    my $curr_ce = $ce{$ce_key};
    if ( !$curr_ce ) {
      my $deisotoped_sequence = $self->clear_isotope( sequence => $seq );
      $curr_ce = $self->calculate_agilent_ce( mz => $q1, charge => $q1c, empirical_ce => $opts{empirical_ce},
					      seq => $deisotoped_sequence, ion => $full_lbl );
    }
    $ce{$ce_key} = $curr_ce unless $opts{empirical_ce};

#    my $ce = ( $q1c == 2 ) ? sprintf( "%0.2f", ( 2.93 * $q1 )/100 + 6.72 ) : 
#				                     sprintf( "%0.2f", ( 3.6 * $q1 )/100 - 4.8 );

    my $istd = 'False';
    $istd = 'True'  if $seq =~ /6\]$/;

    $method .= join( "\t", $name, $istd, $q1, $w, $q3, $u, $d, $f, $curr_ce, $v, $p ) . "\n";
  }
  return $method;
}
## END

sub get_qqq_dynamic_transition_list {
  my $self = shift;
  my %opts = @_;

  my $tsv = $opts{method} || return '';
  $opts{empirical_ce} = $opts{params}->{empirical_ce} || 0;
  $opts{calc_rt} = $opts{params}->{calc_rt} || 0;

  my $method = "Dynamic MRM\n";

  my @headings = ( 'Compound Name', 'ISTD?', 'Precursor Ion', 'MS1 Res', 'Product Ion', 'MS2 Res', 'Fragmentor', 'Collision Energy', 'Cell Accelerator Voltage', 'Ret Time (min)', 'Delta Ret Time', 'Polarity' );
  
  if ( $opts{calc_rt} ) {
    push @headings, 'EstimatedRT';
  }
  $method .= join( "\t", @headings ) . "\n";

  my $u = 'Unit';
  my $w = 'Wide';
  my $p = 'Positive';

  my %ce;

  for my $row ( @{$tsv} ) {
    my @line = @{$row};
    next if $line[0] eq 'Protein';
    my $acc = $line[0];
    $acc =~ s/\s+$//g;

    my $seq = $line[2];
    my $q1 = $line[6];
    my $q1c = $line[7];
    my $q3 = $line[8];
    my $q3c = $line[9];
    my $lbl = $line[10];
		
    # Ion for
    my $ion = $lbl . '-' . $q3c;

    # Changed DSC 2012-05-15 - should use column names!!!
    my $rt = $line[14];
    my $rtd = 5;

    my $name = $seq . '.' . $acc . '.' . $q1c . $ion;

    my $full_lbl = $lbl;
    $full_lbl .= '^' . $q3c if $q3c > 1;

    my $ce_key = $seq . $q1c;
    my $curr_ce = $ce{$ce_key};
    if ( !$curr_ce ) {
      my $deisotoped_sequence = $self->clear_isotope( sequence => $seq ); 
      $curr_ce = $self->calculate_agilent_ce( mz => $q1, charge => $q1c, empirical_ce => $opts{empirical_ce},
					      seq => $deisotoped_sequence, ion => $full_lbl );
    }
    $ce{$ce_key} = $curr_ce unless $opts{empirical_ce};

#    my $ce = ( $q1c == 2 ) ? sprintf( "%0.2f", ( 2.93 * $q1 )/100 + 6.72 ) : 
#				                     sprintf( "%0.2f", ( 3.6 * $q1 )/100 - 4.8 );


    my $est_rt = sprintf( "%0.1f", ($line[13]*72.94461-122.83351)/60);
    my $istd = 'False';
    $istd = 'True' if $seq =~ /6\]$/;
    my @rowdata = ( $name, $istd, $q1, $w, $q3, $u, 125, $curr_ce, 5, $rt, $rtd, $p );
    if ( $opts{calc_rt} ) {
      push @rowdata, $est_rt;
    }
    $method .= join( "\t", @rowdata ) . "\n";
  }
  return $method;
}

sub clear_isotope {
  my $self = shift;
  my %args = @_;
  return '' unless $args{sequence};
  my $sequence = $args{sequence};
  $sequence =~ s/R\[166\]/R/g;
  $sequence =~ s/K\[136\]/K/g;
  return $sequence;
}

sub clear_massmods {
  my $self = shift;
  my $sequence = shift || return '';
  $sequence =~ s/\[\d+\]//g;
  return $sequence;
}

sub get_qtrap_mrmms_method {
  my $self = shift;
  my %opts = @_;
  my $tsv = $opts{method} || return '';

  my $sep = "\t";
  $sep = ",";

  # Headings removed per UKusebauch, 2015-11
#  my $method = join($sep, qw(Q1 Q3 Dwell peptide.protein.Cso CE)) . "\r\n";
  my $method = '';

  my $dwell = 10;
  my %ce = {};
  for my $row ( @{$tsv} ) {
    my @line = @{$row};
    next if $line[0] eq 'Protein';

    my $acc = $line[0];
    $acc =~ s/\s+$//g;

    my $seq = $line[2];
    my $q1 = $line[6];
    my $q1c = $line[7];
    my $q3 = $line[8];
    my $q3c = $line[9];
    my $lbl = $line[10];
    my $label = $seq . '.' . $acc . '.' . $q1c . $lbl; 
#		$label .= '-' . $q3c if $q3c > 1;
    $label .= '-' . $q3c;

    my $ce_key = $seq . $q1c;
    $ce{$ce_key} ||= $self->calculate_abisciex_ce( mz => $q1, charge => $q1c );

#  my $method = join($sep, qw(Q1 Q3 Dwell peptide.protein.Cso CE)) . "\r\n";
    $method .= join( $sep, $q1, $q3, $dwell, $label, $ce{$ce_key} ) . "\r\n";
  }
  return $method;
}

sub get_qtrap_mrm_method {
  my $self = shift;
  my %opts = @_;
  my $tsv = $opts{method} || return '';

  my $sep = "\t";
  $sep = ",";

#  my $method = join($sep, qw(Q1 Q3 RT peptide.protein.Cso CE)) . "\r\n";
  my $method = '';

  my %ce = {};
  for my $row ( @{$tsv} ) {
    my @line = @{$row};
    next if $line[0] eq 'Protein';

    my $acc = $line[0];
    $acc =~ s/\s+$//g;

    my $seq = $line[2];
    my $q1 = $line[6];
    my $q1c = $line[7];
    my $q3 = $line[8];
    my $q3c = $line[9];
    my $lbl = $line[10];
    my $rt = $line[14];

    my $ce_key = $seq . $q1c;
    $ce{$ce_key} ||= $self->calculate_abisciex_ce( mz => $q1, charge => $q1c );

    my $label = $seq . '.' . $acc . '.' . $q1c . $lbl; 
#		$label .= '-' . $q3c if $q3c > 1;
    $label .= '-' . $q3c;
    $method .= join($sep, $q1, $q3, $rt, $label, $ce{$ce_key} ) . "\r\n";
  }
  return $method;
}


sub get_skyline_export {
  my $self = shift;
  my %args = @_;

  my $tsv = $args{method} || return '';

  my $sep = "\t";

#  my $method = join( $sep, qw( Accession Sequence Precursor_mz Product_mz ModSequence )  ) . "\n";
  my $method = '';

  for my $row ( @{$tsv} ) {
    my @line = @{$row};
    next if $line[0] eq 'Protein';

    my $acc = $line[0];
    $acc =~ s/\s+$//g;

    my $mod_seq = $line[2];
    my $clean_seq = $self->clear_massmods( $line[2] );
    my $q1 = $line[6];
    my $q3 = $line[8];

    $method .= join( $sep, $acc, $clean_seq, $q1, $q3, $mod_seq ) . "\n";
  }
  return $method;
}


sub get_thermo_tsq_mrm_method {
  my $self = shift;
  my %args = @_;

  my $tsv = $args{method} || return '';

  my $sep = "\t";

  my $method = join( $sep, ("Q1","Q3","CE","Start time (min)","Stop time (min)","Polarity","Trigger","Reaction category","Name"))."\r\n";

  my %ce = {};
  for my $row ( @{$tsv} ) {
    my @line = @{$row};
    next if $line[0] eq 'Protein';

    my $acc = $line[0];
    $acc =~ s/\s+$//g;

    my $seq = $line[2];
    my $q1 = $line[6];
    my $q1c = $line[7];
    my $q3 = $line[8];
    my $q3c = $line[9];
    my $lbl = $line[10];
    my $rt = $line[14];
    my $rt_delta = 5;

    my $ce_key = $seq . $q1c;
    $ce{$ce_key} ||= $self->calculate_thermo_ce( mz => $q1, charge => $q1c );

    my $label = $seq . '.' . $acc . '.' . $q3c . $lbl . $q3; 
    $method .= join( $sep, $q1, $q3, $ce{$ce_key}, $rt - $rt_delta, $rt + $rt_delta,1,'1.00E+04',1,$label) . "\r\n";
  }
  return $method;
}


sub extract_link {
  my $self = shift;
  my $url = shift;
  if ( $url =~ />([^<]+)<\/A>/ ) {
    my $link = $1;
    $link =~ s/^\s+//;
    $link =~ s/\s+$//;
    return $link;
  }
  return '';
}

sub make_resultset {
  my $self = shift;
  my %args = @_;
  return undef unless $args{rs_data};
  $args{file_prefix} ||= '';
  $args{rs_params} ||= {};

  # We can either get explicitly passed headers,
  # or an array which includes headers
  if ( !$args{headers} ) {
    $args{headers} = shift @{$args{rs_data}};
  }
  my $rs_name = 'SETME';
  my $rs_ref = { column_list_ref => $args{headers},
                        data_ref => $args{rs_data},
             precisions_list_ref => [] };

  $self->getSBEAMS()->writeResultSet( resultset_file_ref => \$rs_name,
				           resultset_ref => $rs_ref,
                                             file_prefix => $args{file_prefix},
                                    query_parameters_ref => $args{rs_params}  );


  $self->{_cached_resultsets} ||= {};
  $self->{_cached_resultsets}->{$rs_name} = $rs_ref;

  return $rs_name;
}

sub get_cached_resultset {
  my $self = shift;
  my %args = @_;
  return undef unless $args{rs_name};
  if ( $self->{_cached_resultsets} ) {
    return $self->{_cached_resultsets}->{$args{rs_name}};
  } else {
    $log->error( "Requested non-existent resultset!" );
    return undef;
  }
}


#################################################################
############PeptideCount
#################################################################
###This method counts the total number of Public builds in which peptide found along with number of organisms in which peptide found

sub PeptideCount {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();

  my %args=@_;

  my ($atlas_project_clause,$peptide_clause);

  $atlas_project_clause=$args{atlas_project_clause};

  $peptide_clause=$args{peptide_clause};


  unless ($peptide_clause && $atlas_project_clause) {

    print "The Required clause parameters not found. Unable to generate the count of Builds in which peptide Found";
    return;

  }
  my $sql = qq~

   SELECT  distinct AB.atlas_build_name, OZ.organism_name
      FROM $TBAT_PEPTIDE_INSTANCE PI
      INNER JOIN $TBAT_PEPTIDE P
      ON ( PI.peptide_id = P.peptide_id )
      INNER JOIN $TBAT_ATLAS_BUILD AB
      ON (PI.atlas_build_id = AB.atlas_build_id)
      INNER JOIN $TBAT_BIOSEQUENCE_SET BS
      ON (AB.biosequence_set_id = BS.biosequence_set_id)
      INNER JOIN $TB_ORGANISM OZ
      ON (BS.organism_id= OZ.organism_id)
      WHERE 1 = 1
      $atlas_project_clause
      $peptide_clause
      ORDER BY  OZ.organism_name, AB.atlas_build_name
      
   ~;
   
  my @rows = $sbeams->selectSeveralColumns($sql) or print " Error in the SQL query";
  my(@build_names,%seen_organisms);

  if (@rows) {
    foreach my $row (@rows) {

      my ($build_name,$org_name)=@{$row};
      $seen_organisms{$row->[1]}++;

      push(@build_names, $row->[0]);

    }# End For Loop

  } # End if Loop


  my @distinct_organisms = keys( %seen_organisms );

  my $no_distinct_organisms= scalar(@distinct_organisms);
  my $no_builds= scalar(@build_names);
  return ($no_distinct_organisms,$no_builds);
}


sub getAnnotationColumnDefs {
  my $self = shift;
  my @entries = (
    { key => 'Sequence', value => 'Amino acid sequence of detected pepide, including any mass modifications.' },
    { key => 'Charge', value => 'Charge on Q1 (precursor) peptide ion.' },
    { key => 'q1_mz', value => 'Mass to charge ratio of precursor peptide ion.' },
    { key => 'q3_mz', value => 'Mass to charge ratio of fragment ion.' },
    { key => 'Label', value => 'Ion-series designation for fragment ion (Q3).' },
    { key => 'Intensity', value => 'Intensity of peak in CID spectrum' },
    { key => 'CE', value => 'Collision energy, the kinetic energy conferred to the peptide ion and resulting in peptide fragmentation. (eV)' },
    { key => 'RT', value => 'Peptide retention time( in minutes ) in the LC/MS system.' },
    { key => 'SSRCalc', value => "Sequence Specific Retention Factor provides a hydrophobicity measure for each peptide using the algorithm of Krohkin et al. Version 3.0 <A HREF=http://hs2.proteome.ca/SSRCalc/SSRCalc.html target=_blank>[more]</A>" },
    { key => 'Instr', value => 'Model of mass spectrometer on which transition pair was validated.' },
    { key => 'Annotator', value => 'Person/lab who contributed validated transition.' },
    { key => 'Quality', value => 'Crude scale of quality for the observation, currently one of Best, OK, and No. ' },
      );
  return \@entries;
}

sub fragment_peptide {
  my $self = shift;
  my $peptide = shift || return [];

  my @chars = split( '', $peptide );
  my @residues;
  my $aa;
  for my $c ( @chars ) {
    if ( $c =~ /[a-zA-Z]/ ) {
      push @residues, $aa if $aa;
      $aa = $c;
    } else {
      $aa .= $c;
    }
  }
  push @residues, $aa if $aa;
  return \@residues;
}

sub get_qtrap5500_ce {
  my $self = shift;
  my %args = @_;

  my $ce = '';
  if ( $args{charge} && $args{mz} ) {
    my ($m, $i);
    if ( $args{charge} == 1 ) {
      $m = 0.058;
      $i = 9;
    } elsif ( $args{charge} == 2 ) {
      $m = 0.044;
      $i = 5.5;
    } elsif ( $args{charge} == 3 ) {
      $m = 0.051;
      $i = 0.5;
    } else {
      $m = 0.05;
      $i = 3;
    }
    $ce = sprintf( "%0.1f", $m*$args{mz} + $i );
  }
  return sprintf( "%0.2f", $ce );
}

sub get_Agilent_ce {
  my $self = shift;
  my %args = @_;

  my %ce = ( low => '', mlow => '', medium => '', mhigh => '', high => '' );
  if ( $args{charge} && $args{mz} ) {

    if ( $args{charge} == 2 ) {
      $ce{medium} = ( (2.93*$args{mz})/100 ) + 6.72;
    } else {
      $ce{medium} = ( (3.6* $args{mz} )/100 ) -4.8;
    }
    if ( $args{medium_only} ) {
      return $ce{medium};
    }

    my $delta = 0;
    if ( $args{charge} == 2 ) {
      $delta = 5;
    } elsif ( $args{charge} == 3 ) {
      $delta = 3.5;
    } else { 
      $delta = 2.5;
    }
  
    $ce{low} = sprintf ( "%0.1f", $ce{medium} - ( 2 * $delta ) );
    $ce{mlow} = sprintf ( "%0.1f", $ce{medium} - $delta );
    $ce{mhigh} = sprintf ( "%0.1f", $ce{medium} + $delta );
    $ce{high} = sprintf ( "%0.1f", $ce{medium} + ( 2 * $delta ) );
    $ce{medium} = sprintf ( "%0.1f", $ce{medium} );
  } 
  return \%ce;
}


sub calc_ions {
  my $self = shift;
  my %args = @_;

  my $masses = $self->getMonoResidueMasses();

  my $charge = $args{charge};
  my $length = length($args{sequence});
  my @residues = split( '', $args{sequence} );

  my $Nterm = 1.0078;
  my $Bion = 0.0;
  my $Yion  = 19.0184;  ## H_2 + O

  my %masslist;
  my (@aminoacids, @indices, @rev_indices, @Bions, @Yions);


  #### Compute the ion masses
  for ( my $i = 0; $i<=$length; $i++) {

    #### B index & Y index
    $indices[$i] = $i;
    $rev_indices[$i] = $length-$i;

#      $Bion += $masses[$i];
    $Bion += $masses->{$residues[$i]};
    $Yion += $masses->{$residues[$rev_indices[$i]]} if $i > 0;
#      $Yion += $masses[ $rev_indices[$i] ]  if ($i > 0);

    #### B ion mass & Y ion mass
    $Bions[$i+1] = ($Bion + $charge*$Nterm)/$charge;
    $Yions[$i] = ($Yion + $charge*$Nterm)/$charge - $Nterm;
  }

  $masslist{indices} = \@indices;
  $masslist{Bions} = \@Bions;
  $masslist{Yions} = \@Yions;
  $masslist{rev_indices} = \@rev_indices;

  #### Return reference to a hash of array references
  return (\%masslist);
}


#+
# calculate theoretical ions (including modified masses).  Borrowed 
# from howOneSpectrum cgi.
# 
# @narg Residues  ref to array of single AA (with optional mass mod signature)
# @narg Charge    Ion series to calculate, defaults to 1 
# @narg modifed_sequence Sequence with mod masses, as string.  Redundant with 
# Residues array.
#-
sub CalcIons {
  my $self = shift;
  my %args = @_;
  my $i;

  my $modification_helper = new SBEAMS::PeptideAtlas::ModificationHelper();
  my $massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator();
  my $mono_mods = $massCalculator->{supported_modifications}->{monoisotopic} || {};

  my $residues_ref = $args{'Residues'};
  my @residues = @$residues_ref;
  my $charge = $args{'Charge'} || 1;
  my $length = scalar(@residues);

  my $modified_sequence = $args{'modified_sequence'};

  # As before, fetch mass defs from modification helper.  Might want to use ISS
  my @masses = $modification_helper->getMasses($modified_sequence);
  my @new_masses;
  my $cnt = 0;
  for my $r ( @residues ) {
    if ( $r =~ /\[/ ) {
      # For modified AA, try to use InSilicoSpectro mod defs.
      if ( $mono_mods->{$r} ) {
        my $stripped_aa = $r;
        $stripped_aa =~ s/\W//g;
        $stripped_aa =~ s/\d//g;
        # Add ISS mod def to monoiso mass from mod_helper.
        my @mass = $modification_helper->getMasses($stripped_aa);
        push @new_masses, $mass[0] + $mono_mods->{$r};
      } else {
        push @new_masses, $masses[$cnt];
      }
    } else {
      push @new_masses, $masses[$cnt];
    }
    $cnt++;
  }

  @masses = @new_masses;

  my $Nterm = 1.0078;
  my $Bion = 0.;
  my $Yion  = 19.0184;  ## H_2 + O

  my @Bcolor = (14) x $length;
  my @Ycolor = (14) x $length;

  my %masslist;
  my (@aminoacids, @indices, @rev_indices, @Bions, @Yions);


  #### Compute the ion masses
  for ($i = 0; $i<$length; $i++) {
    $Bion += $masses[$i];

    #### B index & Y index
    $indices[$i] = $i;
    $rev_indices[$i] = $length-$i;
    $Yion += $masses[ $rev_indices[$i] ]  if ($i > 0);

    #### B ion mass & Y ion mass
    $Bions[$i] = ($Bion + $charge*$Nterm)/$charge;
    $Yions[$i] = ($Yion + $charge*$Nterm)/$charge;
  }

  $masslist{residues} = \@residues;
  $masslist{indices} = \@indices;
  $masslist{Bions} = \@Bions;
  $masslist{Yions} = \@Yions;
  $masslist{rev_indices} = \@rev_indices;

  #### Return reference to a hash of array references
  return (\%masslist);
}


sub make_sort_headings {
  my $self = shift;
  my %args = @_;
  return '' unless $args{headings};

  my @marked;
  my $cnt;
  while( @{$args{headings}} ) {
    my $head = shift @{$args{headings}};
    my $arrow = '';
    if ( $args{default} && $args{default} eq $head ) {
      $arrow = ( $args{asc} ) ? '&#9653;' : '&#9663;';
    }
    my $title = shift @{$args{headings}};
    my $link = qq~ <DIV TITLE="$title" ONCLICK="ts_resortTable(this,'$cnt');return false;" class=sortheader>$head<span class=sortarrow>&nbsp;$arrow</span></DIV>~;
    push @marked, $link;

    last if $cnt++ > 5000; # danger Will Robinson
  }
  return \@marked;
}

sub listBiosequenceSets {
  my $self = shift || die ("Must call as object method");
  my %args = @_;

  my $sets = $self->getBiosequenceSets();
  for my $set ( sort {$a <=> $b } keys( %{$sets} ) ) {
    print "$set\t$sets->{$set}\n";
  }
}

sub getBiosequenceSets {
  my $self = shift || die ("Must call as object method");
  my %args = @_;

  my $sql = qq~
    SELECT biosequence_set_id, set_tag
      FROM $TBAT_BIOSEQUENCE_SET
     WHERE record_status != 'D'
     ORDER BY biosequence_set_id ASC
  ~;

  my $sbeams = $self->getSBEAMS();
  my $sth = $sbeams->get_statement_handle( $sql );

  my %sets;
  while ( my @row = $sth->fetchrow_array() ) {
    $sets{$row[0]} = $row[1];
  }
  return \%sets;
}

sub fetchBuildResources {
  my $self = shift;
  my %args = @_;

  return unless $args{pabst_build_id};

  my $sql = qq~
  SELECT resource_type, resource_id 
  FROM $TBAT_PABST_BUILD_RESOURCE PBR
  WHERE pabst_build_id = $args{pabst_build_id}
  ~;

  my %resources;
  my $sbeams = $self->getSBEAMS();
  my $sth = $sbeams->get_statement_handle( $sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $resources{$row[0]} ||= {};
    $resources{$row[0]}->{$row[1]}++;
  }
  return \%resources;
}

sub calculate_antigenic_index {
  my $self = shift;
  my %args = @_;

  my $seq = $args{sequence} || die "Missing required argument sequence";

  $seq=~s/[^ ACDEFGHIKLMNPQRSTVWY]//g;
  $seq=~s/ //g;
  my $lenseq=length($seq);

  my %AP;

  $AP{'A'}=1.064;
  $AP{'C'}=1.412;
  $AP{'D'}=0.866;
  $AP{'E'}=0.851;
  $AP{'F'}=1.091;
  $AP{'G'}=0.874;
  $AP{'H'}=1.105;
  $AP{'I'}=1.152;
  $AP{'K'}=0.930;
  $AP{'L'}=1.250;
  $AP{'M'}=0.826;
  $AP{'N'}=0.776;
  $AP{'P'}=1.064;
  $AP{'Q'}=1.015;
  $AP{'R'}=0.873;
  $AP{'S'}=1.012;
  $AP{'T'}=0.909;
  $AP{'V'}=1.383;
  $AP{'W'}=0.893;
  $AP{'Y'}=1.161;

  #STEP 2
  my $total=0;
  for ( my $n=0;$n<$lenseq;$n++) {
    my $char=substr($seq,$n,1);
    $total+=$AP{$char};	
  }
  my $aap=$total/$lenseq;

	
  my @av;
  #STEP 1
  my $ymax=0;
  my $window_width=7;
  my $firstone=int($window_width/2)+1;
  my $w=$firstone-1;
  my $negw = $w * -1;
  my $n=$firstone;
  my $lastone=$lenseq-$firstone;
  for (my $n=$firstone;$n<=$lastone;$n++) {
    my $sum=0;
    for (my $k=$negw;$k<=$w;$k++) {
      my $thispos=$n+$k;
      my $char=substr($seq,$thispos,1);
      $sum+=$AP{$char};
    }
    $av[$n]=$sum/$window_width;
    if($av[$n]>$ymax) { $ymax=$av[$n]; }
  }

  #STEP 3  
  my @par;
  if ($aap>=1.0) {
    for (my $n=$firstone;$n<=$lastone;$n++) {
      if ($av[$n]>1.0) {
	$par[$n]=1;
      } else {
	$par[$n]=0;
      }
    }
  } else {
    for (my $n=$firstone;$n<=$lastone;$n++) {
      if ($av[$n]>$aap) {
	$par[$n]=1;
      } else {
	$par[$n]=0;
      }
    }			
  }

  #STEP 4
  my $numinarow=0;
  my $nagd=0;
  my @agd;
  my @agd_start;
  my @agd_end;
  my $first1;
  my $lastn;
  for (my $n=$firstone;$n<=$lastone;$n++) {
    $agd[$n]=0;
    if ($par[$n]==1) {
      if($numinarow==0) {	$first1=$n;	}
      $numinarow++;
    } else {
      if ($numinarow>=7) {
	for(my $j=$first1;$j<$n;$j++) {
	  $agd[$j]=1;
	}
	$nagd++;
	$agd_start[$nagd]=$first1;
	$agd_end[$nagd]=$n-1;
      }
      $numinarow=0;
		}
    $lastn = $n;
  }
  if ($numinarow>=7) {
    for(my $j=$first1;$j<$lastn;$j++) {
      $agd[$j]=1;
    }
    $nagd++;
    $agd_start[$nagd]=$first1;
    $agd_end[$nagd]=$lastn;
  }		
	
  my @antigenic_determinants;

  for (my $k=1;$k<=$nagd;$k++) {
    my $ini = $agd_start[$k] -1;
    my $ter = $agd_end[$k] - $ini;
    my $pep = substr($seq, $ini, $ter);
    push @antigenic_determinants, [ $agd_start[$k], $pep, $agd_end[$k] ];
  }
  return \@antigenic_determinants;
}

sub is_uniprot_accession {
  my $self = shift;
  my %args = @_;
  return 0 unless $args{accession};
  if ( $args{accession} =~ /^[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}/ ) {
    return 1;
  }
  return 0;
}

sub fetchResultHTMLTable{
  my $self = shift;
  my %args = @_;
  my $table_name = $args{'table_name'} || die "parameter table_name missing";
  my $key_value = $args{key_value} || die "parameter key_value missing";
  my $sbeams = $self->getSBEAMS();

  $resultset_ref = $args{'resultset_ref'};

  if ( $args{use_caching} ) {
    my $rs_sql = qq~
		SELECT cache_descriptor
		FROM $TB_CACHED_RESULTSET
		WHERE table_name = '$table_name'
                AND key_value = '$key_value'
		~;
    my $cache_descriptor;
    my $stmt_handle = $sbeams->get_statement_handle( $rs_sql );
    while ( my @row = $stmt_handle->fetchrow_array() ) {
      $cache_descriptor = $row[0];
      last;
    }
    if ( $cache_descriptor ) {
      my %params;
      $log->info( "using cached resultset $cache_descriptor" );
      my $status = $sbeams->readResultSet( resultset_file=>$cache_descriptor,
					   resultset_ref => $resultset_ref,
					   query_parameters_ref => \%params );
      if ($status){
        $resultset_ref->{from_cache}++;
        $resultset_ref->{cache_descriptor} = $cache_descriptor;
        return;
      } else {
	my $clear_cache_sql = qq~
		     DELETE FROM $TB_CACHED_RESULTSET WHERE table_name = '$table_name' and key_value = '$key_value' 
			~;
	$sbeams->do( $clear_cache_sql );
	$log->info( "Cleaned up problem cache" );
	$self->fetchResultHTMLTable( %args, use_caching => 0 );
	return;
      }
    }
  }
}

sub get_current_timestamp{
  my $self = shift;
  use POSIX; 
  my $time = strftime "%Y-%m-%d %H:%M:%S", localtime time;
  return $time;
}

sub get_build_organism {
  my $self = shift;
  my %args = @_;
  my $atlas_build_id = $args{atlas_build_id} || die "need atlas_build_id\n";
  my $sbeams = $self->getSBEAMS();

  my $sql = qq~
             SELECT O.organism_name, O.organism_id
             FROM $TBAT_ATLAS_BUILD AB
             JOIN $TBAT_BIOSEQUENCE_SET BS ON (AB.biosequence_set_id = BS.biosequence_set_id)
             JOIN $TB_ORGANISM O on (BS.organism_id = O.organism_id)
             WHERE AB.atlas_build_id = $atlas_build_id 

   ~;;
  my @row = $sbeams->selectSeveralColumns($sql);
  if (! @row){
    die "cannot find organism id for build=$atlas_build_id\n";
  }
  return @{$row[0]};
}

####################################################
####################################################
sub get_alignment_display {
  my $self = shift;
  my %args = @_;
  # Content scalar to return
  my $sbeams = $self->getSBEAMS();

  my $curr_bid = $args{atlas_build_id}; 
  my $bioseq_strain = $args{bioseq_strain} || {};
  my $order_by = $args{order_by} || '';
  my $sample_category_contraint = $args{sample_category_contraint} ||  '';  
  my $clustal_display = '';
  my $bioseq_clause = '';
  my $warningstr='';

  $clustal_display .= "<form method='post' name='compareProteins'>\n";
  for my $arg ( keys( %args ) ) {
    next if $arg =~ /atlas_build_id/;
    $clustal_display .= "<input type='hidden' name='$arg' value='$args{$arg}'>\n";
  }
  $clustal_display .= "</form>";

  if ( $args{protein_list} ) {
    $args{protein_list} =~ s/;/,/g;
    my $list_ids = $self->getBioseqIDsFromProteinList( protein_list => $args{protein_list}, build_id => $curr_bid );
    $args{bioseq_id} = ( !$args{bioseq_id} ) ? $list_ids : ( $list_ids ) ? $args{bioseq_id} . ',' . $list_ids : $args{bioseq_id};
  }

  if ( $args{restore} ) {
    $args{bioseq_id} = $args{orig_bioseq_id};
  }
  if ( $args{protein_group_number} ) {
    my $excl = '';
    if ( $args{exclude_ipi} ) {
      $excl .= "AND biosequence_name NOT LIKE 'IPI%'\n";
    }
    if ( $args{exclude_ens} ) {
      $excl .= "AND biosequence_name NOT LIKE 'ENS%'\n";
    }

    my $sql = qq~
      (
        SELECT PID.biosequence_id, BS.biosequence_name
        FROM $TBAT_PROTEIN_IDENTIFICATION PID
        JOIN $TBAT_ATLAS_BUILD AB
        ON (AB.atlas_build_id = PID.atlas_build_id)
        JOIN $TBAT_BIOSEQUENCE BS
        ON (BS.biosequence_id = PID.biosequence_id)
        where AB.atlas_build_id ='$curr_bid' AND
        PID.protein_group_number = '$args{protein_group_number}'
        $excl
      ) UNION (
        SELECT BR.related_biosequence_id, BS.biosequence_name
        FROM $TBAT_BIOSEQUENCE_RELATIONSHIP BR
        JOIN $TBAT_ATLAS_BUILD AB
        ON (AB.atlas_build_id = BR.atlas_build_id)
        JOIN $TBAT_BIOSEQUENCE BS
        ON (BS.biosequence_id = BR.related_biosequence_id)
        where AB.atlas_build_id ='$curr_bid' AND
        BR.protein_group_number = '$args{protein_group_number}'
        $excl
      )
      ~;

    my @results = $sbeams->selectSeveralColumns($sql);
    my %proteins;
    # make a hash of biosequence_id to biosequence_name
    if (@results > 100 ){
      $warningstr = $sbeams->makeErrorText( "More than 100 proteins to align (build $curr_bid, protein group $args{protein_group_number}). Truncated the list to 100 proteins.");
      $warningstr .= "<br><br>";
      @results = (@results)[1..99];
    }

    for my $result_aref (@results) {
      $proteins{$result_aref->[0]} = $result_aref->[1];
    }
    my @bioseq_ids = keys %proteins;

    # Filter to include only Swiss-Prot IDs if requested.
    my @swiss_prot_ids = ();
    if ( $args{swiss_prot_only} ) {
      my $prot_info = new SBEAMS::PeptideAtlas::ProtInfo;
      $prot_info->setSBEAMS($sbeams);
      my $swiss_bsids_aref = $prot_info->filter_swiss_prot(
        atlas_build_id => $curr_bid,
        protid_aref => \@bioseq_ids,
    );
      @bioseq_ids = @{$swiss_bsids_aref};
    }

    # Add to whatever additional bioseq_ids (if any) were specified in parameters.
    $clustal_display .= "<b>Highlighting evidence for $proteins{$args{bioseq_id}} , peps $args{pepseq}</b><br>\n" if $args{eval_prot_evidence};
    $args{bioseq_id} .= ',' if ($args{bioseq_id} && @bioseq_ids);
    $args{bioseq_id} .= join( ",", @bioseq_ids);
    #print "<br>bioseq_id = |$args{bioseq_id}|<br>\n";
    my @ids = split (",", $args{bioseq_id});
    @bioseq_ids = (@bioseq_ids, @ids);

    my $n_ids = scalar @bioseq_ids;
    if ( $n_ids < 2 ) {
      # if ( !$args{bioseq_id} ) {
      my $errstr = $sbeams->makeErrorText( "Fewer than 2 proteins to align (build $curr_bid, protein group $args{protein_group_number})");
      return ( "$errstr <br><br>  $clustal_display" );
    }
    $log->debug( "Ran protein group query:" .time() );

  } elsif ( $args{protein_list_id} && $args{key_accession} ) {
    my $sql = qq~
    SELECT DISTINCT biosequence_id
      FROM $TBAT_ATLAS_BUILD AB
      JOIN $TBAT_BIOSEQUENCE B
        ON B.biosequence_set_id = AB.biosequence_set_id
      JOIN $TBAT_PROTEIN_LIST_PROTEIN PLP
        ON B.biosequence_name = PLP.protein_name
      JOIN $TBAT_PROTEIN_LIST PL
        ON PL.protein_list_id = PLP.protein_list_id
      WHERE atlas_build_id = $curr_bid
      AND PL.protein_list_id = $args{protein_list_id}
      AND key_accession = '$args{key_accession}'
    ~;

    my $sth = $sbeams->get_statement_handle( $sql );
    my @bioseq_ids;
    while ( my @row = $sth->fetchrow_array() ) {
      push @bioseq_ids, $row[0];
    }
    $args{bioseq_id} = join( ",", @bioseq_ids);
  }

  $log->debug( "Ran bioseq query:" .time() );
  if ( $args{protein_list} ) {
    $args{protein_list} =~ s/;/,/g;
    my $list_ids = $self->getBioseqIDsFromProteinList( protein_list => $args{protein_list}, build_id => $curr_bid );
    $args{bioseq_id} = ( !$args{bioseq_id} ) ? $list_ids :
  ( $list_ids ) ? $args{bioseq_id} . ',' . $list_ids : $args{bioseq_id};
    $log->debug( "Ran bioseq_id query:" .time() );
  }
 
	my @bioseq_ids = uniq split (",", $args{bioseq_id});
  my $n_ids = scalar @bioseq_ids;
  if ( $n_ids < 2 ) {
      my $errstr = $sbeams->makeErrorText( "Fewer than 2 proteins to align (build $curr_bid, 
                                            protein group $args{protein_group_number})");
      return ( "$errstr <br><br>  $clustal_display" );
  }

  # Define color mapping for various features.
  my %colors = %{$self->get_color_def()}; 

  $clustal_display .= qq~
	<script>document.title = 'PeptideAtlas: Compare Protein Sequences';</script>
  $warningstr
	<a title="show/hide help" onclick="if(document.getElementById('pageinfo').style.display == 'none') document.getElementById('pageinfo').style.display = ''; else document.getElementById('pageinfo').style.display = 'none';" href="#">Page Info and Legend</a>
	<div id="pageinfo" style="margin-left:5px;padding-left:5px;border:1px solid #666;max-width:90%;background:#f1f1f1;display: none;">
	<p>In the <b>Peptide Mapping</b> section below, peptides for each protein are represented by 
  <span style="background:$colors{uniq_tryptic};">teal</span>, 
  <span style="background:$colors{uniq_non_tryptic};">mauve</span>, 
  <span style="background:$colors{multi_tryptic};">red</span>, 
  <span style="background:$colors{multi_non_tryptic};">orange</span>, 
  and <span style="background:springgreen;">green</span> rectangles as defined in the <b>Legend</b>. 

	<p>Red superscript letters <sup><span style='color:red;'>ABCD...</span></sup> after the protein identifiers denote groups of protein entries that are identical in sequence (All the proteins with <span style='color:red;'>A</span> are identical in sequence, etc.)</p><br>

	<p>The <b>Sequence Coverage</b> section below, all relevant proteins are aligned with <a target="_new" href="https://mafft.cbrc.jp/alignment/software/">MAFFT</a> and all detected peptides are displayed in colors. In the <b>consensus</b> (bottom) row, a * indicates identity across all sequences. <br>Other symbols denote varying degrees of similarity. The controls in and below the Sequence Coverage section may be used to adjust the list of proteins displayed.</p>
		<b>Legend</b><br>
		Sequence highlighted with blue: <span class="obs_seq_bg_font">PEPTIDE</span> denotes peptides <b>observed</b> in specified build. 
		Sequence highlighted with green: <span class="sec_obs_seq_bg_font">PEPTIDE</span> denotes '<b>bait</b>' peptide for this set of sequences.<br>

		Peptide highlighted with <span style="background:$colors{uniq_tryptic};">teal</span> denotes a 
		<b>uniquely-mapping</b> and <b>tryptic</b> peptide within this set of sequences.</br>

		Peptide highlighted with <span style="background:$colors{uniq_non_tryptic};">mauve</span> denotes a 
		<b>uniquely-mapping</b> and <b>non-tryptic</b> peptide within this set of sequences.</br>

		Peptide highlighted with <span style="background:$colors{multi_tryptic};">red</span> denotes a 
		<b>multi-mapping</b> and <b>tryptic</b> peptide within this set of sequences.</br>

		Peptide highlighted with <span style="background:$colors{multi_non_tryptic};">orange</span> denotes a 
		<b>multi-mapping</b> and <b>non-tryptic</b> peptide within this set of sequences.</br>


	</div>
   ~;


  if ( $args{bioseq_id} ) {
    $bioseq_clause = "AND BS.biosequence_id IN ( $args{bioseq_id} )\n";
  }

  return 'Problem with form data: no biosequences found' unless $bioseq_clause;

  # SQL to fetch bioseqs in them.
  my $sql =<<"  END_SQL";
  SELECT biosequence_name,
  ORG.organism_name, 
  'search_key_name',
  CAST( biosequence_seq AS VARCHAR(max) ),
  biosequence_id,
  LEN( CAST(biosequence_seq AS VARCHAR(max) ) ),
  biosequence_desc
  FROM $TBAT_ATLAS_BUILD AB 
	JOIN $TBAT_BIOSEQUENCE_SET BSS ON AB.biosequence_set_id = BSS.biosequence_set_id
	JOIN $TBAT_BIOSEQUENCE BS ON BSS.biosequence_set_id = BS.biosequence_set_id
  JOIN $TB_ORGANISM ORG ON BSS.organism_id = ORG.organism_id
  WHERE AB.atlas_build_id IN ( $curr_bid )
  $bioseq_clause
  ORDER BY LEN(CAST(biosequence_seq AS VARCHAR(4000) ) ) DESC, CAST(biosequence_seq AS VARCHAR(4000)), biosequence_name DESC
  END_SQL

  my @rows  = $sbeams->selectSeveralColumns( $sql );
  $log->debug( "got big query stmt handle:" .time() );

  my %result =(); 
  foreach my $row(@rows){
    my $bioseq_id = $row->[4];
    $result{$bioseq_id} = $row;
  }
  @rows=();
  foreach my $bioseq_id(@bioseq_ids){
    push @rows, $result{$bioseq_id};
  } 

  # hash of biosequence_ids -> seq or name
  my %bioseq_id2seq;
  my %bioseq_id2name;

  # hash seq <=> accession
  my %seq2acc;
  my %acc2seq;

  # Store acc -> bioseq_id
  my %acc2bioseq_id;

#  # Store organism for each biosequence set
#	my %bss2org;

  # Counter
  my $cnt = 0;

  # array of protein info
  my @all_proteins;
  my %peptide_map;
  $peptide_map{'peptide_list'} = '';
  $peptide_map{'protein_list'} = '';
  my %coverage;
  my $fasta = '';
  my $peptide = $args{pepseq} || 'ZORROFEELTHESTINGOFHISBLADE';

# 0 SELECT DISTINCT biosequence_name,
#	1	organism_name,
#	2	'search_key_name',
#	3	CAST( biosequence_seq AS VARCHAR(4000) ),
#	4	biosequence_id
#	5 biosequence_desc
  my %seen;
  my @seqs;
  $log->debug( "loopin:" .time() );
  my %seqtype = ( decoy => 0, fwd => 0 );
  my %peptide_list_all =();
  foreach my $row (@rows){
    my @row = @$row;
    my $acc = $row[0];
    #$acc = $acc.'_'. $bioseq_strain->{$row[4]} if ($bioseq_strain->{$row[4]});
    if ( $acc =~ /^DECOY/ ) {
      $seqtype{decoy}++;
    } else {
      $seqtype{fwd}++;
    }

    my $seq = $row[3];
    my $seq_desc = $row[5];

    next if $seen{$acc};
    $seen{$acc}++;
    $seq =~ s/[\r\n]//g;

    push @seqs, $seq;

    $log->debug( "Get build coverage " .time() );
    my $peptide_list = $self->get_protein_build_coverage( build_id => $curr_bid,
																													 biosequence_ids => $row[4],
																													sample_category_contraint => $sample_category_contraint);
    
    $peptide_map{'protein_list'} .= $acc.' '; # preserves order
    my @mapped_peptides = ();
    for my $pos(keys %{$peptide_list}){
      foreach my $pep (keys %{$peptide_list->{$pos}}) {
        foreach my $id (keys %{$peptide_list->{$pos}{$pep}}){
          #print "id=$id pep=$pep pos=$pos $peptide_list->{$pos}{$pep}{$id}<BR>";
					$peptide_list_all{$pos}{$pep}{$acc}{nobs}= $peptide_list->{$pos}{$pep}{$id}{nobs};
          $peptide_list_all{$pos}{$pep}{$acc}{pre}= $peptide_list->{$pos}{$pep}{$id}{pre};
        }
        push @mapped_peptides, $pep;
      }
    }

    $log->debug( "Done.  Now get coverage hash " .time() );
    $coverage{$acc} = $self->get_coverage_hash(seq => $seq,         
						    peptides => \@mapped_peptides); 
 
    $log->debug( "Done " .time() );
    # Check this out later for dups...
    $seq2acc{$seq} ||= {};
    $seq2acc{$seq}->{$acc}++;

    $bioseq_id2seq{$row[4]} = $seq; 
    $bioseq_id2name{$row[4]} = $acc; 

    $fasta .= ">$acc\n$seq\n";

    $acc2bioseq_id{"$acc"} = $row[4];
    # Clustal W alignment file can only take 30 chars

    my $short_acc = substr( $acc, 0, 100 );
    $acc2bioseq_id{"$short_acc"} = $row[4];
    $coverage{"$short_acc"} = $coverage{$acc};
    $seq2acc{$seq}->{"$short_acc"}++;

    my $acckeys = join( ',', keys( %acc2bioseq_id ) );

    $cnt++;
  }
  $log->debug( "Iterated $cnt rows: " .time() );

  ## 
  my %processed_peptide = ();
  for my $pos(sort {$a <=> $b} keys %peptide_list_all){
    foreach my $pep (sort {$a cmp $b} keys %{$peptide_list_all{$pos}}){
      foreach my $acc (split(/ /, $peptide_map{'protein_list'})){
         next if (! $peptide_list_all{$pos}{$pep}{$acc});
				 $peptide_map{'peptide_list'} .= $pep.' ' if (! $processed_peptide{$pep}) ;# preserves order
         $processed_peptide{$pep} = 1;
         $peptide_map{$pep}{$acc}{pos} = $pos;
         $peptide_map{$pep}{$acc}{obs} = $peptide_list_all{$pos}{$pep}{$acc}{nobs};
         $peptide_map{$pep}{$acc}{tryp} = 0;
         $peptide_map{$pep}{$acc}{tryp} = 1 if ($peptide_list_all{$pos}{$pep}{$acc}{pre} =~ /[KR]/ && $pep =~ /[KR]$/);
      }
    }
  }

  # weed out duplicates - not quite working yet?
  my %dup_seqs;
  my $dup_char = 'A';
  for my $seq ( uniq @seqs ) {
    if ( scalar(keys(%{$seq2acc{"$seq"}})) > 1 ) {
      my $skip = 0;
      for my $acc ( keys ( %{$seq2acc{"$seq"}} ) ) {
        $dup_seqs{"$acc"} = $dup_char;
      }
      $dup_char++;
    } else {
      my ( $key ) = keys( %{$seq2acc{"$seq"}} );
      $dup_seqs{"$key"} = '&nbsp;';
    }
  }
 
   
  if ($order_by eq 'dup'){
     my @acc_order =(); 
     my $new_fasta='';
     foreach my $acc (sort {$dup_seqs{$a} cmp $dup_seqs{$b}} keys %dup_seqs){
       push @acc_order, $acc; 
       $new_fasta .=">$acc\n$bioseq_id2seq{$acc2bioseq_id{$acc}}\n";
     }
    $fasta = $new_fasta;
    $peptide_map{protein_list} = join(" ", @acc_order);

  }

  #$clustal_display .= $self->get_peptide_mapping_display(peptide_map => \%peptide_map,
  #                                            dup_seqs => \%dup_seqs);

  my $MSF = SBEAMS::BioLink::MSF->new();

  $log->debug( "Run alignment: " .time() );
  my $acckeys = join( ',', keys( %acc2bioseq_id ) );

  if ( $cnt > 100 ) {
    $clustal_display = $sbeams->makeErrorText( "Too many sequences to run alignment, skipping" );
  } else {
    #print "$fasta<br>";
    my $clustal = $MSF->runClustalW( sequences => $fasta );
    if ( ref $clustal ne 'ARRAY' ) {
      my $rerun_link = '';
      if ( $seqtype{decoy} && $seqtype{fwd} ) {
        my $url = $q->self_url();
        $rerun_link = qq~
&nbsp;        Try re-running clustalW <a href="$url;decoys=no">without DECOY </a> sequences?<br>
&nbsp;        Try re-running clustalW with <a href="$url;decoys=yes"> only DECOY</a> sequences?<br>
        ~;
      }
      $clustal_display = "<div style='margin:50px;'>" . $sbeams->makeErrorText( "Error running Clustal: $clustal" );
      $clustal_display .= "<br> $rerun_link</div>";
    }else {
      my $nseqs = scalar @{$clustal};
      #print "nseqs=$nseqs<br>";
      $clustal_display .= $self->get_peptide_mapping_display_graphic(peptide_map => \%peptide_map,
                                              dup_seqs => \%dup_seqs,
                                              alignments => $clustal,
                                              accessions => $peptide_map{'protein_list'},
                                              );

      $clustal_display .= $self->get_clustal_alignment_display( alignments => $clustal, 
					       dup_seqs => \%dup_seqs,
					       pepseq => $peptide,
					       coverage => \%coverage,
					       acc2bioseq_id => \%acc2bioseq_id,
                 accessions => $peptide_map{'protein_list'},
                 bioseq_strain => $bioseq_strain,
					       %args );
    }
  }
#	  $log->debug( "CompProtein, fasta is " . length( $fasta ) . ", result is " . length( $clustal_display ) );
  return $clustal_display;
}

sub get_peptide_mapping_display{
  my $self = shift;
  my %args = @_;
  my $peptide_map = $args{peptide_map} || die "need peptide_map\n";
  my $dup_seqs = $args{dup_seqs} || die "need dup_seqs\n";

  my $html = "<br><div class='hoverabletitle'>Peptide Mapping</div>";
  $html .= "<div style='width: calc(90vw - 20px); overflow-x: auto; border-right: 1px solid #aaa'>\n<table style='border-spacing:0px'>";
  for my $map_prot (split / /, $peptide_map->{'protein_list'}) {
    $html .= "<tr style='border-top: 1px solid #aaa;'>";
    $html .= "<td class='sequence_font' style='border-top: 1px solid #aaa; border-right: 1px solid #aaa; background-color:#f3f1e4; text-align: right; white-space: nowrap; position:sticky; left: 0px; z-index:6;'>$map_prot";

    if ( $dup_seqs->{$map_prot} ) {
      $html .= "<sup><span style='color:red;'>$dup_seqs->{$map_prot}</span></sup>";
    }
    $html .= "</td><td style='border-top: 1px solid #aaa; white-space: nowrap;'>";

    my $num_uniq = 0;  # might want this...?
    for my $map_pep (split / /, $peptide_map->{'peptide_list'}) {
      my $seqlen = length $map_pep;
      my $pos = '';
      my $obs = '';
      if ( $peptide_map->{$map_pep}{$map_prot}){
        $pos = $peptide_map->{$map_pep}{$map_prot}{pos};
        my $end_pos = $pos + $seqlen -1;
        $pos = "$pos-$end_pos,";
        $obs =' ('.  $peptide_map->{$map_pep}{$map_prot}{obs} . " obs)";
      }

      
      $html .= "<span title='$pos$map_pep$obs' style='width: ${seqlen}px; display: inline-block; ";
      if ($peptide_map->{$map_pep}{$map_prot}) {
				$html .= "height: 11px; background-color:";
				my $opacity = '';
				$opacity = "opacity: 0.5;" if ($peptide_map->{$map_pep}{$map_prot}{obs}< 5); 
        if ($map_pep eq $args{pepseq}) { # bait
          $html .= "springgreen;";
				}elsif (scalar keys %{$peptide_map->{$map_pep}} == 1) { # singly-mapping within this group
					#$html .=  "#ffad4e;";
					$html .=  "#ffad4e; $opacity:";
					$num_uniq++;
				}else {
					#$html .= "lightskyblue;";##d3d1c4;";
          $html .= "lightskyblue; $opacity"; 
				}
      }
      else {
        #$html .= "";
      }
      $html .= "'></span>\n";
    }
    $html .= "</td></tr>\n";
  }
  $html .= "</table></div>\n";
  return $html;

}
sub get_peptide_mapping_display_graphic{
  my $self = shift;
  my %args = @_;
  my $peptide_map = $args{peptide_map} || die "need peptide_map\n";
  my $dup_seqs = $args{dup_seqs} || die "need dup_seqs\n";
  my $alignments = $args{alignments} || die "need alignments\n";
  my $accessions = $args{accessions} || die "need accessions\n";
  my $colors = $self->get_color_def(); 

  my @accessions = split(/ /, $accessions);
  my %sequence_with_gap = ();
  my $i=0;
  my $track_len = 0;
  my %ungapped_range_list = ();

	for my $seq ( @{$args{alignments}} ) {
		my $sequence = $seq->[1];
		my $map_prot = $accessions[$i] || '';
    $sequence_with_gap{$map_prot} = $sequence;
    $track_len = length($sequence);
		my @seqss = split('', $sequence); # explode the sequence
    my @matches = grep { $seqss[$_] ~~ /[A-Z]/} 0 .. $#seqss; #get the positions of each gap character "-"
    my @range_list;
    if (@matches){
			my $s = $matches[0];
      my $e = $s;
			for (my $j=1; $j<=$#matches;$j++){
        if ($j < $#matches && $matches[$j]+1 == $matches[$j+1]){
          next;
        }else{
          if ($j < $#matches){
            push @range_list,[($s+1,$matches[$j]+1)];
            $j++;
            $s = $matches[$j];
          }else{
            push @range_list,[($s+1,$matches[$j]+1)];
          }
        }
			}
    }
    $ungapped_range_list{$map_prot} = \@range_list; 
    next if(! $map_prot);
    $i++;
  }
	my $panel = Bio::Graphics::Panel->new(-length => $track_len, 
																			 -key_style => 'between',
																			 -width     => 1000,
                                       #-grid => 1,
																			 -empty_tracks => 'suppress',
																			 -pad_top   => 5,
																			 -pad_bottom => 5,
																			 -pad_left  => 10,
																			 -pad_right => 20 );

	my $ruler = Bio::SeqFeature::Generic->new( -end => $track_len, 
																				 -start => 1);
  $panel->add_track( $ruler,
                    -glyph  => 'arrow',
                    -tick   => 2,
                    -height => 8,
                    -key  => 'Sequence Alignment and Peptide Mapping' );


  my $html = "<br>";
	my $width = ( $track_len <= 4000 ) ? 1500 : int( $track_len/5 );
  my %pep_info;
  my $cnt=1;
  $i=0;
  for my $map_prot (split / /, $peptide_map->{'protein_list'}) {
    my $sequences = $sequence_with_gap{$map_prot};
    $sequences =~ s/\-//g;
    my $track = $panel->add_track(-glyph       => 'segments',
                                  -connector   => 'dashed',
                                  -height     =>  6,
                                  -bgcolor     => 'gray',
                                  -font2color  => 'red',
                                  -key => $map_prot,
                                 );

     my $feature = Bio::SeqFeature::Generic->new(-start => 1,
                                                 -end => $track_len, 
                                                 -seq_id => $map_prot);
    foreach my $range_list(@{$ungapped_range_list{$map_prot}}){
      my ($s, $e)= @$range_list;
      my $subfeature =  Bio::SeqFeature::Generic->new(-start => $s, -end => $e);
      $feature->add_sub_SeqFeature($subfeature, "EXPAND");
    }
    $track->add_feature($feature);

    my @seqFeatures=();
    for my $map_pep (split / /, $peptide_map->{'peptide_list'}) {
      my $seqlen = length $map_pep;
      my $obs = '';
      if ( $peptide_map->{$map_pep}{$map_prot}){
        my $start_pos = $peptide_map->{$map_pep}{$map_prot}{pos};
        my $end_pos = $start_pos + $seqlen -1;
        $obs =' ('.  $peptide_map->{$map_pep}{$map_prot}{obs} . " obs)";
        my $ugly_key ="$map_prot:$map_pep" . '::::' . $start_pos . $end_pos;
				$cnt++;
        $pep_info{$ugly_key} = "$start_pos - $end_pos, $map_prot: $map_pep $obs";
        ## add gap
        my $s_start = $start_pos;
        my $s_end = $end_pos;
        my $idx=1;
        my @seg = ();
        #print "$start_pos, $end_pos => ";
        LOOP2:foreach my $range_list(@{$ungapped_range_list{$map_prot}}){
					my ($s, $e)= @$range_list;
          my $j=0;
          my $k=$idx;
          #print "($s,$e)$start_pos,";
          LOOP:for($s..$e){
            if($k==$start_pos){
              $s_start = $s+$j;
              $s_end = ($end_pos - $start_pos)+$s_start;
              if ($s_end <= $e){
                push @seg, [$s_start,$s_end];
                last LOOP2;
              }else{
                push @seg, [$s_start,$e];
                $start_pos += $e - $s_start+1;
                last LOOP;
              }
            }
            $j++;
            $k++;
          }
          $idx += $e-$s+1;
        }
 
        my $source_tag = 'multi_non_tryptic';
        my %cnt_mapping = ();
        my $dup_cnt = 1;
        foreach my $acc ( keys %{$peptide_map->{$map_pep}}){
          if ($dup_seqs->{$acc} =~ /([A-Z])/){
            $cnt_mapping{$1} = 1;
          }else{
            $cnt_mapping{$dup_cnt} =1;
            $dup_cnt++;
          }
        }
        $source_tag = 'uniq_non_tryptic' if (scalar keys %cnt_mapping == 1);

        if ($peptide_map->{$map_pep}{$map_prot}{tryp}){
          $source_tag =~ s/non_//; 
        }
        my $score = 1;
        $score = 0.5 if ($peptide_map->{$map_pep}{$map_prot}{obs} < 5);

        my $f = Bio::Graphics::Feature->new(
                             -segments => \@seg, 
                             -source   => $colors->{$source_tag},
                      -display_name    => $ugly_key,
                             -score    => $score,
                             );
         push @seqFeatures, $f;
      }
    }
		$panel->add_track( \@seqFeatures,
											-glyph       => 'graded_segments',
											-bgcolor     => sub {shift->source_tag;},
											-fgcolor     => 'black',
											-font2color  => '#882222',
											-connector   => 'dashed',
											-bump        => 1,
											-height      => 8,
											-label       => '',
											-min_score   => 0,
											-max_score   => 1
										 );
  }
  
  my $baselink = "$CGI_BASE_DIR/PeptideAtlas/GetPeptide?_tab=3&atlas_build_id=$args{build_id}&searchWithinThis=Peptide+Sequence&searchForThis=_PA_Sequence_&action=QUERY";
  my $pid = $$;
  my @objects = $panel->boxes();
  my $map = "<MAP NAME='$pid'>\n";
  for my $obj ( @objects ) {
    my $hkey_name = $obj->[0]->display_name();
    my $link_name = $hkey_name;
    $link_name =~ s/.*:(.*)::::.*/$1/g;  # Grrr...
    if ( $link_name =~ /[A-Z]/ ) { # Peptide, add link + mouseover coords/sequence
      my $coords = join( ", ", @$obj[1..4] );
      my $link = $baselink;
      $link =~ s/_PA_Sequence_/$link_name/g;
      $map .= "<AREA SHAPE='RECT' COORDS='$coords' TITLE='$pep_info{$hkey_name}' TARGET='_peptides' HREF='$link'>\n";
    } else {
      my $f = $obj->[0];
      my $coords = join( ", ", @$obj[1..4] );
      my $text = $f->start() . '-' . $f->end();
      $map .= "<AREA SHAPE='RECT' COORDS='$coords' TITLE='$text'>\n";
    }
  }
  $map .= '</MAP>';
  my $legend = '';
  my $style = '';
  my $file_name    = $pid . "_ortho_peptide_map.png";
  my $tmp_img_path = "images/tmp";
  my $img_file     = "$PHYSICAL_BASE_DIR/$tmp_img_path/$file_name";
	open( OUT, ">$img_file" ) || die "$!: $img_file";
	binmode(OUT);
	print OUT $panel->png;
	close OUT;
  my $graphic =<<"  EOG";
        <img src='$HTML_BASE_DIR/$tmp_img_path/$file_name' ISMAP USEMAP='#$pid' alt='Sorry No Img' BORDER=0>
        $map
        <br>
        <table style='border-width:1px;margin-left:40%;' class='lgnd_outline'>
        $legend
        </table>
  $style
  EOG
 
  return $html."\n".$graphic;
}


sub get_clustal_alignment_display {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my %args = ( acc_color => '#0090D0', @_ );
  my $accessions = $args{accessions} || '';
  my $bioseq_strain = $args{bioseq_strain} || {};
  my $display = qq~
	<br><br>
        <div class='hoverabletitle'>Sequence Coverage</div>
	<div style="width: calc(90vw - 20px); overflow-x: auto; border-right: 1px solid #aaa">
	<form method="POST" name="custom_alignment">
	<table style="border-spacing:1px; border:0;">
	~;

  my $position_bar_track = '';
  my $position_number_track = '&nbsp;';
  my @accessions = split(/ /, $accessions);   
  my $i=0;
  my $first = 1;
  my %first_seq_aa = (); 
  for my $seq ( @{$args{alignments}} ) {
    my $sequence = $seq->[1];
    if ($first){
      my @aas = split(//, $sequence);
      for (my $i=0;$i<=$#aas;$i++){
         $first_seq_aa{$i} =$aas[$i];
      }
      $first = 0;
    }
    my $acc = $accessions[$i] || '';
    $i++;

    if ( $seq->[0] eq 'consensus'  ) {
      my $counter = 1;
      foreach my $a (split(//, $sequence)){ 
        if ($counter % 10 == 0){
           my $space_length = 8 - (length($counter) - 2);
           $position_number_track .= '&nbsp;' x $space_length;
           $position_number_track .= $counter;
           $position_bar_track .= '|';
        }else{
           $position_bar_track .='.';
        }
        $counter++;
      } 
      $sequence =~ s/ /&nbsp;/g;
    } else {
      $sequence = $self->highlight_sites2( seq => $sequence,
                                   acc => $acc, 
                                   ref_aa => \%first_seq_aa, 
																	 coverage => $args{coverage}->{$acc} );
      my @pepseqs = split(",", $args{pepseq});
      for my $pepseq (@pepseqs) {
				$sequence =~ s/${pepseq}/<span class="sec_obs_seq_bg_font">$pepseq<\/span>/g;
      }

    }
    my $dup = '';
    if ( $args{dup_seqs}->{$acc} ) {
      $dup .= "<sup><span style='color:red;'>$args{dup_seqs}->{$acc}</span></sup>";
    }
    my $checkbox = '';
    unless ( $seq->[0] eq 'consensus' ) {
      if ( !$args{acc2bioseq_id}->{"$acc"} ) {
        $log->warn( "$seq->[0] has no bioseq_id, can't re-assemble" );
      } else {
				$checkbox = "<input id='bioseq_id' type='checkbox' checked name='bioseq_id' value='$args{acc2bioseq_id}->{$acc}'></input>";
      }
    }
    my $left_px = 'left:20px';
    my $left_px1 = 'left:20px';
    my $left_px2 = 'left:20px';
    my $max_width = 'max-width:150px;word-wrap: break-word;';
    my $style = "padding:3px; background-color: #f3f1e4; position:sticky;z-index:6";
    if ( $seq->[0] eq 'consensus') {
      $display .= qq~
			<tr>
			<td style="$style; left: 0px; "></td>
      ~;
      $display .= qq~
        <td style="$style;$left_px; $max_width;" class="sequence_font"></td>
      ~ if (%$bioseq_strain);
      $left_px = $left_px2 if (%$bioseq_strain);
      $display .= qq~
			<td style="$style; $left_px;  border-right: 1px solid #aaa; text-align: right;" class="sequence_font">consensus</td>
			<td style="padding:3px; white-space: nowrap;" class="sequence_font">$sequence</td>
			</tr>
			<tr>
			<td style="$style; left: 0px; "></td>
      ~;

      $left_px = $left_px1; 
      $display .= qq~
        <td style="$style;$left_px; $max_width;" class="sequence_font"></td>
      ~ if (%$bioseq_strain);
      $left_px = $left_px2 if (%$bioseq_strain);
      $display .= qq~
			<td style="$style;$left_px;  border-right: 1px solid #aaa; text-align: right;" class="sequence_font"></td>
			<td style="padding:3px; white-space: nowrap;" class="sequence_font">$position_bar_track</td>
			</tr>
      <tr>
      <td style="$style; left: 0px; "></td>
      ~;
 
      $left_px = $left_px1; 
      $display .= qq~
        <td style="$style;$left_px; $max_width;" class="sequence_font"></td>
      ~ if (%$bioseq_strain);
      $left_px = $left_px2 if (%$bioseq_strain);
      $display .= qq~
      <td style="$style;$left_px; border-right:1px solid #aaa;text-align: right;" class="sequence_font">position</td>
      <td style="padding:3px; white-space: nowrap;" class="sequence_font">$position_number_track</td>
      </tr>
			~;
    }else{
			$display .= qq~
			<tr>
			<td style="$style;left:0px; ">$checkbox </td>
      ~;
      $display .= qq~
       <td style="$style;$left_px; $max_width;" class="sequence_font">$bioseq_strain->{$args{acc2bioseq_id}->{$acc}}</td>
      ~ if (%$bioseq_strain);
      $left_px = $left_px2 if (%$bioseq_strain);
      $display .= qq~
			<td style="$style;$left_px;border-right:1px solid #aaa;text-align: right;" class="sequence_font">$acc$dup</td>
			<td style="padding:3px; white-space: nowrap;" class="sequence_font">$sequence</td>
			</tr>
			~;
    }
  }
  
  my $toggle_checkbox = $sbeams->get_checkbox_toggle( controller_name => 'alignment_chk',
						      checkbox_name => 'bioseq_id' );

  my $toggle_text = $sbeams->makeInfoText( 'Toggle all checkboxes' );

  # Add field to allow ad hoc addition of proteins.
  my $text = qq~
	You can add an additional protein or proteins
	to this assembly by inserting their accession
	numbers here as a semicolon-separated list.
	~;

  my $popup = qq~
	$text
    The following accession types should work:
  <br>
  <br>
	<ALIGN = RIGHT>
	Human      IPI, ENSP
  <br>
	Mouse      IPI, ENSMUS
  <br>
	Yeast      Yxxxxx
  <br>
	Halo       VNG
  <br>
	celegans   wormbase acc.
  <br>
  <br>
	</ALIGN>
	  Please note that using more sequences and/or 
	sequences that are not very similar will cause 
	the assembly to be slower.  There is a limit of 
	100 proteins in the assembly, but the practical
	limit of aligning dissimilar proteins is much 
	lower.
	~;

  my $pHTML .= $sbeams->getPopupDHTML();
  my $session_key = $sbeams->getRandomString();
  $sbeams->setSessionAttribute( key => $session_key,  value => $popup );

  my $url = "$CGI_BASE_DIR/help_popup.cgi?title=BuildProteinList;session_key=$session_key;email_link=no";

  my $link =<<"  END_LINK";
   <span title='$text - click for more...' class="popup">
   <img src="$HTML_BASE_DIR/images/greyqmark.gif" border="0" onclick="popitup('$url');"></span>
  END_LINK

  # Cache ids to be able to restore!
  my $orig_bioseq_field = '';
  if ( $args{bioseq_id} && !$args{orig_bioseq_id} ) {
    $orig_bioseq_field = "<input type='hidden' name='orig_bioseq_id' value='$args{bioseq_id}'></input>";
  } else {
    $orig_bioseq_field = "<input type='hidden' name='orig_bioseq_id' value='$args{orig_bioseq_id}'></input>";
  }
  my $self_url = $q->self_url();
  my $short_url = $sbeams->setShortURL( $self_url );

  $display .= qq~
	$pHTML
  <tr><td style="position:sticky; left: 0px;">$toggle_checkbox</td><td style="position:sticky; left: 20px; text-align:left">$toggle_text </td><td></td></tr>
	</table>\n</div>
	<br>

	Add proteins to list
	<span style='background:#e0e0e0; margin:0px 3px; padding:3px;'>$link</span>
	<input type='text' name='protein_list' size='40'>
	<br>
	<br>
	<input type='hidden' name='pepseq' value='$args{pepseq}'>
  $orig_bioseq_field
	<input type='submit' value='Align selected sequences'>
	<input type='submit' value='Restore Original' name='restore'>
	</form>
	<br><br>
  Save link to recall current <a href='$CGI_BASE_DIR/shortURL?key=$short_url'>sequence alignment</a>.
	<br><br>
	~;

  return $display;
}

sub highlight_sites2 {
  my $self = shift;
  my %args = @_;
  my $coverage = $args{coverage};
  #$log->debug( "seq is there , acc is $args{acc}, and coverage is $coverage->{$args{acc}}" );
  my $ref_aa = $args{ref_aa};
 
  #https://merenlab.org/2018/02/13/color-coding-aa-alignments/
  #https://www.jalview.org/help/html/colourSchemes/clustal.html
  my %amino_acid_colors=%{$self->get_color_def()};

#  foreach my $i (sort {$a <=>$b} keys %$ref_aa){
#    print $ref_aa->{$i};
#  }
#  print "<BR>";
#  print "$args{seq}<BR>";

  my @aas = split( '', $args{seq} );
  my $return_seq = '';
  my $cnt = 0;
  my $in_coverage = 0;
  my $span_closed = 1;
  my $i=0;
  for my $aa ( @aas ) {
    if ( $aa =~ /[\-\*]/ ) {
      if ( $in_coverage && !$span_closed ) {
				$return_seq .= "</span>$aa";
				$span_closed++;
      } else {
				$return_seq .= $aa;
      }
    } else { # it is an amino acid
      if ($ref_aa->{$i} ne $aa){
        $aa = "<font color='". $amino_acid_colors{$aa} ."'>$aa</font>"; 
      }
      if ( $coverage->{$cnt} ) {
				if ( $in_coverage ) { # already in
					if ( $span_closed ) {  # Must have been jumping a --- gap
						$span_closed = 0;
						$return_seq .= "<span class='obs_seq_bg_font'>$aa";
					} else {
						$return_seq .= $aa;
					}
				} else {
					$in_coverage++;
					$span_closed = 0;
					$return_seq .= "<span class='obs_seq_bg_font'>$aa";
				}
						} else { # posn not covered!
				if ( $in_coverage ) { # were in, close now
					$return_seq .= "</span>$aa";
					$in_coverage = 0;
					$span_closed++;
				} else {
					$return_seq .= $aa;
				}
      }
        
      $cnt++;
        
    }
    $i++;
  }
  if ( $in_coverage && !$span_closed ) {
    $return_seq .= '</span>';
  }
  return $return_seq;
}

###############################################################################
# get_atlas_build_directory  --  get atlas build directory
# @param atlas_build_id
# @return atlas_build:data_path
###############################################################################
sub get_build_data_directory
{
  my $self = shift; 
  my %args = @_;
	my $sbeams = $self->getSBEAMS();

	my $atlas_build_id = $args{atlas_build_id} or die "need atlas build id";

	my $path;

	my $sql = qq~
			SELECT data_path
			FROM $TBAT_ATLAS_BUILD
			WHERE atlas_build_id = '$atlas_build_id'
			AND record_status != 'D'
	~;

	($path) = $sbeams->selectOneColumn($sql) or
			die "\nERROR: Unable to find the data_path in atlas_build record".
			" with $sql\n\n";

	## get the global variable PeptideAtlas_PIPELINE_DIRECTORY
	my $pipeline_dir = $CONFIG_SETTING{PeptideAtlas_PIPELINE_DIRECTORY};

	$path = "$pipeline_dir/$path";

	## check that path exists
	unless ( -e $path)
	{
			die "\n Can't find path $path in file system.  Please check ".
			" the record for atlas_build with atlas_build_id=$atlas_build_id";

	}

    return $path;
}

sub match_proteome_component{
  my $self = shift;
  my %args = @_;
  my $pattern = $args{pattern} || ();
  my $source_type = $args{source_type} || ''; 
  my $biosequence_name = $args{biosequence_name} || '';
  my $biosequence_desc = $args{biosequence_desc} || '';

  if ($source_type eq '' || ! $pattern || $biosequence_name eq ''){
     return ''; 
  }
	my $matched = 0;
	my $s = '';
	if ($source_type =~ /^accession$/i){
		$s = $biosequence_name;
	}elsif($source_type =~ /^description$/i){
		$s =  $biosequence_desc;
	}elsif($source_type =~ /^AccessionDescription$/i){
		$s = "$biosequence_name $biosequence_desc"; 
	}
	foreach my $pat (@$pattern){
	 if (($source_type =~ /accession/i && $s =~ /^$pat/) ||
			($source_type !~ /accession/i && $s =~ /$pat/)){
			 $matched =1;
			last;
		}
	}
  return $matched;
} 

1;
