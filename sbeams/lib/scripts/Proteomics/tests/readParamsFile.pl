#!/usr/local/bin/perl

###############################################################################
# Program     : readParamsFile.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Test program to read a sequest sequest.params file using
#               SBEAMS::Proteomics::Utilities
#
###############################################################################


  use strict;

  #### Set up the SBEAMS - Proteomics module object
  use lib qw (../perl ../../perl ../../../perl);
  use SBEAMS::Proteomics::Utilities;
  my $sbeamsPR = SBEAMS::Proteomics::Utilities->new();


  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);
  my $verbose = 1;


  #### Get the input file as the first input parameter or otherwise a default
  my $inputfile = shift;
  unless ($inputfile) {
    if (1 == 1) {
      $inputfile =
        "/net/dblocal/data/macrogenics/data/CTCL/CTCL1/human_nci/".
        "CTCL1_0910_R01_042202/sequest.params";
    } else {
      $inputfile =
        "/net/db/projects/proteomics/data/priska/ICAT/".
        "raftapr/raftapr_human/raft0052/sequest.params";
    }
  }


  #### Read the sequest.params file
  my $result = $sbeamsPR->readParamsFile(inputfile =>$inputfile,
    verbose=>$verbose);


  print "resulting object is ",$result,"\n";
  print "key_in_order is a ",$result->{keys_in_order},"\n";
  print "key,values:\n";

  #### Loop over each row
  foreach $key (@{$result->{keys_in_order}}) {
    $value = $result->{parameters}->{$key};
    print "  $key = $value\n";
  }


