#!/usr/local/bin/perl -w


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

my $sbeams = new SBEAMS::Connection;
my $sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

my %debug_info;

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
my $PROG_NAME = $FindBin::Script;
my $USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n                   Set verbosity level.  default is 0
  --debug n                     Set debug flag
  --testonly                    If set, rows in the database are not changed or
	                              added
  --build_id                    ID of the atlas build (already entered by hand
	                              in the atlas_build table) into which to load the
																data
  --reload                      Recalculate stats for all the builds.
  --update_n_searched_spectra   re-run the analysis of the pepXML files for a
	                              build, load results.
  --atlas_search_batch_id       Modifies --update_n_searched, only update
	                              specified search batches.
  --proteomics_search_batch_id  Modifies --update_n_searched, only update 
	                              specified search batches.


EOU

my %OPTIONS;
my %args = ( build_id => [],
             atlas_search_batch_id => [],
             proteomics_search_batch_id => [] );


#### Process options, die with usage if it fails.
unless (GetOptions(\%args,"verbose:s","debug:s","testonly",
        "build_id:i", "reload", "nukem", "update_n_searched_spectra",
				"atlas_search_batch_id:s" ) ) {
	die "\n$USAGE";
}

if ( $args{nukem} || $args{reload} ) {
  print "Fandango\n";
#  $sbeams->do( "DELETE FROM $TBAT_SEARCH_BATCH_STATISTICS" );
#  my %fizz = ( 335, 4964, 332, 3401, 334, 4889, 330, 6918, 329, 977, 333, 3667, 331, 1621 );
#  my %map = ( 335 =>1565, 332 => 1557, 334 => 1564, 330 => 1543, 329 => 1539, 333 => 1563, 331 => 1550);
#  for my $k ( keys ( %fizz ) ) {
#    print $sbeams->evalSQL( "UPDATE $TBAT_ATLAS_SEARCH_BATCH SET n_searched_spectra = $fizz{$k} WHERE atlas_search_batch_id = $k\n" );
#    $sbeams->do( "UPDATE $TBAT_ATLAS_SEARCH_BATCH SET n_searched_spectra = $fizz{$k} WHERE atlas_search_batch_id = $k" );
#    print $sbeams->evalSQL( "UPDATE $TBAT_SEARCH_BATCH_STATISTICS SET n_searched_spectra = $fizz{$k} WHERE atlas_search_batch_id = $map{$k}\n" );
#    $sbeams->do( "UPDATE $TBAT_SEARCH_BATCH_STATISTICS SET n_searched_spectra = $fizz{$k} WHERE atlas_build_search_batch_id = $map{$k}" );
#  }
#  exit;
}

my $VERBOSE = $OPTIONS{"verbose"} || 0;

my $QUIET = $OPTIONS{"quiet"} || 0;

my $DEBUG = $OPTIONS{"debug"} || 0;

my $TESTONLY = $OPTIONS{"testonly"} || 0;

my $UPDATE_ALL = $OPTIONS{"update_all"} || 0;

my $pr2atlas;
my $at2pr;
get_search_batch_map();
   
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
sub main 
{

  my $current_username;
  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless (
      $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
  );

  handleRequest();

} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {

  ##### PROCESS COMMAND LINE OPTIONS AND RESTRICTIONS #####

  for my $id ( @{$args{build_id}} ) {
    die "Illegal build_id" if $id !~ /^\d+$/;
  }

  my $build_id_str = join( ",", @{$args{build_id}} );

  die "must specify build_id(s)" unless $build_id_str || $args{reload} || $args{nukem};
  
  # Delete any old info
  my $limit = '';
  $limit = <<"  END" if $build_id_str;
  WHERE atlas_build_search_batch_id IN
    ( SELECT atlas_build_search_batch_id FROM
      $TBAT_ATLAS_BUILD_SEARCH_BATCH WHERE atlas_build_id IN ($build_id_str)
    )
  END
 
  my $delsql = <<"  END";
  DELETE FROM $TBAT_SEARCH_BATCH_STATISTICS 
  $limit
  END
  
  #$sbeams->do( $delsql );
  #print "Deleted SEARCH_BATCH_STATISTICS information for builds $build_id_str\n";

  $delsql = <<"  END";
  DELETE FROM $TBAT_DATASET_STATISTICS
  where atlas_build_id in ( $build_id_str)
  END

  $sbeams->do( $delsql );
  print "Deleted DATASET_STATISTICS information for builds $build_id_str\n";

  # returns ref to array of build_id/data_path arrayrefs
  my $build_info = get_build_info( \@{$args{build_id}} );

	# Optionally update the n_searched_spectra value in atlas_search_batch
	if ( $args{update_n_searched_spectra} ) {
		update_n_searched();
	}

  for my $builds ( @$build_info ) {
    #my $stats = get_build_stats( $builds );
    #insert_stats( $stats );
    my $stats = get_dataset_statistics ($builds);
    insert_dataset_stats( $stats );
  }
  

}

sub update_n_searched {
	my $build_ids = $args{build_id} || return;
	for my $build_id ( @$build_ids ) {

		my $batch_clause = '';
		if ( $args{proteomics_search_batch_id} && scalar(@{$args{proteomics_search_batch_id}}) ) {
      my $search_batches = join( ",", @{$args{proteomics_search_batch_id}} );
			$batch_clause .= "AND ASB.proteomics_search_batch_id IN ( $search_batches ) \n";
    }
		if ( $args{atlas_search_batch_id} && scalar(@{$args{atlas_search_batch_id}}) ) {
      my $search_batches = join( ",", @{$args{atlas_search_batch_id}} );
			$batch_clause .= "AND ASB.atlas_search_batch_id IN ( $search_batches ) \n";
    }

		my $search_batches = $sbeamsMOD->getBuildSearchBatches( build_id => $build_id,
		                                                        batch_clause => $batch_clause );

		for my $batch ( @{$search_batches} ) {

	    my ($n_runs, $n_spec) = $sbeamsMOD->getNSpecFromFlatFiles( search_batch_path => $batch->{data_location} );
      print "$batch->{data_location} n_runs=$n_runs, n_spec=$n_spec \n";
			print STDERR "n_spec is $n_spec! for id $batch->{atlas_search_batch_id}\n";
      print "n_spec is $n_spec! for id $batch->{atlas_search_batch_id}\n";
			
			if ( $n_spec ) {
			  my $rowdata = { n_searched_spectra => $n_spec, n_runs=>$n_runs};
        $sbeams->updateOrInsertRow( update => 1,
                                   table_name => $TBAT_ATLAS_SEARCH_BATCH,
                                  rowdata_ref => $rowdata,
                                           PK => 'atlas_search_batch_id',
                                     PK_value => $batch->{atlas_search_batch_id},
                                    return_PK => 0 );
			}
		}
	}
}

sub get_build_info {
  my $build_ids = shift;
  my $sql =<<"  END";
  SELECT atlas_build_id, data_path
  FROM $TBAT_ATLAS_BUILD
  END
  if ( scalar( @$build_ids ) ) {
    my $in = join( ', ', @{$build_ids} );
    $sql .= "  WHERE atlas_build_id IN ( $in )\n ";
  }
  my @build_ids = $sbeams->selectSeveralColumns( $sql );
  print "No matching builds\n" if !scalar( @build_ids );
  return \@build_ids;
}

sub get_build_stats {
  my $builds = shift;
  my $build_id = $builds->[0];
  my $data_path = $builds->[1];
  my $base_path = $CONFIG_SETTING{PeptideAtlas_PIPELINE_DIRECTORY};
  $data_path = join( '/', $base_path, $data_path );
	my $analysis_path = $data_path;
  $analysis_path =~ s/DATA_FILES\/*/analysis\//;

  # Fetch peptide counts, hash of hashrefs keyed by asb_id
  # my @keys = qw( atlas_build_search_batch_id n_observations
  # n_searched_spectra, data_location );
  my $build_info = get_peptide_counts( $build_id );
  # Read peptide prophet model info from analysis directory
  my $models = get_models( $analysis_path ); 
  my $progressive = get_build_contributions( $analysis_path );
    
  # Fetch search_batch contributions, hash of arrayrefs keyed by asb_id
  # SELECT ASB.atlas_search_batch_id, COUNT(*) num_unique, sample_title, ASB.sample_id
  my $contributions = get_contributions( $build_id);

  # Loop over builds
  use Data::Dumper;
  for my $batch ( sort { $a <=> $b } keys( %$build_info ) ) {
#  print Dumper( $build_info->{$batch} ) . "\n";
    my $p_batch = $progressive->{$at2pr->{$batch}};
#    print "pbatch is " . Dumper( $p_batch );
    my $m_batch = $models->{$at2pr->{$batch}};
#    print "mbatch is " . Dumper( $m_batch );
    my $c_batch = $contributions->{$batch};
#    print "cbatch is " . Dumper( $c_batch );
    for my $k ( keys( %$p_batch ) ) { 
      $build_info->{$batch}->{$k} = $p_batch->{$k};
    }
    for my $k ( keys( %$m_batch ) ) { 
      $build_info->{$batch}->{$k} = $m_batch->{$k};
    }
    for my $k ( keys( %$c_batch ) ) { 
      $build_info->{$batch}->{$k} = $c_batch->{$k};
    }
  }
  return $build_info;
}
sub get_build_contributions {
  my $data_path = shift;
  my %results;
  $log->debug( "In build contrib" );

#  $data_path =~ s/analysis/DATA_FILES/;
  my $contrib_file = $data_path . '/experiment_contribution_summary.out';
  if ( -e $contrib_file ) {
    open ( CONTRIB, $contrib_file ) || return \%results;
    print "FOUND: $contrib_file\n";
  } else {
    $contrib_file =~ s/analysis/DATA_FILES/;
    if ( -e $contrib_file ) {
      print "FOUND: $contrib_file\n";
      open ( CONTRIB, $contrib_file ) || return \%results;
    } else {
      print "Missing: $contrib_file\n";
      return \%results;
    }
  } 
    
# sample_tag sbid ngoodspec      npep n_new_pep cum_nspec cum_n_new is_pub nprot cum_nprot

   my $rownum = 0;
	 my $n_cum_pep = 0;
   while ( my $line = <CONTRIB> ) { 
     chomp $line; 
     next if $line =~ /^-----|sample_tag\s+sbid/;
		 $rownum++;
     $line =~ s/^\s+//;
     $line =~ s/\s+/\t/g;

     my @vals = split "\t", $line, -1;
		 $n_cum_pep += $vals[4];
     $results{$vals[1]} = { n_good_spectra => $vals[2],
                            n_peptides => $vals[3],
                            n_progressive_peptides => $vals[4],
										cumulative_n_peptides => $n_cum_pep,
										n_canonical_proteins => $vals[8],
										cumulative_n_proteins => $vals[9],
                            rownum => $rownum };
   }

  # return hash keyed by sbid, value is arrayref of ngood, npep, nnew, 
  # cum_ngood, cum_nnew, n_prots, cum_n_prots
  return \%results;
}

sub get_models {
  my $data_path = shift;
  my %results;

  my $model_file = $data_path . 'prophet_model.sts';
  if ( -e $model_file ) {
    open ( MODEL, $model_file ) || return \%results;
    my $id;
    while ( my $line = <MODEL> ) {
      chomp $line;
      if ( $line =~ /^(\d+)$/ ) {
        $id = $1;
#        print "ID: $id\t";
      } else {
        $line =~ /sensitivity="([^"]+)"\s+error="([^"]+)"/;
        if ( $1 ) {
#          print "sens is $1, err is $2\n";
          $results{$id} = { model_90_sensitivity => $1, 
                            model_90_error_rate => $2 };
          $id = '';
        } else { # Skip the kruft
        }
      }
    }
    close MODEL;
  }
  return \%results;
}

# Hash mapping proteomics search_batch to atlas version
sub get_search_batch_map {
  my @batches = $sbeams->selectSeveralColumns( <<"  BMAP" );
  SELECT atlas_search_batch_id, proteomics_search_batch_id
  FROM $TBAT_ATLAS_SEARCH_BATCH
  BMAP
  for my $row ( @batches ) {
    $at2pr->{$row->[0]} = $row->[1];
    $pr2atlas->{$row->[1]} = $row->[0];
  }
}


sub get_peptide_counts {

  my $build_id = shift;
  ##get peptide instance that maps to decoy and contam only
  my $sql = qq~
     SELECT PI.Peptide_id,  BS.biosequence_name
     FROM  $TBAT_PEPTIDE_INSTANCE PI
     JOIN $TBAT_PEPTIDE_MAPPING PM ON (PI.PEPTIDE_INSTANCE_ID = PM.PEPTIDE_INSTANCE_ID)
     JOIN $TBAT_BIOSEQUENCE BS ON (PM.MATCHED_BIOSEQUENCE_ID = BS.BIOSEQUENCE_ID)
     WHERE PI.atlas_build_id = $build_id
     ORDER BY PI.Peptide_id
  ~;
  my @rows =  $sbeams->selectSeveralColumns( $sql );
  my %pep_exclude = ();
  my $pre_pep = '';
  my @proteins = '';
  foreach my $row (@rows){
    my ($pep, $prot) = @$row;
    if ($pre_pep ne '' && $pre_pep ne $pep){
      if(@proteins == 0){
        $pep_exclude{$pre_pep} =1;
      }
      @proteins = ();
    }
    push @proteins , $prot if ($prot !~/(^CONTAM|^DECOY)/);
    $pre_pep = $pep;
  }
  if(@proteins == 0){
    $pep_exclude{$pre_pep} =1;
  }
  my $peptide_id_str = join(",", keys %pep_exclude);
  print "DECOY and CONTAM peptides exclued: " . scalar keys %pep_exclude;
  print "\n";

   $sql =<<"  STATS";
  SELECT ASB.atlas_search_batch_id, 
         n_searched_spectra,
         COUNT(PI.n_observations) as total_distinct, 
         SUM(PI.n_observations) as total_obs,
         data_location, 
         atlas_build_search_batch_id, 
         n_runs
  FROM $TBAT_ATLAS_SEARCH_BATCH ASB
  JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON ( ABSB.atlas_search_batch_id = ASB.atlas_search_batch_id )    
  JOIN $TBAT_PEPTIDE_INSTANCE_SEARCH_BATCH PISB
    ON PISB.atlas_search_batch_id = ASB.atlas_search_batch_id
  JOIN $TBAT_PEPTIDE_INSTANCE PI
    ON PISB.peptide_instance_id = PI.peptide_instance_id
  WHERE PI.atlas_build_id = $build_id
  AND PI.peptide_id not in ($peptide_id_str)
  GROUP BY ASB.atlas_search_batch_id, n_runs, n_searched_spectra, data_location,
           atlas_build_search_batch_id
  STATS
  my @all_cnts = $sbeams->selectSeveralColumns( $sql );
  $log->debug( "Getting peptide counts:\n $sql" );

  # Loop and cache 'all' stats
  my %batch_stats;
  my %results;
  for my $build ( @all_cnts ) {
     my %batch = ( 
                  n_searched_spectra               => $build->[1],
                  n_distinct_peptides              => $build->[2],
                  n_observations                   => $build->[3],
                  data_location                    => $build->[4],
                  atlas_build_search_batch_id     => $build->[5],
                  n_runs                           => $build->[6],
                );
    $results{$build->[0]} = \%batch;
  }
  return \%results;
}

sub get_contributions {
  my $build_id = shift;
  my $sql =<<"  SMPL";
  SELECT ASB.atlas_search_batch_id, COUNT(distinct PI.peptide_instance_id) num_unique, sample_title, 
         ABSB.sample_id, ABSB.atlas_build_search_batch_id
  FROM $TBAT_ATLAS_SEARCH_BATCH ASB
  JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON ( ABSB.atlas_search_batch_id = ASB.atlas_search_batch_id )
  JOIN $TBAT_SAMPLE S ON S.sample_id = ABSB.sample_id
  JOIN $TBAT_PEPTIDE_INSTANCE_SEARCH_BATCH PIS ON PIS.atlas_search_batch_id = ASB.atlas_search_batch_id
  JOIN $TBAT_PEPTIDE_INSTANCE PI ON ( PIS.peptide_instance_id = PI.peptide_instance_id AND PI.atlas_build_id = ABSB.atlas_build_id )
  JOIN $TBAT_PEPTIDE P ON PI.peptide_id = P.peptide_id
  JOIN $TBAT_PEPTIDE_MAPPING PM ON PI.peptide_instance_id = PM.peptide_instance_id
  JOIN $TBAT_BIOSEQUENCE BS ON PM.matched_biosequence_id = BS.biosequence_id
  WHERE PI.atlas_build_id = $build_id
  AND BS.biosequence_name NOT LIKE 'DECOY%'
  AND BS.biosequence_name NOT LIKE 'CONTAM%'
  AND PI.peptide_instance_id IN
    ( SELECT distinct PI.peptide_instance_id
       FROM $TBAT_PEPTIDE_INSTANCE_SEARCH_BATCH PISB JOIN $TBAT_PEPTIDE_INSTANCE PI ON PISB.peptide_instance_id = PI.peptide_instance_id
       WHERE atlas_build_id = $build_id
       GROUP BY PI.peptide_instance_id
       HAVING COUNT(*) = 1
   )
  GROUP BY ABSB.sample_id, ABSB.atlas_build_search_batch_id, sample_title, ASB.atlas_search_batch_id
  SMPL

  my @uniq_cnt = $sbeams->selectSeveralColumns( $sql );
	$debug_info{get_contrib_sql} = $sql;

  my %results;

  for my $cnt ( @uniq_cnt ) {
    $results{$cnt->[0]} = { n_uniq_contributed_peptides => $cnt->[1],
                            sample_title => $cnt->[2],
                            sample_id => $cnt->[3],
                            atlas_build_search_batch_id => $cnt->[4],
                           };
  }
		print "Done loop\n";
	return \%results;

}

sub insert_stats {
  my $stats = shift;

  # print "rownum  n_distinct_peptides n_uniq_contributed_peptides cumulative_n_peptides  cumulative_n_proteins\n";
  for my $build_id ( keys %$stats ) {
    my $build = $stats->{$build_id};
    my %rowdata;
    #for my $k ( qw(rownum  n_distinct_peptides n_uniq_contributed_peptides cumulative_n_peptides  cumulative_n_proteins)){
    #  print  $build->{$k} . ", " if ($build->{rownum} =~ /^[1234]$/);  
    #}
    #print "\n"  if ($build->{rownum} =~ /^[1234]$/);

    for my $k ( qw( n_observations atlas_build_search_batch_id 
                    n_runs n_searched_spectra n_uniq_contributed_peptides 
                    n_distinct_peptides
                    n_progressive_peptides n_good_spectra rownum
                    cumulative_n_peptides n_canonical_proteins 
                    cumulative_n_proteins ) ) {
      $rowdata{$k} = $build->{$k};
    }
    # Assertion!
    if (defined  $rowdata{n_uniq_contributed_peptides} ){
		  unless ( $rowdata{n_progressive_peptides} >= $rowdata{n_uniq_contributed_peptides} ) {
			  print STDERR "Exception! n_progressive($rowdata{n_progressive_peptides}) less than n_uniq ".
                     "($rowdata{n_uniq_contributed_peptides} for atlas_search_batch_id=$build_id sample_id=$stats->{$build_id}{sample_id}!\n";
		  }
    }

    my $stats_id = $sbeams->updateOrInsertRow( 
                                       insert => 1,
                                   table_name => $TBAT_SEARCH_BATCH_STATISTICS,
                                  rowdata_ref => \%rowdata,
                                           PK => 'search_batch_statistics_id',
                                    return_PK => 1 );
  }
  
}

sub process_params {
  my $params = {};
  $sbeams->parse_input_parameters( q => $q, parameters_ref => $params );
  $sbeams->processStandardParameters( parameters_ref => $params );
  return( $params );
}
sub get_dataset_statistics{
  my $builds = shift;
  my $atlas_build_id = $builds->[0];
  my $data_path = $builds->[1];
  my $base_path = $CONFIG_SETTING{PeptideAtlas_PIPELINE_DIRECTORY};
  $data_path = join( '/', $base_path, $data_path );
	print "update dataset_statistics for buid_id=$atlas_build_id\n";
  my @stats = ();
  my $experiment_list = "$data_path/../Experiments.list";
	my $outfile2="$data_path/experiment_contribution_summary_dataset.out";
  my @psb_order = ();
  my %psb_rp_id =();
	my %summary = ();
  open (E, "<$experiment_list") or die "cannot find $experiment_list\n";
  while (my $line = <E>){
    chomp $line;
    next if ($line =~ /^#/);
    next if ($line =~ /^$/);
    $line =~ /^(\d+)\s.*/;
    push @psb_order , $1;
  }

	my $sql =qq~;
		SELECT S.SAMPLE_ID, REPOSITORY_IDENTIFIERS, ASB.n_runs, ASB.proteomics_search_batch_id
		FROM $TBAT_SAMPLE  S
    JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON (ASB.sample_id = S.sample_id)
    JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON(ABSB.ATLAS_SEARCH_BATCH_ID = ASB.ATLAS_SEARCH_BATCH_ID)
    WHERE ABSB.atlas_build_id = $atlas_build_id
	~;
  my @results = $sbeams->selectSeveralColumns($sql);
	my %sample_repository_ids = (); 
  my %runs = ();
  foreach my $row(@results){
    my ($sample_id, $rp_id, $n_runs, $psb_id) = @$row;
    $rp_id = 'NA' if (! $rp_id || $rp_id eq '');
    $sample_repository_ids{$sample_id} = $rp_id;
    $psb_rp_id{$psb_id} = $rp_id;
    $runs{$rp_id} += $n_runs;
  }
	print "getting peptides and proteins\n";
	$sql = qq~
		 SELECT PI.Peptide_id,  BS.biosequence_name, PRL.LEVEL_NAME, PIS.sample_id
		 FROM  $TBAT_PEPTIDE_INSTANCE PI 
		 JOIN  $TBAT_PEPTIDE_INSTANCE_SAMPLE PIS ON (PIS.PEPTIDE_INSTANCE_ID = PI.PEPTIDE_INSTANCE_ID)
		 JOIN $TBAT_PEPTIDE_MAPPING PM ON (PI.PEPTIDE_INSTANCE_ID = PM.PEPTIDE_INSTANCE_ID) 
		 JOIN $TBAT_BIOSEQUENCE BS ON (PM.MATCHED_BIOSEQUENCE_ID = BS.BIOSEQUENCE_ID)
		 LEFT JOIN  $TBAT_PROTEIN_IDENTIFICATION PID ON (PID.biosequence_id = PM.MATCHED_BIOSEQUENCE_ID 
                                                     AND PID.atlas_build_id = $atlas_build_id)
		 LEFT JOIN  $TBAT_PROTEIN_PRESENCE_LEVEL PRL ON (PID.PRESENCE_LEVEL_ID = PRL.PROTEIN_PRESENCE_LEVEL_ID)
		 WHERE PI.atlas_build_id = $atlas_build_id
		 AND BS.BIOSEQUENCE_NAME NOT LIKE 'DECOY%'
		 AND BS.BIOSEQUENCE_NAME NOT LIKE 'CONTAM%'
     AND PI.PEPTIDE_INSTANCE_ID NOT IN (
        SELECT PIA.PEPTIDE_INSTANCE_ID 
		    FROM $TBAT_PEPTIDE_INSTANCE_ANNOTATION PIA 
			  JOIN $TBAT_SPECTRUM_ANNOTATION_LEVEL  SAL  
        ON  (SAL.SPECTRUM_ANNOTATION_LEVEL_ID = PIA.spectrum_annotation_level_id
			  AND PIA.RECORD_STATUS != 'D' )
	      WHERE SAL.SPECTRUM_ANNOTATION_LEVEL_ID in (2,3,4)
     )
  ~;

	
	my %dataset_prot;
	# sample_tag sbid ngoodspec      npep n_new_pep cum_nspec cum_n_new is_pub nprot cum_nprot
	my %peptides = ();
  my $sth = $sbeams->get_statement_handle( $sql );
	while (my @row = $sth->fetchrow_array() ) {
		 my ($pep_id, $bs_name,$protein_level, $sample_id) = @row;
		 my $id = $sample_repository_ids{$sample_id} || 'NA'; 
		 $peptides{$id}{$pep_id} =1;
		 next if ($bs_name eq '');
		 next if ($bs_name =~ /(decoy|contam)/i);
     next if (! $protein_level);
		 next if ($protein_level !~/canonical/i);
			$dataset_prot{$id}{$bs_name} =1;
	}
	my %unique_peptides = ();
	my %unique_proteins = ();
	my @ids = keys %peptides;
	foreach my $id (@ids){
		my %list = ();
		foreach my $pep(keys %{$peptides{$id}}){
			$list{$pep} = 1;
		}
		foreach my $id2(@ids){
			next if ($id2 eq $id);
			foreach my $pep(keys %{$peptides{$id2}}){
				if (defined $list{$pep}){
					 $list{$pep} = 0;
				}
			}
		}
		my $cnt =0;
		foreach my $pep (keys %list){
		 if ( $list{$pep}){
			 $cnt++;
		 }
		}
		$unique_peptides{$id} = $cnt;
	}

	foreach my $id (@ids){
		my %list = ();
		foreach my $protein(keys %{$dataset_prot{$id}}){
			$list{$protein} = 1;
		}
		foreach my $id2(@ids){
			next if ($id2 eq $id);
			foreach my $protein(keys %{$dataset_prot{$id2}}){
				if (defined $list{$protein}){
					 $list{$protein} = 0;
				}
			}
		}
		my $cnt =0;
		foreach my $protein (keys %list){
		 if ( $list{$protein}){
			 $cnt++;
		 }
		}
		$unique_proteins{$id} = $cnt;
	}
	print "getting n_spectra\n";

	$sql =qq~
		select S.repository_identifiers as ID, 
					 SUM(SBS.n_searched_spectra),
					 SUM(n_good_spectra)
		FROM $TBAT_SEARCH_BATCH_STATISTICS SBS
		JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON ABSB.atlas_build_search_batch_id = SBS.atlas_build_search_batch_id
		JOIN $TBAT_ATLAS_SEARCH_BATCH ASB ON ( ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id )
		JOIN $TBAT_SAMPLE S ON (S.sample_id = ASB.sample_id)
		WHERE ABSB.atlas_build_id = $atlas_build_id
		GROUP BY S.repository_identifiers
	~;
  my @rows = $sbeams->selectSeveralColumns($sql);
  my %spectra_cnt = ();
  foreach my $row(@rows){
	  my ($id, $n_searched_spectra, $n_good_spectra) = @$row;
    $id = 'NA' if (! $id || $id eq '');
 	  $spectra_cnt{$id}{n_searched_spectra} = $n_searched_spectra;
	  $spectra_cnt{$id}{n_good_spectra} = $n_good_spectra;
  }
  ## order dataset
  my %processed=();
  my @repository_id_order;
  foreach my $psb_id (@psb_order){
     my $rp_id = $psb_rp_id{$psb_id};
     if (not defined $processed{$rp_id}){
       push @repository_id_order, $rp_id;
     }
     $processed{$rp_id} = 1;
  }

	open (OUTFILE2, ">", $outfile2) or die "can't open $outfile2 ($!)";
	#print OUTFILE2 "pxd  ngoodspec     cum_nspec n_unique_pep cum_nspec cum_n_new_pep nprot  cum_nprot\n";
	printf OUTFILE2 ("%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %s\n", "n_goodspec","cum_nspec",  
									 "n_new_pept", "n_prog_pep", "cum_n_pep", "n_uniq_contr_pep", 
									 "n_can_prot", "n_prog_prot", "cum_n_prot",  "n_uniq_contr_can_prots", "dataset");

	#        id n_goodspec cum_nspec n_peptides n_new_pep cum_n_pep n_unique_pep n_prots n_new_prot cum_n_prot n_unique_prots
	#PXD000136     22419     22419      4569      4569      4569     78  1030  1030 1030    0
	#PXD000546    120945    143364      8858         0         0    218  1163     0    0    0
	#
	my ($cum_nspec, $cum_n_new_pep, $cum_prots);
	my %processed = ();
	my $first = 1;
	my ($cum_n_pep, $cum_n_prot);
	foreach my $id (@repository_id_order){
		my $n_goodspec = $spectra_cnt{$id}{n_good_spectra};
    my $n_searched_spectra = $spectra_cnt{$id}{n_searched_spectra};
		my $n_peptides = scalar keys %{$peptides{$id}};
		my $n_prots =  scalar keys %{$dataset_prot{$id}};
		my $n_unique_pep = $unique_peptides{$id};
		my $n_unique_prots = $unique_proteins{$id};
		my ($n_new_pep, $n_new_prot);
		if ($first){
			$first =0;
			$n_new_pep = $n_peptides;
			$n_new_prot = $n_prots;
			$cum_nspec = $n_goodspec;
			$cum_n_pep = $n_peptides;
			$cum_n_prot = $n_prots;
		}else{
			$cum_nspec += $n_goodspec;
			$n_new_pep = get_cum_new(hash =>\%peptides,
																		cur_id => $id,
																		processed => \%processed);
			$n_new_prot = get_cum_new(hash =>\%dataset_prot,
																		cur_id => $id,
																		processed => \%processed);
			$cum_n_pep +=$n_new_pep;
			$cum_n_prot += $n_new_prot;

		}
			printf OUTFILE2 "%10d %10d %10d %10d %8d %15d %11d %11d %11d %10d %s\n",
				$n_goodspec, $cum_nspec, $n_peptides,$n_new_pep,$cum_n_pep,$n_unique_pep,
				$n_prots, $n_new_prot,$cum_n_prot,$n_unique_prots,$id;
	 $processed{$id} =1;
    push @stats, [$id,$n_goodspec,$n_searched_spectra,$cum_nspec, $n_peptides,$n_new_pep,$cum_n_pep,$n_unique_pep,$n_prots, $n_new_prot,$cum_n_prot,$n_unique_prots, $runs{$id},$atlas_build_id];
	}
  return \@stats;

}

##################################################################################'
sub get_cum_new {
  my %args = @_;
  my $hash = $args{hash};
  my $processed = $args{processed};
  my $cur_id = $args{cur_id}; ;
  my %list = ();
	foreach my $s(keys %{$hash->{$cur_id}}){
		$list{$s} = 1;
	}
  my $cnt = 0;
  foreach my $id (keys %$processed){
		foreach my $s(keys %{$hash->{$id}}){
      #print "##$id $s\n";
			if (defined $list{$s}){
				 $list{$s} = 0;
			}
		}
  }
	$cnt =0;
	foreach my $s (keys %list){
	 if ( $list{$s} == 1 ){
		 $cnt++;
	 }
	}
  return $cnt;
}
sub insert_dataset_stats {
  my $stats = shift;
  if (@$stats == 1){
    print "only one dataset for builds. no insertion\n";
    return;
  }
  # print "rownum  n_distinct_peptides n_uniq_contributed_peptides cumulative_n_peptides  cumulative_n_proteins\n";
  my %cols = (
			0=>'repository_identifiers',
			1=>'n_good_spectra',
			2=>'n_searched_spectra',
			3=>'cumulative_n_spectra',
			4=>'n_distinct_peptides',
			5=>'n_progressive_peptides',
			6=>'cumulative_n_peptides',
			7=>'n_uniq_contributed_peptides',
			8=>'n_canonical_proteins',
			9=>'n_progressive_proteins',
			10=>'cumulative_n_proteins',
			11=>'n_uniq_contributed_proteins',
			12=>'n_runs',
			13=>'atlas_build_id',
   );
  my $rownum = 1;
  for my $row ( @$stats ) {
    die "ERROR: column number < 14" if (@$row < 14);
    my %rowdata;
    for my $k (0..13){
      $rowdata{$cols{$k}} =$row->[$k];
    }
    $rowdata{rownum} = $rownum;
    my $stats_id = $sbeams->updateOrInsertRow( 
                                       insert => 1,
                                   table_name => $TBAT_DATASET_STATISTICS,
                                  rowdata_ref => \%rowdata,
                                           PK => 'dataset_statistics_id',
                                    return_PK => 1 );
   $rownum++;
  }
  
}
