package SBEAMS::Interactions;

###############################################################################
# Program     : SBEAMS::Interactions
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Interactions specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Log;
use SBEAMS::Interactions::DBInterface;
use SBEAMS::Interactions::HTMLPrinter;
use SBEAMS::Interactions::TableInfo;
use SBEAMS::Interactions::Tables;
use SBEAMS::Interactions::Settings;

@ISA = qw(SBEAMS::Interactions::DBInterface
          SBEAMS::Interactions::HTMLPrinter
          SBEAMS::Interactions::TableInfo
          SBEAMS::Interactions::Settings);

my $log = SBEAMS::Connection::Log->new();

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
  SELECT project_id, COUNT(DISTINCT g.interaction_group_id) AS isets, 
         COUNT( i.interaction_id ) AS interactions
  FROM $TBIN_INTERACTION i RIGHT OUTER JOIN $TBIN_INTERACTION_GROUP g
  ON g.interaction_group_id = i.interaction_group_id
  GROUP BY project_id
  END_SQL

  my $cgi_dir = $CGI_BASE_DIR . '/Interactions/';
  my @rows = $self->getSBEAMS()->selectSeveralColumns( $sql );
  foreach my $row ( @rows ) {
    my $title = "$row->[2] Interactions in $row->[1] interaction groups";
    $project_data{$row->[0]} =<<"    END_LINK";
    <A HREF=${cgi_dir}main.cgi?set_current_project_id=$row->[0]>
    <DIV id=Interactions_button TITLE='$title'>
     Interactions
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
