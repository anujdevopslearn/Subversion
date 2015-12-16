package SBEAMS::PeptideAtlas::DIALibrary;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::DIALibrary
# Author      : David Campbell <david.campbell@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::DIALibrary

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::DIALibrary

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
things related to PeptideAtlas Data Independent Analysis (SWATH)
libraries 

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $VERBOSE $TESTONLY $sbeams);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;
use Compress::Zlib;
use Data::Dumper;
use JSON;


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
    $sbeams = SBEAMS::Connection->new();
    return($self);
} # end new


###############################################################################
# setSBEAMS: Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    my $sb = $sbeams;
    $sbeams = $sb if $sb;
    return $sbeams;
} # end setSBEAMS



###############################################################################
# getSBEAMS: Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams;
} # end getSBEAMS

sub get_organism_select {
  my $self = shift;
  my %args = @_;
  my @projects = $sbeams->getAccessibleProjects();
  my $projects = join( ',', @projects);
  my $select = '';
  if ( $args{onchange} ) {
    $select = "<SELECT NAME=organism_id ID=organism_id onchange=$args{onchange}>\n";
  } else {
    $select = "<SELECT NAME=organism_id ID=organism_id>\n";
  }
  $select .= "<OPTION VALUE=''></OPTION>\n";

  my $sql = qq~
  SELECT DISTINCT
  DLS.organism_id, organism_name
  FROM $TBAT_DIA_LIBRARY_SET DLS 
  JOIN $TB_ORGANISM O
    ON O.organism_id = DLS.organism_id
  JOIN $TBAT_DIA_LIBRARY DL
    ON DL.dia_library_set_id = DLS.dia_library_set_id
  WHERE project_id IN ( $projects )
  ORDER BY organism_name
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  my @as_array;
  while ( my @row = $sth->fetchrow_array() ) {
    $select .= "<OPTION VALUE=$row[0]>$row[1] </OPTION>\n";
    push @as_array, { optionValue => $row[1], optionText => $row[0] };
  }
  $select .= "</SELECT>\n";
  return ( $args{as_array} ) ? \@as_array : $select;
}

sub get_library_select {
  my $self = shift;
  my %args = @_;
  my @projects = $sbeams->getAccessibleProjects();
  my $projects = join( ',', @projects);
  my $select = '';
  if ( $args{onchange} ) {
    $select = "<SELECT NAME=library_set_id ID=library_set_id size=4 onchange=$args{onchange}>\n";
  } else {
    $select = "<SELECT NAME=library_set_id size=4 ID=library_set_id>\n";
  }

  my $org_clause = '';
  if ( $args{organism_id} ) {
    $org_clause = "AND DLS.organism_id = $args{organism_id}\n";
  }

  my $sql = qq~
  SELECT DISTINCT
  DLS.dia_library_set_id, set_tag
  FROM $TBAT_DIA_LIBRARY_SET DLS 
  JOIN $TBAT_DIA_LIBRARY DL
    ON DL.dia_library_set_id = DLS.dia_library_set_id
  WHERE project_id IN ( $projects )
  $org_clause
  ORDER BY set_tag
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  my @as_array;
  while ( my @row = $sth->fetchrow_array() ) {
    $select .= "<OPTION VALUE=$row[0]>$row[1] </OPTION>\n";
    push @as_array, { optionValue => $row[0], optionText => $row[1] };
  }
  $select .= "</SELECT>\n";
  return ( $args{as_array} ) ? \@as_array : $select;
}


sub get_format_select {
  my $self = shift;
  my %args = @_;
  my $select = '';
  if ( $args{onchange} ) {
    $select = "<SELECT NAME=output_format ID=output_format onchange=$args{onchange}>\n";
  } else {
    $select = "<SELECT NAME=output_format ID=output_format>\n";
  }

  my $sql = qq~
  SELECT DISTINCT
  file_format
  FROM $TBAT_DIA_LIBRARY 
  ORDER BY file_format
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  my @as_array;
  while ( my @row = $sth->fetchrow_array() ) {
    my $txt = ucfirst($row[0]);

    $select .= "<OPTION VALUE=$row[0]>$txt </OPTION>\n";
    push @as_array, { optionValue => $row[0], optionText => $txt };
  }
  $select .= "</SELECT>\n";
  return ( $args{as_array} ) ? \@as_array : $select;
}



1;

__END__
