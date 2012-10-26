package SBEAMS::PeptideAtlas::Utilities;

use SBEAMS::Connection qw( $log );
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::PeptideMassCalculator;

use constant HYDROGEN_MASS => 1.0078;
use Storable qw( nstore retrieve );
use Bio::Graphics::Panel;

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

  if ( !grep /$enz/, qw( gluc trypsin lysc cnbr aspn ) ) {
    $log->debug( "Unknown enzyme $enz" );
    return;
  }

  # trypsin, GluC, LysC, and CNBr clip Cterminally
  my $term = 'C';

  # AspN is the outlier
  $term = 'N' if $enz eq 'aspn';

  my %regex = ( aspn => 'D',
                gluc => 'E',
                lysc => 'K',
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

  # If we get option to split on '*' peptides, do this with recursive calls
  if ( $args{split_asterisk} ) {
    my @seqs = split( /\*/, $args{aa_seq} );
    for my $seq ( @seqs ) {
      my $sub_tryp = $self->do_tryptic_digestion( %args, aa_seq => $seq, split_asterisk => 0 );
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
sub get_site_positions {
  my $self = shift;
  my %args = @_;
  $args{pattern} = 'N[^P][S|T]' if !defined $args{pattern};
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
	$log->debug( "We be sushi" );

  my $seq = $args{seq};
  $seq =~ s/[^a-zA-Z]//g;
  for my $peptide ( @{$args{peptides}}  )  {

    my $posn = $self->get_site_positions( pattern => $peptide,
                                              seq => $seq );

    for my $p ( @$posn ) {
      for ( my $i = 0; $i < length($peptide); $i++ ){
        my $covered_posn = $p + $i;
        $coverage->{$covered_posn}++;
    	}
		}
	}
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
	my $class = $args{cov_class} || 'obs_seq_font';
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
    $tags->{$input->{start}->[$i]} .= "<SPAN class=$input->{class}>";
    $tags->{$input->{end}->[$i]} .= "</SPAN>";
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
    push @posn, "\n" unless ( $cnt % 70 );
    push @values, \@posn;
  }
  push @values, ['</SPAN></PRE>'];
  my $str = '';
  for my $a ( @values ) {
    $str .= join( "", @{$a} );
  }
  return $str;
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
#      print STDERR "One-time retrieval of CE data\n";
      $self->{_SRM_CE} = retrieve( "/net/db/projects/PeptideAtlas/MRMAtlas/analysis/CE_extraction/global_values/SRM_CE.sto" );
#      print STDERR "Done\n";
    }
    my $pepion = $args{seq} . '/' . $args{charge};
#    print STDERR "looking for CE for $pepion and $args{ion}\n";
    if ( $self->{_SRM_CE}->{$pepion} &&  $self->{_SRM_CE}->{$pepion}->{$args{ion}} ) {
#      print STDERR "Found $self->{_SRM_CE}->{$pepion}->{$args{ion}}->{max_ce}\n";
      return sprintf( "%0.1f", $self->{_SRM_CE}->{$pepion}->{$args{ion}}->{max_ce} );
    }
#    print STDERR "MIA";
  }

  # calculate CE  
  my $ce;
  if ( $args{charge} == 2 || $args{charge} == 1 ) {
    $ce = ( (2.93*$args{mz})/100 ) + 6.72;
  } else {
    $ce = ( (3.6*$args{mz} )/100 ) -4.8;
    $ce = 0 if $ce < 0;
  }
#  print STDERR "Calc is $ce\n";
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
Compound Name	ISTD?	Precursor Ion	MS1 Res	Product Ion	MS2 Res	Dwell	Fragmentor	Collision Energy	Cell Accelerator Voltage	Polarity	Ion type
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
    my $seq = $line[2];
    my $q1 = $line[6];
    my $q1c = $line[7];
    my $q3 = $line[8];
    my $q3c = $line[9];
    my $lbl = $line[10];
    my $ion = $q1c . $lbl . '-' . $q3c;
    
    my $rtd = 5;
    my $name = $acc . '.' . $seq;

    my $ce_key = $seq . $q1c;
    $ce{$ce_key} ||= $self->calculate_agilent_ce( mz => $q1, charge => $q1c, empirical_ce => $opts{empirical_ce} , seq => $seq, ion => $lbl );

#    my $ce = ( $q1c == 2 ) ? sprintf( "%0.2f", ( 2.93 * $q1 )/100 + 6.72 ) : 
#				                     sprintf( "%0.2f", ( 3.6 * $q1 )/100 - 4.8 );

    my $istd = 'False';
    $istd = 'True'  if $seq =~ /6\]$/;

    $method .= join( "\t", $name, $istd, $q1, $w, $q3, $u, $d, $f, $ce{$ce_key}, $v, $p, $ion ) . "\n";
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

  my @headings = ( 'Compound Name', 'ISTD?', 'Precursor Ion', 'MS1 Res', 'Product Ion', 'MS2 Res', 'Fragmentor', 'Collision Energy', 'Cell Accelerator Voltage', 'Ret Time (min)', 'Delta Ret Time', 'Polarity', 'Ion type' );
  
  if ( $opts{calc_rt} ) {
    push @headings, 'EstimatedRT';
  }
  $method .= join( "\t", @headings ) . "\n";

  my $u = 'Unit';
  my $p = 'Positive';

  my %ce;

	for my $row ( @{$tsv} ) {
		my @line = @{$row};
    next if $line[0] eq 'Protein';
    my $acc = $line[0];
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

    my $name = $acc . '.' . $seq;

    my $ce_key = $seq . $q1c;
#    $ce{$ce_key} ||= $self->calculate_agilent_ce( mz => $q1, charge => $q1c );
    $ce{$ce_key} ||= $self->calculate_agilent_ce( mz => $q1, charge => $q1c, empirical_ce => $opts{empirical_ce} , seq => $seq, ion => $lbl );

#    my $ce = ( $q1c == 2 ) ? sprintf( "%0.2f", ( 2.93 * $q1 )/100 + 6.72 ) : 
#				                     sprintf( "%0.2f", ( 3.6 * $q1 )/100 - 4.8 );


    my $est_rt = sprintf( "%0.1f", ($line[13]*72.94461-122.83351)/60);
    my $istd = 'False';
    $istd = 'True' if $seq =~ /6\]$/;
    my @rowdata = ( $name, $istd, $q1, $u, $q3, $u, 125, $ce{$ce_key}, 5, $rt, $rtd, $p, $ion );
    if ( $opts{calc_rt} ) {
      push @rowdata, $est_rt;
    }
    $method .= join( "\t", @rowdata ) . "\n";
	}
  return $method;
}

sub get_qtrap_mrmmsms_method {

  my $self = shift;
  my $tsv = shift || return '';

  my $sep = "\t";
  $sep = ",";

  my $method = join($sep, qw(Q1 Q3 Dwell peptide.protein.Cso CE)) . "\r\n";
  
	my $dwell = 10;
  my %ce = {};
	for my $row ( @{$tsv} ) {
		my @line = @{$row};
    next if $line[0] eq 'Protein';

    my $acc = $line[0];
    my $seq = $line[2];
    my $q1 = $line[6];
    my $q1c = $line[7];
    my $q3 = $line[8];
    my $q3c = $line[9];
    my $lbl = $line[10];
    my $label = $seq . '.' . $acc . '.' . $q1c . $lbl . $q3; 
		$label .= '-' . $q3c if $q3c > 1;

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

  my $method = join($sep, qw(Q1 Q3 RT peptide.protein.Cso CE)) . "\r\n";

  my %ce = {};
	for my $row ( @{$tsv} ) {
		my @line = @{$row};
    next if $line[0] eq 'Protein';

    my $acc = $line[0];
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
		$label .= '-' . $q3c if $q3c > 1;
    $method .= join($sep, $q1, $q3, $rt, $label, $ce{$ce_key} ) . "\r\n";
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
# from ShowOneSpectrum cgi.
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
      $arrow = '&darr;';
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

1;


