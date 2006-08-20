#!/usr/local/bin/perl -w 

use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin";
use lib "/net/db/projects/PeptideAtlas/pipeline/lib/ensembl-39/modules";


use PeptideFilesGenerator;

use vars qw (%OPTIONS $VERBOSE $QUIET $DEBUG $TESTONLY $PROG_NAME $USAGE);
use vars qw ($new_cache $cache_misses $data_files_dir);

#### Do not buffer STDOUT
$|++;

use DBI;
use Storable;
use Data::Dumper;
#use Bio::SeqIO;
use Bio::SearchIO;

use Bio::EnsEMBL::DBSQL::TranscriptAdaptor;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::TopLevelAssemblyMapper;
use Bio::EnsEMBL::DBSQL::CoordSystemAdaptor;
use Bio::EnsEMBL::AssemblyMapper;
use Bio::EnsEMBL::Mapper;
use Bio::EnsEMBL::Mapper::Coordinate;

#######################################################################
# Authors:  Parag Mallick, Eric Deutsch, Nichole King
#######################################################################

###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value key=value ...
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --testonly             Set testonly flag

  --build_abs_path       absolute path to the build directory
  --build_abs_data_path  absolute path to the build directory
  --organism_name        Name of organism like Homo_sapiens
  --organism_abbrev      Abbreviation of organism like Hs
  --min_probability      Limit to a minimum probability
  --ensembl_dir          Ensembl pub ftp directory name
  --mysqldbhost          Hostname of MySQL database of Ensembl tables
  --mysqldbname          Ensembl MySQL database name
  --mysqldbuser          User name to login to Ensembl MySQL host
  --mysqldbpsswd         Password for username to Ensembl MySQL host
  --blast_matrices_path  Path to directory holding BLAST scoring matrices
  --coord_cache_dir      Directory path for cache files

  --getPeptideList       Get input peptide list from Prophet files
  --getEnsembl           Run getEnsembl step
  --BLASTP               Run BLASTP step
  --BLASTParse           Run BLASTParse step
  --IPIBLASTParse        Run IPIBLASTParse step
  --getCoordinates       Run getCoordinates step (very time consuming)
  --lostAndFound         Run make lost and found lists

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
"organism_name:s","organism_abbrev:s", "min_probability:s",
"getPeptideList","getEnsembl","BLASTP","BLASTParse","getCoordinates",
"IPIBLASTParse","lostAndFound",
"ensembl_dir:s", "build_abs_path:s","build_abs_data_path:s",
"blast_matrices_path:s", "coord_cache_dir:s",
"mysqldbpsswd:s","mysqldbuser:s","mysqldbhost:s","mysqldbname:s",
))
{
    print "\n$USAGE\n";
    exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;

my $min_probability = $OPTIONS{min_probability} || 0.9;

main();
exit;


###############################################################################
# main
###############################################################################
sub main
{
  #### If no command to do anything, print usage
  unless (
  $OPTIONS{'getPeptideList'} ||
  $OPTIONS{'getEnsembl'} ||
  $OPTIONS{'BLASTP'} ||
  $OPTIONS{'BLASTParse'} ||
  $OPTIONS{'IPIBLASTParse'} ||
  $OPTIONS{'getCoordinates'} ||
  $OPTIONS{'lostAndFound'}) 
  {
    print "\n$USAGE\n";
    return;
  }


  #### If the getPeptideList step is requested
  if ($OPTIONS{'getPeptideList'}) 
  {
    unless ($OPTIONS{'organism_abbrev'} && $OPTIONS{'build_abs_path'}
    && $OPTIONS{'build_abs_data_path'})
    {
      print "\n$USAGE\n";
      print "ERROR: Must supply organism_abbrev, build_abs_path " .
          " and build_abs_data_path\n";
      return;
    }

    print "Generate peptide files...\n";

    getPeptideList( organism_abbrev => $OPTIONS{'organism_abbrev'},
        build_dir => $OPTIONS{'build_abs_path'},
        data_files_dir => $OPTIONS{'build_abs_data_path'},
        min_probability => $min_probability,
    );

  }

  #### If the getEnsemble step is requested
  if ($OPTIONS{'getEnsembl'}) 
  {
    unless ($OPTIONS{'organism_name'} && $OPTIONS{'ensembl_dir'} &&
    $OPTIONS{'build_abs_data_path'}) 
    {
      print "\n$USAGE\n";
      print "ERROR: Must supply organism_name, ensembl_dir " .
      " and build_abs_path\n";
      return;
    }

    print "Getting Ensemble protein database...\n";

    getEnsembl(
      organism_name => $OPTIONS{'organism_name'},
      ensembl_dir => $OPTIONS{'ensembl_dir'},
      data_files_dir => $OPTIONS{'build_abs_data_path'},
    );
  }


  #### If the BLAST step is requested
  if ($OPTIONS{'BLASTP'}) 
  {
    unless ($OPTIONS{'organism_abbrev'} && 
    $OPTIONS{'build_abs_data_path'} && $OPTIONS{blast_matrices_path}) 
    {
      print "\n$USAGE\n";
      print "ERROR: Must supply organism_abbrev, build_abs_data_path, "
      . " and blast_matrices_path\n";
      return;
    }

    print "BLASTing againt Ensemble protein database...\n";

    BLASTP(organism_abbrev => $OPTIONS{'organism_abbrev'},
        data_files_dir => $OPTIONS{'build_abs_data_path'},
        blast_matrices_path => $OPTIONS{blast_matrices_path});
  }


  #### If the BLASTParse step is requested
  if ($OPTIONS{'BLASTParse'} || $OPTIONS{'IPIBLASTParse'}) 
  {
    unless ($OPTIONS{'mysqldbname'} 
    && $OPTIONS{'mysqldbhost'} && $OPTIONS{'mysqldbuser'}
    && $OPTIONS{'mysqldbpsswd'} && $OPTIONS{'build_abs_data_path'} && 
    $OPTIONS{'coord_cache_dir'}
    ) 
    {
      print "\n$USAGE\n";
      print "ERROR: Must supply mysqldbname, "
      . "mysqldbhost, mysqldbuser, mysqldbpsswd, build_abs_data_path, "
      . " and coord_cache_dir.\n";
      return;
    }

    my $host = $OPTIONS{'mysqldbhost'};
    my $user = $OPTIONS{'mysqldbuser'};
    my $password = $OPTIONS{'mysqldbpsswd'};
    my $dbname = $OPTIONS{'mysqldbname'};

    my $refcode = 'ensembl';
    if ($OPTIONS{'IPIBLASTParse'}) 
    {
      $refcode = 'ipi';
    }

    my ($db,$exon_adaptor,$map_adaptor,$transcript_adaptor,$gene_adaptor);
    my ($cs_adaptor);
    if ($OPTIONS{getCoordinates}) 
    {
      $db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
        -host => $host,
        -user => $user,
        -dbname => $dbname,
        -password => $password,
        -driver => 'mysql',
      );
      $exon_adaptor = $db->get_ExonAdaptor();
      $map_adaptor = $db->get_AssemblyMapperAdaptor();
      $cs_adaptor  = $db->get_CoordSystemAdaptor();
      $transcript_adaptor = $db->get_TranscriptAdaptor();
      $gene_adaptor = $db->get_GeneAdaptor();
    }

    my $cachefile = $OPTIONS{'coord_cache_dir'} ."/$dbname".".enscache";

    BLAST_APD_ENSEMBL(
      db => $db, exon_adaptor => $exon_adaptor,
      map_adaptor => $map_adaptor, cs_adaptor => $cs_adaptor,
      transcript_adaptor => $transcript_adaptor,
      gene_adaptor => $gene_adaptor, refcode => $refcode,
      cachefile => $cachefile, 
      data_files_dir => $OPTIONS{build_abs_data_path},
    );
  }

  #### If lostAndFound step is requested
  if ($OPTIONS{'lostAndFound'}) 
  {
    ##make lost and found list (w.r.t. queries made to Ensembl):
    lostAndFound(organism_abbrev => $OPTIONS{'organism_abbrev'},
    data_files_dir => $OPTIONS{build_abs_data_path});
  }
}


###############################################################################
# getPeptideList: get the latest list of peptides for input to pipeline
# 
# @param min_probability - minimum probability threshhold to apply to peptides
# @organism_abbrev - abbreviation of organism (e.g. Hs, Sc, Dm, ...)
# @build_path - path to build directory
# 
# makes a system call to
#     $SBEAMS/lib/scripts/PeptideAtlas/createPipelineInput.pl
# which creates APD_Hs_all.PAxml and APD_Hs_all.peplist
# and then creates APD files from those.
###############################################################################
sub getPeptideList 
{
    my %args = @_;

    my $organism_abbrev = $args{organism_abbrev} || die 
        "ERROR: Must pass organism_abbrev";

    my $data_files_dir = $args{data_files_dir} || die 
        "ERROR: Must pass data_files_dir";

    my $build_dir = $args{build_dir} || die "ERROR: Must pass build_dir";

    my $min_probability = $args{min_probability} || '0.9';

    my $peptideFilesGenerator = new PeptideFilesGenerator();

    if ($OPTIONS{'min_probability'})
    {
        $peptideFilesGenerator->setMinimumProbability( $min_probability );
    }

    $peptideFilesGenerator->setOrganismAbbreviation( $organism_abbrev );

    $peptideFilesGenerator->setBuildPath( $build_dir );

    $peptideFilesGenerator->setDataPath( $data_files_dir );

    $peptideFilesGenerator->generateFiles();

}


###############################################################################
# getEnsembl: get the latest Ensembl database from ftp, and uses formatdb
# to prepare the fasta file for BLAST
#
# @param organism_name - name used by Ensembl for organism (e.g. homo_sapiens)
# @param ensembl_dir - the desired core ensembl ftp directory path relative to
#     pub
# 
###############################################################################
sub getEnsembl
{
    my %args = @_;

    my $organism_name = $args{organism_name} || die 
        "ERROR: Must pass organism_name";

    my $ensembl_dir = $args{ensembl_dir} || die 
        "ERROR: Must pass ensembl_dir";

    my $data_files_dir = $args{data_files_dir} || die
        "ERROR: Must pass data_files_dir";

    my $pep_file = "$data_files_dir/$organism_name.pep.all.fa";

    my $pep_file_gz = $pep_file . ".gz";

    system("wget -O $pep_file_gz 'ftp://ftp.ensembl.org/pub/$ensembl_dir/data/fasta/pep/*.pep.all.fa.gz'");

    system("gunzip $pep_file_gz");

    system("formatdb -t ensembl_prot -i $pep_file -p T -o T -n ensembl_prot");

    system("/bin/mv ensembl_prot.* $data_files_dir");

    system("/bin/mv formatdb.log $data_files_dir");
}


###############################################################################
# BLASTP - run blastp on local formatted protein file with sequences from APD.
# The blast arguments are set to achieve the highest scores for 
# peptide identities of 100% without gaps.
#
# @param organism_abbrev - organism abbreviation (e.g. Hs, Sc, Dm, ...)
# @param blast_matrices_path - path to directory holding BLAST matrices
# @param data_files_dir - directory to place output files in
###############################################################################
sub BLASTP 
{
    my %args = @_;

    my $organism_abbrev = $args{organism_abbrev} || die 
        "ERROR: Must pass organism_abbrev";

    my $data_files_dir = $args{data_files_dir} || die
        "ERROR: Must pass data_files_dir";

    my $blast_matrices_path = $args{blast_matrices_path} || die
        "ERROR: Must pass blast_matrices_path";

    ## this may not be 
#   $ENV{BLASTDB} = $ENV{PWD}."/$data_files_dir";
    $ENV{BLASTDB} = $data_files_dir;

    $ENV{BLASTMAT} = $blast_matrices_path;

    my $query_file = "$data_files_dir" . "/APD_" . $organism_abbrev .
        "_all.fasta";

    system("blastall -p blastp -i $query_file -d ensembl_prot -F F -W 2 -M PAM30 -G 9 -E 1 -e 10 -K 50 -b 50 -o $data_files_dir/blast_APD_ensembl_out.txt");

}

###############################################################################
# BLAST_APD_ENSEMBL - use bioperl to parse the BLAST hits and call get 
#   coordinates subroutine, also writes the coordinates to a cache file
###############################################################################
sub BLAST_APD_ENSEMBL
{
    my %args = @_;

    my $db = $args{db} || "";

    my $exon_adaptor = $args{exon_adaptor} || "";

    my $map_adaptor = $args{map_adaptor} || "";

    my $cs_adaptor = $args{cs_adaptor} || "";

    my $transcript_adaptor = $args{transcript_adaptor} || "";

    my $gene_adaptor = $args{gene_adaptor} || "";

    my $refcode = $args{refcode} || "";

    my $cachefile = $args{cachefile} || die "need cachefile";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $in = new Bio::SearchIO(
        -format => 'blast',
        -file => "$data_files_dir/blast_APD_${refcode}_out.txt",
    );

    my $outfile = "$data_files_dir/APD_${refcode}_hits.tsv";

    print "Writing outfile $outfile\n";

    open(BLAST_OUT,">$outfile");

    #### If we're going to do coordinate mapping to ENSEMBL, look for
    #### a cache file
    if ($OPTIONS{getCoordinates}) 
    {
        readCoordCache(cachefile => $cachefile);
        #### Clear the coordinate mapping file
        open(COORD,">$data_files_dir/coordinate_mapping.txt");
        close(COORD);
    }

    my %peptides;
    my $n_peptides;
    my $n_peptides_w_hits;
    my $n_peptides_w_perfect_hits;
    $cache_misses = 1;

    while( my $result = $in->next_result ) 
    {
      my $n_hits = 0;
      my $n_perfect_hits = 0;
      while( my $hit = $result->next_hit ){
         while( my $hsp = $hit->next_hsp ) {
            if( $hsp->percent_identity >= 100 ) {
               if( $result->query_length <= $hsp->length('total') ) {
                  my $dif=$result->query_length - $hsp->length('total');
                  my $completeLine = $result->query_name. "\t".
		    $result->query_length. "\t".
		    $hit->name. "\t".
		    $hsp->length('total')."\t".
		    $hsp->percent_identity."\t".
		    $hsp->start('hit')."\t".
		    $hsp->end('hit')."\t".
		    $dif;
                  print BLAST_OUT "$completeLine\n";

                  if ($OPTIONS{getCoordinates})
                  {
                     getCoords($result->query_name,
  		     $hit->name,
                     $hsp->start('hit'),
		     $hsp->end('hit'),
                     $db,
                     $exon_adaptor,
		     $map_adaptor,
                     $cs_adaptor,
                     $transcript_adaptor,
                     $gene_adaptor,
		     $completeLine,
                     $data_files_dir);
                  }
                  $n_perfect_hits++;
               }
            }
         }

         $n_hits++;
      }
      printf("%s  - n_hits %5d    n_perfect_hits: %3d\n",
      $result->query_name,$n_hits,$n_perfect_hits);

      if (exists($peptides{$result->query_name})) {
         die("ERROR: Duplicate query");
      }

      $peptides{$result->query_name} = $n_perfect_hits;
      $n_peptides++;
      $n_peptides_w_hits++ if ($n_hits > 0);
      $n_peptides_w_perfect_hits++ if ($n_perfect_hits > 0);

      #### EDeutsch changed. With a local database, caching is less important
      #if ($cache_misses / 10 == int($cache_misses / 10) &&

      if ($cache_misses / 100 == int($cache_misses / 100) &&
      $OPTIONS{getCoordinates}) 
      {
          writeCoordCache(cachefile => $cachefile);
      }

    }

    close(BLAST_OUT) or die "Cannot close $outfile";

    writeCoordCache(cachefile => $cachefile)
        if ($OPTIONS{getCoordinates});

    printf("%6d peptides\n",$n_peptides);
    printf("%6d peptides with hits\n",$n_peptides_w_hits);
    printf("%6d peptides with perfect hits\n",$n_peptides_w_perfect_hits);
}


###############################################################################
# getCoords -- use bioperl with Ensembl database and blast results
# to map the peptide CDS coordinates to chromosomal coordinates
#
# @param $query_name
# @param $stableId
# @param $start
# @param $end
# @param $db
# @param $exon_adaptor
# @param $map_adaptor
# @param $cs_adaptor
# @param $transcript_adaptor
# @param $gene_adaptor
# @param $completeLine
###############################################################################
sub getCoords
{
    my ($query_name,$stableId,$start,$end,$db,$exon_adaptor, 
        $map_adaptor,$cs_adaptor,$transcript_adaptor,$gene_adaptor,
        $completeLine,$data_files_dir) = @_;

    my ($transcript_stable_id,$gene_stable_id);

    $stableId =~ s/Translation://;
    $completeLine =~ s/Translation://;

    #print "<$stableId> $start $end\n";
    open(COORD,">>$data_files_dir/coordinate_mapping.txt");

    #### See if we already have cached information for this query and hit
    if (defined($new_cache->{$query_name}) &&
        defined($new_cache->{$query_name}->{$stableId}) &&
        defined($new_cache->{$query_name}->{$stableId}->{"$start,$end"}) &&
        defined($new_cache->{$query_name}->{$stableId}->{"$start,$end"}->{$transcript_stable_id}) &&
        defined($new_cache->{$query_name}->{$stableId}->{"$start,$end"}->{$transcript_stable_id}->{$gene_stable_id})  
    ) {

        foreach my $result ( @{$new_cache->{$query_name}->{$stableId}->{"$start,$end"}->{$transcript_stable_id}->{$gene_stable_id}} ) {
            my $buffer = "$completeLine\t".
                $result->{id}."\t".
                $result->{strand}."\t".
                $result->{start}."\t".
                $result->{end}."\t".
                $result->{transcript_stable_id}."\t".
                $result->{gene_stable_id};
                print "$buffer\n";
                print COORD "$buffer\n";
        }
    #### Otherwise, do the query to ENSEMBL
    } else {

        $cache_misses++;

        #### Get the genomic coordinates for this match
        my $transcript = $transcript_adaptor->fetch_by_translation_stable_id($stableId);
        my $top_cs = $cs_adaptor->fetch_top_level();
        my $trans_cs = $transcript->slice->coord_system();
        my $mapper = $map_adaptor->fetch_by_CoordSystems($top_cs, $trans_cs); #create new AssemblyMapper
        my $gene = $gene_adaptor->fetch_by_transcript_stable_id( $transcript->{stable_id} );

        my $chr_name = $transcript->slice()->seq_region_name;

        my @coordlist = $transcript->pep2genomic($start,$end);
        #print "  Found ".scalar(@coordlist)." mappings\n";

        #### For each of the coordinates
        foreach my $cc (@coordlist){
            #printf("  Looking for %s, %s, %s, %s, %s\n",$cc->id,$cc->start,$cc->end,$cc->strand, $trans_cs);
	    #if ($cc->start < 50000) {
	    #  print "  WARNING: Skipping known problem with ccstart < 50000:\n";
            #  printf("    %s, %s, %s, %s, %s\n",$cc->id,$cc->start,$cc->end,$cc->strand, $trans_cs);
            #  next;
	    #}

            my @chr_coordlist;
	    eval {
	      @chr_coordlist = 
                $mapper->map($cc->id,$cc->start,$cc->end,$cc->strand, $trans_cs);
	    };
	    
	    if ( $@ ) {
	      print "  WARNING: Mapping failed with \n$@\n";
	      printf("    %s, %s, %s, %s, %s\n",$cc->id,$cc->start,$cc->end,$cc->strand, $trans_cs);
              next;
	    }

            #print "  Found ".scalar(@chr_coordlist)." chr mappings\n";

            foreach my $i (@chr_coordlist){
                my $buffer = "$completeLine\t".
                    $chr_name."\t".
                    $i->{strand}."\t".
                    $i->{start}."\t".
                    $i->{end}."\t".
                    $transcript->{stable_id}."\t".
                    $gene->{stable_id};
	        print "$buffer\n";
	        print COORD "$buffer\n";

                $transcript_stable_id = $transcript->{stable_id};

                $gene_stable_id = $gene->{stable_id};

	        #### Save this information to the cache
	        my %tmp = (
		    id =>  $chr_name,
		    strand =>  $i->{strand},
		    start =>  $i->{start},
		    end =>  $i->{end},
                    transcript_stable_id  => $transcript_stable_id,
                    gene_stable_id  => $gene_stable_id,
                );
                push(@{$new_cache->{$query_name}->{$stableId}->{"$start,$end"}->{"$transcript_stable_id"}->{"$gene_stable_id"}},\%tmp);
            }
        }
    }
    close(COORD);
}


###############################################################################
# lostAndFound - make list of peptides that weren't matched in protein database
# (expect trypsin, keratin, and proteins no longer in latest database files...)
#
# @param organism_abbrev - organism abbreviation (e.g. Hs, Sc, Dm, ...)
###############################################################################
sub lostAndFound
{
    my %args = @_;

    my $organism_abbrev = $args{organism_abbrev} || die 
        "need organism_abbrev";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $queryfile = "$data_files_dir/APD_$organism_abbrev" . "_all.fasta";

    open QUERIES,"<$queryfile" or die "Unable to open $queryfile for read: ($!)";

    my %query_hash;

    ## reading queries file:
    my $q_count=0;

    while(my $tmp = <QUERIES>)
    {
        chomp ($tmp);

        $tmp =~ s/.//;

        if ( ($q_count % 2 ) == 0 ) 
        { #if even numbered line
            $query_hash{$tmp} = $q_count;
        }
        $q_count++;
    }
    close(QUERIES);

    ## if human:
    my $responsefile = "$data_files_dir/APD_ensembl_hits.tsv";

    ## if yeast:
    if ($args{organism_abbrev} eq "Sc" )
    {
        $responsefile = "$data_files_dir/APD_yeast_hits.tsv";
    }

    open RESPONSE,"<$responsefile" or die "Unable to open $responsefile for read: ($!)";

    my $count=0;
    my $dd;
    my %response_hash;

    ## reading response file:
    while(my $line = <RESPONSE>)
    {
        chomp($line);
        my $tmp;
        ($tmp,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd)=split("\t",$line);
        $response_hash{$tmp} = $count;
        $count++;

        $response_hash{$tmp} = $count;
    }
    close(RESPONSE);


    ##comparing queries to found list:
    my $lostfile = "$data_files_dir/APD_ensembl_lost_queries.dat";

    open LOST,">$lostfile" or die "Unable to open $lostfile for write: ($!)";

    foreach my $query ( keys( %query_hash ) ) 
    {
        if ( $response_hash{$query} == 0 ) 
        { #if there isn't a matching key
             print LOST "$query\n"; #other info wanted besides name?
        }
    }
    close(LOST);
}

###############################################################################
# readCoordCache - retrieve (deserialize) the coordinate cache associated with 
#     this mysqldb into a global complex hash  
# @param absolute path to filename of serialized coordinates
###############################################################################
sub readCoordCache
{
    my %args = @_;

    my $cachefile = $args{cachefile} || die "need cachefile";

    return unless ( -e $cachefile);

    print "Reading cache file...\n";

    %{$new_cache} = %{retrieve($cachefile)};

  return;
}

###############################################################################
# writeCoordCache - serialize the global coordinate cache hash for this mysqldb
# @param absolute path to filename of serialized coordinates
###############################################################################
sub writeCoordCache
{
    my %args = @_;

    my $cachefile = $args{cachefile} || die "need cachefile";

    return unless ( -e $cachefile);

    print "Writing ENSEMBL cache...";

    store($new_cache,$cachefile);

    print "done.\n";

    return;
}
