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
  my $SBEAMSAuth_file = $args{'SBEAMSAuth_file'};


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
  unless (defined($SBEAMSAuth_file) && $SBEAMSAuth_file gt '') {
    my $HOME = $ENV{'HOME'};
    unless ($HOME) {
      die("ERROR: $SUB_NAME: Unable to determine home directory");
    }
    $SBEAMSAuth_file = "$HOME/.SBEAMSAuth";
  }


  #### Create the cookie jar
  my $cookie_jar = HTTP::Cookies->new(ignore_discard=>1);


  #### See if the file exists and read it if it does
  if (-e $SBEAMSAuth_file ) {
    if ($cookie_jar->load($SBEAMSAuth_file)) {
      $self->{_is_authenticated} = 1;
      $self->set_authentication(authentication=>$cookie_jar);
      #print "Loaded cookie jar $cookie_jar\n";
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
					  server_uri=>$server_uri,
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

  $self->{_is_authenticated} = 1;
  $self->set_authentication(authentication=>$SBEAMS_auth);
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
  my $command_parameters = $args{'command_parameters'};


  #### If authentication hasn't happened yet, do it now if possible
  unless ($self->is_authenticated) {
    unless ($server_uri) {
      print "ERROR: $SUB_NAME: Parameter server_uri missing";
      return '';
    }
    unless ($self->authenticate(server_uri => $server_uri)) {
      print "ERROR: $SUB_NAME: Unable to authenticate";
    }
  }


  #### Create the URL for getting the result
  my $url = "$server_uri/cgi/$server_command";


  #### Obtain the authentication cookie
  my $SBEAMS_auth = $self->get_authentication();


  #### Create a user agent object pretending to be Mozilla
  my $ua = new LWP::UserAgent;
  $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:0.9.9)");
  #print "My cookie jar is $SBEAMS_auth\n";
  $ua->cookie_jar($SBEAMS_auth);


  #### Take the command_parameters hashref and build the URL
  my $command_parameters_str = '';
  if (defined($command_parameters) && ref($command_parameters) =~ /HASH/) {

    #### If output_mode and apply_action aren't set, set them
    $command_parameters->{output_mode} = 'tsv'
      unless ($command_parameters->{output_mode});
    $command_parameters->{apply_action} = 'QUERY'
      unless (defined($command_parameters->{apply_action}));

    #### Build the parameter list
    while ( my ($key,$value) = each %{$command_parameters} ) {
      $command_parameters_str .= "$key=$value&";
    }
    chop($command_parameters_str);
  }


  #### Create a request object with the supplied URL and parameters
  my $request = HTTP::Request->new(POST=>$url);
  $request->content_type('application/x-www-form-urlencoded');
  $request->content($command_parameters_str);


  #### Pass request to the user agent and get a response back
  my $response = $ua->request($request);


  #### Create the returned structure
  my $resultset;
  $resultset->{is_success} = $response->is_success;
  $resultset->{raw_response} = $response->content;


  #### Decode the raw result into a real resultset
  $self->decode_response(resultset_ref => $resultset);


  #### Return the result
  return $resultset;


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
# is_authenticated
###############################################################################
sub is_authenticated {
  my $self = shift || croak("parameter self not passed");
  my $SUB_NAME = "is_authenticated";

  #### Decode the argument list
  my $dummy = shift;
  die("ERROR: $SUB_NAME: no parameters allowed") if ($dummy);

  #### Return the data
  return $self->{_is_authenticated};

} # end is_authenticated



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
  unless ($self->is_authenticated()) {
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
# decode_response
###############################################################################
sub decode_response {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "decode_response";

  #### Decode the argument list
  my $resultset = $args{'resultset_ref'}
    || die("ERROR: $SUB_NAME: resultset_ref data missing");;


  #### Try to figure out what type of resultset we have
  my $rawtype = '';
  if ($resultset->{raw_response} =~ /^\s*<HTML>/) {
    $rawtype = 'html'
  } elsif ($resultset->{raw_response} =~ /^\s*<\?xml/) {
    $rawtype = 'xml'
  } elsif ($resultset->{raw_response} =~ /\t/) {
    $rawtype = 'tsv'
  }

  #### If we did not figure out the resultset type, squawk and return
  unless ($rawtype) {
    print "ERROR: $SUB_NAME: Unable to determine response type.\n";
    return 0;
  }


  #### If the type is xml or html, we don't yet know what to do
  if ($rawtype eq 'xml' || $rawtype eq 'html') {
    print "ERROR: $SUB_NAME: Cannot decode $rawtype into a resultset yet.\n";
    return 0;
  }



  #### If data is tsv, decode it
  if ($rawtype eq 'tsv') {

    #### Decode into rows
    my @rows = split("\n",$resultset->{raw_response});

    #### Pull off the first row as the header and make an array
    my $header = shift(@rows);
    my @column_list = split("\t",$header);
    $resultset->{column_list_ref} = \@column_list;

    #### Convert the array into a hash of names to column numbers
    my $i = 0;
    my %column_hash;
    foreach my $element (@column_list) {
      $column_hash{$element} = $i;
      $i++;
    }
    $resultset->{column_hash_ref} = \%column_hash;

    #### Convert each row from string to array ref
    for ($i=0;$i<scalar(@rows);$i++) {
      $rows[$i] = [ split("\t",$rows[$i]) ];
    }
    $resultset->{data_ref} = \@rows;

    #### Return success
    return 1;
  }


  #### Return error if we got this far
  print "ERROR: $SUB_NAME: Unknown type '$rawtype'\n";
  return 0;

} # end decode_response



###############################################################################
###############################################################################
###############################################################################
1;
