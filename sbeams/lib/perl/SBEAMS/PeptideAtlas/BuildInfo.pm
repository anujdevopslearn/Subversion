package SBEAMS::PeptideAtlas::BuildInfo;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::BuildInfo
# Author      : Terry Farrah <tfarrah@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::BuildInfo

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::BuildInfo

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
the gathering, storage, and retrieval of PeptideAtlas build statistics
for the cgi buildInfo.

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use vars qw ($q $sbeams $sbeamsMOD $PROG_NAME);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::AtlasBuild;
use SBEAMS::PeptideAtlas::ProtInfo;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);

my $protinfo = new SBEAMS::PeptideAtlas::ProtInfo;
$protinfo->setSBEAMS($sbeams);


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);
our @EXPORT = qw(
 pa_build_info_2_tsv
);


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
    return($VERBOSE);
} # end setVERBOSE



###############################################################################
# pa_build_info_2_tsv
###############################################################################
sub pa_build_info_2_tsv {

  my $METHOD = 'pa_build_info_2_tsv';
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $VERBOSE = $args{'verbose'};
  my $QUIET = $args{'quiet'};
  my $TESTONLY = $args{'testonly'};
  my $DEBUG = $args{'debug'};

  #### Get the current atlas_build_id based on parameters or session
  my $atlas_build_id = $sbeamsMOD->getCurrentAtlasBuildID(parameters_ref => {});

  #### Get a list of available atlas builds plus some of the info we want
  my $sql = qq~
  SELECT AB.atlas_build_id, atlas_build_name, atlas_build_description,
	 default_atlas_build_id, organism_specialized_build, organism_name,
	 ( SELECT  COUNT(*) cnt
	    FROM $TBAT_PEPTIDE_INSTANCE
	    WHERE atlas_build_id = AB.atlas_build_id ) AS n_distinct,
	 ( SELECT SUM(n_progressive_peptides) 
	   FROM $TBAT_SEARCH_BATCH_STATISTICS SBS JOIN
		$TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB 
	     ON ABSB.atlas_build_search_batch_id = SBS.atlas_build_search_batch_id
	   WHERE atlas_build_id = AB.atlas_build_id ) AS n_distinct_2,
	 AB.probability_threshold, AB.protpro_PSM_FDR_per_expt
  FROM $TBAT_ATLAS_BUILD AB JOIN $TBAT_BIOSEQUENCE_SET BS
    ON AB.biosequence_set_id = BS.biosequence_set_id
  JOIN $TB_ORGANISM O ON BS.organism_id = O.organism_id
  LEFT JOIN $TBAT_DEFAULT_ATLAS_BUILD DAB 
    ON DAB.atlas_build_id = AB.atlas_build_id
  WHERE  AB.atlas_build_id IN
	( SELECT DISTINCT atlas_build_id FROM $TBAT_PEPTIDE_INSTANCE )
  AND ( DAB.record_status IS NULL OR DAB.record_status != 'D' )
  AND AB.record_status != 'D'
  AND BS.record_status != 'D'
  AND NOT ( DAB.organism_id IS NULL 
	    AND default_atlas_build_id IS NOT NULL ) -- keep global default from showing up 2x
  ORDER BY BS.organism_id DESC, organism_specialized_build, 
	   AB.atlas_build_id DESC
  ~;
  my @atlas_builds = $sbeams->selectSeveralColumns($sql);
  $log->debug( $sbeams->evalSQL($sql) );

  my $atlas_build_id_idx = 0;
  my $atlas_build_name_idx = 1;
  my $atlas_build_descr_idx = 2;
  my $def_build_id_idx = 3;
  my $org_spec_build_idx = 4;
  my $org_name_idx = 5;
  my $dist_peps_idx = 6;
  my $dist_peps_2_idx = 7;   #this can undercount; it's based on experiment_contribution_summary.out
  my $prob_threshold_idx = 8;
  my $psm_fdr_cutoff_idx = 9;


  ### IF YOU CHANGE THE INDICES BELOW, CHANGE IN EXACTLY THE SAME WAY
  ### IN THE buildInfo CGI. There is surely a better way to do this; feel
  ### free!
  my $build_name_idx = 0;
  my $org_idx = 1;
  my $peptide_inclusion_idx = 2;
  my $smpl_count_idx = 3;
  my $spectra_searched_idx = 4;
  my $psm_count_idx = 5;
  my $distinct_peps_idx = 6;
  my $n_canonicals_idx = 7;
  my $n_canon_dist_idx = 8;
  my $n_disting_prots_idx = 9;
  my $n_seq_unique_prots_idx = 10;
  my $n_swiss_idx = 11;
  my $n_covering_idx = 12;
  my $descr_idx = 13;
  my $atlas_build_id_output_idx = 14;
  my $ncols = 15;

  my @headers;
  $headers[$build_name_idx] = 'Build Name';
  $headers[$distinct_peps_idx] = 'distinct peptides';
  $headers[$smpl_count_idx] = 'samples';
  $headers[$org_idx] = 'Organism';
  $headers[$peptide_inclusion_idx] = 'Peptide Inclusion Cutoff';
  $headers[$descr_idx] = 'Description';
  $headers[$psm_count_idx] = 'peptide spectrum matches';
  $headers[$spectra_searched_idx] = 'spectra searched';
  $headers[$n_canonicals_idx] = 'canonical proteins';
  $headers[$n_canon_dist_idx] = 'canonical + possibly distinguished proteins';
  $headers[$n_disting_prots_idx] = 'peptide set unique proteins';
  $headers[$n_seq_unique_prots_idx] = 'sequence unique proteins';
  #$headers[$n_swiss_idx] = 'Core Swiss-Prot identifiers covered';
  $headers[$n_swiss_idx] = 'Swiss-Prot IDs covered';
  $headers[$n_covering_idx] = 'covering set';
  $headers[$atlas_build_id_output_idx] = 'Build ID';


  # Define header row

  # Print header into .tsv file
  my $tsv_file = "$PHYSICAL_BASE_DIR/tmp/buildInfo.tsv";
  my $scratch_file = $tsv_file . "_scratch";
  my $save_file = $tsv_file . "_save";
  print "Trying to print to $tsv_file.\n" if $VERBOSE;
  open (SCRATCH, ">$scratch_file") || print "Can't open $scratch_file for writing.\n";
  for (my $i=0; $i<$ncols; $i++) {
    print SCRATCH "$headers[$i]";
    if ($i < $ncols-1) {
      print SCRATCH "\t";
    } else {
      print SCRATCH "\n";
    }
  }

  ### For each build, get the info we want to display.
  my $nbuilds = scalar @atlas_builds;
  print "Getting info for each of $nbuilds builds: \n" if $VERBOSE;
  foreach my $atlas_build ( @atlas_builds ) {
    my @row;
    my $selected = '';

    print "#$atlas_build->[$atlas_build_id_idx] " if $VERBOSE;

    # Retrieve the infos
    my $samples_href = get_sample_info (
      build_id => $atlas_build->[$atlas_build_id_idx],
    );

    my $spectra_searched_href = get_spectra_searched (
      build_id => $atlas_build->[$atlas_build_id_idx],
    );

    # get 7 different protein counts. could be faster.
    my $prot_count_href;
    $prot_count_href = get_protein_identification_count (
      build_id => $atlas_build->[$atlas_build_id_idx],
      presence_level => 'canonical',
    );
    my $canonical_count = $prot_count_href->{nprots};
    $prot_count_href = get_protein_identification_count (
      build_id => $atlas_build->[$atlas_build_id_idx],
      presence_level => 'possibly_distinguished',
    );
    my $poss_dist_count = $prot_count_href->{nprots};
    $prot_count_href = get_protein_identification_count (
      build_id => $atlas_build->[$atlas_build_id_idx],
      presence_level => 'marginally distinguished',
    );
    $poss_dist_count += $prot_count_href->{nprots};
    $prot_count_href = get_protein_identification_count (
      build_id => $atlas_build->[$atlas_build_id_idx],
      presence_level => 'subsumed',
    );
    my $subsumed_count = $prot_count_href->{nprots};
    $prot_count_href = get_protein_identification_count (
      build_id => $atlas_build->[$atlas_build_id_idx],
      presence_level => 'ntt-subsumed',
    );
    my $ntt_subsumed_count = $prot_count_href->{nprots};
    $prot_count_href = get_covering_set_count (
      build_id => $atlas_build->[$atlas_build_id_idx],
    );
    my $covering_count = $prot_count_href->{nprots};
    $prot_count_href = get_protein_relationship_count (
      build_id => $atlas_build->[$atlas_build_id_idx],
      relationship_name => 'indistinguishable',
    );
    my $indistinguishable_count = $prot_count_href->{nprots};
    my $swiss_count = get_swissprot_coverage (
      build_id => $atlas_build->[$atlas_build_id_idx],
    );
    print "$atlas_build->[$atlas_build_name_idx] $swiss_count\n" if $VERBOSE;

    my $canon_dist_count = $canonical_count + $poss_dist_count || "";

    my $distinguishable_prot_count = 
	 $canonical_count +
	 $poss_dist_count +
	 $subsumed_count +
	 $ntt_subsumed_count || "";

    my $sequence_unique_prot_count = 
	 $canonical_count +
	 $poss_dist_count +
	 $subsumed_count +
	 $ntt_subsumed_count +
	 $indistinguishable_count || "";


    if ($atlas_build->[$atlas_build_id_idx] == $atlas_build_id) {
      $selected = 'CHECKED ';
    }
    if ( !$atlas_build->[$def_build_id_idx] ) {
      if ( $selected ne 'CHECKED ' ) { # We will show the current build regardless
	$log->debug( "checking is $atlas_build->[$atlas_build_id_idx]" );
      }
    } 

    # Create a string for Peptide Inclusion Cutoff
    my $prob = $atlas_build->[$prob_threshold_idx];
    my $protpro_PSM_FDR_per_expt = $atlas_build->[$psm_fdr_cutoff_idx];
    $prob = sprintf("%.2f", $prob);
    my $cutoff_str;
    if ($protpro_PSM_FDR_per_expt > 0) {
      $cutoff_str = sprintf "%0.15f", $protpro_PSM_FDR_per_expt;
      $cutoff_str =~ /0\.(0+)(\d+)/;
      my $num = length($1) +1 ;
      my $str = "%.$num".'f';
      $cutoff_str = sprintf($str, $cutoff_str);
      $cutoff_str = "PSM FDR = " . $cutoff_str;
    } elsif ($prob <= 0) {
      $cutoff_str = "Multiple";
    } else {
      $cutoff_str = "P >= $prob";
    }

    # Store the infos into the @row 

    $row[$atlas_build_id_output_idx] = $atlas_build->[$atlas_build_id_idx];
    $row[$build_name_idx] = qq~<A HREF=buildDetails?atlas_build_id=$atlas_build->[$atlas_build_id_idx] TITLE="View details of Atlas Build $atlas_build->[$atlas_build_name_idx]">$atlas_build->[$atlas_build_name_idx]</A>~;

    $row[$distinct_peps_idx] =qq~<A HREF=GetPeptides?atlas_build_id=$atlas_build->[$atlas_build_id_idx]&apply_action=QUERY TITLE="Retrieve distinct peptides for Atlas Build $atlas_build->[$atlas_build_name_idx]">$atlas_build->[$dist_peps_idx]</A>~;
  
    $row[$org_idx] = $atlas_build->[$org_name_idx];
    $row[$peptide_inclusion_idx] = $cutoff_str;

    $row[$smpl_count_idx] = qq~<A HREF=buildDetails?atlas_build_id=$atlas_build->[$atlas_build_id_idx] TITLE="View samples included in Atlas Build $atlas_build->[$atlas_build_name_idx]">$samples_href->{smpl_count}</A>~;

    $row[$psm_count_idx] = $samples_href->{psm_count};
    $row[$spectra_searched_idx] = $spectra_searched_href->{nspec};
    $row[$n_canonicals_idx] = qq~<A HREF=GetProteins?atlas_build_id=$atlas_build->[$atlas_build_id_idx]&presence_level_constraint=1&redundancy_constraint=4&apply_action=QUERY TITLE="Retrieve canonical protein list for Atlas Build $atlas_build->[$atlas_build_name_idx]">$canonical_count</A>~;

    $row[$n_covering_idx] = qq~<A HREF=GetProteins?atlas_build_id=$atlas_build->[$atlas_build_id_idx]&redundancy_constraint=4&covering_constraint=on&apply_action=QUERY TITLE="Retrieve protein list sufficient to explain all peptides observed in Atlas Build $atlas_build->[$atlas_build_name_idx]">$covering_count</A>~;

    $row[$n_canon_dist_idx] = qq~<A HREF=GetProteins?atlas_build_id=$atlas_build->[$atlas_build_id_idx]&presence_level_constraint=1,2&redundancy_constraint=4&apply_action=QUERY TITLE="Retrieve canonical and possibly-distinguished protein list for Atlas Build $atlas_build->[$atlas_build_name_idx]">$canon_dist_count</A>~;

    $row[$n_disting_prots_idx] = qq~<A HREF=GetProteins?atlas_build_id=$atlas_build->[$atlas_build_id_idx]&redundancy_constraint=4&apply_action=QUERY TITLE="Retrieve one protein per distinct peptide set for Atlas Build $atlas_build->[$atlas_build_name_idx]">$distinguishable_prot_count</A>~;

    $row[$n_seq_unique_prots_idx] = qq~<A HREF=GetProteins?atlas_build_id=$atlas_build->[$atlas_build_id_idx]&redundancy_constraint=1&apply_action=QUERY TITLE="Retrieve a list of sequence-unique proteins for Atlas Build $atlas_build->[$atlas_build_name_idx]">$sequence_unique_prot_count</A>~;

# The following query doesn't match splice variants.
# Correct pattern to match is [ABOPQ]_____;[ABOPQ]_____-%  but the
# semi-colon is interpreted as a param separator and quotes, backslashes do not
# escape it effectively. Is problem in DBInterface.pm, parse_input_parameters?
    if ($swiss_count) {
      $row[$n_swiss_idx] = qq~<A HREF=GetProteins?&atlas_build_id=$atlas_build->[$atlas_build_id_idx]&redundancy_constraint=4&biosequence_name_constraint=[ABOPQ]_____&apply_action=QUERY TITLE="Retrieve all Swiss-Prot identifiers in Atlas Build $atlas_build->[$atlas_build_name_idx]">$swiss_count</A>~;

    } else {
      $row[$n_swiss_idx] = '';
    }
    
    # Remove newlines from description.
    $atlas_build->[$atlas_build_descr_idx] =~ s/\r\n/ /g;
    $row[$descr_idx] = $sbeams->truncateStringWithMouseover( string => $atlas_build->[$atlas_build_descr_idx], len => 50 );
#      $row[$is_def_idx] = $atlas_build->[$org_spec_build_idx] || '';
#      $row[$is_def_idx] = ( !$atlas_build->[$def_build_id_idx] ) ? 'N' : ( $row[$is_def_idx] ) ?
#                "<SPAN CLASS=popup_help TITLE='$atlas_build->[$org_spec_build_idx]'>Y</SPAN>" : 'Y';


    # Print the row into .tsv file
    for (my $i=0; $i< $ncols; $i++) {
      print SCRATCH "$row[$i]";
      if ($i < $ncols-1) {
	print SCRATCH "\t";
      } else {
	print SCRATCH "\n";
      }
    }
  }
  print "\n" if $VERBOSE;
  close SCRATCH;

  if (-e $tsv_file) {
    `mv $tsv_file $save_file`;
  }
  `mv $scratch_file $tsv_file`;

} # end pa_build_info_2_tsv



#########################################################################
#
# Subroutines to fetch the data we want to display.
#
#########################################################################

sub get_sample_info
{
  my %args = @_;

  #### Process the arguments list
  my $build_id = $args{'build_id'}
      || die "atlas_build_id not passed";

  my %result_hash = ();

  my $pep_count = $sbeams->selectrow_hashref( <<"  PEP" );  
  SELECT COUNT(*) cnt,  SUM(n_observations) obs
  FROM $TBAT_PEPTIDE_INSTANCE
  WHERE atlas_build_id = $build_id
  PEP

  my $multi_pep_count = $sbeams->selectrow_hashref( <<"  MPEP" );
  SELECT COUNT(*) cnt, SUM(n_observations) obs
  FROM $TBAT_PEPTIDE_INSTANCE
  WHERE atlas_build_id = $build_id
  AND n_observations > 1
  MPEP

  my $smpl_count = $sbeams->selectrow_hashref( <<"  SMPL" );
  SELECT COUNT(*) cnt FROM $TBAT_ATLAS_BUILD_SAMPLE
  WHERE atlas_build_id = $build_id
  SMPL


  %result_hash = (
    pep_count => $pep_count->{cnt},
    multi_pep_count => $multi_pep_count->{cnt},
    smpl_count => $smpl_count->{cnt},
    psm_count => $pep_count->{obs},
  );

  return \%result_hash;

}

sub get_spectra_searched
{
  my %args = @_;

  my $build_id = $args{'build_id'}
      || die "atlas_build_id not passed";

  my $sql =<<"  END";
  SELECT ABS.atlas_build_id ab, SUM(SBS.n_searched_spectra) nspec ,
         SUM(n_good_spectra) ngoodspec
  FROM $TBAT_SEARCH_BATCH_STATISTICS SBS JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
    ON ABSB.atlas_build_search_batch_id = SBS.atlas_build_search_batch_id
  JOIN $TBAT_SAMPLE S ON s.sample_id = ABSB.sample_id
  JOIN $TBAT_ATLAS_BUILD_SAMPLE ABS ON ( s.sample_id = ABS.sample_id )
  JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON ( ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id )
  WHERE ABS.atlas_build_id = $build_id
  AND ABSB.atlas_build_id = $build_id
  GROUP BY ABS.atlas_build_id
  END

  my $result_hash = $sbeams->selectrow_hashref( $sql );
 
  return $result_hash;
  
}

sub get_protein_identification_count
{
  my %args = @_;

  my $build_id = $args{'build_id'}
      || die "atlas_build_id not passed";
  my $presence_level = $args{'presence_level'}
      || die "presence_level not passed";
  my $count_decoys = $args{'count_decoys'} || 0;
  my $count_crap = $args{'count_crap'} || 0;

  my $decoy_clause = " ";
  if (! $count_decoys) {
    $decoy_clause = "AND NOT BS.biosequence_name LIKE \'DECOY%\'";
  }

  my $crap_clause = " ";
  if (! $count_crap) {
    $crap_clause = "AND NOT BS.biosequence_desc LIKE \'%common contaminant%\'";
  }

  my $sql =<<"  END";
  SELECT PI.atlas_build_id ab, COUNT(PI.biosequence_id) nprots
  FROM $TBAT_PROTEIN_IDENTIFICATION PI
    JOIN $TBAT_PROTEIN_PRESENCE_LEVEL PPL ON
     PPL.protein_presence_level_id = PI.presence_level_id
    JOIN $TBAT_BIOSEQUENCE BS ON 
     BS.biosequence_id = PI.biosequence_id
  WHERE PI.atlas_build_id = $build_id
  AND PPL.level_name = \'$presence_level\'
  $decoy_clause
  $crap_clause
  GROUP BY PI.atlas_build_id
  END

  my $result_hash = $sbeams->selectrow_hashref( $sql );
 
  return $result_hash;
}

  
sub get_covering_set_count
{
  my %args = @_;

  my $build_id = $args{'build_id'}
      || die "atlas_build_id not passed";
  my $count_decoys = $args{'count_decoys'} || 0;
  my $count_crap = $args{'count_crap'} || 0;

  my $decoy_clause = " ";
  if (! $count_decoys) {
    $decoy_clause = "AND NOT BS.biosequence_name LIKE \'DECOY%\'";
  }

  my $crap_clause = " ";
  if (! $count_crap) {
    $crap_clause = "AND NOT BS.biosequence_desc LIKE \'%common contaminant%\'";
  }

  my $sql =<<"  END";
  SELECT PI.atlas_build_id ab, COUNT(PI.biosequence_id) nprots
  FROM $TBAT_PROTEIN_IDENTIFICATION PI
    JOIN $TBAT_BIOSEQUENCE BS ON 
     BS.biosequence_id = PI.biosequence_id
  WHERE PI.atlas_build_id = $build_id
  AND PI.is_covering = 1
  $decoy_clause
  $crap_clause
  GROUP BY PI.atlas_build_id
  END

  my $result_hash = $sbeams->selectrow_hashref( $sql );
 
  return $result_hash;
}

  
sub get_protein_relationship_count
{
  my %args = @_;

  my $build_id = $args{'build_id'}
      || die "atlas_build_id not passed";
  my $relationship_name = $args{'relationship_name'}
      || die "relationship_name not passed";
  my $count_decoys = $args{'count_decoys'} || 0;
  my $count_crap = $args{'count_crap'} || 0;

  my $decoy_clause = " ";
  if (! $count_decoys) {
    $decoy_clause = "AND NOT BS.biosequence_name LIKE \'DECOY%\'";
  }

  my $crap_clause = " ";
  if (! $count_crap) {
    $crap_clause = "AND NOT BS.biosequence_desc LIKE \'%common contaminant%\'";
  }

  my $sql =<<"  END";
  SELECT BR.atlas_build_id ab, COUNT(BR.related_biosequence_id) nprots
  FROM $TBAT_BIOSEQUENCE_RELATIONSHIP BR  JOIN
    $TBAT_BIOSEQUENCE_RELATIONSHIP_TYPE BRT ON
     BRT.biosequence_relationship_type_id = BR.relationship_type_id
    JOIN $TBAT_BIOSEQUENCE BS ON 
     BS.biosequence_id = BR.related_biosequence_id
  WHERE BR.atlas_build_id = $build_id
  AND BRT.relationship_name = \'$relationship_name\'
  $decoy_clause
  $crap_clause
  GROUP BY BR.atlas_build_id
  END

  my $result_hash = $sbeams->selectrow_hashref( $sql );
 
  return $result_hash;
}

sub get_swissprot_coverage
{
  my %args = @_;

  my $build_id = $args{'build_id'}
      || die "atlas_build_id not passed";
#--------------------------------------------------
#   my $count_decoys = $args{'count_decoys'} || 0;
#   my $count_crap = $args{'count_crap'} || 0;
# 
#   my $decoy_clause = " ";
#   if (! $count_decoys) {
#     $decoy_clause = "AND NOT BS.biosequence_name LIKE \'DECOY%\'";
#   }
# 
#   my $crap_clause = " ";
#   if (! $count_crap) {
#     $crap_clause = "AND NOT BS.biosequence_desc LIKE \'%common contaminant%\'";
#   }
# 
#   # Get the exhaustive list -- the list of all protein identifiers
#   # in this atlas.
#   my $sql =<<"  END";
#   (
#     SELECT BS.biosequence_name as bsid
#     FROM $TBAT_BIOSEQUENCE_RELATIONSHIP BR 
#       JOIN $TBAT_BIOSEQUENCE BS ON 
#        BS.biosequence_id = BR.related_biosequence_id
#     WHERE BR.atlas_build_id = $build_id
#     $decoy_clause
#     $crap_clause
#   )
#   UNION
#   (
#     SELECT BS.biosequence_name as bsid
#     FROM $TBAT_PROTEIN_IDENTIFICATION PID
#       JOIN $TBAT_BIOSEQUENCE BS ON 
#        BS.biosequence_id = PID.biosequence_id
#     WHERE PID.atlas_build_id = $build_id
#     $decoy_clause
#     $crap_clause
#   )
#   END
# 
#   my @exhaustive_set = $sbeams->selectOneColumn($sql);
#-------------------------------------------------- 

  my $build_swiss_href = $protinfo->get_swiss_idents_in_build(
      atlas_build_id=>$build_id);

  # Now, count distinct 6-char Swiss-Prot identifiers. If P12345 and P12345-3
  # are both in the atlas, just count it once.
  my %swiss_prot_hash;
  for my $protid (keys %{$build_swiss_href}) {
    $swiss_prot_hash{$protid} = 1 if $protid =~ /^[ABCOPQ]\w{5}$/;
  }
  my @swiss_prot_varsplic_ids = grep( /^[ABOPQ]\w{5}-\d{1,3}$/ ,
    keys %{$build_swiss_href} );
  for my $swiss_id (@swiss_prot_varsplic_ids) {
    # Strip off the varsplic suffix to get the basic 6-char identifier.
    $swiss_id =~ /^([ABOPQ]\w{5})/;
    $swiss_id = $1;
    $swiss_prot_hash{$swiss_id} = 1;
  }
  my $n_swiss = scalar keys %swiss_prot_hash;
  
  return $n_swiss;
}
###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Terry Farrah (tfarrah@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
