package SBEAMS::Connection::ErrorHandler;

###############################################################################
# Program     : SBEAMS::Connection::ErrorHandler
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               errors and how they get reported back to the user.
#
###############################################################################


use strict;
use vars qw(@EXPORT @ISA $sbeams);
use Exporter;
@ISA = "Exporter";
@EXPORT	= qw( error );

use CGI;
use CGI::Carp qw( fatalsToBrowser );



###############################################################################
# carp_error
#
# Callback for CGI::Carp to handle errors
###############################################################################
BEGIN {
  sub carp_error {
    my $error_message = shift;
    CGI::Carp::set_message(\&error);
  }
}


###############################################################################
# register_sbeams
#
# Register the SBEAMS object so we can use it
###############################################################################
sub register_sbeams {
  my $METHOD_NAME = "register_sbeams()";
  $sbeams = shift || die "$METHOD_NAME: sbeams object not passed";
  CGI::Carp::set_message(\&error);
}




###############################################################################
# error
#
# Unified SBEAMS error message handling method
###############################################################################
sub error {
  my $message = shift;

  my $METHOD_NAME = 'error';


  #### Define prefix and suffix based on output format
  my $prefix = '';
  my $suffix = '';

  if ($sbeams->output_mode eq 'html') {
    $prefix = '<BR>\nSBEAMS Error:<BR><PRE>';
    $suffix = '</PRE><BR>';
  }


  #### Put some CR's before "Server message ", a SQL Server specific thing
  my $message_str = $message;
  $message_str =~ s/Server message /\nServer message /g;

  #### Display the error and exit
  print "$prefix\n$message_str\n$suffix\n";

  exit;


} # end error


###############################################################################

1;

__END__

###############################################################################
###############################################################################
###############################################################################

