package SBEAMS::Cytometry;

###############################################################################
# Program     : SBEAMS::Cytometry
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Cytometry specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw( $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Cytometry::DBInterface;
use SBEAMS::Cytometry::HTMLPrinter;
use SBEAMS::Cytometry::TableInfo;
use SBEAMS::Cytometry::Tables;
use SBEAMS::Cytometry::Settings;

@ISA = qw(SBEAMS::Cytometry::DBInterface
          SBEAMS::Cytometry::HTMLPrinter
          SBEAMS::Cytometry::TableInfo
          SBEAMS::Cytometry::Settings);


###############################################################################
# Global Variables
###############################################################################
$VERSION = '0.02';


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


###############################################################################
# Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
}


###############################################################################
# Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return($sbeams);
}

sub getProjectData {
  my $self = shift;
  my %args = @_;
  my %project_data;

  unless ( scalar(@{$args{projects}}) ) {
    $log->warn( 'No project list provided to getProjectData' );
    return ( \%project_data);
  }
 
  my $projects = join ',', @{$args{projects}};

  # SQL to determine which projects have data.
  my $sql =<<"  END_SQL";
  SELECT project_id, COUNT(*) AS total FROM $TBCY_FCS_RUN
  WHERE project_id IN ( $projects )
  GROUP BY project_id
  END_SQL

#  my $cgi_dir = "${CGI_BASE_DIR}/${subdir}/";
  my $cgi_dir = $CGI_BASE_DIR . '/Cytometry/';
  my @rows = $self->getSBEAMS()->selectSeveralColumns( $sql );
  foreach my $row ( @rows ) {
    my $title = "$row->[1] Flow sorts in project";
    $project_data{$row->[0]} =<<"    END_LINK";
    <A HREF=${cgi_dir}main.cgi?set_current_project_id=$row->[0]>
    <DIV id=Cytometry_button TITLE='$title'>
    Cytometry 
    </DIV></A>
    END_LINK
  }
  return ( \%project_data );
}


###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################
#
