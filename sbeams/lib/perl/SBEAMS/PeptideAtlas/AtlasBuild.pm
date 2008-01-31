package SBEAMS::PeptideAtlas::AtlasBuild;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::AtlasBuild
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::AtlasBuild

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::AtlasBuild

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
atlas build related things.

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;

my $sbeams = SBEAMS::Connection->new();

###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $sbeams = $self->getSBEAMS();
    return($self);
} # end new


###############################################################################
# setSBEAMS: Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
} # end setSBEAMS



###############################################################################
# getSBEAMS: Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS



###############################################################################
# listBuilds -- List all PeptideAtlas builds
###############################################################################
sub listBuilds {
  my $METHOD = 'listBuilds';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $sql = qq~
    SELECT atlas_build_id,atlas_build_name
      FROM $TBAT_ATLAS_BUILD
     WHERE record_status != 'D'
     ORDER BY atlas_build_name
  ~;

  my @atlas_builds = $sbeams->selectSeveralColumns($sql) or
    die("ERROR[$METHOD]: There appear to be no atlas builds in your database");

  foreach my $atlas_build (@atlas_builds) {
    printf("%5d %s\n",$atlas_build->[0],$atlas_build->[1]);
  }

} # end listBuilds


sub getAtlasBuildDirectory {
  my $self = shift;
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} || return;

  my $sql = qq~
  SELECT data_path
  FROM $TBAT_ATLAS_BUILD
  WHERE atlas_build_id = '$atlas_build_id'
  AND record_status != 'D'
  ~;

  my @path = $sbeams->selectOneColumn($sql); 

  ## get the global variable PeptideAtlas_PIPELINE_DIRECTORY
  my $pipeline_dir = $CONFIG_SETTING{PeptideAtlas_PIPELINE_DIRECTORY};

  return "$pipeline_dir/$path[0]";
}



###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Eric W. Deutsch (edeutsch@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
