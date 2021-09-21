#!/usr/local/bin/perl -w

###############################################################################
#
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use lib "$ENV{SBEAMS}/lib/perl/";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $atlas_build_id 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                 Set verbosity level.  default is 0
  --quiet                     Set flag to print nothing at all except errors
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added
  --atlas_build_id
                              the atlas_build table) into which to load the data
 e.g.:  ./$PROG_NAME --atlas_build_id 448 

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "atlas_build_id:s", 
    )) {
    die "\n$USAGE";
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
$atlas_build_id = $OPTIONS{"atlas_build_id"} || die "need atlas_build_id";
  
my $msg = $sbeams->update_PA_table_variables($atlas_build_id);
 
###############################################################################
# Set Global Variables and execute main()
###############################################################################

main();

exit(0);

###############################################################################
# Main Program:
###############################################################################
sub main 
{
  my $build_path='';
  my $sql = qq~
    SELECT DATA_PATH, BIOSEQUENCE_SET_ID 
    FROM $TBAT_ATLAS_BUILD 
    WHERE ATLAS_BUILD_ID = $atlas_build_id
  ~;
  my @rows = $sbeams->selectOneColumn($sql);
  if (@rows){
    $build_path = "/net/db/projects/PeptideAtlas/pipeline/output/$rows[0]";
  }else{
    die "cannot find build path for build $atlas_build_id\n";
  }

  calculate_peptide_nterm (build_path =>  $build_path);

  my $file = "$build_path/peptide_NET_NMC.tsv";
  my %values = ();
  open (IN, "<$file") or die "cannot open $file\n";

  print "updating PEPTIDE_MAPPING table\n";
  $sql = qq~
      SELECT BS.BIOSEQUENCE_NAME, 
             P.peptide_accession, 
             PI.PEPTIDE_INSTANCE_ID, 
             PM.PEPTIDE_MAPPING_ID
      FROM $TBAT_PEPTIDE_MAPPING PM
      JOIN $TBAT_PEPTIDE_INSTANCE PI ON (PI.PEPTIDE_INSTANCE_ID = PM.PEPTIDE_INSTANCE_ID)
      JOIN $TBAT_PEPTIDE P ON (PI.PEPTIDE_ID = P.PEPTIDE_ID)
      JOIN $TBAT_BIOSEQUENCE BS ON (BS.BIOSEQUENCE_ID = PM.MATCHED_BIOSEQUENCE_ID)
      WHERE 1=1
      AND PI.ATLAS_BUILD_ID = $atlas_build_id
    ~;
  my %peptide_mapping =();
  @rows = $sbeams->selectSeveralColumns($sql);
    
  foreach my $row (@rows){
     my ($prot,$pepacc,$pi_id, $pm_id) = @$row;
     $pepacc =~ s/PAp0+//;
     $peptide_mapping{$prot}{$pepacc}{pi_id} = $pi_id;
     push @{$peptide_mapping{$prot}{$pepacc}{pm_id}}, $pm_id;
  }

  my $cnt = 0;
  my $commit_interval = 1000;

  $sbeams->initiate_transaction();
  while (my $line = <IN>){
    chomp $line;
    my ($pepacc, $pepseq, $prot, 
        $enzyme_prot, $highest_n_enzymatic_termini_prot, $lowest_n_missed_cleavages_prot, 
        $enzyme, $highest_n_enzymatic_termini, $lowest_n_missed_cleavages) = split("\t", $line);
    $pepacc =~ s/PAp0+//;
    my $pi_id = $peptide_mapping{$prot}{$pepacc}{pi_id};
    $cnt++;

    foreach my $pm_id (@{$peptide_mapping{$prot}{$pepacc}{pm_id}}){
      my %rowdata = (
        protease_ids => $enzyme_prot, 
        highest_n_enzymatic_termini => $highest_n_enzymatic_termini_prot, 
        lowest_n_missed_cleavages => $lowest_n_missed_cleavages_prot, 
      );
			my $success = $sbeams->updateOrInsertRow(
					update=>1,
					table_name=>$TBAT_PEPTIDE_MAPPING,
					rowdata_ref=>\%rowdata,
					PK => 'peptide_mapping_id',
					PK_value => $pm_id,
					verbose=>$VERBOSE,
					testonly=>$TESTONLY,
  			);

       #$sbeams->executeSQL("update $TBAT_PEPTIDE_MAPPING set protease_ids='$enzyme_prot', highest_n_enzymatic_termini=$highest_n_enzymatic_termini_prot, lowest_n_missed_cleavages=$lowest_n_missed_cleavages_prot where peptide_mapping_id=$pm_id" );	
 
		  $values{$pi_id}{enzyme} = $enzyme;
			$values{$pi_id}{highest_n_enzymatic_termini} = $highest_n_enzymatic_termini;
			$values{$pi_id}{lowest_n_missed_cleavages} = $lowest_n_missed_cleavages;
    }
    print "$cnt..." if ($cnt % $commit_interval == 0);
    $sbeams->commit_transaction() if($cnt % $commit_interval==0);
  }

  $cnt = 0;
  print "updating PEPTIDE_INSTANCE\n";
  foreach my $id (keys %values){
    $cnt++;
    my %rowdata = (
      #protease_ids => $values{$id}{enzyme},
      highest_n_enzymatic_termini => $values{$id}{highest_n_enzymatic_termini}, 
      lowest_n_missed_cleavages => $values{$id}{lowest_n_missed_cleavages},
    );

    my $success = $sbeams->updateOrInsertRow(
        update=>1,
        table_name=>$TBAT_PEPTIDE_INSTANCE,
        rowdata_ref=>\%rowdata,
        PK => 'peptide_instance_id',
        PK_value => $id,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY,
    );
    print "$cnt..." if ($cnt % $commit_interval == 0);
    $sbeams->commit_transaction() if ($cnt % $commit_interval==0);
  }
  $sbeams->commit_transaction() if ($cnt % $commit_interval>0);
  $sbeams->reset_dbh();
}

##############################################################################################

sub calculate_peptide_nterm {
  my %args = @_;
  my $build_path = $args{build_path};

	my %regex = (
    0 => '[X]|[X]',      # no enzyme
		1 => '[KR][^P]',     # trypsin
		2 => '[K][^P]' ,     # lysc
		3 => '[DE][^P]',     # gluc
		4 => '[D]',          # AspN
		5 => '[FWYL][^P]',   # chymo
		6 => '[R][^P]',      # argc
		8 => '[K]',          # lysn
		9 => '[FWYLKR][^P]', # Trypsin, Chymotrypsin and Lysc
		10 => '[KR][^P]',    # Trypsin and Lysc
		11 => '[KR][^P]',    # ArgC and LysC
		12 => '[KR][^P]',    # Trypsin and ArgC
		13 => '[A-Z]',       # nonSpecific
    14 => '[KR]',        # Lysarginase
    15 => '[KR][^P]',    # Lysarginase or Trypsin 
	);


	my $sql = qq~
		SELECT SB.SEARCH_BATCH_ID, PE.PROTEASE_ID  
		FROM $TBPR_SEARCH_BATCH SB
		JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON (SB.EXPERIMENT_ID = PE.EXPERIMENT_ID)
	~;

	my %sample_enzyme = $sbeams->selectTwoColumnHash ($sql);

	my $peptide_mapping_file = "$build_path/peptide_mapping.tsv";
	my $pa_identlist_file = "$build_path/PeptideAtlasInput_concat.PAidentlist";

	open (IN,"<$pa_identlist_file") or die "cannot open $pa_identlist_file\n";
	my %identifications = ();
	while (my $line = <IN>){
		chomp $line;
		my @tmp = split("\t", $line);
		my $enzyme_id ;
    if ($sample_enzyme{$tmp[0]}){
      $enzyme_id = $sample_enzyme{$tmp[0]};
    }else{
      $enzyme_id = 1;
    }
		my $pepacc = $tmp[2];
		$identifications{$pepacc}{$enzyme_id} =1;
	}

	open (MAP, "<$peptide_mapping_file") or die "cannot open $peptide_mapping_file\n";
	open (OUT, ">$build_path/peptide_NET_NMC.tsv") ;
	print OUT "peptide_accession\tpeptide\tprot\tenzyme\thighest_n_enzymatic_termini\tlowest_n_missed_cleavages\t".
						"\tenzyme\thighest_n_enzymatic_termini\tlowest_n_missed_cleavages\n";
	my %peptide_n_term = ();
	my @list = ();
	my $preacc = '';
	my $first = 1;
	while (my $line =<MAP>){
		chomp $line;
		my ($pepacc,$pep,$prot,$start, $end,$preAA,$folAA) = split("\t", $line);
		next if ($prot eq '' ) ;
		my @pepaas = split(//, $pep);
		my %peptide_n_term_prot =();

		if ($preacc ne $pepacc && !$first){
			my $enzyme_id = get_enzyme_id(peptide_n_term => \%peptide_n_term);
			#if ($preacc eq 'PAp03155327'){
			#	foreach my $e (keys %peptide_n_term){
			#		print "2: $e $peptide_n_term{$e}{highest_n_enzymatic_termini} $peptide_n_term_prot{$e}{lowest_n_missed_cleavages}\n";
			#	}
			#}

			foreach my $line (@list){
				print OUT "$line\t$enzyme_id\t". #$regex{$enzyme_id}\t".
									"$peptide_n_term{$enzyme_id}{highest_n_enzymatic_termini}\t".
									$peptide_n_term{$enzyme_id}{lowest_n_missed_cleavages} ."\n";
			}
			@list = ();
			%peptide_n_term=();
		}
		foreach my $enzyme_id (keys %{$identifications{$pepacc}}){
			my $pat = $regex{$enzyme_id};
			# trypsin, GluC, LysC, and CNBr clip Cterminally
			my $term = 'C';
			# AspN is the outlier
			$term = 'N' if ($enzyme_id == 4 || $enzyme_id == 8 || $enzyme_id == 14);
      $term = 'NC' if ($enzyme_id == 15);
			my $n_term = 0;
			if ($start == 1){
				$n_term++;
			}else{
				my $two_aas = $preAA.$pepaas[0];
				if ($term eq 'C' && $two_aas =~ /^$pat/){
					$n_term++;
				}elsif ($term eq 'N' && $two_aas =~ /$pat$/){
					$n_term++;
				}elsif ($term eq 'NC' && ($two_aas =~ /^$pat/ || $two_aas =~ /$pat$/)){ 
          $n_term++;
        }
				#print "1: n_term $n_term pat  $pat $preAA.$pep.$folAA\n"; 
			}
		 
			if($folAA eq '-' or $folAA eq '*'){
				$n_term++;
			}else{
				my $two_aas = $pepaas[$#pepaas].$folAA; 
				if ($term eq 'C' && $two_aas =~ /^$pat/){
					$n_term++;
				}elsif ($term eq 'N' && $two_aas =~ /$pat$/){
					$n_term++;
				}
				#print "2: n_term $n_term pat  $pat $preAA.$pep.$folAA\n";
			}

			if (not defined $peptide_n_term_prot{$enzyme_id}{highest_n_enzymatic_termini}){
				$peptide_n_term_prot{$enzyme_id}{highest_n_enzymatic_termini} = $n_term;
			}else{ 
				if ($peptide_n_term_prot{$enzyme_id}{highest_n_enzymatic_termini} < $n_term){
					$peptide_n_term_prot{$enzyme_id}{highest_n_enzymatic_termini} = $n_term;
				}
			}
			if (not defined $peptide_n_term{$enzyme_id}{highest_n_enzymatic_termini}){
				$peptide_n_term{$enzyme_id}{highest_n_enzymatic_termini} = $n_term;
			}else{ 
				if ($peptide_n_term{$enzyme_id}{highest_n_enzymatic_termini} < $n_term){
					$peptide_n_term{$enzyme_id}{highest_n_enzymatic_termini} = $n_term;
				}
			}

			my @matches = ($pep =~ /$pat/g);

			if ($term eq 'N'){
				## for current two n-terminal enzymes, this works, but might not work for others.
				@matches = ($pep =~ /\w$pat/g); 
			}
      if ($enzyme_id eq '13'){
        @matches = ();
      }

			if (not defined $peptide_n_term_prot{$enzyme_id}{lowest_n_missed_cleavages}){
				 $peptide_n_term_prot{$enzyme_id}{lowest_n_missed_cleavages} = scalar @matches;
			}else{
				if ($peptide_n_term_prot{$enzyme_id}{lowest_n_missed_cleavages} > scalar @matches){
					$peptide_n_term_prot{$enzyme_id}{lowest_n_missed_cleavages}  = scalar @matches;
				}
			}
			if (not defined $peptide_n_term{$enzyme_id}{lowest_n_missed_cleavages}){
				 $peptide_n_term{$enzyme_id}{lowest_n_missed_cleavages} = scalar @matches;
			}else{
				if ($peptide_n_term{$enzyme_id}{lowest_n_missed_cleavages} > scalar @matches){
					$peptide_n_term{$enzyme_id}{lowest_n_missed_cleavages}  = scalar @matches;
				}
			}
			#print "3: $pepacc,$pep,$pat, n_term $n_term, missed_c ".  scalar @matches ;
			#print "\n";
		}

		### find highest_n_enzymatic_termini and lowest_n_missed_cleavages for this protein mapping
		my $enzyme_id = get_enzyme_id(peptide_n_term => \%peptide_n_term_prot);
		#if ($pep eq 'KPATPAEDDEDDDIDLFGSDNEEED'){
		#  foreach my $e (keys %peptide_n_term_prot){
		#    print "$prot: $e $peptide_n_term_prot{$e}{highest_n_enzymatic_termini} $peptide_n_term_prot{$e}{lowest_n_missed_cleavages}\n";
		#  }
		#}

		push @list , "$pepacc\t$preAA.$pep.$folAA\t$prot\t". #$enzyme_id\t".#"$regex{$enzyme_id}\t" .
                 join(",", keys %peptide_n_term_prot) ."\t".
								 "$peptide_n_term_prot{$enzyme_id}{highest_n_enzymatic_termini}\t".
								 $peptide_n_term_prot{$enzyme_id}{lowest_n_missed_cleavages};

		$preacc = $pepacc; 
		$first = 0; 
		%peptide_n_term_prot = ();

	}

	my $enzyme_id = get_enzyme_id(peptide_n_term => \%peptide_n_term);
	foreach my $line (@list){
		print OUT "$line\t". #\t$enzyme_id\t" .#$regex{$enzyme_id}\t".
              join(",", keys %peptide_n_term) ."\t".
							"$peptide_n_term{$enzyme_id}{highest_n_enzymatic_termini}\t".
							$peptide_n_term{$enzyme_id}{lowest_n_missed_cleavages} ."\n";
  }
  close OUT;
}


##############################################################################################

sub get_enzyme_id {
  my %args = @_;
  my $peptide_n_term = $args{peptide_n_term};
  my %peptide_n_term = %$peptide_n_term;
  my @ids = ();
  my $preval = -1;

  my $n = scalar keys %peptide_n_term;

  foreach my $id (sort {$peptide_n_term{$b}{highest_n_enzymatic_termini} <=> 
                        $peptide_n_term{$a}{highest_n_enzymatic_termini}} keys %peptide_n_term){
    #print "id $id term $peptide_n_term{$id}{highest_n_enzymatic_termini}\n" if ($n>1);
    if ($peptide_n_term{$id}{highest_n_enzymatic_termini} >= $preval){
      push @ids, $id;
    }
    $preval = $peptide_n_term{$id}{highest_n_enzymatic_termini};
  }
  $preval = 1000;
  my $bestid = '';
  foreach my $id (@ids){
    #print "id $id  missed $peptide_n_term{$id}{lowest_n_missed_cleavages}\n" if ($n>1);
    if ($peptide_n_term{$id}{lowest_n_missed_cleavages} < $preval){
      $bestid = $id;
    }elsif ($peptide_n_term{$id}{lowest_n_missed_cleavages} == $preval){
      if ($bestid > $id){
        $bestid = $id;
      }
    }
    $preval = $peptide_n_term{$id}{lowest_n_missed_cleavages};
    #print "id $id $peptide_n_term{$id}{highest_n_enzymatic_termini} $peptide_n_term{$id}{lowest_n_missed_cleavages}\n" if (@ids > 1);

  }
  #print join(",", @ids) . " best $bestid\n"if (@ids>1);
  return $bestid;
}


