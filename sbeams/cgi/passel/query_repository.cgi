#!/usr/local/bin/perl
use strict;
use CGI::Carp qw(fatalsToBrowser croak);
use FindBin;
use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log );
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Authenticator;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::PASSEL;
use CGI qw(:standard);
use JSON;

$sbeams = new SBEAMS::Connection;
my $sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

#### Read in the default input parameters
my %parameters;
my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
$sbeams->processStandardParameters(parameters_ref=>\%parameters);

#### Authenticate. Seems a shame to authenticate here when we already did it
#### in the calling cgi, GetSELExperiments. Seems to print 2 page footers?
# Use same permitted_work_groups as GetSELExperiments.
exit unless ($current_username = $sbeams->Authenticate(
      permitted_work_groups_ref=>['PeptideAtlas_user','PeptideAtlas_admin',
      'PeptideAtlas_readonly', 'PeptideAtlas_exec'],
      allow_anonymous_access=>1,
  ));

my $cmd  = $parameters{'cmd'};
my $scope = $parameters{'scope'};
my $type = $parameters{'type'};
my $pgsize = $parameters{'pgsize'};
my $start = $parameters{'start'} || 1;
my $sortby = $parameters{'sortby'} || 'acc';
my $sort = $parameters{'orderby'} || 'ASC';
my $filtercol = $parameters{'filtercol'} || 'all';
my $filterstr = $parameters{'filterstr'};
my $dlfiletype = $parameters{'dlfiletype'} || '';

my $passel = new SBEAMS::PeptideAtlas::PASSEL;
my $json = new JSON;

# Collect a JSON hash containing data from all of the experiments.
# Store also in string form to use for searching, sorting.
my $json_href = $passel->srm_experiments_2_json();
my $jsonstr = $json->encode($json_href);
my $hash;

my $count = 0;
my %sort_cols_hash =();
my $idx=0;


# User is searching. Figure out which entries pass the user-specified filter.
my %selectedAcc=();
if($filterstr ne '' and $filtercol eq 'all'){
  $filterstr =~ s/^\s+//;
  $filterstr =~ s/\s+$//;
  my %tmp;
  my @qts = split (/\s+/, $filterstr);
  my @lines = split("\n", $jsonstr);
	my $first = 1;
  my $str = ''; 
  my $acc = '';
	foreach my $l (@lines){
		if($l =~ /^\s{9}\{$/){
      if($first){
        $first = 0;
      }else{
        $str =~ s/[\{\}\[\]\s+]/ /g;
        foreach my $q (@qts){
          if($str =~ /$q/i){
            $tmp{$acc}++;
          }
        }
      }
      $str = '';
    }elsif($l =~ /"acc"\s+:\s+"(PAe\d{6})/){
      $str .= $1;
      $acc = $1;
    }else{
      $l =~ s/"\w+"\s+://;
      $str .= $l;
    }
  }
  foreach my $acc (keys %tmp){
    if($tmp{$acc} == scalar @qts){
      $selectedAcc{$acc} = 1;
    }
  }
}

foreach my $sample (@{$json_href->{"MS_QueryResponse"}{samples}}){
  ## filter the record using filterstr and filtercol
  if($filterstr ne ''){
		if($filtercol ne 'all'){
			if($filtercol eq 'acc'){
				 next if($sample->{acc} !~ /$filterstr/i);
			}elsif($filtercol eq 'title'){
				 next if($sample->{tilte} !~ /$filterstr/i);
			}elsif($filtercol eq 'organism'){
				 next if($sample->{taxonomy}{name} !~ /$filterstr/i);
			}elsif($filtercol eq 'instrument'){
				 next if($sample->{instrumentation}{platform}  !~ /$filterstr/i);
			}elsif($filtercol eq 'tag'){
         next if($sample->{sampletag}  !~ /$filterstr/i);
      }elsif($filtercol eq 'publication'){
         next if($sample->{publication}{author}  !~ /$filterstr/i);
      }
		}else{
      next if(not defined $selectedAcc{$sample->{acc}});
    }
  }
 
  if($sortby =~ /platform/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{instrumentation}{platform} ;
  }elsif($sortby =~ /taxonomy/i){
     $sort_cols_hash{$idx}{sortby} = $sample->{taxonomy}{name} ;  
  }elsif($sortby =~ /title/i){
     $sort_cols_hash{$idx}{sortby} = $sample->{title};
  }elsif($sortby =~ /sampletag/i){
     $sort_cols_hash{$idx}{sortby} = $sample->{sampletag};
  }elsif($sortby =~ /publication/){
     $sort_cols_hash{$idx}{sortby} = $sample->{publication}{author};
  }elsif($sortby =~ /acc/){
     $sort_cols_hash{$idx}{sortby} = $sample->{acc};
  }

  $sort_cols_hash{$idx}{sample} = $sample;
  $idx++;
} 

if($cmd eq 'downloadtable'){
  print header( -type => 'application/excel', -attachment => 'PASSEL_SRM_experiments.tsv' ); 
  print"Experiment Title\tSample Tag\tSample Date\tData Contributors\tInstrument\tPublication\tAuthors\n";
  foreach my $idx (sort {$sort_cols_hash{$a}{sortby} cmp $sort_cols_hash{$b}{sortby}} keys %sort_cols_hash ){
    my $title = $sort_cols_hash{$idx}{sample}->{experiment_title};
    my $sampletag  = $sort_cols_hash{$idx}{sample}->{sampletag};
    my $sample_date = $sort_cols_hash{$idx}{sample}->{sample_date};
    my $contributors = $sort_cols_hash{$idx}{sample}->{contributors};
    my $instrument = $sort_cols_hash{$idx}{sample}->{instrumentation};
    my $publication = $sort_cols_hash{$idx}{sample}->{publication}{cite};
    my $authors = $sort_cols_hash{$idx}{sample}->{publication}{author};
    print "$title\t$sampletag\t$sample_date\t$contributors\t$instrument\t";
    print "$publication\t$authors\n";
  }
} else {
  $hash ->{"MS_QueryResponse" }{"userinfo"} = $json_href->{"MS_QueryResponse"}{"userinfo"};
  $hash ->{"MS_QueryResponse" }{"counts"} = $json_href->{"MS_QueryResponse"}{"counts"};

	if($sort =~ /ASC/){
		foreach my $idx (sort {$sort_cols_hash{$a}{sortby} cmp $sort_cols_hash{$b}{sortby}} keys %sort_cols_hash ){
			my $sample = $sort_cols_hash{$idx}{sample};
			if($count < $start -1 ){$count++;next;}
			if($pgsize ne '' and $count >= $pgsize + $start -1){$count++; last;}
			push @{$hash->{"MS_QueryResponse"}{samples}}, $sample;
			$count++;
		}
	}else{
		foreach my $idx(sort {$sort_cols_hash{$b}{sortby} cmp $sort_cols_hash{$a}{sortby}} keys %sort_cols_hash ){
			my $sample = $sort_cols_hash{$idx}{sample};
			if($count < $start -1 ){$count++;next;}
			if($pgsize ne '' and $count >= $pgsize + $start -1){$count++; last;}
			push @{$hash->{"MS_QueryResponse"}{samples}}, $sample;
			$count++;
		}
	}
  $hash ->{"MS_QueryResponse" }{"counts"}{"samples"} = $idx ;
  $json = new JSON;
  $json = $json->pretty([1]);
  print header('application/json');
  print $json->encode($hash);

}
