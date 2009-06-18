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
use SBEAMS::PeptideAtlas::Utilities;
use SBEAMS::PeptideAtlas::AtlasBuild;
use SBEAMS::PeptideAtlas::SearchBatch;
use SBEAMS::PeptideAtlas::Peptide;
use SBEAMS::PeptideAtlas::Annotations;
use SBEAMS::PeptideAtlas::ProtInfo;

@ISA = qw(SBEAMS::PeptideAtlas::DBInterface
          SBEAMS::PeptideAtlas::HTMLPrinter
          SBEAMS::PeptideAtlas::TableInfo
          SBEAMS::PeptideAtlas::Settings
          SBEAMS::PeptideAtlas::Permissions
          SBEAMS::PeptideAtlas::HTMLTabs
          SBEAMS::PeptideAtlas::ModificationHelper
          SBEAMS::PeptideAtlas::Utilities
          SBEAMS::PeptideAtlas::AtlasBuild
          SBEAMS::PeptideAtlas::SearchBatch
          SBEAMS::PeptideAtlas::Peptide
          SBEAMS::PeptideAtlas::Annotations
          SBEAMS::PeptideAtlas::ProtInfo
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

sub getBuildMotif {
  my $self = shift;
  my %args = @_;

  my $build_id = $args{build_id} || $self->getCurrentAtlasBuildID( parameters_ref => { got => 0 } );
  if ( grep /^$build_id$/, @{$self->getGlycoBuilds()} ) {
    return 'glyco';
  } elsif ( grep /^$build_id$/, @{$self->getPhosphoBuilds()} ) {
    return 'phospho';
  } elsif ( grep /^$build_id$/, @{$self->getICATBuilds()} ) {
    return 'icat';
  } 
  return '';
}

# Stub methods with hard-coded build IDs, replace with db lookup based method
sub getBuildConsensusLib {
  my $self = shift;
  my %args = @_;

  # getCurrent wants a param ref
  my $build_id = $args{build_id} || $self->getCurrentAtlasBuildID( parameters_ref => { got => 0 } );
	my @human = ( 98, 107, 108, 113, 115, 119, 134 );
	my @mouse = ( 109, 117, 120, 135 );

	my $lib_id = '';

  # FIXME - hard-coded value for MRM Atlas
  if ( $build_id == 123 ) {
    $lib_id = 12;
  } elsif ( $build_id == 110 ) {
		$lib_id = 5;
	} elsif ( grep /^$build_id$/, @human ) {
		$lib_id = 9;
	} elsif ( grep /^$build_id$/, @mouse ) {
		$lib_id = 7;
  } elsif ( $build_id == 40 ) {
		$lib_id = 2;
	}
	$log->debug( "Lib ID $lib_id for buildish $build_id" );
	return $lib_id;
}

sub getGlycoBuilds {
  my @glyco_builds = ( 115, 120, 149, 156, 175, 177 );
  return \@glyco_builds;
}

sub getPhosphoBuilds {
  my @phospho_builds = ( );
  return \@phospho_builds;
}

sub getICATBuilds {
  my @icat_builds = ( 83, 110 );
  return \@icat_builds;
}

###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################
