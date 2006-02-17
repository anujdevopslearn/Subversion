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
  my $seq = $sbeams->selectrow_array($sql);
  $seq ||= 0;
  return $seq;
}

sub lookup_glycosite {
  my $self = shift;
  my %args = @_;
  for my $key ( qw( ipi start ) ) {
    return unless $args{$key};
  }

  my $sbeams = $self->getSBEAMS() || return;
  my ($id) = $sbeams->selectrow_array( <<"  END" );
  SELECT glyco_site_id FROM $TBGP_GLYCO_SITE
  WHERE protein_glyco_site_position = $args{start}
  AND ipi_data_id = ( SELECT ipi_data_id FROM $TBGP_IPI_DATA 
                      WHERE ipi_accession_number = '$args{ipi}' )
  END
  my $sql = " SELECT glyco_site_id FROM $TBGP_GLYCO_SITE WHERE protein_glyco_site_position = $args{start} AND ipi_data_id = ( SELECT ipi_data_id FROM $TBGP_IPI_DATA WHERE ipi_accession_number = '$args{ipi}' )";
#  die $sql unless $id;
  return $id;
}


sub lookup_identified_to_ipi {
  my $self = shift;
  my %args = @_;
  for my $key ( qw( identified_id glyco_site_id ) ) {
    return unless $args{$key};
  }
  my $sbeams = $self->getSBEAMS() || return;
  my ($id) = $sbeams->selectrow_array( <<"  END" );
  SELECT identified_peptide_id FROM $TBGP_IDENTIFIED_TO_IPI
  WHERE identified_peptide_id = $args{identified_peptide_id}
  AND glyco_site_id = $args{glyco_site_id}
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

sub annotateAsn {
  my $self = shift;
  my $seq = shift;
  $seq =~ s/(N)(.[S|T])/$1#$2/;
  return $seq;
}

sub countTrypticEnds {
  my $self = shift;
  my $seq = shift || return;
  my $cnt = 0;
  # Does sequence start with -, R, or K
  $cnt++ if $seq =~ /^[-|R|K].*$/;

  if ( $seq =~ /.*-$/ ) { # Does sequence end with -?
    $cnt++ 
  } elsif ( $seq =~ /.*[R|K]\..$/ ) { # Does observed sequence end with R or K?
    $cnt++ 
  }
#  print STDERR "Sequence $seq has $cnt tryptic ends, yo!\n";
  return $cnt;

}

sub insertIdentified {
  my $self = shift;
  my $row = shift;
  my $heads = shift;
  
  my @cols = qw( identified_peptide_sequence
                 peptide_prophet_score
                 peptide_mass
                 glyco_site_id
                 matching_sequence
                 tryptic_end
                );

  my %rowdata;
  for my $col ( @cols ) {
    $rowdata{$col} = $row->[$heads->{$col}];
#  print STDERR "Missing $col in insID, $rowdata{$col}\n";
  }
  my $sbeams = $self->getSBEAMS();
  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                    return_PK => 1,
                                   table_name => $TBGP_IDENTIFIED_PEPTIDE,
                                  rowdata_ref => \%rowdata );
  return $id;
}

sub insertIdentifiedToIPI {
  my $self = shift;
  my $row = shift;
  my $heads = shift;
  
  my @cols = qw( ipi_data_id
                 identified_peptide_id 
                 glyco_site_id
                 identified_start
                 identified_stop
                );

  my %rowdata;
  for my $col ( @cols ) {
    $rowdata{$col} = $row->[$heads->{$col}];
  print STDERR "Missing $col in insId2ipi, $rowdata{$col}\n";
 #   print STDERR "Missing $col in inId2ipi\n"; # unless $rowdata{$col};
  }
  my $sbeams = $self->getSBEAMS();
  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                    return_PK => 1,
                                   table_name => $TBGP_IDENTIFIED_TO_IPI,
                                  rowdata_ref => \%rowdata );
   return $id;
}

sub insertPeptideToTissue {
  my $self = shift;
  my $row = shift;
  my @row = @$row;
  my $heads = shift;

  my $sbeams = $self->getSBEAMS();
  my ( $sample_id ) = $sbeams->selectrow_array( <<"  END" );
  SELECT sample_id FROM $TBGP_GLYCO_SAMPLE
  WHERE sample_name = '$row->[$heads->{sample}]'
  END
  push @row, $sample_id;
  $heads->{sample_id} =  $#row;
  
  my @cols = qw( sample_id 
                 identified_peptide_id 
                );

  my %rowdata;
  for my $col ( @cols ) {
    $rowdata{$col} = $row[$heads->{$col}];
    print STDERR "Missing $col in pep2tiss\n" unless $rowdata{$col};
  }
  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                    return_PK => 1,
                                   table_name => $TBGP_PEPTIDE_TO_TISSUE,
                                  rowdata_ref => \%rowdata );
   return $id;
}

1;
