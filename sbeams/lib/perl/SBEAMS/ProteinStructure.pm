package SBEAMS::ProteinStructure;

###############################################################################
# Program     : SBEAMS::ProteinStructure
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - ProteinStructure specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Log;
use SBEAMS::ProteinStructure::DBInterface;
use SBEAMS::ProteinStructure::HTMLPrinter;
use SBEAMS::ProteinStructure::TableInfo;
use SBEAMS::ProteinStructure::Tables;
use SBEAMS::ProteinStructure::Settings;

@ISA = qw(SBEAMS::ProteinStructure::DBInterface
          SBEAMS::ProteinStructure::HTMLPrinter
          SBEAMS::ProteinStructure::TableInfo
          SBEAMS::ProteinStructure::Settings);

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
  SELECT COUNT(*) AS sets,  project_id 
  FROM $TBPS_BIOSEQUENCE_SET BS
	WHERE project_id IN ( $projects )
  GROUP BY project_id
  END_SQL

  my $cgi_dir = $CGI_BASE_DIR . '/ProteinStructure/';
  my @rows = $self->getSBEAMS()->selectSeveralColumns( $sql );
  foreach my $row ( @rows ) {
    my $title = "$row->[0] Biosequence sets";
    $project_data{$row->[1]} =<<"    END_LINK";
    <A HREF=${cgi_dir}main.cgi?set_current_project_id=$row->[1]>
    <DIV id=Proteinstructure_button TITLE='$title'>
     ProteinStructure
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
