package SBEAMS::Proteomics::TableInfo;

###############################################################################
# Program     : SBEAMS::Proteomics::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which returns
#               information about various tables.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Connection::Log;

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
# Return Table Info
#
# Return the required information about the specified Table
###############################################################################
sub returnTableInfo {
  my $self = shift;
  my $table_name = shift || croak("parameter table_name not specified");
  my $info_key = shift || croak("parameter info_key not specified");
  my $parameters_ref = shift;

  my @row;
  my $sql_query;
  my $result;

  #### Obtain main SBEAMS object for later use
  my $sbeams = $self->getSBEAMS();

  # Fetch accessible projects
  my @accessible_project_ids = $self->getSBEAMS()->getAccessibleProjects();
	my $accessible_project_ids = join( ",", @accessible_project_ids ) || '0';

  # Define project SQL hash.
  my %projectSQL;
  $log->debug( 'Getting project SQL ' ) if $info_key eq 'projPermSQL';


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
	 	  INNER JOIN xxxxxxxxx HT
              ON (H.hardware_type_id=HT.hardware_type_id)
      WHERE H.record_status!='D'
      ~;
    } elsif ($info_key eq "FULLQuery") {
     return qq~
		 SELECT H.*
		 FROM xxxxxxx H
		 INNER JOIN xxxxxx HT
		         ON (H.hardware_type_id=HT.hardware_type_id)
		 WHERE H.record_status!='D'
     ~;
    }

  } elsif ($table_name eq "PR_search_hit_annotation") {

    if ($info_key eq "BASICQuery") {
      return qq~
	  	SELECT *
		  FROM $TBPR_SEARCH_HIT SH
		  WHERE SH.search_hit_id = '$parameters_ref->{search_hit_id}'
      ~;
    } elsif ($info_key eq "FULLQuery") {
      return qq~
		  SELECT *
		  FROM $TBPR_SEARCH_HIT SH
		  WHERE SH.search_hit_id = '$parameters_ref->{search_hit_id}'
      ~;
    } elsif ( $info_key eq 'projPermSQL' ) {
      $projectSQL{fsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_PROTEOMICS_EXPERIMENT PE
      JOIN $TBPR_FRACTION F ON F.experiment_id = PE.experiment_id
      JOIN $TBPR_MSMS_SPECTRUM MS ON F.fraction_id = MS.fraction_id 
      JOIN $TBPR_SEARCH S ON S.msms_spectrum_id = MS.msms_spectrum_id 
      JOIN $TBPR_SEARCH_HIT SH ON S.search_id = SH.search_id 
      WHERE search_hit_id = KEYVAL 
      SQL

      $projectSQL{dbsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_PROTEOMICS_EXPERIMENT PE
      JOIN $TBPR_FRACTION F ON F.experiment_id = PE.experiment_id
      JOIN $TBPR_MSMS_SPECTRUM MS ON F.fraction_id = MS.fraction_id 
      JOIN $TBPR_SEARCH S ON S.msms_spectrum_id = MS.msms_spectrum_id 
      JOIN $TBPR_SEARCH_HIT SH ON S.search_id = SH.search_id 
      JOIN $TBPR_SEARCH_HIT_ANNOTATION SHA ON SHA.search_hit_id = SH.search_hit_id 
      WHERE search_hit_annotation_id = KEYVAL 
      SQL
      $log->debug( "Evaluate " . eval "$projectSQL{dbsql}" );

      return \%projectSQL
    }
  # End if search_hit_annotation

  } elsif ($table_name eq "PR_proteomics_experiment") {

    if ($info_key eq "BASICQuery") {
      return qq~
  		SELECT experiment_id,username,P.project_id AS "proj",
  		       name AS 'project_name',PE.experiment_id AS "exp",
  		       experiment_tag,experiment_name,O.organism_name,
                         experiment_description
  		FROM $TBPR_PROTEOMICS_EXPERIMENT PE
  		INNER JOIN $TB_USER_LOGIN UL ON (PE.contact_id=UL.contact_id)
  		INNER JOIN $TB_PROJECT P ON (PE.project_id=P.project_id)
  		LEFT JOIN $TB_ORGANISM O ON (PE.organism_id=O.organism_id)
  		WHERE PE.record_status!='D'
  		  AND UL.record_status!='D'
  		  AND P.record_status!='D'
        AND P.project_id IN ( $accessible_project_ids )
      ORDER BY username,experiment_tag
      ~;
      } elsif ($info_key eq "FULLQuery") {
       return qq~
  		 SELECT PE.*
  		 FROM $TBPR_PROTEOMICS_EXPERIMENT PE
  		 WHERE PE.record_status!='D'
         AND PE.project_id IN ( $accessible_project_ids )
       ~;
  
     } elsif ( $info_key eq 'projPermSQL' ) {
       $projectSQL{fsql} = '';

       $projectSQL{dbsql} =<<"       SQL";
       SELECT project_id 
       FROM $TBPR_PROTEOMICS_EXPERIMENT PE 
       WHERE experiment_id = KEYVAL 
       SQL

       return \%projectSQL
     }
   # End if proteomics_expt

  } elsif ( $table_name eq 'PR_biosequence_set' ) {
     
    if ( $info_key eq 'projPermSQL' ) {
      $projectSQL{fsql} = '';

      $projectSQL{dbsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_BIOSEQUENCE_SET 
      WHERE biosequence_set_id = KEYVAL 
      SQL

      return \%projectSQL
    }
  # End if biosequence_set
     
  } elsif ( $table_name eq 'PR_gradient_program' ) {
     
    if ( $info_key eq 'projPermSQL' ) {
      $projectSQL{fsql} = '';

      $projectSQL{dbsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_GRADIENT_PROGRAM
      WHERE gradient_program_id = KEYVAL
      SQL

      return \%projectSQL
    }
  # End if gradient_program
     
  } elsif ( $table_name eq 'APD_peptide_summary' ) {
     
    if ( $info_key eq 'projPermSQL' ) {
      $projectSQL{fsql} = '';

      $projectSQL{dbsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBAPD_PEPTIDE_SUMMARY
      WHERE peptide_summary_id = KEYVAL
      SQL

      return \%projectSQL
    }
  # End if peptide_summary
     
  } elsif ( $table_name eq 'PR_fraction' ) {
     
    if ( $info_key eq 'projPermSQL' ) {
      $projectSQL{fsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_PROTEOMICS_EXPERIMENT 
      WHERE experiment_id = KEYVAL 
      SQL

      $projectSQL{dbsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_PROTEOMICS_EXPERIMENT PE 
      JOIN $TBPR_FRACTION F ON F.experiment_id = PE.experiment_id
      WHERE fraction_id = KEYVAL 
      SQL

      return \%projectSQL
    }
  # End if fraction

  } elsif ( $table_name eq 'PR_search_batch' ) {
     
    if ( $info_key eq 'projPermSQL' ) {
      $projectSQL{fsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_PROTEOMICS_EXPERIMENT 
      WHERE experiment_id = KEYVAL 
      SQL

      $projectSQL{dbsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_PROTEOMICS_EXPERIMENT PE 
      JOIN $TBPR_SEARCH_BATCH SB ON SB.experiment_id = PE.experiment_id
      WHERE search_batch_id = KEYVAL 
      SQL

      return \%projectSQL
    }
  # End if search_batch

  } elsif ( $table_name eq 'PR_biosequence' ) {
     
    if ( $info_key eq 'projPermSQL' ) {
      $projectSQL{fsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_BIOSEQUENCE_SET 
      WHERE biosequence_set_id = KEYVAL 
      SQL

      $projectSQL{dbsql} =<<"      SQL";
      SELECT project_id 
      FROM $TBPR_BIOSEQUENCE_SET BS
      JOIN $TBPR_BIOSEQUENCE B ON B.biosequence_set_id = BS.biosequence_set_id
      WHERE biosequence_id = KEYVAL 
      SQL

      return \%projectSQL
    }
  # End if biosequence

  } elsif ($table_name eq "PR_publication") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT publication_id,publication_name,
		       title,
		       full_manuscript_file,
		       uri
		  FROM $TBPR_PUBLICATION P
		 WHERE 1 =1
                   AND P.record_status!='D'
		 ORDER BY publication_id
            ~;

        }
  } elsif ($table_name eq "PR_proteomics_sample") {

    if ( $info_key eq "projPermSQL" ) { 
        my %projectSQL;

        $projectSQL{fsql} = '';		#proteomics_sample table has a project_id column

        $projectSQL{dbsql} =<<"        END";
        SELECT project_id 
        FROM $TBPR_PROTEOMICS_SAMPLE 
        WHERE proteomics_sample_id  = KEYVAL 
        END
	$log->debug("SQL '$projectSQL{dbsql}'");
        return \%projectSQL
      }
  }



###############################################################################
  if ($info_key eq "url_cols") {

    my $subdir = $sbeams->getSBEAMS_SUBDIR();
    $subdir .= "/" if ($subdir);
    my $PROGRAM_FILE_NAME =
      $sbeams->returnTableInfo($table_name,"PROGRAM_FILE_NAME");
    my $PK_COLUMN_NAME =
      $sbeams->returnTableInfo($table_name,"PK_COLUMN_NAME");

    if ($table_name eq "PR_proteomics_experiment") {
      my %url_cols;
      $url_cols{experiment_id} =
        "$CGI_BASE_DIR/$subdir$PROGRAM_FILE_NAME&$PK_COLUMN_NAME=%V";
      $url_cols{proj} =
        "$CGI_BASE_DIR/${subdir}ManageTable.cgi?TABLE_NAME=project&project_id=%V";
      $url_cols{exp} =
        "$CGI_BASE_DIR/${subdir}ManageTable.cgi?TABLE_NAME=PR_proteomics_experiment&experiment_id=%V";
      return %url_cols;
    }

  }



###############################################################################

    #### Obtain main SBEAMS object and fall back to its TableInfo handler
    my @temp_result = $sbeams->returnTableInfo($table_name,$info_key);
    return @temp_result;

}




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
  $log->debug( $table_name );

  #### Define the project_id, starting as undef, it gets filled if there is one
  my $project_id;

  #### Check to see if this is a Core table that has project control
  $project_id = $sbeams->getParentProject(
    table_name => $table_name,
    action => $action,
    parameters_ref => $parameters_ref,
  );
  return($project_id) if ($project_id);

  # Value may be cached/defined in input parameters... for reasons unknown!
  # return $parameters_ref->{project_id} if $parameters_ref->{project_id};
   $log->debug( 'Got past the short-circuits with ' . $table_name );

  # Fetch SQL to retrieve project_id from table_name, if it is available.
  my $sqlref = $self->returnTableInfo( $table_name, 'projPermSQL' );

  # If we don't have it 
  unless ( ref( $sqlref ) && $sqlref->{dbsql} ) {
    $log->error( "dbsql not defined for $table_name\n" );
    return undef;
  }


  #############################################################################
  #### Process actions for individual tables

  if ( $table_name  eq 'PR_proteomics_experiment' ) {

    if ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The array table has project_id in it
      if ( $parameters_ref->{experiment_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{experiment_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ( $table_name  eq 'PR_biosequence_set' ) {

    if ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The array table has project_id in it
      if ( $parameters_ref->{biosequence_set_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{biosequence_set_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ( $table_name  eq 'PR_gradient_program' ) {

    if ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The array table has project_id in it
      if ( $parameters_ref->{gradient_program_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{gradient_program_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ( $table_name  eq 'APD_peptide_summary' ) {

    if ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The array table has project_id in it
      if ( $parameters_ref->{peptide_summary_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{peptide_summary_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ( $table_name  eq 'PR_fraction' ) {

    if ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The array table has project_id in it
      if ( $parameters_ref->{fraction_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{fraction_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ( $table_name  eq 'PR_search_batch' ) {

    if ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The array table has project_id in it
      if ( $parameters_ref->{search_batch_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{search_batch_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  } elsif ( $table_name  eq 'PR_search_hit_annotation' ) {

    if ($action eq 'UPDATE' || $action eq 'DELETE') {

      # The array table has project_id in it
      if ( $parameters_ref->{search_hit_annotation_id} ) {
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{search_hit_annotation_id}/;
        ( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;

  }elsif ( uc($table_name) eq 'PR_PROTEOMICS_SAMPLE') { # Proteomics Sample table
	
	
    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      # No parent project yet, for object doesn't exist.
      return undef;

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

      if ( $parameters_ref->{proteomics_sample_id} ) {
         $log->debug( $sqlref->{dbsql});
        $sqlref->{dbsql} =~ s/KEYVAL/$parameters_ref->{proteomics_sample_id}/;
       
	( $project_id ) = $sbeams->selectOneColumn( $sqlref->{dbsql} );
      }
    }
    return ( $project_id ) ? $project_id : undef;
   
  } elsif ($table_name eq "zzzz") {
	
    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

    }

    return($project_id) if ($project_id);
  }
	$log->debug("*****TABLE NAME $table_name *******");

  #### No information for this table so return undef
  return;

}



###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
