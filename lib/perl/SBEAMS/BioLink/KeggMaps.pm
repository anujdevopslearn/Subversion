###############################################################################
# $Id: KeggMaps.pm $
#
# Description : Module to support fetch and  display gene expression on Kegg pathway maps.
#
# SBEAMS is Copyright (C) 2000-2006 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

# package provides interface to various functionality for KEGG pathway maps
package SBEAMS::BioLink::KeggMaps;

use strict;

#require Exporter;
#our @ISA = qw( Exporter );
#our @EXPORT_OK = qw();
use LWP::UserAgent;
use SOAP::Lite;

use lib "../..";
use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::BioLink;
use SBEAMS::BioLink::KGMLParser;
#use SBEAMS::BioLink::Settings;
#use SBEAMS::BioLink::TableInfo;
use SBEAMS::BioLink::Tables;

use lib qw (../../lib/perl);

### Globals ###
my $sbeams = new SBEAMS::Connection;
$sbeams->setRaiseError(1);

my $sbeamsMOD = new SBEAMS::BioLink;
$sbeamsMOD->setSBEAMS($sbeams);


### Class Methods ###
#+
# Constructor  
#
#-
sub new {
  my $class = shift;
  my $this = { _wsdl => 'http://soap.genome.jp/KEGG.wsdl',
               @_ 
              };


  # Objectification.
  bless $this, $class;

  return $this;
}

## General gettor/settor methods
#
#+
# Set URL for WSDL
#-
sub setWSDL {
  my $this = shift;
  $this->{_wsdl} = shift;
}

#+
# Get URL for WSDL
#-
sub getWSDL {
  my $this = shift;
  return $this->{_wsdl};
}

#+
# Get SOAP service object
#-
sub get_service {
  my $this = shift;
  my $wsdl = $this->getWSDL() || die "Missing required WSDL";

  eval {
    $this->{_service} ||= SOAP::Lite->service($wsdl);
  };
  if ( $@ ) {
    $log->error( $@ );
    print( $sbeams->makeErrorText("Temporarily unable to connect to KEGG SOAP service, please try again later") );
    exit;
  }
  return $this->{_service};
}

#+
# reset SOAP service object
#-
sub reset_service {
  my $this = shift;
  my $wsdl = shift || $this->getWSDL() || die "Missing required WSDL";

  $this->{_service} ||= SOAP::Lite->service($wsdl);
  return $this->{_service};
}

#+
# Set current pathway
#-
sub setPathway {
  my $this = shift;
  my %args = @_;
  $this->{_pathway} = $args{pathway} if $args{pathway};
}

#+
# Get current pathway
#-
sub getPathway {
  my $this = shift;
  return $this->{_pathway};
}

#+
# Set current organism (kegg org name, not db organism_id, e.g. hsa, sce)
#-
sub setOrganism {
  my $this = shift;
  my %args = @_;
  $this->{_organism} = $args{organism} if $args{organism};
}

#+
# Get current organism (kegg org name, not db organism_id, e.g. hsa, sce)
#-
sub getOrganism {
  my $this = shift;
  return $this->{_organism};
}

#+
# Get current organism (kegg org name, not db organism_id, e.g. hsa, sce)
#-
sub getOrganismID {
  my $this = shift;
  my $org = $this->getOrganism();
  my ($org_id) = $sbeams->selectrow_array( <<"  END" );
  SELECT kegg_organism_id FROM $TBBL_KEGG_ORGANISM where 
  kegg_organism_name = '$org'
  END
  return $org_id;
}


## KGML processing section

#+
# Process parsed KGML into useful data objects for building image map
#-
sub processEntries {
  my $self = shift;
  my %args = @_;
  
  my @entries;      # Array of entry IDs
  my @coordinates;  # Array of coordinates synced with entries
  my %gene2entries; # Lookup of gene_id => entries
  my %entry2genes;  # Lookup of entry_id => genes
  my %allgenes;     # Non-redundant list of gene IDs

  for my $en ( @{$args{entries}} ) {
    # For now we'll skip all but genes
    next unless $en->{type} eq 'gene';

    # cache entry id
    push @entries, $en->{id};

    # cache coordinates
    my $bl_x = ($en->{gr_x} - int($en->{gr_width}/2)); # bottom left X  
    my $bl_y = ($en->{gr_y} - int($en->{gr_height}/2)); # bottom left Y 
    my $tr_x = $bl_x + $en->{gr_width}; # top right X  
    my $tr_y = $bl_y + $en->{gr_height}; # top right Y  

    push @coordinates, "$bl_x, $bl_y, $tr_x, $tr_y"; 

    my $genelist = $en->{name};
    $genelist =~ s/\s+/ /g;
    my @genes = split( " ", $genelist );
    
    for my $gene ( @genes ) {
      $allgenes{$gene}++;
      $gene2entries{$gene} ||= [];
      push @{$gene2entries{$gene}}, $en->{id};
      
      $entry2genes{$en->{id}} ||= [];
      push @{$entry2genes{$en->{id}}}, $gene;
    }
 }
  my %processed = ( entries  => \@entries,
                    coords   => \@coordinates,
                    allgenes => [keys(%allgenes)],
                gene2entries => \%gene2entries,
                 entry2genes => \%entry2genes );

  return \%processed;
}

#+
# Returns image map HTML
#-
sub get_image_map {
  my $self = shift;
  my %args = @_;

  return undef unless defined $args{coords};
  
  my $name = $args{name} || 'sbeams_map';
  my $src = $args{img_src} || 'src.gif';

  my $colors = "<STYLE TYPE=text/css>#expressed_gene{background-color: red}</STYLE>";
  my $link = "<IMG SRC=$src ISMAP USEMAP='#$name' BORDER=0></A>";
  my $map = "<MAP NAME='$name'>\n";

  my @coords = @{$args{coords}};
  my ( @links, @colors, @text );

  if ( $args{links} ) {
    @links = @{$args{links}};
  } 
  if ( $args{colors} ) {
    @colors = @{$args{colors}};
  }
  if ( $args{text} ) {
    @text = @{$args{text}};
  }

  my $cnt = 0;
  for my $coords ( @coords ) {
    my $href = ( $links[$cnt] ) ? "HREF=$links[$cnt]" : 'HREF=www.peptideatlas.org';
    my $text = ( $text[$cnt] ) ? "$text[$cnt]" : '';
    $colors[$cnt] ||= 'red';
    $map .= "<AREA SHAPE='RECT' CLASS='expressed_gene' COLOR=$colors[$cnt] COORDS='$coords' TITLE='$text' TARGET='_evidence' $href>\n";
    $cnt++;
  }
  $map .= "</MAP>\n";
#  return ( wantarray ) ? ($link, $map) : $link . $map;
  return "$colors\n$link\n$map";
}


sub kegg_tables_exist {
  my $self = shift;
#  return 0;
  unless ( defined $self->{_kegg_tables_exist} ) {
    eval {
      $sbeams->selectrow_array( "SELECT TOP 1 * FROM $TBBL_KEGG_GENE" );
    }; 
    if ( $@ ) {
      $self->{_kegg_tables_exist} = 0;
    } else {
      $self->{_kegg_tables_exist} = 1;
    }
  }
  return $self->{_kegg_tables_exist};
}

#+
# Method to fetch pathway info from KEGG
#-
sub getKeggPathways {
  my $self = shift;
  my %args = @_;

  $self->{_organism} = $args{organism} if $args{organism};

  if ( !$self->{_organism} ) {
    $log->error( "Missing required parameter organism" );
    exit;
  } elsif ( !$self->validateOrganism() ) {
    $log->error( "Invalid organism" );
    exit;
  }

  # Check args and set defaults
  $args{source} ||= 'db';

  if ( $args{source} eq 'db' ) {
    unless ( $self->kegg_tables_exist() ) {
      $log->warn( "Kegg tables not installed, proceeding manually" );
      $args{source} = 'kegg';
    }
  }

  my $result;

  # kegg api-based method, to be replaced with caching version
  if ( $args{source} =~ /kegg/i ) {

    my $service = $self->get_service();
    $result = $service->list_pathways( $args{organism} ); 

  } elsif (  $args{source} =~ /db/i ) {
    # Fetch info from the database
    $result = $self->list_db_pathways( %args ); 
  } else {
  }
  # ref to array of hashrefs
  return $result;
}


#+
# Method to fetch gene info from KEGG
#-
sub getGeneInfo {
  my $self = shift;
  my %args = @_;

  # Check args and set defaults
  unless ( $args{genes} && ref($args{genes}) eq 'ARRAY' ) {
    $log->error( "missing required parameter genes" );
    exit;
  }

  my $org = $self->getOrganism();

  my @genes;
  my $cnt = 0;
  while ( @{$args{genes}} ) {
    $cnt++;
    my $gene_string;
    for ( my $i = 0; $i < 50; $i++ ) {
      $gene_string .= ' ' . "$org:" . shift( @{$args{genes}} ); 
      last unless scalar @{$args{genes}};
    }
    my $service = $self->get_service();
    my $gene_info = $service->btit( $gene_string ); 
    $log->debug( "processing batch # $cnt" );

    foreach my $line ( split /\n/, $gene_info ) {
      my ( $gene_id, $symbol, $defn ) = ($line =~ /$org:(\S+)\s+([^;]+);\s+(.*)/);
      # Multiple gene symbols
      if ( $symbol =~ /,/ ) {
        my @syms = split( /,/, $symbol );
        $symbol = $syms[0];
        $defn = "(AKA " . join /,/, @syms[1..$#syms] . ") $defn";
      }
      push @genes, { gene_id => $gene_id, symbol => $symbol,
                        defn => $defn, annotline => $line };
    }
  }
  $log->debug( "got info for " . scalar( @genes ) . "  total genes" );
  return \@genes;
}


#+
# Check specified organism to see if it is supported.
#-
sub validateOrganism {
  my $self = shift;
  my $organisms = $self->getSupportedOrganisms();
  unless ( grep( /$self->{_organism}/, @{$organisms} ) ) {
    $log->error( "Organism $self->{_organism} not supported" );
    return 0;
  }
  return 1;
}

sub fetch_image {
  my $self = shift;
  my %args = @_;

  # Sort out the arguments
  my $path = $args{pathway} || $self->{_pathway}; 
  $path =~ s/path://g;
  my $org = $args{organism} || $self->{_organism}; 
  for my $req ( $path, $org ) {
    die "Missing required parameter" unless $req;
  }

  my $base = $CONFIG_SETTING{KEGG_IMAGE_URL} || 
    "ftp://ftp.genome.ad.jp/pub/kegg/pathways/__KEGG_ORG__/BASE.gif";

  $base =~ s/BASE/$path/g;
  $base =~ s/__KEGG_ORG__/$org/g;

  my $image_path = "/net/dblocal/data/sbeams/KEGG_MAPS/$org/$path.gif";

  return $image_path if -e $image_path;  #short circuit if image is already there.

  # Fetch response
  my $ua = LWP::UserAgent->new();
  my $response = $ua->get( $base );


  my $image = $response->content;

  open( IMAGE, ">$image_path" );
  print IMAGE $image;
  close IMAGE;

  return $image_path;
}

sub fetchPathwayXML {
  my $self = shift;
  my %args = @_;

  # Sort out the arguments
  my $path = $args{pathway} || $self->{_pathway}; 
  $path =~ s/path://g;
  my $org = $args{organism} || $self->{_organism}; 
  for my $req ( $path, $org ) {
    die "Missing required parameter" unless $req;
  }

  my $base = $CONFIG_SETTING{KGML_URL} || 
    "ftp://ftp.genome.jp/pub/kegg/xml/KGML_v0.6.1/$org/BASE.xml";
#    $base = "ftp://ftp.genome.jp/pub/kegg/xml/organisms/$org/BASE.xml";
#    $log->debug( "kegg earl is $base" );

  $base =~ s/BASE/$path/g;
  $base =~ s/__KEGG_ORG__/$org/g;

  # Fetch response
  my $ua = LWP::UserAgent->new();
  my $response = $ua->get( $base );

  $self->{xml} = $response->content;
  my %results = ( xml => $response->content(),
                  url => $base );

  return \%results;
#  return $response->content();
}

#+
# Fetch and parse KGML file for this pathway
#- 
sub parsePathwayXML {
  my $self = shift;
  my %args = @_;

  # Sort out the arguments
  my $path = $args{pathway} || $self->{_pathway}; 
  $path =~ s/path://g;
  my $org = $args{organism} || $self->{_organism}; 
  for my $req ( $path, $org ) {
    die "Missing required parameter" unless $req;
  }

  my $parser = SBEAMS::BioLink::KGMLParser->new();

  $args{source} ||= 'db';
  if ( $args{source} eq 'db' && $self->kegg_tables_exist() ) {
    my ( $kgml ) = $sbeams->selectrow_array( <<"    END" );
    SELECT kgml FROM $TBBL_KEGG_PATHWAY
    WHERE kegg_pathway_name = 'path:$path'
    END
    if ( $kgml ) {
      $parser->set_string( xml => $kgml );
    } else {
      $log->error( "Failed to retrieve KGML from database" );
      exit;
    }
  } else {
    my $base = $CONFIG_SETTING{KGML_URL} || 
      "ftp://ftp.genome.jp/pub/kegg/xml/KGML_v0.6.1/$org/BASE.xml";

    $base =~ s/BASE/$path/g;
    $base =~ s/__KEGG_ORG__/$org/g;


    $parser->set_url( url => $base );
    if ( !$parser->fetch_url() ) {
      $log->error( "Failed to fetch KGML from KEGG" );
      return undef;
    }
  }
  $parser->parse() || $log->debug("xml failed to parse, eh");
  return $self->processEntries( entries => $parser->{_entries} );
}

#+
# Get list of genes in pathway, currently via KEGG API.
#-
sub getPathwayGenes {
  my $self = shift;
  my %args = @_;

  $args{source} ||= 'db';
  my $pathway = $args{pathway} || $self->{_pathway};
  if ( !$pathway ) {
    $log->error( "Pathway not set" );
    exit;
  } elsif ( !$self->{_organism} ) {
    $pathway =~ /path:(\w{3})(\d*)/;
    $self->{_organism} = $1;
    $self->validateOrganism( $self->{_organism} );
  }

  my $result;
  if ( $args{source} eq 'db' && $self->kegg_tables_exist() ) {
    $result = $self->get_db_pathway_genes( pathway => $pathway,
                                           organism => $self->{_organism} );
  } else {
    my $service = $self->get_service();
    $result = $service->get_genes_by_pathway($pathway);
  }

  my @gene_list;
  for my $gene ( @$result ) {
    $gene =~ s/$self->{_organism}://g;
    if ( $self->{_organism} eq 'hsa' || $args{not_keys}  ) {
      push @gene_list, $gene;
    } else {
      push @gene_list, "'" . $gene . "'";
    }
  }
  return \@gene_list;
}

#+
# Routine to get relationships between genes in pathway
#-
sub getPathwayRelationships {
  my $self = shift;
  my %args = @_;

  my $pathway = $args{pathway} || $self->{_pathway};
  if ( !$pathway ) {
    $log->error( "Pathway not set" );
    exit;
  } elsif ( !$self->{_organism} ) {
    $pathway =~ /path:(\w{3})(\d*)/;
    $self->{_organism} = $1;
    $self->validateOrganism( $self->{_organism} );
  }
  my $service = $self->get_service();
  
  # Fetch elements and relationships from KEGG
  my $elements_by_path = $service->get_elements_by_pathway($pathway);
  my $relations_by_path = $service->get_element_relations_by_pathway($pathway);
  
  my %elements; # hash of elements and associated genes/connections
  my @groups;   # Temp storage for 'groups' of genes
  my %genes;    # List of gene entities, we return only these 

  # Loop over the elements, store genes and save groups for subsequent analysis.
  for my $result ( @{$elements_by_path} ) {
    my $type = $result->{type};
    my $element_id = $result->{element_id};
    if ( $type eq 'group' ) {
      push @groups, $result;
    } 
    if ( $type !~ /gene/ ) {
      next;
    }
    my $names = $result->{names};
    $genes{$element_id}++;
    $elements{$element_id} ||= {};
    for my $gene ( @$names ) {
      $elements{$element_id}->{genes} ||= [];
      push @{$elements{$element_id}->{genes}}, $gene;
    }
  }
  
  # Now that we know which elements are genes, we can process the groups
  for my $group ( @groups ) {
    my $element_id = $group->{element_id};
    $elements{$element_id} ||= {};
    $elements{$element_id}->{genes} ||= [];
    for my $component ( @{$group->{components}} ) {
      if( $genes{$component} ) { # only process if this group component is a gene
        my $c_genes = $elements{$component}->{genes} || [];
        for my $gene ( @$c_genes ) {
          push @{$elements{$element_id}->{genes}}, $gene;
        }
      }
    }
  }
  
  
  # Loop over reported relationships
  for my $result ( @{$relations_by_path} ) {
    my $type = $result->{type};

    # Skip out unless it is a protein-protein relationship
    next unless $type && $type eq 'PPrel';

    # Each relationship follows a e1 description e2 pattern 
    my $element1 = $result->{element_id1};
    next unless $elements{$element1}; # Exit unless we've stored info about this
      
    my $element2 = $result->{element_id2};
    next unless $elements{$element2}; # Exit unless we've stored info about this

    # Record connection, relation, and type ( e.g. 25 inhibition 22 --| ) - 
    $elements{$element1} ||= {};
    $elements{$element1}->{connex} ||= [];
    $elements{$element1}->{relation} ||= [];
    $elements{$element1}->{relation_type} ||= [];
    my $rel = '';
    my $rel_type = '';
    my $subtypes = $result->{subtypes}->[0];
    if ( $subtypes ) {
      $rel = $subtypes->{relation};
      $rel_type = $subtypes->{type};
    }
    # Store relationship info in 3 parallel arrayrefs
    push @{$elements{$element1}->{connex}}, $element2;
    push @{$elements{$element1}->{relation}}, $rel;
    push @{$elements{$element1}->{relation_type}}, $rel_type;
  }
  
  # Array of derived relationships
  my @relationships;

  # Loop through keys of elements array, cacheing the ones with needed info.
  for my $e1 ( sort { $a <=> $b } ( keys( %elements ) ) ) {

    # Skip those without connection info
    next unless $elements{$e1}->{connex}; 

    my @connex =  @{$elements{$e1}->{connex}};
    for ( my $i = 0; $i <= $#connex; $i++ ) { # For each connection record
      my $e2 = $connex[$i];
      my $rel      =  $elements{$e1}->{relation}->[$i];
      my $rel_type =  $elements{$e1}->{relation_type}->[$i];
      my $e1_genes = $elements{$e1}->{genes};
      my $e2_genes = $elements{$e2}->{genes};
      for my $g1 ( @$e1_genes ) { # For each gene defined by element_id 1
        for my $g2 ( @$e2_genes ) { # For each gene defined by element_id 2

          push @relationships, [ $g1, $g2, $rel_type, $rel ];
        }
      }
    }
  }

  # Return reference to array of relationships
  return( \@relationships );
}

#+
# Routine to get Kegg to color pathway with expressed genes
#-
sub getColoredPathway {
  my $self = shift;
  my %args = @_;
  $log->debug( 'here' );
  for my $key ( qw( genes bg fg ) ) {
    if ( !$args{$key} ) {
      $log->error( "Missing required parameter $key" );
      exit;
    } elsif ( ref $args{$key} ne 'ARRAY' ) {
    }
  }
  $log->debug( 'there' );
  my $pathway = $args{pathway} || $self->{_pathway};
  if ( !$pathway ) {
    $log->error( "Pathway not set" );
    exit;
  }
  if ( $pathway !~ /^path:/ ) {
    $pathway = 'path:' .  $pathway;
  }

  my $cnt = 0;
  my $all = '';
  for my $g ( @{$args{genes}} ) {
    $cnt++;
    $all .= " $g"; 
  }
  $cnt = 0;
  $all = '';
  for my $g ( @{$args{fg}} ) {
    $cnt++;
    $all .= " $g"; 
  }
  $cnt = 0;
  $all = '';
  for my $g ( @{$args{bg}} ) {
    $cnt++;
    $all .= " $g"; 
  }
  $log->debug( 'everywhere' );

  my $genes = SOAP::Data->type( array => $args{genes} );
  my $fg = SOAP::Data->type( array => $args{fg} );
  my $bg = SOAP::Data->type( array => $args{bg} );

  my $service = $self->get_service();
  my $url = $service->color_pathway_by_objects("$pathway", $genes, $fg, $bg ) ;
  return $url if $url;
  $log->info( "Initial fetch for $pathway failed!: $!" );
  $url = $service->color_pathway_by_objects("$pathway", $genes, $fg, $bg ) ;
  return $url if $url;
  print "</DIV>Unable to fetch pathway from KEGG, please try again later. </BODY></HTML>\n";
  exit;

}

sub getSupportedOrganisms {
  my $self = shift;
  my @organisms;
  if ( $self->kegg_tables_exist() ) {
    my $sql = "SELECT DISTINCT kegg_organism_name FROM $TBBL_KEGG_ORGANISM";
    @organisms = $sbeams->selectOneColumn( $sql );  
  } else {
    $log->info( "Kegg caching tables not installed, see BioLink.installnotes: $@\n" );
    @organisms = (qw( hsa sce dme mmu ) );
  }
  return \@organisms;
}

##  Routines for handling cached KEGG data

#+
# fetch pathway info from database, as opposed to from kegg API directly
#-
sub list_db_pathways { # $args{organism} ); 
  my $self = shift;
  my %args = @_;

  unless( defined $args{organism} ) {
    $log->error( "missing required arguement organism" );
    exit;
  }
  my $org_id = $self->getOrganismID( name => $args{organism} );
  my @db_rows;
  if ( $args{genes} ) {
    my $in = '';
    my $sep = '';
    for my $gene ( @{$args{genes}} ) {
      $in .= $sep . "'" . $gene . "'";
    }
    @db_rows = $sbeams->selectSeveralColumns( <<"    END");
    SELECT kegg_pathway_name, kegg_pathway_description
    FROM $TBBL_KEGG_PATHWAY KP JOIN $TBBL_KEGG_PATHWAY_GENES KPG
      ON KPG.kegg_pathway_id = KP.kegg_pathway_id
    JOIN $TBBL_KEGG_GENE KG 
      ON KG.kegg_gene_id = KPG.kegg_gene_id
    WHERE KP.kegg_organism_id = $org_id
      AND gene_id IN ( $in )
    ORDER BY kegg_pathway_name ASC
    END
    $log->debug( $sbeams->evalSQL( <<"    END" ) );
    SELECT kegg_pathway_name, kegg_pathway_description
    FROM $TBBL_KEGG_PATHWAY KP JOIN $TBBL_KEGG_PATHWAY_GENES KPG
      ON KPG.kegg_pathway_id = KP.kegg_pathway_id
    JOIN $TBBL_KEGG_GENE KG 
      ON KG.kegg_gene_id = KPG.kegg_gene_id
    WHERE KP.kegg_organism_id = $org_id
      AND gene_id IN ( $in )
    ORDER BY kegg_pathway_name ASC
    END
  } else {
    @db_rows = $sbeams->selectSeveralColumns( <<"    END");
    SELECT kegg_pathway_name, kegg_pathway_description
    FROM $TBBL_KEGG_PATHWAY
    WHERE kegg_organism_id = $org_id
    ORDER BY kegg_pathway_name ASC
    END
  }

  my @results;
  for my $row ( @db_rows ) {
    push @results, {entry_id => $row->[0], definition => $row->[1]}; 
  }
  return \@results;
}

#+
# fetch pathway info from database, as opposed to from kegg API directly
#-
sub get_db_pathway_genes { # $args{organism} ); 
  my $self = shift;
  my %args = @_;

  for my $required ( qw( pathway organism ) ) {
    unless( $args{$required} ) {
      $log->error( "missing required argument $required" );
      exit;
    }
  }
  my $org_id = $self->getOrganismID( name => $args{organism} );

  my @db_rows = $sbeams->selectOneColumn( <<"  END");
  SELECT gene_id
  FROM $TBBL_KEGG_GENE KG 
  JOIN $TBBL_KEGG_PATHWAY_GENES KPG
    ON KG.kegg_gene_id = KPG.kegg_gene_id
  JOIN $TBBL_KEGG_PATHWAY KP
    ON KP.kegg_pathway_id = KPG.kegg_pathway_id
  WHERE KP.kegg_pathway_name = '$args{pathway}'
  AND KG.kegg_organism_id = $org_id
  ORDER BY gene_id ASC
  END

  return \@db_rows;
}

#+
# Delete pathway data for specified organism
#-
sub delete_pathway_cache {
  my $self = shift;
  my %args = @_;

  unless( defined $args{organism} ) {
    $log->error( "missing required arguement organism" );
    exit;
  }

#  for my $org ( @{$args{organism}} ) {
    $self->setOrganism( organism => $args{organism} );
    my $org_id = $self->getOrganismID( name => $args{organism} );

    my $path_sql =<<"    END";
    DELETE FROM $TBBL_KEGG_PATHWAY WHERE kegg_organism_id = $org_id 
    END

    my $path_genes_sql =<<"    END";
    DELETE FROM $TBBL_KEGG_PATHWAY_GENES 
    WHERE kegg_gene_id IN
      ( SELECT kegg_gene_id FROM $TBBL_KEGG_GENE 
        WHERE kegg_organism_id = $org_id )
    END

    my $gene_sql =<<"    END";
    DELETE FROM $TBBL_KEGG_GENE WHERE kegg_organism_id = $org_id
    END

    $sbeams->initiate_transaction();
    eval {
      $sbeams->do( $path_sql );
      $sbeams->do( $path_genes_sql );
      $sbeams->do( $gene_sql );
    };
    if ( $@ ) {
      $log->error( "Error running SQL: $@" );
      $sbeams->rollback_transaction();
    } else {
      $sbeams->commit_transaction();
    }
#  }
}

sub load_pathway_cache {
  my $self = shift;
  my %args = @_;

  unless( defined $args{organism} ) {
    $log->error( "missing required arguement organism" );
    exit;
  }

#  for my $org ( @{$args{organism}} ) {
  $self->setOrganism( organism => $args{organism} );
  my $org_id = $self->getOrganismID( name => $args{organism} );

  # Fetch pathways for org
  my $pathways = $self->getKeggPathways( organism => $args{organism},
                                           source => 'kegg' );

  for my $path ( @$pathways ) {
    
    # keys are description, entry_id

    # Fetch genes for pathway
    my $genes = $self->getPathwayGenes( pathway => $path->{entry_id}, 
                                         source => 'kegg',
                                       not_keys => 1 );

    my $gene_info = $self->getGeneInfo( genes => $genes );
    my $kgml = $self->fetchPathwayXML( pathway => $path->{entry_id} );
    my $image_path = $self->fetch_image( pathway => $path->{entry_id} );

    # Insert pathway, genes
    $sbeams->initiate_transaction();

    eval {
      my ($path_id) = $sbeams->selectrow_array( <<"      END" );
      SELECT kegg_pathway_id 
      FROM $TBBL_KEGG_PATHWAY 
      WHERE kegg_pathway_name = '$path->{entry_id}'
      END

      if ( !$path_id ) {
        my %kpath = ( kegg_pathway_name => $path->{entry_id},
                      kegg_pathway_description => $path->{definition}, 
                      kegg_organism_id  => $org_id,
                      kgml  => $kgml->{xml},
                      kgml_url => $kgml->{url},
                      image  => $image_path,
                      date_modified => $sbeams->get_datetime() );

        $path_id = $sbeams->updateOrInsertRow( table_name => $TBBL_KEGG_PATHWAY,
                                              rowdata_ref => \%kpath,
                                                  return_PK => 1,
                                                  PK_name => 'kegg_pathway_id',
                                                   insert => 1 );
      }

      for my $gene ( @$gene_info ) {

        my ($kgene_id) = $sbeams->selectrow_array( <<"        END" );
        SELECT kegg_gene_id 
        FROM $TBBL_KEGG_GENE 
        WHERE gene_id = '$gene->{gene_id}'
        END

        if ( !$kgene_id ) {
          my %kgene = ( kegg_organism_id => $org_id,
                        gene_id => $gene->{gene_id},
                        gene_symbol => $gene->{symbol},
                        gene_description => $self->clip($gene->{defn}),
                        annotation_line => $self->clip($gene->{annotline}) );
  
          $kgene_id = $sbeams->updateOrInsertRow( table_name => $TBBL_KEGG_GENE,
                                                rowdata_ref => \%kgene,
                                                    PK_name => 'kegg_gene_id',
                                                  return_PK => 1,
                                                     insert => 1 );
        } else {
          $log->debug( "Gene $gene->{gene_id} already inserted" );
          # We assume the join table is already populated, is this correct?
          # next;
        }
        next unless $kgene_id && $path_id;

        my ($joincnt) = $sbeams->selectrow_array( <<"        END" );
        SELECT COUNT(*) FROM $TBBL_KEGG_PATHWAY_GENES
        WHERE kegg_gene_id = $kgene_id
        AND kegg_pathway_id = $path_id
        END

        if ( !$joincnt ) {
          $sbeams->do( <<"          END" );
          INSERT INTO $TBBL_KEGG_PATHWAY_GENES
          (kegg_gene_id, kegg_pathway_id) VALUES
          ( $kgene_id, $path_id )
          END
        }
      }

    };
    if ( $@ ) {
      $log->error( "Error running SQL: $@" );
      $sbeams->rollback_transaction();
    } else {
      $sbeams->commit_transaction();
    }
  }
}

sub clip {
  my $self = shift;
  my $string = shift;
  return ( length($string) > 255 ) ? substr( $string, 0, 255 ) : $string;
}


### Private Methods ###

1;
