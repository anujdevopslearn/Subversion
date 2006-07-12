#!/usr/local/bin/perl -w 

use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin";
use lib "/net/db/projects/PeptideAtlas/pipeline/lib/ensembl-39/modules";

use ProtFeatures;
use PeptideFilesGenerator;

use vars qw (%OPTIONS $VERBOSE $QUIET $DEBUG $TESTONLY $PROG_NAME $USAGE);
use vars qw ($cache_misses);

#### Do not buffer STDOUT
$|++;

use DBI;
use Storable;
use Data::Dumper;

# to parse output from BLAST:
use Bio::SearchIO;

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
  --organism_name        Name of organism, e.g, Homo_sapiens, Yeast
  --organism_abbrev      Abbreviation of organism like Hs
  --min_probability      Limit to a minimum probability
  --prot_ftp_addr        ftp address of protein set (including filename)
  --chrom_ftp_addr       ftp address of chromosome features
  --blast_matrices_path  Path to directory holding BLAST scoring matrices

  --getPeptideList       Get input peptide list from Prophet files
  --getProteinSet        Run get Protein Set step
  --BLASTProteins        Run BLAST step
  --parseBLASTHits       Run parseBLASTHits step
  --getCoordinates       Run getCoordinates step 
  --lostAndFound         Run step to make list of peptides not identified
                         in protein set

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
    "organism_name:s","organism_abbrev:s", "min_probability:s",
    "getPeptideList", "getProteinSet", "prot_ftp_addr:s",
    "BLASTProteins", "parseBLASTHits", "getCoordinates", 
    "chrom_ftp_addr:s", "lostAndFound",
    "build_abs_path:s","build_abs_data_path:s",
    "blast_matrices_path:s",
    )) {
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
    $OPTIONS{'getProteinSet'} ||
    $OPTIONS{'BLASTProteins'} ||
    $OPTIONS{'parseBLASTHits'} ||
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
            min_probability => $min_probability
        );
    }



    #### If the getProteinSet step is requested
    if ($OPTIONS{'getProteinSet'}) 
    {
        unless ($OPTIONS{'prot_ftp_addr'} && $OPTIONS{'organism_name'}
        && $OPTIONS{'build_abs_data_path'}) 
        {
            print "\n$USAGE\n";
            print "ERROR: Must supply organism_name, ensembl_dir " .
            " and build_abs_path\n";
            return;
        }
  
        print "Getting protein database...\n";

        getProteinSet(organism_name => $OPTIONS{'organism_name'},
            prot_ftp_addr => $OPTIONS{'prot_ftp_addr'},
            data_files_dir => $OPTIONS{'build_abs_data_path'},
        );
    }


    #### If the BLASTProteins step is requested
    if ($OPTIONS{'BLASTProteins'}) 
    {
        unless ($OPTIONS{'organism_name'} && $OPTIONS{'organism_abbrev'}
        && $OPTIONS{'build_abs_data_path'} && $OPTIONS{'blast_matrices_path'}) 
        {
            print "\n$USAGE\n";
            print "ERROR: Must supply organism_abbrev, build_abs_data_path, "
                . " and blast_matrices_path\n";
            return;
        }

        print "BLASTing protein database for peptides...\n";

        BLASTProteins(organism_name => $OPTIONS{'organism_name'},
            organism_abbrev => $OPTIONS{'organism_abbrev'},
            data_files_dir => $OPTIONS{'build_abs_data_path'},
            blast_matrices_path => $OPTIONS{'blast_matrices_path'}
        );
    }


    #### If the parseBLASTHits step is requested
    if ($OPTIONS{'parseBLASTHits'}) 
    {
        unless ($OPTIONS{'organism_name'} && $OPTIONS{'organism_abbrev'}
        && $OPTIONS{'build_abs_data_path'} )
        {
            print "\n$USAGE\n";
            print "ERROR: Must supply organism_name, organism_abbrev, "
                . " and build_abs_data_path\n";
            return;
        }

        parseBLASTHits(organism_name => $OPTIONS{'organism_name'},
            organism_abbrev => $OPTIONS{'organism_abbrev'},
            data_files_dir => $OPTIONS{'build_abs_data_path'},
        );

    }

    #### If the getCoordinates step is requested
    if ($OPTIONS{'getCoordinates'}) 
    {
        unless ($OPTIONS{'organism_name'} && $OPTIONS{'chrom_ftp_addr'} &&
        $OPTIONS{'build_abs_data_path'} ) 
        {
            print "\n$USAGE\n";
            print "\nERROR: need organism_name, chrom_ftp_addr ",
            "and build_abs_data_path\n";
            return;
        }

        ## get file from ftp site:
        getChromFeaturesFromFtp(
            chrom_ftp_addr => $OPTIONS{'chrom_ftp_addr'},
            data_files_dir => $OPTIONS{'build_abs_data_path'},
        );

        mapPeptides(
            chrom_ftp_addr => $OPTIONS{'chrom_ftp_addr'},
            organism_name => $OPTIONS{'organism_name'},
            data_files_dir => $OPTIONS{'build_abs_data_path'},
        );

    }



    #### If lostAndFound step is requested
    if ($OPTIONS{'lostAndFound'}) 
    {
        unless ($OPTIONS{'organism_name'} && $OPTIONS{'organism_abbrev'} 
        && $OPTIONS{'build_abs_data_path'}) 
        {
            print "\n$USAGE\n";
            print "\nERROR: Must supply organism_name, organism_abbrev, "
                ." and build_abs_data_path\n";
            return;
        }

        ## make list of APD peptides not found in protein database
        lostAndFound(
            organism_abbrev => $OPTIONS{'organism_abbrev'},
            organism_name => $OPTIONS{'organism_name'},
            data_files_dir => $OPTIONS{'build_abs_data_path'},
        );
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
# getProteinSet: get the latest Protein database
###############################################################################
sub getProteinSet
{
    my %args = @_;

    my $ftp_addr = $args{prot_ftp_addr};

    my $data_files_dir = $args{data_files_dir};

    my $zipped_prot_file_name = getProteinDatabaseZippedFileName (
        prot_ftp_addr => $args{prot_ftp_addr},
    );

    $zipped_prot_file_name = "$data_files_dir/$zipped_prot_file_name";

    my $prot_file_name = getProteinDatabaseFileName (
        prot_ftp_addr => $args{prot_ftp_addr},
    );

    $prot_file_name = "$data_files_dir/$prot_file_name";

    unless ( -e $prot_file_name ) 
    {
        system("wget -O $zipped_prot_file_name '$ftp_addr'");

        system("gunzip $prot_file_name");

        my $organism = $args{organism_name};

        system("formatdb -t ${organism}_prot -i $prot_file_name  -p T -o T -n ${organism}_prot");

        system("/bin/mv ${organism}_prot.* $data_files_dir");

        system("/bin/mv formatdb.log $data_files_dir");
    }

}



###############################################################################
# BLASTProteins: Run BLAST on protein files to find APD peptides
#
# @param organism_name - organism name 
# @param organism_abbrev - organism abbreviation (e.g. Hs, Sc, Dm, ...)
# @param blast_matrices_path - path to directory holding BLAST matrices
# @param data_files_dir - directory to place output files in
###############################################################################
sub BLASTProteins 
{
    my %args = @_;

    my $organism_abbrev = $args{organism_abbrev} || die
        "ERROR: Must pass organism_abbrev";

    my $organism_name = $args{organism_name} || die
        "ERROR: Must pass organism_name";

    my $data_files_dir = $args{data_files_dir} || die
        "ERROR: Must pass data_files_dir";

    my $blast_matrices_path = $args{blast_matrices_path} || die
        "ERROR: Must pass blast_matrices_path";

#   $ENV{BLASTDB} = $ENV{PWD}."/DATA_FILES";
    $ENV{BLASTDB} = $data_files_dir;

#   $ENV{BLASTMAT} = "/package/genome/bin/data";
    $ENV{BLASTMAT} = $blast_matrices_path;

    my $query_file = "$data_files_dir" . "/APD_" . $organism_abbrev .
        "_all.fasta";

    my $BLASTOutFileName = getBLASTOutFileName (
        organism_name => $organism_name,
        data_files_dir => $data_files_dir,
    );

    system("blastall -p blastp -i $query_file -d ${organism_name}_prot -F F -W 2 -M PAM30 -G 9 -E 1 -e 10 -K 50 -b 50 -o $BLASTOutFileName");

}

###############################################################################
# parseBLASTHits
###############################################################################
sub parseBLASTHits 
{
    my %args = @_;

    my $organism_name = $args{organism_name} || die "need organism_name";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $BLASTOutFileName = getBLASTOutFileName (
        organism_name => $organism_name,
        data_files_dir => $data_files_dir,
    );

    my $in = new Bio::SearchIO(
        -format => 'blast',
        -file => $BLASTOutFileName,
    );

    my $hitsFileName = getProteinHitsFileName ( 
        organism_name => $args{organism_name},
        data_files_dir => $data_files_dir,
    );

    open(BLAST_OUT,">$hitsFileName");

    my %peptides;
    my $n_peptides;
    my $n_peptides_w_hits;
    my $n_peptides_w_perfect_hits;
    $cache_misses = 1;

    while( my $result = $in->next_result ) {
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

                        $n_perfect_hits++;
                    }
                }
            }

           $n_hits++;
        }

        printf("%s  - n_hits %5d    n_perfect_hits: %3d\n",
            $result->query_name,$n_hits,$n_perfect_hits);


        die("ERROR: Duplicate query") if (exists($peptides{$result->query_name}));


        $peptides{$result->query_name} = $n_perfect_hits;

        $n_peptides++;

        $n_peptides_w_hits++ if ($n_hits > 0);

        $n_peptides_w_perfect_hits++ if ($n_perfect_hits > 0);

    }

    close(BLAST_OUT);

    printf("%6d peptides\n",$n_peptides);
    printf("%6d peptides with hits\n",$n_peptides_w_hits);
    printf("%6d peptides with perfect hits\n",$n_peptides_w_perfect_hits);

}

###############################################################################
# getChromFeaturesFromFtp: get the latest chromosome features file.  it contains
#    chromosomal coordinates of the proteins
###############################################################################
sub getChromFeaturesFromFtp
{
    my %args = @_;

    my $ftp_addr = $args{chrom_ftp_addr} || die "need chrom_ftp_addr";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $featuresFileName = getFeaturesFileName(
        chrom_ftp_addr => $ftp_addr,
        data_files_dir => $data_files_dir,
    );

    unless ( -e $featuresFileName ) {
        system("wget -O $featuresFileName '$ftp_addr'");
    }

    my $READMEFile = getFeaturesREADMEFileName(
        chrom_ftp_addr => $ftp_addr,
        data_files_dir => $data_files_dir,
    );

    my $README_ftp_addr = getFeaturesREADME_ftp_addr(
        chrom_ftp_addr => $ftp_addr,
        data_files_dir => $data_files_dir,
    );

    unless ( -e $READMEFile ) 
    {
        system("wget -O $READMEFile '$README_ftp_addr'");
    }

}

###############################################################################
#  lostAndFound  make list of peptides that weren't matched in protein database
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


    my $hitsFileName = getProteinHitsFileName (
        organism_name => $args{organism_name},
        data_files_dir => $data_files_dir,
    );


    open HITS,"<$hitsFileName" or die "Unable to open $hitsFileName for read: ($!)";

    my $count=0;
    my $dd;
    my %hits_hash;

    ## reading hits file:
    while(my $line = <HITS>)
    {
        chomp($line);
        my $tmp;
        ($tmp,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd)=split("\t",$line);
        $hits_hash{$tmp} = $count;
        $count++;

        $hits_hash{$tmp} = $count;
    }
    close(HITS);


    ##comparing queries to found list:
    my $lostfile = getAPDLostFileName (
        organism_abbrev => $args{organism_abbrev},
        data_files_dir => $data_files_dir
    );

    open LOST,">$lostfile" or die "Unable to open $lostfile for write: ($!)";

    foreach my $query ( keys( %query_hash ) ) 
    {
        if ( $hits_hash{$query} == 0 ) 
        { #if there isn't a matching key
            print LOST "$query\n"; #other info wanted besides name?
        }
    }
    close(LOST);
}



###############################################################################
#  getFeaturesFileName:  gets the name of the disk file where 
#  where features file will be/is copied to.
###############################################################################
sub getFeaturesFileName
{
    my %args = @_;

    my $ftp_addr = $args{chrom_ftp_addr} || die "need chrom_ftp_addr";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $features_file_name = $ftp_addr;

    $features_file_name =~ s/(.+)\/(.*tab)$/$2/gi;

    $features_file_name = "$data_files_dir/$features_file_name";

    return $features_file_name;
}


###############################################################################
#  getFeaturesREADMEFileName:  gets the name of the disk file where 
#  where README file for features file will be/is copied to.
###############################################################################
sub getFeaturesREADMEFileName
{
    my %args = @_;

    my $ftp_addr = $args{chrom_ftp_addr} || die "need chrom_ftp_addr";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $README_file_name = $ftp_addr;

    $README_file_name =~ s/(.+)\/(.*tab)$/$2/gi;

    $README_file_name = "$data_files_dir/README_$README_file_name";

    return $README_file_name;
}

###############################################################################
#  getFeaturesREADME_ftp_addr:  constructs ftp address for README file from
#  SGD features file address
###############################################################################
sub getFeaturesREADME_ftp_addr
{
    my %args = @_;

    my $README_ftp_addr = $args{chrom_ftp_addr};

    $README_ftp_addr =~ s/(.+)\/(.*tab)$/$1/gi;

    $README_ftp_addr = "$README_ftp_addr/README";

    return $README_ftp_addr;
}


###############################################################################
#  getProteinDatabaseFileName:  gets the name of the disk file where 
#  where Protein database file will be/has been copied to.
###############################################################################
sub getProteinDatabaseFileName
{
    my %args = @_;

    my $prot_file_name = $args{prot_ftp_addr} ||
        die "need prot_ftp_addr in getProteinDatabaseFileName";

    ## parse address to get last word ending with .gz
    $prot_file_name =~ s/(.+)\/(.*gz)$/$2/gi;

    ## remove the .gz
    $prot_file_name =~ s/(.+)\.gz$/$1/gi;

    return $prot_file_name;
}


###############################################################################
#  getProteinDatabaseZippedFileName:  gets the name of the disk file where 
#  where Protein database file will be/has been copied to.
###############################################################################
sub getProteinDatabaseZippedFileName
{
    my %args = @_;

    my $zipped_prot_file_name = $args{prot_ftp_addr} || 
        die "need prot_ftp_addr";

    ## parse address to get last word ending with .gz
    $zipped_prot_file_name =~ s/(.+)\/(.*gz)$/$2/gi;

    return $zipped_prot_file_name;
}


###############################################################################
#  getBLASTOutFileName:  get name of output file of BLAST to protein database
###############################################################################
sub getBLASTOutFileName 
{
    my %args = @_;

    my $organism_name = $args{organism_name} || die "need organism_name in getBLASTOutFileName";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $file = "$data_files_dir/blast_APD_" . $organism_name . "_out.txt";

    return $file;
}


###############################################################################
#  getProteinHitsFileName:  gets name of disk file of protein hits
#  (it's the output file of the parseBLAST stage)
###############################################################################
sub getProteinHitsFileName 
{
    my %args = @_;

    my $organism_name = $args{organism_name} || die "need organism_name";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $file = "$data_files_dir/APD_" . $organism_name . "_hits.tsv";

    return $file;
}


###############################################################################
#  getAPDLostFileName:  gets file name 
###############################################################################
sub getAPDLostFileName 
{
    my %args = @_;

    my $organism_abbrev = $args{organism_abbrev} or
        die "need organism_abbrev in getAPDLostFileName";

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $file = "$data_files_dir/APD_" . $organism_abbrev . "_lost_queries.dat";
      
    return $file;
}     


###############################################################################
#  getCoordsFileName:  gets coordinate mapping file name
###############################################################################
sub getCoordsFileName 
{
    my %args = @_;

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $fileName = "$data_files_dir/coordinate_mapping.txt";

    return $fileName;
}


###############################################################################
# mapPeptides - calculate chromosomal coords for peptide using 
#               peptide location in ORF and
#               set of CDS regions in translated protein
###############################################################################
sub mapPeptides
{
    my %args = @_;

    my $data_files_dir = $args{data_files_dir} || die "need data_files_dir";

    my $organism_name = $args{organism_name} || die "need organism_name";

    my $chrom_ftp_addr = $args{chrom_ftp_addr} || die "need chrom_ftp_addr";

    ## get features file name
    my $featuresFileName = getFeaturesFileName(
        chrom_ftp_addr => $args{'chrom_ftp_addr'},
        data_files_dir => $data_files_dir,
    );

    ## get protein hits file name
    my $proteinHitsFileName = getProteinHitsFileName (
        organism_name => $args{organism_name},
        data_files_dir => $data_files_dir,
    );

    ## create object of coordinate features for proteins in hits file
    my $proteinFeatures = new ProtFeatures( 
        FEATURESFILE => $featuresFileName,
        PROTEINHITSFILE => $proteinHitsFileName,
        data_files_dir => $data_files_dir,
    );

    ## store chrom coordinate info
    $proteinFeatures->readProteinCoords();

    ## calculate coding base-pairs in the translated protein:
    $proteinFeatures->calcCDSBasePairs();

    ## open coordfile for writing:
    my $coordfile = getCoordsFileName(
         data_files_dir => $data_files_dir,
    );

    open(COORD,">$coordfile") or die "Cannot open $coordfile for writing";

    ## open  protein hits file  for reading
    open(HITSFILE,"<$proteinHitsFileName") or die "Cannot open $proteinHitsFileName for reading";
 
    my $line;
    while ($line = <HITSFILE>) 
    {
        chomp ($line);
 
        my @columns = split(/\t/,$line);
 
        my $peptide = $columns[0];
        my $query_length = $columns[1];
        my $protein = $columns[2];
        my $hit_length = $columns[3];
        my $hit_percent_identity = $columns[4];
        my $pep_hit_start = $columns[5];
        my $pep_hit_end = $columns[6];
        my $pep_hit_dif = $columns[7];
  
        my $completeLine = $peptide . "\t".
            $query_length . "\t" .
            $protein . "\t" .
            $hit_length . "\t" .
            $hit_percent_identity . "\t".
            $pep_hit_start . "\t" .
            $pep_hit_end . "\t" .
            $pep_hit_dif;


        ## convert peptide ORF location to chromosomal coordinates:
        my %peptideHash = $proteinFeatures->getChromCoordHash(
            protein => $protein,
            pepStart => $pep_hit_start,
            pepEnd => $pep_hit_end,
        );
        ## returns a hash with :
        ##     first level key {index}
        ##          second level key{chrom}
        ##          second level key{chromStart}
        ##          second level key{chromEnd}
        ##          second level key{strand}

        ## need to know if it wasn't in features file:
        unless (%peptideHash) 
        {
            print "protein $protein not found in features file\n";
        }

        foreach my $ind ( sort keys %peptideHash ) 
        {
            my $buffer = $completeLine."\t".
                $peptideHash{$ind}{SGDID}."\t".
                $peptideHash{$ind}{strand}."\t".            
                $peptideHash{$ind}{chromStart}."\t".            
                $peptideHash{$ind}{chromEnd}."\t".
                $peptideHash{$ind}{chrom};

            print COORD "$buffer\n";
        } 
 
     }
 
     close(HITSFILE);

     close(COORD);
}

