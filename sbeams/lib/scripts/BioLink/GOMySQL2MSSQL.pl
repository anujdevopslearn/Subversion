#!/usr/local/bin/perl -w

###############################################################################
# Program     : GOMySQL2MSSQL.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: DataImport.pl 3704 2005-06-27 17:10:59Z dcampbel $
#
# Description : This script converts the MySQL format CREATE TABLES commands
#               to SQL Server format
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
$| = 1;

use vars qw (
             %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


#### Process options
processOptions();

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit 0;



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  my $input_file = $OPTIONS{input_file} || die("No input file");
  my $output_root = $OPTIONS{output_root} || die("No output root");

  die("ERROR: Unable to find input file $input_file")
    unless (-e $input_file);

  die("ERROR: Unable to open input file $input_file")
    unless (open(INFILE,$input_file));

  die("ERROR: Unable to open output file $output_root.CREATE.mssql")
    unless (open(OUTFILE,">$output_root.CREATE.mssql"));

  die("ERROR: Unable to open output file $output_root.DROP.mssql")
    unless (open(OUTFILEDROP,">$output_root.DROP.mssql"));

  die("ERROR: Unable to open output file $output_root.DROP.mssql")
    unless (open(OUTFILEBCP,">$output_root.BCP.bat"));

  my $line;
  my $within_CREATE_statement = 0;
  my $delay_buffer = '';
  my $buffer = '';

  while ($line=<INFILE>) {

    if ($line =~ /^--/) {
      print OUTFILE $line;
      next;
    }

    if ($line =~ /\s*DROP TABLE/) {
      $line =~ s/`//g;
      $line =~ s/IF EXISTS //g;
      $line =~ s/;/\nGO/;
      print OUTFILEDROP $line;
      next;
    }

    if ($line =~ /\s*CREATE TABLE/) {
      $within_CREATE_statement = 1;
      $line =~ s/`/dbo./;
      $line =~ s/`//g;
      print OUTFILE $line;

      if ($line =~ /CREATE TABLE (\w+)/) {
	print OUTFILEBCP "bcp FGCZ_GO.dbo.$1 in $1.txt -b 10000 -c -E -U fgcz_go -P fgcz_go\n";
      }

      next;
    }

    if ($within_CREATE_statement) {
      if ($line =~ /^\s*\)/) {
	if ($delay_buffer) {
	  $delay_buffer =~ s/,\s*$//;
	  print OUTFILE "$delay_buffer\n";
	  $delay_buffer ='';
	}
	print OUTFILE ")\nGO\n";
	$within_CREATE_statement = 0;
	next;

      } elsif ($line =~ /\s*PRIMARY KEY/) {
	$line =~ s/`//g;
        $line =~ s/,\s*$//;
        print OUTFILE $delay_buffer;
	$delay_buffer = $line;
        next;
 
      } elsif ($line =~ /\s*KEY/) {
        next;
 
      } else {
	$line =~ s/`//g;
        $line =~ s/int\(\d+\)/int/g;
	$line =~ s/auto_increment//;
	$line =~ s/mediumtext/text/;
	print OUTFILE $delay_buffer;
        $delay_buffer = $line;
        next;
      }
    }

  }


  close(INFILE);
  close(OUTFILE);
  close(OUTFILEDROP);

}


###############################################################################
# processOptions
###############################################################################
sub processOptions {
  GetOptions( \%OPTIONS, "verbose:s", "quiet", "debug:s", "testonly", 'help',
             'input_file=s','output_root=s',
  ) || printUsage( "Failed to get parameters" );

  for my $param ( qw(input_file output_root) ) {
    print "$param=$OPTIONS{$param}\n" if ($DEBUG);
    printUsage( "Missing required parameter $param" ) unless $OPTIONS{$param};
  }
}



###############################################################################
# processOptions
###############################################################################
sub printUsage {
  my $msg = shift;

  my $usage = <<"  EOU";
  $msg


  Usage: $0 -s source_file.xml [ -v -d -t ]
    Options:
    -v, --verbose n           Set verbosity level.  default is 0
    -q, --quiet               Set flag to print nothing at all except errors
    -d, --debug n             Set debug flag
    -h, --help                Print usage and exit, overrides all other options.
    -t, --testonly            Set to not actually write to database

    -i, --input_file xxxx     File from which SQL is read
    -o, --output_root xxxx    Root of filenames to which new SQL is written

   e.g.:  $0 --input_file go_200508-termdb-data.mysql --output_root go

  EOU

  print $usage;
  exit(0);

}





