package SBEAMS::Connection::Authenticator;

###############################################################################
# Program     : SBEAMS::Connection::Authenticator
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               authentication to use the system.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw( $q $http_header @ISA @ERRORS
             $current_contact_id $current_username
             $current_work_group_id $current_work_group_name 
             $current_project_id $current_project_name
             $current_user_context_id );

use CGI::Carp qw(fatalsToBrowser croak);
use CGI qw(-no_debug);
use DBI;
use Crypt::CBC;
use Authen::Smb;


use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

$q       = new CGI;


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
# Authenticate the user making the web request.
#
# This is run with every new page, first checking to see if the user already
# has a valid cookie indicating previous login.  If so, return the username,
# else the login process begins.  This is not really terribly secure.
# Login information is not encrypted during transmission unless an
# encryption layer like SSL is used.  The Crypt key should be changed
# frequently for added security.
###############################################################################
sub Authenticate {
    my $self = shift;
    my %args = @_;

    my $set_to_work_group = $args{'work_group'} || "";
    my $connect_read_only = $args{'connect_read_only'} || "";
    my $allow_anonymous_access = $args{'allow_anonymous_access'} || "";
    my $permitted_work_groups_ref = $args{'permitted_work_groups_ref'} || "";


    #### Always disable the output buffering
    $| = 1;


    #### Guess at the current invocation mode
    $self->guessMode();

    #### Obtain the database handle $dbh, thereby opening the DB connection
    my $dbh = $self->getDBHandle(connect_read_only=>$connect_read_only);


    #### If there's a DISABLED file in the main HTML directory, do not allow
    #### entry past here
    if ( -e "$PHYSICAL_BASE_DIR/DISABLED" &&
         $ENV{REMOTE_ADDR} ne "10.0.230.11") {
      $self->printMinimalPageHeader();
      print "<H3>";
      open(INFILE,"$PHYSICAL_BASE_DIR/DISABLED");
      my $line;
      while ($line = <INFILE>) { print $line; }
      close(INFILE);
      $self->printPageFooter();
      exit;
    }


    #### If the effective UID is the apache user, then go through the
    #### cookie authentication mechanism
    my $uid = "$>" || "$<";
    my $www_uid = $self->getWWWUID();
    if ( $uid == $www_uid ) {

        # If the user is not logged in, make them log in
        unless ($current_username = $self->checkLoggedIn(
                allow_anonymous_access=>$allow_anonymous_access)) {
            $current_username = $self->processLogin();
        }

    #### Otherwise, try a command-line authentication
    } else {
        unless ($current_username = $self->checkValidUID()) {
            print STDERR "You (UID=$uid) are not permitted to connect to ".
              "$DBTITLE.\nConsult your $DBTITLE Administrator.\n";
            $self->dbDisconnect();
	  }
    }

    #### If we've obtained a valid user, get additional information
    #### about the user
    if ($current_username) {
        $current_contact_id = $self->getContact_id($current_username);
        $current_work_group_id = $self->getCurrent_work_group_id();
    }


    #### If a permitted list of work_groups was provided or a specific
    #### work_group was provided, verify/switch to that
    if ( $current_username &&
         ($set_to_work_group || $permitted_work_groups_ref) ) {
        $current_work_group_id = $self->setCurrent_work_group(
            set_to_work_group=>$set_to_work_group,
            permitted_work_groups_ref=>$permitted_work_groups_ref,
        );
        $current_username = '' unless ($current_work_group_id);
    }


    return $current_username;

} # end InterfaceEntry


###############################################################################
# Process Login
###############################################################################
sub processLogin {
    my $self = shift;

    my $username  = $q->param('username');
    my $password  = $q->param('password');
    $current_username = "";

    if ($q->param('login')) {
        if ($self->checkLogin($username, $password)) {
            $http_header = $self->createAuthHeader($username);
            $current_contact_id = $self->getContact_id($username);
            $current_username = $username;
        } else {
            $self->printPageHeader(minimal_header=>"YES");
            $self->printAuthErrors();
            $self->printPageFooter();
        }
    } else {
        $self->printPageHeader(minimal_header=>"YES");
        $self->printLoginForm();
        $self->printPageFooter();
    }

    return $current_username;

} # end processLogin


###############################################################################
# guessMode: Guess the current invocation_mode and output_mode
###############################################################################
sub guessMode {
  my $self = shift;

  #### Determine whether we've been invoked by HTTP request or on the
  #### command line by testing for env variable REMOTE_ADDR.  If a
  #### command-line user sets this variable, he can pretend to be coming
  #### from the web interface
  if ($ENV{REMOTE_ADDR}) {
    $self->invocation_mode('http');
    $self->output_mode('html');
  } else {
    $self->invocation_mode('user');
    $self->output_mode('interactive');
    #### Add in a fake reference to MOD_PERL to trick CGI::Carp into
    #### not printing the "Content: text/html\n\n" header
    $ENV{'MOD_PERL'} = 'FAKE'
  }

  return 1;

} # end guessMode


###############################################################################
# get HTTP Header
###############################################################################
sub get_http_header {
    my $self = shift;

    unless ($http_header) {
      $http_header = "Content-type: text/html\n\n";
    }

    return $http_header;

} # end get_http_header


###############################################################################
# checkLoggedIn
#
# Return the username if the user's cookie contains a valid username
###############################################################################
sub checkLoggedIn {
    my $self = shift;
    my %args = @_;

    my $allow_anonymous_access = $args{'allow_anonymous_access'} || "";

    my $username = "";

    if ($main::q->cookie('SBEAMSName')){
        my $cipher = new Crypt::CBC($self->getCryptKey(), 'IDEA');
        $username = $cipher->decrypt($main::q->cookie('SBEAMSName'));
        $username = $self->convertSingletoTwoQuotes($username);

        #### Verify that the deciphered result is still an active username
        my ($result) = $self->selectOneColumn(
            "SELECT username
               FROM $TB_USER_LOGIN
              WHERE username = '$username'
                AND record_status != 'D'"
        );
        $username = "" if ($result ne $username);
    } elsif ($allow_anonymous_access) {
      $username = 'guest';
    }


    return $username;
}


###############################################################################
# checkValidUID
#
# Return the username if the UID belongs to a valid user in the database
###############################################################################
sub checkValidUID {
    my $self = shift;
    my $username = "";

    my $current_uid = "$>" || "$<";

    #### Fix PATH to keep TaintPerl happy
    my $savedENV=$ENV{PATH};
    $ENV{PATH}="";

    my ($uname,$pword,$uid);
    my $element;

    #### Loop over all the local entries to see if this user is there
    my @local_users = `/bin/cat /etc/passwd`;
    foreach $element (@local_users) {
      ($uname,$pword,$uid)=split(":",$element);
      last if ($uid eq $current_uid);
    }

    #### If it wasn't there, check all the NIS users too
    #### It might be faster to use ypmatch instead of ypcat, but
    #### TaintPerl doesn't like user input going into a shell command!
    unless ($uid eq $current_uid) {
      my @NIS_users = `/usr/bin/ypcat passwd`;
      foreach $element (@NIS_users) {
        ($uname,$pword,$uid)=split(":",$element);
        last if ($uid eq $current_uid);
      }
    }


    #### Restore the PATH
    $ENV{PATH}=$savedENV;


    #### If there's a match, then check to make sure it's still in the
    #### database
    if ($uid eq $current_uid) {
        $username = $uname;

        #### Verify that the deciphered result is still an active username
        my ($result) = $self->selectOneColumn(
            "SELECT username
               FROM $TB_USER_LOGIN
              WHERE username = '$username'
                AND record_status != 'D'"
        );
        unless ($result eq $username) {
            print STDERR "ERROR: Your username '$username' is not enabled in ".
                "the database.  See the administrator.\n\n";
            $username = "";
            $self->dbDisconnect();
        }
    }

    return $username;
}


###############################################################################
# Return the contact_id of the user currently logged in
###############################################################################
sub getCurrent_contact_id {
    return $current_contact_id;
}


###############################################################################
# Return the username of the user currently logged in
###############################################################################
sub getCurrent_username {
    return $current_username;
}


###############################################################################
# Set the current work_group_id to that requested by the script if allowed
###############################################################################
sub setCurrent_work_group {
  my $self = shift;
  my %args = @_;

  my $set_to_work_group = $args{'set_to_work_group'} || "";
  my $permitted_work_groups_ref = $args{'permitted_work_groups_ref'} || "";
  my $permanent = $args{'permanent'} || "";


  #### First see what the current work_group context is
  $current_work_group_id = $self->getCurrent_work_group_id()
    unless ($current_work_group_id);
  $current_work_group_name = $self->getCurrent_work_group_name()
    unless ($current_work_group_name);


  #### If a list of permitted work_groups is provided, see which ones
  #### the user can belong to
  if ($permitted_work_groups_ref && (!$set_to_work_group) ) {
    my %work_group_ids = $self->selectTwoColumnHash(
      "SELECT work_group_name,WG.work_group_id
         FROM $TB_USER_WORK_GROUP UWG
         JOIN $TB_WORK_GROUP WG ON ( UWG.work_group_id = WG.work_group_id )
        WHERE UWG.contact_id = '$current_contact_id'
          AND UWG.record_status != 'D'
          AND WG.record_status != 'D'
      ");

    #### If this didn't turn up anything, return
    unless (%work_group_ids) {
      print "ERROR: You are not permitted to act under ".
        "any work group at all and cannot access this page\n\n";
      $self->dbDisconnect();
      return
    }

    #### Loop through the list of permitted work groups and see if we're
    #### already in one of those
    my $already_valid_work_group = 0;
    foreach my $work_group (@{$permitted_work_groups_ref}) {
      if ($work_group eq $current_work_group_name) {
        $already_valid_work_group = 1;
        last;
      }
    }

    #### If so, we're done
    return $current_work_group_id if ($already_valid_work_group);

    #### If not, set it to the first valid one
    $set_to_work_group = "";
    foreach my $work_group (@{$permitted_work_groups_ref}) {
      if ($work_group_ids{$work_group}) {
        $set_to_work_group = $work_group;;
        last;
      }
    }

    #### If this didn't turn up anything, return
    unless ($set_to_work_group) {
      $self->displayPermissionToPageDenied(
        ["You are not a member of any of the work groups that are ".
        "permitted to to access this page"]);
      $self->dbDisconnect();
      return
    }

  }


  #### Find the ID for the requested work_group
  my ($work_group_id) = $self->selectOneColumn("
       SELECT work_group_id
         FROM $TB_WORK_GROUP
        WHERE work_group_name = '$set_to_work_group'
          AND record_status != 'D'
  ");

  #### If this didn't turn up anything, return
  unless ($work_group_id) {
      print STDERR "ERROR: The specified group $set_to_work_group does ".
        "not exist\n\n";
      $self->dbDisconnect();
      return;
  }


  #### See if this user can be a member of this group
  my ($result) = $self->selectOneColumn("
       SELECT work_group_id
         FROM $TB_USER_WORK_GROUP
        WHERE contact_id = '$current_contact_id'
          AND work_group_id = '$work_group_id'
          AND record_status != 'D'
  ");

  #### If this didn't turn up anything, return
  unless ($result) {
      print "ERROR: You are not permitted to act under ".
          "group $set_to_work_group\n\n";
      $self->dbDisconnect();
      return
  }


  #### See what the current context is set to and return success if we're
  #### set already to the desired group
  ($current_work_group_id) = $self->selectOneColumn("
       SELECT work_group_id
         FROM $TB_USER_CONTEXT
        WHERE contact_id = '$current_contact_id'
          AND record_status != 'D'
  ");
  if ($current_work_group_id == $work_group_id) {
    return $current_work_group_id;
  }


  #### We need to change groups, so set the current context variables
  $current_work_group_id = $work_group_id;
  $current_work_group_name = $set_to_work_group;


  #### If this is a permanent change (i.e. not transient for this one
  #### session which is the default) then update the database
  if ($permanent) {
    $self->executeSQL("
      UPDATE $TB_USER_CONTEXT
         SET work_group_id = $work_group_id,
         modified_by_id = $current_contact_id,
         date_modified = CURRENT_TIMESTAMP
       WHERE contact_id = $current_contact_id
    ");
  }


  #### If we haven't successfully set the work_group, disconnect!
  $self->dbDisconnect() unless ($current_work_group_id);

  return $current_work_group_id;
}



###############################################################################
# Return the work_group_id of the user currently logged in
###############################################################################
sub getCurrent_work_group_id {
    my $self = shift;

    #### If the current_work_group_id is already known, return it
    return $current_work_group_id
      if (defined($current_work_group_id) && $current_work_group_id > 0);
    if ($current_contact_id < 1) {
      print STDERR "current_contact_id undefined!!  Authentication must ".
        "have failed!\n\n";
      exit 1;
    }

    #### Otherwise, see if it's in the user_context table
    ($current_work_group_id) = $self->selectOneColumn(
        "SELECT work_group_id
           FROM $TB_USER_CONTEXT
          WHERE contact_id = $current_contact_id
            AND record_status != 'D'
        ");
    if ($current_work_group_id > 0) { return $current_work_group_id; }

    #### Not there, so let's just set it to the first group for this user
    ($current_work_group_id) = $self->selectOneColumn(
        "SELECT work_group_id
           FROM $TB_USER_WORK_GROUP
          WHERE contact_id = $current_contact_id
            AND record_status != 'D'
        ");
    if ($current_work_group_id > 0) {
        $self->executeSQL(
            "INSERT INTO $TB_USER_CONTEXT (contact_id,work_group_id,
              created_by_id,modified_by_id )
              VALUES ( $current_contact_id,$current_work_group_id,
              $current_contact_id,$current_contact_id )
            ");
        return $current_work_group_id;
    }

    #### This user apparently does not belong to any groups, so set to Other
    $current_work_group_id = 2;

    return $current_work_group_id;
}

###############################################################################
# Return the work_group_name of the user currently logged in
###############################################################################
sub getCurrent_work_group_name {
    my $self = shift;

    #### If the current_work_group_name is already known, return it
    return $current_work_group_name
      if (defined($current_work_group_name) && $current_work_group_name gt "");
    if ($current_work_group_id < 1) {
      $current_work_group_id = $self->getCurrent_work_group_id();
    }

    #### Extract the name from the database given the ID
    ($current_work_group_name) = $self->selectOneColumn(
        "SELECT work_group_name
           FROM $TB_WORK_GROUP
          WHERE work_group_id = $current_work_group_id
            AND record_status != 'D'
        ");

    return $current_work_group_name;
}


###############################################################################
# Return the active project_id of the user currently logged in
###############################################################################
sub getCurrent_project_id {
    my $self = shift;

    #### If the current_project_id is already known, return it
    return $current_project_id
      if (defined($current_project_id) && $current_project_id > 0);
    if ($current_contact_id < 1) { die "current_contact_id undefined!!"; }

    #### Otherwise, see if it's in the user_context table
    ($current_project_id,$current_user_context_id) = $self->selectOneColumn(
        "SELECT project_id,user_context_id
           FROM $TB_USER_CONTEXT
          WHERE contact_id = $current_contact_id
            AND record_status != 'D'
        ");
    if (defined($current_project_id) && $current_project_id > 0) {
      return $current_project_id;
    }

    #### This user has not selected an active project, so leave it 0
    $current_project_id = 0;

    return $current_project_id;
}


###############################################################################
# Set the active project_id of the user currently logged in
###############################################################################
sub setCurrent_project_id {
  my $self = shift;
  my %args = @_;


  #### Process the arguments list
  my $set_to_project_id = $args{'set_to_project_id'} || "";


  #### First see what the current project context is
  $current_project_id = $self->getCurrent_project_id()
    unless ($current_project_id > 0);


  #### If the desired project_id is the current one, then just return it
  return($current_project_id) if ($set_to_project_id == $current_project_id);


  #### Define some generic varibles
  my ($i,$element,$key,$value,$line,$result,$sql);


  #### Get a list of project_ids that the user can access
  if ($set_to_project_id > 0) {
    $sql = qq~
	SELECT P.project_id,P.name
	  FROM $TB_PROJECT P
	  JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id = UL.contact_id )
	  LEFT JOIN $TB_USER_PROJECT_PERMISSION UPP
	       ON ( P.project_id = UPP.project_id
	            AND UPP.contact_id = '$current_contact_id' )
	  LEFT JOIN $TB_GROUP_PROJECT_PERMISSION GPP
	       ON ( P.project_id = GPP.project_id )
	  LEFT JOIN $TB_USER_WORK_GROUP UWG
	       ON ( GPP.work_group_id = UWG.work_group_id
	            AND UWG.contact_id = '$current_contact_id' )
	 WHERE P.record_status != 'D'
	   AND ( UPP.privilege_id<=40 OR GPP.privilege_id<=40
	         OR P.PI_contact_id = '$current_contact_id')
    ~;
    my %allowed_project_ids = $self->selectTwoColumnHash($sql);


    #### If this didn't turn up anything, return
    unless (exists($allowed_project_ids{$set_to_project_id})) {
      print "Content-type: text/html\n\n".
        "ERROR: You are not permitted to access ".
        "project_id $set_to_project_id\n\n";
      return
    }


    #### We need to change groups, so set the group here
    $self->executeSQL("
      UPDATE $TB_USER_CONTEXT
         SET project_id = '$set_to_project_id',
         modified_by_id = '$current_contact_id',
         date_modified = CURRENT_TIMESTAMP
       WHERE contact_id = '$current_contact_id'
    ");

    $current_project_id = $set_to_project_id;
    $current_project_name = $allowed_project_ids{$set_to_project_id};

  }


  return $current_project_id;

}



###############################################################################
# Return the active user_context_id of the user currently logged in
###############################################################################
sub getCurrent_user_context_id {
    my $self = shift;

    #### If the current_user_context_id is already known, return it
    return $current_user_context_id
      if (defined($current_user_context_id) && $current_user_context_id > 0);
    if ($current_contact_id < 1) { die "current_contact_id undefined!!"; }

    #### Otherwise, see if it's in the user_context table
    ($current_user_context_id) = $self->selectOneColumn(
        "SELECT user_context_id
           FROM $TB_USER_CONTEXT
          WHERE contact_id = $current_contact_id
            AND record_status != 'D'
        ");

    return $current_user_context_id;
}


###############################################################################
# Return the active project_name of the user currently logged in
###############################################################################
sub getCurrent_project_name {
    my $self = shift;

    #### If the current_project_name is already known, return it
    return $current_project_name
      if (defined($current_project_name) && $current_project_name gt "");
    if ($current_project_id < 1) {
      $current_project_id = $self->getCurrent_project_id();
    }

    #### If there is no current_project_id, return a name of "none"
    if ($current_project_id < 1) {
      $current_project_name = "[none]";
    } else {
      #### Extract the name from the database given the ID
      ($current_project_name) = $self->selectOneColumn(
        "SELECT name
           FROM $TB_PROJECT
          WHERE project_id = $current_project_id
            AND record_status != 'D'
        ");
    }

    return $current_project_name;
}

###############################################################################
# 
###############################################################################
sub printLoginForm {
    my $self = shift;
    my $login_message = shift;

    my $table_name = $q->param('TABLE_NAME');

    print qq!
	<H2>$DBTITLE Login</H2>
	$LINESEPARATOR
    !;

    print qq!
	<TABLE WIDTH=$MESSAGE_WIDTH><TR><TD>
	$login_message
	</TD></TR></TABLE>
	$LINESEPARATOR
    ! if $login_message;

    print qq!
        <FORM METHOD="post">
        <TABLE BORDER=0><TR>
        <TD><B>Username:</B></TD>
        <TD><INPUT TYPE="text" NAME="username" SIZE=15></TD>
        </TR><TR>
        <TD><B>Password:</B></TD>
        <TD><INPUT TYPE="password" NAME="password" SIZE=15></TD>
        </TR><TR>
        <TD COLSPAN=2 ALIGN="center">
        <BR>
        <INPUT TYPE="submit" NAME="login" VALUE=" Login ">
        <INPUT TYPE="reset" VALUE=" Reset ">
    !;

    #### Put all passed parameters into a hidden field here so if
    #### authentication succeeds, they are passed to the called program.
    my ($key,$value);
    foreach $key ( $q->param ) {
      $value = $q->param($key);
      print qq~<INPUT TYPE="hidden" NAME="$key" VALUE="$value">\n~;
    }

    print qq!
        </TD>
        </TR></TABLE>
        </FORM>
        $LINESEPARATOR
    !;
}


###############################################################################
# 
###############################################################################
sub printAuthErrors {
    my $self = shift;
    my $ra_errors = shift || \@ERRORS;

    my $back_button = $self->getGoBackButton();

    print qq!
        <CENTER>
        <H2>$DBTITLE Login Failed</H2>
        Your login failed because of the following Reasons.
        </CENTER>
        <BR><BR>
        <BLOCKQUOTE>
    !;

    foreach my $error (@{$ra_errors}) { print "<LI>$error<P>\n"; }

    print qq!
        </BLOCKQUOTE>
        <CENTER>
        $back_button
        </CENTER>
    !;
}


###############################################################################
# 
###############################################################################
sub displayPermissionToPageDenied{
  my $self = shift;
  my $ra_errors = shift || \@ERRORS;

  my $back_button = $self->getGoBackButton();
  my $start_line = " - ";
  my $end_line = "\n";

  $self->printPageHeader(minimal_header=>"YES");

  if ($self->output_mode() eq 'html') {
    print qq~
      <CENTER>
      <H2>$DBTITLE Access Permission Denied</H2>
      You are not allowed to access this page for the following reasons
      </CENTER>
      <BR><BR>
      <BLOCKQUOTE>
    ~;
    $start_line = "<LI>";
    $end_line = "<P>\n";
  } else {
    print "ERROR: Permission to access this page denied:\n";
  }


  foreach my $error (@{$ra_errors}) {
    print "$start_line$error$end_line";
  }

  if ($self->output_mode() eq 'html') {
    print qq~
      </BLOCKQUOTE>
      <CENTER>
      $back_button
      </CENTER>
    ~;
  }

  $self->printPageFooter();

}


###############################################################################
# 
###############################################################################
sub destroyAuthHeader {
    my $self = shift;

    my $current_username = $self->getCurrent_username;
    my $logging_query="INSERT INTO $TB_USAGE_LOG
	(username,usage_action,result)
	VALUES ('$current_username','logout','SUCCESS')";
    $self->executeSQL($logging_query);

    #### Fixed to set cookie path to tree root instead of possibly middle
    #### which then requires reauthentication when moving below entry point
    #my $cookie_path = $q->url(-absolute=>1);
    my $cookie_path = $HTML_BASE_DIR;
    #$cookie_path =~ s'/[^/]+$'/'; Removed 6/7/2002 Deutsch

    my $cookie = $q->cookie(-name    => 'SBEAMSName',
                            -path    => "$cookie_path",
                            -value   => '0',
                            -expires => '-25h');
    $http_header = $q->header(-cookie => $cookie);

    return $http_header;
}


###############################################################################
# 
###############################################################################
sub createAuthHeader {
    my $self = shift;
    my $username = shift;

    #### Fixed to set cookie path to tree root instead of possibly middle
    #### which then requires reauthentication when moving below entry point
    #my $cookie_path = $q->url(-absolute=>1);
    my $cookie_path = $HTML_BASE_DIR;
    #$cookie_path =~ s'/[^/]+$'/'; Removed 6/7/2002 Deutsch

    my $cipher = new Crypt::CBC($self->getCryptKey(), 'IDEA');
    my $encrypted_user = $cipher->encrypt("$username");

    my $cookie = $q->cookie(-name    => 'SBEAMSName',
                            -path    => "$cookie_path",
                            -value   => "$encrypted_user");
    my $head = $q->header(-cookie => $cookie);

    return $head;
}



###############################################################################
# fetch Errors
#
# Return a reference to the @ERRORS array
###############################################################################
sub fetchErrors {
    my $self = shift;

    return \@ERRORS || 0;
}


###############################################################################
# check Login
#
# Compare the supplied username and password with the login information in
# the database, and return success if the information is valid.
###############################################################################
sub checkLogin {
    my $self = shift;
    my $user = shift;
    my $pass = shift;
    my $logging_query = "";

    my $success = 0;
    my $failed = 0;
    my $error_code = '????';
    @ERRORS  = ();

    #### Set this to 1 to get more useful messages like why the login failed.
    #### Set this to 0 to just get stone-faced "Login Incorrect" messages
    my $more_helpful_message = 1;


    #### Find this user in the user_login table
    my %query_result = $self->selectTwoColumnHash(
        "SELECT username,password
           FROM $TB_USER_LOGIN
          WHERE username = '$user'
            AND record_status != 'D'
        ");


    #### If this user is not in the user_login table, don't look any further
    unless (exists $query_result{$user}) {
      if ($more_helpful_message) {
        push(@ERRORS, "This username is not registered in the system");
      } else {
	push(@ERRORS, "Login Incorrect");
      }
      $success = 0;
      $failed = 1;
      $error_code = 'NON-EXISTENT SBEAMS USERNAME';

    #### If this user is in the user_login table but has no encrypted
    #### password, then try to obtain it from /etc/passwd and NIS
    } else {
      unless ($query_result{$user}) {
        $query_result{$user} = $self->getUnixPassword($user);
      }
    }


    #### If there is an encrypted password, test it
    if ($failed == 0 && $query_result{$user}) {
      if (crypt($pass, $query_result{$user}) eq $query_result{$user}) {
        $success = 1;
        $error_code = 'SUCCESS';
      } else {
        if ($more_helpful_message) {
          push(@ERRORS, "Incorrect password for this username");
        } else {
          push(@ERRORS, "Login Incorrect");
        }
        $success = 0;
        $error_code = 'INCORRECT PASSWORD';
      }
    }


    #### If success is still 0 but we haven't failed, try SMB Authentication
    if ($success == 0 && $failed == 0) {
      my $authResult = Authen::Smb::authen($user,$pass,
        'ISB-DC1','PRINT','ISB');
      if ( $authResult == 0 ) {
        $success = 1;
        $error_code = 'SUCCESS (SMB)';

      } elsif ( $authResult == 3 ) {
        if ($more_helpful_message) {
          push(@ERRORS, "Incorrect password for this username");
        } else {
          push(@ERRORS, "Login Incorrect");
        }
        $success = 0;
        $error_code = 'INCORRECT PASSWORD';

      } else {
        if ($more_helpful_message) {
          push(@ERRORS, "ERROR communication with Domain Controller");
        } else {
          push(@ERRORS, "Login Incorrect");
        }
        $success = 0;
        $error_code = 'UNABLE TO CONTACT DC';
      }

    }


    #### Register the outcome of this attempt
    $logging_query = qq~
	INSERT INTO $TB_USAGE_LOG (username,usage_action,result)
	VALUES ('$user','login','$error_code')
    ~;

    $self->executeSQL($logging_query);

    return $success;
}


###############################################################################
# getUnixPassword
#
# Return the (encrypted) yp passwd for the supplied user
###############################################################################
sub getUnixPassword {
    my $self = shift;
    my $username = shift;
    my $password = 0;

    #### Fix PATH to keep TaintPerl happy
    my $savedENV=$ENV{PATH};
    $ENV{PATH}="";

    #### Collect the list of all passwds.  Using ypmatch would be more
    #### efficient, but sending user-supplied data to a shell is dangerous
    my ($uname,$pword,$uid);
    my $element;


    #### Loop over all the local entries to see if this user is there
    my @local_users = `/bin/cat /etc/passwd`;
    foreach $element (@local_users) {
      ($uname,$pword,$uid)=split(":",$element);
      last if ($uname eq $username);
    }

    #### If it wasn't there, check all the NIS users too
    #### It might be faster to use ypmatch instead of ypcat, but
    #### TaintPerl doesn't like user input going into a shell command!
    unless ($uname eq $username) {
      my @NIS_users = `/usr/bin/ypcat passwd`;
      foreach $element (@NIS_users) {
        ($uname,$pword,$uid)=split(":",$element);
        last if ($uname eq $username);
      }
    }


    if ($uname eq $username) {
        $password = $pword;
    } else {
        push(@ERRORS, "$username is not a valid UNIX username, so ".
          "database cannot have blank password");
    }

    #### Restore the PATH
    $ENV{PATH}=$savedENV;

    return $password;
}


###############################################################################
# 
###############################################################################
sub getContact_id {
    my $self = shift;
    my $username = shift;

    my $sql_query = qq~
	SELECT contact_id
	  FROM $TB_USER_LOGIN
	 WHERE username = '$username'
	   AND record_status != 'D'
    ~;

    my ($contact_id) = $self->selectOneColumn($sql_query);

    return $contact_id;
}


###############################################################################
# getUsername
###############################################################################
sub getUsername {
    my $self = shift;
    my $contact_id = shift;

    my $sql_query = qq~
	SELECT username
	  FROM $TB_USER_LOGIN
	 WHERE contact_id = '$contact_id'
	   AND record_status != 'D'
    ~;

    my ($username) = $self->selectOneColumn($sql_query);

    return $username;
}


###############################################################################
# get_work_group_id
###############################################################################
sub get_work_group_id {
    my $self = shift;
    my $work_group_name = shift;

    return unless ($work_group_name);

    my $sql_query = qq~
	SELECT work_group_id
	  FROM $TB_WORK_GROUP
	 WHERE work_group_name = '$work_group_name'
	   AND record_status != 'D'
    ~;

    my ($work_group_id) = $self->selectOneColumn($sql_query);

    return $work_group_id;
}




###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::Authenticator

SBEAMS Core authentication methods

=head2 SYNOPSIS

See SBEAMS::Connection for usage synopsis.

=head2 DESCRIPTION

This module is inherited by the SBEAMS::Connection module, although it
can be used on its own.  Its main function is to provide a set of
authentication methods for this application.

It uses cookie authentication, where when a user logs in successfully
through a web form, a cookie is placed in the users web browser.  The
web interface then knows how to look for and find this cookie, and can
then tell who the user is, and if they have been authenticated to use
the interface or not.

=head2 METHODS

=over

=item * B<checkLoggedIn()>

    Checks to see if the current user is logged in.  This
    is done by searcing for the cookie that SBEAMS places
    in the users web browser when they first log in.

    (Errors will be loaded into the ERROR array, to be retrieved 
     with fetchErrors() or printed with printAuthErrors())

    Accepts: null
        
    Returns: $scalar
        login_name for success
        0          for failure

=item * B<printLoginForm($loginmessage)>

    Prints a standard login form. A text box for the username, 
    a text box for a password, and a submit button.  A message 
    can also be printed above the form, if one is passed in.

    Accepts: $scalar or null 

    Returns: 
        1 for success

=item * B<checkLogin($user_name, $password)>

    Checks the username and password to see if the user has
    an account to access this application, and if the
    supplied password is correct.

    (Errors will be loaded into the @ERROR array, to be retrieved 
     with fetchErrors() or printed with printAuthErrors())

    Accepts: $user_name, $password (both are required!)

    Returns: 
        1 for success
        0 for failure

=item * B<fetchErrors()>

    Simply returns an array of errors, or reasons, that a 
    method was not successful. (ex: "Invalid username", 
    "Wrong password", ...)  

    Accepts: null

    Returns: 
        @array if there are errors
        0      if there are no errors

=item * B<printAuthErrors()>

    Prints the errors, or resaons, that a mthod was not
    successfull in a nice HTML list.  You can use this 
    method rather than retrieving the array and generating
    the HTML list yourself.

    Accepts: null

    Returns: 
        1 for success

=item * B<createAuthHeader($user_name)>

    Creates a cookie header that will place the users 
    username in their browser so that we can retrieve it later.

    Accepts: $user_name

    Returns:
        1 for success

=item * B<destroyAuthHeader()>

    Call this when a user wants to log out.  This will remove 
    the cookie that we placed in the users browser, and require 
    them to enter their username and password the next time they 
    want to access any part of this interface. 

    Accepts: null

    Returns:
        1 for success

=item * B<checkIfUploader($user_name)>

    Checks the database to find out if the user has uploader 
    privelages to load experiments into this system.  

    (Errors will be loaded into the @ERROR array, to be retrieved 
     with fetchErrors() or printed with printAuthErrors())

    Accepts: $user_name

    Returns:
        $username for success
        0         for failure

=item * B<checkIfAdmin($user_name)>

    Checks the database to find out if the user has administrator
    privelages to control this system.

    (Errors will be loaded into the @ERROR array, to be retrieved
     with fetchErrors() or printed with printAuthErrors())

    Accepts: $user_name

    Returns:
        $username for success
        0         for failure

=item * B<checkUserHasAccess($user_name, $experiment_name)>

    Checks the database to see if the usere really has access to 
    this experiment.  This is checked before any data is returned 
    to make sure that a user can not access another users data.

    (Errors will be loaded into the @ERROR array, to be retrieved
     with fetchErrors() or printed with printAuthErrors())

    Accepts: $user, $experiment (name or id for either is fine)

    Returns:
        'OK' for success
        0    for failure

=item * B<getUsersID($user_name)>

    Gets the user id number for this user.  Commonly used by other 
    methods of this system.

    Returns:
        $user_id for success
        0        for failure



=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut
