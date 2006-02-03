#!/usr/local/bin/perl -w

###############################################################################
# Program     : yeast_molecular_function_figure.pl
# Author      : N. King 
# $Id:
#
# Description : 
#        Makes a figure of the number of Yeast PeptideAtlas genes
#        in first level children of molecular_function.  
#
#        NOTE: At this time, this should only be used for Yeast (Sc).
#        as have organism, etc hard wired, and yeast file name.
#        should be generalized one day soon...
#
# Also writes an output yeastMolecularFunctionData.txt for use with
# IDL plotting program
#
###############################################################################

use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $current_username
             $PROG_NAME $USAGE %OPTIONS $TEST $QUIET
             $atlas_build_id $PASS $outfile
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

## PeptideAtlas classes
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

## BioLink
use SBEAMS::BioLink::Tables;

## graphics libraries:
use GD;
use GD::Graph;
use GD::Graph::xylines;
use GD::Graph::xylinespoints;
use GD::Graph::xypoints;
use GD::Graph::bars;
use GD::Text;


$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

## USAGE:
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: [OPTIONS] key=value key=value ...
Options:
  --test               test program

  --run                run program

  --atlas_build_id     id of atlas

 e.g.:  ./$PROG_NAME --run --atlas_build_id '73'

EOU


GetOptions(\%OPTIONS, "test", "run", "atlas_build_id:s");


if ( ($OPTIONS{"run"} && $OPTIONS{"atlas_build_id"}) || $OPTIONS{"test"} )
{

    $atlas_build_id =  $OPTIONS{"atlas_build_id"};


} else
{

    print "$USAGE\n";

    exit(0);

};



## if test, using yeast atlas P>0.9 characteristics 
if ( $OPTIONS{"test"} )
{

    $atlas_build_id = '73';

    $TEST = $OPTIONS{"test"};

} else
{

    $TEST = 0;

}


## set default test pass to zero
$PASS = 0;

$outfile = "molecularFunctionData.txt";


main();

exit(0);


###############################################################################
# main
###############################################################################
sub main
{

    ## validate user
    check_authentication();


    ##$sbeams->printPageHeader() unless ($QUIET);

    #### Print out the header
    ##$sbeams->printUserContext() if ($QUIET > 0);


    ## check that can write to outfile (also initialize):
    check_file();


    ## get term hash for the molecular function level1 children bins.
    ## data structure is a hash with   key = GO id
    ##                               value = term
    my %molecular_function_terms = get_level1_term_hash();


    my %termFractionHash = getTermFractions(
        term_hash_ref => \%molecular_function_terms
    );

    write_to_outfile( term_fraction_hash_ref => \%termFractionHash);

    make_percent_bar_graph( 
        term_fraction_hash_ref => \%termFractionHash);


    ##$sbeams->printPageFooter() unless ($QUIET);

} ## end main


#######################################################################
# check_authenticatation -- use SBEAMS authentication and exit if a 
#    username is not returned
#######################################################################
sub check_authentication
{

    exit unless ( $current_username =

        $sbeams->Authenticate(

        work_group=>'PeptideAtlas_admin')
    );

}


#######################################################################
# check_file -- check that can write to outfile and initialize
#######################################################################
sub check_file()
{

    ## initialize file:
    open(OUTFILE,">$outfile") or die "cannot write to $outfile";

    close(OUTFILE) or die "cannot close $outfile";

}



#######################################################################
#  get_level1_term_hash -- get global term_hash of first level children of
#                   molecular function
#                   hash of keys = GO numbers, value = the GO term
####################################################################
sub get_level1_term_hash 
{

    my %args = @_;

    ## note, chemoattractant activity, chemorepellant activity,
    ## and energy transducer activity have no children in
    ## any of the species in amigo version of go database

    my %term_hash =  (
        "GO:0016209"  => 'antioxidant activity',
        "GO:0005488"  => 'binding',
        "GO:0003824"  => 'catalytic activity',
        "GO:0030188"  => 'chaperone regulator activity',
        "GO:0042056" =>  'chemoattractant activity',
        "GO:0045499" =>  'chemorepellant activity',
        "GO:0031992" =>  'energy transducer activity',
        "GO:0030234"  => 'enzyme regulator activity',
        "GO:0005554"  => 'molecular_function unknown',
        "GO:0003774"  => 'motor activity',
        "GO:0045735"  => 'nutrient reservoir activity',
        "GO:0031386"  => 'protein_tag',
        "GO:0004871"  => 'signal transducer activity',
        "GO:0005198"  => 'structural molecule activity',
        "GO:0030528"  => 'transcription regulator activity',
        "GO:0045182"  => 'translation regulator activity',
        "GO:0005215"  => 'transporter activity',
        "GO:0030533"  => 'triplet codon-amino acid adaptor activity',
    );


    return %term_hash;

}


#######################################################################
# write_to_outfile - write to outfile the GO molecular term,
# and the percent of genes in that term foudn in the atlas
# @param term_fraction_hash_ref 
#######################################################################
sub write_to_outfile
{

    my %args = @_;

    my $term_fraction_hash_ref = $args{term_fraction_hash_ref} || 
        die "ERROR: Must pass term fraction hash ($!)";

    my %term_fraction_hash= %{$term_fraction_hash_ref};

    open(OUTFILE,">$outfile") or die "cannot write to $outfile";

    ## fill x, y, and data arrays:
    foreach my $go_term ( keys %term_fraction_hash )
    {

#       my $go_term = $term_fraction_hash{$go_id};
 
        my $percent = ($term_fraction_hash{$go_term}) * 100;

        print OUTFILE sprintf("%45s  %8.0f\n",
            $go_term, $percent );

    }

    close(OUTFILE) or die "cannot close $outfile";

    print "wrote $outfile\n";

}

#######################################################################
#
# make_percent_bar_graph
# @param term_fraction_hash
#######################################################################
sub make_percent_bar_graph
{

    my %args = @_;

    my $term_fraction_hash_ref = $args{term_fraction_hash_ref} || 
        die "ERROR: Must pass term fraction hash ($!)";

    my %term_fraction_hash= %{$term_fraction_hash_ref};

    my (@x, @y, @data);

    my $ymax = 100;


    ## fill x, y, and data arrays:
    foreach my $go_term ( keys %term_fraction_hash )
    {

#       my $go_term = $term_fraction_hash{$go_id};
 
        my $percent = ($term_fraction_hash{$go_term}) * 100;

        push(@x, $go_term);

        push(@y, $percent);

    }

    @data = ([@x], [@y]);

    my $graph = new GD::Graph::bars( 512, 512);

#   $graph->set_x_label_font(gdMediumBoldFont);

#   $graph->set_y_label_font(gdMediumBoldFont);

#   $graph->set_x_axis_font(gdMediumBoldFont);

#   $graph->set_y_axis_font(gdMediumBoldFont);

#   $graph->set_title_font(gdGiantFont);

    $graph->set(
        line_width      => 2,
    #   title           => "Yeast PeptideAtlas (Jul 2005, P>0.9)",
        x_label         => "GO Molecular Function Level 1 Leaf Terms",
        y_label         => "Percentage of Term Genes in Yeast PeptideAtlas",
        x_labels_vertical => 1,
        y_max_value     => $ymax,
        y_min_value     => 0,
        l_margin => 10,
        r_margin => 10,
        b_margin => 10,
        t_margin => 10,
        dclrs    => [ qw(green) ],
        markers => [2,1],
        bgclr    => 'white',
        transparent   => 0,
        fgclr         => 'black',
        labelclr      => 'black',
        legendclr      => 'black',
        axislabelclr  => 'black',
        textclr      => 'black',
    ) or die $graph->error;
    #   bar_width  => 
    #   bar_spacing =>

    $graph->set_legend( "Yeast PeptideAtlas Genes");

    my $gd_image = $graph->plot( \@data ) or die $graph->error;

    open(PLOT, ">go_molecular_function.png") or 
        die("Cannot open file for writing");

    # Make sure we are writing to a binary stream
    binmode PLOT;

    # Convert the image to PNG and print it to the file PLOT
    print PLOT $gd_image->png;

    close PLOT;

    print "wrote go_molecular_function.png\n";

}


#######################################################################
#  print_hash
#
# @param reference to hash to print
#######################################################################
sub print_hash
{

    my %args = @_;

    my $hr = $args{hash_ref};

    my %h = %{$hr};

    foreach my $k (keys %h)
    {

        print "key:$k  value:$h{$k}\n";

    }

}


#######################################################################
# getTermFractions
# @param $term_hash_ref
# @return hash with key = term, value = fraction atlas genes in term
#######################################################################
sub getTermFractions
{

    my %args = @_;

    my $term_hash_ref = $args{'term_hash_ref'} or die 
        "need term_hash_ref ($!)";

    my %term_hash = %{$term_hash_ref};

    my %term_fraction_hash;

    foreach my $go_id (keys %term_hash)
    {
        my $sql = qq~
        SELECT COUNT (DISTINCT B.biosequence_gene_name)
        FROM $TBAT_ATLAS_BUILD AB, $TBAT_BIOSEQUENCE B,
        $TBAT_BIOSEQUENCE_ANNOTATED_GENE BAG,
        $TBBL_ANNOTATED_GENE AG, $TBBL_GENE_ANNOTATION GA
        WHERE AB.atlas_build_id = '$atlas_build_id'
        AND AB.biosequence_set_id = B.biosequence_set_id
        AND BAG.biosequence_id = B.biosequence_id
        AND BAG.annotated_gene_id = AG.annotated_gene_id
        AND GA.annotated_gene_id = AG.annotated_gene_id
        AND AG.organism_namespace_id='2'
        AND GA.gene_annotation_type_id='1'
        AND GA.hierarchy_level='1'
        AND GA.external_accession = '$go_id'
        ~;

        my ($n_all_genes_in_term) = $sbeams->selectOneColumn($sql);

        $sql = qq~
        SELECT COUNT (DISTINCT B.biosequence_gene_name)
        FROM  $TBAT_BIOSEQUENCE B,
        $TBAT_BIOSEQUENCE_ANNOTATED_GENE BAG,
        $TBBL_ANNOTATED_GENE AG, 
        $TBBL_GENE_ANNOTATION GA,
        $TBAT_PEPTIDE_INSTANCE PEPI, 
        $TBAT_PEPTIDE_MAPPING PM
        WHERE PEPI.atlas_build_id = '$atlas_build_id'
        AND PEPI.peptide_instance_id = PM.peptide_instance_id
        AND PM.matched_biosequence_id = B.biosequence_id
        AND BAG.biosequence_id = B.biosequence_id
        AND BAG.annotated_gene_id = AG.annotated_gene_id
        AND GA.annotated_gene_id = AG.annotated_gene_id
        AND AG.organism_namespace_id='2'
        AND GA.gene_annotation_type_id='1'
        AND GA.hierarchy_level='1'
        AND GA.external_accession = '$go_id'
        ~;

        my ($n_atlas_genes_in_term) = $sbeams->selectOneColumn($sql);

        my $frac;
        if ($n_all_genes_in_term == 0)
        {
            #$frac = -99;
            $frac = 0;
        } else
        {
            $frac = $n_atlas_genes_in_term / $n_all_genes_in_term;
        }
        $frac = sprintf("%6.2f", $frac);

        my $go_term = $term_hash{$go_id};

#       print "$frac $go_term\n";
        
        $term_fraction_hash{ $go_term } = $frac;

    }

    return %term_fraction_hash;

}

