#!/usr/local/bin/perl  -X

use strict;
use Getopt::Long;
use FindBin;
use File::stat;

use XML::Parser;
use IO::File;
use LWP::UserAgent;
use File::Copy;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $PROG_NAME $USAGE %OPTIONS $TEST $VERBOSE
             $repository_url $repository_path $repository_path_cp
             $sbeams_data_path
             $errorfile $timestamp_pattern
             $public_php_outfile $notpublic_php_outfile
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

## PeptideAtlas classes
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

## Proteomics (for search_batch::data_location)
use SBEAMS::Proteomics::Tables;

use SBEAMS::PeptideAtlas::SpectraDescriptionSetParametersParser; 	 
use SBEAMS::PeptideAtlas::SearchResultsParametersParser;


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);



my $sql = qq~ 
   SELECT SKE.SEARCH_KEY_NAME, 
          SKE.SEARCH_KEY_ID,
          SKE.resource_name,
          SKL.ATLAS_BUILD_ID
   FROM $TBAT_SEARCH_KEY_ENTITY SKE 
   LEFT JOIN $TBAT_SEARCH_KEY_LINK SKL ON (SKE.RESOURCE_NAME = SKL.RESOURCE_NAME) 
   JOIN $TBAT_DEFAULT_ATLAS_BUILD DAB ON (SKL.ATLAS_BUILD_ID = DAB.ATLAS_BUILD_ID)
   WHERE SKL.ATLAS_BUILD_ID is not null
~;
  
 
my $sth = $sbeams->get_statement_handle($sql);
my $dir = "/regis/sbeams5/nobackup/builds_output/cache";
my $cmd = "rm -f /regis/sbeams5/nobackup/builds_output/cache/*";
system($cmd);
chdir $dir;
my %values = ();
while ( my @row = $sth->fetchrow_array() ) {
  my ($key_name,$key_id,$resource_name,$id)= @row;
  $values{$id}{"$key_id,$resource_name,$key_name,"} = 1;
}

my $fh;

foreach my $id (keys %values){
  open ($fh, ">$id.tsv"); 
  foreach my $key (keys %{$values{$id}}){
    print $fh "$key\n";
  }
}

exit;


