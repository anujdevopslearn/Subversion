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
use Net::FTP;
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
EOU


GetOptions(\%OPTIONS,"verbose","help","testonly", "insert");

if ($OPTIONS{help}){
  print $USAGE;
}

$VERBOSE=$OPTIONS{verbose};
$TESTONLY = $OPTIONS{testonly};
my $insert = $OPTIONS{insert};

my $sql = qq~
  SELECT DAB.ATLAS_BUILD_ID , AB.BUILD_DATE, AB.DATA_PATH 
  FROM $TBAT_DEFAULT_ATLAS_BUILD DAB, $TBAT_ATLAS_BUILD AB 
  WHERE DEFAULT_ATLAS_BUILD_ID = 4 
  AND DAB.ATLAS_BUILD_ID = AB.ATLAS_BUILD_ID 
 ~;

my @rows = $sbeams->selectSeveralColumns ($sql);
my ($atlas_build_id, $atlas_build_date,$build_path) = @{$rows[0]};

$build_path = "$build_path/NextProt_SNPs";
#$build_path = "/net/db/projects/PeptideAtlas/pipeline/AtlasProphet/2015-08-10";

$atlas_build_date =~ s/(\d+\-\d+)\-.*/$1/;

use File::stat;
use POSIX qw(strftime);
my $mtime = stat("/data/seqdb/nextprot/chr_reports/nextprot_chromosome_1.txt")->mtime;
my @time = localtime($mtime);
my $nextprot_release_date  = strftime "%Y-%m-%d", @time;

if (! $insert){
  $insert = check_version (nextprot_release_date => $nextprot_release_date, 
                           atlas_build_id => $atlas_build_id);
}

## if there is record for the nextprot_release_date and build_id, no action required. 
if ( ! $insert){
  print "There is a record for the nextprot_release_date $nextprot_release_date and build_id $atlas_build_id already.\n"
        ."If you want to add record still, please use --insert option.\n";
  exit;
}


my $acc_file = "/net/db/projects/PeptideAtlas/species/Human/NextProt/chr_reports/nextprot_ac_list_all.txt";
my ($host, $user, $passwd) = ('ftp.nextprot.org', 'anonymous', '');
my $dir = 'pub/current_release/ac_lists/';
my $ftp = Net::FTP->new($host) or die qq{Cannot connect to $host: $@};
$ftp->login($user, $passwd) or die qq{Cannot login: }, $ftp->message;
$ftp->cwd($dir) or die qq{Cannot cwd to $dir: }, $ftp->message;
$ftp->get('nextprot_ac_list_all.txt', $acc_file); 

my $nextprot_mapping_id = insert_NeXtProt_Mapping(atlas_build_id => $atlas_build_id,
                                                  nextprot_release_date => $nextprot_release_date);


my @files = `ls /data/seqdb/nextprot/chr_reports/nextprot_chromosome_*.txt`;
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
    my @elm = split(/\t/, $line);
    my $acc = $elm[0];
    my $level = $elm[2];
    my $chrominfo = $elm[1];
    my $name = $elm[8];
    $level =~ s/\s+$//;
    $level =~ s/^\s+//; 
    $acc =~ s/.*NX_//;
    $acc =~ s/\s+//g;
    $pe_level{$acc} = $pe_mapping{$level};
    my ($chr,$start,$end) = split(/\s+/, $chrominfo);
    if ($start =~ /\D/ || $end =~ /\D/){
      next;
    }
    $file =~ /chromosome_(\w+).txt/;
    $chr = "$1";
    my $mb = int( $start /1000000);
  }
}

my %bs_name;
my $biosequence_file = "/net/db/projects/PeptideAtlas/pipeline/output/$build_path/Homo_sapiens.fasta";
open (ACC, "<$biosequence_file" ) or die "cannot open $biosequence_file\n";
while (my $line = <ACC>){
  chomp $line;
  if ($line =~ />NX_(\S+).*/){
    my $acc = $1;
    if($acc =~ /NX_(\w+)\-\d+/){
      $bs_name{$1} = 0; 
    }else{
      if ($line =~ />sp.*PE=(\d+).*/){
         $pe_level{$acc} = $1;
         $bs_name{$acc} = 0;
      }
    }
  }elsif($line =~ />(sp\S+)/){
    $bs_name{$1} = 0;
  }
}

#protein_group_number,reference_biosequence_name,related_biosequence_name,relationship_name
my %releationship = ();
my $paprot_releationship_file = "/net/db/projects/PeptideAtlas/pipeline/output/$build_path/PeptideAtlasInput.PAprotRelationships";
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

my $paprotlist_file = "/net/db/projects/PeptideAtlas/pipeline/output/$build_path/PeptideAtlasInput.PAprotIdentlist";
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
	LEFT JOIN sbeams.dbo.organism O
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
		my @elm = split(/\t/, $line);
		$elm[0] =~ /(\S+)\s+NX_(\S+)/;
		my $gene = $1;
 		my $nextprot = $2;
    $bs_name{$nextprot} = 1;
    my $pe_level = $pe_level{$nextprot} || '?';
    $summary{$chr}{'neXtProt entries'}{$nextprot}++;
    $summary_PE{$pe_level}{'neXtProt entries'}{$nextprot}++;
    my $str =  $prot_obs{$nextprot};
    $chr =~ /.*\s+(.*)/;
    my $chr_num = $1;
		if (defined $prot_obs{$nextprot}){
			if (defined $present_level{$nextprot}){
				if (defined $present_level{$nextprot}{present}){
					 $str = "$present_level{$nextprot}{present}\t$str";
					 my $level =  $present_level{$nextprot}{present} ;
					 $level =~ s/(to|by).*//;
					 if ($level =~ /canoni/){
						 $summary{$chr}{$level}{$nextprot}=1;
             $summary_PE{$pe_level}{$level}{$nextprot}=1;
					 }elsif($level =~ /(distinguish|weak|insufficient)/){
             $summary{$chr}{'uncertain'}{$nextprot}=1;
             $summary_PE{$pe_level}{'uncertain'}{$nextprot}=1;
           }else{
						 $summary{$chr}{'Redundant relationship'}{$nextprot}=1;
             $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
					 }
				}
			}elsif(defined $releationship{$nextprot}{indistinguishable}){
					$str = "$releationship{$nextprot}{indistinguishable}\t$str";
					$summary{$chr}{'Redundant relationship'}{$nextprot}=1;
          $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
			}elsif(defined $releationship{$nextprot}{identical}){
					$str = "$releationship{$nextprot}{identical}\t$str";
					$summary{$chr}{'Redundant relationship'}{$nextprot}=1;
          $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
			}else{
				 $str = "not observed\t0";
			}
		}else{
				$summary{$chr}{'Not Observed'}{$nextprot}=1;
        $summary_PE{$pe_level}{'Not Observed'}{$nextprot}=1;
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
		my @m = $line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)(yes|no)\s+(yes|no)\s+(yes|no)\s+(yes|no)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*)$/;
    $m[5] =~ s/\s+$//;
 
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
  if ($bs_name{$nextprot} == 0){
    my $newline = '';
    my $level='';
    my $pe_level = $pe_level{$nextprot} || '?';
    if($nextprot !~ /^sp/){
      $summary{'Chromosome ?'}{'neXtProt entries'}{$nextprot}++;
      $summary_PE{$pe_level}{'neXtProt entries'}{$nextprot}++;
			if (defined $prot_obs{$nextprot}){
				if (defined $present_level{$nextprot}){
					if (defined $present_level{$nextprot}{present}){
						 $level =  $present_level{$nextprot}{present} ;
						 $level =~ s/(to|by).*//;
						 if ($level =~ /(canoni)/){
							 $summary{'Chromosome ?'}{$level}{$nextprot}=1;
							 $summary_PE{$pe_level}{$level}{$nextprot}=1;
						 }elsif($level =~ /(distinguish|weak|insufficient)/){
               $summary{'Chromosome ?'}{uncertain}{$nextprot}=1;
               $summary_PE{$pe_level}{uncertain}{$nextprot}=1;
             }else{
							 $summary{'Chromosome ?'}{'Redundant relationship'}{$nextprot}=1;
							 $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
						 }
					}
				}elsif(defined $releationship{$nextprot}{indistinguishable}){
					 $summary{'Chromosome ?'}{'Redundant relationship'}{$nextprot}=1;
					 $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
					 $level='indistinguishable';
				}elsif(defined $releationship{$nextprot}{identical}){
					 $summary{'Chromosome ?'}{'Redundant relationship'}{$nextprot}=1;
					 $summary_PE{$pe_level}{'Redundant relationship'}{$nextprot}=1;
					 $level='identical';
				}else{
					 $summary{'Chromosome ?'}{'Not Observed'}{$nextprot}=1;
					 $summary_PE{$pe_level}{'Not Observed'}{$nextprot}=1;
					 $level = 'Not Observed';
				}
				$newline = "\tNX_$nextprot\tNA\t\t\t\t\t\t\t\t\t\t\t$level\t$prot_obs{$nextprot}\t ";
			}else{
				 $summary{'Chromosome ?'}{'Not Observed'}{$nextprot}=1;
				 $summary_PE{$pe_level}{'Not Observed'}{$nextprot}=1;
				 $level = 'Not Observed';
				 $newline = "\tNX_$nextprot\tNA\t\t\t\t\t\t\t\t\t\t\t$level\t0\t ";
			}
			push @{$hash{$nextprot}{line}},$newline;
		}else{
      $summary_PE{sp}{'neXtProt entries'}{$nextprot}++;
      my $prot = $nextprot;
      $prot =~ s/.*\|//;
			if (defined $prot_obs{$prot}){
				if (defined $present_level{$nextprot}){
					if (defined $present_level{$nextprot}{present}){
						 $level =  $present_level{$nextprot}{present} ;
						 $level =~ s/(to|by).*//;
						 if ($level =~ /(canoni)/){
							 $summary_PE{sp}{$level}{$nextprot}=1;
						 }elsif($level =~ /(distinguish|weak|insufficient)/){
               $summary_PE{sp}{uncertain}{$nextprot}=1;
             }else{
							 $summary_PE{sp}{'Redundant relationship'}{$nextprot}=1;
						 }
					}
				}elsif(defined $releationship{$nextprot}{indistinguishable}){
					 $summary_PE{sp}{'Redundant relationship'}{$nextprot}=1;
				}elsif(defined $releationship{$nextprot}{identical}){
					 $summary_PE{sp}{'Redundant relationship'}{$nextprot}=1;
				}else{
					 $summary_PE{sp}{'Not Observed'}{$nextprot}=1;
				}
			}else{
				 $summary_PE{sp}{'Not Observed'}{$nextprot}=1;
			}
		}
  }
}


## reading protein mapping files 
my %mapping = ();
my $file = "/data/seqdb/nextprot/mapping/nextprot_refseq.txt";
get_mapping ( 'f' => $file , 'mapping' => \%mapping, 'type' => 'REFSEQ');

$file =  "/data/seqdb/nextprot/mapping/nextprot_ensg.txt";
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

insert_NeXtProt_Chromosome_Mapping (
																		chromosome_mapping  => \%hash,
                                    nextprot_mapping_id => $nextprot_mapping_id,
                                   );

insert_NeXtProt_CHPP_Summary (
                                  summary => \%summary, 
                                  summary_PE => \%summary_PE,
                                  nextprot_mapping_id => $nextprot_mapping_id,
                                  nextprot_release_date => $nextprot_release_date,
                                  atlas_build_date => $atlas_build_date, 
                                   );



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
  my $summary = $args{summary};
  my $summary_PE = $args{summary_PE};
  my $nextprot_mapping_id = $args{nextprot_mapping_id};
  my $nextprot_release_date = $args{nextprot_release_date};
  my $atlas_build_date = $args{atlas_build_date};

  my $output_path = "/net/db/projects/PeptideAtlas/species/Human/NextProt";
  open (S, ">$output_path/PA_C-HPP_SummaryTable.xls") or die "cannot open PA_C-HPP_SummaryTable.xls\n";
  open (P, ">$output_path/PA_C-HPP_SummaryTable_PE.xls") or die "cannot open PA_C-HPP_SummaryTable_PE.xls\n";

 
print S qq~
<p  class="justifiedtext">
Results based on: <br>
- neXtProt downloaded $nextprot_release_date <br>
- PeptideAtlas Build $atlas_build_date <br><br>
~;

  print S "\nChromosome\tneXtProt entries\tCanonical\t%\t".
        "Uncertain\t%\t".
        "Redundant\t%".
        "\tNot Observed\t%\n";#\tNot in SwissProt DB\t%\n";

 
	foreach my $m (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,'X','Y','MT','?'){
		my $chr = "Chromosome $m";
    my $n = scalar keys %{$summary{$chr}{'neXtProt entries'}};
		print S "Chr$m\t$n\t";
		foreach my $c ('canonical','uncertain','Redundant relationship','Not Observed'){ #, 'Not in SwissProt DB') {
			if (defined $summary{$chr}{$c}){
				my $i = scalar keys %{$summary{$chr}{$c}};
				my $j = sprintf("%.1f%", ($i/$n)*100) ;
				print S "$i\t$j\t";
			}else{
				print S "0\t0.0%\t";
			}
		}
    print S "\n";

		my %rowdata = (
			chromosome => $m, 
			n_nextprot_entries => scalar keys %{$summary{$chr}{'neXtProt entries'}}, 
			n_canonical => scalar keys %{$summary{$chr}{'canonical'}},
			n_possibly_distinguished => scalar keys %{$summary{$chr}{'uncertain'}},
			n_redundant  => scalar keys %{$summary{$chr}{'Redundant relationship'}},
			n_not_observed => scalar keys %{$summary{$chr}{'Not Observed'}},
			NeXtProt_Mapping_id => $nextprot_mapping_id,
		);
		my $id = '';
    insert_table (rowdata_ref => \%rowdata);
  }


  print P "PE\tneXtProt entries\tCanonical\t%\t".
        "Uncertain\t%\t".
        "Redundant\t%".
        "\tNot Observed\t%\n";#\tNot in SwissProt DB\t%\n";

	#foreach my $m (qw (1 2 3 4 5 sp ?)){ 
  foreach my $m (qw (1 2 3 4 5 sp)){
		my $n = scalar keys %{$summary_PE{$m}{'neXtProt entries'}};
		next if ($n == 0);
		#$nNextProt_all += $n;
		print P "$m\t$n\t";
		foreach my $c ('canonical','uncertain','Redundant relationship','Not Observed'){ #, 'Not in SwissProt DB') {
			if (defined $summary_PE{$m}{$c}){
				my $i = scalar keys %{$summary_PE{$m}{$c}};
				my $j = sprintf("%.1f%", ($i/$n)*100) ;
				print P "$i\t$j\t";
			}else{
				print P "0\t0.0%\t";
			}
		}
		print P "\n";

    my %rowdata = (
      PE => $m,
      n_nextprot_entries => scalar keys %{$summary_PE{$m}{'neXtProt entries'}},
      n_canonical => scalar keys %{$summary_PE{$m}{'canonical'}},
      n_possibly_distinguished => scalar keys %{$summary_PE{$m}{'uncertain'}},
      n_redundant  => scalar keys %{$summary_PE{$m}{'Redundant relationship'}},
      n_not_observed => scalar keys %{$summary_PE{$m}{'Not Observed'}},
      NeXtProt_Mapping_id => $nextprot_mapping_id,
    );
    insert_table (rowdata_ref => \%rowdata);
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
  foreach my $prot(keys %$chromosome_mapping){
    foreach my $line (@{$chromosome_mapping->{$prot}{line}}){
			my ($Gene_Name,
				$neXtProt_Accession,
				$Chromosome,
				$Start,
				$Stop,
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
     my $pk_id = $sbeams->updateOrInsertRow(
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

sub insert_NeXtProt_Mapping {
  my %args = @_;
  my $atlas_build_id = $args{atlas_build_id};
  my $nextprot_release_date = $args{nextprot_release_date};

	my %rowdata = (
		atlas_build_id => $atlas_build_id,
		pa_mapping_date => 'CURRENT_TIMESTAMP', 
		nextprot_release_date => $nextprot_release_date
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
