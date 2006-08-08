package SBEAMS::Biomarker::TableInfo;
# Description : SBEAMS::Biomarker component which returns various table info.
# $Id$

use strict;


use SBEAMS::Biomarker::Settings;
use SBEAMS::Biomarker::Tables;

use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Log;

my $log = SBEAMS::Connection::Log->new();

#+
# Constructor
#-
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


#+
# Returns information based on subject table and key value. Note that arguments
# have a requisite order, table_name then info_key.
#
# arguements:  table_name  Name of table in table_properties table (req)
# arguements:  info_key    'Key' for specifying which info is needed (req)
#
# returns:     one or more bits of information, depending on key.
#-
###############################################################################
sub returnTableInfo {
  my $self = shift;
  my $table_name = shift || croak("parameter table_name not specified");
  my $info_key = shift || croak("parameter info_key not specified");

  my @row;
  my $sql_query;
  my $result;

  my $sbeams = $self->get_sbeams();
  my $tinfo = $self->getTableProperties($table_name);
  my $cinfo = $self->getColumnProperties($table_name);

  my $dbtable = $sbeams->evalSQL( "$tinfo->{db_table_name}" );
  $log->debug( "Table name is $table_name, dbtable is $dbtable" );

  # First we have table-specific overrides of the default answers
  if ($table_name eq "TABLESQUE") {

    if ($info_key eq "BASICQuery") {
      return qq~
   		SELECT 
      FROM $table_name T
      JOIN sometable S
      ON ( H.some_field = S.some_field )
      WHERE T.record_status!='D'
      AND S.record_status!='D'
      ~;

    } elsif ($info_key eq "FULLQuery") {
      return qq~
   		SELECT 
      FROM $table_name T
      JOIN sometable S
      ON ( H.some_field = S.some_field )
      WHERE T.record_status!='D'
      AND S.record_status!='D'
      ~;
    }

  } elsif ($table_name eq "TABLESQUE") {

  } else { # Non table-specific responses.

    if ($info_key eq "BASICQuery") {
      return qq~
 		  SELECT *
      FROM $dbtable
      WHERE record_status!='D'
      ~;

    } elsif ($info_key eq "FULLQuery") {
      return qq~
 		  SELECT *
      FROM $dbtable
      WHERE record_status!='D'
      ~;
    } elsif ($info_key eq "FULLQuery") {
      $log->debug( $info_key );
    } elsif ($info_key eq "BASICQuery") {
      $log->debug( $info_key );
    } elsif ($info_key eq "CATEGORY") {
      return( $tinfo->{category} );
    } elsif ($info_key eq "data_columns") {
      $log->debug( $info_key );
    } elsif ($info_key eq "data_scales") {
      $log->debug( $info_key );
    } elsif ($info_key eq "data_types") {
      $log->debug( $info_key );
    } elsif ($info_key eq "DB_TABLE_NAME") {
      return( $dbtable );
    } elsif ($info_key eq "fk_tables") {
      my %fktabs;
      for( @$cinfo ){
        $fktabs{$cinfo->{column_name}} = $cinfo->{fk_table};
      }
      return \%fktabs;
    } elsif ($info_key eq "input_types") {
      $log->debug( $info_key );
    } elsif ($info_key eq "key_columns") {
      $log->debug( $info_key );
    } elsif ($info_key eq "ManageTableAllowed") {
      return( $tinfo->{manage_table_allowed} );
    } elsif ($info_key eq "MENU_OPTIONS") {
      $log->debug( $info_key );
    } elsif ($info_key eq "MULTI_INSERT_COLUMN") {
      $log->debug( $info_key );
    } elsif ($info_key eq "ordered_columns") {
      $log->debug( $info_key );
    } elsif ($info_key eq "PK_COLUMN_NAME") {
      $log->debug( $info_key );
    } elsif ($info_key eq "PROGRAM_FILE_NAME") {
      $log->debug( $info_key );
    } elsif ($info_key eq "QueryTypes") {
      $log->debug( $info_key );
    } elsif ($info_key eq "required_columns") {
      $log->debug( $info_key );
    } elsif ($info_key eq "url_cols") {
      $log->debug( $info_key );

    } 

    # fall through to parent sbeams tableInfo handler 
    return $sbeams->returnTableInfo($table_name, $info_key);
  }
}

#+
# Routine to fetch and return table_property information for a particular table
# arguments:    table_name (required)
# returns:      ref to hash of col_name => value for specified table
#-
sub getTableProperties {
  my $self = shift;
  my $table_name = shift || die "Missing required table_name parameter";
  
  # See if we have this cached
  if ( $self->{_tinfo}->{$table_name} ) {
#    $log->debug( "Using cached table info" );
  } else {

    my $tabSQL =<<"    END_TSQL";
    SELECT category, table_group, manage_table_allowed, db_table_name,
    PK_column_name, multi_insert_column, table_url, manage_tables, next_step
    FROM $TB_TABLE_PROPERTY
    WHERE table_name = '$table_name'
    END_TSQL

    my @prop_array = $self->get_sbeams()->selectHashArray( $tabSQL );
    $self->{_tinfo}->{$table_name} = $prop_array[0];
  }
  return $self->{_tinfo}->{$table_name} 

} # End getTableProperties

#+
# Routine to fetch and return column_property information for the columns in
# a particular table
# arguments:    table_name (required)
# returns:      ref to array of col_name => value hashrefs for specified table
#-
sub getColumnProperties {
  my $self = shift;
  my $table_name = shift || die "Missing required table_name parameter";

  # See if we have this cached
  if ( $self->{_cinfo}->{$table_name} ) {
#    $log->debug( "Using cached column info" );
    
  } else {

    my $colSQL =<<"    END_CSQL";
    SELECT column_index, column_name, column_title, data_type, data_scale,
    data_precision, nullable, default_value, is_auto_inc, fk_table,
    fk_column_name, is_required, input_type, input_length, onChange,
    is_data_column, is_display_column, is_key_field, column_text,
    optionlist_query, url
    FROM $TB_TABLE_COLUMN
    WHERE table_name = '$table_name'
    END_CSQL

    $self->{_cinfo}->{$table_name} = $self->get_sbeams()->selectHashArray( $colSQL );
  }
  return $self->{_cinfo}->{$table_name} 

} # End getColumnProperties
  

###############################################################################
# getParentProject
#
# Return the parent project of a record in a table which might govern
# whether the proposed INSERT or UPDATE function may proceed.
###############################################################################
sub getParentProject {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = "getParentProject";

  #### Decode the argument list
  my $table_name = $args{'table_name'}
    || die("ERROR: $SUB_NAME: Parameter table_name not passed");
  my $action = $args{'action'}
    || die("ERROR: $SUB_NAME: Parameter action not passed");
  my $parameters_ref = $args{'parameters_ref'}
    || die("ERROR: $SUB_NAME: Parameter parameters_ref not passed");

  #### Make sure action is one of INSERT,UPDATE,DELETE
  unless ($action =~ /^INSERT$|^UPDATE$|^DELETE$/) {
    die("ERROR: $SUB_NAME: action must be one of INSERT,UPDATE,DELETE");
  }

  #### Get sbeams object, needed for Core tables and SQL queries
  my $sbeams = $self->get_sbeams();

  #### Define the project_id, starting as undef, it gets filled if there is one
  my $project_id;

  #### Check to see if this is a Core table that has project control
  $project_id = $sbeams->getParentProject(
    table_name => $table_name,
    action => $action,
    parameters_ref => $parameters_ref,
  );
  return($project_id) if ($project_id);


  #############################################################################
  #### Process actions for individual tables

  #### If table is xxxx
  if ($table_name eq "xxxx") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

    }

    return($project_id) if ($project_id);
  }


  #### No information for this table so return undef
  return;

}



###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
