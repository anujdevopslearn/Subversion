package SBEAMS::Proteomics::TableInfo;

###############################################################################
# Program     : SBEAMS::Proteomics::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which returns
#               information about various tables.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
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
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT H.*
		  FROM xxxxxxx H
		 INNER JOIN xxxxxx HT
		       ON (H.hardware_type_id=HT.hardware_type_id)
		 WHERE H.record_status!='D'
            ~;
        }


    }


    if ($table_name eq "PR_search_hit_annotation") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT *
		  FROM $TBPR_SEARCH_HIT SH
		 WHERE SH.search_hit_id = '$parameters_ref->{search_hit_id}'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT *
		  FROM $TBPR_SEARCH_HIT SH
		 WHERE SH.search_hit_id = '$parameters_ref->{search_hit_id}'
            ~;
        }


    }


    if ($table_name eq "PR_proteomics_experiment") {

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
		 ORDER BY username,experiment_tag
            ~;

        }


    }



    if ($table_name eq "PR_publication") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT publication_id,publication_name,
		       publication_category_name AS "Category",
		       STR(publication_rating_number,5,0)+' - '+publication_rating_name AS "Rating",
		       presented_on_date AS "Date Presented",
		       username AS "Presented By",
		       title,
		       full_manuscript_file,
		       uri
		  FROM $TBPR_PUBLICATION P
		  LEFT JOIN $TBPR_PUBLICATION_CATEGORY PC
                       ON (P.publication_category_id = PC.publication_category_id)
		  LEFT JOIN $TBPR_PUBLICATION_RATING PR
                       ON (P.publication_rating_id = PR.publication_rating_id)
		  LEFT JOIN $TB_USER_LOGIN UL ON (P.presented_by_contact_id = UL.contact_id)
		 WHERE 1 =1
                   AND P.record_status!='D'
		   AND ( PC.record_status!='D' OR PC.record_status IS NULL )
		   AND ( PR.record_status!='D' OR PR.record_status IS NULL )
		   AND ( UL.record_status!='D' OR UL.record_status IS NULL )
		 ORDER BY publication_id
            ~;

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
