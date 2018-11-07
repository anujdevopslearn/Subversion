#!/usr/local/bin/perl

###############################################################################
# Program     : create_PASS_Json.pl 
# $Id: GetPeptide 6798 2011-07-05 21:35:27Z tfarrah $
#
# Description : encode PASS submisson into json format  
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use utf8;
use Encode qw(encode decode);
use lib "$ENV{SBEAMS}/lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ConsensusSpectrum;
use SBEAMS::PeptideAtlas::ModificationHelper;
use SBEAMS::PeptideAtlas::Utilities;

use SBEAMS::Proteomics::Tables;
$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME 
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
my $enc = 'utf-8';

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}

my ($date) = `date '+%F %T'`;
chomp($date);

my $sql = qq~
	SELECT datasetidentifier,
				 datasetTag,
				 datasetTitle,
         datasetType,
				 UPPER(left(lastname,1))+ 
         LOWER(SUBSTRING(lastname,2,len(lastname)))+','+
         UPPER(left(firstname,1))+
         LOWER(SUBSTRING(firstname,2,len(firstname))), 
				 emailAddress,
				 publicReleaseDate,
				 finalizedDate
	FROM $TBAT_PASS_SUBMITTER S
	JOIN $TBAT_PASS_DATASET D ON (D.submitter_id = S.submitter_id)
~;
my @rows = $sbeams->selectSeveralColumns($sql);
foreach my $row ( @rows ) {
 #$row->[0] = qq~<a href="http://www.peptideatlas.org/PASS/$row->[0]">$row->[0]</a>~;
}
my @labels = qw ( id datasettag title type submitter email release finalize);
#unshift @rows, \@labels;
use JSON;
my $json = new JSON;
my $hash;
foreach my $row (@rows){
	my %data=();
	foreach my $i (0..$#labels){
		if ($i == 6 || $i == 7){
		 my $date = $row->[$i];
		 $date =~ /(\d{4})-0?(\d+)-0?(\d+)\D+/;
			$data{dates}{$labels[$i]}{std}{year} = $1;
			$data{dates}{$labels[$i]}{std}{month} = $2;
			$data{dates}{$labels[$i]}{std}{day} = $3;
		}else{
      if(! Encode::is_utf8($row->[$i])){
        $row->[$i] =  decode($enc, $row->[$i]);
      }
		 $data{$labels[$i]} = $row->[$i];
		}
	}
  ## open and read description file
  my $datasetidentifier =  $row->[0] ;
  my $file = "/proteomics/peptideatlas2/home/$datasetidentifier/$datasetidentifier"."_DESCRIPTION.txt";
  if (open(INFILE,"<$file")){
		my ($key,$value);
		my $prevKey = '';
		while (my $line = <INFILE>) {
			$line =~ s/[\r\n]//g;
			if ($line =~ /^\s*([^:]{0,}):\s*(.*)$/) {
				$key = $1;
				$value = $2;
				$data{$key} = $value;
				$prevKey = $key;
			} else {
				$key = $prevKey;
				$data{$key} .= $line;
			}
		}
  }else{
     print  "cannot open $file\n";
  }
  push @{$hash->{MS_QueryResponse}{samples}}, {%data};
}

close(INFILE);
$hash ->{"MS_QueryResponse" }{"counts"}{"samples"} = scalar @rows;
open(OUT, ">/proteomics/peptideatlas2/PASS.json") or die "cannot open /proteomics/peptideatlas2/PASS.json\n";

$json = $json->pretty([1]);
print  OUT $json->encode($hash);
close OUT;
exit;

