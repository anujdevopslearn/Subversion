package SBEAMS::Connection::Permissions;

###############################################################################
# Program     : SBEAMS::Connection::Permissions
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which contains
#               methods regarding project permissions.
#
# SBEAMS is Copyright (C) 2000-2017 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw(@ERRORS $q @EXPORT @EXPORT_OK);
use CGI::Carp qw(croak);
use Exporter;
our @ISA = qw( Exporter );

use SBEAMS::Connection::Log;
use SBEAMS::Connection::Authenticator qw( $q );
use SBEAMS::Connection::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Inkjet::Tables;
use SBEAMS::Connection::Tables;

our @EXPORT_OK = qw(DATA_NONE DATA_READER DATA_WRITER DATA_MODIFIER DATA_ADMIN );
# Constants that represent access levels
use constant DATA_NONE => 50;
use constant DATA_READER => 40;
use constant DATA_WRITER => 30;
use constant DATA_GROUP_MOD => 25;
use constant DATA_MODIFIER => 20;
use constant DATA_ADMIN => 10;

my $log = SBEAMS::Connection::Log->new();
$log->debug( "Permissions init!" );

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
  my $pid = $self->getCurrent_project_id();
  $permission = $self->get_best_permission();

  my $edit = '';
  if ( $permission <= DATA_NONE ) {
    $edit =<<"    END";
    <A HREF=ManageTable.cgi?TABLE_NAME=project&project_id=$pid>[view/edit]</A>
    END
  }

  print qq~
      <H1>Privileges for <I>$project_name</I>$edit</H1>
      $LINESEPARATOR
      ~;
  

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

  my $verbose = $args{"verbose"} || 0;
  my $testonly = $args{"testonly"} || 0;

  $current_project_id = $args{"project_id"} || $self->getCurrent_project_id;
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
							 add_audit_parameters=>1,
                                                         verbose => $verbose,
                                                         testonly => $testonly
                                                         );
		        }else{
				$rowdata{'record_status'} = 'D';
				$rowdata_ref = \%rowdata;
				$self->updateOrInsertRow(table_name=>$TB_USER_PROJECT_PERMISSION,
							 rowdata_ref=>$rowdata_ref,
							 update=>1,
							 PK_name=>'user_project_permission_id',
							 PK_value=>$rows[0],
							 add_audit_parameters=>1,
                                                         verbose => $verbose,
                                                         testonly => $testonly
                                                         );
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
						 add_audit_parameters=>1,
                                                 verbose => $verbose,
                                                 testonly => $testonly
                                                 );
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

  my $verbose = $args{"verbose"} || 0;
  my $testonly = $args{"testonly"} || 0;

  $current_project_id = $args{"project_id"} || $self->getCurrent_project_id;
  #$current_work_group_id = $self->getCurrent_work_group_id;


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
							 add_audit_parameters=>1,
                                                         verbose => $verbose,
                                                         testonly => $testonly
                                                         );
			  }else{
				$rowdata{'record_status'} = 'D';
				$rowdata_ref = \%rowdata;
				$self->updateOrInsertRow(table_name=>$TB_GROUP_PROJECT_PERMISSION,
							 rowdata_ref=>$rowdata_ref,
							 update=>1,
							 PK_name=>'group_project_permission_id',
							 PK_value=>$rows[0],
							 add_audit_parameters=>1,
                                                         verbose => $verbose,
                                                         testonly => $testonly
                                                         );
			  }
		}else { # no entry in group_project_permission, so insert new
			$rowdata{'work_group_id'}   = $group_id;
			$rowdata{'project_id'}   = $current_project_id;
			$rowdata{'privilege_id'} = $priv_id;
			$rowdata_ref = \%rowdata;
			$self->updateOrInsertRow(table_name=>$TB_GROUP_PROJECT_PERMISSION,
						 rowdata_ref=>$rowdata_ref,
						 insert=>1,
						 PK_name=>'group_project_permission_id',
						 add_audit_parameters=>1,
                                                 verbose => $verbose,
                                                 testonly => $testonly
						);
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
  my $SUB_NAME = "get_best_permission";

  ## Decode argument list
  my $current_contact_id = $args{'contact_id'}
  || $self->getCurrent_contact_id;
  my $current_project_id = $args{'project_id'}
  || $self->getCurrent_project_id;
  my $current_group_id = $args{'group_id'}
  || $self->getCurrent_work_group_id;
  
  # The default behavior of this subroutine is (and was) to return admin (10)
  # automatically if the current work group is admin.  This flag allows users
  # to override this behavior while maintaining backwards compatibility. 
  my $admin_override = ( defined $args{admin_override} ) ? $args{admin_override} : 1;

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
  if ($admin_work_group_id == $current_group_id && $admin_override ){
      return $administrator_privilege_id;
  }

  ## Else find best privilege available
  $sql =<<"  END_SQL";
  SELECT MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL ELSE GPP.privilege_id END) AS "best_group_privilege_id",
         MIN(UPP.privilege_id) AS "best_user_privilege_id"
  FROM $TB_PROJECT P
  JOIN $TB_CONTACT C 
   ON ( P.PI_contact_id = C.contact_id AND C.record_status != 'D' )
  LEFT JOIN $TB_USER_LOGIN UL 
   ON ( C.contact_id = UL.contact_id AND UL.record_status != 'D' )
  LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
   ON ( P.project_id = UPP.project_id AND UPP.contact_id='$current_contact_id' AND UPP.record_status != 'D' )
  LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
   ON ( P.project_id = GPP.project_id AND GPP.record_status != 'D' )
  LEFT JOIN $TB_PRIVILEGE PRIV
   ON ( GPP.privilege_id = PRIV.privilege_id AND PRIV.record_status != 'D' )
  LEFT JOIN $TB_USER_WORK_GROUP UWG
   ON ( GPP.work_group_id = UWG.work_group_id AND UWG.contact_id='$current_contact_id' AND UWG.record_status != 'D' )
  LEFT JOIN $TB_WORK_GROUP WG
   ON ( UWG.work_group_id = WG.work_group_id AND WG.record_status != 'D')
  WHERE P.project_id = '$current_project_id'
  AND P.record_status != 'D'
--  
-- Obsolete? 20005-04-22  
--
--  AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40 )
--  GROUP BY P.project_id,P.project_tag,P.name,UL.username
--  ORDER BY UL.username,P.project_tag
  END_SQL

  @rows = $self->selectSeveralColumns($sql);
  
  # Translate null values to 9999 (de facto null), iff there were any rows.
  @rows = map { ( defined $_ ) ? $_ : 9999 } @{$rows[0]} if @rows; 

  # Afford admin users the ability to at least read records
  my $default_privilege = ( $admin_work_group_id == $current_group_id ) ? DATA_READER : 9999;

  # Select the lowest permission
  my $best_privilege = getMin( $default_privilege, @rows );
  $log->debug( "Best permission for $current_contact_id on project $current_project_id is $best_privilege" );

  # Hack in second look using guest user if perms are 9999
  if ( $best_privilege >= 50 ) {
    my $username =  $self->getCurrent_username();

    $log->debug( "Checking for guest privileges" );
	  unless ( $self->isDeniedGuestPrivileges( $username )) {
      my $guest_contact_id = $self->get_guest_contact_id();


      $sql = qq~
       SELECT MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL ELSE GPP.privilege_id END) AS "best_group_privilege_id",
              MIN(UPP.privilege_id) AS "best_user_privilege_id"
       FROM $TB_PROJECT P
       JOIN $TB_CONTACT C 
        ON ( P.PI_contact_id = C.contact_id AND C.record_status != 'D' )
       LEFT JOIN $TB_USER_LOGIN UL 
        ON ( C.contact_id = UL.contact_id AND UL.record_status != 'D' )
       LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
        ON ( P.project_id = UPP.project_id AND UPP.contact_id='$guest_contact_id' AND UPP.record_status != 'D' )
       LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
        ON ( P.project_id = GPP.project_id AND GPP.record_status != 'D' )
       LEFT JOIN $TB_PRIVILEGE PRIV
        ON ( GPP.privilege_id = PRIV.privilege_id AND PRIV.record_status != 'D' )
       LEFT JOIN $TB_USER_WORK_GROUP UWG
        ON ( GPP.work_group_id = UWG.work_group_id AND UWG.contact_id='$guest_contact_id' AND UWG.record_status != 'D' )
       LEFT JOIN $TB_WORK_GROUP WG
        ON ( UWG.work_group_id = WG.work_group_id AND WG.record_status != 'D')
       WHERE P.project_id = '$current_project_id'
       AND P.record_status != 'D'
       ~;

       @rows = $self->selectSeveralColumns($sql);
  
       # Translate null values to 9999 (de facto null), iff there were any rows.
       @rows = map { ( defined $_ ) ? $_ : 9999 } @{$rows[0]} if @rows; 

       # Select the lowest permission
       $best_privilege = getMin( @rows );

      $log->debug( "Best priv including guest is $best_privilege" );
  	}
  }

  return( $best_privilege );
}

#+
# Simple method to determine if the current user's mode 1 permissions
# on a given table are DATA_WRITER or better (i.e. <= 30).
#
# @arg table_name Common name of table in question.  REQUIRED
# @ret 1 if privilege <= 30, else 0.
# 
sub isTableWritable {
  my $self = shift;
  my %args = @_;
  die( "Missing required parameter table_name" ) unless $args{table_name}; 

  $args{dbtable} = $self->returnTableInfo( $args{table_name}, 'DB_TABLE_NAME' );
  $args{contact_id} = $self->getCurrent_contact_id;
  $args{privilege} = DATA_WRITER;
  my $current_wg = $self->getCurrent_work_group_id();
  
  # Get list of groups user can access, with privilege level.
  my $groups = $self->getTableGroups( %args  );

  my $admin_gid = $self->getAdminWorkGroupId();
  
  if ( !scalar(@$groups) ) {

    # There weren't any groups that would suffice.
    return 0;

  } else {

    # These are sorted by privilege
    my $best = $$groups[0];

    # If the top group is admin and we are not in that group, retry.
    if ( $$best[1] == $admin_gid && $current_wg != $admin_gid ) {

      # Admin was the only choice, bail
      return 0 if scalar(@$groups) == 1; 

      # Get next best thing
      $best = $$groups[1];
    }
    
    # Is the best non-admin group sufficient (Admin OK iff current group)?
    return ( $$best[2] > DATA_WRITER ) ? 0 : 1; 

  }
}

###############################################################################
# getModifiableProjects
###############################################################################
sub getModifiableProjects{
  my $self = shift || croak("parameter self not passed");
  return $self->getAccessibleProjects(privilege_level=>20);
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
# isProjectModifiable
###############################################################################
sub isProjectModifiable{
  my $self = shift || croak("parameter self not passed");
  my %args = @_;

  ## Decode Arguments
  my $project_id = $args{'project_id'} || $self->getCurrent_project_id();

  my @projects = $self->getModifiableProjects();
  foreach my $id (@projects) {
    if ($id == $project_id) {
      return 1;
    }
  }

  return 0;
}


###############################################################################
# isProjectWritable
###############################################################################
sub isProjectWritable{
  my $self = shift || croak("parameter self not passed");
  my %args = @_;

  ## Decode Arguments
  my $project_id = $args{'project_id'} || $self->getCurrent_project_id();

  my @writable_projects = $self->getWritableProjects();
  foreach my $id (@writable_projects) {
    if ($id == $project_id) {
      return 1;
    }
  }

  return 0;
}

sub isDeniedGuestPrivileges {
  my $self = shift || croak("parameter self not passed");
	my $username = shift;
	my $denied = $self->getDeniedGuestUsers();
	if ( grep /^$username$/, @$denied ) {
		return 1;
		$log->debug( "user $username denied guest privileges by policy" );
	}
	return 0;
}

sub getGuestWorkGroup {
  my $self = shift;
  my %args = @_;
  my $wg_clause = '';
 
  if ( $args{wg_name} ) {
    $wg_clause = "WHERE work_group_name = '$args{wg_name}'\n";
  } elsif( $args{wg_module} ) {
    $wg_clause = "WHERE work_group_name = '$args{wg_module}_readonly'\n";
  } else {
    $wg_clause = "WHERE work_group_name = 'guest'\n";
  }
  my $sql = qq~
    SELECT work_group_id, work_group_name
    FROM $TB_WORK_GROUP
    $wg_clause;
  ~;
  my @wg = $self->selectrow_array( $sql );
  return \@wg;
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

  if ( $args{as_guest} ) {
    $current_contact_id = $self->get_guest_contact_id();
    my $wg_info = $self->getGuestWorkGroup(%args);
    $work_group_name = $wg_info->[1];
  }

  my $module = $args{'module'} || "";
  my $privilege_level = $args{'privilege_level'} || 40;

  my $username =  $self->getCurrent_username();

	my $guest_clause = '';
	unless ( $self->isDeniedGuestPrivileges( $username )) {
    my $guest_id = $self->get_guest_contact_id();
		$guest_clause = ", $guest_id" if $guest_id;
	}


  #### Define SQL to get all project to which the current user has access
  my $sql = qq~
  SELECT P.project_id,P.project_tag,P.name,
    CASE WHEN UL.username IS NULL THEN '-No Login-' 
         ELSE UL.username END AS username,
             MIN(CASE WHEN UWG.contact_id IS NULL THEN NULL
                      ELSE GPP.privilege_id END) AS "best_group_privilege_id",
             MIN(CASE WHEN P.PI_contact_id = $current_contact_id THEN 10
                      ELSE UPP.privilege_id END) AS "best_user_privilege_id"
      FROM $TB_PROJECT P
     INNER JOIN $TB_CONTACT C 
           ON ( P.PI_contact_id = C.contact_id AND C.record_status != 'D' )
      LEFT JOIN $TB_USER_LOGIN UL
           ON ( C.contact_id = UL.contact_id AND UL.record_status != 'D' )
      LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
           ON ( P.project_id = UPP.project_id AND UPP.record_status != 'D'
	        AND UPP.contact_id IN ('$current_contact_id' $guest_clause ) )
      LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
           ON ( P.project_id = GPP.project_id AND GPP.record_status != 'D' )
      LEFT JOIN $TB_PRIVILEGE PRIV
           ON ( GPP.privilege_id = PRIV.privilege_id AND PRIV.record_status != 'D' )
      LEFT JOIN $TB_USER_WORK_GROUP UWG
           ON ( GPP.work_group_id = UWG.work_group_id AND UWG.record_status != 'D'
      	        AND UWG.contact_id IN ('$current_contact_id' $guest_clause ) )
      LEFT JOIN $TB_WORK_GROUP WG
           ON ( UWG.work_group_id = WG.work_group_id AND WG.record_status != 'D' )
     WHERE 1=1
       AND P.record_status != 'D'
       AND P.project_id not in (
           SELECT CASE WHEN UPP2.project_id IS NULL THEN NULL
                  ELSE UPP2.project_id
                  END as id
           FROM $TB_USER_PROJECT_PERMISSION UPP2
           WHERE UPP2.project_id= 773
           AND UPP2.contact_id IN ('$current_contact_id' $guest_clause ) 
           AND UPP2.privilege_id = 50
          ) 
  ~;

	if ($work_group_name ne "Admin") {
			$sql .= qq~
      AND ( UPP.privilege_id<=$privilege_level OR GPP.privilege_id<=$privilege_level
            OR P.PI_contact_id IN ('$current_contact_id' $guest_clause ) )
      AND ( WG.work_group_name IS NOT NULL OR UPP.privilege_id IS NOT NULL
            OR P.PI_contact_id IN ('$current_contact_id' $guest_clause ) )
			~;
	}

	$sql .= qq~
      GROUP BY P.project_id,P.project_tag,P.name,UL.username
      ORDER BY UL.username,P.project_tag
  ~;

  my @rows = $self->selectSeveralColumns($sql);

  my @project_ids = ();
  my %projects = {};
  foreach my $element (@rows) {
    push(@project_ids,$element->[0]);
    $projects{$element->[0]} = $element->[2];
  }
  return ( $args{as_hashref} ) ? \%projects :
         ( wantarray ) ? @project_ids : join( ',', @project_ids );
} # end getAccessibleProjects

#+
# Subroutine to standardize checking of a parameter list.  Checks input list
# against acceptable values, returns reference to array of valid input items, 
# logs any errors.
#
# named arg, req: input, arrayref or comma separated list of input to validate
# named arg, req: name, name (type) of parameter, for reportException call
# named arg, req: total, ref to array of all possible values.
# named arg, opt: accessible, ref to array holding all accessible values.
#-
sub validateParamList {
  my $this = shift;
  my %args = @_;
  for ( qw( input total name ) ) {
    unless( $args{$_} ) {
      $log->error( "Missing parameter $_");
      return undef;
    }
  }

  # Can be an arrayref or a comma delimited string
  my @input = (ref($args{input}) eq 'ARRAY' ) ? @{$args{input}} : split ",", $args{input};

  # Array to hold validated entities
  my @valid;

  for my $ent ( @input ) {
    if ( !grep /^$ent$/, @{$args{total}} ) {
      $this->reportException ( state => 'ERROR',
                                type => "Bad $args{name}",
                             message => "Non-existent $args{name} specified: $ent" );
    } elsif ( defined $args{accessible} && !grep /^$ent$/, @{$args{accessible}} ) {
      $this->reportException ( state => 'ERROR',
                                type => "Bad $args{name}",
                             message => "You do not have access to specified $args{name}: $ent" );
    } else {
      push @valid, $ent;
    }
  }

  # If any values were culled, log warning and print stack to show context. 
  unless ( scalar @valid == scalar @input ) {
    $log->warn( "Invalid parameters submitted, investigate" );
    $log->printStack( 'warn' );
  }

  # return reference to array of validated entities
  return ( \@valid )
}


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
sub calculateTablePermission {
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
    $log->error("Error: multiple rows from user permissions  query:\n $usql");
    die ( <<"    END_ERROR" );
    More than one row returned from permissions query.  Please report this
    error to your local $DBTITLE administrator $DBADMIN 
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

#  $log->debug( "USQL: $usql" );
#  $log->debug( "TGSQL: $gsql" );

  my @gperms = $self->selectSeveralColumns( $gsql );
 
  if ( scalar( @gperms ) > 1 ) { # Should only return one row
    $log->error("Error: multiple rows from group permissions  query:\n $gsql");
    die ( <<"    END_ERROR" );
    More than one row returned from permissions query.  Please report this 
    error to your local $DBTITLE administrator $DBADMIN
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


} # End calculateTablePermission

###############################################################################
# calculateProjectPermission Passed a table name, primary_key, and primary_key
# column, the routine will determine the access rights of the currently 
# authenticated sbeams user to that record, based on user's current work_group,
# status of the record, and project associated permissions for that record. 
# 
# Access rights # will be one of the enumerated types DATA_XXX, where XXX is
# among NONE, READER, WRITER, MODIFIER, ADMIN.
#
# named arg table_name - fully qualified tablename (db.dbo.tablename) required!
# named arg pk_name - name of primary key column required!
# named arg pk_value - value of primary key required!


# returns DATA_X access mode for the user on this table
#
###############################################################################
sub calculateProjectPermission {
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
                                          project_id => $parent_project_id, 
# Note 2005-04-21; Admin workgroup membership doesn't exempt user from 
# project permissions.  If Admin user needs to override, they can grant 
# themselves (temporary) privileges on the project.
                                          admin_override => 0
                                              );

  # We have the record information, the parent project, and user's permission on
  # it.   Now determine what permission level all these boil down to.
  if ( $privilege >= DATA_NONE ) { # Deny if overall priv is DATA_NONE or worse?
    return $privilege;

  } elsif ( $rec_info[2] == $args{contact_id} ) { # last modifier, allow
    $log->info( "Promoted last modifier from $privilege to 20" ) if $privilege > DATA_MODIFIER;
    return getMin( $privilege, DATA_MODIFIER ); # return MIN
          
  } elsif ( $rec_info[1] eq 'L' ) { # Locked record, deny all others.
    $log->info( "Denied access to locked record for privileged user ($privilege)" ) if $privilege <= DATA_MODIFIER;
      return getMax( $privilege, DATA_WRITER ); # return MAX
      
  } elsif ( $rec_info[1] eq 'M' ) { # Modifiable, allow if <= DATA_WRITE.
    $log->info( "Promoted from $privilege to 20 for Modifiable record" ) if $privilege > DATA_MODIFIER;
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

} # End calculateProjectPermission

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

  my @allgroups;
  # Get list of groups to which user belongs
  my @group_ids = $self->selectSeveralColumns( <<"  END_SQL" );
  SELECT work_group_name, wg.work_group_id
  FROM $TB_USER_WORK_GROUP uwg
  JOIN $TB_WORK_GROUP wg
  ON wg.work_group_id = uwg.work_group_id
  WHERE uwg.contact_id = $args{contact_id}
  AND wg.record_status != 'D'
  AND uwg.record_status != 'D'
  END_SQL

  foreach my $grp ( @group_ids ) {
  # where group has <= specified permissions on parent project
  my $sql =<<"  END_SQL";
  SELECT privilege_id
  FROM $TB_GROUP_PROJECT_PERMISSION
  WHERE work_group_id = $grp->[1]
  AND project_id = $args{parent_project_id}
  AND record_status != 'D'
  END_SQL
  my ( $priv ) = $self->selectOneColumn( $sql );
  $priv ||= 9999;
  push( @allgroups, [ @{$grp}, $priv ]  )
  }

  # return reference to group array
  return \@allgroups;
  
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
  
  # Need to know what user, table and privilege we're looking for.
  # These must be passed (rather than determined) to avoid mismatches
  foreach my $param ( qw( contact_id privilege table_name ) ) {
    die ( "Missing required parameter $param" ) unless $args{$param};
  }

  # Get list of groups to which user belongs
  # where group has <= specified permissions table in question
  my $sql =<<"  END_SQL";
  SELECT wg.sort_order,
         wg.work_group_name,
         wg.work_group_id,
         CASE WHEN tgs.privilege_id IS NULL 
              THEN 9999 
              ELSE tgs.privilege_id 
         END AS tgs_priv,
         ul.privilege_id AS ul_priv,
         uwg.privilege_id AS uwg_priv,
         uc.privilege_id AS uc_priv
  FROM $TB_USER_LOGIN ul
  LEFT OUTER JOIN $TB_USER_CONTEXT uc
    ON ul.contact_id = uc.contact_id
  INNER JOIN $TB_USER_WORK_GROUP uwg
    ON uwg.contact_id = ul.contact_id
    JOIN $TB_WORK_GROUP wg
    ON wg.work_group_id = uwg.work_group_id
    LEFT OUTER JOIN $TB_TABLE_GROUP_SECURITY tgs
    ON wg.work_group_id = tgs.work_group_id
    LEFT OUTER JOIN $TB_TABLE_PROPERTY tp
    ON tgs.table_group = tp.table_group
  WHERE tp.table_name = '$args{table_name}'
    AND uwg.contact_id = $args{contact_id}
    AND ul.privilege_id <= $args{privilege}
    AND uwg.privilege_id <= $args{privilege}
    AND tgs.privilege_id <= $args{privilege}
    AND tgs.record_status != 'D'
    AND uwg.record_status != 'D'
    AND wg.record_status != 'D'
    AND ul.record_status != 'D'
  END_SQL

# Removed this 2004-12-7; no longer switch to group, thus using admin perms OK.
# To keep from coercing into ADMIN group:
# $sql .= " AND wg.work_group_name <> 'Admin' ";

  my @groups;
  my @rows = $self->selectSeveralColumns( $sql );

# Go through the rows, calculating the worst defined privilege...
  foreach my $row ( @rows ) {
    my $priv = getMax( @$row[3..6] );
    push @groups, [ $$row[0], $$row[1], $$row[2], $priv ];
  }

# Sort first by auth level, then by group name.
  @groups = sort { ( $a->[3] <=> $b->[3] )  # First sort by privilege ASC
                || ( $a->[0] <=> $b->[0] )  # Then by sort order ASC
                || ( $a->[1] cmp $b->[1] ) } @groups; # Then by name ASC

  foreach my $g ( @groups ){
    shift @$g;             # shift of the sort order, no longer needed.
  }
  # return reference to group array
  return \@groups;
  
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
    $log->error("Error, more than one UPP row for a given user and project");
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

#+
# narg fkey  Name of foreign key to access project info (may be project_id)
# narg fval  Value of foreign key to access project info
# narg fsql  SQL to fetch parent project_id
# narg dbsql SQL to fetch parent project_id from db record
# narg tname Name of table to be modified
#
#-
sub checkProjectPermission {
  my $self = shift;
  my %args = @_;

  # Check requirements, don't need fsql if fkey is project_id
  for ( qw( action fkey fval fsql dbsql tname ) ) {
    next if $_ eq 'fsql' && lc($args{fkey}) eq 'project_id';
    if ( !$args{$_} ) {
      return "Required argument $_  missing";
    }
  }

  # Make sure there are no potential db modifiers in sql string
  my $err = $self->isTaintedSQL( $args{fsql} );
  $err ||= $self->isTaintedSQL( $args{dbsql} );

  if ( $err ) {
    return "Dangerous SQL caught:\n $args{fsql}\n $args{dbsql}\n";
  }

  my $pr_id;

  if ( lc($args{fkey}) eq 'project_id' ) {
    $pr_id = $args{fval};
  } else {
    ( $pr_id ) = $self->selectOneColumn( $args{fsql} );
  }

  if ( !$pr_id ) {
    return "Unable to determine project_id\n";
  }

  my $priv = $self->get_best_permission( project_id => $pr_id,
                                         admin_override => 0 
                                       );
  
  if ( uc($args{action}) eq 'INSERT' ) {

    #  Can user write the project? 
    if ( DATA_WRITER < $priv ) {
      # Log error and return error string
      print STDERR "Unable to INSERT $args{tname} record: insufficient permissions\n";
      return "Insufficient permissions ($priv) in project (ID: $pr_id)";
    }

  } elsif ( uc($args{action}) eq 'UPDATE' ) {

    my ( $pr_id_orig ) = $self->selectOneColumn( $args{dbsql} );
    unless ( $pr_id_orig ) {
			$log->warn( <<"      END" );
			Altering record nominally under project control, but which
      currently lacks a project_id.  We will proceed as if the original
      ID were equal to new ID:
      dbsql: $args{dbsql}
      END
			
      $pr_id_orig = $pr_id;
			
      # return "Unable to find parent record";
    }

#   Has associated project has been modified? 
    if ( $pr_id_orig != $pr_id ) { # We've got a new one...

      my $priv_orig = $self->get_best_permission( project_id => $pr_id_orig,
                                                  admin_override => 0 
                                                 );
      my $priv_new = $priv;  # $priv is calculated with cgi passed value

      # can this user change original?
      if ( DATA_WRITER <= $priv_orig ) {
        # Nope, he/she/it ain't allowed
        print STDERR "Unable to UPDATE $args{tname}, lacking permission in current project\n";
        return "Insufficient permissions ($priv_orig) in project (ID: $pr_id_orig)";
      }
      # Can user write new one? 
      if ( DATA_WRITER < $priv_new ) {
        # Nope, he/she/it ain't allowed
        print STDERR "Unable to UPDATE $args{tname}, lacking permission in new project\n";
        return "Insufficient permissions ($priv_new) in project (ID: $pr_id)";
      }
    } else { # project association unchanged.

      # Since new project = original project, calculated priv is original priv
      # can this user change original?
      if ( DATA_WRITER <= $priv ) {
        # Nope, he/she/it ain't allowed
        print STDERR "Unable to UPDATE $args{tname} record: insufficient permissions\n";
        return "Insufficient permissions ($priv) in project (ID: $pr_id)";
      }

    } # END proj_id changed

  } else {
    return 'Unknown action mode!';

  }

}

###############################################################################
# Utility routine, returns (arithmetic) maximum value of passed array 
###############################################################################
#
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
# Utility routine, checks if current user is 'guest' user.
# FIXME: make id lookup dynamic
###############################################################################
sub isGuestUser {

  my $self = shift;

  # Short-circuit if we've already looked this up
  return 1 if ( $self->{_is_guest} );

  my $currID =  $self->getCurrent_contact_id();
  my $username =  $self->getCurrent_username();

  if ( !defined $currID ) {
    return undef;
  } elsif ( $username eq 'guest' ) {
    $self->{_is_guest}++;
    return 1;
  } elsif ( $currID == 107 ) {
    $self->{_is_guest}++;
    return 1;
  } else { 
    return 0;
  }
}

###############################################################################
# Utility routine, checks if current user is 'ext_halo' user.
# FIXME: make id lookup dynamic
###############################################################################
sub is_ext_halo_user {
  my $sbeams = shift;
  my $currID =  $sbeams->getCurrent_contact_id();
  my $username =  $sbeams->getCurrent_username();

  if ( $username eq 'ext_halo' ) {
    $log->debug( "Returning guest mode due to username" );
    return 1;
  } else {
    return 0;
  }
}


###############################################################################
# Utility routine, checks if current user is member of
# PeptideAtlas yeast researchers
# FIXME: make id lookup dynamic
###############################################################################
sub isPAyeastUser {
  my $sbeams = shift;
  my $currID =  $sbeams->getCurrent_contact_id();
  if ( !defined $currID ) {
    return undef;
  } elsif ( ($currID == 215) || ($currID == 52) 
  || ($currID == 64) || ($currID == 318) || ($currID = 461)
  || ($currID == 46) || ($currID == 66) 
  || ($currID == 202) || ($currID == 243)
  ) {
    return 1;
  } else { 
    return 0;
  }
}

#+
#
# Returns hash of privilege names keyed by numeric values
#-
sub getPrivilegeNames {
  my %priv = ( 10 => 'data admin',
               20 => 'data modifier',
               25 => 'data group modifier',
               30 => 'data writer',
               40 => 'data reader',
               50 => 'none',
               999 => 'none',
               9999 => 'none' );
}

#+
# Utility method to fetch id of work group 'Admin' from the database.  There 
# is a fair amount of code that assumes that this will always be 1, this hopes
# to safeguard against cases where it isn't!
#
#-
sub getAdminWorkGroupId {
  my $self = shift;

  # fetch admin_work_group_id
  my ( $admin_gid ) = $self->selectOneColumn( <<"  END_SQL" );
  SELECT WG.work_group_id
  FROM $TB_WORK_GROUP WG
  WHERE WG.work_group_name = 'Admin'
  END_SQL

  return $admin_gid;
}

#+ 
# Method to determine if user is an admin user.  
# narg  current_group  If defined, requires that user is currently in group.
#                      Field is boolean, 1 is yes (require) 0 is no.  Default 1
# narg  contact_id     User to check on, defaults to current contact_id
#                      NOT YET IMPLEMENTED
#-
sub isAdminUser {
  my $self = shift;
  my %args = @_;
  $args{current_group} = 1 if !defined $args{current_group};

  my $current_contact = $self->getCurrent_contact_id();
  my $current_group = $self->getCurrent_work_group_id();
  my $admin_group = $self->getAdminWorkGroupId();

  if ( $admin_group == $current_group ) {
    # We are in Admin group, return 1 regardless
    return 1;
  } elsif ( $args{current_group} ) {
    # We aren't in Admin the group right now, and that was stipulated.
    return 0;
  } else {
    my $sql =<<"    END_SQL";
    SELECT COUNT(*) FROM $TB_USER_WORK_GROUP
    WHERE work_group_id = $admin_group
    AND contact_id = $current_contact
    AND record_status != 'D'
    END_SQL
    my ( $isAdmin ) = $self->selectOneColumn( $sql );
    return $isAdmin;
  }
}

#+
# Returns best permission afforded by any of the groups, *excluding* Admin.
#
#-
sub getBestGroupPermission {
  my $self = shift;
  my $groupref = shift;
  my $min = 9999;
  foreach my $group ( @{$groupref} ) {
    next if $$group[0] =~ /^Admin$/i;
    $min = ( $$group[2] > $min ) ? $min : $$group[2];
  }
  return $min;
}


###############################################################################
###############################################################################
###############################################################################
1;

###############################################################################


