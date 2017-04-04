package SBEAMS::Connection::Authenticator;

###############################################################################
# Program     : SBEAMS::Connection::Authenticator
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               authentication to use the system.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw( $q $http_header $log @ISA $DBTITLE $SESSION_REAUTH @ERRORS
             $current_contact_id $current_username $LOGIN_DURATION
             $current_work_group_id $current_work_group_name $LOGGING_LEVEL 
             $current_project_id $current_project_name $current_project_tag $SMBAUTH
             $current_user_context_id @EXPORT_OK $LDAPAUTH );

use vars qw( %session $session_string );
use Storable qw( nstore retrieve );

use CGI::Carp qw(croak);
use CGI qw(-no_debug);
use DBI;
use Crypt::CBC;
use Authen::Smb;
use Net::LDAPS;

use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings qw(:default $SESSION_REAUTH $LOGIN_DURATION $SMBAUTH $LDAPAUTH);
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::Log;
$log = SBEAMS::Connection::Log->new();

# We will export a CGI object ($q) upon request.
use Exporter;

our @ISA = qw( Exporter );

# Set size of permissible uploads to 30 MB.
$CGI::POST_MAX = 1024 * 30000;
$q = new CGI;

@EXPORT_OK = qw( $q );

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
# Authenticate the user making the request.
#
# This is run with every request, first checking to see if the user already
# has a valid cookie indicating previous login.  If so, return the username,
# else the login process begins.  This is not really terribly secure.
# Login information is not encrypted during transmission unless an
# encryption layer like SSL is used.  The Crypt key should be changed
# frequently for added security.
###############################################################################
sub Authenticate {
  my $self = shift;
  my $SUBNAME = "Authenticate";
  my %args = @_;

  my $set_to_work_group = $args{'work_group'} || "";
  my $connect_read_only = $args{'connect_read_only'} || "";
  my $allow_anonymous_access = $args{'allow_anonymous_access'} || "";
  my $permitted_work_groups_ref = $args{'permitted_work_groups_ref'} || "";

  ## Clean up authentication tokens if requested - NRFPT
#	if ( $q->param('clear_auth') ) {
#    $q->delete( 'SBEAMSentrycode' );
#    $self->destroyAuthHeader();
#		print STDERR "clear auth in Authenticate   \n";
#	}

  #### Always disable the output buffering
  $| = 1;

  #### Guess at the current invocation mode
  $self->guessMode();

  #### Obtain the database handle $dbh, thereby opening the DB connection
  my $dbh = $self->getDBHandle(connect_read_only=>$connect_read_only);

  #### If there's a DISABLED file in the main sbeams directory, do not allow
  #### entry past here.  Same goes for DISABLE.modulename
  my $module_name = $self->getSBEAMS_SUBDIR() || '';

  my $file = '';
  if ( -e "$PHYSICAL_BASE_DIR/DISABLED" ) {
    $file = "$PHYSICAL_BASE_DIR/DISABLED"; 
  } elsif ( -e "$PHYSICAL_BASE_DIR/DISABLED.$module_name" ) {
    $file = "$PHYSICAL_BASE_DIR/DISABLED.$module_name";
  }

  if ( $file ) {
    my $server_name = ($file =~ /DISABLED$/) ? 'SBEAMS' : "SBEAMS $module_name";

    # Get message from disabled file, or else use default
    my $message = "$server_name is currently unavailable (reason unknown)";

    if ( open(INFILE, $file ) ) {
      undef local $/;
      $message = <INFILE>;
      close(INFILE);
    }

    if ( $self->output_mode eq 'html' ) {
      $self->printPageHeader( minimal_header => "YES", navigation_bar => 'NO' );
      print qq~
        <BR><H3>$message</H3><BR><BR>
      ~;
      $self->printPageFooter();
    } else {
      $self->handle_error( message => $message,
                           error_type => 'server_disabled' );
    }
    exit;
  }

  #### Get the cookies from the request
  # SBEAMSName == Autentication cookie
  # SBEAMSession == Session cookie
  # SBEAMUI == ui cookie
  my %cookie = $q->cookie('SBEAMSName');
  $self->{_cgi} = $q; # Cache the cgi object for the less fortunate...
  my $session_cookie = $self->getSessionCookie();
  #$log->debug("session_cookie=\n".Data::Dumper->Dump([$session_cookie]));
  if (scalar(keys(%{$session_cookie}))) {
    my $tmp = $self->getSessionAttribute(key=>'session_started_date');
    #$log->debug("session data=\n".Data::Dumper->Dump([\%session]));
  }

  # Process SBEAMS UI cookie if it exists.
  $self->processSBEAMSuiCookie();

  #### If the effective UID is the apache user, then go through the
  #### cookie authentication mechanism
  my $uid = "$>" || "$<";
  my $www_uid = $self->getWWWUID();
  if ( $uid == $www_uid && !$q->param('force_login') ) {
    # We are presumably here due to a cgi request.

    unless(scalar(keys(%{$session_cookie}))) {
      $session_cookie = $self->createSessionCookie();
      $self->{_session_cookie} = $session_cookie;
      $http_header = $q->header(-cookie => $session_cookie);
      $self->setSessionAttribute(
        key=>'session_started_date',
        value=>time(),
      );
    }

    $current_username = $self->processLogin(cookie_ref => \%cookie);

    # Has cookie/login processing obtained a valid username?
    if ( !$current_username ) {
      $log->debug( "Testing alternate authentication modes" );

      # Otherwise use SBEAMSentrycode if defined
      if ( $q->param('SBEAMSentrycode') ) {
        my $entrycode = $q->param('SBEAMSentrycode');
        $entrycode =~ s/^\s+//;
        $entrycode =~ s/\s+$//;

        $log->info( "Using entry code" );
        $current_username = $DBCONFIG->{$DBINSTANCE}->{ENTRYCODE}->{$entrycode};
        if ( $current_username ) {
          $http_header = $self->createAuthHeader(
            username => $current_username,
            session_cookie => $session_cookie,
          );
        } else {
          print $self->get_http_header();
          $self->printAuthErrors( ["Invalid or expired entrycode used, please check and try again"] );
          $log->warn( "Entry code was specified but not in config file" );
          $log->info( "Entry code was specified but not in config file" );
          exit;
        }

      # Allow anonymous access?
      } elsif ( !$current_username && $allow_anonymous_access ) {
        $log->info( "allowing guest authentication" );
        $current_username = 'guest';
        $current_contact_id = $self->getContact_id($current_username);
        $current_work_group_id = $self->getCurrent_work_group_id();
        return $current_username;
      }
    }
  } elsif ( !$q->param('force_login') ) { # Otherwise, try a command-line authentication
    unless ($current_username = $self->checkValidUID()) {
    $log->error( <<"    ERR" );
    You (UID=$uid) are not permitted to connect to $DBTITLE.
    Please consult your $DBTITLE Administrator.
    ERR
    return;
    }
  }

  # Haven't been able to authenticate, force login
  if ( !$current_username ) {

    # If we have cookie (forced login), destroy it
    $self->destroyAuthHeader() if %cookie;

    if ( $self->output_mode eq 'html' ) {
      # Draw a login form for the user to fill out
      $self->printPageHeader(minimal_header=>"YES");
      $self->printLoginForm();
      $self->printPageFooter();
    } else {
      my $msg = "Must provide valid authentication to access this resource";
      $self->handle_error( message => $msg,
                           error_type => 'authen_required' );
    }
#    } elsif ( requestingNoAuthPage() ) {
#      # This is a dead end at the login page...

# return $current_username;
  } else {

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
            allow_anonymous_access=>$allow_anonymous_access,
        );
        $current_username = '' unless ($current_work_group_id);
  }

	# Global var getting corrupted?
	$self->{_current_username} = $current_username;
  return $current_username;

} # end Authenticate

sub requestingNoAuthPage {
  my $url = $q->url( -absolute => 1 );
  return 1 if $url eq 'logout.cgi';
  $log->info( "Requesting $url, authentication not required" );
  return 0;
}

#+
# Checks the format of user configured cookie shelf life.
#-
sub isValidDuration {
  my $self = shift;
  my %args = @_;
  return 0 unless $args{cookie_duration}; 

#    return 1 if $args{cookie_duration} =~ /^[+-]+\d+[hm]+$/i;
#   opted against fancy time specs  
  return ( $args{cookie_duration} =~ /^\d+$/i ) ? $args{cookie_duration} : 0;
}

#+
# Checks the validity of authentication information, in the form of cookies 
# or username/password.  Returns a username if successful.
#-
sub processLogin {
  my $self = shift;
  my %args = @_;

  # various options
  my %cookie = %{$args{cookie_ref}};

  my $new_cookie = 1;
  my $user  = $q->param('username');
  my $pass  = $q->param('password');
  my $login = $q->param('login');
  $current_username = '';
  
  # For security's sake, delete these from the cgi object upon login.
  $q->delete( 'username', 'password' ) if $login;

  my $chours = $self->isValidDuration(cookie_duration => $LOGIN_DURATION) || 24;
  my $csecs = $chours * 3600;

  # Define mid-point of cookie life, re-issue if more than half gone.
  my $half_eaten = int( $csecs/2 );
  
  # If user and pass were given in login context, use the info.
  if ( ($user && $pass && $login) ) { 
    if ($self->checkLogin($user, $pass)) {

      $http_header = $self->createAuthHeader(username => $user);
      $current_contact_id = $self->getContact_id($user);
      $current_username = $user;
      # $log->info( "User $user connected from " . $q->remote_host() );
    } else {
      $log->warn( "username ($user) failed checkLogin" );
      $log->info( "User $user failed to connect from " . $q->remote_host() );
      if ( $self->output_mode() eq 'html' ) {
        $self->printPageHeader(minimal_header=>"YES");
        $self->printAuthErrors();
        $self->printPageFooter();
      } else {
        $self->handle_error( error_type => 'authen_errors',
                                message => join(", ", @ERRORS ) );
      }
      exit;
    } 

  } elsif ( %cookie ) { # cookie exists

    # SBEAMSName cookie has single key->value pair, time => crypted username
    ( my $cookie_time ) = keys( %cookie );

    # Check validity of cookie information
    my $valid_username = $self->checkCachedAuth( name => $cookie{$cookie_time},
                                                 ctime => $cookie_time );


    if ( $valid_username ) {  # Cookie is valid, check for expiration

      my $curr_time = time;

      # Calculate difference between current time and cookie creation time.
      my $time_diff = $curr_time - $cookie_time;
      my $stale = $csecs - $time_diff;

      # Is cookie expired?
      if ( $stale <= 0 ) { # Cookie is stale (expired)
        $log->info( "Expired cookie, forcing reauthentication" );

      } else {
        if ( $stale < $half_eaten || $time_diff < 0 ) {
          # The cookie is in its final 60 minutes of validity, or postdated
          $http_header = $self->createAuthHeader(username=>$valid_username);
          $log->info( "Cookie will expire soon or is postdated, reissuing" );
        }
        $current_username = $valid_username;
        $current_contact_id = $self->getContact_id($valid_username);
      }

    } else {
      $log->error( "Invalid cookie submitted" ) unless $valid_username;
    }
  }

  return $current_username;

} # end processLogin


###############################################################################
# guessMode: Guess the current invocation_mode and output_mode
###############################################################################
sub guessMode {
  my $self = shift;

  my $mode = $q->param( 'output_mode' );
  if ( defined $mode ) {
    $self->output_mode( $mode );
    return;
  }
  #### Determine whether we've been invoked by HTTP request or on the
  #### command line by testing for env variable REMOTE_ADDR.  If a
  #### command-line user sets this variable, he can pretend to be coming
  #### from the web interface
  if ($ENV{REMOTE_ADDR}) {
    $self->invocation_mode('http');
    $self->output_mode('html');
    # If we are in html output mode send errors to browser - many cgi's already
    # use this anyway. 
    eval "use CGI::Carp qw( fatalsToBrowser )";
  } else {
    $self->invocation_mode('user');
    $self->output_mode('interactive');
    #### Add in a fake reference to MOD_PERL to trick CGI::Carp into
    #### not printing the "Content: text/html\n\n" header
    # $ENV{'MOD_PERL'} ||= 'FAKE'
    ## Re-delete this, because die in command-line scripts
    ### Reinstated with the ||= syntax.  This keeps CGI::Carp from printing 
    ### a header upon die, allowing us to do it explicitly (and print the 
    ### appropriate Content-Type).
    #### Removed this 2005-06-23 EWD.  It's been here for years, but causes
    #### a problem at other sites.  I think it's best we try without this.
  }

  return 1;

} # end guessMode


###############################################################################
# checkCachedAuth
#
# Return the username if the user's cookie contains a valid username
###############################################################################
sub checkCachedAuth {
  my $self = shift;
  my %args = @_;

  # Must have passed both time and username for validation
  return 0 unless $args{name} && $args{ctime};

  # Time must be a 10-digit integer 
  return 0 unless $args{ctime} =~ /^\d{10}$/;

  my $cipher = new Crypt::CBC( {
				key => $self->getCryptKey(),
				cipher => 'IDEA',
				prepend_iv => 0,
				iv => 'd%&jHE3%',
			       } );

  $args{name} = $cipher->decrypt($args{name});
  my $sql_name = $self->convertSingletoTwoQuotes($args{name});

  # Verify that the deciphered result is still an active username
  my ($result) = $self->selectOneColumn( <<"  END" );
  SELECT COUNT(contact_id)
  FROM $TB_USER_LOGIN
  WHERE username = '$sql_name'
  AND record_status != 'D'
  END

  return ( $result ) ? $args{name} : 0;
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
      if ($uid) {
        last if ($uid eq $current_uid);
      }
    }

    #### If it wasn't there, check all the NIS users too
    #### It might be faster to use ypmatch instead of ypcat, but
    #### TaintPerl doesn't like user input going into a shell command!
    unless ($uid && $uid eq $current_uid) {
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
  my $self = shift;
#  return $current_username || '';
  return ( $current_username ) ? $current_username : $self->{_current_username};
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
  my $allow_anonymous = $args{'allow_anonymous_access'} || "";

  #### First see what the current work_group context is
  $current_work_group_id = $self->getCurrent_work_group_id()
    unless ($current_work_group_id);
  $current_work_group_name = $self->getCurrent_work_group_name()
    unless ($current_work_group_name);

  my $guest_clause = '';
  unless ( $self->isDeniedGuestPrivileges( $current_username )) {
	    my $guest_id = $self->get_guest_contact_id();
	    $guest_clause = ", $guest_id" if $guest_id;
	}


  #### If a list of permitted work_groups is provided, see which ones
  #### the user can belong to
  if ($permitted_work_groups_ref && (!$set_to_work_group) ) {
    my %work_group_ids = $self->selectTwoColumnHash(
      "SELECT work_group_name,WG.work_group_id
         FROM $TB_USER_WORK_GROUP UWG
        INNER JOIN $TB_WORK_GROUP WG
              ON ( UWG.work_group_id = WG.work_group_id )
        WHERE UWG.contact_id IN ( '$current_contact_id' $guest_clause )
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
			if ( $allow_anonymous ) {
				$log->info( "Borrowing lab group id because anonymous access is allowed" );
        return $current_work_group_id;
			}
      $self->displayPermissionToPageDenied(
        ["You are not a member of any of the work groups that are ".
        "permitted to access this page"]);
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
    my $msg =<<"    MSG";
    current_contact_id undefined, Authentication must have failed!
    MSG
    print STDERR $msg;
    die( $msg );
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


  #### Get a list of accessible projects
  my @accessible_projects = $self->getAccessibleProjects();
  my $accessible_project_list = join(',',@accessible_projects);
  $accessible_project_list = '0' unless ($accessible_project_list);


  #### Get a hash of project_ids that the user can access
  if ($set_to_project_id > 0) {
    $sql = qq~
	SELECT P.project_id,P.name
	  FROM $TB_PROJECT P
	 WHERE P.project_id IN ( $accessible_project_list )
    ~;

    my %allowed_project_ids = $self->selectTwoColumnHash($sql);


    #### If this didn't turn up anything, return
    unless (exists($allowed_project_ids{$set_to_project_id})) {
      print $self->get_http_header(); 
      print  "ERROR: You are not permitted to access " .
        "project_id $set_to_project_id (only $accessible_project_list)\n\n";
      return;
    }


    #### Store the change permanently in the user_context table
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
# Return the most recently modified project owned by the user
###############################################################################
sub get_default_project_id {
  my $self = shift;
  my $contact = $self->getCurrent_contact_id();

  my @rows = selectSeveralColumns( <<"  END_SQL" );
  SELECT project_id 
  FROM $TB_PROJECT
  WHERE PI_contact_id = $contact
  ORDER BY date_modified DESC
  END_SQL

  return ( scalar( @rows ) ) ? $rows[0]->[0] : undef;
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
# Return the active project_tag of the user currently logged in
###############################################################################
sub getCurrent_project_tag {
    my $self = shift;

    #### If the current_project_tag is already known, return it
    return $current_project_tag
      if (defined($current_project_tag) && $current_project_tag gt "");
    if ($current_project_id < 1) {
      $current_project_id = $self->getCurrent_project_id();
    }

    #### If there is no current_project_id, return a name of "none"
    if ($current_project_id < 1) {
      $current_project_tag = "[none]";
    } else {
      #### Extract the name from the database given the ID
      ($current_project_tag) = $self->selectOneColumn(
        "SELECT project_tag
           FROM $TB_PROJECT
          WHERE project_id = $current_project_id
            AND record_status != 'D'
        ");
    }

    return $current_project_tag;
}


###############################################################################
# 
###############################################################################
sub printLoginForm {
    my $self = shift;
    my $login_message = shift;

    my $pre_username;
    my $pre_password;

    # retrieve demo account info if demo_login is set to 'yes'
    if ($q->param('demo_login') eq 'yes') {
	($pre_username, $pre_password) = $self->getNextDemoAccount();
	# print "<br>Logging in with account: <b>$pre_username</b>($pre_password)<br><br>";
    }

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
        <TD><INPUT TYPE="text" NAME="username" VALUE="$pre_username" SIZE="15"></TD>
        </TR><TR>
        <TD><B>Password:</B></TD>
        <TD><INPUT TYPE="password" NAME="password" VALUE="$pre_password" SIZE="15"></TD>
        </TR><TR>
        <TD COLSPAN=2 ALIGN="center">
        <BR>
        <INPUT TYPE="hidden" NAME="force_login" VALUE="">
        <INPUT TYPE="submit" NAME="login" VALUE=" Login ">
        <INPUT TYPE="reset" VALUE=" Reset ">
    !;

    #### Put all passed parameters into a hidden field here so if
    #### authentication succeeds, they are passed to the called program.
    my ($key,$value);
    foreach $key ( $q->param ) {
      next if ($key eq 'force_login');
      $value = $q->param($key);
      print qq~<INPUT TYPE="hidden" NAME="$key" VALUE="$value">\n~;
    }


    #### Close the table
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
sub displaySBEAMSError{
  my $self = shift;
  my $errors = shift || \@ERRORS;

  # New option.  If template is defined the header below will not print, useful
  # in cases where page printing has already begun when error is thrown.
  my $template = shift || 0;

  my $back_button = $self->getGoBackButton();
  my $start_line = " - ";
  my $end_line = "\n";

  $self->printPageHeader(minimal_header=>"YES") if !$template;

  if ($self->output_mode() eq 'html') {
    print qq~
      <CENTER>
      <H2>$DBTITLE Error </H2>
      The system has encountered an error.  Please report this problem and
      how it occurred to your local $DBTITLE administrator $DBADMIN
      <BR><BR>
      <BLOCKQUOTE>
    ~;
    $start_line = "<LI>";
    $end_line = "<P>\n";
  } else {
    $self->handle_error( error_type => 'sbeams_error',
                            message => join(", ", @{$errors} ) );
  }


  foreach my $error (@{$errors}) {
    print "$start_line$error$end_line";
  }

  if ($self->output_mode() eq 'html') {
    print qq~
      </BLOCKQUOTE>
      $back_button
      </CENTER>
    ~;
  }

  $self->printPageFooter() if !$template;

}


###############################################################################
# 
###############################################################################
sub displayPermissionToPageDenied{
  my $self = shift;
  my $ra_errors = shift || \@ERRORS;

  # New option.  If template is defined the header below will not print, useful
  # in cases where page printing has already begun when error is thrown.
  my $template = shift || 0;

  my $back_button = $self->getGoBackButton();
  my $start_line = " - ";
  my $end_line = "\n";

  $self->printPageHeader(minimal_header=>"YES") if !$template;

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
    $self->handle_error( error_type => 'access_denied',
                            message => 'Access to this resource is denied: ' .
                                      join( ', ', @{$ra_errors} )  
                         );
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

  $self->printPageFooter() if !$template;

}


###############################################################################
# destroyAuthHeader
###############################################################################
sub destroyAuthHeader {
    my $self = shift;

    my $current_username = $self->getCurrent_username;

    #### If there's a curernt username, then record that this user is
    #### logging out.  If there's no username, this call is not a logout
    #### but rather just a safety force logout
    if ($current_username) {
      my $remote_host = $ENV{REMOTE_HOST} || $ENV{REMOTE_ADDR} || '?';
      my $logging_query="INSERT INTO $TB_USAGE_LOG
	(username,usage_action,result,remote_host)
	VALUES ('$current_username','logout','SUCCESS','$remote_host')";
      $self->executeSQL($logging_query);
    }

    #### Fixed to set cookie path to tree root instead of possibly middle
    #### which then requires reauthentication when moving below entry point
    my $cookie_path = $HTML_BASE_DIR;

    my $cookie = $q->cookie(-name    => 'SBEAMSName',
                            -path    => "$cookie_path",
                            -value   => '0',
                            -expires => '-25h');
    $http_header = $q->header(-cookie => $cookie);
    $self->{_sbname_cookie} = $cookie;

    return $http_header;
}


###############################################################################
# createAuthHeader
###############################################################################
sub createAuthHeader {
    my $SUB_NAME = "createAuthHeader";
    my $self = shift;
    my %args = @_;

    my $username = $args{'username'};
    my $session_cookie = $args{'session_cookie'};

    # Fetch configured cookie timeout, else use 24 hrs.
    my $chours = $self->isValidDuration(cookie_duration => $LOGIN_DURATION) || 24;
    $chours = '+' . $chours . 'h';

    #### Fixed to set cookie path to tree root instead of possibly middle
    #### which then requires reauthentication when moving below entry point
    #my $cookie_path = $q->url(-absolute=>1);
    my $cookie_path = $HTML_BASE_DIR;
    #$cookie_path =~ s'/[^/]+$'/'; Removed 6/7/2002 Deutsch

    my $cipher = new Crypt::CBC( {
				  key => $self->getCryptKey(),
				  cipher => 'IDEA',
				  prepend_iv => 0,
				  iv => 'd%&jHE3%',
				 } );

    my $encrypted_user = $cipher->encrypt("$username");
    my $ctime = time();
    my %cookie = (  $ctime => $encrypted_user );

    my $cookie;

    if ( $SESSION_REAUTH ) {
      $cookie = $q->cookie( -name    => 'SBEAMSName',
                            -path    => "$cookie_path",
                            -value   => \%cookie ); 
      $log->info( "Session reauthentication is being enforced" );

    } else {
      $cookie = $q->cookie( -name    => 'SBEAMSName',
                            -path    => "$cookie_path",
                            -value   => \%cookie, 
                            -expires => $chours ); 

    }

    my $head;
    if ($session_cookie) {
      $head = $q->header(-cookie => [$cookie,$session_cookie]);
      $self->{_session_cookie} = $session_cookie;
      $self->{_sbname_cookie} = $cookie;
    } else {
      $head = $q->header(-cookie => $cookie);
      $self->{_sbname_cookie} = $cookie;
    }

    return $head;
}


###############################################################################
# getSessionCookie
###############################################################################
sub getSessionCookie {
  my $self = shift;

  my %cookie = $q->cookie('SBEAMSSession');

  if (scalar(keys(%cookie))) {
    ($session_string) = values(%cookie);
  }

  return \%cookie;

} # end getSessionCookie


###############################################################################
# createSessionCookie
###############################################################################
sub createSessionCookie {
  my $self = shift;
  # print STDERR "Creating session cookie\n";

  my $cookie_path = $HTML_BASE_DIR;

  $session_string = $self->getRandomString( num_chars => 20,
    char_set  => [ 'a'..'z', 0..9 ] );

  my $ctime = time();
  my %cookie = ( $ctime => $session_string );

  my $cookie;

  $cookie = $q->cookie( -name    => 'SBEAMSSession',
                        -path    => "$cookie_path",
                        -value   => \%cookie,
		        -expires => "+1M",
                      );

  return $cookie;
}


###############################################################################
# getSessionAttribute
###############################################################################
sub getSessionAttribute {
  my $SUB_NAME = "getSessionAttribute";
  my $self = shift;
  my %args = @_;

  my $key = $args{'key'}
    || die("ERROR: $SUB_NAME: Parameter 'key' not passed");

  unless ( %session ) {

    unless ($session_string) {
      #die("ERROR: $SUB_NAME: No session_string available");
      return;
    }

    my $session_store_file = "$PHYSICAL_BASE_DIR/var/sessions/".
      "$session_string.dat";

    if (-e $session_store_file) {
      my $session_hashref;
      eval { $session_hashref = retrieve($session_store_file) ||
             $log->error("Unable to retrieve session $session_string");
      };
      if ( $@ ) {
        # log storable error
        $log->error( "Storable: $@" );
        print STDERR "Storable: $@\n";

        # Temporary hack 'cause we're using 2 versions of perl!
        my $cmd = "$PHYSICAL_BASE_DIR/lib/scripts/Core/readStorable.pl $session_store_file";
        my $stored = `$cmd`;

        for my $line ( split( /\n/, $stored ) ) {
          $line =~ /^$key ===> (.*)$/;
          if ( $1 ) {
            $session_hashref->{$key} = $1;
            $log->warn( "brute-forced the session info!" );
            last;
          }
        }
      }
      if ($session_hashref) {
        %session = %{$session_hashref};
      }
      unless (%session) {
        $log->error("ERROR: $SUB_NAME: Unable to open or parse session file ".
	                   "'$session_store_file' (it does exist)");
      }

    } else {
      #### We don't even have a session file yet
      return;
    }
  }

  if ( $key eq 'returnEntireSessionHash' ) {
    return \%session;
  }
  return( $session{$key} ) || '';

} # end getSessionAttribute

sub showSessionHash {
  my $self = shift;
  my $hash = $self->getSessionAttribute( 'key' => 'returnEntireSessionHash' );
  if ( !defined $hash ) {
    $log->warn( "session file doesn't yet exist " );
    $hash = {};
  }
  my $scalar = '';
  if ( $hash ) {
    for my $k ( sort( keys( %$hash ) ) ) {
      $scalar .= "$k => $hash->{$k}\n";
    }
  }
  return $scalar;

}


###############################################################################
# setSessionAttribute
###############################################################################
sub setSessionAttribute {
  my $SUB_NAME = "setSessionAttribute";
  my $self = shift;
  my %args = @_;

  my $key = $args{'key'}
    || die("ERROR: $SUB_NAME: Parameter 'key' not passed");
  my $value = $args{'value'};


  unless ($session_string) {
    #die("ERROR: $SUB_NAME: No session_string available");
    return;
  }


  my $session_store_file = "$PHYSICAL_BASE_DIR/var/sessions/".
    "$session_string.dat";

  unless (%session) {

    if (-e $session_store_file) {
      my $session_hashref;
      eval {
	$session_hashref = retrieve($session_store_file) ||
	  $log->error("Unable to retrieve session $session_string");
      };
      if ($session_hashref) {
	%session = %{$session_hashref};
      }
      unless (%session) {
	$log->error("ERROR: $SUB_NAME: Unable to open or parse session file ".
	    "'$session_store_file' (it does exist)");
      }

    } else {
      #### We don't even have a session file yet
    }
  }


  $session{$key} = $value;

  nstore(\%session,$session_store_file);

  return(1);

} # end setSessionAttribute

#+
# Subroutine to delete attribute from the global session hash.
#-
sub deleteSessionAttribute {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = $self->get_subname();

  my $key = $args{'key'}
    || die("ERROR: $SUB_NAME: Parameter 'key' not passed");
  my $value = $args{'value'};

  unless ($session_string) {
    $log->warn( "$SUB_NAME: No session_string available" );
    return;
  }

  my $session_store_file = "$PHYSICAL_BASE_DIR/var/sessions/".
    "$session_string.dat";

  unless (%session) {

    if (-e $session_store_file) {
      my $session_hashref;
      eval {
      	$session_hashref = retrieve($session_store_file) ||
	      $log->error("Unable to retrieve session $session_string");
      };
      if ($session_hashref) {
      	%session = %{$session_hashref};
      }
      unless (%session) {
      	$log->error( <<"        END" );
        Unable to open or parse existing session file '$session_store_file' 
        END
      }

    } else {
      #### We don't even have a session file yet
    }
  }


  delete($session{$key});

  nstore(\%session,$session_store_file);

  return(1);

} # end deleteSessionAttribute


#+
# Wrapper method CGI.pm redirect method, allows for pertinant code to be
# run in a uniform fashion prior to redirection.  Implemented to allow cookies
# to be propogated through a redirect.
# 
# narg: uri   Required, URI (URL) to which to redirect.
#-
sub sbeams_redirect {
  my $self = shift;
  my %args = @_;
  die "Missing required parameter uri" unless $args{uri};

  my %dough = $q->cookie('SBEAMSName');

  # Fetch configured cookie timeout, else use 24 hrs.
  my $chours = $self->isValidDuration(cookie_duration => $LOGIN_DURATION) || 24;
  $chours = '+' . $chours . 'h';

  if ( !%dough ) { # no cookie, simply pass through to cgi.pm method
    print $q->redirect( $args{uri} );
  } else {
    $dough{'-name'} = 'SBEAMSName';
    $dough{'-path'} = $HTML_BASE_DIR;
    $dough{'-expires'} = $chours unless $SESSION_REAUTH;

    my $cookie = $q->cookie( %dough );
    print $q->redirect( -uri => $args{uri}, -cookie => $cookie );
  }
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

		my $success_code = 'SUCCESS (DB)';

    #### If this user is not in the user_login table, don't look any further
    unless (exists $query_result{$user}) {
      if ($more_helpful_message) {
        push(@ERRORS, "This username is not registered in the system");
        $log->error( "username $user is not registered in the system");
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
		    $success_code = 'SUCCESS (NIS)';
      }
    }

    #### If there is an encrypted password, test it
    if ($failed == 0 && $query_result{$user}) {
      if (crypt($pass, $query_result{$user}) eq $query_result{$user}) {
        $success = 1;
        $error_code = $success_code;
      } else {
        if ($more_helpful_message) {
          push(@ERRORS, "Incorrect password for this username");
        $log->info( "Incorrect Unix password for $user ");
        } else {
          push(@ERRORS, "Login Incorrect");
        }
        $success = 0;
        $error_code = 'INCORRECT PASSWORD';
      }
    }

    # If success is still 0 but we haven't failed, try LDAP Authentication if enabled 
    if ( !$success && !$failed && $LDAPAUTH && $LDAPAUTH->{ENABLE} && $LDAPAUTH->{ENABLE} =~ /yes/i ) { 
      my $ldap_user = $user;
      if ( $LDAPAUTH->{USERTEMPLATE} ) {
        $ldap_user = $LDAPAUTH->{USERTEMPLATE};
        $ldap_user =~ s/USERNAME/$user/g;
      }

      my $port = $LDAPAUTH->{PORT} || 636;
      my $ldap = Net::LDAPS->new ( $LDAPAUTH->{SERVER}, port => $port );

      if ( !$ldap ) {
        $log->error( "LDAP connection failes: $@\n" );
        push(@ERRORS, "$@" );
      } else {
        # Try to bind as user to verify password
        my $result = $ldap->bind ( $ldap_user,
                                   password => $pass,
                                   version => 3 ); 

        if ( $result->code() ) {
          $log->warn( "LDAP Error: " . $result->error()  );
        } else {
          $success = 1;
          $error_code = 'SUCCESS (LDAP)';
        }
      }
    }

    #### If success is still 0 but we haven't failed, try SMB Authentication
    if ($success == 0 && $failed == 0 && $SMBAUTH && $SMBAUTH->{ENABLE} =~ /Y/i) {

      $log->debug( "Dropped to SMB Auth" );

      my $authResult = Authen::Smb::authen($user,$pass, 
                                           @$SMBAUTH{qw(PDC BDC Domain)});
      if ( $authResult == 0 ) {
        $success = 1;
        $error_code = 'SUCCESS (SMB)';

      } elsif ( $authResult == 3 ) {
        if ($more_helpful_message) {
          push(@ERRORS, "Incorrect password for this username");
          $log->warn( "Incorrect SMB password for $user: $authResult ");
        } else {
          push(@ERRORS, "Login Incorrect");
        }
        $success = 0;
        $error_code = 'INCORRECT PASSWORD';

      } else {
        if ($more_helpful_message) {
          push(@ERRORS, "ERROR communicating with the Domain Controller");
          my $etype = ( $authResult == 1 ) ? 'SERVER_ERROR' : 'PROTOCOL_ERROR';
          $log->error( "SMB Error with $SMBAUTH->{Domain}: $etype");
        } else {
          push(@ERRORS, "Login Incorrect");
        }
        $success = 0;
        $error_code = 'UNABLE TO CONTACT DC';
      }
      $log->debug( "Success is $success" );

    }

    # Register the outcome of this attempt
    my $remote_host = $ENV{REMOTE_HOST} || $ENV{REMOTE_ADDR} || '?';
    $logging_query = qq~
	INSERT INTO $TB_USAGE_LOG (username,usage_action,result,remote_host)
	VALUES ('$user','login','$error_code','$remote_host')
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
# getEmail
###############################################################################
sub getEmail {
    my $self = shift;
    my $contact_id = shift;

    my $sql_query = qq~
	SELECT email
	  FROM $TB_CONTACT
	 WHERE contact_id = '$contact_id'
	   AND record_status != 'D'
    ~;

    my ($email) = $self->selectOneColumn($sql_query);

    return $email;
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
# getNextDemoAccount
#
# Returns the most-idle demo account and password as a 2-element array
# Demo accounts are designated by a special string in the user_login.comment
#  field, which also contains the password
###############################################################################
sub getNextDemoAccount {
    my $self = shift;

    my $demologin;
    my $demopwd;
    my $comment_string = 'DEMO ACCOUNT: PASSWORD=';

    # Will this query ever get too expensive?
    # The comment (text type) must be cast (char) in order to use the MAX function
    my $sql_query = qq~
	  SELECT UL1.username, MAX(CAST(UL1.comment as CHAR(255))) as 'comment'
	    FROM $TB_USER_LOGIN UL1
       LEFT JOIN $TB_USAGE_LOG UL2 ON ( UL1.username = UL2.username )
	   WHERE UL1.comment like '${comment_string}%'
	GROUP BY UL1.username
	ORDER BY MAX(UL2.date_created)
    ~;
    my @rows = $self->selectSeveralColumns($sql_query);
    my ($q_username, $q_comment) = @{$rows[0]};

    if ($q_comment =~ /${comment_string}(\w+)/) {
	$demologin = $q_username;
	$demopwd = $1;
    }

    return ($demologin, $demopwd);
}

sub get_self_url {
  my $self = shift;
  return $q->self_url();
}

sub get_url_params {
  my $self = shift;
  my %args = @_;
  $args{escape} = 1 unless defined $args{escape};
  my @omit = ( defined($args{omit}) ) ? @{$args{omit}} : ();
  my $html = '';
  for my $p ( $q->param() ) {
    next if grep( /^$p$/, @omit );
    my $v = $q->param( $p );
    $v = escape( $v ) if $args{escape};
    $html .= "<INPUT TYPE=HIDDEN NAME='$p' VALUE='$v'>\n";
  }
  return $html;
}

sub get_cgi_param {
  my $self = shift;
  my $param = shift;
  return $q->param($param);
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

This module is normally inherited by the SBEAMS::Connection module,
although it can be used on its own.  Its main function is to provide a
set of authentication methods for this application.

If the user is accessing the application via HTTP, then cookie
authentication is used, where when a user logs in successfully
through a web form, a cookie is given to the users web browser.  The
web browser then offers this cookie at every request, and
the application provides access for the user or presents a new
challenge if the cookie expires.

If the user is accessing the application via the command line, then
authentication is based only upon the UID of the user.  This could
potentially be forged by untrusted machines so access should be
limited to trusted machines (not yet implemented.)


=head2 METHODS

=over

=item * B<checkCachedAuth()>

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
