package SBEAMS::Connection::ErrorHandler;

###############################################################################
# Program     : SBEAMS::Connection::ErrorHandler
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               errors and how they get reported back to the user.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
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
    $prefix = "<BR>\nSBEAMS Error:<BR><PRE>";
    $suffix = "</PRE><BR></TABLE></TABLE></TABLE></TABLE>";
  }


  #### Put some CR's before "Server message ", a SQL Server specific thing
  my $message_str = $message;
  $message_str =~ s/Server message /\nServer message /g;

  #### Display the error message
  print "$prefix\n$message_str\n$suffix\n";


  #### Goodbye.
  exit;


} # end error

sub getStackTrace {
  my ( $message, $p, $f, $l, $s, $h, $w );
  my $i = 0;
  use File::Basename;
  while (($p, $f, $l, $s, $h, $w) = caller($i++)) {
    $message .= "Package: $p\t File: " . basename($f) . "\t Line: $l\t Sub: $s\n";
  }
  return $message;
}

###############################################################################

1;

__END__

###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::ErrorHandler

SBEAMS Core error handling methods

=head2 SYNOPSIS

See SBEAMS::Connection for usage synopsis.

=head2 DESCRIPTION

This module provides a set of methods for handling errors which do
different things based on the current output_mode and context.  There
is probably no reason to call any of these methods directly.


=head2 METHODS

=over

=item * B<error($message)>

    The clean way to error out of SBEAMS no matter what the context is.


=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

