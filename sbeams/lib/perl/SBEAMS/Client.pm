package SBEAMS::Client;

###############################################################################
# Program     : SBEAMS::Client
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id $
#
# Description : This module provides a client API to SBEAMS queries
#               exposed via the HTTP interface.
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

  use strict;
  use XML::Parser;
  use LWP::UserAgent;
  use HTTP::Cookies;
  use Data::Dumper;

  use vars qw($VERSION @ISA);
  use vars qw(@stack %info);

  @ISA = ();
  $VERSION = '0.1';


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
# authenticate
###############################################################################
sub authenticate {
  my $self = shift || die("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "authenticate";

  #### Decode the argument list
  my $server_uri = $args{'server_uri'};


  #### Determine the server_uri
  if ($server_uri) {
    $self->set_server_uri($server_uri);
  } else {
    $server_uri = $self->get_server_uri();
    unless ($server_uri) {
      die("ERROR: $SUB_NAME: parameter 'server_uri' missing")
    }
  }


  #### Determine the name of the SBEAMSAuth cache file
  my $HOME = $ENV{'HOME'};
  unless ($home) {
    die("ERROR: $SUB_NAME: Unable to determine home directory");
  }
  my $SBEAMSAuth_file = "$HOME/.SBEAMSAuth";


  #### Create the cookie jar
  my $cookie_jar = HTTP::Cookies->new(ignore_discard=>1);


  #### See if the file exists and read it if it does
  if (-e $SBEAMSAuth_file ) {
    if ($cookie_jar->load($SBEAMSAuth_file)) {
      return $cookie_jar;
    }
  }


  #### If we got this far, there's no cache to be had so prompt the user
  #### for a valid username and password
  my ($username,$password);
  print "SBEAMS Username: ";
  chomp($username = <STDIN>);
  system "stty -echo";
  print "SBEAMS Password: ";
  chomp($password = <STDIN>);
  print "\n";
  system "stty echo";


  #### See if we can get a cookie for this
  my $SBEAMS_auth;
  unless ($SBEAMS_auth = _fetchSBEAMSAuth(
					  server_url=>$server_url,
					  username=>$username,
					  password=>$password,
					 )
	 ) {
    die("ERROR: Unable to authenticate to SBEAMS.");
  }


  #### Since we got the authentication cookie, cache it
  $SBEAMS_auth->save($SBEAMSAuth_file);
  #### And make sure only the user can read the file
  chmod(0600,$SBEAMSAuth_file);

  return $SBEAMS_auth;

} # end authenticate



###############################################################################
# fetch_data
###############################################################################
sub fetch_data {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "fetch_data";

  #### Decode the argument list
  my $server_uri = $args{'server_uri'};
  my $server_command = $args{'server_command'}
    || die("ERROR: $SUB_NAME: parameter server_command missing");
  my $command_parameters = $args{'command_parameters'} || '';


  #### If authentication hasn't happened yet, do it now if possible
  unless ($self->is_authenticated) {
    unless ($server_uri) {
      print "ERROR: $SUB_NAME: Parameter server_uri missing";
      return '';
    };
    unless ($sbeams->authenticate(server_uri => $server_uri) {
      print "ERROR: $SUB_NAME: Unable to authenticate";
    }
  }


  #### Create the URL for getting the result
  my $url = "$server_uri/cgi/$command_parameters";


  #### Obtain the authentication cookie
  my $SBEAMS_auth = $self->get_authentication();


  #### Create a user agent object pretending to be Mozilla
  my $ua = new LWP::UserAgent;
  $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:0.9.9)");
  $ua->cookie_jar($SBEAMS_auth);


  #### Create a request object with the supplied URL and parameters
  my $request = HTTP::Request->new(POST=>$url);
  $request->content_type('application/x-www-form-urlencoded');
  $request->content($parameters);


  #### Pass request to the user agent and get a response back
  my $response = $ua->request($request);


  #### Return the data
  if ($response->is_success) {
    return $response->content;
  } else {
    return '';
  }

} # end fetch_data



###############################################################################
# set_server_uri
###############################################################################
sub set_server_uri {
  my $self = shift || croak("parameter self not passed");
  my $SUB_NAME = "set_server_uri";

  #### Decode the argument list
  my $server_uri = shift
    || die("ERROR: $SUB_NAME: parameter 'server_uri' missing");


  $self->{_server_uri} = $server_uri;

  return 1;

} # end set_server_uri



###############################################################################
# get_server_uri
###############################################################################
sub get_server_uri {
  my $self = shift || croak("parameter self not passed");
  my $SUB_NAME = "get_server_uri";

  #### Decode the argument list
  my $dummy = shift;
  die("ERROR: $SUB_NAME: no parameters allowed") if ($dummy);

  #### Return the data
  return $self->{_server_uri};

} # end get_server_uri



###############################################################################
# set_authentication
###############################################################################
sub set_authentication {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "set_authentication";

  #### Decode the argument list
  my $authentication = $args{'authentication'}
    || die("ERROR: $SUB_NAME: parameter 'authentication' missing");

  $self->{_authentication} = $authentication;

  return 1;

} # end set_authentication



###############################################################################
# get_authentication
###############################################################################
sub get_authentication {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "get_authentication";

  #### Decode the argument list
  my $dummy = shift;
  die("ERROR: $SUB_NAME: no parameters allowed") if ($dummy);


  #### If the authentication has not been yet obtained, try to
  unless ($self->{_authentication}) {
    $self->{_authentication} = $self->authenticate();
  }


  #### Return the data
  return $self->{_authentication};

} # end get_authentication



###############################################################################
# _fetchSBEAMSAuth
###############################################################################
sub _fetchSBEAMSAuth {
  #my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "_fetchSBEAMSAuth";

  #### Decode the argument list
  my $server_uri = $args{'server_uri'}
    || die("ERROR: $SUB_NAME: parameter 'server_uri' missing");
  my $username = $args{'username'}
    || die("ERROR: $SUB_NAME: parameter 'username' missing");
  my $password = $args{'password'}
    || die("ERROR: $SUB_NAME: parameter 'password' missing");


  #### Form the rest of the $url
  my $url = "$server_uri/cgi/main.cgi";
  my $parameters = "username=$username&password=$password&login=Login";


  #### Create a user agent object pretending to be Mozilla
  my $ua = new LWP::UserAgent;
  $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.0)");


  #### Create a request object with the supplied URL and parameters
  my $request = HTTP::Request->new(POST=>$url);
  $request->content_type('application/x-www-form-urlencoded');
  $request->content($parameters);


  #### Pass request to the user agent and get a response back
  my $response = $ua->request($request);


  #### If the request was sucessful
  if ($response->is_success) {

    #### Create a cookie jar and extract the cookie from the response
    my $cookie_jar = HTTP::Cookies->new(ignore_discard=>1);
    $cookie_jar->extract_cookies($response);

    #### If a cookie was obtained, return it
    if ($cookie_jar->as_string()) {
      return $cookie_jar;

    #### Else return empty
    } else {
      return '';
    }

  #### Else return empty
  } else {
    return '';
  }

} # end _fetchSBEAMSAuth



###############################################################################
# Process Data into something more convenient
###############################################################################
sub processSBEAMSData {
  my %args = @_;
  my $SUB_NAME = "processSBEAMSData";

  #### Decode the argument list
  my $data = $args{'data'} || die("ERROR: $SUB_NAME: parameter data missing");;
  my $format = $args{'format'} || die("ERROR: $SUB_NAME: parameter format missing");

  my @fdata = ();
  my @data_tmp = split("\n",$data);
  my $header = shift @data_tmp;
  my @header_a = split("\t",$header);

  if($format eq "matrix"){
    for(my $row=0;$row<@data_tmp;$row++){
      @{$fdata[$row]} = split("\t",$data_tmp[$row]);

### if you feel like doing it the long way ###
#      my @row_tmp_a = split("\t",$data_tmp[$row]);
#      for(my $col=0;$col<@row_tmp_a;$col++){
#	$fdata[$row][$col] = $row_tmp_a[$col];
#      }
###
    }
  }
  elsif($format eq "array_hash"){
    for(my $row=0;$row<@data_tmp;$row++){
      my @row_tmp_a = split("\t",$data_tmp[$row]);
      for(my $col=0;$col<@row_tmp_a;$col++){
	$fdata[$row]{$header_a[$col]} = $row_tmp_a[$col];
      }
    }
  }
  return \@fdata;
}



###############################################################################
###############################################################################
###############################################################################
1;
