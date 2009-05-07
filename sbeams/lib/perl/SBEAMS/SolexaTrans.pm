package SBEAMS::SolexaTrans;

###############################################################################
# Program     : SBEAMS::SolexaTrans
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $$
#
# Description : Perl Module to handle all SBEAMS - SolexaTrans specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use CGI::Carp qw(fatalsToBrowser croak);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Log;

use SBEAMS::SolexaTrans::DBInterface;
use SBEAMS::SolexaTrans::HTMLPrinter;
use SBEAMS::SolexaTrans::TableInfo;
use SBEAMS::SolexaTrans::Settings;
use SBEAMS::SolexaTrans::Tables;

@ISA = qw(SBEAMS::SolexaTrans::DBInterface
          SBEAMS::SolexaTrans::HTMLPrinter
          SBEAMS::SolexaTrans::TableInfo
          SBEAMS::SolexaTrans::Settings);


###############################################################################
# Global Variables
###############################################################################
$VERSION = '0.02';
my $log = SBEAMS::Connection::Log->new();

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


###############################################################################

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

  SELECT project_id, SUM(samples) AS samples FROM
    (
    SELECT project_id, COUNT(*) AS samples
    FROM $TBST_SOLEXA_SAMPLE
    WHERE record_status != 'D'
    GROUP BY project_id
    ) AS temp_table
  WHERE project_id IN ( $projects )
  GROUP BY project_id
  END_SQL

  my @rows = $self->getSBEAMS()->selectSeveralColumns( $sql );
  foreach my $row ( @rows ) {
    my $title = '';
    $title .= "$row->[1] samples" if $row->[1];

    $project_data{$row->[0]} =<<"    END_LINK";
    <A HREF=${CGI_BASE_DIR}/SolexaTrans/main.cgi?set_current_project_id=$row->[0]>
    <DIV id=SolexaTrans_button TITLE='$title'>SolexaTrans</DIV></A>
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
