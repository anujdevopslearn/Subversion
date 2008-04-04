package SBEAMS::Glycopeptide;

###############################################################################
# Program     : SBEAMS::Glycopeptide
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Glycopeptide specific items.
#
###############################################################################


use strict;
use vars qw(@ISA);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Settings;

use SBEAMS::Glycopeptide::DBInterface;
use SBEAMS::Glycopeptide::HTMLPrinter;
use SBEAMS::Glycopeptide::TableInfo;
use SBEAMS::Glycopeptide::Settings;
use SBEAMS::Glycopeptide::Tables;
use SBEAMS::Glycopeptide::Utilities;

@ISA = qw(SBEAMS::Glycopeptide::DBInterface
          SBEAMS::Glycopeptide::HTMLPrinter
          SBEAMS::Glycopeptide::TableInfo
          SBEAMS::Glycopeptide::Tables
          SBEAMS::Glycopeptide::Utilities
          SBEAMS::Glycopeptide::Settings);


# Constructor
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


# Cache SBEAMS object
sub setSBEAMS {
  my $self = shift;
  my $sbeams = shift;
  $self->{_sbeams} = $sbeams;
}


# Provide the main SBEAMS object
sub getSBEAMS {
    my $self = shift;
    unless ( $self->{_sbeams} ) {
      $self->{_sbeams} = new SBEAMS::Connection;
    }
    return($self->{_sbeams});
}

#+
# Stub routine for selecting current unipep organism.
#-
sub getKeggOrganism {
  my $self = shift;
  my $organism = $self->get_current_organism();
  $log->debug( "Org is $organism" );
  return ( !$organism ) ? 'hsa' : ( $organism =~ /Drosophila/i ) ? 'dme' : 
                                  ( $organism =~ /Saccaromyces/i ) ? 'sce' : 
                                  ( $organism =~ /Yeast/i ) ? 'sce' : 
                                  ( $organism =~ /Human/i ) ? 'hsa' :
                                  ( $organism =~ /C elegans/i ) ? 'cel' :
                                  ( $organism =~ /Mouse/i ) ? 'mmu' : 'hsa';
  return 'hsa';
}

sub getSpectraSTLib {
  my $self = shift;
  my %args = @_;

  # Use passed build_id (script) else get current (web)
  my $build_id = $args{build_id} || $self->get_current_build();

  my $sbeams = $self->getSBEAMS();
  my $sql =<<"  END" ;
  SELECT consensus_library_basename 
  FROM $TBGP_UNIPEP_BUILD
  WHERE unipep_build_id = $build_id
  END
  my $row = $sbeams->selectrow_arrayref( $sql );
  return ( $row->[0] );
}

sub fetchSpectrastOffset {
  my $self = shift;
  my %args = @_;
  return '' unless $args{pep_seq};
  
  my $clean_seq = $args{pep_seq};
  $clean_seq =~ s/\*//g;

  my @matches;

# Hard-code intial version
  my $libname = "$PHYSICAL_BASE_DIR/usr/Glycopeptide/" . $self->getSpectraSTLib() . '.pepidx';
  unless ( -e $libname ) {
    $log->error( "Missing SpectraST library: $libname" );
    return '';
  }

#  open ( LIB, "/net/dblocal/wwwspecial/sbeams/devDC/sbeams/cgi/Glycopeptide/raw_consensus.pepidx" ) || return '';
  open ( LIB, "$libname" ) || return '';
  my $cnt = 0;
  $log->debug( "looking up peptide: " . time() );
  while ( my $line = <LIB> ) {
    $cnt++;
    push @matches, $line if $line =~ /^$clean_seq\t/;
  }
  $log->debug( "done: " . time() );

  unless ( scalar(@matches) ) {
    $log->debug( "no possible matches found for $clean_seq" );
    return ''; 
  }

  # We have at least one match...
  # Get the positions of the S/T/Ys in the sequence.  These will have 
  # either a * or a & in them, p_offset is used to keep track of them
  my $positions = $self->get_site_positions( seq => $args{pep_seq}, pattern => '[S|T|Y]\*' );
  my @seq_bits = split '', $clean_seq;

  # Calculate phospho pattern
  my $spectrast_str = '';
  my $p_offset = 0;
  for my $posn ( @$positions ) {
    my $adj_offset = $posn - $p_offset;
    $p_offset++;
    $spectrast_str .=  '\/' . $adj_offset . ',' . $seq_bits[$adj_offset] . ',Phospho' . '.*';
  }
  $log->debug( "Seq is $args{pep_seq}, SPstr is $spectrast_str\n" );

  # Loop over matches, looking for pattern
  my $first_match;
  for my $match ( @matches ) {
    $log->debug( "Testing $match" );
    if ( $match =~ /$clean_seq\s+.*$spectrast_str[\s\/]+/ ) {
      $log->debug( "Matchable is $match" );
#      next unless $match =~ /Methyl/;
      my @match_attrs = split ( /\t/, $match, -1 );
      $first_match = $match_attrs[2] if !$first_match;
      if ( $args{pref_pac} ) {
        $log->debug( "pref pac in the house" );
        next unless $match =~ /Methyl/;
      }
      $log->debug( "Flag" );
      return $match_attrs[2];
    } else {
      $log->debug( "Failed, $clean_seq plus $spectrast_str doesn't match $match" );
    }
  }
  # Didn't find ideal hit, return first if we have one
  return $first_match;
  
}




sub fetchSpectrastOffsets {
  die( "a fiery death!" );  # Do we ever get here?
  my $self = shift;
  my %args = @_;
  return '' unless $args{pep_seqs};
  
  $log->debug( "Starting lookup of " . scalar(@{$args{pep_seqs}}) . " at " . time() );
  
  # Two syncronized arrays, one with the strings to be matched, the other
  # with coordinates (if any).
  my @match_seqs;
  my @match_coordinates;
  for my $pep_seq ( @{$args{pep_seqs}} ) {
    my $clean_seq =~ $pep_seq;
    $clean_seq =~ s/\*//g;
    # Find coordinates of S/T/Y* residue(s) in peptide.
    my $positions = $self->get_site_positions( seq => $pep_seq, pattern => '[S|T|Y]\*' );
    my @seq_bits = split '', $clean_seq;
    # Calculate phospho pattern
    my $spectrast_str = '';
    my $p_offset = 0;
    for my $posn ( @$positions ) {
      my $adj_offset = $posn - $p_offset;
      $p_offset++;
      $spectrast_str .=  '\/' . $adj_offset . ',' . $seq_bits[$adj_offset] . ',Phospho' . '.*';
    }
    $log->debug( "Seq is $clean_seq, SPstr is $spectrast_str\n" );
    push @match_seqs, $spectrast_str;
  }

# Hard-code intial version
  open ( LIB, "/net/dblocal/wwwspecial/sbeams/devDC/sbeams/cgi/Glycopeptide/raw_consensus.pepidx" ) || return '';
  my $cnt = 0;
  $log->debug( time() );
  while ( my $line = <LIB> ) {
    chomp $line;
    my $scnt;  # Counter for the sequence array
    for my $mseq ( @match_seqs ) {
      if ( $line =~ /$mseq/ ) {
        if ( !$match_coordinates[$scnt] ) {
          my @match_attrs = split ( /\t/, $line, -1 );
          $match_coordinates[$scnt] = $match_attrs[2];
        }
      }
    }
    $cnt++;
  }
  $log->debug( time() );
  return \@match_coordinates;
}

__END__
