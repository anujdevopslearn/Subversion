package SBEAMS::BioLink::Utilities;

use SBEAMS::Connection qw($log);
use SBEAMS::BioLink::Tables;

use Bio::Graphics::Panel;
use Bio::SeqFeature::Generic;

sub new {
  my $class = shift;
  my $this = {};
  bless $this, $class;
  return $this;
}

sub get_leaf_annotations {
  my $self = shift;
  my %args = @_;

  return undef unless $args{annotated_gene_id};

  # Default annotation types
  my $types = "'C', 'F', 'P'";

  # Or user-defined types
  if ( defined $args{types_codes} && ref $args{type_codes} eq 'ARRAY' ) {
    return undef unless scalar( @$args{type_codes} );
    $types = "'" . join( "','", @$args{type_codes} ) . "'";
  }

  my $sql = qq~
  SELECT DISTINCT annotation, GAT.gene_annotation_type_code, is_summary 
  FROM $TBBL_ANNOTATED_GENE AG 
  JOIN $TBBL_GENE_ANNOTATION GA 
  ON GA.annotated_gene_id = AG.annotated_gene_id 
  JOIN $TBBL_GENE_ANNOTATION_TYPE GAT 
  ON GAT.gene_annotation_type_id = GA.gene_annotation_type_id 
  WHERE GA.annotated_gene_id = $args{annotated_gene_id}
  AND hierarchy_level = 'leaf'
  AND GAT.gene_annotation_type_code IN ( $types )
  ORDER BY GAT.gene_annotation_type_code ASC, is_summary DESC
  ~;

  my $sbeams = $self->getSBEAMS();
  my @all_annot = $sbeams->selectSeveralColumns( $sql => $sql );

  my %annot;
  for my $annot ( @all_annot ) {
    # Is this summary (primary) annotation or additional (secondary)?
    my $key = ( $annot->[2] =~ /^Y$/i ) ? $annot->[1] . 'pri' : 
                                          $annot->[1] . 'sec';

    my $delim = ( $annot{$key} ) ? '; ' : '';
    $annot{$key} .= "$delim $annot->[0]";
  }
  return \%annot;
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
  #Extracellular1-186m187-207Cytoplasmic208-670
  #m9-29m60-80m97-117m127-147m157-177m182-202m203-223
  #

  if ($string!~ /\d[oi]$/){
    while ( $string =~ m/(\D+)(\d+)\-(\d+)/g ) { 
      my $side = $1;
      my $beg = $2;
      my $end = $3;
      if ($side =~ /^m$/){
        $side = 'tm';
      }

      push @tminfo, [$side,$beg,$end];
    }
  }else{
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
  }
  return \@tminfo;
}


#+
# Returns hashref of one-letter code => amino acid mass data
# Defaults to average mass, can specify mass_type => monoisotopic
#-
sub get_amino_acid_masses {
  my $self = shift;
  my %args = @_;
  $args{mass_type} ||= 'average';

  #### Define the residue masses
  my %masses;

  if ( $args{mass_type} =~ /monoisotopic/i ) {
    %masses = ( G => 57.021464,
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
    
                        X => 118.8057,   # Unknown, avg of 20 common AA.
                        B => 114.5349,   # avg N and D
                        Z => 128.5506,   # avg Q and E
    );
  } else {
    %masses = ( I => 113.1594,   # Isoleucine
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
                        E => 129.1155,   # Glutamic_Acid (Glutamate)
                        Q => 128.1307,   # Glutamine
                        D => 115.0886,   # Aspartic_Acid (Aspartate)
                        N => 114.1038,   # Asparagine
                        K => 128.1741,   # Lysine
                        R => 156.1875,   # Arginine

                        X => 113.1594,   # L or I
                        B => 114.5962,   # avg N and D
                        Z => 128.6231,   # avg Q and E
                        U => 100,        # Selenocysteine!

                      );
  }
  return \%masses;
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




1;
