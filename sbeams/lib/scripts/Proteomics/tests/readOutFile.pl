#!/usr/local/bin/perl

###############################################################################
# Program     : readOutFile.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Test program to read a sequest .out file using
#               SBEAMS::Proteomics::Utilities
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


  use strict;

  use lib qw (../perl ../../perl ../../../perl);
  use SBEAMS::Proteomics::Utilities;
  my $sbeamsPR = SBEAMS::Proteomics::Utilities->new();


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);
  my $verbose = 0;


  #### Get the input file as the first input parameter or otherwise a default
  my $inputfile = shift;
  unless ($inputfile) {
    if (1 == 1) {
      $inputfile =
        "/net/dblocal/data/macrogenics/data/CTCL/CTCL1/human_nci/".
        "CTCL1_0910_R01_042202/CTCL1_0910_R01_042202.3654.3654.2.out";
    } else {
      $inputfile =
        "/net/db/projects/proteomics/data/priska/ICAT/".
        "raftapr/raftapr_human/raft0052/raft0052.1052.1052.3.out";
    }
  }


  #### Read the out file
  my %search_data = $sbeamsPR->readOutFile(inputfile => "$inputfile",
    verbose => "$verbose");


  #### Print out all the keys and values for the returned hash
  print "\n\nsearch_data:\n";
  while ( ($key,$value) = each %search_data ) {
    printf("%22s = %s\n",$key,$value);
  }


  #### Print out all the paramters
  print "\nparameters:\n";
  while ( ($key,$value) = each %{$search_data{parameters}} ) {
    printf("%22s = %s\n",$key,$value);
  }


  #### Print out all the search_hits
  print "\nsearch_hits:\n";
  foreach $element ( @{$search_data{matches}} ) {
    print "  $element -> {reference}: $element->{reference}\n";
    if ($element->{search_hit_proteins}) {
      print "\t\t",join(',',@{$element->{search_hit_proteins}}),"\n";
    }
  }


