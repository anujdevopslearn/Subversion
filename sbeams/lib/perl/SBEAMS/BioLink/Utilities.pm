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




1;
