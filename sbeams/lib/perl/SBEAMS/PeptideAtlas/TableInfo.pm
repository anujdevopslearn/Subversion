package SBEAMS::PeptideAtlas::TableInfo;

###############################################################################
# Program     : SBEAMS::PeptideAtlas::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::PeptideAtlas module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection qw( $log );

use Data::Dumper;


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
# Return Table Info
#
# Return the required information about the specified Table
###############################################################################
sub returnTableInfo {
  my $self = shift;
  my $table_name = shift || croak("parameter table_name not specified");
  my $info_key = shift || croak("parameter info_key not specified");

  my @row;
  my $sql_query;
  my $result;
  my @ids = $self->getSBEAMS()->getAccessibleProjects();
 
  my $project_string = join( ",", @ids ) || '0';

   ###############################################################################
   #
   # First we have table-specific overrides of the default answers
   #
   # This is mostly just Queries now.  This should be pushed out into a
   # nicely formatted file of queries.
   #
   ###############################################################################
   ###############################################################################
  if ($table_name eq "blxxxxxx") {

    if ($info_key eq "BASICQuery") {
      return qq~
     	SELECT hardware_id,HT.name,make,model,serial_number,uri
      FROM xxxxxxxx H
      JOIN xxxxxxxxx HT
      ON (H.hardware_type_id=HT.hardware_type_id)
      WHERE H.record_status!='D'
    ~;
    } elsif ($info_key eq "FULLQuery") {
      return qq~
  		SELECT H.*
      FROM xxxxxxx H
      JOIN xxxxxx HT
      ON (H.hardware_type_id=HT.hardware_type_id)
      WHERE H.record_status!='D'
      ~;
    }

  } elsif ( uc($table_name) eq 'AT_SAMPLE' ) {
      
    if ($info_key eq "BASICQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT sample_id,sample_tag, sample_title, search_batch_id,
        anatomical_site_term, developmental_stage_term, pathology_term, 
        cell_type_term, data_contributors, is_public, peptide_source_type
      FROM $TBAT_SAMPLE 
      WHERE project_id IN ( $project_string )
      AND record_status!='D'
      END_QUERY

    } elsif ($info_key eq "FULLQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT *
      FROM $TBAT_SAMPLE 
      WHERE project_id IN ( $project_string )
      AND record_status!='D'
      END_QUERY

    } elsif ( $info_key eq 'projPermSQL' ) { 
      my %projectSQL;
      $projectSQL{fsql} = '';
      $projectSQL{dbsql} =<<"      END";
      SELECT project_id FROM $TBAT_SAMPLE 
      WHERE sample_id = KEYVAL
      END
      return \%projectSQL
    }

    ## xxxx  need retrieval of is_display_column info from
    ## wherever PeptideAtlas_table_column.txt is stored
    ## by update_driver_tables.pl
      
  } elsif ( uc($table_name) eq 'AT_BIOSEQUENCE_SET' ) {
      
    if ($info_key eq "BASICQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT *
      FROM $TBAT_BIOSEQUENCE_SET 
      WHERE project_id IN ( $project_string )
      AND record_status!='D'
      END_QUERY

    } elsif ($info_key eq "FULLQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT *
      FROM $TBAT_BIOSEQUENCE_SET 
      WHERE project_id IN ( $project_string )
      AND record_status!='D'
      END_QUERY

    } elsif ( $info_key eq 'projPermSQL' ) { 
      my %projectSQL;
      $projectSQL{fsql} = '';
      $projectSQL{dbsql} =<<"      END";
      SELECT project_id FROM $TBAT_BIOSEQUENCE_SET 
      WHERE biosequence_set_id = KEYVAL
      END
      return \%projectSQL
    }

  } elsif ( uc($table_name) eq 'AT_PUBLICATION' ) {
      
    if ($info_key eq "BASICQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT *
      FROM $TBAT_PUBLICATION
      WHERE record_status!='D'
      END_QUERY

    } elsif ($info_key eq "FULLQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT *
      FROM $TBAT_PUBLICATION
      WHERE record_status!='D'
      END_QUERY

    } elsif ( $info_key eq 'projPermSQL' ) { 
      
      my %projectSQL;
      $projectSQL{fsql} = '';
      $projectSQL{dbsql} =<<"      END";
      SELECT project_id FROM $TBAT_ATLAS_BUILD 
      WHERE atlas_build_id = KEYVAL
      END
      return \%projectSQL
    } 

  } elsif ( uc($table_name) eq 'AT_ATLAS_BUILD' ) {
      
    if ($info_key eq "BASICQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT *
      FROM $TBAT_ATLAS_BUILD
      WHERE project_id IN ( $project_string )
      AND record_status!='D'
      END_QUERY

    } elsif ($info_key eq "FULLQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT *
      FROM $TBAT_ATLAS_BUILD 
      WHERE project_id IN ( $project_string )
      AND record_status!='D'
      END_QUERY

    } elsif ( $info_key eq 'projPermSQL' ) { 
      
      my %projectSQL;
      $projectSQL{fsql} = '';
      $projectSQL{dbsql} =<<"      END";
      SELECT project_id FROM $TBAT_ATLAS_BUILD 
      WHERE atlas_build_id = KEYVAL
      END
      return \%projectSQL
    } 
  } elsif ( uc($table_name) eq 'AT_PASS_SUBMITTER' ) {
    if ($info_key eq "BASICQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT submitter_id, firstName, lastName, emailAddress,
	    emailReminders, emailPasswords, comment
      FROM $TBAT_PASS_SUBMITTER
      WHERE record_status!='D'
      END_QUERY

    } elsif ($info_key eq "FULLQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT submitter_id, firstName, lastName, emailAddress,
	    emailReminders, emailPasswords, comment, date_created, created_by_id, date_modified, modified_by_id, owner_group_id, record_status
      FROM $TBAT_PASS_SUBMITTER
      END_QUERY
    }

  } elsif ( uc($table_name) eq 'AT_PASS_DATASET' ) {
    if ($info_key eq "BASICQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT dataset_id, submitter_id, datasetIdentifier, datasetType,
	  datasetTag, datasetTitle, publicReleaseDate, finalizedDate,
	  comment
      FROM $TBAT_PASS_DATASET
      WHERE record_status!='D'
      END_QUERY
    }
  }elsif(uc($table_name) eq 'AT_PUBLIC_DATA_REPOSITORY'){
    if ($info_key eq "BASICQuery") {
     return( <<"      END_QUERY" );
      SELECT dataset_id,
							dataset_identifier,
							source_repository,
							species,
							classfication,
							pa_sample_accession,
							local_data_location,
							datasetTitle,
							datasetType,
							instrument,
							contributor,
							publication
      FROM $TBAT_PUBLIC_DATA_REPOSITORY
      WHERE record_status!='D'
      END_QUERY
    }
  } elsif ( uc($table_name) eq 'AT_DOMAIN_PROTEIN_LIST' ) {
    if ($info_key eq "BASICQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT protein_list_id, title, description, owner_contact_id, project_id, n_proteins
      FROM $TBAT_DOMAIN_PROTEIN_LIST
      WHERE record_status!='D'
      END_QUERY
    }

  } elsif ( uc($table_name) eq 'AT_DOMAIN_LIST_PROTEIN' ) {
    if ($info_key eq "BASICQuery") {
      return( <<"      END_QUERY" ); 
     	SELECT list_protein_id, original_name, original_accession, protein_symbol, gene_symbol, protein_full_name, priority, comment
      FROM $TBAT_DOMAIN_LIST_PROTEIN
      WHERE record_status!='D'
      END_QUERY
    }
  }

  #### Obtain main SBEAMS object and fall back to its TableInfo handler
  my $sbeams = $self->getSBEAMS();
  my @temp_result = $sbeams->returnTableInfo($table_name,$info_key);
#  my $ret = "args: table_name = $table_name, info_key = $info_key\n";
#  for my $r ( @temp_result ) {
#    $ret .= " $r\n";
#  }
#  $log->info( $ret );
  return @temp_result;

} # End returnTableInfo




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
  my $sbeams = $self->getSBEAMS();

  #### Define the project_id, starting as undef, it gets filled if there is one
  my $project_id;

  #### Check to see if this is a Core table that has project control
  $project_id = $sbeams->getParentProject(
    table_name => $table_name,
    action => $action,
    parameters_ref => $parameters_ref,
  );
  return($project_id) if ($project_id);

  # We may well have this cached
  return $parameters_ref->{project_id} if $parameters_ref->{project_id};

  # Fetch SQL to retrieve project_id from table_name, if it is available.
  my $sqlref = $self->returnTableInfo( $table_name, 'projPermSQL' );
##xxxxx may need to return isDisplayColumn here?

  # If we don't have it 
  unless ( ref( $sqlref ) && $sqlref->{dbsql} ) {
    print STDERR "dbsql not defined for $table_name\n";
    return undef;
  }


  #############################################################################
  #### Process actions for individual tables

  #### If table is xxxx
  if ( uc($table_name) eq 'AT_SAMPLE') {

    # If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      # No parent project yet, for object doesn't exist.
      return undef;

    # Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The sample table has project_id in it
      if ( $parameters_ref->{sample_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{sample_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ( uc($table_name) eq 'AT_BIOSEQUENCE_SET') {

    # If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      # No parent project yet, for object doesn't exist.
      return undef;

    # Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The biosequence_set table has project_id in it
      if ( $parameters_ref->{biosequence_set_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{biosequence_set_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ( uc($table_name) eq 'AT_ATLAS_BUILD') {

    # If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      # No parent project yet, for object doesn't exist.
      return undef;

    # Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The atlas_build table has project_id in it
      if ( $parameters_ref->{atlas_build_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{atlas_build_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ($table_name eq "xxxx") {

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
