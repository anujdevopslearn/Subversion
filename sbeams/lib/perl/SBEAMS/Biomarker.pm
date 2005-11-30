package SBEAMS::Biomarker;

###############################################################################
# Program     : SBEAMS::Biomarker
# $Id$
#
# Description : Perl Module to handle Biomarker specific items.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA $sbeams);
use SBEAMS::Connection qw($log);

use SBEAMS::Biomarker::DBInterface;
use SBEAMS::Biomarker::HTMLPrinter;
use SBEAMS::Biomarker::TableInfo;
use SBEAMS::Biomarker::Tables;
use SBEAMS::Biomarker::Settings;

@ISA = qw(SBEAMS::Biomarker::DBInterface
          SBEAMS::Biomarker::HTMLPrinter
          SBEAMS::Biomarker::TableInfo
          SBEAMS::Biomarker::Settings);

#+
# Constructor
#-
sub new {
    my $class = shift;
    my $this = { @_ };
    bless $this, $class;
    return($this);
}

#+
# Routine to cache sbeams object
#-
sub setSBEAMS {
  my $self = shift;
  $self->set_sbeams( @_ );
}


#+
# Routine to return cached sbeams object
#-
sub getSBEAMS {
  my $self = shift;
  return $self->get_sbeams();
}

#+
#+
# Routine to cache sbeams object
#-
sub set_sbeams {
  my $self = shift;
  $sbeams = shift || die "Must pass sbeams object";
  $self->{_sbeams} = $sbeams;
}


#+
# Routine to return cached sbeams object
#-
sub get_sbeams {
  my $self = shift;
  return $self->{_sbeams} || new SBEAMS::Connection;
}

#+
# Routine to check existence and writability of an experiment
# argument  experiment name (req) 
# returns   boolean, whether expt exists and project is writable
#-
sub checkExperiment {
  my $this = shift;
  my $expt = shift || die 'Missing required experiment parameter';

  my $sbeams = $this->get_sbeams();

  my $sql =<<"  END";
  SELECT experiment_id, project_id
  FROM $TBBM_EXPERIMENT
  WHERE experiment_tag = '$expt'
  END

  $sql = $sbeams->evalSQL( $sql );
  my @row = $sbeams->selectrow_array( $sql );

  # project doesn't exist, test fails
  return undef unless $row[0];

  # Is user authorized to write this project?
  return $sbeams->isProjectWritable( project_id => $row[1] );

}


#+
#-
sub get_experiment_name {
  my $this = shift;
  my $expt_id = shift || die 'Missing required experiment parameter';

  my $sbeams = $this->get_sbeams();

  my $sql =<<"  END";
  SELECT experiment_name
  FROM $TBBM_EXPERIMENT
  WHERE experiment_id = $expt_id
  END

  my @row = $sbeams->selectrow_array( $sql );

  return $row[0];
}


#+
#-
sub get_treatment_type {
  my $this = shift;
  my $ttype_id = shift || die 'Missing parameter treatment_type_id';

  my $sbeams = $this->get_sbeams();

  my $sql =<<"  END";
  SELECT treatment_type_name
  FROM $TBBM_TREATMENT_TYPE
  WHERE treatment_type_id = $ttype_id
  END

  my ( $id ) = $sbeams->selectrow_array( $sql );
  $log->debug("ID: $id, SQL: $sql\n");

  return $id;
}

#+ 
# inserts treatment record into database
#-
sub insert_treatment {
  my $this = shift;
  my %args = @_;
  
  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                    return_PK => 1,
                                   table_name => $TBBM_TREATMENT,
                                  rowdata_ref => $args{data_ref},
                         add_audit_parameters => 1
                                     );
  $log->info( "ID is $id\n" );
  return $id;
}

#+ 
# inserts treatment record into database
#-
sub insert_lcms_run {
  my $this = shift;
  my %args = @_;
  return undef unless $args{data_ref};
  
  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                    return_PK => 1,
                                   table_name => $TBBM_MS_RUN,
                                  rowdata_ref => $args{data_ref},
                         add_audit_parameters => 1
                                     );
  $log->info( "New lcms run ID is $id\n" );
  return $id;
}


#+
# Method for creating biogroup records.
# narg data_ref   Reference to array of record hashrefs
#-
sub create_biogroup {
  my $this = shift;
  my %args = @_;

  my $name = $args{group_name} || die 'missing required parameter "group_name"';
  my $desc = $args{description} || '';
  my $type = $args{type} || 'unknown';

  my $data = {     bio_group_name => $name,
            bio_group_description => $desc,
                   bio_group_type => $type };

  my $sbeams = $this->get_sbeams() || die "sbeams object not set";

  # Sanity check 
  my ($is_there) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_BIO_GROUP
  WHERE bio_group_name = '$name'
  END_SQL

  if ( $is_there ) {
    $log->error( "Attempting to create duplicate group" );
    return undef;
  }

  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                    return_PK => 1,
                         add_audit_parameters => 1,
                                   table_name => $TBBM_BIO_GROUP,
                                  rowdata_ref => $data
                                     );

  $log->error( "Couldn't create biogroup: $name" ) unless $id;
  $log->error( "oCreated biogroup: $name" ) if $id;
  return $id;
}

sub set_default_location {
  my $this = shift;
  my @default = $sbeams->selectrow_array( <<"  END" );
  SELECT storage_location_id FROM $TBBM_STORAGE_LOCATION
  WHERE location_name = 'Unknown'
  END
  if ( $default[0] ) {
    return 'unknown';
  } else {
    my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                     table_name => $TBBM_STORAGE_LOCATION,
                                    rowdata_ref => {location_name => 'unknown',
                                             location_description => 'autogenerated'},
                                             add_audit_parameters => 1
                                     ); 
    return ( $id ) ? 'unknown' : undef;
  }
  
}



1;

__END__

=head1 NAME:

SBEAMS::Biomarker

=head1 DESCRIPTION:

root object for SBEAMS Biomarker database.  Database is
designed to support activities of LCMS data acquisition.

=cut
