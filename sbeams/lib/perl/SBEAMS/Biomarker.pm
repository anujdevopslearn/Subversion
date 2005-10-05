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
  $sbeams = shift;
}

#+
# Routine to return cached sbeams object
#-
sub getSBEAMS {
  my $self = shift;
  return($sbeams);
}

#+
# Routine to check existence and writability of an experiment
# argument  experiment name (req) 
# returns   boolean, whether expt exists and project is writable
#-
sub checkExperiment {
  my $this = shift;
  my $expt = shift || die 'Missing required experiment parameter';

  my $sbeams = $this->getSBEAMS();

  my $sql =<<"  END";
  SELECT experiment_id, project_id
  FROM $TBBM_BMRK_EXPERIMENT
  WHERE experiment_name = '$expt'
  END

  $sql = $sbeams->evalSQL( $sql );
  my @row = $sbeams->selectrow_array( $sql );

  # project doesn't exist, test fails
  return undef unless $row[0];

  # Is user authorized to write this project?
  return $sbeams->isProjectWritable( project_id => $row[1] );

}

#+
# Routine builds a list of experiments/samples within.
#-
sub get_experiment_overview {
  my $this = shift;
  my $sbeams = $this->getSBEAMS();
  my $pid = $sbeams->getCurrent_project_id || die("Can't determine project_id");

  my %msruns = $sbeams->selectTwoColumnHash( <<"  END" );
  SELECT e.experiment_id, COUNT(msrs.biosample_id)
  FROM $TBBM_BMRK_EXPERIMENT e 
  LEFT OUTER JOIN $TBBM_BMRK_BIOSAMPLE b
  ON e.experiment_id = b.experiment_id
  LEFT OUTER JOIN $TBBM_BMRK_MS_RUN_SAMPLE msrs
  ON b.biosample_id = msrs.biosample_id
--  JOIN $TBBM_BMRK_MS_RUN msr
--  ON e. = msrs.ms_run_id = msr.ms_run_id
  WHERE project_id = $pid
  -- Just grab the 'primary' samples 
  GROUP BY e.experiment_id
  END

  my $sql =<<"  END";
  SELECT e.experiment_id, experiment_name, experiment_type, 
  experiment_description, COUNT(biosample_id)
  FROM $TBBM_BMRK_EXPERIMENT e 
  LEFT OUTER JOIN $TBBM_BMRK_BIOSAMPLE b
  ON e.experiment_id = b.experiment_id
--  JOIN $TBBM_BMRK_MS_RUN_SAMPLE msrs
--  ON e. = b.biosample_id = msrs.biosample_id
--  JOIN $TBBM_BMRK_MS_RUN msr
--  ON e. = msrs.ms_run_id = msr.ms_run_id
  WHERE project_id = $pid
  -- Just grab the 'primary' samples 
  AND parent_biosample_id IS NULL
  GROUP by experiment_name, experiment_description, 
           experiment_type, e.experiment_id
  ORDER BY experiment_name ASC
  END
  
  my $table = SBEAMS::Connection::DataTable->new( WIDTH => '100%' );
  $table->addResultsetHeader( ['Experiment Name', 'Type', 'Description', 
                         '# samples', '# ms runs' ] );

  for my $row ( $sbeams->selectSeveralColumns($sql) ) {
    my @row = @$row;
    my $id = shift @row;
    $row[2] = ( length $row[2] <= 50 ) ? $row[2] :
                                         substr( $row[2], 0, 47 ) . '...';
    $row[0] =<<"    END";
    <A HREF=experiment_details.cgi?experiment_id=$id>$row[0]</A>
    END
    push @row, $msruns{$id};
    $table->addRow( \@row )
  }
  $table->alternateColors( PERIOD => 1,
                           BGCOLOR => '#FFFFFF',
                           DEF_BGCOLOR => '#E0E0E0' ); 
  $table->setColAttr( ROWS => [ 1..$table->getRowNum() ], 
                      COLS => [ 4, 5 ], 
                      ALIGN => 'RIGHT' );
  return $table;
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

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";

  # Sanity check 
  my ($is_there) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_BMRK_BIO_GROUP
  WHERE bio_group_name = '$name'
  END_SQL

  if ( $is_there ) {
    $log->error( "Attempting to create duplicate group" );
    return undef;
  }

  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                    return_PK => 1,
                         add_audit_parameters => 1,
                                   table_name => $TBBM_BMRK_BIO_GROUP,
                                  rowdata_ref => $data
                                     );

  $log->error( "Couldn't create biogroup: $name" ) unless $id;
  return $id;
}

1;

__END__

=head1 NAME:

SBEAMS::Biomarker

=head1 DESCRIPTION:

root object for SBEAMS Biomarker database.  Database is
designed to support activities of LCMS data acquisition.

=cut
