package SBEAMS::PeptideAtlas;

###############################################################################
# Program     : SBEAMS::PeptideAtlas
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - PeptideAtlas specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Log;
use SBEAMS::PeptideAtlas::DBInterface;
use SBEAMS::PeptideAtlas::HTMLPrinter;
use SBEAMS::PeptideAtlas::TableInfo;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Permissions;
use SBEAMS::PeptideAtlas::HTMLTabs;
use SBEAMS::PeptideAtlas::ModificationHelper;

@ISA = qw(SBEAMS::PeptideAtlas::DBInterface
          SBEAMS::PeptideAtlas::HTMLPrinter
          SBEAMS::PeptideAtlas::TableInfo
          SBEAMS::PeptideAtlas::Settings
          SBEAMS::PeptideAtlas::Permissions
          SBEAMS::PeptideAtlas::HTMLTabs
          SBEAMS::PeptideAtlas::ModificationHelper
       );

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
  SELECT project_id, COUNT(*) AS builds 
  FROM $TBAT_ATLAS_BUILD
  WHERE project_id IN ( $projects )
  AND record_status != 'D'
  GROUP BY project_id
  END_SQL

  my $cgi_dir = $CGI_BASE_DIR . '/PeptideAtlas/';
  my @rows = $self->getSBEAMS()->selectSeveralColumns( $sql );
  foreach my $row ( @rows ) {
    my $title = '';
    $title .= "$row->[1] Atlas Builds";
    $project_data{$row->[0]} =<<"    END_LINK";
    <A HREF=${cgi_dir}main.cgi?set_current_project_id=$row->[0]>
    <DIV id=PeptideAtlas_button TITLE='$title'>PeptideAtlas</DIV></A>
    END_LINK
  }
  return ( \%project_data );
}

sub has_search_key_data {
  my $self = shift;
  my %args = @_;
  my $build_id = $args{build_id} || 
                 $self->getCurrentAtlasBuildID( parameters_ref => $args{parameters_ref} );
  my ( $cnt ) = $self->getSBEAMS()->selectrow_array( <<"  END" );
  SELECT COUNT(*) FROM $TBAT_SEARCH_KEY WHERE atlas_build_id = $build_id
  END
  return $cnt;
}

###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################
