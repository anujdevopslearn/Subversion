###############################################################################
# $Id: KeggMaps.pm $
#
# Description : Module to support fetch and  display gene expression on Kegg pathway maps.
#
# SBEAMS is Copyright (C) 2000-2013 Institute for Systems Biology
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
use Data::Dumper;

use lib "../..";
#use vars qw( @EXPORT_OK $PHYSICAL_BASE_DIR );
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

# my $keggmap = SBEAMS::BioLink::KeggMaps->new();
# my $pathways = $keggmap->getKeggPathways( organism => $kegg_organism );
# $keggmap->setPathway( pathway => $params->{path_id} );
# my $gene_list = $keggmap->getPathwayGenes(); # pathway => $params->{path_id} );
#  my $relationships = $keggmap->getPathwayRelationships();
# my $url = $keggmap->getColoredPathway( bg => $bg,
# my $processed = $keggmap->parsePathwayXML();
# my $image_map = $keggmap->get_image_map( coords => $processed->{coords},

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
  $this->{_service} ||= Service->new();
  return $this->{_service};

  # Deprecated by KEGG as of 2012-12-31
  my $wsdl = $this->getWSDL() || die "Missing required WSDL";

  eval {
    $this->{_service} ||= SOAP::Lite->service($wsdl);
  };
  if ( $@ ) {
    $log->error( "Unable to connect to KEGG SOAP service" );
    $log->error( $@ );
  }
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

#+
# Get kegg organism code based on organism_id 
#-
sub getOrganismCode {
  my $this = shift;
  my %args = @_;

  return '' unless $args{organism_id} && $args{organism_id} =~ /^\d+$/ ;
      
  my $sql = qq~ 
  SELECT kegg_organism_name 
  FROM $TBBL_KEGG_ORGANISM 
  WHERE organism_id = $args{organism_id};
  ~;

  my ($org_code) = $sbeams->selectrow_array( $sql );

  return $org_code || '';
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
  my @allgenes = keys( %allgenes );
  my $gene2uniprot = $self->translateKeggAccessions( genes => \@allgenes );
 

  my %uniprot;
  for my $lgene ( @allgenes ) {
    my $gene = $lgene;
    $gene =~ s/$self->{_organism}://;
    next unless $gene2uniprot->{$gene};
    for my $uniprot ( keys( %{$gene2uniprot->{$gene}} ) ) {
      $uniprot{$uniprot}++;
    }
  }

  my %entry2uniprot_href;
  for my $entry ( keys( %entry2genes ) ) {
    $entry2uniprot_href{$entry} ||= {};
    for my $lgene ( @{$entry2genes{$entry}} ) {
      my $gene = $lgene;
      $gene =~ s/$self->{_organism}://;
      next unless $gene2uniprot->{$gene};
      for my $uniprot ( keys( %{$gene2uniprot->{$gene}} ) ) {
        $uniprot{$uniprot}++;
        $entry2uniprot_href{$entry}->{$uniprot}++;
      }
    }
  }
  my %entry2uniprot;
  for my $entry ( keys( %entry2uniprot_href ) ) {
    my @entry_keys = keys( %{$entry2uniprot_href{$entry}} );
    $entry2uniprot{$entry} = \@entry_keys;
  }

  my %processed = ( entries  => \@entries,
                    coords   => \@coordinates,
                    allgenes => [keys(%allgenes)],
                gene2entries => \%gene2entries,
                 entry2genes => \%entry2genes,
                     uniprot => [keys(%uniprot)],
               entry2uniprot => \%entry2uniprot,
                gene2uniprot => $gene2uniprot,
                   );

  $self->{_processed} = \%processed;

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
    $map .= "<DIV background-color: green><AREA SHAPE='RECT' CLASS='expressed_gene' BACKGROUND=$colors[$cnt] COORDS='$coords' TITLE='$text' TARGET='_evidence' $href></DIV>\n";
    $cnt++;
  }
  $map .= "</MAP>\n";
#  return ( wantarray ) ? ($link, $map) : $link . $map;
  return "$colors\n$link\n$map";
}


sub kegg_tables_exist {
  my $self = shift;
  return 0;
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
    $sbeams->set_page_message( type => "Error", msg => "No pathways available for $self->{_organism}" );
    return;
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
    my @results;
    for my $line ( split( /\n/, $result ) ) {
      $line =~ /^(path:\w+\d+)\s+(\w+.*)$/;
      push @results, { entry_id => $1, definition => $2 }; 
    }
    return \@results;

  } elsif (  $args{source} =~ /db/i ) {
    # Fetch info from the database
    $result = $self->list_db_pathways( organism => $args{organism} ); 
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
        $defn = "(AKA " . join ',', @syms[1..$#syms] . ") $defn";
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

  my $image_path = "/net/dblocal/data/sbeams/KEGG_MAPS/$org/$path.png";

  return $image_path if -e $image_path;  #short circuit if image is already there.

  die "In fetch_image";
  my $service = $self->get_service();
  my $img = $service->get_pathway_image( $path );

  open( IMAGE, ">$image_path" );
  print IMAGE $img;
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
    "ftp://ftp.genome.jp/pub/kegg/xml/organisms/$org/BASE.xml";

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
  $path =~ /(\w\w\w)(.+)/;

  $self->{_organism} = $1;

  my $org = $args{organism} || $self->{_organism}; 
  for my $req ( $path, $org ) {
    die "Missing required parameter $req" unless $req;
  }

  my $parser = SBEAMS::BioLink::KGMLParser->new();

  $args{source} ||= 'db';
  my $kgml = '';
  if ( $args{source} eq 'db' && $self->kegg_tables_exist() ) {
    my $sql = <<"    END"; 
    SELECT kgml FROM $TBBL_KEGG_PATHWAY
    WHERE kegg_pathway_name = 'path:$path'
    END
    ( $kgml ) = $sbeams->selectrow_array( $sql );
    if ( !$kgml ) {
      $log->warn( "Failed to fetch KGML db:\n $sql" );
      $log->warn( "Falling back to direct fetch from KEGG" );
      my $service = $self->get_service();
      $kgml = $service->get_pathway_kgml( $path );
		}

  } else {
    if ( -e "$PHYSICAL_BASE_DIR/tmp/images/kegg/$org/$path.kgml" ) {
      undef local $/;
      open KGML, "$PHYSICAL_BASE_DIR/tmp/images/kegg/$org/$path.kgml";
      $kgml = <KGML>;
      close KGML;
    } else {
      my $service = $self->get_service();
      $kgml = $service->get_pathway_kgml( $path );
      open KGML, ">$PHYSICAL_BASE_DIR/tmp/images/kegg/$org/$path.kgml";
      print KGML $kgml;
      close KGML;
    }
  }
  if ( $kgml ) {
    $parser->set_string( xml => $kgml );
  } else {
    $log->error( "Unable to retrieve KGML from db or KEGG" );
    return;
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
#  if ( $args{source} eq 'db' && $self->kegg_tables_exist() ) {
  if ( $args{source} eq 'db' ) {
    $result = $self->get_db_pathway_genes( pathway => $pathway,
                                           organism => $self->{_organism} );
  } else {
    $result = $self->{_processed}->{allgenes};
  }

  my @gene_list;
  for my $gene ( @$result ) {
    $gene =~ s/$self->{_organism}://g;
    if ( $args{not_keys}  ) {
      push @gene_list, $gene;
    } else {
      push @gene_list, "'" . $gene . "'";
    }
  }
  return \@gene_list;
}

#+
# Routine to get Kegg to color pathway with expressed genes
#-
sub getColoredPathway {
  my $self = shift;
  my %args = @_;
  for my $key ( qw( genes seen ) ) {
    if ( !$args{$key} ) {
      $log->error( "Missing required parameter $key" );
      exit;
    } elsif ( ref $args{$key} ne 'ARRAY' ) {
    }
  }
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
  $log->debug( $cnt . ' genes ' . $all );

  my $service = $self->get_service();
  my $path = $service->get_pathway_image( pathway => $pathway ) ;

#  open( IMAGE, ">$image_path" );
#  print IMAGE $img;
#  close IMAGE;
#  die $url;

  my @path = split( /\//, $path );
  my $file = pop( @path );
  my $colored_file = 'PA_' . $args{atl_as_build_id} . '_' . $file;
  my $colored_path = join( '/', @path ) . "/$colored_file";

  if ( -e $colored_path ) {
    return "$HTML_BASE_DIR/$colored_file";
  }
  my $color_image = $self->color_pathway( path => $path, color_path => $colored_path, %args );
  return "$HTML_BASE_DIR/$colored_path"; 

  print "</DIV>Unable to fetch pathway from KEGG, please try again later.</BODY></HTML>\n";
  exit;
}

sub color_pathway { 
  my $self = shift;
  my %args = @_;

# URL
# seen
# path
# color_path
# genes
# _processed
# ( entries  => \@entries,
# coords   => \@coordinates,
# allgenes => [keys(%allgenes)],
# gene2entries => \%gene2entries,
# entry2genes => \%entry2genes,
# uniprot => [keys(%uniprot)],
# entry2uniprot => \%entry2uniprot,
# gene2uniprot => $gene2uniprot,
# );

  my %local_gene2entry;
  for my $long_entry ( keys( %{$self->{_processed}->{gene2entries}} ) ) {
    my $short_entry = $long_entry;
    $short_entry =~ s/$self->{_organism}://g;
    $local_gene2entry{$short_entry} = $self->{_processed}->{gene2entries}->{$long_entry};
  }

  my $idx = 0;
  my %entries;
  for my $gene ( @{$args{genes}} ) {
    my $seen = $args{seen}->[$idx];
    next unless $local_gene2entry{$gene};
    for my $entry ( @{$local_gene2entry{$gene}} ) {
      $entries{$entry} += $seen;
    }
    $idx++;
  }
  $self->{_args} = \%args;
  $self->{_entries_obs} = \%entries;

  $idx = 0;
  my $seen_cmd = "convert $PHYSICAL_BASE_DIR/$args{path} -strokewidth 0 -fill 'rgba(152,251,152,0.60)' -draw ";
  my $unseen_cmd = "convert $PHYSICAL_BASE_DIR/$args{path}.tmp -strokewidth 0 -fill 'rgba(255,255,0,0.60)' -draw ";

  my $seen_sep = '';
  my $unseen_sep = '';

  for my $entry ( @{$self->{_processed}->{entries}} ) {
    my $coords = $self->{_processed}->{coords}->[$idx];
    if ( $entries{$entry} ) {
      $seen_cmd = $seen_cmd . $seen_sep . '"rectangle ' . $coords . '"';
      $seen_sep = ',';
    } else {
      $unseen_cmd = $unseen_cmd . $unseen_sep . '"rectangle ' . $coords . '"';
      $unseen_sep = ',';
    }
    $idx++;
  }
  $seen_cmd .= " $PHYSICAL_BASE_DIR/$args{path}.tmp";
  $unseen_cmd .= " $PHYSICAL_BASE_DIR/$args{color_path}";
  if ( $seen_sep ) {
    `$seen_cmd`;
  } else {
    `cp $PHYSICAL_BASE_DIR/$args{path} $PHYSICAL_BASE_DIR/$args{path}.tmp`
  }

  if ( $unseen_sep ) {
    `$unseen_cmd`;
  } else {
    `cp $PHYSICAL_BASE_DIR/$args{path}.tmp $PHYSICAL_BASE_DIR/$args{color_path}`
  }
  unlink "$PHYSICAL_BASE_DIR/$args{path}.tmp";
  return $args{color_path}
}


sub getSupportedOrganisms {
  my $self = shift;
  my $sql = "SELECT DISTINCT kegg_organism_name FROM $TBBL_KEGG_ORGANISM";
  my @organisms = $sbeams->selectOneColumn( $sql );  
#  if ( $self->kegg_tables_exist() ) {
  if ( !scalar( @organisms ) ) {
    $log->info( "Kegg caching tables not installed, see BioLink.installnotes: $@\n" );
    @organisms = (qw( hsa sce dme mmu ssc ) );
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

  my @db_rows = $sbeams->selectSeveralColumns( <<"  END");
  SELECT kegg_pathway_name, kegg_pathway_description
  FROM $TBBL_KEGG_PATHWAY
  WHERE kegg_organism_id = $org_id
  ORDER BY kegg_pathway_name ASC
  END

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

#+
# Routine to get relationships between genes in pathway
#-
sub getPathwayRelationships {
  my $self = shift;
  my %args = @_;

  # Test options and set up SOAP service
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
      if( $genes{$component} ) { # only process if component is a gene
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
  $log->debug( 'Found ' . scalar( @relationships ) . " relationships for $pathway" );
  return( \@relationships );
}


sub translateKeggAccessions {
  my $self = shift; 
  my %args = @_;
  my $genes = $args{genes} || return {};
  return {} unless ( $genes && ref( $genes ) eq 'ARRAY' );

  my $genestr = "'" . join( "','", @{$genes} ) . "'";
  $genestr =~ s/$self->{_organism}://g;

  my $sql = qq~
  SELECT kegg_accession, uniprot_accession 
  FROM biolink.dbo.kegg_accession 
  WHERE kegg_accession IN ( $genestr )
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  my %gene2uniprot;
  while ( my @row = $sth->fetchrow_array ) {
    $gene2uniprot{$row[0]} ||= {};
    $gene2uniprot{$row[0]}->{$row[1]}++;
  }
  return \%gene2uniprot;
}


# Inner class Service
# Abstracts conversion of KEGG API from SOAP to REST
{
package Service;
use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Settings;
use Data::Dumper;
use File::Copy qw( copy move );

#  http://rest.kegg.jp/list/pathway/hsa
#  http://rest.kegg.jp/get/path:hsa00010/image
#  http://rest.kegg.jp/get/path:hsa00010/kgml

sub new {
  my $class = shift;
  my $self = { @_ };

  $self->{_user_agent} = LWP::UserAgent->new();

  # Objectification.
  bless $self, $class;

  return $self;
}

# Get list of pathways - from db or kegg?
sub list_pathways {
  my $self = shift;
  my $org = shift || return '';
  my $url = "http://rest.kegg.jp/list/pathway/$org";
  my $response = $self->{_user_agent}->get( $url );
  return $response->{_content};
}


    
sub btit {
  my $self = shift;
  my $gene_string = shift || return '';
}

sub get_elements_by_pathway {
  my $self = shift;
  my $pathway = shift || return '';
}

sub get_element_relations_by_pathway {
  my $self = shift;
  my $pathway = shift || return '';
}

sub get_genes_by_pathway {
  my $self = shift;
  my $pathway = shift || return '';
}

sub color_pathway_by_objects {
}

sub get_pathway_image {
  my $self = shift;
  my %args = @_;

  # Sort out the arguments
  my $path = $args{pathway} || $self->{_pathway}; 
  my $short_path = $path;
  $short_path =~ s/path://g;

  my $org = $args{organism} || $self->{_organism}; 
  $short_path =~ /([a-z]+)(\d+)/;
  $org ||= $1;

  for my $req ( $short_path, $org ) {
    die "Missing required parameter" unless $req;
  }

  my $image_path = "/tmp/images/kegg/$org/$short_path.png";
  my $new_image_path = "/tmp/images/kegg/$org/$short_path" . "_new.png";

  if ( -e "$PHYSICAL_BASE_DIR/$image_path" ) {  #short circuit if image is already there.
    return $image_path; 
  } else { 
    my $img = $self->get_kegg_pathway_image( $path );
    open( IMAGE, ">$PHYSICAL_BASE_DIR/$image_path" );
    print IMAGE $img;
    close IMAGE;
  # The images from KEGG have green color, the following steps remove it, and
  # rely on having imageMagick 'convert' function available.
    system( 'convert ' . "$PHYSICAL_BASE_DIR/$image_path" . ' -channel alpha -fill white -transparent rgb\(191,255,191\) ' . "$PHYSICAL_BASE_DIR/$new_image_path" );
    system( " mv $PHYSICAL_BASE_DIR/$new_image_path $PHYSICAL_BASE_DIR/$image_path" );
    return $image_path; 
  }

  # No longer get to this code.
#

  # The images from KEGG have green color, the following steps remove it, and
  # rely on having imageMagick 'convert' function available.
  my $pre_path = "$PHYSICAL_BASE_DIR/tmp/images/kegg/proc/$short_path" . "_pre.png";
  my $post_path = "$PHYSICAL_BASE_DIR/tmp/images/kegg/proc/$short_path" . ".png";
  my $gif_path = "$PHYSICAL_BASE_DIR/tmp/images/kegg/proc/$short_path" . ".gif";

  eval {
    system( 'convert ' . $pre_path . ' -channel alpha -fill white -transparent rgb\(191,255,191\) ' . $post_path );
    system( 'convert ' . $post_path . ' ' . $gif_path );
    system( 'convert ' . $gif_path . ' ' . $post_path );
  };
  die;
  if ( $@ ) {
    # Error with color stripping.
    print STDERR "Error with convert: $@";
    copy ( $pre_path, $post_path );
  }
  if ( ! -e $post_path ) {
    # Error with color stripping.
    copy ( $pre_path, $post_path );
  }

  print "moving $post_path to $image_path";
  move ( $post_path, "$PHYSICAL_BASE_DIR/$image_path" ) || die $!; 
  unlink $pre_path;
  
}

sub get_kegg_pathway_image {
  my $self = shift;
  my $pathway = shift || return '';
  my $url = "http://rest.kegg.jp/get/$pathway/image";

  $log->info( "Fetching $url from kegg to get map\n" );


  my $response = $self->{_user_agent}->get( $url );
  return $response->{_content};
}

sub get_pathway_kgml {
  my $self = shift;
  my $pathway = shift || return '';
  my $url = "http://rest.kegg.jp/get/$pathway/kgml";
  my $response = $self->{_user_agent}->get( $url );

  return $response->{_content};
}

#  my $gene_info = $service->btit( $gene_string ); 
#  $result = $service->list_pathways( $args{organism} ); 
#  my $elements_by_path = $service->get_elements_by_pathway($pathway);
#  my $relations_by_path = $service->get_element_relations_by_pathway($pathway);
#  my $url = $service->color_pathway_by_objects("$pathway", $genes, $fg, $bg ) ;
#  $result = $service->get_genes_by_pathway($pathway);
  

} # End inner class Service

1;
