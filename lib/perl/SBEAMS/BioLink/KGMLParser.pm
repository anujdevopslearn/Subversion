###############################################################################
# $Id: KGMLParser.pm $
#
# Description : Module to parse KGML docs (http://www.genome.jp/kegg/docs/xml/)
# SBEAMS is Copyright (C) 2000-2006 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::BioLink::KGMLParser;
use strict;

use LWP::UserAgent;

use lib "../..";

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::BioLink;
#use SBEAMS::BioLink::Settings;
#use SBEAMS::BioLink::TableInfo;
use SBEAMS::BioLink::Tables;

### Globals ###

my $sbeams = new SBEAMS::Connection;
my $sbeamsMOD = new SBEAMS::BioLink;
$sbeamsMOD->setSBEAMS($sbeams);

# Array of valid map entries
my @entries;

# current content accumulator
my $current = {};

# basic pathway info
my $pathway = {};

# semaphore, have we seen a graphics section with this element
my $seen_graphics;

sub new {
  my $class = shift;
  my $this = { @_ };

  # Objectification.
  bless $this, $class;

  return $this;
}

#+
# Input type can be a URL, file, or string.
#_
sub set_url {
  my $self = shift;
  my %args = @_;
  return undef unless $args{url};
  $self->{url} = $args{url};
}

#+
# Input type can be a URL, file, or string.
#_
sub set_file {
  my $self = shift;
  my %args = @_;
  return undef unless $args{file};
  open( INFIL, "$args{file}" ) || die "Unable to open file $args{file}";
  {
    undef local $/;
    $self->{xml} = <INFIL>;
  }
  close INFIL;
}

#+
# Input type can be a URL, file, or string.
#_
sub set_string {
  my $self = shift;
  my %args = @_;
  return undef unless $args{xml};
  $self->{xml} = $args{xml};
}

#+
# Parse given resource according to provided settings.
#_
sub parse {
  my $self = shift;
  require XML::Parser;
  my $p = XML::Parser->new( Handlers => { Start => \&_start,
                                          End => \&_end,
                                          Char => \&_char } );
  $p->parse( $self->{xml} );
  $self->{_entries} = \@entries;
  $self->{_pathway} = $pathway;
}

sub getEntries {
  my $self = shift;
  return $self->{_entries};
}

sub getPathway {
  my $self = shift;
  return $self->{_pathway};
}

#+
# 
#_
sub fetch_url {
  my $self = shift;
  my %args = @_;
  $self->{url} = $args{url} if $args{url};

  # Fetch response
  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new();
  my $response = $ua->get(  $self->{url} );
  use Data::Dumper;

  $self->{xml} = $response->content;
  return $response->content();
}

sub _start {
  my $ex = shift;
  my $element = shift;
  my %attrs = @_;
  if ( $element eq 'pathway' ) {
    for my $k ( sort( keys %attrs ) ) {
      $pathway->{$k} = $attrs{$k};
    }
  } elsif ( $element eq 'entry' ) {
    for my $k ( sort( keys %attrs ) ) {
      $current->{$k} = $attrs{$k};
    }
  } elsif ( $element eq 'graphics' ) {
    $seen_graphics = 1;
    for my $k ( sort( keys %attrs ) ) {
      $current->{'gr_' . $k} = $attrs{$k};
    }
  } else {
    # Skip
  }
}


sub _end {
  my $ex = shift;
  my $element = shift;
  if ( $element eq 'entry'  ) {
    push @entries, $current if $seen_graphics;
    $seen_graphics = 0;
    $current = {};
  } else {
    # Skip
  }
}

sub _char {
  my $ex = shift;
  my $element = shift;
}

1;
