#!/usr/bin/perl

###############################################################################
# Program     : parseQAheader.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This little program reads in a QuantArray file header
#
# Example     : parseQAheader.pl 00711.qa
#
###############################################################################

  use strict;

  my ($scriptname) = "parseQAheader.pl";
  my ($inputfilename) = $ARGV[0];

  my $verify;
  if ($inputfilename eq "--verify") {
    $verify = 1;
    $inputfilename = $ARGV[1];
  }

  my ($counter) = 0;
  my ($doneflag) = 0;
  my ($unicode) = 0;

  my ($key,$value,$line,$ScanInfoKey);
  my (@data);
  my ($channel,$image_file);
  my $matches = 0;

  #### Define hash to hold misc scan info key value pairs
  my (%ScanInfoKeyValue);

  #### Add the input filename to the hash
  $ScanInfoKeyValue{'input_filename'}=$inputfilename;


  #### Initial hash defining search patterns and corresponding storage keys
  my (%ScanInfoPatternKey) = (
    "User Name","scan_username",
    "Computer","computer_name",
    "Date","scan_date",
    "Experiment","experiment_label",
    "Experiment Path","experiment_path",
    "Protocol","protocol_name",
    "Version","protocol_version",
    "Units","scan_units",
    "Array Rows","array_nrows",
    "Array Columns","array_ncolumns",
    "Rows","grid_nrows",
    "Columns","grid_ncolumns",
    "Array Row Spacing","array_row_spacing",
    "Array Columns Spacing","array_column_spacing",
    "Spot Rows Spacing","spot_row_spacing",
    "Spot Columns Spacing","spot_column_spacing",
    "Spot Diameter","spot_diameter",
    "Spots Per Array","spots_per_array",
    "Total Spots","total_spots",
    "Quantification Method","measurement_method"
  );


  #### Initialize desired hash values to ""
  while ( ($key,$value) = each %ScanInfoPatternKey ) {
    $ScanInfoKeyValue{$value}="";
  }


  #### Open input file
  open(INFILE,$inputfilename)
    || die "$scriptname: Unable to open file '$inputfilename'";


  #### Read in first line
  $line=<INFILE>;
  chomp $line;

  $unicode=0;
  if ( $line =~ m/\0/) { $unicode = 1; }

  if ($unicode) {
    $line =~ s/\0//g;
    $line =~ s/^..//g;		# Hack out first two weird characters
  }
  chop $line;


  #### Process header portion of the input file, putting data in hash
  while ( $doneflag == 0 && $counter < 30 ) {

    ($key,$value) = split("\t",$line);

    $ScanInfoKey = $ScanInfoPatternKey{$key};
    if (defined $ScanInfoKey) {
      $ScanInfoKeyValue{$ScanInfoKey}=$value;
      $matches++;
    }

    if ($line eq "End Protocol Info") { $doneflag=1; }

    last unless ($line=<INFILE>);
    chomp $line;
    if ($unicode) {
      $line =~ s/\0//g;
    }
    chop $line;
    $counter++;
  }


  #### If a sufficient number of matches were't found, bail out.
  if ($matches < 15) {
    print "ERROR: Input file is NOT a QuantArray file!\n";
    exit 1;
  }


  #### Convert the unix date format "Thu Feb 01 14:51:04 2001" into
  #### something a little more standard that a RDBMS will understand
  $ScanInfoKeyValue{'scan_date'} = 
    substr($ScanInfoKeyValue{'scan_date'},4,99);


  #### Unless just verifying, print all the key,value pairs
  unless ($verify) {
    while ( ($key,$value) = each %ScanInfoKeyValue ) {
      printf("%20s  %s\n",$key,$value);
    }
  }


##########################################################

  #### Skip until "Begin Image Info"
  $doneflag=0;
  while ( $doneflag == 0 ) {
    if ($line eq "Begin Image Info") { $doneflag=1; }

    last unless ($line=<INFILE>);
    if (not defined $line) { $doneflag=1; }
    chomp $line;
    if ($unicode) { $line =~ s/\0//g; }
    chop $line;
  }


##########################################################

  #### Process Channel Information
  $doneflag=0;
  $counter=0;
  while ( $doneflag == 0 ) {

    last unless ($line=<INFILE>);
    chomp $line;
    if ($unicode) { $line =~ s/\0//g; }
    chop $line;

    if ($line eq "End Image Info") {
      $doneflag=1;
    } else {
      @data = split /\t/, $line;
      $channel = $data[0];
      $image_file = $data[1];
      @data = split /\\/,$image_file;
      $image_file=$data[$#data];
      print "$channel=$image_file\n";
    }

    $counter++;
  }



