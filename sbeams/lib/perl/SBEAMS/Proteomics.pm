package SBEAMS::Proteomics;

###############################################################################
# Program     : SBEAMS::Proteomics
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - Proteomics specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams );
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Proteomics::DBInterface;
use SBEAMS::Proteomics::HTMLPrinter;
use SBEAMS::Proteomics::TableInfo;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Log;
use SBEAMS::Proteomics::Utilities;
use SBEAMS::Proteomics::Settings;

@ISA = qw(SBEAMS::Proteomics::DBInterface
          SBEAMS::Proteomics::HTMLPrinter
          SBEAMS::Proteomics::TableInfo
          SBEAMS::Proteomics::Settings
          SBEAMS::Proteomics::Utilities
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

#  my $subdir = $SBEAMS::Proteomics::Settings::SBEAMS_SUBDIR;
  unless ( scalar(@{$args{projects}}) ) {
    $log->warn( 'No project list provided to getProjectData' );
    return ( \%project_data);
  }
 
  my $projects = join ',', @{$args{projects}};

  # SQL to determine which projects have data.
  my $sql =<<"  END_SQL";
  SELECT COUNT(fraction_id) runs, COUNT(DISTINCT PE.experiment_id) exps , project_id 
  FROM $TBPR_PROTEOMICS_EXPERIMENT PE LEFT OUTER JOIN $TBPR_FRACTION F
    ON F.experiment_id = PE.experiment_id
	WHERE project_id IN ( $projects )
  GROUP BY project_id
  END_SQL

#  my $cgi_dir = "${CGI_BASE_DIR}/${subdir}/";
  my $cgi_dir = $CGI_BASE_DIR . '/Proteomics/';
  my @rows = $self->getSBEAMS()->selectSeveralColumns( $sql );
  foreach my $row ( @rows ) {
    my $title = "$row->[0] MS runs in $row->[1] experiments";
    $project_data{$row->[2]} =<<"    END_LINK";
    <A HREF=${cgi_dir}main.cgi?set_current_project_id=$row->[2]>
    <DIV id=Proteomics_button TITLE='$title'>
     Proteomics
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
