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


    ## get hash with key = gene_name 
    ##             value = not important
    my %atlas_gene_names = get_atlas_gene_names( 
        atlas_build_id => $atlas_build_id);


    ## get hash with key = molecular function term,
    ##             value = number of genes in bin
    my %molecular_function_counts_atlas = 
        get_mf_bins( term_hash_ref => \%molecular_function_terms,
        gene_names_hash_ref => \%atlas_gene_names);


    my %referenceDB_gene_names = get_referenceDB_gene_names(
        atlas_build_id => $atlas_build_id);


    ## get hash with key = molecular function term,
    ##             value = number of genes in bin
    my %molecular_function_counts_referenceDB = 
        get_mf_bins( term_hash_ref => \%molecular_function_terms,
        gene_names_hash_ref => \%referenceDB_gene_names);


    write_to_outfile( term_hash_ref => \%molecular_function_terms,
        atlas_counts_ref => \%molecular_function_counts_atlas,
        referenceDB_counts_ref => \%molecular_function_counts_referenceDB,
    );

    make_percent_bar_graph( term_hash_ref => \%molecular_function_terms,
        atlas_counts_ref => \%molecular_function_counts_atlas,
        referenceDB_counts_ref => \%molecular_function_counts_referenceDB,
    );


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
# get_atlas_gene_names -- get hash with key = gene name for all mapped
# peptides
# @param atlas_build_id
# #return hash with key = gene name
#######################################################################
sub get_atlas_gene_names
{

    my %args = @_;

    my %gene_hash;

    my $atlasBuildId = $args{'atlas_build_id'} or die
        "need atlas build id ($!)";

    my $sql = qq~
        SELECT B.biosequence_gene_name, B.biosequence_gene_name
        FROM $TBAT_BIOSEQUENCE B, $TBAT_PEPTIDE_INSTANCE PEPI,
        $TBAT_PEPTIDE_MAPPING PM
        WHERE PEPI.atlas_build_id = '$atlas_build_id'
        AND PEPI.peptide_instance_id = PM.peptide_instance_id
        AND PM.matched_biosequence_id = B.biosequence_id
    ~;

    %gene_hash = $sbeams->selectTwoColumnHash($sql);

    return %gene_hash;

}


#######################################################################
# get_referenceDB_gene_names -- get hash with key = gene name
#
# @param atlas_build_id
# #return hash with key = gene name
#######################################################################
sub get_referenceDB_gene_names
{

    my %args = @_;

    my %gene_hash;

    my $atlasBuildId = $args{'atlas_build_id'} or die
        "need atlas build id ($!)";

    my $sql = qq~
        SELECT B.biosequence_gene_name, B.biosequence_gene_name
        FROM $TBAT_BIOSEQUENCE B, $TBAT_ATLAS_BUILD AB
        WHERE AB.atlas_build_id = '$atlas_build_id'
        AND B.biosequence_set_id = AB.biosequence_set_id
    ~;

    %gene_hash = $sbeams->selectTwoColumnHash($sql);

    return %gene_hash;

}


#######################################################################
#  get_mf_bins - get hash with key = molecular funtion term
#                             value = number of genes in bin
#
# @param hash reference for gene names
# @param hash reference for hash with GO ID's and terms
# @return hash with key = molecular funtion term, value= num genes
####################################################################
sub get_mf_bins
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || 
        die "ERROR: Must pass term hash reference ($!)";

    my %term_hash= %{$term_hash_ref};

    my $gene_names_hash_ref = $args{'gene_names_hash_ref'} ||
        die "ERROR: Must pass gene_names hash reference ($!)";

    my %gene_names_hash = %{$gene_names_hash_ref};


    ## making hash to hold key=mf term, val=num genes
    ## initializing values to zero:
    my %mf_num_hash;

    foreach my $go_id (keys %term_hash)
    {

        my $term = $term_hash{$go_id};

        $mf_num_hash{$term} = 0;

    }


    foreach my $go_id (keys %term_hash)
    {

        ## molecular_function:  GA.gene_annotation_type_id='1'
        ## yeast: AG.organism_namespace_id='2'
        #my $sql = qq~
        #SELECT B.biosequence_gene_name, GA.external_accession
        #FROM $TBAT_PEPTIDE_INSTANCE PI, $TBAT_PEPTIDE P,
        #PEPTIDE_MAPPING PM, $TBAT_BIOSEQUENCE B,
        #$TBAT_BIOSEQUENCE_ANNOTATED_GENE BAG,
        #$TBBL_ANNOTATED_GENE AG, $TBBL_GENE_ANNOTATION GA 
        #WHERE PI.atlas_build_id = '$atlas_build_id'
        #AND GA.gene_annotation_type_id='1' 
        #AND GA.hierarchy_level='1' 
        #AND AG.organism_namespace_id='2'   
        #AND P.peptide_id = PI.peptide_id
        #AND PM.peptide_instance_id = PI.peptide_instance_id
        #AND B.biosequence_id = PM.matched_biosequence_id
        #AND BAG.biosequence_id = B.biosequence_id
        #AND BAG.annotated_gene_id = AG.annotated_gene_id
        #AND GA.annotated_gene_id = AG.annotated_gene_id
        #AND GA.external_accession = '$go_id'
        #~;

        my $sql = qq~
        SELECT B.biosequence_gene_name, GA.external_accession
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

        ## hash to store keys = gene_name, value = only this GO id
        my %tmp_gene_hash = $sbeams->selectTwoColumnHash($sql);

        my $term = $term_hash{$go_id};

        foreach my $gene (keys %tmp_gene_hash)
        {

            ## if gene_name is in gene_hash:
            if (exists $gene_names_hash{$gene})
            {
                $mf_num_hash{$term} = $mf_num_hash{$term} + 1;
            }

        }

    }

    return %mf_num_hash;

}


#######################################################################
#
# make_bar_graph
#
#######################################################################
sub make_bar_graph
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || 
        die "ERROR: Must pass term hash ($!)";

    my %term_hash= %{$term_hash_ref};

    my $atlas_counts_ref = $args{atlas_counts_ref} || 
        die "ERROR: Must pass atlas_counts_ref ($!)";

    my %atlas_counts = %{$atlas_counts_ref};

    my $sgd_counts_ref = $args{sgd_counts_ref} || 
        die "ERROR: Must pass sgd_counts_ref ($!)";

    my %sgd_counts = %{$sgd_counts_ref};

    ## %term_hash :      keys = GO id, value = the GO term
    ## %binsHash  :      keys = GO id, value = num genes per bin

    my (@x, @y, @y2, @data);

    my $ymax = 0;


    ## fill x, y, y2 and data arrays:
    foreach my $term ( keys %term_hash )
    {

        push(@x, $term_hash{$term});

        push(@y, $atlas_counts{$term});

        push(@y2, $sgd_counts{$term});

        $ymax = $sgd_counts{$term} if ( $sgd_counts{$term} > $ymax);

    }

    @data = ([@x], [@y], [@y2]);

    my $graph = new GD::Graph::bars( 512, 512);

#   $graph->set_x_label_font(gdMediumBoldFont);

#   $graph->set_y_label_font(gdMediumBoldFont);

#   $graph->set_x_axis_font(gdMediumBoldFont);

#   $graph->set_y_axis_font(gdMediumBoldFont);

#   $graph->set_title_font(gdGiantFont);

    $graph->set(
        line_width      => 2,
    #   title           => "Yeast PeptideAtlas (Jul 2005, P>0.9)",
        x_label         => "GO Molecular Function bin",
        y_label         => "Number of Genes",
        x_labels_vertical => 1,
        y_max_value     => $ymax,
        l_margin => 10,
        r_margin => 10,
        b_margin => 10,
        t_margin => 10,
        dclrs    => [ qw(lblue green) ],
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

    $graph->set_legend( "Yeast PeptideAtlas Genes", "All SGD Genes" );

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
# write_to_outfile - write to outfile the GO molecular term,
# the number of SGD genes in the term bin, the number of Yeast
# atlas genes in the term bin
#######################################################################
sub write_to_outfile
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || 
        die "ERROR: Must pass term hash ($!)";

    my %term_hash= %{$term_hash_ref};

    my $atlas_counts_ref = $args{atlas_counts_ref} || 
        die "ERROR: Must pass atlas_counts_ref ($!)";

    my %atlas_counts = %{$atlas_counts_ref};

    my $referenceDB_counts_ref = $args{referenceDB_counts_ref} || 
        die "ERROR: Must pass referenceDB_counts_ref ($!)";

    my %referenceDB_counts = %{$referenceDB_counts_ref};

    ## %term_hash :      keys = GO id, value = the GO term
    ## %binsHash  :      keys = GO id, value = num genes per bin

    open(OUTFILE,">$outfile") or die "cannot write to $outfile";

    ## fill x, y, and data arrays:
    foreach my $go_id ( keys %term_hash )
    {

        my $term = $term_hash{$go_id};

        print OUTFILE sprintf("%45s    %8.0f    %8.0f\n",
            $term, $referenceDB_counts{$term}, 
            $atlas_counts{$term});

    }

    close(OUTFILE) or die "cannot close $outfile";

    print "wrote $outfile\n";

}

#######################################################################
#
# make_percent_bar_graph
#
#######################################################################
sub make_percent_bar_graph
{

    my %args = @_;

    my $term_hash_ref = $args{term_hash_ref} || 
        die "ERROR: Must pass term hash ($!)";

    my %term_hash= %{$term_hash_ref};

    my $atlas_counts_ref = $args{atlas_counts_ref} || 
        die "ERROR: Must pass atlas_counts_ref ($!)";

    my %atlas_counts = %{$atlas_counts_ref};

    my $referenceDB_counts_ref = $args{referenceDB_counts_ref} || 
        die "ERROR: Must pass referenceDB_counts_ref ($!)";

    my %referenceDB_counts = %{$referenceDB_counts_ref};

    ## %term_hash :      keys = GO id, value = the GO term
    ## %binsHash  :      keys = GO id, value = num genes per bin

    my (@x, @y, @data);

    my $ymax = 100;


    ## fill x, y, and data arrays:
    foreach my $go_id ( keys %term_hash )
    {

        my $term = $term_hash{$go_id};

        my $tmp_y;

        if ( $referenceDB_counts{$term} == 0 )
        {

            $tmp_y = 0;

        } else
        {

            $tmp_y = 100. * ($atlas_counts{$term} / $referenceDB_counts{$term});

        }

        push(@x, $term);

        push(@y, $tmp_y );

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
        x_label         => "GO Molecular Function bin",
        y_label         => "Percentage of GO annotated DB Reference Genes",
        x_labels_vertical => 1,
        y_max_value     => $ymax,
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
