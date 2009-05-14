###############################################################################
# $Id: TraMLParser.pm $
#
# Description : Module to parse TraML (http://psidev.info/index.php?q=node/405) 
#
# SBEAMS is Copyright (C) 2009 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::PeptideAtlas::TraMLParser;
use strict;

use LWP::UserAgent;


### Globals ###

# Array of valid transitions
my @trans;
my $trans = {};

# Hash of cvs
my %cvs;
# Hash of contacts
my %contacts;
# Hash of pubs
my %pubs;
# Hash of software
my %sw;
# Hash of proteins
my %prots;
# Hash of peptides
my %peps;
# Hash of instruments
my %instrs;
# Hash of molecules
my %mols;

# current content accumulator
my $tree = 0;
my $current = {};
my %current;
my @curr_element;

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
#  print $self->{xml} if $args{verbose};
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
#  for my $c ( keys ( %contacts ) ) { print "Contact $c:\n"; for my $a ( sort( keys( %{$contacts{$c}} ) ) ) { print "$a => $contacts{$c}->{$a}:\n"; } }

#  for my $t ( @trans ) { for my $a ( sort( keys( %$t ) ) ) { print "$a => $t->{$a}\n"; } print "\n"; }

  $self->{_trans} = \@trans;
}

sub getTransitions {
  my $self = shift;
  return $self->{_trans};
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
  my $num = get_num(); 
  my %attrs = @_;
#  print "Elem is $element\n"; print "attrs are :\n"; for my $k ( keys ( %attrs ) ) { print "\t$k => $attrs{$k}\n"; }

  if ( $element !~ /^cvParam$/i ) {
    print ' ' x $num . $element ."\n" if $tree;
    push @curr_element, $element;
#    print "element hash has " . scalar( @curr_element ) . " elements, the last of which is $curr_element[$#curr_element]\n";
  } else {
    handleCV( \%attrs );
    return;
  }
  if ( $element =~ /List$/i ) {
#    print "opening the bloody $element list\n";
  }
  if ( $element =~ /^contact$/i ) {
    die unless $attrs{id};
    $contacts{$attrs{id}} = {};
    $current{contact} = $attrs{id};
  } elsif ( $element =~ /^peptide$/i ) {
    die unless $attrs{id};
    $mols{$attrs{id}} = {};
    $current{molecule} = 'peptide'; 
    $current{peptide} = $attrs{id}; 
    $mols{$current{peptide}}->{modifiedSequence} = $attrs{modifiedSequence};

  } elsif ( $element =~ /^retentionTime$/i ) {
    if ( $current{molecule} eq 'peptide' ) {
      $mols{$current{peptide}}->{retentionTime} = $attrs{localRetentionTime};
    }
  } elsif ( $element =~ /^transition$/i ) {
    $trans = \%attrs;
    $trans->{retentionTime} = $mols{$attrs{peptideRef}}->{retentionTime};
    $trans->{modifiedSequence} = $mols{$attrs{peptideRef}}->{modifiedSequence};
  } elsif ( $element =~ /^prediction$/i ) {
    $trans->{contactName} = $contacts{$attrs{contactRef}}->{'contact name'};
    $trans->{relativeIntensity} = $attrs{relativeIntensity};
  } elsif ( $element =~ /^precursor$/i ) {
    $trans->{precursorCharge} = $attrs{charge};
    $trans->{precursorMz} = $attrs{mz};
  } elsif ( $element =~ /^product$/i ) {
    $trans->{fragmentMz} = $attrs{mz};
    $trans->{fragmentCharge} = $attrs{charge};
  } elsif ( $element =~ /^configuration$/i ) {
    $trans->{collisionEnergy} = $attrs{collisionEnergy};
    $trans->{instrument} = $attrs{instrumentRef};
  } elsif ( $element =~ /^interpretation$/i ) {
    if ( $attrs{primary} && $attrs{primary} eq 'true' ) {
      $trans->{fragmentType} = $attrs{productSeries} . $attrs{productOrdinal};
    }
  } elsif ( $element =~ /^validation$/i ) {
    $trans->{relativeIntensity} = $attrs{relativeIntensity};
    $trans->{transitionRank} = $attrs{recommendedTransitionRank};
    $trans->{comment} = $attrs{transitionSource};
  }

}

sub handleCV {
  my $attrs = shift;
#  print "CV param for $curr_element[$#curr_element]:\n";
#  for my $k ( keys ( %$attrs ) ) { print "$k => $attrs->{$k}\n"; }
  my $num = get_num( 1 );
  print ' ' x $num . '/' . $attrs->{name} . ' => ' . $attrs->{value} ."\n" if $tree;
  if ( $curr_element[$#curr_element] =~ /^contact$/i ) {
    $contacts{$current{contact}}->{$attrs->{name}} = $attrs->{value};
  } elsif (   $curr_element[$#curr_element] =~ /^configuration$/i ) {
    if ( $attrs->{name} && $attrs->{name} eq 'collision energy' ) {
      $mols{$current{peptide}}->{collisionEnergy} = $attrs->{value};
      $trans->{collisionEnergy} = $attrs->{value};
    }
  }
}

sub get_num {
  my $boost = shift || 0;
  my $num = scalar( @curr_element );
  return $num + $boost;
}

sub _end {
  my $ex = shift;
  my $element = shift;
  if ( $element !~ /^cvParam$/i ) {
    my $top = pop @curr_element; 
    my $num = get_num( );
    print ' ' x $num . '/' . $top ."\n" if $tree;
#    print "$top is done\n";
    $current = {};
  } else {
    # Skip
  }
  if ( $element =~ /List$/i ) {
#    print "closing the bloody $element list\n";
  } elsif ( $element =~ /^transition$/ ) {
    push @trans, $trans;
    $trans = {};
  }
}

sub _char {
  my $ex = shift;
  my $element = shift;
}

1;

__DATA__
modified_peptide_annotation_id
peptide_sequence
modified_peptide_sequence
peptide_charge
q1_mz
q3_mz
q3_ion_label
q3_peak_intensity 
transition_suitability_level_id
publication_id
annotator_name
annotator_contact_id
collision_energy
retention_time
instrument
project_id
comment

peptide_id
annotation_set

date_created
created_by_id
date_modified
modified_by_id
owner_group_id
record_status


modified_peptide_sequence
peptide_charge
q1_mz
q3_mz
q3_ion_label
transition_suitability_level_id
publication_id
annotator_name
annotator_contact_id
collision_energy
retention_time
instrument
comment
