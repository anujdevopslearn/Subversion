#!/usr/local/bin/perl

###############################################################################
# Program     : GetPXD_dataset.pl 
# $Id: GetPXD_dataset.pl 6798 2013-03-05 21:35:27Z zsun $
#
# Description : check proteomexchange dataset and create a table for that. 
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
use Unicode::Normalize;

use JSON;
use FindBin;
use lib "$ENV{SBEAMS}/lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS $TEST);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;
use SBEAMS::Connection::Utilities;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeams = new SBEAMS::Connection;

use HTTP::Request::Common;
use LWP::UserAgent;

#### Process options
unless (GetOptions(\%OPTIONS,"test:s", "verbose:s","quiet","debug:s", "update")) {
  print "$USAGE";
  exit;
}

$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --update 
 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Set some specific settings for this program
my $CATEGORY="Get_public_repository_dataset.pl";
my $PROGRAM_FILE_NAME = $PROG_NAME;
my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/$PROGRAM_FILE_NAME";
my $help_url = "$CGI_BASE_DIR/help_popup.cgi";


$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TEST = $OPTIONS{"test"} || 0;

get_from_proteomexchange ();
#get_from_PASSEL();


#################################################################################
## process dataset in proteomexchang
#################################################################################

sub get_from_proteomexchange{
	my $ua=LWP::UserAgent->new;
	my $result = $ua->get ("http://proteomecentral.proteomexchange.org/cgi/GetDataset?outputMode=tsv");
	my @rows = split(/\n/,  $result->content);

	### table columns
	# 1. dataset_id
	# 2. dataset_identifier
	# 3. source_repository
	# 4. datasetTitle
	# 5. datasetType
	# 6. datasetDescription
	# 7. species
	# 8. contributor
	# 9. publication
	# 10. publicReleaseDate
	# 11. date_created
	# 12. classfication
	# 13. local_data_location
	# 14. pa_sample_accession
	# 15. instrument


	# remove header
	shift @rows;
  ## header 
  # Dataset Identifier	
  # Repository	
  # Primary Submitter	
  # LabHead	
  # Title	
  # Species	
  # Instrument	
  # Publication	
  # Announcement Date
	foreach my $line(@rows){
		#print "$line\n";
    $line =~ s/[\r\n]/ /g; 
    $line = Encode::decode( 'iso-8859-1', $line );
    $line = NFD( $line );   ##  decompose
    $line =~ s/\pM//g;         ##  strip combining characters
    $line =~ s/[^\0-\x80]//g;  ##  clear everything else

		my @row = split(/\t/, $line);
		next if($row[2] =~ /PeptideAtlas/i);
		## check if dataset in the table already
    $row[0] =~ /(PXD\d+)/;
    $row[0] = $1;
    next if ($row[0] =~ /(PXD020015|PXD021091)/);
  
    my $id = check_table($row[0], $row[2]);

		my $publication = $row[5];
		my $pubmed = get_pubmed ($publication);

		if($pubmed){
			$publication = $pubmed; 
		}

		if (length ($row[1])> 100){
			$row[1] =~ s/(.{97}).*/$1.../;
		}
    if (length ($row[3])> 100){
      $row[3] =~ s/(.{97}).*/$1.../;
    }

    if ($row[5] =~ /pubmed\/(\d+)/){
      $row[5] = $1;
    }

    #$row[1] = Encode::decode( 'iso-8859-1', $row[1] ); 
    #$row[1] = NFD( $row[1] );   ##  decompose
    #$row[1] =~ s/\pM//g;         ##  strip combining characters
    #$row[1] =~ s/[^\0-\x80]//g;  ##  clear everything else 

		if($id){
      next if (! $OPTIONS{"update"});
      print "$row[0]\n";
			# do update
       my %rowdata =(
          'dataset_identifier' => $row[0],
          'source_repository' => $row[2],
          'contributor' => $row[6],
          'datasetTitle' => $row[1],
          'species' => $row[3],
          'instrument' => $row[4],
          'publication' => $row[5],
       );
      $sbeams->updateOrInsertRow(
            update => 1,
            table_name => $TBAT_PUBLIC_DATA_REPOSITORY,
            rowdata_ref => \%rowdata,
            PK => 'DATASET_ID',
            PK_value => $id,
            testonly => $TEST
       );
 
		}else{
       print "$row[0]\n";
       next if ($row[0] eq '');
			 my %rowdata =(
					'dataset_identifier' => $row[0],
					'source_repository' => $row[2],
					'contributor' => $row[6],
					'datasetTitle' => $row[1],
					'species' => $row[3],
					'instrument' => $row[4],
					'publication' => $row[5],
					'publicReleaseDate' => 'CURRENT_TIMESTAMP', 
					'date_created' => 'CURRENT_TIMESTAMP',
					'record_status' => 'N',
			 );
			 my $PK = $sbeams->updateOrInsertRow(
						insert => 1,
						table_name => $TBAT_PUBLIC_DATA_REPOSITORY,
						rowdata_ref => \%rowdata,
						PK => 'DATASET_ID',
						return_PK => 1,
						testonly => $TEST
			 );
		 }
	 }
}


################################################################################
## process dataset in PASSEL
#################################################################################
sub get_from_PASSEL{
  my $file = "/regis/passdata/PASS.json" ;
  my $json = new JSON;
  open(IN, "<$file");
  my @contents = <IN>;
  my $jsonstr = join("", @contents);
  my $hash = $json -> decode($jsonstr);
  my $idx=0;
  my ($date) = `date '+%F'`;
  chomp($date);
  $date =~ s/\-//g;
  foreach my $dataset (@{$hash->{"MS_QueryResponse"}{samples}}){
    my $email = $dataset->{"email"};
    my $year =  $dataset->{dates}{release}{std}{year};
    my $month = $dataset->{dates}{release}{std}{month};
    my $day = $dataset->{dates}{release}{std}{day};
    $month = substr('00', 0,2- length($month)).$month;
    $day = substr('00', 0,2- length($day)).$day;
    my $releaseDate = "$year$month$day";
    #next if($dataset->{"type"} !~ /msms/i);
    my $flag = 0;
    if ($date > $releaseDate){
      $flag = 1;
    }
    next if (! $flag);
    next if(! $dataset->{"species"} || $dataset->{"species"} eq '');
    my $dataset_identifier = $dataset->{"identifier"};
    next if($dataset_identifier=~/(PASS00049|PASS00541)/);
    my $source_repository = 'PASSEL';
    if (!  $dataset_identifier ){
      $dataset_identifier =  $dataset->{"id"};
    }

		my ($datasetTitle, $publication, $contributor);
		if (defined $dataset->{"title"} ){
			$datasetTitle = $dataset->{"title"};
		}else{
			 $datasetTitle = $dataset->{"tag"};
		}
		if( $dataset->{"contributors"} =~ /([^,]+),.*/){
			$contributor = "$1 et al.";
		}else{
			$contributor = $dataset->{"contributors"} ;
		}
 
    my $publication = $dataset->{"publication"};
    my $pubmed = '';
    if ($publication){
      $pubmed =  get_pubmed ($publication);
    }
    if($pubmed){
      $publication = $pubmed;
    }

    my $id = check_table($dataset_identifier, $source_repository);
    if (length ($dataset->{"species"})> 100){
      $dataset->{"species"} =~ s/(.{97}).*/$1.../;
    }



    if($id){
      # do update
      next if(! $OPTIONS{"update"});
      my %rowdata =(
          'dataset_identifier' => $dataset_identifier,
          'source_repository' => $source_repository,
          'contributor' => $contributor,
          'datasetTitle' => $datasetTitle,
          'species' => $dataset->{"species"},
          'instrument' => $dataset->{"instruments"},
          'publication' => $publication,
          'datasetType' => $dataset->{"type"},
       );
      $sbeams->updateOrInsertRow(
            update => 1,
            table_name => $TBAT_PUBLIC_DATA_REPOSITORY,
            rowdata_ref => \%rowdata,
            PK => 'DATASET_ID',
            PK_value => $id,
            testonly => $TEST
       );
    }else{
      print "$dataset_identifier\n";
      #print "1: $dataset->{contributors} \n2: $contributor\n";
      my %rowdata =(
          'dataset_identifier' => $dataset_identifier,
          'source_repository' => $source_repository,
          'contributor' => $contributor,
          'datasetTitle' => $datasetTitle,
          'species' => $dataset->{"species"},
          'instrument' => $dataset->{"instruments"},
          'publication' => $publication, 
          'publicReleaseDate' => "$year-$month-$day",
          'datasetType' => $dataset->{"type"}, 
          'date_created' => 'CURRENT_TIMESTAMP',
          'record_status' => 'N',
       );
       my $PK = $sbeams->updateOrInsertRow(
            insert => 1,
            table_name => $TBAT_PUBLIC_DATA_REPOSITORY,
            rowdata_ref => \%rowdata,
            PK => 'DATASET_ID',
            return_PK => 1,
            testonly => $TEST,
            verbose => $VERBOSE,
       );
    }
  }

}

sub get_pubmed {
  my $publication = shift;
	my $pubmed = '';
  my $url ; 
  chomp $publication;
  $publication =~ s/submitted//i;
  $publication =~ s/\W+$//;
	if($publication =~ /(\d{8})/){
		$pubmed = $1;
	}else{
		my $query = $publication;
		$query =~ s/\s+/+/g;
    $query =~ s/,/%2C/g;
    $query =~ s/\(/%28/g;
    $query =~ s/\)/%29/g;
    $query=~ s/\++/+/g;
    #$url = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=$query";
    $url = "http://www.ncbi.nlm.nih.gov/pubmed/?term=$query";
    my $ua=LWP::UserAgent->new;
		my $result = $ua->get($url);
    my $content = $result->content;
		#my @ids = ($result->content =~ /<Id>(\d{8})<\/Id>/g);
    if($content =~ /<h3>Abstract<\/h3><div class=""><p>/){
      $content =~ />(\d{8})(<\/span>)?<\/dd> <dd> \[PubMed/;
			$pubmed = $1;
      #print "1: $publication \n$url \n$pubmed\n\n";
		}
	}
  return $pubmed;
}
sub check_table{
  my $id= shift;
  my $source = shift;
	my $sql = qq~ 
			SELECT DATASET_ID
			FROM $TBAT_PUBLIC_DATA_REPOSITORY
			WHERE DATASET_IDENTIFIER= \'$id\' AND SOURCE_REPOSITORY= \'$source\'
	~;
	my @rows = $sbeams->selectOneColumn($sql);
  if(@rows > 1){
    print "more than one record for $id $source\n"; 
    exit;
  }else{
    return $rows[0];
  }
}


