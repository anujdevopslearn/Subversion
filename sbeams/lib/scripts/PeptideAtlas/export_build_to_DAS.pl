#!/usr/local/bin/perl -w

###############################################################################
# Program     : export_build_to_DAS.pl.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: load_atlas_build.pl 3719 2005-07-22 03:36:26Z nking $
#
# Description : This script exports an existing PeptideAtlas build to DAS
#
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $ATLAS_BUILD_ID 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $TESTVARS $CHECKTABLES
            );


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


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --testonly             If set, rows in the database are not changed or added
  --list                 If set, list the available builds and exit
  --atlas_build_name     Name of the atlas build to export
  --das_tag      organism and specificity of the build
  --add
  --delete

 e.g.: $PROG_NAME --list
       $PROG_NAME --atlas_build_name \'Human_P0.9_Ens26_NCBI35\'
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "list","atlas_build_name:s","add", "delete", "das_tag:s"
    )) {

    die "\n$USAGE";

}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;

my $DASTAG = $OPTIONS{'das_tag'};
$DASTAG =~ s/\s+/\_/g;

if ($DEBUG) {
    print "Options settings:\n";
    print "  VERBOSE = $VERBOSE\n";
    print "  QUIET = $QUIET\n";

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

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless (
    $current_username = $sbeams->Authenticate(
      work_group=>'PeptideAtlas_admin')
  );

  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  my %args = @_;

  ##### PROCESS COMMAND LINE OPTIONS AND RESTRICTIONS #####

  #### Set the command-line options
  my $atlas_build_name = $OPTIONS{"atlas_build_name"};


  #### If there are any unresolved parameters, exit
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }


  #### If a listing was desired, do that and exist
  if ($OPTIONS{"list"}) {
    listBuilds();
    exit;
  }


  #### Verify that atlas_build_name was supplied
  unless ($atlas_build_name) {
    print "\nERROR: You must specify an --atlas_build_name\n\n";
    die "\n$USAGE";
  }


  #### Get the atlas_build_id for the name
  my $atlas_build_id = getAtlasBuildID(
    atlas_build_name => $atlas_build_name,
  );
  unless ($atlas_build_id) {
    die("ERROR: Unable to find the atlas_build_id for atlas_build_name ".
	"$atlas_build_name.  Use --list to see a listing");
  }


  #### Export the Build to DAS
  exportBuildToDAS(
    atlas_build_id => $atlas_build_id,
  );


##### Export the build to Proserver, set the ini config file
####  Restart it to server the new build

  updateProserver(atlas_build_name => $atlas_build_name,
		  atlas_build_id   => $atlas_build_id); 

} # end handleRequest



###############################################################################
# listBuilds -- List all PeptideAtlas builds
###############################################################################
sub listBuilds {
  my $SUB = 'listBuilds';
  my %args = @_;

  my $sql = qq~
    SELECT atlas_build_id,atlas_build_name
      FROM $TBAT_ATLAS_BUILD
     WHERE record_status != 'D'
     ORDER BY atlas_build_name
      ~;
  my $dbh = connectToDASDB();
  my @atlas_builds = $sbeams->selectSeveralColumns($sql) or
    die("ERROR[$SUB]: There appear to be no atlas builds in your database");

  foreach my $atlas_build (@atlas_builds) {
    printf("%5d %s\n",$atlas_build->[0],$atlas_build->[1]);
  }

} # end listBuilds



###############################################################################
# getAtlasBuildID -- Return an atlas_build_id
###############################################################################
sub getAtlasBuildID {
  my $SUB = 'getAtlasBuildID';
  my %args = @_;

  print "INFO[$SUB] Getting atlas_build_id..." if ($VERBOSE);

  my $atlas_build_name = $args{atlas_build_name} or
    die("ERROR[$SUB]: parameter atlas_build_name not provided");

  my $sql = qq~
    SELECT atlas_build_id,atlas_build_name
      FROM $TBAT_ATLAS_BUILD
     WHERE record_status != 'D'
           AND atlas_build_name = '$atlas_build_name'
     ORDER BY atlas_build_name
  ~;

  my ($atlas_build_id) = $sbeams->selectOneColumn($sql);

  print "$atlas_build_id\n" if ($VERBOSE);
  return $atlas_build_id;

} # end getAtlasBuildID



###############################################################################
# exportBuildToDAS -- Export the build to DAS
###############################################################################
sub exportBuildToDAS {
  my $SUB = 'exportBuildToDAS';
  my %args = @_;

  print "INFO[$SUB] Exporting to DAS tables...\n" if ($VERBOSE);

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  my $atlas_build_tag = getAtlasBuildTag(
    atlas_build_id => $atlas_build_id,
  ) or die("ERROR[$SUB]: Unable to get atlas_build_tag");


  #### Create or clear the DAS table for this dataset
  clearDASTable(
    atlas_build_id => $atlas_build_id,
  );

  if($OPTIONS{'add'}){
		 #### Get array ref of all peptide and their mappings
		 my $peptide_mappings = getAllPeptideMappings(
			atlas_build_id => $atlas_build_id,
		  );


		  #### connect to database
		  my $dbh = connectToDASDB() or die("ERROR[$SUB]: Cannot connect to database");


		  #### Loop over all peptide_mappings, extracting them
		  my $rowctr = 0;
		  foreach my $peptide_mapping (@{$peptide_mappings}) {
			my ($peptide_accession,$peptide_sequence,$chromosome,
			$start_in_chromosome,$end_in_chromosome,$strand,
			$best_probability,$n_genome_locations) = @{$peptide_mapping};

			printf("%s %4d %10d %10d %1d %.3f %s\n",
				$peptide_accession,$chromosome,
			$start_in_chromosome,$end_in_chromosome,$strand,
			$best_probability,$peptide_sequence) if ($VERBOSE);

			#### Tranlate strand from -/+ to 0/1
			if($strand){
			  if ($strand eq '-') {
				$strand = 0;
			  } else {
				$strand = 1;
			  }
			}

			#### Make a call based on n_genome_locations
			my $peptide_degen_class;
			if ($n_genome_locations == 1) {
			  $peptide_degen_class = 'Uniquely mapped peptide';
			} else {
			  $peptide_degen_class = 'Multiply mapped peptide';
			}


			#### Skip peptides with no mapping
			next unless ($chromosome && $start_in_chromosome &&
				 $end_in_chromosome && $strand gt '');

			#### Insert the record into the DAS Table
			my $sql = qq~
			  INSERT INTO $atlas_build_tag
				(contig_id,start,end,strand,id,score,gff_feature,gff_source,name)
				VALUES
				('$chromosome',$start_in_chromosome,$end_in_chromosome,$strand,
				 '$peptide_accession',$best_probability,'peptide','$peptide_degen_class',
				 '$peptide_sequence')
			~;

			my $sth = $dbh->prepare ($sql)
			  or die("ERROR[$SUB]: Cannot prepare query $DBI::err ($DBI::errstr)");
			$sth->execute()
			  or die("ERROR[$SUB]: Cannot execute query\n$sql\n".
				 "$DBI::err ($DBI::errstr)");
			$sth->finish()
			  or die("ERROR[$SUB]: Cannot finish query $DBI::err ($DBI::errstr)");

			$rowctr++;

			#last if ($peptide_accession gt 'PAp00000099');

		  }

		  print "INFO[$SUB]: $rowctr rows inserted into DAS table $atlas_build_tag\n";

		  $dbh->disconnect()
			or die("ERROR[$SUB]: Cannot disconnect from database ".
			   "$DBI::err ($DBI::errstr)");

    }		 


} # end exportBuildToDAS



###############################################################################
# clearDASTable -- Export the build to DAS
###############################################################################
sub clearDASTable {
  my $SUB = 'clearDASTable';
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  my $atlas_build_tag = getAtlasBuildTag(
    atlas_build_id => $atlas_build_id,
  ) or die("ERROR[$SUB]: Unable to get atlas_build_tag");


  #### connect to database
  my $dbh = connectToDASDB()
    or die("ERROR[$SUB]: Cannot connect to database");


  #### DROP the table if it exists
  print "INFO[$SUB] Dropping DAS table...\n" if ($VERBOSE);
  my $sql = "DROP TABLE IF EXISTS $atlas_build_tag";
  print "[SQL]: ",$sql,"\n" if ($VERBOSE);
  my $sth = $dbh->prepare ($sql)
    or die("ERROR[$SUB]: Cannot prepare query $DBI::err ($DBI::errstr)");
  $sth->execute()
    or die("ERROR[$SUB]: Cannot execute query\n$sql\n".
	   "$DBI::err ($DBI::errstr)");
  $sth->finish()
    or die("ERROR[$SUB]: Cannot finish query $DBI::err ($DBI::errstr)");
 
  if($OPTIONS{'add'}){

		#### CREATE the table
		print "INFO[$SUB] Creating DAS table...\n" if ($VERBOSE);
		my $sql = qq~
		  CREATE TABLE $atlas_build_tag (
						  contig_id    varchar(40) NOT NULL default '',
						  start        int(10) NOT NULL default '0',
						  end          int(10) NOT NULL default '0',
						  strand       int(2) NOT NULL default '0',
						  id           varchar(40) NOT NULL default '',
						  score        double(16,4) NOT NULL default '0.0000',
						  gff_feature  varchar(40) default NULL,
						  gff_source   varchar(40) default NULL,
						  name         varchar(40) default NULL,
						  hstart       int(11) NOT NULL default '0',
						  hend         int(11) NOT NULL default '0',
						  hid          varchar(40) NOT NULL default'',
						  evalue       varchar(40) default NULL,
						  perc_id      int(10) default NULL, 
						  phase        int(11) NOT NULL default '0',
						  end_phase    int(11) NOT NULL default '0',

						  KEY id_contig(contig_id),
						  KEY id_pos(id,start,end)
						  )
						  ~;

		print "[SQL]: ",$sql,"\n" if ($VERBOSE);
		my $sth = $dbh->prepare ($sql)
		  or die("ERROR[$SUB]: Cannot prepare query $DBI::err ($DBI::errstr)");
		$sth->execute()
		  or die("ERROR[$SUB]: Cannot execute query\n$sql\n".
						  "$DBI::err ($DBI::errstr)");
		$sth->finish()
		  or die("ERROR[$SUB]: Cannot finish query $DBI::err ($DBI::errstr)");

		$dbh->disconnect()
		  or die("ERROR[$SUB]: Cannot disconnect from database ".
						  "$DBI::err ($DBI::errstr)");
  }
} # end clearDASTable



###############################################################################
# connectToDASDB -- Connect to the DAS Database
###############################################################################
sub connectToDASDB {
  my $SUB = 'connectToDASDB';
  my %args = @_;


  #### Get the DAS Database connection paramters
  my %connection_params = getDASDBConnParams();
  my $dsn = $connection_params{dsn};
  my $username = $connection_params{username};
  my $password = $connection_params{password};
  my %attr = (               # error-handling attributes
    PrintError => 0,
    RaiseError => 0
  );

  print " DSN \t $dsn \n";
  print" username: \t $username \n";
  print " $password \t $password \n";
  #### connect to database
  print "INFO[$SUB] Connecting to DAS Database...\n" if ($VERBOSE);
  my $dbh = DBI->connect ($dsn, $username, $password, \%attr )
    or die("ERROR[$SUB]: Cannot connect to database");

  return $dbh;

} # end connectToDASDB



###############################################################################
# getDASDBConnParams -- Get the DAS Database connection parameters
###############################################################################
sub getDASDBConnParams {
  my $SUB = 'getDASDBConnParams';
  my %args = @_;


  my $servername = $CONFIG_SETTING{PeptideAtlas_DAS_SERVERNAME}
    or die("ERROR[$SUB]: CONFIG_SETTING{PeptideAtlas_DAS_SERVERNAME} not set ".
	   "in your SBEAMS.conf file");

  my $databasename = $CONFIG_SETTING{PeptideAtlas_DAS_DATABASENAME}
    or die("ERROR[$SUB]: CONFIG_SETTING{PeptideAtlas_DAS_DATABASENAME} not set ".
	   "in your SBEAMS.conf file");

  my $username = $CONFIG_SETTING{PeptideAtlas_DAS_USERNAME}
    or die("ERROR[$SUB]: CONFIG_SETTING{PeptideAtlas_DAS_USERNAME} not set ".
	   "in your SBEAMS.conf file");

  my $password = $CONFIG_SETTING{PeptideAtlas_DAS_PASSWORD}
    or die("ERROR[$SUB]: CONFIG_SETTING{PeptideAtlas_DAS_PASSWORD} not set ".
	   "in your SBEAMS.conf file");

  my $DASURL = $CONFIG_SETTING{PeptideAtlas_DAS_URL}
    or die("ERROR[$SUB]: CONFIG_SETTING{PeptideAtlas_DAS_URL} not set ".
	   "in your SBEAMS.conf file");


  #### Define the DAS Database connection paramters
  my %connection_params = (
    servername => $servername,
    databasename => $databasename,
    username => $username,
    password => $password,
    dsn => "DBI:mysql:$databasename:$servername",
    DASURL => $DASURL,
  );

  return %connection_params;

} # end getDASDBConnParams



###############################################################################
# getAtlasBuildTag -- Return an atlas_build_tag
# At present, this is still a hack of the data_path
###############################################################################
sub getAtlasBuildTag {
  my $SUB = 'getAtlasBuildTag';
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  print "INFO[$SUB] Getting atlas_build_tag... " if ($VERBOSE);

  #### Get the data_path for this atlas_build_id
  my $sql = qq~
    SELECT data_path
      FROM $TBAT_ATLAS_BUILD
     WHERE record_status != 'D'
           AND atlas_build_id = '$atlas_build_id'
  ~;
  my @rows = $sbeams->selectOneColumn($sql);


  #### Make sure we got the right number of rows
  unless (@rows) {
    die("ERROR[$SUB]: No rows returned from $sql");
  }

  if (scalar(@rows) > 1) {
    die("ERROR[$SUB]: Too many rows returned from $sql");
  }

  my $data_path = $rows[0];

  #### Parse out the directory name up to the first /
  unless ($data_path =~ m|^(.+)/|) {
    die("ERROR:[$SUB]: unable to parse $data_path");
  }
  my $atlas_build_tag = $1;

  #### Strip of periods
  $atlas_build_tag =~ s|\.||g;

  #### remove dashes
  $atlas_build_tag =~ s/\-/\_/g;

  print "$atlas_build_tag\n" if ($VERBOSE);
  return $atlas_build_tag;

} # end getAtlasBuildTag


###############################################################################
# getAllPeptideMappings -- Get all of the peptide mappings for this build
###############################################################################
sub getAllPeptideMappings {
  my $SUB = 'getAllPeptideMappings';
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  print "INFO[$SUB] Getting all peptide mappings...\n" if ($VERBOSE);


  #### SQL to get all the peptide mappings
  my $sql = qq~
     SELECT DISTINCT P.peptide_accession,P.peptide_sequence,PM.chromosome,
            PM.start_in_chromosome,PM.end_in_chromosome,PM.strand,
            PI.best_probability,PI.n_genome_locations
       FROM $TBAT_PEPTIDE_INSTANCE PI
      INNER JOIN $TBAT_PEPTIDE P
            ON ( PI.peptide_id = P.peptide_id )
      INNER JOIN $TBAT_ATLAS_BUILD AB
            ON ( PI.atlas_build_id = AB.atlas_build_id )
       LEFT JOIN $TBAT_PEPTIDE_MAPPING PM
            ON ( PI.peptide_instance_id = PM.peptide_instance_id )
      WHERE 1 = 1
        AND PI.atlas_build_id = '$atlas_build_id'
      ORDER BY P.peptide_accession,PM.chromosome,PM.start_in_chromosome
  ~;

# print "\n$sql\n" if ($VERBOSE);
#       AND PI.n_genome_locations > 0

  my @peptide_mappings = $sbeams->selectSeveralColumns($sql);

  return \@peptide_mappings;

} # end getAllPeptideMappings



################################################################################
###### updateProserver --- Stop the server, update the ini file and restart it
################################################################################


sub updateProserver {

    my $SUB = 'updateProserver';
    my %args = @_;
    
    my $PROSERVER_DIREC   = '/net/dblocal/www/html/devAP/DAS/Bio-Das-ProServer';
    my $PERL_EXEC         =  '/net/dblocal/www/html/devAP/local_perl/bin/perl';
    my $INI_FILE          = 'peptideatlas.ini';


    my %connection_params = getDASDBConnParams();
    my $servername = $connection_params{servername};
    my $databasename = $connection_params{databasename};
    my $username = $connection_params{username};
    my $password = $connection_params{password};

    
    my $atlas_build_name = $args{atlas_build_name} or
	die {"ERROR[$SUB] : parameter atlas_build_name not provided"};
    
    my $nospace_atlas_build_name = $atlas_build_name;
        $nospace_atlas_build_name =~ s/\s/_/g;
  
    my $atlas_build_id = $args{atlas_build_id} or
	die {"ERROR[$SUB] : parameter atlas_build_id not provided"};

    my $atlas_build_tag = getAtlasBuildTag(
    atlas_build_id => $atlas_build_id,) or die("ERROR[$SUB]: Unable to get atlas_build_tag");

    print "INFO[$SUB] : Updating the Proserver \n\n ";

    if ( -e "$PROSERVER_DIREC/eg/proserver.mimas.systemsbiology.net.pid") {
	
	print "INFO[$SUB] : Stopping the Proserver \n ";
	system("kill -TERM `cat $PROSERVER_DIREC/eg/proserver.mimas.systemsbiology.net.pid`");
       
    }

    else { print "INFO[$SUB] : No instance of Proserver seems to be running ! Will start a fresh one";}
    
   ### Editing the peptideatlas.ini file 
   
    if ( -e "$PROSERVER_DIREC/eg/$INI_FILE") {

       ### making a copy of the ini file in case it corrupted
	   system("cp -p $PROSERVER_DIREC/eg/$INI_FILE  $PROSERVER_DIREC/eg/$INI_FILE.bak");
	   if( $OPTIONS{'delete'}){
         open (FILE , "<$PROSERVER_DIREC/eg/$INI_FILE");
         open (INI, ">$PROSERVER_DIREC/eg/tmp.ini");

         my $st =0;
         foreach (<FILE>){
           if( $_ !~ /PeptideAtlasdb\_$DASTAG\]/ && ! $st){
             print INI "$_";
           }
           else {
             $st=1;
           }
           if($st && /atlas_build_id/){
             $st=0;
           }
         }
         close(FILE);
         close (INI);
         system("mv $PROSERVER_DIREC/eg/tmp.ini  $PROSERVER_DIREC/eg/$INI_FILE");
       }
       elsif($OPTIONS{'add'}){
	     open (FILE , ">>$PROSERVER_DIREC/eg/$INI_FILE");
		 print (FILE "\n");
		 print (FILE "[PeptideAtlasdb_$DASTAG]\n");
		 print (FILE "state       = on\n");
		 print (FILE "adaptor     = PeptideAtlasdb\n");
		 print (FILE "description = Peptides from the PeptideAtlas build $atlas_build_name\n");
		 print (FILE "transport   = dbi\n");
		 print (FILE "dbhost      = $servername\n");
		 print (FILE "dbname      = $databasename\n");
		 print (FILE "dbuser      = $username\n");
		 print (FILE "dbpass      = $password\n");
		 print (FILE "dbtable     = $atlas_build_tag\n");
		 print (FILE "atlas_build_id = $atlas_build_id\n");


		 close(FILE);
      }
    	print " INFO[$SUB]: INI file updated \n";
    
        print " INFO[$SUB]: Restarting the Proserver \n";
    }


        
     ##  Restarting the Proserver with the updated INI file

   system("$PERL_EXEC $PROSERVER_DIREC/eg/proserver -c $PROSERVER_DIREC/eg/$INI_FILE");
 
   print "\n\n INFO[$SUB]: Proserver successfully started\n\n";
   

	       
 }  ###### END udpateProserver

###############################################################################
# getAllPeptideMappings -- Get all of the peptide mappings for this build
###############################################################################
sub updateDazzleConfigFile {
  my $SUB = 'updateDazzleConfigFile';
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} or
    die("ERROR[$SUB]: parameter atlas_build_id not provided");

  my $atlas_build_tag = getAtlasBuildTag(
    atlas_build_id => $atlas_build_id,
  ) or die("ERROR[$SUB]: Unable to get atlas_build_tag");

  print "INFO[$SUB] Updating Dazzle config file...\n" if ($VERBOSE);

  my %connection_params = getDASDBConnParams();
  my $servername = $connection_params{servername};
  my $databasename = $connection_params{databasename};
  my $username = $connection_params{username};
  my $password = $connection_params{password};
  my $DASURL = $connection_params{DASURL};

  my $linkout_URL = "https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide?_tab=4&atlas_build_id=$atlas_build_id&searchWithinThis=Peptide+Name&searchForThis=####&action=QUERY";
  $linkout_URL =~ s/\&/&amp;/g;

  print qq~
#### DD OR UPDATE THE FOLLOWING SECTION IN dazzlecfg.xml AND RESTART TOMCAT ####
  <!-- BEGIN #### MySQL DAS Connection for PeptideAtlas -->
  <resource id="PeptideAtlasDASConn" jclass="org.ensembl.das.DatabaseHolder">
    <string name="dbURL" value="jdbc:mysql://$servername/$databasename" />
    <string name="dbUser" value="$username" />
    <string name="dbPass" value="$password" />
  </resource>
  <!-- END #### MySQL DAS Connection for PeptideAtlas -->

  <!-- BEGIN #### Datasource definition for PeptideAtlas Build $atlas_build_tag -->
  <datasource id="$atlas_build_tag" jclass="org.ensembl.das.GenericSeqFeatureSource">
    <string name="name" value="PeptideAtlas build $atlas_build_tag" />
    <string name="description" value="Peptides from the PeptideAtlas build $atlas_build_tag" />
    <string name="version" value="1" />
    <string name="mapMaster" value="http://das.ensembl.org/das/ensembl_Homo_sapiens_core_39_36a" />
    <string name="dbHolder" value="PeptideAtlasDASConn" />
    <string name="tableName" value="$atlas_build_tag" />
    <map name="uriPatterns">
      <string name="this peptide in PeptideAtlas" value="$linkout_URL" />
    </map>
  </datasource>
  <!-- END #### Datasource definition for PeptideAtlas Build $atlas_build_tag -->
  ~;

  #### EDeutsch: FIXME What should the value of version be?


} # end getAllPeptideMappings



