#!/usr/local/bin/perl -w

###############################################################################
# Author      : Zhi Sun
# Purpose     : create cache webpages 
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Time::Local; 
use Getopt::Long;
use FindBin;
use HTTP::Tiny;
use Digest::MD5 qw( md5_hex );
 
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $ATLAS_BUILD_ID 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TEST
            );
use lib "$ENV{SBEAMS}/lib/perl/";
#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

my %OPTIONS;
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --atlas_build_id    create cache file for this build only
  --buildDetail
  --prot_list         protein list file for caching protein page
  --getProtein
  --dev       
  --help
 $PROG_NAME --getProtein \
            --prot_list mapping_count_over_1000.txt \
            --atlas_build_id 491

 $PROG_NAME --buildDetail 
 $PROG_NAME --buildDetail --atlas_build_id 491 --dev devZS

EOU

GetOptions(\%OPTIONS,"atlas_build_id:i","prot_list:s","dev:s", "buildDetail","getProtein","help|h");
our ($cache_location, $BASE_URL);

if ($OPTIONS{help}){
  print $USAGE;
}
if ($OPTIONS{dev}){
  $cache_location = "/net/dblocal/www/html/$OPTIONS{dev}/sbeams/htmlcache";  
  $BASE_URL ="https://db.systemsbiology.net/$OPTIONS{dev}/sbeams";
}else{
  $cache_location= "/net/dblocal/www/html/sbeamscommon/htmlcache";
  $BASE_URL ="https://db.systemsbiology.net/sbeams";
}
if (! -d "$cache_location"){
  die "directory $cache_location not found\n";
}

main();

exit(0);

###############################################################################
# Main Program:
###############################################################################
sub main {

  if ($OPTIONS{buildDetail}){
    cache_buildDetail();
  }
  if ($OPTIONS{getProtein}){
    cache_getProtein();
  }



} # end main




###################################################################
#                       buildDetail pages
###################################################################
### get list of public build ids
sub cache_buildDetail {
	my $atlas_build_id = $OPTIONS{atlas_build_id} || ''; 
  
	my $sql = qq~
		SELECT atlas_build_id atlas_build_name
		FROM $TBAT_ATLAS_BUILD_PUBLIC 
	~;
	my %ids = $sbeams->selectTwoColumnHash($sql); 
  my $SBEAMSentrycode='';
  if ($atlas_build_id && not defined $ids{$atlas_build_id}){
     ## internal build
     ## get entry code
     $SBEAMSentrycode = `grep html /net/dblocal/www/html/sbeams/lib/conf/SBEAMSentrycodes.conf | sed 's/\\s\\+.*//'`;
     chomp $SBEAMSentrycode;
     if (! $SBEAMSentrycode){
       die "no SBEAMSentrycode found. Cannot create page for internal build\n";
     }
     $SBEAMSentrycode = '&SBEAMSentrycode=' .$SBEAMSentrycode;
     $ids{$atlas_build_id} =1;
  }


  my $query_url="$BASE_URL/cgi/PeptideAtlas/buildDetails?atlas_build_id=";

	foreach my $id(keys %ids){
		next if ($atlas_build_id && $id ne $atlas_build_id);
    my $request_url="$query_url$id";
    #my $url_mdsum = md5_hex( $request_url );
    my $cache_filename = $request_url;
    $cache_filename =~ s/.*\?//;
		my $url = "$query_url$id$SBEAMSentrycode\&caching=1";
		my $response = HTTP::Tiny->new->get($url);
		if ($response->{success}) { 
			open (OUT, ">$cache_location/buildDetails/$cache_filename");
			print OUT $response->{content};
		}else{
			print "Failed: atlas_build_id=$id $response->{status} $response->{reasons}\n";
		}

	}
	close OUT;
}
###################################################################
##                       Protein pages
####################################################################
sub cache_getProtein{
  my $atlas_build_id = $OPTIONS{atlas_build_id} || '';
	my $protein_list_file =  $OPTIONS{prot_list} || '';
	if ($protein_list_file eq '' || $atlas_build_id eq ''){
		 die $USAGE;
	}
	if (! -e $protein_list_file){
		die "$protein_list_file not found\n";
	}

	my $query_url = "$BASE_URL/cgi/PeptideAtlas/GetProtein?apply_action=QUERY&atlas_build_id=$atlas_build_id&protein_name=";
	open (PROT, "<$protein_list_file");
	while (my $prot =<PROT>){
		chomp $prot;
		my $request_url = "$query_url".lc($prot);
    #my $url_mdsum = md5_hex( $request_url );
    my $cache_filename = lc($request_url);
    $cache_filename =~ s/.*\?//;
    my $url = "$request_url\&caching=1";
		print "$url\n";
		my $response = HTTP::Tiny->new->get("$url");
 		if ($response->{success}) {
			open (OUT, ">$cache_location/GetProtein/$cache_filename");
			print OUT $response->{content};
		}else{
			print "Failed: $response->{status} $response->{reasons}\n";
		}

	}
}


