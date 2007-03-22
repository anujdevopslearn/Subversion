#!/usr/local/bin/perl -w

###############################################################################
# Program     : readParamsFile.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Test program to read a sequest sequest.params file using
#               SBEAMS::Proteomics::Utilities
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use Getopt::Long;
use FindBin;

use vars qw ($PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n            Set verbosity level.  default is 0
  --inputlistfile xx     Text file containing parameter files to test read
  --paramfile xx         Specify paramer file to test read

 e.g.: $PROG_NAME --inputlistfile testParamsFiles.txt
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","inputlistfile:s","paramfile:s",
    )) {

    print "\n$USAGE";
    exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;

main();



###############################################################################
# main
###############################################################################
sub main {

  #### Set up the SBEAMS - Proteomics module Utilities object
  use lib qw (../perl ../../perl ../../../perl);
  use SBEAMS::Proteomics::Utilities;
  my $sbeamsPR = SBEAMS::Proteomics::Utilities->new();

  my @inputfiles;

  #### Pick up a specified parameter to test
  if ($OPTIONS{paramfile}) {
    push(@inputfiles,$OPTIONS{paramfile});
  }

  #### Pick up an input file of parameter files
  if ($OPTIONS{inputlistfile}) {
    if (open(INFILE,$OPTIONS{inputlistfile})) {
      while (my $line = <INFILE>) {
	$line =~ s/[\r\n]//g;
	push(@inputfiles,$line) if ($line);
      }
    } else {
      die("ERROR: Unable to open file '$OPTIONS{inputlistfile}'");
    }
  }

  #### If there are any unresolved parameters, exit
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }

  #### If no parameters, show help
  unless ($OPTIONS{paramfile} || $OPTIONS{inputlistfile}) {
    print "$USAGE";
    exit;
  }


  #### Loop over all specified files
  foreach my $inputfile (@inputfiles) {

    #### Check that file exists
    print "#### $inputfile\n";
    if (! -e $inputfile) {
      print "ERROR: Unable to find file '$inputfile'\n\n";
      next;
    }

    #### Read the parameter file
    my $result = $sbeamsPR->readParamsFile(inputfile =>$inputfile,
      verbose=>$VERBOSE);


    #### Show some information
    print "Loaded ".scalar(@{$result->{keys_in_order}})." parameters.\n";
    print "\$result has:\n";
    foreach my $key (keys(%{$result})) {
      print "  $key = $result->{$key}\n";
    }

    #### If verbose, show all parameters
    if ($VERBOSE) {
      print "Key Value pairs:\n";
      foreach my $key (@{$result->{keys_in_order}}) {
	my $value = $result->{parameters}->{$key};
	print "  $key = $value\n";
      }
    }

    print "\n";

  }

}
