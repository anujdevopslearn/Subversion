#!/usr/local/bin/perl -w

###############################################################################
# Program     : driver_table_file_strip.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script strips driver table files to just the necessary
#               database table components for a diff between versions
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use Getopt::Long;
use FindBin;
use vars qw ( $PROG_NAME $USAGE );

#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME older_version_columns_file newer_version

 e.g.:  $PROG_NAME \$PREV/Proteomics_table_column.txt \$NEW/Proteomics_table_column.txt

EOU

main();
exit 0;


###############################################################################
# Main Program:
#
# Just strip out the important columns of each
###############################################################################
sub main {

  my $older_file = $ARGV[0] || '';
  my $newer_file = $ARGV[1] || '';

  unless (-e $older_file) {
    die("ERROR: Unable to find file 1 '$older_file'\n$USAGE\n");
  }


  unless (-e $newer_file) {
    die("ERROR: Unable to find file 1 '$newer_file'\n$USAGE\n");
  }

  my $line;
  my @files;
  push(@files,$older_file,$newer_file);

  foreach my $file ( @files ) {
    open(INFILE,$file) || die("Unable to open file '$file'");
    my $outfile = "$file-strip";
    open(OUTFILE,">$outfile") || die("Unable to open output file '$outfile'");
    print "Writing $outfile\n";
    while ($line = <INFILE>) {
      $line =~ s/[\r\n]//g;
      my @columns = split(/\t/,$line);
      my @newcolumns;
      foreach my $col ( qw (0 2 4 5 6 7 8 9 ) ) {
	push(@newcolumns,$columns[$col]);
      }
      print OUTFILE join("\t",@newcolumns),"\n";
    }

    close(INFILE);
    close(OUTFILE);

  }


} # end main

