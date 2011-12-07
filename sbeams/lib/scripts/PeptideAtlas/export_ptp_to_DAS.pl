#!/usr/local/bin/perl -w

#############################################################################
# Program     : export_ptp_to_DAS.pl.pl
# Author      : Zhi Sun <zsun@systemsbiology.org>
# Description : This script exports an ptp peptides to DAS
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
  --desc                 description of the biosequence_set
  --organism             
  --input                proteotyptic peptide mapping file
  --add
  --update

 e.g.: $PROG_NAME --list
       $PROG_NAME --add --desc Hsv64.37g-IPI3.71-SPvarspl201110-cumulative_decoys \
       --organism 'Human' --input proteotypic_mapped.tsv
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "list","desc:s","add", "update","input:s","organism:s",
    )) {

    die "\n$USAGE";

}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;

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
  #exit unless (
  #  $current_username = $sbeams->Authenticate(
  #    work_group=>'go2_admin')
  #);

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
  my $desc = $OPTIONS{"desc"};
  my $input_file = $OPTIONS{"input"} || die "no input mapping file\n";
  my $org = $OPTIONS{"organism"} || die "need orgamism name\n";
  $org = lc($org);
  $org = ucfirst($org);

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

  #### Verify that desc was supplied
  unless ($desc and $org) {
    print "\nERROR: You must specify an --desc --org\n\n";
    die "\n$USAGE";
  }

  #### Export the Build to DAS
  #exportPTPToDAS(
  #  input => $input_file,
  #  desc => $desc,
  #  organism => $org
  #);


   ##### Export the build to Proserver, set the ini config file
   ####  Restart it to server the new build

  updateProserver(desc => $desc,
		              organism => $org); 

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
      ~;
  my $dbh = connectToDASDB();
  my @atlas_builds = $sbeams->selectSeveralColumns($sql) or
    die("ERROR[$SUB]: There appear to be no atlas builds in your database");

  foreach my $atlas_build (@atlas_builds) {
    printf("%5d %s\n",$atlas_build->[0],$atlas_build->[1]);
  }

} # end listBuilds

###############################################################################
# exportPTPToDAS -- Export the build to DAS
###############################################################################
sub exportPTPToDAS {
  my $SUB = 'exportPTPToDAS';
  my %args = @_;

  print "INFO[$SUB] Exporting to DAS tables...\n" if ($VERBOSE);

  my $inputfile = $args{input} or
    die("ERROR[$SUB]: parameter inputfile not provided");

  my $desc = $args{desc} or
    die("ERROR[$SUB]: parameter desc not provided");
 
  my $organism = $args{organism} or
    die("ERROR[$SUB]: parameter organism not provided");

  my $ptp_table_name = "PTPdb_$organism";
  #### Create or clear the DAS table for this dataset
  clearDASTable(
    table_name => $ptp_table_name,
  );
  if($OPTIONS{'add'}){
		 #### Get array ref of all peptide and their mappings
      open(IN, "<$inputfile") or die "cannot open $inputfile\n";
		  #### connect to database
		  my $dbh = connectToDASDB() or die("ERROR[$SUB]: Cannot connect to database");
		  #### Loop over all peptide_mappings, extracting them
		  my $rowctr = 0;
		  while (my $line = <IN>){
        next if($line =~ /^Protein/);
        my($Protein,$Pre,$Peptide,$Fol,$apex,$espp,
           $detectability_predictor,$peptide_sieve,$stepp,
           $Combined_Score,$n_prot_map,$n_exact_map,$n_gen_loc,
           $n_sp_mapping,$n_spvar_mapping,$n_spsnp_mapping,
           $n_ensp_mapping,$n_ensg_mapping,$n_ipi_mapping,
           $n_sgd_mapping,$mapping) = split("\t", $line);
       for my $score ($apex,$espp,$detectability_predictor,$peptide_sieve,$stepp,$Combined_Score) {
         $score = -1 if $score =~ /NA/i;
       }
			#### Insert the record into the DAS Table
      next if($Peptide =~ /\*/);
      $mapping =~ s/\s+//g;
      if($mapping ne ''){
        my @coords = split (",", $mapping);
        foreach my $m (@coords){
          next if($m =~ /HSCHR/);
          my ($chrom,$strand, $start,$end) = split("_:_",, $m);
     			my $sql = qq~
	    		  INSERT INTO $ptp_table_name
		    		VALUES ('$chrom',$start,$end,'$strand',
                '$Protein','$Pre','$Peptide','$Fol',
                $apex,$espp,$detectability_predictor,$peptide_sieve,$stepp,
                $Combined_Score,$n_prot_map,$n_exact_map,$n_gen_loc,
                $n_sp_mapping,$n_spvar_mapping,$n_spsnp_mapping,
                $n_ensp_mapping,$n_ensg_mapping,$n_ipi_mapping,$n_sgd_mapping
                )
		  	~;
			 my $sth = $dbh->prepare ($sql)
			    or die("ERROR[$SUB]: Cannot prepare query $DBI::err ($DBI::errstr)");
			 $sth->execute()
			    or die("ERROR[$SUB]: Cannot execute query\n$sql\n".
				 "$DBI::err ($DBI::errstr)");
			  $sth->finish()
			    or die("ERROR[$SUB]: Cannot finish query $DBI::err ($DBI::errstr)");

			  $rowctr++;
		    }
       }
      }
		  print "INFO[$SUB]: $rowctr rows inserted into DAS table $ptp_table_name\n";
		  $dbh->disconnect()
			or die("ERROR[$SUB]: Cannot disconnect from database ".
			   "$DBI::err ($DBI::errstr)");
    }		 


} # end exportPTPToDAS



###############################################################################
# clearDASTable -- Export the build to DAS
###############################################################################
sub clearDASTable {
  my $SUB = 'clearDASTable';
  my %args = @_;

  my $ptp_table_name = $args{table_name} or
    die("ERROR[$SUB]: parameter table_name not provided");

  #### connect to database
  my $dbh = connectToDASDB()
    or die("ERROR[$SUB]: Cannot connect to database");


  #### DROP the table if it exists
  print "INFO[$SUB] Dropping DAS table...\n" if ($VERBOSE);
  my $sql = "DROP TABLE IF EXISTS $ptp_table_name";
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
		  CREATE TABLE $ptp_table_name (
              chromosome    varchar(40) NOT NULL default '',
              start        int(10) NOT NULL default '0',
              end          int(10) NOT NULL default '0',
              strand       int(2) NOT NULL default '0',
              protein_name varchar(255) NOT NULL default '',
						  preceding_residue             char NOT NULL default '',
						  peptide_sequence              varchar(255) NOT NULL default '',
						  flanking_residue              char NOT NULL default '',
						  apex_score                    float NOT NULL default '0',
						  espp_score                    float NOT NULL default '0',
						  detectabilityPredictor_score  float NOT NULL default '0',
						  peptideSieve_score            float NOT NULL default '0',
						  stepp_score                    float NOT NULL default '0',
						  merged_predictor_score        float NOT NULL default '0',
              n_protein_mappings	          int	NOT NULL default '0',
              n_exact_protein_mappings	    int	NOT NULL default '0',
              n_genome_locations		        int NOT NULL default '0',	
              n_sp_mapping	                int NOT NULL default '0',
              n_spvar_mapping               int NOT NULL default '0',
              n_spsnp_mapping               int NOT NULL default '0',
              n_ensp_mapping	              int NOT NULL default '0',
              n_ensg_mapping                int NOT NULL default '0',
              n_ipi_mapping	                int NOT NULL default '0',
              n_sgd_mapping	                int NOT NULL default '0',
              PRIMARY KEY id_pos(protein_name,peptide_sequence,strand,start,end)
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


################################################################################
###### updateProserver --- Stop the server, update the ini file and restart it
################################################################################
sub updateProserver {

    my $SUB = 'updateProserver';
    my %args = @_;
    
    #my $PROSERVER_DIREC   = '/net/dblocal/www/html/devAP/DAS/Bio-Das-ProServer';
    #my $PERL_EXEC         =  '/net/dblocal/www/html/devAP/local_perl/bin/perl';
    my $PROSERVER_DIREC   = '/net/db/projects/PeptideAtlas/Das/Bio-Das-ProServer';
    my $PERL_EXEC         =  '/net/db/projects/PeptideAtlas/Das/local_perl/bin/perl';
    my $INI_FILE          = 'peptideatlas.ini';

    my %connection_params = getDASDBConnParams();
    my $servername = $connection_params{servername};
    my $databasename = $connection_params{databasename};
    my $username = $connection_params{username};
    my $password = $connection_params{password};

    
    my $desc = $args{desc} or
    	die {"ERROR[$SUB] : parameter desc not provided"};
    my $organism = $args{organism} or die {"ERROR[$SUB] : parameter organism not provided"};

    my $nospace_desc = $desc;
        $nospace_desc =~ s/\s/_/g;
    my $ptp_table_name = "PTPdb_$organism";

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
	   if( $OPTIONS{'update'}){
       open (FILE , "<$PROSERVER_DIREC/eg/$INI_FILE");
       open (INI, ">$PROSERVER_DIREC/eg/tmp.ini");

       my $st =0;
       foreach (<FILE>){
         if( $_ =~ /\[$ptp_table_name\]/i){
            $st=1;
         }
         if($st && $_ =~ /^description/i){
           print "$_ $ptp_table_name \n";
           print INI "description = Peptides from the PTP $organism Build, $desc\n";
           $st = 0;
         }else{
           print INI "$_";
         }
       }
       close(FILE);
       close (INI);
       system("mv $PROSERVER_DIREC/eg/tmp.ini  $PROSERVER_DIREC/eg/$INI_FILE");
     }elsif($OPTIONS{'add'}){
	       open (FILE , ">>$PROSERVER_DIREC/eg/$INI_FILE");
				 print (FILE "\n");
				 print (FILE "[$ptp_table_name]\n");
				 print (FILE "state       = on\n");
				 print (FILE "adaptor     = PTPdb\n");
				 print (FILE "description = Peptides from the PTP $organism, $desc\n");
				 print (FILE "transport   = dbi\n");
				 print (FILE "dbhost      = $servername\n");
				 print (FILE "dbname      = $databasename\n");
				 print (FILE "dbuser      = $username\n");
				 print (FILE "dbpass      = $password\n");
				 print (FILE "dbtable     = $ptp_table_name\n");
		     close(FILE);
      }
    	print " INFO[$SUB]: INI file updated \n";
      print " INFO[$SUB]: Restarting the Proserver \n";
    }


        
     ##  Restarting the Proserver with the updated INI file
   chdir $PROSERVER_DIREC;

   #system("$PERL_EXEC $PROSERVER_DIREC/eg/proserver -c $PROSERVER_DIREC/eg/$INI_FILE");
   system("$PERL_EXEC eg/proserver -c eg/$INI_FILE");
   print "\n\n INFO[$SUB]: Proserver successfully started\n\n";
 }  ###### END udpateProserver

__DATA__

### LAST load
./export_ptp_to_DAS.pl --update --desc Hsv64.37g-IPI3.71-SPvarspl201110-cumulative_decoys --organism 'Human' --input /regis/dbase/users/sbeams/BSS_ENSEMBL64/Human/proteotypic_mapped.tsv
/net/dblocal/www/html/devZS/sbeams/lib/scripts/PeptideAtlas/export_ptp_to_DAS.pl --update --desc Mm_v37.64-IPI3.72-SP-varspl201110-cum_decoys --organism 'Mouse' --input proteotypic_mapped.tsv
