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


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);


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

    if ($n_protein_mappings > 1) {
      if ($n_genome_locations > 1) {
        $suitability_score = 0.0;
      }
    }

    ## Penalty if not fully tryptic
    unless ($preceding_residue =~ /[KR\-]/ && 
             ($peptide_sequence =~ /[KR]$/ || $following_residue eq '-') 
					 ) {
      $suitability_score *= 0.2;
    }

    ## Penalty if missed cleavages
    if (substr($peptide_sequence,0,length($peptide_sequence)) =~ /([KR][^P])/) {
      $suitability_score *= 0.67;
		}

    $resultset_ref->{data_ref}->[$i]->[$cols->{suitability_score}] =
      sprintf("%.2f",$suitability_score);
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
          AND ( PTP.detectabilitypredictor_score >= 0.5 OR peptide_accession IS NOT NULL )
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
                  nE => .4,
                  Xc => .5,
                   C => .3,
                   W => .1,
                   P => .3,
                  NG => .5,
                  DP => .5,
                  QG => .5,
                  DG => .5,
                nxxG => .3,
                nGPG => .1,
                   D => .9,
                   S => .9 );

	if ( !$args{show_defs} ) {
	  return \%scores;
	} else {
		my %defs = (    M => 'Avoid M',
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
                    S => 'Slightly penalize D or S in general?'  
               );
		my $score_defs = '';
		for my $k ( sort( keys ( %scores ) ) ) {
      $score_defs .= "$k\t$scores{$k}\t# $defs{$k}\n";
		}
		return $score_defs;
	}
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

  # Score adjustment for observed peptides!!!
  my $obs_adjustment = $args{bonus_obs} || 1;

  my $pepsql =<<"  END"; 
  SELECT DISTINCT 
                  biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  CASE WHEN empirical_proteotypic_score IS NULL THEN .5 + $obs_adjustment 
                       ELSE  empirical_proteotypic_score + $obs_adjustment
                  END AS empirical_proteotypic_score,
                  '' AS suitability_score,
                  '' AS merged_score,
                  STR(molecular_weight, 7, 4) Molecular_weight,
                  STR(P.SSRCalc_relative_hydrophobicity,7,2) AS "SSRCalc_relative_hydrophobicity",
                  PI.n_protein_mappings AS "n_protein_mappings",
                  PI.n_genome_locations AS "n_genome_locations",
                  STR(PI.best_probability,7,3) AS "best_probability",
                  PI.n_observations AS "n_observations"
  FROM $TBAT_PEPTIDE_INSTANCE PI
  JOIN $TBAT_PEPTIDE P ON ( PI.peptide_id = P.peptide_id )
  JOIN $TBAT_PEPTIDE_MAPPING PM ON ( PI.peptide_instance_id = PM.peptide_instance_id )
  JOIN $TBAT_BIOSEQUENCE BS ON ( PM.matched_biosequence_id = BS.biosequence_id )
  $build_where
  $nobs_and
  $name_in
  ORDER BY biosequence_name, suitability_score DESC
  END

  my $sth = $sbeams->get_statement_handle( $pepsql );
  # Big hash of proteins
  my $pep_cnt;
  my %proteins;
  while( my @row = $sth->fetchrow_array() ) {

     # Adjust the score with a PBR!
#     my $row = $pep_sel->pabst_evaluate_peptides( peptides => [\@row], seq_idx => 2, follow_idx => 3, score_idx => 4 );
#     @row = @{$row->[0]};

    # Each protein is an arrayref
    $proteins{$row[0]} ||= [];
    push @{$proteins{$row[0]}}, \@row;

    # Each protein is a hashref
#    $proteins{$row[0]} ||= {};
    # That hashref points to the row, keyed by sequence w/ flanking AA
#    $proteins{$row[0]}->{$row[1].$row[2].$row[3]} = \@row;
    $pep_cnt++;
  }
#  print STDERR "Saw a respectable " . scalar( keys( %proteins ) ) . "  total proteins and $pep_cnt peptides\n";
#  my $cnt = 0; for my $k ( keys ( %proteins ) ) { print "$k\n"; last if $cnt++ >= 10; }
  
  my $headings = $self->get_pabst_headings( as_col_hash => 1 );
  my %protein_hash;
  for my $prot ( keys( %proteins ) ) {
#    for my $row ( @{$proteins{$prot}} ) { print STDERR "Before EPS is $row->[4], SS is $row->[5] for $row->[2]\n"; }

    $self->getBestPeptides( resultset_ref => { data_ref => $proteins{$prot}, column_hash_ref => $headings } );
    $protein_hash{$prot} ||= {};
    for my $row ( @{$proteins{$prot}} ) {
      $protein_hash{$prot}->{$row->[1].$row->[2].$row->[3]} = $row;
#      print STDERR "After EPS is $row->[4], SS is $row->[5] for $row->[2]\n";
    }
#  my $n_rows = scalar(@{$resultset_ref->{data_ref}});
#  my $cols = $resultset_ref->{column_hash_ref};

  }
  return \%protein_hash;
}

sub get_pabst_headings {
  my $self = shift;
  my %args = @_;
  my @headings = qw( biosequence_name preceding_residue peptide_sequence following_residue 
                     empirical_proteotypic_score suitability_score merged_score molecular_weight 
                     SSRCalc_relative_hydrophobicity n_protein_mappings n_genome_locations
                     best_probability n_observations synthesis_score synthesis_warnings
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

  return undef unless $args{atlas_build};

  my $build_where = "WHERE AB.atlas_build_id = $args{atlas_build}";
  my $name_in = $args{protein_in_clause} || '';

  my $pepsql =<<"  END"; 
  SELECT DISTINCT biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  '' AS empirical_proteotypic_score,
                  CASE WHEN  peptidesieve_ESI > peptidesieve_ICAT THEN  (peptidesieve_ESI +  detectabilitypredictor_score )/2  
                       ELSE  (peptidesieve_ICAT +  detectabilitypredictor_score )/2  
                  END AS suitability_score,
                  '' AS merged_score,
                  STR(molecular_weight, 7, 4) Molecular_weight,
                  STR(SSRCalc_relative_hydrophobicity,7,2) AS "SSRCalc_relative_hydrophobicity",
                  n_protein_mappings AS "n_protein_mappings",
                  n_genome_locations AS "n_genome_locations",
                  'n/a',
                  'n/a'
  FROM $TBAT_PROTEOTYPIC_PEPTIDE PP
  JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PM ON ( PP.proteotypic_peptide_id = PM.proteotypic_peptide_id )
  JOIN $TBAT_BIOSEQUENCE BS ON ( PM.source_biosequence_id = BS.biosequence_id )
  JOIN $TBAT_ATLAS_BUILD AB ON ( AB.biosequence_set_id = BS.biosequence_set_id ) 
  $build_where
  $name_in
  ORDER BY biosequence_name, suitability_score DESC
  END

#  print STDERR $pepsql; exit;


  my $sth = $sbeams->get_statement_handle( $pepsql );
  # Big hash of proteins
  my $pep_cnt;
  my %proteins;
  while( my @row = $sth->fetchrow_array() ) {

    # Adjust the score with a PBR!
#    my $row = $pep_sel->pabst_evaluate_peptides( peptides => [\@row], seq_idx => 2, follow_idx => 3, score_idx => 4 );
#    @row = @{$row->[0]};

    # Each protein is a hashref
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

  my $cnt = 0;
  print STDERR "Merging peptides from a total of " . scalar( keys( %$theo ) ) . " proteins\n" if $args{verbose};

  # loop over keys of theoretical list - all proteins are represented
  for my $prot ( sort( keys( %$theo ) ) ) {

    $cnt++;
    if ( $args{verbose} && !($cnt % 100) ) {
      print STDERR "merged $cnt proteins: " . time() . " \n";
    }

    # List of peptides for this protein
    my @peptides; 

    my @pep_keys = ( keys( %{$theo->{$prot}} ), keys( %{$obs->{$prot}} ) );
#    print STDERR scalar @pep_keys . " peptides \n";
    my %seen;
    my @pep_keys =  grep !$seen{$_}++, @pep_keys;
#    print STDERR scalar @pep_keys . " unique peptides \n";

    # consider each theoretical peptide...
    for my $pep( @pep_keys ) {

      my $peptide;
      if ( !$theo->{$prot}->{$pep} ) {  # only obs, must be non-tryptic :(
        $peptide = $obs->{$prot}->{$pep};
        $peptide->[6] = $peptide->[5];
      } elsif ( !$obs->{$prot}->{$pep} ) { # only theo, must not be a flyer :(
        $peptide = $theo->{$prot}->{$pep};
        $peptide->[6] = $peptide->[5];
      } else { # It exists in both, pick use best suitablity?
        $peptide = $obs->{$prot}->{$pep};
        $peptide->[6] = ( $obs->{$prot}->{$pep}->[5] > $theo->{$prot}->{$pep}->[5] ) ?
                          $obs->{$prot}->{$pep}->[5] : $theo->{$prot}->{$pep}->[5]; 

        # 'Borrow' MGL penalty!                  
        if ( defined  $obs->{$prot}->{$pep} && $obs->{$prot}->{$pep}->[5] == 0 ) {
          $peptide->[6] = 0;
        }
      }

      push @peptides, $peptide;
    }
#    PBR
    my $row = $self->pabst_evaluate_peptides( peptides => \@peptides,
                                               seq_idx => 2, 
                                            follow_idx => 3, 
                                             score_idx => 6,
                                            );
    @peptides = @{$row};

    # OK, we have a merged array of peptides with scores.  Sort and return
    @peptides = sort { $b->[15] <=> $a->[15] } @peptides;

    # Apply peptide number threshold.  Score threshold too?
    if ( $args{n_peptides} ) {
      my $cnt = 0;
      for my $pep ( @peptides ) {
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

sub set_penalty_values {
  my $self = shift;
  my %args = @_;
  $self->{_penalties} = {};
  for my $k ( keys( %args ) ) {
    $self->{_penalties}->{$k} = $args{$k};
  }
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
	my $pen_ref = $self->get_default_pabst_scoring();
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

  # Loop over peptides
  my $cnt = 0;
  for my $pep ( @{$args{peptides}} ) {

    # If we have a header column, push new headings
    if ( $args{header} && !$cnt ) {
      $cnt++;
      push @$pep, 'Penalty_score', 'Penalty_codes';
      if ( defined $args{score_idx} ) {
        push @$pep, 'Adjusted_score';
      }
      next;
    }

    # Start multiplier at 1
    my $scr = 1;
    my $seq = uc($pep->[$args{seq_idx}]);
    my @pen_codes;

    # Time to run the gauntlet!
    # Exclude/Avoid M
    if ( $seq =~ /M/ ) {
      $scr *= $pen_defs{M};
      push @pen_codes, 'M';
    }

    # Exclude N-terminal Q
    if ( $seq =~ /^Q/ ) {
      $scr *= $pen_defs{nQ};
      push @pen_codes, 'nQ';
    }

    # Avoid N-terminal E
    if ( $seq =~ /^E/ ) {
      $scr *= $pen_defs{nE};
      push @pen_codes, 'nE';
    }

    # Avoid C 
    if ( $seq =~ /C/ ) {
      $scr *= $pen_defs{C};
      push @pen_codes, 'C';
    }

    # Avoid W
    if ( $seq =~ /W/ ) {
      $scr *= $pen_defs{W};
      push @pen_codes, 'W';
    }

    # Avoid P
    if ( $seq =~ /P/ ) {
      $scr *= $pen_defs{P};
      push @pen_codes, 'P';
    }

    # Avoid dipeptide NG
    if ( $seq =~ /NG/ ) {
      $scr *= $pen_defs{NG};
      push @pen_codes, 'NG';
    }

    # Avoid dipeptide DP
    if ( $seq =~ /DP/ ) {
      $scr *= $pen_defs{DP};
      push @pen_codes, 'DP';
    }

    # Avoid dipeptide DG
    if ( $seq =~ /DG/ ) {
      $scr *= $pen_defs{DG};
      push @pen_codes, 'DG';
    }

    # Avoid dipeptide QG
    if ( $seq =~ /QG/ ) {
      $scr *= $pen_defs{QG};
      push @pen_codes, 'QG';
    }

    # Avoid nxxG
    if ( $seq =~ /^..G/ ) {
      $scr *= $pen_defs{nxxG};
      push @pen_codes, 'nxxG';
    }

    # Exclude nxyG where x or y is P or G
    if ( $seq =~ /^[GP].G/ ||  $seq =~ /^.[GP]G/   ) {
      $scr *= $pen_defs{nGPG};
      push @pen_codes, 'nGPG';
    }

    # Slightly penalize D in general
    if ( $seq =~ /D/ ) {
      $scr *= $pen_defs{D};
      push @pen_codes, 'D';
    }

    # Slightly penalize S in general
    if ( $seq =~ /S/ ) {
      $scr *= $pen_defs{S};
      push @pen_codes, 'S';
    }
    
    # Can only analyze Xc peptides if follow_idx is given
    if ( defined $args{follow_idx} && $pep->[$args{follow_idx}] eq '*' || $pep->[$args{follow_idx}] eq '-' ) {
      $scr *= $pen_defs{Xc};
      push @pen_codes, 'Xc';
    }

#    $log->info( "Score is $scr for peptide $seq!" );

    push @$pep, $scr, join( ',', @pen_codes);
    if ( defined $args{score_idx} ) {
      push @$pep, $scr * $pep->[$args{score_idx}];
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
