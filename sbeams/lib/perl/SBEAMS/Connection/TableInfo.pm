package SBEAMS::Connection::TableInfo;

###############################################################################
# Program     : SBEAMS::Connection::TableInfo
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which returns
#               information about various tables.
#
# SBEAMS is Copyright (C) 2000-2014 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use CGI::Carp qw(croak);

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Log;

# Need to include child table definitions if this program is to process those
# This should not be necessary.  FIXME
use SBEAMS::Microarray::Tables;
use SBEAMS::Proteomics::Tables;
use SBEAMS::BEDB::Tables;
use SBEAMS::BioLink::Tables;
use SBEAMS::Biosap::Tables;
use SBEAMS::Biomarker::Tables;
use SBEAMS::Cytometry::Tables;
use SBEAMS::Genotyping::Tables;
use SBEAMS::Glycopeptide::Tables;
#use SBEAMS::Imaging::Tables;
use SBEAMS::Immunostain::Tables;
use SBEAMS::Inkjet::Tables;
use SBEAMS::Interactions::Tables;
use SBEAMS::Oligo::Tables;
use SBEAMS::Ontology::Tables;
use SBEAMS::PhenoArray::Tables;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::ProteinStructure::Tables;
use SBEAMS::SIGID::Tables;
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::SNP::Tables;
use SBEAMS::Tools::Tables;

my $log = SBEAMS::Connection::Log->new();

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
		       PO.organization AS "parent_organization",
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
    if ($table_name eq "project" && $info_key =~ /FULLQuery|BASICQuery/ ) {

      my @accessible = $self->getAccessibleProjects();
      my $accProjects = join( ',', @accessible ) || 0;

      my $fields = qq~
	  	P.project_id,P.project_tag,P.name,
      CASE WHEN UL.username IS NULL 
           THEN first_name || '_' || last_name || '(No Login)' 
           ELSE UL.username END AS username,
		  SUBSTRING(P.description,1,100) AS "description"
      ~;

      if ($info_key eq "FULLQuery") {
        $fields .= qq~
        , P.budget,P.project_status,P.uri,
		    SUBSTRING(P.comment,1,100) AS "comment",
	      P.date_created,P.created_by_id,P.date_modified,
        P.modified_by_id,P.owner_group_id,P.record_status
        ~;
      }

      return qq~
	    SELECT $fields
		  FROM $TB_PROJECT P
		  INNER JOIN $TB_CONTACT C ON (P.PI_contact_id=C.contact_id)
		  LEFT JOIN $TB_USER_LOGIN UL ON (C.contact_id=UL.contact_id)
		  WHERE project_id IN ( $accProjects ) 
      AND P.record_status!='D'
	  	AND C.record_status!='D'
	  	AND ( UL.record_status!='D' OR  UL.record_status IS NULL )
      ORDER BY username,P.name
      ~;
    }


###############################################################################
    if ($table_name eq "contact") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT C.contact_id,
			C.last_name AS "Last_Name",
			C.first_name AS "First_Name",
			C.middle_name AS "MI",
                       	C.location AS "Location",
		       	DpO.organization AS "Deparment",
		       	GrO.organization AS "Group",
		       	LbO.organization AS "Lab",
		       	O.organization AS "Organization",
			CT.contact_type_name AS "Contact_Type",
			C.job_title AS "Job_Title",
                       	C.phone_extension AS "Phone_Ext",
			C.uri AS "uri"
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
                  LEFT JOIN $TB_CONTACT SV
                       ON (C.supervisor_contact_id=SV.contact_id)
                 WHERE C.record_status!='D'
            ~;
        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT C.*
                  FROM $TB_CONTACT C
                 INNER JOIN $TB_ORGANIZATION O
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
    if ($table_name eq "group_project_permission") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT GPP.group_project_permission_id,WG.work_group_name,
                       UL.username||' - '||PROJ.name AS "Project",PRIV.name,GPP.comment
                  FROM $TB_GROUP_PROJECT_PERMISSION GPP
                  LEFT JOIN $TB_PROJECT PROJ ON ( GPP.project_id=PROJ.project_id )
                  LEFT JOIN $TB_USER_LOGIN UL ON ( PROJ.PI_contact_id=UL.contact_id )
                  LEFT JOIN $TB_WORK_GROUP WG ON ( GPP.work_group_id=WG.work_group_id )
                  LEFT JOIN $TB_PRIVILEGE PRIV ON ( GPP.privilege_id=PRIV.privilege_id )
                 WHERE GPP.record_status!='D'
                   AND PROJ.record_status!='D'
                   AND UL.record_status!='D'
                   AND WG.record_status!='D'
                   AND PRIV.record_status!='D'
                 ORDER BY Project,PROJ.name
            ~;
        }

    }


###############################################################################
    if ($table_name eq "user_project_permission") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT UPP.user_project_permission_id,
                       PUL.username||' - '||PROJ.name AS "Project",UL.username,PRIV.name,UPP.comment
                  FROM $TB_USER_PROJECT_PERMISSION UPP
                  LEFT JOIN $TB_PROJECT PROJ ON ( UPP.project_id = PROJ.project_id )
                  LEFT JOIN $TB_USER_LOGIN PUL ON ( PROJ.PI_contact_id = PUL.contact_id )
                  LEFT JOIN $TB_USER_LOGIN UL ON ( UPP.contact_id = UL.contact_id )
                  LEFT JOIN $TB_PRIVILEGE PRIV ON ( UPP.privilege_id = PRIV.privilege_id )
                 WHERE UPP.record_status!='D'
                   AND PROJ.record_status!='D'
                   AND PUL.record_status!='D'
                   AND UL.record_status!='D'
                   AND PRIV.record_status!='D'
                 ORDER BY UL.username,PROJ.name
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
    if ($table_name eq "cached_resultset") {
        my $current_contact_id = $self->getCurrent_contact_id();

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT CR.cached_resultset_id,username,CR.date_created,
		       CR.query_name,CR.resultset_name,CR.cache_descriptor
		  FROM $TB_CACHED_RESULTSET CR
		 INNER JOIN $TB_USER_LOGIN UL
                       ON ( CR.contact_id = UL.contact_id )
		 WHERE CR.record_status!='D'
		   AND UL.record_status!='D'
		   AND CR.contact_id = '$current_contact_id'
		 ORDER BY CR.date_created DESC,CR.resultset_name
            ~;
        }

    }


###############################################################################
    if ($table_name eq "protocol") {

        if ($info_key eq "BASICQuery") {
            return qq~
		SELECT P.protocol_id,PT.name AS 'protocol_type',P.other_type,
                       P.name AS 'protocol_name',
                       P.date_created,P.created_by_id,P.date_modified,
		       P.modified_by_id,P.owner_group_id,P.record_status
		  FROM $TB_PROTOCOL P
		 INNER JOIN $TB_PROTOCOL_TYPE PT
                       ON ( P.protocol_type_id = PT.protocol_type_id )
		 WHERE P.record_status!='D'
		   AND PT.record_status!='D'
		 ORDER BY protocol_type,protocol_name
            ~;

        }

        if ($info_key eq "FULLQuery") {
            return qq~
		SELECT P.protocol_id,PT.name AS 'protocol_type',P.other_type,
                       P.name AS 'protocol_name',
		       SUBSTRING(P.abstract,1,100) AS 'abstract',
		       SUBSTRING(protocol,1,100) AS 'protocol',
		       SUBSTRING(P.comment,1,100) AS 'comment',
		       P.date_created,P.created_by_id,P.date_modified,
		       P.modified_by_id,P.owner_group_id,P.record_status
		  FROM $TB_PROTOCOL P
		  LEFT JOIN $TB_PROTOCOL_TYPE PT
		       ON (P.protocol_type_id=PT.protocol_type_id)
		 WHERE P.record_status!='D'
		   AND PT.record_status!='D'
		 ORDER BY PT.name,P.name
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

    my $sql =<<"    END";
    SELECT manage_tables
    FROM $TB_TABLE_PROPERTY
    WHERE table_name='$table_name'
    END
    ($manage_tables) = $self->selectOneColumn( $sql );

    my @table_array = split(",",$manage_tables);
    my @result_array;

    my $CATEGORY = $self->returnTableInfo($table_name,"CATEGORY");
    my $PROGRAM_FILE_NAME =
      $self->returnTableInfo($table_name,"PROGRAM_FILE_NAME");

    @result_array = (
          "Add $CATEGORY",
         	"$CGI_BASE_DIR/$subdir$PROGRAM_FILE_NAME&ShowEntryForm=1"
    ) if $CATEGORY && $PROGRAM_FILE_NAME; # added 2008-03, fixes phantom linx

    my $element;
    foreach $element (@table_array) {
      $CATEGORY = $self->returnTableInfo($element,"CATEGORY");
      $PROGRAM_FILE_NAME =
        $self->returnTableInfo($element,"PROGRAM_FILE_NAME");
      $CATEGORY .= 's' unless $CATEGORY =~ /s$/; # 2008-3, don't add 2nd 's'
      push (@result_array, (
        "Manage $CATEGORY",
        "$CGI_BASE_DIR/$subdir$PROGRAM_FILE_NAME") 
      ) if $CATEGORY && $PROGRAM_FILE_NAME; # added 2008-03, fixes phantom linx
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
        $url_cols{$element} = "$CGI_BASE_DIR/$subdir$PROGRAM_FILE_NAME&".
          "$PK_COLUMN_NAME=%V";
      } elsif ($url eq "uploaded_file") {
        $url_cols{$element} = "$CGI_BASE_DIR/$subdir$PROGRAM_FILE_NAME&".
          "$PK_COLUMN_NAME=%0V&GetFile=%K";
      } elsif ($url eq "SELF") {
        $url_cols{$element} = "%V";
      }
    }


    if ($table_name eq "cached_resultset") {
      $url_cols{cache_descriptor} = "$CGI_BASE_DIR/%3V?apply_action=VIEWRESULTSET&rs_set_name=%5V";
    }


    if ($table_name eq "user_work_group") {
      $url_cols{username} = "$CGI_BASE_DIR/$subdir/ManageTable.cgi?TABLE_NAME=user_work_group&where_clause=username+like+'%V'";
    }



    #### Put in some fixed URLs for audit trail columns
    $url_cols{created_by_id} = "$CGI_BASE_DIR/$subdir/ManageTable.cgi?".
          "TABLE_NAME=contact&contact_id=%V";
    $url_cols{modified_by_id} = "$CGI_BASE_DIR/$subdir/ManageTable.cgi?".
          "TABLE_NAME=contact&contact_id=%V";
    $url_cols{owner_group_id} = "$CGI_BASE_DIR/$subdir/ManageTable.cgi?".
          "TABLE_NAME=work_group&work_group_id=%V";


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
  if ($info_key eq "fk_tables") {

    $sql_query = qq~
	SELECT column_name,fk_table
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$table_name'
	   AND is_data_column='Y'
	 ORDER BY column_index
    ~;

    return $self->selectTwoColumnHash($sql_query);
  }



###############################################################################
  if ($info_key eq "data_types") {

    $sql_query = qq~
	SELECT column_name,data_type
	  FROM $TB_TABLE_COLUMN
	 WHERE table_name='$table_name'
	   AND is_data_column='Y'
	 ORDER BY column_index
    ~;

    return $self->selectTwoColumnHash($sql_query);
  }



###############################################################################
  if ($info_key eq "data_scales") {

    $sql_query = qq~
	SELECT column_name,data_scale
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


###############################################################################
# getGroupList
#
# returns list of groups for current module in order of ascending permissions.
# Used to grant minimum allowable access when doing automatic group switching 
# based on an attempt to access a disallowed resource.
###############################################################################
sub getGroupList {
  my $self = shift;
  my @groups = selectSeveralColumns( <<"  END" );
  SELECT work_group_name, work_group_id
  FROM work_group
  WHERE work_group_name IN ( 'guest', 'developer', 'other', 'admin' )
  END
  
  my %grps;
  for( @groups ) {
  $grps{$_->[0]} = $_->[1];
  }
  return( [ $grps{guest}, $grps{other}, $grps{developer} ] ); # skip admin
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


  #### Make sure action is one of INSERT,UPDATE,DELETE, or SELECT
  unless ($action =~ /^INSERT$|^UPDATE$|^DELETE$|^SELECT$/) {
    die("ERROR: $SUB_NAME: action must be one of INSERT,UPDATE,DELETE, or SELECT");
  }

  #### Get sbeams object, we'll need it for queries
  #my $sbeams = $self->getSBEAMS();

  #### Define the project_id, starting as undef, it gets filled if there is one
  my $project_id;


  #############################################################################
  #### Process actions for individual tables

  #### If table is project
  if ($table_name eq "project") {

    ### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      #### There is none yet!

    #### Else for UPDATE, DELETE or SELECT, determine how it fits into project
    } elsif ( $action =~ /^UPDATE$|^DELETE$|^SELECT$/ ) {
      #### The parent is me!
      $project_id = $parameters_ref->{project_id};
    }

    return($project_id);
  }


  #### If table is project_file
  if ($table_name eq "project_file") {

    ### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {
      $project_id = $parameters_ref->{project_id};

    #### Else for UPDATE, DELETE or SELECT, determine how it fits into project
    } elsif ( $action =~ /^UPDATE$|^DELETE$|^SELECT$/ ) {
      #### Should some combination of the previous and possibly new project FIXME
      $project_id = $parameters_ref->{project_id};
    }

    return($project_id);
  }


  #### If table is xxxx
  if ($table_name eq "xxxx") {

    #### If the user wants to INSERT, determine how it fits into project
    if ($action eq 'INSERT') {

    #### Else for an UPDATE or DELETE, determine how it fits into project
    } elsif ($action eq 'UPDATE' || $action eq 'DELETE') {

    }

    return($project_id);
  }


  #### No information for this table so return undef
  return;

}

###########################################################################
# Routine returns and HTML table with information and links
# that pertain to a given project
#
#  narg      project_id   The ID of the project to be displayed.  Required
#
#  ret       scalar with HTML block as a string.
###########################################################################
sub getProjectDetailsTable {
  my $self = shift;
  my %args  = @_;

  # Must...have...project_id
  unless ( $args{project_id} ) {
    die ( "Missing required parameter project_id" );
  }
  
  my @rows = $self->selectSeveralColumns( <<"  END_SQL" );
  SELECT project_id, project_status, project_tag, description,
         first_name || ' ' || last_name AS PI_name, name 
  FROM $TB_PROJECT p JOIN $TB_CONTACT c
  ON c.contact_id = p.PI_contact_id
  WHERE project_id = $args{project_id}
  END_SQL

  if( !scalar( @rows ) ) { # Can't find it.  Log error and return undef
    print STDERR "Unable to get details for $args{project_id}\n";
    return undef;
  }
    
  my ( $project_id, $project_status, $project_tag, $proj_desc, $PI_name, $project_name ) = @{$rows[0]};

  my $table =<<"  END_TAB";
	<H1>Summary of <FONT color="red">$project_name</font>
  </H1>
  <TABLE WIDTH="100%" BORDER=0>
	<TR>
    <TD></TD>
    <TD COLSPAN="2"><A HREF="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=project&project_id=$project_id">[View/Edit Full Project Information]</A></TD>
  </TR>

	<TR>
    <TD></TD>
    <TD COLSPAN="2"><B>PI:</B> $PI_name</TD>
  </TR>

	<TR>
    <TD><IMG SRC="$HTML_BASE_DIR/images/space.gif" WIDTH="20" HEIGHT="1"></TD>
	  <TD COLSPAN="2" WIDTH="100%"><B>Status:</B> $project_status</TD></TR>
	<TR>
    <TD></TD>
    <TD COLSPAN="2"><B>Project Tag:</B> $project_tag  (ID $project_id)</TD>
  </TR>
	<TR>
    <TD></TD>
    <TD COLSPAN="2"><B>Description:</B> $proj_desc</TD>
  </TR>
  <PRE_PRIVILEGES_HOOK>
	<TR>
    <TD></TD>
    <TD COLSPAN="2"><B>Access Privileges:</B> <A HREF="$CGI_BASE_DIR/ManageProjectPrivileges">[View/Edit]</A>
    </TD>
  </TR>
  <POST_PRIVILEGES_HOOK>
  </TABLE>
  <BR>
  END_TAB

  return $table;

} # End getProjectDetailsTable

#+
# 'Official' sbeams evalSQL method
#-
sub evalSQL {
  my $self = shift;
  my $sql = shift;
	my $post;
	{
    $post = eval "\"$sql\"";
	};
	if ( $@ ) { $log->error( "Error in evalSQL: $@" ) }
	return $post;
}

#+
# Returns reference to a list of tables that this module knows about.
#-
sub get_info_tables {
  return [qw(organization project contact user_work_group protocol
             group_project_permission user_project_permission
             table_group_security cached_resultset )
         ];
}

#+
# Returns reference to a list of info_keys that this module knows about.
#-
sub get_info_keys {
  return [ qw( ManageTableAllowed CATEGORY DB_TABLE_NAME PK_COLUMN_NAME
               fk_tables MULTI_INSERT_COLUMN MENU_OPTIONS BASICQuery
               FULLQuery PROGRAM_FILE_NAME QueryTypes url_cols ordered_columns
               required_columns data_columns key_columns input_types
               data_types data_scales)
         ];
}

#+
# Method to fetch contact_id for guest user
#-
sub get_guest_contact_id {
  my $self = shift;
  my ( $id ) = $self->selectrow_array( <<"  END" );
  SELECT contact_id FROM $TB_USER_LOGIN where 
  username = 'guest'
  END
  return $id;
}

#+
# Method to fetch organism_id and name
#-
sub get_organism_hash {
  my $self = shift;
  my %args = ( key => 'organism_id', @_ );

  my $sql = qq~
  SELECT organism_id, organism_name
  FROM $TB_ORGANISM where 
  record_status = 'N'
  ~;
  my $sth = $self->get_statement_handle( $sql );

  my %name2id;
  my %id2name;
  while ( my @row = $sth->fetchrow_array() ) {
    $name2id{$row[1]} = $row[0];
    $id2name{$row[0]} = $row[1];
  }
  return \%id2name if $args{key} eq 'organism_id';
  return \%name2id;
}

#+
# Method to fetch organism_id from database from provided name
#-
sub get_organism_id {
  my $self = shift;
  my %args = @_;
  return unless $args{organism};
  my ( $id ) = $self->selectrow_array( <<"  END" );
  SELECT organism_id FROM $TB_ORGANISM where 
  organism_name = '$args{organism}'
  END
  return $id;
}

#+
# Method to construct SQL to fetch a record from a generic SBEAMS table
#
# @narg table_name    module-qualified table name, i.e. MA_affy_array, REQUIRED
# @narg module_prefix module db_table_name prefix, i.e. $TBPR, REQUIRED
# @narg object_id     Build SQL including explicit object_id, else placeholder
# @narg skip_status   Omit clause limiting return to record_status <> D
#
#-
sub get_object_SQL {
  my $self = shift;
  my %args = @_;

  for my $key ( qw(table_name module_prefix) ) {
    return unless $args{$key};
  }

  my $pk_value = ( defined $args{object_id} ) ? $args{object_id} : 'OBJECT_ID';

  # Figure out primary key, table name, and if it has audit cols
  my @row = $self->selectrow_array( <<"  END" );
  SELECT db_table_name, PK_column_name, 
  (SELECT COUNT(*) FROM $TB_TABLE_COLUMN TC 
      WHERE TP.table_name = TC.table_name 
      AND column_name = 'RECORD_STATUS') AS has_audit
  FROM $TB_TABLE_PROPERTY TP 
  WHERE db_table_name LIKE '$args{module_prefix}%'
  AND TP.table_name = '$args{table_name}';
  END

  my $sql =<<"  END";
  SELECT * 
  FROM $row[0]
  WHERE $row[1] = $pk_value
  END
  unless ( $args{skip_status} ) {
    $sql .= "AND record_status <> 'D'" if $row[2];
  }
  return $self->evalSQL( $sql );
}



###############################################################################
1;

__END__

###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::TableInfo

SBEAMS Core table information methods

=head2 SYNOPSIS

See SBEAMS::Connection for usage synopsis.

=head2 DESCRIPTION

This module is really kind of old and krusty and probably ought to be
redesigned.  It provides a number of methods for getting properties of
tables, principally for use by ManageTable


=head2 METHODS

=over

=item * B<returnTableInfo($table_name,$info_key)>

This method returns the type of information provided in $info_key for
the table (or query) provided in $table_name.


=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

