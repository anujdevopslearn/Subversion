#!/usr/local/bin/perl 
use strict;
use DBI;
use Getopt::Long;
use File::Basename;
use Cwd qw( abs_path );
use FindBin;
use Data::Dumper;
use FileHandle;

use lib "$FindBin::Bin/../../perl";

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;


$|++; # don't buffer output

my $sbeams = SBEAMS::Connection->new();
$sbeams->Authenticate();

my $atlas = SBEAMS::PeptideAtlas->new();
$atlas->setSBEAMS( $sbeams );

my $args = process_args();

my $atlas_build_id = $args->{atlas_build_id};
my $empai_file = $args->{empai_file};
my $expected_protein_file = $args->{expected_protein_file};
my $test =  $args->{test};
my $verbose = $args->{verbose};
my $dbh = $sbeams->getDBHandle();
$dbh->{RaiseError}++;

# TODO
# implement delete
# code to check supplied elution_time_type_id
# code to print list of available elution_time_type_id
# supress insert if other records with same type exist?
#

{ # Main 

  if ( $args->{delete} ) {
    print "please use purge prot_info in load_atlas_build.pl\n";
    exit;
  }
      
  my $get_protseq_sql = qq~
       SELECT BS.biosequence_name, BS.biosequence_seq, BS.biosequence_id
       FROM  $TBAT_BIOSEQUENCE BS
       JOIN  $TBAT_ATLAS_BUILD AB ON (AB.biosequence_set_id = BS.biosequence_set_id)
       WHERE AB.atlas_build_id IN ( $atlas_build_id )
       AND BS.BIOSEQUENCE_NAME NOT LIKE 'DECOY%'
     ~;
  my @rows = $sbeams->selectSeveralColumns($get_protseq_sql);;
  
  my %prot_seq;
  my %sku=();
  foreach my $row (@rows){
    my ($prot, $seq, $id) = @$row;
    $prot_seq{$prot}{seq} = $seq;
    $prot_seq{$prot}{id} = $id;
  }
  my %prot2tube = ();
  my %tube2Origene = ();
  open(IN, "<$expected_protein_file") or die "cannot open $expected_protein_file\n";
  foreach my $line (<IN>){
    chomp $line ;
    my ($tpid, @spids,$tube);
    if( $line =~ /(TP\d+),([^,]+),(\w),(\d+),.*VE.+_ISBHOT(0[0123]\d).*/ || $line =~/(TP\d+),([^,]+),(\w),(\d+).*,ISBHOT(0[0123]\d).*/){
      $tpid = $1;
      @spids = split(/\./,$2);
      $tube = "ISBHOT$5-$3$4";
    }
    foreach my $a (@spids){
      $prot2tube{$a} .= "'$tube'";
      $tube2Origene{$tube} = $tpid;
      if($a =~ /(\S+)\-\d+/){
       $prot2tube{$1} .= "'$tube'";
     }
    }
  }
  foreach my $prot (keys %prot2tube){
    if (defined $prot_seq{$prot}){
      my $id = $prot_seq{$prot}{id};
      my $tube = $prot2tube{$prot};
      if ($prot2tube{$prot} =~ /''/){
        $tube =~ s/''/ /g;
        $tube =~ s/'//g;
        my @tubes = split(/\s+/, $tube);
        foreach my $t (@tubes){
          push @{$sku{$id}{tube}}, $t;
          push @{$sku{$id}{sku}}, $tube2Origene{$t};
        }
      }else{
	      push @{$sku{$id}{tube}},$tube;
        $tube =~ s/'//g;
		    push @{$sku{$id}{sku}}, $tube2Origene{$tube};
      }
      #print "$id\t", join(",", @{$sku{$id}{tube}}) ."\t". join(",", @{$sku{$id}{sku}}). "\n";
    }
  }
	my $cnt = 0;

  if ( $args->{update_protein_identification} || $args->{load} ){
    foreach my $prot (keys %prot_seq){
			my $sql = qq~
				 SELECT BS.biosequence_name, MPI.modified_peptide_sequence, S.spectrum_name 
				 FROM  $TBAT_SPECTRUM S
				 INNER JOIN  $TBAT_SPECTRUM_IDENTIFICATION SI
							 ON (SI.spectrum_id = S.spectrum_id )
				 INNER JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI 
							 ON ( MPI.modified_peptide_instance_id = SI.modified_peptide_instance_id)
				 INNER JOIN $TBAT_PEPTIDE_INSTANCE PI 
							 ON (PI.peptide_instance_id = MPI.peptide_instance_id)
				 INNER JOIN $TBAT_PEPTIDE_MAPPING PM
							 ON ( PI.peptide_instance_id = PM.peptide_instance_id )
				 INNER JOIN $TBAT_ATLAS_BUILD AB
							 ON ( PI.atlas_build_id = AB.atlas_build_id )
				 INNER JOIN $TBAT_BIOSEQUENCE_SET BSS
							 ON ( AB.biosequence_set_id = BSS.biosequence_set_id )
				 INNER JOIN sbeams.dbo.organism O
							 ON ( BSS.organism_id = O.organism_id )
				 INNER JOIN $TBAT_BIOSEQUENCE BS
							 ON ( PM.matched_biosequence_id = BS.biosequence_id )
				 INNER JOIN $TBAT_PROTEIN_IDENTIFICATION PID
							 ON (BS.biosequence_id = PID.biosequence_id and PID.atlas_build_id = AB.atlas_build_id)
				 WHERE 1 = 1 AND AB.atlas_build_id IN ( $atlas_build_id)
					 AND BS.biosequence_name = '$prot'
			~;
			my @rows = $sbeams->selectSeveralColumns ($sql);
      if (! @rows){
        print "no result for $prot\n";
        next;
      }else{
 			  print scalar @rows ."\n";
      }
			my %modified_results;
			my $modified_results_ref = \%modified_results;
			ProcessResultset(
						resultset_ref=>\@rows,
						atlas_build_id=>$atlas_build_id,
						modified_results_ref => \%modified_results,
						prot2tube => \%prot2tube,
						tube2Origene => \%tube2Origene,
						prot_seq => \%prot_seq,
			);

			foreach my $bid ( keys %modified_results ) {
				my $first = 1;
				my @row = (); 
				foreach my $line (@{$modified_results{$bid}}){
					my ($SKU,$tube,$prot,$n_observations,$n_distinct_peptides,$protein_content,$sequence_coverage) = split( ",", $line );
					## save to update biosequence_set_properity table
					$cnt++;
					if ($first){
						## update
						my $sql = qq~
											select  protein_identification_id, 
															biosequence_id,
															atlas_build_id,
															protein_group_number,
															presence_level_id,
															represented_by_biosequence_id,
															probability, 
															confidence,
															subsumed_by_biosequence_id,
															seq_unique_prots_in_group,
															is_covering
											FROM $TBAT_PROTEIN_IDENTIFICATION
											where biosequence_id = $bid and atlas_build_id = $atlas_build_id

						~;
						my @rows =  $sbeams->selectSeveralColumns ($sql);
						if (@rows > 1 || ! @rows ){
							print "WARNNING: there are ", scalar @rows , " rows for $bid in $atlas_build_id build\n";
              print "Please do: load_atlas_build.pl --purge --prot_info and --load  --prot_info for the build first\n";
              exit;
						}else{
							@row = @{$rows[0]};
							## update the entry in TBAT_Protein_identification using the first entry of modified_results
							my $rowdata = {n_observations          => $n_observations, 
														 n_distinct_peptides     => $n_distinct_peptides,
														 observed_in_origenetube => $tube, 
														 origenetube_emPAI       => $protein_content,
														 sequence_coverage       => $sequence_coverage
														};

							my $success = $sbeams->updateOrInsertRow( update => 1,
																						table_name  => $TBAT_PROTEIN_IDENTIFICATION,
																						rowdata_ref => $rowdata,
																						verbose     => $verbose,
																										 PK => 'protein_identification_id',
																						PK_value    => $row[0],
																						testonly    => $test);
						}
						$first = 0;
					}else{
						 ## insert
						 my $rowdata = {
									biosequence_id           => $row[1],
									atlas_build_id           => $row[2],
									protein_group_number     => $row[3],
									presence_level_id        => $row[4],
									represented_by_biosequence_id=> $row[5],
									probability              => $row[6],
									confidence               => $row[7],
									subsumed_by_biosequence_id=> $row[8],
									seq_unique_prots_in_group => $row[9],
									is_covering              => $row[10],
								 n_observations            => $n_observations,
								 n_distinct_peptides       => $n_distinct_peptides,
								 observed_in_origenetube   => $tube,
								 origenetube_emPAI         => $protein_content,
								 sequence_coverage         => $sequence_coverage
								};
								my $id = $sbeams->updateOrInsertRow( insert => 1,
																		table_name  => $TBAT_PROTEIN_IDENTIFICATION,
																		rowdata_ref => $rowdata,
																		verbose     => $verbose,
																						 PK => 'protein_identification_id',
																	 return_PK    => 1,
																		testonly    => $test );


					}
						print STDERR '*' unless $cnt % 500;
						print STDERR "\n" unless $cnt % 12500;
					}

			}
    }
		print STDERR "loaded $cnt total rows to protein_identification\n";
  } 

  if ( $args->{update_biosequence_property_set} || $args->{load}){
		## update biosequence_property_set 
		$cnt=0;
		foreach my $bid (keys %sku){
			my @skus = @{$sku{$bid}{sku}};
			my @tubes = @{$sku{$bid}{tube}};
			for(my $i = 0; $i< scalar @skus; $i++){
				my $sku = $skus[$i];
				my $tube = $tubes[$i];
				$tube =~ s/'//g;
				$cnt++;
				my $rowdata = {
								biosequence_id => $bid,
								origene_SKU => $sku,
								origene_tube => $tube,
										 };
				my $sql = qq~ 
						SELECT BIOSEQUENCE_PROPERTY_SET_ID
						FROM $TBAT_BIOSEQUENCE_PROPERTY_SET
						WHERE BIOSEQUENCE_ID = $bid and origene_tube = '$tube'
						and origene_SKU = '$sku'
				~;
				my @rows = $sbeams->selectOneColumn ($sql);
				if ( ! @rows){
					#insert
					my $id = $sbeams->updateOrInsertRow( insert => 1,
																	table_name  => $TBAT_BIOSEQUENCE_PROPERTY_SET,
																	rowdata_ref => $rowdata,
																	verbose     => $verbose,
																					 PK => 'BIOSEQUENCE_PROPERTY_SET_ID',
																	testonly    => $test);
				}else{
					my $success = $sbeams->updateOrInsertRow( update => 1,
																	table_name  => $TBAT_BIOSEQUENCE_PROPERTY_SET,
																	rowdata_ref => $rowdata,
																	verbose     => $verbose,
																					 PK => 'BIOSEQUENCE_PROPERTY_SET_ID',
																	PK_value    => $rows[0],
																	testonly    => $test);

			 }
			}
		}
		print STDERR "loaded $cnt total rows to BIOSEQUENCE_PROPERTY_SET \n"; 
  } 
} # End Main

sub ProcessResultset{
  my %args = @_;
  ####eProcess the arguments list
  my $resultset_ref = $args{'resultset_ref'};
  my $column_titles_ref = $args{'column_titles_ref'};
  my $atlas_build_id = $args{'atlas_build_id'};
  my $modified_results =  $args{'modified_results_ref'};
  my %prot2tube = %{$args{prot2tube}};
  my %tube2Origene =  %{$args{tube2Origene}};
  my %prot_seq = %{$args{prot_seq}};

  my $n_rows = scalar(@$resultset_ref);
  my %obs_peptide_per_protein = ();
  my %prot_seq_cov = ();
  my %obs_in_samples = ();
  my %content_in_molar = ();
  open (CIM, "<$empai_file") or die "cannot open $empai_file\n";
  while (my $line = <CIM>){
    chomp $line ;
    my ($tube,$acc,$value)  = split(/\s+/, $line);
    $tube =~ s/(\-\w)0+/$1/g;
    $content_in_molar{$tube}{$acc} = $value;
  }

  my %prot_obs_tubes = ();
  my %prot_obs_pep_per_tube = ();
  my %prot_obs_spectra_per_tube = ();
  my %bioseq_info = ();
  
  foreach my $row (@$resultset_ref){
    my $biosequence_name = $row->[0]; 
    my $modpep = $row->[1];
    my $spectrum_name  = $row->[2] ;
    $modpep =~ s/\[\d+\]//g;
    my ($tag,$plate,$tube_num);
    if( $spectrum_name =~ /VE_?\d+_ISBHOT(\d{3})\_\d+\_(\w)0?(\d+)\_/ || $spectrum_name =~/VE_?\d+_ISBHOT(\d{3})\_(\w)0?(\d+)_\d+\_/){
      $tag = "$1-$2$3";
      $plate = "ISBHOT$1-$2";
      $tube_num = $3;
    }
    push @{$prot_obs_pep_per_tube{$plate}{$tube_num}{$biosequence_name}}, $modpep;
    $prot_obs_spectra_per_tube{$plate}{$tube_num}{$biosequence_name}++;
    $tag =~ s/^0+//;
    $prot_obs_tubes{$biosequence_name}{$tag} =1;
  }
  foreach my $plate (sort {$a cmp $b} keys %prot_obs_pep_per_tube){
    foreach my $num ( sort {$a <=> $b} keys %{$prot_obs_pep_per_tube{$plate}}){
      foreach my $prot( keys %{$prot_obs_pep_per_tube{$plate}{$num}}){
         my @row = ();
         my $row_ref = \@row;
         my $nobs = $prot_obs_spectra_per_tube{$plate}{$num}{$prot};
         my $SKU = "$tube2Origene{$plate.$num}";
         my $tube = $plate.$num;
         my $acc = $tube2Origene{$plate.$num};
         my $n_observations = $nobs;
         my $protein_content = $content_in_molar{$plate.$num}{$prot};
         ### get protein sequence coverage
         my @peptides = @{$prot_obs_pep_per_tube{$plate}{$num}{$prot}};
         my $sequence = $prot_seq{$prot}{seq};
         my %start_positions;
         my %end_positions;
         my %all_peps = ();
         foreach my $label_peptide (@peptides) {
           $all_peps{$label_peptide} =1;
           if ($label_peptide) {
             my $pos = -1;
             while (($pos = index($sequence,$label_peptide,$pos)) > -1) {
               $start_positions{$pos}++;
               $end_positions{$pos+length($label_peptide)}++;
               $pos++;
             }
           }
         }
         my $seq_length = length($sequence);
         my $i = 0;
         my $color_level = 0;
         my $observed_residues = 0;
         while ($i < $seq_length) {
           if ($end_positions{$i}) {
             $color_level -= $end_positions{$i} unless ($color_level == 0);
           }
           if ($start_positions{$i}) {
             $color_level += $start_positions{$i};
           }
           if ($color_level) {
             $observed_residues++;
           }
           $i++;
         }
         my $sequence_coverage = 0;
         if($seq_length ne 0){
            $sequence_coverage = int($observed_residues/$seq_length*1000)/10;
         }
         my $n_distinct_peptides = scalar keys %all_peps;
         #print "$prot_seq{$prot}{id},$SKU,$tube,$prot,$n_observations,$n_distinct_peptides,$protein_content,$sequence_coverage\n";
         push @{$modified_results->{$prot_seq{$prot}{id}}}, "$SKU,$tube,$prot,$n_observations,$n_distinct_peptides,$protein_content,$sequence_coverage";
      }
    }
  }

} # end postProcessResult

sub process_args {

  my %args;
  GetOptions( \%args, 'load', 'delete', 'empai_file=s', 'atlas_build_id:i', 
             'expected_protein_file=s', 'update_biosequence_property_set' , 
             'update_protein_identification', 'test', 'verbose' );

  print_usage() if $args{help};

  my $missing = '';
  for my $opt ( qw( empai_file expected_protein_file atlas_build_id ) ) {
    $missing = ( $missing ) ? $missing . ", $opt" : "Missing required arg(s) $opt" if !$args{$opt};
  }
  print_usage( $missing ) if $missing;

  unless ( $args{load} || $args{update_protein_identification} || $args{update_biosequence_property_set} || $args{'delete'} ) {
    print_usage( "Must specify at least one of load and delete" );
  }

  return \%args;
}


sub print_usage {
  my $msg = shift || '';
  my $exe = basename( $0 );

  print <<"  END";
      $msg

usage: $exe --load  --empai_file \$PIPELINE/../species/Human/Origene/emPAI.out-build367 \
       --expected_protein_file \$PIPELINE/../species/Human/Origene/ExpectedProtein.txt \
       --atlas_build_id 367
        $exe --load  --empai_file \$PIPELINE/../species/Human/Origene/emPAI.out-build297 \
       --expected_protein_file \$PIPELINE/../species/Human/Origene/ExpectedProtein.txt \
       --atlas_build_id 297		

   --update_biosequence_property_set 
   -h, --help           print this usage and exit
   -l, --load           Load RT Catalog 
   -em, --empai_file     \$PIPELINE/../species/Human/Origene/emPAI.out-build367 
   -ex, --expected_protein_file  \$PIPELINE/../species/Human/Origene/ExpectedProtein.txt
   -i, --atlas_build_id
   --test 
   --verbose
  END

  exit;

}

