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

    my $sql='';

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

    if ($sql) {
        my ($project_id) = $sbeams->selectOneColumn($sql) ||
          $sbeams->reportException( message => "Unable to find the project_id with SQL:\n $sql" ,
                                      state => 'ERROR',
                                      type => 'BAD CONSTRAINT',
					
					);

        ## check that project is accessible:
        if ( $sbeams->isProjectAccessible( project_id => $project_id ) )
        {

            return $project_id;

        } else
        {

            return 0;

        }

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



###############################################################################
# prntVar
###############################################################################
sub prntVar
{

  my ($str, $val) = @_;

  print "$str = $val\n";

}



###############################################################################
# getCurrentAtlasBuildID
###############################################################################
sub getCurrentAtlasBuildID {
  my $METHOD_NAME = 'getCurrentAtlasBuildID';
  my $self = shift || die("ERROR[$METHOD_NAME]: parameter self not passed");
  my %args = @_;

  #### Decode the argument list
  my $parameters_ref = $args{'parameters_ref'}
   || die "ERROR[$METHOD_NAME]: parameters_ref not passed";
  my %parameters = %{$parameters_ref};
  my $sbeams = $self->getSBEAMS();


  #### Extract what was specified as a parameter
  my $atlas_build_id = $parameters{'atlas_build_id'};
  my $atlas_build_name = $parameters{'atlas_build_name'};
  my $organism_id = $parameters{'organism_id'};


  #### If atlas_build_id was supplied
  if ($atlas_build_id) {
    #### we're fine, this is exactly what we want

  #### Else if atlas_build_name was supplied
  } elsif ($atlas_build_name) {

    #### Build atlas_build_name constraint
    my $atlas_build_name_clause = $sbeams->parseConstraint2SQL(
      constraint_column=>"atlas_build_name",
      constraint_type=>"plain_text",
      constraint_name=>"Atlas Build Name",
      constraint_value=>$parameters{atlas_build_name} );
    return if ($atlas_build_name_clause eq '-1');

    #### Fetch the id based on the name
    my $sql = qq~
      SELECT atlas_build_id
        FROM $TBAT_ATLAS_BUILD
       WHERE 1=1
         $atlas_build_name_clause
         AND record_status != 'D'
    ~;
    my @rows = $sbeams->selectOneColumn($sql);


    #### Check that we got only one result or squawk
    if (scalar(@rows) == 0) {
      print "ERROR[$METHOD_NAME]: No atlas_build_id's found for ".
	"'$atlas_build_name'<BR>\n";
      return(-1);

    } elsif (scalar(@rows) > 1) {
      print "ERROR[$METHOD_NAME]: Too many atlas_build_id's found for ".
	"'$atlas_build_name'<BR>\n";
      return(-1);

    } else {
      $atlas_build_id = $rows[0];
    }
    print "atlas build is $atlas_build_id\n";

  #### Else if organism_id was supplied
  } elsif ($organism_id) {

    #### Build organism_id constraint
    my $organism_id_clause = $sbeams->parseConstraint2SQL(
      constraint_column=>"organism_id",
      constraint_type=>"int",
      constraint_name=>"Organism ID",
      constraint_value=>$parameters{organism_id} );
    return if ($organism_id_clause eq '-1');

    #### Build organism_specialized_build constraint
    my $organism_specialized_build_clause = $sbeams->parseConstraint2SQL(
      constraint_column=>"organism_specialized_build",
      constraint_type=>"plain_text",
      constraint_name=>"Organism Specialized Build",
      constraint_value=>'NULL' );
    return if ($organism_specialized_build_clause eq '-1');

    my $organism_specialized_build_clause = 
      'AND organism_specialized_build IS NULL ';

    #### Fetch the id based on the name
    my $sql = qq~
      SELECT atlas_build_id
        FROM $TBAT_DEFAULT_ATLAS_BUILD
       WHERE 1=1
         $organism_id_clause
         $organism_specialized_build_clause
         AND record_status != 'D'
    ~;
    print ($sql);
    my @rows = $sbeams->selectOneColumn($sql);


    #### Check that we got exactly one result or squawk
    #### If we got multiple results, use the first one.
    if (scalar(@rows) == 0) {
      print "ERROR[$METHOD_NAME]: No non-specialized default atlas builds found for organism ID ".
	"'$organism_id'<BR>\n";
      return(-1);
    } elsif (scalar(@rows) > 1) {
      print "ERROR[$METHOD_NAME]: Multiple non-specialized default atlas builds found for organism ID ".
	"'$organism_id'<BR>\n";
      return(-1);

    } else {
      $atlas_build_id = $rows[0];
    }
    print "atlas build is $atlas_build_id\n";

  #### Otherwise try to get it from the session cookie
  } else {
    $atlas_build_id = $sbeams->getSessionAttribute(
      key => 'PeptideAtlas_atlas_build_id',
    );

  }

  #### If we still don't have an atlas_build_id, guess!
  unless ($atlas_build_id) {
    my $organism_name = $sbeams->getSessionAttribute(
      key => 'PeptideAtlas_organism_name',
    );

    my $default_atlas_build_name_clause;
    if ($organism_name) {
      $default_atlas_build_name_clause =
        "  AND O.organism_name = '$organism_name'\n";
    } else {
      $default_atlas_build_name_clause =
        "  AND O.organism_name IS NULL\n";
    }

    my $sql = qq~
        SELECT atlas_build_id
          FROM $TBAT_DEFAULT_ATLAS_BUILD DAB
          LEFT JOIN $TB_ORGANISM O
               ON ( DAB.organism_id = O.organism_id AND O.record_status != 'D')
         WHERE 1=1
           $default_atlas_build_name_clause
           AND DAB.record_status != 'D'
    ~;
    my @rows = $sbeams->selectOneColumn($sql);

    if (scalar(@rows) > 1) {
      die("ERROR: Too may rows returned for $sql");
    } elsif ( @rows ) {
      $atlas_build_id = $rows[0];
    }

  }


  #### If we still don't have an atlas_build_id, just assume id 1!
  unless ($atlas_build_id) {
    $atlas_build_id = 1;
  }

  #### Verify that the user is allowed to see this atlas_build_id
  my @accessible_project_ids = $sbeams->getAccessibleProjects();
  my $accessible_project_ids = join( ",", @accessible_project_ids ) || '0';
  my $sql = qq~
      SELECT atlas_build_id
        FROM $TBAT_ATLAS_BUILD AB
       WHERE AB.project_id IN ( $accessible_project_ids )
         AND AB.record_status!='D'
         AND atlas_build_id = '$atlas_build_id'
  ~;
  my @rows = $sbeams->selectOneColumn($sql);

  #### If not, stop here
  unless (scalar(@rows) == 1 && $rows[0] eq $atlas_build_id) {

    my $reset_link = "$CGI_BASE_DIR/PeptideAtlas/main.cgi?tab=1;reset_id=true";
    my $current_username = $sbeams->getCurrent_username();

    my $LOGIN_URI = "$SERVER_BASE_DIR$ENV{REQUEST_URI}";
    if ($LOGIN_URI =~ /\?/) {
      $LOGIN_URI .= "&force_login=yes";
    } else {
      $LOGIN_URI .= "?force_login=yes";
    }

    print qq~
      <BR>Sorry, you are not permitted to access atlas_build_id
      '$atlas_build_id' with your current credentials as
      user '$current_username'.<BR><BR>
      - <A HREF="$LOGIN_URI">LOGIN</A> as a different user.<BR><BR>
      - <A HREF="$reset_link">SELECT</A> a different atlas build to explore<BR>
    ~;
    return(-1);
  }


  #### Test if the current session already has this atlas_build_id, and if
  #### not, then set it
  if( $args{no_cache} ) {
    $log->info( "Skipping storage due to no_cache directive" );
  } else {
    my $cached_atlas_build_id = $sbeams->getSessionAttribute(
      key => 'PeptideAtlas_atlas_build_id',
    );

    if ($cached_atlas_build_id != $atlas_build_id) {
      $sbeams->setSessionAttribute(
        key => 'PeptideAtlas_atlas_build_id',
        value => $atlas_build_id,
      );
    }
  }

  return($atlas_build_id);

} # end getCurrentAtlasBuildID

sub clearBuildSettings {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  $sbeams->deleteSessionAttribute(
    key => 'PeptideAtlas_atlas_build_id',
  );
  $sbeams->deleteSessionAttribute(
    key => 'PeptideAtlas_atlas_name',
  );

  $sbeams->deleteSessionAttribute(
      key => 'PeptideAtlas_organism_name',
  );
}


sub setBuildSessionAttributes {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my %args = @_;
  return '' if !$args{build_id};
  my ( $name ) = $sbeams->selectrow_array( <<"  END" );
  SELECT atlas_build_name
    FROM $TBAT_ATLAS_BUILD
   WHERE atlas_build_id = $args{build_id}
     AND record_status!='D'
  END
  $sbeams->setSessionAttribute(
    key => 'PeptideAtlas_atlas_build_id',
    value => $args{build_id},
  );
  $sbeams->setSessionAttribute(
    key => 'PeptideAtlas_atlas_name',
    value => $name,
  );
}

sub isAccessibleBuild {
  my $self = shift;
  my %args = @_;
  return '' if !$args{build_id};

  my @builds = $self->getAccessibleBuilds();
  return ( grep /^$args{build_id}$/, @builds );
}
  
sub getAccessibleBuilds {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my $projects = join( ', ', $sbeams->getAccessibleProjects() );
  return $sbeams->selectOneColumn( <<"  END" );
  SELECT atlas_build_id
    FROM $TBAT_ATLAS_BUILD
   WHERE project_id IN ( $projects )
     AND record_status!='D'
   ORDER BY atlas_build_name
  END
}

sub getCurrentAtlasOrganism {
  my $self = shift();
  my %args = @_;

  my $params = $args{'parameters_ref'} || die "parameters_ref not passed";
  my $sbeams = $self->getSBEAMS();

  my $build_id = $params->{atlas_build_id} || 
                 $self->getCurrentAtlasBuildID(%args);
  
  my $sql = qq~
  SELECT organism_name, O.organism_id
  FROM $TBAT_BIOSEQUENCE_SET BSS
  LEFT JOIN $TB_ORGANISM O
    ON ( BSS.organism_id = O.organism_id )
  WHERE BSS.biosequence_set_id IN (
  SELECT DISTINCT B.biosequence_set_id FROM
  $TBAT_ATLAS_BUILD AB
  LEFT JOIN $TBAT_BIOSEQUENCE B
    ON ( AB.biosequence_set_id = B.biosequence_set_id )
  WHERE 1=1
  AND atlas_build_id = $build_id 
  AND AB.record_status != 'D'
  AND B.record_status != 'D'
  )
  AND O.record_status != 'D' 
  AND BSS.record_status != 'D'  
  ~;

  my @rows = $sbeams->selectrow_array($sql);
  die "Couldn't find specified organism: $sql" if !scalar(@rows);

  if ( $args{type} && $args{type} eq 'kegg' ) {
    return  ( $rows[0] =~ /Human/ ) ? 'hsa' :
            ( $rows[0] =~ /Yeast/ ) ? 'sce' :
            ( $rows[0] =~ /Mouse/ ) ? 'mmu' :
            ( $rows[0] =~ /Drosophila/ ) ? 'dme' : $rows[0];
  } elsif  ( $args{type} && $args{type} eq 'organism_id' ) {
    return $rows[1];
  } else {
    return $rows[0];
  }
}


###############################################################################
1;
__END__
###############################################################################
###############################################################################
###############################################################################


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

Copyright 2005 by Institute for Systems Biology	 

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
