package SBEAMS::Glycopeptide::DBInterface;

###############################################################################
# Program     : SBEAMS::Glycopeptide::DBInterface
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: DBInterface.pm 3976 2005-09-26 17:25:12Z dcampbel $
#
# Description : This is part of the SBEAMS::Glycopeptide module which handles
#               general communication with the database.
#
###############################################################################

use strict;
use vars qw(@ERRORS);
use CGI::Carp qw( croak);
use DBI;

use SBEAMS::Glycopeptide::Tables;

# Global variables


# Constructor
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}

# Access routines
##################
sub ipi_data_from_accession {
  my $self = shift;
  my %args = @_;
  return unless $args{ipi};
  my $sbeams = $self->getSBEAMS() || return;
  my $sql =<<"  END";
  SELECT * FROM $TBGP_IPI_DATA
  WHERE ipi_accession_number = '$args{ipi}'
  END
  my $row = $sbeams->selectrow_hashref($sql);
  return $row;
}

sub ipi_name_from_accession {
  my $self = shift;
  my %args = @_;
  return unless $args{ipi};
  my $sbeams = $self->getSBEAMS() || return;
  my $sql =<<"  END";
  SELECT protein_name FROM $TBGP_IPI_DATA
  WHERE ipi_accession_number = '$args{ipi}'
  END
  my ($ipi) = $sbeams->selectrow_array($sql) || 0;
  return $ipi;
}

sub ipi_seq_from_accession {
  my $self = shift;
  my %args = @_;
  return unless $args{ipi};
  my $sbeams = $self->getSBEAMS() || return;
  my $sql =<<"  END";
  SELECT protein_sequence FROM $TBGP_IPI_DATA
  WHERE ipi_accession_number = '$args{ipi}'
  END
  my ($seq) = $sbeams->selectrow_array($sql) || 0;
  print STDERR "$seq from $sql\n";
  return $seq;
}

sub lookup_glycosite {
  my $self = shift;
  my %args = @_;
  for my $key ( qw( ipi start ) ) {
    return unless $args{$key};
  }

  my $sbeams = $self->getSBEAMS() || return;
  my ($id) = $sbeams->selectrow_array( <<"  END" ) || 0;
  SELECT glyco_site_id FROM $TBGP_GLYCO_SITE
  WHERE protein_glyco_site_position = $args{start}
  AND ipi_data_id = ( SELECT ipi_data_id FROM $TBGP_IPI_DATA 
                      WHERE ipi_accession = '$args{ipi}' )
  END
  return $id;
}


sub lookup_identified {
  my $self = shift;
  my %args = @_;
  for my $key ( qw( sequence ) ) {
    return unless $args{$key};
  }
  my $sbeams = $self->getSBEAMS() || return;
  my ($id) = $sbeams->selectrow_array( <<"  END" );
  SELECT identified_peptide_id FROM $TBGP_IDENTIFIED_PEPTIDE
  WHERE matching_sequence = '$args{sequence}'
  END

  return $id;
}

sub insert_identified {
  my $self = shift;
  my $row = shift;
  my $heads = shift;

  for my $key ( keys( %$heads ) ) {
    print "$key => $heads->{$key} => $row->[$heads->{$key}]\n";
  }
  exit;
  my $sbeams = $self->getSBEAMS() || return;
}

1;
