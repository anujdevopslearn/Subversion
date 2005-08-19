#!/usr/local/bin/perl -w
#
# Usage: transfer_Ake_to_Genotyping.pl
#
# Transfers a dataset in the MySQL Ake database to the Genotyping
# database. User should provide a locus name to transfer.
#
# 204/11/15 Kerry Deutsch


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;
use Getopt::Long;

use lib qw (/net/dblocal/www/html/dev8/sbeams/lib/perl /net/dblocal/www/html/dev8/sbeams/lib/perl/SBEAMS/Genotyping);
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TESTONLY
             $current_contact_id $current_username
            );

use dbhandle;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Genotyping;
use SBEAMS::Genotyping::Settings;
use SBEAMS::Genotyping::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Genotyping;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = "transfer_Ake_to_Genotyping.pl";
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          If set, nothing is actually inserted into the database,
                      but we just go through all the motions.  Use --verbose
                      to see all the SQL statements that would occur

 e.g.:  $PROG_NAME locus_name=D5S2500

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly")) {
  print "$USAGE";
  exit;
}
$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}

###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### If there aren't any parameters, print usage
  unless ($ARGV[0]){
    print "$USAGE";
    exit;
  }

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(work_group=>'Genotyping_user'));

  #### Read in the default input parameters
  my %parameters;
  my @input_parameters = ('locus_name');
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters,columns_ref=>\@input_parameters);


  #### Set the command-line options
  $TESTONLY = $OPTIONS{'testonly'} || 0;
  $VERBOSE = $OPTIONS{"verbose"} || 0;

  #### Define standard variables
  my ($i,$element,$key,$value,$line,$result,$sql);
  my $SRCDB = "Ake.dbo.";


  #### Print out the header
  $sbeams->printUserContext(style=>'TEXT') unless ($QUIET);
  print "\n" unless ($QUIET);

  #### Open a connection to MySQL too
  my $mysqlconn = DBHANDLE->new();
  $mysqlconn->createdbh();


  my @rows;
  my %column_map;
  my %transform_map;


  ######################################################################
  #### Transfer Akedb -> microsatellite_genotype_call

  #### First get data from Ake db
  $sql = qq~
        SELECT '477',gels.name,
                L.locus,
                coalesce(concat(S.name,' ',G.ind_id,' ',G.aliquot),
                         concat(S.name,' ',G.ind_id),
                         concat(G.ind_id,' ',G.aliquot),
                         G.ind_id),
                SC.name,
                concat(G.all1,'/',G.all2)
          FROM genotypes G
     LEFT JOIN gels on (gels.gel_id = G.gel_id)
     LEFT JOIN loci L on (L.locus_id = G.locus_id)
     LEFT JOIN study S on (S.study_id = G.study_id)
     LEFT JOIN sample_codes SC on (SC.sample_code = G.sample_code)
         WHERE L.locus='$parameters{locus_name}' and G.gel_id NOT IN (
               SELECT excluded_gels.gel_id
                 FROM excluded_gels
            LEFT JOIN loci L on (L.locus_id = excluded_gels.locus_id)
                WHERE L.locus='$parameters{locus_name}' )
           AND (G.all1 <> 0 and G.all2 <> 0)
  ~;

  #### Define column map
  %column_map = (
    '0'=>'project_id',
    '1'=>'gel_name',
    '2'=>'assay_name',
    '3'=>'sample_name',
    '4'=>'sample_description',
    '5'=>'genotype_call',
  );

  %transform_map = (
  );


  $sbeams->executeSQL("BEGIN TRANSACTION");

  #### Do the transfer
  print "\nTransferring Ake -> microsatellite_genotype_call";
  $sbeams->transferTable(
    'src_conn'=>$mysqlconn,
    'sql'=>$sql,
    'src_PK_name'=>'project_id',
    'src_PK_column'=>'1',
    'dest_conn'=>$sbeams,
    'column_map_ref'=>\%column_map,
    'transform_map_ref'=>\%transform_map,
    'table_name'=>"${TBGT_MICROSATELLITE_GENOTYPE_CALL}",
    'testonly'=>$TESTONLY,
    'verbose'=>$VERBOSE,
  );

  print "\n\n";

  #### Close MySQL connection
  $mysqlconn->destroydbh();


  $sbeams->executeSQL("COMMIT TRANSACTION");


}
