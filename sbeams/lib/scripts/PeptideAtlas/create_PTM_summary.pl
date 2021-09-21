#!/usr/local/bin/perl 

use strict;
use Getopt::Long;
use Storable qw(nstore retrieve);
use lib( "/net/db/projects/PeptideAtlas/pipeline/bin/lib" );
use FAlite;
use FindBin;
$|++;

use lib "$ENV{SBEAMS}/lib/perl/";
use vars qw ($sbeams $sbeamsMOD $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG 
             $TABLE_NAME ); 

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$sbeams = new SBEAMS::Connection;


use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --ptm_build_path   build path for ptm enriched dataset
  --fasta                
  --non-enrichment_list  experiment list for non-enrichment dataset
  --build_path           build path for all data
  --ptm_type             STY:79.9663/K:42.0106  

 e.g.:  $PROG_NAME \\
     --ptm_build_path DATA_FILES/ \\
     --fasta DATA_FILES/Arabidopsis.fasta \\
     --non-enrichment_list Experiments_2021-01_no_phospho.list \\
     --build_path DATA_FILES/

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"ptm_build_path|p:s",
  "fasta|f:s", "non-enrichment_list|n:s","build_path|b:s","ptm_type:s")) {
  print "$USAGE";
  exit;
}


my $buildpath = $OPTIONS{ptm_build_path} || die $USAGE;
my $fastafile = $OPTIONS{fasta} || die $USAGE;
my $unenriched_list = $OPTIONS{"non-enrichment_list"} || die $USAGE;
my $HsPA_buildpath = $OPTIONS{build_path} || die $USAGE;
my $ptm_type = $OPTIONS{ptm_type} || die $USAGE;
my $ptm_residue = $ptm_type;
$ptm_residue =~ s/:.*//;

main();
exit;

###############################################################################
sub main {

  my $PeptideMappingFile = "$buildpath/HsPA-HsPhos_peptide_mapping.tsv";
  my $PAIdentlistFile  = "$buildpath/PeptideAtlasInput_concat.PAidentlist";
  my $PAIdentlistFile_all = "$buildpath/PeptideAtlasInput_concat.PAidentlist-all";
  my $HsPA_PAIdentlistFile = "$HsPA_buildpath/PeptideAtlasInput_concat.PAidentlist";
  my $ext_list = "$buildpath/../Experiments.list";
 
  my %non_enriched_list = ();
  my %enriched_list = ();
  if (! -e $PAIdentlistFile_all ){
    print "WARNING: $PAIdentlistFile_all not found, will use $buildpath/PeptideAtlasInput_concat.PAidentlist file\n";
    print "Please stop job if the file is not correct\n";
    $PAIdentlistFile_all = "$buildpath/PeptideAtlasInput_concat.PAidentlist";

  }
  if ( ! -e "$PeptideMappingFile"){
    print "WARNING: $PeptideMappingFile not found, will use $buildpath/peptide_mapping.tsv file\n";
    print "Please stop job if the file is not correct\n";
    $PeptideMappingFile = "$buildpath/peptide_mapping.tsv";
  }

  open (IN, "<$unenriched_list") or die "cannot open $unenriched_list file\n";
  while (my $line = <IN>){
    chomp $line;
    next if ($line =~ /^#/);
    next if($line =~ /^$/);
    next if($line =~ /^PXD/);
    my ($id , $dir) = split("\t", $line);
    $non_enriched_list{$id} =1;
  }
  open (E, "<$ext_list") or die "cannot open $ext_list file\n";
  while (my $line = <E>){
    chomp $line;
    next if ($line =~ /^#/);
    next if($line =~ /^$/);
    my ($id , $dir) = split("\t", $line);
    next if (defined $non_enriched_list{$id});
    $enriched_list{$id} =1;
  }
  close E;
  close IN;

  my %tmp = ();
  my $peptide_obs = \%tmp;
  ## get spectrum count from human all and phospho all
  if (! -e "$buildpath/PeptideObs.savedState") {
		readIdentFile(
			file => $PAIdentlistFile_all,
			peptides => $peptide_obs,
			enriched_list => \%enriched_list,
			tag => 'ptm'
		);

		readIdentFile(
			file => $HsPA_PAIdentlistFile,
			peptides => $peptide_obs,
			enriched_list => \%enriched_list,
			tag => 'all'
		);
     saveState( peptides => $peptide_obs );
  }else{
     
     $peptide_obs = restoreState();
  }
  my %peptides;
#use Data::Dumper;
#print Dumper ($peptide_obs->{GCNPLAQTGR});
#print Dumper ($peptide_obs->{KGCNPLAQTGR});
#print Dumper ($peptide_obs->{GCNPLAQTGRSK});

  foreach my $pep (keys %$peptide_obs){
    foreach my $modpep(keys %{$peptide_obs->{$pep}}){
       my $modpep_w_term = $modpep;
       if ($modpep_w_term !~ /n\[/){
         $modpep_w_term = 'n'.$modpep_w_term;
       }
       if ($modpep_w_term !~ /c\[/){
         $modpep_w_term = $modpep_w_term.'c';
       }
       
       my @elms =  split(/(?=[a-zA-Z])/, $modpep_w_term) ; 
       my $pos = 0;
       foreach my $i (0..$#elms){
         if ($elms[$i] =~ /c/){ 
            $pos--;
         }    
         my $res = $elms[$i];
         $res =~ s/\[.*//;
         #print "$pep $modpep $res $pos\n" if ($pep eq 'KPAAEKPVEEK');
          #unmodified peptide
				 if ($pep eq $modpep){
						$peptides{$pep}{$pos}{$res}{"enriched-but-non-mod"} += $peptide_obs->{$pep}{$modpep}{enriched};
            $peptides{$pep}{$pos}{$res}{"non-enriched"} += $peptide_obs->{$pep}{$modpep}{"unenriched"};
				 }else{
            # site modified
            if ($elms[$i] =~ /\[/){
               $peptides{$pep}{$pos}{$res}{"enriched-with-mod"} += $peptide_obs->{$pep}{$modpep}{enriched};
            }else{
            # site unmodified
              $peptides{$pep}{$pos}{$res}{"enriched-but-non-mod"} += $peptide_obs->{$pep}{$modpep}{enriched};
              $peptides{$pep}{$pos}{$res}{"non-enriched"} += $peptide_obs->{$pep}{$modpep}{"unenriched"};
            }
         }
				 if ($elms[$i] !~ /n/){
					 $pos++;
				 }
       }
    }
  }

	 #foreach my $pos (keys %{$peptides{'GNPLAQTGR'}}){
		# foreach my $c(("enriched-but-non-mod", "non-enriched", "enriched-with-mod")){
		# }
	 #}

	open (I, "<$PAIdentlistFile") or die "cannot open $PAIdentlistFile\n";
	open (M, "<$PeptideMappingFile") or die "cannot open $PeptideMappingFile\n";

  #search_batch_id,spectrum_query,peptide_accession,peptide_sequence,preceding_residue,modified_peptide_sequence,following_residue,charge,probability,massdiff,protein_name
  # HRPT[181](1.000)FT(0.000)R 

	while (my $line = <I>){
    chomp $line;
		my @tmp = split(/\t/, $line);
		my $pep = $tmp[3];
    my $ptm_sequence = $tmp[19];
    my $modified_sequence = $tmp[5];
    my $type='';
    next if ($ptm_sequence !~ /$ptm_type/);
    #[STY:79.9663]RRES(0.997)RS(0.997)PPPY(0.007)EK
    $modified_sequence = get_modified_sequence ($modified_sequence);

		$ptm_sequence =~ /\[$ptm_type\](\S+)/;
    $ptm_sequence = $1;
 
    ## only obs has ptm score is counted
 		$peptides{$pep}{obsall}++;
    my @n_ptm_sites = $modified_sequence =~ /([$ptm_residue]\[)/g;
    my $n = scalar @n_ptm_sites;
    my $pep_w_term = 'n'.$pep.'c';
    my @n_potential_sites = $pep =~ /([$ptm_residue])/g;

    if ($n >=3 ){
       $peptides{$pep}{'obs3+'}++;
    }else{
      $peptides{$pep}{"obs$n"}++;
    }
    my @elms =  split(/(?=[a-zA-Z])/, $ptm_sequence) ;
    #print join(",", @elms) ."\n";
    my $pos = 0;
    foreach my $i (0..$#elms){
     if($elms[$i] =~ /[$ptm_residue]/){
       $elms[$i] =~ /([a-zA-Z])\(([\.\d]+)\)/;
       my $score = $2;
       my $res = $1;
       #print "$ptm_sequence $i $elms[$i],$res,$score\n";
       if ( $score >= 0 && $score < 0.01 ){
         $peptides{$pep}{$pos}{$res}{nP01}++;
       }elsif($score >= 0.01 && $score < 0.05 ){ 
        $peptides{$pep}{$pos}{$res}{nP05}++ ;
       }elsif($score >= 0.05 && $score < 0.20 ){
        $peptides{$pep}{$pos}{$res}{nP19}++ ;
       }elsif ($score >= 0.20 && $score < 0.80){
         $peptides{$pep}{$pos}{$res}{nP81}++ ;
       }elsif ($score > 0.80 && $score <= 0.95){
         $peptides{$pep}{$pos}{$res}{nP95}++ ;
       }elsif ($score > 0.95 && $score <= 0.99){
         $peptides{$pep}{$pos}{$res}{nP99}++ ;
       }else{
         if (scalar @n_potential_sites == scalar @n_ptm_sites && $score == 1 ){
           $peptides{$pep}{$pos}{$res}{"no-choice"}++;
         }else{
           $peptides{$pep}{$pos}{$res}{nP100}++ ;
         }
       }
     }
     if($elms[$i] !~ /n/){ 
       $pos++;
     }
	 }
  }

  my %protInfo =();
  my %uniprotMod = ();
  my %nextprotMod = ();
  my $counter =0;
  my @prob_categories = qw (nP01 nP05 nP19 nP81 nP95 nP99 nP100 no-choice enriched-with-mod enriched-but-non-mod non-enriched );

  print "getting PTM obs info for each mapped protein\n";
  my %processed = ();
  while (my $line = <M>){
    my ($peptide_accession, $pep, $prot,$start, $end) = split(/\t/, $line);
    next if ($prot =~ /(ENS|IPI|DECOY|[NXY]P\_|CONTAM|CONTRI|Microbe|IMGT)/);
    #next if($pep !~ /[$ptm_residue]/);
    next if (not defined $peptides{$pep});
    my %args = (accession => $prot);
    if ( ! $processed{$prot}  && not defined $uniprotMod{$prot} && $prot !~ /\-/){
       my $swiss = $sbeamsMOD->get_uniprot_annotation( %args );
       if ($swiss->{has_modres}){
          if ($swiss->{MOD_RES}){
            foreach my $item (@{$swiss->{MOD_RES}}){
              if ($item->{info} =~ /phospho/i){
                $uniprotMod{$prot}{$item->{start}} = 1;
              }
            }
          }
       }
    }

    if (! $processed{$prot}  && ! $processed{$prot} &&  $prot !~ /\-/){
       $args{use_nextprot}  = 1;
       my $nextprot = $sbeamsMOD->get_uniprot_annotation(%args);
        if ($nextprot->{has_modres}){
          if ($nextprot->{MOD_RES}){
            foreach my $item (@{$nextprot->{MOD_RES}}){
              print "$item->{info} $item->{start}\n" if ($prot =~ /Q8IUC4/); 
              if ($item->{info} =~ /phospho/i){
                $nextprotMod{$prot}{$item->{start}} = 1;
              }
            }
          }
       }

    }
    $processed{$prot} =1;
    my $pep_w_term = 'n'.$pep.'c';
    my @m = $pep_w_term =~ /[$ptm_residue]/g;
    my $cnt =0;
    while ($pep_w_term =~ /[$ptm_residue]/g){
      my $mpos = $-[0]-1;
      my $pos = $start + $mpos;
      if ($m[$cnt] eq 'n'){
        $pos++;
        $mpos++;
      }
      if ($m[$cnt] eq 'c'){
        $pos--;
      }
      #print "\n########### $pep $m[$cnt] $mpos $pos\n" if ($pep eq 'KPAAEKPVEEK');

      if (defined  $peptides{$pep}){
				$protInfo{$prot}{$pos}{res}{$m[$cnt]}{obsall} += $peptides{$pep}{obsall};
				$protInfo{$prot}{$pos}{res}{$m[$cnt]}{obs1} += $peptides{$pep}{obs1};
				$protInfo{$prot}{$pos}{res}{$m[$cnt]}{obs2} += $peptides{$pep}{obs2};
				$protInfo{$prot}{$pos}{res}{$m[$cnt]}{'obs3+'} += $peptides{$pep}{'obs3+'};
				if (not defined  $protInfo{$prot}{$pos}{representive_peptide}){
					 $protInfo{$prot}{$pos}{representive_peptide}{pep} = "$pep" ;
					 $protInfo{$prot}{$pos}{representive_peptide}{cnt} = $peptides{$pep}{obsall};
				}else{
					 if($peptides{$pep}{obsall} > $protInfo{$prot}{$pos}{representive_peptide}{cnt}){
						 $protInfo{$prot}{$pos}{representive_peptide}{pep} = "$pep" ;
						 $protInfo{$prot}{$pos}{representive_peptide}{cnt} = $peptides{$pep}{obsall};
					 }
				}
        
        foreach my $i (keys %{$peptides{$pep}}){
          next if($i =~ /obs/);
          next if($i != $mpos);
          my $pos = $start + $i;
          #print "### $i \n" if ($pep eq 'KPAAEKPVEEK');
          foreach my $c (@prob_categories){
            if (defined $peptides{$pep}{$i}{$m[$cnt]}{$c}){
              #print "$prot $pos $m[$cnt] $c $peptides{$pep}{$i}{$m[$cnt]}{$c} \n" if ($pep eq 'KPAAEKPVEEK') ;
              $protInfo{$prot}{$pos}{res}{$m[$cnt]}{$c} += $peptides{$pep}{$i}{$m[$cnt]}{$c};
            }
          }
        }
      }
      $cnt++;
    }
    
    $counter++;
    print "$counter..." if ($counter %1000 ==0);
  
  }
  print "\n";



	open(FA, "$fastafile") || die "Couldn't open file\n";
	my $fasta = new FAlite(\*FA);
	my %sequence;
	while( my $entry = $fasta->nextEntry() ){
		my $seq = uc( $entry->seq() );
		my $def = $entry->def();
		my @def = split( /\s/, $def );
		my $acc = $def[0];
		next if($acc =~ /(IPI|ENS|DECOY)/);
		$acc =~ s/^>//g;
		$sequence{$acc} = $seq; 
	}



  open (OUT, ">$buildpath/protein_PTM_summary_$ptm_type.txt");
  print OUT "protein\toffset\tresidue\tnObs\t1phospho\t2phospho\t3+phospho\t";
  print OUT  join("\t", @prob_categories) ;
  print OUT "\tisInUniProt\tisInNeXtProt\tmost_observed_peptide\tptm_type\n";

  foreach my $prot (keys %protInfo){
    if (not defined $sequence{$prot}){
      print "WARNING: $prot no sequence found\n";
      next;
    }
    my @aas = split(//, $sequence{$prot});
    my $pos = 1;
    foreach my $aa (@aas){ 
      if ($aa !~ /[$ptm_residue]/ && not defined $protInfo{$prot}{$pos}){
        $pos++;
        next;
      }
      if (defined $protInfo{$prot}{$pos}{res}){
				foreach my $res (keys %{$protInfo{$prot}{$pos}{res}}){
					if ($res !~ /[nc]/ && $res ne $aa){
						print "WARNING: $prot $pos-1 $aas[$pos-1] !=  $res\n";
					}
					print OUT "$prot\t$pos\t$res\t";
						 
					foreach my $c (qw (obsall obs1 obs2 obs3+) ,@prob_categories){
						if (defined $protInfo{$prot}{$pos}{res}{$res}{$c}){
							print OUT "$protInfo{$prot}{$pos}{res}{$res}{$c}\t"; 
						}else{
							print OUT "0\t";
						}
					}
					if (defined $uniprotMod{$prot}{$pos}){
						print OUT "yes\t";
					}else{
						print OUT "no\t";
					}
					if (defined $nextprotMod{$prot}{$pos}){
						print OUT "yes\t";
					}else{
						print OUT "no\t";
					}
					print OUT "$protInfo{$prot}{$pos}{representive_peptide}{pep}\t$ptm_type\n";
				}
      }else{
         print OUT "$prot\t$pos\t$aa\t";
         foreach my $c (qw (obsall obs1 obs2 obs3+) ,@prob_categories){
           print OUT "0\t";
         }
         if (defined $uniprotMod{$prot}{$pos}){
            print OUT "yes\t";
         }else{
            print OUT "no\t";
         }
         if (defined $nextprotMod{$prot}{$pos}){
            print OUT "yes\t";
         }else{
            print OUT "no\t";
         }
         print OUT "\t$ptm_type\n"; 
      }
      $pos++;
    }
  }
  close I;
  close M;
  close OUT;

}
###############################################################################
# readIdentFile
###############################################################################
sub readIdentFile {

  my %args = @_;
  my $inputFile = $args{file} ||  die "ERROR: Parameter file not passed\n";
  my $peptides = $args{peptides} || die "ERROR: Parameter peptides not passed\n";
  my $enriched_list = $args{enriched_list} || die "ERROR: enriched_list not passed\n";
  my $tag = $args{tag}|| die "not tag passed\n";

  open(INFILE,$inputFile) || die("Unable to open $inputFile");
  print "Reading PAidentlist file $inputFile\n";

  my $line;
  my $counter = 0;

  while ( $line = <INFILE> ) {
    if ($line =~ /^[\s\r\n]*$/) {
      print "Skipping empty line...\n";
      next;
    }
    #### Extract the relevant columns
    my @columns = split(/\t/,$line);
    my $id =  $columns[0];
    my $peptideSequence = $columns[3];
    my $modifiedSequence = $columns[5];
    
    ## need to consider mod mass. do it later 
    next if($peptideSequence !~ /[$ptm_residue]/);
    ## acetyl
    $modifiedSequence = get_modified_sequence($modifiedSequence);

    #print "$modifiedSequence\n" if ($line =~ /E11409_2p_5454_HanChao_T30_1.17997.17997.4/);
 
    # non-enriched data in phospho build not used 
    if ($tag =~ /ptm/i && defined $enriched_list->{$id}){
       $peptides->{$peptideSequence}{$modifiedSequence}{enriched}++;
    }elsif ($tag =~ /all/i && not defined  $enriched_list->{$id}){
       $peptides->{$peptideSequence}{$modifiedSequence}{unenriched}++;
    }
    $counter++;
    print "$counter.." if ( $counter/1000000 == int($counter/1000000) );

  } #### End main reading loop

  print "\n";
  close(INFILE);

}
###############################################################################
# writeSummaryFile
###############################################################################
sub writeSummaryFile {

  my %args = @_;
  my $peptides = $args{peptides} || die("ERROR: Parameter peptides not passed");

  my $summaryFile = "HumanPhospho_202009-all_promast_mapping.tsv";
  open(SUMMARYFILE,">$summaryFile") || die("ERROR: Unable to open for write '$summaryFile'");
  print SUMMARYFILE "peptide\tphospho_peptide\tenriched\tnon-enriched\n";
  foreach my $peptide ( keys %{$peptides} ) {
    foreach my $modpep (keys %{$peptides->{$peptide}}){
       print SUMMARYFILE "$peptide\t$modpep\t";
       foreach my $c (qw(enriched unenriched)){
          if (defined $peptides->{$peptide}{$modpep}{$c}){
             print SUMMARYFILE "$peptides->{$peptide}{$modpep}{$c}\t";
          }else{
             print SUMMARYFILE "0\t";
          }  
        }
        print SUMMARYFILE "\n";
     }
  }
  close(SUMMARYFILE);
  return;
}

###############################################################################
# remove mods not in ptm type
# #############################################################################
sub get_modified_sequence {
  my $modified_sequence = shift;
	if ($ptm_type =~ /[nK]/){
		$modified_sequence =~ s/n\[43\]/z4444/g;
		$modified_sequence =~ s/K\[170\]/K1111/g;
		$modified_sequence =~ s/\[\d+\]//g;
		$modified_sequence =~ s/n//;
		$modified_sequence =~ s/z4444/n\[43\]/g;
		$modified_sequence =~ s/K1111/K\[170\]/g;
	}elsif($ptm_type =~ /[STY]/){
		$modified_sequence =~ s/([ncA-RU-XZ])\[\d+\]+/$1/g;
		$modified_sequence =~ s/[nc]//g;
	}
  return $modified_sequence;
}

###############################################################################
# restoreState
###############################################################################
sub restoreState {

  my %args = @_;

  #### Read back in the data structure
  my $infile = "PeptideObs.savedState";
  print "[INFO]: Restoring previous state from $infile\n";
  my $peptides = retrieve($infile);

  return $peptides;
}

###############################################################################
# saveState
###############################################################################
sub saveState {

  my %args = @_;
  my $peptides = $args{peptides} || die("ERROR: Parameter peptides not passed");

  #### Write out the data structure
  my $outfile = "PeptideObs.savedState";
  print "[INFO]: Storing current state to $outfile\n";
  nstore($peptides,$outfile);

  return;
}

