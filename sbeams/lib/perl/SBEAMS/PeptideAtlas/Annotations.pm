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
    
    # modified_peptide_sequence - generate matching sequence
    $trns->{peptide_sequence} = strip_mods($trns->{modified_peptide_sequence});
    $log->info( "Trying with $trns->{modified_peptide_sequence}" );
     
    # Check for peptide ID, generate one if necessary
    $trns->{peptide_id} = $self->getPeptideId( seq => $trns->{peptide_sequence} );
    if ( !$trns->{peptide_id} ) {
      $log->info( "skippy-poo for $trns->{peptide_sequence}" );
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
    # q1_mz 
    # q3_mz 
    # q3_ion_label

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
    # q3_peak_intensity

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
sub get_mrm_transitions {
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
  q1_mz,
  q3_mz,
  q3_ion_label,  
  q3_peak_intensity,
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
  ORDER BY peptide_accession, modified_peptide_sequence, peptide_charge DESC, level_score DESC, Q3_peak_intensity DESC, q3_mz
  END
  my @rows = $sbeams->selectSeveralColumns($sql);
  return \@rows;
}



# STUB
sub get_publication {
  return '';
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
    my $row = { modified_peptide_sequence => $tt->{transitionLabel},
                peptide_charge => $tt->{precursorCharge},
                q1_mz => $tt->{precursorMz},
                q3_mz => $tt->{fragmentMz},
                q3_ion_label => $tt->{fragmentType},
                transition_suitability_level_id => 'OK',
                publication_id => undef,
                annotator_name => $tt->{contactName},
                collision_energy => $tt->{collisionEnergy},
                retention_time => $tt->{retentionTime},
                instrument => $tt->{instrument},
                comment => $tt->{comment},
                q3_peak_intensity => $tt->{relativeIntensity} 
              };

    push @converted, $row;
  }
  return \@converted;
} # End convert_traml_transitions




sub get_std_transition_headers {
  my $self = shift;
  my @std_headers = qw( modified_peptide_sequence peptide_charge q1_mz q3_mz q3_ion_label transition_suitability_level_id publication_id annotator_name collision_energy retention_time instrument comment q3_peak_intensity );
  return \@std_headers;
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
