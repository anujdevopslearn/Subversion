#!/usr/local/bin/perl -w

###############################################################################
#
###############################################################################


###############################################################################
   # rebuild all atlas index after each big load  
###############################################################################

use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username
             $ATLAS_BUILD_ID %spectra
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $sbeamsPROT  $UPDATE_ALL
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);

$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

if (! $ENV{user} || ! $ENV{password}){
   die  "need to set environment varialbe \"\$user, \$password\" \n";
}


my $file = "$FindBin::Bin/../../sql/PeptideAtlas/PeptideAtlas_CREATEINDEXES.mssql";
my $cmd = "$FindBin::Bin/../../scripts/Core/runsql.pl -u $ENV{user} -p $ENV{password} -i -m  ";

 
open (IN, "<$file" ) or die "cannot open $file \n";


my $module = $sbeams->getSBEAMS_SUBDIR();
my $database =  $DBPREFIX{$module};

my $flag = 0;
while (my $line = <IN>){
  chomp $line ;
  next if($line =~ /^$/);
  if ($line =~ /use Peptideatlas/i){
    $flag = 1;
    next;
  }
  #if($line =~ /^--\s+/ && $line !~ /atlas_build INDEXES/){
  if ($line =~ /consensus/){
    $flag = 0;
  }
  if ($flag){
    $line =~ s/\-\-WITH/ WITH/; 
    $line =~ s/dbo./$database/;
    print "$line\n";
    my $log = `$cmd '$line'`;
  }

}

close IN;
exit; 

