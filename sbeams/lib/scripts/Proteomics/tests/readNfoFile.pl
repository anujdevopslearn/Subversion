#!/usr/local/bin/perl

###############################################################################
# Program     : readNfoFile.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Test program to read a .nfo file (containing spectrum scan_time
#               information derived from the .dat file with `datinfo`) using
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
        "/net/dblocal/data/macrogenics/data/CTCL/CTCL1/human_nci/../".
        "CTCL1_0910_R01_042202.nfo";
    } else {
      $inputfile =
        "/net/db/projects/proteomics/data/priska/ICAT/".
        "raftapr/raftapr_human/../raft0052.nfo";
    }
  }


  #### Read the summary file
  $|=1;
  print "Reading file...";
  my %msrun_data = $sbeamsPR->readNfoFile(source_file=>$inputfile,
    verbose=>$verbose);


  #### Print out the contents of the returned hash
  print "\n\nmsrun_data:\n";
  while ( ($key,$value) = each %msrun_data ) {
    printf("%22s = %s\n",$key,$value);
  }


  #### Print out all the parameters
  print "\nparameters:\n";
  while ( ($key,$value) = each %{$msrun_data{parameters}} ) {
    printf("%22s = %s\n",$key,$value);
  }


  print "\ncolumns:\n";
  foreach $element ( @{$msrun_data{columns}} ) {
    print "  $element\n";
  }


  print "\nsample data:\n";
  for ($i=0; $i<15; $i++) {
    print $msrun_data{spec_data}->[$i]->[0],"\t",
      $msrun_data{spec_data}->[$i]->[3]/10000.0,"\n";
  }






