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
things related to PeptideAtlas spectra

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
use SBEAMS::Proteomics::Tables;


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
    $VERBOSE = 0;
    $TESTONLY = 0;
    return($self);
} # end new

sub isValidSeq {
  my $self = shift;
  my %args = @_;
  unless ( $args{pepseq} ) {
    $log->error( "Missing required parameter pepseq" );
    return 0;
  }
  if ( $args{pepseq} !~ /^[A-Za-z]+$/ ) {
    my $pepseq = $args{pepseq};
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

  # Test for faulty input...
  unless ( $args{pepseq} ) {
    $log->error( "Missing required parameter pepseq" );
    $log->printStack( "error" );
    return 0;
  }
  unless ( isValidSeq( pepseq => $args{pepseq} ) ) {
    $log->error( "Missing required parameter pepseq" );
    $log->printStack( "error" );
    return 0;
  }

  # See if we have a cached value
  $self->getAccessionList();

  if ( $self->{_pa_accessions}->{$args{pepseq}} ) {
    return $self->{_pa_accessions}->{$args{pepseq}};
  } elsif ( !$args{add_ok} ) {
    $log->warn( "Accession not found, skipping addition as specified" );
    return 0;
  } 

  my $accession = $self->_addPeptideIdentity( \%args );
  $log->debug( "Added accession $accession for peptide $args{pepseq}" );
  return $accession;
} # End getPeptideAccession


#+
# Routine to fetch and return entries from the peptide table
#-
sub getAccessionList {
  my $self = shift;
  my %args = @_;

  return if $self->{_pa_accessions} && !$args{refresh};

  my $sql = <<"  END";
  SELECT peptide_sequence, peptide_accession
  FROM $TBAT_PEPTIDE
  END
  my $sth = $sbeams->prepare( $sql );
  $sth->execute();

  my %accessions;
  while ( my @row = $sth->fetchrow_array() ) {
    $accessions{$row[0]} = $row[1];
  }
  $self->{_pa_accessions} = \%accessions;
} # end get_accessions

#+
# Routine to fetch and return entries from the APD protein_identity table
#-
sub getIdentityList {
  my $self = shift;
  my %args = @_;

  return if $self->{_apd_identities} && !$args{refresh};

  my $sql = <<"  END";
  SELECT peptide, peptide_identifier_str, peptide_identifier_id
  FROM $TBAPD_PEPTIDE_IDENTIFIER
  END
  my $sth = $sbeams->prepare( $sql );

  my %accessions;
  while ( my @row = $sth->fetchrow_array() ) {
    $accessions{$row[0]} = \@row[1,2];
  }
} # end getIdentityList

sub cacheIdentityList {
  my $self = shift;
  my %args = @_;
}

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
    return($TESTONLY);
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
