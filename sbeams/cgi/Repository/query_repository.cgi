#!/usr/local/bin/perl
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $q $QUIET $VERBOSE $DEBUG );

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use CGI qw(:standard);
use JSON;

$sbeams = new SBEAMS::Connection;
my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
$sbeams->processStandardParameters(parameters_ref=>\%parameters);

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
 
my $file = "/net/dblocal/www/html/devZS/sbeams/cgi/Repository/PA_Samples_entries.json" ;
my $json = new JSON;
open(IN, "<$file");
my @contents = <IN>;
my $jsonstr = join("", @contents);
my $content = $json -> decode($jsonstr);
my $hash;

my $count = 0;
my %sort_cols_hash =();
my $idx=0;


my %selectedAcc=();
if($filterstr ne '' and $filtercol eq 'all'){
  $filterstr =~ s/^\s+//;
  $filterstr =~ s/\s+$//;
  my %tmp;
  my @qts = split (/\s+/, $filterstr);
  open (IN, "<$file");
  my @lines = <IN>;
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
      $l =~ s/.*://;
      $str .= $l;
    }
  }
  foreach my $acc (keys %tmp){
    if($tmp{$acc} == scalar @qts){
      $selectedAcc{$acc} = 1;
    }
  }
}

foreach my $sample (@{$content->{"MS_QueryResponse"}{samples}}){
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
  print header( -type => 'application/excel', -attachment => 'table.xls' ); 
  print"Accession\tSample Title\tSample Tag\tInstrument\tPubmed ids\tAuthors\n";
  foreach my $idx (sort {$sort_cols_hash{$a}{sortby} cmp $sort_cols_hash{$b}{sortby}} keys %sort_cols_hash ){
    my $acc  = $sort_cols_hash{$idx}{sample}->{acc};
    my $samletag  = $sort_cols_hash{$idx}{sample}->{sampletag};
    my $title = $sort_cols_hash{$idx}{sample}->{title};
    my $pubmedids = $sort_cols_hash{$idx}{sample}->{publication}{ids};
    my $author = $sort_cols_hash{$idx}{sample}->{publication}{author};
    my $instrument = $sort_cols_hash{$idx}{sample}->{instrumentation}{platform};
    print "$acc\t$title\t$sampletag\t$instrument\t";
    print join(",",@{$pubmedids});
    print "\t$author\n";
  }
}elsif($cmd eq 'download'){
  my $url = 'ftp://ftp:a@ftp.peptideatlas.org/pub/PeptideAtlas/Repository';
  my @list;
  print header( -type => 'application/txt', -attachment => 'list.txt' ); 
  foreach my $idx (sort {$sort_cols_hash{$a}{sortby} cmp $sort_cols_hash{$b}{sortby}} keys %sort_cols_hash ){
    my $acc  = $sort_cols_hash{$idx}{sample}->{acc};
    my $files = opendir(DIR , "/prometheus/u1/ftp/pub/PeptideAtlas/Repository/$acc");
    my @files = readdir(DIR);
    
    if($dlfiletype eq 'all'){
      foreach my $file (@files){
        if($file =~ /gz$/ || $file =~ /README/){
          print "$url/$acc/$file\n";
        }
      }
    }else{
      foreach my $file (@files){
        if($file =~ /$dlfiletype/i){
          print "$url/$acc/$file\n";
        }
      }
    }
  } 
}else{
  $hash ->{"MS_QueryResponse" }{"userinfo"} = $content->{"MS_QueryResponse"}{"userinfo"};
  $hash ->{"MS_QueryResponse" }{"counts"} = $content->{"MS_QueryResponse"}{"counts"};

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
  print  header('application/json');
  print   $json->encode($hash);

}
