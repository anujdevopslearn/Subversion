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
  use LWP::UserAgent;
  use HTTP::Cookies;
  use Data::Dumper;

  use vars qw($VERSION @ISA);

  @ISA = ();
  $VERSION = '0.1';


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    #### Create myself with my attributes and return
    my $self = {
		_is_authenticated => '',
		_authentication => '',
		_server_uri => '',
	       };
    bless($self,$class);
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
  my $server_uri = $args{'server_uri'} || '';
  my $SBEAMSAuth_file = $args{'SBEAMSAuth_file'} || '';


  #### Determine the server_uri
  if ($server_uri) {
    $self->set_server_uri($server_uri);
  } else {
    $server_uri = $self->get_server_uri();
    unless ($server_uri) {
      die("ERROR: $SUB_NAME: parameter 'server_uri' missing");
    }
  }


  #### Determine the name of the SBEAMSAuth cache file
  unless ($SBEAMSAuth_file gt '') {
    my $HOME = $ENV{'HOME'};
    unless ($HOME) {
      die("ERROR: $SUB_NAME: Unable to determine home directory to find ".
	  "SBEAMS authorization cache file.");
    }
    $SBEAMSAuth_file = "$HOME/.SBEAMSAuth";
  }


  #### Create the cookie jar
  my $cookie_jar = HTTP::Cookies->new(ignore_discard => 1);


  #### See if the SBEAMSAuth file exists
  if (-e $SBEAMSAuth_file ) {

    #### Read its contents into a cookie jar
    if ($cookie_jar->load($SBEAMSAuth_file)) {

      #### Decode the server and path for the SBEAMS server_uri
      my $server = $server_uri;
      $server =~ s/^http[s]*:\/\///;
      my $path = '/';
      if ($server =~ /.+?(\/.+)/) {
	$path = $1;
      }
      $server =~ s/\/.*//;

      #### If we have a cookie for this location, the set the auth
      if (defined($cookie_jar->{COOKIES}->{$server}->{$path})) {
        $self->set_authentication(authentication => $cookie_jar);
        return $cookie_jar;
      }
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
    print("ERROR: Unable to authenticate to SBEAMS server:\n  $server_uri\n");
    return '';
  }


  #### Since we got the authentication cookie, cache it
  $SBEAMS_auth->save($SBEAMSAuth_file);
  #### And make sure only the user can read the file
  chmod(0600,$SBEAMSAuth_file);

  $self->set_authentication(authentication => $SBEAMS_auth);
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
  my $server_uri = $args{'server_uri'} || '';
  my $server_command = $args{'server_command'}
    || die("ERROR: $SUB_NAME: parameter server_command missing");
  my $command_parameters = $args{'command_parameters'} || '';


  #### If authentication hasn't happened yet, do it now if possible
  unless ($self->is_authenticated()) {
    unless ($server_uri) {
      print "ERROR: $SUB_NAME: Parameter server_uri missing";
      return '';
    }
    unless ($self->authenticate(server_uri => $server_uri)) {
      print "ERROR: $SUB_NAME: Unable to authenticate\n";
      return '';
    }
  }


  #### Create the URL for getting the result
  my $url = "$server_uri/cgi/$server_command";


  #### Obtain the authentication cookie
  my $SBEAMS_auth = $self->get_authentication();


  #### Create a user agent object and provide the cookie jar
  my $ua = new LWP::UserAgent(timeout => 600);
  $ua->agent("SBEAMS::Client");
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

  #print "URL=$url\n";
  #print "params=$command_parameters_str\n";

  #### Create a request object with the supplied URL and parameters
  my $request = HTTP::Request->new(POST => $url);
  $request->content_type('application/x-www-form-urlencoded');
  $request->content($command_parameters_str);


  #### Pass request to the user agent and get a response back
  my $response = $ua->request($request);


  #### Create the returned structure
  my $resultset;
  $resultset->{is_success} = $response->is_success;
  $resultset->{raw_response} = $response->content;

  #print "RAW=".$response->content."\n";
  #use Data::Dumper;
  #print Data::Dumper->Dump([$response])."\n\n";

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
  $self->{_is_authenticated} = 1;

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
    $self->set_authentication($self->authenticate());
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
  $ua->agent("SBEAMS::Client");


  #### Create a request object with the supplied URL and parameters
  my $request = HTTP::Request->new(POST => $url);
  $request->content_type('application/x-www-form-urlencoded');
  $request->content($parameters);


  #### Pass request to the user agent and get a response back
  my $response = $ua->request($request);


  #### If the request was sucessful
  if ($response->is_success) {

    #### Create a cookie jar and extract the cookie from the response
    my $cookie_jar = HTTP::Cookies->new(ignore_discard => 1);
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
    return '';
  }


  #### If the type is xml or html, we don't yet know what to do
  if ($rawtype eq 'xml' || $rawtype eq 'html') {
    print "ERROR: $SUB_NAME: Cannot decode $rawtype into a resultset yet.\n";
    return '';
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
  return '';

} # end decode_response



###############################################################################

1;

__END__

###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Client

SBEAMS Client module for accessing a remote SBEAMS server via HTTP

=head2 SYNOPSIS

      use SBEAMS::Client;
      my $sbeams = new SBEAMS::Client;

      my $server_uri = "https://db.systemsbiology.net/sbeams";
      my $server_command = "Proteomics/BrowseBioSequence.cgi";
      my $command_parameters = {
        biosequence_set_id => 3,
        biosequence_gene_name_constraint => "bo%",
      };

      my $resultset = $sbeams->fetch_data(
        server_uri => $server_uri,
        server_command => $server_command,
        command_parameters => $command_parameters,
       );

      while ( my ($key,$value) = each %{$resultset}) {
        if ($key eq 'raw_response') {
          print "  key = <FULL DATA RESPONSE>\n";
        } else {
          print "  $key = $value\n";
        }
      }


=head2 DESCRIPTION

This class provides a simple mechanism for fetching data from a remote
SBEAMS server via HTTP, including handling for authentication and
parsing the returned data stream.


=head2 METHODS

=over

=item * B<new()>

    Constructor creates a new SBEAMS::Client object

    INPUT PARAMETERS:

      None

    OUTPUT:

      New SBEAMS::Client object


=item * B<fetch_data(see INPUT PARAMETERS)>

    Fetch a resultset from a remote SBEAMS server

    INPUT PARAMETERS:

      server_uri => Scalar URI address of the remote SBEAMS server, e.g.:
      https://db.systemsbiology.net/sbeams

      server_command => Scalar command on the server to run, e.g.:
      Proteomics/BrowseBioSequence.cgi

      command_parameters => Hash reference for the parameters to pass, e.g.
      {
        biosequence_set_id => 3,
        biosequence_gene_name_constraint => "bo%",
      }

    OUTPUT:

      A hash reference of some complexity containing the fetched resultset:
      {
        is_success = 1
        raw_response = <FULL HTTP RESPONSE BODY>
        column_list_ref = ARRAY(0x834d380)
        column_hash_ref = HASH(0x834d428)
        data_ref = ARRAY(0x834d2e4)
      }


=item * B<authenticate(see INPUT PARAMETERS)>

    Verify the authentication required to communicate with the server,
    either by reading a cached authentication or promtping the user for
    an SBEAMS username and password.

    INPUT PARAMETERS:

      server_uri => Scalar URI address of the remote SBEAMS server, e.g.:
      https://db.systemsbiology.net/sbeams

      SBEAMSAuth_file => Scalar filename containing a cached cookie, e.g.:
      $HOME/.SBEAMSAuth

    OUTPUT:

      SBEAMS_auth object


=item * B<set_server_uri($server_uri)>

    Set the server_uri attribute

    INPUT PARAMETERS:

      $server_uri: a scalar string containing the server URI address, e.g.
      https://db.systemsbiology.net/sbeams

    OUTPUT:

      1


=item * B<get_server_uri()>

    Get the current server_uri attribute

    INPUT PARAMETERS:

      None

    OUTPUT:

      The current value of the $server_uri


=item * B<is_authenticated()>

    Determine if the user has currently already authenticated

    INPUT PARAMETERS:

      None

    OUTPUT:

      1 if yes, 0 if not


=item * B<set_authentication(see INPUT PARAMETERS)>

    Set the authentication parameter

    INPUT PARAMETERS:

      authentication => SBEAMS authentication object

    OUTPUT:

      1


=item * B<get_authentication()>

    Get the current authentication parameter or if the user is not yet
    authenticated, call authenticate().

    INPUT PARAMETERS:

      None

    OUTPUT:

      SBEAMS authentication object or undef if not able to authenticate.


=item * B<_fetchSBEAMSAuth(see INPUT PARAMETERS)>

    Fetch an SBEAMS authentication object (cookie) given the supplied
    username and password.  The client software using this method
    must handle a raw password, which is discouraged.  It is preferred
    to use the authenticate() method which has its internal means of
    asking for username and password.

    INPUT PARAMETERS:

      server_uri => Scalar URI address of the remote SBEAMS server, e.g.:
      https://db.systemsbiology.net/sbeams

      username => Scalar SBEAMS username with which to authenticate

      password => Scalar SBEAMS password with which to authenticate

    OUTPUT:

      SBEAMS Auth object if success or empty string if failed.


=item * B<decode_response(see INPUT PARAMETERS)>

    This method decodes the raw HTTP response (e.g., TSV or XML) into a
    resultset object (or rather currently just a hash with the data in it).

    INPUT PARAMETERS:

      resultset_ref => Hash reference to the current fetch result

    OUTPUT:

      1 is success or 0 if failed.


=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

