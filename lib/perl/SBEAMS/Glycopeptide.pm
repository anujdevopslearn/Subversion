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

use SBEAMS::Glycopeptide::DBInterface;
use SBEAMS::Glycopeptide::HTMLPrinter;
use SBEAMS::Glycopeptide::TableInfo;
use SBEAMS::Glycopeptide::Settings;
use SBEAMS::Glycopeptide::Utilities;

@ISA = qw(SBEAMS::Glycopeptide::DBInterface
          SBEAMS::Glycopeptide::HTMLPrinter
          SBEAMS::Glycopeptide::TableInfo
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
  return ( !$organism ) ? 'hsa' : ( $organism =~ /Drosophila/i ) ? 'dme' : 
                                  ( $organism =~ /Saccaromyces/i ) ? 'sce' : 
                                  ( $organism =~ /Human/i ) ? 'hsa' :
                                  ( $organism =~ /Mouse/i ) ? 'mmu' : 'hsa';
  return 'hsa';
}

sub fetchSpectrastOffset {
  my $self = shift;
  my %args = @_;
  return '' unless $args{pep_seq};
  
  my $clean_seq = $args{pep_seq};
  $clean_seq =~ s/\*//g;

  my @matches;

# Hard-code intial version
  open ( LIB, "/net/dblocal/wwwspecial/sbeams/devDC/sbeams/cgi/Glycopeptide/raw_consensus.pepidx" ) || return '';
  my $cnt = 0;
  while ( my $line = <LIB> ) {
    $cnt++;
    push @matches, $line if $line =~ /^$clean_seq\t/;
  }

  return '' unless scalar(@matches);

  # We have at least one match...
  my $positions = $self->get_site_positions( seq => $args{pep_seq}, pattern => '[S|T]\*' );
  my @seq_bits = split '', $clean_seq;

  # Calculate phospho pattern
  my $spectrast_str = '';
  my $p_offset = 0;
  for my $posn ( @$positions ) {
    my $adj_offset = $posn - $p_offset;
    $p_offset++;
    $spectrast_str .=  '/' . $adj_offset . ',' . $seq_bits[$adj_offset] . ',Phospho';
  }

  # Loop over matches, looking for pattern
  for my $match ( @matches ) {
    if ( $match =~ /$clean_seq\s+.*$spectrast_str\s+/ ) {
      my @match_attrs = split ( /\t/, $match, -1 );
      return $match_attrs[2];
    }
  }


  

  
}


1;

__END__
