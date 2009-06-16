package SBEAMS::PeptideAtlas::Peptide;

###############################################################################
#                                                           
# Class       : SBEAMS::PeptideAtlas::Peptide
# Author      : 
#
=head1 SBEAMS::PeptideAtlas::Peptide

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::Peptide

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
things related to PeptideAtlas Peptides

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
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

use SBEAMS::Proteomics::PeptideMassCalculator;


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);


#+
# Constructor
#-
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = @_;
    bless $self, $class;
    return($self);
} # end new

sub isValidSeq {
  my $self = shift;
  my %args = @_;
  unless ( $args{seq} ) {
    $log->error( "Missing required parameter pepseq" );
    return 0;
  }

  if ( $args{seq} !~ /^[A-Za-z]+$/ ) {
    my $pepseq = $args{seq};
    $pepseq =~ s/[A-Za-z]//g;
    $log->error( "Illegal sequence characters passed: $pepseq" );
    return 0;
  }
  return 1;
}

#+
# Routine to fetch accession number for a peptide sequence
#-
sub getPeptideAccession {
  my $self = shift;
  my %args = @_;

  return unless $args{seq} && $self->isValidSeq( seq => $args{seq} );
  $sbeams = $self->getSBEAMS();

  my $sql =<<"  END";
    SELECT peptide_accession
    FROM $TBAT_PEPTIDE 
    WHERE peptide_sequence = '$args{seq}'
  END

  if( $args{no_cache} ) {
    my ($acc) = $sbeams->selectrow_arrayref( $sql );
    return $acc;
  }

  # Already cached info?
  if ( !$self->{_pa_acc_list} ) {
    $self->cacheAccList();
  }

  # current seq not found, try to lookup.
  unless( $self->{_pa_acc_list}->{$args{seq}} ) {  
    ( $self->{_pa_acc_list}->{$args{seq}} ) = $sbeams->selectrow_arrayref($sql);
  }

  # Might be null, but we tried!
  return $self->{_pa_acc_list}->{$args{seq}} 

} # End getPeptideAccession


sub getPeptideId {
  my $self = shift;
  my %args = @_;

  return unless $args{seq} && $self->isValidSeq( seq => $args{seq} );
  $sbeams = $self->getSBEAMS();

  my $sql =<<"  END";
    SELECT peptide_id
    FROM $TBAT_PEPTIDE 
    WHERE peptide_sequence = '$args{seq}'
  END

  if( $args{no_cache} ) {
    my ($id) = $sbeams->selectrow_arrayref( $sql );
    return $id;
  }

  # Already cached info?
  if ( !$self->{_pa_id_list} ) {
    $self->cacheIdList();
  }

  # current seq not found, try to lookup.
  unless( $self->{_pa_id_list}->{$args{seq}} ) {  
    ( $self->{_pa_id_list}->{$args{seq}} ) = $sbeams->selectrow_arrayref($sql);
  }

  # Might be null, but we tried!
  return $self->{_pa_id_list}->{$args{seq}} 
}

#+
# Routine fetches peptide_id, accession, and instance_id for a passed
# set of peptide sequences.
#-
sub getPeptideList {
  my $self = shift;
  my %args = @_;

  return unless $args{sequence_ref};
  $sbeams = $self->getSBEAMS();

  my @peptides;
  for my $pep ( @{$args{sequence_ref}} ) {
    push @peptides, "'" . $pep . "'" if isValidSeq( seq => $pep );
  }

  my @results;
  return \@results unless @peptides;

  $log->warn( "Large seq list in getPeptideList: " . scalar( @peptides) );

  my $in_clause = '(' . join( ", ", @peptides ) . ')';

  my $sql;
  if ( $args{build_id} ) {
    my $sql =<<"    END";
      SELECT peptide_id, peptide_accession, peptide_instance_id
      FROM $TBAT_PEPTIDE P 
      LEFT JOIN  $TBAT_PEPTIDE_INSTANCE PI ON P.peptide_id = PI.peptide_id 
      WHERE peptide_sequence IN ( $in_clause )
      AND atlas_build_id = $args{build_id}
    END
  } else {
    my $sql =<<"    END";
      SELECT peptide_id, peptide_accession, '' 
      FROM $TBAT_PEPTIDE P 
      WHERE peptide_sequence IN ( $in_clause )
    END
  }

  my $sth = $sbeams->get_statement_handle( $sql );
  while ( my $row = $sth->fetchrow_arrayref() ) {
    push @results, $row;
  }
  return \@results;

}



#+
# Routine to fetch and return entries from the peptide table
#-
sub cacheAccList {
  my $self = shift;
  my %args = @_;

  return if $self->{_pa_acc_list} && !$args{refresh};

  my $sql = <<"  END";
  SELECT peptide_sequence, peptide_accession
  FROM $TBAT_PEPTIDE
  END
  my $sth = $sbeams->get_statement_handle( $sql );
  $sth->execute();

  my %accessions;
  while ( my @row = $sth->fetchrow_array() ) {
    $accessions{$row[0]} = $row[1];
  }
  $self->{_pa_acc_list} = \%accessions;
} # end get_accessions


#+
# Routine to fetch and return entries from the peptide table
#-
sub cacheIdList {
  my $self = shift;
  my %args = @_;

  return if $self->{_pa_id_list} && !$args{refresh};

  my $sql = <<"  END";
  SELECT peptide_sequence, peptide_id
  FROM $TBAT_PEPTIDE
  END
  my $sth = $sbeams->get_statement_handle( $sql );
  $sth->execute();

  my %ids;
  while ( my @row = $sth->fetchrow_array() ) {
    $ids{$row[0]} = $row[1];
  }
  $self->{_pa_id_list} = \%ids;
}

sub updateIdCache {
  my $self = shift;
  my %args = @_;
}


#+
# Routine to add new peptide to the atlas.  This is comprised of two steps, 
# which by default are wrapped in a transaction to make them atomic.
#
# @narg make_atomic   Should inserts be wrapped in transaction? default = 1
# @narg sequence      Peptide sequence to be added [required]
#
#-
sub addNewPeptide {
  my $self = shift;
  my %args = @_;

  # return if no sequence specified
  return unless $args{seq} && $self->isValidSeq( seq => $args{seq} );

  if ( $self->getPeptideId( seq => $args{seq} ) ) {
    # Should we do more here, i.e. update cache?
    $log->warn( "addNewPeptide called on existing sequence: $args{seq}" );
#    return 0;
  }

  $sbeams = $self->getSBEAMS();

  # fetch and cache identity list if not already done
  unless ( $self->{_apd_id_list} ) {
    $self->cacheIdentityList();
  }

  unless ( $self->{_apd_id_list}->{$args{seq}} ) {
    $self->addAPDIdentity( %args ); # Pass through seq and make_atomic args.
  }

  return unless $self->{_apd_id_list}->{$args{seq}};

  # We have an APD ID, and peptide is not otherwise in the database.  Calculate
  # peptide attributes and insert
 

  $self->{_massCalc} ||= new SBEAMS::Proteomics::PeptideMassCalculator;
  $self->{_ssrCalc} ||= $self->getSSRCalculator();
    
  my $mw =  $self->{_massCalc}->getPeptideMass( mass_type => 'monoisotopic',
                                                  sequence => $args{seq} );

  my $pI = $self->calculatePeptidePI( sequence => $args{seq} );

  my $ssr;
  if ($self->{_ssrCalc}->checkSequence($args{seq})) {
    $ssr = $self->{_ssrCalc}->TSUM3($args{seq});
  }

  my $rowdata_ref = {};
  
  $rowdata_ref->{molecular_weight} = $mw;
  $rowdata_ref->{peptide_isoelectric_point} = $pI;
  $rowdata_ref->{SSRCalc_relative_hydrophobicity} = $ssr;
  $rowdata_ref->{peptide_sequence} = $args{seq};
  $rowdata_ref->{peptide_length} = length( $args{seq} );
  $rowdata_ref->{peptide_accession} = $self->{_apd_id_list}->{$args{seq}};
  
  my $peptide_id = $sbeams->updateOrInsertRow(
    insert      => 1,
    table_name  => $TBAT_PEPTIDE,
    rowdata_ref => $rowdata_ref,
    PK          => 'peptide_id',
    return_PK   => 1,
    verbose     => $VERBOSE,
    testonly    => $args{testonly} );

  return $peptide_id;
  
}

sub getSSRCalculator {
  my $self = shift;
  
  # Create and initialize SSRCalc object with 3.0
  my $ssr = $self->getSSRCalcDir();

  $ENV{SSRCalc} = $ssr;

  use lib '/net/db/src/SSRCalc/ssrcalc';
  use SSRCalculator;

  my $calculator = new SSRCalculator();
  $calculator->initializeGlobals3();
  $calculator->ReadParmFile3();
  return $calculator;
}

sub addAPDIdentity {
  my $self = shift;
  my %args = @_;

  # return if no sequence specified
  return unless $args{seq} && $self->isValidSeq( seq => $args{seq} );

  # Make atomic if not already handled by calling code
  $args{make_atomic} = 1 if !defined $args{make_atomic};

  $sbeams = $self->getSBEAMS();

  unless ( $self->{_apd_id_list} ) {
    $self->cacheIdentityList();
  }

  # log and return if it is already there
  if ( $self->{_apd_id_list}->{$args{seq}} ) {
    $log->warn("Tried to add APD identity for seq $args{seq}, already exists");
    return; 
  }

  my $rowdata = {};
  $rowdata->{peptide} = $args{seq};
  $rowdata->{peptide_identifier_str} = 'tmp';

  # Do the next two statements as a transaction
  $sbeams->initiate_transaction() if $args{make_atomic};

  #### Insert the data into the database
  my $apd_id = $sbeams->updateOrInsertRow(
    table_name => $TBAPD_PEPTIDE_IDENTIFIER,
        insert => 1,
   rowdata_ref => $rowdata,
            PK => "peptide_identifier_id",
     return_PK => 1,
       verbose => $VERBOSE,
    testonly   => $args{testonly} );

  unless ($apd_id ) {
    $log->error( "Unable to insert APD_identity for $args{seq}" );
    return;
  }

  if ( $apd_id > 99999999 ) {
    $log->error( "key length too long for current Atlas accession template!" );
    die " Unable to insert APD accession";
  }
  
  $rowdata->{peptide_identifier_str} = 'PAp' . sprintf( "%08s", $apd_id );

  #### UPDATE the record
  my $result = $sbeams->updateOrInsertRow(
    table_name => $TBAPD_PEPTIDE_IDENTIFIER,
        update => 1,
   rowdata_ref => $rowdata,
            PK => "peptide_identifier_id",
      PK_value => $apd_id ,
     return_PK => 1,
       verbose => $VERBOSE,
      testonly => $args{testonly} );

  #### Commit the INSERT+UPDATE pair
  $sbeams->commit_transaction() if $args{make_atomic};

  #### Put this new one in the hash for the next lookup
  $self->{_apd_id_list}->{$args{seq}} = $apd_id;

} # end addAPDIdentity



#+
# Routine to fetch and return entries from the APD protein_identity table
#-
sub cacheIdentityList {
  my $self = shift;
  my %args = @_;
  
  $self->{_apd_id_list} = { GSYGSGGSSYGSGGGSYGSGGGGGGHGSYGSGSSSGGYR => 'PAp00000038' };

  if ( $self->{_apd_id_list} && !$args{refresh} ) {
    return;
  }
  $sbeams = $self->getSBEAMS();

  my $sql = <<"  END";
  SELECT peptide, peptide_identifier_str, peptide_identifier_id
  FROM $TBAPD_PEPTIDE_IDENTIFIER
  END

  my $sth = $sbeams->get_statement_handle( $sql );

  my %accessions;
  while ( my @row = $sth->fetchrow_array() ) {
    $accessions{$row[0]} = $row[1];
  }
  $self->{_apd_id_list} = \%accessions;

} # end getIdentityList


sub _addPeptideIdentity {
  my $self = shift;
}

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
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Eric W. Deutsch (edeutsch@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################

1;
