package SBEAMS::PeptideAtlas::ConsensusSpectrum;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::ConsensusSpectrum;
#
=head1 SBEAMS::PeptideAtlas::ConsensusSpectrum

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::ConsensusSpectrum

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

use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;


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

sub spectrum_search {
  my $self = shift;
  my %args = @_;

  for my $opt ( qw( seq ) ) {
    die( "Missing required parameter $opt" ) unless defined $args{$opt};
  }

  my $charge = ( !$args{charge} ) ? '' : "AND charge = '$args{charge}'";
  my $m_seq = ( !$args{m_seq} ) ? '' : "AND modified_sequence = '$args{m_seq}'";

  my $sql =<<"  END";
  SELECT NIST_library_spectrum_id, sequence, charge, modifications, protein_name
    mz_exact, NIST_spectrum_type_id, NIST_library_id, modified_sequence,
    protein_name_alt
    FROM $TBAT_NIST_LIBRARY_SPECTRUM
    WHERE sequence = '$args{seq}'
    $charge
    $m_seq
  END
  my @rows = $sbeams->selectSeveralColumns( $sql );
  return \@rows if @rows;
  return []; 
}

1;

