package SBEAMS::Connection::TableInfo;

###############################################################################
# Program     : SBEAMS::Connection::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which returns
#               information about various tables.
#
###############################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

# Need to include child table definitions if this program is to process those
use SBEAMS::Microarray::Tables;
use SBEAMS::Tools::Tables;
use SBEAMS::GEAP::Tables;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Inkjet::Tables;
use SBEAMS::Biosap::Tables;
use SBEAMS::PhenoArray::Tables;
use SBEAMS::SNP::Tables;
use SBEAMS::BEDB::Tables;


###############################################################################
# 
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


###############################################################################
#
# First we have table-specific overrides of the default answers
#
# This is mostly just Queries now.  This should be pushed out into a
# nicely formatted data file of queries.
#
###############################################################################
###############################################################################


###############################################################################
    if ($table_name eq "organization") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT O.organization_id,O.organization,
		       PO.organization AS 'parent_organization',
		       O.city,O.province_state,O.uri
                  FROM $TB_ORGANIZATION O
                  LEFT JOIN $TB_ORGANIZATION PO
                       ON (O.parent_organization_id = PO.organization_id)
		 WHERE O.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT *
                  FROM $TB_ORGANIZATION
		 WHERE record_status!='D'
            ~;
        }


    }


###############################################################################
    if ($table_name eq "project") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT P.project_id,P.name,UL.username,
		       SUBSTRING(P.description,1,100) AS 'description'
		  FROM $TB_PROJECT P
		  LEFT JOIN $TB_USER_LOGIN UL
		       ON (P.PI_contact_id=UL.contact_id)
		 WHERE P.record_status!='D'
		   AND UL.record_status!='D'
		 ORDER BY UL.username,P.name
            ~;

        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT P.project_id,P.name,UL.username,
		       SUBSTRING(P.description,1,100) AS 'description',
		       P.budget,P.project_status,P.uri,
		       SUBSTRING(P.comment,1,100) AS 'comment',
		       P.date_created,P.created_by_id,P.date_modified,
		       P.modified_by_id,P.owner_group_id,P.record_status
		  FROM $TB_PROJECT P
		  LEFT JOIN $TB_USER_LOGIN UL
		       ON (P.PI_contact_id=UL.contact_id)
		 WHERE P.record_status!='D'
		   AND UL.record_status!='D'
		 ORDER BY UL.username,P.name
            ~;
        }

    }


###############################################################################
    if ($table_name eq "contact") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT C.contact_id,last_name,first_name,middle_name AS 'MI',
		       CT.contact_type_name,O.organization,
		       DpO.organization AS 'deparment',
		       GrO.organization AS 'group',
		       LbO.organization AS 'lab',
                       C.phone,C.email,C.uri
                  FROM $TB_CONTACT C
                  LEFT JOIN $TB_CONTACT_TYPE CT
                       ON (C.contact_type_id=CT.contact_type_id)
                  LEFT JOIN $TB_ORGANIZATION O
                       ON (C.organization_id=O.organization_id)
                  LEFT JOIN $TB_ORGANIZATION DpO
                       ON (C.department_id=DpO.organization_id)
                  LEFT JOIN $TB_ORGANIZATION GrO
                       ON (C.group_id=GrO.organization_id)
                  LEFT JOIN $TB_ORGANIZATION LbO
                       ON (C.lab_id=LbO.organization_id)
                 WHERE C.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT C.*
                  FROM $TB_CONTACT C
                  JOIN $TB_ORGANIZATION O
                       ON (C.organization_id=O.organization_id)
                 WHERE C.record_status!='D'
		   AND O.record_status!='D'
            ~;
        }

    }


###############################################################################
    if ($table_name eq "user_work_group") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT user_work_group_id,UL.username,WG.work_group_name,
                       P.name,UWG.comment
                  FROM $TB_USER_WORK_GROUP UWG
                  LEFT JOIN $TB_USER_LOGIN UL ON ( UWG.contact_id=UL.contact_id )
                  LEFT JOIN $TB_WORK_GROUP WG ON ( UWG.work_group_id=WG.work_group_id )
                  LEFT JOIN $TB_PRIVILEGE P ON ( UWG.privilege_id=P.privilege_id )
                 WHERE UWG.record_status!='D'
                   AND UL.record_status!='D'
                   AND WG.record_status!='D'
                   AND P.record_status!='D'
                 ORDER BY UL.username,WG.work_group_name
            ~;
        }

    }




###############################################################################
    if ($table_name eq "table_group_security") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT TGS.table_group_security_id,TGS.table_group,work_group_name,P.name,TGS.comment
		  FROM $TB_TABLE_GROUP_SECURITY TGS
		  LEFT JOIN $TB_WORK_GROUP WG ON ( TGS.work_group_id=WG.work_group_id )
		  LEFT JOIN $TB_PRIVILEGE P ON ( TGS.privilege_id=P.privilege_id )
		 WHERE TGS.record_status!='D'
		   AND WG.record_status!='D'
		   AND P.record_status!='D'
		 ORDER BY TGS.table_group,work_group_name
            ~;
        }

    }



###############################################################################
###############################################################################
###############################################################################
###############################################################################





###############################################################################
  if ($info_key eq "ManageTableAllowed") {

    ($result) = $self->selectOneColumn(
      "SELECT manage_table_allowed
         FROM $TB_TABLE_PROPERTY
        WHERE table_name='$table_name'
      ");

    return $result;

  }


###############################################################################
  if ($info_key eq "CATEGORY") {

    ($result) = $self->selectOneColumn(
      "SELECT category
         FROM $TB_TABLE_PROPERTY
        WHERE table_name='$table_name'
      ");

    return $result;

  }


###############################################################################
  if ($info_key eq "DB_TABLE_NAME") {

    ($result) = $self->selectOneColumn(
      "SELECT db_table_name
         FROM $TB_TABLE_PROPERTY
        WHERE table_name='$table_name'
      ");

    #print "Content-type: text/html\n\n==$result==<BR>\n";

    # Evaluate (via interpolation) any variables within this result
    $result = eval "\"$result\"";

    return $result;

  }


###############################################################################
  if ($info_key eq "PK_COLUMN_NAME") {

    ($result) = $self->selectOneColumn(
      "SELECT PK_column_name
         FROM $TB_TABLE_PROPERTY
        WHERE table_name='$table_name'
      ");

    return $result;

  }


###############################################################################
  if ($info_key eq "MULTI_INSERT_COLUMN") {

    ($result) = $self->selectOneColumn(
      "SELECT multi_insert_column
         FROM $TB_TABLE_PROPERTY
        WHERE table_name='$table_name'
      ");

    return $result;

  }


###############################################################################
  if ($info_key eq "MENU_OPTIONS") {
    my $manage_tables;

    my $subdir = $self->getSBEAMS_SUBDIR();
    $subdir .= "/" if ($subdir);

    ($manage_tables) = $self->selectOneColumn(
      "SELECT manage_tables
         FROM $TB_TABLE_PROPERTY
        WHERE table_name='$table_name'
      ");

    my @table_array = split(",",$manage_tables);
    my @result_array;

    my $CATEGORY = $self->returnTableInfo($table_name,"CATEGORY");
    my $PROGRAM_FILE_NAME =
      $self->returnTableInfo($table_name,"PROGRAM_FILE_NAME");
    @result_array = (
	"Add $CATEGORY",
	"$CGI_BASE_DIR/$subdir$PROGRAM_FILE_NAME&ShowEntryForm=1"
    );

    my $element;
    foreach $element (@table_array) {
      $CATEGORY = $self->returnTableInfo($element,"CATEGORY");
      $PROGRAM_FILE_NAME =
        $self->returnTableInfo($element,"PROGRAM_FILE_NAME");
      push (@result_array, (
        "Manage ${CATEGORY}s",
        "$CGI_BASE_DIR/$subdir$PROGRAM_FILE_NAME"
      ));
    }

    return @result_array;

  }



###############################################################################
  if ($info_key eq "BASICQuery") {

    my $DB_TABLE_NAME = $self->returnTableInfo($table_name,"DB_TABLE_NAME");
    #print "Content-type: text/html\n\n==$table_name==$DB_TABLE_NAME==<BR>\n";

    return qq~
	SELECT *
	  FROM $DB_TABLE_NAME
	 WHERE record_status!='D'
    ~;
  }



###############################################################################
  if ($info_key eq "FULLQuery") {

    my $DB_TABLE_NAME = $self->returnTableInfo($table_name,"DB_TABLE_NAME");

    return qq~
	SELECT *
	  FROM $DB_TABLE_NAME
	 WHERE record_status!='D'
    ~;
  }



###############################################################################
  if ($info_key eq "PROGRAM_FILE_NAME") {

    ($result) = $self->selectOneColumn(
      "SELECT table_url
         FROM $TB_TABLE_PROPERTY
        WHERE table_name='$table_name'
      ");

    return $result;

  }


###############################################################################
  if ($info_key eq "QueryTypes") {

    return ("BASIC","FULL");

  }


###############################################################################
  if ($info_key eq "url_cols") {

    my $subdir = $self->getSBEAMS_SUBDIR();
    $subdir .= "/" if ($subdir);

    my %url_cols;
    my ($url,$element);
    my $PROGRAM_FILE_NAME =
      $self->returnTableInfo($table_name,"PROGRAM_FILE_NAME");
    my $PK_COLUMN_NAME =
      $self->returnTableInfo($table_name,"PK_COLUMN_NAME");

    $sql_query = qq~
	SELECT column_name,url
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$table_name'
	   AND url > ''
    ~;

    %url_cols = $self->selectTwoColumnHash($sql_query);

    foreach $element (keys %url_cols) {

      $url = $url_cols{$element};
      if ($url eq "pkDEFAULT") {
        $url_cols{$element} = "$CGI_BASE_DIR/$subdir$PROGRAM_FILE_NAME&$PK_COLUMN_NAME=%V";
      } elsif ($url eq "SELF") {
        $url_cols{$element} = "%V";
      }
    }

    return %url_cols;
  }


###############################################################################
  if ($info_key eq "ordered_columns") {

    $sql_query = qq~
	SELECT column_name
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$table_name'
	 ORDER BY column_index
    ~;

    return $self->selectOneColumn($sql_query);
  }


###############################################################################
  if ($info_key eq "required_columns") {

    $sql_query = qq~
	SELECT column_name
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$table_name'
	   AND is_required='Y'
	 ORDER BY column_index
    ~;

    return $self->selectOneColumn($sql_query);
  }


###############################################################################
  if ($info_key eq "data_columns") {

    $sql_query = qq~
	SELECT column_name
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$table_name'
	   AND is_data_column='Y'
	 ORDER BY column_index
    ~;

    return $self->selectOneColumn($sql_query);
  }


###############################################################################
  if ($info_key eq "key_columns") {

    $sql_query = qq~
	SELECT column_name
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$table_name'
	   AND is_key_field='Y'
	 ORDER BY column_index
    ~;

    return $self->selectOneColumn($sql_query);
  }



###############################################################################
  if ($info_key eq "input_types") {

    $sql_query = qq~
	SELECT column_name,input_type
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$table_name'
	   AND is_data_column='Y'
	 ORDER BY column_index
    ~;

    return $self->selectTwoColumnHash($sql_query);
  }



###############################################################################


    return 0;
}

1;

__END__
###############################################################################
###############################################################################
###############################################################################
