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

  #### Define SQL to get all project to which the current user has access
  my $sql = qq~
      SELECT P.project_id,P.project_tag,P.name,UL.username,
             MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL
                      ELSE GPP.privilege_id END) AS "best_group_privilege_id",
             MIN(CASE WHEN P.PI_contact_id = $current_contact_id THEN 10
                      ELSE UPP.privilege_id END) AS "best_user_privilege_id"
			~;

	## Only show microarry/inkjet specific projects
	if ($module eq "microarray" || $module eq "inkjet"){
			$sql .= qq~,
			COUNT (AR.array_request_id) AS 'array_requests'
					~;
	}

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

	if ($module eq "microarray") {
			$sql .= qq~
      LEFT JOIN $TBMA_ARRAY_REQUEST AR
      ON ( AR.project_id = P.project_id )
			~;
	}

	if ($module eq "inkjet") {
			$sql .= qq~
      LEFT JOIN $TBIJ_ARRAY_REQUEST AR
      ON ( AR.project_id = P.project_id )
			~;
	}

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
      AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40
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
    ## If microarray, check to see if there have been array requests
    if ($module eq "microarray" || $module eq "inkjet"){
      if($element->[6] > 0 || $element->[5] == 10 || $element->[4] == 10){
					push(@project_ids,$element->[0]);
      }
    }else {
      push(@project_ids,$element->[0]);
    }
  }
  return (@project_ids);
} # end getAccessibleProjects


###############################################################################
###############################################################################
###############################################################################
###############################################################################
1;
