###############################################################################
# $Id$
#
# Description : Module which facilitates the lookup of information based on
# a set of genome coordinates. 
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::BioLink::GenomeCoordinates;
use strict;
#use vars qw ($current_contact_id $current_username $TABLE_NAME $DB_TABLE_NAME);

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( &getProbesets );

use lib "../..";

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::BioLink;
use SBEAMS::BioLink::Settings;
#use SBEAMS::BioLink::TableInfo;
use SBEAMS::BioLink::Tables;

use lib qw (../../lib/perl);

### Globals ###

my $sbeams = new SBEAMS::Connection;
my $sbeamsMOD = new SBEAMS::BioLink;
$sbeamsMOD->setSBEAMS($sbeams);

##### Public Methods ###########################################################
#
# Module provides interface to fetch information based on a set of genome 
# coordinates.

#+
# Constructor method.  
#
# narg  coordinate_string
# narg  genome_build_id
# narg  chromosome
# narg  start_pos 
# narg  end_pos 
# narg  strand 
#
#
sub new {
  my $class = shift;
  my $this = { @_ };

  foreach( keys( %$this ) ){ $log->debug( "$_ => $this->{$_}" ) }
  # Sanity check
  unless ( $this->{coordinate_string} ) {
    for( qw( genome_build_id chromosome start_pos end_pos strand ) ) {
      die ( "Must supply coordinate_string OR all constituent data (no $_)" )
        unless $this->{$_};
    }
  }
  # Objectification.
  bless $this, $class;

  # parse coordinate string.  coord_string values override those passed indivd.
  if( $this->{coordinate_string} ) {
    $this->_parseCoordinates();
  } else {
    $this->setOrganism();
  }
  
  $log->debug( 'gonna val' );
  # validate info.
  return undef unless $this->_validateCoordinates();
  $log->debug( 'val' );

  return $this;
}

### Non object methods ###

#+
# Wrapper method for class, exported.
#-
sub getProbesets {
  my %args = @_;

  $log->debug( "Called get probesets with coord_string => $args{coordinate_string}" );
  # Must supply coordinate string
  return undef unless $args{coordinate_string};
  my $gc = SBEAMS::BioLink::GenomeCoordinates->new( coordinate_string => $args{coordinate_string});
  return undef unless $gc;

  # Fetch info from stated coordinates
  # $gc->_fetchInfo();
  return $gc->_getResultSet();

  #
  # return ( wantarray() ) ? @{$gc->{probe_set_name}} : ${$gc->{probe_set_name}}[0];
}

### Private Methods ###


#+
#
#-
sub _getResultSet {
  my $this = shift;

  # Build array with the fields we will be fetching.
  
  my $sql =<<"  END_SQL";
  SELECT probe_set_name, genbank, gene_symbol, dots, gene_synonyms
  FROM $TBBL_CBIL_GENOME_COORDINATES
  WHERE chromosome = '$this->{chromosome}'
  AND organism_id = $this->{organism}
  AND ( $this->{start_pos} BETWEEN gene_start AND gene_end 
       OR  $this->{end_pos} BETWEEN gene_start AND gene_end 
       OR  gene_start BETWEEN $this->{start_pos} AND  $this->{end_pos} )
  END_SQL
  $log->debug( $sql );

  my $rsref = {};
  $sbeams->fetchResultSet( sql_query => $sql, resultset_ref => $rsref );
  
#use Data::Dumper;
# print Dumper( $rsref );

  $log->debug( "Found entities matching this range " );
  return $rsref;
}

#+
#
#-
sub _fetchInfo {
  my $this = shift;

  # Build array with the fields we will be fetching.
  my @fields = qw( probe_set_name genbank gene_symbol dots gene_synonyms );
  
  # Make each an array ref in parent object 
  foreach( @fields ){ $this->{$_} = [] }

  # Prepare them for inclusion in a SQL query
  my $fields = join ',', @fields;

  my $sql =<<"  END_SQL";
  SELECT $fields
  FROM $TBBL_CBIL_GENOME_COORDINATES
  WHERE chromosome = '$this->{chromosome}'
  AND organism_id = $this->{organism}
  AND ( $this->{start_pos} BETWEEN gene_start AND gene_end 
       OR  $this->{end_pos} BETWEEN gene_start AND gene_end 
       OR  gene_start BETWEEN $this->{start_pos} AND  $this->{end_pos} )
  END_SQL
  $log->debug( $sql );

#  $sql = eval( "\"$sql\"" );
#  $log->debug( $sql );

  my $dbh = $sbeams->getDBHandle();
  my $sth = $dbh->prepare( $sql );
  $sth->execute();
  my $cnt = 0;
  while( my $row = $sth->fetchrow_hashref() ) {
    foreach( @fields ) { push @{$this->{$_}}, $row->{$_}; }
    $cnt++;
  }
  $log->debug( "Found $cnt entities matching this range " );
}


#+
#
#-
sub _validateCoordinates {
  my $this = shift;
  # Test genome build 
  return 0 unless $this->_validateGenomeBuild();
  # Test chromosome values?
  # Test start < end?
  # Test strand?
  return 1;
}


#+
# Checks build_id against current valid builds.  Returns 1 on success, else 0
#-
sub _validateGenomeBuild {
  my $this = shift;
  # Current valid genome identifiers
  if ( lc($this->{genome_build_id}) =~ /^mm4$|^mm5$|^hg16$|^hg17$|^z/ ) {
    return 1;
  }
  $log->debug( "Illegal genome_build_id: $this->{genome_build_id}" );
  return 0;
}

#+
#
#-
sub _validateStrand {
  my $this = shift;
  return 1;
}

#+
#
#-
sub _validatePositions {
  my $this = shift;
  return 1;
}


#+
#
#-
sub _validateChromosome {
  my $this = shift;
  return 1;
}

#+
#
#-
sub _parseCoordinates {
  my $this = shift;
  $log->debug( "Parsing coordinate string $this->{coordinate_string}" );
  if ( $this->{coordinate_string} =~ /^([^:]+):chr([^:]+):(\d+)-(\d+)([+-\?]*)$/ ) {
    $this->{genome_build_id} = $1;
    $this->{chromosome} = $2;
    $this->{start_pos} = $3;
    $this->{end_pos} = $4;
    $this->{strand} = $5 || '';
    $log->debug( "Parse succeeded, GB: $1, CH: $2, SP: $3, EP: $4 STR: $5" );
  } else {
    $log->debug( "Parse failed" );
    return 0;
  }
  $this->setOrganism();

  my $str;
  foreach( keys( %$this ) ){ $str .= "PARSE: $_ => $this->{$_}\n" }
  $log->debug( $str );
  return 1;
}

#+
#
#-
sub setOrganism {
  my $this = shift;
  # Map organism to genome build.  Assume mm => 6, hg => 2, human is default.
  $this->{organism} = ( $this->{genome_build_id} =~ /^mm/i ) ? 6 :
                      ( $this->{genome_build_id} =~ /^hg/i ) ? 2 : 2;

}

1;
