#!/usr/local/bin/perl

###############################################################################
# Program     : NextProtPAmapping 
# 
#
# Description : for each neXtProt protein on chromosome N provides a simple yes/no and counts results 
#               from our latest Human All atlas 
#               
#
# SBEAMS is Copyright (C) 2000-2011 Institute for Systems Biology
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
$|++;

use lib "$ENV{SBEAMS}/lib/perl";
use vars qw ($sbeams $sbeamsMOD $VERBOSE $TESTONLY $USAGE $PROG_NAME); 
use LWP::UserAgent;

use File::Listing qw(parse_dir);
use File::stat;
use File::Copy;
use POSIX qw(strftime);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;
$sbeams = new SBEAMS::Connection;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ProtInfo;

$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


my %OPTIONS;
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
                              When nonzero, waits for user confirm at each step.
  --testonly                  If set, rows in the database are not changed or
                                added and no new directories are created.
  --insert                    will insert even there is a same nextprot mapping for the build  
                              (use when the atlasprophet version changed)
  --update
  --insertMapping
  --insertSummary
  --protein_file_location   
  --nextprot_mapping_id 
  --atlas_build_id 
 $ENV{SBEAMS}/lib/scripts/PeptideAtlas/load_neXtProt_mapping.pl \
 --nextprot_mapping_id 4 \
 --protein_file_location /net/db/projects/PeptideAtlas/pipeline/AtlasProphet/2015-10-26/HumanAll/ \
 --update --verbose --testonly

 $ENV{SBEAMS}/lib/scripts/PeptideAtlas/load_neXtProt_mapping.pl \
 --nextprot_mapping_id 2 \
 --protein_file_location /net/db/projects/PeptideAtlas/pipeline/output/Human_UPSP_2014/DATA_FILES --update

EOU


GetOptions(\%OPTIONS,"verbose","help","testonly", "insert","protein_file_location:s",
           "nextprot_mapping_id:i","insertMapping","insertSummary","atlas_build_id:i",
           "update");

if ($OPTIONS{help}){
  print $USAGE;
}

$VERBOSE=$OPTIONS{verbose};
$TESTONLY = $OPTIONS{testonly};
my $insert = $OPTIONS{insert};
my $update = $OPTIONS{update};
my $nextprot_mapping_id = $OPTIONS{nextprot_mapping_id} || '';
my $insertMapping = $OPTIONS{insertMapping} || 0;
my $insertSummary = $OPTIONS{insertSummary} || 0;
my $atlas_build_id = $OPTIONS{atlas_build_id} || '';

my ($sql,$atlas_build_date,$build_path); 

if (! $atlas_build_id){
  $sql = qq~
  SELECT DAB.ATLAS_BUILD_ID , AB.BUILD_DATE, AB.DATA_PATH 
  FROM $TBAT_DEFAULT_ATLAS_BUILD DAB, $TBAT_ATLAS_BUILD AB 
  WHERE DEFAULT_ATLAS_BUILD_ID = 4 
  AND DAB.ATLAS_BUILD_ID = AB.ATLAS_BUILD_ID 
 ~;
}else{
  $sql = qq~
  SELECT AB.ATLAS_BUILD_ID , AB.BUILD_DATE, AB.DATA_PATH
  FROM $TBAT_ATLAS_BUILD AB
  WHERE AB.ATLAS_BUILD_ID = $atlas_build_id 
 ~;

}

my @rows = $sbeams->selectSeveralColumns ($sql);
($atlas_build_id, $atlas_build_date,$build_path) = @{$rows[0]};

print "$atlas_build_id, $atlas_build_date,$build_path\n";

my $msg = $sbeams->update_PA_table_variables($atlas_build_id);

#$build_path = "$build_path/NextProt_SNPs";

#$atlas_build_id = 451;
#$build_path = "/HumanPublic_201511/DATA_FILES/";


my $protein_file_location = $OPTIONS{protein_file_location} || die "need protein file location\n";
print "protein_file_location $protein_file_location\n";

#$atlas_build_date =~ s/(\d+\-\d+)\-.*/$1/;

use File::stat;
my $neXtprot_file_loc = "/net/db/projects/PeptideAtlas/species/Human/NextProt/chr_reports/";
my $ua = LWP::UserAgent->new;
my $host="https://download.nextprot.org/pub/current_release";
my $url = "$host/ac_lists/nextprot_ac_list_all.txt";

my $req = HTTP::Request->new(GET => $url);
my $response = $ua->request($req);

my $localfile = "$neXtprot_file_loc/nextprot_ac_list_all.txt";
open (OUT, ">$localfile") or die "cannot open $localfile\n";
if ($response->is_success){
	print OUT $response->content;
}else{
	die "cannot download $url\n";
}

my $dir="chr_reports";
my @chrs = ();
for my $i (1..22){
  push @chrs, $i;
}
@chrs = (@chrs, 'X', 'Y', 'MT', 'unknown');
foreach my $chr (@chrs){
  my $url = "$host/$dir/nextprot_chromosome_$chr.txt";
  my $localfile = "$neXtprot_file_loc/nextprot_chromosome_$chr.txt";
  open (OUT, ">$localfile") or die "cannot open $localfile\n";
  my $req = HTTP::Request->new(GET => $url);
  $response = $ua->request($req);
  if ($response->is_success){
		print OUT $response->content;
	}else{
		die "cannot download $url\n";
	}
   #utime($time, $time, "$neXtprot_file_loc/$ftp_file");
}

$dir = "mapping";
foreach my $file (qw(nextprot_refseq.txt nextprot_ensg.txt)){
  my $url = "$host/$dir/$file";
  my $localfile = "$neXtprot_file_loc/$file";
  open (OUT, ">$localfile") or die "cannot open $localfile\n";
  my $req = HTTP::Request->new(GET => $url);
  $response = $ua->request($req);
  if ($response->is_success){
    print OUT $response->content;
  }else{
    die "cannot download $url\n";
  }
   #utime($time, $time, "$neXtprot_file_loc/$ftp_file");
}

#nextprot_ac_list_all.txt</a></td><td class="indexcollastmod">2021-11-19
my $str = `wget -S -O- https://download.nextprot.org/pub/current_release/ac_lists/`;
$str =~ /nextprot_ac_list_all.txt.*indexcollastmod">([\d\-]+) /;
my $nextprot_release_date  = $1; 
print "nextprot_release_date=$nextprot_release_date\n";
die if ($nextprot_release_date eq '');

if (! $insert){
  $insert = check_version (nextprot_release_date => $nextprot_release_date, 
                           atlas_build_id => $atlas_build_id);
}

## if there is record for the nextprot_release_date and build_id, no action required. 
if ( ! $update && (! $insert && ! $insertMapping && ! $insertSummary)){
  print "There is a record for the nextprot_release_date $nextprot_release_date and build_id $atlas_build_id already.\n"
        ."If you want to add record still, please use --insert option.\n";
  exit;
}

if ($insert && $nextprot_mapping_id eq ''){
 $nextprot_mapping_id = insert_NeXtProt_Mapping(atlas_build_id => $atlas_build_id,
                                                  nextprot_release_date => $nextprot_release_date);
}

#my @files = `ls /data/seqdb/nextprot/chr_reports/nextprot_chromosome_*.txt`;
my @files = `ls /net/db/projects/PeptideAtlas/species/Human/NextProt/chr_reports/nextprot_chromosome_*.txt`;
my %pe_level = ();
my %pe_mapping = (
  'homology' => 3,
  'predicted' => 4, 
  'protein level' => 1,
  'transcript level' => 2,
  'uncertain' => 5,
);

foreach my $file (@files){
  open (IN, "<$file") or die "cannot open file\n";
  while (my $line = <IN>){
    if ($line !~ /NX_/){
      next;
    }
    chomp $line;
    #my @elm = split(/\t/, $line);
    my @elm = $line =~ /^(\S+)\s{0,}(NX_\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(forward|reverse|\-)\s+(.*)(yes|no)\s+(yes|no)\s+(yes|no)\s+(yes|no)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)$/;
    #for my $i (0..$#elm){
    #  print "$i $elm[$i]\n";
    #}
    my $acc = $elm[1];
    my $level = $elm[6];
    my $chrominfo = $elm[2];
    $level =~ s/\s+$//;
    $level =~ s/^\s+//; 
    $acc =~ s/.*NX_//;
    $acc =~ s/\s+//g;
    $pe_level{$acc} = $pe_mapping{$level};

    my $start = $elm[3];
    my $end = $elm[4];
    if ($start =~ /\D/ || $end =~ /\D/){
      next;
    }
    $file =~ /chromosome_(\w+).txt/;
    my $chr = "$1";
    my $mb = int( $start /1000000);
  }
}

my %bs_name;

my $biosequence_file = "$ENV{PIPELINE}/output/$build_path/Homo_sapiens.fasta";
if ($protein_file_location){
  $biosequence_file = "$protein_file_location/Homo_sapiens.fasta";
}

open (ACC, "<$biosequence_file" ) or die "cannot open $biosequence_file\n";
while (my $line = <ACC>){
  chomp $line;
  next if($line !~ />/);
  if ($line =~ /nP20K/){
    $line =~ />(\S+) .*PE=(\d+)/;
    $pe_level{$1} = $2 if (not defined $pe_level{$1}); 
    $bs_name{$1} = 0;
  }elsif($line =~ /SPnotNP/i){
    $line =~ />(\S+) .*/;
    $bs_name{"sp|$1"} = 0;
  }elsif($line =~ />(CONTAM\_\S+)/){
    $bs_name{"CONTAM|$1"} = 0;
  }elsif($line =~ />(IMGT\_\S+)/){
    $bs_name{"IMGT|$1"} = 0;
  }elsif($line =~ />(DECOY\_\S+)/){
    $bs_name{"DECOY|$1"} = 0;
  }else{
    if ($line !~ /(>gi|>ENSP|Uniprot|nPvarsplic)/){
      $line =~ />(\S+)/;
      $bs_name{"CONTRIB|$1"} = 0;
    }
  }
}

#protein_group_number,reference_biosequence_name,related_biosequence_name,relationship_name
my %releationship = ();
my $paprot_releationship_file = "$protein_file_location/PeptideAtlasInput.PAprotRelationships";
open (R, "<$paprot_releationship_file") or die "cannot open $paprot_releationship_file\n";
while (my $line = <R>){
  chomp $line;
  my ($group, $ref, $prot,$rel) = split(",", $line);
  if ($prot =~ /NX_(\S+)-\d+/){
     $prot = $1;
  }
  if ($ref =~ /NX_(\S+)-\d+/){
     $ref = $1;
  }
  $releationship{$prot}{$rel} = "$rel to $ref";
  $releationship{$ref}{$rel} = "$rel to $prot";
}

#protein_group_number,biosequence_name,probability,
#confidence,n_observations,n_distinct_peptides,level_name,
#represented_by_biosequence_name,subsumed_by_biosequence_name,
#estimated_ng_per_ml,abundance_uncertainty,is_covering,group_size,norm_PSMs_per_100K

my $paprotlist_file = "$protein_file_location/PeptideAtlasInput.PAprotIdentlist";
open (IN, "<$paprotlist_file") or die "cannot open $paprotlist_file\n";

@rows = ();
while (my $line = <IN>){
  my @elms = split(",", $line);
  my $group = $elms[0];
  my $proteins = $elms[1];
  my $level_name = $elms[6];
  my $subsumed_by = $elms[8]; 
  my $ref = $elms[7];
  $level_name =~ s/_/ /g;
  $level_name =~ s/-/ /g; 
  $level_name =~ s/ntt/NTT/g;
  if ($ref =~ /NX_(\S+)\-\d+/){
     $ref = $1;
  }
  
  foreach my $prot (split(/\s+/, $proteins)){
		if ($prot =~ /NX_(\S+)\-\d+/){
			 $prot = $1;
		}
    if ($level_name =~ /subsum/){
      push @rows , [$prot, $level_name,$subsumed_by];
    }else{ 
      push @rows , [$prot, $level_name,$ref];
    }
  }
}

my %present_level = ();
foreach my $row (@rows){
	my ($protein_name, $present_level, $ref) = @$row;
  if ($present_level ne ''){
    if ($present_level =~ /subs/){
        $present_level{$protein_name}{present} = "$present_level by $ref";
    }else{
      $present_level{$protein_name}{present} = $present_level;
    }
  }
} 

$sql = qq~
	SELECT DISTINCT
				 BS.biosequence_name,
				 count (distinct P.peptide_accession),
         sum (PI.n_observations) 
	FROM $TBAT_PEPTIDE_INSTANCE PI
	INNER JOIN $TBAT_PEPTIDE P
				ON ( PI.peptide_id = P.peptide_id )
	LEFT JOIN $TBAT_PEPTIDE_MAPPING PM
				ON ( PI.peptide_instance_id = PM.peptide_instance_id )
	INNER JOIN $TBAT_ATLAS_BUILD AB
				ON ( PI.atlas_build_id = AB.atlas_build_id )
	LEFT JOIN $TBAT_BIOSEQUENCE_SET BSS
				ON ( AB.biosequence_set_id = BSS.biosequence_set_id )
	LEFT JOIN $TB_ORGANISM O
				ON ( BSS.organism_id = O.organism_id )
	LEFT JOIN $TBAT_BIOSEQUENCE BS
				ON ( PM.matched_biosequence_id = BS.biosequence_id )
	WHERE 1 = 1
	AND AB.atlas_build_id IN ($atlas_build_id)
	GROUP BY BS.BIOSEQUENCE_NAME
~;

my %prot_obs = ();
my %pi_obs =();
my @rows = $sbeams->selectSeveralColumns($sql);


foreach my $row (@rows){
  my ($prot, $npep, $nobs) = @$row;
  next if ($prot =~ /DECOY/);
  if ($prot =~ /NX_(\S+)-\d+/){
    $prot = $1;
  }
  next if($prot =~ /CONTA/);
  $prot =~ s/.*\|//;
  $prot_obs{$prot} = $npep;
  $pi_obs{$prot} = $nobs;
}

my $space = 118;
my %hash = ();
my %summary = ();
my %summary_PE =();


foreach my $file (@files){
  chomp $file;
  print "$file\n";
  $file =~ /chromosome_(\w+).txt/;
  my $chr = "Chromosome $1";
  if ($chr =~ /unknow/i){
    $chr = "Chromosome ?";
  }

  open (IN, "<$file") or die "cannot open file\n";
  while (my $line = <IN>){
		if ($line !~ /NX_/){
			next;
		}
		chomp $line;
	  my @m = $line =~ /^(\S+)\s{0,}(NX_\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(forward|reverse|\-)\s+(.*)(yes|no)\s+(yes|no)\s+(yes|no)\s+(yes|no)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)$/;
		my $gene = $m[0];
 		my $nextprot = $m[1];
    $nextprot =~ s/NX_//; 
    $bs_name{$nextprot} = 1;
    my $pe_level = $pe_level{$nextprot} || '?';
    $summary{$chr}{'neXtProt entries'}{$nextprot}++;
    $summary_PE{$pe_level}{'neXtProt entries'}{$nextprot}++;
    $summary_PE{'Total'}{'neXtProt entries'}{$nextprot}++;
    my $str =  $prot_obs{$nextprot};
    $chr =~ /.*\s+(.*)/;
    my $chr_num = $1;
		if (defined $prot_obs{$nextprot}){
			if (defined $present_level{$nextprot}){
				if (defined $present_level{$nextprot}{present}){
					 $str = "$present_level{$nextprot}{present}\t$str";
					 my $level =  $present_level{$nextprot}{present} ;
					 $level =~ s/(into|to|by).*//;
					 if ($level =~ /canoni/i){
						 $summary{$chr}{$level}{$nextprot}=1;
             $summary_PE{$pe_level}{$level}{$nextprot}=1;
             $summary_PE{'Total'}{$level}{$nextprot}=1;
					 }elsif($level =~ /subsumed/i){
						 $summary{$chr}{'Redundant relationship'}{$nextprot}=1;
             $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
             $summary_PE{'Total'}{'Redundant relationship'}{$nextprot}=1;
           }elsif($level =~ /rejected/i){
             $summary{$chr}{'Not Observed'}{$nextprot}=1;
             $summary_PE{$pe_level}{'Not Observed'}{$nextprot}=1;
             $summary_PE{'Total'}{'Not Observed'}{$nextprot}=1;

           }else{## indistinguishable representative, insufficient evidence, marginally distinguished, weak
             $summary{$chr}{'uncertain'}{$nextprot}=1;
             $summary_PE{$pe_level}{'uncertain'}{$nextprot}=1;
             $summary_PE{'Total'}{'uncertain'}{$nextprot}=1;
					 }
				}
			}elsif(defined $releationship{$nextprot}{indistinguishable}){
					$str = "$releationship{$nextprot}{indistinguishable}\t$str";
					$summary{$chr}{'Redundant relationship'}{$nextprot}=1;
          $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
          $summary_PE{'Total'}{'Redundant relationship'}{$nextprot}=1;
			}elsif(defined $releationship{$nextprot}{identical}){
					$str = "$releationship{$nextprot}{identical}\t$str";
					$summary{$chr}{'Redundant relationship'}{$nextprot}=1;
          $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
          $summary_PE{'Total'}{'Redundant relationship'}{$nextprot}=1;

			}else{
				 $str = "not observed\t$str";
        $summary{$chr}{'Not Observed'}{$nextprot}=1;
        $summary_PE{$pe_level}{'Not Observed'}{$nextprot}=1;
        $summary_PE{'Total'}{'Not Observed'}{$nextprot}=1;
			}
		}else{
				$summary{$chr}{'Not Observed'}{$nextprot}=1;
        $summary_PE{$pe_level}{'Not Observed'}{$nextprot}=1;
        $summary_PE{'Total'}{'Not Observed'}{$nextprot}=1;
				$str = "not observed\t0";
		}
    if ($line =~ /([qp][\d\.]+)(\s+-\s+)([qp][\d\.]+)/){
       my $pre = $1;
       my $s = $2;
       my $fol = $3;
       $line =~ s/$pre$s$fol/$pre-$fol/;
    }
    if ($line =~ /unknownq32.2130146082/){
      $line =~ s/unknownq32.2130146082/unknownq32.21 30146082/;
    }
    $m[6] =~ s/\s+$//;
 
    if ($m[2] =~ /unknown/i  || $m[2] !~ /[1-22XYMT]/  ){
			$file =~ /chromosome_(\S+).txt/;
			$m[2] = $1;
			if ($m[2] =~ /unknown/i){
				$m[2] = "NA";
			}
    }
    $m[2] =~ s/\s+//g; 

    my $new_line = join("\t", @m);
    if($str){
      $new_line .= "\t$str"; 
    }else{
      $new_line .= "\t\t\t";
    }
    push @{$hash{$nextprot}{line}},$new_line;
    $hash{$nextprot}{cnt}++;

	}
}
foreach my $nextprot (keys %bs_name){
    my $newline = '';
    my $level='';
    my $pe_level = $pe_level{$nextprot} || '?';
    next if($nextprot !~ /^(sp|DECOY|CONTAM|CONTRIB|IMGT)/);
    $nextprot =~ /(\w+)\|(.*)/;
    my $prot = $2;
    my $tag = $1;
    
    $summary_PE{$tag}{'neXtProt entries'}{$prot}++;
			if (defined $prot_obs{$prot}){
				if (defined $present_level{$prot}){
					if (defined $present_level{$prot}{present}){
						 $level =  $present_level{$prot}{present} ;
						 $level =~ s/(to|by).*//;
						 if ($level =~ /(canoni)/){
							 $summary_PE{$tag}{$level}{$prot}=1;
						 }elsif($level =~ /(distinguish|weak|insufficient)/){
               $summary_PE{$tag}{uncertain}{$prot}=1;
             }else{
							 $summary_PE{$tag}{'Redundant relationship'}{$prot}=1;
						 }
					}
				}elsif(defined $releationship{$prot}{indistinguishable}){
					 $summary_PE{$tag}{'Redundant relationship'}{$prot}=1;
				}elsif(defined $releationship{$prot}{identical}){
					 $summary_PE{$tag}{'Redundant relationship'}{$prot}=1;
				}else{
					 $summary_PE{$tag}{'Not Observed'}{$prot}=1;
				}
			}else{
				 $summary_PE{$tag}{'Not Observed'}{$prot}=1;
			}
}


## reading protein mapping files 
my %mapping = ();
my $file = "/net/db/projects/PeptideAtlas/species/Human/NextProt/chr_reports/nextprot_refseq.txt";
get_mapping ( 'f' => $file , 'mapping' => \%mapping, 'type' => 'REFSEQ');

$file =  "/net/db/projects/PeptideAtlas/species/Human/NextProt/chr_reports/nextprot_ensg.txt";
get_mapping ( 'f' => $file , 'mapping' => \%mapping, 'type' => 'ENSEMBL');

foreach my $nextprot(keys %hash){
  foreach (@{$hash{$nextprot}{line}}){
		my @elms = split("\t", $_);
    my $chr =  $elms[2];
    $chr =~ s/[pq].*//;
    if ($chr eq 'NA'){
      $chr = '?';
    }
    my $chr = 'Chromosome ' .$chr;
    $_ .= "\t$mapping{$nextprot}{ENSEMBL}\t$mapping{$nextprot}{REFSEQ}\t$hash{$nextprot}{cnt}";
    
  }
}

if ( ($update && $nextprot_mapping_id) || ($insertMapping && $nextprot_mapping_id) || ($insert && $nextprot_mapping_id)){
  insert_NeXtProt_Chromosome_Mapping (
                                    update => $update,
 																		chromosome_mapping  => \%hash,
                                    nextprot_mapping_id => $nextprot_mapping_id,
                                   );
}
if (($update && $nextprot_mapping_id) || (($insertSummary && $nextprot_mapping_id) || ($insert && $nextprot_mapping_id))){
  insert_NeXtProt_CHPP_Summary (
                                  update => $update,
                                  summary => \%summary, 
                                  summary_PE => \%summary_PE,
                                  nextprot_mapping_id => $nextprot_mapping_id, 
                                  nextprot_release_date => $nextprot_release_date,
                                  #atlas_build_date => $atlas_build_date, 
                                   );
#  foreach my $key1 (sort {$a cmp $b} %summary_PE){
#    print "$key1,";
#    foreach my $key2 (keys %{$summary_PE{$key1}}){
#      my $n = scalar keys %{$summary_PE{$key1}{$key2}};
#      print "$key2=$n,";
#    }
#    print "\n";
#  }

}


exit;

####################################################################################
sub check_version {
  my %args = @_;
  my $nextprot_release_date = $args{nextprot_release_date};
  my $atlas_build_id = $args{atlas_build_id};

  my $sql = qq~
   SELECT ID 
   FROM $TBAT_NEXTPROT_MAPPING 
   WHERE ATLAS_BUILD_ID = $atlas_build_id
   AND NEXTPROT_RELEASE_DATE = '$nextprot_release_date'
 ~;
  my @rows = $sbeams->selectOneColumn($sql);
  if (@rows){
    return 0;
  }else{
    return 1;
  }
} 

sub get_mapping {
  my %args = @_;
  my $file = $args{ 'f'};
  my $mapping = $args{'mapping'};
  my $type = $args{'type'};
  if ( -e "$file"){
    open (F , "<$file") or die "cannot open $file\n";
    while (my $line = <F>){
      $line =~ /NX_(\w+)\s+(\w+)/; 
      $mapping{$1}{$type} = $2;
    }
    close F;
  }
}

sub insert_NeXtProt_CHPP_Summary {
  my %args = @_;
  my $update = $args{update} || 0;
  my $summary = $args{summary};
  my $summary_PE = $args{summary_PE};
  my $nextprot_mapping_id = $args{nextprot_mapping_id};
  my $nextprot_release_date = $args{nextprot_release_date};
  #my $atlas_build_date = $args{atlas_build_date};

	foreach my $m (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,'X','Y','MT','?'){
		my $chr = "Chromosome $m";
		my %rowdata = (
			chromosome => $m, 
			n_nextprot_entries => scalar keys %{$summary{$chr}{'neXtProt entries'}}, 
			n_canonical => scalar keys %{$summary{$chr}{'canonical'}},
			n_uncertain => scalar keys %{$summary{$chr}{'uncertain'}},
			n_redundant  => scalar keys %{$summary{$chr}{'Redundant relationship'}},
			n_not_observed => scalar keys %{$summary{$chr}{'Not Observed'}},
			NeXtProt_Mapping_id => $nextprot_mapping_id,
		);
		my $id = '';
    if($update){
      update_summary_table (rowdata_ref => \%rowdata);
    }else{
      insert_table (rowdata_ref => \%rowdata);
    }
  }
  foreach my $m (qw (1 2 3 4 5 Total sp IMGT CONTAM CONTRIB DECOY )){
		my $n = scalar keys %{$summary_PE{$m}{'neXtProt entries'}};
		next if ($n == 0);
    my %rowdata = (
      PE => $m,
      n_nextprot_entries => scalar keys %{$summary_PE{$m}{'neXtProt entries'}},
      n_canonical => scalar keys %{$summary_PE{$m}{'canonical'}},
      n_uncertain => scalar keys %{$summary_PE{$m}{'uncertain'}},
      n_redundant  => scalar keys %{$summary_PE{$m}{'Redundant relationship'}},
      n_not_observed => scalar keys %{$summary_PE{$m}{'Not Observed'}},
      NeXtProt_Mapping_id => $nextprot_mapping_id,
    );
    if($update){
      update_summary_table (rowdata_ref => \%rowdata);
    }else{
      insert_table (rowdata_ref => \%rowdata);
    }
	}
}

sub update_summary_table {
  my %args = @_;
  my $rowdata_ref = $args{rowdata_ref};
  my $sql;
  my $nextprot_mapping_id = $rowdata_ref->{NeXtProt_Mapping_id};
  my ($pe, $chr);
  if (defined $rowdata_ref->{PE}){
    $pe = $rowdata_ref->{PE};
    $sql = qq~
      SELECT ID
      FROM $TBAT_NEXTPROT_CHPP_SUMMARY 
      WHERE NEXTPROT_MAPPING_ID = $nextprot_mapping_id 
      AND PE='$pe'
    ~;
  }else{
    $chr = $rowdata_ref->{chromosome};
    $sql = qq~
      SELECT ID
      FROM $TBAT_NEXTPROT_CHPP_SUMMARY
      WHERE NEXTPROT_MAPPING_ID = $nextprot_mapping_id
      AND chromosome='$chr'
    ~;
  }

  my @results = $sbeams->selectOneColumn($sql);
  if(@results == 1){
   my $msg = $sbeams->updateOrInsertRow(
    update =>1,
    table_name =>$TBAT_NEXTPROT_CHPP_SUMMARY,
    rowdata_ref=>$rowdata_ref,
    PK => 'id',
    return_PK => 1,
    PK_value => $results[0],
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
   );
  }elsif(@results == 0){
   my $msg = $sbeams->updateOrInsertRow(
    insert =>1,
    table_name =>$TBAT_NEXTPROT_CHPP_SUMMARY,
    rowdata_ref=>$rowdata_ref,
    PK => 'id',
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
   );
  }else{
    print "ERROR: ";
    print scalar @results ;
    print " result(s) for nextprot_mapping_id=$nextprot_mapping_id PE/CHR=$pe/$chr\n"; 
  }
}


sub insert_table { 
  my %args = @_;
  my $rowdata_ref = $args{rowdata_ref}; 
	 my $pk_id = $sbeams->updateOrInsertRow(
		insert =>1,
		table_name =>$TBAT_NEXTPROT_CHPP_SUMMARY,
		rowdata_ref=>$rowdata_ref,
		PK => 'id',
		return_PK => 1,
		verbose=>$VERBOSE,
		testonly=>$TESTONLY,
	 );
}

sub insert_NeXtProt_Chromosome_Mapping{
  my %args = @_;
  my $chromosome_mapping = $args{chromosome_mapping};
  my $nextprot_mapping_id = $args{nextprot_mapping_id};
  my $update = $args{update} || 0;

  foreach my $prot(keys %$chromosome_mapping){
    foreach my $line (@{$chromosome_mapping->{$prot}{line}}){
			my ($Gene_Name,
				$neXtProt_Accession,
				$Chromosome,
				$Start,
				$Stop,
        $coding_strand,
				$Protein_existence,
				$Proteomics,
				$AntiBody,
				$ThreeD,
				$Disease,
				$Isoforms,
				$Variants,
				$PTMs,
				$Description,
				$PeptideAtlas_Category,
				$n_obs,
				$Ensembl_Accession,
				$RefSeq_Accession,
				$n_neXtProt_entry) = split(/\t/, $line);
      $neXtProt_Accession =~ s/^NX_//;
			my %rowdata = (
				neXtProt_Accession => $neXtProt_Accession,
        Gene_Name => $Gene_Name,
				Chromosome => $Chromosome,
				Start => $Start,
				Stop => $Stop,
				Protein_existence => $Protein_existence,
				Proteomics => $Proteomics,
				AntiBody => $AntiBody,
				ThreeD => $ThreeD,
				Disease => $Disease,
				Isoforms => $Isoforms,
				Variants => $Variants,
				PTMs => $PTMs,
				Description => $Description,
				PeptideAtlas_Category => $PeptideAtlas_Category,
				n_obs => $n_obs,
				Ensembl_Accession => $Ensembl_Accession,
				RefSeq_Accession => $RefSeq_Accession,
				n_neXtProt_entry => $n_neXtProt_entry,
        NeXtProt_Mapping_id => $nextprot_mapping_id,
	  	);
     if ( ! $update){
			 my $pk_id = $sbeams->updateOrInsertRow(
					insert =>1,
					table_name =>$TBAT_NEXTPROT_CHROMOSOME_MAPPING,
					rowdata_ref=>\%rowdata,
					PK => 'id',
					return_PK => 1,
					verbose=>$VERBOSE,
					testonly=>$TESTONLY,
			);
    }else{
      if ($Start eq '-'){
        $Start = 0;
      }
      if ($Stop eq '-'){
        $Stop = 0;
      }

      my $sql = qq~
        SELECT ID 
        FROM $TBAT_NEXTPROT_CHROMOSOME_MAPPING
        WHERE NEXTPROT_ACCESSION='$neXtProt_Accession'
        AND CHROMOSOME LIKE '$Chromosome'
        AND NEXTPROT_MAPPING_ID = $nextprot_mapping_id
        AND START = $Start
        AND STOP = $Stop 
      ~;
      my @results = $sbeams->selectOneColumn($sql);
			if(@results >= 1){
        foreach my $id (@results){
					 my $msg = $sbeams->updateOrInsertRow(
						update =>1,
						table_name =>$TBAT_NEXTPROT_CHROMOSOME_MAPPING,
						rowdata_ref=>\%rowdata,
						PK => 'id',
						PK_value => $id,
						return_PK => 1,
						verbose=>$VERBOSE,
						testonly=>$TESTONLY,
					 );
         }
			}else{
				 my $msg = $sbeams->updateOrInsertRow(
					insert =>1,
					table_name =>$TBAT_NEXTPROT_CHROMOSOME_MAPPING,
					rowdata_ref=>\%rowdata,
					PK => 'id',
					return_PK => 1,
					verbose=>$VERBOSE,
					testonly=>$TESTONLY,
				 );
      }
    }
   }
  }
}

sub insert_NeXtProt_Mapping {
  my %args = @_;
  my $atlas_build_id = $args{atlas_build_id};
  my $nextprot_release_date = $args{nextprot_release_date};

	my %rowdata = (
		atlas_build_id => $atlas_build_id,
		pa_mapping_date => 'CURRENT_TIMESTAMP', 
		nextprot_release_date => $nextprot_release_date,
    is_public => 'N',
    record_status => 'N'
	);
	my $pk_id = $sbeams->updateOrInsertRow(
			insert =>1,
			table_name=>$TBAT_NEXTPROT_MAPPING,
			rowdata_ref=>\%rowdata,
			PK => 'id',
			return_PK => 1,
			verbose=>$VERBOSE,
			testonly=>$TESTONLY,
	);
  
  return $pk_id;
}
