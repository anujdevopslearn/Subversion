package SBEAMS::Inkjet;

###############################################################################
# Program     : SBEAMS::Inkjet
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Perl Module to handle all SBEAMS-MicroArray specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Log;
use SBEAMS::Inkjet::DBInterface;
use SBEAMS::Inkjet::HTMLPrinter;
use SBEAMS::Inkjet::TableInfo;
use SBEAMS::Inkjet::Tables;
use SBEAMS::Inkjet::Settings;

@ISA = qw(SBEAMS::Inkjet::DBInterface
          SBEAMS::Inkjet::HTMLPrinter
          SBEAMS::Inkjet::TableInfo
          SBEAMS::Inkjet::Settings);

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
  SELECT project_id, COUNT(*) AS two_color
  FROM $TBIJ_ARRAY
  WHERE project_id IN ( $projects )
  GROUP BY project_id
  END_SQL

  my $cgi_dir = $CGI_BASE_DIR . '/Inkjet/';
  my @rows = $self->getSBEAMS()->selectSeveralColumns( $sql );
  foreach my $row ( @rows ) {
    my $title = '';
    $title .= "$row->[1] two-color arrays";
    $project_data{$row->[0]} =<<"    END_LINK";
    <A HREF=${cgi_dir}ProjectHome.cgi?set_current_project_id=$row->[0]>
    <DIV id=Inkjet_button TITLE='$title'>Inkjet</DIV></A>
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
