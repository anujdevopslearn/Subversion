#!/usr/local/bin/perl -w

###############################################################################
# Program     : encryptDbPasswd.pl
# $Id$
#
# Description : Utility script to encrypt/decrypt password.  Used with SBEAMS
# to protect database password
#
# SBEAMS is Copyright (C) 2000-2004 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use Crypt::CBC;
use FindBin qw($Bin);
use Getopt::Long;

use lib "$Bin/../../perl/";
use SBEAMS::Connection::Encrypt;

use strict;

main();
exit(0);


###############################################################################
# main
###############################################################################
sub main {

  # Fetch and validate parameters.  Print usage if there is an error
  my %args;
  GetOptions( \%args, 'password=s', 'conf=s', 'decrypt' );

  printUsage( msg => "Must specify password" ) unless $args{password};
  printUsage( msg => "Must specify SBEAMS.conf file" ) unless $args{conf};

  # Open file and read if possible
  die "Config file $args{conf} does not exist" if ( ! -e $args{conf} );
  open( CONF, "<$args{conf}" ) || 
                        die "Unable to open specified file $args{conf}\n"; 

  # Slurp into a scalar, makes substitution easier later.
  my $conf;
    {
    undef local $/;
    $conf = <CONF>;
    }
  my @conf = split "\n", $conf;
  close CONF;

  # Get INSTALL_DATE from SBEAMS.conf if availble
  my @hits = grep{ /INSTALL_DATE/ } @conf;
  my $date = $hits[0];

  if ( !$date ) {
    # If date is not in SBEAMS.conf, insert a new one
    $date = localtime();
    open( CONF, ">$args{conf}" ) || die "Can't open file $args{conf} for writing\n"; 
    $conf =~ s/(\[default\])/$1\n#### Date SBEAMS was installed\nINSTALL_DATE = $date\n/gm;
    print CONF $conf;
    close CONF;
  } else {
    # If the date is there, use it
    $date =~ /\=\s+(.*)$/;
    $date = $1;
  }

  # Some versions of IDEA can only use a 16-bit key, minimize redundant chars.
  $date =~ s/[\s\:]//g;
  $date = substr( $date, 0, 16 );

  # Crafty crafty, use date as Crypt key value
  my $sCryptor = SBEAMS::Connection::Encrypt->new( 
                                         decrypted => $args{password},
                                         key => $date );

  unless ( $args{decrypt} ) {
  print $sCryptor->encrypt() . "\n";
  exit 0;
  }
  # Undocumented feature, will decrypt on demand!
  $sCryptor->setEncrypted( encrypted => $args{password} );
  print $sCryptor->decrypt() . "\n";
}

sub printUsage {
  my %args = @_;
  my $msg = ( defined $args{msg} ) ? $args{msg} : '';
  print <<"  END";
  $msg

  USAGE: encryptDbPassword.pl -p password -k key 
  OPTIONS: --conf -c   SBEAMS.conf file to use 
           --password -p   password to encrypt
  END
  exit (0);
}
