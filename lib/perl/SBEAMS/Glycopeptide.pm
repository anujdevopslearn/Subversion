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
  return 'hsa';
}


1;

__END__
