#!/usr/local/bin/perl

###############################################################################
# Program     : publicDataRepository2PA
# Author      : Zhi Sun <zsun@systemsbiology.org>
# $Id: main.cgi 6972 2013-02-28
#
# Description : download datasets from proteomecentral and make a PA build 
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use Getopt::Long;
use XML::Simple;
use FindBin;
use Cwd;
use Data::Dumper;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $dbh $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_work_group_id $current_work_group_name $date
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS $TEST $VERBOSE %OPTIONS);
use DBI;
#use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
#$q = new CGI;
$sbeams = new SBEAMS::Connection;

use SBEAMS::Proteomics::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::TableInfo;
$sbeamsMOD = new SBEAMS::PeptideAtlas;

$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$current_username = $sbeams->Authenticate(
    allow_anonymous_access => 1,
);
$current_contact_id = $sbeams->getCurrent_contact_id;
$current_work_group_id = $sbeams->getCurrent_work_group_id;
my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
$year += 1900;
$mon++;
$date = "$year\-$mon\-$mday $hour:$min:$sec";

require 'ManageTable.pllib';
use Net::FTP;
our $ftp;

###############################################################################
# Global Variables
###############################################################################
$PROG_NAME = 'publicDataRepository2PA';
$USAGE = qq~ 
USAGE: $PROG_NAME [OPTIONS] source_file
Options:
	--verbose n         Set verbosity level.  default is 0
	--quiet             Set flag to print nothing at all except errors
											This masks the printing of progress information
  --debug n           Set debug level.  default is 0
  --testonly          If set, nothing is actually inserted into the database,
                      but we just go through all the motions.  Use --verbose
                      to see all the SQL statements that would occur
  --help 
  --list_instrument 
  --list_experiment_type
  --list_organism

  ## parameters for downloading dataset
  --download 
  --downloadURL
  --downloadTo       
  

  ## parameters for inserting project. If not provided, will get into interactive mode. 
  --setup_PR_Experiment    create project and experiment(s), and load experiment(s)
                           minimum option: dataset_identifier 
  --insertProject
  --project_tag 
  --dataset_identifier  such as PXD000113, PASS00224 
                        (can take more than one id separate with ',', NOTE: all data will have
                         same project id) 

  ## parameters for inserting and loading samples. 
  --insert_PR_Experiment    don't create project  
                            minimum option: --dataset_identifier
  --dataset_identifier  such as PXD000113, PASS00224
  --project_location
  --organism_id
  --pr_biosequence_set_id 
  --experiment_type_id
  --instrument_id
  --sample_description_file files containing these columns:
						experiment_name
						experiment_tag 
						experiment_description 
						experiment_path
						search_batch_subdir

   --load_PR_Experiment    don't create project
                            minimum option: --dataset_identifier 


   --create_experiment_list  minimum option: --dataset_identifier --search_batch_subdir
   --search_batch_subdir
  ## parameters for generating build script. If not provided, will get into interactive mode.
  --getBuildScript
  --organism_id
  --pr_biosequence_set_id
  --biosequence_set_id
  --fdr_threshold
  --prob_threshold
  --experiment_list
  --atlas_build_id
  --ensemblsqldb
					bos_taurus_core_67_31
					caenorhabditis_elegans_core_67_230
					canis_familiaris_core_67_2
					drosophila_melanogaster_core_67_539
					homo_sapiens_core_67_37
					mus_musculus_core_67_37
					pan_troglodytes_core_67_214
					rattus_norvegicus_core_67_34
					saccharomyces_cerevisiae_core_67_4
					sus_scrofa_core_67_102
					equus_caballus_core_67_2
  --ensembldir
					bos_taurus
					caenorhabditis_elegans
					canis_familiaris
					drosophila_melanogaster
					equus_caballus
					homo_sapiens
					mus_musculus
					pan_troglodytes
					saccharomyces_cerevisiae
					sus_scrofa

  --updateSampleAccession  add sample accession to table


 $PROG_NAME --setup_PR_Experiment --dataset_identifier PXD000036
 $PROG_NAME --insert_PR_Experiment --dataset_identifier PXD000036
 $PROG_NAME --load_PR_Experiment --dataset_identifier PXD000036
 $PROG_NAME --create_experiment_list --dataset_identifier PXD000036 --search_batch_subdir combined

~;

main();


###############################################################################
# Main Program:
###############################################################################
sub main
{
	unless (GetOptions(\%OPTIONS,"verbose","quiet","debug:s","testonly",
     "list_instrument",
     "list_experiment_type",
     "list_organism",
		 "downloadURL:s", 
		 "downloadTo:s",
		 "download",
      "setup_PR_Experiment",
      "insertProject",
      "dataset_identifier:s", 
      "project_tag:s",

			"pr_biosequence_set_id:i",
			"organism_id:i",

			"insert_PR_Experiment",
      "load_PR_Experiment",
      "create_experiment_list",
      "search_batch_subdir:s",
			"project_location:s",
			"experiment_type_id:i",
			"instrument_id:i",
			"sample_description_file:s",

			"getBuildScript",
			"biosequence_set_id:s",
			"fdr_threshold:s",
			"prob_threshold:s",
			"experiment_list:s",
			"atlas_build_id:s",
			"ensemblsqldb:s",
			"ensembldir:s",
    
      "updateSampleAccession",
		)) {
		print "$USAGE";
		exit;
	}


  $TEST = $OPTIONS{testonly} || 0;
  $VERBOSE = $OPTIONS{verbose} || 0;
  if($OPTIONS{help}){
    print "$USAGE";
    exit;
  }

  if($OPTIONS{list_experiment_type}){
    list_experiment_type ();
  }elsif($OPTIONS{list_instrument}){
    list_instrument();
  }elsif($OPTIONS{list_organism}){
    list_organism();
  }elsif ($OPTIONS{download}){
		get_files ();
	}elsif($OPTIONS{"create_experiment_list"}){
    create_experiment_list();
  }elsif($OPTIONS{"insertProject"} || $OPTIONS{"setup_PR_Experiment"} || $OPTIONS{insert_PR_Experiment} ||  
   $OPTIONS{load_PR_Experiment} ){
    my $project_id;
	  my $dataset_identifier = $OPTIONS{"dataset_identifier"} || ''; 
		$dataset_identifier =~ s/\s+//g;
		if( $dataset_identifier eq '' ){
			$dataset_identifier = get_user_input ('dataset_identifier', '', 100);
		}
	  my $response = check_project($dataset_identifier);
    if (check_project($dataset_identifier)){
      $project_id = $response;
      print "have project already: $project_id\n";
    }

    if(! $response && ($OPTIONS{"insertProject"} ||  $OPTIONS{"setup_PR_Experiment"}) ){
			 print "About to create project \n";
			 my $project_tag =  $OPTIONS{"project_tag"} || '';
			 if($project_tag eq ''){
					$project_tag =  get_user_input ('project_tag', '', 100);
					$OPTIONS{"project_tag"} = $project_tag; 
			 }
			 if($dataset_identifier =~ /PXD\d{6}/ ){
				 $project_id = insert_project_PXD($dataset_identifier);
			 }elsif($OPTIONS{"dataset_identifier"} =~ /PASS\d{4}/){
				 $project_id = insert_project_PASS($dataset_identifier);
			 }else{
				 die "$dataset_identifier not supported\n";
			 }
			 if($project_id && ! $TEST){
					print "update public data repository: set $dataset_identifier to have project_id $project_id\n";
					update_public_data_repository (project_id => $project_id, dataset_identifier => $dataset_identifier);
				}else{
					print "$dataset_identifier has project id $response already\n";
       }
		}
    if ($OPTIONS{"setup_PR_Experiment"} || $OPTIONS{insert_PR_Experiment} ){  
      print "insert proteomics experiment\n"; 
		  insert_proteomics_experiments($project_id);
    }
    if ($OPTIONS{"setup_PR_Experiment"} || $OPTIONS{load_PR_Experiment} ){
      print "load proteomics experiments\n";
      load_proteomics_experiments($project_id);
    }
	}elsif($OPTIONS{updateSampleAccession}){
     updateSampleAccession();
  }elsif($OPTIONS{getBuildScript}){ ## not finished 
    if( ! $OPTIONS{organism_id} || 
				! $OPTIONS{pr_biosequence_set_id} || 
				! $OPTIONS{biosequence_set_id} || 
				! ($OPTIONS{fdr_threshold} || $OPTIONS{prob_threshold} )|| 
				! $OPTIONS{experiment_list} || 
				! $OPTIONS{atlas_build_id}){
       print qq~ 
         needs input for 
					--organism_id
					--pr_biosequence_set_id
					--biosequence_set_id
					--fdr_threshold or	--prob_threshold
					--experiment_list
					--ensemblsqldb
					--ensembldir
      ~;
      exit;
    }
		generate_build_script();
	}
} # end showMainPage

#########################################################################################
sub updateSampleAccession{
  my $sql = qq~
			SELECT DISTINCT S.SAMPLE_ACCESSION,
             PSB.DATA_LOCATION,  
             PDR.DATASET_IDENTIFIER, 
             PDR.LOCAL_DATA_LOCATION,
             PDR.DATASET_ID
			FROM $TBAT_PUBLIC_DATA_REPOSITORY PDR
			JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON (PDR.PROJECT_ID = PE.PROJECT_ID)
			JOIN $TBPR_SEARCH_BATCH PSB ON (PE.EXPERIMENT_ID = PSB.EXPERIMENT_ID)
			JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON (ASB.PROTEOMICS_SEARCH_BATCH_ID = PSB.SEARCH_BATCH_ID)
			JOIN $TBAT_SAMPLE S ON (ASB.SAMPLE_ID = S.SAMPLE_ID)
			WHERE PDR.PROJECT_ID IS NOT NULL AND PDR.PA_SAMPLE_ACCESSION IS NULL
  ~;


  my @rows = $sbeams->selectSeveralColumns ($sql);
  my %mapping = ();
  ## one DATASET_IDENTIFIER might have several SAMPLE_ACCESSION
  ## one SAMPLE_ACCESSION can only map to one DATASET_IDENTIFIER
  
  my %hash = ();
  foreach my $row (@rows){
    my ($sample_accession, $data_loc ,$dataset_identifier, $local_data_loc,$id) = @$row;
    $local_data_loc =~ s/sbeams\d+/sbeams/g;
    $data_loc =~ s/sbeams\d+/sbeams/g;

    if ( not defined $hash{$sample_accession} ){
      $hash{$sample_accession} = 0;
    }
    $data_loc =~ s/.*archive\///;
    $local_data_loc =~ s/.*archive\///;
    print "$sample_accession\nPDR:$local_data_loc\nPSB:$data_loc\n----------------\n";

    if($data_loc =~ /$local_data_loc/){
      print "$sample_accession $dataset_identifier\n";
      push @{$mapping{$dataset_identifier}}, [$sample_accession, $data_loc,$id];
      $hash{$sample_accession} = 1;
    }
  }
  foreach my $sample_accession (keys %hash){
    if(! $hash{$sample_accession}){
      print "$sample_accession did not found dataset_identifier\n";
    }
  }
  ## update TBAT_PUBLIC_DATA_REPOSITORY
  foreach my $dataset_identifier (keys %mapping){
    my @rows = @{$mapping{$dataset_identifier}};
    my ($sample_accession, $data_loc,$id);
    my $sep ='';
    $id = $rows[0]->[2];
    $data_loc = $rows[0]->[1];
    if(@rows > 1){
      $data_loc =~ s/(.*\/.*)\/.*/$1/;
    }
    foreach my $row(@rows){
      $sample_accession .= $sep.$row->[0];
      $sep = ', '; 
    } 
    print "UPDATE: $dataset_identifier\n$sample_accession $data_loc\n";
    my %rowdata=(
      pa_sample_accession => $sample_accession,
      local_data_location => $data_loc,
      classfication => 3,
    );

    my $response = $sbeams->updateOrInsertRow(
       update=>1,
       table_name=>$TBAT_PUBLIC_DATA_REPOSITORY,
       rowdata_ref=>\%rowdata,
       PK => 'dataset_id',
       PK_value=> $id,
       return_PK => 1,
       add_audit_parameters => 1,
       verbose=>$VERBOSE,
       testonly=> $TEST
      );
   }
}



sub check_project {
  my $dataset_identifier = shift;
  my $sql = qq~
     SELECT PROJECT_ID
     FROM  $TBAT_PUBLIC_DATA_REPOSITORY
     WHERE DATASET_IDENTIFIER = '$dataset_identifier'
  ~;
  my @rows = $sbeams->selectOneColumn($sql);
  if(@rows){
    return $rows[0];
  }else{
    return 0;
  }
}


sub update_public_data_repository {
  my %args = @_;
  my $project_id = $args{project_id} || '' ;
  my $dataset_identifier = $args{dataset_identifier} || die "need dataset identifier\n";
  my $local_data_location = $args{local_data_location} || '';
  my $setstr = '';
  my $sep = '';
  if($project_id){
    $setstr .= "PROJECT_ID = $project_id";
    $sep = ',';
  }
  if($dataset_identifier){
     $setstr .= "$sep local_data_location='$local_data_location'";
  }

  my $sql = qq~
     UPDATE $TBAT_PUBLIC_DATA_REPOSITORY 
     SET $setstr 
     WHERE DATASET_IDENTIFIER = '$dataset_identifier'
  ~;
  my $result = $sbeams->executeSQL($sql);
}


sub insert_project_PXD{
  my $dataset_identifier = shift;
  ##Public data repository
  my $sql = qq~
    SELECT DATASET_ID
    FROM $TBAT_PUBLIC_DATA_REPOSITORY
    WHERE DATASET_IDENTIFIER = '$dataset_identifier'
  ~;
  my @rows = $sbeams->selectOneColumn($sql);
  if (! @rows){
   print "$dataset_identifier not in PUBLIC_DATA_REPOSITORY table, please run ". 
         '$SBEAMS/lib/scripts/PeptideAtlas/get_public_repository_dataset.pl' ."\n";
   exit;
  } 

  my $result = `wget  -qO- "http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=$dataset_identifier&outputMode=XML&test=no"`;
  my @lines = split(/\n/, $result);
  ## get contact id, project name, tag, description, and publication
  my $str = '';
  my ($project_name, $project_tag, $project_description, 
      $pubmed_id, $contact_name, $contact_email, $contact_aff);

  if(defined $OPTIONS{project_tag}){
    $project_tag = $OPTIONS{project_tag} 
  }


  my $simple = XML::Simple->new(KeyAttr=>[],ForceArray => ['Contact', 'Publication']);
  my $data = $simple -> XMLin($result);
  #use Data::Dumper;
  #print Dumper($data);
  if (defined $data->{ContactList} ){
    #my $contact = $data->{ContactList}->{Contact}->[0]->{cvParam};
    foreach my $contact (@{$data->{ContactList}->{Contact}}){
      next if($contact->{id} ne 'project_lab_head');
			foreach my $cvParam (@{$contact->{cvParam}}){
				if($cvParam->{name} =~ /email/i){
					$contact_email = $cvParam->{value};
				}elsif($cvParam->{name}  =~ /(organization|affiliation)/i){
					$contact_aff = $cvParam->{value} ;
				}#elsif($cvParam->{name}  =~ /contact name/i){
				 #	 $contact_name = $cvParam->{value};
				#}
			}
    }
  }
  #if ( ! $contact_name){
  #  $contact_name =  get_user_input ('contact_name', '', 100);
  #  $contact_email = get_user_input ('contact_email', '', 100);
  #}

  if (defined $data->{PublicationList} ){
    $pubmed_id = $data->{PublicationList}->{Publication}->[0]->{id};
    if($pubmed_id =~ /(\d{8})/){
     $pubmed_id = $1;
    }else{
     $pubmed_id = '';
    }
  }

  $project_name = $data->{DatasetSummary}->{title};
  $project_description = $data->{DatasetSummary}->{Description};
  if(length($project_tag) > 50){
    print "Getting project_tag\n";
    $project_tag = get_user_input('project_tag', $project_tag, 50);
  }
  if(length($project_name) > 100){
    print "Getting project_name\n";
    $project_name = get_user_input('project_name' , $project_name, 100);
  }


  print qq~ 
    project_name: $project_name
    project_tag: $project_tag
    project_description: $project_description
    pubmed_id: $pubmed_id
    #contact_name: $contact_name
    #contact_email: $contact_email
    contact affiliation: $contact_aff
  ~ if($VERBOSE);

  my $project_id = insert_project(
      name => $project_name,
      project_tag => $project_tag,
      description => $project_description,
      pubmed_id => $pubmed_id,
      #contact_name => $contact_name,
      #contact_email => $contact_email,
      contact_aff => $contact_aff,
  );
  return $project_id ; 

}

sub insert_project_PASS{
  my $dataset_identifier = shift;
  my $description_file = "/proteomics/peptideatlas2/home/$dataset_identifier/$dataset_identifier". "_DESCRIPTION.txt";
  if ( ! -e "$description_file"){
    die "cannot find $description_file\n";
  }
  open (IN, "<$description_file") or die "cannot open $description_file\n";
  my @fields = ("identifier", "type", "tag", "title", "summary", "contributors",
  "publication", "growth", "treatment", "extraction", "separation", "digestion",
  "acquisition", "informatics", "instruments", "species", "massModifications",);
  my %fields = map {$_ => 1} @fields;
  my @lines;
  my $prev_line = '';
  while (my $line =<IN>){
    chomp $line;
    if (($line =~ /^(\S+):/) && (defined $fields{$1})) {
      push (@lines, $prev_line);
      $prev_line = $line;
    } else {
      $prev_line .= $line;
    }
  }
  push (@lines, $prev_line);
  my ($project_name, $project_tag,$project_description, $pubmed_id, $publication);
  for my $line (@lines) {
		chomp $line;
		if ($line =~ /^summary:\s*(.*)$/) {
			$project_description = $1;
			$project_description =~ s/^\s*//g;
			$project_description =~ s/\s*$//g;
      if ($project_description eq ''){
         print "Getting project_description\n";
        $project_description = get_user_input('project_description', $project_description, 500);
      }
			print "project_description: $project_description\n" if $VERBOSE;
			#use this for Project Description
		} elsif ($line =~ /^publication:\s*(.*)$/) {
			$publication = $1;
			$publication =~ s/^\s*//g;
			$publication =~ s/\s*$//g;
			print "Publication: $publication\n" if $VERBOSE;
		}elsif($line =~ /^tag:\s*(.*)$/) {
      $project_tag = $1;
      if(length($project_tag) > 50){
        print "Getting project_tag\n";
        $project_tag = get_user_input('project_tag', $project_tag, 50);
      }
      print "project_tag: $project_tag\n" if $VERBOSE;
    }elsif($line =~ /^title:\s*(.*)$/) {
      $project_name = $1;
      if(length($project_name) > 100){
        print "Getting project_tag\n";
        $project_name = get_user_input('project_name' , $project_name, 100);
      }
      print "project_name: $project_name\n" if $VERBOSE;
    }
  }
  my ($pubmed_id);
  if ($publication){
    if ( $publication =~ /(\d{8})/){
       $pubmed_id = $1;
    }else{
      print "WARNNING: cannot find pubmed id, if there is a publication, it won't get inserted\n";
    }
  }

  ## 
  my $sql = qq~ 
    SELECT FIRSTNAME, LASTNAME, EMAILADDRESS
    FROM $TBAT_PASS_SUBMITTER PS
    JOIN $TBAT_PASS_DATASET PD ON (PS.SUBMITTER_ID = PD.SUBMITTER_ID)
    WHERE PD.DATASETIDENTIFIER = '$dataset_identifier'
  ~; 
  my @rows = $sbeams->selectSeveralColumns($sql);
  my ($fname, $lname, $contact_email) = @{$rows[0]};

  my $project_id = insert_project(
      name => $project_name,
      project_tag => $project_tag,
      description => $project_description,
      pubmed_id => $pubmed_id,
      contact_name => "$fname $lname",
      contact_email => $contact_email,
      contact_aff => '',
  );
  return $project_id; 

}



sub get_user_input {
  my $field = shift;
  my $str = shift;
  my $limit = shift;
  my $newstr = $str;
  my $answer = 'NO';
  while (length($newstr) > $limit || $answer =~ /(n|no)/i){
    if ($newstr ne ''){
		  print "$newstr too long/not accepted, limit is $limit, try again\n";
    }else{
      print "please enter $field\n";
    }

		$newstr = <STDIN> ;
		if(length($newstr) <= $limit){
			print "$field will have name: $newstr. Accept it? YES/NO\n";
			$answer = <STDIN>; 
			while ($answer !~/^(y|n)/i){
				print "Please enter y/n\n";
				$answer = <STDIN>;
			} 
			if($answer =~ /^y/i){
				last;
			}
		} 
	}
  chomp $newstr;
  return $newstr;
}


sub insert_project{
  my %args = @_;
  my $name = $args{name} || die "need project name\n";
  my $project_tag = $args{project_tag} || die "needs project tag\n";
  my $description = $args{description} || die "needs description\n";
  my $pubmed_id = $args{pubmed_id};
  #my $contact_name = $args{contact_name} || die "needs contact name\n";
  #my $contact_email = $args{contact_email};
  #my $contact_aff = $args{contact_aff};
  #my $contact_id = get_contact_id(       
  #    contact_name => $contact_name,
  #    contact_email => $contact_email,
  #    contact_aff => $contact_aff);
  

  my $publication_id = '';
  if($pubmed_id && $pubmed_id =~ /\d+/){
    $publication_id =  get_publication_id ( $pubmed_id);
  }
  print "pubmed_id $pubmed_id\npublication_id  $publication_id\n";

  my $sql = qq~
    SELECT PROJECT_ID 
    FROM $TB_PROJECT
    WHERE PROJECT_TAG = '$project_tag'
          AND NAME ='$name'
  ~;
  my @result = $sbeams->selectOneColumn($sql);
  my $project_id;
  if(@result){
    print "There is a proejct for $project_tag and $name\n";
    $project_id = $result[0];
  }else{
    my %rowdata= (
			name => $name, 
			project_tag =>  $project_tag,
			pi_contact_id => $current_contact_id,
			description =>  $description,
			budget =>  "N/A",
      created_by_id => $current_contact_id,
      modified_by_id => $current_contact_id,
      record_status => "N",
			project_status  => "N", 
			publication_id => $publication_id);
 
	  $project_id = $sbeams->updateOrInsertRow(
				 insert => 1,
				 table_name => $TB_PROJECT,
				 rowdata_ref => \%rowdata,
				 PK => "project_id",
				 verbose=>$VERBOSE,
				 testonly=>$TEST,
				 return_PK => 1,);
    print "$project_id\n";
    print Dumper(\%rowdata);
  }
  ## grant access of current_contact_id to this project
  if($project_id ){
		print "Adding USER_PROJECT_PERMISSION \n";
		my $sql = qq~
			SELECT USER_PROJECT_PERMISSION_ID
			FROM $TB_USER_PROJECT_PERMISSION
			WHERE CONTACT_ID = $current_contact_id AND 
						PROJECT_ID = $project_id 
		~;
		my @row = $sbeams->selectOneColumn($sql);
		if ( ! @row){
			## insert
			my %rowdata = (
				contact_id => $current_contact_id,
				privilege_id  => 10,
				project_id => $project_id,
				date_created       =>  $date,
				created_by_id      =>  $current_contact_id,
				date_modified      =>  $date,
				modified_by_id     =>  $current_contact_id,
				owner_group_id     =>  $current_work_group_id,
				record_status      =>  'N',);
			my $id = $sbeams->updateOrInsertRow(
					 insert => 1,
					 table_name => $TB_USER_PROJECT_PERMISSION,
					 rowdata_ref => \%rowdata,
					 PK => "USER_PROJECT_PERMISSION_ID",
					 verbose=>$VERBOSE,
					 testonly=>$TEST,
					 return_PK => 1,);
       print "USER_PROJECT_PERMISSION_ID $id added for project $project_id\n";
		}
		print "Add GROUP_PROJECT_PERMISSION\n";
    $sql = qq~
      SELECT work_group_id, group_project_permission_id
      FROM $TB_GROUP_PROJECT_PERMISSION
      WHERE (work_group_id  = 40 or work_group_id  = 85)  AND
            PROJECT_ID = $project_id
    ~;
    my %g_permission = $sbeams->selectTwoColumnHash($sql);
    foreach my $num (qw( 40 85)){
      my $privilege_id = 10; 
      if($num == 85){
        $privilege_id = 40;
      }
      if (not defined $g_permission{$num}){
       my %rowdata = (
        work_group_id => $num, 
        privilege_id  => $privilege_id,
        project_id => $project_id,
        date_created       =>  $date,
        created_by_id      =>  $current_contact_id,
        date_modified      =>  $date,
        modified_by_id     =>  $current_contact_id,
        owner_group_id     =>  $current_work_group_id,
        record_status      =>  'N',);
       my $id = $sbeams->updateOrInsertRow(
           insert => 1,
           table_name => $TB_GROUP_PROJECT_PERMISSION,
           rowdata_ref => \%rowdata,
           PK => "GROUP_PROJECT_PERMISSION_ID",
           verbose=>$VERBOSE,
           testonly=>$TEST,
           return_PK => 1,);
      print "GROUP_PROJECT_PERMISSION_ID $id added for project $project_id\n";
    }
  }
 }      

  return $project_id;
}


sub get_publication_id {
  my $pubmed_id = shift;

  my $sql = qq~
   SELECT PUBLICATION_ID
   FROM $TBAT_PUBLICATION
   WHERE pubmed_ID = '$pubmed_id' 
  ~;
  my @rows = $sbeams->selectOneColumn($sql);

  if (@rows){
    print "publication $pubmed_id in table already, publication id is $rows[0]\n";
    return $rows[0];
  }

  use SBEAMS::Connection::PubMedFetcher;
  my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
  my $pubmed_info = $PubMedFetcher->getArticleInfo(PubMedID=>$pubmed_id);

  if ($pubmed_info) {
    my %keymap = (
				MedlineTA=>'journal_name',
				AuthorList=>'author_list',
				Volume=>'volume_number',
				Issue=>'issue_number',
				AbstractText=>'abstract',
				ArticleTitle=>'title',
				PublishedYear=>'published_year',
				MedlinePgn=>'page_numbers',
				PublicationName=>'publication_name',);
    my %rowdata= ();
    while (my ($key,$value) = each %{$pubmed_info}) {
      if ($keymap{$key}) {
        if ($key eq 'AuthorList'){
           $value =~ s/([^,]+),.*/$1, et al./;
         } 
        $rowdata{$keymap{$key}} = $value;
      }
    }
    $rowdata{pubmed_ID} = $pubmed_id;
    $rowdata{date_created} = $date;
    $rowdata{created_by_id}      = $current_contact_id;
    $rowdata{date_modified}      = $date;
    $rowdata{modified_by_id}     = $current_contact_id;
    $rowdata{owner_group_id }    = $current_work_group_id;

    $rowdata{uri} = "http://www.ncbi.nlm.nih.gov/pubmed/$pubmed_id";
    my $publication_id = $sbeams->updateOrInsertRow( 
           insert => 1,
           table_name => $TBAT_PUBLICATION,
           rowdata_ref => \%rowdata,
           PK => "publication_id",
           verbose=>$VERBOSE,
           testonly=>$TEST,
           return_PK => 1,);
    return $publication_id;
  }
}

sub get_contact_id{
  my %args = @_;
  my $contact_name = $args{contact_name};
  my $contact_email = $args{contact_email};
  my $contact_aff = $args{contact_aff};
  my ($fname, $lname, $contact_id);
  if ($contact_name =~ /(\w+)\s+(\w+)/ || $contact_name =~ /(\w+)\s?,\s+(\w+)/){
    if($contact_name =~ /(\w+)\s+(\w+)/){
      $fname = $1;
      $lname = $2;
    }else{
      $lname = $1;
      $fname = $2;
    }
    print "Contact for the dataset is $fname $lname, Yes/No?\n";
    my $answer = <STDIN>;
    if($answer =~ /^n/i){
      print "Please input firstname of contact\n";
      $fname = get_user_input( "contact first name", $contact_name, 50);
      print "Please input lastname of contact\n";
      $lname = get_user_input( "contact last name", $contact_name, 50);
    }
  }else{
    print "cannot tell first name of contact\n"; 
    $fname = get_user_input( "contact first name", $contact_name, 50);
    print "Please input lastname of contact\n";
    $lname = get_user_input( "contact last name", $contact_name, 50);
  }
  chomp $fname;
  chomp $lname;
  my $sql = qq~
   SELECT CONTACT_ID 
   FROM $TB_CONTACT
   WHERE FIRST_NAME = '$fname' AND LAST_NAME = '$lname'
   AND RECORD_STATUS != 'D' 
  ~;
  my @rows = $sbeams->selectOneColumn($sql);

  if(@rows > 1){
    print join(",", @rows) ."\n";
    die "more than one match for contact $contact_name\n";
  }elsif(@rows == 1){
    $contact_id = $rows[0];
  }else{
    ## set organization_id to unknown, need to update later.
    my %rowdata= (
      first_name => $fname, 
      last_name => $lname, 
      contact_type_id => 8,
      organization_id => 5,
      comment => "$contact_aff, $OPTIONS{dataset_identifier}",
    );
    $contact_id = $sbeams->updateOrInsertRow( insert => 1,
					 table_name => $TB_CONTACT,
					 rowdata_ref => \%rowdata,
           PK => "contact_id",
           verbose=>$VERBOSE,
           testonly=>$TEST,
           return_PK => 1,); 
  }
	## add user login if have none
	if($contact_id =~ /\d+/){
		$sql = qq~
		 SELECT USER_LOGIN_ID
		 FROM $TB_USER_LOGIN
		 WHERE CONTACT_ID = $contact_id 
		~;
		my @rows = $sbeams->selectOneColumn($sql);
		if (! @rows){
			$fname =~ /^(\w).*/;
			my $username = $1.$lname;
			my %rowdata = (
				contact_id => $contact_id, 
				username => lc($username),
				privilege_id  => 40,
				date_created       =>  $date,
				created_by_id      =>  $current_contact_id,
				date_modified      =>  $date,
				modified_by_id     =>  $current_contact_id,
				owner_group_id     =>  $current_work_group_id,
				record_status      =>  'N',);
			my $login_id = $sbeams->updateOrInsertRow( 
           insert => 1,
					 table_name => $TB_USER_LOGIN,
					 rowdata_ref => \%rowdata,
					 PK => "user_login_id",
					 verbose=>$VERBOSE,
					 testonly=>$TEST,
					 return_PK => 1,);
		}
     ## add user_work_group
    $sql = qq~
     SELECT USER_WORK_GROUP_ID
     FROM $TB_USER_WORK_GROUP
     WHERE CONTACT_ID = $contact_id
    ~;
     my @rows = $sbeams->selectOneColumn($sql);
     if(! @rows){
       my %rowdata=();
			 print "Creating user_work_group user_work_group_id for contact $contact_id\n";
			 $rowdata{'contact_id'} = $contact_id;
			 $rowdata{'work_group_id'} = 39; #PeptideAtlas_user
			 $rowdata{'privilege_id'} = 20; #data_modifier
			 $rowdata{'created_by_id'} = $current_contact_id;
			 $rowdata{'modified_by_id'} = $current_contact_id;
			 my $user_work_group_id = $sbeams->updateOrInsertRow(
					insert=>1,
					table_name=>$TB_USER_WORK_GROUP,
					rowdata_ref=>\%rowdata,
					PK => 'user_work_group_id',
					return_PK => 1,
					verbose=>$VERBOSE,
					testonly=>$TEST,
				);
     }
  }
 
  #if ( !  $contact_id ){
  #  $contact_id = 668;
  #}
  return $contact_id;

}

sub get_files{
   my $downloadURL = $OPTIONS{downloadURL}; 
   my $downloadTo = $OPTIONS{"downloadTo"} || "/regis/sbeams9/archive/"; 
   $downloadURL=~ /(PXD\d+|PASS\d+)/;
   my $dataset_identifier = $1;

	 my $result = `wget -qO- $downloadURL`;
	 my @files = split("\n", $result);
	 my $directoy_size = 0;
	 foreach my $f (@files){
		 $f =~ /\((\d+) bytes/;
		 $directoy_size += $1;
	 }
	 print "Directoy_size: " . pretty_size ( $directoy_size ). "\n";
	 ## check target location size
	 my $drive = '';
	 if($downloadTo =~ /(.*sbeams\d?)\/archive/){
		 $drive = $1;
	 }else{
		 print "Download to location should be in sbeams/archive/ area";
		 exit;
	 }
	 my $avail = `df -h $drive | tail -1`;
	 chomp $avail;
	 $avail = (split(/\s+/, $avail))[3];

	 #use Filesys::DiskSpace;
	 #my $drive = (File::Spec->splitpath($to_location))[0];
	 #my ($fs_type, $fs_desc, $used, $avail, $fused, $favail) = df $to_location;

	 if($avail =~ /T$/){
			$avail *= 10 ** 12;
	 }elsif($avail =~ /G$/){
			$avail *= 10 ** 9;
	 }elsif($avail =~ /M$/){
			$avail *= 10 ** 6;
	 }elsif($avail =~ /K$/){
			 $avail *= 10 ** 3;
	 }
	 if ($avail - $directoy_size < 0){
		 print "No enough space left in $downloadTo for $downloadURL\n";
	 }else{
		 print "Target drive available size: ". pretty_size ($avail) ."\n";
     update_public_data_repository (local_data_location =>$downloadTo , dataset_identifier => $dataset_identifier);
		 $downloadTo = download_file ($downloadURL, $downloadTo);
     convert_file ($downloadTo);
	 }
}
## 
sub convert_file {
  my $to_location = shift;
  chdir $to_location;
  use File::Find qw(finddepth);
  my @files;
  finddepth(sub {
      return if($_ !~ /(RAW$|wiff$|\.d$)/i);
      push @files, $File::Find::name;
  }, "$to_location");

	foreach my $f (@files){
    chomp $f;
    $f =~ /(.*)\/(.*)/;
    print "$to_location $f\n"; 
    my $cmd = "ssh -Y $current_username\@regis.systemsbiology.net \"cd $1; qconvert $2\"";
    system  ($cmd);
	}
 
}

###############################################################################
# load_proteomics_experiments
###############################################################################

sub load_proteomics_experiments {
  my %args = @_;
  my $project_id  = shift; 
  my $search_batch_subdir = $OPTIONS{search_batch_subdir} || '';
  my $biosequence_set_id = $OPTIONS{biosequence_set_id} || '' ;
  if (! $project_id){ 
    die "need $project_id\n";
  }

  if (! $biosequence_set_id){
    my $organism_id = $OPTIONS{organism_id} || '';
    if(! $organism_id) {
       list_organism();
       print "\nplease enter organism_id \n\n";
       $organism_id =<STDIN>;
       $organism_id = checkWithUser(
         entry=>$organism_id,
         desc=>"organism_id",
         ask=>1,
       );
    }
    print "\nplease enter proteomics biosequence_set_id\n\n";
    list_pr_biosequence_set($organism_id);
    $biosequence_set_id = <STDIN>;
    $biosequence_set_id = checkWithUser(
			entry=>$biosequence_set_id,
			desc=>"biosequence_set_id",
			ask=>1,
    ); 
  } 
  if (! $search_batch_subdir){
    print "\nplease enter search_batch_subdir\n";
    $search_batch_subdir = <STDIN>;
    $search_batch_subdir = checkWithUser(
      entry=>$search_batch_subdir,
      desc=>"search_batch_subdir",
      ask=>1,
    );
  }
  
  my $sql = qq~
      SELECT PE.EXPERIMENT_ID, PE.EXPERIMENT_PATH  
      FROM $TBPR_PROTEOMICS_EXPERIMENT PE 
      JOIN $TB_PROJECT P ON (PE.project_id = P.project_id)
      WHERE P.project_id = $project_id
  ~;

  my @row = $sbeams->selectSeveralColumns($sql);
  foreach my $row (@row){
    my ($exp_id, $exp_path ) = @$row;
		my $search_batch_id = addSearchBatchEntry(
					experiment_id=>$exp_id,
					biosequence_set_id=>$biosequence_set_id,
					experiment_path => $exp_path,
					search_batch_subdir=>$search_batch_subdir,
			);
  }
}
###############################################################################
# addSearchBatchEntry: find or make a new entry in search_batch table
###############################################################################
sub addSearchBatchEntry {
  my %args = @_;
  my $SUB_NAME = 'addSearchBatchEntry';

  #### Decode the argument list
  my $experiment_id = $args{'experiment_id'}
   || die "ERROR[$SUB_NAME]: experiment_id not passed";
  my $biosequence_set_id = $args{'biosequence_set_id'}
   || die "ERROR[$SUB_NAME]: search_database not passed";
  my $search_batch_subdir = $args{'search_batch_subdir'}
   || die "ERROR[$SUB_NAME]: search_batch_subdir not passed";
  my $experiment_path = $args{'experiment_path'}
   || die "ERROR[$SUB_NAME]: experiment_path not passed";

  #### See if a suitable search_batch entry already exists
  my $sql_query = qq~
      SELECT search_batch_id
        FROM $TBPR_SEARCH_BATCH
       WHERE experiment_id = '$experiment_id'
         AND search_batch_subdir = '$search_batch_subdir'
  ~;
  my @search_batch_ids = $sbeams->selectOneColumn($sql_query);
  my $search_batch_id;


  #### If not, create one
  if (! @search_batch_ids) {
    my %rowdata;
    $rowdata{experiment_id} = $experiment_id;
    $rowdata{biosequence_set_id} = $biosequence_set_id;
    $rowdata{data_location} = $experiment_path; 
    $rowdata{search_batch_subdir} = $search_batch_subdir;
    $search_batch_id = $sbeams->insert_update_row(
      insert=>1,
      table_name=>$TBPR_SEARCH_BATCH,
      rowdata_ref=>\%rowdata,
      PK=>'search_batch_id',
      return_PK=>1,
      verbose=>$VERBOSE,
      testonly=>$TEST,
    );
    unless ($search_batch_id) {
      die "ERROR: Failed to retreive PK search_batch_id\n";
    }
    print "created search_batch_id $search_batch_id for experiment $experiment_id\n";
    print "/regis/sbeams/archive/$experiment_path/$search_batch_subdir\n";
  #### If there's exactly one, the that's what we want
  } elsif (scalar(@search_batch_ids) == 1) {
    print "experiment $experiment_id has search_batch_ids $search_batch_ids[0]\n";
  #### If there's more than one, we have a big problem
  } elsif (scalar(@search_batch_ids) > 1) {
    die "ERROR: Found too many records for\n$sql_query\n";
  }

}
###############################################################################
# insert_proteomics_experiments
###############################################################################
sub insert_proteomics_experiments{
  my $project_id = shift; 
  my $dataset_identifier = $OPTIONS{dataset_identifier} || die "need dataset_identifier\n"; 
  my $description_file = $OPTIONS{sample_description_file} || '';
  ## insert and load sample to project
  ## create experiment list
  if(! $project_id ){
    die "no project_id for $dataset_identifier. need to insert project first\n";
  }

  my @fields = qw(experiment_name experiment_tag experiment_description experiment_directory search_batch_subdir);
	my %length_limit = (
		experiment_name => 100, 
		experiment_tag => 30,
		experiment_description => 8000,   
		experiment_directory => 100,
		search_batch_subdir => 100, 
	);
  my @description=();
  if ( -e $description_file){
    print "$description_file \n";
    open (F, "<$description_file") or die "cannot open $description_file\n";
    my $line = <F>;
    chomp $line;
    
		my @header =split(/\t/, $line);
		my %col = ();
		foreach my $i (0..$#header){
			 my $col_name = $header[$i];
			 $col_name =~ s/\s+$//;
			 $col_name =~ s/^\s+//;
			 $col_name =~ s/\s+/_/g;
			 $col{lc($col_name)} = $i;
		 }
     
		 foreach my $field (@fields){
			 if(not defined $col{lc($field)}){
				 die "needs experiment_name, experiment_tag, experiment_description, experiment_directory and search_batch_subdir info in description file\n";
			 }
		 }
		 while ($line=<F>){
			 chomp($line);
			 $line =~ s/\r//g; 
       print "$line\n";
			 my @elms = split(/\t/, $line);
			 foreach (@elms){
				 s/^"//;
				 s/"$//;
			 }
			 my @row =();
       ## check length  
       my @data=();
       foreach my $name (@fields){
        $name = get_user_input ($name, $col{$name}, $length_limit{$name});
        push @data, $name;
      }
			push @description , [@data];
		}
  }else{ ## no experiment description file, get user input
    print "no experiment description file. Please enter experiment description\n";
    print "please enter number of experiment for project $project_id\n";
    my $n_expt = <STDIN> ; 
    chomp $n_expt;
    while ($n_expt !~ /^\d+/){
      print "please enter number only\n";
      $n_expt = <STDIN> ;
      chomp $n_expt;
    }
    print "you will need to entry experiment descript for $n_expt experiment\n";
    while ($n_expt > 0){
      print "getting experiment description for experiment $n_expt\n";
      my @data = ();
      foreach my $name (@fields){
        my $value = get_user_input ($name, '', $length_limit{$name});
        push @data, $value;
      }     
      push @description , [@data];
      $n_expt--;
    } 

  }
  # organism_id        =>  $OPTIONS{organism_id},
  # experiment_type_id =>  $OPTIONS{experiment_type_id},
  # instrument_id      =>  $OPTIONS{instrument_id},
  my $organism_id  = $OPTIONS{organism_id} | '';
  my $experiment_type_id = $OPTIONS{experiment_type_id} || '';
  my $instrument_id = $OPTIONS{instrument_id} || '';
  my $protease_id = $OPTIONS{protease_id} || '';
  if (! $organism_id){
    list_organism();
    print "\nplease enter organism_id\n";
    $organism_id = <STDIN> ;
    $organism_id = checkWithUser(
      entry=>$organism_id,
      desc=>"organism_id",
      ask=>1,
    );
   $OPTIONS{organism_id} = $organism_id;
  } 
  if (! $experiment_type_id){
    list_experiment_type();
    print "\nplease enter experiment_type_id \n";
    $experiment_type_id = <STDIN> ;
      $experiment_type_id = checkWithUser(
      entry=>$experiment_type_id,
      desc=>"experiment_type_id",
      ask=>1,
    );
    $OPTIONS{experiment_type_id} = $experiment_type_id;
  } 
  if(! $instrument_id){
     print "\nplease enter instrument_id\n"; 
    list_instrument();
    $instrument_id = <STDIN> ;
     $instrument_id = checkWithUser(
      entry=>$instrument_id,
      desc=>"instrument_id",
      ask=>1,
    );
    $OPTIONS{instrument_id} = $instrument_id;
  } 
  if(! $protease_id){
    list_protease();
    print "\nplease enter protease_id\n";
    $protease_id = <STDIN> ;
     $protease_id = checkWithUser(
      entry=>$protease_id,
      desc=>"protease_id",
      ask=>1,
    );
    $OPTIONS{protease_id} = $protease_id;
  }

  my $project_location = $OPTIONS{project_location} || '';
  if(! $project_location){
    $project_location = get_user_input ('project_location', '', 100);
    $OPTIONS{project_location}  = $project_location;
  }

  foreach my $row (@description){
    my ($experiment_name, $experiment_tag, $experiment_description,$experiment_directory,$search_batch_subdir)=@$row;
    my $experiment_path = "$project_location/$experiment_directory";
    if (! -d "$experiment_path"){
      print "experiment_path $experiment_path not found. Please enter correct experiment_path\n";
      while ( ! -d $experiment_path){
        $experiment_path = checkWithUser(
        entry=>$experiment_path,
        desc=>"experiment_path",
         ask=>1,
        ) 
      }
    }
    $experiment_path =~ s/.*archive\///;
    
    my $sql = qq~
      SELECT EXPERIMENT_ID 
      FROM $TBPR_PROTEOMICS_EXPERIMENT
      WHERE EXPERIMENT_PATH = '$experiment_path' 
      AND EXPERIMENT_TAG = '$experiment_tag'
    ~;
    my @result = $sbeams->selectOneColumn($sql);

		my %rowdata = (
			contact_id         => $current_contact_id,
			project_id         => $project_id,
			experiment_name    => $experiment_name, 
			experiment_tag     => $experiment_tag,
			experiment_description => $experiment_description,
			experiment_path    => $experiment_path,
			organism_id        =>  $organism_id,
      protease_id        =>  $protease_id,
			experiment_type_id =>  $experiment_type_id,
			instrument_id      =>  $instrument_id,
			date_created       =>  $date,
			created_by_id      =>  $current_contact_id,
			date_modified      =>  $date,
			modified_by_id     =>  $current_contact_id,
			owner_group_id     =>  $current_work_group_id,
			record_status      =>  'N',);
    if(! @result){
			my $experiment_id = $sbeams->updateOrInsertRow(
			 insert=>1,
			 table_name=>$TBPR_PROTEOMICS_EXPERIMENT,
			 rowdata_ref=>\%rowdata,
			 PK => 'experiment_id',
			 return_PK => 1,
			 add_audit_parameters => 1,
			 verbose=>$VERBOSE,
			 testonly=> $TEST
			);
      print "\n$experiment_id inserted to project $project_id\n";
    }elsif(@result == 1){ # update
      my $experiment_id = $sbeams->updateOrInsertRow(
       update=>1,
       table_name=>$TBPR_PROTEOMICS_EXPERIMENT,
       rowdata_ref=>\%rowdata,
       PK => 'experiment_id',
       PK_value=> $result[0],
       return_PK => 1,
       add_audit_parameters => 1,
       verbose=>$VERBOSE,
       testonly=> $TEST
      );
      print "\nEXPERIMENT_ID $result[0]  updated\n";
    }else{
       die "ERROR: more than one entry for $experiment_tag updated";
    }
  }  
}

#create_experiment_list  minimum option: --dataset_identifier --search_batch_subdir
###############################################################################
# create_experiment_list
###############################################################################
sub create_experiment_list {
  my $dataset_identifier = $OPTIONS{dataset_identifier} || die "need dataset_identifier\n";
  my $search_batch_subdir = $OPTIONS{search_batch_subdir} || die "need search_batch_subdir\n"; 
  my $project_id = '';
  my $response = check_project($dataset_identifier) ;
  if ($response){
    $project_id = $response;
  }else{
    print "didn't find project id for $dataset_identifier\n";
  }
  my $sql = qq~
     SELECT SB.SEARCH_BATCH_ID , PE.experiment_path, SB.SEARCH_BATCH_SUBDIR
     FROM $TB_PROJECT P
     JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON (P.PROJECT_ID = PE.PROJECT_ID )
     JOIN $TBPR_SEARCH_BATCH SB ON (SB.EXPERIMENT_ID = PE.EXPERIMENT_ID) 
     WHERE P.PROJECT_ID = $project_id
  ~;
  my @rows = $sbeams -> selectSeveralColumns ($sql);
  foreach my $row(@rows){
    my ($id, $loc,$subdir) = @$row;
    if ( ! -d "/regis/sbeams/archive/$loc/$subdir"){
      print "WARNING: /regis/sbeams/archive/$loc not exist\n";
    }
    print "$id\t/regis/sbeams/archive/$loc/$subdir\n";
  }

}

###############################################################################
# generate_build_script
###############################################################################
sub generate_build_script{
     my $organism_id = $OPTIONS{organism_id};
     my $fdr_threshold = $OPTIONS{fdr_threshold}||0;
     my $prob_threshold = $OPTIONS{prob_threshold} || 0;
     my $atlas_build_id = $OPTIONS{atlas_build_id};
     my $biosequence_set_id = $OPTIONS{'biosequence_set_id'};
     my $ensembl_dir = $OPTIONS{'ensembldir'};
     my $ensemblsqldb = $OPTIONS{'ensemblsqldb'};
     my $sql = qq~
      SELECT FULL_NAME, ABBREVIATION, ORGANISM_ID,ORGANISM_NAME 
      FROM $TB_ORGANISM
      WHERE ORGANISM_ID = $organism_id
     ~;
     my @row = $sbeams->selectSeveralColumns($sql);
     my ($full_name,$organism_abbrev,$organism_id, $organism);

     if( @row){
       ($full_name,$organism_abbrev,$organism_id, $organism) = @{$row[0]};
        $full_name =~ s/\s+/_/g;
     }
     my $threshold;
     if ($fdr_threshold){ 
       $threshold = "setenv FDR_THRESHOLD $fdr_threshold"; 
     }elsif($prob_threshold){ 
       $threshold = "setenv PROBABILITY_THRESHOLD $prob_threshold"; 
     }else{
       $threshold = "setenv FDR_THRESHOLD\n#setenv PROBABILITY_THRESHOLD";
     }
    $sql = qq~ 
       SELECT ATLAS_BUILD_NAME, DATA_PATH
       FROM $TBAT_ATLAS_BUILD
       WHERE ATLAS_BUILD_ID = $atlas_build_id 
     ~;
    my @rows = $sbeams->selectSeveralColumns($sql);
    my ($atlas_build_name, $build_path) = @{$rows[0]};
    $build_path =~ s/\/DATA.*//;
    my $build_directory = $build_path;
    $build_directory =~ s/.*\///;       
    my ($date) = `date '+%F+%H+%m+%s'`;
    chomp $date;
     
    my $file = "/net/db/projects/PeptideAtlas/pipeline/run_scripts_web/run_{$full_name}_$date.csh";
    open (F, ">$file") or die "cannot open $file $!\n";
    #system("chmod 777 $file");
    #system("chown $current_username $file");

     my $str = qq~ 
      #!/bin/csh
      setenv STEPSTORUN "01 01a 02a 02sc 02b 02 03 04 05 06 07a_stats ";
      $current_username
			setenv ORGANISM_NAME $full_name 
			setenv ORGANISM_LABEL $organism
			setenv ORGANISM_ABBREV $organism_abbrev
			setenv ORGANISM_ID $organism_id
			setenv BSS_ID $biosequence_set_id 
			setenv ESTIMATE_ABUNDANCE 0
			setenv SLOPE
			setenv YINT
			setenv GLYCO 0
      setenv VERSION $build_directory 
      setenv SUPPLEMENTAL_PROTEINS \$supplemental_proteins
      $threshold
      setenv BUILD_ABS_PATH "\$PIPELINE/output/\$VERSION"
      setenv MASTER_PROTXML "\$BUILD_ABS_PATH/analysis/interact-combined.prot.xml"
      setenv PER_EXPT_PIPELINE ''
      setenv DATABASE_NAME 
      setenv DECOY_PREFIX DECOY 
      setenv PIPELINE /net/db/projects/PeptideAtlas/pipeline/
			setenv PIPELINE_SCRIPT /net/db/projects/PeptideAtlas/pipeline/peptideAtlasPipeline_Ensembl.pl
			setenv BUILD_ABS_DATA_PATH \$BUILD_ABS_PATH/DATA_FILES
			setenv SPECTRAST_EXE "spectrast"
			setenv EXPERIMENTS_LIST_PATH \$PIPELINE/etc/build_list/\$ORGANISM_LABEL/
			setenv ENSEMBL_DIR	$ensembl_dir
      setenv ENSMYSQLDBNAME  $ensemblsqldb
			setenv MAP_ADAPTOR GRCH37
			setenv ENSMYSQLDBHOST "mysql"
			setenv ENSMYSQLDBUSER "guest"
			setenv ENSMYSQLDBPSSWD "guest"
      setenv SBEAMS "/net/dblocal/www/html/devZS/sbeams"
      #### Run the master script with the above settings
      ./run_Master.csh
    ~;
    print F "$str";
    close F;
		###############################################################################
		# generate_loading_script
		###############################################################################
		$file = "/net/db/projects/PeptideAtlas/pipeline/run_scripts_web/load.csh";
		open (L, ">$file") or die "cannot open $file $!\n";

		my $str = qq~ 
			#!/bin/csh
			set atlas_build_id=$atlas_build_id
			set atlas_build_name="$atlas_build_name"
			set organism_name=$organism
			set organism_abbrev=$organism_abbrev
			set build_path=/net/db/projects/PeptideAtlas/pipeline/output/$build_path
			setenv SBEAMS /net/dblocal/www/html/devZS/sbeams
			#### Load the build results into the database
			cd \$build_path
			rm load.log
			touch load.log

			nohup \$SBEAMS/lib/scripts/PeptideAtlas/load_atlas_build.pl \\
				--atlas_build_name "\$atlas_build_name" --organism_abbrev "\$organism_abbrev" \\
				--purge \\
				--default_sample_project_id 476 \\
			>> load.log


			nohup \$SBEAMS/lib/scripts/PeptideAtlas/load_atlas_build.pl \\
				--atlas_build_name "\$atlas_build_name" --organism_abbrev "\$organism_abbrev" \\
				--load \\
				--default_sample_project_id 476 \\
			>> load.log

			nohup \$SBEAMS/lib/scripts/PeptideAtlas/load_atlas_build.pl \\
				--atlas_build_name "\$atlas_build_name" --organism_abbrev "\$organism_abbrev" \\
				--prot_info \\
			>> load.log

			#### Build the search key
			nohup \$SBEAMS/lib/scripts/PeptideAtlas/rebuildKeySearch.pl \\
				--organism_name "\$organism_name" \\
				--atlas_build_id "\$atlas_build_id" \\
			>> load.log


			#### Update empirical proteotypic scores
			nohup \$SBEAMS/lib/scripts/PeptideAtlas/updateProteotypicScores.pl \\
				--atlas_build_name "\$atlas_build_name" \\
				--update_observed \\
				--export_file observed_peptides.tsv \\
			>> load.log


			#### Load spectra and spectrum IDs
			nohup \$SBEAMS/lib/scripts/PeptideAtlas/load_atlas_build.pl \\
				--atlas_build_name "\$atlas_build_name" --organism_abbrev "\$organism_abbrev" \\
				--spectra \\
				--default_sample_project_id 476 \\
			>> load.log

			#### Update the build statistics
			nohup \$SBEAMS/lib/scripts/PeptideAtlas/update_search_batch_statistics.pl \\
				--build_id "\$atlas_build_id" \\
			>> load.log

		~;
		print L "$str";
		close L;
}

sub download_file{
  my $from_location = shift;
  my $to_location = shift;

  $from_location =~ s/\/$//;
  $from_location =~ /(PXD\d+|PASS\d+)/;
  $to_location .= "/$1";


  if ( ! -d $to_location){
    if ($to_location !~ /\/sbeams.*\/archive/){
      print "must put file in /regis/sbeams/archive \n";
      return;
    }
		$to_location =~ /(.*archive\/)(.*)/;
		my $dir = $1;
		my $subdir = $2;  
		print "chdir $dir\n";
		chdir $dir;
    $subdir =~ s/^\///;
    `mkdir -p $subdir`;
    print "chdir $subdir\n";
    chdir "$subdir";
		#foreach my $d (split("/", $subdir)){
	 	# print "mkdir $d\n";
		#	mkdir $d;
		#	print "chdir $d\n";
		#	chdir $d;
		#}
  }else{
    print "chdir $to_location\n";
    chdir $to_location;
    opendir(DIR, "$to_location") or die "Cannot open the current directory: $!";
    my @filelist = grep {$_ ne '.' and $_ ne '..'} readdir DIR;
    close DIR;
    if(@filelist){
      print "WARNNING: $to_location not empty\n";
    }

  }
  ## download file
  
  my ($username,$password,$ftp_host,$ftp_dir);
  if($from_location =~ /(PASS\d+):(.+)@(.*)/){
    $username = $1;
    $password = $2;
    $ftp_host = $3;
    $ftp_dir = "./";
    $ftp = Net::FTP->new("$ftp_host", Debug => 0) or die "Cannot connect to $ftp_host: $@";
    $ftp->login("$username","$password") or die "Cannot login ", $ftp->message;
  }else{
		$from_location =~ s/ftp:\/\///;
		$from_location =~ /([^\/]+)\/(.*)/;
		$ftp_host = $1;
		$ftp_dir = $2;
		#print "ftp host: $ftp_host , ftp dir: $ftp_dir\n";
		$ftp = Net::FTP->new("$ftp_host", Debug => 0) or die "Cannot connect to $ftp_host: $@";
		$ftp->login('', '') || die;
    $ftp->cwd("$ftp_dir") or die "Cannot change working directory ", $ftp->message;
  }
  $ftp -> binary();

  BFS('.', $to_location); # or '.' as the remote root directory where the crawling begins
  $ftp->quit();
  return $to_location;
}
sub BFS{
 my $root=shift;
 my $to_location = shift;
 my @queue = ($root);
 chdir $to_location;
 mkdir_locally("$root");
 while (scalar(@queue) > 0 ){
	 my @tmp_queue; 
	 foreach my $remotedir (@queue){
	 	 print "$remotedir\n";
		 my($remotefiles,$remotedirs) = ftp_dirs_files($remotedir);
		 map { &mkdir_locally("$to_location/$_");} @$remotedirs;
		 map { &ftp_get_file($_);}  @$remotefiles;
		 push @tmp_queue,@$remotedirs;
	 }
	@queue = @tmp_queue;
 }
}

sub mkdir_locally{
  my $local_dir = shift;
	$local_dir =~ s/\/$//;
	my @dirs = split(/\//,$local_dir);
	my $dir;
	for(my $i=0; $i < scalar(@dirs) ; $i++) {
		$dir .= $dirs[$i]."/"; 
		unless(-d $dir){
			mkdir $dir || die("can't mkdir $dir: $!");
		}
	}
}

sub ftp_dirs_files{
  my $dir=shift;
  my $dirinfo= $ftp->dir($dir);
  my (@remotedirs, @remotefiles);
  foreach my $remotefile (@$dirinfo){
		next if ($remotefile =~ /^\.$/ || $remotefile =~ /^\.\.$/);
    if($remotefile =~ /^d/){
      #    #drwxr-xr-x    2 100203   2004         4096 Feb 20  2013 3T3_L1_bilayer2
      #     drwxr-xr-x    2 0        0            4096 Jul 29 05:45 AcetylK_replicate 1 
      $remotefile =~ s/.*\w+\s+\d+\s+(\d{4}|[\d:]+)\s+//;
		  $remotefile = "${dir}/${remotefile}";
			push(@remotedirs,$remotefile);
    }else{
      $remotefile =~ s/.*\w+\s+\d+\s+(\d{4}|[\d:]+)\s+//;
      
      $remotefile = "${dir}/${remotefile}";
			push(@remotefiles,$remotefile);
		}
	}
	#return lists of remote files names and directories names
	return(\@remotefiles,\@remotedirs); 
}

sub ftp_get_file{
	my $remotefile = shift;
	print "remotefile: $remotefile\n";
  
	$ftp->get("$remotefile","$remotefile");
}



sub pretty_size {
  my $size = shift;
  my @l = qw(KB MB GB TB);
  my $n = -1;

  while ($size / 1000 > 1){
    $size = $size / 1000;
    $n++;
  }
  $size = sprintf("%.2f", $size);
  return "$size $l[$n]";
} 

sub list_instrument{
  my $sql = "SELECT INSTRUMENT_ID, INSTRUMENT_NAME FROM $TBPR_INSTRUMENT";
  my @rows = $sbeams -> selectSeveralColumns($sql);
  foreach my $row(@rows){
    print join(",", @$row);
    print "\n";
  }
  print "\n";
}

sub list_protease{
  my $sql = "SELECT ID, NAME FROM $TBAT_PROTEASES";
  my @rows = $sbeams -> selectSeveralColumns($sql);
  foreach my $row(@rows){
    print join(",", @$row);
    print "\n";
  }
  print "\n";


}
sub list_organism{
  my $sql = "SELECT ORGANISM_ID, ORGANISM_NAME FROM $TB_ORGANISM";
  my @rows = $sbeams -> selectSeveralColumns($sql);
  foreach my $row(@rows){
    print join(",", @$row);
    print "\n";
  }
  print "\n";

}
sub list_experiment_type{
  my $sql = "SELECT EXPERIMENT_TYPE_ID, EXPERIMENT_TYPE_NAME FROM $TBPR_EXPERIMENT_TYPE";
  my @rows = $sbeams -> selectSeveralColumns($sql);
  foreach my $row(@rows){
    print join(",", @$row);
    print "\n";
  }
  print "\n";
}

sub list_pr_biosequence_set{
  my $organism_id = shift;
  my $sql = "SELECT biosequence_set_id,set_path FROM $TBPR_BIOSEQUENCE_SET where organism_id = $organism_id order by biosequence_set_id desc";
  my %hash = $sbeams -> selectTwoColumnHash($sql);
  my $cnt = 10;
  foreach my $key(keys %hash){
    print "$key,$hash{$key}\n" if ($cnt > 0);
    $cnt--; 
  }
  return \%hash;
}

###############################################################################
###
### checkWithUser: allow user to enter, verify, or modify a data string
###
###############################################################################

sub checkWithUser {
  my %argv = @_;
  my $entry = $argv{entry};
  my $desc = $argv{desc};
  my $specs = $argv{specs} ||  '';
  my $ask = $argv{ask} || 0;

  my $answer = 'n';
  # Optionally, ask user if they want to change the current value
  if ($ask) {
    print "\n$desc: $entry\n";
    print "Requirements: $specs\n" if $specs;
    print "OK? ";
    $answer = <STDIN>;
    while ($answer !~ /[yYnN]/) {
      print "OK? (y/n) ";
      $answer = <STDIN>;
    }
  }
  # Get value from user and ask them to confirm.
  while ($answer !~ /^y/i) {
    print "Enter different $desc\n";
    $entry = <STDIN>;
    chomp $entry;
    print "Here is what you entered:\n";
    print $entry, "\n";
    print "OK now? ";
    $answer = <STDIN>;
    while ($answer !~ /[yYnN]/) {
      print "OK now? (y/n) ";
      $answer = <STDIN>;
    }
  }
  chomp $entry;
  return $entry;
}


