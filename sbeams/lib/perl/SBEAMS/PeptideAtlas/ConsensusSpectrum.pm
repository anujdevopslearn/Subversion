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

use SBEAMS::Connection qw( $log );
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
  my $lib = ( !$args{lib_id} ) ? '' : "AND CLS.consensus_library_id = '$args{lib_id}'";

  my $sql =<<"  END";
  SELECT consensus_library_spectrum_id, sequence, charge, modifications, protein_name,
    mz_exact, consensus_spectrum_type_id, CLS.consensus_library_id, modified_sequence,
    protein_name_alt, consensus_library_name
    FROM $TBAT_CONSENSUS_LIBRARY_SPECTRUM CLS
    JOIN $TBAT_CONSENSUS_LIBRARY CL ON CL.consensus_library_id = CLS.consensus_library_id
    WHERE sequence = '$args{seq}'
    $charge
    $m_seq
    $lib
  END
  my @rows = $sbeams->selectSeveralColumns( $sql );
  return \@rows || [];
}

sub get_spectrum_peaks {
	my $self = shift;
	my %args = @_;

  for my $arg ( qw( file_path entry_idx ) ) {
    die $arg unless defined $args{$arg};
  }

#  print "Looking in file $args{file_path} for index $args{entry_idx}\n";

  open FIL, $args{file_path} || die "Dang, yo";
  seek ( FIL, $args{entry_idx}, 0 );
  my $collect_peaks;
  my %spectrum = ( n_peaks => 0,
                   masses => [],
                   intensities => [] );

  my $cnt = 0;
  my $peak_cnt;
  while ( my $line = <FIL> ) {
    $cnt++;
    chomp $line;
    if ( $line =~ /^NumPeaks:\s+(\d+)\s*$/ ) {
      $spectrum{n_peaks} = $1;
      $collect_peaks++;
      next;
    } elsif ( $line =~ /^NumPeaks/ ) {
      die "Why didn't $line trip it!";
    }
    next unless $collect_peaks;
    last if $line =~ /^\s*$/;
    $line =~ /(\S+)\s+(\S+).*$/;
    push @{$spectrum{masses}}, $1;
    push @{$spectrum{intensities}}, $2;
#    print STDERR "pushing $1 and $2 to the m/i arrays\n";
    $peak_cnt++;
    if ( $peak_cnt > $spectrum{n_peaks} ) {
      print STDERR "Past our due date with $line\n";
      last;
    }
  }
#  print " saw $cnt total rows for $args{file_path} entry $args{entry_idx}!\n";
#  print STDERR " masses: " . scalar( @{$spectrum{masses}} ) . " entries";
#  print STDERR " intensities: " . scalar( @{$spectrum{intensities}} ) . " entries";

  return \%spectrum;
}

1;

