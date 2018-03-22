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

use SBEAMS::Proteomics::PeptideMassCalculator;
use SBEAMS::PeptideAtlas;
use SBEAMS::BioLink::MSF;

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
  
  # Set default build type to tryptic
  my %args = ( is_trypsin_build => 'Y', @_ );

  # Validate parameters
  my $resultset_ref = $args{resultset_ref}
    or die("ERROR[$METHOD]: Parameter resultset_ref not passed");

  $args{ss_adjust} ||= 1;

  my $n_rows = scalar(@{$resultset_ref->{data_ref}});
  my $cols = $resultset_ref->{column_hash_ref};
  my $peptide_info = $args{peptide_info} || {};

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
    my $peptide_accession = $resultset_ref->{data_ref}->[$i]->[$cols->{peptide_accession}];
    my $n_observations = $resultset_ref->{data_ref}->[$i]->[$cols->{n_observations}];
    my $best_probability = $resultset_ref->{data_ref}->[$i]->[$cols->{best_probability}];
    my $n_protein_mappings = $resultset_ref->{data_ref}->[$i]->[$cols->{n_protein_mappings}];
    my $n_genome_locations = $resultset_ref->{data_ref}->[$i]->[$cols->{n_genome_locations}];
    my $empirical_observability_score = $resultset_ref->{data_ref}->[$i]->[$cols->{empirical_proteotypic_score}];
    my $preceding_residue = $resultset_ref->{data_ref}->[$i]->[$cols->{preceding_residue}];
    my $following_residue = $resultset_ref->{data_ref}->[$i]->[$cols->{following_residue}];
    my $peptide_sequence = $resultset_ref->{data_ref}->[$i]->[$cols->{peptide_sequence}];
    my $highest_n_enzymatic_termini = ''; 
    my $lowest_n_missed_cleavages  =  '';
    if ($peptide_info){
      if (defined $peptide_info->{$peptide_accession}{highest_n_enzymatic_termini}){
        $highest_n_enzymatic_termini = $peptide_info->{$peptide_accession}{highest_n_enzymatic_termini};
        $lowest_n_missed_cleavages = $peptide_info->{$peptide_accession}{lowest_n_missed_cleavages};
        $resultset_ref->{data_ref}->[$i]->[$cols->{preceding_residue}] = join(",", @{$peptide_info->{$peptide_accession}{preceding_residue}});
        $resultset_ref->{data_ref}->[$i]->[$cols->{following_residue}] = join(",", @{$peptide_info->{$peptide_accession}{following_residue}});
        $resultset_ref->{data_ref}->[$i]->[$cols->{highest_n_enzymatic_termini}] = $highest_n_enzymatic_termini;
        $resultset_ref->{data_ref}->[$i]->[$cols->{lowest_n_missed_cleavages}] =$lowest_n_missed_cleavages;
      }
    }
    my @annot; # array of sequence annotations
    next if(! $n_observations);

    # removed p=1.0 fudge factor 2008-11-04 as per EWD.
    # $best_probability += 0.03 if ($best_probability == 1.000);
    my $empirical_observability_fraction = 0;
    my $divisor = 3;

    if ($max_empirical_observability_score == 0) {
      $divisor = 2;
    } else {
      $empirical_observability_fraction = $empirical_observability_score/$max_empirical_observability_score;
    }

    my $suitability_score = (
      $n_observations/$max_n_observations+($best_probability - 0.9 ) / 0.1 +
      $empirical_observability_fraction)/$divisor;
    $suitability_score *= $args{ss_adjust};

    if ($n_protein_mappings > 1) {
      if ($n_genome_locations > 1) {
        $suitability_score *= 0.1;
        push @annot, 'MGL';
      }
    }

    ## Penalty if not fully tryptic 
    # Fixed? 2010-06-21

#    unless ($preceding_residue =~ /[KR\-]/ && 
#             ($peptide_sequence =~ /[KR]$/ || $following_residue eq '-') ) {
#      $suitability_score *= 0.2;
#      push @annot, 'ST';
#    }
#
     
    if ($highest_n_enzymatic_termini ne ''){
      if ($highest_n_enzymatic_termini < 2){
        $suitability_score *= 0.2;
        push @annot, 'ST';
      }
      if ($lowest_n_missed_cleavages > 0){
        $suitability_score *= 0.67;
         push @annot, 'MC';
      }
    }else{
			if($args{is_trypsin_build} eq 'Y'){
				my $ntt = 0;
				# N Terminal side
				if ( $preceding_residue =~ /[RK]/ && $peptide_sequence !~ /^P/ ) {
					$ntt++;
				} elsif ( $preceding_residue =~ /-/ ) {
					$ntt++;
				}

					# CTerminal side
				if ( $following_residue eq '-' ) {
					$ntt++;
				} elsif ( $peptide_sequence =~ /[RK]$/ && $following_residue ne 'P' ) {
					$ntt++;
				}

				## Penalty for ntt < 2 
				unless ( $ntt == 2 ) {
					$suitability_score *= 0.2;
					push @annot, 'ST';
				}

				## Penalty for missed cleavage
				if ( $peptide_sequence =~ /([KR][^P])/) {
					$suitability_score *= 0.67;
					push @annot, 'MC';
				}
			} ## if not trypsin build skip, this step. 
    }

    if ( $args{build_weight} ) {
      my $build_id = $resultset_ref->{data_ref}->[$i]->[$cols->{atlas_build}];
      $suitability_score *= $args{build_weight}->{$build_id};
    }

    $resultset_ref->{data_ref}->[$i]->[$cols->{suitability_score}] =
      sprintf("%.2f",$suitability_score);

    if ( $args{annotate} ) {
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
             'Peptide Accession_ATAG' => "TITLE='View information for this peptide in the current build'",
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

  $args{build_accessions} ||= {};

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $biosequence_id = $args{biosequence_id}
    or die("ERROR[$METHOD]: Parameter biosequence_id not passed");

  my $build_string = join( ',', $atlas->getAccessibleBuilds() );

  my $sql = qq~
       SELECT DISTINCT BS.BIOSEQUENCE_ID
       FROM  $TBAT_PROTEOTYPIC_PEPTIDE PP,$TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PPM,
             $TBAT_BIOSEQUENCE BS
       WHERE PP.PROTEOTYPIC_PEPTIDE_ID = PPM.PROTEOTYPIC_PEPTIDE_ID
       AND PPM.SOURCE_BIOSEQUENCE_ID = BS.BIOSEQUENCE_ID
       AND BS.BIOSEQUENCE_NAME = (
          SELECT BS3.BIOSEQUENCE_NAME 
          FROM $TBAT_BIOSEQUENCE BS3
          WHERE BS3.BIOSEQUENCE_ID = $biosequence_id
       )
       GROUP BY BS.BIOSEQUENCE_ID
       HAVING (COUNT (PP.COMBINED_PREDICTOR_SCORE)*100/COUNT(BS.BIOSEQUENCE_ID))>= 90
       ORDER BY BS.BIOSEQUENCE_ID DESC
  ~;
 
  my @biosequence_ids = $sbeams->selectOneColumn($sql); 

  #print "<H4>@biosequece_ids $atlas_build_id $biosequence_id</H4>\n";
  if( @biosequence_ids == 0 ){
    my $result = $self -> getHighlyObservablePeptides_old(
      atlas_build_id => $atlas_build_id,
      biosequence_id => $biosequence_id,
    );
    return $result;
  }
 
 
  #### Define the desired columns in the query
  #### [friendly name used in url_cols,SQL,displayed column title]
  my @column_array = (
    ["peptide_accession","P.peptide_accession","Peptide Accession"],
    ["preceding_residue","PTP.preceding_residue","Pre AA"],
    ["peptide_sequence","PTP.peptide_sequence","Peptide Sequence"],
    ["following_residue","PTP.following_residue","Fol AA"],
    ["combined_predictor_score","PTP.combined_predictor_score","Combined Predictor Score"],
    ["peptidesieve_score","PTP.peptidesieve_score","PeptideSieve Score"],
    ["espp_score", "PTP.espp_score","ESPP Score"],
    ["build_placeholder",1,"build_placeholder"],
    ["detectabilitypredictor_score","PTP.detectabilitypredictor_score","Detectability Predictor Score"],
    ["apex_score", "PTP.apex_score", "APEX Score"],
    ["stepp_score", "PTP.stepp_score", "STEPP Score"],
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
  my $pepsql = qq~
     SELECT DISTINCT
     $columns_clause
     FROM $TBAT_PROTEOTYPIC_PEPTIDE PTP
     LEFT JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PTPM
          ON ( PTP.proteotypic_peptide_id = PTPM.proteotypic_peptide_id )
     LEFT JOIN $TBAT_PEPTIDE P
          ON ( PTP.matched_peptide_id = P.peptide_id )
     LEFT JOIN $TBAT_BIOSEQUENCE BS
          ON ( PTPM.source_biosequence_id = BS.biosequence_id )
     LEFT JOIN $TBAT_DBXREF DBX ON ( BS.dbxref_id = DBX.dbxref_id )
    WHERE 1 = 1
	  AND PTPM.source_biosequence_id = $biosequence_ids[0]
    AND ( PTP.combined_predictor_score is not null OR peptide_accession IS NOT NULL )
    ORDER BY PTP.combined_predictor_score DESC
  ~;

  #### Fetch the results from the database server
  my %resultset = ();
  my $resultset_ref = \%resultset;
  $sbeams->fetchResultSet(
    sql_query=>$pepsql,
    resultset_ref=>$resultset_ref,
  );

  for my $row ( @{$resultset{data_ref}} ) {
    $row->[7] = $args{build_accessions}->{$row->[0]};
  }

  my $result;
  $result->{resultset_ref} = $resultset_ref;
  $result->{column_titles_ref} = \@column_titles;
  $result->{mapping_biosequence_id} = $biosequence_ids[0];

  return $result;

} # end getHighlyObservablePeptides

###############################################################################
# getHighlyObservablePeptides_PTP -- Selects the best piptides from some application
###############################################################################
sub getHighlyObservablePeptides_PTP {
  my $METHOD = 'getHighlyObservablePeptides_PTP';
  my $self = shift || die ("self not passed");
  my %args = @_;

  $args{build_accessions} ||= {};

  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $biosequence_id = $args{biosequence_id}
    or die("ERROR[$METHOD]: Parameter biosequence_id not passed");

  my $build_string = join( ',', $atlas->getAccessibleBuilds() );

  my $sql = qq~
     SELECT DISTINCT BS2.BIOSEQUENCE_ID
     FROM $TBAT_BIOSEQUENCE BS2
     WHERE BS2.BIOSEQUENCE_ID in (
       SELECT BS.BIOSEQUENCE_ID
       FROM  $TBAT_PROTEOTYPIC_PEPTIDE PP,  $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PPM,
             $TBAT_BIOSEQUENCE BS,  $TBAT_ATLAS_BUILD AB
       WHERE PP.PROTEOTYPIC_PEPTIDE_ID = PPM.PROTEOTYPIC_PEPTIDE_ID
       AND PPM.SOURCE_BIOSEQUENCE_ID = BS.BIOSEQUENCE_ID
       AND BS.BIOSEQUENCE_SET_ID = AB.BIOSEQUENCE_SET_ID 
       AND AB.ATLAS_BUILD_ID = $atlas_build_id
       AND BS.BIOSEQUENCE_ID =  $biosequence_id
       GROUP BY BS.BIOSEQUENCE_ID
       HAVING (COUNT (PP.COMBINED_PREDICTOR_SCORE)*100/COUNT(BS.BIOSEQUENCE_ID))>= 90
    )
  ~;
  
  my @biosequece_ids = $sbeams->selectOneColumn($sql); 

  #print "<H4>@biosequece_ids $atlas_build_id $biosequence_id</H4>\n";
  if( @biosequece_ids == 0 ){
    my $result = $self -> getHighlyObservablePeptides_old(
      atlas_build_id => $atlas_build_id,
      biosequence_id => $biosequence_id,
    );
    return $result;
  }
 
 
  #### Define the desired columns in the query
  #### [friendly name used in url_cols,SQL,displayed column title]
  my @column_array = (
    ["preceding_residue","PTP.preceding_residue","Pre AA"],
    ["peptide_sequence","PTP.peptide_sequence","Peptide Sequence"],
    ["following_residue","PTP.following_residue","Fol AA"],
    ["combined_predictor_score","PTP.combined_predictor_score","Combined Predictor Score"],
    ["peptidesieve_score","PTP.peptidesieve_score","PeptideSieve Score"],
    ["espp_score", "PTP.espp_score","ESPP Score"],
    ["detectabilitypredictor_score","PTP.detectabilitypredictor_score","Detectability Predictor Score"],
    ["build_placeholder",1,"build_placeholder"],
    ["apex_score", "PTP.apex_score", "APEX Score"],
    ["stepp_score", "PTP.stepp_score", "STEPP Score"],
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
  my $pepsql = qq~
     SELECT DISTINCT
     $columns_clause
     FROM $TBAT_PROTEOTYPIC_PEPTIDE PTP
     LEFT JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PTPM
          ON ( PTP.proteotypic_peptide_id = PTPM.proteotypic_peptide_id )
     LEFT JOIN $TBAT_PEPTIDE P
          ON ( PTP.matched_peptide_id = P.peptide_id )
     LEFT JOIN $TBAT_BIOSEQUENCE BS
          ON ( PTPM.source_biosequence_id = BS.biosequence_id )
     LEFT JOIN $TBAT_DBXREF DBX ON ( BS.dbxref_id = DBX.dbxref_id )
    WHERE 1 = 1
	  AND PTPM.source_biosequence_id = $biosequece_ids[0]
    AND PTP.combined_predictor_score is not null
    ORDER BY PTP.combined_predictor_score DESC
  ~;

  #### Fetch the results from the database server
  my %resultset = ();
  my $resultset_ref = \%resultset;
  $sbeams->fetchResultSet(
    sql_query=>$pepsql,
    resultset_ref=>$resultset_ref,
  );

  for my $row ( @{$resultset{data_ref}} ) {
    $row->[7] = $args{build_accessions}->{$row->[0]};
  }

  my $result;
  $result->{resultset_ref} = $resultset_ref;
  $result->{column_titles_ref} = \@column_titles;

  return $result;

} # end getHighlyObservablePeptides

sub getHighlyObservablePeptides_old {
  my $METHOD = 'getHighlyObservablePeptides_old';
  my $self = shift || die ("self not passed");
  my %args = @_;

  $args{build_accessions} ||= {};
  #### Process parameters
  my $atlas_build_id = $args{atlas_build_id}
    or die("ERROR[$METHOD]: Parameter atlas_build_id not passed");

  my $biosequence_id = $args{biosequence_id}
    or die("ERROR[$METHOD]: Parameter biosequence_id not passed");

  my $build_string = join( ',', $atlas->getAccessibleBuilds() );

  my @column_array = (
    ["peptide_accession","P.peptide_accession","Peptide Accession"],
    ["preceding_residue","PTP.preceding_residue","Pre AA"],
    ["peptide_sequence","PTP.peptide_sequence","Peptide Sequence"],
    ["following_residue","PTP.following_residue","Fol AA"],
    ["suitability_score","(PTP.detectabilitypredictor_score+PTP.peptidesieve_ESI)/2","Suitability Score"],
    ["detectabilitypredictor_score","PTP.detectabilitypredictor_score","Detectability Predictor Score"],
    ["peptidesieve_score","PTP.peptidesieve_ESI","PeptideSieve Score"],
    ["build_placeholder",1,"build_placeholder"],
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
     SELECT DISTINCT
     $columns_clause
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
        ORDER BY (PTP.detectabilitypredictor_score+PTP.peptidesieve_ESI)/2 DESC
  ~;

  #### Fetch the results from the database server
  my %resultset = ();
  my $resultset_ref = \%resultset;
  $sbeams->fetchResultSet(
    sql_query=>$sql,
    resultset_ref=>$resultset_ref,
  );

  for my $row ( @{$resultset{data_ref}} ) {
    $row->[7] = $args{build_accessions}->{$row->[0]};
  }

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

  my $best_peptide_information = $args{best_peptide_information}
    or die("ERROR[$METHOD]: Parameter best_peptide_information not passed");

  my $base_url = $args{base_url}
    or die("ERROR[$METHOD]: Parameter base_url not passed");

  my $resultset_ref = $best_peptide_information->{resultset_ref};

#   add_num_mapped => 1,
#   dbxref_id => $dbxref_id,

  my %pep2mappings;
  if ( $args{add_num_mapped} ) {

    my @peps;

    for my $line ( @{$args{best_peptide_information}->{resultset_ref}->{data_ref}} ) {
      push @peps, $line->[2];
    }
    my $biosequence_id = $args{best_peptide_information}->{mapping_biosequence_id};

    my $pepstr = "'" . join(  "','", @peps ) . "'";

    my $sql = qq~
    SELECT peptide_sequence, count(*) 
    FROM $TBAT_PROTEOTYPIC_PEPTIDE PTP
    JOIN $TBAT_PROTEOTYPIC_PEPTIDE_MAPPING PTPM
      ON ( PTP.proteotypic_peptide_id = PTPM.proteotypic_peptide_id )
    JOIN $TBAT_BIOSEQUENCE BS
      ON ( PTPM.source_biosequence_id = BS.biosequence_id )
    WHERE biosequence_set_id IN (SELECT biosequence_set_id FROM $TBAT_BIOSEQUENCE WHERE biosequence_id = $biosequence_id )
    AND peptide_sequence IN ( $pepstr )
    AND dbxref_id = $args{dbxref_id}
    GROUP BY peptide_sequence
    ~;
    my $sth = $sbeams->get_statement_handle( $sql );
    while( my @row = $sth->fetchrow_array() ) {
      $pep2mappings{$row[0]} = $row[1];
    }


    $resultset_ref->{column_hash_ref}->{num_prot_mappings} = 11;
    push @{$resultset_ref->{column_list_ref}}, 'num_prot_mappings';
    push @{$resultset_ref->{types_list_ref}}, 'int';

  }


  my @data;
  for my $row ( @{$resultset_ref->{data_ref}} ) {
    # Define the hypertext links for columns that need them
    if ( $sbeams->output_mode() =~ /html/i ) {
      $row->[0] = "<A HREF='$CGI_BASE_DIR/PeptideAtlas/Summarize_Peptide?searchForThis=$row->[0]&query=QUERY'>$row->[0]</A>";
      $row->[2] = "<A HREF='$CGI_BASE_DIR/PeptideAtlas/GetPeptide?_tab=3&atlas_build_id=$args{atlas_build_id}&searchWithinThis=Peptide+Name&searchForThis=$row->[2]&action=QUERY'>$row->[2]</A>" if $row->[7];
    }
    for my $idx ( 4..10 ) {
      $row->[$idx] = sprintf( "%0.2f", $row->[$idx] );
    }
    my $nmappings = $pep2mappings{$row->[2]} || 'na';
		$nmappings = "<FONT COLOR=RED>$nmappings</FONT>" if $nmappings > 1;
    my @data_row = @{$row}[0..6,8..10];
    if ( $args{add_num_mapped} ) {
      push @data_row, $nmappings;
    }
    push @data, [@data_row];
  }

  my %cols;
  my $last;
  for my $col ( keys( %{$resultset_ref->{column_hash_ref}} ) ) {
#    $log->debug( "Col is $col, ColHR is $resultset_ref->{column_hash_ref}->{$col}" );
    $cols{$resultset_ref->{column_hash_ref}->{$col}} = $col;
    $last = $col;
  }

  my %translate = ( 'detectabilitypredictor_score' => 'DPred',
                               'preceding_residue' => 'Pre AA',
                              'peptidesieve_score' => 'PSieve',
                               'peptide_accession' => 'Accession',
                        'combined_predictor_score' => 'PSS',
                                'peptide_sequence' => 'Sequence',
                                      'apex_score' => 'APEX',
                                      'espp_score' => 'ESPP',
                                     'stepp_score' => 'STEPP',
                               'following_residue' => 'Fol AA',
                               'num_prot_mappings' => 'N Prot Map',
                      ); 

  my @headings;
  for my $col ( sort { $a <=> $b } ( keys( %cols ) ) ) {
    next if $cols{$col} =~ /build_placeholder/;
    push @headings, $translate{$cols{$col}};
  }
  my $headings = $atlas->get_column_defs( labels => \@headings, plain_hash => 1 );
  

  my $peptides = ( $self->make_sort_headings( headings => $headings,
                                              default => 'PSS' )  );
  unshift @data, $peptides;


  my $coldefs = $atlas->get_column_defs( labels => \@headings );
  my $table_help = $atlas->make_table_help( entries => $coldefs,
                                           description => "Theoretical tryptic peptides ranked by combined predictor score (PSS)" );


  my $align = [qw(center right left left right right right right right right right)];

  my $html = $atlas->encodeSectionTable( header => 1, 
					 tr_info => $args{tr},
					 align  => $align,
					 rows => \@data,
					 rows_to_show => 20,
					 help_text => $table_help,
					 max_rows => 500,
					 nowrap => [1..11],
					 bkg_interval => 4,
					 set_download => 'Download peptides', 
					 rs_headings => \@headings,
					 file_prefix => 'highly_observable', 
					 header => 1,
					 bg_color => '#EAEAEA',
					 sortable => 1,
					 table_id => 'highly_observable',
					 close_table => 1,
      );
  
  return "<TABLE>$html\n";
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

sub getBuildOrganism {
  my $self = shift;
  my %args = @_;

  # Default to human
  return 2 unless $args{pabst_build_id};

  my $sql = "SELECT organism_id FROM $TBAT_PABST_BUILD WHERE pabst_build_id = $args{pabst_build_id}";

  my $sth = $sbeams->get_statement_handle( $sql );
  while( my @row = $sth->fetchrow_array() ) {
    return $row[0];
  }
  # Default to human
  return 2;
}

sub getStaticInstrumentMap {
  my $self = shift;
	my %args = @_;
  my %instruments = ( QTrap4000 => 'Q',
                     QTrap5500 => 'S',
                     Orbitrap => 'B',
                    Predicted => 'P',
                    IonTrap => 'I',
                    PATR => 'R',
                    QTOF => 'T' );
  if ( $args{invert} ) {
    my %code2instr = reverse( %instruments );
    return \%code2instr;
  }
  return \%instruments;
}

sub isGlycoBuild {
	my $self = shift;
	my %args = @_;
	if ( $args{pabst_build_id} ) {
		for my $build ( 154,164,165 ) {
			if ( $build == $args{pabst_build_id} ) {
				return 1;
			}
		}
	}
	return 0;
}


sub getInstrumentMap {
  my $self = shift;
	my %args = @_;
  my $sql = "SELECT DISTINCT instrument_type_id, instrument_type_name FROM $TBAT_INSTRUMENT_TYPE";
  if ( $args{src_only} ) {
    $sql .= " WHERE is_source_instrument = 'Y'";
  }
  my $sth;
  eval {
    $sth = $sbeams->get_statement_handle( $sql );
  };
  if ( $@ ) {
    die $sql;
    return $self->getStaticInstrumentMap( %args );
  }

  my %instr;
  while( my @row = $sth->fetchrow_array() ) {
		if ( $args{inhibit_predicted} ) {
			next if $row[1] =~ /Predicted/;
		}
    $instr{$row[1]} = $row[0];
  }
	if ( $args{invert} ) {
		my %code2instr = reverse( %instr );
		return \%code2instr;
	}
  return \%instr;
} 

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

# Deprecated
#                   NG => ' Dipeptide NG',
#                   DP => ' Dipeptide DP',
#                   DG => ' Dipeptide DG',
#                   QG => ' Dipeptide QG',
#                 nxxG => ' Peptides with nxxG motif',
#                 nGPG => ' Peptides with nxyG motif, x or y is P or G',
#                 

  my @defs =  (    
                 '4H' => ' 4 consecutive hydrophobic residues: C,F,I,L,V,W,Y',
                 '5H' => ' 5 straight hydrophobic residues: F,I,L,V,W,M',
               'Hper' => ' More than 75% hydrophobic residues (F,I,L,V,W,M)',
                ssr_p => ' Peptides with SSR hydrophobicity < 10 or > 46',

                    C => ' Cysteine-containing peptides ',
                    D => ' Asparagine-containing peptides',
                    M => ' Methionine-containing peptides',
                    P => ' Proline-containing peptides',
                    R => ' Arginine-containing peptides ',
                    S => ' Serine-containing peptides',  
                    W => ' Tryptophan-containing peptides',

                   nQ => ' N-terminal Glutamine',
                 NxST => ' Peptides without NxST motif',
                   nE => ' N-terminal Glutamic Acid',
                   nM => ' N-terminal Methionine',
                   Xc => ' Any C-terminal peptide',
                   nX => ' Any N-terminal peptide',
                  bAA => ' Any non-standard amino acid (BJOUXZ)',

                   BA => ' More than 4 basic (protonatable) sites: H, K, R, n-term',
                   EC2 => ' More than 2 basic (protonatable) sites: H, K, R, n-term, each addional charge is penalized more strongly',

                  obs => ' Peptides observed in Peptide Atlas',
                 PATR => ' Peptide exists in PA transition resource',

                min_l => ' Minimum length for peptide',
                min_p => ' Peptides under min length',
                max_l => ' Maximum length for peptide',
                max_p => ' Peptides over max length',
               );
  if ( wantarray ) {
    return @defs;
  }
  my %defs = @defs;
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

# Deprecated
#                  NG => 1,
#                  DP => 1,
#                  QG => 1,
#                  DG => 1,
#                nxxG => 1,
#                nGPG => 1,
#

  my %scores =  (  M => 1,
                  nQ => 1,
                NxST => 1,
                  nE => 1,
                  nM => 1,
                  Xc => 1,
                  nX => 1,
                   C => 1,
                   W => 1,
                   P => 1,
                  BA => 1,
                 EC2 => 1,
                '4H' => 1,
                '5H' => 1,
              'Hper' => 1,
                   D => 1,
                   R => 1,
                 obs => 2.0,
                PATR => 10.0,
                   S => 1,
               min_l => 7,
               min_p => 0.2,
               max_l => 25,
               max_p => 0.2,
               ssr_p => 0.5,
                 bAA => 0,
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


sub get_pabst_static_peptide_transitions_display {
  my $self = shift;
  my %args = @_;
  # Check for required opts
  my $err;
  for my $opt ( qw( link tr_info biosequence_id peptide_sequence ) ) {
    $err = ( $err ) ? $err . ',' . $opt : $opt if !defined $args{$opt};
  }
  die "Missing required parameter(s) $err" if $err;

#  pabst_peptide_id     pabst_build_id     biosequence_id     preceding_residue     peptide_sequence                         following_residue     empirical_proteotypic_score     suitability_score     merged_score     molecular_weight     SSRCalc_relative_hydrophobicity     n_protein_mappings     n_genome_locations     best_probability     n_observations     synthesis_score     synthesis_warnings     synthesis_adjusted_score    
# 0 pabst_peptide_id
# 1 pabst_build_id
# 2 biosequence_id
# 3 preceding_residue
# 4 peptide_sequence
# 5 following_residue
# 6 empirical_proteotypic_score
# 7 suitability_score
# 8 merged_score
# 9 molecular_weight
# 10 SSRCalc_relative_hydrophobicity
# 11 n_protein_mappings
# 12 n_genome_locations
# 13 best_probability
# 14 n_observations
# 15 atlas_build_id
# 16 synthesis_score
# 17 synthesis_warnings
# 18 synthesis_adjusted_score
#
# 3,4,5,6,7,8,10,11,12,16,15 
#
# 0 fragment_ion_id
# 1 pabst_peptide_id
# 2 transition_source
# 3 precursor_ion_mass
# 4 precursor_ion_charge
# 5 fragment_ion_mass
# 6 fragment_ion_charge
# 7 fragment_ion_label
# 8 ion_rank
# 9 relative_intensity


# FIXME - can't assume order, duh.
  my $sql = qq~
  SELECT DISTINCT preceding_residue,peptide_sequence,following_residue,
  transition_source,precursor_ion_mass, precursor_ion_charge,fragment_ion_mass,
  fragment_ion_charge, fragment_ion_label, ion_rank, relative_intensity
  FROM $TBAT_PABST_PEPTIDE PP 
  JOIN $TBAT_PABST_PEPTIDE_MAPPING PM 
  ON PM.pabst_peptide_id = PP.pabst_peptide_id 
  JOIN $TBAT_PABST_TRANSITION PT 
  ON PT.pabst_peptide_id = PM.pabst_peptide_id 
  JOIN $TBAT_BIOSEQUENCE B
  ON B.biosequence_id = PM.biosequence_id 
  WHERE PM.biosequence_id = $args{biosequence_id}
  AND peptide_sequence = '$args{peptide_sequence}'
  ORDER BY ion_rank ASC 
  ~;

  my @headings = ( pre => 'Previous amino acid',
                   sequence => 'Amino acid sequence of peptide',
                   fol => 'Followin amino acid',
                   Source => 'Transition source, one of PATR, QQQ-observed (triple quad), IT-observed (ion trap), Predicted (In silico/theoretical)',
                   Q1_mz => 'Precursor ion m/z',
                   Q1_chg => 'Precursor ion charge',
                   Q3_mz => 'Fragment ion m/z',
                   Q3_chg => 'Fragment ion charge',
                   Label => 'Fragment ion label (series/number)',
                   Rank => 'PABST transition rank',
                   RI => 'Fragment peak relative intensity (scaled to 10000 Units)',
                   );


  my @peptides = ( $self->make_sort_headings( headings => \@headings,
                                              default => 'adj_SS' )  );
#  my $naa = $sbeams->makeInactiveText( 'n/a' );

  my $naa = 'n/a';
  $naa = $sbeams->makeInactiveText($naa) if $sbeams->output_mode() =~ /html/i;
  my %src_name = ( T => 'Predicted', Q => 'QQQ-observed', I => 'IT-observed', 'P' => 'PATR-validated' );

  my $sth = $sbeams->get_statement_handle( $sql );
  while( my @row = $sth->fetchrow_array() ) {
    $row[3] = $src_name{$row[3]};
    $row[4] = sprintf( "%0.2f", $row[4] );
    $row[6] = sprintf( "%0.2f", $row[6] );
    if ( $row[10] ) {
      $row[10] = sprintf( "%2d", $row[10] );
    } else {
      $row[10] = $naa;
    }
    push @peptides, [ @row ];
  }

  my $align = [qw(right left right center right center right center left right right)];

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
                                              );
    #### Display table
    return "<TABLE WIDTH=600><BR>$html\n";

} # End get_pabst_static_peptide_transitions_display

sub GetPABSTOrgansim {
  my $self = shift;
  my %args = @_;
  return '' unless $args{pabst_build_id};
  my $sql = qq~
  SELECT organism_id
  FROM $TBAT_PABST_BUILD
  WHERE pabst_build_id = $args{pabst_build_id}
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  while( my @row = $sth->fetchrow_array() ) {
  }

}


sub get_dirty_peptide_display {
  my $self = shift;
  my %args = @_;
  # Check for required opts
  my $err;
  for my $opt ( qw( link tr_info biosequence_id ) ) {
    $err = ( $err ) ? $err . ',' . $opt : $opt if !defined $args{$opt};
  }
  die "Missing required parameter(s) $err" if $err;
  my $organism_id = $atlas->getCurrentAtlasOrganism( parameters_ref => { atlas_build_id => $args{atlas_build_id} },
                                                     type => 'organism_id' );

  my $sql = qq~
  SELECT DISTINCT Sequence, Plate, ESPPred, EmpSuit, PredSuit, SSR_Calc,
         Annot, PABST, N_obs_ident, N_obs_templ, N_obs_Orbi, N_mapped,
         CASE WHEN Status = 'A' THEN 'Analyzed' 
              WHEN Status = 'R' THEN 'Rejected'    
              WHEN Status = 'O' THEN 'Ordered'    
              WHEN Status = 'S' THEN 'Re-pooled'    
              WHEN Status = 'Z' THEN 'Zh_proteome_order'    
              WHEN Status = 'D' THEN 'Observed_order'    
              WHEN Status = 'P' THEN 'Predicted_order_2010-05'    
              ELSE 'Unknown' END as Status
  FROM $TBAT_BIOSEQUENCE B
  JOIN peptideatlas.dbo.dirty_peptides DP 
  ON B.biosequence_name = DP.P_mapped
  WHERE B.biosequence_id = $args{biosequence_id}
  ORDER BY N_obs_ident DESC, N_obs_Orbi DESC
  ~;

  my @headings = ( Sequence => 'Amino acid sequence of peptide',
                   Plate => 'Synthesis plate',
                   ESPP => 'Carr ESP predictor score',
                   ESS => 'Empirical suitability score',
                   PSS => 'Predicted suitability score',
                   hyd_scr => 'SSRCalc Relative hydrophobicity score',
                   Annotations => 'Annotation of peptide features such as missed cleavage (MC), etc.',
                   adj_SS => 'Best suitability score, adjusted based on sequence features',
                   'n_obs_P0.9' => 'Number of times peptide was observed w/ P > 0.9',
                   'n_obs_P0.5' => 'Number of times peptide was observed w/ P > 0.5 ',
                   n_obs_Orbi => 'Number of times peptide was observed in Orbitrap',
                   n_prots => 'Number of  proteins to which peptide maps' ,
                   Status => 'Status of peptide' );


  my @peptides;
  my $naa = 'n/a';
  $naa = $sbeams->makeInactiveText($naa) if $sbeams->output_mode() =~ /html/i;

  my $sth = $sbeams->get_statement_handle( $sql );
  while( my @row = $sth->fetchrow_array() ) {
    for my $idx ( 2..5,7 ) {
      if ( defined $row[$idx] && $row[$idx] ne '' ) {
        $row[$idx] = sprintf( "%0.2f", $row[$idx] );
      } else {
        $row[$idx] = $naa; 
      }
    }
    for my $idx ( 8..10 ) {
      if ( $row[12] ne 'Analyzed' ) {
        $row[$idx] = $naa unless $row[$idx]
      }
    }
    push @peptides, [ @row];
  }

  # Short circuit if there are no peptides
  return '' unless scalar( @peptides );
  unshift @peptides, $self->make_sort_headings(headings => \@headings, default => 'adj_SS');

  my $align = [qw(left left right right right right center right right right right right left )];

  my $html = $atlas->encodeSectionTable( header => 1, 
                                                 width => '600',
                                               tr_info => $args{tr},
                                                align  => $align,
                                                  rows => \@peptides,
                                          rows_to_show => 20,
                                              max_rows => 500,
                                          bkg_interval => 3, 
#     set_download => 'Download peptides', 
#                                           file_prefix => 'best_peptides_', 
                                                header => 1,
                                              bg_color => '#EAEAEA',
                                              sortable => 1,
                                              table_id => 'dirty_peps',
                                           close_table => 1,
                                              );
    #### Display table
    return "<TABLE WIDTH=600><BR>$html\n";

} # End dirty_peptide display



#+ 
#  Routine builds pabst peptide table from db.
#- 
sub get_pabst_static_peptide_display {
  my $self = shift;
  my %args = @_;
  # Check for required opts
  my $err;
  for my $opt ( qw( link tr_info biosequence_name ) ) {
    $err = ( $err ) ? $err . ',' . $opt : $opt if !defined $args{$opt};
  }
  die "Missing required parameter(s) $err" if $err;
  my $organism = $atlas->getCurrentAtlasOrganism( parameters_ref => { atlas_build_id => $args{atlas_build_id} } );
#  $log->debug( "Org is $organism" );

  # If atlas build ID is passed, use organism to set pabst_build_id
  my $pabst_build_id;
  if ( defined $args{atlas_build_id} ) {
    $pabst_build_id = $self->get_pabst_build( organism_name => $organism );
  } else {
    $pabst_build_id = $self->get_pabst_build();
  }
#  $log->debug( "build is $pabst_build_id!" );
  



  $args{patr_peptides} ||= {};


  my $dp_sql = qq~
  SELECT DISTINCT Sequence, ESPPred, N_obs_ident, N_obs_templ, N_obs_Orbi,
         N_mapped,
         CASE WHEN Status = 'A' THEN 'Analyzed' 
              WHEN Status = 'R' THEN 'Rejected'    
              WHEN Status = 'O' THEN 'Ordered'    
              WHEN Status = 'S' THEN 'Re-pooled'    
              ELSE 'Unknown' END as Status
  FROM $TBAT_BIOSEQUENCE B
  JOIN peptideatlas.dbo.dirty_peptides DP 
  ON B.biosequence_name = DP.P_mapped
  WHERE B.biosequence_id = $args{biosequence_id}
  ~;

#  $log->debug( $dp_sql );

  my %dirty_peptides;
  my $dp_data = 0;
  my $dp_sth = $sbeams->get_statement_handle( $dp_sql );
  while( my @row = $dp_sth->fetchrow_array() ) {
    $dp_data++;
    $dirty_peptides{$row[0]} = \@row;
  }

  my $mapped_id = $self->get_pabst_mapped_id( $args{biosequence_name}, $pabst_build_id );

  # No id, no query
  return '' unless $mapped_id;

# 0 pabst_peptide_id
# 1 pabst_build_id
# 2 biosequence_id
# 3 preceding_residue
# 4 peptide_sequence
# 5 following_residue
# 6 empirical_proteotypic_score
# 7 suitability_score
# 8 merged_score
# 9 molecular_weight
# 10 SSRCalc_relative_hydrophobicity
# 11 n_protein_mappings
# 12 n_genome_locations
# 13 best_probability
# 14 n_observations
# 15 atlas_build_id
# 16 synthesis_score
# 17 annotations
# 18 synthesis_adjusted_score
#
# 3, 4,5, 6, 7, 8, 10, 11,12, 16,15 

#  $log->debug( $sbeams->showSessionHash() );
# FIXME - can't assume order, duh.
  my $sql = qq~
  SELECT DISTINCT preceding_residue, peptide_sequence, following_residue,
  synthesis_adjusted_score, suitability_score, predicted_suitability_score,
  SSRCalc_relative_hydrophobicity, n_genome_locations, n_observations,
  annotations, peptide_sequence AS Organism,
  CASE WHEN stripped_peptide_sequence IS NULL then 'No' ELSE 'Yes' END AS PATR
  FROM $TBAT_PABST_PEPTIDE PP 
  JOIN $TBAT_PABST_PEPTIDE_MAPPING PM
  ON PM.pabst_peptide_id = PP.pabst_peptide_id 
  JOIN $TBAT_PABST_BUILD PB 
  ON PB.pabst_build_id = PP.pabst_build_id 
  JOIN $TBAT_BIOSEQUENCE B
  ON B.biosequence_id = PM.biosequence_id 
  LEFT OUTER JOIN $TBAT_SRM_TRANSITION STR
  ON STR.stripped_peptide_sequence = PP.peptide_sequence
  WHERE PM.biosequence_id = $mapped_id
  AND PB.pabst_build_id = $pabst_build_id
  ORDER BY PATR DESC, synthesis_adjusted_score DESC
  ~;

  my @columns = ( 'Pre AA', 'Sequence', 'Fol AA', 'Adj SS', 'ESS', 'PSS', 
                   'SSRT', 'N Gen Loc', 'N Obs', 'Annot', 'Org', 'PATR' );
  my $coldefs = $atlas->get_column_defs( labels => \@columns );
  my @headings;
  my @rs_headings;
  for my $def ( @{$coldefs} ) {
    push @headings, $def->{key}, $def->{value};
    push @rs_headings, $def->{key};
  }
  my $table_help = $atlas->make_table_help( entries => $coldefs,
                                           description => "Possible peptides ranked by PABST score" );
#                                             help_text => $table_help,


  # Defer for now...
  if ( 0 && $dp_data ) {
    push @headings, ( ESPP => 'Carr ESP predictor score',
                     Detected => 'Peptide observations',
                     n_prots => 'Number of  proteins to which peptide maps' ,
                      Status => 'Status of peptide' );

  } 

  my @peptides = ( $self->make_sort_headings( headings => \@headings,
                                              default => 'Adj SS' )  );
  my $naa = 'n/a';
  $naa = $sbeams->makeInactiveText($naa) if $sbeams->output_mode() =~ /html/i;
	 
  my $sth = $sbeams->get_statement_handle( $sql );

  my %uniq_peps;
  while( my @row = $sth->fetchrow_array() ) {
    $uniq_peps{$row[1]}++;
    $row[7] = $naa if $row[7] && $row[7] == 9999;
    for my $idx ( 3,4,5 ) {
      if ( defined $row[$idx] && $row[$idx] ne '' ) {
        $row[$idx] = sprintf( "%0.2f", $row[$idx] );
      } else {
        $row[$idx] = $naa; 
      }
    }

    if ( 0 && $dp_data ) {
#  SELECT DISTINCT Sequence, ESPPred, N_obs_ident, N_obs_templ, N_obs_Orbi,
#         N_mapped,
#         CASE WHEN Status = 'A' THEN 'Anlyzed' 
      if ( $dirty_peptides{$row[1]} ) {
        my @dp =  @{$dirty_peptides{$row[1]}};
        
        my $det = '';
        if ( $dp[2] ) {
          $det = 'QQQ';
        } elsif  ( $dp[3] ) {
          $det = 'qqq';
        } 
        
        $dp[1] = sprintf( "%0.2f", $dp[1] );
        if ( $dp[4] ) {
          $det = ( $det ) ? "$det,Orbi" : 'Orbi';
        }



        push @row, ( $dp[1], $det, $dp[5], $dp[6] ); 
      } else {
        push @row,$naa,$naa,$naa,$naa;
      }
    } 

    $row[4] = sprintf( "%0.2f", $row[4] );
    $row[5] = sprintf( "%0.2f", $row[5] );
    $row[6] = sprintf( "%0.1f", $row[6] );
#    $row[10] = sprintf( "%0.2f", $row[10] );

    if ( $row[11] eq 'Yes' ) {
#      $row[3] *= 5;
    }

    $row[1] = "<A HREF=GetPeptide?_tab=3;atlas_build_id=$args{atlas_build_id};searchWithinThis=Peptide+Sequence;searchForThis=$row[1];action=QUERY;biosequence_id=$args{biosequence_id} TITLE='View peptide $row[1] details'>$row[1]</A>" if $row[8];

    push @peptides, [ @row];
  }

  my $uniq_peps = "'" . join( "','", keys( %uniq_peps ) ) . "'"; 
  my $uniq_sql = qq~
  SELECT DISTINCT peptide_sequence, organism_id 
  FROM $TBAT_PABST_BUILD PB  
  JOIN $TBAT_PABST_PEPTIDE PP ON PB.pabst_build_id = PP.pabst_build_id
  WHERE peptide_sequence = ? 
  ~;
  my $dbh = $sbeams->getDBHandle( $uniq_sql );
  my $sth = $dbh->prepare( $uniq_sql );

  my %pep2org;
  for my $pep ( keys( %uniq_peps ) ) {
    $sth->execute( $pep );
    while ( my @row = $sth->fetchrow_array() ) {
      $pep2org{$row[0]} ||= [];
      push @{$pep2org{$row[0]}}, $row[1];
    }
  }
	$sth->finish();

  my $seen_sql = qq~
  SELECT DISTINCT peptide_sequence 
  FROM $TBAT_PEPTIDE 
  WHERE peptide_sequence IN ( $uniq_peps )
  ~;

  $sth = $sbeams->get_statement_handle( $seen_sql );
  my %pep2acc;
  while ( my @row = $sth->fetchrow_array() ) {
    $pep2acc{$row[0]}++;
  }

  my @mod_peptides;
  my %orgMap = ( 2 => 'Hs', 6 => 'Mm', '3' => 'Sc' );
  my $cnt = 0;
  for my $pep ( @peptides ) {
    if ( !$cnt++ ) {
      push @mod_peptides, $pep;
      next;
    }
    if ( $pep2org{$pep->[10]} ) {
      my @orgs;
      for my $org( @{$pep2org{$pep->[10]}} ) {
        my $sym = $orgMap{$org} || 'MIA';
        push @orgs, $sym;
      }
      $pep->[10] = join( ', ', @orgs);
    } else {
      $pep->[10] = '';
    }
    $pep->[1] = "<A HREF='$CGI_BASE_DIR/PeptideAtlas/Summarize_Peptide?searchForThis=$pep->[1]&query=QUERY'>$pep->[1]</A>" if $pep2acc{$pep->[1]};
    push @mod_peptides, $pep;
  }

  my $align = [qw(right left left right right right right right right left left left)];

  my $html = $atlas->encodeSectionTable( header => 1, 
                                                 width => '600',
                                               tr_info => $args{tr},
                                                align  => $align,
                                                  rows => \@mod_peptides,
                                          rows_to_show => 20,
                                                nowrap => [1..12],
                                              max_rows => 500,
                                          bkg_interval => 3, 
                                          set_download => 'Download peptides', 
                                           rs_headings => \@rs_headings, 
                                           file_prefix => 'best_peptides_', 
                                                header => 1,
                                             help_text => $table_help,
                                              bg_color => '#EAEAEA',
                                              sortable => 1,
                                              table_id => 'pabst',
                                           close_table => 1,
                                              );
    #### Display table
    return "<TABLE WIDTH=600><BR>$html\n";

} # End get pabst static display


sub get_pabst_mapped_id {
  my $self = shift;
  my $name = shift || return '';
  my $build = shift || '';

  my $and = '';
  if ( $build ) {
    $and = "AND pabst_build_id = $build";
  }

  my $sql = qq~
  SELECT MAX( PM.biosequence_id )
  FROM $TBAT_PABST_PEPTIDE PP 
  JOIN $TBAT_PABST_PEPTIDE_MAPPING PM
  ON PM.pabst_peptide_id = PP.pabst_peptide_id 
  JOIN $TBAT_BIOSEQUENCE B
  ON B.biosequence_id = PM.biosequence_id 
  WHERE biosequence_name = '$name'
  $and
  ~;

#  $log->debug( $sql );
  
  my @ids = $sbeams->selectrow_array( $sql );
  return $ids[0] || '';

}


sub get_pabst_bss_id {
  my $self = shift;
  my %params = @_;

  my $build_id = $params{pabst_build_id} || return '';

  my $sql = qq~
  SELECT biosequence_set_id
  FROM $TBAT_PABST_BUILD PB 
  WHERE PB.pabst_build_id = $params{pabst_build_id} 
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  while ( my @row = $sth->fetchrow_array() ) {
    return $row[0];
  }
	return '';
}

#+
# Returns best legal pabst build id based on 
#  1) passed pabst_build_id param
#  1.3) passed atlas_build_id param
#  1.5) passed organism param
#  2) cached session value
#  3) default
#-
sub get_pabst_build {
  my $self = shift;
  my %params = @_;

# Not used for now
#  my $atlas_build_id = $atlas->getCurrentAtlasBuildID( parameters_ref => {} );

  my $build_id = $params{pabst_build_id};

  my $cookie_build_id = $sbeams->getSessionAttribute( key => 'pabst_build_id' );

  my $organism = $params{organism_name} || '';

  # Hash build_id to organism_name and build_name
  my @accessible = $sbeams->getAccessibleProjects();
  my $acc_str = join( ',', @accessible );
  my $sql = qq~
  SELECT pabst_build_id, organism_name, build_name, is_default
  FROM $TBAT_PABST_BUILD PB 
  JOIN $TB_ORGANISM O ON O.organism_id = PB.organism_id
  WHERE PB.project_id IN ( $acc_str )
  ORDER BY pabst_build_id DESC
  ~;

#  $log->debug( "organism is $organism!!!" );

  my %build_organisms;
  my %default_organisms;
  my %build_names;
  my $validated_build_id = '';
  my $sth = $sbeams->get_statement_handle( $sql );
  while ( my @row = $sth->fetchrow_array() ) {
    $build_organisms{$row[0]} = $row[1];
    $default_organisms{$row[0]} = $row[1] if $row[3]  eq 'T';
    $build_names{$row[0]} = $row[2];

    # Set this to the default, might well get reset based on priority
    $validated_build_id ||= $row[0];
  }

  my $found = 0;
    
  # Use preset value from cgi param if possible
  if ( $build_id && $build_names{$build_id} ) {
    $validated_build_id = $build_id;
    $log->debug( "Returning $validated_build_id based on pabst_build_id" );
    $found++;
  }

  # Get most recent build (highest build_id) for organism
  if ( !$found && $organism ) {
    for my $build_id ( sort { $b <=> $a } ( keys( %build_names ) ) ) {
      if ( ( lc( $default_organisms{$build_id} ) eq lc( $organism ) ) ) {
        $validated_build_id = $build_id;
        $log->debug( "Returning $validated_build_id based on organism" );
        $found++;
      }
    }
    $log->info( "No suitable builds found for organism $organism!" ) if !$found;
  }

  if ( !$found && $cookie_build_id && $build_organisms{$cookie_build_id} ) {
    $validated_build_id = $cookie_build_id;
    $log->debug( "Returning $validated_build_id based on cookie" );
    $found++;
  }

  if ( !$found ) {
    $log->debug( "Returning $validated_build_id based on global default" );
  }

  if ( $validated_build_id ) {
    $sbeams->setSessionAttribute( key => 'pabst_build_id', value => $validated_build_id ); 
  } else {
    $log->info( "No valid build ids found" ); 
  }
  return $validated_build_id;
}

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
# 15 atlas_build_id
# 16 synthesis_score
# 17 synthesis_adjusted_score
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
# 11 sa_score 17
#
#
  
  my $protein_info = $self->get_mapped_proteins( peptide_info => $args{peptides},
                                               biosequence_id => $args{biosequence_id},
                                               atlas_build_id => $args{atlas_build_id}
                                               );

  my $change_form = $self->get_change_form( noop => 1 );

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
# 12 sa_score 17
  for my $pep_row ( @{$args{peptides}} ) {

    $pep_row->[4] = sprintf( "%0.2f", $pep_row->[4] ) if $pep_row->[4] !~ /n\/a/;
    $pep_row->[5] = sprintf( "%0.2f", $pep_row->[5] ) if $pep_row->[5] !~ /n\/a/;
    $pep_row->[6] = sprintf( "%0.2f", $pep_row->[6] ) if $pep_row->[6] !~ /n\/a/;
    $pep_row->[7] = sprintf( "%0.2f", $pep_row->[7] );
    $pep_row->[17] = sprintf( "%0.2f", $pep_row->[17] );
    $pep_row->[9] = sprintf( "%0.1f", $pep_row->[9] );

    if ( $pep_row->[12] eq 'n/a' ) {
      $pep_row->[12] = 0;
      $pep_row->[10] = $naa if $pep_row->[10] == 99;
      $pep_row->[11] = $naa;
    } else {
      $pep_row->[12] = sprintf( "%0.3f", $pep_row->[12] );
    }

    if ( $pep_row->[5] eq '0.00' ) {
      $pep_row->[5] = $naa;
    }
    $pep_row->[13] ||= $naa; 
    
    my $prots = $protein_info->{$pep_row->[2]} || '';
    if ( $self->{_cached_acc} && $self->{_cached_acc}->{$pep_row->[2]} ) {
      my $acc = $self->{_cached_acc}->{$pep_row->[2]};

      $pep_row->[2] = "<A HREF=GetPeptide?_tab=3&atlas_build_id=$atlas_build_id&searchWithinThis=Peptide+Name&searchForThis=$acc&action=QUERY TITLE='View peptide $acc details'>$pep_row->[2]</A>";
    }

    push @peptides, [ @{$pep_row}[1..3,5..7,9,11,13,14,17], $prots ];
  }
#                   EOS => 'Empirical observability score',
  my $align = [qw(right left right right left center center center right right)];

  my $html = $atlas->encodeSectionTable( header => 1, 
                                                 width => '600',
                                               tr_info => $args{tr},
                                                align  => $align,
                                                  rows => \@peptides,
                                          rows_to_show => 12,
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
	my @pen_defs = $self->get_pabst_scoring_defs();

  my $pen_defs = {};
  my @pen_names;
  while ( @pen_defs ) {
    my $key = shift @pen_defs;
    my $val = shift @pen_defs;
    $pen_defs->{$key} = $val;
    push @pen_names, $key;
  }

  if ( defined $args{set_params} ) {
    for my $key ( keys( %{$penalties} ) ) {
      $log->debug( "$key goes from $pen_defs->{$key} to $args{set_params}->{$key}" );
      $penalties->{$key} = $args{set_params}->{$key} if defined $args{set_params}->{$key};
    }
  }

  my $noop = ( $args{noop} ) ? "Feature temporarily unavailable" : '';
  my ( $tr, $link ) = $sbeams->make_table_toggle( name => 'pabst_penalty_form',
                                                visible => 1,
                                                tooltip => 'Show/Hide penalty form',
                                                 sticky => 1,
                                                imglink => 1,
                                               textlink => 1,
                                               hidetext => "Hide form",
                                               showtext => 'Show form',
                                              );


  my $form_table = SBEAMS::Connection::DataTable->new( BORDER => 1 );
  $form_table->addRow( [ "Parameter", 'Weight', 'Description' ] );
  $form_table->setHeaderAttr( BOLD=>1, ALIGN=>'center' );
  my $action = ( $args{noop} ) ? 'onFocus=this.blur()' : '';
  for my $k ( @pen_names ) {

    my $input = "<INPUT TYPE=text SIZE=8 CLASS=small_form_field NAME=$k VALUE='$penalties->{$k}' $action></INPUT>";
    $form_table->addRow( [ "<DIV CLASS=small_form_caption>$k:</CLASS>", $input, "<DIV CLASS=small_form_text>$pen_defs->{$k}</DIV>" ] );
  }
  my @buttons = $sbeams->getFormButtons( name => 'recalculate',
                                         value => 'recalc',
                                         types => [ 'submit', 'reset' ] );
  $form_table->addRow( [ @buttons, '' ] ) unless $args{hide_buttons};
  $form_table->setRowAttr( ROWS => [1..$form_table->getRowNum()], "$tr noop"=>1 );
  $form_table->setColAttr( ROWS => [2..$form_table->getRowNum()], COLS => [1], ALIGN => 'right' );
  $form_table->setColAttr( ROWS => [1], COLS => [1..3], ALIGN => 'center' );

  if ( $args{shade_defs} ) {
    my %colors = ( B => '#EEEEEE',
                   A => '#C0D0C0',
                   C => '#CCCCCC' );
    my $row = 0;
    my $curr = 'C';
    my $first = 'head';
    for my $key ( $first, @pen_names ) {
      $row++;
      $key =~ s/\://g;
#      print "key is $key, color is $colors{$curr} for $curr!\n";
      if ( grep /$key/, ( qw( 4H C NG nQ BA min_l ) ) ) {
        $curr = ( $curr eq 'A' ) ? 'B' : 'A';
      }
      $form_table->setColAttr( ROWS => [$row], COLS => [1..3], BGCOLOR => $colors{$curr} );
    }
  }

  if ( $args{form_only} ) {
    return "$form_table";
  } elsif ( $args{hideable_form} ) {
    return $link, "$form_table";
  }

  my $form = qq~
  $link
  <FORM NAME=reset_scoring METHOD=POST>
  $form_table
  </FORM>
  ~;
  return $form;


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
      $arrow = '&#9663;';
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
  for my $build ( @{$args{atlas_build}} ) {
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
  ORDER BY preceding_residue || peptide_sequence || following_residue,
  n_observations DESC, 
  empirical_proteotypic_score DESC,
  atlas_build_id DESC
 
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

  my %peptide_values;

  while( my @row = $sth->fetchrow_array() ) {

# 0 biosequence_name, 
# 1 preceding_residue,
# 2 peptide_sequence,
# 3 following_residue,           
# 4 empirical_proteotypic_score,
# 5 suitability_score,
# 6 predicted_suitability_score,
# 7 merged_score,
# 8 Molecular_weight,
# 9 "SSRCalc_relative_hydrophobicity",
# 10 "n_protein_mappings",
# 11 "n_genome_locations",
# 12 "best_probability",
# 13 "n_observations",
# 14 '' as annotations,
# 15 PI.atlas_build_id,
# 16 preceding_residue || peptide_sequence || following_residue,
# 17 P.peptide_accession

#print "ahoy, rin tin tin\n" if $row[2] eq 'SYIEGTAVSQADVTVFK';
#print "ahoy, ran tan tan\n" if $row[2] eq 'LQINCVVEDDK';

#    KSYIEGTAVSQADVTVFKA
    # Row 17 is the peptide key (flanked sequence)
    if ( $peptide_values{$row[16]} ) {
#      print "Back attack with $row[16]\n";
      # seen before, use first value for n_obs and EPS
#      print "using $row[4] and $row[13] from $peptide_values{$row[16]}->[0] for $row[16] in $row[0]\n" if $row[2] eq 'LQINCVVEDDK';
#      print "using $row[4] and $row[13] from $peptide_values{$row[16]}->[0] for $row[16] in $row[0]\n" if $row[2] eq 'SYIEGTAVSQADVTVFK';
#      print "curr vals are $row[4] and $row[13] for $row[16] from $row[0] in build $row[15]\n";  
      for my $idx ( 4, 13 ) {
        $row[$idx] = $peptide_values{$row[16]}->[$idx]; 
      }
#      print "new vals are $row[4] and $row[13] for $row[16] from $peptide_values{$row[16]}->[0] in build $peptide_values{$row[16]}->[15]\n" if $row[2] eq 'LQINCVVEDDK';  
#      print "new vals are $row[4] and $row[13] for $row[16] from $peptide_values{$row[16]}->[0] in build $peptide_values{$row[16]}->[15]\n" if $row[2] eq 'SYIEGTAVSQADVTVFK';  
#      print "Holy bagels batman, what is up with $row[2] and $row[16]?\n" if $row[16] eq 'KLQINCVVEDDKV' && $row[2] ne 'LQINCVVEDDK';
    } else {
#      print "first time, using what god gave us! $row[4] and $row[13] from $row[16] in $row[0]\n" if $row[2] eq 'LQINCVVEDDK';
#      print "first time, using what god gave us! $row[4] and $row[13] from $row[16] in $row[0]\n" if $row[2] eq 'SYIEGTAVSQADVTVFK';
      $peptide_values{$row[16]} = \@row;
    }



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
    $pep_cnt++;

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
  my $name_like = $args{name_like_clause} || '';

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
  $name_in
  $name_like
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
                     synthesis_adjusted_score );

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
  my $name_like = $args{name_like_clause} || '';

  my $pepsql =<<"  END"; 
  SELECT DISTINCT biosequence_name, 
                  preceding_residue,
                  peptide_sequence,
                  following_residue,           
                  '' AS empirical_proteotypic_score,
                  '' AS suitability_score,

--                  CASE WHEN  peptidesieve_ESI > peptidesieve_ICAT THEN  (peptidesieve_ESI +  detectabilitypredictor_score )/2  
--                       ELSE  (peptidesieve_ICAT +  detectabilitypredictor_score )/2  
--                  END AS predicted_suitability_score,
--                  combined_predictor_score,
--  Replacing average of psieve and detect with combined score - but isn't fully populated yet
                  CASE WHEN combined_predictor_score IS NOT NULL THEN combined_predictor_score
                       WHEN peptidesieve_ESI < 0 THEN ( peptidesieve_ESI + 1 +  detectabilitypredictor_score )/2  
                       ELSE (peptidesieve_ESI +  detectabilitypredictor_score )/2  
                       END AS combined_predictor_score,

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
  $name_like
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
#    if ( $row[10] && $row[10] > 1 ) {
#      if ( $row[11] && $row[11] != 99 && $row[11] > 1 ) {
      # Not sure this is computed correctly
#        $row[6] *= 0.1; 
#        $row[14] = 'MGL';
#      }
#    }

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
  my %args = ( nobs_normalization => 1,
               @_ );

  my $obs = $args{obs};
  my $theo = $args{theo};
  my @final_protein_list;

  # We want a consistent n_obs and eps score for all peptides - even if not 
  # mapped in a particular build  
  my %seen_peptides;
  if ( $args{nobs_normalization} ) {
    for my $prot ( sort( keys( %$obs ) ) ) {
      for my $key ( keys( %{$obs->{$prot}} ) ) {
        my $pep_row = $obs->{$prot}->{$key};
        # Seen peptides are keyed by sequence with flanking AAs.
        my $pep_key =  join( '', @{$pep_row}[1..3] );
        if ( $seen_peptides{$pep_key} ) {
          # Should we look for and use the highest value here?  The
          # really should all be the same.
        } else {
#          print "seeing $pep_row->[2] for the first time, nobs is $pep_row->[13]\n";
          $seen_peptides{$pep_key} = { n_obs => $pep_row->[13],
                                            eps => $pep_row->[4],
                                            ess => $pep_row->[5] };
        }
      }
    }
  }

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

#    print STDERR scalar ( keys(  %{$theo->{$prot}} ) )  . " Theo peptides \n";
#    print STDERR scalar ( keys(  %{$obs->{$prot}} ) )  . " Obs peptides \n";

    my %merged_keys;
    for my $key ( keys( %{$theo->{$prot}} ), keys( %{$obs->{$prot}} ) ) {
      $merged_keys{$key}++;
    }
    my @pep_keys = ( keys( %merged_keys ) );

#    print STDERR "\n\n";

#    print STDERR scalar ( keys( %merged_keys ) )  . " merged peptides \n";

#    my @pep_keys = ( keys( %{$theo->{$prot}} ), keys( %{$obs->{$prot}} ) );
#    print STDERR scalar @pep_keys . " peptides \n";
#    my %seen;
#    @pep_keys =  grep !$seen{$_}++, @pep_keys;
#    print STDERR scalar @pep_keys . "Unseen peptides \n";
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
# 17 synthesis_adjusted_score

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

        # This protein may be unmapped, but we have info from a mapped protein
        if ( $seen_peptides{$pep} ) {
          $peptide->[4] = $seen_peptides{$pep}->{eps};
          $peptide->[5] = $seen_peptides{$pep}->{ess};
          $peptide->[13] = $seen_peptides{$pep}->{n_obs};
          $peptide->[7] = $peptide->[5];
        } else {
          $peptide->[7] = $peptide->[6];
          $peptide->[4] = $naa;
          $peptide->[5] = $naa;
        }

      } else { # It exists in both, pick use best suitablity? - no, use OBS if avail!
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
    my $row = $self->pabst_evaluate_peptides( %args,
                                              peptides => \@peptides,
                                          previous_idx => 1, 
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
    $args{n_peptides} ||= 5000;
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

    # Bolted on - print on the fly, a bit ugly
    if ( $args{print_onfly} ) {
      for my $peptide ( @final_protein_list ) {
        if ( defined $args{min_score} ) {
          next if $peptide->[17] <= $args{min_score};
        }
        if ( defined $args{no_mc} ) {
          next if ( $peptide->[14] && $peptide->[14] =~ /MC/ );
        }
        if ( defined $args{no_st} ) {
          next if ( $peptide->[14] && $peptide->[14] =~ /ST/ );
        }
  
        $peptide->[4] = sprintf( "%0.2f", $peptide->[4] ) if $peptide->[4] !~ /na/;
        $peptide->[5] = sprintf( "%0.2f", $peptide->[5] ) if $peptide->[5] !~ /na/;
        $peptide->[6] = sprintf( "%0.2f", $peptide->[6] ) if $peptide->[6] !~ /na/;
        $peptide->[7] = sprintf( "%0.2f", $peptide->[7] ) if $peptide->[7] !~ /na/;
        $peptide->[15] ||= 'na';
        $peptide->[16] = sprintf( "%0.2f", $peptide->[16] ) if $peptide->[16];
        $peptide->[17] = sprintf( "%0.3f", $peptide->[17] );

        print  { $args{tsv_file} } join( "\t", @{$peptide} ) . "\n";
      }
      @final_protein_list = ();
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

#  for my $a ( sort( keys( %args ) ) ) { print STDERR "$a => $args{$a}\n"; } exit;

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
    $is_penalized{$k}++ if $pen_defs{$k} < 1;
#    print STDERR "$k => $pen_defs{$k}\n";
  }

  # Regular expressions for each score key.
  my %rx =  (  M => ['M'],
              nQ => ['^Q'],
              nE => ['^E'],
              nM => ['^M'],
               C => ['C'],
               R => ['R'],
               W => ['W'],
               P => ['P'],
              NG => ['NG'],
              DP => ['DP'],
              QG => ['QG'],
            '4H' => ['[CFILVWY]{4,}'],
            '5H' => ['[FILVWM]{5,}'],
              DG => ['DG'],
            nxxG => ['^..G'],
            nGPG => ['^[GP].G', '^.[GP]G'],
               D => ['D'],
               S => ['S'] );

#  print STDERR "scr is $args{peptide_hash_scr}\n" if $args{peptide_hash_scr};

  if ( !$atlas ) {
    $atlas = SBEAMS::PeptideAtlas->new();
  }
  my $patr_peps = $atlas->get_PATR_peptides();
#  print "found " . scalar( keys( %{$patr_peps} ) ) . " PATR peptides!\n";

  # Loop over peptides
  my $cnt = 0;
  my @result_peptides;
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

    # Array of annotations
    my @pen_codes;

    # peptide sequence to consider
    my $seq = uc($pep->[$args{seq_idx}]);

    if ( $args{trim_mods} ) {
      $seq =~ s/\[\d+\]//gm;
    }

    # PATR peptides get a boost.
    if ( $patr_peps->{$seq} ) {
      $scr *= $pen_defs{PATR};
      push @pen_codes, 'PATR';
    }

    # New-ish addition.  Inclusion on a particular list might be good or bad.
    if ( $args{chk_peptide_hash} && defined $args{peptide_hash_scr} ) {

      # Disallow any peptides not on check list of chk_only is set
      if ( $args{chk_only} && !$args{chk_peptide_hash}->{$seq} ) {
        next;
      }

      if ( $args{chk_peptide_hash}->{$seq} ) {
        $scr *= $args{peptide_hash_scr};
        push @pen_codes, 'PepL';
      }
    }

    if ( $args{force_mc} ) {
      if ( $seq =~ /[KR][^P]/ ) {
        push @pen_codes, 'MC';
        $scr *= 0.5;
      }
    }


    my $lys = $seq =~ tr/K/K/;
    my $arg = $seq =~ tr/R/R/;
    my $his = $seq =~ tr/H/H/;
    my $bnum = 1 + $lys + $arg + $his;

    # Time to run the gauntlet!
    for my $k ( keys( %pen_defs ) ) {
      if ( $k eq 'Xc' ) {
        # Can only analyze Xc peptides if follow_idx is given
        if ( defined $args{follow_idx} && ( $pep->[$args{follow_idx}] eq '*' || $pep->[$args{follow_idx}] eq '-' ) ) {
          $scr *= $pen_defs{Xc};
          push @pen_codes, 'Xc';
        }
      } elsif ( $k eq 'NxST' ) {  # Implemented as a penalty for non-matching sequences.
        # Can only fully analyze NxST peptides if follow_idx is given
        my $nxst = 0;
        if ( $pep->[$args{seq_idx}] =~ /N.[ST]/ ) {
          $nxst++;
        } elsif ( $args{follow_idx} && ( $pep->[$args{seq_idx}] =~ /N.$/ && $pep->[$args{follow_idx}] =~ /[ST]/ ) ) {
          $nxst++;
        }

        if ( !$nxst && $pen_defs{NxST} != 1 ) {
          $scr *= $pen_defs{NxST};
          push @pen_codes, '!NxST';
        }

      } elsif ( $k eq 'nX' ) {
        # Can only analyze nX peptides if previous_idx is given
        if ( defined $args{previous_idx} && ( $pep->[$args{previous_idx}] eq '*' || $pep->[$args{previous_idx}] eq '-' ) ) {
          $scr *= $pen_defs{nX};
          push @pen_codes, 'nX';
        }
      } elsif( $k eq 'ssr_p') {
        if ( defined $args{hydrophob_idx} ) {
          my $hyd = $pep->[$args{hydrophob_idx}];
          if ( $hyd < 10 || $hyd > 46 ) {
            $scr *= $pen_defs{$k};
            push @pen_codes, $k if $is_penalized{$k};
          }
        }

      } elsif( $k eq 'BA' && $is_penalized{$k} ) {
         
        if ( $bnum > 4 || (length($seq)*115/$bnum < 300) ) {
          $scr *= $pen_defs{$k};
          push @pen_codes, $k;
        }

      } elsif ( $k eq 'EC2' && $is_penalized{$k} ) {  # each step away is penalized more heavily

        my $delta = abs( $bnum - 2 );
        if ( $delta ) {
          $scr *= $pen_defs{$k}**$delta;
          push @pen_codes, $k;
        }

      } elsif( $k eq 'Hper' && $is_penalized{$k} ) {
         my $safe_seq = $seq;
         my $cnt = $safe_seq =~ tr/FILVWM/FILVWM/;
         if ( $cnt && $cnt/length($seq) > 0.75 ) {
           $scr *= $pen_defs{$k};
           push @pen_codes, $k;
         }
      } elsif( $k eq 'bAA' && $is_penalized{$k} ) {
         if ( $seq !~ /^[ACDEFGHIKLMNPQRSTVWY]+$/ ) {
           $scr *= $pen_defs{$k};
           push @pen_codes, $k;
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
    push @result_peptides, $pep;
  }
  return \@result_peptides;
}
      
sub calculate_CE {
 
  my $self = shift;
  my %args = @_;

  for my $req_arg ( qw( mass charge ) ) {
    unless ( $args{$req_arg} ) {
      $log->warn( "Missing required argument $req_arg" );
      return '';
    }
  }

  my $ce;

  if    ( $args{charge} == 1 ) { 
    $ce = 0.058 * $args{mass} + 9; 
  } elsif ( $args{charge} == 2 ) { 
    $ce = 0.044 * $args{mass} + 5.5;
  } elsif ( $args{charge} == 3 ) { 
    $ce = 0.051 * $args{mass} + 0.5;
  } elsif ( $args{charge} > 3 )  { 
    $ce = 0.003 * $args{mass} + 2; 
  }

  $ce = 75 if ( $ce > 75 ); 

  return $ce;
}

sub get_peptide_mass {
  my $self = shift;
  my %args = @_;

  return unless ( $args{peptide_seq} && $args{charge} );

  $self->{_mass_calc} ||= new SBEAMS::Proteomics::PeptideMassCalculator;

  my $mass = $self->{_mass_calc}->getPeptideMass( sequence => $args{peptide_seq},
                                                 mass_type => 'monoisotopic',
                                                    charge => $args{charge} );

  return $mass;

}

# Generate theoretical fragments from a peptide sequence
# @narg peptide_seq  required
# @narg max_mz  (default 10000)
# @narg min_mz  (default 0)
# @narg precursor_excl (default 0)
sub generate_fragment_ions {

  my $self = shift;
  my %args = ( max_mz => 10000,
               min_mz => 0,
               precursor_excl => 0,
               add_score => 1,
               type => 'P',
               charge => 2,
              @_ );

  $self->{_mass_calc} ||= new SBEAMS::Proteomics::PeptideMassCalculator;


  for my $req_arg ( qw( peptide_seq ) ) {
    unless ( $args{$req_arg} ) {
      $log->warn( "Missing required argument $req_arg" );
      return [];
    }
  }

  if ( $args{peptide_seq} =~ /X|U|\*/ ) {
    $log->warn( "Illegal characters in peptide sequence" );
    return [];
  }

  # TODO loop over charge 2 and 3?
  my @frags;

  my $len = length( $args{peptide_seq} );

  if ( !$atlas ) {
    $atlas = SBEAMS::PeptideAtlas->new();
  }
  my $residues = $atlas->fragment_peptide( $args{peptide_seq} );

  my $mass = $self->{_mass_calc}->getPeptideMass( sequence => $args{peptide_seq},
                                                         mass_type => 'monoisotopic',
                                                            charge => 0 );

  my $hydrogen_mass = 1.007825;
  my $mz = ($mass + $args{charge} * $hydrogen_mass)/$args{charge};

#  print "mz is $mz and mass is $mass for peptide $args{peptide_seq}\n and charge $args{charge}\n";

  if ( !$mass ) {
    $log->warn( "Mass calulation yeilds 0 for $args{peptide_seq}" );
    return [];
  }


  my $ce = $self->calculate_CE( mass => $mass, charge => $args{charge} );

  $sbeams = $self->getSBEAMS();

#  my $ions = $atlas->CalcIons( Residues => $residues,
#                       modified_sequence => $args{peptide_seq},
#                                  Charge => 1 );


  my $ions = $atlas->calc_ions( 
                       sequence => $args{peptide_seq},
                         charge => 1 );

#  use Data::Dumper;
#  print Dumper( $ions );


  # precursor mz norm to 1000 Th
  my $norm_factor = (1000/$mz);

  my %series = ( Yions => 'y',
                 Bions => 'b' );

  # Push first Y and then B ions
#  print "precursor mz is $mz, norm factor is $norm_factor\n";
  for my $series_class ( qw( Yions Bions ) ) {

    for ( my $i = 1; $i < $len; $i++ ) {

      if ( $ions->{$series_class}->[$i] < $args{min_mz} ||  
           $ions->{$series_class}->[$i] > $args{max_mz} ||
           abs( $mz - $ions->{$series_class}->[$i] ) < $args{precursor_excl} 
         ) {

        # user-defined out-of-range
#        print "$series_class $ions->{indices}->[$i] failed! $ions->{$series_class}->[$i]\n";
        next;
      }

      if ( abs( $ions->{$series_class}->[$i] - $mass ) < 2 ) {
        print STDERR "Skipping $series_class $i ( $ions->{$series_class}->[$i] as intact precursor\n";
        next;
      }

      my $scr = sprintf( '%0.1f', $ions->{$series_class}->[$i] * $norm_factor );
#      print "Score is $scr for $i $series_class ) $ions->{indices}->[$i] is $ions->{$series_class}->[$i] \n";
#      print "$i) $series{$series_class} $ions->{indices}->[$i] is $ions->{$series_class}->[$i]\n";
#
# peptide sequence
# modified_peptide_sequence
# q1_mz
# q1_charge
# q3_mz
# q3_charge
# ion_series
# ion_number
# CE
# Relative intensity 
# Type (user-defineable)
# Score  (optional) -  on by default
#
      my $fragment =  [ $args{peptide_seq}, 
                        $args{peptide_seq},
                        $mz,
                        $args{charge},
                        $ions->{$series_class}->[$i],
                        1, 
                        $series{$series_class},
                        $ions->{indices}->[$i],
                        $ce, 
                        '',
                       ];
      if ( $args{type} ) {
        push @{$fragment}, $args{type};
      }
      if ( $args{add_score} ) {
        push @{$fragment}, $scr;
      }
      push @frags, $fragment;
    }
  }
  return \@frags;

} # End generate_fragment_ions

# Cheap 'n dirty fragment sorter.
# Y over
# B over
# Y under
# B under
sub order_fragments {
  my $self = shift;
  my $frags = shift;
  my @frags;
  my $f = scalar( @$frags );

  # First Y
  my @y_over;
  my @y_under;
  for my $frag ( @{$frags} ) {
    next if $frag->[6] =~ /b/i;
    if ( $frag->[11] > 1000 ) {
# Was just pushing 0..10 - why?
#      push @y_over, [@{$frag}[0..10]];
      push @y_over, [@$frag];
    } else {
      unshift @y_under, [@$frag];
    }
  }

  # Next B
  my @b_under;
  my @b_over;
  for my $frag ( @{$frags} ) {
    next if $frag->[6] =~ /y/i;
    if ( $frag->[11] > 1000 ) {
      push @b_over, [@$frag];
    } else {
      unshift @b_under, [@$frag];
    }
  }

  push @frags, @y_over, @b_over, @y_under, @b_under;

  return \@frags;
}

# Routine to return charge state ratios for transitions based on
# peptide sequence (length and expected charge).
sub get_charge_ratios {
  my $self = shift;
  my %args = @_;
  return undef unless $args{sequence};
  my $len = length( $args{sequence} );
  my $bnum = $self->get_expected_charge( %args );
  my $instrument = $args{instrument_type} || 'QTOF';

  # Put code here to get 
  $self->{_ratio_matrix} ||= generate_ratio_matrix();

  unless ( $self->{'_ratio_matrix'}->{$args{instrument_type}} ) {
    return "Unknown instrument type $args{instrument_type}";
  }


  my $mass = $args{mass} || $len * 115;

}

sub generate_ratio_matrix {
  my $self = shift;
  my %map;
  for my $instr ( qw( QTOF QTrap4000 QTrap5500 IonTrap ) ) {
    $map{$instr} ||= {};
    for my $ex_ch ( 1..10 ) {
      $map{$instr}->{$ex_ch} ||= {};
      for my $len ( 6..50 ) {
        $map{$instr}->{$ex_ch}->{$len} ||= [];
        if ( $ex_ch > 3 ) {
          $map{$instr}->{$ex_ch}->{$len} = [0,0,25,75];
        } elsif ( $ex_ch == 3 ) {
          $map{$instr}->{$ex_ch}->{$len} = [0,25,50,25];
        } elsif ( $ex_ch == 2 ) {
          $map{$instr}->{$ex_ch}->{$len} = [25,50,25,0];
        } else {
          $map{$instr}->{$ex_ch}->{$len} = [75,25,0,0];
        }
        next;
        
        # deprecated, will use matrix eventually
        my $low_lim = 300;
        my $hi_lim = ( $instr =~ /QTrap/ ) ? 1200 : 2000;
        my $mass = $len + 115;
        my $ex_mz = $mass/$ex_ch;
        if ( $ex_mz > $low_lim ) {
          if ( $ex_mz < $hi_lim ) {
          }
        }

      }
    }
  }
  return \%map;
}

sub get_expected_charge {

  my $self = shift;
  my %args = @_;
  return undef unless $args{sequence};
  my $seq = $args{sequence};

  my $lys = $seq =~ tr/K/K/;
  my $arg = $seq =~ tr/R/R/;
  my $his = $seq =~ tr/H/H/;

  my $bnum = 1 + $lys + $arg + $his;
  return $bnum;


}

sub get_predicted_charge {
  my $self = shift;
  my %args = @_;
  for my $arg ( qw( mass e_chg ) ) {
    die " Missing required parameter $arg" if !defined $args{$arg};
  }

  my $mass = int( $args{mass}/10 );

  $mass = 50 if $mass < 50;
  $mass = 400 if $mass > 400;


  $self->{"_charge_matrix"} ||= $self->get_charge_matrix();

#  print STDERR $self->{"_charge_matrix"};
#  exit;

  my $pred_chg = $self->{"_charge_matrix"}->{$mass}->{$args{e_chg}}; 
  
#  use Data::Dumper;
#  print STDERR Dumper( $self->{"_charge_matrix"} );

  print STDERR "No result for m=$args{mass}, c=$args{e_chg}" if !$pred_chg;
  return $pred_chg;
}

sub get_charge_matrix {
  my $self = shift;
  my %args = @_;

  my %matrix;
  for my $mass ( 50..400 ) {
    $matrix{$mass} = {};
    for my $ec ( 1..5 ) {
      my $pc = ( $ec < 4 ) ? $ec : 4;
      $matrix{$mass}->{$ec} = $pc;
    }
  }
  my $chg_file = "$PHYSICAL_BASE_DIR/lib/refdata/PeptideAtlas/QTOF_expected2observed_charge.tsv";

  return \%matrix unless ( -e $chg_file );

  open( CHG_FILE, $chg_file ) || return \%matrix;
  while ( my $line = <CHG_FILE> ) {
    chomp $line;
    my @vals = split( /\t/, $line );
    next unless $vals[0] && $vals[1];
    $matrix{$vals[0]}->{$vals[1]} = $vals[2];
  }
  return \%matrix;

}


sub get_pabst_build_select {

  my $self = shift || die ("self not passed");
  my %args = ( build_id => '', @_ );

	my $project_string = join( ', ', $sbeams->getAccessibleProjects() );
	return unless $project_string;


	if ( $args{build_id} && $args{build_id} =~ /^\d+$/ ) {
	  my $sth = $sbeams->get_statement_handle( "SELECT build_name FROM $TBAT_PABST_BUILD WHERE pabst_build_id = $args{build_id}" );
    while ( my @row = $sth->fetchrow_array() ) {
      $args{build_name} = $row[0];
      last;
    }
  }

	my $project_string = join( ', ', $sbeams->getAccessibleProjects() );
	return unless $project_string;

	my $onchange_script = '';
	my $onchange = '';
  if ($args{set_onchange}) {
	  $onchange = 'onchange="switchAtlasBuild()"';
		$onchange_script =  qq~
		<SCRIPT LANGUAGE=javascript TYPE=text/javascript>
		function switchAtlasBuild() {
			document.$args{form_name}.submit();
		}
		</SCRIPT>
		~;
	}

  my $sql = qq~
    SELECT pabst_build_id, build_name 
      FROM $TBAT_PABST_BUILD
		 WHERE project_id IN ( $project_string )
     ORDER BY build_name
  ~;
	my $sth = $sbeams->get_statement_handle( $sql );
	my $select = "<SELECT NAME=build_id $onchange>\n";
	while ( my @row = $sth->fetchrow_array() ) {
		# default to first one
		$args{build_name} ||= $row[1];
		my $selected = ( $row[1] =~ /^$args{build_name}$/ ) ? 'SELECTED' : '';
		$select .= "<OPTION VALUE=$row[0] $selected> $row[1] </OPTION>";
	}
	$select .= "</SELECT>\n";

	return ( wantarray() ) ? ($select, $onchange_script) :  $select . $onchange_script; 
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
