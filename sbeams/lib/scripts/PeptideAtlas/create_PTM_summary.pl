#!/usr/local/bin/perl 

use strict;
use Getopt::Long;
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

my $buildpath = shift || usage();
my $fastafile = shift || usage();

main();
exit;



###############################################################################
## usage
################################################################################
sub usage {
  print( <<"  END" );
  Usage:  LoadProteinPTM_summary.pl <build_path> <fastafile>
  END
  exit;
}

sub main {

  my $PeptideMappingFile = "$buildpath/peptide_mapping.tsv";
  my $PAIdentlistFile = "$buildpath/PeptideAtlasInput_concat.PAidentlist";

  #$PeptideMappingFile = "tmp_mapping.tsv";
  #$PAIdentlistFile = "tmp.PAidentlist";  
	#$fastafile = "tmp.fasta"; 

 
	open (I, "<$PAIdentlistFile") or die "cannot open $PAIdentlistFile\n";
	open (M, "<$PeptideMappingFile") or die "cannot open $PeptideMappingFile\n";

  #search_batch_id,spectrum_query,peptide_accession,peptide_sequence,preceding_residue,modified_peptide_sequence,following_residue,charge,probability,massdiff,protein_name
  # HRPT[181](1.000)FT(0.000)R 

	my %peptides = ();
	while (my $line = <I>){
		my @tmp = split(/\t/, $line);
		my $pep = $tmp[3];
    my $ptm_sequence = $tmp[5];
    next if ($ptm_sequence !~ /\(/);
    ## only obs has ptm score is counted
 		$peptides{$pep}{obsall}++;
    my @matches = $ptm_sequence =~ /[STY]\[/g;
    my $n = scalar @matches;
    if ($n >=3 ){
       $peptides{$pep}{'obs3+'}++;
    }else{
      $peptides{$pep}{"obs$n"}++;
    }
    $ptm_sequence =~ s/\[...\]//g;
    my @elms =  split(/(?=[a-zA-Z])/, $ptm_sequence) ;
    #print join(",", @elms) ."\n";
    my $pos = 0;
    foreach my $i (0..$#elms){
     if($elms[$i] =~ /n/){ next;};
     if($elms[$i] =~ /[STY]/){
       $elms[$i] =~ /([\.\d]+)/;
       my $score = $1;
       #print "$ptm_sequence $i $elms[$i] $score\n";
       if ( $score >= 0 && $score < 0.01 ){
         $peptides{$pep}{$pos}{nP01}++;
       }elsif($score >= 0.01 && $score < 0.05 ){ 
        $peptides{$pep}{$pos}{nP05}++ ;
       }elsif($score >= 0.05 && $score < 0.19 ){
        $peptides{$pep}{$pos}{nP19}++ ;
       }elsif ($score >= 0.18 && $score < 0.81){
         $peptides{$pep}{$pos}{nP81}++ ;
       }elsif ($score >= 0.81 && $score < 0.95){
         $peptides{$pep}{$pos}{nP95}++ ;
       }elsif ($score >= 0.95 && $score < 0.99){
         $peptides{$pep}{$pos}{nP99}++ ;
       }else{
         $peptides{$pep}{$pos}{nP100}++ ;
       }
     }
     $pos++;
	 }
  }

  my %protInfo =();
  my %uniprotMod = ();
  my %nextprotMod = ();
  my $counter =0;
  my @prob_categories = qw (nP01 nP05 nP19 nP81 nP95 nP99 nP100);

  print "getting PTM obs info for each mapped protein\n";
  while (my $line = <M>){
    my ($peptide_accession, $pep, $prot,$start, $end) = split(/\t/, $line);
    next if ($prot =~ /(ENS|IPI|DECOY)/);
    next if($pep !~ /[STY]/);
    my %args = (accession => $prot);
    if (not defined $uniprotMod{$prot} && $prot !~ /\-/){
       my $swiss = $sbeamsMOD->get_uniprot_annotation( %args );
       if ($swiss->{has_modres}){
          if ($swiss->{MOD_RES}){
            foreach my $item (@{$swiss->{MOD_RES}}){
              #print "$item->{info} $item->{start}\n"; 
              if ($item->{info} =~ /phospho/i){
                $uniprotMod{$prot}{$item->{start}} = 1;
              }
            }
          }
       }
    }

    if (not defined $nextprotMod{$prot} && $prot !~ /\-/){
       $args{use_nextprot}  = 1;
       my $nextprot = $sbeamsMOD->get_uniprot_annotation(%args);
        if ($nextprot->{has_modres}){
          if ($nextprot->{MOD_RES}){
            foreach my $item (@{$nextprot->{MOD_RES}}){
              #print "$item->{info} $item->{start}\n";
              if ($item->{info} =~ /phospho/i){
                $nextprotMod{$prot}{$item->{start}} = 1;
              }
            }
          }
       }

    }

    my @m = $pep =~ /[STY]/g;
    #print join(",", @m) ."\n";
    my $cnt =0;
    while ($pep =~ /[STY]/g){
      my $mpos = $-[0];
      my $pos = $start + $mpos;
      $protInfo{$prot}{$pos}{res} = $m[$cnt];

      if (defined  $peptides{$pep}){
				$protInfo{$prot}{$pos}{obsall} += $peptides{$pep}{obsall};
				$protInfo{$prot}{$pos}{obs1} += $peptides{$pep}{obs1};
				$protInfo{$prot}{$pos}{obs2} += $peptides{$pep}{obs2};
				$protInfo{$prot}{$pos}{'obs3+'} += $peptides{$pep}{'obs3+'};
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
          my $p = $start + $i;
          foreach my $c (@prob_categories){
            if (defined $peptides{$pep}{$i}{$c}){
              #print "$prot $p $c $peptides{$pep}{$i}{$c} \n";
              $protInfo{$prot}{$p}{$c} += $peptides{$pep}{$i}{$c};
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



  open (OUT, ">protein_PTM_summary.txt");
  print OUT "protein\toffset\tresidue\tnObs\t1phospho\t2phospho\t3+phospho\t";
  print OUT  join("\t", @prob_categories) ;
  print OUT "\tisInUniProt\tisInNeXtProt\tmost_observed_peptide\n";

  foreach my $prot (keys %protInfo){
    if (not defined $sequence{$prot}){
      print "WARNING: $prot no sequence found\n";
      next;
    }
    my @aas = split(//, $sequence{$prot});
    while ($sequence{$prot} =~ /[STY]/g){
      my $pos = $-[0]+1; 
      #foreach my $pos (sort {$a <=> $b} keys %{$protInfo{$prot}}){
      print OUT "$prot\t$pos\t$aas[$pos-1]\t";
      if (defined $protInfo{$prot}{$pos}{res} && $protInfo{$prot}{$pos}{res} ne $aas[$pos-1]){
        print "ERROR: $aas[$pos-1] !=  $protInfo{$prot}{$pos}{res}\n";
        exit;
      }
      foreach my $c (qw (obsall obs1 obs2 obs3+) ,@prob_categories){
        if (defined $protInfo{$prot}{$pos}{$c}){
          print OUT "$protInfo{$prot}{$pos}{$c}\t"; 
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
      print OUT "$protInfo{$prot}{$pos}{representive_peptide}{pep}\n";
    }
  }
  close I;
  close M;
  close OUT;

}

 
