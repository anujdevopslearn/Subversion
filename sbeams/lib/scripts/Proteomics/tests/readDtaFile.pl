#!/usr/local/bin/perl

###############################################################################
# Program     : readDtaFile.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Test program to read a sequest .dta file using
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
  my $verbose = 0;


  #### Get the input file as the first input parameter or otherwise a default
  my $inputfile = shift;
  unless ($inputfile) {
    if (1 == 1) {
      $inputfile =
        "/net/dblocal/data/macrogenics/data/CTCL/CTCL1/human_nci/".
        "CTCL1_0910_R01_042202/CTCL1_0910_R01_042202.3654.3654.2.dta";
    } else {
      $inputfile =
        "/net/db/projects/proteomics/data/priska/ICAT/".
        "raftapr/raftapr_human/raft0052/raft0052.1052.1052.3.dta";
    }
  }


  #### Read the dta file
  my $result = $sbeamsPR->readDtaFile(inputfile =>$inputfile,
    verbose=>$verbose);


  #### Print out all the paramters
  while ( ($key,$value) = each %{$result->{parameters}} ) {
    printf("%22s = %s\n",$key,$value);
  }


  #### Print an arbitrary paramter
  print "\nNumber of m/z,intensity pairs: ",
    $result->{parameters}->{n_peaks},"\n";


  #### Print out all the m/z, intensity pairs
  for ($i=0; $i<$result->{parameters}->{n_peaks}; $i++) {
    printf "%12.1f %12.1f\n",
      $result->{mass_intensities}->[$i]->[0],
      $result->{mass_intensities}->[$i]->[1];
  }


