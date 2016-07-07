#!/usr/local/bin/perl

###############################################################################
# Program     : PASS_Query.cgi
# 
#
# Description : query PASS submission 
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
use JSON;
use POSIX qw(ceil);

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);
##use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

my $current_page = { organism => '', atlas_build_id => '' };

#$q = new CGI;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
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

    #### Read in the default input parameters
    my %parameters;
    my $n_params_found = $sbeams->parse_input_parameters(
        q=>$q,
        parameters_ref=>\%parameters
        );

    handle_request(ref_parameters=>\%parameters);

} # end main


###############################################################################
# Handle Request
###############################################################################
sub handle_request {

  my %args = @_;
  $log->debug( "Start page " . time() );

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
      || die "ref_parameters not passed";

  my %parameters = %{$ref_parameters};
  my $PROGRAM_FILE_NAME = $PROG_NAME;
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);
  #### Check the session cookie for a PASS_emailaddress
  my $cachedEmailAddress = $sbeams->getSessionAttribute( key => 'PASS_emailAddress' );
  my $cachedPassword = $sbeams->getSessionAttribute( key => 'PASS_xx' );
  my $emailAddress = $parameters{'email'};
  $emailAddress = $cachedEmailAddress if (!$emailAddress && $cachedEmailAddress);
  my $password = $parameters{'password'};
  $password = $cachedPassword if (!$password && $cachedPassword);
  my $firstName;
  my $lastName;
	my $action  = $parameters{'action'};
	my $pgsize = $parameters{'pgsize'};
	my $start = $parameters{'start'} || 1;
	my $sortby = $parameters{'sortby'} || 'id';
	my $sort = $parameters{'orderby'} || 'ASC';
	my $filtercol = $parameters{'filtercol'} || 'all';
	my $filterstr = $parameters{'filterstr'} || '';
  my $dlfiletype = $parameters{'dlfiletype'} || 'all';
  my $idOnly =  $parameters{'idOnly'} || 0;
  #### Compile any error we encounter in an array
  $filtercol =~ s/[\n\r]//;
  $filterstr =~ s/[\n\r]//;
  $dlfiletype =~ s/[\n\r]//;

  my @errors;
  my $login_msg = '';
  #### If the request was to LOGOUT, then purge everything
  if ($action =~ /LOGOUT/i ) {
    $sbeams->setSessionAttribute( key => 'PASS_emailAddress', value => '' );
    $sbeams->setSessionAttribute( key => 'PASS_xx', value => ''  );
    $emailAddress = '';
    $password = '';
  }

  #### See if we're already logged in
  my $authentication;
  if ($emailAddress && $password) {
    $authentication = authenticateUser(emailAddress=>$emailAddress,password=>$password);
    if ($authentication->{result} eq 'Success') {
      $firstName = $authentication->{firstName};
      $lastName = $authentication->{lastName};
    }
  }else{
    push @{$authentication->{errors}}, "The submitter email address or password is not filled in";
  } 

  #### Check authentication parameters and warn of any problems
  if ($action =~ /LOGIN/i && ! @errors ) {
    if ($authentication->{result} eq 'Success') {
      $sbeams->setSessionAttribute( key => 'PASS_emailAddress', value => $emailAddress );
      $sbeams->setSessionAttribute( key => 'PASS_xx', value => $password  );
    } else {
      push(@errors,@{$authentication->{errors}});
      foreach (@{$authentication->{errors}}){
       $login_msg .= "$_.";
      }
    }
  }

  $log->debug( "end param handling " . time() );

  my $file = "/proteomics/peptideatlas2/PASS.json" ;
	my %selectedID=();
	if($filterstr ne '' and $filtercol eq 'all'){
		$filterstr =~ s/^\s+//;
		$filterstr =~ s/\s+$//;
    $filterstr =~ s/[,;]//;
		my %tmp;
		my @qts = split (/\s+/, $filterstr);
		open (IN, "<$file") or die "cannot open $file\n";;
		my @lines = <IN>;
		my $first = 1;
		my $str = '';
		my $id = '';
		foreach my $l (@lines){
			if($l =~ /^\s{9}\{$/){
				if($first){
					$first = 0;
				}else{
					$str =~ s/[\{\}\[\]\s+]/ /g;
					foreach my $q (@qts){
						if($str =~ /$q/i){
							$tmp{$id}++;
						}
					}
				}
				$str = '';
			}elsif($l =~ /"id"\s+:\s+"(PASS\d{5})/){
				$str .= $1;
				$id = $1;
			}else{
				$l =~ s/"\w+"\s+://;
				$str .= $l;
			}
		}
		foreach my $id (keys %tmp){
			if($tmp{$id} == scalar @qts){
				$selectedID{$id} = 1;
     	}
		}
    
	}


  my ($date) = `date '+%F'`;
  chomp($date);
  my $json = new JSON;
  open(IN, "<$file");
  my @contents = <IN>;
  my $jsonstr = join("", @contents);
  my $hash = $json -> decode($jsonstr);
  my $filtered_hash;
  my %sort_cols_hash;
  my $idx=0;
  $date =~ s/\-//g;
  foreach my $dataset (@{$hash->{"MS_QueryResponse"}{samples}}){
    my $email = $dataset->{"email"};
    my $year =  $dataset->{dates}{release}{std}{year};
    my $month = $dataset->{dates}{release}{std}{month};
    my $day = $dataset->{dates}{release}{std}{day};
    $month = substr('00', 0,2- length($month)).$month;
    $day = substr('00', 0,2- length($day)).$day;
    my $releaseDate = "$year$month$day";
    my $flag = 0;
    if ($date > $releaseDate){
      $flag = 1;
    }
    if (($emailAddress && $password && $authentication->{result} eq 'Success')){
      if ($emailAddress =~ /$email/i){
        $flag = 1;
      }
    }
    next if (! $flag);
		 #push @{$filtered_hash->{"MS_QueryResponse"}{datasets}}, $dataset;
	 if($filterstr ne ''){
		 if($filtercol ne 'all'){
			 if($filtercol eq 'id'){
				 next if($dataset->{id} !~ /$filterstr/i);
			 }elsif($filtercol eq 'title'){
				 next if($dataset->{title} !~ /$filterstr/i);
			 }elsif($filtercol eq 'tag'){
				 next if($dataset->{tag}  !~ /$filterstr/i);
			 }elsif($filtercol eq 'email'){
				 next if($dataset->{email}  !~ /$filterstr/i);
			 }elsif($filtercol eq 'type'){
         next if($dataset->{type}  !~ /$filterstr/i);
       }elsif($filtercol eq 'submitter'){
         next if ($dataset->{submitter} !~ /$filterstr/i);
       }
		  }else{
        next if(not defined $selectedID{$dataset->{id}});
      }
		}
 		if($sortby =~ /id/i){
      if ($authentication->{result} eq 'Success' && 
         $emailAddress =~ /$email/i) {
	  		 $sort_cols_hash{$idx}{sortby} = "0.$dataset->{id}" ;
      }else{
          $sort_cols_hash{$idx}{sortby} = $dataset->{id};
      }
		}elsif($sortby =~ /tag/i){
			 $sort_cols_hash{$idx}{sortby} = uc ($dataset->{datasettag}) ;
		}elsif($sortby =~ /title/i){
			 $sort_cols_hash{$idx}{sortby} = uc( $dataset->{title});
		}elsif($sortby =~ /submitter/){
			 $sort_cols_hash{$idx}{sortby} = $dataset->{submitter}; 
		}elsif($sortby =~ /email/){
			 $sort_cols_hash{$idx}{sortby} = uc($dataset->{email});
		}elsif($sortby =~ /release/){
        $sort_cols_hash{$idx}{sortby} = $dataset->{dates}{release}{std}{year}.
                                        $dataset->{dates}{release}{std}{month}.
                                        $dataset->{dates}{release}{std}{day};
    }elsif($sortby =~ /type/i){
      $sort_cols_hash{$idx}{sortby} = uc($dataset->{type});
    }
		$sort_cols_hash{$idx}{sample} = $dataset;
		$idx++;
  }
  my $count;
  my @ids = ();
  
 
 if($sort =~ /ASC/){
    foreach my $idx (sort {$sort_cols_hash{$a}{sortby} cmp $sort_cols_hash{$b}{sortby}} keys %sort_cols_hash ){
      my $sample = $sort_cols_hash{$idx}{sample};
      if($count < $start -1 ){$count++;next;}
      if($pgsize ne '' and $count >= $pgsize + $start -1){$count++; last;}
      push @{$filtered_hash->{"MS_QueryResponse"}{samples}}, $sample;
      push @ids , $sample->{id};
      $count++;
    }
  }else{
    foreach my $idx(sort {$sort_cols_hash{$b}{sortby} cmp
      $sort_cols_hash{$a}{sortby}} keys %sort_cols_hash ){
      my $sample = $sort_cols_hash{$idx}{sample};
      if($count < $start -1 ){$count++;next;}
      if($pgsize ne '' and $count >= $pgsize + $start -1){$count++; last;}
      push @{$filtered_hash->{"MS_QueryResponse"}{samples}}, $sample;
      push @ids , $sample->{id};
      $count++;
    }
  }
 if ($action eq 'downloadtable'){
    print $q-> header( -type => 'application/excel', -attachment => 'table.xls' );
    print"Identifier\tDataset Title\tDataset Tag\tSubmitter\tEmail\tRelease Date\n";
    foreach my $idx (sort {$sort_cols_hash{$a}{sortby} cmp $sort_cols_hash{$b}{sortby}} keys %sort_cols_hash ){
			my $id  = $sort_cols_hash{$idx}{sample}->{id};
			my $tag  = $sort_cols_hash{$idx}{sample}->{tag};
			my $title = $sort_cols_hash{$idx}{sample}->{title};
			my $submitter = $sort_cols_hash{$idx}{sample}->{submitter};
      my $email = $sort_cols_hash{$idx}{sample}->{email};
			my $date = $sort_cols_hash{$idx}{sample}->{dates}{release}{std}{year}. "-" .
                      $sort_cols_hash{$idx}{sample}->{dates}{release}{std}{month}."-" .
                      $sort_cols_hash{$idx}{sample}->{dates}{release}{std}{day};
			print "$id\t$title\t$tag\t$submitter\t$email\t$date\n";
   }

 }elsif ($action eq 'download'){
  my $url = 'ftp://ftp:a@ftp.peptideatlas.org/pub/PeptideAtlas/Repository';
  my @list;
  print $q -> header( -type => 'application/txt', -attachment => 'list.txt' );
  foreach my $idx (sort {$sort_cols_hash{$a}{sortby} cmp $sort_cols_hash{$b}{sortby}} keys %sort_cols_hash ){
    my $id  = $sort_cols_hash{$idx}{sample}->{id};
    my $datapassword = $sort_cols_hash{$idx}{sample}->{datapassword};
    my $url = "ftp://$id:$datapassword".'@ftp.peptideatlas.org';
    my $dir = "/proteomics/peptideatlas2/home/$id";
    my @files;
    use File::Find;
    find( sub{
            if (-f $_ and $_ !~/bash/){
               my $file = $File::Find::name;
               $file =~ s/.*PASS/PASS/;
               push @files ,$file;
            }
    }, $dir );

    if($dlfiletype eq 'all'){
        print "$url\n";
    }else{
      foreach my $file (@files){
        if ($dlfiletype =~ /ML/i){
          $dlfiletype =~ s/\//|/;
          if($file =~ /($dlfiletype)$/i){
            print "$url/$file\n";
          }
        }elsif ($dlfiletype =~ /raw/i){
          $dlfiletype = 'raw|wiff|wiff.scan';
          if($file =~ /($dlfiletype)$/i){
             print "$url/$file\n";
          }
        }else{
          if($file =~ /$dlfiletype/i){
            print "$url/$file\n";
          }
        }
      }
    }
  }
 }else{
	 if ($action =~ /LOGIN/i){ 
			if ($authentication->{result} eq 'Success'){
				$filtered_hash->{"MS_QueryResponse"}{login} = 'success';
			}else{
				$filtered_hash->{"MS_QueryResponse"}{login} = $login_msg;
			}
		}else{
			$filtered_hash->{"MS_QueryResponse"}{login} = 'Anonymous';
		}


	 $filtered_hash->{"MS_QueryResponse"}{counts}{samples} = $idx;
   if ($idOnly){
      print join("," ,@ids);
   }else{
		 print  $q -> header('application/json');
		 $json = $json->pretty([1]);
		 print   $json->encode($filtered_hash);
   }
  }
}

#######################################################################
# authenticateUser
#######################################################################
sub authenticateUser {
  my %args = @_;
  my $SUB_NAME = 'authenticateUser';

  #### Decode the argument list
  my $emailAddress = $args{'emailAddress'} || die "[$SUB_NAME] ERROR:emailAddress  not passed";
  my $password = $args{'password'} || die "[$SUB_NAME] ERROR:password  not passed";


  my $response;
  my $sql = qq~
        SELECT submitter_id,firstName,lastName,password
        FROM $TBAT_PASS_SUBMITTER
        WHERE emailAddress = '$emailAddress'
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);
    if ( @rows ) {
      if (scalar(@rows) == 1) {

	my $databasePassword = $rows[0]->[3];
	if ($password eq $databasePassword) {
	  $response->{result} = 'Success';
	  $response->{firstName} = $rows[0]->[1];
	  $response->{lastName} = $rows[0]->[2];
	  $response->{submitter_id} = $rows[0]->[0];
	} else {
	  $response->{result} = 'IncorrectPassword';
	  push(@{$response->{errors}},'Incorrect password for this email address');
	}

      } else {
	die("ERROR: Too many rows returned for email address '$emailAddress'");
      }

    } else {
      $response->{result} = 'NoSuchUser';
      push(@{$response->{errors}},"There is not any user registered to '$emailAddress'");
    }

    return $response;
}

