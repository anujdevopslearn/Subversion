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
		  JOIN xxxxxxxxx HT
		       ON (H.hardware_type_id=HT.hardware_type_id)
		 WHERE H.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT H.*
		  FROM xxxxxxx H
		  JOIN xxxxxx HT
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
		       experiment_tag,experiment_name,experiment_description
		  FROM $TBPR_PROTEOMICS_EXPERIMENT PE
		  JOIN $TB_USER_LOGIN UL ON (PE.contact_id=UL.contact_id)
		  JOIN $TB_PROJECT P ON (PE.project_id=P.project_id)
		 WHERE PE.record_status!='D'
		   AND UL.record_status!='D'
		   AND P.record_status!='D'
		 ORDER BY username,experiment_tag
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

1;

__END__
###############################################################################
###############################################################################
###############################################################################
