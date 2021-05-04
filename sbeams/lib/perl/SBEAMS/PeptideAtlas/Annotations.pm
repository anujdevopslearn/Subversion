package SBEAMS::PeptideAtlas::Annotations;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::Annotations
#
=head1 SBEAMS::PeptideAtlas::Annotations

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::Annotations

=head2 DESCRIPTION

This is part of SBEAMS::PeptideAtlas which handles peptide annotations
and related items.

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::TraMLParser;



###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);

#
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

## MRM transitions - modified_peptide_annotations

#+
# Insert data
#-
sub insert_transition_data {
  my $self = shift;
  my %args = @_;

  $args{verbose} ||= 0;
  $args{testonly} ||= 0;

  return '' unless $args{set_name};
  my @inserted_ids;

  # start transaction
#  $sbeams->initiate_transaction();
  $log->info( "Initiate" );

  for my $trns ( @{$self->{mrm_data}} ) {
    
#    for my $k ( sort( keys( %$trns ) ) ) { $log->info( "$k => $trns->{$k}" ); }

    # modified_peptide_sequence - generate matching sequence
    $trns->{peptide_sequence} = strip_mods($trns->{modified_peptide_sequence});
     
    # Check for peptide ID, generate one if necessary
    $trns->{peptide_id} = $self->getPeptideId( seq => $trns->{peptide_sequence} );
    if ( !$trns->{peptide_id} ) {
      $log->warn( "skipping $trns->{peptide_sequence}, no peptide accession" );
      # Skip this for now
      next;
      $self->addNewPeptide( seq => $trns->{peptide_sequence} );
      $trns->{peptide_id} = $self->getPeptideId( seq => $trns->{peptide_sequence} );
    }

    if ( !$trns->{peptide_id} ) {
      # Is it OK to fail?  Not for now!
      my $insert = "INSERT INTO $TBAT_MODIFIED_PEPTIDE_ANNOTATION ( " . join( ", ". keys( %$trns ) ) . " ) VALUES ( '" . join( "','". values( %$trns ) ) . "');";
      $log->error( $insert );
#      $sbeams->rollback_transaction();
      # Set error
      # redirect
#      exit 1;
    }
  
    # peptide_charge - OK
    # Q1_mz 
    # Q3_mz 
    # Q3_ion_label

    # transition_suitability_level_id
    $log->debug(  $trns->{transition_suitability_level_id} );
    $trns->{transition_suitability_level_id} = $self->get_suitability_level( $trns->{transition_suitability_level_id} );

    # publication_id
    $trns->{publication_id} = $self->get_publication( title => $trns->{publication_id} );
  
    # annotator_name
    $trns->{annotator_name} ||= 'Anon';
    $trns->{annotator_contact_id} = ( $sbeams->isGuestUser() ) ? '' : $sbeams->getCurrent_contact_id();
 
    # project_id 
    $trns->{project_id} = $sbeams->getCurrent_project_id;

    $trns->{annotation_set} = $args{set_name};
  
    # collision_energy
    # retention_time
    # instrument
    # comment 
    # Q3_peak_intensity

    my $mpa_id = $sbeams->updateOrInsertRow ( table_name => $TBAT_MODIFIED_PEPTIDE_ANNOTATION,
                                                  insert => 1,
                                             rowdata_ref => $trns,
                                                      PK => 'modified_peptide_annotation_id',
                                               return_PK => 1,
                                    add_audit_parameters => 1,
                                                 verbose => $args{verbose},
                                                testonly => $args{testonly},
                                            );
    $log->debug( "tried insert, got $mpa_id back!" );
    push @inserted_ids, $mpa_id;
  }
#  $sbeams->rollback_transaction();
#  $sbeams->commit_transaction();
  return \@inserted_ids;
 
  # commit
}

sub strip_mods {
  my $seq = shift;
  $log->info( "In is $seq" );
  $seq =~ s/\[[^\]]+\]//g;
  $log->info( "Out is $seq" );
  return $seq;
}


#+
# 
#-
sub get_suitability_level {
  my $self = shift;
  my $level = shift;
  if ( ! $self->{suitability_levels} ) {
    $self->{suitability_levels} = {};
    my @results = $sbeams->selectSeveralColumns( <<"    END" );
    SELECT transition_suitability_level_id, level_name
    FROM $TBAT_TRANSITION_SUITABILITY_LEVEL
    END
    for my $row ( @results ) {
      $self->{suitability_level}->{uc($row->[1])} = $row->[0];
    }
  }

  for my $key ( keys( %{$self->{suitability_level}} ) ) {
    return $self->{suitability_level}->{$key} if $key eq uc($level);
  }
  # Default
  return $self->{suitability_level}->{OK};
}

#+ 
#  These come primarily from the modified_peptide_annotations table
#- 
sub get_mrm_transitions_acc_list {
  my $self = shift;
  my %args = @_;

  return unless $args{accessions};
  my $acc_string =  "'" . join( "', '", @{$args{accessions}} ) . "'";

  my $sbeams = $self->getSBEAMS();

  # Project control
  my @accessible = $sbeams->getAccessibleProjects();
  my $projects = join( ",", @accessible );
  return '' unless $projects;

  my $sql =<<"  END";
  SELECT
  peptide_accession,
  modified_peptide_sequence,
  peptide_charge, 
  Q1_mz,
  Q3_mz,
  Q3_ion_label,  
  Q3_peak_intensity,
  collision_energy,
  retention_time,
  ssrcalc_relative_hydrophobicity,
  instrument,
  CASE WHEN contact_id IS NULL 
    THEN annotator_name 
    ELSE username 
    END AS name,
  level_name
  FROM $TBAT_MODIFIED_PEPTIDE_ANNOTATION MPA 
  JOIN $TBAT_PEPTIDE P ON MPA.peptide_id = P.peptide_id
  JOIN $TBAT_TRANSITION_SUITABILITY_LEVEL TSL 
    ON TSL.transition_suitability_level_id = MPA.transition_suitability_level_id
  LEFT JOIN $TB_USER_LOGIN UL ON UL.contact_id = MPA.annotator_contact_id
  WHERE peptide_accession IN ( $acc_string )
  AND project_id IN ( $projects )
  AND level_score > 0.8
  ORDER BY peptide_accession, modified_peptide_sequence, peptide_charge DESC, level_score DESC, Q3_peak_intensity DESC, Q3_mz
  END
  my @rows = $sbeams->selectSeveralColumns($sql);
  return \@rows;
}

sub get_mrm_transitions {
  my $self = shift;
  my %args = @_;

  my $where = '';
  if ( !$args{peptides} && $args{accessions} ) {
#   return $self->get_mrm_transitions_acc_list( %args );
    my $acc_string =  "'" . join( "', '", @{$args{accessions}} ) . "'";
    $where = " WHERE peptide_accession IN ( $acc_string ) ";
  } else {

    my %peps;
    my $pep_str;
    my $sep = '';
    for my $pep ( @{$args{peptides}} ) {
      next if $peps{$pep};
      $pep_str .= $sep . "'" . $pep . "'";
      $sep = ',';
    }
    $where = " WHERE stripped_peptide_sequence IN ( $pep_str ) ";
  }

  my $sbeams = $self->getSBEAMS();

  # Project control
  my @accessible = $sbeams->getAccessibleProjects();
  my $projects = join( ",", @accessible );
  return '' unless $projects;

  my $sql =<<"  END";
  SELECT
  peptide_accession,
  stripped_peptide_sequence,
  peptide_charge, 
  Q1_mz,
  Q3_mz,
  Q3_ion_label,  
  '' AS intensity,
  collision_energy,
  retention_time,
  ssrcalc_relative_hydrophobicity,
  '' AS instrument,
  set_tag,
  level_name
  FROM $TBAT_SRM_TRANSITION ST 
  JOIN $TBAT_SRM_TRANSITION_SET STS 
    ON ST.srm_transition_set_id = STS.srm_transition_set_id
  LEFT JOIN $TBAT_PEPTIDE P
    ON ST.stripped_peptide_sequence = P.peptide_sequence
  JOIN $TBAT_TRANSITION_SUITABILITY_LEVEL TSL 
    ON TSL.transition_suitability_level_id = ST.transition_suitability_level_id
  $where
  AND IS_PUBLIC = 'Y'
--  AND project_id IN ( $projects )
--  AND level_score > 0.8
  ORDER BY peptide_accession, peptide_sequence, Q1_mz, level_score DESC, Q3_mz
  END
  $log->debug( $sql );

  my @rows = $sbeams->selectSeveralColumns($sql);
  return \@rows;
}


# STUB
sub get_publication {
  return '';
}

#+
#
#-
sub get_PATR_peptides {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();

# No project id in PATR
#  my @accessible = $sbeams->getAccessibleProjects();
#  my $projects = join( ",", @accessible );
#  return '' unless $projects;

  my $sql = qq~
  SELECT DISTINCT stripped_peptide_sequence
  FROM $TBAT_SRM_TRANSITION
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my %peptides;
  while ( my @row = $sth->fetchrow_array() ) {
    $peptides{$row[0]}++;
  }
  return \%peptides;
}

##
#+
# Check and cache headers, validate data format
#-
sub validate_transition_data {
  my $self = shift;
  $sbeams = $self->getSBEAMS();
  my %args = @_;
  my $file = $args{transition_file_data} || return '';
  my $cnt = 1;

  $self->{mrm_data} ||= [];
  if ( $args{type} eq 'tabtext' ) {
    for my $line ( @$file ) {
      $log->debug( "Line " . $cnt++ );
      chomp $line;
      my @line = split("\t", $line, -1);
      if ( !$self->{mrm_headers} ) {
        my $std_headers = $self->get_std_transition_headers();
        $self->{mrm_headers} = \@line;
        $self->{mrm_headers_idx} = {};
        my $idx = 0;
        for my $col ( @line ) {
          if ( $std_headers->[$idx] ne $col ) {
            $log->debug( "Non-standard header $col (expected $std_headers->[$idx] at idx $idx)" );
            return undef;
          }
          $self->{mrm_headers_idx}->{$idx} = $col;
          $idx++;
        }
        next;
      }
      my $data_ref = $self->transitions_as_hashref( \@line );
      push @{$self->{mrm_data}}, $data_ref;
    }
    return 1;
  } elsif ( $args{type} eq 'traml' ) {
    my $tparse = new SBEAMS::PeptideAtlas::TraMLParser;
    my $tstring = join( "", @$file );
    $tparse->set_string( xml => $tstring );
    $tparse->parse();
    my $trans = $tparse->getTransitions();
    my $converted = $self->traml_trans_hashref( traml_trans => $trans );
    push @{$self->{mrm_data}}, @$converted;
  }
}

# Hack alert!  Danger!
sub traml_trans_hashref {
  my $self = shift;
  my %args = @_;
# traml_transitions
  return unless $args{traml_trans};
  my @converted;
  for my $tt ( @{$args{traml_trans}} ) {
    my $row = { modified_peptide_sequence => $tt->{modifiedSequence},
                peptide_charge => $tt->{precursorCharge},
                Q1_mz => $tt->{precursorMz},
                Q3_mz => $tt->{fragmentMz},
                Q3_ion_label => $tt->{fragmentType},
                transition_suitability_level_id => 'OK',
                publication_id => undef,
                annotator_name => $tt->{contactName},
                collision_energy => $tt->{collisionEnergy},
                retention_time => $tt->{retentionTime},
                instrument => $tt->{instrument},
                comment => $tt->{comment},
                Q3_peak_intensity => $tt->{relativeIntensity} 
              };

    push @converted, $row;
  }
  return \@converted;
} # End convert_traml_transitions




sub get_std_transition_headers {
  my $self = shift;
  my @std_headers = qw( modified_peptide_sequence peptide_charge Q1_mz Q3_mz Q3_ion_label transition_suitability_level_id publication_id annotator_name collision_energy retention_time instrument comment Q3_peak_intensity );
  return \@std_headers;
}

#+
# Unified source for column definitions 
#-
sub get_column_defs {
  my $self = shift;
  my %args = @_;

  my %coldefs = ( 
			' QTRAP ' => 'Chromatogram from SCIEX QTRAP 5500 showing ion intensity over time',
			'6460 QQQ' => 'Consensus spectrum from Agilent 6460 QQQ instrument(s)',
			'6460 QQQ ' => 'Chromatogram from Agilent 6460 QQQ showing ion intensity over time',
			'6530 QTOF' => 'Consensus spectrum from Agilent 6530 QTOF instrument(s)',
			'6530 QTOF_CE' => 'Consensus spectra from Agilent 6530 QTOF instrument(s) at various collision energies',
      'Accession' => 'Peptide Accession',
			'APEX' => 'Predicted peptide score calculated by APEX algorithm',
			'Adj SS' => 'Final suitablity score, the greater of ESS and PSS, adjusted by PABST weightings.',
			'Annot' => 'Annotation of peptide features such as missed cleavage (MC), etc.',
      'Annotator' => 'Person/lab who contributed validated transition.',
			'Annotation Set' => 'Set of transitions with which subject transition was uploaded.',
			'Annotator' => 'Person/lab who contributed validated transition.',
			'Best Adj Prob' => 'Highest iProphet-adjusted probablity for this observed sequence',
			'Best Prob' => 'Highest iProphet probability for this observed sequence',
			'Biosequence Name' => 'Protein Name/Accession.',
			'CE' => 'Collision energy, the kinetic energy conferred to the peptide ion and resulting in peptide fragmentation',
			'Canonical Proteins' => 'Minimally redunant set of proteins required to explain (virtually) all non-decoy peptides observed in build',
			'Charge' => 'Charge on peptide ion',
			'Combined Predictor Score' => 'Score genereated based on STEPP, PSieve, ESPP, APEX and DPred scores',
			'DPred' => 'Predicted peptide score calculated by Detectability Predictor algorithm',
			'EOS' => 'Empirical Observability Score, a measure of how many samples a particular peptide is seen in relative to other peptides from the same protein',
			'ESPP' => 'Predicted peptide score calculated by ESPP algorithm',
			'ESS' => 'Empirical suitability score, derived from peptide probability, EOS, and the number of times observed.  This is then adjusted sequence characteristics such as missed cleavage <SUP><FONT COLOR=RED>[MC]</FONT></SUP> or enzyme termini <SUP><FONT COLOR=RED>[ET]</FONT></SUP>, or <BR> multiple genome locations <SUP><FONT COLOR=RED>[MGL]</FONT></SUP>.',
			'Expt' => 'Experiment ID from which this spectrum was obtained',
			'External Links' => 'Links to information about this protein in other resources',
			'Fol AA' => 'Following (towards the C terminus) amino acid',
      'Fragmentation Type' => 'Fragmentation method used to generate spectrum. IT = IonTrap, CID = Collision Induced Dissociation, etc.',
			'IT' => 'Consensus spectrum from Ion Trap instrument(s)',
			'InNextProt' => 'PTM site annotated in neXtprot',
			'InUniprot' => 'PTM site annotated in Uniprot',
			'Instr' => 'Model of mass spectrometer.',
			#'Intensity' => 'Relative intensity of peak in CID spectrum, scaled to 10000 units',
      'Intensity' => 'Relative intensity of peak in CID spectrum',
			'Ion' => 'Ion-series designation for fragment ion (Q3).',
			'IonTrap' => 'Consensus spectrum from Ion Trap instrument(s)',
      'Prob'    => 'Probability assigned peptide-spectrum match (iProphet)', 
      'Label'   => 'Ion-series designation for fragment ion (Q3).', 
      'Modified Sequence' => 'Amino acid sequence of detected pepide, including any mass modifications',
			'MSS' => 'Merged suitability score, greater of ESS and PSS',
			'N ENSG Mapping' => 'Number of Ensembl gene mapping',
			'N ENSP Mapping' => 'Number of Ensembl protein mapping',
			'N Gen Loc' => 'Number of discrete genome locations which encode this amino acid sequence',
			'N Human Mapping' => 'Number of Human protein mapping, including SwissProt, IPI and Ensembl Proteins',
			'N IPI Mapping' => 'Number of IPI protein mapping',
			'N Mouse Mapping' => 'Number of Mouse protein mapping, including SwissProt, IPI and Ensembl Proteins',
			'N Obs' => 'Total number of observations in all modified forms and charge states',
			'N Prot Map' => 'Number of proteins in the reference database to which this peptide maps',
			'N SP Mapping' => 'Number of SwissProt primary protein mapping',
			'N SP-nsSNP Mapping' => 'Number of SwissProt primary and alternatively-spliced protein mapping, plus nsSNP mapping,<BR>wherein all Swiss-Prot-annotated nsSNPs have been expanded out to sequence with context so that any nsSNP-containing peptides are properly mapped.',
			'N SP-varsplic Mapping' => 'Number of SwissProt primary and alternatively-spliced protein mapping',
			'N Samples' => 'The number of samples in which this sequence was seen',
			'N Yeast Mapping' => 'Number of Yeast protein mapping, including SwissProt, SGD and Ensembl Proteins',
			'NET' => 'Highest number of enzymatic termini for this protein',
			'NMC' => 'Lowest number of missed cleavage for this protein',
			'N_map' => 'Number of proteins in target proteome to which peptide maps',
			'Offset' => 'Residue offset in the protein.',
			'One_mod' => 'The containing peptides have only one observed PTM site.',
			'Org' => 'Organism(s) in which peptide was seen',
			'Over_two_mods' => 'The containing peptides have more than two observed PTM sites.',
			'PATR' => 'Peptide assay defined in transition resource',
			'PSS' => 'Predicted suitability score, derived from combining publicly available algorithms (Peptide Sieve, STEPP, ESPP, APEX, Detectability Predictor)',
			'PSieve' => 'Predicted peptide score calculated by Peptide Sieve algorithm',
			'Parent Peptides' => 'Observed peptides of which this peptide is a subsequence',
			'Peptide Accession' => 'Peptide Atlas accession number, beginning with PAp followed by 9 digits.',
			'Peptide Length' => 'Length of peptide',
			'Pre AA' => 'Preceding (towards the N terminus) amino acid',
			'Pred' => 'Predicted spectrum',
      'Precursor Intensity' => 'Precursor Intensity in Millions',
			'Probability threshold' => 'iProphet probability threshold applied to build',
			'ProtLinks' => 'Links to information about this protein in other resources',
			'Protein' => 'Protein Name/Accession.',
      'Sequence' => 'Amino acid sequence of detected pepide',
      'Spectrum' => 'Link to display of actual spectrum',
			'Q1_chg' => 'Charge on Q1 (precursor) peptide ion.',
			'Q1_mz' => 'Mass to charge ratio of Q1 (precursor) peptide ion.',
			'Q3_chg' => 'Charge on Q3 (fragment) ion.',
			'Q3_mz' => 'Mass to charge ratio of Q3 (fragment) ion.',
			'QQQ' => 'Consensus spectrum from Agilent 6460 QQQ instrument(s)',
			'QQQ ' => 'Chromatogram from Agilent 6460 QQQ showing ion intensity over time',
			'QQQ_ch' => 'Chromatogram from Agilent 6460 QQQ showing ion intensity over time',
			'QTOF' => 'Consensus spectrum from Agilent 6530 QTOF instrument(s)',
			'QTOF_CE' => 'Consensus spectra from Agilent 6530 QTOF instrument(s) at various collision energies',
			'QTRAP' => 'Consensus spectrum from SCIEX QTRAP 5500 instrument(s)',
			'QTRAP ' => 'Chromatogram from SCIEX QTRAP 5500 showing ion intensity over time',
			'QTRAP 5500' => 'Consensus spectrum from SCIEX QTRAP 5500 instrument(s)',
			'QTrap' => 'Consensus spectrum from SCIEX QTRAP 5500 instrument(s)',
			'QTrap  ' => 'Chromatogram from SCIEX QTRAP 5500 showing ion intensity over time',
			'QTrap 5500' => 'Consensus spectrum from SCIEX QTRAP 5500 instrument(s)',
			'QTrap5500' => 'Consensus spectrum from SCIEX QTRAP 5500 instrument(s)',
			'QTrap_ch' => 'Chromatogram from SCIEX QTRAP 5500 showing ion intensity over time',
			'Quality' => 'Crude scale of quality for the observation, currently one of Best, OK, and No. ',
			'RI' => 'Relative Intensity of peak in CID spectrum',
			'RT' => 'Peptide retention time( in minutes ) in the LC/MS system.',
			'RT_Cat' => 'Peptide retention time(minutes) on specified LC/MS system.',
			'Rank' => 'PABST Transition rank',
			'Residue' => '',
			'SSRT' => 'Sequence Specific Retention time provides a hydrophobicity measure for each peptide using the algorithm of Krohkin et al. Version 3.0 <A HREF=http://hs2.proteome.ca/SSRCalc/SSRCalc.html target=_blank>[more]</A>',
			'STEPP' => 'Predicted peptide score calculated by STEPP algorithm',
			'Samples' => 'Samples in which this sequence was seen',
			'Sequence' => 'Amino acid sequence of detected pepide, including any mass modifications.',
			'Source' => 'Source from which transitions were obtained',
			'SpecLinks' => 'Links to spectra for this peptide ion in one or more spectral libraries',
			'Src Adj SS' => 'Adj SS weighed by transition source, rewards transitions actually observed in higher-priority instruments (which vary by target instrument).',
			'Start' => 'Start postion in the protein',
			'Subpep of' => 'Number of observed peptides of which this peptide is a subsequence',
      'S/N' => 'Signal to noise',
			'Two_mods' => 'The containing peptides have two observed PTM sites.',
			'enriched-but-non-mod' => 'Number of PSMs covering this site with no phospho modification anywhere on the peptide, but yet originating from a phospho-enriched sample',
      'TIC' => 'Total ion current in Millions',
			'enriched-with-mod' => 'Number of PSMs covering this site with phospho modification on this site, and originating from a phospho-enriched sample',
			'iRT' => 'iRT normalized peptide retention time as per <A HREF=http://tinyurl.com/iRTrefs> Escher et al. 2012 </A> ',
			'nObs' => 'Total observed PTM spectra for the site.',
			'nP.2-.8' => 'PTMProphet probability >= 0.19 and < 0.80',
			'nP<.01' => 'PTMProphet probability < 0.01',
			'nP<.05' => 'PTMProphet probability >= 0.01 and < 0.05',
			'nP<.20' => 'PTMProphet probability >= 0.05 and < 0.19',
			'nP>.80' => 'PTMProphet probability >= 0.80 and < 0.95 ',
			'nP>.95' => 'PTMProphet probability >= 0.95 and < 0.99 ',
			'nP>.99' => 'PTMProphet probability >= 0.99',
			'n_obs' => 'Number of times peptide ion was observed in this particular consensus library',
			'no-choice' => 'Number of PSMs covering this site for which there was no choice in the localization of the PTM. Only one residue was an S, T, or Y',
			'non-enriched' => 'Number of PSMs covering this site with no phospho modification anywhere on the peptide, and originating from a non-enriched sample, typically not searched for phospho',
			#dataset
			 'Datase'=>'Public repository identifier',
			 'MS Runs'=>'The total number of runs for this experiment/dataset.',
			 'Spectra Searched'=> 'The total number of spectra searched in the experiment/dataset ' ,
			 'Spectra ID\'d'=> 'The number of spectra identifed with a probability greater than the atlas threshold ' ,
			 '%Spectra ID\'d'=> '',
			 'Distinct Peptides'=> 'The number of distinct peptide sequences in this build that are seen in this experiment/dataset. ' ,
			 'Unique Peptides'=> "The number of distinct peptides that are seen only in this experiment/dataset (unique contribution).  This discriminates against smaller experiments/dataset, and is less useful in atlas' with a large number of experiments. " ,
			 'Added Peptides'=> 'Order-dependent unique peptides contributed by a given experiment.  The contribution for each experiment/datasets is based on the experiments that have gone before it, so later experiments/datasets tend to have a lower progressive contribution. ' ,
			 'Cumulative Peptides'=> 'Order-dependent cumulative number of unique peptides contributed to build by this and previous experiments/datasets. ' ,
			 'Distinct Canonical Proteins'=> 'The number of canonical (highly distinguishable, non-redundant) protein sequences identified from the peptides in this experiment/dataset.' ,
			 'Unique Canonical Proteins'=> 'The number of canonical proteins that have peptides observed in the sample only.',
			 'Added Canonical Proteins'=> 'Order-dependent unique canonical proteins contributed by a given experiment/dataset.',
			 'Cumulative Canonical Proteins'=> 'Order-dependent cumulative number of canonical proteins contributed to build by this and previous experiments.<br>Counts non-human contaminants, so final tally may be greater than Canonical Proteins count in Build Overview. ' ,

			#batch
			 'Experiment Tag'=> 'Tag for this experiment. ' ,
			 'Unique All Proteins'=> 'The number of proteins (not limited to canonical protein) that have peptides observed in the sample only.',
			 'Date Added'=> '',
			 'Pubmed Id or DOI'=> '',
			 'Instrument Name'=> '',
				# mayu
       'nr_runs' => 'Number of MS runs contributing to this build ',
			 'nr_files' => 'Always 1 ',
			 'mFDR' => 'Data in current row applies to all data meting this PSM (spectrum) FDR threshold. ',
			 'target_PSM'=> 'Number of non-decoy PSMs at this mFDR (counts peptides mappable to protein reference set only)',
			 'decoy_PSM'=> 'Number of decoy PSMs at this mFDR ',
			 'FP_PSM'=> 'Number of false positive PSMs predicted by Mayu for this mFDR. Usually near, but not exactly the same as, the number of decoys. ',
			 'TP_PSM'=> 'target_PSM - FP_PSM ',
			 'target_pepID'=> 'Number of non-decoy unique peptides at this mFDR (counts peptides mappable to protein reference set only) ',
			 'decoy_pepID'=> 'Number of decoy unique peptides at this mFDR ',
			 'FP_pepID'=> 'Number of false positive unique peptides predicted by Mayu for this mFDR. Usually near, but not exactly the same as, the number of decoys. ',
			 'FP_pepID_stdev'=> ' ',
			 'TP_pepID'=> 'target_pepID - FP_pepID ',
			 'pepFDR'=> 'Peptide FDR (unique peptides)',
			 'target_protID'=> 'Number of non-decoy protein identifications at this mFDR. Applied to the covering set of proteins -- a set that is close to the smallest necessary to explain all the pepIDs. Includes all canonicals and some possibly_distinguished. ',
			 'decoy_protID'=> 'Number of decoy protein identifications at this mFDR. ',
			 'FP_protID'=> 'Number of false postiive protein identifications predicted by Mayu for this mFDR.  Usually near, but not exactly the same as, the number of decoys. ',
			 'FP_protID_stdev'=> ' ',
			 'TP_protID'=> 'target_protID - FP_protID ',
			 'protFDR'=> 'Protein FDR. The largest value in this column is the protein FDR for the entire build. ',
			 'lFDR_1' => "lFDR1, lFDR5, lFDR10,2 lFDR5: Local protein FDR, computed over the previous step (i.e. between the previous row in the table and the current row), the previous 5 steps, the previous 10 steps, and the previous 25 steps.<br>Often there are fewer than 25 rows in the table, in which case column lFDR25 is uninformative. ",
			 'target_protIDs' => 'target_protIDs, decoy_protIDs, etc. Same as above, except for singleton proteins (those identified by only one PSM) only. ',
			 'target_protIDns' => 'target_protIDns, decoy_protIDns etc. Same as above, except for multiply-observed proteins only. ',
      # protein 
      'Canonical' => 'Minimally redunant set of proteins required to explain (virtually) all non-decoy peptides observed in build (<a target=_termdefs href="http://www.peptideatlas.org/docs/protein_ident_terms.php">more info</a>)',
      'Indistinguishable Representative' => 'Indistinguishable representative means that there are peptides that map uniquely to a set of non-canonical proteins, thereby indicating that at least one of the proteins in the set must be present, but it cannot be determined which it is.',
      'Marginally Distinguished'=>'Marginally distinguished means that this protein has peptides that are shared with a canonical peptide, but it also has a small number of peptides that appear to distinguish it from the canonical identification.',
      'Representative'=>'Representative means that there are peptides that map uniquely to a set of non-canonical proteins, thereby indicating that at least one of the proteins in the set must be present, but it cannot be determined which it is.',
      'Insufficient Evidence'=>'Protein has one or more apparently uniquely mapping peptides but none are 9AA or greater',
      'Weak' => 'Protein has one peptide that is uniquely mapping and at least 9 AA long, but is missing a second peptide that meets HPP guidelines',
 
  );

  if ( $args{labels} ) {
    my @entries;
    for my $label ( @{$args{labels}} ) {
      if ( $args{plain_hash} ) {
        if ( $coldefs{$label} ) {
          push @entries, $label => $coldefs{$label};
        } else {
          push @entries, $label => 'Not Defined';
        }
      } else {
        if ( !defined $coldefs{$label} ) {
          if ( $label =~ /PSM FDR threshold/ ) {
            $coldefs{$label} = 'PSM (peptide-spectrum match) level FDR threshold applied to build';
          } else {
            $coldefs{$label} = 'Not Defined';
          }
        }
        push @entries, { key => $label, value => $coldefs{$label} };
      }
    }
    return \@entries;
  }
  return \%coldefs;
}

sub make_annotation_text {
  my $self = shift;
  my %args = @_;
  return {} unless $args{label_hash};

  my @entries;

  if ( $args{label_order} ) {
    for my $key ( @{$args{label_order}} ) {
      push @entries, { key => $key, value => $args{label_hash}->{$key} };
    }
  } else {
    while ( my ($key, $value) = each( %{$args{label_hash}} ) ) {
      push @entries, { key => $key, value => $value };
    }
  }
  return \@entries;
}

#+
# Make toggle-able table of column defs for display 
#-
sub make_table_help {
  my $self = shift;
  my %args = @_;
  return '' unless $args{entries};

  my $description = $args{description} || '';
  $args{footnote} ||= '';
  my $heading = $args{heading} || '';

  my $showtext = 'show column descriptions';
  my $hidetext = 'hide column descriptions';

  my $help = $self->get_table_help_section( description => $description,
                                               footnote => $args{footnote},
                                                   name => $heading,
                                                heading => $heading,
                                                entries => $args{entries},
                                               showtext => $showtext,
                                               hidetext => $hidetext
                                          );

  return $help;
  
}


sub transitions_as_hashref {
  my $self = shift;
  my $data = shift;
  my $idx = 0;
  my %hashed_vals;
  for my $val ( @$data ) {
    $hashed_vals{$self->{mrm_headers_idx}->{$idx}} = $val;
    $idx++;
  }
  return \%hashed_vals;
}
## End MRM transitions section



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

1;

__DATA__
