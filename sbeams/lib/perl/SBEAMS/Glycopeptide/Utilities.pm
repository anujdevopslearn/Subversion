package SBEAMS::Glycopeptide::Utilities;

sub new {
  my $class = shift;
  my $this = {};
  bless $this, $class;
  return $this;
}

sub match_count {
  my $self = shift;
  my %args = @_;
  return unless $args{pepseq} && $args{protseq};

  my @cnt = split( $args{pepseq}, $args{protseq}, -1 );
  return $#cnt;
}

# map_peptide_to_protein, 0-based
sub map_peptide_to_protein {
	my $self = shift;
	my %args = @_;
	my $pep_seq = $args{pepseq};
	my $protein_seq = $args{protseq};
	
	if ( $protein_seq =~ /$pep_seq/ ) {
		my $start_pos = length($`);    
		my $stop_pos = length($pep_seq) + $start_pos;  
		return ($start_pos, $stop_pos);	
	}else{
		return;
	}
}

# Returns reference to an array holding the 0-based indices of a pattern 'X'
# in the sequence
sub get_site_positions {
  my $self = shift;
  my %args = @_;
  $args{pattern} ||= 'N.[S|T]';
  return unless $args{seq};

  my @posn;
  while ( $args{seq} =~ m/$args{pattern}/g ) {
    push @posn, pos($string) - length($&) # start position of match
  }
  return \@posn;
}

sub get_current_prophet_cutoff {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my $cutoff = $sbeams->getSessionAttribute( key => 'glyco_prophet_cutoff' );
  $cutoff = 0.5 if !defined $cutoff;
  return $cutoff;
}

sub process_prophet_cutoff {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my $cutoff = $sbeams->getSessionAttribute( key => 'glyco_prophet_cutoff' );
  $cutoff = 0.5 if !defined $cutoff;
  return $cutoff;
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

  # Trim of leading/lagging amino acids
  $seq =~ s/^.\.//g;
  $seq =~ s/\..$//g;
  return $seq;
}
1;

