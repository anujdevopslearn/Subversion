#!/usr/local/bin/perl

###############################################################################
# Program      : transfer_PAsample_to_PASS.pl
# Author       : Zhi Sun <zsun@systemsbiology.org>
# $Id: 
# 
# Description  :
# transfer High value MS2 dataset to PASS
###############################################################################

###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use File::Find;
use Cwd 'abs_path';
use Net::FTP;
$|++;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Authenticator;
use SBEAMS::Connection::Tables;
use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;

use vars qw ($PROG_NAME $USAGE %OPTIONS $VERBOSE $QUIET
             $DEBUG $TESTONLY);

$sbeams = new SBEAMS::Connection;

###############################################################################
# Set program name and usage banner for command line use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

  --fname
  --lname                 
  --project_id 
 
 e.g.:  $PROG_NAME --verbose 3 --debug 1 
 ./transfer_PAsample_to_PASS.pl --fname Tamar --lname Geiger --project_id 1120 --test 1 --debug 1 --verbose 1
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "fname:s", "lname:s", "project_id:s",
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
    print "  DEBUG = $DEBUG\n";
    print "  TESTONLY = $TESTONLY\n";
}

my $fname = $OPTIONS{"fname"};
my $lname = $OPTIONS{"lname"};
my $project_id = $OPTIONS{"project_id"};

if (! $fname && ! $lname && ! $project_id) {
  print "$USAGE\nMust specify either --fname, --lname, and --project_id\n";
  exit();
}

my $sql = qq~
    SELECT  S.SUBMITTER_ID 
    FROM $TBAT_PASS_SUBMITTER S
    WHERE S.FIRSTNAME=\'$fname\' AND S.LASTNAME= \'$lname\'
~;

my @submitter_ids = $sbeams->selectOneColumn($sql);
my ($submitter_id,$email, $password);
if ( @submitter_ids >1 ){
  die "more than one submitter_id found in $TBAT_PASS_SUBMITTER\n";
}elsif(@submitter_ids == 1){
  ## primary contact has a PASS account already, submit dataset use this account
  $submitter_id = $submitter_ids[0]; 
}else{
  ## primary contact doesnot have a PASS account already,
  ## creat an account for he/she, and submit dataset use this account
  ($submitter_id, $email, $password) = create_account('fname' => $fname, 'lname' => $lname);
}

my ($datasetIdentifier,$success) = addDataset ('submitter_id' => $submitter_id, 'parameters' => \%OPTIONS); 

#my ($datasetIdentifier,$datasetPassword, $password,$email )=qw(PASS00084 SL2975ye QJ7855eu geiger@biochem.mpg.de); 
#my $success = 1;

my $str = '';
if($password ne ''){ ## we generate the account
  $str = qq~
	We have created an account for you:
	Username: $email
	Password: $password
  ~;
}
my $emai_content = qq~
	Dear $fname $lname,

	Thank you for sending your raw data to PeptideAtlas. We appreciate your willingness to make your data
	broadly available. Since your submission to Tranche appears to be incomplete and we have received
	further interest in your dataset, we are depositing your complete dataset to the PeptideAtlas
	Submission System on your behalf. No action is required on your part. If you receive future emails
	about problems acquiring the dataset from Tranche, you may direct those interested parties to the
	PeptideAtlas PASS URL below.

	$str	 

	You can accession dataset from here: 
	http://www.peptideatlas.org/PASS/$datasetIdentifier
~;

#print "$emai_content\n";

if ($success and ! $TESTONLY){
  my (@toRecipients,@ccRecipients,@bccRecipients);
  @toRecipients = (
    "$fname $lname","$email",
  );
  @ccRecipients = (
    'Zhi Sun', 'zhi.sun@systemsbiology.org',
    'Terry Farrah','terry.farrah@systemsbiology.org',
    'Eric Deutsch','eric.deutsch@systemsbiology.org',
  );
  @bccRecipients = ();

  SBEAMS::Connection::Utilities::sendEmail(
    toRecipients=>\@toRecipients,
    ccRecipients=>\@ccRecipients,
    bccRecipients=>\@bccRecipients,
   subject=>"PeptideAtlas dataset submission $datasetIdentifier",
   message=>"$emai_content",);
}

exit;
#######################################################################
# addDataset
#######################################################################
sub addDataset{
  my %args = @_;
  my $SUB_NAME = 'generatePassword';
  my $submitter_id = $args{submitter_id};
  my $parameters = $args{parameters};
  my $project_id = $parameters->{project_id} || die "need to pass project_id\n";
  my $fname = $parameters->{fname};
  my $lname = $parameters->{lname};

  my $sql = qq~
  SELECT DISTINCT S.SAMPLE_ACCESSION,
           P.project_tag,
           E.EXPERIMENT_PATH,
           ASB.SEARCH_BATCH_SUBDIR,
           P.NAME,
           O.ORGANISM_NAME,
           I.INSTRUMENT_NAME,
           PUB.AUTHOR_LIST,
           PUB.JOURNAL_NAME,
           PUB.TITLE,
           PUB.PUBMED_ID
    FROM $TB_PROJECT P 
    RIGHT JOIN $TBPR_PROTEOMICS_EXPERIMENT E ON (P.PROJECT_ID = E.PROJECT_ID)
    LEFT JOIN $TBPR_SEARCH_BATCH SB ON ( E.EXPERIMENT_ID = SB.EXPERIMENT_ID)
    LEFT JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON ( SB.SEARCH_BATCH_ID = ASB.PROTEOMICS_SEARCH_BATCH_ID ) 
    LEFT JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON (ASB.SAMPLE_ID = ABSB.SAMPLE_ID)
    LEFT JOIN $TBAT_SAMPLE S ON (ABSB.SAMPLE_ID = S.SAMPLE_ID)
    LEFT JOIN $TBAT_PUBLICATION PUB ON (PUB.PUBLICATION_ID = S.SAMPLE_PUBLICATION_IDS)
    LEFT JOIN $TBPR_INSTRUMENT I ON (E.INSTRUMENT_ID = I.INSTRUMENT_ID)
    LEFT JOIN $TB_ORGANISM O ON (O.ORGANISM_ID = E.ORGANISM_ID)
    WHERE P.project_id = $project_id
  ~;

  my @rows = $sbeams -> selectSeveralColumns ($sql);
  my $PK;
  my $passdir = "/regis/passdata/test/"; 
  my $datasetIdentifiers = ();
  my %datadirs = ();
  my %description = ();

  foreach my $row (@rows){
    
    my ($sample_accession,
        $exp_tag,
        $exp_path,
        $subdir,
        $exp_title,
        $organism,
        $instrument,
        $author, 
        $journal,
        $journal_title,
        $pubmed_id)= @$row;
    next if ($sample_accession !~ /PAe/);
    my $publication;
    if($pubmed_id){
      $publication = "PubmedID: $pubmed_id";
    }elsif($journal_title){
      $publication ="$author, $journal_title, submitted\n";
    }else{
      $publication = "unpublished";
    }
    print "$exp_path/$subdir\n";
    $datadirs{$sample_accession} = "$exp_path/$subdir";
    $description{datasetTag}{$exp_tag} = 1;
    $description{datasetTitle}{$exp_title} = 1;
    $description{publication}{$publication} = 1;
    $description{instrument}{$instrument} = 1;
    $description{species}{$organism} = 1;
  }    

	my %rowdata = (
		submitter_id => $submitter_id, 
		datasetIdentifier => "tmp_XXXXX",
		datasetType => 'MSMS',
		datasetPassword => '',
		datasetTag => join(",", keys %{$description{datasetTag}}),
		datasetTitle => join(",", keys %{$description{datasetTitle}}),
		publicReleaseDate => 'CURRENT_TIMESTAMP',
		finalizedDate => 'NULL',
	);
	$PK = $sbeams->updateOrInsertRow(
				 insert => 1,
				 table_name => $TBAT_PASS_DATASET,
				 rowdata_ref => \%rowdata,
				 PK => 'dataset_id',
				 return_PK => 1,
				 add_audit_parameters => 0,
				 testonly => $TESTONLY,
				 verbose => $VERBOSE,
				);

    if (! $PK || $PK < 0) {
      die "failed to insert\n";;
    }


	#my $datasetIdentifier = "PASS".substr('000000',0,5-length($PK)).$PK;
  my $datasetIdentifier = 'PASS00084';
	%rowdata = ( datasetIdentifier => $datasetIdentifier );
	my $result = $sbeams->updateOrInsertRow(
						update => 1,
						table_name => $TBAT_PASS_DATASET,
						rowdata_ref => \%rowdata,
						PK => 'dataset_id',
						PK_value => $PK,
						testonly => $TESTONLY,
						verbose => $VERBOSE,
				 );
 
  my $PASS_FTP_AGENT_BASE = '/prometheus/u1/home/PASSftpAgent';

	#mkdir "$passdir/$datasetIdentifier";
	my $outfile = "$PASS_FTP_AGENT_BASE/Incoming/${datasetIdentifier}_DESCRIPTION.txt";
	open(OUTFILE,">$outfile") || die("ERROR: Unable to write to '$outfile'");
	my $metadata .= "identifier:\t$datasetIdentifier\n";
	$metadata .= "type:\tMSMS\n";
	$metadata .= "tag:\t".  join(",", keys %{$description{datasetTag}}) ."\n";
	$metadata .= "title:\t".  join(",", keys %{$description{datasetTitle}}) ."\n";
	$metadata .= "summary:\n";
	$metadata .= "contributors:\t$fname $lname\n";
	$metadata .= "publication:\t". join(";", keys %{$description{publication}}) ."\n";
	foreach my $tag ( 'growth','treatment','extraction','separation','digestion','acquisition','informatics' ) {
		$metadata .= "$tag:\t\n";
	}
	$metadata .= "instrument:\t". join(",", keys %{$description{instrument}}) ."\n";
	$metadata .= "species:\t". join(",", keys %{$description{species}}) ."\n";

    ## get modification
  my %stat_mod=();
  my %var_mod = ();
  foreach my $sample_accession (keys %datadirs){
    my $dir = $datadirs{$sample_accession};
    my $search_result_file = `ls /regis/sbeams/archive/$dir/*.xml |grep -v inter | tail -1`;
    if ($search_result_file){
      my $mass = 0;
      my $aa='';
      open (IN, "<$search_result_file") or die "cannot open $search_result_file\n";
      while (my $line = <IN>){
         next if ($line !~ /<aminoacid_modification/);
         if($line =~ /aminoacid="(\w)" massdiff="([\d\.\+\-]+)" mass="([\d\.\+\-]+)"\s+variable="N"/){
           $mass = sprintf ("%.2f" , $2);
           $aa = $1;
           if ( $mass !~ /[\+\-]/ ){ 
             $stat_mod{"$aa+$mass"} = 1;
           }else{
             $stat_mod{"$aa$mass"} = 1;
           }
         }elsif($line =~ /aminoacid="(\w)" massdiff="([\d\.\+\-]+)" mass="([\d\.\+\-]+)"\s+variable="Y"/){
           $mass = sprintf ("%.2f" , $2);
           $aa = $1;
           if ( $mass !~ /[\+\-]/ ){
             $var_mod{"$aa+$mass"} = 1;
           }else{
             $var_mod{"$aa$mass"} = 1;
           }
         }
       }
       close IN;
    }
  }
  $metadata .= "massModifications:\tstatic: ". join(",", keys %stat_mod) ."; variable: ". join(",", keys %var_mod) ."\n";
  print OUTFILE $metadata;
  close(OUTFILE);

  #### Tell the FTP agent to create the account
  #my $datasetPassword = generatePassword();
  my $datasetPassword = 'SL2975ye';
  my $cmdfile = "$PASS_FTP_AGENT_BASE/commands.queue";
  open(CMDFILE,">>$cmdfile") || die("ERROR: Unable to append to '$cmdfile'");
  print CMDFILE "CreateUser $datasetIdentifier with password $datasetPassword \n";
  close(CMDFILE);

  for my $i (1..3){
    if ( ! -d "/regis/passdata/home/$datasetIdentifier" ){
      sleep 10;
    }
  }
  if (! -d "/regis/passdata/home/$datasetIdentifier" ){
    die "cannot create /regis/passdata/home/$datasetIdentifier\n";
  } 

  ### transfer files
	my $ftp = Net::FTP->new("ftp.peptideatlas.org", Debug => 0) or die "Cannot connect to ftp.peptideatlas.org: $@";
	$ftp->login("$datasetIdentifier","$datasetPassword")	or die "Cannot login ", $ftp->message;
  my $success = 1;
  foreach my $sample_accession (keys %datadirs){
    my $dir = $datadirs{$sample_accession};
		my %filelist = ();
		find(sub{$filelist{abs_path($_)} = 1 if (-f and /(RAW|mzML|mzXML|raw)/) }, "/regis/sbeams/archive/$dir/../");
		my $cnt = 0;
		#mkdir "$passdir/$datasetIdentifier/$sample_accession";
    my $cnt_file_to_copy = scalar keys %filelist;
    $ftp->cwd("$sample_accession") or die "Cannot change working directory ", $ftp->message;
		foreach my $abs_path_file (keys %filelist){
      my $file = $abs_path_file;
      $file =~ s/.*\///;
			if ($TESTONLY){
				print "copy $abs_path_file to /regis/passdata/home/$datasetIdentifier/$sample_accession/ \n";
			}else{
        if ( ! -e "/regis/passdata/home/$datasetIdentifier/$sample_accession/$file"){
					my $msg = $ftp->put("$abs_path_file");
          $cnt++;
					if($file !~ /$msg/) {## file transfer failure
						print  "cannot put file $file, ";
						$success=0;
						## delete file 
						$ftp->delete ($file);
					}
        }
        print sprintf ("%.2f%", $cnt/$cnt_file_to_copy);
        print "\tfinished\n"; 
			}
    }
    $ftp->cwd("../") or die "Cannot change working directory ", $ftp->message;
	}
	$ftp->quit;
  if ( $success and ! $TESTONLY){
    ## finalized
    my %rowdata = ( finalizedDate => 'CURRENT_TIMESTAMP' );
    my $result = $sbeams->updateOrInsertRow(
            update => 1,
            table_name => $TBAT_PASS_DATASET,
            rowdata_ref => \%rowdata,
            PK => 'dataset_id',
            PK_value => $PK,
           );
    open(CMDFILE2,">>$cmdfile") || die("ERROR: Unable to append to '$cmdfile'");
    print CMDFILE2 "FinalizeDataset $datasetIdentifiers\n";
    close(CMDFILE2);
  }  
  return ($datasetIdentifiers,$success);

}


#######################################################################
# generatePassword
#######################################################################
sub generatePassword {
  my $SUB_NAME = 'generatePassword';

  my $password = '';
  $password .= pack("c",int(rand(26))+65);
  $password .= pack("c",int(rand(26))+65);

  $password .= int(rand(9900))+100;

  for (my $i=0; $i<int(rand(3))+1; $i++) {
    $password .= pack("c",int(rand(26))+97);
  }

  #### Replace troublesome letters and numbers with more distinguishable ones
  $password =~ s/O/P/g;
  $password =~ s/0/5/g;
  $password =~ s/1/4/g;
  $password =~ s/l/m/g;

  return($password);
}


sub create_account{
  my %args = @_;
  my $fname = $args{fname};
  my $lname = $args{lname};

  my $sql = qq~
    SELECT CONTACT_ID, EMAIL
    FROM $TB_CONTACT
    WHERE FIRST_NAME=\'$fname\' AND LAST_NAME= \'$lname\'
  ~;
  my %result  = $sbeams->selectTwoColumnHash($sql);

  my $email = '';
  if ( scalar keys %result > 1 ){
    die "more than one contact found for $fname $lname in $TB_CONTACT\n";
  }elsif(scalar keys %result == 0 ){
    print "WARNING no email address found for $fname $lname, cannot send email\n";
    
  }else{
    my @emails = values %result;
    $email = $emails[0];
  }
  my $pass = generatePassword();
  my $submitter_id =  insert_account ('fname'=>$fname,
                                      'lname'=>$lname,
                                      'email'=>$email,
                                      'pass'=> $pass);
  return ($submitter_id, $email, $pass);
}
  
sub insert_account{
  my %args = @_;
  my $fanme = $args{fname} || die "no first name is passed\n";
  my $lanme = $args{lname} || die "no last name is passed\n";
  my $email = $args{email};
  my $pass = $args{pass} || die "no password is passed\n";

  my %rowdata = (
    'firstname' => $fname,
    'lastname'  => $lname,
    'emailAddress' =>$email,
    'password' => $pass,
    'emailReminders' => 'YES',
    'emailPasswords' => 'YES',
  );

	my $submitter_id = $sbeams->updateOrInsertRow(
			insert=>1,
			table_name=> $TBAT_PASS_SUBMITTER,
			rowdata_ref=>\%rowdata,
      PK => 'submitter_id',
			return_PK => 1,
			verbose=> $VERBOSE,
			testonly=> $TESTONLY,
	);
  return $submitter_id;
 
}


