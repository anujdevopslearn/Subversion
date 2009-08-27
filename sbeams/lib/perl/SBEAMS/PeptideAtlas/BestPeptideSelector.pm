package SBEAMS::PeptideAtlas::BestPeptideSelector;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::BestPeptideSelector
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::BestPeptideSelector

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::BestPeptideSelector

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
things related to finding the best peptides to use for some other application

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;

use Data::Dumper;
use Digest::MD5 qw(md5_hex);


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams $atlas);


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $VERBOSE = 0;
    $TESTONLY = 0;
    return($self);
} # end new


###############################################################################
# setSBEAMS: Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
} # end setSBEAMS

###############################################################################
# setAtlas: Receive peptide atlas object 
###############################################################################
sub setAtlas {
    my $self = shift;
    $atlas = shift;
    return($atlas);
} # end setAtlas



###############################################################################
# getSBEAMS: Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS



###############################################################################
# setTESTONLY: Set the current test mode
###############################################################################
sub setTESTONLY {
    my $self = shift;
    $TESTONLY = shift;
    return($TESTONLY);
} # end setTESTONLY



###############################################################################
# setVERBOSE: Set the verbosity level
###############################################################################
sub setVERBOSE {
    my $self = shift;
    $VERBOSE = shift;
    return($TESTONLY);
} # end setVERBOSE



###############################################################################
# getBestPeptides -- Selects the best piptides from some application
#
# @narg resultset_ref   Reference to resultset, needs to have the following 
#                       columns defined:
#                       n_observations
#                       empirical_proteotypic_score
#                       best_probability
#                       n_protein_mappings
#                       n_genome_locations
#                       preceding_residue
#                       following_residue
#                       peptide_sequence
#                       suitability_score
# The suitability score is just a placeholder column, and will be replaced with
# the computed value
#
# The routine also expects to get all the peptides for a given biosequence, and
# only peptides for that biosequence!
#
###############################################################################
sub getBestPeptides {
  my $METHOD = 'getBestPeptides';
  my $self = shift || die ("self not passed");
  my %args = @_;

  # Validate parameters
  my $resultset_ref = $args{resultset_ref}
    or die("ERROR[$METHOD]: Parameter resultset_ref not passed");

  $args{ss_adjust} ||= 1;

  my $n_rows = scalar(@{$resultset_ref->{data_ref}});
  my $cols = $resultset_ref->{column_hash_ref};

  #### Loop over all rows, calculating some max stats of certain columns
  my $max_n_observations = 0;
  my $max_empirical_observability_score = 0;
  for (my $i=0; $i<$n_rows; $i++) {
    my $n_observations = $resultset_ref->{data_ref}->[$i]->[$cols->{n_observations}];
    if ($n_observations > $max_n_observations) {
      $max_n_observations = $n_observations;
    }

    my $empirical_observability_score = $resultset_ref->{data_ref}->[$i]->[$cols->{empirical_proteotypic_score}];
    if ($empirical_observability_score > $max_empirical_observability_score) {
      $max_empirical_observability_score = $empirical_observability_score;
    }

  }

  #### Loop over all rows, calculating a suitability score
  for (my $i=0; $i<$n_rows; $i++) {
    my $n_observations = $resultset_ref->{data_ref}->[$i]->[$cols->{n_observations}];
    my $best_probability = $resultset_ref->{data_ref}->[$i]->[$cols->{best_probability}];
    my $n_protein_mappings = $resultset_ref->{data_ref}->[$i]->[$cols->{n_protein_mappings}];
    my $n_genome_locations = $resultset_ref->{data_ref}->[$i]->[$cols->{n_genome_locations}];
    my $empirical_observability_score = $resultset_ref->{data_ref}->[$i]->[$cols->{empirical_proteotypic_score}];
    my $preceding_residue = $resultset_ref->{data_ref}->[$i]->[$cols->{preceding_residue}];
    my $following_residue = $resultset_ref->{data_ref}->[$i]->[$cols->{following_residue}];
    my $peptide_sequence = $resultset_ref->{data_ref}->[$i]->[$cols->{peptide_sequence}];

    my @annot; # array of sequence annotations

    # removed p=1.0 fudge factor 2008-11-04 as per EWD.
    # $best_probability += 0.03 if ($best_probability == 1.000);
    my $empirical_observability_fraction = 0;
    my $divisor = 3;

    if ($max_empirical_observability_score == 0) {
      $divisor = 2;
    } else {
      $empirical_observability_fraction = 
	$empirical_observability_score / $max_empirical_observability_score;
    }

    my $suitability_score = (
      $n_observations / $max_n_observations +
      ( $best_probability - 0.9 ) / 0.1 +
      $empirical_observability_fraction
    ) / $divisor;
    $suitability_score *= $args{ss_adjust};

    if ($n_protein_mappings > 1) {
      if ($n_genome_locations > 1) {
        $suitability_score *= 0.1;
        push @annot, 'MGL';
      }
    }

    ## Penalty if not fully tryptic
    unless ($preceding_residue =~ /[KR\-]/ && 
             ($peptide_sequence =~ /[KR]$/ || $following_residue eq '-') 
					 ) {
      $suitability_score *= 0.2;
      push @annot, 'ST';
    }

    ## Penalty if missed cleavages
#    if (substr($peptide_sequence,0,length($peptide_sequence)) =~ /([KR][^P])/) {
    if ( $peptide_sequence =~ /([KR][^P])/) {
      $suitability_score *= 0.67;
      push @annot, 'MC';
		}

    if ( $args{build_weight} ) {
      my $build_id = $resultset_ref->{data_ref}->[$i]->[$cols->{atlas_build}];
      $suitability_score *= $args{build_weight}->{$build_id};
    }

    $resultset_ref->{data_ref}->[$i]->[$cols->{suitability_score}] =
      sprintf("%.2f",$suitability_score);

    if ( $args{annotate} ) {
#      print STDERR "joining annotations to " . join( ',', @annot ) . "\n";
#      $log->debug( "joining annotations to " . join( ',', @annot ) );
      $resultset_ref->{data_ref}->[$i]->[$cols->{annotations}] .= join( ',', @annot );
    }
  }


  $self->sortBySuitabilityScore( $resultset_ref );

  return $resultset_ref;

} # end getBestPeptides


###############################################################################
# getBestPeptidesDisplay -- Selects the best piptides from some application
###############################################################################
sub getBestPeptidesDisplay {
  my $METHOD = 'getBestPeptidesDisplay';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $best_peptide_information = $args{best_peptide_information}
    or die("ERROR[$METHOD]: Parameter best_peptide_information not passed");

  my $query_parameters_ref = $args{query_parameters_ref}
    or die("ERROR[$METHOD]: Parameter query_parameters_ref not passed");

  my $column_titles_ref = $args{column_titles_ref}
    or die("ERROR[$METHOD]: Parameter column_titles_ref not passed");

  my $base_url = $args{base_url}
    or die("ERROR[$METHOD]: Parameter base_url not passed");


  my $resultset_ref = $best_peptide_information;

  #### Define the hypertext links for columns that need them
  my %url_cols = (
    	       'Peptide Accession' => "$CGI_BASE_DIR/PeptideAtlas/GetPeptide?_tab=3&atlas_build_id=$atlas_build_id&searchWithinThis=Peptide+Name&searchForThis=%V&action=QUERY",
  );

  my %hidden_cols;

  $sbeams->displayResultSet(
      resultset_ref=>$resultset_ref,
      query_parameters_ref=>$query_parameters_ref,
      #rs_params_ref=>\%rs_params,
      url_cols_ref=>\%url_cols,
      hidden_cols_ref=>\%hidden_cols,
      #max_widths=>\%max_widths,
      column_titles_ref=>$column_titles_ref,
      base_url=>$base_url,
  );

  return 1;

} # end getBestPeptidesDisplay



###############################################################################
# getHighlyObservablePeptides -- Selects the best piptides from some application
###############################################################################
sub getHighlyObservablePeptides {
  my $METHOD = 'getHighlyObservablePeptides';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $biosequence_id = $args{biosequence_id}
    or die("ERROR[$METHOD]: Parameter biosequence_id not passed");


  #### Define the desired columns in the query
  #### [friendly name used in url_cols,SQL,displayed column title]
  my @column_array = (
    ["peptide_accession","P.peptide_accession","Peptide Accession"],
    ["preceding_residue","PTP.preceding_residue","Pre AA"],
    ["peptide_sequence","PTP.peptide_sequence","Peptide Sequence"],
    ["following_residue","PTP.following_residue","Fol AA"],
    ["suitability_score","(PTP.detectabilitypredictor_score+PTP.peptidesieve_ESI)/2","Suitability Score"],
    ["detectabilitypredictor_score","PTP.detectabilitypredictor_score","Detectability Predictor Score"],
    ["peptidesieve_score","PTP.peptidesieve_ESI","PeptideSieve Score"],
    #["parag_score_ESI","PTP.parag_score_ESI","PM ESI"],
    #["parag_score_ICAT","PTP.parag_score_ICAT","PM ICAT"],
  );
  my %colnameidx = ();
  my @column_titles = ();
  my $columns_clause = $sbeams->build_SQL_columns_list(
    column_array_ref=>\@column_array,
    colnameidx_ref=>\%colnameidx,
    column_titles_ref=>\@column_titles
  );

  #### Define a query to return peptides for this protein
  my $sql = qq~
     SELECT $columns_clause
     FROM $TBAT_PROTEOTYPIC_PEPTIDE PTP
     LEFT JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PTPM
          ON ( PTP.proteotypic_peptide_id = PTPM.proteotypic_peptide_id )
     LEFT JOIN $TBAT_PEPTIDE P
          ON ( PTP.matched_peptide_id = P.peptide_id )
     LEFT JOIN $TBAT_BIOSEQUENCE BS
          ON ( PTPM.source_biosequence_id = BS.biosequence_id )
     LEFT JOIN $TBAT_DBXREF DBX ON ( BS.dbxref_id = DBX.dbxref_id )
    WHERE 1 = 1
	  AND PTPM.source_biosequence_id = $biosequence_id
          AND ( (PTP.detectabilitypredictor_score+peptidesieve_ESI) >= 1 OR peptide_accession IS NOT NULL )
    ORDER BY PTP.detectabilitypredictor_score+PTP.peptidesieve_ESI DESC
  ~;

  #### Fetch the results from the database server
  my %resultset = ();
  my $resultset_ref = \%resultset;
  $sbeams->fetchResultSet(
    sql_query=>$sql,
    resultset_ref=>$resultset_ref,
  );


  my $result;
  $result->{resultset_ref} = $resultset_ref;
  $result->{column_titles_ref} = \@column_titles;

  return $result;

} # end getHighlyObservablePeptides


###############################################################################
# getHighlyObservablePeptidesDisplay -- Selects the best piptides from some application
###############################################################################
sub getHighlyObservablePeptidesDisplay {
  my $METHOD = 'getHighlyObservablePeptidesDisplay';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $best_peptide_information = $args{best_peptide_information}
    or die("ERROR[$METHOD]: Parameter best_peptide_information not passed");

  my $query_parameters_ref = $args{query_parameters_ref}
    or die("ERROR[$METHOD]: Parameter query_parameters_ref not passed");

  my $base_url = $args{base_url}
    or die("ERROR[$METHOD]: Parameter base_url not passed");


  my $resultset_ref = $best_peptide_information->{resultset_ref};
  my $column_titles_ref = $best_peptide_information->{column_titles_ref};

  #### Define the hypertext links for columns that need them
  my %url_cols = (
    	       'Peptide Accession' => "$CGI_BASE_DIR/PeptideAtlas/GetPeptide?_tab=3&atlas_build_id=$atlas_build_id&searchWithinThis=Peptide+Name&searchForThis=%V&action=QUERY",
  );

  my %hidden_cols;

  $sbeams->displayResultSet(
      resultset_ref=>$resultset_ref,
      query_parameters_ref=>$query_parameters_ref,
      #rs_params_ref=>\%rs_params,
      url_cols_ref=>\%url_cols,
      hidden_cols_ref=>\%hidden_cols,
      #max_widths=>\%max_widths,
      column_titles_ref=>$column_titles_ref,
      base_url=>$base_url,
  );

  return 1;

} # end getHighlyObservablePeptidesDisplay



###############################################################################
# sortBySuitabilityScore
###############################################################################
sub sortBySuitabilityScore {
  my $METHOD = 'sortBySuitabilityScore';
  my $self = shift || die ("self not passed");

  # Note we will be modifying the passed RS!
  my $resultset_ref = shift;

  my $n_rows = scalar(@{$resultset_ref->{data_ref}});

  my $cols = $resultset_ref->{column_hash_ref};
  my @rows = @{$resultset_ref->{data_ref}};

  my @newrows = sort { $b->[$cols->{suitability_score}] <=> $a->[$cols->{suitability_score}]
	                    || 
                     $b->[$cols->{empirical_proteotypic_score}] <=> $a->[$cols->{empirical_proteotypic_score}]
	                    || 
                     $b->[$cols->{n_observations}] <=> $a->[$cols->{n_observations}]
											} @rows; 

  $resultset_ref->{data_ref} = \@newrows;

} # end sortBySuitabilityScore


###############################################################################
# bySuitabilityScore
###############################################################################
sub bySuitabilityScore {

  return $b->[4] <=> $a->[4];

} # end bySuitabilityScore

# Subroutine calculates empirical suitability score from empirical 
# observability and sequence features/mapping info.  Works as current (04/2009)
# version of getBestPeptides routine
sub calc_suitability_score {
	my $self = shift;
	my %args = @_;


}


# Experimental section with PABST-related routines.  Should be moved
# to a separate module?

sub get_pabst_scoring_defs {
	my $self = shift;
	my %args = @_;
  my %defs =  (    M => 'Avoid M',
                   nQ => 'Avoid N-terminal Q',
                   nE => 'Avoid N-terminal E',
                   Xc => 'Avoid any C-terminal peptide',
                    C => 'Avoid C ',
                    W => 'Avoid W',
                    P => 'Avoid P',
                   NG => 'Avoid dipeptide NG',
                   DP => 'Avoid dipeptide DP',
                   DG => 'Avoid dipeptide DG',
                   QG => 'Avoid dipeptide QG',
                 nxxG => 'Avoid nxxG',
                 nGPG => 'Avoid nxyG where x or y is P or G',
                    D => 'Slightly penalize D or S in general?',
                    S => 'Slightly penalize D or S in general?',  
                  obs => 'Bonus for observed peptides, usually > 1',
                min_l => 'Minimum length for peptide',
                min_p => 'Penalty for peptides under min length',
                max_l => 'Maximum length for peptide',
                max_p => 'Penalty for peptides over max length',
                ssr_p => 'Penalty for very high or low hydrophobicity',
               );
  return \%defs;
}

#+
# Returns either hashref to scoring matrix, or string with keys, scores, and
# definitions for each (with show_defs argument).
#
# @narg show_defs     Ret scalar with keys/scores/defs instead of score hashref
#
sub get_default_pabst_scoring {
	my $self = shift;
	my %args = @_;
	$args{show_defs} ||= 0;

  my %scores =  (  M => .3,
                  nQ => .1,
                  nE => .9,
                  Xc => .5,
                   C => .7,
                   W => .1,
                   P => .5,
                  NG => .5,
                  DP => .5,
                  QG => .5,
                  DG => .5,
                nxxG => .3,
                nGPG => .1,
                   D => 1.0,
                 obs => 2.0,
                   S => 1.0,
               min_l => 0,
               min_p => 1,
               max_l => 0,
               max_p => 1,
               ssr_p => 0.5,
                );

	if ( !$args{show_defs} ) {
	  return \%scores;
	} else {
		my $defs = $self->get_pabst_scoring_defs();
		my @score_defs;
		for my $k ( sort( keys ( %scores ) ) ) {
      push @score_defs, "$k\t$scores{$k}\t# $defs->{$k}";
		}
		return ( wantarray() ) ? @score_defs : join( "\n", @score_defs, '' );
	}
}

sub get_pabst_peptides {
  my $self = shift;
  my %args = @_;

  # Check for required opts
  my $err;
  for my $opt ( qw( atlas_build_id biosequence_id ) ) {
    $err = ( $err ) ? $err . ',' . $opt : $opt if !defined $args{$opt};
  }
  die "Missing required parameter(s) $err" if $err;

  my $bioseq_in =    "AND BS.biosequence_id = $args{biosequence_id}";

  my $obs = $self->get_pabst_observed_peptides( 
                                        atlas_build => $args{atlas_build_id},
                                        protein_in_clause => $bioseq_in, 
                                              );

  my $theo = $self->get_pabst_theoretical_peptides( 
                                         atlas_build => $args{atlas_build_id},
                                   protein_in_clause => $bioseq_in, 
                                                  );
  my $merged = $self->merge_pabst_peptides(  obs => $obs, 
                                            theo => $theo );

  return $merged;

} # End get_pabst_peptides



sub get_pabst_peptide_display {
  my $self = shift;
  my %args = @_;
  # Check for required opts
  my $err;
  for my $opt ( qw( peptides link tr_info biosequence_id ) ) {
    $err = ( $err ) ? $err . ',' . $opt : $opt if !defined $args{$opt};
  }
  die "Missing required parameter(s) $err" if $err;

# 0 biosequence_name
# 1 preceding_residue
# 2 peptide_sequence
# 3 following_residue
# 4 empirical_proteotypic_score
# 5 suitability_score
# 6 predicted_suitability_score
# 7 merged_score
# 8 molecular_weight
# 9 SSRCalc_relative_hydrophobicity
# 10 n_protein_mappings
# 11 n_genome_locations
# 12 best_probability
# 13 n_observations
# 14 annotations
# 15 synthesis_score
# 16 syntheis_adjusted_score
#
# 0 pre_aa    1
# 1 sequence  2
# 2 fol_aa    3
# 3 EPS       4  emp proteo
# 4 eSS       5  emp suit
# 5 PSS       6  pred suit
# 5 MSS       7  best suit
# 6 MW        8   - removed
# 7 SSR       9   - removed
# 7 n_gen_loc 11
# 8 bprob     12   - removed
# 9 n_obs     13
# 10 annot    14
# 11 sa_score 16
#
#
  
  my $protein_info = $self->get_mapped_proteins( peptide_info => $args{peptides},
                                               biosequence_id => $args{biosequence_id},
                                               atlas_build_id => $args{atlas_build_id}
                                               );

  my $change_form = $self->get_change_form();

  my @headings = ( pre => 'Previous amino acid',
                   sequence => 'Amino acid sequence of peptide',
                   fol => 'Followin amino acid',
                   ESS => 'Empirical suitability score',
                   PSS => 'Predicted suitability score',
                   MSS => 'Merged suitability score',
                   hyd_scr => 'Relative hydrophobicity score',
                   n_gen_loc => 'Number of locations on genome to which sequence maps',
                   n_obs => 'Number of times peptide was observed',
                   Annotations => 'Annotation of peptide features such as missed cleavage (MC), etc.',
                   adj_SS => 'Best suitability score, adjusted based on sequence features',
                   map_prots => 'List of proteins to which peptide maps' );


  my @peptides = ( $self->make_sort_headings( headings => \@headings,
                                              default => 'adj_SS' )  );
  
  my $naa = $sbeams->makeInactiveText( 'n/a' );

  my $atlas_build_id = $atlas->getCurrentAtlasBuildID( parameters_ref => {} );

#     my $row = $pep_sel->pabst_evaluate_peptides( peptides => [\@row], seq_idx => 2, follow_idx => 3, score_idx => 4 );
# 0 pre_aa    1
# 1 sequence  2
# 2 fol_aa    3
# 3 EPS       4  emp proteo
# 4 eSS       5  emp suit
# 5 PSS       6  pred suit
# 5 MSS       7  best suit
# 6 MW        8   - removed
# 7 SSR       9   - removed
# 8 n_gen_loc 11
# 9 bprob     12   - removed
# 10 n_obs    13
# 11 annot    14
# 12 sa_score 16
  for my $pep_row ( @{$args{peptides}} ) {

    $pep_row->[4] = sprintf( "%0.2f", $pep_row->[4] ) if $pep_row->[4] !~ /n\/a/;
    $pep_row->[5] = sprintf( "%0.2f", $pep_row->[5] ) if $pep_row->[5] !~ /n\/a/;
    $pep_row->[6] = sprintf( "%0.2f", $pep_row->[6] ) if $pep_row->[6] !~ /n\/a/;
    $pep_row->[7] = sprintf( "%0.2f", $pep_row->[7] );
    $pep_row->[16] = sprintf( "%0.2f", $pep_row->[16] );
    $pep_row->[9] = sprintf( "%0.1f", $pep_row->[9] );

    if ( $pep_row->[12] eq 'n/a' ) {
      $pep_row->[12] = 0;
      $pep_row->[10] = $naa if $pep_row->[10] == 99;
      $pep_row->[11] = $naa;
    } else {
      $pep_row->[12] = sprintf( "%0.3f", $pep_row->[12] );
    }

    
    my $prots = $protein_info->{$pep_row->[2]} || '';
    if ( $self->{_cached_acc} && $self->{_cached_acc}->{$pep_row->[2]} ) {
      my $acc = $self->{_cached_acc}->{$pep_row->[2]};

      $pep_row->[2] = "<A HREF=GetPeptide?_tab=3&atlas_build_id=$atlas_build_id&searchWithinThis=Peptide+Name&searchForThis=$acc&action=QUERY TITLE='View peptide $acc details'>$pep_row->[2]</A>";
    }

    push @peptides, [ @{$pep_row}[1..3,5..7,9,11,13,14,16], $prots ];
  }
#                   EOS => 'Empirical observability score',
  my $align = [qw(right left right right left center center center right right)];

  my $html = $atlas->encodeSectionTable( header => 1, 
                                                 width => '600',
                                               tr_info => $args{tr},
                                                align  => $align,
                                                  rows => \@peptides,
                                          rows_to_show => 20,
                                              max_rows => 500,
                                          bkg_interval => 3, 
                                          set_download => 'Download peptides', 
                                           file_prefix => 'best_peptides_', 
                                                header => 1,
                                              bg_color => '#EAEAEA',
                                              sortable => 1,
                                              table_id => 'pabst',
                                           close_table => 1,
                                           change_form => $change_form 
                                              );
    #### Display table
    return "<TABLE WIDTH=600><BR>$html\n";

} # End get_pabst_peptide_display

sub get_mapped_proteins {
  my $self = shift;
  my %args = @_;
  my $in;
  my $sep = '';
  for my $row ( @{$args{peptide_info}} ) {
    $in .= $sep . "'" . $row->[2] . "'";
    $sep = ',';
  }

  my $sql = qq~
  SELECT DISTINCT peptide_sequence, biosequence_id, CAST(biosequence_seq AS VARCHAR(8000) )
  FROM $TBAT_BIOSEQUENCE B 
  JOIN $TBAT_PEPTIDE_MAPPING PM 
  ON ( PM.matched_biosequence_id = B.biosequence_id )
  JOIN $TBAT_PEPTIDE_INSTANCE PI
  ON ( PI.peptide_instance_id = PM.peptide_instance_id )
  JOIN $TBAT_PEPTIDE P
  ON ( PI.peptide_id = P.peptide_id )
  WHERE PI.atlas_build_id = $args{atlas_build_id}
  AND peptide_sequence IN ( $in )
  UNION ALL
  SELECT DISTINCT peptide_sequence, biosequence_id, CAST(biosequence_seq AS VARCHAR(8000) )
  FROM $TBAT_BIOSEQUENCE B JOIN $TBAT_ATLAS_BUILD AB
  ON AB.biosequence_set_id = B.biosequence_set_id
  JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PPM 
  ON ( PPM.source_biosequence_id = B.biosequence_id ) 
  JOIN $TBAT_PROTEOTYPIC_PEPTIDE PP ON PP.proteotypic_peptide_id = PPM.proteotypic_peptide_id
  WHERE AB.atlas_build_id = $args{atlas_build_id}
  AND peptide_sequence IN ( $in );
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my %prots;
  my $prot_symbol = 'a';
  my %pep_link;
  my %pep_matches;
  my $ref_group = '';
  while( my @row = $sth->fetchrow_array() ) {
    $pep_link{$row[0]} ||= {};
    $pep_matches{$row[0]} ||= {};

    if ( !$prots{$row[2]} ) {
      if ( $row[1] == $args{biosequence_id} ) {
        $ref_group = $row[2]; # Set ref_group by sequence...
      }
      $prots{$row[2]} = $prot_symbol;
      $prot_symbol++;
    }
    $pep_link{$row[0]}->{$row[1]}++;
    $pep_matches{$row[0]}->{$prots{$row[2]}}++;
  }

  # Run pairwise alignments...
  # hash of checksums keyed by sequence
  my %seq2chksum;
  # inverse, hash of sequences keyed by checksum
  my %chksum2seq;
  my $ref_sum;
  my @align_seqs;
  for my $prot_seq ( keys( %prots ) ) {
    $seq2chksum{$prot_seq} = md5_hex( $prot_seq );
    $chksum2seq{$seq2chksum{$prot_seq}} = $prot_seq;
    if ( $prot_seq eq $ref_group ) {
      $ref_sum = $seq2chksum{$prot_seq} 
    } else {
      push @align_seqs, $prot_seq;
    }
  }

  # Run alignment 
  use SBEAMS::BioLink::MSF;
  my $MSF = SBEAMS::BioLink::MSF->new();
  my $alignment_results = $MSF->runAllvsOne( reference => $ref_sum, 
                                             sequences => \%chksum2seq 
                                           );

  # parse alignment

  my %peptides;
  for my $p ( sort( keys( %pep_matches ) ) ) {
    my $mstr = join( ',', sort(keys (%{$pep_matches{$p}})) );
    my $pep_cnt = scalar( keys( %{$pep_matches{$p}}));
    my $lstr = join( ',', keys (%{$pep_link{$p}}) );
    $peptides{$p} = "<A HREF=compareProteins?pepseq=$p;bioseq_id=$lstr TARGET=compareProteins TITLE='View alignment of the $pep_cnt distinct proteins to which peptide maps'>$mstr</A>";
  }
#  https://db.systemsbiology.net/devDC/sbeams/cgi/PeptideAtlas/compareProteins?pepseq=SSPSFSSLHYQDAGNYVCETALQEVEGLK;bioseq_id=2363390,2348488,2348487,2424938,2326767,2363391,2424936,2449216,2424937
  return \%peptides;
}


#+
# Routine builds small form to with various settings as cgi params.  Assumes
# that the values passed to the current page load have been set in BPS object.
#-
sub get_change_form {
  my $self = shift;
  my %args = @_;

	my $penalties = $self->get_pabst_penalty_values();
	my $pen_defs = $self->get_pabst_scoring_defs();

  my ( $tr, $link ) = $sbeams->make_table_toggle( name => 'pabst_penalty_form',
                                                visible => 1,
                                                tooltip => 'Show/Hide penalty form',
                                                 sticky => 1,
                                                imglink => 1,
                                               textlink => 1,
                                               hidetext => 'Hide form',
                                               showtext => 'Show form',
                                              );


  my $form_table = SBEAMS::Connection::DataTable->new( BORDER => 1 );
  $form_table->addRow( [ "Parameter", 'Value', 'Description' ] );
  $form_table->setHeaderAttr( BOLD=>1, ALIGN=>'center' );
  for my $k ( sort( keys( %{$penalties} ) ) ) {

    my $input = "<INPUT TYPE=text SIZE=8 CLASS=small_form_field NAME=$k VALUE='$penalties->{$k}'></INPUT>";
    $form_table->addRow( [ "<DIV CLASS=small_form_caption>$k:</CLASS>", $input, "<DIV CLASS=small_form_text>$pen_defs->{$k}</DIV>" ] );
  }
  my @buttons = $sbeams->getFormButtons( name => 'recalculate',
                                         value => 'recalc',
                                         types => [ 'submit', 'reset' ] );
  $form_table->addRow( [ @buttons, '' ] );
  $form_table->setRowAttr( ROWS => [1..$form_table->getRowNum()], "$tr noop"=>1 );
  $form_table->setColAttr( ROWS => [1..$form_table->getRowNum()], COLS => [1], ALIGN => 'right' );
  my $form = qq~
  $link
  <FORM NAME=reset_scoring METHOD=POST>
  $form_table
  </FORM>
  ~;


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
     
    last if $cnt++ > 100; # danger Will Robinson
  }
  return \@marked;
}

# Copied shamelessly from g_p_o_p, but don't want to mess up the former yet.
sub get_pabst_multibuild_observed_peptides_depr {

  my $self = shift;
  my %args = @_;

  return undef unless $args{atlas_build};
  return undef unless ref($args{atlas_build}) eq 'ARRAY';

  my @builds = @{$args{atlas_build}};

  my @weights;
  if(  ref($args{build_weights}) eq 'ARRAY' ) {
    @weights = @{$args{build_weights}};
  } else { 
    @weights = map( 1 , @builds);
  }

  my $cnt = 0;
  my %build2weight;
  for my $b ( @builds ) {
    $build2weight{$b} = $weights[$cnt];
    $cnt++;
  }

  my $build_where = 'WHERE PI.atlas_build_id IN ( ' . join( ',', @builds ) . ')';

  # array of bioseq names for which to fetch peptides
  my $name_in = $args{protein_in_clause} || '';

  # minimum n_obs to consider as observed
  my $nobs_and = $args{min_nobs_clause} || ''; 

  my $name_like = $args{name_like} || '';

  my $pepsql =<<"  END"; 
  SELECT DISTINCT biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  CASE WHEN empirical_proteotypic_score IS NULL THEN .5  
                       ELSE  empirical_proteotypic_score 
                  END AS empirical_proteotypic_score,
                  '' AS suitability_score,
                  '' AS predicted_suitability_score,
                  '' AS merged_score,
                  STR(molecular_weight, 7, 4) Molecular_weight,
                  STR(P.SSRCalc_relative_hydrophobicity,7,2) AS "SSRCalc_relative_hydrophobicity",
                  PI.n_protein_mappings AS "n_protein_mappings",
                  PI.n_genome_locations AS "n_genome_locations",
                  STR(PI.best_probability,7,3) AS "best_probability",
                  PI.n_observations AS "n_observations",
                  '' as annotations,
                  PI.atlas_build_id,
                  preceding_residue || peptide_sequence || following_residue,
                  P.peptide_accession
  FROM $TBAT_PEPTIDE_INSTANCE PI
  JOIN $TBAT_PEPTIDE P ON ( PI.peptide_id = P.peptide_id )
  JOIN $TBAT_PEPTIDE_MAPPING PM ON ( PI.peptide_instance_id = PM.peptide_instance_id )
  JOIN $TBAT_BIOSEQUENCE BS ON ( PM.matched_biosequence_id = BS.biosequence_id )
  $build_where
  $nobs_and
  $name_like
  $name_in
  ORDER BY biosequence_name ASC, preceding_residue || peptide_sequence || following_residue, atlas_build_id ASC
 
  END

  $self->{_cached_acc} ||= {};

  my $sth = $sbeams->get_statement_handle( $pepsql );
  # Big hash of proteins
  my $pep_cnt;
  my %proteins;

  # New feature, we want to use the best EPS score from any build, where
  # the ESP might be adjusted by a build weight.  So we'll cache peptides until
  # we have a new one ( prev + seq + follow ), then pick the best and move on.
  my %peptides;

  my $curr_prot = '';
  my $prev_prot = '';
  my @sorted;
  my $curr_pep = '';
  my $prev_pep = '';
  my $curr_build;
  while( my @row = $sth->fetchrow_array() ) {

    # Each protein is an arrayref
    $curr_prot = $row[0];
    $proteins{$curr_prot} ||= [];

    $prev_prot ||= $curr_prot;

    # pop off peptide accession and cache
    my $pa = pop @row;
    $self->{_cached_acc}->{$row[2]} = $pa;

    # Also pop concat peptide
    $curr_pep = pop @row;
#    print "CURRENTS are $curr_pep and $curr_prot!\n";

    $curr_build = $row[15];

    # Each protein is an arrayref
    $peptides{$curr_pep} ||= [];

#    print "CP is $curr_pep, CB is $curr_build\n";


#    print "pre-adjust score is $row[4]\n";
    # Make build 'weight' adjustment
#    $row[4] *= $build2weight{$curr_build};
#print "$curr_prot - $row[2] adjusted to $row[4] with $build2weight{$curr_build}\n"; 

#    if ( !$prev_pep ) { # first time through
#      push @{$peptides{$curr_pep}}, \@row;
#    } elsif ( $prev_pep eq $curr_pep ) { # repeat peptide
#      push @{$peptides{$curr_pep}}, \@row;
#    } else { 
     
    print "pushing $row[2] for build $row[15]\n";
    push @{$peptides{$curr_pep}}, \@row;

    # new peptide, this is where the action is!
    if ( $prev_pep && $prev_pep ne $curr_pep ) { 
#print "In sortie!\n";
      # The score is in row 4
#print "peptides has " . scalar( @{$peptides{$prev_pep}} ).  "entries\n";
#      @sorted = sort { $b->[4] <=> $a->[4] } @{$peptides{$prev_pep}};
#print "sorted has " . scalar( @sorted ).  " entries\n";

      # We will use first entry     
#      push @{$proteins{$curr_prot}}, $sorted[0];
#print "Using score $sorted[0]->[4] from build $sorted[0]->[15] ( $build2weight{$sorted[0]->[15]} )\n"; 

      my $skip = 0;
      for my $build ( @{$args{atlas_build}} ) {
        print "considering build $build\n";
        for my $buildpep ( @{$peptides{$prev_pep}} ) {
          if ( $buildpep->[15] == $build ) {
            print "build $build is the winner for $buildpep->[2]\n";
            push @{$proteins{$curr_prot}}, $buildpep;
            $skip++;
            last;
          }
        }
        last if $skip;
      }

#print " > score is $s->[4] from build $s->[15] ( $build2weight{$s->[15]} )\n";

    } elsif ( $prev_pep ) {
      # Reset peptide storage
      if ( $prev_prot ne $curr_prot ) {
        # Reset peptide hash for each new protein.
        $peptides{$prev_pep} = [];
      }
    }

    $prev_pep = $curr_pep;
    $pep_cnt++;
  }

  # Have to collect one straggler
  # Each protein is an arrayref
  $proteins{$curr_prot} ||= [];
  my $skip = 0;
  for my $build ( @{args{atlas_build}} ) {
    for my $buildpep ( @{$peptides{$prev_pep}} ) {
      if ( $buildpep->[15] == $build ) {
        print "build $build is the winner for $buildpep->[2]\n";
        push @{$proteins{$curr_prot}}, $buildpep;
        $skip++;
        last;
      }
    }
    last if $skip;
  }
  

#print " > score is $s->[4] from build $s->[15] ( $build2weight{$s->[15]} )\n";

#  push @{$proteins{$curr_prot}}, $sorted[0];

  
#  print STDERR "Saw a respectable " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n";
  print STDERR "Observed " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n" if $args{verbose};
#  my $cnt = 0; for my $k ( keys ( %proteins ) ) { print "$k\n"; last if $cnt++ >= 10; }
  
  my $headings = $self->get_pabst_headings( as_col_hash => 1 );
  my $scores = $self->get_pabst_penalty_values();
  # Score adjustment for observed peptides!!!
  # Bonus obs deprecated.
  my $obs_adjustment = ( defined $args{bonus_obs} ) ? $args{bonus_obs} : 
                       ( defined $scores->{obs} ) ? $scores->{obs} : 1;

  my %protein_hash;
  for my $prot ( keys( %proteins ) ) {
#    for my $row ( @{$proteins{$prot}} ) { print STDERR "Before EPS is $row->[4], SS is $row->[5] for $row->[2]\n"; }

    $self->getBestPeptides( resultset_ref => { data_ref => $proteins{$prot}, 
                          column_hash_ref => $headings },
                                 annotate => 1,
                                ss_adjust => $obs_adjustment,
                             build_weight => \%build2weight,
                          );
    $protein_hash{$prot} ||= {};
    for my $row ( @{$proteins{$prot}} ) {
      $protein_hash{$prot}->{$row->[1].$row->[2].$row->[3]} = $row;
#      print STDERR "After EPS is $row->[4], SS is $row->[5] for $row->[2]\n";
    }

  }
  return \%protein_hash;
}


# Copied shamelessly from g_p_o_p, but don't want to mess up the former yet.
sub get_pabst_multibuild_observed_peptides {

  my $self = shift;
  my %args = @_;

  return undef unless $args{atlas_build};
  return undef unless ref($args{atlas_build}) eq 'ARRAY';

  my @builds = @{$args{atlas_build}};

  my @weights;
  if(  ref($args{build_weights}) eq 'ARRAY' ) {
    @weights = @{$args{build_weights}};
  } else { 
    @weights = map( 1 , @builds);
  }

  my $cnt = 0;
  my %build2weight;
  for my $b ( @builds ) {
    $build2weight{$b} = $weights[$cnt];
    $cnt++;
  }

  my $build_where = 'WHERE PI.atlas_build_id IN ( ' . join( ',', @builds ) . ')';

  # array of bioseq names for which to fetch peptides
  my $name_in = $args{protein_in_clause} || '';

  # minimum n_obs to consider as observed
  my $nobs_and = $args{min_nobs_clause} || ''; 

  my $name_like = $args{name_like} || '';

  my $pepsql =<<"  END"; 
  SELECT DISTINCT biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  CASE WHEN empirical_proteotypic_score IS NULL THEN .5  
                       ELSE  empirical_proteotypic_score 
                  END AS empirical_proteotypic_score,
                  '' AS suitability_score,
                  '' AS predicted_suitability_score,
                  '' AS merged_score,
                  STR(molecular_weight, 7, 4) Molecular_weight,
                  STR(P.SSRCalc_relative_hydrophobicity,7,2) AS "SSRCalc_relative_hydrophobicity",
                  PI.n_protein_mappings AS "n_protein_mappings",
                  PI.n_genome_locations AS "n_genome_locations",
                  STR(PI.best_probability,7,3) AS "best_probability",
                  PI.n_observations AS "n_observations",
                  '' as annotations,
                  PI.atlas_build_id,
                  preceding_residue || peptide_sequence || following_residue,
                  P.peptide_accession
  FROM $TBAT_PEPTIDE_INSTANCE PI
  JOIN $TBAT_PEPTIDE P ON ( PI.peptide_id = P.peptide_id )
  JOIN $TBAT_PEPTIDE_MAPPING PM ON ( PI.peptide_instance_id = PM.peptide_instance_id )
  JOIN $TBAT_BIOSEQUENCE BS ON ( PM.matched_biosequence_id = BS.biosequence_id )
  $build_where
  $nobs_and
  $name_like
  $name_in
  ORDER BY biosequence_name ASC, preceding_residue || peptide_sequence || following_residue, atlas_build_id ASC
 
  END

  $self->{_cached_acc} ||= {};

  my $sth = $sbeams->get_statement_handle( $pepsql );

  my $pep_cnt;

  # Big hash of proteins
  my %proteins;

  # New feature, we want to use the best EPS score from any build, where
  # the ESP might be adjusted by a build weight.  So we'll cache peptides until
  # we have a new one ( prev + seq + follow ), then pick the best and move on.
  my %peptides;

  while( my @row = $sth->fetchrow_array() ) {

    # Each protein is an arrayref
    my $curr_prot = $row[0];

    # pop off peptide accession and cache
    my $pa = pop @row;
    $self->{_cached_acc}->{$row[2]} = $pa;

    # Also pop concat peptide
    my $curr_pep = pop @row;

    my $curr_build = $row[15];

    # Each protein is an arrayref
    $peptides{$curr_prot} ||= {};
    $peptides{$curr_prot}->{$curr_pep} ||= {};
    $peptides{$curr_prot}->{$curr_pep}->{$curr_build} = \@row;

  }

  for my $prot ( sort( keys( %peptides ) ) ) {
    for my $pep ( sort( keys( %{$peptides{$prot}} ) ) ) {
      my $skip = 0;
      for my $build ( @{$args{atlas_build}} ) {
#        print "considering build $build\n";
        if ( $peptides{$prot}->{$pep}->{$build} ) {
          push @{$proteins{$prot}}, $peptides{$prot}->{$pep}->{$build};
          last; 
        }
      }

    }
  }

#  print STDERR "Saw a respectable " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n";
  print STDERR "Observed " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n" if $args{verbose};
#  my $cnt = 0; for my $k ( keys ( %proteins ) ) { print "$k\n"; last if $cnt++ >= 10; }
  
  my $headings = $self->get_pabst_headings( as_col_hash => 1 );
  my $scores = $self->get_pabst_penalty_values();
  # Score adjustment for observed peptides!!!
  # Bonus obs deprecated.
  my $obs_adjustment = ( defined $args{bonus_obs} ) ? $args{bonus_obs} : 
                       ( defined $scores->{obs} ) ? $scores->{obs} : 1;

  my %protein_hash;
  for my $prot ( keys( %proteins ) ) {
#    for my $row ( @{$proteins{$prot}} ) { print STDERR "Before EPS is $row->[4], SS is $row->[5] for $row->[2]\n"; }

    $self->getBestPeptides( resultset_ref => { data_ref => $proteins{$prot}, 
                          column_hash_ref => $headings },
                                 annotate => 1,
                                ss_adjust => $obs_adjustment,
                             build_weight => \%build2weight,
                          );
    $protein_hash{$prot} ||= {};
    for my $row ( @{$proteins{$prot}} ) {
      $protein_hash{$prot}->{$row->[1].$row->[2].$row->[3]} = $row;
#      print STDERR "After EPS is $row->[4], SS is $row->[5] for $row->[2]\n";
    }

  }
  return \%protein_hash;
}
sub get_pabst_observed_peptides {
  my $self = shift;
  my %args = @_;

  return undef unless $args{atlas_build};

  my $build_where = "WHERE PI.atlas_build_id = $args{atlas_build}";

  # array of bioseq names for which to fetch peptides
  my $name_in = $args{protein_in_clause} || '';

  # minimum n_obs to consider as observed
  my $nobs_and = $args{min_nobs_clause} || ''; 

  my $name_like = $args{name_like} || '';

  my $pepsql =<<"  END"; 
  SELECT DISTINCT 
                  biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  CASE WHEN empirical_proteotypic_score IS NULL THEN .5  
                       ELSE  empirical_proteotypic_score 
                  END AS empirical_proteotypic_score,
                  '' AS suitability_score,
                  '' AS predicted_suitability_score,
                  '' AS merged_score,
                  STR(molecular_weight, 7, 4) Molecular_weight,
                  STR(P.SSRCalc_relative_hydrophobicity,7,2) AS "SSRCalc_relative_hydrophobicity",
                  PI.n_protein_mappings AS "n_protein_mappings",
                  PI.n_genome_locations AS "n_genome_locations",
                  STR(PI.best_probability,7,3) AS "best_probability",
                  PI.n_observations AS "n_observations",
                  '' as annotations,
                  PI.atlas_build_id,
                  P.peptide_accession
  FROM $TBAT_PEPTIDE_INSTANCE PI
  JOIN $TBAT_PEPTIDE P ON ( PI.peptide_id = P.peptide_id )
  JOIN $TBAT_PEPTIDE_MAPPING PM ON ( PI.peptide_instance_id = PM.peptide_instance_id )
  JOIN $TBAT_BIOSEQUENCE BS ON ( PM.matched_biosequence_id = BS.biosequence_id )
  $build_where
  $nobs_and
  $name_like
  $name_in
  ORDER BY biosequence_name, suitability_score DESC
  END

  $self->{_cached_acc} ||= {};

  my $sth = $sbeams->get_statement_handle( $pepsql );
  # Big hash of proteins
  my $pep_cnt;
  my %proteins;
  while( my @row = $sth->fetchrow_array() ) {

    # pop off peptide accession and cache
    my $pa = pop @row;
    $self->{_cached_acc}->{$row[2]} = $pa;

    # Each protein is an arrayref
    $proteins{$row[0]} ||= [];
    push @{$proteins{$row[0]}}, \@row;

    $pep_cnt++;
  }
#  print STDERR "Saw a respectable " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n";
  print STDERR "Observed " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n" if $args{verbose};
#  my $cnt = 0; for my $k ( keys ( %proteins ) ) { print "$k\n"; last if $cnt++ >= 10; }
  
  my $headings = $self->get_pabst_headings( as_col_hash => 1 );
  my $scores = $self->get_pabst_penalty_values();
  # Score adjustment for observed peptides!!!
  # Bonus obs deprecated.
  my $obs_adjustment = ( defined $args{bonus_obs} ) ? $args{bonus_obs} : 
                       ( defined $scores->{obs} ) ? $scores->{obs} : 1;

  my %protein_hash;
  for my $prot ( keys( %proteins ) ) {
#    for my $row ( @{$proteins{$prot}} ) { print STDERR "Before EPS is $row->[4], SS is $row->[5] for $row->[2]\n"; }

    $self->getBestPeptides( resultset_ref => { data_ref => $proteins{$prot}, 
                                        column_hash_ref => $headings },
                                 annotate => 1,
                                 ss_adjust => $obs_adjustment
                          );
    $protein_hash{$prot} ||= {};
    for my $row ( @{$proteins{$prot}} ) {
      $protein_hash{$prot}->{$row->[1].$row->[2].$row->[3]} = $row;
#      print STDERR "After EPS is $row->[4], SS is $row->[5] for $row->[2]\n";
    }

  }
  return \%protein_hash;
}

sub get_pabst_headings {
  my $self = shift;
  my %args = @_;
  my @headings = qw( biosequence_name
                     preceding_residue
                     peptide_sequence
                     following_residue 
                     empirical_proteotypic_score
                     suitability_score
                     predicted_suitability_score
                     merged_score
                     molecular_weight
                     SSRCalc_relative_hydrophobicity
                     n_protein_mappings
                     n_genome_locations
                     best_probability
                     n_observations
                     annotations
                     atlas_build
                     synthesis_score
                     syntheis_adjusted_score );

  if ( $args{as_col_hash} ) {
    my %col_hash;
    my $cnt = 0;
    for my $head ( @headings ) {
      $col_hash{$head} = $cnt++;
    }
    return \%col_hash;
  } else {
    return \@headings;
  }
}


#+
# Routine to get theoretical peptides for PABST application
#-
sub get_pabst_theoretical_peptides {
  my $self = shift;
  my %args = @_;

  return undef unless ($args{atlas_build} || $args{bioseq_set} );

  if ( !$atlas ) {
    $atlas = SBEAMS::PeptideAtlas->new();
  }

  # Can run in one of two modes.
  # Old-school, provide atlas_build_id
  if ( $args{atlas_build} && !$args{bioseq_set} ) {
    $args{bioseq_set} = $atlas->getBuildBiosequenceSetID( build_id => $args{atlas_build} );
  }
  # Gnu School, explicit build_id

  my $where = "WHERE BS.biosequence_set_id = $args{bioseq_set}";

  my $name_in = $args{protein_in_clause} || '';

  my $pepsql =<<"  END"; 
  SELECT DISTINCT biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  '' AS empirical_proteotypic_score,
                  '' AS suitability_score,
                  CASE WHEN  peptidesieve_ESI > peptidesieve_ICAT THEN  (peptidesieve_ESI +  detectabilitypredictor_score )/2  
                       ELSE  (peptidesieve_ICAT +  detectabilitypredictor_score )/2  
                  END AS predicted_suitability_score,
                  '' AS merged_score,
                  STR(molecular_weight, 7, 4) Molecular_weight,
                  STR(SSRCalc_relative_hydrophobicity,7,2) AS "SSRCalc_relative_hydrophobicity",
                  n_protein_mappings AS "n_protein_mappings",
                  n_genome_locations AS "n_genome_locations",
                  'n/a' as best_probability,
                  0 as n_observations,
                  '' as annotations,
                  '' as atlas_build
  FROM $TBAT_PROTEOTYPIC_PEPTIDE PP
  JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PM ON ( PP.proteotypic_peptide_id = PM.proteotypic_peptide_id )
  JOIN $TBAT_BIOSEQUENCE BS ON ( PM.source_biosequence_id = BS.biosequence_id )
  $where
  $name_in
  ORDER BY biosequence_name, suitability_score DESC
  END



  my $sth = $sbeams->get_statement_handle( $pepsql );
  # Big hash of proteins
  my $pep_cnt;
  my %proteins;
  while( my @row = $sth->fetchrow_array() ) {

    # Adjust the score with a PBR!
#    my $row = $pep_sel->pabst_evaluate_peptides( peptides => [\@row], seq_idx => 2, follow_idx => 3, score_idx => 4 );
#    @row = @{$row->[0]};

    # Replicate the EOS penalty for MGL
    if ( $row[10] && $row[10] > 1 ) {
      if ( $row[11] && $row[11] != 99 && $row[11] > 1 ) {
        $row[6] *= 0.1; 
        $row[14] = 'MGL';
      }
    }

    # Each protein is a hashref, to be keyed by sequence w/ flanking AAs
    $proteins{$row[0]} ||= {};

    # That hashref points to the row
    $proteins{$row[0]}->{$row[1].$row[2].$row[3]} = \@row;
    $pep_cnt++;
  }
  print STDERR "Theoretical " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n" if $args{verbose};
#  my $cnt = 0; for my $k ( keys ( %proteins ) ) { print "$k\n"; last if $cnt++ >= 10; }
  return \%proteins;
}

#+
# Routine to merge observed and theoretical peptides, run PABST scoring 
# algorithm on them, and return merged array with scoring columns
#
#-
sub merge_pabst_peptides {
  my $self = shift;
  my %args = @_;

  my $obs = $args{obs};
  my $theo = $args{theo};
  my @final_protein_list;

  my $headings = $self->get_pabst_headings( as_col_hash => 1 );

  my $cnt = 0;
  print STDERR "Merging peptides from a total of " . scalar( keys( %$theo ) ) . " proteins\n" if $args{verbose};

  # loop over keys of theoretical list - all proteins are represented
  # unless of course there are none - should this work without any theo?
  for my $prot ( sort( keys( %$theo ) ) ) {

    $cnt++;
    if ( $args{verbose} && !($cnt % 5000) ) {
      print STDERR "merged $cnt proteins: " . time() . " \n";
    }

    # List of peptides for this protein
    my @peptides; 

    # 
    my @pep_keys = ( keys( %{$theo->{$prot}} ), keys( %{$obs->{$prot}} ) );
#    print STDERR scalar @pep_keys . " peptides \n";
    my %seen;
    @pep_keys =  grep !$seen{$_}++, @pep_keys;
#    print STDERR scalar @pep_keys . " unique peptides \n";

# 0 biosequence_name
# 1 preceding_residue
# 2 peptide_sequence
# 3 following_residue
# 4 empirical_proteotypic_score
# 5 suitability_score
# 6 predicted_suitability_score
# 7 merged_score
# 8 molecular_weight
# 9 SSRCalc_relative_hydrophobicity
# 10 n_protein_mappings
# 11 n_genome_locations
# 12 best_probability
# 13 n_observations
# 14 annotations
# 15 atlas build
# 16 synthesis_score
# 17 syntheis_adjusted_score

    my $naa = 'na';
    $naa = $sbeams->makeInactiveText($naa) if $sbeams->output_mode() =~ /html/i;
    # consider each peptide...
    for my $pep( @pep_keys ) {

      my $peptide;
      if ( !$theo->{$prot}->{$pep} ) {  # only obs, must be non-tryptic :(
        $peptide = $obs->{$prot}->{$pep};
        $peptide->[7] = $peptide->[5];
        $peptide->[6] = $naa;
      } elsif ( !$obs->{$prot}->{$pep} ) { # only theo, must not be a flyer :(
        $peptide = $theo->{$prot}->{$pep};
        $peptide->[7] = $peptide->[6];
        $peptide->[4] = $naa;
        $peptide->[5] = $naa;
      } else { # It exists in both, pick use best suitablity?
        $peptide = $obs->{$prot}->{$pep};
        $peptide->[6] = $theo->{$prot}->{$pep}->[6];
#        $peptide->[7] = ( $obs->{$prot}->{$pep}->[5] > $theo->{$prot}->{$pep}->[6] ) ?
#                          $obs->{$prot}->{$pep}->[5] : $theo->{$prot}->{$pep}->[6]; 
        # Just use the observed value
        $peptide->[7] = $peptide->[5];
       

        # 'Borrow' MGL penalty!                  
        # Some theoretical peptides have genome mapping info.
#        if ( defined  $obs->{$prot}->{$pep} && $obs->{$prot}->{$pep}->[5] == 0 ) {
#          $peptide->[7] = 0;
#        }
      }

      push @peptides, $peptide;
    }
#    PBR
#    print STDERR scalar( @{$peptides[0]} ) . " COLS\n";
    my $row = $self->pabst_evaluate_peptides( peptides => \@peptides,
                                               seq_idx => 2, 
                                            follow_idx => 3, 
                                             score_idx => 7,
                                             annot_idx => 14,
                                         hydrophob_idx => 9
                                            );
    @peptides = @{$row};


#    for my $p ( @peptides ) { print STDERR join( ':', @$p ) . "\n" if $p->[2] eq 'LNLSENYTLSISNAR'; }
#    print STDERR scalar( @{$peptides[0]} ) . " COLS\n";
    # OK, we have a merged array of peptides with scores.  Sort and return
    @peptides = sort { $b->[17] <=> $a->[17] } @peptides;

#    for my $p ( @peptides ) { print STDERR join( ':', @$p ) . "\n" if $p->[2] eq 'LNLSENYTLSISNAR'; }

    # Apply peptide number threshold.  Score threshold too?
    $args{n_peptides} ||= 100;
    if ( $args{n_peptides} ) {
      my $cnt = 0;
      for my $pep ( @peptides ) {
        #$pep->[15] = sprintf( "%0d", $pep->[15] );
#        $pep->[15] = 12345; #xxxxxxxsprintf( "%0d", $pep->[15] );
        push @final_protein_list, $pep;
        $cnt++;
        last if $cnt >= $args{n_peptides};
      }
    } else { # push 'em all!
      push @final_protein_list, @peptides;
    }

  }
  return \@final_protein_list;
}

#+
# Sets up penalty values for BPS object.  Merge values from 3 sources, in order
# of priority: passed args, already set _penalties, and default values.
#-
sub set_pabst_penalty_values {
  my $self = shift;
  my %args = @_;

  # only have to set a subset, the rest will be filled with default values
  $self->{_penalties} ||= {};

	my $default = $self->get_default_pabst_scoring();

  for my $k ( keys( %{$default} ) ) {
    if ( defined $args{$k} ) { # Use passed value if it is defined
      $self->{_penalties}->{$k} = $args{$k};
    } elsif ( ! defined $self->{_penalties}->{$k} ) { # Use default IFF not set
      $self->{_penalties}->{$k} = $default->{$k};
    }
  }

  # Don't really have to return these, but might be useful in some cases.
  # Use copy to preserve integrity of object cached values.
  my %penalties_copy = %{$self->{_penalties}};
  return \%penalties_copy;
}

#+
# Routine returns currently set penalty values.  If not yet set, will fetch
# and return the defaults.
#-
sub get_pabst_penalty_values {
  my $self = shift;
  my %args = @_;
  if ( $self->{_penalties} ) {
#    $log->debug( "returning already set values: $self->{_penalties}" );
#    for my $k ( keys ( %{$self->{_penalties}}  )) { $log->debug( "$k => $self->{_penalties}->{$k}" ); }

    return $self->{_penalties} 
  }
  # _penalties not yet set, this call will set to defaults and return them.
    $log->debug( "returning newly set values!" );
  return $self->set_pabst_penalty_values();
}

#+
# @narg peptides  reference to array of peptides
# @narg header    Does array have header row, default 0
# @narg seq_idx   index of sequence column in array, default to 0
# @narg score_idx index of score column, default is undef
# @narg pen_defs  reference to hash of scoring penalties, any that exist will
#                 override defaults
#
# Routine will return reference to same array, with score multiplier and 
# list of matched codes appended to the end of each row.
#
# If a score_idx is given, a third column will be appended with that score
# multiplied by the penalty multiplier.
#-
sub pabst_evaluate_peptides {
  my $self = shift;
  my %args = ( header => 0,
               seq_idx => 0,
               score_idx => undef,
               @_ );

  return undef unless $args{peptides};

  # Moved defs to standalone routine
	my $pen_ref = $self->get_pabst_penalty_values();
	my %pen_defs = %{$pen_ref};

  # Allow user override, resolve passed penalties, but only once per run unless
  # clear_cache param set.
  if ( !$args{clear_cache} && !$self->{_merged_penalties} ) {
    # Preset supercede defaults
    if ( $self->{_penalties} ) {
      # only consider known keys
      for my $k ( keys( %pen_defs ) ) {
#      print STDERR "Setting def for $k from $pen_defs{$k} to $self->{_penalties}->{$k}\n" if $self->{_penalties}->{$k};
        $pen_defs{$k} = $self->{_penalties}->{$k} if $self->{_penalties}->{$k};
      }
    }
    $self->{_merged_penalties} = \%pen_defs;
  } else {
    %pen_defs = %{$self->{_merged_penalties}};
  }

  # Passed in overrule all
  if ( $args{pen_defs} && ref  $args{pen_defs} eq 'HASH' ) {
    for my $k ( keys( %pen_defs ) ) {
      $pen_defs{$k} = $args{pen_defs}->{$k} if $args{pen_defs}->{$k};
    }
  }


  my %is_penalized;
  for my $k ( keys( %pen_defs ) ) {
    $is_penalized{$k}++ if $pen_defs{$k} < 1.0;
  }

  # Regular expressions for each score key.
  my %rx =  (  M => ['M'],
              nQ => ['^Q'],
              nE => ['^E'],
               C => ['C'],
               W => ['W'],
               P => ['P'],
              NG => ['NG'],
              DP => ['DP'],
              QG => ['QG'],
              DG => ['DG'],
            nxxG => ['^..G'],
            nGPG => ['^[GP].G', '^.[GP]G'],
               D => ['D'],
               S => ['S'] );

  # Loop over peptides
  my $cnt = 0;
  for my $pep ( @{$args{peptides}} ) {

#    print STDERR "COLS: " . scalar( @$pep ) . " before\n";
    # If we have a header column, push new headings - first pass only
    if ( $args{header} && !$cnt ) {
      $cnt++;
      push @$pep, 'Penalty_score';
      if ( defined $args{score_idx} ) {
        push @$pep, 'Adjusted_score';
      }
      next;
    }

    # Start multiplier at 1
    my $scr = 1;
    my $seq = uc($pep->[$args{seq_idx}]);
    my @pen_codes;

    if ( $args{force_mc} ) {
      if ( $seq =~ /[KR][^P]/ ) {
        push @pen_codes, 'MC';
        $scr *= 0.5;
      }
    }

    # Time to run the gauntlet!
    for my $k ( keys( %pen_defs ) ) {
      if ( $k eq 'Xc' ) {
        # Can only analyze Xc peptides if follow_idx is given
        if ( defined $args{follow_idx} && ( $pep->[$args{follow_idx}] eq '*' || $pep->[$args{follow_idx}] eq '-' ) ) {
          $scr *= $pen_defs{Xc};
          push @pen_codes, 'Xc';
        }
      } elsif( $k eq 'ssr_p') {
        if ( defined $args{hydrophob_idx} ) {
          my $hyd = $pep->[$args{hydrophob_idx}];
          if ( $hyd < 9 || $hyd > 44 ) {
            $scr *= $pen_defs{$k};
            push @pen_codes, $k if $is_penalized{$k};
          }
        }
      } elsif( $rx{$k} ) {
        for my $rx ( @{$rx{$k}} ) {
          if ( $pep->[$args{seq_idx}] =~ /$rx/ ) {
            $scr *= $pen_defs{$k};
            push @pen_codes, $k if $is_penalized{$k};
          }
        }
      }
    }

    # min/max length and penalties
    if ( $pen_defs{min_l} ) {
      if ( length($pep->[$args{seq_idx}]) < $pen_defs{min_l} ) {
        $scr *= $pen_defs{min_p};
        push @pen_codes, 'Min';
      }
    }
    if ( $pen_defs{max_l} ) {
      if ( length($pep->[$args{seq_idx}]) > $pen_defs{max_l} ) {
        $scr *= $pen_defs{max_p};
        push @pen_codes, 'Max';
      }
    }

    # May have pre-existing annotations for missed cleavage, etc.
    if ( defined $args{annot_idx} ) {
      if( @pen_codes ) {
        if ( $pep->[$args{annot_idx}] ) {
          $pep->[$args{annot_idx}] .= ',' . join( ',', @pen_codes);
        } else {
          $pep->[$args{annot_idx}] = join( ',', @pen_codes);
        }
      }
    } elsif ( @pen_codes ) {
      push @$pep, join( ',', @pen_codes);
    } else {
      push @$pep, '';
    }

    push @$pep, $scr;
#    print STDERR "SCR is $scr\n";
    if ( defined $args{score_idx} ) {
      push @$pep, $scr * $pep->[$args{score_idx}];
#      print STDERR "adjusted is is " . $scr * $pep->[$args{score_idx}] . "\n";
#      print STDERR "COLS: " . scalar( @$pep ) . " after\n";
    }
  }
  return $args{peptides};

}




###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Eric W. Deutsch (edeutsch@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
