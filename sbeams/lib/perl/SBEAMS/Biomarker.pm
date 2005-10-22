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
sub get_experiment_list {
  my $this = shift;

  my $sbeams = $this->getSBEAMS();
  my $project_id = $sbeams->getCurrent_project_id();

  my $select = '<SELECT>';

  my $sql =<<"  END";
  SELECT experiment_id, experiment_name
  FROM $TBBM_BMRK_EXPERIMENT
  WHERE project_id = $project_id
  ORDER BY experiment_name ASC
  END

  my @rows = $sbeams->selectSeveralColumns( $sql );
  for my $row ( @rows ) {
    $select .= "<OPTION VALUE=$row->[0]> $row->[1]";
  }
  $select .= '</SELECT>';

  return $select;
}


#+
#-
sub get_experiment_name {
  my $this = shift;
  my $expt_id = shift || die 'Missing required experiment parameter';

  my $sbeams = $this->getSBEAMS();

  my $sql =<<"  END";
  SELECT experiment_name
  FROM $TBBM_BMRK_EXPERIMENT
  WHERE experiment_id = $expt_id
  END

  my @row = $sbeams->selectrow_array( $sql );

  # project doesn't exist, test fails
  return $row[0];
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
  SELECT e.experiment_id, experiment_name, experiment_tag, 
  experiment_type, experiment_description, COUNT(biosample_id)
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
           experiment_type, e.experiment_id, experiment_tag
  ORDER BY experiment_name ASC
  END
  $log->error( $sql );
  
  my $table = SBEAMS::Connection::DataTable->new( WIDTH => '100%' );
  $table->addResultsetHeader( ['Experiment Name', 'Tag', 'Type', 'Description', 
                         '# samples', '# ms runs' ] );

  for my $row ( $sbeams->selectSeveralColumns($sql) ) {
    my @row = @$row;
    my $id = shift @row;
    $row[3] = ( length $row[3] <= 50 ) ? $row[3] : shortlink($row[3], 50);
    $row[0] =<<"    END";
    <A HREF=experiment_details.cgi?experiment_id=$id>$row[0]</A>
    END
    push @row, $msruns{$id};
    $table->addRow( \@row )
  }
  $table->alternateColors( PERIOD => 1,
                           BGCOLOR => '#FFFFFF',
                           DEF_BGCOLOR => '#E0E0E0' ); 
  $table->setColAttr( ROWS => [ 2..$table->getRowNum() ], 
                      COLS => [ 4, 5 ], 
                      ALIGN => 'RIGHT' );
  $table->setColAttr( ROWS => [ 1 ], 
                      COLS => [ 1..6 ], 
                      ALIGN => 'CENTER' );
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


#+
# Routine builds a list of experiments/samples within.
#-
sub get_experiment_samples {
  my $this = shift;
  my $expt_id = shift;
  my $sbeams = $this->getSBEAMS();
  my $pid = $sbeams->getCurrent_project_id || die("Can't determine project_id");

  my $sql =<<"  END";
  SELECT biosample_id, biosample_name, tissue_type_name, 
         original_volume, location_name, 'glycocapture' AS glyco, 
         'msrun' AS msrun, 'mzXML' AS mzXML, 'pep3D' AS pep3D  
  FROM $TBBM_BMRK_BIOSAMPLE b 
   JOIN $TBBM_BMRK_BIOSOURCE r ON r.biosource_id = b.biosource_id
   JOIN $TBBM_TISSUE_TYPE t ON r.tissue_type_id = t.tissue_type_id
   JOIN $TBBM_BMRK_STORAGE_LOCATION s ON s.storage_location_id = b.storage_location_id
  WHERE experiment_id = $expt_id
  ORDER BY biosample_name ASC
  END
       
  my $table = SBEAMS::Connection::DataTable->new( WIDTH => '80%' );
  $table->addResultsetHeader( ['Sample Name', 'Tissue', 'Vol (&#181;l)',
                       'Storage location', 'Glycocap', 'MS_run', 'mzXML', 'pep3D' ] );

  my $cnt = 0;
  for my $row ( $sbeams->selectSeveralColumns($sql) ) {
    my @row = @$row;
    my $id = shift @row;
    $row[3] = ( length $row[3] <= 30 ) ? $row[3] :
                                         substr( $row[3], 0, 27 ) . '...';
    $row[2] = ( $row[2] ) ? $row[2]/1000 : 0;
    $row[0] =<<"    END";
    <A HREF=sample_details.cgi?sample_id=$id>$row[0]</A>
    END
    if ( $cnt > 5 ) {
      $row[7] = undef;
      $row[6] = undef;
    } else {
      $row[6] = 'Yes';
      $row[7] = '<A HREF=/tmp/pep3d.gif>Yes</A>';
    }
    if ( $cnt > 11 ) {
      $row[5] = undef;
    } else {
      $row[5] = '<A HREF=/tmp/pep3d.gif>Yes</A>';
    }
    if ( $cnt > 108 ) {
      $row[4] = undef;
    } else {
      $row[4] = '<A HREF=/tmp/pep3d.gif>Yes</A>';
    }
    $cnt++;
    $table->addRow( \@row )
  }
  $table->alternateColors( PERIOD => 3,
                           BGCOLOR => '#F3F3F3',
                           DEF_BGCOLOR => '#E0E0E0' ); 
  $table->setColAttr( ROWS => [ 2..$table->getRowNum() ], 
                      COLS => [ 2,4..8 ], 
                      ALIGN => 'CENTER' );
  $table->setColAttr( ROWS => [ 2..$table->getRowNum() ], 
                      COLS => [ 3 ], 
                      ALIGN => 'RIGHT' );
  $table->setColAttr( ROWS => [ 1 ], 
                      COLS => [ 1..8 ], 
                      ALIGN => 'CENTER' );
  return $table;
}
1;

#+
# Routine builds a list of experiments/samples within.
#-
sub get_experiment_details {
  my $this = shift;
  my $expt_id = shift;
  return '';
  my $sbeams = $this->getSBEAMS();
  my $pid = $sbeams->getCurrent_project_id || die("Can't determine project_id");

  my $sql =<<"  END";
  SELECT e.experiment_id, experiment_tag, experiment_name, experiment_type, 
  experiment_description, COUNT(biosample_id) AS total_biosamples
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

  my ($expt) = $sbeams->selectrow_hashref($sql);
  my $table = '<TABLE>';
  for my $key ( qw(experiment_name experiment_tag experiment_type 
                   experiment_description total_biosamples) ) {
    my $ukey = ucfirst( $key );
    $table .= "<TR><TD ALIGN=RIGHT><B>$ukey:</B></TD><TD>$expt->{$key}</TD></TR>";
  }
  $table .= '</TABLE>';
       
  return $table;
}


sub shortlink {
  my $val = shift;
  my $len = shift;
  return "<DIV title='$val'> ". substr( $val, 0, $len - 3 ) . '...</DIV>';
}

sub set_default_location {
  my $this = shift;
  my @default = $sbeams->selectrow_array( <<"  END" );
  SELECT storage_location_id FROM $TBBM_BMRK_STORAGE_LOCATION
  WHERE location_name = 'Unknown'
  END
  if ( $default[0] ) {
    return 'unknown';
  } else {
    my $id = sbeams->updateOrInsertRow( insert => 1,
                                     return_PK => 1,
                                    table_name => $TBBM_BMRK_STORAGE_LOCATION,
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
