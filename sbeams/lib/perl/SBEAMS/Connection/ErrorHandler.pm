package SBEAMS::Connection::ErrorHandler;

###############################################################################
# Program     : SBEAMS::Connection::ErrorHandler
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               errors and how they get reported back to the user.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
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
use CGI::Carp;




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

  if ($sbeams->get_output_mode() eq 'html') {
    $prefix = "<BR>\nSBEAMS Error:<BR><PRE>";
    $suffix = "";#</PRE><BR></TABLE></TABLE></TABLE></TABLE>";
  } else {
    $sbeams->handle_error( error_type  => 'sbeams_error',
                           message     => $message,
                           h_printed   => 0,
                           out_mode    => $sbeams->get_output_mode()
                         ); 
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
    my $file = basename( $f );
    $message .= "Package: $p\t File: $file\t Line: $l\t Sub: $s\n";
  }
  return $message;
}

#+
#
#-
sub handle_error {
  my $self = shift;
  my %args = @_;
  $args{error_type} ||= 'unknown_error';
  $args{out_mode}   ||= $sbeams->get_output_mode();
  $args{message}    ||= 'Unknown problem';
  $args{state}      ||= 'SBEAMS_ERROR';

  # Use default routine if HTML and sbeams_error
  if ($args{out_mode} eq 'html' && $args{error_type} =~ /unknown|sbeams_err/) {
    die ( $args{message} );
  }

  $args{code} = $self->get_error_code( $args{error_type} );
  
  my $ctype = '';
  my $content = '';
  my @headings = qw( State Code Type Message );

  if ( $args{out_mode} =~ /tsv|tsvfull/ ) {
    $ctype = $sbeams->get_content_type( 'tsv' );
    $content = join( "\t", @headings ) . "\n" .
               join( "\t", @args{qw(state code error_type message)} );
  } elsif ( $args{out_mode} =~ /csv|csvfull/ ) {
    $ctype = $sbeams->get_content_type( 'csv' );
    $content = join( ',', @headings ) . "\n" .
               join( ',', @args{qw(state code error_type message)} );
  } elsif ( $args{out_mode} =~ /html/ ) {
    $content = '<TABLE><TR><TD>';
    $content .= join( "</TD><TD>", @headings ) . '</TD></TR><TR><TD>';
    $content .= join( "</TD><TD>", @args{qw(state code error_type message)} );
    $content .= '</TD></TR></TABLE>';
  } elsif ( $args{out_mode} =~ /interactive/ ) {
    $content = join( "\t", @headings ) . "\n" .
               join( "\t", @args{qw(state code error_type message)} );
  } else {
    $content = join( "\t", @headings ) . "\n" .
               join( "\t", @args{qw(state code error_type message)} );
  }

  # Are we over-reliant on this?
  if ( $ENV{REMOTE_ADDR} && $ctype ) {
    print $sbeams->get_http_header( mode => $args{out_mode} ); 
  }
  print "$content\n";
  exit;
}

sub get_error_code {
  my $self = shift;
  my $code = shift || 'unknown_error';
  my %codes = (  sbeams_error    => '0100',
                 server_disabled => '0200',
                 authen_required => '0300',
                 authen_failed   => '0400',
                 access_denied   => '0500',
                 unknown_error   => '0000',
                'bad constraint' => '1000',
      'insufficient constraints' => '1010',
                'data mismatch'  => '1100', 
            'permission denied'  => '0500'

              );
  return $codes{$code} || $codes{unknown_error};
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

