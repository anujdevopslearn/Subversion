package SBEAMS::PeptideAtlas::Permissions;

###############################################################################
# Program     : SBEAMS::PeptideAtlas::Permissions
# Author      : Nichole King <nking@systemsbiology.org>
#
# Description : This is part of the SBEAMS::WebInterface module which handles
#               checks user project privileges.  Useful in conjunction
#               with HTMLPrinter to tailor a skin (navbar options) for
#               a project.
###############################################################################

use 5.008;

use strict;

use vars qw(@ERRORS $q @EXPORT @EXPORT_OK);
use CGI::Carp qw(fatalsToBrowser croak);
use Exporter;
our @ISA = qw( Exporter );

use SBEAMS::Connection::Log;
use SBEAMS::Connection::Authenticator qw( $q );
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Connection::Tables;

my $log = SBEAMS::Connection::Log->new();

##our $VERSION = '0.20'; can get this from Settings::get_sbeams_version


# Preloaded methods go here.

###############################################################################
# Constructor
###############################################################################
#sub new 
#{
#    my $this = shift;
#    my $class = ref($this) || $this;
#    my $self = {};
#    bless $self, $class;
#    return($self);
#}


###############################################################################
# Utility routine, checks if current user is 'guest' user.
# FIXME: make id lookup dynamic
###############################################################################
sub isPAGuestUser {

  my $self = shift;

  my $sbeams = $self->getSBEAMS();

  my $currID =  $sbeams->getCurrent_contact_id();

  if ( !defined $currID ) {

      return undef;

  } elsif ( $currID == 107 ) {

      return 1;

  } else {

      return 0;

  }

}


###############################################################################
# Utility routine, checks if current project is yeast development.
# Returns 1 if true, 0 if false.
###############################################################################
sub isYeastPA
{

    my $self = shift ;

    my $sbeams = $self->getSBEAMS();
 
    my %args = @_;

    my $project_id = $args{'project_id'} || $sbeams->getCurrent_project_id();

    if ( !defined $project_id ) 
    {
        return undef;

    } elsif ($project_id == 491 ) 
    {
        return 1;

    } else {

        return 0;
    }

}



###############################################################################
# Utility routine, gets current project id, and checks that it's
# accessible to user.  If yes, returns project id, else returns 0.
###############################################################################
sub getProjectID
{

    my $self = shift ;

    my $sbeams = $self->getSBEAMS();
 
    my %args = @_;

    my $atlas_build_name = $args{'atlas_build_name'} || '';

    my $atlas_build_id = $args{'atlas_build_id'} || '';

    my $sql;

    if ($atlas_build_name)
    {
        $sql = qq~
            SELECT project_id
            FROM $TBAT_ATLAS_BUILD
            WHERE atlas_build_name = '$atlas_build_name'
            ~;
    } elsif ( $atlas_build_id )
    {
        $sql = qq~
            SELECT project_id
            FROM $TBAT_ATLAS_BUILD
            WHERE atlas_build_id = '$atlas_build_id'
            ~;
    }

    my ($project_id) = $sbeams->selectOneColumn($sql) or
      die "\nERROR: Unable to find the project_id"
      . " with $sql\n\n";

    ## check that project is accessible:
    if ( $sbeams->isProjectAccessible( project_id => $project_id ) )
    {

        return $project_id;

    } else
    {

        return 0;

    }

}



###############################################################################
# isProjectAccessible
###############################################################################
#sub isProjectAccessible{
#  my $self = shift || croak("parameter self not passed");
#  my %args = @_;
#
#  ## Decode Arguments
#  my $project_id = $args{'project_id'} || $self->getCurrent_project_id();
#
#  my @accessible_projects = $self->getAccessibleProjects();
#  foreach my $id (@accessible_projects) {
#        if ($id == $project_id) {
#          return 1;
#        }
#  }
#  return 0;
#}


sub prntVar
{

  my ($str, $val) = @_;

  print "$str = $val\n";

}
1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Permissions - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Permissions;
  blah blah blah

=head1 ABSTRACT

  This should be the abstract for Permissions.
  The abstract is used when making PPD (Perl Package Description) files.
  If you don't want an ABSTRACT you should also edit Makefile.PL to
  remove the ABSTRACT_FROM option.

=head1 DESCRIPTION

Stub documentation for Permissions, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Nichole King, E<lt>nking@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Nichole King

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
