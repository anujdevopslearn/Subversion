#!/usr/local/bin/perl -w

###############################################################################
# Program     : count_genes_yeast.pl
# Author      : nking
# $Id:  Exp $
#
# Description : This reads APD file to get protein list, and then
# reads SGD_features file to get number of unique gene names
#
###############################################################################


###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($current_username $BASE_DIR $ORGANISM
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --testonly             If set, rows in the database are not changed or added

  --base_dir             Base directory path (has APD hits file and features file)
  --organism             assumed yeast here

 e.g.:  ./count_genes_yeast.pl --base_dir /net/db/projects/PeptideAtlas/pipeline/output/YeastBuild2/DATA_FILES

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "base_dir:s", "organism:s")) {

    die "\n$USAGE";

}

$VERBOSE = $OPTIONS{"verbose"} || 0;

$QUIET = $OPTIONS{"quiet"} || 0;

$DEBUG = $OPTIONS{"debug"} || 0;

$TESTONLY = $OPTIONS{"testonly"} || 0;

$BASE_DIR = $OPTIONS{"base_dir"} || 0;

$ORGANISM = $OPTIONS{"organism"} || 'yeast';


if ($DEBUG) {

    print "Options settings:\n";

    print "  VERBOSE = $VERBOSE\n";

    print "  QUIET = $QUIET\n";

    print "  DEBUG = $DEBUG\n";

    print "  BASE_DIR = $BASE_DIR\n";

    print "  ORGANISM = $ORGANISM\n";

}
   

unless ($BASE_DIR) {

    die "\nNeed base_dir\n$USAGE\n";

}
   

###############################################################################
# Set Global Variables and execute main()
###############################################################################

handleRequest();

exit(0);


########################################################################
# handleRequest
########################################################################
sub handleRequest {

    my %args = @_;

    #### Set the command-line options
    my $apd_hits_file = "$BASE_DIR/APD_$ORGANISM"."_hits.tsv";

    my $features_file = "$BASE_DIR/SGD_features.tab";

    my %orf_hash;


    ## read APD hits file to get hash with keys = protein names.
    my $infile = $apd_hits_file;

    open(INFILE, "<$infile") or 
        die "cannot open $infile for reading ($!)";

    my $line;

    while ($line = <INFILE>) {

        chomp($line);

        my ($pep, $d1, $orf, $d2, $d3, $d4, $d5, $d6) = split("\t",$line);

        $orf_hash{$orf} = $orf;

    }
    
    close(INFILE) or die "cannot close $infile ($!)";
  

    my %mapped_gene_hash; ##keys=gene, value=comma sep string of orfs
    my %gene_hash; ##keys=gene...this is for all genes in SGD features file

    ## read SGD features file to get gene names
    $infile = $features_file;

    open(INFILE, "<$infile") or
    die "cannot open $infile for reading ($!)";

    while ($line = <INFILE>) {

        chomp($line);

        my @columns = split(/\t/,$line);
    
        my $featureType = $columns[1];

        my $featureName = $columns[3];

        my $gene_name = $columns[4];

        if  ($featureType eq "ORF")  {

            $gene_hash{$gene_name} = $gene_name;

            if ( exists $orf_hash{$featureName} ) {

                if ( exists $mapped_gene_hash{$gene_name} ) {## in case want to write to file later:

                    $mapped_gene_hash{$gene_name} = 
                        join ",", $mapped_gene_hash{$gene_name}, $featureName;
    
                } else {

                    $mapped_gene_hash{$gene_name} = $featureName;

                }

            }

        }
    }
    close(INFILE) or die "cannot close $infile ($!)";
  

    my $n_genes = keys %gene_hash;

    my $n_mapped_genes = keys %mapped_gene_hash;

    my $frac = $n_mapped_genes/$n_genes;

    $frac = sprintf "%.2f", $frac;

    print "Number of genes in SGD features file is $n_genes\n";

    print "Number of genes atlas maps to is $n_mapped_genes ($frac of total)\n";
}
