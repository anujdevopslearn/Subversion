#!/usr/local/bin/perl
# This cgi is called by GetSELExperiments via grid_ISB.js. Its job is to 
# retrieve data for all accessible experiments, then apply any search,
# sort, or download operation requested by the user.
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
my $sortby = $parameters{'sortby'} || 'experiment_title';
my $sort = $parameters{'orderby'} || 'ASC';
my $filtercol = $parameters{'filtercol'} || 'all';
my $filterstr = $parameters{'filterstr'};
my $dlfiletype = $parameters{'dlfiletype'} || '';

my $passel = new SBEAMS::PeptideAtlas::PASSEL;
my $json = new JSON;

# Collect a JSON hash containing data from all of the experiments.
# Store also in string form to use for searching, sorting.
my $json_href = $passel->srm_experiments_2_json();
$json = $json->pretty([1]);  # make encode add newlines & indentation
my $jsonstr = $json->encode($json_href);
my $hash;

my $count = 0;
my %sort_cols_hash =();
my $idx=0;


# User is searching. Figure out which entries pass the user-specified filter.
# This method depends on json pretty-encoding to always behave the same.
my %selectedTag=();
if($filterstr ne '' and $filtercol eq 'all'){
  $filterstr =~ s/^\s+//;
  $filterstr =~ s/\s+$//;
  my %tmp;
  my @qts = split (/\s+/, $filterstr);
  my @lines = split("\n", $jsonstr);
  my $first = 1;
  my $str = ''; 
  my $acc = '';
  # For each line in the string representation of the json data object
  foreach my $l (@lines){
    # if the line begins with 9 spaces, then a left brace
    # we are starting a new entry. Count filter matches for previous.
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
    # if the line contains the label "acc" ,
    # store the tag and add the line to the current entry
    }elsif($l =~ /"acc"\s*:\s*"(\S+)"/){
      $str .= $l;
      $acc = $1;
    # if the line matches neither of those patterns
    # add the line to the current entry
    }else{
      $l =~ s/"\w+"\s+://;
      $str .= $l;
    }
  }
  # for each acc we've seen, if it matched all the filters,
  # mark it as selected
  foreach my $acc (keys %tmp){
    if($tmp{$acc} == scalar @qts){
      $selectedTag{$acc} = 1;
    }
  }
}

foreach my $sample (@{$json_href->{"MS_QueryResponse"}{samples}}){
  ## filter the record using filterstr and filtercol
  if($filterstr ne ''){
    if($filtercol ne 'all'){
      if($filtercol eq 'title'){
	next if($sample->{experiment_title} !~ /$filterstr/i);
      }elsif($filtercol eq 'organism'){
	next if($sample->{taxonomy} !~ /$filterstr/i);
      }elsif($filtercol eq 'instrument'){
	next if($sample->{instrumentation}  !~ /$filterstr/i);
      }elsif($filtercol eq 'tag'){
	next if($sample->{sampletag}  !~ /$filterstr/i);
      }elsif($filtercol eq 'publication'){
	next if($sample->{publication}{cite}  !~ /$filterstr/i);
      }elsif($filtercol eq 'abstract'){
	next if($sample->{abstract}  !~ /$filterstr/i);
      }elsif($filtercol eq 'contributors'){
	next if($sample->{contributors}  !~ /$filterstr/i);
      }
    }else{
      next if(not defined $selectedTag{$sample->{acc}});
    }
  }

  if($sortby =~ /taxonomy/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{taxonomy} ;  
  }elsif($sortby =~ /title/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{experiment_title};
  }elsif($sortby =~ /instrument/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{instrumentation};
  }elsif($sortby =~ /publication/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{publication_name};
  }elsif($sortby =~ /spikein/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{spikein};
  }elsif($sortby =~ /mprophet/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{mprophet};

  # sorts are alphabetic, so these numeric columns don't sort correctly
  # So they've been made unsortable (sortable: false) in grid_ISB.js
  }elsif($sortby =~ /runs/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{counts}{runs};
  }elsif($sortby =~ /prots/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{counts}{prots};
  }elsif($sortby =~ /peps/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{counts}{peps};
  }elsif($sortby =~ /ions/i){
    $sort_cols_hash{$idx}{sortby} = $sample->{counts}{ions};
  }

  $sort_cols_hash{$idx}{sample} = $sample;
  $idx++;
} 

# User has requested to download table into file
if($cmd eq 'downloadtable'){
  print header( -type => 'application/excel', -attachment => 'PASSEL_SRM_experiments.tsv' ); 
  print "Experiment Title\tSample Tag\tSample Date\tOrganism\tData Contributors\tInstrument\t";
  print "Runs\tProteins\tPeptides\tSpike-in\tmProphet\t";
  print "Publication\tAuthors\tAbstract\n";
  foreach my $idx (sort {$sort_cols_hash{$a}{sortby} cmp $sort_cols_hash{$b}{sortby}} keys %sort_cols_hash ){
    my $title = $sort_cols_hash{$idx}{sample}->{experiment_title};
    my $sampletag  = $sort_cols_hash{$idx}{sample}->{sampletag};
    my $sample_date = $sort_cols_hash{$idx}{sample}->{sample_date};
    my $organism = $sort_cols_hash{$idx}{sample}->{taxonomy};
    my $contributors = $sort_cols_hash{$idx}{sample}->{contributors};
    my $instrument = $sort_cols_hash{$idx}{sample}->{instrumentation};

    my $runs = $sort_cols_hash{$idx}{sample}->{counts}{runs};
    my $proteins = $sort_cols_hash{$idx}{sample}->{counts}{prots};
    my $peptides = $sort_cols_hash{$idx}{sample}->{counts}{peps};
    my $spikein = $sort_cols_hash{$idx}{sample}->{spikein};
    my $mprophet = $sort_cols_hash{$idx}{sample}->{mprophet};

    my $publication = $sort_cols_hash{$idx}{sample}->{publication}{cite};
    my $authors = $sort_cols_hash{$idx}{sample}->{publication}{author};
    my $abstract = $sort_cols_hash{$idx}{sample}->{abstract};
    
    my $line =
    "$title\t$sampletag\t$sample_date\t$organism\t$contributors\t$instrument\t".
    "$runs\t$proteins\t$peptides\t$spikein\t$mprophet\t".
    "$publication\t$authors\t$abstract";
    # Remove all newlines, then add one at the end.
    $line =~ s/\n/ /g;
    $line =~ s/\r/ /g;
    $line .= "\n";

    print $line;
  }

# User wants to see table displayed in browser. Sort the list of sample numbers,
#  then print table for current page as json data object.
#  Display code (in grid_ISB.js) knows how to make use of this sorting?
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
