#!/usr/local/bin/perl

###############################################################################
# Program     : readSummaryFile.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Test program to read an Interact summary file using
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
        "CTCL1_0910_R01_042202.html";
    } else {
      $inputfile =
        "/net/db/projects/proteomics/data/priska/ICAT/".
        "raftapr/raftapr_human/raft0052.html";
    }
  }


  #### Read the summary file
  $|=1;
  print "Reading file...";
  my $result = $sbeamsPR->readSummaryFile(inputfile =>$inputfile,
    verbose=>$verbose);


  print "\nresult = ",$result,"\n\n";

  print "key,value pairs:\n";
  while ( ($key,$value) = each %{$result} ) {
    print "  $key = $value\n";
  }
  print "\n";


  #### Loop over each row
  my ($key2,$value2);
  foreach $element qw ( CTCL1_0910_R01_042202.2490.2490.3 CTCL1_0910_R01_042202.1894.1894.3 ) {
    $key = "$element.out";
    $value = $result->{files}->{$key};
    print "  $key = $value\n";
    while ( ($key2,$value2) = each %{$result->{files}->{$key}} ) {
      print "     $key2 = $value2\n";
    }
  }


  exit;


  #### Loop over each row
  while ( ($key,$value) = each %{$result->{files}} ) {
    print "  $key = $value\n";
    while ( ($key2,$value2) = each %{$result->{files}->{$key}} ) {
      print "     $key2 = $value2\n";
    }
  }





