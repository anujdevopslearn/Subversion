package SBEAMS::Connection::Permissions;

###############################################################################
# Program     : SBEAMS::Connection::Permissions
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which contains
#               methods regarding project permissions.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw(@ERRORS $q
           );
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Inkjet::Tables;
use SBEAMS::Connection::Tables;

# Constants that represent access levels
use constant DATA_NONE => 50;
use constant DATA_READER => 40;
use constant DATA_WRITER => 30;
use constant DATA_GROUP_MOD => 25;
use constant DATA_MODIFIER => 20;
use constant DATA_ADMIN => 10;

$q       = new CGI;

###############################################################################
# print_permissions_table
#
# arguments:
# -parameters_ref
# -no_permissions  --> does not execute 'printUserContext'
###############################################################################
sub print_permissions_table {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "print_permissions_table";
  

  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $self->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$self->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $self->processStandardParameters(parameters_ref=>\%parameters);

  ## Decode argument list
#  my $ref_parameters = $args{'ref_parameters'};
#  my %parameters;
#  if ($ref_parameters) {%parameters = %{$ref_parameters}; }
  
  ## Define standard variables
  my ($sql, @rows);
  my $alter_permission;
  my ($current_contact_id, $current_project_id, $current_group_id,$project_name);
  my ($permission, $permission_to_alter);


  #### Draw the page
  if ($parameters{'userPermissions'}){
      $self->update_user_permissions(ref_parameters=>\%parameters);
  }
  if ($parameters{'groupPermissions'}){
      $self->update_group_permissions(ref_parameters=>\%parameters);

  }


  #### Show current user context information
  unless ($args{'no_permissions'}) {
    $self->printUserContext();
  };
  $project_name = $self->getCurrent_project_name;

  print qq~
      <H1>Privileges for $project_name</H1>
      $LINESEPARATOR
      ~;
  
  $permission = $self->get_best_permission();

  ## SQL to get administrator privilege ID
  $sql = qq~
      SELECT PRIV.privilege_id
      FROM $TB_PRIVILEGE PRIV
      WHERE PRIV.name = 'administrator'
      AND record_status != 'D'
      ~;
  @rows = $self->selectOneColumn($sql);
  my $cutoff = $rows[0];

  ## Grant permission to alter if best priv is administrator level
  if ($permission <= $cutoff){ $permission_to_alter = 1; }
  else { $permission_to_alter = 0; }

  $self->print_user_permissions(permission_to_alter=>$permission_to_alter);

  $self->print_group_permissions(permission_to_alter=>$permission_to_alter);

  return;
}


###############################################################################
# update_user_permissions
###############################################################################
sub update_user_permissions {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "update_user_permission";

  ## Decode argument list
  my $ref_parameters = $args{'ref_parameters'};
  my %parameters;
  if ($ref_parameters) {%parameters = %{$ref_parameters}; }

  ## Define standard variables
  my ($sql,@rows);
  my ($counter,$current_project_id,$priv_chooser,$user_chooser);

  $current_project_id = $self->getCurrent_project_id;
  $priv_chooser = "userPriv";
  $user_chooser = "userName";
  $counter = 0;
  my $test_string = $priv_chooser.$counter;

  while($parameters{$test_string}){
    my (%rowdata, $rowdata_ref);
		my $temp_user = $user_chooser.$counter;
		my $temp_priv = $priv_chooser.$counter;
		my $user_id = $parameters{$temp_user};
		my $priv_id = $parameters{$temp_priv};

		#set up for next go around
		$counter++;
		$test_string = $priv_chooser.$counter;
		next if ($user_id == '-1');

		# Test to see if the user already has assigned privileges
		# If the permissions are to be updated, then update
		# If the permissions are to be deleted, then delete
		$sql = qq~
				SELECT UPP.user_project_permission_id
				FROM $TB_USER_PROJECT_PERMISSION UPP
				LEFT JOIN $TB_PROJECT P ON (P.project_id = UPP.project_id)
				WHERE UPP.contact_id = $user_id
				AND P.project_id = $current_project_id
				~;
		@rows = $self->selectOneColumn($sql);

		if (@rows){
			if ($priv_id ne "-1"){
				$rowdata{'privilege_id'} = $priv_id;
				$rowdata{'record_status'} = 'N';
				$rowdata_ref= \%rowdata;
				$self->updateOrInsertRow(table_name=>$TB_USER_PROJECT_PERMISSION,
																 rowdata_ref=>$rowdata_ref,
																 update=>1,
																 PK_name=>'user_project_permission_id',
																 PK_value=>$rows[0],
																 add_audit_parameters=>1);
		  }else{
				$rowdata{'record_status'} = 'D';
				$rowdata_ref = \%rowdata;
				$self->updateOrInsertRow(table_name=>$TB_USER_PROJECT_PERMISSION,
																 rowdata_ref=>$rowdata_ref,
																 update=>1,
																 PK_name=>'user_project_permission_id',
																 PK_value=>$rows[0],
																 add_audit_parameters=>1);
			}
	  }else {
			$rowdata{'contact_id'}   = $user_id;
			$rowdata{'project_id'}   = $current_project_id;
			$rowdata{'privilege_id'} = $priv_id;
			$rowdata_ref = \%rowdata;
			$self->updateOrInsertRow(table_name=>$TB_USER_PROJECT_PERMISSION,
															 rowdata_ref=>$rowdata_ref,
															 insert=>1,
															 PK_name=>'user_project_permission_id',
															 add_audit_parameters=>1);
	  }
  }
}

###############################################################################
# update_group_permissions
###############################################################################
sub update_group_permissions {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "update_group_permission";

  ## Decode argument list
  my $ref_parameters = $args{'ref_parameters'};
  my %parameters;
  if ($ref_parameters) {%parameters = %{$ref_parameters}; }

  ## Define standard variables
  my ($sql,@rows);
  my ($counter,$current_project_id,$current_work_group_id);
  my ($priv_chooser,$group_chooser);

  $current_project_id = $self->getCurrent_project_id;
  $current_work_group_id = $self->getCurrent_work_group_id;

  $priv_chooser = "groupPriv";
  $group_chooser = "groupName";
  $counter = 0;
  my $test_string = $priv_chooser.$counter;

  while($parameters{$test_string}){
    my (%rowdata, $rowdata_ref);
		my $temp_group = $group_chooser.$counter;
		my $temp_priv = $priv_chooser.$counter;
		my $group_id = $parameters{$temp_group};
		my $priv_id = $parameters{$temp_priv};

		#set up for next go around
		$counter++;
		$test_string = $priv_chooser.$counter;
		next if ($group_id == '-1');

		#test to see if the user already has assigned privileges
		$sql = qq~
				SELECT GPP.group_project_permission_id
				FROM $TB_GROUP_PROJECT_PERMISSION GPP
				WHERE GPP.project_id = '$current_project_id'
				AND GPP.work_group_id = '$group_id'
				~;
		@rows = $self->selectOneColumn($sql);

		if (@rows){
			if ($priv_id ne "-1"){
				$rowdata{'privilege_id'} = $priv_id;
				$rowdata{'record_status'} = 'N';
				$rowdata_ref= \%rowdata;
				$self->updateOrInsertRow(table_name=>$TB_GROUP_PROJECT_PERMISSION,
																 rowdata_ref=>$rowdata_ref,
																 update=>1,
																 PK_name=>'group_project_permission_id',
																 PK_value=>$rows[0],
																 add_audit_parameters=>1);
		  }else{
				$rowdata{'record_status'} = 'D';
				$rowdata_ref = \%rowdata;
				$self->updateOrInsertRow(table_name=>$TB_GROUP_PROJECT_PERMISSION,
																 rowdata_ref=>$rowdata_ref,
																 update=>1,
																 PK_name=>'group_project_permission_id',
																 PK_value=>$rows[0],
																 add_audit_parameters=>1);
		  }
	  }else {
			$rowdata{'work_group_id'}   = $group_id;
			$rowdata{'project_id'}   = $current_project_id;
			$rowdata{'privilege_id'} = $priv_id;
			$rowdata_ref = \%rowdata;
			$self->updateOrInsertRow(table_name=>$TB_GROUP_PROJECT_PERMISSION,
															 rowdata_ref=>$rowdata_ref,
															 insert=>1,
															 PK_name=>'group_project_permission_id',
															 add_audit_parameters=>1);
	  }
  }
}


###############################################################################
# print_user_permissions
###############################################################################
sub print_user_permissions {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "print_user_permissions";

  ## Decode argument list
  my $current_project_id = $self->getCurrent_project_id();
  my $current_contact_id = $self->getCurrent_contact_id();
  my $current_group_id   = $self->getCurrent_work_group_id();
  my $permission_to_alter = $args{'permission_to_alter'} || 0;

  ## Define standard variables
  my ($sql, $priv_sql, $user_sql, $pi_sql, @rows);
  my (@users, @permissions);
  my (%rowdata, $rowdata_ref);
  my ($proj_pi_id, $proj_pi_name);

  # SQL for all privileges
  $priv_sql = qq~
      SELECT PRIV.name, PRIV.privilege_id
      FROM $TB_PRIVILEGE PRIV
      WHERE record_status != 'D'
      ~;

  # SQL for getting project pi
  $pi_sql = qq~
      SELECT P.PI_contact_id, UL.username
      FROM $TB_PROJECT P
      LEFT JOIN $TB_USER_LOGIN UL ON (UL.contact_id = P.PI_contact_id)
      WHERE P.project_id = '$current_project_id'
      AND P.record_status != 'D'
      ~;
  @rows = $self->selectSeveralColumns($pi_sql);
  ($proj_pi_id, $proj_pi_name) = @{$rows[0]};

  # SQL for all users except current user
  $user_sql = qq~
      SELECT UL.username, UL.contact_id
      FROM $TB_USER_LOGIN UL
      WHERE record_status != 'D'
      AND UL.contact_id != '$proj_pi_id'
      ORDER BY UL.username
      ~;

  #### Get project permissions (minus the project owner)# 
  $sql = qq~
      SELECT UL.username,UL.contact_id, UPP.privilege_id 
      FROM $TB_USER_LOGIN UL
      LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP ON (UPP.contact_id = UL.contact_id)
      LEFT JOIN $TB_PROJECT P ON (P.project_id = UPP.project_id)
      LEFT JOIN $TB_PRIVILEGE PRIV ON (PRIV.privilege_id = UPP.privilege_id)
      WHERE UPP.project_id = '$current_project_id'
			AND UPP.record_status != 'D'
			AND PRIV.record_status != 'D'
			AND UL.record_status != 'D'
      AND UL.contact_id != P.PI_contact_id
			ORDER BY UL.username
      ~;
	#print "\n$sql\n";

  @rows = $self->selectSeveralColumns($sql);

  ## Start permissions table
  print qq~
      <FORM NAME="userPermissions" METHOD="POST">
      <TABLE>
      <TR>
        <TD><FONT COLOR="red"><B>User</B></FONT></TD>
	<TD><FONT COLOR="red"><B>Privilege</B></FONT></TD>
      </TR>
      <TR>
        <TD><B>$proj_pi_name</B></TD>
	<TD><B>administrator (project PI)</B></TD>
      </TR>
      ~;
  ## Print known users/privileges
  ## Also see if current contact has permission to alter
  my ($counter, $chooser_name);
  $counter = 0;
  foreach my $row_ref (@rows) {
      my @row = @{$row_ref};

      print qq~
      <TR>
        <TD>
	~;
      $chooser_name = "userName".$counter;
      $self->print_chooser(sql=>$user_sql,
			   selected_id=>$row[1],
			   input_name=>$chooser_name);
      print qq~
	</TD>
	<TD>
      ~;
      $chooser_name = "userPriv".$counter;
      $self->print_chooser(sql=>$priv_sql,
			   selected_id=>$row[2],
			   input_name=>$chooser_name);
      print qq~
	</TD>
      </TR>
      ~;
      $counter++;
  }

  ## Print new user row
  print qq~
      <TR>
        <TD>
  ~;
  $chooser_name = "userName".$counter;
  $self->print_chooser(sql=>$user_sql,
											 blank_chooser=>1,
											 input_name=>$chooser_name);
  print qq~
        </TD>
	<TD>
  ~;
  $chooser_name = "userPriv".$counter;
  $self->print_chooser(sql=>$priv_sql, 
											 blank_chooser=>1,
											 input_name=>$chooser_name);
  print qq~
        </TD>
      </TR>
  ~;

  ## End table
  print qq~
      </TABLE>
      ~;
  if ($permission_to_alter==1){
      print qq~
      <INPUT TYPE="hidden" Name="tab" VALUE="permissions">
      <INPUT TYPE="submit" NAME="userPermissions" VALUE="Update!">
      </FORM>
      ~;
  }else {
      print qq~
      <H3>You need 'administrator' privileges to make changes.</H3>
      <H3>Contact <A HREF="mailto:$proj_pi_name\@systemsbiology.org">$proj_pi_name</A> or another administrator to obtain access.</H3>
      </FORM>
      ~;
  }


}


###############################################################################
# print_group_permissions
###############################################################################
sub print_group_permissions {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "print_user_permissions";

  ## Decode argument list
  my $ref_parameters = $args{'ref_parameters'};
  my $current_project_id = $self->getCurrent_project_id();
  my $current_contact_id = $self->getCurrent_contact_id();
  my $current_group_id   = $self->getCurrent_work_group_id();
  my $best_permission = $args{'best_permission'};
  my $permission_to_alter = $args{'permission_to_alter'} || 0;

  ## Define standard variables
  my ($sql, $priv_sql, $group_sql, $current_permissions_sql,@rows);

  # SQL to get current group permissions
  $current_permissions_sql = qq~
      SELECT WG.work_group_id, PRIV.privilege_id
      FROM $TB_WORK_GROUP WG
      LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP ON (GPP.work_group_id = WG.work_group_id)
      LEFT JOIN $TB_PRIVILEGE PRIV ON (PRIV.privilege_id = GPP.privilege_id)
      LEFT JOIN $TB_PROJECT P ON (P.project_id = GPP.project_id)
      WHERE P.project_id = '$current_project_id'
      AND WG.work_group_name != 'Admin'
			AND GPP.record_status != 'D'
      AND WG.record_status != 'D'
      AND PRIV.record_status != 'D'
			ORDER BY WG.work_group_name
      ~;

  # SQL for all privileges
  $priv_sql = qq~
      SELECT PRIV.name, PRIV.privilege_id
      FROM $TB_PRIVILEGE PRIV
      WHERE PRIV.record_status != 'D'
      ~;

  # SQL for all work groups except Admin 
  $group_sql = qq~
      SELECT  WG.work_group_name, WG.work_group_id 
      FROM $TB_WORK_GROUP WG
      WHERE WG.record_status != 'D'
      AND WG.work_group_name != 'Admin'
			ORDER BY WG.work_group_name
      ~;


  ## Start permissions table
  print qq~
      <FORM NAME="groupPermissions" METHOD="POST">
      <TABLE>
      <TR>
        <TD><FONT COLOR="red"><B>Group</B></FONT></TD>
	<TD><FONT COLOR="red"><B>Privilege</B></FONT></TD>
      </TR>
      ~;

  ##Print known work groups/privileges
  @rows = $self->selectSeveralColumns($current_permissions_sql);
  my ($counter, $chooser_name);
  $counter = 0;
  foreach my $row_ref (@rows) {
      my @row = @{$row_ref};

      print qq~
      <TR>
        <TD>
	~;
      $chooser_name = "groupName".$counter;
      $self->print_chooser(sql=>$group_sql,
		    selected_id=>$row[0],
		    input_name=>$chooser_name);
      print qq~
	</TD>
	<TD>
      ~;
      $chooser_name = "groupPriv".$counter;
      $self->print_chooser(sql=>$priv_sql,
		    selected_id=>$row[1],
		    input_name=>$chooser_name);
      print qq~
	</TD>
      </TR>
      ~;
      $counter++;
  }

  ## Print new user row
  print qq~
      <TR>
        <TD>
  ~;
  $chooser_name = "groupName".$counter;
  $self->print_chooser(sql=>$group_sql,
		       blank_chooser=>1,
		       input_name=>$chooser_name);
  print qq~
        </TD>
	<TD>
  ~;
  $chooser_name = "groupPriv".$counter;
  $self->print_chooser(sql=>$priv_sql, 
		       blank_chooser=>1,
		       input_name=>$chooser_name);
  print qq~
        </TD>
      </TR>
  ~;

  ## End table
  print qq~
      </TABLE>
      ~;
  if ($permission_to_alter==1){
      print qq~
      <INPUT TYPE="hidden" Name="tab" VALUE="permissions">
      <INPUT TYPE="submit" NAME="groupPermissions" VALUE="Update!">
      </FORM>
      ~;
  }else {
      print qq~
      <h3>You need 'administrator' rights to make changes</h3>
      </FORM>
      ~;
  }
  
}

################################
# print_chooser
################################
sub print_chooser {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "print_chooser";

  ## Decode argument list
  my $selected_id     = $args{'selected_id'};
  my $input_name      = $args{'input_name'} || "";
  my $selected_name   = $args{'selected_name'};
  my $omitted_ids_ref = $args{'omitted_ids'}; 
  my $blank_chooser   = $args{'blank_chooser'};
  my $sql             = $args{'sql'};
  my $row_ref         = $args{'sql_results_ref'};
 
  ## Define standard variables
  my @rows;
  my %omitted_ids;
  if ($omitted_ids_ref){
      %omitted_ids = %{$omitted_ids_ref};
  }
 
  ## Get results if SQL is passed
  if ($sql){
      @rows = $self->selectSeveralColumns($sql);
  }elsif ($row_ref) {
      @rows = @{$row_ref};
  }else{
      die "ERROR[$SUB_NAME]:Neither SQL nor SQL results passed\n";
  }

  ## Start SELECT
  print qq~
      <SELECT NAME="$input_name">
      ~;

  ## Print OPTIONs
  if ($blank_chooser){
      print qq~
	  <OPTION VALUE="-1" SELECTED>
	  ~;
  }else {
      print qq~
	  <OPTION VALUE="-1">
	  ~;
  }
  foreach my $row_ref(@rows){
      my @row = @{$row_ref};
      next if (defined($omitted_ids{$row[1]}));
      if ($row[1] == $selected_id || $row[0] eq $selected_name){
	  print qq~
	  <OPTION VALUE=\"$row[1]\" SELECTED>$row[0]
	  ~;
      }else {
	  print qq~
	  <OPTION VALUE=\"$row[1]\">$row[0]
	  ~;
      }
  }

  ## End SELECT
  print qq~
      </SELECT>
      ~;
  return;
}

###############################################################################
# get_best_permission
###############################################################################
sub get_best_permission{
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "find_best_permission";

  ## Decode argument list
  my $current_contact_id = $args{'contact_id'}
  || $self->getCurrent_contact_id;
  my $current_project_id = $args{'project_id'}
  || $self->getCurrent_project_id;
  my $current_group_id = $args{'group_id'}
  || $self->getCurrent_work_group_id;

  ## Define standard variables
  my ($sql, @rows);
  my ($project_pi,$administrator_privilege_id, $admin_work_group_id);

  ## Set $administrator_privilege_id
  $sql = qq~
      SELECT PRIV.privilege_id
      FROM $TB_PRIVILEGE PRIV
      WHERE PRIV.name = 'administrator'
      ~;
  @rows = $self->selectOneColumn($sql);
  $administrator_privilege_id = $rows[0];

  ## Set $admin_work_group_id
  $sql = qq~
      SELECT WG.work_group_id
      FROM $TB_WORK_GROUP WG
      WHERE WG.work_group_name = 'Admin'
      ~;
  @rows = $self->selectOneColumn($sql);
  $admin_work_group_id = $rows[0];

  ## SQL to find project_PI
  $sql = qq~
      SELECT P.PI_contact_id 
      FROM $TB_PROJECT P
      WHERE P.project_id = $current_project_id
      AND P.record_status != 'D'
      ~;
  @rows = $self->selectOneColumn($sql);
  $project_pi = $rows[0];

  ## If contact_id is the PI, automatically return 'adminstrator' privileges
  if ($project_pi == $current_contact_id){
      return $administrator_privilege_id;
  }

  ## If work group is set to Admin, automatically return 'administrator' privileges
  if ($admin_work_group_id == $current_group_id){
      return $administrator_privilege_id;
  }

  ## Else find best privilege available
  $sql = qq~
      SELECT UL.username,
      MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL ELSE GPP.privilege_id END) AS "best_group_privilege_id",
      MIN(UPP.privilege_id) AS "best_user_privilege_id"
      FROM $TB_PROJECT P
     INNER JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id = UL.contact_id )
      LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
      ON ( P.project_id = UPP.project_id
	   AND UPP.contact_id='$current_contact_id' )
      LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
      ON ( P.project_id = GPP.project_id )
      LEFT JOIN $TB_PRIVILEGE PRIV
      ON ( GPP.privilege_id = PRIV.privilege_id )
      LEFT JOIN $TB_USER_WORK_GROUP UWG
      ON ( GPP.work_group_id = UWG.work_group_id
	   AND UWG.contact_id='$current_contact_id' )
      LEFT JOIN $TB_WORK_GROUP WG
      ON ( UWG.work_group_id = WG.work_group_id )
      WHERE 1=1
      AND P.record_status != 'D'
      AND UL.record_status != 'D'
      AND ( UPP.record_status != 'D' OR UPP.record_status IS NULL )
      AND ( GPP.record_status != 'D' OR GPP.record_status IS NULL )
      AND ( PRIV.record_status != 'D' OR PRIV.record_status IS NULL )
      AND ( UWG.record_status != 'D' OR UWG.record_status IS NULL )
      AND ( WG.record_status != 'D' OR WG.record_status IS NULL )
      AND P.project_id = '$current_project_id'
      AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40 )
      AND ( WG.work_group_name IS NOT NULL OR UPP.privilege_id IS NOT NULL )
      GROUP BY P.project_id,P.project_tag,P.name,UL.username
      ORDER BY UL.username,P.project_tag
      ~;
  @rows = $self->selectSeveralColumns($sql);

  my $best_privilege_id = 9999;

  if (@rows) {
      my ($username,$best_group_privilege_id,$best_user_privilege_id) = @{$rows[0]};
      
      #### Select the lowest permission and translate to a name
      $best_group_privilege_id = 9999
        unless (defined($best_group_privilege_id));
      $best_user_privilege_id = 9999
        unless (defined($best_user_privilege_id));

      $best_privilege_id = $best_group_privilege_id;
      $best_privilege_id = $best_user_privilege_id if
        ($best_user_privilege_id < $best_privilege_id);
  }

  return $best_privilege_id;
}


###############################################################################
# getWritableProjects
###############################################################################
sub getWritableProjects{
  my $self = shift || croak("parameter self not passed");
  return $self->getAccessibleProjects(privilege_level=>30);
}

###############################################################################
# isProjectAccessible
###############################################################################
sub isProjectAccessible{
  my $self = shift || croak("parameter self not passed");
  my %args = @_;

  ## Decode Arguments
  my $project_id = $args{'project_id'} || $self->getCurrent_project_id();

  my @accessible_projects = $self->getAccessibleProjects();
  foreach my $id (@accessible_projects) {
	if ($id == $project_id) {
	  return 1;
	}
  }
  return 0;
}

###############################################################################
# getAccessibleProjects
###############################################################################
sub getAccessibleProjects{
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "getAccessibleProjects";
  my $work_group_name = $self->getCurrent_work_group_name();
  
  ## Decode argument list
  my $current_contact_id = $args{'contact_id'}
    || $self->getCurrent_contact_id();
  my $module = $args{'module'} || "";
  my $privilege_level = $args{'privilege_level'} || 40;


  #### Define SQL to get all project to which the current user has access
  my $sql = qq~
      SELECT P.project_id,P.project_tag,P.name,UL.username,
             MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL
                      ELSE GPP.privilege_id END) AS "best_group_privilege_id",
             MIN(CASE WHEN P.PI_contact_id = $current_contact_id THEN 10
                      ELSE UPP.privilege_id END) AS "best_user_privilege_id"
			~;

	$sql .= qq~
      FROM $TB_PROJECT P
     INNER JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id = UL.contact_id )
      LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
      ON ( P.project_id = UPP.project_id
	   AND UPP.contact_id='$current_contact_id' )
      LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
      ON ( P.project_id = GPP.project_id )
      LEFT JOIN $TB_PRIVILEGE PRIV
      ON ( GPP.privilege_id = PRIV.privilege_id )
      LEFT JOIN $TB_USER_WORK_GROUP UWG
      ON ( GPP.work_group_id = UWG.work_group_id
	   AND UWG.contact_id='$current_contact_id' )
      LEFT JOIN $TB_WORK_GROUP WG
      ON ( UWG.work_group_id = WG.work_group_id )
			~;

	$sql .= qq~
      WHERE 1=1
      AND P.record_status != 'D'
      AND UL.record_status != 'D'
      AND ( UPP.record_status != 'D' OR UPP.record_status IS NULL )
      AND ( GPP.record_status != 'D' OR GPP.record_status IS NULL )
      AND ( PRIV.record_status != 'D' OR PRIV.record_status IS NULL )
      AND ( UWG.record_status != 'D' OR UWG.record_status IS NULL )
      AND ( WG.record_status != 'D' OR WG.record_status IS NULL )
			~;
	if ($work_group_name ne "Admin") {
			$sql .= qq~
      AND ( UPP.privilege_id<=$privilege_level OR GPP.privilege_id<=$privilege_level
            OR P.PI_contact_id = '$current_contact_id' )
      AND ( WG.work_group_name IS NOT NULL OR UPP.privilege_id IS NOT NULL
            OR P.PI_contact_id = '$current_contact_id' )
			~;
	}

	$sql .= qq~
      GROUP BY P.project_id,P.project_tag,P.name,UL.username
      ORDER BY UL.username,P.project_tag
  ~;

  my @rows = $self->selectSeveralColumns($sql);

  my @project_ids = ();

  foreach my $element (@rows) {
      push(@project_ids,$element->[0]);
  }
  return (@project_ids);
} # end getAccessibleProjects


###############################################################################
# Passed a table name, the routine will determine the access
# rights of the currently authenticated sbeams user to that table, based on 
# user's current work_group.  Access rights will be one of the # enumerated
# types DATA_XXX, where XXX is among NONE, READER, WRITER, MODIFIER, ADMIN.
#
# named arg table_name - fully qualified tablename (db.dbo.tablename) !required 
#
# returns DATA_X access mode for the user on this table
#
###############################################################################
sub getTablePermission {
  my $self = shift;
  my %args = @_;

  # Need to know what table, user, and group we're working with.
  # These must be passed (rather than determined) to avoid mismatches
  foreach my $param ( qw( dbtable table_name contact_id work_group_id ) ) {
    die ( "Missing required parameter $param" ) unless $args{$param};
  }

  # Current thinking is that ADMIN workgroup does NOT automatically convey priv
  # return DATA_ADMIN if $args{work_group_id} == 1;

  # We may have a specific record to consider
  my @rec_info;

  # If we have optional parameters for primary key column name and value
  if ( $args{pk_column_name} && $args{pk_value} ) {
    @rec_info = $self->selectSeveralColumns( <<"    END_SQL" );
    SELECT $args{pk_column_name}, record_status, modified_by_id,
           created_by_id, owner_group_id
    FROM $args{dbtable}
    WHERE $args{pk_column_name} = $args{pk_value}
    END_SQL

    die ( "Unable to find specified record" ) if !scalar( @rec_info );

    # Convienience, put record values into array instead of array of array refs
    @rec_info = @{$rec_info[0]};
  }

  # This query will return user/work_group privileges
  my $usql =<<"  END";
  SELECT ul.privilege_id userlogin_priv,
        uwg.privilege_id userworkgroup_priv,
         uc.privilege_id usercontext_priv
  FROM $TB_USER_LOGIN ul
  LEFT OUTER JOIN $TB_USER_CONTEXT uc
    ON ul.contact_id = uc.contact_id
  LEFT OUTER JOIN $TB_USER_WORK_GROUP uwg
    ON uwg.contact_id = ul.contact_id
  WHERE ul.contact_id = $args{contact_id}
  AND uwg.work_group_id = $args{work_group_id}
  AND ul.record_status != 'D'
  AND uc.record_status != 'D'
  AND uwg.record_status != 'D'
  END

  my @uperms = $self->selectSeveralColumns( $usql );
 
  if ( scalar( @uperms ) > 1 ) { # Should only return one row
    die ( <<'    END_ERROR' );
    More than one row returned from permissions query.  Please report this 
    error to Eric Deutsch or to submit to sbeams bug database
    END_ERROR
  }


  # This query will fetch table_group_security info, if available
  # Note that this schism was due to lack of tgs entries for some table groups
  my $gsql =<<"  END";
  SELECT tgs.privilege_id tablegroupsecurity_priv
  FROM $TB_TABLE_GROUP_SECURITY tgs
  LEFT OUTER JOIN $TB_TABLE_PROPERTY tp
    ON tgs.table_group = tp.table_group
  WHERE tgs.work_group_id = $args{work_group_id}
  AND tp.table_name = '$args{table_name}'
  AND tgs.record_status != 'D'
  END

  # print STDERR "USQL: $usql \n\n TGSQL: $gsql\n";

  my @gperms = $self->selectSeveralColumns( $gsql );
 
  if ( scalar( @gperms ) > 1 ) { # Should only return one row
    die ( <<'    END_ERROR' );
    More than one row returned from permissions query.  Please report this 
    error to Eric Deutsch or to submit to sbeams bug database
    END_ERROR
  }

  # The computed privilege for this user, group, table combo
  my $privilege;

    my @permissions;
  if ( !scalar( @gperms ) ) {
    $privilege = DATA_NONE;

  } else {
    # Cull the NULL
    for( @{$gperms[0]}, @{$uperms[0]} ) { push @permissions, $_ if defined $_; }
    # The biggest (worst access) or null permissions
    $privilege = ( scalar @permissions ) ? getMax( @permissions ) : DATA_NONE ;

  } 

  # Decision time.
  if ( $privilege == DATA_NONE ) { # Deny if overall priv is DATA_NONE ?
    return DATA_NONE;

  } elsif ( scalar( @rec_info ) ) { # Existing record.

    if ( $rec_info[2] == $args{contact_id} ) { # last modifier, allow
      return getMin( $privilege, DATA_MODIFIER ); # return MIN
          
    } elsif ( $rec_info[1] eq 'L' ) { # Locked record, deny all others.
      return getMax( $privilege, DATA_WRITER ); # return MAX
      
    } elsif ( $rec_info[1] eq 'M' ) { # Modifiable, allow if <= DATA_WRITE.
      return ( $privilege > DATA_WRITER ) ? $privilege 
                                          : getMin( $privilege, DATA_MODIFIER );

    } elsif ( $privilege == DATA_GROUP_MOD ) {        # User is group_mod &&
      if ( $rec_info[4] == $args{work_group_id} ) {  # Group data, allow
        return DATA_MODIFIER;

      } else { # Not group data, demote to DATA_WRITER
        return DATA_WRITER;

      }
    
    } else { # No special cases apply, return calculated privilege
      return $privilege;

    }

  } else { # No record, just return calculated privilege
    return $privilege;

  }


} # End getTablePermission


###############################################################################
# Utility routine, returns (arithmetic) maximum value of passed array 
###############################################################################
sub getMax {
  my @sorted = sort { $b <=> $a } @_;
  return $sorted[0];
}

###############################################################################
# Utility routine, returns (arithmetic) minimum value of passed array 
###############################################################################
sub getMin {
  my @sorted = sort { $a <=> $b } @_;
  return $sorted[0];
}

###############################################################################
# getProjectPermission Passed a table name, primary_key, and primary_key column, 
# the routine will determine the access rights of the currently authenticated
# sbeams user to that record, based on user's current work_group, status of the 
# record, and project associated permissions for that record.  Access rights
# will be one of the enumerated
# types DATA_XXX, where XXX is among NONE, READER, WRITER, MODIFIER, ADMIN.
#
# named arg table_name - fully qualified tablename (db.dbo.tablename) required!
# named arg pk_name - name of primary key column required!
# named arg pk_value - value of primary key required!
#
# returns DATA_X access mode for the user on this table
#
###############################################################################
sub getProjectPermission {
  my $self = shift;
  my %args = @_;

  # Need to know what table, user, group, and record we're working with.
  # These must be passed (rather than determined) to avoid mismatches
  foreach my $param ( qw( table_name contact_id work_group_id parent_project_id
                          pk_column_name pk_value dbtable ) ) {
    die ( "Missing required parameter $param" ) unless defined $args{$param};
  }


  # Determine it the record has a parent project, without it 
  # the routine is moot.
  my $parent_project_id = ( $args{parent_project_id} ) ? $args{parent_project_id} : 
                            $self->getParentProject ( table_name => $args{table_name},
                                                      parameters_ref => \%args,
                                                      action => 'SELECT');
                                               
  # This will signal that the item is not under project control, use only mode1
  return undef unless $parent_project_id;

  # Used DBI call cause it will be a single row, don't want array of array refs
  my @rec_info = $self->getDBHandle()->selectrow_array( <<"  END_SQL" );
  SELECT $args{pk_column_name}, record_status, modified_by_id,
         created_by_id, owner_group_id
  FROM $args{dbtable}
  WHERE $args{pk_column_name} = $args{pk_value}
  END_SQL

  die ( "Unable to find specified record" ) if !defined $rec_info[0];

  # Get best project permission (of User and Group) for this record.  By
  # using the parent project for the record of interest, we get the desired
  # behavior.
  my $privilege = $self->get_best_permission (
                                          work_group_id => $args{work_group_id},
                                          contact_id => $args{contact_id}, 
                                          project_id => $parent_project_id 
                                              );

  # We have the record information, the parent project, and user's permission on
  # it.   Now determine what permission level all these boil down to.
  if ( $privilege == DATA_NONE ) { # Deny if overall priv is DATA_NONE ?
    return DATA_NONE;

  } elsif ( $rec_info[2] == $args{contact_id} ) { # last modifier, allow
    return getMin( $privilege, DATA_MODIFIER ); # return MIN
          
  } elsif ( $rec_info[1] eq 'L' ) { # Locked record, deny all others.
      return getMax( $privilege, DATA_WRITER ); # return MAX
      
  } elsif ( $rec_info[1] eq 'M' ) { # Modifiable, allow if <= DATA_WRITE.
      return ( $privilege > DATA_WRITER ) ? $privilege 
                                          : getMin( $privilege, DATA_MODIFIER );

  } elsif ( $privilege == DATA_GROUP_MOD ) {        # User is group_mod &&
    if ( $rec_info[4] == $args{work_group_id} ) {  # Group data, allow
        return DATA_MODIFIER;

    } else { # Not group data, demote to DATA_WRITER
        return DATA_WRITER;

    }
    
  } else { # No special cases apply, return calculated privilege
    return $privilege;

  }

} # End getProjectPermission

###############################################################################
# Passed user information, resource information, and access level sought 
# ( READER, WRITER, MODIFIER ), returns one or more groups that user 
# belongs to that would allow specified access to the resource.
#
# named arg table_name - fully qualified tablename (db.dbo.tablename) Req.
# named arg pk_column_name - Name of primary key field Req.
# named arg pk_column_value - value of primary key
# named arg parent_project_id
# named arg contact_id
# named arg permission_level
#
###############################################################################
sub getProjectGroups {
  my $self = shift;
  my %args = @_;
  
  # Need to know what user, group, project and privilege we're looking for.
  # These must be passed (rather than determined) to avoid mismatches
  foreach my $param ( qw( contact_id
                          privilege
                          work_group_id 
                          parent_project_id )
                    ) {

    die ( "Missing required parameter $param" ) unless $args{$param};
  }

  # Get list of groups to which user belongs
  # where group has <= specified permissions on parent project
  my $sql =<<"  END_SQL";
  SELECT wg.work_group_name
  FROM $TB_GROUP_PROJECT_PERMISSION gpp
       JOIN $TB_USER_WORK_GROUP uwg
       ON gpp.work_group_id = uwg.work_group_id
       JOIN $TB_WORK_GROUP wg
       ON gpp.work_group_id = wg.work_group_id
       WHERE gpp.project_id = $args{parent_project_id}
       AND uwg.contact_id = $args{contact_id}
       AND gpp.privilege_id >= $args{privilege}
       AND gpp.record_status != 'D'
       AND uwg.record_status != 'D'
  END_SQL

  my @row = $self->selectOneColumn( $sql );

  # return reference to group array
  return \@row;
  
}

###############################################################################
# Passed user information, resource information, and access level sought 
# ( READER, WRITER, MODIFIER ), returns one or more groups that user 
# belongs to that would allow specified access to the resource.
#
# named arg table_name - fully qualified tablename (db.dbo.tablename) Req.
# named arg contact_id
# named arg permission_level
#
###############################################################################
sub getTableGroups {
  my $self = shift;
  my %args = @_;
  
  # Need to know what user, group, project and privilege we're looking for.
  # These must be passed (rather than determined) to avoid mismatches
  foreach my $param ( qw( contact_id
                          privilege
                          table_name
                          work_group_id )
                    ) {

    die ( "Missing required parameter $param" ) unless $args{$param};
  }

  # Get list of groups to which user belongs
  # where group has <= specified permissions table in question
  my $sql =<<"  END_SQL";
  SELECT wg.work_group_name
  FROM $TB_WORK_GROUP wg 
    JOIN $TB_USER_WORK_GROUP uwg
      ON wg.work_group_id = uwg.work_group_id
    JOIN $TB_TABLE_GROUP_SECURITY tgs
      ON wg.work_group_id = tgs.work_group_id
    JOIN $TB_TABLE_PROPERTY tp
      ON tgs.table_group = tp.table_group
  WHERE tp.table_name = '$args{table_name}'
    AND uwg.contact_id = $args{contact_id}
    AND uwg.privilege_id <= $args{privilege}
    AND tgs.privilege_id <= $args{privilege}
    AND tgs.record_status != 'D'
    AND uwg.record_status != 'D'
    AND wg.record_status != 'D'
  END_SQL

  # To keep from coercing into ADMIN group:
  $sql .= " AND wg.work_group_name <> 'Admin' ";

  my @row = $self->selectOneColumn( $sql );

  # return reference to group array
  return \@row;
  
}


###############################################################################
# getUserProjectPermission
# 
# narg project_id      Parent project ID
# narg contact_id      
# 
# ret hashref with 3 keys:  privilege  (privilege_id)
#                           id         (user_project_permission_id)
#                           status     (record_status)
#
# If record does not exist, all three keys are undef
###############################################################################
sub getUserProjectPermission {
  my $self = shift;
  my %args = @_;

  foreach ( 'project_id', 'contact_id' ) {
    die ("Required parameter $_ missing") if !defined $args{$_};
  }

  my @rows = $self->selectSeveralColumns( <<"  END_SQL" );
  SELECT user_project_permission_id, privilege_id, record_status
  FROM $TB_USER_PROJECT_PERMISSION
  WHERE project_id = $args{project_id}
  AND contact_id = $args{contact_id}
  END_SQL

  if ( scalar( @rows ) > 1 ) {
    print STDERR "Error, more than one UPP row for a given user and project";
  }

  my %vals = ( id => undef, privilege => undef, status => undef );

  return ( \%vals ) if !scalar( @rows );

  my $cnt = 0;
  for ( 'id', 'privilege', 'status' ) {
    $vals{$_} = $rows[0]->[$cnt];
    $cnt++;
  }

  return ( \%vals ); 

} # End getUserProjectPermission


###############################################################################
###############################################################################
###############################################################################
###############################################################################
1;
