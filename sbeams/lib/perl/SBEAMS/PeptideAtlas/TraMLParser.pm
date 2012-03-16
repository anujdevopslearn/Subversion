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

use vars qw($VERBOSE $DEBUG);
$VERBOSE = 1;
$DEBUG = 1;
$| = 1;

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

# Begin Writer routines



###############################################################################
# openTraMLFile
###############################################################################
sub openTraMLFile {
  my $self = shift;
  my %args = @_;
  my $outputFile = $args{'outputFile'} || die("No outputFile provided");

  print "Opening output file '$outputFile'...\n";


  #### Open and write header
  our $TRAMLOUTFILE;
  open(TRAMLOUTFILE,">$outputFile")
    || die("ERROR: Unable to open '$outputFile' for write");
  print TRAMLOUTFILE qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
  $TRAMLOUTFILE = *TRAMLOUTFILE;

  #### Write out parent build element
  my $buffer = encodeXMLEntity(
    entity_name => 'TraML',
    indent => 0,
    entity_type => 'open',
    attributes => {
      version => '0.10',
      xmlns => 'http://psi.hupo.org/ms/traml',
      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
      'xsi:schemaLocation' => 'http://psi.hupo.org/ms/traml TraML0.1.xsd',
    },
  );

  print $TRAMLOUTFILE $buffer;

  return(1);
}


###############################################################################
# writeTraMLFile
###############################################################################
sub writeTraMLFile {
  my $self = shift;
  my %args = @_;
  my $transitions = $args{'transitions'} || die("No transitions provided");

  our $TRAMLOUTFILE;

  my $buffer = '';

  #### Write out the cvList information
  $buffer .= $self->writeCvListSection();

  #### Write out the cvList information
  $buffer .= $self->writeContactSection();

  #### Write out the instrumentList information
  $buffer .= $self->writeInstrumentSection();

  print $TRAMLOUTFILE $buffer;


  #### Write out the transitions list
  if ($transitions->{transitionsList}) {
    $buffer = encodeXMLEntity(
      entity_name => 'transitionList',
      indent => 2,
      entity_type => 'open',
    );
    print $TRAMLOUTFILE $buffer;

    foreach my $transition (@{$transitions->{transitionsList}}) {

      $transition->{moleculeName} =~ s/\"//g;
      $transition->{precursorMz} = 0 unless ($transition->{precursorMz});

      $buffer = encodeXMLEntity(
        entity_name => 'transition',
        indent => 4,
        entity_type => 'open',
        attributes => {
          transitionLabel => $transition->{moleculeName},
          precursorMz => $transition->{precursorMz},
          fragmentMz => $transition->{productMz},
          #moleculeCategory => $transition->{moleculeCategory},
          #groupLabel => $transition->{groupLabel},
          #retentionTime => $transition->{retentionTime},
        },
      );
      print $TRAMLOUTFILE $buffer;


      $buffer = encodeXMLEntity(
        entity_name => 'configurationList',
        indent => 6,
        entity_type => 'open',
      );
      print $TRAMLOUTFILE $buffer;


      $buffer = encodeXMLEntity(
        entity_name => 'configuration',
        indent => 8,
        entity_type => 'openclose',
        attributes => {
          instrumentRef => 'TSQ',
          collisionEnergy => $transition->{collisionEnergy},
          tubeLens => $transition->{tubeLens},
        },
      );
      print $TRAMLOUTFILE $buffer;


      $buffer = encodeXMLEntity(
        entity_name => 'configurationList',
        indent => 6,
        entity_type => 'close',
      );
      print $TRAMLOUTFILE $buffer;

      $buffer = encodeXMLEntity(
        entity_name => 'transition',
        indent => 4,
        entity_type => 'close',
      );
      print $TRAMLOUTFILE $buffer;

    }

    $buffer = encodeXMLEntity(
      entity_name => 'transitionList',
      indent => 2,
      entity_type => 'close',
    );
    print $TRAMLOUTFILE $buffer;

  }

  return(1);
}



###############################################################################
# writeCvListSection
###############################################################################
sub writeCvListSection {
  my $self = shift;
  my %args = @_;

  my $buffer = '';

  $buffer .= encodeXMLEntity(
    entity_name => 'cvList',
    indent => 2,
    entity_type => 'open',
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'cv',
    indent => 4,
    entity_type => 'openclose',
    attributes => {
      id => 'MS',
      fullName => 'Proteomics Standards Initiative Mass Spectrometry Ontology',
      version => '1.3.10',
      URI => 'http://psidev.sourceforge.net/ms/xml/mzdata/psi-ms.2.0.2.obo',
    },
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'cv',
    indent => 4,
    entity_type => 'openclose',
    attributes => {
      id => 'UO',
      fullName => 'Unit Ontology',
      version => 'unknown',
      URI => 'http://obo.cvs.sourceforge.net/obo/obo/ontology/phenotype/unit.obo',
    },
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'cvList',
    indent => 2,
    entity_type => 'close',
  );

  return $buffer;
}



###############################################################################
# writeContactSection
###############################################################################
sub writeContactSection {
  my $self = shift;
  my %args = @_;

  my $buffer = '';


  $buffer .= encodeXMLEntity(
    entity_name => 'contactList',
    indent => 2,
    entity_type => 'open',
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'contact',
    indent => 4,
    entity_type => 'open',
    attributes => {
      id => 'Eric',
    },
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'cvParam',
    indent => 6,
    entity_type => 'openclose',
    attributes => {
      cvRef => 'MS',
      accession => 'MS:1000586',
      name => 'contact name',
      value => 'Eric Deutsch',
    },
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'cvParam',
    indent => 6,
    entity_type => 'openclose',
    attributes => {
      cvRef => 'MS',
      accession => 'MS:1000590',
      name => 'contact organization',
      value => 'Institute for Systems Biology',
    },
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'contact',
    indent => 4,
    entity_type => 'close',
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'contactList',
    indent => 2,
    entity_type => 'close',
  );

  return $buffer;
}



###############################################################################
# writeInstrumentSection
###############################################################################
sub writeInstrumentSection {
  my $self = shift;
  my %args = @_;

  my $buffer = '';


  $buffer .= encodeXMLEntity(
    entity_name => 'instrumentList',
    indent => 2,
    entity_type => 'open',
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'instrument',
    indent => 4,
    entity_type => 'open',
    attributes => {
      id => 'TSQ',
    },
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'cvParam',
    indent => 6,
    entity_type => 'openclose',
    attributes => {
      cvRef => 'MS',
      accession => 'MS:1000554',
      name => 'Thermo TSQ',
    },
  );


  $buffer .= encodeXMLEntity(
    entity_name => 'instrument',
    indent => 4,
    entity_type => 'close',
  );

  $buffer .= encodeXMLEntity(
    entity_name => 'instrumentList',
    indent => 2,
    entity_type => 'close',
  );

  return $buffer;
}



###############################################################################
# closeTraMLFile
###############################################################################
sub closeTraMLFile {
  my $self = shift;

  our $TRAMLOUTFILE;

  #### Close out parent element
  my $buffer = encodeXMLEntity(
    entity_name => 'TraML',
    indent => 0,
    entity_type => 'close',
  );

  print $TRAMLOUTFILE $buffer;

  close($TRAMLOUTFILE);

  return(1);
}



###############################################################################
# encodeXMLEntity
###############################################################################
sub encodeXMLEntity {
  my %args = @_;
  my $entity_name = $args{'entity_name'} || die("No entity_name provided");
  my $indent = $args{'indent'} || 0;
  my $entity_type = $args{'entity_type'} || 'openclose';
  my $attributes = $args{'attributes'} || '';

  #### Define a string from which to get padding
  my $padstring = '                                                       ';
  my $compact = 1;

  #### Define a stack to make user we are nesting correctly
  our @xml_entity_stack;

  #### Close tag
  if ($entity_type eq 'close') {

    #### Verify that the correct item was on top of the stack
    my $top_entity = pop(@xml_entity_stack);
    if ($top_entity ne $entity_name) {
      die("ERROR forming XML: Was told to close <$entity_name>, but ".
          "<$top_entity> was on top of the stack!");
    }
    return substr($padstring,0,$indent)."</$entity_name>\n";
  }

  #### Else this is an open tag
  my $buffer = substr($padstring,0,$indent)."<$entity_name";


  #### encode the attribute values if any
  if ($attributes) {

    while (my ($name,$value) = each %{$attributes}) {
      if ($value  && $value ne "")
      {
        if ($compact) {
        $buffer .= qq~ $name="$value"~;
        } else {
        $buffer .= "\n".substr($padstring,0,$indent+8).qq~$name="$value"~;
        }
      }
    }

  }

  #### If an open and close tag, write the trailing /
  if ($entity_type eq 'openclose') {
    $buffer .= "/";

  #### Otherwise push the entity on our stack
  } else {
    push(@xml_entity_stack,$entity_name);
  }


  $buffer .= ">\n";

  return($buffer);

} # end encodeXMLEntity




###############################################################################
1;

