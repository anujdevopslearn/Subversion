#!/usr/local/bin/perl -w

###############################################################################
# Program     : crypt.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script UNIX crypts the input string suitable for
#               using as a crypted password string
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;

main();
exit(0);


###############################################################################
# main
###############################################################################
sub main {

  my $password = $ARGV[0];
  unless ($password) {
    print("USAGE: crypt.pl <password>\n\n");
    exit(1);
  }

  $password =~ s/[\r\n]//g;


  my $salt = sprintf("%c%c",int(rand(26))+65,int(rand(26))+65);

  my $result = crypt($password,$salt);

  print "$result\n";

}

