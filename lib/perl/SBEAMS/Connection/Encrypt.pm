###############################################################################
# Program     : SBEAMS::Connection::Encrypt.pm
# $Id$
#
# Description :  Simple module that utilizes Crypt::CBC to allow encryption and
#                decryption of passwords, specifically for allowing database
#                password to be encrypted.  Uses encrypt_hex and decrypt_hex
#                to ensure results contain only printable characters.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use Exporter;
use Crypt::CBC;

package SBEAMS::Connection::Encrypt;
my @ISA = "Exporter";
my @EXPORT	= qw( encrypt decrypt );

use SBEAMS::Connection::Log;
my $log = new SBEAMS::Connection::Log();

sub new {
  my $class = shift;
  my $this = { key => undef,
               encrypted => undef,
               decrypted => undef,
               @_ };
  bless $this, $class;
  return $this;
}

sub setKey {
  my $this = shift;
  my %args = @_;
  die ( "Must specify key" ) unless $args{key};
  $this->{key} = $args{key};
}

sub setDecrypted {
  my $this = shift;
  my %args = @_;
  die ( "Must specify decrypted string" ) unless $args{decrypted};
  $this->{decrypted} = $args{decrypted};
}

sub setEncrypted {
  my $this = shift;
  my %args = @_;
  die ( "Must specify encrypted string" ) unless $args{encrypted};
  $this->{encrypted} = $args{encrypted};
}


sub encrypt {
  my $this = shift;
  my %args = @_;
  # We will operate by default on passed value
  $this->{decrypted} = ( defined ( $args{value} ) ) ? $args{value} : 
                                                      $this->{decrypted};
 
  # We will operate by default on passed key
  $this->{key} = ( defined ( $args{key} ) ) ? $args{key} : $this->{key};
 
  # If we don't have a value, we can't proceed
  die ( "No string provided for encryption" ) unless $this->{decrypted};
  die ( "No key provided for encryption" ) unless $this->{key};

  my $cipher;
  my $version = $Crypt::CBC::VERSION;
  $log->debug( "Crypt::CBC version is $version" );

  if ( $version <= 2.17 ) {
    $cipher = new Crypt::CBC( $this->{key}, 'IDEA' );
  } else {
    $cipher = new Crypt::CBC( -key => $this->{key},
                           -cipher => 'IDEA',
                           -header => 'randomiv' );
  }

  $this->{encrypted} = $cipher->encrypt_hex( $this->{decrypted} );
  return $this->{encrypted}
}

sub decrypt {
  my $this = shift;
  my %args = @_;
  # We will operate by default on passed value
  $this->{encrypted} = ( defined ( $args{value} ) ) ? $args{value} : 
                                                      $this->{encrypted};
 
  # We will operate by default on passed key
  $this->{key} = ( defined ( $args{key} ) ) ? $args{key} : $this->{key};
 
  # If we don't have a value, we can't proceed
  die ( "No string provided for decryption" ) unless $this->{encrypted};
  die ( "No key provided for decryption" ) unless $this->{key};

  if ( $this->{encrypted} !~ /^[a-fA-F0-9]+$/ ) {
    print STDERR "Rejected attempt to decrypt non-hex value\n";
    return undef;
    }

  my $cipher;
  my $version = $Crypt::CBC::VERSION;
  $log->debug( "Crypt::CBC version is $version" );

  if ( $version <= 2.17 ) {
    $cipher = new Crypt::CBC( $this->{key}, 'IDEA' );
  } else {
    $cipher = new Crypt::CBC( -key => $this->{key},
                           -cipher => 'IDEA',
                           -header => 'randomiv' );
  }

  $this->{decrypted} = $cipher->decrypt_hex( $this->{encrypted} );
  return $this->{decrypted}
}

###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::Encrypt

SBEAMS Core 

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

